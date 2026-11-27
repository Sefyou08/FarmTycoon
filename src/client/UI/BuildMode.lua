--[[
	BuildMode.lua
	=============
	Mode construction (bouton "🔨 Construire" du HUD).

	  • Menu à droite : acheter un champ, un enclos ou un bâtiment, et liste des
	    éléments RANGÉS à replacer.
	  • Après un choix : un APERÇU transparent suit la souris (PC). Sur mobile / tablette,
	    il se place au CENTRE de l'écran sous un viseur (on bouge la caméra ou on glisse le
	    doigt pour viser), ou là où on touche le sol ; des flèches le décalent d'une case.
	    Une cible lumineuse au sol montre le centre. Grille de Config.Build.Grid studs.
	    Vert = valide, rouge = invalide (la raison est affichée).
	    R ou ↻ pour tourner, clic gauche ou ✔ Poser pour valider, ✖ pour annuler.
	  • Sans rien en main : survoler un élément de SA parcelle le surligne ;
	    cliquer dessus le prend pour le DÉPLACER, avec un bouton 📦 Ranger.
	  • La couleur de l'aperçu est calculée localement (PlacementUtil), mais c'est
	    le serveur qui valide (RemoteFunction BuildAction).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local PlacementUtil = require(ReplicatedStorage.Shared.PlacementUtil)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(script.Parent.Theme)

local BuildMode = {}

local player = Players.LocalPlayer
local StateController
local notify: (string, string) -> ()
local buildRemote: RemoteFunction

local VALID_COLOR = Color3.fromRGB(80, 230, 110)
local INVALID_COLOR = Color3.fromRGB(240, 70, 70)

local active = false
local busy = false
-- Élément en main : { Action = "Buy" | "Place", Type, Kind?, Id?, X, Z, Rot, Placed?, Valid, Reason }
local holding: { [string]: any }? = nil

local ghost: Part
local frontMarker: Part
local groundTarget: Part -- cible lumineuse au sol, sous l'aperçu
local reticle: Frame -- viseur au centre de l'écran (mobile / tablette)
local arrowPad: Frame -- flèches pour décaler d'une case (mobile / tablette)
local aimButton: TextButton
local followCenter = true -- mobile : l'aperçu suit le centre de l'écran (viseur)

-- Mobile / tablette : écran tactile sans souris
local function isTouchMode(): boolean
	return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
end
local hoverBox: SelectionBox
local panel: Frame
local list: ScrollingFrame
local actionBar: Frame
local hintLabel: TextLabel
local storeButton: TextButton
local toggleButton: TextButton

--------------------------------------------------------------------------
-- Données locales (copie lecture seule envoyée par le serveur)
--------------------------------------------------------------------------

local function getMyPlot(): Model?
	local folder = Workspace:FindFirstChild("Plots")
	if not folder then
		return nil
	end
	for _, plot in folder:GetChildren() do
		if plot:IsA("Model") and plot:GetAttribute("OwnerUserId") == player.UserId then
			return plot
		end
	end
	return nil
end

local function getOrigin(): CFrame?
	local plot = getMyPlot()
	local origin = plot and plot:GetAttribute("Origin")
	return if typeof(origin) == "CFrame" then origin else nil
end

local function getLevel(): number
	return StateController.Get("PlotLevel") or 1
end

local function clientData(): { [string]: any }
	return {
		Fields = StateController.Get("Fields") or {},
		Pens = StateController.Get("Pens") or {},
		Buildings = StateController.Get("Buildings") or {},
		Pedestals = StateController.Get("Pedestals") or {},
	}
end

local function recordsOf(data: { [string]: any }, placeType: string): { [string]: any }
	if placeType == "Field" then
		return data.Fields
	elseif placeType == "Pen" then
		return data.Pens
	elseif placeType == "Pedestal" then
		return data.Pedestals
	end
	return data.Buildings
end

local function count(tbl: { [any]: any }): number
	local n = 0
	for _ in tbl do
		n += 1
	end
	return n
end

--------------------------------------------------------------------------
-- Aperçu
--------------------------------------------------------------------------

local function candidate(): { [string]: any }
	local h = holding :: { [string]: any }
	return { Type = h.Type, Id = h.Id, Kind = h.Kind, X = h.X, Z = h.Z, Rot = h.Rot }
end

local function updateGhost()
	local origin = getOrigin()
	if not holding or not origin or holding.X == nil then
		ghost.Parent = nil
		frontMarker.Parent = nil
		if groundTarget then
			groundTarget.Parent = nil
		end
		return
	end
	local w, d = PlacementUtil.Footprint(holding.Type, holding.Kind)
	local cf = origin * PlacementUtil.LocalCFrame(holding.X, holding.Z, holding.Rot) * CFrame.new(0, 0.75, 0)
	ghost.Size = Vector3.new(w, 1.5, d)
	ghost.CFrame = cf
	-- Barre sur le côté "avant" (porte, mangeoire...) pour voir l'orientation
	frontMarker.Size = Vector3.new(w * 0.6, 0.4, 0.8)
	frontMarker.CFrame = cf * CFrame.new(0, 0.95, -d / 2 + 0.6)

	local ok, reason = PlacementUtil.Check(getLevel(), PlacementUtil.Collect(clientData()), candidate())
	holding.Valid, holding.Reason = ok, reason
	ghost.Color = if ok then VALID_COLOR else INVALID_COLOR
	frontMarker.Color = ghost.Color
	hintLabel.Text = if ok then "✔ Emplacement valide" else "✖ " .. (reason or "Emplacement invalide")
	hintLabel.TextColor3 = ghost.Color

	ghost.Parent = Workspace
	frontMarker.Parent = Workspace
	-- Cible au sol : anneau lumineux sous le centre de l'aperçu
	groundTarget.Size = Vector3.new(0.2, math.min(w, d) * 0.6, math.min(w, d) * 0.6)
	groundTarget.CFrame = cf * CFrame.new(0, -0.65, 0) * CFrame.Angles(0, 0, math.rad(90))
	groundTarget.Color = ghost.Color
	groundTarget.Parent = Workspace
end

-- Rayon depuis un point de l'écran (souris : coordonnées viewport ; tactile : coordonnées écran)
local function raycast(position: Vector2, isTouch: boolean): RaycastResult?
	local camera = Workspace.CurrentCamera
	local ray = if isTouch then camera:ScreenPointToRay(position.X, position.Y) else camera:ViewportPointToRay(position.X, position.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { ghost, frontMarker }
	if player.Character then
		table.insert(exclude, player.Character)
	end
	params.FilterDescendantsInstances = exclude
	return Workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
end

local function setTargetFromScreen(position: Vector2, isTouch: boolean)
	if not holding then
		return
	end
	local origin = getOrigin()
	local result = raycast(position, isTouch)
	if not origin or not result then
		return
	end
	local localPosition = origin:PointToObjectSpace(result.Position)
	holding.X = PlacementUtil.Snap(localPosition.X)
	holding.Z = PlacementUtil.Snap(localPosition.Z)
	updateGhost()
end

-- Élément de MA parcelle sous un point de l'écran : (type, id, modèle)
local function placeableAt(position: Vector2, isTouch: boolean): (string?, string?, Instance?)
	local result = raycast(position, isTouch)
	local myPlot = getMyPlot()
	local current = result and result.Instance
	while current and current ~= Workspace do
		local placeType = current:GetAttribute("PlaceType")
		if placeType then
			if myPlot and current:IsDescendantOf(myPlot) then
				return placeType, current:GetAttribute("PlaceId"), current
			end
			return nil, nil, nil
		end
		current = current.Parent
	end
	return nil, nil, nil
end

--------------------------------------------------------------------------
-- Prendre / poser
--------------------------------------------------------------------------

local function stopHolding()
	holding = nil
	actionBar.Visible = false
	updateGhost()
end

local function startHolding(info: { [string]: any })
	followCenter = true
	holding = info
	holding.Rot = holding.Rot or 0
	actionBar.Visible = true
	storeButton.Visible = info.Action == "Place" and info.Placed == true
	-- Position de départ : celle de l'élément, sinon devant le joueur
	if holding.X == nil then
		local origin = getOrigin()
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if origin and root then
			local localPosition = origin:PointToObjectSpace((root :: BasePart).Position + (root :: BasePart).CFrame.LookVector * 20)
			holding.X = PlacementUtil.Snap(localPosition.X)
			holding.Z = PlacementUtil.Snap(localPosition.Z)
		else
			holding.X, holding.Z = 0, 30
		end
	end
	updateGhost()
end

local function rotate()
	if holding then
		holding.Rot = (holding.Rot + 1) % 4
		updateGhost()
	end
end

-- Décale l'aperçu d'une case, dans la direction vue par la caméra (▲ = s'éloigner de la caméra)
local function nudge(forward: number, right: number)
	local origin = getOrigin()
	local camera = Workspace.CurrentCamera
	if not holding or not origin or not camera or holding.X == nil then
		return
	end
	followCenter = false -- les flèches prennent la main sur le viseur
	local function dominant(v: Vector3): Vector3
		local localV = origin:VectorToObjectSpace(v)
		if math.abs(localV.X) > math.abs(localV.Z) then
			return Vector3.new(math.sign(localV.X), 0, 0)
		end
		return Vector3.new(0, 0, math.sign(localV.Z))
	end
	local f = dominant(camera.CFrame.LookVector)
	local r = dominant(camera.CFrame.RightVector)
	local step = Config.Build.NudgeStep
	holding.X += (f.X * forward + r.X * right) * step
	holding.Z += (f.Z * forward + r.Z * right) * step
	updateGhost()
end

local function invoke(action: string, payload: { [string]: any }): boolean
	if busy then
		return false
	end
	busy = true
	local ok, success, message = pcall(function()
		return buildRemote:InvokeServer(action, payload)
	end)
	busy = false
	if ok then
		notify(message or "", if success then "Success" else "Error")
		return success == true
	end
	notify("Erreur réseau.", "Error")
	return false
end

local function confirm()
	if not holding then
		return
	end
	if not holding.Valid then
		notify("✖ " .. (holding.Reason or "Emplacement invalide"), "Error")
		return
	end
	local action = holding.Action
	if invoke(action, candidate()) then
		stopHolding()
	end
end

local function storeHeld()
	if holding and holding.Action == "Place" and holding.Placed then
		if invoke("Store", { Type = holding.Type, Id = holding.Id }) then
			stopHolding()
		end
	end
end

-- Prend un élément existant (posé ou rangé) pour le déplacer / le replacer
local function pickExisting(placeType: string, id: string)
	local record = recordsOf(clientData(), placeType)[id]
	if not record then
		return
	end
	startHolding({
		Action = "Place",
		Type = placeType,
		Id = id,
		Kind = if placeType == "Building" then id else nil,
		X = if record.Placed then record.X else nil,
		Z = if record.Placed then record.Z else nil,
		Rot = record.Rot or 0,
		Placed = record.Placed == true,
	})
end

--------------------------------------------------------------------------
-- Menu
--------------------------------------------------------------------------

local function addRow(order: number, title: string, subtitle: string, buttonText: string?, buttonColor: Color3?, onClick: (() -> ())?)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -8, 0, 58)
	row.LayoutOrder = order
	row.BackgroundColor3 = Color3.fromRGB(50, 56, 75)
	row.Parent = list
	Theme.Corner(row, 8)

	Theme.Label({
		Size = UDim2.new(0.58, -8, 0, 26),
		Position = UDim2.fromOffset(8, 4),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = title,
		Parent = row,
	})
	Theme.Label({
		Size = UDim2.new(0.58, -8, 0, 20),
		Position = UDim2.fromOffset(8, 32),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(200, 200, 210),
		Text = subtitle,
		Parent = row,
	})
	if buttonText and onClick then
		local button = Theme.Button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -6, 0.5, 0),
			Size = UDim2.new(0.42, -8, 0, 40),
			BackgroundColor3 = buttonColor or Theme.Colors.Button,
			Text = buttonText,
			Parent = row,
		})
		button.Activated:Connect(onClick)
	end
end

local function addHeader(order: number, text: string)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, -8, 0, 26)
	frame.LayoutOrder = order
	frame.BackgroundTransparency = 1
	frame.Parent = list
	Theme.Label({ Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Left, Text = text, Parent = frame })
end

local function rebuildMenu()
	if not active then
		return
	end
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local data = clientData()
	local level = getLevel()
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	local gold = Color3.fromRGB(240, 180, 40)

	addHeader(nextOrder(), "🛒 Acheter et placer")

	-- Champ
	local fields = count(data.Fields)
	local fieldPrice = Config.Farm.FieldPrices[fields + 1]
	local maxFields = Config.Farm.MaxFieldsByLevel[level]
	if fieldPrice and fields < maxFields then
		addRow(nextOrder(), "🌱 Champ (6 cases)", ("%d / %d champs"):format(fields, maxFields), "💰" .. Format.Number(fieldPrice), gold, function()
			startHolding({ Action = "Buy", Type = "Field" })
		end)
	else
		addRow(nextOrder(), "🌱 Champ", if fieldPrice then "Agrandis ta parcelle" else "Maximum atteint")
	end

	-- Enclos
	local pens = count(data.Pens)
	local penPrice = Config.Pens.Prices[pens + 1]
	local maxPens = Config.Pens.MaxByLevel[level]
	if penPrice and pens < maxPens then
		addRow(nextOrder(), "🐾 Enclos", ("%d / %d enclos"):format(pens, maxPens), "💰" .. Format.Number(penPrice), gold, function()
			startHolding({ Action = "Buy", Type = "Pen" })
		end)
	else
		addRow(nextOrder(), "🐾 Enclos", if penPrice then "Agrandis ta parcelle" else "Maximum atteint")
	end

	-- Socles d'exposition
	local pedestals = count(data.Pedestals)
	local pedestalPrice = Config.Display.PedestalPrices[pedestals + 1]
	local maxPedestals = Config.Display.MaxPedestalsByLevel[level]
	if pedestalPrice and pedestals < maxPedestals then
		addRow(nextOrder(), "🏛️ Socle d'exposition", ("%d / %d socles"):format(pedestals, maxPedestals), "💰" .. Format.Number(pedestalPrice), gold, function()
			startHolding({ Action = "Buy", Type = "Pedestal" })
		end)
	else
		addRow(nextOrder(), "🏛️ Socle d'exposition", if pedestalPrice then "Agrandis ta parcelle" else "Maximum atteint")
	end

	-- Bâtiments, dans l'ordre de déblocage
	local buildingIds = {}
	for id in Config.Buildings do
		table.insert(buildingIds, id)
	end
	table.sort(buildingIds, function(a, b)
		return Config.Buildings[a].Order < Config.Buildings[b].Order
	end)
	for _, id in buildingIds do
		local def = Config.Buildings[id]
		local label = PlacementUtil.Label("Building", id)
		if data.Buildings[id] then
			addRow(nextOrder(), label, "✅ Déjà construit")
		elseif level < def.RequiredLevel then
			addRow(nextOrder(), label, ("🔒 Parcelle niveau %d"):format(def.RequiredLevel))
		elseif def.Requires and not data.Buildings[def.Requires] then
			addRow(nextOrder(), label, "🔒 Après : " .. Config.Buildings[def.Requires].DisplayName)
		else
			addRow(nextOrder(), label, "Disponible", "💰" .. Format.Number(def.Price), gold, function()
				startHolding({ Action = "Buy", Type = "Building", Kind = id })
			end)
		end
	end

	-- Éléments rangés
	local stored = {}
	for _, placeType in PlacementUtil.Types do
		for id, record in recordsOf(data, placeType) do
			if type(record) == "table" and record.Placed == false then
				table.insert(stored, { Type = placeType, Id = id })
			end
		end
	end
	addHeader(nextOrder(), ("📦 Rangés (%d)"):format(#stored))
	if #stored == 0 then
		addRow(nextOrder(), "Rien de rangé", "Clique sur un élément posé pour le déplacer")
	end
	for _, entry in stored do
		addRow(nextOrder(), PlacementUtil.Label(entry.Type, if entry.Type == "Building" then entry.Id else nil), "Rangé", "📍 Placer", Theme.Colors.Button, function()
			pickExisting(entry.Type, entry.Id)
		end)
	end
end

--------------------------------------------------------------------------
-- Activation
--------------------------------------------------------------------------

local function setActive(value: boolean)
	active = value
	panel.Visible = value
	toggleButton.Text = if value then "🔨 Terminer" else "🔨 Construire"
	if value then
		rebuildMenu()
		notify("Mode construction : choisis un élément, ou clique sur un élément posé pour le déplacer.", "Info")
	else
		stopHolding()
		hoverBox.Adornee = nil
	end
end

function BuildMode.Init(screen: ScreenGui, HUD, stateController, notifyFn: (string, string) -> ())
	StateController = stateController
	notify = notifyFn
	buildRemote = Remotes.Get("BuildAction")

	-- Aperçu (objets locaux, invisibles pour les autres joueurs)
	ghost = Instance.new("Part")
	ghost.Name = "BuildGhost"
	ghost.Anchored = true
	ghost.CanCollide = false
	ghost.CanQuery = false
	ghost.CanTouch = false
	ghost.Transparency = 0.55
	ghost.Material = Enum.Material.Neon
	frontMarker = ghost:Clone()
	frontMarker.Name = "BuildFront"
	frontMarker.Transparency = 0.2

	hoverBox = Instance.new("SelectionBox")
	hoverBox.Color3 = Color3.fromRGB(255, 220, 80)
	hoverBox.LineThickness = 0.15
	hoverBox.Parent = Workspace

	toggleButton = HUD.AddButton("BuildButton", "🔨 Construire", Color3.fromRGB(230, 140, 40), 4, function()
		setActive(not active)
	end)

	-- Menu à droite
	panel = Instance.new("Frame")
	panel.Name = "BuildMenu"
	panel.AnchorPoint = Vector2.new(1, 0.5)
	panel.Position = UDim2.new(1, -12, 0.5, 0)
	panel.Size = UDim2.new(0, 300, 0.62, 0)
	panel.BackgroundColor3 = Theme.Colors.Panel
	panel.Visible = false
	panel.Parent = screen
	Theme.Corner(panel, 14)
	Theme.Stroke(panel, 3)
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = Vector2.new(300, 440)
	constraint.Parent = panel

	Theme.Label({ Size = UDim2.new(1, -16, 0, 30), Position = UDim2.fromOffset(8, 6), Text = "🔨 Construction", Parent = panel })
	list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(8, 42)
	list.Size = UDim2.new(1, -16, 1, -50)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = list

	-- Barre d'actions (en bas) quand on tient un élément
	actionBar = Instance.new("Frame")
	actionBar.Name = "BuildActions"
	actionBar.AnchorPoint = Vector2.new(0.5, 1)
	actionBar.Position = UDim2.new(0.5, 0, 1, -104)
	actionBar.Size = UDim2.fromOffset(470, 84)
	actionBar.BackgroundTransparency = 1
	actionBar.Visible = false
	actionBar.Parent = screen

	hintLabel = Theme.Label({ Size = UDim2.new(1, 0, 0, 26), TextStrokeTransparency = 0.3, Text = "", Parent = actionBar })
	local buttons = Instance.new("Frame")
	buttons.Position = UDim2.fromOffset(0, 32)
	buttons.Size = UDim2.new(1, 0, 0, 50)
	buttons.BackgroundTransparency = 1
	buttons.Parent = actionBar
	local buttonLayout = Instance.new("UIListLayout")
	buttonLayout.FillDirection = Enum.FillDirection.Horizontal
	buttonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	buttonLayout.Padding = UDim.new(0, 8)
	buttonLayout.SortOrder = Enum.SortOrder.LayoutOrder
	buttonLayout.Parent = buttons

	-- Gros boutons faciles à toucher (encore plus gros sur mobile / tablette)
	local touch = isTouchMode()
	local bw, bh = if touch then 128 else 108, if touch then 64 else 48
	actionBar.Size = UDim2.fromOffset(if touch then 680 else 580, if touch then 104 else 84)
	buttons.Size = UDim2.new(1, 0, 0, bh + 2)
	local function actionButton(order: number, text: string, color: Color3, callback: () -> ()): TextButton
		local button = Theme.Button({ Size = UDim2.fromOffset(bw, bh), LayoutOrder = order, BackgroundColor3 = color, Text = text, Parent = buttons })
		button.Activated:Connect(callback)
		return button
	end
	actionButton(1, if touch then "↻ Tourner" else "↻ Tourner (R)", Color3.fromRGB(70, 120, 200), rotate)
	actionButton(2, "✔ Poser", Color3.fromRGB(60, 170, 80), confirm)
	storeButton = actionButton(3, "📦 Ranger", Color3.fromRGB(150, 110, 70), storeHeld)
	aimButton = actionButton(4, "🎯 Viseur", Color3.fromRGB(230, 170, 40), function()
		followCenter = true
	end)
	actionButton(5, "✖ Annuler", Color3.fromRGB(200, 60, 60), stopHolding)
	-- Message d'emplacement : bien lisible, sur un fond
	hintLabel.BackgroundTransparency = 0.25
	hintLabel.BackgroundColor3 = Color3.fromRGB(25, 28, 40)
	Theme.Corner(hintLabel, 8)

	-- Flèches pour décaler d'une case (mobile / tablette), à gauche de la barre
	arrowPad = Instance.new("Frame")
	arrowPad.Name = "BuildArrows"
	arrowPad.AnchorPoint = Vector2.new(0, 1)
	arrowPad.Position = UDim2.new(0, 290, 1, -100)
	arrowPad.Size = UDim2.fromOffset(186, 186)
	arrowPad.BackgroundTransparency = 1
	arrowPad.Visible = false
	arrowPad.Parent = screen
	for _, info in { { "▲", 62, 0, 1, 0 }, { "▼", 62, 124, -1, 0 }, { "◀", 0, 62, 0, -1 }, { "▶", 124, 62, 0, 1 } } do
		local arrow = Theme.Button({ Size = UDim2.fromOffset(62, 62), Position = UDim2.fromOffset(info[2], info[3]), BackgroundColor3 = Color3.fromRGB(80, 90, 130), Text = info[1], Parent = arrowPad })
		arrow.Activated:Connect(function()
			nudge(info[4], info[5])
		end)
	end

	-- Viseur au centre de l'écran (mobile) : cercle + point
	reticle = Instance.new("Frame")
	reticle.Name = "BuildReticle"
	reticle.AnchorPoint = Vector2.new(0.5, 0.5)
	reticle.Position = UDim2.fromScale(0.5, 0.5)
	reticle.Size = UDim2.fromOffset(56, 56)
	reticle.BackgroundTransparency = 1
	reticle.Visible = false
	reticle.Parent = screen
	Theme.Corner(reticle, 28)
	Theme.Stroke(reticle, 4, Color3.fromRGB(255, 235, 90))
	local dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.fromOffset(10, 10)
	dot.BackgroundColor3 = Color3.fromRGB(255, 235, 90)
	dot.Parent = reticle
	Theme.Corner(dot, 5)

	groundTarget = Instance.new("Part")
	groundTarget.Name = "BuildTarget"
	groundTarget.Shape = Enum.PartType.Cylinder
	groundTarget.Anchored = true
	groundTarget.CanCollide = false
	groundTarget.CanQuery = false
	groundTarget.CanTouch = false
	groundTarget.Material = Enum.Material.Neon
	groundTarget.Transparency = 0.2

	-- Clavier / souris (PC)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not active or gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.R then
			rotate()
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			local mouse = UserInputService:GetMouseLocation()
			if holding then
				setTargetFromScreen(mouse, false)
				confirm()
			else
				local placeType, id = placeableAt(mouse, false)
				if placeType and id then
					pickExisting(placeType, id)
				end
			end
		end
	end)

	-- Tactile (mobile / tablette) : toucher place l'aperçu, ou sélectionne un élément
	UserInputService.TouchTapInWorld:Connect(function(position, processedByUI)
		if not active or processedByUI then
			return
		end
		if holding then
			followCenter = false -- toucher le sol place l'aperçu à cet endroit
			setTargetFromScreen(position, true)
		else
			local placeType, id = placeableAt(position, true)
			if placeType and id then
				pickExisting(placeType, id)
			end
		end
	end)

	-- Souris : l'aperçu suit le pointeur ; sans rien en main, on surligne l'élément survolé
	RunService.RenderStepped:Connect(function()
		local touch = isTouchMode()
		reticle.Visible = active and touch and holding ~= nil and followCenter
		arrowPad.Visible = active and touch and holding ~= nil
		aimButton.Visible = touch and not followCenter
		if active and touch and holding and followCenter then
			-- Mobile : l'aperçu se place au centre de l'écran (on bouge la caméra pour viser)
			local camera = Workspace.CurrentCamera
			setTargetFromScreen(camera.ViewportSize / 2, false)
		end
		if not active or touch then
			return
		end
		local mouse = UserInputService:GetMouseLocation()
		if holding then
			setTargetFromScreen(mouse, false)
			hoverBox.Adornee = nil
		else
			local _, _, model = placeableAt(mouse, false)
			hoverBox.Adornee = model
		end
	end)

	StateController.Changed:Connect(function(key)
		if not active then
			return
		end
		if key == "*" or key == "Fields" or key == "Pens" or key == "Buildings" or key == "Pedestals" or key == "PlotLevel" then
			rebuildMenu()
			updateGhost()
		end
	end)
end

return BuildMode
