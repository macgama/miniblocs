extends SceneTree
## Vitrine des vols cinématiques : une petite ville fête ses 10 ans (feu
## d'artifice à 22 h, vol au-dessus), puis gagne le palier « Village » en plein
## jour (vol, titre, bulle d'habitant).
## Usage (avec affichage) :
##   godot --path . --script res://tests/grands_evenements_vitrine.gd -- --sortie dossier


func _initialize() -> void:
	_run.call_deferred()


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


func _at(date: String, hour: float) -> float:
	return Time.get_unix_time_from_datetime_string(date + "T00:00:00") + (hour - 2.0) * 3600.0


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("capture : ", path)


## Attend que le vol en soit à `secs` secondes.
func _avancer(secs: float) -> void:
	var vol: VolCinematique = root.get_node("Terre").vol_cinematique if root.has_node("Terre") else null
	for i in 3000:
		if vol == null or not vol.actif or vol.t >= secs:
			return
		await process_frame


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var sortie := "user://vitrine_vols"
	for i in args.size():
		if args[i] == "--sortie" and i + 1 < args.size():
			sortie = args[i + 1]
	DirAccess.make_dir_recursive_absolute(sortie)
	Langue.activer("fr")
	root.msaa_3d = Viewport.MSAA_DISABLED
	root.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	Creations.persist = false
	BatimentsVie.chantiers = false
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var amb: DayNight = scene.get_node("Ambiance")
	var transport: TransportSystem = scene.get_node("Transport")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.set_origin(46.2, 6.9)
	await _frames(90)
	bs.unlimited_money = true
	scene.evenements.forcer_auto = 0
	amb.set_speed(0)
	amb.unix_time = _at("2026-06-11", 21.9)
	if amb.weather != null:
		amb.weather.set_process(false)
		amb.weather.precip = 0.0
	amb._apply()
	if scene.tutoriel != null:
		scene.tutoriel.clear()
	scene.timelapse.set_process(false)
	var rig: Node3D = scene.rig
	rig.position = Vector3(0, 40, 0)
	var mairie := bs.place("maison_commune", Vector2i(0, -14), 0)
	scene.communes.actif = true
	var vid: int = scene.communes.fonder_au_point("Valbelle", Vector2(0, 0), mairie)
	scene.communes.villages[vid].fonde = _at("2016-06-11", 9.0)
	var y := world.cell_height(Vector2i(0, 0))
	transport.build_segment("rue", Vector3(-90, y, 0), Vector3(90, y, 0))
	transport.build_segment("rue", Vector3(0, y, 0), Vector3(0, y, 120))
	for i in 6:
		for row in [10, -12]:
			var cc := Vector2i(-80 + i * 28, row)
			bs.place("maison", cc, bs.best_rotation("maison", cc))
	for i in 5:
		for side in [12, -12]:
			var cc := Vector2i(side, 24 + i * 16)
			bs.place("maison", cc, bs.best_rotation("maison", cc))
	await _frames(60)
	var ge: GrandsEvenements = scene.grands_evenements
	var vol: VolCinematique = scene.vol_cinematique
	# Fête des 10 ans, déjà commencée : le feu d'artifice part à 22 h.
	var fid := ge.organiser_fete(Vector3(0, y, 0))
	scene.evenements.events[fid].data.ans = 10
	scene.evenements.events[fid].debut = amb.unix_time - 600.0
	amb.set_speed(1)
	await _frames(20)
	amb.unix_time = _at("2026-06-11", 22.02)
	await _frames(5)
	print("vol : ", vol.actif, " ", vol.plan.get("titre", ""))
	await _avancer(3.5)
	await _shot(sortie.path_join("1-fete-titre.png"))
	await _avancer(7.0)
	await _shot(sortie.path_join("2-fete-feux.png"))
	await _avancer(10.0)
	await _shot(sortie.path_join("3-fete-bulle.png"))
	vol.passer()
	# Palier en plein jour.
	amb.set_speed(0)
	amb.unix_time = _at("2026-06-12", 11.0)
	amb._apply()
	scene.communes.calculer_stats()
	scene.communes.stats[vid]["hab"] = 130
	scene.objectifs._cache["sat:%d" % vid] = [Time.get_ticks_msec() + 600000, 80]
	scene.objectifs.verifier_palier(vid)
	await _avancer(2.4)
	await _shot(sortie.path_join("4-palier-titre.png"))
	await _avancer(7.4)
	await _shot(sortie.path_join("5-palier-bulle.png"))
	quit(0)
