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
	StageCount = 3,
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
}

Config.Hazards = {
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
	MinStageSeconds = { 5, 6, 4 },
	MinRunSeconds = 20,
}

Config.Data = {
	StoreName = "PlayerProfiles",
	KeyPrefix = "player_",
	SchemaVersion = 2,
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
}

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
}

Config.Text = {
	Intro = "You wake up onstage. The house lights are off.",
	Caught = "CUT! Take it from the top.",
	Fell = "Missed your mark! Back to places.",
	FakeExit = "It's only paint!",
	SavingDisabled = "Your progress couldn't load, so saving is paused this visit.",
}

return Config
