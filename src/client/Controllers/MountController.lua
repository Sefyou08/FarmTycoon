--[[
	MountController.lua
	===================
	Montures, côté client :
	  • Bouton "🐴 Monture" : si on est à cheval -> descendre ; sinon -> fenêtre avec
	    tous ses chevaux (enclos + chevaux sauvages capturés), leur vitesse, leur saut,
	    leur particularité, et un bouton "Monter". Le serveur valide (MountAction).
	  • Pose du cavalier : le joueur local joue l'animation "assis" de son personnage
	    (celle du script Animate de Roblox) ; elle est répliquée, donc tout le monde voit
	    le cavalier assis.
	  • Animation des chevaux de TOUS les joueurs (tag "MountModel"), selon l'attribut MountRig :
	      "Generated" : pattes qui alternent selon la vitesse réelle (pas -> galop), tête qui
	                    hoche, queue qui balance ;
	      "Animated"  : modèle importé avec squelette : ses animations (Idle / Walk / Run, dossier
	                    MountAnimations) jouées et accélérées selon la vitesse ;
	      "Simple"    : modèle importé sans animation : balancement de galop + léger rebond
	                    (articulation "MountBob").
	    Purement visuel, calculé par chaque client, aucun trafic réseau.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local MountController = {}

local player = Players.LocalPlayer
local Theme
local notify: (string, string) -> ()
local window: Frame
local list: ScrollingFrame
local busy = false
local sitTrack: AnimationTrack? = nil

-- Articulations animées d'un cheval : { [Motor6D] = C0 d'origine }
type MountRig = {
	Model: Model,
	Kind: string,
	Motors: { [string]: Motor6D },
	Base: { [Motor6D]: CFrame },
	Phase: number,
	Tracks: { [string]: AnimationTrack },
	Current: string?,
}
local rigs: { [Model]: MountRig } = {}

local LEG_OFFSETS = { LegFL = 0, LegBR = 0, LegFR = math.pi, LegBL = math.pi } -- diagonales opposées

--------------------------------------------------------------------------
-- Animation des chevaux
--------------------------------------------------------------------------

local function loadTracks(model: Model, rig: MountRig)
	local folder = model:FindFirstChild("MountAnimations")
	local controller = model:FindFirstChildOfClass("AnimationController")
	local animator = controller and controller:FindFirstChildOfClass("Animator")
	if not folder or not animator then
		return
	end
	for _, anim in folder:GetChildren() do
		if anim:IsA("Animation") then
			local ok, loaded = pcall(function()
				return (animator :: Animator):LoadAnimation(anim)
			end)
			if ok and loaded then
				loaded.Looped = true
				loaded.Priority = Enum.AnimationPriority.Movement
				rig.Tracks[anim.Name] = loaded
			end
		end
	end
end

local function track(model: Instance)
	if not model:IsA("Model") or rigs[model] then
		return
	end
	local rig: MountRig = { Model = model, Kind = model:GetAttribute("MountRig") or "Generated", Motors = {}, Base = {}, Phase = math.random() * 10, Tracks = {} }
	for _, motor in model:GetDescendants() do
		if motor:IsA("Motor6D") then
			rig.Motors[motor.Name] = motor
			rig.Base[motor] = motor.C0
		end
	end
	if rig.Kind == "Animated" then
		loadTracks(model, rig)
		if next(rig.Tracks) == nil then
			rig.Kind = "Simple" -- animations illisibles : balancement simple à la place
		end
	end
	rigs[model] = rig
end

-- Choisit l'animation importée selon la vitesse (arrêt / pas / galop) et l'accélère
local function animateTracks(rig: MountRig, speed: number)
	local wanted = if speed < 2 then "Idle" elseif speed < 30 then "Walk" else "Run"
	-- Animation manquante : on prend la plus proche disponible
	local order = { Idle = { "Idle", "Walk", "Run" }, Walk = { "Walk", "Run", "Idle" }, Run = { "Run", "Walk", "Idle" } }
	local chosen
	for _, name in order[wanted] do
		if rig.Tracks[name] then
			chosen = name
			break
		end
	end
	if not chosen then
		return
	end
	if rig.Current ~= chosen then
		if rig.Current and rig.Tracks[rig.Current] then
			rig.Tracks[rig.Current]:Stop(0.25)
		end
		rig.Tracks[chosen]:Play(0.25)
		rig.Current = chosen
	end
	local reference = if chosen == "Run" then 40 elseif chosen == "Walk" then 16 else 0
	local trackSpeed = if reference > 0 and speed > 0.5 then math.clamp(speed / reference, 0.4, 2) elseif chosen == "Idle" then 1 else 0.4
	rig.Tracks[chosen]:AdjustSpeed(trackSpeed)
end

local function animateRigs(dt: number)
	local now = os.clock()
	for model, rig in rigs do
		if not model.Parent then
			rigs[model] = nil
			continue
		end
		-- Vitesse réelle du cavalier (le cheval est soudé à son HumanoidRootPart)
		local body = model.PrimaryPart
		local speed = if body then Vector3.new(body.AssemblyLinearVelocity.X, 0, body.AssemblyLinearVelocity.Z).Magnitude else 0
		local gait = math.clamp(speed / 30, 0, 1) -- 0 = arrêt, ~0,5 = pas, 1 = galop
		rig.Phase += dt * (4 + speed * 0.35)

		if rig.Kind == "Animated" then
			animateTracks(rig, speed)
			continue
		end
		local bobMotor = rig.Motors.MountBob
		if rig.Kind == "Simple" and bobMotor then
			-- Galop simple : rebond (deux appuis par foulée), tangage avant/arrière, respiration
			local bounce = math.abs(math.sin(rig.Phase)) * 0.28 * gait
			local pitch = math.sin(rig.Phase) * math.rad(5) * gait
			local roll = math.sin(rig.Phase * 0.5) * math.rad(1.5) * gait
			local breathe = math.sin(now * 2) * 0.04
			bobMotor.C0 = rig.Base[bobMotor] * CFrame.new(0, bounce + breathe, 0) * CFrame.Angles(pitch, 0, roll)
			continue
		end
		for name, offset in LEG_OFFSETS do
			local motor = rig.Motors[name]
			if motor then
				local swing = math.sin(rig.Phase + offset) * math.rad(40) * gait
				motor.C0 = rig.Base[motor] * CFrame.Angles(swing, 0, 0)
			end
		end
		local neck = rig.Motors.Neck
		if neck then
			local bob = math.sin(rig.Phase * 2) * math.rad(6) * gait + math.sin(now * 1.5) * math.rad(3)
			neck.C0 = rig.Base[neck] * CFrame.Angles(bob, 0, 0)
		end
		local tail = rig.Motors.Tail
		if tail then
			tail.C0 = rig.Base[tail] * CFrame.Angles(0, math.sin(now * 3) * math.rad(15), 0)
		end
	end
end

--------------------------------------------------------------------------
-- Pose du cavalier (joueur local)
--------------------------------------------------------------------------

local function stopSit()
	if sitTrack then
		sitTrack:Stop(0.2)
		sitTrack = nil
	end
end

local function playSit()
	stopSit()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	-- L'animation "assis" fournie par le script Animate de Roblox (R15 ou R6)
	local animate = character and character:FindFirstChild("Animate")
	local sitFolder = animate and animate:FindFirstChild("sit")
	local animation = sitFolder and sitFolder:FindFirstChildOfClass("Animation")
	if animator and animation then
		local ok, loaded = pcall(function()
			return animator:LoadAnimation(animation)
		end)
		if ok and loaded then
			loaded.Priority = Enum.AnimationPriority.Action
			loaded.Looped = true
			loaded:Play(0.2)
			sitTrack = loaded
		end
	end
end

--------------------------------------------------------------------------
-- Fenêtre de choix du cheval
--------------------------------------------------------------------------

local function invoke(...: any): (boolean, any, any)
	if busy then
		return false, nil, nil
	end
	busy = true
	local args = table.pack(...)
	local ok, a, b = pcall(function()
		return Remotes.Get("MountAction"):InvokeServer(table.unpack(args, 1, args.n))
	end)
	busy = false
	return ok, a, b
end

local function rebuild(entries: { { [string]: any } })
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	if #entries == 0 then
		local empty = Instance.new("Frame")
		empty.Size = UDim2.new(1, -8, 0, 60)
		empty.BackgroundTransparency = 1
		empty.Parent = list
		Theme.Label({
			Size = UDim2.fromScale(1, 1),
			TextWrapped = true,
			TextColor3 = Color3.fromRGB(190, 190, 200),
			Text = "Aucun cheval : achète-en un au stand 🐄 ANIMAUX, ou capture un cheval sauvage en expédition !",
			Parent = empty,
		})
		return
	end
	for order, entry in entries do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -8, 0, 64)
		row.LayoutOrder = order
		row.BackgroundColor3 = Color3.fromRGB(50, 56, 75)
		row.Parent = list
		Theme.Corner(row, 8)
		Theme.Label({
			Size = UDim2.new(0.64, -10, 0, 28),
			Position = UDim2.fromOffset(10, 4),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = ("🐴 %s   (%s)"):format(entry.Label, entry.Where),
			Parent = row,
		})
		Theme.Label({
			Size = UDim2.new(0.64, -10, 0, 22),
			Position = UDim2.fromOffset(10, 36),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(200, 200, 210),
			Text = ("🏃 %d (galop %d)  •  ⬆️ saut %d  •  %s"):format(entry.Speed, entry.SprintSpeed, entry.JumpPower, entry.Perk),
			Parent = row,
		})
		local button = Theme.Button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.new(0.34, -16, 0, 44),
			BackgroundColor3 = Color3.fromRGB(150, 100, 60),
			Text = "Monter",
			Parent = row,
		})
		button.Activated:Connect(function()
			local ok, success, message = invoke("Mount", entry.Kind, entry.Id)
			if ok then
				notify(message or "", if success then "Success" else "Error")
				if success then
					window.Visible = false
				end
			end
		end)
	end
end

local function openWindow()
	local ok, entries = invoke("List")
	if ok and type(entries) == "table" then
		rebuild(entries)
		window.Visible = true
	end
end

--------------------------------------------------------------------------
-- Init
--------------------------------------------------------------------------

function MountController.Init(screen: ScreenGui, HUD, theme, notifyFn: (string, string) -> ())
	Theme = theme
	notify = notifyFn

	local content
	window, content = Theme.Window(screen, "Mounts", "🐴 Mes montures", Vector2.new(560, 420))
	list = Instance.new("ScrollingFrame")
	list.Size = UDim2.fromScale(1, 1)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = content
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = list

	local button = HUD.AddButton("MountButton", "🐴 Monture", Color3.fromRGB(150, 100, 60), 9, function()
		if player:GetAttribute("Mounted") then
			local ok, success, message = invoke("Dismount")
			if ok and message then
				notify(message, if success then "Info" else "Error")
			end
		elseif window.Visible then
			window.Visible = false
		else
			openWindow()
		end
	end)

	-- Pose assise + texte du bouton selon l'état
	player:GetAttributeChangedSignal("Mounted"):Connect(function()
		if player:GetAttribute("Mounted") then
			playSit()
			button.Text = "🐴 Descendre"
		else
			stopSit()
			button.Text = "🐴 Monture"
		end
	end)
	player.CharacterAdded:Connect(function()
		sitTrack = nil
		button.Text = "🐴 Monture"
	end)

	-- Chevaux de tous les joueurs
	for _, model in CollectionService:GetTagged("MountModel") do
		track(model)
	end
	-- Attend que tout le modèle soit répliqué (articulations, animations) avant de l'analyser
	CollectionService:GetInstanceAddedSignal("MountModel"):Connect(function(model)
		task.delay(0.2, track, model)
	end)
	CollectionService:GetInstanceRemovedSignal("MountModel"):Connect(function(model)
		rigs[model :: Model] = nil
	end)
	RunService.RenderStepped:Connect(function(dt)
		if next(rigs) ~= nil then
			animateRigs(dt)
		end
	end)
end

return MountController
