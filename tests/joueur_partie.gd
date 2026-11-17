extends SceneTree
## Partie complète jouée comme un joueur, pour traquer les bugs avant la démo.
## Contrairement aux autres bancs, on passe par les vrais écrans : menu principal,
## globe, écran de chargement, boîte « Fonder ton village », clics de souris sur le
## terrain, touches du clavier, menu Pause (Sauver, Quitter vers le menu), bouton
## « Continuer » du menu principal.
## Chaque sauvegarde est rechargée puis réécrite : toute section qui ne revient pas
## à l'identique est signalée (c'est ainsi qu'on trouve les bugs de rechargement,
## comme les bâtiments qui repartaient en chantier).
##   godot --headless --path . --script res://tests/joueur_partie.gd [-- --jours 25 --hors-ligne --etapes ville,touches,recharge,f9,epoque,demo]

var ok := true
var _logger: JournalErreurs
var constats: Array[String] = []
var _contexte := "démarrage"


class JournalErreurs extends Logger:
	var mutex := Mutex.new()
	var liste: Array = []
	var contexte := ""

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool,
			error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING or rationale.begins_with("ÉCHEC") or code.begins_with("ÉCHEC"):
			return
		mutex.lock()
		if liste.size() < 400:
			liste.append("[%s] %s (%s:%d %s)" % [contexte, rationale if rationale != "" else code, file.get_file(), line, function])
		mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass


func _initialize() -> void:
	_logger = JournalErreurs.new()
	OS.add_logger(_logger)
	_run.call_deferred()
	create_timer(float(_arg("delai", "5400"))).timeout.connect(func() -> void:
		_check(false, "délai dépassé (%s)" % _contexte)
		_fin())


func _arg(nom: String, defaut: String) -> String:
	var a := OS.get_cmdline_user_args()
	var i := a.find("--" + nom)
	return a[i + 1] if i >= 0 and i + 1 < a.size() else defaut


func _etape(nom: String) -> bool:
	var e := _arg("etapes", "ville,touches,recharge,f9,epoque,demo")
	return e.split(",").has(nom)


func _ctx(t: String) -> void:
	_contexte = t
	_logger.contexte = t
	print("== ", t)


func _check(cond: bool, what: String) -> void:
	if cond:
		print("  ok  ", what)
	else:
		push_error("ÉCHEC : " + what)
		print("  !!  ", what)
		constats.append("[%s] %s" % [_contexte, what])
		ok = false


func _note(what: String) -> void:
	print("  ..  ", what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


# --- Hors ligne (option) -------------------------------------------------------------

var hors_ligne := false


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(430.0)
	return a


func _offline(g: Node) -> void:
	var w: TerrainWorld = g.get_node("Terrain")
	w.tiles.offline_generator = _flat_tile
	w.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	w.horizon.tiles.offline_generator = _flat_tile


## La partie s'ouvre derrière l'écran de chargement : on attend la scène Terre, puis
## que l'écran s'efface (comme le joueur qui attend la fin du chargement).
func _wait_game() -> Node:
	var t0 := Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Terre") and Time.get_ticks_msec() - t0 < 60000:
		await process_frame
	var g: Node = current_scene
	if g != null and g.name == "Terre" and hors_ligne:
		_offline(g)
	while EcranChargement.actif != null and Time.get_ticks_msec() - t0 < 120000:
		await process_frame
	_note("chargement : %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	return g


func _wait_scene(nom: String, max_ms := 60000) -> Node:
	var t0 := Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != nom or EcranChargement.actif != null) and Time.get_ticks_msec() - t0 < max_ms:
		await process_frame
	return current_scene


# --- Souris et clavier -----------------------------------------------------------------

var game: Node


func _cam() -> Camera3D:
	return game.get_viewport().get_camera_3d()


## Centre la caméra sur un point puis attend qu'elle s'y pose.
func _viser(p: Vector3, distance := 180.0) -> void:
	var rig: Node3D = game.rig
	rig.position.x = p.x
	rig.position.z = p.z
	rig._target_distance = distance
	await _frames(30)


## Clic gauche de souris sur un point du terrain (à l'écran, comme un vrai clic).
func _clic(p: Vector3, shift := false) -> bool:
	var cam := _cam()
	if cam == null or cam.is_position_behind(p):
		return false
	var sp := cam.unproject_position(p)
	var mm := InputEventMouseMotion.new()
	mm.position = sp
	mm.global_position = sp
	root.push_input(mm)
	await _frames(2)
	for pressed in [true, false]:
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = pressed
		mb.shift_pressed = shift
		mb.position = sp
		mb.global_position = sp
		root.push_input(mb)
		await _frames(2)
	return true


func _touche(code: Key, shift := false, ctrl := false) -> void:
	for pressed in [true, false]:
		var k := InputEventKey.new()
		k.keycode = code
		k.physical_keycode = code
		k.pressed = pressed
		k.shift_pressed = shift
		k.ctrl_pressed = ctrl
		root.push_input(k)
		await process_frame


func _sol(x: float, z: float) -> Vector3:
	return Vector3(x, game.world.cell_height(Vector2i(roundi(x), roundi(z))), z)


# --- Comparaison des sauvegardes --------------------------------------------------------

func _json(v: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(v))


## Toutes les sections de la sauvegarde, en JSON. Les cases de terrain modifiées sont
## comparées case par case (leur encodage par bloc dépend de l'ordre d'insertion).
func _instantane() -> Dictionary:
	var d: Dictionary = _json(game.save_sections())
	if d.has("terrain") and d.terrain is Dictionary and d.terrain.has("modifs"):
		d.terrain.modifs.erase("blocs")
	var cases := {}
	var w: TerrainWorld = game.world
	for c in w.modifications:
		cases["%d,%d" % [c.x, c.y]] = snappedf(float(w.modifications[c]), 0.01)
	d["_cases_terrain"] = cases
	return d


## Différences entre deux valeurs (chemins), au plus `maxi`.
func _diff(a: Variant, b: Variant, chemin: String, out: Array, maxi := 12) -> void:
	if out.size() >= maxi:
		return
	if typeof(a) != typeof(b):
		out.append("%s : %s → %s" % [chemin, _court(a), _court(b)])
		return
	if a is Dictionary:
		for k in a:
			if not b.has(k):
				out.append("%s.%s : disparu (%s)" % [chemin, k, _court(a[k])])
			else:
				_diff(a[k], b[k], "%s.%s" % [chemin, k], out, maxi)
			if out.size() >= maxi:
				return
		var apparus := []
		for k in b:
			if not a.has(k):
				apparus.append(k)
		if not apparus.is_empty():
			out.append("%s : %d clé(s) apparue(s), dont %s = %s" % [chemin, apparus.size(), apparus[0], _court(b[apparus[0]])])
		return
	if a is Array:
		if a.size() != b.size():
			var plus := ""
			if b.size() > a.size():
				var i := 0
				while i < a.size() and JSON.stringify(a[i]) == JSON.stringify(b[i]):
					i += 1
				plus = " (en plus au rang %d : %s)" % [i, _court(b[i])]
			out.append("%s : %d → %d éléments%s" % [chemin, a.size(), b.size(), plus])
			return
		for i in a.size():
			_diff(a[i], b[i], "%s[%d]" % [chemin, i], out, maxi)
			if out.size() >= maxi:
				return
		return
	if a is float and b is float:
		if absf(a - b) > maxf(1e-4, absf(a) * 1e-6):
			out.append("%s : %s → %s" % [chemin, _court(a), _court(b)])
		return
	if a != b:
		out.append("%s : %s → %s" % [chemin, _court(a), _court(b)])


func _court(v: Variant) -> String:
	var s := JSON.stringify(v)
	return s if s.length() < 90 else s.substr(0, 87) + "…"


## Sections qui changent forcément (horloge de la caméra, aperçus…) : on ne les compare pas.
const SECTIONS_LIBRES := ["personnage"]
## Écarts sans conséquence : relevés recalculés à chaque image (météo du jour), record
## d'habitants recompté, foyers sans niveau évalués d'office, champ par défaut ajouté.
const ECARTS_PERMIS := ["reseaux.incidents.tmax", "reglages.record_habitants", "niveaux_vie.foyers : ",
	"saisons.aujourdhui.tmax", "nuisances.valeurs : "]


func _comparer(avant: Dictionary, apres: Dictionary, quoi: String) -> int:
	var n := 0
	for s in avant:
		if SECTIONS_LIBRES.has(s):
			continue
		if not apres.has(s):
			_check(false, "%s : section « %s » absente après rechargement" % [quoi, s])
			n += 1
			continue
		var d := []
		_diff(avant[s], apres[s], s, d)
		d = d.filter(func(l: String) -> bool:
			for b in ECARTS_PERMIS:
				if l.begins_with(b):
					return false
			# Cortège « prévu » relu avec son champ par défaut.
			return not (l.begins_with("avis.manifs.liste[") and l.ends_with("dont ferme = false")))
		if not d.is_empty():
			n += 1
			print("  ≠ section %s (%d+ différences) :" % [s, d.size()])
			for l in d:
				print("      ", l)
			constats.append("[%s] section « %s » change au rechargement : %s" % [quoi, s, d[0]])
	return n


# --- Partie ------------------------------------------------------------------------------

var bs: BuildingSystem
var tr: TransportSystem
var zs: ZoneSystem
var amb: DayNight
var pop: Population
var fd: Fondateurs
var cm: Communes
var res: Reseaux


func _lier() -> void:
	bs = game.buildings
	tr = game.transport
	zs = game.zones
	amb = game.ambiance
	pop = game.population
	fd = game.fondateurs
	cm = game.communes
	res = game.reseaux


func _route(a: Vector2, b: Vector2, type := "route") -> bool:
	var r: Dictionary = tr.build_segment(type, _sol(a.x, a.y), _sol(b.x, b.y))
	if not r.get("ok", false):
		_note("route refusée %s -> %s : %s" % [a, b, r.get("reason", "?")])
	return bool(r.get("ok", false))


## Pose un bâtiment le long d'une rue est-ouest (z = rue), côté nord (-1) ou sud (1).
func _poser(id: String, x0: int, rue_z: int, cote: int, x1 := 0) -> int:
	var t := BuildingCatalog.get_type(id)
	if t.is_empty():
		_note("type inconnu : " + id)
		return -1
	var x := x0
	var pas := 6 if x1 > x0 else -6
	if x1 == 0:
		x1 = x0 + 240
		pas = 6
	var raison := ""
	while (pas > 0 and x <= x1) or (pas < 0 and x >= x1):
		for ecart in [1, 4, 10]:
			var c := Vector2i(x, rue_z + cote * (6 + int(t.d) / 2 + ecart))
			var r := bs.best_rotation(id, c)
			var chk := bs.check_place(id, c, r)
			if chk.ok:
				var bid := bs.place(id, c, r)
				if bid >= 0:
					return bid
			elif raison == "":
				raison = String(chk.get("reason", "?"))
		x += pas
	_note("%s refusé : %s" % [id, raison])
	return -1


func _habitants() -> int:
	cm.calculer_stats()
	var v := cm.principal()
	return int(cm.stats.get(v, {}).get("hab", 0)) if v >= 0 else 0


func _en_chantier() -> int:
	var n := 0
	for bid in bs.buildings:
		if bs.en_chantier(bid):
			n += 1
	return n


func _sans(r: String) -> int:
	var n := 0
	for bid in pop.by_home:
		if (pop.by_home[bid] as Array).is_empty() or Fondateurs.est_campement(bid):
			continue
		if res.taux(bid, r) < 0.5:
			n += 1
	return n


## Avance le temps en pas de 10 min de jeu (une image par pas), comme partie_test.
func _jours(n: float, quoi := "") -> void:
	var t0 := amb.unix_time
	var fin := t0 + n * 86400.0
	var j_prec := -1
	while amb.unix_time < fin:
		amb.unix_time += 600.0
		zs.grow_step()
		await process_frame
		if bs.money < 500_000 and game.budget != null and _emprunts < 3:
			var e: Dictionary = game.budget.emprunter(5_000_000, 20)
			if not e.is_empty():
				_emprunts += 1
				_note("emprunt de 5 M€ (caisse presque vide)")
		var j := int((amb.unix_time - t0) / 86400.0)
		if j != j_prec and j % 5 == 0 and quoi != "":
			j_prec = j
			_note("%s j+%d : %d hab, %d bâtiments dont %d en chantier, caisse %s, sans courant %d, sans eau %d" % [quoi, j,
				_habitants(), bs.buildings.size(), _en_chantier(), BuildingSystem.format_money(bs.money), _sans("elec"), _sans("eau")])


var _emprunts := 0


func _meteo_fixe() -> void:
	amb.weather.mode = Meteo.Mode.SOLEIL
	amb.weather.settle(amb.unix_time, 8.0)


# --- Étapes ------------------------------------------------------------------------------

func _run() -> void:
	Creations.persist = false
	hors_ligne = OS.get_cmdline_user_args().has("--hors-ligne")
	_ctx("Menu principal")
	change_scene_to_file(MenuPrincipal.SCENE)
	var menu := await _wait_scene("MenuPrincipal", 20000)
	if menu == null or not menu.get("_boutons") is Dictionary:
		menu = current_scene
	await _frames(10)
	_check(menu != null and (menu.get("_boutons") as Dictionary).has("nouvelle"), "le menu principal propose « Nouvelle partie »")
	(menu._boutons["nouvelle"] as Button).pressed.emit()
	var globe := await _wait_scene("Globe", 20000)
	await _frames(10)
	_check(globe != null and globe.has_method("select_place"), "le globe s'ouvre (%s)" % (globe.name if globe else "?"))

	_ctx("Globe")
	ReglagesPartie.prochaine = ReglagesPartie.preset("normal")
	ReglagesPartie.prochaine.tutoriel = true
	globe.select_place(46.775, 6.62, "Yverdon-les-Bains", true, "ch")
	await _frames(5)
	globe.start_game()
	game = await _wait_game()
	_check(game != null and game.name == "Terre", "la partie s'ouvre derrière l'écran de chargement")
	if game == null:
		_fin()
		return
	_lier()
	await _frames(20)

	if _etape("ville"):
		await _ville()
	if _etape("touches"):
		await _touches()
	if _etape("recharge"):
		await _recharge()
	if _etape("f9"):
		await _f9()
	if _etape("epoque"):
		await _epoque()
	if _etape("demo"):
		await _demo()
	_fin()


func _ville() -> void:
	_ctx("Fondation")
	_check(ReglagesPartie.actuel.preset_name() == "Normal" and not bs.unlimited_money, "mode Normal, argent compté")
	var tuto: Tutoriel = game.tutoriel
	_check(tuto.actif, "le tutoriel démarre pour une nouvelle partie (étape « %s »)" % tuto.id_courant())
	_note("caisse avant la fondation : " + BuildingSystem.format_money(bs.money))
	# Le joueur suit le tutoriel : tour de la caméra, puis « Fonder » avec le bouton de l'étape.
	for i in 6:
		if tuto.id_courant() == "fonder" or not tuto.actif:
			break
		_note("tutoriel : « %s » passé" % tuto.id_courant())
		tuto.passer()
		await _frames(3)
	_check(tuto.id_courant() == "fonder", "le tutoriel arrive à l'étape « fonder » (%s)" % tuto.id_courant())
	tuto.agir()
	await _frames(5)
	var dlg: ConfirmationDialog = game.villages_panel._dialog
	_check(dlg.visible, "le bouton du tutoriel ouvre « Fonder ton village »")
	game.villages_panel._dialog_edit.text = "Yverdon"
	dlg.get_ok_button().pressed.emit()
	await _frames(5)
	_check(bs.mode == BuildingSystem.Mode.PLACE and bs.type_id == "maison_commune", "outil Maison de commune en main")
	var centre := _sol(0, -20)
	await _viser(centre, 160.0)
	await _clic(centre)
	await _frames(10)
	_check(cm.villages.size() == 1, "un clic sur le terrain fonde le village (%d village)" % cm.villages.size())
	if cm.villages.is_empty():
		var mc := bs.place("maison_commune", Vector2i(0, -20), 0)
		_note("pose directe de la Maison de commune : %d" % mc)
		await _frames(5)
	if not cm.villages.is_empty():
		_check(String(cm.villages[cm.principal()].nom) == "Yverdon", "le village porte le nom tapé (%s)" % cm.villages[cm.principal()].nom)
	_check(fd.arrives, "les fondateurs arrivent (%d)" % fd.vivants().size())
	_check(tr.network.edges.size() > 0, "rue en T offerte (%d tronçons)" % tr.network.edges.size())
	_note("tutoriel : étape « %s » (%d/%d)" % [tuto.id_courant(), tuto.numero(), tuto.total()])
	_note("caisse : " + BuildingSystem.format_money(bs.money))

	_ctx("Rues à la souris")
	amb.set_speed(0)
	_meteo_fixe()
	game.hud.select_tool_silently(TerreHud.FIRST_TRANSPORT_TOOL)
	game._on_tool_selected(TerreHud.FIRST_TRANSPORT_TOOL)
	await _frames(3)
	var n0: int = tr.network.edges.size()
	var a := _sol(-120, 60)
	var b := _sol(120, 60)
	await _viser(Vector3(0, a.y, 60), 260.0)
	await _clic(a)
	await _clic(b)
	await _frames(5)
	_check(tr.network.edges.size() > n0, "deux clics tracent une rue (%d → %d tronçons)" % [n0, tr.network.edges.size()])
	await _touche(KEY_ESCAPE)
	await _frames(3)

	_ctx("Plan de la ville")
	var rues_ok := true
	for z in [0, 70, 140, -90, -160]:
		rues_ok = _route(Vector2(-300, z), Vector2(300, z)) and rues_ok
	for x in [-300, 60, 300]:
		rues_ok = _route(Vector2(x, -160), Vector2(x, 140)) and rues_ok
	_check(rues_ok, "plan de rues posé (%d tronçons)" % tr.network.edges.size())
	var poses := {}
	for p in [["eolienne", 120, -160, -1, 290], ["eolienne", 170, -160, -1, 290], ["centrale_solaire", -290, -160, -1, -60],
			["batteries", -200, -160, -1, -60], ["forage_eau", -40, -160, -1, -290], ["lagunage", 160, 140, 1, 290],
			["ecole", -280, 0, 1, 280], ["entreprise_btp", 20, 140, -1, 290], ["entreprise_btp", 100, 140, -1, 290],
			["entreprise_btp", 180, 140, -1, 290]]:
		var bid := _poser(p[0], p[1], p[2], p[3], p[4])
		poses[p[0]] = poses.get(p[0], 0) + (1 if bid >= 0 else 0)
	_check(poses.get("eolienne", 0) == 2 and poses.get("forage_eau", 0) == 1 and poses.get("entreprise_btp", 0) == 3,
		"courant, eau et entreprises du bâtiment posés (%s)" % JSON.stringify(poses))
	var zn := 0
	for z in [0, 70, 140, -90]:
		for x in [-290, 10]:
			var k := "R"
			if z == 140 and x == 10:
				k = "I"
			elif z == -90:
				k = "C"
			if zs.add_zone(k, Rect2i(x, z - 30, 280, 60)) >= 0:
				zn += 1
	_check(zn >= 6, "%d zones peintes" % zn)
	_note("caisse : " + BuildingSystem.format_money(bs.money))

	_ctx("La ville grandit")
	var jours := float(_arg("jours", "30"))
	await _jours(jours * 0.6, "ville")
	# Services de la ville quand elle a des habitants, comme un joueur.
	for p in [["caserne_pompiers", -280, 70, 1, 280], ["police", -280, 70, -1, 280], ["hopital", -280, -90, 1, 280],
			["decheterie", -280, 140, 1, 280], ["decharge", -280, -160, 1, 280], ["antenne_5g", -280, 140, 1, 280],
			["foot", -280, 140, -1, 280], ["parc", -100, 0, -1, 280]]:
		if BuildingCatalog.get_type(p[0]).is_empty():
			_note("pas de type « %s »" % p[0])
			continue
		var bid := _poser(p[0], p[1], p[2], p[3], p[4])
		poses[p[0]] = bid
	_note("services : " + JSON.stringify(poses))
	await _jours(jours * 0.4, "ville")
	var hab := _habitants()
	_check(hab >= 100, "la ville a des habitants (%d)" % hab)
	_note("tutoriel : étape « %s » (%d/%d), actif %s" % [tuto.id_courant(), tuto.numero(), tuto.total(), tuto.actif])


## Toutes les touches des panneaux, ouvertes puis refermées, comme un joueur curieux.
const TOUCHES := [
	[KEY_F1, false], [KEY_F2, false], [KEY_F4, false], [KEY_F6, false], [KEY_F7, false], [KEY_F7, true], [KEY_F8, false],
	[KEY_F10, false], [KEY_F11, false], [KEY_F12, false], [KEY_END, false],
	[KEY_B, false], [KEY_M, false], [KEY_N, true], [KEY_I, true], [KEY_M, true], [KEY_H, true], [KEY_P, true], [KEY_N, false],
	[KEY_O, false], [KEY_X, false], [KEY_Y, false], [KEY_H, false], [KEY_K, false], [KEY_L, false], [KEY_G, false],
	[KEY_P, false], [KEY_U, false], [KEY_A, true], [KEY_G, true], [KEY_Z, true], [KEY_C, true], [KEY_B, true],
	[KEY_X, true], [KEY_R, true], [KEY_D, true], [KEY_S, true], [KEY_W, true], [KEY_K, true], [KEY_O, true],
	[KEY_U, true], [KEY_F, true], [KEY_L, true], [KEY_E, true], [KEY_F1, true], [KEY_PAGEDOWN, false], [KEY_PAGEUP, false],
	[KEY_HOME, false], [KEY_TAB, false], [KEY_TAB, false], [KEY_SPACE, false],
]


func _nom_touche(t: Array) -> String:
	return ("Maj+" if t[1] else "") + OS.get_keycode_string(t[0])


func _touches() -> void:
	_ctx("Touches des panneaux")
	var avant: int = _logger.liste.size()
	var noeuds0 := root.get_child_count()
	for t in TOUCHES:
		_logger.contexte = "touche " + _nom_touche(t)
		await _touche(t[0], t[1])
		await _frames(6)
		await _jours(0.05)
		await _touche(t[0], t[1])
		await _frames(4)
		if game.pause_menu != null:
			game.close_pause()
		await _touche(KEY_ESCAPE)
		await _frames(3)
		if game.pause_menu != null:
			game.close_pause()
			await _frames(2)
		if paused:
			paused = false
	_logger.contexte = _contexte
	var nouvelles: int = _logger.liste.size() - avant
	_check(nouvelles == 0, "aucune erreur de script en ouvrant et fermant %d panneaux (%d)" % [TOUCHES.size(), nouvelles])
	_check(root.get_child_count() == noeuds0, "rien ne traîne à la racine (%d → %d)" % [noeuds0, root.get_child_count()])


func _recharge() -> void:
	_ctx("Sauvegarde au menu Pause")
	amb.set_speed(0)
	await _frames(3)
	# Échap referme d'abord ce qui est ouvert (outil, panneau), puis ouvre le menu Pause.
	for i in 4:
		if game.pause_menu != null:
			break
		await _touche(KEY_ESCAPE)
		await _frames(5)
	_check(game.pause_menu != null, "Échap ouvre le menu Pause")
	if game.pause_menu == null:
		game.open_pause()
		await _frames(2)
	var avant: Dictionary = _instantane()
	game.pause_menu.save_requested.emit()
	await _frames(3)
	var slot: String = GameStart.slot_id
	_check(slot != "" and SaveGame.exists(slot), "la partie est sauvegardée (%s)" % slot)
	var n_bat := bs.buildings.size()
	var n_ch := _en_chantier()
	var hab := _habitants()
	var caisse := bs.money
	var sans_c := _sans("elec")
	var sans_e := _sans("eau")
	var date: float = amb.unix_time
	_ctx("Quitter vers le menu puis Continuer")
	game.pause_menu.quit_requested.emit(false, false)
	var menu := await _wait_scene("MenuPrincipal", 60000)
	await _frames(10)
	_check(menu != null and menu.name == "MenuPrincipal", "retour au menu principal")
	_check(menu._carte.visible and String(menu._derniere.get("id", "")) == slot, "la carte « Continuer » montre la partie")
	(menu._boutons.get("continuer", menu._boutons.get("nouvelle")) as Button).pressed.emit()
	game = await _wait_game()
	_check(game != null and game.name == "Terre", "la partie se rouvre")
	_lier()
	amb.set_speed(0)
	await _frames(3)
	_ctx("Rechargement identique")
	_check(absf(amb.unix_time - date) < 3600.0, "même date (écart %.0f s)" % (amb.unix_time - date))
	_check(bs.buildings.size() == n_bat, "même nombre de bâtiments (%d → %d)" % [n_bat, bs.buildings.size()])
	_check(_en_chantier() <= n_ch, "pas de bâtiment fini qui repart en chantier (%d → %d)" % [n_ch, _en_chantier()])
	_check(absi(_habitants() - hab) <= maxi(3, hab / 50), "mêmes habitants (%d → %d)" % [hab, _habitants()])
	_check(absi(bs.money - caisse) <= 1000, "même caisse (%s → %s)" % [BuildingSystem.format_money(caisse), BuildingSystem.format_money(bs.money)])
	_check(_sans("elec") <= sans_c + 2 and _sans("eau") <= sans_e + 2, "courant et eau toujours servis (sans courant %d → %d, sans eau %d → %d)" % [sans_c, _sans("elec"), sans_e, _sans("eau")])
	var apres: Dictionary = _instantane()
	var n := _comparer(avant, apres, "rechargement")
	_check(n == 0, "toutes les sections reviennent à l'identique (%d différente(s))" % n)

	_ctx("La ville continue après le rechargement")
	_meteo_fixe()
	var hab0 := _habitants()
	await _jours(5.0, "après")
	_check(_habitants() >= hab0 * 0.9, "pas d'exode après le rechargement (%d → %d)" % [hab0, _habitants()])
	# Deuxième aller-retour : sauvegarde automatique puis rechargement direct.
	_ctx("Sauvegarde automatique")
	amb.set_speed(0)
	await _frames(2)
	var avant2: Dictionary = _instantane()
	game._unsaved = true
	game._autosave_timer = OptionsJeu.autosave_min * 60.0
	game._autosave(1.0)
	var auto: Dictionary = SaveGame.derniere_autosave()
	_check(not auto.is_empty(), "sauvegarde automatique écrite (%s)" % auto.get("id", "?"))
	if not auto.is_empty():
		game.hud.globe_requested.emit()
		var gl := await _wait_scene("Globe", 30000)
		await _frames(5)
		gl.load_saved_game(String(auto.id))
		game = await _wait_game()
		_lier()
		amb.set_speed(0)
		await _frames(3)
		var n2 := _comparer(avant2, _instantane(), "sauvegarde auto")
		_check(n2 == 0, "la sauvegarde automatique revient à l'identique (%d différente(s))" % n2)
		SaveGame.delete(String(auto.id))
	SaveGame.delete(slot)


## F5 puis F9 : le joueur sauve, joue encore, puis revient à sa sauvegarde sans quitter
## la partie (chargement par-dessus une ville qui tourne). Puis il charge une autre
## partie depuis le menu Pause → Charger : rien de la première ne doit rester.
func _f9() -> void:
	_ctx("F5 puis F9")
	amb.set_speed(0)
	await _frames(2)
	await _touche(KEY_F5)
	await _frames(3)
	var slot: String = GameStart.slot_id
	_check(slot != "" and SaveGame.exists(slot), "F5 sauvegarde la partie (%s)" % slot)
	var avant: Dictionary = _instantane()
	var n_bat := bs.buildings.size()
	_meteo_fixe()
	await _jours(4.0, "avant F9")
	# Le joueur casse quelque chose qu'il regrette, puis F9.
	var victime := -1
	for bid in bs.buildings:
		if BuildingCatalog.base_of(String(bs.buildings[bid].t)) == "eolienne":
			victime = bid
	if victime >= 0:
		bs.demolish(victime)
	amb.set_speed(0)
	await _frames(2)
	await _touche(KEY_F9)
	await _frames(5)
	amb.set_speed(0)
	await _frames(2)
	_check(bs.buildings.size() == n_bat, "F9 ramène les bâtiments de la sauvegarde (%d → %d)" % [n_bat, bs.buildings.size()])
	var n := _comparer(avant, _instantane(), "F9")
	_check(n == 0, "F9 revient exactement à la sauvegarde (%d section(s) différente(s))" % n)
	# Une autre partie, chargée par-dessus celle-ci : rien ne doit rester de la première.
	_ctx("Charger une autre partie depuis le jeu")
	var autre := await _partie_minuscule()
	if autre == "":
		return
	var propre: Dictionary = {}
	# Référence : l'autre partie chargée seule.
	game.hud.globe_requested.emit()
	var gl := await _wait_scene("Globe", 30000)
	await _frames(5)
	gl.load_saved_game(slot)
	game = await _wait_game()
	_lier()
	amb.set_speed(0)
	await _frames(3)
	# Ville rechargée (pleine) → on charge par-dessus la petite partie.
	game.open_saves_panel()
	await _frames(3)
	_check(game._saves_panel != null, "Charger ouvre la liste des parties")
	game._saves_panel.load_chosen.emit(autre)
	await _frames(5)
	_lier()
	amb.set_speed(0)
	await _frames(3)
	var par_dessus: Dictionary = _instantane()
	game.hud.globe_requested.emit()
	gl = await _wait_scene("Globe", 30000)
	await _frames(5)
	gl.load_saved_game(autre)
	game = await _wait_game()
	_lier()
	amb.set_speed(0)
	await _frames(3)
	propre = _instantane()
	var m := _comparer(propre, par_dessus, "par-dessus")
	_check(m == 0, "charger par-dessus une ville donne la même partie qu'un chargement neuf (%d section(s) différente(s))" % m)
	SaveGame.delete(autre)
	# On revient à la grande ville pour la suite.
	game.hud.globe_requested.emit()
	gl = await _wait_scene("Globe", 30000)
	await _frames(5)
	gl.load_saved_game(slot)
	game = await _wait_game()
	_lier()
	amb.set_speed(0)


## Petite partie neuve ailleurs (une Maison de commune, une rue), sauvegardée.
func _partie_minuscule() -> String:
	game.hud.globe_requested.emit()
	var gl := await _wait_scene("Globe", 30000)
	await _frames(5)
	var r := ReglagesPartie.preset("normal")
	r.tutoriel = false
	ReglagesPartie.prochaine = r
	gl.select_place(46.2, 6.14, "Genève", true, "ch")
	gl.start_game()
	game = await _wait_game()
	_lier()
	if game.villages_panel._dialog.visible:
		game.villages_panel._dialog.get_ok_button().pressed.emit()
		await _frames(3)
	bs.place("maison_commune", Vector2i(0, -20), 0)
	await _frames(5)
	amb.set_speed(0)
	_route(Vector2(-100, 40), Vector2(100, 40))
	await _jours(1.0)
	amb.set_speed(0)
	await _frames(2)
	var ok_s: bool = game.save_game("", "Banc petite partie")
	_check(ok_s, "petite partie sauvegardée")
	return GameStart.slot_id if ok_s else ""


func _epoque() -> void:
	_ctx("Partie en 1800")
	game.hud.globe_requested.emit()
	var gl := await _wait_scene("Globe", 30000)
	await _frames(5)
	var r := ReglagesPartie.preset("normal")
	r.tutoriel = false
	r.annee_depart = 1800
	ReglagesPartie.prochaine = r
	gl.select_place(46.52, 6.63, "Lausanne", true, "ch")
	gl.start_game()
	game = await _wait_game()
	_check(game != null and game.name == "Terre", "partie de 1800 ouverte")
	_lier()
	await _frames(10)
	var annee := Epoques.annee()
	_note("année : %d" % annee)
	if game.villages_panel._dialog.visible:
		game.villages_panel._dialog.get_ok_button().pressed.emit()
		await _frames(3)
	var mc := bs.place("maison_commune", Vector2i(0, -20), 0)
	await _frames(5)
	_check(mc >= 0 and cm.villages.size() == 1, "village fondé en 1800")
	amb.set_speed(0)
	_meteo_fixe()
	_route(Vector2(-200, 40), Vector2(200, 40), "route")
	_check(not Epoques.batiment_disponible("eolienne"), "pas d'éolienne en 1800 (%s)" % Epoques.raison_batiment("eolienne"))
	for id in ["puits", "ecole", "ferme", "maison"]:
		if not BuildingCatalog.get_type(id).is_empty():
			var bid := _poser(id, -190, 40, 1, 190)
			_note("%s en 1800 : %s" % [id, "posé" if bid >= 0 else "refusé"])
	zs.add_zone("R", Rect2i(-190, 50, 380, 50))
	await _jours(10.0, "1800")
	var avant: Dictionary = _instantane()
	_check(game.save_game("", "Banc 1800"), "partie de 1800 sauvegardée")
	var slot: String = GameStart.slot_id
	game.hud.globe_requested.emit()
	gl = await _wait_scene("Globe", 30000)
	await _frames(5)
	gl.load_saved_game(slot)
	game = await _wait_game()
	_lier()
	amb.set_speed(0)
	await _frames(3)
	var n := _comparer(avant, _instantane(), "1800")
	_check(n == 0, "la partie de 1800 revient à l'identique (%d différente(s))" % n)
	_check(ReglagesPartie.actuel.annee_depart == 1800, "l'année de départ est gardée (%d)" % ReglagesPartie.actuel.annee_depart)
	SaveGame.delete(slot)


func _demo() -> void:
	_ctx("Démo guidée")
	_quitter_vers_menu()
	var menu := await _wait_scene("MenuPrincipal", 60000)
	await _frames(10)
	_check(menu != null and (menu._boutons as Dictionary).has("demo"), "le menu propose la démo guidée")
	if menu == null or not (menu._boutons as Dictionary).has("demo"):
		return
	(menu._boutons["demo"] as Button).pressed.emit()
	game = await _wait_game()
	_check(game != null and game.name == "Terre", "la démo s'ouvre")
	if game == null:
		return
	_lier()
	await _frames(30)
	var tuto: Tutoriel = game.tutoriel
	_check(tuto.actif and tuto.est_demo(), "la démo guide le joueur (étape « %s », %d/%d)" % [tuto.id_courant(), tuto.numero(), tuto.total()])
	# Le joueur suit les étapes avec le bouton « Fais-le pour moi » quand il en a.
	var vus := {}
	for i in 80:
		if not tuto.actif:
			break
		var id := tuto.id_courant()
		vus[id] = true
		_logger.contexte = "démo, étape " + id
		tuto.agir()
		await _frames(5)
		await _jours(0.25)
		if tuto.id_courant() == id:
			tuto.passer()
			await _frames(3)
	_logger.contexte = _contexte
	_note("étapes vues : %s" % ", ".join(vus.keys()))
	_check(vus.size() >= 5, "la démo enchaîne ses étapes (%d)" % vus.size())


func _quitter_vers_menu() -> void:
	if game != null and is_instance_valid(game) and game.has_method("open_pause"):
		game.open_pause()
		await _frames(2)
		game.pause_menu.quit_requested.emit(false, false)


func _fin() -> void:
	var erreurs: Array = _logger.liste.duplicate()
	if not erreurs.is_empty():
		print("Erreurs de script pendant la partie (%d) :" % erreurs.size())
		var vues := {}
		for e in erreurs:
			var cle := String(e).substr(String(e).find("]") + 1)
			if not vues.has(cle):
				vues[cle] = true
				print("  ! ", e)
		ok = false
	if not constats.is_empty():
		print("Constats (%d) :" % constats.size())
		for c in constats:
			print("  - ", c)
	print("JOUEUR TEST OK" if ok else "JOUEUR TEST ÉCHEC")
	quit(0 if ok else 1)
