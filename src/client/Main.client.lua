--[[
	Main.client.lua  (StarterPlayerScripts.Client.Main)
	===================================================
	Point d'entrée du client. Le client ne fait QUE :
	  - afficher l'état reçu du serveur ;
	  - envoyer des demandes (RemoteEvents) que le serveur valide.
]]

local Controllers = script.Parent:WaitForChild("Controllers")
local UI = script.Parent:WaitForChild("UI")

local StateController = require(Controllers:WaitForChild("StateController"))
local PromptController = require(Controllers:WaitForChild("PromptController"))
local PlantTimers = require(Controllers:WaitForChild("PlantTimers"))
local AnimalController = require(Controllers:WaitForChild("AnimalController"))
local MovementController = require(Controllers:WaitForChild("MovementController"))

local Notifications = require(UI:WaitForChild("Notifications"))
local HUD = require(UI:WaitForChild("HUD"))
local SeedBar = require(UI:WaitForChild("SeedBar"))
local ShopUI = require(UI:WaitForChild("ShopUI"))
local InventoryUI = require(UI:WaitForChild("InventoryUI"))
local AnimalShopUI = require(UI:WaitForChild("AnimalShopUI"))
local BuildingUI = require(UI:WaitForChild("BuildingUI"))
local PortalUI = require(UI:WaitForChild("PortalUI"))
local CaptureUI = require(UI:WaitForChild("CaptureUI"))
local CollectionUI = require(UI:WaitForChild("CollectionUI"))
local BuildMode = require(UI:WaitForChild("BuildMode"))
local IndexUI = require(UI:WaitForChild("IndexUI"))
local VisitUI = require(UI:WaitForChild("VisitUI"))

Notifications.Init()
HUD.Init(StateController)
SeedBar.Init(HUD.Screen, StateController)
ShopUI.Init(HUD.Screen, Notifications.Show)
InventoryUI.Init(HUD.Screen, HUD, StateController)
AnimalShopUI.Init(HUD.Screen, Notifications.Show)
BuildingUI.Init(HUD.Screen, StateController, Notifications.Show)
PortalUI.Init(HUD.Screen, StateController, Notifications.Show)
CaptureUI.Init(HUD.Screen, Notifications.Show)
CollectionUI.Init(HUD.Screen, HUD, StateController, Notifications.Show)
BuildMode.Init(HUD.Screen, HUD, StateController, Notifications.Show)
IndexUI.Init(HUD.Screen, HUD, StateController, Notifications.Show)
VisitUI.Init(HUD.Screen, HUD)

PromptController.Init()
PlantTimers.Init()
AnimalController.Init()
MovementController.Init(HUD)
StateController.Init() -- en dernier : l'UI écoute déjà Changed quand l'état arrive

print("[FarmTycoon] Client démarré ✅ (Phase 6)")
