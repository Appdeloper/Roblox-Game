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
	-- Stage 3 only: which exit is real ("Left" | "Right").
	realExit: string?,
	-- Server time (workspace:GetServerTimeNow()) when the run began; drives the HUD timer.
	runStartedAt: number,
	retakes: number,
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
	Settings: { ReducedScares: boolean },
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

export type StageInfo = {
	index: number,
	entrance: CFrame,
	mannequinHome: CFrame,
	killY: number,
	exitZone: ZoneInfo?,
	scareZone: ZoneInfo?,
	doors: { DoorInfo },
	-- Stage 3 only.
	exitLeftZone: ZoneInfo?,
	exitRightZone: ZoneInfo?,
}

export type MapInfo = {
	lobbySpawn: CFrame,
	stages: { StageInfo },
}

-- ModuleScripts must return exactly one non-nil value; the types above are the real export.
return {}
