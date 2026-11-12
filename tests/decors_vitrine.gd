extends SceneTree
## Captures des décors en jeu, sur de vrais lieux (relief et biomes téléchargés) :
## la Beauce en août (bottes de foin, route et ses poteaux), un pré avec son
## troupeau, le bord du lac d'Annecy (ponton, barques), une place de village.
## Usage (avec affichage et réseau) :
##   godot --path . --script res://tests/decors_vitrine.gd -- --dossier /chemin/captures


func _initialize() -> void:
	_run.call_deferred()


func _shot(path: String) -> void:
	for i in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)
	print("Capture : ", path)


func _wait_loaded(world: TerrainWorld, max_ms: int) -> void:
	var t0 := Time.get_ticks_msec()
	var stable := 0
	while Time.get_ticks_msec() - t0 < max_ms:
		await process_frame
		var busy := world.tiles.pending_count() + world.land.pending_count()
		stable = stable + 1 if busy == 0 and world.missing_chunk_count() == 0 and world._jobs.is_empty() else 0
		if stable > 40:
			break


## Le décor de cette liste le plus proche de l'origine : [x, y, z] ou [].
func _trouve(dec: DecorSystem, ids: Array) -> Array:
	var best := []
	var bd := INF
	for src: Dictionary in [dec._auto, dec._routes, dec.poses]:
		for k in src:
			for r: Array in src[k]:
				if r[0] in ids:
					var d := Vector2(r[1], r[3]).length()
					if d < bd:
						bd = d
						best = [r[1], r[2], r[3]]
	return best


func _lieu(scene: Node, lat: float, lon: float, date: String) -> void:
	var world: TerrainWorld = scene.get_node("Terrain")
	var amb: DayNight = scene.get_node("Ambiance")
	amb.set_speed(0)
	amb.weather.mode = Meteo.Mode.SOLEIL
	amb.unix_time = Time.get_unix_time_from_datetime_string(date + "T10:00:00") - lon / 15.0 * 3600.0 + 3600.0 * 5.0
	world.set_origin(lat, lon)
	await _wait_loaded(world, 90_000)
	world.temps_jours = amb.unix_time / 86400.0
	var dec: DecorSystem = scene.decors
	dec._champs_timer = 0.0
	dec._process(0.016)
	dec.calcule_autour(Vector3.ZERO)


func _vise(scene: Node, p: Array, dist: float, pitch: float, angle: float) -> void:
	var rig: Node3D = scene.get_node("CameraRig")
	if not p.is_empty():
		rig.position = Vector3(p[0], p[1], p[2])
	rig.rotation_degrees.y = angle
	rig._target_distance = dist
	rig.set_pitch(pitch, true)
	var dec: DecorSystem = scene.decors
	for i in 20:
		await process_frame
	dec.calcule_autour(rig.position)
	await _wait_loaded(scene.get_node("Terrain"), 30_000)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var dir := "user://captures"
	for i in args.size():
		if args[i] == "--dossier" and i + 1 < args.size():
			dir = args[i + 1]
	DirAccess.make_dir_recursive_absolute(dir)
	root.size = Vector2i(1600, 900)
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	root.add_child(scene)
	var transport: TransportSystem = scene.get_node("Transport")
	var world: TerrainWorld = scene.get_node("Terrain")
	var dec: DecorSystem = scene.decors

	# 1. Beauce, 12 août : moisson faite, bottes rondes ; une départementale.
	await _lieu(scene, 48.33, 1.62, "2026-08-12")
	var y := world.cell_height(Vector2i(0, 0))
	var rr := transport.build_segment("route", Vector3(-250, y, 0), Vector3(250, y, 0))
	print("Route : ", rr.get("ok"), " ", rr.get("reason", rr.get("error", "")))
	dec._calcule_routes()
	dec.calcule_autour(Vector3.ZERO)
	var b := _trouve(dec, ["botte_ronde", "botte_enrubannee"])
	await _vise(scene, [b[0] if not b.is_empty() else 0.0, y, 0.0], 70.0, 26.0, 200.0)
	await _shot(dir.path_join("decors-beauce-aout.png"))

	# 2. Un pré et son troupeau (Gruyère, Suisse).
	await _lieu(scene, 46.58, 7.08, "2026-06-20")
	var a := _trouve(dec, ["vache_pie_noire", "vache_broute", "vache_blanche", "cheval", "brebis", "mouton_broute", "vache_rousse"])
	await _vise(scene, a, 30.0, 40.0, 150.0)
	await _shot(dir.path_join("decors-pre-troupeau.png"))

	# 3. Bord du lac d'Annecy : ponton et bateaux.
	await _lieu(scene, 45.899, 6.135, "2026-07-14")
	var p := _trouve(dec, ["ponton", "ponton_court"])
	await _vise(scene, p, 55.0, 30.0, 40.0)
	await _shot(dir.path_join("decors-lac.png"))

	# 4. Place de village posée à la main (autour de l'origine de Gruyère).
	await _lieu(scene, 46.58, 7.08, "2026-06-20")
	var h := world.cell_height(Vector2i(0, 0))
	dec.efface(Vector3(0, h, 0), 30.0)
	dec.pose("fontaine", 0, 0)
	for k in 4:
		var ang := k * PI / 2.0
		var d := Vector3(sin(ang), 0, cos(ang))
		dec.pose("banc_vert", d.x * 6.0, d.z * 6.0, ang + PI)
		dec.pose("reverbere", d.x * 9.0 + d.z * 3.0, d.z * 9.0 - d.x * 3.0)
	for k in 3:
		dec.pose("terrasse_cafe", 8.0 + k * 3.2, 12.0, 0.4 * k)
		dec.pose(["etal_fruits", "tente_marche", "etal_fruits"][k], -12.0 + k * 4.5, 13.0, PI)
	dec.pose("statue", -13, -12, PI / 4.0)
	dec.pose("colonne_affichage", 13, -12)
	dec.pose("cabine_telephone", 15, -7, -PI / 2.0)
	dec.pose_ligne("haie", Vector3(-18, h, 19), Vector3(18, h, 19))
	dec.calcule_autour(Vector3.ZERO)
	await _vise(scene, [0.0, h, 0.0], 45.0, 35.0, 30.0)
	await _shot(dir.path_join("decors-place.png"))
	quit(0)
