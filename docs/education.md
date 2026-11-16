# Éducation : systèmes scolaires par pays

Code : `scripts/education/` (`systemes_scolaires.gd` les données, `education.gd` le parcours des habitants,
`education_types.gd` les nouveaux bâtiments, `education_panel.gd` le panneau **Maj+K**). Test : `tests/education_test.gd`.

## Trois systèmes

Chaque ville suit le système scolaire de son pays réel (code du pays du lieu). Le panneau Éducation, onglet
**Système**, permet de le changer pour chaque pays de la partie.

| | Suisse (`ch`) | France (`fr`) | Générique (`gen`, autres pays) |
|---|---|---|---|
| Obligatoire | 4-15 ans (HarmoS, dès 2009), 6-15 dès 1874 | 3-16 (2019), 6-16 (1959), 6-14 (1936), 6-13 (1882) | 6-15 dès 1950, 6-12 dès 1900 |
| Degrés | École enfantine 1H-2H, primaire 3H-8H, secondaire I 9H-11H | Maternelle, élémentaire (CP-CM2), collège (6e-3e) | Préscolaire, primaire, secondaire inférieur |
| À 15 ans | Gymnase (maturité, 4 ans), école de culture générale, **apprentissage dual CFC** chez un employeur, école de métiers, AFP | Lycée (bac), lycée professionnel (CAP, bac pro), apprentissage en CFA | Secondaire supérieur, formation professionnelle |
| Supérieur | Université ou EPF (bachelor, master, doctorat ; licence avant Bologne 2001), HES (technicum avant 1997), HEP (école normale avant 2001), diplôme fédéral de médecin | BTS, DUT/BUT, licence, master (DEA/DESS avant 2002), école d'ingénieurs, doctorat en médecine, DE d'infirmier, master MEEF | Licence/bachelor, master, doctorat, diplôme technique, diplôme d'enseignant |

Tout suit l'année de la partie (dès 1800) : part des enfants scolarisés avant l'obligation, part de chaque filière,
noms des diplômes (certificat d'apprentissage cantonal avant le CFC de 1933, maturité fédérale en 1906…),
cursus qui existent, exigences des métiers.

## Un bâtiment par degré

| Bâtiment | Degrés |
|---|---|
| Crèche | école enfantine |
| École (et école de la République, école de village) | enfantine, primaire |
| Maison d'école (1800) | enfantine, primaire, secondaire I (classe unique) |
| Collège | secondaire I |
| Lycée (gymnase en Suisse) | gymnase, culture générale |
| École professionnelle (nouveau, 1880) | apprentis (un jour par semaine), école de métiers |
| Technicum (1874) puis Haute école HES/IUT (1997) | HES |
| École normale (1830) puis HEP (2001) | formation des enseignants |
| Université | université, EPF, doctorat |
| Résidence étudiante (nouveau, 1925) | 80 studios réservés aux étudiants des hautes écoles de la ville |

Sans collège, les élèves du secondaire I vont à l'école primaire en classes à plusieurs degrés (moins de réussite
aux examens). Sans bâtiment pour le secondaire II, l'école professionnelle ou le supérieur, on étudie dans une autre
ville (pas compté « sans école »).

## Apprentissage

Un jeune qui choisit l'apprentissage cherche une entreprise formatrice en ville (boulangerie, atelier, usine,
commerce, ferme, hôpital pour les ASSC, crèche pour les ASE…). Chaque entreprise formatrice offre une place
d'apprentissage pour huit postes (au moins une), en plus de son personnel. Il signe un contrat, occupe un poste, touche un
salaire d'apprenti (25 %) et va le mardi à l'école professionnelle. À la fin : CFC du métier (ou CAP), maturité
professionnelle pour 20 % (dès 1994), et 65 % sont gardés par leur entreprise (s'il y reste un poste). Sans place au bout d'un an : école de
métiers à plein temps. Après 25 ans, un titulaire de CFC peut obtenir un brevet ou une maîtrise fédérale.

## Diplômes exigés par les métiers

Chaque métier a une exigence (niveau, domaine) : médecin (diplôme de médecin), infirmier (bachelor santé),
enseignant (bachelor HEP), professeur (master), professeur d'université (doctorat), ingénieur, policier… Les
métiers **obligatoires** n'embauchent pas sans le diplôme : le poste reste vide et des **frontaliers** (une ville
d'un autre pays à moins de 60 km) ou des **pendulaires** viennent le tenir. Ils ne vivent pas en ville. Dès qu'un
chômeur qualifié habite la ville, un externe lui laisse sa place. Les autres métiers (boulanger, employé de
commerce…) embauchent sans diplôme, mais chaque employé non qualifié fait baisser la production (−40 %).
Une partie des arrivants viennent pour un poste qualifié vacant.

Les postes d'un bâtiment sont répartis par métier selon sa liste (un hôpital : 20 % de médecins, 50 %
d'infirmiers, 30 % d'aides-soignants) : un non-diplômé ne peut plus prendre la place d'un médecin.

## Pilote automatique

Il construit aussi collège (1 200 habitants), lycée (4 000), école professionnelle (5 000), haute école (20 000),
université et résidence étudiante (40 000), quand la caisse le permet (sans bloquer le reste).

## Anciennes sauvegardes

Les anciens diplômes (brevet, bac, BTS, licence, master) restent valables pour tous les domaines. Les enseignants des
collèges, lycées et universités prennent le métier de leur établissement. Les employés gardent leur poste.
