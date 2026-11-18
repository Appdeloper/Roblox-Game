--!strict
-- Minimal test harness for the offline runner.

local T = {}

local passed = 0
local failed = 0
local currentSuite = ""

function T.suite(name: string)
	currentSuite = name
	print("\n== " .. name)
end

function T.test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		passed += 1
		print("  ok   " .. name)
	else
		failed += 1
		print("  FAIL " .. name .. "\n       " .. tostring(err))
	end
end

function T.expect(cond: boolean, message: string?)
	if not cond then
		error(message or "expectation failed", 2)
	end
end

function T.near(a: number, b: number, eps: number, message: string?)
	if math.abs(a - b) > eps then
		error(string.format("%s: expected %.4f ≈ %.4f", message or "near", a, b), 2)
	end
end

function T.eq(a: any, b: any, message: string?)
	if a ~= b then
		error(string.format("%s: expected %s, got %s", message or "eq", tostring(b), tostring(a)), 2)
	end
end

function T.finish()
	print(string.format("\n%d passed, %d failed (%s)", passed, failed, currentSuite))
	if failed > 0 then
		error("tests failed", 0)
	end
end

return T
