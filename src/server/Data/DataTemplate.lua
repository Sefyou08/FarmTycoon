--[[
	DataTemplate.lua
	================
	Structure par défaut des données d'un joueur.

	À chaque chargement, les données sauvegardées sont "réconciliées" avec ce
	modèle : si tu ajoutes un nouveau champ ici, les anciens joueurs le
	recevront automatiquement avec sa valeur par défaut.

	⚠️ Règles pour que la sauvegarde fonctionne (DataStore = JSON) :
	  - seulement des nombres, chaînes, booléens et tables ;
	  - une table est SOIT une liste {a, b, c}, SOIT un dictionnaire à clés
	    "string" — jamais un mélange, jamais de clés numériques à trous ;
	  - pas d'Instance, de Vector3, de Color3, etc.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

return {
	DataVersion = 1, -- pour d'éventuelles migrations futures

	Coins = Config.Currency.StartingCoins,
	Rebirths = 0,

	Inventory = {}, -- produits récoltés : { [cropId] = { [variante] = quantité } } (variante "Normal" ou mutation en phase 3)
	Seeds = {}, -- graines possédées : { [cropId] = quantité }
	Plants = {}, -- plantes en terre : { ["indexCase"] = { CropId, PlantedAt, ReadyAt } } (os.time, continue de pousser hors ligne)
	StarterPackGiven = false, -- pack de graines de départ déjà donné ?

	PlotLevel = 1, -- niveau d'agrandissement de la parcelle (Config.Plots.Expansions)
	-- Enclos construits : { ["indexEmplacement"] = {
	--     Species = "Cow" | nil (nil = enclos vide),
	--     Animals = { { Id, Variant, Progress } },  -- Progress = secondes accumulées vers la prochaine ressource
	--     Feed = rations dans la mangeoire,
	--     Storage = { [variante] = quantité } dans la caisse,
	--     LastUpdate = os.time() de la dernière simulation (production hors ligne) } }
	Pens = {},
	-- Bâtiments construits : { [buildingId] = {
	--     Level = 1,
	--     Queue = { { Recipe = "Bread", Variant = "Normal", Remaining = secondes de travail } },
	--     Output = { [itemId] = { [variante] = quantité } }  -- produits finis à récupérer
	--     LastUpdate = os.time() } }
	Buildings = {},
	Upgrades = {}, -- (phase 7) améliorations : { [upgradeId] = niveau } (ex. ExtraTiles, collecteurs)
	Creatures = {}, -- (phase 5) créatures capturées en expédition
	Displayed = {}, -- (phase 6) créatures exposées sur les socles

	Stats = {
		TotalEarned = 0, -- total de coins gagnés depuis toujours
		TotalHarvested = 0,
		PlayTime = 0, -- secondes
	},

	-- (phase 5) reçus de Developer Products déjà crédités (anti double-crédit)
	PurchaseHistory = {},
}
