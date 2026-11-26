--[[
	PlantTimers.lua
	===============
	Affiche le compte à rebours au-dessus des plantes qui poussent.
	Le serveur pose le tag "GrowingPlant" et l'attribut ReadyAt (os.time) ;
	le client calcule le temps restant localement (aucun trafic réseau).
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Format = require(ReplicatedStorage.Shared.Format)

local PlantTimers = {}

local GROWING_TAG = "GrowingPlant"

local function updateAll()
	local now = Workspace:GetServerTimeNow()
	for _, model in CollectionService:GetTagged(GROWING_TAG) do
		local readyAt = model:GetAttribute("ReadyAt")
		local gui = model:FindFirstChild("StatusGui")
		local label = gui and gui:FindFirstChild("Label")
		if readyAt and label and label:IsA("TextLabel") then
			local remaining = readyAt - now
			label.Text = if remaining > 0 then "⏳ " .. Format.Time(math.ceil(remaining)) else "✅ Prêt !"
		end
	end
end

function PlantTimers.Init()
	task.spawn(function()
		while true do
			updateAll()
			task.wait(0.25)
		end
	end)
end

return PlantTimers
