--[[
	PlotService.lua
	===============
	Génère la map (sol, spawn central, 6 parcelles) en Parts simples, attribue
	automatiquement une parcelle libre à chaque joueur qui rejoint et la libère
	quand il part.

	Chaque parcelle est un Model "Plot_<id>" dans Workspace.Plots avec :
	  - attribut PlotId (number)
	  - attribut OwnerUserId (0 = libre)
	  - Base (sol), bordures, panneau avec le nom du propriétaire, Spawn (invisible)
	Le joueur reçoit l'attribut "PlotId" (lisible par le client).

	API :
	  PlotService:GetPlot(player) -> plot | nil
	  PlotService:TeleportHome(player)

	Remplacer les visuels plus tard : modifie seulement les fonctions build*().
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RemoteGuard = require(script.Parent.Parent.Util.RemoteGuard)
local CurrencyService = require(script.Parent.CurrencyService)
local SyncService = require(script.Parent.SyncService)

local PlotConfig = Config.Plots

local PlotService = {}

export type Plot = {
	Id: number,
	Model: Model,
	CFrame: CFrame, -- centre du sol, regard (-Z) tourné vers l'allée centrale
	SpawnCFrame: CFrame,
	Owner: Player?,
	OwnerLabel: TextLabel,
}

local plots: { Plot } = {} -- liste ordonnée par Id
local plotByPlayer: { [Player]: Plot } = {}

-- Callbacks des autres services (FarmService, etc.).
-- (Pas de BindableEvent : il COPIE les tables, on perdrait la référence à la parcelle.)
local assignedCallbacks: { (Player, Plot) -> () } = {}
local releasedCallbacks: { (Player, Plot) -> () } = {}

-- callback(player, plot) : appelé quand un joueur reçoit une parcelle
function PlotService:OnPlotAssigned(callback: (Player, Plot) -> ())
	table.insert(assignedCallbacks, callback)
end

-- callback(player, plot) : appelé (synchroniquement) juste AVANT la libération d'une parcelle
function PlotService:OnPlotReleased(callback: (Player, Plot) -> ())
	table.insert(releasedCallbacks, callback)
end

--------------------------------------------------------------------------
-- Construction de la map
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

local function buildWorld()
	-- Sol général si la place n'a pas déjà un Baseplate
	if not Workspace:FindFirstChild("Baseplate") and not Workspace:FindFirstChild("FarmGround") then
		makePart({
			Name = "FarmGround",
			Size = Vector3.new(512, 2, 512),
			Position = Vector3.new(0, -1, 0),
			Color = Color3.fromRGB(90, 140, 60),
			Material = Enum.Material.Grass,
			Parent = Workspace,
		})
	end

	-- Allée centrale + spawn d'arrivée
	makePart({
		Name = "CentralPath",
		Size = Vector3.new(PlotConfig.SpacingX * PlotConfig.Columns, 0.2, PlotConfig.RowOffsetZ * 2 - PlotConfig.Size.Z - 4),
		Position = Vector3.new(0, 0.1, 0),
		Color = Color3.fromRGB(200, 180, 140),
		Material = Enum.Material.Sand,
		CanCollide = false,
		Parent = Workspace,
	})

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

local function buildPlot(id: number, folder: Folder): Plot
	local index = id - 1
	local column = index % PlotConfig.Columns
	local row = index // PlotConfig.Columns -- 0 = rangée sud, 1 = rangée nord

	local size = PlotConfig.Size
	local x = (column - (PlotConfig.Columns - 1) / 2) * PlotConfig.SpacingX
	local z = if row == 0 then -PlotConfig.RowOffsetZ else PlotConfig.RowOffsetZ
	local center = Vector3.new(x, size.Y / 2, z)

	-- Le "devant" (-Z local) de la parcelle regarde l'allée centrale
	local facing = Vector3.new(0, 0, if z < 0 then 1 else -1)
	local plotCFrame = CFrame.lookAt(center, center + facing)

	local model = Instance.new("Model")
	model.Name = "Plot_" .. id
	model:SetAttribute("PlotId", id)
	model:SetAttribute("OwnerUserId", 0)

	-- Sol
	local base = makePart({
		Name = "Base",
		Size = size,
		CFrame = plotCFrame,
		Color = PlotConfig.GroundColor,
		Material = Enum.Material.Grass,
		Parent = model,
	})
	model.PrimaryPart = base

	-- Bordures basses (on peut marcher par-dessus)
	local borderHeight, borderThickness = 0.6, 1
	local topY = size.Y / 2 + borderHeight / 2
	local borders = {
		{ Vector3.new(size.X, borderHeight, borderThickness), Vector3.new(0, topY, -size.Z / 2) },
		{ Vector3.new(size.X, borderHeight, borderThickness), Vector3.new(0, topY, size.Z / 2) },
		{ Vector3.new(borderThickness, borderHeight, size.Z), Vector3.new(-size.X / 2, topY, 0) },
		{ Vector3.new(borderThickness, borderHeight, size.Z), Vector3.new(size.X / 2, topY, 0) },
	}
	for i, border in borders do
		makePart({
			Name = "Border" .. i,
			Size = border[1],
			CFrame = plotCFrame * CFrame.new(border[2]),
			Color = PlotConfig.BorderColor,
			Material = Enum.Material.Wood,
			Parent = model,
		})
	end

	-- Panneau à l'entrée (2 poteaux + planche)
	local signLocal = CFrame.new(0, size.Y / 2, -size.Z / 2 - 2)
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
	billboard.StudsOffset = Vector3.new(0, 0, 0)
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
	label.Parent = billboard

	-- Point d'apparition (invisible), juste à l'entrée, tourné vers l'intérieur
	local spawnCFrame = plotCFrame * CFrame.new(0, size.Y / 2 + 3, -size.Z / 2 + 5) * CFrame.Angles(0, math.pi, 0)
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

	model.Parent = folder

	local plot: Plot = {
		Id = id,
		Model = model,
		CFrame = plotCFrame,
		SpawnCFrame = spawnCFrame,
		Owner = nil,
		OwnerLabel = label,
	}
	return plot
end

-- Pad jaune de test : donne des coins (pour vérifier la sauvegarde en Phase 1)
local function buildDebugCoinPad(plot: Plot)
	local size = PlotConfig.Size
	local pad = makePart({
		Name = "DebugCoinPad",
		Size = Vector3.new(4, 0.4, 4),
		CFrame = plot.CFrame * CFrame.new(size.X / 2 - 6, size.Y / 2 + 0.2, -size.Z / 2 + 6),
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
		-- Toute la validation est faite ici, côté serveur
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
-- Attribution / libération
--------------------------------------------------------------------------

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

local function assignPlot(player: Player)
	if plotByPlayer[player] then
		return
	end

	for _, plot in plots do
		if plot.Owner == nil then
			plot.Owner = player
			plot.Model:SetAttribute("OwnerUserId", player.UserId)
			plot.OwnerLabel.Text = PlotConfig.OwnerLabelFormat:format(player.DisplayName)
			plotByPlayer[player] = plot
			player:SetAttribute("PlotId", plot.Id)
			print(("[PlotService] Parcelle %d attribuée à %s"):format(plot.Id, player.Name))
			for _, callback in assignedCallbacks do
				task.spawn(callback, player, plot)
			end
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
	for _, callback in releasedCallbacks do
		local ok, err = pcall(callback, player, plot) -- ex. FarmService retire les plantes affichées
		if not ok then
			warn("[PlotService] Erreur dans un callback de libération : " .. tostring(err))
		end
	end
	plotByPlayer[player] = nil
	plot.Owner = nil
	plot.Model:SetAttribute("OwnerUserId", 0)
	plot.OwnerLabel.Text = PlotConfig.FreeLabel
	print(("[PlotService] Parcelle %d libérée (départ de %s)"):format(plot.Id, player.Name))
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
	end
	print(("[PlotService] %d parcelles générées"):format(#plots))
end

function PlotService:Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(releasePlot)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

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
