--!strict
--[[
	JumpAssist (client) — forgiving parkour for every input (keyboard, touch, gamepad):

	  Coyote time      jump a beat after running off an edge (shared/JumpAssist rules)
	  Jump buffering   jump pressed just before landing fires on landing
	  Ledge forgiveness  falling just short of a platform's lip pops you up onto it
	  Touch camera     on phones/tablets: a closer zoom range and a steadier field of view

	All of it only shapes the local character's physics, which Roblox already trusts to the
	client. The server still judges catches, falls, exits and times.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Rules = require(ReplicatedStorage.Shared.JumpAssist)
local ClientState = require(script.Parent.Parent.ClientState)

local JumpAssist = {}

local player = Players.LocalPlayer
local state = Rules.new()

local function parts(): (Humanoid?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return humanoid, if root and root:IsA("BasePart") then root else nil
end

local function forceJump(humanoid: Humanoid)
	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
end

--- Falling just short of a ledge in the direction you're moving: step up onto it.
local function ledgeForgive(humanoid: Humanoid, root: BasePart)
	local velocity = root.AssemblyLinearVelocity
	local move = humanoid.MoveDirection
	if velocity.Y > 1 or move.Magnitude < 0.5 then
		return
	end
	local feet = root.Position - Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Instance }
	local reach = Config.Feel.LedgeReach + root.Size.X / 2
	-- Look down onto the space just ahead, from a little above where the ledge top could be.
	local probe = feet + move.Unit * reach + Vector3.new(0, Config.Feel.LedgeLift + 0.2, 0)
	local hit = Workspace:Raycast(probe, Vector3.new(0, -(Config.Feel.LedgeLift + 0.4), 0), params)
	if not hit or not hit.Instance.CanCollide or hit.Normal.Y < 0.9 then
		return
	end
	local lift = hit.Position.Y - feet.Y
	if lift > 0.05 and lift <= Config.Feel.LedgeLift then
		root.CFrame += Vector3.new(0, lift + 0.05, 0) + move.Unit * 0.4
		root.AssemblyLinearVelocity = Vector3.new(velocity.X, 0, velocity.Z)
	end
end

local function onStep()
	local humanoid, root = parts()
	if not humanoid or not root or humanoid.Health <= 0 then
		return
	end
	local now = os.clock()
	local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
	if Rules.setGrounded(state, Config.Feel, grounded, now) then
		forceJump(humanoid)
	end
	if not grounded and ClientState.phase == "Running" then
		local s = humanoid:GetState()
		if s == Enum.HumanoidStateType.Freefall then
			ledgeForgive(humanoid, root)
		end
	end
end

local function onJumpRequest()
	local humanoid = parts()
	if not humanoid or humanoid.Health <= 0 or humanoid.JumpPower <= 0 then
		return
	end
	if Rules.press(state, Config.Feel, os.clock()) == "Coyote" then
		forceJump(humanoid)
	end
end

local function applyTouchCamera()
	if not UserInputService.TouchEnabled or UserInputService.KeyboardEnabled then
		return
	end
	local cam = Config.Feel.TouchCamera
	player.CameraMinZoomDistance = cam.MinZoom
	player.CameraMaxZoomDistance = cam.MaxZoom
	local camera = Workspace.CurrentCamera
	if camera then
		camera.FieldOfView = cam.FieldOfView
	end
end

local function watchHumanoid(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	local stateChanged = humanoid and (humanoid :: any).StateChanged
	if humanoid and humanoid:IsA("Humanoid") and stateChanged then
		stateChanged:Connect(function(_, new)
			if new == Enum.HumanoidStateType.Jumping then
				Rules.didJump(state)
			end
		end)
	end
	state = Rules.new()
end

function JumpAssist.init()
	-- (The offline test client has no JumpRequest; Roblox always does.)
	local jumpRequest = (UserInputService :: any).JumpRequest
	if jumpRequest then
		jumpRequest:Connect(onJumpRequest)
	end
	RunService.Heartbeat:Connect(onStep)
	player.CharacterAdded:Connect(watchHumanoid)
	if player.Character then
		task.spawn(watchHumanoid, player.Character)
	end
	applyTouchCamera()
end

return JumpAssist
