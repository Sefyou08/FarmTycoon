--[[
	AnnouncementService.lua
	=======================
	Annonces des grosses captures, selon la portée de la rareté (Config.CreatureRarities.Announce) :
	  "Server" : bannière pour tous les joueurs du serveur
	  "Chat"   : bannière + message système dans le chat du serveur
	  "Global" : bannière + chat sur TOUS les serveurs du jeu (MessagingService)

	MessagingService ne marche pas toujours dans Studio : si l'envoi ou l'abonnement
	échoue, l'annonce est faite au moins sur le serveur actuel.
]]

local MessagingService = game:GetService("MessagingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SyncService = require(script.Parent.SyncService)

local AnnouncementService = {}

local TOPIC = "FarmTycoon_GlobalAnnounce"
local subscribed = false

local function showLocally(text: string, colorHex: string, withChat: boolean)
	SyncService:NotifyAll(text, "Rare")
	if withChat then
		Remotes.Get("ChatAnnounce"):FireAllClients(text, colorHex)
	end
end

function AnnouncementService:Announce(text: string, color: Color3, scope: string?)
	if not scope then
		return
	end
	local colorHex = color:ToHex()
	if scope == "Server" then
		showLocally(text, colorHex, false)
	elseif scope == "Chat" then
		showLocally(text, colorHex, true)
	elseif scope == "Global" then
		task.spawn(function()
			local ok = pcall(function()
				MessagingService:PublishAsync(TOPIC, { Text = text, Color = colorHex })
			end)
			-- Si l'abonnement marche, ce serveur reçoit aussi le message (pas de doublon)
			if not ok or not subscribed then
				showLocally("🌍 " .. text, colorHex, true)
			end
		end)
	end
end

function AnnouncementService:Init() end

function AnnouncementService:Start()
	task.spawn(function()
		local ok, err = pcall(function()
			MessagingService:SubscribeAsync(TOPIC, function(message)
				local data = message.Data
				if type(data) == "table" and type(data.Text) == "string" and #data.Text <= 200 then
					local colorHex = if type(data.Color) == "string" and #data.Color <= 8 then data.Color else "FFD700"
					showLocally("🌍 " .. data.Text, colorHex, true)
				end
			end)
		end)
		subscribed = ok
		if not ok then
			warn("[AnnouncementService] MessagingService indisponible (normal dans Studio) : annonces limitées à ce serveur. " .. tostring(err))
		end
	end)
end

return AnnouncementService
