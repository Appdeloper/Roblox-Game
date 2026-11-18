--!strict
--[[
	LayoutTypes — shape of the pure-data stage layouts in ./Layouts.
	All coordinates are LOCAL to the stage origin (Config.Map.StageOrigins[i]), as { x, y, z }.
	Layout files contain no requires so the offline test runner can load them.
]]

export type Vec = { number }

export type Box = { center: Vec, size: Vec }

-- How the player gets from the previous route element onto this one.
export type Link = "Start" | "Jump" | "Walk" | "Climb" | "Drop" | "Slide"

export type RouteKind = "Platform" | "SeatRow" | "Roof" | "Step" | "Landing" | "Slide" | "Floor"

export type RouteBox = {
	id: string,
	kind: RouteKind,
	center: Vec,
	size: Vec,
	link: Link,
	-- Seat rows look tipped over: rotation (degrees) around the Z axis. Cosmetic, kept small.
	tilt: number?,
	-- Stage 3 cardboard steps.
	collapse: boolean?,
	-- Slide only: the direction its surface slopes DOWN toward ("+X" | "-X" | "+Z" | "-Z").
	slopeToward: string?,
}

export type Placement = { pos: Vec, facing: Vec }

export type DoorLayout = {
	id: string,
	entry: Placement,
	exit: Placement,
	trigger: Box,
	-- Mannequin root positions (Config.Mannequin.RootHeight above the floor).
	entryPoint: Vec,
	path: { Vec },
	exitStep: Vec,
	pathSpeed: number?,
}

export type Solid = Box & {
	name: string,
	-- Theme.Surfaces key.
	surface: string,
	-- false = purely decorative, players pass through.
	collide: boolean?,
	transparency: number?,
	tag: string?,
	-- Optional window holes for a wall whose thin axis is Z: spans are local X ranges.
	windows: { y1: number, y2: number, spans: { { number } } } | nil,
}

export type Layout = {
	name: string,
	room: { min: Vec, max: Vec },
	net: Box,
	spawn: Placement,
	mannequinHome: Placement,
	route: { RouteBox },
	trusses: { Box },
	solids: { Solid },
	doors: { DoorLayout },
	exitZone: Box?,
	scareZone: Box?,
	-- Stage 2
	backdrop: { panel: Box, trigger: Box } | nil,
	windowWalk: { from: Vec, to: Vec } | nil,
	-- Stage 3
	exits: { left: Placement, right: Placement, leftZone: Box, rightZone: Box } | nil,
}

return {}
