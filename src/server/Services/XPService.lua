--[[
	XPService.lua
	=============
	Expérience et niveau du joueur.
	  • XPService:AddXP(player, amount) : ajoute de l'XP (x boost "XP"), gère les
	    passages de niveau (plusieurs d'un coup si besoin), offre des Coins et
	    annonce les déblocages (Config.Progression.Unlocks).
	  • XP nécessaire pour passer du niveau N au N+1 : XPBase x N ^ XPExponent.
	  • Les autres services appellent AddXP : récolte, production animale,
	    fabrication, capture.
	  • Le niveau est affiché dans le classement (leaderstats "Niveau").
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local DataService = require(script.Parent.DataService)
local SyncService = require(script.Parent.SyncService)
local CurrencyService = require(script.Parent.CurrencyService)
local BoostService = require(script.Parent.BoostService)

local Progression = Config.Progression

local XPService = {}

-- Libellés des déblocages par niveau
local UNLOCK_NAMES = {
	Farmer = "🧑‍🌾 Fermier PNJ (bouton Aides)",
	Caretaker = "🧺 Soigneur PNJ (bouton Aides)",
	Mount = "🐴 Monture (si tu as un cheval)",
	Rebirth = "⭐ Rebirth",
}

function XPService:GetXPForNextLevel(level: number): number
	return math.floor(Progression.XPBase * level ^ Progression.XPExponent)
end

function XPService:GetLevel(player: Player): number
	local data = DataService:GetData(player)
	return if data then data.Level else 1
end

-- true si le joueur a le niveau requis pour un déblocage (Config.Progression.Unlocks)
function XPService:HasUnlock(player: Player, unlockId: string): boolean
	return self:GetLevel(player) >= (Progression.Unlocks[unlockId] or 1)
end

local function refresh(player: Player, data: { [string]: any })
	SyncService:Set(player, "XP", data.XP)
	SyncService:Set(player, "Level", data.Level)
	local leaderstats = player:FindFirstChild("leaderstats")
	local levelValue = leaderstats and leaderstats:FindFirstChild("Niveau")
	if levelValue then
		levelValue.Value = data.Level
	end
end

function XPService:AddXP(player: Player, amount: number)
	local data = DataService:GetData(player)
	if not data or type(amount) ~= "number" or amount <= 0 then
		return
	end
	data.XP += math.floor(amount * BoostService:GetMultiplier(player, "XP") + 0.5)

	local needed = self:GetXPForNextLevel(data.Level)
	while data.XP >= needed do
		data.XP -= needed
		data.Level += 1
		local reward = Progression.LevelUpCoins * data.Level
		CurrencyService:AddCoins(player, reward, "LevelUp")
		SyncService:Notify(player, ("⬆️ Niveau %d ! +%s Coins"):format(data.Level, Format.Number(reward)), "Rare")
		for unlockId, level in Progression.Unlocks do
			if level == data.Level and UNLOCK_NAMES[unlockId] then
				SyncService:Notify(player, "🔓 Débloqué : " .. UNLOCK_NAMES[unlockId], "Success")
			end
		end
		needed = self:GetXPForNextLevel(data.Level)
	end
	refresh(player, data)
end

function XPService:Init()
	DataService:OnProfileLoaded(function(player, data)
		data.Level = math.max(1, math.floor(tonumber(data.Level) or 1))
		data.XP = math.max(0, math.floor(tonumber(data.XP) or 0))
		-- leaderstats "Niveau" (créé ici, à côté de Coins et Rebirths)
		task.defer(function()
			local leaderstats = player:WaitForChild("leaderstats", 10)
			if leaderstats and not leaderstats:FindFirstChild("Niveau") then
				local levelValue = Instance.new("IntValue")
				levelValue.Name = "Niveau"
				levelValue.Value = data.Level
				levelValue.Parent = leaderstats
			end
			refresh(player, data)
		end)
	end)
end

function XPService:Start() end

return XPService
