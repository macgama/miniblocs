extends SceneTree
## Test de l'arbre de progression à points (ArbreProgression, ArbrePanel) :
## points gagnés (population, rangs, missions, succès), achat des niveaux dans
## l'ordre, verrous des bâtiments, voies et stations, époque avant l'arbre,
## mode « tout débloqué », panneau Maj+F10 et sauvegarde.
## Usage : godot --headless --path . --script res://tests/arbre_test.gd

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


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shift_f10() -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = KEY_F10
		e.physical_keycode = KEY_F10
		e.shift_pressed = true
		e.pressed = pressed
		root.push_input(e)
		await process_frame


func _run() -> void:
	print("Classement des bâtiments :")
	var A := ArbreProgression
	_check(A.niveau_batiment("maison") == 0 and A.branche_batiment("maison") == "logement", "maison : Logement 0")
	_check(A.niveau_batiment("ecole") == 0, "école : toujours ouverte")
	_check(A.niveau_batiment("maison_commune") == 0, "Maison de commune : toujours ouverte")
	var par_branche := {}
	var sans := 0
	for id in BuildingCatalog.all_types():
		var t: Dictionary = BuildingCatalog.get_type(id)
		# (créations du joueur : hors arbre, toujours ouvertes)
		if t.get("cache", false) or Creations.items.has(id):
			continue
		var b := A.branche_batiment(id)
		if b == "":
			sans += 1
			continue
		if not par_branche.has(b):
			par_branche[b] = [0, 0, 0, 0, 0]
		par_branche[b][A.niveau_batiment(id)] += 1
	print("    ", par_branche, " · hors arbre : ", sans)
	for b in A.BRANCHES:
		if String(b.id) != "transports":
			_check(par_branche.has(String(b.id)), "la branche %s ouvre des bâtiments" % b.nom)
	_check(sans == 0, "chaque bâtiment du catalogue a sa branche (%d sans)" % sans)
	_check(not A.contenu("logement", 0).ids.is_empty() and not A.contenu("transports", 1).noms.is_empty(), "contenu des niveaux listé")

	print("Points :")
	var r := ReglagesPartie.preset("normal")
	r.deblocage = "arbre"
	_check(A.points_disponibles(r) == A.POINTS_DEPART, "%d points au départ" % A.POINTS_DEPART)
	r.note_population(260)
	_check(A.points_gagnes(r) == A.POINTS_DEPART + 3, "260 habitants : +3 (50, 100, 250)")
	_check(A.prochain_seuil(r.record_habitants) == 500, "prochain point à 500 habitants")
	_check(String(r.journal_points[-1].raison) == "250 habitants", "journal : « 250 habitants »")
	_check(A.acheter(r, "logement") == "" and A.niveau(r, "logement") == 1, "Logement I acheté (1 point)")
	_check(A.acheter(r, "logement") == "" and A.niveau(r, "logement") == 2, "Logement II acheté (2 points)")
	_check(A.points_disponibles(r) == A.POINTS_DEPART + 3 - 3, "reste %d points" % A.points_disponibles(r))
	_check(A.points_disponibles(r) == 3 and A.acheter(r, "patrimoine") == "" and A.acheter(r, "patrimoine") == "", "Patrimoine I et II achetés")
	_check(A.acheter(r, "logement") != "" and A.niveau(r, "logement") == 2, "Logement III refusé : pas assez de points")
	_check(A.acheter(r, "inconnue") != "", "branche inconnue refusée")

	print("Verrous :")
	var grand := ""
	for id in A.contenu("logement", 3).ids:
		if Epoques.raison_batiment(id, r) == "":
			grand = id
			break
	_check(grand != "" and not r.est_debloque(grand), "logement de niveau III (%s) verrouillé" % grand)
	_check(r.raison_blocage(grand).contains("Logement III"), "raison : " + r.raison_blocage(grand))
	_check(r.raison_voie("autoroute").contains("Transports III") and r.raison_voie("rue") == "", "autoroute verrouillée, rue ouverte")
	_check(r.raison_station("aeroport").contains("Transports IV") and r.raison_station("arret_bus") == "", "aéroport verrouillé, arrêt de bus ouvert")
	A.gagner(r, 10, "test")
	for i in 3:
		A.acheter(r, "transports")
	_check(r.raison_voie("autoroute") == "" and r.raison_voie("lgv") != "", "Transports III : autoroute ouverte, LGV encore fermée")
	# L'époque passe avant l'arbre.
	r.annee_depart = 1850
	r.histoire_debut = 0.0
	_check(r.raison_voie("autoroute").contains("pas encore inventé"), "1850 : autoroute pas encore inventée malgré l'arbre")
	r.annee_depart = 0
	r.deblocage = "tout"
	_check(r.est_debloque(grand) and r.raison_station("aeroport") == "", "« tout débloqué » : rien de verrouillé")

	print("Sauvegarde des réglages :")
	r.deblocage = "arbre"
	var r2 := ReglagesPartie.new()
	r2.from_dict(JSON.parse_string(JSON.stringify(r.to_dict())))
	_check(r2.deblocage == "arbre" and A.niveau(r2, "transports") == 3 and A.niveau(r2, "logement") == 2, "niveaux retrouvés")
	_check(A.points_disponibles(r2) == A.points_disponibles(r) and r2.journal_points.size() == r.journal_points.size(), "points et journal retrouvés")
	var anc := r.to_dict()
	anc.deblocage = "progression"
	r2.from_dict(anc)
	_check(r2.deblocage == "arbre", "ancienne partie par paliers : passée sur l'arbre")

	print("Partie :")
	Creations.persist = false
	var pre := ReglagesPartie.preset("difficile")
	_check(pre.deblocage == "arbre", "préréglage Difficile : arbre de progression")
	ReglagesPartie.prochaine = pre
	GameStart.mode = GameStart.Mode.BAC_A_SABLE
	GameStart.load_slot = ""
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var bs: BuildingSystem = scene.get_node("Batiments")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.set_origin(46.52, 6.63)
	await _frames(60)
	var reg := ReglagesPartie.actuel
	_check(reg.deblocage == "arbre" and A.points_disponibles(reg) == A.POINTS_DEPART, "nouvelle partie : arbre vide, %d points" % A.points_disponibles(reg))
	var y := world.cell_height(Vector2i(0, 0))
	var plan: Dictionary = scene.transport.evaluate("autoroute", {}, PackedVector2Array([Vector2(300, -200), Vector2(300, 200)]))
	_check(not bool(plan.ok) and String(plan.reason).contains("Transports III"), "autoroute refusée : " + String(plan.reason))
	var st: Dictionary = scene.transport.stations.place("aeroport", Vector3(400, y, 400))
	_check(not bool(st.ok) and String(st.reason).contains("Transports IV"), "aéroport refusé : " + String(st.reason))
	var lock: Dictionary = bs.check_place(grand, Vector2i(60, 0), 3)
	_check(not lock.ok and String(lock.reason).contains("arbre de progression"), "grand logement refusé : " + String(lock.reason))

	# Objectifs : rang, mission, succès.
	var avant := A.points_gagnes(reg)
	A.rang_atteint("Bourg", "Testville")
	A.mission_reussie("Construire une école")
	A.succes_gagne("Première pierre")
	_check(A.points_gagnes(reg) == avant + 4, "Bourg +2, mission +1, succès +1")
	var obj = scene.get("objectifs")
	if obj != null:
		var g0 := A.points_gagnes(reg)
		obj.succes.erase("premier_village")
		obj.succes_debloque("premier_village")
		_check(A.points_gagnes(reg) == g0 + 1 or bs.unlimited_money, "succès des Objectifs : +1 point")

	# Panneau.
	var panel: ArbrePanel = scene.arbre_panel
	_check(panel != null and not panel.is_open(), "panneau créé, fermé")
	await _shift_f10()
	_check(panel.is_open(), "Maj+F10 ouvre l'arbre")
	var admin_ouvert: bool = scene.get_node_or_null("PanneauAdmin") != null and scene.get_node("PanneauAdmin").visible
	_check(not admin_ouvert, "Maj+F10 n'ouvre pas l'Admin")
	var dispo := A.points_disponibles(reg)
	panel._acheter("logement")
	await _frames(2)
	_check(A.niveau(reg, "logement") == 1 and A.points_disponibles(reg) == dispo - 1, "achat depuis le panneau")
	panel._selection = "transports"
	panel.refresh()
	_check(panel._body.get_child_count() > 20, "panneau rempli (%d lignes)" % panel._body.get_child_count())
	await _shift_f10()
	_check(not panel.is_open(), "Maj+F10 referme")

	print("Sauvegarde de la partie :")
	var slot := SaveGame.make_slot_id("test arbre")
	_check(scene.save_game(slot, "test arbre"), "sauvegarde (%s)" % scene.last_error)
	var niv := A.niveau(reg, "logement")
	var pts := A.points_disponibles(reg)
	ReglagesPartie.actuel = ReglagesPartie.preset("normal")
	_check(scene.load_game(slot), "chargement (%s)" % scene.last_error)
	reg = ReglagesPartie.actuel
	_check(reg.deblocage == "arbre" and A.niveau(reg, "logement") == niv and A.points_disponibles(reg) == pts, "arbre retrouvé au chargement (%d points)" % A.points_disponibles(reg))
	SaveGame.delete(slot)

	scene.queue_free()
	await _frames(2)
	print("TEST OK" if ok else "TEST ÉCHEC")
	quit(0 if ok else 1)
