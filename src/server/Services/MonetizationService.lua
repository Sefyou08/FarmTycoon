--[[
	MonetizationService.lua
	=======================
	Achats Robux (Config.Monetization). TOUT est décidé et donné par le serveur.

	  • GAME PASSES (achat unique, effet permanent) : à l'arrivée du joueur on vérifie
	    UserOwnsGamePassAsync pour chaque pass dont l'Id > 0, et on pose l'attribut
	    "Pass_<Nom>" sur le joueur (lu par CurrencyService, HelperService, ItemUtil,
	    CreatureUtil...). Un achat en jeu (PromptGamePassPurchaseFinished) active le pass
	    immédiatement.
	  • DEVELOPER PRODUCTS (achetables plusieurs fois) : MarketplaceService.ProcessReceipt.
	    Idempotent : chaque reçu (PurchaseId) est mémorisé dans data.PurchaseHistory ;
	    un reçu déjà vu est confirmé sans redonner la récompense. On renvoie
	    NotProcessedYet si le joueur n'est pas là ou ses données pas chargées :
	    Roblox réessaiera plus tard (le joueur n'est jamais débité pour rien).
	  • Un Id à 0 = produit pas encore créé sur Roblox : le bouton affiche "Bientôt disponible".
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local CosmeticUtil = require(ReplicatedStorage.Shared.CosmeticUtil)
local Format = require(ReplicatedStorage.Shared.Format)
local DataService = require(script.Parent.DataService)
local SyncService = require(script.Parent.SyncService)
local CurrencyService = require(script.Parent.CurrencyService)
local BoostService = require(script.Parent.BoostService)
local PlotService = require(script.Parent.PlotService)
local EggService = require(script.Parent.EggService)
local CosmeticService = require(script.Parent.CosmeticService)
local WheelService = require(script.Parent.WheelService)

local Monetization = Config.Monetization

local MonetizationService = {}

-- Id Roblox -> clé du produit dans Config
local productById: { [number]: string } = {}
local passById: { [number]: string } = {}

--------------------------------------------------------------------------
-- Game Passes
--------------------------------------------------------------------------

local function setPass(player: Player, key: string)
	if player:GetAttribute("Pass_" .. key) then
		return
	end
	player:SetAttribute("Pass_" .. key, true)
	local pass = Monetization.GamePasses[key]
	SyncService:Notify(player, ("%s Game Pass actif : %s"):format(pass.Icon, pass.Name), "Rare")
	-- Les capacités (sac, collection, couveuses) sont recalculées côté client via l'attribut
	CurrencyService:Refresh(player)
end

local function checkPasses(player: Player)
	for key, pass in Monetization.GamePasses do
		if RunService:IsStudio() and Monetization.GrantAllPassesInStudio then
			setPass(player, key)
		elseif pass.Id > 0 then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.Id)
			if ok and owns and player.Parent then
				setPass(player, key)
			elseif not ok then
				warn(("[Monetization] Vérification du pass %s impossible : %s"):format(key, tostring(owns)))
			end
		end
	end
end

--------------------------------------------------------------------------
-- Developer Products
--------------------------------------------------------------------------

-- Donne la récompense du produit ; renvoie true si c'est fait
local function grantProduct(player: Player, data: { [string]: any }, productId: number): boolean
	-- Cosmétique payant ?
	local cosmeticId = CosmeticUtil.FindByProductId(productId)
	if cosmeticId then
		return CosmeticService:GrantOwned(player, cosmeticId)
	end

	local key = productById[productId]
	local product = key and Monetization.Products[key]
	if not product then
		warn(("[Monetization] Produit inconnu : %d"):format(productId))
		return false
	end

	if product.Kind == "Coins" then
		-- Coins achetés : pas de multiplicateur (montant exact affiché dans la boutique)
		local amount = product.Amount + (product.PerLevel or 0) * (data.Level or 1)
		CurrencyService:AddCoins(player, amount, "Robux:" .. key)
		SyncService:Notify(player, ("💰 +%s Coins, merci !"):format(Format.Number(amount)), "Success")
		return true
	elseif product.Kind == "Boost" then
		local ok = BoostService:Grant(player, product.Boost, product.Power, product.Duration)
		if ok then
			SyncService:Notify(player, ("%s %s activé, merci !"):format(product.Icon, product.Name), "Success")
		end
		return ok
	elseif product.Kind == "PlotExpansion" then
		if PlotService:GrantExpansion(player) then
			return true
		end
		-- Parcelle déjà au maximum (ou pas prête) : on compense en Coins pour ne rien perdre
		local refund = 150000 + 15000 * (data.Level or 1)
		CurrencyService:AddCoins(player, refund, "Robux:PlotRefund")
		SyncService:Notify(player, ("Parcelle déjà au maximum : +%s Coins à la place."):format(Format.Number(refund)), "Info")
		return true
	elseif product.Kind == "HatchNow" then
		local count = EggService:HatchAllNow(player)
		if count == 0 then
			-- Aucun œuf : on garde l'achat sous forme de tour de roue pour ne rien perdre
			WheelService:AddSpins(player, 1)
			SyncService:Notify(player, "Aucun œuf en couveuse : tu reçois 1 tour de roue 🎡 à la place.", "Info")
		else
			SyncService:Notify(player, ("🐣 %d œuf(s) prêts à éclore !"):format(count), "Success")
		end
		return true
	elseif product.Kind == "WheelSpins" then
		local ok = WheelService:AddSpins(player, product.Amount)
		if ok then
			SyncService:Notify(player, ("🎡 +%d tour(s) de roue !"):format(product.Amount), "Success")
		end
		return ok
	end
	return false
end

local function processReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local data = player and DataService:GetData(player)
	if not player or not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- Roblox réessaiera
	end

	data.PurchaseHistory = data.PurchaseHistory or {}
	local history = data.PurchaseHistory
	if table.find(history, receipt.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- déjà donné
	end

	local ok, granted = pcall(grantProduct, player, data, receipt.ProductId)
	if not ok then
		warn("[Monetization] Erreur pendant l'achat : " .. tostring(granted))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not granted then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	table.insert(history, receipt.PurchaseId)
	while #history > Monetization.MaxReceiptHistory do
		table.remove(history, 1)
	end
	-- Sauvegarde tout de suite : un achat ne doit jamais être perdu
	DataService:SaveNow(player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

--------------------------------------------------------------------------

function MonetizationService:Init()
	for key, product in Monetization.Products do
		if product.Id > 0 then
			productById[product.Id] = key
		end
	end
	for key, pass in Monetization.GamePasses do
		if pass.Id > 0 then
			passById[pass.Id] = key
		end
	end
	DataService:OnProfileLoaded(function(player)
		task.spawn(checkPasses, player)
	end)
end

function MonetizationService:Start()
	if not Monetization.Enabled then
		return
	end
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local key = passById[passId]
		if purchased and key then
			setPass(player, key)
		end
	end)
end

return MonetizationService
