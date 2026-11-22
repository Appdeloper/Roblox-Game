--!strict
--[[
	Theme — THE place to retune the look of the whole game.

	  Theme.Lighting   moonlit-teal mood: ambient, atmosphere/fog, colour grade, bloom, vignette
	  Theme.Surfaces   every Part's Color + Material (+ optional Reflectance/Transparency).
	                   Builders and the mannequin rig ONLY accept a surface name, so changing a
	                   surface here restyles every part that uses it.
	  Theme.Colors     light/glow colours and UI colours
	  Theme.TicketSkins, Theme.Fonts

	Art direction: a haunted school theatre as a toy diorama — chunky, handcrafted, a little
	cartoonish. Deep teal moonlit shadows, warm amber spots, velvet red, aged wood, brass.
	Gameplay rule: anything you can stand on ("Route*" surfaces) is lighter and warmer than the
	set around it, with a glow-tape edge, so the parkour path reads instantly on a small screen.
]]

local Theme = {}

Theme.Colors = {
	-- Light & glow
	MoonTeal = Color3.fromRGB(64, 138, 150),
	DeepTeal = Color3.fromRGB(14, 38, 46),
	AmbientTeal = Color3.fromRGB(28, 56, 64),
	WarmSpot = Color3.fromRGB(255, 196, 120),
	Footlight = Color3.fromRGB(255, 170, 90),
	DoorGlow = Color3.fromRGB(255, 214, 140),
	Window = Color3.fromRGB(255, 220, 150),
	Brass = Color3.fromRGB(214, 168, 72),
	Fog = Color3.fromRGB(90, 150, 160),
	Curtain = Color3.fromRGB(150, 24, 36),

	-- UI
	Ink = Color3.fromRGB(28, 22, 20),
	Paper = Color3.fromRGB(246, 236, 210),
	PaperShade = Color3.fromRGB(226, 210, 176),
	UiDark = Color3.fromRGB(16, 20, 26),
	UiPanel = Color3.fromRGB(26, 32, 42),
	UiAccent = Color3.fromRGB(255, 196, 120),
	UiDanger = Color3.fromRGB(230, 90, 90),
	UiGood = Color3.fromRGB(120, 210, 160),
	White = Color3.new(1, 1, 1),
	Black = Color3.new(0, 0, 0),
}

export type Surface = {
	Color: Color3,
	Material: Enum.Material,
	Reflectance: number?,
	Transparency: number?,
}

local function s(r: number, g: number, b: number, material: Enum.Material, extra: { [string]: number }?): Surface
	local surface: Surface = { Color = Color3.fromRGB(r, g, b), Material = material }
	if extra then
		surface.Reflectance = extra.Reflectance
		surface.Transparency = extra.Transparency
	end
	return surface
end

local M = Enum.Material

Theme.Surfaces = {
	-- Walkable route (high contrast, warm, always lighter than surroundings)
	RouteWood = s(186, 136, 88, M.WoodPlanks),
	RouteFloor = s(150, 104, 66, M.WoodPlanks),
	RouteCardboard = s(204, 160, 104, M.Cardboard),
	RouteSlide = s(56, 126, 196, M.Rubber),
	RouteRoof = s(124, 98, 104, M.Slate),
	GlowTape = s(150, 240, 225, M.Neon),

	-- Wood & stage
	Plank = s(132, 92, 58, M.WoodPlanks),
	PlankLight = s(150, 106, 66, M.WoodPlanks),
	PlankDark = s(112, 76, 48, M.WoodPlanks),
	AgedWood = s(96, 66, 44, M.Wood),
	DarkWood = s(64, 42, 30, M.Wood),
	Ladder = s(170, 124, 80, M.Wood),

	-- Fabric
	Velvet = s(132, 28, 40, M.Fabric),
	Curtain = s(150, 24, 36, M.Fabric),
	CurtainFold = s(104, 14, 24, M.Fabric),
	Carpet = s(112, 22, 32, M.Carpet),
	Rope = s(160, 128, 84, M.Fabric),
	Sandbag = s(150, 132, 98, M.Fabric),
	Net = s(30, 40, 46, M.Fabric),
	CostumeTeal = s(64, 138, 150, M.Fabric),
	CostumePurple = s(96, 64, 110, M.Fabric),
	Cobweb = s(220, 228, 232, M.SmoothPlastic, { Transparency = 0.72 }),

	-- Walls & ceilings
	Plaster = s(40, 46, 58, M.Plaster),
	WallPanel = s(70, 40, 46, M.WoodPlanks),
	Ceiling = s(22, 26, 34, M.Concrete),
	FacadeRose = s(190, 120, 96, M.Plaster),
	FacadeSage = s(110, 150, 120, M.Plaster),
	FacadeOchre = s(200, 170, 110, M.Plaster),
	Roof = s(70, 60, 66, M.Slate),
	Chalkboard = s(30, 48, 40, M.Slate),

	-- Metal & trim
	Brass = s(214, 168, 72, M.Metal, { Reflectance = 0.12 }),
	-- The door star is the single most important thing to notice: polished brighter.
	BrassStar = s(240, 198, 96, M.Metal, { Reflectance = 0.35 }),
	Gilt = s(201, 160, 70, M.Foil),
	Iron = s(34, 36, 42, M.Metal),

	-- Doors, props
	PaintedDoor = s(96, 64, 110, M.WoodPlanks),
	DoorPanelInset = s(76, 48, 90, M.WoodPlanks),
	ExitDoor = s(64, 42, 30, M.WoodPlanks),
	PaintFlat = s(64, 42, 30, M.SmoothPlastic),
	Cardboard = s(176, 138, 92, M.Cardboard),
	PaintRed = s(190, 50, 50, M.SmoothPlastic),
	PaintBlue = s(60, 100, 180, M.SmoothPlastic),
	PaintYellow = s(230, 190, 70, M.SmoothPlastic),
	Paper = s(246, 236, 210, M.SmoothPlastic),
	-- Lore props
	Playbill = s(238, 226, 196, M.SmoothPlastic),
	PlaybillBoard = s(92, 26, 34, M.WoodPlanks),
	TagCard = s(214, 186, 134, M.SmoothPlastic),
	BookPage = s(246, 242, 232, M.SmoothPlastic),
	-- Marks on the floor: flat, faint, and always below standing height.
	ScuffMark = s(28, 24, 26, M.SmoothPlastic, { Transparency = 0.5 }),
	DustPrint = s(226, 232, 230, M.SmoothPlastic, { Transparency = 0.62 }),
	DustFilm = s(214, 222, 224, M.SmoothPlastic, { Transparency = 0.78 }),

	-- Glow (Neon)
	WindowGlow = s(255, 214, 120, M.Neon),
	Footlight = s(255, 170, 90, M.Neon),
	WarmGlow = s(255, 196, 120, M.Neon),
	MoonGlow = s(64, 138, 150, M.Neon),
	DoorGlow = s(255, 214, 140, M.Neon, { Transparency = 1 }),
	-- Floor light spill in front of a lit door; hidden until a client reveals it.
	SpillGlow = s(255, 206, 140, M.Neon, { Transparency = 1 }),
	ExitSign = s(120, 210, 160, M.Neon),

	-- Volumetric-looking light (big, faint, Neon so it glows without a real light source)
	MoonShaft = s(120, 196, 206, M.Neon, { Transparency = 0.9 }),
	WarmBeam = s(255, 206, 142, M.Neon, { Transparency = 0.88 }),
	PaintedMoon = s(226, 238, 228, M.Neon),
	MoonRing = s(150, 176, 182, M.SmoothPlastic),
	Smoke = s(188, 196, 200, M.SmoothPlastic, { Transparency = 0.6 }),

	-- Aged variants: a fraction of the seats are faded and dusty, so rows are not uniform
	VelvetDusty = s(104, 40, 48, M.Fabric),
	CarpetWorn = s(88, 26, 34, M.Carpet),

	-- Hazards & atmosphere
	Fog = s(90, 150, 160, M.SmoothPlastic, { Transparency = 0.82 }),
	Backdrop = s(70, 92, 140, M.Fabric),
	Glass = s(255, 220, 150, M.Glass, { Transparency = 0.75 }),

	-- Mannequin
	Mannequin = s(196, 160, 118, M.Wood),
	MannequinJoint = s(150, 112, 80, M.Wood),

	-- Utility
	ShadowInk = s(0, 0, 0, M.SmoothPlastic, { Transparency = 0.25 }),
	Invisible = s(255, 255, 255, M.SmoothPlastic, { Transparency = 1 }),
}

--- Applies a surface to any BasePart: the ONLY way parts get Color/Material in this game.
--- Errors on an unknown name so a typo surfaces in tests instead of as a grey part.
function Theme.apply(part: BasePart, name: string)
	local surface = (Theme.Surfaces :: any)[name] :: Surface?
	assert(surface, "Unknown Theme surface: " .. tostring(name))
	part.Color = surface.Color
	part.Material = surface.Material
	part.Reflectance = surface.Reflectance or 0
	part.Transparency = surface.Transparency or 0
end

--- Moonlit-teal mood. Applied by MapBuilder/LightingSetup (server) and scaled by Quality (client).
Theme.Lighting = {
	ClockTime = 0,
	Brightness = 1.2,
	Ambient = Color3.fromRGB(34, 62, 72), -- teal fill: every shadow leans teal
	OutdoorAmbient = Color3.fromRGB(18, 40, 50),
	EnvironmentDiffuseScale = 0.3,
	EnvironmentSpecularScale = 0.35,
	ExposureCompensation = 0.2,
	ShadowSoftness = 0.35,
	-- Atmosphere = light moonlit fog inside the sealed rooms.
	AtmosphereDensity = 0.3,
	AtmosphereHaze = 1.4,
	AtmosphereColor = Color3.fromRGB(40, 86, 98),
	AtmosphereDecay = Color3.fromRGB(14, 38, 46),
	-- Grade: lifts warm highlights while the teal ambient keeps the shadows cool.
	GradeTint = Color3.fromRGB(255, 244, 228),
	GradeContrast = 0.14,
	GradeSaturation = 0.06,
	GradeBrightness = 0.01,
	BloomIntensity = 0.45,
	BloomSize = 24,
	BloomThreshold = 1.5,
	-- Client vignette (GUI): edge darkness 0..1 (0 = off).
	VignetteStrength = 0.38,
	VignetteColor = Color3.fromRGB(4, 14, 18),
}

-- Ticket skin palettes (keys match Config.TicketSkins).
Theme.TicketSkins = {
	Classic = {
		Paper = Color3.fromRGB(246, 236, 210),
		Ink = Color3.fromRGB(70, 30, 30),
		Border = Color3.fromRGB(170, 60, 50),
	},
	OpeningNight = {
		Paper = Color3.fromRGB(250, 244, 230),
		Ink = Color3.fromRGB(30, 30, 60),
		Border = Color3.fromRGB(214, 168, 72),
	},
	VelvetCurtain = {
		Paper = Color3.fromRGB(250, 236, 220),
		Ink = Color3.fromRGB(90, 16, 26),
		Border = Color3.fromRGB(150, 20, 34),
	},
	Golden = {
		Paper = Color3.fromRGB(255, 226, 140),
		Ink = Color3.fromRGB(80, 50, 10),
		Border = Color3.fromRGB(200, 140, 30),
	},
	Moonlit = {
		Paper = Color3.fromRGB(200, 232, 236),
		Ink = Color3.fromRGB(16, 56, 66),
		Border = Color3.fromRGB(64, 138, 150),
	},
}

Theme.Fonts = {
	Title = Enum.Font.Bodoni,
	Body = Enum.Font.GothamMedium,
	Bold = Enum.Font.GothamBold,
	Ticket = Enum.Font.Garamond,
	Mono = Enum.Font.RobotoMono,
}

return Theme
