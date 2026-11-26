--[[
	AnimalController.lua
	====================
	Animations purement visuelles des animaux, calculées par le client (aucun
	trafic réseau, aucun effet sur le gameplay) :
	  • les modèles tagués "FarmAnimal" se promènent au hasard dans leur enclos
	    (attributs WanderCenter / WanderRadius posés par le serveur) ;
	  • les parts taguées "RainbowPart" changent de couleur en continu
	    (variantes Arc-en-ciel et Mythique).
]]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local AnimalController = {}

local ANIMAL_TAG = "FarmAnimal"
local RAINBOW_TAG = "RainbowPart"
local WALK_SPEED = 3 -- studs par seconde

-- Jeton par modèle : si le modèle sort puis revient (streaming), l'ancienne boucle s'arrête
local wandering: { [Model]: {} } = {}

-- Boucle de promenade d'UN animal : pause, puis marche vers un point au hasard.
local function wander(model: Model)
	if wandering[model] then
		return
	end
	local token = {}
	wandering[model] = token

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

			local from = model:GetPivot()
			local angle = math.random() * math.pi * 2
			local distance = math.random() * radius
			local target = Vector3.new(center.X + math.cos(angle) * distance, from.Position.Y, center.Z + math.sin(angle) * distance)
			local travel = (target - from.Position).Magnitude
			if travel < 0.5 then
				continue
			end

			-- On se tourne vers la destination (la tête est vers -Z = LookVector), puis on avance
			local goal = CFrame.lookAt(target, target + (target - from.Position).Unit)
			driver.Value = CFrame.lookAt(from.Position, target)
			local tween = TweenService:Create(driver, TweenInfo.new(travel / WALK_SPEED, Enum.EasingStyle.Linear), { Value = goal })
			tween:Play()
			tween.Completed:Wait()
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
