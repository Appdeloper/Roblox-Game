--!strict
--[[
	MannequinService — one server-side mannequin per running player.

	A single Heartbeat connection drives every mannequin (connected only while at least one
	exists). Each tick reads the owner's HumanoidRootPart CFrame (nil if the character is
	missing/dead), feeds it to that player's Mannequin, and relays door events to the owner only.

	Other systems talk to it through functions (spawn/reset/despawn/tryDoor/holdForScare/bow)
	and listen to its signals (Caught, DoorOutran). It never touches run state itself.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Types = require(ReplicatedStorage.Shared.Types)
local Mannequin = require(script.Parent.Mannequin.Mannequin)

local MannequinService = {}

MannequinService.Caught = Signal.new() :: Signal.Signal<Player>
MannequinService.DoorOutran = Signal.new() :: Signal.Signal<Player, string>

local active: { [Player]: Mannequin.Mannequin } = {}
local heartbeat: RBXScriptConnection? = nil
local folder: Folder

local function rootCFrame(player: Player): CFrame?
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return nil
	end
	return root.CFrame
end

local function step(dt: number)
	local now = os.clock()
	for player, mannequin in active do
		-- A player can leave between frames; PlayerRemoving cleans up, this just guards.
		if player.Parent then
			mannequin:update(now, dt, rootCFrame(player))
		end
	end
end

local function ensureLoop()
	if next(active) and not heartbeat then
		heartbeat = RunService.Heartbeat:Connect(step)
	elseif not next(active) and heartbeat then
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
	}
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
end

--- Creates (or reuses) the player's mannequin and sends it home for `stage`.
function MannequinService.spawn(player: Player, stage: Types.StageInfo)
	local mannequin = active[player]
	if not mannequin then
		mannequin = Mannequin.new("Mannequin_" .. player.UserId, player.UserId, folder, eventsFor(player))
		active[player] = mannequin
	end
	mannequin:reset(stage, os.clock())
	ensureLoop()
end

--- Clears the trail, moves the mannequin home and starts the respawn grace period.
function MannequinService.reset(player: Player, stage: Types.StageInfo)
	local mannequin = active[player]
	if mannequin then
		mannequin:reset(stage, os.clock())
	else
		MannequinService.spawn(player, stage)
	end
end

function MannequinService.despawn(player: Player)
	local mannequin = active[player]
	if mannequin then
		active[player] = nil
		mannequin:destroy()
	end
	ensureLoop()
end

function MannequinService.tryDoor(player: Player, door: Types.DoorInfo): boolean
	local mannequin = active[player]
	return mannequin ~= nil and mannequin:tryDoor(door, os.clock())
end

function MannequinService.holdForScare(player: Player, seconds: number)
	local mannequin = active[player]
	if mannequin then
		mannequin:holdForScare(seconds, os.clock())
	end
end

function MannequinService.bow(player: Player, delay: number, seconds: number)
	local mannequin = active[player]
	if mannequin then
		mannequin:bow(delay, seconds, os.clock())
	end
end

function MannequinService.has(player: Player): boolean
	return active[player] ~= nil
end

return MannequinService
