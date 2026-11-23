--!strict
--[[
	Client entry point (StarterPlayerScripts.Client.Main).
	The client only renders, animates and sends requests; the server decides everything that
	matters. Controllers init in dependency order, then remotes are wired to them here so the
	whole client flow can be read top to bottom in one place.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Types = require(ReplicatedStorage.Shared.Types)

local Client = script.Parent
local AmbienceController = require(Client.Audio.AmbienceController)
local AudioController = require(Client.Audio.AudioController)
local ProximityFX = require(Client.Audio.ProximityFX)
local CameraEffects = require(Client.Camera.CameraEffects)
local Vignette = require(Client.Camera.Vignette)
local Captions = require(Client.UI.Captions)
local ClientState = require(Client.ClientState)
local Quality = require(Client.Quality)
local DebugOverlay = require(Client.UI.DebugOverlay)
local MobileJump = require(Client.Input.MobileJump)
local JumpAssist = require(Client.Input.JumpAssist)
local FinishTicket = require(Client.UI.FinishTicket)
local Hud = require(Client.UI.Hud)
local LobbyPanel = require(Client.UI.LobbyPanel)
local SettingsPanel = require(Client.UI.SettingsPanel)
local TitleCard = require(Client.UI.TitleCard)
local UIRoot = require(Client.UI.UIRoot)
local Wardrobe = require(Client.UI.Wardrobe)
local Ambient = require(Client.World.Ambient)
local Curtains = require(Client.World.Curtains)
local DoorEffects = require(Client.World.DoorEffects)
local Hazards = require(Client.World.Hazards)
local MannequinAnimator = require(Client.World.MannequinAnimator)
local LookWatcher = require(Client.World.LookWatcher)
local Movers = require(Client.World.Movers)
local TrophyShelf = require(Client.World.TrophyShelf)
local ClipMode = require(Client.UI.ClipMode)
local NearMiss = require(Client.World.NearMiss)
local Scares = require(Client.World.Scares)

-- Quality first: other controllers read its settings as they start up.
Quality.init()
UIRoot.init()
AudioController.init()
AmbienceController.init()
CameraEffects.init()
Vignette.init()
Captions.init()
TitleCard.init()
SettingsPanel.init()
Hud.init(SettingsPanel.toggle)
MobileJump.init()
JumpAssist.init()
FinishTicket.init(function()
	Hud.unfreeze()
	LobbyPanel.setHidden(false)
end)
LobbyPanel.init(Wardrobe.open)
Wardrobe.init(LobbyPanel.setHidden)

-- LocalScripts can start before the server-built map has replicated: wait for it before the
-- world modules index doors, hazards and curtains. (Server→client remotes fired meanwhile are
-- queued by Roblox and delivered once the handlers below connect.)
if not game:IsLoaded() then
	game.Loaded:Wait()
end
if not Workspace:WaitForChild("Map", 60) then
	warn("[Client] Workspace.Map never arrived — is the server script running?")
end

MannequinAnimator.init()
LookWatcher.init()
Movers.init()
TrophyShelf.init()
ClipMode.init()
NearMiss.init()
FinishTicket.setExtras({
	hasReplay = NearMiss.has,
	replay = function()
		-- Step out of the ticket for the replay, then bring it back.
		local layer = UIRoot.get("Modal"):FindFirstChild("FinishLayer")
		if layer and layer:IsA("GuiObject") then
			layer.Visible = false
		end
		NearMiss.play()
		if layer and layer:IsA("GuiObject") then
			layer.Visible = true
		end
	end,
	share = function()
		-- The ticket alone on screen, then the platform's capture/share sheet.
		local row = UIRoot.get("Modal"):FindFirstChild("Buttons", true)
		local shareRow = UIRoot.get("Modal"):FindFirstChild("ShareButtons", true)
		for _, r in { row, shareRow } do
			if r and r:IsA("GuiObject") then
				r.Visible = false
			end
		end
		local wasClip = ClipMode.isOn()
		ClipMode.set(true)
		task.wait(0.3)
		ClipMode.snapshot()
		task.wait(1)
		ClipMode.set(wasClip)
		for _, r in { row, shareRow } do
			if r and r:IsA("GuiObject") then
				r.Visible = true
			end
		end
	end,
	invite = ClipMode.inviteFriends,
})
DoorEffects.init()
Hazards.init()
Scares.init()
Curtains.init()
Ambient.init()
ProximityFX.init()
DebugOverlay.init()

-- ── Run flow ──────────────────────────────────────────────────────────────────────────────

Remotes.get("RunStarted").OnClientEvent:Connect(function(startedAt: number)
	ClientState.set("runStartedAt", startedAt)
	ClientState.set("phase", "Running")
end)

Remotes.get("StageStarted").OnClientEvent:Connect(function(info: Types.StageStartInfo)
	Scares.stop()
	DoorEffects.resetAll()
	ClientState.set("phase", "Running")
	ClientState.set("stageInfo", info)
	ClientState.set("stage", info.stage)
	ClientState.set("retakes", info.retakes)
	ClientState.set("runStartedAt", info.runStartedAt)
	Hazards.onStageStarted(info.stage, info.realExit)
	CameraEffects.fadeThrough(0.05)
	if info.isRetake then
		TitleCard.showRetake(info.retakes + 1)
	else
		TitleCard.show(info.act, info.title, info.hint)
	end
end)

Remotes.get("RunFinished").OnClientEvent:Connect(function(ticket: Types.TicketData)
	Scares.stop()
	ClientState.set("phase", "Finished")
	ClientState.set("stage", 0)
	Hud.freeze(ticket.escapeTime)
	LobbyPanel.setHidden(true)
	FinishTicket.show(ticket)
end)

Remotes.get("ProfileUpdated").OnClientEvent:Connect(function(snapshot: Types.ProfileSnapshot)
	ClientState.set("profile", snapshot)
	ClientState.set("reducedScares", snapshot.reducedScares)
	-- The graphics level this player chose last time they played.
	if snapshot.quality and snapshot.quality ~= Quality.requested then
		Quality.set(snapshot.quality)
	end
end)

Remotes.get("Notify").OnClientEvent:Connect(function(message: string)
	Captions.show(message, 3)
end)

Remotes.get("Caught").OnClientEvent:Connect(function(retakes: number)
	ClientState.set("retakes", retakes)
	AudioController.play("CaughtSting")
	CameraEffects.flash()
	CameraEffects.shake()
	Captions.show(Config.Text.Caught, 1.6)
end)

Remotes.get("Fell").OnClientEvent:Connect(function(retakes: number)
	ClientState.set("retakes", retakes)
	AudioController.play("FellSting")
	Captions.show(Config.Text.Fell, 1.6)
end)

Remotes.get("Spotted").OnClientEvent:Connect(function(retakes: number)
	ClientState.set("retakes", retakes)
	AudioController.play("FellSting")
	CameraEffects.flash(Theme.Colors.WarmSpot)
	Captions.show(Config.Text.Spotted, 1.6)
end)

Remotes.get("ReturnedToLobby").OnClientEvent:Connect(function()
	Scares.stop()
	DoorEffects.resetAll()
	Hazards.resetAll()
	ClientState.set("phase", "Lobby")
	ClientState.set("stage", 0)
end)

-- ── Doors, hazards, scares ────────────────────────────────────────────────────────────────

Remotes.get("DoorWarning").OnClientEvent:Connect(function(doorId: string, seconds: number)
	DoorEffects.warn(doorId .. "/Exit", seconds)
end)

Remotes.get("DoorOpened").OnClientEvent:Connect(function(doorId: string)
	DoorEffects.open(doorId .. "/Exit")
end)

Remotes.get("DoorOutran").OnClientEvent:Connect(function()
	Captions.show("You outran the painted door!", 2)
end)

Remotes.get("FakeExit").OnClientEvent:Connect(function(exitName: string)
	Hazards.onFakeExit(exitName)
	CameraEffects.shake(0.2, 0.25)
	Captions.show(Config.Text.FakeExit, 2)
end)

Remotes.get("Scare").OnClientEvent:Connect(function(stage: number)
	Scares.play(stage)
end)

-- ── Intro ─────────────────────────────────────────────────────────────────────────────────

TitleCard.show(
	string.upper(Config.Game.Name),
	Config.Text.Intro,
	"Walk through the STAGE DOOR (or tap Start) when you're ready."
)
