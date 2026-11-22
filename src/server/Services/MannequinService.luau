--!strict
--[[
	MannequinService — the server-side mannequins of every running player.

	Each player has a cast that depends on the stage's behaviours (Config.Behaviours):
	  Main        the Copycat, always (takes painted doors on stages that have them)
	  Understudy* extra copies with longer delays (stages with "Understudy")
	  Mirror      a reflection ahead of the player (stages with "Mirror" and a Config.Mirrors entry)

	A single Heartbeat connection drives every mannequin (connected only while at least one
	exists). Each tick reads the owner's HumanoidRootPart CFrame and movement pose (nil while
	the character is missing/dead) and feeds every mannequin in the cast.

	Other systems talk to it through functions (spawn/reset/despawn/tryDoor/holdForScare/bow/
	setLooking) and listen to its signals (Caught, DoorOutran). It never touches run state.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Clock = require(ReplicatedStorage.Shared.Clock)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Types = require(ReplicatedStorage.Shared.Types)
local Mannequin = require(script.Parent.Mannequin.Mannequin)
local RemoteGuard = require(script.Parent.RemoteGuard)

local MannequinService = {}

MannequinService.Caught = Signal.new() :: Signal.Signal<Player>
MannequinService.DoorOutran = Signal.new() :: Signal.Signal<Player, string>
-- A mannequin lunged because the player stared too long. (player)
MannequinService.Stared = Signal.new() :: Signal.Signal<Player>
-- The player's reflection cracked (they ran past it). (player)
MannequinService.MirrorCracked = Signal.new() :: Signal.Signal<Player>

-- Cosmetic colour for a player's Copycat (set by CosmeticsService).
local skinResolver: ((Player) -> Color3?)? = nil

type Cast = { [string]: Mannequin.Mannequin } -- key: "Main", "Understudy1", …, "Mirror"

local casts: { [Player]: Cast } = {}
-- Endless: a per-player Copycat delay (nil = Config.Mannequin.Delay).
local copycatDelay: { [Player]: number } = {}
local heartbeat: RBXScriptConnection? = nil
local folder: Folder

local function rootOf(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	if not character then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return nil, nil
	end
	return root, humanoid
end

--- The player's movement pose, replayed by their mannequins ("pose copy").
local function poseTag(root: BasePart, humanoid: Humanoid): string
	local state = humanoid:GetState()
	if state == Enum.HumanoidStateType.Jumping then
		return "Jump"
	elseif state == Enum.HumanoidStateType.Freefall then
		return if root.AssemblyLinearVelocity.Y > 2 then "Jump" else "Fall"
	elseif state == Enum.HumanoidStateType.Climbing then
		return "Climb"
	end
	local speed = (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
	return if speed > 1 then "Run" else "Idle"
end

local function step(dt: number)
	local now = Clock.now()
	for player, cast in casts do
		-- A player can leave between frames; PlayerRemoving cleans up, this just guards.
		if player.Parent then
			local root, humanoid = rootOf(player)
			local cf = if root then root.CFrame else nil
			local tag: string? = nil
			if root and humanoid then
				local ok, result = pcall(poseTag, root, humanoid)
				tag = if ok then result else nil
			end
			for _, mannequin in cast do
				mannequin:update(now, dt, cf, tag)
			end
		end
	end
end

local function ensureLoop()
	if next(casts) and not heartbeat then
		heartbeat = RunService.Heartbeat:Connect(step)
	elseif not next(casts) and heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil
	end
end

local function eventsFor(player: Player): Mannequin.Events
	return {
		caught = function()
			MannequinService.Caught:Fire(player)
		end,
		doorWarning = function(doorId: string, seconds: number)
			Remotes.get("DoorWarning"):FireClient(player, doorId, seconds)
		end,
		doorOpened = function(doorId: string)
			Remotes.get("DoorOpened"):FireClient(player, doorId)
		end,
		doorOutran = function(doorId: string)
			Remotes.get("DoorOutran"):FireClient(player, doorId)
			MannequinService.DoorOutran:Fire(player, doorId)
		end,
		stare = function(name: string)
			Remotes.get("StareLunge"):FireClient(player, name)
			MannequinService.Stared:Fire(player)
		end,
		mirrorCracked = function(name: string)
			Remotes.get("MirrorCracked"):FireClient(player, name)
			MannequinService.MirrorCracked:Fire(player)
		end,
	}
end

--- Which cast members a stage needs: key → options.
function MannequinService.castFor(
	stageIndex: number,
	hasMirrorPath: boolean,
	player: Player?
): { [string]: Mannequin.Options }
	local behaviours = Config.Behaviours[stageIndex] or { "Copycat" }
	local wanted: { [string]: Mannequin.Options } = { Main = { role = "Copycat" } }
	if player and copycatDelay[player] then
		wanted.Main.delay = copycatDelay[player]
	end
	if table.find(behaviours, "Understudy") then
		local delays = Config.Mannequin.UnderstudyDelaysByStage[stageIndex] or Config.Mannequin.UnderstudyDelays
		for i, delay in delays do
			wanted["Understudy" .. i] = { role = "Understudy", delay = delay }
		end
	end
	if table.find(behaviours, "Mirror") and Config.Mirrors[stageIndex] and hasMirrorPath then
		wanted.Mirror = { role = "Mirror" }
	end
	return wanted
end

local function nameFor(player: Player, key: string): string
	return if key == "Main" then "Mannequin_" .. player.UserId else "Mannequin_" .. player.UserId .. "_" .. key
end

--- Brings the player's cast in line with `stage` and sends everyone home.
local function prepare(player: Player, stage: Types.StageInfo)
	local cast = casts[player]
	if not cast then
		cast = {}
		casts[player] = cast
	end
	local wanted = MannequinService.castFor(stage.index, stage.routePath ~= nil, player)
	for key, mannequin in cast do
		if not wanted[key] then
			cast[key] = nil
			mannequin:destroy()
		end
	end
	local now = Clock.now()
	for key, options in wanted do
		local mannequin = cast[key]
		if not mannequin then
			mannequin = Mannequin.new(nameFor(player, key), player.UserId, folder, eventsFor(player), options)
			cast[key] = mannequin
		end
		mannequin:setDelay(options.delay)
		mannequin:reset(stage, now)
	end
	MannequinService.refreshSkin(player)
	ensureLoop()
end

local function onLookState(player: Player, name: string)
	local cast = casts[player]
	if not cast then
		return
	end
	local root = rootOf(player)
	for _, mannequin in cast do
		local looking = name ~= "" and mannequin:name() == name
		-- A client can only freeze its own mannequins, and only ones near it.
		if
			looking and (not root or (root.Position - mannequin.position).Magnitude > Config.Mannequin.Look.ServerRange)
		then
			looking = false
		end
		mannequin:setLooking(looking)
	end
end

function MannequinService.init()
	local existing = Workspace:FindFirstChild("Mannequins")
	if existing then
		existing:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "Mannequins"
	folder.Parent = Workspace
	Players.PlayerRemoving:Connect(function(player)
		MannequinService.despawn(player)
	end)
	RemoteGuard.connect("LookState", RemoteGuard.args("string"), onLookState)
end

--- Creates (or reuses) the player's cast for `stage` and sends it home.
function MannequinService.spawn(player: Player, stage: Types.StageInfo)
	prepare(player, stage)
end

--- Clears the trails, moves the cast home and starts the respawn grace period.
function MannequinService.reset(player: Player, stage: Types.StageInfo)
	prepare(player, stage)
end

function MannequinService.setSkinResolver(resolver: (Player) -> Color3?)
	skinResolver = resolver
end

--- Repaints the player's Copycat with their equipped mannequin skin.
function MannequinService.refreshSkin(player: Player)
	local cast = casts[player]
	local main = cast and cast.Main
	if main and skinResolver then
		local ok, color = pcall(skinResolver, player)
		main:applySkin(if ok then color else nil)
	end
end

--- Endless: the Copycat's delay for this player (nil restores the default). Applies on the
--- next spawn/reset.
function MannequinService.setCopycatDelay(player: Player, delay: number?)
	copycatDelay[player] = delay
end

function MannequinService.despawn(player: Player)
	copycatDelay[player] = nil
	local cast = casts[player]
	if cast then
		casts[player] = nil
		for _, mannequin in cast do
			mannequin:destroy()
		end
	end
	ensureLoop()
end

function MannequinService.tryDoor(player: Player, door: Types.DoorInfo): boolean
	local cast = casts[player]
	local main = cast and cast.Main
	return main ~= nil and main:tryDoor(door, Clock.now())
end

function MannequinService.holdForScare(player: Player, seconds: number)
	local cast = casts[player]
	if cast then
		for _, mannequin in cast do
			mannequin:holdForScare(seconds, Clock.now())
		end
	end
end

function MannequinService.bow(player: Player, delay: number, seconds: number)
	local cast = casts[player]
	local main = cast and cast.Main
	if main then
		main:bow(delay, seconds, Clock.now())
	end
end

--- The look report, as if it came from the client (tests and tooling).
function MannequinService.setLooking(player: Player, name: string)
	onLookState(player, name)
end

function MannequinService.has(player: Player): boolean
	return casts[player] ~= nil
end

--- The player's cast (read-only use: tests, debug overlay).
function MannequinService.castOf(player: Player): Cast?
	return casts[player]
end

return MannequinService
