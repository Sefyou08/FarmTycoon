--[[
	LeaderboardService.lua
	======================
	Classement des collections les plus rares.
	Score d'un joueur = somme des points de prestige de toutes ses créatures
	(CreatureUtil.GetPrestige : rareté x mutation).

	  • Toutes les Config.Leaderboard.UpdateInterval secondes, les scores des joueurs
	    du serveur sont envoyés dans un OrderedDataStore, puis le top est relu
	    (classement GLOBAL, tous serveurs confondus).
	  • Si le DataStore est inaccessible (Studio sans API), on affiche le classement
	    des joueurs du serveur.
	  • Affichage : un grand panneau près du spawn (SurfaceGui).
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local CreatureUtil = require(ReplicatedStorage.Shared.CreatureUtil)
local Format = require(ReplicatedStorage.Shared.Format)
local DataService = require(script.Parent.DataService)

local LeaderConfig = Config.Leaderboard

local LeaderboardService = {}

local store: OrderedDataStore? = nil
local nameCache: { [number]: string } = {}
local rowLabels: { TextLabel } = {}
local footerLabel: TextLabel

function LeaderboardService:GetScore(data: { [string]: any }): number
	local total = 0
	for _, entry in data.Creatures do
		total += CreatureUtil.GetPrestige(entry.Creature, entry.Mutation)
	end
	return math.floor(total)
end

local function getName(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		nameCache[userId] = player.DisplayName
		return player.DisplayName
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local result = if ok and name then name else ("Joueur " .. userId)
	nameCache[userId] = result
	return result
end

local function buildBoard()
	local position = LeaderConfig.BoardPosition
	local board = Instance.new("Part")
	board.Name = "CollectionLeaderboard"
	board.Anchored = true
	board.Size = Vector3.new(14, 18, 1)
	-- Face avant tournée vers le spawn (centre de la map)
	board.CFrame = CFrame.lookAt(position + Vector3.new(0, 11, 0), Vector3.new(0, 11, 0))
	board.Color = Color3.fromRGB(40, 35, 60)
	board.Material = Enum.Material.SmoothPlastic
	board.Parent = Workspace

	for _, x in { -6, 6 } do
		local post = Instance.new("Part")
		post.Anchored = true
		post.Size = Vector3.new(0.8, 2, 0.8)
		post.CFrame = board.CFrame * CFrame.new(x, -10, 0)
		post.Color = Color3.fromRGB(90, 70, 50)
		post.Material = Enum.Material.Wood
		post.Parent = Workspace
	end

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = board

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = gui

	local function line(order: number, height: number, color: Color3): TextLabel
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 0, height)
		label.LayoutOrder = order
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = color
		label.Text = ""
		label.Parent = gui
		return label
	end
	line(0, 80, Color3.fromRGB(255, 220, 90)).Text = "🏆 Collections les plus rares"
	for i = 1, LeaderConfig.Size do
		rowLabels[i] = line(i, 52, Color3.new(1, 1, 1))
	end
	footerLabel = line(100, 36, Color3.fromRGB(180, 180, 200))
end

-- Met à jour le panneau : entries = { { Name, Score } }
local function render(entries: { { [string]: any } }, isGlobal: boolean)
	for i, label in rowLabels do
		local entry = entries[i]
		if entry then
			local medal = if i == 1 then "🥇" elseif i == 2 then "🥈" elseif i == 3 then "🥉" else ("%d."):format(i)
			label.Text = ("%s %s  —  %s ⭐"):format(medal, entry.Name, Format.Number(entry.Score))
		else
			label.Text = ""
		end
	end
	footerLabel.Text = if isGlobal then "Tous les serveurs • score = prestige total des créatures" else "Ce serveur (classement global indisponible)"
end

local function localEntries(): { { [string]: any } }
	local entries = {}
	for _, player in Players:GetPlayers() do
		local data = DataService:GetData(player)
		if data then
			table.insert(entries, { Name = player.DisplayName, Score = LeaderboardService:GetScore(data) })
		end
	end
	table.sort(entries, function(a, b)
		return a.Score > b.Score
	end)
	return entries
end

local function update()
	if store then
		local ok = pcall(function()
			for _, player in Players:GetPlayers() do
				local data = DataService:GetData(player)
				if data then
					(store :: OrderedDataStore):SetAsync(tostring(player.UserId), LeaderboardService:GetScore(data))
				end
			end
		end)
		local pages
		if ok then
			ok, pages = pcall(function()
				return (store :: OrderedDataStore):GetSortedAsync(false, LeaderConfig.Size)
			end)
		end
		if ok and pages then
			local entries = {}
			for _, item in pages:GetCurrentPage() do
				table.insert(entries, { Name = getName(tonumber(item.key) or 0), Score = item.value })
			end
			render(entries, true)
			return
		end
	end
	render(localEntries(), false)
end

function LeaderboardService:Init()
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore(LeaderConfig.StoreName)
	end)
	if ok then
		store = result
	end
	buildBoard()
end

function LeaderboardService:Start()
	task.spawn(function()
		task.wait(10) -- laisse le temps aux données des joueurs de se charger
		while true do
			update()
			task.wait(LeaderConfig.UpdateInterval)
		end
	end)
end

return LeaderboardService
