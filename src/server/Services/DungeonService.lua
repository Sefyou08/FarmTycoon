--[[
	DungeonService.lua
	==================
	Donjons (phase 8) : un portail rouge sur la map ouvre la liste des donjons
	(OpenUI = "Dungeon"). Chaque partie est SOLO, dans une arène réservée au
	joueur, loin de la map.

	Déroulement : vagues d'ennemis (Config.Dungeons[x].Waves), puis un boss, puis
	récompenses (Coins, XP, graines rares, œufs de créatures, ingrédients rares).

	Combat (tout est décidé par le serveur) :
	  • PV du joueur propres au donjon (pas la vie Roblox) : Config.Combat, selon le
	    niveau, x (1 + boost "Combat") ; les dégâts reçus sont divisés par ce même facteur.
	  • ⚔️ Attaque (RemoteEvent DungeonAttack) : cooldown serveur ; le serveur frappe
	    l'ennemi le plus proche à portée.
	  • 💨 Esquive (RemoteEvent DungeonDodge) : invulnérabilité courte, cooldown serveur ;
	    le bond est fait par le client.
	  • Ennemis : ils avancent vers le joueur, deviennent ROUGES pendant WindUp avant
	    de frapper (le temps d'esquiver ou de s'éloigner). Les boss font en plus une
	    attaque de zone annoncée par un cercle rouge au sol.
	  • Défaite : PV à 0, mort du personnage, sortie de l'arène, ou délai dépassé.

	Performance : les ennemis n'existent côté serveur QUE sous forme de données
	(position, état, PV). Le serveur envoie au joueur un petit instantané 10 fois par
	seconde (RemoteEvent "DungeonEnemies" : positions + événements "touché", "mort",
	"attaque de zone"...), et c'est le CLIENT qui crée les modèles, les fait bouger en
	douceur et joue toutes les animations et tous les effets. L'état (PV, vague, boss)
	part par "DungeonState", au plus 5 fois par seconde et seulement s'il a changé.

	RemoteFunction "DungeonAction" : ("Enter", dungeonId) | ("Leave").
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local ItemUtil = require(ReplicatedStorage.Shared.ItemUtil)
local CropUtil = require(ReplicatedStorage.Shared.CropUtil)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RemoteGuard = require(script.Parent.Parent.Util.RemoteGuard)
local GameEvents = require(script.Parent.Parent.Util.GameEvents)
local ArenaDecor = require(script.Parent.Parent.Util.ArenaDecor)
local ArtKit = require(script.Parent.Parent.Util.ArtKit)
local DataService = require(script.Parent.DataService)
local SyncService = require(script.Parent.SyncService)
local CurrencyService = require(script.Parent.CurrencyService)
local InventoryService = require(script.Parent.InventoryService)
local BoostService = require(script.Parent.BoostService)
local XPService = require(script.Parent.XPService)
local PlotService = require(script.Parent.PlotService)
local MovementService = require(script.Parent.MovementService)

local Combat = Config.Combat

local DungeonService = {}

local TICK = 0.1 -- simulation et instantanés : 10 fois par seconde
local STATE_INTERVAL = 0.2 -- état (PV, vague, boss) : au plus 5 fois par seconde
local MAX_ARENAS = Config.Plots.Count -- une arène par joueur possible

type Enemy = {
	Id: number,
	Key: string, -- id de Config.Enemies (le client construit le modèle à partir de lui)
	Def: any,
	HP: number,
	MaxHP: number,
	Position: Vector3,
	Yaw: number, -- orientation (radians), pour le client
	State: string, -- "Chase" | "WindUp" | "Cooldown" | "Slam"
	StateUntil: number,
	NextSlam: number,
}

type Run = {
	Player: Player,
	DungeonId: string,
	Def: any,
	Arena: { [string]: any },
	Wave: number, -- 1..#Waves, puis #Waves + 1 = boss
	Enemies: { [number]: Enemy },
	HP: number,
	MaxHP: number,
	Damage: number,
	Defense: number,
	InvulnerableUntil: number,
	NextAttack: number,
	NextDodge: number,
	NextWaveAt: number?,
	State: string, -- "Fighting" | "Ended"
	StartedAt: number,
	Dirty: boolean,
	LastStateSent: number,
	Events: { { any } }, -- événements à envoyer avec le prochain instantané (effets côté client)
	BossName: string?,
}

local runs: { [Player]: Run } = {}
local arenas: { { [string]: any } } = {}
local enemyCounter = 0
local rng = Random.new()
local portalPosition: Vector3

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

local function getRoot(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

--------------------------------------------------------------------------
-- Arènes (construites une fois au démarrage, recolorées par donjon)
--------------------------------------------------------------------------

local function buildArena(index: number)
	local size = Combat.ArenaSize
	local origin = Combat.ArenaOrigin + Vector3.new((index - 1) * Combat.ArenaSpacing, 0, 0)
	local folder = Instance.new("Folder")
	folder.Name = "Arena_" .. index
	folder.Parent = Workspace:FindFirstChild("Dungeons")

	local floor = makePart({ Name = "Floor", Size = Vector3.new(size, 2, size), CFrame = CFrame.new(origin - Vector3.new(0, 1, 0)), Material = Enum.Material.Slate, Parent = folder })
	local walls = {}
	for _, wall in {
		{ Vector3.new(size + 8, 20, 4), Vector3.new(0, 10, size / 2 + 2) },
		{ Vector3.new(size + 8, 20, 4), Vector3.new(0, 10, -size / 2 - 2) },
		{ Vector3.new(4, 20, size + 8), Vector3.new(size / 2 + 2, 10, 0) },
		{ Vector3.new(4, 20, size + 8), Vector3.new(-size / 2 - 2, 10, 0) },
	} do
		table.insert(walls, makePart({ Name = "Wall", Size = wall[1], CFrame = CFrame.new(origin + wall[2]), Material = Enum.Material.Rock, Parent = folder }))
	end
	-- Murs invisibles très hauts au-dessus des murs visibles : on ne saute pas hors de l'arène
	for _, wall in {
		{ Vector3.new(size + 8, Config.Bounds.WallHeight, 4), Vector3.new(0, Config.Bounds.WallHeight / 2, size / 2 + 2) },
		{ Vector3.new(size + 8, Config.Bounds.WallHeight, 4), Vector3.new(0, Config.Bounds.WallHeight / 2, -size / 2 - 2) },
		{ Vector3.new(4, Config.Bounds.WallHeight, size + 8), Vector3.new(size / 2 + 2, Config.Bounds.WallHeight / 2, 0) },
		{ Vector3.new(4, Config.Bounds.WallHeight, size + 8), Vector3.new(-size / 2 - 2, Config.Bounds.WallHeight / 2, 0) },
	} do
		makePart({ Name = "InvisibleWall", Size = wall[1], CFrame = CFrame.new(origin + wall[2]), Transparency = 1, CanQuery = false, Parent = folder })
	end
	-- Quelques piliers pour se mettre à l'abri
	for _, offset in { Vector3.new(-25, 0, -15), Vector3.new(25, 0, -15), Vector3.new(-25, 0, 20), Vector3.new(25, 0, 20) } do
		table.insert(walls, makePart({ Name = "Pillar", Shape = Enum.PartType.Cylinder, Size = Vector3.new(14, 5, 5), CFrame = CFrame.new(origin + offset + Vector3.new(0, 7, 0)) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Rock, Parent = folder }))
	end

	local enemies = Instance.new("Folder")
	enemies.Name = "Enemies"
	enemies.Parent = folder

	arenas[index] = {
		Index = index,
		Origin = origin,
		Floor = floor,
		Walls = walls,
		EnemyFolder = enemies,
		EntryCFrame = CFrame.lookAt(origin + Vector3.new(0, 3, size / 2 - 12), origin + Vector3.new(0, 3, 0)),
		Owner = nil,
	}
end

local function freeArena(): { [string]: any }?
	for _, arena in arenas do
		if not arena.Owner then
			return arena
		end
	end
	return nil
end

--------------------------------------------------------------------------
-- Ennemis
--------------------------------------------------------------------------

local function spawnEnemy(run: Run, enemyId: string)
	local def = Config.Enemies[enemyId]
	if not def then
		warn("[DungeonService] Ennemi inconnu : " .. tostring(enemyId))
		return
	end
	local origin = run.Arena.Origin
	local root = getRoot(run.Player)
	local half = Combat.ArenaSize / 2 - 10
	-- Position au hasard, pas trop près du joueur
	local position = origin
	for _ = 1, 10 do
		local candidate = origin + Vector3.new(rng:NextNumber(-half, half), 0, rng:NextNumber(-half, half * 0.3))
		if not root or (flat(candidate) - flat(root.Position)).Magnitude > 25 then
			position = candidate
			break
		end
	end
	if def.Boss then
		position = origin + Vector3.new(0, 0, -Combat.ArenaSize / 4)
	end

	-- Aucune Part côté serveur : juste des données (le client dessine l'ennemi)
	enemyCounter += 1
	run.Enemies[enemyCounter] = {
		Id = enemyCounter,
		Key = enemyId,
		Def = def,
		HP = def.HP,
		MaxHP = def.HP,
		Position = position,
		Yaw = 0,
		State = "Chase",
		StateUntil = 0,
		NextSlam = os.clock() + (def.SlamInterval or math.huge),
	}
	if def.Boss then
		run.BossName = def.DisplayName
	end
end

local function removeEnemy(run: Run, enemy: Enemy)
	run.Enemies[enemy.Id] = nil
end

-- Instantané compact des ennemis + événements, envoyé au joueur (10 fois par seconde max)
local function sendSnapshot(run: Run)
	local list = {}
	for id, enemy in run.Enemies do
		-- { id, clé, x, z, orientation, PV, état } : quelques nombres par ennemi
		table.insert(list, { id, enemy.Key, math.floor(enemy.Position.X * 10) / 10, math.floor(enemy.Position.Z * 10) / 10, math.floor(enemy.Yaw * 100) / 100, math.max(0, math.floor(enemy.HP)), enemy.State })
	end
	Remotes.Get("DungeonEnemies"):FireClient(run.Player, list, run.Events)
	run.Events = {}
end

--------------------------------------------------------------------------
-- État envoyé au client
--------------------------------------------------------------------------

local function sendState(run: Run, extra: { [string]: any }?)
	local boss = nil
	for _, enemy in run.Enemies do
		if enemy.Def.Boss then
			boss = enemy
		end
	end
	local count = 0
	for _ in run.Enemies do
		count += 1
	end
	local state = {
		Active = run.State == "Fighting",
		DungeonName = run.Def.Icon .. " " .. run.Def.DisplayName,
		Wave = math.min(run.Wave, #run.Def.Waves),
		TotalWaves = #run.Def.Waves,
		IsBoss = run.Wave > #run.Def.Waves,
		BossName = run.BossName,
		BossHP = if boss then boss.HP else 0,
		BossMaxHP = if boss then boss.MaxHP else 1,
		HP = run.HP,
		MaxHP = run.MaxHP,
		Enemies = count,
		NextWaveAt = run.NextWaveAt,
		ArenaY = run.Arena.Origin.Y,
	}
	if extra then
		for key, value in extra do
			state[key] = value
		end
	end
	Remotes.Get("DungeonState"):FireClient(run.Player, state)
	run.Dirty = false
	run.LastStateSent = os.clock()
end

--------------------------------------------------------------------------
-- Fin de partie
--------------------------------------------------------------------------

local function rollRange(range: { number }): number
	return rng:NextInteger(range[1], range[2])
end

-- Distribue les récompenses ; renvoie le texte du résumé
local function giveRewards(run: Run): string
	local player = run.Player
	local data = DataService:GetData(player)
	local rewards = run.Def.Rewards
	local parts = {}

	local coins = rollRange(rewards.Coins)
	if data and not (data.DungeonClears[run.DungeonId] and data.DungeonClears[run.DungeonId] > 0) then
		coins += rewards.FirstClearBonus or 0
		table.insert(parts, "🏅 1re victoire !")
	end
	if data then
		data.DungeonClears[run.DungeonId] = (data.DungeonClears[run.DungeonId] or 0) + 1
		SyncService:Set(player, "DungeonClears", data.DungeonClears)
	end
	CurrencyService:AddCoins(player, coins, "Dungeon:" .. run.DungeonId)
	table.insert(parts, "💰 " .. Format.Number(coins))
	XPService:AddXP(player, rewards.XP)
	table.insert(parts, ("⭐ %d XP"):format(rewards.XP))

	for _, loot in rewards.Loot do
		if rng:NextNumber() < loot.Chance then
			local amount = rollRange(loot.Amount)
			if loot.Kind == "Seeds" then
				local added = InventoryService:AddSeeds(player, loot.Id, amount)
				if added > 0 then
					table.insert(parts, ("%d graine(s) %s"):format(added, CropUtil.Label(loot.Id)))
				end
			else
				local variant = loot.Variant or "Normal"
				if InventoryService:AddItem(player, loot.Id, variant, amount) then
					table.insert(parts, ("%d %s"):format(amount, ItemUtil.Label(loot.Id, variant)))
				else
					-- Sac plein : le butin est converti en Coins pour ne rien perdre
					local value = ItemUtil.UnitValue(loot.Id, variant) * amount
					CurrencyService:AddCoins(player, value, "DungeonLootOverflow")
					table.insert(parts, ("%d %s (sac plein : +%s Coins)"):format(amount, ItemUtil.Label(loot.Id, variant), Format.Number(value)))
				end
			end
		end
	end
	return table.concat(parts, "  •  ")
end

-- outcome : "Victory" | "Defeat" | "Abandon"
local function endRun(run: Run, outcome: string, reason: string?)
	if run.State == "Ended" then
		return
	end
	run.State = "Ended"
	local player = run.Player

	for _, enemy in run.Enemies do
		removeEnemy(run, enemy)
	end
	if player.Parent then
		sendSnapshot(run) -- le client retire les modèles restants
	end

	local message
	if outcome == "Victory" then
		local summary = giveRewards(run)
		GameEvents.Fire(player, "DungeonWin")
		message = ("🏆 Victoire : %s !\n%s"):format(run.Def.DisplayName, summary)
		SyncService:Notify(player, "🏆 Donjon terminé ! " .. summary, "Rare")
	elseif outcome == "Defeat" then
		message = "💀 Défaite... " .. (reason or "Tes PV sont tombés à 0.") .. " Mange un boost ⚔️ Combat et réessaie !"
		SyncService:Notify(player, message, "Error")
	else
		message = reason or "Tu as quitté le donjon."
	end
	if player.Parent then
		sendState(run, { Active = false, Ended = true, Outcome = outcome, Message = message })
		player:SetAttribute("InDungeon", nil)
	end

	-- Retour à la ferme après un court délai (le temps de lire le résultat)
	task.delay(if outcome == "Abandon" then 0 else Combat.EndDelay, function()
		if runs[player] == run then
			runs[player] = nil
		end
		run.Arena.Owner = nil
		-- Victoire / défaite : retour à la ferme. Abandon : le joueur est déjà parti (ou "Quitter"
		-- l'a déjà téléporté).
		if player.Parent and outcome ~= "Abandon" then
			PlotService:TeleportHome(player)
		end
	end)
end

--------------------------------------------------------------------------
-- Boucle de combat
--------------------------------------------------------------------------

local function damagePlayer(run: Run, amount: number)
	local now = os.clock()
	if now < run.InvulnerableUntil then
		table.insert(run.Events, { "Dodged" })
		return
	end
	local damage = math.floor(amount / run.Defense + 0.5)
	run.HP = math.max(0, run.HP - damage)
	table.insert(run.Events, { "PlayerHit", damage })
	run.Dirty = true
	if run.HP <= 0 then
		sendState(run)
		endRun(run, "Defeat")
	end
end

local function nextWave(run: Run)
	run.Wave += 1
	run.NextWaveAt = nil
	if run.Wave <= #run.Def.Waves then
		for _, enemyId in run.Def.Waves[run.Wave] do
			spawnEnemy(run, enemyId)
		end
		SyncService:Notify(run.Player, ("⚔️ Vague %d / %d !"):format(run.Wave, #run.Def.Waves), "Info")
	else
		spawnEnemy(run, run.Def.Boss)
		SyncService:Notify(run.Player, ("👑 BOSS : %s ! Esquive son attaque de zone (cercle rouge) !"):format(Config.Enemies[run.Def.Boss].DisplayName), "Rare")
	end
	run.Dirty = true
end

local function updateEnemy(run: Run, enemy: Enemy, rootPosition: Vector3, now: number)
	local def = enemy.Def
	local toPlayer = flat(rootPosition) - flat(enemy.Position)
	local distance = toPlayer.Magnitude
	local reach = def.AttackRange + def.Size / 2
	if distance > 0.1 then
		enemy.Yaw = math.atan2(-toPlayer.X, -toPlayer.Z) -- regarde le joueur
	end

	if enemy.State == "Chase" then
		-- Boss : attaque de zone à intervalle régulier (le client affiche le cercle rouge)
		if def.Boss and now >= enemy.NextSlam then
			enemy.State = "Slam"
			enemy.StateUntil = now + def.SlamWindup
			table.insert(run.Events, { "SlamStart", enemy.Id, def.SlamRadius, def.SlamWindup })
			return
		end
		if distance <= reach then
			enemy.State = "WindUp" -- le client le fait devenir rouge et armer son coup
			enemy.StateUntil = now + def.WindUp
		elseif distance > 0.1 then
			local step = math.min(def.Speed * TICK, distance - reach * 0.8)
			if step > 0 then
				enemy.Position += toPlayer.Unit * step
			end
		end
	elseif enemy.State == "WindUp" then
		if now >= enemy.StateUntil then
			table.insert(run.Events, { "Attack", enemy.Id })
			if distance <= reach + 1.5 then
				damagePlayer(run, def.Damage)
			end
			enemy.State = "Cooldown"
			enemy.StateUntil = now + def.AttackCooldown
		end
	elseif enemy.State == "Slam" then
		if now >= enemy.StateUntil then
			table.insert(run.Events, { "SlamHit", enemy.Id, def.SlamRadius })
			if distance <= def.SlamRadius then
				damagePlayer(run, def.SlamDamage)
			end
			enemy.NextSlam = now + def.SlamInterval
			enemy.State = "Cooldown"
			enemy.StateUntil = now + def.AttackCooldown
		end
	elseif enemy.State == "Cooldown" then
		if now >= enemy.StateUntil then
			enemy.State = "Chase"
		end
	end
end

local function tickRun(run: Run, now: number)
	local player = run.Player
	local root = getRoot(player)
	if not root then
		return
	end
	-- Sortie de l'arène (bouton Ma ferme, visite...) : partie abandonnée
	local offset = flat(root.Position) - flat(run.Arena.Origin)
	if math.abs(offset.X) > Combat.ArenaSize / 2 + 15 or math.abs(offset.Z) > Combat.ArenaSize / 2 + 15 then
		endRun(run, "Abandon", "Tu as quitté l'arène : partie abandonnée.")
		return
	end
	if now - run.StartedAt > Combat.RunTimeout then
		endRun(run, "Defeat", "Temps écoulé.")
		return
	end

	for _, enemy in run.Enemies do
		if run.State ~= "Fighting" then
			return
		end
		updateEnemy(run, enemy, root.Position, now)
	end
	if run.State ~= "Fighting" then
		return
	end

	-- Vague terminée ?
	if next(run.Enemies) == nil then
		if run.Wave > #run.Def.Waves then
			endRun(run, "Victory")
			return
		elseif not run.NextWaveAt then
			run.NextWaveAt = now + Combat.WaveDelay
			run.Dirty = true
		elseif now >= run.NextWaveAt then
			nextWave(run)
		end
	end
	-- Réseau : instantané des ennemis (10/s) et état seulement s'il a changé (5/s max)
	if next(run.Enemies) ~= nil or #run.Events > 0 then
		sendSnapshot(run)
	end
	if run.Dirty and now - run.LastStateSent >= STATE_INTERVAL then
		sendState(run)
	end
end

--------------------------------------------------------------------------
-- Actions du joueur
--------------------------------------------------------------------------

local function onAttack(player: Player)
	local run = runs[player]
	local now = os.clock()
	if not run or run.State ~= "Fighting" or now < run.NextAttack then
		return
	end
	run.NextAttack = now + Combat.AttackCooldown
	local root = getRoot(player)
	if not root then
		return
	end
	-- L'ennemi le plus proche à portée
	local target, best = nil, math.huge
	for _, enemy in run.Enemies do
		local distance = (flat(enemy.Position) - flat(root.Position)).Magnitude - enemy.Def.Size / 2
		if distance <= Combat.AttackRange and distance < best then
			target, best = enemy, distance
		end
	end
	if not target then
		return
	end
	local damage = math.floor(run.Damage * rng:NextNumber(0.9, 1.1) + 0.5)
	target.HP -= damage
	-- Le client joue l'impact (flash, recul, particules, son, nombre de dégâts)
	table.insert(run.Events, { "Hit", target.Id, damage })
	if target.HP <= 0 then
		table.insert(run.Events, { "Death", target.Id })
		XPService:AddXP(player, target.Def.XP)
		removeEnemy(run, target)
	end
	run.Dirty = true
end

local function onDodge(player: Player)
	local run = runs[player]
	local now = os.clock()
	if not run or run.State ~= "Fighting" or now < run.NextDodge then
		return
	end
	run.NextDodge = now + Combat.DodgeCooldown
	run.InvulnerableUntil = now + Combat.DodgeInvulnerability
end

local function onDungeonAction(player: Player, action: any, dungeonId: any): (boolean, string)
	if not RemoteGuard.CheckCooldown(player, "DungeonAction", 1) then
		return false, "Doucement !"
	end
	if action == "Leave" then
		local run = runs[player]
		if run and run.State == "Fighting" then
			endRun(run, "Abandon", "Tu as quitté le donjon.")
			PlotService:TeleportHome(player)
			return true, "Tu as quitté le donjon."
		end
		return false, "Tu n'es pas dans un donjon."
	end
	if action ~= "Enter" then
		return false, "Action inconnue."
	end

	local def = type(dungeonId) == "string" and Config.Dungeons[dungeonId]
	if not def then
		return false, "Donjon inconnu."
	end
	if runs[player] then
		return false, "Tu es déjà dans un donjon."
	end
	if not RemoteGuard.IsNear(player, portalPosition, 20) then
		return false, "Approche-toi du portail des donjons."
	end
	if XPService:GetLevel(player) < def.RequiredLevel then
		return false, ("Niveau %d requis."):format(def.RequiredLevel)
	end
	local arena = freeArena()
	if not arena then
		return false, "Toutes les arènes sont occupées, réessaie dans un instant."
	end

	-- PV et dégâts selon le niveau et le boost Combat
	local level = XPService:GetLevel(player)
	local combatBoost = BoostService:GetMultiplier(player, "Combat")
	local now = os.clock()
	local run: Run = {
		Player = player,
		DungeonId = dungeonId,
		Def = def,
		Arena = arena,
		Wave = 0,
		Enemies = {},
		HP = 0,
		MaxHP = math.floor((Combat.PlayerBaseHealth + Combat.HealthPerLevel * level) * combatBoost),
		Damage = (Combat.BaseDamage + Combat.DamagePerLevel * level) * combatBoost,
		Defense = combatBoost,
		InvulnerableUntil = 0,
		NextAttack = 0,
		NextDodge = 0,
		NextWaveAt = now + Combat.WaveDelay,
		State = "Fighting",
		StartedAt = now,
		Dirty = true,
		LastStateSent = 0,
		Events = {},
		BossName = nil,
	}
	run.HP = run.MaxHP
	arena.Owner = player
	arena.Floor.Color = def.FloorColor
	for _, wall in arena.Walls do
		wall.Color = def.WallColor
	end
	ArenaDecor.Apply(arena :: any, dungeonId) -- décor thématique (phase 10)
	runs[player] = run
	MovementService:Dismount(player) -- on descend de cheval en passant le portail
	player:SetAttribute("InDungeon", dungeonId)

	pcall(function()
		player:RequestStreamAroundAsync(arena.EntryCFrame.Position, 5)
	end)
	local character = player.Character
	if character and character.PrimaryPart then
		character:PivotTo(arena.EntryCFrame)
	end
	sendState(run)
	return true, ("%s %s : %d vagues puis un boss. ⚔️ Attaque (clic / F), 💨 Esquive (Q) quand un ennemi devient ROUGE !"):format(def.Icon, def.DisplayName, #def.Waves)
end

--------------------------------------------------------------------------
-- Cycle de vie
--------------------------------------------------------------------------

local function buildPortal()
	portalPosition = Config.Stands.DungeonPortalPosition
	local cframe = CFrame.lookAt(portalPosition, portalPosition + Vector3.new(1, 0, 0)) -- tourné vers le spawn
	local folder = Instance.new("Model")
	folder.Name = "DungeonPortal"
	folder.Parent = Workspace
	local radius = 6
	local center = cframe * CFrame.new(0, radius + 1.5, 0)
	makePart({ Name = "Base", Size = Vector3.new(16, 1, 6), CFrame = cframe * CFrame.new(0, 0.5, 0), Color = Color3.fromRGB(50, 40, 40), Material = Enum.Material.Basalt, Parent = folder })
	for i = 1, 16 do
		local angle = i / 16 * math.pi * 2
		makePart({ Name = "Ring", Size = Vector3.new(2.6, 0.9, 0.9), CFrame = center * CFrame.new(math.cos(angle) * radius, math.sin(angle) * radius, 0) * CFrame.Angles(0, 0, angle + math.pi / 2), Color = Color3.fromRGB(230, 40, 40), Material = Enum.Material.Neon, CanCollide = false, Parent = folder })
	end
	-- Arche de pierre sombre à pointes, braseros de chaque côté (phase 10)
	for i = 1, 16 do
		local angle = i / 16 * math.pi * 2
		makePart({ Name = "Stone", Size = Vector3.new(3.2, 1.6, 1.6), CFrame = center * CFrame.new(math.cos(angle) * (radius + 1.1), math.sin(angle) * (radius + 1.1), 0.2) * CFrame.Angles(0, 0, angle + math.pi / 2), Color = Color3.fromRGB(55, 45, 50), Material = Enum.Material.Basalt, CanCollide = false, Parent = folder })
		if i % 4 == 0 and math.sin(angle) > -0.5 then
			local spike = Instance.new("WedgePart")
			spike.Anchored = true
			spike.CanCollide = false
			spike.Size = Vector3.new(0.8, 2, 1)
			spike.CFrame = center * CFrame.new(math.cos(angle) * (radius + 2.6), math.sin(angle) * (radius + 2.6), 0.2) * CFrame.Angles(0, 0, angle - math.pi / 2)
			spike.Color = Color3.fromRGB(230, 40, 40)
			spike.Material = Enum.Material.Neon
			spike.Parent = folder
		end
	end
	for _, sx in { -1, 1 } do
		local base = cframe * CFrame.new(sx * (radius + 4.5), 0, 0)
		makePart({ Name = "BrazierStand", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4, 0.8, 0.8), CFrame = base * CFrame.new(0, 2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(60, 55, 55), Material = Enum.Material.Metal, Parent = folder })
		local fire = makePart({ Name = "BrazierFire", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.6, CFrame = base * CFrame.new(0, 4.6, 0), Color = Color3.fromRGB(255, 90, 40), Material = Enum.Material.Neon, CanCollide = false, Parent = folder })
		local flames = Instance.new("ParticleEmitter")
		flames.Color = ColorSequence.new(Color3.fromRGB(255, 200, 60), Color3.fromRGB(255, 50, 20))
		flames.LightEmission = 1
		flames.Rate = 14
		flames.Lifetime = NumberRange.new(0.4, 0.8)
		flames.Speed = NumberRange.new(2, 3)
		flames.Size = NumberSequence.new(0.7, 0)
		flames.EmissionDirection = Enum.NormalId.Top
		flames.SpreadAngle = Vector2.new(15, 15)
		flames.Parent = fire
	end
	local disc = makePart({ Name = "Disc", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, radius * 2 - 1, radius * 2 - 1), CFrame = center * CFrame.Angles(0, math.pi / 2, 0), Color = Color3.fromRGB(120, 0, 0), Material = Enum.Material.Neon, Transparency = 0.5, CanCollide = false, Parent = folder })
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 60, 60)
	light.Range = 16
	light.Brightness = 2
	light.Parent = disc

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(14, 2.5)
	gui.StudsOffsetWorldSpace = Vector3.new(0, radius + 2.5, 0)
	gui.MaxDistance = 200
	gui.LightInfluence = 0
	gui.Parent = disc
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 120, 120)
	label.TextStrokeTransparency = 0.2
	label.Text = "⚔️ DONJONS"
	label.Parent = gui

	makePart({ Name = "InteractRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 8, 8), CFrame = cframe * CFrame.new(0, 0.12, -5) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(255, 70, 70), Material = Enum.Material.Neon, Transparency = 0.25, CanCollide = false, CanQuery = false, Parent = folder })
	local anchor = makePart({ Name = "PortalPrompt", Size = Vector3.one, CFrame = cframe * CFrame.new(0, 3, -1), Transparency = 1, CanCollide = false, CanQuery = false, Parent = folder })
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Entrer dans un donjon"
	prompt.ObjectText = "Portail"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OpenUI", "Dungeon")
	prompt.Parent = anchor
	-- Modèle à toi : ServerStorage.CustomModels.Props.DungeonPortal
	ArtKit.Swap("Props", "DungeonPortal", folder:GetChildren(), folder, cframe, 16)
end

-- Arène du donjon en cours (limites de la map) : (centre, côté, point d'entrée) ou nil
function DungeonService:GetArenaBounds(player: Player): (Vector3?, number?, CFrame?)
	local run = runs[player]
	if not run then
		return nil, nil, nil
	end
	-- (aussi pendant l'écran de fin : le joueur reste dans l'arène jusqu'au retour)
	return run.Arena.Origin, Combat.ArenaSize, run.Arena.EntryCFrame
end

-- Toutes les arènes (pour repérer un joueur dans une arène sans y être entré par le portail)
function DungeonService:GetAllArenaBounds(): { { Origin: Vector3, Size: number } }
	local result = {}
	for _, arena in arenas do
		table.insert(result, { Origin = arena.Origin, Size = Combat.ArenaSize })
	end
	return result
end

function DungeonService:Init()
	local root = Instance.new("Folder")
	root.Name = "Dungeons"
	root.Parent = Workspace
	for index = 1, MAX_ARENAS do
		buildArena(index)
	end
	buildPortal()
end

function DungeonService:Start()
	Remotes.Get("DungeonAction").OnServerInvoke = onDungeonAction
	Remotes.Get("DungeonAttack").OnServerEvent:Connect(onAttack)
	Remotes.Get("DungeonDodge").OnServerEvent:Connect(onDodge)

	local function onPlayerAdded(player: Player)
		-- Mort / réapparition pendant un donjon : défaite
		player.CharacterAdded:Connect(function()
			local run = runs[player]
			if run and run.State == "Fighting" then
				endRun(run, "Defeat", "Ton personnage est tombé.")
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local run = runs[player]
		if run then
			endRun(run, "Abandon", "Déconnexion.")
			runs[player] = nil
			run.Arena.Owner = nil
		end
	end)

	task.spawn(function()
		while true do
			task.wait(TICK)
			local now = os.clock()
			for _, run in runs do
				if run.State == "Fighting" then
					local ok, err = pcall(tickRun, run, now)
					if not ok then
						warn("[DungeonService] Erreur pendant le combat : " .. tostring(err))
					end
				end
			end
		end
	end)
end

return DungeonService
