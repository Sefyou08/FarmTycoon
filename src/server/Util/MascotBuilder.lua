--[[
	MascotBuilder.lua
	=================
	La mascotte ORIGINALE du jeu : « Biscotte », un chaton fermier tout rond
	(pelage abricot, ventre crème, salopette verte, chapeau de paille à ruban rouge,
	une carotte dans la patte). Couleurs : Config.Art.Mascot.

	  MascotBuilder.Build(groundCFrame, scale)  -> Model (statue / peluche, assise)
	  MascotBuilder.Motif(parent, cframe, size) -> petite tête plate (motif décoratif
	      posé sur une surface : cframe regarde vers l'extérieur de la surface, -Z)

	Remplaçable par un modèle à toi : ServerStorage.CustomModels.Mascot.Biscotte (voir ArtKit).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ArtKit = require(script.Parent.ArtKit)

local MascotBuilder = {}

local M = Config.Art.Mascot
local DARK = Color3.fromRGB(35, 25, 30)
local WHITE = Color3.new(1, 1, 1)
local PINK = Color3.fromRGB(255, 160, 175)

-- Statue assise, hauteur ≈ 4,6 studs x scale. Le modèle regarde vers -Z.
function MascotBuilder.Build(groundCFrame: CFrame, scale: number?): Model
	local custom = ArtKit.Custom("Mascot", "Biscotte")
	if custom then
		ArtKit.PlaceCustom(custom, groundCFrame)
		if scale and scale ~= 1 then
			custom:ScaleTo(scale)
		end
		return custom
	end

	local model = Instance.new("Model")
	model.Name = "Biscotte"
	local g = groundCFrame
	local function at(x, y, z)
		return g * CFrame.new(x, y, z)
	end

	-- Corps assis + ventre
	local body = ArtKit.Ellipsoid(model, "Body", Vector3.new(2.3, 2.1, 2.0), at(0, 1.05, 0), M.Fur)
	model.PrimaryPart = body
	ArtKit.Ellipsoid(model, "Belly", Vector3.new(1.5, 1.5, 0.6), at(0, 1.15, -0.75), M.Belly)

	-- Salopette : bas cylindrique, bavette, bretelles, boutons
	ArtKit.Cylinder(model, "Overalls", 0.95, 2.35, at(0, 0.6, 0), M.Overalls)
	ArtKit.Block(model, "Bib", Vector3.new(1.0, 0.75, 0.18), at(0, 1.35, -0.95), M.Overalls)
	for _, sx in { -1, 1 } do
		ArtKit.Block(model, "Strap", Vector3.new(0.22, 1.2, 0.12), at(sx * 0.42, 1.75, -0.86) * CFrame.Angles(math.rad(-15), 0, 0), M.Overalls)
		ArtKit.Ball(model, "Button", 0.2, at(sx * 0.4, 1.6, -1.05), Color3.fromRGB(255, 215, 70))
	end
	ArtKit.Block(model, "Pocket", Vector3.new(0.45, 0.35, 0.1), at(0, 1.25, -1.05), ArtKit.Darker(M.Overalls, 0.15))

	-- Pattes avant (dont une tient une carotte) et pieds
	for _, sx in { -1, 1 } do
		ArtKit.Ellipsoid(model, "Arm", Vector3.new(0.6, 1.1, 0.6), at(sx * 1.15, 1.25, -0.35) * CFrame.Angles(math.rad(-25), 0, sx * math.rad(-20)), M.Fur)
		ArtKit.Ellipsoid(model, "Foot", Vector3.new(0.75, 0.45, 0.9), at(sx * 0.55, 0.22, -0.95), M.Belly)
		for t = -1, 1 do
			ArtKit.Ball(model, "Toe", 0.14, at(sx * 0.55 + t * 0.18, 0.3, -1.38), PINK)
		end
	end
	local carrot = at(1.25, 1.1, -0.95) * CFrame.Angles(math.rad(-30), 0, math.rad(-15))
	ArtKit.Cylinder(model, "Carrot", 1.0, 0.32, carrot, Color3.fromRGB(255, 140, 40))
	ArtKit.Ball(model, "CarrotTip", 0.26, carrot * CFrame.new(0, -0.5, 0), Color3.fromRGB(255, 140, 40))
	for i = -1, 1 do
		ArtKit.Block(model, "CarrotLeaf", Vector3.new(0.1, 0.45, 0.1), carrot * CFrame.new(i * 0.08, 0.7, 0) * CFrame.Angles(0, 0, i * math.rad(25)), Color3.fromRGB(80, 190, 70))
	end

	-- Queue en crochet (3 boules)
	for i, info in { { 0, 0.7, 1.15, 0.55 }, { 0.25, 1.2, 1.4, 0.5 }, { 0.35, 1.75, 1.35, 0.45 } } do
		ArtKit.Ball(model, "Tail" .. i, info[4], at(info[1], info[2], info[3]), M.Fur)
	end

	-- Tête (grosse, style chibi)
	local headY = 3.0
	ArtKit.Ball(model, "Head", 2.7, at(0, headY, 0), M.Fur)
	ArtKit.Ellipsoid(model, "Muzzle", Vector3.new(1.3, 0.8, 0.5), at(0, headY - 0.45, -1.1), M.Belly)
	-- Oreilles triangulaires + intérieur rose
	for _, sx in { -1, 1 } do
		local ear = at(sx * 0.78, headY + 1.15, -0.1) * CFrame.Angles(0, 0, sx * math.rad(-18))
		ArtKit.Triangle(model, "Ear", 0.95, 1.0, 0.3, ear, M.Fur)
		ArtKit.Triangle(model, "EarInner", 0.55, 0.6, 0.1, ear * CFrame.new(0, -0.12, -0.17), PINK)
	end
	-- Yeux brillants
	for _, sx in { -1, 1 } do
		ArtKit.Ellipsoid(model, "Eye", Vector3.new(0.45, 0.62, 0.2), at(sx * 0.5, headY + 0.1, -1.18), DARK)
		ArtKit.Ball(model, "EyeShine", 0.17, at(sx * 0.5 + 0.08, headY + 0.25, -1.29), WHITE)
		ArtKit.Ellipsoid(model, "Blush", Vector3.new(0.5, 0.25, 0.1), at(sx * 0.85, headY - 0.35, -1.0), PINK)
		for w = -1, 1 do
			ArtKit.Block(model, "Whisker", Vector3.new(0.7, 0.05, 0.05), at(sx * 1.0, headY - 0.45 + w * 0.12, -1.0) * CFrame.Angles(0, 0, sx * w * math.rad(-12)), DARK)
		end
	end
	ArtKit.Ellipsoid(model, "Nose", Vector3.new(0.3, 0.2, 0.18), at(0, headY - 0.25, -1.36), M.Nose)
	ArtKit.Block(model, "Mouth", Vector3.new(0.3, 0.05, 0.05), at(0, headY - 0.55, -1.35), DARK)

	-- Chapeau de paille (bord, calotte, ruban) légèrement penché
	local hat = at(0, headY + 1.05, 0.05) * CFrame.Angles(math.rad(-8), 0, math.rad(6))
	ArtKit.Cylinder(model, "HatBrim", 0.15, 3.3, hat, M.Hat, Enum.Material.Fabric)
	ArtKit.Cylinder(model, "HatCrown", 0.75, 1.7, hat * CFrame.new(0, 0.42, 0), M.Hat, Enum.Material.Fabric)
	ArtKit.Cylinder(model, "HatBand", 0.22, 1.75, hat * CFrame.new(0, 0.2, 0), M.HatBand)
	ArtKit.Ball(model, "HatFlower", 0.35, hat * CFrame.new(0.75, 0.25, -0.35), Color3.fromRGB(255, 240, 120))

	if scale and scale ~= 1 then
		model.WorldPivot = groundCFrame
		model:ScaleTo(scale)
	end
	return model
end

-- Petite tête plate de Biscotte (motif). cframe : centre du motif, -Z = vers l'extérieur
function MascotBuilder.Motif(parent: Instance, cframe: CFrame, size: number)
	local t = size * 0.15
	ArtKit.Disc(parent, "MotifHead", t, size, cframe * CFrame.Angles(0, math.rad(90), 0), M.Fur)
	for _, sx in { -1, 1 } do
		ArtKit.Triangle(parent, "MotifEar", size * 0.4, size * 0.4, t, cframe * CFrame.new(sx * size * 0.3, size * 0.5, 0) * CFrame.Angles(0, 0, sx * math.rad(-15)), M.Fur)
		ArtKit.Ball(parent, "MotifEye", size * 0.16, cframe * CFrame.new(sx * size * 0.18, size * 0.05, -t * 0.6), DARK)
	end
	ArtKit.Ball(parent, "MotifNose", size * 0.12, cframe * CFrame.new(0, -size * 0.12, -t * 0.6), M.Nose)
	ArtKit.Block(parent, "MotifHat", Vector3.new(size * 1.05, size * 0.1, t), cframe * CFrame.new(0, size * 0.48, -t * 0.3), M.Hat)
	ArtKit.Block(parent, "MotifHat", Vector3.new(size * 0.5, size * 0.25, t), cframe * CFrame.new(0, size * 0.62, -t * 0.3), M.Hat)
	ArtKit.Block(parent, "MotifHatBand", Vector3.new(size * 0.52, size * 0.07, t * 1.1), cframe * CFrame.new(0, size * 0.55, -t * 0.3), M.HatBand)
end

return MascotBuilder
