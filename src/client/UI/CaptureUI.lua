--[[
	CaptureUI.lua
	=============
	Mini-jeu de capture (lasso + barre de timing).
	  • Le serveur envoie les paramètres (CaptureStart) : vitesse du curseur,
	    largeur et positions des zones vertes, nombre de réussites nécessaires.
	  • Un curseur fait des allers-retours ; le joueur clique "LANCER !" (ou Espace,
	    ou touche l'écran) quand il est dans la zone verte.
	  • À chaque clic, on envoie au serveur le temps serveur estimé
	    (Workspace:GetServerTimeNow) ; c'est LE SERVEUR qui décide si c'est réussi.
	  • Un lasso (Beam) relie le joueur à la créature pendant la capture.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CreatureUtil = require(ReplicatedStorage.Shared.CreatureUtil)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(script.Parent.Theme)

local CaptureUI = {}

local player = Players.LocalPlayer
local notify: (string, string) -> ()
local actionRemote: RemoteFunction

local panel: Frame
local titleLabel: TextLabel
local statusLabel: TextLabel
local bar: Frame
local zoneFrame: Frame
local cursor: Frame
local throwButton: TextButton

local session: { [string]: any }? = nil
local hits, misses = 0, 0
local waiting = false
local lasso: { Instance } = {}

local function clearLasso()
	for _, instance in lasso do
		instance:Destroy()
	end
	table.clear(lasso)
end

-- Corde visuelle entre la main du joueur et la créature (purement local)
local function createLasso(model: Model?)
	clearLasso()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local target = model and model.PrimaryPart
	if not root or not target then
		return
	end
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(1, 0.5, -0.5)
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Parent = target
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Width0 = 0.25
	beam.Width1 = 0.25
	beam.CurveSize0 = 2
	beam.CurveSize1 = -2
	beam.Color = ColorSequence.new(Color3.fromRGB(200, 160, 90))
	beam.FaceCamera = true
	beam.Parent = root
	lasso = { a0, a1, beam }
end

local function updateZone()
	if not session then
		return
	end
	local center = session.Centers[hits + 1] or session.Centers[#session.Centers]
	zoneFrame.Size = UDim2.fromScale(session.Width, 1)
	zoneFrame.Position = UDim2.fromScale(center - session.Width / 2, 0)
	statusLabel.Text = ("Réussites %d/%d   •   Ratés %d/%d"):format(hits, session.HitsNeeded, misses, session.MaxMisses)
end

local THROW_ACTION = "CaptureThrow"

local function close(message: string?, kind: string?)
	ContextActionService:UnbindAction(THROW_ACTION)
	session = nil
	waiting = false
	panel.Visible = false
	clearLasso()
	if message and message ~= "" then
		notify(message, kind or "Info")
	end
end

local function throw()
	if not session or waiting then
		return
	end
	local now = Workspace:GetServerTimeNow()
	if now < session.Start then
		return -- le curseur n'a pas encore démarré
	end
	waiting = true
	local sessionId = session.SessionId
	local ok, response = pcall(function()
		return actionRemote:InvokeServer("Hit", sessionId, now)
	end)
	waiting = false
	if not session or session.SessionId ~= sessionId then
		return
	end
	if not ok or type(response) ~= "table" then
		close("Erreur réseau pendant la capture.", "Error")
		return
	end

	if response.Result == "Hit" or response.Result == "Miss" then
		hits, misses = response.Hits, response.Misses
		cursor.BackgroundColor3 = if response.Result == "Hit" then Color3.fromRGB(90, 255, 120) else Color3.fromRGB(255, 80, 80)
		task.delay(0.2, function()
			cursor.BackgroundColor3 = Color3.new(1, 1, 1)
		end)
		updateZone()
	elseif response.Result == "Ended" then
		-- Le serveur a déjà envoyé la notification (capturée / échappée)
		close(if response.Outcome == "Cancelled" then response.Message else nil)
	else
		close()
	end
end

local function onCaptureStart(data: { [string]: any })
	session = data
	hits, misses = 0, 0
	titleLabel.Text = ('🪢 Capture : %s <font color="#%s">[%s]</font>'):format(data.Label, data.RarityColor:ToHex(), data.RarityName)
	panel.Visible = true
	updateZone()
	createLasso(data.Model)

	-- Espace lance le lasso pendant la capture (et ne fait plus sauter le personnage)
	ContextActionService:BindAction(THROW_ACTION, function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			throw()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Space)
end

function CaptureUI.Init(screen: ScreenGui, notifyFn: (string, string) -> ())
	notify = notifyFn
	actionRemote = Remotes.Get("CaptureAction")

	panel = Instance.new("Frame")
	panel.Name = "Capture"
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -110)
	panel.Size = UDim2.new(0.9, 0, 0, 170)
	panel.BackgroundColor3 = Theme.Colors.Panel
	panel.Visible = false
	panel.Parent = screen
	Theme.Corner(panel, 14)
	Theme.Stroke(panel, 3)
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = Vector2.new(560, 170)
	constraint.Parent = panel

	titleLabel = Theme.Label({ Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(10, 6), RichText = true, Text = "", Parent = panel })
	statusLabel = Theme.Label({ Size = UDim2.new(1, -20, 0, 20), Position = UDim2.fromOffset(10, 38), TextColor3 = Color3.fromRGB(210, 210, 220), Text = "", Parent = panel })

	bar = Instance.new("Frame")
	bar.Position = UDim2.fromOffset(20, 66)
	bar.Size = UDim2.new(1, -40, 0, 30)
	bar.BackgroundColor3 = Color3.fromRGB(70, 75, 95)
	bar.ClipsDescendants = true
	bar.Parent = panel
	Theme.Corner(bar, 8)

	zoneFrame = Instance.new("Frame")
	zoneFrame.BackgroundColor3 = Color3.fromRGB(80, 220, 110)
	zoneFrame.BorderSizePixel = 0
	zoneFrame.Parent = bar

	cursor = Instance.new("Frame")
	cursor.AnchorPoint = Vector2.new(0.5, 0)
	cursor.Size = UDim2.new(0, 6, 1, 0)
	cursor.BackgroundColor3 = Color3.new(1, 1, 1)
	cursor.BorderSizePixel = 0
	cursor.ZIndex = 2
	cursor.Parent = bar

	throwButton = Theme.Button({
		Position = UDim2.new(0.5, -170, 0, 108),
		Size = UDim2.fromOffset(220, 48),
		BackgroundColor3 = Color3.fromRGB(240, 180, 40),
		Text = "🪢 LANCER ! (Espace)",
		Parent = panel,
	})
	throwButton.Activated:Connect(throw)

	local cancel = Theme.Button({
		Position = UDim2.new(0.5, 60, 0, 108),
		Size = UDim2.fromOffset(110, 48),
		BackgroundColor3 = Color3.fromRGB(200, 60, 60),
		Text = "Abandonner",
		Parent = panel,
	})
	cancel.Activated:Connect(function()
		if session then
			local sessionId = session.SessionId
			task.spawn(function()
				pcall(function()
					actionRemote:InvokeServer("Cancel", sessionId)
				end)
			end)
			close("Capture annulée.", "Info")
		end
	end)

	-- Curseur : même formule que le serveur (CreatureUtil.CursorPosition)
	RunService.RenderStepped:Connect(function()
		if session then
			local now = Workspace:GetServerTimeNow()
			local position = if now < session.Start then 0 else CreatureUtil.CursorPosition(session.Start, session.Speed, now)
			cursor.Position = UDim2.fromScale(position, 0)
		end
	end)

	Remotes.Get("CaptureStart").OnClientEvent:Connect(onCaptureStart)
	Remotes.Get("CaptureEnded").OnClientEvent:Connect(function(sessionId, _outcome, message)
		if session and session.SessionId == sessionId then
			close(message, "Info")
		end
	end)
end

return CaptureUI
