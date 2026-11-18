--[[
	Lune smoke harness — executes the real server modules from the Rojo-built place outside
	Roblox, so runtime errors (nil indexes, bad property names, wrong enum items) surface in CI.

	Not a physics simulation: services Lune doesn't implement are stubbed with just enough
	behaviour for boot code (tags, attributes, signals, task scheduling).

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
		table.insert(handlers, fn)
		return {
			Connected = true,
			Disconnect = function(conn)
				conn.Connected = false
				local i = table.find(handlers, fn)
				if i then
					table.remove(handlers, i)
				end
			end,
		}
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
		for _, fn in table.clone(handlers) do
			fn(...)
		end
	end
	function signal:Wait()
		return nil
	end
	return signal
end
Harness.makeSignal = makeSignal

local function stubServices(game)
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
			for _, d in game:GetDescendants() do
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
	stubs.Players = {
		PlayerAdded = makeSignal(),
		PlayerRemoving = makeSignal(),
		GetPlayers = function()
			return {}
		end,
		RespawnTime = 5,
		CharacterAutoLoads = true,
	}
	return stubs
end

function Harness.load(placePath: string)
	local place = roblox.deserializePlace(fs.readFile(placePath))
	local stubs = stubServices(place)
	local cache = {}
	local env
	local requireModule

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

	function requireModule(module)
		if cache[module] ~= nil then
			return cache[module]
		end
		assert(module.ClassName == "ModuleScript", "require expects a ModuleScript, got " .. tostring(module))
		local source = module.Source
		local chunk = luau.load(source, {
			debugName = module:GetFullName(),
			environment = (function()
				-- Lune copies the env table (no metatable lookups), so pass a flat one.
				local moduleEnv = table.clone(env)
				moduleEnv.script = module
				return moduleEnv
			end)(),
		})
		local result = chunk()
		cache[module] = result
		return result
	end

	env = {
		game = gameProxy,
		workspace = place:GetService("Workspace"),
		require = requireModule,
		warn = function(...)
			print("[warn]", ...)
		end,
		tick = os.clock,
		task = {
			wait = function(_)
				return 0
			end,
			spawn = function(fn, ...)
				return coroutine.wrap(fn)(...)
			end,
			defer = function(fn, ...)
				return coroutine.wrap(fn)(...)
			end,
			delay = function(_, _fn)
				return nil
			end,
			cancel = function() end,
		},
	}
	-- Roblox datatypes and constructors (Vector3, CFrame, Color3, Enum, Instance, ...).
	for key, value in roblox do
		if env[key] == nil then
			env[key] = value
		end
	end

	return {
		place = place,
		require = requireModule,
		stubs = stubs,
		game = gameProxy,
	}
end

return Harness
