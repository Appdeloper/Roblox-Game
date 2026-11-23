--!strict
--[[
	Movers — animates the stage 4–6 hazards on this client, from server time (shared/Motion),
	so every player sees the same swing at the same moment and the server's beam judgement
	matches what's on screen.

	  Pendulum   sandbag on a rope swinging across the catwalk (solid on this client)
	  Slider     shelf sliding across the aisle (solid on this client)
	  Spinner    light rig turning; its beam lands on the painted gate mark (the server judges
	             hits; the mark glows while the beam is on it and flickers just before)
	  PulseProp  crates shrinking and growing (always back to full size: jump then)
	  Costumes   ride the conveyor's rail at the belt's speed and wrap around

	Only movers in your current stage are animated (others are parked), to keep phones fast.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Motion = require(ReplicatedStorage.Shared.Motion)
local ClientState = require(script.Parent.Parent.ClientState)

local Movers = {}

type Mover = {
	model: Model,
	kind: string,
	spec: Motion.Spec,
	axis: Vector3,
	pivot: Vector3,
	parts: { [BasePart]: CFrame }, -- rest CFrames
	stage: number?,
	mark: BasePart?,
}

type Pulse = { part: BasePart, spec: Motion.Spec, base: Vector3, rest: CFrame, stage: number? }
type Costume = { part: BasePart, head: BasePart?, rest: CFrame, headRest: CFrame?, min: number, max: number }

local movers: { Mover } = {}
local pulses: { Pulse } = {}
local costumes: { Costume } = {}
local conveyorSpeed = 0

--- Rebuilds a Motion spec from the attributes StageBuilder wrote.
function Movers.specOf(instance: Instance): Motion.Spec
	local function num(name: string): number?
		local v = instance:GetAttribute(name)
		return if type(v) == "number" then v else nil
	end
	return {
		period = num("Period") or 4,
		phase = num("Phase"),
		amplitude = num("Amplitude"),
		min = num("Min"),
		hold = num("Hold"),
		aim = num("Aim"),
		halfWidth = num("HalfWidth"),
	}
end

local function addMover(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local pivot = model:GetAttribute("Pivot")
	if typeof(pivot) ~= "Vector3" then
		return
	end
	local parts: { [BasePart]: CFrame } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			parts[d] = d.CFrame
			if d:GetAttribute("Solid") then
				-- Built non-colliding on the server; it pushes only this client's character.
				d.CanCollide = true
			end
		end
	end
	local mark = model:FindFirstChild("GateMark")
	local stage = model:GetAttribute("Stage")
	table.insert(movers, {
		model = model,
		kind = tostring(model:GetAttribute("Kind")),
		spec = Movers.specOf(model),
		axis = if model:GetAttribute("Axis") == "Z" then Vector3.zAxis else Vector3.xAxis,
		pivot = pivot,
		parts = parts,
		stage = if type(stage) == "number" then stage else nil,
		mark = if mark and mark:IsA("BasePart") then mark else nil,
	})
end

local function addPulse(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	local base = part:GetAttribute("BaseSize")
	local stage = part:GetAttribute("Stage")
	table.insert(pulses, {
		part = part,
		spec = Movers.specOf(part),
		base = if typeof(base) == "Vector3" then base else part.Size,
		rest = part.CFrame,
		stage = if type(stage) == "number" then stage else nil,
	})
end

local function addCostume(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	local head: BasePart? = nil
	for _, h in CollectionService:GetTagged("CostumeHead") do
		if h:IsA("BasePart") and (h.Position - part.Position).Magnitude < 3 then
			head = h
		end
	end
	local min, max = part:GetAttribute("RailMin"), part:GetAttribute("RailMax")
	table.insert(costumes, {
		part = part,
		head = head,
		rest = part.CFrame,
		headRest = if head then head.CFrame else nil,
		min = if type(min) == "number" then min else part.Position.X - 10,
		max = if type(max) == "number" then max else part.Position.X + 10,
	})
end

local function animateMover(m: Mover, t: number)
	if m.kind == "Pendulum" then
		local angle = math.rad(Motion.pendulum(m.spec, t))
		-- Swing across `axis`: rotate about the perpendicular horizontal axis through the hinge.
		local hingeAxis = if m.axis == Vector3.zAxis then Vector3.xAxis else Vector3.zAxis
		local swing = CFrame.new(m.pivot) * CFrame.fromAxisAngle(hingeAxis, -angle) * CFrame.new(-m.pivot)
		for part, rest in m.parts do
			part.CFrame = swing * rest
		end
	elseif m.kind == "Slider" then
		local offset = m.axis * Motion.slide(m.spec, t)
		for part, rest in m.parts do
			part.CFrame = rest + offset
		end
	elseif m.kind == "Spinner" then
		local aim = m.spec.aim or 0
		local turn = math.rad(Motion.spin(m.spec, t) - aim)
		local spin = CFrame.new(m.pivot) * CFrame.Angles(0, turn, 0) * CFrame.new(-m.pivot)
		for part, rest in m.parts do
			if part ~= m.mark then
				part.CFrame = spin * rest
			end
		end
		if m.mark then
			local on = Motion.beamOn(m.spec, t)
			local eta = Motion.beamEta(m.spec, t)
			-- Glows while the beam is on it; flickers in the last half-second as a warning.
			local warn = not on and eta < 0.5 and (math.floor(t * 12) % 2 == 0)
			m.mark.Transparency = if on or warn then 0 else 0.65
		end
	end
end

local function animatePulse(p: Pulse, t: number)
	local s = Motion.pulse(p.spec, t)
	-- Shrink in X/Z only, keeping the top surface where the player expects it.
	p.part.Size = Vector3.new(p.base.X * s, p.base.Y, p.base.Z * s)
	p.part.CFrame = p.rest
end

local function animateCostumes(t: number)
	if conveyorSpeed == 0 then
		return
	end
	for _, c in costumes do
		local span = c.max - c.min
		local x = c.rest.Position.X + conveyorSpeed * t
		x = c.min + ((x - c.min) % span)
		local offset = Vector3.new(x - c.rest.Position.X, 0, 0)
		c.part.CFrame = c.rest + offset
		if c.head and c.headRest then
			-- During the stage 5 scare the heads turn to face you (Scares sets the attribute).
			local turn = c.head:GetAttribute("Turn")
			local yaw = if type(turn) == "number" then turn else 0
			c.head.CFrame = (c.headRest + offset) * CFrame.Angles(0, yaw, 0)
		end
	end
end

local function step()
	local stage = ClientState.stage
	if stage < 4 then
		return
	end
	local t = Workspace:GetServerTimeNow()
	for _, m in movers do
		if m.stage == stage then
			animateMover(m, t)
		end
	end
	for _, p in pulses do
		if p.stage == stage then
			animatePulse(p, t)
		end
	end
	if stage == 5 then
		animateCostumes(t)
	end
end

function Movers.init()
	for _, model in CollectionService:GetTagged("Mover") do
		addMover(model)
	end
	for _, part in CollectionService:GetTagged("PulseProp") do
		addPulse(part)
	end
	for _, belt in CollectionService:GetTagged("Conveyor") do
		local v = belt:GetAttribute("ConveyorVelocity")
		if typeof(v) == "Vector3" then
			conveyorSpeed = v.X
		end
	end
	for _, part in CollectionService:GetTagged("ConveyorCostume") do
		addCostume(part)
	end
	CollectionService:GetInstanceAddedSignal("Mover"):Connect(addMover)
	CollectionService:GetInstanceAddedSignal("PulseProp"):Connect(addPulse)
	CollectionService:GetInstanceAddedSignal("ConveyorCostume"):Connect(addCostume)
	RunService.Heartbeat:Connect(step)
end

return Movers
