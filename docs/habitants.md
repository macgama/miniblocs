# Habitants

Code : `scripts/habitants/`. Section de sauvegarde : `"habitants"` (voir `Population.to_dict()`).

## Données

- **Habitant** : id, foyer, prénom, nom, sexe, jour de naissance (sur l'horloge de la vie), rôle dans le foyer (adulte ou enfant), emploi (bâtiment + métier), école (bâtiment), loisirs.
- **Foyer** : id, logement (bâtiment), région des noms, épargne, nombre de voitures, membres.
- Un logement du catalogue (`"logements"`) = un foyer. Un emploi (`"emplois"`) = un poste. Les écoles (type `ecole` ou archétype `ecole` de la bible) ont `"visiteurs"` places (250 par défaut).
- Les index `by_home`, `by_job`, `by_school` (bâtiment → foyers / employés / élèves) sont recalculés au chargement. C'est la même liste qui sert au profil d'un enfant et à la fiche de son école : les deux sont toujours d'accord.

## Temps

- L'emploi du temps suit l'heure locale du cycle jour/nuit (`DayNight`), donc la pause (T) et la vitesse (Maj + T).
- L'âge suit une horloge à part (`life_clock`), qui avance avec le temps du jeu multiplié par la vitesse de la vie (réaliste ×1, rapide ×12, très rapide ×365).
- Toutes les 5 minutes de jeu : arrivées dans les logements libres, attribution des écoles et des emplois au plus proche, départs à la retraite.
- Chaque jour de jeu : paie (foyers et ville), voyageurs des lignes, naissances, décès, jeunes qui quittent leurs parents, foyers endettés qui partent.

## Journée

`Population.day_plan(habitant)` renvoie la journée en étapes `[début, fin, genre, bâtiment, texte]` ; `activity()` donne l'étape en cours. Genres : `dort`, `maison`, `trajet`, `ecole`, `travail`, `courses`, `loisir`, `garde` (bébé chez l'assistante maternelle). École : lundi, mardi, jeudi, vendredi 8 h 30 – 16 h 30, mercredi matin, vacances en juillet-août. Congés : trois semaines en août pour la moitié des actifs.

Ce découpage est prêt pour faire marcher de vrais piétons : chaque étape de trajet a un départ, une arrivée et un mode (à pied, vélo, voiture, ligne de transport public avec l'itinéraire de `TransitPlanner`).

## Économie (euros par mois)

| Foyer | |
| --- | --- |
| Revenus | salaire net du métier, pension 1 450, allocation chômage 1 050 |
| Dépenses | loyer (maison 1 050, appartement 720), courses 260 par personne, 160 par voiture |

| Ville | |
| --- | --- |
| Recettes | taxe foncière 95 par foyer, impôts des entreprises 60 par emploi privé occupé, dotation de l'État 15 par habitant |
| Dépenses | salaires des agents de la ville × 1,45 (ATSEM, agents municipaux, pompiers ; enseignants, police nationale et hôpital sont payés par l'État), entretien des bâtiments publics 0,08 % de leur prix |

Le solde est versé chaque jour (1/30,44 du mois) dans la caisse, sauf avec « argent illimité ».

## Pistes

- Faire marcher les habitants dans la rue (piétons) et monter dans les bus d'après leur journée.
- Demande de logements, d'emplois et de commerces selon la population (le zonage pourrait la suivre).
- Couples qui se forment, déménagements, études supérieures, crèches, collèges et lycées séparés.
- Commerces qui vivent des achats des habitants, impôts réglables, satisfaction qui attire ou fait partir.
