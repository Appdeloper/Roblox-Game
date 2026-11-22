--!strict
--[[
	RoundService — owns each player's run: Lobby → Running (stages 1..N) → Finished.

	Modes (shared/Modes.luau): Story, Daily (seeded stage list), Endless (shuffled stages, lives,
	faster mannequin each clear) and Coop (a party shares clears; a caught player is downed until
	a teammate revives them; everyone down = the party retakes the stage).

	It is the orchestrator: it teleports, counts retakes (via CheckpointService), spawns and
	resets the mannequin, and runs one 10 Hz zone watcher for every running player (stage exits,
	painted-door triggers, scare zones, kill line, real/fake exits). Other services hook in through
	the RunFinished / StageEntered signals so this file never grows their logic.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local Clock = require(ReplicatedStorage.Shared.Clock)
local Motion = require(ReplicatedStorage.Shared.Motion)
local Config = require(ReplicatedStorage.Shared.Config)
local Modes = require(ReplicatedStorage.Shared.Modes)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Signal = require(ReplicatedStorage.Shared.Signal)
local TimeFormat = require(ReplicatedStorage.Shared.TimeFormat)
local Types = require(ReplicatedStorage.Shared.Types)
local Zone = require(ReplicatedStorage.Shared.Zone)
local Analytics = require(script.Parent.Analytics)
local CheckpointService = require(script.Parent.CheckpointService)
local MannequinService = require(script.Parent.MannequinService)
local RemoteGuard = require(script.Parent.RemoteGuard)

local RoundService = {}

export type RunResult = {
	time: number,
	retakes: number,
	-- false when anti-cheat thresholds were not met (no leaderboard / badges).
	verified: boolean,
	doorsOutran: number,
	mode: Modes.Mode,
	-- Stages cleared this run (the Endless score).
	cleared: number,
	-- true when the player escaped the theatre (Endless runs end when lives run out instead).
	escaped: boolean,
	-- Daily only: the UTC day the run belongs to.
	dailyDay: number?,
	-- Co-op: how many players started the show together (1 otherwise).
	partySize: number,
}

type Party = {
	members: { Player },
	realExits: { [number]: string },
}

type Run = {
	mode: Modes.Mode,
	lives: number,
	dailyDay: number?,
	party: Party?,
	downed: boolean,
	reviveProgress: number,
	phase: Types.RunPhase,
	-- workspace:GetServerTimeNow() at start (shared clock for the HUD timer).
	startedAt: number,
	clockStartedAt: number,
	-- Stage index -> name of the real exit, picked when the run starts.
	realExits: { [number]: string },
	scaresPlayed: { [number]: boolean },
	respawning: boolean,
	lastStartRequest: number,
	lastFakeExitAt: number,
	verified: boolean,
	doorsOutran: number,
}

-- Fired after a run completes; handlers return nothing. (player, result)
RoundService.RunFinished = Signal.new() :: Signal.Signal<Player, RunResult>
-- Fired whenever a stage (re)starts. (player, stageIndex, isRetake)
RoundService.StageEntered = Signal.new() :: Signal.Signal<Player, number, boolean>
-- Fired when a player stands in a stage's scare zone for the first time this run.
RoundService.ScareZoneEntered = Signal.new() :: Signal.Signal<Player, number>
-- Fired when a player clears a stage (before moving on). (player, stageIndex)
RoundService.StageCleared = Signal.new() :: Signal.Signal<Player, number>
-- Fired when a downed co-op player is revived. (player, revivedBy)
RoundService.Revived = Signal.new() :: Signal.Signal<Player, Player>

-- Optional hook so DataService can enrich the finish ticket (best time etc.).
export type TicketEnricher = (player: Player, result: RunResult, ticket: Types.TicketData) -> ()
local ticketEnricher: TicketEnricher? = nil

local map: Types.MapInfo
local runs: { [Player]: Run } = {}

-- ── Helpers ───────────────────────────────────────────────────────────────────────────────

local function newRun(): Run
	return {
		phase = "Lobby",
		startedAt = 0,
		clockStartedAt = 0,
		realExits = {},
		scaresPlayed = {},
		respawning = false,
		lastStartRequest = -math.huge,
		lastFakeExitAt = -math.huge,
		verified = true,
		doorsOutran = 0,
		mode = "Story",
		lives = 0,
		dailyDay = nil,
		party = nil,
		downed = false,
		reviveProgress = 0,
	}
end

local function rootPosition(player: Player): Vector3?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return nil
	end
	return root.Position
end

local function stageStartInfo(player: Player, run: Run, isRetake: boolean): Types.StageStartInfo
	local progress = CheckpointService.get(player)
	local stage = if progress then progress.stage else 1
	local text = Config.Stages[stage]
	return {
		stage = stage,
		title = text.Title,
		act = text.Act,
		hint = text.Hint,
		isRetake = isRetake,
		realExit = if run.party then (run.party :: Party).realExits[stage] else run.realExits[stage],
		runStartedAt = run.startedAt,
		retakes = if progress then progress.retakes else 0,
		mode = run.mode,
		lives = if run.mode == "Endless" then run.lives else nil,
		step = if progress then progress.step else 1,
		steps = if progress and run.mode ~= "Endless" then #progress.sequence else nil,
	}
end

--- Picks the real exit for a stage with a door choice (fresh each time the stage is entered,
--- so it can't be memorised across Endless laps).
local function pickRealExit(stageIndex: number): string?
	local info = map.stages[stageIndex]
	if not info or not info.exits then
		return nil
	end
	local candidates = {}
	for _, exit in info.exits do
		if exit.canBeReal then
			table.insert(candidates, exit.name)
		end
	end
	return if #candidates > 0 then candidates[math.random(1, #candidates)] else nil
end

local function setDowned(player: Player, run: Run, downed: boolean)
	run.downed = downed
	run.reviveProgress = 0
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = if downed then 0 else Config.Movement.WalkSpeed
		humanoid.JumpPower = if downed then 0 else Config.Movement.JumpPower
	end
	if character then
		character:SetAttribute("Downed", downed)
	end
end

local function applyMovement(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.UseJumpPower = true
		humanoid.JumpPower = Config.Movement.JumpPower
		humanoid.WalkSpeed = Config.Movement.WalkSpeed
	end
end

-- ── Stage flow ────────────────────────────────────────────────────────────────────────────

--- Puts the player at their checkpoint, resets the mannequin and tells the client.
local function enterStage(player: Player, run: Run, isRetake: boolean)
	local stage = CheckpointService.stageInfo(player)
	if not stage then
		return
	end
	if not isRetake and not run.party then
		run.realExits[stage.index] = pickRealExit(stage.index) :: string
	end
	if run.downed then
		setDowned(player, run, false)
	end
	CheckpointService.teleportToEntrance(player)
	if run.mode == "Endless" then
		local progress = CheckpointService.get(player)
		MannequinService.setCopycatDelay(
			player,
			Modes.endlessDelay(Config.Modes.Endless, if progress then progress.cleared else 0)
		)
	end
	MannequinService.reset(player, stage)
	run.respawning = false
	Remotes.get("StageStarted"):FireClient(player, stageStartInfo(player, run, isRetake))
	RoundService.StageEntered:Fire(player, stage.index, isRetake)
	if not isRetake then
		Analytics.track("stage_started", player, { stage = stage.index })
	end
end

function RoundService.startRun(player: Player, mode: Modes.Mode?, party: Party?): boolean
	local run = runs[player]
	if not run or run.phase == "Running" then
		return false
	end
	local chosen: Modes.Mode = mode or "Story"
	local now = Clock.now()
	if now - run.lastStartRequest < Config.Run.StartCooldown then
		return false
	end
	run.lastStartRequest = now
	run.phase = "Running"
	run.startedAt = Clock.serverNow()
	run.clockStartedAt = now
	table.clear(run.realExits)
	run.mode = chosen
	run.party = party
	run.downed = false
	run.reviveProgress = 0
	run.lives = if chosen == "Endless" then Config.Modes.Endless.Lives else 0
	run.dailyDay = nil
	run.verified = true
	run.doorsOutran = 0
	if Config.Scares.PlayOncePerRun then
		table.clear(run.scaresPlayed)
	end
	if chosen == "Daily" then
		local day = Modes.dayNumber(os.time())
		run.dailyDay = day
		CheckpointService.begin(player, Modes.dailySequence(day, Config.Game.StageCount, Config.Modes.Daily.Length))
	elseif chosen == "Endless" then
		local seed = os.time() + player.UserId
		CheckpointService.begin(player, Modes.endlessSequence(seed, Config.Game.StageCount, 1), function(step)
			return Modes.endlessSequence(seed, Config.Game.StageCount, step)[step]
		end)
		MannequinService.setCopycatDelay(player, Config.Modes.Endless.BaseDelay)
	else
		CheckpointService.begin(player)
		MannequinService.setCopycatDelay(player, nil)
	end
	Analytics.track("run_started", player, { mode = chosen })
	local stage = CheckpointService.stageInfo(player) :: Types.StageInfo
	MannequinService.spawn(player, stage)
	Remotes.get("RunStarted"):FireClient(player, run.startedAt)
	enterStage(player, run, false)
	return true
end

local function respawnAtCheckpoint(player: Player)
	local run = runs[player]
	if run and run.phase == "Running" then
		enterStage(player, run, true)
	end
end

-- Defined below; sendBack ends an Endless run through it.
local finish: (player: Player, run: Run) -> ()

--- Shared path for anything that sends you back to the stage entrance.
local function sendBack(player: Player, run: Run, reason: "caught" | "fell" | "died" | "spotted", countIt: boolean)
	if run.phase ~= "Running" or run.respawning or run.downed then
		return
	end
	if run.party and reason == "caught" then
		RoundService.down(player, run)
		return
	end
	run.respawning = true
	local progress = CheckpointService.get(player)
	local retakes = if countIt then CheckpointService.addRetake(player) elseif progress then progress.retakes else 0
	local stage = if progress then progress.stage else 0
	Analytics.track(
		if reason == "caught" then "caught" else "fell",
		player,
		{ stage = stage, retakes = retakes, reason = reason }
	)
	if reason == "caught" then
		Remotes.get("Caught"):FireClient(player, retakes)
	elseif reason == "fell" then
		Remotes.get("Fell"):FireClient(player, retakes)
	elseif reason == "spotted" then
		Remotes.get("Spotted"):FireClient(player, retakes)
	end
	if run.mode == "Endless" and countIt then
		run.lives -= 1
		if run.lives <= 0 then
			-- Out of lives: the Endless run ends here and its score is stages cleared.
			task.delay(Config.Catch.RespawnDelay, function()
				if run.phase == "Running" then
					finish(player, run)
				end
			end)
			return
		end
	end
	if reason ~= "died" then
		task.delay(Config.Catch.RespawnDelay, respawnAtCheckpoint, player)
	end
end

function finish(player: Player, run: Run)
	local progress = CheckpointService.get(player)
	if not progress then
		return
	end
	local elapsed = Clock.now() - run.clockStartedAt
	local verified = run.verified and elapsed >= Config.AntiCheat.MinRunSeconds
	local result: RunResult = {
		time = elapsed,
		retakes = progress.retakes,
		verified = verified,
		doorsOutran = run.doorsOutran,
		mode = run.mode,
		cleared = progress.cleared,
		escaped = run.mode ~= "Endless",
		dailyDay = run.dailyDay,
		partySize = if run.party then #(run.party :: Party).members else 1,
	}
	run.phase = "Finished"
	MannequinService.despawn(player)
	Analytics.track("finished", player, { time = elapsed, retakes = progress.retakes, verified = verified })

	local ticket: Types.TicketData = {
		escapeTime = elapsed,
		retakes = progress.retakes,
		bestTime = nil,
		isNewBest = false,
		titleEarned = if progress.retakes == 0 and result.escaped then Config.Titles.OpeningNight.DisplayName else nil,
		mode = run.mode,
		stagesCleared = progress.cleared,
		skin = Config.DefaultTicketSkin,
		playerName = player.DisplayName,
		seat = TimeFormat.seat(player.UserId),
	}
	RoundService.RunFinished:Fire(player, result)
	if ticketEnricher then
		local ok, err = pcall(ticketEnricher, player, result, ticket)
		if not ok then
			warn("[RoundService] ticket enricher failed: " .. tostring(err))
		end
	end
	CheckpointService.clear(player)
	if run.downed then
		setDowned(player, run, false)
	end
	run.party = nil
	CheckpointService.teleport(player, map.lobbySpawn)
	Remotes.get("RunFinished"):FireClient(player, ticket)
end

local function partyMembersRunning(party: Party): { Player }
	local out = {}
	for _, member in party.members do
		local r = runs[member]
		if member.Parent and r and r.phase == "Running" and r.party == party then
			table.insert(out, member)
		end
	end
	return out
end

local function clearStage(player: Player, run: Run)
	local progress = CheckpointService.get(player)
	if not progress then
		return
	end
	local stageTime = Clock.now() - progress.stageStartedAt
	if stageTime < Config.AntiCheat.MinStageSeconds[progress.stage] then
		-- Impossible clear: still let them progress, but keep it off the leaderboard.
		run.verified = false
	end
	Analytics.track("stage_cleared", player, {
		stage = progress.stage,
		time = stageTime,
		retakes = progress.stageRetakes,
	})
	local party = run.party
	if party then
		for _, member in partyMembersRunning(party) do
			RoundService.StageCleared:Fire(member, progress.stage)
		end
		-- One clear moves the whole party on (or finishes the show for everyone).
		local nextStage = progress.sequence[progress.step + 1]
		if nextStage then
			party.realExits[nextStage] = pickRealExit(nextStage) :: string
		end
		for _, member in partyMembersRunning(party) do
			local memberRun = runs[member]
			if memberRun then
				if CheckpointService.advance(member) then
					enterStage(member, memberRun, false)
				else
					finish(member, memberRun)
				end
			end
		end
		return
	end
	RoundService.StageCleared:Fire(player, progress.stage)
	if CheckpointService.advance(player) then
		enterStage(player, run, false)
	else
		finish(player, run)
	end
end

-- ── Co-op ─────────────────────────────────────────────────────────────────────────────────

local function notifyParty(party: Party, message: string)
	for _, member in party.members do
		if member.Parent then
			Remotes.get("Notify"):FireClient(member, message)
		end
	end
end

--- Caught in co-op: frozen in place until a teammate revives you. If nobody is left standing,
--- the whole party takes the stage from the top.
function RoundService.down(player: Player, run: Run)
	local party = run.party :: Party
	setDowned(player, run, true)
	MannequinService.holdForScare(player, 1e6)
	Remotes.get("Caught")
		:FireClient(player, CheckpointService.get(player) and (CheckpointService.get(player) :: any).retakes or 0)
	notifyParty(party, player.DisplayName .. " is down! Stand next to them to revive.")
	Analytics.track("downed", player, { stage = (CheckpointService.get(player) or { stage = 0 } :: any).stage })
	local standing = 0
	for _, member in partyMembersRunning(party) do
		local r = runs[member]
		if r and not r.downed then
			standing += 1
		end
	end
	if standing == 0 then
		notifyParty(party, "CUT! The whole cast is down. Take it from the top!")
		for _, member in partyMembersRunning(party) do
			local r = runs[member]
			if r then
				r.downed = false
				r.respawning = true
				CheckpointService.addRetake(member)
				task.delay(Config.Catch.RespawnDelay, respawnAtCheckpoint, member)
			end
		end
	end
end

local function revive(player: Player, run: Run, by: Player)
	setDowned(player, run, false)
	local stage = CheckpointService.stageInfo(player)
	if stage then
		-- Fresh grace and a fresh trail, from where you stand.
		MannequinService.reset(player, stage)
	end
	notifyParty(run.party :: Party, by.DisplayName .. " revived " .. player.DisplayName .. "!")
	RoundService.Revived:Fire(player, by)
	Analytics.track("revived", player, { by = by.UserId })
end

--- Zone-loop hook: downed players next to a standing teammate get revived over time.
local function checkRevive(player: Player, run: Run, pos: Vector3)
	local party = run.party
	if not party or not run.downed then
		return
	end
	local cfg = Config.Modes.Coop
	local helper: Player? = nil
	for _, member in partyMembersRunning(party) do
		local r = runs[member]
		local mpos = rootPosition(member)
		if member ~= player and r and not r.downed and mpos and (mpos - pos).Magnitude <= cfg.ReviveRadius then
			helper = member
			break
		end
	end
	if helper then
		run.reviveProgress += Config.Zones.CheckInterval
		if run.reviveProgress >= cfg.ReviveSeconds then
			revive(player, run, helper)
		end
	else
		run.reviveProgress = 0
	end
end

local gathering: { members: { Player }, startsAt: number }? = nil

local function startCoop()
	local g = gathering
	gathering = nil
	if not g then
		return
	end
	local party: Party = { members = {}, realExits = {} }
	for _, member in g.members do
		local r = runs[member]
		if member.Parent and r and r.phase ~= "Running" then
			table.insert(party.members, member)
		end
	end
	if #party.members == 0 then
		return
	end
	party.realExits[1] = pickRealExit(1) :: string
	for _, member in party.members do
		RoundService.startRun(member, "Coop", party)
	end
	Analytics.track("coop_started", party.members[1], { size = #party.members })
end

--- Co-op: the first request opens a short gathering window; everyone in the lobby who picks
--- Co-op before it closes (up to MaxPlayers) starts together.
local function requestCoop(player: Player)
	local run = runs[player]
	if not run or run.phase == "Running" then
		return
	end
	local cfg = Config.Modes.Coop
	if not gathering then
		gathering = { members = {}, startsAt = Clock.now() + cfg.GatherSeconds }
		task.delay(cfg.GatherSeconds, startCoop)
	end
	local g = gathering :: { members: { Player }, startsAt: number }
	if table.find(g.members, player) or #g.members >= cfg.MaxPlayers then
		return
	end
	table.insert(g.members, player)
	local message = string.format(
		"Co-op starts in %ds (%d/%d). Pick Co-op to join!",
		math.max(1, math.ceil(g.startsAt - Clock.now())),
		#g.members,
		cfg.MaxPlayers
	)
	for _, other in Players:GetPlayers() do
		local r = runs[other]
		if r and r.phase ~= "Running" then
			Remotes.get("Notify"):FireClient(other, message)
		end
	end
end

--- Starts a run in `mode` (Coop gathers a party first).
function RoundService.requestMode(player: Player, mode: string)
	if not Modes.isMode(mode) then
		return
	end
	if mode == "Coop" then
		requestCoop(player)
	else
		RoundService.startRun(player, mode :: Modes.Mode)
	end
end

function RoundService.returnToLobby(player: Player, reason: string)
	local run = runs[player]
	if not run then
		return
	end
	if run.phase == "Running" then
		local progress = CheckpointService.get(player)
		Analytics.track("quit_stage", player, {
			stage = if progress then progress.stage else 0,
			retakes = if progress then progress.retakes else 0,
			reason = reason,
		})
	end
	run.phase = "Lobby"
	run.respawning = false
	if run.downed then
		setDowned(player, run, false)
	end
	run.party = nil
	MannequinService.despawn(player)
	CheckpointService.clear(player)
	CheckpointService.teleport(player, map.lobbySpawn)
	Remotes.get("ReturnedToLobby"):FireClient(player)
end

-- ── Zone watcher (10 Hz) ──────────────────────────────────────────────────────────────────

local function checkExits(player: Player, run: Run, stage: Types.StageInfo, pos: Vector3)
	for _, exit in stage.exits :: { Types.ExitInfo } do
		if Zone.contains(exit.zone, pos) then
			local real = if run.party then (run.party :: Party).realExits[stage.index] else run.realExits[stage.index]
			if exit.name == real then
				clearStage(player, run)
			elseif Clock.now() - run.lastFakeExitAt > 2 then
				run.lastFakeExitAt = Clock.now()
				Remotes.get("FakeExit"):FireClient(player, exit.name)
				Analytics.track("fake_exit", player, { stage = stage.index })
			end
			return
		end
	end
end

local function watchPlayer(player: Player, run: Run)
	local stage = CheckpointService.stageInfo(player)
	local pos = rootPosition(player)
	if not stage or not pos then
		return
	end
	if run.downed then
		checkRevive(player, run, pos)
		return
	end
	if pos.Y < stage.killY then
		sendBack(player, run, "fell", Config.Retakes.CountFalls)
		return
	end
	for _, door in stage.doors do
		if Zone.contains({ cframe = door.triggerCFrame, size = door.triggerSize }, pos) then
			MannequinService.tryDoor(player, door)
		end
	end
	if stage.spinners then
		-- Light-rig beams: judged here from the same clock the clients animate with. The beam
		-- must have been on for a moment, so a crossing that looked clear on screen stays clear.
		local now = Clock.serverNow()
		for _, rig in stage.spinners do
			if
				Zone.contains(rig.gate, pos)
				and Motion.beamOn(rig.motion, now)
				and Motion.beamOn(rig.motion, now - Config.Hazards.BeamLeniency)
			then
				sendBack(player, run, "spotted", Config.Retakes.CountFalls)
				return
			end
		end
	end
	if stage.scareZone and not run.scaresPlayed[stage.index] and Zone.contains(stage.scareZone, pos) then
		run.scaresPlayed[stage.index] = true
		RoundService.ScareZoneEntered:Fire(player, stage.index)
	end
	if stage.exitZone and Zone.contains(stage.exitZone, pos) then
		clearStage(player, run)
	elseif stage.exits then
		checkExits(player, run, stage, pos)
	end
end

local function zoneLoop()
	while true do
		task.wait(Config.Zones.CheckInterval)
		for player, run in runs do
			if run.phase == "Running" and not run.respawning and player.Parent then
				local ok, err = pcall(watchPlayer, player, run)
				if not ok then
					warn("[RoundService] zone check failed: " .. tostring(err))
				end
			end
		end
	end
end

-- ── Players & characters ──────────────────────────────────────────────────────────────────

local function onCharacterAdded(player: Player, character: Model)
	applyMovement(character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid.Died:Connect(function()
			local run = runs[player]
			if run and run.phase == "Running" then
				sendBack(player, run, "died", Config.Retakes.CountDeaths)
			end
		end)
	end
	local run = runs[player]
	if run and run.phase == "Running" then
		-- Respawned mid-run (reset / died): wait for the root, then return to the checkpoint.
		if character:WaitForChild("HumanoidRootPart", 10) then
			task.defer(respawnAtCheckpoint, player)
		end
	end
end

local function onPlayerAdded(player: Player)
	runs[player] = newRun()
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

local function onPlayerRemoving(player: Player)
	local run = runs[player]
	if run and run.phase == "Running" then
		local progress = CheckpointService.get(player)
		Analytics.track("quit_stage", player, {
			stage = if progress then progress.stage else 0,
			retakes = if progress then progress.retakes else 0,
			reason = "left_game",
		})
	end
	if run and run.party then
		local party = run.party :: Party
		local i = table.find(party.members, player)
		if i then
			table.remove(party.members, i)
		end
	end
	if gathering then
		local i = table.find(gathering.members, player)
		if i then
			table.remove(gathering.members, i)
		end
	end
	runs[player] = nil
	MannequinService.despawn(player)
end

-- ── Public API ────────────────────────────────────────────────────────────────────────────

function RoundService.getPhase(player: Player): Types.RunPhase?
	local run = runs[player]
	return if run then run.phase else nil
end

function RoundService.setTicketEnricher(fn: TicketEnricher)
	ticketEnricher = fn
end

local function configureCharacters()
	StarterPlayer.CharacterUseJumpPower = true
	StarterPlayer.CharacterJumpPower = Config.Movement.JumpPower
	StarterPlayer.CharacterWalkSpeed = Config.Movement.WalkSpeed
	Workspace.Gravity = Config.Movement.Gravity
	Players.RespawnTime = Config.Movement.RespawnTime
end

local function connectRemotes()
	RemoteGuard.connect("RequestStart", RemoteGuard.args(), function(player)
		RoundService.startRun(player)
	end)
	RemoteGuard.connect("RequestMode", RemoteGuard.args("string"), RoundService.requestMode)
	RemoteGuard.connect("RequestLobby", RemoteGuard.args(), function(player)
		local run = runs[player]
		if run and run.phase ~= "Lobby" then
			RoundService.returnToLobby(player, "requested")
		end
	end)
end

function RoundService.init(builtMap: Types.MapInfo & { startPrompt: ProximityPrompt })
	map = builtMap
	configureCharacters()
	connectRemotes()

	builtMap.startPrompt.Triggered:Connect(function(player)
		RoundService.startRun(player)
	end)
	MannequinService.Caught:Connect(function(player)
		local run = runs[player]
		if run then
			sendBack(player, run, "caught", Config.Retakes.CountCatches)
		end
	end)
	MannequinService.DoorOutran:Connect(function(player)
		local run = runs[player]
		if run then
			run.doorsOutran += 1
		end
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	task.spawn(zoneLoop)
end

return RoundService
