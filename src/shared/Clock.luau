--!strict
--[[
	Clock — the one place game code reads time from, so tests can substitute a fake clock.
	  now()        monotonic seconds for durations (os.clock)
	  serverNow()  server-synchronised wall time shared with clients (HUD timer)
]]

local Workspace = game:GetService("Workspace")

local Clock = {}

function Clock.now(): number
	return os.clock()
end

function Clock.serverNow(): number
	return Workspace:GetServerTimeNow()
end

return Clock
