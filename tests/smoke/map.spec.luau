--[[
	MapBuilder smoke checks: the whole place builds and every interactive piece exists.
]]

return function(h, check)
	local place = h.place
	print("== Smoke: MapBuilder")
	local ServerScriptService = place:GetService("ServerScriptService")
	local MapBuilder = h.require(ServerScriptService.MapBuilder)
	local ok, map = pcall(MapBuilder.build)
	check(ok, "MapBuilder.build() runs" .. (if ok then "" else ": " .. tostring(map)))
	if not ok then
		return nil
	end

	local Workspace = place:GetService("Workspace")
	local root = Workspace:FindFirstChild("Map")
	check(root ~= nil, "Workspace.Map exists")
	local parts = 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	print(string.format("       %d parts built", parts))
	local budget = h.require(place:GetService("ReplicatedStorage").Shared.Config).Performance
	check(
		parts > 200 and parts <= budget.MaxParts,
		string.format("part count within the %d budget (%d)", budget.MaxParts, parts)
	)
	check(#map.stages == 3, "three stages returned")
	for i, stage in map.stages do
		check(stage.entrance ~= nil and stage.mannequinHome ~= nil, "stage " .. i .. " has entrance + home")
		check(#stage.doors >= 1, "stage " .. i .. " has a painted door")
		check(stage.killY < stage.entrance.Position.Y - 3, "stage " .. i .. " kill line below entrance")
	end
	check(map.stages[3].exitLeftZone ~= nil and map.stages[3].exitRightZone ~= nil, "stage 3 has two exit zones")
	check(map.startPrompt ~= nil and map.startPrompt.ClassName == "ProximityPrompt", "lobby start prompt")
	check(map.leaderboardGui ~= nil, "lobby leaderboard gui")

	local CollectionService = h.game:GetService("CollectionService")
	check(#CollectionService:GetTagged("PaintedDoor") == 6, "six painted door models (entry + exit x3)")
	check(#CollectionService:GetTagged("CollapseStep") == 12, "twelve collapsing steps")
	check(#CollectionService:GetTagged("Backdrop") == 1, "one descending backdrop")
	check(#CollectionService:GetTagged("StageExitDoor") == 2, "two stage-3 exit doors")
	check(#CollectionService:GetTagged("SlideMat") == 1, "one slide mat")
	check(#CollectionService:GetTagged("SceneryLadder") == 1, "one scenery ladder")
	check(#CollectionService:GetTagged("WindowWalk") == 1, "window-walk marker for the stage 2 scare")
	check(#CollectionService:GetTagged("ShadowScreen") == 1, "shadow screen for the stage 1 scare")
	local stamped = true
	for _, door in CollectionService:GetTagged("PaintedDoor") do
		stamped = stamped and door:GetAttribute("Stage") ~= nil and door:GetAttribute("DoorId") ~= nil
	end
	check(stamped, "painted doors carry Stage + DoorId attributes")

	-- Every part is styled from Theme.Surfaces (one place to retune the whole look).
	local Theme = h.require(place:GetService("ReplicatedStorage").Shared.Theme)
	local function key(color, material)
		return string.format(
			"%d,%d,%d,%s",
			math.round(color.R * 255),
			math.round(color.G * 255),
			math.round(color.B * 255),
			tostring(material)
		)
	end
	local known = {}
	for _, surface in Theme.Surfaces do
		known[key(surface.Color, surface.Material)] = true
	end
	local offTheme = {}
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") and not known[key(d.Color, d.Material)] then
			table.insert(offTheme, d:GetFullName())
		end
	end
	-- Environment storytelling actually reached the world (guards the wiring).
	local counts = {}
	for _, d in root:GetDescendants() do
		counts[d.Name] = (counts[d.Name] or 0) + 1
	end
	local Lore = h.require(place:GetService("ReplicatedStorage").Shared.Lore)
	check((counts.LoreBoard or 0) >= 6, "lore boards placed (playbills, cast list, schedule, notices)")
	check((counts.CountdownBoard or 0) == 1, "opening-night countdown board")
	check((counts.CostumeTag or 0) == #Lore.CostumeTags, "one costume tag per cast member")
	check((counts.PromptBook or 0) == 1, "prompt book on its stand")
	check((counts.ScriptPage or 0) >= 15, "script pages scattered around")
	check((counts.ScuffMark or 0) >= 15, "scuff marks dragged toward the painted doors")
	check((counts.Footprint or 0) >= 10, "footprints in the dust")

	-- Each act has its own look: the signature pieces must actually be there.
	local function countIn(stageName: string, names: { string }): number
		local model = root:FindFirstChild(stageName)
		local total = 0
		if model then
			for _, d in model:GetDescendants() do
				if table.find(names, d.Name) then
					total += 1
				end
			end
		end
		return total
	end
	check(
		countIn("Stage1_Auditorium", { "LightShaft", "LightPool" }) >= 6,
		"Act I: moonlight shafts through high windows"
	)
	check(countIn("Stage1_Auditorium", { "AisleCarpet" }) >= 8, "Act I: torn aisle carpet in pieces")
	check(countIn("Stage2_PaintedStreet", { "PaintedMoon", "MoonCrater" }) >= 5, "Act II: a painted moon on the flats")
	check(countIn("Stage2_PaintedStreet", { "Chimney" }) == 3, "Act II: smoking chimneys on the roofline")
	check(countIn("Stage3_CurtainCall", { "BeamSegment" }) >= 10, "Act III: two beams narrowing toward the exits")
	check(countIn("Stage3_CurtainCall", { "Confetti" }) >= 80, "Act III: confetti and torn paper on the floor")

	-- Lights and emitters are the expensive part on a phone.
	for _, stageName in { "Stage1_Auditorium", "Stage2_PaintedStreet", "Stage3_CurtainCall" } do
		local model = root:FindFirstChild(stageName)
		local lights, emitters = 0, 0
		for _, d in model:GetDescendants() do
			if d:IsA("Light") then
				lights += 1
			elseif d:IsA("ParticleEmitter") then
				emitters += 1
			end
		end
		check(
			lights <= budget.MaxLightsPerStage,
			string.format("%s: %d lights (cap %d)", stageName, lights, budget.MaxLightsPerStage)
		)
		check(
			emitters <= budget.MaxEmittersPerStage,
			string.format("%s: %d particle emitters (cap %d)", stageName, emitters, budget.MaxEmittersPerStage)
		)
	end

	check(#offTheme == 0, "every map part uses a Theme surface" .. (if #offTheme > 0 then ": " .. offTheme[1] else ""))
	return map
end
