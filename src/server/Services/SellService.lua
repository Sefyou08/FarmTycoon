--[[
	SellService.lua
	===============
	Stand de vente : le ProximityPrompt ouvre la fenêtre de vente (SellUI) où le joueur
	CHOISIT quoi vendre (objet par objet, quantité) ou vend tout.
	RemoteFunction "SellItems" (validée ici : distance, quantités, objets possédés).
	Prix d'un objet = SellPrice (Config.Crops / Config.Resources)
	                  x multiplicateur de variante (Config.Variants : Doré x2, ...)
	                  x multiplicateur du joueur (phase 7 : rebirth, phase 8 : game pass x2)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local ItemUtil = require(ReplicatedStorage.Shared.ItemUtil)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RemoteGuard = require(script.Parent.Parent.Util.RemoteGuard)
local GameEvents = require(script.Parent.Parent.Util.GameEvents)
local StandBuilder = require(script.Parent.Parent.Util.StandBuilder)
local CurrencyService = require(script.Parent.CurrencyService)
local InventoryService = require(script.Parent.InventoryService)

local SellService = {}

local standPosition: Vector3

function SellService:GetPlayerSellMultiplier(player: Player): number
	-- Rebirths + boost Coins (phase 9 : game pass x2 ici aussi)
	return CurrencyService:GetCoinMultiplier(player)
end

-- Vend une liste d'objets choisis par le joueur (ou tout l'inventaire avec "All").
-- request = "All" | { { Item = id, Variant = variante, Amount = quantité }, ... }
local function onSellItems(player: Player, request: any): (boolean, string)
	if not RemoteGuard.CheckCooldown(player, "SellItems", 0.4) then
		return false, "Doucement !"
	end
	if not RemoteGuard.IsNear(player, standPosition, Config.Stands.MaxDistance) then
		return false, "Approche-toi du stand 💰 VENTE."
	end
	if InventoryService:GetItemCount(player) <= 0 then
		return false, "Rien à vendre ! Récolte tes plantes ou ramasse la production de tes animaux."
	end

	-- Liste à vendre (validée : types, quantités entières, objets réellement possédés)
	local wanted: { [string]: { [string]: number } } = {}
	if request == "All" then
		wanted = InventoryService:TakeAllItems(player)
	else
		if type(request) ~= "table" or #request == 0 or #request > 200 then
			return false, "Choisis au moins un objet à vendre."
		end
		local sums: { [string]: { [string]: number } } = {}
		for _, entry in request do
			if type(entry) ~= "table" or type(entry.Item) ~= "string" or not ItemUtil.Get(entry.Item) or not ItemUtil.IsValidVariant(entry.Variant) then
				return false, "Requête invalide."
			end
			local amount = tonumber(entry.Amount)
			if not amount or amount ~= amount or amount < 1 or amount ~= math.floor(amount) then
				return false, "Quantité invalide."
			end
			sums[entry.Item] = sums[entry.Item] or {}
			sums[entry.Item][entry.Variant] = (sums[entry.Item][entry.Variant] or 0) + amount
		end
		for itemId, variants in sums do
			for variant, amount in variants do
				if InventoryService:GetAmount(player, itemId, variant) < amount then
					return false, ("Tu n'as pas %d %s."):format(amount, ItemUtil.Label(itemId, variant))
				end
			end
		end
		for itemId, variants in sums do
			for variant, amount in variants do
				InventoryService:RemoveItem(player, itemId, variant, amount)
			end
		end
		wanted = sums
	end

	local total, count = 0, 0
	for itemId, variants in wanted do
		for variant, amount in variants do
			total += ItemUtil.UnitValue(itemId, variant) * amount
			count += amount
		end
	end
	total *= SellService:GetPlayerSellMultiplier(player)
	local ok, added = CurrencyService:AddCoins(player, total, "Sell")
	if not ok then
		return false, "Rien n'a été vendu."
	end
	GameEvents.Fire(player, "Sell")
	return true, ("+%s Coins (%d objet(s) vendu(s))"):format(Format.Number(added), count)
end

function SellService:Init()
	standPosition = Config.Stands.SellStandPosition
	local _, _, prompt = StandBuilder.Build({
		Name = "SellStand",
		Position = standPosition,
		Facing = Vector3.new(-1, 0, 0), -- tourné vers le centre de la map
		Color = Color3.fromRGB(200, 150, 40),
		Title = "💰 VENTE",
		ActionText = "Vendre",
		ObjectText = "Marchand",
		PromptDistance = 10,
		Theme = "Sell", -- décor du stand (phase 10)
	})
	prompt:SetAttribute("OpenUI", "Sell") -- le client ouvre la fenêtre de vente (choix des objets)
end

function SellService:Start()
	Remotes.Get("SellItems").OnServerInvoke = onSellItems
end

return SellService
