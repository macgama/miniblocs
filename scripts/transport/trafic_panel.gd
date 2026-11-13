class_name TraficPanel
extends CanvasLayer
## Panneau « Trafic » (Maj + L, bouton Trafic de la barre du bas) : comment
## les habitants se déplacent, bouchons, stationnement, remplissage des lignes,
## tarifs, voies de bus et routes fermées. Affiche aussi la carte du trafic.

signal focus_requested(pos: Vector3)

const W := 360.0
const H := 560.0
const MODE_NAMES := {"voiture": "En voiture", "commun": "Transports en commun", "velo": "À vélo", "pied": "À pied"}
const MODE_COLORS := {"voiture": Color("e76f51"), "commun": Color("2a9d8f"), "velo": Color("e9c46a"), "pied": Color("8ecae6")}

var trafic: Trafic
var overlay: TraficOverlay
var camera: Camera3D
var view := "bilan"
## Clic sur une route pour la choisir (voie de bus, fermeture).
var picking := false
var picked := -1
var _panel: PanelContainer
var _title: Label
var _body: VBoxContainer
var _scroll: ScrollContainer
var _tick := 0.0


func setup(t: Trafic, o: TraficOverlay, cam: Camera3D) -> void:
	trafic = t
	overlay = o
	camera = cam
	_build()


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
	icon.texture = Icones.get_icon("circulation", 22, UiStyle.ACCENT)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(icon)
	_title = Label.new()
	_title.text = "Trafic"
	_title.add_theme_font_size_override("font_size", 16)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	var x := UiStyle.icon_button("fermer", "Fermer", "Maj+L", 18, 32)
	x.pressed.connect(func() -> void: set_open(false))
	head.add_child(x)
	var tabs := HBoxContainer.new()
	outer.add_child(tabs)
	for spec in [["Bilan", "bilan", "circulation"], ["Bouchons", "bouchons", "route"], ["Parkings", "parkings", "vehicules"], ["Lignes", "lignes", "lignes"]]:
		var b := Button.new()
		b.text = spec[0]
		b.icon = Icones.get_icon(spec[2], 16)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 12)
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
	else:
		picking = false


func toggle() -> void:
	set_open(not _panel.visible)


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.physical_keycode == KEY_L and k.shift_pressed and not k.ctrl_pressed:
		toggle()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not picking or not is_open():
		return
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		var eid := _edge_under(mb.position)
		if eid >= 0:
			picked = eid
			picking = false
			view = "bouchons"
			refresh()
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		picking = false
		refresh()
		get_viewport().set_input_as_handled()


func _edge_under(screen: Vector2) -> int:
	if camera == null or trafic.transport.world == null:
		return -1
	var hit: Variant = trafic.transport.world.pick_point(camera.project_ray_origin(screen), camera.project_ray_normal(screen))
	if hit == null:
		return -1
	var net := trafic.transport.network
	var best := -1
	var best_d := INF
	for id in net.edges:
		if TransportTypes.mode_of(net.edges[id].t) != TransportTypes.Mode.ROAD:
			continue
		var h := net.nearest_on_edge(id, hit)
		if h.dist < net.half_width(id) + 2.0 and h.dist < best_d:
			best_d = h.dist
			best = id
	return best


func show_view(v: String) -> void:
	view = v
	refresh()
	_scroll.scroll_vertical = 0


func _process(delta: float) -> void:
	if not is_open():
		return
	_tick += delta
	if _tick >= 1.5:
		_tick = 0.0
		var keep := _scroll.scroll_vertical
		refresh()
		_scroll.set_deferred("scroll_vertical", keep)


func refresh() -> void:
	if trafic == null:
		return
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	_map_row()
	match view:
		"bouchons": _view_jams()
		"parkings": _view_parkings()
		"lignes": _view_lines()
		_: _view_summary()


# --- Petits outils ----------------------------------------------------------------------

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


func _bar(frac: float, c: Color, label: String) -> void:
	var r := _row()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(150, 0)
	l.add_theme_font_size_override("font_size", 12)
	r.add_child(l)
	var bg := ColorRect.new()
	bg.color = Color(1, 1, 1, 0.12)
	bg.custom_minimum_size = Vector2(170, 12)
	bg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(bg)
	var fg := ColorRect.new()
	fg.color = c
	fg.size = Vector2(170.0 * clampf(frac, 0.0, 1.0), 12)
	bg.add_child(fg)


static func pct(x: float) -> String:
	return "%d %%" % roundi(x * 100.0)


static func euros(x: float) -> String:
	if absf(x) >= 1000.0:
		return "%s €" % String.num(snappedf(x, 1.0), 0)
	return "%.2f €" % x


func _edge_name(eid: int) -> String:
	var e: Dictionary = trafic.transport.network.edges.get(eid, {})
	if e.is_empty():
		return "Tronçon %d" % eid
	return "%s n° %d (%d m)" % [TransportTypes.get_type(e.t).name, eid, roundi(float(e.len))]


func _focus_edge(eid: int) -> void:
	var net := trafic.transport.network
	if net.edges.has(eid):
		var e: Dictionary = net.edges[eid]
		focus_requested.emit(net.point_at(eid, float(e.len) * 0.5))


# --- Carte --------------------------------------------------------------------------------

func _map_row() -> void:
	var r := _row()
	r.add_child(_button("Carte du trafic", func() -> void:
		overlay.set_shown(not overlay.visible)
		refresh(), 1 if overlay.visible else 0))
	r.add_child(_button("Heure de pointe" if overlay.moment == "pointe" else "Maintenant", func() -> void:
		overlay.moment = "maintenant" if overlay.moment == "pointe" else "pointe"
		overlay.rebuild()
		refresh()))
	r.add_child(_button("Choisir une route", func() -> void:
		picking = true
		refresh(), 1 if picking else 0))
	if picking:
		_text("Clique sur une route pour voir sa charge (Échap pour annuler).", true, 12)


# --- Bilan --------------------------------------------------------------------------------

func _view_summary() -> void:
	_title.text = "Trafic · bilan"
	var s := trafic.stats
	if s.is_empty() or int(s.get("trips", 0)) == 0:
		_text("Pas encore de trajets : il faut des habitants qui vont au travail ou à l'école.", true)
		return
	var n := maxf(1.0, float(s.trips))
	_section("Comment les habitants se déplacent (%d trajets par jour)" % int(s.trips))
	for m in ["voiture", "commun", "velo", "pied"]:
		var k := int((s.modes as Dictionary).get(m, 0))
		_bar(k / n, MODE_COLORS[m], "%s : %s" % [MODE_NAMES[m], pct(k / n)])
	_section("Temps de trajet")
	_text("Trajet moyen : %d min" % roundi(float(s.avg_min)))
	_text("En voiture : %d min perdues dans les bouchons, %d min pour se garer" % [roundi(float(s.avg_delay)), roundi(float(s.avg_search))])
	_text("Heure de pointe : les routes roulent %s plus lentement qu'à vide." % pct(maxf(0.0, float(s.jam_factor) - 1.0)), true)
	_section("Réseau")
	_text("%d tronçon%s saturé%s à la pointe" % [int(s.jammed), "s" if int(s.jammed) > 1 else "", "s" if int(s.jammed) > 1 else ""])
	_text("%d quartier%s sans place libre · %d places de stationnement" % [int(s.parking_full), "s" if int(s.parking_full) > 1 else "",
		roundi(float(s.parking_places))])
	_text("%d voyageurs par jour sur les lignes" % int(s.get("riders", 0)))
	_section("Recettes de la ville (ce mois)")
	var m: Dictionary = trafic.ledger.mois
	_text("Tickets : %s · Stationnement : %s" % [euros(float(m.get("Tickets de transport", 0.0))), euros(float(m.get("Stationnement", 0.0)))])
	var ent := trafic.budget_entretien()
	if not ent.is_empty():
		_text("Exploitation des lignes : %s par mois" % euros(float(ent.values()[0])), true)
	_section("Réglages")
	var r := _row()
	r.add_child(_button("Bouchons visibles", func() -> void:
		trafic.visible_jams = not trafic.visible_jams
		refresh(), 1 if trafic.visible_jams else 0))


# --- Bouchons -----------------------------------------------------------------------------

func _view_jams() -> void:
	_title.text = "Trafic · bouchons"
	if picked >= 0 and trafic.transport.network.edges.has(picked):
		_edge_card(picked)
	var worst: Array = trafic.stats.get("worst", [])
	_section("Tronçons les plus chargés à la pointe")
	if worst.is_empty():
		_text("Aucun tronçon chargé. Tout roule.", true)
	for it in worst:
		var eid := int(it[1])
		if not trafic.transport.network.edges.has(eid):
			continue
		var r := _row()
		var sw := TextureRect.new()
		sw.texture = _swatch(TraficOverlay.color_for(float(it[0])))
		sw.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		r.add_child(sw)
		var l := Label.new()
		l.text = "%s · %s" % [_edge_name(eid), pct(float(it[0]))]
		l.add_theme_font_size_override("font_size", 12)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		r.add_child(l)
		r.add_child(_button("Voir", func() -> void:
			picked = eid
			_focus_edge(eid)
			refresh()))
	if not trafic.closures.is_empty():
		_section("Routes fermées")
		for eid in trafic.closures:
			var r2 := _row()
			var l2 := Label.new()
			l2.text = "%s : %s" % [_edge_name(int(eid)), String(trafic.closures[eid])]
			l2.add_theme_font_size_override("font_size", 12)
			l2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			r2.add_child(l2)
			var e2 := int(eid)
			r2.add_child(_button("Rouvrir", func() -> void:
				trafic.rouvrir(e2)
				refresh()))


func _edge_card(eid: int) -> void:
	_section(_edge_name(eid))
	var cap := trafic.capacity(eid)
	_text("Capacité : %d véhicules/h par sens · à la pointe : %d véh/h (%s)" % [roundi(cap), roundi(trafic.edge_flow(eid)), pct(trafic.ratio(eid))])
	_text("En ce moment : %d véh/h · bus : %d par heure" % [roundi(trafic.flux(eid)), roundi(float(trafic.bus_flow.get(eid, 0.0)))], true)
	var r := _row()
	r.add_child(_button("Voie de bus", func() -> void:
		trafic.set_bus_lane(eid, not trafic.bus_lanes.has(eid))
		overlay.rebuild()
		refresh(), 1 if trafic.bus_lanes.has(eid) else 0))
	var closed := trafic.transport.network.closed_edges.has(eid)
	r.add_child(_button("Rouvrir" if closed else "Fermer à la circulation", func() -> void:
		if closed:
			trafic.rouvrir(eid)
		else:
			trafic.fermer(eid, "fermée par le maire")
		overlay.rebuild()
		refresh()))
	r.add_child(_button("Voir", func() -> void: _focus_edge(eid)))
	if trafic.bus_lanes.has(eid):
		_text("Une voie est réservée aux bus : ils évitent les bouchons, les voitures ont une voie de moins.", true, 12)


func _swatch(c: Color) -> Texture2D:
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	img.fill(c)
	return ImageTexture.create_from_image(img)


# --- Parkings -----------------------------------------------------------------------------

func _view_parkings() -> void:
	_title.text = "Trafic · stationnement"
	var st := trafic.transport.stations
	_text("Les voitures se garent d'abord sur le parking de l'entreprise, puis le long des rues et dans les parkings du quartier. Sans place, on tourne et on finit à pied.", true, 12)
	_section("Parkings construits")
	var any := false
	if trafic.transport.traffic != null:
		for node in trafic.transport.traffic.parkings:
			var pk: Dictionary = trafic.transport.traffic.parkings[node]
			var sid := int(pk.get("station", -1))
			if not st.stations.has(sid):
				continue
			any = true
			var occ := trafic.parking_occupancy(int(node))
			var fare := float(trafic.parking_fares.get(sid, 0.0))
			_text("%s · %d places · quartier rempli à %s · %s" % [String(st.stations[sid].name), (pk.spots as Array).size(), pct(occ),
				"gratuit" if fare <= 0.0 else "%s par jour" % euros(fare)])
			var r := _row()
			r.add_child(_button("− 1 €", func() -> void:
				trafic.parking_fares[sid] = maxf(0.0, fare - 1.0)
				refresh()))
			r.add_child(_button("+ 1 €", func() -> void:
				trafic.parking_fares[sid] = fare + 1.0
				refresh()))
			var p: Vector3 = st.stations[sid].pos
			r.add_child(_button("Voir", func() -> void: focus_requested.emit(p)))
	if not any:
		_text("Aucun parking. Construis-en avec Lignes (L) > Parking.", true)
	_section("Quartiers les plus pleins")
	var cells: Array = []
	for c in trafic.park_cells:
		var pc: Dictionary = trafic.park_cells[c]
		if float(pc.demand) > 0.0:
			cells.append([float(pc.occ), c])
	cells.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	if cells.is_empty():
		_text("Personne ne cherche de place.", true)
	for it in cells.slice(0, 8):
		var c: Vector2i = it[1]
		var pc: Dictionary = trafic.park_cells[c]
		var center := Vector3((c.x + 0.5) * Trafic.CELL, 0, (c.y + 0.5) * Trafic.CELL)
		var r2 := _row()
		var sw := TextureRect.new()
		sw.texture = _swatch(TraficOverlay.color_for(float(pc.occ)))
		sw.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		r2.add_child(sw)
		var l := Label.new()
		l.text = "%d voitures pour %d places · %d min pour se garer" % [roundi(float(pc.demand)), roundi(float(pc.free) + float(pc.paid)),
			roundi(float(pc.search) + float(pc.walk))]
		l.add_theme_font_size_override("font_size", 12)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		r2.add_child(l)
		r2.add_child(_button("Voir", func() -> void: focus_requested.emit(center)))


# --- Lignes -------------------------------------------------------------------------------

func _view_lines() -> void:
	_title.text = "Trafic · lignes"
	var st := trafic.transport.stations
	if st == null or st.lines.is_empty():
		_text("Aucune ligne. Crée-en avec le panneau Lignes (L).", true)
		return
	_text("Remplissage à l'heure de pointe. Une ligne pleine laisse des voyageurs sur le quai : ils attendent le véhicule suivant ou reprennent la voiture.", true, 12)
	for lid in st.lines:
		var l: Dictionary = st.lines[lid]
		if String(l.kind) == "camion":
			continue
		var ll: Dictionary = trafic.line_load.get(lid, {})
		_section("%s (%s)" % [String(l.name), String(Station_kind(String(l.kind)))])
		if ll.is_empty():
			_text("Ligne incomplète ou pas encore calculée.", true)
			continue
		var load := float(ll.load)
		_bar(load, TraficOverlay.color_for(load), "Pointe : %s" % pct(load))
		_text("%d voyageurs par jour · %d véhicule%s de %d places · un passage toutes les %d min" % [int(ll.riders), int(l.count),
			"s" if int(l.count) > 1 else "", int(ll.places), maxi(1, roundi(float(ll.headway) / 60.0))], false, 12)
		if float(ll.extra) > 1.0:
			_text("Bondé : %d min d'attente en plus. Ajoute des véhicules (panneau Lignes)." % roundi(float(ll.extra) / 60.0), false, 12)
		var fare := trafic.fare_of(lid)
		var r := _row()
		var fl := Label.new()
		fl.text = "Ticket : %s" % ("gratuit" if fare <= 0.0 else euros(fare))
		fl.add_theme_font_size_override("font_size", 12)
		fl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(fl)
		var id := int(lid)
		r.add_child(_button("− 0,50 €", func() -> void:
			trafic.fares[id] = maxf(0.0, fare - 0.5)
			trafic.population._transit_cache.clear()
			refresh()))
		r.add_child(_button("+ 0,50 €", func() -> void:
			trafic.fares[id] = fare + 0.5
			trafic.population._transit_cache.clear()
			refresh()))


static func Station_kind(kind: String) -> String:
	return String(StationSystem.KIND_NAMES.get(kind, kind))
