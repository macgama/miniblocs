extends SceneTree
## Test du rendu cosy (RenduCosy) et de la verdure des jardins (Verdure) :
## réglages de l'environnement le jour et la nuit, couleurs douces du sol,
## arbres et fleurs autour des maisons (jamais sur une voie ni dans un
## bâtiment), retour au rendu d'avant quand l'option est coupée.
## Usage : godot --headless --path . --script res://tests/rendu_cosy_test.gd

var ok := true


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	if not cond:
		push_error("ÉCHEC : " + what)
		ok = false
	else:
		print("  ok  ", what)


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


func _run() -> void:
	Creations.persist = false
	BatimentsVie.chantiers = false
	DayNight.rendu_pousse = true
	RenduCosy.actif = true
	print("Ciel et lumière :")
	var jour := RenduCosy.sky_at(40.0)
	var nuit := RenduCosy.sky_at(-30.0)
	_check((jour[3] as Color).b > (jour[3] as Color).r, "ombres du jour bleutées (lumière du ciel)")
	_check(float(nuit[4]) >= 0.3, "la nuit reste lisible (ambiance %.2f)" % float(nuit[4]))
	_check((nuit[3] as Color).b > 0.5, "nuit bleue, pas noire")
	_check(RenduCosy.sun_color_at(2.0).b < RenduCosy.sun_color_at(40.0).b, "soleil plus orangé quand il est bas")

	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var amb: DayNight = scene.get_node("Ambiance")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.view_radius_override = 600.0
	world.set_origin(46.52, 6.63)
	for i in 3000:
		await process_frame
		if i >= 150 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	amb.set_speed(0)
	amb.unix_time = Time.get_unix_time_from_datetime_string("2026-06-21T12:00:00")
	amb.set_local_hour(13.0)
	var env := amb.env
	_check(env.ssao_enabled and env.ssao_light_affect > 0.0, "occlusion ambiante, visible même au soleil")
	_check(env.tonemap_mode == Environment.TONE_MAPPER_ACES, "tons ACES")
	_check(env.ambient_light_color.b > env.ambient_light_color.r, "lumière ambiante bleutée le jour")
	var sat_jour := env.adjustment_saturation
	var mat: ShaderMaterial = world._material
	_check(float(mat.get_shader_parameter("douceur")) > 0.5, "couleurs du sol adoucies")
	amb.set_local_hour(23.5)
	_check(env.glow_intensity > 0.6, "halo des lumières la nuit (%.2f)" % env.glow_intensity)
	_check(env.ambient_light_energy >= 0.3, "nuit éclairée en bleu (énergie %.2f)" % env.ambient_light_energy)
	_check(env.adjustment_saturation >= sat_jour, "couleurs de nuit au moins aussi vives")
	_check(amb.street.energie > 3.2, "lampadaires plus chauds et plus forts")

	print("Jardins :")
	bs.unlimited_money = true
	var o := Vector3(0, world.cell_height(Vector2i.ZERO), 0)
	transport.build_segment("rue", o + Vector3(-80, 0, 0), o + Vector3(80, 0, 0))
	var ids := []
	for x in [-50, -25, 0, 25, 50]:
		var c := Vector2i(x, 14)
		var bid := bs.place("maison", c, bs.best_rotation("maison", c))
		if bid >= 0:
			ids.append(bid)
	_check(ids.size() >= 3, "%d maisons posées le long de la rue" % ids.size())
	var v: Verdure = scene.verdure
	_check(v != null, "verdure branchée dans la scène")
	v.replanter()
	var n := v.compte()
	_check(n >= ids.size() * 4, "%d plantes dans les jardins" % n)
	var mal := 0
	var arbres := 0
	for bid in v._jardins:
		for p in v._jardins[bid]:
			var c: Vector2i = p[0]
			if bs.occupancy.has(c) or world.tree_blocker.call(c):
				mal += 1
			if Plantes.categorie(int(p[1])) == Plantes.Cat.ARBRE:
				arbres += 1
	_check(mal == 0, "aucune plante sur une voie ou dans un bâtiment")
	_check(arbres >= ids.size(), "au moins un arbre par maison (%d)" % arbres)
	_check(v.get_child_count() > 0, "plantes affichées (MultiMesh)")
	# Toujours les mêmes plantes au même endroit.
	var avant: Array = (v._jardins[ids[0]] as Array).map(func(p: Array) -> Vector2i: return p[0])
	v._jardins.clear()
	v.replanter()
	var apres: Array = (v._jardins[ids[0]] as Array).map(func(p: Array) -> Vector2i: return p[0])
	_check(avant == apres, "jardins identiques d'une fois sur l'autre")
	# Une maison démolie : son jardin disparaît.
	bs.demolish(ids[0])
	v.replanter()
	_check(not v._jardins.has(ids[0]), "jardin retiré avec la maison")

	print("Rendu d'avant :")
	RenduCosy.actif = false
	v.replanter()
	_check(v.compte() == 0, "sans rendu cosy, pas de jardins ajoutés")
	RenduCosy.init_terrain(world)
	_check(float(mat.get_shader_parameter("douceur")) == 0.0, "couleurs du sol d'avant")
	RenduCosy.actif = true

	print("TEST OK" if ok else "TEST ÉCHEC")
	quit(0 if ok else 1)
