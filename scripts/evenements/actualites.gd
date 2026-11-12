class_name Actualites
extends CanvasLayer
## Fil d'actualité en haut de l'écran : les dernières nouvelles des événements
## (« Incendie : Maison rue… »). Un clic va voir sur place ; les nouvelles
## s'effacent après quelques secondes.

signal focus_requested(pos: Vector3)
signal open_requested

const MAX := 3
const DUREE := 14.0
const W := 470.0

var ev: Evenements
var _box: VBoxContainer
var _items: Array = []


func setup(e: Evenements) -> void:
	ev = e
	layer = 5
	_box = VBoxContainer.new()
	_box.name = "FilActualite"
	# Au centre, sous les messages : le coin haut gauche est pris par l'habitant suivi,
	# la droite par les panneaux.
	_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_box.offset_left = -W * 0.5
	_box.offset_right = W * 0.5
	_box.offset_top = 104
	_box.custom_minimum_size = Vector2(W, 0)
	_box.add_theme_constant_override("separation", 4)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	ev.actualite.connect(_on_news)


func _on_news(n: Dictionary) -> void:
	var b := Button.new()
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(W, 30)
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var genre := String(n.genre)
	var t: Dictionary = Evenements.TYPES.get(_type_of(genre), {})
	var col: Color = t.get("couleur", UiStyle.ACCENT)
	b.icon = Icones.get_icon(String(t.get("icone", "infos")), 18, col)
	b.text = "%s   %s" % [ev.heure_courte(float(n.t)), String(n.texte)]
	b.tooltip_text = String(n.texte) + ("\nClic : aller voir" if (n.pos as Vector3).is_finite() else "\nClic : panneau Infos (I)")
	b.add_theme_font_size_override("font_size", 13)
	var sb := UiStyle.flat_box(Color(0.07, 0.09, 0.08, 0.82), 8, 4)
	sb.border_width_left = 4
	sb.border_color = col
	sb.content_margin_left = 8
	b.add_theme_stylebox_override("normal", sb)
	var hov := sb.duplicate() as StyleBoxFlat
	hov.bg_color = Color(0.12, 0.15, 0.13, 0.92)
	b.add_theme_stylebox_override("hover", hov)
	b.add_theme_stylebox_override("pressed", hov)
	var pos: Vector3 = n.pos
	b.pressed.connect(func() -> void:
		if pos.is_finite():
			focus_requested.emit(pos)
		else:
			open_requested.emit())
	_box.add_child(b)
	_box.move_child(b, 0)
	_items.push_front({"b": b, "t": DUREE})
	while _items.size() > MAX:
		var old: Dictionary = _items.pop_back()
		(old.b as Node).queue_free()


static func _type_of(genre: String) -> String:
	match genre:
		"ruine", "reparation":
			return "incendie"
	return genre


func _process(delta: float) -> void:
	for it in _items.duplicate():
		it.t = float(it.t) - delta
		var b: Button = it.b
		if float(it.t) < 1.5:
			b.modulate.a = clampf(float(it.t) / 1.5, 0.0, 1.0)
		if float(it.t) <= 0.0:
			_items.erase(it)
			b.queue_free()


func count() -> int:
	return _items.size()
