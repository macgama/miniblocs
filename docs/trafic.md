# Trafic : bouchons, stationnement et transports en commun

Le trafic dépend des vrais trajets des habitants (domicile → travail ou école).
Plus une rue est chargée à l'heure de pointe, plus on y roule lentement ; les
habitants changent alors de route, ou prennent le bus, le tram, le vélo.

Panneau **Trafic** : touche **Maj + L** ou bouton *Trafic* de la barre du bas.

## Ce qui est simulé

| Sujet | Règle |
|---|---|
| Capacité | voies par sens × débit de la classe : rue 500, avenue 800, départementale 1 100, giratoire 1 200, bretelle 1 500, voie express 1 800, autoroute 1 900 véhicules/h par voie |
| Bouchons | formule BPR : temps = temps à vide × (1 + 0,15 × (flux / capacité)⁴), plafonnée à 300 % de charge ; + 3 s par carrefour |
| Heure de pointe | la moitié des automobilistes roulent pendant l'heure de pointe ; la charge suit l'heure (pointes vers 8 h et 17 h 30, nuit très calme) |
| Itinéraires | chaque voiture prend le chemin le plus rapide d'après les bouchons du cycle précédent ; les flux sont lissés (moitié ancien, moitié nouveau) : la ville trouve son équilibre en quelques cycles |
| Voitures visibles | elles ralentissent selon la saturation de leur tronçon à l'heure qu'il est (jusqu'à 15 % de la vitesse) |
| Choix du mode | chacun prend le trajet le moins pénible : minutes + coût (15 €/h, soit 4 min par euro) ; voiture : 0,15 €/km + parking ; ligne : prix du ticket (gratuit avant 18 ans) ; la moitié des gens préfèrent la voiture (×0,6), un tiers aiment le vélo |
| Sans route | un bâtiment à plus de 400 m d'une route n'est pas accessible en voiture |
| Stationnement | places privées des entreprises (0,3 par emploi), puis le long des rues (une place tous les 4,5 m de rue, 5,5 m d'avenue, réparties par quartier de 200 m), puis les parkings construits ; au-delà de 75 % de remplissage on tourne pour chercher, au-delà de 100 % on se gare plus loin et on marche |
| Parkings payants | tarif réglable par parking (€ par jour) ; payé par ceux qui ne trouvent pas de place gratuite ; recettes pour la ville |
| Lignes | capacité = places du véhicule (catalogue) × passages par heure ; pleine à la pointe : attente d'un ou plusieurs véhicules de plus ; les bus subissent les bouchons de leur route |
| Voies de bus et de tram | sur un tronçon choisi : les bus et trams y passent sans bouchon, les voitures perdent une voie (les trams sur leurs rails sont déjà en site propre) |
| Fermetures | « Fermer à la circulation » (ou `Trafic.fermer(eid, raison)`) : les itinéraires l'évitent |
| Argent | tickets (1,50 € par défaut) et stationnement encaissés par le budget communal ; exploitation des lignes payée chaque mois (bus 3 000 €, tram 5 000 €, métro 8 000 €, train 9 000 € par véhicule) |
| Avis | − bouchons (8 min perdues ou plus), − pas de place pour se garer, − bus bondé, + transports en commun pratiques |

## Panneau Trafic

- **Bilan** : part de la voiture, des transports en commun, du vélo et de la marche ; trajet moyen ; minutes perdues dans les bouchons et pour se garer ; recettes du mois.
- **Bouchons** : les tronçons les plus chargés (Voir : la caméra y va). *Choisir une route* puis clic sur une route : capacité, flux, voie de bus, fermeture.
- **Parkings** : tarif de chaque parking, quartiers les plus pleins.
- **Lignes** : remplissage à la pointe, voyageurs par jour, fréquence, prix du ticket.
- **Carte du trafic** : les routes colorées du vert (fluide) au rouge (bouché), maintenant ou à l'heure de pointe ; parkings colorés selon leur remplissage ; voies de bus en bleu, routes fermées en violet. Elle est aussi dans le panneau commun des cartes (touche N) quand il existe.

## Pour les autres systèmes

- `Traffic.flux(eid)`, `Traffic.flux_all()`, `Traffic.flux_lourds(eid)` : véhicules par heure à l'heure actuelle (pollution, bruit).
- `Trafic.edge_flow(eid)` : véhicules par heure de pointe, deux sens (usure des routes).
- `Traffic.speed_factors` : facteurs de vitesse par tronçon (bouchons, état de la chaussée).
- `Trafic.car_trip(depart, arrivee, distance)` : utilisé par `Population.commute`.
- Groupes `budget_recettes`, `budget_entretien`, `avis_sources`.
- Sauvegarde : section `trafic` (tarifs, voies de bus, fermetures, comptes).

## Code

`scripts/transport/trafic.gd` (modèle, calcul par morceaux à chaque image),
`trafic_panel.gd`, `trafic_overlay.gd`. Test : `tests/trafic_test.gd`.
Captures : `tests/trafic_vitrine.gd`.
