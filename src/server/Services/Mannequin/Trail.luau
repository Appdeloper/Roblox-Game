--!strict
--[[
	Trail — time-stamped CFrame history for one player (recorded at Config.Mannequin.SampleRate).

	Stored as two parallel arrays with a moving `head` index so pruning old samples is O(1)
	amortised (no table.remove(…, 1) shifting every tick on mobile servers).
]]

local Trail = {}
Trail.__index = Trail

export type Trail = typeof(setmetatable(
	{} :: {
		times: { number },
		frames: { CFrame },
		tags: { string },
		head: number,
	},
	Trail
))

local COMPACT_AFTER = 256

function Trail.new(): Trail
	return setmetatable({ times = {}, frames = {}, tags = {}, head = 1 }, Trail)
end

function Trail.clear(self: Trail)
	table.clear(self.times)
	table.clear(self.frames)
	table.clear(self.tags)
	self.head = 1
end

function Trail.count(self: Trail): number
	return #self.times - self.head + 1
end

function Trail.firstTime(self: Trail): number?
	return self.times[self.head]
end

function Trail.lastTime(self: Trail): number?
	return self.times[#self.times]
end

--- `tag` is the player's movement pose at that moment ("Run", "Jump", …), replayed by the rig.
function Trail.push(self: Trail, t: number, cf: CFrame, tag: string?)
	local last = self.times[#self.times]
	if last and t <= last then
		return -- never go back in time (keeps binary search valid)
	end
	table.insert(self.times, t)
	table.insert(self.frames, cf)
	table.insert(self.tags, tag or "")
end

--- Index of the last sample with time <= t (nil if t is before the first sample).
function Trail.indexAt(self: Trail, t: number): number?
	local lo, hi = self.head, #self.times
	if hi < lo or self.times[lo] > t then
		return nil
	end
	while lo < hi do
		local mid = (lo + hi + 1) // 2
		if self.times[mid] <= t then
			lo = mid
		else
			hi = mid - 1
		end
	end
	return lo
end

--- Interpolated CFrame at time t (clamped to the recorded range). nil when empty.
function Trail.sample(self: Trail, t: number): CFrame?
	if self:count() == 0 then
		return nil
	end
	local i = self:indexAt(t)
	if not i then
		return self.frames[self.head]
	end
	local nextIndex = i + 1
	if nextIndex > #self.times then
		return self.frames[i]
	end
	local t0, t1 = self.times[i], self.times[nextIndex]
	local alpha = math.clamp((t - t0) / (t1 - t0), 0, 1)
	return self.frames[i]:Lerp(self.frames[nextIndex], alpha)
end

--- Time of the recorded sample (at or after `since`) closest to `point`, within `radius`.
function Trail.nearestTime(self: Trail, point: Vector3, since: number, radius: number): number?
	local start = self:indexAt(since) or self.head
	local bestTime: number? = nil
	local bestDist = radius
	for i = start, #self.times do
		if self.times[i] >= since then
			local dist = (self.frames[i].Position - point).Magnitude
			if dist <= bestDist then
				bestDist = dist
				bestTime = self.times[i]
			end
		end
	end
	return bestTime
end

--- The pose tag recorded at or just before `t` ("" if none).
function Trail.tagAt(self: Trail, t: number): string
	local i = self:indexAt(t) or self.head
	return self.tags[i] or ""
end

--- Drops samples older than `before`, always keeping at least one at or before it so
--- sample(before) still interpolates correctly.
function Trail.prune(self: Trail, before: number)
	-- Only move `head`: writing nil at the front would leave holes and make `#` unreliable.
	while self.head < #self.times and self.times[self.head + 1] <= before do
		self.head += 1
	end
	if self.head > COMPACT_AFTER then
		local n = #self.times - self.head + 1
		table.move(self.times, self.head, #self.times, 1)
		table.move(self.frames, self.head, #self.frames, 1)
		table.move(self.tags, self.head, #self.tags, 1)
		for i = n + 1, #self.times do
			self.times[i] = nil :: any
			self.frames[i] = nil :: any
			self.tags[i] = nil :: any
		end
		self.head = 1
	end
end

return Trail
