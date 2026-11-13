class_name SonPanel
extends CanvasLayer
## Panneau Son et musique (F2, ou haut-parleur de la barre du haut) : volumes,
## options, morceaux de la liste de lecture.

signal closed

const LIGNES := [
	["general", "Général", "Tout le jeu"],
	["musique", "Musique", "Les morceaux (changent avec l'heure : jour, soir, nuit)"],
	["ambiance", "Ambiance", "Ville, nature, oiseaux, grillons, pluie, vent, mer, trafic, chantiers : selon ce que regarde la caméra"],
	["effets", "Effets", "Constructions, démolitions, sirènes, cloches, tonnerre, fanfares"],
	["interface", "Interface", "Clics des boutons, ouverture des panneaux, nouvelles"],
]

var _son: Son
var _titre: Label
var _valeurs := {}
var _sliders := {}
var _cases := {}


func _init() -> void:
	layer = 60
	name = "PanneauSon"


func _ready() -> void:
	_son = Son.ici()
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			close_panel())
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	var panel := PanelContainer.new()
	UiStyle.style_panel(panel, 0.96, 12, 16)
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)

	var head := HBoxContainer.new()
	v.add_child(head)
	var ic := TextureRect.new()
	ic.texture = Icones.get_icon("son", 24, UiStyle.ACCENT)
	ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(ic)
	var title := Label.new()
	title.text = "Son et musique"
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := Button.new()
	close.text = "Fermer (F2 ou Échap)"
	close.pressed.connect(close_panel)
	head.add_child(close)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 6)
	v.add_child(grid)
	for l in LIGNES:
		var id: String = l[0]
		var lab := Label.new()
		lab.text = l[1]
		lab.tooltip_text = l[2]
		lab.mouse_filter = Control.MOUSE_FILTER_PASS
		lab.custom_minimum_size = Vector2(90, 0)
		grid.add_child(lab)
		var s := HSlider.new()
		s.min_value = 0
		s.max_value = 100
		s.step = 1
		s.custom_minimum_size = Vector2(340, 24)
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.tooltip_text = l[2]
		s.value = roundf(float(_son.volumes[id]) * 100.0)
		s.value_changed.connect(func(x: float) -> void:
			_son.set_volume(id, x / 100.0)
			_valeurs[id].text = "%d %%" % roundi(x)
			if id == "effets":
				Son.jouer("pose_batiment", -6.0))
		grid.add_child(s)
		_sliders[id] = s
		var val := Label.new()
		val.text = "%d %%" % roundi(s.value)
		val.custom_minimum_size = Vector2(50, 0)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(val)
		_valeurs[id] = val

	v.add_child(HSeparator.new())
	var opts := HBoxContainer.new()
	opts.add_theme_constant_override("separation", 16)
	v.add_child(opts)
	_cases.pauses = _case(opts, "Silences entre les morceaux", _son.pauses_musique,
		"Comme à la radio du dimanche : quelques dizaines de secondes de calme entre deux morceaux, pour entendre la ville",
		func(on: bool) -> void:
			_son.pauses_musique = on
			_son.sauver_reglages())
	_cases.focus = _case(opts, "Couper quand le jeu est en arrière-plan", _son.couper_hors_focus,
		"Le son se coupe quand tu passes à une autre fenêtre", func(on: bool) -> void:
			_son.couper_hors_focus = on
			_son.appliquer_volumes()
			_son.sauver_reglages())

	v.add_child(HSeparator.new())
	var now := HBoxContainer.new()
	v.add_child(now)
	_titre = Label.new()
	_titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_titre.add_theme_color_override("font_color", UiStyle.ACCENT)
	now.add_child(_titre)
	var nxt := Button.new()
	nxt.text = "Morceau suivant"
	nxt.pressed.connect(func() -> void: _son.suivant())
	now.add_child(nxt)
	var stop := Button.new()
	stop.text = "Silence"
	stop.tooltip_text = "Arrêter la musique jusqu'au prochain morceau (après une pause)"
	stop.pressed.connect(func() -> void: _son.arreter_musique())
	now.add_child(stop)

	var lst := Label.new()
	lst.text = "Liste de lecture (décocher pour retirer un morceau, ▶ pour l'écouter) :"
	lst.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	v.add_child(lst)
	var hum := {"menu": "globe", "jour": "journée", "soir": "soirée", "nuit": "nuit"}
	for id in Son.MORCEAUX:
		var row := HBoxContainer.new()
		v.add_child(row)
		var cb := CheckBox.new()
		cb.text = "%s  ·  %s" % [Son.MORCEAUX[id][0], hum[Son.MORCEAUX[id][1]]]
		cb.button_pressed = not _son.exclus.has(id)
		cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cb.toggled.connect(func(on: bool) -> void:
			if on:
				_son.exclus.erase(id)
			elif not _son.exclus.has(id):
				_son.exclus.append(id)
			_son.sauver_reglages())
		row.add_child(cb)
		var play := Button.new()
		play.text = "▶"
		play.tooltip_text = "Écouter maintenant"
		play.pressed.connect(func() -> void: _son.lancer(id))
		row.add_child(play)

	var credit := Label.new()
	credit.text = "Sons et musiques fabriqués pour MiniBlocs (tools/build_sons.py), libres de droits (CC0)."
	credit.add_theme_font_size_override("font_size", 11)
	credit.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	v.add_child(credit)

	_son.morceau_change.connect(_maj_titre)
	_maj_titre(_son.titre(_son.morceau))
	Son.jouer("ui_ouvrir", 0.0, 0.0, "Interface")


func _case(parent: Control, text: String, on: bool, tip: String, f: Callable) -> CheckBox:
	var cb := CheckBox.new()
	cb.text = text
	cb.tooltip_text = tip
	cb.button_pressed = on
	cb.toggled.connect(f)
	parent.add_child(cb)
	return cb


func _maj_titre(t: String) -> void:
	if _titre != null:
		_titre.text = ("♪  " + t) if t != "" else "♪  (silence)"


func close_panel() -> void:
	Son.jouer("ui_fermer", 0.0, 0.0, "Interface")
	closed.emit()
	queue_free()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and (k.keycode == KEY_ESCAPE or k.keycode == KEY_F2):
		get_viewport().set_input_as_handled()
		close_panel()
