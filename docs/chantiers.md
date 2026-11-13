# Chantiers en temps réel

Demande de Gaël (13 novembre 2026) : tout ce qui se construit prend un temps
réaliste, cohérent avec l'horloge du jeu et la vitesse de la vie des habitants
et des arbres, et on voit les travaux avancer.

## Règles (scripts/chantiers/chantiers.gd)

- Chaque chantier a une quantité de travail en **heures réelles** d'une équipe :
  - bâtiment : `3 + 1,6 × étages^0,9 + √surface / 20` mois (maison ≈ 7 à 9 mois,
    immeuble ≈ 1 an et demi, tour de 20 étages ≈ 2 ans et demi ; places et
    parcs : quelques jours à quelques mois) ;
  - voie : surface × 0,1 h/m² pour une route, 0,14 pour le rail, 0,04 pour un
    chemin, ×6 sur les ponts et en tunnel (100 m de départementale ≈ 80 h).
- Le travail n'avance que pendant les **horaires de l'équipe**, à l'heure locale
  du lieu : jours ouvrés 7 h 30–12 h et 13 h–16 h 30 (par défaut), tous les
  jours, ou jour et nuit (réglage Admin).
- **Rythme** = vitesse de la vie (`Population.life_speed`) : avec 1 an de vie =
  1 mois de jeu (défaut), une maison de 9 mois demande ≈ 3 semaines de jeu.
- **Paiement au fil des travaux** : rien n'est payé à la pose, le prix part de la
  caisse au fur et à mesure. Caisse vide : le chantier s'arrête (le panneau le
  dit) et repart quand il y a de l'argent. Démolir un chantier rend la moitié
  de ce qui a été payé.
- **Construction instantanée** (Admin, F10, section Construction) : pas de
  chantier, tout apparaît d'un coup (bac à sable). Les chantiers en cours se
  terminent aussitôt.

## Bâtiments (BatimentsVie)

Étapes (`Chantiers.ETAPES_BATIMENT`) : terrassement (fouille, tas de déblais,
pelleteuse et camion-benne), fondations (dalle qui monte, camion-toupie), gros
œuvre (étage par étage derrière les échafaudages, grue au-delà de 12 m), toit,
finitions (échafaudages démontés, camionnette). Palissade jusqu'à la fin.
Panneau de chantier au-dessus de l'entrée (de près) : nom, étape, pourcentage,
date de fin prévue.

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

## Tester

- `godot --headless --path . --script res://tests/chantiers_test.gd`
- Vitrine : `godot --path . --script res://tests/chantiers_vitrine.gd -- --screenshot chantiers.png [--vue routes]`
