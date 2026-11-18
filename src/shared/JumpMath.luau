--!strict
--[[
	JumpMath — pure projectile math for Humanoid jumps (no Roblox APIs; unit-tested offline).

	A Humanoid jump launches straight up at JumpPower studs/s while keeping WalkSpeed horizontally,
	and gravity pulls it down at Gravity studs/s². From that:
	  max height        h = v² / 2g
	  flat jump time    t = 2v / g
	  flat jump reach   d = WalkSpeed * t
	Landing on a ledge that is `rise` studs higher shortens the time in the air (and the reach).
]]

local JumpMath = {}

export type Physics = { WalkSpeed: number, JumpPower: number, Gravity: number }

function JumpMath.maxHeight(p: Physics): number
	return (p.JumpPower * p.JumpPower) / (2 * p.Gravity)
end

function JumpMath.maxDistance(p: Physics): number
	return p.WalkSpeed * (2 * p.JumpPower / p.Gravity)
end

--- Horizontal reach when landing `rise` studs above (positive) or below (negative) take-off.
--- Returns 0 when the ledge is too high to reach at all.
function JumpMath.reachAtRise(p: Physics, rise: number): number
	local v, g = p.JumpPower, p.Gravity
	local disc = v * v - 2 * g * rise
	if disc < 0 then
		return 0
	end
	-- Later root of rise = v t - g t² / 2 (the descending moment we land on the ledge).
	local t = (v + math.sqrt(disc)) / g
	return p.WalkSpeed * t
end

--- Gap budget used by the map: under `ratio` of the flat max distance, and also within `ratio`
--- of the actual reach for this rise. `ratio` is Config.Map.MaxGapRatio (0.7).
function JumpMath.allowedGap(p: Physics, rise: number, ratio: number): number
	local flat = JumpMath.maxDistance(p) * ratio
	local atRise = JumpMath.reachAtRise(p, math.max(rise, 0)) * ratio
	return math.min(flat, atRise)
end

function JumpMath.isFairJump(p: Physics, gap: number, rise: number, gapRatio: number, riseRatio: number): boolean
	if rise > JumpMath.maxHeight(p) * riseRatio then
		return false
	end
	return gap < JumpMath.allowedGap(p, rise, gapRatio)
end

return JumpMath
