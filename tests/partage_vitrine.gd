extends SceneTree
## Vitrine du partage : un petit zoo-parc enregistré en plan de site, le menu
## Partage (onglets) et le plan reposé ailleurs, tourné.
## Usage (avec affichage) :
##   godot --path . --script res://tests/partage_vitrine.gd -- --screenshot p.png --vue partager|sites|decouvrir|pose|repose


func _initialize() -> void:
	_run.call_deferred()


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


func _cam(rig: Node3D, p: Vector3, dist: float, yaw: float, pitch: float) -> void:
	rig.position = p
	rig.set("_distance", dist)
	rig.set("_target_distance", dist)
	rig.rotation_degrees.y = yaw
	if "pitch_degrees" in rig:
		rig.set("pitch_degrees", pitch)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var shot := "partage.png"
	var vue := "sites"
	for i in args.size():
		if args[i] == "--screenshot" and i + 1 < args.size():
			shot = args[i + 1]
		if args[i] == "--vue" and i + 1 < args.size():
			vue = args[i + 1]
	root.msaa_3d = Viewport.MSAA_DISABLED
	root.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	Creations.persist = false
	BanqueModeles.persist = false
	PlansSites.persist = false
	Partage.persist = false
	BatimentsVie.chantiers = false
	Partage.echange = "user://vitrine_partage"
	_vider("user://vitrine_partage")
	Partage.local().root = "user://vitrine_partage/atelier_local"
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var amb: DayNight = scene.get_node("Ambiance")
	var transport: TransportSystem = scene.get_node("Transport")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.set_origin(46.2, 6.9)
	for i in 90:
		await process_frame
	Langue.activer("fr")
	bs.unlimited_money = true
	bs.require_access = false
	amb.set_speed(0)
	amb.unix_time = Time.get_unix_time_from_datetime_string("2026-07-17T09:00:00")
	if amb.weather != null:
		amb.weather.set_process(false)
		amb.weather.precip = 0.0
		amb.weather.fog = 0.0
	var rig: Node3D = scene.get_node("CameraRig")
	var y := world.cell_height(Vector2i(0, 0))
	transport.build_segment("route", Vector3(-200, y, -6), Vector3(200, y, -6))
	# Un petit zoo-parc : entrée, enclos de zèbres, manège, kiosques, allées, bancs.
	var zoo: ZooSysteme = scene.zoo
	zoo.ignore_staff = true
	var o := Vector2i(-60, 0)
	bs.place("entree_zoo", o + Vector2i(15, 6), 0)
	for id_pos in [["maison", Vector2i(50, 8)], ["maison", Vector2i(62, 8)], ["cafe", Vector2i(80, 8)]]:
		if not BuildingCatalog.get_type(String(id_pos[0])).is_empty():
			bs.place(String(id_pos[0]), o + id_pos[1], 0)
	var e1 := zoo.ajouter_enclos(PackedVector2Array([Vector2(o.x + 4, o.y + 20), Vector2(o.x + 34, o.y + 20), Vector2(o.x + 34, o.y + 44), Vector2(o.x + 4, o.y + 44)]), "grillage")
	for i in 4:
		zoo.acheter("zebre", e1)
	var e2 := zoo.ajouter_enclos(PackedVector2Array([Vector2(o.x + 40, o.y + 22), Vector2(o.x + 62, o.y + 22), Vector2(o.x + 62, o.y + 44), Vector2(o.x + 40, o.y + 44)]), "grillage")
	for i in 3:
		zoo.acheter("girafe", e2)
	var al: ParcAllees = scene.parc_allees
	al.ajoute_allee(Vector2(o.x + 15, o.y + 12), Vector2(o.x + 15, o.y + 18))
	al.ajoute_allee(Vector2(o.x + 4, o.y + 18), Vector2(o.x + 90, o.y + 18))
	var dec: DecorSystem = scene.decors
	for i in 8:
		dec.pose("banc_bois", o.x + 8.0 + i * 10.0, o.y + 16.5, 0.0)
	zoo._sync()
	var ctx: Dictionary = scene.contexte_partage()
	var cap := PlansSites.capture(ctx, Rect2i(o, Vector2i(100, 50)), "Le Petit Zoo de la Vallée")
	var plan := PlansSites.get_plan(String(cap.get("id", "")))
	Partage.publier("site", String(plan.get("id", "")), "Le Petit Zoo de la Vallée", "Zèbres, girafes, allée bordée de bancs.", ["savane", "famille"])
	var panel: PartagePanel = scene.partage_panel
	match vue:
		"partager", "sites", "decouvrir":
			_cam(rig, Vector3(-10, 20, 25), 120.0, 0.0, 50.0)
			panel.set_open(true)
			panel.show_view(vue)
		"pose":
			_cam(rig, Vector3(-10, 20, 90), 170.0, 0.0, 55.0)
			scene.outil_site.poser(plan)
			scene.outil_site.rot = 1
			scene.outil_site._refaire_boites()
			scene.outil_site._survol(Vector2i(30, 110))
		"repose":
			PlansSites.poser(plan, Vector2i(-40, 70), 1, ctx)
			_cam(rig, Vector3(-10, 20, 70), 200.0, 0.0, 55.0)
	for i in 60:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(shot)
	print("Vitrine partage : %s → %s" % [PlansSites.resume(plan), shot])
	quit()


func _vider(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for sub in d.get_directories():
		_vider(dir.path_join(sub))
	for f in d.get_files():
		d.remove(f)
	DirAccess.remove_absolute(dir)
