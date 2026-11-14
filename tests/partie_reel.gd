extends SceneTree
## Banc « images en temps réel » sur une partie sauvegardée : recharge la partie,
## met le temps à la vitesse normale (1 jour par minute), caméra sur l'origine,
## et mesure la durée de chaque image.
##
##   godot --headless --path . --script res://tests/partie_reel.gd -- [--partie sauvegarde-auto] [--images 1500]
##
## La partie du banc tests/partie_pays.gd est sauvegardée dans « sauvegarde-auto » :
## lancer ce banc juste après donne la mesure sur 8 villes et 3 pays. Prendre au
## moins 1 500 images pour passer un minuit de jeu (les calculs du jour).


func _initialize() -> void:
	_run.call_deferred()


func _arg(nom: String, defaut: String) -> String:
	var a := OS.get_cmdline_user_args()
	var i := a.find("--" + nom)
	return a[i + 1] if i >= 0 and i + 1 < a.size() else defaut


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	Creations.persist = false
	var partie := _arg("partie", "sauvegarde-auto")
	var n := int(_arg("images", "1500"))
	change_scene_to_file("res://scenes/globe.tscn")
	await _frames(5)
	current_scene.load_saved_game(partie)
	var t0 := Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Terre") and Time.get_ticks_msec() - t0 < 60000:
		await process_frame
	var g: Node = current_scene
	if g == null or g.name != "Terre":
		print("ÉCHEC partie « %s » introuvable" % partie)
		quit(1)
		return
	# Sans internet, le relief manquant est plat (sinon le chargement attend le réseau).
	var w: TerrainWorld = g.get_node("Terrain")
	w.tiles.offline_generator = func(_t: Vector2i) -> PackedFloat32Array:
		var a := PackedFloat32Array()
		a.resize(65536)
		a.fill(260.0)
		return a
	while EcranChargement.actif != null and Time.get_ticks_msec() - t0 < 120000:
		await process_frame
	print("Partie « %s » chargée en %d ms (%d habitants)" % [partie, Time.get_ticks_msec() - t0, g.population.persons.size()])
	g.rig.position = Vector3.ZERO
	g.ambiance.set_speed(DayNight.DEFAULT_SPEED)
	await _frames(120)
	var ims: Array[float] = []
	var last := Time.get_ticks_usec()
	for i in n:
		await process_frame
		var now := Time.get_ticks_usec()
		ims.append((now - last) / 1000.0)
		last = now
	ims.sort()
	var moy := 0.0
	for x in ims:
		moy += x
	moy /= ims.size()
	var lentes := 0
	for x in ims:
		if x > 100.0:
			lentes += 1
	print("Images : moyenne %.1f ms (%.0f par seconde), médiane %.1f ms, 95 %% sous %.1f ms, pire %.0f ms, %d au-dessus de 100 ms" % [
		moy, 1000.0 / maxf(moy, 0.01), ims[ims.size() / 2], ims[int(ims.size() * 0.95)], ims[-1], lentes])
	print("PARTIE REEL OK")
	quit(0)
