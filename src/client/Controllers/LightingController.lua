--[[
	LightingController.lua
	======================
	Ambiance visuelle et sonore selon l'endroit où se trouve le joueur (phase 10) :
	  Ferme, Forêt, Montagne, Désert, Volcan (zone d'expédition), Donjon.
	  • Éclairage : Lighting + Atmosphere + ColorCorrection + Bloom (Config.Art.Lighting),
	    avec une transition douce (Config.Art.TransitionTime).
	  • Particules d'ambiance autour de la caméra : lucioles (Forêt), flocons (Montagne),
	    sable volant (Désert), braises (Volcan), poussière magique (Donjon), pollen (Ferme).
	  • Musique d'ambiance par lieu si un SoundId est donné (Config.Art.Music, 0 = aucune).
	Tout est LOCAL (client) : chaque joueur voit l'ambiance de l'endroit où il est.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local LightingController = {}

local player = Players.LocalPlayer
local Art = Config.Art

-- Particules d'ambiance par lieu
local AMBIENCE = {
	Farm = { Color = Color3.fromRGB(255, 250, 200), Rate = 3, Size = 0.15, Speed = 0.6, Light = 0.5, Lifetime = 6 },
	Forest = { Color = Color3.fromRGB(200, 255, 120), Rate = 14, Size = 0.25, Speed = 0.8, Light = 1, Lifetime = 5 },
	Mountain = { Color = Color3.fromRGB(255, 255, 255), Rate = 60, Size = 0.3, Speed = 3, Light = 0.2, Lifetime = 6, Fall = true },
	Desert = { Color = Color3.fromRGB(230, 190, 120), Rate = 45, Size = 0.35, Speed = 10, Light = 0, Lifetime = 3, Wind = true },
	Volcano = { Color = Color3.fromRGB(255, 120, 40), Rate = 35, Size = 0.25, Speed = 2.5, Light = 1, Lifetime = 4, Rise = true },
	Dungeon = { Color = Color3.fromRGB(190, 120, 255), Rate = 18, Size = 0.25, Speed = 0.8, Light = 1, Lifetime = 5 },
}

local current: string? = nil
local ambiencePart: Part
local emitter: ParticleEmitter
local music: Sound

local function child(parent: Instance, className: string): any
	local existing = parent:FindFirstChildOfClass(className)
	if existing then
		return existing
	end
	local created = Instance.new(className)
	created.Parent = parent
	return created
end

-- Lieu actuel du joueur
local function locate(): string
	if player:GetAttribute("InDungeon") then
		return "Dungeon"
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		local pos = (root :: BasePart).Position
		for zoneId, zone in Config.Zones do
			local half = zone.Size / 2 + 40
			if math.abs(pos.X - zone.Center.X) < half and math.abs(pos.Z - zone.Center.Z) < half then
				return zoneId
			end
		end
	end
	return "Farm"
end

local function apply(place: string)
	local preset = Art.Lighting[place] or Art.Lighting.Farm
	local info = TweenInfo.new(Art.TransitionTime, Enum.EasingStyle.Sine)
	TweenService:Create(Lighting, info, {
		ClockTime = preset.ClockTime,
		Brightness = preset.Brightness,
		Ambient = preset.Ambient,
		OutdoorAmbient = preset.OutdoorAmbient,
	}):Play()
	TweenService:Create(child(Lighting, "Atmosphere"), info, {
		Density = preset.Density,
		Haze = preset.Haze,
		Color = preset.AtmosphereColor,
		Decay = preset.Decay,
	}):Play()
	TweenService:Create(child(Lighting, "ColorCorrectionEffect"), info, {
		TintColor = preset.Tint,
		Saturation = preset.Saturation,
		Contrast = preset.Contrast,
	}):Play()
	TweenService:Create(child(Lighting, "BloomEffect"), info, { Intensity = preset.Bloom }):Play()

	-- Particules d'ambiance
	local amb = AMBIENCE[place] or AMBIENCE.Farm
	emitter.Color = ColorSequence.new(amb.Color)
	emitter.Rate = amb.Rate
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, amb.Size), NumberSequenceKeypoint.new(1, 0) })
	emitter.Speed = NumberRange.new(amb.Speed * 0.5, amb.Speed)
	emitter.LightEmission = amb.Light
	emitter.Lifetime = NumberRange.new(amb.Lifetime * 0.6, amb.Lifetime)
	emitter.Acceleration = if amb.Fall then Vector3.new(0.5, -2, 0) elseif amb.Rise then Vector3.new(0, 2.5, 0) elseif amb.Wind then Vector3.new(6, -0.5, 2) else Vector3.zero
	emitter.EmissionDirection = if amb.Fall then Enum.NormalId.Bottom else Enum.NormalId.Top

	-- Musique
	local soundId = Art.Music[place] or 0
	if soundId > 0 then
		music.SoundId = "rbxassetid://" .. soundId
		music.Volume = Art.MusicVolume
		music:Play()
	else
		music:Stop()
	end
end

function LightingController.Init()
	ambiencePart = Instance.new("Part")
	ambiencePart.Name = "AmbienceEmitter"
	ambiencePart.Anchored = true
	ambiencePart.CanCollide = false
	ambiencePart.CanQuery = false
	ambiencePart.CanTouch = false
	ambiencePart.Transparency = 1
	ambiencePart.Size = Vector3.new(70, 1, 70) -- les particules naissent sur toute la surface
	ambiencePart.Parent = Workspace
	emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Ambience"
	emitter.SpreadAngle = Vector2.new(30, 30)
	emitter.Parent = ambiencePart

	music = Instance.new("Sound")
	music.Name = "AmbientMusic"
	music.Looped = true
	music.Parent = SoundService

	-- Le décor d'ambiance suit la caméra ; le lieu est vérifié 2 fois par seconde
	RunService.RenderStepped:Connect(function()
		local camera = Workspace.CurrentCamera
		if camera then
			local amb = AMBIENCE[current or "Farm"]
			local height = if amb and amb.Fall then 22 elseif amb and amb.Rise then -4 else 6
			ambiencePart.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, height, 0))
		end
	end)
	task.spawn(function()
		while true do
			local place = locate()
			if place ~= current then
				current = place
				apply(place)
			end
			task.wait(0.5)
		end
	end)
end

return LightingController
