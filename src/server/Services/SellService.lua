--[[
	SellService.lua
	===============
	Stand de vente : "Tout vendre" via un ProximityPrompt (validé côté serveur).

	Vend TOUT l'inventaire : récoltes, ressources animales (et produits en phase 4).
	Prix d'un objet = SellPrice (Config.Crops / Config.Resources)
	                  x multiplicateur de variante (Config.Variants : Doré x2, ...)
	                  x multiplicateur du joueur (phase 7 : rebirth, phase 8 : game pass x2)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local ItemUtil = require(ReplicatedStorage.Shared.ItemUtil)
local RemoteGuard = require(script.Parent.Parent.Util.RemoteGuard)
local StandBuilder = require(script.Parent.Parent.Util.StandBuilder)
local CurrencyService = require(script.Parent.CurrencyService)
local InventoryService = require(script.Parent.InventoryService)
local SyncService = require(script.Parent.SyncService)

local SellService = {}

local standPosition: Vector3

function SellService:GetPlayerSellMultiplier(_player: Player): number
	return 1 -- phase 7 : rebirths ; phase 8 : game pass x2
end

local function onSellTriggered(player: Player)
	if not RemoteGuard.IsNear(player, standPosition, Config.Stands.MaxDistance) then
		return
	end
	if not RemoteGuard.CheckCooldown(player, "SellAll", 0.5) then
		return
	end
	if InventoryService:GetItemCount(player) <= 0 then
		SyncService:Notify(player, "Rien à vendre ! Récolte tes plantes ou ramasse la production de tes animaux.", "Error")
		return
	end

	local items = InventoryService:TakeAllItems(player)
	local total, count = 0, 0
	for itemId, variants in items do
		for variant, amount in variants do
			total += ItemUtil.UnitValue(itemId, variant) * amount
			count += amount
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
