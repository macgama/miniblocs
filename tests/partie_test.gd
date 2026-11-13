extends SceneTree
## Partie complète accélérée, comme un joueur en mode Normal (sans réseau) :
## globe -> fondation du village -> 100 fondateurs -> rues, réseaux, zones ->
## les chantiers avancent avec les ouvriers -> la ville grandit jusqu'à ~1 000 habitants
## -> sauvegarde et chargement. Relève chaque jour la population, la caisse, les
## chantiers, l'emploi, et compte les erreurs de script et le temps par image.
## Usage : godot --headless --path . --script res://tests/partie_test.gd [-- --jours 250 --cible 1000 --rapport partie.csv --messages --diag]

var ok := true
var erreurs: Array = []
var _logger: Journal


class Journal extends Logger:
	var mutex := Mutex.new()
	var liste: Array = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool,
			error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		# Les avertissements ne comptent pas ; les « ÉCHEC » du test non plus (déjà comptés).
		if error_type == ERROR_TYPE_WARNING or rationale.begins_with("ÉCHEC") or code.begins_with("ÉCHEC"):
			return
		mutex.lock()
		if liste.size() < 200:
			liste.append("%s (%s:%d %s)" % [rationale if rationale != "" else code, file.get_file(), line, function])
		mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass


func _initialize() -> void:
	_logger = Journal.new()
	OS.add_logger(_logger)
	_run.call_deferred()
	create_timer(3000.0).timeout.connect(func() -> void:
		push_error("ÉCHEC : délai dépassé")
		_fin())


func _check(cond: bool, what: String) -> void:
	if not cond:
		push_error("ÉCHEC : " + what)
		ok = false
	else:
		print("  ok  ", what)


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(120.0)
	return a


func _arg(nom: String, defaut: String) -> String:
	var a := OS.get_cmdline_user_args()
	var i := a.find("--" + nom)
	return a[i + 1] if i >= 0 and i + 1 < a.size() else defaut


func _frames(n: int) -> void:
	for i in n:
		await process_frame


var game: Node
var world: TerrainWorld
var bs: BuildingSystem
var tr: TransportSystem
var zs: ZoneSystem
var amb: DayNight
var pop: Population
var fd: Fondateurs
var cm: Communes
var res: Reseaux
var _t0_msg := 0.0


func _route(a: Vector2, b: Vector2) -> bool:
	var y := world.cell_height(Vector2i(roundi(a.x), roundi(a.y)))
	var r: Dictionary = tr.build_segment("route", Vector3(a.x, y, a.y), Vector3(b.x, y, b.y))
	if not r.get("ok", false):
		print("    route refusée ", a, " -> ", b, " : ", r.get("reason", "?"))
	return bool(r.get("ok", false))


## Pose un bâtiment le long d'une rue est-ouest (z = rue), côté nord (-1) ou sud (1).
func _poser(id: String, x0: int, rue_z: int, cote: int, x1 := 0) -> int:
	var t := BuildingCatalog.get_type(id)
	var x := x0
	var pas := 6 if x1 > x0 else -6
	if x1 == 0:
		x1 = x0 + 240
		pas = 6
	while (pas > 0 and x <= x1) or (pas < 0 and x >= x1):
		var c := Vector2i(x, rue_z + cote * (6 + int(t.d) / 2 + 1))
		var r := bs.best_rotation(id, c)
		var chk := bs.check_place(id, c, r)
		if chk.ok:
			var bid := bs.place(id, c, r)
			if bid >= 0:
				return bid
		x += pas
	var c0 := Vector2i(x0, rue_z + cote * (6 + int(t.d) / 2 + 1))
	print("    %s refusé : %s" % [id, bs.check_place(id, c0, bs.best_rotation(id, c0)).get("reason", "?")])
	return -1


func _habitants() -> int:
	cm.calculer_stats()
	var v := cm.principal()
	return int(cm.stats.get(v, {}).get("hab", 0)) if v >= 0 else 0


## Logements habités qui manquent de courant ou d'eau.
func _sans(r: String) -> int:
	var n := 0
	for bid in pop.by_home:
		if (pop.by_home[bid] as Array).is_empty() or Fondateurs.est_campement(bid):
			continue
		if res.taux(bid, r) < 0.5:
			n += 1
	return n


func _en_chantier() -> int:
	var n := 0
	for bid in bs.buildings:
		if bs.en_chantier(bid):
			n += 1
	return n


func _diag() -> void:
	var n := 0
	fd.repartir()
	print("    ouvriers=%d libres=%d besoins=%d chantiers_listes=%d" % [fd.total_ouvriers, fd.libres, fd.besoins.size(), fd.liste_chantiers().size()])
	for bid in bs.buildings:
		if not bs.en_chantier(bid):
			continue
		var b: Dictionary = bs.buildings[bid]
		print("    #%d %s av=%.3f hr=%.0f f=%.2f attente=%s sans=%s du=%d" % [bid, b.t, float(b.get("av", -1)), float(b.get("hr", 0)),
			Fondateurs.facteur_de(Fondateurs.cle_batiment(bid)), b.get("attente", false), b.get("sans_ouvriers", false), int(b.get("du", 0))])
		n += 1
		if n >= 12:
			break


func _run() -> void:
	Creations.persist = false
	var jours_max := int(_arg("jours", "250"))
	var cible := int(_arg("cible", "1000"))
	var rapport := _arg("rapport", "")
	ReglagesPartie.prochaine = ReglagesPartie.preset("normal")

	print("Globe :")
	change_scene_to_file("res://scenes/globe.tscn")
	await _frames(5)
	var globe: Node = current_scene
	globe.select_place(46.2, 6.6, "Valpartie (test)", true)
	globe.start_game()
	await _frames(3)
	game = current_scene
	_check(game != null and game.name == "Terre", "la partie s'ouvre")
	world = game.world
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.view_radius_override = 900.0
	world.set_origin(46.25, 6.65)
	GameStart.place_name = "Valpartie (test)"
	for i in 3000:
		await process_frame
		if i >= 120 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	bs = game.buildings
	tr = game.transport
	zs = game.zones
	amb = game.ambiance
	pop = game.population
	fd = game.fondateurs
	cm = game.communes
	res = game.reseaux
	_check(ReglagesPartie.actuel.preset_name() == "Normal" and not bs.unlimited_money, "mode Normal, argent compté")
	var argent0 := bs.money
	print("  caisse de départ : ", BuildingSystem.format_money(argent0))
	# On joue en accéléré : l'horloge est avancée à la main (pas de vitesse réelle).
	amb.set_speed(0)
	amb.unix_time = float(Time.get_unix_time_from_datetime_string("2026-04-06T07:00:00")) - amb.utc_offset() * 3600.0
	await _frames(2)

	print("Fondation :")
	if game.villages_panel._dialog.visible:
		game.villages_panel._dialog.hide()
	cm.nom_en_attente = "Valpartie"
	var mc := bs.place("maison_commune", Vector2i(0, -20), 0)
	await _frames(3)
	_check(mc >= 0 and cm.villages.size() == 1, "Maison de commune posée, village fondé")
	_check(fd.arrives and fd.vivants().size() == ReglagesPartie.actuel.fondateurs, "%d fondateurs au campement" % fd.vivants().size())

	print("Rues :")
	var rues_ok := true
	# Grande rue est-ouest et rues parallèles tous les 70 m, reliées par trois rues nord-sud.
	var rues_z := [0, 70, 140, -90, -160]
	for z in rues_z:
		rues_ok = _route(Vector2(-300, z), Vector2(300, z)) and rues_ok
	for x in [-300, 60, 300]:
		rues_ok = _route(Vector2(x, -160), Vector2(x, 140)) and rues_ok
	_check(rues_ok, "%d tronçons de rue posés" % tr.network.edges.size())
	print("  caisse : ", BuildingSystem.format_money(bs.money))

	print("Réseaux et services :")
	var eol := []
	for i in 2:
		eol.append(_poser("eolienne", 120 + i * 50, -160, -1, 290))
	var sol := _poser("centrale_solaire", -290, -160, -1, -60)
	var batt := _poser("batteries", -200, -160, -1, -60)
	_check(batt >= 0, "batteries de stockage")
	var forage := _poser("forage_eau", -40, -160, -1, -290)
	var rejet := _poser("lagunage", 160, 140, 1, 290)
	var ecole := _poser("ecole", -280, 0, 1, 280)
	var btp := []
	for i in 3:
		btp.append(_poser("entreprise_btp", 20 + i * 80, 140, -1, 290))
	_check(not btp.has(-1), "trois entreprises du bâtiment")
	_check(not eol.has(-1) and sol >= 0, "éoliennes et parc solaire")
	_check(forage >= 0 and rejet >= 0, "forage et lagunage")
	_check(ecole >= 0, "école")
	print("  caisse : ", BuildingSystem.format_money(bs.money))

	print("Zones :")
	var zn := 0
	for z in [0, 70, 140, -90]:
		for x in [-290, 10]:
			var k := "R"
			if z == 140 and x == 10:
				k = "I"
			elif z == -90:
				k = "C"
			var id := zs.add_zone(k, Rect2i(x, z - 30, 280, 60))
			if id >= 0:
				zn += 1
	_check(zn >= 6, "%d zones peintes" % zn)
	print("  caisse : ", BuildingSystem.format_money(bs.money))

	if OS.get_cmdline_user_args().has("--messages"):
		for n in game.find_children("*", "", true, false):
			if n.has_signal("message") and n != game.hud:
				var nom := String(n.name)
				n.connect("message", func(txt: String) -> void:
					print("    [j%d %s] %s" % [int((amb.unix_time - _t0_msg) / 86400.0), nom, txt]))
	_t0_msg = amb.unix_time
	print("La ville grandit (pas de 10 min, une tentative de croissance par pas) :")
	var lignes := ["jour;habitants;campement;foyers;batiments;chantiers;caisse;logements;emplois;chomeurs;satisfaction;sans_courant;sans_eau;ms_image"]
	var pas := 600.0
	var t0 := amb.unix_time
	var jour := 0
	var atteint := -1
	var ms_tot := 0.0
	var ms_max := 0.0
	var n_frames := 0
	var hab := 0
	var argent_min := bs.money
	var emprunts := 0
	while jour < jours_max:
		amb.unix_time += pas
		zs.grow_step()
		var t := Time.get_ticks_usec()
		await process_frame
		var ms := float(Time.get_ticks_usec() - t) / 1000.0
		ms_tot += ms
		ms_max = maxf(ms_max, ms)
		n_frames += 1
		argent_min = mini(argent_min, bs.money)
		# Comme un maire prudent : un emprunt quand la caisse est presque vide.
		if bs.money < 500_000 and emprunts < 2 and game.budget != null:
			var e: Dictionary = game.budget.emprunter(5_000_000, 20)
			if not e.is_empty():
				emprunts += 1
				print("    jour %d : emprunt de 5 M€ sur 20 ans" % jour)
		var j := int((amb.unix_time - t0) / 86400.0)
		if j != jour:
			jour = j
			hab = _habitants()
			var st := pop.stats()
			var ligne := "%d;%d;%d;%d;%d;%d;%d;%d;%d;%d;%d;%d;%d;%.1f" % [jour, hab, fd.au_campement(), pop.households.size(), bs.buildings.size(),
				_en_chantier(), bs.money, int(st.logements), int(st.emplois), int(st.chomeur), int(st.satisfaction), _sans("elec"), _sans("eau"), ms_tot / maxf(n_frames, 1)]
			lignes.append(ligne)
			if jour % 5 == 0:
				print("  ", ligne)
				if OS.get_cmdline_user_args().has("--diag"):
					_diag()
			if atteint < 0 and hab >= cible:
				atteint = jour
				break
	print("  temps moyen par pas : %.1f ms, pire : %.0f ms" % [ms_tot / maxf(n_frames, 1), ms_max])
	_check(atteint >= 0, "%d habitants atteints (%s)" % [cible, ("jour %d" % atteint) if atteint >= 0 else "%d au jour %d" % [hab, jour]])
	_check(argent_min > -5_000_000, "la caisse ne s'effondre pas (plus bas : %s)" % BuildingSystem.format_money(argent_min))
	if rapport != "":
		var f := FileAccess.open(rapport, FileAccess.WRITE)
		if f != null:
			f.store_string("\n".join(lignes) + "\n")

	print("Sauvegarde et chargement :")
	var n_bat := bs.buildings.size()
	var n_pers := pop.persons.size()
	var pids := pop.persons.keys()
	var n_voies := tr.network.edges.size()
	_check(game.save_game(), "partie sauvegardée")
	var slot := GameStart.slot_id
	game.hud.globe_requested.emit()
	await _frames(3)
	globe = current_scene
	globe.load_saved_game(slot)
	await _frames(2)
	game = current_scene
	game.world.tiles.offline_generator = _flat_tile
	game.world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	await _frames(10)
	_check(game.buildings.buildings.size() == n_bat, "bâtiments revenus (%d / %d)" % [game.buildings.buildings.size(), n_bat])
	# Le temps repart à la vitesse de la partie : quelques foyers peuvent déjà emménager.
	var revenus := 0
	for pid in pids:
		if game.population.persons.has(pid):
			revenus += 1
	_check(revenus >= n_pers - 3, "habitants revenus (%d / %d, %d en tout)" % [revenus, n_pers, game.population.persons.size()])
	_check(game.transport.network.edges.size() == n_voies, "rues revenues")
	SaveGame.delete(slot)
	_fin()


func _fin() -> void:
	erreurs = _logger.liste.duplicate()
	if not erreurs.is_empty():
		print("Erreurs de script pendant la partie (%d) :" % erreurs.size())
		var vues := {}
		for e in erreurs:
			if not vues.has(e):
				vues[e] = true
				print("  ! ", e)
		ok = false
	print("PARTIE TEST OK" if ok else "PARTIE TEST ÉCHEC")
	quit(0 if ok else 1)
