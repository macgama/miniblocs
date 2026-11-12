extends SceneTree
## Test des réglages de partie et du panneau Admin : préréglages, droits d'admin,
## prix, déblocage par paliers, économie, panneau, sauvegarde.
## Usage : godot --headless --path . --script res://tests/admin_test.gd

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


func _key(k: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.pressed = pressed
		root.push_input(e)
		await process_frame


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	print("Réglages :")
	var r := ReglagesPartie.preset("normal")
	_check(r.argent_depart == 20_000_000 and r.cout_construction == 1.0 and r.deblocage == "tout", "préréglage Normal = règles d'avant (20 M€, prix ×1, tout débloqué)")
	_check(r.preset_name() == "Normal", "nom du préréglage reconnu")
	r.cout_construction = 1.5
	_check(r.preset_name() == "Personnalisé", "réglage changé : Personnalisé")
	var d := ReglagesPartie.preset("difficile").to_dict()
	var r2 := ReglagesPartie.new()
	r2.from_dict(d)
	_check(r2.to_dict() == d, "aller-retour en dictionnaire")
	r2.from_dict({"cout_construction": 99.0, "impots": -3.0, "argent_depart": -5, "vitesse_temps": 42, "deblocage": "n'importe quoi"})
	_check(r2.cout_construction == ReglagesPartie.COUT_MAX and r2.impots == 0.0 and r2.argent_depart == 0, "valeurs hors bornes ramenées dans les bornes")
	_check(r2.vitesse_temps == DayNight.SPEEDS.size() - 1 and r2.deblocage == "tout", "vitesse et déblocage bornés")

	print("Qui est admin :")
	var M := GameStart.Mode
	_check(ReglagesPartie.peut_administrer(M.BAC_A_SABLE, "a", "b", false), "bac à sable : tout le monde")
	_check(ReglagesPartie.peut_administrer(M.ENTRE_AMIS, "a", "a", false), "entre amis : le créateur")
	_check(not ReglagesPartie.peut_administrer(M.ENTRE_AMIS, "a", "b", false), "entre amis : pas les invités")
	_check(not ReglagesPartie.peut_administrer(M.MONDIALE, "a", "a", false), "carte mondiale : pas les joueurs, même le créateur")
	_check(ReglagesPartie.peut_administrer(M.MONDIALE, "", "b", true), "carte mondiale : le développeur")

	print("Déblocage par paliers :")
	var p := ReglagesPartie.preset("normal")
	p.deblocage = "progression"
	_check(p.est_debloque("maison"), "maison ouverte dès le départ")
	_check(p.est_debloque("ecole"), "école toujours ouverte")
	var big := ""
	for id in BuildingCatalog.all_types():
		# (les stades, immenses, toucheraient la route du test)
		if BuildingCatalog.cost(id) > 40_000_000 and BuildingCatalog.get_type(id).get("cat", "") != "production" and not BuildingCatalog.get_type(id).has("stade"):
			big = id
			break
	_check(big != "" and not p.est_debloque(big), "grand bâtiment (%s) verrouillé au départ" % big)
	_check(p.raison_blocage(big).contains("10000 habitants"), "raison : " + p.raison_blocage(big))
	_check(p.note_population(150) == "Village", "150 habitants : palier Village")
	_check(p.note_population(120) == "" and p.record_habitants == 150, "la population qui baisse ne rebloque rien")
	p.note_population(20000)
	_check(p.est_debloque(big), "20 000 habitants : tout est ouvert")
	p.deblocage = "tout"
	p.record_habitants = 0
	_check(p.est_debloque(big), "« tout débloqué » : tout est ouvert")

	print("Nouvelle partie réglée sur le globe :")
	Creations.persist = false
	var pre := ReglagesPartie.preset("difficile")
	pre.deblocage = "progression"
	ReglagesPartie.prochaine = pre
	GameStart.mode = GameStart.Mode.BAC_A_SABLE
	GameStart.load_slot = ""
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var bs: BuildingSystem = scene.get_node("Batiments")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.set_origin(48.8584, 2.2945)
	await _frames(60)
	var reg := ReglagesPartie.actuel
	_check(ReglagesPartie.prochaine == null and reg != pre and reg.preset_name() == "Difficile", "réglages du globe copiés dans la partie")
	_check(reg.createur == SaveGame.player_id(), "le joueur est le créateur de la partie")
	_check(bs.money == 5_000_000, "argent de départ : %s" % BuildingSystem.format_money(bs.money))
	_check(bs.require_access, "accès à une voie obligatoire")
	var y := world.cell_height(Vector2i(0, 0))
	scene.transport.build_segment("route", Vector3(0, y, -80), Vector3(0, y, 80))
	await _frames(2)
	var chk := bs.check_place("maison", Vector2i(16, 0), 3)
	var base := BuildingCatalog.cost("maison") + roundi(float(chk.earth) * BuildingSystem.EARTH_COST)
	if not chk.ok:
		print("    raison : ", chk.reason)
	_check(chk.ok and int(chk.cost) == base * 2, "coûts ×2 : maison à %s" % BuildingSystem.format_money(int(chk.cost)))
	var lock := bs.check_place(big, Vector2i(60, 0), 3)
	_check(not lock.ok and String(lock.reason).begins_with("Débloqué"), "bâtiment verrouillé refusé : " + String(lock.reason))

	print("Panneau Admin :")
	_check(scene.hud._admin_button.visible, "bouton Admin visible en bac à sable")
	await _key(KEY_F10)
	await _frames(2)
	var panel: AdminPanel = scene._admin
	_check(panel != null and panel.is_inside_tree(), "F10 ouvre le panneau Admin")
	panel._cout.value = 1.0
	panel._illimite.button_pressed = true
	panel._impots.value = 2.0
	panel._deblocage.select(0)
	panel._deblocage.item_selected.emit(0)
	await _frames(1)
	_check(reg.cout_construction == 1.0 and bs.unlimited_money and reg.deblocage == "tout", "changements appliqués tout de suite")
	_check(not String(bs.check_place(big, Vector2i(60, 0), 3).reason).begins_with("Débloqué"), "plus de verrou")
	panel._illimite.button_pressed = false
	panel._caisse.value = 1_300_000
	for c in panel.find_children("*", "Button", true, false):
		if (c as Button).text == "Mettre la caisse à ce montant":
			(c as Button).pressed.emit()
	_check(bs.money == 1_300_000, "l'admin règle la caisse")
	var pop: Population = scene.population
	pop.households[999] = {"id": 999, "b": -1, "reg": "fr", "ep": 0.0, "car": 0, "m": []}
	_check(is_equal_approx(float(pop.city_budget().recettes["Taxe foncière"]), Population.TAXE_FONCIERE * 2.0), "taxe foncière ×2")
	pop.households.erase(999)
	panel._temps.select(4)
	panel._temps.item_selected.emit(4)
	_check(scene.ambiance.speed_index == 4, "vitesse du temps appliquée")
	await _key(KEY_ESCAPE)
	await _frames(2)
	_check(scene._admin == null, "Échap ferme le panneau")

	print("Droits selon le mode :")
	GameStart.mode = GameStart.Mode.MONDIALE
	scene._apply_settings(false)
	_check(scene.hud._admin_button.visible == ReglagesPartie.est_developpeur() and scene.build_panel._rules_button.visible == ReglagesPartie.est_developpeur(), "carte mondiale : bouton Admin pour le développeur seulement")
	GameStart.mode = GameStart.Mode.ENTRE_AMIS
	reg.createur = "quelqu-un-d-autre"
	scene._apply_settings(false)
	scene.toggle_admin()
	_check(scene._admin == null, "entre amis, invité : le panneau ne s'ouvre pas")
	reg.createur = SaveGame.player_id()
	GameStart.mode = GameStart.Mode.BAC_A_SABLE
	scene._apply_settings(false)

	print("Sauvegarde :")
	reg.salaires = 1.5
	reg.epuisement = false
	var slot := SaveGame.make_slot_id("test admin")
	_check(scene.save_game(slot, "test admin"), "sauvegarde (%s)" % scene.last_error)
	ReglagesPartie.actuel = ReglagesPartie.preset("normal")
	_check(scene.load_game(slot), "chargement (%s)" % scene.last_error)
	var back := ReglagesPartie.actuel
	_check(back.salaires == 1.5 and not back.epuisement and back.impots == 2.0 and back.createur == SaveGame.player_id(), "réglages retrouvés au chargement")
	_check(absi(bs.money - 1_300_000) < 100_000, "caisse retrouvée : %s" % BuildingSystem.format_money(bs.money))
	SaveGame.delete(slot)

	scene.queue_free()
	await _frames(2)
	print("TEST OK" if ok else "TEST ÉCHEC")
	quit(0 if ok else 1)
