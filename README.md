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

## Avancement
Le plan complet et l'équilibrage sont dans [DESIGN.md](DESIGN.md).

- [x] Phase 1 : setup Rojo, parcelles, argent, sauvegarde
- [x] Phase 2 : planter, pousse (3 stades), récolte, vente
- [ ] Phase 3 : animaux de ferme, enclos, variantes, agrandissement de parcelle (à tester)
- [ ] Phase 4 : bâtiments de transformation
- [ ] Phase 5 : expéditions
- [ ] Phase 6 : collection et exposition
- [ ] Phase 7 : progression (boutique tournante, rebirth...)
- [ ] Phase 8 : monétisation et UI
- [ ] Phase 9 : décor

## Boucle de jeu actuelle
1. Stand **🌱 GRAINES** (à gauche du spawn) : acheter des graines.
2. Barre du bas : choisir la graine, puis **E** sur une case de terre de ta parcelle.
3. La plante passe par 3 stades puis affiche « Prêt ! » : **E** pour récolter.
4. Bouton vert **🏗️ Enclos** sur ta parcelle : construire un enclos.
5. Stand **🐄 ANIMAUX** (devant le spawn) : acheter un animal (chance de variante rare).
6. **E** sur la mangeoire pour la remplir avec tes récoltes, **E** sur la caisse pour ramasser la production.
7. Le **fumier** du cheval sert d'engrais : **E** sur une plante qui pousse.
8. Stand **💰 VENTE** (à droite du spawn) : tout vendre.
9. Bouton bleu à l'entrée de ta parcelle : **agrandir** la parcelle.
