--!strict
--[[
	Zone — oriented-box containment tests. Cheaper and more reliable than Touched for triggers:
	the server polls player positions at Config.Zones.CheckInterval and asks "is this point inside?".
]]

local Zone = {}

export type Box = { cframe: CFrame, size: Vector3 }

function Zone.contains(box: Box, point: Vector3): boolean
	local localPoint = box.cframe:PointToObjectSpace(point)
	local half = box.size * 0.5
	return math.abs(localPoint.X) <= half.X and math.abs(localPoint.Y) <= half.Y and math.abs(localPoint.Z) <= half.Z
end

function Zone.fromPart(part: BasePart): Box
	return { cframe = part.CFrame, size = part.Size }
end

return Zone
