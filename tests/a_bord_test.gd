extends SceneTree
## Test « à bord des véhicules » : monter (E près d'un véhicule, Maj+V depuis la
## vue de dessus), caméra qui suit à la 3e et à la 1re personne, bandeau (vitesse,
## ligne, prochain arrêt), changement de véhicule, descente à côté, refus en plein
## vol, fin de course, machines agricoles et engins de chantier (groupe ABord.GROUPE).
## Fonctionne sans réseau (relief synthétique de tests/personnage_test.gd).
## Usage : godot --headless --path . --script res://tests/a_bord_test.gd

var ok := true
var world: TerrainWorld


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	if not cond:
		push_error("ÉCHEC : " + what)
		ok = false
	else:
		print("  ok  ", what)


func _fake_tile(t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	for y in 256:
		for x in 256:
			var gx := float(t.x * 256 + x)
			var gy := float(t.y * 256 + y)
			var lx := (gx - world._px0) / world._px_per_m
			var lz := (gy - Geo.lat_to_pixel_y(world.origin_lat, 15)) / world._px_per_m
			a[y * 256 + x] = 20.0 + 6.0 * exp(-((lx - 150.0) * (lx - 150.0) + lz * lz) / 2000.0)
	return a


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _touche(code: Key, maj := false) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.shift_pressed = maj
	ev.pressed = true
	Input.parse_input_event(ev)
	await process_frame
	var up := ev.duplicate() as InputEventKey
	up.pressed = false
	Input.parse_input_event(up)
	await process_frame


func _run() -> void:
	ReglagesPartie.actuel.construction_instantanee = true
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	world = scene.get_node("Terrain")
	var tr: TransportSystem = scene.get_node("Transport")
	var vue: VueSol = scene.get_node("VueSol")
	var rig: Node3D = scene.get_node("CameraRig")
	root.add_child(scene)
	world.tiles.offline_generator = _fake_tile
	world.set_origin(48.8584, 2.2945)
	for i in 30:
		await process_frame
	var traffic := tr.traffic
	traffic.set_enabled(false)
	traffic.clear()

	# Une route droite et deux arrêts de bus, une ligne de 1 bus.
	var r := tr.build_segment("route", Vector3(-80, 0, -60), Vector3(80, 0, -60))
	var r2 := tr.build_segment("route", Vector3(80, 0, -60), Vector3(80, 0, 80))
	_check(r.ok and r2.ok, "deux routes posées")
	var st := tr.stations
	var a1 := st.place("arret_bus", Vector3(-50, 0, -60))
	var a2 := st.place("arret_bus", Vector3(80, 0, 50))
	_check(a1.ok and a2.ok, "deux arrêts de bus")
	var ln := st.create_line([a1.id, a2.id], "", 1)
	_check(ln.ok, "ligne de bus créée")
	traffic.set_enabled(true)
	traffic.clear(true)
	await _frames(5)
	var bus := {}
	for v in traffic.vehicles:
		if v.has("line"):
			bus = v
	_check(not bus.is_empty(), "le bus de la ligne roule")
	if bus.is_empty():
		_fin()
		return

	print("Monter avec Maj+V depuis la vue de dessus :")
	var bp: Vector3 = (bus.body as Node3D).global_position
	rig.global_position = Vector3(bp.x + 20.0, rig.global_position.y, bp.z + 10.0)
	await _touche(KEY_V, true)
	_check(vue.a_bord() and is_same(vue.bord.v, bus), "Maj+V : à bord du bus le plus proche du centre de la vue")
	_check(vue.vue == VueSol.Vue.TROISIEME and vue.camera.current, "caméra au sol, 3e personne")
	_check(not vue.personnage.visible, "le personnage est caché pendant le trajet")
	_check(bus.has("aboard"), "le bus sait qu'il a quelqu'un à bord")
	await _frames(90)
	var corps: Node3D = bus.body
	var d_cam := vue.camera.global_position.distance_to(corps.global_position)
	_check(d_cam > 4.0 and d_cam < 40.0, "la caméra suit le bus de l'extérieur (%.1f m)" % d_cam)
	_check(vue.personnage.global_position.distance_to(corps.global_position) < 0.5, "le relief se charge autour du bus")
	var txt := vue._bord_texte.text
	_check(vue._bord_panneau.visible and txt.contains("km/h") and txt.contains(String(st.lines[ln.id].name)), "bandeau : nom, vitesse, ligne (« %s »)" % txt.replace("\n", " / "))
	_check(txt.contains(String(st.stations[a1.id].name)) or txt.contains(String(st.stations[a2.id].name)), "bandeau : prochain arrêt")
	var x0 := corps.global_position
	var t0 := Time.get_ticks_msec()
	while corps.global_position.distance_to(x0) < 2.0 and Time.get_ticks_msec() - t0 < 15000:
		await process_frame
	_check(corps.global_position.distance_to(x0) > 2.0, "le bus roule tout seul pendant qu'on est dedans (%.1f m)" % corps.global_position.distance_to(x0))

	print("1re personne :")
	await _touche(KEY_V)
	await _frames(3)
	_check(vue.vue == VueSol.Vue.PREMIERE and vue.a_bord(), "V à bord : place du conducteur, toujours à bord")
	var loc := corps.global_transform.affine_inverse() * vue.camera.global_position
	var bx: AABB = vue.bord.box
	_check(bx.grow(0.3).has_point(loc) and loc.z < bx.get_center().z, "la caméra est dans la cabine, à l'avant (%.1f ; %.1f ; %.1f)" % [loc.x, loc.y, loc.z])
	var avant := -vue.camera.global_transform.basis.z
	var avant_bus := -corps.global_transform.basis.z
	_check(avant.dot(avant_bus) > 0.8, "on regarde devant le bus")
	await _touche(KEY_V)
	_check(vue.vue == VueSol.Vue.TROISIEME, "V : retour à la caméra extérieure")

	print("Descendre :")
	await _touche(KEY_E)
	_check(not vue.a_bord() and vue.personnage.visible, "E : on descend, le personnage réapparaît")
	_check(not bus.has("aboard"), "le bus n'a plus personne à bord")
	var dp := vue.personnage.global_position.distance_to((bus.body as Node3D).global_position)
	_check(dp < 6.0, "posé à côté du bus (%.1f m)" % dp)
	var hp := world.cell_height(Vector2i(floori(vue.personnage.global_position.x), floori(vue.personnage.global_position.z)))
	_check(absf(vue.personnage.global_position.y - hp) < 1.0, "sur le sol (%.2f m, sol %.2f m)" % [vue.personnage.global_position.y, hp])

	print("Monter avec E au sol :")
	vue.personnage.teleporter((bus.body as Node3D).global_position + (bus.body as Node3D).global_transform.basis.x * 2.5, 0.0)
	await _touche(KEY_E)
	_check(vue.a_bord() and is_same(vue.bord.v, bus), "E près du bus : on remonte")

	print("Changer de véhicule (Maj+E) :")
	var benne := EnginsChantier.benne()
	scene.add_child(benne)
	benne.global_position = (bus.body as Node3D).global_position + Vector3(12, 0, 0)
	await _frames(2)
	await _touche(KEY_E, true)
	_check(vue.a_bord() and vue.bord.node == benne and vue.bord.nom == "Camion-benne", "Maj+E : dans le camion-benne du chantier voisin")
	_check(not bus.has("aboard"), "le bus est libéré")
	await _touche(KEY_V)
	await _frames(2)
	var lb := benne.global_transform.affine_inverse() * vue.camera.global_position
	_check(lb.z > 1.5 and lb.y > 1.8, "1re personne dans la cabine de l'engin (avant vers +Z)")
	var av := -vue.camera.global_transform.basis.z
	_check(av.dot(benne.global_transform.basis.z) > 0.8, "on regarde vers l'avant de l'engin")
	_check(vue._bord_texte.text.contains("chantier"), "bandeau de l'engin (« %s »)" % vue._bord_texte.text.replace("\n", " / "))
	await _touche(KEY_V)

	print("Machine agricole (fin de course et successeur) :")
	var tracteur := Node3D.new()
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.4, 2.8, 4.2)
	mi.mesh = bm
	mi.position.y = 1.4
	tracteur.add_child(mi)
	tracteur.add_to_group(ABord.GROUPE)
	tracteur.set_meta("nom_bord", "Tracteur et charrue")
	tracteur.set_meta("infos_bord", func() -> String: return "Aux champs · Labour")
	scene.add_child(tracteur)
	tracteur.global_position = Vector3(30, 20, 40)
	_check(vue.monter(ABord.cible_noeud(tracteur)), "à bord du tracteur")
	await _frames(10)
	_check(vue._bord_texte.text.contains("Labour"), "bandeau : la tâche aux champs")
	# La tâche change : l'engin est remplacé par un autre au même endroit.
	var suivant := tracteur.duplicate() as Node3D
	suivant.set_meta("nom_bord", "Tracteur et semoir")
	scene.add_child(suivant)
	suivant.global_position = tracteur.global_position + Vector3(1, 0, 0)
	tracteur.queue_free()
	await _frames(5)
	_check(vue.a_bord() and vue.bord.node == suivant, "engin remplacé : on reste à bord du nouveau")
	suivant.queue_free()
	await _frames(5)
	_check(not vue.a_bord() and vue.personnage.visible, "engin disparu : on descend sur place")

	print("Avion en vol :")
	var path_fn := func(_l: int, _a: int, _b: int) -> PackedVector3Array:
		return PackedVector3Array([Vector3(-200, 120, 100), Vector3(400, 120, 100)])
	_check(traffic.add_air_vehicle(9999, "biplan", 2, 0, path_fn, 0.0), "un biplan en vol")
	var avion: Dictionary = traffic.vehicles[traffic.vehicles.size() - 1]
	avion.dwell = 0.0
	await _frames(5)
	_check(vue.monter(ABord.cible_trafic(avion)), "à bord du biplan")
	_check(vue._bord_texte.text.contains("Biplan"), "bandeau : Biplan")
	await _touche(KEY_E)
	_check(vue.a_bord(), "E en plein vol : refusé, on reste à bord")
	traffic.vehicles.erase(avion)
	traffic._free_vehicle(avion)
	await _frames(3)
	_check(not vue.a_bord(), "avion retiré de la circulation : on est déposé")

	print("Voiture d'ambiance :")
	traffic.clear()
	_check(traffic.spawn(TransportTypes.Mode.ROAD), "une voiture d'ambiance")
	var car: Dictionary = traffic.vehicles[traffic.vehicles.size() - 1]
	_check(vue.monter(ABord.cible_trafic(car)), "à bord de la voiture")
	_check(vue._bord_texte.text.contains("Circulation"), "bandeau : circulation")
	traffic.demand = func() -> Dictionary: return {}
	traffic._spawn_timer = 0.0
	await _frames(10)
	_check(traffic.vehicles.has(car) and vue.a_bord(), "la voiture n'est pas retirée par la densité tant qu'on est dedans")
	traffic.demand = Callable()

	print("Retour à la vue de dessus (Maj+V à bord) :")
	await _touche(KEY_V, true)
	_check(vue.vue == VueSol.Vue.DESSUS and not vue.a_bord() and not car.has("aboard"), "vue de dessus, plus à bord")
	_check(Vector2(rig.global_position.x, rig.global_position.z).distance_to(Vector2((car.body as Node3D).global_position.x, (car.body as Node3D).global_position.z)) < 10.0, "la vue de dessus est centrée sur le véhicule")
	_fin()


func _fin() -> void:
	print("TEST OK" if ok else "TEST ÉCHEC")
	quit(0 if ok else 1)
