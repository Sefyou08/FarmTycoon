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
- [x] Phase 7 : progression, ressources rares, consommables, aides PNJ
- [x] Phase 8 : donjon + œufs de créatures
- [x] Phase 9 : monétisation, roue quotidienne, cosmétiques
- [ ] Phase 10 : direction artistique (à tester)

## Boucle de jeu actuelle
1. Stand **🌱 GRAINES** (à gauche du spawn) : acheter des graines.
2. Barre du bas : choisir la graine, puis **E** sur une case de terre d'un champ.
3. La plante passe par 3 stades puis affiche « Prêt ! » : **E** pour récolter.
4. Bouton **🔨 Construire** : acheter et placer des champs, des enclos et des bâtiments
   (aperçu vert / rouge, **R** pour tourner, clic pour valider). Cliquer sur un élément posé
   permet de le déplacer ou de le ranger.
5. **E** sur une case grise d'un champ pour la débloquer.
6. Stand **🐄 ANIMAUX** (devant le spawn) : acheter un animal (chance de variante rare). Il arrive dans
   **🐾 Mes animaux** : choisis l'enclos où le placer (et retire-le quand tu veux). ⭐ = le montrer dans la vitrine.
7. **E** sur la mangeoire pour la remplir avec tes récoltes, **E** sur la caisse pour ramasser la production.
8. Le **fumier** du cheval sert d'engrais : **E** sur une plante qui pousse.
9. **E** sur la porte d'un bâtiment : lancer des recettes, récupérer, améliorer.
10. Stand **💰 VENTE** (à droite du spawn) : choisis ce que tu vends (onglets, quantité par objet) ou vends tout.
11. Boutons au sol à l'entrée de ta parcelle : **💰 Agrandir** (Coins) ou **💎 Agrandir** (Robux, immédiat),
    et des boosts Robux de 2 h (⚡ XP, 💰 Coins, 🏭 Production, 🌱 Pousse) : marche dessus ou appuie sur E.
12. **Maj** pour courir.
13. **Portail violet** derrière le spawn : expéditions et capture de créatures (bouton **📖 Créatures**).
14. **Socles d'exposition** (🔨 Construire) : expose tes créatures (📖 Créatures → 🏛️ Exposer) pour gagner des Coins/seconde, même hors ligne. ⭐ épingle une créature dans la **vitrine** devant ta parcelle.
15. **📚 Index** : complète une zone pour réclamer sa récompense. **🏡 Visiter** : va voir la ferme des autres joueurs. Panneau **🏆** près du spawn : classement des collections.
16. **Niveau / XP** (barre en haut) : récolte, élevage, fabrication et capture font gagner de l'XP.
17. **Stock rare** de la boutique de graines : renouvelé toutes les 5 min (compte à rebours).
18. **🍴** dans le sac : manger un produit donne un boost (vitesse, XP, Coins, capture).
19. **🧑‍🌾 Aides** : fermier et soigneur PNJ. **🐴 Monture** : monter sur ton cheval. **⭐ Rebirth** : renaître contre un multiplicateur de Coins.
20. **Capture** : choisis 🎯 Sûr (100 % de réussite finale, un peu plus dur) ou ⚡ Rapide (un peu plus facile, moins sûr).
21. **Portail rouge ⚔️ DONJONS** (à gauche du spawn) : vagues d'ennemis puis un boss. ⚔️ Attaque (clic / F), 💨 Esquive (Q) quand un ennemi devient rouge.
22. **🐣 Couver** dans le sac : fais éclore les œufs gagnés au donjon pour obtenir des créatures.
23. **🐴 Monture** : choisis ton cheval (enclos ou chevaux sauvages capturés), monte et descends avec le même bouton.
24. **Chevaux sauvages** : un par zone d'expédition (Mousseval, Givrecrin, Sablecrin, Brasecrin), capturables ; 🐾 dans la collection pour le mettre en enclos.
25. **🎡 Roue** : 1 tour gratuit par jour (chances affichées) ; 0,1 % de gagner l'Astrelune 🦄, animal exclusif.
26. **💎 Boutique** : Game Passes et achats Robux (IDs à mettre dans `Config.Monetization`).
27. **🎨 Personnaliser** : clôtures, sol, bâtiments, champs, panneau, vitrine, traces, titre, chapeaux, selle (visuel uniquement).
28. **🎯 Tutoriel** : une quête affichée en haut de l'écran, avec une flèche vers l'objectif (passer / relancer depuis **❓ Guide**).
29. **❓ Guide** : explication de chaque système. **🎁 Temps de jeu** (en haut à gauche) : cadeaux à 15 min, 30 min, 1 h et 2 h.

## Achats Robux : où mettre les IDs
- Game Passes : `Config.Monetization.GamePasses.<Nom>.Id`
- Developer Products : `Config.Monetization.Products.<Nom>.Id` (dont les boosts 2 h des boutons au sol :
  `XPBoost2h`, `CoinsBoost2h`, `ProductionBoost2h`, `GrowthBoost2h`, et `PlotExpansion` pour 💎 Agrandir).
  Emplacement des boutons au sol : `Config.TycoonPads`.
- Cosmétiques payants : `Config.Cosmetics.<Nom>.Unlock.ProductId` (un Developer Product par cosmétique)
- Un Id à `0` affiche « Bientôt disponible ». `GrantAllPassesInStudio = true` donne tous les passes dans Studio pour tester.

## Remplacer un modèle par un modèle de la Toolbox
Liste EXACTE des noms et des dossiers : voir **MODELES.md**. Rojo ne touche jamais à
`ServerStorage > CustomModels` ni à `ReplicatedStorage > CustomModels` (`$ignoreUnknownInstances`).

Chaque modèle généré peut être remplacé, un par un, sans toucher au gameplay :
1. Dans Studio, crée `ServerStorage > CustomModels` (Folder), puis dedans un Folder par catégorie :
   `Creatures`, `Animals`, `Buildings`, `Stands`, `Mascot`.
   Pour les ennemis de donjon (dessinés par le client) : `ReplicatedStorage > CustomModels > Enemies`.
2. Mets-y ton Model, renommé EXACTEMENT comme l'id : `Cow`, `Chicken`, `Horse`, `Pharaonix`, `Bakery`,
   `SeedShop`, `SellStand`, `AnimalShop`, `Biscotte`, `Ronceux`... (ids dans `Config.lua`).
3. Le modèle doit regarder vers -Z (bouton « Front » de Studio), avoir ses pieds au niveau de
   son pivot, et à peu près la taille du modèle généré.
Le jeu ajoute tout seul ce qu'il faut (zone cliquable, panneau, effets de rareté / variante).

## Images et sons (facultatif)
Tous les motifs existent déjà en 3D (petites Parts). Une image (Decal) les rend plus fins :
quand un ID est mis dans `Config.Art.Decals`, l'image remplace le motif 3D, répétée en mosaïque.

| Nom dans Config.Art.Decals | Ce que l'image doit montrer | Taille conseillée |
|---|---|---|
| `Stars` | petites étoiles dorées éparpillées | 512 x 512 |
| `Hearts` | petits cœurs roses / rouges | 512 x 512 |
| `Diamonds` | diamants bleu clair brillants | 512 x 512 |
| `Pearls` | rangées de perles nacrées | 512 x 512 |
| `Flowers` | petites fleurs roses à cœur jaune | 512 x 512 |
| `Flames` | flammes orange et jaunes stylisées | 512 x 512 |
| `Clouds` | nuages blancs cartoon | 512 x 512 |
| `Checker` | damier noir et blanc (2 x 2 cases) | 256 x 256 |
| `Stripes` | rayures verticales (2 couleurs) | 256 x 256 |
| `Glitter` | paillettes scintillantes | 512 x 512 |
| `Unicorn` | têtes de licorne mignonnes (corne dorée, crinière rose) | 512 x 512 |
| `Mascot` | tête de Biscotte (chaton abricot, chapeau de paille) | 512 x 512 |
| `MascotLogo` | logo du jeu : Biscotte + « Farm Tycoon » (panneau du spawn) | 1024 x 512 |

Règles : PNG à fond transparent, motif qui se répète sans couture sur les bords (« tileable »),
dessin 100 % original (aucun personnage ni logo existant).

Étapes :
1. Crée l'image : dessine-la (Krita, Photopea, Canva...) ou génère-la avec un outil d'images par IA
   (ex. : « motif répétable de petites étoiles dorées, style cartoon, fond transparent »).
   Recadre à la taille conseillée et exporte en PNG.
2. Dans Studio : menu **Affichage (View) > Asset Manager**, bouton **Importer** (Bulk Import),
   choisis tes PNG. Attends la fin de la modération Roblox.
3. Dans l'Asset Manager, dossier **Images** : clic droit sur l'image > **Copy ID to Clipboard**.
4. Colle le nombre dans `src/shared/Config.lua`, par exemple `Stars = 1234567890,`, puis relance.
   (Astuce : si tu as un ID de « Decal » du site et qu'il ne s'affiche pas, colle-le dans la
   propriété Texture d'un Decal dans Studio : Studio le convertit en ID d'image, à recopier.)

Musiques d'ambiance (une par lieu) : **Toolbox > Audio**, cherche une musique libre (ex. celles
publiées par Roblox), clic droit > **Copy Asset ID**, colle-le dans `Config.Art.Music`
(`Farm`, `Forest`, `Mountain`, `Desert`, `Volcano`, `Dungeon`). 0 = pas de musique.

Conseil éclairage : dans l'Explorer, sélectionne **Lighting** et mets **Technology = Future**
pour des lumières (torches, lave, cristaux) plus jolies.
