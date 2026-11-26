--[[
	PromptController.lua
	====================
	Masque, pour CE joueur uniquement, les ProximityPrompts marqués "OwnerOnly"
	qui se trouvent sur la parcelle d'un autre joueur (cases de terre, pad de test).

	C'est purement visuel : même si un exploiteur réactive un prompt, le serveur
	refuse l'action ("Ce n'est pas ta parcelle !").

	Astuce : on modifie MaxActivationDistance (que le serveur ne change jamais)
	plutôt que Enabled (que le serveur change selon l'état de la case).
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local PromptController = {}

local player = Players.LocalPlayer
local baseDistances: { [ProximityPrompt]: number } = {}

local function getPlotModel(instance: Instance): Model?
	local current = instance.Parent
	while current and current ~= Workspace do
		if current:IsA("Model") and current:GetAttribute("PlotId") then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function applyPrompt(prompt: ProximityPrompt)
	local plot = getPlotModel(prompt)
	if not plot then
		return
	end
	if not baseDistances[prompt] then
		baseDistances[prompt] = prompt.MaxActivationDistance
		prompt.Destroying:Connect(function()
			baseDistances[prompt] = nil
		end)
	end
	local isMine = plot:GetAttribute("OwnerUserId") == player.UserId
	prompt.MaxActivationDistance = if isMine then baseDistances[prompt] else 0
end

local function applyPlot(plot: Instance)
	for _, descendant in plot:GetDescendants() do
		if descendant:IsA("ProximityPrompt") and descendant:GetAttribute("OwnerOnly") then
			applyPrompt(descendant)
		end
	end
end

local function watchPlot(plot: Instance)
	if not plot:IsA("Model") then
		return
	end
	applyPlot(plot)
	plot:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
		applyPlot(plot)
	end)
	plot.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("ProximityPrompt") and descendant:GetAttribute("OwnerOnly") then
			applyPrompt(descendant)
		end
	end)
end

function PromptController.Init()
	task.spawn(function()
		local plotsFolder = Workspace:WaitForChild("Plots")
		for _, plot in plotsFolder:GetChildren() do
			watchPlot(plot)
		end
		plotsFolder.ChildAdded:Connect(watchPlot)
	end)
end

return PromptController
