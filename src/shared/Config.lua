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
-- RARETÉS des graines (affichage ; la boutique tournante arrive en phase 7)
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
--   FeedValue : nombre de rations données aux animaux pour UN produit
--               (≈ 1 ration pour 9 Coins de valeur de vente)
--   FruitShape : "Ball" | "Block" | "Cylinder" (forme du fruit, en Parts simples)
--   Feminine  : true si le nom est féminin ("Carotte Dorée" / "Blé Doré")
--------------------------------------------------------------------------
Config.Crops = {
	Wheat = {
		DisplayName = "Blé",
		Icon = "🌾",
		Rarity = "Common",
		Order = 0,
		SeedPrice = 5,
		SellPrice = 8,
		GrowTime = 15,
		FeedValue = 1,
		Color = Color3.fromRGB(230, 200, 110),
		FruitShape = "Block",
		FruitSize = Vector3.new(0.5, 1.6, 0.5),
	},
	Carrot = {
		DisplayName = "Carotte",
		Icon = "🥕",
		Rarity = "Common",
		Order = 1,
		SeedPrice = 10,
		SellPrice = 18,
		GrowTime = 20,
		FeedValue = 2,
		Feminine = true,
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
		FeedValue = 6,
		Feminine = true,
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
		FeedValue = 16,
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
		FeedValue = 40,
		Feminine = true,
		Color = Color3.fromRGB(235, 110, 20),
		FruitShape = "Ball",
		FruitSize = Vector3.new(2.2, 2.2, 2.2),
	},

	-- Cultures RARES : vendues uniquement dans le stock tournant de la boutique (phase 7)
	Strawberry = {
		DisplayName = "Fraise", Icon = "🍓", Rarity = "Rare", Order = 10, Feminine = true,
		SeedPrice = 150, SellPrice = 320, GrowTime = 60, FeedValue = 35,
		Color = Color3.fromRGB(240, 40, 70), FruitShape = "Ball", FruitSize = Vector3.new(1, 1, 1),
	},
	Blueberry = {
		DisplayName = "Myrtille", Icon = "🫐", Rarity = "Rare", Order = 11, Feminine = true,
		SeedPrice = 250, SellPrice = 520, GrowTime = 80, FeedValue = 55,
		Color = Color3.fromRGB(70, 80, 220), FruitShape = "Ball", FruitSize = Vector3.new(0.9, 0.9, 0.9),
	},
	Watermelon = {
		DisplayName = "Pastèque", Icon = "🍉", Rarity = "Epic", Order = 12, Feminine = true,
		SeedPrice = 900, SellPrice = 2000, GrowTime = 150, FeedValue = 220,
		Color = Color3.fromRGB(60, 160, 60), FruitShape = "Ball", FruitSize = Vector3.new(2.4, 2.4, 2.4),
	},
	Dragonfruit = {
		DisplayName = "Fruit du dragon", Icon = "🐉", Rarity = "Epic", Order = 13,
		SeedPrice = 1500, SellPrice = 3400, GrowTime = 200, FeedValue = 370,
		Color = Color3.fromRGB(255, 60, 150), FruitShape = "Ball", FruitSize = Vector3.new(1.6, 1.6, 1.6),
	},
	StarFlower = {
		DisplayName = "Fleur étoilée", Icon = "🌟", Rarity = "Legendary", Order = 14, Feminine = true,
		SeedPrice = 6000, SellPrice = 15000, GrowTime = 360, FeedValue = 1600,
		Color = Color3.fromRGB(255, 230, 80), FruitShape = "Ball", FruitSize = Vector3.new(1.8, 1.8, 1.8),
	},
	MoonPumpkin = {
		DisplayName = "Citrouille lunaire", Icon = "🌙", Rarity = "Legendary", Order = 15, Feminine = true,
		SeedPrice = 10000, SellPrice = 26000, GrowTime = 480, FeedValue = 2800,
		Color = Color3.fromRGB(170, 190, 255), FruitShape = "Ball", FruitSize = Vector3.new(2.6, 2.6, 2.6),
	},
}

--------------------------------------------------------------------------
-- FERME (cases de terre, inventaire, engrais)
--------------------------------------------------------------------------
Config.Farm = {
	-- Un CHAMP = un bloc de FieldColumns x FieldRows cases, placé avec le mode construction
	FieldColumns = 3,
	FieldRows = 2,
	TileSize = 6, -- taille d'une case (studs)
	TileGap = 2, -- espace entre deux cases
	FieldFootprint = Vector2.new(24, 16), -- emprise d'un champ (largeur X, profondeur Z)
	SoilColor = Color3.fromRGB(105, 70, 40),
	LockedSoilColor = Color3.fromRGB(80, 75, 70),

	StartingUnlockedTiles = 6, -- le 1er champ offert a toutes ses cases débloquées
	DefaultFieldPosition = { X = 0, Z = 22 }, -- position du 1er champ (et des anciennes sauvegardes)

	-- Prix du 1er, 2e, 3e... champ (le 1er est offert). Ses cases arrivent verrouillées.
	FieldPrices = { 0, 400, 1500, 4000, 10000, 25000, 60000, 150000, 350000, 800000 },
	-- Nombre max de champs selon le niveau de la parcelle (1 à 4)
	MaxFieldsByLevel = { 4, 6, 8, 10 },
	-- Prix pour débloquer une case : Base x Growth ^ (cases déjà débloquées - StartingUnlockedTiles)
	TileUnlockBase = 60,
	TileUnlockGrowth = 1.12,

	InteractDistance = 10, -- distance max pour planter / récolter
	ActionCooldown = 0.15, -- secondes entre deux actions planter/récolter (anti-spam)

	InventoryCapacity = 300, -- nombre max de produits (récoltes + ressources) dans l'inventaire
	MaxSeedsPerCrop = 999, -- nombre max de graines d'un même type

	-- Pack de départ donné UNE seule fois à chaque joueur
	StarterSeeds = { Carrot = 5, Wheat = 5 },

	-- Mutations de plantes à la RÉCOLTE (mêmes variantes que les animaux : Config.Variants).
	-- Chance de base, multipliée par RarityBonus selon la rareté de la culture.
	HarvestMutations = { Gold = 0.04, Rainbow = 0.01, Legendary = 0.002, Mythic = 0.0004 },
	HarvestMutationRarityBonus = { Common = 1, Rare = 1.5, Epic = 2, Legendary = 3 },
}

-- Fumier du cheval utilisé comme engrais sur une plante qui pousse
Config.Fertilizer = {
	ItemId = "Manure",
	TimeReduction = 0.5, -- retire 50 % du temps de pousse restant (une fois par plante)
}

--------------------------------------------------------------------------
-- VARIANTES (animaux, et plus tard ressources / produits / créatures)
--   Chance             : probabilité à l'achat d'un animal (Normal = le reste)
--   SpeedMultiplier    : vitesse de production de l'animal
--   ValueMultiplier    : multiplicateur du prix de vente des ressources produites
--   DisplayName(F)     : adjectif masculin / féminin ("Lait Doré", "Laine Dorée")
--   Effect             : effet visuel ("Gold", "Rainbow", "Aura")
--------------------------------------------------------------------------
Config.Variants = {
	Normal = {
		Order = 1,
		Prestige = 1, -- points de prestige d'un animal de cette variante (vitrine)
		DisplayName = "",
		DisplayNameF = "",
		Chance = 0,
		SpeedMultiplier = 1,
		ValueMultiplier = 1,
		Color = Color3.fromRGB(255, 255, 255),
	},
	Gold = {
		Order = 2,
		Prestige = 5, -- points de prestige d'un animal de cette variante (vitrine)
		DisplayName = "Doré",
		DisplayNameF = "Dorée",
		Chance = 0.05,
		SpeedMultiplier = 1.25,
		ValueMultiplier = 2,
		Color = Color3.fromRGB(255, 205, 50),
		Gold = true,
	},
	Rainbow = {
		Order = 3,
		Prestige = 25, -- points de prestige d'un animal de cette variante (vitrine)
		DisplayName = "Arc-en-ciel",
		DisplayNameF = "Arc-en-ciel",
		Chance = 0.015,
		SpeedMultiplier = 1.5,
		ValueMultiplier = 4,
		Color = Color3.fromRGB(255, 120, 220),
		Rainbow = true,
	},
	Legendary = {
		Order = 4,
		Prestige = 100, -- points de prestige d'un animal de cette variante (vitrine)
		DisplayName = "Légendaire",
		DisplayNameF = "Légendaire",
		Chance = 0.004,
		SpeedMultiplier = 2,
		ValueMultiplier = 8,
		Color = Color3.fromRGB(255, 170, 30),
		Gold = true,
		Aura = Color3.fromRGB(255, 220, 90),
	},
	Mythic = {
		Order = 5,
		Prestige = 500, -- points de prestige d'un animal de cette variante (vitrine)
		DisplayName = "Mythique",
		DisplayNameF = "Mythique",
		Chance = 0.001,
		SpeedMultiplier = 3,
		ValueMultiplier = 20,
		Color = Color3.fromRGB(190, 90, 255),
		Rainbow = true,
		Aura = Color3.fromRGB(180, 80, 255),
		AnnounceToServer = true, -- message à tous les joueurs du serveur
	},
}

--------------------------------------------------------------------------
-- RESSOURCES produites par les animaux
--------------------------------------------------------------------------
Config.Resources = {
	Egg = { DisplayName = "Œuf", Icon = "🥚", Order = 1, SellPrice = 20 },
	Fur = { DisplayName = "Fourrure", Icon = "🐾", Order = 2, SellPrice = 45, Feminine = true },
	Feather = { DisplayName = "Plume", Icon = "🪶", Order = 3, SellPrice = 70, Feminine = true },
	Wool = { DisplayName = "Laine", Icon = "🧶", Order = 4, SellPrice = 120, Feminine = true },
	GoatMilk = { DisplayName = "Lait de chèvre", Icon = "🍼", Order = 5, SellPrice = 190 },
	Milk = { DisplayName = "Lait", Icon = "🥛", Order = 6, SellPrice = 350 },
	Manure = { DisplayName = "Fumier", Icon = "💩", Order = 7, SellPrice = 60 },
	Truffle = { DisplayName = "Truffe", Icon = "🍄", Order = 8, SellPrice = 800, Feminine = true },
	-- Crins des chevaux sauvages (capturés en expédition, puis mis en enclos)
	MossMane = { DisplayName = "Crin de mousse", Icon = "🌿", Order = 9, SellPrice = 450 },
	FrostMane = { DisplayName = "Crin de givre", Icon = "❄️", Order = 10, SellPrice = 1200 },
	SandMane = { DisplayName = "Crin doré", Icon = "✨", Order = 11, SellPrice = 2500 },
	EmberMane = { DisplayName = "Crin de braise", Icon = "🔥", Order = 12, SellPrice = 6000 },
	-- Ressource EXCLUSIVE de l'Astrelune (roue quotidienne)
	Stardust = { DisplayName = "Poussière d'étoile", Icon = "🌠", Order = 13, SellPrice = 30000, Feminine = true },
}

--------------------------------------------------------------------------
-- ANIMAUX DE FERME
--   Price          : prix d'achat au stand 🐄 ANIMAUX
--   Resource       : ressource produite (Config.Resources)
--   ProductionTime : secondes pour produire 1 ressource (variante Normale)
--   FeedPerProduct : rations consommées par ressource produite
--   Diet           : récoltes acceptées dans la mangeoire (dans l'ordre de préférence)
--   Visuel en Parts : BodySize, HeadSize, LegHeight, Color, HeadColor, + détails optionnels
--------------------------------------------------------------------------
Config.Animals = {
	Chicken = {
		DisplayName = "Poule", Icon = "🐔", Feminine = true, Order = 1,
		Price = 150, Resource = "Egg", ProductionTime = 30, FeedPerProduct = 1,
		Diet = { "Wheat", "Corn" },
		BodySize = Vector3.new(1.4, 1.2, 1.6), HeadSize = Vector3.new(0.8, 0.8, 0.8), LegHeight = 0.6,
		Color = Color3.fromRGB(245, 245, 240), HeadColor = Color3.fromRGB(245, 245, 240),
		Beak = true, Crest = true,
	},
	Rabbit = {
		DisplayName = "Lapin", Icon = "🐰", Order = 2,
		Price = 400, Resource = "Fur", ProductionTime = 45, FeedPerProduct = 2,
		Diet = { "Carrot" },
		BodySize = Vector3.new(1.2, 1.1, 1.6), HeadSize = Vector3.new(0.9, 0.9, 0.9), LegHeight = 0.3,
		Color = Color3.fromRGB(200, 180, 160), HeadColor = Color3.fromRGB(210, 190, 170),
		Ears = true,
	},
	Duck = {
		DisplayName = "Canard", Icon = "🦆", Order = 3,
		Price = 800, Resource = "Feather", ProductionTime = 60, FeedPerProduct = 3,
		Diet = { "Wheat", "Carrot" },
		BodySize = Vector3.new(1.4, 1.1, 1.9), HeadSize = Vector3.new(0.8, 0.8, 0.8), LegHeight = 0.5,
		Color = Color3.fromRGB(240, 240, 235), HeadColor = Color3.fromRGB(40, 130, 60),
		Beak = true,
	},
	Sheep = {
		DisplayName = "Brebis", Icon = "🐑", Feminine = true, Order = 4,
		Price = 1500, Resource = "Wool", ProductionTime = 90, FeedPerProduct = 5,
		Diet = { "Wheat", "Carrot" },
		BodySize = Vector3.new(2.4, 2, 3), HeadSize = Vector3.new(1, 1, 1.1), LegHeight = 1,
		Color = Color3.fromRGB(240, 240, 240), HeadColor = Color3.fromRGB(60, 55, 55),
	},
	Goat = {
		DisplayName = "Chèvre", Icon = "🐐", Feminine = true, Order = 5,
		Price = 3000, Resource = "GoatMilk", ProductionTime = 100, FeedPerProduct = 8,
		Diet = { "Carrot", "Tomato", "Wheat" },
		BodySize = Vector3.new(1.8, 1.7, 2.8), HeadSize = Vector3.new(0.9, 1, 1.2), LegHeight = 1.3,
		Color = Color3.fromRGB(190, 170, 140), HeadColor = Color3.fromRGB(180, 160, 130),
		Horns = true,
	},
	Cow = {
		DisplayName = "Vache", Icon = "🐄", Feminine = true, Order = 6,
		Price = 6000, Resource = "Milk", ProductionTime = 120, FeedPerProduct = 12,
		Diet = { "Wheat", "Corn" },
		BodySize = Vector3.new(2.6, 2.3, 4.2), HeadSize = Vector3.new(1.4, 1.4, 1.6), LegHeight = 1.6,
		Color = Color3.fromRGB(250, 250, 250), HeadColor = Color3.fromRGB(250, 250, 250),
		Spots = Color3.fromRGB(30, 30, 30), Horns = true,
	},
	Horse = {
		DisplayName = "Cheval", Icon = "🐴", Order = 7,
		Price = 8000, Resource = "Manure", ProductionTime = 90, FeedPerProduct = 3,
		Diet = { "Carrot", "Wheat" },
		BodySize = Vector3.new(2, 2.2, 4.4), HeadSize = Vector3.new(1, 1.3, 2), LegHeight = 2.6,
		Color = Color3.fromRGB(130, 80, 45), HeadColor = Color3.fromRGB(120, 75, 40),
		Mane = Color3.fromRGB(40, 30, 25),
	},
	Pig = {
		DisplayName = "Cochon", Icon = "🐷", Order = 8,
		Price = 15000, Resource = "Truffle", ProductionTime = 180, FeedPerProduct = 25,
		Diet = { "Pumpkin", "Tomato", "Corn" },
		BodySize = Vector3.new(2.2, 1.8, 3.2), HeadSize = Vector3.new(1.4, 1.3, 1.1), LegHeight = 0.8,
		Color = Color3.fromRGB(250, 170, 180), HeadColor = Color3.fromRGB(250, 165, 175),
		Snout = true,
	},

	-- Chevaux SAUVAGES : pas en vente, obtenus en capturant le cheval de chaque zone
	-- (NotForSale = true). Ils servent de monture ET produisent un crin rare en enclos.
	ForestHorse = {
		DisplayName = "Mousseval", Icon = "🐴", Order = 20, NotForSale = true,
		Price = 0, Resource = "MossMane", ProductionTime = 120, FeedPerProduct = 10,
		Diet = { "Carrot", "Wheat" },
		BodySize = Vector3.new(2, 2.2, 4.4), HeadSize = Vector3.new(1, 1.3, 2), LegHeight = 2.6,
		Color = Color3.fromRGB(90, 140, 70), HeadColor = Color3.fromRGB(80, 130, 65),
		Mane = Color3.fromRGB(190, 230, 120),
	},
	SnowHorse = {
		DisplayName = "Givrecrin", Icon = "🐴", Order = 21, NotForSale = true,
		Price = 0, Resource = "FrostMane", ProductionTime = 150, FeedPerProduct = 20,
		Diet = { "Blueberry", "Carrot", "Wheat" },
		BodySize = Vector3.new(2, 2.2, 4.4), HeadSize = Vector3.new(1, 1.3, 2), LegHeight = 2.8,
		Color = Color3.fromRGB(235, 245, 255), HeadColor = Color3.fromRGB(225, 240, 255),
		Mane = Color3.fromRGB(120, 200, 255),
	},
	SandHorse = {
		DisplayName = "Sablecrin", Icon = "🐴", Order = 22, NotForSale = true,
		Price = 0, Resource = "SandMane", ProductionTime = 180, FeedPerProduct = 40,
		Diet = { "Watermelon", "Corn", "Carrot" },
		BodySize = Vector3.new(1.9, 2.1, 4.6), HeadSize = Vector3.new(1, 1.3, 2), LegHeight = 2.9,
		Color = Color3.fromRGB(225, 185, 110), HeadColor = Color3.fromRGB(215, 175, 100),
		Mane = Color3.fromRGB(255, 240, 170),
	},
	LavaHorse = {
		DisplayName = "Brasecrin", Icon = "🐴", Order = 23, NotForSale = true,
		Price = 0, Resource = "EmberMane", ProductionTime = 240, FeedPerProduct = 80,
		Diet = { "Pumpkin", "Dragonfruit", "Corn" },
		BodySize = Vector3.new(2.1, 2.3, 4.6), HeadSize = Vector3.new(1.05, 1.35, 2.05), LegHeight = 2.8,
		Color = Color3.fromRGB(45, 30, 30), HeadColor = Color3.fromRGB(55, 35, 30),
		Mane = Color3.fromRGB(255, 110, 20), Horns = true,
	},

	-- Animal EXCLUSIF de la roue quotidienne (0,1 %) : introuvable ailleurs.
	-- Cheval céleste à corne d'étoile, crinière arc-en-ciel, auréole et poussière d'étoiles.
	Astrelune = {
		DisplayName = "Astrelune", Icon = "🦄", Feminine = true, Order = 30, NotForSale = true, Celestial = true,
		Price = 0, Resource = "Stardust", ProductionTime = 300, FeedPerProduct = 30,
		Diet = { "StarFlower", "MoonPumpkin", "Strawberry", "Carrot" },
		BodySize = Vector3.new(2, 2.2, 4.4), HeadSize = Vector3.new(1, 1.3, 2), LegHeight = 2.9,
		Color = Color3.fromRGB(235, 225, 255), HeadColor = Color3.fromRGB(245, 235, 255),
		Mane = Color3.fromRGB(255, 120, 220), Horns = true,
	},
}

--------------------------------------------------------------------------
-- ENCLOS
--------------------------------------------------------------------------
Config.Pens = {
	Size = 20, -- côté de l'enclos (studs)
	Capacity = 4, -- animaux max par enclos (une seule espèce par enclos)
	InventoryCapacity = 60, -- animaux max dans 🐾 Mes animaux (hors enclos)
	FeedCapacity = 300, -- rations max dans la mangeoire
	StorageCapacity = 30, -- ressources max dans la caisse avant de devoir les récupérer
	MaxOfflineSeconds = 8 * 3600, -- production hors ligne plafonnée à 8 h
	InteractDistance = 10,

	-- Prix du 1er, 2e, 3e... enclos construit
	Prices = { 300, 1500, 5000, 15000, 40000, 100000, 250000, 600000 },
	-- Nombre max d'enclos selon le niveau de la parcelle (1 à 4)
	MaxByLevel = { 2, 4, 6, 8 },
	-- RESSOURCES RARES : chance qu'une production soit d'une variante SUPÉRIEURE à celle de
	-- l'animal (Normal -> Doré -> Arc-en-ciel -> Légendaire -> Mythique). Plus l'animal est rare,
	-- plus la chance est élevée.
	RareProduceChance = { Normal = 0.03, Gold = 0.05, Rainbow = 0.07, Legendary = 0.1, Mythic = 0 },
	-- Emprise d'un enclos placé (largeur X, profondeur Z) : clôture + mangeoire et caisse devant
	Footprint = Vector2.new(22, 26),

	-- Anciennes positions fixes (avant le mode construction) : utilisées UNIQUEMENT pour
	-- convertir les anciennes sauvegardes. X = gauche/droite, Z = profondeur depuis l'entrée.
	LegacySlots = {
		{ X = -37, Z = 20, RequiredLevel = 1 },
		{ X = 37, Z = 20, RequiredLevel = 1 },
		{ X = -37, Z = 46, RequiredLevel = 2 },
		{ X = 37, Z = 46, RequiredLevel = 2 },
		{ X = -37, Z = 72, RequiredLevel = 3 },
		{ X = 37, Z = 72, RequiredLevel = 3 },
		{ X = -37, Z = 98, RequiredLevel = 4 },
		{ X = 37, Z = 98, RequiredLevel = 4 },
	},
}

--------------------------------------------------------------------------
-- STANDS (au centre de la map)
--------------------------------------------------------------------------
Config.Stands = {
	SeedShopPosition = Vector3.new(-30, 0, 0),
	SellStandPosition = Vector3.new(30, 0, 0),
	AnimalShopPosition = Vector3.new(0, 0, -24),
	DungeonPortalPosition = Vector3.new(-62, 0, 0), -- portail rouge des donjons (phase 8)
	MaxDistance = 16, -- distance max pour acheter / vendre (vérifiée par le serveur)
}

Config.Shop = {
	BuyAmounts = { 1, 5 }, -- boutons d'achat affichés dans la boutique de graines
	MaxBuyAmount = 25, -- quantité max par requête
	BuyCooldown = 0.2,

	-- Stock TOURNANT des graines rares (même stock pour tout le serveur, quantité par joueur)
	Rotation = {
		Interval = 300, -- secondes entre deux renouvellements (compte à rebours affiché)
		Chance = { Rare = 0.8, Epic = 0.4, Legendary = 0.12 }, -- chance qu'une graine soit en stock
		Stock = { Rare = { 3, 6 }, Epic = { 1, 3 }, Legendary = { 1, 1 } }, -- quantité par joueur (min, max)
	},
}

--------------------------------------------------------------------------
-- PARCELLES (générées en Parts simples au démarrage du serveur)
--   Le point d'origine d'une parcelle est le MILIEU DE SON ENTRÉE (côté allée).
--   Elle s'agrandit vers le fond et sur les côtés, l'entrée ne bouge pas.
--------------------------------------------------------------------------
Config.Plots = {
	Count = 6, -- nombre de parcelles sur la map (= nombre max de joueurs conseillé)
	Columns = 3, -- 2 rangées de 3 parcelles, face à face
	SpacingX = 180, -- distance entre les centres de deux parcelles voisines (axe X)
	FrontOffsetZ = 40, -- distance entre le centre de la map et l'entrée d'une parcelle
	BaseHeight = 1, -- épaisseur du sol de la parcelle

	-- Étapes d'agrandissement (Width = largeur, Depth = profondeur, Price en Coins)
	Expansions = {
		{ Width = 98, Depth = 64, Price = 0 },
		{ Width = 118, Depth = 90, Price = 3000 },
		{ Width = 138, Depth = 116, Price = 20000 },
		{ Width = 158, Depth = 142, Price = 100000 },
	},
	ExpandInteractDistance = 10,
	GateWidth = 16, -- ouverture de la clôture à l'entrée de la parcelle

	GroundColor = Color3.fromRGB(150, 210, 95), -- sol de parcelle par défaut (plus clair que la map)
	BorderColor = Color3.fromRGB(110, 75, 45),
	SignColor = Color3.fromRGB(150, 105, 60),

	FreeLabel = "Parcelle libre",
	OwnerLabelFormat = "Ferme de %s", -- %s = DisplayName du joueur
}

--------------------------------------------------------------------------
-- BOUTONS AU SOL (style tycoon), dans la bande d'entrée de chaque parcelle
--   X, Z : position locale (X = gauche/droite, Z = profondeur depuis l'entrée ; Z < 10)
--   Product : clé de Config.Monetization.Products (achat Robux)
--------------------------------------------------------------------------
Config.TycoonPads = {
	Size = 4.6, -- côté d'un bouton (studs)
	Height = 1.2, -- hauteur du socle du bouton (bien visible au-dessus du sol)
	ExpandCoins = { X = -43, Z = 4 }, -- 💰 agrandir avec les Coins
	ExpandRobux = { X = -36.5, Z = 4, Product = "PlotExpansion" }, -- 💎 agrandir avec des Robux
	Boosts = {
		{ X = -30, Z = 4, Product = "GrowthBoost2h" },
		{ X = 24.5, Z = 4, Product = "ProductionBoost2h" },
		{ X = 31, Z = 4, Product = "XPBoost2h" },
		{ X = 37.5, Z = 4, Product = "CoinsBoost2h" },
	},
	TouchCooldown = 4, -- secondes entre deux fenêtres d'achat en marchant sur un bouton
}

--------------------------------------------------------------------------
-- DÉPLACEMENT DU PERSONNAGE
--------------------------------------------------------------------------
Config.Movement = {
	WalkSpeed = 24, -- vitesse de marche normale (Roblox par défaut : 16)
	SprintEnabled = true,
	SprintSpeed = 32, -- vitesse en courant (touche maintenue, ou bouton sur mobile)
	SprintKeys = { Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift },
	-- Monture : voir Config.Mounts (vitesse selon le cheval monté)
}

--------------------------------------------------------------------------
-- MONTURES (chevaux de ferme et chevaux sauvages capturés)
--   Species : vitesse de marche, de sprint, saut, et petit texte de description par espèce
--   (les espèces sont dans Config.Animals ; un cheval sauvage capturé a le champ Horse).
--------------------------------------------------------------------------
Config.Mounts = {
	RiderOffset = 1.1, -- hauteur du personnage au-dessus du dos du cheval
	VariantSpeedBonus = 0.05, -- +5 % de vitesse par rang de variante (Doré, Arc-en-ciel...)
	-- Mutation d'un cheval sauvage -> variante (couleur, effets, valeur de sa production)
	MutationToVariant = { Normal = "Normal", Gold = "Gold", Giant = "Legendary", Rainbow = "Rainbow", Spectral = "Mythic" },
	Species = {
		Horse = { Speed = 40, SprintSpeed = 48, JumpPower = 50, Perk = "Fidèle cheval de ferme" },
		ForestHorse = { Speed = 44, SprintSpeed = 54, JumpPower = 58, Perk = "Agile et équilibré" },
		SnowHorse = { Speed = 44, SprintSpeed = 54, JumpPower = 80, Perk = "Saute très haut" },
		SandHorse = { Speed = 52, SprintSpeed = 64, JumpPower = 50, Perk = "Le plus rapide" },
		LavaHorse = { Speed = 50, SprintSpeed = 62, JumpPower = 65, Perk = "Rapide et puissant" },
		Astrelune = { Speed = 56, SprintSpeed = 70, JumpPower = 90, Perk = "Monture céleste exclusive" },
	},
}

--------------------------------------------------------------------------
-- PRODUITS TRANSFORMÉS (fabriqués dans les bâtiments)
--   Valeur ≈ 1,8 à 2,5 fois celle des ingrédients ; la variante de l'ingrédient
--   principal est transmise au produit ("Beurre Doré" = x2).
--------------------------------------------------------------------------
Config.Products = {
	Bread = { DisplayName = "Pain", Icon = "🍞", Order = 1, SellPrice = 70 },
	Cake = { DisplayName = "Gâteau", Icon = "🍰", Order = 2, SellPrice = 170 },
	Yarn = { DisplayName = "Fil", Icon = "🧵", Order = 3, SellPrice = 520 },
	Fabric = { DisplayName = "Tissu", Icon = "🧣", Order = 4, SellPrice = 2300 },
	Cream = { DisplayName = "Crème", Icon = "🍦", Order = 5, SellPrice = 700, Feminine = true },
	Butter = { DisplayName = "Beurre", Icon = "🧈", Order = 6, SellPrice = 1500 },
	GoatCheese = { DisplayName = "Fromage de chèvre", Icon = "🥧", Order = 7, SellPrice = 1300 },
	Cheese = { DisplayName = "Fromage", Icon = "🧀", Order = 8, SellPrice = 2400 },
	TruffleCheese = { DisplayName = "Fromage truffé", Icon = "🏆", Order = 9, SellPrice = 12000 },
	Pillow = { DisplayName = "Oreiller", Icon = "🛏️", Order = 10, SellPrice = 5800 },
	Coat = { DisplayName = "Manteau", Icon = "🧥", Order = 11, SellPrice = 5600 },

	-- Produits RARES (recettes rares : ingrédient principal d'une variante minimale)
	RoyalCake = { DisplayName = "Gâteau royal", Icon = "🎂", Order = 20, SellPrice = 2500, Rarity = "Rare" },
	RainbowFabric = { DisplayName = "Tissu arc-en-ciel", Icon = "🌈", Order = 21, SellPrice = 25000, Rarity = "Epic" },
	CelestialBread = { DisplayName = "Pain céleste", Icon = "🥐", Order = 22, SellPrice = 9000, Rarity = "Legendary" },
	LegendaryCheese = { DisplayName = "Fromage légendaire", Icon = "👑", Order = 23, SellPrice = 120000, Rarity = "Legendary" },
	DivineCream = { DisplayName = "Crème divine", Icon = "✨", Order = 24, SellPrice = 250000, Rarity = "Mythic", Feminine = true },
	RoyalCoat = { DisplayName = "Manteau royal", Icon = "🦚", Order = 25, SellPrice = 18000, Rarity = "Rare" },
}

--------------------------------------------------------------------------
-- BÂTIMENTS DE TRANSFORMATION
--   Price          : prix de construction (Coins)
--   RequiredLevel  : niveau de parcelle nécessaire
--   Requires       : bâtiment à construire avant (ordre de déblocage)
--   X, Z           : position par défaut (anciennes sauvegardes) ; ensuite le joueur
--                    place librement le bâtiment avec le mode construction
--   Recipes        : Inputs (le 1er ingrédient donne la variante du produit),
--                    Output, Time (secondes au niveau 1), RequiredBuildingLevel (optionnel),
--                    MinVariant (optionnel) : recette RARE, l'ingrédient principal doit être au
--                    moins de cette variante ; le produit est alors un objet rare (variante Normale)
-- Ordre de déblocage : Boulangerie (blé, œufs) -> Filature (laine) -> Laiterie (lait)
--                      -> Fromagerie -> Atelier de couture (tissu + plumes / fourrure)
--------------------------------------------------------------------------
Config.Buildings = {
	Bakery = {
		DisplayName = "Boulangerie", Icon = "🥖", Order = 1, Feminine = true,
		Price = 1500, RequiredLevel = 1, Requires = nil,
		X = -12, Z = 50, Width = 13, Depth = 11,
		WallColor = Color3.fromRGB(235, 210, 170), RoofColor = Color3.fromRGB(170, 70, 50),
		Recipes = {
			{ Id = "Bread", Inputs = { { Item = "Wheat", Amount = 4 } }, Output = { Item = "Bread", Amount = 1 }, Time = 30 },
			{ Id = "Cake", Inputs = { { Item = "Egg", Amount = 3 }, { Item = "Wheat", Amount = 2 } }, Output = { Item = "Cake", Amount = 1 }, Time = 60 },
			-- Recettes rares : MinVariant = variante minimale de l'ingrédient principal
			{ Id = "RoyalCake", MinVariant = "Gold", Inputs = { { Item = "Egg", Amount = 3 }, { Item = "Wheat", Amount = 2 } }, Output = { Item = "RoyalCake", Amount = 1 }, Time = 120 },
			{ Id = "CelestialBread", MinVariant = "Legendary", Inputs = { { Item = "Wheat", Amount = 4 } }, Output = { Item = "CelestialBread", Amount = 1 }, Time = 240 },
		},
	},
	Spinning = {
		DisplayName = "Filature", Icon = "🧶", Order = 2, Feminine = true,
		Price = 8000, RequiredLevel = 1, Requires = "Bakery",
		X = 12, Z = 50, Width = 13, Depth = 11,
		WallColor = Color3.fromRGB(200, 190, 230), RoofColor = Color3.fromRGB(90, 70, 150),
		Recipes = {
			{ Id = "Yarn", Inputs = { { Item = "Wool", Amount = 2 } }, Output = { Item = "Yarn", Amount = 1 }, Time = 60 },
			{ Id = "Fabric", Inputs = { { Item = "Yarn", Amount = 2 } }, Output = { Item = "Fabric", Amount = 1 }, Time = 120 },
			{ Id = "RainbowFabric", MinVariant = "Rainbow", Inputs = { { Item = "Wool", Amount = 3 } }, Output = { Item = "RainbowFabric", Amount = 1 }, Time = 300 },
		},
	},
	Dairy = {
		DisplayName = "Laiterie", Icon = "🥛", Order = 3, Feminine = true,
		Price = 25000, RequiredLevel = 2, Requires = "Spinning",
		X = -12, Z = 72, Width = 13, Depth = 11,
		WallColor = Color3.fromRGB(240, 245, 255), RoofColor = Color3.fromRGB(60, 120, 200),
		Recipes = {
			{ Id = "Cream", Inputs = { { Item = "Milk", Amount = 1 } }, Output = { Item = "Cream", Amount = 1 }, Time = 45 },
			{ Id = "Butter", Inputs = { { Item = "Milk", Amount = 2 } }, Output = { Item = "Butter", Amount = 1 }, Time = 90 },
			{ Id = "DivineCream", MinVariant = "Mythic", Inputs = { { Item = "Milk", Amount = 2 } }, Output = { Item = "DivineCream", Amount = 1 }, Time = 600, RequiredBuildingLevel = 3 },
		},
	},
	Cheese = {
		DisplayName = "Fromagerie", Icon = "🧀", Order = 4, Feminine = true,
		Price = 60000, RequiredLevel = 2, Requires = "Dairy",
		X = 12, Z = 72, Width = 13, Depth = 11,
		WallColor = Color3.fromRGB(255, 225, 130), RoofColor = Color3.fromRGB(150, 100, 40),
		Recipes = {
			{ Id = "GoatCheese", Inputs = { { Item = "GoatMilk", Amount = 3 } }, Output = { Item = "GoatCheese", Amount = 1 }, Time = 120 },
			{ Id = "Cheese", Inputs = { { Item = "Milk", Amount = 3 } }, Output = { Item = "Cheese", Amount = 1 }, Time = 150 },
			{
				Id = "TruffleCheese",
				Inputs = { { Item = "Cheese", Amount = 2 }, { Item = "Truffle", Amount = 1 } },
				Output = { Item = "TruffleCheese", Amount = 1 },
				Time = 240,
				RequiredBuildingLevel = 3, -- recette débloquée au niveau 3 du bâtiment
			},
			{ Id = "LegendaryCheese", MinVariant = "Legendary", Inputs = { { Item = "Milk", Amount = 3 } }, Output = { Item = "LegendaryCheese", Amount = 1 }, Time = 480, RequiredBuildingLevel = 2 },
		},
	},
	Tailor = {
		DisplayName = "Atelier de couture", Icon = "🪡", Order = 5,
		Price = 150000, RequiredLevel = 3, Requires = "Cheese",
		X = 0, Z = 96, Width = 15, Depth = 11,
		WallColor = Color3.fromRGB(250, 200, 210), RoofColor = Color3.fromRGB(180, 60, 110),
		Recipes = {
			{ Id = "Pillow", Inputs = { { Item = "Fabric", Amount = 1 }, { Item = "Feather", Amount = 4 } }, Output = { Item = "Pillow", Amount = 1 }, Time = 180 },
			{ Id = "Coat", Inputs = { { Item = "Fabric", Amount = 1 }, { Item = "Fur", Amount = 5 } }, Output = { Item = "Coat", Amount = 1 }, Time = 180 },
			{ Id = "RoyalCoat", MinVariant = "Gold", Inputs = { { Item = "Fur", Amount = 5 }, { Item = "Fabric", Amount = 1 } }, Output = { Item = "RoyalCoat", Amount = 1 }, Time = 300 },
		},
	},
}

-- Niveaux d'amélioration (communs à tous les bâtiments)
--   CostMultiplier : prix de l'amélioration = Price du bâtiment x ce multiplicateur
--   Speed          : vitesse de production
--   Slots          : nombre de productions EN MÊME TEMPS
--   QueueSize      : nombre max de commandes dans la file d'attente
Config.BuildingLevels = {
	{ CostMultiplier = 0, Speed = 1, Slots = 1, QueueSize = 5 },
	{ CostMultiplier = 1.5, Speed = 1.25, Slots = 1, QueueSize = 8 },
	{ CostMultiplier = 3, Speed = 1.5, Slots = 2, QueueSize = 10 },
	{ CostMultiplier = 6, Speed = 2, Slots = 2, QueueSize = 12 },
	{ CostMultiplier = 12, Speed = 2.5, Slots = 3, QueueSize = 15 },
}

Config.BuildingSettings = {
	OutputCapacity = 40, -- produits finis max en attente dans un bâtiment
	MaxOfflineSeconds = 8 * 3600, -- production hors ligne plafonnée à 8 h
	InteractDistance = 12,
	QueueAmounts = { 1, 5 }, -- boutons "Lancer x1 / x5" dans l'interface
}

--------------------------------------------------------------------------
-- EXPÉDITIONS : PORTAIL ET ZONES
--   Les zones sont des zones lointaines de la MÊME place (pas de TeleportService).
--   Center     : centre de la zone (le sol est à Y = Center.Y)
--   Size       : côté de la zone (studs)
--   UnlockPrice: prix pour débloquer l'accès (0 = gratuit)
--   ValueMultiplier : multiplie la valeur des créatures de la zone
--   IncomeMultiplier: multiplie les Coins / seconde des créatures exposées de la zone
--   Props      : décor simple ("Trees", "Rocks", "Cacti", "Lava")
--------------------------------------------------------------------------
Config.Expeditions = {
	PortalPosition = Vector3.new(0, 0, 26), -- portail principal, devant le spawn
	PortalInteractDistance = 12,

	MaxWildPerZone = 12, -- créatures sauvages max en même temps dans une zone
	SpawnInterval = 2.5, -- secondes entre deux apparitions (si des joueurs sont dans la zone)
	-- Plus d'apparitions, mais surtout des COMMUNES : le poids des communes est multiplié,
	-- ce qui garde à peu près le même rythme d'apparition pour les raretés hautes
	SpawnRarityBoost = { Common = 2 },
	EntrySpawn = 4, -- créatures qui apparaissent tout de suite quand on arrive dans la zone
	EntryRarityBoost = { Common = 3, Rare = 1.5 },
	WildLifetime = 150, -- secondes avant qu'une créature sauvage reparte
	WildWanderRadius = 6,
	SpawnMargin = 35, -- bande du bord de zone sans créatures (réservée au décor, phase 10)
	CaptureDistance = 12, -- distance max pour lancer une capture

	MaxCreatures = 100, -- créatures max dans la collection
	CaptureTimeout = 20, -- secondes max pour finir le mini-jeu
	MaxLatency = 1.0, -- tolérance réseau (s) sur le moment du clic envoyé par le client
	HitTolerance = 0.02, -- marge (en fraction de barre) autour de la zone verte
}

Config.Zones = {
	Forest = {
		DisplayName = "Forêt", Icon = "🌲", Order = 1, Feminine = true,
		UnlockPrice = 0, ValueMultiplier = 1, IncomeMultiplier = 1,
		Center = Vector3.new(-900, 0, 1400), Size = 320,
		GroundColor = Color3.fromRGB(80, 150, 60), GroundMaterial = Enum.Material.Grass,
		WallColor = Color3.fromRGB(60, 100, 50), Props = "Trees",
	},
	Mountain = {
		DisplayName = "Montagne", Icon = "⛰️", Order = 2, Feminine = true,
		UnlockPrice = 25000, ValueMultiplier = 4, IncomeMultiplier = 3,
		Center = Vector3.new(-300, 0, 1400), Size = 320,
		GroundColor = Color3.fromRGB(150, 150, 160), GroundMaterial = Enum.Material.Slate,
		WallColor = Color3.fromRGB(230, 235, 245), Props = "Rocks",
	},
	Desert = {
		DisplayName = "Désert", Icon = "🏜️", Order = 3,
		UnlockPrice = 100000, ValueMultiplier = 15, IncomeMultiplier = 8,
		Center = Vector3.new(300, 0, 1400), Size = 320,
		GroundColor = Color3.fromRGB(235, 205, 140), GroundMaterial = Enum.Material.Sand,
		WallColor = Color3.fromRGB(200, 150, 90), Props = "Cacti",
	},
	Volcano = {
		DisplayName = "Volcan", Icon = "🌋", Order = 4,
		UnlockPrice = 400000, ValueMultiplier = 50, IncomeMultiplier = 20,
		Center = Vector3.new(900, 0, 1400), Size = 320,
		GroundColor = Color3.fromRGB(60, 45, 45), GroundMaterial = Enum.Material.Basalt,
		WallColor = Color3.fromRGB(40, 30, 30), Props = "Lava",
	},
}

--------------------------------------------------------------------------
-- RARETÉS DES CRÉATURES
--   Weight    : poids d'apparition (en % si le total fait 100)
--   BaseValue : valeur de base (x zone x mutation) ; sert à la vente
--   Income    : Coins / seconde quand la créature est exposée sur un socle (x zone x mutation)
--   Prestige  : points de prestige (vitrine, meilleure prise, classement)
--   Announce  : "Server" = bannière, "Chat" = chat + bannière, "Global" = TOUS les serveurs
--   SpawnAlert: "Zone" = prévient les joueurs de la zone à l'apparition, "Server" = tout le serveur
--   Capture : DEUX MODES, choisis par le joueur au début de chaque capture
--     Safe (🎯 Sûr)    : 100 % de chance finale, mini-jeu un peu plus dur
--     Fast (⚡ Rapide) : mini-jeu un peu plus facile, chance finale plus faible
--     Pour chaque mode :
--       Hits      = clics réussis à enchaîner
--       Width     = largeur de la zone verte (fraction de la barre, 0 à 1)
--       Speed     = allers par seconde du curseur (plus petit = plus lent)
--       MaxMisses = ratés autorisés
--       Chance    = tirage final après le mini-jeu réussi (0 à 1)
--   Visual (en attendant les vrais modèles de la phase 10) :
--     Scale     = taille du modèle (Commune = 1)
--     Vivid     = couleurs plus saturées et lumineuses
--     Particles = étincelles par seconde autour de la créature (0 = aucune)
--     Light     = portée de la lumière émise (0 = aucune)
--     Beacon    = colonne de lumière visible de loin (course entre les joueurs)
--------------------------------------------------------------------------
Config.CreatureRarities = {
	Common = {
		DisplayName = "Commune", Order = 1, Color = Color3.fromRGB(200, 200, 200),
		Weight = 60, BaseValue = 100,
		Income = 1, Prestige = 1,
		Capture = {
			Safe = { Hits = 1, Width = 0.26, Speed = 0.85, MaxMisses = 2, Chance = 1 }, -- 🎯 Sûr
			Fast = { Hits = 1, Width = 0.32, Speed = 0.78, MaxMisses = 2, Chance = 0.97 }, -- ⚡ Rapide
		},
		Visual = { Scale = 1, Vivid = false, Particles = 0, Light = 0, Beacon = false },
	},
	Rare = {
		DisplayName = "Rare", Order = 2, Color = Color3.fromRGB(70, 150, 255),
		Weight = 25, BaseValue = 400,
		Income = 4, Prestige = 5,
		Capture = {
			Safe = { Hits = 2, Width = 0.23, Speed = 0.9, MaxMisses = 2, Chance = 1 }, -- 🎯 Sûr
			Fast = { Hits = 2, Width = 0.28, Speed = 0.82, MaxMisses = 2, Chance = 0.92 }, -- ⚡ Rapide
		},
		Visual = { Scale = 1.05, Vivid = false, Particles = 0, Light = 0, Beacon = false },
	},
	Epic = {
		DisplayName = "Épique", Order = 3, Color = Color3.fromRGB(170, 80, 240),
		Weight = 10, BaseValue = 1500,
		Income = 15, Prestige = 25,
		Capture = {
			Safe = { Hits = 3, Width = 0.21, Speed = 0.9, MaxMisses = 2, Chance = 1 }, -- 🎯 Sûr
			Fast = { Hits = 2, Width = 0.25, Speed = 0.86, MaxMisses = 2, Chance = 0.87 }, -- ⚡ Rapide
		},
		Visual = { Scale = 1.2, Vivid = true, Particles = 3, Light = 8, Beacon = false },
	},
	Legendary = {
		DisplayName = "Légendaire", Order = 4, Color = Color3.fromRGB(255, 180, 30),
		Weight = 4, BaseValue = 6000,
		Income = 60, Prestige = 100,
		Capture = {
			Safe = { Hits = 4, Width = 0.19, Speed = 0.95, MaxMisses = 2, Chance = 1 }, -- 🎯 Sûr
			Fast = { Hits = 3, Width = 0.22, Speed = 0.9, MaxMisses = 2, Chance = 0.8 }, -- ⚡ Rapide
		},
		Visual = { Scale = 1.5, Vivid = true, Particles = 8, Light = 12, Beacon = false },
	},
	Mythic = {
		DisplayName = "Mythique", Order = 5, Color = Color3.fromRGB(255, 70, 120),
		Weight = 0.9, BaseValue = 25000, Announce = "Server", SpawnAlert = "Zone",
		Income = 250, Prestige = 500,
		Capture = {
			Safe = { Hits = 4, Width = 0.17, Speed = 1.0, MaxMisses = 3, Chance = 1 }, -- 🎯 Sûr
			Fast = { Hits = 3, Width = 0.20, Speed = 0.95, MaxMisses = 3, Chance = 0.75 }, -- ⚡ Rapide
		},
		Visual = { Scale = 1.8, Vivid = true, Particles = 15, Light = 16, Beacon = true },
	},
	Secret = {
		DisplayName = "Secrète", Order = 6, Color = Color3.fromRGB(20, 255, 200),
		Weight = 0.1, BaseValue = 120000, Announce = "Chat", SpawnAlert = "Server",
		Income = 1200, Prestige = 2500,
		Capture = {
			Safe = { Hits = 5, Width = 0.15, Speed = 1.05, MaxMisses = 3, Chance = 1 }, -- 🎯 Sûr
			Fast = { Hits = 4, Width = 0.18, Speed = 1.0, MaxMisses = 3, Chance = 0.75 }, -- ⚡ Rapide
		},
		Visual = { Scale = 2.1, Vivid = true, Particles = 25, Light = 20, Beacon = true },
	},
	Divine = {
		DisplayName = "Divine", Order = 7, Color = Color3.fromRGB(255, 235, 120),
		Weight = 0.001, BaseValue = 1500000, Announce = "Global", SpawnAlert = "Server", Divine = true,
		Income = 10000, Prestige = 25000,
		Capture = {
			Safe = { Hits = 6, Width = 0.10, Speed = 1.1, MaxMisses = 3, Chance = 1 }, -- 🎯 Sûr
			Fast = { Hits = 5, Width = 0.16, Speed = 1.05, MaxMisses = 3, Chance = 0.75 }, -- ⚡ Rapide
		},
		Visual = { Scale = 2.6, Vivid = true, Particles = 40, Light = 26, Beacon = true },
	},
}

-- Mutations des créatures sauvages (tirées à l'apparition)
Config.CreatureMutations = {
	Normal = { Order = 1, DisplayName = "", DisplayNameF = "", Chance = 0, ValueMultiplier = 1, Color = Color3.new(1, 1, 1) },
	Gold = { Order = 2, DisplayName = "Doré", DisplayNameF = "Dorée", Chance = 0.06, ValueMultiplier = 2, Color = Color3.fromRGB(255, 205, 50), Gold = true },
	Giant = { Order = 3, DisplayName = "Géant", DisplayNameF = "Géante", Chance = 0.04, ValueMultiplier = 3, Color = Color3.fromRGB(255, 140, 60), Scale = 2 },
	Rainbow = { Order = 4, DisplayName = "Arc-en-ciel", DisplayNameF = "Arc-en-ciel", Chance = 0.02, ValueMultiplier = 5, Color = Color3.fromRGB(255, 120, 220), Rainbow = true },
	Spectral = { Order = 5, DisplayName = "Spectral", DisplayNameF = "Spectrale", Chance = 0.005, ValueMultiplier = 10, Color = Color3.fromRGB(150, 255, 255), Spectral = true },
}

--------------------------------------------------------------------------
-- CRÉATURES (originales, inventées pour ce jeu)
--   Body : "Ball" | "Block" ; Size : taille du corps (studs)
--   Color / Accent : couleurs principale et secondaire
--   Features : détails en Parts ("Ears", "Horns", "Wings", "Tail", "Leaf", "Hat",
--              "Spots", "Spikes", "Legs", "Glow")
--------------------------------------------------------------------------
local function creature(zone, rarity, order, name, body, size, color, accent, features, feminine)
	return {
		DisplayName = name, Zone = zone, Rarity = rarity, Order = order, Body = body, Size = size,
		Color = color, Accent = accent, Features = features, Feminine = feminine,
	}
end
local rgb = Color3.fromRGB

Config.Creatures = {
	-- 🌲 Forêt
	Mousselin = creature("Forest", "Common", 1, "Mousselin", "Ball", 2, rgb(110, 180, 80), rgb(60, 130, 50), { "Leaf" }),
	Glandinet = creature("Forest", "Common", 2, "Glandinet", "Ball", 1.8, rgb(170, 110, 60), rgb(110, 70, 40), { "Hat" }),
	Champiloup = creature("Forest", "Rare", 3, "Champiloup", "Ball", 2.2, rgb(245, 230, 210), rgb(220, 50, 50), { "Hat", "Spots" }),
	Lucifeuille = creature("Forest", "Epic", 4, "Lucifeuille", "Ball", 1.8, rgb(200, 240, 120), rgb(255, 255, 150), { "Wings", "Glow" }, true),
	Cerfeuillu = creature("Forest", "Legendary", 5, "Cerfeuillu", "Block", 3, rgb(150, 110, 70), rgb(90, 180, 70), { "Horns", "Legs", "Leaf" }),
	Racinor = creature("Forest", "Mythic", 6, "Racinor", "Block", 3.6, rgb(100, 75, 50), rgb(120, 255, 120), { "Spikes", "Legs", "Glow" }),
	MurmureDesBois = creature("Forest", "Secret", 7, "Murmure-des-Bois", "Ball", 2.4, rgb(210, 255, 220), rgb(120, 255, 180), { "Wings", "Glow" }),

	-- ⛰️ Montagne
	Caillouteux = creature("Mountain", "Common", 1, "Caillouteux", "Ball", 2, rgb(140, 140, 150), rgb(100, 100, 110), { "Spikes" }),
	Flocon = creature("Mountain", "Common", 2, "Flocon", "Ball", 1.9, rgb(250, 250, 255), rgb(200, 220, 255), { "Ears" }),
	Bouquetonnerre = creature("Mountain", "Rare", 3, "Bouquetonnerre", "Block", 2.6, rgb(200, 190, 170), rgb(90, 90, 200), { "Horns", "Legs" }),
	Givrelle = creature("Mountain", "Epic", 4, "Givrelle", "Ball", 2, rgb(170, 230, 255), rgb(120, 220, 255), { "Wings", "Glow" }, true),
	Grizzlune = creature("Mountain", "Legendary", 5, "Grizzlune", "Block", 3.4, rgb(110, 80, 60), rgb(230, 230, 255), { "Ears", "Legs" }),
	Aquilorage = creature("Mountain", "Mythic", 6, "Aquilorage", "Ball", 2.8, rgb(90, 80, 130), rgb(190, 120, 255), { "Wings", "Tail", "Glow" }),
	Yetinou = creature("Mountain", "Secret", 7, "Yétinou", "Block", 2.6, rgb(245, 250, 255), rgb(140, 220, 255), { "Horns", "Legs", "Glow" }),

	-- 🏜️ Désert
	Dunelle = creature("Desert", "Common", 1, "Dunelle", "Ball", 1.9, rgb(230, 200, 140), rgb(200, 160, 100), { "Ears" }, true),
	Scorpinou = creature("Desert", "Common", 2, "Scorpinou", "Block", 2, rgb(200, 80, 50), rgb(120, 40, 30), { "Tail", "Spikes", "Legs" }),
	Cactouille = creature("Desert", "Rare", 3, "Cactouille", "Block", 2.4, rgb(90, 170, 80), rgb(255, 120, 180), { "Spikes" }, true),
	Mirageon = creature("Desert", "Epic", 4, "Mirageon", "Block", 2.4, rgb(120, 200, 255), rgb(200, 240, 255), { "Tail", "Legs", "Glow" }),
	Sphinxou = creature("Desert", "Legendary", 5, "Sphinxou", "Block", 3, rgb(230, 180, 80), rgb(60, 90, 200), { "Ears", "Tail", "Legs" }),
	Pharaonix = creature("Desert", "Mythic", 6, "Pharaonix", "Ball", 2.8, rgb(255, 150, 40), rgb(255, 230, 80), { "Wings", "Tail", "Glow" }),
	Oasien = creature("Desert", "Secret", 7, "Oasien", "Ball", 2.4, rgb(80, 200, 255), rgb(150, 255, 230), { "Leaf", "Glow" }),

	-- 🌋 Volcan
	Braisou = creature("Volcano", "Common", 1, "Braisou", "Ball", 1.8, rgb(255, 120, 40), rgb(255, 200, 60), { "Glow" }),
	Cendrou = creature("Volcano", "Common", 2, "Cendrou", "Ball", 2, rgb(110, 105, 105), rgb(255, 110, 50), { "Ears" }),
	Magmoche = creature("Volcano", "Rare", 3, "Magmoche", "Block", 2.6, rgb(70, 40, 35), rgb(255, 90, 20), { "Spikes", "Glow" }),
	Salamandrix = creature("Volcano", "Epic", 4, "Salamandrix", "Block", 2.4, rgb(220, 50, 40), rgb(255, 200, 50), { "Tail", "Legs", "Glow" }, true),
	Pyrodrake = creature("Volcano", "Legendary", 5, "Pyrodrake", "Block", 3.4, rgb(170, 30, 30), rgb(255, 150, 30), { "Wings", "Horns", "Tail", "Legs" }),
	Volcanosaure = creature("Volcano", "Mythic", 6, "Volcanosaure", "Block", 4, rgb(50, 35, 35), rgb(255, 80, 20), { "Spikes", "Horns", "Legs", "Glow" }),
	CoeurDeLave = creature("Volcano", "Secret", 7, "Cœur-de-Lave", "Ball", 2.6, rgb(255, 60, 20), rgb(255, 240, 120), { "Spikes", "Glow" }),

	-- 🐴 Chevaux sauvages (un par zone) : champ Horse = espèce de monture / d'enclos
	Mousseval = { DisplayName = "Mousseval", Zone = "Forest", Rarity = "Rare", Order = 9, Body = "Block", Size = 2.8, Color = rgb(90, 140, 70), Accent = rgb(190, 230, 120), Features = { "Legs", "Tail", "Ears" }, Horse = "ForestHorse" },
	Givrecrin = { DisplayName = "Givrecrin", Zone = "Mountain", Rarity = "Epic", Order = 9, Body = "Block", Size = 2.9, Color = rgb(235, 245, 255), Accent = rgb(120, 200, 255), Features = { "Legs", "Tail", "Ears", "Glow" }, Horse = "SnowHorse" },
	Sablecrin = { DisplayName = "Sablecrin", Zone = "Desert", Rarity = "Epic", Order = 9, Body = "Block", Size = 2.9, Color = rgb(225, 185, 110), Accent = rgb(255, 240, 170), Features = { "Legs", "Tail", "Ears" }, Horse = "SandHorse" },
	Brasecrin = { DisplayName = "Brasecrin", Zone = "Volcano", Rarity = "Legendary", Order = 9, Body = "Block", Size = 3, Color = rgb(45, 30, 30), Accent = rgb(255, 110, 20), Features = { "Legs", "Tail", "Horns", "Glow" }, Horse = "LavaHorse" },

	-- ✨ Divines (une par zone, bonus de l'Index)
	Sylvanthe = creature("Forest", "Divine", 8, "Sylvanthe", "Block", 3.4, rgb(200, 255, 190), rgb(255, 240, 140), { "Horns", "Legs", "Wings", "Leaf", "Glow" }, true),
	Aurorea = creature("Mountain", "Divine", 8, "Auroréal", "Ball", 3, rgb(220, 240, 255), rgb(180, 140, 255), { "Wings", "Tail", "Glow" }),
	Solarion = creature("Desert", "Divine", 8, "Solarion", "Block", 3.4, rgb(255, 215, 90), rgb(255, 255, 200), { "Ears", "Wings", "Tail", "Legs", "Glow" }),
	Ignaros = creature("Volcano", "Divine", 8, "Ignaros", "Block", 3.8, rgb(30, 20, 20), rgb(255, 200, 60), { "Wings", "Horns", "Tail", "Legs", "Spikes", "Glow" }),
}

--------------------------------------------------------------------------
-- EXPOSITION : socles, vitrine de prestige, Index, classement (phase 6)
--------------------------------------------------------------------------
Config.Display = {
	-- Socles placés avec le mode construction ; 1 créature exposée par socle
	PedestalPrices = { 500, 2000, 6000, 15000, 40000, 100000, 250000, 500000, 1000000, 2000000 },
	MaxPedestalsByLevel = { 4, 6, 8, 10 },
	PedestalFootprint = Vector2.new(7, 7),
	IncomeInterval = 5, -- les Coins des socles sont versés toutes les 5 s
	MaxOfflineSeconds = 8 * 3600, -- revenus hors ligne plafonnés à 8 h
}

Config.Showcase = {
	Slots = 5, -- socles de la vitrine devant l'entrée de chaque parcelle
	Spacing = 7, -- écart entre deux socles (studs)
	DistanceFromEntrance = 10, -- distance entre l'entrée de la parcelle et la vitrine (côté allée)
	RefreshInterval = 3, -- secondes entre deux vérifications du contenu de la vitrine
}

Config.Index = {
	-- Récompense (Coins) quand toutes les créatures d'une zone sont découvertes (hors Divines)
	ZoneRewards = { Forest = 5000, Mountain = 30000, Desert = 150000, Volcano = 600000 },
}

Config.Leaderboard = {
	StoreName = "FarmTycoon_CollectionScore_v1", -- OrderedDataStore (score = prestige total)
	UpdateInterval = 120, -- secondes entre deux mises à jour du classement
	Size = 10, -- nombre de joueurs affichés
	BoardPosition = Vector3.new(60, 0, 0), -- grand panneau près du spawn
}

--------------------------------------------------------------------------
-- PROGRESSION : XP, niveau, rebirth (phase 7)
--------------------------------------------------------------------------
Config.Progression = {
	-- XP pour passer du niveau N au niveau N+1 = XPBase x N ^ XPExponent
	XPBase = 30,
	XPExponent = 1.5,
	LevelUpCoins = 100, -- Coins offerts au passage de niveau = LevelUpCoins x nouveau niveau
	-- XP gagnée par action
	XP = {
		Harvest = 3, -- par récolte (x rang de rareté de la culture)
		AnimalProduct = 2, -- par ressource ramassée
		Craft = 6, -- par produit fabriqué récupéré
		Capture = { Common = 10, Rare = 25, Epic = 60, Legendary = 150, Mythic = 400, Secret = 1000, Divine = 5000 },
	},
	-- Niveau requis pour débloquer
	Unlocks = { Farmer = 5, Mount = 6, Caretaker = 8, Rebirth = 15 },
}

Config.Rebirth = {
	BaseCost = 1000000, -- Coins nécessaires pour le 1er rebirth
	CostGrowth = 3, -- chaque rebirth coûte x3 de plus
	CoinMultiplierPerRebirth = 0.5, -- multiplicateur de Coins = 1 + 0,5 x rebirths (vente + socles)
	-- Ce qui est remis à zéro : Coins, niveau de parcelle, champs (1 champ de 6 cases), plantes,
	-- graines (pack de départ redonné), enclos et animaux, bâtiments, inventaire.
	-- Ce qui est GARDÉ : créatures, Index, zones débloquées, socles (rangés), niveau et XP, aides PNJ.
}

--------------------------------------------------------------------------
-- CONSOMMABLES ET BOOSTS (phase 7)
--   Boost    : "Speed" (vitesse) | "XP" | "Coins" (vente + socles) | "Capture" (zone verte
--              plus large + tirage final) | "Combat" (donjon, phase 8)
--   Power    : bonus (0.2 = +20 %) ; Duration : secondes
--   La variante de l'objet mangé renforce le boost (VariantPowerBonus / VariantDurationBonus par rang).
--------------------------------------------------------------------------
Config.Consumables = {
	Strawberry = { Boost = "Speed", Power = 0.1, Duration = 90 },
	Watermelon = { Boost = "XP", Power = 0.2, Duration = 120 },
	Bread = { Boost = "Speed", Power = 0.15, Duration = 120 },
	Cake = { Boost = "XP", Power = 0.25, Duration = 180 },
	Cream = { Boost = "Coins", Power = 0.1, Duration = 180 },
	Butter = { Boost = "Coins", Power = 0.2, Duration = 240 },
	Cheese = { Boost = "Capture", Power = 0.1, Duration = 300 },
	GoatCheese = { Boost = "Combat", Power = 0.15, Duration = 300 },
	TruffleCheese = { Boost = "Capture", Power = 0.25, Duration = 600 },
	RoyalCake = { Boost = "XP", Power = 0.6, Duration = 600 },
	CelestialBread = { Boost = "Speed", Power = 0.4, Duration = 900 },
	LegendaryCheese = { Boost = "Capture", Power = 0.4, Duration = 900 },
	DivineCream = { Boost = "Coins", Power = 1.0, Duration = 1200 },
}

Config.Boosts = {
	VariantPowerBonus = 0.5, -- +50 % de puissance par rang de variante (Doré = x1,5, Arc-en-ciel = x2...)
	VariantDurationBonus = 0.5,
	MaxDuration = 6 * 3600, -- un boost ne peut pas dépasser 6 h (en cumulant, ex. plusieurs achats de 2 h)
	Types = {
		Speed = { Icon = "🏃", DisplayName = "Vitesse" },
		XP = { Icon = "⭐", DisplayName = "XP" },
		Coins = { Icon = "💰", DisplayName = "Coins" },
		Capture = { Icon = "🪢", DisplayName = "Capture" },
		Combat = { Icon = "⚔️", DisplayName = "Combat (donjon)" },
		Growth = { Icon = "🌱", DisplayName = "Pousse des plantes" }, -- s'applique aux plantes semées pendant le boost
		Production = { Icon = "🏭", DisplayName = "Production (animaux + bâtiments)" },
	},
}

--------------------------------------------------------------------------
-- AIDES AUTOMATIQUES (PNJ) (phase 7)
--   Fermier : récolte les plantes mûres puis replante (graine choisie, sinon la 1re possédée).
--   Soigneur : remplit les mangeoires et ramasse la production des enclos.
--   Levels : Price = prix d'achat / d'amélioration, Interval = secondes entre deux tournées,
--            Actions (fermier) = cases traitées par tournée, Pens (soigneur) = enclos par tournée.
--   Position : où le PNJ se tient sur la parcelle (coordonnées locales, bande d'entrée).
--------------------------------------------------------------------------
Config.Helpers = {
	Farmer = {
		DisplayName = "Fermier", Icon = "🧑‍🌾", Order = 1, Position = { X = -20, Z = 5 },
		Color = Color3.fromRGB(70, 130, 60),
		Levels = {
			{ Price = 5000, Interval = 20, Actions = 3 },
			{ Price = 20000, Interval = 15, Actions = 5 },
			{ Price = 60000, Interval = 10, Actions = 8 },
			{ Price = 150000, Interval = 7, Actions = 12 },
			{ Price = 400000, Interval = 5, Actions = 18 },
		},
	},
	Caretaker = {
		DisplayName = "Soigneur", Icon = "🧺", Order = 2, Position = { X = 20, Z = 5 },
		Color = Color3.fromRGB(200, 110, 60),
		Levels = {
			{ Price = 15000, Interval = 30, Pens = 1 },
			{ Price = 40000, Interval = 25, Pens = 2 },
			{ Price = 100000, Interval = 20, Pens = 4 },
			{ Price = 250000, Interval = 15, Pens = 6 },
			{ Price = 600000, Interval = 10, Pens = 8 },
		},
	},
}

--------------------------------------------------------------------------
-- DONJONS (phase 8)
--------------------------------------------------------------------------
-- Combat : PV et dégâts du joueur selon son niveau, x (1 + boost "Combat")
Config.Combat = {
	PlayerBaseHealth = 100,
	HealthPerLevel = 6,
	BaseDamage = 20,
	DamagePerLevel = 3,
	AttackRange = 9, -- portée de l'attaque (studs, + la taille de l'ennemi)
	AttackCooldown = 0.45, -- secondes entre deux attaques
	DodgeCooldown = 1.5, -- secondes entre deux esquives
	DodgeInvulnerability = 0.5, -- secondes d'invulnérabilité pendant l'esquive
	DodgeSpeed = 70, -- vitesse du bond d'esquive (client)
	RunTimeout = 600, -- un donjon doit être fini en 10 min
	WaveDelay = 3, -- secondes de pause entre deux vagues
	EndDelay = 5, -- secondes avant le retour à la ferme (victoire / défaite)
	ArenaSize = 110, -- côté d'une arène (studs)
	ArenaOrigin = Vector3.new(0, 0, -1800), -- position de la 1re arène (loin de la map)
	ArenaSpacing = 300, -- écart entre deux arènes (une par joueur en donjon)
	ComboWindow = 0.8, -- secondes pour enchaîner le coup suivant du combo (3 coups max, visuel)
}

-- Effets de combat (CLIENT uniquement : purement visuels / sonores)
-- Les sons sont des sons intégrés à Roblox ; remplace-les par des "rbxassetid://..." si tu veux.
Config.CombatEffects = {
	SwingSound = "rbxasset://sounds/swordslash.wav",
	HitSound = "rbxasset://sounds/swordlunge.wav",
	EquipSound = "rbxasset://sounds/unsheath.wav",
	HitParticles = 8, -- particules par coup reçu par un ennemi
	DeathParticles = 18,
	MaxDamageNumbers = 8, -- nombres de dégâts affichés en même temps (au-delà : ignorés)
}

-- Ennemis (créatures originales, modèles en Parts)
--   HP, Damage, Speed (studs/s), AttackRange, WindUp (s d'avertissement avant le coup, en rouge),
--   AttackCooldown, Size, Body ("Ball" | "Block"), Color, Accent, XP (gagnée en le battant)
--   Boss : SlamDamage / SlamRadius / SlamWindup / SlamInterval = attaque de zone (cercle rouge au sol)
Config.Enemies = {
	Ronceux = { DisplayName = "Ronceux", HP = 70, Damage = 8, Speed = 9, AttackRange = 5, WindUp = 0.7, AttackCooldown = 1.4, Size = 2.6, Body = "Ball", Color = Color3.fromRGB(90, 130, 50), Accent = Color3.fromRGB(120, 70, 40), XP = 8 },
	Champitox = { DisplayName = "Champitox", HP = 45, Damage = 11, Speed = 12, AttackRange = 4.5, WindUp = 0.6, AttackCooldown = 1.2, Size = 2.1, Body = "Ball", Color = Color3.fromRGB(170, 60, 200), Accent = Color3.fromRGB(240, 240, 240), XP = 8 },
	Givrelin = { DisplayName = "Givrelin", HP = 120, Damage = 15, Speed = 11, AttackRange = 5, WindUp = 0.65, AttackCooldown = 1.3, Size = 2.4, Body = "Ball", Color = Color3.fromRGB(170, 220, 255), Accent = Color3.fromRGB(80, 140, 230), XP = 14 },
	Cognebloc = { DisplayName = "Cognebloc", HP = 260, Damage = 26, Speed = 7, AttackRange = 6, WindUp = 0.9, AttackCooldown = 1.8, Size = 4, Body = "Block", Color = Color3.fromRGB(200, 230, 255), Accent = Color3.fromRGB(110, 150, 200), XP = 22 },
	Scarabix = { DisplayName = "Scarabix", HP = 200, Damage = 22, Speed = 13, AttackRange = 5, WindUp = 0.6, AttackCooldown = 1.2, Size = 2.6, Body = "Block", Color = Color3.fromRGB(60, 130, 140), Accent = Color3.fromRGB(230, 190, 80), XP = 24 },
	Ventsableux = { DisplayName = "Ventsableux", HP = 240, Damage = 28, Speed = 10, AttackRange = 6, WindUp = 0.75, AttackCooldown = 1.5, Size = 3, Body = "Ball", Color = Color3.fromRGB(230, 200, 140), Accent = Color3.fromRGB(180, 130, 70), XP = 28 },
	Braisard = { DisplayName = "Braisard", HP = 380, Damage = 36, Speed = 13, AttackRange = 5, WindUp = 0.6, AttackCooldown = 1.2, Size = 2.8, Body = "Block", Color = Color3.fromRGB(220, 60, 30), Accent = Color3.fromRGB(255, 200, 60), XP = 40 },
	Magmolosse = { DisplayName = "Magmolosse", HP = 700, Damage = 50, Speed = 7, AttackRange = 7, WindUp = 1, AttackCooldown = 1.8, Size = 4.6, Body = "Block", Color = Color3.fromRGB(50, 30, 30), Accent = Color3.fromRGB(255, 110, 20), XP = 55 },

	-- Boss
	VieuxChene = { DisplayName = "Vieux Chêne Grognon", Boss = true, HP = 1200, Damage = 20, Speed = 6, AttackRange = 8, WindUp = 0.9, AttackCooldown = 1.8, Size = 8, Body = "Block", Color = Color3.fromRGB(110, 80, 50), Accent = Color3.fromRGB(80, 170, 60), XP = 150, SlamDamage = 35, SlamRadius = 14, SlamWindup = 1.3, SlamInterval = 7 },
	ReineGivre = { DisplayName = "Reine du Givre", Boss = true, HP = 3200, Damage = 34, Speed = 7, AttackRange = 8, WindUp = 0.85, AttackCooldown = 1.6, Size = 8, Body = "Ball", Color = Color3.fromRGB(200, 235, 255), Accent = Color3.fromRGB(120, 90, 255), XP = 350, SlamDamage = 55, SlamRadius = 16, SlamWindup = 1.25, SlamInterval = 6.5 },
	GardienDunes = { DisplayName = "Gardien des Dunes", Boss = true, HP = 6500, Damage = 48, Speed = 8, AttackRange = 9, WindUp = 0.8, AttackCooldown = 1.5, Size = 9, Body = "Block", Color = Color3.fromRGB(220, 180, 90), Accent = Color3.fromRGB(60, 90, 200), XP = 700, SlamDamage = 80, SlamRadius = 17, SlamWindup = 1.2, SlamInterval = 6 },
	TitanLave = { DisplayName = "Titan de Lave", Boss = true, HP = 13000, Damage = 70, Speed = 8, AttackRange = 10, WindUp = 0.8, AttackCooldown = 1.4, Size = 10, Body = "Block", Color = Color3.fromRGB(40, 25, 25), Accent = Color3.fromRGB(255, 120, 20), XP = 1400, SlamDamage = 110, SlamRadius = 18, SlamWindup = 1.15, SlamInterval = 5.5 },
}

-- Donjons : vagues d'ennemis puis un boss, récompenses à la victoire
--   RequiredLevel : niveau du joueur requis
--   Waves : liste de vagues (ids de Config.Enemies), puis Boss
--   Rewards.Coins = { min, max } ; Rewards.XP ; FirstClearBonus = Coins en plus à la 1re victoire
--   Rewards.Loot : tirages indépendants { Kind = "Seeds" | "Item", Id, Variant?, Amount = { min, max }, Chance }
Config.Dungeons = {
	RootCave = {
		DisplayName = "Grotte des Racines", Icon = "🌳", Order = 1, RequiredLevel = 8,
		FloorColor = Color3.fromRGB(80, 60, 40), WallColor = Color3.fromRGB(60, 90, 50),
		Waves = { { "Ronceux", "Ronceux", "Champitox" }, { "Ronceux", "Champitox", "Champitox", "Ronceux" } },
		Boss = "VieuxChene",
		Rewards = {
			Coins = { 3000, 6000 }, XP = 200, FirstClearBonus = 10000,
			Loot = {
				{ Kind = "Seeds", Id = "Strawberry", Amount = { 2, 4 }, Chance = 0.6 },
				{ Kind = "Seeds", Id = "Watermelon", Amount = { 1, 2 }, Chance = 0.25 },
				{ Kind = "Item", Id = "ForestEgg", Amount = { 1, 1 }, Chance = 0.35 },
				{ Kind = "Item", Id = "Egg", Variant = "Legendary", Amount = { 1, 2 }, Chance = 0.1 },
				{ Kind = "Item", Id = "Wheat", Variant = "Mythic", Amount = { 2, 4 }, Chance = 0.05 },
			},
		},
	},
	FrostMine = {
		DisplayName = "Mine de Givre", Icon = "❄️", Order = 2, RequiredLevel = 14,
		FloorColor = Color3.fromRGB(150, 170, 190), WallColor = Color3.fromRGB(220, 235, 250),
		Waves = { { "Givrelin", "Givrelin", "Givrelin" }, { "Givrelin", "Cognebloc", "Givrelin" }, { "Cognebloc", "Cognebloc", "Givrelin", "Givrelin" } },
		Boss = "ReineGivre",
		Rewards = {
			Coins = { 15000, 30000 }, XP = 500, FirstClearBonus = 50000,
			Loot = {
				{ Kind = "Seeds", Id = "Blueberry", Amount = { 3, 5 }, Chance = 0.6 },
				{ Kind = "Seeds", Id = "Dragonfruit", Amount = { 1, 2 }, Chance = 0.3 },
				{ Kind = "Item", Id = "MountainEgg", Amount = { 1, 1 }, Chance = 0.35 },
				{ Kind = "Item", Id = "Wool", Variant = "Mythic", Amount = { 2, 3 }, Chance = 0.08 },
				{ Kind = "Item", Id = "Milk", Variant = "Legendary", Amount = { 2, 3 }, Chance = 0.12 },
			},
		},
	},
	SandTemple = {
		DisplayName = "Temple Ensablé", Icon = "🏛️", Order = 3, RequiredLevel = 20,
		FloorColor = Color3.fromRGB(220, 190, 130), WallColor = Color3.fromRGB(180, 140, 80),
		Waves = { { "Scarabix", "Scarabix", "Ventsableux" }, { "Ventsableux", "Scarabix", "Ventsableux", "Scarabix" }, { "Ventsableux", "Ventsableux", "Scarabix", "Scarabix", "Scarabix" } },
		Boss = "GardienDunes",
		Rewards = {
			Coins = { 60000, 120000 }, XP = 1200, FirstClearBonus = 200000,
			Loot = {
				{ Kind = "Seeds", Id = "StarFlower", Amount = { 1, 2 }, Chance = 0.35 },
				{ Kind = "Item", Id = "DesertEgg", Amount = { 1, 1 }, Chance = 0.35 },
				{ Kind = "Item", Id = "Milk", Variant = "Mythic", Amount = { 2, 3 }, Chance = 0.1 },
				{ Kind = "Item", Id = "Truffle", Variant = "Legendary", Amount = { 1, 2 }, Chance = 0.15 },
			},
		},
	},
	LavaForge = {
		DisplayName = "Forge Volcanique", Icon = "🌋", Order = 4, RequiredLevel = 28,
		FloorColor = Color3.fromRGB(45, 35, 35), WallColor = Color3.fromRGB(90, 30, 20),
		Waves = { { "Braisard", "Braisard", "Braisard" }, { "Braisard", "Magmolosse", "Braisard" }, { "Magmolosse", "Braisard", "Magmolosse", "Braisard" } },
		Boss = "TitanLave",
		Rewards = {
			Coins = { 250000, 500000 }, XP = 3000, FirstClearBonus = 800000,
			Loot = {
				{ Kind = "Seeds", Id = "MoonPumpkin", Amount = { 1, 2 }, Chance = 0.4 },
				{ Kind = "Item", Id = "VolcanoEgg", Amount = { 1, 1 }, Chance = 0.35 },
				{ Kind = "Item", Id = "Truffle", Variant = "Mythic", Amount = { 1, 2 }, Chance = 0.1 },
				{ Kind = "Item", Id = "Milk", Variant = "Mythic", Amount = { 3, 5 }, Chance = 0.12 },
			},
		},
	},
}

-- ŒUFS DE CRÉATURES (récompenses de donjon) : on les fait couver depuis le sac (🐣),
-- ils éclosent après HatchTime secondes et donnent une créature de leur zone.
Config.Eggs = {
	ForestEgg = { DisplayName = "Œuf de la Forêt", Icon = "🥚", Order = 1, SellPrice = 800, Zone = "Forest", HatchTime = 60 },
	MountainEgg = { DisplayName = "Œuf de la Montagne", Icon = "🥚", Order = 2, SellPrice = 3000, Zone = "Mountain", HatchTime = 120 },
	DesertEgg = { DisplayName = "Œuf du Désert", Icon = "🥚", Order = 3, SellPrice = 10000, Zone = "Desert", HatchTime = 240 },
	VolcanoEgg = { DisplayName = "Œuf du Volcan", Icon = "🥚", Order = 4, SellPrice = 35000, Zone = "Volcano", HatchTime = 480 },
}

Config.EggSettings = {
	Incubators = 3, -- œufs qui peuvent couver en même temps
	-- Un œuf donne plus souvent des raretés hautes qu'une capture : poids d'apparition multipliés
	RarityWeightMultiplier = { Common = 1, Rare = 1.5, Epic = 3, Legendary = 5, Mythic = 8, Secret = 10, Divine = 10 },
}

--------------------------------------------------------------------------
-- MODE CONSTRUCTION (placer / déplacer / ranger champs, enclos, bâtiments)
--------------------------------------------------------------------------
Config.Build = {
	Grid = 1, -- les positions sont arrondies à ce pas (studs)
	EntranceDepth = 10, -- bande d'entrée interdite (spawn + boutons), en studs de profondeur
	EdgeMargin = 1, -- marge avec le bord de la parcelle
	ActionCooldown = 0.3,
	-- Marge ajoutée autour de l'emprise d'un bâtiment (largeur, profondeur) : porte + passage
	BuildingMargin = Vector2.new(2, 4),
}

--------------------------------------------------------------------------
-- MONÉTISATION (phase 9)
--   Remplace chaque Id = 0 par le vrai ID créé sur le Creator Dashboard (voir README).
--   Un objet dont l'Id vaut 0 est affiché "Bientôt disponible" et ne peut pas être acheté.
--   Price = prix en Robux AFFICHÉ (le vrai prix est celui réglé sur Roblox).
--------------------------------------------------------------------------
Config.Monetization = {
	Enabled = true,
	-- Studio uniquement : donne tous les Game Passes pour tester leurs effets sans les acheter
	GrantAllPassesInStudio = false,

	-- GAME PASSES : achetés une fois, effet permanent
	GamePasses = {
		DoubleCoins = { Id = 0, Price = 199, Icon = "💰", Name = "x2 Coins", Description = "Tous tes gains de Coins (vente, socles) x2, pour toujours." },
		PremiumHelpers = { Id = 0, Price = 249, Icon = "🧑‍🌾", Name = "Aides premium", Description = "Le fermier et le soigneur font leurs tournées 2x plus vite." },
		BigBackpack = { Id = 0, Price = 99, Icon = "🎒", Name = "Grand sac", Description = "+300 places dans ton sac.", Bonus = 300 },
		ExtraIncubators = { Id = 0, Price = 149, Icon = "🐣", Name = "Couveuses en plus", Description = "+2 œufs qui couvent en même temps.", Bonus = 2 },
		BigCollection = { Id = 0, Price = 149, Icon = "📖", Name = "Grande collection", Description = "+100 places pour tes créatures.", Bonus = 100 },
	},

	-- DEVELOPER PRODUCTS : achetables plusieurs fois
	--   Kind : "Coins" (Amount + PerLevel x niveau) | "Boost" (Boost, Power, Duration) |
	--          "PlotExpansion" | "HatchNow" (tous les œufs éclosent) | "WheelSpins" (Amount)
	Products = {
		PlotExpansion = { Id = 0, Price = 99, Icon = "🗺️", Name = "Agrandissement", Description = "Agrandis ta parcelle d'un niveau tout de suite.", Kind = "PlotExpansion" },
		CoinsSmall = { Id = 0, Price = 25, Icon = "💰", Name = "Petit sac de Coins", Description = "Des Coins (plus si ton niveau est haut).", Kind = "Coins", Amount = 25000, PerLevel = 2500 },
		CoinsMedium = { Id = 0, Price = 99, Icon = "💰", Name = "Coffre de Coins", Description = "Beaucoup de Coins.", Kind = "Coins", Amount = 150000, PerLevel = 15000 },
		CoinsLarge = { Id = 0, Price = 299, Icon = "💰", Name = "Trésor de Coins", Description = "Énormément de Coins.", Kind = "Coins", Amount = 600000, PerLevel = 60000 },
		GrowthBoost = { Id = 0, Price = 39, Icon = "🌱", Name = "Pousse x2 (30 min)", Description = "Les plantes semées poussent 2x plus vite.", Kind = "Boost", Boost = "Growth", Power = 1, Duration = 1800 },
		ProductionBoost = { Id = 0, Price = 49, Icon = "🏭", Name = "Production x2 (30 min)", Description = "Animaux et bâtiments produisent 2x plus vite.", Kind = "Boost", Boost = "Production", Power = 1, Duration = 1800 },
		CoinsBoost = { Id = 0, Price = 49, Icon = "💰", Name = "Coins x2 (30 min)", Description = "Gains de Coins x2 pendant 30 min.", Kind = "Boost", Boost = "Coins", Power = 1, Duration = 1800 },
		XPBoost = { Id = 0, Price = 29, Icon = "⭐", Name = "XP x2 (30 min)", Description = "XP x2 pendant 30 min.", Kind = "Boost", Boost = "XP", Power = 1, Duration = 1800 },
		SpeedBoost = { Id = 0, Price = 15, Icon = "🏃", Name = "Vitesse +30 % (30 min)", Description = "Tu cours plus vite.", Kind = "Boost", Boost = "Speed", Power = 0.3, Duration = 1800 },
		CaptureBoost = { Id = 0, Price = 39, Icon = "🪢", Name = "Capture +25 % (30 min)", Description = "Zone verte plus large et meilleure chance finale.", Kind = "Boost", Boost = "Capture", Power = 0.25, Duration = 1800 },
		CombatBoost = { Id = 0, Price = 39, Icon = "⚔️", Name = "Force +50 % (30 min)", Description = "Plus de PV et de dégâts au donjon.", Kind = "Boost", Boost = "Combat", Power = 0.5, Duration = 1800 },
		HatchNow = { Id = 0, Price = 25, Icon = "🐣", Name = "Éclosion immédiate", Description = "Tous tes œufs en couveuse éclosent tout de suite.", Kind = "HatchNow" },
		-- Boosts longs (2 h) : vendus aussi sur les boutons au sol autour de la base
		XPBoost2h = { Id = 0, Price = 79, Icon = "⚡", Name = "XP x2 (2 h)", Description = "XP x2 pendant 2 heures.", Kind = "Boost", Boost = "XP", Power = 1, Duration = 7200 },
		CoinsBoost2h = { Id = 0, Price = 129, Icon = "💰", Name = "Coins x2 (2 h)", Description = "Gains de Coins x2 pendant 2 heures.", Kind = "Boost", Boost = "Coins", Power = 1, Duration = 7200 },
		ProductionBoost2h = { Id = 0, Price = 129, Icon = "🏭", Name = "Production x2 (2 h)", Description = "Animaux et bâtiments 2x plus rapides pendant 2 heures.", Kind = "Boost", Boost = "Production", Power = 1, Duration = 7200 },
		GrowthBoost2h = { Id = 0, Price = 99, Icon = "🌱", Name = "Pousse x2 (2 h)", Description = "Plantes 2x plus rapides pendant 2 heures.", Kind = "Boost", Boost = "Growth", Power = 1, Duration = 7200 },
		WheelSpin = { Id = 0, Price = 19, Icon = "🎡", Name = "1 tour de roue", Description = "Un tour de roue en plus.", Kind = "WheelSpins", Amount = 1 },
		WheelSpins5 = { Id = 0, Price = 79, Icon = "🎡", Name = "5 tours de roue", Description = "Cinq tours de roue en plus.", Kind = "WheelSpins", Amount = 5 },
	},
	MaxReceiptHistory = 300, -- reçus mémorisés par joueur (anti double-crédit)
}

--------------------------------------------------------------------------
-- ROUE QUOTIDIENNE (phase 9)
--   1 tour gratuit toutes les Cooldown secondes (délai sauvegardé) ; tours en plus
--   achetables (Developer Products WheelSpin / WheelSpins5). Tout est tiré PAR LE SERVEUR.
--   Rewards : Weight = poids (les chances affichées = Weight / total)
--     Kind "Coins" (Amount + PerLevel x niveau) | "XP" (Amount + PerLevel x niveau) |
--     "Seeds" (Id, Amount) | "Boost" (Boost, Power, Duration) | "Rations" (Amount par enclos) |
--     "Item" (Id, Variant?, Amount) | "Creature" (Zone : créature de cette zone, raretés favorisées) |
--     "Animal" (Species, Variant) : l'animal exclusif, annoncé sur tous les serveurs
--------------------------------------------------------------------------
Config.Wheel = {
	Cooldown = 24 * 3600,
	SpinDuration = 5, -- secondes d'animation (suspense) côté client
	Rewards = {
		{ Id = "CoinsS", Kind = "Coins", Amount = 5000, PerLevel = 500, Weight = 25, Icon = "💰", Color = Color3.fromRGB(240, 190, 60) },
		{ Id = "Strawberry", Kind = "Seeds", Item = "Strawberry", Amount = 5, Weight = 14, Icon = "🍓", Color = Color3.fromRGB(240, 70, 90) },
		{ Id = "CoinsL", Kind = "Coins", Amount = 20000, PerLevel = 2000, Weight = 10, Icon = "💰", Color = Color3.fromRGB(255, 160, 40) },
		{ Id = "BoostCoins", Kind = "Boost", Boost = "Coins", Power = 0.5, Duration = 900, Weight = 8, Icon = "💰", Color = Color3.fromRGB(250, 220, 90) },
		{ Id = "BoostXP", Kind = "Boost", Boost = "XP", Power = 0.5, Duration = 900, Weight = 8, Icon = "⭐", Color = Color3.fromRGB(120, 200, 255) },
		{ Id = "XP", Kind = "XP", Amount = 300, PerLevel = 60, Weight = 8, Icon = "⭐", Color = Color3.fromRGB(90, 160, 255) },
		{ Id = "Dragonfruit", Kind = "Seeds", Item = "Dragonfruit", Amount = 3, Weight = 6, Icon = "🐉", Color = Color3.fromRGB(255, 80, 170) },
		{ Id = "BoostGrowth", Kind = "Boost", Boost = "Growth", Power = 1, Duration = 900, Weight = 6, Icon = "🌱", Color = Color3.fromRGB(90, 200, 90) },
		{ Id = "Rations", Kind = "Rations", Amount = 150, Weight = 5, Icon = "🍽️", Color = Color3.fromRGB(200, 160, 90) },
		{ Id = "BoostCapture", Kind = "Boost", Boost = "Capture", Power = 0.25, Duration = 900, Weight = 4, Icon = "🪢", Color = Color3.fromRGB(190, 140, 90) },
		{ Id = "StarFlower", Kind = "Seeds", Item = "StarFlower", Amount = 1, Weight = 2, Icon = "🌟", Color = Color3.fromRGB(255, 230, 80) },
		{ Id = "ForestEgg", Kind = "Item", Item = "ForestEgg", Amount = 1, Weight = 2.5, Icon = "🥚", Color = Color3.fromRGB(140, 200, 110) },
		{ Id = "MountainEgg", Kind = "Item", Item = "MountainEgg", Amount = 1, Weight = 1, Icon = "🥚", Color = Color3.fromRGB(180, 220, 255) },
		{ Id = "Creature", Kind = "Creature", Zone = "Desert", Weight = 0.4, Icon = "📖", Color = Color3.fromRGB(170, 80, 240) },
		{ Id = "Astrelune", Kind = "Animal", Species = "Astrelune", Variant = "Normal", Weight = 0.1, Icon = "🦄", Color = Color3.fromRGB(255, 120, 220), Jackpot = true },
	},
}

--------------------------------------------------------------------------
-- PERSONNALISATION COSMÉTIQUE (phase 9) : UNIQUEMENT visuel, aucun avantage de jeu.
--   Category : PenSkin | PlotFloor | BuildingPalette | FieldStyle | SignStyle | ShowcaseFX |
--              Trail | Title | AnimalHat | MountSkin
--   Unlock : { Kind = "Free" } | { Kind = "Coins", Price } | { Kind = "Level", Level } |
--            { Kind = "Index", Zone } (zone de l'Index complétée) |
--            { Kind = "Robux", Price = prix affiché, ProductId = ID du Developer Product (0 = à créer) }
--   Default = true : équipé par défaut (gratuit)
--------------------------------------------------------------------------
local rgb2 = Color3.fromRGB
Config.CosmeticCategories = {
	{ Id = "PenSkin", Icon = "🐾", DisplayName = "Clôtures d'enclos" },
	{ Id = "PlotFloor", Icon = "🟩", DisplayName = "Sol de parcelle" },
	{ Id = "BuildingPalette", Icon = "🏠", DisplayName = "Couleurs des bâtiments" },
	{ Id = "FieldStyle", Icon = "🌱", DisplayName = "Bordures des champs" },
	{ Id = "SignStyle", Icon = "🪧", DisplayName = "Panneau de parcelle" },
	{ Id = "ShowcaseFX", Icon = "✨", DisplayName = "Effets de vitrine" },
	{ Id = "Trail", Icon = "👣", DisplayName = "Traces de pas" },
	{ Id = "Title", Icon = "🏷️", DisplayName = "Titre" },
	{ Id = "AnimalHat", Icon = "🎩", DisplayName = "Chapeaux des animaux" },
	{ Id = "MountSkin", Icon = "🐴", DisplayName = "Selle de monture" },
	{ Id = "PlotFence", Icon = "🧱", DisplayName = "Clôture de parcelle" },
}

Config.Cosmetics = {
	-- Clôtures d'enclos
	PenWood = { Category = "PenSkin", Name = "Bois", Default = true, Unlock = { Kind = "Free" }, Color = rgb2(150, 105, 60), Material = Enum.Material.Wood },
	PenStone = { Category = "PenSkin", Name = "Pierre", Unlock = { Kind = "Coins", Price = 25000 }, Color = rgb2(150, 150, 155), Material = Enum.Material.Cobblestone },
	PenIce = { Category = "PenSkin", Name = "Glace", Unlock = { Kind = "Index", Zone = "Mountain" }, Color = rgb2(170, 220, 255), Material = Enum.Material.Ice },
	PenCandy = { Category = "PenSkin", Name = "Bonbon", Unlock = { Kind = "Robux", Price = 49, ProductId = 0 }, Color = rgb2(255, 130, 200), Material = Enum.Material.SmoothPlastic },
	PenNeon = { Category = "PenSkin", Name = "Néon", Unlock = { Kind = "Robux", Price = 79, ProductId = 0 }, Color = rgb2(80, 230, 255), Material = Enum.Material.Neon },
	PenGold = { Category = "PenSkin", Name = "Or", Unlock = { Kind = "Robux", Price = 99, ProductId = 0 }, Color = rgb2(255, 200, 50), Material = Enum.Material.Foil },

	-- Sol de parcelle
	FloorGrass = { Category = "PlotFloor", Name = "Gazon clair", Default = true, Unlock = { Kind = "Free" }, Color = rgb2(150, 210, 95), Material = Enum.Material.Grass },
	FloorMeadow = { Category = "PlotFloor", Name = "Prairie fleurie", Unlock = { Kind = "Level", Level = 10 }, Color = rgb2(130, 190, 90), Material = Enum.Material.SmoothPlastic, Pattern = "Flowers" },
	FloorSand = { Category = "PlotFloor", Name = "Sable doré", Unlock = { Kind = "Coins", Price = 50000 }, Color = rgb2(230, 205, 140), Material = Enum.Material.Sand },
	FloorSnow = { Category = "PlotFloor", Name = "Neige", Unlock = { Kind = "Index", Zone = "Mountain" }, Color = rgb2(240, 245, 255), Material = Enum.Material.Snow },
	FloorLava = { Category = "PlotFloor", Name = "Roche volcanique", Unlock = { Kind = "Robux", Price = 99, ProductId = 0 }, Color = rgb2(50, 35, 35), Material = Enum.Material.Basalt },
	FloorRoyal = { Category = "PlotFloor", Name = "Velours royal", Unlock = { Kind = "Robux", Price = 149, ProductId = 0 }, Color = rgb2(110, 50, 160), Material = Enum.Material.Fabric },

	-- Couleurs des bâtiments (Wall = murs, Roof = toit)
	BuildClassic = { Category = "BuildingPalette", Name = "Classique", Default = true, Unlock = { Kind = "Free" } },
	BuildPastel = { Category = "BuildingPalette", Name = "Pastel", Unlock = { Kind = "Coins", Price = 40000 }, Wall = rgb2(255, 230, 240), Roof = rgb2(170, 220, 255) },
	BuildNight = { Category = "BuildingPalette", Name = "Nuit étoilée", Unlock = { Kind = "Level", Level = 20 }, Wall = rgb2(50, 55, 90), Roof = rgb2(25, 25, 50) },
	BuildCandy = { Category = "BuildingPalette", Name = "Bonbon", Unlock = { Kind = "Robux", Price = 49, ProductId = 0 }, Wall = rgb2(255, 170, 210), Roof = rgb2(150, 255, 200) },
	BuildGold = { Category = "BuildingPalette", Name = "Palais doré", Unlock = { Kind = "Robux", Price = 99, ProductId = 0 }, Wall = rgb2(255, 240, 200), Roof = rgb2(255, 190, 40) },

	-- Bordures des champs
	FieldClassic = { Category = "FieldStyle", Name = "Terre", Default = true, Unlock = { Kind = "Free" }, Color = rgb2(85, 60, 35), Material = Enum.Material.Ground },
	FieldStone = { Category = "FieldStyle", Name = "Pavés", Unlock = { Kind = "Coins", Price = 15000 }, Color = rgb2(140, 140, 145), Material = Enum.Material.Cobblestone },
	FieldFlowers = { Category = "FieldStyle", Name = "Fleurs", Unlock = { Kind = "Level", Level = 12 }, Color = rgb2(240, 140, 200), Material = Enum.Material.LeafyGrass },
	FieldGold = { Category = "FieldStyle", Name = "Or", Unlock = { Kind = "Robux", Price = 49, ProductId = 0 }, Color = rgb2(255, 200, 60), Material = Enum.Material.Foil },

	-- Panneau de parcelle
	SignWood = { Category = "SignStyle", Name = "Bois", Default = true, Unlock = { Kind = "Free" }, Color = rgb2(150, 105, 60), Material = Enum.Material.WoodPlanks, TextColor = rgb2(255, 255, 255) },
	SignRoyal = { Category = "SignStyle", Name = "Royal", Unlock = { Kind = "Level", Level = 15 }, Color = rgb2(110, 50, 160), Material = Enum.Material.Fabric, TextColor = rgb2(255, 220, 90) },
	SignGold = { Category = "SignStyle", Name = "Or", Unlock = { Kind = "Robux", Price = 25, ProductId = 0 }, Color = rgb2(255, 200, 50), Material = Enum.Material.Foil, TextColor = rgb2(255, 250, 220) },
	SignNeon = { Category = "SignStyle", Name = "Néon", Unlock = { Kind = "Robux", Price = 49, ProductId = 0 }, Color = rgb2(40, 20, 60), Material = Enum.Material.Neon, TextColor = rgb2(120, 255, 255) },

	-- Effets autour de la vitrine
	FXNone = { Category = "ShowcaseFX", Name = "Aucun", Default = true, Unlock = { Kind = "Free" } },
	FXSparkles = { Category = "ShowcaseFX", Name = "Étincelles", Unlock = { Kind = "Coins", Price = 100000 }, ParticleColor = rgb2(255, 240, 180), Rate = 6 },
	FXFireflies = { Category = "ShowcaseFX", Name = "Lucioles", Unlock = { Kind = "Index", Zone = "Forest" }, ParticleColor = rgb2(200, 255, 120), Rate = 4 },
	FXRainbow = { Category = "ShowcaseFX", Name = "Arc-en-ciel", Unlock = { Kind = "Robux", Price = 99, ProductId = 0 }, ParticleColor = rgb2(255, 120, 220), Rate = 10, Rainbow = true },
	FXStars = { Category = "ShowcaseFX", Name = "Pluie d'étoiles", Unlock = { Kind = "Robux", Price = 149, ProductId = 0 }, ParticleColor = rgb2(255, 230, 120), Rate = 14 },

	-- Traces de pas (traînée derrière le joueur)
	TrailNone = { Category = "Trail", Name = "Aucune", Default = true, Unlock = { Kind = "Free" } },
	TrailLeaves = { Category = "Trail", Name = "Feuilles", Unlock = { Kind = "Level", Level = 8 }, Color1 = rgb2(120, 200, 80), Color2 = rgb2(60, 140, 50) },
	TrailFire = { Category = "Trail", Name = "Braises", Unlock = { Kind = "Index", Zone = "Volcano" }, Color1 = rgb2(255, 200, 60), Color2 = rgb2(255, 60, 20), Glow = true },
	TrailSparkle = { Category = "Trail", Name = "Paillettes", Unlock = { Kind = "Robux", Price = 49, ProductId = 0 }, Color1 = rgb2(255, 255, 255), Color2 = rgb2(255, 220, 120), Glow = true },
	TrailRainbow = { Category = "Trail", Name = "Arc-en-ciel", Unlock = { Kind = "Robux", Price = 99, ProductId = 0 }, Color1 = rgb2(255, 80, 80), Color2 = rgb2(80, 120, 255), Glow = true, Rainbow = true },

	-- Titres au-dessus du joueur
	TitleNone = { Category = "Title", Name = "Aucun", Default = true, Unlock = { Kind = "Free" } },
	TitleFarmer = { Category = "Title", Name = "Fermier", Unlock = { Kind = "Free" }, Text = "🌾 Fermier", Color = rgb2(180, 230, 120) },
	TitleBreeder = { Category = "Title", Name = "Éleveur", Unlock = { Kind = "Level", Level = 10 }, Text = "🐄 Éleveur", Color = rgb2(255, 220, 160) },
	TitleHunter = { Category = "Title", Name = "Chasseur de créatures", Unlock = { Kind = "Index", Zone = "Forest" }, Text = "🪢 Chasseur de créatures", Color = rgb2(200, 160, 255) },
	TitleChampion = { Category = "Title", Name = "Champion du donjon", Unlock = { Kind = "Level", Level = 25 }, Text = "⚔️ Champion du donjon", Color = rgb2(255, 120, 120) },
	TitleLegend = { Category = "Title", Name = "Légende", Unlock = { Kind = "Robux", Price = 75, ProductId = 0 }, Text = "🌟 Légende", Color = rgb2(255, 210, 60) },
	TitleVIP = { Category = "Title", Name = "VIP", Unlock = { Kind = "Robux", Price = 150, ProductId = 0 }, Text = "💎 VIP", Color = rgb2(120, 255, 255) },

	-- Chapeaux de tous les animaux de ferme
	HatNone = { Category = "AnimalHat", Name = "Aucun", Default = true, Unlock = { Kind = "Free" } },
	HatStraw = { Category = "AnimalHat", Name = "Chapeau de paille", Unlock = { Kind = "Coins", Price = 30000 }, Shape = "Hat", Color = rgb2(230, 200, 110) },
	HatFlowers = { Category = "AnimalHat", Name = "Couronne de fleurs", Unlock = { Kind = "Level", Level = 12 }, Shape = "Ring", Color = rgb2(255, 140, 200) },
	HatParty = { Category = "AnimalHat", Name = "Chapeau de fête", Unlock = { Kind = "Robux", Price = 25, ProductId = 0 }, Shape = "Cone", Color = rgb2(120, 200, 255) },
	HatCrown = { Category = "AnimalHat", Name = "Couronne", Unlock = { Kind = "Robux", Price = 79, ProductId = 0 }, Shape = "Crown", Color = rgb2(255, 200, 50) },

	-- Selle des montures
	SaddleClassic = { Category = "MountSkin", Name = "Classique", Default = true, Unlock = { Kind = "Free" }, Saddle = rgb2(120, 50, 40) },
	SaddleRoyal = { Category = "MountSkin", Name = "Selle royale", Unlock = { Kind = "Coins", Price = 80000 }, Saddle = rgb2(110, 40, 160), Harness = rgb2(255, 200, 60) },
	SaddleGold = { Category = "MountSkin", Name = "Harnais doré", Unlock = { Kind = "Robux", Price = 99, ProductId = 0 }, Saddle = rgb2(255, 200, 50), Harness = rgb2(255, 240, 150), Neon = true },
	SaddleStars = { Category = "MountSkin", Name = "Selle étoilée", Unlock = { Kind = "Robux", Price = 149, ProductId = 0 }, Saddle = rgb2(30, 30, 70), Harness = rgb2(150, 220, 255), Neon = true, Sparkles = true, Pattern = "Stars" },

	-- Clôture autour de la parcelle entière (Style : "Rail" barrières | "Picket" piquets |
	--   "Wall" muret | "Panel" panneaux décorés d'un motif). Color = barres / panneaux, Post = poteaux, Cap = boules
	FenceWood = { Category = "PlotFence", Name = "Barrière en bois", Default = true, Unlock = { Kind = "Free" }, Style = "Rail", Color = rgb2(165, 115, 70), Post = rgb2(110, 75, 45), Cap = rgb2(110, 75, 45), Material = Enum.Material.WoodPlanks },
	FencePicket = { Category = "PlotFence", Name = "Piquets blancs", Unlock = { Kind = "Coins", Price = 30000 }, Style = "Picket", Color = rgb2(250, 250, 245), Post = rgb2(240, 240, 235), Cap = rgb2(240, 240, 235), Material = Enum.Material.WoodPlanks },
	FenceStone = { Category = "PlotFence", Name = "Muret de pierre", Unlock = { Kind = "Level", Level = 12 }, Style = "Wall", Color = rgb2(150, 150, 155), Post = rgb2(120, 120, 125), Cap = rgb2(180, 180, 185), Material = Enum.Material.Cobblestone },
	FenceStars = { Category = "PlotFence", Name = "Nuit étoilée", Unlock = { Kind = "Level", Level = 25 }, Style = "Panel", Color = rgb2(40, 45, 95), Post = rgb2(25, 25, 60), Cap = rgb2(255, 220, 90), Material = Enum.Material.SmoothPlastic, Pattern = "Stars" },
	FenceMascot = { Category = "PlotFence", Name = "Biscotte", Unlock = { Kind = "Index", Zone = "Forest" }, Style = "Panel", Color = rgb2(255, 240, 215), Post = rgb2(70, 160, 90), Cap = rgb2(240, 205, 110), Material = Enum.Material.WoodPlanks, Pattern = "Mascot" },
	FenceCandy = { Category = "PlotFence", Name = "Sucre d'orge", Unlock = { Kind = "Robux", Price = 49, ProductId = 0 }, Style = "Rail", Color = rgb2(255, 140, 190), Post = rgb2(255, 255, 255), Cap = rgb2(230, 50, 80), Material = Enum.Material.SmoothPlastic },
	FenceHearts = { Category = "PlotFence", Name = "Cœurs", Unlock = { Kind = "Robux", Price = 49, ProductId = 0 }, Style = "Panel", Color = rgb2(255, 215, 230), Post = rgb2(230, 90, 140), Cap = rgb2(255, 120, 170), Material = Enum.Material.SmoothPlastic, Pattern = "Hearts" },
	FenceNeon = { Category = "PlotFence", Name = "Néon", Unlock = { Kind = "Robux", Price = 79, ProductId = 0 }, Style = "Rail", Color = rgb2(80, 230, 255), Post = rgb2(30, 30, 50), Cap = rgb2(255, 80, 220), Material = Enum.Material.Neon },
	FenceGold = { Category = "PlotFence", Name = "Grille dorée", Unlock = { Kind = "Robux", Price = 99, ProductId = 0 }, Style = "Picket", Color = rgb2(255, 205, 60), Post = rgb2(255, 190, 40), Cap = rgb2(255, 240, 150), Material = Enum.Material.Foil },
	FenceDiamonds = { Category = "PlotFence", Name = "Diamants", Unlock = { Kind = "Robux", Price = 149, ProductId = 0 }, Style = "Panel", Color = rgb2(220, 240, 255), Post = rgb2(120, 200, 255), Cap = rgb2(160, 230, 255), Material = Enum.Material.Glass, Pattern = "Diamonds" },

	------------------------------------------------------------------
	-- MOTIFS ET DÉCORATIONS (phase 10) : Pattern = Stars | Hearts | Diamonds | Pearls |
	--   Flowers | Flames | Clouds | Checker | Stripes | Glitter | Unicorn | Mascot
	--   (voir PatternBuilder ; une image Config.Art.Decals[Pattern] remplace le motif 3D)
	--   PatternColor / PatternAccent : couleurs du motif (sinon couleurs par défaut)
	------------------------------------------------------------------
	-- Bâtiments
	BuildStripes = { Category = "BuildingPalette", Name = "Rayures de marché", Unlock = { Kind = "Coins", Price = 75000 }, Wall = rgb2(255, 245, 230), Roof = rgb2(220, 60, 60), Pattern = "Stripes", PatternColor = rgb2(255, 255, 255), PatternAccent = rgb2(240, 90, 90) },
	BuildFlowers = { Category = "BuildingPalette", Name = "Maison fleurie", Unlock = { Kind = "Level", Level = 14 }, Wall = rgb2(255, 250, 235), Roof = rgb2(120, 180, 90), Pattern = "Flowers" },
	BuildStars = { Category = "BuildingPalette", Name = "Nuit étoilée+", Unlock = { Kind = "Level", Level = 22 }, Wall = rgb2(45, 50, 95), Roof = rgb2(25, 25, 55), Pattern = "Stars" },
	BuildMascot = { Category = "BuildingPalette", Name = "Biscotte", Unlock = { Kind = "Level", Level = 5 }, Wall = rgb2(255, 240, 215), Roof = rgb2(70, 160, 90), Pattern = "Mascot" },
	BuildFlames = { Category = "BuildingPalette", Name = "Forge ardente", Unlock = { Kind = "Index", Zone = "Volcano" }, Wall = rgb2(60, 40, 40), Roof = rgb2(30, 20, 20), Pattern = "Flames" },
	BuildHearts = { Category = "BuildingPalette", Name = "Petits cœurs", Unlock = { Kind = "Robux", Price = 49, ProductId = 0 }, Wall = rgb2(255, 220, 235), Roof = rgb2(230, 80, 130), Pattern = "Hearts" },
	BuildClouds = { Category = "BuildingPalette", Name = "Ciel de nuages", Unlock = { Kind = "Robux", Price = 75, ProductId = 0 }, Wall = rgb2(150, 200, 255), Roof = rgb2(255, 255, 255), Pattern = "Clouds" },
	BuildUnicorn = { Category = "BuildingPalette", Name = "Licornes", Unlock = { Kind = "Robux", Price = 99, ProductId = 0 }, Wall = rgb2(240, 220, 255), Roof = rgb2(255, 150, 220), Pattern = "Unicorn" },
	BuildDiamonds = { Category = "BuildingPalette", Name = "Palais de diamants", Unlock = { Kind = "Robux", Price = 149, ProductId = 0 }, Wall = rgb2(230, 245, 255), Roof = rgb2(120, 200, 255), Pattern = "Diamonds" },
	BuildGlitter = { Category = "BuildingPalette", Name = "Paillettes", Unlock = { Kind = "Robux", Price = 99, ProductId = 0 }, Wall = rgb2(255, 230, 250), Roof = rgb2(220, 120, 255), Pattern = "Glitter" },

	-- Clôtures d'enclos (panneaux décorés entre les barres)
	PenChecker = { Category = "PenSkin", Name = "Damier", Unlock = { Kind = "Coins", Price = 45000 }, Color = rgb2(245, 245, 245), Material = Enum.Material.SmoothPlastic, Pattern = "Checker" },
	PenFlowers = { Category = "PenSkin", Name = "Fleurie", Unlock = { Kind = "Level", Level = 16 }, Color = rgb2(255, 250, 235), Material = Enum.Material.WoodPlanks, Pattern = "Flowers" },
	PenMascot = { Category = "PenSkin", Name = "Biscotte", Unlock = { Kind = "Index", Zone = "Desert" }, Color = rgb2(255, 240, 215), Material = Enum.Material.WoodPlanks, Pattern = "Mascot" },
	PenHearts = { Category = "PenSkin", Name = "Cœurs", Unlock = { Kind = "Robux", Price = 49, ProductId = 0 }, Color = rgb2(255, 200, 220), Material = Enum.Material.SmoothPlastic, Pattern = "Hearts" },
	PenPearls = { Category = "PenSkin", Name = "Perles", Unlock = { Kind = "Robux", Price = 79, ProductId = 0 }, Color = rgb2(240, 230, 250), Material = Enum.Material.Marble, Pattern = "Pearls" },
	PenFlames = { Category = "PenSkin", Name = "Flammes", Unlock = { Kind = "Robux", Price = 99, ProductId = 0 }, Color = rgb2(40, 30, 30), Material = Enum.Material.Basalt, Pattern = "Flames" },

	-- Sols de parcelle (motifs semés sur le sol)
	FloorFlowers = { Category = "PlotFloor", Name = "Champ de fleurs", Unlock = { Kind = "Level", Level = 18 }, Color = rgb2(115, 185, 80), Material = Enum.Material.SmoothPlastic, Pattern = "Flowers" },
	FloorChecker = { Category = "PlotFloor", Name = "Damier", Unlock = { Kind = "Coins", Price = 90000 }, Color = rgb2(235, 235, 235), Material = Enum.Material.SmoothPlastic, Pattern = "Checker", PatternColor = rgb2(60, 60, 70) },
	FloorStars = { Category = "PlotFloor", Name = "Ciel étoilé", Unlock = { Kind = "Level", Level = 28 }, Color = rgb2(35, 35, 80), Material = Enum.Material.SmoothPlastic, Pattern = "Stars" },
	FloorClouds = { Category = "PlotFloor", Name = "Nuages", Unlock = { Kind = "Robux", Price = 99, ProductId = 0 }, Color = rgb2(150, 205, 255), Material = Enum.Material.SmoothPlastic, Pattern = "Clouds" },
	FloorUnicorn = { Category = "PlotFloor", Name = "Licornes", Unlock = { Kind = "Robux", Price = 149, ProductId = 0 }, Color = rgb2(240, 220, 255), Material = Enum.Material.SmoothPlastic, Pattern = "Unicorn" },
	FloorMascot = { Category = "PlotFloor", Name = "Biscotte", Unlock = { Kind = "Level", Level = 30 }, Color = rgb2(255, 235, 200), Material = Enum.Material.Sand, Pattern = "Mascot" },

	-- Panneaux de parcelle
	SignStars = { Category = "SignStyle", Name = "Étoiles", Unlock = { Kind = "Coins", Price = 20000 }, Color = rgb2(40, 40, 90), Material = Enum.Material.SmoothPlastic, TextColor = rgb2(255, 230, 120), Pattern = "Stars" },
	SignMascot = { Category = "SignStyle", Name = "Biscotte", Unlock = { Kind = "Free" }, Color = rgb2(255, 240, 215), Material = Enum.Material.WoodPlanks, TextColor = rgb2(120, 70, 40), Pattern = "Mascot" },
	SignFlames = { Category = "SignStyle", Name = "Flammes", Unlock = { Kind = "Level", Level = 18 }, Color = rgb2(50, 30, 30), Material = Enum.Material.Basalt, TextColor = rgb2(255, 200, 80), Pattern = "Flames" },
	SignHearts = { Category = "SignStyle", Name = "Cœurs", Unlock = { Kind = "Robux", Price = 25, ProductId = 0 }, Color = rgb2(255, 210, 230), Material = Enum.Material.SmoothPlastic, TextColor = rgb2(200, 50, 110), Pattern = "Hearts" },
	SignUnicorn = { Category = "SignStyle", Name = "Licorne", Unlock = { Kind = "Robux", Price = 49, ProductId = 0 }, Color = rgb2(240, 220, 255), Material = Enum.Material.SmoothPlastic, TextColor = rgb2(170, 80, 200), Pattern = "Unicorn" },
	SignDiamonds = { Category = "SignStyle", Name = "Diamants", Unlock = { Kind = "Robux", Price = 75, ProductId = 0 }, Color = rgb2(200, 235, 255), Material = Enum.Material.Glass, TextColor = rgb2(40, 90, 160), Pattern = "Diamonds" },

	-- Selles
	SaddleFlowers = { Category = "MountSkin", Name = "Selle fleurie", Unlock = { Kind = "Level", Level = 15 }, Saddle = rgb2(255, 240, 220), Harness = rgb2(120, 190, 90), Pattern = "Flowers" },
	SaddleFlames = { Category = "MountSkin", Name = "Selle de feu", Unlock = { Kind = "Index", Zone = "Volcano" }, Saddle = rgb2(40, 25, 25), Harness = rgb2(255, 110, 30), Neon = true, Pattern = "Flames" },
	SaddleUnicorn = { Category = "MountSkin", Name = "Selle licorne", Unlock = { Kind = "Robux", Price = 99, ProductId = 0 }, Saddle = rgb2(250, 230, 255), Harness = rgb2(255, 150, 220), Pattern = "Unicorn", Sparkles = true },
	SaddleCheckers = { Category = "MountSkin", Name = "Selle de course", Unlock = { Kind = "Coins", Price = 60000 }, Saddle = rgb2(245, 245, 245), Harness = rgb2(40, 40, 50), Pattern = "Checker", PatternColor = rgb2(30, 30, 40) },
}

--------------------------------------------------------------------------
-- DIRECTION ARTISTIQUE (phase 10)
--   Éclairage par lieu, décor de la ferme, images (Decals) facultatives, mascotte.
--   Les valeurs d'éclairage sont appliquées côté client selon l'endroit où se trouve
--   le joueur (ferme, zone d'expédition, donjon), avec une transition douce.
--------------------------------------------------------------------------
local rgb3 = Color3.fromRGB
Config.Art = {
	-- Éclairage : Lighting + Atmosphere + ColorCorrection
	Lighting = {
		Farm = {
			ClockTime = 14.3, Brightness = 2.6, Ambient = rgb3(120, 105, 90), OutdoorAmbient = rgb3(165, 145, 120),
			FogColor = rgb3(220, 205, 180), Density = 0.28, Haze = 1.2, AtmosphereColor = rgb3(255, 230, 200), Decay = rgb3(255, 200, 150),
			Tint = rgb3(255, 244, 228), Saturation = 0.18, Contrast = 0.06, Bloom = 0.35,
		},
		Forest = {
			ClockTime = 16.5, Brightness = 2, Ambient = rgb3(70, 95, 60), OutdoorAmbient = rgb3(110, 140, 95),
			FogColor = rgb3(150, 190, 140), Density = 0.42, Haze = 2, AtmosphereColor = rgb3(190, 230, 170), Decay = rgb3(120, 170, 90),
			Tint = rgb3(230, 255, 225), Saturation = 0.15, Contrast = 0.08, Bloom = 0.5,
		},
		Mountain = {
			ClockTime = 12, Brightness = 3, Ambient = rgb3(130, 145, 170), OutdoorAmbient = rgb3(180, 200, 230),
			FogColor = rgb3(225, 235, 250), Density = 0.45, Haze = 2.5, AtmosphereColor = rgb3(220, 235, 255), Decay = rgb3(170, 200, 240),
			Tint = rgb3(235, 245, 255), Saturation = 0, Contrast = 0.05, Bloom = 0.45,
		},
		Desert = {
			ClockTime = 13, Brightness = 3.4, Ambient = rgb3(150, 120, 80), OutdoorAmbient = rgb3(210, 170, 110),
			FogColor = rgb3(240, 205, 150), Density = 0.38, Haze = 3, AtmosphereColor = rgb3(255, 215, 160), Decay = rgb3(240, 170, 90),
			Tint = rgb3(255, 238, 210), Saturation = 0.12, Contrast = 0.08, Bloom = 0.4,
		},
		Volcano = {
			ClockTime = 19.2, Brightness = 1.3, Ambient = rgb3(110, 50, 35), OutdoorAmbient = rgb3(130, 60, 40),
			FogColor = rgb3(90, 40, 30), Density = 0.5, Haze = 2.5, AtmosphereColor = rgb3(200, 90, 50), Decay = rgb3(255, 90, 30),
			Tint = rgb3(255, 220, 200), Saturation = 0.2, Contrast = 0.15, Bloom = 0.7,
		},
		-- Donjon : ambiance violette mais BIEN éclairée (on doit voir les ennemis)
		Dungeon = {
			ClockTime = 15, Brightness = 2.6, Ambient = rgb3(150, 135, 170), OutdoorAmbient = rgb3(175, 160, 195),
			FogColor = rgb3(120, 100, 150), Density = 0.18, Haze = 0.4, AtmosphereColor = rgb3(200, 180, 230), Decay = rgb3(170, 120, 210),
			Tint = rgb3(245, 238, 255), Saturation = 0.12, Contrast = 0.08, Bloom = 0.4,
		},
	},
	TransitionTime = 1.5, -- secondes de transition entre deux éclairages

	-- Musiques d'ambiance (SoundId Roblox, 0 = pas de musique). Voir README : « Images et sons ».
	Music = { Farm = 0, Forest = 0, Mountain = 0, Desert = 0, Volcano = 0, Dungeon = 0 },
	MusicVolume = 0.35,

	-- Décor de la ferme
	Farm = {
		Seed = 2024, -- graine du hasard (même décor sur tous les serveurs)
		GroundSize = 1700, -- côté du terrain d'herbe (studs)
		StreamX = -90, -- ruisseau nord-sud entre la 1re et la 2e colonne de parcelles
		StreamWidth = 8,
		MainPathWidth = 14,
		BranchPathWidth = 8,
		Trees = 140, Flowers = 220, Bushes = 60, Rocks = 30,
		MountainRing = { Radius = 760, Count = 16 },
		GrassColor = rgb3(88, 150, 58), -- sol de la map (plus foncé que le sol des parcelles)
		PathColor = rgb3(205, 170, 115),
	},

	-- IMAGES FACULTATIVES (Decals / Textures). 0 = pas d'image : le motif est fait en 3D (Parts).
	-- Quand tu mets un ID, l'image remplace le motif 3D sur les surfaces (répétée en mosaïque).
	-- Liste complète, tailles et étapes : README, section « Images et sons ».
	Decals = {
		Stars = 0, Hearts = 0, Diamonds = 0, Pearls = 0, Flowers = 0, Flames = 0, Clouds = 0,
		Checker = 0, Stripes = 0, Glitter = 0, Unicorn = 0, Mascot = 0,
		MascotLogo = 0, -- logo du jeu sur le panneau du spawn
	},
	-- Noms des motifs (affichés dans 🎨 Personnaliser)
	PatternNames = {
		Stars = "étoiles", Hearts = "cœurs", Diamonds = "diamants", Pearls = "perles", Flowers = "fleurs",
		Flames = "flammes", Clouds = "nuages", Checker = "damier", Stripes = "rayures", Glitter = "paillettes",
		Unicorn = "licornes", Mascot = "Biscotte",
	},

	-- Mascotte originale du jeu
	Mascot = {
		Name = "Biscotte",
		Description = "un chaton fermier tout rond, avec un chapeau de paille et une salopette verte",
		Fur = rgb3(255, 196, 120), Belly = rgb3(255, 240, 215), Overalls = rgb3(70, 160, 90),
		Hat = rgb3(240, 205, 110), HatBand = rgb3(220, 70, 70), Nose = rgb3(255, 130, 150),
	},
}

--------------------------------------------------------------------------
-- TUTORIEL : suite de quêtes pour les nouveaux joueurs
--   Event   : action qui valide la quête (GameEvents, côté serveur) ; Arg = précision (bâtiment)
--   Check   : déjà fait ? (validée tout de suite) : HasPen | HasAnimal | HasAnimalInPen |
--             HasBuilding (Arg) | HasPedestal | HasExhibit
--   Target  : où pointe la flèche : { Kind = "World", Position } | { Kind = "Plot", Prefix, Part? }
--             (objet de TA parcelle) | { Kind = "Button", Name } (bouton du HUD qui clignote)
--   Reward  : { Coins, XP, Seeds = { Id, Amount }, Item = { Id, Amount }, Boost = { Type, Power, Duration },
--             WheelSpins } (donnée UNE seule fois, même si on relance le tutoriel)
--------------------------------------------------------------------------
local stands = Config.Stands
Config.Tutorial = {
	Quests = {
		{ Id = "BuySeed", Event = "BuySeed", Text = "Achète des graines au stand 🌱 GRAINES", Target = { Kind = "World", Position = stands.SeedShopPosition }, Reward = { Coins = 100 } },
		{ Id = "Plant", Event = "Plant", Text = "Plante une graine : choisis-la en bas de l'écran, puis E sur une case de terre", Target = { Kind = "Plot", Prefix = "Field_" }, Reward = { Coins = 100, XP = 20 } },
		{ Id = "Harvest", Event = "Harvest", Text = "Attends qu'elle pousse, puis récolte-la (E quand c'est « Prêt ! »)", Target = { Kind = "Plot", Prefix = "Field_" }, Reward = { Coins = 150, XP = 20 } },
		{ Id = "Sell", Event = "Sell", Text = "Vends ta récolte au stand 💰 VENTE", Target = { Kind = "World", Position = stands.SellStandPosition }, Reward = { Coins = 200 } },
		{ Id = "BuildPen", Event = "BuildPen", Check = "HasPen", Text = "Construis un enclos : 🔨 Construire > Enclos, puis pose-le sur ta parcelle", Target = { Kind = "Button", Name = "BuildButton" }, Reward = { Coins = 300 } },
		{ Id = "BuyAnimal", Event = "BuyAnimal", Check = "HasAnimal", Text = "Achète un animal au stand 🐄 ANIMAUX (une poule pour commencer)", Target = { Kind = "World", Position = stands.AnimalShopPosition }, Reward = { Coins = 200 } },
		{ Id = "PlaceAnimal", Event = "PlaceAnimal", Check = "HasAnimalInPen", Text = "Ouvre 🐾 Mes animaux et place ton animal dans l'enclos", Target = { Kind = "Button", Name = "AnimalsButton" }, Reward = { Coins = 200, XP = 30 } },
		{ Id = "Feed", Event = "Feed", Text = "Remplis la mangeoire : E sur la mangeoire de l'enclos (avec des récoltes qu'il aime)", Target = { Kind = "Plot", Prefix = "Pen_", Part = "Trough" }, Reward = { Coins = 300, Seeds = { Id = "Wheat", Amount = 6 } } },
		{ Id = "BuildBakery", Event = "BuildBuilding", Arg = "Bakery", Check = "HasBuilding", Text = "Construis la 🥖 Boulangerie : 🔨 Construire > Bâtiments", Target = { Kind = "Button", Name = "BuildButton" }, Reward = { Coins = 500 } },
		{ Id = "Recipe", Event = "QueueRecipe", Arg = "Bakery", Text = "Lance une recette : E sur la porte de la boulangerie, choisis Pain, puis « Lancer » (4 blés)", Target = { Kind = "Plot", Prefix = "Building_Bakery", Part = "Door" }, Reward = { Coins = 300, XP = 50 } },
		{ Id = "Collect", Event = "CollectRecipe", Arg = "Bakery", Text = "Quand le pain est prêt, récupère-le : E sur la porte > Récupérer", Target = { Kind = "Plot", Prefix = "Building_Bakery", Part = "Door" }, Reward = { Coins = 300 } },
		{ Id = "Consume", Event = "Consume", Text = "Mange un produit pour un boost : 🎒 Sac, bouton 🍴 à côté du pain", Target = { Kind = "Button", Name = "InventoryButton" }, Reward = { Boost = { Type = "Speed", Power = 0.2, Duration = 600 } } },
		{ Id = "Travel", Event = "Travel", Text = "Pars en expédition : portail violet 🧭 EXPÉDITIONS, puis la Forêt", Target = { Kind = "World", Position = Config.Expeditions.PortalPosition }, Reward = { Coins = 500 } },
		{ Id = "Capture", Event = "Capture", Text = "Capture une créature : approche-toi, E, puis clique quand le curseur est dans la zone verte", Target = nil, Reward = { Coins = 800, XP = 80 } },
		{ Id = "Pedestal", Event = "BuildPedestal", Check = "HasPedestal", Text = "De retour à la ferme, construis un socle : 🔨 Construire > Socle", Target = { Kind = "Button", Name = "BuildButton" }, Reward = { Coins = 500 } },
		{ Id = "Exhibit", Event = "Exhibit", Check = "HasExhibit", Text = "Expose ta créature : 📖 Créatures > 🏛️ Exposer (elle rapporte des Coins/s)", Target = { Kind = "Button", Name = "CollectionButton" }, Reward = { Coins = 1000 } },
		{ Id = "Dungeon", Event = "DungeonWin", Text = "Termine un donjon au portail rouge ⚔️ DONJONS (dès le niveau 8)", Target = { Kind = "World", Position = stands.DungeonPortalPosition }, Reward = { Coins = 5000, WheelSpins = 1 } },
	},
	FinalReward = { Coins = 3000, Boost = { Type = "Coins", Power = 0.5, Duration = 900 } },
}

--------------------------------------------------------------------------
-- RÉCOMPENSES DE TEMPS DE JEU (dans la session en cours, vérifiées par le serveur)
--   Minutes : temps de jeu nécessaire depuis l'arrivée ; Reward : comme le tutoriel
--   (CoinsPerLevel = Coins en plus par niveau du joueur)
--------------------------------------------------------------------------
Config.Playtime = {
	Rewards = {
		{ Minutes = 15, Reward = { Coins = 2000, CoinsPerLevel = 300 } },
		{ Minutes = 30, Reward = { Seeds = { Id = "Dragonfruit", Amount = 3 }, Boost = { Type = "Coins", Power = 0.5, Duration = 900 } } },
		{ Minutes = 60, Reward = { WheelSpins = 1, Coins = 8000, CoinsPerLevel = 800, Boost = { Type = "XP", Power = 0.5, Duration = 1200 } } },
		{ Minutes = 120, Reward = { Item = { Id = "MountainEgg", Amount = 1 }, Seeds = { Id = "StarFlower", Amount = 1 }, Coins = 25000, CoinsPerLevel = 2500 } },
	},
}

--------------------------------------------------------------------------
-- LIMITES DE LA MAP (murs invisibles + retour automatique au point sûr)
--   Le saut le plus haut (Astrelune, JumpPower 90) monte à ~21 studs : les murs font 160.
--------------------------------------------------------------------------
Config.Bounds = {
	WallHeight = 160,
	FarmRadius = 585, -- rayon de la zone de jeu de la ferme (avant le pied des montagnes)
	FarmWallSegments = 40,
	FallY = -30, -- en dessous : le joueur est ramené à un point sûr
	CheckInterval = 0.5, -- secondes entre deux vérifications (serveur)
	Margin = 12, -- tolérance au-delà des murs avant de ramener le joueur
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
	Enabled = false, -- VERSION DE SORTIE : pas de dalle de pièces de test, pas de messages de debug
	TestCoinPadAmount = 25, -- coins donnés par le pad jaune de test sur chaque parcelle
	TestCoinPadCooldown = 1, -- secondes entre deux utilisations du pad
	PrintDataOnLoad = false, -- affiche les données chargées dans l'Output
}

return Config
