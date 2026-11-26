--[[
	Main.server.lua  (ServerScriptService.Server.Main)
	==================================================
	Point d'entrée unique du serveur.
	1. Crée les RemoteEvents / RemoteFunctions.
	2. Charge chaque service, appelle :Init() sur tous, puis :Start() sur tous.
	   - Init  : préparation (connexions internes, construction de la map...)
	   - Start : démarrage (écoute des joueurs, boucles...)
	L'ordre de la liste compte : un service peut utiliser ceux qui le précèdent.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
Remotes.Init()

local ServicesFolder = script.Parent:WaitForChild("Services")

local SERVICE_ORDER = {
	"DataService",
	"SyncService",
	"InventoryService",
	"BoostService",
	"CurrencyService",
	"XPService",
	"PlotService",
	"FarmService",
	"AnimalService",
	"MovementService",
	"BuildingService",
	"DisplayService",
	"PlacementService",
	"ShopService",
	"AnimalShopService",
	"SellService",
	"AnnouncementService",
	"ExpeditionService",
	"EggService",
	"DungeonService",
	"IndexService",
	"LeaderboardService",
	"HelperService",
	"RebirthService",
	"CosmeticService",
	"WheelService",
	"MonetizationService",
}

local services = {}

for _, name in SERVICE_ORDER do
	services[name] = require(ServicesFolder:WaitForChild(name))
end

for _, name in SERVICE_ORDER do
	local service = services[name]
	if service.Init then
		service:Init()
	end
end

for _, name in SERVICE_ORDER do
	local service = services[name]
	if service.Start then
		service:Start()
	end
end

print("[FarmTycoon] Serveur démarré ✅ (Phase 10)")
