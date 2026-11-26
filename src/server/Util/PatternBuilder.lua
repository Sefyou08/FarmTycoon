--[[
	PatternBuilder.lua
	==================
	Motifs et décorations peints sur les surfaces (cosmétiques, phase 10) :
	  Stars (étoiles), Hearts (cœurs), Diamonds (diamants), Pearls (perles),
	  Flowers (fleurs), Flames (flammes), Clouds (nuages), Checker (damier),
	  Stripes (rayures), Glitter (paillettes), Unicorn (licornes), Mascot (Biscotte).

	  PatternBuilder.Apply(part, face, patternId, options?)
	    part      : la Part à décorer (mur, sol, planche de clôture, panneau, selle)
	    face      : Enum.NormalId (Front = -Z, Top = dessus...)
	    options   : { Color, Accent, Spacing (studs), Size (studs), MaxCount, Parent }

	Deux façons de dessiner :
	  1. une IMAGE (Texture répétée en mosaïque) si Config.Art.Decals[patternId] > 0 ;
	  2. sinon des petites Parts plates en relief (aucune image nécessaire).
	Toutes les pièces du motif sont décoratives (sans collision, ni requête, ni ombre).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ArtKit = require(script.Parent.ArtKit)
local MascotBuilder = require(script.Parent.MascotBuilder)

local PatternBuilder = {}

-- Couleurs par défaut de chaque motif (Color = principale, Accent = secondaire)
PatternBuilder.Defaults = {
	Stars = { Color = Color3.fromRGB(255, 215, 70), Accent = Color3.fromRGB(255, 250, 200) },
	Hearts = { Color = Color3.fromRGB(240, 70, 120), Accent = Color3.fromRGB(255, 170, 200) },
	Diamonds = { Color = Color3.fromRGB(140, 230, 255), Accent = Color3.fromRGB(255, 255, 255) },
	Pearls = { Color = Color3.fromRGB(250, 245, 240), Accent = Color3.fromRGB(255, 220, 230) },
	Flowers = { Color = Color3.fromRGB(255, 130, 190), Accent = Color3.fromRGB(255, 225, 80) },
	Flames = { Color = Color3.fromRGB(255, 90, 30), Accent = Color3.fromRGB(255, 220, 60) },
	Clouds = { Color = Color3.fromRGB(255, 255, 255), Accent = Color3.fromRGB(210, 230, 255) },
	Checker = { Color = Color3.fromRGB(40, 40, 50), Accent = Color3.fromRGB(255, 255, 255) },
	Stripes = { Color = Color3.fromRGB(255, 255, 255), Accent = Color3.fromRGB(230, 80, 80) },
	Glitter = { Color = Color3.fromRGB(255, 240, 180), Accent = Color3.fromRGB(255, 255, 255) },
	Unicorn = { Color = Color3.fromRGB(255, 255, 255), Accent = Color3.fromRGB(255, 150, 220) },
	Mascot = { Color = Color3.fromRGB(255, 196, 120), Accent = Color3.fromRGB(70, 160, 90) },
}

-- Noms lisibles (UI)
PatternBuilder.Names = Config.Art.PatternNames

local DECOR = { CastShadow = false }

--------------------------------------------------------------------------
-- Motifs en Parts. cf : centre du motif, -Z = vers l'extérieur de la surface.
--------------------------------------------------------------------------

local T = 0.12 -- épaisseur du relief

local function flatDisc(parent, name, d, cf, color, material)
	return ArtKit.Disc(parent, name, T, d, cf * CFrame.new(0, 0, -T / 2) * CFrame.Angles(0, math.rad(90), 0), color, material, DECOR)
end

local function flatSquare(parent, name, s, cf, color, material, angle)
	return ArtKit.Block(parent, name, Vector3.new(s, s, T), cf * CFrame.Angles(0, 0, angle or 0) * CFrame.new(0, 0, -T / 2), color, material, DECOR)
end

local function flatTriangle(parent, name, w, h, cf, color, material)
	return ArtKit.Triangle(parent, name, w, h, T, cf * CFrame.new(0, 0, -T / 2), color, material, DECOR)
end

local MOTIFS = {}

function MOTIFS.Stars(parent, cf, s, c)
	flatSquare(parent, "Star", s * 0.55, cf, c.Color, Enum.Material.Neon)
	flatSquare(parent, "Star", s * 0.55, cf * CFrame.new(0, 0, -0.01), c.Color, Enum.Material.Neon, math.rad(45))
	flatDisc(parent, "StarCore", s * 0.3, cf * CFrame.new(0, 0, -0.03), c.Accent, Enum.Material.Neon)
end

function MOTIFS.Hearts(parent, cf, s, c)
	flatDisc(parent, "Heart", s * 0.5, cf * CFrame.new(-s * 0.17, s * 0.12, 0), c.Color)
	flatDisc(parent, "Heart", s * 0.5, cf * CFrame.new(s * 0.17, s * 0.12, 0), c.Color)
	flatSquare(parent, "Heart", s * 0.5, cf * CFrame.new(0, -s * 0.08, 0), c.Color, nil, math.rad(45))
	flatDisc(parent, "HeartShine", s * 0.12, cf * CFrame.new(-s * 0.2, s * 0.2, -0.02), c.Accent)
end

function MOTIFS.Diamonds(parent, cf, s, c)
	flatTriangle(parent, "Diamond", s * 0.6, s * 0.35, cf * CFrame.new(0, s * 0.175, 0), c.Color, Enum.Material.Glass)
	flatTriangle(parent, "Diamond", s * 0.6, s * 0.55, cf * CFrame.new(0, -s * 0.275, 0) * CFrame.Angles(0, 0, math.pi), c.Color, Enum.Material.Glass)
	flatDisc(parent, "DiamondShine", s * 0.12, cf * CFrame.new(-s * 0.1, s * 0.15, -0.03), c.Accent, Enum.Material.Neon)
end

function MOTIFS.Pearls(parent, cf, s, c)
	for i = -1, 1 do
		ArtKit.Ball(parent, "Pearl", s * 0.32, cf * CFrame.new(i * s * 0.34, math.abs(i) * s * 0.08, -s * 0.05), if i == 0 then c.Accent else c.Color, nil, { Reflectance = 0.35, CastShadow = false })
	end
end

function MOTIFS.Flowers(parent, cf, s, c)
	for i = 0, 4 do
		local a = i / 5 * math.pi * 2
		flatDisc(parent, "Petal", s * 0.36, cf * CFrame.new(math.cos(a) * s * 0.24, math.sin(a) * s * 0.24, 0), c.Color)
	end
	flatDisc(parent, "FlowerHeart", s * 0.28, cf * CFrame.new(0, 0, -0.02), c.Accent)
end

function MOTIFS.Flames(parent, cf, s, c)
	flatTriangle(parent, "Flame", s * 0.55, s * 0.85, cf * CFrame.new(0, s * 0.05, 0), c.Color, Enum.Material.Neon)
	flatTriangle(parent, "FlameCore", s * 0.3, s * 0.5, cf * CFrame.new(0, -s * 0.08, -0.02), c.Accent, Enum.Material.Neon)
	flatDisc(parent, "FlameBase", s * 0.5, cf * CFrame.new(0, -s * 0.3, 0), c.Color, Enum.Material.Neon)
end

function MOTIFS.Clouds(parent, cf, s, c)
	flatDisc(parent, "Cloud", s * 0.45, cf * CFrame.new(-s * 0.25, 0, 0), c.Color)
	flatDisc(parent, "Cloud", s * 0.6, cf * CFrame.new(0, s * 0.1, 0), c.Color)
	flatDisc(parent, "Cloud", s * 0.45, cf * CFrame.new(s * 0.25, 0, 0), c.Color)
	ArtKit.Block(parent, "CloudBase", Vector3.new(s * 0.75, s * 0.2, T), cf * CFrame.new(0, -s * 0.12, -T / 2), c.Accent, nil, DECOR)
end

function MOTIFS.Unicorn(parent, cf, s, c)
	flatDisc(parent, "UnicornHead", s * 0.5, cf, c.Color)
	ArtKit.Block(parent, "UnicornSnout", Vector3.new(s * 0.4, s * 0.25, T), cf * CFrame.new(s * 0.2, -s * 0.12, -T / 2) * CFrame.Angles(0, 0, math.rad(-20)), c.Color, nil, DECOR)
	flatTriangle(parent, "UnicornHorn", s * 0.12, s * 0.4, cf * CFrame.new(s * 0.05, s * 0.38, -0.01) * CFrame.Angles(0, 0, math.rad(-15)), Color3.fromRGB(255, 210, 80), Enum.Material.Neon)
	for i = 0, 2 do
		flatDisc(parent, "UnicornMane", s * 0.2, cf * CFrame.new(-s * 0.22, s * (0.18 - i * 0.16), -0.02), if i == 1 then Color3.fromRGB(150, 200, 255) else c.Accent)
	end
	ArtKit.Ball(parent, "UnicornEye", s * 0.08, cf * CFrame.new(s * 0.06, s * 0.05, -T), Color3.fromRGB(30, 25, 40), nil, DECOR)
end

function MOTIFS.Mascot(parent, cf, s, _c)
	MascotBuilder.Motif(parent, cf * CFrame.new(0, 0, -0.05), s * 0.75)
end

--------------------------------------------------------------------------
-- Géométrie d'une face
--------------------------------------------------------------------------

-- Renvoie (repère du centre de la face (-Z = extérieur), largeur, hauteur)
local function faceFrame(part: BasePart, face: Enum.NormalId): (CFrame, number, number)
	local n = Vector3.FromNormalId(face)
	local size = part.Size
	local center = part.CFrame * (n * size / 2)
	local normal = part.CFrame:VectorToWorldSpace(n)
	local upLocal, width, height
	if math.abs(n.Y) > 0.5 then
		upLocal, width, height = Vector3.new(0, 0, -1), size.X, size.Z
	elseif math.abs(n.X) > 0.5 then
		upLocal, width, height = Vector3.new(0, 1, 0), size.Z, size.Y
	else
		upLocal, width, height = Vector3.new(0, 1, 0), size.X, size.Y
	end
	local up = part.CFrame:VectorToWorldSpace(upLocal)
	local right = up:Cross(-normal)
	return CFrame.fromMatrix(center, right, up, -normal), width, height
end

--------------------------------------------------------------------------

function PatternBuilder.Apply(part: BasePart, face: Enum.NormalId, patternId: string?, options: { [string]: any }?)
	if not patternId or not PatternBuilder.Defaults[patternId] then
		return
	end
	options = options or {}
	local defaults = PatternBuilder.Defaults[patternId]
	local colors = { Color = options.Color or defaults.Color, Accent = options.Accent or defaults.Accent }
	local parent = options.Parent or part.Parent
	local spacing = options.Spacing or 3
	local motifSize = options.Size or spacing * 0.6

	-- 1. Image en mosaïque si un ID est configuré
	local decalId = Config.Art.Decals[patternId]
	if decalId and decalId > 0 then
		local texture = Instance.new("Texture")
		texture.Name = "Pattern_" .. patternId
		texture.Texture = "rbxassetid://" .. decalId
		texture.Face = face
		texture.StudsPerTileU = spacing
		texture.StudsPerTileV = spacing
		texture.Parent = part
		return
	end

	local frame, width, height = faceFrame(part, face)
	local folder = Instance.new("Model")
	folder.Name = "Pattern_" .. patternId
	folder.Parent = parent

	-- Rayures : bandes verticales sur toute la hauteur
	if patternId == "Stripes" then
		local count = math.max(1, math.floor(width / spacing))
		for i = 0, count - 1 do
			local x = -width / 2 + (i + 0.5) * (width / count)
			ArtKit.Block(folder, "Stripe", Vector3.new(width / count * 0.45, height, T), frame * CFrame.new(x, 0, -T / 2), if i % 2 == 0 then colors.Color else colors.Accent, nil, DECOR)
		end
		return
	end
	-- Paillettes : scintillement + quelques éclats
	if patternId == "Glitter" then
		local emitter = ArtKit.Particles(part, {
			Name = "Glitter",
			Color = ColorSequence.new(colors.Color, colors.Accent),
			LightEmission = 1,
			Rate = math.clamp(width * height * 0.15, 4, 40),
			Lifetime = NumberRange.new(0.4, 0.9),
			Speed = NumberRange.new(0, 0.2),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.25), NumberSequenceKeypoint.new(1, 0) }),
		})
		emitter.Shape = Enum.ParticleEmitterShape.Box
		emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	end

	-- Grille de motifs (rangées décalées), sans dépasser MaxCount
	local columns = math.max(1, math.floor(width / spacing))
	local rows = math.max(1, math.floor(height / spacing))
	local maxCount = options.MaxCount or 60
	local count = 0
	for row = 0, rows - 1 do
		for col = 0, columns - 1 do
			local checker = patternId == "Checker"
			if (not checker) or ((row + col) % 2 == 0) then
				if count >= maxCount then
					return
				end
				count += 1
				local shift = if checker or row % 2 == 0 then 0 else 0.5
				local x = -width / 2 + (col + 0.5 + shift) * (width / columns)
				local y = -height / 2 + (row + 0.5) * (height / rows)
				if x < width / 2 then
					local cf = frame * CFrame.new(x, y, 0)
					if checker then
						ArtKit.Block(folder, "Checker", Vector3.new(width / columns, height / rows, T), cf * CFrame.new(0, 0, -T / 2), colors.Color, nil, DECOR)
					elseif patternId == "Glitter" then
						flatSquare(folder, "Sparkle", motifSize * 0.25, cf, colors.Accent, Enum.Material.Neon, math.rad(45))
					else
						MOTIFS[patternId](folder, cf, motifSize, colors)
					end
				end
			end
		end
	end
end

return PatternBuilder
