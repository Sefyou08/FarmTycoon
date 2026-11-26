--[[
	BuildingService.lua
	===================
	Bâtiments de transformation (boulangerie, filature, laiterie, fromagerie,
	atelier de couture) construits sur la parcelle.

	  • Chaque bâtiment a un emplacement fixe (Config.Buildings[x].X / Z) et un
	    bouton tycoon "Construire". Déblocage dans l'ordre (champ Requires) et
	    selon le niveau de parcelle (RequiredLevel).
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
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local ItemUtil = require(ReplicatedStorage.Shared.ItemUtil)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RemoteGuard = require(script.Parent.Parent.Util.RemoteGuard)
local CurrencyService = require(script.Parent.CurrencyService)
local SyncService = require(script.Parent.SyncService)
local PlotService = require(script.Parent.PlotService)
local InventoryService = require(script.Parent.InventoryService)

local Settings = Config.BuildingSettings
local LEVELS = Config.BuildingLevels

local BuildingService = {}

type Pad = {
	Part: Part,
	Prompt: ProximityPrompt,
	Gui: BillboardGui,
	Label: TextLabel,
}

type Visual = {
	Model: Model,
	Label: TextLabel,
	Smoke: ParticleEmitter,
	Prompt: ProximityPrompt,
}

type State = {
	Player: Player,
	Plot: any,
	Data: { [string]: any },
	Visuals: { [string]: Visual },
}

local padsByPlotId: { [number]: { [string]: Pad } } = {}
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

function BuildingService:GetSpeedMultiplier(_player: Player): number
	return 1 -- phase 7 (rebirth) / phase 8 (game pass)
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
	visual.Smoke.Enabled = #building.Queue > 0
end

local function buildVisual(state: State, buildingId: string)
	local def = Config.Buildings[buildingId]
	local origin = PlotService:ToWorld(state.Plot, def.X, def.Z)

	local model = Instance.new("Model")
	model.Name = "Building_" .. buildingId
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	local wallHeight = 7
	local walls = makePart({
		Name = "Walls",
		Size = Vector3.new(def.Width, wallHeight, def.Depth),
		CFrame = origin * CFrame.new(0, wallHeight / 2, 0),
		Color = def.WallColor,
		Material = Enum.Material.SmoothPlastic,
		Parent = model,
	})
	model.PrimaryPart = walls

	-- Toit à deux pentes (2 WedgeParts)
	for _, side in { -1, 1 } do
		local roof = Instance.new("WedgePart")
		roof.Anchored = true
		roof.Size = Vector3.new(def.Width + 1, 3, def.Depth / 2 + 0.5)
		-- Un WedgePart est haut côté +Z local et descend vers -Z : on tourne la pente "+Z"
		-- de 180° pour que les deux pentes montent vers le faîte (au centre)
		roof.CFrame = origin * CFrame.new(0, wallHeight + 1.5, side * (def.Depth / 4 + 0.25)) * CFrame.Angles(0, if side > 0 then math.pi else 0, 0)
		roof.Color = def.RoofColor
		roof.Material = Enum.Material.SmoothPlastic
		roof.Parent = model
	end

	-- Cheminée avec fumée quand le bâtiment travaille
	local chimney = makePart({
		Name = "Chimney",
		Size = Vector3.new(1.4, 4, 1.4),
		CFrame = origin * CFrame.new(def.Width / 2 - 2.5, wallHeight + 2.5, def.Depth / 4),
		Color = Color3.fromRGB(120, 90, 80),
		Material = Enum.Material.Brick,
		Parent = model,
	})
	local smoke = Instance.new("ParticleEmitter")
	smoke.Color = ColorSequence.new(Color3.fromRGB(220, 220, 220))
	smoke.Transparency = NumberSequence.new(0.3, 1)
	smoke.Size = NumberSequence.new(0.8, 2.5)
	smoke.Lifetime = NumberRange.new(2, 3)
	smoke.Rate = 4
	smoke.Speed = NumberRange.new(2, 3)
	smoke.SpreadAngle = Vector2.new(10, 10)
	smoke.EmissionDirection = Enum.NormalId.Top
	smoke.Enabled = false
	smoke.Parent = chimney

	-- Porte côté entrée de la parcelle (-Z local = vers l'allée) : c'est là qu'est le prompt
	local door = makePart({
		Name = "Door",
		Size = Vector3.new(3, 5, 0.3),
		CFrame = origin * CFrame.new(0, 2.5, -def.Depth / 2 - 0.15),
		Color = Color3.fromRGB(110, 70, 40),
		Material = Enum.Material.Wood,
		Parent = model,
	})

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
	state.Visuals[buildingId] = { Model = model, Label = label, Smoke = smoke, Prompt = prompt }
	updateVisual(state, buildingId)
end

local function refreshPads(state: State)
	local level = PlotService:GetLevel(state.Player)
	for buildingId, pad in padsByPlotId[state.Plot.Id] do
		local def = Config.Buildings[buildingId]
		local built = state.Data.Buildings[buildingId] ~= nil
		local visible = not built and level >= def.RequiredLevel
		pad.Part.Transparency = if visible then 0.4 else 1
		pad.Gui.Enabled = visible
		pad.Prompt.Enabled = visible
		if visible then
			local reason = lockReason(state.Data, buildingId, level)
			if reason then
				pad.Prompt.ActionText = "Verrouillé"
				pad.Prompt.ObjectText = reason
				pad.Label.Text = ("🔒 %s %s"):format(def.Icon, def.DisplayName)
				pad.Part.Color = Color3.fromRGB(150, 150, 150)
			else
				pad.Prompt.ActionText = ("Construire : %s Coins"):format(Format.Number(def.Price))
				pad.Prompt.ObjectText = def.DisplayName
				pad.Label.Text = ("🏗️ %s %s"):format(def.Icon, def.DisplayName)
				pad.Part.Color = Color3.fromRGB(255, 170, 60)
			end
		end
	end
end

local function hidePads(plot: any)
	for _, pad in padsByPlotId[plot.Id] do
		pad.Part.Transparency = 1
		pad.Gui.Enabled = false
		pad.Prompt.Enabled = false
	end
end

--------------------------------------------------------------------------
-- Actions des joueurs (toutes validées ici)
--------------------------------------------------------------------------

local function onPadTriggered(plot: any, buildingId: string, player: Player)
	local state = states[player]
	local pad = padsByPlotId[plot.Id][buildingId]
	if not state or state.Plot ~= plot then
		SyncService:Notify(player, "Ce n'est pas ta ferme !", "Error")
		return
	end
	if not RemoteGuard.IsNear(player, pad.Part.Position, Settings.InteractDistance + 4) then
		return
	end
	if not RemoteGuard.CheckCooldown(player, "BuildBuilding", 0.5) then
		return
	end
	local data = state.Data
	if data.Buildings[buildingId] then
		return
	end
	local reason = lockReason(data, buildingId, PlotService:GetLevel(player))
	if reason then
		SyncService:Notify(player, "🔒 " .. reason, "Error")
		return
	end
	local def = Config.Buildings[buildingId]
	if not CurrencyService:SpendCoins(player, def.Price, "BuildBuilding:" .. buildingId) then
		SyncService:Notify(player, ("Il te faut %s Coins pour construire : %s."):format(Format.Number(def.Price), def.DisplayName), "Error")
		return
	end

	data.Buildings[buildingId] = { Level = 1, Queue = {}, Output = {}, LastUpdate = os.time() }
	buildVisual(state, buildingId)
	refreshPads(state) -- le bâtiment suivant se déverrouille
	sync(state)
	SyncService:Notify(player, ("%s %s construite ! Approche-toi de la porte pour l'utiliser."):format(def.Icon, def.DisplayName), "Success")
end

-- Choisit la variante de l'ingrédient principal : la plus rare dont on a assez.
local function pickPrimaryVariant(player: Player, itemId: string, amount: number): string?
	local variants = ItemUtil.SortedVariants()
	for i = #variants, 1, -1 do
		if InventoryService:GetAmount(player, itemId, variants[i]) >= amount then
			return variants[i]
		end
	end
	return nil
end

-- Prend les ingrédients d'UNE commande. Renvoie la variante du produit, ou nil si impossible.
local function takeIngredients(player: Player, recipe: any): string?
	local primary = recipe.Inputs[1]
	local variant = pickPrimaryVariant(player, primary.Item, primary.Amount)
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
	return variant
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
	if not state or not state.Data.Buildings[buildingId] or not visual then
		return false, "Tu n'as pas ce bâtiment."
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
	refreshPads(state)
	sync(state)
end

local function deactivate(player: Player, plot: any)
	local state = states[player]
	states[player] = nil
	if state then
		for _, visual in state.Visuals do
			visual.Model:Destroy()
		end
	end
	hidePads(plot)
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
-- Construction des emplacements (boutons tycoon)
--------------------------------------------------------------------------

local function buildPads(plot: any)
	local pads: { [string]: Pad } = {}
	for buildingId, def in Config.Buildings do
		local part = makePart({
			Name = "BuildingPad_" .. buildingId,
			Size = Vector3.new(8, 0.3, 8),
			CFrame = PlotService:ToWorld(plot, def.X, def.Z, 0.15),
			Color = Color3.fromRGB(255, 170, 60),
			Material = Enum.Material.Neon,
			Transparency = 1,
			CanCollide = false,
			Parent = plot.Model,
		})
		local gui, label = makeBillboard(part, Vector2.new(10, 1.8), Vector3.new(0, 3, 0), 90)
		gui.Enabled = false

		local prompt = Instance.new("ProximityPrompt")
		prompt.HoldDuration = 0.4 -- petit appui long : évite les achats par erreur
		prompt.MaxActivationDistance = Settings.InteractDistance
		prompt.RequiresLineOfSight = false
		prompt.Enabled = false
		prompt:SetAttribute("OwnerOnly", true)
		prompt.Parent = part
		prompt.Triggered:Connect(function(player)
			onPadTriggered(plot, buildingId, player)
		end)

		pads[buildingId] = { Part = part, Prompt = prompt, Gui = gui, Label = label }
	end
	padsByPlotId[plot.Id] = pads
end

--------------------------------------------------------------------------
-- Cycle de vie
--------------------------------------------------------------------------

function BuildingService:Init()
	for _, plot in PlotService:GetAllPlots() do
		buildPads(plot)
	end
	PlotService:OnPlotReady(activate)
	PlotService:OnPlotReleased(deactivate)
	PlotService:OnPlotLevelChanged(function(player)
		local state = states[player]
		if state then
			refreshPads(state)
		end
	end)
end

function BuildingService:Start()
	Remotes.Get("BuildingAction").OnServerInvoke = onBuildingAction
	task.spawn(productionLoop)
end

return BuildingService
