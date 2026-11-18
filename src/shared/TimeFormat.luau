--!strict
--[[
	TimeFormat — pure helpers for showing run times (unit-tested offline).
]]

local TimeFormat = {}

--- 83.456 -> "01:23.45" (centiseconds truncated, never rounded up past the real time).
function TimeFormat.clock(seconds: number): string
	local safe = math.max(0, seconds)
	local centis = math.floor(safe * 100 + 1e-6)
	local minutes = centis // 6000
	local secs = (centis // 100) % 60
	local cs = centis % 100
	return string.format("%02d:%02d.%02d", minutes, secs, cs)
end

--- Seat label printed on the ticket, derived from a user id so it is stable per player.
function TimeFormat.seat(userId: number): string
	local rows = "ABCDEFGHJKLMN"
	local n = math.abs(userId)
	local rowIndex = (n % #rows) + 1
	local seatNumber = (n // #rows) % 30 + 1
	return string.sub(rows, rowIndex, rowIndex) .. tostring(seatNumber)
end

return TimeFormat
