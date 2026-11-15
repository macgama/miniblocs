class_name ScenariosPanel
extends Control
## Fenêtre « Scénarios et défis » du menu principal : la liste des scénarios
## à gauche (difficulté, meilleure médaille), le scénario choisi à droite
## (histoire, lieu, durée, objectifs, règles) avec son classement, et
## « Jouer ».

signal closed
signal jouer(id: String)

var choisi := ""
var _liste: VBoxContainer
var _detail: VBoxContainer
var _boutons := {}


func _ready() -> void:
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
	panel.name = "Scenarios"
	panel.custom_minimum_size = Vector2(1100, 780)
	UiStyle.style_panel(panel, 0.96, 14, 18)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var t := _label("Scénarios et défis", 26, UiStyle.ACCENT, 0.0)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var x := Button.new()
	x.text = "Fermer (Échap)"
	x.pressed.connect(fermer)
	head.add_child(x)
	v.add_child(_label("Un lieu, des règles, une date limite. Remplis les objectifs le plus vite possible pour gagner des points et une médaille.", 14, UiStyle.TEXT_DIM, 1000.0))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(h)
	var ls := ScrollContainer.new()
	ls.custom_minimum_size = Vector2(330, 0)
	ls.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	h.add_child(ls)
	_liste = VBoxContainer.new()
	_liste.add_theme_constant_override("separation", 6)
	ls.add_child(_liste)
	var ds := ScrollContainer.new()
	ds.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ds.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	h.add_child(ds)
	_detail = VBoxContainer.new()
	_detail.name = "Detail"
	_detail.add_theme_constant_override("separation", 8)
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ds.add_child(_detail)
	for id in Scenarios.ids():
		_ajouter_bouton(String(id))
	choisir(String(Scenarios.ids()[0]))
	(_boutons[choisi] as Button).grab_focus.call_deferred()


func _ajouter_bouton(id: String) -> void:
	var s := Scenarios.donnees(id)
	var b := Button.new()
	b.name = id
	b.toggle_mode = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(310, 56)
	b.icon = Icones.get_icon(String(s.get("icone", "trophee")), 22)
	var med := Classement.meilleure_medaille(id)
	var etoiles := "●".repeat(int(s.difficulte)) + "○".repeat(3 - int(s.difficulte))
	b.text = "%s\n%s%s" % [String(s.nom), etoiles, ("   · " + String(Scenarios.NOMS_MEDAILLES[med])) if med > 0 else ""]
	if med > 0:
		b.add_theme_color_override("icon_normal_color", Scenarios.COULEURS_MEDAILLES[med])
	b.pressed.connect(func() -> void: choisir(id))
	_liste.add_child(b)
	_boutons[id] = b


func choisir(id: String) -> void:
	choisi = id
	for k in _boutons:
		(_boutons[k] as Button).button_pressed = k == id
	for c in _detail.get_children():
		_detail.remove_child(c)
		c.queue_free()
	var s := Scenarios.donnees(id)
	_detail.add_child(_label(String(s.nom), 22, UiStyle.ACCENT))
	_detail.add_child(_label("%s · %s · %d jours de jeu (environ %d min à la vitesse normale)" % [
		String(s.lieu.nom), String(Scenarios.NOMS_DIFFICULTE[int(s.difficulte)]), int(s.jours), int(s.jours)], 13, UiStyle.TEXT_DIM))
	_detail.add_child(_label(String(s.histoire), 14))
	_detail.add_child(_label("Objectifs", 16, UiStyle.ACCENT))
	for o in s.get("objectifs", []):
		_detail.add_child(_label("○ " + String(o.texte), 14))
	var bonus: Array = s.get("bonus", [])
	if not bonus.is_empty():
		_detail.add_child(_label("Bonus (+%d points chacun)" % Scenarios.POINTS_BONUS, 14, UiStyle.TEXT_DIM))
		for o in bonus:
			_detail.add_child(_label("○ " + String(o.texte), 13, UiStyle.TEXT_DIM))
	var rappel := ScenarioCarte._rappel_contraintes(s.get("contraintes", {}))
	if rappel != "":
		_detail.add_child(_label(rappel, 13, UiStyle.TEXT_DIM))
	var m: Dictionary = s.get("medailles", {})
	_detail.add_child(_label("Médailles : bronze en réussissant, argent dès %d points, or dès %d points." % [
		int(m.get("argent", 0)), int(m.get("or", 0))], 13, UiStyle.TEXT_DIM))
	var jouer_b := Button.new()
	jouer_b.name = "Jouer"
	jouer_b.text = "Jouer ce scénario"
	jouer_b.custom_minimum_size = Vector2(240, 44)
	jouer_b.add_theme_font_size_override("font_size", 18)
	jouer_b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	for st in ["normal", "hover", "focus", "pressed"]:
		jouer_b.add_theme_stylebox_override(st, UiStyle.flat_box(UiStyle.ACCENT if st == "normal" else UiStyle.ACCENT.lightened(0.15), 10, 10))
	for st in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		jouer_b.add_theme_color_override(st, UiStyle.ACCENT_INK)
	jouer_b.pressed.connect(func() -> void: jouer.emit(id))
	_detail.add_child(jouer_b)
	_detail.add_child(_label("Classement" + (" (en ligne)" if Classement.en_ligne() else " (sur cet ordinateur)"), 16, UiStyle.ACCENT))
	var l: Array = Classement.lecture_en_ligne.call(id) if Classement.en_ligne() else Classement.liste(id)
	if l.is_empty():
		_detail.add_child(_label("Personne n'a encore réussi ce scénario. La première place t'attend.", 13, UiStyle.TEXT_DIM))
		return
	var g := GridContainer.new()
	g.name = "Classement"
	g.columns = 5
	g.add_theme_constant_override("h_separation", 18)
	_detail.add_child(g)
	for i in l.size():
		var e: Dictionary = l[i]
		var med := int(e.get("medaille", 0))
		g.add_child(_label("%d." % (i + 1), 13, UiStyle.TEXT_DIM, 30.0))
		g.add_child(_label(String(e.get("nom", "?")), 13, UiStyle.TEXT, 200.0))
		g.add_child(_label("%d pts" % int(e.get("score", 0)), 13, UiStyle.ACCENT, 90.0))
		g.add_child(_label("%d jours" % int(e.get("jours", 0)), 13, UiStyle.TEXT_DIM, 80.0))
		g.add_child(_label(String(Scenarios.NOMS_MEDAILLES[med]), 13, Scenarios.COULEURS_MEDAILLES[med], 70.0))


func fermer() -> void:
	closed.emit()
	queue_free()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		fermer()


func _label(t: String, size := 14, col := UiStyle.TEXT, w := 660.0) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if w > 0.0 else TextServer.AUTOWRAP_OFF
	l.custom_minimum_size = Vector2(w, 0)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l
