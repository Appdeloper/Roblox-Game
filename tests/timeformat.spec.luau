--!strict
local TimeFormat = require("../src/shared/TimeFormat")

return function(T)
	T.suite("TimeFormat")

	T.test("clock formatting", function()
		T.eq(TimeFormat.clock(0), "00:00.00")
		T.eq(TimeFormat.clock(83.456), "01:23.45")
		T.eq(TimeFormat.clock(59.999), "00:59.99")
		T.eq(TimeFormat.clock(600), "10:00.00")
		T.eq(TimeFormat.clock(-3), "00:00.00")
	end)

	T.test("seat labels are stable and short", function()
		T.eq(TimeFormat.seat(12345), TimeFormat.seat(12345))
		T.expect(#TimeFormat.seat(987654321) <= 3, "short seat")
	end)
end
