--[[
	AnimalsUI.lua
	=============
	Fenêtre "🐾 Mes animaux" :
	  • Inventaire : les animaux achetés (ou gagnés) qui ne sont pas encore dans un enclos.
	    Pour chacun : un bouton par enclos compatible ("→ Enclos 2") pour l'y placer.
	  • Dans tes enclos : chaque enclos et ses animaux, avec "📦 Retirer" (retour à l'inventaire).
	  • ⭐ : épingler / désépingler l'animal dans la vitrine de prestige (devant la parcelle).
	Tout est validé par le serveur (RemoteFunction "AnimalAction").
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ItemUtil = require(ReplicatedStorage.Shared.ItemUtil)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(script.Parent.Theme)

local AnimalsUI = {}

local StateController
local notify: (string, string) -> ()
local actionRemote: RemoteFunction
local window: Frame
local list: ScrollingFrame
local busy = false

local function label(speciesId: string, variantId: string): string
	local species = Config.Animals[speciesId]
	if not species then
		return speciesId
	end
	local adjective = ItemUtil.VariantAdjective(species, variantId)
	return species.Icon .. " " .. species.DisplayName .. (if adjective ~= "" then " " .. adjective else "")
end

local function sortedPens(): { { Key: string, Pen: any } }
	local result = {}
	for key, pen in StateController.Get("Pens") or {} do
		if pen.Placed then
			table.insert(result, { Key = key, Pen = pen })
		end
	end
	table.sort(result, function(a, b)
		return (tonumber(a.Key) or 0) < (tonumber(b.Key) or 0)
	end)
	return result
end

local rebuild

local function act(...)
	if busy then
		return
	end
	busy = true
	local args = { ... }
	local ok, success, message = pcall(function()
		return actionRemote:InvokeServer(table.unpack(args))
	end)
	busy = false
	if ok then
		notify(message or "?", if success then "Success" else "Error")
	else
		notify("Erreur réseau.", "Error")
	end
end

local function header(text: string, order: number)
	Theme.Label({ Size = UDim2.new(1, -8, 0, 28), LayoutOrder = order, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Theme.Colors.Coins, Text = text, Parent = list })
end

local function row(order: number, text: string, variantId: string): Frame
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, -8, 0, 46)
	frame.LayoutOrder = order
	frame.BackgroundColor3 = Color3.fromRGB(50, 56, 75)
	frame.Parent = list
	Theme.Corner(frame, 10)
	local variant = ItemUtil.GetVariant(variantId)
	Theme.Label({
		Size = UDim2.new(0.42, -10, 1, -10),
		Position = UDim2.fromOffset(10, 5),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = if variantId == "Normal" then Theme.Colors.Text else variant.Color,
		Text = text,
		Parent = frame,
	})
	local buttons = Instance.new("Frame")
	buttons.Name = "Buttons"
	buttons.AnchorPoint = Vector2.new(1, 0)
	buttons.Position = UDim2.new(1, -6, 0, 5)
	buttons.Size = UDim2.new(0.58, -6, 1, -10)
	buttons.BackgroundTransparency = 1
	buttons.Parent = frame
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = buttons
	return buttons
end

local function button(parent: Instance, text: string, color: Color3, width: number, order: number, onClick: () -> ())
	local b = Theme.Button({ Size = UDim2.new(0, width, 1, 0), BackgroundColor3 = color, Text = text, LayoutOrder = order, Parent = parent })
	b.Activated:Connect(onClick)
end

rebuild = function()
	for _, child in list:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	local picks = StateController.Get("ShowcasePicks") or {}
	local pens = sortedPens()
	local inventory = StateController.Get("AnimalInventory") or {}

	header(("📦 Dans ton inventaire (%d/%d)"):format(#inventory, Config.Pens.InventoryCapacity), 1)
	if #inventory == 0 then
		Theme.Label({ Size = UDim2.new(1, -8, 0, 24), LayoutOrder = 2, TextColor3 = Color3.fromRGB(190, 195, 210), Text = "Aucun animal en attente. Achète-en au stand 🐄 ANIMAUX.", Parent = list })
	end
	for i, animal in inventory do
		local buttons = row(10 + i, label(animal.Species, animal.Variant), animal.Variant)
		local pinned = table.find(picks, "A:" .. animal.Id) ~= nil
		button(buttons, if pinned then "⭐" else "☆", if pinned then Color3.fromRGB(230, 170, 40) else Color3.fromRGB(90, 95, 110), 40, 0, function()
			act("Pin", animal.Id)
		end)
		local options = 0
		for index, entry in pens do
			local pen = entry.Pen
			local compatible = (pen.Species == nil or pen.Species == animal.Species) and #pen.Animals < Config.Pens.Capacity
			if compatible and options < 3 then
				options += 1
				local text = ("→ Enclos %d%s"):format(index, if pen.Species == nil then " (vide)" else "")
				button(buttons, text, Color3.fromRGB(60, 170, 80), 130, options, function()
					act("Place", animal.Id, entry.Key)
				end)
			end
		end
		if options == 0 then
			Theme.Label({ Size = UDim2.new(0, 190, 1, 0), LayoutOrder = 1, TextColor3 = Color3.fromRGB(255, 170, 120), Text = "Aucun enclos libre (🔨 Construire)", Parent = buttons })
		end
	end

	header("🏠 Dans tes enclos", 500)
	if #pens == 0 then
		Theme.Label({ Size = UDim2.new(1, -8, 0, 24), LayoutOrder = 501, TextColor3 = Color3.fromRGB(190, 195, 210), Text = "Aucun enclos : construis-en un avec 🔨 Construire.", Parent = list })
	end
	local order = 502
	for index, entry in pens do
		local pen = entry.Pen
		local species = pen.Species and Config.Animals[pen.Species]
		order += 1
		Theme.Label({
			Size = UDim2.new(1, -8, 0, 22),
			LayoutOrder = order,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = ("Enclos %d : %s  (%d/%d)"):format(index, if species then species.Icon .. " " .. species.DisplayName else "vide", #pen.Animals, Config.Pens.Capacity),
			Parent = list,
		})
		for _, animal in pen.Animals do
			order += 1
			local buttons = row(order, label(pen.Species, animal.Variant), animal.Variant)
			local pinned = table.find(picks, "A:" .. tostring(animal.Id)) ~= nil
			button(buttons, if pinned then "⭐" else "☆", if pinned then Color3.fromRGB(230, 170, 40) else Color3.fromRGB(90, 95, 110), 40, 0, function()
				act("Pin", tostring(animal.Id))
			end)
			button(buttons, "📦 Retirer", Color3.fromRGB(70, 120, 200), 120, 1, function()
				act("Store", tostring(animal.Id))
			end)
		end
	end
end

function AnimalsUI.Open()
	rebuild()
	window.Visible = true
end

function AnimalsUI.Init(screen: ScreenGui, HUD, stateController, notifyFn)
	StateController = stateController
	notify = notifyFn
	actionRemote = Remotes.Get("AnimalAction")
	local content
	window, content = Theme.Window(screen, "AnimalsWindow", "🐾 Mes animaux", Vector2.new(720, 560))
	Theme.Label({ Size = UDim2.new(1, 0, 0, 20), TextColor3 = Color3.fromRGB(200, 205, 220), Text = "Place tes animaux dans un enclos (une espèce par enclos). ⭐ = les montrer dans la vitrine.", Parent = content })
	list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(0, 26)
	list.Size = UDim2.new(1, 0, 1, -26)
	list.BackgroundTransparency = 1
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = content
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 5)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	AnimalsUI.Button = HUD.AddButton("AnimalsButton", "🐾 Mes animaux", Color3.fromRGB(200, 130, 70), 14, function()
		if window.Visible then
			window.Visible = false
		else
			AnimalsUI.Open()
		end
	end)

	StateController.Changed:Connect(function(key)
		if window.Visible and (key == "*" or key == "AnimalInventory" or key == "Pens" or key == "ShowcasePicks") then
			rebuild()
		end
	end)
end

return AnimalsUI
