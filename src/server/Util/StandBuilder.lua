--[[
	StandBuilder.lua
	================
	Construit un stand de marché cartoon (phase 10) : comptoir en planches, poteaux,
	auvent rayé à festons, marchand (chapeau de paille), panneau, et un décor selon
	le thème :
	  "Seeds"   : caisses de légumes, sachets de graines, pots de jeunes pousses ;
	  "Sell"    : balance dorée, sacs de pièces et piles de pièces ;
	  "Animals" : bottes de foin, petite barrière d'enclos, seau, poussin.
	Le comptoir ("Counter") porte le ProximityPrompt et le panneau d'infos.
	Modèle à toi : ServerStorage.CustomModels.Stands.<Name> (SeedShop, SellStand, AnimalShop).
]]

local Workspace = game:GetService("Workspace")

local ArtKit = require(script.Parent.ArtKit)

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
	Theme: string?, -- "Seeds" | "Sell" | "Animals"
}

local WOOD = Color3.fromRGB(165, 115, 70)
local DARK_WOOD = Color3.fromRGB(105, 70, 45)
local WHITE = Color3.new(1, 1, 1)

local THEMES = {}

function THEMES.Seeds(model: Model, base: CFrame, _color: Color3)
	-- Caisses de légumes devant le comptoir
	local veggies = {
		{ Name = "Tomato", Color = Color3.fromRGB(230, 50, 50), Size = 0.8 },
		{ Name = "Pumpkin", Color = Color3.fromRGB(255, 140, 30), Size = 1.1 },
		{ Name = "Cabbage", Color = Color3.fromRGB(120, 200, 80), Size = 1 },
	}
	for i, veg in veggies do
		local crate = base * CFrame.new(-4.5 + (i - 1) * 4.5, 0, -4.6) * CFrame.Angles(math.rad(-12), 0, 0)
		ArtKit.Block(model, "Crate", Vector3.new(3.4, 1.3, 1.8), crate * CFrame.new(0, 0.8, 0), WOOD, Enum.Material.WoodPlanks)
		ArtKit.Block(model, "CrateSlat", Vector3.new(3.5, 0.25, 1.85), crate * CFrame.new(0, 0.5, 0), DARK_WOOD, Enum.Material.Wood)
		for j = 0, 5 do
			ArtKit.Ball(model, veg.Name, veg.Size, crate * CFrame.new(-1.1 + (j % 3) * 1.1, 1.6 + (j // 3) * 0.35, -0.35 + (j // 3) * 0.6), veg.Color)
		end
	end
	-- Carottes en botte
	for i = 0, 3 do
		local carrot = base * CFrame.new(5.6, 1.2, -2.6 + i * 0.4) * CFrame.Angles(0, 0, math.rad(80))
		ArtKit.Cylinder(model, "Carrot", 1.6, 0.35, carrot, Color3.fromRGB(255, 140, 40))
		ArtKit.Block(model, "CarrotTop", Vector3.new(0.15, 0.7, 0.15), carrot * CFrame.new(0, 1.1, 0), Color3.fromRGB(80, 180, 60))
	end
	-- Sachets de graines colorés sur le comptoir
	local packColors = { Color3.fromRGB(255, 220, 80), Color3.fromRGB(255, 120, 160), Color3.fromRGB(120, 200, 255), Color3.fromRGB(170, 230, 110), Color3.fromRGB(255, 160, 80) }
	for i, c in packColors do
		local pack = base * CFrame.new(-4 + (i - 1) * 2, 3.9, -2.2) * CFrame.Angles(math.rad(-15), 0, 0)
		ArtKit.Block(model, "SeedPacket", Vector3.new(1.3, 1.6, 0.15), pack, c)
		ArtKit.Ball(model, "SeedPacketPicture", 0.55, pack * CFrame.new(0, 0.1, -0.08), ArtKit.Darker(c, 0.35))
	end
	-- Pots de jeunes pousses
	for _, sx in { -1, 1 } do
		local pot = base * CFrame.new(sx * 7.2, 0, -1)
		ArtKit.Cylinder(model, "Pot", 1.2, 1.3, pot * CFrame.new(0, 0.6, 0), Color3.fromRGB(200, 110, 70), Enum.Material.Slate)
		for k = 0, 2 do
			ArtKit.Ellipsoid(model, "Sprout", Vector3.new(0.6, 0.15, 0.3), pot * CFrame.new(0, 1.4 + k * 0.15, 0) * CFrame.Angles(0, k * 2, math.rad(20)), Color3.fromRGB(110, 210, 80))
		end
	end
end

function THEMES.Sell(model: Model, base: CFrame, _color: Color3)
	local gold = Color3.fromRGB(255, 200, 50)
	-- Balance dorée sur le comptoir
	local scale = base * CFrame.new(0, 3.5, -2.2)
	ArtKit.Cylinder(model, "ScaleBase", 0.3, 1.6, scale * CFrame.new(0, 0.15, 0), gold, Enum.Material.Metal)
	ArtKit.Cylinder(model, "ScalePole", 2.2, 0.25, scale * CFrame.new(0, 1.3, 0), gold, Enum.Material.Metal)
	ArtKit.Block(model, "ScaleBeam", Vector3.new(3.4, 0.2, 0.2), scale * CFrame.new(0, 2.4, 0), gold, Enum.Material.Metal)
	for _, sx in { -1, 1 } do
		ArtKit.Block(model, "ScaleString", Vector3.new(0.06, 1, 0.06), scale * CFrame.new(sx * 1.6, 1.9, 0), DARK_WOOD)
		ArtKit.Cylinder(model, "ScalePan", 0.15, 1.3, scale * CFrame.new(sx * 1.6, 1.35, 0), gold, Enum.Material.Metal)
	end
	ArtKit.Ball(model, "ScaleTop", 0.4, scale * CFrame.new(0, 2.6, 0), gold, Enum.Material.Metal)
	-- Sacs de pièces devant le comptoir
	for _, info in { { -4.5, 1.6 }, { -2.6, 1.2 }, { 4.2, 1.8 } } do
		local bag = base * CFrame.new(info[1], 0, -4.4)
		ArtKit.Ellipsoid(model, "CoinBag", Vector3.new(info[2], info[2] * 1.1, info[2]), bag * CFrame.new(0, info[2] * 0.5, 0), Color3.fromRGB(170, 120, 70), Enum.Material.Fabric)
		ArtKit.Cylinder(model, "CoinBagTie", 0.3, info[2] * 0.45, bag * CFrame.new(0, info[2] * 1.05, 0), Color3.fromRGB(120, 80, 45), Enum.Material.Fabric)
		ArtKit.Disc(model, "CoinSymbol", 0.1, info[2] * 0.5, bag * CFrame.new(0, info[2] * 0.5, -info[2] * 0.5) * CFrame.Angles(0, math.rad(90), 0), gold, Enum.Material.Metal)
	end
	-- Piles de pièces
	for k, x in { -6.4, 6.4 } do
		for j = 0, 3 + k do
			ArtKit.Cylinder(model, "Coin", 0.25, 1, base * CFrame.new(x, 3.62 + j * 0.26, -2), gold, Enum.Material.Metal)
		end
	end
end

function THEMES.Animals(model: Model, base: CFrame, _color: Color3)
	local hay = Color3.fromRGB(235, 200, 90)
	-- Bottes de foin
	for _, info in { { -5, 0, 0 }, { -3, 0, 0.3 }, { -4, 1.4, 0.1 } } do
		local bale = base * CFrame.new(info[1], info[2], -4.6 + info[3])
		ArtKit.Block(model, "HayBale", Vector3.new(2, 1.4, 1.4), bale * CFrame.new(0, 0.7, 0), hay, Enum.Material.Grass)
		for _, sx in { -0.5, 0.5 } do
			ArtKit.Block(model, "HayStrap", Vector3.new(0.15, 1.45, 1.45), bale * CFrame.new(sx, 0.7, 0), Color3.fromRGB(150, 100, 60))
		end
	end
	-- Petite barrière d'enclos
	local fence = base * CFrame.new(4.5, 0, -4.8)
	for i = 0, 3 do
		ArtKit.Block(model, "FencePost", Vector3.new(0.4, 2, 0.4), fence * CFrame.new(-2.25 + i * 1.5, 1, 0), WOOD, Enum.Material.Wood)
	end
	for _, h in { 0.7, 1.5 } do
		ArtKit.Block(model, "FenceRail", Vector3.new(5, 0.3, 0.2), fence * CFrame.new(0, h, 0), WHITE, Enum.Material.WoodPlanks)
	end
	-- Seau et poussin
	local bucket = base * CFrame.new(1.5, 0, -4.5)
	ArtKit.Cylinder(model, "Bucket", 1, 1.1, bucket * CFrame.new(0, 0.5, 0), Color3.fromRGB(150, 155, 165), Enum.Material.Metal)
	ArtKit.Cylinder(model, "BucketMilk", 0.1, 0.95, bucket * CFrame.new(0, 0.95, 0), WHITE)
	local chick = base * CFrame.new(3.4, 0, -6)
	ArtKit.Ball(model, "Chick", 0.8, chick * CFrame.new(0, 0.4, 0), Color3.fromRGB(255, 230, 80))
	ArtKit.Ball(model, "ChickHead", 0.55, chick * CFrame.new(0, 0.95, -0.2), Color3.fromRGB(255, 230, 80))
	ArtKit.Wedge(model, "ChickBeak", Vector3.new(0.2, 0.15, 0.25), chick * CFrame.new(0, 0.92, -0.55), Color3.fromRGB(255, 150, 40))
	-- Fer à cheval au-dessus du comptoir
	ArtKit.Disc(model, "Horseshoe", 0.2, 1.4, base * CFrame.new(0, 7.6, -2.4) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(170, 170, 180), Enum.Material.Metal)
end

-- Marchand cartoon (salopette, chapeau de paille)
local function merchant(model: Model, base: CFrame, shirt: Color3)
	local npc = base * CFrame.new(0, 0, 1)
	ArtKit.Cylinder(model, "NPCLegs", 1.6, 1.4, npc * CFrame.new(0, 0.8, 0), Color3.fromRGB(60, 90, 160))
	ArtKit.Ellipsoid(model, "NPCBody", Vector3.new(2.2, 2.4, 1.6), npc * CFrame.new(0, 2.7, 0), shirt)
	for _, sx in { -1, 1 } do
		ArtKit.Ellipsoid(model, "NPCArm", Vector3.new(0.6, 1.6, 0.6), npc * CFrame.new(sx * 1.2, 2.6, -0.3) * CFrame.Angles(math.rad(-30), 0, sx * math.rad(-15)), shirt)
		ArtKit.Ball(model, "NPCHand", 0.55, npc * CFrame.new(sx * 1.35, 1.9, -0.8), Color3.fromRGB(255, 205, 160))
	end
	ArtKit.Ball(model, "NPCHead", 1.7, npc * CFrame.new(0, 4.6, 0), Color3.fromRGB(255, 205, 160))
	for _, sx in { -1, 1 } do
		ArtKit.Ball(model, "NPCEye", 0.25, npc * CFrame.new(sx * 0.32, 4.75, -0.75), Color3.fromRGB(30, 25, 30))
		ArtKit.Ball(model, "NPCCheek", 0.3, npc * CFrame.new(sx * 0.55, 4.4, -0.62), Color3.fromRGB(255, 160, 150))
	end
	ArtKit.Ellipsoid(model, "NPCMoustache", Vector3.new(0.9, 0.2, 0.25), npc * CFrame.new(0, 4.3, -0.8), Color3.fromRGB(120, 80, 50))
	ArtKit.Cylinder(model, "NPCHatBrim", 0.15, 2.8, npc * CFrame.new(0, 5.4, 0), Color3.fromRGB(240, 205, 110), Enum.Material.Fabric)
	ArtKit.Cylinder(model, "NPCHatTop", 0.7, 1.5, npc * CFrame.new(0, 5.8, 0), Color3.fromRGB(240, 205, 110), Enum.Material.Fabric)
	ArtKit.Cylinder(model, "NPCHatBand", 0.2, 1.55, npc * CFrame.new(0, 5.55, 0), Color3.fromRGB(220, 70, 70))
end

-- Renvoie (model, counterPart, prompt)
function StandBuilder.Build(options: StandOptions): (Model, Part, ProximityPrompt)
	local base = CFrame.lookAt(options.Position, options.Position + options.Facing)
	local model = ArtKit.Custom("Stands", options.Name)
	local counter: BasePart

	if model then
		ArtKit.PlaceCustom(model, base, true, 13) -- largeur d'un stand
		counter = ArtKit.Block(model, "Counter", Vector3.new(12, 3.5, 3), base * CFrame.new(0, 1.75, -2), WHITE, nil, { Transparency = 1, CanCollide = true, CanQuery = true })
	else
		model = Instance.new("Model")
		local color = options.Color

		-- Comptoir en planches avec panneau avant coloré
		counter = ArtKit.Block(model, "Counter", Vector3.new(12, 3.5, 3), base * CFrame.new(0, 1.75, -2), WOOD, Enum.Material.WoodPlanks, { CanCollide = true, CanQuery = true })
		ArtKit.Block(model, "CounterTop", Vector3.new(12.6, 0.3, 3.4), base * CFrame.new(0, 3.6, -2), DARK_WOOD, Enum.Material.Wood)
		ArtKit.Block(model, "CounterFront", Vector3.new(10.5, 2.2, 0.2), base * CFrame.new(0, 1.8, -3.55), color, Enum.Material.WoodPlanks)

		-- Poteaux torsadés + auvent rayé à festons
		for _, x in { -5.8, 5.8 } do
			ArtKit.Cylinder(model, "Post", 9, 0.7, base * CFrame.new(x, 4.5, -2.8), DARK_WOOD, Enum.Material.Wood)
			ArtKit.Cylinder(model, "Post", 9, 0.7, base * CFrame.new(x, 4.5, 2), DARK_WOOD, Enum.Material.Wood)
		end
		local stripes = 8
		for i = 0, stripes - 1 do
			local x = -6.5 + (i + 0.5) * 13 / stripes
			local c = if i % 2 == 0 then color else WHITE
			ArtKit.Block(model, "Awning", Vector3.new(13 / stripes + 0.02, 0.25, 6.4), base * CFrame.new(x, 9.4, -0.6) * CFrame.Angles(math.rad(-14), 0, 0), c, Enum.Material.Fabric)
			ArtKit.Ball(model, "AwningScallop", 13 / stripes, base * CFrame.new(x, 8.6, -3.85), c, Enum.Material.Fabric)
		end

		merchant(model, base, ArtKit.Lighter(color, 0.15))
		local theme = options.Theme and THEMES[options.Theme]
		if theme then
			theme(model, base, color)
		end
		-- Panneau en bois au sommet
		local sign = ArtKit.Block(model, "TopSign", Vector3.new(8, 1.8, 0.4), base * CFrame.new(0, 11.2, -1.4), Color3.fromRGB(250, 235, 200), Enum.Material.WoodPlanks)
		ArtKit.Block(model, "TopSignFrame", Vector3.new(8.5, 2.3, 0.3), base * CFrame.new(0, 11.2, -1.2), DARK_WOOD, Enum.Material.Wood)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.CanvasSize = Vector2.new(400, 90)
		gui.Parent = sign
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.FredokaOne
		text.TextScaled = true
		text.TextColor3 = ArtKit.Darker(color, 0.35)
		text.Text = options.Title
		text.Parent = gui
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d ~= counter then
				d.CanQuery = false
			end
		end
	end
	model.Name = options.Name

	-- Zone d'interaction : disque lumineux au sol devant le comptoir (où se placer pour E)
	local spot = base * CFrame.new(0, 0, -6.5)
	ArtKit.Disc(model, "InteractRing", 0.2, 7, spot * CFrame.new(0, 0.12, 0) * CFrame.Angles(0, 0, math.rad(90)), options.Color, Enum.Material.Neon, { Transparency = 0.25 })
	ArtKit.Disc(model, "InteractRingInner", 0.22, 5.6, spot * CFrame.new(0, 0.13, 0) * CFrame.Angles(0, 0, math.rad(90)), ArtKit.Lighter(options.Color, 0.6), Enum.Material.SmoothPlastic)

	-- Panneau d'infos flottant (lisible de loin)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(12, 3)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 11, 0)
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
	return model, counter :: Part, prompt
end

return StandBuilder
