--[[
	DungeonUI.lua
	=============
	  • Fenêtre du portail des donjons (OpenUI = "Dungeon") : niveau requis, vagues,
	    boss, butin possible, victoires, bouton "Entrer".
	  • Pendant un donjon : PV du joueur, vague / boss avec sa barre de vie, et les
	    boutons ⚔️ Attaquer (clic gauche ou F) et 💨 Esquive (Q), 🚪 Quitter.
	  • Le client ne fait qu'ENVOYER "j'attaque" / "j'esquive" : le serveur choisit la
	    cible, calcule les dégâts et gère les cooldowns. Le bond d'esquive, les gestes
	    (CombatAnimator) et les ennemis (DungeonRenderer) sont dessinés par le client.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local ItemUtil = require(ReplicatedStorage.Shared.ItemUtil)
local CropUtil = require(ReplicatedStorage.Shared.CropUtil)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(script.Parent.Theme)
local Controllers = script.Parent.Parent:WaitForChild("Controllers")
local DungeonRenderer = require(Controllers:WaitForChild("DungeonRenderer"))
local CombatAnimator = require(Controllers:WaitForChild("CombatAnimator"))

local DungeonUI = {}

local Combat = Config.Combat
local player = Players.LocalPlayer
local StateController
local notify: (string, string) -> ()
local busy = false

local window: Frame
local list: ScrollingFrame
local hud: Frame
local hpFill: Frame
local hpLabel: TextLabel
local waveLabel: TextLabel
local bossBar: Frame
local bossFill: Frame
local bossLabel: TextLabel
local inDungeon = false
local lastAttack, lastDodge = 0, 0

--------------------------------------------------------------------------
-- Liste des donjons
--------------------------------------------------------------------------

local function lootText(def: any): string
	local parts = {}
	for _, loot in def.Rewards.Loot do
		local label = if loot.Kind == "Seeds" then CropUtil.Label(loot.Id) else ItemUtil.Label(loot.Id, loot.Variant)
		table.insert(parts, ("%s (%d %%)"):format(label, math.floor(loot.Chance * 100 + 0.5)))
	end
	return table.concat(parts, ", ")
end

local function rebuildList()
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local level = StateController.Get("Level") or 1
	local clears = StateController.Get("DungeonClears") or {}
	local ids = {}
	for id in Config.Dungeons do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return Config.Dungeons[a].Order < Config.Dungeons[b].Order
	end)

	for order, id in ids do
		local def = Config.Dungeons[id]
		local boss = Config.Enemies[def.Boss]
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -8, 0, 112)
		row.LayoutOrder = order
		row.BackgroundColor3 = Color3.fromRGB(50, 56, 75)
		row.Parent = list
		Theme.Corner(row, 10)

		Theme.Label({
			Size = UDim2.new(0.66, -10, 0, 26),
			Position = UDim2.fromOffset(10, 4),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = ("%s %s   (niv. %d)   ✅ %d"):format(def.Icon, def.DisplayName, def.RequiredLevel, clears[id] or 0),
			Parent = row,
		})
		Theme.Label({
			Size = UDim2.new(0.66, -10, 0, 78),
			Position = UDim2.fromOffset(10, 30),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
			TextColor3 = Color3.fromRGB(200, 200, 210),
			Text = ("%d vagues puis 👑 %s\n💰 %s à %s  •  ⭐ %d XP%s\n🎁 %s"):format(
				#def.Waves,
				boss.DisplayName,
				Format.Number(def.Rewards.Coins[1]),
				Format.Number(def.Rewards.Coins[2]),
				def.Rewards.XP,
				if (clears[id] or 0) == 0 then ("  •  1re victoire +%s"):format(Format.Number(def.Rewards.FirstClearBonus)) else "",
				lootText(def)
			),
			Parent = row,
		})

		local unlocked = level >= def.RequiredLevel
		local button = Theme.Button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.new(0.34, -20, 0, 50),
			BackgroundColor3 = if unlocked then Color3.fromRGB(200, 60, 60) else Color3.fromRGB(90, 90, 100),
			Text = if unlocked then "⚔️ Entrer" else ("🔒 Niveau %d"):format(def.RequiredLevel),
			Parent = row,
		})
		button.Activated:Connect(function()
			if not unlocked or busy then
				return
			end
			busy = true
			local ok, success, message = pcall(function()
				return Remotes.Get("DungeonAction"):InvokeServer("Enter", id)
			end)
			busy = false
			if ok then
				notify(message or "", if success then "Info" else "Error")
				if success then
					window.Visible = false
				end
			end
		end)
	end
end

--------------------------------------------------------------------------
-- Combat
--------------------------------------------------------------------------

local function attack()
	if not inDungeon then
		return
	end
	local now = os.clock()
	if now - lastAttack < Combat.AttackCooldown then
		return
	end
	lastAttack = now
	CombatAnimator.Attack() -- geste + trace + son (visuel)
	Remotes.Get("DungeonAttack"):FireServer()
end

local function dodge()
	if not inDungeon then
		return
	end
	local now = os.clock()
	if now - lastDodge < Combat.DodgeCooldown then
		return
	end
	lastDodge = now
	Remotes.Get("DungeonDodge"):FireServer()
	CombatAnimator.Roll()
	-- Bond dans la direction de déplacement (ou vers l'avant)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and root:IsA("BasePart") and humanoid then
		local direction = if humanoid.MoveDirection.Magnitude > 0.1 then humanoid.MoveDirection else root.CFrame.LookVector
		root.AssemblyLinearVelocity = Vector3.new(direction.X * Combat.DodgeSpeed, root.AssemblyLinearVelocity.Y, direction.Z * Combat.DodgeSpeed)
	end
end

local function setInDungeon(value: boolean)
	if inDungeon == value then
		return
	end
	inDungeon = value
	hud.Visible = value
	CombatAnimator.EquipWeapon(value)
	if not value then
		DungeonRenderer.Clear()
	end
	if value then
		ContextActionService:BindAction("DungeonAttack", function(_, inputState)
			if inputState == Enum.UserInputState.Begin then
				attack()
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.KeyCode.F)
		ContextActionService:BindAction("DungeonDodge", function(_, inputState)
			if inputState == Enum.UserInputState.Begin then
				dodge()
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.KeyCode.Q)
	else
		ContextActionService:UnbindAction("DungeonAttack")
		ContextActionService:UnbindAction("DungeonDodge")
	end
end

local function onState(state: { [string]: any })
	if type(state) ~= "table" then
		return
	end
	if state.Ended then
		setInDungeon(false)
		if state.Message then
			notify(state.Message, if state.Outcome == "Victory" then "Rare" elseif state.Outcome == "Defeat" then "Error" else "Info")
		end
		return
	end
	setInDungeon(state.Active == true)
	if state.ArenaY then
		DungeonRenderer.SetArenaY(state.ArenaY)
	end
	local hp, maxHp = state.HP or 0, math.max(1, state.MaxHP or 1)
	hpFill.Size = UDim2.fromScale(math.clamp(hp / maxHp, 0, 1), 1)
	hpLabel.Text = ("❤️ %d / %d PV"):format(hp, maxHp)

	if state.IsBoss then
		waveLabel.Text = ("%s  •  👑 BOSS"):format(state.DungeonName or "")
		bossBar.Visible = true
		bossFill.Size = UDim2.fromScale(math.clamp((state.BossHP or 0) / math.max(1, state.BossMaxHP or 1), 0, 1), 1)
		bossLabel.Text = ("👑 %s  %s / %s"):format(state.BossName or "Boss", Format.Number(math.max(0, state.BossHP or 0)), Format.Number(state.BossMaxHP or 0))
	else
		bossBar.Visible = false
		local wave = state.Wave or 0
		if state.Enemies == 0 and state.NextWaveAt then
			waveLabel.Text = ("%s  •  prochaine vague..."):format(state.DungeonName or "")
		else
			waveLabel.Text = ("%s  •  Vague %d / %d  •  %d ennemi(s)"):format(state.DungeonName or "", math.max(wave, 1), state.TotalWaves or 1, state.Enemies or 0)
		end
	end
end

--------------------------------------------------------------------------
-- Init
--------------------------------------------------------------------------

function DungeonUI.Init(screen: ScreenGui, stateController, notifyFn: (string, string) -> ())
	StateController = stateController
	notify = notifyFn

	-- Fenêtre du portail
	local content
	window, content = Theme.Window(screen, "Dungeons", "⚔️ Donjons", Vector2.new(660, 500))
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
	layout.Padding = UDim.new(0, 8)
	layout.Parent = list

	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt:GetAttribute("OpenUI") == "Dungeon" then
			rebuildList()
			window.Visible = true
		end
	end)

	-- Interface de combat (en bas, au-dessus de la barre de graines)
	hud = Instance.new("Frame")
	hud.Name = "DungeonHUD"
	hud.AnchorPoint = Vector2.new(0.5, 1)
	hud.Position = UDim2.new(0.5, 0, 1, -100)
	hud.Size = UDim2.new(0.9, 0, 0, 150)
	hud.BackgroundTransparency = 1
	hud.Visible = false
	hud.Parent = screen
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = Vector2.new(560, 150)
	constraint.Parent = hud

	waveLabel = Theme.Label({ Size = UDim2.new(1, 0, 0, 24), TextStrokeTransparency = 0.3, Text = "", Parent = hud })

	bossBar = Instance.new("Frame")
	bossBar.Position = UDim2.fromOffset(0, 26)
	bossBar.Size = UDim2.new(1, 0, 0, 22)
	bossBar.BackgroundColor3 = Color3.fromRGB(40, 20, 20)
	bossBar.Visible = false
	bossBar.Parent = hud
	Theme.Corner(bossBar, 6)
	bossFill = Instance.new("Frame")
	bossFill.Size = UDim2.fromScale(1, 1)
	bossFill.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
	bossFill.BorderSizePixel = 0
	bossFill.Parent = bossBar
	Theme.Corner(bossFill, 6)
	bossLabel = Theme.Label({ Size = UDim2.fromScale(1, 1), ZIndex = 2, TextStrokeTransparency = 0.3, Text = "", Parent = bossBar })

	local hpBar = Instance.new("Frame")
	hpBar.Position = UDim2.fromOffset(0, 52)
	hpBar.Size = UDim2.new(1, 0, 0, 26)
	hpBar.BackgroundColor3 = Color3.fromRGB(30, 40, 30)
	hpBar.Parent = hud
	Theme.Corner(hpBar, 8)
	Theme.Stroke(hpBar, 2)
	hpFill = Instance.new("Frame")
	hpFill.Size = UDim2.fromScale(1, 1)
	hpFill.BackgroundColor3 = Color3.fromRGB(80, 200, 100)
	hpFill.BorderSizePixel = 0
	hpFill.Parent = hpBar
	Theme.Corner(hpFill, 8)
	hpLabel = Theme.Label({ Size = UDim2.fromScale(1, 1), ZIndex = 2, TextStrokeTransparency = 0.3, Text = "", Parent = hpBar })

	local buttons = Instance.new("Frame")
	buttons.Position = UDim2.fromOffset(0, 86)
	buttons.Size = UDim2.new(1, 0, 0, 56)
	buttons.BackgroundTransparency = 1
	buttons.Parent = hud
	local buttonLayout = Instance.new("UIListLayout")
	buttonLayout.FillDirection = Enum.FillDirection.Horizontal
	buttonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	buttonLayout.Padding = UDim.new(0, 8)
	buttonLayout.Parent = buttons
	local attackButton = Theme.Button({ Size = UDim2.fromOffset(170, 54), BackgroundColor3 = Color3.fromRGB(200, 70, 60), Text = "⚔️ Attaquer (F)", Parent = buttons })
	attackButton.Activated:Connect(attack)
	local dodgeButton = Theme.Button({ Size = UDim2.fromOffset(150, 54), BackgroundColor3 = Color3.fromRGB(70, 120, 200), Text = "💨 Esquive (Q)", Parent = buttons })
	dodgeButton.Activated:Connect(dodge)
	local leaveButton = Theme.Button({ Size = UDim2.fromOffset(110, 54), BackgroundColor3 = Color3.fromRGB(90, 90, 100), Text = "🚪 Quitter", Parent = buttons })
	leaveButton.Activated:Connect(function()
		pcall(function()
			Remotes.Get("DungeonAction"):InvokeServer("Leave")
		end)
	end)

	-- Clic gauche = attaque pendant un donjon (sauf sur un bouton de l'interface)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if inDungeon and not gameProcessed and input.UserInputType == Enum.UserInputType.MouseButton1 then
			attack()
		end
	end)

	Remotes.Get("DungeonState").OnClientEvent:Connect(onState)
	Remotes.Get("DungeonEnemies").OnClientEvent:Connect(function(list, events)
		if inDungeon and type(list) == "table" and type(events) == "table" then
			DungeonRenderer.OnSnapshot(list, events)
		end
	end)

	-- Effets quand le JOUEUR est touché / esquive (écran rouge + petite secousse de caméra)
	local flash = Instance.new("Frame")
	flash.Name = "HitFlash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
	flash.BackgroundTransparency = 1
	flash.ZIndex = 0
	flash.Parent = screen
	local shakeUntil = 0
	DungeonRenderer.Init(function(_damage)
		flash.BackgroundTransparency = 0.7
		hpFill.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
		shakeUntil = os.clock() + 0.2
		task.delay(0.15, function()
			flash.BackgroundTransparency = 1
			hpFill.BackgroundColor3 = Color3.fromRGB(80, 200, 100)
		end)
	end, function()
		notify("💨 Esquivé !", "Success")
	end)
	CombatAnimator.Init()
	game:GetService("RunService").RenderStepped:Connect(function()
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end
		if os.clock() < shakeUntil then
			humanoid.CameraOffset = Vector3.new(math.random() - 0.5, math.random() - 0.5, 0) * 0.6
		elseif humanoid.CameraOffset ~= Vector3.zero and inDungeon then
			humanoid.CameraOffset = Vector3.zero
		end
	end)

	-- Fermeture de la fenêtre si on s'éloigne du portail
	task.spawn(function()
		local position = Config.Stands.DungeonPortalPosition
		while true do
			task.wait(0.5)
			if window.Visible then
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if not root or (root.Position - position).Magnitude > 24 then
					window.Visible = false
				end
			end
		end
	end)
end

return DungeonUI
