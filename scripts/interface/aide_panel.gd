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
		["Catégories", "Observer, Terrain, Voies, Paysage : un clic ouvre leurs outils juste au-dessus ; Construire, Lignes, Habitants ouvrent leur panneau à droite (un seul à la fois)"],
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
		["Construire → Production", "fermes (céréales, légumes, betteraves, lin, lait, élevage), forêt, pêche, carrières, mines, puits ; usines (moulin, laiterie, sucrerie, agroalimentaire, brasserie, verrerie, papeterie, chimie, textile, hygiène, pharmacie, électronique, automobile…) ; entreprise de transport routier"],
		["Livraisons", "chaque site a son stock ; des camions conduits par des chauffeurs-livreurs (lundi-vendredi) livrent le plus proche qui en a besoin. Sans chauffeur ou sans route : rayons vides et habitants mécontents. Les entrepôts servent de relais ; le reste vient par import (route qui sort de la carte, dépôt, gare, port)"],
		["Survol d'une case", "les ressources les plus riches de la case s'affichent dans la fiche du terrain"],
		["Règles", "il faut des habitants pour les emplois, une voie d'accès, des commerces pour vendre, un dépôt, une gare ou un port pour exporter"],
	]],
	["Décors", [
		["G", "panneau Décors : 160 modèles (bancs, lampadaires, fontaines, statues, clôtures, panneaux, marché, jeux, plage, ferme, animaux, bateaux, rochers)"],
		["Poser", "clic : un décor ; glisser : une rangée, ou une clôture d'un point à l'autre ; R / Maj+R : tourner"],
		["Pinceau, Gomme", "semer au hasard (troupeau, bottes de foin, rochers) ; la gomme efface aussi les décors automatiques"],
		["Automatiques", "bancs et poteaux le long des routes, bottes de foin après la moisson, troupeaux qui broutent, pontons et bateaux, rochers (case à cocher du panneau)"],
	]],
	["Réseaux (électricité, eau, égouts)", [
		["O", "panneau Réseaux : production et demande, sources, bâtiments coupés, comptes ; ses onglets allument le calque du réseau (pastille verte, orange ou rouge sur chaque bâtiment)"],
		["Construire > Réseaux", "centrales (charbon, gaz, bois, nucléaire, barrage, éolienne, solaire, réseau national), captage et forage d'eau, château d'eau, station d'épuration, lagunage, rejet direct"],
		["Routes", "chaque route porte la desserte locale : un bâtiment à moins de 30 m d'une route reliée à une source est desservi"],
		["Panneau O > ligne HT, MT, conduite, collecteur", "clic pour chaque point, clic droit ou Échap pour finir ; le tronçon a son chantier avant d'être en service"],
		["Panneau O > Retirer", "clic sur un tronçon pour l'enlever (30 % rendus)"],
	]],
	["Urgences", [
		["U", "panneau Urgences : appels en cours (clic : y aller), casernes et véhicules, bilan des temps d'intervention, carte de couverture"],
		["Construire → Services", "caserne de pompiers (FPT, VSAV, grande échelle), commissariat (police, ou gendarmerie dans une ville de moins de 2 000 habitants), hôpital (ambulances, SMUR)"],
		["Sur la route", "gyrophares et sirène deux-tons : ils passent les feux au ralenti, les autres se rangent à droite, ils doublent par la voie d'en face quand elle est libre"],
		["Équipages", "un véhicule ne part que si son équipage est de garde aujourd'hui (employés du bâtiment) ; l'ambulance passe par l'hôpital avant de rentrer"],
		["Appel d'essai ici", "bouton du panneau : un appel au hasard près de la caméra, pour voir partir les secours"],
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
	["Déchets", [
		["X", "panneau Déchets : ce que la ville jette et recycle, poubelles qui débordent (clic : y aller), installations, bennes en tournée"],
		["Construire → Déchets", "dépôt de collecte (4 bennes), déchèterie, centre de tri, usine de recyclage, compost, décharge, incinérateur (électricité)"],
		["Bacs", "chaque logement, commerce et entreprise remplit ses bacs (1,4 kg par habitant et par jour) ; plein, il déborde : sacs sur le trottoir, habitants mécontents, rue sale"],
		["Tournées", "les bennes partent du dépôt de 5 h à 12 h (lundi-samedi) avec 3 éboueurs de service, vident les bacs porte à porte puis déchargent à l'usine"],
		["Tri", "sans centre de tri personne ne trie ; avec lui, recyclables et verre partent en balles et en calcin vers l'usine de recyclage et les usines (verrerie, brasserie…)"],
		["Décharge pleine", "bouton « Recouvrir » du panneau : elle devient une colline verte et pollue beaucoup moins"],
		["Admin (F10)", "déchets oui/non, quantité par habitant ×0,5 à ×3"],
	]],
	["Pollution, bruit et valeur", [
		["N", "panneau Cartes : air, eau, bruit le jour et la nuit, valeur du terrain, loyers (une carte à la fois, et celles des autres systèmes)"],
		["Survol d'une case", "air et eau pollués (%), bruit (dB, jour et nuit) et prix du terrain (€/m²) dans la fiche du terrain"],
		["Effets", "la pollution rend malade, le bruit et les odeurs fâchent les habitants ; arbres et parcs protègent. Le terrain prend de la valeur près des parcs, de l'eau, des commerces et des transports, en perd près des usines et des grandes routes"],
		["Loyers", "ils suivent la valeur du quartier peu à peu, comme la taxe foncière ; un foyer au loyer trop cher déménage, les quartiers chers font pousser les bâtiments chics (zonage)"],
	]],
	["Temps et vue", [
		["T", "mettre le temps en pause / reprendre"],
		["Maj + T", "vitesse suivante du temps (la marée suit l'heure et la Lune : voir la barre d'état)"],
		["Ctrl + T, ou clic sur le Soleil de l'horloge", "jour permanent : l'image reste de jour pour construire, l'heure, les habitants et la production continuent (automatique quand Construire ou l'éditeur libre est ouvert)"],
		["V", "vue suivante : dessus, 3e personne, 1re personne"],
		["ZQSD, Maj, Espace", "marcher, courir, sauter (vue au sol)"],
		["E ou clic gauche", "ouvrir ou fermer une porte, une porte de garage (vue au sol), y compris dans les murs fins"],
		["Échap", "libérer la souris (vue au sol)"],
	]],
	["Partie (barre du haut)", [
		["Loupe", "aller à des coordonnées ou à un lieu connu, infos techniques (tuiles, marée)"],
		["Chiffres", "caisse, habitants, satisfaction, chômage : un clic ouvre le panneau Habitants"],
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
