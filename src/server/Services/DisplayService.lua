--[[
	DisplayService.lua
	==================
	Exposition des créatures (phase 6).

	  • SOCLES d'exposition : achetés et placés avec le mode construction
	    (PlacementService). Données : data.Pedestals[id] = { X, Z, Rot, Placed, Creature }.
	    Une créature exposée sur un socle POSÉ rapporte des Coins / seconde
	    (CreatureUtil.GetIncome), versés toutes les Config.Display.IncomeInterval
	    secondes, et aussi pendant l'absence du joueur (plafonné).
	  • VITRINE DE PRESTIGE : devant l'entrée de chaque parcelle, côté allée,
	    Config.Showcase.Slots socles éclairés montrent d'abord ce que le joueur a épinglé
	    (data.ShowcasePicks : créatures, ou animaux "A:<id>"), puis ses créatures les plus
	    prestigieuses. Un animal n'y apparaît QUE s'il est épinglé. Tout le monde la voit.
	  • PANNEAU de la parcelle : "Ferme de X" + la meilleure prise du joueur.

	RemoteFunction "DisplayAction" (validée ici) :
	  ("Assign", idCréature) -> expose la créature sur le premier socle posé libre
	  ("Remove", idCréature) -> la retire de son socle
	  ("Pin", idCréature)    -> l'épingle / la désépingle dans la vitrine
	  ("ToPen", idCréature)  -> cheval sauvage : il quitte la collection et va dans un enclos
	                            (il y produit son crin et reste utilisable comme monture)

	API (PlacementService) :
	  DisplayService:CanBuyPedestal(player) -> (prix | nil, raison)
	  DisplayService:CreatePedestal(player, x, z, rot)
	  DisplayService:RefreshPedestal(player, id)
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CreatureUtil = require(ReplicatedStorage.Shared.CreatureUtil)
local Format = require(ReplicatedStorage.Shared.Format)
local ItemUtil = require(ReplicatedStorage.Shared.ItemUtil)
local PlacementUtil = require(ReplicatedStorage.Shared.PlacementUtil)
local CosmeticUtil = require(ReplicatedStorage.Shared.CosmeticUtil)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RemoteGuard = require(script.Parent.Parent.Util.RemoteGuard)
local GameEvents = require(script.Parent.Parent.Util.GameEvents)
local CreatureBuilder = require(script.Parent.Parent.Util.CreatureBuilder)
local CurrencyService = require(script.Parent.CurrencyService)
local SyncService = require(script.Parent.SyncService)
local PlotService = require(script.Parent.PlotService)
local AnimalService = require(script.Parent.AnimalService)

local DisplayConfig = Config.Display
local ShowcaseConfig = Config.Showcase

local DisplayService = {}

local SPIN_TAG = "DisplaySpin" -- le client fait tourner doucement ces modèles

type State = {
	Player: Player,
	Plot: any,
	Data: { [string]: any },
	Pedestals: { [string]: Model },
	ShowcaseSignature: string,
	Income: number,
}

type ShowcaseSlot = {
	Ring: Part,
	Light: PointLight,
	Label: TextLabel,
	Top: CFrame,
	Content: Model?,
	FX: ParticleEmitter?, -- cosmétique "Effets de vitrine"
}

local states: { [any]: State } = {}
local showcaseByPlotId: { [number]: { ShowcaseSlot } } = {}

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

local function makeBillboard(parent: Instance, size: Vector2, offset: Vector3, maxDistance: number): TextLabel
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
	label.RichText = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Parent = gui
	return label
end

local function findCreature(data: { [string]: any }, uid: string): { [string]: any }?
	for _, entry in data.Creatures do
		if entry.Id == uid then
			return entry
		end
	end
	return nil
end

local function pedestalOf(data: { [string]: any }, uid: string): string?
	for id, pedestal in data.Pedestals do
		if pedestal.Creature == uid then
			return id
		end
	end
	return nil
end

local function sortedPedestalIds(data: { [string]: any }): { string }
	local ids = {}
	for id in data.Pedestals do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return (tonumber(string.sub(a, 2)) or 0) < (tonumber(string.sub(b, 2)) or 0)
	end)
	return ids
end

local function countPedestals(data: { [string]: any }): number
	local n = 0
	for _ in data.Pedestals do
		n += 1
	end
	return n
end

-- Revenu total (Coins / s) des créatures exposées sur des socles posés
local function computeIncome(data: { [string]: any }): number
	local total = 0
	for _, pedestal in data.Pedestals do
		if pedestal.Placed and pedestal.Creature then
			local entry = findCreature(data, pedestal.Creature)
			if entry then
				total += CreatureUtil.GetIncome(entry.Creature, entry.Mutation)
			end
		end
	end
	return total
end

local function syncIncome(state: State)
	local income = computeIncome(state.Data)
	if income ~= state.Income then
		state.Income = income
		SyncService:Set(state.Player, "DisplayIncome", income)
	end
end

-- "Pharaonix Spectral [Secrète]" en texte riche, couleur de la rareté
local function creatureTitle(creatureId: string, mutationId: string): string
	local rarity = CreatureUtil.GetRarity(Config.Creatures[creatureId].Rarity)
	return ('%s\n<font color="#%s">[%s]</font>'):format(CreatureUtil.Label(creatureId, mutationId), rarity.Color:ToHex(), rarity.DisplayName)
end

--------------------------------------------------------------------------
-- Socles d'exposition (sur la parcelle)
--------------------------------------------------------------------------

local function buildPedestal(state: State, id: string)
	local old = state.Pedestals[id]
	if old then
		old:Destroy()
		state.Pedestals[id] = nil
	end
	local pedestal = state.Data.Pedestals[id]
	if not pedestal or not pedestal.Placed then
		return
	end

	local origin = PlotService:ToWorld(state.Plot, 0, 0) * PlacementUtil.LocalCFrame(pedestal.X, pedestal.Z, pedestal.Rot or 0)
	local entry = pedestal.Creature and findCreature(state.Data, pedestal.Creature)
	local rarity = entry and CreatureUtil.GetRarity(Config.Creatures[entry.Creature].Rarity)
	local ringColor = if rarity then rarity.Color else Color3.fromRGB(120, 120, 130)

	local model = Instance.new("Model")
	model.Name = "Pedestal_" .. id
	model:SetAttribute("PlaceType", "Pedestal")
	model:SetAttribute("PlaceId", id)

	local base = makePart({
		Name = "Base",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.4, 5.5, 5.5),
		CFrame = origin * CFrame.new(0, 0.7, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(200, 200, 210),
		Material = Enum.Material.Marble,
		Parent = model,
	})
	local ring = makePart({
		Name = "Ring",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.25, 5.8, 5.8),
		CFrame = origin * CFrame.new(0, 1.45, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = ringColor,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = model,
	})
	local light = Instance.new("PointLight")
	light.Color = ringColor
	light.Range = 12
	light.Brightness = if entry then 2 else 0.5
	light.Parent = ring

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = if entry then "Changer de créature" else "Exposer une créature"
	prompt.ObjectText = "Socle"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OwnerOnly", true)
	prompt:SetAttribute("OpenUI", "Collection") -- le client ouvre la fenêtre des créatures
	prompt.Parent = base

	local label = makeBillboard(base, Vector2.new(9, 2.6), Vector3.new(0, 7.5, 0), 70)
	if entry then
		local creature = CreatureBuilder.Build(entry.Creature, entry.Mutation, origin * CFrame.new(0, 1.6, 0))
		creature.Parent = model
		CollectionService:AddTag(creature, SPIN_TAG)
		label.Text = ("%s\n💰 %s/s"):format(creatureTitle(entry.Creature, entry.Mutation), Format.Number(CreatureUtil.GetIncome(entry.Creature, entry.Mutation)))
	else
		label.Text = "Socle vide\n<font size=\"14\">E : exposer une créature</font>"
	end

	model.Parent = state.Plot.Model
	state.Pedestals[id] = model
end

function DisplayService:CanBuyPedestal(player: Player): (number?, string?)
	local state = states[player]
	if not state then
		return nil, "Ta ferme n'est pas encore prête."
	end
	local owned = countPedestals(state.Data)
	if owned >= DisplayConfig.MaxPedestalsByLevel[PlotService:GetLevel(player)] then
		return nil, "Agrandis ta parcelle pour placer plus de socles."
	end
	local price = DisplayConfig.PedestalPrices[owned + 1]
	if not price then
		return nil, "Nombre maximum de socles atteint."
	end
	return price, nil
end

function DisplayService:CreatePedestal(player: Player, x: number, z: number, rot: number)
	local state = states[player]
	if not state then
		return
	end
	local n = 1
	while state.Data.Pedestals["S" .. n] do
		n += 1
	end
	local id = "S" .. n
	state.Data.Pedestals[id] = { X = x, Z = z, Rot = rot, Placed = true, Creature = nil }
	buildPedestal(state, id)
	SyncService:Set(player, "Pedestals", state.Data.Pedestals)
end

function DisplayService:RefreshPedestal(player: Player, id: string)
	local state = states[player]
	if state then
		buildPedestal(state, id)
		SyncService:Set(player, "Pedestals", state.Data.Pedestals)
		syncIncome(state)
	end
end

--------------------------------------------------------------------------
-- Vitrine de prestige (devant l'entrée) + panneau "meilleure prise"
--------------------------------------------------------------------------

-- Liste des meilleurs éléments : épinglés d'abord, puis par prestige décroissant
local function showcaseEntries(data: { [string]: any }): { { [string]: any } }
	local candidates = {}
	local byUid = {}
	for _, entry in data.Creatures do
		local candidate = {
			Kind = "Creature",
			Creature = entry.Creature,
			Mutation = entry.Mutation,
			Prestige = CreatureUtil.GetPrestige(entry.Creature, entry.Mutation),
			Key = "C:" .. entry.Id,
		}
		byUid[entry.Id] = candidate
		table.insert(candidates, candidate)
	end
	-- Animaux : SEULEMENT s'ils sont épinglés (⭐ dans 🐾 Mes animaux), jamais par défaut
	local function addAnimal(speciesId: string, animal: { [string]: any })
		byUid["A:" .. tostring(animal.Id)] = {
			Kind = "Animal",
			Species = speciesId,
			Variant = animal.Variant,
			Prestige = CreatureUtil.GetAnimalPrestige(speciesId, animal.Variant),
			Key = "A:" .. tostring(animal.Id),
		}
	end
	for _, pen in data.Pens do
		if pen.Species then
			for _, animal in pen.Animals do
				addAnimal(pen.Species, animal)
			end
		end
	end
	for _, animal in data.AnimalInventory or {} do
		addAnimal(animal.Species, animal)
	end

	local result, used = {}, {}
	for _, uid in data.ShowcasePicks do
		local candidate = byUid[uid]
		if candidate and #result < ShowcaseConfig.Slots then
			table.insert(result, candidate)
			used[candidate] = true
		end
	end
	table.sort(candidates, function(a, b)
		return a.Prestige > b.Prestige
	end)
	for _, candidate in candidates do
		if #result >= ShowcaseConfig.Slots then
			break
		end
		if not used[candidate] then
			table.insert(result, candidate)
		end
	end
	return result
end

local function clearShowcase(plot: any)
	for _, slot in showcaseByPlotId[plot.Id] do
		if slot.Content then
			slot.Content:Destroy()
			slot.Content = nil
		end
		if slot.FX then
			slot.FX:Destroy()
			slot.FX = nil
		end
		slot.Ring.Color = Color3.fromRGB(120, 120, 130)
		slot.Light.Enabled = false
		slot.Label.Text = ""
	end
end

local function renderShowcase(state: State)
	local entries = showcaseEntries(state.Data)
	local keys = {}
	for _, entry in entries do
		table.insert(keys, entry.Key .. "|" .. (entry.Mutation or entry.Variant or ""))
	end
	local fxId = CosmeticUtil.EquippedId(state.Data, "ShowcaseFX") or ""
	local signature = table.concat(keys, ",") .. "|" .. fxId
	if signature == state.ShowcaseSignature then
		return -- rien n'a changé
	end
	state.ShowcaseSignature = signature

	clearShowcase(state.Plot)
	for index, slot in showcaseByPlotId[state.Plot.Id] do
		local entry = entries[index]
		if entry then
			local color, text
			if entry.Kind == "Creature" then
				local rarity = CreatureUtil.GetRarity(Config.Creatures[entry.Creature].Rarity)
				color = rarity.Color
				text = creatureTitle(entry.Creature, entry.Mutation)
				slot.Content = CreatureBuilder.Build(entry.Creature, entry.Mutation, slot.Top)
			else
				local species = Config.Animals[entry.Species]
				local variant = ItemUtil.GetVariant(entry.Variant)
				local adjective = ItemUtil.VariantAdjective(species, entry.Variant)
				color = if entry.Variant == "Normal" then Color3.fromRGB(200, 200, 200) else variant.Color
				text = ('%s %s\n<font color="#%s">[%s]</font>'):format(species.Icon, species.DisplayName .. (if adjective ~= "" then " " .. adjective else ""), color:ToHex(), if entry.Variant == "Normal" then "Ferme" else variant.DisplayName)
				slot.Content = AnimalService:BuildAnimalModel(entry.Species, entry.Variant, slot.Top)
				-- Le modèle d'animal a déjà son nom : on retire ce panneau pour éviter le doublon
				for _, descendant in (slot.Content :: Model):GetDescendants() do
					if descendant:IsA("BillboardGui") then
						descendant:Destroy()
					end
				end
			end
			local content = slot.Content :: Model
			content.Parent = state.Plot.Model
			CollectionService:AddTag(content, SPIN_TAG)
			slot.Ring.Color = color
			slot.Light.Color = color
			slot.Light.Enabled = true
			slot.Label.Text = text
		end
		-- Effet cosmétique autour de chaque socle de la vitrine
		local fx = Config.Cosmetics[fxId]
		if fx and fx.Rate then
			local particles = Instance.new("ParticleEmitter")
			particles.Color = if fx.Rainbow
				then ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
					ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 230, 80)),
					ColorSequenceKeypoint.new(0.66, Color3.fromRGB(80, 220, 120)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(100, 140, 255)),
				})
				else ColorSequence.new(fx.ParticleColor)
			particles.LightEmission = 1
			particles.Rate = fx.Rate
			particles.Lifetime = NumberRange.new(1.2, 2.2)
			particles.Speed = NumberRange.new(0.5, 1.5)
			particles.SpreadAngle = Vector2.new(180, 30)
			particles.Size = NumberSequence.new(0.3, 0)
			particles.Parent = slot.Ring
			slot.FX = particles
		end
	end

	-- Panneau de la parcelle : meilleure prise (créatures uniquement)
	local best = nil
	for _, entry in state.Data.Creatures do
		local prestige = CreatureUtil.GetPrestige(entry.Creature, entry.Mutation)
		if not best or prestige > best.Prestige then
			best = { Prestige = prestige, Creature = entry.Creature, Mutation = entry.Mutation }
		end
	end
	if best then
		local rarity = CreatureUtil.GetRarity(Config.Creatures[best.Creature].Rarity)
		PlotService:SetSignSubtitle(state.Plot, ('🌟 %s – <font color="#%s">%s</font>'):format(CreatureUtil.Label(best.Creature, best.Mutation), rarity.Color:ToHex(), rarity.DisplayName))
	else
		PlotService:SetSignSubtitle(state.Plot, nil)
	end
end

local function buildShowcase(plot: any)
	local folder = Instance.new("Folder")
	folder.Name = "Showcase"
	folder.Parent = plot.Model

	local slots: { ShowcaseSlot } = {}
	local count = ShowcaseConfig.Slots
	for i = 1, count do
		local x = (i - (count + 1) / 2) * ShowcaseConfig.Spacing
		-- Côté allée (Z négatif), posé au niveau du sol de la map (sous l'épaisseur de la parcelle).
		-- Les modèles regardent -Z, donc vers l'allée et les passants.
		local ground = PlotService:ToWorld(plot, x, -ShowcaseConfig.DistanceFromEntrance, -Config.Plots.BaseHeight)
		makePart({
			Name = "ShowcaseBase",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.6, 4.5, 4.5),
			CFrame = ground * CFrame.new(0, 0.8, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(70, 60, 90),
			Material = Enum.Material.Marble,
			Parent = folder,
		})
		local ring = makePart({
			Name = "ShowcaseRing",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.25, 4.8, 4.8),
			CFrame = ground * CFrame.new(0, 1.65, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(120, 120, 130),
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = folder,
		})
		local light = Instance.new("PointLight")
		light.Range = 10
		light.Brightness = 2.5
		light.Enabled = false
		light.Parent = ring
		local label = makeBillboard(ring, Vector2.new(8, 2.2), Vector3.new(0, 6.5, 0), 90)

		slots[i] = { Ring = ring, Light = light, Label = label, Top = ground * CFrame.new(0, 1.8, 0), Content = nil }
	end
	showcaseByPlotId[plot.Id] = slots
end

--------------------------------------------------------------------------
-- Actions du joueur
--------------------------------------------------------------------------

local function onDisplayAction(player: Player, action: any, uid: any): (boolean, string)
	if type(action) ~= "string" or type(uid) ~= "string" or #uid > 64 then
		return false, "Requête invalide."
	end
	if not RemoteGuard.CheckCooldown(player, "DisplayAction", 0.3) then
		return false, "Doucement !"
	end
	local state = states[player]
	if not state then
		return false, "Ta ferme n'est pas encore prête."
	end
	local data = state.Data
	local entry = findCreature(data, uid)
	if not entry then
		return false, "Créature introuvable."
	end
	local label = CreatureUtil.Label(entry.Creature, entry.Mutation)

	if action == "Assign" then
		if pedestalOf(data, uid) then
			return false, "Cette créature est déjà exposée."
		end
		for _, id in sortedPedestalIds(data) do
			local pedestal = data.Pedestals[id]
			if pedestal.Placed and not pedestal.Creature then
				pedestal.Creature = uid
				buildPedestal(state, id)
				GameEvents.Fire(player, "Exhibit")
				SyncService:Set(player, "Pedestals", data.Pedestals)
				syncIncome(state)
				return true, ("🏛️ %s exposé : +%s Coins/s"):format(label, Format.Number(CreatureUtil.GetIncome(entry.Creature, entry.Mutation)))
			end
		end
		return false, "Aucun socle libre : place un socle avec 🔨 Construire."
	elseif action == "Remove" then
		local id = pedestalOf(data, uid)
		if not id then
			return false, "Cette créature n'est pas exposée."
		end
		data.Pedestals[id].Creature = nil
		buildPedestal(state, id)
		SyncService:Set(player, "Pedestals", data.Pedestals)
		syncIncome(state)
		return true, label .. " retiré du socle."
	elseif action == "Pin" then
		local picks = data.ShowcasePicks
		local index = table.find(picks, uid)
		if index then
			table.remove(picks, index)
			SyncService:Set(player, "ShowcasePicks", picks)
			return true, label .. " n'est plus épinglé dans la vitrine."
		end
		if #picks >= ShowcaseConfig.Slots then
			return false, ("Vitrine pleine (%d épinglés max)."):format(ShowcaseConfig.Slots)
		end
		table.insert(picks, uid)
		SyncService:Set(player, "ShowcasePicks", picks)
		return true, "⭐ " .. label .. " épinglé dans la vitrine !"
	elseif action == "ToPen" then
		local def = Config.Creatures[entry.Creature]
		if not def.Horse then
			return false, "Seuls les chevaux sauvages vont en enclos."
		end
		if pedestalOf(data, uid) then
			return false, "Retire-le d'abord de son socle."
		end
		local variant = Config.Mounts.MutationToVariant[entry.Mutation] or "Normal"
		local ok, reason = AnimalService:GiveAnimal(player, def.Horse, variant)
		if not ok then
			return false, reason or "🐾 Mes animaux est plein."
		end
		for index, creature in data.Creatures do
			if creature.Id == uid then
				table.remove(data.Creatures, index)
				break
			end
		end
		SyncService:Set(player, "Creatures", data.Creatures)
		return true, ("🐾 %s rejoint 🐾 Mes animaux : place-le dans un enclos pour qu'il produise son crin (il reste une monture) !"):format(label)
	end
	return false, "Action inconnue."
end

--------------------------------------------------------------------------
-- Activation / boucles
--------------------------------------------------------------------------

local function sanitize(data: { [string]: any })
	local valid = {}
	for _, entry in data.Creatures do
		valid[entry.Id] = true
	end
	local taken = {}
	for id, pedestal in data.Pedestals do
		if type(pedestal) ~= "table" then
			data.Pedestals[id] = nil
			continue
		end
		pedestal.Rot = math.clamp(math.floor(tonumber(pedestal.Rot) or 0), 0, 3)
		pedestal.Placed = pedestal.Placed ~= false
		-- Créature vendue ou exposée deux fois : on libère le socle
		if pedestal.Creature and (not valid[pedestal.Creature] or taken[pedestal.Creature]) then
			pedestal.Creature = nil
		end
		if pedestal.Creature then
			taken[pedestal.Creature] = true
		end
	end
	for i = #data.ShowcasePicks, 1, -1 do
		if not valid[data.ShowcasePicks[i]] then
			table.remove(data.ShowcasePicks, i)
		end
	end
	data.DisplayLastTick = tonumber(data.DisplayLastTick) or 0
end

local function activate(player: Player, plot: any, data: { [string]: any })
	if states[player] then
		return
	end
	sanitize(data)
	local state: State = { Player = player, Plot = plot, Data = data, Pedestals = {}, ShowcaseSignature = "", Income = -1 }
	states[player] = state

	for id in data.Pedestals do
		buildPedestal(state, id)
	end
	syncIncome(state)
	SyncService:Set(player, "Pedestals", data.Pedestals)
	SyncService:Set(player, "ShowcasePicks", data.ShowcasePicks)

	-- Revenus des socles pendant l'absence du joueur
	local now = os.time()
	if data.DisplayLastTick > 0 and state.Income > 0 then
		local elapsed = math.clamp(now - data.DisplayLastTick, 0, DisplayConfig.MaxOfflineSeconds)
		local ok, added = CurrencyService:AddCoins(player, state.Income * elapsed * CurrencyService:GetCoinMultiplier(player), "DisplayOffline")
		if ok and added > 0 then
			SyncService:Notify(player, ("🏛️ Tes créatures exposées t'ont rapporté %s Coins pendant ton absence !"):format(Format.Number(added)), "Success")
		end
	end
	data.DisplayLastTick = now
	renderShowcase(state)
end

local function deactivate(player: Player, plot: any)
	local state = states[player]
	states[player] = nil
	if state then
		for _, model in state.Pedestals do
			model:Destroy()
		end
	end
	clearShowcase(plot)
end

local function incomeLoop()
	while true do
		task.wait(DisplayConfig.IncomeInterval)
		local now = os.time()
		for player, state in states do
			syncIncome(state)
			local elapsed = math.clamp(now - state.Data.DisplayLastTick, 0, DisplayConfig.IncomeInterval * 3)
			state.Data.DisplayLastTick = now
			if state.Income > 0 and elapsed > 0 then
				local multiplier = CurrencyService:GetCoinMultiplier(player)
				CurrencyService:AddCoins(player, state.Income * elapsed * multiplier, "DisplayIncome", true)
			end
		end
	end
end

local function showcaseLoop()
	while true do
		task.wait(ShowcaseConfig.RefreshInterval)
		for _, state in states do
			renderShowcase(state) -- ne reconstruit que si le contenu a changé
		end
	end
end

function DisplayService:Init()
	for _, plot in PlotService:GetAllPlots() do
		buildShowcase(plot)
	end
	PlotService:OnPlotReady(activate)
	PlotService:OnPlotReleased(deactivate)
end

function DisplayService:Start()
	Remotes.Get("DisplayAction").OnServerInvoke = onDisplayAction
	task.spawn(incomeLoop)
	task.spawn(showcaseLoop)
end

return DisplayService
