--!strict
--[[
	Street (Stage 2 set) — a flat painted-scenery street:
	  * window frames + striped awnings around the upstairs windows (the scare windows)
	  * glowing painted windows on the facade's other floors
	  * shopfronts (glowing windows) on each shop body, cornices under every roof edge
	  * a fly-loft rig (battens, pulleys, ropes) over the audience side of the street,
	    never above the roofs you jump across.
]]

local Theme = require(game:GetService("ReplicatedStorage").Shared.Theme)
local Builders = require(script.Parent.Parent.Builders)
local SetPieces = require(script.Parent.Parent.SetPieces)

local Street = {}

export type Ctx = {
	set: Instance,
	origin: Vector3,
	rng: Random,
	route: { [string]: BasePart },
}

-- Facade front face is at local z = 12 and faces -Z (toward the roofs).
local FACADE_FACE_Z = 11.95
local HOLE_SPANS = { { 48, 54 }, { 58, 64 }, { 68, 74 }, { 78, 84 } }

local function L(ctx: Ctx, x: number, y: number, z: number): Vector3
	return ctx.origin + Vector3.new(x, y, z)
end

local function onFacade(ctx: Ctx, x: number, y: number): CFrame
	local pos = L(ctx, x, y, FACADE_FACE_Z)
	return CFrame.lookAt(pos, pos - Vector3.zAxis)
end

local function upstairs(ctx: Ctx)
	for _, span in HOLE_SPANS do
		local xc = (span[1] + span[2]) / 2
		SetPieces.windowFrame(ctx.set, onFacade(ctx, xc, 33.5), span[2] - span[1], 7, false)
		local top = L(ctx, xc, 38.8, 12)
		SetPieces.awning(ctx.set, CFrame.lookAt(top, top - Vector3.zAxis), 7, 2, 1.2)
	end
end

local function paintedWindows(ctx: Ctx)
	-- Second floor beside the scare windows (clear of the rooftop door at x 37..43).
	for _, x in { 16, 28, 96, 108, 120 } do
		SetPieces.windowFrame(ctx.set, onFacade(ctx, x, 33.5), 4.5, 5, true)
	end
	-- Third floor (clear of the painted moon at x 67.5..76.5). Two panes cast real light.
	for i, x in { 14, 28, 42, 100, 114, 128, 142 } do
		local pane = SetPieces.windowFrame(ctx.set, onFacade(ctx, x, 45), 4.5, 5, true)
		if pane and (i == 2 or i == 5) then
			Builders.pointLight(pane, Theme.Colors.Window, 16, 0.9)
		end
	end
end

local function shopfronts(ctx: Ctx)
	for _, id in { "RoofA", "RoofB", "RoofC", "RoofD" } do
		local cap = ctx.route[id]
		if cap then
			SetPieces.cornice(ctx.set, cap)
			local top = cap.CFrame.Position.Y + cap.Size.Y / 2
			local faceZ = cap.CFrame.Position.Z - (cap.Size.Z - 0.4) / 2 - 0.05
			for _, dx in { -0.25, 0.25 } do
				local pos = Vector3.new(cap.CFrame.Position.X + dx * (cap.Size.X - 0.4), top - 9, faceZ)
				SetPieces.windowFrame(ctx.set, CFrame.lookAt(pos, pos - Vector3.zAxis), 3.6, 4, true)
			end
		end
	end
end

--- The painted moon on the flats, chimneys smoking along the roofline, and two painted
--- backdrop cloths hung on the audience side (tagged Curtain so they sway later).
local function skyline(ctx: Ctx)
	SetPieces.paintedMoon(ctx.set, onFacade(ctx, 72, 46), 5, ctx.rng)
	-- Chimneys sit on the facade roofline, never on the roofs the player runs across.
	for _, x in { 30, 64, 112 } do
		SetPieces.chimney(ctx.set, CFrame.new(L(ctx, x, 58, 13)), 2, 1.5)
	end
	for _, x in { 40, 112 } do
		SetPieces.stripCurtain(ctx.set, "StreetBackdrop", L(ctx, x, 45, -21), Vector3.new(22, 22, 1.1), 1.6)
	end
end

local function rigging(ctx: Ctx)
	-- Battens only over the audience side (z < -10): nothing hangs above the roofs.
	SetPieces.rigging(ctx.set, ctx.rng, ctx.origin.X, ctx.origin.X + 176, {
		ctx.origin.Z - 24,
		ctx.origin.Z - 15,
	}, ctx.origin.Y + 56, 16, ctx.origin.Y + 40)
end

function Street.build(ctx: Ctx)
	upstairs(ctx)
	paintedWindows(ctx)
	shopfronts(ctx)
	skyline(ctx)
	rigging(ctx)
	-- Signature fill: warm amber windows against an indigo night street.
	for _, x in { 34, 110 } do
		local fill = Builders.part({
			name = "StreetFill",
			size = Vector3.one,
			cframe = CFrame.new(L(ctx, x, 40, -14)),
			parent = ctx.set,
			surface = "Invisible",
			decor = true,
		})
		Builders.pointLight(fill, Theme.Colors.WarmSpot, 60, 0.6)
	end
end

return Street
