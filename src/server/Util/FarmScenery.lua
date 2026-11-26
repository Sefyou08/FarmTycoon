--[[
	FarmScenery.lua
	===============
	Décor de la ferme (phase 10), construit une fois au démarrage du serveur :
	  • terrain d'herbe (Terrain Roblox, herbe animée) à la place du Baseplate gris ;
	  • montagnes enneigées en arrière-plan (anneau autour de la map) ;
	  • ruisseau nord-sud entre deux colonnes de parcelles, un étang, un pont en bois
	    arrondi sur le chemin principal ;
	  • chemins en terre (allée principale + un chemin vers chaque parcelle) ;
	  • arbres (chênes ronds, sapins, pommiers), buissons, fleurs, rochers ;
	  • clôture en bois autour de la ferme ;
	  • place du spawn pavée avec la statue de la mascotte Biscotte et un panneau d'accueil ;
	  • éclairage chaud (Lighting, Atmosphere, nuages, couleurs), repris ensuite par
	    le client (LightingController) selon l'endroit où se trouve le joueur.

	Tout est décoratif : sans collision (sauf le pont et les troncs) et ancré.
	Valeurs : Config.Art.Farm, Config.Art.Lighting.Farm, Config.Plots.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local ArtKit = require(script.Parent.ArtKit)
local MascotBuilder = require(script.Parent.MascotBuilder)

local FarmScenery = {}

local Art = Config.Art.Farm
local Plots = Config.Plots
local rng = Random.new(Art.Seed)

local folder: Folder

-- Zone occupée par les parcelles (agrandies au maximum) + allée centrale
local maxExp = Plots.Expansions[#Plots.Expansions]
local PLOTS_HALF_X = Plots.SpacingX * (Plots.Columns - 1) / 2 + maxExp.Width / 2 + 12
local PLOTS_HALF_Z = Plots.FrontOffsetZ + maxExp.Depth + 12
local POND = Vector3.new(Art.StreamX, 0, -(PLOTS_HALF_Z + 120))

local function isFree(x: number, z: number, margin: number): boolean
	if math.abs(x) < PLOTS_HALF_X + margin and math.abs(z) < PLOTS_HALF_Z + margin then
		return false
	end
	if math.abs(x - Art.StreamX) < Art.StreamWidth / 2 + margin + 2 then
		return false
	end
	if (Vector3.new(x, 0, z) - POND).Magnitude < 32 + margin then
		return false
	end
	return true
end

-- Point au hasard dans l'anneau de décor (hors parcelles, avant les montagnes)
local function randomSpot(margin: number): (number, number)
	local limit = Config.Art.Farm.MountainRing.Radius - 140
	for _ = 1, 40 do
		local x = rng:NextNumber(-limit, limit)
		local z = rng:NextNumber(-limit, limit)
		if isFree(x, z, margin) and Vector2.new(x, z).Magnitude < limit then
			return x, z
		end
	end
	return limit, limit
end

--------------------------------------------------------------------------
-- Terrain : herbe, ruisseau, étang, montagnes
--------------------------------------------------------------------------

local function buildTerrain()
	local terrain = Workspace.Terrain
	terrain:SetMaterialColor(Enum.Material.Grass, Art.GrassColor)
	terrain:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(95, 165, 65))
	terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(130, 125, 135))
	terrain:SetMaterialColor(Enum.Material.Snow, Color3.fromRGB(245, 250, 255))
	terrain:SetMaterialColor(Enum.Material.Sand, Color3.fromRGB(225, 200, 150))
	terrain.WaterColor = Color3.fromRGB(70, 170, 220)
	terrain.WaterTransparency = 0.6
	terrain.WaterReflectance = 0.6
	terrain.WaterWaveSize = 0.08
	terrain.WaterWaveSpeed = 6
	pcall(function()
		-- Pas de brins d'herbe 3D : ils étaient trop hauts et cachaient les champs, enclos et socles
		terrain.Decoration = false
	end)

	-- Sol d'herbe : dessus à y = 0
	local size = Art.GroundSize
	terrain:FillBlock(CFrame.new(0, -6, 0), Vector3.new(size, 12, size), Enum.Material.Grass)

	-- Sous les parcelles : terre (pas d'herbe) ; le sol de chaque parcelle est une Part au-dessus
	for column = 0, Plots.Columns - 1 do
		local x = (column - (Plots.Columns - 1) / 2) * Plots.SpacingX
		for _, side in { -1, 1 } do
			local z = side * (Plots.FrontOffsetZ + maxExp.Depth / 2)
			terrain:FillBlock(CFrame.new(x, -2, z), Vector3.new(maxExp.Width + 4, 4, maxExp.Depth + 4), Enum.Material.Ground)
		end
	end
	terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(120, 90, 60))

	-- Ruisseau nord-sud (creusé puis rempli d'eau), berges de sable
	local length = Config.Art.Farm.MountainRing.Radius * 2
	local sx, width = Art.StreamX, Art.StreamWidth
	terrain:FillBlock(CFrame.new(sx, -6, 0), Vector3.new(width + 6, 4, length), Enum.Material.Sand)
	terrain:FillBlock(CFrame.new(sx, -2.5, 0), Vector3.new(width, 5, length), Enum.Material.Air)
	terrain:FillBlock(CFrame.new(sx, -3.25, 0), Vector3.new(width, 3.5, length), Enum.Material.Water)
	-- Étang au sud
	terrain:FillCylinder(CFrame.new(POND - Vector3.new(0, 5, 0)), 4, 34, Enum.Material.Sand)
	terrain:FillCylinder(CFrame.new(POND - Vector3.new(0, 2.5, 0)), 5, 30, Enum.Material.Air)
	terrain:FillCylinder(CFrame.new(POND - Vector3.new(0, 3.25, 0)), 3.5, 30, Enum.Material.Water)

	-- Montagnes : grosse boule de roche, jupe d'herbe, sommet enneigé
	local ring = Art.MountainRing
	for i = 1, ring.Count do
		local angle = (i / ring.Count) * math.pi * 2 + rng:NextNumber(-0.12, 0.12)
		local radius = ring.Radius + rng:NextNumber(0, 140)
		local r = rng:NextNumber(110, 175)
		local center = Vector3.new(math.cos(angle) * radius, -r * 0.42, math.sin(angle) * radius)
		terrain:FillBall(center + Vector3.new(0, -r * 0.35, 0), r * 1.05, Enum.Material.Grass)
		terrain:FillBall(center, r, Enum.Material.Rock)
		terrain:FillBall(center + Vector3.new(rng:NextNumber(-0.5, 0.5) * r, -r * 0.2, rng:NextNumber(-0.3, 0.3) * r), r * 0.7, Enum.Material.Rock)
		local peak = center.Y + r
		terrain:FillBall(Vector3.new(center.X, peak - r * 0.3, center.Z), r * 0.42, Enum.Material.Snow)
	end
end

--------------------------------------------------------------------------
-- Chemins, pont, clôtures
--------------------------------------------------------------------------

local function pathStrip(name: string, fromPos: Vector3, toPos: Vector3, width: number)
	local delta = toPos - fromPos
	local length = delta.Magnitude
	if length < 1 then
		return
	end
	local mid = (fromPos + toPos) / 2
	ArtKit.Block(folder, name, Vector3.new(width, 0.2, length), CFrame.lookAt(mid, mid + delta) * CFrame.new(0, 0.1, 0), Art.PathColor, Enum.Material.Ground)
	-- bordure de petits cailloux
	for side = -1, 1, 2 do
		local count = math.floor(length / 7)
		for i = 0, count do
			local t = (i + rng:NextNumber(0, 0.6)) / math.max(count, 1)
			local p = fromPos + delta * math.clamp(t, 0, 1)
			local offset = CFrame.lookAt(p, p + delta) * CFrame.new(side * (width / 2 + 0.4), 0.15, 0)
			ArtKit.Ellipsoid(folder, "Pebble", Vector3.new(rng:NextNumber(0.6, 1.1), 0.4, rng:NextNumber(0.6, 1)), offset, Color3.fromRGB(165, 160, 150), Enum.Material.Slate)
		end
	end
end

local function buildPaths()
	local halfLength = PLOTS_HALF_X + 30
	local streamMin = Art.StreamX - 9
	local streamMax = Art.StreamX + 9
	-- Allée principale (coupée au niveau du pont)
	pathStrip("MainPath", Vector3.new(-halfLength, 0, 0), Vector3.new(streamMin, 0, 0), Art.MainPathWidth)
	pathStrip("MainPath", Vector3.new(streamMax, 0, 0), Vector3.new(halfLength, 0, 0), Art.MainPathWidth)
	-- Un chemin vers l'entrée de chaque parcelle
	for column = 0, Plots.Columns - 1 do
		local x = (column - (Plots.Columns - 1) / 2) * Plots.SpacingX
		for _, side in { -1, 1 } do
			pathStrip("PlotPath", Vector3.new(x, 0, side * (Art.MainPathWidth / 2)), Vector3.new(x, 0, side * (Plots.FrontOffsetZ - 1)), Art.BranchPathWidth)
		end
	end
end

local function buildBridge()
	local model = Instance.new("Model")
	model.Name = "Bridge"
	local x = Art.StreamX
	local wood = Color3.fromRGB(160, 110, 65)
	local dark = ArtKit.Darker(wood, 0.3)
	local span, width, rise = 18, 12, 1.6
	local planks = 9
	for i = 0, planks - 1 do
		local t = (i + 0.5) / planks
		local px = x - span / 2 + t * span
		local h = math.sin(t * math.pi) * rise
		local slope = math.cos(t * math.pi) * rise * math.pi / span
		ArtKit.Block(model, "Plank", Vector3.new(span / planks + 0.15, 0.4, width), CFrame.new(px, h + 0.2, 0) * CFrame.Angles(0, 0, math.atan(slope)), if i % 2 == 0 then wood else ArtKit.Lighter(wood, 0.08), Enum.Material.WoodPlanks, { CanCollide = true, CanQuery = true })
	end
	-- Garde-corps : poteaux arrondis + main courante
	for _, side in { -1, 1 } do
		local z = side * (width / 2 - 0.3)
		for i = 0, 4 do
			local t = i / 4
			local px = x - span / 2 + t * span
			local h = math.sin(t * math.pi) * rise
			ArtKit.Cylinder(model, "Post", 3, 0.6, CFrame.new(px, h + 1.9, z), dark, Enum.Material.Wood, { CanCollide = true })
			ArtKit.Ball(model, "PostCap", 0.75, CFrame.new(px, h + 3.4, z), dark, Enum.Material.Wood)
		end
		for i = 0, 3 do
			local a = x - span / 2 + i / 4 * span
			local b = x - span / 2 + (i + 1) / 4 * span
			local ha = math.sin(i / 4 * math.pi) * rise + 3
			local hb = math.sin((i + 1) / 4 * math.pi) * rise + 3
			local pa, pb = Vector3.new(a, ha, z), Vector3.new(b, hb, z)
			ArtKit.Block(model, "Rail", Vector3.new(0.35, 0.35, (pb - pa).Magnitude), CFrame.lookAt((pa + pb) / 2, pb), wood, Enum.Material.Wood)
		end
	end
	-- Lanternes à chaque bout
	for _, sx in { -1, 1 } do
		local base = CFrame.new(x + sx * (span / 2 + 1.5), 0, width / 2 + 1)
		ArtKit.Cylinder(model, "LanternPole", 6, 0.4, base * CFrame.new(0, 3, 0), Color3.fromRGB(60, 55, 50), Enum.Material.Metal)
		local lamp = ArtKit.Block(model, "Lantern", Vector3.new(1, 1.2, 1), base * CFrame.new(0, 6.4, 0), Color3.fromRGB(255, 220, 140), Enum.Material.Neon)
		ArtKit.Light(lamp, Color3.fromRGB(255, 200, 120), 16, 1.2)
	end
	model.Parent = folder
end

local function fenceRun(fromPos: Vector3, toPos: Vector3)
	local delta = toPos - fromPos
	local length = delta.Magnitude
	if length < 2 then
		return
	end
	local color = Color3.fromRGB(150, 105, 60)
	local dir = CFrame.lookAt(fromPos, toPos)
	local posts = math.max(1, math.floor(length / 10))
	for i = 0, posts do
		local p = fromPos + delta * (i / posts)
		ArtKit.Block(folder, "FencePost", Vector3.new(0.8, 3.4, 0.8), CFrame.new(p) * dir.Rotation * CFrame.new(0, 1.7, 0), ArtKit.Darker(color, 0.15), Enum.Material.Wood, { CanCollide = true })
		ArtKit.Wedge(folder, "FenceTip", Vector3.new(0.8, 0.5, 0.8), CFrame.new(p) * dir.Rotation * CFrame.new(0, 3.65, 0), ArtKit.Darker(color, 0.15), Enum.Material.Wood)
	end
	for _, h in { 1.2, 2.5 } do
		ArtKit.Block(folder, "FenceRail", Vector3.new(0.3, 0.45, length), dir * CFrame.new(0, h, -length / 2), color, Enum.Material.WoodPlanks, { CanCollide = true })
	end
end

local function buildFence()
	local hx, hz = PLOTS_HALF_X + 14, PLOTS_HALF_Z + 10
	local gap0, gap1 = Art.StreamX - 8, Art.StreamX + 8
	for _, z in { -hz, hz } do
		fenceRun(Vector3.new(-hx, 0, z), Vector3.new(gap0, 0, z))
		fenceRun(Vector3.new(gap1, 0, z), Vector3.new(hx, 0, z))
	end
	for _, x in { -hx, hx } do
		fenceRun(Vector3.new(x, 0, -hz), Vector3.new(x, 0, -Art.MainPathWidth))
		fenceRun(Vector3.new(x, 0, Art.MainPathWidth), Vector3.new(x, 0, hz))
	end
end

--------------------------------------------------------------------------
-- Végétation
--------------------------------------------------------------------------

local LEAF_COLORS = { Color3.fromRGB(80, 170, 60), Color3.fromRGB(100, 185, 70), Color3.fromRGB(65, 150, 55) }

local function oakTree(x: number, z: number)
	local model = Instance.new("Model")
	model.Name = "Tree"
	local h = rng:NextNumber(7, 11)
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	ArtKit.Cylinder(model, "Trunk", h, rng:NextNumber(1.6, 2.2), base * CFrame.new(0, h / 2, 0), Color3.fromRGB(120, 80, 50), Enum.Material.Wood, { CanCollide = true })
	local leaf = LEAF_COLORS[rng:NextInteger(1, #LEAF_COLORS)]
	local crown = rng:NextNumber(8, 11)
	ArtKit.Ball(model, "Leaves", crown, base * CFrame.new(0, h + crown * 0.25, 0), leaf, Enum.Material.Grass)
	for i = 1, 3 do
		local a = i * 2.1
		ArtKit.Ball(model, "Leaves", crown * 0.65, base * CFrame.new(math.cos(a) * crown * 0.38, h + crown * 0.05, math.sin(a) * crown * 0.38), ArtKit.Lighter(leaf, 0.08), Enum.Material.Grass)
	end
	if rng:NextNumber() < 0.3 then
		-- Pommier : quelques pommes rouges
		for i = 1, 6 do
			local a = rng:NextNumber(0, math.pi * 2)
			ArtKit.Ball(model, "Apple", 0.8, base * CFrame.new(math.cos(a) * crown * 0.5, h + rng:NextNumber(-0.5, crown * 0.3), math.sin(a) * crown * 0.5), Color3.fromRGB(220, 40, 40))
		end
	end
	model.Parent = folder
end

local function pineTree(x: number, z: number)
	local model = Instance.new("Model")
	model.Name = "Pine"
	local scale = rng:NextNumber(0.9, 1.4)
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	ArtKit.Cylinder(model, "Trunk", 4 * scale, 1.2 * scale, base * CFrame.new(0, 2 * scale, 0), Color3.fromRGB(105, 70, 45), Enum.Material.Wood, { CanCollide = true })
	local green = Color3.fromRGB(50, 120, 70)
	for i, w in { 9, 7, 5 } do
		local y = (2.5 + (i - 1) * 3.2) * scale
		local tier = base * CFrame.new(0, y + 2.2 * scale, 0)
		ArtKit.Triangle(model, "Needles", w * scale, 4.4 * scale, w * 0.6 * scale, tier, ArtKit.Lighter(green, i * 0.04), Enum.Material.Grass)
		ArtKit.Triangle(model, "Needles", w * scale, 4.4 * scale, w * 0.6 * scale, tier * CFrame.Angles(0, math.rad(90), 0), ArtKit.Lighter(green, i * 0.04), Enum.Material.Grass)
	end
	model.Parent = folder
end

local function bush(x: number, z: number)
	local leaf = LEAF_COLORS[rng:NextInteger(1, #LEAF_COLORS)]
	local base = CFrame.new(x, 0, z)
	for i = 1, 3 do
		local d = rng:NextNumber(2.2, 3.4)
		ArtKit.Ball(folder, "Bush", d, base * CFrame.new(rng:NextNumber(-1.2, 1.2), d * 0.3, rng:NextNumber(-1.2, 1.2)), ArtKit.Lighter(leaf, i * 0.05), Enum.Material.Grass)
	end
	if rng:NextNumber() < 0.5 then
		for _ = 1, 4 do
			ArtKit.Ball(folder, "Berry", 0.4, base * CFrame.new(rng:NextNumber(-1.5, 1.5), rng:NextNumber(1, 2), rng:NextNumber(-1.5, 1.5)), Color3.fromRGB(230, 60, 120))
		end
	end
end

local FLOWER_COLORS = {
	Color3.fromRGB(255, 90, 120), Color3.fromRGB(255, 220, 70), Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(170, 110, 255), Color3.fromRGB(255, 150, 60), Color3.fromRGB(90, 170, 255),
}

local function flower(x: number, z: number, color: Color3?)
	local h = rng:NextNumber(0.8, 1.5)
	ArtKit.Block(folder, "Stem", Vector3.new(0.15, h, 0.15), CFrame.new(x, h / 2, z), Color3.fromRGB(70, 150, 60), nil, { CastShadow = false })
	ArtKit.Ball(folder, "Petals", rng:NextNumber(0.6, 0.9), CFrame.new(x, h, z), color or FLOWER_COLORS[rng:NextInteger(1, #FLOWER_COLORS)], nil, { CastShadow = false })
end

local function flowerPatch(cx: number, cz: number, count: number, radius: number)
	local color = FLOWER_COLORS[rng:NextInteger(1, #FLOWER_COLORS)]
	for _ = 1, count do
		local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0, radius)
		flower(cx + math.cos(a) * r, cz + math.sin(a) * r, if rng:NextNumber() < 0.75 then color else nil)
	end
end

local function rock(x: number, z: number)
	local s = rng:NextNumber(2, 5)
	ArtKit.Ellipsoid(folder, "Rock", Vector3.new(s * rng:NextNumber(1, 1.5), s * 0.7, s), CFrame.new(x, s * 0.2, z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), Color3.fromRGB(140, 140, 150), Enum.Material.Slate, { CanCollide = true })
end

local function buildVegetation()
	for _ = 1, Art.Trees do
		local x, z = randomSpot(10)
		if rng:NextNumber() < 0.35 then
			pineTree(x, z)
		else
			oakTree(x, z)
		end
	end
	for _ = 1, Art.Bushes do
		local x, z = randomSpot(4)
		bush(x, z)
	end
	for _ = 1, Art.Rocks do
		local x, z = randomSpot(4)
		rock(x, z)
	end
	-- Fleurs : massifs dans la campagne + le long du ruisseau
	local patches = math.floor(Art.Flowers / 10)
	for _ = 1, patches do
		local x, z = randomSpot(4)
		flowerPatch(x, z, 10, 4)
	end
	-- Roseaux et nénuphars sur l'étang
	for i = 1, 10 do
		local a = i / 10 * math.pi * 2
		ArtKit.Disc(folder, "LilyPad", 0.1, rng:NextNumber(1.5, 2.5), CFrame.new(POND + Vector3.new(math.cos(a) * 18, -1.2, math.sin(a) * 14)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(70, 160, 70))
		local reed = POND + Vector3.new(math.cos(a) * 29, 0, math.sin(a) * 29)
		for j = 1, 3 do
			ArtKit.Block(folder, "Reed", Vector3.new(0.2, 3, 0.2), CFrame.new(reed + Vector3.new(j * 0.5, 1.5, 0)) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-10, 10))), Color3.fromRGB(110, 150, 60))
		end
	end
end

--------------------------------------------------------------------------
-- Place du spawn : pavés, mascotte, panneau d'accueil, jardinières
--------------------------------------------------------------------------

local function buildPlaza()
	ArtKit.Disc(folder, "Plaza", 0.3, 40, CFrame.new(0, 0.15, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(190, 175, 155), Enum.Material.Cobblestone)
	ArtKit.Disc(folder, "PlazaRing", 0.32, 42, CFrame.new(0, 0.14, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(150, 130, 110), Enum.Material.Cobblestone)

	-- Statue de Biscotte sur un socle
	local statuePos = Vector3.new(18, 0, 16)
	local facing = CFrame.lookAt(statuePos, Vector3.new(0, 0, 0))
	ArtKit.Cylinder(folder, "Pedestal", 2, 7, facing * CFrame.new(0, 1, 0), Color3.fromRGB(230, 220, 200), Enum.Material.Marble, { CanCollide = true })
	ArtKit.Cylinder(folder, "PedestalTrim", 0.4, 7.6, facing * CFrame.new(0, 2, 0), Color3.fromRGB(255, 205, 90), Enum.Material.SmoothPlastic)
	local mascot = MascotBuilder.Build(facing * CFrame.new(0, 2.2, 0), 1.6)
	mascot.Parent = folder
	ArtKit.MakeDecor(mascot)

	-- Panneau d'accueil
	local signPos = Vector3.new(-18, 0, 16)
	local signFacing = CFrame.lookAt(signPos, Vector3.new(0, 0, 0))
	for _, sx in { -3.5, 3.5 } do
		ArtKit.Cylinder(folder, "SignPole", 7, 0.6, signFacing * CFrame.new(sx, 3.5, 0), Color3.fromRGB(140, 95, 55), Enum.Material.Wood)
	end
	local board = ArtKit.Block(folder, "WelcomeBoard", Vector3.new(9, 3.6, 0.5), signFacing * CFrame.new(0, 5.6, 0), Color3.fromRGB(250, 235, 200), Enum.Material.WoodPlanks)
	ArtKit.Block(folder, "WelcomeFrame", Vector3.new(9.6, 4.2, 0.4), signFacing * CFrame.new(0, 5.6, 0.12), Color3.fromRGB(200, 80, 70), Enum.Material.Wood)
	ArtKit.Roof(folder, "WelcomeRoof", 10.4, 1.4, 1.2, signFacing * CFrame.new(0, 7.75, 0), Color3.fromRGB(200, 80, 70), Enum.Material.WoodPlanks)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(450, 180)
	gui.LightInfluence = 0.3
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(120, 70, 40)
	label.Text = "🌾 Farm Tycoon 🌾\nBienvenue chez Biscotte !"
	label.Parent = gui
	local logoId = Config.Art.Decals.MascotLogo
	if logoId and logoId > 0 then
		local decal = Instance.new("Decal")
		decal.Texture = "rbxassetid://" .. logoId
		decal.Face = Enum.NormalId.Back
		decal.Parent = board
	end

	-- Jardinières fleuries autour de la place
	for i = 0, 7 do
		local a = (i + 0.5) / 8 * math.pi * 2
		local pos = Vector3.new(math.cos(a) * 22.5, 0, math.sin(a) * 22.5)
		-- On laisse libres l'allée (axe X) et les accès aux stands / portails (axe Z)
		if math.abs(pos.Z) > 6 and math.abs(pos.X) > 6 then
			local box = CFrame.lookAt(pos, Vector3.zero)
			ArtKit.Block(folder, "Planter", Vector3.new(5, 1.2, 1.6), box * CFrame.new(0, 0.6, 0), Color3.fromRGB(150, 100, 60), Enum.Material.WoodPlanks)
			ArtKit.Block(folder, "PlanterSoil", Vector3.new(4.6, 0.2, 1.2), box * CFrame.new(0, 1.2, 0), Color3.fromRGB(90, 60, 40), Enum.Material.Ground)
			for j = -2, 2 do
				local p = box * CFrame.new(j * 0.9, 1.2, 0)
				flower(p.Position.X, p.Position.Z, FLOWER_COLORS[(i + j) % #FLOWER_COLORS + 1])
			end
		end
	end
end

--------------------------------------------------------------------------
-- Éclairage chaud (le client le reprend ensuite lieu par lieu)
--------------------------------------------------------------------------

local function child(parent: Instance, className: string): any
	local existing = parent:FindFirstChildOfClass(className)
	if existing then
		return existing
	end
	local created = Instance.new(className)
	created.Parent = parent
	return created
end

function FarmScenery.ApplyLighting(preset: { [string]: any })
	Lighting.ClockTime = preset.ClockTime
	Lighting.Brightness = preset.Brightness
	Lighting.Ambient = preset.Ambient
	Lighting.OutdoorAmbient = preset.OutdoorAmbient
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.5
	Lighting.GlobalShadows = true
	local atmosphere = child(Lighting, "Atmosphere")
	atmosphere.Density = preset.Density
	atmosphere.Haze = preset.Haze
	atmosphere.Color = preset.AtmosphereColor
	atmosphere.Decay = preset.Decay
	atmosphere.Glare = 0.2
	atmosphere.Offset = 0.15
	local color = child(Lighting, "ColorCorrectionEffect")
	color.TintColor = preset.Tint
	color.Saturation = preset.Saturation
	color.Contrast = preset.Contrast
	local bloom = child(Lighting, "BloomEffect")
	bloom.Intensity = preset.Bloom
	bloom.Size = 24
	bloom.Threshold = 0.95
	local rays = child(Lighting, "SunRaysEffect")
	rays.Intensity = 0.06
	rays.Spread = 0.6
end

local function buildSky()
	local clouds = child(Workspace.Terrain, "Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.6
	clouds.Color = Color3.fromRGB(255, 250, 245)
	FarmScenery.ApplyLighting(Config.Art.Lighting.Farm)
end

--------------------------------------------------------------------------

function FarmScenery.Build()
	-- Le Baseplate gris est remplacé par le terrain d'herbe
	for _, name in { "Baseplate", "FarmGround" } do
		local old = Workspace:FindFirstChild(name)
		if old and old:IsA("BasePart") then
			old:Destroy()
		end
	end
	folder = Instance.new("Folder")
	folder.Name = "Scenery"
	folder.Parent = Workspace

	buildTerrain()
	buildSky()
	buildPaths()
	buildBridge()
	buildFence()
	buildPlaza()
	buildVegetation()
end

return FarmScenery
