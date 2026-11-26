--[[
	TycoonPad.lua
	=============
	Bouton au sol « style tycoon » (phase 10) : un socle surélevé avec une bordure colorée,
	une plaque lumineuse sur le dessus, une lumière, quelques étincelles, et un panneau
	au-dessus (icône, titre, prix). Le joueur marche dessus (ou appuie sur E).

	  TycoonPad.Build(parent, groundCFrame, opts) -> pad (Model), top (Part), prompt, title, detail
	    opts : Name, Color, Icon, Title, Detail, ActionText, ObjectText, Hold
	  TycoonPad.SetVisible(pad, visible)  -- cache le bouton (parcelle libre, agrandissement au max...)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ArtKit = require(script.Parent.ArtKit)

local TycoonPad = {}

local Pads = Config.TycoonPads

function TycoonPad.Build(parent: Instance, ground: CFrame, opts: { [string]: any })
	local size, height = Pads.Size, Pads.Height
	local color = opts.Color
	local pad = Instance.new("Model")
	pad.Name = opts.Name
	-- Socle (bordure foncée) + plaque lumineuse en relief
	local base = ArtKit.Block(pad, "PadBase", Vector3.new(size + 0.6, height, size + 0.6), ground * CFrame.new(0, height / 2, 0), ArtKit.Darker(color, 0.45), Enum.Material.SmoothPlastic, { CanCollide = true })
	base:SetAttribute("VisibleTransparency", 0)
	local rim = ArtKit.Block(pad, "PadRim", Vector3.new(size + 0.2, 0.25, size + 0.2), ground * CFrame.new(0, height + 0.05, 0), Color3.fromRGB(255, 255, 255), Enum.Material.Neon)
	rim:SetAttribute("VisibleTransparency", 0)
	local top = ArtKit.Block(pad, "PadTop", Vector3.new(size - 0.6, 0.3, size - 0.6), ground * CFrame.new(0, height + 0.15, 0), color, Enum.Material.Neon, { CanQuery = true, CanTouch = true })
	top:SetAttribute("VisibleTransparency", 0.05)
	top.Transparency = 0.05
	ArtKit.Light(top, color, 12, 1.5)
	ArtKit.Particles(top, {
		Name = "Sparkles",
		Color = ColorSequence.new(color, Color3.new(1, 1, 1)),
		LightEmission = 1,
		Rate = 4,
		Lifetime = NumberRange.new(0.8, 1.4),
		Speed = NumberRange.new(1, 2),
		SpreadAngle = Vector2.new(20, 20),
		EmissionDirection = Enum.NormalId.Top,
		Size = NumberSequence.new(0.3, 0),
	})

	-- Panneau au-dessus : icône + titre + détail (prix, effet, minuteur)
	local gui = Instance.new("BillboardGui")
	gui.Name = "PadGui"
	gui.Size = UDim2.fromScale(7, 3.2)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3.4, 0)
	gui.MaxDistance = 70
	gui.LightInfluence = 0
	gui.Parent = top
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.fromScale(1, 0.55)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextStrokeTransparency = 0.2
	title.Text = opts.Icon .. " " .. opts.Title
	title.Parent = gui
	local detail = Instance.new("TextLabel")
	detail.Name = "Detail"
	detail.Position = UDim2.fromScale(0, 0.55)
	detail.Size = UDim2.fromScale(1, 0.45)
	detail.BackgroundTransparency = 1
	detail.Font = Enum.Font.FredokaOne
	detail.TextScaled = true
	detail.RichText = true
	detail.TextColor3 = ArtKit.Lighter(color, 0.5)
	detail.TextStrokeTransparency = 0.2
	detail.Text = opts.Detail or ""
	detail.Parent = gui

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = opts.ActionText or "Acheter"
	prompt.ObjectText = opts.ObjectText or opts.Title
	prompt.HoldDuration = opts.Hold or 0.3
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OwnerOnly", true)
	prompt.Parent = top

	pad.PrimaryPart = top
	pad.Parent = parent
	return pad, top, prompt, title, detail
end

function TycoonPad.SetVisible(pad: Model, visible: boolean)
	for _, d in pad:GetDescendants() do
		if d:IsA("BasePart") then
			d.Transparency = if visible then (d:GetAttribute("VisibleTransparency") or 0) else 1
			d.CanCollide = visible and d.Name == "PadBase"
		elseif d:IsA("BillboardGui") or d:IsA("ParticleEmitter") or d:IsA("PointLight") then
			(d :: any).Enabled = visible
		elseif d:IsA("ProximityPrompt") then
			d.Enabled = visible
		end
	end
	pad:SetAttribute("Visible", visible)
end

return TycoonPad
