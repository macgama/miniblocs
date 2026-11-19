extends SceneTree
## Vitrine « Routes en montagne » : sur un versant à 25 %, la ligne droite est
## refusée (rouge), une montée plus douce passe en zone orange, et le bouton
## « Lacets » propose un tracé en épingles, posé puis ouvert à la circulation.
## Usage (avec affichage) :
##   godot --path . --rendering-driver opengl3 --script res://tests/montagne_vitrine.gd -- --dossier /chemin/captures

var world: TerrainWorld


func _initialize() -> void:
	_run.call_deferred()


## Versant : plat à 800 m jusqu'à x = 0, puis 25 % vers l'est (plafond à 1 000 m).
static func relief(x: float, _z: float) -> float:
	return 800.0 + clampf(x, 0.0, 800.0) * 0.25


func _tile(t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	for y in 256:
		for x in 256:
			var gx := float(t.x * 256 + x)
			var gy := float(t.y * 256 + y)
			var lx := (gx - world._px0) / world._px_per_m
			var lz := (gy - Geo.lat_to_pixel_y(world.origin_lat, 15)) / world._px_per_m
			a[y * 256 + x] = relief(lx, lz)
	return a


func _shot(path: String) -> void:
	for i in 12:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(path)
	print("capture : ", path)


func _apercu(tr: TransportSystem, a: Vector3, b: Vector3) -> Dictionary:
	tr._start = {"node": -1, "edge": -1, "pos": a, "dir": Vector2.ZERO}
	tr._cursor = b
	tr._cursor_valid = true
	tr._update_preview()
	return tr._plan


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var dir := "."
	for i in args.size() - 1:
		if args[i] == "--dossier":
			dir = args[i + 1]
	root.size = Vector2i(1600, 900)
	Creations.persist = false
	BatimentsVie.chantiers = false
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	world = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var amb: DayNight = scene.get_node("Ambiance")
	root.add_child(scene)
	world.tiles.offline_generator = _tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.view_radius_override = 1500.0
	world.set_origin(46.2, 7.4)
	for i in 3000:
		await process_frame
		if i >= 120 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	Langue.activer("fr")
	amb.set_speed(0)
	amb.unix_time = Time.get_unix_time_from_datetime_string("2026-07-09T10:30:00")
	bs.unlimited_money = true
	var rig: Node3D = scene.get_node("CameraRig")
	var hy := func(x: float, z: float) -> Vector3: return Vector3(x, transport.ground_height(x, z), z)
	transport.set_build("departementale")
	rig.position = hy.call(110.0, 0.0)
	rig._target_distance = 330.0
	rig.set_pitch(40.0, true)
	rig.rotation_degrees.y = -70.0
	# 1. Tout droit dans la pente : refusé (rouge).
	var p1 := _apercu(transport, hy.call(-20.0, 0.0), hy.call(220.0, 0.0))
	print("droit : ", p1.reason)
	await _shot(dir.path_join("1-trop-raide-rouge.png"))
	# 2. En biais : 11,5 %, zone orange (plus cher, plus lent).
	rig.position = hy.call(60.0, 120.0)
	rig._target_distance = 300.0
	var p2 := _apercu(transport, hy.call(-20.0, 0.0), hy.call(130.0, 170.0))
	print("biais : ", p2.ok, " ", p2.get("avert", p2.reason), " surcoût ", p2.get("surcout", 0))
	await _shot(dir.path_join("2-zone-orange.png"))
	# 3. Bouton « Lacets » : tracé en épingles proposé.
	rig.position = hy.call(110.0, 0.0)
	rig._target_distance = 330.0
	transport.set_lacets(true)
	transport.spec_changed.emit(transport.type_id, transport.spec)
	var p3 := _apercu(transport, hy.call(-20.0, 0.0), hy.call(220.0, 0.0))
	print("lacets : ", p3.ok, " ", roundi(float(p3.length)), " m ", p3.get("avert", p3.reason))
	await _shot(dir.path_join("3-lacets-apercu.png"))
	# 4. Lacets posés, chantier terminé.
	var res := transport.build_path("departementale", {}, transport._current_path())
	print("posés : ", res.ok, " ", res.get("reason", ""))
	transport.cancel()
	if ChantiersVoies.instance != null:
		ChantiersVoies.instance.finir_tout()
	await process_frame
	rig.position = hy.call(100.0, 0.0)
	rig._target_distance = 260.0
	rig.set_pitch(52.0, true)
	await _shot(dir.path_join("4-lacets-construits.png"))
	rig._target_distance = 110.0
	rig.set_pitch(30.0, true)
	rig.rotation_degrees.y = -100.0
	rig.position = hy.call(160.0, 30.0)
	await _shot(dir.path_join("5-lacets-epingle.png"))
	quit(0)
