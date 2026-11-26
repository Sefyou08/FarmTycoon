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
}

--------------------------------------------------------------------------
-- ENCLOS
--------------------------------------------------------------------------
Config.Pens = {
	Size = 20, -- côté de l'enclos (studs)
	Capacity = 4, -- animaux max par enclos (une seule espèce par enclos)
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

	GroundColor = Color3.fromRGB(106, 170, 70),
	BorderColor = Color3.fromRGB(110, 75, 45),
	SignColor = Color3.fromRGB(150, 105, 60),

	FreeLabel = "Parcelle libre",
	OwnerLabelFormat = "Ferme de %s", -- %s = DisplayName du joueur
}

--------------------------------------------------------------------------
-- DÉPLACEMENT DU PERSONNAGE
--------------------------------------------------------------------------
Config.Movement = {
	WalkSpeed = 24, -- vitesse de marche normale (Roblox par défaut : 16)
	SprintEnabled = true,
	SprintSpeed = 32, -- vitesse en courant (touche maintenue, ou bouton sur mobile)
	SprintKeys = { Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift },
	-- Monture (cheval) : il faut posséder au moins un cheval dans un enclos + le niveau requis
	MountSpeed = 40,
	MountSprintSpeed = 48,
	MountSpecies = "Horse",
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

	MaxWildPerZone = 10, -- créatures sauvages max en même temps dans une zone
	SpawnInterval = 4, -- secondes entre deux apparitions (si des joueurs sont dans la zone)
	WildLifetime = 150, -- secondes avant qu'une créature sauvage reparte
	WildWanderRadius = 6,
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
			Safe = { Hits = 6, Width = 0.13, Speed = 1.1, MaxMisses = 3, Chance = 1 }, -- 🎯 Sûr
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
	MaxDuration = 3600, -- un boost ne peut pas dépasser 1 h (en cumulant)
	Types = {
		Speed = { Icon = "🏃", DisplayName = "Vitesse" },
		XP = { Icon = "⭐", DisplayName = "XP" },
		Coins = { Icon = "💰", DisplayName = "Coins" },
		Capture = { Icon = "🪢", DisplayName = "Capture" },
		Combat = { Icon = "⚔️", DisplayName = "Combat (donjon)" },
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
-- MONÉTISATION (préparée, DÉSACTIVÉE : activée en phase 8)
-- Remplace les Id = 0 par les vrais IDs créés sur le Creator Dashboard.
--------------------------------------------------------------------------
Config.Monetization = {
	Enabled = false,
	Products = {
		-- Débloque l'étape d'agrandissement suivante sans payer de Coins
		PlotExpansion = { Id = 0, Enabled = false },
	},
	GamePasses = {
		-- Version premium des aides PNJ (tournées 2x plus rapides) : phase 9
		PremiumHelpers = { Id = 0, Enabled = false },
	},
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
