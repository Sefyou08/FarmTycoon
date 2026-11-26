--[[
	Config.lua  (ReplicatedStorage.Shared.Config)
	=============================================
	TOUTES les valeurs d'équilibrage du jeu sont ici.
	Modifie ce fichier pour ajuster prix, temps, revenus, etc.

	⚠️ Ce module est lisible par le client (ReplicatedStorage) : n'y mets
	jamais de secret. Le serveur reste la seule source de vérité : le client
	ne lit la config que pour l'AFFICHAGE.

	Les sections des phases suivantes (graines, mutations, améliorations,
	rebirth, familiers, monétisation) seront ajoutées au fur et à mesure.
]]

local Config = {}

--------------------------------------------------------------------------
-- MONNAIE
--------------------------------------------------------------------------
Config.Currency = {
	Name = "Coins",
	StartingCoins = 0, -- coins donnés à un tout nouveau joueur
}

--------------------------------------------------------------------------
-- PARCELLES (générées en Parts simples au démarrage du serveur)
--------------------------------------------------------------------------
Config.Plots = {
	Count = 6, -- nombre de parcelles sur la map (= nombre max de joueurs conseillé)
	Columns = 3, -- 2 rangées de 3 parcelles, face à face
	Size = Vector3.new(60, 1, 60), -- taille du sol d'une parcelle (studs)
	SpacingX = 80, -- distance entre les centres de deux parcelles voisines (axe X)
	RowOffsetZ = 75, -- distance entre le centre de la map et une rangée (axe Z)

	GroundColor = Color3.fromRGB(106, 170, 70),
	BorderColor = Color3.fromRGB(110, 75, 45),
	SignColor = Color3.fromRGB(150, 105, 60),

	FreeLabel = "Parcelle libre",
	OwnerLabelFormat = "Ferme de %s", -- %s = DisplayName du joueur
}

--------------------------------------------------------------------------
-- SAUVEGARDE
--------------------------------------------------------------------------
Config.Data = {
	-- ⚠️ Changer le nom = repartir de zéro pour tous les joueurs (utile en dev).
	StoreName = "FarmTycoon_PlayerData_v1",

	AutoSaveInterval = 60, -- secondes entre deux sauvegardes automatiques
	MaxRetries = 5, -- tentatives par requête DataStore avant abandon
	RetryBaseDelay = 1, -- délai (s) de la 1re nouvelle tentative, doublé à chaque échec

	-- Session locking : empêche deux serveurs d'écrire les mêmes données
	LockStaleTime = 300, -- un verrou non rafraîchi depuis 5 min est considéré abandonné (crash serveur)
	LockRetryAttempts = 8, -- tentatives si les données sont verrouillées par un autre serveur
	LockRetryDelay = 5, -- secondes entre ces tentatives

	-- Dans Studio sans "API Services" activés, on bascule sur un stockage
	-- en mémoire (non persistant) au lieu de planter.
	UseMockStoreInStudio = true,
}

--------------------------------------------------------------------------
-- SÉCURITÉ / ANTI-SPAM des RemoteEvents
--------------------------------------------------------------------------
Config.Security = {
	TeleportHomeCooldown = 5, -- secondes entre deux téléportations "Ma ferme"
}

--------------------------------------------------------------------------
-- DEBUG (mettre Enabled = false avant de publier le jeu)
--------------------------------------------------------------------------
Config.Debug = {
	Enabled = true,
	TestCoinPadAmount = 25, -- coins donnés par le pad jaune de test sur chaque parcelle
	TestCoinPadCooldown = 1, -- secondes entre deux utilisations du pad
	PrintDataOnLoad = true, -- affiche les données chargées dans l'Output
}

return Config
