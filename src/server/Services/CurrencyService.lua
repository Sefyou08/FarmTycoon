--[[
	CurrencyService.lua
	===================
	SEUL endroit autorisé à modifier les Coins d'un joueur.
	Gère aussi les leaderstats (Coins, Rebirths) affichés dans le classement.

	  CurrencyService:AddCoins(player, amount, reason) -> (ok, montantAjouté)
	  CurrencyService:SpendCoins(player, amount, reason) -> ok
	  CurrencyService:GetCoins(player) -> number
	  CurrencyService:CanAfford(player, amount) -> boolean

	Multiplicateur des gains : CurrencyService:GetCoinMultiplier (rebirths + boost Coins),
	appliqué par la vente et les socles (pas par les remboursements ni les récompenses).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local SyncService = require(script.Parent.SyncService)
local BoostService = require(script.Parent.BoostService)

local CurrencyService = {}

local function isValidAmount(amount: any): boolean
	return typeof(amount) == "number" and amount == amount and amount > 0 and amount < math.huge
end

-- Met à jour leaderstats + HUD client à partir des données serveur.
function CurrencyService:Refresh(player: Player)
	local data = DataService:GetData(player)
	if not data then
		return
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local coins = leaderstats:FindFirstChild(Config.Currency.Name)
		local rebirths = leaderstats:FindFirstChild("Rebirths")
		if coins then
			coins.Value = data.Coins
		end
		if rebirths then
			rebirths.Value = data.Rebirths
		end
	end

	SyncService:Set(player, "Coins", data.Coins)
	SyncService:Set(player, "Rebirths", data.Rebirths)
end

-- Multiplicateur des GAINS (vente, socles) : rebirths x boost "Coins" x Game Pass x2 Coins
function CurrencyService:GetCoinMultiplier(player: Player): number
	local data = DataService:GetData(player)
	local rebirths = if data then data.Rebirths else 0
	local pass = if player:GetAttribute("Pass_DoubleCoins") then 2 else 1 -- Game Pass x2 Coins
	return (1 + Config.Rebirth.CoinMultiplierPerRebirth * rebirths) * BoostService:GetMultiplier(player, "Coins") * pass
end

function CurrencyService:GetCoins(player: Player): number
	local data = DataService:GetData(player)
	return if data then data.Coins else 0
end

function CurrencyService:CanAfford(player: Player, amount: number): boolean
	return isValidAmount(amount) and self:GetCoins(player) >= amount
end

-- silent = true : pas de ligne dans l'Output (versements fréquents, ex. socles toutes les 5 s)
function CurrencyService:AddCoins(player: Player, amount: number, reason: string?, silent: boolean?): (boolean, number)
	if not isValidAmount(amount) then
		warn(("[CurrencyService] AddCoins refusé : montant invalide (%s) pour %s"):format(tostring(amount), player.Name))
		return false, 0
	end
	local data = DataService:GetData(player)
	if not data then
		return false, 0
	end

	local finalAmount = math.floor(amount)
	if finalAmount <= 0 then
		return false, 0
	end

	data.Coins += finalAmount
	data.Stats.TotalEarned += finalAmount
	self:Refresh(player)

	if Config.Debug.Enabled and not silent then
		print(("[CurrencyService] +%d coins pour %s (%s) -> total %d"):format(finalAmount, player.Name, reason or "?", data.Coins))
	end
	return true, finalAmount
end

function CurrencyService:SpendCoins(player: Player, amount: number, reason: string?): boolean
	if not isValidAmount(amount) then
		return false
	end
	local data = DataService:GetData(player)
	if not data then
		return false
	end

	local cost = math.ceil(amount)
	if data.Coins < cost then
		return false
	end

	data.Coins -= cost
	self:Refresh(player)

	if Config.Debug.Enabled then
		print(("[CurrencyService] -%d coins pour %s (%s) -> total %d"):format(cost, player.Name, reason or "?", data.Coins))
	end
	return true
end

function CurrencyService:Init()
	-- Création des leaderstats dès que les données sont chargées
	DataService:OnProfileLoaded(function(player, data)
		local leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"

		local coins = Instance.new("IntValue")
		coins.Name = Config.Currency.Name
		coins.Value = data.Coins
		coins.Parent = leaderstats

		local rebirths = Instance.new("IntValue")
		rebirths.Name = "Rebirths"
		rebirths.Value = data.Rebirths
		rebirths.Parent = leaderstats

		leaderstats.Parent = player
		self:Refresh(player)
	end)
end

function CurrencyService:Start() end

return CurrencyService
