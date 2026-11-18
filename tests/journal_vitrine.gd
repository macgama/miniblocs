extends SceneTree
## Vitrine du journal : un petit village avec ses habitants, une journée chargée
## (incendie, pont vers nulle part, match, naissance, décès), puis la même page
## à trois époques (1823, 1925, 2026) et en anglais.
## Usage (avec affichage) :
##   godot --path . --rendering-driver opengl3 --script res://tests/journal_vitrine.gd -- --dossier /chemin/captures


func _initialize() -> void:
	_run.call_deferred()


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


func _shot(path: String) -> void:
	for i in 12:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(path)
	print("capture : ", path)


func _journee(scene: Node, j: Journal, y: float) -> void:
	var ev: Evenements = scene.evenements
	var pop: Population = scene.population
	var transport: TransportSystem = scene.get_node("Transport")
	ev.news("Incendie : Boulangerie du Centre ! Les pompiers sont appelés.", Vector3(-1000, y, 60), "incendie", 501)
	ev.news("Le feu gagne la maison voisine.", Vector3(-1000, y, 60), "incendie", 501)
	ev.news("Incendie maîtrisé : Boulangerie du Centre abîmée, façade à réparer.", Vector3(-1000, y, 60), "incendie", 501)
	ev.news("Marché du samedi terminé : 64 habitants venus, 1 200 € de droits de place.", Vector3.INF, "marche", 502)
	ev.news("Le club recrute un gardien de 19 ans.", Vector3.INF, "match")
	j._on_resultat({"sport": "football", "club": "FC Valfleuri", "adv": "Racing Annecy", "dom": true, "pour": 2, "contre": 1,
		"issue": "V", "buteurs": [], "affluence": 3800, "texte": "FC Valfleuri 2 – 1 Racing Annecy"})
	var ids: Array = pop.persons.keys()
	if ids.size() >= 3:
		var a: Dictionary = pop.persons[ids[0]]
		var b: Dictionary = pop.persons[ids[1]]
		pop.etape_vie.emit(a, "naissance", "Naît à Valfleuri", -1)
		pop.etape_vie.emit(b, "mariage", "Se marie", int(ids[2]))
	pop.etape_vie.emit({"id": 99001, "p": "Germaine", "n": "Rolland", "nj": pop.life_clock - 102.0 * 365.25, "s": "F"},
		"deces", "Meurt de vieillesse à 102 ans, entourée des siens", -1)
	var net := transport.network
	var n1 := net.add_node(Vector3(-760, y, 300), TransportTypes.Mode.ROAD)
	var n2 := net.add_node(Vector3(-700, y, 300), TransportTypes.Mode.ROAD)
	net.add_edge(n1, n2, "route", PackedVector3Array([Vector3(-760, y, 300), Vector3(-730, y + 5, 300), Vector3(-700, y, 300)]),
		PackedByteArray([TransportTypes.Struct.BRIDGE, TransportTypes.Struct.BRIDGE, TransportTypes.Struct.BRIDGE]))
	j.scanner()


func _run() -> void:
	var dossier := "user://"
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--dossier" and i + 1 < args.size():
			dossier = args[i + 1]
	Langue.activer("fr")
	Creations.persist = false
	BatimentsVie.chantiers = false
	GameStart.chosen = true
	GameStart.place_name = "Valfleuri, Savoie"
	ReglagesPartie.prochaine = ReglagesPartie.preset("normal")
	ReglagesPartie.prochaine.deblocage = "tout"  # (ce test ne porte pas sur l'arbre de progression)
	ReglagesPartie.prochaine.fondateurs = 0
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.view_radius_override = 1200.0
	world.set_origin(45.5, 6.4)
	for i in 3000:
		await process_frame
		if i >= 120 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	scene.urgences.random_calls = false
	Langue.activer("fr")
	var j: Journal = scene.journal
	j.auto = false
	var y := world.cell_height(Vector2i(0, 0))
	var cm: Communes = scene.communes
	cm.nom_en_attente = "Valfleuri"
	bs.place("maison_commune", Vector2i(-1000, 0), 0)
	transport.build_segment("route", Vector3(-1300, y, 40), Vector3(-700, y, 40))
	var pop: Population = scene.population
	var maisons := []
	for x in [-1200, -1150, -1100, -900, -850]:
		var b := bs.place("immeuble", Vector2i(x, 56), bs.best_rotation("immeuble", Vector2i(x, 56)))
		if b > 0:
			maisons.append(b)
	await process_frame
	for b in maisons:
		for _k in 3:
			pop.spawn_household(b, "couple")
	scene.rig.position = Vector3(-1000, 0, 60)
	j.clear()
	j.scanner()
	j.faits.clear()
	var panel: JournalPanel = scene.journal_panel
	for an in [1823, 1925, 2026]:
		scene.statistiques.releve()
		_journee(scene, j, y)
		j.annee_forcee = an
		j.publier()
		panel.set_open(true)
		await _shot(dossier.path_join("journal-%d.png" % an))
	Langue.activer("en")
	panel.refresh()
	await _shot(dossier.path_join("journal-2026-en.png"))
	Langue.activer("fr")
	quit(0)
