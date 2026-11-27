# Modèles de remplacement (Toolbox) : noms exacts et dossiers

Crée les dossiers dans Studio (ils ne sont jamais effacés par Rojo). Mets un **Model** nommé EXACTEMENT comme la clé.
Le jeu supprime les scripts, les Humanoid, les ProximityPrompt et ClickDetector, ancre les pièces, enlève les collisions, ajuste la taille, centre le modèle et le pose sur le sol.
L'avant du modèle doit regarder vers -Z (bouton « Front » de Studio) ; sinon ajoute au Model un attribut nombre `YawOffset` (ex. 90, 180, -90).

### Redresser un modèle couché ou mal tourné (toutes catégories)

Ajoute au **Model** (pas à une pièce) un ou plusieurs attributs de type **number**, en degrés :

| Attribut | Effet | Quand l'utiliser |
|---|---|---|
| `YawOffset` | tourne sur lui-même (autour de la verticale) | il est debout mais regarde dans la mauvaise direction |
| `PitchOffset` | bascule vers l'avant ou l'arrière | il est couché sur le dos ou sur le ventre |
| `RollOffset` | bascule sur le côté | il est couché sur le flanc |

Comment faire dans Studio :
1. Sélectionne le Model dans l'Explorer (ex. `ServerStorage > CustomModels > Props > Pedestal`).
2. Fenêtre Properties, tout en bas : **Attributes > +** (Add Attribute), nom `PitchOffset`, type **Number**, valeur `90`.
3. Lance le jeu (Play) et regarde le modèle. S'il est maintenant la tête en bas ou couché de l'autre côté, essaie `-90` (ou `180`). S'il est toujours couché mais sur le flanc, enlève `PitchOffset` et essaie `RollOffset` = `90` puis `-90`.
4. Une fois debout, s'il regarde dans le mauvais sens, ajuste `YawOffset` (90, 180, -90).

Valeurs utiles : presque toujours `90`, `-90` ou `180`. Le jeu redresse d'abord, puis tourne, puis remet la taille et pose le modèle sur le sol : tu n'as rien à recaler toi-même.

## Cultures : `ServerStorage > CustomModels > Crops` (11)

Un seul modèle par culture, utilisé pour les 3 stades (petit, moyen, mûr). Taille mûre : `Config.Farm.CustomCropSize` (ou `ModelSize` dans la culture).

| Nom du Model | Culture |
|---|---|
| `Wheat` | Blé |
| `Carrot` | Carotte |
| `Tomato` | Tomate |
| `Corn` | Maïs |
| `Pumpkin` | Citrouille |
| `Strawberry` | Fraise |
| `Blueberry` | Myrtille |
| `Watermelon` | Pastèque |
| `Dragonfruit` | Fruit du dragon |
| `StarFlower` | Fleur étoilée |
| `MoonPumpkin` | Citrouille lunaire |

## Animaux de la ferme : `ServerStorage > CustomModels > Animals` (13)

| Nom du Model | Animal |
|---|---|
| `Chicken` | Poule |
| `Rabbit` | Lapin |
| `Duck` | Canard |
| `Sheep` | Brebis |
| `Goat` | Chèvre |
| `Cow` | Vache |
| `Horse` | Cheval |
| `Pig` | Cochon |
| `ForestHorse` | Mousseval |
| `SnowHorse` | Givrecrin |
| `SandHorse` | Sablecrin |
| `LavaHorse` | Brasecrin |
| `Astrelune` | Astrelune |

## Créatures : `ServerStorage > CustomModels > Creatures` (36)

| Nom du Model | Créature | Zone | Rareté |
|---|---|---|---|
| `Mousselin` | Mousselin | Forest | Common |
| `Glandinet` | Glandinet | Forest | Common |
| `Champiloup` | Champiloup | Forest | Rare |
| `Lucifeuille` | Lucifeuille | Forest | Epic |
| `Cerfeuillu` | Cerfeuillu | Forest | Legendary |
| `Racinor` | Racinor | Forest | Mythic |
| `MurmureDesBois` | Murmure-des-Bois | Forest | Secret |
| `Caillouteux` | Caillouteux | Mountain | Common |
| `Flocon` | Flocon | Mountain | Common |
| `Bouquetonnerre` | Bouquetonnerre | Mountain | Rare |
| `Givrelle` | Givrelle | Mountain | Epic |
| `Grizzlune` | Grizzlune | Mountain | Legendary |
| `Aquilorage` | Aquilorage | Mountain | Mythic |
| `Yetinou` | Yétinou | Mountain | Secret |
| `Dunelle` | Dunelle | Desert | Common |
| `Scorpinou` | Scorpinou | Desert | Common |
| `Cactouille` | Cactouille | Desert | Rare |
| `Mirageon` | Mirageon | Desert | Epic |
| `Sphinxou` | Sphinxou | Desert | Legendary |
| `Pharaonix` | Pharaonix | Desert | Mythic |
| `Oasien` | Oasien | Desert | Secret |
| `Braisou` | Braisou | Volcano | Common |
| `Cendrou` | Cendrou | Volcano | Common |
| `Magmoche` | Magmoche | Volcano | Rare |
| `Salamandrix` | Salamandrix | Volcano | Epic |
| `Pyrodrake` | Pyrodrake | Volcano | Legendary |
| `Volcanosaure` | Volcanosaure | Volcano | Mythic |
| `CoeurDeLave` | Cœur-de-Lave | Volcano | Secret |
| `Mousseval` | Mousseval | Forest | Rare |
| `Givrecrin` | Givrecrin | Mountain | Epic |
| `Sablecrin` | Sablecrin | Desert | Epic |
| `Brasecrin` | Brasecrin | Volcano | Legendary |
| `Sylvanthe` | Sylvanthe | Forest | Divine |
| `Aurorea` | Auroréal | Mountain | Divine |
| `Solarion` | Solarion | Desert | Divine |
| `Ignaros` | Ignaros | Volcano | Divine |

## Bâtiments : `ServerStorage > CustomModels > Buildings` (5)

| Nom du Model | Bâtiment |
|---|---|
| `Bakery` | Boulangerie |
| `Spinning` | Filature |
| `Dairy` | Laiterie |
| `Cheese` | Fromagerie |
| `Tailor` | Atelier de couture |

## Stands : `ServerStorage > CustomModels > Stands`

| Nom du Model | Stand |
|---|---|
| `SeedShop` | 🌱 Graines |
| `SellStand` | 💰 Vente |
| `AnimalShop` | 🐄 Animaux |

## Mascotte : `ServerStorage > CustomModels > Mascot`

| Nom du Model | |
|---|---|
| `Biscotte` | statue du spawn |

## Ennemis et boss de donjon : `ReplicatedStorage > CustomModels > Enemies` (12)

(dans ReplicatedStorage car c'est le client qui les dessine)

| Nom du Model | Ennemi |
|---|---|
| `Ronceux` | Ronceux |
| `Champitox` | Champitox |
| `Givrelin` | Givrelin |
| `Cognebloc` | Cognebloc |
| `Scarabix` | Scarabix |
| `Ventsableux` | Ventsableux |
| `Braisard` | Braisard |
| `Magmolosse` | Magmolosse |
| `VieuxChene` | Vieux Chêne Grognon (boss) |
| `ReineGivre` | Reine du Givre (boss) |
| `GardienDunes` | Gardien des Dunes (boss) |
| `TitanLave` | Titan de Lave (boss) |

## Aides (PNJ) : `ServerStorage > CustomModels > Helpers`

| Nom du Model | Aide |
|---|---|
| `Farmer` | 🧑‍🌾 Fermier |
| `Caretaker` | 🧺 Soigneur |
| `Artisan` | 🧰 Artisan |

## Marchands des stands : `ServerStorage > CustomModels > Merchants`

Un modèle par stand, ou un seul `Merchant` utilisé pour tous les stands qui n'ont pas le leur.

| Nom du Model | Stand |
|---|---|
| `SeedShop` | marchand du stand 🌱 Graines |
| `SellStand` | marchand du stand 💰 Vente |
| `AnimalShop` | marchand du stand 🐄 Animaux |
| `Merchant` | marchand par défaut (tous les stands) |

## Objets interactifs : `ServerStorage > CustomModels > Props`

Le prompt, le panneau, les collisions et les effets lumineux restent ceux du jeu ; seul le visuel change.

| Nom du Model | Objet |
|---|---|
| `Pedestal` | socle d'exposition (la créature se pose sur son sommet) |
| `ShowcaseBase` | socle de la vitrine de prestige |
| `ExpeditionPortal` | portail 🧭 Expéditions (ferme) |
| `ReturnPortal` | portail de retour dans chaque zone |
| `DungeonPortal` | portail ⚔️ Donjons |
| `Trough` | mangeoire des enclos |
| `Crate` | caisse de production des enclos |

## Décor : `ServerStorage > CustomModels > Scenery`

Un modèle par type, réutilisé partout où le décor en place un (taille ajustée à chaque fois).

| Nom du Model | Décor | Où |
|---|---|---|
| `Tree` | arbre | ferme + grands arbres de la Forêt |
| `Pine` | sapin | ferme + sapins de la Montagne |
| `Bush` | buisson | ferme |
| `Rock` | rocher | ferme |
| `Flower` | fleur | ferme (massifs, jardinières) |
| `Bridge` | pont du ruisseau (on marche toujours dessus) | ferme |
| `Lantern` | lanterne | pont + portail d'entrée des parcelles |

## Bâtiments importés : effet de production
Un bâtiment importé garde un effet quand il produit : fumée et étincelles au sommet du modèle.
