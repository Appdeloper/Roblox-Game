--[[
	Lune smoke tests: run the real game modules from the Rojo place.
	  lune run tests/smoke/run build/DontLookBackstage.rbxl
]]

local process = require("@lune/process")
local Harness = require("./harness")

local placePath = process.args[1] or "build/DontLookBackstage.rbxl"

local failures = 0
local function check(cond: any, message: string)
	if cond then
		print("  ok   " .. message)
	else
		failures += 1
		print("  FAIL " .. message)
	end
end

local h = Harness.load(placePath)
local map = require("./map.spec")(h, check)
if map then
	require("./mannequin.spec")(h, map, check)
	require("./clearance.spec")(h, map, check)
end
require("./round.spec")(placePath, check)
require("./data.spec")(placePath, check)
require("./meta.spec")(placePath, check)
require("./shop.spec")(placePath, check)
require("./client.spec")(placePath, check)

print("\n== Smoke: every ModuleScript in the Rojo build was required")
local never = {}
for _, d in h.place:GetDescendants() do
	if d.ClassName == "ModuleScript" and not Harness.loaded[d:GetFullName()] then
		table.insert(never, d:GetFullName())
	end
end
-- Clock is always replaced by the fake clock (its real body is just os.clock() and
-- Workspace:GetServerTimeNow(), which Lune can't provide).
local ALWAYS_MOCKED = { ["ReplicatedStorage.Shared.Clock"] = true }
for i = #never, 1, -1 do
	if ALWAYS_MOCKED[never[i]] then
		table.remove(never, i)
	end
end
check(#never == 0, "all modules loaded" .. (if #never > 0 then ": missing " .. table.concat(never, ", ") else ""))

if failures > 0 then
	error(string.format("%d smoke checks failed", failures), 0)
end
print("\nSmoke checks passed.")
