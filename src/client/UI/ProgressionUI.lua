--[[
	ProgressionUI.lua
	=================
	Deux fenêtres de progression (phase 7) :
	  • "🧑‍🌾 Aides" : fermier et soigneur PNJ (niveau requis, niveau actuel, effet,
	    prix du prochain niveau, dernière tournée).
	  • "⭐ Rebirth" : conditions, coût, ce qui est perdu / gardé, multiplicateur
	    obtenu, et confirmation en deux clics.
	Les actions passent par HelperAction et Rebirth (validées par le serveur).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(script.Parent.Theme)

local ProgressionUI = {}

local player = Players.LocalPlayer
local StateController
local notify: (string, string) -> ()
local busy = false

local helpersWindow: Frame
local helpersList: ScrollingFrame
local rebirthWindow: Frame
local rebirthText: TextLabel
local rebirthButton: TextButton
local rebirthArmed = false

local function invoke(remoteName: string, ...: any): boolean
	if busy then
		return false
	end
	busy = true
	local args = table.pack(...)
	local ok, success, message = pcall(function()
		return Remotes.Get(remoteName):InvokeServer(table.unpack(args, 1, args.n))
	end)
	busy = false
	if ok then
		notify(message or "", if success then "Success" else "Error")
		return success == true
	end
	return false
end

--------------------------------------------------------------------------
-- Aides PNJ
--------------------------------------------------------------------------

local function rebuildHelpers()
	for _, child in helpersList:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local helpers = StateController.Get("Helpers") or {}
	local level = StateController.Get("Level") or 1

	local ids = {}
	for id in Config.Helpers do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return Config.Helpers[a].Order < Config.Helpers[b].Order
	end)

	for order, helperId in ids do
		local def = Config.Helpers[helperId]
		local current = helpers[helperId] or 0
		local requiredLevel = Config.Progression.Unlocks[helperId] or 1
		local nextLevel = def.Levels[current + 1]
		local info = def.Levels[math.max(current, 1)]
		local effect = if helperId == "Farmer"
			then ("%d cases toutes les %d s"):format(info.Actions, info.Interval)
			else ("%d enclos toutes les %d s"):format(info.Pens, info.Interval)

		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -8, 0, 96)
		row.LayoutOrder = order
		row.BackgroundColor3 = Color3.fromRGB(50, 56, 75)
		row.Parent = helpersList
		Theme.Corner(row, 10)

		Theme.Label({
			Size = UDim2.new(0.6, -10, 0, 28),
			Position = UDim2.fromOffset(10, 6),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = ("%s %s   %s"):format(def.Icon, def.DisplayName, if current > 0 then ("niv. %d/%d"):format(current, #def.Levels) else "(pas embauché)"),
			Parent = row,
		})
		local lastRun = player:GetAttribute(helperId .. "LastRun")
		Theme.Label({
			Size = UDim2.new(0.6, -10, 0, 52),
			Position = UDim2.fromOffset(10, 36),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
			TextColor3 = Color3.fromRGB(200, 200, 210),
			Text = (if helperId == "Farmer" then "Récolte et replante tout seul" else "Nourrit les animaux et ramasse la production")
				.. ("\n%s%s"):format(if current > 0 then "Actuel : " else "Niv. 1 : ", effect)
				.. (if lastRun then "\nDernière tournée : " .. tostring(lastRun) else ""),
			Parent = row,
		})

		local text, color, enabled
		if level < requiredLevel then
			text, color, enabled = ("🔒 Niveau %d"):format(requiredLevel), Color3.fromRGB(90, 90, 100), false
		elseif not nextLevel then
			text, color, enabled = "✅ Niveau max", Color3.fromRGB(90, 90, 100), false
		else
			text = ("%s 💰%s"):format(if current == 0 then "Embaucher" else "Améliorer", Format.Number(nextLevel.Price))
			color, enabled = Color3.fromRGB(240, 180, 40), true
		end
		local button = Theme.Button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.new(0.4, -20, 0, 48),
			BackgroundColor3 = color,
			Text = text,
			AutoButtonColor = enabled,
			Parent = row,
		})
		button.Activated:Connect(function()
			if enabled then
				invoke("HelperAction", helperId)
			end
		end)
	end
end

--------------------------------------------------------------------------
-- Rebirth
--------------------------------------------------------------------------

local function rebuildRebirth()
	local rebirths = StateController.Get("Rebirths") or 0
	local level = StateController.Get("Level") or 1
	local coins = StateController.Get("Coins") or 0
	local cost = math.floor(Config.Rebirth.BaseCost * Config.Rebirth.CostGrowth ^ rebirths)
	local requiredLevel = Config.Progression.Unlocks.Rebirth
	local per = Config.Rebirth.CoinMultiplierPerRebirth
	local nowMult = 1 + per * rebirths
	local nextMult = 1 + per * (rebirths + 1)

	local levelOk = level >= requiredLevel
	local coinsOk = coins >= cost
	local function mark(ok: boolean): string
		return if ok then '<font color="#7CFF7C">✔</font>' else '<font color="#FF7C7C">✖</font>'
	end
	rebirthText.Text = table.concat({
		("Rebirths : <b>%d</b>   •   Gains de Coins : <b>x%s</b> → <b>x%s</b>"):format(rebirths, tostring(nowMult), tostring(nextMult)),
		"",
		("%s Niveau %d requis (tu es niveau %d)"):format(mark(levelOk), requiredLevel, level),
		("%s %s Coins requis (tu as %s)"):format(mark(coinsOk), Format.Number(cost), Format.Number(coins)),
		"",
		'<font color="#FF9C9C">Perdu :</font> Coins, agrandissements, champs (1 champ gardé), plantes, graines, enclos et animaux, bâtiments, inventaire.',
		'<font color="#9CFF9C">Gardé :</font> créatures, Index, zones, socles (rangés), niveau et XP, aides PNJ, boosts.',
	}, "\n")
	rebirthArmed = false
	rebirthButton.Text = "⭐ Renaître"
	rebirthButton.BackgroundColor3 = if levelOk and coinsOk then Color3.fromRGB(190, 120, 255) else Color3.fromRGB(90, 90, 100)
end

--------------------------------------------------------------------------
-- Init
--------------------------------------------------------------------------

function ProgressionUI.Init(screen: ScreenGui, HUD, stateController, notifyFn: (string, string) -> ())
	StateController = stateController
	notify = notifyFn

	-- Fenêtre des aides
	local content
	helpersWindow, content = Theme.Window(screen, "Helpers", "🧑‍🌾 Aides automatiques", Vector2.new(560, 320))
	helpersList = Instance.new("ScrollingFrame")
	helpersList.Size = UDim2.fromScale(1, 1)
	helpersList.BackgroundTransparency = 1
	helpersList.BorderSizePixel = 0
	helpersList.ScrollBarThickness = 6
	helpersList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	helpersList.CanvasSize = UDim2.new()
	helpersList.Parent = content
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = helpersList

	HUD.AddButton("HelpersButton", "🧑‍🌾 Aides", Color3.fromRGB(70, 130, 60), 7, function()
		helpersWindow.Visible = not helpersWindow.Visible
		if helpersWindow.Visible then
			rebuildHelpers()
		end
	end)

	-- Fenêtre du rebirth
	local rebirthContent
	rebirthWindow, rebirthContent = Theme.Window(screen, "Rebirth", "⭐ Rebirth", Vector2.new(560, 380))
	rebirthText = Theme.Label({
		Size = UDim2.new(1, 0, 1, -64),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		TextScaled = false,
		TextSize = 18,
		RichText = true,
		Text = "",
		Parent = rebirthContent,
	})
	rebirthButton = Theme.Button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.fromOffset(240, 52),
		Text = "⭐ Renaître",
		Parent = rebirthContent,
	})
	rebirthButton.Activated:Connect(function()
		if not rebirthArmed then
			-- 1er clic : confirmation (le rebirth remet la ferme à zéro)
			rebirthArmed = true
			rebirthButton.Text = "Sûr ? Clique encore"
			rebirthButton.BackgroundColor3 = Color3.fromRGB(220, 70, 70)
			task.delay(4, function()
				if rebirthArmed then
					rebuildRebirth()
				end
			end)
			return
		end
		if invoke("Rebirth") then
			rebirthWindow.Visible = false
		else
			rebuildRebirth()
		end
	end)

	HUD.AddButton("RebirthButton", "⭐ Rebirth", Color3.fromRGB(150, 90, 220), 8, function()
		rebirthWindow.Visible = not rebirthWindow.Visible
		if rebirthWindow.Visible then
			rebuildRebirth()
		end
	end)

	StateController.Changed:Connect(function(key)
		if helpersWindow.Visible and (key == "*" or key == "Helpers" or key == "Level") then
			rebuildHelpers()
		end
		if rebirthWindow.Visible and not rebirthArmed and (key == "*" or key == "Coins" or key == "Level" or key == "Rebirths") then
			rebuildRebirth()
		end
	end)
end

return ProgressionUI
