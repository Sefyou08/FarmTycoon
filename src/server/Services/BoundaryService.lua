--[[
	BoundaryService.lua
	===================
	Limites de la map, vérifiées par le SERVEUR (Config.Bounds) :
	  • les murs invisibles sont construits avec le décor (FarmScenery, ExpeditionService,
	    DungeonService) ;
	  • ici, toutes les Config.Bounds.CheckInterval secondes, chaque joueur est contrôlé :
	      - en donjon   : il doit rester dans SON arène, sinon retour à l'entrée de l'arène ;
	      - en zone     : il doit rester dans la zone où il est entré par le portail, sinon
	                      retour au point d'arrivée (devant le portail de retour) ;
	      - à la ferme  : il doit rester dans le cercle de jeu, au-dessus du sol, sinon retour
	                      sur sa parcelle.
	    Un joueur qui se trouve dans une zone ou une arène sans être passé par le portail
	    (zone verrouillée, triche...) est donc renvoyé à la ferme.
	  • Le retour se fait SANS réapparition : on garde tout (inventaire, monture, boosts).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local SyncService = require(script.Parent.SyncService)
local PlotService = require(script.Parent.PlotService)
local ExpeditionService = require(script.Parent.ExpeditionService)
local DungeonService = require(script.Parent.DungeonService)

local Bounds = Config.Bounds

local BoundaryService = {}

local function inside(pos: Vector3, center: Vector3, size: number): boolean
	local half = size / 2 + Bounds.Margin
	return math.abs(pos.X - center.X) <= half
		and math.abs(pos.Z - center.Z) <= half
		and pos.Y > center.Y + Bounds.FallY
		and pos.Y < center.Y + Bounds.WallHeight
end

local function rescue(player: Player, character: Model, root: BasePart, target: CFrame, message: string)
	root.AssemblyLinearVelocity = Vector3.zero
	character:PivotTo(target + Vector3.new(0, 3, 0))
	SyncService:Notify(player, message, "Info")
end

local function farmFallback(player: Player): CFrame
	local plot = PlotService:GetPlot(player)
	if plot then
		return plot.SpawnCFrame
	end
	local spawn = Workspace:FindFirstChildWhichIsA("SpawnLocation")
	return if spawn then spawn.CFrame else CFrame.new(0, 3, 0)
end

local function check(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
		return
	end
	local pos = root.Position

	-- 1. En donjon : rester dans son arène
	local arenaCenter, arenaSize, entry = DungeonService:GetArenaBounds(player)
	if arenaCenter then
		if not inside(pos, arenaCenter, arenaSize :: number) then
			rescue(player, character :: Model, root, entry :: CFrame, "↩️ Tu es revenu à l'entrée de l'arène.")
		end
		return
	end

	-- 2. En expédition : rester dans la zone (entrée par le portail)
	local zoneId = ExpeditionService:GetZone(player)
	if zoneId then
		local center, size, arrival = ExpeditionService:GetZoneBounds(zoneId)
		if center and not inside(pos, center, size :: number) then
			rescue(player, character :: Model, root, arrival :: CFrame, "↩️ Tu es revenu devant le portail de la zone.")
		end
		return
	end

	-- 3. À la ferme : rester dans le cercle de jeu, au-dessus du sol
	local flat = Vector2.new(pos.X, pos.Z).Magnitude
	if flat > Bounds.FarmRadius + Bounds.Margin or pos.Y < Bounds.FallY or pos.Y > Bounds.WallHeight then
		rescue(player, character :: Model, root, farmFallback(player), "↩️ Tu es revenu sur ta parcelle.")
	end
end

function BoundaryService:Init() end

function BoundaryService:Start()
	task.spawn(function()
		while true do
			task.wait(Bounds.CheckInterval)
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(check, player)
				if not ok then
					warn("[BoundaryService] " .. tostring(err))
				end
			end
		end
	end)
end

return BoundaryService
