--[[
	AnimalController.lua
	====================
	Animations purement visuelles des animaux, calculées par le client (aucun
	trafic réseau, aucun effet sur le gameplay) :
	  • les modèles tagués "FarmAnimal" (animaux de ferme et créatures sauvages)
	    se promènent au hasard autour de leur point d'origine (attributs
	    WanderCenter / WanderRadius posés par le serveur ; arrêt si "Frozen") ;
	  • leurs pièces articulées (attribut Anim posé par AnimalBuilder / CreatureBuilder)
	    bougent : pattes qui marchent pendant les déplacements, tête qui hoche,
	    queue qui remue, ailes qui battent, petit rebond de respiration ("Breathe") ;
	  • les parts taguées "RainbowPart" changent de couleur en continu
	    (variantes Arc-en-ciel et Mythique) ;
	  • les modèles tagués "DisplaySpin" (socles, vitrine) tournent doucement sur eux-mêmes.
	Les animaux loin de la caméra ne sont pas animés (performance).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local AnimalController = {}

local ANIMAL_TAG = "FarmAnimal"
local RAINBOW_TAG = "RainbowPart"
local SPIN_TAG = "DisplaySpin" -- créatures exposées sur un socle / dans la vitrine
local SPIN_SPEED = 0.6 -- radians par seconde
local WALK_SPEED = 3 -- studs par seconde
local ANIM_DISTANCE = 110 -- au-delà, pas d'animation des membres

-- Jeton par modèle : si le modèle sort puis revient (streaming), l'ancienne boucle s'arrête
local wandering: { [Model]: {} } = {}
local walking: { [Model]: boolean } = {}

type Joint = { Part: BasePart, Local: CFrame, Kind: string, Phase: number, Hinge: Vector3 }
type Rig = { Joints: { Joint }, Seed: number, Hop: boolean, Flyer: boolean, Scale: number }
local rigs: { [Model]: Rig } = {}

--------------------------------------------------------------------------
-- Articulations
--------------------------------------------------------------------------

local function buildRig(model: Model)
	local pivot = model:GetPivot()
	local scale = model:GetAttribute("RigScale") or 1 -- les articulations suivent la taille appliquée
	local joints = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local kind = d:GetAttribute("Anim")
			if type(kind) == "string" then
				local hinge = d:GetAttribute("Hinge")
				table.insert(joints, {
					Part = d,
					Local = pivot:ToObjectSpace(d.CFrame),
					Kind = kind,
					Phase = d:GetAttribute("Phase") or 0,
					Hinge = if typeof(hinge) == "Vector3" then hinge * scale else Vector3.zero,
				})
			end
		end
	end
	if #joints > 0 then
		rigs[model] = {
			Joints = joints,
			Seed = math.random() * 10,
			Hop = model:GetAttribute("Hop") == true,
			Flyer = model:GetAttribute("Flyer") == true,
			Scale = scale,
		}
	end
end

-- Angle de chaque type de pièce selon le temps et la marche
local function jointRotation(kind: string, t: number, phase: number, seed: number, isWalking: boolean, flyer: boolean): CFrame
	if kind == "Leg" or kind == "Arm" then
		return if isWalking then CFrame.Angles(math.sin(t * 9 + phase) * 0.55, 0, 0) else CFrame.identity
	elseif kind == "Head" then
		local nod = if isWalking then math.sin(t * 9) * 0.06 else math.sin(t * 1.3 + seed) * 0.09
		return CFrame.Angles(nod, math.sin(t * 0.5 + seed) * 0.12, 0)
	elseif kind == "Tail" then
		return CFrame.Angles(0, math.sin(t * (if isWalking then 7 else 3.5) + seed) * 0.35, 0)
	elseif kind == "Wing" then
		local flap
		if flyer then
			flap = math.sin(t * 11 + seed) * 0.45 -- les volants battent des ailes sans arrêt
		elseif isWalking then
			flap = math.abs(math.sin(t * 12)) * 0.5
		else
			flap = math.max(0, math.sin(t * 0.8 + seed) - 0.85) * 2.5
		end
		return CFrame.Angles(0, 0, -phase * flap)
	elseif kind == "Breathe" then
		return CFrame.identity -- traité à part (translation)
	end
	return CFrame.identity
end

local function animate(t: number)
	local camera = Workspace.CurrentCamera
	local cameraPos = if camera then camera.CFrame.Position else Vector3.zero
	local parts, cframes = {}, {}
	for model, rig in rigs do
		if not model.Parent then
			rigs[model] = nil
			continue
		end
		local pivot = model:GetPivot()
		if (pivot.Position - cameraPos).Magnitude > ANIM_DISTANCE then
			continue
		end
		local isWalking = walking[model] == true and not model:GetAttribute("Frozen")
		-- Petit rebond quand l'animal marche (ou sautille pour les créatures "Hop")
		local bounce = if isWalking then math.abs(math.sin(t * 9)) * (if rig.Hop then 0.6 else 0.12) * rig.Scale else 0
		if rig.Flyer then
			bounce = math.sin(t * 2 + rig.Seed) * 0.35 * rig.Scale -- vol stationnaire
		end
		for _, joint in rig.Joints do
			local localCf = joint.Local
			if joint.Kind == "Breathe" then
				localCf = CFrame.new(0, math.sin(t * 2 + rig.Seed) * 0.05 * rig.Scale + bounce, 0) * localCf
			else
				local rotation = jointRotation(joint.Kind, t, joint.Phase, rig.Seed, isWalking, rig.Flyer)
				local hingePos = localCf.Position + joint.Hinge
				localCf = CFrame.new(0, bounce, 0) * CFrame.new(hingePos) * rotation * CFrame.new(-hingePos) * localCf
			end
			table.insert(parts, joint.Part)
			table.insert(cframes, pivot * localCf)
		end
	end
	if #parts > 0 then
		Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

--------------------------------------------------------------------------
-- Promenade
--------------------------------------------------------------------------

-- Hauteur du sol sous un point (rayon vertical qui ignore les animaux et les joueurs)
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local function groundHeight(position: Vector3, fallback: number): number
	local exclude = CollectionService:GetTagged(ANIMAL_TAG)
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(exclude, other.Character)
		end
	end
	rayParams.FilterDescendantsInstances = exclude
	local hit = Workspace:Raycast(Vector3.new(position.X, fallback + 12, position.Z), Vector3.new(0, -40, 0), rayParams)
	return if hit then hit.Position.Y else fallback
end

-- Boucle de promenade d'UN animal : pause, puis marche vers un point au hasard.
local function wander(model: Model)
	if wandering[model] then
		return
	end
	local token = {}
	wandering[model] = token
	task.defer(buildRig, model) -- attend que tout le modèle soit répliqué

	task.spawn(function()
		local driver = Instance.new("CFrameValue")
		driver.Changed:Connect(function(value)
			if model.Parent then
				model:PivotTo(value)
			end
		end)

		while model.Parent and wandering[model] == token do
			task.wait(2 + math.random() * 4)
			local center = model:GetAttribute("WanderCenter")
			local radius = model:GetAttribute("WanderRadius")
			if not model.Parent or typeof(center) ~= "Vector3" or type(radius) ~= "number" then
				continue
			end
			if model:GetAttribute("Frozen") then
				continue -- créature en cours de capture : elle ne bouge plus
			end

			local from = model:GetPivot()
			local angle = math.random() * math.pi * 2
			local distance = math.random() * radius
			local target = Vector3.new(center.X + math.cos(angle) * distance, from.Position.Y, center.Z + math.sin(angle) * distance)
			-- Le pivot est sous les pieds : on suit le VRAI sol à destination (bosses, Terrain...)
			local groundY = groundHeight(target, from.Position.Y)
			target = Vector3.new(target.X, groundY, target.Z)
			local travel = (target - from.Position).Magnitude
			if travel < 0.5 then
				continue
			end

			-- On se tourne vers la destination (la tête est vers -Z = LookVector), puis on avance
			-- (direction à plat : l'animal reste droit même si le sol monte ou descend)
			local flat = Vector3.new(target.X - from.Position.X, 0, target.Z - from.Position.Z)
			if flat.Magnitude < 0.1 then
				continue
			end
			local goal = CFrame.lookAt(target, target + flat.Unit)
			driver.Value = CFrame.lookAt(from.Position, from.Position + flat.Unit)
			local tween = TweenService:Create(driver, TweenInfo.new(travel / WALK_SPEED, Enum.EasingStyle.Linear), { Value = goal })
			walking[model] = true
			tween:Play()
			tween.Completed:Wait()
			walking[model] = nil
		end

		driver:Destroy()
		if wandering[model] == token then
			wandering[model] = nil
		end
	end)
end

function AnimalController.Init()
	for _, model in CollectionService:GetTagged(ANIMAL_TAG) do
		if model:IsA("Model") then
			wander(model)
		end
	end
	CollectionService:GetInstanceAddedSignal(ANIMAL_TAG):Connect(function(model)
		if model:IsA("Model") then
			wander(model)
		end
	end)
	CollectionService:GetInstanceRemovedSignal(ANIMAL_TAG):Connect(function(model)
		wandering[model] = nil
		walking[model] = nil
		rigs[model] = nil
	end)

	-- Rotation lente des créatures exposées
	RunService.RenderStepped:Connect(function(dt)
		for _, model in CollectionService:GetTagged(SPIN_TAG) do
			if model:IsA("Model") and model.PrimaryPart then
				model:PivotTo(model:GetPivot() * CFrame.Angles(0, dt * SPIN_SPEED, 0))
			end
		end
		animate(os.clock())
	end)

	-- Couleurs arc-en-ciel animées
	RunService.Heartbeat:Connect(function()
		local t = os.clock() * 0.25
		for _, part in CollectionService:GetTagged(RAINBOW_TAG) do
			if part:IsA("BasePart") then
				local offset = part:GetAttribute("HueOffset") or 0
				part.Color = Color3.fromHSV((t + offset) % 1, 0.75, 1)
			end
		end
	end)
end

return AnimalController
