--[[
	Theme.lua
	=========
	Couleurs et petites fonctions de création d'UI partagées par tous les écrans.
]]

local Theme = {}

Theme.Font = Enum.Font.FredokaOne

Theme.Colors = {
	Panel = Color3.fromRGB(35, 40, 55),
	PanelStroke = Color3.fromRGB(15, 18, 28),
	Text = Color3.fromRGB(255, 255, 255),
	Coins = Color3.fromRGB(255, 210, 60),
	Rebirth = Color3.fromRGB(190, 120, 255),
	Button = Color3.fromRGB(80, 170, 90),
}

-- Couleur de fond des notifications selon leur type
Theme.NotifyColors = {
	Info = Color3.fromRGB(60, 120, 200),
	Success = Color3.fromRGB(60, 170, 80),
	Error = Color3.fromRGB(200, 60, 60),
	Rare = Color3.fromRGB(150, 80, 220),
	Mutation = Color3.fromRGB(230, 170, 30),
}

function Theme.Corner(parent: Instance, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 10)
	corner.Parent = parent
	return corner
end

function Theme.Stroke(parent: Instance, thickness: number?, color: Color3?)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = thickness or 2
	stroke.Color = color or Theme.Colors.PanelStroke
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

-- TextLabel transparent avec la police du jeu
function Theme.Label(props: { [string]: any }): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Theme.Font
	label.TextColor3 = Theme.Colors.Text
	label.TextScaled = true
	local anyLabel: any = label
	for key, value in props do
		anyLabel[key] = value
	end
	return label
end

-- Bouton texte arrondi
function Theme.Button(props: { [string]: any }): TextButton
	local button = Instance.new("TextButton")
	button.BackgroundColor3 = Theme.Colors.Button
	button.Font = Theme.Font
	button.TextScaled = true
	button.TextColor3 = Theme.Colors.Text
	button.AutoButtonColor = true
	local anyButton: any = button
	for key, value in props do
		anyButton[key] = value
	end
	Theme.Corner(button, 10)
	Theme.Stroke(button, 2)

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 5)
	padding.PaddingBottom = UDim.new(0, 5)
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 6)
	padding.Parent = button
	return button
end

-- Fenêtre centrée avec titre et bouton de fermeture. Renvoie (fenêtre, zone de contenu, bouton X).
-- maxSize : taille max en pixels ; la fenêtre rétrécit sur les petits écrans (mobile).
function Theme.Window(parent: Instance, name: string, title: string, maxSize: Vector2): (Frame, Frame, TextButton)
	local window = Instance.new("Frame")
	window.Name = name
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.5)
	window.Size = UDim2.fromScale(0.92, 0.8)
	window.BackgroundColor3 = Theme.Colors.Panel
	window.Visible = false
	window.Parent = parent
	Theme.Corner(window, 14)
	Theme.Stroke(window, 3)

	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = maxSize
	constraint.Parent = window

	Theme.Label({
		Name = "Title",
		Size = UDim2.new(1, -70, 0, 36),
		Position = UDim2.fromOffset(14, 8),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = title,
		Parent = window,
	})

	local close = Theme.Button({
		Name = "Close",
		Size = UDim2.fromOffset(36, 36),
		Position = UDim2.new(1, -46, 0, 8),
		BackgroundColor3 = Color3.fromRGB(200, 60, 60),
		Text = "X",
		Parent = window,
	})
	close.Activated:Connect(function()
		window.Visible = false
	end)

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.Position = UDim2.fromOffset(12, 52)
	content.Size = UDim2.new(1, -24, 1, -64)
	content.BackgroundTransparency = 1
	content.Parent = window

	return window, content, close
end

return Theme
