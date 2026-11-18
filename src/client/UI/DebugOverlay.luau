--!strict
--[[
	DebugOverlay — a Studio-only panel for checking the performance budget and the route.

	  F3  part / light / emitter counts against Config.Performance, plus the live frame rate
	  F4  route gizmo: a wireframe box around every walkable platform, so you can see the
	      path through all the scenery and spot anything sitting on it

	It never appears in a published game: it only builds itself when RunService:IsStudio().
	Counting walks the tree, so it refreshes on a timer rather than every frame.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Quality = require(script.Parent.Parent.Quality)
local UIRoot = require(script.Parent.UIRoot)
local Widgets = require(script.Parent.Widgets)

local DebugOverlay = {}

local REFRESH_SECONDS = 1

local panel: Frame
local label: TextLabel
local gizmos: Folder? = nil
local frames = 0
local elapsed = 0
local sinceRefresh = REFRESH_SECONDS

type Counts = { parts: number, lights: number, emitters: number, decals: number }

local function countUnder(root: Instance, counts: Counts)
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			counts.parts += 1
		elseif d:IsA("Light") then
			counts.lights += 1
		elseif d:IsA("ParticleEmitter") then
			counts.emitters += 1
		elseif d:IsA("SurfaceGui") then
			counts.decals += 1
		end
	end
end

local function refresh(fps: number)
	local counts: Counts = { parts = 0, lights = 0, emitters = 0, decals = 0 }
	for _, name in { "Map", "Mannequins", "Ambience", "LocalScareFX", "LocalStageLight" } do
		local root = Workspace:FindFirstChild(name)
		if root then
			countUnder(root, counts)
		end
	end
	local budget = Config.Performance
	label.Text = string.format(
		"FPS %d   quality %s (%s)\nparts %d / %d\nlights %d   emitters %d   surface guis %d",
		math.floor(fps + 0.5),
		Quality.level,
		Quality.requested,
		counts.parts,
		budget.MaxParts,
		counts.lights,
		counts.emitters,
		counts.decals
	)
	label.TextColor3 = if counts.parts > budget.MaxParts then Theme.Colors.UiDanger else Theme.Colors.UiGood
end

--- A wireframe box around every walkable platform.
local function buildGizmos()
	local folder = Instance.new("Folder")
	folder.Name = "RouteGizmos"
	folder.Parent = Workspace
	local map = Workspace:FindFirstChild("Map")
	if not map then
		return folder
	end
	for _, model in map:GetChildren() do
		local route = model:FindFirstChild("Route")
		if route then
			for _, part in route:GetChildren() do
				if part:IsA("BasePart") then
					local box = Instance.new("SelectionBox")
					box.Name = "RouteGizmo"
					box.Adornee = part
					box.LineThickness = 0.08
					box.Color3 = Theme.Colors.UiGood
					box.SurfaceTransparency = 0.85
					box.SurfaceColor3 = Theme.Colors.UiAccent
					box.Parent = folder
				end
			end
		end
	end
	return folder
end

local function toggleGizmos()
	if gizmos then
		gizmos:Destroy()
		gizmos = nil
	else
		gizmos = buildGizmos()
	end
end

function DebugOverlay.init()
	if not RunService:IsStudio() then
		return
	end
	panel = Widgets.frame(
		"DebugOverlay",
		UIRoot.get("Hud"),
		UDim2.fromOffset(320, 96),
		UDim2.new(0, 10, 1, -10),
		Theme.Colors.UiDark,
		0.25
	)
	panel.AnchorPoint = Vector2.new(0, 1)
	panel.Visible = false
	Widgets.corner(panel, 8)
	label = Widgets.label({
		name = "Counts",
		parent = panel,
		text = "",
		size = UDim2.new(1, -16, 1, -12),
		position = UDim2.fromOffset(8, 6),
		font = Theme.Fonts.Mono,
		textSize = 15,
		align = Enum.TextXAlignment.Left,
	})
	label.TextYAlignment = Enum.TextYAlignment.Top

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.F3 then
			panel.Visible = not panel.Visible
		elseif input.KeyCode == Enum.KeyCode.F4 then
			toggleGizmos()
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		frames += 1
		elapsed += dt
		sinceRefresh += dt
		if panel.Visible and sinceRefresh >= REFRESH_SECONDS then
			refresh(if elapsed > 0 then frames / elapsed else 0)
			sinceRefresh, frames, elapsed = 0, 0, 0
		end
	end)
	print("[Debug] F3 = part counter, F4 = route gizmo (Studio only)")
end

return DebugOverlay
