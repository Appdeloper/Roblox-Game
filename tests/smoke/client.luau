--[[
	Client harness — runs the real client modules (UI, effects, scares) under Lune.

	Lune instances validate property names/types (good: catches typos) but have no events, so
	client code sees every Instance through a membrane proxy:
	  * property reads/writes go to the real Lune instance (validated),
	  * events (Activated, Changed, InputBegan, …) are per-instance fake signals,
	  * writing a property fires Changed / GetPropertyChangedSignal like Roblox does,
	  * TweenService applies goals instantly (exercising the property writes).
]]

local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local Client = {}

local EVENTS = {
	Activated = true,
	Changed = true,
	ChildAdded = true,
	ChildRemoved = true,
	DescendantAdded = true,
	DescendantRemoving = true,
	AncestryChanged = true,
	Destroying = true,
	MouseButton1Click = true,
	MouseButton1Down = true,
	MouseButton1Up = true,
	MouseEnter = true,
	MouseLeave = true,
	InputBegan = true,
	InputEnded = true,
	InputChanged = true,
	Touched = true,
	TouchEnded = true,
	Triggered = true,
	Completed = true,
	Ended = true,
	Played = true,
	Died = true,
	FocusLost = true,
	OnClientEvent = true,
	OnServerEvent = true,
}

function Client.membrane(makeSignal)
	local byPid = {}
	local nextPid = 0
	local wrap, unwrap

	local function isProxy(v)
		return type(v) == "table" and rawget(v, "__real") ~= nil
	end

	function unwrap(v)
		if isProxy(v) then
			return rawget(v, "__real")
		end
		return v
	end

	local function unwrapAll(...)
		local out = table.pack(...)
		for i = 1, out.n do
			out[i] = unwrap(out[i])
		end
		return table.unpack(out, 1, out.n)
	end

	local function wrapAll(...)
		local out = table.pack(...)
		for i = 1, out.n do
			out[i] = wrap(out[i])
			if type(out[i]) == "table" and not isProxy(out[i]) and #out[i] > 0 then
				for j, item in out[i] do
					out[i][j] = wrap(item)
				end
			end
		end
		return table.unpack(out, 1, out.n)
	end

	local function signalOf(proxy, key)
		local signals = rawget(proxy, "__signals")
		if not signals[key] then
			signals[key] = makeSignal()
		end
		return signals[key]
	end

	local special = {}
	function special.GetPropertyChangedSignal(proxy, prop)
		return signalOf(proxy, "prop:" .. prop)
	end
	function special.WaitForChild(proxy, name)
		return wrap(rawget(proxy, "__real"):FindFirstChild(name))
	end
	function special.ClearAllChildren(proxy)
		for _, child in rawget(proxy, "__real"):GetChildren() do
			child:Destroy()
		end
	end
	function special.GetPivot(proxy)
		local real = rawget(proxy, "__real")
		return if real:IsA("Model") and real.PrimaryPart then real.PrimaryPart.CFrame else real.CFrame
	end

	-- Properties Lune can't compute (derived/engine-driven) are served by fakes.
	local fakeCamera = {
		ViewportSize = roblox.Vector2.new(1280, 720),
		CFrame = roblox.CFrame.new(0, 20, 0),
		GetPropertyChangedSignal = function()
			return makeSignal()
		end,
	}
	local overrides = {
		CurrentCamera = function()
			return fakeCamera
		end,
		Position = function(proxy)
			local real = rawget(proxy, "__real")
			if real:IsA("BasePart") then
				return real.CFrame.Position
			end
			return real.Position
		end,
	}

	local meta = {}
	function meta.__index(proxy, key)
		if special[key] then
			return special[key]
		end
		if overrides[key] then
			return overrides[key](proxy)
		end
		if EVENTS[key] then
			return signalOf(proxy, key)
		end
		local real = rawget(proxy, "__real")
		local value = real[key]
		if type(value) == "function" then
			return function(_, ...)
				return wrapAll(value(real, unwrapAll(...)))
			end
		end
		return wrap(value)
	end
	function meta.__newindex(proxy, key, value)
		local real = rawget(proxy, "__real")
		real[key] = unwrap(value)
		local signals = rawget(proxy, "__signals")
		local changed = signals.Changed
		if changed then
			changed:Fire(if real:IsA("ValueBase") then real.Value else key)
		end
		local propSignal = signals["prop:" .. key]
		if propSignal then
			propSignal:Fire()
		end
	end
	function meta.__tostring(proxy)
		return tostring(rawget(proxy, "__real"))
	end

	function wrap(v)
		if typeof(v) ~= "Instance" then
			return v
		end
		local pid = v:GetAttribute("__pid")
		if pid and byPid[pid] then
			return byPid[pid]
		end
		nextPid += 1
		v:SetAttribute("__pid", nextPid)
		local proxy = setmetatable({ __real = v, __signals = {} }, meta)
		byPid[nextPid] = proxy
		return proxy
	end

	return { wrap = wrap, unwrap = unwrap, isProxy = isProxy }
end

--- Builds the client environment on top of a server harness `h` (whose place has the map).
function Client.boot(h, Fakes)
	local m = Client.membrane(h.signal)
	local place = h.place
	local RS = place:GetService("ReplicatedStorage")
	local sched = h.sched

	-- Fake character + LocalPlayer.
	local character = Fakes.character(h.signal, roblox.CFrame.new(0, 13, 0))
	character.humanoid.CameraOffset = roblox.Vector3.zero
	character.humanoid.Jump = false
	local playerGui = m.wrap(roblox.Instance.new("Folder"))
	playerGui.Name = "PlayerGui"
	local localPlayer = {
		Name = "Tester",
		DisplayName = "Tester",
		UserId = 4242,
		Character = character,
		CharacterAdded = h.signal(),
		PlayerGui = playerGui,
	}
	function localPlayer:WaitForChild(name)
		return localPlayer[name]
	end
	function localPlayer:FindFirstChild(name)
		return localPlayer[name]
	end

	local log = {}
	local clientRemotes = {}
	local realRemotes = h.require(RS.Shared.Remotes)
	local remotesFake = {
		ServerToClient = realRemotes.ServerToClient,
		ClientToServer = realRemotes.ClientToServer,
		log = log,
	}
	function remotesFake.get(name)
		if not clientRemotes[name] then
			clientRemotes[name] = {
				OnClientEvent = h.signal(),
				FireServer = function(_, ...)
					table.insert(log, { name = name, args = table.pack(...) })
				end,
			}
		end
		return clientRemotes[name]
	end
	function remotesFake.fromServer(name, ...)
		remotesFake.get(name).OnClientEvent:Fire(...)
	end
	function remotesFake.sent(name)
		local n = 0
		for _, e in log do
			if e.name == name then
				n += 1
			end
		end
		return n
	end

	local stubs = {
		Players = { LocalPlayer = localPlayer },
		RunService = {
			Heartbeat = h.signal(),
			Stepped = h.signal(),
			RenderStepped = h.signal(),
			IsClient = function()
				return true
			end,
			IsServer = function()
				return false
			end,
			IsStudio = function()
				return true
			end,
		},
		UserInputService = {
			TouchEnabled = true,
			InputBegan = h.signal(),
			InputEnded = h.signal(),
		},
		TweenService = {
			Create = function(_, instance, _info, goals)
				local tween = { Completed = h.signal(), PlaybackState = "Begin" }
				function tween:Play()
					for key, value in goals do
						instance[key] = value
					end
					sched.task.defer(function()
						tween.Completed:Fire("Completed")
					end)
				end
				function tween:Cancel() end
				function tween:Pause() end
				return tween
			end,
		},
		CollectionService = {
			GetTagged = function(_, tag)
				local found = {}
				for _, inst in h.game:GetService("CollectionService"):GetTagged(tag) do
					table.insert(found, m.wrap(inst))
				end
				return found
			end,
			GetInstanceAddedSignal = function()
				return h.signal()
			end,
			GetInstanceRemovedSignal = function()
				return h.signal()
			end,
			AddTag = function(_, inst, tag)
				m.unwrap(inst):AddTag(tag)
			end,
			HasTag = function(_, inst, tag)
				return m.unwrap(inst):HasTag(tag)
			end,
		},
		ProximityPromptService = { PromptTriggered = h.signal() },
		MarketplaceService = {
			PromptGamePassPurchase = function() end,
			PromptProductPurchase = function() end,
			PromptGamePassPurchaseFinished = h.signal(),
		},
		GuiService = {},
	}

	local clientGame = setmetatable({
		GetService = function(_, name)
			if stubs[name] then
				return stubs[name]
			end
			return m.wrap(place:GetService(name))
		end,
	}, {
		__index = function(_, key)
			return m.wrap(place[key])
		end,
	})

	local cache = {}
	local env
	local function requireModule(module)
		local real = m.unwrap(module)
		local key = real:GetFullName()
		if key == RS.Shared.Remotes:GetFullName() then
			return remotesFake
		end
		if key == RS.Shared.Clock:GetFullName() then
			return {
				now = function()
					return sched.now
				end,
				serverNow = function()
					return 1000 + sched.now
				end,
			}
		end
		if cache[key] ~= nil then
			return cache[key]
		end
		local moduleEnv = table.clone(env)
		moduleEnv.script = m.wrap(real)
		local chunk = luau.load(real.Source, { debugName = "client:" .. key, environment = moduleEnv })
		local result = chunk()
		cache[key] = result
		return result
	end

	local fakeInstance = table.clone(roblox.Instance)
	fakeInstance.new = function(className, parent)
		local inst = m.wrap(roblox.Instance.new(className))
		if parent then
			inst.Parent = parent
		end
		return inst
	end

	env = table.clone(roblox)
	env.Instance = fakeInstance
	-- Lune has no TweenInfo datatype; the TweenService stub ignores timing anyway.
	env.TweenInfo = {
		new = function(time, style, direction, repeatCount, reverses, delay)
			return {
				Time = time or 1,
				EasingStyle = style,
				EasingDirection = direction,
				RepeatCount = repeatCount or 0,
				Reverses = reverses or false,
				DelayTime = delay or 0,
			}
		end,
	}
	env.game = clientGame
	env.workspace = clientGame:GetService("Workspace")
	env.require = requireModule
	env.task = sched.task
	env.warn = function(...)
		print("[client warn]", ...)
	end
	env.os = setmetatable({
		clock = function()
			return sched.now
		end,
	}, { __index = os })
	env.typeof = function(v)
		if m.isProxy(v) then
			return "Instance"
		end
		return typeof(v)
	end

	local function runMain()
		local mainScript = place:GetService("StarterPlayer").StarterPlayerScripts.Client.Main
		local mainEnv = table.clone(env)
		mainEnv.script = m.wrap(mainScript)
		local chunk = luau.load(mainScript.Source, { debugName = "client:Main", environment = mainEnv })
		chunk()
	end

	--- Finds a GuiObject anywhere in PlayerGui by name (first match).
	local function find(name)
		for _, d in m.unwrap(playerGui):GetDescendants() do
			if d.Name == name then
				return m.wrap(d)
			end
		end
		return nil
	end

	local function tick(seconds)
		local t = 0
		local dt = 1 / 30
		while t < seconds do
			t += dt
			sched.advance(dt)
			stubs.RunService.Heartbeat:Fire(dt)
			stubs.RunService.Stepped:Fire(sched.now, dt)
			stubs.RunService.RenderStepped:Fire(dt)
		end
	end

	return {
		runMain = runMain,
		remotes = remotesFake,
		find = find,
		tick = tick,
		character = character,
		stubs = stubs,
		wrap = m.wrap,
	}
end

return Client
