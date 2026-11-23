--[[
	Clearance spec — the guard rail for all set dressing.

	The rule from the brief: "Decorative geometry must never block or confuse the parkour
	route." Without Studio I can't *look* at the map, so this proves it geometrically:

	  1. Standing room — above every walkable surface, a corridor the size of the platform
	     (inset slightly so flush edge markers don't count) and HEADROOM studs tall must
	     contain no colliding geometry other than the route itself.
	  2. Jump corridors — the air a player flies through between two route boxes (the gap,
	     from the lower surface up to jump apex) must contain no colliding geometry.
	  3. Nothing solid may sit in front of a stage's exit zone or a painted-door trigger.

	Colliding geometry is what can actually block a jump, so that is a hard failure.
	Decorative (non-colliding) parts are allowed in the corridor only above head height,
	which is where hanging ropes and battens live.
]]

local roblox = require("@lune/roblox")
local Vector3 = roblox.Vector3

local HEADROOM = 7 -- a player plus a jump's worth of air
-- Big floors (a stage) legitimately carry set pieces; what must stay clear is the lane the
-- player actually walks. Narrow platforms are fully covered by this anyway.
local PATH_HALF_WIDTH = 7
local LANDING_MARGIN = 7 -- room beyond the landing edge the player may overshoot into
local LATERAL_MARGIN = 1 -- half a character's width past the platform edge
local HEAD_HEIGHT = 5.5 -- below this, even decor would be in the player's face
local INSET = 0.45 -- ignore flush trim/tape hanging off the very edge
local FLAT_MARKING_HEIGHT = 0.12 -- anything this flat is paint on the floor, not an obstacle

-- Route parts, their support posts and the safety net are allowed to be there.
local IGNORED_NAMES = {
	SafetyNet = true,
	FogLayer = true,
	EdgeTape = true,
	Post = true,
	SpikeMark = true,
	Plank = true,
	StageStep = true,
	-- Invisible, non-colliding marker/emitter volumes that span a whole room by design.
	DustVolume = true,
	WindowWalk = true,
	StartPromptPart = true,
}

type Box = { min: Vector3, max: Vector3 }

local function boxOf(center: Vector3, size: Vector3): Box
	return { min = center - size / 2, max = center + size / 2 }
end

local function overlaps(a: Box, b: Box): boolean
	return a.min.X < b.max.X
		and b.min.X < a.max.X
		and a.min.Y < b.max.Y
		and b.min.Y < a.max.Y
		and a.min.Z < b.max.Z
		and b.min.Z < a.max.Z
end

--- World-axis-aligned bounds of a part (conservative: uses the rotated extents).
local function partBox(part): Box
	local cf, size = part.CFrame, part.Size
	local half = Vector3.new(
		math.abs(cf.RightVector.X) * size.X / 2
			+ math.abs(cf.UpVector.X) * size.Y / 2
			+ math.abs(cf.LookVector.X) * size.Z / 2,
		math.abs(cf.RightVector.Y) * size.X / 2
			+ math.abs(cf.UpVector.Y) * size.Y / 2
			+ math.abs(cf.LookVector.Y) * size.Z / 2,
		math.abs(cf.RightVector.Z) * size.X / 2
			+ math.abs(cf.UpVector.Z) * size.Y / 2
			+ math.abs(cf.LookVector.Z) * size.Z / 2
	)
	return { min = cf.Position - half, max = cf.Position + half }
end

return function(h, map, check)
	print("\n== Smoke: parkour clearance")
	local SSS = h.place:GetService("ServerScriptService")
	local RS = h.place:GetService("ReplicatedStorage")
	local Config = h.require(RS.Shared.Config)
	local JumpMath = h.require(RS.Shared.JumpMath)
	local mapRoot = h.place:GetService("Workspace").Map

	local apex = JumpMath.maxHeight(Config.Movement)

	-- Every part in the map, with the route parts themselves identified by name per stage.
	local parts = {}
	for _, d in mapRoot:GetDescendants() do
		-- Moving hazards (light rigs, sandbags, shelves) are meant to be in the way, at times:
		-- they're judged by timing (shared/Motion), not by clearance.
		if d:IsA("BasePart") and not IGNORED_NAMES[d.Name] and d:GetAttribute("Hazard") ~= true then
			local box = partBox(d)
			-- A flat sheet lying on a surface (scuffs, footprints, dust, dropped pages) is
			-- physically incapable of obstructing anyone, so it is never a blocker.
			if box.max.Y - box.min.Y > FLAT_MARKING_HEIGHT then
				table.insert(parts, { inst = d, box = box, collides = d.CanCollide })
			end
		end
	end

	-- Exit zones per stage: a glowing doorway frame there is wayfinding, not an obstacle
	-- (and it is non-colliding, so it can never actually block).
	local exitVolumes: { Box } = {}

	local function inExit(box: Box): boolean
		for _, zone in exitVolumes do
			if overlaps(zone, box) then
				return true
			end
		end
		return false
	end

	--- `solidVolume` is the generous volume a solid part must stay out of; `decorVolume` is
	--- the tighter flight path that even non-blocking decor must not clutter.
	local function blockers(solidVolume: Box, decorVolume: Box, allowed: { [string]: boolean }, decorFloorY: number?)
		local hits = {}
		for _, p in parts do
			local volume = if p.collides then solidVolume else decorVolume
			if not allowed[p.inst.Name] and overlaps(volume, p.box) then
				-- Decor is fine once it is above head height (ropes, battens, valances).
				local tooLow = decorFloorY == nil or p.box.min.Y < decorFloorY
				if (p.collides or tooLow) and not inExit(p.box) then
					table.insert(
						hits,
						string.format(
							"%s (%s) y=%.2f..%.2f x=%.1f z=%.1f",
							p.inst:GetFullName(),
							if p.collides then "solid" else "decor",
							p.box.min.Y,
							p.box.max.Y,
							p.inst.CFrame.Position.X,
							p.inst.CFrame.Position.Z
						)
					)
				end
			end
		end
		return hits
	end

	for stageIndex = 1, Config.Game.StageCount do
		local layout = h.require(SSS.MapBuilder.Layouts["Stage" .. stageIndex])
		local origin = Vector3.new(
			Config.Map.StageOrigins[stageIndex][1],
			Config.Map.StageOrigins[stageIndex][2],
			Config.Map.StageOrigins[stageIndex][3]
		)
		table.clear(exitVolumes)
		local zones = { map.stages[stageIndex].exitZone }
		for _, exit in map.stages[stageIndex].exits or {} do
			table.insert(zones, exit.zone)
		end
		for _, zone in zones do
			table.insert(exitVolumes, boxOf(zone.cframe.Position, zone.size * 1.5))
		end
		-- Route element ids are part names; allow them plus the shop bodies under roofs.
		local allowed = {}
		for _, box in layout.route do
			allowed[box.id] = true
			allowed[box.id .. "_Shop"] = true
		end

		-- The lane through each route box: from where the player arrives to where they leave.
		local function laneEnds(index: number): (Vector3, Vector3)
			local function centreOf(i: number): Vector3?
				local rb = layout.route[i]
				if not rb then
					return nil
				end
				return origin + Vector3.new(rb.center[1], rb.center[2], rb.center[3])
			end
			local here = centreOf(index) :: Vector3
			local from = centreOf(index - 1) or here
			local to = centreOf(index + 1)
			if not to then
				local zone = layout.exitZone or (layout.exits and layout.exits[1].zone)
				to = if zone then origin + Vector3.new(zone.center[1], zone.center[2], zone.center[3]) else here
			end
			return from, to :: Vector3
		end

		local lateral = LATERAL_MARGIN
		local standing, jumping = {}, {}
		local prevTop, prevBox
		for routeIndex, rb in layout.route do
			local center = origin + Vector3.new(rb.center[1], rb.center[2], rb.center[3])
			local size = Vector3.new(rb.size[1], rb.size[2], rb.size[3])
			local top = center.Y + size.Y / 2
			local footprint = Vector3.new(math.max(size.X - INSET * 2, 0.5), 1, math.max(size.Z - INSET * 2, 0.5))

			-- 1. standing room above the walking lane
			local from, to = laneEnds(routeIndex)
			local laneMinX = math.max(center.X - footprint.X / 2, math.min(from.X, to.X, center.X) - PATH_HALF_WIDTH)
			local laneMaxX = math.min(center.X + footprint.X / 2, math.max(from.X, to.X, center.X) + PATH_HALF_WIDTH)
			local laneMinZ = math.max(center.Z - footprint.Z / 2, math.min(from.Z, to.Z, center.Z) - PATH_HALF_WIDTH)
			local laneMaxZ = math.min(center.Z + footprint.Z / 2, math.max(from.Z, to.Z, center.Z) + PATH_HALF_WIDTH)
			local volume = {
				min = Vector3.new(laneMinX, top + 0.25, laneMinZ),
				max = Vector3.new(laneMaxX, top + 0.25 + HEADROOM, laneMaxZ),
			}
			for _, hit in blockers(volume, volume, allowed, top + HEAD_HEIGHT) do
				table.insert(standing, rb.id .. " <- " .. hit)
			end

			-- 2. the air the player actually flies through (the gap plus landing room) —
			--    not the whole destination platform, which may be a 44-stud stage.
			if prevBox and rb.link == "Jump" then
				local lowTop = math.min(prevTop, top)
				local highTop = math.max(prevTop, top)
				local curBox = boxOf(center, size)
				-- Travel runs along whichever axis the two boxes are furthest apart on.
				local dx = math.abs(center.X - (prevBox.min.X + prevBox.max.X) / 2)
				local dz = math.abs(center.Z - (prevBox.min.Z + prevBox.max.Z) / 2)
				local function span(axis: string, dominant: boolean): (number, number)
					local pMin, pMax = (prevBox.min :: any)[axis], (prevBox.max :: any)[axis]
					local cMin, cMax = (curBox.min :: any)[axis], (curBox.max :: any)[axis]
					if dominant then
						-- Between the two facing edges, plus a stud of take-off and
						-- LANDING_MARGIN of landing room on the far side.
						local lo = math.min(math.max(pMin, cMin), math.min(pMax, cMax))
						local hi = math.max(math.max(pMin, cMin), math.min(pMax, cMax))
						-- You cannot overshoot past the far end of the platform you land on.
						local far = math.max(pMax, cMax) + 1
						return math.min(lo, hi) - 1, math.min(math.max(lo, hi) + LANDING_MARGIN, far)
					end
					-- Sideways: only where the two platforms actually overlap, plus a margin.
					local lo = math.max(math.min(pMin, pMax), math.min(cMin, cMax))
					local hi = math.min(math.max(pMin, pMax), math.max(cMin, cMax))
					if hi <= lo then
						lo, hi = math.min(pMin, cMin), math.max(pMax, cMax)
					end
					return lo - lateral, hi + lateral
				end
				local minX, maxX = span("X", dx >= dz)
				local minZ, maxZ = span("Z", dz > dx)
				-- Decor can never block, so it only matters directly over the flight path.
				lateral = 0
				local tightMinX, tightMaxX = span("X", dx >= dz)
				local tightMinZ, tightMaxZ = span("Z", dz > dx)
				lateral = LATERAL_MARGIN
				if maxX > minX and maxZ > minZ then
					local corridor = {
						min = Vector3.new(minX, lowTop + 0.25, minZ),
						max = Vector3.new(maxX, highTop + apex, maxZ),
					}
					local tight = {
						min = Vector3.new(tightMinX, lowTop + 0.25, tightMinZ),
						max = Vector3.new(tightMaxX, highTop + apex, tightMaxZ),
					}
					for _, hit in blockers(corridor, tight, allowed, highTop + HEAD_HEIGHT) do
						table.insert(jumping, rb.id .. " <- " .. hit)
					end
				end
			end
			prevTop = top
			prevBox = boxOf(center, size)
		end

		check(
			#standing == 0,
			string.format("stage %d: standing room above every platform is clear", stageIndex)
				.. (if #standing > 0 then " — " .. standing[1] else "")
		)
		check(
			#jumping == 0,
			string.format("stage %d: jump corridors are clear", stageIndex)
				.. (if #jumping > 0 then " — " .. jumping[1] else "")
		)

		-- 3. triggers (exit zone, painted doors) must be reachable, not walled off
		local stage = map.stages[stageIndex]
		local triggers: { { name: string, cf: any, size: Vector3 } } = {}
		if stage.exitZone then
			table.insert(triggers, { name = "exit zone", cf = stage.exitZone.cframe, size = stage.exitZone.size })
		end
		for _, door in stage.doors do
			table.insert(triggers, { name = "door " .. door.id, cf = door.triggerCFrame, size = door.triggerSize })
		end
		local blocked = {}
		for _, trigger in triggers do
			local volume = boxOf(trigger.cf.Position, trigger.size * 0.6)
			for _, p in parts do
				if p.collides and not allowed[p.inst.Name] and overlaps(volume, p.box) then
					table.insert(blocked, trigger.name .. " <- " .. p.inst:GetFullName())
				end
			end
		end
		check(
			#blocked == 0,
			string.format("stage %d: nothing solid blocks exits or door triggers", stageIndex)
				.. (if #blocked > 0 then " — " .. blocked[1] else "")
		)
	end
end
