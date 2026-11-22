--!strict
--[[
	Motion — deterministic movement for stage hazards, as pure functions of time.

	Every client animates movers from workspace:GetServerTimeNow(), and the server evaluates
	the same functions for anything it judges (light-rig beams), so everyone sees the same
	thing at the same moment and the server stays the referee. No Roblox types: unit-tested
	offline.

	  pendulum  swing angle (degrees) of a rope swing / sandbag
	  slide     offset (studs) of a sliding shelf along its axis
	  spin      angle (degrees) of a rotating light rig
	  beamOn    whether a spinning rig's beam currently lands on its target gate
	  pulse     scale (0..1) of a shrinking/growing prop
]]

export type Spec = {
	period: number,
	phase: number?, -- 0..1, fraction of a period
	amplitude: number?, -- pendulum degrees / slide half-distance (studs)
	min: number?, -- pulse: smallest scale
	hold: number?, -- pulse: fraction of the period spent at full size
	aim: number?, -- spin: angle (degrees) at which the beam hits its gate
	halfWidth: number?, -- spin: beam half-width (degrees)
}

local Motion = {}

local TAU = math.pi * 2

local function cycle(spec: Spec, t: number): number
	local x = t / spec.period + (spec.phase or 0)
	return x - math.floor(x)
end

function Motion.pendulum(spec: Spec, t: number): number
	return (spec.amplitude or 30) * math.sin(TAU * cycle(spec, t))
end

function Motion.slide(spec: Spec, t: number): number
	return (spec.amplitude or 4) * math.sin(TAU * cycle(spec, t))
end

function Motion.spin(spec: Spec, t: number): number
	return 360 * cycle(spec, t)
end

--- Smallest absolute difference between two angles in degrees (0..180).
function Motion.angleDelta(a: number, b: number): number
	local d = (a - b) % 360
	return if d > 180 then 360 - d else d
end

function Motion.beamOn(spec: Spec, t: number): boolean
	return Motion.angleDelta(Motion.spin(spec, t), spec.aim or 0) <= (spec.halfWidth or 20)
end

--- Seconds until the beam next lands on its gate (0 while it is on).
function Motion.beamEta(spec: Spec, t: number): number
	if Motion.beamOn(spec, t) then
		return 0
	end
	local half = spec.halfWidth or 20
	local start = ((spec.aim or 0) - half) % 360
	local now = Motion.spin(spec, t)
	local degrees = (start - now) % 360
	return degrees / 360 * spec.period
end

--- Full size for `hold` of the period, then eases down to `min` and back up.
function Motion.pulse(spec: Spec, t: number): number
	local hold = spec.hold or 0.45
	local min = spec.min or 0.4
	local c = cycle(spec, t)
	if c < hold then
		return 1
	end
	local u = (c - hold) / (1 - hold) -- 0..1 over the shrink-grow
	local s = 0.5 - 0.5 * math.cos(TAU * u) -- 0 → 1 → 0
	return 1 - (1 - min) * s
end

return Motion
