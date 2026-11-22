--!strict
--[[
	Offline test runner (plain Luau CLI, no Roblox):  luau tests/run.luau
	Only pure modules (no `game`, no Roblox datatypes) can be tested here.
]]

local T = require("./lib")

require("./config.spec")(T)
require("./jumpmath.spec")(T)
require("./timeformat.spec")(T)
require("./signal.spec")(T)
require("./layout.spec")(T)
require("./lore.spec")(T)
require("./lookrule.spec")(T)
require("./modes.spec")(T)
require("./progression.spec")(T)

T.finish()
