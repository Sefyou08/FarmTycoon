--[[
	AnimalService.lua
	=================
	Enclos et animaux de ferme.

	  • Les enclos s'achètent et se placent avec le mode construction (PlacementService).
	    Prix croissant (Config.Pens.Prices), nombre max selon le niveau de parcelle
	    (Config.Pens.MaxByLevel). Position dans data.Pens[key] : X, Z, Rot, Placed.
	    Déplacer / ranger un enclos ne fait rien perdre (animaux, rations, caisse).
	  • Un enclos = UNE espèce, jusqu'à Config.Pens.Capacity animaux.
	  • Mangeoire : on y met des récoltes acceptées par l'espèce (Config.Animals.Diet),
	    qui donnent des rations (Config.Crops.FeedValue).
	  • Production : chaque animal accumule du temps (x vitesse de sa variante) ;
	    à chaque cycle complet il produit 1 ressource et consomme des rations.
	    Sans rations ou caisse pleine : il attend.
	  • Caisse : la production s'accumule (Config.Pens.StorageCapacity), on la
	    récupère avec E. Les ressources gardent la VARIANTE de l'animal.
	  • Hors ligne : à la connexion, on simule le temps écoulé (plafonné).
	  • Toute la validation est faite ici (propriétaire, distance, cooldown, Coins).

	API (utilisée par AnimalShopService et PlacementService) :
	  AnimalService:FindPenFor(player, speciesId) -> penKey | nil, raisonSiNil
	  AnimalService:CanBuyPen(player) -> (prix | nil, raison)
	  AnimalService:CreatePen(player, x, z, rot) -> penKey
	  AnimalService:RefreshPen(player, penKey)  (reconstruit / retire le visuel)
	  AnimalService:RollVariant() -> variantId
	  AnimalService:AddAnimal(player, penKey, speciesId, variantId) -> boolean
	  AnimalService:GetProductionMultiplier(player) -> number (phase 7/8)
]]

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ItemUtil = require(ReplicatedStorage.Shared.ItemUtil)
local PlacementUtil = require(ReplicatedStorage.Shared.PlacementUtil)
local CosmeticUtil = require(ReplicatedStorage.Shared.CosmeticUtil)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RemoteGuard = require(script.Parent.Parent.Util.RemoteGuard)
local PatternBuilder = require(script.Parent.Parent.Util.PatternBuilder)
local AnimalBuilder = require(script.Parent.Parent.Util.AnimalBuilder)
local GameEvents = require(script.Parent.Parent.Util.GameEvents)
local DataService = require(script.Parent.DataService)
local SyncService = require(script.Parent.SyncService)
local PlotService = require(script.Parent.PlotService)
local InventoryService = require(script.Parent.InventoryService)
local XPService = require(script.Parent.XPService)
local BoostService = require(script.Parent.BoostService)

local PenConfig = Config.Pens

local AnimalService = {}

local ANIMAL_TAG = "FarmAnimal" -- le client fait se promener ces modèles

type PenVisual = {
	Folder: Model,
	Center: CFrame,
	TroughPrompt: ProximityPrompt,
	CratePrompt: ProximityPrompt,
	InfoLabel: TextLabel,
	Animals: { [string]: Model },
}

type State = {
	Player: Player,
	Plot: any,
	Data: { [string]: any },
	Visuals: { [string]: PenVisual },
}

local states: { [Player]: State } = {}

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

local function decoPart(props: { [string]: any }): Part
	props.CanCollide = false
	props.CanQuery = false
	props.CanTouch = false
	return makePart(props)
end

local function makeBillboard(parent: Instance, size: Vector2, offset: Vector3, maxDistance: number): (BillboardGui, TextLabel)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(size.X, size.Y)
	gui.StudsOffsetWorldSpace = offset
	gui.MaxDistance = maxDistance
	gui.LightInfluence = 0
	gui.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Parent = gui
	return gui, label
end

local function makePrompt(parent: Instance, actionText: string, objectText: string): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = PenConfig.InteractDistance
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OwnerOnly", true) -- masqué par le client sur les parcelles des autres
	prompt.Parent = parent
	return prompt
end

local function storageTotal(pen: { [string]: any }): number
	local total = 0
	for _, count in pen.Storage do
		total += count
	end
	return total
end

local function countBuiltPens(data: { [string]: any }): number
	local count = 0
	for _ in data.Pens do
		count += 1
	end
	return count
end

local function sortedPenKeys(data: { [string]: any }): { string }
	local keys = {}
	for key in data.Pens do
		table.insert(keys, key)
	end
	table.sort(keys, function(a, b)
		return (tonumber(a) or 0) < (tonumber(b) or 0)
	end)
	return keys
end

local function syncPens(state: { [string]: any })
	SyncService:Set(state.Player, "Pens", state.Data.Pens)
end

-- Boost "Production" (Developer Product) : animaux plus rapides
function AnimalService:GetProductionMultiplier(player: Player): number
	return BoostService:GetMultiplier(player, "Production")
end

--------------------------------------------------------------------------
-- Production (simulation, utilisée en jeu ET pour le hors-ligne)
--------------------------------------------------------------------------

-- Variante juste au-dessus (Normal -> Gold -> Rainbow -> Legendary -> Mythic, plafonnée)
local function nextVariant(variantId: string): string
	local variants = ItemUtil.SortedVariants()
	local index = table.find(variants, variantId) or 1
	return variants[math.min(index + 1, #variants)]
end

-- Fait avancer la production de l'enclos jusqu'à `now`. Renvoie le nombre de ressources produites.
-- Chaque ressource a une petite chance d'être d'une variante supérieure (Config.Pens.RareProduceChance).
local function simulate(pen: { [string]: any }, now: number, multiplier: number): number
	local elapsed = math.clamp(now - (pen.LastUpdate or now), 0, PenConfig.MaxOfflineSeconds)
	pen.LastUpdate = now
	local species = pen.Species and Config.Animals[pen.Species]
	if elapsed <= 0 or not species or #pen.Animals == 0 then
		return 0
	end

	local cycle = species.ProductionTime
	local produced = 0
	for _, animal in pen.Animals do
		local variant = ItemUtil.GetVariant(animal.Variant)
		animal.Progress = (animal.Progress or 0) + elapsed * variant.SpeedMultiplier * multiplier

		local ready = math.floor(animal.Progress / cycle)
		if ready > 0 then
			local byFeed = math.floor(pen.Feed / species.FeedPerProduct)
			local bySpace = PenConfig.StorageCapacity - storageTotal(pen)
			local count = math.max(0, math.min(ready, byFeed, bySpace))

			if count > 0 then
				pen.Feed -= count * species.FeedPerProduct
				-- Ressources rares : tirage pour chaque ressource produite
				local upgradeChance = PenConfig.RareProduceChance[animal.Variant] or 0
				local upgraded = 0
				if upgradeChance > 0 then
					for _ = 1, count do
						if math.random() < upgradeChance then
							upgraded += 1
						end
					end
				end
				if count - upgraded > 0 then
					pen.Storage[animal.Variant] = (pen.Storage[animal.Variant] or 0) + count - upgraded
				end
				if upgraded > 0 then
					local better = nextVariant(animal.Variant)
					pen.Storage[better] = (pen.Storage[better] or 0) + upgraded
				end
				produced += count
			end

			animal.Progress -= count * cycle
			if count < ready then
				-- Bloqué (faim ou caisse pleine) : l'animal attend, prêt à produire dès que possible
				animal.Progress = math.min(animal.Progress, cycle)
			end
		end
	end
	return produced
end

--------------------------------------------------------------------------
-- Visuels des animaux (Parts simples, à remplacer par de vrais modèles plus tard)
--------------------------------------------------------------------------

local function buildAnimalModel(speciesId: string, variantId: string, groundCFrame: CFrame): Model
	-- Modèle cartoon (AnimalBuilder, phase 10) ou modèle à toi (CustomModels/Animals)
	local species = Config.Animals[speciesId]
	local variant = ItemUtil.GetVariant(variantId)
	local model = AnimalBuilder.Build(speciesId, variantId, groundCFrame)
	local bodyPart = model.PrimaryPart :: BasePart

	-- Nom au-dessus de l'animal ("Vache Dorée")
	local adjective = ItemUtil.VariantAdjective(species, variantId)
	local _, nameLabel = makeBillboard(bodyPart, Vector2.new(6, 1.1), Vector3.new(0, species.BodySize.Y / 2 + species.HeadSize.Y + 1.2, 0), 45)
	nameLabel.Text = species.DisplayName .. (if adjective ~= "" then " " .. adjective else "")
	nameLabel.TextColor3 = if variantId == "Normal" then Color3.new(1, 1, 1) else variant.Color
	return model
end

-- Utilisé par la vitrine de prestige (DisplayService) : même modèle, sans promenade
function AnimalService:BuildAnimalModel(speciesId: string, variantId: string, groundCFrame: CFrame): Model
	return buildAnimalModel(speciesId, variantId, groundCFrame)
end

--------------------------------------------------------------------------
-- Visuels des enclos
--------------------------------------------------------------------------

-- Cosmétique "Chapeaux des animaux" : un petit accessoire posé sur la tête
local function addHat(model: Model, hat: any)
	local head = model:FindFirstChild("Head") :: BasePart?
	if not hat or not hat.Shape or not head then
		return
	end
	local top = head.CFrame * CFrame.new(0, head.Size.Y / 2, 0)
	local function hatPart(name: string, shape: Enum.PartType, size: Vector3, offset: CFrame, material: Enum.Material?)
		local p = Instance.new("Part")
		p.Name = name
		p.Shape = shape
		p.Size = size
		p.CFrame = top * offset
		p.Color = hat.Color
		p.Material = material or Enum.Material.SmoothPlastic
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		-- Le chapeau suit le hochement de la tête (animation client)
		if head:GetAttribute("Anim") == "Head" then
			p:SetAttribute("Anim", "Head")
			p:SetAttribute("Hinge", model:GetPivot():VectorToObjectSpace(head.Position - p.Position) + (head:GetAttribute("Hinge") or Vector3.zero))
		end
		p.Parent = model
	end
	local w = head.Size.X
	if hat.Shape == "Hat" then
		hatPart("HatBrim", Enum.PartType.Cylinder, Vector3.new(0.1, w * 1.6, w * 1.6), CFrame.new(0, 0.05, 0) * CFrame.Angles(0, 0, math.rad(90)))
		hatPart("HatTop", Enum.PartType.Cylinder, Vector3.new(w * 0.5, w * 0.8, w * 0.8), CFrame.new(0, w * 0.25, 0) * CFrame.Angles(0, 0, math.rad(90)))
	elseif hat.Shape == "Ring" then
		for i = 1, 6 do
			local angle = i / 6 * math.pi * 2
			hatPart("Flower", Enum.PartType.Ball, Vector3.one * w * 0.3, CFrame.new(math.cos(angle) * w * 0.4, 0.1, math.sin(angle) * w * 0.4))
		end
	elseif hat.Shape == "Cone" then
		hatPart("PartyHat", Enum.PartType.Block, Vector3.new(w * 0.45, w * 0.9, w * 0.45), CFrame.new(0, w * 0.45, 0) * CFrame.Angles(0, math.rad(45), 0))
	elseif hat.Shape == "Crown" then
		for i = 1, 5 do
			local angle = i / 5 * math.pi * 2
			hatPart("Crown", Enum.PartType.Block, Vector3.new(w * 0.15, w * 0.35, w * 0.15), CFrame.new(math.cos(angle) * w * 0.35, w * 0.17, math.sin(angle) * w * 0.35), Enum.Material.Foil)
		end
	end
end

local function spawnAnimalVisual(state: State, key: string, animal: { [string]: any })
	local visual = state.Visuals[key]
	local pen = state.Data.Pens[key]
	if not visual or not pen or not pen.Species or visual.Animals[animal.Id] then
		return
	end
	local radius = PenConfig.Size / 2 - 3
	local angle = math.random() * math.pi * 2
	local distance = math.random() * radius
	local ground = visual.Center * CFrame.new(math.cos(angle) * distance, 0, math.sin(angle) * distance) * CFrame.Angles(0, math.random() * math.pi * 2, 0)

	local model = buildAnimalModel(pen.Species, animal.Variant, ground)
	addHat(model, CosmeticUtil.Equipped(state.Data, "AnimalHat"))
	model:SetAttribute("WanderCenter", visual.Center.Position)
	model:SetAttribute("WanderRadius", radius)
	model.Parent = visual.Folder
	CollectionService:AddTag(model, ANIMAL_TAG)
	visual.Animals[animal.Id] = model
end

-- Met à jour le panneau et les prompts de l'enclos (seulement si le texte change).
local function updatePenInfo(state: State, key: string)
	local visual = state.Visuals[key]
	local pen = state.Data.Pens[key]
	if not visual or not pen then
		return
	end

	local text
	local species = pen.Species and Config.Animals[pen.Species]
	if not species then
		text = "Enclos vide\nAchète un animal au stand 🐄 ANIMAUX"
		visual.TroughPrompt.Enabled = false
		visual.CratePrompt.Enabled = false
	else
		local resource = Config.Resources[species.Resource]
		local stored = storageTotal(pen)
		local feedLine = if pen.Feed < species.FeedPerProduct
			then "⚠️ Faim ! Remplis la mangeoire"
			else ("🍽️ Rations %d/%d"):format(pen.Feed, PenConfig.FeedCapacity)
		text = ("%s %s  %d/%d\n%s %d/%d   •   %s"):format(
			species.Icon,
			species.DisplayName,
			#pen.Animals,
			PenConfig.Capacity,
			resource.Icon,
			stored,
			PenConfig.StorageCapacity,
			feedLine
		)

		local trough = visual.TroughPrompt
		trough.Enabled = true
		local troughText = ("Mangeoire %d/%d"):format(pen.Feed, PenConfig.FeedCapacity)
		if trough.ObjectText ~= troughText then
			trough.ObjectText = troughText
		end

		local crate = visual.CratePrompt
		crate.Enabled = stored > 0
		local crateText = ("%s x%d"):format(ItemUtil.Label(species.Resource), stored)
		if crate.ObjectText ~= crateText then
			crate.ObjectText = crateText
		end
	end

	if visual.InfoLabel.Text ~= text then
		visual.InfoLabel.Text = text
	end
end

local onTroughTriggered: (State, string, Player) -> ()
local onCrateTriggered: (State, string, Player) -> ()

local function destroyPenVisual(state: State, key: string)
	local visual = state.Visuals[key]
	if visual then
		visual.Folder:Destroy()
		state.Visuals[key] = nil
	end
end

-- (Re)construit le visuel d'un enclos à sa position sauvegardée (rien si rangé).
local function buildPenVisual(state: State, key: string)
	destroyPenVisual(state, key)
	local pen = state.Data.Pens[key]
	if not pen or not pen.Placed then
		return
	end

	local size = PenConfig.Size
	-- Repère de l'emprise ; la clôture est au fond, la mangeoire et la caisse devant (-Z)
	local origin = PlotService:ToWorld(state.Plot, 0, 0) * PlacementUtil.LocalCFrame(pen.X, pen.Z, pen.Rot or 0)
	local center = origin * CFrame.new(0, 0, 2)

	local folder = Instance.new("Model")
	folder.Name = "Pen_" .. key
	folder:SetAttribute("PlaceType", "Pen")
	folder:SetAttribute("PlaceId", key)

	-- Sol en paille
	makePart({
		Name = "Floor",
		Size = Vector3.new(size - 1, 0.1, size - 1),
		CFrame = center * CFrame.new(0, 0.05, 0),
		Color = Color3.fromRGB(215, 190, 110),
		Material = Enum.Material.Grass,
		CanCollide = false,
		Parent = folder,
	})

	-- Clôtures basses (on peut sauter par-dessus) + poteaux d'angle
	local half = size / 2
	local fenceHeight = 1.6
	-- Cosmétique "Clôtures d'enclos"
	local skin = CosmeticUtil.Equipped(state.Data, "PenSkin")
	local fenceColor = if skin and skin.Color then skin.Color else Color3.fromRGB(150, 105, 60)
	local fenceMaterial = if skin and skin.Material then skin.Material else Enum.Material.Wood
	for _, side in {
		{ Vector3.new(size, 0.3, 0.3), Vector3.new(0, 0, -half) },
		{ Vector3.new(size, 0.3, 0.3), Vector3.new(0, 0, half) },
		{ Vector3.new(0.3, 0.3, size), Vector3.new(-half, 0, 0) },
		{ Vector3.new(0.3, 0.3, size), Vector3.new(half, 0, 0) },
	} do
		for _, y in { 0.6, 1.3 } do
			makePart({
				Name = "Rail",
				Size = side[1],
				CFrame = center * CFrame.new(side[2] + Vector3.new(0, y, 0)),
				Color = fenceColor,
				Material = fenceMaterial,
				Parent = folder,
			})
		end
	end
	-- Motif cosmétique : un panneau décoré entre les barres de chaque côté (phase 10)
	if skin and skin.Pattern then
		for _, side in {
			{ Vector3.new(size, 0.9, 0.15), Vector3.new(0, 0.95, -half), Enum.NormalId.Front },
			{ Vector3.new(size, 0.9, 0.15), Vector3.new(0, 0.95, half), Enum.NormalId.Back },
			{ Vector3.new(0.15, 0.9, size), Vector3.new(-half, 0.95, 0), Enum.NormalId.Left },
			{ Vector3.new(0.15, 0.9, size), Vector3.new(half, 0.95, 0), Enum.NormalId.Right },
		} do
			local panel = makePart({
				Name = "Panel",
				Size = side[1],
				CFrame = center * CFrame.new(side[2]),
				Color = fenceColor,
				Material = fenceMaterial,
				Parent = folder,
			})
			PatternBuilder.Apply(panel, side[3], skin.Pattern, { Parent = folder, Spacing = 2, Size = 0.8, MaxCount = 10, Color = skin.PatternColor, Accent = skin.PatternAccent })
		end
	end
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			makePart({
				Name = "Post",
				Size = Vector3.new(0.5, fenceHeight, 0.5),
				CFrame = center * CFrame.new(sx * half, fenceHeight / 2, sz * half),
				Color = fenceColor,
				Material = fenceMaterial,
				Parent = folder,
			})
		end
	end

	-- Mangeoire et caisse devant l'enclos
	local trough = makePart({
		Name = "Trough",
		Size = Vector3.new(5, 1, 1.6),
		CFrame = origin * CFrame.new(-4, 0.5, -10.5),
		Color = Color3.fromRGB(120, 80, 45),
		Material = Enum.Material.WoodPlanks,
		Parent = folder,
	})
	decoPart({
		Name = "Hay",
		Size = Vector3.new(4.6, 0.1, 1.2),
		CFrame = trough.CFrame * CFrame.new(0, 0.5, 0),
		Color = Color3.fromRGB(230, 200, 90),
		Material = Enum.Material.Grass,
		Parent = folder,
	})
	local crate = makePart({
		Name = "Crate",
		Size = Vector3.new(2.2, 2.2, 2.2),
		CFrame = origin * CFrame.new(4, 1.1, -10.5),
		Color = Color3.fromRGB(170, 120, 70),
		Material = Enum.Material.WoodPlanks,
		Parent = folder,
	})

	-- Panneau d'infos au-dessus de l'enclos
	local anchor = decoPart({
		Name = "InfoAnchor",
		Size = Vector3.new(1, 1, 1),
		CFrame = center * CFrame.new(0, 6, 0),
		Transparency = 1,
		Parent = folder,
	})
	local _, infoLabel = makeBillboard(anchor, Vector2.new(14, 3.2), Vector3.zero, 90)

	local visual: PenVisual = {
		Folder = folder,
		Center = center,
		TroughPrompt = makePrompt(trough, "Nourrir", "Mangeoire"),
		CratePrompt = makePrompt(crate, "Récupérer", "Caisse"),
		InfoLabel = infoLabel,
		Animals = {},
	}
	visual.TroughPrompt.Triggered:Connect(function(player)
		onTroughTriggered(state, key, player)
	end)
	visual.CratePrompt.Triggered:Connect(function(player)
		onCrateTriggered(state, key, player)
	end)

	state.Visuals[key] = visual
	folder.Parent = state.Plot.Model

	for _, animal in pen.Animals do
		spawnAnimalVisual(state, key, animal)
	end
	updatePenInfo(state, key)
end

--------------------------------------------------------------------------
-- Actions des joueurs (toutes validées ici)
--------------------------------------------------------------------------

-- Vérifie propriétaire + distance + cooldown. Renvoie l'état si tout est bon.
local function validate(state: State, player: Player, part: BasePart, action: string): boolean
	if states[player] ~= state then
		SyncService:Notify(player, "Ce n'est pas ta ferme !", "Error")
		return false
	end
	if not RemoteGuard.IsNear(player, part.Position, PenConfig.InteractDistance + 4) then
		return false
	end
	return RemoteGuard.CheckCooldown(player, action, 0.3)
end

-- Remplit la mangeoire avec les récoltes acceptées (ordre de préférence). Renvoie les rations ajoutées.
-- silent = true pour le soigneur PNJ (pas de notification).
local function feedPen(state: State, key: string, player: Player, silent: boolean?): number
	local pen = state.Data.Pens[key]
	local species = pen and pen.Species and Config.Animals[pen.Species]
	if not species then
		return 0
	end
	simulate(pen, os.time(), AnimalService:GetProductionMultiplier(player))
	local needed = PenConfig.FeedCapacity - pen.Feed
	if needed <= 0 then
		if not silent then
			SyncService:Notify(player, "La mangeoire est pleine.", "Info")
		end
		return 0
	end

	local given, parts = 0, {}
	local hasAcceptedFood = false
	for _, cropId in species.Diet do
		local feedValue = Config.Crops[cropId].FeedValue
		local available = InventoryService:GetAmount(player, cropId)
		if available > 0 then
			hasAcceptedFood = true
		end
		local take = math.min(available, needed // feedValue)
		if take > 0 then
			local removed = InventoryService:RemoveAnyVariant(player, cropId, take)
			pen.Feed += removed * feedValue
			needed -= removed * feedValue
			given += removed * feedValue
			table.insert(parts, ("%d %s"):format(removed, ItemUtil.Label(cropId)))
		end
	end

	if not silent then
		if given > 0 then
			GameEvents.Fire(player, "Feed")
			SyncService:Notify(player, ("+%d rations (%s)"):format(given, table.concat(parts, ", ")), "Success")
		elseif hasAcceptedFood then
			SyncService:Notify(player, "La mangeoire est presque pleine.", "Info")
		else
			local names = {}
			for _, cropId in species.Diet do
				table.insert(names, ItemUtil.Label(cropId))
			end
			SyncService:Notify(player, ("%s mange : %s. Récolte-en d'abord !"):format(species.DisplayName, table.concat(names, ", ")), "Error")
		end
	end
	updatePenInfo(state, key)
	return given
end

-- Ramasse la caisse (variantes les plus rares d'abord). Renvoie le nombre de ressources ramassées.
local function collectPen(state: State, key: string, player: Player, silent: boolean?): number
	local pen = state.Data.Pens[key]
	local species = pen and pen.Species and Config.Animals[pen.Species]
	if not species then
		return 0
	end
	simulate(pen, os.time(), AnimalService:GetProductionMultiplier(player))
	if storageTotal(pen) <= 0 then
		if not silent then
			SyncService:Notify(player, "Rien à récupérer pour l'instant.", "Info")
		end
		return 0
	end
	local space = InventoryService:GetFreeSpace(player)
	if space <= 0 then
		if not silent then
			SyncService:Notify(player, "Inventaire plein ! Va vendre au stand 💰", "Error")
		end
		return 0
	end

	local collected, parts = 0, {}
	local rare = false
	local variants = ItemUtil.SortedVariants()
	for i = #variants, 1, -1 do
		local variant = variants[i]
		local count = pen.Storage[variant] or 0
		local take = math.min(count, space - collected)
		if take > 0 and InventoryService:AddItem(player, species.Resource, variant, take) then
			pen.Storage[variant] = if count - take > 0 then count - take else nil
			collected += take
			rare = rare or variant ~= "Normal"
			table.insert(parts, ("%d %s"):format(take, ItemUtil.Label(species.Resource, variant)))
		end
	end

	if collected > 0 then
		XPService:AddXP(player, Config.Progression.XP.AnimalProduct * collected)
		-- Le soigneur PNJ ne prévient que pour les ressources rares
		if not silent or rare then
			SyncService:Notify(player, "+" .. table.concat(parts, ", "), if rare then "Rare" else "Success")
		end
	end
	updatePenInfo(state, key)
	return collected
end

onTroughTriggered = function(state: State, key: string, player: Player)
	local visual = state.Visuals[key]
	if visual and validate(state, player, visual.TroughPrompt.Parent :: BasePart, "FeedPen") then
		feedPen(state, key, player, false)
	end
end

onCrateTriggered = function(state: State, key: string, player: Player)
	local visual = state.Visuals[key]
	if visual and validate(state, player, visual.CratePrompt.Parent :: BasePart, "CollectPen") then
		collectPen(state, key, player, false)
	end
end

-- Tournée du soigneur PNJ : nourrit et ramasse jusqu'à maxPens enclos posés.
-- Renvoie (rations données, ressources ramassées).
function AnimalService:AutoCare(player: Player, maxPens: number): (number, number)
	local state = states[player]
	if not state then
		return 0, 0
	end
	local fed, collected, done = 0, 0, 0
	for _, key in sortedPenKeys(state.Data) do
		local pen = state.Data.Pens[key]
		if done >= maxPens then
			break
		end
		if pen.Placed and pen.Species then
			collected += collectPen(state, key, player, true)
			fed += feedPen(state, key, player, true)
			done += 1
		end
	end
	return fed, collected
end

--------------------------------------------------------------------------
-- API pour la boutique d'animaux
--------------------------------------------------------------------------

-- Enclos où placer un nouvel animal : un enclos de la même espèce avec de la place,
-- sinon un enclos vide. Renvoie (clé, nil) ou (nil, raison).
function AnimalService:FindPenFor(player: Player, speciesId: string): (string?, string?)
	local state = states[player]
	if not state then
		return nil, "Ta ferme n'est pas encore prête."
	end
	local emptyKey = nil
	for _, key in sortedPenKeys(state.Data) do
		local pen = state.Data.Pens[key]
		if pen.Placed then
			if pen.Species == speciesId and #pen.Animals < PenConfig.Capacity then
				return key, nil
			elseif pen.Species == nil and not emptyKey then
				emptyKey = key
			end
		end
	end
	if emptyKey then
		return emptyKey, nil
	end
	if countBuiltPens(state.Data) == 0 then
		return nil, "Construis d'abord un enclos : bouton 🔨 Construire !"
	end
	return nil, "Pas de place : construis (ou place) un enclos pour cette espèce."
end

-- Ajoute des rations dans la mangeoire de chaque enclos posé et occupé (récompense de la roue).
-- Renvoie le nombre d'enclos remplis.
function AnimalService:AddRationsAll(player: Player, amount: number): number
	local state = states[player]
	if not state then
		return 0
	end
	local count = 0
	for key, pen in state.Data.Pens do
		if pen.Placed and pen.Species then
			simulate(pen, os.time(), AnimalService:GetProductionMultiplier(player))
			pen.Feed = math.min(PenConfig.FeedCapacity, pen.Feed + amount)
			updatePenInfo(state, key)
			count += 1
		end
	end
	return count
end

-- Prix du prochain enclos, ou nil + raison
function AnimalService:CanBuyPen(player: Player): (number?, string?)
	local state = states[player]
	if not state then
		return nil, "Ta ferme n'est pas encore prête."
	end
	local owned = countBuiltPens(state.Data)
	if owned >= PenConfig.MaxByLevel[PlotService:GetLevel(player)] then
		return nil, "Agrandis ta parcelle pour construire plus d'enclos."
	end
	local price = PenConfig.Prices[owned + 1]
	if not price then
		return nil, "Nombre maximum d'enclos atteint."
	end
	return price, nil
end

-- Crée un enclos vide à cette position (appelé par PlacementService APRÈS paiement)
function AnimalService:CreatePen(player: Player, x: number, z: number, rot: number): string?
	local state = states[player]
	if not state then
		return nil
	end
	local n = 1
	while state.Data.Pens[tostring(n)] do
		n += 1
	end
	local key = tostring(n)
	state.Data.Pens[key] = {
		Species = nil,
		Animals = {},
		Feed = 0,
		Storage = {},
		LastUpdate = os.time(),
		X = x,
		Z = z,
		Rot = rot,
		Placed = true,
	}
	buildPenVisual(state, key)
	syncPens(state)
	SyncService:Notify(player, "Enclos construit ! Achète un animal au stand 🐄 ANIMAUX.", "Success")
	return key
end

function AnimalService:RefreshPen(player: Player, key: string)
	local state = states[player]
	if state then
		buildPenVisual(state, key)
		syncPens(state)
	end
end

-- Tire une variante au hasard selon Config.Variants[x].Chance (de la plus rare à la plus commune).
function AnimalService:RollVariant(): string
	local roll = math.random()
	local cumulative = 0
	local variants = ItemUtil.SortedVariants()
	for i = #variants, 1, -1 do
		local id = variants[i]
		cumulative += Config.Variants[id].Chance
		if id ~= "Normal" and roll < cumulative then
			return id
		end
	end
	return "Normal"
end

function AnimalService:AddAnimal(player: Player, penKey: string, speciesId: string, variantId: string): boolean
	local state = states[player]
	local pen = state and state.Data.Pens[penKey]
	if not pen or not Config.Animals[speciesId] or not ItemUtil.IsValidVariant(variantId) then
		return false
	end
	if pen.Species ~= nil and pen.Species ~= speciesId then
		return false
	end
	if #pen.Animals >= PenConfig.Capacity then
		return false
	end

	simulate(pen, os.time(), self:GetProductionMultiplier(player))
	pen.Species = speciesId
	local animal = { Id = HttpService:GenerateGUID(false), Variant = variantId, Progress = 0 }
	table.insert(pen.Animals, animal)

	spawnAnimalVisual(state :: State, penKey, animal)
	updatePenInfo(state :: State, penKey)
	syncPens(state :: State)
	return true
end

--------------------------------------------------------------------------
-- 🐾 Mes animaux : inventaire des animaux hors enclos
--------------------------------------------------------------------------

local function syncInventory(state: State)
	SyncService:Set(state.Player, "AnimalInventory", state.Data.AnimalInventory)
end

-- Donne un animal au joueur : il arrive dans 🐾 Mes animaux (achat, roue, cheval sauvage...)
function AnimalService:GiveAnimal(player: Player, speciesId: string, variantId: string): (boolean, string?)
	local data = DataService:GetData(player)
	if not data or not Config.Animals[speciesId] or not ItemUtil.IsValidVariant(variantId) then
		return false, "Animal invalide."
	end
	if #data.AnimalInventory >= PenConfig.InventoryCapacity then
		return false, ("🐾 Mes animaux est plein (%d max) : place-en dans un enclos."):format(PenConfig.InventoryCapacity)
	end
	table.insert(data.AnimalInventory, { Id = HttpService:GenerateGUID(false), Species = speciesId, Variant = variantId })
	SyncService:Set(player, "AnimalInventory", data.AnimalInventory)
	return true, nil
end

function AnimalService:HasInventoryRoom(player: Player): boolean
	local data = DataService:GetData(player)
	return data ~= nil and #data.AnimalInventory < PenConfig.InventoryCapacity
end

local function findInPens(data: { [string]: any }, animalId: string): (string?, number?)
	for key, pen in data.Pens do
		for index, animal in pen.Animals do
			if animal.Id == animalId then
				return key, index
			end
		end
	end
	return nil, nil
end

local function animalLabel(speciesId: string, variantId: string): string
	local species = Config.Animals[speciesId]
	local adjective = ItemUtil.VariantAdjective(species, variantId)
	return species.Icon .. " " .. species.DisplayName .. (if adjective ~= "" then " " .. adjective else "")
end

-- Inventaire -> enclos (penKey facultatif : sinon le premier enclos compatible)
local function placeAnimal(state: State, animalId: string, penKey: string?): (boolean, string)
	local data = state.Data
	local index
	for i, entry in data.AnimalInventory do
		if entry.Id == animalId then
			index = i
			break
		end
	end
	if not index then
		return false, "Animal introuvable."
	end
	local entry = data.AnimalInventory[index]
	local key = penKey
	if key == nil then
		local found, reason = AnimalService:FindPenFor(state.Player, entry.Species)
		if not found then
			return false, reason or "Aucun enclos libre."
		end
		key = found
	end
	local pen = data.Pens[key :: string]
	if not pen or not pen.Placed then
		return false, "Enclos introuvable (est-il posé ?)."
	end
	if pen.Species and pen.Species ~= entry.Species then
		return false, "Cet enclos accueille déjà une autre espèce."
	end
	if #pen.Animals >= PenConfig.Capacity then
		return false, ("Cet enclos est plein (%d max)."):format(PenConfig.Capacity)
	end
	simulate(pen, os.time(), AnimalService:GetProductionMultiplier(state.Player))
	pen.Species = entry.Species
	table.remove(data.AnimalInventory, index)
	-- L'animal garde son identifiant (les épingles de la vitrine restent valables)
	local animal = { Id = entry.Id, Variant = entry.Variant, Progress = 0 }
	table.insert(pen.Animals, animal)
	spawnAnimalVisual(state, key :: string, animal)
	updatePenInfo(state, key :: string)
	syncPens(state)
	syncInventory(state)
	GameEvents.Fire(state.Player, "PlaceAnimal")
	return true, animalLabel(entry.Species, entry.Variant) .. " entre dans l'enclos !"
end

-- Enclos -> inventaire
local function storeAnimal(state: State, animalId: string): (boolean, string)
	local data = state.Data
	local key, index = findInPens(data, animalId)
	if not key or not index then
		return false, "Animal introuvable dans tes enclos."
	end
	if #data.AnimalInventory >= PenConfig.InventoryCapacity then
		return false, "🐾 Mes animaux est plein."
	end
	local pen = data.Pens[key]
	simulate(pen, os.time(), AnimalService:GetProductionMultiplier(state.Player))
	local animal = table.remove(pen.Animals, index)
	local speciesId = pen.Species
	table.insert(data.AnimalInventory, { Id = animal.Id, Species = speciesId, Variant = animal.Variant })
	if #pen.Animals == 0 then
		pen.Species = nil
	end
	local visual = state.Visuals[key]
	if visual and visual.Animals[animal.Id] then
		visual.Animals[animal.Id]:Destroy()
		visual.Animals[animal.Id] = nil
	end
	updatePenInfo(state, key)
	syncPens(state)
	syncInventory(state)
	return true, animalLabel(speciesId, animal.Variant) .. " retourne dans 🐾 Mes animaux."
end

-- Épingle / désépingle un animal (enclos ou inventaire) dans la vitrine de prestige
local function pinAnimal(state: State, animalId: string): (boolean, string)
	local data = state.Data
	local exists = findInPens(data, animalId) ~= nil
	if not exists then
		for _, entry in data.AnimalInventory do
			if entry.Id == animalId then
				exists = true
			end
		end
	end
	if not exists then
		return false, "Animal introuvable."
	end
	local key = "A:" .. animalId
	local picks = data.ShowcasePicks
	local index = table.find(picks, key)
	if index then
		table.remove(picks, index)
		SyncService:Set(state.Player, "ShowcasePicks", picks)
		return true, "L'animal n'est plus épinglé dans la vitrine."
	end
	if #picks >= Config.Showcase.Slots then
		return false, ("Vitrine pleine (%d épinglés max)."):format(Config.Showcase.Slots)
	end
	table.insert(picks, key)
	SyncService:Set(state.Player, "ShowcasePicks", picks)
	return true, "⭐ Animal épinglé dans la vitrine !"
end

local function onAnimalAction(player: Player, action: any, animalId: any, penKey: any): (boolean, string)
	if not RemoteGuard.CheckCooldown(player, "AnimalAction", 0.3) then
		return false, "Doucement !"
	end
	local state = states[player]
	if not state then
		return false, "Ta ferme n'est pas encore prête."
	end
	if type(animalId) ~= "string" then
		return false, "Requête invalide."
	end
	if action == "Place" then
		if penKey ~= nil and type(penKey) ~= "string" then
			return false, "Requête invalide."
		end
		return placeAnimal(state, animalId, penKey)
	elseif action == "Store" then
		return storeAnimal(state, animalId)
	elseif action == "Pin" then
		return pinAnimal(state, animalId)
	end
	return false, "Action inconnue."
end

--------------------------------------------------------------------------
-- Activation / désactivation
--------------------------------------------------------------------------

-- Nettoie les données d'enclos (config modifiée, données corrompues...).
local function sanitizePens(data: { [string]: any })
	for key, pen in data.Pens do
		local index = tonumber(key)
		if type(pen) ~= "table" or not index then
			data.Pens[key] = nil
			continue
		end
		-- Anciennes sauvegardes (emplacements fixes) : on reprend l'ancienne position,
		-- décalée pour respecter la bande d'entrée du mode construction
		if type(pen.X) ~= "number" or type(pen.Z) ~= "number" then
			local legacy = PenConfig.LegacySlots[index]
			if legacy then
				pen.X, pen.Z, pen.Rot, pen.Placed = legacy.X, legacy.Z + 3, 0, true
			else
				pen.X, pen.Z, pen.Rot, pen.Placed = 0, 40, 0, false -- rangé : le joueur le replacera
			end
		end
		pen.Rot = math.clamp(math.floor(tonumber(pen.Rot) or 0), 0, 3)
		pen.Placed = pen.Placed ~= false
		if pen.Species ~= nil and not Config.Animals[pen.Species] then
			pen.Species = nil
			pen.Animals = {}
		end
		pen.Animals = if type(pen.Animals) == "table" then pen.Animals else {}
		pen.Storage = if type(pen.Storage) == "table" then pen.Storage else {}
		pen.Feed = math.clamp(tonumber(pen.Feed) or 0, 0, PenConfig.FeedCapacity)
		for i = #pen.Animals, 1, -1 do
			local animal = pen.Animals[i]
			if type(animal) ~= "table" or not ItemUtil.IsValidVariant(animal.Variant) then
				table.remove(pen.Animals, i)
			else
				animal.Id = animal.Id or HttpService:GenerateGUID(false)
			end
		end
		if #pen.Animals == 0 then
			pen.Species = nil
		end
	end
end

local function activate(player: Player, plot: any, data: { [string]: any })
	if states[player] then
		return
	end
	local state: State = { Player = player, Plot = plot, Data = data, Visuals = {} }
	states[player] = state

	sanitizePens(data)

	-- Production pendant l'absence du joueur
	local now = os.time()
	local multiplier = AnimalService:GetProductionMultiplier(player)
	local offline = 0
	for _, pen in data.Pens do
		offline += simulate(pen, now, multiplier)
	end
	if offline > 0 then
		SyncService:Notify(player, ("Pendant ton absence, tes animaux ont produit %d ressources !"):format(offline), "Success")
	end

	for key in data.Pens do
		buildPenVisual(state, key)
	end
	syncPens(state)

	-- Anciens animaux "en attente" (roue) : ils vont dans 🐾 Mes animaux
	if type(data.AnimalInventory) ~= "table" then
		data.AnimalInventory = {}
	end
	for _, pending in data.PendingAnimals or {} do
		if Config.Animals[pending.Species] then
			table.insert(data.AnimalInventory, { Id = HttpService:GenerateGUID(false), Species = pending.Species, Variant = pending.Variant or "Normal" })
		end
	end
	data.PendingAnimals = {}
	syncInventory(state)
end

local function deactivate(player: Player, _plot: any)
	local state = states[player]
	states[player] = nil
	if state then
		for _, visual in state.Visuals do
			visual.Folder:Destroy()
		end
	end
end

local function productionLoop()
	while true do
		task.wait(1)
		local now = os.time()
		for player, state in states do
			local multiplier = AnimalService:GetProductionMultiplier(player)
			for key, pen in state.Data.Pens do
				local feedBefore = pen.Feed
				local produced = simulate(pen, now, multiplier)
				if produced > 0 or feedBefore ~= pen.Feed then
					updatePenInfo(state, key)
				end
			end
		end
	end
end

--------------------------------------------------------------------------
-- Cycle de vie
--------------------------------------------------------------------------

function AnimalService:Init()
	PlotService:OnPlotReady(activate)
	PlotService:OnPlotReleased(deactivate)
end

function AnimalService:Start()
	Remotes.Get("AnimalAction").OnServerInvoke = onAnimalAction
	task.spawn(productionLoop)
end

return AnimalService
