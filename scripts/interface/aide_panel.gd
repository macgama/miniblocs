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
		["Catégories", "Observer, Terrain, Voies, Paysage : un clic ouvre leurs outils juste au-dessus ; Construire, Lignes, Habitants ouvrent leur panneau à droite (un seul à la fois)"],
		["Circulation, Véhicules, Vue", "afficher la circulation, choisir l'époque et la région des véhicules, changer de vue"],
		["1", "observer : survoler une case pour voir son altitude et son biome (et le nom de la rivière)"],
		["2 · 3 · 4", "aplanir, monter de 1 m, creuser de 1 m (clic gauche glissé)"],
		["5 · 6 · 7 · 8", "route, rail (tram, train, LGV, crémaillère, métro), chemin, voie d'eau : un clic par point"],
		["C", "voie en courbe (pendant le tracé)"],
		["Maj", "angles par pas de 15° (pendant le tracé)"],
		["9", "démolir une voie"],
		["J", "carrefour : clic pour changer son régime (auto, feux, stop, cédez-le-passage, priorité à droite)"],
		["Maj + clic (outil J)", "transformer le carrefour en giratoire"],
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
		["Page haut / Page bas", "étage actif (jusqu'à 59 étages et 5 sous-sols, le terrain est creusé) ; les étages du dessus sont masqués pendant l'édition"],
		["Copier l'étage ↑", "recopie l'étage actif au-dessus, autant de fois que voulu (immeubles)"],
		["Murs et pièces sur N étages", "réglage du panneau : un trait de Mur ou un rectangle de Pièce monte sur plusieurs étages d'un coup"],
		["Toit (murs et étages)", "deux pans, quatre pans ou plat, posé en blocs sur le dernier étage"],
		["Filtres", "région, époque et recherche par nom dans les listes de bâtiments"],
	]],
	["Transports publics", [
		["L", "panneau Lignes : arrêts, stations de métro, gares, ports, aéroports, dépôts de marchandises, parkings et lignes (case Fret pour les trains et les bateaux)"],
	]],
	["Habitants", [
		["H", "panneau Habitants : la ville en chiffres, la liste des habitants, le budget de la ville"],
		["Clic sur un bâtiment (outil 1)", "fiche du bâtiment : logements, employés, élèves, qui y vit et qui s'y trouve en ce moment"],
		["Clic sur un nom", "profil : âge, foyer, travail ou école, loisirs, budget et journée heure par heure"],
		["Vitesse de la vie", "réglage du panneau : vieillissement réaliste, rapide (1 an = 1 mois) ou très rapide (1 an = 1 jour)"],
	]],
	["Production", [
		["P", "panneau Production : carte des ressources (clic sur une ressource pour la voir sur le terrain), stocks, sites"],
		["Construire → Production", "extraction (forêt, ferme, élevage, pêche, carrière, sablière, argile, mine, puits) et transformation (scierie, moulin, boulangerie industrielle, aciérie, raffinerie…)"],
		["Survol d'une case", "les ressources les plus riches de la case s'affichent dans la fiche du terrain"],
		["Règles", "il faut des habitants pour les emplois, une voie d'accès, des commerces pour vendre, un dépôt, une gare ou un port pour exporter"],
	]],
	["Temps et vue", [
		["T", "mettre le temps en pause / reprendre"],
		["Maj + T", "vitesse suivante du temps (la marée suit l'heure et la Lune : voir la barre d'état)"],
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
