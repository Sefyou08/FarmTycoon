--[[
	HelperService.lua
	=================
	Aides automatiques (PNJ), achetables puis améliorables avec des Coins
	(Config.Helpers), débloquées par le niveau du joueur (Config.Progression.Unlocks).

	  • Fermier  : à chaque tournée, récolte les plantes mûres puis replante
	               (FarmService:AutoFarm), dans la limite de "Actions" cases.
	  • Soigneur : à chaque tournée, ramasse la production et remplit les
	               mangeoires de "Pens" enclos (AnimalService:AutoCare).
	  • Un petit personnage se tient à l'entrée de la parcelle, avec son niveau.
	  • data.Helpers = { Farmer = niveau, Caretaker = niveau } (absent = pas acheté).
	  • RemoteFunction "HelperAction"(helperId) : achète le niveau 1 ou le niveau suivant.
	  • Phase 9 : Game Pass "aides premium" (tournées 2x plus rapides) -> GetSpeedMultiplier.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RemoteGuard = require(script.Parent.Parent.Util.RemoteGuard)
local CurrencyService = require(script.Parent.CurrencyService)
local SyncService = require(script.Parent.SyncService)
local PlotService = require(script.Parent.PlotService)
local XPService = require(script.Parent.XPService)
local FarmService = require(script.Parent.FarmService)
local AnimalService = require(script.Parent.AnimalService)

local HelperService = {}

type State = {
	Player: Player,
	Plot: any,
	Data: { [string]: any },
	NextRun: { [string]: number },
	Models: { [string]: Model },
}

local states: { [Player]: State } = {}

-- Game Pass "Aides premium" : tournées 2x plus rapides (attribut posé par MonetizationService)
function HelperService:GetSpeedMultiplier(player: Player): number
	return if player:GetAttribute("Pass_PremiumHelpers") then 2 else 1
end

local function makePart(props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	local anyPart: any = part
	for key, value in props do
		anyPart[key] = value
	end
	return part
end

-- Petit PNJ en Parts (corps, tête, chapeau) avec son nom et son niveau
local function buildHelperModel(state: State, helperId: string)
	local old = state.Models[helperId]
	if old then
		old:Destroy()
		state.Models[helperId] = nil
	end
	local level = state.Data.Helpers[helperId]
	if not level then
		return
	end
	local def = Config.Helpers[helperId]
	local base = PlotService:ToWorld(state.Plot, def.Position.X, def.Position.Z) * CFrame.Angles(0, math.pi, 0)

	local model = Instance.new("Model")
	model.Name = "Helper_" .. helperId
	makePart({ Name = "Legs", Size = Vector3.new(1.4, 2, 1), CFrame = base * CFrame.new(0, 1, 0), Color = Color3.fromRGB(60, 80, 150), Parent = model })
	makePart({ Name = "Body", Size = Vector3.new(2, 2, 1.1), CFrame = base * CFrame.new(0, 3, 0), Color = def.Color, Parent = model })
	makePart({ Name = "Head", Shape = Enum.PartType.Ball, Size = Vector3.new(1.5, 1.5, 1.5), CFrame = base * CFrame.new(0, 4.8, 0), Color = Color3.fromRGB(255, 205, 160), Parent = model })
	makePart({ Name = "Hat", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 2.4, 2.4), CFrame = base * CFrame.new(0, 5.5, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(220, 190, 110), Parent = model })

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(7, 1.6)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 7.2, 0)
	gui.MaxDistance = 60
	gui.LightInfluence = 0
	gui.Adornee = model:FindFirstChild("Head") :: BasePart
	gui.Parent = model
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Text = ("%s %s niv. %d"):format(def.Icon, def.DisplayName, level)
	label.Parent = gui

	model.Parent = state.Plot.Model
	state.Models[helperId] = model
end

local function onHelperAction(player: Player, helperId: any): (boolean, string)
	local def = type(helperId) == "string" and Config.Helpers[helperId]
	if not def then
		return false, "Aide inconnue."
	end
	if not RemoteGuard.CheckCooldown(player, "HelperAction", 0.5) then
		return false, "Doucement !"
	end
	local state = states[player]
	if not state then
		return false, "Ta ferme n'est pas encore prête."
	end
	if not XPService:HasUnlock(player, helperId) then
		return false, ("%s %s débloqué au niveau %d."):format(def.Icon, def.DisplayName, Config.Progression.Unlocks[helperId] or 1)
	end
	local current = state.Data.Helpers[helperId] or 0
	local nextLevel = def.Levels[current + 1]
	if not nextLevel then
		return false, "Niveau maximum atteint."
	end
	if not CurrencyService:SpendCoins(player, nextLevel.Price, "Helper:" .. helperId) then
		return false, ("Il te faut %s Coins."):format(Format.Number(nextLevel.Price))
	end
	state.Data.Helpers[helperId] = current + 1
	state.NextRun[helperId] = 0 -- première tournée tout de suite
	buildHelperModel(state, helperId)
	SyncService:Set(player, "Helpers", state.Data.Helpers)
	if current == 0 then
		return true, ("%s %s embauché ! Il travaille même quand tu es occupé ailleurs."):format(def.Icon, def.DisplayName)
	end
	return true, ("%s %s passe au niveau %d !"):format(def.Icon, def.DisplayName, current + 1)
end

-- Une tournée d'une aide
local function runHelper(state: State, helperId: string, levelInfo: any)
	local player = state.Player
	if helperId == "Farmer" then
		local harvested, planted = FarmService:AutoFarm(player, levelInfo.Actions)
		if harvested + planted > 0 then
			player:SetAttribute("FarmerLastRun", ("🌾 %d récoltées, %d plantées"):format(harvested, planted))
		end
	elseif helperId == "Caretaker" then
		local fed, collected = AnimalService:AutoCare(player, levelInfo.Pens)
		if fed + collected > 0 then
			player:SetAttribute("CaretakerLastRun", ("🍽️ %d rations, 📦 %d ramassées"):format(fed, collected))
		end
	end
end

local function activate(player: Player, plot: any, data: { [string]: any })
	if states[player] then
		return
	end
	if type(data.Helpers) ~= "table" then
		data.Helpers = {}
	end
	local state: State = { Player = player, Plot = plot, Data = data, NextRun = {}, Models = {} }
	states[player] = state
	for helperId in Config.Helpers do
		buildHelperModel(state, helperId)
	end
	SyncService:Set(player, "Helpers", data.Helpers)
end

local function deactivate(player: Player, _plot: any)
	local state = states[player]
	states[player] = nil
	if state then
		for _, model in state.Models do
			model:Destroy()
		end
	end
end

function HelperService:Init()
	PlotService:OnPlotReady(activate)
	PlotService:OnPlotReleased(deactivate)
end

function HelperService:Start()
	Remotes.Get("HelperAction").OnServerInvoke = onHelperAction
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.clock()
			for player, state in states do
				for helperId, def in Config.Helpers do
					local level = state.Data.Helpers[helperId]
					local levelInfo = level and def.Levels[level]
					if levelInfo and now >= (state.NextRun[helperId] or 0) then
						state.NextRun[helperId] = now + levelInfo.Interval / HelperService:GetSpeedMultiplier(player)
						local ok, err = pcall(runHelper, state, helperId, levelInfo)
						if not ok then
							warn("[HelperService] Erreur pendant la tournée : " .. tostring(err))
						end
					end
				end
			end
		end
	end)
end

return HelperService
