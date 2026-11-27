--[[
	FenceBuilder.lua
	================
	Clôture continue autour d'une parcelle ENTIÈRE (pas les enclos), qui suit son
	agrandissement, avec une ouverture à l'entrée encadrée de deux grands poteaux à lanterne.
	Style donné par le cosmétique "Clôture de parcelle" (Config.Cosmetics, catégorie PlotFence) :
	  "Rail"   : poteaux + 2 barres (bois, bonbon, néon...)
	  "Picket" : piquets serrés à bout pointu + barres (blanc, doré...)
	  "Wall"   : muret plein avec chaperon (pierre)
	  "Panel"  : panneaux pleins décorés d'un motif (étoiles, cœurs, Biscotte, diamants...)

	  FenceBuilder.Build(folder, plotCFrame, width, depth, style, gateWidth, baseTop)
	    plotCFrame : repère de l'entrée (-Z = vers l'allée, +Z = intérieur)
]]

local ArtKit = require(script.Parent.ArtKit)
local PatternBuilder = require(script.Parent.PatternBuilder)

local FenceBuilder = {}

local HEIGHT = 3.4
local POST_SPACING = 6

local function solid(extra: { [string]: any }?): { [string]: any }
	local o = { CanCollide = true }
	if extra then
		for k, v in extra do
			o[k] = v
		end
	end
	return o
end

-- Un tronçon droit de a vers b (coordonnées locales de la parcelle, au niveau du sol)
local function run(folder: Instance, frame: CFrame, a: Vector3, b: Vector3, style: any, outward: Vector3)
	local delta = b - a
	local length = delta.Magnitude
	if length < 0.5 then
		return
	end
	local dir = CFrame.lookAt(a, b) -- -Z local = le long du tronçon
	local posts = math.max(1, math.ceil(length / POST_SPACING))
	local step = length / posts
	local kind = style.Style or "Rail"

	for i = 0, posts do
		local p = frame * dir * CFrame.new(0, 0, -i * step)
		local postH = if kind == "Wall" then HEIGHT * 0.85 else HEIGHT
		ArtKit.Block(folder, "FencePost", Vector3.new(0.8, postH, 0.8), p * CFrame.new(0, postH / 2, 0), style.Post, style.Material, solid())
		ArtKit.Ball(folder, "FenceCap", 0.95, p * CFrame.new(0, postH + 0.3, 0), style.Cap, if style.Material == Enum.Material.Neon then Enum.Material.Neon else Enum.Material.SmoothPlastic)
	end

	local mid = frame * dir * CFrame.new(0, 0, -length / 2)
	if kind == "Wall" then
		ArtKit.Block(folder, "FenceWall", Vector3.new(0.6, HEIGHT * 0.7, length), mid * CFrame.new(0, HEIGHT * 0.35, 0), style.Color, style.Material, solid())
		ArtKit.Block(folder, "FenceWallCap", Vector3.new(0.9, 0.3, length), mid * CFrame.new(0, HEIGHT * 0.72, 0), style.Cap, style.Material)
		return
	end
	-- Barres hautes et basses sur toute la longueur
	for _, h in { 1.1, 2.5 } do
		ArtKit.Block(folder, "FenceRail", Vector3.new(0.3, 0.45, length), mid * CFrame.new(0, h, 0), style.Color, style.Material, solid())
	end
	if kind == "Picket" then
		local count = math.floor(length / 1.4)
		for i = 1, count - 1 do
			local p = frame * dir * CFrame.new(0, 0, -i * (length / count))
			ArtKit.Block(folder, "Picket", Vector3.new(0.25, HEIGHT - 0.5, 0.6), p * CFrame.new(0, (HEIGHT - 0.5) / 2, 0), style.Color, style.Material)
			ArtKit.Wedge(folder, "PicketTip", Vector3.new(0.25, 0.5, 0.3), p * CFrame.new(0, HEIGHT - 0.25, -0.15) * CFrame.Angles(0, math.pi, 0), style.Color, style.Material)
			ArtKit.Wedge(folder, "PicketTip", Vector3.new(0.25, 0.5, 0.3), p * CFrame.new(0, HEIGHT - 0.25, 0.15), style.Color, style.Material)
		end
	elseif kind == "Panel" then
		-- Un panneau par intervalle entre poteaux, motif sur la face extérieure
		for i = 0, posts - 1 do
			local center = frame * dir * CFrame.new(0, 1.8, -(i + 0.5) * step)
			local panel = ArtKit.Block(folder, "FencePanel", Vector3.new(0.2, 1.6, step - 0.9), center, style.Color, style.Material)
			-- Face qui regarde dehors : on compare la normale à la direction "outward"
			local face = if panel.CFrame.RightVector:Dot(frame:VectorToWorldSpace(outward)) > 0 then Enum.NormalId.Right else Enum.NormalId.Left
			PatternBuilder.Apply(panel, face, style.Pattern, { Parent = folder, Spacing = 2, Size = 1.1, MaxCount = 3 })
		end
	end
end

function FenceBuilder.Build(folder: Instance, plotCFrame: CFrame, width: number, depth: number, style: any, gateWidth: number, baseTop: number)
	local frame = plotCFrame * CFrame.new(0, baseTop, 0)
	local hw = width / 2
	local gate = gateWidth / 2
	-- Avant (deux tronçons de chaque côté de l'entrée), fond, côtés
	run(folder, frame, Vector3.new(-hw, 0, 0), Vector3.new(-gate, 0, 0), style, Vector3.new(0, 0, -1))
	run(folder, frame, Vector3.new(gate, 0, 0), Vector3.new(hw, 0, 0), style, Vector3.new(0, 0, -1))
	run(folder, frame, Vector3.new(-hw, 0, depth), Vector3.new(hw, 0, depth), style, Vector3.new(0, 0, 1))
	run(folder, frame, Vector3.new(-hw, 0, 0), Vector3.new(-hw, 0, depth), style, Vector3.new(-1, 0, 0))
	run(folder, frame, Vector3.new(hw, 0, 0), Vector3.new(hw, 0, depth), style, Vector3.new(1, 0, 0))

	-- Portail d'entrée : deux grands poteaux avec lanterne
	for _, sx in { -1, 1 } do
		local p = frame * CFrame.new(sx * gate, 0, 0)
		ArtKit.Block(folder, "GatePost", Vector3.new(1.4, HEIGHT + 2.4, 1.4), p * CFrame.new(0, (HEIGHT + 2.4) / 2, 0), style.Post, style.Material, solid())
		local lamp = ArtKit.Block(folder, "GateLantern", Vector3.new(1, 1.2, 1), p * CFrame.new(0, HEIGHT + 3.1, 0), Color3.fromRGB(255, 225, 150), Enum.Material.Neon)
		ArtKit.Light(lamp, Color3.fromRGB(255, 210, 140), 14, 1)
		local roof = ArtKit.Block(folder, "GateRoof", Vector3.new(1.8, 0.3, 1.8), p * CFrame.new(0, HEIGHT + 3.85, 0), style.Cap, Enum.Material.SmoothPlastic)
		-- Lanterne remplaçable : Scenery.Lantern (posée en haut du poteau)
		ArtKit.Swap("Scenery", "Lantern", { lamp, roof }, folder, p * CFrame.new(0, HEIGHT + 2.4, 0), 2)
	end
end

return FenceBuilder
