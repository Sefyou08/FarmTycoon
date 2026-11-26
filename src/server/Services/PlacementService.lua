--[[
	PlacementService.lua
	====================
	Mode construction : acheter + placer, déplacer, ranger et replacer les
	éléments de la parcelle (champs, enclos, bâtiments ; socles en phase 6).

	Le client envoie ses demandes par la RemoteFunction "BuildAction" :
	  ("Buy",   { Type, Kind?, X, Z, Rot })  -> achète un nouvel élément et le pose
	  ("Place", { Type, Id, X, Z, Rot })     -> déplace un élément posé, ou repose un élément rangé
	  ("Store", { Type, Id })                -> range un élément (il disparaît de la parcelle)

	Le SERVEUR vérifie tout (PlacementUtil.Check) :
	  - arguments (types, nombres finis, rotation 0..3), cooldown ;
	  - c'est bien SA parcelle (données chargées, parcelle prête) ;
	  - dans les limites du niveau actuel, hors de la bande d'entrée ;
	  - pas de chevauchement avec un autre élément posé ;
	  - Coins et conditions d'achat (FarmService / AnimalService / BuildingService).
	Seules les positions changent : plantes, animaux, rations, files et stocks
	restent dans les données ; les services reconstruisent juste les visuels.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local PlacementUtil = require(ReplicatedStorage.Shared.PlacementUtil)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RemoteGuard = require(script.Parent.Parent.Util.RemoteGuard)
local DataService = require(script.Parent.DataService)
local CurrencyService = require(script.Parent.CurrencyService)
local PlotService = require(script.Parent.PlotService)
local FarmService = require(script.Parent.FarmService)
local AnimalService = require(script.Parent.AnimalService)
local BuildingService = require(script.Parent.BuildingService)

local PlacementService = {}

local MAX_COORD = 400 -- garde-fou contre les valeurs absurdes

-- Table de données correspondant à un type d'élément
local function recordsFor(data: { [string]: any }, placeType: string): { [string]: any }?
	if placeType == "Field" then
		return data.Fields
	elseif placeType == "Pen" then
		return data.Pens
	elseif placeType == "Building" then
		return data.Buildings
	end
	return nil
end

local function refresh(player: Player, placeType: string, id: string)
	if placeType == "Field" then
		FarmService:RefreshField(player, id)
	elseif placeType == "Pen" then
		AnimalService:RefreshPen(player, id)
	elseif placeType == "Building" then
		BuildingService:Refresh(player, id)
	end
end

-- Lit et valide la position envoyée par le client. Renvoie (x, z, rot) arrondis, ou nil.
local function readPosition(payload: { [string]: any }): (number?, number?, number?)
	local x, z, rot = payload.X, payload.Z, payload.Rot
	if not RemoteGuard.IsValidNumber(x, -MAX_COORD, MAX_COORD) or not RemoteGuard.IsValidNumber(z, -MAX_COORD, MAX_COORD) then
		return nil, nil, nil
	end
	if not RemoteGuard.IsValidNumber(rot, 0, 3, true) then
		return nil, nil, nil
	end
	return PlacementUtil.Snap(x), PlacementUtil.Snap(z), rot
end

local function checkSpot(player: Player, data: { [string]: any }, candidate: { [string]: any }): (boolean, string?)
	return PlacementUtil.Check(PlotService:GetLevel(player), PlacementUtil.Collect(data), candidate)
end

local function actionBuy(player: Player, data: { [string]: any }, payload: { [string]: any }): (boolean, string)
	local placeType, kind = payload.Type, payload.Kind
	local x, z, rot = readPosition(payload)
	if not x then
		return false, "Position invalide."
	end
	if placeType == "Building" and (type(kind) ~= "string" or not Config.Buildings[kind]) then
		return false, "Bâtiment inconnu."
	end

	-- 1. Conditions d'achat et prix (selon le type)
	local price, reason
	if placeType == "Field" then
		price, reason = FarmService:CanBuyField(player)
	elseif placeType == "Pen" then
		price, reason = AnimalService:CanBuyPen(player)
	elseif placeType == "Building" then
		price, reason = BuildingService:CanBuy(player, kind)
	else
		return false, "Type inconnu."
	end
	if not price then
		return false, reason or "Achat impossible."
	end

	-- 2. Emplacement (vérifié AVANT de faire payer)
	local ok, spotReason = checkSpot(player, data, {
		Type = placeType,
		Kind = if placeType == "Building" then kind else nil,
		X = x,
		Z = z,
		Rot = rot,
	})
	if not ok then
		return false, spotReason or "Emplacement invalide."
	end

	-- 3. Paiement puis création
	if price > 0 and not CurrencyService:SpendCoins(player, price, "BuildBuy:" .. placeType .. (if kind then ":" .. kind else "")) then
		return false, ("Il te faut %s Coins."):format(Format.Number(price))
	end
	if placeType == "Field" then
		FarmService:CreateField(player, x, z, rot)
		return true, "🌱 Champ placé ! Débloque ses cases avec E."
	elseif placeType == "Pen" then
		AnimalService:CreatePen(player, x, z, rot)
		return true, "🐾 Enclos placé !"
	end
	BuildingService:Create(player, kind, x, z, rot)
	return true, PlacementUtil.Label("Building", kind) .. " placé(e) !"
end

local function actionPlace(player: Player, data: { [string]: any }, payload: { [string]: any }): (boolean, string)
	local placeType, id = payload.Type, payload.Id
	local records = recordsFor(data, placeType)
	local record = records and type(id) == "string" and records[id]
	if not record then
		return false, "Élément introuvable."
	end
	local x, z, rot = readPosition(payload)
	if not x then
		return false, "Position invalide."
	end
	local ok, reason = checkSpot(player, data, {
		Type = placeType,
		Id = id,
		Kind = if placeType == "Building" then id else nil,
		X = x,
		Z = z,
		Rot = rot,
	})
	if not ok then
		return false, reason or "Emplacement invalide."
	end
	record.X, record.Z, record.Rot, record.Placed = x, z, rot, true
	refresh(player, placeType, id)
	return true, PlacementUtil.Label(placeType, if placeType == "Building" then id else nil) .. " déplacé(e)."
end

local function actionStore(player: Player, data: { [string]: any }, payload: { [string]: any }): (boolean, string)
	local placeType, id = payload.Type, payload.Id
	local records = recordsFor(data, placeType)
	local record = records and type(id) == "string" and records[id]
	if not record or not record.Placed then
		return false, "Élément introuvable."
	end
	record.Placed = false
	refresh(player, placeType, id)
	return true, "📦 Rangé ! Tu peux le replacer depuis le menu 🔨 Construire."
end

local function onBuildAction(player: Player, action: any, payload: any): (boolean, string)
	if type(action) ~= "string" or type(payload) ~= "table" or type(payload.Type) ~= "string" then
		return false, "Requête invalide."
	end
	if not RemoteGuard.CheckCooldown(player, "BuildAction", Config.Build.ActionCooldown) then
		return false, "Doucement !"
	end
	local data = DataService:GetData(player)
	if not data or not PlotService:GetPlot(player) then
		return false, "Ta parcelle n'est pas encore prête."
	end

	if action == "Buy" then
		return actionBuy(player, data, payload)
	elseif action == "Place" then
		return actionPlace(player, data, payload)
	elseif action == "Store" then
		return actionStore(player, data, payload)
	end
	return false, "Action inconnue."
end

function PlacementService:Init() end

function PlacementService:Start()
	Remotes.Get("BuildAction").OnServerInvoke = onBuildAction
end

return PlacementService
