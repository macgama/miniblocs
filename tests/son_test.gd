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
	for id in AmbiancesSonores.NAPPES + ["chantier", "nature_hiver"] + AmbiancesSonores.NAPPES_ANCIENNES.values() + AmbiancesSonores.LIEUX.keys() \
			+ ["sirene_pompiers", "sirene_police", "sirene_samu", "sirene_us", "sirene_japon", "cloche_pompiers", "sifflet_police"]:
		if Son.flux("ambiance/" + id, true) == null:
			manque.append("ambiance/" + id)
	for id in ["ui_clic", "ui_ouvrir", "ui_fermer", "ui_notification", "ui_erreur", "pose_batiment", "pose_route",
			"demolition", "chantier_fini", "argent", "palier", "election_gagnee", "election_perdue", "alerte",
			"tonnerre_1", "tonnerre_2", "cloches", "coq", "sifflet_vapeur",
			"but_foule", "sifflet_arbitre", "sonnerie_ecole", "cloche_main", "succes"]:
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
	son.annee_forcee = 0
	_check(not son.liste("jour").has("menuet_de_la_place"), "partie moderne : pas de musique d'époque")
	son.annee_forcee = 1850
	var l1850 := son.liste("jour")
	_check(l1850.has("menuet_de_la_place") and not l1850.has("premier_coup_de_pioche"), "1850 : musique d'époque seulement")
	_check(son.liste("nuit").has("nocturne_a_la_bougie"), "1850 : nocturne la nuit")
	_check(not l1850.has("swing_du_tramway"), "1850 : pas encore de swing")
	son.annee_forcee = 1910
	var l1910 := son.liste("jour")
	_check(l1910.has("menuet_de_la_place") and l1910.has("bal_musette_du_14_juillet") and not l1910.has("premier_coup_de_pioche"),
		"1910 : XIXe siècle et bal musette se mélangent")
	son.annee_forcee = 1930
	var l1930 := son.liste("jour")
	_check(l1930.has("swing_du_tramway") and l1930.has("premier_coup_de_pioche") and not l1930.has("menuet_de_la_place"),
		"1930 : swing et morceaux modernes, plus de menuet")
	_check(son.liste("nuit").has("clair_de_lune_sur_le_gazometre") and son.liste("soir").has("tango_du_cadastre"), "1930 : nocturne et tango")
	son.annee_forcee = 1990
	_check(not son.liste("jour").has("swing_du_tramway") and son.liste("jour").has("premier_coup_de_pioche"), "1990 : morceaux modernes")
	son.annee_forcee = 0
	_check(not son.liste("jour").has("bal_musette_du_14_juillet"), "partie moderne : pas de bal musette")
	son.annee_forcee = 1850
	_check(son.liste("menu") == ["une_terre_a_batir"], "1850 : le globe garde son thème")
	son.annee_forcee = -1
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
	_check(not amb.ancien and amb._players.trafic.stream == Son.flux("ambiance/trafic", true), "partie moderne : trafic moderne")
	amb.annee_forcee = 1850
	amb._maj_epoque()
	_check(amb.ancien and amb._players.trafic.stream == Son.flux("ambiance/trafic_attelages", true), "1850 : attelages au lieu des moteurs")
	_check(amb._players.ville_jour.stream == Son.flux("ambiance/ville_jour_ancien", true), "1850 : ville d'avant le moteur")
	amb.annee_forcee = 1925
	amb._maj_epoque()
	_check(not amb.ancien and amb._players.trafic.stream == Son.flux("ambiance/trafic", true), "1925 : retour aux moteurs")
	amb.annee_forcee = -1
	amb._maj_epoque()
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

	print("Saisons :")
	day.set_local_hour(15.0)
	amb.saison_forcee = AmbiancesSonores.ETE
	await _frames(5)
	day.weather.temperature = 31.0
	amb.calculer()
	_check(float(amb.cible.cigales) > 0.3, "été, 15 h, 31 °C : les cigales chantent (%.2f)" % float(amb.cible.cigales))
	amb.saison_forcee = AmbiancesSonores.HIVER
	day.weather.temperature = 2.0
	amb._maj_saison()
	amb.calculer()
	_check(amb.hiver and amb._players.nature_jour.stream == Son.flux("ambiance/nature_hiver", true) and float(amb.cible.cigales) == 0.0,
		"hiver : corneilles au lieu des oiseaux, pas de cigales")
	amb.saison_forcee = AmbiancesSonores.PRINTEMPS
	amb._maj_saison()
	day.set_local_hour(23.0)
	await _frames(5)
	day.weather.temperature = 16.0
	amb.calculer()
	_check(not amb.hiver and amb._players.nature_jour.stream == Son.flux("ambiance/nature_jour", true), "printemps : les oiseaux reviennent")
	amb.saison_forcee = -1

	print("Lieux de la ville :")
	_check(AmbiancesSonores.lieu_de("ecole", 10.2, 15.0, 0.0) == ["cour_recre", 1.0], "école à la récré de 10 h : cour animée")
	_check(String(AmbiancesSonores.lieu_de("ecole", 21.0, 15.0, 0.0)[0]) == "", "école le soir : silence")
	_check(String(AmbiancesSonores.lieu_de("piscine", 15.0, 28.0, 0.0)[0]) == "piscine" and float(AmbiancesSonores.lieu_de("piscine", 15.0, 12.0, 0.0)[1]) == 0.0,
		"piscine : pleine quand il fait chaud, vide quand il fait froid")
	_check(String(AmbiancesSonores.lieu_de("usine", 10.0, 15.0, 0.0)[0]) == "usine", "usine : machines")
	_check(String(AmbiancesSonores.lieu_de("cafe", 12.0, 20.0, 0.8)[0]) == "", "café sous la pluie : terrasse vide")
	day.set_local_hour(10.25)
	await _frames(3)
	var ecole := -1
	for gz in [90, 130, -100]:
		ecole = bs.place("ecole", Vector2i(10, gz), 0)
		if ecole >= 0:
			break
	if ecole >= 0 and bs.buildings[ecole].has("chantier"):
		bs.buildings[ecole].erase("chantier")
	EchelleTemps.force = 1.0
	amb.calculer()
	amb._placer_lieux()
	_check(ecole >= 0 and int(amb.lieux_actifs.get("cour_recre", 0)) >= 1 and (amb._lieux.cour_recre[0] as AudioStreamPlayer3D).playing,
		"une école posée : on entend la récré sur place (%s)" % str(amb.lieux_actifs))
	EchelleTemps.force = 0.0
	amb.calculer()
	amb._maj_pause()
	_check(amb.en_pause and float(amb.cible.trafic) == 0.0 and amb.figes >= 1,
		"temps en pause : trafic coupé, la récré se fige")
	EchelleTemps.force = 1.0
	amb.calculer()
	amb._maj_pause()
	_check(not amb.en_pause and amb.figes == 0 and (amb._lieux.cour_recre[0] as AudioStreamPlayer3D).playing, "le temps repart : la récré aussi")
	EchelleTemps.force = -1.0

	print("Sirènes :")
	_check(AmbiancesSonores.sirene_de("fpt", 0) == "sirene_pompiers", "pompiers : deux-tons")
	_check(AmbiancesSonores.sirene_de("police_nationale", 0) == "sirene_police", "police : son deux-tons rapide")
	_check(AmbiancesSonores.sirene_de("ambulance", 0) == "sirene_samu", "SAMU : trois tons")
	_check(AmbiancesSonores.sirene_de("police_us", 0) == "sirene_us" and AmbiancesSonores.sirene_de("police_japon", 0) == "sirene_japon", "sirènes américaine et japonaise")
	_check(AmbiancesSonores.sirene_de("fpt", 1880) == "cloche_pompiers" and AmbiancesSonores.sirene_de("police_nationale", 1880) == "sifflet_police",
		"1880 : cloche des pompiers à cheval, sifflet des sergents de ville")

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
