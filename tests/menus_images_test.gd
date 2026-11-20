extends SceneTree
## Test des menus en images (ChoixVisuel, Pictos, VignettesVoies) :
## - ChoixVisuel se comporte comme une OptionButton (add_item, select, ids,
##   choisir → item_selected, grille de vignettes avec infobulles) ;
## - chaque illustration dessinée (Pictos) se rend, aussi en --headless ;
## - chaque classe de voie a une maquette 3D (tronçon + sol + véhicule) ;
## - les menus branchés (voies, croisement, carrefour, bords, météo, biomes,
##   filtres et cadrages photo, format du time-lapse, époque) sont en images ;
## - les nouveaux textes sont traduits dans les 4 langues ;
## - phase 2 : plus aucune OptionButton dans le jeu, chaque choix a une image
##   (vignette d'office, jauge, toit, timbre, champ, maillot, modèle 3D), les
##   menus nommés (toits, usages, continents, styles…) montrent leurs modèles.
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
	_test_partout()
	_test_illustrations()
	await _test_panneaux()
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


func _scan(d: String, out: Array) -> void:
	for f in DirAccess.get_files_at(d):
		if f.ends_with(".gd"):
			out.append(d.path_join(f))
	for sd in DirAccess.get_directories_at(d):
		_scan(d.path_join(sd), out)


func _test_partout() -> void:
	var fichiers: Array = []
	_scan("res://scripts", fichiers)
	var restes: Array[String] = []
	var n := 0
	for f in fichiers:
		var src := FileAccess.get_file_as_string(String(f))
		if src.contains("OptionButton") and not String(f).ends_with("choix_visuel.gd"):
			restes.append(String(f).get_file())
		n += src.count("ChoixVisuel.new()")
	_check(restes.is_empty(), "plus aucune liste de texte (OptionButton) dans le jeu %s" % [restes])
	_check(n >= 70, "%d menus à choix en images" % n)
	# Chaque choix a une image, même sans modèle : vignette d'office ou jauge.
	var c := ChoixVisuel.new()
	root.add_child(c)
	for t in ["Rares", "Normales", "Fréquentes"]:
		c.add_item(t)
	c.ouvrir()
	var vides := 0
	for i in 3:
		if (c.tuile(i).find_child("Image", true, false) as TextureRect).texture == null:
			vides += 1
	_check(vides == 0, "chaque vignette a une image dessinée d'office")
	_check(Pictos.icone_pour("2 semaines") == "horloge" and Pictos.icone_pour("500 k€") == "billet", "icône du thème devinée d'après le nom")
	var a := Pictos.auto("× 3", 2, 4, "grue", true).get_image()
	var b := Pictos.auto("× 1", 0, 4, "grue", true).get_image()
	_check(a.get_width() == 120 and a.get_data() != b.get_data(), "jauge : l'image change avec le rang")
	c.clear()
	c.gradue = -1
	for t in ["10 %", "25 %", "50 %"]:
		c.add_item(t)
	_check(c._est_gradue(), "liste de nombres : jauge d'office")
	c.queue_free()


func _test_illustrations() -> void:
	for k in Personnalisation.ROOF_ORDER:
		_check(Illustrations.connu("toit", String(k)), "toit « %s » dessiné" % Personnalisation.ROOFS[k])
	for t in VisiteVille.TIMBRES:
		_check(Illustrations.connu("timbre", String(t)), "timbre « %s » dessiné" % t)
	for u in ConstructionSouterraine.USAGE_ORDRE:
		_check(Pictos.has_picto("sous_" + String(u)), "pièce souterraine « %s » dessinée" % u)
	for cid in AgriDonnees.ORDRE_CULTURES:
		_check(Pictos.champ(String(cid)) != null, "champ de « %s »" % cid)
	for k in ClubDonnees.COULEURS:
		_check(Pictos.maillot(String(k[0]), String(k[1])) != null, "maillot %s / %s" % k)
	for c in ZooEspeces.CONTINENTS:
		_check(Illustrations.animal_de_continent(String(c)) != "", "continent « %s » : un animal (%s)" % [ZooEspeces.CONTINENTS[c], Illustrations.animal_de_continent(String(c))])
	for u in Mobilier.USAGE_ORDER:
		_check(Illustrations.connu("usage", String(u)), "usage « %s » : bâtiment %s" % [Mobilier.USAGES[u].name, Illustrations.batiment_de("usage", String(u))])
	for p in Meubles.CATEGORIES:
		_check(Illustrations.connu("piece", String(p)), "pièce « %s » : meuble %s" % [p, Illustrations.meuble_de_piece(String(p))])
	for f in SpectaclesObjets.SALLE_ORDER:
		_check(Illustrations.connu("piece", String(f)), "salle « %s » illustrée" % f)
	var manque: Array[String] = []
	for r in Styles.REGIONS:
		if r.id != "monde" and not Illustrations.connu("region", String(r.id)):
			manque.append(String(r.id))
	for e in Styles.ERAS:
		if not Illustrations.connu("epoque", String(e.id)):
			manque.append(String(e.id))
	_check(manque.is_empty(), "chaque région et chaque époque a une maison %s" % [manque])
	var sans: Array[String] = []
	for sid in Styles.STYLES:
		if not Illustrations.connu("style", String(sid)):
			sans.append(String(sid))
	_check(sans.is_empty(), "%d styles du zonage avec un bâtiment %s" % [Styles.STYLES.size(), sans])
	for f in CatalogueJeu.FAMILLES:
		_check(Illustrations.connu("famille", String(f[0])), "famille du catalogue « %s »" % f[1])
	for s in Partage.SORTES:
		_check(Illustrations.connu("icone_sorte", String(s)), "sorte partagée « %s »" % s)
	for c in Decors.categories():
		_check(Illustrations.connu("decor_cat", String(c.id)), "catégorie de décors « %s »" % c.nom)
	for e in Styles.ERAS:
		_check(Illustrations.connu("vehicule_epoque", String(e.id)) or String(e.id) == "antique", "véhicule de l'époque « %s »" % e.name)
	var l := ItemList.new()
	root.add_child(l)
	l.add_item("Toit")
	_check(Illustrations.poser_dans_liste("toit", "hip", l, 0) and l.get_item_icon(0) != null, "image posée dans une liste (décors)")
	l.queue_free()


func _test_panneaux() -> void:
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	root.add_child(scene)
	for i in 5:
		await process_frame
	var trouves := 0
	for c in scene.find_children("*", "Button", true, false):
		if c is ChoixVisuel:
			trouves += 1
	_check(trouves > 0, "%d menus en images construits dans la partie" % trouves)
	scene.queue_free()
	await process_frame
