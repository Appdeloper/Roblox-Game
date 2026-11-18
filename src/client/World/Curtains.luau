--!strict
--[[
	Curtains — every part tagged "Curtain" sways from its top edge like fabric in a draughty
	old theatre, and ripples when someone runs past.

	Cost: the idle sway is a single looping TweenService tween per strip, driven in C++ with
	no Lua running per frame. A ripple is one short tween on the handful of strips nearest
	the player, after which the idle sway resumes. Nothing here polls.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local Curtains = {}

--- How many strips have been kicked by a passing player. Diagnostic only.
Curtains.rippled = 0

type Entry = {
	part: BasePart,
	pivot: CFrame,
	offset: CFrame,
	-- Rotate about Z for strips that are thin along X, otherwise about X.
	rollAxis: boolean,
	idle: Tween?,
	rippleUntil: number,
}

local entries: { [BasePart]: Entry } = {}

local function posed(entry: Entry, degrees: number): CFrame
	local angle = math.rad(degrees)
	local rotation = if entry.rollAxis then CFrame.Angles(0, 0, angle) else CFrame.Angles(angle, 0, 0)
	return entry.pivot * rotation * entry.offset
end

--- Looping sway: hangs at -amplitude and tweens to +amplitude, reversing forever.
local function startIdle(entry: Entry)
	if entry.idle then
		entry.idle:Cancel()
	end
	local amplitude = Config.Effects.CurtainSwayDegrees
	entry.part.CFrame = posed(entry, -amplitude)
	local info = TweenInfo.new(
		Config.Effects.CurtainSwaySeconds,
		Enum.EasingStyle.Sine,
		Enum.EasingDirection.InOut,
		-1,
		true,
		math.random() * Config.Effects.CurtainSwaySeconds
	)
	local tween = TweenService:Create(entry.part, info, { CFrame = posed(entry, amplitude) })
	entry.idle = tween
	tween:Play()
end

local function register(part: Instance)
	if not part:IsA("BasePart") or entries[part] then
		return
	end
	local base = part.CFrame
	local pivot = base * CFrame.new(0, part.Size.Y / 2, 0)
	local entry: Entry = {
		part = part,
		pivot = pivot,
		offset = pivot:ToObjectSpace(base),
		rollAxis = part.Size.X < part.Size.Z,
		idle = nil,
		rippleUntil = 0,
	}
	entries[part] = entry
	startIdle(entry)
end

function Curtains.init()
	for _, part in CollectionService:GetTagged("Curtain") do
		register(part)
	end
	CollectionService:GetInstanceAddedSignal("Curtain"):Connect(register)
	CollectionService:GetInstanceRemovedSignal("Curtain"):Connect(function(part)
		local entry = entries[part :: BasePart]
		if entry then
			if entry.idle then
				entry.idle:Cancel()
			end
			entries[part :: BasePart] = nil
		end
	end)
end

--- Fabric kicks as something rushes past. Only strips within `radius` react, and only
--- while they are not already rippling, so running along a wall stays cheap.
function Curtains.ripple(position: Vector3, radius: number, strength: number)
	local now = os.clock()
	local amplitude = Config.Effects.CurtainSwayDegrees * (3 + 4 * strength)
	for _, entry in entries do
		if now >= entry.rippleUntil and entry.part.Parent then
			local distance = (entry.part.Position - position).Magnitude
			if distance <= radius then
				entry.rippleUntil = now + 1.1
				Curtains.rippled += 1
				if entry.idle then
					entry.idle:Cancel()
				end
				-- Falls off with distance so the kick travels along the row.
				local falloff = 1 - distance / radius
				local info = TweenInfo.new(0.28, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 1, true)
				local tween = TweenService:Create(entry.part, info, { CFrame = posed(entry, amplitude * falloff) })
				entry.idle = tween
				tween:Play()
				tween.Completed:Once(function()
					if entries[entry.part] then
						startIdle(entry)
					end
				end)
			end
		end
	end
end

return Curtains
