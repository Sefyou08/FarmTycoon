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
local Notifications = require(UI:WaitForChild("Notifications"))
local HUD = require(UI:WaitForChild("HUD"))

Notifications.Init()
HUD.Init(StateController)
StateController.Init() -- en dernier : l'UI écoute déjà Changed quand l'état arrive

print("[FarmTycoon] Client démarré ✅ (Phase 1)")
