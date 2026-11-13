extends SceneTree
## Vitrine des quartiers et arrêtés : trois quartiers peints sur la ville, la liste
## (Maj+Y), un quartier et ses arrêtés, le pinceau, la mairie perdue.
## Usage (avec affichage) :
##   godot --path . --rendering-driver opengl3 --script res://tests/quartiers_vitrine.gd -- --dossier /chemin/captures


func _initialize() -> void:
	_run.call_deferred()


func _shot(path: String, frames := 12) -> void:
	for i in frames:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(path)
	print("capture : ", path)


func _flat_tile(t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	for j in 256:
		for i in 256:
			var x := float(t.x * 256 + i)
			var z := float(t.y * 256 + j)
			a[j * 256 + i] = 40.0 + 3.0 * sin(x * 0.015) * cos(z * 0.012)
	return a


func _at(date: String, hour: float) -> float:
	return Time.get_unix_time_from_datetime_string(date + "T00:00:00") + (hour - 1.0) * 3600.0


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
	ReglagesPartie.prochaine.fondateurs = 0
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var amb: DayNight = scene.get_node("Ambiance")
	var rig: Node3D = scene.get_node("CameraRig")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.view_radius_override = 1600.0
	world.set_origin(45.5, 6.4)
	for i in 4000:
		await process_frame
		if i >= 120 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	scene.urgences.random_calls = false
	amb.set_speed(0)
	amb.unix_time = _at("2026-06-10", 16.0)
	var cm: Communes = scene.communes
	var q: Quartiers = scene.quartiers
	var panel: QuartiersPanel = scene.quartiers_panel
	var pop: Population = scene.population
	scene.villages_panel._dialog.hide()
	cm.nom_en_attente = "Valfleuri"
	var y := world.cell_height(Vector2i(-1000, 0))
	bs.place("maison_commune", Vector2i(-1000, -40), 0)
	var v1 := cm.principal()
	scene.pays.choisir(v1, true)
	scene.pays._poser(v1, 8_000_000)
	# Une petite ville : une grande rue, deux rues en travers, des maisons et des commerces.
	transport.build_segment("avenue", Vector3(-1300, y, 30), Vector3(-700, y, 30))
	transport.build_segment("route", Vector3(-1150, y, 30), Vector3(-1150, y, 260))
	transport.build_segment("route", Vector3(-850, y, 30), Vector3(-850, y, 260))
	for i in 18:
		for z in [52, 8]:
			var c := Vector2i(-1280 + i * 32, z)
			bs.place("maison", c, bs.best_rotation("maison", c))
	for i in 8:
		for x in [-1170, -1130, -870, -830]:
			var c := Vector2i(x, 70 + i * 24)
			bs.place("maison" if i % 3 else "immeuble", c, bs.best_rotation("maison", c))
	pop._sync_buildings()
	for i in 72:
		pop.advance(300.0)
	var a := q.creer("Les Tilleuls", v1)
	q.peindre_rect(a, Rect2i(-1300, -50, 300, 150))
	var b := q.creer("La Gare", v1)
	q.peindre_rect(b, Rect2i(-1000, -50, 300, 150))
	var c2 := q.creer("Les Vignes", v1)
	q.peindre_rect(c2, Rect2i(-1200, 100, 400, 200))
	for aid in ["zone_30", "calme_nuit", "espaces_verts", "detecteurs_fumee"]:
		q.adopter(a, aid)
	for aid in ["stationnement_payant", "poids_lourds"]:
		q.adopter(b, aid)
	for aid in ["rue_pietonne", "tri_obligatoire", "extinction_eclairage"]:
		q.adopter(c2, aid)
	q.calculer_stats()

	# 1. Les quartiers sur la ville, panneau ouvert sur la liste.
	panel.set_open(true)
	q.selection = -1
	panel.refresh()
	rig.position = Vector3(-1000, y, 110)
	rig._target_distance = 720.0
	rig.set_pitch(60.0, true)
	rig.rotation_degrees.y = 0.0
	await _shot(dir.path_join("quartiers-liste.png"), 90)

	# 2. Un quartier et ses arrêtés, avec le pinceau.
	q.selection = a
	q._sale = true
	q.set_outil("peindre", a)
	q.rayon = 2
	var cam: Camera3D = bs.camera
	panel.refresh()
	rig.position = Vector3(-1150, y, 30)
	rig._target_distance = 420.0
	rig.set_pitch(52.0, true)
	await _shot(dir.path_join("quartiers-arretes.png"), 30)
	q._survoler(cam.unproject_position(Vector3(-1180, y, 140)))
	await _shot(dir.path_join("quartiers-pinceau.png"), 10)

	# 3. Mairie perdue : lecture seule.
	q.set_outil("")
	var av: Avis = scene.avis
	var el := av.elections_de(v1)
	el.forcer_mode = "mairie"
	el.etat = "mandat"
	el.mandat_debut = av.jour()
	el.vote_jour = av.jour() + 30
	av.examiner(v1)
	el._elire({"id": "securite", "nom": "Valfleuri tranquille", "couleur": "577590", "tendance": "securite",
		"themes": ["securite"], "promesses": [], "joueur": false, "sortant": false, "tete": -1, "tete_nom": "Paul Girard"}, 55.0, "test", 60.0)
	av.examiner(av.ville_par_defaut())
	q.gerer_conseil(v1, "securite")
	q.selection = c2
	q._sale = true
	panel.refresh()
	await _shot(dir.path_join("quartiers-mairie-perdue.png"), 20)
	quit()
