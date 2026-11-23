--!strict
--[[
	Types — shared type definitions for server and client.
	Keep these structural (plain tables) so they can travel through RemoteEvents.
]]

export type RunPhase = "Lobby" | "Running" | "Transition" | "Finished"

-- Sent to the client whenever a stage (re)starts.
export type StageStartInfo = {
	stage: number,
	title: string,
	act: string,
	hint: string,
	isRetake: boolean,
	-- Stages with a choice of exits: the name of the real one.
	realExit: string?,
	-- Server time (workspace:GetServerTimeNow()) when the run began; drives the HUD timer.
	runStartedAt: number,
	retakes: number,
	-- "Story" | "Daily" | "Endless" | "Coop"
	mode: string?,
	-- Endless: lives left.
	lives: number?,
	-- Position in the run's stage list, and its length (nil in Endless: it never ends).
	step: number?,
	steps: number?,
}

-- The theatre ticket shown on the finish screen.
export type TicketData = {
	escapeTime: number,
	retakes: number,
	bestTime: number?,
	isNewBest: boolean,
	titleEarned: string?,
	skin: string,
	playerName: string,
	seat: string,
	mode: string?,
	stagesCleared: number?,
}

export type ProfileSnapshot = {
	bestTime: number?,
	totalEscapes: number,
	titles: { string },
	ownedSkins: { string },
	equippedSkin: string,
	ownsSpotlightTrail: boolean,
	trailEnabled: boolean,
	reducedScares: boolean,
	quality: string,
	savingEnabled: boolean,
}

-- Persisted profile (DataStore value). Version is migrated by DataService.
export type ProfileData = {
	Version: number,
	BestTime: number?,
	BestRetakes: number?,
	TotalEscapes: number,
	TotalRetakes: number,
	Titles: { [string]: boolean },
	OwnedSkins: { [string]: boolean },
	EquippedSkin: string,
	TrailEnabled: boolean,
	Settings: { ReducedScares: boolean, Quality: string },
	-- purchaseId -> os.time() when granted. Guards ProcessReceipt against double credit.
	ProcessedReceipts: { [string]: number },
}

export type LeaderboardEntry = {
	rank: number,
	name: string,
	time: number,
}

-- Server-side description of one painted-door shortcut (built by MapBuilder).
export type DoorInfo = {
	id: string,
	stage: number,
	triggerCFrame: CFrame,
	triggerSize: Vector3,
	-- Where the mannequin slips into the entry door.
	entryPoint: Vector3,
	-- Hidden waypoints behind the scenery.
	path: { Vector3 },
	-- Where it steps out (on the player route, ahead of the trigger).
	exitStep: Vector3,
	exitFacing: Vector3,
	pathSpeed: number,
}

export type ZoneInfo = {
	cframe: CFrame,
	size: Vector3,
}

-- A rotating light rig whose beam lands on `gate` (judged by the server from shared/Motion).
export type SpinnerInfo = {
	id: string,
	motion: { period: number, phase: number?, aim: number?, halfWidth: number? },
	gate: ZoneInfo,
}

export type ExitInfo = {
	name: string,
	zone: ZoneInfo,
	canBeReal: boolean,
}

export type StageInfo = {
	index: number,
	entrance: CFrame,
	mannequinHome: CFrame,
	killY: number,
	exitZone: ZoneInfo?,
	scareZone: ZoneInfo?,
	doors: { DoorInfo },
	-- Walkable route as mannequin-root-height points, entrance to exit (Mirror uses it).
	routePath: { Vector3 }?,
	-- Stages with a choice of exits (one real per run, the rest painted fakes).
	exits: { ExitInfo }?,
	-- Stage 4: light-rig beams.
	spinners: { SpinnerInfo }?,
}

export type MapInfo = {
	lobbySpawn: CFrame,
	stages: { StageInfo },
}

-- ModuleScripts must return exactly one non-nil value; the types above are the real export.
return {}
