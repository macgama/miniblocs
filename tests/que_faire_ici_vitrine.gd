extends SceneTree
## Vitrine de la fiche « Que faire ici ? » : un clic en lisière de forêt, à côté
## des champs (Lorraine : fer, sel, gaz), en 2026 puis en 1800.
## Usage (avec affichage) :
##   godot --path . --rendering-driver opengl3 --script res://tests/que_faire_ici_vitrine.gd -- --dossier /chemin/captures


func _initialize() -> void:
	_run.call_deferred()


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


func _shot(path: String) -> void:
	for i in 40:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(path)
	print("capture : ", path)


## Fait défiler la fiche jusqu'au premier texte qui commence par `debut`.
func _defile_vers(f: QueFaireIci, debut: String) -> void:
	await process_frame
	for n in f._body.find_children("*", "Label", true, false):
		if (n as Label).text.begins_with(debut):
			f._scroll.scroll_vertical = int((n as Label).global_position.y - f._body.global_position.y) - 30
			return


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var dir := "."
	for i in args.size() - 1:
		if args[i] == "--dossier":
			dir = args[i + 1]
	# --desert : broussailles près de Las Vegas (aucune ferme à règle de sol).
	var desert := args.has("--desert")
	root.size = Vector2i(1600, 900)
	Creations.persist = false
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	var lat := 36.18 if desert else 49.15
	var lon := -115.13 if desert else 6.75
	if desert:
		world.land.offline_generator = func(_la: float, _lo: float) -> int: return 60
	else:
		world.land.offline_generator = func(_la: float, lo: float) -> int: return 10 if lo < lon else 40
	world.view_radius_override = 900.0
	world.set_origin(lat, lon)
	for i in 3000:
		await process_frame
		if i >= 150 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	var amb: DayNight = scene.get_node("Ambiance")
	amb.set_speed(0)
	amb.unix_time = Time.get_unix_time_from_datetime_string("2026-06-10T19:00:00" if desert else "2026-06-10T11:00:00")
	OptionsJeu.langue = "fr"
	Langue.activer("fr")
	var rig: Node3D = scene.rig
	rig.position = Vector3(-60, rig.position.y, 0)
	rig.max_distance = 2000.0
	rig._target_distance = 420.0
	scene.ouvrir_que_faire_ici(Vector2i(-60, 0))
	var f: QueFaireIci = scene.que_faire_ici
	if desert:
		await _shot(dir.path_join("desert-1-haut.png"))
		await _defile_vers(f, "Agriculture ici")
		await _shot(dir.path_join("desert-2-agriculture.png"))
		await _defile_vers(f, "Pour cultiver ici")
		await _shot(dir.path_join("desert-3-pour-cultiver.png"))
		# Un forage d'irrigation au bord d'une route : le désert devient cultivable.
		var bs: BuildingSystem = scene.get_node("Batiments")
		var tr: TransportSystem = scene.get_node("Transport")
		var y := world.cell_height(Vector2i(-60, 40))
		tr.build_segment("route", Vector3(-200, y, 40), Vector3(100, y, 40))
		var fd := int(BuildingCatalog.get_type("forage_irrigation").d)
		var c := Vector2i(-60, 40 - (fd / 2 + 6))
		bs.place("forage_irrigation", c, bs.best_rotation("forage_irrigation", c))
		scene.production._sync()
		f.ouvrir(Vector2i(-60, 0))
		await _shot(dir.path_join("desert-4-irrigue.png"))
		quit(0)
		return
	await _shot(dir.path_join("que-faire-ici-1-haut.png"))
	await _defile_vers(f, "Agriculture ici")
	await _shot(dir.path_join("que-faire-ici-5-agriculture.png"))
	f._scroll.scroll_vertical = 520
	await _shot(dir.path_join("que-faire-ici-2-chaines.png"))
	f._scroll.scroll_vertical = 100000
	await _shot(dir.path_join("que-faire-ici-3-pas-ici.png"))
	var r := ReglagesPartie.actuel
	if r != null:
		r.annee_depart = 1800
		r.histoire_saut = 0
		r.histoire_debut = 0.0
	f.ouvrir(Vector2i(-60, 0))
	f._scroll.scroll_vertical = 100000
	await _shot(dir.path_join("que-faire-ici-4-en-1800.png"))
	quit(0)
