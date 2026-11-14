# Partie à plusieurs villes et pays

Test d'une partie solo avec des petites et des grandes villes dans trois pays, reliées
par la route pour commercer, sur plusieurs semaines de jeu. But : vérifier que le jeu
tient avec beaucoup de villes et d'habitants, et que l'économie tourne.

## Lancer le banc

```bash
godot --headless --path . --script res://tests/partie_pays.gd -- --jours 40 --echelle 0.5 --reel 600 --rapport bilan.csv
```

- `--jours` : jours de jeu simulés (120 par défaut).
- `--echelle` : taille des villes (1 = Bâle 4 000 hab., Saint-Louis 2 500, Lörrach 1 500,
  Liestal 800 ; 0,5 = la moitié).
- `--reel` : nombre d'images mesurées à la fin en temps réel (1 jour par minute), 0 pour sauter.
- `--rapport` : une ligne CSV par jour (habitants, caisses, chômage, satisfaction, commerce…).

La carte : autour de Bâle, la France à l'ouest, la Suisse au milieu, l'Allemagne à l'est.
Quatre villes déjà habitées (grilles de rues, zones, services, réseaux, entreprises) et
quatre villages qui partent de zéro (Sierentz, Hagenthal, Aesch, Efringen), tous sous
pilote automatique. Des départementales relient chaque ville à Bâle et sortent vers les
bords de la carte (import et export). Les chaînes de production sont réparties pour
obliger les villes à commercer : fermes en France, usines à Bâle et à Lörrach, bois à
Liestal, sucre à Efringen.

Pendant le banc, chaque image fait avancer le jeu de 10 minutes, ce qui est environ
25 fois plus dense que le vrai jeu. La fin du banc mesure donc les vraies images en
temps réel, puis sauvegarde et recharge la partie. Le bilan détaille aussi chaque
entreprise (effectif, stocks, ce qui lui manque) et la satisfaction de chaque ville par thème.

## Résultats (40 jours, échelle 0,5)

| | Début | Après 40 jours |
|---|---|---|
| Habitants | 4 600 | 13 300 |
| Commerce entre villes | 1 600 € par mois | 88 500 € par mois |
| dont entre pays | 1 500 € par mois | 60 100 € par mois (3 000 € de douane) |
| Satisfaction des villes | | 45 à 62 (villes), 31 à 44 (villages) |
| Chômage | 0 % | 0 % |
| Mémoire | 1,1 Go | 1,3 Go |

Avant les correctifs ci-dessous, la même partie finissait à 5 à 17 de satisfaction,
avec des usines presque vides (1 ouvrier sur 60 ou 120).

## Ce qui a été corrigé

**Lenteurs à plusieurs villes** (même résultat, en moins de temps) :
- sondages d'avis : les habitants sont rangés par ville une fois, au lieu de parcourir
  toute la population pour chaque ville et pour chaque motif ;
- couverture des services : lieux, charges et accroches gardés en cache, trajets
  impossibles écartés à vol d'oiseau, accès des élèves à leur école gardé en cache ;
- habitants : la liste des lieux ouverts (commerces, loisirs) n'est plus reconstruite
  pour chaque logement, ni effacée à chaque déménagement ; en jeu, les emplois et les
  écoles sont attribués quand des foyers arrivent, sinon une fois par heure de jeu ;
- objectifs et résumé à l'écran : satisfaction relue dans le dernier sondage de la ville ;
- nuisances et niveaux de vie : leur fin de calcul est étalée sur plusieurs images.

Pire image en temps réel : de 4,8 s à moins de 2,5 s ; pas moyen du banc de 1,1 s à 0,4 s.

**Équilibrage** :
- *Marché du travail* : chaque jour, des actifs quittent un employeur au complet pour une
  entreprise proche (4 km) qui a moins de la moitié de son personnel, 15 % des postes
  vacants par jour (`Population._mobilite`). Une usine qui ouvre dans une ville sans
  chômeurs se remplit en une à deux semaines. Les métiers indispensables (enseignant,
  médecin…) et le personnage du joueur ne partent pas.
- *Villages* : sous 40 foyers, une ville se remplit sans le plafond d'arrivées par jour.
- *Vie politique par ville* : une manifestation ignorée, des promesses tenues ou un
  nouveau mandat ne touchent plus que leur ville (avant : toutes les villes du joueur).
  La négociation est payée par la ville qui manifeste.
- *Pilote automatique* : une construction par jour si besoin (avant : une par semaine) ;
  il pose aussi l'antenne 4G, le central téléphonique, un dépôt de collecte des déchets et
  une décharge, la police selon la taille, et reçoit les manifestants si la caisse le permet.

**Envie de revenir** :
- *Défi du jour* (Maj+J et résumé à l'écran) : un petit objectif tiré d'après la vraie date,
  le même pour tous les joueurs ce jour-là ; prime qui grandit avec la série de jours
  réussis d'affilée (jusqu'à ×2), succès « Fidèle au poste » à 7 jours.
- *Rang « Ville moyenne »* à 5 000 habitants, entre Ville (2 000) et Grande ville (10 000).

## Ce qui reste

- **Images en temps réel** : 100 à 160 ms par image en moyenne sans carte graphique
  (6 à 10 images par seconde) avec 8 villes et 5 000 habitants, contre 29 ms pour une seule
  ville de 15 000 habitants. Les plus gros postes : circulation (~11 ms), réseaux (~10 ms),
  zones (~10 ms), habitants. À mesurer aussi sur un vrai PC, avec la carte graphique.
- **Villages neufs lents** : 8 à 185 habitants en 40 jours, même sous pilote automatique.
- **Import bloqué** : avec deux sorties de route seulement, la capacité d'import du jour est
  vite prise (sel, acier, plastiques, bois manquants). Une gare ou un port en plus règle ça.
- **Chauffeurs-livreurs** : 4 ou 5 entreprises attendent un chauffeur en fin de partie.
- **Chargement** d'une partie de 13 000 habitants : ~45 s dans le conteneur, dont 25 s
  d'attente du relief hors ligne (sans internet) ; `transport.from_dict` prend ~6,6 s.
