--[[
	AnimalShopService.lua
	=====================
	Stand 🐄 ANIMAUX au centre de la map. Le ProximityPrompt ouvre l'interface
	côté client (attribut OpenUI = "AnimalShop"). L'achat passe par la
	RemoteFunction "BuyAnimal", validée ici :
	  type de l'argument, cooldown, distance au stand, place dans un enclos, Coins.
	La variante (Doré, Arc-en-ciel, Légendaire, Mythique) est tirée au sort PAR LE
	SERVEUR, après le paiement.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ItemUtil = require(ReplicatedStorage.Shared.ItemUtil)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RemoteGuard = require(script.Parent.Parent.Util.RemoteGuard)
local StandBuilder = require(script.Parent.Parent.Util.StandBuilder)
local CurrencyService = require(script.Parent.CurrencyService)
local SyncService = require(script.Parent.SyncService)
local AnimalService = require(script.Parent.AnimalService)

local AnimalShopService = {}

local standPosition: Vector3

local function onBuyAnimal(player: Player, speciesId: any): (boolean, string, string?)
	-- 1. Argument
	if type(speciesId) ~= "string" or not Config.Animals[speciesId] or Config.Animals[speciesId].NotForSale then
		return false, "Animal inconnu."
	end
	local species = Config.Animals[speciesId]
	-- 2. Anti-spam
	if not RemoteGuard.CheckCooldown(player, "BuyAnimal", 0.5) then
		return false, "Doucement !"
	end
	-- 3. Distance au stand
	if not RemoteGuard.IsNear(player, standPosition, Config.Stands.MaxDistance) then
		return false, "Approche-toi du stand des animaux."
	end
	-- 4. Place dans un enclos (vérifiée AVANT de faire payer)
	local penKey, reason = AnimalService:FindPenFor(player, speciesId)
	if not penKey then
		return false, reason or "Pas de place."
	end
	-- 5. Paiement
	if not CurrencyService:SpendCoins(player, species.Price, "BuyAnimal:" .. speciesId) then
		return false, "Pas assez de Coins !"
	end

	-- 6. Tirage de la variante côté serveur, puis ajout dans l'enclos
	local variantId = AnimalService:RollVariant()
	if not AnimalService:AddAnimal(player, penKey, speciesId, variantId) then
		-- Ne devrait jamais arriver (place vérifiée juste avant) : on rembourse
		CurrencyService:AddCoins(player, species.Price, "RefundAnimal")
		return false, "Erreur, tu as été remboursé."
	end

	local adjective = ItemUtil.VariantAdjective(species, variantId)
	local name = species.DisplayName .. (if adjective ~= "" then " " .. adjective else "")
	local variant = Config.Variants[variantId]

	if variantId ~= "Normal" then
		SyncService:Notify(player, ("✨ INCROYABLE ! %s %s !"):format(species.Icon, name), "Rare")
	end
	if variant.AnnounceToServer then
		SyncService:NotifyAll(("🌟 %s a obtenu : %s %s !"):format(player.DisplayName, species.Icon, name), "Rare")
	end
	return true, ("%s %s rejoint ta ferme !"):format(species.Icon, name), variantId
end

function AnimalShopService:Init()
	standPosition = Config.Stands.AnimalShopPosition
	local _, _, prompt = StandBuilder.Build({
		Name = "AnimalShop",
		Position = standPosition,
		Facing = Vector3.new(0, 0, 1), -- tourné vers le spawn
		Color = Color3.fromRGB(190, 110, 60),
		Title = "🐄 ANIMAUX",
		ActionText = "Voir les animaux",
		ObjectText = "Éleveur",
		PromptDistance = 10,
		Theme = "Animals", -- décor du stand (phase 10)
	})
	prompt:SetAttribute("OpenUI", "AnimalShop") -- le client ouvre la fenêtre
end

function AnimalShopService:Start()
	Remotes.Get("BuyAnimal").OnServerInvoke = onBuyAnimal
end

return AnimalShopService
