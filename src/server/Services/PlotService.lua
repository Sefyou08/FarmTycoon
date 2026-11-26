--[[
	PlotService.lua
	===============
	Génère la map (sol, spawn central, 6 parcelles) en Parts simples, attribue
	automatiquement une parcelle libre à chaque joueur qui rejoint, gère
	l'AGRANDISSEMENT de la parcelle, et la libère quand le joueur part.

	Repère d'une parcelle (plot.CFrame) : le MILIEU DE SON ENTRÉE, au niveau
	du sol, regard (-Z local) tourné vers l'allée centrale. L'intérieur de la
	parcelle est donc vers +Z local. Elle s'agrandit vers le fond et sur les
	côtés (Config.Plots.Expansions) : l'entrée ne bouge jamais.

	Chaque parcelle est un Model "Plot_<id>" dans Workspace.Plots avec :
	  - attribut PlotId, attribut OwnerUserId (0 = libre), attribut Level
	  - Base (sol), Borders, panneau avec le nom du propriétaire, Spawn (invisible)
	  - ExpandPad : bouton tycoon "Agrandir la parcelle"

	Événements pour les autres services (callbacks, voir plus bas) :
	  OnPlotReady(player, plot, data)  : le joueur a sa parcelle ET ses données chargées
	  OnPlotReleased(player, plot)     : juste avant la libération (déconnexion)
	  OnPlotLevelChanged(player, plot, level)

	API :
	  PlotService:GetPlot(player) -> plot | nil
	  PlotService:GetAllPlots() -> { plot }
	  PlotService:GetLevel(player) -> number
	  PlotService:ToWorld(plot, x, z, height?) -> CFrame (coordonnées locales -> monde)
	  PlotService:GrantExpansion(player) -> boolean  (Developer Product, phase 8)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local CosmeticUtil = require(ReplicatedStorage.Shared.CosmeticUtil)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RemoteGuard = require(script.Parent.Parent.Util.RemoteGuard)
local FarmScenery = require(script.Parent.Parent.Util.FarmScenery)
local PatternBuilder = require(script.Parent.Parent.Util.PatternBuilder)
local FenceBuilder = require(script.Parent.Parent.Util.FenceBuilder)
local TycoonPad = require(script.Parent.Parent.Util.TycoonPad)
local DataService = require(script.Parent.DataService)
local CurrencyService = require(script.Parent.CurrencyService)
local SyncService = require(script.Parent.SyncService)

local PlotConfig = Config.Plots
local EXPANSIONS = PlotConfig.Expansions
local MAX_LEVEL = #EXPANSIONS

local PlotService = {}

export type Plot = {
	Id: number,
	Model: Model,
	CFrame: CFrame, -- milieu de l'entrée, au centre de l'épaisseur du sol
	SpawnCFrame: CFrame,
	Owner: Player?,
	OwnerLabel: TextLabel,
	Level: number,
	Base: Part,
	Borders: Folder,
	ExpandPad: Part,
	ExpandPrompt: ProximityPrompt,
	ExpandPadModel: Model,
	ExpandRobuxPad: Model,
	ExpandDetail: TextLabel,
	BoostPads: { Model },
}

local plots: { Plot } = {} -- liste ordonnée par Id
local plotByPlayer: { [Player]: Plot } = {}
local readyPlayers: { [Player]: boolean } = {}

-- Callbacks des autres services.
-- (Pas de BindableEvent : il COPIE les tables, on perdrait la référence à la parcelle.)
local readyCallbacks: { (Player, Plot, { [string]: any }) -> () } = {}
local releasedCallbacks: { (Player, Plot) -> () } = {}
local levelCallbacks: { (Player, Plot, number) -> () } = {}

local function runCallbacks(list: { any }, ...)
	for _, callback in list do
		local ok, err = pcall(callback, ...)
		if not ok then
			warn("[PlotService] Erreur dans un callback : " .. tostring(err))
		end
	end
end

function PlotService:OnPlotReady(callback: (Player, Plot, { [string]: any }) -> ())
	table.insert(readyCallbacks, callback)
end

function PlotService:OnPlotReleased(callback: (Player, Plot) -> ())
	table.insert(releasedCallbacks, callback)
end

function PlotService:OnPlotLevelChanged(callback: (Player, Plot, number) -> ())
	table.insert(levelCallbacks, callback)
end

--------------------------------------------------------------------------
-- Construction
--------------------------------------------------------------------------

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

-- Coordonnées locales de parcelle -> CFrame monde.
-- x : gauche/droite, z : profondeur depuis l'entrée (vers l'intérieur), height : au-dessus du sol.
function PlotService:ToWorld(plot: Plot, x: number, z: number, height: number?): CFrame
	-- plot.CFrame regarde l'allée (-Z local) : +Z local va donc vers l'intérieur de la parcelle.
	return plot.CFrame * CFrame.new(x, PlotConfig.BaseHeight / 2 + (height or 0), z)
end

local function buildWorld()
	-- Terrain, montagnes, ruisseau, chemins, arbres, place du spawn, éclairage (phase 10)
	FarmScenery.Build()

	if not Workspace:FindFirstChildWhichIsA("SpawnLocation") then
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "LobbySpawn"
		spawn.Anchored = true
		spawn.Size = Vector3.new(8, 1, 8)
		spawn.Position = Vector3.new(0, 0.5, 0)
		spawn.Color = Color3.fromRGB(240, 220, 120)
		spawn.Duration = 0 -- pas de bouclier ForceField
		spawn.Parent = Workspace
	end
end

-- Redimensionne le sol et les bordures selon le niveau d'agrandissement.
local function applyLevel(plot: Plot, level: number)
	plot.Level = level
	plot.Model:SetAttribute("Level", level)

	local size = EXPANSIONS[level]
	local height = PlotConfig.BaseHeight
	plot.Base.Size = Vector3.new(size.Width, height, size.Depth)
	plot.Base.CFrame = plot.CFrame * CFrame.new(0, 0, size.Depth / 2)

	-- Clôture continue autour de la parcelle (cosmétique "Clôture de parcelle"), recréée à chaque niveau
	plot.Borders:ClearAllChildren()
	local owner = plot.Owner and DataService:GetData(plot.Owner)
	local fenceStyle = CosmeticUtil.Equipped(owner, "PlotFence") or Config.Cosmetics.FenceWood
	FenceBuilder.Build(plot.Borders, plot.CFrame, size.Width, size.Depth, fenceStyle, PlotConfig.GateWidth, height / 2)

	-- Bouton d'agrandissement : visible seulement si la parcelle a un propriétaire et n'est pas au max
	local canExpand = plot.Owner ~= nil and level < MAX_LEVEL
	TycoonPad.SetVisible(plot.ExpandPadModel, canExpand)
	TycoonPad.SetVisible(plot.ExpandRobuxPad, canExpand)
	if level < MAX_LEVEL then
		local price = Format.Number(EXPANSIONS[level + 1].Price)
		plot.ExpandPrompt.ActionText = ("Agrandir : %s Coins"):format(price)
		plot.ExpandPrompt.ObjectText = ("Parcelle niveau %d → %d"):format(level, level + 1)
		plot.ExpandDetail.Text = ("%s Coins  •  niv. %d → %d"):format(price, level, level + 1)
	end
	-- Boutons de boosts Robux : seulement sur une parcelle qui a un propriétaire
	for _, pad in plot.BoostPads do
		TycoonPad.SetVisible(pad, plot.Owner ~= nil)
	end

	-- Cosmétiques du propriétaire : sol et panneau (valeurs par défaut si parcelle libre)
	local data = plot.Owner and DataService:GetData(plot.Owner)
	local floor = CosmeticUtil.Equipped(data, "PlotFloor")
	plot.Base.Color = if floor and floor.Color then floor.Color else PlotConfig.GroundColor
	plot.Base.Material = if floor and floor.Material then floor.Material else Enum.Material.SmoothPlastic
	local sign = CosmeticUtil.Equipped(data, "SignStyle")
	for _, child in plot.Model:GetChildren() do
		if child:IsA("BasePart") and (child.Name == "SignPost" or child.Name == "SignBoard") then
			child.Color = if sign and sign.Color then sign.Color else PlotConfig.SignColor
			child.Material = if sign and sign.Material then sign.Material else Enum.Material.WoodPlanks
		end
	end
	plot.OwnerLabel.TextColor3 = if sign and sign.TextColor then sign.TextColor else Color3.new(1, 1, 1)

	-- Motifs cosmétiques sur le sol et le panneau (phase 10), recréés à chaque changement
	for _, name in { "FloorPattern", "SignPattern" } do
		local old = plot.Model:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	if floor and floor.Pattern then
		local holder = Instance.new("Model")
		holder.Name = "FloorPattern"
		holder.Parent = plot.Model
		local checker = floor.Pattern == "Checker"
		PatternBuilder.Apply(plot.Base, Enum.NormalId.Top, floor.Pattern, {
			Parent = holder,
			Spacing = if checker then 8 else 13,
			Size = 4,
			MaxCount = if checker then 200 else 90,
			Color = floor.PatternColor,
			Accent = floor.PatternAccent,
		})
	end
	local board = plot.Model:FindFirstChild("SignBoard")
	if sign and sign.Pattern and board and board:IsA("BasePart") then
		local holder = Instance.new("Model")
		holder.Name = "SignPattern"
		holder.Parent = plot.Model
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			PatternBuilder.Apply(board, face, sign.Pattern, { Parent = holder, Spacing = 2.6, Size = 1.6, MaxCount = 10, Color = sign.PatternColor, Accent = sign.PatternAccent })
		end
	end
end

local function buildPlot(id: number, folder: Folder): Plot
	local index = id - 1
	local column = index % PlotConfig.Columns
	local row = index // PlotConfig.Columns -- 0 = rangée sud, 1 = rangée nord

	local x = (column - (PlotConfig.Columns - 1) / 2) * PlotConfig.SpacingX
	local frontZ = if row == 0 then -PlotConfig.FrontOffsetZ else PlotConfig.FrontOffsetZ
	local origin = Vector3.new(x, PlotConfig.BaseHeight / 2, frontZ)

	-- -Z local regarde l'allée ; l'intérieur de la parcelle est vers +Z local (loin de l'allée)
	local towardRoad = Vector3.new(0, 0, if frontZ < 0 then 1 else -1)
	local plotCFrame = CFrame.lookAt(origin, origin + towardRoad)

	local model = Instance.new("Model")
	model.Name = "Plot_" .. id
	model:SetAttribute("PlotId", id)
	model:SetAttribute("OwnerUserId", 0)
	-- Repère de la parcelle (milieu de l'entrée), utilisé par le mode construction côté client
	model:SetAttribute("Origin", plotCFrame * CFrame.new(0, PlotConfig.BaseHeight / 2, 0))

	local base = makePart({
		Name = "Base",
		Size = Vector3.new(10, PlotConfig.BaseHeight, 10),
		CFrame = plotCFrame,
		Color = PlotConfig.GroundColor,
		Material = Enum.Material.SmoothPlastic,
		Parent = model,
	})
	model.PrimaryPart = base

	local borders = Instance.new("Folder")
	borders.Name = "Borders"
	borders.Parent = model

	-- Panneau devant l'entrée (2 poteaux + planche)
	local signLocal = CFrame.new(0, PlotConfig.BaseHeight / 2, -3)
	for _, offsetX in { -6, 6 } do
		makePart({
			Name = "SignPost",
			Size = Vector3.new(0.6, 7, 0.6),
			CFrame = plotCFrame * signLocal * CFrame.new(offsetX, 3.5, 0),
			Color = PlotConfig.SignColor,
			Material = Enum.Material.Wood,
			Parent = model,
		})
	end
	local board = makePart({
		Name = "SignBoard",
		Size = Vector3.new(14, 3, 0.4),
		CFrame = plotCFrame * signLocal * CFrame.new(0, 6, 0),
		Color = PlotConfig.SignColor,
		Material = Enum.Material.WoodPlanks,
		Parent = model,
	})

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "OwnerGui"
	billboard.Size = UDim2.fromScale(14, 3) -- en studs
	billboard.MaxDistance = 250
	billboard.LightInfluence = 0
	billboard.Adornee = board
	billboard.Parent = board

	local label = Instance.new("TextLabel")
	label.Name = "OwnerLabel"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Text = PlotConfig.FreeLabel
	label.RichText = true -- 2e ligne : meilleure prise du joueur (DisplayService)
	label.Parent = billboard

	-- Point d'apparition (invisible), juste après l'entrée, tourné vers l'intérieur
	local spawnCFrame = plotCFrame * CFrame.new(0, PlotConfig.BaseHeight / 2 + 3, 6) * CFrame.Angles(0, math.pi, 0)
	makePart({
		Name = "Spawn",
		Size = Vector3.new(2, 1, 2),
		CFrame = spawnCFrame,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = model,
	})

	-- Boutons au sol style tycoon (bande d'entrée) : agrandir (Coins / Robux) et boosts Robux
	local Pads = Config.TycoonPads
	local function padGround(spot: { [string]: any }): CFrame
		return plotCFrame * CFrame.new(spot.X, PlotConfig.BaseHeight / 2, spot.Z)
	end
	local expandModel, expandPad, expandPrompt, _, expandDetail = TycoonPad.Build(model, padGround(Pads.ExpandCoins), {
		Name = "ExpandCoinsPad",
		Color = Color3.fromRGB(60, 200, 255),
		Icon = "💰",
		Title = "Agrandir",
		Detail = "",
		ActionText = "Agrandir",
		Hold = 0.4, -- petit appui long : évite les achats par erreur
	})
	expandPad.Name = "ExpandPad"
	expandPrompt.MaxActivationDistance = PlotConfig.ExpandInteractDistance

	local function robuxPad(spot: { [string]: any }, color: Color3, name: string): Model
		local product = Config.Monetization.Products[spot.Product]
		local price = if product.Id > 0 then ("💎 %d R$"):format(product.Price) else ("💎 %d R$ (bientôt)"):format(product.Price)
		local pad, top, prompt = TycoonPad.Build(model, padGround(spot), {
			Name = name,
			Color = color,
			Icon = product.Icon,
			Title = product.Name,
			Detail = price,
			ActionText = ("Acheter (%d R$)"):format(product.Price),
			ObjectText = product.Description,
		})
		-- Le client ouvre la fenêtre d'achat Roblox (prompt ou en marchant dessus)
		prompt:SetAttribute("RobuxProduct", spot.Product)
		top:SetAttribute("RobuxProduct", spot.Product)
		if product.Kind == "Boost" then
			top:SetAttribute("BoostType", product.Boost)
			top:SetAttribute("PriceText", price)
		end
		return pad
	end
	local expandRobux = robuxPad(Pads.ExpandRobux, Color3.fromRGB(170, 90, 255), "ExpandRobuxPad")
	local boostColors = { Growth = Color3.fromRGB(90, 210, 90), Production = Color3.fromRGB(255, 150, 50), XP = Color3.fromRGB(90, 170, 255), Coins = Color3.fromRGB(255, 205, 50) }
	local boostPads = {}
	for i, spot in Pads.Boosts do
		local product = Config.Monetization.Products[spot.Product]
		table.insert(boostPads, robuxPad(spot, boostColors[product.Boost] or Color3.fromRGB(255, 120, 200), "BoostPad" .. i))
	end

	model.Parent = folder

	local plot: Plot = {
		Id = id,
		Model = model,
		CFrame = plotCFrame,
		SpawnCFrame = spawnCFrame,
		Owner = nil,
		OwnerLabel = label,
		Level = 1,
		Base = base,
		Borders = borders,
		ExpandPad = expandPad,
		ExpandPrompt = expandPrompt,
		ExpandPadModel = expandModel,
		ExpandRobuxPad = expandRobux,
		ExpandDetail = expandDetail,
		BoostPads = boostPads,
	}
	applyLevel(plot, 1)
	return plot
end

-- Pad jaune de test : donne des coins (Config.Debug)
local function buildDebugCoinPad(plot: Plot)
	local firstWidth = EXPANSIONS[1].Width
	local pad = makePart({
		Name = "DebugCoinPad",
		Size = Vector3.new(4, 0.4, 4),
		CFrame = plot.CFrame * CFrame.new(firstWidth / 2 - 6, PlotConfig.BaseHeight / 2 + 0.2, 4),
		Color = Color3.fromRGB(255, 210, 40),
		Material = Enum.Material.Neon,
		Parent = plot.Model,
	})

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = ("Prendre %d Coins"):format(Config.Debug.TestCoinPadAmount)
	prompt.ObjectText = "Pad de test"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OwnerOnly", true) -- le client le masque sur les parcelles des autres
	prompt.Parent = pad

	prompt.Triggered:Connect(function(player: Player)
		if plot.Owner ~= player then
			SyncService:Notify(player, "Ce n'est pas ta parcelle !", "Error")
			return
		end
		if not RemoteGuard.IsNear(player, pad.Position, prompt.MaxActivationDistance + 4) then
			return
		end
		if not RemoteGuard.CheckCooldown(player, "DebugCoinPad", Config.Debug.TestCoinPadCooldown) then
			return
		end
		local ok, added = CurrencyService:AddCoins(player, Config.Debug.TestCoinPadAmount, "DebugCoinPad")
		if ok then
			SyncService:Notify(player, ("+%d Coins"):format(added), "Success")
		end
	end)
end

--------------------------------------------------------------------------
-- Agrandissement
--------------------------------------------------------------------------

function PlotService:GetLevel(player: Player): number
	local plot = plotByPlayer[player]
	return if plot then plot.Level else 1
end

-- Passe la parcelle du joueur au niveau suivant (sans paiement : à appeler APRÈS avoir payé).
local function expand(player: Player): boolean
	local plot = plotByPlayer[player]
	local data = DataService:GetData(player)
	if not plot or not data or not readyPlayers[player] or plot.Level >= MAX_LEVEL then
		return false
	end
	data.PlotLevel = plot.Level + 1
	applyLevel(plot, data.PlotLevel)
	SyncService:Set(player, "PlotLevel", data.PlotLevel)
	runCallbacks(levelCallbacks, player, plot, data.PlotLevel)
	SyncService:Notify(player, ("Parcelle agrandie : niveau %d ! Nouveaux emplacements débloqués."):format(data.PlotLevel), "Success")
	return true
end

-- Emplacement pour le Developer Product "PlotExpansion" (phase 8, désactivé).
-- Sera appelé par MonetizationService dans ProcessReceipt, après un achat Robux validé.
function PlotService:GrantExpansion(player: Player): boolean
	return expand(player)
end

local function onExpandTriggered(plot: Plot, player: Player)
	if plot.Owner ~= player or not readyPlayers[player] then
		return
	end
	if plot.Level >= MAX_LEVEL then
		return
	end
	if not RemoteGuard.IsNear(player, plot.ExpandPad.Position, PlotConfig.ExpandInteractDistance + 4) then
		return
	end
	if not RemoteGuard.CheckCooldown(player, "ExpandPlot", 1) then
		return
	end
	local price = EXPANSIONS[plot.Level + 1].Price
	if not CurrencyService:SpendCoins(player, price, "ExpandPlot") then
		SyncService:Notify(player, ("Il te faut %s Coins pour agrandir."):format(Format.Number(price)), "Error")
		return
	end
	expand(player)
end

--------------------------------------------------------------------------
-- Attribution / libération
--------------------------------------------------------------------------

-- Panneau de la parcelle : "Ferme de X" + une 2e ligne optionnelle (ex. meilleure prise)
function PlotService:SetSignSubtitle(plot: Plot, subtitle: string?)
	if not plot.Owner then
		plot.OwnerLabel.Text = PlotConfig.FreeLabel
		return
	end
	local title = PlotConfig.OwnerLabelFormat:format(plot.Owner.DisplayName)
	local text = if subtitle then ('%s\n<font size="20">%s</font>'):format(title, subtitle) else title
	if plot.OwnerLabel.Text ~= text then
		plot.OwnerLabel.Text = text
	end
end

function PlotService:GetPlot(player: Player): Plot?
	return plotByPlayer[player]
end

function PlotService:GetAllPlots(): { Plot }
	return plots
end

function PlotService:TeleportHome(player: Player)
	local plot = plotByPlayer[player]
	local character = player.Character
	if plot and character and character.PrimaryPart then
		character:PivotTo(plot.SpawnCFrame)
	end
end

-- Déclenche OnPlotReady quand le joueur a sa parcelle ET ses données (ordre variable).
local function tryReady(player: Player)
	if readyPlayers[player] or not player.Parent then
		return
	end
	local plot = plotByPlayer[player]
	local data = DataService:GetData(player)
	if not plot or not data then
		return
	end
	readyPlayers[player] = true

	local level = math.clamp(math.floor(tonumber(data.PlotLevel) or 1), 1, MAX_LEVEL)
	data.PlotLevel = level
	applyLevel(plot, level)
	SyncService:Set(player, "PlotLevel", level)

	runCallbacks(readyCallbacks, player, plot, data)
end

local function assignPlot(player: Player)
	if plotByPlayer[player] then
		return
	end

	for _, plot in plots do
		if plot.Owner == nil then
			plot.Owner = player
			plot.Model:SetAttribute("OwnerUserId", player.UserId)
			PlotService:SetSignSubtitle(plot, nil)
			plotByPlayer[player] = plot
			player:SetAttribute("PlotId", plot.Id)
			print(("[PlotService] Parcelle %d attribuée à %s"):format(plot.Id, player.Name))
			tryReady(player)
			return
		end
	end

	-- Standard des tycoons : nombre max de joueurs du serveur = nombre de parcelles.
	warn(("[PlotService] Aucune parcelle libre pour %s ! Règle Max Players = %d dans Game Settings."):format(player.Name, PlotConfig.Count))
	SyncService:Notify(player, "Aucune parcelle libre sur ce serveur.", "Error")
end

local function releasePlot(player: Player)
	local plot = plotByPlayer[player]
	if not plot then
		return
	end
	if readyPlayers[player] then
		runCallbacks(releasedCallbacks, player, plot) -- les services retirent plantes, enclos...
	end
	readyPlayers[player] = nil
	plotByPlayer[player] = nil
	plot.Owner = nil
	plot.Model:SetAttribute("OwnerUserId", 0)
	plot.OwnerLabel.Text = PlotConfig.FreeLabel
	applyLevel(plot, 1)
	print(("[PlotService] Parcelle %d libérée (départ de %s)"):format(plot.Id, player.Name))
end

-- Reconstruit toute la ferme du joueur à partir de ses données (ex. après un rebirth) :
-- les services retirent leurs visuels (OnPlotReleased) puis les recréent (OnPlotReady).
function PlotService:Reload(player: Player)
	local plot = plotByPlayer[player]
	if not plot then
		return
	end
	if readyPlayers[player] then
		runCallbacks(releasedCallbacks, player, plot)
	end
	readyPlayers[player] = nil
	tryReady(player)
end

local function onCharacterAdded(player: Player, character: Model)
	-- On attend que le personnage soit réellement placé avant de le déplacer
	character:WaitForChild("HumanoidRootPart", 10)
	task.wait()
	if character.Parent and plotByPlayer[player] then
		character:PivotTo(plotByPlayer[player].SpawnCFrame)
	end
end

local function onPlayerAdded(player: Player)
	assignPlot(player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

--------------------------------------------------------------------------
-- Cycle de vie
--------------------------------------------------------------------------

function PlotService:Init()
	buildWorld()

	local folder = Instance.new("Folder")
	folder.Name = "Plots"
	folder.Parent = Workspace

	for id = 1, PlotConfig.Count do
		local plot = buildPlot(id, folder)
		table.insert(plots, plot)
		if Config.Debug.Enabled then
			buildDebugCoinPad(plot)
		end
		plot.ExpandPrompt.Triggered:Connect(function(player)
			onExpandTriggered(plot, player)
		end)
	end
	print(("[PlotService] %d parcelles générées"):format(#plots))

	DataService:OnProfileLoaded(function(player)
		tryReady(player)
	end)
end

function PlotService:Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(releasePlot)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	-- Visite de la parcelle d'un autre joueur (bouton 🏡 Visiter)
	Remotes.Get("RequestVisit").OnServerEvent:Connect(function(player: Player, userId: any)
		if not RemoteGuard.IsValidNumber(userId, 1, math.huge, true) then
			return
		end
		if not RemoteGuard.CheckCooldown(player, "Visit", 3) then
			SyncService:Notify(player, "Patiente un peu avant de te téléporter.", "Error")
			return
		end
		local target = Players:GetPlayerByUserId(userId)
		local plot = target and plotByPlayer[target]
		local character = player.Character
		if not plot or not character or not character.PrimaryPart then
			SyncService:Notify(player, "Ce joueur n'a pas de parcelle.", "Error")
			return
		end
		character:PivotTo(plot.SpawnCFrame)
		if target ~= player then
			SyncService:Notify(player, ("🏡 Bienvenue chez %s ! (🏠 Ma ferme pour rentrer)"):format((target :: Player).DisplayName), "Info")
		end
	end)

	-- Bouton "Ma ferme" du client : cooldown vérifié côté serveur
	Remotes.Get("RequestTeleportHome").OnServerEvent:Connect(function(player: Player)
		if not RemoteGuard.CheckCooldown(player, "TeleportHome", Config.Security.TeleportHomeCooldown) then
			SyncService:Notify(player, "Patiente un peu avant de te téléporter.", "Error")
			return
		end
		self:TeleportHome(player)
	end)
end

return PlotService
