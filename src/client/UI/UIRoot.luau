--!strict
--[[
	UIRoot — creates the game's ScreenGuis once and keeps them scaled for the device.

	  Hud      safe-area aware (avoids notches and Roblox's top bar), DisplayOrder 5
	  Overlay  full-screen (fades, flashes, vignette), ignores insets, DisplayOrder 10
	  Modal    safe-area aware (ticket, settings, wardrobe), DisplayOrder 20

	All layouts are authored for a 720-px short side; a UIScale per gui keeps text and touch
	targets readable from small phones to tablets (clamped by Config.UI).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local UIRoot = {}

local guis: { [string]: ScreenGui } = {}
local scales: { UIScale } = {}

local function computeScale(): number
	local camera = Workspace.CurrentCamera
	local size = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local shortSide = math.min(size.X, size.Y)
	return math.clamp(shortSide / Config.UI.ReferenceShortSide, Config.UI.MinScale, Config.UI.MaxScale)
end

local function updateScales()
	local scale = computeScale()
	for _, s in scales do
		s.Scale = scale
	end
end

local function make(name: string, displayOrder: number, fullScreen: boolean): ScreenGui
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = displayOrder
	gui.IgnoreGuiInset = fullScreen
	gui.ScreenInsets = if fullScreen then Enum.ScreenInsets.None else Enum.ScreenInsets.CoreUISafeInsets
	gui.Parent = playerGui
	if not fullScreen then
		local scale = Instance.new("UIScale")
		scale.Parent = gui
		table.insert(scales, scale)
	end
	return gui
end

function UIRoot.init()
	guis.Hud = make("DLB_Hud", 5, false)
	guis.Overlay = make("DLB_Overlay", 10, true)
	guis.Modal = make("DLB_Modal", 20, false)
	updateScales()
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScales)
	end
end

function UIRoot.get(name: "Hud" | "Overlay" | "Modal"): ScreenGui
	local gui = guis[name]
	assert(gui, "UIRoot.init() must run first")
	return gui
end

--- Scaled size of the UI in reference pixels (for layouts that need the real canvas size).
function UIRoot.scale(): number
	return computeScale()
end

return UIRoot
