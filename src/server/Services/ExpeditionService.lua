--[[
	ExpeditionService.lua
	=====================
	Expéditions : portail, zones, créatures sauvages, capture et collection.

	  • Un PORTAIL au centre de la map ouvre l'interface des zones (OpenUI = "Portal").
	    Le client demande ("Travel", zoneId) ou ("Unlock", zoneId) via ExpeditionAction.
	  • Les ZONES (Config.Zones) sont des zones lointaines de la même place, construites
	    au démarrage (sol, falaises, décor simple, portail de retour).
	  • Des CRÉATURES SAUVAGES apparaissent dans les zones où il y a des joueurs :
	    rareté tirée selon Config.CreatureRarities[x].Weight, mutation selon
	    Config.CreatureMutations[x].Chance. Elles repartent après WildLifetime.
	  • CAPTURE : le joueur utilise le prompt "Capturer". Le serveur crée une session
	    (vitesse du curseur, positions des zones vertes) et l'envoie au client
	    (CaptureStart). À chaque clic, le client envoie le temps serveur estimé ;
	    le serveur recalcule la position du curseur (CreatureUtil.CursorPosition),
	    vérifie que le temps est plausible, compte réussites et ratés, puis fait un
	    tirage final (Capture.Chance) : même un client truqué ne garantit rien.
	  • Les créatures capturées vont dans data.Creatures (collection, Config.Expeditions.MaxCreatures).
	    Première capture d'une espèce -> data.CreatureIndex (Index de la phase 6).
	  • Vente d'une créature depuis la collection (SellCreature).
	  • Annonces (AnnouncementService) : Mythique = bannière serveur ; Secrète = chat +
	    bannière ; Divine = tous les serveurs (MessagingService).
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local CreatureUtil = require(ReplicatedStorage.Shared.CreatureUtil)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RemoteGuard = require(script.Parent.Parent.Util.RemoteGuard)
local CreatureBuilder = require(script.Parent.Parent.Util.CreatureBuilder)
local DataService = require(script.Parent.DataService)
local CurrencyService = require(script.Parent.CurrencyService)
local SyncService = require(script.Parent.SyncService)
local PlotService = require(script.Parent.PlotService)
local AnnouncementService = require(script.Parent.AnnouncementService)

local Exp = Config.Expeditions

local ExpeditionService = {}

local WANDER_TAG = "FarmAnimal" -- même promenade côté client que les animaux de ferme

type Wild = {
	Id: string,
	ZoneId: string,
	CreatureId: string,
	Mutation: string,
	Position: Vector3,
	Model: Model,
	Prompt: ProximityPrompt,
	ExpiresAt: number,
	Session: any?,
}

type Session = {
	Id: string,
	Player: Player,
	Wild: Wild,
	Start: number,
	Speed: number,
	Width: number,
	Centers: { number },
	HitsNeeded: number,
	Hits: number,
	Misses: number,
	LastHit: number,
	Expires: number,
}

type ZoneInfo = {
	Id: string,
	Def: any,
	ArrivalCFrame: CFrame,
	Folder: Folder,
	Wilds: { [string]: Wild },
}

local zones: { [string]: ZoneInfo } = {}
local playerZone: { [Player]: string } = {}
local sessions: { [Player]: Session } = {}
local portalPosition: Vector3

local rng = Random.new()

--------------------------------------------------------------------------
-- Utilitaires de construction
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
	label.RichText = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Parent = gui
	return gui, label
end

-- Portail : anneau vertical de segments néon + disque lumineux. Renvoie le point d'ancrage du prompt.
local function buildPortal(cframe: CFrame, color: Color3, parent: Instance, title: string): Part
	local radius = 6
	local center = cframe * CFrame.new(0, radius + 1.5, 0)

	makePart({
		Name = "PortalBase",
		Size = Vector3.new(16, 1, 6),
		CFrame = cframe * CFrame.new(0, 0.5, 0),
		Color = Color3.fromRGB(90, 90, 110),
		Material = Enum.Material.Slate,
		Parent = parent,
	})
	local segments = 16
	for i = 1, segments do
		local angle = (i / segments) * math.pi * 2
		makePart({
			Name = "Ring",
			Size = Vector3.new(2.6, 0.9, 0.9),
			CFrame = center * CFrame.new(math.cos(angle) * radius, math.sin(angle) * radius, 0) * CFrame.Angles(0, 0, angle + math.pi / 2),
			Color = color,
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = parent,
		})
	end
	local disc = makePart({
		Name = "Disc",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, radius * 2 - 1, radius * 2 - 1),
		CFrame = center * CFrame.Angles(0, math.pi / 2, 0),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.55,
		CanCollide = false,
		Parent = parent,
	})
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 16
	light.Brightness = 2
	light.Parent = disc

	local anchor = makePart({
		Name = "PortalPrompt",
		Size = Vector3.new(1, 1, 1),
		CFrame = cframe * CFrame.new(0, 3, -1),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = parent,
	})
	local _, label = makeBillboard(disc, Vector2.new(14, 2.5), Vector3.new(0, radius + 2.5, 0), 200)
	label.Text = title
	return anchor
end

-- Décor très simple par thème (remplacé par un vrai décor en phase 9)
local function buildProps(info: ZoneInfo, seed: number)
	local def = info.Def
	local propRng = Random.new(seed)
	local half = def.Size / 2 - 15
	local arrival = info.ArrivalCFrame.Position

	for _ = 1, 45 do
		local position = def.Center + Vector3.new(propRng:NextNumber(-half, half), 0, propRng:NextNumber(-half, half))
		if (Vector3.new(position.X, arrival.Y, position.Z) - arrival).Magnitude < 30 then
			continue
		end
		local base = CFrame.new(position) * CFrame.Angles(0, propRng:NextNumber(0, math.pi * 2), 0)

		if def.Props == "Trees" then
			local height = propRng:NextNumber(7, 12)
			makePart({ Name = "Trunk", Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, 1.6, 1.6), CFrame = base * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(110, 75, 45), Material = Enum.Material.Wood, Parent = info.Folder })
			local leaves = propRng:NextNumber(6, 9)
			makePart({ Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.one * leaves, CFrame = base * CFrame.new(0, height + leaves * 0.3, 0), Color = Color3.fromRGB(60, 140 + propRng:NextInteger(0, 40), 50), Material = Enum.Material.Grass, Parent = info.Folder })
		elseif def.Props == "Rocks" then
			local size = propRng:NextNumber(3, 9)
			makePart({ Name = "Rock", Shape = Enum.PartType.Ball, Size = Vector3.one * size, CFrame = base * CFrame.new(0, size * 0.3, 0), Color = Color3.fromRGB(120, 120, 130), Material = Enum.Material.Slate, Parent = info.Folder })
			if size > 6 then
				makePart({ Name = "Snow", Shape = Enum.PartType.Ball, Size = Vector3.one * size * 0.6, CFrame = base * CFrame.new(0, size * 0.65, 0), Color = Color3.fromRGB(245, 250, 255), Material = Enum.Material.Snow, CanCollide = false, Parent = info.Folder })
			end
		elseif def.Props == "Cacti" then
			local height = propRng:NextNumber(5, 9)
			makePart({ Name = "Cactus", Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, 1.6, 1.6), CFrame = base * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(70, 150, 70), Material = Enum.Material.Grass, Parent = info.Folder })
			for _, side in { -1, 1 } do
				makePart({ Name = "Arm", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.5, 1, 1), CFrame = base * CFrame.new(side * 1.3, height * 0.55, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(70, 150, 70), Material = Enum.Material.Grass, Parent = info.Folder })
			end
		else -- Lava
			local size = propRng:NextNumber(3, 7)
			makePart({ Name = "LavaRock", Shape = Enum.PartType.Ball, Size = Vector3.one * size, CFrame = base * CFrame.new(0, size * 0.3, 0), Color = Color3.fromRGB(35, 25, 25), Material = Enum.Material.Basalt, Parent = info.Folder })
			makePart({ Name = "LavaPool", Size = Vector3.new(size * 1.2, 0.2, size * 0.8), CFrame = base * CFrame.new(size, 0.1, 0), Color = Color3.fromRGB(255, 100, 20), Material = Enum.Material.Neon, CanCollide = false, Parent = info.Folder })
		end
	end
end

local function buildZone(zoneId: string, def: any, parent: Folder)
	local folder = Instance.new("Folder")
	folder.Name = zoneId
	folder.Parent = parent

	local size = def.Size
	makePart({
		Name = "Ground",
		Size = Vector3.new(size, 2, size),
		CFrame = CFrame.new(def.Center - Vector3.new(0, 1, 0)),
		Color = def.GroundColor,
		Material = def.GroundMaterial,
		Parent = folder,
	})

	-- Falaises tout autour : on ne tombe pas dans le vide
	local wallHeight = 16
	for _, wall in {
		{ Vector3.new(size + 8, wallHeight, 4), Vector3.new(0, wallHeight / 2, size / 2 + 2) },
		{ Vector3.new(size + 8, wallHeight, 4), Vector3.new(0, wallHeight / 2, -size / 2 - 2) },
		{ Vector3.new(4, wallHeight, size + 8), Vector3.new(size / 2 + 2, wallHeight / 2, 0) },
		{ Vector3.new(4, wallHeight, size + 8), Vector3.new(-size / 2 - 2, wallHeight / 2, 0) },
	} do
		makePart({ Name = "Cliff", Size = wall[1], CFrame = CFrame.new(def.Center + wall[2]), Color = def.WallColor, Material = Enum.Material.Rock, Parent = folder })
	end

	-- Arrivée au "sud" de la zone, tournée vers le centre ; portail de retour juste derrière
	local arrivalPosition = def.Center + Vector3.new(0, 0, -(size / 2 - 25))
	local arrivalCFrame = CFrame.lookAt(arrivalPosition + Vector3.new(0, 3, 0), def.Center + Vector3.new(0, 3, 0))
	-- Le portail de retour est derrière le point d'arrivée et regarde vers lui (+Z)
	local returnPosition = arrivalPosition - Vector3.new(0, 0, 12)
	local portalCFrame = CFrame.lookAt(returnPosition, returnPosition + Vector3.new(0, 0, 1))

	local info: ZoneInfo = { Id = zoneId, Def = def, ArrivalCFrame = arrivalCFrame, Folder = folder, Wilds = {} }
	zones[zoneId] = info

	local anchor = buildPortal(portalCFrame, Color3.fromRGB(120, 255, 160), folder, ("%s %s\n🏠 Retour à la ferme"):format(def.Icon, def.DisplayName))
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Rentrer à la ferme"
	prompt.ObjectText = "Portail"
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = Exp.PortalInteractDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor
	prompt.Triggered:Connect(function(player)
		if playerZone[player] ~= zoneId or not RemoteGuard.CheckCooldown(player, "ReturnHome", 1) then
			return
		end
		ExpeditionService:ReturnHome(player)
	end)

	buildProps(info, def.Order * 1000)
end

--------------------------------------------------------------------------
-- Créatures sauvages
--------------------------------------------------------------------------

local function rollRarity(): string
	local total = 0
	for _, rarity in Config.CreatureRarities do
		total += rarity.Weight
	end
	local roll = rng:NextNumber(0, total)
	for _, id in CreatureUtil.SortedRarities() do
		roll -= Config.CreatureRarities[id].Weight
		if roll <= 0 then
			return id
		end
	end
	return "Common"
end

local function rollMutation(): string
	local roll = rng:NextNumber()
	local cumulative = 0
	local ids = CreatureUtil.SortedMutations()
	for i = #ids, 1, -1 do -- de la plus rare à la plus commune
		local id = ids[i]
		cumulative += Config.CreatureMutations[id].Chance
		if id ~= "Normal" and roll < cumulative then
			return id
		end
	end
	return "Normal"
end

-- Choisit une créature de la zone avec la rareté tirée (ou la plus proche en dessous)
local function pickCreature(zoneId: string): string?
	local rarityId = rollRarity()
	local rarityOrder = CreatureUtil.GetRarity(rarityId).Order
	local candidates = CreatureUtil.CreaturesInZone(zoneId)
	for order = rarityOrder, 1, -1 do
		local matching = {}
		for _, id in candidates do
			if CreatureUtil.GetRarity(Config.Creatures[id].Rarity).Order == order then
				table.insert(matching, id)
			end
		end
		if #matching > 0 then
			return matching[rng:NextInteger(1, #matching)]
		end
	end
	return nil
end

local function destroyWild(wild: Wild)
	local zone = zones[wild.ZoneId]
	if zone then
		zone.Wilds[wild.Id] = nil
	end
	if wild.Model then
		wild.Model:Destroy()
	end
end

local startCapture: (Player, Wild) -> ()

local function spawnWild(info: ZoneInfo)
	local creatureId = pickCreature(info.Id)
	if not creatureId then
		return
	end
	local def = info.Def
	local half = def.Size / 2 - 20
	local arrival = info.ArrivalCFrame.Position

	-- Position au hasard, loin de l'arrivée
	local position
	for _ = 1, 10 do
		local candidate = def.Center + Vector3.new(rng:NextNumber(-half, half), 0, rng:NextNumber(-half, half))
		if (Vector3.new(candidate.X, arrival.Y, candidate.Z) - arrival).Magnitude > 30 then
			position = candidate
			break
		end
	end
	if not position then
		return
	end

	local mutationId = rollMutation()
	local groundCFrame = CFrame.new(position) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local model, body = CreatureBuilder.Build(creatureId, mutationId, groundCFrame)
	model:SetAttribute("WanderCenter", position)
	model:SetAttribute("WanderRadius", Exp.WildWanderRadius)

	local creatureDef = Config.Creatures[creatureId]
	local rarity = CreatureUtil.GetRarity(creatureDef.Rarity)
	local label = CreatureUtil.Label(creatureId, mutationId)
	local height = model:GetExtentsSize().Y
	local _, nameLabel = makeBillboard(body, Vector2.new(8, 2), Vector3.new(0, height / 2 + 1.5, 0), 70)
	nameLabel.Text = ('%s\n<font color="#%s">[%s]</font>'):format(label, rarity.Color:ToHex(), rarity.DisplayName)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Capturer"
	prompt.ObjectText = ("%s (%s)"):format(label, rarity.DisplayName)
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Exp.CaptureDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = body

	local wild: Wild = {
		Id = HttpService:GenerateGUID(false),
		ZoneId = info.Id,
		CreatureId = creatureId,
		Mutation = mutationId,
		Position = position,
		Model = model,
		Prompt = prompt,
		ExpiresAt = os.clock() + Exp.WildLifetime,
		Session = nil,
	}
	prompt.Triggered:Connect(function(player)
		startCapture(player, wild)
	end)

	model.Parent = info.Folder
	CollectionService:AddTag(model, WANDER_TAG)
	info.Wilds[wild.Id] = wild
end

local function spawnLoop()
	while true do
		task.wait(Exp.SpawnInterval)
		local now = os.clock()
		for zoneId, info in zones do
			-- Les créatures trop anciennes repartent (sauf pendant une capture)
			for _, wild in info.Wilds do
				if now > wild.ExpiresAt and not wild.Session then
					destroyWild(wild)
				end
			end
			-- Apparition seulement s'il y a des joueurs dans la zone
			local hasPlayers = false
			for _, z in playerZone do
				if z == zoneId then
					hasPlayers = true
					break
				end
			end
			local count = 0
			for _ in info.Wilds do
				count += 1
			end
			if hasPlayers and count < Exp.MaxWildPerZone then
				spawnWild(info)
			end
		end
	end
end

--------------------------------------------------------------------------
-- Capture
--------------------------------------------------------------------------

local function announce(player: Player, creatureId: string, mutationId: string)
	local def = Config.Creatures[creatureId]
	local rarity = CreatureUtil.GetRarity(def.Rarity)
	if not rarity.Announce then
		return
	end
	local text = ("🌟 %s a capturé %s [%s] !"):format(player.DisplayName, CreatureUtil.Label(creatureId, mutationId), rarity.DisplayName)
	AnnouncementService:Announce(text, rarity.Color, rarity.Announce)
end

local function giveCreature(player: Player, creatureId: string, mutationId: string): boolean
	local data = DataService:GetData(player)
	if not data or #data.Creatures >= Exp.MaxCreatures then
		return false
	end
	table.insert(data.Creatures, {
		Id = HttpService:GenerateGUID(false),
		Creature = creatureId,
		Mutation = mutationId,
		CaughtAt = os.time(),
	})
	local isNew = not data.CreatureIndex[creatureId]
	data.CreatureIndex[creatureId] = true
	SyncService:Set(player, "Creatures", data.Creatures)
	if isNew then
		SyncService:Set(player, "CreatureIndex", data.CreatureIndex)
		SyncService:Notify(player, ("📖 Nouvelle créature découverte : %s !"):format(Config.Creatures[creatureId].DisplayName), "Rare")
	end
	return true
end

-- Termine une session. outcome : "Captured" | "Escaped" | "Cancelled" | "Timeout"
local function endSession(session: Session, outcome: string, fromServer: boolean): string
	local player = session.Player
	local wild = session.Wild
	if sessions[player] == session then
		sessions[player] = nil
	end
	wild.Session = nil

	local label = CreatureUtil.Label(wild.CreatureId, wild.Mutation)
	local message
	if outcome == "Captured" then
		if giveCreature(player, wild.CreatureId, wild.Mutation) then
			message = ("🎉 Tu as capturé %s !"):format(label)
			SyncService:Notify(player, message, if wild.Mutation ~= "Normal" then "Rare" else "Success")
			announce(player, wild.CreatureId, wild.Mutation)
		else
			message = "Ta collection est pleine !"
		end
		destroyWild(wild)
	elseif outcome == "Escaped" then
		message = ("💨 %s s'est échappé..."):format(label)
		SyncService:Notify(player, message, "Error")
		destroyWild(wild)
	else
		-- Annulé / trop lent : la créature reste, quelqu'un d'autre peut tenter
		message = if outcome == "Timeout" then "Trop lent : la créature s'est libérée." else "Capture annulée."
		if wild.Model and wild.Model.Parent then
			wild.Prompt.Enabled = true
			wild.Model:SetAttribute("Frozen", nil)
		end
	end

	if fromServer and player.Parent then
		Remotes.Get("CaptureEnded"):FireClient(player, session.Id, outcome, message)
	end
	return message
end

startCapture = function(player: Player, wild: Wild)
	if playerZone[player] ~= wild.ZoneId or wild.Session or not wild.Model.Parent then
		return
	end
	if sessions[player] then
		return
	end
	if not RemoteGuard.CheckCooldown(player, "StartCapture", 1) then
		return
	end
	if not RemoteGuard.IsNear(player, wild.Position, Exp.CaptureDistance + Exp.WildWanderRadius + 4) then
		return
	end
	local data = DataService:GetData(player)
	if not data then
		return
	end
	if #data.Creatures >= Exp.MaxCreatures then
		SyncService:Notify(player, ("Ta collection est pleine (%d) ! Vends des créatures."):format(Exp.MaxCreatures), "Error")
		return
	end

	local def = Config.Creatures[wild.CreatureId]
	local rarity = CreatureUtil.GetRarity(def.Rarity)
	local capture = rarity.Capture

	-- Paramètres générés par le serveur
	local centers = {}
	for i = 1, capture.Hits do
		centers[i] = rng:NextNumber(capture.Width / 2 + 0.05, 1 - capture.Width / 2 - 0.05)
	end
	local now = Workspace:GetServerTimeNow()
	local session: Session = {
		Id = HttpService:GenerateGUID(false),
		Player = player,
		Wild = wild,
		Start = now + 0.5, -- petit délai pour que l'interface apparaisse
		Speed = capture.Speed,
		Width = capture.Width,
		Centers = centers,
		HitsNeeded = capture.Hits,
		Hits = 0,
		Misses = 0,
		LastHit = now,
		Expires = now + Exp.CaptureTimeout,
	}
	sessions[player] = session
	wild.Session = session
	wild.Prompt.Enabled = false
	wild.Model:SetAttribute("Frozen", true) -- la créature arrête de marcher

	Remotes.Get("CaptureStart"):FireClient(player, {
		SessionId = session.Id,
		Start = session.Start,
		Speed = session.Speed,
		Width = session.Width,
		Centers = centers,
		HitsNeeded = session.HitsNeeded,
		MaxMisses = Exp.MaxMisses,
		Label = CreatureUtil.Label(wild.CreatureId, wild.Mutation),
		RarityName = rarity.DisplayName,
		RarityColor = rarity.Color,
		Model = wild.Model,
	})
end

local function onCaptureAction(player: Player, action: any, sessionId: any, claimedTime: any): { [string]: any }
	local session = sessions[player]
	if not session or session.Id ~= sessionId then
		return { Result = "NoSession" }
	end

	if action == "Cancel" then
		return { Result = "Ended", Outcome = "Cancelled", Message = endSession(session, "Cancelled", false) }
	end
	if action ~= "Hit" or not RemoteGuard.IsValidNumber(claimedTime) then
		return { Result = "Invalid" }
	end

	-- Le temps envoyé doit être plausible : ni dans le futur, ni trop vieux, ni avant le clic précédent
	local now = Workspace:GetServerTimeNow()
	local plausible = claimedTime <= now + 0.1 and claimedTime >= now - Exp.MaxLatency and claimedTime >= session.Start and claimedTime > session.LastHit + 0.15

	local hit = false
	if plausible then
		local position = CreatureUtil.CursorPosition(session.Start, session.Speed, claimedTime)
		local center = session.Centers[session.Hits + 1]
		hit = math.abs(position - center) <= session.Width / 2 + Exp.HitTolerance
	end
	session.LastHit = math.max(session.LastHit, math.min(claimedTime, now))

	if hit then
		session.Hits += 1
		if session.Hits >= session.HitsNeeded then
			-- Tirage final selon la rareté
			local chance = CreatureUtil.GetRarity(Config.Creatures[session.Wild.CreatureId].Rarity).Capture.Chance
			local outcome = if rng:NextNumber() <= chance then "Captured" else "Escaped"
			return { Result = "Ended", Outcome = outcome, Message = endSession(session, outcome, false) }
		end
		return { Result = "Hit", Hits = session.Hits, Misses = session.Misses }
	end

	session.Misses += 1
	if session.Misses > Exp.MaxMisses then
		return { Result = "Ended", Outcome = "Escaped", Message = endSession(session, "Escaped", false) }
	end
	return { Result = "Miss", Hits = session.Hits, Misses = session.Misses }
end

-- true si le personnage du joueur est dans les limites de la zone
local function isInZone(player: Player, zoneId: string): boolean
	local info = zones[zoneId]
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not info or not root or not root:IsA("BasePart") then
		return false
	end
	local offset = root.Position - info.Def.Center
	local half = info.Def.Size / 2 + 10
	return math.abs(offset.X) <= half and math.abs(offset.Z) <= half
end

-- Surveille les sessions (délai dépassé, joueur trop loin) et les joueurs sortis d'une zone
-- (bouton Ma ferme, visite d'une parcelle...)
local function sessionLoop()
	while true do
		task.wait(0.5)
		for player, zoneId in playerZone do
			if not isInZone(player, zoneId) then
				playerZone[player] = nil
			end
		end
		local now = Workspace:GetServerTimeNow()
		for player, session in sessions do
			if now > session.Expires then
				endSession(session, "Timeout", true)
			elseif not RemoteGuard.IsNear(player, session.Wild.Position, Exp.CaptureDistance * 3) then
				endSession(session, "Cancelled", true)
			end
		end
	end
end

--------------------------------------------------------------------------
-- Voyage, déblocage, vente
--------------------------------------------------------------------------

function ExpeditionService:GetZone(player: Player): string?
	return playerZone[player]
end

function ExpeditionService:ReturnHome(player: Player)
	local session = sessions[player]
	if session then
		endSession(session, "Cancelled", true)
	end
	playerZone[player] = nil
	PlotService:TeleportHome(player)
end

local function teleportTo(player: Player, cframe: CFrame)
	-- Charge la zone autour du point d'arrivée avant de déplacer le joueur (StreamingEnabled)
	pcall(function()
		player:RequestStreamAroundAsync(cframe.Position, 5)
	end)
	local character = player.Character
	if character and character.PrimaryPart then
		character:PivotTo(cframe)
	end
end

local function onExpeditionAction(player: Player, action: any, zoneId: any): (boolean, string)
	if type(zoneId) ~= "string" or not Config.Zones[zoneId] then
		return false, "Zone inconnue."
	end
	if not RemoteGuard.CheckCooldown(player, "ExpeditionAction", 0.5) then
		return false, "Doucement !"
	end
	if not RemoteGuard.IsNear(player, portalPosition, Exp.PortalInteractDistance + 8) then
		return false, "Approche-toi du portail."
	end
	local data = DataService:GetData(player)
	if not data then
		return false, "Données pas encore chargées."
	end
	local def = Config.Zones[zoneId]

	if action == "Unlock" then
		if data.UnlockedZones[zoneId] then
			return false, "Zone déjà débloquée."
		end
		if not CurrencyService:SpendCoins(player, def.UnlockPrice, "UnlockZone:" .. zoneId) then
			return false, ("Il te faut %s Coins."):format(Format.Number(def.UnlockPrice))
		end
		data.UnlockedZones[zoneId] = true
		SyncService:Set(player, "UnlockedZones", data.UnlockedZones)
		return true, ("%s %s débloquée !"):format(def.Icon, def.DisplayName)
	elseif action == "Travel" then
		if not data.UnlockedZones[zoneId] and def.UnlockPrice > 0 then
			return false, "Débloque d'abord cette zone."
		end
		-- Téléportation D'ABORD (elle attend le chargement de la zone), puis on note la zone :
		-- sinon la vérification "est-il dans la zone ?" le retirerait pendant l'attente
		teleportTo(player, zones[zoneId].ArrivalCFrame)
		playerZone[player] = zoneId
		return true, ("Bienvenue : %s %s ! Approche-toi d'une créature pour la capturer."):format(def.Icon, def.DisplayName)
	end
	return false, "Action inconnue."
end

local function onSellCreature(player: Player, creatureUid: any): (boolean, string)
	if type(creatureUid) ~= "string" or #creatureUid > 64 then
		return false, "Requête invalide."
	end
	if not RemoteGuard.CheckCooldown(player, "SellCreature", 0.2) then
		return false, "Doucement !"
	end
	local data = DataService:GetData(player)
	if not data then
		return false, "Données pas encore chargées."
	end
	for _, pedestal in data.Pedestals do
		if pedestal.Creature == creatureUid then
			return false, "Cette créature est exposée : retire-la d'abord de son socle."
		end
	end
	for index, entry in data.Creatures do
		if entry.Id == creatureUid then
			local value = CreatureUtil.GetValue(entry.Creature, entry.Mutation)
			table.remove(data.Creatures, index)
			SyncService:Set(player, "Creatures", data.Creatures)
			CurrencyService:AddCoins(player, value, "SellCreature:" .. entry.Creature)
			return true, ("%s vendu : +%s Coins"):format(CreatureUtil.Label(entry.Creature, entry.Mutation), Format.Number(value))
		end
	end
	return false, "Créature introuvable."
end

--------------------------------------------------------------------------
-- Cycle de vie
--------------------------------------------------------------------------

local function sanitize(data: { [string]: any })
	for i = #data.Creatures, 1, -1 do
		local entry = data.Creatures[i]
		if type(entry) ~= "table" or not CreatureUtil.Get(entry.Creature) or not CreatureUtil.IsValidMutation(entry.Mutation) then
			table.remove(data.Creatures, i)
		else
			entry.Id = entry.Id or HttpService:GenerateGUID(false)
		end
	end
	data.UnlockedZones.Forest = true
end

function ExpeditionService:Init()
	local root = Instance.new("Folder")
	root.Name = "Expeditions"
	root.Parent = Workspace
	for zoneId, def in Config.Zones do
		buildZone(zoneId, def, root)
	end

	-- Portail principal, devant le spawn, tourné vers lui (-Z)
	portalPosition = Exp.PortalPosition
	local portalCFrame = CFrame.lookAt(portalPosition, portalPosition + Vector3.new(0, 0, -1))
	local anchor = buildPortal(portalCFrame, Color3.fromRGB(150, 90, 255), Workspace, "🧭 EXPÉDITIONS")
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Partir en expédition"
	prompt.ObjectText = "Portail"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Exp.PortalInteractDistance
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OpenUI", "Portal") -- le client ouvre la liste des zones
	prompt.Parent = anchor

	DataService:OnProfileLoaded(function(_player, data)
		sanitize(data)
	end)
end

function ExpeditionService:Start()
	Remotes.Get("ExpeditionAction").OnServerInvoke = onExpeditionAction
	Remotes.Get("CaptureAction").OnServerInvoke = onCaptureAction
	Remotes.Get("SellCreature").OnServerInvoke = onSellCreature

	local function onPlayerAdded(player: Player)
		-- Mort / réapparition : le joueur revient à sa ferme (PlotService), il quitte donc la zone
		player.CharacterAdded:Connect(function()
			local session = sessions[player]
			if session then
				endSession(session, "Cancelled", true)
			end
			playerZone[player] = nil
		end)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local session = sessions[player]
		if session then
			endSession(session, "Cancelled", false)
		end
		playerZone[player] = nil
	end)

	task.spawn(spawnLoop)
	task.spawn(sessionLoop)
end

return ExpeditionService
