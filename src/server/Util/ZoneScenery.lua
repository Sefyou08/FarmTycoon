--[[
	ZoneScenery.lua
	===============
	Décor des zones d'expédition (phase 10) : chaque zone a sa propre identité.
	  Forest   : herbe, grands arbres à étages, champignons géants (certains lumineux),
	             rivière avec un pont, troncs couchés, fougères, fleurs.
	  Mountain : neige et roche, sapins enneigés, rochers, cristaux de glace,
	             lac gelé, hautes montagnes en arrière-plan.
	  Desert   : sable, dunes, cactus, ruines (colonnes, arche, pyramide), oasis à palmiers.
	  Volcan   : basalte et lave craquelée, volcan fumant en arrière-plan, coulées de lave
	             lumineuses, pics d'obsidienne, cheminées de fumée.
	La zone de jeu (où apparaissent les créatures) reste plate ; le relief est au bord
	et derrière les falaises. L'éclairage, le brouillard, les particules d'ambiance
	(lucioles, flocons, sable, braises) et la musique sont gérés côté client
	(LightingController, Config.Art).

	  ZoneScenery.Build(zoneId, def, folder, arrivalPosition)
]]

local Workspace = game:GetService("Workspace")

local ArtKit = require(script.Parent.ArtKit)

local ZoneScenery = {}

local rgb = Color3.fromRGB
local terrain = Workspace.Terrain

type Env = {
	Folder: Folder,
	Center: Vector3,
	Half: number, -- demi-côté de la zone
	Arrival: Vector3,
	Rng: Random,
}

-- Point au hasard dans la zone ; inner = true -> zone de jeu, sinon bande du bord
local function spot(env: Env, margin: number, nearEdge: boolean?): Vector3
	for _ = 1, 30 do
		local x, z
		if nearEdge then
			local side = env.Rng:NextInteger(1, 4)
			local t = env.Rng:NextNumber(-env.Half + 8, env.Half - 8)
			local depth = env.Rng:NextNumber(env.Half - 30, env.Half - 8)
			x = if side <= 2 then t else (if side == 3 then depth else -depth)
			z = if side <= 2 then (if side == 1 then depth else -depth) else t
		else
			x = env.Rng:NextNumber(-env.Half + margin, env.Half - margin)
			z = env.Rng:NextNumber(-env.Half + margin, env.Half - margin)
		end
		local p = env.Center + Vector3.new(x, 0, z)
		if (Vector3.new(p.X, env.Arrival.Y, p.Z) - env.Arrival).Magnitude > 28 then
			return p
		end
	end
	return env.Center + Vector3.new(env.Half - 15, 0, env.Half - 15)
end

-- Sol plat, falaises en terrain tout autour, relief derrière
-- partColor : sol lisse en Parts (sans herbe) au lieu du Terrain ; gapZ = bande laissée
-- ouverte pour une rivière (décalage Z depuis le centre, largeur)
local function ground(env: Env, floor: Enum.Material, cliff: Enum.Material, cap: Enum.Material?, partColor: Color3?, gapZ: number?, gapWidth: number?)
	local c, size = env.Center, env.Half * 2
	if partColor then
		-- Sol en Parts « Grass » seulement, SANS Terrain dessous (il ressortait au travers)
		local full = size + 120
		local minZ, maxZ = -full / 2, full / 2
		local pieces = if gapZ then { { minZ, gapZ - gapWidth / 2 }, { gapZ + gapWidth / 2, maxZ } } else { { minZ, maxZ } }
		for _, piece in pieces do
			local depth = piece[2] - piece[1]
			ArtKit.Block(env.Folder, "ZoneGround", Vector3.new(full, 8, depth), CFrame.new(c + Vector3.new(0, -4, (piece[1] + piece[2]) / 2)), partColor, Enum.Material.Grass, { CanCollide = true, CanQuery = true, CastShadow = false })
		end
	else
		terrain:FillBlock(CFrame.new(c - Vector3.new(0, 6, 0)), Vector3.new(size + 120, 12, size + 120), floor)
	end
	-- Falaises (4 murs irréguliers)
	for i = 0, 23 do
		local t = (i % 6) / 6 * size - env.Half + size / 12
		local side = i // 6
		local pos = if side == 0 then Vector3.new(t, 0, env.Half + 12)
			elseif side == 1 then Vector3.new(t, 0, -env.Half - 12)
			elseif side == 2 then Vector3.new(env.Half + 12, 0, t)
			else Vector3.new(-env.Half - 12, 0, t)
		local r = env.Rng:NextNumber(26, 38)
		terrain:FillBall(c + pos + Vector3.new(0, r * 0.3, 0), r, cliff)
		if cap then
			terrain:FillBall(c + pos + Vector3.new(0, r * 0.95, 0), r * 0.45, cap)
		end
	end
end

local function tree(env: Env, pos: Vector3, height: number, trunk: Color3, leaves: { Color3 }, tiers: number)
	local model = Instance.new("Model")
	model.Name = "BigTree"
	local base = CFrame.new(pos) * CFrame.Angles(0, env.Rng:NextNumber(0, 6.28), 0)
	ArtKit.Cylinder(model, "Trunk", height, height * 0.14, base * CFrame.new(0, height / 2, 0), trunk, Enum.Material.Wood, { CanCollide = true })
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2
		ArtKit.Ellipsoid(model, "Root", Vector3.new(height * 0.08, height * 0.08, height * 0.3), base * CFrame.new(math.cos(a) * height * 0.1, height * 0.02, math.sin(a) * height * 0.1) * CFrame.Angles(0, -a + math.pi / 2, 0), trunk, Enum.Material.Wood)
	end
	for i = 1, tiers do
		local y = height * (0.55 + i * 0.18)
		local d = height * (0.9 - i * 0.15)
		ArtKit.Ellipsoid(model, "Canopy", Vector3.new(d, d * 0.45, d), base * CFrame.new(0, y, 0), leaves[(i - 1) % #leaves + 1], Enum.Material.Grass)
	end
	model.Parent = env.Folder
end

--------------------------------------------------------------------------
-- 🌲 Forêt
--------------------------------------------------------------------------

local function forest(env: Env)
	-- Sol vert lisse (pas d'herbe), falaises de roche ; rivière le long du bord nord avec un pont
	local riverZ = env.Half - 22
	ground(env, Enum.Material.Ground, Enum.Material.Rock, nil, rgb(90, 155, 60), riverZ, 12)
	local leaves = { rgb(60, 140, 55), rgb(80, 165, 60), rgb(50, 120, 50) }
	local c = env.Center
	-- Rivière dans la fente entre les sols : lit de sable + eau, sous le niveau du sol
	terrain:FillBlock(CFrame.new(c + Vector3.new(0, -6, riverZ)), Vector3.new(env.Half * 2 + 120, 4, 12), Enum.Material.Sand)
	terrain:FillBlock(CFrame.new(c + Vector3.new(0, -2.5, riverZ)), Vector3.new(env.Half * 2 + 120, 3, 12), Enum.Material.Water)
	local bridge = CFrame.new(c + Vector3.new(-40, 0, riverZ))
	for i = -3, 3 do
		ArtKit.Block(env.Folder, "BridgePlank", Vector3.new(6, 0.4, 2), bridge * CFrame.new(0, 0.6 + (1 - math.abs(i) / 3) * 0.8, i * 2), rgb(140, 95, 60), Enum.Material.WoodPlanks, { CanCollide = true })
	end
	for _, sx in { -1, 1 } do
		ArtKit.Block(env.Folder, "BridgeRail", Vector3.new(0.3, 0.3, 15), bridge * CFrame.new(sx * 3, 2.6, 0), rgb(110, 75, 45), Enum.Material.Wood)
	end

	-- Grands arbres (bord) et arbres moyens (intérieur)
	for _ = 1, 26 do
		tree(env, spot(env, 0, true), env.Rng:NextNumber(18, 30), rgb(100, 70, 45), leaves, 3)
	end
	for _ = 1, 14 do
		tree(env, spot(env, 20), env.Rng:NextNumber(10, 15), rgb(115, 80, 50), leaves, 2)
	end
	-- Champignons géants (certains lumineux)
	for i = 1, 12 do
		local pos = spot(env, 15, i % 2 == 0)
		local h = env.Rng:NextNumber(3, 7)
		local glowing = i % 3 == 0
		local capColor = if glowing then rgb(90, 200, 255) else (if i % 2 == 0 then rgb(220, 50, 50) else rgb(230, 150, 60))
		ArtKit.Cylinder(env.Folder, "MushroomStem", h, h * 0.3, CFrame.new(pos + Vector3.new(0, h / 2, 0)), rgb(245, 235, 215))
		local cap = ArtKit.Ellipsoid(env.Folder, "MushroomCap", Vector3.new(h * 1.2, h * 0.45, h * 1.2), CFrame.new(pos + Vector3.new(0, h, 0)), capColor, if glowing then Enum.Material.Neon else nil)
		if glowing then
			ArtKit.Light(cap, capColor, 14, 1.5)
		else
			for k = 0, 4 do
				local a = k / 5 * math.pi * 2
				ArtKit.Ball(env.Folder, "CapSpot", h * 0.18, CFrame.new(pos + Vector3.new(math.cos(a) * h * 0.35, h * 1.12, math.sin(a) * h * 0.35)), rgb(255, 255, 255))
			end
		end
	end
	-- Troncs couchés, fougères, fleurs
	for _ = 1, 8 do
		local pos = spot(env, 20)
		ArtKit.Disc(env.Folder, "Log", env.Rng:NextNumber(6, 10), 2, CFrame.new(pos + Vector3.new(0, 1, 0)) * CFrame.Angles(0, env.Rng:NextNumber(0, 6.28), 0), rgb(110, 75, 45), Enum.Material.Wood)
	end
	for _ = 1, 40 do
		local pos = spot(env, 10)
		for k = 0, 3 do
			ArtKit.Wedge(env.Folder, "Fern", Vector3.new(0.2, 1.6, 1.2), CFrame.new(pos) * CFrame.Angles(0, k * math.pi / 2, 0) * CFrame.new(0, 0.8, 0.6) * CFrame.Angles(math.rad(25), 0, 0), rgb(70, 160, 60))
		end
	end
	for _ = 1, 50 do
		local pos = spot(env, 8)
		ArtKit.Ball(env.Folder, "Flower", 0.7, CFrame.new(pos + Vector3.new(0, 0.5, 0)), ({ rgb(255, 120, 180), rgb(255, 230, 90), rgb(180, 140, 255) })[env.Rng:NextInteger(1, 3)])
	end
end

--------------------------------------------------------------------------
-- ⛰️ Montagne
--------------------------------------------------------------------------

local function snowyPine(env: Env, pos: Vector3, scale: number)
	local base = CFrame.new(pos)
	ArtKit.Cylinder(env.Folder, "Trunk", 4 * scale, 1.2 * scale, base * CFrame.new(0, 2 * scale, 0), rgb(95, 65, 45), Enum.Material.Wood, { CanCollide = true })
	for i, w in { 9, 7, 5 } do
		local tier = base * CFrame.new(0, (2.5 + (i - 1) * 3.2) * scale + 2.2 * scale, 0)
		for _, rot in { 0, 90 } do
			ArtKit.Triangle(env.Folder, "Needles", w * scale, 4.4 * scale, w * 0.6 * scale, tier * CFrame.Angles(0, math.rad(rot), 0), rgb(45, 100, 70), Enum.Material.Grass)
			ArtKit.Triangle(env.Folder, "SnowCap", w * 0.55 * scale, 2 * scale, w * 0.62 * scale, tier * CFrame.new(0, 1.3 * scale, 0) * CFrame.Angles(0, math.rad(rot), 0), rgb(245, 250, 255), Enum.Material.Snow)
		end
	end
end

local function mountain(env: Env)
	terrain:SetMaterialColor(Enum.Material.Snow, rgb(240, 246, 255))
	terrain:SetMaterialColor(Enum.Material.Glacier, rgb(170, 220, 250))
	ground(env, Enum.Material.Snow, Enum.Material.Rock, Enum.Material.Snow)
	local c = env.Center
	-- Hautes montagnes en arrière-plan
	for i = 0, 6 do
		local x = (i - 3) * 70
		local r = env.Rng:NextNumber(70, 110)
		terrain:FillBall(c + Vector3.new(x, r * 0.2, env.Half + 90 + env.Rng:NextNumber(0, 40)), r, Enum.Material.Rock)
		terrain:FillBall(c + Vector3.new(x, r * 0.95, env.Half + 90), r * 0.5, Enum.Material.Snow)
	end
	-- Lac gelé (plat : on peut marcher dessus)
	local lake = c + Vector3.new(env.Half - 45, 0, -env.Half + 50)
	terrain:FillCylinder(CFrame.new(lake - Vector3.new(0, 1, 0)), 2, 22, Enum.Material.Glacier)
	for _ = 1, 30 do
		snowyPine(env, spot(env, 0, true), env.Rng:NextNumber(1.1, 1.8))
	end
	for _ = 1, 10 do
		snowyPine(env, spot(env, 25), env.Rng:NextNumber(0.8, 1.1))
	end
	for _ = 1, 22 do
		local pos = spot(env, 10)
		local size = env.Rng:NextNumber(3, 8)
		ArtKit.Ellipsoid(env.Folder, "Boulder", Vector3.new(size * 1.3, size * 0.8, size), CFrame.new(pos + Vector3.new(0, size * 0.25, 0)) * CFrame.Angles(0, env.Rng:NextNumber(0, 6.28), 0), rgb(130, 135, 150), Enum.Material.Slate, { CanCollide = true })
		ArtKit.Ellipsoid(env.Folder, "BoulderSnow", Vector3.new(size * 1.1, size * 0.3, size * 0.8), CFrame.new(pos + Vector3.new(0, size * 0.6, 0)), rgb(245, 250, 255), Enum.Material.Snow)
	end
	-- Cristaux de glace lumineux
	for i = 1, 14 do
		local pos = spot(env, 12, i % 2 == 0)
		local cluster = CFrame.new(pos)
		for k = 0, 2 do
			local h = env.Rng:NextNumber(2, 5)
			local crystal = ArtKit.Wedge(env.Folder, "IceCrystal", Vector3.new(0.8, h, 1), cluster * CFrame.Angles(0, k * 2.1, math.rad((k - 1) * 18)) * CFrame.new(0, h / 2, 0), rgb(160, 220, 255), Enum.Material.Glass, { Transparency = 0.2, Reflectance = 0.3 })
			if k == 0 then
				ArtKit.Light(crystal, rgb(150, 210, 255), 10, 1)
			end
		end
	end
end

--------------------------------------------------------------------------
-- 🏜️ Désert
--------------------------------------------------------------------------

local function saguaro(env: Env, pos: Vector3)
	local h = env.Rng:NextNumber(6, 11)
	local base = CFrame.new(pos) * CFrame.Angles(0, env.Rng:NextNumber(0, 6.28), 0)
	local green = rgb(80, 160, 80)
	ArtKit.Cylinder(env.Folder, "Cactus", h, 1.8, base * CFrame.new(0, h / 2, 0), green, Enum.Material.Grass, { CanCollide = true })
	ArtKit.Ball(env.Folder, "CactusTop", 1.8, base * CFrame.new(0, h, 0), green, Enum.Material.Grass)
	for _, sx in { -1, 1 } do
		local armY = h * env.Rng:NextNumber(0.4, 0.6)
		ArtKit.Disc(env.Folder, "CactusArm", 2, 1.1, base * CFrame.new(sx * 1.6, armY, 0), green, Enum.Material.Grass)
		ArtKit.Cylinder(env.Folder, "CactusArm", 2.5, 1.1, base * CFrame.new(sx * 2.5, armY + 1.2, 0), green, Enum.Material.Grass)
		ArtKit.Ball(env.Folder, "CactusArmTop", 1.1, base * CFrame.new(sx * 2.5, armY + 2.45, 0), green, Enum.Material.Grass)
	end
	if env.Rng:NextNumber() < 0.4 then
		ArtKit.Ball(env.Folder, "CactusFlower", 0.8, base * CFrame.new(0, h + 0.8, 0), rgb(255, 120, 180))
	end
end

local function desert(env: Env)
	terrain:SetMaterialColor(Enum.Material.Sand, rgb(235, 205, 145))
	terrain:SetMaterialColor(Enum.Material.Sandstone, rgb(210, 160, 100))
	ground(env, Enum.Material.Sand, Enum.Material.Sandstone, Enum.Material.Sand)
	local c = env.Center
	-- Dunes au loin
	for i = 0, 8 do
		local a = i / 9 * math.pi * 2
		local r = env.Rng:NextNumber(50, 80)
		terrain:FillBall(c + Vector3.new(math.cos(a) * (env.Half + 80), -r * 0.55, math.sin(a) * (env.Half + 80)), r, Enum.Material.Sand)
	end
	-- Pyramide en arrière-plan (marches de grès)
	local pyramid = c + Vector3.new(60, 0, env.Half + 70)
	for i = 0, 9 do
		local w = 90 - i * 9
		ArtKit.Block(env.Folder, "PyramidStep", Vector3.new(w, 6, w), CFrame.new(pyramid + Vector3.new(0, 3 + i * 6, 0)), rgb(225, 185, 115), Enum.Material.Sandstone)
	end
	ArtKit.Block(env.Folder, "PyramidTop", Vector3.new(6, 4, 6), CFrame.new(pyramid + Vector3.new(0, 62, 0)), rgb(255, 210, 80), Enum.Material.Foil)
	-- Ruines : colonnes brisées et une arche
	for i = 1, 10 do
		local pos = spot(env, 15, i % 3 == 0)
		local h = env.Rng:NextNumber(4, 12)
		ArtKit.Cylinder(env.Folder, "Column", h, 2.4, CFrame.new(pos + Vector3.new(0, h / 2, 0)), rgb(220, 190, 140), Enum.Material.Sandstone, { CanCollide = true })
		ArtKit.Block(env.Folder, "ColumnBase", Vector3.new(3.4, 1, 3.4), CFrame.new(pos + Vector3.new(0, 0.5, 0)), rgb(205, 175, 125), Enum.Material.Sandstone)
		if h > 9 then
			ArtKit.Block(env.Folder, "ColumnTop", Vector3.new(3.2, 0.8, 3.2), CFrame.new(pos + Vector3.new(0, h + 0.4, 0)), rgb(205, 175, 125), Enum.Material.Sandstone)
		else
			ArtKit.Block(env.Folder, "Rubble", Vector3.new(2, 1.2, 1.6), CFrame.new(pos + Vector3.new(2.2, 0.6, 1)) * CFrame.Angles(0, 0.6, 0.2), rgb(215, 185, 135), Enum.Material.Sandstone)
		end
	end
	local arch = CFrame.new(c + Vector3.new(-env.Half + 35, 0, 10)) * CFrame.Angles(0, math.rad(90), 0)
	for _, sx in { -1, 1 } do
		ArtKit.Block(env.Folder, "ArchPillar", Vector3.new(3, 12, 3), arch * CFrame.new(sx * 6, 6, 0), rgb(215, 180, 125), Enum.Material.Sandstone, { CanCollide = true })
	end
	ArtKit.Block(env.Folder, "ArchTop", Vector3.new(16, 3, 3.4), arch * CFrame.new(0, 13.5, 0), rgb(215, 180, 125), Enum.Material.Sandstone)
	ArtKit.Block(env.Folder, "ArchGem", Vector3.new(1.5, 1.5, 3.6), arch * CFrame.new(0, 13.5, 0) * CFrame.Angles(0, 0, math.rad(45)), rgb(80, 200, 255), Enum.Material.Neon)
	-- Oasis : petit lac et palmiers
	local oasis = c + Vector3.new(env.Half - 24, 0, env.Half - 24)
	terrain:FillCylinder(CFrame.new(oasis - Vector3.new(0, 2.5, 0)), 5, 16, Enum.Material.Air)
	terrain:FillCylinder(CFrame.new(oasis - Vector3.new(0, 3.2, 0)), 3.5, 16, Enum.Material.Water)
	for k = 0, 4 do
		local a = k / 5 * math.pi * 2
		local base = CFrame.new(oasis + Vector3.new(math.cos(a) * 20, 0, math.sin(a) * 20))
		local h = env.Rng:NextNumber(9, 13)
		for j = 0, 4 do
			ArtKit.Cylinder(env.Folder, "PalmTrunk", h / 5 + 0.2, 1.2 - j * 0.1, base * CFrame.new(j * 0.35, h / 10 + j * h / 5, 0) * CFrame.Angles(0, 0, math.rad(-6)), rgb(150, 110, 70), Enum.Material.Wood)
		end
		for leaf = 0, 5 do
			local la = leaf / 6 * math.pi * 2
			ArtKit.Ellipsoid(env.Folder, "PalmLeaf", Vector3.new(1.4, 0.3, 6), base * CFrame.new(1.7, h, 0) * CFrame.Angles(0, la, 0) * CFrame.new(0, -0.6, -2.8) * CFrame.Angles(math.rad(-20), 0, 0), rgb(70, 160, 70), Enum.Material.Grass)
		end
		ArtKit.Ball(env.Folder, "Coconut", 0.9, base * CFrame.new(1.7, h - 0.6, 0.5), rgb(120, 80, 45))
	end
	for _ = 1, 24 do
		saguaro(env, spot(env, 12))
	end
	for _ = 1, 30 do
		local pos = spot(env, 8)
		ArtKit.Ellipsoid(env.Folder, "DesertRock", Vector3.new(3, 1.6, 2.4), CFrame.new(pos + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, env.Rng:NextNumber(0, 6), 0), rgb(195, 140, 90), Enum.Material.Sandstone)
	end
end

--------------------------------------------------------------------------
-- 🌋 Volcan
--------------------------------------------------------------------------

local function volcano(env: Env)
	terrain:SetMaterialColor(Enum.Material.Basalt, rgb(45, 38, 40))
	terrain:SetMaterialColor(Enum.Material.CrackedLava, rgb(255, 90, 30))
	ground(env, Enum.Material.Basalt, Enum.Material.Basalt, Enum.Material.CrackedLava)
	local c = env.Center
	-- Plaques de lave craquelée au sol
	for _ = 1, 10 do
		local pos = spot(env, 15)
		terrain:FillCylinder(CFrame.new(pos - Vector3.new(0, 0.6, 0)), 1.2, env.Rng:NextNumber(5, 10), Enum.Material.CrackedLava)
	end
	-- Grand volcan fumant derrière la falaise nord
	local peak = c + Vector3.new(0, 0, env.Half + 110)
	terrain:FillBall(peak + Vector3.new(0, -20, 0), 120, Enum.Material.Basalt)
	terrain:FillCylinder(CFrame.new(peak + Vector3.new(0, 95, 0)), 20, 26, Enum.Material.CrackedLava)
	local crater = ArtKit.Ball(env.Folder, "CraterGlow", 30, CFrame.new(peak + Vector3.new(0, 100, 0)), rgb(255, 110, 30), Enum.Material.Neon)
	ArtKit.Light(crater, rgb(255, 120, 40), 60, 3)
	ArtKit.Particles(crater, { Name = "VolcanoSmoke", Color = ColorSequence.new(rgb(70, 60, 60)), LightEmission = 0, Rate = 8, Lifetime = NumberRange.new(6, 9), Speed = NumberRange.new(10, 16), Size = NumberSequence.new(10, 30), Transparency = NumberSequence.new(0.3, 1), SpreadAngle = Vector2.new(20, 20), EmissionDirection = Enum.NormalId.Top })
	-- Coulées de lave lumineuses
	for i = 1, 6 do
		local start = spot(env, 0, true)
		local dir = (c - start) * Vector3.new(1, 0, 1)
		local length = env.Rng:NextNumber(25, 45)
		local stepCount = 5
		for k = 0, stepCount - 1 do
			local p = start + dir.Unit * (k * length / stepCount) + Vector3.new(math.sin(k + i) * 3, 0, math.cos(k + i) * 3)
			local lava = ArtKit.Block(env.Folder, "LavaFlow", Vector3.new(4 - k * 0.4, 0.3, length / stepCount + 1), CFrame.lookAt(p + Vector3.new(0, 0.1, 0), p + dir), rgb(255, 100, 20), Enum.Material.Neon)
			if k % 2 == 0 then
				ArtKit.Light(lava, rgb(255, 110, 30), 14, 1.5)
			end
		end
	end
	-- Pics d'obsidienne et roches volcaniques
	for _ = 1, 16 do
		local pos = spot(env, 12)
		for k = 0, 2 do
			local h = env.Rng:NextNumber(3, 8)
			ArtKit.Wedge(env.Folder, "Obsidian", Vector3.new(1.2, h, 1.6), CFrame.new(pos) * CFrame.Angles(0, k * 2.1, math.rad((k - 1) * 15)) * CFrame.new(0, h / 2, 0), rgb(30, 20, 35), Enum.Material.Glass, { Reflectance = 0.25, CanCollide = true })
		end
	end
	for _ = 1, 20 do
		local pos = spot(env, 8)
		local size = env.Rng:NextNumber(2.5, 6)
		ArtKit.Ellipsoid(env.Folder, "LavaRock", Vector3.new(size * 1.2, size * 0.7, size), CFrame.new(pos + Vector3.new(0, size * 0.2, 0)), rgb(45, 35, 35), Enum.Material.Basalt, { CanCollide = true })
	end
	-- Cheminées de fumée et de braises
	for _ = 1, 8 do
		local pos = spot(env, 15)
		local vent = ArtKit.Cylinder(env.Folder, "Vent", 1.6, 3, CFrame.new(pos + Vector3.new(0, 0.8, 0)), rgb(60, 45, 40), Enum.Material.Basalt)
		ArtKit.Particles(vent, { Name = "VentSmoke", Color = ColorSequence.new(rgb(90, 80, 80)), LightEmission = 0, Rate = 3, Lifetime = NumberRange.new(3, 5), Speed = NumberRange.new(3, 5), Size = NumberSequence.new(1.5, 5), Transparency = NumberSequence.new(0.3, 1), SpreadAngle = Vector2.new(10, 10), EmissionDirection = Enum.NormalId.Right })
		ArtKit.Particles(vent, { Name = "VentEmbers", Color = ColorSequence.new(rgb(255, 200, 60), rgb(255, 60, 20)), LightEmission = 1, Rate = 6, Lifetime = NumberRange.new(1, 2), Speed = NumberRange.new(4, 7), Size = NumberSequence.new(0.3, 0), EmissionDirection = Enum.NormalId.Right })
	end
end

--------------------------------------------------------------------------

local BUILDERS = { Forest = forest, Mountain = mountain, Desert = desert, Volcano = volcano }

function ZoneScenery.Build(zoneId: string, def: any, folder: Folder, arrivalPosition: Vector3)
	local env: Env = {
		Folder = folder,
		Center = def.Center,
		Half = def.Size / 2,
		Arrival = arrivalPosition,
		Rng = Random.new(def.Order * 7919),
	}
	local builder = BUILDERS[zoneId]
	if builder then
		builder(env)
	else
		ground(env, def.GroundMaterial or Enum.Material.Grass, Enum.Material.Rock)
	end
end

return ZoneScenery
