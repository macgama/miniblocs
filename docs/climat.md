# Climat et pollution à long terme

Code : `scripts/climat/climat.gd` (nœud « Climat », `Climat.instance`), données `climat_types.gd`,
panneau `climat_panel.gd` (touche **F7**, menu Infos). Test : `tests/climat_test.gd`.
Section de sauvegarde : `climat`. S'appuie sur la pollution de l'air, de l'eau et le bruit de
`docs/nuisances.md`, sur les saisons (`docs/saisons.md`) et sur les époques.

## Ce que le joueur voit (F7)

- **Bilan** : CO₂ par jour et par secteur (électricité, chauffage, transports, industrie, agriculture,
  déchets, moins ce qu'absorbent forêts et parcs), par habitant et par an, comparé à un pays industrialisé
  de l'époque ; total depuis le début ; bilan de chaque année d'histoire.
- **Climat** : réchauffement mondial (°C depuis 1850-1900), décalage de la météo locale et îlot de chaleur
  urbain, scénario suivi, risques ×N, courbe des années, montée de la mer et bâtiments menacés, grandes
  dates (Fourier 1824, Foote 1856, Arrhenius 1896, Keeling 1958, GIEC 1988, Kyoto 1997, Paris 2015…).
- **Énergie** : mix électrique (charbon, gaz, déchets, réseau national, biomasse, nucléaire, hydraulique,
  éolien, solaire), g CO₂/kWh, part bas carbone, intensité du réseau national du pays.
- **Sols** : hectares de sols pollués, points noirs (bouton pour y aller). Carte « Sols pollués » dans N.
- **Mesures** : le plan climat, chaque mesure avec son année d'arrivée, son coût et un bouton.

## Réchauffement

- Avant 2026 : l'histoire réelle (−0,3 °C en 1815 après le Tambora, 0 en 1850, +0,3 en 1940, +1,45 en 2026).
- Après : trois scénarios proches du GIEC (2100 : sobre 1,8 °C, médian 2,7 °C, fossile 4,4 °C ; 2200 : jusqu'à 7 °C).
- Réglage Admin **Réchauffement climatique** : désactivé ; histoire réelle (médian ensuite) ; **le monde suit
  l'exemple de vos villes** (par défaut : avant 2026, la courbe est poussée ×0,6 à ×1,5 selon vos émissions par
  habitant comparées à l'époque ; après, 2 t/hab/an → sobre, 6 → médian, 12 → fossile) ; accéléré (effets ×2).
- Inertie de 5 ans : la température rejoint sa cible peu à peu. Quand l'admin saute des années (époques),
  le climat suit ; en revenant en arrière, il repart de l'histoire.

**Effets** : `Meteo.ecart_climat` = (écart − 1,45) × 1,3 (les terres chauffent plus que la moyenne) + îlot de
chaleur (jusqu'à 2,5 °C dans une ville de 40 000 habitants sans verdure, moitié moins avec « Arbres et toits
végétalisés »). La météo est donc plus fraîche en 1850 et plus chaude en 2100 : canicules (Saisons, 33 °C),
chauffage et climatisation (Réseaux), neige. Un climat plus chaud est plus sec mais ses pluies sont plus
fortes (+7 % par °C). `Saisons.frequence()` est multipliée par `Climat.facteur_extremes()` (+15 % par °C) :
crues, feux de broussailles.

**Mer** : +0,1 cm/an + 0,28 cm/an par °C (≈ +22 cm entre 1900 et 2026). Un bâtiment plus bas que la mer
d'aujourd'hui + la hausse + 1 m de surcote + la marée est menacé ; pendant une tempête, une **submersion
marine** peut inonder jusqu'à 40 bâtiments (dégâts « inondation », réparables), au plus une fois par 20 jours.

## Bilan carbone (chaque heure de jeu)

| Secteur | Comment |
|---|---|
| Électricité | production réelle de chaque centrale (capacité × part de la demande servie) × intensité de sa filière ; réseaux non obligatoires : ce que la ville ne produit pas vient du réseau national (intensité selon l'année et le pays : France 50 g/kWh, Pologne 700…, en 2050 selon le scénario) |
| Chauffage | foyers × 4 kW × besoin de chauffage (température) ; gaz du réseau à 0,2 t/MWh, le reste au bois (1800), charbon (1880-1950), fioul, puis pompes à chaleur |
| Transports | trafic réel (`Traffic.flux_all`, véh/h × longueur des tronçons), poids lourds ×4, 0 avant l'automobile, 350 g/km en 1900, 160 en 2020, 40 en 2050 ; aéroports, ports |
| Industrie | t CO₂ par emploi et par jour (cimenterie 6, aciérie 4, raffinerie 4, chimie 2…) × part du personnel présent |
| Agriculture | élevages (méthane), champs engraissés (protoxyde d'azote) |
| Déchets | décharges (méthane) ; l'incinérateur est compté avec l'électricité ou l'industrie |
| Absorption | forêts autour de la ville (6 t/ha/an) et parcs (3 t/ha/an), relevés tous les 30 jours |

## Sols pollués

Grille de cases de 40 m. Chaque jour, les bâtiments qui polluent l'eau ou l'air (usines, mines, centrales
au charbon, décharges du module Déchets…) déposent sur les cases autour d'eux, les champs traités aux
pesticides aussi (après 1945). Le sol guérit tout seul très lentement (demi-vie ≈ 5 ans), dix fois plus vite
avec « Dépollution des sols ».

Effets : santé des habitants (`Nuisances.sante` ajoute `Climat.risque_sol`, jusqu'à 0,25), récoltes
(`Agriculture.rendement` × `Climat.facteur_champ`, jusqu'à −50 %), valeur des terrains (sources « saleté »
du groupe `pollution_sources`). Réglage Admin « Les sols gardent la pollution ».

## Plan climat (mesures datées)

| Mesure | Année | Effet | Coût |
|---|---|---|---|
| Électrofiltres | 1910 | air des industries −45 % | 1 500 €/site/mois |
| Épuration industrielle | 1960 | eau des industries −60 %, sols ×0,5 | 2 500 €/site |
| Arbres et toits végétalisés | 1970 | îlot de chaleur ÷2, absorption | 0,8 €/hab |
| Isolation des logements | 1974 | chauffage −25 % | 10 €/foyer |
| Désulfuration | 1975 | air industries et centrales −40 % | 4 000 €/site |
| Vélo et transports en commun | 1975 | trafic −15 % (CO₂ et air) | 1,5 €/hab |
| Dépollution des sols | 1980 | sols ×10 plus vite | 3 000 €/ha pollué |
| Taxe carbone | 1991 | industrie −15 %, 45 €/t versés à la ville | recette |
| Normes nitrates et pesticides | 1991 | eau des fermes −50 %, sols −60 %, récoltes −5 % | — |
| Pot catalytique | 1993 | air du trafic −40 % | — |
| Panneaux solaires sur les toits | 2000 | électricité −15 % | 5 €/foyer |
| Zone à faibles émissions | 2015 | air du trafic −30 %, CO₂ −15 %, les foyers râlent | 20 000 €/mois |
| Captage du CO₂ | 2030 | industrie −60 % | 8 000 €/site |

Coûts dans le budget (groupe `budget_entretien`, « Plan climat : … »), taxe carbone dans `budget_recettes`.
Avis des habitants : +1,5 avec 4 mesures ou plus, −1 pour la ZFE, −1 à −2 quand l'été devient étouffant.

## Autres branchements

- Statistiques (Maj+I) : « Émissions de CO₂ », « Réchauffement mondial », « Sols pollués ».
- Nouvelles et gazette : genres `climat` et `submersion`.
- Aide F1 : ligne F7.

## Pistes

Faire monter la mer à l'écran (le plan d'eau suit déjà la marée), fumées des poêles au charbon dans la
pollution de l'air du XIXe siècle, bilan par ville quand il y en a plusieurs, glaciers qui reculent,
nouvelles cultures qui deviennent possibles plus au nord.
