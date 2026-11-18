--!strict
local Config = require("../src/shared/Config")
local JumpMath = require("../src/shared/JumpMath")

return function(T)
	T.suite("JumpMath")
	local p = Config.Movement

	T.test("default physics give the classic ~8.15 stud jump", function()
		T.near(JumpMath.maxDistance(p), 8.155, 0.01, "max distance")
		T.near(JumpMath.maxHeight(p), 6.371, 0.01, "max height")
	end)

	T.test("reach at zero rise equals flat reach", function()
		T.near(JumpMath.reachAtRise(p, 0), JumpMath.maxDistance(p), 1e-6, "flat")
	end)

	T.test("higher ledges shorten reach, drops lengthen it", function()
		T.expect(JumpMath.reachAtRise(p, 3) < JumpMath.maxDistance(p), "rise")
		T.expect(JumpMath.reachAtRise(p, -5) > JumpMath.maxDistance(p), "drop")
		T.eq(JumpMath.reachAtRise(p, 100), 0, "unreachable")
	end)

	T.test("70% rule", function()
		local limit = JumpMath.maxDistance(p) * 0.7
		T.expect(JumpMath.isFairJump(p, limit - 0.01, 0, 0.7, 0.7), "just under")
		T.expect(not JumpMath.isFairJump(p, limit + 0.01, 0, 0.7, 0.7), "just over")
		T.expect(not JumpMath.isFairJump(p, 1, 5, 0.7, 0.7), "too high")
	end)
end
