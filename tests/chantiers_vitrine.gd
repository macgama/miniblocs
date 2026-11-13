extends SceneTree
## Vitrine des chantiers : une rue de maisons à toutes les étapes (fouille,
## fondations, murs, toit, finitions), un immeuble avec sa grue, et cinq routes
## à des étapes différentes (piquets, terre, grave, enrobé, marquage), un lundi
## matin (ouvriers au travail).
## Usage (avec affichage) :
##   godot --path . --script res://tests/chantiers_vitrine.gd -- --screenshot chantiers.png [--distance 90] [--yaw 30] [--vue routes] [--heure 10]


func _initialize() -> void:
	_run.call_deferred()


func _tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var shot := "chantiers.png"
	var dist := 95.0
	var yaw := 30.0
	var vue := "batiments"
	var heure := 10.0
	for i in args.size():
		if args[i] == "--screenshot" and i + 1 < args.size():
			shot = args[i + 1]
		if args[i] == "--distance" and i + 1 < args.size():
			dist = args[i + 1].to_float()
		if args[i] == "--yaw" and i + 1 < args.size():
			yaw = args[i + 1].to_float()
		if args[i] == "--vue" and i + 1 < args.size():
			vue = args[i + 1]
		if args[i] == "--heure" and i + 1 < args.size():
			heure = args[i + 1].to_float()
	Creations.persist = false
	ReglagesPartie.actuel = ReglagesPartie.preset("normal")
	BatimentsVie.chantiers = true
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	root.add_child(scene)
	world.tiles.offline_generator = _tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.set_origin(48.8584, 2.2945)
	for i in 90:
		await process_frame
	var amb: DayNight = scene.get_node("Ambiance")
	amb.set_speed(0)
	# Lundi 2 mars 2026, à l'heure demandée.
	amb.unix_time = float(Time.get_unix_time_from_datetime_string("2026-03-02T00:00:00")) - amb.utc_offset() * 3600.0 + heure * 3600.0
	var vie: BatimentsVie = scene.get_node("VieBatiments")
	var cv: ChantiersVoies = scene.get_node("ChantiersVoies")
	var suivi: SuiviChantiers = scene.get_node("Chantiers")
	vie._t_prev = amb.unix_time
	suivi._t_prev = amb.unix_time
	bs.unlimited_money = true
	bs.require_access = false
	var y := world.cell_height(Vector2i(0, 0))
	var rue := transport.build_segment("route", Vector3(-20, y, -60), Vector3(-20, y, 60))
	var focus := Vector3(0, y, 0)
	if vue == "batiments":
		var etapes := [0.04, 0.13, 0.45, 0.85, 0.96]
		for i in etapes.size():
			var bid := bs.place("colombages__maison", Vector2i(-6, -44 + i * 17), 3)
			if bid > 0:
				bs.buildings[bid]["av"] = etapes[i]
		var imm := bs.place("international__immeuble", Vector2i(22, 0), 3)
		if imm > 0:
			bs.buildings[imm]["av"] = 0.5
		focus = Vector3(0, y, 0)
	else:
		var etapes2 := [0.05, 0.25, 0.5, 0.76, 0.95]
		for i in etapes2.size():
			var x := -10.0 + i * 16.0
			var r := transport.build_segment("departementale", Vector3(x, y, -50), Vector3(x, y, 50))
			if r.ok:
				cv.commencer(r.edges)
				for eid in r.edges:
					suivi.chantiers[ChantiersVoies.cle(eid)].av = etapes2[i]
					cv._maj(eid, etapes2[i], [])
		focus = Vector3(22, y, 0)
	vie._update_chantiers()
	var rig = scene.get_node("CameraRig")
	rig.position = Vector3(focus.x, y, focus.z)
	rig._distance = dist
	rig._target_distance = dist
	rig.rotation_degrees.y = yaw
	for i in 40:
		await process_frame
	vie._update_chantiers()
	for i in 20:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(shot)
	print("Capture : ", shot)
	quit()
