--[[
	PlaytimeUI.lua
	==============
	Petit panneau (en haut à gauche) des récompenses de temps de jeu (Config.Playtime) :
	montre la prochaine récompense et un minuteur ; le bouton « Réclamer » s'allume quand
	c'est prêt. Le serveur vérifie tout (RemoteFunction "ClaimPlaytime").
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local RewardUtil = require(ReplicatedStorage.Shared.RewardUtil)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(script.Parent.Theme)

local PlaytimeUI = {}

local Rewards = Config.Playtime.Rewards

function PlaytimeUI.Init(screen: ScreenGui, StateController, notify: (string, string) -> ())
	local remote: RemoteFunction = Remotes.Get("ClaimPlaytime")

	local panel = Instance.new("Frame")
	panel.Name = "PlaytimePanel"
	panel.Position = UDim2.fromOffset(12, 60)
	panel.Size = UDim2.fromOffset(270, 66)
	panel.BackgroundColor3 = Theme.Colors.Panel
	panel.BackgroundTransparency = 0.1
	panel.Visible = false
	panel.Parent = screen
	Theme.Corner(panel, 12)
	Theme.Stroke(panel, 2, Color3.fromRGB(255, 200, 80))
	local title = Theme.Label({ Size = UDim2.new(1, -96, 0, 26), Position = UDim2.fromOffset(8, 4), TextXAlignment = Enum.TextXAlignment.Left, Text = "", Parent = panel })
	local detail = Theme.Label({ Size = UDim2.new(1, -96, 0, 30), Position = UDim2.fromOffset(8, 32), TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, TextColor3 = Theme.Colors.Coins, Text = "", Parent = panel })
	local claim = Theme.Button({ Size = UDim2.fromOffset(84, 50), Position = UDim2.new(1, -90, 0, 8), Text = "⏳", Parent = panel })

	local nextIndex: number? = nil
	local ready = false

	local function refresh()
		local playtime = StateController.Get("Playtime")
		if not playtime then
			panel.Visible = false
			return
		end
		local claimed = playtime.Claimed or {}
		nextIndex = nil
		for index in Rewards do
			if not claimed[tostring(index)] then
				nextIndex = index
				break
			end
		end
		if not nextIndex then
			panel.Visible = true
			title.Text = "🎁 Toutes les récompenses réclamées !"
			detail.Text = "Reviens dans une prochaine session."
			claim.Visible = false
			return
		end
		local reward = Rewards[nextIndex]
		local remaining = math.max(0, playtime.Start + reward.Minutes * 60 - Workspace:GetServerTimeNow())
		ready = remaining <= 0
		panel.Visible = true
		claim.Visible = true
		title.Text = if ready then ("🎁 Cadeau des %d min prêt !"):format(reward.Minutes) else ("🎁 Cadeau dans %s"):format(Format.Time(math.ceil(remaining)))
		detail.Text = RewardUtil.Describe(reward.Reward, StateController.Get("Level") or 1)
		claim.Text = if ready then "Réclamer" else "⏳"
		claim.BackgroundColor3 = if ready then Color3.fromRGB(60, 170, 80) else Color3.fromRGB(90, 90, 100)
	end

	claim.Activated:Connect(function()
		if not ready or not nextIndex then
			notify("Pas encore : continue à jouer !", "Info")
			return
		end
		local ok, success, message = pcall(function()
			return remote:InvokeServer(nextIndex)
		end)
		if ok then
			notify(message, if success then "Rare" else "Error")
		end
	end)

	StateController.Changed:Connect(function(key)
		if key == "*" or key == "Playtime" then
			refresh()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			refresh()
		end
	end)
end

return PlaytimeUI
