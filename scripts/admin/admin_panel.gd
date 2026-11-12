class_name AdminPanel
extends Control
## Panneau Admin (F10, ou bouton de la barre du haut) : réglages de la partie.
## Sur le globe, le même panneau sert à régler la partie avant de la commencer.
## Chaque changement s'applique tout de suite (signal settings_changed).

signal settings_changed
signal closed
## Admin : mettre la caisse du joueur à ce montant (en cours de partie).
signal caisse_set(amount: int)

var reglages: ReglagesPartie
## true : avant la partie (globe) ; false : en cours de partie.
var creation := false
var editable := true
## Caisse actuelle (en cours de partie), -1 pour ne pas l'afficher.
var caisse := -1

var _filling := false
var _preset_label: Label
var _argent: SpinBox
var _illimite: CheckBox
var _caisse: SpinBox
var _cout: HSlider
var _cout_l: Label
var _acces: CheckBox
var _deblocage: OptionButton
var _paliers_l: Label
var _impots: HSlider
var _impots_l: Label
var _salaires: HSlider
var _salaires_l: Label
var _temps: OptionButton
var _vie: OptionButton
var _epuisement: CheckBox
var _ev_auto: CheckBox
var _catas: CheckBox
var _freq: OptionButton
const FREQS := [0.25, 1.0, 3.0]
var _status: Label


func _init(r: ReglagesPartie = null, at_creation := false, can_edit := true, money := -1) -> void:
	reglages = r if r != null else ReglagesPartie.actuel
	creation = at_creation
	editable = can_edit
	caisse = money


func _ready() -> void:
	name = "PanneauAdmin"
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
	UiStyle.style_panel(panel, 0.96, 12, 16)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	# Titre.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)
	var ic := TextureRect.new()
	ic.texture = Icones.get_icon("admin", 26, UiStyle.ACCENT)
	ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(ic)
	var title := Label.new()
	title.text = "Réglages de la nouvelle partie" if creation else "Admin : réglages de la partie"
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := UiStyle.icon_button("fermer", "Fermer (F10 ou Échap)")
	close.pressed.connect(close_panel)
	head.add_child(close)

	var who := _label(ReglagesPartie.qui_est_admin(int(GameStart.mode)) if editable
		else "Lecture seule : " + ReglagesPartie.qui_est_admin(int(GameStart.mode)).to_lower(), 13, UiStyle.TEXT_DIM)
	v.add_child(who)

	# Préréglages.
	var pr := HBoxContainer.new()
	pr.add_theme_constant_override("separation", 6)
	v.add_child(pr)
	pr.add_child(_label("Préréglage :", 14))
	for id in ReglagesPartie.PRESETS:
		var b := Button.new()
		b.text = String(ReglagesPartie.PRESETS[id].nom)
		b.disabled = not editable
		var pid: String = id
		b.pressed.connect(func() -> void:
			reglages.apply_preset(pid)
			_fill()
			_emit())
		pr.add_child(b)
	_preset_label = _label("", 14, UiStyle.ACCENT)
	pr.add_child(_preset_label)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 28)
	v.add_child(cols)
	var left := _column(cols)
	var right := _column(cols)

	# Argent.
	var g := _section(left, "Argent", "budget")
	_argent = _spin(0, ReglagesPartie.ARGENT_MAX, 100_000, " €")
	_row(g, "Argent de départ de chaque joueur", _argent)
	_illimite = _check("Argent illimité")
	g.add_child(_illimite)
	if not creation and caisse >= 0:
		var crow := HBoxContainer.new()
		_caisse = _spin(0, ReglagesPartie.ARGENT_MAX, 100_000, " €")
		_caisse.value = caisse
		crow.add_child(_caisse)
		var set_btn := Button.new()
		set_btn.text = "Mettre la caisse à ce montant"
		set_btn.disabled = not editable
		set_btn.pressed.connect(func() -> void:
			caisse = int(_caisse.value)
			caisse_set.emit(caisse)
			_status.text = "Caisse mise à %s." % BuildingSystem.format_money(caisse))
		crow.add_child(set_btn)
		_row(g, "Caisse actuelle", crow)

	# Construction.
	g = _section(left, "Construction", "construire")
	var c := _slider(ReglagesPartie.COUT_MIN, ReglagesPartie.COUT_MAX, 0.25)
	_cout = c[0]
	_cout_l = c[1]
	_row(g, "Coût des constructions", c[2])
	_acces = _check("Accès à une voie obligatoire pour construire")
	g.add_child(_acces)
	_deblocage = OptionButton.new()
	_deblocage.add_item("Tout débloqué d'office")
	_deblocage.add_item("Au fil de la partie (paliers de population)")
	_deblocage.disabled = not editable
	_deblocage.item_selected.connect(func(_i: int) -> void: _changed())
	_row(g, "Bâtiments", _deblocage)
	_paliers_l = _label("", 12, UiStyle.TEXT_DIM)
	_paliers_l.custom_minimum_size = Vector2(400, 0)
	_paliers_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	g.add_child(_paliers_l)

	# Économie.
	g = _section(right, "Économie", "habitants")
	c = _slider(0.0, ReglagesPartie.IMPOTS_MAX, 0.25)
	_impots = c[0]
	_impots_l = c[1]
	_row(g, "Impôts touchés par la ville", c[2])
	c = _slider(ReglagesPartie.SALAIRES_MIN, ReglagesPartie.SALAIRES_MAX, 0.05)
	_salaires = c[0]
	_salaires_l = c[1]
	_row(g, "Salaires", c[2])

	# Temps.
	g = _section(right, "Temps", "horloge")
	_temps = OptionButton.new()
	for n in DayNight.SPEED_NAMES:
		_temps.add_item(n)
	_temps.disabled = not editable
	_temps.item_selected.connect(func(_i: int) -> void: _changed())
	_row(g, "Vitesse du temps", _temps)
	_vie = OptionButton.new()
	for n in Population.LIFE_SPEED_NAMES:
		_vie.add_item(n)
	_vie.disabled = not editable
	_vie.item_selected.connect(func(_i: int) -> void: _changed())
	_row(g, "Vitesse de la vie", _vie)

	# Ressources.
	g = _section(right, "Ressources", "ressources")
	_epuisement = _check("Épuisement des ressources (mines, puits, forêts et poissons surexploités)")
	g.add_child(_epuisement)

	# Événements de la ville.
	g = _section(right, "Événements", "infos")
	_ev_auto = _check("Fêtes, marchés et matchs organisés tout seuls")
	g.add_child(_ev_auto)
	_catas = _check("Catastrophes au hasard (incendies, tempêtes, épidémies)")
	g.add_child(_catas)
	_freq = OptionButton.new()
	for n in ["Rares", "Normales", "Fréquentes"]:
		_freq.add_item(n)
	_freq.disabled = not editable
	_freq.item_selected.connect(func(_i: int) -> void: _changed())
	_row(g, "Fréquence des catastrophes", _freq)

	# Pied.
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 8)
	v.add_child(foot)
	_status = _label("", 13, UiStyle.GOOD)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(_status)
	var keep := Button.new()
	keep.text = "Garder par défaut"
	keep.tooltip_text = "Ces réglages seront proposés pour toutes les nouvelles parties"
	keep.pressed.connect(func() -> void:
		_status.text = "Réglages gardés pour les nouvelles parties." if reglages.save_as_defaults() else "Impossible d'écrire le fichier des réglages.")
	foot.add_child(keep)
	var ok := Button.new()
	ok.text = "Valider" if creation else "Fermer"
	ok.custom_minimum_size = Vector2(110, 0)
	ok.pressed.connect(close_panel)
	foot.add_child(ok)
	_fill()


# --- Contrôles ------------------------------------------------------------------------

func _label(text: String, size := 14, color := UiStyle.TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _column(parent: Control) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.custom_minimum_size = Vector2(430, 0)
	parent.add_child(col)
	return col


func _section(parent: Control, title: String, icon: String) -> VBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	parent.add_child(h)
	var ic := TextureRect.new()
	ic.texture = Icones.get_icon(icon, 18, UiStyle.ACCENT)
	ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	h.add_child(ic)
	h.add_child(_label(title, 16, UiStyle.ACCENT))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	parent.add_child(box)
	return box


func _row(parent: Control, text: String, ctrl: Control) -> void:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 8)
	var l := _label(text, 13)
	l.custom_minimum_size = Vector2(170, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.add_child(l)
	ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(ctrl)
	parent.add_child(r)


func _spin(lo: float, hi: float, step: float, suffix: String) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 1000
	s.custom_arrow_step = step
	s.suffix = suffix
	s.custom_minimum_size = Vector2(170, 0)
	s.editable = editable
	s.value_changed.connect(func(_x: float) -> void: _changed())
	return s


func _check(text: String) -> CheckBox:
	var b := CheckBox.new()
	b.text = text
	b.disabled = not editable
	b.toggled.connect(func(_on: bool) -> void: _changed())
	return b


## [HSlider, Label de la valeur, ligne qui les contient].
func _slider(lo: float, hi: float, step: float) -> Array:
	var h := HBoxContainer.new()
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.editable = editable
	h.add_child(s)
	var l := _label("", 14, UiStyle.ACCENT)
	l.custom_minimum_size = Vector2(56, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(l)
	s.value_changed.connect(func(_x: float) -> void: _changed())
	return [s, l, h]


# --- Valeurs --------------------------------------------------------------------------

## Remplit les contrôles depuis les réglages.
func _fill() -> void:
	_filling = true
	_argent.value = reglages.argent_depart
	_illimite.button_pressed = reglages.argent_illimite
	_cout.value = reglages.cout_construction
	_acces.button_pressed = reglages.acces_route
	_deblocage.select(1 if reglages.deblocage == "progression" else 0)
	_impots.value = reglages.impots
	_salaires.value = reglages.salaires
	_temps.select(reglages.vitesse_temps)
	_vie.select(reglages.vitesse_vie)
	_epuisement.button_pressed = reglages.epuisement
	_ev_auto.button_pressed = reglages.evenements_auto
	_catas.button_pressed = reglages.catastrophes
	var fi := 1
	for i in FREQS.size():
		if absf(float(FREQS[i]) - reglages.frequence_catastrophes) < 0.01:
			fi = i
	_freq.select(fi)
	_filling = false
	_update_labels()


func _changed() -> void:
	if _filling or not editable:
		return
	reglages.argent_depart = int(_argent.value)
	reglages.argent_illimite = _illimite.button_pressed
	reglages.cout_construction = _cout.value
	reglages.acces_route = _acces.button_pressed
	reglages.deblocage = "progression" if _deblocage.selected == 1 else "tout"
	reglages.impots = _impots.value
	reglages.salaires = _salaires.value
	reglages.vitesse_temps = maxi(0, _temps.selected)
	reglages.vitesse_vie = maxi(0, _vie.selected)
	reglages.epuisement = _epuisement.button_pressed
	reglages.evenements_auto = _ev_auto.button_pressed
	reglages.catastrophes = _catas.button_pressed
	reglages.frequence_catastrophes = float(FREQS[maxi(0, _freq.selected)])
	_emit()


func _emit() -> void:
	_update_labels()
	settings_changed.emit()


func _update_labels() -> void:
	_cout_l.text = "×" + ReglagesPartie._fmt(_cout.value)
	_impots_l.text = "×" + ReglagesPartie._fmt(_impots.value)
	_salaires_l.text = "×" + ReglagesPartie._fmt(_salaires.value)
	_preset_label.text = reglages.preset_name()
	_argent.editable = editable and not _illimite.button_pressed
	if _caisse:
		_caisse.editable = editable and not _illimite.button_pressed
	var parts: Array[String] = []
	for p in ReglagesPartie.PALIERS:
		var m := int(p.prix_max)
		parts.append("%s (%d hab.) : %s" % [p.nom, int(p.habitants), "tout" if m < 0 else "jusqu'à " + BuildingSystem.format_short(m)])
	var t := "Paliers : " + " · ".join(parts) + ". Écoles et production toujours ouvertes."
	if not creation and reglages.deblocage == "progression":
		t += "\nPalier atteint : %s (record %d habitants)." % [ReglagesPartie.PALIERS[reglages.palier_atteint()].nom, reglages.record_habitants]
	_paliers_l.text = t
	_paliers_l.visible = reglages.deblocage == "progression"


func close_panel() -> void:
	closed.emit()
	queue_free()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and (k.keycode == KEY_ESCAPE or k.keycode == KEY_F10):
		get_viewport().set_input_as_handled()
		close_panel()
