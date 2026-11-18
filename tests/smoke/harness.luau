--[[
	Lune smoke harness — executes the real game modules from the Rojo-built place outside
	Roblox, so runtime errors (nil indexes, bad property names, wrong enum items, broken flows)
	surface in CI.

	Not a physics simulation. It provides:
	  * a ModuleScript loader with per-module `script`, and mockable modules
	  * a deterministic `task` scheduler on a fake clock (task.wait/delay/defer/spawn)
	  * stubs for services Lune doesn't implement (CollectionService, RunService, Players,
	    DataStoreService, BadgeService, MarketplaceService, ...)

	Usage: lune run tests/smoke/run build/DontLookBackstage.rbxl
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local Harness = {}

-- Full names of every ModuleScript actually loaded by any harness (server or client).
Harness.loaded = {}

local function makeSignal()
	local handlers = {}
	local signal = {}
	function signal:Connect(fn)
		local conn = { Connected = true }
		local entry = { fn = fn, conn = conn }
		function conn.Disconnect(c)
			c.Connected = false
			local i = table.find(handlers, entry)
			if i then
				table.remove(handlers, i)
			end
		end
		table.insert(handlers, entry)
		return conn
	end
	function signal:Once(fn)
		local conn
		conn = signal:Connect(function(...)
			conn:Disconnect()
			fn(...)
		end)
		return conn
	end
	-- Like Roblox, each handler runs on its own thread (so it may yield); errors are re-raised.
	function signal:Fire(...)
		for _, entry in table.clone(handlers) do
			if entry.conn.Connected then
				local co = coroutine.create(entry.fn)
				local ok, err = coroutine.resume(co, ...)
				if not ok then
					error(err, 0)
				end
			end
		end
	end
	function signal:Wait()
		return nil
	end
	return signal
end
Harness.makeSignal = makeSignal

-- ── Scheduler ─────────────────────────────────────────────────────────────────────────────

local function makeScheduler()
	local sched = { now = 0, queue = {}, errors = {} }

	local function resume(co, ...)
		local ok, err = coroutine.resume(co, ...)
		if not ok then
			table.insert(sched.errors, tostring(err))
			print("[task error] " .. tostring(err))
		end
	end

	local function schedule(at, co, args)
		table.insert(sched.queue, { at = at, co = co, args = args })
	end

	sched.task = {
		wait = function(seconds)
			local co = coroutine.running()
			-- Like Roblox, task.wait() always yields at least one frame.
			schedule(sched.now + math.max(seconds or 0, 1 / 60), co, {})
			coroutine.yield()
			return seconds or 0
		end,
		spawn = function(fn, ...)
			local co = if type(fn) == "thread" then fn else coroutine.create(fn)
			resume(co, ...)
			return co
		end,
		defer = function(fn, ...)
			local co = coroutine.create(fn)
			schedule(sched.now, co, table.pack(...))
			return co
		end,
		delay = function(seconds, fn, ...)
			local co = coroutine.create(fn)
			schedule(sched.now + (seconds or 0), co, table.pack(...))
			return co
		end,
		cancel = function(co)
			for i = #sched.queue, 1, -1 do
				if sched.queue[i].co == co then
					table.remove(sched.queue, i)
				end
			end
		end,
	}

	--- Advances the fake clock, running everything that becomes due (in time order).
	function sched.advance(dt)
		local target = sched.now + dt
		while true do
			table.sort(sched.queue, function(a, b)
				return a.at < b.at
			end)
			local nextItem = sched.queue[1]
			if not nextItem or nextItem.at > target then
				break
			end
			table.remove(sched.queue, 1)
			sched.now = math.max(sched.now, nextItem.at)
			resume(nextItem.co, table.unpack(nextItem.args, 1, nextItem.args.n or #nextItem.args))
		end
		sched.now = target
	end

	return sched
end

-- ── Service stubs ─────────────────────────────────────────────────────────────────────────

local function stubServices(place, sched)
	local stubs = {}
	stubs.CollectionService = {
		AddTag = function(_, inst, tag)
			inst:AddTag(tag)
		end,
		RemoveTag = function(_, inst, tag)
			inst:RemoveTag(tag)
		end,
		HasTag = function(_, inst, tag)
			return inst:HasTag(tag)
		end,
		GetTags = function(_, inst)
			return inst:GetTags()
		end,
		GetTagged = function(_, tag)
			local found = {}
			for _, d in place:GetDescendants() do
				if d:HasTag(tag) then
					table.insert(found, d)
				end
			end
			return found
		end,
		GetInstanceAddedSignal = function()
			return makeSignal()
		end,
		GetInstanceRemovedSignal = function()
			return makeSignal()
		end,
	}
	stubs.RunService = {
		IsServer = function()
			return true
		end,
		IsClient = function()
			return false
		end,
		IsStudio = function()
			return true
		end,
		Heartbeat = makeSignal(),
		Stepped = makeSignal(),
		RenderStepped = makeSignal(),
		PreSimulation = makeSignal(),
		PostSimulation = makeSignal(),
	}
	local playerList = {}
	stubs.Players = {
		PlayerAdded = makeSignal(),
		PlayerRemoving = makeSignal(),
		GetPlayers = function()
			return table.clone(playerList)
		end,
		GetPlayerByUserId = function(_, id)
			for _, p in playerList do
				if p.UserId == id then
					return p
				end
			end
			return nil
		end,
		GetNameFromUserIdAsync = function(_, id)
			return "Player" .. tostring(id)
		end,
		_list = playerList,
		RespawnTime = 5,
		CharacterAutoLoads = true,
	}
	stubs.AnalyticsService = {
		LogCustomEvent = function() end,
	}
	stubs.DataStoreService = Harness.fakeDataStores(sched)
	stubs.MarketplaceService = {
		owned = {},
		ProcessReceipt = nil,
		PromptGamePassPurchaseFinished = makeSignal(),
		UserOwnsGamePassAsync = function(self, _userId, passId)
			return self.owned[passId] == true
		end,
	}
	stubs.BadgeService = {
		awarded = {},
		AwardBadgeAsync = function(self, userId, badgeId)
			table.insert(self.awarded, { userId = userId, badgeId = badgeId })
			return true
		end,
		UserHasBadgeAsync = function()
			return false
		end,
	}
	return stubs
end

--- Roblox's Random datatype (Lune has no equivalent). A small deterministic LCG: the exact
--- number stream differs from Roblox, but seeding/determinism — what the map relies on —
--- behaves the same.
local function makeRandom()
	local Random = {}
	Random.__index = Random
	function Random.new(seed)
		return setmetatable({ state = (math.floor(seed or 0) % 2147483647 + 2147483647) % 2147483647 + 1 }, Random)
	end
	function Random:_next()
		self.state = (self.state * 48271) % 2147483647
		return self.state / 2147483647
	end
	function Random:NextNumber(min, max)
		local v = self:_next()
		if min and max then
			return min + v * (max - min)
		end
		return v
	end
	function Random:NextInteger(min, max)
		return min + math.floor(self:_next() * (max - min + 1 - 1e-9))
	end
	function Random:Clone()
		return setmetatable({ state = self.state }, Random)
	end
	return Random
end

-- ── Fake DataStores ───────────────────────────────────────────────────────────────────────

local function deepCopy(v)
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in v do
		out[k] = deepCopy(x)
	end
	return out
end

--- In-memory DataStoreService. Values are deep-copied (like real serialization) and each
--- store can be told to fail its next N reads/writes to exercise retry + lockout paths.
function Harness.fakeDataStores(sched)
	local service = { stores = {} }
	local function makeStore(name)
		-- `latency`: seconds each call yields (real DataStore calls yield; catches blocking callers).
		local store = { name = name, data = {}, failGets = 0, failUpdates = 0, gets = 0, updates = 0, latency = 0 }
		local function lag(self)
			if self.latency > 0 and sched then
				sched.task.wait(self.latency)
			end
		end
		function store.GetAsync(self, key)
			lag(self)
			self.gets += 1
			if self.failGets > 0 then
				self.failGets -= 1
				error("fake DataStore outage")
			end
			return deepCopy(self.data[key])
		end
		function store.UpdateAsync(self, key, transform)
			lag(self)
			self.updates += 1
			if self.failUpdates > 0 then
				self.failUpdates -= 1
				error("fake DataStore outage")
			end
			local new = transform(deepCopy(self.data[key]))
			if new ~= nil then
				self.data[key] = deepCopy(new)
			end
			return new
		end
		function store.SetAsync(self, key, value)
			self.data[key] = deepCopy(value)
		end
		function store.GetSortedAsync(self, ascending, pageSize)
			if self.failGets > 0 then
				self.failGets -= 1
				error("fake DataStore outage")
			end
			local rows = {}
			for k, v in self.data do
				table.insert(rows, { key = k, value = v })
			end
			table.sort(rows, function(a, b)
				if ascending then
					return a.value < b.value
				end
				return a.value > b.value
			end)
			local page = {}
			for i = 1, math.min(pageSize, #rows) do
				page[i] = rows[i]
			end
			return {
				GetCurrentPage = function()
					return page
				end,
				IsFinished = true,
			}
		end
		return store
	end
	function service.GetDataStore(_, name)
		service.stores[name] = service.stores[name] or makeStore(name)
		return service.stores[name]
	end
	service.GetOrderedDataStore = service.GetDataStore
	function service.GetRequestBudgetForRequestType()
		return 100
	end
	return service
end

-- ── Loader ────────────────────────────────────────────────────────────────────────────────

function Harness.load(placePath: string)
	local place = roblox.deserializePlace(fs.readFile(placePath))
	local sched = makeScheduler()
	local stubs = stubServices(place, sched)
	local cache = {}
	local mocks = {}
	local env

	local closeHandlers = {}
	local gameProxy = setmetatable({
		BindToClose = function(_, fn)
			table.insert(closeHandlers, fn)
		end,
		GetService = function(_, name)
			if stubs[name] then
				return stubs[name]
			end
			return place:GetService(name)
		end,
	}, {
		__index = function(_, key)
			return place[key]
		end,
	})

	-- Lune returns a fresh userdata per Instance access, so key by full path, not identity.
	local function requireModule(module)
		local key = module:GetFullName()
		if mocks[key] ~= nil then
			return mocks[key]
		end
		if cache[key] ~= nil then
			return cache[key]
		end
		assert(module.ClassName == "ModuleScript", "require expects a ModuleScript, got " .. tostring(module))
		-- Lune copies the env table (no metatable lookups), so pass a flat one.
		local moduleEnv = table.clone(env)
		moduleEnv.script = module
		Harness.loaded[key] = true
		local chunk = luau.load(module.Source, { debugName = module:GetFullName(), environment = moduleEnv })
		local result = chunk()
		cache[key] = result
		return result
	end

	env = {
		game = gameProxy,
		workspace = place:GetService("Workspace"),
		require = requireModule,
		warn = function(...)
			print("[warn]", ...)
		end,
		tick = function()
			return sched.now
		end,
		task = sched.task,
		os = setmetatable({
			clock = function()
				return sched.now
			end,
		}, { __index = os }),
	}
	env.Random = makeRandom()
	-- Roblox datatypes and constructors (Vector3, CFrame, Color3, Enum, Instance, ...).
	for key, value in roblox do
		if env[key] == nil then
			env[key] = value
		end
	end

	local shared = place:GetService("ReplicatedStorage").Shared
	-- Game time comes from the scheduler's fake clock.
	mocks[shared.Clock:GetFullName()] = {
		now = function()
			return sched.now
		end,
		serverNow = function()
			return 1000 + sched.now
		end,
	}

	return {
		place = place,
		require = requireModule,
		mock = function(module, value)
			mocks[module:GetFullName()] = value
		end,
		stubs = stubs,
		game = gameProxy,
		sched = sched,
		closeHandlers = closeHandlers,
		signal = makeSignal,
	}
end

return Harness
