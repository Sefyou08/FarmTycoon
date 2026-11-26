--[[
	GameEvents.lua
	==============
	Petit bus d'événements de jeu côté serveur (pour le tutoriel et les quêtes).
	Les services signalent ce que fait le joueur, sans dépendre du tutoriel :
	  GameEvents.Fire(player, "Plant")            -- (nom, argument facultatif)
	  GameEvents.Connect(function(player, name, arg) ... end)
	Noms utilisés : BuySeed, Plant, Harvest, Sell, BuildPen, BuildPedestal, BuildBuilding (id),
	BuyAnimal, PlaceAnimal, Feed, QueueRecipe, CollectRecipe, Consume, Travel (zone),
	Capture, Exhibit, DungeonWin.
]]

local GameEvents = {}

local listeners: { (Player, string, any) -> () } = {}

function GameEvents.Connect(callback: (Player, string, any) -> ())
	table.insert(listeners, callback)
end

function GameEvents.Fire(player: Player, name: string, arg: any?)
	for _, callback in listeners do
		task.spawn(callback, player, name, arg)
	end
end

return GameEvents
