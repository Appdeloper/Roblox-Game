--!strict
--[[
	Mannequin — one player's chaser. A small state machine driven by `update(now, dt, playerCF)`
	(the clock is injected, so tests can run it deterministically).

	States
	  Idle      standing at the stage's home spot; waits for the player to leave the entrance.
	  Warmup    recording the player's trail; waits until a full Delay of history exists.
	  Trailing  replays the trail `Delay` seconds late (catches up / drifts back smoothly).
	  Shortcut  painted-door shortcut: Approach → Path (hidden) → Hold (warning) → StepOut.
	  Ambush    stepped out of the door; rejoins the trail as soon as it's fair to.

	Movement: the root is unanchored and server-owned; AlignPosition/AlignOrientation with
	RigidityEnabled pull it to the target, so clients get smooth, interpolated physics
	replication instead of 20 Hz anchored teleports.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local MannequinRig = require(ReplicatedStorage.Shared.MannequinRig)
local Types = require(ReplicatedStorage.Shared.Types)
local Trail = require(script.Parent.Trail)

export type State = "Idle" | "Warmup" | "Trailing" | "Shortcut" | "Ambush"
type Phase = "Approach" | "Path" | "Hold" | "StepOut"

export type Events = {
	caught: () -> (),
	doorWarning: (doorId: string, seconds: number) -> (),
	doorOpened: (doorId: string) -> (),
	doorOutran: (doorId: string) -> (),
}

type Shortcut = {
	door: Types.DoorInfo,
	triggeredAt: number,
	phase: Phase,
	waypoint: number,
}

local Mannequin = {}
Mannequin.__index = Mannequin

export type Mannequin = typeof(setmetatable(
	{} :: {
		rig: MannequinRig.Rig,
		align: AlignPosition,
		orient: AlignOrientation,
		events: Events,
		stage: Types.StageInfo?,
		state: State,
		trail: Trail.Trail,
		nextSampleAt: number,
		cursor: number,
		emergeStartedAt: number,
		graceUntil: number,
		pausedUntil: number,
		bowFrom: number,
		bowUntil: number,
		pose: string,
		shortcut: Shortcut?,
		ambushUntil: number,
		doorsUsed: { [string]: boolean },
		position: Vector3,
		facing: Vector3,
		caughtPending: boolean,
	},
	Mannequin
))

local SAMPLE_INTERVAL = 1 / Config.Mannequin.SampleRate
local ARRIVE_EPSILON = 0.05

--- Yaw-only copy of a CFrame (the mannequin never tilts with jumps).
local function flatten(cf: CFrame): CFrame
	local look = cf.LookVector * Vector3.new(1, 0, 1)
	if look.Magnitude < 1e-3 then
		look = Vector3.new(0, 0, -1)
	end
	return CFrame.lookAt(cf.Position, cf.Position + look.Unit)
end

local function flatDirection(from: Vector3, to: Vector3, fallback: Vector3): Vector3
	local d = (to - from) * Vector3.new(1, 0, 1)
	if d.Magnitude < 1e-3 then
		return fallback
	end
	return d.Unit
end

function Mannequin.new(name: string, ownerUserId: number, parent: Instance, events: Events): Mannequin
	local rig = MannequinRig.build(name, CFrame.new())
	rig.model:SetAttribute("OwnerUserId", ownerUserId)

	local attachment = Instance.new("Attachment")
	attachment.Name = "AlignAttachment"
	attachment.Parent = rig.root

	local align = Instance.new("AlignPosition")
	align.Mode = Enum.PositionAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.RigidityEnabled = true
	align.Parent = rig.root

	local orient = Instance.new("AlignOrientation")
	orient.Mode = Enum.OrientationAlignmentMode.OneAttachment
	orient.Attachment0 = attachment
	orient.RigidityEnabled = true
	orient.Parent = rig.root

	rig.model.Parent = parent
	-- Server owns the physics so every client sees the same, interpolated motion.
	pcall(function()
		rig.root:SetNetworkOwner(nil)
	end)

	local self = setmetatable({
		rig = rig,
		align = align,
		orient = orient,
		events = events,
		stage = nil,
		state = "Idle" :: State,
		trail = Trail.new(),
		nextSampleAt = 0,
		cursor = 0,
		emergeStartedAt = -math.huge,
		graceUntil = 0,
		pausedUntil = 0,
		bowFrom = math.huge,
		bowUntil = 0,
		pose = "Idle",
		shortcut = nil,
		ambushUntil = 0,
		doorsUsed = {},
		position = Vector3.zero,
		facing = Vector3.new(0, 0, -1),
		caughtPending = false,
	}, Mannequin)
	return self
end

-- ── Output ────────────────────────────────────────────────────────────────────────────────

function Mannequin.targetCFrame(self: Mannequin): CFrame
	return CFrame.lookAt(self.position, self.position + self.facing)
end

function Mannequin._apply(self: Mannequin, teleport: boolean)
	local cf = self:targetCFrame()
	self.align.Position = cf.Position
	self.orient.CFrame = cf.Rotation
	if teleport then
		self.rig.root.CFrame = cf
	end
end

function Mannequin._setPose(self: Mannequin, pose: string)
	if self.pose ~= pose then
		self.pose = pose
		self.rig.model:SetAttribute("Pose", pose)
	end
end

-- ── Commands ──────────────────────────────────────────────────────────────────────────────

--- Sends the mannequin home for `stage`: clears the trail and starts the respawn grace period.
function Mannequin.reset(self: Mannequin, stage: Types.StageInfo, now: number)
	self.stage = stage
	self.state = "Idle"
	self.trail:clear()
	self.nextSampleAt = 0
	self.cursor = 0
	self.emergeStartedAt = -math.huge
	self.graceUntil = now + Config.Catch.GraceSeconds
	self.pausedUntil = 0
	self.bowFrom, self.bowUntil = math.huge, 0
	self.shortcut = nil
	self.ambushUntil = 0
	table.clear(self.doorsUsed)
	self.caughtPending = false
	self.position = stage.mannequinHome.Position
	self.facing = stage.mannequinHome.LookVector
	self:_setPose("Idle")
	self:_apply(true)
end

--- Freezes the mannequin and disables catching (used while a scare plays).
function Mannequin.holdForScare(self: Mannequin, seconds: number, now: number)
	self.pausedUntil = math.max(self.pausedUntil, now + seconds)
end

--- Plays the bow pose after `delay` seconds, for `seconds`.
function Mannequin.bow(self: Mannequin, delay: number, seconds: number, now: number)
	self.bowFrom = now + delay
	self.bowUntil = now + delay + seconds
end

--- Called by the zone watcher when the player passes a painted door. Returns true if the
--- mannequin takes the shortcut (only while trailing, once per door per attempt).
function Mannequin.tryDoor(self: Mannequin, door: Types.DoorInfo, now: number): boolean
	if self.state ~= "Trailing" or self.doorsUsed[door.id] or now < self.pausedUntil then
		return false
	end
	self.doorsUsed[door.id] = true
	self.shortcut = { door = door, triggeredAt = now, phase = "Approach", waypoint = 1 }
	self.state = "Shortcut"
	self.events.doorWarning(door.id, self:_estimateShortcutSeconds(door))
	return true
end

function Mannequin._estimateShortcutSeconds(self: Mannequin, door: Types.DoorInfo): number
	local travel = (door.entryPoint - self.position).Magnitude / Config.Door.ApproachSpeed
	local last = door.entryPoint
	for _, point in door.path do
		travel += (point - last).Magnitude / door.pathSpeed
		last = point
	end
	return math.max(Config.Door.MinWarningSeconds, travel)
end

-- ── Per-frame update ──────────────────────────────────────────────────────────────────────

function Mannequin._record(self: Mannequin, now: number, playerCF: CFrame)
	if now < self.nextSampleAt then
		return
	end
	self.trail:push(now, flatten(playerCF))
	-- Fixed cadence; if a frame was slow, resync instead of bursting samples.
	self.nextSampleAt = math.max(self.nextSampleAt + SAMPLE_INTERVAL, now)
end

--- Moves `position` toward `target` at `speed`; returns true once arrived.
function Mannequin._moveToward(self: Mannequin, target: Vector3, speed: number, dt: number): boolean
	local offset = target - self.position
	local distance = offset.Magnitude
	local step = speed * dt
	if distance <= math.max(step, ARRIVE_EPSILON) then
		self.position = target
		return true
	end
	self.facing = flatDirection(self.position, target, self.facing)
	self.position += offset.Unit * step
	return false
end

function Mannequin._updateIdle(self: Mannequin, now: number, playerCF: CFrame?)
	local stage = self.stage :: Types.StageInfo
	if not playerCF then
		return
	end
	local moved = (playerCF.Position - stage.entrance.Position).Magnitude
	if moved > Config.Mannequin.StartMoveDistance then
		self.state = "Warmup"
		self.nextSampleAt = now
		self:_record(now, playerCF)
	end
end

function Mannequin._updateWarmup(self: Mannequin, now: number)
	local first = self.trail:firstTime()
	if first and now - first >= Config.Mannequin.Delay then
		self.state = "Trailing"
		self.cursor = first
		self.emergeStartedAt = now
	end
end

function Mannequin._advanceCursor(self: Mannequin, dt: number, now: number)
	local desired = now - Config.Mannequin.Delay
	if self.cursor < desired then
		-- Fell behind (scare hold): replay faster until back to Delay.
		self.cursor = math.min(desired, self.cursor + dt * Config.Mannequin.CatchUpRate)
	else
		-- Closer than Delay (after a shortcut): replay slower so the gap reopens.
		self.cursor += dt * Config.Mannequin.DriftBackRate
	end
end

function Mannequin._updateTrailing(self: Mannequin, now: number, dt: number)
	local stage = self.stage :: Types.StageInfo
	self:_advanceCursor(dt, now)
	local cf = self.trail:sample(self.cursor)
	if not cf then
		return
	end
	local alpha = (now - self.emergeStartedAt) / Config.Mannequin.EmergeSeconds
	if alpha < 1 then
		cf = stage.mannequinHome:Lerp(cf, math.max(alpha, 0))
	end
	self.position = cf.Position
	self.facing = cf.LookVector
end

function Mannequin._finishHold(self: Mannequin, shortcut: Shortcut)
	local door = shortcut.door
	shortcut.phase = "StepOut"
	self.events.doorOpened(door.id)
	-- If the player already passed the exit step, they outran the shortcut.
	local passed = self.trail:nearestTime(door.exitStep, shortcut.triggeredAt, Config.Door.RejoinRadius)
	if passed then
		self.events.doorOutran(door.id)
	end
end

function Mannequin._updateShortcut(self: Mannequin, now: number, dt: number)
	local shortcut = self.shortcut :: Shortcut
	local door = shortcut.door
	if shortcut.phase == "Approach" then
		if self:_moveToward(door.entryPoint, Config.Door.ApproachSpeed, dt) then
			shortcut.phase = "Path"
		end
	elseif shortcut.phase == "Path" then
		local target = door.path[shortcut.waypoint]
		if not target then
			shortcut.phase = "Hold"
		elseif self:_moveToward(target, door.pathSpeed, dt) then
			shortcut.waypoint += 1
		end
	elseif shortcut.phase == "Hold" then
		self.facing = door.exitFacing
		if now - shortcut.triggeredAt >= Config.Door.MinWarningSeconds then
			self:_finishHold(shortcut)
		end
	elseif shortcut.phase == "StepOut" then
		if self:_moveToward(door.exitStep, door.pathSpeed * 0.6, dt) then
			self.state = "Ambush"
			self.ambushUntil = now + Config.Door.AmbushSeconds
		end
	end
end

function Mannequin._updateAmbush(self: Mannequin, now: number, playerCF: CFrame?)
	local shortcut = self.shortcut :: Shortcut
	local door = shortcut.door
	if playerCF then
		self.facing = flatDirection(self.position, playerCF.Position, self.facing)
	end
	local t = self.trail:nearestTime(door.exitStep, shortcut.triggeredAt, Config.Door.RejoinRadius)
	if t and now - t >= Config.Door.MinRejoinDelay then
		-- Rejoin the trail where the player passed the door, never closer than MinRejoinDelay.
		self.cursor = t
	elseif now >= self.ambushUntil then
		-- Player never came this way: fall back to normal trailing.
		self.cursor = math.max(now - Config.Mannequin.Delay, self.trail:firstTime() or now)
	else
		return
	end
	self.state = "Trailing"
	self.shortcut = nil
	self.emergeStartedAt = -math.huge
end

function Mannequin._updatePose(self: Mannequin, now: number)
	if now >= self.bowFrom and now < self.bowUntil then
		self:_setPose("Bow")
	elseif self.state == "Idle" or self.state == "Warmup" then
		self:_setPose("Idle")
	else
		self:_setPose("Walk")
	end
end

function Mannequin._pruneTrail(self: Mannequin, now: number)
	local keepFrom = self.cursor
	if self.shortcut then
		keepFrom = math.min(keepFrom, self.shortcut.triggeredAt)
	end
	keepFrom = math.max(keepFrom - 0.5, now - Config.Mannequin.MaxTrailSeconds)
	self.trail:prune(keepFrom)
	local first = self.trail:firstTime()
	if first and self.cursor < first and self.state == "Trailing" then
		self.cursor = first
	end
end

function Mannequin.canCatch(self: Mannequin, now: number): boolean
	if self.caughtPending or now < self.graceUntil or now < self.pausedUntil then
		return false
	end
	if now - self.emergeStartedAt < Config.Mannequin.EmergeSeconds then
		return false
	end
	if self.state == "Trailing" or self.state == "Ambush" then
		return true
	end
	return self.state == "Shortcut" and self.shortcut ~= nil and self.shortcut.phase == "StepOut"
end

function Mannequin._checkCatch(self: Mannequin, now: number, playerCF: CFrame)
	if not self:canCatch(now) then
		return
	end
	local delta = playerCF.Position - self.position
	local horizontal = (delta * Vector3.new(1, 0, 1)).Magnitude
	if horizontal < Config.Catch.Distance and math.abs(delta.Y) < Config.Catch.VerticalTolerance then
		self.caughtPending = true
		self.events.caught()
	end
end

--- playerCF is nil while the character is missing or dead (nothing is recorded or caught).
function Mannequin.update(self: Mannequin, now: number, dt: number, playerCF: CFrame?)
	if not self.stage then
		return
	end
	self:_updatePose(now)
	if playerCF and self.state ~= "Idle" then
		self:_record(now, playerCF)
	end
	if now >= self.pausedUntil then
		if self.state == "Idle" then
			self:_updateIdle(now, playerCF)
		elseif self.state == "Warmup" then
			self:_updateWarmup(now)
		elseif self.state == "Trailing" then
			self:_updateTrailing(now, dt)
		elseif self.state == "Shortcut" then
			self:_updateShortcut(now, dt)
		elseif self.state == "Ambush" then
			self:_updateAmbush(now, playerCF)
		end
	end
	self:_pruneTrail(now)
	self:_apply(false)
	if playerCF then
		self:_checkCatch(now, playerCF)
	end
end

function Mannequin.destroy(self: Mannequin)
	self.trail:clear()
	self.rig.model:Destroy()
end

return Mannequin
