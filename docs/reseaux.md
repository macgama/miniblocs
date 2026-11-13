# Réseaux : électricité, eau potable, égouts, gaz et chauffage

Touche **O** : panneau Réseaux (onglets Courant, Eau, Égouts, Chauffage, Comptes). Code dans `scripts/reseaux/`, tests `tests/reseaux_test.gd` et `tests/reseaux_crises_test.gd`.

## Principe (inspiré des city builders, sans copier)

- **Les routes portent la desserte locale** : basse tension, petites conduites
  et égouts de rue. Un bâtiment à moins de 30 m d'une route (en plus de sa
  demi-taille) est raccordé au réseau de cette route.
- **Le joueur pose les gros tronçons** (panneau O) : ligne haute tension
  (pylônes de 28 m tous les 300 m), ligne moyenne tension (poteaux de 10 m tous
  les 60 m), conduite d'eau potable, collecteur d'égout. Clic pour chaque point,
  clic droit ou Échap pour finir. Chaque tronçon a son chantier (piquetage,
  fondations, levage, câbles ; ou tranchée, pose, remblai) avant d'être en service.
- Deux tracés se touchent si l'extrémité de l'un est à moins de 4 m de l'autre.
- Dans chaque réseau relié (composante), la production est partagée entre
  tous : taux = production / demande, au plus 100 %.

## Production (Construire > Réseaux)

| Bâtiment | Capacité | Particularité |
|---|---|---|
| Centrale au charbon | 20 MW | 190 t de charbon par jour livrées par camion |
| Centrale au gaz | 60 MW | 260 t de gaz par jour |
| Centrale biomasse | 8 MW | 210 t de bois par jour |
| Centrale nucléaire | 900 MW | eau à moins de 250 m |
| Centrale hydraulique | 10 MW | rivière à moins de 40 m |
| Éolienne | 3 MW | selon le vent (rien sous 15 %) |
| Parc solaire | 5 MW | selon le soleil et les nuages, rien la nuit |
| Raccordement national | 50 MW | à moins de 300 m du bord de la carte, 0,25 € le kWh payé par la ville |
| Captage et usine d'eau potable | 6 000 m³/j | rivière ou lac à moins de 80 m, consomme 0,12 MW |
| Forage | 1 500 m³/j | nappe (30 % dans le désert), consomme 0,04 MW |
| Château d'eau (Services publics) | réserve 1 500 m³ | se remplit quand il y a du surplus, donne l'eau pendant une coupure |
| Station d'épuration | 3 000 m³/j | consomme 0,15 MW |
| Lagunage | 400 m³/j | sans électricité |
| Rejet d'égout sans traitement | illimité | pollue l'eau en aval |

Les centrales au combustible sont des sites de Production (transformation sans
produit) : les camions leur livrent le combustible, et la ville couvre chaque
jour leurs pertes (combustible, salaires). Les autres centrales tournent à
30 % sans personnel, à 100 % avec tous leurs emplois.

Les usines d'eau et les stations ont besoin de courant : sans électricité,
plus d'eau.

## Gaz et chauffage

| Bâtiment | Chaleur | Particularité |
|---|---|---|
| Poste de livraison de gaz | 30 MW | gaz acheté 0,05 € le kWh par la ville |
| Chaufferie bois (chauffage urbain) | 10 MW | 70 t de bois par jour livrées par camion |
| Centrale de géothermie | 6 MW | sans combustible, consomme 0,3 MW |

Tronçon : conduite de gaz ou de chaleur (180 € le mètre). Les routes portent
aussi les conduites de rue.

- Besoin de chauffage : (18 − T) / 22, entre 0 et 120 %, plus 8 % d'eau chaude.
  Grand froid : 4 kW par logement, 0,8 kW par emploi (2 dans l'industrie).
- Sans gaz, la chaleur qui manque est demandée au réseau électrique (× 0,8 :
  radiateurs et pompes à chaleur) : la pointe d'hiver grimpe.
- Quand il fait froid : sans gaz et avec du courant rationné, logement mal
  chauffé (−4 de satisfaction) ; sans gaz ni courant, on a froid (la plainte
  « pas d'électricité » devient « ni chauffage ») et le risque pour la santé monte.
- Facture : 0,10 € le kWh de gaz ou de chaleur.

## Usure, pannes et crises (`ReseauxIncidents`)

- **Usure** : chaque tronçon perd son état sur sa durée de vie (HT 60 ans,
  MT 40, conduite d'eau 50, collecteur 70, gaz 50), au rythme du réglage Admin
  « usure ». Les pannes : 0,004 par km et par jour pour un tronçon neuf, jusqu'à
  4 fois plus quand il est usé. « Rénover » le remet à neuf (35 % du prix neuf × l'usure).
- **Pannes** : un tronçon cassé est hors service (`hs`) jusqu'à la réparation
  (4 h + 6 h par km, ×1,5 après une tempête), payée par la ville (4 % du prix,
  2 000 € au moins ; « Vite » : le double, tout de suite). Dans les rues : fuites
  d'eau (−15 % de la production du réseau, 4 à 12 h) et transformateurs grillés
  (bâtiments à moins de 60 m dans le noir, 2 à 6 h). Repères : camionnette et
  cônes, flaque pour une fuite ; câbles tombés au sol sur une ligne cassée.
- **Orages** : les arbres tombent sur les lignes aériennes (selon la force de l'orage).
- **Pour les tempêtes et crues des événements** : `Reseaux.instance.endommager(pos, rayon, cause)`
  (cause « crue » : conduites comprises).
- **Canicule** (30 °C et plus) : courant ×(1 + 4 % par degré au-dessus de 27,
  40 % au plus), eau ×(1 + 2,5 % par degré au-dessus de 25, 30 % au plus).
- **Sécheresse** : après 12 jours secs (plus de 15 °C, pas de pluie), le niveau
  monte en 30 jours : captages et barrages jusqu'à −60 %, forages −35 %, centrales
  refroidies par une rivière −40 %. Un jour de pluie retire 4 jours secs.
- **Restrictions d'eau** (onglet Eau) : −20 % de consommation, −3 de satisfaction.

## Demande

Par bâtiment (moyennes, `Reseaux.demande_type`) : 0,6 kW et 0,33 m³/j par
logement ; 3 kW et 0,5 m³/j par emploi d'industrie ; 0,9 kW par emploi de
commerce… Les eaux usées valent 90 % de l'eau. Le courant suit la journée
(pointes à 8 h et 19 h 30), l'hiver (+8 % d'éclairage, plus le chauffage
électrique), et la canicule.

## Conséquences

- **Courant < 50 %** : fenêtres noires (méta `res_panne`), entreprises au ralenti
  (`rendement`, groupe `rendement_sources` lu par Production) : il reste 10 % à
  l'usine, 30 % dans les commerces et services, 80 % aux champs et au grand air,
  −15 de satisfaction (−6 si rationné).
- **Eau < 50 %** : −15 de satisfaction, hygiène (santé), pompiers 3 fois plus lents
  (groupe `eau_incendie`, lu par les incendies).
- **Égouts < 50 %** : −10 de satisfaction, santé.
- **Eau polluée** : un captage en aval (plus bas) d'un rejet sans traitement à
  moins de 2 km, ou un forage à moins de 300 m d'un rejet, donne une eau non
  potable : −8 de satisfaction et risque pour la santé (groupe `sante_sources`,
  ajouté à la pollution dans CycleVie).
- **7 jours sans courant ou sans eau** : les foyers quittent la ville.

## Argent

- Factures payées chaque jour par les foyers (épargne) et les entreprises
  (caisse du site) : 0,20 € le kWh, 2,10 € le m³ d'eau, 2,00 € le m³
  d'assainissement, × le réglage Admin « Factures d'eau et d'électricité ».
- Entretien : 3 % par an du prix des bâtiments des réseaux, plus un prix par
  mètre et par an pour chaque tronçon. Déclaré au Budget communal (groupe
  `budget_entretien`) ; payé par les réseaux eux-mêmes si le Budget n'existe pas.

## Admin (F10)

- **Réseaux obligatoires** (oui par défaut, non en bac à sable libre) : sinon
  tout est desservi d'office.
- **Factures d'eau et d'électricité** : ×0 à ×3.

## Pour les autres systèmes

- `ReseauBase` (`scripts/reseaux/reseau_base.gd`) : mécanique générique
  (tronçons, sources, consommateurs, raccordement, partage) réutilisable (fibre…).
- `Reseaux.instance` : `taux(bid, "elec"|"eau"|"egout")`, `raccorde_egout(bid)`,
  `qualite_de(bid)`, `bilan(res)`.
- Sources électriques d'un autre système : nœud du groupe
  `electricite_sources` avec `electricite_sources() -> [{bid, mw, nom}]`.
- Onglet dans le panneau O : `Reseaux.instance.panneau.ajouter_onglet(titre, control)`.
- Calques : inscrits dans le panneau commun Calques (`reseau_elec`, `reseau_eau`,
  `reseau_egout`, `reseau_gaz`) s'il existe ; les onglets du panneau O les allument aussi.
- Rejets d'eaux usées déclarés au module Nuisances (type « eau ») s'il existe.

## Sauvegarde

Section `reseaux` : tronçons des 4 réseaux (tracé, type, en service, avancement du chantier,
prix payé, état d'usure, panne), réserves des châteaux d'eau, jours de coupure, comptes du mois, pannes en cours,
jours sans pluie, restrictions.
Sources et consommateurs sont reconstruits depuis les bâtiments.
