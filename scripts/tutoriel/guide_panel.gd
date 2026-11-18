class_name GuidePanel
extends CanvasLayer
## Panneau « Guide » (Ctrl+F1) : tous les chapitres du guide en bulles, rangés par
## thème, avec ceux déjà vus. Un clic sur « Voir » lance le chapitre.

const W := 600.0
const H := 600.0

var guide: Guide
var _panel: PanelContainer
var _body: VBoxContainer
var _proposer: CheckBox
var _resume_l: Label


func setup(g: Guide) -> void:
	guide = g
	_build()
	guide.changed.connect(func() -> void:
		if is_open():
			refresh())


func _build() -> void:
	layer = 8
	_panel = PanelContainer.new()
	_panel.name = "PanneauGuide"
	UiStyle.style_panel(_panel, 0.95, 14, 14)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(W, 0)
	_panel.visible = false
	add_child(_panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	_panel.add_child(outer)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	outer.add_child(head)
	var ic := TextureRect.new()
	ic.texture = Icones.get_icon("aide", 22, UiStyle.ACCENT)
	ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(ic)
	var title := Label.new()
	title.text = "Guide du maire"
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var x := UiStyle.icon_button("fermer", "Fermer", "Ctrl+F1", 18, 32)
	x.pressed.connect(func() -> void: set_open(false))
	head.add_child(x)
	_resume_l = Label.new()
	_resume_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_resume_l.custom_minimum_size = Vector2(W - 30, 0)
	_resume_l.add_theme_font_size_override("font_size", 13)
	_resume_l.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	outer.add_child(_resume_l)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(W, H)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 4)
	scroll.add_child(_body)
	var bas := HBoxContainer.new()
	bas.add_theme_constant_override("separation", 8)
	outer.add_child(bas)
	_proposer = CheckBox.new()
	_proposer.text = "Proposer une visite quand je découvre une fonction"
	_proposer.focus_mode = Control.FOCUS_NONE
	_proposer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_proposer.toggled.connect(func(on: bool) -> void: guide.set_proposer(on))
	bas.add_child(_proposer)
	var zero := Button.new()
	zero.text = "Tout revoir"
	zero.tooltip_text = "Tous les chapitres redeviennent nouveaux et seront reproposés"
	zero.focus_mode = Control.FOCUS_NONE
	zero.pressed.connect(func() -> void: guide.oublier())
	bas.add_child(zero)


func is_open() -> bool:
	return _panel.visible


func set_open(on: bool) -> void:
	_panel.visible = on
	if on:
		refresh()
		_panel.reset_size()
		_panel.position = (_panel.get_viewport_rect().size - _panel.size) * 0.5


func toggle() -> void:
	set_open(not is_open())


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	# Ctrl+F1 : la barre (TerreHud.guide_requested) ouvre et ferme le panneau.
	if k.keycode == KEY_ESCAPE and is_open():
		set_open(false)
		get_viewport().set_input_as_handled()


func refresh() -> void:
	if guide == null:
		return
	_proposer.set_pressed_no_signal(guide.proposer)
	_resume_l.text = "Un chapitre par fonction du jeu, en quelques bulles qui montrent où cliquer. Chapitres vus : %d / %d." % [
		guide.nb_vus(), Guide.CHAPITRES.size()]
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	var theme := ""
	for ch in Guide.CHAPITRES:
		if String(ch.theme) != theme:
			theme = String(ch.theme)
			if _body.get_child_count() > 0:
				_body.add_child(HSeparator.new())
			var t := Label.new()
			t.text = theme
			t.add_theme_font_size_override("font_size", 15)
			t.add_theme_color_override("font_color", UiStyle.ACCENT)
			_body.add_child(t)
		_body.add_child(_ligne(ch))


func _ligne(ch: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var ic := TextureRect.new()
	ic.texture = Icones.get_icon(String(ch.icone), 24, UiStyle.TEXT)
	ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	ic.custom_minimum_size = Vector2(28, 28)
	row.add_child(ic)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	row.add_child(v)
	var vu := guide.est_vu(String(ch.id))
	var t := Label.new()
	t.text = ("✓ " if vu else "") + String(ch.titre)
	t.add_theme_font_size_override("font_size", 14)
	t.add_theme_color_override("font_color", UiStyle.GOOD if vu else UiStyle.TEXT)
	v.add_child(t)
	var r := Label.new()
	r.text = String(ch.resume)
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.custom_minimum_size = Vector2(W - 170, 0)
	r.add_theme_font_size_override("font_size", 12)
	r.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	v.add_child(r)
	var b := Button.new()
	b.text = "Revoir" if vu else "Voir"
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(80, 32)
	var id := String(ch.id)
	b.pressed.connect(func() -> void:
		set_open(false)
		guide.lancer(id))
	row.add_child(b)
	return row
