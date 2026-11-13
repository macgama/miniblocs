class_name TelecomPanel
extends CanvasLayer
## Panneau « Internet et téléphone » (Maj + O) : bilan du réseau, outils pour
## poser la fibre et les lignes sur poteaux, calques de couverture mobile et de
## débit, et le service du bâtiment survolé.
## Le contenu (TelecomVue) peut aussi être un onglet du panneau Réseaux (O).

const W := 348.0
const H := 560.0

var tel: Telecom
var vue: TelecomVue
var _panel: PanelContainer


func setup(t: Telecom) -> void:
	tel = t
	layer = 6
	_panel = PanelContainer.new()
	UiStyle.place_right(_panel)
	_panel.custom_minimum_size = Vector2(W, 0)
	UiStyle.style_panel(_panel)
	_panel.visible = false
	add_child(_panel)
	var outer := VBoxContainer.new()
	_panel.add_child(outer)
	var head := HBoxContainer.new()
	outer.add_child(head)
	var icon := TextureRect.new()
	icon.texture = Icones.get_icon("services", 22, UiStyle.ACCENT)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(icon)
	var title := Label.new()
	title.text = "Internet et téléphone"
	title.add_theme_font_size_override("font_size", 16)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var x := UiStyle.icon_button("fermer", "Fermer", "Maj+O", 18, 32)
	x.pressed.connect(func() -> void: set_open(false))
	head.add_child(x)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(W, H)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	vue = TelecomVue.new()
	vue.setup(t, W - 24.0)
	scroll.add_child(vue)


func is_open() -> bool:
	return _panel != null and _panel.visible


func set_open(on: bool) -> void:
	_panel.visible = on
	if on:
		vue.refresh()
	else:
		vue.rangement()


func toggle() -> void:
	set_open(not is_open())


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.physical_keycode == KEY_O and k.shift_pressed and not k.ctrl_pressed:
		toggle()
		get_viewport().set_input_as_handled()
