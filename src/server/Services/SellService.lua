--[[
	SellService.lua
	===============
	Stand de vente : "Tout vendre" via un ProximityPrompt (validé côté serveur).

	Prix d'un produit = SellPrice de la culture
	                    x multiplicateur de variante (phase 3 : mutations)
	                    x multiplicateur du joueur (phase 4 : rebirth, phase 5 : familiers / game pass)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local RemoteGuard = require(script.Parent.Parent.Util.RemoteGuard)
local StandBuilder = require(script.Parent.Parent.Util.StandBuilder)
local CurrencyService = require(script.Parent.CurrencyService)
local InventoryService = require(script.Parent.InventoryService)
local SyncService = require(script.Parent.SyncService)

local SellService = {}

local standPosition: Vector3

function SellService:GetVariantMultiplier(_variant: string): number
	return 1 -- phase 3 : Dorée x3, Arc-en-ciel x10...
end

function SellService:GetPlayerSellMultiplier(_player: Player): number
	return 1 -- phase 4/5 : rebirths, familiers, game pass x2
end

local function onSellTriggered(player: Player)
	if not RemoteGuard.IsNear(player, standPosition, Config.Stands.MaxDistance) then
		return
	end
	if not RemoteGuard.CheckCooldown(player, "SellAll", 0.5) then
		return
	end
	if InventoryService:GetItemCount(player) <= 0 then
		SyncService:Notify(player, "Rien à vendre ! Récolte d'abord tes plantes.", "Error")
		return
	end

	local items = InventoryService:TakeAllCrops(player)
	local total, count = 0, 0
	for cropId, variants in items do
		local crop = Config.Crops[cropId]
		if crop then
			for variant, amount in variants do
				total += crop.SellPrice * SellService:GetVariantMultiplier(variant) * amount
				count += amount
			end
		end
	end
	total *= SellService:GetPlayerSellMultiplier(player)

	local ok, added = CurrencyService:AddCoins(player, total, "SellAll")
	if ok then
		SyncService:Notify(player, ("+%s Coins (%d produits vendus)"):format(Format.Number(added), count), "Success")
	end
end

function SellService:Init()
	standPosition = Config.Stands.SellStandPosition
	local _, _, prompt = StandBuilder.Build({
		Name = "SellStand",
		Position = standPosition,
		Facing = Vector3.new(-1, 0, 0), -- tourné vers le centre de la map
		Color = Color3.fromRGB(200, 150, 40),
		Title = "💰 VENTE",
		ActionText = "Tout vendre",
		ObjectText = "Marchand",
		PromptDistance = 10,
	})
	prompt.Triggered:Connect(onSellTriggered)
end

function SellService:Start() end

return SellService
