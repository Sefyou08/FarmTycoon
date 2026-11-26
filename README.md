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
- [x] Phase 3 : animaux de ferme, enclos, variantes, agrandissement de parcelle
- [x] Phase 4 : bâtiments de transformation, vitesse de marche et sprint
- [x] Phase 5 : expéditions, créatures, capture
- [x] Phase 5b : mode construction + champs
- [x] Phase 6 : collection, exposition, vitrine, Index, classement
- [ ] Phase 7 : progression, ressources rares, consommables, aides PNJ (à tester)
- [ ] Phase 8 : donjon
- [ ] Phase 9 : monétisation
- [ ] Phase 10 : direction artistique

## Boucle de jeu actuelle
1. Stand **🌱 GRAINES** (à gauche du spawn) : acheter des graines.
2. Barre du bas : choisir la graine, puis **E** sur une case de terre d'un champ.
3. La plante passe par 3 stades puis affiche « Prêt ! » : **E** pour récolter.
4. Bouton **🔨 Construire** : acheter et placer des champs, des enclos et des bâtiments
   (aperçu vert / rouge, **R** pour tourner, clic pour valider). Cliquer sur un élément posé
   permet de le déplacer ou de le ranger.
5. **E** sur une case grise d'un champ pour la débloquer.
6. Stand **🐄 ANIMAUX** (devant le spawn) : acheter un animal (chance de variante rare).
7. **E** sur la mangeoire pour la remplir avec tes récoltes, **E** sur la caisse pour ramasser la production.
8. Le **fumier** du cheval sert d'engrais : **E** sur une plante qui pousse.
9. **E** sur la porte d'un bâtiment : lancer des recettes, récupérer, améliorer.
10. Stand **💰 VENTE** (à droite du spawn) : tout vendre.
11. Bouton bleu à l'entrée de ta parcelle : **agrandir** la parcelle.
12. **Maj** pour courir.
13. **Portail violet** derrière le spawn : expéditions et capture de créatures (bouton **📖 Créatures**).
14. **Socles d'exposition** (🔨 Construire) : expose tes créatures (📖 Créatures → 🏛️ Exposer) pour gagner des Coins/seconde, même hors ligne. ⭐ épingle une créature dans la **vitrine** devant ta parcelle.
15. **📚 Index** : complète une zone pour réclamer sa récompense. **🏡 Visiter** : va voir la ferme des autres joueurs. Panneau **🏆** près du spawn : classement des collections.
16. **Niveau / XP** (barre en haut) : récolte, élevage, fabrication et capture font gagner de l'XP.
17. **Stock rare** de la boutique de graines : renouvelé toutes les 5 min (compte à rebours).
18. **🍴** dans le sac : manger un produit donne un boost (vitesse, XP, Coins, capture).
19. **🧑‍🌾 Aides** : fermier et soigneur PNJ. **🐴 Monture** : monter sur ton cheval. **⭐ Rebirth** : renaître contre un multiplicateur de Coins.
