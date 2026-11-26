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
| 3 | Animaux de ferme, enclos, variantes rares, parcelles agrandissables | 🧪 codée, à tester |
| 4 | Bâtiments de transformation (machines, recettes, files de production) | à faire |
| 5 | Expéditions (portail, zones, créatures sauvages, capture) | à faire |
| 6 | Collection et exposition (socles, Coins/s, Index, classement) | à faire |
| 7 | Progression (boutique tournante, plantes rares et mutations, collecteurs, rebirth, monture) | à faire |
| 8 | Monétisation (Game Passes, Developer Products, IDs factices) et finitions de l'UI | à faire |
| 9 | Décor (terrain, arbres, clôtures, chemins, éclairage) | à faire |

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

### Phase 9 : Décor
- Terrain (herbe), arbres, clôtures, chemins, éclairage, à la place du Baseplate gris.

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

### 5.4 Bâtiments (phase 4, provisoire)
Ordre de déblocage visé : Laiterie → Filature → Fromagerie → Boulangerie → autres.
Un produit transformé vaut environ 1,8 à 2,5 fois la valeur des ressources utilisées.

| Bâtiment | Recettes envisagées |
|---|---|
| Laiterie | Lait → Beurre ; Lait → Crème |
| Filature | Laine → Fil ; Fil → Tissu |
| Fromagerie | Lait (ou lait de chèvre) → Fromage |
| Boulangerie | Œufs + Blé → Gâteau ; Blé → Pain |

### 5.5 Créatures (phase 5, provisoire)
Raretés : Commune, Rare, Épique, Légendaire, Mythique, Secrète (de la plus fréquente à la plus
rare). Les chances et les revenus exposés seront fixés en phase 5, dans Config.
