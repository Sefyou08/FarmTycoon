--[[
	FarmService.lua
	===============
	Champs, cases de terre, plantation, pousse (3 stades), engrais et récolte.

	Fonctionnement :
	  • Un CHAMP = un bloc de Config.Farm.FieldColumns x FieldRows cases, placé
	    librement avec le mode construction (PlacementService). Données :
	      data.Fields[fieldId] = { X, Z, Rot, Placed, Unlocked }
	    Unlocked = nombre de cases débloquées (elles se débloquent dans l'ordre).
	  • Le 1er champ est offert avec toutes ses cases. Les champs suivants
	    s'achètent dans le menu de construction ; leurs cases se débloquent une
	    par une (E sur la case), prix croissant (GetTileUnlockPrice).
	  • Chaque case a un ProximityPrompt géré PAR LE SERVEUR :
	      verrouillée -> "Débloquer : X Coins" (seulement la prochaine case du champ)
	      vide        -> "Planter : <graine choisie>"
	      pousse      -> "Mettre de l'engrais" si le joueur a du fumier, sinon masqué
	      mûre        -> "Récolter"
	  • Plantes : data.Plants["<fieldId>:<case>"] = { CropId, PlantedAt, ReadyAt, Fertilized }
	    (os.time) : elles continuent de pousser hors ligne, ou quand le champ est
	    rangé / déplacé (seuls les visuels sont reconstruits).
	  • Toute la validation est faite ici, côté serveur.

	API :
	  FarmService:GetGrowTime(player, cropId) -> secondes (multiplicateurs en phase 7/9)
	  FarmService:GetTileUnlockPrice(data) -> Coins
	  FarmService:CanBuyField(player) -> (prix | nil, raison)
	  FarmService:CreateField(player, x, z, rot) -> fieldId   (appelé par PlacementService après paiement)
	  FarmService:RefreshField(player, fieldId)               (reconstruit / retire le visuel)
	  FarmService:RefreshSeedSelection(player)
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CropUtil = require(ReplicatedStorage.Shared.CropUtil)
local ItemUtil = require(ReplicatedStorage.Shared.ItemUtil)
local Format = require(ReplicatedStorage.Shared.Format)
local PlacementUtil = require(ReplicatedStorage.Shared.PlacementUtil)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RemoteGuard = require(script.Parent.Parent.Util.RemoteGuard)
local CurrencyService = require(script.Parent.CurrencyService)
local SyncService = require(script.Parent.SyncService)
local PlotService = require(script.Parent.PlotService)
local InventoryService = require(script.Parent.InventoryService)
local XPService = require(script.Parent.XPService)

local FarmConfig = Config.Farm
local TILES_PER_FIELD = FarmConfig.FieldColumns * FarmConfig.FieldRows

local FarmService = {}

-- Tag posé sur les plantes en train de pousser : le client met à jour leur minuteur
local GROWING_TAG = "GrowingPlant"
local STAGE_SCALE = { 0.35, 0.65, 1 } -- taille de la plante par stade (petite, moyenne, mûre)

type Tile = {
	FieldId: string,
	Index: number,
	Key: string, -- clé de data.Plants : "<fieldId>:<index>"
	Part: Part,
	Prompt: ProximityPrompt,
	Model: Model?, -- visuel de la plante actuelle
	Stage: number, -- 0 = vide, 1..3 = stade affiché
}

type FieldVisual = {
	Model: Model,
	Tiles: { Tile },
}

type Farm = {
	Player: Player,
	Plot: any,
	Data: { [string]: any },
	Fields: { [string]: FieldVisual },
}

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

local function plantKey(fieldId: string, index: number): string
	return fieldId .. ":" .. index
end

function FarmService:GetGrowTime(_player: Player, cropId: string): number
	local crop = Config.Crops[cropId]
	-- Phase 7 (boosts) / phase 9 (game pass) appliqueront un multiplicateur ici
	return crop.GrowTime
end

local function totalUnlockedTiles(data: { [string]: any }): number
	local total = 0
	for _, field in data.Fields do
		total += field.Unlocked or 0
	end
	return total
end

function FarmService:GetTileUnlockPrice(data: { [string]: any }): number
	local extra = math.max(0, totalUnlockedTiles(data) - FarmConfig.StartingUnlockedTiles)
	return math.floor(FarmConfig.TileUnlockBase * FarmConfig.TileUnlockGrowth ^ extra)
end

local function countFields(data: { [string]: any }): number
	local count = 0
	for _ in data.Fields do
		count += 1
	end
	return count
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

-- Met à jour visuel + prompt d'une case selon les données du joueur.
local function renderTile(farm: Farm, tile: Tile, now: number)
	local field = farm.Data.Fields[tile.FieldId]
	if not field then
		return
	end

	-- Case verrouillée : seule la prochaine case du champ propose le déblocage
	if tile.Index > field.Unlocked then
		clearTileVisual(tile)
		tile.Part.Color = FarmConfig.LockedSoilColor
		tile.Part.Transparency = 0.35
		if tile.Index == field.Unlocked + 1 then
			tile.Prompt.ActionText = ("Débloquer : %s Coins"):format(Format.Number(FarmService:GetTileUnlockPrice(farm.Data)))
			tile.Prompt.ObjectText = "Case verrouillée"
			tile.Prompt.HoldDuration = 0.3
			tile.Prompt.Enabled = true
		else
			tile.Prompt.Enabled = false
		end
		return
	end

	tile.Part.Color = FarmConfig.SoilColor
	tile.Part.Transparency = 0
	tile.Prompt.HoldDuration = 0

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
	for _, visual in farm.Fields do
		for _, tile in visual.Tiles do
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
-- Actions sur une case
--------------------------------------------------------------------------

local function unlockTile(farm: Farm, tile: Tile)
	local player = farm.Player
	local field = farm.Data.Fields[tile.FieldId]
	if not field or tile.Index ~= field.Unlocked + 1 then
		return
	end
	local price = FarmService:GetTileUnlockPrice(farm.Data)
	if not CurrencyService:SpendCoins(player, price, "UnlockTile") then
		SyncService:Notify(player, ("Il te faut %s Coins pour débloquer cette case."):format(Format.Number(price)), "Error")
		return
	end
	field.Unlocked += 1
	renderFarm(farm) -- le prix de la case suivante change partout
	SyncService:Set(player, "Fields", farm.Data.Fields)
	SyncService:Notify(player, "Case débloquée ! 🌱", "Success")
end

local function plantSeed(farm: Farm, tile: Tile, silent: boolean?): boolean
	local player = farm.Player
	local cropId = resolveSeed(player)
	if not cropId then
		if not silent then
			SyncService:Notify(player, "Tu n'as plus de graines ! Achète-en à la boutique 🌱", "Error")
		end
		return false
	end
	if not InventoryService:ConsumeSeed(player, cropId) then
		return false
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
	return true
end

-- Mutation de plante à la récolte (Config.Farm.HarvestMutations), de la plus rare à la plus commune
local function rollHarvestMutation(cropId: string): string
	local crop = Config.Crops[cropId]
	local bonus = FarmConfig.HarvestMutationRarityBonus[crop.Rarity] or 1
	local roll = math.random()
	local cumulative = 0
	local variants = ItemUtil.SortedVariants()
	for i = #variants, 1, -1 do
		local chance = FarmConfig.HarvestMutations[variants[i]]
		if chance then
			cumulative += chance * bonus
			if roll < cumulative then
				return variants[i]
			end
		end
	end
	return "Normal"
end

-- Récolte une case mûre. silent = true pour le fermier PNJ (pas de notification pour les normales).
-- Renvoie true si la récolte a eu lieu.
local function harvestTile(farm: Farm, tile: Tile, silent: boolean?): boolean
	local player = farm.Player
	local plant = farm.Data.Plants[tile.Key]
	local now = os.time()
	if not plant or now < plant.ReadyAt then
		return false -- pas encore mûre (le client ne devrait même pas voir le prompt)
	end
	if not InventoryService:HasRoom(player, 1) then
		if not silent then
			SyncService:Notify(player, "Inventaire plein ! Va vendre au stand 💰", "Error")
		end
		return false
	end

	local variant = rollHarvestMutation(plant.CropId)
	if not InventoryService:AddItem(player, plant.CropId, variant, 1) then
		return false
	end
	farm.Data.Stats.TotalHarvested += 1
	local rarityRank = (Config.Rarities[Config.Crops[plant.CropId].Rarity] or Config.Rarities.Common).Order
	XPService:AddXP(player, Config.Progression.XP.Harvest * rarityRank)

	farm.Data.Plants[tile.Key] = nil
	renderTile(farm, tile, now)
	if variant ~= "Normal" then
		SyncService:Notify(player, ("✨ Mutation ! %s"):format(ItemUtil.Label(plant.CropId, variant)), "Mutation")
	elseif not silent then
		SyncService:Notify(player, ("+1 %s"):format(CropUtil.Label(plant.CropId)), "Success")
	end
	return true
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

local function onTileTriggered(farm: Farm, tile: Tile, player: Player)
	if farms[player] ~= farm then
		SyncService:Notify(player, "Ce n'est pas ta parcelle !", "Error")
		return
	end
	local field = farm.Data.Fields[tile.FieldId]
	if not field or not field.Placed then
		return
	end
	if not RemoteGuard.IsNear(player, tile.Part.Position, FarmConfig.InteractDistance + 4) then
		return
	end
	if not RemoteGuard.CheckCooldown(player, "FarmAction", FarmConfig.ActionCooldown) then
		return
	end

	if tile.Index > field.Unlocked then
		unlockTile(farm, tile)
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
-- Visuel d'un champ
--------------------------------------------------------------------------

local function destroyFieldVisual(farm: Farm, fieldId: string)
	local visual = farm.Fields[fieldId]
	if visual then
		visual.Model:Destroy()
		farm.Fields[fieldId] = nil
	end
end

local function buildFieldVisual(farm: Farm, fieldId: string)
	local field = farm.Data.Fields[fieldId]
	destroyFieldVisual(farm, fieldId)
	if not field or not field.Placed then
		return
	end

	local origin = PlotService:ToWorld(farm.Plot, 0, 0) * PlacementUtil.LocalCFrame(field.X, field.Z, field.Rot or 0)
	local model = Instance.new("Model")
	model.Name = "Field_" .. fieldId
	model:SetAttribute("PlaceType", "Field")
	model:SetAttribute("PlaceId", fieldId)

	-- Bordure de terre retournée sous le champ (repère visuel de l'emprise)
	local footprint = FarmConfig.FieldFootprint
	makePart({
		Name = "Border",
		Size = Vector3.new(footprint.X - 0.5, 0.2, footprint.Y - 0.5),
		CFrame = origin * CFrame.new(0, 0.1, 0),
		Color = Color3.fromRGB(85, 60, 35),
		Material = Enum.Material.Ground,
		Parent = model,
	})

	local columns, rows = FarmConfig.FieldColumns, FarmConfig.FieldRows
	local step = FarmConfig.TileSize + FarmConfig.TileGap
	local tiles: { Tile } = {}
	for index = 1, TILES_PER_FIELD do
		local column = (index - 1) % columns
		local row = (index - 1) // columns -- rangée 0 = côté entrée de la parcelle (à rotation 0)
		local localX = (column - (columns - 1) / 2) * step
		local localZ = (row - (rows - 1) / 2) * step

		local part = makePart({
			Name = "Tile_" .. index,
			Size = Vector3.new(FarmConfig.TileSize, 0.4, FarmConfig.TileSize),
			CFrame = origin * CFrame.new(localX, 0.4, localZ),
			Color = FarmConfig.SoilColor,
			Material = Enum.Material.Ground,
			Parent = model,
		})

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Planter"
		prompt.ObjectText = "Terre"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = FarmConfig.InteractDistance
		prompt.RequiresLineOfSight = false
		prompt.Enabled = false
		prompt:SetAttribute("OwnerOnly", true) -- masqué par le client sur les parcelles des autres
		prompt.Parent = part

		local tile: Tile = {
			FieldId = fieldId,
			Index = index,
			Key = plantKey(fieldId, index),
			Part = part,
			Prompt = prompt,
			Model = nil,
			Stage = 0,
		}
		prompt.Triggered:Connect(function(player: Player)
			onTileTriggered(farm, tile, player)
		end)
		tiles[index] = tile
	end

	model.Parent = farm.Plot.Model
	farm.Fields[fieldId] = { Model = model, Tiles = tiles }

	local now = os.time()
	for _, tile in tiles do
		renderTile(farm, tile, now)
	end
end

--------------------------------------------------------------------------
-- API pour le mode construction (PlacementService)
--------------------------------------------------------------------------

-- Tournée du fermier PNJ : récolte les plantes mûres puis replante les cases vides,
-- dans la limite de maxActions. Renvoie (récoltes, plantations).
function FarmService:AutoFarm(player: Player, maxActions: number): (number, number)
	local farm = farms[player]
	if not farm then
		return 0, 0
	end
	local harvested, planted, actions = 0, 0, 0
	local now = os.time()
	-- 1. Récoltes
	for fieldId, visual in farm.Fields do
		local field = farm.Data.Fields[fieldId]
		for _, tile in visual.Tiles do
			if actions >= maxActions then
				return harvested, planted
			end
			local plant = farm.Data.Plants[tile.Key]
			if field and tile.Index <= field.Unlocked and plant and now >= plant.ReadyAt then
				if harvestTile(farm, tile, true) then
					harvested += 1
					actions += 1
				else
					break -- inventaire plein
				end
			end
		end
	end
	-- 2. Plantations
	for fieldId, visual in farm.Fields do
		local field = farm.Data.Fields[fieldId]
		for _, tile in visual.Tiles do
			if actions >= maxActions then
				return harvested, planted
			end
			if field and tile.Index <= field.Unlocked and not farm.Data.Plants[tile.Key] then
				if plantSeed(farm, tile, true) then
					planted += 1
					actions += 1
				else
					return harvested, planted -- plus de graines
				end
			end
		end
	end
	return harvested, planted
end

function FarmService:CanBuyField(player: Player): (number?, string?)
	local farm = farms[player]
	if not farm then
		return nil, "Ta ferme n'est pas encore prête."
	end
	local owned = countFields(farm.Data)
	local level = PlotService:GetLevel(player)
	if owned >= FarmConfig.MaxFieldsByLevel[level] then
		return nil, "Agrandis ta parcelle pour acheter plus de champs."
	end
	local price = FarmConfig.FieldPrices[owned + 1]
	if not price then
		return nil, "Nombre maximum de champs atteint."
	end
	return price, nil
end

function FarmService:CreateField(player: Player, x: number, z: number, rot: number, unlocked: number?): string?
	local farm = farms[player]
	if not farm then
		return nil
	end
	local n = 1
	while farm.Data.Fields["F" .. n] do
		n += 1
	end
	local fieldId = "F" .. n
	farm.Data.Fields[fieldId] = { X = x, Z = z, Rot = rot, Placed = true, Unlocked = unlocked or 0 }
	buildFieldVisual(farm, fieldId)
	SyncService:Set(player, "Fields", farm.Data.Fields)
	return fieldId
end

function FarmService:RefreshField(player: Player, fieldId: string)
	local farm = farms[player]
	if farm then
		buildFieldVisual(farm, fieldId)
		SyncService:Set(player, "Fields", farm.Data.Fields)
	end
end

--------------------------------------------------------------------------
-- Activation / désactivation d'une ferme
--------------------------------------------------------------------------

-- Convertit les anciennes sauvegardes (cases "1".."6" de la grille fixe) en 1er champ,
-- et nettoie les données invalides.
local function migrate(data: { [string]: any })
	if type(data.Fields) ~= "table" then
		data.Fields = {}
	end
	if next(data.Fields) == nil then
		local default = FarmConfig.DefaultFieldPosition
		data.Fields.F1 = { X = default.X, Z = default.Z, Rot = 0, Placed = true, Unlocked = FarmConfig.StartingUnlockedTiles }
		-- On collecte d'abord (ajouter des clés pendant un parcours n'est pas sûr en Lua)
		local legacy = {}
		for key, plant in data.Plants do
			local index = tonumber(key)
			if index then
				legacy[index] = plant
			end
		end
		for index, plant in legacy do
			data.Plants[tostring(index)] = nil
			if index >= 1 and index <= TILES_PER_FIELD then
				data.Plants[plantKey("F1", index)] = plant
			end
		end
	end

	for fieldId, field in data.Fields do
		if type(field) ~= "table" then
			data.Fields[fieldId] = nil
			continue
		end
		field.Unlocked = math.clamp(math.floor(tonumber(field.Unlocked) or 0), 0, TILES_PER_FIELD)
		field.Rot = math.clamp(math.floor(tonumber(field.Rot) or 0), 0, 3)
		field.X = tonumber(field.X) or 0
		field.Z = tonumber(field.Z) or FarmConfig.DefaultFieldPosition.Z
		field.Placed = field.Placed ~= false
	end

	for key, plant in data.Plants do
		local fieldId, indexText = string.match(key, "^(.+):(%d+)$")
		local index = tonumber(indexText)
		local field = fieldId and data.Fields[fieldId]
		if type(plant) ~= "table" or not CropUtil.Get(plant.CropId) or not field or not index or index > field.Unlocked then
			data.Plants[key] = nil
		end
	end
end

-- Appelé par PlotService quand le joueur a À LA FOIS sa parcelle et ses données.
local function activate(player: Player, plot: any, data: { [string]: any })
	if farms[player] then
		return
	end
	migrate(data)

	local farm: Farm = { Player = player, Plot = plot, Data = data, Fields = {} }
	farms[player] = farm

	for fieldId in data.Fields do
		buildFieldVisual(farm, fieldId)
	end
	SyncService:Set(player, "Fields", data.Fields) -- le mode construction du client en a besoin
	resolveSeed(player)
	renderFarm(farm)
end

local function deactivate(player: Player, _plot: any)
	local farm = farms[player]
	farms[player] = nil
	selectedSeed[player] = nil
	if farm then
		for fieldId in farm.Fields do
			destroyFieldVisual(farm, fieldId)
		end
	end
end

-- Boucle de pousse : met à jour les stades une fois par seconde.
local function growthLoop()
	while true do
		task.wait(1)
		local now = os.time()
		for _, farm in farms do
			for _, visual in farm.Fields do
				for _, tile in visual.Tiles do
					local plant = farm.Data.Plants[tile.Key]
					if plant and getStage(plant, now) ~= tile.Stage then
						renderTile(farm, tile, now)
					end
				end
			end
		end
	end
end

--------------------------------------------------------------------------
-- Cycle de vie
--------------------------------------------------------------------------

function FarmService:Init()
	PlotService:OnPlotReady(activate)
	PlotService:OnPlotReleased(deactivate)

	-- L'inventaire change (ex. fumier récupéré) : met à jour les prompts "engrais"
	InventoryService:OnItemsChanged(function(player)
		local farm = farms[player]
		if farm then
			renderFarm(farm)
		end
	end)
	-- Les Coins changent : rien à faire (le prix d'une case dépend du nombre de cases, pas des Coins)
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
