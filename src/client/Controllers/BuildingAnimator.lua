--[[
	BuildingAnimator.lua
	====================
	Anime côté client les pièces mobiles des bâtiments (Models tagués "BuildingAnim",
	créés par BuildingBuilder) : roue de la fromagerie, rouet de la filature, volant,
	bobine et aiguille de la machine à coudre.
	  Attributs : Anim = "Spin" (rotation) | "Bob" (va-et-vient), Axis = "X" | "Y" | "Z"
	  (axe local du pivot), Speed (rad/s ou fréquence), Amp (amplitude du va-et-vient).
	Ça ne bouge QUE si le bâtiment a l'attribut Working = true (posé par le serveur
	quand il y a une production en cours). Les bâtiments éloignés ne sont pas animés.
]]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BuildingAnimator = {}

local TAG = "BuildingAnim"
local MAX_DISTANCE = 160

type Entry = { Base: CFrame, Angle: number, Building: Instance? }
local entries: { [Model]: Entry } = {}

local function findBuilding(model: Model): Instance?
	local node = model.Parent
	while node and node ~= Workspace do
		if node:GetAttribute("Working") ~= nil then
			return node
		end
		node = node.Parent
	end
	return nil
end

local function track(model: Instance)
	if model:IsA("Model") then
		entries[model] = { Base = model:GetPivot(), Angle = 0, Building = findBuilding(model) }
	end
end

function BuildingAnimator.Init()
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(model)
		task.defer(track, model) -- attend que tout le modèle soit répliqué
	end)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(model)
		entries[model :: Model] = nil
	end)
	for _, model in CollectionService:GetTagged(TAG) do
		track(model)
	end

	local clock = 0
	RunService.Heartbeat:Connect(function(dt)
		clock += dt
		local camera = Workspace.CurrentCamera
		local cameraPos = if camera then camera.CFrame.Position else Vector3.zero
		for model, entry in entries do
			if not model.Parent then
				entries[model] = nil
				continue
			end
			if not entry.Building then
				entry.Building = findBuilding(model)
			end
			local building = entry.Building
			if not building or not building:GetAttribute("Working") then
				continue
			end
			if (entry.Base.Position - cameraPos).Magnitude > MAX_DISTANCE then
				continue
			end
			local speed = model:GetAttribute("Speed") or 1
			local axis = model:GetAttribute("Axis") or "Y"
			if model:GetAttribute("Anim") == "Bob" then
				local amp = model:GetAttribute("Amp") or 0.3
				local offset = math.sin(clock * speed) * amp
				local delta = if axis == "X" then Vector3.new(offset, 0, 0) elseif axis == "Z" then Vector3.new(0, 0, offset) else Vector3.new(0, offset, 0)
				model:PivotTo(entry.Base * CFrame.new(delta))
			else
				entry.Angle = (entry.Angle + dt * speed) % (math.pi * 2)
				local rotation = if axis == "X" then CFrame.Angles(entry.Angle, 0, 0) elseif axis == "Z" then CFrame.Angles(0, 0, entry.Angle) else CFrame.Angles(0, entry.Angle, 0)
				model:PivotTo(entry.Base * rotation)
			end
		end
	end)
end

return BuildingAnimator
