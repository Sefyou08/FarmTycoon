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
-- RARETÉS (utilisées pour l'affichage ; la boutique tournante arrive en phase 3)
--------------------------------------------------------------------------
Config.Rarities = {
	Common = { DisplayName = "Commune", Color = Color3.fromRGB(190, 190, 190), Order = 1 },
	Rare = { DisplayName = "Rare", Color = Color3.fromRGB(70, 150, 255), Order = 2 },
	Epic = { DisplayName = "Épique", Color = Color3.fromRGB(170, 80, 240), Order = 3 },
	Legendary = { DisplayName = "Légendaire", Color = Color3.fromRGB(255, 180, 30), Order = 4 },
}

--------------------------------------------------------------------------
-- CULTURES
--   SeedPrice : prix d'UNE graine (Coins)
--   SellPrice : prix de vente d'UN produit récolté (Coins)
--   GrowTime  : temps de pousse total en secondes (3 stades : petite / moyenne / mûre)
--   FruitShape : "Ball" | "Block" | "Cylinder" (forme du fruit, en Parts simples)
--------------------------------------------------------------------------
Config.Crops = {
	Carrot = {
		DisplayName = "Carotte",
		Icon = "🥕",
		Rarity = "Common",
		Order = 1,
		SeedPrice = 10,
		SellPrice = 18,
		GrowTime = 20,
		Color = Color3.fromRGB(255, 140, 30),
		FruitShape = "Cylinder",
		FruitSize = Vector3.new(1.6, 0.8, 0.8),
	},
	Tomato = {
		DisplayName = "Tomate",
		Icon = "🍅",
		Rarity = "Common",
		Order = 2,
		SeedPrice = 30,
		SellPrice = 55,
		GrowTime = 45,
		Color = Color3.fromRGB(230, 40, 40),
		FruitShape = "Ball",
		FruitSize = Vector3.new(1.3, 1.3, 1.3),
	},
	Corn = {
		DisplayName = "Maïs",
		Icon = "🌽",
		Rarity = "Common",
		Order = 3,
		SeedPrice = 80,
		SellPrice = 150,
		GrowTime = 90,
		Color = Color3.fromRGB(255, 220, 60),
		FruitShape = "Block",
		FruitSize = Vector3.new(0.8, 1.8, 0.8),
	},
	Pumpkin = {
		DisplayName = "Citrouille",
		Icon = "🎃",
		Rarity = "Common",
		Order = 4,
		SeedPrice = 200,
		SellPrice = 400,
		GrowTime = 180,
		Color = Color3.fromRGB(235, 110, 20),
		FruitShape = "Ball",
		FruitSize = Vector3.new(2.2, 2.2, 2.2),
	},
}

--------------------------------------------------------------------------
-- FERME (cases de terre, inventaire)
--------------------------------------------------------------------------
Config.Farm = {
	StartingTiles = 6, -- cases de terre débloquées au départ
	GridColumns = 6, -- grille max = 6 x 4 = 24 cases (les autres se débloquent en phase 4)
	GridRows = 4,
	TileSize = 6, -- taille d'une case (studs)
	TileGap = 2, -- espace entre deux cases
	GridOffsetZ = 4, -- décale la grille vers le fond de la parcelle
	SoilColor = Color3.fromRGB(105, 70, 40),

	InteractDistance = 10, -- distance max pour planter / récolter
	ActionCooldown = 0.15, -- secondes entre deux actions planter/récolter (anti-spam)

	InventoryCapacity = 200, -- nombre max de produits récoltés dans l'inventaire
	MaxSeedsPerCrop = 999, -- nombre max de graines d'un même type

	-- Pack de départ donné UNE seule fois à chaque joueur
	StarterSeeds = { Carrot = 5 },
}

--------------------------------------------------------------------------
-- STANDS (boutique de graines et stand de vente, au centre de la map)
--------------------------------------------------------------------------
Config.Stands = {
	SeedShopPosition = Vector3.new(-30, 0, 0),
	SellStandPosition = Vector3.new(30, 0, 0),
	MaxDistance = 16, -- distance max pour acheter / vendre (vérifiée par le serveur)
}

Config.Shop = {
	BuyAmounts = { 1, 5 }, -- boutons d'achat affichés dans la boutique
	MaxBuyAmount = 25, -- quantité max par requête
	BuyCooldown = 0.2,
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
