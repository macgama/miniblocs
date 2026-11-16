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
	["Manette et Steam Deck", [
		["Stick gauche · Ⓐ", "curseur et clic (maintenir Ⓐ pour glisser : tracer, peindre) ; au bord de l'écran, la caméra suit"],
		["Stick droit · LB / RB · LT / RT", "déplacer, tourner, zoomer la caméra"],
		["Croix", "↑ ↓ incliner, ← → outil précédent / suivant ; dans un menu, passer d'un bouton à l'autre"],
		["Ⓑ · ☰ · ⧉", "annuler (Échap) · menu pause · Gérer / Créer (Tab)"],
		["Ⓧ · Ⓨ", "tourner le bâtiment (R) · vue au sol (V)"],
		["F6", "succès : toutes tes médailles, débloquées ou non (aussi dans le menu Infos et le menu principal)"],
	]],
	["Barre du bas", [
		["Tab · Gérer / Créer", "Gérer : la ville (terrain, voies, zonage, catalogue, lignes, habitants). Créer : construire un bâtiment soi-même (murs et étages, blocs, intérieur, Mes créations, banque, atelier, partage), la ville en pause ; touches 1 à 8 et échelle des étages"],
		["Catégories", "Observer, Terrain, Voies, Paysage : un clic ouvre leurs outils juste au-dessus ; Construire et Décors ouvrent leur panneau à droite (un seul à la fois)"],
		["Menus ▴", "Transports (lignes, trafic, circulation, véhicules), Ville (habitants, urgences, avis, budget, déchets), Économie (production, agriculture), Loisirs (créer un parc, panneau du parc, musée, zoo, spectacles, club, tourisme, patrimoine), Infos (infos, cartes) : un clic ouvre la rangée de leurs panneaux ; les touches restent les mêmes"],
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
		["R (éditeur libre)", "tourner la forme d'un quart de tour (escalier, pente, arrondi, porte, fenêtre…) ; sans rien toucher, elle se tourne face à la caméra"],
		["F · C (éditeur libre, Blocs)", "F renverse la forme tête en bas, C la couche sur le côté (R choisit alors le côté) ; aussi en boutons « Orientation » du panneau ; l'orientation choisie s'affiche dans la barre du bas"],
		["Enregistrer + clic glissé", "éditeur libre : ta construction devient un bâtiment de « Mes créations »"],
		["Murs et étages (éditeur libre)", "murs de 20 cm posés sur les lignes de la grille, pièces, sols, escaliers, portes et fenêtres, peinture d'un côté de mur ou de toute une pièce"],
		["Page haut / Page bas, ou l'échelle des étages", "étage actif (jusqu'à 59 étages et 20 sous-sols, 60 m sous terre pour un bunker ; le terrain est creusé) ; les étages du dessus sont masqués pendant l'édition"],
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
		["Page bas sous le rez-de-chaussée (ou Infos → Vue sous terre)", "vue sous terre : Sous-sol −1 à −20 (3 m par niveau). Réseaux sous les rues (vert télécoms, rouge électricité, jaune gaz, bleu eau, marron égouts ; gris : pas alimenté), gros tronçons enterrés, branchements des bâtiments, tunnels, métro et stations, caves, parkings et sous-sols de l'Atelier. Page haut remonte, Origine ou Échap revient à la surface"],
		["Construire sous terre (barre de la vue sous terre)", "au niveau affiché : poser une conduite d'eau, un égout, du gaz ou de la fibre (plus profond = plus cher : tranchée, tranchée blindée, microtunnelier) ; creuser un métro ou un tunnel routier (à partir du −3, rampe automatique vers la surface) ; creuser une cave, un parking, un entrepôt, un local technique ou un bunker sur 1 à 3 niveaux, puis l'aménager avec les murs, portes et escaliers de l'Atelier ; Déplacer une conduite (elle reste en service pendant les travaux) ; Supprimer. Tout se construit en chantier, payé au fil des travaux"],
		["Banque (6) · Atelier (7)", "tes modèles étiquetés (type, style, époque, couleur) à reposer ou échanger ; l'atelier : terrain plat sans habitants ni argent"],
		["Fonction d'un modèle (Banque, Mes créations)", "le bâtiment du jeu dont ton modèle prend le rôle : maison, centrale électrique, stade, piscine, grand-huit… Il fonctionne comme lui (capacités à sa taille) avec ton apparence"],
		["Mes modèles (Construire, B)", "tes modèles et créations se posent comme les autres bâtiments : prix, R pour tourner, accès à une route, chantier ; chantier fini, ses vrais murs, pièces et meubles sont posés : il se visite (V)"],
		["Chantiers", "bâtiments et voies se construisent étape par étape au rythme de la vie (maison ≈ 3 semaines de jeu), en semaine et en journée ; le prix se paie au fil des travaux ; panneau Admin (F10) : horaires des équipes ou construction instantanée"],
	]],
	["Époques", [
		["Année de départ", "globe, Réglages de la partie (ou Admin F10), section Époque : partie historique de 1800 à aujourd'hui ; chaque invention arrive à sa date (train 1830, électricité 1882, autoroute 1930, 4G 2010…)"],
		["Pas encore inventé", "vignette « Arrive en 1882 » dans Construire ; voies, stations, lignes électriques, fibre et matériaux de l'Atelier suivent aussi l'année"],
		["Services d'époque", "maison d'école, Hôtel-Dieu, remise des pompes, gendarmerie ; pompes à bras, ambulances et corbillards à chevaux, tombereaux, rues pavées et réverbères"],
		["Rythme de l'histoire", "Admin (F10) : 1 à 25 années d'histoire par année de jeu, ou changer l'année en cours ; les habitants n'attendent le courant qu'en 1925, l'eau courante en 1900, le téléphone en 1975"],
	]],
	["Événements", [
		["I", "panneau Infos : événements en cours et à venir, journal, organiser une fête ou un marché, dégâts à réparer, stades et classement"],
		["Fil d'actualité (haut de l'écran)", "clic sur une nouvelle pour aller sur place"],
		["Incendie, tempête, épidémie à la main", "panneau Infos, onglet Organiser, puis clic sur la carte (Échap pour annuler)"],
		["Catastrophes", "panneau Admin (F10), section Événements : les couper ou régler leur fréquence"],
	]],
	["Saisons et risques naturels", [
		["Maj+R", "panneau Saisons et risques (menu Infos) : saison, prévisions (3 jours, 7 avec une station météo), records ; vigilances neige, crues, sécheresse, canicule ; déneigement ; calendrier des cultures"],
		["Neige", "elle tient sur les routes et ralentit tout le monde (secours compris), avec des accidents ; le Centre technique municipal (Construire → Services publics) envoie ses chasse-neige, les grands axes d'abord, et sale : 12 h sans neige qui tient"],
		["Crues", "plusieurs jours de grosses pluies ou une fonte rapide des neiges : la rivière monte pendant des heures, routes coupées, maisons et champs inondés ; un bassin de rétention fait monter l'eau 25 % moins haut à 3 km"],
		["Sécheresse", "vigilance, alerte (restrictions d'eau imposées), alerte renforcée (feux de broussailles au bord des bois), crise ; les cultures et les prés souffrent"],
		["Canicule, gel", "3 jours à 33 °C et plus : canicule ; gelée tardive au printemps : jeunes pousses abîmées"],
		["Provoquer", "Maj+R, onglet Risques (ou I → Organiser) : chute de neige, crue, sécheresse, canicule, feu de broussailles ; Admin (F10) : neige sur les routes oui / non"],
	]],
	["Villages et territoire", [
		["Début de partie", "sur le globe, cherche la ville de départ ; puis choisis le nom et le drapeau du village et pose sa Maison de commune (pas besoin de route) : avant, on ne peut que regarder et modeler le paysage"],
		["Drapeau", "Maj+M, bouton Changer… à côté du drapeau d'un village : n'importe quel pays, ou aucun"],
		["Maj+M", "panneau Villages : habitants, territoire et palier de chaque village ; Aller, Renommer, Agrandir, Céder, Fusionner"],
		["Fondateurs", "100 fondateurs (réglable en F10) arrivent avec le premier village et campent près de la Maison de commune : ce sont les ouvriers des premiers chantiers. Vivres pour 90 jours, puis ravitaillement payé par la caisse ; ils emménagent dans les maisons finies"],
		["Villages neufs", "un village fondé après le premier reçoit 20 pionniers pendant 60 jours pour bâtir ses logements ; tant qu'il a moins de 150 foyers, ses zones poussent avant celles des grandes villes (maisons et petits immeubles) et son premier chantier a toujours une équipe"],
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
		["Pilote automatique", "Maj+P, bouton Activer sous une ville : chaque jour elle fait la construction la plus urgente (rue, zone résidentielle, école, aire de jeux, boulangerie, parc, pompiers, police, antenne 4G, collecte des déchets et décharge, supérette, central téléphonique, gymnase, hôpital, zone d'activités si le chômage dépasse 12 %), en gardant 3 mois de dépenses en réserve ; chaque semaine elle tient son budget à l'équilibre ; elle reçoit les manifestants si la caisse le permet"],
		["Plusieurs pays", "chaque ville appartient au pays réel où elle se trouve ; chacun de tes pays a sa caisse, son impôt national, sa dotation et sa douane (Maj+P, boutons des pays) ; un nouveau pays reçoit une aide d'installation et paie le capital de sa première ville"],
		["Commerce et douane", "les ventes des entreprises entre tes villes et entre tes pays sont comptées chaque mois (Maj+P) ; entre deux pays, l'acheteur paie la douane au pays qui importe (5 % par défaut, de 0 à 30 %)"],
		["Marché du travail", "une entreprise qui manque de monde recrute chaque jour des actifs chez les employeurs proches qui sont au complet (sauf enseignants, médecins… et ton personnage) : une usine neuve se remplit en une à deux semaines"],
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
	["Immobilier", [
		["F11", "panneau Immobilier (menu Ville) : marché de chaque ville, promoteurs et permis de construire, quartiers qui changent, bidonvilles"],
		["Prix et loyers", "chaque ville a un indice des prix : peu de logements vides et des emplois qui attirent du monde le font monter, beaucoup de logements vides le font baisser ; loyer = loyer de base × valeur du terrain × indice. Rares krachs quand les prix sont trop hauts"],
		["Règles du maire", "encadrement des loyers (aucun, souple, moyen, strict), part de logements sociaux imposée aux promoteurs (0 à 30 %), permis de construire libre, sur demande ou gelé ; des règles strictes freinent les promoteurs"],
		["Promoteurs", "Immo Prestige (résidences de standing dans les quartiers chers), Les Bâtisseurs Réunis (maisons), Béton & Fils (maison rasée pour un immeuble), Pierre & Rendement (immeuble racheté et rénové haut de gamme, loyers +30 %) ; ils bâtissent à leurs frais et la ville touche 5 % de taxe d'aménagement"],
		["Gentrification", "un secteur de 200 m dont les prix montent de plus de 12 % en six mois s'embourgeoise : ses foyers modestes ont peur d'être chassés puis partent ; un secteur qui perd plus de 12 % se paupérise. Carte : N → Immobilier → Quartiers qui changent"],
		["Bidonvilles", "une famille qui ne trouve aucun logement abordable depuis un mois, ou des travailleurs attirés par des emplois sans logement libre, bâtissent des baraques en bord de ville : pas de loyer, mais odeurs, eau polluée, terrains voisins dévalués et niveau Précaire. Viabiliser (eau, courant : niveau Modeste possible), reloger (logements à moins de 35 % des revenus, sociaux d'abord) ou raser (les familles quittent la ville et les habitants s'en souviennent)"],
		["Logements sociaux", "B → Logement, selon l'époque : cité ouvrière (1853), immeuble HBM (1894), barre HLM (1955), résidence sociale (1985). Loyer à 55 % du loyer de base ; la ville touche les loyers et paie l'entretien (budget)"],
		["Admin", "F10 → Immobilier : couper le marché vivant (promoteurs, gentrification) ou les bidonvilles"],
	]],
	["Objectifs du pays", [
		["Maj+J", "panneau Objectifs : réputation du pays (étoiles), missions en cours, rang de chaque ville, succès"],
		["Missions", "3 missions à la fois, tirées selon tes villes (faire grandir une ville, ouvrir une école, rendre une ville heureuse, faire baisser le chômage, rembourser ses emprunts, fonder une ville, relier deux villes, créer une ligne) ; chacune a un délai et une prime versée au pays"],
		["Rangs des villes", "Hameau, Village, Bourg, Ville, Ville moyenne, Grande ville, Métropole : il faut des habitants, des habitants contents et des services (école, pompiers, police, hôpital, transports, caisse saine) ; chaque rang rapporte une prime et ne se perd jamais"],
		["Réputation", "de 0 à 100 : missions, rangs et succès la montent ; missions ratées, tutelle et mairies perdues la baissent ; au-dessus de 20 les emprunts coûtent moins cher (jusqu'à −1 point)"],
		["Défi du jour", "un petit objectif qui change chaque jour (vraie date), le même pour tous : sa prime grandit avec ta série de jours réussis d'affilée (jusqu'à ×2)"],
		["Succès", "18 étapes à débloquer une fois pour toutes : première ville, mille habitants, pays heureux, villes reliées, mairie reprise, classe moyenne, beaux quartiers…"],
	]],
	["Statistiques et conseiller", [
		["Maj+I", "panneau Statistiques (menu Infos) : courbes dans le temps de chaque ville et du pays, sur 30 jours, 1 an ou toute la partie"],
		["Chiffres suivis", "habitants, satisfaction, chômage, caisse, solde du mois, logements et emplois libres, enfants sans école, pollution de l'air ; pour tout le pays : électricité, eau, coupures, bouchons, trajet moyen, déchets"],
		["Tableau", "chiffre du jour et évolution sur 30 jours (vert : ça s'améliore, rouge : ça se dégrade) ; clic sur une ligne pour tracer sa courbe, survol de la courbe pour lire une date"],
		["Comparer les villes", "case sous la courbe : une couleur par ville"],
		["Conseiller", "deuxième onglet : les problèmes du moment, du plus urgent au plus anodin, avec quoi faire et un bouton pour ouvrir le bon panneau ; un problème urgent qui apparaît s'affiche aussi en haut de l'écran"],
		["Relevés", "un par jour de jeu, à minuit ; les plus vieux sont regroupés par 30 jours, ils restent dans la sauvegarde"],
	]],
	["Gazette de la ville", [
		["F4", "le journal du matin (menu Infos) : chaque jour de jeu, une édition qui raconte la veille avec tes vrais habitants"],
		["À la une", "le fait le plus marquant (incendie, tempête, épidémie, pont vers nulle part, village fondé, match, élections…), avec un témoin qui donne son avis ; clic sur un titre souligné : la caméra va sur place ; clic sur un nom : sa fiche"],
		["Colonne de droite", "météo de demain, chiffre du jour, micro-trottoir, sports en bref, brèves, carnet (naissances, mariages, décès), petites annonces"],
		["Époques", "le nom, la devise, le prix et le ton suivent l'année de la partie : La Gazette (1800), Le Courrier (1830), Le Petit Journal (1870), L'Écho (1914), -Matin (1945), Infos (1980), Actu (2002), .info (2015)"],
		["Archives", "flèches en haut : les 60 dernières éditions ; « Aujourd'hui » revient à la dernière"],
	]],
	["Tutoriel et objectifs à l'écran", [
		["Tutoriel guidé", "case sur le globe (cochée par défaut) : une étape à la fois en haut à gauche (caméra, fonder le village, fondateurs, route, logements, courant et eau, temps, emplois, école, budget, objectifs) ; chaque étape se valide toute seule quand tu l'as faite"],
		["Bouton de l'étape · Passer · croix", "le bouton fait le premier geste à ta place (ouvrir le bon panneau, prendre l'outil) ; Passer saute l'étape ; la croix arrête le tutoriel"],
		["Démo guidée", "bouton du menu principal : une partie d'environ 30 minutes près d'Échallens, le tutoriel puis six chapitres (vue au sol, loisirs, fête, bus, 100 habitants) et un bilan ; la partie continue après"],
		["F10 → Aide", "relancer le tutoriel (il reprend à la première étape pas faite) ou masquer les objectifs à l'écran"],
		["Objectifs à l'écran", "sous le tutoriel : rang de la ville gérée et ce qui manque pour monter, missions du pays avec leur progrès, les jours restants et la prime ; clic sur « Objectifs » : panneau Maj+J ; ▾ replie"],
	]],
	["Carte entre amis (en ligne)", [
		["Menu principal → Entre amis", "rejoindre la carte d'un ami (adresse du serveur, code d'invitation, pseudo) ou héberger une de tes parties sur ce PC"],
		["F3", "joueurs connectés et villes de chacun, code d'invitation (admin), discussion, Resynchroniser, Quitter la carte"],
		["Ta caisse", "celle de ta ville si tu en es le maire, sinon ta caisse personnelle (l'argent de départ) ; hors de tes villes, c'est toi qui paies"],
		["Admin", "le créateur de la carte : réglages (F10), vitesse du temps (T, Maj+T), nouveau code, exclure, arrêter le serveur"],
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
		["Agrandir (fiche du bâtiment)", "3 niveaux : niveau 2 = 50 % de places en plus (logements, emplois, élèves, lits, MW…), niveau 3 = le double ; un étage de plus, un vrai chantier payé au fil des travaux, le bâtiment reste ouvert"],
		["Rénover (fiche du bâtiment)", "bâtiment usé : façade et toit refaits, l'usure repart de zéro (15 % du prix)"],
		["Densification", "un bâtiment du zonage plein, dans un quartier qui prend de la valeur et une ville qui demande des logements, des commerces ou des industries, s'agrandit tout seul aux frais de ses propriétaires"],
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
	["Commerce entre villes et pays", [
		["Maj + S (Économie ▴ → Commerce)", "menu Commerce : Marché mondial (cours du jour et courbes), Offres des villes partenaires, Accords en cours, Entre tes villes et pays, Crises, Bilan"],
		["Cours mondiaux", "chaque marchandise a un cours qui bouge chaque jour ; les marchandises d'une même famille (énergie, métaux, agriculture…) bougent ensemble. Export et import au cours du jour ; sur la carte et en rayon, les prix suivent le cours à moitié"],
		["Villes partenaires", "de vraies villes voisines de ton lieu. Elles proposent d'acheter ou de vendre tant de tonnes par jour, à prix fixe, pendant 30 à 180 jours. Une mission commerciale (25 000 €) améliore la relation et fait venir deux offres"],
		["Accord d'exportation", "tes camions portent la marchandise à la frontière avant tout le reste ; il faut la produire, des chauffeurs-livreurs et une route qui sort de la carte (ou un dépôt, une gare, un port). Ce qui manque chaque jour coûte 10 % de pénalité et fâche le partenaire"],
		["Accord d'importation", "prix fixe, à l'abri des crises, et passage garanti même quand la frontière est pleine"],
		["Entre tes villes", "la ville qui achète se fournit d'abord chez celle qui vend, au prix convenu ; sur une carte entre amis, le maire de l'autre ville doit accepter. Libre-échange entre deux de tes pays : plus de douane"],
		["Crises économiques", "choc pétrolier, krach, sécheresse mondiale, pénurie de puces, boom de la construction, inflation, guerre commerciale, récolte record, ruée vers les métaux : elles montent, durent de 1 à 6 mois puis redescendent. F10 : crises oui ou non, marché calme, normal ou agité"],
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
	["Quartiers et arrêtés", [
		["Maj+Y", "panneau Quartiers (menu Ville) : les quartiers de la ville gérée, leurs habitants, leur bruit, leurs arrêtés et ce qu'ils coûtent"],
		["Nouveau quartier, Peindre", "clic ou glisser sur la carte : îlots de 50 × 50 m, pinceau de 1 à 9 × 9 îlots ; Gomme pour retirer ; clic droit ou Échap pour arrêter ; un quartier reste dans le territoire de sa ville"],
		["Arrêtés", "zone 30, rues piétonnes, poids lourds interdits, tranquillité la nuit, tri obligatoire, détecteurs de fumée, éclairage renforcé ou éteint, stationnement payant, fleurissement : une mise en place et un coût par mois selon la surface"],
		["Effets", "vitesse et itinéraires des voitures, camions, bruit le jour et la nuit, air, valeur des terrains, tri des déchets, départs de feu, recettes de stationnement, avis des habitants du quartier"],
		["Mairie perdue", "le conseil élu trace les quartiers et choisit les arrêtés selon son programme (un changement par semaine) ; le pilote automatique (Maj+P) en ajoute aussi"],
	]],
	["Trafic", [
		["Maj+L", "panneau Trafic (bouton Trafic de la barre du bas) : comment les habitants se déplacent, temps perdu dans les bouchons et pour se garer, routes saturées, parkings, remplissage des lignes"],
		["Bouchons", "chaque rue a une capacité (voies × débit de sa classe) ; plus elle est chargée à l'heure de pointe, plus on y roule lentement, et les habitants changent de route ou prennent le bus, le vélo"],
		["Carte du trafic", "bouton du panneau : routes colorées du vert (fluide) au rouge (bouché), maintenant ou à l'heure de pointe ; parkings colorés selon leur remplissage"],
		["Stationnement", "places privées des entreprises, puis le long des rues et dans les parkings (Lignes > Parking) ; sans place, on tourne et on marche ; tarif réglable par parking"],
		["Lignes", "chaque bus, tram ou métro a ses places ; plein, on attend le suivant ; ticket réglable par ligne (1,50 € par défaut, gratuit pour les moins de 18 ans)"],
		["Bilan des lignes", "panneau Lignes (L) > Bilan ▸ : voyageurs ou tonnes par jour, recettes (tickets, fret), personnel et énergie, entretien et pannes, résultat du mois ; prix du ticket réglable ici aussi"],
		["Véhicules", "achetés à la création de la ligne (prix réel selon le modèle, réglage Admin du coût), revendus selon leur âge ; ils vieillissent, coûtent plus d'entretien et tombent en panne après leur durée de vie (bus 12 ans, tram 30, train 35…) : « Renouveler les usés » ou case Automatique"],
		["Fret", "les camions, trains et bateaux de fret ne sont payés (à la tonne et au km) que pour les marchandises que les entreprises de la région expédient ou reçoivent ; sans client, ils roulent à vide"],
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
	["Musées", [
		["Maj + C", "menu Musée (barre du bas, Loisirs) : note en étoiles, visiteurs, billet, recettes, salles, œuvres, expositions, ce que disent les visiteurs, conseils"],
		["Bâtir", "12 musées prêts à poser (beaux-arts, muséum, sciences, civilisations, transports, cinéma et musique, sport, mer, préhistoire, jouet et BD, vin…) ou tes propres murs (mode Créer) ; « Faire du bâtiment visé un musée » ; matériaux de musée (parquet Versailles, marbre…)"],
		["Salles", "26 fonctions (hall, galerie de peinture, Égypte, dinosaures, transports, automobile, espace, marine, cinéma, sport, mode, musique, jouets, préhistoire, BD, gastronomie, boutique, café…) ; « Aménager » meuble la salle avec ses vitrines, socles et œuvres"],
		["Objets", "208 objets en 24 familles : œuvres d'art, antiquités, fossiles, machines, locomotive, voitures, module lunaire, galion, caméras, maillots, robes, piano, jouets, grotte peinte, planches de BD, pressoir… plus éclairage, parcours et accueil"],
		["Note", "prestige des œuvres (plus fort dans la salle de leur thème), éclairage, place, vitrines pour les objets fragiles, bancs, toilettes, billetterie, boutique, café ; une exposition temporaire attire du monde"],
		["Visiteurs", "habitants et touristes, de 10 h à 18 h (19 h l'été), fermé le lundi ; plus nombreux le week-end, le mercredi, l'été et quand il pleut ; gratuit le 1er dimanche si tu le veux"],
	]],
	["Spectacles", [
		["Maj + X", "menu Spectacles (barre du bas, Loisirs) : cinémas, salles de concert, théâtres et studios de cinéma ; onglets Mes salles, Programmer, Studios, Bâtir, Aménager l'intérieur, À l'affiche, Public"],
		["Salles meublées", "onglet Bâtir : 9 salles en murs fins prêtes à poser (cinémas, théâtre de poche, théâtre municipal, opéra, club de jazz, salle de concert, auditorium, studios de tournage) ; clic sur un terrain libre, R pour tourner"],
		["Aménager l'intérieur", "usage Cinéma, Théâtre, Salle de concert ou Studio pour un bâtiment en murs fins ; fonction des pièces ; la scène ou l'écran face aux portes, les fauteuils en rangées face à elle ; 58 objets (scène, rideaux, écrans, sono, caméras, fond vert…) ; chaque siège est une place, la billetterie est indispensable"],
		["Bâtir", "25 bâtiments (Construire → Spectacles) : cinéma d'art et d'essai, multiplexe, plein air, drive-in ; club de jazz, salle de musiques actuelles, auditorium, aréna, scène de festival ; café-théâtre, théâtre à l'italienne, scène contemporaine, grand opéra, théâtre de verdure, chapiteau ; studios et annexes"],
		["Programmer", "60 spectacles en tournée (orchestres, rock, rap, électro, chanson, Molière, Shakespeare, opéras, ballets, humour, cirque, marionnettes) avec le public et le bénéfice attendus ; ou la programmation automatique"],
		["Public", "selon la notoriété, l'âge des habitants (goûts par genre), le jour (vendredi et samedi), la saison, le prix du billet et la note de la salle ; les stars font venir la région. En plein air : fermé l'hiver, annulé sous la pluie"],
		["Argent", "billets et bar contre cachet, technique, droits d'auteur (9 %) et salaires ; au cinéma, la moitié du billet va au distributeur, ou à tes studios si c'est ton film"],
		["Studios", "produire un film : genre, budget (court métrage à superproduction), réalisateur, tête d'affiche ; un plateau par film ; décors, effets spéciaux, post-production et atelier à moins de 300 m améliorent le film ; 8 semaines en salle dans tout le pays puis les droits télé ; Bobine d'or chaque 20 mai"],
	]],
	["Club de sport", [
		["Maj + B", "menu Club de sport (barre du bas, Loisirs) : en haut le sport (Foot, Basket, Hand, Hockey, Rugby, Tennis), puis les onglets Club, Effectif, Calendrier, Classement, Transferts, Formation, Supporters, Finances"],
		["Fonder", "football et rugby : un stade ou un terrain de foot ; basket et handball : un gymnase, un terrain de basket ou une salle omnisports ; hockey : une patinoire ; tennis : des courts (Construire → Sport). Nom, couleurs ; la ville verse une subvention de départ ; chaque club a sa propre caisse"],
		["Sports", "basket (samedi soir, pas de nul, prolongation), handball (vendredi soir), hockey (septembre à mars, tirs au but), rugby (dimanche, points de bonus), tennis par équipes (poule de 8 au printemps, 4 simples et 2 doubles)"],
		["Centre de formation", "onglet Formation : école de sport, centre de formation ou académie (ces deux-là demandent le bâtiment Centre de formation) ; chaque saison, des jeunes arrivent, d'abord les enfants de la ville ; à 19 ans, ils passent pro ou partent"],
		["Supporters", "habitants supporters (surtout ceux qui pratiquent le sport) : drapeaux aux couleurs du club devant chez eux, plus contents quand le club gagne ; abonnements vendus en début de saison ; fête en ville après un titre ou une montée"],
		["Championnat", "12 clubs, 22 journées le samedi d'août à fin mai (trêve de Noël) ; Régionale → Nationale → Deuxième Ligue → Première Ligue ; les 2 premiers montent, les 2 derniers descendent"],
		["Équipe", "formation (4-4-2, 4-3-3…), tactique, entraînement (les jeunes progressent, les vétérans baissent) ; forme, fatigue, blessures ; en Régionale, des habitants fans de foot jouent bénévolement"],
		["Matchs", "à domicile, on voit le match au stade : joueurs aux couleurs du club, foule, tableau d'affichage, buts dans le fil d'actualité"],
		["Argent", "billets (prix au choix : trop cher, les tribunes se vident), buvette, boutique, sponsors, droits télé, primes de classement, ventes de joueurs ; contre salaires, staff, transferts et location du stade versée à la ville"],
		["Transferts", "marché renouvelé chaque lundi : joueurs libres ou sous contrat ; les meilleurs refusent un club trop modeste ; vendre, prolonger, mettre au repos"],
	]],
	["Parc de loisirs", [
		["Maj + G", "panneau du parc : note en étoiles, visiteurs, prix de l'entrée et des tours, recettes, attractions (files, fiabilité, pannes), ce que disent les visiteurs, conseils"],
		["Construire → Parc de loisirs", "l'Entrée du parc (au bord d'une route) fonde le parc ; attractions, stands, toilettes, aires de repos et atelier se posent à moins de 250 m derrière elle, sans route"],
		["Visiteurs", "habitants de la ville et touristes (selon l'attrait des manèges, la note et la route) ; plus nombreux le week-end, le mercredi et l'été, moins sous la pluie"],
		["Entretien", "les manèges s'usent et tombent en panne ; l'atelier d'entretien révise, répare et ramasse les papiers (sans lui, un dépanneur extérieur, lent et cher)"],
		["Maj + A", "Créer un parc (barre du bas → Loisirs) : onglets Grands-huit, Aquatiques, Manèges, Boutiques, Allées, Décors, Mes attractions"],
		["Tracer un grand-huit", "choisis un type, pose la gare (R tourne), puis ajoute les pièces une à une : droits, virages, pentes, loopings, vrilles, freins, lanceur… Chaîne de montée pour les montées ; Boucler relie la fin à la gare ; Retour arrière retire la dernière pièce"],
		["Notes du tour", "excitation, intensité, nausée (0 à 10), vitesse, forces G, apesanteur ; les erreurs (circuit pas bouclé, train qui s'arrête, arrivée trop rapide) s'affichent en rouge. Essai lance un train fantôme"],
		["Allées et files", "allées pavées, en bois, en terre ou en asphalte, tracées à la main ; une file d'attente part de l'entrée d'une attraction et les visiteurs la suivent"],
		["Mes attractions", "Enregistrer garde un tracé dans ta bibliothèque pour le reposer dans n'importe quelle partie ; 5 modèles prêts à poser"],
	]],
	["Zoo", [
		["Maj + Z (Loisirs ▴ → Zoo)", "panneau du zoo en 7 onglets : Zoo (note, visiteurs, prix, comptes, personnel, conseils), Enclos, Terrain, Animaux, Bâtiments, Visiteurs, Objets"],
		["Fonder", "poser l'Entrée du zoo au bord d'une route (onglet Bâtiments ou Construire → Zoo) ; le reste se pose à moins de 400 m"],
		["Enclos → Tracer", "clic à chaque coin, clic sur le premier point ou Entrée pour fermer, glisser pour un rectangle, Retour arrière efface le dernier coin ; 9 barrières (bois, électrique, grillage, palissade, renforcée, volière, vitre, mur, douve) : hauteur, solidité, vue et prix"],
		["Terrain", "pinceaux de sol (herbe, forêt, savane sèche, sable, roche, neige, marais), bassin d'eau, remblai, relief (Maj : lisser), arbres et arrachage ; rayon du pinceau réglable"],
		["Animaux", "34 espèces (Afrique, Asie, Europe, Amériques, Océanie, pôles, mini-ferme) : clic sur l'espèce puis dans l'enclos (Maj + clic : un groupe). Chaque espèce veut sa surface, ses sols, de l'eau, un abri, son climat, un groupe à sa taille, des jouets et du calme"],
		["Soigneurs et bâtiments", "poste de soigneurs (repas à 8 h et 15 h, nettoyage), cuisine, clinique vétérinaire, atelier (réparation des barrières), abris, belvédère, kiosque pédagogique, restaurants, toilettes"],
		["Risques", "barrière trop basse ou usée : évasions ; fauves et proies ensemble : prédation ; enclos sale ou animaux mal soignés : maladies. Naissances quand le bien-être est bon"],
		["Visiteurs", "chemins depuis l'entrée, vue sur les enclos (vitres et douves les meilleures), espèces rares et menacées : note, prestige et dons pour la conservation"],
	]],
	["Tourisme", [
		["Maj + D (Loisirs ▴ → Tourisme)", "menu Tourisme : En bref (touristes en ville, arrivées, nuitées, refus, réputation, dépenses et ce que touche la caisse, conseils), Hébergements, Attractions, Publicité, Bâtir, Avis des touristes"],
		["Pourquoi ils viennent", "l'attrait des parcs de loisirs, zoos, musées, salles de spectacle et du patrimoine (châteaux, cathédrales, temples, phares) selon leur taille et leur note, plus la variété ; l'été, le vendredi, la réputation de la ville, l'accès (gare, aéroport, port, autocars), l'office de tourisme et la publicité"],
		["Hébergements", "Construire → Hôtels et tourisme : aire de camping-cars, camping, camping-club, gîte, chambres d'hôtes, auberge de jeunesse, hôtels de 2 à 5 étoiles, résidence, village vacances (et les hôtels de la bible) ; sans lit libre, les touristes repartent ; le prix de la nuit se règle hôtel par hôtel"],
		["Séjour", "de 1 à 7 nuits (plus long au camping, en résidence, en village vacances, l'été et avec un office de tourisme) ; chaque jour, ils visitent les sites proches de leur hôtel, mangent au restaurant, font leurs courses et achètent des souvenirs"],
		["Argent", "taxe de séjour par nuit (0,50 € à 4 € selon les étoiles) et impôt sur les bénéfices des hôtels pour la ville ; camping municipal et aire de camping-cars : tout pour la ville ; repas et courses font vivre les restaurants et les commerces (qu'il faut livrer)"],
		["Réputation", "ce que pensent les touristes qui repartent : confort et prix de l'hôtel, repas trouvés, ce qu'il y avait à voir, rayons pleins, souvenirs, foule ; trop de touristes pour trop peu d'habitants agace la ville"],
		["Nature", "plages, côtes, lacs, rivières, forêts, sommets et glaciers du vrai terrain autour des villages attirent aussi (onglet Attractions) : surtout l'été, moins sous la pluie ; une route à moins de 800 m, des sentiers (outil Chemin) et les aménagements (poste de secours, base nautique, belvédère, parking de randonnée, maison de la nature) les rendent plus attirants"],
		["Autocars", "avec un parking d'autocars, les cars des voyages organisés arrivent le matin par l'entrée de la ville, déposent leur groupe au parking puis l'emmènent voir les sites"],
	]],
	["Patrimoine et grands monuments", [
		["Fin (Loisirs ▴ → Patrimoine)", "menu Patrimoine : En bref (rayonnement, monuments protégés, entretien, Journées du patrimoine, règles des abords, conseils), Grands chantiers, Classement, Bâtir un monument"],
		["Grands monuments", "Construire → Patrimoine et grands monuments : cathédrale gothique, basilique à coupole, grande mosquée, pagode, palais de verre (1851), grand opéra (1861), statue colossale (1884), tour de fer (1887), barrage (1905), gratte-ciel Art déco (1930), tour de télévision (1965), grande arche (1985), tour de 600 m (2008). Des chantiers de plusieurs années, étape par étape (le chœur, la nef, les voûtes, les tours, la flèche…), payés au fil des travaux"],
		["Souscription et mécènes", "une souscription populaire fait payer aux habitants jusqu'à 25 % du chantier ; des mécènes donnent parfois 1 à 4 % ; les curieux viennent déjà voir le chantier"],
		["Inauguration", "un grand monument fini est classé monument historique d'office et attire les touristes du monde entier (Tourisme, Maj+D)"],
		["Classement", "un édifice remarquable (église, château, théâtre, phare…), d'architecture ancienne ou vieux de plusieurs dizaines d'années peut être inscrit (intérêt 1, 15 k€) puis classé (intérêt 2, 40 k€) : attrait ×1,3 ou ×1,7"],
		["Protection", "un monument protégé ne se démolit pas et ne s'agrandit pas ; à ses abords (100 m inscrit, 200 m classé) : 45 m ou 30 m de haut au plus, pas d'usine ni de déchets"],
		["Entretien", "0,12 % (inscrit) ou 0,25 % (classé) de sa valeur par an, dont 30 % ou 50 % payés par l'État : il s'use trois fois moins vite. Sans entretien, il s'abîme et attire moins ; la restauration est aidée par l'État (25 % ou 40 %)"],
		["Journées du patrimoine", "le troisième week-end de septembre, les monuments attirent presque deux fois plus de visiteurs"],
	]],
	["Partage des créations", [
		["Maj + W (ou Créer → 8)", "menu Partage : Partager mes créations, Plans de site, Découvrir les créations des autres"],
		["Partager", "bâtiments de la Banque (façades personnalisées, murs fins meublés, musées), créations en blocs, attractions dessinées (grands-huit…), plans de site ; « Publier » (titre, description, étiquettes) ou « Fichier .mbloc » à envoyer à un ami. Une création emporte ce dont elle a besoin"],
		["Plans de site", "nom, puis « Choisir une zone sur la carte » : clic sur un coin, glisser, relâcher (400 m au plus). Le plan garde bâtiments, allées et files du parc, enclos et animaux, décors, murs fins meublés et blocs libres. « Poser » : il suit la souris, R le tourne, clic pour poser (prix, accès, chantiers comme d'habitude)"],
		["Découvrir", "« Recevoir » lit les fichiers .mbloc déposés dans le dossier d'échange ; Installer, Mettre à jour, Retirer ; filtre par sorte (bâtiment, musée, blocs, attraction, parc, zoo, quartier) et recherche"],
		["Steam Workshop", "à la sortie sur Steam, « Publier » enverra sur le Workshop et les abonnements s'installeront seuls ; d'ici là, l'atelier local et les fichiers .mbloc font la même chose"],
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
	["Son et musique", [
		["F2, ou haut-parleur de la barre du haut", "panneau Son : volumes général, musique, ambiance, effets et interface ; silences entre les morceaux ; morceau suivant ; retirer ou écouter un morceau"],
		["Ambiances", "on entend ce que regarde la caméra : oiseaux ou grillons à la campagne, rue animée en ville, voitures près des routes, chantiers en activité, pluie, vent, orage, mer ; en prenant de la hauteur, le vent couvre le reste"],
		["Musique", "elle suit l'heure de la ville : morceaux de journée, de soirée et de nuit ; un thème pour le globe"],
		["Réglages", "gardés pour toutes les parties (fichier son.cfg du joueur)"],
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
	["Mode photo et time-lapse", [
		["F8 (ou Infos → Mode photo)", "le temps se fige, l'interface disparaît, une caméra libre part de ta vue : ZQSD avancer, A / E descendre et monter, clic droit glissé regarder, molette zoomer, Maj vite, Ctrl lent"],
		["Panneau du mode photo", "heure de la lumière (temps figé), zoom, horizon penché, flou de profondeur, 12 filtres (noir et blanc, sépia, vintage, maquette…), luminosité, contraste, saturation, vignette, grain ; cadrage écran, 16:9, vertical 9:16 (TikTok), carré, 4:5, cinéma ; HD, 2K ou 4K"],
		["Espace · H · Échap ou F8", "prendre la photo (PNG sans l'interface, dans Images › MiniBlocs › Photos) · masquer le panneau · quitter"],
		["Maj + F8", "time-lapse : chaque village est filmé depuis sa fondation, une image par jour de jeu vers midi ; lecture accélérée (Espace, ← →), jusqu'à 4 caméras (vue actuelle, « Filmer ce cadrage » du mode photo), export vidéo AVI (MP4 en plus si ffmpeg est installé) ou images, avec la date, les habitants et le logo"],
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
	["Santé publique et épidémies", [
		["F7", "panneau Santé publique (menu Infos) : épidémie en cours, hygiène des logements (eau potable, égouts), lits d'hôpital, conseils ; onglets Vaccins, Mesures et Histoire"],
		["Maladies de l'eau", "choléra et typhoïde passent par les puits souillés et l'eau mal traitée : des égouts, une station d'épuration et de l'eau potable les arrêtent ; en urgence, faire bouillir l'eau"],
		["Vaccins", "datés (variole 1800, diphtérie 1923, grippe 1945, polio 1955, rougeole 1963, Covid-19 2021) : campagne payée à la dose ou obligation ; une partie des habitants refuse ; au-delà de 90 % de vaccinés, la maladie ne prend plus"],
		["Mesures", "quarantaine, écoles fermées, lazaret, campagne d'hygiène (1847), eau bouillie (1854), chlore dans l'eau (1902), masques et confinement (1918) : coût par jour, satisfaction ; levées seules une semaine après l'épidémie"],
		["Grandes épidémies", "partie commencée dans le passé : choléra de 1832, 1849, 1854…, variole de 1870, grippe espagnole de 1918, grippes de 1957 et 1968, Covid-19 en 2020 ; une rumeur arrive d'abord dans la gazette (F7 → Histoire pour couper le calendrier)"],
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
	# Défile quand les trois colonnes dépassent l'écran.
	v.add_child(UiStyle.scroll_fit(cols, panel))
	# Trois colonnes : barre du bas · construire, lignes, habitants · caméra, temps, partie.
	const COLUMN_OF := [2, 0, 1, 1, 1, 2, 2]
	var columns: Array[VBoxContainer] = []
	for c in 3:
		var vb := VBoxContainer.new()
		cols.add_child(vb)
		columns.append(vb)
	# Les sections suivantes vont dans la colonne la moins remplie (en lignes).
	var rows := [0, 0, 0]
	for i in SECTIONS.size():
		var sec: Array = SECTIONS[i]
		var ci: int = COLUMN_OF[i] if i < COLUMN_OF.size() else rows.find(rows.min())
		rows[ci] += sec[1].size() + 2
		var col := columns[ci]
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
			# Touches longues sur deux lignes : les trois colonnes tiennent en largeur.
			k.custom_minimum_size = Vector2(140, 0)
			k.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
