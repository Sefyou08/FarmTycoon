--[[
	PadController.lua
	=================
	Boutons au sol "style tycoon" achetés en Robux (TycoonPad, attribut RobuxProduct) :
	  • en marchant dessus (sur TA parcelle) ou avec E : ouvre la fenêtre d'achat Roblox
	    (MarketplaceService). Le serveur donne la récompense après l'achat (ProcessReceipt) ;
	  • un ID à 0 = produit pas encore créé : « Bientôt disponible » ;
	  • les boutons de boost affichent le boost actif et son minuteur (« ✅ Actif : 1 h 12 min »).
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local PadController = {}

local player = Players.LocalPlayer
local lastPrompt = 0

local function ownerOf(instance: Instance): number?
	local node = instance.Parent
	while node and node ~= Workspace do
		local owner = node:GetAttribute("OwnerUserId")
		if owner ~= nil then
			return owner
		end
		node = node.Parent
	end
	return nil
end

local function buy(productKey: string, notify: (string, string) -> ())
	local product = Config.Monetization.Products[productKey]
	if not product then
		return
	end
	if os.clock() - lastPrompt < Config.TycoonPads.TouchCooldown then
		return
	end
	lastPrompt = os.clock()
	if product.Id <= 0 then
		notify(("%s %s : bientôt disponible !"):format(product.Icon, product.Name), "Info")
		return
	end
	MarketplaceService:PromptProductPurchase(player, product.Id)
end

function PadController.Init(StateController, notify: (string, string) -> ())
	-- Avec E (ProximityPrompt)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local key = prompt:GetAttribute("RobuxProduct")
		if type(key) == "string" then
			lastPrompt = 0
			buy(key, notify)
		end
	end)

	-- En marchant dessus (uniquement sur ma parcelle)
	local connected: { [BasePart]: boolean } = {}
	local function watch(part: Instance)
		if part:IsA("BasePart") and part.Name == "PadTop" and type(part:GetAttribute("RobuxProduct")) == "string" and not connected[part] then
			connected[part] = true
			part.Touched:Connect(function(hit)
				local character = player.Character
				if character and hit:IsDescendantOf(character) and ownerOf(part) == player.UserId and part.Transparency < 0.5 then
					buy(part:GetAttribute("RobuxProduct"), notify)
				end
			end)
		end
	end
	local plots = Workspace:WaitForChild("Plots", 30)
	if plots then
		for _, d in plots:GetDescendants() do
			watch(d)
		end
		plots.DescendantAdded:Connect(watch)
	end

	-- Minuteur du boost actif sur les boutons de boost
	task.spawn(function()
		while true do
			task.wait(1)
			local boosts = StateController.Get("Boosts") or {}
			local now = Workspace:GetServerTimeNow()
			for part in connected do
				local boostType = part:GetAttribute("BoostType")
				local gui = part:FindFirstChild("PadGui")
				local detail = gui and gui:FindFirstChild("Detail")
				if boostType and detail and detail:IsA("TextLabel") then
					local mine = ownerOf(part) == player.UserId
					local boost = boosts[boostType]
					local remaining = if mine and boost then (boost.EndsAt or 0) - now else 0
					detail.Text = if remaining > 0
						then ('<font color="#7CFF8A">✅ Actif : %s</font>  •  %s'):format(Format.Time(math.ceil(remaining)), part:GetAttribute("PriceText") or "")
						else part:GetAttribute("PriceText") or ""
				end
			end
		end
	end)
end

return PadController
