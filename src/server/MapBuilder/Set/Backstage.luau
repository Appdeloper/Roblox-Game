--!strict
--[[
	Backstage — set dressing for Acts IV–VI. Everything here is decorative: it never
	collides and stays out of the route corridors (the clearance spec proves it).

	  The Flies       hanging ropes and battens, rope locks on the fly rail, a painted sky drop
	  The Prop Room   stacked crates along the walls, a costume rail riding over the conveyor
	  Opening Night   a full house of seated mannequins (they stand in the scare), a proscenium
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Shared.Theme)
local Builders = require(script.Parent.Parent.Builders)
local Props = require(script.Parent.Parent.Props)

export type Ctx = { set: Instance, origin: Vector3, rng: Random }

local Backstage = {}

local function L(ctx: Ctx, x: number, y: number, z: number): Vector3
	return ctx.origin + Vector3.new(x, y, z)
end

local function decor(ctx: Ctx, name: string, size: Vector3, cframe: CFrame, surface: string): Part
	return Builders.part({
		name = name,
		size = size,
		cframe = cframe,
		parent = ctx.set,
		surface = surface,
		decor = true,
	})
end

-- ── Act IV: The Flies ────────────────────────────────────────────────────────────────────

function Backstage.flies(ctx: Ctx)
	-- Ropes hanging from the grid, well away from the catwalks (|z| >= 9).
	for i = 0, 13 do
		local x = 6 + i * 9.5
		for _, z in { -14, 12 } do
			local length = 16 + ctx.rng:NextNumber(0, 18)
			decor(ctx, "FlyRope", Vector3.new(0.25, length, 0.25), CFrame.new(L(ctx, x, 68 - length / 2, z)), "Rope")
		end
	end
	-- Battens (long pipes with a scrap of scenery) high above head height.
	for i, x in { 20, 58, 104 } do
		decor(ctx, "FlyPipe", Vector3.new(0.5, 0.5, 30), CFrame.new(L(ctx, x, 60, 0)), "Iron")
		decor(
			ctx,
			"HangingFlat",
			Vector3.new(10, 6, 0.3),
			CFrame.new(L(ctx, x, 56, if i % 2 == 0 then -10 else 10)),
			if i == 2 then "PaintBlue" else "Backdrop"
		)
	end
	-- Rope locks along the fly rail.
	for i = 0, 22 do
		decor(ctx, "RopeLock", Vector3.new(0.6, 1.4, 0.6), CFrame.new(L(ctx, 4 + i * 6, 34, 22.6)), "Brass")
	end
	-- A painted night sky drop far below.
	decor(ctx, "SkyDrop", Vector3.new(130, 30, 0.4), CFrame.new(L(ctx, 67, 12, -23)), "Backdrop")
	Props.stageSpot(ctx.set, L(ctx, 30, 64, -14), L(ctx, 28, 40, 0), Theme.Colors.WarmSpot, 50)
	Props.stageSpot(ctx.set, L(ctx, 112, 62, -14), L(ctx, 120, 41, 0), Theme.Colors.WarmSpot, 50)
	Props.sign(
		ctx.set,
		CFrame.lookAt(L(ctx, 10, 48, -6.8), L(ctx, 10, 48, 10)),
		Vector3.new(10, 2, 0.3),
		"MIND THE LIGHT RIGS",
		Theme.Colors.Paper,
		"DarkWood"
	)
end

-- ── Act V: The Prop Room ─────────────────────────────────────────────────────────────────

local COSTUMES = { "CostumeTeal", "CostumePurple", "Velvet", "CurtainFold" }

function Backstage.propRoom(ctx: Ctx)
	-- Crates stacked against both walls.
	for i = 0, 15 do
		local x = 4 + i * 8.5
		for _, z in { -21, 21 } do
			local h = ctx.rng:NextInteger(1, 3)
			for j = 0, h - 1 do
				decor(ctx, "Crate", Vector3.new(4, 4, 4), CFrame.new(L(ctx, x, 2 + j * 4, z)), "Plank")
			end
		end
	end
	-- The costume rail over the conveyor: costumes hang from it and ride the belt (clients
	-- move them, so they always line up with the belt's speed).
	decor(ctx, "CostumeRail", Vector3.new(30, 0.4, 0.4), CFrame.new(L(ctx, 82, 21.1, 0)), "Iron")
	for i = 0, 5 do
		local hanger = decor(
			ctx,
			"Costume",
			Vector3.new(2.4, 3.2, 1),
			CFrame.new(L(ctx, 70 + i * 5, 19.2, 0)),
			COSTUMES[i % #COSTUMES + 1]
		)
		local head =
			decor(ctx, "CostumeHead", Vector3.new(1, 1.2, 1), hanger.CFrame * CFrame.new(0, 2.2, 0), "Mannequin")
		hanger:SetAttribute("RailMin", L(ctx, 69, 0, 0).X)
		hanger:SetAttribute("RailMax", L(ctx, 95, 0, 0).X)
		CollectionService:AddTag(hanger, "ConveyorCostume")
		CollectionService:AddTag(head, "CostumeHead")
	end
	Props.stageSpot(ctx.set, L(ctx, 26, 34, -18), L(ctx, 38, 10, 0), Theme.Colors.WarmSpot, 45)
	Props.stageSpot(ctx.set, L(ctx, 108, 34, 18), L(ctx, 108, 12, 0), Theme.Colors.WarmSpot, 45)
	Props.sign(
		ctx.set,
		CFrame.lookAt(L(ctx, 10, 16, -6.8), L(ctx, 10, 16, 10)),
		Vector3.new(10, 2, 0.3),
		"PROPS · DO NOT TOUCH",
		Theme.Colors.Paper,
		"DarkWood"
	)
end

-- ── Act VI: Opening Night ────────────────────────────────────────────────────────────────

--- One seated audience mannequin: a block body that the scare stands up (client-side).
local function audienceMember(ctx: Ctx, pos: Vector3)
	local model = Builders.model("AudienceMember", ctx.set)
	local facing = CFrame.lookAt(pos, pos + Vector3.new(1, 0, 0))
	-- Dark wood in the dim house (the route must stay the brightest thing around); the
	-- scare's house lights are what reveal them.
	decor(ctx, "Body", Vector3.new(1.6, 2, 0.9), facing * CFrame.new(0, 1, 0), "DarkWood").Parent = model
	decor(ctx, "Head", Vector3.new(1, 1.2, 1), facing * CFrame.new(0, 2.7, 0), "DarkWood").Parent = model
	model:SetAttribute("Seated", facing)
	CollectionService:AddTag(model, "Audience")
end

function Backstage.openingNight(ctx: Ctx)
	-- The house: rows of seats down in the stalls (below and in front of the stage, out of
	-- the route), each with a mannequin in it.
	for row = 0, 4 do
		local x = 60 + row * 6
		for i = -6, 6 do
			local z = i * 3.4
			if math.abs(z) > 4 then
				local seat = L(ctx, x - 40, 1 + row * 1.2, z)
				decor(ctx, "Seat", Vector3.new(1.6, 1, 2.6), CFrame.new(seat), "Velvet")
				audienceMember(ctx, seat + Vector3.new(0, 0.5, 0))
			end
		end
	end
	-- Proscenium over the main stage.
	for _, z in { -26, 26 } do
		decor(ctx, "Proscenium", Vector3.new(2, 40, 3), CFrame.new(L(ctx, 90, 24, z)), "Gilt")
	end
	decor(ctx, "ProsceniumTop", Vector3.new(2, 4, 54), CFrame.new(L(ctx, 90, 44, 0)), "Gilt")
	Props.sign(
		ctx.set,
		CFrame.lookAt(L(ctx, 90.6, 40, 0), L(ctx, 0, 40, 0)),
		Vector3.new(0.3, 3.4, 26),
		"OPENING NIGHT",
		Theme.Colors.Brass,
		"Curtain"
	)
	for _, z in { -16, 16 } do
		Props.stageSpot(ctx.set, L(ctx, 96, 44, z), L(ctx, 120, 9, 0), Theme.Colors.WarmSpot, 70)
	end
end

return Backstage
