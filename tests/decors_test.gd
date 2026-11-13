extends SceneTree
## Vérifie les décors (assets/modeles/decors/*.glb) et leur pose :
## catalogue complet et léger, modèles posés au sol, Terre vierge (rien
## d'humain sans bâtiment), décors des routes et carrefours, pose par le
## joueur (un, en ligne, au pinceau, animaux qui bougent), gomme, sauvegarde.
## Usage : godot --headless --path . --import   (une fois, après de nouveaux .glb)
##         godot --headless --path . --script res://tests/decors_test.gd

const MAX_TRIS := 1600

var ok := true


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	if not cond:
		push_error("ÉCHEC : " + what)
		ok = false
	else:
		print("  ok  ", what)


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


func _tris(m: Mesh) -> int:
	var n := 0
	for s in m.get_surface_count():
		var a := m.surface_get_arrays(s)
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		n += idx.size() / 3 if idx.size() > 0 else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return n


func _run() -> void:
	print("Catalogue :")
	var tous := Decors.tous()
	_check(tous.size() >= 150, "%d décors au catalogue" % tous.size())
	var total := 0
	var sans_uv := []
	var en_l_air := []
	for e: Dictionary in tous:
		var m := Decors.mesh(e.id)
		if m == null:
			_check(false, "modèle %s.glb importé" % e.id)
			continue
		var t := _tris(m)
		total += t
		if t > MAX_TRIS:
			_check(false, "%s : %d triangles (max %d)" % [e.id, t, MAX_TRIS])
		var uv: Variant = m.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
		if uv == null or (uv as PackedVector2Array).is_empty():
			sans_uv.append(e.id)
		var b := m.get_aabb()
		if not Decors.sur_eau(e.id) and int(e.get("berge", 0)) == 0 and (b.position.y > 0.01 or b.position.y < -maxf(0.6, b.size.y * (0.65 if e.cat == "rochers" else 0.45))):
			en_l_air.append("%s (%.2f)" % [e.id, b.position.y])
	_check(sans_uv.is_empty(), "tous les modèles ont leurs couleurs (UV de la palette) %s" % [sans_uv])
	_check(en_l_air.is_empty(), "tous posés au sol %s" % [en_l_air])
	print("  %d triangles en tout" % total)
	for c: Dictionary in Decors.categories():
		_check(not Decors.de_categorie(c.id).is_empty(), "catégorie %s remplie (%d)" % [c.nom, Decors.de_categorie(c.id).size()])
	_check(Decors.materiau().albedo_texture != null and Decors.materiau().emission_texture != null, "palette et lumières chargées")
	_check(Decors.hauteur("pylone") > 25.0 and Decors.hauteur("poule_blanche") < 0.8 and absf(Decors.hauteur("vache_pie_noire") - 1.5) < 0.4,
		"tailles réelles (pylône %.0f m, vache %.1f m)" % [Decors.hauteur("pylone"), Decors.hauteur("vache_pie_noire")])
	_check(Decors.ligne("cloture_ranch") == 2.0 and Decors.est_anime("cheval") and Decors.sur_eau("voilier"), "options du catalogue (clôture, animal, bateau)")

	print("En jeu :")
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var amb: DayNight = scene.get_node("Ambiance")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	# Prés à l'ouest de l'origine, champs à l'est (Beauce).
	const LAT := 48.33
	const LON := 1.62
	world.land.offline_generator = func(_lat: float, lon: float) -> int: return 30 if lon < LON else 40
	world.view_radius_override = 500.0
	world.set_origin(LAT, LON)
	for i in 1500:
		await process_frame
		if i >= 60 and world.missing_chunk_count() == 0 and world._jobs.is_empty():
			break
	amb.set_speed(0)
	# 10 août : le blé est moissonné, le colza aussi (chaume).
	amb.unix_time = Time.get_unix_time_from_datetime_string("2026-08-10T12:00:00")
	world.temps_jours = amb.unix_time / 86400.0
	var dec: DecorSystem = scene.decors
	_check(dec != null and scene.decors_panel != null, "décors branchés dans la scène")
	dec.calcule_autour(Vector3.ZERO)
	# Terre vierge : rien d'humain sans bâtiment du joueur (ni enclos, ni bêtes
	# d'élevage, ni bottes de foin, ni machines ; l'agriculture s'en charge).
	var humains := 0
	for id in ["botte_ronde", "botte_enrubannee", "botte_debout", "pile_bottes", "tracteur", "tracteur_rouge", "epouvantail",
			"cloture_ranch", "cloture_barbelee", "abreuvoir", "cairn", "ponton", "ponton_court", "barque", "parasol_plage"]:
		humains += dec.nombre_de(id)
	var animaux := 0
	for e: Dictionary in tous:
		if Decors.est_anime(e.id):
			animaux += dec.nombre_de(e.id)
	_check(humains == 0 and animaux == 0, "Terre vierge en août : ni enclos, ni troupeau, ni bottes (%d décors humains, %d bêtes)" % [humains, animaux])
	_check(not dec._habite(Vector2.ZERO), "sans bâtiment, le lieu n'est pas habité")

	print("Routes :")
	var y := world.cell_height(Vector2i(0, 0))
	var r := transport.build_segment("route", Vector3(-300, y, 40), Vector3(300, y, 40))
	_check(r.ok, "route posée")
	transport.build_segment("route", Vector3(0, y, 40), Vector3(0, y, 250))
	dec._calcule_routes()
	dec.calcule_autour(Vector3.ZERO)
	_check(dec.nombre_de("poteau_electrique") >= 8, "campagne : poteaux électriques le long de la route (%d)" % dec.nombre_de("poteau_electrique"))
	_check(dec.nombre_de("balise") >= 8, "balises de bord de route (%d)" % dec.nombre_de("balise"))
	_check(dec.nombre_de("panneau_cedez") >= 1, "cédez-le-passage au carrefour (%d)" % dec.nombre_de("panneau_cedez"))
	var sur_route := 0
	for k in dec._routes:
		for d: Array in dec._routes[k]:
			if absf(float(d[3]) - 40.0) < 3.0 and absf(float(d[1])) < 290.0 and absf(float(d[1])) > 15.0:
				sur_route += 1
	_check(sur_route == 0, "rien n'est posé sur la chaussée")

	print("Pose par le joueur :")
	var n0 := dec.nombre_poses()
	_check(dec.pose("fontaine", 20.0, -60.0), "fontaine posée")
	_check(not dec.pose("inconnu", 0.0, 0.0), "décor inconnu refusé")
	var nl := dec.pose_ligne("cloture_bois", Vector3(-20, 0, -80), Vector3(20, 0, -80))
	_check(nl == 20, "clôture de 40 m : 20 tronçons (%d)" % nl)
	dec.choix = "vache_pie_noire"
	dec.rayon_pinceau = 10.0
	dec.densite = 1.0
	for i in 10:
		dec._seme(Vector3(-100, y, -100))
	var semees := dec.nombre_poses() - n0 - 21
	_check(semees >= 8, "pinceau : %d vaches semées" % semees)
	dec.calcule_autour(Vector3.ZERO)
	var avant := []
	for a: Dictionary in dec._animaux:
		avant.append(a.pos)
	for i in 400:
		dec._anime(0.05)
	var bouges := 0
	for i in dec._animaux.size():
		if (dec._animaux[i].pos as Vector2).distance_to(avant[i]) > 0.3:
			bouges += 1
	_check(bouges > 0, "les vaches semées se promènent (%d sur %d)" % [bouges, dec._animaux.size()])
	var loin := true
	for a: Dictionary in dec._animaux:
		loin = loin and (a.pos as Vector2).distance_to(a.home) < 12.0
	_check(loin, "elles restent près de leur place")
	_check(dec.nombre_de("fontaine") == 1 and dec.nombre_de("cloture_bois") == 20, "décors posés dessinés")
	var sauve := dec.to_dict()
	var retirees := dec.efface(Vector3(20, y, -60), 3.0)
	_check(retirees == 1 and dec.nombre_poses() == n0 + 20 + semees, "gomme : la fontaine est retirée")
	var effaces_avant := dec.effaces.size()
	var poteaux := dec.nombre_de("poteau_electrique")
	dec.efface(Vector3(0, y, 40), 60.0)
	dec._calcule_routes()
	dec.calcule_autour(Vector3.ZERO)
	_check(dec.effaces.size() > effaces_avant and dec.nombre_de("poteau_electrique") < poteaux, "gomme : efface aussi les poteaux automatiques (%d → %d)" % [poteaux, dec.nombre_de("poteau_electrique")])
	dec.from_dict(sauve)
	dec.calcule_autour(Vector3.ZERO)
	_check(dec.nombre_de("fontaine") == 1 and dec.nombre_poses() == n0 + 21 + semees, "sauvegarde : les décors reviennent")
	var j: Variant = JSON.parse_string(JSON.stringify(scene.save_sections()))
	_check(j is Dictionary and (j as Dictionary).has("decors"), "section « decors » dans la sauvegarde")
	DecorSystem.auto_actif = false
	dec._dessine(Vector3.ZERO)
	_check(dec.nombre_de("botte_ronde") == 0 and dec.nombre_de("fontaine") == 1, "sans décors automatiques, seuls ceux posés restent")
	DecorSystem.auto_actif = true

	print("Panneau :")
	scene.toggle_decors()
	_check(scene.decors_panel.visible and dec.outil == DecorSystem.Outil.POSER, "touche G : le panneau s'ouvre avec l'outil Poser")
	scene.toggle_decors()
	_check(not scene.decors_panel.visible and dec.outil == DecorSystem.Outil.AUCUN, "et se referme")

	scene.queue_free()
	await process_frame
	print("TEST OK" if ok else "TEST ÉCHEC")
	quit(0 if ok else 1)
