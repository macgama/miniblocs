class_name OptionsPanel
extends Control
## Fenêtre Options (menu principal et menu pause) : Graphismes, Son, Jeu, Touches.
## Chaque changement s'applique tout de suite et est gardé (OptionsJeu).

signal closed

const TOUCHES := [
	["Partout", [
		["Échap", "fermer la fenêtre ou l'outil en cours ; sinon menu pause"],
		["F1", "aide : toutes les commandes"],
		["F2", "son et musique"],
		["F5 / F9", "sauvegarde rapide / recharger la dernière partie"],
		["F10", "réglages de la partie (Admin)"],
		["T / Maj + T", "pause du temps / vitesse suivante"],
	]],
	["Caméra", [
		["ZQSD ou flèches", "se déplacer"],
		["Molette", "zoomer"],
		["A / E", "tourner"],
		["Ctrl + molette", "incliner jusqu'à la vue rasante"],
		["V", "vue au sol (3e puis 1re personne)"],
	]],
	["Construire", [
		["Tab", "mode Gérer (la ville) / Créer (construction libre)"],
		["1 à 9, 0, J", "outils : observer, terrain, voies, démolir, paysage, carrefour"],
		["B", "catalogue des bâtiments et zonage"],
		["R", "tourner le bâtiment"],
		["Ctrl + Z", "annuler (éditeur libre)"],
		["G", "décors"],
	]],
	["Panneaux", [
		["M / Maj + M", "mairie et budget / villages"],
		["H / Maj + H", "habitants / fondateurs"],
		["L", "lignes de transport"],
		["O / Maj + O", "réseaux / internet et téléphone"],
		["P / Maj + F", "production / agriculture"],
		["U / Maj + U", "urgences / services publics"],
		["X, Y, N, K", "déchets, avis, cartes, habitants au travail"],
	]],
]

var _tabs: TabContainer
var _volumes := {}
var _note: Label


func _ready() -> void:
	OptionsJeu.appliquer(get_tree())
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 500)
	UiStyle.style_panel(panel, 0.97, 12, 16)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var title := Label.new()
	title.text = "Options"
	title.add_theme_font_size_override("font_size", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := Button.new()
	close.text = "Fermer (Échap)"
	close.pressed.connect(close_panel)
	head.add_child(close)

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_tabs)
	_tabs.add_child(_onglet_graphismes())
	_tabs.add_child(_onglet_son())
	_tabs.add_child(_onglet_jeu())
	_tabs.add_child(_onglet_touches())
	_note = Label.new()
	_note.add_theme_font_size_override("font_size", 12)
	_note.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	_note.text = "Les options valent pour toutes les parties. Les réglages d'une partie (argent, coûts, règles) sont dans l'Admin (F10)."
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_note)


# --- Onglets ---------------------------------------------------------------------------

func _page(nom: String) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.name = nom
	page.add_theme_constant_override("separation", 8)
	return page


func _ligne(page: Control, texte: String, ctrl: Control, aide := "") -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var l := Label.new()
	l.text = texte
	l.custom_minimum_size = Vector2(230, 0)
	l.tooltip_text = aide
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(l)
	ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ctrl.tooltip_text = aide
	row.add_child(ctrl)
	page.add_child(row)


func _choix(items: Array, sel: int, on_change: Callable) -> OptionButton:
	var o := OptionButton.new()
	for it in items:
		o.add_item(String(it))
	o.select(sel)
	o.item_selected.connect(func(i: int) -> void:
		on_change.call(i)
		_changed())
	return o


func _case(on: bool, on_change: Callable) -> CheckButton:
	var c := CheckButton.new()
	c.button_pressed = on
	c.toggled.connect(func(b: bool) -> void:
		on_change.call(b)
		_changed())
	return c


func _changed() -> void:
	OptionsJeu.sauver()
	OptionsJeu.appliquer(get_tree())


func _onglet_graphismes() -> Control:
	var p := _page("Graphismes")
	_ligne(p, "Affichage", _choix(["Fenêtre", "Plein écran", "Plein écran exclusif"], OptionsJeu.fenetre,
		func(i: int) -> void: OptionsJeu.fenetre = i))
	_ligne(p, "Synchronisation verticale", _case(OptionsJeu.vsync, func(b: bool) -> void: OptionsJeu.vsync = b),
		"Évite les déchirures de l'image ; à couper pour mesurer les performances.")
	var fps_items: Array = []
	for f in OptionsJeu.FPS_CHOIX:
		fps_items.append("Sans limite" if f == 0 else "%d images/s" % f)
	_ligne(p, "Images par seconde max.", _choix(fps_items, maxi(OptionsJeu.FPS_CHOIX.find(OptionsJeu.fps_max), 0),
		func(i: int) -> void: OptionsJeu.fps_max = OptionsJeu.FPS_CHOIX[i]),
		"Limiter fait moins chauffer l'ordinateur portable.")
	var s := HSlider.new()
	s.min_value = 0.5
	s.max_value = 1.0
	s.step = 0.05
	s.value = OptionsJeu.echelle_3d
	s.custom_minimum_size = Vector2(200, 24)
	var sl := Label.new()
	var maj := func(x: float) -> void: sl.text = "%d %%" % roundi(x * 100.0)
	maj.call(s.value)
	s.value_changed.connect(func(x: float) -> void:
		maj.call(x)
		OptionsJeu.echelle_3d = x
		_changed())
	var srow := HBoxContainer.new()
	srow.add_child(s)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.custom_minimum_size = Vector2(56, 0)
	srow.add_child(sl)
	_ligne(p, "Résolution 3D", srow, "En dessous de 100 %, la 3D est calculée plus petite puis agrandie (FSR) : plus fluide, un peu plus flou. Les textes restent nets.")
	_ligne(p, "Ombres", _choix(["Basses", "Moyennes", "Hautes"], OptionsJeu.ombres, func(i: int) -> void: OptionsJeu.ombres = i))
	_ligne(p, "Anticrénelage", _choix(["Aucun", "MSAA 2×", "MSAA 4×"], OptionsJeu.anticrenelage,
		func(i: int) -> void: OptionsJeu.anticrenelage = i))
	_ligne(p, "Rendu poussé", _case(OptionsJeu.rendu_pousse, func(b: bool) -> void: OptionsJeu.rendu_pousse = b),
		"Heures dorées, occlusion ambiante, brume du matin. Prend effet à la prochaine partie chargée.")
	var b := Button.new()
	b.text = "Préréglage : ordinateur modeste"
	b.pressed.connect(func() -> void:
		OptionsJeu.echelle_3d = 0.75
		OptionsJeu.ombres = 0
		OptionsJeu.anticrenelage = 0
		OptionsJeu.rendu_pousse = false
		OptionsJeu.fps_max = 60
		_changed()
		_rebuild(0))
	var b2 := Button.new()
	b2.text = "Préréglage : par défaut"
	b2.pressed.connect(func() -> void:
		OptionsJeu.echelle_3d = 1.0
		OptionsJeu.ombres = 1
		OptionsJeu.anticrenelage = 1
		OptionsJeu.rendu_pousse = true
		OptionsJeu.fps_max = 0
		_changed()
		_rebuild(0))
	var row := HBoxContainer.new()
	row.add_child(b)
	row.add_child(b2)
	p.add_child(row)
	return p


func _onglet_son() -> Control:
	var p := _page("Son")
	for id in OptionsJeu.VOLUMES:
		var s := HSlider.new()
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.01
		s.value = OptionsJeu.volume(id)
		s.custom_minimum_size = Vector2(200, 24)
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var l := Label.new()
		l.custom_minimum_size = Vector2(56, 0)
		l.text = "%d %%" % roundi(s.value * 100.0)
		var vid: String = id
		s.value_changed.connect(func(x: float) -> void:
			l.text = "%d %%" % roundi(x * 100.0)
			OptionsJeu.set_volume(vid, x))
		var row := HBoxContainer.new()
		row.add_child(s)
		row.add_child(l)
		_volumes[id] = s
		_ligne(p, String(OptionsJeu.NOMS_VOLUMES[id]), row)
	var info := Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	info.text = "En jeu, F2 ouvre le panneau Son complet : liste des morceaux, pauses entre les morceaux, couper le son quand la fenêtre n'est pas au premier plan."
	p.add_child(info)
	return p


func _onglet_jeu() -> Control:
	var p := _page("Jeu")
	var items: Array = []
	for m in OptionsJeu.AUTOSAVE_CHOIX:
		items.append("Jamais" if m == 0 else "Toutes les %d minutes" % m)
	_ligne(p, "Sauvegarde automatique", _choix(items, maxi(OptionsJeu.AUTOSAVE_CHOIX.find(OptionsJeu.autosave_min), 0),
		func(i: int) -> void: OptionsJeu.autosave_min = OptionsJeu.AUTOSAVE_CHOIX[i]),
		"Seulement s'il y a eu des changements, dans une partie à part (« Sauvegarde automatique ») : ta partie à toi n'est jamais écrasée.")
	var langues: Array = []
	var sel := 0
	for i in OptionsJeu.LANGUES.size():
		langues.append(OptionsJeu.LANGUES[i][1])
		if OptionsJeu.LANGUES[i][0] == OptionsJeu.langue:
			sel = i
	var lo := _choix(langues, sel, func(i: int) -> void: OptionsJeu.langue = String(OptionsJeu.LANGUES[i][0]))
	for i in range(1, OptionsJeu.LANGUES.size()):
		lo.set_item_disabled(i, true)
	_ligne(p, "Langue", lo, "Le jeu est en français. Les traductions viendront après la démo.")
	_ligne(p, "Écran titre immobile", _case(OptionsJeu.titre_fixe, func(b: bool) -> void: OptionsJeu.titre_fixe = b),
		"La caméra de l'écran titre ne tourne plus autour du village.")
	var dossier := Button.new()
	dossier.text = "Ouvrir le dossier des sauvegardes"
	dossier.pressed.connect(func() -> void:
		DirAccess.make_dir_recursive_absolute(SaveGame.DIR)
		OS.shell_open(ProjectSettings.globalize_path(SaveGame.DIR)))
	p.add_child(dossier)
	return p


func _onglet_touches() -> Control:
	var scroll := ScrollContainer.new()
	scroll.name = "Touches"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var p := _page("Liste")
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(p)
	for sec in TOUCHES:
		var h := Label.new()
		h.text = String(sec[0])
		h.add_theme_font_size_override("font_size", 16)
		h.add_theme_color_override("font_color", UiStyle.ACCENT)
		p.add_child(h)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 16)
		for t in sec[1]:
			var k := Label.new()
			k.text = String(t[0])
			k.custom_minimum_size = Vector2(170, 0)
			k.add_theme_color_override("font_color", UiStyle.ACCENT.lightened(0.3))
			grid.add_child(k)
			var d := Label.new()
			d.text = String(t[1])
			d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			d.custom_minimum_size = Vector2(380, 0)
			grid.add_child(d)
		p.add_child(grid)
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	l.text = "Touches pensées pour un clavier AZERTY (ZQSD) ; en QWERTY, les mêmes touches physiques marchent (WASD). Changer les touches viendra plus tard. Liste complète en jeu : F1."
	p.add_child(l)
	return scroll


func _rebuild(onglet: int) -> void:
	var old := _tabs.get_child(onglet)
	var neuf: Control = [_onglet_graphismes, _onglet_son, _onglet_jeu, _onglet_touches][onglet].call()
	_tabs.add_child(neuf)
	_tabs.move_child(neuf, onglet)
	old.queue_free()
	_tabs.current_tab = onglet


func close_panel() -> void:
	closed.emit()
	queue_free()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close_panel()
