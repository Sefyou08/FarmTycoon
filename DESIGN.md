# Farm Tycoon : document de design

Document de référence du jeu : à relire avant chaque phase et à mettre à jour quand le plan change.
Les valeurs chiffrées ci-dessous sont des **valeurs de départ** : la source de vérité reste
`src/shared/Config.lua`.

---

## 1. Vision

Un farm tycoon avec **4 boucles de jeu reliées** :

```
          ┌──────────── vend ────────────┐
          ▼                              │
 🌱 PLANTES ──récoltes──► 🐄 ANIMAUX ──ressources──► 🏭 BÂTIMENTS ──produits──► 💰 VENTE
          ▲                  │   ▲                                            │
          └── fumier (engrais)┘   │                                            │
                                  └──── 🧭 EXPÉDITIONS (captures) ◄────── Coins ┘
                                              │
                                              ▼
                                   🏛️ COLLECTION exposée sur la base
                                      (Coins/seconde + prestige)
```

1. **Plantes** : on plante, ça pousse, on récolte. Les récoltes se **vendent** ou servent à
   **nourrir les animaux**.
2. **Animaux de ferme** : ils mangent des récoltes et produisent des ressources (lait, laine, œufs…).
3. **Bâtiments de transformation** : ils transforment les ressources en produits qui valent
   beaucoup plus cher (beurre, fromage, tissu, gâteau…).
4. **Expéditions et collection** : on part capturer des créatures rares (inventées, originales),
   qu'on collectionne et qu'on expose sur sa base pour gagner des Coins/seconde.

Chaque boucle alimente la suivante, et l'argent gagné sert à agrandir la parcelle, à acheter
plus d'animaux et de bâtiments, et à partir en expédition.

---

## 2. Règles techniques (toutes les phases)

- **Tout est validé côté serveur** : argent, récoltes, achats, captures. Le client affiche et
  envoie des demandes (RemoteEvents/RemoteFunctions), avec vérification de type, de distance et
  de cooldown (`RemoteGuard`).
- **Tout l'équilibrage est dans `Config.lua`** (prix, temps, revenus, multiplicateurs, chances).
- Code **modulaire** (un service par système), **commenté en français**, pas de `wait()` déprécié.
- Visuels en **Parts simples** remplaçables plus tard par de vrais modèles.
- **Sauvegarde** DataStore avec verrou de session, retries, auto-save 60 s, BindToClose.
  Tout ce qui produit (plantes, animaux, bâtiments) **continue hors ligne** grâce à des
  horodatages `os.time()` (avec un plafond hors ligne).
- **Une phase à la fois** : à la fin de chaque phase, on s'arrête avec la liste des tests à faire
  dans Studio.
- Créatures et animaux **originaux** : aucun personnage, nom ou visuel venant d'autres jeux.

---

## 3. La parcelle

- 6 parcelles par serveur (Max Players = 6), attribuées automatiquement, libérées au départ.
- **Grande parcelle** pour les cultures, les enclos, les bâtiments et les
  socles d'exposition (phase 6). Depuis la phase 5b, tout se place librement avec le mode
  construction.
- **Agrandissement par étapes**, payé en Coins avec un prix croissant (bouton tycoon sur la
  parcelle). Chaque étape débloque de nouveaux emplacements (enclos, bâtiments, socles).
- Emplacement prévu pour un **Developer Product** qui débloque un agrandissement avec de l'argent
  réel : **désactivé**, activé en phase 9.

| Niveau | Taille (studs) | Prix |
|---|---|---|
| 1 | 98 × 64 | gratuit |
| 2 | 118 × 90 | 3 000 |
| 3 | 138 × 116 | 20 000 |
| 4 | 158 × 142 | 100 000 |

---

## 4. Les phases

| Phase | Contenu | État |
|---|---|---|
| 1 | Setup Rojo, parcelles, argent, sauvegarde | ✅ fait |
| 2 | Planter, pousse en 3 stades, récolte, vente, boutique de graines | ✅ fait |
| 3 | Animaux de ferme, enclos, variantes rares, parcelles agrandissables | ✅ fait |
| 4 | Bâtiments de transformation + vitesse de marche et sprint | ✅ fait |
| 5 | Expéditions (portail, zones, créatures sauvages, capture) | ✅ fait |
| 5b | Mode construction (placer / déplacer / ranger) + champs supplémentaires | ✅ fait |
| 6 | Collection et exposition (socles, Coins/s, visite, Index, classement) + vitrine de prestige + rareté Divine | ⏳ en cours |
| 7 | Progression + ressources et recettes rares + consommables, boosts, XP + aides PNJ | à faire |
| 8 | Donjon (ennemis, boss, combat simple, récompenses rares) | à faire |
| 9 | Monétisation (Game Passes, Developer Products, IDs factices) + personnalisation cosmétique | à faire |
| 10 | Direction artistique complète (créatures, animaux, zones, ferme, bâtiments) | à faire |

### Phase 3 : Animaux de ferme
- **Enclos** construits sur sa parcelle, prix croissant. Un enclos accueille **une seule espèce**,
  jusqu'à 4 animaux.
- **Animaux achetés** au stand 🐄 ANIMAUX (prix croissant d'une espèce à l'autre), avec une chance
  d'obtenir une **variante rare**. L'animal va automatiquement dans un enclos de son espèce qui a de
  la place, sinon dans un enclos vide.
- **Nourrir** : chaque enclos a une mangeoire. On y met des récoltes acceptées par l'espèce, ce
  qui donne des « rations ». Chaque ressource produite consomme des rations : sans nourriture,
  pas de production.
- **Production** : elle s'accumule dans la caisse de l'enclos (capacité limitée) et se récupère
  avec E. Elle continue hors ligne (8 h max).
- **Cheval** : produit du **fumier**, un engrais. Mis sur une plante qui pousse, il réduit le temps
  restant. Le cheval deviendra aussi une **monture** en phase 7.
- Les animaux se promènent dans leur enclos (animation côté client).

### Phase 4 : Bâtiments de transformation
- Bâtiments construits sur la parcelle avec des Coins, **débloqués dans un ordre logique**.
- Chaque bâtiment a des **recettes** (dans Config), une **file d'attente de production**, et des
  **améliorations** : niveau, vitesse, nombre d'emplacements de production.
- Les produits transformés se vendent **beaucoup plus cher** que les ressources de base.
- La variante de la ressource (Doré, etc.) se transmet au produit, avec son multiplicateur.

### Phase 5 : Expéditions
- Un **portail** sur la map envoie vers des zones : Forêt, Montagne, Désert, Volcan.
- Des **créatures sauvages** originales apparaissent avec une rareté : Commune, Rare, Épique,
  Légendaire, Mythique, **Secrète** (très faible chance, annoncée à tout le serveur).
- **Capture** avec un mini-jeu : lasso et barre de timing.
- **Mutations** des créatures (Dorée, Géante, Arc-en-ciel, Spectrale), qui multiplient leur valeur.
- Les zones sont des **zones lointaines de la même place** (pas de TeleportService) : même
  sauvegarde, même serveur, plus simple à tester dans Studio.
- Les créatures capturées vont dans la **collection** (100 max) ; on peut les vendre en
  attendant les socles de la phase 6.
- Anti-triche : le serveur génère les paramètres du mini-jeu, recalcule la position du curseur à
  chaque clic, vérifie que le temps envoyé est plausible, puis fait un dernier tirage selon la
  rareté.

### Phase 5b : Mode construction + champs
1. **Plus de champs**
   - Un **champ** = un bloc de 6 cases de terre (3 × 2). Le joueur commence avec 1 champ déjà
     débloqué.
   - Chaque nouveau champ s'achète dans le menu de construction. Ses cases arrivent
     **verrouillées** et se débloquent une par une (E sur la case), avec un **prix croissant**
     calculé sur le nombre total de cases déjà débloquées.
   - Les 18 cases suivantes (3 champs) sont disponibles dès le niveau 1 de la parcelle ; chaque
     agrandissement permet d'acheter 2 champs de plus.
2. **Mode construction**
   - Bouton **« 🔨 Construire »** : ouvre le menu de construction (champs, enclos, bâtiments, et
     plus tard socles) et la liste des éléments **rangés**.
   - On choisit un élément, puis son emplacement : **aperçu transparent** (vert = valide,
     rouge = invalide), **R** ou le bouton ↻ pour tourner d'un quart de tour, **clic** (ou le
     bouton ✔ sur mobile) pour valider. L'achat n'est payé qu'à la validation.
   - En mode construction, cliquer sur un élément déjà posé le sélectionne : on peut le
     **déplacer** ou le **ranger** (il disparaît de la parcelle et va dans « Rangés »).
   - Le **serveur vérifie tout** : c'est bien sa parcelle, l'élément est dans les limites du niveau
     actuel, il ne chevauche aucun autre élément ni la zone d'entrée (spawn et boutons), la
     rotation est un quart de tour, et le joueur a les Coins.
   - Les positions (X, Z, rotation, posé/rangé) sont **sauvegardées** dans les données de chaque
     élément.
   - **Rien n'est perdu** quand on déplace ou range : les plantes, les animaux, la nourriture, la
     production et les files des bâtiments sont dans les données, seuls les visuels sont
     reconstruits. Un élément rangé continue de produire, mais on ne peut pas l'utiliser.
   - Mobile : toucher l'écran place l'aperçu à cet endroit, puis boutons ↻ / ✔ / ✖ à l'écran.
   - Les anciennes sauvegardes sont converties : les enclos et bâtiments gardent leur position
     d'avant, les 6 premières cases deviennent le 1er champ.

### Phase 6 : Collection et exposition
- **Socles d'exposition** placés avec le mode construction : chaque créature exposée génère des
  Coins/seconde selon sa rareté et sa mutation.
- Les autres joueurs peuvent **visiter** et voir la collection : nom, rareté, effet brillant pour
  les rares.
- **Index / Collection** : créatures découvertes et manquantes, avec une récompense pour chaque
  zone complétée.
- **Classement** des collections les plus rares.
- **Vitrine de prestige** :
  - devant l'entrée de chaque parcelle, une vitrine automatique affiche les **3 à 5 créatures et
    animaux les plus rares** du joueur, sur des socles éclairés, avec leur nom, leur rareté et leur
    effet visuel ;
  - choix **automatique** (par rareté puis mutation), ou **épinglé** par le joueur depuis sa
    collection ;
  - le **panneau de la parcelle** affiche le nom du joueur et sa **meilleure prise**
    (ex. « 🌟 Pharaonix Spectral – Secrète »).
- **Rareté Divine**, au-dessus de Secrète : chance d'environ **0,001 %**, effet visuel unique
  (auréole dorée, lumière intense, particules), et **annonce sur TOUS les serveurs**
  (MessagingService) quand quelqu'un en capture une. Une créature Divine par zone ; elles sont un
  **bonus de l'Index** (pas nécessaires pour compléter une zone).

### Phase 7 : Progression, ressources rares, consommables et aides
- **Progression** : boutique de graines **tournante** (stock rare renouvelé toutes les 5 min,
  compte à rebours), plantes Rares / Épiques / Légendaires et **mutations de plantes** à la
  récolte, **monture** (cheval) pour aller plus vite, **rebirth** (remise à zéro contre un
  multiplicateur de revenus permanent).
- **Ressources rares** : chaque production d'un animal a une petite chance de donner une ressource
  d'une **rareté supérieure** à celle de l'animal (une poule normale peut rarement pondre un Œuf
  Doré ; un lapin Légendaire peut donner de la Fourrure Mythique). Plus l'animal est rare, plus la
  chance est élevée. Chances dans Config.
- **Recettes rares** : certains bâtiments débloquent des recettes Rares, Épiques, Légendaires et
  Mythiques qui demandent des ingrédients rares.
- Les produits rares se **vendent très cher** OU se **consomment**.
- **Consommables et boosts** : manger un produit donne un boost temporaire (vitesse, XP, gain de
  Coins, chance de capture en expédition, dégâts / vie au donjon). Plus le produit est rare, plus
  le boost est fort et long. Affichage des boosts actifs avec un minuteur.
- **XP et niveau joueur** (pas encore dans le jeu) : on gagne de l'XP en récoltant, produisant,
  fabriquant et capturant ; le niveau débloque du contenu et des récompenses.
- **Aides automatiques** achetables et améliorables avec des Coins :
  - un **fermier PNJ** qui plante et récolte tout seul ;
  - un **soigneur PNJ** qui nourrit les animaux et ramasse la production.

### Phase 8 : Donjon
- Un **portail de donjon** vers des donjons avec des **ennemis** et des **boss**.
- **Combat simple** : attaque, esquive.
- **Récompenses rares** : graines, œufs de créatures, ingrédients mythiques.
- Les **boosts** des consommables s'appliquent au donjon et en expédition.

### Phase 9 : Monétisation
- Game Passes et Developer Products, avec des **IDs factices** dans Config et un `ProcessReceipt`
  idempotent (reçus enregistrés dans la sauvegarde).
- Exemples : version **premium des aides automatiques**, **agrandissement de parcelle** accéléré
  (emplacement déjà prévu : `PlotService:GrantExpansion`), **boosts**, **emplacements en plus**,
  packs de Coins, x2 Coins.
- **Personnalisation cosmétique** :
  - **uniquement cosmétique**, aucun avantage de gameplay (pas de pay-to-win) ;
  - skins d'enclos (clôtures en bois, pierre, bonbon, or, néon…), sols de parcelle, couleurs et
    motifs des bâtiments, panneau de parcelle personnalisé, effets autour de la vitrine
    (particules, lumières), traces de pas, titres affichés au-dessus du joueur ;
  - petits prix en Robux (environ **25 à 150 Robux**), et certains cosmétiques **débloquables en
    jouant** (succès, Index complété, niveaux) pour que les joueurs gratuits puissent aussi se
    distinguer ;
  - un menu **« 🎨 Personnaliser »** avec un **aperçu avant l'achat** ;
  - si un achat payant donne un résultat aléatoire, **afficher clairement les chances** (règle
    Roblox).

### Phase 10 : Direction artistique complète
Le gameplay est là ; il faut maintenant une vraie identité visuelle.
- **Créatures d'expédition** : refaire entièrement leurs modèles (aujourd'hui des boules
  empilées). Des créatures originales avec une vraie silhouette d'animal ou de créature, en style
  **cartoon mignon et lisible** (dans l'esprit des jeux de monstres à collectionner, mais 100 %
  inventées, aucun personnage existant) :
  - corps à la forme travaillée (wedges, cylindres, parts arrondies combinés), pattes, queue,
    oreilles, cornes, ailes ou nageoires selon la créature, **yeux expressifs** ;
  - palette cohérente avec la zone : Forêt verts et bruns, Montagne blancs et bleus glacés,
    Désert ocres et dorés, Volcan noirs et rouges / orangés ;
  - petites **animations** : respiration, marche, sauts, queue qui bouge ;
  - plus la créature est rare, plus elle est impressionnante (taille, détails, particules).
- **Animaux de la ferme** : même travail ; ils doivent vraiment ressembler à une vache, une
  poule, un mouton, un cheval, etc., en cartoon.
- **Zones d'expédition** avec une vraie identité :
  - Forêt : grands arbres, champignons, rivière, lucioles ;
  - Montagne : neige, sapins, rochers, flocons ;
  - Désert : dunes, cactus, ruines, légère tempête de sable ;
  - Volcan : roches noires, coulées de lave lumineuses, fumée, braises ;
  - éclairage et brouillard différents par zone, et une musique d'ambiance par zone si possible.
- **Ferme** : terrain herbe, montagnes en arrière-plan, ruisseau avec un pont, chemins, arbres,
  fleurs, clôtures, éclairage chaud (à la place du Baseplate gris).
- **Bâtiments thématiques** en cartoon / low-poly, en Parts et formes simples :
  - **Boulangerie** : façade avec auvent rayé, vitrine avec baguettes, croissants et pains, une
    baguette ou un croissant géant sur le toit, un four visible ;
  - **Laiterie** : une bouteille de lait géante, une vache stylisée reliée à la bouteille par un
    tuyau, du lait qui « coule » quand la production tourne ;
  - **Fromagerie** : une grosse meule de fromage à trous, une machine avec une roue animée ;
  - **Filature** : un rouet géant qui tourne, des pelotes de laine colorées ;
  - **Atelier de couture** : une machine à coudre géante, des rouleaux de tissu ;
  - **Stands** (graines, vente, animaux) dans le même style : caisses de légumes et sachets de
    graines, balance et sacs de pièces, bottes de foin et barrière d'enclos.
- **Animations** (roues, lait qui coule, fumée) actives **uniquement quand le bâtiment produit**.
  Elles sont calculées côté client : le serveur pose seulement un attribut `Working`.
- **Organisation du code des modèles** : une fonction de construction par créature, animal et
  bâtiment, derrière une interface commune. On pourra ainsi remplacer un modèle généré par un vrai
  modèle 3D (MeshPart importé, rangé dans ReplicatedStorage) **un par un**, sans toucher au
  gameplay.

---

## 5. Équilibrage de base

### 5.1 Cultures (phase 2)
Une « ration » de nourriture vaut environ 9 Coins, quelle que soit la culture donnée aux animaux.

| Culture | Graine | Pousse | Vente | Rations |
|---|---|---|---|---|
| 🌾 Blé | 5 | 15 s | 8 | 1 |
| 🥕 Carotte | 10 | 20 s | 18 | 2 |
| 🍅 Tomate | 30 | 45 s | 55 | 6 |
| 🌽 Maïs | 80 | 1 min 30 | 150 | 16 |
| 🎃 Citrouille | 200 | 3 min | 400 | 40 |

### 5.2 Animaux (phase 3)
Valeur produite ≈ 2,2 à 2,8 fois le coût de la nourriture consommée.

| Animal | Prix | Ressource | Vente | Cycle | Rations / cycle | Mange |
|---|---|---|---|---|---|---|
| 🐔 Poule | 150 | 🥚 Œuf | 20 | 30 s | 1 | Blé, Maïs |
| 🐰 Lapin | 400 | 🐾 Fourrure | 45 | 45 s | 2 | Carotte |
| 🦆 Canard | 800 | 🪶 Plume | 70 | 60 s | 3 | Blé, Carotte |
| 🐑 Brebis | 1 500 | 🧶 Laine | 120 | 1 min 30 | 5 | Blé, Carotte |
| 🐐 Chèvre | 3 000 | 🍼 Lait de chèvre | 190 | 1 min 40 | 8 | Carotte, Tomate, Blé |
| 🐄 Vache | 6 000 | 🥛 Lait | 350 | 2 min | 12 | Blé, Maïs |
| 🐴 Cheval | 8 000 | 💩 Fumier (engrais) | 60 | 1 min 30 | 3 | Carotte, Blé |
| 🐷 Cochon | 15 000 | 🍄 Truffe | 800 | 3 min | 25 | Citrouille, Tomate, Maïs |

- Enclos : 4 animaux max, mangeoire de 300 rations, caisse de 30 ressources.
- Prix des enclos (du 1er au 8e) : 300, 1 500, 5 000, 15 000, 40 000, 100 000, 250 000, 600 000.
- Fumier : réduit de 50 % le temps de pousse restant d'une plante (une fois par plante).

### 5.3 Variantes (animaux, puis ressources et produits)

| Variante | Chance à l'achat | Vitesse de production | Valeur des ressources | Effet visuel |
|---|---|---|---|---|
| Normal | reste | x1 | x1 | aucun |
| Doré | 5 % | x1,25 | x2 | couleur or brillante |
| Arc-en-ciel | 1,5 % | x1,5 | x4 | couleurs arc-en-ciel animées |
| Légendaire | 0,4 % | x2 | x8 | or + aura lumineuse |
| Mythique | 0,1 % | x3 | x20 | arc-en-ciel + aura violette, annonce au serveur |

### 5.4 Bâtiments (phase 4)
Ordre de déblocage, choisi selon les ressources dont le joueur dispose en premier :
**Boulangerie** (blé, œufs) → **Filature** (laine) → **Laiterie** (lait) → **Fromagerie** →
**Atelier de couture** (tissu + plumes / fourrure). Chaque bâtiment demande le précédent et un
niveau de parcelle. La variante du **1er ingrédient** est transmise au produit.

| Bâtiment | Prix | Parcelle | Recettes (temps au niveau 1) |
|---|---|---|---|
| 🥖 Boulangerie | 1 500 | niv. 1 | 4 Blé → 🍞 Pain 70 (30 s) ; 3 Œufs + 2 Blé → 🍰 Gâteau 170 (1 min) |
| 🧶 Filature | 8 000 | niv. 1 | 2 Laine → 🧵 Fil 520 (1 min) ; 2 Fil → 🧣 Tissu 2 300 (2 min) |
| 🥛 Laiterie | 25 000 | niv. 2 | 1 Lait → 🍦 Crème 700 (45 s) ; 2 Lait → 🧈 Beurre 1 500 (1 min 30) |
| 🧀 Fromagerie | 60 000 | niv. 2 | 3 Lait de chèvre → Fromage de chèvre 1 300 (2 min) ; 3 Lait → 🧀 Fromage 2 400 (2 min 30) ; 2 Fromages + 1 Truffe → Fromage truffé 12 000 (4 min, bâtiment niv. 3) |
| 🪡 Atelier de couture | 150 000 | niv. 3 | 1 Tissu + 4 Plumes → 🛏️ Oreiller 5 800 (3 min) ; 1 Tissu + 5 Fourrures → 🧥 Manteau 5 600 (3 min) |

Améliorations (communes à tous les bâtiments, prix = prix du bâtiment × multiplicateur) :

| Niveau | Prix | Vitesse | Productions en même temps | File d'attente |
|---|---|---|---|---|
| 1 | — | x1 | 1 | 5 |
| 2 | x1,5 | x1,25 | 1 | 8 |
| 3 | x3 | x1,5 | 2 | 10 |
| 4 | x6 | x2 | 2 | 12 |
| 5 | x12 | x2,5 | 3 | 15 |

Stock de produits finis : 40 par bâtiment. Production hors ligne : 8 h max.

### 5.5 Créatures (phase 5)
4 zones, 8 créatures originales par zone (32 au total, dont 4 Divines marquées ✨) :

| Zone | Prix d'accès | Valeur x | Créatures (de Commune à Secrète) |
|---|---|---|---|
| 🌲 Forêt | gratuit | x1 | Mousselin, Glandinet, Champiloup, Lucifeuille, Cerfeuillu, Racinor, Murmure-des-Bois, ✨ Sylvanthe |
| ⛰️ Montagne | 25 000 | x4 | Caillouteux, Flocon, Bouquetonnerre, Givrelle, Grizzlune, Aquilorage, Yétinou, ✨ Auroréal |
| 🏜️ Désert | 100 000 | x15 | Dunelle, Scorpinou, Cactouille, Mirageon, Sphinxou, Pharaonix, Oasien, ✨ Solarion |
| 🌋 Volcan | 400 000 | x50 | Braisou, Cendrou, Magmoche, Salamandrix, Pyrodrake, Volcanosaure, Cœur-de-Lave, ✨ Ignaros |

| Rareté | Apparition | Valeur de base | Clics réussis | Largeur zone verte | Vitesse | Chance finale | Annonce |
|---|---|---|---|---|---|---|---|
| Commune | 60 % | 100 | 1 | 30 % | lente | 100 % | — |
| Rare | 25 % | 400 | 2 | 24 % | | 90 % | — |
| Épique | 10 % | 1 500 | 2 | 18 % | | 75 % | — |
| Légendaire | 4 % | 6 000 | 3 | 15 % | | 55 % | — |
| Mythique | 0,9 % | 25 000 | 3 | 12 % | | 40 % | bannière serveur |
| Secrète | 0,1 % | 120 000 | 4 | 10 % | très rapide | 30 % | chat + bannière |
| Divine | 0,001 % | 1 500 000 | 5 | 8 % | extrême | 25 % | tous les serveurs |

Valeur d'une créature = valeur de base × multiplicateur de zone × mutation. 2 ratés autorisés
par capture. En cas d'échec, la créature s'enfuit.

| Mutation | Chance | Valeur | Effet visuel |
|---|---|---|---|
| Dorée | 6 % | x2 | couleur or brillante |
| Géante | 4 % | x3 | taille x2 |
| Arc-en-ciel | 2 % | x5 | couleurs animées |
| Spectrale | 0,5 % | x10 | translucide et lumineuse |

### 5.6 Déplacement
Vitesse de marche 24 (au lieu de 16), sprint à 32 en maintenant Maj (bouton sur mobile).

### 5.7 Champs et mode construction (phase 5b)
- Champ : 3 × 2 cases, emprise 24 × 16 studs. 1 champ offert (6 cases débloquées).
- Prix des champs (du 2e au 10e) : 400, 1 500, 4 000, 10 000, 25 000, 60 000, 150 000, 350 000,
  800 000. Leurs cases arrivent verrouillées.
- Déblocage d'une case : 60 × 1,12^(cases déjà débloquées − 6) Coins (case 7 : 60, case 24 : ~410,
  case 60 : ~24 500).
- Nombre max d'éléments selon le niveau de parcelle (1 → 4) : champs 4 / 6 / 8 / 10, enclos
  2 / 4 / 6 / 8 ; bâtiments selon leur niveau de parcelle requis.
- Emprises : enclos 22 × 26 (mangeoire et caisse devant), bâtiment = sa taille + 2 × 4.
- Zone interdite : la bande d'entrée (les 10 premiers studs de profondeur : spawn, boutons
  d'agrandissement et de test). Placement sur une grille de 1 stud, rotation par quarts de tour.
