--[[
	DungeonRenderer.lua
	===================
	Dessine et anime les ennemis du donjon CÔTÉ CLIENT.
	Le serveur n'envoie que des données (RemoteEvent "DungeonEnemies", 10 fois/s) :
	  { id, clé, x, z, orientation, PV, état } par ennemi + une liste d'événements
	  ("Hit", "Death", "Attack", "SlamStart", "SlamHit", "PlayerHit", "Dodged").
	Le client :
	  • crée un modèle en Parts par ennemi (une seule fois), et le déplace en douceur
	    (interpolation à chaque image, aucun trafic réseau en plus) ;
	  • anime : marche (rebond), armement du coup (recul + rouge), attaque (élan vers
	    l'avant), touché (flash blanc, recul, particules, son, nombre de dégâts),
	    mort (rétrécit + particules), attaque de zone du boss (cercle rouge qui grandit,
	    saut, onde de choc) ;
	  • détruit tout à la fin du combat (aucun objet oublié).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local EnemyBuilder = require(script.Parent.EnemyBuilder)

local DungeonRenderer = {}

local Effects = Config.CombatEffects
local player = Players.LocalPlayer

type View = {
	Id: number,
	Def: any,
	Model: Model,
	Body: BasePart,
	Parts: { { Part: BasePart, Color: Color3, Material: Enum.Material } }, -- pièces qui changent de couleur
	Joints: { any }, -- pattes / bras animés (EnemyBuilder)
	HPFill: Frame,
	Particles: ParticleEmitter,
	HitSound: Sound,
	Current: CFrame,
	Target: CFrame,
	HP: number,
	State: string,
	StateTime: number,
	LungeAt: number,
	RecoilAt: number,
	FlashUntil: number,
	Dying: boolean,
	SlamCircle: BasePart?,
	SlamStart: number,
	SlamWindup: number,
	SlamRadius: number,
}

local folder: Folder? = nil
local views: { [number]: View } = {}
local arenaY = 0
local damageNumbers = 0
local onPlayerHit: ((number) -> ())? = nil
local onDodged: (() -> ())? = nil

local function getFolder(): Folder
	if not folder or not folder.Parent then
		local f = Instance.new("Folder")
		f.Name = "DungeonEnemiesClient"
		f.Parent = Workspace
		folder = f
	end
	return folder :: Folder
end

local function makePart(props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	local anyPart: any = part
	for key, value in props do
		anyPart[key] = value
	end
	return part
end

local function makeSound(parent: Instance, soundId: string, volume: number): Sound
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume
	sound.RollOffMaxDistance = 120
	sound.Parent = parent
	return sound
end

--------------------------------------------------------------------------
-- Modèle d'un ennemi (Parts simples, construit UNE fois)
--------------------------------------------------------------------------

local function buildView(id: number, key: string, cframe: CFrame): View?
	local def = Config.Enemies[key]
	if not def then
		return nil
	end
	-- Modèle cartoon de l'ennemi (EnemyBuilder, phase 10)
	local model, body, flashParts, joints = EnemyBuilder.Build(key, cframe)
	local bodySize = body.Size
	local parts = {}
	for _, p in flashParts do
		table.insert(parts, { Part = p, Color = p.Color, Material = p.Material })
	end
	if def.Boss then
		local light = Instance.new("PointLight")
		light.Color = def.Accent
		light.Range = 18
		light.Parent = body
	end

	-- Barre de vie
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(math.max(4, def.Size * 1.2), 1.4)
	gui.StudsOffsetWorldSpace = Vector3.new(0, bodySize.Y / 2 + 1.5, 0)
	gui.MaxDistance = 140
	gui.LightInfluence = 0
	gui.Parent = body
	local name = Instance.new("TextLabel")
	name.Size = UDim2.fromScale(1, 0.55)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.FredokaOne
	name.TextScaled = true
	name.TextColor3 = if def.Boss then Color3.fromRGB(255, 120, 120) else Color3.new(1, 1, 1)
	name.TextStrokeTransparency = 0.3
	name.Text = (if def.Boss then "👑 " else "") .. def.DisplayName
	name.Parent = gui
	local back = Instance.new("Frame")
	back.Position = UDim2.fromScale(0, 0.6)
	back.Size = UDim2.fromScale(1, 0.35)
	back.BackgroundColor3 = Color3.fromRGB(40, 20, 20)
	back.Parent = gui
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(230, 60, 60)
	fill.BorderSizePixel = 0
	fill.Parent = back

	-- Particules d'impact (une seule émettrice, déclenchée avec :Emit)
	local attachment = Instance.new("Attachment")
	attachment.Position = Vector3.new(0, 0, -bodySize.Z / 2)
	attachment.Parent = body
	local particles = Instance.new("ParticleEmitter")
	particles.Enabled = false
	particles.Color = ColorSequence.new(Color3.fromRGB(255, 240, 180), def.Accent)
	particles.LightEmission = 0.8
	particles.Lifetime = NumberRange.new(0.25, 0.45)
	particles.Speed = NumberRange.new(8, 16)
	particles.SpreadAngle = Vector2.new(70, 70)
	particles.Size = NumberSequence.new(0.35, 0)
	particles.Parent = attachment

	model.Parent = getFolder()
	return {
		Id = id,
		Def = def,
		Model = model,
		Body = body,
		Parts = parts,
		Joints = joints,
		HPFill = fill,
		Particles = particles,
		HitSound = makeSound(body, Effects.HitSound, 0.6),
		Current = cframe,
		Target = cframe,
		HP = def.HP,
		State = "Chase",
		StateTime = os.clock(),
		LungeAt = 0,
		RecoilAt = 0,
		FlashUntil = 0,
		Dying = false,
		SlamCircle = nil,
		SlamStart = 0,
		SlamWindup = 1,
		SlamRadius = 0,
	}
end

local function setColor(view: View, color: Color3?, material: Enum.Material?)
	for _, entry in view.Parts do
		entry.Part.Color = color or entry.Color
		entry.Part.Material = material or entry.Material
	end
end

local function removeView(view: View)
	views[view.Id] = nil
	if view.SlamCircle then
		view.SlamCircle:Destroy()
	end
	view.Model:Destroy()
end

--------------------------------------------------------------------------
-- Effets
--------------------------------------------------------------------------

local function damageNumber(view: View, amount: number)
	if damageNumbers >= Effects.MaxDamageNumbers then
		return
	end
	damageNumbers += 1
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(3, 1.2)
	gui.StudsOffsetWorldSpace = Vector3.new(math.random() * 2 - 1, view.Body.Size.Y / 2 + 2.5, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = view.Body
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 230, 90)
	label.TextStrokeTransparency = 0
	label.Text = "-" .. Format.Number(amount)
	label.Parent = gui
	TweenService:Create(gui, TweenInfo.new(0.6), { StudsOffsetWorldSpace = gui.StudsOffsetWorldSpace + Vector3.new(0, 2.5, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(0.6), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(0.6, function()
		damageNumbers -= 1
		gui:Destroy()
	end)
end

local function onHit(view: View, amount: number)
	view.FlashUntil = os.clock() + 0.08
	view.RecoilAt = os.clock()
	setColor(view, Color3.new(1, 1, 1), Enum.Material.Neon)
	view.Particles:Emit(Effects.HitParticles)
	view.HitSound.PlaybackSpeed = 0.9 + math.random() * 0.3
	view.HitSound:Play()
	damageNumber(view, amount)
end

local function onDeath(view: View)
	if view.Dying then
		return
	end
	view.Dying = true
	view.Particles:Emit(Effects.DeathParticles)
	-- Rétrécit et disparaît (taille animée via ScaleTo, pas de nouvelles Parts)
	local scale = Instance.new("NumberValue")
	scale.Value = 1
	scale.Changed:Connect(function(value)
		if view.Model.Parent then
			view.Model:ScaleTo(math.max(0.05, value))
		end
	end)
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Value = 0.05 }):Play()
	task.delay(0.4, function()
		scale:Destroy()
		removeView(view)
	end)
end

local function startSlam(view: View, radius: number, windup: number)
	view.SlamStart = os.clock()
	view.SlamWindup = windup
	view.SlamRadius = radius
	if view.SlamCircle then
		view.SlamCircle:Destroy()
	end
	view.SlamCircle = makePart({
		Name = "SlamWarning",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 1, 1),
		CFrame = CFrame.new(view.Current.Position + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(255, 40, 40),
		Material = Enum.Material.Neon,
		Transparency = 0.45,
		Parent = getFolder(),
	})
end

local function slamImpact(view: View, radius: number)
	if view.SlamCircle then
		view.SlamCircle:Destroy()
		view.SlamCircle = nil
	end
	-- Onde de choc : un anneau qui s'élargit et s'efface
	local ring = makePart({
		Name = "Shockwave",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 2, 2),
		CFrame = CFrame.new(view.Current.Position + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(255, 200, 120),
		Material = Enum.Material.Neon,
		Transparency = 0.2,
		Parent = getFolder(),
	})
	TweenService:Create(ring, TweenInfo.new(0.35), { Size = Vector3.new(0.3, radius * 2.2, radius * 2.2), Transparency = 1 }):Play()
	Debris:AddItem(ring, 0.4)
	view.Particles:Emit(Effects.DeathParticles)
	view.HitSound.PlaybackSpeed = 0.5
	view.HitSound:Play()
end

--------------------------------------------------------------------------
-- Réception des instantanés
--------------------------------------------------------------------------

function DungeonRenderer.OnSnapshot(list: { any }, events: { any })
	local seen = {}
	for _, entry in list do
		local id, key, x, z, yaw, hp, state = entry[1], entry[2], entry[3], entry[4], entry[5], entry[6], entry[7]
		local target = CFrame.new(x, arenaY, z) * CFrame.Angles(0, yaw, 0)
		local view = views[id]
		if not view then
			view = buildView(id, key, target)
			if view then
				views[id] = view
			end
		end
		if view and not view.Dying then
			seen[id] = true
			view.Target = target
			view.HP = hp
			view.HPFill.Size = UDim2.fromScale(math.clamp(hp / view.Def.HP, 0, 1), 1)
			if view.State ~= state then
				view.State = state
				view.StateTime = os.clock()
				if state == "WindUp" or state == "Slam" then
					setColor(view, Color3.fromRGB(255, 40, 40), Enum.Material.Neon) -- avertissement
				elseif os.clock() >= view.FlashUntil then
					setColor(view)
				end
			end
		end
	end

	for _, event in events do
		local kind = event[1]
		local view = event[2] and views[event[2]]
		if kind == "Hit" and view then
			onHit(view, event[3])
		elseif kind == "Death" and view then
			onDeath(view)
		elseif kind == "Attack" and view then
			view.LungeAt = os.clock()
		elseif kind == "SlamStart" and view then
			startSlam(view, event[3], event[4])
		elseif kind == "SlamHit" and view then
			slamImpact(view, event[3])
		elseif kind == "PlayerHit" and onPlayerHit then
			onPlayerHit(event[2])
		elseif kind == "Dodged" and onDodged then
			onDodged()
		end
	end

	-- Ennemis absents de l'instantané (fin de vague, fin de partie) : on les retire
	for id, view in views do
		if not seen[id] and not view.Dying then
			onDeath(view)
		end
	end
end

function DungeonRenderer.SetArenaY(y: number)
	arenaY = y
end

function DungeonRenderer.Clear()
	for _, view in views do
		removeView(view)
	end
	if folder then
		folder:ClearAllChildren()
	end
end

-- callbacks(playerHit(dégâts), dodged())
function DungeonRenderer.Init(playerHitCallback: (number) -> (), dodgedCallback: () -> ())
	onPlayerHit = playerHitCallback
	onDodged = dodgedCallback

	-- Une seule boucle par image pour tous les ennemis : interpolation + petites animations
	RunService.RenderStepped:Connect(function(dt)
		if next(views) == nil then
			return
		end
		local now = os.clock()
		local alpha = math.min(1, dt * 12)
		for _, view in views do
			if view.Dying then
				continue
			end
			local previous = view.Current.Position
			view.Current = view.Current:Lerp(view.Target, alpha)
			local s = view.Def.Size
			local moving = (view.Current.Position - previous).Magnitude > 0.02

			-- Décalages d'animation (dans le repère de l'ennemi : -Z = devant)
			local up, forward, tilt = 0, 0, 0
			if moving and view.State == "Chase" then
				up = math.abs(math.sin(now * 12)) * s * 0.12 -- rebond de marche
			end
			if view.State == "WindUp" then
				local t = math.min(1, (now - view.StateTime) / math.max(0.1, view.Def.WindUp))
				forward = -s * 0.25 * t -- recule pour armer
				tilt = math.rad(-15) * t
			end
			local lunge = now - view.LungeAt
			if lunge < 0.25 then
				forward = s * 0.6 * math.sin(lunge / 0.25 * math.pi) -- élan vers l'avant
			end
			local recoil = now - view.RecoilAt
			if recoil < 0.15 then
				forward -= s * 0.2 * (1 - recoil / 0.15) -- petit recul quand il est touché
			end
			if view.State == "Slam" then
				local t = math.min(1, (now - view.SlamStart) / view.SlamWindup)
				up = s * 0.8 * math.sin(t * math.pi * 0.5) -- le boss saute avant de retomber
				if view.SlamCircle then
					local size = view.SlamRadius * 2 * t
					view.SlamCircle.Size = Vector3.new(0.2, math.max(1, size), math.max(1, size))
				end
			end
			if view.FlashUntil > 0 and now >= view.FlashUntil then
				view.FlashUntil = 0
				if view.State == "WindUp" or view.State == "Slam" then
					setColor(view, Color3.fromRGB(255, 40, 40), Enum.Material.Neon)
				else
					setColor(view)
				end
			end

			local pivot = view.Current * CFrame.new(0, up, -forward) * CFrame.Angles(tilt, 0, 0)
			view.Model:PivotTo(pivot)
			-- Pattes et bras : balancent quand l'ennemi avance, les bras s'élancent à l'attaque
			if #view.Joints > 0 then
				local partsList, cframes = {}, {}
				local swing = if moving and view.State == "Chase" then math.sin(now * 12) else 0
				-- Bras : en avant pendant l'élan (angle > 0), en arrière pendant l'armement
				local armBoost = if lunge < 0.25 then math.sin(lunge / 0.25 * math.pi) * 1.2 elseif view.State == "WindUp" then -0.8 else 0
				for _, j in view.Joints do
					local angle
					if j.Kind == "Arm" then
						angle = if armBoost ~= 0 then armBoost else swing * 0.4 * (if j.Phase == 0 then 1 else -1)
					else
						angle = if moving then math.sin(now * 12 + j.Phase) * 0.5 else 0
					end
					local hingePos = j.Local.Position + j.Hinge
					table.insert(partsList, j.Part)
					table.insert(cframes, pivot * CFrame.new(hingePos) * CFrame.Angles(angle, 0, 0) * CFrame.new(-hingePos) * j.Local)
				end
				Workspace:BulkMoveTo(partsList, cframes, Enum.BulkMoveMode.FireCFrameChanged)
			end
		end
	end)

	-- Sécurité : si le personnage réapparaît (fin de donjon), on nettoie tout
	player.CharacterAdded:Connect(function()
		DungeonRenderer.Clear()
	end)
end

return DungeonRenderer
