extends SceneTree
## Vitrine des événements : une petite ville, puis une capture par événement
## (marché, fête, match, incendie, dégâts et ruine, tempête).
## Usage (avec affichage) :
##   godot --path . --script res://tests/evenements_vitrine.gd -- --dossier captures/evenements [--seul match]


func _initialize() -> void:
	_run.call_deferred()


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


## Pose le long d'une route : verticale en x = 0 (h = false) ou horizontale en z = zr.
func _put(bs: BuildingSystem, id: String, from: int, h := false, zr := 0, sides := [1, -1]) -> int:
	for k in range(from, from + 400, 4):
		for side in sides:
			for r in 4:
				var fp := BuildingCatalog.footprint(id, r)
				for gap in [3, 6, 9]:
					var c := Vector2i(int(side) * (fp.x / 2 + gap), k)
					if h:
						c = Vector2i(k, zr + int(side) * (fp.y / 2 + gap))
					if bs.check_place(id, c, r).ok:
						return bs.place(id, c, r)
	print("non posé : ", id)
	return -1


func _cam(rig: Node3D, p: Vector3, dist: float, yaw: float, pitch: float) -> void:
	rig.position = p
	rig._distance = dist
	rig._target_distance = dist
	rig.rotation_degrees.y = yaw
	rig.set_pitch(pitch, true)


func _shot(dir: String, name: String, seul: String) -> void:
	for i in 40:
		await process_frame
	if seul != "" and seul != name:
		return
	var path := dir.path_join("evenements-%s.png" % name)
	root.get_viewport().get_texture().get_image().save_png(path)
	print("Capture : ", path)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var dir := "."
	var seul := ""
	for i in args.size():
		if args[i] == "--dossier" and i + 1 < args.size():
			dir = args[i + 1]
		if args[i] == "--seul" and i + 1 < args.size():
			seul = args[i + 1]
	DirAccess.make_dir_recursive_absolute(dir)
	Creations.persist = false
	BatimentsVie.chantiers = false
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var amb: DayNight = scene.get_node("Ambiance")
	var rig: Node3D = scene.get_node("CameraRig")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.set_origin(46.5197, 6.6323)
	GameStart.place_name = "Lausanne"
	for i in 60:
		await process_frame
	var ev: Evenements = scene.evenements
	var pop: Population = scene.population
	ev.forcer_auto = 0
	ev.forcer_catastrophes = 0
	amb.set_speed(0)
	amb.weather.mode = Meteo.Mode.SOLEIL
	amb.unix_time = Time.get_unix_time_from_datetime_string("2026-09-12T08:00:00")
	bs.unlimited_money = true
	var y := world.cell_height(Vector2i(0, 0))
	transport.build_segment("route", Vector3(0, y, -300), Vector3(0, y, 300))
	transport.build_segment("route", Vector3(0, y, 0), Vector3(-400, y, 0))
	transport.build_segment("route", Vector3(0, y, 120), Vector3(200, y, 120))
	var homes := []
	for i in 10:
		homes.append(_put(bs, "maison", -230 + i * 16, false, 0, [1]))
		homes.append(_put(bs, "maison", -230 + i * 16, false, 0, [-1]))
	var place := _put(bs, "place_pavee", -380, true, 0, [1])
	for i in 3:
		homes.append(_put(bs, "immeuble", -300 + i * 30, true, 0, [-1]))
	_put(bs, "boulangerie", -200, true, 0, [1])
	_put(bs, "cafe", -170, true, 0, [1])
	_put(bs, "pompiers", 40, false, 0, [1])
	_put(bs, "ecole", 30, false, 0, [-1])
	var stade := _put(bs, "stade_tuiliere", 10, true, 120, [1, -1])
	pop._sync_buildings()
	for i in 72:
		pop.advance(300.0)
	scene.get_node("PanneauConstruction").set_open(false)

	# Marché sur la place, samedi matin.
	var mid := ev.ajouter("marche", "Marché du samedi", ev.now() - 60.0, ev.now() + 5 * 3600.0, ev.building_pos(place), place, {"etals": 12})
	ev._process(0.1)
	amb.set_local_hour(10.0)
	_cam(rig, ev.building_pos(place), 38.0, 35.0, 38.0)
	await _shot(dir, "marche", seul)
	ev.finir(mid)

	# Fête de quartier, le soir.
	amb.set_local_hour(20.6)
	var fpos := Vector3(-250, y, 14)
	var fid := ev.ajouter("fete", "Fête de quartier", ev.now() - 60.0, ev.now() + 6 * 3600.0, fpos, -1, {})
	ev._process(0.1)
	_cam(rig, fpos, 34.0, 200.0, 30.0)
	await _shot(dir, "fete", seul)
	ev.finir(fid)

	# Match au stade : 1re mi-temps.
	amb.set_local_hour(16.0)
	if stade > 0:
		ev.matchs.club_de(stade)
		ev.matchs._schedule(stade, int(pop.now().day), 18.0, "Match de championnat", ev.matchs.club_de(stade), "Racing Val-Rhône", true)
		var me: Dictionary = ev.prevus("match")[0]
		amb.unix_time = float(me.debut) + Matchs.AVANT + 25 * 60.0
		for i in 120:
			ev._process(0.016)
			await process_frame
		var pel := Stades.pelouse_monde(bs, stade)
		_cam(rig, pel.centre, 120.0, 20.0, 42.0)
		await _shot(dir, "match", seul)
		_cam(rig, pel.centre, 45.0, 60.0, 30.0)
		await _shot(dir, "match-pres", seul)
		ev.finir(int(me.id))

	# Incendie : une maison brûle, le feu gagne la voisine.
	amb.set_local_hour(19.5)
	var burn: int = homes[6]
	ev.incendies.start_fire(burn, "manuel")
	ev.incendies.feux[burn].i = 1.0
	ev.set_degats(burn, 0.5, "incendie")
	ev.incendies.start_fire(homes[8], "propagation", int(ev.incendies.feux[burn].ev))
	for i in 60:
		ev._process(0.016)
		await process_frame
	_cam(rig, ev.building_pos(burn), 40.0, 120.0, 28.0)
	await _shot(dir, "incendie", seul)

	# Après : façades noircies, une ruine, un toit bâché.
	ev.resoudre(int(ev.events[int(ev.incendies.feux.get(burn, {"ev": -1}).ev)].data.inc) if ev.incendies.feux.has(burn) else -1)
	ev.set_degats(burn, 0.7, "incendie")
	ev.detruire(homes[8], "incendie")
	ev.set_degats(homes[10], 0.3, "tempete", true)
	ev.set_degats(homes[12], 0.25, "tempete", true)
	amb.set_local_hour(11.0)
	for i in 30:
		await process_frame
	_cam(rig, ev.building_pos(burn) + Vector3(0, 0, 15), 55.0, 120.0, 40.0)
	await _shot(dir, "degats", seul)

	# Tempête : arbre tombé sur la route, quartier sans courant le soir.
	amb.set_local_hour(14.0)
	var sid := ev.tempetes.start(ev.now(), 12.0, false)
	ev._process(0.1)
	var se: Dictionary = ev.events[sid]
	for i in 20:
		ev.tempetes._effets(se, amb.unix_time)
	var tree_pos := Vector3(0, y, -60)
	var best := 1e9
	for k in ev.tempetes.arbres:
		var tp := (ev.tempetes.arbres[k].node as Node3D).position
		if absf(tp.z + 100.0) < best:
			best = absf(tp.z + 100.0)
			tree_pos = tp
	_cam(rig, tree_pos, 40.0, 50.0, 32.0)
	await _shot(dir, "tempete", seul)

	# Panneau Infos.
	amb.set_local_hour(11.0)
	scene.evenements_panel.set_open(true)
	scene.evenements_panel.show_view("en_cours")
	_cam(rig, Vector3(0, y, -80), 260.0, 30.0, 50.0)
	await _shot(dir, "panneau", seul)
	quit(0)
