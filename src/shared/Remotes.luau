--!strict
--[[
	Remotes — the single list of network endpoints.

	The server creates every RemoteEvent on first require; clients wait for them.
	Direction is documented per remote. Client→server remotes are validated and
	rate-limited by server/Services/RemoteGuard.luau — never trust their arguments.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"
local CLIENT_WAIT_SECONDS = 30

local Remotes = {}

-- Server → client
Remotes.ServerToClient = {
	"ProfileUpdated", -- (snapshot: ProfileSnapshot)
	"RunStarted", -- (runStartedAt: number)
	"StageStarted", -- (info: StageStartInfo)
	"Caught", -- (retakes: number)
	"Fell", -- (retakes: number)
	"DoorWarning", -- (doorId: string, warningSeconds: number)
	"DoorOpened", -- (doorId: string)
	"DoorOutran", -- (doorId: string)
	"Scare", -- (stage: number)
	"MannequinPose", -- (pose: string) for local-only polish (heartbeat spikes)
	"FakeExit", -- ()
	"RunFinished", -- (ticket: TicketData)
	"ReturnedToLobby", -- ()
	"Leaderboard", -- (entries: { LeaderboardEntry })
	"Notify", -- (message: string)
}

-- Client → server (all validated server-side)
Remotes.ClientToServer = {
	"RequestStart", -- ()
	"RequestLobby", -- ()
	"SetSetting", -- (key: string, value: boolean)
	"SetQuality", -- (level: string) one of Config.Quality.Order, or "Auto"
	"EquipSkin", -- (skinId: string)
	"SetTrailEnabled", -- (enabled: boolean)
	"ScareSkipped", -- (stage: number) analytics only
}

local cache: { [string]: RemoteEvent } = {}

local function isKnown(name: string): boolean
	return table.find(Remotes.ServerToClient, name) ~= nil or table.find(Remotes.ClientToServer, name) ~= nil
end

local function getFolder(): Folder
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if existing and existing:IsA("Folder") then
			return existing
		end
		local folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
		return folder
	end
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME, CLIENT_WAIT_SECONDS)
	assert(folder and folder:IsA("Folder"), "Remotes folder missing — is the server running?")
	return folder
end

--- Creates every remote (server only). Call once on boot before players can join.
function Remotes.init()
	assert(RunService:IsServer(), "Remotes.init is server-only")
	local folder = getFolder()
	for _, list in { Remotes.ServerToClient, Remotes.ClientToServer } do
		for _, name in list do
			if not folder:FindFirstChild(name) then
				local remote = Instance.new("RemoteEvent")
				remote.Name = name
				remote.Parent = folder
			end
		end
	end
end

--- Returns the RemoteEvent with this name (waits on the client).
function Remotes.get(name: string): RemoteEvent
	assert(isKnown(name), "Unknown remote: " .. name)
	local cached = cache[name]
	if cached then
		return cached
	end
	local folder = getFolder()
	local remote: Instance?
	if RunService:IsServer() then
		remote = folder:FindFirstChild(name)
	else
		remote = folder:WaitForChild(name, CLIENT_WAIT_SECONDS)
	end
	assert(remote and remote:IsA("RemoteEvent"), "Remote not created: " .. name)
	cache[name] = remote
	return remote
end

return Remotes
