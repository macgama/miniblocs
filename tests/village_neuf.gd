extends SceneTree
## Banc « villages neufs » : combien de temps faut-il à un village qui part de
## rien pour devenir vivant, à côté d'une première ville déjà lancée ?
##
## Partie lancée du globe en mode Normal (relief plat, sans réseau), comme
## tests/partie_test.gd : Valpartie est fondée (100 fondateurs), avec ses rues,
## ses réseaux, ses zones. Après --apres jours, deux nouveaux villages sont fondés
## à 2,6 km et reliés à Valpartie par la route :
##   - Neuville, en pilote automatique (comme les villages de tests/partie_pays.gd) ;
##   - Clairbois, aménagé comme le ferait un joueur : une rue, deux zones
##     résidentielles, une entreprise du bâtiment.
## Puis la partie tourne --jours jours (pas de 10 min, une tentative de croissance
## par pas). Relève tous les 5 jours les habitants, logements, chantiers et zones de
## chaque village. Les seuils (SEUILS) : Clairbois doit passer 15 habitants en
## 20 jours et 100 en 40 jours, Neuville 40 en 40 jours (avant l'équilibrage :
## 0 pour Clairbois et 36 pour Neuville en 40 jours).
##
## Usage : godot --headless --path . --script res://tests/village_neuf.gd [-- --apres 10 --jours 40 --rapport villages.csv]

const NEUFS := [["Neuville", 2600, 0, true], ["Clairbois", -2600, 0, false]]
## Seuils [20 jours, 40 jours] : le village aménagé et celui du pilote automatique
## (qui zone peu à peu et varie beaucoup d'un lancement à l'autre).
const SEUILS := {"Clairbois": [15, 100], "Neuville": [0, 40]}

var ok := true
var _logger: Journal


class Journal extends Logger:
	var mutex := Mutex.new()
	var liste: Array = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool,
			error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
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
	create_timer(3600.0).timeout.connect(func() -> void:
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
var pa: PiloteAuto
var pays: Pays
var _perdus := 0


func _offline(g: Node) -> void:
	var w: TerrainWorld = g.get_node("Terrain")
	w.tiles.offline_generator = _flat_tile
	w.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30


func _wait_game() -> Node:
	var t0 := Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Terre") and Time.get_ticks_msec() - t0 < 30000:
		await process_frame
	var g: Node = current_scene
	if g != null and g.name == "Terre":
		_offline(g)
	while EcranChargement.actif != null and Time.get_ticks_msec() - t0 < 60000:
		await process_frame
	return g


func _route(a: Vector2, b: Vector2, type := "route") -> bool:
	var y := world.cell_height(Vector2i(roundi(a.x), roundi(a.y)))
	var r: Dictionary = tr.build_segment(type, Vector3(a.x, y, a.y), Vector3(b.x, y, b.y))
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
		if bs.check_place(id, c, r).ok:
			var bid := bs.place(id, c, r)
			if bid >= 0:
				return bid
		x += pas
	print("    %s refusé près de x=%d" % [id, x0])
	return -1


func _chantiers_de(vid: int) -> int:
	var n := 0
	for bid in bs.buildings:
		if bs.en_chantier(bid) and cm.village_de(bid) == vid:
			n += 1
	return n


func _ligne(vid: int) -> Dictionary:
	cm.calculer_stats()
	var st: Dictionary = cm.stats.get(vid, {})
	return {"hab": int(st.get("hab", 0)), "foyers": int(st.get("foyers", 0)), "logements": int(st.get("logements", 0)),
		"chantiers": _chantiers_de(vid), "zonesR": pa.zones_de(vid, "R"), "caisse": pays.solde(vid)}


func _run() -> void:
	Creations.persist = false
	var apres := int(_arg("apres", "10"))
	var jours_max := int(_arg("jours", "40"))
	var rapport := _arg("rapport", "")
	ReglagesPartie.prochaine = ReglagesPartie.preset("normal")

	print("Globe :")
	change_scene_to_file("res://scenes/globe.tscn")
	await _frames(5)
	var globe: Node = current_scene
	globe.select_place(46.2, 6.6, "Valpartie (test)", true)
	ReglagesPartie.prochaine.tutoriel = false
	globe.start_game()
	game = await _wait_game()
	_check(game != null and game.name == "Terre", "la partie s'ouvre")
	world = game.world
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.view_radius_override = 900.0
	world.set_origin(46.25, 6.65)
	GameStart.place_name = "Valpartie (test)"
	# Relief de toute la bande où seront les trois villages et leurs routes.
	var tuiles := {}
	for x in range(-3200, 3201, 200):
		for z in range(-800, 801, 200):
			tuiles[Vector2i(int(world._pixel_x(x)) >> 8, int(world._pixel_y(z)) >> 8)] = true
	for t in tuiles:
		if not world.tiles.has_tile(t):
			world.tiles.request_tile(t)
	for i in 3000:
		await process_frame
		if i >= 120 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty() \
				and tuiles.keys().all(func(t: Vector2i) -> bool: return world.tiles.has_tile(t)):
			break
	_check(not is_nan(world.cell_height(Vector2i(2600, 0))) and not is_nan(world.cell_height(Vector2i(-2600, 0))), "relief chargé jusqu'aux villages neufs")
	bs = game.buildings
	tr = game.transport
	zs = game.zones
	amb = game.ambiance
	pop = game.population
	fd = game.fondateurs
	cm = game.communes
	pa = game.pilote
	pays = game.pays
	amb.set_speed(0)
	amb.unix_time = float(Time.get_unix_time_from_datetime_string("2026-04-06T07:00:00")) - amb.utc_offset() * 3600.0
	await _frames(2)

	print("Valpartie, la première ville :")
	if game.villages_panel._dialog.visible:
		game.villages_panel._dialog.hide()
	cm.nom_en_attente = "Valpartie"
	var mc := bs.place("maison_commune", Vector2i(0, -20), 0)
	await _frames(3)
	_check(mc >= 0 and fd.arrives, "Maison de commune posée, %d fondateurs" % fd.vivants().size())
	var rues_ok := true
	for z in [0, 70, 140, -90, -160]:
		rues_ok = _route(Vector2(-300, z), Vector2(300, z)) and rues_ok
	for x in [-300, 60, 300]:
		rues_ok = _route(Vector2(x, -160), Vector2(x, 140)) and rues_ok
	_check(rues_ok, "rues de Valpartie")
	for i in 2:
		_poser("eolienne", 120 + i * 50, -160, -1, 290)
	_poser("centrale_solaire", -290, -160, -1, -60)
	_poser("batteries", -200, -160, -1, -60)
	_poser("forage_eau", -40, -160, -1, -290)
	_poser("lagunage", 160, 140, 1, 290)
	_poser("ecole", -280, 0, 1, 280)
	for i in 3:
		_poser("entreprise_btp", 20 + i * 80, 140, -1, 290)
	for z in [0, 70, 140, -90]:
		for x in [-290, 10]:
			var k := "R"
			if z == 140 and x == 10:
				k = "I"
			elif z == -90:
				k = "C"
			zs.add_zone(k, Rect2i(x, z - 30, 280, 60))
	var vid0 := cm.principal()
	# Bâtiments démolis ou perdus (incendie, tempête…) : comptés pour le bilan.
	bs.removed.connect(func(bid: int) -> void:
		_perdus += 1)
	# Croissance pas à pas seulement (une tentative par pas de 10 min, pas d'essais en
	# plus selon le temps réel) et premiers tirages fixés.
	zs.growth = false
	zs.rng.seed = 20261114
	pop.rng.seed = 20261114

	var pas := 600.0
	var t0 := amb.unix_time
	var jour := 0
	var vids := {}
	var lignes := ["jour;village;habitants;foyers;logements;chantiers;zones_R;caisse"]
	var atteint := {}
	var a20 := {}
	var ms_tot := 0.0
	var n_frames := 0
	while jour < apres + jours_max:
		amb.unix_time += pas
		zs.grow_step()
		var t := Time.get_ticks_usec()
		await process_frame
		ms_tot += float(Time.get_ticks_usec() - t) / 1000.0
		n_frames += 1
		# Comme un maire prudent : un emprunt quand la caisse est presque vide.
		if pays.solde(vid0) < 500_000 and game.budget != null and not atteint.has("emprunt"):
			var caisse_prev := Pays.a_la_caisse(vid0)
			game.budget.emprunter(5_000_000, 20)
			Pays.retour(caisse_prev)
			atteint["emprunt"] = jour
		var j := int((amb.unix_time - t0) / 86400.0)
		if j == jour:
			continue
		jour = j
		if jour == apres:
			await _fonder_neufs(vids)
		for nom in vids:
			var l := _ligne(int(vids[nom]))
			var age := jour - apres
			lignes.append("%d;%s;%d;%d;%d;%d;%d;%d" % [age, nom, l.hab, l.foyers, l.logements, l.chantiers, l.zonesR, l.caisse])
			if age == 20:
				a20[nom] = int(l.hab)
			if not atteint.has(nom) and int(l.hab) >= 100:
				atteint[nom] = age
		if jour % 5 == 0:
			var l0 := _ligne(vid0)
			var txt := ["jour %3d : Valpartie %d hab (%d au campement, %d ouvriers libres)" % [jour, l0.hab, fd.au_campement(), fd.libres]]
			for nom in vids:
				var l := _ligne(int(vids[nom]))
				txt.append("%s %d hab, %d/%d logements, %d chantiers, %d zones R, %s" % [nom, l.hab, l.foyers, l.logements, l.chantiers, l.zonesR,
					BuildingSystem.format_money(int(l.caisse))])
			print("  " + " | ".join(txt))
			if OS.get_cmdline_user_args().has("--diag"):
				_diag(vids)
	print("  temps moyen par pas : %.1f ms ; %d bâtiments démolis ou perdus" % [ms_tot / maxf(n_frames, 1), _perdus])
	if rapport != "":
		var f := FileAccess.open(rapport, FileAccess.WRITE)
		if f != null:
			f.store_string("\n".join(lignes) + "\n")
	print("Bilan des villages neufs :")
	for v in NEUFS:
		var nom := String(v[0])
		if not vids.has(nom):
			_check(false, "%s fondé" % nom)
			continue
		var l := _ligne(int(vids[nom]))
		var mode := "pilote automatique" if bool(v[3]) else "aménagé par le joueur"
		print("    %-10s (%s) : %d habitants, 100 habitants %s" % [nom, mode, l.hab,
			("au jour %d" % int(atteint[nom])) if atteint.has(nom) else "pas atteints"])
		var seuils: Array = SEUILS[nom]
		if jours_max >= 20:
			_check(int(a20.get(nom, 0)) >= int(seuils[0]), "%s : %d habitants après 20 jours (au moins %d)" % [nom, int(a20.get(nom, 0)), int(seuils[0])])
		if jours_max >= 40:
			_check(int(l.hab) >= int(seuils[1]), "%s : %d habitants après %d jours (au moins %d)" % [nom, l.hab, jours_max, int(seuils[1])])
	_fin()


func _diag(vids: Dictionary) -> void:
	fd.repartir()
	print("    ouvriers %d (libres %d), %d chantiers en tout" % [fd.total_ouvriers, fd.libres, fd.liste_chantiers().size()])
	for ch in fd.liste_chantiers():
		var vid := int(ch.get("vid", -1))
		if not vids.values().has(vid):
			continue
		var eq := fd.equipe_de(String(ch.cle))
		print("      %s %s : av %.2f, équipe %d/%d%s%s" % [cm.villages[vid].nom, ch.nom, float(ch.av), int(eq[0]), int(eq[1]),
			" en pause" if bool(ch.pause) else "", " en attente" if bool(ch.get("attente", false)) else ""])


## Fonde Neuville (pilote auto) et Clairbois (aménagé « à la main »), reliés à Valpartie.
func _fonder_neufs(vids: Dictionary) -> void:
	print("Deux villages neufs (caisse de Valpartie %s) :" % BuildingSystem.format_money(pays.solde(cm.principal())))
	for v in NEUFS:
		var nom := String(v[0])
		var x := int(v[1])
		var sens := signi(x)
		# Départementale depuis le bout de la grande rue de Valpartie.
		_route(Vector2(300 * sens, 0), Vector2(x - 320 * sens, 0))
		cm.nom_en_attente = nom
		var mc := bs.place("maison_commune", Vector2i(x, -20), 0)
		if game.villages_panel._dialog.visible:
			game.villages_panel._dialog.hide()
		var vid := cm.village_du_batiment(mc)
		_check(mc >= 0 and vid >= 0, "%s fondé (caisse %s)" % [nom, BuildingSystem.format_money(pays.solde(vid)) if vid >= 0 else "?"])
		if vid < 0:
			continue
		vids[nom] = vid
		var caisse_prev := Pays.a_la_caisse(vid)
		if bool(v[3]):
			pa.activer(vid, true)
			# La départementale arrive au bout de sa première rue.
			_route(Vector2(x - 320 * sens, 0), Vector2(x - 150 * sens, 0))
		else:
			_route(Vector2(x - 320 * sens, 0), Vector2(x + 300 * sens, 0))
			zs.add_zone("R", Rect2i(x - 290, -30, 280, 60))
			zs.add_zone("R", Rect2i(x + 10, -30, 280, 60))
			_poser("entreprise_btp", x - 280, 0, -1, x + 280)
		Pays.retour(caisse_prev)
	await _frames(2)


func _fin() -> void:
	var erreurs: Array = _logger.liste.duplicate()
	if not erreurs.is_empty():
		print("Erreurs de script (%d) :" % erreurs.size())
		var vues := {}
		for e in erreurs:
			if not vues.has(e):
				vues[e] = true
				print("  ! ", e)
		ok = false
	print("VILLAGES NEUFS OK" if ok else "VILLAGES NEUFS ÉCHEC")
	quit(0 if ok else 1)
