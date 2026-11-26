# Farm Tycoon (Roblox / Rojo)

## Installation de Rojo
1. Installe **Rokit** (gestionnaire d'outils) : https://github.com/rojo-rbx/rokit, puis dans ce dossier : `rokit install`
   (ou télécharge `rojo` directement depuis https://github.com/rojo-rbx/rojo/releases, ou l'extension VS Code « Rojo »).
2. Installe le plugin Studio : `rojo plugin install` (ou « Rojo » sur le Creator Store).
3. Lance le serveur de synchro : `rojo serve`
4. Dans Roblox Studio (place Baseplate) : onglet **Plugins → Rojo → Connect** (localhost:34872).

## Structure
| Dossier | Destination dans Studio |
|---|---|
| `src/shared` | `ReplicatedStorage.Shared` (Config, Remotes, Format) |
| `src/server` | `ServerScriptService.Server` (Main + Services) |
| `src/client` | `StarterPlayer.StarterPlayerScripts.Client` |

Tout l'équilibrage est dans `src/shared/Config.lua`.

## Sauvegarde dans Studio
Publie la place, puis **Game Settings → Security → Enable Studio Access to API Services**.
Sans ça, le jeu tourne en « mode mock » (données en mémoire, perdues à l'arrêt).
