class_name ProductionPanel
extends CanvasLayer
## Panneau « Production » (touche P) : carte des ressources de la région,
## marchandises de la ville, sites (usines, commerces, entrepôts, avec leur
## stock et leur caisse) et camions de livraison.

signal focus_requested(pos: Vector3)
## Outil des carrières demandé : "perimetre" (pour le site bid) ou "sondage".
signal outil_carriere(mode: String, bid: int)

const W := 348.0
const H := 560.0

var prod: Production
var overlay: RessourcesOverlay
## Carrières et mines (onglet Mines), facultatif.
var carrieres: Carrieres
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
	for spec in [["Ressources", "ressources", "ressources"], ["Stocks", "stocks", "budget"], ["Sites", "sites", "industrie"], ["Camions", "camions", "vehicules"], ["Mines", "mines", "creuser"]]:
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
		"camions":
			_view_trucks()
		"mines":
			_view_mines()
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
	_title.text = "Production · marchandises de la ville"
	_text("Chaque usine, ferme, commerce et entrepôt a son propre stock. Les camions livrent le plus proche qui en a besoin. Entrepôts : %s de place en tout." % \
		Ressources.format_t(prod.capacity()), true)
	var n := prod.export_stations()
	var ex := prod.edge_exits()
	var exits := 0
	for m in ex:
		exits += int(ex[m])
	var cap := prod.export_capacity()
	if cap <= 0.0 or prod.gateways().is_empty():
		_text("Ni import ni export : pose un dépôt de marchandises, une gare ou un port (panneau Lignes, L), ou prolonge une route jusqu'au bord de la carte. Sans cela, ce que la ville ne produit pas manque en rayon.", false)
	else:
		_text("Import et export : %s par jour chacun (%d station%s, %d sortie%s par le bord de la carte, fret de tes lignes)." % [Ressources.format_t(cap),
			n, "s" if n > 1 else "", exits, "s" if exits > 1 else ""], true)
	if not prod.has_shops():
		_text("Aucun commerce : les habitants ne peuvent rien acheter (pose une supérette, une boulangerie, un supermarché…).", false)
	_section("Marchandises (hier)")
	var any := false
	var y: Dictionary = prod.yesterday
	var stock := prod.total_stock()
	var road := prod.in_transit()
	var top := 1.0
	for g in stock:
		top = maxf(top, float(stock[g]))
	for g in Ressources.MARCHANDISES:
		var st := float(stock.get(g, 0.0))
		var r := float(road.get(g, 0.0))
		var vals := {}
		var sum := 0.0
		for f in ["prod", "conso", "vente", "export", "import", "livre"]:
			vals[f] = float(y.get(f, {}).get(g, 0.0))
			sum += float(vals[f])
		if st + r < 0.0005 and sum < 0.0005:
			continue
		any = true
		var row := HBoxContainer.new()
		_body.add_child(row)
		var l := Label.new()
		l.text = Ressources.good_name(g)
		l.custom_minimum_size = Vector2(130, 0)
		l.clip_text = true
		l.add_theme_font_size_override("font_size", 13)
		row.add_child(l)
		_bar(row, st / top, Color("d4a373"))
		var q := Label.new()
		q.text = Ressources.format_t(st)
		q.custom_minimum_size = Vector2(70, 0)
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		q.add_theme_font_size_override("font_size", 13)
		row.add_child(q)
		var parts: Array[String] = []
		const WORDS := {"prod": "+%s produits", "conso": "−%s transformés", "vente": "−%s vendus", "livre": "%s livrés",
			"import": "+%s importés", "export": "−%s exportés"}
		for f in WORDS:
			if float(vals[f]) > 0.0:
				parts.append(String(WORDS[f]) % Ressources.format_t(float(vals[f])))
		if r > 0.0:
			parts.append("%s sur la route" % Ressources.format_t(r))
		if not parts.is_empty():
			_text("    " + " · ".join(parts), true, 11)
	if not any:
		_text("Rien en stock pour l'instant.", true)
	_section("Comptes du mois (toutes les entreprises)")
	var m: Dictionary = prod.ledger.mois
	if m.is_empty():
		_text("Pas encore de vente ni de salaire.", true)
	for k in m:
		_text("%s : %s" % [k, BuildingSystem.format_money(roundi(float(m[k])))])
	_text("Ta caisse (la ville) touche seulement l'impôt sur les bénéfices des entreprises (%d %% × réglage Impôts)." % roundi(Production.IMPOT_BENEFICES * 100.0), true, 11)


# --- Vue « Sites » ----------------------------------------------------------------------------

const KIND_ORDER := ["extraction", "transformation", "commerce", "entrepot", "logistique"]
const KIND_NAMES := {"extraction": "Fermes, forêts, mines", "transformation": "Usines", "commerce": "Commerces",
	"entrepot": "Entrepôts", "logistique": "Transport routier"}


func _view_sites() -> void:
	_title.text = "Production · sites et entreprises"
	if prod.sites.is_empty():
		_text("Aucun site. Ouvre Construire (B) → Production : ferme, mine, scierie, moulin… et Commerce : boulangerie, supérette, station-service…", true)
		return
	var ids := prod.sites.keys()
	ids.sort()
	for kind in KIND_ORDER:
		var first := true
		for bid in ids:
			if String(prod.sites[bid].kind) != kind:
				continue
			var info := prod.site_info(bid)
			if info.is_empty():
				continue
			if first:
				_section(KIND_NAMES[kind])
				first = false
			_site_card(info)


func _site_card(info: Dictionary) -> void:
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
	var st := _text(String(info.status), true, 12)
	if String(info.status).contains("vides") or String(info.status).contains("attente") or String(info.status).contains("Aucun"):
		st.add_theme_color_override("font_color", Color("ff9f80"))
	var extra := String(info.recipe)
	if info.has("res"):
		extra = "%s : richesse %d %%" % [info.res, roundi(float(info.rich) * 100.0)]
		if info.has("reserve"):
			extra += " · reste %s" % Ressources.format_t(float(info.reserve))
		if info.has("vit"):
			extra += " · ressource à %d %% (repousse si on exploite moins)" % roundi(float(info.vit) * 100.0)
	if extra != "":
		_text(extra, true, 11)
	var stock: Dictionary = info.stock
	if not stock.is_empty() or not (info.inc as Dictionary).is_empty():
		var parts: Array[String] = []
		for g in stock:
			parts.append("%s %s" % [Ressources.good_name(g).to_lower(), Ressources.format_t(float(stock[g]))])
		var txt := "Stock : " + (", ".join(parts) if not parts.is_empty() else "vide")
		var inc: Array[String] = []
		for g in info.inc:
			inc.append("%s %s" % [Ressources.good_name(g).to_lower(), Ressources.format_t(float(info.inc[g]))])
		if not inc.is_empty():
			txt += " · en route : " + ", ".join(inc)
		_text(txt, true, 11)
	var month := 0.0
	for k in info.mois:
		month += float(info.mois[k])
	var c := _text("Caisse : %s · ce mois : %s%s" % [BuildingSystem.format_money(roundi(float(info.cash))), BuildingSystem.format_money(roundi(month)),
		(" · %d chauffeur%s" % [int(info.drivers), "s" if int(info.drivers) > 1 else ""]) if int(info.drivers) > 0 else ""], true, 11)
	c.add_theme_color_override("font_color", UiStyle.GOOD if float(info.cash) >= 0.0 else Color("ff9f80"))


# --- Vue « Camions » ----------------------------------------------------------------------------

func _view_trucks() -> void:
	_title.text = "Production · camions de livraison"
	var ds := prod.driver_stats()
	_text("Chauffeurs-livreurs : %d en ville, %d au travail en ce moment, %d libres, %d en tournée." % [int(ds.total), int(ds.au_travail),
		int(ds.libres), int(ds.en_tournee)], false)
	if int(ds.total) == 0:
		_text("Personne ne livre : pose une entreprise de transport routier (Construire → Production) ou un entrepôt, et des logements pour que des habitants y travaillent. Les fermes et usines ont aussi souvent un chauffeur.", false)
	elif int(ds.attente) > 0:
		_text("%d livraison%s attend%s un chauffeur libre. Les chauffeurs travaillent du lundi au vendredi, de %dh à %dh." % [int(ds.attente),
			"s" if int(ds.attente) > 1 else "", "ent" if int(ds.attente) > 1 else "", int(Metiers.job("chauffeur").h[0]), int(Metiers.job("chauffeur").h[1])], true)
	_section("Tournées en cours")
	var list := prod.missions.values()
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.t_end) < float(b.t_end))
	var now := prod.clock
	if list.is_empty():
		_text("Aucun camion sur la route.", true)
	for m in list:
		var goods: Array[String] = []
		for g in m.cargo:
			goods.append("%s %s" % [Ressources.format_t(float(m.cargo[g])), Ressources.good_name(g).to_lower()])
		var who := ""
		if prod.population != null and prod.population.persons.has(int(m.driver)):
			who = String(prod.population.persons[int(m.driver)].n)
		var state := "livré, retour au dépôt" if bool(m.done) else "livraison dans %d min" % maxi(roundi((float(m.t_unload) - now) / 60.0), 0)
		_text("%s → %s" % [prod.place_name(int(m.from), int(m.gw)), prod.place_name(int(m.to), int(m.gw))], false, 13)
		_text("    %s · %s · %s, %s · %.1f km" % [", ".join(goods), String(VehicleCatalog.get_type(String(m.model)).get("name", m.model)),
			who, state, float(m.km)], true, 11)


# --- Vue « Mines » : carrières, fosses, verses, sondages ----------------------------------------

func _button(t: String, cb: Callable, parent: Control = null) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 12)
	b.pressed.connect(cb)
	(parent if parent != null else _body).add_child(b)
	return b


func _view_mines() -> void:
	_title.text = "Production · carrières et mines"
	if carrieres == null:
		_text("Carrières indisponibles.", true)
		return
	_text("Chaque tonne extraite creuse la fosse en gradins ; les stériles montent en verse. La réserve, c'est la roche du périmètre jusqu'à la profondeur maximale.", true, 12)
	var top := HBoxContainer.new()
	_body.add_child(top)
	_button("Faire un sondage (%s)" % BuildingSystem.format_money(ReglagesPartie.prix(Carrieres.SONDAGE_PRIX)),
		func() -> void: outil_carriere.emit("sondage", -1), top)
	var ids := carrieres.sites.keys()
	ids.sort()
	if ids.is_empty():
		_section("Sites")
		_text("Aucune carrière ni mine. Construire (B) → Production : carrière, sablière et gravière, carrière d'argile, mine à ciel ouvert, mine souterraine, mine de sel.", true)
	else:
		_section("Sites")
	for bid in ids:
		var inf := carrieres.info(int(bid))
		if inf.is_empty():
			continue
		_mine_card(inf)
	if not carrieres.sondages.is_empty():
		_section("Sondages")
		var now := carrieres.ambiance.unix_time if carrieres.ambiance != null else 0.0
		for i in range(carrieres.sondages.size() - 1, -1, -1):
			var sd: Dictionary = carrieres.sondages[i]
			var b := Button.new()
			b.flat = true
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.focus_mode = Control.FOCUS_NONE
			b.add_theme_font_size_override("font_size", 12)
			var pos := Vector3(float(sd.x), 0, float(sd.z))
			if (sd.res as Dictionary).is_empty():
				b.text = "↗ Forage en cours, encore %.1f jour(s)" % maxf((float(sd.fin) - now) / 86400.0, 0.0)
			else:
				b.text = "↗ " + Carrieres.resume_sondage(sd)
			b.pressed.connect(func() -> void: focus_requested.emit(pos))
			_body.add_child(b)


func _mine_card(inf: Dictionary) -> void:
	var b := Button.new()
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.text = "%s  ↗" % inf.name
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", Color("a8dadc"))
	var pos: Vector3 = inf.pos
	b.pressed.connect(func() -> void: focus_requested.emit(pos))
	_body.add_child(b)
	var st := _text(String(inf.status), true, 12)
	if String(inf.status).begins_with("Pas de place") or String(inf.status).contains("pauvre") or String(inf.status).contains("épuisé"):
		st.add_theme_color_override("font_color", Color("ff9f80"))
	var line := ""
	if inf.has("res"):
		line = "%s : richesse %d %%" % [inf.res, roundi(float(inf.rich) * 100.0)]
	if inf.has("reserve"):
		line += " · reste %s" % Ressources.format_t(float(inf.reserve))
		if float(inf.par_jour) > 0.0:
			var days := float(inf.reserve) / float(inf.par_jour)
			line += " (%s au rythme actuel)" % (("%.1f ans" % (days / 365.0)) if days > 365.0 else ("%d jours" % roundi(days)))
	if line != "":
		_text(line, true, 11)
	if inf.has("rect"):
		var r: Rect2i = inf.rect
		var row := HBoxContainer.new()
		_body.add_child(row)
		var l := Label.new()
		l.text = "Fosse"
		l.custom_minimum_size = Vector2(74, 0)
		l.add_theme_font_size_override("font_size", 12)
		row.add_child(l)
		_bar(row, float(inf.part), Color("c2b8a3"))
		var w := Label.new()
		w.text = "%d %%" % roundi(float(inf.part) * 100.0)
		w.add_theme_font_size_override("font_size", 12)
		row.add_child(w)
		_text("Périmètre %d × %d m · profondeur %.0f m sur %.0f · gradin %d sur %d" % [r.size.x, r.size.y,
			float(inf.prof), float(inf.prof_max), int(inf.gradin), int(inf.gradins)], true, 11)
	if inf.has("verse_h"):
		_text(("Terril" if not bool(inf.fosse) else "Verse à stériles") + " : %.0f m de haut, pleine à %d %%" % [float(inf.verse_h), roundi(float(inf.verse_part) * 100.0)], true, 11)
	if not bool(inf.fosse):
		return
	var bid := int(inf.bid)
	var acts := HBoxContainer.new()
	_body.add_child(acts)
	_button("Nouveau périmètre", func() -> void: outil_carriere.emit("perimetre", bid), acts)
	if String(inf.fin) != "" or not inf.has("rect"):
		return
	var fin := HBoxContainer.new()
	_body.add_child(fin)
	var lab := Label.new()
	lab.text = "Réaménager :"
	lab.add_theme_font_size_override("font_size", 12)
	fin.add_child(lab)
	for spec in [["Plan d'eau", "lac"], ["Remblai", "remblai"], ["Laisser", "laisser"]]:
		var kind: String = spec[1]
		var bt := _button(spec[0], func() -> void:
			var why := carrieres.reamenager(bid, kind)
			if why != "":
				carrieres.message.emit(why)
			refresh(), fin)
		bt.tooltip_text = {"lac": "Le fond se remplit d'eau : baignade, pêche (%s)." % BuildingSystem.format_money(Carrieres.LAC_PRIX),
			"remblai": "La fosse est comblée et redevient prairie (%s le m³)." % BuildingSystem.format_money(int(Carrieres.REMBLAI_M3)),
			"laisser": "On ferme le site et on laisse la fosse telle quelle (gratuit)."}[kind]
