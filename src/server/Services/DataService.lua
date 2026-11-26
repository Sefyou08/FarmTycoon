--[[
	DataService.lua
	===============
	Chargement / sauvegarde des données joueur avec DataStoreService.

	Choix : implémentation maison (pas de dépendance externe) qui reprend les
	principes de ProfileStore :
	  • SESSION LOCKING : à l'ouverture, on écrit dans la sauvegarde "ce joueur
	    est ouvert sur le serveur X". Un autre serveur qui essaie de charger le
	    même joueur attend que le verrou soit libéré (anti duplication d'objets).
	    Un verrou non rafraîchi depuis Config.Data.LockStaleTime est considéré
	    abandonné (serveur crashé) et peut être repris.
	  • RETRIES : chaque requête DataStore est retentée avec un délai croissant.
	  • AUTO-SAVE toutes les Config.Data.AutoSaveInterval secondes.
	  • SAUVEGARDE + LIBÉRATION du verrou à la déconnexion.
	  • BindToClose : à l'arrêt du serveur, on attend la fin de toutes les sauvegardes.
	  • Si le chargement échoue, le joueur est expulsé avec un message plutôt
	    que de jouer avec des données vides (qui écraseraient sa vraie sauvegarde).

	Format stocké dans le DataStore :
	  { Data = { ...données du joueur... }, Meta = { Lock = { SessionId, Time }, LastSave } }

	API :
	  DataService:GetData(player) -> table | nil   (nil = pas encore chargé)
	  DataService:IsLoaded(player) -> boolean
	  DataService:OnProfileLoaded(callback(player, data))  -- appelé aussi pour les joueurs déjà chargés
	  DataService:SaveNow(player)                          -- sauvegarde immédiate (ex. après un achat Robux)
]]

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local DataTemplate = require(script.Parent.Parent.Data.DataTemplate)

local DataConfig = Config.Data

local DataService = {}

-- Identifiant unique de CE serveur (JobId est vide dans Studio).
local SESSION_ID = if game.JobId ~= "" then game.JobId else ("Studio_" .. HttpService:GenerateGUID(false))

type Profile = {
	Player: Player,
	UserId: number,
	Key: string,
	Data: { [string]: any },
	IsSaving: boolean,
	LastPlayTimeTick: number,
}

local profiles: { [Player]: Profile } = {}
local releasing: { [number]: boolean } = {} -- UserId en cours de libération sur CE serveur
local loadedCallbacks: { (Player, { [string]: any }) -> () } = {}
local pendingReleases = 0
local isShuttingDown = false

local store: any = nil -- GlobalDataStore réel, ou MockStore en Studio
local usingMock = false

--------------------------------------------------------------------------
-- Utilitaires
--------------------------------------------------------------------------

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

-- Ajoute les champs manquants du template (sans écraser l'existant).
local function reconcile(data: { [string]: any }, template: { [string]: any })
	for key, defaultValue in template do
		if data[key] == nil then
			data[key] = deepCopy(defaultValue)
		elseif type(defaultValue) == "table" and type(data[key]) == "table" and next(defaultValue) ~= nil then
			-- On ne réconcilie que les sous-tables "structurées" (ex. Stats),
			-- pas les tables vides par défaut (Inventory, Seeds...) qui sont libres.
			reconcile(data[key], defaultValue)
		end
	end
end

-- Exécute fn() avec des retries et un délai exponentiel. Renvoie (ok, résultat | erreur).
local function withRetries(label: string, fn: () -> any): (boolean, any)
	local lastError = nil
	for attempt = 1, DataConfig.MaxRetries do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastError = result
		warn(("[DataService] %s : échec (tentative %d/%d) : %s"):format(label, attempt, DataConfig.MaxRetries, tostring(result)))
		if attempt < DataConfig.MaxRetries then
			task.wait(DataConfig.RetryBaseDelay * 2 ^ (attempt - 1))
		end
	end
	return false, lastError
end

local function keyFor(userId: number): string
	return "Player_" .. userId
end

--------------------------------------------------------------------------
-- MockStore : DataStore en mémoire pour Studio sans accès API
--------------------------------------------------------------------------
local MockStore = {}
MockStore.__index = MockStore

function MockStore.new()
	return setmetatable({ _entries = {} }, MockStore)
end

function MockStore:UpdateAsync(key: string, transform: (any) -> any): any
	local current = deepCopy(self._entries[key])
	local newValue = transform(current)
	if newValue ~= nil then
		self._entries[key] = deepCopy(newValue)
	end
	return newValue
end

local function initStore()
	local ok, result = pcall(function()
		local realStore = DataStoreService:GetDataStore(DataConfig.StoreName)
		realStore:GetAsync("__probe__") -- lève une erreur si l'accès API est désactivé
		return realStore
	end)

	if ok then
		store = result
		print(("[DataService] DataStore '%s' prêt (session %s)"):format(DataConfig.StoreName, SESSION_ID))
		return
	end

	if RunService:IsStudio() and DataConfig.UseMockStoreInStudio then
		store = MockStore.new()
		usingMock = true
		warn("[DataService] DataStore inaccessible dans Studio (" .. tostring(result) .. ")")
		warn("[DataService] -> MODE MOCK : les données NE SERONT PAS sauvegardées entre deux tests.")
		warn("[DataService]    Pour tester la vraie sauvegarde : publie le jeu puis Game Settings > Security > Enable Studio Access to API Services.")
		return
	end

	-- En jeu publié, une erreur ponctuelle ne doit pas bloquer : les retries feront le travail.
	warn("[DataService] Sonde DataStore en échec, on continue avec les retries : " .. tostring(result))
	store = DataStoreService:GetDataStore(DataConfig.StoreName)
end

--------------------------------------------------------------------------
-- Chargement (avec session lock)
--------------------------------------------------------------------------

-- Renvoie (data, nil) en cas de succès, ou (nil, raison) : "left" | "locked" | "error"
local function loadData(player: Player): ({ [string]: any }?, string?)
	local key = keyFor(player.UserId)

	for _ = 1, DataConfig.LockRetryAttempts do
		local status = "error"
		local loaded = nil

		local ok = withRetries("Chargement " .. key, function()
			return store:UpdateAsync(key, function(stored)
				-- ⚠️ Pas de yield ici : cette fonction peut être rappelée plusieurs fois par Roblox.
				stored = if type(stored) == "table" then stored else {}
				stored.Meta = if type(stored.Meta) == "table" then stored.Meta else {}

				local now = os.time()
				local lock = stored.Meta.Lock
				if type(lock) == "table" and lock.SessionId ~= SESSION_ID and now - (lock.Time or 0) < DataConfig.LockStaleTime then
					status = "locked"
					return nil -- annule l'écriture : un autre serveur possède le joueur
				end

				stored.Meta.Lock = { SessionId = SESSION_ID, Time = now }
				status = "ok"
				loaded = stored.Data
				return stored
			end)
		end)

		if not ok then
			return nil, "error"
		end

		if status == "ok" then
			local data = if type(loaded) == "table" then deepCopy(loaded) else deepCopy(DataTemplate)
			reconcile(data, DataTemplate)
			return data, nil
		end

		-- Verrouillé ailleurs : on attend un peu puis on réessaie
		warn(("[DataService] Données de %s verrouillées par un autre serveur, nouvelle tentative dans %ds"):format(player.Name, DataConfig.LockRetryDelay))
		task.wait(DataConfig.LockRetryDelay)
		if not player.Parent then
			return nil, "left"
		end
	end

	return nil, "locked"
end

--------------------------------------------------------------------------
-- Sauvegarde
--------------------------------------------------------------------------

-- release = true : libère aussi le verrou (déconnexion / arrêt serveur)
local function saveProfile(profile: Profile, release: boolean): boolean
	-- Attend une éventuelle sauvegarde en cours (auto-save) pour ne pas en lancer deux en parallèle
	while profile.IsSaving do
		task.wait(0.1)
	end
	profile.IsSaving = true

	-- Mise à jour du temps de jeu
	local now = os.time()
	profile.Data.Stats.PlayTime += now - profile.LastPlayTimeTick
	profile.LastPlayTimeTick = now

	local lockLost = false
	local ok, err = withRetries("Sauvegarde " .. profile.Key, function()
		return store:UpdateAsync(profile.Key, function(stored)
			stored = if type(stored) == "table" then stored else {}
			stored.Meta = if type(stored.Meta) == "table" then stored.Meta else {}

			local lock = stored.Meta.Lock
			if type(lock) == "table" and lock.SessionId ~= SESSION_ID then
				lockLost = true -- un autre serveur a repris le joueur : on n'écrase RIEN
				return nil
			end

			stored.Data = profile.Data
			stored.Meta.LastSave = os.time()
			if release then
				stored.Meta.Lock = nil
			else
				stored.Meta.Lock = { SessionId = SESSION_ID, Time = os.time() } -- rafraîchit le verrou
			end
			return stored
		end)
	end)

	profile.IsSaving = false

	if not ok then
		warn(("[DataService] ÉCHEC définitif de la sauvegarde de %s : %s"):format(profile.Key, tostring(err)))
		return false
	end

	if lockLost then
		warn(("[DataService] Verrou perdu pour %s : session ouverte sur un autre serveur."):format(profile.Key))
		if not release and profile.Player.Parent then
			profile.Player:Kick("Ta partie a été ouverte sur un autre serveur. Reconnecte-toi.")
		end
		return false
	end

	return true
end

-- Retire le profil, sauvegarde et libère le verrou.
local function releaseProfile(profile: Profile)
	releasing[profile.UserId] = true
	pendingReleases += 1

	local ok = saveProfile(profile, true)
	if ok then
		print(("[DataService] Données de %s sauvegardées et libérées%s"):format(profile.Player.Name, if usingMock then " (mock)" else ""))
	end

	pendingReleases -= 1
	releasing[profile.UserId] = nil
end

--------------------------------------------------------------------------
-- Événements joueurs
--------------------------------------------------------------------------

local function onPlayerAdded(player: Player)
	-- Si ce même joueur vient de quitter CE serveur, on attend la fin de sa sauvegarde
	while releasing[player.UserId] do
		task.wait(0.2)
	end

	local data, reason = loadData(player)

	if not data then
		if reason ~= "left" and player.Parent then
			local message = if reason == "locked"
				then "Ta partie est encore ouverte sur un autre serveur. Réessaie dans quelques minutes."
				else "Impossible de charger tes données (Roblox DataStore indisponible). Réessaie plus tard."
			player:Kick(message)
		end
		return
	end

	local profile: Profile = {
		Player = player,
		UserId = player.UserId,
		Key = keyFor(player.UserId),
		Data = data,
		IsSaving = false,
		LastPlayTimeTick = os.time(),
	}

	-- Le joueur est parti pendant le chargement : on libère juste le verrou.
	if not player.Parent then
		task.spawn(releaseProfile, profile)
		return
	end

	profiles[player] = profile

	if Config.Debug.Enabled and Config.Debug.PrintDataOnLoad then
		print(("[DataService] Données chargées pour %s : Coins=%d, Rebirths=%d"):format(player.Name, data.Coins, data.Rebirths))
	end

	for _, callback in loadedCallbacks do
		task.spawn(callback, player, data)
	end
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if not profile then
		return -- jamais chargé (ou déjà libéré)
	end
	profiles[player] = nil
	releaseProfile(profile)
end

local function onServerClose()
	isShuttingDown = true

	-- Libère tous les profils restants en parallèle
	for player, profile in profiles do
		profiles[player] = nil
		task.spawn(releaseProfile, profile)
	end

	-- Attend la fin de toutes les sauvegardes (Roblox laisse ~30 s max)
	local start = os.clock()
	while pendingReleases > 0 and os.clock() - start < 25 do
		task.wait(0.1)
	end
	if pendingReleases > 0 then
		warn(("[DataService] Arrêt du serveur : %d sauvegarde(s) non terminée(s)"):format(pendingReleases))
	end
end

local function autoSaveLoop()
	while true do
		task.wait(DataConfig.AutoSaveInterval)
		if isShuttingDown then
			break
		end
		local count = 0
		for _, profile in profiles do
			count += 1
			task.spawn(saveProfile, profile, false)
		end
		if count > 0 and Config.Debug.Enabled then
			print(("[DataService] Auto-save de %d joueur(s)"):format(count))
		end
	end
end

--------------------------------------------------------------------------
-- API publique
--------------------------------------------------------------------------

function DataService:GetData(player: Player): { [string]: any }?
	local profile = profiles[player]
	return profile and profile.Data
end

function DataService:IsLoaded(player: Player): boolean
	return profiles[player] ~= nil
end

function DataService:OnProfileLoaded(callback: (Player, { [string]: any }) -> ())
	table.insert(loadedCallbacks, callback)
	for player, profile in profiles do
		task.spawn(callback, player, profile.Data)
	end
end

function DataService:SaveNow(player: Player): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	return saveProfile(profile, false)
end

function DataService:Init()
	initStore()
end

function DataService:Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	-- Joueurs déjà présents avant que le script ne démarre (fréquent dans Studio)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	game:BindToClose(onServerClose)
	task.spawn(autoSaveLoop)
end

return DataService
