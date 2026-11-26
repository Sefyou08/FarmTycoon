--[[
	ArenaDecor.lua
	==============
	Décor thématique des arènes de donjon (phase 10). Les arènes sont partagées
	(une par joueur en donjon) : le décor est reconstruit à chaque entrée selon le donjon.
	  RootCave   Grotte des Racines : racines sur les murs, lianes, champignons lumineux,
	                                  piliers en bois, torches.
	  FrostMine  Mine de Givre      : sol de glace, cristaux lumineux, étais en bois,
	                                  rails de wagonnet, lanternes, tas de neige.
	  SandTemple Temple Ensablé     : dallage en damier, frise bleu et or, statues de chat,
	                                  braseros, trésor.
	  LavaForge  Forge Volcanique   : rigoles de lave, fourneaux, enclumes, chaînes,
	                                  pics d'obsidienne, braises.
	Les murs et piliers (collision) existent déjà ; on change leur matière / couleur et
	on ajoute des Parts décoratives (sans collision) dans le dossier "Decor" de l'arène.

	  ArenaDecor.Apply(arena, dungeonId)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ArtKit = require(script.Parent.ArtKit)

local ArenaDecor = {}

local rgb = Color3.fromRGB

type Arena = { Origin: Vector3, Floor: BasePart, Walls: { BasePart }, Decor: Folder? }

-- Positions le long des murs (intérieur), espacées de step
local function alongWalls(origin: Vector3, half: number, step: number, inset: number): { CFrame }
	local list = {}
	for t = -half + step / 2, half - step / 2, step do
		table.insert(list, CFrame.lookAt(origin + Vector3.new(t, 0, half - inset), origin + Vector3.new(t, 0, 0)))
		table.insert(list, CFrame.lookAt(origin + Vector3.new(t, 0, -half + inset), origin + Vector3.new(t, 0, 0)))
		table.insert(list, CFrame.lookAt(origin + Vector3.new(half - inset, 0, t), origin + Vector3.new(0, 0, t)))
		table.insert(list, CFrame.lookAt(origin + Vector3.new(-half + inset, 0, t), origin + Vector3.new(0, 0, t)))
	end
	return list
end

local function torch(folder: Folder, cf: CFrame, flame: Color3, withLight: boolean)
	ArtKit.Cylinder(folder, "TorchPole", 4, 0.4, cf * CFrame.new(0, 2, 0), rgb(90, 60, 40), Enum.Material.Wood)
	ArtKit.Cylinder(folder, "TorchCup", 0.6, 0.9, cf * CFrame.new(0, 4.2, 0), rgb(70, 65, 60), Enum.Material.Metal)
	local fire = ArtKit.Ball(folder, "TorchFlame", 0.8, cf * CFrame.new(0, 4.8, 0), flame, Enum.Material.Neon)
	ArtKit.Particles(fire, { Color = ColorSequence.new(flame, rgb(255, 80, 20)), LightEmission = 1, Rate = 10, Lifetime = NumberRange.new(0.3, 0.6), Speed = NumberRange.new(1, 2), Size = NumberSequence.new(0.5, 0), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(15, 15) })
	if withLight then
		ArtKit.Light(fire, flame, 22, 1.8)
	end
end

local THEMES = {}

-- 🌳 Grotte des Racines
function THEMES.RootCave(arena: Arena, folder: Folder, half: number)
	local o = arena.Origin
	arena.Floor.Material = Enum.Material.Ground
	for _, wall in arena.Walls do
		wall.Material = if wall.Name == "Pillar" then Enum.Material.Wood else Enum.Material.Rock
		if wall.Name == "Pillar" then
			wall.Color = rgb(100, 70, 45)
			for i = 0, 3 do
				local a = i / 4 * math.pi * 2
				ArtKit.Ellipsoid(folder, "Root", Vector3.new(1.4, 1.4, 5), CFrame.new(wall.Position.X + math.cos(a) * 3, o.Y + 0.4, wall.Position.Z + math.sin(a) * 3) * CFrame.Angles(0, -a + math.pi / 2, 0), rgb(110, 75, 50), Enum.Material.Wood)
			end
			ArtKit.Ellipsoid(folder, "PillarMoss", Vector3.new(6, 1.5, 6), CFrame.new(wall.Position + Vector3.new(0, 7.2, 0)), rgb(80, 150, 60), Enum.Material.Grass)
		end
	end
	for i, cf in alongWalls(o, half, 11, 1.5) do
		-- Racines qui descendent le long des murs et lianes
		ArtKit.Cylinder(folder, "WallRoot", 14, 1.2, cf * CFrame.new((i % 3 - 1) * 1.5, 9, 0) * CFrame.Angles(0, 0, math.rad((i % 2 - 0.5) * 20)), rgb(95, 65, 40), Enum.Material.Wood)
		if i % 2 == 0 then
			ArtKit.Block(folder, "Vine", Vector3.new(0.3, 8, 0.3), cf * CFrame.new(2, 15, 0.3), rgb(70, 150, 60), Enum.Material.Grass)
			for k = 0, 2 do
				ArtKit.Ellipsoid(folder, "VineLeaf", Vector3.new(0.8, 0.2, 0.5), cf * CFrame.new(2.3, 13 - k * 2.5, 0.2), rgb(90, 180, 70), Enum.Material.Grass)
			end
		end
		-- Champignons lumineux au pied des murs
		if i % 5 == 0 then
			local base = cf * CFrame.new(0, 0, -2)
			for k = 0, 2 do
				local h = 1 + k * 0.6
				ArtKit.Cylinder(folder, "GlowStem", h, 0.4, base * CFrame.new(k * 1.1 - 1, h / 2, 0), rgb(230, 240, 230))
				local cap = ArtKit.Ellipsoid(folder, "GlowCap", Vector3.new(1.4, 0.6, 1.4), base * CFrame.new(k * 1.1 - 1, h, 0), rgb(90, 220, 255), Enum.Material.Neon)
				if k == 1 then
					ArtKit.Light(cap, rgb(90, 220, 255), 14, 1.2)
				end
			end
		end
		if i % 7 == 3 then
			torch(folder, cf * CFrame.new(0, 0, -1.5), rgb(255, 170, 60), true)
		end
	end
end

-- ❄️ Mine de Givre
function THEMES.FrostMine(arena: Arena, folder: Folder, half: number)
	local o = arena.Origin
	arena.Floor.Material = Enum.Material.Ice
	for _, wall in arena.Walls do
		wall.Material = if wall.Name == "Pillar" then Enum.Material.Glacier else Enum.Material.Rock
	end
	-- Étais de mine en bois le long des murs
	for i, cf in alongWalls(o, half, 18, 2) do
		for _, sx in { -3, 3 } do
			ArtKit.Block(folder, "MineSupport", Vector3.new(1, 16, 1), cf * CFrame.new(sx, 8, 0), rgb(120, 85, 55), Enum.Material.Wood)
		end
		ArtKit.Block(folder, "MineBeam", Vector3.new(8, 1, 1.2), cf * CFrame.new(0, 16, 0), rgb(120, 85, 55), Enum.Material.Wood)
		if i % 3 == 0 then
			local lantern = ArtKit.Block(folder, "Lantern", Vector3.new(0.9, 1.2, 0.9), cf * CFrame.new(0, 14.6, -0.4), rgb(255, 230, 160), Enum.Material.Neon)
			ArtKit.Light(lantern, rgb(255, 220, 150), 20, 1.5)
		end
		-- Grappe de cristaux de glace
		if i % 2 == 1 then
			for k = 0, 2 do
				local h = 2 + k
				ArtKit.Wedge(folder, "IceCrystal", Vector3.new(1, h, 1.2), cf * CFrame.new(-6 + k * 0.9, h / 2, -0.8) * CFrame.Angles(0, k, math.rad((k - 1) * 15)), rgb(150, 220, 255), Enum.Material.Glass, { Transparency = 0.2, Reflectance = 0.3 })
			end
		end
	end
	-- Rails de wagonnet traversant l'arène + un wagonnet
	for _, sx in { -1.2, 1.2 } do
		ArtKit.Block(folder, "Rail", Vector3.new(0.3, 0.3, half * 2 - 6), CFrame.new(o + Vector3.new(-half + 12 + sx, 0.15, 0)), rgb(150, 150, 160), Enum.Material.Metal)
	end
	for z = -half + 6, half - 6, 3 do
		ArtKit.Block(folder, "Sleeper", Vector3.new(3.6, 0.2, 0.7), CFrame.new(o + Vector3.new(-half + 12, 0.1, z)), rgb(110, 80, 50), Enum.Material.Wood)
	end
	local cart = CFrame.new(o + Vector3.new(-half + 12, 0, 10))
	ArtKit.Block(folder, "MineCart", Vector3.new(3.2, 2, 4.5), cart * CFrame.new(0, 1.6, 0), rgb(110, 110, 120), Enum.Material.Metal)
	ArtKit.Block(folder, "CartIce", Vector3.new(2.8, 1, 4), cart * CFrame.new(0, 2.6, 0), rgb(170, 230, 255), Enum.Material.Glass)
	for _, sx in { -1.5, 1.5 } do
		for _, sz in { -1.5, 1.5 } do
			ArtKit.Disc(folder, "CartWheel", 0.3, 1.1, cart * CFrame.new(sx, 0.55, sz), rgb(60, 60, 65), Enum.Material.Metal)
		end
	end
	for _ = 1, 8 do
		local p = o + Vector3.new(math.random(-40, 40), 0, math.random(-40, 40))
		ArtKit.Ellipsoid(folder, "SnowPile", Vector3.new(5, 1.2, 4), CFrame.new(p + Vector3.new(0, 0.3, 0)), rgb(245, 250, 255), Enum.Material.Snow)
	end
end

-- 🏛️ Temple Ensablé
function THEMES.SandTemple(arena: Arena, folder: Folder, half: number)
	local o = arena.Origin
	arena.Floor.Material = Enum.Material.Sandstone
	for _, wall in arena.Walls do
		wall.Material = Enum.Material.Sandstone
		if wall.Name == "Pillar" then
			for _, h in { 3, 11 } do
				ArtKit.Cylinder(folder, "PillarBand", 0.8, 5.3, CFrame.new(wall.Position.X, o.Y + h, wall.Position.Z), rgb(255, 200, 60), Enum.Material.Foil)
			end
		end
	end
	-- Dallage en damier
	local tile = 10
	for x = -half + tile / 2, half - tile / 2, tile do
		for z = -half + tile / 2, half - tile / 2, tile do
			if (math.floor(x / tile) + math.floor(z / tile)) % 2 == 0 then
				ArtKit.Block(folder, "Tile", Vector3.new(tile, 0.1, tile), CFrame.new(o + Vector3.new(x, 0.05, z)), rgb(200, 165, 105), Enum.Material.Sandstone, { CastShadow = false })
			end
		end
	end
	-- Frise bleu et or en haut des murs
	for i, cf in alongWalls(o, half, 4, 0.2) do
		ArtKit.Block(folder, "Frieze", Vector3.new(4, 1.6, 0.3), cf * CFrame.new(0, 16, -0.1), if i % 2 == 0 then rgb(50, 90, 200) else rgb(255, 200, 60), Enum.Material.SmoothPlastic)
	end
	-- Statues de chat aux coins et braseros
	for _, c in { Vector3.new(-1, 0, -1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, 1) } do
		local pos = o + c * (half - 8)
		local cf = CFrame.lookAt(pos, o)
		ArtKit.Block(folder, "StatueBase", Vector3.new(4, 2, 4), cf * CFrame.new(0, 1, 0), rgb(190, 150, 90), Enum.Material.Sandstone)
		ArtKit.Ellipsoid(folder, "StatueBody", Vector3.new(2.6, 4, 3), cf * CFrame.new(0, 4, 0), rgb(220, 180, 100), Enum.Material.Sandstone)
		ArtKit.Ball(folder, "StatueHead", 2.2, cf * CFrame.new(0, 6.8, -0.6), rgb(220, 180, 100), Enum.Material.Sandstone)
		for _, sx in { -1, 1 } do
			ArtKit.Triangle(folder, "StatueEar", 0.9, 1.2, 0.3, cf * CFrame.new(sx * 0.6, 8.1, -0.6), rgb(220, 180, 100), Enum.Material.Sandstone)
			ArtKit.Ball(folder, "StatueEye", 0.4, cf * CFrame.new(sx * 0.45, 7, -1.65), rgb(80, 200, 255), Enum.Material.Neon)
		end
		local brazier = cf * CFrame.new(0, 0, -5)
		ArtKit.Cylinder(folder, "BrazierStand", 3, 0.6, brazier * CFrame.new(0, 1.5, 0), rgb(200, 160, 60), Enum.Material.Metal)
		ArtKit.Cylinder(folder, "BrazierBowl", 0.8, 2.2, brazier * CFrame.new(0, 3.2, 0), rgb(220, 180, 70), Enum.Material.Foil)
		local fire = ArtKit.Ball(folder, "BrazierFire", 1.4, brazier * CFrame.new(0, 3.9, 0), rgb(255, 170, 50), Enum.Material.Neon)
		ArtKit.Light(fire, rgb(255, 170, 70), 20, 1.6)
		ArtKit.Particles(fire, { Color = ColorSequence.new(rgb(255, 220, 90), rgb(255, 90, 20)), LightEmission = 1, Rate = 14, Lifetime = NumberRange.new(0.4, 0.8), Speed = NumberRange.new(2, 3), Size = NumberSequence.new(0.7, 0), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(15, 15) })
	end
	-- Trésor au fond
	local treasure = o + Vector3.new(0, 0, -half + 6)
	for i = 0, 14 do
		ArtKit.Disc(folder, "GoldCoin", 0.25, 1, CFrame.new(treasure + Vector3.new(math.random(-30, 30) / 10, 0.2 + (i % 5) * 0.25, math.random(-15, 15) / 10)) * CFrame.Angles(0, 0, math.rad(90)), rgb(255, 210, 60), Enum.Material.Foil)
	end
	ArtKit.Block(folder, "Chest", Vector3.new(4, 2.2, 2.6), CFrame.new(treasure + Vector3.new(4, 1.1, 0)), rgb(150, 95, 50), Enum.Material.WoodPlanks)
	ArtKit.Block(folder, "ChestTrim", Vector3.new(4.2, 0.4, 2.8), CFrame.new(treasure + Vector3.new(4, 1.8, 0)), rgb(255, 200, 60), Enum.Material.Foil)
end

-- 🌋 Forge Volcanique
function THEMES.LavaForge(arena: Arena, folder: Folder, half: number)
	local o = arena.Origin
	arena.Floor.Material = Enum.Material.Basalt
	for _, wall in arena.Walls do
		wall.Material = Enum.Material.Basalt
	end
	-- Rigoles de lave au pied des murs
	for _, side in { { Vector3.new(half * 2 - 4, 0.3, 2.5), Vector3.new(0, 0.15, half - 2.5) }, { Vector3.new(half * 2 - 4, 0.3, 2.5), Vector3.new(0, 0.15, -half + 2.5) }, { Vector3.new(2.5, 0.3, half * 2 - 4), Vector3.new(half - 2.5, 0.15, 0) }, { Vector3.new(2.5, 0.3, half * 2 - 4), Vector3.new(-half + 2.5, 0.15, 0) } } do
		local lava = ArtKit.Block(folder, "LavaChannel", side[1], CFrame.new(o + side[2]), rgb(255, 100, 20), Enum.Material.Neon)
		ArtKit.Light(lava, rgb(255, 110, 30), 26, 1.4)
	end
	for i, cf in alongWalls(o, half, 22, 5) do
		if i % 2 == 0 then
			-- Fourneau en briques avec bouche incandescente
			ArtKit.Block(folder, "Furnace", Vector3.new(6, 8, 4), cf * CFrame.new(0, 4, 1), rgb(90, 40, 30), Enum.Material.Brick)
			local mouth = ArtKit.Block(folder, "FurnaceMouth", Vector3.new(3, 2.5, 0.3), cf * CFrame.new(0, 3, -1.1), rgb(255, 130, 40), Enum.Material.Neon)
			ArtKit.Particles(mouth, { Color = ColorSequence.new(rgb(255, 200, 60), rgb(255, 60, 20)), LightEmission = 1, Rate = 8, Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(2, 4), Size = NumberSequence.new(0.3, 0), Acceleration = Vector3.new(0, 4, 0) })
		else
			-- Enclume et chaînes
			local anvil = cf * CFrame.new(0, 0, -3)
			ArtKit.Block(folder, "AnvilBase", Vector3.new(1.6, 1.6, 1.2), anvil * CFrame.new(0, 0.8, 0), rgb(60, 60, 70), Enum.Material.Metal)
			ArtKit.Block(folder, "AnvilTop", Vector3.new(3.4, 0.8, 1.4), anvil * CFrame.new(0, 2, 0), rgb(70, 70, 80), Enum.Material.Metal)
			ArtKit.Wedge(folder, "AnvilHorn", Vector3.new(1.4, 0.8, 1.2), anvil * CFrame.new(-2.2, 2, 0) * CFrame.Angles(0, math.rad(90), 0), rgb(70, 70, 80), Enum.Material.Metal)
			for k = 0, 6 do
				ArtKit.Block(folder, "Chain", Vector3.new(0.3, 0.8, 0.5), cf * CFrame.new(3, 17 - k * 0.75, 0.3) * CFrame.Angles(0, (k % 2) * math.pi / 2, 0), rgb(80, 80, 90), Enum.Material.Metal)
			end
		end
	end
	for _ = 1, 6 do
		local p = o + Vector3.new(math.random(-42, 42), 0, math.random(-42, 42))
		for k = 0, 2 do
			local h = 2 + k * 1.2
			ArtKit.Wedge(folder, "Obsidian", Vector3.new(1, h, 1.4), CFrame.new(p) * CFrame.Angles(0, k * 2.1, math.rad((k - 1) * 15)) * CFrame.new(0, h / 2, 0), rgb(30, 20, 35), Enum.Material.Glass, { Reflectance = 0.25 })
		end
	end
end

--------------------------------------------------------------------------

function ArenaDecor.Apply(arena: Arena, dungeonId: string)
	if arena.Decor then
		arena.Decor:Destroy()
	end
	local def = Config.Dungeons[dungeonId]
	local folder = Instance.new("Folder")
	folder.Name = "Decor"
	folder.Parent = arena.Floor.Parent
	arena.Decor = folder
	-- Grandes lumières douces au-dessus de l'arène : bonne visibilité quel que soit le thème
	for _, offset in { Vector3.new(-25, 22, -25), Vector3.new(25, 22, -25), Vector3.new(-25, 22, 25), Vector3.new(25, 22, 25), Vector3.new(0, 26, 0) } do
		local lamp = ArtKit.Block(folder, "ArenaLight", Vector3.one, CFrame.new(arena.Origin + offset), Color3.new(1, 1, 1), nil, { Transparency = 1 })
		ArtKit.Light(lamp, Color3.fromRGB(255, 245, 230), 60, 1.3)
	end
	local theme = THEMES[dungeonId]
	if theme and def then
		theme(arena, folder, Config.Combat.ArenaSize / 2)
	end
end

return ArenaDecor
