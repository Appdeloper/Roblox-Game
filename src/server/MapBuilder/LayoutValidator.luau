--!strict
--[[
	LayoutValidator — checks a stage layout is fair and consistent. Pure: dependencies are
	passed in, so the same code runs in Studio (MapBuilder warns) and offline (tests fail).

	Rules enforced:
	  * Jump links: edge-to-edge gap < Config.Map.MaxGapRatio of the max jump (for that rise),
	    and the rise < Config.Map.MaxRiseRatio of the max jump height.
	  * Walk links need no jump; Climb links need a truss touching both ends; Drop links go down.
	  * Everything walkable sits above the kill line; spawns sit on the first platform.
	  * Door triggers overlap the route and door exits land on the route.
]]

local LayoutValidator = {}

type Vec = { number }
type Box = { center: Vec, size: Vec }

export type Deps = {
	physics: { WalkSpeed: number, JumpPower: number, Gravity: number },
	gapRatio: number,
	riseRatio: number,
	killMargin: number,
	rootHeight: number,
	jumpMath: any,
}

local function top(box: Box): number
	return box.center[2] + box.size[2] / 2
end

local function axisGap(a: Box, b: Box, axis: number): number
	return math.max(0, math.abs(a.center[axis] - b.center[axis]) - (a.size[axis] + b.size[axis]) / 2)
end

--- Horizontal (XZ) edge-to-edge distance between two boxes; 0 when footprints overlap.
function LayoutValidator.horizontalGap(a: Box, b: Box): number
	local dx = axisGap(a, b, 1)
	local dz = axisGap(a, b, 3)
	return math.sqrt(dx * dx + dz * dz)
end

--- Tipped seat rows raise one edge of their top surface; count it against the jump.
local function tiltLift(box: any): number
	local tilt = box.tilt or 0
	return (box.size[1] / 2) * math.sin(math.rad(math.abs(tilt)))
end

local function pointOnBoxTop(point: Vec, box: Box, rootHeight: number, tolerance: number): boolean
	local insideX = math.abs(point[1] - box.center[1]) <= box.size[1] / 2 + tolerance
	local insideZ = math.abs(point[3] - box.center[3]) <= box.size[3] / 2 + tolerance
	local heightOk = math.abs(point[2] - (top(box) + rootHeight)) <= 1
	return insideX and insideZ and heightOk
end

local function checkJump(errors: { string }, prev: any, cur: any, deps: Deps)
	local gap = LayoutValidator.horizontalGap(prev, cur)
	local rise = top(cur) + tiltLift(cur) - top(prev)
	local jm = deps.jumpMath
	local maxRise = jm.maxHeight(deps.physics) * deps.riseRatio
	if rise > maxRise then
		table.insert(errors, string.format("%s: rise %.2f exceeds %.2f", cur.id, rise, maxRise))
		return
	end
	local allowed = jm.allowedGap(deps.physics, rise, deps.gapRatio)
	if gap >= allowed then
		table.insert(errors, string.format("%s: gap %.2f must be under %.2f (rise %.2f)", cur.id, gap, allowed, rise))
	end
end

local function checkClimb(errors: { string }, prev: any, cur: any, trusses: { Box })
	for _, truss in trusses do
		local touchesPrev = LayoutValidator.horizontalGap(truss, prev) <= 1
		local touchesCur = LayoutValidator.horizontalGap(truss, cur) <= 1
		if touchesPrev and touchesCur and top(truss) >= top(cur) then
			return
		end
	end
	table.insert(errors, cur.id .. ": climb link has no truss touching both ends and reaching the top")
end

local function checkLink(errors: { string }, prev: any, cur: any, layout: any, deps: Deps)
	local link = cur.link
	if link == "Jump" then
		checkJump(errors, prev, cur, deps)
	elseif link == "Walk" then
		if LayoutValidator.horizontalGap(prev, cur) > 0.5 or math.abs(top(cur) - top(prev)) > 1 then
			table.insert(errors, cur.id .. ": walk link must be flush (gap <= 0.5, step <= 1)")
		end
	elseif link == "Climb" then
		checkClimb(errors, prev, cur, layout.trusses)
	elseif link == "Drop" then
		if top(cur) >= top(prev) then
			table.insert(errors, cur.id .. ": drop link must go down")
		end
		checkJump(errors, prev, cur, deps)
	elseif link == "Slide" then
		if prev.kind ~= "Slide" or top(cur) > top(prev) - (prev.size[2] - 1) then
			table.insert(errors, cur.id .. ": slide link must follow a slide and sit at its low end")
		end
	else
		table.insert(errors, cur.id .. ": unexpected link " .. tostring(link))
	end
end

function LayoutValidator.killY(layout: any, killMargin: number): number
	return top(layout.net) + killMargin
end

local function checkDoors(errors: { string }, layout: any, deps: Deps)
	for _, door in layout.doors do
		local triggerOnRoute = false
		local exitOnRoute = false
		for _, box in layout.route do
			if LayoutValidator.horizontalGap(door.trigger, box) == 0 then
				triggerOnRoute = true
			end
			if pointOnBoxTop(door.exitStep, box, deps.rootHeight, 0) then
				exitOnRoute = true
			end
		end
		if not triggerOnRoute then
			table.insert(errors, door.id .. ": trigger does not overlap the route")
		end
		if not exitOnRoute then
			table.insert(errors, door.id .. ": exitStep is not standing on a route surface")
		end
		if #door.path == 0 then
			table.insert(errors, door.id .. ": empty shortcut path")
		end
	end
end

--- Returns a list of human-readable problems (empty = layout is valid).
function LayoutValidator.validate(layout: any, deps: Deps): { string }
	local errors: { string } = {}
	local route = layout.route
	if #route < 2 then
		table.insert(errors, layout.name .. ": route needs at least two elements")
		return errors
	end
	if route[1].link ~= "Start" then
		table.insert(errors, route[1].id .. ": first element must use link 'Start'")
	end
	for i = 2, #route do
		checkLink(errors, route[i - 1], route[i], layout, deps)
	end

	local killY = LayoutValidator.killY(layout, deps.killMargin)
	for _, box in route do
		if top(box) + deps.rootHeight <= killY + 1 then
			table.insert(errors, string.format("%s: surface %.1f is below the kill line %.1f", box.id, top(box), killY))
		end
	end
	if not pointOnBoxTop(layout.spawn.pos, route[1], deps.rootHeight, 0) then
		table.insert(errors, layout.name .. ": spawn is not standing on the first route element")
	end
	checkDoors(errors, layout, deps)
	return errors
end

return LayoutValidator
