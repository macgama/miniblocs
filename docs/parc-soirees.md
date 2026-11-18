# Parc de loisirs : publicité, recherche et soirées

Trois nouveaux onglets dans le panneau du parc (**Maj+G**) : **Publicité**, **Recherche** et **Soirées**.

## Publicité (`scripts/parc/parc_publicite.gd`)

- Une campagne = un **support**, une **cible** et une **durée** (1, 2, 4 ou 8 semaines). Au plus 4 campagnes à la fois par parc.
- Supports datés (époques) : affiches et journal (1800), dépliants dans les gares et hôtels (1850), radio (1922), télévision (1950), panneaux au bord des routes (1960), Internet (1996), réseaux sociaux (2006), influenceurs (2012).
- Cibles : tout le monde, les habitants, les touristes, les familles (manèges doux, dépensent plus aux stands), les amateurs de sensations (grands frissons).
- La campagne fait monter la **notoriété** en ville et dans la région ; elle retombe de 4 % par jour sans pub. À notoriété maximale : +60 % d'habitants, +100 % de touristes.
- Une pub pour un parc mal noté marche moitié moins ; viser les sensations sans attraction à sensations (excitation 6 ou plus) ne sert presque à rien.
- Coût : prix par semaine ÷ 7 chaque jour, caisse de la ville du parc (poste « Parc de loisirs : publicité »).

## Recherche (`scripts/parc/parc_recherche.gd`, `scripts/parc/parc_inventions.gd`)

- Un **bureau d'études** commun à tous les parcs. Budget mensuel : 0, 10 000, 30 000 ou 80 000 € (partagé entre les villes des parcs), plus des points grâce aux visiteurs.
- Un projet en cours et une file d'attente (6 au plus) ; le suivant démarre seul.
- Chaque projet a son année (pas de looping en 1850) et parfois un projet requis.
- **Nouvelles attractions** : palais des glaces (1850), tour panoramique (1970), montagnes russes à looping (1976), rivière rapide en bouées (1980), cinéma dynamique 4D (1993). Les anciennes (grande roue, montagnes russes familiales, chaises volantes, autos tamponneuses, train fantôme, tasses, bateau pirate, bateaux tamponneurs, piscine à vagues, tour de chute) s'inventent aussi.
- **Améliorations** : révisions préventives (usure −25 %), éclairage féerique, feux en couleurs, mascottes (+4 d'humeur), restauration rapide (stands +30 %), lasers et jets d'eau, feux pyromélodiques, billetterie en ligne (+8 % de visiteurs), coupe-file (attente ressentie −20 %), drones lumineux.
- Réglage de partie **« Recherche des attractions »** (Admin F10 → Parc de loisirs) : oui dans les nouvelles parties. Les attractions à inventer restent verrouillées dans Construire (« À inventer · Maj+G »). Non : tout se pose d'office, la recherche garde les améliorations. Les anciennes sauvegardes gardent tout débloqué.
- Signal `ParcLoisirs.recherche_terminee(id)` et `ParcRecherche.est_fait(id)` pour les autres systèmes (arbre de progression).

## Soirées (`scripts/parc/parc_soirees.gd`, `scripts/parc/parc_soirees_visuels.gd`)

- Spectacles : feu d'artifice (de tout temps ; dorés avant 1830, en couleurs avec la recherche, bleu et violet dès 1880), parade lumineuse (1900), lasers et jets d'eau (1980), feu pyromélodique (1990), drones (2016).
- Taille petit / moyen / grand (prix, durée, effet) ; quand : jamais, les samedis, les jours de fête (14 juillet, 1er août, 31 décembre), chaque soir d'été, chaque soir. Bouton « Un spectacle ce soir ».
- À la nuit tombée (22 h 30 en juin-juillet, 19 h l'hiver) ; le parc ferme après le spectacle. Plus de visiteurs ce jour-là (surtout en fin d'après-midi), ils restent jusqu'au bout et repartent de bien meilleure humeur.
- Sous la pluie : annulé (20 % du prix payé), sauf les lasers. Bruit pendant les feux (pollution sonore).
- Les fusées bougent à la vitesse visible (EchelleTemps) : ralentir le temps (T, Maj+T) pour profiter du spectacle.

## Tests

- `godot --headless --path . --script res://tests/parc_soirees_test.gd`
- Captures : `godot --path . --script res://tests/parc_soirees_vitrine.gd -- --dossier captures/parc-soirees`
