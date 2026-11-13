class_name CartesPanel
extends CanvasLayer
## Panneau « Cartes » (touche M) : les cartes de couleur de tous les systèmes
## (registre Calques), rangées par groupe. Une seule carte à la fois ; fermer le
## panneau éteint la carte. En bas, un résumé fourni par le jeu (resume).

const W := 330.0

## Lignes de résumé sous les cartes : Callable() -> Array de String.
var resume: Callable
var _panel: PanelContainer
var _list: VBoxContainer
var _legend: Label
var _resume: Label
var _buttons: Dictionary = {}
var _count := -1
var _tick := 0.0


func _ready() -> void:
	layer = 6
	_panel = PanelContainer.new()
	UiStyle.place_right(_panel)
	_panel.custom_minimum_size = Vector2(W, 0)
	UiStyle.style_panel(_panel)
	_panel.visible = false
	add_child(_panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 6)
	_panel.add_child(outer)
	var head := HBoxContainer.new()
	outer.add_child(head)
	var icon := TextureRect.new()
	icon.texture = Icones.get_icon("cartes", 22, UiStyle.ACCENT)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(icon)
	var title := Label.new()
	title.text = "Cartes"
	title.add_theme_font_size_override("font_size", 16)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var x := UiStyle.icon_button("fermer", "Fermer", "M", 18, 32)
	x.pressed.connect(func() -> void: set_open(false))
	head.add_child(x)
	var hint := Label.new()
	hint.text = "Une carte de couleur sur le terrain autour de la caméra. Survole une case pour lire ses valeurs."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(W - 24, 0)
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
	outer.add_child(hint)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 3)
	outer.add_child(_list)
	_legend = Label.new()
	_legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_legend.custom_minimum_size = Vector2(W - 24, 0)
	_legend.add_theme_font_size_override("font_size", 12)
	outer.add_child(_legend)
	outer.add_child(HSeparator.new())
	_resume = Label.new()
	_resume.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_resume.custom_minimum_size = Vector2(W - 24, 0)
	_resume.add_theme_font_size_override("font_size", 12)
	outer.add_child(_resume)


func is_open() -> bool:
	return _panel != null and _panel.visible


func set_open(on: bool) -> void:
	_panel.visible = on
	if on:
		refresh()
	else:
		Calques.eteindre()


func toggle() -> void:
	set_open(not _panel.visible)


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.physical_keycode == KEY_M and not k.shift_pressed and not k.ctrl_pressed:
		toggle()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not is_open():
		return
	_tick += delta
	if Calques.liste().size() != _count:
		refresh()
	elif _tick >= 1.0:
		_tick = 0.0
		_update_texts()


## Montre une carte (ou l'éteint si elle est déjà montrée).
func choisir(id: String) -> void:
	Calques.afficher(id, Calques.actif() != id)
	_update_buttons()
	_update_texts()


func refresh() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_buttons.clear()
	var all := Calques.liste()
	_count = all.size()
	if all.is_empty():
		var l := Label.new()
		l.text = "Aucune carte pour l'instant."
		_list.add_child(l)
	for g in Calques.groupes():
		var gl := Label.new()
		gl.text = String(g)
		gl.add_theme_font_size_override("font_size", 13)
		gl.add_theme_color_override("font_color", UiStyle.ACCENT)
		_list.add_child(gl)
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 4)
		flow.add_theme_constant_override("v_separation", 4)
		_list.add_child(flow)
		for c in all:
			if c.groupe != g:
				continue
			var b := Button.new()
			b.text = String(c.nom)
			b.toggle_mode = true
			b.focus_mode = Control.FOCUS_NONE
			var id := String(c.id)
			b.pressed.connect(func() -> void: choisir(id))
			flow.add_child(b)
			_buttons[id] = b
	_update_buttons()
	_update_texts()


func _update_buttons() -> void:
	for id in _buttons:
		(_buttons[id] as Button).set_pressed_no_signal(Calques.actif() == id)


func _update_texts() -> void:
	var a := Calques.actif()
	_legend.text = ""
	for c in Calques.liste():
		if c.id == a:
			_legend.text = "%s : %s" % [c.nom, c.legende] if String(c.legende) != "" else String(c.nom)
	if _legend.text == "":
		_legend.text = "Choisis une carte."
	_resume.text = "\n".join(resume.call()) if resume.is_valid() else ""
