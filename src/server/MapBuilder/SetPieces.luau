--!strict
--[[
	SetPieces — reusable, Theme-styled set dressing for the toy-diorama theatre.
	Everything here is decorative (`decor = true`: no collision, no raycasts, no shadows)
	unless stated, so it can never block or snag the parkour route. Randomness always comes
	from a seeded Random passed in, so the map looks hand-made but is identical every build.

	Geometry helpers
	  rightTriangle   a WedgePart placed by its right-angle corner and two legs — the primitive
	                  behind arch corners and the five-point brass stars.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Shared.Theme)
local Builders = require(script.Parent.Builders)

local SetPieces = {}

local PLANK_SURFACES = { "Plank", "PlankLight", "PlankDark" }

-- ── Primitives ────────────────────────────────────────────────────────────────────────────

--- WedgePart forming the right triangle with its right angle at `corner`, one leg along
--- `legA` (length lenA) and the other along `legC` (length lenC), extruded `thickness`.
--- (WedgePart local frame: right angle at (y=-h/2, z=+l/2), legs along -Z and +Y.)
function SetPieces.rightTriangle(
	parent: Instance,
	name: string,
	corner: Vector3,
	legA: Vector3,
	lenA: number,
	legC: Vector3,
	lenC: number,
	thickness: number,
	surface: string
): WedgePart
	local zAxis = -legA.Unit
	local yAxis = legC.Unit
	local xAxis = yAxis:Cross(zAxis)
	local center = corner + legA.Unit * (lenA / 2) + legC.Unit * (lenC / 2)
	return Builders.wedge({
		name = name,
		size = Vector3.new(thickness, lenC, lenA),
		cframe = CFrame.fromMatrix(center, xAxis, yAxis, zAxis),
		parent = parent,
		surface = surface,
		decor = true,
	})
end

--- Five-point star lying in the plane of `cf` (RightVector/UpVector), facing cf.LookVector.
function SetPieces.star(
	parent: Instance,
	name: string,
	cf: CFrame,
	rOuter: number,
	rInner: number,
	thickness: number,
	surface: string
)
	local center = cf.Position
	local right, up = cf.RightVector, cf.UpVector
	-- Centre disc (cylinder axis = local X, turned to face the viewer).
	Builders.cylinder({
		name = name .. "_Hub",
		size = Vector3.new(thickness, rInner * 2.1, rInner * 2.1),
		cframe = cf * CFrame.Angles(0, math.rad(90), 0),
		parent = parent,
		surface = surface,
		decor = true,
	})
	local half = math.rad(36)
	for k = 0, 4 do
		local theta = math.rad(90 + 72 * k)
		local u = right * math.cos(theta) + up * math.sin(theta)
		local p = right * -math.sin(theta) + up * math.cos(theta)
		local mid = center + u * (rInner * math.cos(half))
		local length = rOuter - rInner * math.cos(half)
		local halfBase = rInner * math.sin(half)
		for _, side in { 1, -1 } do
			SetPieces.rightTriangle(parent, name .. "_Point", mid, u, length, p * side, halfBase, thickness, surface)
		end
	end
end

-- ── Floors, walls, trims ──────────────────────────────────────────────────────────────────

--- Overlays visible planks (random light/dark) on top of a box; non-colliding, so the walk
--- surface underneath is unchanged.
function SetPieces.plankFloor(parent: Instance, boxCF: CFrame, boxSize: Vector3, rng: Random, plankWidth: number?)
	local width = plankWidth or 1.6
	local alongX = boxSize.X >= boxSize.Z
	local length = if alongX then boxSize.X else boxSize.Z
	local across = if alongX then boxSize.Z else boxSize.X
	local count = math.max(1, math.floor(across / width))
	local actual = across / count
	for i = 1, count do
		local offset = -across / 2 + actual * (i - 0.5)
		local localPos = if alongX
			then Vector3.new(0, boxSize.Y / 2 + 0.04, offset)
			else Vector3.new(offset, boxSize.Y / 2 + 0.04, 0)
		local size = if alongX
			then Vector3.new(length - 0.1, 0.08, actual - 0.08)
			else Vector3.new(actual - 0.08, 0.08, length - 0.1)
		-- A few boards are loose: the client gives these a creak and a puff of dust
		-- when someone steps on them.
		Builders.part({
			name = "Plank",
			size = size,
			cframe = boxCF * CFrame.new(localPos),
			parent = parent,
			surface = PLANK_SURFACES[rng:NextInteger(1, #PLANK_SURFACES)],
			decor = true,
			tag = if rng:NextNumber() < 0.22 then "Creaky" else nil,
		})
	end
end

--- Glow-tape lips on the take-off/landing edges (±X faces) of a walkable box: the single
--- strongest readability cue for jumps on a small screen.
function SetPieces.edgeTape(parent: Instance, part: BasePart)
	for _, side in { -1, 1 } do
		Builders.part({
			name = "EdgeTape",
			size = Vector3.new(0.22, 0.06, math.max(part.Size.Z - 0.3, 0.5)),
			cframe = part.CFrame * CFrame.new(side * (part.Size.X / 2 - 0.13), part.Size.Y / 2 + 0.03, 0),
			parent = parent,
			surface = "GlowTape",
			decor = true,
		})
	end
end

--- A gilded wall panel: wood board + four gold frame strips. `cf` sits on the wall surface,
--- LookVector pointing into the room.
function SetPieces.trimPanel(parent: Instance, cf: CFrame, width: number, height: number)
	Builders.part({
		name = "WallPanel",
		size = Vector3.new(width, height, 0.3),
		cframe = cf * CFrame.new(0, 0, -0.15),
		parent = parent,
		surface = "WallPanel",
		decor = true,
	})
	local t = 0.25
	for _, y in { -1, 1 } do
		Builders.part({
			name = "PanelTrim",
			size = Vector3.new(width, t, 0.15),
			cframe = cf * CFrame.new(0, y * (height / 2 - t / 2), -0.36),
			parent = parent,
			surface = "Gilt",
			decor = true,
		})
	end
	for _, x in { -1, 1 } do
		Builders.part({
			name = "PanelTrim",
			size = Vector3.new(t, height - 2 * t, 0.15),
			cframe = cf * CFrame.new(x * (width / 2 - t / 2), 0, -0.36),
			parent = parent,
			surface = "Gilt",
			decor = true,
		})
	end
end

--- Row of gilded panels along a wall from `a` to `b` (both at floor level of the band),
--- with a gold rail above and below. `skip` = list of {from, to} distances along the wall.
function SetPieces.wallPanels(
	parent: Instance,
	a: Vector3,
	b: Vector3,
	normal: Vector3,
	y0: number,
	y1: number,
	panelWidth: number,
	skip: { { number } }?
)
	local dir = (b - a).Unit
	local length = (b - a).Magnitude
	local count = math.max(1, math.floor(length / panelWidth))
	local spacing = length / count
	local function skipped(t: number): boolean
		for _, range in skip or {} do
			if t + spacing / 2 > range[1] and t - spacing / 2 < range[2] then
				return true
			end
		end
		return false
	end
	for i = 1, count do
		local t = spacing * (i - 0.5)
		if not skipped(t) then
			local pos = Vector3.new(a.X, (y0 + y1) / 2, a.Z) + dir * t
			SetPieces.trimPanel(parent, CFrame.lookAt(pos, pos + normal), spacing - 0.8, y1 - y0)
		end
	end
	for _, y in { y0 - 0.5, y1 + 0.5 } do
		local mid = Vector3.new((a.X + b.X) / 2, y, (a.Z + b.Z) / 2) + normal * 0.2
		Builders.part({
			name = "PanelRail",
			size = Vector3.new(0.4, 0.35, length),
			cframe = CFrame.lookAt(mid, mid + dir),
			parent = parent,
			surface = "Gilt",
			decor = true,
		})
	end
end

--- Brass railing (top rail, mid rail, wooden posts) from `from` to `to` at floor height.
function SetPieces.railing(parent: Instance, from: Vector3, to: Vector3, height: number, postGap: number)
	local length = (to - from).Magnitude
	local dir = (to - from).Unit
	for _, h in { height, height * 0.45 } do
		local mid = (from + to) / 2 + Vector3.new(0, h, 0)
		Builders.part({
			name = "Rail",
			size = Vector3.new(0.28, 0.28, length),
			cframe = CFrame.lookAt(mid, mid + dir),
			parent = parent,
			surface = "Brass",
			decor = true,
		})
	end
	local posts = math.max(2, math.floor(length / postGap) + 1)
	for i = 0, posts - 1 do
		local pos = from + dir * (length * i / (posts - 1)) + Vector3.new(0, height / 2, 0)
		Builders.part({
			name = "RailPost",
			size = Vector3.new(0.32, height, 0.32),
			cframe = CFrame.new(pos),
			parent = parent,
			surface = "DarkWood",
			decor = true,
		})
	end
end

-- ── Seating ───────────────────────────────────────────────────────────────────────────────

--- One theatre seat (cushion, back panel, armrest). `cf` = floor point, looking at the stage.
--- Some seats are tipped up (rng) so rows look lived-in rather than copy-pasted.
function SetPieces.seat(parent: Instance, cf: CFrame, rng: Random, tag: string?)
	local folded = rng:NextNumber() < 0.18
	-- A third of the house has faded, so the rows read as dusty rather than new.
	local velvet = if rng:NextNumber() < 0.34 then "VelvetDusty" else "Velvet"
	if folded then
		Builders.part({
			name = "SeatCushion",
			size = Vector3.new(1.7, 1.4, 0.4),
			cframe = cf * CFrame.new(0, 1.2, 0.35),
			parent = parent,
			surface = velvet,
			decor = true,
		})
	else
		Builders.part({
			name = "SeatCushion",
			size = Vector3.new(1.7, 0.45, 1.5),
			cframe = cf * CFrame.new(0, 0.75, 0),
			parent = parent,
			surface = velvet,
			decor = true,
		})
	end
	Builders.part({
		name = "SeatBack",
		size = Vector3.new(1.7, 1.8, 0.3),
		cframe = cf * CFrame.new(0, 1.65, 0.8) * CFrame.Angles(math.rad(8), 0, 0),
		parent = parent,
		surface = velvet,
		decor = true,
		tag = tag,
	})
	Builders.part({
		name = "Armrest",
		size = Vector3.new(0.22, 0.85, 1.3),
		cframe = cf * CFrame.new(0.95, 1.0, 0.1),
		parent = parent,
		surface = "DarkWood",
		decor = true,
	})
end

export type Bounds = { minX: number, maxX: number, minZ: number, maxZ: number }

--- Curved rows of seats facing `focus` (x, z), for radii rMin..rMax. Seats outside `bounds`
--- or within 1.2 studs of an aisle z are skipped.
function SetPieces.seatArcs(
	parent: Instance,
	rng: Random,
	focus: Vector3,
	floorY: number,
	rMin: number,
	rMax: number,
	rowGap: number,
	bounds: Bounds,
	aisles: { number }
): number
	local seats = 0
	local radius = rMin
	while radius <= rMax do
		local step = 2.05 / radius
		local maxAngle = math.rad(70)
		local angle = -maxAngle
		while angle <= maxAngle do
			local x = focus.X - radius * math.cos(angle)
			local z = focus.Z + radius * math.sin(angle)
			local inBounds = x >= bounds.minX and x <= bounds.maxX and z >= bounds.minZ and z <= bounds.maxZ
			local inAisle = false
			for _, aisle in aisles do
				inAisle = inAisle or math.abs(z - aisle) < 1.2
			end
			if inBounds and not inAisle then
				local pos = Vector3.new(x, floorY, z)
				SetPieces.seat(parent, CFrame.lookAt(pos, Vector3.new(focus.X, floorY, focus.Z)), rng)
				seats += 1
			end
			angle += step
		end
		radius += rowGap
	end
	return seats
end

-- ── Curtains ──────────────────────────────────────────────────────────────────────────────

--- Heavy curtain as many thin vertical strips (pleats at alternating depth). Each strip is
--- tagged "Curtain" with a SwayIndex so clients can ripple them with cheap looping tweens.
function SetPieces.stripCurtain(parent: Instance, name: string, center: Vector3, size: Vector3, stripWidth: number?)
	local thinAlongX = size.X < size.Z
	local width = if thinAlongX then size.Z else size.X
	local thick = if thinAlongX then size.X else size.Z
	local count = math.max(2, math.ceil(width / (stripWidth or 1.3)))
	local strip = width / count
	for i = 1, count do
		local offset = -width / 2 + strip * (i - 0.5)
		local fold = if i % 2 == 0 then 0.4 else 0
		local pos = center + if thinAlongX then Vector3.new(fold, 0, offset) else Vector3.new(offset, 0, fold)
		local stripSize = if thinAlongX
			then Vector3.new(thick, size.Y, strip + 0.12)
			else Vector3.new(strip + 0.12, size.Y, thick)
		local part = Builders.part({
			name = name .. "_Strip",
			size = stripSize,
			cframe = CFrame.new(pos),
			parent = parent,
			surface = if i % 2 == 0 then "CurtainFold" else "Curtain",
			decor = true,
			tag = "Curtain",
		})
		part:SetAttribute("SwayIndex", i)
	end
end

--- A gathered valance: a velvet band with a gold trim line along its hem.
function SetPieces.valance(parent: Instance, center: Vector3, size: Vector3)
	Builders.part({
		name = "Valance",
		size = size,
		cframe = CFrame.new(center),
		parent = parent,
		surface = "Curtain",
		decor = true,
	})
	local hem = Vector3.new(size.X + 0.1, 0.3, size.Z + 0.1)
	Builders.part({
		name = "ValanceTrim",
		size = hem,
		cframe = CFrame.new(center - Vector3.new(0, size.Y / 2, 0)),
		parent = parent,
		surface = "Gilt",
		decor = true,
	})
end

-- ── Architecture ──────────────────────────────────────────────────────────────────────────

--- Proscenium arch around an opening. `cf` = floor centre of the opening, LookVector toward
--- the audience. Pillars with gilt fluting, a header, rounded corners and a brass star crest.
function SetPieces.proscenium(
	parent: Instance,
	cf: CFrame,
	openWidth: number,
	openHeight: number,
	pillarWidth: number,
	depth: number,
	headerHeight: number
)
	for _, side in { -1, 1 } do
		local x = side * (openWidth / 2 + pillarWidth / 2)
		Builders.part({
			name = "ProsceniumPillar",
			size = Vector3.new(pillarWidth, openHeight, depth),
			cframe = cf * CFrame.new(x, openHeight / 2, 0),
			parent = parent,
			surface = "AgedWood",
			decor = true,
		})
		for _, y in { 0.6, openHeight - 0.6 } do
			Builders.part({
				name = "PillarCap",
				size = Vector3.new(pillarWidth + 0.8, 1.2, depth + 0.6),
				cframe = cf * CFrame.new(x, y, 0),
				parent = parent,
				surface = "DarkWood",
				decor = true,
			})
		end
		for _, flute in { -0.25, 0.25 } do
			Builders.part({
				name = "PillarFlute",
				size = Vector3.new(0.3, openHeight - 2.6, 0.2),
				cframe = cf * CFrame.new(x + flute * pillarWidth, openHeight / 2, -depth / 2 - 0.1),
				parent = parent,
				surface = "Gilt",
				decor = true,
			})
		end
	end
	local fullWidth = openWidth + pillarWidth * 2
	Builders.part({
		name = "ProsceniumHeader",
		size = Vector3.new(fullWidth, headerHeight, depth),
		cframe = cf * CFrame.new(0, openHeight + headerHeight / 2, 0),
		parent = parent,
		surface = "AgedWood",
		decor = true,
	})
	Builders.part({
		name = "HeaderTrim",
		size = Vector3.new(fullWidth, 0.35, 0.2),
		cframe = cf * CFrame.new(0, openHeight + 0.4, -depth / 2 - 0.1),
		parent = parent,
		surface = "Gilt",
		decor = true,
	})
	-- Rounded top corners of the opening.
	local corner = math.min(pillarWidth * 1.2, openHeight * 0.25)
	for _, side in { -1, 1 } do
		local cornerPos = (cf * CFrame.new(side * openWidth / 2, openHeight, 0)).Position
		SetPieces.rightTriangle(
			parent,
			"ArchCorner",
			cornerPos,
			cf.RightVector * -side,
			corner,
			-cf.UpVector,
			corner,
			depth,
			"AgedWood"
		)
	end
	SetPieces.star(
		parent,
		"Crest",
		cf * CFrame.new(0, openHeight + headerHeight / 2, -depth / 2 - 0.15),
		headerHeight * 0.45,
		headerHeight * 0.18,
		0.3,
		"Brass"
	)
end

-- ── Painted street ────────────────────────────────────────────────────────────────────────

--- Window frame (four bars + sill), optionally with a glowing pane and cross mullions.
--- `cf` = centre of the window on the wall face, LookVector out of the wall.
function SetPieces.windowFrame(parent: Instance, cf: CFrame, width: number, height: number, glow: boolean): BasePart?
	local pane: BasePart? = nil
	if glow then
		pane = Builders.part({
			name = "WindowPane",
			size = Vector3.new(width, height, 0.1),
			cframe = cf * CFrame.new(0, 0, -0.05),
			parent = parent,
			surface = "WindowGlow",
			decor = true,
		})
		Builders.part({
			name = "Mullion",
			size = Vector3.new(0.18, height, 0.2),
			cframe = cf * CFrame.new(0, 0, -0.15),
			parent = parent,
			surface = "AgedWood",
			decor = true,
		})
		Builders.part({
			name = "Mullion",
			size = Vector3.new(width, 0.18, 0.2),
			cframe = cf * CFrame.new(0, 0, -0.15),
			parent = parent,
			surface = "AgedWood",
			decor = true,
		})
	end
	local bar = 0.35
	for _, y in { -1, 1 } do
		Builders.part({
			name = "WindowFrame",
			size = Vector3.new(width + bar * 2, bar, 0.4),
			cframe = cf * CFrame.new(0, y * (height / 2 + bar / 2), -0.2),
			parent = parent,
			surface = "AgedWood",
			decor = true,
		})
	end
	for _, x in { -1, 1 } do
		Builders.part({
			name = "WindowFrame",
			size = Vector3.new(bar, height, 0.4),
			cframe = cf * CFrame.new(x * (width / 2 + bar / 2), 0, -0.2),
			parent = parent,
			surface = "AgedWood",
			decor = true,
		})
	end
	Builders.part({
		name = "WindowSill",
		size = Vector3.new(width + 1, 0.3, 0.8),
		cframe = cf * CFrame.new(0, -height / 2 - bar - 0.15, -0.4),
		parent = parent,
		surface = "DarkWood",
		decor = true,
	})
	return pane
end

--- Striped shop awning sloping down and away from the wall. `cf` = top centre at the wall.
function SetPieces.awning(parent: Instance, cf: CFrame, width: number, depth: number, drop: number)
	local stripes = math.max(2, math.floor(width / 1.2))
	local stripe = width / stripes
	for i = 1, stripes do
		local x = -width / 2 + stripe * (i - 0.5)
		-- WedgePart: tall at local +Z (the wall), thinning toward -Z (= LookVector, outward).
		Builders.wedge({
			name = "AwningStripe",
			size = Vector3.new(stripe, drop, depth),
			cframe = cf * CFrame.new(x, -drop / 2, -depth / 2),
			parent = parent,
			surface = if i % 2 == 0 then "Paper" else "PaintRed",
			decor = true,
		})
	end
end

--- Cornice band just below a roof's top edge, all four sides (decorative lip).
function SetPieces.cornice(parent: Instance, roofCap: BasePart)
	local size = roofCap.Size
	-- Well below the roof line: the roofs are jumped across, so nothing may sit near the lip.
	local y = -size.Y / 2 - 1.4
	local specs = {
		{ Vector3.new(size.X + 0.8, 0.5, 0.5), Vector3.new(0, y, size.Z / 2 + 0.05) },
		{ Vector3.new(size.X + 0.8, 0.5, 0.5), Vector3.new(0, y, -size.Z / 2 - 0.05) },
		{ Vector3.new(0.5, 0.5, size.Z), Vector3.new(size.X / 2 + 0.05, y, 0) },
		{ Vector3.new(0.5, 0.5, size.Z), Vector3.new(-size.X / 2 - 0.05, y, 0) },
	}
	for _, spec in specs do
		Builders.part({
			name = "Cornice",
			size = spec[1],
			cframe = roofCap.CFrame * CFrame.new(spec[2]),
			parent = parent,
			surface = "DarkWood",
			decor = true,
		})
	end
end

-- ── Fly loft ──────────────────────────────────────────────────────────────────────────────

--- Rigging over a stage: long battens, cross beams, pulleys and hanging ropes. Ropes never
--- reach below `ropeFloor` (keep it above the route's jump corridor).
function SetPieces.rigging(
	parent: Instance,
	rng: Random,
	minX: number,
	maxX: number,
	zs: { number },
	y: number,
	crossEvery: number,
	ropeFloor: number
)
	local midX = (minX + maxX) / 2
	for _, z in zs do
		Builders.part({
			name = "Batten",
			size = Vector3.new(maxX - minX, 1, 1),
			cframe = CFrame.new(midX, y, z),
			parent = parent,
			surface = "AgedWood",
			decor = true,
		})
	end
	local minZ, maxZ = math.huge, -math.huge
	for _, z in zs do
		minZ, maxZ = math.min(minZ, z), math.max(maxZ, z)
	end
	local x = minX + crossEvery / 2
	while x < maxX do
		Builders.part({
			name = "CrossBeam",
			size = Vector3.new(0.9, 0.9, maxZ - minZ + 2),
			cframe = CFrame.new(x, y + 0.95, (minZ + maxZ) / 2),
			parent = parent,
			surface = "DarkWood",
			decor = true,
		})
		for _, z in zs do
			Builders.cylinder({
				name = "Pulley",
				size = Vector3.new(0.5, 1.5, 1.5),
				cframe = CFrame.new(x, y - 1, z),
				parent = parent,
				surface = "Iron",
				decor = true,
			})
			if rng:NextNumber() < 0.55 then
				local bottom = ropeFloor + rng:NextNumber() * (y - 2 - ropeFloor) * 0.6
				local length = (y - 1.6) - bottom
				if length > 1 then
					local rope = Builders.part({
						name = "Rope",
						size = Vector3.new(0.16, length, 0.16),
						cframe = CFrame.new(x + 0.55, bottom + length / 2, z),
						parent = parent,
						surface = "Rope",
						decor = true,
						tag = "RiggingRope",
					})
					-- Every so often the rope ends in a counterweight sandbag. The pair is
					-- tagged as one swinging prop and pivots about the rope's top anchor.
					if rng:NextNumber() < 0.45 then
						local bag = Builders.part({
							name = "Sandbag",
							size = Vector3.new(1.5, 2.1, 1.5),
							cframe = CFrame.new(x + 0.55, bottom - 1.05, z),
							parent = parent,
							surface = "Sandbag",
							decor = true,
						})
						for index, piece in { rope, bag } do
							piece:SetAttribute("SwingPivot", Vector3.new(x + 0.55, y - 1.6, z))
							piece:SetAttribute("SwingIndex", index)
							piece:AddTag("SwingProp")
						end
					end
				end
			end
		end
		x += crossEvery
	end
end

-- ── Exits ─────────────────────────────────────────────────────────────────────────────────

--- Three fading floor panels of warm light in front of a door (hidden; clients reveal them).
--- `base` = door base CFrame, LookVector into the room.
function SetPieces.lightSpill(parent: Instance, base: CFrame, tag: string, attributes: { [string]: any })
	local specs = { { 5.4, 1.8, -1.0, 0.45 }, { 6.4, 2.4, -3.1, 0.7 }, { 7.6, 3.0, -5.8, 0.85 } }
	for i, spec in specs do
		local part = Builders.part({
			name = "Spill" .. i,
			size = Vector3.new(spec[1], 0.05, spec[2]),
			cframe = base * CFrame.new(0, 0.04, spec[3]),
			parent = parent,
			surface = "SpillGlow",
			decor = true,
			tag = tag,
		})
		part:SetAttribute("Opacity", spec[4])
		for key, value in attributes do
			part:SetAttribute(key, value)
		end
	end
end

-- ── Volumetric-looking light ──────────────────────────────────────────────────────────────

--- A shaft of light from `from` to `to`: one long faint Neon box plus the pool it casts.
--- No real light source, so it costs nothing but overdraw — Quality can switch it off.
--- Slow dust motes drifting inside a shaft of light. One emitter per shaft; callers keep
--- the per-stage count inside Config.Performance.MaxEmittersPerStage.
function SetPieces.motes(host: BasePart, rate: number): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Motes"
	emitter.Rate = rate
	emitter.Lifetime = NumberRange.new(5, 9)
	emitter.Speed = NumberRange.new(0.1, 0.5)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new(0.16)
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.35, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Color = ColorSequence.new(Theme.Colors.Paper)
	emitter.LightEmission = 0.8
	emitter.Acceleration = Vector3.new(0.25, -0.12, 0)
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	emitter.Parent = host
	return emitter
end

function SetPieces.lightShaft(
	parent: Instance,
	from: Vector3,
	to: Vector3,
	width: number,
	surface: string,
	poolSurface: string?,
	moteRate: number?
)
	local length = (to - from).Magnitude
	if length < 1 then
		return
	end
	local shaft = Builders.part({
		name = "LightShaft",
		size = Vector3.new(width, width * 0.55, length),
		cframe = CFrame.lookAt((from + to) / 2, to),
		parent = parent,
		surface = surface,
		decor = true,
		tag = "LightShaft",
	})
	if moteRate then
		SetPieces.motes(shaft, moteRate)
	end
	-- The pool where it lands, flattened onto the floor.
	local pool = Builders.cylinder({
		name = "LightPool",
		size = Vector3.new(0.08, width * 1.5, width * 1.5),
		cframe = CFrame.new(to) * CFrame.Angles(0, 0, math.rad(90)),
		parent = parent,
		surface = poolSurface or surface,
		decor = true,
		tag = "LightShaft",
	})
	pool.Transparency = math.max((Builders.surfaceTransparency(poolSurface or surface)) - 0.22, 0)
end

--- A beam that narrows toward its target, built from stacked cylinders (Roblox has no cone).
--- Reads as a spotlight picking something out; `segments` keeps the part count honest.
function SetPieces.narrowingBeam(
	parent: Instance,
	apex: Vector3,
	target: Vector3,
	startRadius: number,
	endRadius: number,
	segments: number,
	surface: string
)
	local axis = target - apex
	local length = axis.Magnitude
	if length < 1 then
		return
	end
	local step = length / segments
	for i = 1, segments do
		local alpha = (i - 0.5) / segments
		local radius = startRadius + (endRadius - startRadius) * alpha
		local centre = apex + axis.Unit * (step * (i - 0.5))
		local segment = Builders.cylinder({
			name = "BeamSegment",
			size = Vector3.new(step * 1.02, radius * 2, radius * 2),
			cframe = CFrame.lookAt(centre, centre + axis.Unit) * CFrame.Angles(0, math.rad(90), 0),
			parent = parent,
			surface = surface,
			decor = true,
			tag = "LightShaft",
		})
		-- Fades out along its length so the far end dissolves instead of stopping flat.
		segment.Transparency = math.clamp(Builders.surfaceTransparency(surface) + alpha * 0.07, 0, 1)
	end
end

-- ── Painted scenery ───────────────────────────────────────────────────────────────────────

--- The painted moon on a scenery flat: a glowing disc, a painted ring and a few craters.
function SetPieces.paintedMoon(parent: Instance, cf: CFrame, radius: number, rng: Random)
	Builders.cylinder({
		name = "PaintedMoonRing",
		size = Vector3.new(0.12, radius * 2.3, radius * 2.3),
		cframe = cf * CFrame.Angles(0, math.rad(90), 0),
		parent = parent,
		surface = "MoonRing",
		decor = true,
	})
	Builders.cylinder({
		name = "PaintedMoon",
		size = Vector3.new(0.3, radius * 2, radius * 2),
		cframe = cf * CFrame.new(0, 0, -0.12) * CFrame.Angles(0, math.rad(90), 0),
		parent = parent,
		surface = "PaintedMoon",
		decor = true,
	})
	for _ = 1, 4 do
		local angle = rng:NextNumber() * math.pi * 2
		local distance = radius * 0.55 * math.sqrt(rng:NextNumber())
		local size = radius * rng:NextNumber(0.12, 0.24)
		Builders.cylinder({
			name = "MoonCrater",
			size = Vector3.new(0.1, size, size),
			cframe = cf
				* CFrame.new(math.cos(angle) * distance, math.sin(angle) * distance, -0.3)
				* CFrame.Angles(0, math.rad(90), 0),
			parent = parent,
			surface = "MoonRing",
			decor = true,
		})
	end
end

--- A brick chimney with a slow smoke plume. `rate` is capped by the caller for mobile.
function SetPieces.chimney(parent: Instance, base: CFrame, height: number, rate: number)
	local stack = Builders.part({
		name = "Chimney",
		size = Vector3.new(2.2, height, 2.2),
		cframe = base * CFrame.new(0, height / 2, 0),
		parent = parent,
		surface = "FacadeRose",
		decor = true,
	})
	Builders.part({
		name = "ChimneyCap",
		size = Vector3.new(2.8, 0.4, 2.8),
		cframe = base * CFrame.new(0, height, 0),
		parent = parent,
		surface = "DarkWood",
		decor = true,
	})
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Smoke"
	emitter.Rate = rate
	emitter.Lifetime = NumberRange.new(4, 7)
	emitter.Speed = NumberRange.new(2.5, 4)
	emitter.SpreadAngle = Vector2.new(14, 14)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.4),
		NumberSequenceKeypoint.new(1, 5.5),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Color = ColorSequence.new(Theme.Surfaces.Smoke.Color)
	emitter.LightEmission = 0.15
	emitter.Acceleration = Vector3.new(0.6, 1.2, 0)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-12, 12)
	emitter.Parent = stack
	-- Emit from the top of the stack only.
	emitter.EmissionDirection = Enum.NormalId.Top
	return stack
end

-- ── Floor litter ──────────────────────────────────────────────────────────────────────────

local CONFETTI_SURFACES = { "PaintRed", "PaintBlue", "PaintYellow", "Gilt", "Paper" }

--- Confetti and torn paper settled on the floor after a performance that never happened.
--- Flat enough that the clearance test treats it as paint (it cannot obstruct anything).
function SetPieces.confetti(parent: Instance, rng: Random, centre: Vector3, radius: Vector2, count: number)
	for _ = 1, count do
		local pos = centre + Vector3.new(rng:NextNumber(-radius.X, radius.X), 0, rng:NextNumber(-radius.Y, radius.Y))
		local long = rng:NextNumber(0.4, 1.1)
		Builders.part({
			name = "Confetti",
			size = Vector3.new(long, 0.04, long * rng:NextNumber(0.3, 0.7)),
			cframe = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber() * math.pi * 2, 0),
			parent = parent,
			surface = CONFETTI_SURFACES[rng:NextInteger(1, #CONFETTI_SURFACES)],
			decor = true,
		})
	end
end

--- A carpet runner that has been walked threadbare: segments with torn gaps between them.
function SetPieces.tornCarpet(parent: Instance, rng: Random, from: Vector3, to: Vector3, width: number)
	local axis = to - from
	local length = axis.Magnitude
	if length < 2 then
		return
	end
	local direction = axis.Unit
	local travelled = 0
	while travelled < length do
		local piece = math.min(rng:NextNumber(5, 11), length - travelled)
		if piece > 1.5 then
			local centre = from + direction * (travelled + piece / 2)
			Builders.part({
				name = "AisleCarpet",
				size = Vector3.new(piece, 0.06, width * rng:NextNumber(0.86, 1)),
				cframe = CFrame.lookAt(centre, centre + direction) * CFrame.Angles(0, math.rad(90), 0),
				parent = parent,
				surface = if rng:NextNumber() < 0.35 then "CarpetWorn" else "Carpet",
				decor = true,
			})
		end
		-- A torn gap before the next piece.
		travelled += piece + rng:NextNumber(0.6, 2.2)
	end
end

return SetPieces
