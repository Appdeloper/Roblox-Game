--!strict
local Signal = require("../src/shared/Signal")

return function(T)
	T.suite("Signal")

	T.test("fires connected handlers with arguments", function()
		local s = Signal.new()
		local got = 0
		s:Connect(function(n: number)
			got += n
		end)
		s:Fire(2)
		s:Fire(3)
		T.eq(got, 5)
	end)

	T.test("disconnect stops delivery, even from inside a handler", function()
		local s = Signal.new()
		local count = 0
		local conn
		conn = s:Connect(function()
			count += 1
			conn:Disconnect()
		end)
		s:Fire()
		s:Fire()
		T.eq(count, 1)
		T.eq(conn.Connected, false)
	end)
end
