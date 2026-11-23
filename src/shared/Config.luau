--!strict
--[[
	Config — every gameplay tunable in one place.

	Rules:
	  * Plain data only (numbers, strings, booleans, tables). No Roblox types, so this module
	    can be required by the offline test runner (`luau tests/run.luau`).
	  * Colours and fonts live in Theme.luau, asset IDs in Assets.luau.
	  * IDs set to 0 are PLACEHOLDERS. Systems skip/disable themselves gracefully while an ID is 0.
]]

local Config = {}

Config.Game = {
	Name = "Don't Look Backstage",
	StageCount = 6,
	-- Bump when you ship a change that should show in the lobby footer.
	BuildLabel = "v1.0.0",
}

-- Character physics. MapBuilder validates every jump gap against these numbers.
Config.Movement = {
	WalkSpeed = 16,
	JumpPower = 50,
	Gravity = 196.2,
	RespawnTime = 1.5,
}

-- Forgiving controls (client-side feel; the server still judges every outcome).
Config.Feel = {
	-- Jump this long after running off an edge and it still counts.
	CoyoteSeconds = 0.12,
	-- Press jump this long before landing and you jump the moment you land.
	BufferSeconds = 0.15,
	-- Ledge forgiveness: falling just short of a platform's edge (within LedgeReach studs out
	-- and LedgeLift studs below its top) pops you up onto it.
	LedgeReach = 0.9,
	LedgeLift = 1.2,
	-- Phones and tablets: a closer, steadier camera that keeps the route in view.
	TouchCamera = { MinZoom = 10, MaxZoom = 26, FieldOfView = 74 },
}

Config.Map = {
	-- Spec: every jump gap must be under 70 % of the theoretical max jump distance.
	MaxGapRatio = 0.7,
	-- Same safety ratio applied to how high a jump may climb.
	MaxRiseRatio = 0.7,
	-- A player whose root part drops this far below the stage's lowest walkable surface has fallen.
	KillMargin = 5,
	-- Studs above a spawn pad where characters are placed (root part height).
	SpawnHeight = 3,
	-- World offsets for each area. Stages are sealed rooms, so they never see each other.
	-- Everything sits 400 studs up so Studio template parts (Baseplate, flat terrain at y≈0)
	-- can never poke into the stage pits, whatever place you sync into.
	LobbyOrigin = { 0, 400, -220 },
	StageOrigins = {
		{ 0, 400, 0 },
		{ 0, 400, 260 },
		{ 0, 400, 520 },
		{ 0, 400, 780 },
		{ 0, 400, 1040 },
		{ 0, 400, 1300 },
	},
	SupportPostThickness = 0.8,
	-- Seed for all set-dressing randomness (seat variety, plank shades, ropes, prop jitter).
	-- Same seed = identical map every build; change it to reshuffle the look.
	VisualSeed = 1984,
}

Config.Mannequin = {
	-- Spec: the mannequin copies the player 1.5 s late.
	Delay = 1.5,
	-- Spec: record the player's CFrame at 20 Hz.
	SampleRate = 20,
	-- If the mannequin fell further behind than Delay (scare pause), it replays faster until caught up.
	CatchUpRate = 1.25,
	-- If a shortcut put it closer than Delay, it replays slower until back to Delay.
	DriftBackRate = 0.85,
	-- Seconds to blend from its home spot onto the first trail sample.
	EmergeSeconds = 0.6,
	-- Recording only starts once the player walks this far from the stage entrance,
	-- so nobody is caught while reading the title card.
	StartMoveDistance = 3,
	-- Hard cap on trail memory, regardless of pauses.
	MaxTrailSeconds = 30,
	-- Height of the rig's root above its feet (matches R6/R15 HumanoidRootPart height).
	RootHeight = 3,
	-- Other players' mannequins are faded on your screen to this transparency.
	OtherPlayersTransparency = 0.75,
	-- Inside this distance (and able to catch) it reaches for you with both arms.
	ReachDistance = 9,
	-- Understudy: extra mannequins replaying the same trail, each later than the last.
	UnderstudyDelays = { 2.6, 3.8 },
	-- Per-stage override (the finale fields the full cast).
	UnderstudyDelaysByStage = {
		[4] = { 3.0 },
		[6] = { 2.2, 3.0, 3.8 },
	},
	-- Mirror: a reflection that walks the route toward you from a point ahead. It can't catch
	-- you, but stare at it too long and it steps out of the glass and joins the chase.
	Mirror = {
		-- Seconds of lag on the reflection (it mirrors you a beat late).
		Delay = 0.35,
		-- It cracks and vanishes when you get this close (studs along the route) to the mirror point.
		VanishGap = 4,
	},
	-- "Don't Look": watching a mannequin freezes it; staring too long makes it lunge.
	Look = {
		-- View cone used by the client to decide you're looking at it.
		MaxAngleDegrees = 16,
		MaxRange = 70,
		-- Seconds of continuous looking before the lights flicker and it lunges.
		StareSeconds = 2.2,
		-- After a lunge it ignores your gaze for this long.
		CooldownSeconds = 3,
		-- Stare meter drained per second while you look away (1 = empties in a second).
		DrainRate = 0.8,
		-- A lunge skips this much of the trail (seconds), but never closer than MinGapSeconds behind you.
		LungeSeconds = 0.6,
		MinGapSeconds = 0.55,
		-- The server ignores look reports for mannequins further away than this.
		ServerRange = 90,
	},
}

-- Which mannequin behaviours each stage uses. They escalate:
--   Copycat    your mannequin copies you Delay seconds late (always on)
--   Shortcut   it takes painted doors when you pass them (stages whose layout has doors)
--   Mirror     a reflection walks toward you from ahead (stages with a mirror in Config.Mirrors)
--   Understudy extra mannequins with longer delays (Config.Mannequin.UnderstudyDelays)
Config.Behaviours = {
	{ "Copycat", "Shortcut" },
	{ "Copycat", "Shortcut", "Mirror" },
	{ "Copycat", "Shortcut", "Understudy" },
	{ "Copycat", "Understudy" },
	{ "Copycat", "Mirror", "Understudy" },
	-- Opening Night: the full cast at once.
	{ "Copycat", "Shortcut", "Mirror", "Understudy" },
}

-- Mirror points as fractions of the stage's route length: it appears once you pass `From`
-- and stands at the reflection of your progress across `Plane`.
Config.Mirrors = {
	[2] = { From = 0.06, Plane = 0.62 },
	[5] = { From = 0.05, Plane = 0.6 },
	[6] = { From = 0.05, Plane = 0.62 },
}

-- Game modes (rules in shared/Modes.luau).
Config.Modes = {
	Daily = {
		-- Stages in a Daily Run (always ends on the finale).
		Length = 4,
		-- One OrderedDataStore per UTC day: StoreName .. "_" .. dayNumber.
		StoreName = "DailyBest_v1",
	},
	Endless = {
		-- Catches/falls you can take before the run ends.
		Lives = 3,
		-- The Copycat's delay starts at the story delay and shrinks every stage cleared.
		BaseDelay = 1.5,
		DelayStep = 0.06,
		MinDelay = 0.9,
		-- Best stages cleared (higher is better).
		StoreName = "EndlessBest_v1",
	},
	Coop = {
		MaxPlayers = 4,
		-- Seconds after the first player picks Co-op before the show starts.
		GatherSeconds = 10,
		-- Stand this close to a downed teammate for this long to revive them.
		ReviveRadius = 7,
		ReviveSeconds = 1.5,
	},
}

Config.Catch = {
	Distance = 3,
	VerticalTolerance = 4,
	-- After a respawn the mannequin cannot catch you for this long (no re-catch loops).
	GraceSeconds = 3,
	-- Time between "CUT!" and the respawn teleport (covers the fade).
	RespawnDelay = 0.8,
}

Config.Door = {
	-- The exit door warns (handle turns, light under door, creak) for at least this long before it opens.
	MinWarningSeconds = 1.6,
	-- Speed the mannequin glides to the entry door once a shortcut starts.
	ApproachSpeed = 40,
	-- Default speed along the hidden preset path (layouts may override per door).
	DefaultPathSpeed = 24,
	-- After stepping out, the mannequin rejoins the trail at the closest sample within this radius.
	RejoinRadius = 9,
	-- ...but never closer than this many seconds behind the player.
	MinRejoinDelay = 0.9,
	-- If the player hasn't passed the exit yet, it waits this long, then returns to normal trailing.
	AmbushSeconds = 4,
	HandleTurnDegrees = 50,
	HandleTurnSeconds = 0.35,
}

Config.Retakes = {
	CountCatches = true,
	CountFalls = true,
	CountDeaths = true,
}

Config.Zones = {
	-- Server zone watcher tick (exits, doors, scares, kill nets). 10 Hz is plenty for triggers.
	CheckInterval = 0.1,
}

Config.Scares = {
	-- Scares play once per run; retakes skip them so they never become a chore.
	PlayOncePerRun = true,
	CaptionSeconds = 2.6,
	Stage1 = {
		-- Catching is paused while the scare plays.
		CatchPause = 4.5,
		ShadowBowSeconds = 1.4,
		MannequinBowDelay = 1.2,
		MannequinBowSeconds = 1.6,
	},
	Stage2 = {
		CatchPause = 3,
		WindowWalkSeconds = 4,
		HandleTurns = 3,
	},
	Stage3 = {
		CatchPause = 4.5,
		KnockToApplauseSeconds = 1.5,
		ApplauseSeconds = 3.5,
	},
	-- The Flies: a light rig drops on its chain and its spot finds you.
	Stage4 = {
		CatchPause = 3.5,
		DropSeconds = 0.6,
		SpotSeconds = 2.4,
	},
	-- The Prop Room: every costume on the rail turns to look at you.
	Stage5 = {
		CatchPause = 3.5,
		TurnSeconds = 1.2,
		HoldSeconds = 2,
	},
	-- Opening Night: house lights up, the audience is mannequins, and they stand.
	Stage6 = {
		CatchPause = 4,
		LightsUpSeconds = 0.8,
		StandSeconds = 1.6,
		ApplauseSeconds = 3,
	},
}

Config.Hazards = {
	-- A light-rig beam only counts once it has been on the gate this long (seconds), so a
	-- crossing that looked clear on a laggy phone stays clear.
	BeamLeniency = 0.15,
	Backdrop = {
		DescendSeconds = 3.4,
		HoldSeconds = 1.6,
		RiseSeconds = 1.4,
		-- Gap left under the closed backdrop (too small to fit through).
		ClosedGap = 0.4,
	},
	Staircase = {
		-- Time from first touch to the step dropping.
		CollapseDelay = 0.7,
		-- Part of CollapseDelay spent visibly wobbling (the warning).
		WobbleSeconds = 0.45,
		FallDistance = 30,
		FallSeconds = 0.8,
		ResetSeconds = 4,
	},
	-- Friction on the slide mat (0 = ice).
	SlideFriction = 0,
}

Config.Run = {
	-- Seconds a player must wait between run start requests.
	StartCooldown = 2,
	-- Seconds the stage transition fade lasts.
	TransitionSeconds = 0.6,
	TitleCardSeconds = 2.8,
}

Config.AntiCheat = {
	-- Clears faster than these (seconds) are ignored for the leaderboard/badges.
	MinStageSeconds = { 5, 6, 4, 6, 6, 5 },
	MinRunSeconds = 20,
}

Config.Data = {
	StoreName = "PlayerProfiles",
	KeyPrefix = "player_",
	SchemaVersion = 3,
	MaxRetries = 4,
	RetryBaseDelay = 1,
	AutosaveSeconds = 120,
	-- Processed purchase IDs kept per profile (oldest pruned first).
	MaxReceiptHistory = 200,
	-- Max seconds BindToClose waits for saves to finish.
	ShutdownTimeout = 25,
}

Config.Leaderboard = {
	StoreName = "BestTimes_v1",
	Entries = 10,
	RefreshSeconds = 60,
	-- OrderedDataStore stores integers: times are saved as centiseconds.
	TimeScale = 100,
}

-- PLACEHOLDER badge IDs. Create badges on the Creator Dashboard and paste the IDs here.
Config.Badges = {
	FirstEscape = 0,
	OpeningNight = 0,
	SpottedTheDoor = 0,
	StareDown = 0,
	MirrorMirror = 0,
	FullHouse = 0,
	DailyDouble = 0,
	DailyDevotee = 0,
	EndlessTen = 0,
	CastParty = 0,
	RevivalAct = 0,
}

-- Trophies: what the trophy shelf in the lobby shows. Each one also awards the badge of the
-- same key (Config.Badges) through BadgeService, server-side. Order = shelf position.
Config.Trophies = {
	FirstEscape = { Order = 1, DisplayName = "First Escape", Description = "Escape the theatre." },
	OpeningNight = { Order = 2, DisplayName = "Opening Night", Description = "Escape with zero retakes." },
	SpottedTheDoor = { Order = 3, DisplayName = "Spotted the Door", Description = "Outrun a painted-door shortcut." },
	StareDown = {
		Order = 4,
		DisplayName = "Stare Down",
		Description = "Make a mannequin lunge, then still clear the stage.",
	},
	MirrorMirror = {
		Order = 5,
		DisplayName = "Mirror, Mirror",
		Description = "Run past your reflection until it cracks.",
	},
	FullHouse = { Order = 6, DisplayName = "Full House", Description = "Clear Opening Night." },
	DailyDouble = { Order = 7, DisplayName = "Daily Double", Description = "Finish a Daily Run." },
	DailyDevotee = { Order = 8, DisplayName = "Daily Devotee", Description = "Visit three days in a row." },
	EndlessTen = { Order = 9, DisplayName = "Long Run", Description = "Clear 10 stages in one Endless run." },
	CastParty = { Order = 10, DisplayName = "Cast Party", Description = "Finish Co-op with a friend." },
	RevivalAct = { Order = 11, DisplayName = "Revival", Description = "Revive a teammate in Co-op." },
}

-- Ticket stubs for the ticket book: one per act cleared, plus one per mode finished.
Config.Stubs = {
	Act1 = { Order = 1, DisplayName = "Act I" },
	Act2 = { Order = 2, DisplayName = "Act II" },
	Act3 = { Order = 3, DisplayName = "Act III" },
	Act4 = { Order = 4, DisplayName = "Act IV" },
	Act5 = { Order = 5, DisplayName = "Act V" },
	Act6 = { Order = 6, DisplayName = "Act VI" },
	Daily = { Order = 7, DisplayName = "Daily Run" },
	Endless = { Order = 8, DisplayName = "Endless" },
	Coop = { Order = 9, DisplayName = "Co-op" },
}

-- Cosmetics earned by playing (none of them change gameplay). Unlock.Kind:
--   "Free" | "Title" (Config.Titles key) | "Trophy" (Config.Trophies key) |
--   "Streak" (best daily streak >= Key) | "GamePass" (Config.Monetization.GamePasses key) |
--   "Product" (Config.Monetization.Products key: bought once, kept forever)
-- Colours are RGB 0..255.
Config.Cosmetics = {
	Trail = {
		None = { Order = 1, DisplayName = "No trail", Color = { 60, 60, 70 }, Unlock = { Kind = "Free" } },
		Spotlight = {
			Order = 2,
			DisplayName = "Spotlight",
			Color = { 255, 214, 140 },
			Unlock = { Kind = "GamePass", Key = "SpotlightTrail" },
		},
		StageDust = {
			Order = 3,
			DisplayName = "Stage Dust",
			Color = { 214, 200, 170 },
			Unlock = { Kind = "Streak", Key = 2 },
		},
		Confetti = {
			Order = 4,
			DisplayName = "Confetti",
			Color = { 236, 120, 200 },
			Unlock = { Kind = "Trophy", Key = "FullHouse" },
		},
		Moonbeam = {
			Order = 5,
			DisplayName = "Moonbeam",
			Color = { 120, 214, 224 },
			Unlock = { Kind = "Trophy", Key = "EndlessTen" },
		},
		Sparkler = {
			Order = 6,
			DisplayName = "Sparkler",
			Color = { 255, 200, 80 },
			Unlock = { Kind = "Product", Key = "SparklerTrail" },
		},
	},
	MannequinSkin = {
		Pine = { Order = 1, DisplayName = "Pine", Color = { 196, 160, 118 }, Unlock = { Kind = "Free" } },
		Ebony = {
			Order = 2,
			DisplayName = "Ebony",
			Color = { 58, 44, 40 },
			Unlock = { Kind = "Title", Key = "OpeningNight" },
		},
		Painted = {
			Order = 3,
			DisplayName = "Painted",
			Color = { 92, 140, 196 },
			Unlock = { Kind = "Trophy", Key = "MirrorMirror" },
		},
		Gilded = {
			Order = 4,
			DisplayName = "Gilded",
			Color = { 214, 168, 72 },
			Unlock = { Kind = "Trophy", Key = "StareDown" },
		},
		Porcelain = {
			Order = 5,
			DisplayName = "Porcelain",
			Color = { 236, 232, 224 },
			Unlock = { Kind = "Streak", Key = 7 },
		},
		Marble = {
			Order = 6,
			DisplayName = "Marble",
			Color = { 214, 218, 226 },
			Unlock = { Kind = "Product", Key = "MarbleMannequin" },
		},
	},
	Playbill = {
		Classic = { Order = 1, DisplayName = "Classic", Color = { 150, 24, 36 }, Unlock = { Kind = "Free" } },
		Midnight = {
			Order = 2,
			DisplayName = "Midnight",
			Color = { 24, 40, 84 },
			Unlock = { Kind = "Streak", Key = 3 },
		},
		Sunrise = {
			Order = 3,
			DisplayName = "Sunrise",
			Color = { 220, 120, 64 },
			Unlock = { Kind = "Trophy", Key = "DailyDouble" },
		},
		Velvet = {
			Order = 4,
			DisplayName = "Velvet",
			Color = { 96, 32, 110 },
			Unlock = { Kind = "Trophy", Key = "CastParty" },
		},
		Starlight = {
			Order = 5,
			DisplayName = "Starlight",
			Color = { 30, 60, 110 },
			Unlock = { Kind = "GamePass", Key = "PlaybillCollection" },
		},
		Gaslight = {
			Order = 6,
			DisplayName = "Gaslight",
			Color = { 120, 96, 40 },
			Unlock = { Kind = "GamePass", Key = "PlaybillCollection" },
		},
	},
}
Config.DefaultCosmetics = { Trail = "None", MannequinSkin = "Pine", Playbill = "Classic" }

Config.Titles = {
	OpeningNight = { DisplayName = "Opening Night", Description = "Escaped with zero retakes." },
	FirstEscape = { DisplayName = "Understudy", Description = "Escaped the theatre for the first time." },
	DoorSpotter = { DisplayName = "Door Spotter", Description = "Outran a painted-door shortcut." },
}

-- PLACEHOLDER monetization IDs. Everything sold here is cosmetic only.
Config.Monetization = {
	GamePasses = {
		SpotlightTrail = {
			Id = 0,
			DisplayName = "Spotlight Trail",
			Description = "A warm spotlight glow follows you around the theatre.",
		},
		VelvetCurtainBorder = {
			Id = 0,
			DisplayName = "Velvet Curtain Border",
			Description = "A red velvet curtain frame for your finish ticket.",
			GrantsSkin = "VelvetCurtain",
		},
		PlaybillCollection = {
			Id = 0,
			DisplayName = "Playbill Collection",
			Description = "Two extra playbill backgrounds for your stage title cards.",
		},
	},
	Products = {
		GoldenTicketSkin = {
			Id = 0,
			DisplayName = "Golden Ticket Skin",
			Description = "A shiny gold finish ticket.",
			GrantsSkin = "Golden",
		},
		MoonlitTicketSkin = {
			Id = 0,
			DisplayName = "Moonlit Ticket Skin",
			Description = "A teal, moon-silver finish ticket.",
			GrantsSkin = "Moonlit",
		},
		SparklerTrail = {
			Id = 0,
			DisplayName = "Sparkler Trail",
			Description = "A fizzing golden trail. Cosmetic only.",
			GrantsCosmetic = { "Trail", "Sparkler" },
		},
		MarbleMannequin = {
			Id = 0,
			DisplayName = "Marble Mannequin",
			Description = "Your Copycat in cool white marble. Cosmetic only.",
			GrantsCosmetic = { "MannequinSkin", "Marble" },
		},
	},
}

-- Ticket skins. Unlock.Kind: "Free" | "GamePass" | "Product" | "Title".
Config.TicketSkins = {
	Classic = { Order = 1, DisplayName = "Classic Stub", Unlock = { Kind = "Free", Key = "" } },
	OpeningNight = { Order = 2, DisplayName = "Opening Night", Unlock = { Kind = "Title", Key = "OpeningNight" } },
	VelvetCurtain = {
		Order = 3,
		DisplayName = "Velvet Curtain",
		Unlock = { Kind = "GamePass", Key = "VelvetCurtainBorder" },
	},
	Golden = { Order = 4, DisplayName = "Golden Ticket", Unlock = { Kind = "Product", Key = "GoldenTicketSkin" } },
	Moonlit = { Order = 5, DisplayName = "Moonlit", Unlock = { Kind = "Product", Key = "MoonlitTicketSkin" } },
}
Config.DefaultTicketSkin = "Classic"

Config.Remotes = {
	-- Token bucket per player per remote.
	RatePerSecond = 4,
	Burst = 8,
}

Config.Analytics = {
	Enabled = true,
	PrintEvents = true,
	-- Flip on to also forward events to AnalyticsService:LogCustomEvent.
	UseRobloxAnalytics = false,
}

Config.UI = {
	-- UI is authored for a 720-px short side and scaled with UIScale.
	ReferenceShortSide = 720,
	MinScale = 0.7,
	MaxScale = 1.35,
	JumpButtonSize = 150,
	MinTouchTarget = 64,
	TweenFast = 0.18,
	TweenMedium = 0.35,
	TweenSlow = 0.7,
}

Config.Audio = {
	-- Heartbeat starts at this distance (studs) and peaks at Config.Catch.Distance.
	HeartbeatRange = 45,
	HeartbeatMinSpeed = 0.8,
	HeartbeatMaxSpeed = 2.0,
	HeartbeatMaxVolume = 0.8,
	CreakVolume = 0.45,
	-- Mannequin creaks only while it moves faster than this.
	CreakMinSpeed = 2,
	AmbienceVolume = 0.3,
	SfxVolume = 0.7,
}

--- Quality presets. "Auto" picks Low on touch devices and High elsewhere.
--- Every value is a plain number/boolean so this stays unit-testable offline.
Config.Quality = {
	Default = "Auto",
	Order = { "Low", "Medium", "High" },
	Levels = {
		Low = {
			-- Big transparent light volumes are pure overdraw: off entirely.
			LightShafts = false,
			ParticleScale = 0,
			Shadows = false,
			Bloom = false,
			Vignette = 0.6,
			-- Mannequin limb animation and pendulums stop sooner.
			AnimationRange = 80,
			SwingRange = 70,
			CurtainSway = false,
		},
		Medium = {
			LightShafts = true,
			ShaftFade = 0.04,
			ParticleScale = 0.55,
			Shadows = true,
			Bloom = true,
			Vignette = 0.85,
			AnimationRange = 130,
			SwingRange = 110,
			CurtainSway = true,
		},
		High = {
			LightShafts = true,
			ShaftFade = 0,
			ParticleScale = 1,
			Shadows = true,
			Bloom = true,
			Vignette = 1,
			AnimationRange = 170,
			SwingRange = 150,
			CurtainSway = true,
		},
	},
}

Config.Performance = {
	-- Hard ceiling for everything under Workspace.Map. Checked by the smoke tests so the
	-- map can never quietly grow past what a phone can draw.
	MaxParts = 12000,
	-- Where we expect to sit; a big gap means there is room for more detail.
	TargetParts = 6000,
	-- Real lights are the expensive part on a phone, so each room gets a hard cap.
	MaxLightsPerStage = 30,
	-- Particle emitters per stage (dust, smoke).
	MaxEmittersPerStage = 6,
}

--- Layered 3D ambience. Each layer is a looping sound placed in the world by
--- AmbienceService; the rolloff numbers are what make it fade naturally as you move.
Config.Ambience = {
	Layers = {
		Drip = { asset = "AmbientDrip", min = 8, max = 65 },
		Wind = { asset = "AmbientWind", min = 25, max = 150 },
		Wood = { asset = "AmbientWood", min = 12, max = 80 },
		Piano = { asset = "AmbientPiano", min = 18, max = 110 },
		Applause = { asset = "AmbientApplause", min = 30, max = 170 },
	},
	-- Room reverb, applied per stage to the ambience sound group on each client.
	-- DecayTime is how long the tail rings; WetLevel is how much of it you hear (dB).
	Reverb = {
		Lobby = { DecayTime = 1.1, Density = 0.7, Diffusion = 0.7, WetLevel = -9, DryLevel = 0 },
		Stages = {
			-- A big empty hall: long tail, very present.
			{ DecayTime = 3.4, Density = 1, Diffusion = 1, WetLevel = -2, DryLevel = 0 },
			-- Outdoors between painted flats: short and dry.
			{ DecayTime = 1.3, Density = 0.5, Diffusion = 0.6, WetLevel = -10, DryLevel = 0 },
			-- Boxy backstage timber.
			{ DecayTime = 2.1, Density = 0.9, Diffusion = 0.85, WetLevel = -5, DryLevel = 0 },
			-- High in the flies: airy, a long thin tail.
			{ DecayTime = 2.8, Density = 0.6, Diffusion = 0.9, WetLevel = -4, DryLevel = 0 },
			-- A cramped prop store full of soft costumes: short and muffled.
			{ DecayTime = 0.9, Density = 1, Diffusion = 0.5, WetLevel = -12, DryLevel = 0 },
			-- The full house: big, warm, applause-friendly.
			{ DecayTime = 3, Density = 1, Diffusion = 1, WetLevel = -3, DryLevel = 0 },
		},
	},
	-- Seconds to cross-fade between rooms, so reverb never changes with a click.
	ReverbBlend = 1.2,
}

Config.Effects = {
	ShakeIntensity = 0.35,
	ShakeSeconds = 0.35,
	FlashSeconds = 0.25,
	CurtainSwayDegrees = 1.6,
	CurtainSwaySeconds = 4,
	DustRate = 6,
	-- Mannequins further than this are not animated on the client (saves frame time).
	AnimationRange = 160,
}

Config.Stages = {
	{
		Title = "The Empty Auditorium",
		Act = "ACT I",
		Hint = "Hop the tipped-over seats. Keep moving!",
	},
	{
		Title = "The Painted Street",
		Act = "ACT II",
		Hint = "Climb the ladder, cross the roofs, slide under the backdrop.",
	},
	{
		Title = "Curtain Call",
		Act = "ACT III",
		Hint = "Run down the stairs. Only one exit is real.",
	},
	{
		Title = "The Flies",
		Act = "ACT IV",
		Hint = "Cross the catwalks while the light rigs look away.",
	},
	{
		Title = "The Prop Room",
		Act = "ACT V",
		Hint = "Jump while the crates are big. Don't ride the belt.",
	},
	{
		Title = "Opening Night",
		Act = "ACT VI",
		Hint = "The whole cast is here. Find the one real exit!",
	},
}

Config.Text = {
	Intro = "You wake up onstage. The house lights are off.",
	Caught = "CUT! Take it from the top.",
	Fell = "Missed your mark! Back to places.",
	FakeExit = "It's only paint!",
	Spotted = "Caught in the spotlight! Back to places.",
	LookHint = "Look at the mannequin and it freezes. Stare too long and it moves closer!",
	StareLunge = "You stared too long. It moved closer!",
	MirrorCracked = "Crack! Your reflection is gone... for now.",
	SavingDisabled = "Your progress couldn't load, so saving is paused this visit.",
}

return Config
