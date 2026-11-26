--[[
	FarmService.lua
	===============
	Cases de terre, plantation, pousse (3 stades) et récolte.

	Fonctionnement :
	  • Au démarrage, chaque parcelle reçoit une grille de cases (Config.Farm).
	    Seules les StartingTiles premières sont visibles ; les autres seront
	    débloquées en phase 4.
	  • Chaque case a un ProximityPrompt géré PAR LE SERVEUR :
	      vide  -> "Planter : <graine choisie>"
	      pousse -> "Mettre de l'engrais" si le joueur a du fumier (cheval), sinon masqué
	                (un minuteur s'affiche au-dessus de la plante)
	      mûre  -> "Récolter"
	  • Les plantes sont sauvegardées dans data.Plants avec des horodatages
	    os.time() : elles continuent de pousser quand le joueur est hors ligne
	    (comme dans Grow a Garden).
	  • Toute la validation (propriétaire, distance, cooldown, graine possédée,
	    plante mûre, inventaire plein) est faite ici, côté serveur.

	API :
	  FarmService:GetGrowTime(player, cropId) -> secondes (multiplicateurs en phase 4/5)
	  FarmService:GetUnlockedTileCount(player) -> number
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CropUtil = require(ReplicatedStorage.Shared.CropUtil)
local ItemUtil = require(ReplicatedStorage.Shared.ItemUtil)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RemoteGuard = require(script.Parent.Parent.Util.RemoteGuard)
local DataService = require(script.Parent.DataService)
local SyncService = require(script.Parent.SyncService)
local PlotService = require(script.Parent.PlotService)
local InventoryService = require(script.Parent.InventoryService)

local FarmConfig = Config.Farm

local FarmService = {}

-- Tag posé sur les plantes en train de pousser : le client met à jour leur minuteur
local GROWING_TAG = "GrowingPlant"
local STAGE_SCALE = { 0.35, 0.65, 1 } -- taille de la plante par stade (petite, moyenne, mûre)

type Tile = {
	Index: number,
	Key: string, -- index en chaîne (clé de data.Plants)
	Part: Part,
	Prompt: ProximityPrompt,
	Model: Model?, -- visuel de la plante actuelle
	Stage: number, -- 0 = vide, 1..3 = stade affiché
}

type Farm = {
	Player: Player,
	Plot: any,
	Data: { [string]: any },
}

local tilesByPlotId: { [number]: { Tile } } = {}
local farms: { [Player]: Farm } = {}
local selectedSeed: { [Player]: string } = {}

--------------------------------------------------------------------------
-- Utilitaires
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

-- Partie décorative : pas de collision, pas de raycast, pas de Touched
local function decoPart(props: { [string]: any }): Part
	props.CanCollide = false
	props.CanQuery = false
	props.CanTouch = false
	return makePart(props)
end

local function getStage(plant: { [string]: any }, now: number): number
	if now >= plant.ReadyAt then
		return 3
	end
	local duration = math.max(plant.ReadyAt - plant.PlantedAt, 1)
	local progress = (now - plant.PlantedAt) / duration
	return if progress < 0.5 then 1 else 2
end

function FarmService:GetGrowTime(_player: Player, cropId: string): number
	local crop = Config.Crops[cropId]
	-- Phase 4 (arroseur) et phase 5 (familiers) appliqueront un multiplicateur ici
	return crop.GrowTime
end

function FarmService:GetUnlockedTileCount(player: Player): number
	local data = DataService:GetData(player)
	local maxTiles = FarmConfig.GridColumns * FarmConfig.GridRows
	-- Phase 4 : + les cases achetées avec les boutons tycoon
	local extra = if data then (data.Upgrades.ExtraTiles or 0) else 0
	return math.min(FarmConfig.StartingTiles + extra, maxTiles)
end

--------------------------------------------------------------------------
-- Visuels des plantes (Parts simples, à remplacer par tes modèles plus tard)
--------------------------------------------------------------------------

local function buildPlantModel(tile: Tile, cropId: string, stage: number, readyAt: number): Model
	local crop = Config.Crops[cropId]
	local scale = STAGE_SCALE[stage]
	local model = Instance.new("Model")
	model.Name = "Plant"

	local ground = tile.Part.CFrame * CFrame.new(0, tile.Part.Size.Y / 2, 0)
	local stemHeight = 3 * scale

	local stem = decoPart({
		Name = "Stem",
		Size = Vector3.new(0.35, stemHeight, 0.35),
		CFrame = ground * CFrame.new(0, stemHeight / 2, 0),
		Color = Color3.fromRGB(70, 160, 60),
		Material = Enum.Material.Grass,
		Parent = model,
	})
	model.PrimaryPart = stem

	-- Deux feuilles en croix
	for i = 0, 1 do
		decoPart({
			Name = "Leaf",
			Size = Vector3.new(2.2 * scale, 0.15, 0.7 * scale),
			CFrame = ground * CFrame.new(0, stemHeight * 0.6, 0) * CFrame.Angles(0, math.rad(45 + 90 * i), math.rad(15)),
			Color = Color3.fromRGB(90, 190, 70),
			Material = Enum.Material.Grass,
			Parent = model,
		})
	end

	-- Fruit : petit et pâle au stade 2, taille et couleur réelles au stade 3
	if stage >= 2 then
		local fruitScale = if stage == 3 then 1 else 0.5
		local size = crop.FruitSize * fruitScale
		local color = if stage == 3 then crop.Color else crop.Color:Lerp(Color3.fromRGB(90, 190, 70), 0.5)
		local shape = Enum.PartType[crop.FruitShape] or Enum.PartType.Ball
		local fruitCFrame = ground * CFrame.new(0, stemHeight + size.Y / 2, 0)
		if shape == Enum.PartType.Cylinder then
			-- Le cylindre Roblox est orienté sur X : on le redresse
			fruitCFrame = ground * CFrame.new(0, stemHeight + size.X / 2, 0) * CFrame.Angles(0, 0, math.rad(90))
		end
		decoPart({
			Name = "Fruit",
			Shape = shape,
			Size = size,
			CFrame = fruitCFrame,
			Color = color,
			Material = Enum.Material.SmoothPlastic,
			Parent = model,
		})
	end

	-- Minuteur / état au-dessus de la plante (texte mis à jour par le client)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "StatusGui"
	billboard.Size = UDim2.fromScale(4, 1.2)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, stemHeight + 2.5, 0)
	billboard.MaxDistance = 60
	billboard.LightInfluence = 0
	billboard.Adornee = tile.Part
	billboard.Parent = model

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextStrokeTransparency = 0.3
	label.Parent = billboard

	if stage == 3 then
		label.Text = "✅ Prêt !"
		label.TextColor3 = Color3.fromRGB(120, 255, 120)
	else
		label.Text = ""
		label.TextColor3 = Color3.new(1, 1, 1)
		model:SetAttribute("ReadyAt", readyAt)
		CollectionService:AddTag(model, GROWING_TAG)
	end

	model.Parent = tile.Part
	return model
end

local function clearTileVisual(tile: Tile)
	if tile.Model then
		tile.Model:Destroy()
		tile.Model = nil
	end
	tile.Stage = 0
end

local function setTileUnlocked(tile: Tile, unlocked: boolean)
	tile.Part.Transparency = if unlocked then 0 else 1
	tile.Part.CanCollide = unlocked
	tile.Part.CanQuery = unlocked
	if not unlocked then
		tile.Prompt.Enabled = false
	end
end

-- Met à jour visuel + prompt d'une case selon les données du joueur.
local function renderTile(farm: Farm, tile: Tile, now: number)
	local plant = farm.Data.Plants[tile.Key]

	if not plant then
		clearTileVisual(tile)
		local seedId = selectedSeed[farm.Player]
		tile.Prompt.ActionText = if seedId then ("Planter : %s"):format(Config.Crops[seedId].DisplayName) else "Planter"
		tile.Prompt.ObjectText = "Terre"
		tile.Prompt.Enabled = true
		return
	end

	local stage = getStage(plant, now)
	if stage ~= tile.Stage then
		clearTileVisual(tile)
		tile.Model = buildPlantModel(tile, plant.CropId, stage, plant.ReadyAt)
		tile.Stage = stage
	end

	if stage == 3 then
		tile.Prompt.ActionText = "Récolter"
		tile.Prompt.ObjectText = CropUtil.Label(plant.CropId)
		tile.Prompt.Enabled = true
	else
		-- En pousse : engrais possible une fois, si le joueur a du fumier
		local manure = InventoryService:GetAmount(farm.Player, Config.Fertilizer.ItemId)
		if manure > 0 and not plant.Fertilized then
			tile.Prompt.ActionText = "Mettre de l'engrais"
			tile.Prompt.ObjectText = ("%s (x%d)"):format(ItemUtil.Label(Config.Fertilizer.ItemId), manure)
			tile.Prompt.Enabled = true
		else
			tile.Prompt.Enabled = false
		end
	end
end

local function renderFarm(farm: Farm)
	local now = os.time()
	local unlocked = FarmService:GetUnlockedTileCount(farm.Player)
	for _, tile in tilesByPlotId[farm.Plot.Id] do
		if tile.Index <= unlocked then
			renderTile(farm, tile, now)
		end
	end
end

--------------------------------------------------------------------------
-- Choix de la graine
--------------------------------------------------------------------------

local function setSelectedSeed(player: Player, cropId: string?)
	selectedSeed[player] = cropId
	SyncService:Set(player, "SelectedSeed", cropId)
	local farm = farms[player]
	if farm then
		renderFarm(farm) -- met à jour le texte "Planter : ..." des cases vides
	end
end

-- Renvoie la graine à planter : celle choisie si le joueur en a encore, sinon la première possédée.
local function resolveSeed(player: Player): string?
	local current = selectedSeed[player]
	if current and InventoryService:GetSeedCount(player, current) > 0 then
		return current
	end
	local fallback = InventoryService:GetFirstOwnedSeed(player)
	if fallback ~= current then
		setSelectedSeed(player, fallback)
	end
	return fallback
end

-- À appeler après un achat de graines : sélectionne automatiquement une graine si aucune ne l'était.
function FarmService:RefreshSeedSelection(player: Player)
	resolveSeed(player)
end

--------------------------------------------------------------------------
-- Planter / récolter
--------------------------------------------------------------------------

local function plantSeed(farm: Farm, tile: Tile)
	local player = farm.Player
	local cropId = resolveSeed(player)
	if not cropId then
		SyncService:Notify(player, "Tu n'as plus de graines ! Achète-en à la boutique 🌱", "Error")
		return
	end
	if not InventoryService:ConsumeSeed(player, cropId) then
		return
	end

	local now = os.time()
	farm.Data.Plants[tile.Key] = {
		CropId = cropId,
		PlantedAt = now,
		ReadyAt = now + FarmService:GetGrowTime(player, cropId),
	}
	renderTile(farm, tile, now)

	-- Plus de graines de ce type : on passe automatiquement à la suivante
	if InventoryService:GetSeedCount(player, cropId) <= 0 then
		resolveSeed(player)
	end
end

local function harvestTile(farm: Farm, tile: Tile)
	local player = farm.Player
	local plant = farm.Data.Plants[tile.Key]
	local now = os.time()
	if not plant or now < plant.ReadyAt then
		return -- pas encore mûre (le client ne devrait même pas voir le prompt)
	end
	if not InventoryService:HasRoom(player, 1) then
		SyncService:Notify(player, "Inventaire plein ! Va vendre au stand 💰", "Error")
		return
	end

	-- Phase 7 : tirage de mutation de plante ici (Dorée, Arc-en-ciel...)
	local variant = "Normal"
	if not InventoryService:AddItem(player, plant.CropId, variant, 1) then
		return
	end
	farm.Data.Stats.TotalHarvested += 1

	farm.Data.Plants[tile.Key] = nil
	renderTile(farm, tile, now)
	SyncService:Notify(player, ("+1 %s"):format(CropUtil.Label(plant.CropId)), "Success")
end

-- Fumier : retire une partie du temps de pousse restant (une seule fois par plante).
local function fertilizeTile(farm: Farm, tile: Tile)
	local player = farm.Player
	local plant = farm.Data.Plants[tile.Key]
	local now = os.time()
	if not plant or now >= plant.ReadyAt or plant.Fertilized then
		return
	end
	if InventoryService:RemoveAnyVariant(player, Config.Fertilizer.ItemId, 1) < 1 then
		SyncService:Notify(player, "Il te faut du fumier (produit par les chevaux) !", "Error")
		return
	end

	local remaining = plant.ReadyAt - now
	plant.ReadyAt = now + math.ceil(remaining * (1 - Config.Fertilizer.TimeReduction))
	plant.Fertilized = true
	if tile.Model then
		tile.Model:SetAttribute("ReadyAt", plant.ReadyAt) -- met à jour le minuteur client
	end
	renderTile(farm, tile, now)
	SyncService:Notify(player, ("Engrais ! -%s de pousse"):format(Format.Time(remaining - (plant.ReadyAt - now))), "Success")
end

local function onTileTriggered(plot: any, tile: Tile, player: Player)
	local farm = farms[player]
	if not farm or farm.Plot ~= plot then
		SyncService:Notify(player, "Ce n'est pas ta parcelle !", "Error")
		return
	end
	if tile.Index > FarmService:GetUnlockedTileCount(player) then
		return
	end
	if not RemoteGuard.IsNear(player, tile.Part.Position, FarmConfig.InteractDistance + 4) then
		return
	end
	if not RemoteGuard.CheckCooldown(player, "FarmAction", FarmConfig.ActionCooldown) then
		return
	end

	local plant = farm.Data.Plants[tile.Key]
	if not plant then
		plantSeed(farm, tile)
	elseif os.time() >= plant.ReadyAt then
		harvestTile(farm, tile)
	else
		fertilizeTile(farm, tile)
	end
end

--------------------------------------------------------------------------
-- Activation / désactivation d'une ferme
--------------------------------------------------------------------------

-- Appelé par PlotService quand le joueur a À LA FOIS sa parcelle et ses données.
local function activate(player: Player, plot: any, data: { [string]: any })
	if farms[player] then
		return
	end

	local farm: Farm = { Player = player, Plot = plot, Data = data }
	farms[player] = farm

	-- Nettoie les plantes sauvegardées invalides (culture supprimée de la config, case verrouillée...)
	local unlocked = FarmService:GetUnlockedTileCount(player)
	for key, plant in data.Plants do
		local index = tonumber(key)
		if type(plant) ~= "table" or not CropUtil.Get(plant.CropId) or not index or index > unlocked then
			data.Plants[key] = nil
		end
	end

	for _, tile in tilesByPlotId[plot.Id] do
		setTileUnlocked(tile, tile.Index <= unlocked)
	end

	resolveSeed(player)
	renderFarm(farm)
end

local function deactivate(player: Player, plot: any)
	farms[player] = nil
	selectedSeed[player] = nil
	for _, tile in tilesByPlotId[plot.Id] do
		clearTileVisual(tile)
		setTileUnlocked(tile, tile.Index <= FarmConfig.StartingTiles)
		tile.Prompt.Enabled = false
		tile.Prompt.ActionText = "Planter"
	end
end

-- Boucle de pousse : met à jour les stades une fois par seconde.
local function growthLoop()
	while true do
		task.wait(1)
		local now = os.time()
		for _, farm in farms do
			local unlocked = FarmService:GetUnlockedTileCount(farm.Player)
			for _, tile in tilesByPlotId[farm.Plot.Id] do
				local plant = farm.Data.Plants[tile.Key]
				if plant and tile.Index <= unlocked and getStage(plant, now) ~= tile.Stage then
					renderTile(farm, tile, now)
				end
			end
		end
	end
end

--------------------------------------------------------------------------
-- Construction des cases
--------------------------------------------------------------------------

local function buildTiles(plot: any)
	local folder = Instance.new("Folder")
	folder.Name = "Tiles"
	folder.Parent = plot.Model

	local columns, rows = FarmConfig.GridColumns, FarmConfig.GridRows
	local step = FarmConfig.TileSize + FarmConfig.TileGap
	local groundY = Config.Plots.BaseHeight / 2

	local tiles: { Tile } = {}
	for index = 1, columns * rows do
		local column = (index - 1) % columns
		local row = (index - 1) // columns -- rangée 0 = la plus proche de l'entrée
		local localX = (column - (columns - 1) / 2) * step
		local localZ = FarmConfig.GridStartZ + row * step -- +Z = vers le fond de la parcelle

		local part = makePart({
			Name = "Tile_" .. index,
			Size = Vector3.new(FarmConfig.TileSize, 0.4, FarmConfig.TileSize),
			CFrame = plot.CFrame * CFrame.new(localX, groundY + 0.2, localZ),
			Color = FarmConfig.SoilColor,
			Material = Enum.Material.Ground,
			Parent = folder,
		})
		part:SetAttribute("TileIndex", index)

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Planter"
		prompt.ObjectText = "Terre"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = FarmConfig.InteractDistance
		prompt.RequiresLineOfSight = false
		prompt.Enabled = false
		prompt:SetAttribute("OwnerOnly", true)
		prompt.Parent = part

		local tile: Tile = {
			Index = index,
			Key = tostring(index),
			Part = part,
			Prompt = prompt,
			Model = nil,
			Stage = 0,
		}
		prompt.Triggered:Connect(function(player: Player)
			onTileTriggered(plot, tile, player)
		end)

		setTileUnlocked(tile, index <= FarmConfig.StartingTiles)
		tiles[index] = tile
	end
	tilesByPlotId[plot.Id] = tiles
end

--------------------------------------------------------------------------
-- Cycle de vie
--------------------------------------------------------------------------

function FarmService:Init()
	for _, plot in PlotService:GetAllPlots() do
		buildTiles(plot)
	end

	PlotService:OnPlotReady(activate)
	PlotService:OnPlotReleased(deactivate)

	-- L'inventaire change (ex. fumier récupéré) : met à jour les prompts "engrais"
	InventoryService:OnItemsChanged(function(player)
		local farm = farms[player]
		if farm then
			renderFarm(farm)
		end
	end)
end

function FarmService:Start()
	-- Le client choisit sa graine dans la barre du bas
	Remotes.Get("SelectSeed").OnServerEvent:Connect(function(player: Player, cropId: any)
		if not RemoteGuard.CheckCooldown(player, "SelectSeed", 0.1) then
			return
		end
		if not CropUtil.Get(cropId) or InventoryService:GetSeedCount(player, cropId) <= 0 then
			return
		end
		setSelectedSeed(player, cropId)
	end)

	Players.PlayerRemoving:Connect(function(player)
		selectedSeed[player] = nil
	end)

	task.spawn(growthLoop)
end

return FarmService
