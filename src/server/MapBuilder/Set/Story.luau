--!strict
--[[
	Story — places the lore props and the mechanic hints in the world.

	What the player can piece together, in the order they will meet it:
	  lobby    the playbill for "The Understudy", the cast list with the lead crossed out,
	           an opening-night countdown stuck on 0, and costume tags on the wardrobe rail
	           ending with one marked UNDERSTUDY · PINE — the mannequin's name.
	  stage 1  the rehearsal schedule with every day struck off except the dress rehearsal,
	           scripts dropped in the seats, and fresh footprints in the stage dust.
	  stage 2  a wet-paint notice on the half-finished flats and a playbill pasted up outside.
	  stage 3  the prompt book open on its stand, its last cue never written, and the cast
	           list again by the two doors.

	Mechanic hints are placed with the same hand: scuff marks dragged toward every painted
	door (something heavy keeps going that way) and footprints showing the way across.

	Everything is decorative and every floor mark is flatter than 0.1 studs, so none of it
	can interfere with a jump — tests/smoke/clearance.spec.luau enforces that.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lore = require(ReplicatedStorage.Shared.Lore)
local LoreProps = require(script.Parent.Parent.LoreProps)

local Story = {}

export type Ctx = {
	set: Instance,
	origin: Vector3,
	rng: Random,
}

local function L(ctx: Ctx, x: number, y: number, z: number): Vector3
	return ctx.origin + Vector3.new(x, y, z)
end

--- A board mounted flat on a wall, facing `normal`.
local function onWall(ctx: Ctx, x: number, y: number, z: number, normal: Vector3): CFrame
	local pos = L(ctx, x, y, z)
	return CFrame.lookAt(pos, pos + normal)
end

-- ── Lobby: the whole premise, before you ever start a run ──────────────────────────────────

function Story.lobby(ctx: Ctx)
	-- Back wall (z = -22), either side of the title sign.
	LoreProps.playbill(ctx.set, onWall(ctx, -17, 13, -21.8, Vector3.zAxis), Vector2.new(11, 9), -2)
	LoreProps.board(ctx.set, onWall(ctx, 17, 13, -21.8, Vector3.zAxis), Vector2.new(10, 8), {
		heading = Lore.CastList.Heading,
		subheading = Lore.Play.Title,
		lines = Lore.CastList.Lines,
		style = LoreProps.Styles.Playbill,
		tilt = 1.5,
	})
	-- Right-hand wall (x = 30), clear of the stage door at z = 4.
	LoreProps.countdown(ctx.set, onWall(ctx, 29.8, 12, -13, -Vector3.xAxis), Vector2.new(12, 9))

	-- Wardrobe rail (centre x = -14, z = 16): four tags, the mannequin's last.
	for index, tag in Lore.CostumeTags do
		LoreProps.costumeTag(ctx.set, L(ctx, -17.4 + (index - 1) * 2.3, 6.4, 15.4), -Vector3.zAxis, tag)
	end
	LoreProps.board(ctx.set, onWall(ctx, -14, 12.5, 21.8, -Vector3.zAxis), Vector2.new(8, 4), {
		heading = Lore.Notices.Wardrobe.Heading,
		lines = Lore.Notices.Wardrobe.Lines,
		style = LoreProps.Styles.Notice,
		tilt = -3,
	})

	-- Someone walked off the rehearsal stage toward the stage door and never came back.
	LoreProps.footprints(ctx.set, ctx.rng, L(ctx, 4, 0.03, -5), L(ctx, 26, 0.03, 3))
	LoreProps.scriptPages(ctx.set, ctx.rng, L(ctx, -6, 3.05, -15), 5, 4)
end

-- ── Stage 1: the rehearsal that never ended ───────────────────────────────────────────────

function Story.stage1(ctx: Ctx)
	-- House-left wall, where the cast would have checked it on the way in.
	LoreProps.board(ctx.set, onWall(ctx, 22, 14, -25.8, Vector3.zAxis), Vector2.new(12, 9), {
		heading = Lore.Schedule.Heading,
		lines = Lore.Schedule.Lines,
		style = LoreProps.Styles.Chalk,
	})
	LoreProps.board(ctx.set, onWall(ctx, 74, 15, -25.8, Vector3.zAxis), Vector2.new(8, 4.5), {
		heading = Lore.Notices.Backstage.Heading,
		lines = Lore.Notices.Backstage.Lines,
		style = LoreProps.Styles.Notice,
		tilt = 2,
	})
	-- Scripts abandoned in the seats, out in the misty house.
	LoreProps.scriptPages(ctx.set, ctx.rng, L(ctx, 40, 1.03, -18), 7, 5)
	LoreProps.scriptPages(ctx.set, ctx.rng, L(ctx, 68, 1.03, 19), 6, 4)

	-- Dust on the stage, and fresh prints walking out through the backstage arch.
	LoreProps.dustFilm(ctx.set, CFrame.new(L(ctx, 130, 21, 0)), Vector3.new(54, 2, 48))
	LoreProps.footprints(ctx.set, ctx.rng, L(ctx, 106, 22.06, 4), L(ctx, 150, 22.06, 0))

	-- Something heavy keeps being dragged to the painted doors.
	LoreProps.scuffTrail(ctx.set, ctx.rng, L(ctx, 54, 11.54, 17), L(ctx, 54, 11.54, 24.4))
	LoreProps.scuffTrail(ctx.set, ctx.rng, L(ctx, 93.5, 14.04, 17), L(ctx, 93.5, 14.04, 24.4), 5)
end

-- ── Stage 2: a set that was never finished ────────────────────────────────────────────────

function Story.stage2(ctx: Ctx)
	-- On the painted flats themselves (front face of the facade is z = 12).
	LoreProps.board(ctx.set, onWall(ctx, 104, 20, 11.9, -Vector3.zAxis), Vector2.new(9, 5), {
		heading = Lore.Notices.Paint.Heading,
		lines = Lore.Notices.Paint.Lines,
		style = LoreProps.Styles.Notice,
		tilt = -2.5,
	})
	LoreProps.playbill(ctx.set, onWall(ctx, 138, 20, 11.9, -Vector3.zAxis), Vector2.new(8, 7), 2)
	-- Scripts on the starting deck, where the crew would have been standing.
	LoreProps.scriptPages(ctx.set, ctx.rng, L(ctx, 7, 1.03, -6), 4, 3)
	-- Scuffs across the first roof, pointing at the rooftop door.
	LoreProps.scuffTrail(ctx.set, ctx.rng, L(ctx, 34, 24.04, 1), L(ctx, 40, 24.04, 9), 6)
end

-- ── Stage 3: the last page nobody wrote ───────────────────────────────────────────────────

function Story.stage3(ctx: Ctx)
	-- Prompt book on the main stage, well off the run to the doors.
	LoreProps.promptBook(ctx.set, CFrame.lookAt(L(ctx, 104, 6, -19.5), L(ctx, 120, 6, -13)))
	LoreProps.board(ctx.set, onWall(ctx, 118, 14, -25.8, Vector3.zAxis), Vector2.new(10, 8), {
		heading = Lore.CastList.Heading,
		subheading = Lore.Play.Title,
		lines = Lore.CastList.Lines,
		style = LoreProps.Styles.Playbill,
		tilt = -1.5,
	})
	LoreProps.scriptPages(ctx.set, ctx.rng, L(ctx, 110, 6.03, 15), 4, 4)
	-- The mannequin's own route to the landing door.
	LoreProps.scuffTrail(ctx.set, ctx.rng, L(ctx, 56, 23.04, -1), L(ctx, 56, 23.04, -6.4), 5)
end

Story.byStage = { Story.stage1, Story.stage2, Story.stage3 }

return Story
