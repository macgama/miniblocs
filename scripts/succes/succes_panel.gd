class_name SuccesPanel
extends Control
## Fenêtre « Succès » (menu principal, et en partie : F6 ou menu Infos) : tous les
## succès du joueur, débloqués ou non, avec l'avancement des compteurs. Les succès
## secrets restent cachés tant qu'ils ne sont pas débloqués.

signal closed

const W := 720.0
const H := 560.0

var filtre := "tous"
var _liste: VBoxContainer
var _titre: Label
var _onglets := {}


func _ready() -> void:
	Succes.charger()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	UiStyle.style_panel(panel, 0.97, 12, 16)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var ic := TextureRect.new()
	ic.texture = Icones.get_icon("trophee", 26, UiStyle.ACCENT)
	ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(ic)
	_titre = Label.new()
	_titre.add_theme_font_size_override("font_size", 24)
	_titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_titre)
	var close := Button.new()
	close.name = "Fermer"
	close.text = "Fermer (Échap)"
	close.pressed.connect(close_panel)
	head.add_child(close)
	var tabs := HBoxContainer.new()
	v.add_child(tabs)
	for spec in [["tous", "Tous"], ["debloques", "Débloqués"], ["a_faire", "À faire"]]:
		var b := Button.new()
		b.text = String(spec[1])
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var f := String(spec[0])
		b.pressed.connect(func() -> void:
			filtre = f
			refresh())
		tabs.add_child(b)
		_onglets[f] = b
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(W, H)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var marge := MarginContainer.new()
	marge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	marge.add_theme_constant_override("margin_right", 14)
	scroll.add_child(marge)
	_liste = VBoxContainer.new()
	_liste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_liste.add_theme_constant_override("separation", 6)
	marge.add_child(_liste)
	var note := Label.new()
	note.add_theme_font_size_override("font_size", 12)
	note.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(W, 0)
	note.text = "Steam : connecté, tes succès y sont reportés." if SteamPont.actif() \
		else "Tes succès sont gardés sur cet ordinateur et valent pour toutes tes parties. Ils passeront sur Steam à la sortie du jeu."
	v.add_child(note)
	refresh()
	(_onglets[filtre] as Button).grab_focus.call_deferred()


func refresh() -> void:
	_titre.text = "Succès : %d / %d" % [Succes.nombre(), Succes.total()]
	for f in _onglets:
		(_onglets[f] as Button).button_pressed = f == filtre
	for c in _liste.get_children():
		c.queue_free()
	# Les derniers débloqués en premier, puis les autres dans l'ordre du catalogue.
	var faits: Array = []
	var reste: Array = []
	for s in Succes.catalogue():
		(faits if Succes.est_debloque(String(s.id)) else reste).append(s)
	faits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(Succes.debloques.get(String(a.id), 0)) > int(Succes.debloques.get(String(b.id), 0)))
	for s in faits + reste:
		var ok := Succes.est_debloque(String(s.id))
		if filtre == "debloques" and not ok or filtre == "a_faire" and ok:
			continue
		_liste.add_child(_ligne(s, ok))


func _ligne(s: Dictionary, ok: bool) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiStyle.flat_box(Color(1, 1, 1, 0.07 if ok else 0.03), 9, 8))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	var cache: bool = bool(s.get("cache", false)) and not ok
	var ic := TextureRect.new()
	ic.texture = badge("cadenas" if cache else String(s.get("icone", "trophee")), ok, 48)
	ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	h.add_child(ic)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	h.add_child(v)
	var n := Label.new()
	n.text = "Succès secret" if cache else String(s.nom)
	n.add_theme_font_size_override("font_size", 16)
	n.add_theme_color_override("font_color", UiStyle.ACCENT if ok else UiStyle.TEXT)
	v.add_child(n)
	var d := Label.new()
	d.text = "Continue à jouer, il viendra peut-être tout seul." if cache else String(s.desc)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.add_theme_font_size_override("font_size", 13)
	d.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	v.add_child(d)
	var av := Succes.avancement(String(s.id))
	if not ok and av >= 0.0 and not cache:
		var bar := ProgressBar.new()
		bar.min_value = 0.0
		bar.max_value = 1.0
		bar.value = av
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 8)
		v.add_child(bar)
		var t := Label.new()
		t.text = "%s / %s" % [_nombre(Succes.stat(String(s.stat)), String(s.stat)), _nombre(float(s.seuil), String(s.stat))]
		t.add_theme_font_size_override("font_size", 11)
		t.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
		v.add_child(t)
	if ok:
		var date := Label.new()
		date.text = PartiesPanel.format_date(int(Succes.debloques.get(String(s.id), 0)))
		date.add_theme_font_size_override("font_size", 11)
		date.add_theme_color_override("font_color", UiStyle.GOOD)
		h.add_child(date)
	return p


static func _nombre(v: float, stat: String) -> String:
	if stat == "route_m":
		return "%s km" % String.num(snappedf(v / 1000.0, 0.1), 1).replace(".", ",")
	if stat == "caisse":
		return BuildingSystem.format_money(int(v))
	if stat == "pause_s":
		return "%d min" % floori(v / 60.0)
	return Statistiques._milliers(floori(v))


## Médaille ronde : fond doré (débloqué) ou gris (pas encore), icône au milieu.
## Sert aussi aux icônes Steam (tools/steam, 256 px).
static var _badges := {}


static func badge(icone: String, ok: bool, px := 48) -> Texture2D:
	var key := "%s|%s|%d" % [icone, ok, px]
	if _badges.has(key):
		return _badges[key]
	var tex := ImageTexture.create_from_image(badge_image(icone, ok, px))
	_badges[key] = tex
	return tex


static func badge_image(icone: String, ok: bool, px := 48) -> Image:
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	var fond := Color("ffd166") if ok else Color("4a5550")
	var bord := Color("b8862b") if ok else Color("2e3633")
	var c := Vector2(px, px) * 0.5
	var r := px * 0.5 - 1.0
	for y in px:
		for x in px:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			if d > r + 0.5:
				continue
			var a := clampf(r + 0.5 - d, 0.0, 1.0)
			var col := bord if d > r - px * 0.07 else fond.lerp(fond.lightened(0.25), clampf(1.0 - (y as float) / px, 0.0, 1.0) * 0.6)
			col.a = a
			img.set_pixel(x, y, col)
	var ink := UiStyle.ACCENT_INK if ok else Color("aeb8b2")
	var isz := int(px * 0.58)
	var icon := Icones.get_icon(icone if Icones.has_icon(icone) else "trophee", isz, ink).get_image()
	icon.convert(Image.FORMAT_RGBA8)
	var o := Vector2i((px - icon.get_width()) / 2, (px - icon.get_height()) / 2)
	img.blend_rect(icon, Rect2i(Vector2i.ZERO, icon.get_size()), o)
	return img


func close_panel() -> void:
	closed.emit()
	queue_free()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and (k.keycode == KEY_ESCAPE or k.keycode == KEY_F6):
		get_viewport().set_input_as_handled()
		close_panel()
