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

local Notifications = require(UI:WaitForChild("Notifications"))
local HUD = require(UI:WaitForChild("HUD"))
local SeedBar = require(UI:WaitForChild("SeedBar"))
local ShopUI = require(UI:WaitForChild("ShopUI"))
local InventoryUI = require(UI:WaitForChild("InventoryUI"))

Notifications.Init()
HUD.Init(StateController)
SeedBar.Init(HUD.Screen, StateController)
ShopUI.Init(HUD.Screen, Notifications.Show)
InventoryUI.Init(HUD.Screen, HUD, StateController)

PromptController.Init()
PlantTimers.Init()
StateController.Init() -- en dernier : l'UI écoute déjà Changed quand l'état arrive

print("[FarmTycoon] Client démarré ✅ (Phase 2)")
