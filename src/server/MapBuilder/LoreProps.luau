--!strict
--[[
	LoreProps — the props that tell the story without a word of narration: playbills, the
	rehearsal schedule, the opening-night countdown, costume tags, the cast list with a name
	crossed out, loose script pages and the open prompt book.

	Plus the props that teach a mechanic instead of a story beat: scuff marks dragged toward
	a painted door, and fresh footprints in the stage dust.

	Everything here is decorative (no collision, no raycasts, no shadows) and every floor
	mark is flatter than 0.1 studs, so it can never interfere with a jump
	(tests/smoke/clearance.spec.luau holds that line).

	Text is drawn with SurfaceGuis rather than decals, so there are no image assets to
	upload and every word can be edited in src/shared/Lore.luau.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lore = require(ReplicatedStorage.Shared.Lore)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Builders = require(script.Parent.Builders)

local LoreProps = {}

local PIXELS_PER_STUD = 32

export type BoardStyle = {
	-- Theme surface for the backing board.
	surface: string,
	heading: Color3,
	body: Color3,
	accent: Color3,
	font: Enum.Font,
	headingFont: Enum.Font?,
}

LoreProps.Styles = {
	Chalk = {
		surface = "Chalkboard",
		heading = Theme.Colors.Paper,
		body = Theme.Colors.PaperShade,
		accent = Theme.Colors.UiAccent,
		font = Theme.Fonts.Body,
		headingFont = Theme.Fonts.Title,
	} :: BoardStyle,
	Playbill = {
		surface = "Playbill",
		heading = Color3.fromRGB(96, 24, 30),
		body = Color3.fromRGB(58, 44, 36),
		accent = Color3.fromRGB(150, 24, 36),
		font = Theme.Fonts.Ticket,
		headingFont = Theme.Fonts.Title,
	} :: BoardStyle,
	Notice = {
		surface = "Paper",
		heading = Color3.fromRGB(44, 38, 32),
		body = Color3.fromRGB(78, 68, 58),
		accent = Color3.fromRGB(150, 24, 36),
		font = Theme.Fonts.Body,
		headingFont = Theme.Fonts.Bold,
	} :: BoardStyle,
}

local function newGui(part: BasePart, face: Enum.NormalId): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Lore"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PIXELS_PER_STUD
	gui.LightInfluence = 0.75
	gui.Parent = part
	return gui
end

local function textLine(
	parent: Instance,
	text: string,
	font: Enum.Font,
	color: Color3,
	height: number,
	order: number
): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = "Line"
	label.LayoutOrder = order
	label.Size = UDim2.new(1, 0, 0, height)
	label.BackgroundTransparency = 1
	label.Text = text
	label.Font = font
	label.TextColor3 = color
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = height
	limit.Parent = label
	return label
end

--- A pen stroke through a line of text.
local function strikeThrough(label: TextLabel, color: Color3)
	local stroke = Instance.new("Frame")
	stroke.Name = "Struck"
	stroke.AnchorPoint = Vector2.new(0, 0.5)
	stroke.Position = UDim2.fromScale(0, 0.55)
	stroke.Size = UDim2.new(1, 0, 0, 2)
	stroke.BorderSizePixel = 0
	stroke.BackgroundColor3 = color
	stroke.Rotation = -1
	stroke.Parent = label
end

export type BoardSpec = {
	heading: string?,
	subheading: string?,
	lines: { Lore.Line }?,
	footer: string?,
	style: BoardStyle,
	-- Degrees of tilt, so pinned paper never looks machine-placed.
	tilt: number?,
}

--- A flat board with text on its Front face. `cf` sits on the wall, LookVector into the room.
function LoreProps.board(parent: Instance, cf: CFrame, size: Vector2, spec: BoardSpec): BasePart
	local style = spec.style
	local part = Builders.part({
		name = "LoreBoard",
		size = Vector3.new(size.X, size.Y, 0.2),
		cframe = cf * CFrame.Angles(0, 0, math.rad(spec.tilt or 0)) * CFrame.new(0, 0, -0.1),
		parent = parent,
		surface = style.surface,
		decor = true,
	})
	local gui = newGui(part, Enum.NormalId.Front)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 1
	frame.Parent = gui
	local padding = Instance.new("UIPadding")
	local pad = UDim.new(0.07, 0)
	padding.PaddingTop, padding.PaddingBottom, padding.PaddingLeft, padding.PaddingRight = pad, pad, pad, pad
	padding.Parent = frame
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 3)
	layout.Parent = frame

	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	if spec.heading then
		textLine(frame, spec.heading, style.headingFont or style.font, style.heading, 26, nextOrder()).TextXAlignment =
			Enum.TextXAlignment.Center
	end
	if spec.subheading then
		textLine(frame, spec.subheading, style.font, style.body, 15, nextOrder()).TextXAlignment =
			Enum.TextXAlignment.Center
	end
	for _, line in spec.lines or {} do
		local color = if line.accent then style.accent else style.body
		local label = textLine(frame, line.text, style.font, color, 18, nextOrder())
		if line.struck then
			label.TextTransparency = 0.35
			strikeThrough(label, style.accent)
		end
	end
	if spec.footer then
		textLine(frame, spec.footer, style.font, style.accent, 18, nextOrder()).TextXAlignment =
			Enum.TextXAlignment.Center
	end
	return part
end

--- The playbill: company, title, and the three acts (which double as a map of the run).
function LoreProps.playbill(parent: Instance, cf: CFrame, size: Vector2, tilt: number?): BasePart
	Builders.part({
		name = "PlaybillBoard",
		size = Vector3.new(size.X + 0.7, size.Y + 0.7, 0.18),
		cframe = cf * CFrame.Angles(0, 0, math.rad(tilt or 0)) * CFrame.new(0, 0, 0.02),
		parent = parent,
		surface = "PlaybillBoard",
		decor = true,
	})
	local lines: { Lore.Line } = {}
	for _, act in Lore.Acts do
		table.insert(lines, { text = "ACT " .. act.Numeral .. "   " .. act.Title })
	end
	table.insert(lines, { text = "" })
	table.insert(lines, { text = Lore.Play.Venue })
	return LoreProps.board(parent, cf, size, {
		heading = Lore.Play.Title,
		subheading = Lore.Play.Subtitle .. "  ·  " .. Lore.Play.Company,
		lines = lines,
		footer = "ONE NIGHT ONLY",
		style = LoreProps.Styles.Playbill,
		tilt = tilt,
	})
end

--- Opening-night countdown: rubbed-out earlier numbers and today's big zero.
function LoreProps.countdown(parent: Instance, cf: CFrame, size: Vector2): BasePart
	local part = Builders.part({
		name = "CountdownBoard",
		size = Vector3.new(size.X, size.Y, 0.25),
		cframe = cf * CFrame.new(0, 0, -0.12),
		parent = parent,
		surface = "Chalkboard",
		decor = true,
	})
	local gui = newGui(part, Enum.NormalId.Front)
	local heading = Instance.new("TextLabel")
	heading.Size = UDim2.new(1, 0, 0.2, 0)
	heading.Position = UDim2.fromScale(0, 0.06)
	heading.BackgroundTransparency = 1
	heading.Text = Lore.Countdown.Heading
	heading.Font = Theme.Fonts.Bold
	heading.TextScaled = true
	heading.TextColor3 = Theme.Colors.PaperShade
	heading.Parent = gui

	local big = Instance.new("TextLabel")
	big.Size = UDim2.fromScale(0.5, 0.5)
	big.Position = UDim2.fromScale(0.25, 0.26)
	big.BackgroundTransparency = 1
	big.Text = Lore.Countdown.Current
	big.Font = Theme.Fonts.Title
	big.TextScaled = true
	big.TextColor3 = Theme.Colors.Paper
	big.Parent = gui

	-- Earlier days, rubbed out and rewritten smaller along the bottom.
	local row = Instance.new("Frame")
	row.Size = UDim2.fromScale(0.86, 0.16)
	row.Position = UDim2.fromScale(0.07, 0.62)
	row.BackgroundTransparency = 1
	row.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.Parent = row
	for index, day in Lore.Countdown.Previous do
		local label = Instance.new("TextLabel")
		label.LayoutOrder = index
		label.Size = UDim2.fromScale(0.14, 1)
		label.BackgroundTransparency = 1
		label.Text = day
		label.Font = Theme.Fonts.Mono
		label.TextScaled = true
		label.TextTransparency = 0.55
		label.TextColor3 = Theme.Colors.PaperShade
		label.Parent = row
		strikeThrough(label, Theme.Colors.PaperShade)
	end

	local footer = Instance.new("TextLabel")
	footer.Size = UDim2.new(1, 0, 0.14, 0)
	footer.Position = UDim2.fromScale(0, 0.82)
	footer.BackgroundTransparency = 1
	footer.Text = Lore.Countdown.Footer
	footer.Font = Theme.Fonts.Bold
	footer.TextScaled = true
	footer.TextColor3 = Theme.Colors.UiAccent
	footer.Parent = gui
	return part
end

--- A manila costume tag on a string, hung from a rail.
function LoreProps.costumeTag(
	parent: Instance,
	anchor: Vector3,
	facing: Vector3,
	tag: { role: string, name: string, struck: boolean?, accent: boolean? }
)
	local drop = 1.1
	Builders.part({
		name = "TagString",
		size = Vector3.new(0.06, drop, 0.06),
		cframe = CFrame.new(anchor - Vector3.new(0, drop / 2, 0)),
		parent = parent,
		surface = "Rope",
		decor = true,
	})
	local cardPos = anchor - Vector3.new(0, drop + 0.6, 0)
	local card = Builders.part({
		name = "CostumeTag",
		size = Vector3.new(1.5, 1.1, 0.06),
		cframe = CFrame.lookAt(cardPos, cardPos + facing) * CFrame.Angles(0, 0, math.rad(6)),
		parent = parent,
		surface = "TagCard",
		decor = true,
	})
	local gui = newGui(card, Enum.NormalId.Front)
	gui.PixelsPerStud = 64
	local role = Instance.new("TextLabel")
	role.Size = UDim2.fromScale(1, 0.38)
	role.Position = UDim2.fromScale(0, 0.12)
	role.BackgroundTransparency = 1
	role.Text = tag.role
	role.Font = Theme.Fonts.Bold
	role.TextScaled = true
	role.TextColor3 = Color3.fromRGB(110, 86, 52)
	role.Parent = gui
	local name = Instance.new("TextLabel")
	name.Size = UDim2.fromScale(1, 0.34)
	name.Position = UDim2.fromScale(0, 0.5)
	name.BackgroundTransparency = 1
	name.Text = tag.name
	name.Font = Theme.Fonts.Title
	name.TextScaled = true
	name.TextColor3 = if tag.accent then Color3.fromRGB(150, 24, 36) else Color3.fromRGB(52, 40, 28)
	name.Parent = gui
	if tag.struck then
		name.TextTransparency = 0.3
		strikeThrough(name, Color3.fromRGB(150, 24, 36))
	end
end

--- Loose script pages, scattered flat on a surface.
function LoreProps.scriptPages(parent: Instance, rng: Random, center: Vector3, radius: number, count: number)
	for i = 1, count do
		local angle = rng:NextNumber() * math.pi * 2
		local distance = radius * math.sqrt(rng:NextNumber())
		local pos = center + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
		local page = Builders.part({
			name = "ScriptPage",
			size = Vector3.new(1.5, 0.04, 2),
			cframe = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber() * math.pi * 2, 0),
			parent = parent,
			surface = "BookPage",
			decor = true,
		})
		local gui = newGui(page, Enum.NormalId.Top)
		gui.PixelsPerStud = 48
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(0.86, 0.3)
		label.Position = UDim2.fromScale(0.07, 0.3)
		label.BackgroundTransparency = 1
		label.Text = Lore.ScriptPages[(i - 1) % #Lore.ScriptPages + 1]
		label.Font = Theme.Fonts.Mono
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(82, 72, 64)
		label.Parent = gui
	end
end

--- The open prompt book on a stand: the last cues anyone wrote down.
function LoreProps.promptBook(parent: Instance, cf: CFrame)
	Builders.part({
		name = "PromptStandPost",
		size = Vector3.new(0.3, 4, 0.3),
		cframe = cf * CFrame.new(0, 2, 0),
		parent = parent,
		surface = "Iron",
		decor = true,
	})
	Builders.part({
		name = "PromptStandFoot",
		size = Vector3.new(1.8, 0.2, 1.8),
		cframe = cf * CFrame.new(0, 0.1, 0),
		parent = parent,
		surface = "Iron",
		decor = true,
	})
	local desk = Builders.part({
		name = "PromptDesk",
		size = Vector3.new(4.4, 0.2, 3),
		cframe = cf * CFrame.new(0, 4.1, 0) * CFrame.Angles(math.rad(-18), 0, 0),
		parent = parent,
		surface = "DarkWood",
		decor = true,
	})
	local book = Builders.part({
		name = "PromptBook",
		size = Vector3.new(4, 0.14, 2.6),
		cframe = desk.CFrame * CFrame.new(0, 0.17, 0),
		parent = parent,
		surface = "BookPage",
		decor = true,
	})
	local gui = newGui(book, Enum.NormalId.Top)
	gui.PixelsPerStud = 48
	for side, pageLines in { Lore.PromptBook.Left, Lore.PromptBook.Right } do
		local column = Instance.new("Frame")
		column.Size = UDim2.fromScale(0.44, 0.82)
		column.Position = UDim2.fromScale(if side == 1 then 0.04 else 0.52, 0.09)
		column.BackgroundTransparency = 1
		column.Parent = gui
		local layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0, 2)
		layout.Parent = column
		for index, line in pageLines do
			textLine(column, line, Theme.Fonts.Mono, Color3.fromRGB(80, 70, 62), 14, index)
		end
	end
	-- The spine crease.
	Builders.part({
		name = "PromptBookSpine",
		size = Vector3.new(0.1, 0.16, 2.6),
		cframe = book.CFrame,
		parent = parent,
		surface = "AgedWood",
		decor = true,
	})
end

-- ── Marks that teach a mechanic ───────────────────────────────────────────────────────────

--- Scuff marks dragged along the floor toward a painted door: the hint that something
--- heavy keeps going that way. Flat (0.04 studs) so they never affect movement.
function LoreProps.scuffTrail(parent: Instance, rng: Random, from: Vector3, to: Vector3, count: number?)
	local total = count or 7
	local direction = to - from
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude < 0.1 then
		return
	end
	local yaw = math.atan2(flat.X, flat.Z)
	for i = 1, total do
		local alpha = (i - 0.5) / total
		-- Streaks get longer and darker closer to the door.
		local pos = from:Lerp(to, alpha)
		local jitter = Vector3.new(rng:NextNumber(-1.1, 1.1), 0, rng:NextNumber(-1.1, 1.1))
		Builders.part({
			name = "ScuffMark",
			size = Vector3.new(rng:NextNumber(0.35, 0.7), 0.04, 1.4 + alpha * 2.2),
			cframe = CFrame.new(pos + jitter) * CFrame.Angles(0, yaw + rng:NextNumber(-0.18, 0.18), 0),
			parent = parent,
			surface = "ScuffMark",
			decor = true,
		})
	end
end

--- Fresh footprints in the dust: pairs of pale soles walking from `from` to `to`.
function LoreProps.footprints(parent: Instance, rng: Random, from: Vector3, to: Vector3, stride: number?)
	local step = stride or 3.2
	local direction = to - from
	local flat = Vector3.new(direction.X, 0, direction.Z)
	local distance = flat.Magnitude
	if distance < step then
		return
	end
	local forward = flat.Unit
	local side = Vector3.new(-forward.Z, 0, forward.X)
	local yaw = math.atan2(forward.X, forward.Z)
	local steps = math.floor(distance / step)
	for i = 0, steps do
		local pos = from + forward * (i * step) + side * (if i % 2 == 0 then 0.75 else -0.75)
		-- Prints fade out the further they are from where they were made.
		local fade = 0.45 + 0.4 * (i / math.max(steps, 1))
		local sole = Builders.part({
			name = "Footprint",
			size = Vector3.new(0.7, 0.04, 1.5),
			cframe = CFrame.new(pos) * CFrame.Angles(0, yaw + rng:NextNumber(-0.12, 0.12), 0),
			parent = parent,
			surface = "DustPrint",
			decor = true,
		})
		sole.Transparency = fade
	end
end

--- A thin film of dust on a surface, so footprints read as tracks through it.
function LoreProps.dustFilm(parent: Instance, cf: CFrame, size: Vector3)
	Builders.part({
		name = "DustFilm",
		size = Vector3.new(size.X, 0.03, size.Z),
		cframe = cf * CFrame.new(0, size.Y / 2 + 0.015, 0),
		parent = parent,
		surface = "DustFilm",
		decor = true,
	})
end

return LoreProps
