--[[
	GuideUI.lua
	===========
	Fenêtre "❓ Guide" : explique simplement chaque système du jeu (un onglet par sujet),
	et permet de relancer le tutoriel.
]]

local Theme = require(script.Parent.Theme)

local GuideUI = {}

local PAGES = {
	{
		Title = "🌱 Cultures",
		Text = "1. Achète des graines au stand 🌱 GRAINES (devant le spawn).\n2. Choisis une graine dans la barre en bas de l'écran.\n3. Va dans ton champ et appuie sur E sur une case de terre pour planter.\n4. La plante pousse en 3 étapes. Quand elle affiche « Prêt ! », appuie sur E pour récolter.\n5. Au stand 💰 VENTE, choisis ce que tu vends (objet par objet, ou tout), et garde le reste pour nourrir tes animaux et cuisiner.\n\nAstuces : les cases grises se débloquent avec E. Une récolte peut muter (Dorée, Arc-en-ciel...) et valoir beaucoup plus. Le stock rare de la boutique change toutes les 5 minutes.",
	},
	{
		Title = "🐄 Animaux",
		Text = "1. Construis un enclos : 🔨 Construire > Enclos, puis pose-le sur ta parcelle.\n2. Achète un animal au stand 🐄 ANIMAUX : il arrive dans 🐾 Mes animaux.\n3. Ouvre 🐾 Mes animaux et place-le dans un enclos (une seule espèce par enclos, 4 animaux max).\n4. Remplis la mangeoire (E) avec les récoltes que l'animal aime.\n5. Ramasse sa production dans la caisse (E) : œufs, lait, laine...\n\nAstuces : un animal peut naître Doré, Arc-en-ciel, Légendaire ou Mythique. Le bouton ⭐ de 🐾 Mes animaux le montre dans ta vitrine.",
	},
	{
		Title = "🥖 Bâtiments et recettes",
		Text = "Les bâtiments transforment tes récoltes et productions en produits qui valent plus cher.\n\n1. Construis un bâtiment : 🔨 Construire > Bâtiments (la 🥖 Boulangerie en premier).\n2. Approche-toi de sa PORTE et appuie sur E : la fenêtre des recettes s'ouvre.\n3. Choisis une recette (ex. Pain = 4 blés) et clique sur « Lancer x1 » ou « x5 ».\n4. Attends la fin (la fumée sort de la cheminée pendant la production).\n5. Reviens à la porte et clique sur « Récupérer » : le produit va dans ton 🎒 Sac.\n\nAstuces : améliore le bâtiment pour produire plus vite et plusieurs choses à la fois. Les recettes rares demandent des ingrédients Dorés ou mieux.",
	},
	{
		Title = "🍴 Consommables et boosts",
		Text = "Certains produits se mangent et donnent un BOOST temporaire :\n• 🏃 Vitesse (pain, fraises)\n• ⭐ XP (gâteau, pastèque)\n• 💰 Coins (crème, beurre)\n• 🪢 Capture (fromage)\n• ⚔️ Combat (fromage de chèvre)\n\nOuvre 🎒 Sac et clique sur 🍴 à côté du produit. Tes boosts actifs s'affichent en haut à droite avec leur temps restant. Plus le produit est rare, plus le boost est fort et long.",
	},
	{
		Title = "🧭 Expéditions et capture",
		Text = "1. Va au portail violet 🧭 EXPÉDITIONS (derrière le spawn) et choisis une zone.\n2. Des créatures sauvages apparaissent : approche-toi et appuie sur E.\n3. Choisis 🎯 Sûr (réussite garantie, un peu plus dur) ou ⚡ Rapide (plus facile, mais elle peut s'échapper).\n4. Clique quand le curseur est dans la zone verte, autant de fois que demandé.\n5. Rentre par le portail vert de la zone.\n\nLes créatures très rares sont annoncées et brillent : fonce ! Chaque zone a un cheval sauvage à capturer, qui devient une monture.",
	},
	{
		Title = "🏛️ Socles et vitrine",
		Text = "• Socles : construis-en avec 🔨 Construire > Socle, puis 📖 Créatures > 🏛️ Exposer. Une créature exposée rapporte des Coins chaque seconde, même quand tu n'es pas connecté.\n• Vitrine de prestige : devant ta parcelle, elle montre tes plus belles créatures à tous les joueurs. Épingle tes préférées avec ⭐ (dans 📖 Créatures). Les animaux n'y vont que si tu les épingles dans 🐾 Mes animaux.\n• 📚 Index : complète une zone pour une récompense.",
	},
	{
		Title = "⚔️ Donjons",
		Text = "Dès le niveau 8, entre par le portail rouge ⚔️ DONJONS (à gauche du spawn).\n\n• Plusieurs vagues d'ennemis, puis un boss.\n• ⚔️ Attaque : clic ou F (vise automatiquement l'ennemi le plus proche).\n• 💨 Esquive : Q, quand un ennemi devient ROUGE (il va frapper).\n• Le boss fait aussi une attaque de zone : sors du cercle rouge au sol !\n\nRécompenses : Coins, XP, graines rares et œufs de créatures (à couver depuis 🎒 Sac > 🐣). Le boost ⚔️ Combat t'aide beaucoup.",
	},
	{
		Title = "⭐ Rebirth",
		Text = "Quand tu es riche (dès le niveau 15), le bouton ⭐ Rebirth te propose de recommencer ta ferme contre un MULTIPLICATEUR de Coins permanent (x1,5, puis x2...).\n\nTu perds : Coins, champs, enclos, animaux, bâtiments, inventaire.\nTu gardes : créatures, Index, zones débloquées, socles, niveau, aides PNJ.\n\nC'est la meilleure façon d'aller toujours plus loin.",
	},
	{
		Title = "🧑‍🌾 Aides automatiques",
		Text = "Bouton 🧑‍🌾 Aides : embauche des PNJ avec tes Coins, puis améliore-les (5 niveaux). Ils travaillent pour toi sur ta parcelle :\n\n• 🧑‍🌾 Fermier (niveau 5) : récolte les plantes mûres et replante.\n• 🧺 Soigneur (niveau 8) : remplit les mangeoires et ramasse la production des enclos.\n• 🧰 Artisan (niveau 12) : récupère les produits finis des bâtiments et relance la DERNIÈRE recette que tu as lancée, si les ingrédients sont dans ton sac. Il ne lance jamais les recettes rares : celles-là, c'est toi qui décides.\n\nDans la fenêtre d'un bâtiment, le bouton « 🧰 Artisan : oui / non » l'active ou le désactive pour ce bâtiment. Le Game Pass « Aides premium » rend les trois aides 2x plus rapides.",
	},
	{
		Title = "🎁 Récompenses",
		Text = "• 🎡 Roue : 1 tour gratuit par jour (les chances sont affichées).\n• Temps de jeu : un cadeau à 15 min, 30 min, 1 h et 2 h de jeu (panneau en haut à gauche).\n• Quêtes du tutoriel : chacune donne une petite récompense.",
	},
}

function GuideUI.Init(screen: ScreenGui, HUD, restartTutorial: () -> ())
	local window, content = Theme.Window(screen, "GuideWindow", "❓ Guide", Vector2.new(780, 560))

	local tabs = Instance.new("ScrollingFrame")
	tabs.Size = UDim2.new(0, 210, 1, -50)
	tabs.BackgroundTransparency = 1
	tabs.ScrollBarThickness = 4
	tabs.AutomaticCanvasSize = Enum.AutomaticSize.Y
	tabs.CanvasSize = UDim2.new()
	tabs.Parent = content
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = tabs

	local page = Instance.new("ScrollingFrame")
	page.Position = UDim2.fromOffset(220, 0)
	page.Size = UDim2.new(1, -220, 1, 0)
	page.BackgroundColor3 = Color3.fromRGB(50, 56, 75)
	page.ScrollBarThickness = 6
	page.AutomaticCanvasSize = Enum.AutomaticSize.Y
	page.CanvasSize = UDim2.new()
	page.Parent = content
	Theme.Corner(page, 10)
	local pageText = Theme.Label({
		Position = UDim2.fromOffset(12, 10),
		Size = UDim2.new(1, -24, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextScaled = false,
		TextSize = 19,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Font = Enum.Font.Gotham,
		Text = "",
		Parent = page,
	})

	local buttons = {}
	local function show(index: number)
		local p = PAGES[index]
		pageText.Text = ("<b>%s</b>\n\n%s"):format(p.Title, p.Text)
		pageText.RichText = true
		for i, b in buttons do
			b.BackgroundColor3 = if i == index then Color3.fromRGB(230, 140, 40) else Color3.fromRGB(70, 76, 100)
		end
	end
	for i, p in PAGES do
		local b = Theme.Button({ Size = UDim2.new(1, -6, 0, 38), LayoutOrder = i, Text = p.Title, Parent = tabs })
		b.Activated:Connect(function()
			show(i)
		end)
		buttons[i] = b
	end
	local restart = Theme.Button({ Position = UDim2.new(0, 0, 1, -44), Size = UDim2.fromOffset(210, 40), BackgroundColor3 = Color3.fromRGB(60, 170, 80), Text = "🎯 Relancer le tutoriel", Parent = content })
	restart.Activated:Connect(function()
		restartTutorial()
		window.Visible = false
	end)
	show(1)

	HUD.AddButton("GuideButton", "❓ Guide", Color3.fromRGB(90, 110, 200), 15, function()
		window.Visible = not window.Visible
	end)
end

return GuideUI
