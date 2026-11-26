# Version de sortie : achats à créer et réglages Roblox

Les IDs vont dans `src/shared/Config.lua`. Un ID laissé à `0` affiche « Bientôt disponible ».

## Game Passes (Créations > ton jeu > Monétisation > Passes)

Où mettre l'ID : `Config.Monetization.GamePasses.<Clé>.Id`

| Clé dans Config | Nom à afficher | Prix (R$) | Description pour Roblox |
|---|---|---|---|
| `DoubleCoins` | 💰 x2 Coins | 199 | Tous tes gains de Coins (vente, socles) x2, pour toujours. |
| `PremiumHelpers` | 🧑‍🌾 Aides premium | 249 | Le fermier et le soigneur font leurs tournées 2x plus vite. |
| `BigBackpack` | 🎒 Grand sac | 99 | +300 places dans ton sac. |
| `ExtraIncubators` | 🐣 Couveuses en plus | 149 | +2 œufs qui couvent en même temps. |
| `BigCollection` | 📖 Grande collection | 149 | +100 places pour tes créatures. |

## Developer Products (Monétisation > Produits pour développeurs)

Où mettre l'ID : `Config.Monetization.Products.<Clé>.Id`

| Clé dans Config | Nom à afficher | Prix (R$) | Description pour Roblox |
|---|---|---|---|
| `PlotExpansion` | 🗺️ Agrandissement | 99 | Agrandis ta parcelle d'un niveau tout de suite. |
| `CoinsSmall` | 💰 Petit sac de Coins | 25 | Des Coins (plus si ton niveau est haut). |
| `CoinsMedium` | 💰 Coffre de Coins | 99 | Beaucoup de Coins. |
| `CoinsLarge` | 💰 Trésor de Coins | 299 | Énormément de Coins. |
| `GrowthBoost` | 🌱 Pousse x2 (30 min) | 39 | Les plantes semées poussent 2x plus vite. |
| `ProductionBoost` | 🏭 Production x2 (30 min) | 49 | Animaux et bâtiments produisent 2x plus vite. |
| `CoinsBoost` | 💰 Coins x2 (30 min) | 49 | Gains de Coins x2 pendant 30 min. |
| `XPBoost` | ⭐ XP x2 (30 min) | 29 | XP x2 pendant 30 min. |
| `SpeedBoost` | 🏃 Vitesse +30 % (30 min) | 15 | Tu cours plus vite. |
| `CaptureBoost` | 🪢 Capture +25 % (30 min) | 39 | Zone verte plus large et meilleure chance finale. |
| `CombatBoost` | ⚔️ Force +50 % (30 min) | 39 | Plus de PV et de dégâts au donjon. |
| `HatchNow` | 🐣 Éclosion immédiate | 25 | Tous tes œufs en couveuse éclosent tout de suite. |
| `XPBoost2h` | ⚡ XP x2 (2 h) | 79 | XP x2 pendant 2 heures. |
| `CoinsBoost2h` | 💰 Coins x2 (2 h) | 129 | Gains de Coins x2 pendant 2 heures. |
| `ProductionBoost2h` | 🏭 Production x2 (2 h) | 129 | Animaux et bâtiments 2x plus rapides pendant 2 heures. |
| `GrowthBoost2h` | 🌱 Pousse x2 (2 h) | 99 | Plantes 2x plus rapides pendant 2 heures. |
| `WheelSpin` | 🎡 1 tour de roue | 19 | Un tour de roue en plus. |
| `WheelSpins5` | 🎡 5 tours de roue | 79 | Cinq tours de roue en plus. |

## Cosmétiques payants (un Developer Product par cosmétique)

Où mettre l'ID : `Config.Cosmetics.<Clé>.Unlock.ProductId`

| Clé dans Config | Nom à afficher | Prix (R$) | Description pour Roblox |
|---|---|---|---|
| `PenCandy` | Clôture d'enclos : Bonbon | 49 | Cosmétique clôture d'enclos « Bonbon » (visuel uniquement). |
| `PenNeon` | Clôture d'enclos : Néon | 79 | Cosmétique clôture d'enclos « Néon » (visuel uniquement). |
| `PenGold` | Clôture d'enclos : Or | 99 | Cosmétique clôture d'enclos « Or » (visuel uniquement). |
| `FloorLava` | Sol de parcelle : Roche volcanique | 99 | Cosmétique sol de parcelle « Roche volcanique » (visuel uniquement). |
| `FloorRoyal` | Sol de parcelle : Velours royal | 149 | Cosmétique sol de parcelle « Velours royal » (visuel uniquement). |
| `BuildCandy` | Couleurs des bâtiments : Bonbon | 49 | Cosmétique couleurs des bâtiments « Bonbon » (visuel uniquement). |
| `BuildGold` | Couleurs des bâtiments : Palais doré | 99 | Cosmétique couleurs des bâtiments « Palais doré » (visuel uniquement). |
| `FieldGold` | Bordure de champ : Or | 49 | Cosmétique bordure de champ « Or » (visuel uniquement). |
| `SignGold` | Panneau de parcelle : Or | 25 | Cosmétique panneau de parcelle « Or » (visuel uniquement). |
| `SignNeon` | Panneau de parcelle : Néon | 49 | Cosmétique panneau de parcelle « Néon » (visuel uniquement). |
| `FXRainbow` | Effet de vitrine : Arc-en-ciel | 99 | Cosmétique effet de vitrine « Arc-en-ciel » (visuel uniquement). |
| `FXStars` | Effet de vitrine : Pluie d'étoiles | 149 | Cosmétique effet de vitrine « Pluie d'étoiles » (visuel uniquement). |
| `TrailSparkle` | Traces de pas : Paillettes | 49 | Cosmétique traces de pas « Paillettes » (visuel uniquement). |
| `TrailRainbow` | Traces de pas : Arc-en-ciel | 99 | Cosmétique traces de pas « Arc-en-ciel » (visuel uniquement). |
| `TitleLegend` | Titre : Légende | 75 | Cosmétique titre « Légende » (visuel uniquement). |
| `TitleVIP` | Titre : VIP | 150 | Cosmétique titre « VIP » (visuel uniquement). |
| `HatParty` | Chapeau des animaux : Chapeau de fête | 25 | Cosmétique chapeau des animaux « Chapeau de fête » (visuel uniquement). |
| `HatCrown` | Chapeau des animaux : Couronne | 79 | Cosmétique chapeau des animaux « Couronne » (visuel uniquement). |
| `SaddleGold` | Selle de monture : Harnais doré | 99 | Cosmétique selle de monture « Harnais doré » (visuel uniquement). |
| `SaddleStars` | Selle de monture : Selle étoilée | 149 | Cosmétique selle de monture « Selle étoilée » (visuel uniquement). |
| `FenceCandy` | Clôture de parcelle : Sucre d'orge | 49 | Cosmétique clôture de parcelle « Sucre d'orge » (visuel uniquement). |
| `FenceHearts` | Clôture de parcelle : Cœurs | 49 | Cosmétique clôture de parcelle « Cœurs » (visuel uniquement). |
| `FenceNeon` | Clôture de parcelle : Néon | 79 | Cosmétique clôture de parcelle « Néon » (visuel uniquement). |
| `FenceGold` | Clôture de parcelle : Grille dorée | 99 | Cosmétique clôture de parcelle « Grille dorée » (visuel uniquement). |
| `FenceDiamonds` | Clôture de parcelle : Diamants | 149 | Cosmétique clôture de parcelle « Diamants » (visuel uniquement). |
| `BuildHearts` | Couleurs des bâtiments : Petits cœurs | 49 | Cosmétique couleurs des bâtiments « Petits cœurs » (visuel uniquement). |
| `BuildClouds` | Couleurs des bâtiments : Ciel de nuages | 75 | Cosmétique couleurs des bâtiments « Ciel de nuages » (visuel uniquement). |
| `BuildUnicorn` | Couleurs des bâtiments : Licornes | 99 | Cosmétique couleurs des bâtiments « Licornes » (visuel uniquement). |
| `BuildDiamonds` | Couleurs des bâtiments : Palais de diamants | 149 | Cosmétique couleurs des bâtiments « Palais de diamants » (visuel uniquement). |
| `BuildGlitter` | Couleurs des bâtiments : Paillettes | 99 | Cosmétique couleurs des bâtiments « Paillettes » (visuel uniquement). |
| `PenHearts` | Clôture d'enclos : Cœurs | 49 | Cosmétique clôture d'enclos « Cœurs » (visuel uniquement). |
| `PenPearls` | Clôture d'enclos : Perles | 79 | Cosmétique clôture d'enclos « Perles » (visuel uniquement). |
| `PenFlames` | Clôture d'enclos : Flammes | 99 | Cosmétique clôture d'enclos « Flammes » (visuel uniquement). |
| `FloorClouds` | Sol de parcelle : Nuages | 99 | Cosmétique sol de parcelle « Nuages » (visuel uniquement). |
| `FloorUnicorn` | Sol de parcelle : Licornes | 149 | Cosmétique sol de parcelle « Licornes » (visuel uniquement). |
| `SignHearts` | Panneau de parcelle : Cœurs | 25 | Cosmétique panneau de parcelle « Cœurs » (visuel uniquement). |
| `SignUnicorn` | Panneau de parcelle : Licorne | 49 | Cosmétique panneau de parcelle « Licorne » (visuel uniquement). |
| `SignDiamonds` | Panneau de parcelle : Diamants | 75 | Cosmétique panneau de parcelle « Diamants » (visuel uniquement). |
| `SaddleUnicorn` | Selle de monture : Selle licorne | 99 | Cosmétique selle de monture « Selle licorne » (visuel uniquement). |

## Checklist des réglages Roblox

1. **Publier le jeu** : Studio > Fichier > Publier sur Roblox (les achats et la sauvegarde n'existent qu'une fois publié).
2. **API Services** : Studio > Accueil > Paramètres du jeu > Sécurité > activer **« Enable Studio Access to API Services »** (pour tester la sauvegarde et le classement dans Studio ; en ligne, les DataStores marchent toujours).
3. **DataStores** (sauvegarde `FarmTycoon_PlayerData_v1` + classement en OrderedDataStore) : rien d'autre à activer, mais ne change pas `Config.Data.StoreName` après la sortie (sinon tout le monde repart de zéro).
4. **Annonces entre serveurs** (MessagingService, créatures Divines et Astrelune) : marchent automatiquement une fois le jeu publié (pas dans un test Studio à un seul serveur).
5. **Chat** : Explorer > TextChatService > ChatVersion = **TextChatService** (les annonces s'affichent dans le canal général).
6. **Achats** : crée les Game Passes et Produits ci-dessus, colle les IDs, republie. Dans Studio, les achats sont simulés (aucun Robux dépensé).
7. **Paramètres du jeu > Autorisations** : jeu **Public**, et genre / appareils (ordinateur, mobile, tablette, console).
8. **Paramètres du jeu > Monétisation** : si tu veux, active les « Paid Access » désactivés (jeu gratuit) et vérifie que les ventes de passes sont autorisées.
9. **Questionnaire Maturity / Experience Guidelines** (Creator Dashboard > ton jeu > Questionnaire) : à remplir, sinon le jeu n'est pas visible pour tout le monde.
10. **Lighting** : Explorer > Lighting > Technology = **Future** (plus joli ; facultatif).
11. **Nombre de joueurs par serveur** : Paramètres du jeu > Places > **6 joueurs max** (il y a 6 parcelles : `Config.Plots.Count`).
12. **Debug** : déjà désactivé (`Config.Debug.Enabled = false`, pas de dalle de pièces de test). `GrantAllPassesInStudio = false`.
13. **Icône et vignettes** : Creator Dashboard > ton jeu > Places > infos de base (icône 512 x 512, vignettes 1920 x 1080).
