--[[
	PlacementUtil.lua  (ReplicatedStorage.Shared.PlacementUtil)
	===========================================================
	Règles de placement du mode construction, partagées client/serveur :
	le client s'en sert pour colorer l'aperçu (vert / rouge), le serveur pour
	VALIDER (c'est lui qui a le dernier mot).

	Coordonnées LOCALES de parcelle :
	  X = gauche/droite depuis le milieu de l'entrée, Z = profondeur (vers l'intérieur).
	  Rot = 0, 1, 2 ou 3 quarts de tour.
	Un élément placé = { Type = "Field" | "Pen" | "Building" | "Pedestal", Id, Kind, X, Z, Rot }
	(Kind = id du bâtiment pour "Building").
]]

local Config = require(script.Parent.Config)

local PlacementUtil = {}

local Build = Config.Build

PlacementUtil.Types = { "Field", "Pen", "Building", "Pedestal" }

-- Emprise (largeur X, profondeur Z) à la rotation 0
function PlacementUtil.Footprint(placeType: string, kind: string?): (number, number)
	if placeType == "Field" then
		return Config.Farm.FieldFootprint.X, Config.Farm.FieldFootprint.Y
	elseif placeType == "Pen" then
		return Config.Pens.Footprint.X, Config.Pens.Footprint.Y
	elseif placeType == "Pedestal" then
		return Config.Display.PedestalFootprint.X, Config.Display.PedestalFootprint.Y
	elseif placeType == "Building" then
		local def = kind and Config.Buildings[kind]
		if def then
			return def.Width + Build.BuildingMargin.X, def.Depth + Build.BuildingMargin.Y
		end
	end
	return 0, 0
end

-- Rectangle occupé (minX, maxX, minZ, maxZ). Les quarts de tour impairs échangent largeur et profondeur.
function PlacementUtil.Rect(placeType: string, kind: string?, x: number, z: number, rot: number): (number, number, number, number)
	local w, d = PlacementUtil.Footprint(placeType, kind)
	if rot % 2 == 1 then
		w, d = d, w
	end
	return x - w / 2, x + w / 2, z - d / 2, z + d / 2
end

-- Zone autorisée pour un niveau de parcelle (sans la bande d'entrée)
function PlacementUtil.Bounds(level: number): (number, number, number, number)
	local expansion = Config.Plots.Expansions[math.clamp(level, 1, #Config.Plots.Expansions)]
	local margin = Build.EdgeMargin
	return -expansion.Width / 2 + margin, expansion.Width / 2 - margin, Build.EntranceDepth, expansion.Depth - margin
end

function PlacementUtil.Snap(value: number): number
	return math.floor(value / Build.Grid + 0.5) * Build.Grid
end

-- CFrame de l'élément RELATIF à l'origine de la parcelle
function PlacementUtil.LocalCFrame(x: number, z: number, rot: number): CFrame
	return CFrame.new(x, 0, z) * CFrame.Angles(0, rot * math.pi / 2, 0)
end

-- Liste des éléments POSÉS à partir des données du joueur
function PlacementUtil.Collect(data: { [string]: any }): { { [string]: any } }
	local list = {}
	local function add(placeType: string, tableData: any)
		if type(tableData) ~= "table" then
			return
		end
		for id, record in tableData do
			if type(record) == "table" and record.Placed and type(record.X) == "number" and type(record.Z) == "number" then
				table.insert(list, {
					Type = placeType,
					Id = id,
					Kind = if placeType == "Building" then id else nil,
					X = record.X,
					Z = record.Z,
					Rot = record.Rot or 0,
				})
			end
		end
	end
	add("Field", data.Fields)
	add("Pen", data.Pens)
	add("Building", data.Buildings)
	add("Pedestal", data.Pedestals)
	return list
end

--------------------------------------------------------------------------
-- Façade de la parcelle (suit l'agrandissement) : vitrine et panneau devant, entrée libre
--------------------------------------------------------------------------

-- DEVANT la parcelle (côté allée, z < 0), de part et d'autre de l'entrée qui reste libre :
-- vitrine d'un côté, panneau du propriétaire de l'autre (Config.Showcase.Side). Chacun est
-- centré dans la moitié de façade comprise entre le portail et le coin de la clôture : il suit
-- donc l'agrandissement. Rien de tout ça n'est DANS la parcelle : la zone constructible est entière.
local function frontCenterX(level: number): number
	local expansion = Config.Plots.Expansions[math.clamp(level, 1, #Config.Plots.Expansions)]
	return (Config.Plots.GateWidth / 2 + expansion.Width / 2) / 2
end

-- Positions locales (x, z) des socles de la vitrine de prestige, alignés face à l'allée
function PlacementUtil.ShowcaseSpots(level: number): { Vector2 }
	local show = Config.Showcase
	local center = show.Side * frontCenterX(level)
	local spots = {}
	for i = 1, show.Slots do
		-- Du côté de l'entrée vers le coin de la clôture
		local offset = (i - (show.Slots + 1) / 2) * show.Spacing
		table.insert(spots, Vector2.new(center + show.Side * offset, -show.FrontDistance))
	end
	return spots
end

-- Position locale (x, z) du centre du panneau du propriétaire (côté opposé à la vitrine)
function PlacementUtil.SignSpot(level: number): Vector2
	local show = Config.Showcase
	return Vector2.new(-show.Side * frontCenterX(level), -show.SignDistance)
end

-- Vérifie un placement. candidate = { Type, Id?, Kind?, X, Z, Rot }.
-- Renvoie (true) ou (false, raison). L'élément d'id candidate.Id est ignoré (déplacement).
function PlacementUtil.Check(level: number, placed: { { [string]: any } }, candidate: { [string]: any }): (boolean, string?)
	local w = PlacementUtil.Footprint(candidate.Type, candidate.Kind)
	if w <= 0 then
		return false, "Élément inconnu."
	end
	if candidate.Rot ~= 0 and candidate.Rot ~= 1 and candidate.Rot ~= 2 and candidate.Rot ~= 3 then
		return false, "Rotation invalide."
	end

	local minX, maxX, minZ, maxZ = PlacementUtil.Rect(candidate.Type, candidate.Kind, candidate.X, candidate.Z, candidate.Rot)
	local bMinX, bMaxX, bMinZ, bMaxZ = PlacementUtil.Bounds(level)
	if minX < bMinX or maxX > bMaxX or maxZ > bMaxZ then
		return false, "Dépasse de ta parcelle : rapproche-le du centre (ou agrandis ta parcelle)."
	end
	if minZ < bMinZ then
		return false, "Trop près de l'entrée (la bande des boutons au sol doit rester libre) : recule-le."
	end

	for _, other in placed do
		local same = other.Type == candidate.Type and other.Id == candidate.Id
		if not same then
			local oMinX, oMaxX, oMinZ, oMaxZ = PlacementUtil.Rect(other.Type, other.Kind, other.X, other.Z, other.Rot)
			-- Chevauchement strict (des bords qui se touchent sont autorisés)
			if minX < oMaxX and maxX > oMinX and minZ < oMaxZ and maxZ > oMinZ then
				return false, ("Ça chevauche : %s. Décale-le un peu."):format(PlacementUtil.Label(other.Type, other.Kind))
			end
		end
	end
	return true, nil
end

-- Libellé d'un élément pour l'interface
function PlacementUtil.Label(placeType: string, kind: string?): string
	if placeType == "Field" then
		return "🌱 Champ"
	elseif placeType == "Pen" then
		return "🐾 Enclos"
	elseif placeType == "Pedestal" then
		return "🏛️ Socle d'exposition"
	elseif placeType == "Building" and kind and Config.Buildings[kind] then
		local def = Config.Buildings[kind]
		return def.Icon .. " " .. def.DisplayName
	end
	return placeType
end

return PlacementUtil
