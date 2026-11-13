extends SceneTree
## Test du tutoriel guidé et des objectifs à l'écran : démarrage d'une partie
## neuve, étapes validées par les gestes du joueur (caméra, fondation, route,
## zonage, courant et eau, emplois, école, budget, objectifs), étapes sans objet
## sautées, « Passer », fin, relance depuis l'Admin, sauvegarde, carte à l'écran.
## Usage : godot --headless --path . --script res://tests/tutoriel_test.gd

var ok := true


func _initialize() -> void:
	_run.call_deferred()
	create_timer(400.0).timeout.connect(func() -> void:
		push_error("ÉCHEC : délai dépassé")
		quit(1))


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


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	Creations.persist = false
	BatimentsVie.chantiers = false
	GameStart.chosen = true
	GameStart.load_slot = ""
	GameStart.place_name = "Valfleuri, Savoie"
	ReglagesPartie.prochaine = ReglagesPartie.preset("normal")
	ReglagesPartie.prochaine.fondateurs = 0
	_check(ReglagesPartie.prochaine.tutoriel and ReglagesPartie.prochaine.objectifs_ecran, "tutoriel et objectifs à l'écran cochés par défaut")
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var zones: ZoneSystem = scene.get_node("Zones")
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
	bs.message.connect(func(t: String) -> void: print("     (bâtiments) ", t))
	var t: Tutoriel = scene.tutoriel
	var carte: TutorielCarte = scene.tuto_carte
	var y := world.cell_height(Vector2i(0, 0))

	print("Démarrage :")
	_check(t != null and carte != null and Tutoriel.instance == t, "tutoriel et carte branchés")
	_check(t.actif and t.id_courant() == "camera", "partie neuve : le tutoriel commence par la caméra (%s)" % t.id_courant())
	_check(not scene.villages_panel._dialog.visible, "pas de fenêtre de fondation par-dessus le tutoriel")
	await _frames(3)
	_check(carte._tuto_panel.visible and carte._titre_l.text == "Bienvenue, futur maire", "carte de l'étape à l'écran")
	_check(carte._obj_panel.visible, "objectifs à l'écran")
	_check(" ".join(carte.lignes_objectifs().map(func(l) -> String: return String(l[0]))).contains("Fonde ton village"), "objectifs : fonder d'abord")

	print("Étapes :")
	t.verifier()
	_check(t.id_courant() == "camera", "la caméra n'a pas bougé : on attend")
	scene.rig.position.x += 60.0
	t.verifier()
	_check(t.id_courant() == "fonder", "caméra déplacée : étape « fonder »")
	t.agir()
	_check(scene.villages_panel._dialog.visible, "bouton « Fonder mon village » : fenêtre du nom")
	scene.villages_panel._dialog.hide()
	scene.communes.nom_en_attente = "Valfleuri"
	var mc := bs.place("maison_commune", Vector2i(0, 0), 0)
	_check(mc > 0, "Maison de commune posée")
	t.verifier()
	_check(not t.faits.has("route") and t.id_courant() == "route", "village fondé, fondateurs sans objet (0 fondateur) : étape « route » (%s)" % t.id_courant())
	t.agir()
	_check(scene.hud._current_tool == TerreHud.FIRST_TRANSPORT_TOOL, "bouton : outil Route en main")
	_check(t.progres().begins_with("Route tracée : 0"), "progrès : %s" % t.progres())
	_check(transport.build_segment("route", Vector3(0, y, 12), Vector3(0, y, 220)).ok, "route tracée")
	t.verifier()
	_check(t.id_courant() == "zone_r", "étape « zone_r » (%s)" % t.id_courant())
	t.agir()
	_check(scene.build_panel.is_open() and scene.build_panel.category() == "zones", "bouton : Construire → Zonage")
	_check(zones.add_zone("R", Rect2i(6, 30, 16, 60)) > 0, "zone résidentielle")
	t.verifier()
	_check(t.id_courant() == "reseaux", "étape « reseaux » (%s)" % t.id_courant())
	print("     essai centrale : ", bs.check_place("eolienne", Vector2i(-20, 120), 1).get("reason", ""))
	var pn := bs.place("eolienne", Vector2i(-20, 120), 1)
	var fo := bs.place("forage_eau", Vector2i(-20, 180), 1)
	print("     centrale %d, forage %d, sources %s · %s" % [pn, fo, t.sources(), t.progres()])
	if pn < 0 or fo < 0:
		t.passer()
	t.verifier()
	_check(t.id_courant() == "temps", "étape « temps » (%s)" % t.id_courant())
	var v0: int = scene.ambiance.speed_index
	t.agir()
	_check(scene.ambiance.speed_index > v0, "bouton : le temps accélère (%d → %d)" % [v0, scene.ambiance.speed_index])
	scene.ambiance.set_speed(DayNight.DEFAULT_SPEED)
	_check(t.progres().contains("logés"), "progrès : %s" % t.progres())
	t.passer()
	_check(t.id_courant() == "emplois", "« Passer » : étape « emplois »")
	_check(zones.add_zone("C", Rect2i(6, 100, 14, 30)) > 0, "zone commerciale")
	t.verifier()
	_check(t.id_courant() == "ecole", "étape « ecole » (%s)" % t.id_courant())
	var ec := bs.place("ecole", Vector2i(-26, 60), 1)
	if ec < 0:
		ec = bs.place("ecole", Vector2i(28, 160), 1)
	_check(ec > 0, "école posée")
	t.verifier()
	_check(t.id_courant() == "budget", "étape « budget » (%s)" % t.id_courant())
	t.verifier()
	_check(t.id_courant() == "budget", "budget pas encore ouvert : on attend")
	t.agir()
	await _frames(2)
	t.verifier()
	_check(t.id_courant() == "objectifs", "budget ouvert : étape « objectifs » (%s)" % t.id_courant())

	print("Objectifs à l'écran :")
	scene.objectifs.nouveau_jour()
	carte._sig = ""
	var lignes := " / ".join(carte.lignes_objectifs().map(func(l) -> String: return String(l[0])))
	print("     ", lignes)
	_check(lignes.contains("Valfleuri : Hameau → Village"), "rang de la ville et le suivant")
	_check(lignes.contains("Missions du pays") and scene.objectifs.missions.size() > 0, "missions du pays")
	carte._refresh_objectifs()
	_check(carte._obj_body.get_child_count() >= 3, "lignes affichées (%d)" % carte._obj_body.get_child_count())
	t.replie = true
	carte._refresh_objectifs()
	_check(not carte._obj_body.visible, "objectifs repliés")
	t.replie = false
	carte.objectifs_requested.emit()
	await _frames(2)
	_check(scene.objectifs_panel.is_open(), "clic sur « Objectifs » : panneau Maj+J")
	t.verifier()
	_check(t.id_courant() == "fin", "panneau des objectifs vu : dernière étape")

	print("Sauvegarde :")
	var sec: Dictionary = scene.save_sections()
	_check(sec.has("tutoriel") and ReglagesPartie.actuel.to_dict().has("tutoriel"), "section « tutoriel » et réglage dans la sauvegarde")
	var d := t.to_dict()
	t.clear()
	_check(not t.actif and t.faits.is_empty(), "remise à zéro")
	t.from_dict(JSON.parse_string(JSON.stringify(d)))
	_check(t.actif and t.id_courant() == "fin" and t.faits.has("route") and t.faits.has("temps"), "étape et étapes faites rechargées")

	print("Fin et relance :")
	t.agir()
	_check(not t.actif and not ReglagesPartie.actuel.tutoriel, "« Terminer » : tutoriel fini, réglage décoché")
	await _frames(2)
	_check(not carte._tuto_panel.visible and carte._obj_panel.visible, "la carte de l'étape disparaît, les objectifs restent")
	t.set_actif(true)
	_check(t.actif and t.id_courant() == "camera", "relancé depuis l'Admin : reprend au début (%s)" % t.id_courant())
	scene.rig.position.x += 60.0
	t.verifier()
	_check(t.id_courant() == "temps" and t.faits.has("route") and t.faits.has("reseaux"), "étapes déjà faites sautées jusqu'à la première à faire (%s)" % t.id_courant())
	ReglagesPartie.actuel.objectifs_ecran = false
	await _frames(2)
	_check(not carte._obj_panel.visible, "objectifs à l'écran décochés : masqués")
	ReglagesPartie.actuel.objectifs_ecran = true
	scene.hud.create_mode = true
	await _frames(2)
	_check(not carte._tuto_panel.visible and not carte._obj_panel.visible, "carte masquée en mode Créer")
	scene.hud.create_mode = false

	print("Admin :")
	var adm := AdminPanel.new(ReglagesPartie.actuel, false, true)
	root.add_child(adm)
	await _frames(1)
	_check(adm._tutoriel.button_pressed == ReglagesPartie.actuel.tutoriel and adm._obj_ecran.button_pressed, "cases de l'Admin (section Aide)")
	adm._tutoriel.button_pressed = false
	_check(not ReglagesPartie.actuel.tutoriel, "décocher dans l'Admin change le réglage")
	adm.queue_free()

	print("RÉSULTAT : ", "OK" if ok else "ÉCHEC")
	quit(0 if ok else 1)
