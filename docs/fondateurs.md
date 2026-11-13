# Fondateurs du village et ouvriers des chantiers

Code : `scripts/communes/fondateurs.gd` (`Fondateurs`, nœud « Fondateurs » sous la scène Terre) et `fondateurs_panel.gd` (panneau **Maj+H**). Test : `tests/fondateurs_test.gd`.

## L'idée

Au début d'une partie, il n'y a encore aucun habitant. Mais les chantiers ont besoin de bras. Quand on pose la **Maison de commune** du premier village, les **fondateurs** arrivent : **100 par défaut** (réglage Admin). Ils plantent leur **campement** à côté de la Maison de commune. C'est la réserve de travailleurs des premiers chantiers, et il faut bien la doser.

## Les chantiers ont besoin d'ouvriers

- Chaque chantier veut une **équipe complète** : une maison ≈ 8 à 10 ouvriers, la Maison de commune ≈ 10, une usine ≈ 20, une voie ou un réseau 3 à 16 selon la longueur (`Chantiers.equipe_batiment`, `Chantiers.equipe_travaux`).
- Les ouvriers sont les fondateurs restés à la **base de chantier** du campement, puis les employés des **Entreprises du bâtiment** (Construire → Industrie, 20 emplois, 450 000 €).
- Ils vont aux chantiers **dans l'ordre** où ceux-ci ont commencé, chacun jusqu'à son équipe complète. Un chantier à **équipe incomplète** avance moins vite (5 ouvriers sur 10 = deux fois plus lent). Un chantier **sans ouvriers attend**, et rien n'est payé tant qu'il attend.
- Pour doser : dans le panneau **Maj+H**, chaque chantier a **Pause** (ses ouvriers vont aux suivants) et **En premier** (il est servi avant les autres).
- Le panneau du chantier (de près) dit « En attente d'ouvriers », « En pause » ou « 6 ouvriers sur 10 ».

## Les fondateurs prennent n'importe quel métier

Dans **Maj+H → Affecter les fondateurs** : chaque bâtiment fini qui a des postes libres (ferme, boulangerie, école…) est listé. On choisit le métier (ou « au choix du bâtiment »), puis on envoie **+1** ou **+5** fondateurs. Ils quittent alors le chantier. **Rappeler 1** ou **Tous** les ramène à la base de chantier, comme ouvriers du bâtiment.

## Le campement

- Les fondateurs dorment **sous la tente** : ni loyer ni courses, pas de taxe foncière.
- Ils ont des **vivres** pour 90 jours de jeu (réglage Admin). Ensuite, le **ravitaillement** du campement est payé par la caisse : 12 € par personne et par jour. Si la caisse ne peut pas payer, le campement a faim (comme des rayons vides, voir `Repas`).
- Dès qu'une maison est finie, un foyer de fondateurs y **emménage avant tout nouvel arrivant** (le plus près du campement). Le campement se vide à vue d'œil (5 variantes du modèle, de 30 tentes à aucune).
- Tant qu'ils dorment sous la tente, les fondateurs ne comptent pas pour les **paliers** (territoire, déblocage). Logés, ils sont les **premiers habitants**.
- On ne peut pas démolir le campement tant que des fondateurs y dorment. Ensuite, sa base de chantier reste : la démolir renvoie ses ouvriers chercher un autre emploi.

## Réglages Admin (F10 → Construction)

- **Fondateurs du village** : 100 par défaut (0 à 1000). 0 = pas de fondateurs.
- **Vivres de départ** : 90 jours par défaut (0 à 365).
- **Les chantiers ont besoin d'ouvriers** : oui par défaut, non en « Bac à sable libre ». Sans cette règle, tous les chantiers ont toujours leur équipe complète.

Les fondateurs n'arrivent que dans une **partie neuve lancée du globe**. Dans une ancienne partie ou une scène de test, rien ne change : les chantiers gardent leur équipe complète.

## Sauvegarde

Section `fondateurs` : `{version, arrives, camp, membres, foyers_depart, vivres, ravitaillement, affame, alerte, pauses, ordres, jour}`. Les places du campement (`nlog`, `nemp`) et les chantiers en pause ou passés en premier (`pause`, `ordre`) sont gardés avec les bâtiments.

## Pour les autres systèmes

- `Fondateurs.instance`, `Fondateurs.facteur_de(cle)` : part de l'équipe présente (0 à 1). Clés : `"bat:<id>"` pour un bâtiment, sinon celles de `SuiviChantiers` (`"voie:12"`, `"reseau:elec:3"`…). Sans fondateurs arrivés, toujours 1.
- `BatimentsVie` et `SuiviChantiers` multiplient l'avancement par ce facteur.
- `Population.avant_arrivees` (les fondateurs s'installent avant les arrivées), `BuildingSystem.demolish_check(bid)` (raison qui empêche de démolir).
- `Fondateurs.est_campement(bid)`, `Fondateurs.nourris(bid)`.
