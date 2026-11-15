extends SceneTree
## Démo guidée jouée de bout en bout, comme un joueur qui découvre le jeu :
## menu principal → bouton « Démo guidée » → écran de chargement → partie à
## Échallens (réglages Normal, 100 fondateurs, chantiers réels) → chaque étape
## faite avec le bouton de la carte puis le geste demandé (aucun « Passer ») →
## le temps tourne à la vitesse du jeu (accéléré par Engine.time_scale, le
## chrono de la démo compte donc les minutes du joueur) → bilan → « Menu
## principal » (sauvegarde) → « Continuer » reprend la partie.
##
## Relève : minutes du joueur et jours de jeu par étape, caisse, habitants,
## erreurs de script. Échoue si une étape bloque, si la démo dépasse 45 min, si
## la caisse s'effondre ou s'il y a des erreurs.
##
## Usage : godot --headless --path . --script res://tests/demo_parcours_test.gd
##   [-- --echelle 20 --proxy 127.0.0.1:PORT --ca fichier.crt --rapport parcours.csv]
## Sans --proxy le relief est plat (hors ligne) ; avec, c'est le vrai relief d'Échallens.

var ok := true
var _logger: Journal
var echelle := 20.0
var proxy_hote := ""
var proxy_port := 0
var ca: X509Certificate
var _proxies := {}
var soigneux := false


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
	create_timer(3600.0, true, false, true).timeout.connect(func() -> void:
		push_error("ÉCHEC : délai dépassé")
		_fin())


func _check(cond: bool, what: String) -> void:
	if not cond:
		push_error("ÉCHEC : " + what)
		ok = false
	else:
		print("  ok  ", what)


func _args() -> void:
	var a := OS.get_cmdline_user_args()
	for i in a.size():
		var nxt: String = a[i + 1] if i + 1 < a.size() else ""
		match a[i]:
			"--soigneux":
				soigneux = true
			"--echelle":
				echelle = float(nxt)
			"--proxy":
				proxy_hote = nxt.get_slice(":", 0)
				proxy_port = int(nxt.get_slice(":", 1))
			"--ca":
				ca = X509Certificate.new()
				if ca.load(nxt) != OK:
					ca = null


func _arg(nom: String, defaut: String) -> String:
	var a := OS.get_cmdline_user_args()
	var i := a.find("--" + nom)
	return a[i + 1] if i >= 0 and i + 1 < a.size() else defaut


func _brancher_proxy(n: Node) -> void:
	if proxy_hote == "" or n == null:
		return
	for c in n.find_children("*", "HTTPRequest", true, false):
		if _proxies.has(c.get_instance_id()):
			continue
		_proxies[c.get_instance_id()] = true
		var r := c as HTTPRequest
		r.set_https_proxy(proxy_hote, proxy_port)
		r.set_http_proxy(proxy_hote, proxy_port)
		if ca != null:
			r.set_tls_options(TLSOptions.client(ca))


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(620.0)
	return a


func _frames(n: int) -> void:
	for i in n:
		await process_frame


var game: Node
var world: TerrainWorld
var bs: BuildingSystem
var tr: TransportSystem
var zs: ZoneSystem
var amb: DayNight
var t: Tutoriel
var lignes_rapport := ["etape;minutes;jour;habitants;loges;campement;batiments;chantiers;caisse;satisfaction"]


## Attend la scène Terre derrière l'écran de chargement.
func _attendre_partie() -> Node:
	var t0 := Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Terre") and Time.get_ticks_msec() - t0 < 60000:
		await process_frame
	var g: Node = current_scene
	if g != null and g.name == "Terre":
		if proxy_hote == "":
			var w: TerrainWorld = g.get_node("Terrain")
			w.tiles.offline_generator = _flat_tile
			w.land.offline_generator = func(_lat: float, _lon: float) -> int: return 40
		_brancher_proxy(g)
	while EcranChargement.actif != null and Time.get_ticks_msec() - t0 < 120000:
		_brancher_proxy(current_scene)
		await process_frame
	return g


func _attendre_relief(max_ms: int) -> void:
	var t0 := Time.get_ticks_msec()
	var stable := 0
	while Time.get_ticks_msec() - t0 < max_ms:
		await process_frame
		_brancher_proxy(game)
		var busy := world.tiles.pending_count() + world.land.pending_count()
		stable = stable + 1 if busy == 0 and world.missing_chunk_count() == 0 and world._jobs.is_empty() and world.chunks.size() > 0 else 0
		if stable > 30:
			break
	print("  relief prêt : %d blocs (%d ms)" % [world.chunks.size(), Time.get_ticks_msec() - t0])


func _h(x: float, z: float) -> float:
	var h := world.cell_height(Vector2i(roundi(x), roundi(z)))
	return 0.0 if is_nan(h) or is_inf(h) else h


func _p(x: float, z: float) -> Vector3:
	return Vector3(x, _h(x, z), z)


func _route(a: Vector2, b: Vector2) -> bool:
	var r: Dictionary = tr.build_segment("route", _p(a.x, a.y), _p(b.x, b.y))
	if not r.get("ok", false):
		print("    route refusée ", a, " → ", b, " : ", r.get("reason", "?"))
	return bool(r.get("ok", false))


## Pose un bâtiment le long d'une rue est-ouest (z = rue), côté nord (-1) ou sud (1),
## en cherchant une place libre entre x0 et x1.
func _poser(id: String, x0: int, x1: int, rue_z: int, cote: int) -> int:
	var ty := BuildingCatalog.get_type(id)
	if ty.is_empty():
		ty = ReseauxTypes.TYPES.get(id, {})
	var pas := 4 if x1 > x0 else -4
	var x := x0
	var raison := ""
	while (pas > 0 and x <= x1) or (pas < 0 and x >= x1):
		var c := Vector2i(x, rue_z + cote * (6 + int(ty.get("d", 10)) / 2 + 1))
		var r := bs.best_rotation(id, c)
		var chk := bs.check_place(id, c, r)
		if chk.ok:
			var bid := bs.place(id, c, r)
			if bid >= 0:
				return bid
		elif raison == "":
			raison = String(chk.get("reason", "?"))
		x += pas
	print("    %s refusé : %s" % [id, raison])
	return -1


func _habitants() -> int:
	return t.habitants_ville()


func _en_chantier() -> int:
	var n := 0
	for bid in bs.buildings:
		if bs.en_chantier(bid):
			n += 1
	return n


func _jour() -> int:
	return int(game.objectifs.jour()) - maxi(t.jour0, 0)


func _ligne(etape: String) -> void:
	var l := "%s;%.1f;%d;%d;%d;%d;%d;%d;%d;%d" % [etape, t.temps_demo / 60.0, _jour(), _habitants(), t.loges(),
		game.fondateurs.au_campement(), bs.buildings.size(), _en_chantier(), bs.money, t.satisfaction_ville()]
	lignes_rapport.append(l)
	print("    [%s] %.1f min · jour %d · %d hab. · %d logés · %d au campement · %d bât. (%d chantiers) · %s · satisfaction %d" % [etape,
		t.temps_demo / 60.0, _jour(), _habitants(), t.loges(), game.fondateurs.au_campement(), bs.buildings.size(),
		_en_chantier(), BuildingSystem.format_money(bs.money), t.satisfaction_ville()])


## Le jeu tourne (à sa vitesse) jusqu'à ce que l'étape en cours change, ou max_min minutes du joueur.
func _jouer_jusqu_a_fin_etape(id: String, max_min: float, pendant := Callable()) -> bool:
	var m0 := t.temps_demo
	var dernier := -1
	while t.actif and t.id_courant() == id and t.temps_demo - m0 < max_min * 60.0:
		await process_frame
		if soigneux:
			var mf = Avis.instance.manifs
			for mid in mf.liste.keys():
				if String(mf.liste[mid].reponse) == "" and String(mf.liste[mid].etat) != "finie":
					print("    manifestation (%s) : %s" % [mf.liste[mid].theme, mf.repondre(mid, "negocier")])
		if pendant.is_valid():
			pendant.call()
		var m := int(t.temps_demo / 60.0)
		if m != dernier and m % 2 == 0:
			dernier = m
			_ligne(id + " (en cours)")
	return t.id_courant() != id


func _fermer_panneaux() -> void:
	for p in ["build_panel", "fondateurs_panel", "budget_panel", "objectifs_panel", "evenements_panel", "transit_panel"]:
		var n = game.get(p)
		if n != null and n.has_method("set_open"):
			n.set_open(false)
	if game.hud.has_method("choose_tool"):
		game.hud.choose_tool(0)


## Étape faite à la main puis validée par le tutoriel (deux vérifications par seconde).
func _etape(id: String, geste: Callable, max_min := 3.0) -> void:
	_check(t.id_courant() == id, "étape « %s » (en cours : « %s »)" % [id, t.id_courant()])
	if t.id_courant() != id:
		for bid in bs.buildings:
			var ty := String(bs.buildings[bid].t)
			print("      bâtiment #%d %s (%s)%s" % [bid, ty, BuildingCatalog.get_type(ty).get("cat", ""), " zone" if bs.buildings[bid].has("zone") else ""])
		return
	t.agir()
	await _frames(3)
	await geste.call()
	var fini := await _jouer_jusqu_a_fin_etape(id, max_min)
	_check(fini, "« %s » validée" % id)
	_fermer_panneaux()
	_ligne(id)


func _run() -> void:
	_args()
	Creations.persist = false
	Engine.max_fps = 60

	print("Menu principal :")
	change_scene_to_file(MenuPrincipal.SCENE)
	await _frames(5)
	var menu: Node = current_scene
	_check(menu != null and menu._boutons.has("demo"), "bouton « Démo guidée »")
	(menu._boutons.demo as Button).pressed.emit()
	game = await _attendre_partie()
	_check(game != null and game.name == "Terre", "la partie de la démo s'ouvre")
	if game == null:
		_fin()
		return
	world = game.world
	bs = game.buildings
	tr = game.transport
	zs = game.zones
	amb = game.ambiance
	t = game.tutoriel
	await _attendre_relief(180_000 if proxy_hote != "" else 30_000)
	_check(ReglagesPartie.actuel.preset_name() == "Normal" and not bs.unlimited_money, "réglages Normal (%s)" % BuildingSystem.format_money(bs.money))
	_check(t.actif and t.est_demo(), "la démo guidée commence (%s)" % t.id_courant())
	_check(GameStart.place_name.contains("Échallens"), "lieu : %s" % GameStart.place_name)
	print("  vitesse du temps au départ : %s" % DayNight.SPEED_NAMES[amb.speed_index])
	print("  heure : %s" % Time.get_datetime_string_from_unix_time(int(amb.unix_time + amb.utc_offset() * 3600.0)))
	game.urgences.random_calls = false
	# Incendies, tempêtes et crues tirés au hasard : seulement avec --aleas (le test reste reproductible).
	if not OS.get_cmdline_user_args().has("--aleas"):
		game.evenements.forcer_auto = 0
		game.evenements.forcer_catastrophes = 0
	for n in game.find_children("*", "", true, false):
		if n.has_signal("message") and n != game.hud:
			var nom := String(n.name)
			n.connect("message", func(txt: String) -> void:
				print("      [jour %d · %s] %s" % [_jour(), nom, txt]))
	Engine.time_scale = echelle

	print("Parcours (×%.0f) :" % echelle)
	await _etape("camera", func() -> void: game.rig.position.x += 60.0)

	await _etape("fonder", func() -> void:
		var vp = game.villages_panel
		_check(vp._dialog.visible, "fenêtre du nom du village")
		vp._dialog_edit.text = "Valdémo"
		vp._valider_nom()
		vp._dialog.hide()
		await _frames(2)
		game.rig.position = Vector3(0, game.rig.position.y, 0)
		var m0 := bs.money
		var mc := _poser("maison_commune", -60, 60, 20, -1)
		_check(mc >= 0, "Maison de commune posée")
		await _frames(2)
		print("    caisse : %s → %s" % [BuildingSystem.format_money(m0), BuildingSystem.format_money(bs.money)]))

	if t.id_courant() == "fondateurs":
		await _etape("fondateurs", func() -> void:
			_check(game.fondateurs_panel.is_open(), "panneau des fondateurs ouvert")
			print("    fondateurs : %d au campement" % game.fondateurs.au_campement()))
	else:
		_check(false, "étape « fondateurs » attendue (%s)" % t.id_courant())

	var fd = game.fondateurs
	var n_camp: int = fd.au_campement()
	if not OS.get_cmdline_user_args().has("--sans-feu"):
		game.evenements.set_degats(fd.camp, 1.0, "incendie")
	await _frames(3)
	_check(fd.au_campement() >= n_camp - 2 and bs.buildings.has(fd.camp), "un incendie du campement ne chasse pas les fondateurs (%d / %d)" % [fd.au_campement(), n_camp])

	await _etape("route", func() -> void:
		# Une grande rue devant la mairie, puis un petit quartier.
		_route(Vector2(-200, 30), Vector2(200, 30))
		_route(Vector2(-200, 100), Vector2(200, 100))
		for x in [-200, 0, 200]:
			_route(Vector2(x, 30), Vector2(x, 100)))

	await _etape("zone_r", func() -> void:
		_check(game.build_panel.is_open(), "Construire → Zonage ouvert")
		_check(zs.add_zone("R", Rect2i(-195, 37, 190, 56)) >= 0, "zone résidentielle"))

	await _etape("reseaux", func() -> void:
		_check(game.build_panel.is_open() and game.build_panel.category() == "reseaux", "Construire → Réseaux ouvert")
		var m0 := bs.money
		_check(_poser("poste_national", -190, 190, 30, -1) >= 0, "raccordement électrique")
		_check(_poser("forage_eau", 190, -190, 30, -1) >= 0, "forage")
		t.verifier()
		_check(t.id_courant() == "reseaux", "sans égouts, l'étape attend (%s)" % t.progres())
		# Le lagunage (kit) au bout d'une rue de service, au nord.
		_route(Vector2(-130, 30), Vector2(-130, -120))
		_route(Vector2(-200, -120), Vector2(200, -120))
		_check(_poser("lagunage", -190, 190, -120, -1) >= 0, "lagunage")

		print("    réseaux payés : %s (bons du kit)" % BuildingSystem.format_money(m0 - bs.money)))

	if soigneux:
		# Un maire prévoyant : déchets et dépôt de marchandises (import).
		print("    soigneux : collecte %d, décharge %d" % [_poser("depot_collecte", 190, -190, -120, -1),
			_poser("decharge", 190, -190, -120, -1)])
		var dp: Dictionary = tr.stations.place("depot", _p(100, -120 - 5))
		print("    dépôt de marchandises : %s" % dp.get("reason", "ok"))

	await _etape("temps", func() -> void:
		print("    vitesse : %s" % DayNight.SPEED_NAMES[amb.speed_index]), 20.0)

	await _etape("emplois", func() -> void:
		_check(zs.add_zone("C", Rect2i(5, 37, 190, 56)) >= 0, "zone commerciale"))

	await _etape("ecole", func() -> void:
		_check(game.build_panel.category() == "services", "Construire → Services ouvert")
		_check(_poser("ecole", 196, -196, 100, 1) >= 0, "école"))

	await _etape("budget", func() -> void: _check(game.budget_panel.is_open(), "budget ouvert"))
	await _etape("objectifs", func() -> void: _check(game.objectifs_panel.is_open(), "objectifs ouverts"))

	await _etape("vue_sol", func() -> void:
		var vs: VueSol = game.get_node("VueSol")
		_check(vs.vue != VueSol.Vue.DESSUS, "en bas, dans la rue"))
	var vs: VueSol = game.get_node("VueSol")
	vs.set_vue(VueSol.Vue.DESSUS)
	await _frames(3)

	await _etape("loisirs", func() -> void:
		_check(game.build_panel.category() == "espaces", "Construire → Espaces publics ouvert")
		_check(_poser("square", -196, 196, 100, 1) >= 0, "square"))

	await _etape("fete", func() -> void:
		_check(game.evenements_panel.is_open(), "Infos → Organiser ouvert")
		_check(game.evenements.fetes.organiser("marche", _p(0, 65)) > 0, "marché organisé"))

	await _etape("ligne", func() -> void:
		_check(game.transit_panel.is_open(), "panneau des lignes ouvert")
		var a: Dictionary = tr.stations.place("arret_bus", _p(-150, 24))
		var b: Dictionary = tr.stations.place("arret_bus", _p(150, 24))
		print("    arrêts : %s / %s" % [a.get("reason", "ok"), b.get("reason", "ok")])
		var ln: Dictionary = tr.stations.create_line([a.get("id", -1), b.get("id", -1)], "", 2) if a.get("ok", false) and b.get("ok", false) else {"ok": false}
		_check(ln.get("ok", false), "ligne de bus"))

	# Cent habitants : comme un joueur, on agrandit le quartier dès qu'il est plein
	# (plus aucun chantier en cours).
	_check(t.id_courant() == "village", "étape « village » (%s)" % t.id_courant())
	t.agir()
	await _frames(3)
	_check(game.objectifs_panel.is_open(), "ce qui manque (Maj+J) ouvert")
	_fermer_panneaux()
	var agrandi := 0
	while t.id_courant() == "village" and t.temps_demo < 45.0 * 60.0:
		await _jouer_jusqu_a_fin_etape("village", 1.5)
		if t.id_courant() == "village" and _en_chantier() == 0 and agrandi < 3:
			var z: int = 170 + agrandi * 70
			print("    quartier plein (%s) : nouvelle rue z = %d" % [t.progres(), z])
			_route(Vector2(-200, z), Vector2(200, z))
			for x in [-150, 50, 150]:
				_route(Vector2(x, z - 70), Vector2(x, z))
				if agrandi == 2:
					_route(Vector2(x, z), Vector2(x, z + 50))
			# Zones de 300 m au plus : deux moitiés.
			for x0 in [-195, 5]:
				zs.add_zone("R", Rect2i(x0, z - 63, 190, 56))
			# « Logements, emplois, services : tout compte » : des emplois de l'autre côté de la rue.
			zs.add_zone("I" if agrandi % 2 == 0 else "C", Rect2i(-195, z + 7, 190, 40))
			agrandi += 1
	_check(t.id_courant() == "fin_demo", "cent habitants (%s, %.0f min)" % [t.progres(), t.temps_demo / 60.0])
	_ligne("village")
	_avis()

	print("Bilan :")
	var minutes := t.temps_demo / 60.0
	_check(minutes <= 45.0, "la démo tient en %.0f minutes (annoncée : %d)" % [minutes, Demo.DUREE_MIN])
	Engine.time_scale = 1.0
	t.agir()
	await _frames(3)
	_check(game.bilan_demo != null, "bilan affiché")
	if game.bilan_demo != null:
		for l in game.bilan_demo.lignes():
			print("    %s : %s" % [l[0], l[1]])
		var menu_b: Button = game.bilan_demo.find_child("Menu", true, false)
		_check(menu_b != null, "bouton « Menu principal »")
		var n_bat := bs.buildings.size()
		var hab := _habitants()
		menu_b.pressed.emit()
		var t0 := Time.get_ticks_msec()
		while (current_scene == null or current_scene.name == "Terre" or EcranChargement.actif != null) and Time.get_ticks_msec() - t0 < 60000:
			await process_frame
		await _frames(5)
		menu = current_scene
		_check(menu != null and menu.get("_boutons") != null and menu._boutons.has("continuer"), "retour au menu, « Continuer » proposé")
		if menu != null and menu._boutons.has("continuer"):
			(menu._boutons.continuer as Button).pressed.emit()
			game = await _attendre_partie()
			await _frames(20)
			_check(game != null and game.name == "Terre", "« Continuer » rouvre la partie")
			if game != null:
				_check(game.buildings.buildings.size() == n_bat, "bâtiments revenus (%d / %d)" % [game.buildings.buildings.size(), n_bat])
				_check(game.tutoriel.habitants_ville() >= hab - 5, "habitants revenus (%d / %d)" % [game.tutoriel.habitants_ville(), hab])
				_check(not game.tutoriel.actif and game.tutoriel.demo_finie, "la démo reste finie")
				if GameStart.slot_id != "":
					SaveGame.delete(GameStart.slot_id)
	var rapport := _arg("rapport", "")
	if rapport != "":
		var f := FileAccess.open(rapport, FileAccess.WRITE)
		if f != null:
			f.store_string("\n".join(lignes_rapport) + "\n")
	_fin()


## Ce que disent les habitants (sondage de l'Avis) : notes et motifs par thème.
func _avis() -> void:
	var av := Avis.instance
	if av == null:
		return
	av.examiner(t.ville())
	var sd: Dictionary = av.sondage(true)
	print("  Avis : %d %% (%d mécontents, %d contents sur %d)" % [int(sd.valeur), int(sd.mecontents), int(sd.contents), int(sd.habitants)])
	for th in sd.themes:
		var e: Dictionary = sd.themes[th]
		print("    %s : %s (%.1f) %s" % [th, e.note, float(e.delta), e.raisons])
	var pids: Array = game.population.persons.keys()
	for i in [0, pids.size() / 2, pids.size() - 1]:
		if i < 0 or i >= pids.size():
			continue
		var pe: Dictionary = game.population.persons[pids[i]]
		var sa: Dictionary = game.population.satisfaction(pe)
		print("    habitant %s (logement #%d) : %d · %s" % [pids[i], game.population.home_of(pe), int(sa.value), sa.why])
	var types := {}
	for bid in bs.buildings:
		var ty := String(bs.buildings[bid].t)
		types[ty] = int(types.get(ty, 0)) + 1
	print("    bâtiments : %s" % types)
	var res = game.reseaux
	for r in ["elec", "eau", "egout"]:
		var manque := 0
		var n := 0
		for bid in game.population.by_home:
			if (game.population.by_home[bid] as Array).is_empty() or Fondateurs.est_campement(bid):
				continue
			n += 1
			if res.taux(bid, r) < 0.5:
				manque += 1
		var rb = res.get(r)
		var bi: Dictionary = rb.bilan()
		print("      bilan %s : %s · sources %s" % [r, bi, rb.sources.values()])
		print("    réseau %s : %d logements sur %d sans service · sources %s" % [r, manque, n, (res.get(r).sources as Dictionary).keys()])
	var mf = av.get("manifs")
	if mf != null:
		print("    manifestations : %s" % str(mf.get("colere")))
	# Pas un échec : l'équilibre de la satisfaction d'un hameau est à revoir à part.
	print("  satisfaction à la fin de la démo : %d %%" % int(sd.valeur))


func _fin() -> void:
	Engine.time_scale = 1.0
	var erreurs: Array = _logger.liste.duplicate()
	if not erreurs.is_empty():
		print("Erreurs de script pendant la démo (%d) :" % erreurs.size())
		var vues := {}
		for e in erreurs:
			if not vues.has(e):
				vues[e] = true
				print("  ! ", e)
		ok = false
	print("TEST OK" if ok else "TEST ÉCHEC")
	quit(0 if ok else 1)
