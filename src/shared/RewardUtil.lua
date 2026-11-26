--[[
	RewardUtil.lua  (ReplicatedStorage.Shared.RewardUtil)
	=====================================================
	Texte d'une récompense (tutoriel, temps de jeu), identique côté client et serveur.
	  RewardUtil.Describe(reward, level) -> "💰 300 Coins • ⭐ 20 XP"
	  RewardUtil.Coins(reward, level)    -> montant de Coins (avec CoinsPerLevel)
]]

local Config = require(script.Parent.Config)
local Format = require(script.Parent.Format)

local RewardUtil = {}

function RewardUtil.Coins(reward: { [string]: any }, level: number): number
	return (reward.Coins or 0) + (reward.CoinsPerLevel or 0) * (level or 1)
end

function RewardUtil.Describe(reward: { [string]: any }?, level: number?): string
	if not reward then
		return ""
	end
	local parts = {}
	local coins = RewardUtil.Coins(reward, level or 1)
	if coins > 0 then
		table.insert(parts, "💰 " .. Format.Number(coins) .. " Coins")
	end
	if reward.XP then
		table.insert(parts, "⭐ " .. reward.XP .. " XP")
	end
	if reward.Seeds then
		local crop = Config.Crops[reward.Seeds.Id]
		table.insert(parts, ("🌱 %d graine(s) %s"):format(reward.Seeds.Amount, if crop then crop.DisplayName else reward.Seeds.Id))
	end
	if reward.Item then
		local egg = Config.Eggs[reward.Item.Id]
		table.insert(parts, ("%d %s"):format(reward.Item.Amount, if egg then egg.Icon .. " " .. egg.DisplayName else reward.Item.Id))
	end
	if reward.Boost then
		local info = Config.Boosts.Types[reward.Boost.Type]
		table.insert(parts, ("%s boost %s +%d %% (%s)"):format(info.Icon, info.DisplayName, math.floor(reward.Boost.Power * 100), Format.Time(reward.Boost.Duration)))
	end
	if reward.WheelSpins then
		table.insert(parts, ("🎡 %d tour(s) de roue"):format(reward.WheelSpins))
	end
	return table.concat(parts, " • ")
end

return RewardUtil
