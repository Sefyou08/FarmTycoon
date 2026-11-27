--[[
	ArtKit.lua
	==========
	Boîte à outils commune à tous les modèles générés (phase 10) :
	  • petites fonctions pour créer des Parts « cartoon » (bloc, boule, cylindre
	    vertical, coin, triangle) déjà ancrées, lisses, sans collision par défaut ;
	  • la BIBLIOTHÈQUE DE MODÈLES DE REMPLACEMENT (Toolbox / MeshPart importé).

	REMPLACER UN MODÈLE GÉNÉRÉ PAR UN MODÈLE À TOI
	  ServerStorage
	    └ CustomModels (Folder)
	        ├ Creatures (Folder) : Model nommé comme l'id de la créature (ex. "Pharaonix")
	        ├ Animals   (Folder) : Model nommé comme l'espèce (ex. "Cow", "Chicken", "Horse")
	        ├ Buildings (Folder) : Model nommé comme le bâtiment (ex. "Bakery", "Dairy")
	        ├ Stands    (Folder) : "SeedShop", "SellStand", "AnimalShop"
	        ├ Crops     (Folder) : Model nommé comme la culture (ex. "Carrot") : utilisé pour les 3 stades
	        ├ Helpers   (Folder) : "Farmer", "Caretaker", "Artisan"
	        ├ Merchants (Folder) : "SeedShop", "SellStand", "AnimalShop" (ou "Merchant" pour tous)
	        ├ Props     (Folder) : "Pedestal", "ShowcaseBase", "ExpeditionPortal", "ReturnPortal",
	        │                      "DungeonPortal", "Trough", "Crate"
	        ├ Scenery   (Folder) : "Tree", "Pine", "Bush", "Rock", "Flower", "Bridge", "Lantern"
	        ├ Enemies   → dans ReplicatedStorage.CustomModels.Enemies (dessinés par le client)
	        └ Mascot    (Folder) : "Biscotte"
	  Le jeu s'occupe de tout : il SUPPRIME les scripts (sécurité), ancre les pièces, enlève les
	  collisions, met le modèle à la bonne taille, le centre et le pose sur le sol. Le modèle doit
	  regarder vers -Z (son avant) ; sinon, ajoute-lui un attribut nombre "YawOffset" (degrés,
	  ex. 90 ou 180) pour le tourner. S'il est couché, "PitchOffset" (bascule avant/arrière,
	  axe X) et "RollOffset" (bascule sur le côté, axe Z), en degrés, le redressent.
	  Tout le gameplay reste identique.
]]

local ServerStorage = game:GetService("ServerStorage")

local ArtKit = {}

local DEFAULTS = {
	Anchored = true,
	CanCollide = false,
	CanTouch = false,
	CanQuery = false,
	TopSurface = Enum.SurfaceType.Smooth,
	BottomSurface = Enum.SurfaceType.Smooth,
	Material = Enum.Material.SmoothPlastic,
}

-- Part générique : props = propriétés Roblox (Size, CFrame, Color, Material, Parent...)
function ArtKit.Part(props: { [string]: any }, className: string?): BasePart
	local part = Instance.new(className or "Part") :: any
	for key, value in DEFAULTS do
		if props[key] == nil then
			part[key] = value
		end
	end
	local parent = props.Parent
	for key, value in props do
		if key ~= "Parent" then
			part[key] = value
		end
	end
	part.Parent = parent
	return part
end

-- Bloc
function ArtKit.Block(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, extra: { [string]: any }?): BasePart
	local props = { Name = name, Size = size, CFrame = cframe, Color = color, Material = material or Enum.Material.SmoothPlastic, Parent = parent }
	if extra then
		for k, v in extra do
			props[k] = v
		end
	end
	return ArtKit.Part(props)
end

-- Boule (size = diamètre en X, Y, Z ; une Part Ball reste ronde : on garde le plus petit côté)
function ArtKit.Ball(parent: Instance, name: string, diameter: number, cframe: CFrame, color: Color3, material: Enum.Material?, extra: { [string]: any }?): BasePart
	local props = { Name = name, Shape = Enum.PartType.Ball, Size = Vector3.one * diameter, CFrame = cframe, Color = color, Material = material or Enum.Material.SmoothPlastic, Parent = parent }
	if extra then
		for k, v in extra do
			props[k] = v
		end
	end
	return ArtKit.Part(props)
end

-- Ellipsoïde (boule étirée : une Part Block avec un SpecialMesh "Sphere")
function ArtKit.Ellipsoid(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, extra: { [string]: any }?): BasePart
	local part = ArtKit.Block(parent, name, size, cframe, color, material, extra)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

-- Cylindre VERTICAL (axe Y) : cframe = centre
function ArtKit.Cylinder(parent: Instance, name: string, height: number, diameter: number, cframe: CFrame, color: Color3, material: Enum.Material?, extra: { [string]: any }?): BasePart
	local props = {
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = cframe * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		Parent = parent,
	}
	if extra then
		for k, v in extra do
			props[k] = v
		end
	end
	return ArtKit.Part(props)
end

-- Cylindre HORIZONTAL (axe X local) : roues, rouleaux, meules
function ArtKit.Disc(parent: Instance, name: string, thickness: number, diameter: number, cframe: CFrame, color: Color3, material: Enum.Material?, extra: { [string]: any }?): BasePart
	local props = { Name = name, Shape = Enum.PartType.Cylinder, Size = Vector3.new(thickness, diameter, diameter), CFrame = cframe, Color = color, Material = material or Enum.Material.SmoothPlastic, Parent = parent }
	if extra then
		for k, v in extra do
			props[k] = v
		end
	end
	return ArtKit.Part(props)
end

-- Coin (WedgePart) : fin à l'avant (-Z), pleine hauteur à l'arrière (+Z)
function ArtKit.Wedge(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, extra: { [string]: any }?): BasePart
	local props = { Name = name, Size = size, CFrame = cframe, Color = color, Material = material or Enum.Material.SmoothPlastic, Parent = parent }
	if extra then
		for k, v in extra do
			props[k] = v
		end
	end
	return ArtKit.Part(props, "WedgePart")
end

-- Triangle isocèle debout (oreilles, toits pointus, flammes) : base en bas, pointe en haut.
-- width = largeur de la base, height = hauteur, depth = épaisseur
function ArtKit.Triangle(parent: Instance, name: string, width: number, height: number, depth: number, cframe: CFrame, color: Color3, material: Enum.Material?, extra: { [string]: any }?)
	local half = width / 2
	-- Deux coins dos à dos (chaque coin = moitié du triangle)
	local left = ArtKit.Wedge(parent, name, Vector3.new(depth, height, half), cframe * CFrame.new(-half / 2, 0, 0) * CFrame.Angles(0, math.rad(90), 0), color, material, extra)
	local right = ArtKit.Wedge(parent, name, Vector3.new(depth, height, half), cframe * CFrame.new(half / 2, 0, 0) * CFrame.Angles(0, math.rad(-90), 0), color, material, extra)
	return left, right
end

-- Toit à deux pentes (deux coins) : cframe = centre du bas du toit, regarde -Z
function ArtKit.Roof(parent: Instance, name: string, width: number, height: number, depth: number, cframe: CFrame, color: Color3, material: Enum.Material?)
	local half = width / 2
	ArtKit.Wedge(parent, name, Vector3.new(depth, height, half), cframe * CFrame.new(-half / 2, height / 2, 0) * CFrame.Angles(0, math.rad(90), 0), color, material)
	ArtKit.Wedge(parent, name, Vector3.new(depth, height, half), cframe * CFrame.new(half / 2, height / 2, 0) * CFrame.Angles(0, math.rad(-90), 0), color, material)
end

-- Rend tout un modèle "décor" : sans collision ni requête (ombres conservées)
function ArtKit.MakeDecor(model: Instance)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
		end
	end
end

-- Couleur plus foncée / plus claire
function ArtKit.Darker(color: Color3, amount: number?): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount or 0.25)
end

function ArtKit.Lighter(color: Color3, amount: number?): Color3
	return color:Lerp(Color3.new(1, 1, 1), amount or 0.25)
end

-- Lumière ponctuelle
function ArtKit.Light(parent: Instance, color: Color3, range: number, brightness: number?): PointLight
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness or 1.5
	light.Parent = parent
	return light
end

-- Particules simples
function ArtKit.Particles(parent: Instance, props: { [string]: any }): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter") :: any
	emitter.LightEmission = 0.6
	emitter.Lifetime = NumberRange.new(1, 2)
	emitter.Speed = NumberRange.new(0.5, 1.5)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new(0.4, 0)
	for k, v in props do
		emitter[k] = v
	end
	emitter.Parent = parent
	return emitter
end

-- Pose un modèle bien SUR le sol : la pièce la plus basse touche groundCFrame (+ lift).
-- Corrige les pattes / sabots qui s'enfonçaient. groundCFrame doit être droit (axe Y vers le haut).
function ArtKit.SnapToGround(model: Model, groundCFrame: CFrame, lift: number?)
	local primary = model.PrimaryPart
	local pivot = model:GetPivot()
	model.PrimaryPart = nil
	model.WorldPivot = CFrame.new(pivot.Position) * groundCFrame.Rotation -- boîte alignée sur le sol
	local cf, size = model:GetBoundingBox()
	model.PrimaryPart = primary
	local bottom = groundCFrame:PointToObjectSpace(cf.Position).Y - size.Y / 2
	local delta = (lift or 0.02) - bottom
	if math.abs(delta) > 0.005 then
		model:PivotTo(model:GetPivot() + groundCFrame.UpVector * delta)
	end
end

--------------------------------------------------------------------------
-- Bibliothèque de modèles de remplacement
--------------------------------------------------------------------------

-- Renvoie un CLONE de ServerStorage.CustomModels.<category>.<id>, ou nil
-- Sécurité : un modèle importé ne doit contenir AUCUN code (Script, LocalScript, ModuleScript),
-- ni Humanoid (barre de vie / nom au-dessus du modèle)
function ArtKit.Sanitize(model: Instance)
	for _, d in model:GetDescendants() do
		if d:IsA("LuaSourceContainer") or d:IsA("Humanoid") or d:IsA("ProximityPrompt") or d:IsA("ClickDetector") then
			d:Destroy()
		end
	end
end

-- Renvoie un CLONE nettoyé de ServerStorage.CustomModels.<category>.<id>, ou nil
function ArtKit.Custom(category: string, id: string): Model?
	local root = ServerStorage:FindFirstChild("CustomModels")
	local folder = root and root:FindFirstChild(category)
	local template = folder and folder:FindFirstChild(id)
	if template and template:IsA("Model") then
		local clone = template:Clone()
		clone.Name = id
		ArtKit.Sanitize(clone)
		if not clone.PrimaryPart then
			clone.PrimaryPart = clone:FindFirstChildWhichIsA("BasePart", true)
		end
		return clone
	end
	return nil
end

-- Correction d'orientation d'un modèle importé, lue sur ses attributs (en degrés) :
--   YawOffset   : tourne autour de la verticale (avant du modèle vers -Z)
--   PitchOffset : bascule avant/arrière (axe X) — pour un modèle couché sur le dos ou le ventre
--   RollOffset  : bascule sur le côté (axe Z) — pour un modèle couché sur le flanc
-- Ordre : d'abord on redresse (pitch, puis roll), ensuite on tourne (yaw).
function ArtKit.OrientOffset(model: Instance): CFrame
	local function deg(name: string): number
		return math.rad(tonumber(model:GetAttribute(name)) or 0)
	end
	return CFrame.Angles(0, deg("YawOffset"), 0) * CFrame.Angles(deg("PitchOffset"), 0, 0) * CFrame.Angles(0, 0, deg("RollOffset"))
end

-- Prépare un modèle importé : ancré, sans collision, tourné et redressé (-Z = avant ; attributs
-- facultatifs "YawOffset", "PitchOffset", "RollOffset" en degrés, voir OrientOffset), mis à la taille voulue (targetSize =
-- plus grande dimension, en studs), centré sur groundCFrame et posé sur le sol.
function ArtKit.PlaceCustom(model: Model, groundCFrame: CFrame, anchored: boolean?, targetSize: number?)
	local primary = model.PrimaryPart
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = anchored ~= false
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = d == primary
		end
	end
	model:PivotTo(groundCFrame * ArtKit.OrientOffset(model))
	if targetSize and targetSize > 0 then
		local extents = model:GetExtentsSize()
		local biggest = math.max(extents.X, extents.Y, extents.Z)
		if biggest > 0.01 then
			model:ScaleTo(model:GetScale() * targetSize / biggest)
		end
	end
	-- Centre horizontal sur le point voulu, puis pieds au sol
	local cf = model:GetBoundingBox()
	local offset = groundCFrame:PointToObjectSpace(cf.Position)
	model:PivotTo(model:GetPivot() - groundCFrame:VectorToWorldSpace(Vector3.new(offset.X, 0, offset.Z)))
	ArtKit.SnapToGround(model, groundCFrame)
end
-- Remplace un élément généré par un modèle importé, SANS casser le gameplay :
-- les pièces générées (generated : liste d'Instances) deviennent invisibles mais gardent
-- leurs collisions, prompts, panneaux, lumières et particules ; le modèle importé est ajouté
-- par-dessus, préparé par PlaceCustom. Renvoie le modèle importé, ou nil s'il n'y en a pas.
function ArtKit.Swap(category: string, id: string, generated: { Instance }, parent: Instance, groundCFrame: CFrame, targetSize: number): Model?
	local custom = ArtKit.Custom(category, id)
	if not custom then
		return nil
	end
	for _, root in generated do
		local list = root:GetDescendants()
		table.insert(list, root)
		for _, d in list do
			if d:IsA("BasePart") then
				d.Transparency = 1
				d.CastShadow = false
			elseif d:IsA("Decal") or d:IsA("Texture") then
				d.Transparency = 1
			elseif d:IsA("SurfaceGui") then
				d.Enabled = false
			end
		end
	end
	ArtKit.PlaceCustom(custom, groundCFrame, true, targetSize)
	custom.Parent = parent
	return custom
end

-- Haut d'un modèle (repère au sommet de sa boîte englobante), pour y accrocher de la fumée
function ArtKit.TopOf(model: Model): CFrame
	local cf, size = model:GetBoundingBox()
	return cf * CFrame.new(0, size.Y / 2, 0)
end

return ArtKit
