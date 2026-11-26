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

return Theme
