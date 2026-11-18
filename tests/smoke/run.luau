--[[
	Lune smoke test: builds the whole map from the Rojo place and sanity-checks the result.
	  lune run tests/smoke/run build/DontLookBackstage.rbxl
]]

local process = require("@lune/process")
local Harness = require("./harness")

local placePath = process.args[1] or "build/DontLookBackstage.rbxl"
local h = Harness.load(placePath)
local place = h.place

local failures = 0
local function check(cond: boolean, message: string)
	if cond then
		print("  ok   " .. message)
	else
		failures += 1
		print("  FAIL " .. message)
	end
end

print("== Smoke: MapBuilder")
local ServerScriptService = place:GetService("ServerScriptService")
local MapBuilder = h.require(ServerScriptService.MapBuilder)
local ok, map = pcall(MapBuilder.build)
check(ok, "MapBuilder.build() runs" .. (if ok then "" else ": " .. tostring(map)))

if ok then
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
	check(parts > 200 and parts < 3000, "part count in a mobile-friendly range")
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
	for _, door in CollectionService:GetTagged("PaintedDoor") do
		check(door:GetAttribute("Stage") ~= nil, door.Name .. " stamped with Stage attribute")
	end
end

if ok then
	require("./mannequin.spec")(h, map, check)
end

if failures > 0 then
	error(string.format("%d smoke checks failed", failures), 0)
end
print("\nSmoke checks passed.")
