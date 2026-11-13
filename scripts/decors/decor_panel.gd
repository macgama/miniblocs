class_name DecorPanel
extends CanvasLayer
## Panneau « Décors » (touche G) : choisir un décor du catalogue et le poser
## (un par un, en rangée, en clôture), le semer au pinceau, ou gommer.
## On y coupe aussi les décors automatiques (routes, bâtiments, berges, rochers).

## Touche G : ouvrir ou fermer (terre_main range alors les autres outils).
signal bascule_demandee

var decors: DecorSystem
var _panel: PanelContainer
var _cats: OptionButton
var _liste: ItemList
var _outils: Array[Button] = []
var _rayon_label: Label
var _auto: CheckBox
var _ids: Array = []


func _ready() -> void:
	_panel = PanelContainer.new()
	_panel.offset_left = 10
	_panel.offset_top = UiStyle.SIDE_TOP
	UiStyle.style_panel(_panel)
	_panel.custom_minimum_size = Vector2(270, 0)
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_panel.add_child(box)
	var titre := Label.new()
	titre.text = "Décors"
	titre.add_theme_font_size_override("font_size", 17)
	box.add_child(titre)

	var ligne := HBoxContainer.new()
	box.add_child(ligne)
	var groupe := ButtonGroup.new()
	for o in [[DecorSystem.Outil.POSER, "Poser", "Clic : pose le décor choisi. Glisser : une rangée (ou une clôture). R : tourner."],
			[DecorSystem.Outil.PINCEAU, "Pinceau", "Glisser : sème le décor choisi au hasard (troupeau, rochers, bottes de foin…)."],
			[DecorSystem.Outil.GOMME, "Gomme", "Glisser : efface les décors, ceux posés et ceux venus tout seuls."]]:
		var b := Button.new()
		b.text = o[1]
		b.tooltip_text = o[2]
		b.toggle_mode = true
		b.button_group = groupe
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var outil: int = o[0]
		b.pressed.connect(func() -> void:
			if decors:
				decors.set_outil(outil))
		ligne.add_child(b)
		_outils.append(b)

	_cats = OptionButton.new()
	for c: Dictionary in Decors.categories():
		_cats.add_item("%s (%d)" % [c.nom, Decors.de_categorie(c.id).size()])
		_cats.set_item_metadata(_cats.item_count - 1, c.id)
	_cats.item_selected.connect(func(_i: int) -> void: _remplit())
	box.add_child(_cats)

	_liste = ItemList.new()
	_liste.custom_minimum_size = Vector2(250, 300)
	_liste.item_selected.connect(func(i: int) -> void:
		if decors and i < _ids.size():
			decors.set_choix(_ids[i])
			_maj_outils())
	box.add_child(_liste)

	var r := HBoxContainer.new()
	box.add_child(r)
	_rayon_label = Label.new()
	_rayon_label.custom_minimum_size = Vector2(110, 0)
	r.add_child(_rayon_label)
	var s := HSlider.new()
	s.min_value = 1
	s.max_value = 30
	s.step = 1
	s.value = 6
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.value_changed.connect(func(v: float) -> void:
		if decors:
			decors.rayon_pinceau = v
		_rayon_label.text = "Pinceau : %d m" % int(v * 2))
	r.add_child(s)
	_rayon_label.text = "Pinceau : 12 m"

	var r2 := HBoxContainer.new()
	box.add_child(r2)
	var dl := Label.new()
	dl.text = "Densité"
	dl.custom_minimum_size = Vector2(110, 0)
	r2.add_child(dl)
	var ds := HSlider.new()
	ds.min_value = 0.1
	ds.max_value = 1.0
	ds.step = 0.05
	ds.value = 0.5
	ds.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ds.value_changed.connect(func(v: float) -> void:
		if decors:
			decors.densite = v)
	r2.add_child(ds)

	_auto = CheckBox.new()
	_auto.text = "Décors automatiques"
	_auto.tooltip_text = "Bancs et poteaux le long des routes, pontons et bateaux près des bâtiments, rochers et canards sauvages."
	_auto.button_pressed = DecorSystem.auto_actif
	_auto.toggled.connect(func(on: bool) -> void:
		DecorSystem.auto_actif = on
		if decors:
			decors._sale = true)
	box.add_child(_auto)

	var aide := Label.new()
	aide.text = "Clic droit : tourner la caméra. Échap : lâcher l'outil."
	aide.add_theme_font_size_override("font_size", 12)
	aide.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	box.add_child(aide)
	_remplit()
	visible = false


func _remplit() -> void:
	_liste.clear()
	_ids.clear()
	if _cats.item_count == 0:
		return
	var cat := String(_cats.get_item_metadata(_cats.selected))
	for e: Dictionary in Decors.de_categorie(cat):
		var t: Array = e.taille
		_liste.add_item(String(e.nom))
		_liste.set_item_tooltip(_liste.item_count - 1, "%s\n%.1f × %.1f m, %.1f m de haut, %d triangles" % [e.nom, t[0], t[1], t[2], e.triangles])
		_ids.append(e.id)


func _maj_outils() -> void:
	if decors == null:
		return
	for i in _outils.size():
		_outils[i].set_pressed_no_signal(decors.outil == i + 1)


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.physical_keycode == KEY_G and not k.shift_pressed and not k.ctrl_pressed:
		bascule_demandee.emit()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	set_shown(not visible)


func set_shown(on: bool) -> void:
	visible = on
	_auto.set_pressed_no_signal(DecorSystem.auto_actif)
	if decors:
		if on and decors.outil == DecorSystem.Outil.AUCUN:
			decors.set_outil(DecorSystem.Outil.POSER)
		elif not on:
			decors.set_inactive()
	_maj_outils()
