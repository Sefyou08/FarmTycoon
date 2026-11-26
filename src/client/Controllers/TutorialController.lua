--[[
	TutorialController.lua
	======================
	Affichage du tutoriel (l'état et la validation des quêtes sont sur le serveur) :
	  • bandeau d'objectif en haut de l'écran : "🎯 Quête 3/17 : ...", la récompense,
	    la distance jusqu'à la cible, et un bouton "Passer" ;
	  • guidage vers la cible :
	      - cible dans le monde (stand, portail, champ, mangeoire, porte...) : un faisceau
	        lumineux (Beam) part du joueur vers la cible, et une flèche rebondit au-dessus ;
	      - cible = bouton du HUD (🔨 Construire, 🐾 Mes animaux...) : le bouton clignote
	        et une flèche 👉 le désigne.
	Les cibles sont décrites dans Config.Tutorial.Quests[x].Target.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local RewardUtil = require(ReplicatedStorage.Shared.RewardUtil)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local TutorialController = {}

local player = Players.LocalPlayer
local Quests = Config.Tutorial.Quests

local StateController
local Theme
local notify: (string, string) -> ()
local screen: ScreenGui
local bar: Frame
local titleLabel: TextLabel
local rewardLabel: TextLabel
local pointer: TextLabel -- flèche 👉 à côté d'un bouton du HUD
local targetPart: Part -- ancre invisible de la cible dans le monde
local marker: Model -- flèche qui rebondit au-dessus de la cible
local beam: Beam
local targetAttachment: Attachment
local currentButton: GuiObject? = nil
local buttonStroke: UIStroke? = nil

local function currentQuest(): any
	local tutorial = StateController.Get("Tutorial")
	if not tutorial or tutorial.Skipped then
		return nil, 0
	end
	return Quests[tutorial.Step], tutorial.Step
end

-- Ma parcelle (Workspace.Plots.Plot_x avec OwnerUserId = moi)
local function myPlot(): Instance?
	local plots = Workspace:FindFirstChild("Plots")
	if not plots then
		return nil
	end
	for _, plot in plots:GetChildren() do
		if plot:GetAttribute("OwnerUserId") == player.UserId then
			return plot
		end
	end
	return nil
end

-- Position monde de la cible, ou nil
local function worldTarget(target: any): Vector3?
	if not target then
		return nil
	end
	if target.Kind == "World" then
		return target.Position
	elseif target.Kind == "Plot" then
		local plot = myPlot()
		if not plot then
			return nil
		end
		for _, child in plot:GetChildren() do
			if string.sub(child.Name, 1, #target.Prefix) == target.Prefix then
				local part = if target.Part then child:FindFirstChild(target.Part, true) else nil
				if part and part:IsA("BasePart") then
					return part.Position
				end
				if child:IsA("Model") then
					return child:GetPivot().Position
				end
			end
		end
		-- Objet pas encore construit : on pointe l'entrée de la parcelle
		local origin = plot:GetAttribute("Origin")
		return if typeof(origin) == "CFrame" then origin.Position + origin.LookVector * -10 else nil
	end
	return nil
end

local function findButton(name: string): GuiObject?
	local found = screen:FindFirstChild(name, true)
	return if found and found:IsA("GuiObject") then found else nil
end

local function setButton(button: GuiObject?)
	if currentButton == button then
		return
	end
	if buttonStroke then
		buttonStroke:Destroy()
		buttonStroke = nil
	end
	currentButton = button
	if button then
		local stroke = Instance.new("UIStroke")
		stroke.Name = "TutorialStroke"
		stroke.Thickness = 4
		stroke.Color = Color3.fromRGB(255, 230, 60)
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = button
		buttonStroke = stroke
	end
end

local function buildMarker()
	marker = Instance.new("Model")
	marker.Name = "TutorialMarker"
	local function part(name: string, cf: CFrame, size: Vector3, className: string?): BasePart
		local p = Instance.new(className or "Part") :: BasePart
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Material = Enum.Material.Neon
		p.Color = Color3.fromRGB(255, 225, 60)
		p.Size = size
		p.CFrame = cf
		p.Parent = marker
		return p
	end
	-- Flèche vers le bas : tige + pointe (2 coins)
	local stem = part("Stem", CFrame.new(0, 2.2, 0), Vector3.new(0.8, 2.2, 0.8))
	part("TipL", CFrame.new(-0.6, 0.6, 0) * CFrame.Angles(0, math.rad(90), math.pi), Vector3.new(0.8, 1.2, 1.2), "WedgePart")
	part("TipR", CFrame.new(0.6, 0.6, 0) * CFrame.Angles(0, math.rad(-90), math.pi), Vector3.new(0.8, 1.2, 1.2), "WedgePart")
	marker.PrimaryPart = stem
	marker.WorldPivot = CFrame.new()
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 225, 60)
	light.Range = 12
	light.Parent = stem
end

local function refreshBar()
	local quest, step = currentQuest()
	if not quest then
		bar.Visible = false
		setButton(nil)
		return
	end
	bar.Visible = true
	titleLabel.Text = ("🎯 Quête %d/%d : %s"):format(step, #Quests, quest.Text)
	rewardLabel.Text = "🎁 " .. RewardUtil.Describe(quest.Reward, StateController.Get("Level") or 1)
end

function TutorialController.Init(hudScreen: ScreenGui, stateController, theme, notifyFn)
	screen = hudScreen
	StateController = stateController
	Theme = theme
	notify = notifyFn
	local remote: RemoteFunction = Remotes.Get("TutorialAction")

	-- Bandeau d'objectif
	bar = Instance.new("Frame")
	bar.Name = "TutorialBar"
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0, 110)
	bar.Size = UDim2.new(0.6, 0, 0, 58)
	bar.BackgroundColor3 = Color3.fromRGB(35, 40, 55)
	bar.BackgroundTransparency = 0.1
	bar.Visible = false
	bar.Parent = screen
	Theme.Corner(bar, 12)
	Theme.Stroke(bar, 2, Color3.fromRGB(255, 220, 60))
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = Vector2.new(720, 58)
	constraint.Parent = bar
	titleLabel = Theme.Label({ Size = UDim2.new(1, -100, 0, 30), Position = UDim2.fromOffset(10, 4), TextXAlignment = Enum.TextXAlignment.Left, Text = "", Parent = bar })
	rewardLabel = Theme.Label({ Size = UDim2.new(1, -100, 0, 20), Position = UDim2.fromOffset(10, 34), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Theme.Colors.Coins, Text = "", Parent = bar })
	local skip = Theme.Button({ Size = UDim2.fromOffset(80, 40), Position = UDim2.new(1, -88, 0, 9), BackgroundColor3 = Color3.fromRGB(110, 110, 125), Text = "Passer", Parent = bar })
	skip.Activated:Connect(function()
		local ok, success, message = pcall(function()
			return remote:InvokeServer("Skip")
		end)
		if ok then
			notify(message, if success then "Info" else "Error")
		end
	end)

	pointer = Theme.Label({ Size = UDim2.fromOffset(44, 44), Text = "👉", Visible = false, ZIndex = 10, Parent = screen })

	-- Faisceau et flèche dans le monde (locaux : seul ce joueur les voit)
	targetPart = Instance.new("Part")
	targetPart.Name = "TutorialTarget"
	targetPart.Anchored = true
	targetPart.CanCollide = false
	targetPart.CanQuery = false
	targetPart.CanTouch = false
	targetPart.Transparency = 1
	targetPart.Size = Vector3.one
	targetPart.Parent = Workspace
	targetAttachment = Instance.new("Attachment")
	targetAttachment.Parent = targetPart
	beam = Instance.new("Beam")
	beam.Attachment1 = targetAttachment
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 240, 120), Color3.fromRGB(255, 200, 40))
	beam.Transparency = NumberSequence.new(0.2, 0.6)
	beam.LightEmission = 1
	beam.Width0 = 0.6
	beam.Width1 = 0.6
	beam.FaceCamera = true
	beam.Segments = 20
	beam.CurveSize0 = 6
	beam.Enabled = false
	beam.Parent = targetPart
	buildMarker()

	StateController.Changed:Connect(function(key)
		if key == "*" or key == "Tutorial" or key == "Level" then
			refreshBar()
		end
	end)

	-- Guidage mis à jour à chaque image (position de la cible vérifiée 4 fois / s)
	local lastLookup = 0
	local targetPos: Vector3? = nil
	RunService.RenderStepped:Connect(function()
		local quest = currentQuest()
		local now = os.clock()
		if now - lastLookup > 0.25 then
			lastLookup = now
			targetPos = if quest then worldTarget(quest.Target) else nil
			local buttonName = quest and quest.Target and quest.Target.Kind == "Button" and quest.Target.Name
			setButton(if buttonName then findButton(buttonName) else nil)
		end

		-- Bouton du HUD : clignote + flèche 👉 à sa gauche
		if currentButton and currentButton.Visible and buttonStroke then
			buttonStroke.Transparency = 0.5 + math.sin(now * 6) * 0.5
			pointer.Visible = true
			local pos = currentButton.AbsolutePosition
			pointer.Position = UDim2.fromOffset(pos.X + currentButton.AbsoluteSize.X + 4 + math.sin(now * 6) * 6, pos.Y)
			pointer.Text = "👈"
		else
			pointer.Visible = false
		end

		-- Cible dans le monde : faisceau + flèche qui rebondit + distance
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if targetPos and root and root:IsA("BasePart") then
			if not beam.Attachment0 or beam.Attachment0.Parent ~= root then
				local attachment = root:FindFirstChild("TutorialAttachment") or Instance.new("Attachment")
				attachment.Name = "TutorialAttachment"
				attachment.Parent = root
				beam.Attachment0 = attachment :: Attachment
			end
			targetPart.CFrame = CFrame.new(targetPos + Vector3.new(0, 1, 0))
			beam.Enabled = (root.Position - targetPos).Magnitude > 8
			marker.Parent = Workspace
			marker:PivotTo(CFrame.new(targetPos + Vector3.new(0, 7 + math.abs(math.sin(now * 3)) * 1.5, 0)) * CFrame.Angles(0, now * 2, 0))
			if quest then
				local distance = math.floor((root.Position - targetPos).Magnitude)
				rewardLabel.Text = ("🎁 %s   •   📍 %d m"):format(RewardUtil.Describe(quest.Reward, StateController.Get("Level") or 1), distance)
			end
		else
			beam.Enabled = false
			marker.Parent = nil
		end
	end)
end

-- Relance (depuis ❓ Guide)
function TutorialController.Restart()
	local ok, success, message = pcall(function()
		return (Remotes.Get("TutorialAction") :: RemoteFunction):InvokeServer("Restart")
	end)
	if ok then
		notify(message, if success then "Success" else "Error")
	end
end

return TutorialController
