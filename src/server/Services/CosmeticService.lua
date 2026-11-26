--[[
	CosmeticService.lua
	===================
	Personnalisation cosmétique (UNIQUEMENT visuelle, aucun avantage de jeu).
	Catalogue : Config.Cosmetics ; catégories : Config.CosmeticCategories.

	  • Déblocage : gratuit, niveau, zone d'Index complétée (CosmeticUtil.IsOwned),
	    achat en Coins (ici), ou achat en Robux (Developer Product -> MonetizationService
	    appelle CosmeticService:GrantOwned).
	  • RemoteFunction "CosmeticAction" :
	      ("Buy", id)   -> achat en Coins
	      ("Equip", id) -> équiper un cosmétique possédé (un par catégorie)
	  • Application : la plupart des cosmétiques sont lus par les services qui
	    construisent les visuels (enclos, sol, bâtiments, champs, panneau, vitrine,
	    chapeaux, selle) ; après un changement on reconstruit la ferme (PlotService:Reload).
	    Traces de pas et titre : posés ici sur le personnage, visibles par tous.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CosmeticUtil = require(ReplicatedStorage.Shared.CosmeticUtil)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RemoteGuard = require(script.Parent.Parent.Util.RemoteGuard)
local DataService = require(script.Parent.DataService)
local SyncService = require(script.Parent.SyncService)
local CurrencyService = require(script.Parent.CurrencyService)
local PlotService = require(script.Parent.PlotService)

local CosmeticService = {}

-- Catégories qui touchent les visuels de la ferme (reconstruits après un changement)
local FARM_CATEGORIES = {
	PenSkin = true,
	PlotFloor = true,
	BuildingPalette = true,
	FieldStyle = true,
	SignStyle = true,
	ShowcaseFX = true,
	AnimalHat = true,
	PlotFence = true,
}

--------------------------------------------------------------------------
-- Traces de pas et titre (sur le personnage)
--------------------------------------------------------------------------

local function applyCharacterCosmetics(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local head = character and character:FindFirstChild("Head")
	if not root or not head then
		return
	end
	local data = DataService:GetData(player)

	-- Traînée derrière le joueur
	for _, name in { "CosmeticTrail", "CosmeticTrailA0", "CosmeticTrailA1" } do
		local old = root:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	local trail = CosmeticUtil.Equipped(data, "Trail")
	if trail and trail.Color1 then
		local a0 = Instance.new("Attachment")
		a0.Name = "CosmeticTrailA0"
		a0.Position = Vector3.new(0, -1.2, 0.3)
		a0.Parent = root
		local a1 = Instance.new("Attachment")
		a1.Name = "CosmeticTrailA1"
		a1.Position = Vector3.new(0, -2.6, 0.3)
		a1.Parent = root
		local effect = Instance.new("Trail")
		effect.Name = "CosmeticTrail"
		effect.Attachment0 = a0
		effect.Attachment1 = a1
		effect.Lifetime = 0.6
		effect.MinLength = 0.2
		effect.LightEmission = if trail.Glow then 0.8 else 0
		effect.Transparency = NumberSequence.new(0.2, 1)
		effect.Color = if trail.Rainbow
			then ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
				ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 200, 60)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 220, 120)),
				ColorSequenceKeypoint.new(0.75, Color3.fromRGB(80, 160, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 100, 255)),
			})
			else ColorSequence.new(trail.Color1, trail.Color2 or trail.Color1)
		effect.Parent = root
	end

	-- Titre au-dessus de la tête
	local oldTitle = head:FindFirstChild("CosmeticTitle")
	if oldTitle then
		oldTitle:Destroy()
	end
	local title = CosmeticUtil.Equipped(data, "Title")
	if title and title.Text then
		local gui = Instance.new("BillboardGui")
		gui.Name = "CosmeticTitle"
		gui.Size = UDim2.fromScale(8, 1)
		gui.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
		gui.MaxDistance = 80
		gui.LightInfluence = 0
		gui.Parent = head
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = title.Color or Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0.3
		label.Text = title.Text
		label.Parent = gui
	end
end

local function refresh(player: Player, category: string)
	local data = DataService:GetData(player)
	if data then
		SyncService:Set(player, "Cosmetics", data.Cosmetics)
	end
	if FARM_CATEGORIES[category] then
		PlotService:Reload(player) -- reconstruit la ferme avec les nouveaux visuels
	elseif category == "Trail" or category == "Title" then
		applyCharacterCosmetics(player)
	end
	-- MountSkin : appliqué à la prochaine montée en selle
end

--------------------------------------------------------------------------
-- API
--------------------------------------------------------------------------

-- Achat Robux validé (appelé par MonetizationService dans ProcessReceipt)
function CosmeticService:GrantOwned(player: Player, id: string): boolean
	local data = DataService:GetData(player)
	local def = Config.Cosmetics[id]
	if not data or not def then
		return false
	end
	data.Cosmetics.Owned[id] = true
	data.Cosmetics.Equipped[def.Category] = id -- on l'équipe directement
	refresh(player, def.Category)
	SyncService:Notify(player, ("🎨 %s débloqué et équipé !"):format(def.Name), "Rare")
	return true
end

local function onCosmeticAction(player: Player, action: any, id: any): (boolean, string)
	if not RemoteGuard.CheckCooldown(player, "CosmeticAction", 0.5) then
		return false, "Doucement !"
	end
	local def = CosmeticUtil.Get(id)
	local data = DataService:GetData(player)
	if not def or not data then
		return false, "Cosmétique inconnu."
	end

	if action == "Buy" then
		if CosmeticUtil.IsOwned(data, id) then
			return false, "Tu l'as déjà."
		end
		if def.Unlock.Kind ~= "Coins" then
			return false, "Ce cosmétique ne s'achète pas en Coins."
		end
		if not CurrencyService:SpendCoins(player, def.Unlock.Price, "Cosmetic:" .. id) then
			return false, ("Il te faut %s Coins."):format(Format.Number(def.Unlock.Price))
		end
		data.Cosmetics.Owned[id] = true
		data.Cosmetics.Equipped[def.Category] = id
		refresh(player, def.Category)
		return true, ("🎨 %s acheté et équipé !"):format(def.Name)
	elseif action == "Equip" then
		if not CosmeticUtil.IsOwned(data, id) then
			return false, "Débloque-le d'abord : " .. CosmeticUtil.UnlockText(def)
		end
		data.Cosmetics.Equipped[def.Category] = id
		refresh(player, def.Category)
		return true, ("🎨 %s équipé."):format(def.Name)
	end
	return false, "Action inconnue."
end

function CosmeticService:Init()
	DataService:OnProfileLoaded(function(player, data)
		if type(data.Cosmetics) ~= "table" then
			data.Cosmetics = { Owned = {}, Equipped = {} }
		end
		SyncService:Set(player, "Cosmetics", data.Cosmetics)
		applyCharacterCosmetics(player)
	end)
end

function CosmeticService:Start()
	Remotes.Get("CosmeticAction").OnServerInvoke = onCosmeticAction
	local function onPlayerAdded(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("HumanoidRootPart", 10)
			character:WaitForChild("Head", 10)
			applyCharacterCosmetics(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return CosmeticService
