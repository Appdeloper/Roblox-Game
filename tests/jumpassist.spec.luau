--!strict
local Config = require("../src/shared/Config")
local JumpAssist = require("../src/shared/JumpAssist")

return function(T)
	T.suite("JumpAssist")
	local P = Config.Feel

	T.test("on the ground the humanoid jumps by itself", function()
		local s = JumpAssist.new()
		T.eq(JumpAssist.press(s, P, 0), "Native", "grounded press")
	end)

	T.test("coyote time: a late press just after an edge still jumps, once", function()
		local s = JumpAssist.new()
		JumpAssist.setGrounded(s, P, false, 10)
		T.eq(JumpAssist.press(s, P, 10 + P.CoyoteSeconds * 0.5), "Coyote", "inside the window")
		T.eq(JumpAssist.press(s, P, 10 + P.CoyoteSeconds * 0.8), "Buffered", "no second coyote jump")
	end)

	T.test("too late for coyote time", function()
		local s = JumpAssist.new()
		JumpAssist.setGrounded(s, P, false, 10)
		T.eq(JumpAssist.press(s, P, 10 + P.CoyoteSeconds + 0.05), "Buffered", "outside the window")
	end)

	T.test("no coyote jump after a real jump", function()
		local s = JumpAssist.new()
		JumpAssist.didJump(s)
		JumpAssist.setGrounded(s, P, false, 10)
		T.eq(JumpAssist.press(s, P, 10.02), "Buffered", "already jumped")
	end)

	T.test("jump buffering fires on landing, only inside the window", function()
		local s = JumpAssist.new()
		JumpAssist.setGrounded(s, P, false, 0)
		JumpAssist.press(s, P, 1)
		T.expect(JumpAssist.setGrounded(s, P, true, 1 + P.BufferSeconds * 0.5), "buffered jump on landing")
		JumpAssist.setGrounded(s, P, false, 2)
		JumpAssist.press(s, P, 3)
		T.expect(not JumpAssist.setGrounded(s, P, true, 3 + P.BufferSeconds + 0.05), "stale buffer ignored")
	end)

	T.test("windows are small enough to stay fair", function()
		T.expect(P.CoyoteSeconds > 0 and P.CoyoteSeconds <= 0.2, "coyote window")
		T.expect(P.BufferSeconds > 0 and P.BufferSeconds <= 0.2, "buffer window")
		T.expect(P.LedgeReach <= 1.2 and P.LedgeLift <= 1.5, "ledge forgiveness stays small")
	end)
end
