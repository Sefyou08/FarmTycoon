--[[
	MovementService.lua
	===================
	  • Applique la vitesse de marche de base (Config.Movement.WalkSpeed) à chaque
	    personnage qui apparaît. Le sprint (Maj) et le boost de vitesse sont appliqués
	    par le client (MovementController), qui lit les attributs posés ici.
	  • MONTURE (phase 7) : RemoteEvent "ToggleMount". Le serveur vérifie que le joueur
	    a le niveau requis (Config.Progression.Unlocks.Mount) et possède au moins un
	    cheval dans un enclos. Il pose alors l'attribut "Mounted" sur le joueur et soude
	    un modèle de cheval (sa plus belle variante) sous le personnage, visible par tous.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ItemUtil = require(ReplicatedStorage.Shared.ItemUtil)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RemoteGuard = require(script.Parent.Parent.Util.RemoteGuard)
local DataService = require(script.Parent.DataService)
local SyncService = require(script.Parent.SyncService)
local XPService = require(script.Parent.XPService)
local AnimalService = require(script.Parent.AnimalService)

local MovementService = {}

local mounts: { [Player]: Model } = {}

-- Plus belle variante de cheval possédée, ou nil
local function bestHorse(player: Player): string?
	local data = DataService:GetData(player)
	if not data then
		return nil
	end
	local best, bestOrder = nil, 0
	for _, pen in data.Pens do
		if pen.Species == Config.Movement.MountSpecies then
			for _, animal in pen.Animals do
				local order = ItemUtil.GetVariant(animal.Variant).Order
				if order > bestOrder then
					best, bestOrder = animal.Variant, order
				end
			end
		end
	end
	return best
end

local function dismount(player: Player)
	player:SetAttribute("Mounted", nil)
	local model = mounts[player]
	mounts[player] = nil
	if model then
		model:Destroy()
	end
end

local function mount(player: Player, variant: string)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	-- Modèle de cheval (Parts) soudé sous le personnage, sans collision ni masse
	local model = AnimalService:BuildAnimalModel(Config.Movement.MountSpecies, variant, root.CFrame * CFrame.new(0, -4.2, 0.5))
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = descendant
			weld.Parent = descendant
		elseif descendant:IsA("BillboardGui") then
			descendant:Destroy()
		end
	end
	model.Name = "Mount"
	model.Parent = character
	mounts[player] = model
	player:SetAttribute("Mounted", true)
end

local function onToggleMount(player: Player)
	if not RemoteGuard.CheckCooldown(player, "ToggleMount", 1) then
		return
	end
	if player:GetAttribute("Mounted") then
		dismount(player)
		return
	end
	if not XPService:HasUnlock(player, "Mount") then
		SyncService:Notify(player, ("🐴 Monture débloquée au niveau %d."):format(Config.Progression.Unlocks.Mount), "Error")
		return
	end
	local variant = bestHorse(player)
	if not variant then
		SyncService:Notify(player, "🐴 Il te faut un cheval dans un de tes enclos (stand 🐄 ANIMAUX).", "Error")
		return
	end
	mount(player, variant)
	SyncService:Notify(player, "🐴 En selle ! (rappuie pour descendre)", "Success")
end

local function onCharacterAdded(player: Player, character: Model)
	dismount(player) -- la monture ne survit pas à une réapparition
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid.WalkSpeed = Config.Movement.WalkSpeed
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
	Remotes.Get("ToggleMount").OnServerEvent:Connect(onToggleMount)
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(dismount)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return MovementService
