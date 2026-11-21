extends SceneTree
## Vitrine de l'objectif de séance et des alertes claires : carte de séance
## (médailles, temps, barre), bannière d'un palier, fil « À faire » limité à 3
## avec « Régler » et la cause dépliée (« ? »), Mairie avec « Pourquoi ? ».
## Usage (avec affichage) :
##   godot --path . --rendering-driver opengl3 --script res://tests/seance_vitrine.gd -- --dossier /chemin/captures


func _initialize() -> void:
	_run.call_deferred()


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


func _shot(path: String, n := 14) -> void:
	for i in n:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(path)
	print("capture : ", path)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var dir := "."
	for i in args.size() - 1:
		if args[i] == "--dossier":
			dir = args[i + 1]
	root.size = Vector2i(1600, 900)
	Langue.activer("fr")
	Creations.persist = false
	BatimentsVie.chantiers = true
	GameStart.chosen = true
	GameStart.place_name = "Valfleuri, Savoie"
	ReglagesPartie.prochaine = ReglagesPartie.preset("normal")
	ReglagesPartie.prochaine.deblocage = "tout"
	ReglagesPartie.prochaine.tutoriel = false
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var amb: DayNight = scene.get_node("Ambiance")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.view_radius_override = 900.0
	world.set_origin(45.5, 6.4)
	for i in 200:
		await process_frame
	amb.set_speed(0)
	amb.unix_time = Time.get_unix_time_from_datetime_string("2026-06-10T15:00:00")
	scene.urgences.random_calls = false
	scene.population.arrivals = false
	bs.require_access = false
	if scene.tutoriel.actif:
		scene.tutoriel.arreter()
	scene.kit.pays_de = func(_v: int) -> String: return "zz"
	scene.kit.pays_servis["zz"] = 0
	scene.communes.nom_en_attente = "Valfleuri"
	bs.place("maison_commune", Vector2i(0, 0), 0)
	for i in 10:
		await process_frame
	bs.unlimited_money = true
	var x := 60
	var n := 0
	while n < 14 and x < 500:
		for z in [-60, 60]:
			var c := Vector2i(x, z)
			if bs.check_place("colombages__maison", c, 0).ok and bs.place("colombages__maison", c, 0) > 0:
				n += 1
		x += 22
	bs.unlimited_money = false
	scene.fondateurs.repartir()
	scene.rig.position = Vector3(150, 0, 0)
	var se: Seance = scene.seance
	var vid: int = scene.communes.principal()
	scene.communes.calculer_stats()
	var h0 := int(scene.communes.stats[vid].hab)
	se.courante = {"type": "habitants", "titre": "Faire grandir la ville", "vid": vid, "debut": se.ecoule - 7.0 * 60.0,
		"pourquoi": "Plus d'habitants, plus d'impôts, et le prochain rang se rapproche.",
		"atteints": 0, "depart": float(h0), "cibles": [h0 + 10.0, h0 + 20.0, h0 + 30.0], "prime": 60000}
	scene.communes.stats[vid].hab = h0 + 13
	se.suivre()
	scene.statistiques.releve()
	scene.fil_alertes.refresh()
	await _shot(dir + "/1-carte-seance-et-banniere.png", 20)
	# Fil « À faire » : la cause des chantiers dépliée.
	for i in 300:
		await process_frame
	var ch := scene.fil_alertes._list.find_child("Alerte_chantiers_lents", true, false)
	if ch != null:
		(ch.find_child("Pourquoi", true, false) as Button).button_pressed = true
	await _shot(dir + "/2-a-faire-cause.png")
	scene.mairie_panel.set_open(true)
	await _shot(dir + "/3-mairie-pourquoi.png")
	scene.mairie_panel.set_open(false)
	scene.communes.stats[vid].hab = h0 + 40
	se.suivre()
	await _shot(dir + "/4-seance-reussie.png", 30)
	quit(0)
