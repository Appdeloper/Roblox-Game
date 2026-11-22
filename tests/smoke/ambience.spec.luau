--[[
	Ambience spec — the layered 3D soundscape.

	The valuable invariant here is reach: every layer must fall silent well before the next
	stage begins, or players would hear another room through the wall.
]]

return function(h, check)
	print("\n== Smoke: ambience")
	local SSS = h.place:GetService("ServerScriptService")
	local RS = h.place:GetService("ReplicatedStorage")
	local Config = h.require(RS.Shared.Config)
	local Assets = h.require(RS.Shared.Assets)
	local AmbienceService = h.require(SSS.Services.AmbienceService)

	AmbienceService.init()
	local folder = h.place:GetService("Workspace"):FindFirstChild("Ambience")
	check(folder ~= nil, "Workspace.Ambience built")
	if not folder then
		return
	end

	local emitters = folder:GetChildren()
	check(#emitters >= 15, string.format("%d ambience emitters placed around the building", #emitters))

	-- How far apart the rooms are: nothing may be audible across that gap.
	local gap = math.huge
	local origins = { Config.Map.LobbyOrigin, table.unpack(Config.Map.StageOrigins) }
	for i = 1, #origins do
		for j = i + 1, #origins do
			local a, b = origins[i], origins[j]
			local dx, dy, dz = a[1] - b[1], a[2] - b[2], a[3] - b[3]
			gap = math.min(gap, math.sqrt(dx * dx + dy * dy + dz * dz))
		end
	end

	local perStage = {}
	local problems = {}
	for _, host in emitters do
		local sound = host:FindFirstChildWhichIsA("Sound")
		local stage = host:GetAttribute("Stage")
		perStage[stage] = (perStage[stage] or 0) + 1
		if not sound then
			table.insert(problems, host.Name .. " has no Sound")
		elseif not sound.Looped then
			table.insert(problems, host.Name .. " is not looped")
		elseif sound.RollOffMinDistance >= sound.RollOffMaxDistance then
			table.insert(problems, host.Name .. " has backwards rolloff distances")
		elseif sound.RollOffMaxDistance >= gap then
			table.insert(
				problems,
				string.format(
					"%s carries %d studs, past the %d to the next room",
					host.Name,
					sound.RollOffMaxDistance,
					gap
				)
			)
		end
	end
	check(
		#problems == 0,
		"every layer is looped, 3D and fades out before the next room"
			.. (if #problems > 0 then " — " .. problems[1] else "")
	)

	for stage = 1, Config.Game.StageCount do
		check((perStage[stage] or 0) >= 4, string.format("stage %d has a layered soundscape", stage))
	end
	check((perStage[0] or 0) >= 2, "the lobby has ambience too")

	-- Every layer must point at a real entry in Assets, so a rename cannot silently break one.
	local missing = {}
	for name, layer in Config.Ambience.Layers do
		if (Assets.Sounds :: any)[layer.asset] == nil then
			table.insert(missing, name)
		end
	end
	check(#missing == 0, "every ambience layer maps to an Assets entry")

	-- A reverb preset per room, so no stage falls back to a dry default by accident.
	check(Config.Ambience.Reverb.Lobby ~= nil, "lobby reverb preset")
	check(#Config.Ambience.Reverb.Stages == Config.Game.StageCount, "one reverb preset per stage")
end
