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
end
require("./round.spec")(placePath, check)

if failures > 0 then
	error(string.format("%d smoke checks failed", failures), 0)
end
print("\nSmoke checks passed.")
