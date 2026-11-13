class_name TerreHud
extends CanvasLayer
## Interface du mode Terre : choix du lieu, outils de terrassement, infos de la case.

signal go_requested(lat: float, lon: float)
signal tool_selected(tool: int)
signal save_requested
signal help_requested
signal load_requested
signal quick_load_requested
signal city_requested
signal globe_requested
signal traffic_toggled(on: bool)
## Époque et région des véhicules de la circulation ("" = toutes).
signal traffic_filter_changed(era: String, region: String)
## Bouton « Lignes » : panneau des transports publics.
signal transit_requested
signal habitants_requested
## Panneau « Production » (touche P) : ressources, stocks, sites.
signal production_requested
signal agriculture_requested
## Panneau « Budget » (touche M) : impôts, emprunts, entretien des voies.
signal budget_requested
## Bouton « Décors » (touche G) : bancs, clôtures, animaux, bateaux, rochers…
signal decors_requested
## Panneau Infos : événements de la ville (touche I).
signal infos_requested
## Panneau « Urgences » (touche U) : appels, casernes, couverture.
signal urgences_requested
## Panneau Avis : satisfaction, élections, manifestations (Y).
signal avis_requested
## Bouton « Villages » : villages et territoire (Maj+M).
signal villages_requested
## Bouton « Fondateurs » : fondateurs et chantiers (Maj+H).
signal fondateurs_requested
## Panneau « Trafic » (Maj + L) : bouchons, parkings, remplissage des lignes.
signal trafic_requested
## Bouton « Déchets » (touche X).
signal dechets_requested
## Panneau « Cartes » (touche N) : pollution, bruit, valeur des terrains, autres calques.
signal cartes_requested
## Bouton Admin de la barre du haut, ou F10 : réglages de la partie.
signal admin_requested
signal spec_edited(type_id: String, spec: Dictionary)
signal curve_toggled(on: bool)
## Passage aux croisements choisi : "auto", "dessus" ou "dessous".
signal level_changed(level: String)
## Action de l'outil Carrefour : "regime", "giratoire" ou "echangeur".
signal junction_action_changed(action: String)

const PLACES := [
	{"name": "Tour Eiffel", "lat": 48.85826, "lon": 2.29450},
	{"name": "Genève (rade)", "lat": 46.20730, "lon": 6.15570},
	{"name": "Mont Blanc", "lat": 45.83260, "lon": 6.86520},
	{"name": "Étretat", "lat": 49.70700, "lon": 0.20160},
	{"name": "Grand Canyon", "lat": 36.06100, "lon": -112.10800},
	{"name": "Mont Fuji", "lat": 35.36060, "lon": 138.72740},
	{"name": "Rio (Pain de Sucre)", "lat": -22.94860, "lon": -43.15660},
]

const TOOLS := [
	{"name": "Observer", "key": KEY_1},
	{"name": "Aplanir", "key": KEY_2},
	{"name": "Monter +1 m", "key": KEY_3},
	{"name": "Creuser −1 m", "key": KEY_4},
	{"name": "Route", "key": KEY_5},
	{"name": "Rail", "key": KEY_6},
	{"name": "Chemin", "key": KEY_7},
	{"name": "Voie d'eau", "key": KEY_8},
	{"name": "Démolir", "key": KEY_9},
	{"name": "Carrefour", "key": KEY_J},
	{"name": "Paysage", "key": KEY_0},
]
## Premier outil de transport dans TOOLS (les précédents sont les outils de terrain).
const FIRST_TRANSPORT_TOOL := 4
## Outil « Paysage » : ouvre le panneau des pinceaux (colline, eau, biomes, arbres).
const LANDSCAPE_TOOL := 10

## Catégories de la barre du bas : outils (indices dans TOOLS) ou panneaux.
## « mode » : barre où elles paraissent, Gérer (la ville) ou Créer (construction libre).
const CATEGORIES := [
	{"id": "observer", "name": "Observer", "icon": "observer", "key": "1", "tools": [0], "mode": "both"},
	{"id": "terrain", "name": "Terrain", "icon": "terrain", "key": "2-4", "tools": [1, 2, 3]},
	{"id": "voies", "name": "Voies", "icon": "route", "key": "5-9", "tools": [4, 5, 6, 7, 9, 8]},
	{"id": "paysage", "name": "Paysage", "icon": "paysage", "key": "0", "tools": [10]},
	{"id": "construire", "name": "Construire", "icon": "construire", "key": "B", "panel": true},
	{"id": "lignes", "name": "Lignes", "icon": "lignes", "key": "L", "panel": true, "group": "transports"},
	{"id": "habitants", "name": "Habitants", "icon": "habitants", "key": "H", "panel": true, "group": "ville"},
	{"id": "production", "name": "Production", "icon": "ressources", "key": "P", "panel": true, "group": "economie"},
	{"id": "agriculture", "name": "Agriculture", "icon": "agriculture", "key": "Maj+F", "panel": true, "group": "economie"},
	{"id": "decors", "name": "Décors", "icon": "decors", "key": "G", "panel": true},
	{"id": "infos", "name": "Infos", "icon": "infos", "key": "I", "panel": true, "group": "infos"},
	{"id": "urgences", "name": "Urgences", "icon": "services", "key": "U", "panel": true, "group": "ville"},
	{"id": "avis", "name": "Avis", "icon": "urne", "key": "Y", "panel": true, "group": "ville"},
	{"id": "villages", "name": "Villages", "icon": "village", "key": "Maj+M", "panel": true, "group": "ville"},
	{"id": "fondateurs", "name": "Fondateurs et chantiers", "icon": "emploi", "key": "Maj+H", "panel": true, "group": "ville"},
	{"id": "trafic", "name": "Trafic", "icon": "circulation", "key": "Maj+L", "panel": true, "group": "transports"},
	{"id": "budget", "name": "Budget", "icon": "budget", "key": "M", "panel": true, "group": "ville"},
	{"id": "dechets", "name": "Déchets", "icon": "dechets", "key": "X", "panel": true, "group": "ville"},
	{"id": "cartes", "name": "Cartes", "icon": "cartes", "key": "N", "panel": true, "group": "infos"},
	{"id": "murs", "name": "Murs et étages", "icon": "mur", "key": "2", "panel": true, "mode": "creer"},
	{"id": "blocs", "name": "Blocs", "icon": "editeur", "key": "3", "panel": true, "mode": "creer"},
	{"id": "interieur", "name": "Intérieur", "icon": "interieur", "key": "4", "panel": true, "mode": "creer"},
	{"id": "creations", "name": "Mes créations", "icon": "creations", "key": "5", "panel": true, "mode": "creer"},
	{"id": "banque", "name": "Banque", "icon": "banque", "key": "6", "panel": true, "mode": "creer"},
	{"id": "atelier", "name": "Atelier", "icon": "atelier", "key": "7", "panel": true, "mode": "creer"},
]
## Menus de la barre du bas (mode Gérer) : leurs panneaux s'ouvrent dans une
## petite rangée au-dessus du bouton, pour que la barre tienne sur tout écran.
const GROUPS := [
	{"id": "transports", "name": "Transports", "icon": "lignes"},
	{"id": "ville", "name": "Ville", "icon": "habitants"},
	{"id": "economie", "name": "Économie", "icon": "ressources"},
	{"id": "infos", "name": "Infos", "icon": "infos"},
]
## Touches 2 à 5 du mode Créer.
const CREATE_KEYS := {KEY_2: "murs", KEY_3: "blocs", KEY_4: "interieur", KEY_5: "creations", KEY_6: "banque", KEY_7: "atelier"}
## Icône de chaque outil de TOOLS.
const TOOL_ICONS := ["observer", "aplanir", "monter", "creuser", "route", "rail", "chemin", "eau", "demolir", "carrefour", "paysage"]
## Nom court sous l'icône (le nom complet est dans l'infobulle).
const TOOL_SHORT := ["Observer", "Aplanir", "Monter", "Creuser", "Route", "Rail", "Chemin", "Voie d'eau", "Démolir", "Carrefour", "Paysage"]
const VIEW_NAMES := ["Dessus", "3e pers.", "1re pers."]
## Taille des boutons de la barre du bas (assez étroite pour laisser la carte de la case à gauche).
const DOCK_TILE := Vector2(70, 70)

## Bouton « Construire » de la barre du bas (le panneau s'ouvre à droite).
signal build_requested
## Bouton « Vue » : vue suivante (dessus, 3e personne, 1re personne).
signal view_requested
## Interrupteur Gérer / Créer (touche Tab) : la ville, ou la construction libre.
signal mode_changed(create: bool)
## Mode Créer : catégorie choisie ("murs", "blocs", "interieur", "creations").
signal create_requested(id: String)
## Mode Créer : flèches de l'étage (−1 ou +1).
signal level_step_requested(delta: int)

var coords_edit: LineEdit
var _place_label: Label
var _cell_label: Label
var _status_label: Label
var _network_label: Label
var _tool_label: Label
var _hint_panel: PanelContainer
var _message_label: Label
var _message_timer := 0.0
## Boutons des outils (mêmes indices que TOOLS), rangés dans le plateau au-dessus de la barre.
var _buttons: Array[Button] = []
var _cat_buttons := {}
var _tray: PanelContainer
var _tray_tools: HBoxContainer
var _tray_sep: Control
var _coords_panel: PanelContainer
var _chips := {}
var _view_button: Button
var _admin_button: Button
var _current_tool := 0
## Mode Créer (construction libre) : la barre du bas ne montre que l'atelier.
var create_mode := false
var _create_cat := ""
var _mode_buttons := {}
var _gerer_only: Array[Control] = []
var _creer_only: Array[Control] = []
var _level_label: Label
var _mode_badge: PanelContainer
## Menus de la barre : bouton et rangée de chaque groupe, menu ouvert.
var _group_buttons := {}
var _group_popups := {}
var _open_group := ""
var _dock: PanelContainer
var _cell_card: PanelContainer
## Barre en icônes seules (écran étroit).
var compact := false
## Dernier outil choisi dans chaque catégorie (clic sur la catégorie = on y revient).
var _last_tool := {"terrain": 1, "voies": 4}
# Panneau de réglage de la voie à poser.
var _spec_panel: HBoxContainer
var _class_pick: OptionButton
var _class_ids: Array = []
var _lanes: SpinBox
var _lane_w: SpinBox
var _tracks: SpinBox
var _width: SpinBox
var _curve: Button
var _level_pick: OptionButton
const LEVEL_IDS := ["auto", "dessus", "dessous"]
var _junction_panel: HBoxContainer
var _junction_buttons: Dictionary = {}
var _spec_rows: Dictionary = {}
var _filling := false


func _ready() -> void:
	_build_top_bar()
	_build_coords_panel()

	_message_label = Label.new()
	_message_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_message_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_message_label.offset_top = 76
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.add_theme_font_size_override("font_size", 16)
	_message_label.add_theme_color_override("font_color", Color("fff3b0"))
	_message_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_message_label.add_theme_constant_override("outline_size", 6)
	_message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_message_label)

	_build_cell_card()
	_build_bottom()
	_build_mode_badge()

	var credit := _build_credit()
	credit.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	credit.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	credit.grow_vertical = Control.GROW_DIRECTION_BEGIN
	credit.offset_right = -12
	credit.offset_bottom = -6
	add_child(credit)
	_update_categories()
	get_viewport().size_changed.connect(_fit_dock)
	_fit_dock.call_deferred()


# --- Barre du haut : lieu, partie, chiffres (l'horloge se place au centre) ---------

func _build_top_bar() -> void:
	var top := PanelContainer.new()
	top.name = "BarreHaut"
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 10
	top.offset_right = -10
	top.offset_top = 10
	top.custom_minimum_size = Vector2(0, 58)
	UiStyle.style_panel(top, 0.86, 12, 8)
	add_child(top)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	top.add_child(row)

	var pin := TextureRect.new()
	pin.texture = Icones.get_icon("lieu", 22, UiStyle.ACCENT)
	pin.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	pin.custom_minimum_size = Vector2(26, 0)
	row.add_child(pin)
	_place_label = Label.new()
	_place_label.add_theme_font_size_override("font_size", 16)
	_place_label.custom_minimum_size = Vector2(150, 0)
	_place_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_place_label.clip_text = true
	_place_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_place_label.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(_place_label)
	var go := UiStyle.icon_button("chercher", "Aller à d'autres coordonnées, infos techniques")
	go.toggle_mode = true
	go.toggled.connect(func(on: bool) -> void:
		_coords_panel.visible = on
		if on:
			coords_edit.grab_focus())
	row.add_child(go)
	row.add_child(UiStyle.vsep())
	for spec in [["globe", "Revenir au globe pour changer de lieu", "", globe_requested],
			["sauver", "Sauvegarder la partie", "F5", save_requested],
			["charger", "Parties sauvegardées (F9 : recharger la partie en cours)", "F9", load_requested],
			["aide", "Toutes les commandes", "F1", help_requested],
			["admin", "Admin : réglages de la partie (argent, coûts, règles, temps, déblocage)", "F10", admin_requested]]:
		var b := UiStyle.icon_button(spec[0], spec[1], spec[2])
		var sig: Signal = spec[3]
		b.pressed.connect(func() -> void: sig.emit())
		row.add_child(b)
		if spec[0] == "admin":
			_admin_button = b

	# Centre : l'horloge (ClockHud, calque au-dessus) s'y pose.
	var middle := Control.new()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(middle)

	for spec in [["caisse", "budget", "Caisse de la ville (clic : budget)"],
			["habitants", "habitants", "Habitants (clic : panneau Habitants, H)"],
			["satisfaction", "sourire", "Satisfaction moyenne sur 100"],
			["chomage", "emploi", "Chômage"]]:
		var chip := UiStyle.stat_chip(spec[1], spec[2])
		chip.text = "—"
		if spec[0] == "satisfaction":
			chip.tooltip_text = "Satisfaction moyenne sur 100 (clic : panneau Avis, Y)"
			chip.pressed.connect(func() -> void: avis_requested.emit())
		else:
			chip.pressed.connect(func() -> void: habitants_requested.emit())
		row.add_child(chip)
		_chips[spec[0]] = chip


func _build_coords_panel() -> void:
	_coords_panel = PanelContainer.new()
	_coords_panel.position = Vector2(10, 74)
	_coords_panel.visible = false
	UiStyle.style_panel(_coords_panel)
	add_child(_coords_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_coords_panel.add_child(box)
	var row := HBoxContainer.new()
	box.add_child(row)
	var l := Label.new()
	l.text = "Latitude, longitude :"
	row.add_child(l)
	coords_edit = LineEdit.new()
	coords_edit.custom_minimum_size = Vector2(220, 0)
	coords_edit.placeholder_text = "48.8584, 2.2945"
	coords_edit.text_submitted.connect(func(_t: String) -> void: _on_go())
	row.add_child(coords_edit)
	var go := Button.new()
	go.text = "Y aller"
	go.pressed.connect(_on_go)
	row.add_child(go)
	var places := HFlowContainer.new()
	places.custom_minimum_size = Vector2(460, 0)
	box.add_child(places)
	for p in PLACES:
		var b := Button.new()
		b.text = p.name
		b.focus_mode = Control.FOCUS_NONE
		var lat: float = p.lat
		var lon: float = p.lon
		b.pressed.connect(func() -> void:
			_coords_panel.visible = false
			go_requested.emit(lat, lon))
		places.add_child(b)
	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size = Vector2(460, 0)
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	box.add_child(_status_label)


# --- Carte de la case survolée (en bas à gauche) -------------------------------------

func _build_cell_card() -> void:
	var card := PanelContainer.new()
	card.name = "CarteCase"
	card.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	card.offset_left = 10
	card.offset_bottom = -10
	card.custom_minimum_size = Vector2(300, 0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiStyle.style_panel(card, 0.82, 12, 10)
	add_child(card)
	_cell_card = card
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	card.add_child(box)
	_cell_label = Label.new()
	_cell_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cell_label.custom_minimum_size = Vector2(278, 0)
	_cell_label.add_theme_font_size_override("font_size", 13)
	box.add_child(_cell_label)
	_network_label = Label.new()
	_network_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_network_label.custom_minimum_size = Vector2(278, 0)
	_network_label.add_theme_font_size_override("font_size", 12)
	_network_label.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	box.add_child(_network_label)


# --- Bas de l'écran : aide de l'outil, plateau d'outils, barre de catégories -------

func _build_bottom() -> void:
	var col := VBoxContainer.new()
	col.name = "BasEcran"
	col.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	col.grow_horizontal = Control.GROW_DIRECTION_BOTH
	col.grow_vertical = Control.GROW_DIRECTION_BEGIN
	col.offset_bottom = -10
	col.alignment = BoxContainer.ALIGNMENT_END
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)

	# Aide de l'outil en cours : une seule ligne, au-dessus du plateau.
	_hint_panel = PanelContainer.new()
	_hint_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hsb := UiStyle.flat_box(Color(0.08, 0.10, 0.09, 0.72), 14, 5)
	hsb.content_margin_left = 14
	hsb.content_margin_right = 14
	_hint_panel.add_theme_stylebox_override("panel", hsb)
	_hint_panel.visible = false
	col.add_child(_hint_panel)
	_tool_label = Label.new()
	_tool_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tool_label.add_theme_font_size_override("font_size", 14)
	_tool_label.add_theme_color_override("font_color", Color("e8f5e9"))
	_hint_panel.add_child(_tool_label)

	# Plateau : les outils de la catégorie choisie et le réglage de la voie.
	_tray = PanelContainer.new()
	_tray.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UiStyle.style_panel(_tray, 0.88, 12, 8)
	col.add_child(_tray)
	var tray_row := HBoxContainer.new()
	tray_row.add_theme_constant_override("separation", 4)
	_tray.add_child(tray_row)
	_tray_tools = HBoxContainer.new()
	_tray_tools.add_theme_constant_override("separation", 4)
	tray_row.add_child(_tray_tools)
	var group := ButtonGroup.new()
	for i in TOOLS.size():
		var b := UiStyle.tile_button(TOOL_ICONS[i], TOOL_SHORT[i], OS.get_keycode_string(TOOLS[i].key), Vector2(76, 64), 28)
		b.tooltip_text = "%s (%s)" % [TOOLS[i].name, OS.get_keycode_string(TOOLS[i].key)]
		b.add_theme_font_size_override("font_size", 12)
		b.toggle_mode = true
		b.button_group = group
		var tool_index := i
		b.pressed.connect(func() -> void:
			_set_current_tool(tool_index)
			tool_selected.emit(tool_index))
		_tray_tools.add_child(b)
		_buttons.append(b)
	_buttons[0].button_pressed = true
	_tray_sep = UiStyle.vsep()
	tray_row.add_child(_tray_sep)
	_build_spec_panel(tray_row)

	# Barre de catégories.
	var dock := PanelContainer.new()
	dock.name = "BarreCategories"
	dock.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UiStyle.style_panel(dock, 0.88, 14, 8)
	col.add_child(dock)
	_dock = dock
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	dock.add_child(row)
	row.add_child(_build_mode_switch())
	row.add_child(UiStyle.vsep())
	for c in CATEGORIES:
		if c.id == "construire":
			var s := UiStyle.vsep()
			row.add_child(s)
			_gerer_only.append(s)
		var b := UiStyle.tile_button(c.icon, c.name, c.key, DOCK_TILE)
		if c.get("mode", "gerer") == "creer":
			UiStyle.tint_pressed(b, UiStyle.CREATE, UiStyle.CREATE_INK)
		b.tooltip_text = "%s (%s)" % [c.name, c.key]
		# Toutes allumables : outil en cours ou panneau ouvert (état remis par _update_categories / set_panel_open).
		b.toggle_mode = true
		var id: String = c.id
		b.pressed.connect(func() -> void: _on_category(id))
		_cat_buttons[id] = b
		var gid: String = c.get("group", "")
		if gid == "":
			row.add_child(b)
			continue
		if not _group_popups.has(gid):
			row.add_child(_build_group(gid))
		(_group_popups[gid].get_child(0) as HBoxContainer).add_child(b)
	var fsep := UiStyle.vsep()
	row.add_child(fsep)
	_creer_only.append(fsep)
	var floor_box := _build_floor_widget()
	row.add_child(floor_box)
	_creer_only.append(floor_box)
	var traffic := UiStyle.tile_button("circulation", "Circulation", "", DOCK_TILE)
	traffic.tooltip_text = "Afficher ou masquer la circulation"
	traffic.toggle_mode = true
	traffic.button_pressed = true
	traffic.add_theme_stylebox_override("pressed", UiStyle.flat_box(Color(0.62, 0.89, 0.69, 0.18)))
	traffic.add_theme_stylebox_override("hover_pressed", UiStyle.flat_box(Color(0.62, 0.89, 0.69, 0.26)))
	for k in ["font_pressed_color", "font_hover_pressed_color", "icon_pressed_color", "icon_hover_pressed_color"]:
		traffic.add_theme_color_override(k, UiStyle.GOOD)
	traffic.toggled.connect(func(on: bool) -> void: traffic_toggled.emit(on))
	# Circulation et véhicules : dans le menu Transports.
	var trow := _group_popups.transports.get_child(0) as HBoxContainer
	trow.add_child(UiStyle.vsep())
	trow.add_child(traffic)
	trow.add_child(_build_vehicle_menu())
	row.add_child(UiStyle.vsep())
	_view_button = UiStyle.tile_button("vue", "Dessus", "V", DOCK_TILE)
	_view_button.tooltip_text = "Vue suivante : dessus, 3e personne, 1re personne (V)"
	_view_button.pressed.connect(func() -> void: view_requested.emit())
	row.add_child(_view_button)


## Bouton d'un menu de la barre et sa rangée de panneaux (cachée).
func _build_group(gid: String) -> Button:
	var g: Dictionary = {}
	for gg in GROUPS:
		if gg.id == gid:
			g = gg
	var keys := []
	for c in CATEGORIES:
		if c.get("group", "") == gid:
			keys.append("%s (%s)" % [c.name, c.key])
	var b := UiStyle.tile_button(g.icon, g.name + " ▴", "", DOCK_TILE)
	b.tooltip_text = "%s : %s" % [g.name, ", ".join(keys)]
	b.toggle_mode = true
	b.pressed.connect(func() -> void: toggle_group(gid))
	_group_buttons[gid] = b
	_gerer_only.append(b)
	var pop := PanelContainer.new()
	pop.name = "Menu_" + gid
	UiStyle.style_panel(pop, 0.94, 12, 6)
	pop.visible = false
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 4)
	pop.add_child(r)
	add_child(pop)
	_group_popups[gid] = pop
	return b


## Ouvre (ou ferme) la rangée d'un menu, juste au-dessus de son bouton.
func toggle_group(gid: String) -> void:
	_open_group = "" if _open_group == gid else gid
	_place_group_popup()
	_refresh_groups()


func close_groups() -> void:
	if _open_group != "":
		_open_group = ""
		_place_group_popup()
		_refresh_groups()


func _place_group_popup() -> void:
	for id in _group_popups:
		(_group_popups[id] as Control).visible = id == _open_group
	if _open_group == "":
		return
	var pop: PanelContainer = _group_popups[_open_group]
	var b: Button = _group_buttons[_open_group]
	pop.reset_size()
	var sz := pop.get_combined_minimum_size()
	var view := get_viewport().get_visible_rect().size
	var x := b.global_position.x + b.size.x * 0.5 - sz.x * 0.5
	x = clampf(x, 8.0, maxf(8.0, view.x - sz.x - 8.0))
	pop.position = Vector2(x, _dock.global_position.y - sz.y - 6.0)
	pop.size = sz


## Bouton d'un menu allumé s'il est ouvert ou si l'un de ses panneaux l'est.
func _refresh_groups() -> void:
	for gid in _group_buttons:
		var on: bool = gid == _open_group
		for c in CATEGORIES:
			if c.get("group", "") == gid and (_cat_buttons[c.id] as Button).button_pressed:
				on = true
		(_group_buttons[gid] as Button).set_pressed_no_signal(on)


## Fait tenir la barre dans l'écran, à droite de la carte de la case : icônes
## seules si la place manque. width : largeur de l'écran (tests), sinon la vraie.
func _fit_dock(width := -1.0) -> void:
	if _dock == null:
		return
	var view := width if width > 0.0 else get_viewport().get_visible_rect().size.x
	var card_right := 10.0 + _cell_card.size.x + 10.0
	set_compact(false)
	var w := _dock.get_combined_minimum_size().x
	if w > view - card_right - 10.0:
		set_compact(true)
		w = _dock.get_combined_minimum_size().x
	# Centre de la barre décalé à droite si elle chevaucherait la carte.
	var col := _dock.get_parent() as Control
	var col_w := col.get_combined_minimum_size().x
	var shift := maxf(0.0, card_right + w * 0.5 - view * 0.5)
	shift = minf(shift, maxf(0.0, (view - col_w) * 0.5 - 10.0))
	col.offset_left = shift
	col.offset_right = shift
	_place_group_popup()


## Icônes seules (le nom reste dans l'infobulle) : la barre est presque deux fois plus courte.
func set_compact(on: bool) -> void:
	if compact == on:
		return
	compact = on
	var tiles: Array = _cat_buttons.values() + _group_buttons.values() + [_view_button]
	for b in tiles:
		var btn := b as Button
		if btn.get_parent() != _dock.get_child(0):
			continue # les rangées des menus gardent leurs noms
		if on:
			btn.set_meta("label", btn.text)
			btn.text = ""
			btn.custom_minimum_size = Vector2(52, 52)
		else:
			btn.text = String(btn.get_meta("label", btn.text))
			btn.custom_minimum_size = DOCK_TILE
	for m in _mode_buttons.values():
		var mb := m as Button
		if on:
			mb.set_meta("label", mb.text)
			mb.text = ""
			mb.custom_minimum_size = Vector2(34, 26)
		else:
			mb.text = String(mb.get_meta("label", mb.text))
			mb.custom_minimum_size = Vector2(84, 30)


func _input(event: InputEvent) -> void:
	# Clic ailleurs : le menu ouvert se referme.
	var mb := event as InputEventMouseButton
	if _open_group == "" or mb == null or not mb.pressed:
		return
	var pop: Control = _group_popups[_open_group]
	var b: Control = _group_buttons[_open_group]
	if not pop.get_global_rect().has_point(mb.position) and not b.get_global_rect().has_point(mb.position):
		close_groups()


## Interrupteur Gérer / Créer, à gauche de la barre du bas.
func _build_mode_switch() -> Control:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 3)
	var group := ButtonGroup.new()
	for m in [["gerer", "Gérer", "zonage", "Gérer la ville : terrain, voies, zonage, catalogue, lignes, habitants (Tab)"],
			["creer", "Créer", "editeur", "Créer un bâtiment : murs et étages, blocs, intérieur ; la ville se met en pause (Tab)"]]:
		var b := Button.new()
		b.text = m[1]
		b.icon = Icones.get_icon(m[2], 18)
		b.tooltip_text = m[3]
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(84, 30)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 13)
		b.add_theme_constant_override("icon_max_width", 18)
		UiStyle.style_icon_button(b)
		if m[0] == "creer":
			UiStyle.tint_pressed(b, UiStyle.CREATE, UiStyle.CREATE_INK)
		var on: bool = m[0] == "creer"
		b.pressed.connect(func() -> void: _request_mode(on))
		box.add_child(b)
		_mode_buttons[m[0]] = b
	(_mode_buttons.gerer as Button).button_pressed = true
	var tab := UiStyle.key_label("Tab")
	tab.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(tab)
	return box


## Mode Créer : l'étage où l'on construit, avec ses flèches (Page bas / Page haut).
func _build_floor_widget() -> Control:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.custom_minimum_size = Vector2(170, 0)
	var cap := Label.new()
	cap.text = "ÉTAGE"
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.add_theme_font_size_override("font_size", 11)
	cap.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	box.add_child(cap)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	box.add_child(row)
	var down := UiStyle.icon_button("bas", "Étage du dessous", "Page bas", 18, 32)
	down.pressed.connect(func() -> void: level_step_requested.emit(-1))
	row.add_child(down)
	_level_label = Label.new()
	_level_label.text = "Rez-de-chaussée"
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_label.custom_minimum_size = Vector2(98, 0)
	_level_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_level_label.add_theme_font_size_override("font_size", 15)
	row.add_child(_level_label)
	var up := UiStyle.icon_button("haut", "Étage du dessus", "Page haut", 18, 32)
	up.pressed.connect(func() -> void: level_step_requested.emit(1))
	row.add_child(up)
	return box


## Pastille du haut en mode Créer : on sait toujours où l'on est.
func _build_mode_badge() -> void:
	_mode_badge = PanelContainer.new()
	_mode_badge.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_mode_badge.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_mode_badge.offset_top = 74
	_mode_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := UiStyle.flat_box(UiStyle.CREATE, 14, 4)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	_mode_badge.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = "Mode Créer : la ville est en pause  ·  Tab : retour à la ville"
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", UiStyle.CREATE_INK)
	_mode_badge.add_child(l)
	_mode_badge.visible = false
	add_child(_mode_badge)


func _request_mode(on: bool) -> void:
	if on == create_mode:
		return
	set_create_mode(on)
	mode_changed.emit(on)


## Passe la barre du bas en mode Créer ou Gérer (sans prévenir).
func set_create_mode(on: bool) -> void:
	create_mode = on
	if _mode_buttons.is_empty():
		return
	(_mode_buttons.creer as Button).set_pressed_no_signal(on)
	(_mode_buttons.gerer as Button).set_pressed_no_signal(not on)
	if on and _current_tool != 0:
		_buttons[0].button_pressed = true
		_set_current_tool(0)
		tool_selected.emit(0)
	if not on:
		_create_cat = ""
	_mode_badge.visible = on
	_message_label.offset_top = 110 if on else 76
	_update_categories()
	_fit_dock.call_deferred()


## Mode Créer : catégorie allumée ("" : aucune).
func set_create_category(id: String) -> void:
	_create_cat = id
	_update_categories()


func create_category() -> String:
	return _create_cat


## Mode Créer : nom de l'étage actif sous les flèches.
func set_level_text(text: String) -> void:
	if _level_label:
		_level_label.text = text.get_slice("  ·", 0)


func _on_category(id: String) -> void:
	close_groups()
	var c := _category(id)
	if c.get("mode", "gerer") == "creer":
		_create_cat = "" if _create_cat == id else id
		create_requested.emit(_create_cat)
		_update_categories()
		return
	if c.get("panel", false):
		match id:
			"construire": build_requested.emit()
			"lignes": transit_requested.emit()
			"habitants": habitants_requested.emit()
			"production": production_requested.emit()
			"agriculture": agriculture_requested.emit()
			"budget": budget_requested.emit()
			"decors": decors_requested.emit()
			"infos": infos_requested.emit()
			"urgences": urgences_requested.emit()
			"avis": avis_requested.emit()
			"villages": villages_requested.emit()
			"fondateurs": fondateurs_requested.emit()
			"trafic": trafic_requested.emit()
			"dechets": dechets_requested.emit()
			"cartes": cartes_requested.emit()
		_update_categories()
		return
	if create_mode and id == "observer":
		# Mode Créer : Observer range l'outil de l'atelier.
		if _create_cat != "":
			_create_cat = ""
			create_requested.emit("")
		_buttons[0].button_pressed = true
		_set_current_tool(0)
		tool_selected.emit(0)
		return
	var tools: Array = c.tools
	var t: int = tools[0]
	if tools.has(_current_tool):
		# Deuxième clic sur la catégorie active : retour à Observer.
		t = 0
	elif _last_tool.has(id):
		t = _last_tool[id]
	_buttons[t].button_pressed = true
	_set_current_tool(t)
	tool_selected.emit(t)


func _category(id: String) -> Dictionary:
	for c in CATEGORIES:
		if c.id == id:
			return c
	return {}


func _category_of_tool(t: int) -> String:
	for c in CATEGORIES:
		if (c.get("tools", []) as Array).has(t):
			return c.id
	return "observer"


func _set_current_tool(t: int) -> void:
	_current_tool = t
	var cat := _category_of_tool(t)
	if _last_tool.has(cat):
		_last_tool[cat] = t
	_update_categories()


## Met la barre à jour : catégorie active en ambre, plateau des outils de la catégorie.
func _update_categories() -> void:
	if _tray == null:
		return
	var cat := _category_of_tool(_current_tool)
	for c in CATEGORIES:
		var mode: String = c.get("mode", "gerer")
		var b := _cat_buttons[c.id] as Button
		b.visible = mode == "both" or (mode == "creer") == create_mode
		if mode == "creer":
			b.set_pressed_no_signal(c.id == _create_cat)
		elif not c.get("panel", false):
			b.set_pressed_no_signal(c.id == cat and (not create_mode or _create_cat == ""))
	for n in _gerer_only:
		n.visible = not create_mode
	if create_mode:
		close_groups()
	_refresh_groups()
	for n in _creer_only:
		n.visible = create_mode
	var tools: Array = _category(cat).get("tools", [])
	for i in _buttons.size():
		_buttons[i].visible = tools.size() > 1 and tools.has(i)
	# Ordre du plateau : celui de la catégorie (Carrefour avant Démolir).
	for k in tools.size():
		_tray_tools.move_child(_buttons[tools[k]], k)
	var spec_on := (_spec_panel != null and _spec_panel.visible) or (_junction_panel != null and _junction_panel.visible)
	_tray_tools.visible = tools.size() > 1
	_tray_sep.visible = _tray_tools.visible and spec_on
	_tray.visible = _tray_tools.visible or spec_on


## Texte du bandeau du mode Créer (l'atelier a le sien).
func set_create_banner(text: String) -> void:
	if _mode_badge and _mode_badge.get_child_count() > 0:
		(_mode_badge.get_child(0) as Label).text = text


## Change le nom et l'infobulle d'une tuile de la barre du bas.
func set_category_label(id: String, text: String, tip := "") -> void:
	var b := _cat_buttons.get(id) as Button
	if b:
		b.text = text
		if tip != "":
			b.tooltip_text = tip


## Panneaux ouverts (Construire, Lignes, Habitants) : leur catégorie est allumée.
func set_panel_open(id: String, on: bool) -> void:
	var b := _cat_buttons.get(id) as Button
	if b and b.button_pressed != on:
		b.set_pressed_no_signal(on)
		_refresh_groups()


## Le bouton Admin n'est montré qu'à qui peut administrer la partie.
func set_admin_visible(on: bool) -> void:
	if _admin_button:
		_admin_button.visible = on


func set_view(v: int) -> void:
	if _view_button:
		_view_button.text = VIEW_NAMES[clampi(v, 0, 2)]


## Chiffres de la ville dans la barre du haut.
func set_stats(money: String, people: int, satisfaction: int, unemployment: String) -> void:
	if _chips.is_empty():
		return
	(_chips.caisse as Button).text = money
	(_chips.habitants as Button).text = str(people)
	(_chips.satisfaction as Button).text = "—" if people == 0 else str(satisfaction)
	(_chips.chomage as Button).text = unemployment


func _build_credit() -> Label:
	var credit := Label.new()
	credit.text = "Relief : Mapzen   ·   Biomes : © ESA   ·   Rivières : © OSM"
	credit.tooltip_text = "Relief : Mapzen Terrain Tiles (AWS Open Data) — SRTM, GMTED, ETOPO1, EU-DEM\nBiomes : © ESA WorldCover 2021, données Copernicus Sentinel (CC BY 4.0)\nRivières : © contributeurs OpenStreetMap (ODbL) si disponible, sinon calculées sur le relief"
	credit.mouse_filter = Control.MOUSE_FILTER_PASS
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	credit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	credit.add_theme_font_size_override("font_size", 11)
	credit.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	credit.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	credit.add_theme_constant_override("outline_size", 3)
	return credit


var _veh_era := ""
var _veh_region := ""


## Menu « Véhicules » : époque et région des modèles qui circulent.
func _build_vehicle_menu() -> MenuButton:
	var mb := MenuButton.new()
	mb.text = "Véhicules ▾"
	mb.icon = Icones.get_icon("vehicules", 30)
	mb.tooltip_text = "Époque et région des véhicules qui circulent"
	mb.custom_minimum_size = DOCK_TILE
	mb.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mb.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	mb.add_theme_font_size_override("font_size", 13)
	mb.add_theme_constant_override("icon_max_width", 30)
	UiStyle.style_icon_button(mb)
	var pm := mb.get_popup()
	pm.hide_on_checkable_item_selection = false
	pm.add_separator("Époque")
	var entries: Array = [["era", ""]]
	pm.add_radio_check_item("Toutes les époques", 0)
	for e in Styles.ERAS:
		pm.add_radio_check_item(e.name, entries.size())
		entries.append(["era", e.id])
	pm.add_separator("Région")
	pm.add_radio_check_item("Toutes les régions", entries.size())
	entries.append(["region", ""])
	for r in Styles.REGIONS:
		if r.id == "monde":
			continue
		pm.add_radio_check_item(r.name, entries.size())
		entries.append(["region", r.id])
	var refresh := func() -> void:
		for i in pm.item_count:
			var id := pm.get_item_id(i)
			if pm.is_item_separator(i) or id < 0 or id >= entries.size():
				continue
			var en: Array = entries[id]
			pm.set_item_checked(i, (_veh_era if en[0] == "era" else _veh_region) == en[1])
	refresh.call()
	pm.id_pressed.connect(func(id: int) -> void:
		var en: Array = entries[id]
		if en[0] == "era":
			_veh_era = en[1]
		else:
			_veh_region = en[1]
		refresh.call()
		traffic_filter_changed.emit(_veh_era, _veh_region))
	return mb


func _build_spec_panel(parent: Control) -> void:
	_spec_panel = HBoxContainer.new()
	_spec_panel.visible = false
	_spec_panel.add_theme_constant_override("separation", 10)
	parent.add_child(_spec_panel)
	var row := _spec_panel
	_class_pick = OptionButton.new()
	_class_pick.custom_minimum_size = Vector2(230, 0)
	_class_pick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_class_pick.item_selected.connect(func(i: int) -> void:
		if _filling:
			return
		var id: String = _class_ids[i]
		spec_edited.emit(id, TransportTypes.default_spec(id)))
	row.add_child(_class_pick)
	_lanes = _spin(row, "lanes", "Voies par sens", 1, 4, 1)
	_lane_w = _spin(row, "lane_w", "Largeur d'une voie (m)", 2.75, 3.5, 0.05)
	_tracks = _spin(row, "tracks", "Voies ferrées", 1, 2, 1)
	_width = _spin(row, "width", "Largeur (m)", 1.0, 60.0, 0.1)
	_curve = Button.new()
	_curve.text = "Courbe"
	_curve.icon = Icones.get_icon("courbe", 18)
	_curve.tooltip_text = "Voie en courbe (C)"
	_curve.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_curve.toggle_mode = true
	_curve.toggled.connect(func(on: bool) -> void:
		if not _filling:
			curve_toggled.emit(on))
	row.add_child(_curve)
	_level_pick = OptionButton.new()
	_level_pick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_level_pick.tooltip_text = "Aux croisements avec une autre voie (N) : carrefour automatique, ou toujours un pont, ou toujours un tunnel"
	for t in ["Croisement : auto", "Passer dessus (pont)", "Passer dessous (tunnel)"]:
		_level_pick.add_item(t)
	_level_pick.item_selected.connect(func(i: int) -> void:
		if not _filling:
			level_changed.emit(LEVEL_IDS[i]))
	row.add_child(_level_pick)
	# Outil Carrefour : régime, giratoire ou échangeur.
	_junction_panel = HBoxContainer.new()
	_junction_panel.visible = false
	_junction_panel.add_theme_constant_override("separation", 6)
	parent.add_child(_junction_panel)
	var group := ButtonGroup.new()
	for it in [["regime", "Régime", "Changer le régime d'un carrefour : feux, stop, cédez-le-passage, priorité à droite"],
			["giratoire", "Rond-point", "Transformer un carrefour en giratoire (aussi : Maj + clic)"],
			["echangeur", "Échangeur", "Relier une route à l'autoroute qu'elle enjambe : 2 sorties et 2 entrées"]]:
		var jb := Button.new()
		jb.text = it[1]
		jb.tooltip_text = it[2]
		jb.toggle_mode = true
		jb.button_group = group
		jb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var action: String = it[0]
		jb.pressed.connect(func() -> void: junction_action_changed.emit(action))
		_junction_panel.add_child(jb)
		_junction_buttons[action] = jb


## Affiche les actions de l'outil Carrefour ("" : les cacher).
func show_junction_panel(action: String) -> void:
	_junction_panel.visible = action != ""
	if _junction_buttons.has(action):
		(_junction_buttons[action] as Button).set_pressed_no_signal(true)
	_update_categories()


func _spin(row: Control, key: String, label: String, lo: float, hi: float, step: float) -> SpinBox:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l := Label.new()
	l.text = label
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	box.add_child(l)
	var sb := SpinBox.new()
	sb.min_value = lo
	sb.max_value = hi
	sb.step = step
	sb.custom_minimum_size = Vector2(86, 0)
	sb.value_changed.connect(func(_v: float) -> void: _emit_spec())
	box.add_child(sb)
	row.add_child(box)
	_spec_rows[key] = box
	return sb


func _emit_spec() -> void:
	if _filling or _class_ids.is_empty():
		return
	var id: String = _class_ids[_class_pick.selected]
	var s := {"lanes": int(_lanes.value), "lane_w": _lane_w.value, "tracks": int(_tracks.value), "width": _width.value}
	spec_edited.emit(id, TransportTypes.normalize(id, s))


## Affiche le panneau de réglage pour une classe de voie (null : le cacher).
func show_spec(type_id: String, spec: Dictionary, curve: bool, level := "auto") -> void:
	_junction_panel.visible = false
	if type_id == "":
		_spec_panel.visible = false
		_update_categories()
		return
	_filling = true
	var c := TransportTypes.get_type(type_id)
	_class_ids = TransportTypes.BY_MODE.get(int(c.mode), [type_id])
	_class_pick.clear()
	for id in _class_ids:
		_class_pick.add_item(TransportTypes.get_type(id).name)
	_class_pick.select(maxi(0, _class_ids.find(type_id)))
	_spec_rows.lanes.visible = c.has("lanes")
	_spec_rows.lane_w.visible = c.has("lanes")
	_spec_rows.tracks.visible = c.has("tracks")
	_spec_rows.width.visible = c.has("width")
	if c.has("lanes"):
		_lanes.min_value = c.lanes[0]
		_lanes.max_value = c.lanes[1]
		_lanes.value = spec.lanes
		_lanes.editable = int(c.lanes[0]) != int(c.lanes[1])
		_lane_w.min_value = c.lane_w[0]
		_lane_w.max_value = c.lane_w[1]
		_lane_w.value = spec.lane_w
		_lane_w.editable = float(c.lane_w[0]) != float(c.lane_w[1])
	if c.has("tracks"):
		_tracks.min_value = c.tracks[0]
		_tracks.max_value = c.tracks[1]
		_tracks.value = spec.tracks
		_tracks.editable = int(c.tracks[0]) != int(c.tracks[1])
	if c.has("width"):
		_width.min_value = c.width[0]
		_width.max_value = c.width[1]
		_width.value = spec.width
	_curve.button_pressed = curve
	_level_pick.select(maxi(0, LEVEL_IDS.find(level)))
	_level_pick.visible = int(c.mode) != TransportTypes.Mode.WATER
	_spec_panel.visible = true
	_filling = false
	_update_categories()


func _on_go() -> void:
	var v: Variant = Geo.parse_lat_lon(coords_edit.text)
	coords_edit.release_focus()
	if v == null:
		show_message("Coordonnées non comprises. Exemple : 48.8584, 2.2945")
		return
	go_requested.emit((v as Vector2).x, (v as Vector2).y)


func _process(delta: float) -> void:
	if _message_timer > 0.0:
		_message_timer -= delta
		if _message_timer <= 0.0:
			_message_label.text = ""


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_TAB and not key.ctrl_pressed and not key.alt_pressed:
		_request_mode(not create_mode)
		get_viewport().set_input_as_handled()
		return
	if create_mode:
		var kc := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		if CREATE_KEYS.has(kc):
			_on_category(CREATE_KEYS[kc])
			get_viewport().set_input_as_handled()
			return
		if kc == KEY_1:
			_on_category("observer")
			get_viewport().set_input_as_handled()
			return
	for i in TOOLS.size():
		if key.keycode == TOOLS[i].key or key.physical_keycode == TOOLS[i].key:
			_buttons[i].button_pressed = true
			_set_current_tool(i)
			tool_selected.emit(i)
			return
	if key.keycode == KEY_F1:
		help_requested.emit()
	elif key.keycode == KEY_F5:
		save_requested.emit()
	elif key.keycode == KEY_F9:
		quick_load_requested.emit()
	elif key.keycode == KEY_F10:
		admin_requested.emit()


## Enfonce le bouton d'un outil sans prévenir (un autre système a pris la main).
func select_tool_silently(i: int) -> void:
	_buttons[i].set_pressed_no_signal(true)
	_set_current_tool(i)


func show_message(text: String) -> void:
	_message_label.text = text
	_message_timer = 3.0


func set_place(lat: float, lon: float) -> void:
	var where := GameStart.place_name if GameStart.place_name != "" else "%.4f, %.4f" % [lat, lon]
	_place_label.text = where
	_place_label.tooltip_text = "Région de %d × %d km centrée sur %.5f, %.5f (1 case = 1 m × 1 m)" % [
		int(GameStart.REGION_SIZE / 1000.0), int(GameStart.REGION_SIZE / 1000.0), lat, lon]
	if not coords_edit.has_focus():
		coords_edit.text = "%.5f, %.5f" % [lat, lon]


func set_cell_info(text: String) -> void:
	_cell_label.text = text


func set_tool_info(text: String) -> void:
	_tool_label.text = text.strip_edges()
	_hint_panel.visible = _tool_label.text != ""


func set_network_info(text: String) -> void:
	_network_label.text = text


func set_status(text: String) -> void:
	_status_label.text = text
