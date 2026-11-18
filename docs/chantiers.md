# Chantiers en temps réel

Demande de Gaël (13 novembre 2026) : tout ce qui se construit prend un temps
réaliste, cohérent avec l'horloge du jeu et la vitesse de la vie des habitants
et des arbres, et on voit les travaux avancer.

## Règles (scripts/chantiers/chantiers.gd)

- Chaque chantier a une quantité de travail en **heures réelles** d'une équipe :
  - bâtiment : selon sa **surface de plancher** (emprise bâtie × niveaux, un
    niveau = 3,5 m de hauteur) : `0,42 × plancher^0,46` mois, puis × **type**
    (industrie 0,75, services 1,1, réseaux 1,2 ; hôpital 1,35, centrale 1,4,
    nucléaire 2,5, gare 1,15, hangar 0,6…), × **matériaux** (bois 0,8, pierre
    de taille 1,25) et × **époque** (avant 1850 : 1,6 ; avant 1900 : 1,4 ;
    avant 1945 : 1,2 ; avant 1980 : 1,05 ; ensuite 1). Stades, parcs et zoos
    comptent leur emprise, pas les niveaux. Plafond 10 ans (les grands
    monuments ont leurs propres durées). Repères aujourd'hui : maison ≈ 4 à
    6 mois, immeuble de 8 niveaux ≈ 14 mois, école ≈ 1 an, gare ≈ 1 an et
    quart, hôpital ≈ 3 ans, stade ≈ 2 ans et demi, tour de 40 étages ≈ 4 ans.
    Places et parcs : quelques jours à quelques mois. La durée est fixée au
    lancement du chantier (année de jeu de ce moment-là) ;
  - voie : surface × 0,1 h/m² pour une route, 0,14 pour le rail, 0,04 pour un
    chemin, ×6 sur les ponts et en tunnel (100 m de départementale ≈ 80 h).
- Le travail n'avance que pendant les **horaires de l'équipe**, à l'heure locale
  du lieu : jours ouvrés 7 h 30–12 h et 13 h–16 h 30 (par défaut), tous les
  jours, ou jour et nuit (réglage Admin).
- **Rythme** = vitesse de la vie (`Population.life_speed`) ÷ 3 (au moins ×1)
  × réglage Admin « rythme des chantiers » (×3 par défaut). Avec 1 an de vie =
  1 mois de jeu : ×4 × 3 = ×12. Maison ≈ 2 semaines de jeu, immeuble ≈ 5 à
  6 semaines, hôpital ≈ 4 mois (à ×1 : trois fois plus).
- **Ouvriers** : avec moins d'ouvriers que l'équipe complète, le chantier
  avance d'autant moins vite (Fondateurs).
- **Paiement au fil des travaux** : rien n'est payé à la pose, le prix part de la
  caisse au fur et à mesure. Caisse vide : le chantier s'arrête (pastille rouge
  sur son marqueur) et repart quand il y a de l'argent. Démolir un chantier rend la moitié
  de ce qui a été payé.
- **Construction instantanée** (Admin, F10, section Construction) : pas de
  chantier, tout apparaît d'un coup (bac à sable). Les chantiers en cours se
  terminent aussitôt.

## Bâtiments (BatimentsVie)

Étapes (`Chantiers.ETAPES_BATIMENT`) : terrassement (fouille, tas de déblais,
pelleteuse et camion-benne), fondations (dalle qui monte, camion-toupie), gros
œuvre (étage par étage derrière les échafaudages, grue au-delà de 12 m), toit,
finitions (échafaudages démontés, camionnette). Palissade jusqu'à la fin.
Marqueur de chantier (`scripts/chantiers/marqueurs_chantiers.gd`, à la place de
l'ancien texte flottant) : un cône de chantier entouré d'un anneau jaune qui se
remplit avec l'avancement, et une petite pastille quand le chantier n'avance
pas normalement : lune (équipe au repos), pièce rouge (caisse vide), casque
orange (pas d'ouvriers ou équipe incomplète), ‖ (pause). Taille à peu près
constante à l'écran, effacé au-delà de 650 m, absent des photos (F8).
Survol : carte avec le nom, l'étape, la barre d'avancement, l'état, les
matériaux et la date de fin. Clic : la carte reste ouverte (Échap ou clic
ailleurs pour la fermer). Agrandissements et rénovations ont le même marqueur
(immeuble + flèche, rouleau de peinture) ; leur clic ouvre la fiche du
bâtiment. Option : Options → Jeu → « Marqueurs des chantiers ».
Test : `tests/marqueurs_chantiers_test.gd`.

Ouvriers (figurines en gilet orange, `Figurine.creer(…, "ouvrier")`) : seulement
près de la caméra (240 m) et pendant les heures de travail ; à la pioche dans la
fouille, au béton sur la dalle, sur les échafaudages, sur le toit, puis aux
finitions.

Données du bâtiment (sauvegardées) : `ne` (début), `fin` (fin prévue/réelle),
`av` (avancement 0 à 1), `hr` (heures réelles), `du` (reste à payer).
Les anciennes parties (chantiers datés `ne`/`fin`) reprennent où elles en étaient.

## Voies (ChantiersVoies) et suivi générique (SuiviChantiers)

Les tronçons posés par le joueur (`TransportSystem.edges_built`) portent `ch`
(avancement) et `chr` (heures réelles) dans le réseau : ni itinéraires ni trafic
ni lampadaires avant la fin. Étapes (`Chantiers.ETAPES_VOIE`) : piquets du
tracé, décapage (terre), couche de grave, enrobé derrière le finisseur et le
rouleau, puis marquage. Un tronçon coupé en deux garde son avancement.

`SuiviChantiers` (nœud « Chantiers » de terre_main, `SuiviChantiers.instance`)
fait avancer tout chantier générique :

```gdscript
SuiviChantiers.instance.commencer("reseau:eau:12", heures_reelles,
	func(av: float, etape: Array) -> void: troncon.av = av,
	func() -> void: troncon.en_service = true, av_sauvegarde, cout)
```

Le propriétaire garde l'avancement dans sa donnée et rappelle `commencer` au
chargement. `ChantiersVoies.instance.chantier_reparation(eid, heures, cout, fini)`
ferme un tronçon le temps d'une réparation (cônes, rouleau).

## Matériaux d'époque (MateriauxChantiers)

Chaque chantier consomme de vraies marchandises, au fil des travaux (10 %
d'avancement = 10 % des matériaux), selon l'année de la partie :

| Époque | Bâtiment (par m² de plancher) |
|---|---|
| avant 1850 | pierre, chaux, sable, bois, tuiles |
| 1850-1900 | pierre et briques, chaux, bois, tuiles, un peu de verre et de fer |
| 1900-1950 | briques, ciment, sable, acier, planches, tuiles, verre |
| après 1950 | béton (ciment, sable, granulats), acier, verre, briques, un peu de plastique |

Les chalets et maisons à ossature bois prennent surtout du bois ; les usines
plus d'acier. Les routes prennent des granulats et du sable (et un peu de
ciment après 1920), les voies ferrées du ballast, des rails et des traverses
(bois avant 1950, béton après).

Le chantier se sert d'abord dans les stocks de la carte (carrière, four à
chaux, scierie, briqueterie, tuilerie, cimenterie, entrepôts…), du plus proche
au plus loin dans un rayon de 30 km : l'entreprise est payée sur le prix du
chantier (« Ventes aux chantiers » dans ses comptes). Ce qui manque est
importé, déjà compris dans le prix. Le prix d'un chantier ne change donc pas,
mais une ville qui produit ses matériaux fait travailler ses entreprises.

La carte du marqueur (survol) affiche les principaux matériaux. Code :
`scripts/chantiers/materiaux_chantiers.gd` ; `BatimentsVie.materiaux_de(bid)`
et `SuiviChantiers.materiaux_de(cle)` donnent ce qui a été reçu (local ou
importé).

## Tester

- `godot --headless --path . --script res://tests/chantiers_test.gd`
- Matériaux et agriculture d'époque : `godot --headless --path . --script res://tests/agri_epoques_test.gd`
- Vitrine : `godot --path . --script res://tests/chantiers_vitrine.gd -- --screenshot chantiers.png [--vue routes]`
