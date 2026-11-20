extends SceneTree
## Vitrine du sélecteur de villes : trois villes, photos prises en les visitant,
## boutons ◀ drapeau ▶ de la barre du haut et bande des villes en vignettes.
## Usage (avec affichage) :
##   godot --path . --rendering-driver opengl3 --script res://tests/selecteur_villes_vitrine.gd -- --dossier /chemin/captures


func _initialize() -> void:
	_run.call_deferred()


func _shot(path: String, frames := 12) -> void:
	for i in frames:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(path)
	print("capture : ", path)


func _tile(t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	for j in 256:
		for i in 256:
			var x := float(t.x * 256 + i)
			var z := float(t.y * 256 + j)
			a[j * 256 + i] = 40.0 + 5.0 * sin(x * 0.015) * cos(z * 0.012)
	return a


func _ville(scene: Node, nom: String, drapeau: String, c: Vector2i, n: int) -> int:
	var bs: BuildingSystem = scene.get_node("Batiments")
	var transport: TransportSystem = scene.get_node("Transport")
	var world: TerrainWorld = scene.get_node("Terrain")
	var cm: Communes = scene.communes
	cm.nom_en_attente = nom
	cm.drapeau_en_attente = drapeau
	bs.place("maison_commune", c, 0)
	var vid: int = cm.village_au_point(c.x, c.y)
	var y := world.cell_height(c)
	transport.build_segment("route", Vector3(c.x - 260, y, c.y + 30), Vector3(c.x + 260, y, c.y + 30))
	transport.build_segment("route", Vector3(c.x, y, c.y + 30), Vector3(c.x, y, c.y + 320))
	for i in n:
		var p := Vector2i(c.x - 240 + i * 26, c.y + 46)
		bs.place("maison" if i % 4 != 3 else "immeuble", p, bs.best_rotation("maison", p))
		var q := Vector2i(c.x - 240 + i * 26, c.y + 2)
		if absi(q.x - c.x) > 30:
			bs.place("maison", q, bs.best_rotation("maison", q))
	for i in n / 2:
		var p := Vector2i(c.x - 16, c.y + 70 + i * 22)
		bs.place("maison", p, bs.best_rotation("maison", p))
	return vid


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var dir := "."
	for i in args.size() - 1:
		if args[i] == "--dossier":
			dir = args[i + 1]
	root.size = Vector2i(1600, 900)
	Creations.persist = false
	BatimentsVie.chantiers = false
	GameStart.chosen = true
	GameStart.place_name = "Valfleuri, Savoie"
	ReglagesPartie.prochaine = ReglagesPartie.preset("normal")
	ReglagesPartie.prochaine.deblocage = "tout"
	ReglagesPartie.prochaine.fondateurs = 0
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var amb: DayNight = scene.get_node("Ambiance")
	var rig: Node3D = scene.get_node("CameraRig")
	root.add_child(scene)
	world.tiles.offline_generator = _tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.view_radius_override = 2300.0
	world.set_origin(45.5, 6.4)
	for i in 4000:
		await process_frame
		if i >= 120 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	scene.urgences.random_calls = false
	amb.set_speed(0)
	amb.unix_time = Time.get_unix_time_from_datetime_string("2026-06-10T00:00:00") + 15.0 * 3600.0
	scene.villages_panel._dialog.hide()
	(scene.get_node("Batiments") as BuildingSystem).unlimited_money = false
	print("terrain prêt")
	var v1 := _ville(scene, "Valfleuri", "fr", Vector2i(-1000, 0), 18)
	var v2 := _ville(scene, "Les Granges", "ch", Vector2i(1100, 0), 10)
	var v3 := _ville(scene, "Montbrison", "fr", Vector2i(0, 1900), 6)
	print("villes : ", scene.communes.villages.size())
	scene.communes.calculer_stats()
	var sel: SelecteurVilles = scene.selecteur_villes
	rig._target_distance = 260.0
	rig.set_pitch(52.0, true)
	for v in [v2, v3, v1]:
		sel.aller(v)
		for i in 90:
			await process_frame
		for i in 4:
			await process_frame
		sel.prendre_photo(v)
		for i in 4:
			await process_frame
	print("photos : ", sel.photos.size())
	if scene.tutoriel != null:
		scene.tutoriel.arreter()
		scene.tutoriel.set_actif(false)
	for b in scene.find_children("*", "BullesAide", true, false):
		(b as BullesAide).fermer()
	sel._sale = true
	await _shot(dir.path_join("1-barre-du-haut.png"), 30)
	sel.ouvrir()
	await _shot(dir.path_join("2-mes-villes.png"), 30)
	sel._fermer()
	sel._input(_ctrl_tab())
	await _shot(dir.path_join("3-ctrl-tab.png"), 30)
	quit()


func _ctrl_tab() -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = KEY_TAB
	e.ctrl_pressed = true
	e.pressed = true
	return e
