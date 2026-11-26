--[[
	StandBuilder.lua
	================
	Construit un stand en Parts simples (comptoir, toit, panneau, PNJ) avec un
	ProximityPrompt. Utilisé par la boutique de graines et le stand de vente.
	Pour mettre tes propres modèles plus tard, remplace seulement ce fichier.
]]

local Workspace = game:GetService("Workspace")

local StandBuilder = {}

export type StandOptions = {
	Name: string,
	Position: Vector3, -- position au sol du centre du stand
	Facing: Vector3, -- direction vers laquelle le comptoir est tourné
	Color: Color3,
	Title: string, -- texte du panneau
	ActionText: string, -- texte du ProximityPrompt
	ObjectText: string,
	PromptDistance: number,
}

local function makePart(props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	local anyPart: any = part
	for key, value in props do
		anyPart[key] = value
	end
	return part
end

-- Renvoie (model, counterPart, prompt)
function StandBuilder.Build(options: StandOptions): (Model, Part, ProximityPrompt)
	local model = Instance.new("Model")
	model.Name = options.Name

	local base = CFrame.lookAt(options.Position, options.Position + options.Facing)

	-- Comptoir (devant)
	local counter = makePart({
		Name = "Counter",
		Size = Vector3.new(12, 3.5, 3),
		CFrame = base * CFrame.new(0, 1.75, -2),
		Color = options.Color,
		Material = Enum.Material.WoodPlanks,
		Parent = model,
	})

	-- Poteaux + toit
	for _, x in { -5.5, 5.5 } do
		makePart({
			Name = "Post",
			Size = Vector3.new(0.6, 9, 0.6),
			CFrame = base * CFrame.new(x, 4.5, -2),
			Color = Color3.fromRGB(120, 85, 50),
			Material = Enum.Material.Wood,
			Parent = model,
		})
	end
	makePart({
		Name = "Roof",
		Size = Vector3.new(14, 0.6, 8),
		CFrame = base * CFrame.new(0, 9.3, 0) * CFrame.Angles(math.rad(-8), 0, 0),
		Color = options.Color:Lerp(Color3.new(1, 1, 1), 0.35),
		Material = Enum.Material.Fabric,
		Parent = model,
	})

	-- PNJ très simple derrière le comptoir (corps + tête)
	makePart({
		Name = "NPCBody",
		Size = Vector3.new(2, 3, 1),
		CFrame = base * CFrame.new(0, 3, 1),
		Color = Color3.fromRGB(60, 110, 200),
		Parent = model,
	})
	makePart({
		Name = "NPCHead",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.6, 1.6, 1.6),
		CFrame = base * CFrame.new(0, 5.3, 1),
		Color = Color3.fromRGB(255, 205, 160),
		Parent = model,
	})

	-- Panneau au-dessus
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(12, 3)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 7.5, 0)
	billboard.MaxDistance = 300
	billboard.LightInfluence = 0
	billboard.Parent = counter

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.2
	label.Text = options.Title
	label.Parent = billboard

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = options.ActionText
	prompt.ObjectText = options.ObjectText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = options.PromptDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter

	model.PrimaryPart = counter
	model.Parent = Workspace
	return model, counter, prompt
end

return StandBuilder
