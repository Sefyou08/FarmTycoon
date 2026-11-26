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
}

--------------------------------------------------------------------------
-- FERME (cases de terre, inventaire, engrais)
--------------------------------------------------------------------------
Config.Farm = {
	StartingTiles = 6, -- cases de terre débloquées au départ
	GridColumns = 6, -- grille max = 6 x 4 = 24 cases (les autres se débloquent en phase 7)
	GridRows = 4,
	TileSize = 6, -- taille d'une case (studs)
	TileGap = 2, -- espace entre deux cases
	GridStartZ = 12, -- distance entre l'entrée de la parcelle et la 1re rangée de cases
	SoilColor = Color3.fromRGB(105, 70, 40),

	InteractDistance = 10, -- distance max pour planter / récolter
	ActionCooldown = 0.15, -- secondes entre deux actions planter/récolter (anti-spam)

	InventoryCapacity = 300, -- nombre max de produits (récoltes + ressources) dans l'inventaire
	MaxSeedsPerCrop = 999, -- nombre max de graines d'un même type

	-- Pack de départ donné UNE seule fois à chaque joueur
	StarterSeeds = { Carrot = 5, Wheat = 5 },
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
		DisplayName = "",
		DisplayNameF = "",
		Chance = 0,
		SpeedMultiplier = 1,
		ValueMultiplier = 1,
		Color = Color3.fromRGB(255, 255, 255),
	},
	Gold = {
		Order = 2,
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

	-- Emplacements sur la parcelle, en coordonnées locales :
	--   X = gauche/droite depuis le centre, Z = profondeur depuis l'entrée.
	--   RequiredLevel = niveau de parcelle nécessaire (voir Config.Plots.Expansions)
	Slots = {
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
	MaxDistance = 16, -- distance max pour acheter / vendre (vérifiée par le serveur)
}

Config.Shop = {
	BuyAmounts = { 1, 5 }, -- boutons d'achat affichés dans la boutique de graines
	MaxBuyAmount = 25, -- quantité max par requête
	BuyCooldown = 0.2,
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
	-- Phase 7 : la monture (cheval) ajoutera un bonus ici
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
}

--------------------------------------------------------------------------
-- BÂTIMENTS DE TRANSFORMATION
--   Price          : prix de construction (Coins)
--   RequiredLevel  : niveau de parcelle nécessaire
--   Requires       : bâtiment à construire avant (ordre de déblocage)
--   X, Z           : emplacement sur la parcelle (coordonnées locales, Z = profondeur)
--   Recipes        : Inputs (le 1er ingrédient donne la variante du produit),
--                    Output, Time (secondes au niveau 1), RequiredBuildingLevel (optionnel)
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
	MaxMisses = 2, -- ratés autorisés pendant le mini-jeu
	CaptureTimeout = 20, -- secondes max pour finir le mini-jeu
	MaxLatency = 1.0, -- tolérance réseau (s) sur le moment du clic envoyé par le client
	HitTolerance = 0.02, -- marge (en fraction de barre) autour de la zone verte
}

Config.Zones = {
	Forest = {
		DisplayName = "Forêt", Icon = "🌲", Order = 1, Feminine = true,
		UnlockPrice = 0, ValueMultiplier = 1,
		Center = Vector3.new(-900, 0, 1400), Size = 320,
		GroundColor = Color3.fromRGB(80, 150, 60), GroundMaterial = Enum.Material.Grass,
		WallColor = Color3.fromRGB(60, 100, 50), Props = "Trees",
	},
	Mountain = {
		DisplayName = "Montagne", Icon = "⛰️", Order = 2, Feminine = true,
		UnlockPrice = 25000, ValueMultiplier = 4,
		Center = Vector3.new(-300, 0, 1400), Size = 320,
		GroundColor = Color3.fromRGB(150, 150, 160), GroundMaterial = Enum.Material.Slate,
		WallColor = Color3.fromRGB(230, 235, 245), Props = "Rocks",
	},
	Desert = {
		DisplayName = "Désert", Icon = "🏜️", Order = 3,
		UnlockPrice = 100000, ValueMultiplier = 15,
		Center = Vector3.new(300, 0, 1400), Size = 320,
		GroundColor = Color3.fromRGB(235, 205, 140), GroundMaterial = Enum.Material.Sand,
		WallColor = Color3.fromRGB(200, 150, 90), Props = "Cacti",
	},
	Volcano = {
		DisplayName = "Volcan", Icon = "🌋", Order = 4,
		UnlockPrice = 400000, ValueMultiplier = 50,
		Center = Vector3.new(900, 0, 1400), Size = 320,
		GroundColor = Color3.fromRGB(60, 45, 45), GroundMaterial = Enum.Material.Basalt,
		WallColor = Color3.fromRGB(40, 30, 30), Props = "Lava",
	},
}

--------------------------------------------------------------------------
-- RARETÉS DES CRÉATURES
--   Weight    : poids d'apparition (en % si le total fait 100)
--   BaseValue : valeur de base (x zone x mutation) ; sert à la vente et aux revenus (phase 6)
--   Capture   : Hits = clics réussis nécessaires, Width = largeur de la zone verte (0-1),
--               Speed = allers par seconde du curseur, Chance = tirage final après le mini-jeu
--   Announce  : "Server" = bannière à tout le serveur, "Chat" = chat + bannière
--------------------------------------------------------------------------
Config.CreatureRarities = {
	Common = {
		DisplayName = "Commune", Order = 1, Color = Color3.fromRGB(200, 200, 200),
		Weight = 60, BaseValue = 100,
		Capture = { Hits = 1, Width = 0.30, Speed = 0.8, Chance = 1.0 },
	},
	Rare = {
		DisplayName = "Rare", Order = 2, Color = Color3.fromRGB(70, 150, 255),
		Weight = 25, BaseValue = 400,
		Capture = { Hits = 2, Width = 0.24, Speed = 1.0, Chance = 0.9 },
	},
	Epic = {
		DisplayName = "Épique", Order = 3, Color = Color3.fromRGB(170, 80, 240),
		Weight = 10, BaseValue = 1500,
		Capture = { Hits = 2, Width = 0.18, Speed = 1.25, Chance = 0.75 },
	},
	Legendary = {
		DisplayName = "Légendaire", Order = 4, Color = Color3.fromRGB(255, 180, 30),
		Weight = 4, BaseValue = 6000,
		Capture = { Hits = 3, Width = 0.15, Speed = 1.5, Chance = 0.55 },
	},
	Mythic = {
		DisplayName = "Mythique", Order = 5, Color = Color3.fromRGB(255, 70, 120),
		Weight = 0.9, BaseValue = 25000, Announce = "Server",
		Capture = { Hits = 3, Width = 0.12, Speed = 1.8, Chance = 0.4 },
	},
	Secret = {
		DisplayName = "Secrète", Order = 6, Color = Color3.fromRGB(20, 255, 200),
		Weight = 0.1, BaseValue = 120000, Announce = "Chat",
		Capture = { Hits = 4, Width = 0.10, Speed = 2.1, Chance = 0.3 },
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
