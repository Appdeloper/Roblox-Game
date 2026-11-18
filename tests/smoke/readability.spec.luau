--[[
	Readability spec — "no decoration may hide or confuse the route".

	The clearance spec already proves nothing is physically in the way. This one proves the
	route can be SEEN, which is the half I cannot check by eye without Studio:

	  1. every walkable surface is styled with a Route* surface (never accidentally dressed
	     as scenery),
	  2. every walkable surface is measurably brighter than the set immediately around it,
	     measured on the built map rather than on the palette,
	  3. platforms of the same kind are the same size, so a jump always looks like a jump,
	  4. ladders and slide mats are marked.

	Brightness uses relative luminance (0.2126 R + 0.7152 G + 0.0722 B), the standard weighting
	for how light a colour looks to the eye.
]]

local roblox = require("@lune/roblox")

local MIN_CONTRAST = 12 -- luminance points a platform must beat its surroundings by
local NEIGHBOUR_RADIUS = 22 -- how far around a platform counts as "its surroundings"
local FLUSH_DRESSING = 0.3 -- thinner than this and it is paint on a surface, not scenery

local function luminance(color): number
	return (0.2126 * color.R + 0.7152 * color.G + 0.0722 * color.B) * 255
end

local function median(values: { number }): number
	table.sort(values)
	local n = #values
	if n == 0 then
		return 0
	end
	if n % 2 == 1 then
		return values[(n + 1) // 2]
	end
	return (values[n // 2] + values[n // 2 + 1]) / 2
end

return function(h, check)
	print("\n== Smoke: route readability")
	local RS = h.place:GetService("ReplicatedStorage")
	local SSS = h.place:GetService("ServerScriptService")
	local Theme = h.require(RS.Shared.Theme)
	local Config = h.require(RS.Shared.Config)
	local mapRoot = h.place:GetService("Workspace").Map

	-- Colours that count as "the walkable path".
	local routeColours = {}
	for name, surface in Theme.Surfaces do
		if string.sub(name, 1, 5) == "Route" then
			routeColours[tostring(surface.Color)] = name
		end
	end

	-- Collect the built route parts (named after their layout id) and everything else.
	local routeIds = {}
	for stage = 1, Config.Game.StageCount do
		local layout = h.require(SSS.MapBuilder.Layouts["Stage" .. stage])
		for _, box in layout.route do
			routeIds[box.id] = true
		end
	end

	local routeParts, decorParts = {}, {}
	for _, d in mapRoot:GetDescendants() do
		if d:IsA("BasePart") then
			if routeIds[d.Name] then
				table.insert(routeParts, d)
			elseif
				d.Transparency < 0.9
				and d.Material ~= roblox.Enum.Material.Neon
				and math.min(d.Size.X, d.Size.Y, d.Size.Z) > FLUSH_DRESSING
			then
				-- Skipped: invisible helpers; flat dressing lying ON a surface (planks, glow
				-- tape, confetti, scuffs), which is the platform's own skin rather than
				-- competing scenery; and anything emissive, since a glowing lamp reads as
				-- a light, not as a floor you might mistake for the route.
				table.insert(decorParts, d)
			end
		end
	end
	check(#routeParts >= 30, string.format("%d walkable platforms found", #routeParts))

	-- 1. Every walkable surface is a Route* surface.
	local miscast = {}
	for _, part in routeParts do
		if not routeColours[tostring(part.Color)] then
			table.insert(miscast, part:GetFullName())
		end
	end
	check(
		#miscast == 0,
		"every platform is styled as a walkable surface" .. (if #miscast > 0 then " — " .. miscast[1] else "")
	)

	-- 2. Every platform out-reads its surroundings.
	local dim = {}
	for _, part in routeParts do
		local here = luminance(part.Color)
		local around = {}
		local position = part.CFrame.Position
		local brightest, brightestName = -1, "?"
		for _, other in decorParts do
			if (other.CFrame.Position - position).Magnitude <= NEIGHBOUR_RADIUS then
				local value = luminance(other.Color)
				table.insert(around, value)
				if value > brightest then
					brightest, brightestName = value, other.Name
				end
			end
		end
		if #around >= 4 then
			local backdrop = median(around)
			if here - backdrop < MIN_CONTRAST then
				table.insert(
					dim,
					string.format(
						"%s: %.0f vs %.0f around it (brightest %s at %.0f)",
						part.Name,
						here,
						backdrop,
						brightestName,
						brightest
					)
				)
			end
		end
	end
	check(
		#dim == 0,
		"every platform reads brighter than the set around it" .. (if #dim > 0 then " — " .. dim[1] else "")
	)

	-- 3. Platforms of the same kind share a size, so a jump always looks like a jump.
	local odd = {}
	for stage = 1, Config.Game.StageCount do
		local layout = h.require(SSS.MapBuilder.Layouts["Stage" .. stage])
		local byKind: { [string]: { any } } = {}
		for _, box in layout.route do
			byKind[box.kind] = byKind[box.kind] or {}
			table.insert(byKind[box.kind], box)
		end
		for kind, boxes in byKind do
			-- Stepping stones must match; big floors and landings are allowed to differ.
			if (kind == "SeatRow" or kind == "Step") and #boxes > 1 then
				local first = boxes[1]
				for _, box in boxes do
					for axis = 1, 3 do
						if math.abs(box.size[axis] - first.size[axis]) > 0.01 then
							table.insert(odd, string.format("stage %d %s %s", stage, kind, box.id))
						end
					end
				end
			end
		end
	end
	check(#odd == 0, "stepping stones are a consistent size" .. (if #odd > 0 then " — " .. odd[1] else ""))

	-- 4. Climbs and the slide are marked.
	local tags = h.game:GetService("CollectionService")
	check(#tags:GetTagged("SceneryLadder") >= 1, "the scenery ladder exists")
	local marks = 0
	for _, d in mapRoot:GetDescendants() do
		if d.Name == "LadderMark" then
			marks += 1
		end
	end
	check(marks >= 2, "the ladder is marked at its foot and its head")
	local slide = tags:GetTagged("SlideMat")[1]
	check(slide ~= nil and routeColours[tostring(slide.Color)] ~= nil, "the slide mat reads as a walkable surface")

	-- 5. Edge markers on the platforms you jump between.
	local tape = 0
	for _, d in mapRoot:GetDescendants() do
		if d.Name == "EdgeTape" then
			tape += 1
		end
	end
	check(tape >= #routeParts, string.format("%d glow-tape edge markers across the route", tape))
end
