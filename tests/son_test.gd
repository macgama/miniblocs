extends SceneTree
## Test du son : fichiers présents, bus et volumes, réglages du joueur, musique
## selon l'heure, ambiances selon la caméra (ville, nature, nuit, pluie, mer,
## altitude), chantiers, panneau Son (F2), clic des boutons.
## Fonctionne sans réseau (relief synthétique) et sans carte son (pilote muet).
## Usage : godot --headless --path . --script res://tests/son_test.gd

var ok := true


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	if not cond:
		push_error("ÉCHEC : " + what)
		ok = false
	else:
		print("  ok  ", what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _key(k: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.pressed = pressed
		root.push_input(e)
		await process_frame


func _flat_tile(t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	for y in 256:
		for x in 256:
			a[y * 256 + x] = 30.0
	return a


func _run() -> void:
	print("Fichiers :")
	var manque: Array = []
	for id in AmbiancesSonores.NAPPES + ["chantier"]:
		if Son.flux("ambiance/" + id, true) == null:
			manque.append("ambiance/" + id)
	for id in ["ui_clic", "ui_ouvrir", "ui_fermer", "ui_notification", "ui_erreur", "pose_batiment", "pose_route",
			"demolition", "chantier_fini", "argent", "palier", "election_gagnee", "election_perdue", "alerte",
			"tonnerre_1", "tonnerre_2", "cloches", "coq"]:
		if Son.flux("effets/" + id) == null:
			manque.append("effets/" + id)
	for id in Son.MORCEAUX:
		var st := Son.flux("musique/" + id)
		if st == null:
			manque.append("musique/" + id)
		elif st.get_length() < 60.0:
			manque.append("musique/%s trop court (%.0f s)" % [id, st.get_length()])
	_check(manque.is_empty(), "tous les sons et morceaux se chargent %s" % (str(manque) if not manque.is_empty() else ""))
	var pluie := Son.flux("ambiance/pluie", true) as AudioStreamOggVorbis
	_check(pluie != null and pluie.loop, "les ambiances bouclent")
	var fx := Son.flux("effets/argent") as AudioStreamOggVorbis
	_check(fx != null and not fx.loop, "les effets ne bouclent pas")

	print("Bus et volumes :")
	var son := Son.ici()
	await _frames(2)
	_check(son != null and son.is_inside_tree() and son.get_parent() == root, "nœud /root/Son créé à la demande")
	for b in Son.BUS:
		_check(AudioServer.get_bus_index(b) >= 0, "bus « %s »" % b)
	var avant := son.volumes.duplicate()
	son.set_volume("musique", 0.25)
	_check(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Musique")), linear_to_db(0.0625)), "volume Musique appliqué au bus")
	son.set_volume("ambiance", 0.0)
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Ambiance")), "volume 0 : bus coupé")
	var cf := ConfigFile.new()
	_check(cf.load(Son.CONFIG) == OK and is_equal_approx(float(cf.get_value("volumes", "musique")), 0.25), "réglages enregistrés dans user://son.cfg")
	son.volumes.musique = 0.9
	son.charger_reglages()
	_check(is_equal_approx(float(son.volumes.musique), 0.25), "réglages relus")
	for k in avant:
		son.volumes[k] = avant[k]
	son.sauver_reglages()
	son.appliquer_volumes()

	print("Musique :")
	_check(son.liste("menu") == ["une_terre_a_batir"], "globe : le thème du menu")
	_check(son.liste("nuit").has("lampadaires") and not son.liste("nuit").has("premier_coup_de_pioche"), "la nuit : morceaux de nuit")
	son.exclus = ["lampadaires"]
	_check(not son.liste("nuit").has("lampadaires"), "un morceau décoché sort de la liste")
	son.exclus = []
	son.lancer("valse_du_permis_de_construire")
	await _frames(2)
	_check(son.morceau == "valse_du_permis_de_construire" and son._music_cur.playing, "un morceau se lance")
	var titre := [""]
	son.morceau_change.connect(func(t: String) -> void: titre[0] = t)
	son.humeur_fn = func() -> String: return "nuit"
	son.suivant()
	_check(Son.MORCEAUX[son.morceau][1] in ["nuit", "soir"] and titre[0] == son.titre(son.morceau), "morceau suivant pris dans l'humeur du moment (%s)" % titre[0])
	son.humeur_fn = Callable()

	print("Effets :")
	Son.jouer("argent")
	Son.jouer("argent")
	var playing := 0
	for p in son._pool:
		if p.playing:
			playing += 1
	_check(playing == 1, "le même son deux fois de suite n'est joué qu'une fois")

	print("Clic des boutons :")
	var b := Button.new()
	root.add_child(b)
	await _frames(1)
	_check(b.has_meta("son_branche"), "un nouveau bouton fait « tic »")
	b.queue_free()

	print("Panneau Son :")
	await _key(KEY_F2)
	await _frames(2)
	var panel := son._panneau
	_check(panel != null and panel.is_inside_tree(), "F2 ouvre le panneau Son")
	if panel != null:
		(panel._sliders.general as HSlider).value = 50
		_check(is_equal_approx(float(son.volumes.general), 0.5), "le curseur Général règle le volume")
		(panel._sliders.general as HSlider).value = roundf(float(avant.general) * 100.0)
	await _key(KEY_ESCAPE)
	await _frames(2)
	_check(son._panneau == null, "Échap ferme le panneau")

	print("Ambiances dans la Terre :")
	Creations.persist = false
	GameStart.mode = GameStart.Mode.BAC_A_SABLE
	GameStart.load_slot = ""
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var bs: BuildingSystem = scene.get_node("Batiments")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.set_origin(48.8584, 2.2945)
	await _frames(40)
	var amb: AmbiancesSonores = scene.sons
	_check(amb != null and amb._players.size() == AmbiancesSonores.NAPPES.size(), "nappes d'ambiance prêtes")
	var day: DayNight = scene.ambiance
	day.set_local_hour(11.0)
	day.weather.mode = Meteo.Mode.SOLEIL
	day.weather.precip = 0.0
	day.weather.storm = 0.0
	scene.rig.position = Vector3(0, scene.rig.position.y, 0)
	scene.rig._target_distance = 40.0
	await _frames(20)
	amb.calculer()
	_check(float(amb.cible.nature_jour) > 0.5 and float(amb.cible.ville_jour) < 0.1, "campagne de jour : oiseaux (%.2f), pas de ville" % float(amb.cible.nature_jour))
	var y := world.cell_height(Vector2i(0, 0))
	bs.unlimited_money = true
	bs.require_access = false
	var n := 0
	for gx in range(-60, 61, 20):
		for gz in range(-60, 61, 20):
			if bs.place("maison", Vector2i(gx, gz), 0) >= 0:
				n += 1
	amb.calculer()
	_check(float(amb.cible.ville_jour) > 0.6 and float(amb.cible.ville_jour) > float(amb.cible.nature_jour),
		"%d maisons autour : ambiance de ville (%.2f)" % [n, float(amb.cible.ville_jour)])
	day.set_local_hour(23.5)
	await _frames(5)
	amb.calculer()
	_check(float(amb.cible.ville_nuit) > float(amb.cible.ville_jour), "la nuit : ville de nuit (nuit %.2f)" % day.night)
	day.weather.precip = 0.9
	day.weather.snow = 0.0
	amb.calculer()
	_check(float(amb.cible.pluie) > 0.6, "pluie : on l'entend (%.2f)" % float(amb.cible.pluie))
	day.weather.precip = 0.0
	scene.rig._target_distance = 3000.0
	await _frames(40)
	amb.calculer()
	_check(float(amb.cible.ville_nuit) < 0.2 and float(amb.cible.vent) > 0.3,
		"caméra très haute : la ville s'efface, le vent domine (h %.0f m)" % float(amb.mesure.hauteur))
	scene.rig._target_distance = 40.0
	await _frames(40)
	# Mer : le point écouté au-dessus de l'eau (hauteurs négatives).
	var mer_avant := amb._mer(Vector3(0, 0, 0))
	_check(mer_avant == 0.0, "pas de mer en pleine terre")
	# Chantier : une source qui annonce un chantier près de la caméra.
	amb.sources_chantiers.append(func() -> Array: return [Vector3(5, y, 5)])
	amb._placer_chantiers()
	_check(amb._chantiers[0].playing and amb._chantiers[0].global_position.distance_to(Vector3(5, y, 5)) < 0.1, "un chantier en activité s'entend sur place")
	amb.sources_chantiers.clear()
	amb._placer_chantiers()
	_check(not amb._chantiers[0].playing, "chantier fini : silence")
	# Orage : un éclair, puis le tonnerre.
	day.weather.flash = 1.0
	amb._flash_prev = 0.0
	amb._ponctuels(0.01)
	_check(amb._tonnerres.size() == 1, "un éclair : le tonnerre est en route")
	day.weather.flash = 0.0
	_check(son.humeur() in ["jour", "soir", "nuit"], "dans la ville, la musique suit l'heure (%s)" % son.humeur())
	_check(scene.hud.find_children("*", "Button", true, false).any(func(x) -> bool: return (x as Button).tooltip_text.begins_with("Son et musique")), "bouton Son dans la barre du haut")

	print("Aide :")
	var aide := false
	for sec in AidePanel.SECTIONS:
		if String(sec[0]).begins_with("Son"):
			aide = true
	_check(aide, "section Son et musique dans l'aide (F1)")

	scene.queue_free()
	await _frames(3)
	_check(not son.humeur_fn.is_valid() and son.humeur() == "jour", "partie fermée : la musique n'écoute plus l'ancienne ville")
	print("TEST OK" if ok else "TEST ÉCHEC")
	quit(0 if ok else 1)
