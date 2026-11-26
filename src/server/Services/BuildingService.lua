--[[
	BuildingService.lua
	===================
	Bâtiments de transformation (boulangerie, filature, laiterie, fromagerie,
	atelier de couture) construits sur la parcelle.

	  • Les bâtiments s'achètent et se placent avec le mode construction
	    (PlacementService). Déblocage dans l'ordre (champ Requires) et selon le
	    niveau de parcelle (RequiredLevel). Position dans data.Buildings[id] :
	    X, Z, Rot, Placed. Déplacer / ranger ne fait rien perdre (file, stock).
	  • Recettes : ingrédients -> produit, avec un temps de fabrication.
	    La VARIANTE du 1er ingrédient est transmise au produit (Lait Doré -> Beurre Doré).
	  • File d'attente : on commande plusieurs produits ; `Slots` commandes sont
	    fabriquées en même temps (selon le niveau du bâtiment). Les ingrédients sont
	    pris dans l'inventaire au moment de la commande.
	  • Produits finis : stockés dans le bâtiment (OutputCapacity), à récupérer.
	  • Améliorations : Config.BuildingLevels (vitesse, emplacements, taille de la file).
	  • Hors ligne : à la connexion, on simule le temps écoulé (plafonné).

	Le client ouvre l'interface via le prompt du bâtiment (attribut OpenUI = "Building")
	et envoie ses demandes par la RemoteFunction "BuildingAction" :
	  ("Queue", buildingId, recipeId, quantité) | ("Collect", buildingId) | ("Upgrade", buildingId)
	Tout est validé ici : propriétaire, distance, cooldown, ingrédients, place, Coins.

	API (PlacementService) :
	  BuildingService:CanBuy(player, buildingId) -> (prix | nil, raison)
	  BuildingService:Create(player, buildingId, x, z, rot)
	  BuildingService:Refresh(player, buildingId)  (reconstruit / retire le visuel)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local ItemUtil = require(ReplicatedStorage.Shared.ItemUtil)
local BuildingBuilder = require(script.Parent.Parent.Util.BuildingBuilder)
local PlacementUtil = require(ReplicatedStorage.Shared.PlacementUtil)
local CosmeticUtil = require(ReplicatedStorage.Shared.CosmeticUtil)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RemoteGuard = require(script.Parent.Parent.Util.RemoteGuard)
local CurrencyService = require(script.Parent.CurrencyService)
local SyncService = require(script.Parent.SyncService)
local PlotService = require(script.Parent.PlotService)
local InventoryService = require(script.Parent.InventoryService)
local XPService = require(script.Parent.XPService)
local BoostService = require(script.Parent.BoostService)

local Settings = Config.BuildingSettings
local LEVELS = Config.BuildingLevels

local BuildingService = {}

type Visual = {
	Model: Model,
	Label: TextLabel,
	Prompt: ProximityPrompt,
	WorkFX: { Instance }, -- fumée, feu, gouttes de lait : allumés seulement en production
	WorkShow: { BasePart }, -- pièces visibles seulement en production (feu, filet de lait)
}

type State = {
	Player: Player,
	Plot: any,
	Data: { [string]: any },
	Visuals: { [string]: Visual },
}

local states: { [Player]: State } = {}

--------------------------------------------------------------------------
-- Utilitaires
--------------------------------------------------------------------------

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

local function getRecipe(def: any, recipeId: any)
	if type(recipeId) ~= "string" then
		return nil
	end
	for _, recipe in def.Recipes do
		if recipe.Id == recipeId then
			return recipe
		end
	end
	return nil
end

local function levelInfo(level: number)
	return LEVELS[math.clamp(level, 1, #LEVELS)]
end

local function outputTotal(building: { [string]: any }): number
	local total = 0
	for _, variants in building.Output do
		for _, count in variants do
			total += count
		end
	end
	return total
end

-- Boost "Production" (Developer Product) : bâtiments plus rapides
function BuildingService:GetSpeedMultiplier(player: Player): number
	return BoostService:GetMultiplier(player, "Production")
end

-- Raison pour laquelle le bâtiment ne peut pas être construit (nil = constructible)
local function lockReason(data: { [string]: any }, buildingId: string, plotLevel: number): string?
	local def = Config.Buildings[buildingId]
	if plotLevel < def.RequiredLevel then
		return ("Parcelle niveau %d requis"):format(def.RequiredLevel)
	end
	if def.Requires and not data.Buildings[def.Requires] then
		return "Construis d'abord : " .. Config.Buildings[def.Requires].DisplayName
	end
	return nil
end

--------------------------------------------------------------------------
-- Production (simulation, utilisée en jeu ET pour le hors-ligne)
--------------------------------------------------------------------------

-- Fait avancer la file jusqu'à `now`. Renvoie le nombre de produits terminés.
local function simulate(buildingId: string, building: { [string]: any }, now: number, multiplier: number): number
	local elapsed = math.clamp(now - (building.LastUpdate or now), 0, Settings.MaxOfflineSeconds)
	building.LastUpdate = now
	local def = Config.Buildings[buildingId]
	local info = levelInfo(building.Level)
	local speed = info.Speed * multiplier
	local queue = building.Queue
	local completed = 0

	while #queue > 0 do
		-- 1. Termine les commandes actives déjà finies (s'il y a de la place)
		local blocked = false
		local i = 1
		while i <= math.min(info.Slots, #queue) do
			local job = queue[i]
			if job.Remaining <= 1e-6 then
				local recipe = getRecipe(def, job.Recipe)
				local amount = if recipe then recipe.Output.Amount else 0
				if amount > 0 and outputTotal(building) + amount > Settings.OutputCapacity then
					job.Remaining = 0
					blocked = true -- stockage plein : la production attend
					i += 1
				else
					if recipe then
						local variants = building.Output[recipe.Output.Item] or {}
						variants[job.Variant] = (variants[job.Variant] or 0) + amount
						building.Output[recipe.Output.Item] = variants
						completed += 1
					end
					table.remove(queue, i)
				end
			else
				i += 1
			end
		end
		if blocked or elapsed <= 1e-6 or #queue == 0 then
			break
		end

		-- 2. Avance jusqu'à la prochaine fin de commande (ou la fin du temps écoulé)
		local active = math.min(info.Slots, #queue)
		local nextDone = math.huge
		for j = 1, active do
			nextDone = math.min(nextDone, queue[j].Remaining)
		end
		local step = math.min(elapsed, nextDone / speed)
		for j = 1, active do
			queue[j].Remaining = math.max(0, queue[j].Remaining - step * speed)
		end
		elapsed -= step
	end
	return completed
end

--------------------------------------------------------------------------
-- Visuels
--------------------------------------------------------------------------

local function sync(state: State)
	SyncService:Set(state.Player, "Buildings", state.Data.Buildings)
end

local function updateVisual(state: State, buildingId: string)
	local visual = state.Visuals[buildingId]
	local building = state.Data.Buildings[buildingId]
	if not visual or not building then
		return
	end
	local def = Config.Buildings[buildingId]
	local stored = outputTotal(building)
	local status
	if #building.Queue == 0 and stored == 0 then
		status = "💤 En attente de commandes"
	else
		status = ("🔨 %d en file   •   📦 %d prêt(s)"):format(#building.Queue, stored)
	end
	local text = ("%s %s  (niv. %d)\n%s"):format(def.Icon, def.DisplayName, building.Level, status)
	if visual.Label.Text ~= text then
		visual.Label.Text = text
	end
	-- Animations UNIQUEMENT quand le bâtiment produit : le serveur allume fumée / feu / lait
	-- et pose l'attribut Working ; les roues et l'aiguille sont animées par le client
	local working = #building.Queue > 0
	if visual.Model:GetAttribute("Working") ~= working then
		visual.Model:SetAttribute("Working", working)
		for _, fx in visual.WorkFX do
			(fx :: any).Enabled = working
		end
		for _, part in visual.WorkShow do
			part.Transparency = if working then 0 else 1
		end
	end
end

local function destroyVisual(state: State, buildingId: string)
	local visual = state.Visuals[buildingId]
	if visual then
		visual.Model:Destroy()
		state.Visuals[buildingId] = nil
	end
end

-- (Re)construit le visuel d'un bâtiment à sa position sauvegardée (rien si rangé).
local function buildVisual(state: State, buildingId: string)
	destroyVisual(state, buildingId)
	local def = Config.Buildings[buildingId]
	local building = state.Data.Buildings[buildingId]
	if not building or not building.Placed then
		return
	end
	-- Repère de l'emprise ; le bâtiment est reculé de 1 stud pour laisser la place devant la porte
	local base = PlotService:ToWorld(state.Plot, 0, 0) * PlacementUtil.LocalCFrame(building.X, building.Z, building.Rot or 0)
	-- Cosmétique "Couleurs des bâtiments" (Classique = couleurs d'origine de chaque bâtiment)
	local palette = CosmeticUtil.Equipped(state.Data, "BuildingPalette") or {}
	local origin = base * CFrame.new(0, 0, 1)

	-- Modèle cartoon thématique (BuildingBuilder) ; seuls Walls et Door comptent pour le gameplay
	local model, refs = BuildingBuilder.Build(buildingId, origin, palette)
	model.Name = "Building_" .. buildingId
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:SetAttribute("PlaceType", "Building")
	model:SetAttribute("PlaceId", buildingId)
	model:SetAttribute("Working", false)
	local walls, door = refs.Walls, refs.Door
	local wallHeight = BuildingBuilder.WallHeight

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Ouvrir"
	prompt.ObjectText = def.DisplayName
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Settings.InteractDistance
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OwnerOnly", true)
	prompt:SetAttribute("OpenUI", "Building")
	prompt:SetAttribute("BuildingId", buildingId)
	prompt.Parent = door

	local _, label = makeBillboard(walls, Vector2.new(14, 3), Vector3.new(0, wallHeight / 2 + 5, 0), 120)

	model.Parent = state.Plot.Model
	state.Visuals[buildingId] = { Model = model, Label = label, Prompt = prompt, WorkFX = refs.WorkFX, WorkShow = refs.WorkShow }
	updateVisual(state, buildingId)
end

--------------------------------------------------------------------------
-- Actions des joueurs (toutes validées ici)
--------------------------------------------------------------------------

-- Prix de construction, ou nil + raison (verrouillé, déjà construit...)
function BuildingService:CanBuy(player: Player, buildingId: string): (number?, string?)
	local state = states[player]
	local def = Config.Buildings[buildingId]
	if not state or not def then
		return nil, "Bâtiment inconnu."
	end
	if state.Data.Buildings[buildingId] then
		return nil, "Tu as déjà ce bâtiment (il est peut-être rangé)."
	end
	local reason = lockReason(state.Data, buildingId, PlotService:GetLevel(player))
	if reason then
		return nil, "🔒 " .. reason
	end
	return def.Price, nil
end

-- Crée le bâtiment à cette position (appelé par PlacementService APRÈS paiement)
function BuildingService:Create(player: Player, buildingId: string, x: number, z: number, rot: number)
	local state = states[player]
	local def = Config.Buildings[buildingId]
	if not state or not def then
		return
	end
	state.Data.Buildings[buildingId] = {
		Level = 1,
		Queue = {},
		Output = {},
		LastUpdate = os.time(),
		X = x,
		Z = z,
		Rot = rot,
		Placed = true,
	}
	buildVisual(state, buildingId)
	sync(state)
	SyncService:Notify(player, ("%s %s %s ! Approche-toi de la porte pour l'utiliser."):format(def.Icon, def.DisplayName, if def.Feminine then "construite" else "construit"), "Success")
end

function BuildingService:Refresh(player: Player, buildingId: string)
	local state = states[player]
	if state then
		buildVisual(state, buildingId)
		sync(state)
	end
end

-- Choisit la variante de l'ingrédient principal : la plus rare dont on a assez.
-- minVariant (recettes rares) : la variante doit être au moins de ce rang.
local function pickPrimaryVariant(player: Player, itemId: string, amount: number, minVariant: string?): string?
	local variants = ItemUtil.SortedVariants()
	local minOrder = if minVariant then ItemUtil.GetVariant(minVariant).Order else 1
	for i = #variants, 1, -1 do
		if ItemUtil.GetVariant(variants[i]).Order >= minOrder and InventoryService:GetAmount(player, itemId, variants[i]) >= amount then
			return variants[i]
		end
	end
	return nil
end

-- Prend les ingrédients d'UNE commande. Renvoie la variante du produit, ou nil si impossible.
local function takeIngredients(player: Player, recipe: any): string?
	local primary = recipe.Inputs[1]
	local variant = pickPrimaryVariant(player, primary.Item, primary.Amount, recipe.MinVariant)
	if not variant then
		return nil
	end
	-- Vérifie les autres ingrédients AVANT de retirer quoi que ce soit
	for index = 2, #recipe.Inputs do
		local input = recipe.Inputs[index]
		if InventoryService:GetAmount(player, input.Item) < input.Amount then
			return nil
		end
	end
	if not InventoryService:RemoveItem(player, primary.Item, variant, primary.Amount) then
		return nil
	end
	for index = 2, #recipe.Inputs do
		local input = recipe.Inputs[index]
		InventoryService:RemoveAnyVariant(player, input.Item, input.Amount)
	end
	-- Recette rare : le produit est déjà un objet rare, il sort en variante Normale
	return if recipe.MinVariant then "Normal" else variant
end

local function actionQueue(state: State, buildingId: string, recipeId: any, count: any): (boolean, string)
	local def = Config.Buildings[buildingId]
	local building = state.Data.Buildings[buildingId]
	local recipe = getRecipe(def, recipeId)
	if not recipe then
		return false, "Recette inconnue."
	end
	if not RemoteGuard.IsValidNumber(count, 1, 50, true) then
		return false, "Quantité invalide."
	end
	if (recipe.RequiredBuildingLevel or 1) > building.Level then
		return false, ("Recette débloquée au niveau %d du bâtiment."):format(recipe.RequiredBuildingLevel)
	end

	simulate(buildingId, building, os.time(), BuildingService:GetSpeedMultiplier(state.Player))
	local info = levelInfo(building.Level)
	local room = info.QueueSize - #building.Queue
	if room <= 0 then
		return false, "La file d'attente est pleine."
	end

	local queued = 0
	for _ = 1, math.min(count, room) do
		local variant = takeIngredients(state.Player, recipe)
		if not variant then
			break
		end
		table.insert(building.Queue, { Recipe = recipe.Id, Variant = variant, Remaining = recipe.Time })
		queued += 1
	end

	if queued == 0 then
		if recipe.MinVariant then
			local primary = recipe.Inputs[1]
			return false, ("Il te faut %d %s (ou mieux)."):format(primary.Amount, ItemUtil.Label(primary.Item, recipe.MinVariant))
		end
		return false, "Il te manque des ingrédients."
	end
	updateVisual(state, buildingId)
	sync(state)
	return true, ("+%d %s en fabrication"):format(queued, ItemUtil.Label(recipe.Output.Item))
end

local function actionCollect(state: State, buildingId: string): (boolean, string)
	local building = state.Data.Buildings[buildingId]
	simulate(buildingId, building, os.time(), BuildingService:GetSpeedMultiplier(state.Player))
	if outputTotal(building) == 0 then
		return false, "Rien à récupérer pour l'instant."
	end
	local space = InventoryService:GetFreeSpace(state.Player)
	if space <= 0 then
		return false, "Inventaire plein ! Va vendre au stand 💰"
	end

	local collected, parts = 0, {}
	for itemId, variants in building.Output do
		for variant, count in variants do
			local take = math.min(count, space - collected)
			if take > 0 and InventoryService:AddItem(state.Player, itemId, variant, take) then
				variants[variant] = if count - take > 0 then count - take else nil
				collected += take
				table.insert(parts, ("%d %s"):format(take, ItemUtil.Label(itemId, variant)))
			end
		end
		if next(variants) == nil then
			building.Output[itemId] = nil
		end
	end

	XPService:AddXP(state.Player, Config.Progression.XP.Craft * collected)

	-- La place libérée peut débloquer des commandes terminées
	simulate(buildingId, building, os.time(), BuildingService:GetSpeedMultiplier(state.Player))
	updateVisual(state, buildingId)
	sync(state)
	return true, "+" .. table.concat(parts, ", ")
end

local function actionUpgrade(state: State, buildingId: string): (boolean, string)
	local def = Config.Buildings[buildingId]
	local building = state.Data.Buildings[buildingId]
	if building.Level >= #LEVELS then
		return false, "Niveau maximum atteint."
	end
	local cost = math.floor(def.Price * LEVELS[building.Level + 1].CostMultiplier)
	-- On fige la production au niveau actuel avant de changer de vitesse
	simulate(buildingId, building, os.time(), BuildingService:GetSpeedMultiplier(state.Player))
	if not CurrencyService:SpendCoins(state.Player, cost, "UpgradeBuilding:" .. buildingId) then
		return false, ("Il te faut %s Coins."):format(Format.Number(cost))
	end
	building.Level += 1
	updateVisual(state, buildingId)
	sync(state)
	return true, ("%s %s passe au niveau %d !"):format(def.Icon, def.DisplayName, building.Level)
end

local function onBuildingAction(player: Player, action: any, buildingId: any, arg1: any, arg2: any): (boolean, string)
	-- 1. Arguments
	if type(action) ~= "string" or type(buildingId) ~= "string" or not Config.Buildings[buildingId] then
		return false, "Requête invalide."
	end
	-- 2. Anti-spam
	if not RemoteGuard.CheckCooldown(player, "BuildingAction", 0.2) then
		return false, "Doucement !"
	end
	-- 3. Propriétaire + bâtiment construit + distance
	local state = states[player]
	local visual = state and state.Visuals[buildingId]
	if not state or not state.Data.Buildings[buildingId] then
		return false, "Tu n'as pas ce bâtiment."
	end
	if not visual then
		return false, "Ce bâtiment est rangé : place-le avec 🔨 Construire."
	end
	local door = visual.Prompt.Parent :: BasePart
	if not RemoteGuard.IsNear(player, door.Position, Settings.InteractDistance + 8) then
		return false, "Approche-toi du bâtiment."
	end

	if action == "Queue" then
		return actionQueue(state, buildingId, arg1, arg2)
	elseif action == "Collect" then
		return actionCollect(state, buildingId)
	elseif action == "Upgrade" then
		return actionUpgrade(state, buildingId)
	end
	return false, "Action inconnue."
end

--------------------------------------------------------------------------
-- Activation / désactivation
--------------------------------------------------------------------------

local function sanitize(data: { [string]: any })
	for buildingId, building in data.Buildings do
		local def = Config.Buildings[buildingId]
		if not def or type(building) ~= "table" then
			data.Buildings[buildingId] = nil
			continue
		end
		building.Level = math.clamp(math.floor(tonumber(building.Level) or 1), 1, #LEVELS)
		-- Anciennes sauvegardes (emplacement fixe) : on reprend la position par défaut
		if type(building.X) ~= "number" or type(building.Z) ~= "number" then
			building.X, building.Z, building.Rot, building.Placed = def.X, def.Z, 0, true
		end
		building.Rot = math.clamp(math.floor(tonumber(building.Rot) or 0), 0, 3)
		building.Placed = building.Placed ~= false
		building.Queue = if type(building.Queue) == "table" then building.Queue else {}
		building.Output = if type(building.Output) == "table" then building.Output else {}
		for i = #building.Queue, 1, -1 do
			local job = building.Queue[i]
			if type(job) ~= "table" or not getRecipe(def, job.Recipe) or not ItemUtil.IsValidVariant(job.Variant) then
				table.remove(building.Queue, i)
			else
				job.Remaining = math.max(0, tonumber(job.Remaining) or 0)
			end
		end
	end
end

local function activate(player: Player, plot: any, data: { [string]: any })
	if states[player] then
		return
	end
	local state: State = { Player = player, Plot = plot, Data = data, Visuals = {} }
	states[player] = state

	sanitize(data)
	local now = os.time()
	local multiplier = BuildingService:GetSpeedMultiplier(player)
	local offline = 0
	for buildingId, building in data.Buildings do
		offline += simulate(buildingId, building, now, multiplier)
		buildVisual(state, buildingId)
	end
	if offline > 0 then
		SyncService:Notify(player, ("Pendant ton absence, tes bâtiments ont fabriqué %d produits !"):format(offline), "Success")
	end
	sync(state)
end

local function deactivate(player: Player, _plot: any)
	local state = states[player]
	states[player] = nil
	if state then
		for _, visual in state.Visuals do
			visual.Model:Destroy()
		end
	end
end

local function productionLoop()
	while true do
		task.wait(1)
		local now = os.time()
		for player, state in states do
			local multiplier = BuildingService:GetSpeedMultiplier(player)
			local anyCompleted = false
			for buildingId, building in state.Data.Buildings do
				if simulate(buildingId, building, now, multiplier) > 0 then
					anyCompleted = true
					updateVisual(state, buildingId)
				end
			end
			if anyCompleted then
				sync(state) -- l'interface du joueur se met à jour
			end
		end
	end
end

--------------------------------------------------------------------------
-- Cycle de vie
--------------------------------------------------------------------------

function BuildingService:Init()
	PlotService:OnPlotReady(activate)
	PlotService:OnPlotReleased(deactivate)
end

function BuildingService:Start()
	Remotes.Get("BuildingAction").OnServerInvoke = onBuildingAction
	task.spawn(productionLoop)
end

return BuildingService
