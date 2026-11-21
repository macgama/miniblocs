# Mode gestion « tycoon » : un jeu de gestion dans chaque bâtiment

Clique sur un hôtel, puis sur la tuile **Gérer l'hôtel** de sa fiche (ou sur **Gérer** dans le menu Tourisme, Maj+D → Hébergements) : on entre dans l'hôtel, vu en 3D isométrique, comme dans un petit jeu de gestion à part. Le temps de la ville continue (T : pause, Maj + T : vitesse) ; **Échap** ramène à la ville.

**Si tu ne t'en occupes pas, l'hôtel se gère tout seul** (bouton **Gestion auto** en haut, actif par défaut) : il répare ses pannes, ajuste le prix de la nuit chaque semaine selon le remplissage et investit ses bénéfices dans l'amélioration ou l'objet le plus rentable, en gardant 15 jours de charges en réserve. Il ne touche jamais à la caisse de la ville. Clique sur le bouton pour passer en **Je gère** et tout décider toi-même ; tu peux aussi acheter ce que tu veux en mode automatique.

![Hôtel en mode gestion](apercu-gestion-hotel.png)

## Ce qu'on voit

- **La maquette** : le rez-de-chaussée coupé comme une maison de poupée. Murs du fond hauts avec fenêtres, rideaux et appliques ; cloisons basses ; façade rasée. Sols à motifs (damier du hall, parquet du bar et du restaurant, moquette des chambres, carrelage du spa et de la lingerie, dalles de la salle de sport). Dehors : parvis avec jardinières, vélos, mâts et drapeaux, l'enseigne avec le nom de l'hôtel et ses étoiles, le parking, la rue avec ses voitures qui passent.
- **13 pièces** : hall et réception, chambres (6 chambres le long d'un couloir, avec lit, chevets, salle de bains), lingerie, bureau de la direction, bar et salon, restaurant (cuisine ouverte), spa, boutique, salle de sport, salle de conférences ; dehors la piscine, le jardin et club enfants, le parking et voiturier. Une pièce pas encore construite est un emplacement de chantier (gravier, piquets, ruban, « + nom de la pièce »).
- **Les objets achetés** (environ 75, de 4 à 9 par pièce), chacun dessiné à sa place : télé, minibar, clim, coffre, baignoire balnéo dans chaque chambre ; fontaine, lustre, borne d'enregistrement dans le hall ; piano, billard, juke-box, cheminée au bar ; buffet, four à pizza, aquarium au restaurant ; sauna, jacuzzi, hammam au spa ; plongeoir, toboggan, palmiers, bar de la piscine ; balançoire, kiosque au jardin ; bornes de recharge, guérite, navette au parking… Beaucoup donnent des places en plus aux clients (canapés, bancs, transats, vélos d'appartement).
- **Le personnel** : les vrais employés de l'hôtel (les habitants embauchés), chacun à son poste selon son métier. Un poste sans personne affiche **Poste vacant**. Les pièces ajoutées dont l'hôtel n'embauche pas le métier (vendeur de la boutique, coach, animateur du club enfants…) ont des **extras**, payés dans l'entretien de la pièce.
- **Les clients** : un personnage pour environ 5 clients réels (au plus 22 à l'écran). Ils arrivent par le trottoir, font la queue à la réception, vont dans une chambre, au restaurant, au bar, au spa, à la piscine, à la boutique, à la salle de sport, au jardin ou en conférence, et repartent. Le prix de la nuit, des repas ou des soins s'affiche au-dessus d'eux.
- **Les demandes** : de temps en temps un client lève un **!** (« Des serviettes propres ! », « Le projecteur ne s'allume pas ! », « Mon fils est coincé en haut du toboggan ! »…). Un clic dessus la règle : pourboire et clients plus contents. Une demande oubliée les déçoit un peu.
- **Les pannes** : un appareil tombe en panne de temps en temps (douche bouchée, four en panne, filtre de la piscine encrassé…). Un **⚠** et de la fumée apparaissent au-dessus de la pièce ; tant que ce n'est pas réparé, la satisfaction baisse chaque jour. Un clic sur le ⚠ répare. Un personnel formé et une direction au niveau 3 cassent moins.

## Ce qu'on fait

- **Améliorer les pièces** (clic sur une pièce ou sur sa tuile en bas) : 5 niveaux par pièce. La carte de droite dit ce que le niveau suivant apporte, son prix et qui le paie. Chaque niveau ajoute de l'**entretien** par jour.
- **Équiper les pièces** : sous les niveaux, la liste des objets de la pièce avec leurs effets et leur prix ; certains demandent un niveau de pièce (le lustre attend un hall au niveau 4).
- **Onglet Hôtel** : étoiles, objectifs, comptes d'hier, prix de la nuit (− et +), remboursement de la ville.
- **Onglet Équipe** : postes pourvus par pièce, **salaires** (80 % à 150 % : mieux payée, l'équipe sourit et les clients le sentent), **formation** (5 niveaux : service plus rapide, clients plus contents, moins de pannes), **pannes** à réparer.
- **Onglet Chiffres** : recettes et charges des 30 derniers jours en barres, remplissage en courbe, note, satisfaction, séminaires, clients célèbres.
- **Onglet Journal** : tout ce qui s'est passé (travaux, achats, pannes, visites).
- **Gagner des étoiles** : tous les 0,6 point de confort gagné, une étoile de plus (jusqu'à 5).

## Ce qui arrive tout seul

- **L'inspecteur du guide** passe incognito à peu près une fois par mois. Si la note est assez bonne pour les étoiles de l'hôtel, il le **recommande** pendant 60 jours (+6 % de clients).
- **Séminaires** : la salle de conférences se loue à des entreprises (plus souvent et plus cher quand elle est équipée).
- **Clients célèbres** : une chanteuse, un footballeur, une ministre… laissent un gros pourboire (plus souvent dans les beaux hôtels).
- **Autocars** : un groupe de touristes arrive sans prévenir quand il reste de la place (plus souvent avec un grand parking).

Objectifs : 3 améliorations, 15 objets, 10 demandes réglées, hôtel rempli à 75 %, note de 4, recommandation du guide, toutes les pièces, 5 étoiles.

## L'argent

L'hôtel est une entreprise privée : ses bénéfices s'accumulent sur son **compte**. Ce qu'on achète se paie d'abord avec ce compte ; s'il ne suffit pas, **la caisse de la ville avance le reste** (inscrit au budget : « Gestion : avance à … »), que l'hôtel rembourse plus tard (bouton **Rembourser la ville**). La gestion automatique, elle, n'utilise que le compte de l'hôtel. Avec l'argent illimité (F10), tout est gratuit.

La boutique, le bar, le spa, le minibar, la cave à vins… font **dépenser** les clients sur place : ces ventes entrent dans les recettes de l'hôtel. Ce que la ville y gagne : plus de lits et de clients, donc plus de nuitées, de taxe de séjour, d'impôts sur les bénéfices, de repas et de courses en ville.

## Rythme

Le mode suit le temps du jeu : rien ne se gagne pendant que le jeu est fermé, rien ne bouge en pause, tout va plus vite en vitesse rapide. La gestion automatique, les pannes et les événements tournent chaque jour de jeu pour tous les hôtels, même ceux qu'on n'ouvre jamais. Un hôtel jamais ouvert garde ses effets à zéro tant qu'il n'a rien acheté.

## Pour aller plus loin (code)

- `scripts/gestion/gestion_types.gd` (`GestionTypes`) : les genres gérables. Un genre = ses pièces (plan, niveaux, prix, effets, métiers et postes, portes et chemins), ses objets (modèle, poses, prix, niveau requis, effets), ses demandes, ses pannes, les activités des clients. Pour ajouter la prison, l'hôpital, l'usine… : une entrée dans `GENRES`, une ligne dans `genre_de()`, et les décors de base de ses pièces dans le diorama (`_decor_<nom>`).
- `scripts/gestion/gestion.gd` (`Gestion`) : niveaux, objets, prix, paiement, effets (`Gestion.effet_de(bid, clé)`), étoiles, personnel (salaires, formation), pannes, événements, historique, journal, gestion automatique (`gerer_auto`, `candidats`), objectifs, sauvegarde (section `gestion`). `nouveau_jour()` est appelé par le tourisme à chaque fin de journée.
- `scripts/gestion/gestion_modeles.gd` (`GestionModeles`) : la bibliothèque des objets low-poly (72 modèles) et les places qu'ils offrent aux clients.
- `scripts/gestion/gestion_diorama.gd` (`GestionDiorama`) : la maquette (sols, murs, fenêtres, façade, rue), les figurines, les trajets, les pannes.
- `scripts/gestion/gestion_vue.gd` (`GestionVue`) et `graphe_gestion.gd` : l'écran (caméra isométrique, barre du haut, carte à onglets, tuiles du bas, bulles, graphique).
- Effets lus par le tourisme : `Tourisme.spec`, `lits`, `note`, `attrait_heb`, repas sur place, dépenses sur place (`ventes`), satisfaction, entretien.

Tests : `xvfb-run -a godot --path . --rendering-driver opengl3 --script res://tests/gestion_test.gd`. Captures : `tests/gestion_vitrine.gd -- --out DOSSIER --niveau 1|3|5 [--piece spa] [--zoom 30] [--onglet personnel|stats|journal] [--x 20 --z 14]`.
