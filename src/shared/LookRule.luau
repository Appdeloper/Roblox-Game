--!strict
--[[
	LookRule — the "Don't Look" rule as a tiny, pure state machine (no Roblox types, unit-tested
	offline).

	  Look at a mannequin  → it freezes (it can't move while watched).
	  Keep staring         → after StareSeconds the stage lights flicker and it lunges closer,
	                         then it ignores your gaze for CooldownSeconds.
	  Look away            → the stare meter drains at DrainRate, so short glances are free.

	The meter (0..1) is what the HUD shows, so the rule is telegraphed on every device.
]]

export type Params = {
	StareSeconds: number, -- continuous looking before the lunge
	CooldownSeconds: number, -- after a lunge, looking does not freeze it
	DrainRate: number, -- meter drained per second while not looking (in meter units)
}

export type State = {
	meter: number, -- 0..1
	cooldownUntil: number,
	lastAt: number?,
}

export type Result = {
	frozen: boolean,
	lunge: boolean, -- true on the single step the stare limit is crossed
	meter: number,
}

local LookRule = {}

function LookRule.new(): State
	return { meter = 0, cooldownUntil = -math.huge, lastAt = nil }
end

function LookRule.reset(state: State)
	state.meter = 0
	state.cooldownUntil = -math.huge
	state.lastAt = nil
end

--- Advances the rule to `now`. `looking` is whether the owner is watching this mannequin.
function LookRule.step(state: State, params: Params, looking: boolean, now: number): Result
	local dt = if state.lastAt then math.max(0, now - (state.lastAt :: number)) else 0
	state.lastAt = now
	if now < state.cooldownUntil then
		state.meter = math.max(0, state.meter - dt / params.CooldownSeconds)
		return { frozen = false, lunge = false, meter = state.meter }
	end
	if not looking then
		state.meter = math.max(0, state.meter - dt * params.DrainRate)
		return { frozen = false, lunge = false, meter = state.meter }
	end
	state.meter = math.min(1, state.meter + dt / params.StareSeconds)
	if state.meter >= 1 then
		state.cooldownUntil = now + params.CooldownSeconds
		return { frozen = false, lunge = true, meter = 1 }
	end
	return { frozen = true, lunge = false, meter = state.meter }
end

--- Pure geometry used by the client: is `target` inside the view cone?
--- `dot` is the cosine between the camera look vector and the direction to the target.
function LookRule.inCone(dot: number, distance: number, maxAngleDegrees: number, maxRange: number): boolean
	return distance <= maxRange and dot >= math.cos(math.rad(maxAngleDegrees))
end

return LookRule
