--!strict
--[[
	RoutePath — a stage's route as a polyline through the walkable tops of its route boxes,
	measured in studs from the stage entrance. Used by the Mirror mannequin: it stands at the
	"reflection" of your progress across a point ahead of you, so it walks the real platforms
	toward you while you walk toward it.
]]

local RoutePath = {}
RoutePath.__index = RoutePath

export type RoutePath = typeof(setmetatable(
	{} :: {
		points: { Vector3 },
		cumulative: { number },
		total: number,
	},
	RoutePath
))

function RoutePath.new(points: { Vector3 }): RoutePath
	assert(#points >= 2, "RoutePath needs at least two points")
	local cumulative = { 0 }
	for i = 2, #points do
		cumulative[i] = cumulative[i - 1] + (points[i] - points[i - 1]).Magnitude
	end
	return setmetatable({ points = points, cumulative = cumulative, total = cumulative[#points] }, RoutePath)
end

--- Distance along the path of the point on it closest to `position`.
function RoutePath.project(self: RoutePath, position: Vector3): number
	local best, bestS = math.huge, 0
	for i = 1, #self.points - 1 do
		local a, b = self.points[i], self.points[i + 1]
		local ab = b - a
		local lengthSq = ab:Dot(ab)
		local t = if lengthSq > 0 then math.clamp((position - a):Dot(ab) / lengthSq, 0, 1) else 0
		local closest = a + ab * t
		local d = (position - closest).Magnitude
		if d < best then
			best = d
			bestS = self.cumulative[i] + math.sqrt(lengthSq) * t
		end
	end
	return bestS
end

--- Point on the path `s` studs from the start (clamped to the ends).
function RoutePath.at(self: RoutePath, s: number): Vector3
	if s <= 0 then
		return self.points[1]
	end
	for i = 1, #self.points - 1 do
		local s1 = self.cumulative[i + 1]
		if s <= s1 then
			local s0 = self.cumulative[i]
			local span = s1 - s0
			local t = if span > 0 then (s - s0) / span else 0
			return self.points[i]:Lerp(self.points[i + 1], t)
		end
	end
	return self.points[#self.points]
end

--- Unit horizontal direction of travel at `s` (falls back to -Z on a vertical segment).
function RoutePath.direction(self: RoutePath, s: number): Vector3
	local i = 1
	while i < #self.points - 1 and self.cumulative[i + 1] < s do
		i += 1
	end
	local d = (self.points[i + 1] - self.points[i]) * Vector3.new(1, 0, 1)
	return if d.Magnitude > 1e-3 then d.Unit else Vector3.new(0, 0, -1)
end

return RoutePath
