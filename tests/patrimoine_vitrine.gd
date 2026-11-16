extends SceneTree
## Vitrine du patrimoine : les grands monuments, un chantier de cathédrale en
## cours, une église classée, et le menu Patrimoine (touche Fin).
## Usage (avec affichage) :
##   xvfb-run -a godot --path . --rendering-driver opengl3 --script res://tests/patrimoine_vitrine.gd -- \
##     --screenshot p.png --vue anciens|modernes|chantier|panneau|chantiers|monument [--id tour_fer]


func _initialize() -> void:
	_run.call_deferred()


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


func _at(date: String, hour: float) -> float:
	return Time.get_unix_time_from_datetime_string(date + "T00:00:00") + (hour - 2.0) * 3600.0


func _cam(rig: Node3D, p: Vector3, dist: float, yaw: float, pitch: float) -> void:
	rig.position = p
	rig.set("_distance", dist)
	rig.set("_target_distance", dist)
	rig.rotation_degrees.y = yaw
	if "pitch_degrees" in rig:
		rig.set("pitch_degrees", pitch)
	if rig.has_method("set_target_pitch"):
		rig.call("set_target_pitch", pitch)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var shot := "patrimoine.png"
	var vue := "anciens"
	var seul := "tour_fer"
	for i in args.size():
		if args[i] == "--screenshot" and i + 1 < args.size():
			shot = args[i + 1]
		if args[i] == "--vue" and i + 1 < args.size():
			vue = args[i + 1]
		if args[i] == "--id" and i + 1 < args.size():
			seul = args[i + 1]
	root.msaa_3d = Viewport.MSAA_DISABLED
	root.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	Creations.persist = false
	BatimentsVie.chantiers = true
	ReglagesPartie.actuel.construction_instantanee = false
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var amb: DayNight = scene.get_node("Ambiance")
	var transport: TransportSystem = scene.get_node("Transport")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.view_radius_override = 900.0
	world.set_origin(46.2, 6.9)
	for i in 3000:
		await process_frame
		if i >= 120 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	bs.unlimited_money = true
	amb.set_speed(0)
	amb.unix_time = _at("2026-09-19", 16.5)
	if amb.weather != null:
		amb.weather.set_process(false)
		amb.weather.precip = 0.0
		amb.weather.fog = 0.0
	var pat: Patrimoine = scene.patrimoine
	var vie: BatimentsVie = scene.vie_batiments
	var rig: Node3D = scene.get_node("CameraRig")
	var y := world.cell_height(Vector2i(0, 0))
	var rr := transport.build_segment("route", Vector3(-900, y, 0), Vector3(900, y, 0))
	print("route : ", rr.ok, " ", rr.get("reason", ""))
	var poser := func(id: String, c: Vector2i) -> int:
		var sn := bs.road_snap(id, c)
		if sn.is_empty():
			return bs.place(id, c, 0)
		return bs.place(id, sn.center, int(sn.r), 0, float(sn.get("a", 0.0)))
	var bids := {}
	var rangee := func(ids: Array, x0: float, cote: int) -> void:
		var x := x0
		for id in ids:
			var t := BuildingCatalog.get_type(String(id))
			x += float(t.w) / 2.0 + 14.0
			bids[id] = poser.call(String(id), Vector2i(int(x), cote * (int(float(t.d) / 2.0) + 10)))
			x += float(t.w) / 2.0
	match vue:
		"anciens", "panneau", "chantiers":
			rangee.call(["grande_cathedrale", "basilique_coupole", "grande_mosquee", "pagode_neuf_etages"], -330.0, -1)
			rangee.call(["grand_opera", "palais_cristal", "statue_colossale"], -330.0, 1)
		"modernes":
			rangee.call(["tour_fer", "gratte_ciel_art_deco", "tour_television", "tour_verre_600"], -330.0, -1)
			rangee.call(["arche_fraternite", "barrage_poids"], -330.0, 1)
		"chantier":
			rangee.call(["grande_cathedrale"], -60.0, -1)
		"monument":
			rangee.call([seul], -60.0, -1)
	# Quelques maisons pour l'échelle.
	for i in 10:
		var c := Vector2i(400 + i * 14, 12)
		bs.place("maison", c, bs.best_rotation("maison", c))
	vie.finish_all()
	pat.nouveau_jour()
	if vue in ["chantier", "chantiers"]:
		var cat := int(bids.get("grande_cathedrale", -1))
		if vue == "chantier":
			# Remettre la cathédrale en chantier : la nef monte derrière ses échafaudages.
			bs.remove_quietly(cat)
			cat = poser.call("grande_cathedrale", Vector2i(-20, -70))
			bids["grande_cathedrale"] = cat
		else:
			bs.remove_quietly(cat)
			cat = poser.call("grande_cathedrale", Vector2i(-300, -70))
		var b: Dictionary = bs.buildings[cat]
		b["av"] = 0.58
		vie._show_etape(cat)
		pat.lancer_souscription(cat)
		pat.souscriptions[cat]["recu"] = 3_400_000
		pat.souscriptions[cat]["mecenes"] = 2
	var focus := func(id: String) -> Vector3:
		return pat.pos_of(int(bids.get(id, -1)))
	match vue:
		"anciens":
			_cam(rig, Vector3(-120, 20, -10), 420.0, 200.0, 30.0)
		"modernes":
			_cam(rig, Vector3(-60, 60, 0), 750.0, 200.0, 22.0)
		"chantier":
			var c: Vector3 = focus.call("grande_cathedrale")
			_cam(rig, Vector3(c.x, 20, c.z), 170.0, 215.0, 28.0)
		"monument":
			var c: Vector3 = focus.call(seul)
			var h := BuildingCatalog.approx_height(seul)
			_cam(rig, Vector3(c.x, h * 0.35, c.z), maxf(140.0, h * 1.5), 200.0, 22.0)
		"panneau", "chantiers":
			_cam(rig, Vector3(-120, 20, -10), 420.0, 200.0, 30.0)
			var panel: PatrimoinePanel = scene.patrimoine_panel
			panel.set_open(true)
			panel.show_view("batir" if vue == "panneau" else "chantiers")
	for i in 90:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(shot)
	print("Vitrine patrimoine : %s → %s" % [str(bids), shot])
	quit(0)
