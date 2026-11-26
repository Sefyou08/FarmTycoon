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
| 6 | Collection et exposition (socles, Coins/s, visite, Index, classement) + vitrine de prestige + rareté Divine | ✅ fait |
| 7 | Progression + ressources et recettes rares + consommables, boosts, XP + aides PNJ | ✅ fait |
| 8 | Donjon (ennemis, boss, combat simple, récompenses rares) + œufs de créatures | ✅ fait |
| 9 | Monétisation (Game Passes, Developer Products, IDs factices) + roue quotidienne + personnalisation cosmétique | ✅ fait |
| 10 | Direction artistique complète (créatures, animaux, zones, ferme, bâtiments, donjons) + motifs cosmétiques + mascotte | 🧪 codée, à tester |

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
  restant. C'est aussi une **monture** (voir 5.10).
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
- **XP et niveau joueur** : on gagne de l'XP en récoltant, produisant, fabriquant et capturant ;
  le niveau débloque du contenu (fermier, monture, soigneur, rebirth) et donne des Coins.
- **Aides automatiques** achetables et améliorables avec des Coins :
  - un **fermier PNJ** qui plante et récolte tout seul ;
  - un **soigneur PNJ** qui nourrit les animaux et ramasse la production.

### Phase 8 : Donjon
- Un **portail rouge ⚔️ DONJONS** près du spawn ; 4 donjons débloqués par le niveau du joueur.
- Parties **solo**, dans une **arène réservée** au joueur (loin de la map) : vagues d'ennemis,
  puis un **boss**.
- **Combat simple**, entièrement décidé par le serveur :
  - **PV propres au donjon** (pas la vie Roblox), selon le niveau, x boost ⚔️ Combat ;
  - **⚔️ Attaque** (clic gauche, F ou bouton) : le serveur frappe l'ennemi le plus proche à portée ;
  - **💨 Esquive** (Q ou bouton) : bond + invulnérabilité courte ;
  - les ennemis deviennent **rouges** avant de frapper (le temps d'esquiver) ; les boss font une
    **attaque de zone** annoncée par un **cercle rouge** au sol.
- **Récompenses** : Coins, XP, bonus de 1re victoire, et butin aléatoire (graines rares, **œufs de
  créatures**, ingrédients Légendaires et Mythiques). Sac plein : le butin est converti en Coins.
- **Œufs de créatures** : 🐣 Couver depuis le sac (3 couveuses), éclosion après un délai (même hors
  ligne) ; ils donnent une créature de leur zone avec des **raretés hautes favorisées**.
- Les **boosts** des consommables s'appliquent au donjon (Combat) et en expédition (Capture).
- **Performance** : les ennemis n'existent côté serveur que sous forme de données ; le serveur
  envoie un petit instantané 10 fois par seconde (positions, PV, état, événements), et le
  **client** crée les modèles, les déplace en douceur et joue toutes les animations.
- **Animations (client)** : épée en main, combo de 3 coups, trace lumineuse, impact sur l'ennemi
  (flash, recul, particules, son, nombre de dégâts), roulade d'esquive, ennemis qui marchent,
  arment leur coup, chargent, meurent ; le boss saute avant son attaque de zone (onde de choc).

### Phase 9 : Monétisation
- Game Passes et Developer Products, avec des **IDs factices** dans Config et un `ProcessReceipt`
  idempotent (reçus enregistrés dans la sauvegarde).
- **Principes** : petits prix, **chances toujours affichées** pour tout achat au résultat aléatoire
  (règle Roblox), et un jeu qui reste **agréable et complet pour les joueurs gratuits**. Tout est
  décidé et validé **côté serveur**.
- **Achats en Robux** (Developer Products / Game Passes) :
  - **agrandissement de parcelle** plus rapide (emplacement déjà prévu : `PlotService:GrantExpansion`) ;
  - **accélération** de la pousse des plantes, de l'éclosion des œufs, de la production des
    animaux et des bâtiments ;
  - **boosts** : vitesse, Coins, XP, chance de capture, force au donjon ;
  - **version premium des aides automatiques** (emplacement prévu : `HelperService:GetSpeedMultiplier`) ;
  - **emplacements en plus** (inventaire, collection, couveuses...), packs de Coins, x2 Coins.
- **🎡 Roue quotidienne** :
  - s'affiche **à la connexion**, et via un bouton **🎡 Roue** dans le HUD ;
  - **1 tour gratuit toutes les 24 h**, avec un compte à rebours ; le délai est **sauvegardé** ;
  - récompenses : Coins, graines (dont des rares), boosts, XP, rations, et **rarement** un œuf ou
    une créature ;
  - récompense **ultra rare (0,1 %)** : un **animal de ferme EXCLUSIF à la roue**, impossible à
    obtenir autrement, vraiment beau (design original, couleurs vives, aura et particules uniques),
    qui produit une **ressource exclusive de grande valeur** ; son obtention est **annoncée sur
    tous les serveurs** (AnnouncementService, portée "Global") ;
  - **animation avec suspense** (la roue ralentit, le résultat est décidé AVANT par le serveur et
    l'animation s'arrête dessus) ;
  - **chances affichées** dans la fenêtre de la roue ;
  - **tours supplémentaires achetables en Robux**.
- **Personnalisation cosmétique** :
  - **uniquement cosmétique**, aucun avantage de gameplay (pas de pay-to-win) ;
  - skins d'enclos (clôtures en bois, pierre, bonbon, or, néon…), sols de parcelle, couleurs et
    motifs des bâtiments, panneau de parcelle personnalisé, effets autour de la vitrine
    (particules, lumières), traces de pas, titres affichés au-dessus du joueur ;
  - **champs** (bordures, terre, décorations) et **animaux** (skins, couleurs, accessoires) ;
  - **montures** : selles, skins, couleurs, accessoires (tête, crinière, harnais) ;
  - petits prix en Robux (environ **25 à 150 Robux**), et certains cosmétiques **débloquables en
    jouant** (succès, Index complété, niveaux) pour que les joueurs gratuits puissent aussi se
    distinguer ;
  - un menu **« 🎨 Personnaliser »** avec un **aperçu avant l'achat** ;
  - si un achat payant donne un résultat aléatoire, **afficher clairement les chances** (règle
    Roblox).

**Réalisé (phase 9)** :
- `MonetizationService` : Game Passes vérifiés à l'arrivée (attribut `Pass_<Nom>` sur le joueur),
  `ProcessReceipt` idempotent (`data.PurchaseHistory`, 300 derniers reçus, sauvegarde immédiate),
  `NotProcessedYet` si les données ne sont pas prêtes. Id = 0 → bouton « Bientôt disponible ».
- `WheelService` + `WheelUI` (🎡) : tirage serveur, bande de cases qui ralentit jusqu'au résultat,
  chances affichées, ouverture auto à la connexion, tours achetés en réserve.
- **Astrelune** 🦄 (0,1 %) : licorne céleste exclusive (aura, particules, crinière rose, corne
  lumineuse), produit la **Poussière d'étoile** (30 000 Coins). Montable (56 / 70, saut 90).
  Sans enclos libre, elle attend (`data.PendingAnimals`) et arrive dès qu'un enclos se libère.
- `CosmeticService` + `CosmeticsUI` (🎨) : 10 catégories, déblocage gratuit / niveau / Index /
  Coins / Robux, aperçu 👁 (traces et titre essayés sur ton personnage).
- `StoreUI` (💎 Boutique) : passes et produits, prix affichés.

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
- **Créatures rares** : en attendant, les Légendaires, Mythiques, Secrètes et Divines sont
  agrandies (Divine x2,6), avec des couleurs plus vives, plus de particules et de lumière
  (`Config.CreatureRarities[x].Visual`). Leur **design complet est à refaire** en phase 10.
- **Modèles de la Toolbox** : certains modèles pourront être remplacés par des modèles de la
  Toolbox. Le système est déjà en place pour les créatures : un Model nommé comme l'id de la
  créature dans `ServerStorage/CustomModels/Creatures` remplace le modèle généré (taille de
  rareté, mutation Géante et lumières appliquées par-dessus). Même principe à prévoir pour les
  animaux et les bâtiments.
- **Organisation du code des modèles** : une fonction de construction par créature, animal et
  bâtiment, derrière une interface commune. On pourra ainsi remplacer un modèle généré par un vrai
  modèle 3D (MeshPart importé, rangé dans ReplicatedStorage) **un par un**, sans toucher au
  gameplay.

**Réalisé (phase 10)** — tout en Parts / Terrain, chaque modèle derrière une fonction dédiée :
- **Ferme** (`FarmScenery`) : Terrain d'herbe animée à la place du Baseplate, anneau de montagnes
  enneigées, ruisseau nord-sud + étang, pont arrondi à lanternes, chemins de terre bordés de
  cailloux, chênes / sapins / pommiers, buissons, fleurs, clôture, place pavée du spawn avec la
  statue de la mascotte et un panneau d'accueil, éclairage chaud.
- **Éclairage par lieu** (`LightingController`, `Config.Art.Lighting`) : ferme, 4 zones, donjon,
  transition douce, particules d'ambiance (pollen, lucioles, flocons, sable, braises), musique
  par lieu (`Config.Art.Music`).
- **Bâtiments** (`BuildingBuilder`) : boulangerie, laiterie, fromagerie, filature, atelier ;
  fumée / feu / lait seulement en production, roues / aiguille animées par le client
  (`BuildingAnimator`, attribut `Working`). **Stands** décorés (`StandBuilder`, thèmes).
- **Animaux** (`AnimalBuilder`) : vache, poule, canard, lapin, brebis, chèvre, cochon, chevaux ;
  pattes, tête, queue, ailes animées (`AnimalController`, attributs `Anim` / `Hinge`).
- **Créatures** (`CreatureBuilder`) : une fonction par créature sur 7 silhouettes (boule,
  quadrupède, lézard, insecte, volant, oiseau, bipède), yeux expressifs, chevaux sauvages =
  vrais chevaux. **Zones** (`ZoneScenery`) : identité complète par zone.
- **Donjons** : décor thématique par arène (`ArenaDecor`), ennemis et boss redessinés
  (`EnemyBuilder`, client) avec pattes / bras animés.
- **Motifs cosmétiques** (`PatternBuilder`) : étoiles, cœurs, diamants, perles, fleurs, flammes,
  nuages, damier, rayures, paillettes, licornes, mascotte — sur bâtiments, clôtures, sols,
  panneaux, selles ; image facultative par motif (`Config.Art.Decals`, liste dans le README).
- **Mascotte originale** : **Biscotte**, chaton fermier abricot (chapeau de paille, salopette
  verte, carotte) — statue au spawn, motif, cosmétiques « Biscotte » (`MascotBuilder`).
- **Remplacement par des modèles Toolbox** : `ServerStorage.CustomModels.<Catégorie>.<id>`
  (Creatures, Animals, Buildings, Stands, Mascot) et `ReplicatedStorage.CustomModels.Enemies`.

**Corrections après la phase 10** :
- Herbe 3D du Terrain désactivée, terre sous les parcelles : sols, champs, enclos et socles bien visibles ;
  le cosmétique de sol s'applique au sol de la parcelle.
- **🐾 Mes animaux** (`data.AnimalInventory`, RemoteFunction `AnimalAction`) : tout animal acheté / gagné
  arrive dans l'inventaire ; on choisit l'enclos, on peut le retirer ; ⭐ l'épingle dans la vitrine.
  La vitrine ne montre plus d'animaux par défaut (seulement s'ils sont épinglés).
- Donjons bien éclairés (`Config.Art.Lighting.Dungeon` + lumières d'arène) et contour `Highlight` sur
  les ennemis et les boss.
- **Tutoriel** (`TutorialService`, `Config.Tutorial`) : 17 quêtes avec récompense, flèche (Beam + flèche
  3D) ou bouton du HUD qui clignote, objectif en haut de l'écran, passer / relancer. Les services
  signalent les actions par `GameEvents`.
- **❓ Guide** (`GuideUI`) et **récompenses de temps de jeu** (`PlaytimeService`, `Config.Playtime`).

**Lisibilité et boutons tycoon** :
- Sol de la ferme et de la Forêt : UNE couche de grandes Parts en matériau Grass (texture plate, sans
  brins) ; aucun Terrain dessous (`Terrain:Clear()` au démarrage, Terrain seulement pour l'eau et les
  montagnes) : plus de terre ni d'herbe qui perce au travers.
- Éléments interactifs surélevés et lumineux : jardinières des champs (cadre coloré, case à débloquer
  dorée, panneau 🌱), socles et vitrine plus hauts avec liseré, disques lumineux devant stands et
  portails, paillasson lumineux devant les portes, repères sous la mangeoire et la caisse.
- Clôture continue autour de chaque parcelle (`FenceBuilder`), qui suit l'agrandissement, portail à
  lanternes ; cosmétique « Clôture de parcelle » (bois, piquets, pierre, bonbon, néon, or, motifs).
- Animaux et créatures posés exactement sur le sol (`ArtKit.SnapToGround`).
- Boutons au sol (`TycoonPad`, `Config.TycoonPads`) : 💰 / 💎 Agrandir, boosts Robux de 2 h avec
  minuteur du boost actif (`PadController`).

**Limites de la map et vente au choix** :
- Murs invisibles de 160 studs (`Config.Bounds`) : cercle autour de la ferme (avant les montagnes),
  autour de chaque zone et de chaque arène. `BoundaryService` ramène tout joueur hors limites ou
  tombé sous la map (arène → entrée, zone → portail de retour, ferme → parcelle) sans réapparition ;
  une zone / arène atteinte sans passer par le portail renvoie à la ferme.
- Stand de vente : fenêtre `SellUI` (onglets, quantité par objet, sélection, tout vendre),
  RemoteFunction `SellItems` validée par le serveur.

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

| Rareté | Apparition | Valeur de base | Taille | Annonce |
|---|---|---|---|---|
| Commune | 60 % | 100 | x1 | — |
| Rare | 25 % | 400 | x1,05 | — |
| Épique | 10 % | 1 500 | x1,2 | — |
| Légendaire | 4 % | 6 000 | x1,5 | — |
| Mythique | 0,9 % | 25 000 | x1,8 | bannière serveur |
| Secrète | 0,1 % | 120 000 | x2,1 | chat + bannière |
| Divine | 0,001 % | 1 500 000 | x2,6 | tous les serveurs |

**Modes de capture** : au début de chaque capture, le joueur choisit **🎯 Sûr** (100 % de chance
finale, mini-jeu un peu plus dur) ou **⚡ Rapide** (mini-jeu un peu plus facile, chance finale plus
faible). L'écart de difficulté reste léger. Format : réussites / zone verte / vitesse du curseur /
ratés permis / chance finale.

| Rareté | 🎯 Sûr | ⚡ Rapide |
|---|---|---|
| Commune | 1 / 26 % / 0,85 / 2 / 100 % | 1 / 32 % / 0,78 / 2 / 97 % |
| Rare | 2 / 23 % / 0,9 / 2 / 100 % | 2 / 28 % / 0,82 / 2 / 92 % |
| Épique | 3 / 21 % / 0,9 / 2 / 100 % | 2 / 25 % / 0,86 / 2 / 87 % |
| Légendaire | 4 / 19 % / 0,95 / 2 / 100 % | 3 / 22 % / 0,9 / 2 / 80 % |
| Mythique | 4 / 17 % / 1,0 / 3 / 100 % | 3 / 20 % / 0,95 / 3 / 75 % |
| Secrète | 5 / 15 % / 1,05 / 3 / 100 % | 4 / 18 % / 1,0 / 3 / 75 % |
| Divine | 6 / 10 % / 1,1 / 3 / 100 % | 5 / 16 % / 1,05 / 3 / 75 % |

La difficulté vient du **nombre de réussites à enchaîner** et d'une zone verte un peu plus petite,
pas d'une vitesse impossible. Tout est réglable par rareté et par mode dans
`Config.CreatureRarities[x].Capture.Safe / .Fast` (et l'apparence dans `.Visual`). Le boost
« Capture » élargit la zone verte et augmente la chance finale du mode Rapide.

**Captures partagées (course)** : les créatures sauvages sont les mêmes pour tous les joueurs de la
zone. Plusieurs joueurs peuvent tenter la même en même temps ; le **premier qui réussit la gagne**.
Un joueur qui échoue ne peut plus la retenter ; elle ne s'enfuit que si personne d'autre n'essaie.
Les Mythiques, Secrètes et Divines ont une **colonne de lumière** visible de loin et une étiquette
visible à travers le décor ; leur apparition est annoncée (zone pour les Mythiques, tout le serveur
pour les Secrètes et Divines).

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

### 5.8 Progression, ressources rares, consommables et aides (phase 7)
**XP** : XP pour passer du niveau N au N+1 = 30 × N^1,5 (niveau 1 → 2 : 30 XP ; 14 → 15 : ~1 570 XP).
Récolte 3 XP × rang de rareté de la culture, ressource animale 2, produit fabriqué 6, capture de 10
(Commune) à 5 000 (Divine). Passage de niveau : 100 × niveau en Coins.
Déblocages : 🧑‍🌾 Fermier niv. 5, 🐴 Monture niv. 6, 🧺 Soigneur niv. 8, ⭐ Rebirth niv. 15.

**Boutique tournante** : nouveau stock toutes les 5 min, même stock pour le serveur, quantité par
joueur. Chance d'être en stock : Rare 80 % (3 à 6), Épique 40 % (1 à 3), Légendaire 12 % (1).

| Culture rare | Rareté | Graine | Pousse | Vente |
|---|---|---|---|---|
| 🍓 Fraise | Rare | 150 | 1 min | 320 |
| 🫐 Myrtille | Rare | 250 | 1 min 20 | 520 |
| 🍉 Pastèque | Épique | 900 | 2 min 30 | 2 000 |
| 🐉 Fruit du dragon | Épique | 1 500 | 3 min 20 | 3 400 |
| 🌟 Fleur étoilée | Légendaire | 6 000 | 6 min | 15 000 |
| 🌙 Citrouille lunaire | Légendaire | 10 000 | 8 min | 26 000 |

**Mutations de plantes** à la récolte (mêmes variantes que les animaux) : Dorée 4 %, Arc-en-ciel
1 %, Légendaire 0,2 %, Mythique 0,04 %, multipliées par 1,5 / 2 / 3 pour les cultures Rares /
Épiques / Légendaires.

**Ressources rares** : chance qu'une production soit d'une variante supérieure à celle de
l'animal : Normal 3 %, Doré 5 %, Arc-en-ciel 7 %, Légendaire 10 %.

**Recettes rares** (ingrédient principal d'une variante minimale) : Gâteau royal (Œufs Dorés+),
Pain céleste (Blé Légendaire+), Tissu arc-en-ciel (Laine Arc-en-ciel+), Fromage légendaire (Lait
Légendaire+), Crème divine (Lait Mythique), Manteau royal (Fourrure Dorée+).

**Consommables** : 🍴 dans le sac. Puissance et durée +50 % par rang de variante de l'objet mangé,
1 h maximum en cumulant. Exemples : Pain → vitesse +15 % 2 min ; Gâteau → XP +25 % 3 min ; Beurre →
Coins +20 % 4 min ; Fromage → capture +10 % 5 min ; Crème divine → Coins +100 % 20 min.
Le boost Combat est stocké pour le donjon (phase 8).

**Monture** : il faut un cheval dans un enclos ; vitesse 40 (48 en sprint).

**Rebirth** : 1 000 000 Coins × 3^rebirths ; gains de Coins (vente + socles) × (1 + 0,5 × rebirths).
Perdu : Coins, agrandissements, champs (1 gardé), plantes, graines, enclos + animaux, bâtiments,
inventaire. Gardé : créatures, Index, zones, socles (rangés), niveau / XP, aides, boosts.

**Aides PNJ** :

| Niveau | Fermier (prix / tournée / cases) | Soigneur (prix / tournée / enclos) |
|---|---|---|
| 1 | 5 000 / 20 s / 3 | 15 000 / 30 s / 1 |
| 2 | 20 000 / 15 s / 5 | 40 000 / 25 s / 2 |
| 3 | 60 000 / 10 s / 8 | 100 000 / 20 s / 4 |
| 4 | 150 000 / 7 s / 12 | 250 000 / 15 s / 6 |
| 5 | 400 000 / 5 s / 18 | 600 000 / 10 s / 8 |

### 5.9 Donjons et œufs (phase 8)
**Joueur** : PV = (100 + 6 × niveau) × boost Combat ; dégâts = (20 + 3 × niveau) × boost Combat ;
dégâts reçus ÷ boost Combat. Attaque toutes les 0,45 s (portée 9), esquive toutes les 1,5 s
(0,5 s d'invulnérabilité). 10 min max par donjon.

| Donjon | Niveau | Vagues | Boss (PV) | Coins | XP | 1re victoire | Butin possible |
|---|---|---|---|---|---|---|---|
| 🌳 Grotte des Racines | 8 | 2 | Vieux Chêne Grognon (1 200) | 3 000 – 6 000 | 200 | +10 000 | Fraises, Pastèques, Œuf de la Forêt, Œufs Légendaires, Blé Mythique |
| ❄️ Mine de Givre | 14 | 3 | Reine du Givre (3 200) | 15 000 – 30 000 | 500 | +50 000 | Myrtilles, Fruits du dragon, Œuf de la Montagne, Laine Mythique, Lait Légendaire |
| 🏛️ Temple Ensablé | 20 | 3 | Gardien des Dunes (6 500) | 60 000 – 120 000 | 1 200 | +200 000 | Fleurs étoilées, Œuf du Désert, Lait Mythique, Truffes Légendaires |
| 🌋 Forge Volcanique | 28 | 3 | Titan de Lave (13 000) | 250 000 – 500 000 | 3 000 | +800 000 | Citrouilles lunaires, Œuf du Volcan, Truffes Mythiques, Lait Mythique |

Ennemis : Ronceux, Champitox, Givrelin, Cognebloc, Scarabix, Ventsableux, Braisard, Magmolosse
(créatures originales). Toutes les valeurs : `Config.Combat`, `Config.Enemies`, `Config.Dungeons`.

**Œufs** : Forêt 1 min, Montagne 2 min, Désert 4 min, Volcan 8 min d'éclosion. Poids d'apparition
multipliés : Rare x1,5, Épique x3, Légendaire x5, Mythique x8, Secrète et Divine x10.

### 5.10 Montures et chevaux sauvages
- **Monture** (niveau 6) : bouton 🐴 → choix du cheval parmi ceux possédés (enclos + chevaux
  sauvages de la collection). Le personnage est **assis** sur le dos (animation « assis » de
  Roblox, vue par tous) ; le cheval est soudé sous lui et **animé par les clients** (pattes au pas
  et au galop, tête, queue). Le personnage garde la physique : direction, sprint, saut, rotation.
- Descente : bouton 🐴, mort, déconnexion, portail d'expédition ou de donjon. Pas de monture en
  donjon.
- La variante du cheval (Doré, Arc-en-ciel, Légendaire, Mythique) se voit sur la monture et donne
  +5 % de vitesse par rang. Mutation d'un cheval sauvage → variante : Doré → Doré, Géant →
  Légendaire, Arc-en-ciel → Arc-en-ciel, Spectral → Mythique.

| Cheval | Origine | Rareté | Vitesse / galop | Saut | Particularité | Production en enclos |
|---|---|---|---|---|---|---|
| Cheval | stand 🐄 (8 000) | — | 40 / 48 | 50 | Fidèle cheval de ferme | 💩 Fumier |
| Mousseval | 🌲 Forêt | Rare | 44 / 54 | 58 | Agile et équilibré | 🌿 Crin de mousse (450) |
| Givrecrin | ⛰️ Montagne | Épique | 44 / 54 | 80 | Saute très haut | ❄️ Crin de givre (1 200) |
| Sablecrin | 🏜️ Désert | Épique | 52 / 64 | 50 | Le plus rapide | ✨ Crin doré (2 500) |
| Brasecrin | 🌋 Volcan | Légendaire | 50 / 62 | 65 | Rapide et puissant | 🔥 Crin de braise (6 000) |

Un cheval sauvage capturé reste dans la collection (monture possible) ; le bouton 🐾 le met dans
un enclos, où il produit son crin et reste une monture. Valeurs : `Config.Mounts`,
`Config.Animals` (espèces ForestHorse, SnowHorse, SandHorse, LavaHorse), `Config.Creatures`.

### 5.11 Monétisation, roue et cosmétiques (phase 9)
Tous les prix et effets : `Config.Monetization`, `Config.Wheel`, `Config.Cosmetics`.

| Game Pass | Prix | Effet |
|---|---|---|
| 💰 x2 Coins | 199 R$ | gains de Coins x2 |
| 🧑‍🌾 Aides premium | 249 R$ | tournées des aides 2x plus rapides |
| 🎒 Grand sac | 99 R$ | +300 places |
| 🐣 Couveuses en plus | 149 R$ | +2 couveuses |
| 📖 Grande collection | 149 R$ | +100 créatures |

Developer Products : packs de Coins (25 / 99 / 299 R$, montant selon le niveau), agrandissement
(99 R$ ; Coins si déjà au maximum), éclosion immédiate (25 R$), tours de roue (19 R$ / 5 pour
79 R$), boosts 30 min de 15 à 49 R$ (pousse, production, Coins, XP, vitesse, capture, force).

Roue (total des poids = 100, donc poids = %) : Coins 25 %, fraises 14 %, gros Coins 10 %,
boost Coins 8 %, boost XP 8 %, XP 8 %, fruit du dragon 6 %, boost pousse 6 %, rations 5 %,
boost capture 4 %, œuf Forêt 2,5 %, fleur étoile 2 %, œuf Montagne 1 %, créature du Désert 0,4 %,
**Astrelune 0,1 %**.

Cosmétiques : 25 à 150 R$ ; environ la moitié se débloque en jouant (niveaux 8 à 25, Index de zone,
Coins).
