--!strict
--[[
	RoundService — owns each player's run: Lobby → Running (stages 1..N) → Finished.

	It is the orchestrator: it teleports, counts retakes (via CheckpointService), spawns and
	resets the mannequin, and runs one 10 Hz zone watcher for every running player (stage exits,
	painted-door triggers, scare zones, kill line, stage-3 exits). Other services hook in through
	the RunFinished / StageEntered signals so this file never grows their logic.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local Clock = require(ReplicatedStorage.Shared.Clock)
local Config = require(ReplicatedStorage.Shared.Config)
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
}

type Run = {
	phase: Types.RunPhase,
	-- workspace:GetServerTimeNow() at start (shared clock for the HUD timer).
	startedAt: number,
	clockStartedAt: number,
	realExit: string,
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
		realExit = "Left",
		scaresPlayed = {},
		respawning = false,
		lastStartRequest = -math.huge,
		lastFakeExitAt = -math.huge,
		verified = true,
		doorsOutran = 0,
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
		realExit = if stage == Config.Game.StageCount then run.realExit else nil,
		runStartedAt = run.startedAt,
		retakes = if progress then progress.retakes else 0,
	}
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
	CheckpointService.teleportToEntrance(player)
	MannequinService.reset(player, stage)
	run.respawning = false
	Remotes.get("StageStarted"):FireClient(player, stageStartInfo(player, run, isRetake))
	RoundService.StageEntered:Fire(player, stage.index, isRetake)
	if not isRetake then
		Analytics.track("stage_started", player, { stage = stage.index })
	end
end

function RoundService.startRun(player: Player): boolean
	local run = runs[player]
	if not run or run.phase == "Running" then
		return false
	end
	local now = Clock.now()
	if now - run.lastStartRequest < Config.Run.StartCooldown then
		return false
	end
	run.lastStartRequest = now
	run.phase = "Running"
	run.startedAt = Clock.serverNow()
	run.clockStartedAt = now
	run.realExit = if math.random() < 0.5 then "Left" else "Right"
	run.verified = true
	run.doorsOutran = 0
	if Config.Scares.PlayOncePerRun then
		table.clear(run.scaresPlayed)
	end
	CheckpointService.begin(player)
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

--- Shared path for anything that sends you back to the stage entrance.
local function sendBack(player: Player, run: Run, reason: "caught" | "fell" | "died", countIt: boolean)
	if run.phase ~= "Running" or run.respawning then
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
	end
	if reason ~= "died" then
		task.delay(Config.Catch.RespawnDelay, respawnAtCheckpoint, player)
	end
end

local function finish(player: Player, run: Run)
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
	}
	run.phase = "Finished"
	MannequinService.despawn(player)
	Analytics.track("finished", player, { time = elapsed, retakes = progress.retakes, verified = verified })

	local ticket: Types.TicketData = {
		escapeTime = elapsed,
		retakes = progress.retakes,
		bestTime = nil,
		isNewBest = false,
		titleEarned = if progress.retakes == 0 then Config.Titles.OpeningNight.DisplayName else nil,
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
	CheckpointService.teleport(player, map.lobbySpawn)
	Remotes.get("RunFinished"):FireClient(player, ticket)
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
	if CheckpointService.advance(player) then
		enterStage(player, run, false)
	else
		finish(player, run)
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
	MannequinService.despawn(player)
	CheckpointService.clear(player)
	CheckpointService.teleport(player, map.lobbySpawn)
	Remotes.get("ReturnedToLobby"):FireClient(player)
end

-- ── Zone watcher (10 Hz) ──────────────────────────────────────────────────────────────────

local function checkExits3(player: Player, run: Run, stage: Types.StageInfo, pos: Vector3)
	for _, side in { "Left", "Right" } do
		local zoneInfo = if side == "Left" then stage.exitLeftZone else stage.exitRightZone
		if zoneInfo and Zone.contains(zoneInfo, pos) then
			if side == run.realExit then
				clearStage(player, run)
			elseif Clock.now() - run.lastFakeExitAt > 2 then
				run.lastFakeExitAt = Clock.now()
				Remotes.get("FakeExit"):FireClient(player)
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
	if pos.Y < stage.killY then
		sendBack(player, run, "fell", Config.Retakes.CountFalls)
		return
	end
	for _, door in stage.doors do
		if Zone.contains({ cframe = door.triggerCFrame, size = door.triggerSize }, pos) then
			MannequinService.tryDoor(player, door)
		end
	end
	if stage.scareZone and not run.scaresPlayed[stage.index] and Zone.contains(stage.scareZone, pos) then
		run.scaresPlayed[stage.index] = true
		RoundService.ScareZoneEntered:Fire(player, stage.index)
	end
	if stage.exitZone and Zone.contains(stage.exitZone, pos) then
		clearStage(player, run)
	elseif stage.exitLeftZone then
		checkExits3(player, run, stage, pos)
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
