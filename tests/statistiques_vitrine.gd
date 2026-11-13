extends SceneTree
## Vitrine des statistiques : une année de relevés inventés (deux villes qui
## grandissent, une caisse qui plonge puis remonte, des bouchons qui montent),
## puis captures du panneau Maj+I (courbes, comparaison des villes, conseiller).
## Usage (avec affichage) :
##   godot --path . --rendering-driver opengl3 --script res://tests/statistiques_vitrine.gd -- --dossier /chemin/captures


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


func _run() -> void:
	var dossier := "user://"
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--dossier" and i + 1 < args.size():
			dossier = args[i + 1]
	Creations.persist = false
	BatimentsVie.chantiers = false
	GameStart.chosen = true
	GameStart.place_name = "Valfleuri, Savoie"
	ReglagesPartie.prochaine = ReglagesPartie.preset("normal")
	ReglagesPartie.prochaine.fondateurs = 0
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
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
	var cm: Communes = scene.communes
	cm.nom_en_attente = "Valfleuri"
	bs.place("maison_commune", Vector2i(-1000, 0), 0)
	var v1 := cm.principal()
	cm.nom_en_attente = "Les Granges"
	var mc2 := bs.place("maison_commune", Vector2i(1100, 0), 0)
	var v2 := cm.village_du_batiment(mc2)
	var st: Statistiques = scene.statistiques
	st.auto = false
	st.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var j0 := st.jour() - 364
	for k in 365:
		var t := k / 364.0
		var h1 := 1200.0 / (1.0 + exp(-8.0 * (t - 0.45))) + rng.randf_range(-6, 6)
		var h2 := 0.0 if k < 120 else 380.0 / (1.0 + exp(-9.0 * (t - 0.7))) + rng.randf_range(-3, 3)
		var c1 := 2_400_000.0 - 3_100_000.0 * sin(clampf(t * 1.6, 0.0, PI)) + 900_000.0 * t
		var d := {}
		d[str(v1)] = {"habitants": h1, "satisfaction": 66.0 - 22.0 * sin(clampf(t * 1.6, 0.0, PI)) + rng.randf_range(-2, 2),
			"chomage": 6.0 + 9.0 * maxf(0.0, t - 0.55) + rng.randf_range(-0.5, 0.5), "caisse": c1,
			"solde": -90_000.0 * cos(clampf(t * 1.6, 0.0, PI)) * -1.0, "logements_libres": 30.0 * (1.0 - t), "emplois_libres": 80.0 * t,
			"sans_ecole": 0.0 if t < 0.8 else 12.0, "pollution": 12.0 + 20.0 * t}
		if k >= 120:
			d[str(v2)] = {"habitants": h2, "satisfaction": 72.0 + rng.randf_range(-2, 2), "chomage": 4.0, "caisse": 1_000_000.0 - 400_000.0 * t,
				"solde": -8_000.0, "logements_libres": 12.0, "emplois_libres": 5.0, "sans_ecole": 0.0, "pollution": 6.0}
		d[Statistiques.PAYS] = {"habitants": h1 + h2, "satisfaction": 64.0 - 18.0 * sin(clampf(t * 1.6, 0.0, PI)), "chomage": 6.0 + 8.0 * maxf(0.0, t - 0.55),
			"caisse": 8_000_000.0 - 3_000_000.0 * t, "solde": -20_000.0, "logements_libres": 30.0, "emplois_libres": 80.0, "sans_ecole": 0.0,
			"pollution": 10.0 + 18.0 * t, "electricite": 100.0 if t < 0.85 else 91.0, "eau": 100.0, "coupures": 0.0 if t < 0.85 else 14.0,
			"congestion": 5.0 + 40.0 * t * t + rng.randf_range(-2, 2), "trajet": 9.0 + 6.0 * t, "dechets": 0.0 if t < 0.9 else 3.0, "recyclage": 18.0 + 20.0 * t}
		st.historique.append({"j": j0 + k, "n": 1, "d": d})
	st.noms[str(v1)] = "Valfleuri"
	st.noms[str(v2)] = "Les Granges"
	var panel: StatsPanel = scene.stats_panel
	scene.villages_panel._dialog.hide()
	scene.pays.choisir(v1)
	panel.set_open(true)
	await _shot(dossier.path_join("stats-habitants.png"))
	panel.comparer = true
	panel.refresh()
	await _shot(dossier.path_join("stats-comparer.png"))
	panel.comparer = false
	panel.ind = "caisse"
	panel.refresh()
	await _shot(dossier.path_join("stats-caisse.png"))
	panel.lieu = Statistiques.PAYS
	panel.ind = "congestion"
	panel.refresh()
	await _shot(dossier.path_join("stats-bouchons.png"))
	panel.lieu = str(v1)
	panel.show_view("conseiller")
	await _shot(dossier.path_join("stats-conseiller.png"))
	quit(0)
