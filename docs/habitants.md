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

## Circulation

`Population.traffic_demand()` plafonne la circulation d'ambiance (`Traffic.demand`) : sur un échantillon de 300 habitants, on compte ceux dont un trajet tombe à moins de 20 minutes de l'heure actuelle (selon leur mode : voiture, vélo, à pied ou transports publics, qui commencent à pied) et ceux qui sont aux courses ou à un loisir. S'y ajoutent les livraisons (un utilitaire pour 40 emplois occupés, de 7 h à 19 h), et un train ou un bateau d'ambiance pour 300 ou 400 emplois. Sans habitant, la demande est nulle : pas de voiture, de vélo ni de piéton. Les bus d'ambiance sont retirés, seuls roulent ceux des lignes.

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

## Cycle de vie (`scripts/habitants/cycle_vie.gd`)

Par défaut, **1 an de vie = 1 mois de jeu** (`Population.DEFAULT_LIFE_SPEED`, réglage de partie `vitesse_vie`) : à 100 min/s, une année de partie dure 2 h et fait vieillir tout le monde de 12 ans ; une vie de 80 ans dure environ 13 h de jeu. Chaque jour de jeu, `CycleVie.daily()` fait passer les années écoulées (1/30 d'an par jour).

**CV.** Chaque habitant a une liste d'étapes `cv` : `[jour de vie, code, texte, référence]`. Le texte est écrit au moment de l'étape (le nom d'un bâtiment reste même s'il est démoli). Codes : `naissance`, `arrivee`, `ecole`, `diplome`, `etudes`, `emploi`, `fin_emploi`, `retraite`, `demenage`, `couple`, `pacs`, `mariage`, `separation`, `enfant`, `veuvage`, `deuil`, `heritage`, `loisir`, `sport`, `permis`, `voiture`, `maladie`, `guerison`, `deces`, `depart`. Les nouveaux arrivants ont un passé inventé (naissance « loin d'ici », diplômes, permis, union), daté avant leur arrivée.

**Famille.** `pa` = [mère, père], `cj` = conjoint, `un` = `couple`, `pacs` ou `mariage`. `CycleVie.relation()` donne le lien (mère, demi-frère, beau-père, petite-fille…). Les foyers d'une ancienne sauvegarde sont reliés au chargement (couple et parents devinés).

| Chaque année de vie | Probabilité (par an) |
| --- | --- |
| Rencontre (célibataires de 20 à 77 ans) | 30 % ; au travail, au même loisir, dans le quartier (moins de 400 m) ou par des amis ; écart d'âge 10 ans au plus |
| Emménager ensemble | aussitôt : le plus petit foyer rejoint l'autre avec ses enfants mineurs (famille recomposée) ; deux jeunes qui vivent chez leurs parents prennent un logement libre |
| Mariage ou PACS | 12 % pour un couple qui vit ensemble (60 % mariage) |
| Séparation | 1,2 % mariés, 3 % sinon ; l'un part dans un logement libre avec 40 % de l'épargne, les enfants restent |
| Naissance | 11 % pour une femme de 20 à 42 ans en couple sous le même toit (2 petits de moins de 6 ans au plus) |
| Quitter ses parents | 30 % de 19 à 31 ans (pas pendant les études) |
| Brevet / bac | à 15 ans (87 %) et 18 ans (85 %), seulement si l'enfant avait une place au collège puis au lycée |
| Études supérieures | 60 % des bacheliers : BTS 2 ans, licence 3 ans, master 5 ans, à l'université hors de la ville (étape « Étudiant », bourse de 500 € par mois) |
| Travail | 6,5 % changent de travail, 1,5 % perdent leur emploi ; les diplômés (licence, master) prennent le métier le mieux payé de deux tirages, les non-diplômés le moins bien payé |
| Permis | 35 % par an (70 % si le foyer a une voiture) ; un foyer sans voiture qui a 12 000 € d'épargne en achète une (25 %) |
| Loisirs | 10 % : un nouveau loisir ; un loisir trop jeune pour l'âge est abandonné |
| Distinctions sportives | 7 % par sport pratiqué dans un club de la ville (tournoi, médaille régionale, champion départemental, équipe nationale) |

**Santé et mort.** Risque de décès de base `0,00002 × e^(0,1 × âge)` (+ 0,35 % la première année, + 0,03 % avant 40 ans), soit environ 83 ans d'espérance de vie. La ville le change :

| | Effet sur le risque |
| --- | --- |
| Hôpital à moins de 6 km | × 0,82 (sinon × 1,15) ; il double aussi les chances de guérir |
| Pollution (usines et industries à moins de 800 m) | × (1 + 0,4 × pollution) ; elle donne aussi de l'asthme |
| Satisfaction | × (1,3 − 0,006 × satisfaction) : de × 1,3 (0/100) à × 0,7 (100/100) |
| Maladie | hypertension × 1,25, diabète × 1,35, maladie du cœur × 1,8, cancer × 2,4, asthme × 1,15 |

La fiche montre l'espérance de vie estimée et ce qui la fait varier.

**Héritage.** L'épargne est celle du foyer : le conjoint la garde avec le logement. Sans adulte, les enfants majeurs héritent du logement familial et deviennent les adultes du foyer. Une personne seule lègue son épargne à ses enfants qui vivent en ville. Des mineurs sans adulte partent chez leur autre parent, leurs grands-parents ou un frère ou une sœur majeur ; sinon dans une famille d'accueil hors de la ville.

**Défunts.** Les défunts et les habitants partis gardent leur fiche dans `CycleVie.archive` (4 000 au plus) : CV, famille, cause du décès, dernier logement. Liste « Défunts et partis » dans le panneau. Un cimetière viendra plus tard dans le catalogue.

**Nouvelles.** Chaque jour, un message résume les naissances, décès, couples, mariages, PACS, séparations, diplômes et médailles. Les étapes de l'habitant suivi s'affichent une par une.

**Suivre un habitant.** Bouton « ☆ Suivre » de la fiche : un repère jaune tourne au-dessus de lui avec son nom et ce qu'il fait, une carte en haut à gauche le résume, la caméra l'accompagne (sur un trajet, elle glisse d'un lieu à l'autre). Touche **F** : caméra qui le suit ou libre ; déplacer la caméra la libère. À sa mort, le suivi passe à l'aîné de ses enfants en ville, sinon à son conjoint.

**Sauvegarde.** Section `habitants` version 2 : chaque habitant a un 12e champ (dictionnaire `CycleVie.pack`) et la section a une clé `vie` (archive, habitant suivi, totaux). Les sauvegardes version 1 se chargent toujours.

Test : `tests/cycle_vie_test.gd` (80 ans simulés). Captures : `tests/cycle_vie_vitrine.gd`.

## Voir vivre les habitants (`scripts/habitants/passants.gd`)

Vitesses du temps : **1 min/s** (une journée en 24 minutes), **10 min/s**, **100 min/s** (100 jours en 24 minutes, une année de partie en 2 h). La journée de chaque habitant suit l'horloge ; son âge suit la vitesse de la vie (1 an = 1 mois par défaut).

Les habitants qui vivent, travaillent ou étudient près de la caméra (rayon de 150 à 700 m selon le zoom, 300 au plus), plus l'habitant suivi, sont dessinés pendant leurs trajets : ils sortent par la façade qui donne sur la voie, suivent le plus court chemin sur les routes (`TransportNetwork.find_route`), sur le trottoir à pied, sur la voie de droite en voiture ou à vélo, puis entrent dans le bâtiment d'arrivée. Leur position suit l'heure : un trajet de 10 minutes dure 10 secondes à 1 min/s. Clic sur un passant : sa fiche. Les habitants dessinés remplacent autant de figurants de la circulation d'ambiance.

## Ordres (`scripts/habitants/ordres.gd`)

Fiche d'un habitant, section « Donner un ordre ». Tout le monde peut commander tout le monde, sauf le personnage principal d'un autre joueur.

- **Sa journée** : aller à… (clic sur un bâtiment, Échap pour annuler), rentrer, aller au travail ou à l'école, faire un loisir ou du sport (liste des lieux), faire les courses, rendre visite à… (famille, collègues), aller dormir. L'habitant part tout de suite, reste sur place (2 h, 1 h pour les courses), rentre, puis reprend sa journée le lendemain (`p.ord`, appliqué par `Population.day_plan`).
- **Ses choix de vie** : chercher un emploi, démissionner, déménager (tout le foyer), chercher l'âme sœur, demander en mariage, avoir un enfant, se séparer, prendre sa retraite (dès 60 ans). Notés dans le CV.
- Un bouton grisé explique pourquoi l'ordre est impossible (bébé, pas de logement libre…). Pour ajouter un ordre : une entrée dans `Ordres.LISTE`, un cas dans `check()` et `give()`.

## Ton personnage principal (`scripts/habitants/personnage_principal.gd`)

Il naît dans la première famille de la ville qui le peut (un couple sous le même toit, avec une femme de 18 à 45 ans), et il est suivi d'office (`p.joueur` = identifiant du joueur). Le hasard ne décide plus pour lui ni pour son couple : une carte en haut de l'écran pose les questions (rencontre, mariage ou PACS, enfant, études après le bac, offre d'emploi, retraite anticipée) et met le temps en pause jusqu'à la réponse. À sa mort : continuer avec un enfant ou le conjoint, ou faire naître un nouveau personnage. Bouton « Prendre sa place » de la fiche : on l'incarne en vue au sol (n'importe quel habitant aussi), V pour revenir.

Tests : `tests/journee_test.gd`. Captures : `tests/journee_vitrine.gd`.

## Pistes

- Faire marcher les habitants dans la rue (piétons) et monter dans les bus d'après leur journée.
- Demande de logements, d'emplois et de commerces selon la population (le zonage pourrait la suivre).
- Université dans le catalogue (les études se font aujourd'hui hors de la ville), crèches, collèges et lycées séparés.
- Cimetière dans le catalogue, avec les tombes des défunts.
- Prendre le bus et le tram avec les habitants dessinés (aujourd'hui, ils y vont à pied).
- Habitants dessinés pendant les loisirs en plein air (parcs, terrains de sport).
- Commerces qui vivent des achats des habitants, impôts réglables, satisfaction qui attire ou fait partir.
