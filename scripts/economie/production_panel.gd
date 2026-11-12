class_name ProductionPanel
extends CanvasLayer
## Panneau « Production » (touche P) : carte des ressources de la région,
## stocks de la ville (production, ventes, export), sites de production.

signal focus_requested(pos: Vector3)

const W := 348.0
const H := 560.0

var prod: Production
var overlay: RessourcesOverlay
## Point autour duquel on mesure les ressources (pivot de la caméra).
var focus: Node3D
var _panel: PanelContainer
var _title: Label
var _body: VBoxContainer
var _scroll: ScrollContainer
## Vue affichée : "ressources", "stocks", "sites".
var view := "ressources"
var _tick := 0.0
var _around := {}
var _around_at := Vector2(INF, INF)


func setup(p: Production, o: RessourcesOverlay, f: Node3D) -> void:
	prod = p
	overlay = o
	focus = f
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
	icon.texture = Icones.get_icon("ressources", 22, UiStyle.ACCENT)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(icon)
	_title = Label.new()
	_title.text = "Production"
	_title.add_theme_font_size_override("font_size", 16)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	var x := UiStyle.icon_button("fermer", "Fermer", "P", 18, 32)
	x.pressed.connect(func() -> void: set_open(false))
	head.add_child(x)
	var tabs := HBoxContainer.new()
	outer.add_child(tabs)
	for spec in [["Ressources", "ressources", "ressources"], ["Stocks", "stocks", "budget"], ["Sites", "sites", "industrie"]]:
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
	if k and k.pressed and not k.echo and k.physical_keycode == KEY_P and not k.shift_pressed and not k.ctrl_pressed:
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
	if _tick >= 2.0:
		_tick = 0.0
		var keep := _scroll.scroll_vertical
		refresh()
		_scroll.set_deferred("scroll_vertical", keep)


func refresh() -> void:
	if prod == null:
		return
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	match view:
		"stocks":
			_view_stocks()
		"sites":
			_view_sites()
		_:
			_view_resources()


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


func _bar(parent: Control, value: float, col: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = 1.0
	bar.step = 0.001
	bar.value = clampf(value, 0.0, 1.0)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(80, 10)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_theme_stylebox_override("background", UiStyle.flat_box(Color(1, 1, 1, 0.12), 5, 0))
	bar.add_theme_stylebox_override("fill", UiStyle.flat_box(col, 5, 0))
	parent.add_child(bar)
	return bar


static func _dir(dlat: float, dlon_km: float) -> String:
	var a := fposmod(rad_to_deg(atan2(dlon_km, dlat)), 360.0)
	return ["au nord", "au nord-est", "à l'est", "au sud-est", "au sud", "au sud-ouest", "à l'ouest", "au nord-ouest"][int(roundf(a / 45.0)) % 8]


# --- Vue « Ressources » -------------------------------------------------------------------

func _view_resources() -> void:
	_title.text = "Production · ressources"
	_text("Clique sur une ressource pour la voir sur le terrain. Plus la couleur est franche, plus c'est riche. Pose ensuite le bon bâtiment (Construire → Production).", true)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	_body.add_child(grid)
	var around := _measure_around()
	for res in Ressources.ORDRE:
		var nat := Ressources.naturelle(res)
		var b := Button.new()
		b.toggle_mode = true
		b.button_pressed = overlay != null and overlay.res == res
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2((W - 34) / 2.0, 30)
		b.add_theme_font_size_override("font_size", 12)
		var r := float(around.get(res, -1.0))
		b.text = String(nat.name).replace(" (bois)", "") + ("  %d %%" % roundi(r * 100.0) if r >= 0.0 else "")
		b.icon = _swatch(nat.color)
		b.tooltip_text = "%s\n%s\nRichesse moyenne près de la caméra (1 km) : %s" % [nat.name, nat.desc,
			("%d %%" % roundi(r * 100.0)) if r >= 0.0 else "en cours de lecture"]
		var id: String = res
		b.pressed.connect(func() -> void:
			if overlay != null:
				overlay.show_resource("" if overlay.res == id else id)
			refresh())
		grid.add_child(b)
	if overlay != null and overlay.res != "":
		var hide := Button.new()
		hide.text = "Masquer la carte"
		hide.focus_mode = Control.FOCUS_NONE
		hide.pressed.connect(func() -> void:
			overlay.show_resource("")
			refresh())
		_body.add_child(hide)
	_section("Grandes régions minières et pétrolières")
	var world := prod.world
	var list := prod.carte.region_provinces()
	if list.is_empty():
		_text("Aucune grande région connue à moins de %d km. De petits gisements locaux restent possibles : regarde la carte." % int(CarteRessources.SEARCH_KM), true)
	for p in list:
		var where := "tu es dedans"
		if float(p.d) > float(p.r):
			var dlon := (float(p.lon) - world.origin_lon) * 111.32 * cos(deg_to_rad(world.origin_lat))
			where = "à %d km %s" % [roundi(float(p.d) - float(p.r)), _dir(float(p.lat) - world.origin_lat, dlon)]
		var row := HBoxContainer.new()
		_body.add_child(row)
		var sw := TextureRect.new()
		sw.texture = _swatch(Ressources.naturelle(p.res).color)
		sw.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		row.add_child(sw)
		var l := Label.new()
		l.text = "%s · %s · %s" % [p.name, String(Ressources.naturelle(p.res).name).to_lower(), where]
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(W - 60, 0)
		l.add_theme_font_size_override("font_size", 13)
		row.add_child(l)
	_text("Forêts, champs et prairies : ESA WorldCover 2021 (CC BY 4.0). Relief : tuiles Terrarium (AWS Open Data). Régions minières : géographie publique, placement des gisements calculé par le jeu.", true, 11)


## Richesse moyenne de chaque ressource dans un rayon de 500 m autour de la caméra.
func _measure_around() -> Dictionary:
	if focus == null or prod.carte == null:
		return {}
	var c := Vector2(focus.global_position.x, focus.global_position.z)
	if c.distance_to(_around_at) < 60.0 and not _around.is_empty() and not _around.values().has(-1.0):
		return _around
	_around_at = c
	var env := prod.carte.sample_env(c.x - 500.0, c.y - 500.0, 25, 25, 40.0)
	_around = {}
	for res in Ressources.ORDRE:
		var v := prod.carte.evaluate(res, env)
		var sum := 0.0
		var n := 0
		for x in v:
			if x >= 0.0:
				sum += x
				n += 1
		# Moyenne sur ce qui est déjà chargé (-1 si rien ne l'est encore).
		var m := -1.0 if n * 4 < v.size() else sum / n
		if res == "poisson" and m > 0.0:
			m = clampf(m * 2.5, 0.0, 1.0)
		if res in Ressources.SOUS_SOL and m > 0.0:
			# Un gisement est une tache : on montre sa meilleure richesse.
			m = 0.0
			for x in v:
				m = maxf(m, x)
		_around[res] = m
	return _around


static var _swatches := {}


static func _swatch(c: Color) -> Texture2D:
	var key := c.to_html()
	if not _swatches.has(key):
		var img := Image.create(14, 14, false, Image.FORMAT_RGBA8)
		img.fill(c)
		_swatches[key] = ImageTexture.create_from_image(img)
	return _swatches[key]


# --- Vue « Stocks » --------------------------------------------------------------------------

func _view_stocks() -> void:
	_title.text = "Production · stocks de la ville"
	_text("Capacité : %s par marchandise (un entrepôt ajoute %s)." % [Ressources.format_t(prod.capacity()),
		Ressources.format_t(Production.STOCK_ENTREPOT)], true)
	var n := prod.export_stations()
	var ex := prod.edge_exits()
	var exits := 0
	for m in ex:
		exits += int(ex[m])
	var cap := prod.export_capacity()
	if cap <= 0.0:
		_text("Pas d'export : pose un dépôt de marchandises, une gare ou un port (panneau Lignes, L), ou prolonge une route, un rail ou une voie d'eau jusqu'au bord de la carte.", false)
	else:
		_text("Export : %s par jour (%d station%s, %d sortie%s par le bord de la carte, fret de tes lignes)." % [Ressources.format_t(cap),
			n, "s" if n > 1 else "", exits, "s" if exits > 1 else ""], true)
	if not prod.has_shops():
		_text("Aucun commerce : les habitants ne peuvent rien acheter (pose une supérette ou un supermarché).", false)
	_section("Marchandises (hier)")
	var any := false
	var y: Dictionary = prod.yesterday
	for g in Ressources.MARCHANDISES:
		var s := float(prod.stock.get(g, 0.0))
		var p := float(y.prod.get(g, 0.0))
		var c := float(y.conso.get(g, 0.0))
		var v := float(y.vente.get(g, 0.0))
		var e := float(y.export.get(g, 0.0))
		if s < 0.0005 and p + c + v + e < 0.0005:
			continue
		any = true
		var row := HBoxContainer.new()
		_body.add_child(row)
		var l := Label.new()
		l.text = Ressources.good_name(g)
		l.custom_minimum_size = Vector2(130, 0)
		l.add_theme_font_size_override("font_size", 13)
		row.add_child(l)
		_bar(row, s / prod.capacity(), Color("d4a373"))
		var q := Label.new()
		q.text = Ressources.format_t(s)
		q.custom_minimum_size = Vector2(70, 0)
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		q.add_theme_font_size_override("font_size", 13)
		row.add_child(q)
		var parts: Array[String] = []
		if p > 0.0:
			parts.append("+%s produits" % Ressources.format_t(p))
		if c > 0.0:
			parts.append("−%s transformés" % Ressources.format_t(c))
		if v > 0.0:
			parts.append("−%s vendus" % Ressources.format_t(v))
		if e > 0.0:
			parts.append("−%s exportés" % Ressources.format_t(e))
		if not parts.is_empty():
			_text("    " + " · ".join(parts), true, 11)
	if not any:
		_text("Rien en stock pour l'instant.", true)
	_section("Comptes du mois")
	var m: Dictionary = prod.ledger.mois
	if m.is_empty():
		_text("Pas encore de vente ni de salaire.", true)
	var total := 0.0
	for k in m:
		total += float(m[k])
		_text("%s : %s" % [k, BuildingSystem.format_money(roundi(float(m[k])))])
	if not m.is_empty():
		_text("Solde : %s (%d jour%s)" % [BuildingSystem.format_money(roundi(total)), int(prod.ledger.jours), "s" if int(prod.ledger.jours) > 1 else ""], false, 14)


# --- Vue « Sites » ----------------------------------------------------------------------------

func _view_sites() -> void:
	_title.text = "Production · sites"
	if prod.sites.is_empty():
		_text("Aucun site de production. Ouvre Construire (B) → Production : exploitation forestière, ferme céréalière, mine, scierie, moulin…", true)
		return
	var ids := prod.sites.keys()
	ids.sort()
	for bid in ids:
		var info := prod.site_info(bid)
		if info.is_empty():
			continue
		var b := Button.new()
		b.flat = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.text = "%s  ↗" % info.name
		b.add_theme_font_size_override("font_size", 14)
		b.add_theme_color_override("font_color", Color("a8dadc"))
		var pos: Vector3 = info.pos
		b.pressed.connect(func() -> void: focus_requested.emit(pos))
		_body.add_child(b)
		var row := HBoxContainer.new()
		_body.add_child(row)
		var l := Label.new()
		l.text = "Activité"
		l.custom_minimum_size = Vector2(74, 0)
		l.add_theme_font_size_override("font_size", 12)
		row.add_child(l)
		_bar(row, float(info.eff), UiStyle.GOOD)
		var w := Label.new()
		w.text = "%d/%d emplois" % [info.workers, info.jobs]
		w.add_theme_font_size_override("font_size", 12)
		row.add_child(w)
		_text(String(info.status), true, 12)
		var extra := String(info.recipe)
		if info.has("res"):
			extra = "%s : richesse %d %%" % [info.res, roundi(float(info.rich) * 100.0)]
			if info.has("reserve"):
				extra += " · reste %s" % Ressources.format_t(float(info.reserve))
			if info.has("vit"):
				extra += " · ressource à %d %% (repousse si on exploite moins)" % roundi(float(info.vit) * 100.0)
		_text(extra, true, 11)
