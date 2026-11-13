class_name AidePanel
extends Control
## Fenêtre d'aide (F1) : toutes les commandes du jeu, rangées par thème.

signal closed

const SECTIONS := [
	["Caméra (vue de dessus)", [
		["ZQSD ou flèches", "déplacer (WASD en QWERTY)"],
		["Clic droit glissé", "faire glisser la carte"],
		["Molette", "zoomer"],
		["A / E, ou clic molette glissé à gauche / à droite", "tourner (Q / E en QWERTY)"],
		["Clic molette glissé en haut / en bas, ou Ctrl + molette", "incliner : jusqu'à une vue rasante pour voir le relief jusqu'à l'horizon (10 km)"],
	]],
	["Barre du bas", [
		["Tab · Gérer / Créer", "Gérer : la ville (terrain, voies, zonage, catalogue, lignes, habitants). Créer : construire un bâtiment soi-même (murs et étages, blocs, intérieur, Mes créations, banque, atelier), la ville en pause ; touches 1 à 7 et échelle des étages"],
		["Catégories", "Observer, Terrain, Voies, Paysage : un clic ouvre leurs outils juste au-dessus ; Construire et Décors ouvrent leur panneau à droite (un seul à la fois)"],
		["Menus ▴", "Transports (lignes, trafic, circulation, véhicules), Ville (habitants, urgences, avis, budget, déchets), Économie (production, agriculture, parc de loisirs), Infos (infos, cartes) : un clic ouvre la rangée de leurs panneaux ; les touches restent les mêmes"],
		["Circulation, Véhicules, Vue", "afficher la circulation, choisir l'époque et la région des véhicules, changer de vue"],
		["1", "observer : survoler une case pour voir son altitude et son biome (et le nom de la rivière)"],
		["2 · 3 · 4", "aplanir, monter de 1 m, creuser de 1 m (clic gauche glissé)"],
		["5 · 6 · 7 · 8", "route, rail (tram, train, LGV, crémaillère, métro), chemin, voie d'eau : un clic par point"],
		["C", "voie en courbe (pendant le tracé)"],
		["N", "croisements : automatique, passer dessus (pont), passer dessous (tunnel)"],
		["Maj", "angles par pas de 15° (pendant le tracé)"],
		["9", "démolir une voie"],
		["J", "carrefour : clic pour changer son régime (auto, feux, stop, cédez-le-passage, priorité à droite)"],
		["Maj + clic (outil J)", "transformer le carrefour en giratoire"],
		["Outil J > Échangeur", "clic sur une route qui enjambe une autoroute : 4 bretelles"],
		["0", "paysage : colline, lisser, lac ou canal, combler l'eau, peindre un biome, planter ou arracher des arbres (pinceau rond, clic gauche glissé)"],
		["Échap ou clic droit", "arrêter le tracé, annuler l'outil"],
		["Échap (sans outil en cours)", "menu pause : le temps s'arrête ; sauvegarder, charger, options, menu principal, quitter"],
	]],
	["Construire (panneau de droite)", [
		["B", "afficher ou masquer le panneau Construire (catégories en icônes, bâtiments en vignettes)"],
		["Clic gauche", "poser le bâtiment choisi"],
		["R", "tourner le bâtiment d'un quart de tour (sinon il se cale tout seul le long de la route la plus proche, même courbe, à sa hauteur)"],
		["Ctrl + Z", "annuler (éditeur libre : blocs, murs et étages)"],
		["R (éditeur libre)", "tourner l'escalier, la pente, la porte ou la fenêtre d'un quart de tour"],
		["Enregistrer + clic glissé", "éditeur libre : ta construction devient un bâtiment de « Mes créations »"],
		["Murs et étages (éditeur libre)", "murs de 20 cm posés sur les lignes de la grille, pièces, sols, escaliers, portes et fenêtres, peinture d'un côté de mur ou de toute une pièce"],
		["Page haut / Page bas, ou l'échelle des étages", "étage actif (jusqu'à 59 étages et 5 sous-sols, le terrain est creusé) ; les étages du dessus sont masqués pendant l'édition"],
		["Copier l'étage ↑", "recopie l'étage actif au-dessus, autant de fois que voulu (immeubles)"],
		["Murs et pièces sur N étages", "réglage du panneau : un trait de Mur ou un rectangle de Pièce monte sur plusieurs étages d'un coup"],
		["Toit (murs et étages)", "deux pans, quatre pans ou plat, posé en blocs sur le dernier étage"],
		["Filtres", "région, époque et recherche par nom dans les listes de bâtiments"],
	]],
	["Intérieur (Construire → fauteuil)", [
		["Bâtiments meublés", "maison, immeuble, école, boutique, bureaux, café : posés meublés, dans le style choisi, prêts à visiter (V)"],
		["Meubler / Fonction / Catalogue", "meubler une pièce selon sa fonction, choisir la fonction, ou poser un meuble de la bible case par case (R tourne, clic droit retire, Ctrl + Z)"],
		["E sur un meuble (vue au sol)", "son nom, son style et ce qu'il apporte : confort, attractivité, valeur"],
		["Personnaliser (fiche d'un bâtiment)", "couleurs, toit, étages, pente, variante (bâtiments Blender : couleurs) ; « Ouvrir l'intérieur » le refait en murs fins, meublé et visitable"],
		["Page bas · Page haut · Origine", "vue par étage (mode Gérer) : enlève ou remet les étages des bâtiments en murs fins autour de la caméra, pour voir les habitants dedans"],
		["Banque (6) · Atelier (7)", "tes modèles étiquetés (type, style, époque, couleur) à reposer ou échanger ; l'atelier : terrain plat sans habitants ni argent"],
		["Chantiers", "bâtiments et voies se construisent étape par étape au rythme de la vie (maison ≈ 3 semaines de jeu), en semaine et en journée ; le prix se paie au fil des travaux ; panneau Admin (F10) : horaires des équipes ou construction instantanée"],
	]],
	["Événements", [
		["I", "panneau Infos : événements en cours et à venir, journal, organiser une fête ou un marché, dégâts à réparer, stades et classement"],
		["Fil d'actualité (haut de l'écran)", "clic sur une nouvelle pour aller sur place"],
		["Incendie, tempête, épidémie à la main", "panneau Infos, onglet Organiser, puis clic sur la carte (Échap pour annuler)"],
		["Catastrophes", "panneau Admin (F10), section Événements : les couper ou régler leur fréquence"],
	]],
	["Villages et territoire", [
		["Début de partie", "sur le globe, cherche la ville de départ ; puis choisis le nom et le drapeau du village et pose sa Maison de commune (pas besoin de route) : avant, on ne peut que regarder et modeler le paysage"],
		["Drapeau", "Maj+M, bouton Changer… à côté du drapeau d'un village : n'importe quel pays, ou aucun"],
		["Maj+M", "panneau Villages : habitants, territoire et palier de chaque village ; Aller, Renommer, Agrandir, Céder, Fusionner"],
		["Fondateurs", "100 fondateurs (réglable en F10) arrivent avec le premier village et campent près de la Maison de commune : ce sont les ouvriers des premiers chantiers. Vivres pour 90 jours, puis ravitaillement payé par la caisse ; ils emménagent dans les maisons finies"],
		["Maj+H", "panneau Fondateurs et chantiers : équipes de chaque chantier (pause, « En premier »), affecter les fondateurs à n'importe quel métier ou les rappeler au chantier"],
		["Ouvriers", "un chantier veut une équipe complète (maison ≈ 8 à 10 ouvriers) : moins d'ouvriers, il avance moins vite ; aucun, il attend. Plus tard : Entreprise du bâtiment (Construire → Industrie)"],
		["Territoire", "carrés de 100 × 100 m autour de la mairie : 500 m au départ, il grandit tout seul avec la population (800 m à 100 hab., 1,2 km à 500, 2 km à 2 000, 3 km à 10 000)"],
		["Agrandir / Céder", "clic sur un carré qui touche le territoire pour l'acheter, ou sur un carré vide pour le rendre ; clic droit ou Échap pour arrêter"],
		["Nouveau village", "Maison de commune ou Mairie posée hors de tout territoire, à 2 km au moins d'un autre centre ; deux villages qui se touchent peuvent fusionner"],
		["Règles", "bâtiments et zonage seulement sur le territoire ; voies, réseaux et lignes partout ; Admin (F10) → Construction pour couper ces règles"],
	]],
	["Pays et caisses des villes", [
		["Maj+P", "panneau Pays : caisse du pays, impôt national, dotation par habitant, et chaque ville avec sa caisse, son solde du mois et son maire ; Gérer, Subvention, Reverser au pays"],
		["Une caisse par ville", "chaque ville a ses impôts, ses emprunts, son entretien et sa tutelle ; la caisse affichée en haut est celle de la ville que regarde la caméra (Gérer dans Maj+P pour l'épingler)"],
		["Qui paie ?", "ce qui se construit sur le territoire d'une ville est payé par sa caisse ; les voies et bâtiments hors des villes, par le pays ; les ventes des entreprises sont partagées selon la population"],
		["Caisse du pays", "elle reçoit l'argent de départ et l'impôt national (10 % des impôts des villes) ; elle paie la dotation par habitant, l'entretien des voies hors des villes, les subventions et le capital des nouvelles villes (60 % de la caisse pour la première, 1 M€ pour les suivantes)"],
		["Pays à sec", "une caisse du pays vide ne verse plus de dotation : les villes doivent alors vivre de leurs impôts"],
		["Élections", "chaque ville vote de son côté, pour son maire ; le panneau Avis (Y) montre la ville gérée"],
		["Mairie perdue", "si une autre liste gagne (réglage Admin « Défaite : mairie perdue », par défaut), tu construis toujours dans cette ville, mais son maire décide des impôts, des emprunts et de l'entretien selon son programme ; tu ne peux plus reverser son argent au pays"],
		["Kit de l'État", "ta première ville dans chaque pays reçoit un kit d'installation : un bâtiment offert pour l'électricité (jusqu'à 25 M€), l'eau potable (8 M€), les égouts (10 M€) et les déchets (3 M€), du type de ton choix, que tu places où tu veux sur son territoire ou à moins de 3 km de la mairie ; le chantier se fait avec les fondateurs, et l'État envoie 40 ouvriers de plus ; restant dans Maj+P"],
		["Pilote automatique", "Maj+P, bouton Activer sous une ville : chaque semaine elle tient son budget à l'équilibre et fait la construction la plus urgente (rue, zone résidentielle, école, aire de jeux, boulangerie, parc, pompiers, police, supérette, gymnase, hôpital, zone d'activités si le chômage dépasse 12 %), en gardant 3 mois de dépenses en réserve"],
		["Reprendre la mairie", "gagne les municipales suivantes (campagne et promesses dans Y), ou lance des élections anticipées par pétition si la satisfaction tombe sous 40"],
	]],
	["Niveaux de vie", [
		["Maj+N", "panneau Niveaux de vie : combien de foyers à chaque niveau, ce qui les empêche de monter (avec un conseil), les besoins de chaque niveau, la liste des foyers"],
		["Les 5 niveaux", "Précaire, Modeste, Classe moyenne, Aisé, Très aisé ; les nouveaux arrivants commencent au plus en Classe moyenne"],
		["Monter", "tous les besoins du niveau visé pendant quelques jours (4 à 20) et un revenu suffisant par part : eau, courant, de quoi manger, pas de dettes ; puis école, hôpital, égouts, internet, vêtements ; puis trajets courts, loisirs, calme, police, logement agréable ; enfin électronique et meubles, quartier recherché, beau logement"],
		["Redescendre", "un besoin du niveau qui manque pendant 10 jours (coupure, rayon vide, chômage, dettes…) fait perdre un niveau"],
		["Effets", "plus un foyer est aisé, plus il paie de taxe foncière (×0,6 à ×1,7), plus il achète dans les commerces et dépense en sorties ; dès Aisé, son épargne lui rapporte des intérêts ; il déménage vers un logement plus cossu quand le sien le bloque"],
		["Carte", "N → Habitants → Niveaux de vie : du rouge (précaire) au bleu (très aisé)"],
	]],
	["Objectifs du pays", [
		["Maj+J", "panneau Objectifs : réputation du pays (étoiles), missions en cours, rang de chaque ville, succès"],
		["Missions", "3 missions à la fois, tirées selon tes villes (faire grandir une ville, ouvrir une école, rendre une ville heureuse, faire baisser le chômage, rembourser ses emprunts, fonder une ville, relier deux villes, créer une ligne) ; chacune a un délai et une prime versée au pays"],
		["Rangs des villes", "Hameau, Village, Bourg, Ville, Grande ville, Métropole : il faut des habitants, des habitants contents et des services (école, pompiers, police, hôpital, transports, caisse saine) ; chaque rang rapporte une prime et ne se perd jamais"],
		["Réputation", "de 0 à 100 : missions, rangs et succès la montent ; missions ratées, tutelle et mairies perdues la baissent ; au-dessus de 20 les emprunts coûtent moins cher (jusqu'à −1 point)"],
		["Succès", "17 étapes à débloquer une fois pour toutes : première ville, mille habitants, pays heureux, villes reliées, mairie reprise, classe moyenne, beaux quartiers…"],
	]],
	["Statistiques et conseiller", [
		["Maj+I", "panneau Statistiques (menu Infos) : courbes dans le temps de chaque ville et du pays, sur 30 jours, 1 an ou toute la partie"],
		["Chiffres suivis", "habitants, satisfaction, chômage, caisse, solde du mois, logements et emplois libres, enfants sans école, pollution de l'air ; pour tout le pays : électricité, eau, coupures, bouchons, trajet moyen, déchets"],
		["Tableau", "chiffre du jour et évolution sur 30 jours (vert : ça s'améliore, rouge : ça se dégrade) ; clic sur une ligne pour tracer sa courbe, survol de la courbe pour lire une date"],
		["Comparer les villes", "case sous la courbe : une couleur par ville"],
		["Conseiller", "deuxième onglet : les problèmes du moment, du plus urgent au plus anodin, avec quoi faire et un bouton pour ouvrir le bon panneau ; un problème urgent qui apparaît s'affiche aussi en haut de l'écran"],
		["Relevés", "un par jour de jeu, à minuit ; les plus vieux sont regroupés par 30 jours, ils restent dans la sauvegarde"],
	]],
	["Tutoriel et objectifs à l'écran", [
		["Tutoriel guidé", "case sur le globe (cochée par défaut) : une étape à la fois en haut à gauche (caméra, fonder le village, fondateurs, route, logements, courant et eau, temps, emplois, école, budget, objectifs) ; chaque étape se valide toute seule quand tu l'as faite"],
		["Bouton de l'étape · Passer · croix", "le bouton fait le premier geste à ta place (ouvrir le bon panneau, prendre l'outil) ; Passer saute l'étape ; la croix arrête le tutoriel"],
		["F10 → Aide", "relancer le tutoriel (il reprend à la première étape pas faite) ou masquer les objectifs à l'écran"],
		["Objectifs à l'écran", "sous le tutoriel : rang de la ville gérée et ce qui manque pour monter, missions du pays avec leur progrès, les jours restants et la prime ; clic sur « Objectifs » : panneau Maj+J ; ▾ replie"],
	]],
	["Budget de la commune", [
		["M", "panneau Budget : bilan du mois, impôts votés par le maire, emprunts, entretien et état des voies"],
		["Impôts", "taxe foncière, impôt des entreprises, impôt sur les bénéfices de 0 à 200 % : plus haut, la caisse se remplit et les habitants râlent"],
		["Emprunts", "de 100 k€ à 20 M€ sur 5 à 30 ans ; le taux monte avec la dette, plafond de 8 ans de recettes, remboursement anticipé possible"],
		["Tutelle", "caisse dans le rouge 90 jours : le préfet relève les impôts à 150 %, bloque emprunts et bâtiments publics jusqu'à 30 jours sans dette"],
		["Usure", "routes, rails, chemins et voies d'eau s'usent avec l'âge et le trafic (camions surtout) ; sous 50 % : nids-de-poule et véhicules ralentis ; à 0 % : voie fermée"],
		["Entretien", "budget courant par réseau, réparation automatique sous un seuil, carte de l'état (vert → rouge), « Voir » et « Réparer » sur les pires tronçons ; vitesse d'usure dans l'Admin (F10)"],
	]],
	["Transports publics", [
		["L", "panneau Lignes : arrêts, stations de métro, gares, ports, aéroports, dépôts de marchandises, parkings et lignes (case Fret pour les trains et les bateaux)"],
	]],
	["Habitants", [
		["H", "panneau Habitants : la ville en chiffres, la liste des habitants, le budget de la ville"],
		["Clic sur un bâtiment (outil 1)", "fiche du bâtiment : logements, employés, élèves, qui y vit et qui s'y trouve en ce moment"],
		["Clic sur un nom", "profil : âge, foyer, travail ou école, loisirs, budget et journée heure par heure"],
		["Vitesse de la vie", "réglage du panneau : 1 an de vie = 1 mois de jeu par défaut, ou très rapide (1 an = 1 jour), ou réaliste"],
		["Fiche d'un habitant", "sa vie en frise et son CV (écoles, diplômes, emplois, couple, enfants, santé, médailles), sa famille cliquable, même après sa mort"],
		["☆ Suivre (fiche d'un habitant)", "suivre un habitant façon Sims : repère au-dessus de lui, caméra qui l'accompagne, nouvelles de sa vie"],
		["F", "habitant suivi : la caméra le suit ou reste libre (bouger la caméra la libère aussi)"],
		["Clic sur un passant", "les habitants près de la caméra marchent, roulent ou pédalent vers leur travail, l'école, le sport : un clic ouvre sa fiche"],
		["Donner un ordre (fiche)", "sa journée (aller à…, rentrer, travail, loisir, courses, visite, dormir) ou ses choix de vie (emploi, déménagement, rencontre, mariage, enfant, séparation, retraite) ; Échap annule « Aller à… »"],
		["Ton personnage", "il naît dans une famille de ta ville ; une carte te demande ses grands choix (couple, mariage, enfants, études, emploi, retraite), le temps se met en pause"],
		["Prendre sa place (fiche)", "incarner l'habitant en vue au sol (3e personne) ; V pour revenir, il reprend sa journée"],
	]],
	["Métiers", [
		["K", "vue métiers : zoome près d'un commerce, d'une école, d'un hôpital… il s'ouvre en coupe et on voit les employés à leur poste (le boulanger pétrit, le prof écrit au tableau, le médecin ausculte) ; K la coupe, K la remet"],
		["Maj + K", "ouvrir les bâtiments en coupe quand on zoome, ou non (les employés d'extérieur restent visibles)"],
		["Dehors", "agriculteurs aux champs, bûcherons, carriers, pêcheurs, marchands, policiers de garde, pompiers près de leur camion"],
		["Ouvert / Fermé", "enseigne sur la façade et rideau de fer selon le personnel présent ; pancarte orange « Manque de personnel », rouge « Fermé : pas d'enseignant »…"],
		["Sans personnel", "école fermée : les élèves restent à la maison ; commerce fermé : les clients vont ailleurs ; hôpital fermé : la santé baisse ; production selon les postes pourvus"],
		["Clic sur un employé", "sa fiche : ce qu'il fait en ce moment, et le personnel du bâtiment"],
	]],
	["Production", [
		["P", "panneau Production : carte des ressources, marchandises de la ville, sites (stock et caisse de chaque entreprise), camions de livraison"],
		["Construire → Production", "fermes (céréales, légumes, betteraves, lin, lait, élevage), forêt, pêche, carrière, sablière et gravière, argilière, mine à ciel ouvert, mine souterraine, mine de sel, puits ; usines (moulin, laiterie, sucrerie, agroalimentaire, brasserie, verrerie, papeterie, chimie, textile, hygiène, pharmacie, électronique, automobile…) ; entreprise de transport routier"],
		["Livraisons", "chaque site a son stock ; des camions conduits par des chauffeurs-livreurs (lundi-vendredi) livrent le plus proche qui en a besoin. Sans chauffeur ou sans route : rayons vides et habitants mécontents. Les entrepôts servent de relais ; le reste vient par import (route qui sort de la carte, dépôt, gare, port)"],
		["Survol d'une case", "les ressources les plus riches de la case s'affichent dans la fiche du terrain"],
		["Règles", "il faut des habitants pour les emplois, une voie d'accès, des commerces pour vendre, un dépôt, une gare ou un port pour exporter"],
		["Carrières et mines", "le périmètre d'extraction se pose tout seul à côté des installations ; chaque tonne creuse la fosse en gradins et les stériles montent en verse (terril pour une mine souterraine). La réserve est la roche du périmètre"],
		["P → Mines", "état des fosses (profondeur, gradins, réserve, années restantes), « Nouveau périmètre » (glisser un rectangle), sondage (15 000 €, deux jours : richesse exacte), réaménagement : plan d'eau, remblai ou fosse laissée"],
		["Vie du site", "pelle et tombereaux de 7 h à 17 h en semaine, tir de mine à midi dans les carrières de roche et les mines à ciel ouvert"],
		["Maj+F", "Agriculture : choisir une ferme, « Préparer la ferme », tracer des champs (culture au choix), acheter ou louer des machines, acheter des bêtes ; les ouvriers labourent, sèment et moissonnent selon la saison"],
		["Repas", "les habitants mangent chaque jour dans les commerces ; s'ils manquent de nourriture : santé et satisfaction baissent, puis ils déménagent (Admin : faim aucune, normale ou mortelle)"],
	]],
	["Décors", [
		["G", "panneau Décors : 160 modèles (bancs, lampadaires, fontaines, statues, clôtures, panneaux, marché, jeux, plage, ferme, animaux, bateaux, rochers)"],
		["Poser", "clic : un décor ; glisser : une rangée, ou une clôture d'un point à l'autre ; R / Maj+R : tourner"],
		["Pinceau, Gomme", "semer au hasard (troupeau, bottes de foin, rochers) ; la gomme efface aussi les décors automatiques"],
		["Automatiques", "bancs et poteaux le long des routes, pontons et bateaux près de vos bâtiments, rochers et canards sauvages ; ailleurs la Terre reste vierge (case à cocher du panneau)"],
	]],
	["Réseaux (électricité, eau, égouts, chauffage)", [
		["O", "panneau Réseaux : production et demande, sources, bâtiments coupés, comptes ; ses onglets allument le calque du réseau (pastille verte, orange ou rouge sur chaque bâtiment)"],
		["Construire > Réseaux", "centrales (charbon, gaz, bois, nucléaire, barrage, éolienne, solaire, réseau national posable partout), batteries (gardent le surplus pour la nuit et les jours sans vent), captage et forage d'eau, château d'eau, station d'épuration, lagunage, rejet direct"],
		["Routes", "chaque route porte la desserte locale : un bâtiment à moins de 30 m d'une route reliée à une source est desservi"],
		["Panneau O > ligne HT, MT, conduite, collecteur", "clic pour chaque point, clic droit ou Échap pour finir ; le tronçon a son chantier avant d'être en service"],
		["Panneau O > Retirer", "clic sur un tronçon pour l'enlever (30 % rendus)"],
		["Chauffage", "poste de gaz, chaufferie bois, géothermie et conduites de gaz : la demande suit le froid ; sans gaz, on se chauffe à l'électricité (pointe d'hiver), sans les deux on a froid"],
		["Pannes", "les tronçons s'usent (réglage Admin « usure »), cassent plus souvent, et les orages abattent les lignes ; fuites et transformateurs grillés dans les rues ; une équipe répare en quelques heures (bouton « Vite » : le double du prix) ; « Rénover » remet un tronçon usé à neuf"],
		["Crises", "canicule (30 °C) : clim et soif font grimper la demande ; sécheresse (plus de 12 jours sans pluie) : rivières et nappes baissent ; onglet Eau : restrictions d'eau (−20 %)"],
	]],
	["Urgences", [
		["U", "panneau Urgences : appels en cours (clic : y aller), casernes et véhicules, bilan des temps d'intervention, carte de couverture"],
		["Construire → Services", "caserne de pompiers (FPT, VSAV, grande échelle), commissariat (police, ou gendarmerie dans une ville de moins de 2 000 habitants), hôpital (ambulances, SMUR)"],
		["Sur la route", "gyrophares et sirène deux-tons : ils passent les feux au ralenti, les autres se rangent à droite, ils doublent par la voie d'en face quand elle est libre"],
		["Équipages", "un véhicule ne part que si son équipage est de garde aujourd'hui (employés du bâtiment) ; l'ambulance passe par l'hôpital avant de rentrer"],
		["Appel d'essai ici", "bouton du panneau : un appel au hasard près de la caméra, pour voir partir les secours"],
	]],
	["Avis et élections", [
		["Y, ou clic sur la satisfaction", "panneau Avis : satisfaction moyenne et sa courbe, note de chaque thème (emploi, logement, écoles et santé, environnement, transports, impôts, réseaux…) et ce qui pèse le plus"],
		["Quartiers", "satisfaction par quartier, carte de couleur au-dessus des logements (rouge mécontent, vert content), aussi dans le panneau Cartes (N)"],
		["Paroles", "ce que disent quelques habitants, les plus mécontents d'abord (clic : leur fiche)"],
		["Élections", "maire dès 30 habitants, municipales tous les 6 ans de vie des habitants (dimanche, résultats à 20 h, 2e tour si besoin) ; pendant la campagne, choisis jusqu'à 3 promesses ; « Élections anticipées » pour voter le dimanche suivant"],
		["Manifs", "sous 35 / 100 sur un thème, un cortège marche jusqu'à la mairie : négocier (argent), ignorer (grève la 2e fois) ou police (s'il y a un commissariat)"],
		["Admin (F10) → Événements", "élections : aucune, défaite sans effet, objectifs imposés ou fin de partie ; manifestations oui / non"],
	]],
	["Trafic", [
		["Maj+L", "panneau Trafic (bouton Trafic de la barre du bas) : comment les habitants se déplacent, temps perdu dans les bouchons et pour se garer, routes saturées, parkings, remplissage des lignes"],
		["Bouchons", "chaque rue a une capacité (voies × débit de sa classe) ; plus elle est chargée à l'heure de pointe, plus on y roule lentement, et les habitants changent de route ou prennent le bus, le vélo"],
		["Carte du trafic", "bouton du panneau : routes colorées du vert (fluide) au rouge (bouché), maintenant ou à l'heure de pointe ; parkings colorés selon leur remplissage"],
		["Stationnement", "places privées des entreprises, puis le long des rues et dans les parkings (Lignes > Parking) ; sans place, on tourne et on marche ; tarif réglable par parking"],
		["Lignes", "chaque bus, tram ou métro a ses places ; plein, on attend le suivant ; ticket réglable par ligne (1,50 € par défaut, gratuit pour les moins de 18 ans)"],
		["Voie de bus", "Choisir une route > Voie de bus : bus et trams y passent les bouchons, les voitures perdent une voie ; Fermer à la circulation coupe la route"],
	]],
	["Services publics", [
		["Maj + U", "panneau Services publics : écoles, hôpitaux, police ; habitants bien couverts, loin, saturés ou sans service ; places, lits et agents de chaque bâtiment (clic : y aller)"],
		["Voir la couverture", "bouton du panneau (ou panneau Cartes) : chaque logement en couleur, vert bien couvert, jaune loin, orange saturé, rouge rien ; les services en bleu"],
		["Distance", "temps de trajet par les routes et chemins : école 15 min (maternelle, élémentaire), 25 min (collège), 40 min (lycée), à pied ou en car ; hôpital 30 min en voiture ; police 10 min d'intervention. Au double, plus de couverture"],
		["Places", "école : pupitres ; hôpital : 3 lits pour 1 000 habitants ; police : 1 agent pour 400 habitants. Sans personnel embauché, le service ne couvre rien"],
		["Conséquences", "santé et espérance de vie (hôpital), satisfaction des habitants, petits délits (cambriolages) dans les quartiers sans police"],
	]],
	["Internet et téléphone", [
		["Maj + O", "panneau Internet et téléphone (aussi en onglet « Télécom » du panneau Réseaux, O) : outils des câbles, calques, bâtiment survolé, bilan"],
		["Construire → Services", "pylône 2G (7 km), pylône 4G (2,5 km), pylône 4G + 5G, petite antenne 5G (450 m), central téléphonique, nœud de la fibre"],
		["Cuivre", "toutes les routes reliées à un central portent le téléphone et l'ADSL : 20 Mb/s près du central, de moins en moins jusqu'à 5 km"],
		["Fibrer une rue", "clic sur une route : la fibre (1 Gb/s) suit toute la rue ; elle doit toucher un central ou un nœud optique"],
		["Fibre ou téléphone sur poteaux", "un clic par point, Échap ou clic droit pour finir : pour les fermes et hameaux loin des routes"],
		["Calques", "couverture mobile (disques 2G, 4G, 5G) ou débit de chaque bâtiment (fibre, ADSL, box 4G / 5G, lent, rien)"],
		["Conséquences", "sans internet ni réseau mobile, les habitants sont moins satisfaits et les entreprises produisent moins (bureaux surtout) ; une antenne trop chargée sature. Réglage Admin (F10) pour couper"],
	]],
	["Parc de loisirs", [
		["Maj + G", "panneau du parc : note en étoiles, visiteurs, prix de l'entrée et des tours, recettes, attractions (files, fiabilité, pannes), ce que disent les visiteurs, conseils"],
		["Construire → Parc de loisirs", "l'Entrée du parc (au bord d'une route) fonde le parc ; attractions, stands, toilettes, aires de repos et atelier se posent à moins de 250 m derrière elle, sans route"],
		["Visiteurs", "habitants de la ville et touristes (selon l'attrait des manèges, la note et la route) ; plus nombreux le week-end, le mercredi et l'été, moins sous la pluie"],
		["Entretien", "les manèges s'usent et tombent en panne ; l'atelier d'entretien révise, répare et ramasse les papiers (sans lui, un dépanneur extérieur, lent et cher)"],
	]],
	["Déchets", [
		["X", "panneau Déchets : ce que la ville jette et recycle, poubelles qui débordent (clic : y aller), installations, bennes en tournée"],
		["Construire → Déchets", "dépôt de collecte (4 bennes), déchèterie, centre de tri, usine de recyclage, compost, décharge, incinérateur (électricité)"],
		["Bacs", "chaque logement, commerce et entreprise remplit ses bacs (1,4 kg par habitant et par jour) ; plein, il déborde : sacs sur le trottoir, habitants mécontents, rue sale"],
		["Tournées", "les bennes partent du dépôt de 5 h à 12 h (lundi-samedi) avec 3 éboueurs de service, vident les bacs porte à porte puis déchargent à l'usine"],
		["Tri", "sans centre de tri personne ne trie ; avec lui, recyclables et verre partent en balles et en calcin vers l'usine de recyclage et les usines (verrerie, brasserie…)"],
		["Décharge pleine", "bouton « Recouvrir » du panneau : elle devient une colline verte et pollue beaucoup moins"],
		["Admin (F10)", "déchets oui/non, quantité par habitant ×0,5 à ×3"],
	]],
	["Obsèques et cimetières", [
		["H → Funéraire", "décès, obsèques en cours et à venir, défunts qui attendent une place, places libres de chaque cimetière, corbillards"],
		["Construire → Funéraire", "pompes funèbres (2 corbillards), cimetière de village, communal, paysager, militaire, d'Asie, musulman, juif, columbarium, crématorium"],
		["Obsèques", "1 à 3 jours après le décès, du lundi au samedi : le corbillard prend le défunt chez lui ou à l'hôpital, passe au lieu de culte, puis va au cimetière ou au crématorium ; la famille suit en voiture"],
		["Cimetière", "les proches se rassemblent autour de la fosse, puis la pierre tombale apparaît, fleurie quelques semaines ; clic sur une tombe : la fiche du défunt"],
		["Plus de place", "le défunt attend à la chambre funéraire, puis il est enterré dans une commune voisine : plus cher, et la famille est mécontente"],
		["Argent", "la famille paie les obsèques (≈ 3 800 €) ; la commune encaisse les concessions de 30 ans et la redevance du crématorium, et paie l'entretien"],
		["Admin (F10)", "obsèques oui/non, part des crémations (selon la région de chacun, ou de 10 à 95 %)"],
	]],
	["Pollution, bruit et valeur", [
		["N", "panneau Cartes : air, eau, bruit le jour et la nuit, valeur du terrain, loyers (une carte à la fois, et celles des autres systèmes)"],
		["Survol d'une case", "air et eau pollués (%), bruit (dB, jour et nuit) et prix du terrain (€/m²) dans la fiche du terrain"],
		["Effets", "la pollution rend malade, le bruit et les odeurs fâchent les habitants ; arbres et parcs protègent. Le terrain prend de la valeur près des parcs, de l'eau, des commerces et des transports, en perd près des usines et des grandes routes"],
		["Loyers", "ils suivent la valeur du quartier peu à peu, comme la taxe foncière ; un foyer au loyer trop cher déménage, les quartiers chers font pousser les bâtiments chics (zonage)"],
	]],
	["Temps et vue", [
		["T", "mettre le temps en pause / reprendre"],
		["Maj + T", "vitesse suivante du temps : par défaut 1 jour de jeu par minute ; plus lent pour regarder la ville vivre (la marée suit l'heure et la Lune : voir la barre d'état)"],
		["Ctrl + T, ou clic sur le Soleil de l'horloge", "jour permanent : l'image reste de jour pour construire, l'heure, les habitants et la production continuent (automatique quand Construire ou l'éditeur libre est ouvert)"],
		["V", "vue suivante : dessus, 3e personne, 1re personne"],
		["ZQSD, Maj, Espace", "marcher, courir, sauter (vue au sol)"],
		["E ou clic gauche", "ouvrir ou fermer une porte, une porte de garage (vue au sol), y compris dans les murs fins"],
		["Échap", "libérer la souris (vue au sol)"],
	]],
	["À bord des véhicules", [
		["E près d'un véhicule", "monter à bord (vue au sol) : voitures, bus, cars, trams, trains, métros, camions, bennes, corbillards, secours, bateaux, avions, tracteurs et machines agricoles, engins de chantier"],
		["Maj + V", "monter dans le véhicule le plus proche du centre de la vue, depuis n'importe quelle vue ; à bord, revenir à la vue de dessus"],
		["E à bord", "descendre (pas en plein vol ni en pleine mer : attendre l'atterrissage ou le port)"],
		["Maj + E à bord", "sauter dans le véhicule voisin le plus proche (moins de 40 m)"],
		["V à bord", "caméra extérieure (souris pour tourner autour, molette pour reculer) ou place du conducteur"],
		["Conduite", "pour l'instant le véhicule roule tout seul : il suit sa ligne, sa tournée, sa mission ou un trajet au hasard ; le bandeau indique la vitesse, la ligne et le prochain arrêt"],
	]],
	["Partie (barre du haut)", [
		["Loupe", "aller à des coordonnées ou à un lieu connu, infos techniques (tuiles, marée)"],
		["Chiffres", "caisse, habitants, satisfaction, chômage : un clic ouvre le panneau Habitants (la satisfaction : le panneau Avis)"],
		["… (horloge)", "lever et coucher du Soleil, Lune, curseur de l'heure, mois précédent ou suivant, météo"],
		["F5", "sauvegarder la partie"],
		["F9", "recharger la partie en cours"],
		["Charger", "liste des parties : charger, supprimer, sauvegarder sous un autre nom"],
		["Globe", "revenir au globe pour changer de lieu"],
		["F10 ou icône réglages", "panneau Admin : argent de départ, caisse, argent illimité, coût des constructions, accès à une voie, impôts, salaires, vitesses, épuisement des ressources, déblocage des bâtiments, pollution (seulement pour l'admin de la partie)"],
		["F1", "afficher ou masquer cette aide"],
	]],
]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.11, 0.13, 0.96)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var title := Label.new()
	title.text = "Commandes de MiniBlocs"
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := Button.new()
	close.text = "Fermer (F1 ou Échap)"
	close.pressed.connect(close_panel)
	head.add_child(close)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 28)
	v.add_child(cols)
	# Trois colonnes : barre du bas · construire, lignes, habitants · caméra, temps, partie.
	const COLUMN_OF := [2, 0, 1, 1, 1, 2, 2]
	var columns: Array[VBoxContainer] = []
	for c in 3:
		var vb := VBoxContainer.new()
		cols.add_child(vb)
		columns.append(vb)
	for i in SECTIONS.size():
		var sec: Array = SECTIONS[i]
		var col := columns[COLUMN_OF[mini(i, COLUMN_OF.size() - 1)]]
		var h := Label.new()
		h.text = sec[0]
		h.add_theme_font_size_override("font_size", 16)
		h.add_theme_color_override("font_color", Color("ffd166"))
		col.add_child(h)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 14)
		col.add_child(grid)
		for row in sec[1]:
			var k := Label.new()
			k.text = row[0]
			k.add_theme_color_override("font_color", Color("d8f3dc"))
			k.add_theme_font_size_override("font_size", 13)
			grid.add_child(k)
			var d := Label.new()
			d.text = row[1]
			d.add_theme_font_size_override("font_size", 13)
			d.custom_minimum_size = Vector2(250, 0)
			d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			grid.add_child(d)
		col.add_child(Control.new())
	var credit := Label.new()
	credit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	credit.custom_minimum_size = Vector2(1200, 0)
	credit.text = "Relief : Mapzen Terrain Tiles (AWS Open Data) — SRTM, GMTED, ETOPO1, EU-DEM · Biomes : © ESA WorldCover 2021, données Copernicus Sentinel (CC BY 4.0) · Rivières : © contributeurs OpenStreetMap (ODbL), sinon calculées sur le relief"
	credit.add_theme_font_size_override("font_size", 11)
	credit.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	v.add_child(credit)


func close_panel() -> void:
	closed.emit()
	queue_free()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and (k.keycode == KEY_ESCAPE or k.keycode == KEY_F1):
		get_viewport().set_input_as_handled()
		close_panel()
