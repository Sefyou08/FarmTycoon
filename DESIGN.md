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
- **Grande parcelle** avec des zones : cultures devant, enclos sur les côtés, bâtiments au fond,
  socles d'exposition sur les bords (phase 6).
- **Agrandissement par étapes**, payé en Coins avec un prix croissant (bouton tycoon sur la
  parcelle). Chaque étape débloque de nouveaux emplacements (enclos, bâtiments, socles).
- Emplacement prévu pour un **Developer Product** qui débloque un agrandissement avec de l'argent
  réel : **désactivé**, activé en phase 8.

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
| 4 | Bâtiments de transformation (machines, recettes, files de production) + vitesse de marche et sprint | ✅ fait |
| 5 | Expéditions (portail, zones, créatures sauvages, capture) | ⏳ en cours |
| 6 | Collection et exposition (socles, Coins/s, Index, classement) | à faire |
| 7 | Progression (boutique tournante, plantes rares et mutations, collecteurs, rebirth, monture) | à faire |
| 8 | Monétisation (Game Passes, Developer Products, IDs factices) et finitions de l'UI | à faire |
| 9 | Décor (terrain, arbres, éclairage) + bâtiments et stands thématiques animés | à faire |

### Phase 3 : Animaux de ferme
- **Enclos** construits sur sa parcelle (boutons tycoon, prix croissant). Un enclos accueille
  **une seule espèce**, jusqu'à 4 animaux.
- **Animaux achetés** au stand 🐄 ANIMAUX (prix croissant d'une espèce à l'autre), avec une chance
  d'obtenir une **variante rare**. L'animal va automatiquement dans un enclos de son espèce qui a de
  la place, sinon dans un enclos vide. Plus tard, ils pourront aussi être capturés en expédition
  (phase 5).
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
- Exemples : laiterie (lait → beurre, crème), fromagerie (lait → fromage), filature
  (laine → fil → tissu), boulangerie (œufs + blé → gâteau, pain), etc.
- La variante de la ressource (Doré, etc.) se transmet au produit, avec son multiplicateur.

### Phase 5 : Expéditions
- Un **portail** sur la map envoie vers des zones séparées : Forêt, Montagne, Désert, puis
  d'autres zones à débloquer.
- Des **créatures sauvages** originales apparaissent avec une rareté : Commune, Rare, Épique,
  Légendaire, Mythique, **Secrète** (très faible chance, annoncée à tout le serveur quand
  quelqu'un en attrape une).
- **Capture** avec un mini-jeu simple : filet ou lasso, et une barre de timing.
- **Mutations** des créatures (Dorée, Arc-en-ciel, Géante…), qui multiplient leur valeur.
- Choix : les zones sont des **zones lointaines de la même place** (pas des places séparées
  avec TeleportService), comme dans la plupart des simulateurs Roblox : la sauvegarde, la parcelle
  et le serveur restent les mêmes, et c'est plus simple à tester dans Studio.
- Les créatures capturées vont dans la **collection** (sac de créatures, 100 max). En attendant
  les socles de la phase 6, on peut les **vendre** depuis la fenêtre de collection.
- Anti-triche de la capture : le serveur génère les paramètres du mini-jeu (vitesse, position des
  zones vertes), recalcule la position du curseur à chaque clic, vérifie que le temps envoyé est
  plausible, puis fait **un dernier tirage de chance** selon la rareté. Même un tricheur parfait ne
  peut donc pas garantir une Secrète.

### Phase 6 : Collection et exposition
- **Socles d'exposition** sur la base : chaque créature exposée génère des Coins/seconde selon sa
  rareté et sa mutation.
- Les autres joueurs peuvent **visiter** et voir la collection : nom, rareté, effet brillant pour
  les rares.
- **Index / Collection** : créatures découvertes et manquantes, avec une récompense pour chaque
  zone complétée.
- **Classement** des collections les plus rares.

### Phase 7 : Progression
- Boutique de graines **tournante** (stock rare renouvelé toutes les 5 min, compte à rebours).
- Plantes de rareté Rare, Épique et Légendaire, et **mutations de plantes** à la récolte.
- Cases de terre supplémentaires et **collecteurs automatiques** (récolte et ramassage).
- **Monture** (cheval) pour se déplacer plus vite sur la map.
- **Rebirth** : on remet à zéro coins et améliorations contre un multiplicateur de revenus
  permanent.

### Phase 8 : Monétisation et UI
- Game Passes (x2 Coins, collecteur VIP, emplacements en plus…), Developer Products (packs de
  Coins, agrandissement de parcelle). IDs factices dans Config, `ProcessReceipt` idempotent
  (reçus enregistrés dans la sauvegarde).
- Finitions de l'interface.

### Phase 9 : Décor et visuels thématiques
- Terrain (herbe), arbres, clôtures, chemins, éclairage, à la place du Baseplate gris.
- **Bâtiments thématiques** en style cartoon / low-poly, construits en Parts et formes simples
  (cylindres, boules, wedges), à la place des blocs avec un nom au-dessus :
  - **Boulangerie** : façade avec auvent rayé, vitrine avec baguettes, croissants et pains, une
    baguette ou un croissant géant sur le toit, un four visible.
  - **Laiterie** : une bouteille de lait géante, une vache stylisée reliée à la bouteille par un
    tuyau, du lait qui « coule » (animation) quand la production tourne.
  - **Fromagerie** : une grosse meule de fromage à trous, une machine avec une roue animée
    pendant la production.
  - **Filature** : un rouet géant qui tourne, des pelotes de laine colorées.
  - **Atelier de couture** : une machine à coudre géante, des rouleaux de tissu.
  - **Stands** (graines, vente, animaux) décorés dans le même style : caisses de légumes et
    sachets de graines, balance et sacs de pièces, bottes de foin et barrière d'enclos.
- **Animations** (roues qui tournent, lait qui coule, fumée) actives **uniquement quand le bâtiment
  produit** (la file n'est pas vide), comme la fumée de cheminée actuelle.
- Technique : animations calculées **côté client** (aucun trafic réseau). Le serveur pose
  seulement un attribut `Working` sur le bâtiment, et le client fait tourner les parts taguées.
  Chaque visuel est isolé dans une fonction par bâtiment, pour pouvoir remplacer plus tard par un
  vrai modèle 3D sans toucher au gameplay.

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
4 zones, 7 créatures originales par zone (28 au total) :

| Zone | Prix d'accès | Valeur x | Créatures (de Commune à Secrète) |
|---|---|---|---|
| 🌲 Forêt | gratuit | x1 | Mousselin, Glandinet, Champiloup, Lucifeuille, Cerfeuillu, Racinor, Murmure-des-Bois |
| ⛰️ Montagne | 25 000 | x4 | Caillouteux, Flocon, Bouquetonnerre, Givrelle, Grizzlune, Aquilorage, Yétinou |
| 🏜️ Désert | 100 000 | x15 | Dunelle, Scorpinou, Cactouille, Mirageon, Sphinxou, Pharaonix, Oasien |
| 🌋 Volcan | 400 000 | x50 | Braisou, Cendrou, Magmoche, Salamandrix, Pyrodrake, Volcanosaure, Cœur-de-Lave |

| Rareté | Apparition | Valeur de base | Clics réussis | Largeur zone verte | Vitesse | Chance finale | Annonce |
|---|---|---|---|---|---|---|---|
| Commune | 60 % | 100 | 1 | 30 % | lente | 100 % | — |
| Rare | 25 % | 400 | 2 | 24 % | | 90 % | — |
| Épique | 10 % | 1 500 | 2 | 18 % | | 75 % | — |
| Légendaire | 4 % | 6 000 | 3 | 15 % | | 55 % | — |
| Mythique | 0,9 % | 25 000 | 3 | 12 % | | 40 % | bannière serveur |
| Secrète | 0,1 % | 120 000 | 4 | 10 % | très rapide | 30 % | chat + bannière |

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
