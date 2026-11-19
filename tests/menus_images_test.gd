extends SceneTree
## Test des menus en images (ChoixVisuel, Pictos, VignettesVoies) :
## - ChoixVisuel se comporte comme une OptionButton (add_item, select, ids,
##   choisir → item_selected, grille de vignettes avec infobulles) ;
## - chaque illustration dessinée (Pictos) se rend, aussi en --headless ;
## - chaque classe de voie a une maquette 3D (tronçon + sol + véhicule) ;
## - les menus branchés (voies, croisement, carrefour, bords, météo, biomes,
##   filtres et cadrages photo, format du time-lapse, époque) sont en images ;
## - les nouveaux textes sont traduits dans les 4 langues.
## Usage : godot --headless --path . --script res://tests/menus_images_test.gd

var ok := true


func _initialize() -> void:
	_run.call_deferred()
	create_timer(120.0).timeout.connect(func() -> void:
		push_error("ÉCHEC : délai dépassé")
		quit(1))


func _check(cond: bool, what: String) -> void:
	if not cond:
		push_error("ÉCHEC : " + what)
		ok = false
	else:
		print("  ok  ", what)


func _run() -> void:
	_test_choix()
	_test_pictos()
	_test_voies()
	await _test_hud()
	_test_branchements()
	_test_traductions()
	print("RÉSULTAT : ", "OK" if ok else "ÉCHEC")
	quit(0 if ok else 1)


func _test_choix() -> void:
	var c := ChoixVisuel.new()
	root.add_child(c)
	var recus: Array[int] = []
	c.item_selected.connect(func(i: int) -> void: recus.append(i))
	c.add_item("Un", 10)
	c.add_item("Deux", 20, "route")
	c.add_item("Trois")
	_check(c.item_count == 3 and c.selected == 0, "3 choix, le premier choisi d'office")
	_check(c.get_item_id(1) == 20 and c.get_item_id(2) == 2 and c.get_item_index(20) == 1, "identifiants comme une OptionButton")
	_check(c.get_item_icon(1) != null and c.get_item_icon(0) == null, "icône du jeu sur le 2e choix")
	c.set_item_tooltip(2, "détail")
	c.select(2)
	_check(c.selected == 2 and c.get_selected_id() == 2 and recus.is_empty(), "select() ne prévient pas")
	_check(c.tooltip_text == "Trois\ndétail", "infobulle du bouton : nom + détail")
	c.ouvrir()
	_check(c.est_ouvert() and c.tuile(0) != null and c.tuile(2) != null and c.tuile(3) == null, "grille : une vignette par choix")
	_check((c.tuile(2) as Button).button_pressed and not (c.tuile(0) as Button).button_pressed, "vignette du choix actuel enfoncée")
	_check(c.tuile(2).tooltip_text == "Trois\ndétail", "infobulle de la vignette")
	c.tuile(1).pressed.emit()
	_check(recus == [1] and c.selected == 1 and not c.est_ouvert(), "clic sur une vignette : choisi, signal, grille fermée")
	c.set_item_disabled(0, true)
	c.choisir(0)
	_check(c.selected == 1 and recus.size() == 1, "choix désactivé : refusé")
	var vus: Array[int] = []
	var c2 := ChoixVisuel.new()
	c2.illustrer = func(i: int, _cible: TextureRect) -> void: vus.append(i)
	root.add_child(c2)
	c2.add_item("A")
	c2.add_item("B")
	c2.ouvrir()
	_check(vus.has(0) and vus.has(1), "illustrer appelé pour le bouton et chaque vignette")
	c.clear()
	_check(c.item_count == 0 and c.selected == -1, "clear()")
	c.queue_free()
	c2.queue_free()


func _test_pictos() -> void:
	var rates: Array[String] = []
	for nom in Pictos.SVG:
		var t := Pictos.get_picto(String(nom), 120)
		if t == null or t.get_width() != 120 or t.get_height() != 80:
			rates.append(String(nom))
	_check(rates.is_empty(), "%d illustrations rendues en 120 × 80 %s" % [Pictos.SVG.size(), rates])
	_check(Pictos.get_picto("inconnu") == null, "illustration inconnue : null")
	for f in ModePhoto.FORMATS:
		_check(Pictos.cadrage(float(f.r), 96) != null, "cadrage « %s »" % f.nom)
	var base := Pictos.get_picto("photo_scene", 60).get_image()
	var nb := Pictos.filtre_photo(1, 60).get_image()
	var p := nb.get_pixel(20, 6)
	_check(absf(p.r - p.g) < 0.02 and absf(p.g - p.b) < 0.02 and base.get_pixel(20, 6).b > base.get_pixel(20, 6).r + 0.1,
		"filtre noir et blanc : le ciel bleu devient gris")
	for f in ModePhoto.FILTRES:
		_check(Pictos.filtre_photo(int(f[1]), 60) != null, "aperçu du filtre « %s »" % f[0])


func _test_voies() -> void:
	var n := 0
	for mode in TransportTypes.BY_MODE:
		for id in TransportTypes.BY_MODE[mode]:
			var m := VignettesVoies.maquette(String(id))
			var box := m.get_aabb()
			var w := TransportTypes.width_of(String(id), TransportTypes.default_spec(String(id)))
			_check(m.get_surface_count() >= 2 and box.size.x >= w - 0.01 and box.size.z >= 20.0,
				"maquette 3D « %s » (%d surfaces, %.0f × %.0f m)" % [id, m.get_surface_count(), box.size.x, box.size.z])
			_check(m.surface_get_material(0) != null, "« %s » : matériau à couleurs de sommets" % id)
			_check(VignettesVoies.details(String(id)).contains("km/h"), "infobulle « %s » : %s" % [id, VignettesVoies.details(String(id))])
			if int(mode) != TransportTypes.Mode.PATH:
				_check(VignettesVoies.vehicule(String(id)) != "", "« %s » : un véhicule pour l'échelle (%s)" % [id, VignettesVoies.vehicule(String(id))])
			n += 1
	_check(n >= 30, "%d classes de voies illustrées" % n)


func _test_hud() -> void:
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	root.add_child(scene)
	for i in 5:
		await process_frame
	var hud: TerreHud = scene.hud
	_check(hud._class_pick is ChoixVisuel and hud._level_pick is ChoixVisuel, "outils de voies : choix en images")
	for t in [TerreHud.FIRST_TRANSPORT_TOOL, TerreHud.FIRST_TRANSPORT_TOOL + 1, TerreHud.FIRST_TRANSPORT_TOOL + 2, TerreHud.FIRST_TRANSPORT_TOOL + 3]:
		hud.choose_tool(t)
		await process_frame
		var mode := TransportTypes.mode_of(String(hud._class_ids[0])) if not hud._class_ids.is_empty() else -1
		_check(hud._class_pick.item_count == TransportTypes.BY_MODE.get(mode, []).size() and hud._class_pick.item_count > 0,
			"outil %d : %d classes dans la grille (%s)" % [t, hud._class_pick.item_count, hud._class_pick.titre])
	hud.choose_tool(TerreHud.FIRST_TRANSPORT_TOOL)
	await process_frame
	var recu := []
	hud.spec_edited.connect(func(id: String, _s: Dictionary) -> void: recu.append(id))
	hud._class_pick.ouvrir()
	hud._class_pick.tuile(4).pressed.emit()
	_check(recu.size() == 1 and recu[0] == hud._class_ids[4], "clic sur la vignette « %s » : classe choisie" % hud._class_pick.get_item_text(4))
	_check(hud._class_pick.tuile(0) == null or not hud._class_pick.est_ouvert(), "grille refermée")
	_check(hud._level_pick.get_item_icon(1) != null and hud._level_pick.get_item_icon(2) != null, "croisement : dessins pont et tunnel")
	var lv := []
	hud.level_changed.connect(func(l: String) -> void: lv.append(l))
	hud._level_pick.choisir(2)
	_check(lv == ["dessous"], "croisement « tunnel » choisi")
	for a in hud._junction_buttons:
		_check((hud._junction_buttons[a] as Button).icon != null, "carrefour : dessin « %s »" % a)
	var ev: EvolutionPanel = scene.get_node("PanneauEvolution")
	_check(ev._class is ChoixVisuel and ev._bords is ChoixVisuel, "Faire évoluer : classe et bords en images")
	scene.queue_free()
	await process_frame


func _test_branchements() -> void:
	_check(Pictos.has_picto("croisement_auto") and Pictos.has_picto("pont") and Pictos.has_picto("tunnel"), "dessins du croisement")
	for a in ["regime", "giratoire", "echangeur"]:
		_check(Pictos.has_picto(a), "dessin de l'action Carrefour « %s »" % a)
	for k in TransportTypes.BORDS:
		_check(Pictos.has_picto("bords_" + String(k)), "dessin des bords « %s »" % k)
	for k in TerrainWorld.PAINTABLE_KINDS:
		_check(Pictos.has_picto("biome_%d" % k), "dessin du biome « %s »" % TerrainWorld.KIND_NAMES[k])
	_check(Meteo.MODE_NAMES.size() == 8, "8 temps, 8 dessins de météo")
	var gm: GDScript = load("res://scripts/terre/globe_menu.gd")
	var ep: Array = gm.get_script_constant_map().EPOQUES
	var ev: Array = gm.get_script_constant_map().EPOQUES_VEHICULES
	_check(ep.size() == ev.size(), "un véhicule par époque de départ")
	for v in ev:
		_check(String(v) == "" or not VehicleCatalog.get_type(String(v)).is_empty(), "véhicule d'époque « %s » existe" % v)
	var sources := {
		"res://scripts/ambiance/clock_hud.gd": "_weather_pick = ChoixVisuel.new()",
		"res://scripts/terre/paysage_panel.gd": "_biome_pick = ChoixVisuel.new()",
		"res://scripts/photo/timelapse_panel.gd": "_fmt = ChoixVisuel.new()",
		"res://scripts/photo/mode_photo.gd": "var ofm := ChoixVisuel.new()",
		"res://scripts/terre/globe_menu.gd": "_epoque_opt = ChoixVisuel.new()",
	}
	for f in sources:
		_check(FileAccess.get_file_as_string(f).contains(sources[f]), "%s : menu en images" % String(f).get_file())


func _test_traductions() -> void:
	var textes := ["Aux croisements avec une autre voie (N)", "Carrefour à niveau quand c'est possible, sinon pont ou tunnel",
		"Toujours un pont au-dessus de l'autre voie", "Toujours un tunnel sous l'autre voie", "Nouvelle classe de la route",
		"Bords de la route", "Météo", "Biome à peindre", "Format de la caméra", "Filtre", "Cadrage", "Époque de départ",
		"%d km/h", "sens unique", "%d voie%s par sens", "voie unique", "double voie", "largeur %s m"]
	for code in ["en", "de", "it", "es"]:
		var data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/langues/%s.json" % code))
		var manque: Array[String] = []
		for t in textes:
			if not (data.textes as Dictionary).has(t):
				manque.append(t)
		_check(manque.is_empty(), "%s : textes des menus en images traduits %s" % [code, manque])
