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
	function signal:Fire(...)
		for _, entry in table.clone(handlers) do
			if entry.conn.Connected then
				entry.fn(...)
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
			schedule(sched.now + (seconds or 0), co, {})
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

local function stubServices(place)
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
	return stubs
end

-- ── Loader ────────────────────────────────────────────────────────────────────────────────

function Harness.load(placePath: string)
	local place = roblox.deserializePlace(fs.readFile(placePath))
	local sched = makeScheduler()
	local stubs = stubServices(place)
	local cache = {}
	local mocks = {}
	local env

	local gameProxy = setmetatable({
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
		signal = makeSignal,
	}
end

return Harness
