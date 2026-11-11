class_name AidePanel
extends Control
## Fenêtre d'aide (F1) : toutes les commandes du jeu, rangées par thème.

signal closed

const SECTIONS := [
	["Caméra (vue de dessus)", [
		["ZQSD ou flèches", "déplacer (WASD en QWERTY)"],
		["Clic droit glissé", "faire glisser la carte"],
		["Molette", "zoomer"],
		["A / E, ou clic molette glissé", "tourner (Q / E en QWERTY)"],
	]],
	["Outils (barre du bas)", [
		["1", "observer : survoler une case pour voir son altitude et son biome (et le nom de la rivière)"],
		["2 · 3 · 4", "aplanir, monter de 1 m, creuser de 1 m (clic gauche glissé)"],
		["5 · 6 · 7 · 8", "route, rail, chemin, voie d'eau : un clic par point"],
		["C", "voie en courbe (pendant le tracé)"],
		["Maj", "angles par pas de 15° (pendant le tracé)"],
		["9", "démolir une voie"],
		["Échap ou clic droit", "arrêter le tracé, annuler l'outil"],
	]],
	["Construire (panneau de droite)", [
		["B", "afficher ou masquer le panneau Construire"],
		["Clic gauche", "poser le bâtiment choisi"],
		["R", "tourner le bâtiment d'un quart de tour"],
		["Ctrl + Z", "annuler (éditeur libre bloc par bloc)"],
	]],
	["Transports publics", [
		["L", "panneau Lignes : stations, gares, ports, aéroports et lignes"],
	]],
	["Temps et vue", [
		["T", "mettre le temps en pause / reprendre"],
		["Maj + T", "vitesse suivante du temps"],
		["V", "vue suivante : dessus, 3e personne, 1re personne"],
		["ZQSD, Maj, Espace", "marcher, courir, sauter (vue au sol)"],
		["Échap", "libérer la souris (vue au sol)"],
	]],
	["Partie", [
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
	var col_a := VBoxContainer.new()
	var col_b := VBoxContainer.new()
	cols.add_child(col_a)
	cols.add_child(col_b)
	for i in SECTIONS.size():
		var sec: Array = SECTIONS[i]
		var col := col_a if i < 3 else col_b
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
			k.add_theme_font_size_override("font_size", 14)
			grid.add_child(k)
			var d := Label.new()
			d.text = row[1]
			d.add_theme_font_size_override("font_size", 14)
			d.custom_minimum_size = Vector2(330, 0)
			d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			grid.add_child(d)
		col.add_child(Control.new())
	var credit := Label.new()
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
