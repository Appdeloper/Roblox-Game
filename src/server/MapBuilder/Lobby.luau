--!strict
--[[
	Lobby — "The Rehearsal Room". Players wake up on a small rehearsal stage under the ghost
	light, read the best-times chalkboard, visit the wardrobe (cosmetics) and walk through the
	STAGE DOOR (ProximityPrompt) to start a run.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Builders = require(script.Parent.Builders)
local Props = require(script.Parent.Props)
local StageBuilder = require(script.Parent.StageBuilder)
local Story = require(script.Parent.Set.Story)

local Lobby = {}

export type LobbyInfo = {
	spawn: CFrame,
	startPrompt: ProximityPrompt,
	leaderboardGui: SurfaceGui,
	-- Mode boards: "Daily" and "Endless".
	modeBoards: { [string]: SurfaceGui },
}

local ROOM_MIN = Vector3.new(-30, 0, -22)
local ROOM_MAX = Vector3.new(30, 26, 22)
local LEADERBOARD_ROWS = 10

local function prompt(parent: BasePart, name: string, action: string, object: string): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.Name = name
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = 0
	p.MaxActivationDistance = 12
	p.RequiresLineOfSight = false
	p.Parent = parent
	return p
end

local function rehearsalStage(parent: Instance, o: Vector3): SpawnLocation
	Builders.part({
		name = "RehearsalStage",
		size = Vector3.new(40, 3, 14),
		cframe = CFrame.new(o + Vector3.new(0, 1.5, -15)),
		parent = parent,
		surface = "Plank",
	})
	-- Two shallow steps down to the floor.
	for i, z in { -7.5, -6.5 } do
		Builders.part({
			name = "StageStep",
			size = Vector3.new(10, 3 - i, 1),
			cframe = CFrame.new(o + Vector3.new(0, (3 - i) / 2, z)),
			parent = parent,
			surface = "AgedWood",
		})
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(10, 0.4, 6)
	spawn.CFrame = CFrame.new(o + Vector3.new(0, 3.2, -15))
	Theme.apply(spawn, "RouteWood")
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = parent
	Props.spikeMark(parent, CFrame.new(o + Vector3.new(0, 3.4, -15)))
	Props.footlights(parent, o + Vector3.new(-19, 3.3, -8.4), o + Vector3.new(19, 3.3, -8.4), 12, 4)
	return spawn
end

--- The traditional theatre "ghost light": a bare bulb left burning on an empty stage.
local function ghostLight(parent: Instance, o: Vector3)
	Builders.part({
		name = "GhostLightStand",
		size = Vector3.new(0.3, 6, 0.3),
		cframe = CFrame.new(o + Vector3.new(6, 6, -17)),
		parent = parent,
		surface = "Iron",
		decor = true,
	})
	local bulb = Builders.part({
		name = "GhostLightBulb",
		size = Vector3.new(1, 1, 1),
		cframe = CFrame.new(o + Vector3.new(6, 9.4, -17)),
		parent = parent,
		surface = "WarmGlow",
		decor = true,
	})
	bulb.Shape = Enum.PartType.Ball
	Builders.pointLight(bulb, Theme.Colors.WarmSpot, 40, 1.8)
end

local function leaderboardBoard(
	parent: Instance,
	o: Vector3,
	cframe: CFrame?,
	heading: string?,
	size: Vector3?
): SurfaceGui
	local pos = o + Vector3.new(-29.6, 12, 2)
	local board = Builders.part({
		name = "LeaderboardBoard",
		size = size or Vector3.new(20, 14, 0.4),
		cframe = cframe or CFrame.lookAt(pos, pos + Vector3.xAxis),
		parent = parent,
		surface = "Chalkboard",
	})
	local gui = Instance.new("SurfaceGui")
	gui.Name = "LeaderboardGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0.2
	gui.Parent = board

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.fromScale(1, 0.16)
	title.BackgroundTransparency = 1
	title.Font = Theme.Fonts.Title
	title.TextScaled = true
	title.TextColor3 = Theme.Colors.Paper
	title.Text = heading or "★ BEST ESCAPES ★"
	title.Parent = gui

	local list = Instance.new("Frame")
	list.Name = "List"
	list.Position = UDim2.fromScale(0.06, 0.18)
	list.Size = UDim2.fromScale(0.88, 0.8)
	list.BackgroundTransparency = 1
	list.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	for i = 1, LEADERBOARD_ROWS do
		local row = Instance.new("TextLabel")
		row.Name = "Row" .. i
		row.LayoutOrder = i
		row.Size = UDim2.fromScale(1, 1 / LEADERBOARD_ROWS)
		row.BackgroundTransparency = 1
		row.Font = Theme.Fonts.Mono
		row.TextScaled = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = Theme.Colors.Paper
		row.Text = if i == 1 then "  Loading the playbill…" else ""
		row.Parent = list
	end
	return gui
end

local function stageDoor(parent: Instance, o: Vector3): ProximityPrompt
	local base = CFrame.lookAt(o + Vector3.new(29.9, 0, 4), o + Vector3.new(0, 0, 4))
	Props.exitDoor(parent, base, "Lobby")
	local door = parent:FindFirstChild("Exit_Lobby")
	if door then
		-- The lobby door is not a stage-3 exit; drop that tag.
		CollectionService:RemoveTag(door, "StageExitDoor")
		door.Name = "StageDoor"
		local sign = door:FindFirstChild("ExitSign", true)
		local label = sign and sign:FindFirstChildWhichIsA("SurfaceGui")
		local text = label and label:FindFirstChildWhichIsA("TextLabel")
		if text then
			text.Text = "STAGE"
		end
	end
	local pad = Builders.part({
		name = "StartPromptPart",
		size = Vector3.new(1, 1, 1),
		cframe = base * CFrame.new(0, 4, -1.5),
		parent = parent,
		surface = "Invisible",
		decor = true,
	})
	Props.sign(
		parent,
		base * CFrame.new(0, 12.6, -0.3),
		Vector3.new(10, 2, 0.3),
		"PLACES, PLEASE!",
		Theme.Colors.WarmSpot,
		"Iron"
	)
	return prompt(pad, "StartPrompt", "Start the Show", "Stage Door")
end

local function wardrobe(parent: Instance, o: Vector3)
	local rail = Builders.part({
		name = "WardrobeRail",
		size = Vector3.new(10, 0.3, 0.3),
		cframe = CFrame.new(o + Vector3.new(-14, 6.5, 16)),
		parent = parent,
		surface = "Brass",
		decor = true,
	})
	local costumes = { "Curtain", "CostumeTeal", "Gilt", "CostumePurple" }
	for i, costume in costumes do
		Builders.part({
			name = "Costume",
			size = Vector3.new(1.6, 4, 0.6),
			cframe = CFrame.new(o + Vector3.new(-18 + i * 2.2, 4.3, 16)),
			parent = parent,
			surface = costume,
			decor = true,
		})
	end
	local p = prompt(rail, "WardrobePrompt", "Open Wardrobe", "Cosmetics")
	CollectionService:AddTag(p, "WardrobePrompt")
	Props.sign(
		parent,
		CFrame.lookAt(o + Vector3.new(-14, 9.5, 16.2), o + Vector3.new(-14, 9.5, 0)),
		Vector3.new(8, 1.6, 0.3),
		"WARDROBE",
		Theme.Colors.Paper,
		"DarkWood"
	)
end

local function titleSign(parent: Instance, o: Vector3)
	Props.sign(
		parent,
		CFrame.lookAt(o + Vector3.new(0, 18, -21.7), o + Vector3.new(0, 18, 0)),
		Vector3.new(36, 5, 0.3),
		Config.Game.Name,
		Theme.Colors.WarmSpot,
		"Curtain"
	)
	Props.sign(
		parent,
		CFrame.lookAt(o + Vector3.new(0, 1.2, 21.7), o + Vector3.new(0, 1.2, 0)),
		Vector3.new(10, 1.2, 0.3),
		Config.Game.BuildLabel,
		Theme.Colors.PaperShade,
		"Iron"
	)
end

function Lobby.build(parent: Instance, origin: Vector3): LobbyInfo
	local model = Builders.model("Lobby_RehearsalRoom", parent)
	StageBuilder.room(model, origin + ROOM_MIN, origin + ROOM_MAX)
	local spawn = rehearsalStage(model, origin)
	ghostLight(model, origin)
	local gui = leaderboardBoard(model, origin)
	-- The mode boards hang on the side walls, high enough to read over the crowd.
	local dailyPos = origin + Vector3.new(-16, 13, -21.6)
	local endlessPos = origin + Vector3.new(-16, 13, 21.6)
	local modeBoards = {
		Daily = leaderboardBoard(
			model,
			origin,
			CFrame.lookAt(dailyPos, dailyPos + Vector3.zAxis),
			"☀ TODAY'S DAILY RUN ☀",
			Vector3.new(16, 11, 0.4)
		),
		Endless = leaderboardBoard(
			model,
			origin,
			CFrame.lookAt(endlessPos, endlessPos - Vector3.zAxis),
			"∞ ENDLESS: MOST STAGES ∞",
			Vector3.new(16, 11, 0.4)
		),
	}
	local startPrompt = stageDoor(model, origin)
	wardrobe(model, origin)
	-- The trophy shelf: each player's client fills it with their own trophies.
	local shelf = Builders.part({
		name = "TrophyShelf",
		size = Vector3.new(16, 0.6, 2.4),
		cframe = CFrame.new(origin + Vector3.new(16, 7, 20.6)),
		parent = model,
		surface = "DarkWood",
		tag = "TrophyShelf",
	})
	Props.sign(
		model,
		CFrame.lookAt(origin + Vector3.new(16, 5.6, 21.75), origin + Vector3.new(16, 5.6, 0)),
		Vector3.new(9, 1.2, 0.2),
		"YOUR TROPHIES",
		Theme.Colors.Brass,
		"DarkWood"
	)
	local _ = shelf
	titleSign(model, origin)
	Story.lobby({
		set = Builders.folder("Story", model),
		origin = origin,
		rng = Random.new(Config.Map.VisualSeed),
	})
	for _, z in { -12, 12 } do
		Props.stageSpot(
			model,
			origin + Vector3.new(-6, 24, z),
			origin + Vector3.new(0, 3, -15),
			Theme.Colors.WarmSpot,
			40
		)
	end
	return {
		spawn = spawn.CFrame * CFrame.new(0, Config.Map.SpawnHeight, 0),
		startPrompt = startPrompt,
		leaderboardGui = gui,
		modeBoards = modeBoards,
	}
end

return Lobby
