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

## Le restaurant

Les 55 cafés et restaurants du jeu (café-restaurant, brasserie, auberge, taverne, pub, maquis, salon de thé…) se gèrent aussi : tuile **Gérer le restaurant** sur leur fiche. 14 pièces : accueil et vestiaire, grande salle, cuisine, plonge, réserve et chambre froide, bureau du patron, bar, toilettes, salon privé, cave à vins, salon de thé et pâtisserie, et dehors la terrasse, le potager avec son poulailler et le quai de livraison. Environ 70 objets dessinés (friteuse, four mixte, piano du chef en cuivre, rôtissoire, tireuse à bière, baby-foot, aquarium à homards, pergola et vigne, guirlandes, ruches, scooters de livraison, camionnette…).

- Le compte du restaurant est la caisse de l'entreprise (économie, touche P) : les améliorations se paient d'abord avec elle, la ville avance le reste.
- **Couverts** : la salle, la terrasse, le salon privé et le bar ajoutent des tables : le restaurant peut servir plus de repas par jour (habitants et touristes).
- **Affluence** : la note, l'attrait et le **prix du menu** (− / + dans l'onglet Restaurant) décident combien de clients viennent. Plus cher, chaque repas rapporte plus mais il vient moins de monde et ils sont moins contents.
- **Toques** (1 à 5) : comme les étoiles de l'hôtel, gagnées par le confort ; chaque toque rend le repas plus cher. Le vin, les desserts et les cafés (« ventes ») s'ajoutent à l'addition.
- Chaque jour : salaires, entretien des améliorations, bilan (recettes, charges, couverts servis), satisfaction (prix, pannes, produits qui manquent) et note.
- Événements : critique gastronomique incognito (« Coup de cœur » du guide), inspection d'hygiène (amende si la cuisine, la plonge, la réserve ou les toilettes sont en panne), banquets dans le salon privé (mariages, repas d'entreprise), clients célèbres, soirs de match au bar.
- Gestion automatique comme l'hôtel (sans jamais toucher à la caisse de la ville).

## La caserne de pompiers

Les casernes (et leurs versions d'époque) se gèrent : tuile **Gérer la caserne** sur leur fiche. C'est un **service public** : pas de clients qui paient, mais un **budget versé chaque jour par la caisse de la ville** (1 000 € par jour pour une caserne standard, − / + dans l'onglet Caserne, de 0 à 8 fois plus). La caserne paie son entretien avec ce budget et investit le reste (tout seule en gestion automatique). Une caserne jamais ouverte en mode gestion ne coûte rien de plus.

14 pièces : accueil et couloir, salle d'alerte, remise des engins, chambres de garde, vestiaires et douches, cuisine et réfectoire, salle de formation, bureau du chef de centre, magasin et pharmacie, salle de sport, atelier mécanique, et dehors la cour d'honneur, la tour de manœuvre et l'aire de lavage et de carburant. 74 objets dessinés (râtelier de tuyaux, compresseur d'air, désincarcération, tour de séchage, mât de descente, lits superposés, tenues de feu, mur d'écrans, mannequins de secourisme, simulateur de feu, pont élévateur, pompe à bras de 1890, camion des années 1950, conteneur d'entraînement au feu…).

Ce que ça change **vraiment** dans les urgences (touche U) :
- **Remise** : chaque niveau ajoute un engin à la flotte (VSAV, fourgon pompe-tonne, VSAV, grande échelle) et l'engin de réserve un de plus. Dans la maquette, les engins sont garés dans la remise ; quand un appel arrive, l'alerte sonne et l'engin sort, gyrophares allumés, et part par la rue. Il revient à sa place quand il rentre.
- **Chambres de garde** : un pompier de garde de plus par niveau (lits superposés : un de plus). Chaque engin a besoin de son équipage pour partir : plus de garde, plus d'engins en même temps. Les **volontaires** (recrutés grâce au prestige et à la salle de formation) comptent aussi.
- **Rapidité** : alerte, vestiaires, sport, tour de manœuvre, matériel et formation du personnel font travailler l'équipe plus vite sur place (jusqu'à 2,5 fois).
- **Note** : elle suit le **délai moyen d'arrivée** des secours de cette caserne (5 sur 5 sous 3 minutes), le moral et les pannes. **Galons** (1 à 5) : gagnés par l'expérience (pièces et objets).
- Événements : inspection (« citée en exemple » : un pompier de garde en plus pendant 60 jours), bal des pompiers en juillet, tournée des calendriers en fin d'année, volontaires, manœuvres, visites d'écoles. Les visiteurs (stages de secourisme, enfants, futurs volontaires) posent leurs questions : y répondre rapporte un petit don.

## Le commissariat de police

Les commissariats se gèrent aussi : tuile **Gérer le commissariat** sur leur fiche. Comme la caserne, c'est un **service public** payé par la ville (budget de 900 € par jour pour un commissariat standard, − / + dans l'onglet Commissariat). Un commissariat jamais ouvert en mode gestion ne coûte rien de plus.

14 pièces : accueil et salle d'attente, salle de commandement (le 17), garage des voitures, vestiaires et salle de repos, bureau des plaintes, salle de pause, bureau du commissaire, armurerie et scellés, bureau des enquêteurs, cellules de garde à vue, stand de tir et sport, et dehors le parvis avec sa piste d'éducation routière, le chenil de la brigade cynophile et la fourrière. 75 objets (tableau des clés, motos, radar, gilets pare-balles, scellés, tableau de l'enquête avec ses fils rouges, kit d'empreintes, petit labo de police scientifique, toise, salle d'audition, cibles mobiles, niches, Rex le chien, dépanneuse, sabots de Denver, estafette des années 1960…).

Ce que ça change **vraiment** dans la ville :
- **Garage** : chaque niveau ajoute une voiture de patrouille (ou un fourgon) à la vraie flotte de police ; la voiture banalisée de réserve en ajoute une. Dans la maquette, on voit la voiture sortir, gyrophares allumés, quand un appel arrive.
- **Vestiaires et repos** : un policier en service de plus par niveau. Les **réservistes** (recrutés grâce à la confiance des habitants et au bureau des plaintes) comptent aussi.
- **Enquêtes** (nouveau) : quand la patrouille arrive trop tard sur un cambriolage, les enquêteurs ont une chance de retrouver les voleurs (bureau des enquêteurs, cellules, chenil, empreintes, fichier, labo : jusqu'à 85 %). Le foyer ne perd alors rien, et c'est compté dans les statistiques des urgences.
- **Fourrière** : les voitures mal garées rapportent des frais au budget du commissariat.
- **Note** : délai moyen d'arrivée, moral et pannes. **Insignes** (1 à 5) : gagnés par l'expérience.
- Événements : contrôle de la préfecture (« félicité » : un policier en plus pendant 60 jours), permis vélo des écoles au printemps, démonstrations de la brigade cynophile, défilé du 14 juillet, objets trouvés rendus, réservistes.

## L'hôpital

Les hôpitaux se gèrent aussi : tuile **Gérer l'hôpital** sur leur fiche. Service public payé par la ville (environ 3 100 € par jour pour un hôpital standard, − / + dans l'onglet Hôpital). Un hôpital jamais ouvert en mode gestion ne coûte rien de plus.

14 pièces : accueil des urgences, régulation du SAMU (le 15), garage du SAMU, chambres des patients, salle de garde des urgentistes, consultations, direction, pharmacie, bloc opératoire, imagerie (radio, scanner), laboratoire, et dehors le jardin des patients, l'hélistation et le parking des visiteurs. 67 objets (fauteuils roulants, lits médicalisés, pieds à perfusion, table d'examen, échographe, table d'opération, scialytique, moniteurs, respirateur, robot chirurgical, scanner, microscopes, frigo à poches de sang, hélicoptère sanitaire…).

Ce que ça change **vraiment** dans la ville :
- **Garage du SAMU** : chaque niveau ajoute une ambulance ou un SMUR à la vraie flotte (Urgences). Elles sortent du garage gyrophares allumés dans la maquette.
- **Salle de garde** : un urgentiste de garde de plus par niveau. Les **internes** (attirés par la réputation et les consultations) comptent aussi.
- **Chambres** (nouveau) : 12 lits de plus par niveau (et 4 avec les lits médicalisés) dans la capacité de l'hôpital, utilisée par les services publics et la santé publique.
- **Soins** (nouveau) : bloc, imagerie, labo, pharmacie, hélistation. Quand l'ambulance arrive trop tard sur un malaise, une partie des patients qui seraient morts sont sauvés (jusqu'à 80 %).
- **Parking** : les tickets des visiteurs rapportent un peu chaque jour.
- **Note** : délai moyen d'arrivée des ambulances, moral, pannes. **Caducées** (1 à 5) : gagnés par l'expérience.
- Événements : certification (« sans réserve » : un urgentiste en plus pendant 60 jours), naissances, collecte de sang en hiver, clowns hospitaliers, hélicoptère, internes.

## Le parc de loisirs

Le parc de loisirs se gère comme une maquette : bouton **Gérer le parc (maquette)** dans le panneau du parc (Maj+G), ou tuile sur la fiche de l'**Entrée du parc**. Le parc appartient à la ville : les billets et les stands vont toujours dans la caisse de la ville. Une fois le parc ouvert en gestion, **25 % du bénéfice du jour** sont mis de côté dans la **caisse des travaux** du parc, qui paie les aménagements (la ville avance le reste). Un parc jamais ouvert en gestion ne change pas.

13 zones : billetterie, direction, infirmerie, manèges familiaux, grands frissons, rivière et toboggans, royaume des petits, place gourmande, boutique de souvenirs, scène des spectacles, toilettes, atelier technique et parking des visiteurs. 68 objets (bornes à billets, mascotte, coupe-file, écrans d'attente, brumisateurs, photo souvenir, petit train, friterie, barbe à papa, food truck, gradins, projecteurs, machine à fumée, nacelle élévatrice, balayeuse, ombrière solaire, autocar…).

**Les vraies attractions** du parc apparaissent **en miniature** dans leur zone, et elles tournent : montagnes russes et bateau pirate dans les grands frissons, attractions sur l'eau dans la rivière, petits manèges chez les petits, le reste dans les manèges familiaux (et là aussi tant que leur zone n'est pas construite).

Ce que ça change **vraiment** dans le parc :
- **Visiteurs attirés** (billetterie, parking, spectacles, mascotte…) : plus de visiteurs attendus chaque jour, jusqu'à +80 %.
- **Confort** (décors, files ombragées, bancs…) : jusqu'à +1 étoile sur la note du parc.
- **Vitesse** : manèges et stands qui servent plus vite (jusqu'à +50 %).
- **Fiabilité des manèges** (atelier, techniciens) : jusqu'à 70 % d'usure en moins et des révisions plus efficaces.
- **Propreté** (toilettes, atelier, balayeuse) : les agents de propreté nettoient plus vite.
- **Ventes** : photos, consigne, poussettes… chaque visiteur dépense un peu plus.
- **Humeur** : les visiteurs arrivent de meilleure humeur, surtout quand on règle leurs demandes (« J'ai perdu mon fils ! », « Mon ballon s'est envolé ! »).
- Le **billet** se règle depuis la maquette (− / +) ; en gestion automatique, il suit ce que vaut le parc et les refus à l'entrée.
- **Fanions** (1 à 5) : gagnés par l'expérience. Événements : inspection de sécurité (label Sécurité 60 jours), trophée du parc de l'année en décembre, autocars et sorties scolaires, anniversaires, influenceurs, canicule.

## Rythme

Le mode suit le temps du jeu : rien ne se gagne pendant que le jeu est fermé, rien ne bouge en pause, tout va plus vite en vitesse rapide. La gestion automatique, les pannes et les événements tournent chaque jour de jeu pour tous les hôtels, même ceux qu'on n'ouvre jamais. Un hôtel jamais ouvert garde ses effets à zéro tant qu'il n'a rien acheté.

## Pour aller plus loin (code)

- `scripts/gestion/genres/genre_restaurant.gd` (`GenreRestaurant`) : le restaurant (pièces, objets, demandes, pannes). `source` dit qui fait vivre le bâtiment : `tourisme` (hôtel) ou `production` (restaurant : `Gestion.affluence_de`, `prix_repas_de`, `couverts_de`, `compter_de`, `entretien_site`, `cloture_de` sont appelés par `Production`).
- `scripts/gestion/decors_restaurant.gd` et `modeles_restaurant.gd` : décors de base des pièces et ~50 modèles du restaurant.
- `scripts/gestion/genres/genre_caserne.gd` (`GenreCaserne`), `decors_caserne.gd`, `modeles_caserne.gd` : la caserne. Source `ville` : le compte est `etat.caisse`, alimenté par `dotation()` dans `_journee_ville()`. Liens avec `Urgences` : `Gestion.flotte_de` (engins en plus, `Urgences.maj_flotte`), `equipage_de` (ajouté à `staff_of`), effet `vitesse` (temps sur place), `intervention_de` et `depart_de` (délai, note, journal). Les engins de la maquette : `GestionDiorama.placer_engins`.
- `scripts/gestion/genres/genre_commissariat.gd` (`GenreCommissariat`), `decors_commissariat.gd`, `modeles_commissariat.gd` : le commissariat, même source `ville`. Les mots propres au service (voiture/engin, garage/remise, policier/pompier, « en service »/« de garde », conseil) sont des clés du genre (`vehicule`, `vehicules`, `garage`, `agent`, `agents`, `de_garde`, `conseil`, `label_effet`, `seul`). Effet `enquete` : `Gestion.chance_enquete_de` et `enquete_de`, appelés par `Urgences._effects_on_done` pour un cambriolage arrivé trop tard.
- `scripts/gestion/genres/genre_hopital.gd` (`GenreHopital`), `decors_hopital.gd`, `modeles_hopital.gd` : l'hôpital. Effet `lits_sup` (un nombre de lits, `Gestion.lits_sup_de`, ajouté dans `ServicesPublics.capacite`) et effet `soins` (`Gestion.chance_soins_de`, `patient_de`, appelés par `Urgences._effects_on_done` pour un malaise en retard).
- `scripts/gestion/genres/genre_parc.gd` (`GenreParc`), `decors_parc.gd`, `modeles_parc.gd` : le parc de loisirs. Source `parc` : chiffres de `ParcLoisirs` (`Gestion._journee_parc`, `visiteurs_parc`, `batiments_parc`). Les effets sont lus par `ParcLoisirs.effet_gestion` (plafonnés par `GESTION_MAX`). Miniatures : `GestionVue.zone_attraction` et `GestionDiorama._poser_miniatures` (clé `miniatures` du genre), clôture et allées : clés `cloture` et `allees`.
- `scripts/gestion/gestion_types.gd` (`GestionTypes`) : les genres gérables. Un genre = ses pièces (plan, niveaux, prix, effets, métiers et postes, portes et chemins), ses objets (modèle, poses, prix, niveau requis, effets), ses demandes, ses pannes, les activités des clients. Pour ajouter la prison, l'hôpital, l'usine… : une entrée dans `GENRES`, une ligne dans `genre_de()`, et les décors de base de ses pièces dans le diorama (`_decor_<nom>`).
- `scripts/gestion/gestion.gd` (`Gestion`) : niveaux, objets, prix, paiement, effets (`Gestion.effet_de(bid, clé)`), étoiles, personnel (salaires, formation), pannes, événements, historique, journal, gestion automatique (`gerer_auto`, `candidats`), objectifs, sauvegarde (section `gestion`). `nouveau_jour()` est appelé par le tourisme à chaque fin de journée.
- `scripts/gestion/gestion_modeles.gd` (`GestionModeles`) : la bibliothèque des objets low-poly (72 modèles) et les places qu'ils offrent aux clients.
- `scripts/gestion/gestion_diorama.gd` (`GestionDiorama`) : la maquette (sols, murs, fenêtres, façade, rue), les figurines, les trajets, les pannes.
- `scripts/gestion/gestion_vue.gd` (`GestionVue`) et `graphe_gestion.gd` : l'écran (caméra isométrique, barre du haut, carte à onglets, tuiles du bas, bulles, graphique).
- Effets lus par le tourisme : `Tourisme.spec`, `lits`, `note`, `attrait_heb`, repas sur place, dépenses sur place (`ventes`), satisfaction, entretien.

Tests : `xvfb-run -a godot --path . --rendering-driver opengl3 --script res://tests/gestion_test.gd` (hôtel) , `res://tests/gestion_restaurant_test.gd` (restaurant) `res://tests/gestion_caserne_test.gd` (caserne) `res://tests/gestion_commissariat_test.gd` (commissariat) et `res://tests/gestion_hopital_test.gd` (hôpital). Captures : `tests/gestion_vitrine.gd -- --out DOSSIER [--type haussmann__restaurant|pompiers|police|hopital] [--depart] --niveau 1|3|5 [--piece spa] [--zoom 30] [--onglet personnel|stats|journal] [--x 20 --z 14]`.
