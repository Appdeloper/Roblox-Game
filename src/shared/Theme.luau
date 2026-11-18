--!strict
--[[
	Theme — colours, materials and fonts. Part of the config surface (kept apart from Config.luau
	only because Color3/Enum values don't exist in the offline test runner).
]]

local Theme = {}

Theme.Colors = {
	-- Lighting
	MoonTeal = Color3.fromRGB(64, 138, 150),
	DeepTeal = Color3.fromRGB(14, 38, 46),
	AmbientTeal = Color3.fromRGB(28, 56, 64),
	WarmSpot = Color3.fromRGB(255, 196, 120),
	Footlight = Color3.fromRGB(255, 170, 90),
	DoorGlow = Color3.fromRGB(255, 214, 140),

	-- Set dressing
	StageWood = Color3.fromRGB(120, 82, 52),
	DarkWood = Color3.fromRGB(64, 42, 30),
	SeatVelvet = Color3.fromRGB(132, 28, 40),
	Curtain = Color3.fromRGB(150, 24, 36),
	Wall = Color3.fromRGB(40, 46, 58),
	Ceiling = Color3.fromRGB(22, 26, 34),
	Net = Color3.fromRGB(30, 40, 46),
	Fog = Color3.fromRGB(90, 150, 160),
	Brass = Color3.fromRGB(214, 168, 72),
	PaintedDoor = Color3.fromRGB(96, 64, 110),
	Cardboard = Color3.fromRGB(176, 138, 92),
	SlideMat = Color3.fromRGB(46, 108, 168),
	Backdrop = Color3.fromRGB(70, 92, 140),
	Facade = { Color3.fromRGB(190, 120, 96), Color3.fromRGB(110, 150, 120), Color3.fromRGB(200, 170, 110) },
	Roof = Color3.fromRGB(70, 60, 66),
	Window = Color3.fromRGB(255, 220, 150),
	Mannequin = Color3.fromRGB(196, 160, 118),
	MannequinJoint = Color3.fromRGB(150, 112, 80),
	Chalkboard = Color3.fromRGB(30, 48, 40),

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
