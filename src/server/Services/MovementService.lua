--[[
	MovementService.lua
	===================
	  • Applique la vitesse de marche de base (Config.Movement.WalkSpeed) à chaque
	    personnage qui apparaît. Le sprint (Maj) et les boosts de vitesse sont
	    appliqués par le client (MovementController), qui lit les attributs posés ici.
	  • MONTURES : RemoteFunction "MountAction"
	      ("List")             -> chevaux possédés (enclos + chevaux sauvages capturés)
	      ("Mount", kind, id)  -> monter sur ce cheval (kind = "Pen" | "Creature")
	      ("Dismount")         -> descendre
	    Le serveur vérifie le niveau (Config.Progression.Unlocks.Mount) et que le cheval
	    appartient bien au joueur. Il construit un cheval articulé (MountBuilder), le
	    soude sous le personnage et LÈVE le personnage (HipHeight) pour qu'il soit assis
	    sur le dos : c'est donc le personnage qui porte la physique (direction, saut,
	    rotation fluide), et le cheval est animé par les clients (pattes, tête).
	    Attributs posés sur le joueur : Mounted, MountSpeed, MountSprint (lus par le client).
	  • Descente automatique : mort / réapparition, déconnexion, portail (expédition,
	    donjon) via MovementService:Dismount(player).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CreatureUtil = require(ReplicatedStorage.Shared.CreatureUtil)
local CosmeticUtil = require(ReplicatedStorage.Shared.CosmeticUtil)
local ItemUtil = require(ReplicatedStorage.Shared.ItemUtil)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RemoteGuard = require(script.Parent.Parent.Util.RemoteGuard)
local MountBuilder = require(script.Parent.Parent.Util.MountBuilder)
local DataService = require(script.Parent.DataService)
local XPService = require(script.Parent.XPService)

local Mounts = Config.Mounts

local MovementService = {}

type Ride = {
	Model: Model,
	Humanoid: Humanoid,
	HipHeight: number,
	UseJumpPower: boolean,
	JumpPower: number,
}

local rides: { [Player]: Ride } = {}

-- Tous les chevaux montables du joueur : { Kind, Id, Species, Variant, Label, Speed, SprintSpeed, JumpPower, Perk }
local function listMounts(player: Player): { { [string]: any } }
	local data = DataService:GetData(player)
	local result = {}
	if not data then
		return result
	end
	local function add(kind: string, id: string, speciesId: string, variantId: string)
		local stats = Mounts.Species[speciesId]
		if not stats then
			return
		end
		local species = Config.Animals[speciesId]
		local rank = ItemUtil.GetVariant(variantId).Order - 1
		local multiplier = 1 + Mounts.VariantSpeedBonus * rank
		local adjective = ItemUtil.VariantAdjective(species, variantId)
		table.insert(result, {
			Kind = kind,
			Id = id,
			Species = speciesId,
			Variant = variantId,
			Label = species.DisplayName .. (if adjective ~= "" then " " .. adjective else ""),
			Speed = math.floor(stats.Speed * multiplier + 0.5),
			SprintSpeed = math.floor(stats.SprintSpeed * multiplier + 0.5),
			JumpPower = stats.JumpPower,
			Perk = stats.Perk,
			Where = if kind == "Pen" then "Enclos" elseif kind == "Stable" then "Mes animaux" else "Collection",
		})
	end
	-- Chevaux dans les enclos (cheval de ferme et chevaux sauvages mis en enclos)
	for _, pen in data.Pens do
		if pen.Species and Mounts.Species[pen.Species] then
			for _, animal in pen.Animals do
				add("Pen", tostring(animal.Id), pen.Species, animal.Variant)
			end
		end
	end
	-- Chevaux dans 🐾 Mes animaux (pas encore en enclos)
	for _, animal in data.AnimalInventory or {} do
		if Mounts.Species[animal.Species] then
			add("Stable", animal.Id, animal.Species, animal.Variant)
		end
	end
	-- Chevaux sauvages encore dans la collection
	for _, entry in data.Creatures do
		local def = CreatureUtil.Get(entry.Creature)
		if def and def.Horse then
			add("Creature", entry.Id, def.Horse, Mounts.MutationToVariant[entry.Mutation] or "Normal")
		end
	end
	table.sort(result, function(a, b)
		return a.SprintSpeed > b.SprintSpeed
	end)
	return result
end

function MovementService:Dismount(player: Player)
	local ride = rides[player]
	rides[player] = nil
	player:SetAttribute("Mounted", nil)
	player:SetAttribute("MountSpeed", nil)
	player:SetAttribute("MountSprint", nil)
	if ride then
		if ride.Humanoid.Parent then
			ride.Humanoid.HipHeight = ride.HipHeight
			ride.Humanoid.UseJumpPower = ride.UseJumpPower
			ride.Humanoid.JumpPower = ride.JumpPower
		end
		ride.Model:Destroy()
	end
end

local function mount(player: Player, entry: { [string]: any }): (boolean, string)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
		return false, "Ton personnage n'est pas prêt."
	end
	MovementService:Dismount(player)

	-- Le personnage est levé pour être assis sur le dos du cheval ; le cheval est soudé dessous
	local ride: Ride = {
		Model = nil :: any,
		Humanoid = humanoid,
		HipHeight = humanoid.HipHeight,
		UseJumpPower = humanoid.UseJumpPower,
		JumpPower = humanoid.JumpPower,
	}
	local skin = CosmeticUtil.Equipped(DataService:GetData(player), "MountSkin") -- selle cosmétique
	-- Cheval généré, ou modèle importé (CustomModels.Animals.<espèce>) mesuré pour de vrai
	local model, body, layout = MountBuilder.Build(entry.Species, entry.Variant, skin)
	model:SetAttribute("OwnerUserId", player.UserId)
	ride.Model = model
	-- Hauteur du centre du HumanoidRootPart : assis sur le dos. Avec HipHeight ainsi réglé,
	-- le personnage "flotte" à la bonne hauteur et les sabots du cheval touchent le sol.
	local riderHeight = layout.BackHeight + Mounts.RiderOffset

	humanoid.HipHeight = riderHeight - root.Size.Y / 2
	humanoid.UseJumpPower = true
	humanoid.JumpPower = entry.JumpPower

	local weld = Instance.new("Weld")
	weld.Part0 = root
	weld.Part1 = body
	-- Le siège (milieu du dos) est juste sous le cavalier
	weld.C0 = CFrame.new(0, layout.AttachHeight - riderHeight, -layout.SeatZ)
	weld.Parent = body
	model.Parent = character

	rides[player] = ride
	player:SetAttribute("MountSpeed", entry.Speed)
	player:SetAttribute("MountSprint", entry.SprintSpeed)
	player:SetAttribute("Mounted", true)
	return true, ("🐴 En selle sur %s ! (%s, vitesse %d)"):format(entry.Label, entry.Perk, entry.Speed)
end

local function onMountAction(player: Player, action: any, kind: any, id: any): any
	if not RemoteGuard.CheckCooldown(player, "MountAction", 0.5) then
		return false, "Doucement !"
	end
	if action == "List" then
		return listMounts(player)
	elseif action == "Dismount" then
		MovementService:Dismount(player)
		return true, "Tu descends de cheval."
	elseif action == "Mount" then
		if not XPService:HasUnlock(player, "Mount") then
			return false, ("🐴 Monture débloquée au niveau %d."):format(Config.Progression.Unlocks.Mount)
		end
		if player:GetAttribute("InDungeon") then
			return false, "Pas de monture dans un donjon !"
		end
		if type(kind) ~= "string" or type(id) ~= "string" then
			return false, "Requête invalide."
		end
		for _, entry in listMounts(player) do
			if entry.Kind == kind and entry.Id == id then
				return mount(player, entry)
			end
		end
		return false, "Tu n'as pas ce cheval."
	end
	return false, "Action inconnue."
end

local function onCharacterAdded(player: Player, character: Model)
	-- La monture ne survit pas à une réapparition (le personnage précédent est détruit)
	local ride = rides[player]
	rides[player] = nil
	if ride then
		ride.Model:Destroy()
	end
	player:SetAttribute("Mounted", nil)
	player:SetAttribute("MountSpeed", nil)
	player:SetAttribute("MountSprint", nil)

	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid.WalkSpeed = Config.Movement.WalkSpeed
		humanoid.Died:Connect(function()
			MovementService:Dismount(player)
		end)
	end
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

function MovementService:Init() end

function MovementService:Start()
	Remotes.Get("MountAction").OnServerInvoke = onMountAction
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		MovementService:Dismount(player)
	end)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return MovementService
