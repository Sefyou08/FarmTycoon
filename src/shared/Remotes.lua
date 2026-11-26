--[[
	Remotes.lua  (ReplicatedStorage.Shared.Remotes)
	===============================================
	Point d'accès unique aux RemoteEvents / RemoteFunctions.

	- Le SERVEUR appelle Remotes.Init() au démarrage : il crée le dossier
	  ReplicatedStorage.Remotes et tous les remotes listés ci-dessous.
	- Le CLIENT et le serveur utilisent Remotes.Get("Nom") pour les récupérer.

	Pour ajouter un remote : ajoute simplement son nom dans la bonne liste.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

local FOLDER_NAME = "Remotes"

-- RemoteEvents (communication à sens unique)
Remotes.EventNames = {
	"Notify", -- Serveur -> Client : afficher une notification (texte, type)
	"StateChanged", -- Serveur -> Client : une valeur des données du joueur a changé (clé, valeur)
	"RequestTeleportHome", -- Client -> Serveur : "téléporte-moi à ma parcelle"
}

-- RemoteFunctions (requête + réponse)
Remotes.FunctionNames = {
	"GetState", -- Client -> Serveur : renvoie l'état complet du joueur (ou nil si pas encore chargé)
}

local folder: Folder? = nil

local function getFolder(): Folder
	if folder then
		return folder
	end
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if not existing then
			existing = Instance.new("Folder")
			existing.Name = FOLDER_NAME
			existing.Parent = ReplicatedStorage
		end
		folder = existing :: Folder
	else
		folder = ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
	end
	return folder :: Folder
end

-- À appeler UNE fois côté serveur, avant tout le reste.
function Remotes.Init()
	assert(RunService:IsServer(), "Remotes.Init() doit être appelé côté serveur")
	local f = getFolder()

	for _, name in Remotes.EventNames do
		if not f:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = f
		end
	end

	for _, name in Remotes.FunctionNames do
		if not f:FindFirstChild(name) then
			local remote = Instance.new("RemoteFunction")
			remote.Name = name
			remote.Parent = f
		end
	end
end

-- Récupère un remote par son nom (attend côté client s'il n'existe pas encore).
function Remotes.Get(name: string): any
	local f = getFolder()
	if RunService:IsServer() then
		local remote = f:FindFirstChild(name)
		assert(remote, ("Remote '%s' introuvable : l'as-tu ajouté dans Remotes.lua ?"):format(name))
		return remote
	end
	return f:WaitForChild(name)
end

return Remotes
