class_name UrgencesPanel
extends CanvasLayer
## Panneau « Urgences » (touche U) : appels en cours, casernes et véhicules,
## zones de couverture, bilan des temps d'intervention.

signal focus_requested(pos: Vector3)

const W := 348.0
const H := 560.0

var urg: Urgences
## Point autour duquel lancer un appel d'essai (pivot de la caméra).
var focus: Node3D
var view := "appels"
var _panel: PanelContainer
var _title: Label
var _body: VBoxContainer
var _scroll: ScrollContainer
var _tick := 0.0


func setup(u: Urgences, f: Node3D) -> void:
	urg = u
	focus = f
	_build()
	urg.changed.connect(func() -> void:
		if is_open() and _tick > 0.4:
			_tick = 0.0
			_refresh_keep())


func _build() -> void:
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
	_title = Label.new()
	_title.text = "Urgences"
	_title.add_theme_font_size_override("font_size", 16)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	var x := UiStyle.icon_button("fermer", "Fermer", "U", 18, 32)
	x.pressed.connect(func() -> void: set_open(false))
	head.add_child(x)
	var tabs := HBoxContainer.new()
	outer.add_child(tabs)
	for spec in [["Appels", "appels", "services"], ["Casernes", "casernes", "publics"], ["Bilan", "bilan", "horloge"]]:
		var b := Button.new()
		b.text = spec[0]
		b.icon = Icones.get_icon(spec[2], 18)
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v: String = spec[1]
		b.pressed.connect(func() -> void: show_view(v))
		tabs.add_child(b)
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(W, H)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 3)
	_scroll.add_child(_body)


func is_open() -> bool:
	return _panel.visible


func set_open(on: bool) -> void:
	_panel.visible = on
	if on:
		refresh()


func toggle() -> void:
	set_open(not _panel.visible)


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.physical_keycode == KEY_U and not k.shift_pressed and not k.ctrl_pressed:
		toggle()
		get_viewport().set_input_as_handled()


func show_view(v: String) -> void:
	view = v
	refresh()
	_scroll.scroll_vertical = 0


func _process(delta: float) -> void:
	if not is_open():
		return
	_tick += delta
	if _tick >= 1.0:
		_tick = 0.0
		_refresh_keep()


func _refresh_keep() -> void:
	var keep := _scroll.scroll_vertical
	refresh()
	_scroll.set_deferred("scroll_vertical", keep)


func refresh() -> void:
	if urg == null:
		return
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	match view:
		"casernes": _view_stations()
		"bilan": _view_stats()
		_: _view_calls()


# --- Petits outils ---------------------------------------------------------------------

func _text(t: String, dim := false, size := 13) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(W - 30, 0)
	l.add_theme_font_size_override("font_size", size)
	if dim:
		l.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
	_body.add_child(l)
	return l


func _section(t: String) -> void:
	_body.add_child(HSeparator.new())
	var l := _text(t, false, 15)
	l.add_theme_color_override("font_color", Color("ffd166"))


func _button(t: String, cb: Callable, toggled := -1) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 12)
	if toggled >= 0:
		b.toggle_mode = true
		b.button_pressed = toggled == 1
	b.pressed.connect(cb)
	return b


func _row() -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 4)
	_body.add_child(r)
	return r


func _swatch(c: Color) -> Texture2D:
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	img.fill(c)
	return ImageTexture.create_from_image(img)


# --- Appels -------------------------------------------------------------------------------

func _view_calls() -> void:
	_title.text = "Urgences · appels"
	var r := _row()
	r.add_child(_button("Appel d'essai ici", func() -> void:
		var p := focus.global_position if focus != null else Vector3.INF
		if urg.random_call("", p) < 0:
			urg.message.emit("Pas de route ni de logement ici pour un appel d'essai.")
		refresh()))
	r.add_child(_button("Appels au hasard", func() -> void:
		urg.random_calls = not urg.random_calls
		refresh(), 1 if urg.random_calls else 0))
	var snd := _row()
	var tf := urg.transport.traffic if urg.transport != null else null
	if tf != null:
		snd.add_child(_button("Son des sirènes", func() -> void:
			tf.set_siren_sound(not tf.siren_sound)
			refresh(), 1 if tf.siren_sound else 0))
	if urg.incidents.is_empty():
		_text("Aucun appel en cours. Les véhicules attendent dans leur caserne.", true)
	else:
		_section("En cours (%d)" % urg.incidents.size())
		for id in urg.incidents:
			_incident_row(urg.incidents[id], true)
	if not urg.history.is_empty():
		_section("Terminés")
		for i in mini(urg.history.size(), 10):
			_incident_row(urg.history[i], false)


func _incident_row(inc: Dictionary, live: bool) -> void:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 12)
	b.custom_minimum_size = Vector2(W - 30, 0)
	var needs: Array[String] = []
	for s in inc.besoin:
		var mark := "✓" if inc.done.get(s, false) else ("●" if inc.arrived.has(s) else "…")
		needs.append("%s %s" % [String(Urgences.SERVICE_NAMES.get(s, s)).get_slice(" ", 0), mark])
	var times: Array[String] = []
	for s in inc.arrived:
		times.append("%s en %s" % [String(Urgences.SERVICE_NAMES.get(s, s)).get_slice(" ", 0), Urgences.format_time(float(inc.arrived[s]))])
	b.text = "%s%s — %s\n%s%s" % [String(inc.name), " (gravité %d)" % int(inc.gravite) if int(inc.gravite) > 1 else "",
		urg.state_label(inc), " · ".join(needs), ("\n" + " · ".join(times)) if not times.is_empty() else ""]
	b.icon = _swatch(Color("ff5d5d") if live else Color("6c757d"))
	var pos: Vector3 = inc.pos
	b.pressed.connect(func() -> void: focus_requested.emit(pos))
	b.tooltip_text = "Clique pour y aller."
	_body.add_child(b)


# --- Casernes --------------------------------------------------------------------------------

func _view_stations() -> void:
	_title.text = "Urgences · casernes"
	if urg.stations.is_empty():
		_text("Aucun bâtiment de secours. Pose une caserne de pompiers, un commissariat ou un hôpital (Construire → Services), au bord d'une route.", true)
	for bid in urg.stations:
		var st: Dictionary = urg.stations[bid]
		var name_ := String(BuildingCatalog.get_type(String(st.t)).get("name", st.t))
		_section(name_)
		var staff := urg.staff_of(int(bid))
		var busy := urg.crew_busy(int(bid))
		_text("De garde aujourd'hui : %d · en intervention : %d" % [staff, busy] if staff < 999 else "Équipage : toujours disponible", true)
		if (st.road as Dictionary).is_empty():
			_text("Pas de route devant la porte : les véhicules ne peuvent pas sortir.")
		for u in st.units:
			var model := String(u.get("model", urg.model_for(String(u.base)))) if u.out else urg.model_for(String(u.base))
			var state := ""
			if u.out:
				state = {"aller": "en route, sirène", "sur_place": "sur place", "hopital": "vers l'hôpital",
					"pause": "à l'hôpital", "retour": "rentre"}.get(String(u.get("phase", "")), "dehors")
			elif urg.unit_ready(int(bid), u):
				state = "prêt"
			else:
				state = "sans équipage (%d pers.)" % urg.crew_of(model)
			var b := Button.new()
			b.focus_mode = Control.FOCUS_NONE
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.add_theme_font_size_override("font_size", 12)
			b.text = "%s — %s" % [String(VehicleCatalog.get_type(model).get("name", model)), state]
			b.icon = _swatch(Urgences.SERVICE_COLORS.get(String(u.role), Color.WHITE))
			var target: Vector3 = (st.road.pos as Vector3) if not (st.road as Dictionary).is_empty() else Vector3.ZERO
			if u.out and not (u.v as Dictionary).is_empty():
				target = urg.transport.traffic.vehicle_position(u.v)
			b.pressed.connect(func() -> void: focus_requested.emit(target))
			_body.add_child(b)


# --- Bilan ---------------------------------------------------------------------------------

func _view_stats() -> void:
	_title.text = "Urgences · bilan"
	_section("Couverture sur la carte")
	_text("Temps pour arriver par la route, sirène allumée.", true)
	var r := _row()
	for spec in [["Aucune", ""], ["Pompiers", "pompiers"], ["Secours", "ambulance"], ["Police", "police"]]:
		var id: String = spec[1]
		r.add_child(_button(spec[0], func() -> void:
			urg.set_coverage(id)
			refresh(), 1 if urg.coverage == id else 0))
	var leg := _row()
	var names := ["< 3 min", "3-6 min", "6-10 min", "> 10 min"]
	for i in names.size():
		var l := Label.new()
		l.text = names[i]
		l.add_theme_font_size_override("font_size", 11)
		var tr := TextureRect.new()
		tr.texture = _swatch(Urgences.COVER_COLORS[i])
		tr.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		leg.add_child(tr)
		leg.add_child(l)
	_section("Temps d'intervention")
	for s in Urgences.SERVICES:
		var st: Dictionary = urg.stats[s]
		if int(st.n) == 0:
			_text("%s : pas encore d'intervention" % String(Urgences.SERVICE_NAMES[s]), true)
		else:
			_text("%s : %d interventions, moyenne %s (plus rapide %s, plus lente %s)" % [String(Urgences.SERVICE_NAMES[s]), int(st.n),
				Urgences.format_time(urg.average(s)), Urgences.format_time(float(st.best)), Urgences.format_time(float(st.worst))])
	_section("Depuis le début")
	_text("Appels : %d · terminés : %d · secours trop tardifs : %d" % [int(urg.stats.appels), int(urg.stats.terminees), int(urg.stats.trop_tard)])
	_text("Personnes secourues : %d · décès : %d · cambriolages non élucidés : %d" % [int(urg.stats.sauves), int(urg.stats.deces), int(urg.stats.non_elucides)])
