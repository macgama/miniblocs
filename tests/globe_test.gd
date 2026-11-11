extends SceneTree
## Test du globe de départ : géométrie, clic, recherche, hasard, lancement.
## Fonctionne sans réseau (planète synthétique).
## Usage : godot --headless --path . --script res://tests/globe_test.gd
## Option : -- --screenshot chemin.png [--place lat,lon]  (vraie planète, nécessite un affichage)

var ok := true


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	if not cond:
		push_error("ÉCHEC : " + what)
		ok = false
	else:
		print("  ok  ", what)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var shot := ""
	var place := ""
	for i in args.size():
		if args[i] == "--screenshot" and i + 1 < args.size():
			shot = args[i + 1]
		if args[i] == "--place" and i + 1 < args.size():
			place = args[i + 1]

	var scene: Node = load("res://scenes/globe.tscn").instantiate()
	scene.offline = shot == ""
	root.add_child(scene)
	await process_frame

	if shot != "":
		var t0 := Time.get_ticks_msec()
		while scene._planet == null and Time.get_ticks_msec() - t0 < 90_000:
			await process_frame
		if place != "":
			var v: Variant = Geo.parse_lat_lon(place)
			scene.select_place(v.x, v.y, "Genève")
		for i in 90:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png(shot)
		print("Capture : ", shot)
		quit(0)
		return

	var G = scene.get_script()
	var p: Vector3 = G.lat_lon_to_point(46.2, 6.1)
	var back: Vector2 = G.point_to_lat_lon(p)
	_check(back.distance_to(Vector2(46.2, 6.1)) < 1e-4, "lat/lon -> point -> lat/lon")

	# Après avoir tourné le globe vers un lieu, le centre de l'écran doit viser ce lieu.
	scene.fly_to(-33.92, 18.42, 2.0, true)
	var center := root.get_viewport().get_visible_rect().size / 2.0
	var hit: Variant = scene.pick(center)
	_check(hit != null and (hit as Vector2).distance_to(Vector2(-33.92, 18.42)) < 0.5, "clic au centre = Le Cap (%s)" % [hit])
	scene.fly_to(0.0, 0.0, 4.0, true)
	_check(scene.pick(Vector2(2, 2)) == null, "clic dans l'espace = rien")

	scene._search.text = "gen"
	scene._refresh_list()
	_check(scene._list.item_count == 1 and scene._filtered[0][0] == "Genève", "recherche « gen » -> Genève")
	scene._list.item_selected.emit(0)
	_check(scene.selected and is_equal_approx(scene.sel_lat, 46.2044), "choisir Genève dans la liste")
	_check(not scene._start_btn.disabled, "bouton Commencer actif")
	var d: Dictionary = scene.describe_selection()
	_check(not d.is_empty() and d.kind == "Plaine" and is_equal_approx(d.height, 500.0), "aperçu du relief (%s)" % [d])

	_check(scene.pick_random_land(), "lieu au hasard trouvé")
	_check(scene.planet_height(scene.sel_lat, scene.sel_lon) > 5.0, "le hasard tombe sur la terre ferme")

	scene._coords.text = "48,8584 2,2945"
	scene._on_coords()
	_check(is_equal_approx(scene.sel_lon, 2.2945), "coordonnées tapées")

	scene.start_game()
	await process_frame
	await process_frame
	_check(GameStart.chosen and is_equal_approx(GameStart.lat, 48.8584), "choix transmis à la partie")
	var terre := current_scene
	_check(terre != null and terre.name == "Terre", "la scène Terre est lancée")
	if terre:
		var world: TerrainWorld = terre.get_node("Terrain")
		_check(is_equal_approx(world.origin_lat, 48.8584) and is_equal_approx(world.origin_lon, 2.2945), "la région est centrée sur le lieu choisi")

	print("GLOBE TEST OK" if ok else "GLOBE TEST ÉCHEC")
	quit(0 if ok else 1)
