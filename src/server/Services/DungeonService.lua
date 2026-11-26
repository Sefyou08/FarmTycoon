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

	Le client reçoit l'état (PV, vague, boss) par le RemoteEvent "DungeonState".
	RemoteFunction "DungeonAction" : ("Enter", dungeonId) | ("Leave").
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local ItemUtil = require(ReplicatedStorage.Shared.ItemUtil)
local CropUtil = require(ReplicatedStorage.Shared.CropUtil)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RemoteGuard = require(script.Parent.Parent.Util.RemoteGuard)
local DataService = require(script.Parent.DataService)
local SyncService = require(script.Parent.SyncService)
local CurrencyService = require(script.Parent.CurrencyService)
local InventoryService = require(script.Parent.InventoryService)
local BoostService = require(script.Parent.BoostService)
local XPService = require(script.Parent.XPService)
local PlotService = require(script.Parent.PlotService)

local Combat = Config.Combat

local DungeonService = {}

local TICK = 0.1
local MAX_ARENAS = Config.Plots.Count -- une arène par joueur possible

type Enemy = {
	Id: number,
	Def: any,
	Model: Model,
	Body: BasePart,
	HP: number,
	MaxHP: number,
	Position: Vector3,
	State: string, -- "Chase" | "WindUp" | "Cooldown" | "Slam"
	StateUntil: number,
	NextSlam: number,
	SlamCircle: BasePart?,
	HPFill: Frame,
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

local function buildEnemyModel(def: any, ground: CFrame): (Model, BasePart, Frame)
	local model = Instance.new("Model")
	model.Name = def.DisplayName
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local s = def.Size
	local bodySize = if def.Body == "Ball" then Vector3.one * s else Vector3.new(s * 0.9, s * 0.8, s)
	local function part(name: string, shape: Enum.PartType, size: Vector3, offset: CFrame, color: Color3): Part
		return makePart({ Name = name, Shape = shape, Size = size, CFrame = ground * offset, Color = color, CanCollide = false, CanTouch = false, CanQuery = false, Material = Enum.Material.SmoothPlastic, Parent = model })
	end
	local body = part("Body", if def.Body == "Ball" then Enum.PartType.Ball else Enum.PartType.Block, bodySize, CFrame.new(0, bodySize.Y / 2, 0), def.Color)
	model.PrimaryPart = body
	model.WorldPivot = ground
	-- Yeux méchants (à l'avant, -Z) + piquants
	for _, sx in { -1, 1 } do
		part("Eye", Enum.PartType.Ball, Vector3.one * s * 0.22, CFrame.new(sx * s * 0.2, bodySize.Y * 0.65, -bodySize.Z / 2), Color3.fromRGB(255, 230, 80))
		part("Brow", Enum.PartType.Block, Vector3.new(s * 0.28, s * 0.06, s * 0.08), CFrame.new(sx * s * 0.2, bodySize.Y * 0.8, -bodySize.Z / 2 - 0.05) * CFrame.Angles(0, 0, sx * math.rad(20)), Color3.fromRGB(20, 20, 20))
	end
	for i = -1, 1 do
		part("Spike", Enum.PartType.Block, Vector3.new(s * 0.15, s * 0.35, s * 0.15), CFrame.new(i * s * 0.25, bodySize.Y + s * 0.1, 0) * CFrame.Angles(0, 0, math.rad(i * 15)), def.Accent)
	end
	if def.Boss then
		-- Couronne + aura pour les boss
		for i = 1, 6 do
			local angle = i / 6 * math.pi * 2
			part("Crown", Enum.PartType.Block, Vector3.new(s * 0.12, s * 0.3, s * 0.12), CFrame.new(math.cos(angle) * s * 0.3, bodySize.Y + s * 0.3, math.sin(angle) * s * 0.3), Color3.fromRGB(255, 210, 60)).Material = Enum.Material.Neon
		end
		local light = Instance.new("PointLight")
		light.Color = def.Accent
		light.Range = 20
		light.Brightness = 2
		light.Parent = body
	end

	-- Barre de vie au-dessus
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(math.max(4, s * 1.2), 1.4)
	gui.StudsOffsetWorldSpace = Vector3.new(0, bodySize.Y / 2 + 2, 0)
	gui.MaxDistance = 120
	gui.LightInfluence = 0
	gui.Parent = body
	local name = Instance.new("TextLabel")
	name.Size = UDim2.fromScale(1, 0.55)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.FredokaOne
	name.TextScaled = true
	name.TextColor3 = if def.Boss then Color3.fromRGB(255, 120, 120) else Color3.new(1, 1, 1)
	name.TextStrokeTransparency = 0.3
	name.Text = (if def.Boss then "👑 " else "") .. def.DisplayName
	name.Parent = gui
	local back = Instance.new("Frame")
	back.Position = UDim2.fromScale(0, 0.6)
	back.Size = UDim2.fromScale(1, 0.35)
	back.BackgroundColor3 = Color3.fromRGB(40, 20, 20)
	back.Parent = gui
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(230, 60, 60)
	fill.BorderSizePixel = 0
	fill.Parent = back
	return model, body, fill
end

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
	local model, body, fill = buildEnemyModel(def, CFrame.new(position))
	model.Parent = run.Arena.EnemyFolder

	enemyCounter += 1
	run.Enemies[enemyCounter] = {
		Id = enemyCounter,
		Def = def,
		Model = model,
		Body = body,
		HP = def.HP,
		MaxHP = def.HP,
		Position = position,
		State = "Chase",
		StateUntil = 0,
		NextSlam = os.clock() + (def.SlamInterval or math.huge),
		SlamCircle = nil,
		HPFill = fill,
	}
	if def.Boss then
		run.BossName = def.DisplayName
	end
end

local function setEnemyColor(enemy: Enemy, warning: boolean)
	enemy.Body.Color = if warning then Color3.fromRGB(255, 40, 40) else enemy.Def.Color
	enemy.Body.Material = if warning then Enum.Material.Neon else Enum.Material.SmoothPlastic
end

local function removeEnemy(run: Run, enemy: Enemy)
	run.Enemies[enemy.Id] = nil
	if enemy.SlamCircle then
		enemy.SlamCircle:Destroy()
	end
	enemy.Model:Destroy()
end

-- Petit nombre de dégâts qui s'envole au-dessus de l'ennemi
local function damagePopup(body: BasePart, amount: number)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(3, 1.2)
	gui.StudsOffsetWorldSpace = Vector3.new(rng:NextNumber(-1, 1), body.Size.Y / 2 + 3, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = body
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 230, 90)
	label.TextStrokeTransparency = 0
	label.Text = "-" .. Format.Number(amount)
	label.Parent = gui
	Debris:AddItem(gui, 0.7)
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
	}
	if extra then
		for key, value in extra do
			state[key] = value
		end
	end
	Remotes.Get("DungeonState"):FireClient(run.Player, state)
	run.Dirty = false
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

	local message
	if outcome == "Victory" then
		local summary = giveRewards(run)
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
		sendState(run, { Dodged = true })
		return
	end
	run.HP = math.max(0, run.HP - math.floor(amount / run.Defense + 0.5))
	run.Dirty = true
	sendState(run, { Hit = true })
	if run.HP <= 0 then
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

	if enemy.State == "Chase" then
		-- Boss : attaque de zone à intervalle régulier
		if def.Boss and now >= enemy.NextSlam then
			enemy.State = "Slam"
			enemy.StateUntil = now + def.SlamWindup
			local circle = makePart({
				Name = "SlamWarning",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.3, def.SlamRadius * 2, def.SlamRadius * 2),
				CFrame = CFrame.new(enemy.Position + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
				Color = Color3.fromRGB(255, 40, 40),
				Material = Enum.Material.Neon,
				Transparency = 0.45,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				Parent = run.Arena.EnemyFolder,
			})
			enemy.SlamCircle = circle
			setEnemyColor(enemy, true)
			return
		end
		if distance <= reach then
			enemy.State = "WindUp"
			enemy.StateUntil = now + def.WindUp
			setEnemyColor(enemy, true) -- avertissement : il va frapper !
		elseif distance > 0.1 then
			local step = math.min(def.Speed * TICK, distance - reach * 0.8)
			if step > 0 then
				enemy.Position += toPlayer.Unit * step
			end
			enemy.Model:PivotTo(CFrame.lookAt(enemy.Position, enemy.Position + toPlayer.Unit))
		end
	elseif enemy.State == "WindUp" then
		if now >= enemy.StateUntil then
			setEnemyColor(enemy, false)
			if distance <= reach + 1.5 then
				damagePlayer(run, def.Damage)
			end
			enemy.State = "Cooldown"
			enemy.StateUntil = now + def.AttackCooldown
		end
	elseif enemy.State == "Slam" then
		if now >= enemy.StateUntil then
			setEnemyColor(enemy, false)
			if enemy.SlamCircle then
				enemy.SlamCircle:Destroy()
				enemy.SlamCircle = nil
			end
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
	if run.Dirty then
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
	damagePopup(target.Body, damage)
	target.HPFill.Size = UDim2.fromScale(math.clamp(target.HP / target.MaxHP, 0, 1), 1)
	if target.HP <= 0 then
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
		BossName = nil,
	}
	run.HP = run.MaxHP
	arena.Owner = player
	arena.Floor.Color = def.FloorColor
	for _, wall in arena.Walls do
		wall.Color = def.WallColor
	end
	runs[player] = run
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

	local anchor = makePart({ Name = "PortalPrompt", Size = Vector3.one, CFrame = cframe * CFrame.new(0, 3, -1), Transparency = 1, CanCollide = false, CanQuery = false, Parent = folder })
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Entrer dans un donjon"
	prompt.ObjectText = "Portail"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OpenUI", "Dungeon")
	prompt.Parent = anchor
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
