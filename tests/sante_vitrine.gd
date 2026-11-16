extends SceneTree
## Vitrine de la santé publique : une petite ville en 1832, le choléra arrive
## (rumeur, puis épidémie), et les 4 onglets du panneau F7.
## Usage (avec affichage) :
##   godot --path . --rendering-driver opengl3 --script res://tests/sante_vitrine.gd -- --dossier /chemin/captures


func _initialize() -> void:
	_run.call_deferred()


func _shot(path: String) -> void:
	for i in 12:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(path)
	print("capture : ", path)


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


func _run() -> void:
	var dossier := "user://captures_sante"
	var args := OS.get_cmdline_user_args()
	var i := args.find("--dossier")
	if i >= 0 and i + 1 < args.size():
		dossier = args[i + 1]
	DirAccess.make_dir_recursive_absolute(dossier)
	Creations.persist = false
	BatimentsVie.chantiers = false
	Langue.activer("fr")
	root.size = Vector2i(1600, 900)
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var amb: DayNight = scene.get_node("Ambiance")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.set_origin(48.8584, 2.2945)
	for k in 90:
		await process_frame
	Langue.activer("fr")
	var ev: Evenements = scene.evenements
	var pop: Population = scene.population
	var sp: SantePublique = scene.sante
	ev.forcer_auto = 0
	ev.forcer_catastrophes = 0
	amb.set_speed(0)
	amb.unix_time = Time.get_unix_time_from_datetime_string("2026-05-12T09:00:00")
	var r := ReglagesPartie.actuel
	r.annee_depart = 0
	bs.unlimited_money = true
	var y := world.cell_height(Vector2i(0, 0))
	transport.build_segment("route", Vector3(0, y, -260), Vector3(0, y, 120))
	transport.build_segment("route", Vector3(-120, y, -60), Vector3(120, y, -60))
	for k in 8:
		bs.place("maison", Vector2i(-12, -200 + k * 15), 1)
	for k in 4:
		bs.place("immeuble", Vector2i(16, -200 + k * 22), 3)
	bs.place("bureaux", Vector2i(20, 60), 3)
	bs.place("ecole", Vector2i(-30, 60), 1)
	pop._sync_buildings()
	for k in 72:
		pop.advance(300.0)
	r.annee_depart = 1831
	r.histoire_saut = 0
	r.histoire_debut = 0.0
	sp.forcer_historiques = 1
	sp._process(0.0)
	for d in 2:
		amb.unix_time += 86400.0
		ev._process(0.1)
		sp._process(0.0)
	Epoques.aller_a(1832)
	for d in 400:
		amb.unix_time += 86400.0
		ev._process(0.1)
		sp._process(0.0)
		if ev.epidemies.active >= 0:
			break
	for d in 6:
		amb.unix_time += 86400.0
		ev._process(0.1)
		sp._process(0.0)
	sp.set_mesure("quarantaine", true)
	sp.lancer_campagne("variole")
	amb.unix_time += 86400.0
	ev._process(0.1)
	sp._process(0.0)
	var rig = scene.rig
	rig.position = Vector3(-60, y, -110)
	rig._target_distance = 230.0
	for v in ["bilan", "vaccins", "mesures", "histoire"]:
		scene.sante_panel.set_open(true)
		scene.sante_panel.show_view(v)
		await _shot(dossier.path_join("sante-%s.png" % v))
	print("SANTE VITRINE OK")
	quit(0)
