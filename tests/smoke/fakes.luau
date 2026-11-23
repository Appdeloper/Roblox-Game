--[[
	Fakes for the server sim: players, characters and RemoteEvents as plain tables that
	implement exactly the API surface the game code uses.
]]

local roblox = require("@lune/roblox")
local CFrame = roblox.CFrame
local Vector3 = roblox.Vector3

local Fakes = {}

--- A Remotes module replacement: every FireClient is logged per player for assertions.
function Fakes.remotes(realRemotes, makeSignal)
	local log = {}
	local remotes = {}
	local fake = {
		ServerToClient = realRemotes.ServerToClient,
		ClientToServer = realRemotes.ClientToServer,
		log = log,
	}
	function fake.init() end
	function fake.get(name)
		if not remotes[name] then
			remotes[name] = {
				Name = name,
				OnServerEvent = makeSignal(),
				FireClient = function(_, player, ...)
					table.insert(log, { name = name, userId = player.UserId, args = table.pack(...) })
				end,
				FireAllClients = function(_, ...)
					table.insert(log, { name = name, userId = 0, args = table.pack(...) })
				end,
			}
		end
		return remotes[name]
	end
	--- Simulates a client firing a remote at the server.
	function fake.fromClient(name, player, ...)
		fake.get(name).OnServerEvent:Fire(player, ...)
	end
	function fake.count(name, userId)
		local n = 0
		for _, e in log do
			if e.name == name and (userId == nil or e.userId == userId) then
				n += 1
			end
		end
		return n
	end
	function fake.last(name, userId)
		for i = #log, 1, -1 do
			local e = log[i]
			if e.name == name and (userId == nil or e.userId == userId) then
				return e.args
			end
		end
		return nil
	end
	return fake
end

local function fakePart(name, cf)
	local part = {
		Name = name,
		ClassName = "Part",
		CFrame = cf,
		AssemblyLinearVelocity = Vector3.zero,
		AssemblyAngularVelocity = Vector3.zero,
	}
	function part:IsA(class)
		return class == "BasePart" or class == "Part" or class == "Instance"
	end
	function part:FindFirstChild()
		return nil
	end
	return setmetatable(part, {
		__index = function(t, key)
			if key == "Position" then
				return rawget(t, "CFrame").Position
			end
			return nil
		end,
	})
end

local function fakeHumanoid(makeSignal)
	local humanoid = {
		Name = "Humanoid",
		ClassName = "Humanoid",
		Health = 100,
		Died = makeSignal(),
		UseJumpPower = false,
		JumpPower = 0,
		WalkSpeed = 0,
		MoveDirection = Vector3.zero,
	}
	function humanoid:IsA(class)
		return class == "Humanoid" or class == "Instance"
	end
	return humanoid
end

--- `realRoot`: use a real Lune Part (supports children like Trails) — lobby-only tests,
--- since Lune can't read the derived BasePart.Position the run code uses.
function Fakes.character(makeSignal, cf, realRoot)
	local root
	if realRoot then
		root = roblox.Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.CFrame = cf or CFrame.new()
	else
		root = fakePart("HumanoidRootPart", cf or CFrame.new())
	end
	local humanoid = fakeHumanoid(makeSignal)
	local children = { HumanoidRootPart = root, Humanoid = humanoid }
	local character = { Name = "Character", ClassName = "Model", root = root, humanoid = humanoid }
	function character:FindFirstChild(name)
		return children[name]
	end
	function character:WaitForChild(name)
		return children[name]
	end
	function character:FindFirstChildOfClass(class)
		for _, child in children do
			if child.ClassName == class then
				return child
			end
		end
		return nil
	end
	function character:PivotTo(target)
		root.CFrame = target
	end
	function character:GetPivot()
		return root.CFrame
	end
	local attributes = {}
	function character:SetAttribute(key, value)
		attributes[key] = value
	end
	function character:GetAttribute(key)
		return attributes[key]
	end
	return character
end

local nextUserId = 1000

function Fakes.player(makeSignal, name)
	nextUserId += 1
	local player = {
		Name = name,
		DisplayName = name,
		UserId = nextUserId,
		Parent = "Players",
		Character = nil,
		CharacterAdded = makeSignal(),
		CharacterRemoving = makeSignal(),
		kicked = nil,
	}
	function player:Kick(message)
		player.kicked = message or true
	end
	function player:IsA(class)
		return class == "Player"
	end
	--- Spawns a fresh character at `cf` and fires CharacterAdded (like Roblox does).
	function player:spawn(cf, realRoot)
		local character = Fakes.character(makeSignal, cf, realRoot)
		player.Character = character
		player.CharacterAdded:Fire(character)
		return character
	end
	--- Moves the character's root (what the client would replicate).
	function player:moveTo(position, look)
		local root = player.Character.root
		local dir = look or root.CFrame.LookVector
		root.CFrame = CFrame.lookAt(position, position + dir)
	end
	function player:position()
		return player.Character.root.CFrame.Position
	end
	return player
end

return Fakes
