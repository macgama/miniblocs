# Saisons et risques naturels

**Maj+R** (ou menu Infos → Saisons et risques) : panneau Saisons et risques.
Construire → **Services publics** : centre technique municipal, bassin de
rétention, station météo. Code : `scripts/saisons/` (`Saisons`,
`SaisonsPanel`, `SaisonsTypes`), test `tests/saisons_test.gd`, vitrine
`tests/saisons_vitrine.gd`.

Tout part de la météo existante (`Meteo` : temps reproductible selon le lieu
et la date, neige sous 1 °C) et des systèmes déjà là : événements et
urgences, réseaux (la sécheresse et la canicule de `ReseauxIncidents`),
agriculture, circulation.

## Saisons et météo (onglet Météo)

- Printemps, été, automne, hiver selon la vraie date et l'hémisphère (été en
  janvier à Rio). Sous climat tropical : saison des pluies et saison sèche.
- Chaque jour est noté : pluie (mm), neige (cm), températures mini et maxi.
  Courbe des 30 derniers jours, records de la partie, et un bilan à chaque
  changement de saison dans le fil d'actualité.
- **Prévisions** sur 3 jours, 7 avec une **station météo** (250 000 €). Comme
  le temps du jeu est calculé d'avance, elles disent vrai.

## Neige et déneigement (onglet Déneigement)

- La neige tient sur les routes (cm par tronçon, visible en blanc) et fond au
  redoux. Sur la neige, tout le monde roule moins vite : −8 % par cm, jusqu'à
  −70 % (les secours aussi). Les voitures glissent : accidents de temps en
  temps (police et ambulance). Les habitants dont la rue n'est pas déneigée
  râlent ; ceux dont la rue est salée sont contents.
- **Centre technique municipal** (1,4 M€) : 2 chasse-neige saleuses et un dôme
  de 150 t de sel. Dès que la neige tient (1,5 cm), les engins partent, les
  grands axes d'abord, à 30 km/h dans un rayon de 7 km. Ils roulent vraiment
  sur les routes. Derrière eux, la route est salée : la neige ne tient plus
  pendant 12 h (jusqu'à −8 °C). 0,12 t de sel par km.
- Le sel se rachète tout seul (110 € la tonne) quand le dôme est à moitié
  vide. Entretien : 2 200 € par engin et par mois, plus le bâtiment.
- Sans centre technique, la neige reste jusqu'au redoux (« Jour de neige : la
  ville est paralysée »).
- Admin (F10) → Événements : **Neige sur les routes** oui / non.

## Crues (onglet Risques)

- Vigilance crues d'après la pluie des 3 derniers jours, plus la fonte rapide
  des neiges : verte, jaune (40 mm), orange (70 mm), rouge (100 mm).
- En orange (une chance sur trois chaque jour) ou en rouge, la rivière la plus
  proche sort de son lit : l'eau monte pendant 8 à 24 heures (0,6 à 1 m en
  orange, 1,2 à 2 m en rouge), coupe les routes, abîme les bâtiments bas
  (dégâts à réparer, panneau Infos), appelle les pompiers, puis redescend en
  6 heures. Les champs au bord de l'eau perdent 60 % de leur récolte.
- **Bassin de rétention** (2,2 M€) : l'eau monte 25 % moins haut à moins de
  3 km, jusqu'à −75 % avec trois bassins.
- Les crues des tempêtes (panneau Infos) passent par le même code.

## Sécheresse

Niveaux des arrêtés français, d'après les jours sans vraie pluie (les mêmes
que les réseaux : rivières, nappes et barrages qui baissent) :

| Niveau | Quand | Effets |
| --- | --- | --- |
| Vigilance | 8 jours secs | nouvelle |
| Alerte | 13 jours | restrictions d'eau imposées par la préfecture (−20 %), cultures qui souffrent, prés à −20 % |
| Alerte renforcée | ~25 jours | prés à −40 %, feux de broussailles au bord des bois par les journées chaudes |
| Crise | ~35 jours | prés à −60 %, habitants très mécontents |

Les restrictions se lèvent quand la pluie revient (sauf si tu les avais
imposées toi-même, panneau O ou bouton du panneau Saisons).

## Canicule et gel

- **Canicule** : 3 jours de suite à 33 °C ou plus. Nouvelle, habitants
  mécontents (en plus de la climatisation et de l'eau des réseaux).
- **Gelée tardive** : au printemps (mars à mai dans l'hémisphère nord), une
  nuit à −1,5 °C abîme les jeunes pousses (−15 % de récolte).
- La grêle des orages existait déjà (−10 à −35 %).

## Récoltes selon la saison (onglet Cultures)

Calendrier de chaque culture qui pousse ici : mois de semis (vert) et de
récolte (jaune), dans l'hémisphère du lieu. Les champs le suivent tout seuls
(panneau Agriculture, Maj+F) ; la météo s'en mêle (gel, grêle, sécheresse,
crue, pluie qui empêche les travaux).

## Provoquer (bac à sable)

Onglet Risques, ou panneau Infos (I) → Organiser : chute de neige (5 cm, puis
3 h de neige et 36 h de froid), crue rouge, sécheresse, canicule, feu de
broussailles. Au hasard, ils arrivent avec le réglage Admin « Catastrophes ».

## Pour les autres systèmes

- `Saisons.instance` : `neige_de(eid)`, `etat_routes()`, `niveau_secheresse`,
  `canicule`, `vigilance_crue`, `previsions(n)`, `calendrier()`.
- Groupes : `avis_sources` (thèmes transports, réseaux, environnement),
  `budget_entretien`.
- `Evenements.modules[type]` : un module d'un autre fil peut prendre en
  charge un type d'événement (`on_start(e)`, `on_end(e)`) ; « crue » l'utilise.
- `Agriculture.herbe_facteur` : herbe des prés (1 normale).
- Sauvegarde : section `saisons`.
