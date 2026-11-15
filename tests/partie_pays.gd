extends SceneTree
## Partie test à plusieurs villes et plusieurs pays, sans affichage, comme une
## partie solo en mode Normal autour de Bâle (France, Suisse, Allemagne) :
##   - 8 villes : 4 déjà grandes (on les remplit d'un coup, comme après des mois
##     de jeu) et 4 villages qui partent de rien ;
##   - chaque ville appartient au pays réel de son lieu (géographie du jeu) ;
##   - des routes départementales relient les villes, deux sortent par les
##     bords de la carte (import, export) ;
##   - des fermes, usines et entrepôts répartis dans les trois pays : les
##     camions traversent les villes et les frontières (douane) ;
##   - toutes les villes passent en pilote automatique, la vie suit son cours
##     (arrivées, chantiers avec ouvriers, élections, événements).
## Le temps avance par pas de 10 min de jeu. Chaque jour : habitants, caisses des
## villes et des pays, chômage, satisfaction, commerce entre villes et entre
## pays, temps par pas, mémoire. À la fin : mesure en temps réel (1 jour/min),
## sauvegarde et chargement, erreurs de script.
##
## Usage :
##   godot --headless --path . --script res://tests/partie_pays.gd -- [--jours 120] [--rapport partie_pays.csv]
##         [--echelle 1.0] [--reel 600] [--messages]
##   --echelle X  multiplie la taille des grandes villes (0.25 pour un essai rapide)
##   --reel N     images mesurées à la fin à la vitesse normale (0 : pas de mesure)

const BLOC := 120

## nom, x, z, habitants au départ (0 : village qui part de rien).
const VILLES := [
	["Bâle", 0, 0, 4000],
	["Saint-Louis", -6000, -4000, 2500],
	["Lörrach", 8000, -8000, 1500],
	["Liestal", 12000, 8000, 800],
	["Sierentz", -8000, -12000, 0],
	["Hagenthal", -12000, 2000, 0],
	["Aesch", 0, 8000, 0],
	["Efringen", 0, -12000, 0],
]
## Routes entre villes (indices dans VILLES).
const LIENS := [[0, 1], [0, 2], [0, 6], [0, 3], [1, 4], [1, 5], [2, 7], [7, 4], [2, 3]]
## Sorties par le bord de la carte : [ville, x, z].
const SORTIES := [[5, -19900, 2000], [2, 19900, -8000]]
## Entreprises par ville (chaînes réparties entre les pays).
const ENTREPRISES := {
	"Saint-Louis": ["ferme_cereales", "ferme_cereales", "moulin", "ferme_laitiere", "elevage", "transporteur", "entrepot"],
	"Sierentz": ["ferme_cereales", "ferme_maraichere"],
	"Bâle": ["laiterie", "fournil", "usine_agro", "brasserie", "usine_hygiene", "labo_pharma", "transporteur", "supermarche"],
	"Liestal": ["menuiserie", "scierie", "exploitation_forestiere"],
	"Lörrach": ["abattoir", "usine_biens", "usine_textile", "transporteur", "entrepot", "grand_magasin"],
	"Efringen": ["ferme_betteraves", "sucrerie"],
}
## Services posés dans les grandes villes avant de commencer : [type, habitants par bâtiment].
const SERVICES := [["ecole", 1500], ["boulangerie", 1500], ["superette", 1200], ["parc", 2000], ["aire_jeux", 2000],
	["pompiers", 5000], ["police", 2500], ["central_telephonique", 3000], ["pylone_4g", 2500], ["gymnase", 4000], ["hopital", 6000], ["entreprise_btp", 1500]]

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
		if liste.size() < 300:
			liste.append("%s (%s:%d %s)" % [rationale if rationale != "" else code, file.get_file(), line, function])
		mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass


func _initialize() -> void:
	_logger = Journal.new()
	OS.add_logger(_logger)
	_run.call_deferred()
	create_timer(4.0 * 3600.0).timeout.connect(func() -> void:
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
	a.fill(260.0)
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
var cm: Communes
var pays: Pays
var pa: PiloteAuto
var prod: Production
var stats: Statistiques
var rig: Node3D
## Nom -> vid.
var vids := {}
## Nom -> [x, z] du centre.
var centres := {}


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


## Charge le relief autour d'un point (générateur hors ligne, tuiles d'environ 800 m) :
## les villes lointaines peuvent construire même quand la caméra est ailleurs.
func _charger(c: Vector2, rayon: float) -> void:
	var x := c.x - rayon
	while x <= c.x + rayon:
		var z := c.y - rayon
		while z <= c.y + rayon:
			_tuile(x, z)
			z += 300.0
		x += 300.0


func _tuile(x: float, z: float) -> void:
	var t := Vector2i(int(world._pixel_x(x)) >> 8, int(world._pixel_y(z)) >> 8)
	if not world.tiles.has_tile(t):
		world.tiles.request_tile(t)


## Relief le long d'un tracé (et 300 m de part et d'autre).
func _charger_ligne(a: Vector2, b: Vector2) -> void:
	var n := maxi(1, ceili(a.distance_to(b) / 200.0))
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		for dx in [-300.0, 0.0, 300.0]:
			for dz in [-300.0, 0.0, 300.0]:
				_tuile(p.x + dx, p.y + dz)


func _aller(x: float, z: float, n := 4) -> void:
	rig.position = Vector3(x, 0.0, z)
	await _frames(n)


func _h(x: float, z: float) -> float:
	var h := world.cell_height(Vector2i(roundi(x), roundi(z)))
	return 260.0 if is_nan(h) else h


## Route départementale en tronçons de 2,5 km au plus (3 km maximum par tronçon).
func _route_longue(a: Vector2, b: Vector2) -> bool:
	_charger_ligne(a, b)
	var n := maxi(1, ceili(a.distance_to(b) / 2500.0))
	var ok_tout := true
	for i in n:
		ok_tout = _route(a.lerp(b, float(i) / n), a.lerp(b, float(i + 1) / n)) and ok_tout
	return ok_tout


func _route(a: Vector2, b: Vector2, voie := "route") -> bool:
	var r: Dictionary = tr.build_segment(voie, Vector3(a.x, _h(a.x, a.y), a.y), Vector3(b.x, _h(b.x, b.y), b.y))
	if not r.get("ok", false):
		print("    route refusée ", a, " -> ", b, " : ", r.get("reason", "?"))
	return bool(r.get("ok", false))


## Grille de n × n pâtés (n impair) centrée sur la mairie : le pâté du milieu
## garde la mairie.
func _grille(c: Vector2, n: int) -> void:
	var span := BLOC * n / 2.0
	for k in n + 1:
		var v := -span + k * BLOC
		# Rues en ville (les départementales relient les villes).
		_route(Vector2(c.x + v, c.y - span), Vector2(c.x + v, c.y + span), "rue")
		_route(Vector2(c.x - span, c.y + v), Vector2(c.x + span, c.y + v), "rue")


func _logements(vid: int) -> int:
	cm.calculer_stats()
	return int(cm.stats.get(vid, {}).get("logements", 0))


## Agrandit une ville (grille, zonage) jusqu'à loger `habitants`, puis fait
## emménager des foyers.
func _remplir(vid: int, c: Vector2, habitants: int) -> void:
	var n := 3
	var zones_faites := {}
	while true:
		if _logements(vid) * 2.3 >= habitants * 1.15 or n > 15:
			break
		n += 2
		cm._etendre(vid, BLOC * n * 0.75 + 200.0)
		_grille(c, n)
		var span := BLOC * n / 2.0
		for k in n:
			for l in n:
				var key := Vector2i(k - n / 2, l - n / 2)
				if key == Vector2i.ZERO or zones_faites.has(key):
					continue
				zones_faites[key] = true
				var kinds := ["R", "R", "R", "C", "I", "R", "R"]
				var kind: String = kinds[absi(key.x * 7 + key.y * 3) % kinds.size()]
				zs.add_zone(kind, Rect2i(int(c.x - span + k * BLOC + 6), int(c.y - span + l * BLOC + 6), BLOC - 12, BLOC - 12))
		for i in n * n * 40:
			zs.grow_step()
	pop._sync_buildings()
	cm.calculer_stats()
	var homes := []
	for bid in pop.known:
		if int(pop.known[bid].log) > 0 and cm.village_de(bid) == vid:
			homes.append(bid)
	homes.shuffle()
	var guard := 0
	var avant := pop.persons.size()
	while pop.persons.size() - avant < habitants and guard < 40000 and not homes.is_empty():
		guard += 1
		pop.spawn_household(homes[guard % homes.size()])
	print("  %s : grille %d × %d, %d logements, %d habitants" % [pays.nom_de(vid), n, n, _logements(vid), pop.persons.size() - avant])


func _poser(vid: int, id: String) -> int:
	if not BuildingCatalog.all_types().has(id):
		print("    type inconnu : ", id)
		return -1
	var bid := pa._poser(vid, id)
	if bid < 0:
		# Plus de place le long des rues : on en ouvre une.
		pa._prolonger(vid)
		bid = pa._poser(vid, id)
	if bid < 0:
		print("    %s refusé à %s" % [id, pays.nom_de(vid)])
	return bid


## Point de raccordement d'une ville vers un point lointain : le bout de rue le plus proche.
func _bout(vid: int, vers: Vector2) -> Vector2:
	var best := Vector2(centres[pays.nom_de(vid)][0], centres[pays.nom_de(vid)][1])
	var best_d := INF
	var net := tr.network
	for eid in pa._voies(vid):
		var e: Dictionary = net.edges[eid]
		for nd in [int(e.a), int(e.b)]:
			var p := net.node_pos(nd)
			var d := Vector2(p.x, p.z).distance_to(vers)
			if d < best_d:
				best_d = d
				best = Vector2(p.x, p.z)
	return best


## Un nœud du réseau routier de la ville (-1 sans rue).
func _noeud(vid: int) -> int:
	var vs := pa._voies(vid)
	return int(tr.network.edges[vs[0]].a) if not vs.is_empty() else -1


func _reseaux(vid: int, hab: int) -> void:
	_poser(vid, "poste_national")
	for i in maxi(1, ceili(hab / 3000.0)):
		_poser(vid, "forage_eau")
	if hab <= 1500 or _poser(vid, "station_epuration_locale") < 0:
		if _poser(vid, "lagunage") < 0:
			_poser(vid, "station_epuration_locale")
	# Déchets : dépôt de collecte (camions-bennes), décharge, déchèterie.
	for i in maxi(1, ceili(hab / 6000.0)):
		_poser(vid, "depot_collecte")
	_poser(vid, "decharge")
	_poser(vid, "decheterie")


func _run() -> void:
	Creations.persist = false
	var jours_max := int(_arg("jours", "120"))
	var rapport := _arg("rapport", "")
	var echelle := float(_arg("echelle", "1.0"))
	var reel := int(_arg("reel", "600"))
	ReglagesPartie.prochaine = ReglagesPartie.preset("normal")

	print("Globe : Bâle")
	change_scene_to_file("res://scenes/globe.tscn")
	await _frames(5)
	var globe: Node = current_scene
	globe.select_place(47.56, 7.59, "Bâle (test)", true)
	ReglagesPartie.prochaine.tutoriel = false
	globe.start_game()
	game = await _wait_game()
	_check(game != null and game.name == "Terre", "la partie s'ouvre")
	world = game.world
	_offline(game)
	world.view_radius_override = 900.0
	world.set_origin(47.56, 7.59)
	rig = game.get_node("CameraRig")
	bs = game.buildings
	tr = game.transport
	zs = game.zones
	amb = game.ambiance
	pop = game.population
	cm = game.communes
	pays = game.pays
	pa = game.pilote
	prod = game.production
	stats = game.statistiques if game.get("statistiques") != null else null
	for v in VILLES:
		_charger(Vector2(float(v[1]), float(v[2])), 2500.0)
	for i in 600:
		await process_frame
		if i >= 60 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	_check(not is_nan(world.cell_height(Vector2i(12000, 8000))) and not is_nan(world.cell_height(Vector2i(-8000, -12000))), "relief chargé autour des villes")
	amb.set_speed(0)
	amb.unix_time = float(Time.get_unix_time_from_datetime_string("2026-04-06T07:00:00")) - amb.utc_offset() * 3600.0
	if game.villages_panel._dialog.visible:
		game.villages_panel._dialog.hide()

	print("Mise en place (comme après plusieurs mois de jeu) :")
	var t_setup := Time.get_ticks_msec()
	var argent_depart := bs.money
	bs.unlimited_money = true
	BatimentsVie.chantiers = false
	pop.arrivals = false
	zs.growth = false
	for v in VILLES:
		var nom := String(v[0])
		var c := Vector2(float(v[1]), float(v[2]))
		centres[nom] = [c.x, c.y]
		await _aller(c.x, c.y)
		cm.nom_en_attente = nom
		var mc := bs.place("maison_commune", Vector2i(roundi(c.x), roundi(c.y)), 0)
		var vid := cm.village_du_batiment(mc)
		vids[nom] = vid
		_check(mc >= 0 and vid >= 0, "%s fondée (%s)" % [nom, pays.nom_nation(pays.nation_de(vid)) if vid >= 0 else "?"])
		if game.villages_panel._dialog.visible:
			game.villages_panel._dialog.hide()
	_check(pays.cles_nations().size() == 3, "trois pays : %s" % ", ".join(pays.cles_nations().map(func(k) -> String: return pays.nom_nation(int(k)))))
	for v in VILLES:
		var nom := String(v[0])
		var vid := int(vids[nom])
		var c := Vector2(float(v[1]), float(v[2]))
		var hab := roundi(int(v[3]) * echelle)
		await _aller(c.x, c.y)
		if hab > 0:
			_remplir(vid, c, hab)
		else:
			var t := pa._rue_mairie(vid)
			if t == "":
				print("    pas de première rue à %s" % nom)
	print("Routes entre les villes :")
	var routes_ok := 0
	for l in LIENS:
		var a := int(vids[String(VILLES[l[0]][0])])
		var b := int(vids[String(VILLES[l[1]][0])])
		var ca := Vector2(centres[pays.nom_de(a)][0], centres[pays.nom_de(a)][1])
		var cb := Vector2(centres[pays.nom_de(b)][0], centres[pays.nom_de(b)][1])
		if _route_longue(_bout(a, cb), _bout(b, ca)):
			routes_ok += 1
	for s in SORTIES:
		var a := int(vids[String(VILLES[s[0]][0])])
		if _route_longue(_bout(a, Vector2(s[1], s[2])), Vector2(float(s[1]), float(s[2]))):
			routes_ok += 1
	_check(routes_ok >= LIENS.size() + SORTIES.size() - 1, "%d routes entre villes et vers les bords" % routes_ok)
	print("Réseaux, services et entreprises :")
	for v in VILLES:
		var nom := String(v[0])
		var vid := int(vids[nom])
		var hab := roundi(int(v[3]) * echelle)
		await _aller(float(v[1]), float(v[2]))
		_reseaux(vid, hab)
		if hab > 0:
			for s in SERVICES:
				for i in maxi(1, roundi(float(hab) / float(s[1]))):
					if hab >= int(s[1]) / 3 or String(s[0]) in ["ecole", "boulangerie", "entreprise_btp"]:
						_poser(vid, String(s[0]))
		else:
			_poser(vid, "entreprise_btp")
		for id in ENTREPRISES.get(nom, []):
			_poser(vid, String(id))
	var relies := true
	var n0 := _noeud(int(vids["Bâle"]))
	for nom in vids:
		var n1 := _noeud(int(vids[nom]))
		if n0 < 0 or n1 < 0 or float(prod.route_pts({"n": n0}, {"n": n1}).m) == INF:
			relies = false
			print("    %s n'est pas reliée à Bâle par la route" % nom)
	_check(relies, "toutes les villes reliées par la route")
	_check(prod.gateways().size() >= 1, "%d portes d'import-export au bord de la carte" % prod.gateways().size())
	pop._sync_buildings()
	pop._match_all()
	# Fin de la mise en place : argent compté, chantiers, arrivées, croissance.
	bs.unlimited_money = false
	for k in pays.cles():
		var kk := int(k)
		var v := 0
		if Pays.est_nation(kk):
			v = 10_000_000 if kk == Pays.PAYS else 5_000_000
		else:
			cm.calculer_stats()
			v = 1_000_000 + 300 * int(cm.stats.get(kk, {}).get("hab", 0))
		pays._poser(kk, v)
	BatimentsVie.chantiers = true
	pop.arrivals = true
	zs.growth = true
	for nom in vids:
		pa.activer(int(vids[nom]), true)
	cm.calculer_stats()
	print("  mise en place en %.0f s : %d habitants, %d bâtiments, %d voies, %d entreprises (argent de départ du mode Normal : %s)" % [
		(Time.get_ticks_msec() - t_setup) / 1000.0, pop.persons.size(), bs.buildings.size(), tr.network.edges.size(), prod.sites.size(),
		BuildingSystem.format_money(argent_depart)])

	if OS.get_cmdline_user_args().has("--messages"):
		for n in game.find_children("*", "", true, false):
			if n.has_signal("message") and n != game.hud:
				var nm := String(n.name)
				n.connect("message", func(txt: String) -> void:
					print("    [%s] %s" % [nm, txt]))

	await _aller(0, 0)
	print("La partie tourne (pas de 10 min de jeu) :")
	var noms: Array = vids.keys()
	var entete := ["jour", "habitants", "personnes", "foyers", "batiments", "entreprises", "livraisons", "ms_pas", "ms_pire", "memoire_mo", "noeuds",
		"commerce_villes", "commerce_pays", "douane"]
	for nom in noms:
		entete.append_array(["hab_" + nom, "caisse_" + nom, "chomage_" + nom, "satisf_" + nom])
	for nk in pays.cles_nations():
		entete.append("caisse_pays_" + pays.nom_nation(int(nk)))
	var lignes := [";".join(entete)]
	var pas := 600.0
	var t0 := amb.unix_time
	var jour := 0
	var ms_jour := 0.0
	var ms_pire_jour := 0.0
	var n_jour := 0
	var ms_tot := 0.0
	var ms_max := 0.0
	var n_tot := 0
	var hab0 := pop.persons.size()
	var min_caisse := {}
	var mem_max := 0.0
	var t_boucle := Time.get_ticks_msec()
	# Profil par script si scripts/prof_banc.gd existe (copie du dépôt enveloppée, voir docs/performances.md).
	var prof: Script = load("res://scripts/prof_banc.gd") if ResourceLoader.exists("res://scripts/prof_banc.gd") else null
	if prof != null:
		prof.reset()
	while jour < jours_max:
		amb.unix_time += pas
		zs.grow_step()
		var t := Time.get_ticks_usec()
		await process_frame
		var ms := float(Time.get_ticks_usec() - t) / 1000.0
		ms_jour += ms
		ms_pire_jour = maxf(ms_pire_jour, ms)
		n_jour += 1
		ms_tot += ms
		ms_max = maxf(ms_max, ms)
		n_tot += 1
		for k in pays.cles():
			min_caisse[k] = mini(int(min_caisse.get(k, 1 << 40)), pays.solde(int(k)))
		var j := int((amb.unix_time - t0) / 86400.0)
		if j == jour:
			continue
		jour = j
		cm.calculer_stats()
		var mem := Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
		mem_max = maxf(mem_max, mem)
		var ct := prod.commerce_total(false)
		var hab_tot := 0
		for nom in noms:
			hab_tot += int(cm.stats.get(vids[nom], {}).get("hab", 0))
		var row := [jour, hab_tot, pop.persons.size(), pop.households.size(), bs.buildings.size(), prod.sites.size(), prod.missions.size(),
			"%.1f" % (ms_jour / maxf(n_jour, 1)), "%.0f" % ms_pire_jour, "%.0f" % mem, Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			roundi(float(ct.villes)), roundi(float(ct.pays)), roundi(float(ct.douane))]
		for nom in noms:
			var vid := int(vids[nom])
			var ch := pa.chiffres(vid)
			var sat := float(Objectifs.instance.satisfaction(vid)) if Objectifs.instance != null else -1.0
			row.append_array([int(ch.hab), pays.solde(vid), "%.1f" % float(ch.chomage), "%.0f" % sat])
		for nk in pays.cles_nations():
			row.append(pays.solde(int(nk)))
		lignes.append(";".join(row.map(func(x) -> String: return str(x))))
		if jour % 10 == 0 or jour == 1:
			print("  jour %3d : %6d habitants (%d personnes), %d bâtiments, %d livraisons, pas moyen %.1f ms (pire %.0f), mémoire %.0f Mo | commerce du mois : %s entre villes, %s entre pays, douane %s" % [
				jour, hab_tot, pop.persons.size(), bs.buildings.size(), prod.missions.size(), ms_jour / maxf(n_jour, 1), ms_pire_jour, mem,
				BuildingSystem.format_money(roundi(float(ct.villes))), BuildingSystem.format_money(roundi(float(ct.pays))), BuildingSystem.format_money(roundi(float(ct.douane)))])
			var detail := []
			for nom in noms:
				var vid := int(vids[nom])
				var ch := pa.chiffres(vid)
				detail.append("%s %d hab, %s, chôm %.0f %%, satisf %.0f" % [nom, int(ch.hab), BuildingSystem.format_money(pays.solde(vid)), float(ch.chomage),
					float(Objectifs.instance.satisfaction(vid)) if Objectifs.instance != null else -1.0])
			print("      " + " | ".join(detail))
			var dn := []
			for nk in pays.cles_nations():
				dn.append("%s %s" % [pays.nom_nation(int(nk)), BuildingSystem.format_money(pays.solde(int(nk)))])
			print("      pays : " + " | ".join(dn))
		ms_jour = 0.0
		ms_pire_jour = 0.0
		n_jour = 0
	var duree := (Time.get_ticks_msec() - t_boucle) / 1000.0
	if prof != null:
		prof.rapport(n_tot)
	print("  %d jours de jeu en %.0f s réelles ; pas moyen %.1f ms, pire %.0f ms ; mémoire max %.0f Mo" % [jours_max, duree, ms_tot / maxf(n_tot, 1), ms_max, mem_max])
	if rapport != "":
		var f := FileAccess.open(rapport, FileAccess.WRITE)
		if f != null:
			f.store_string("\n".join(lignes) + "\n")
			print("  rapport : ", rapport)

	_diag_production(prod, pop)
	print("Bilan :")
	cm.calculer_stats()
	var hab_fin := pop.persons.size()
	_check(hab_fin > hab0, "la population grandit (%d → %d)" % [hab0, hab_fin])
	var ct2 := prod.commerce_total(true)
	if float(ct2.villes) <= 0.0:
		ct2 = prod.commerce_total(false)
	_check(float(ct2.villes) > 0.0, "commerce entre villes : %s par mois" % BuildingSystem.format_money(roundi(float(ct2.villes))))
	_check(float(ct2.pays) > 0.0, "commerce entre pays : %s par mois, douane %s" % [BuildingSystem.format_money(roundi(float(ct2.pays))), BuildingSystem.format_money(roundi(float(ct2.douane)))])
	for nom in noms:
		var vid := int(vids[nom])
		var ch := pa.chiffres(vid)
		print("    %-12s %-10s %5d hab | caisse %s (plus bas %s) | chômage %.0f %% | %d écoles, %d élèves sans école | satisfaction %.0f | ventes aux autres villes %s, achats %s" % [nom,
			pays.nom_nation(pays.nation_de(vid)), int(ch.hab), BuildingSystem.format_money(pays.solde(vid)), BuildingSystem.format_money(int(min_caisse.get(vid, 0))),
			float(ch.chomage), pa.compter(vid, "ecole"), int(ch.sans_ecole), float(Objectifs.instance.satisfaction(vid)) if Objectifs.instance != null else -1.0,
			BuildingSystem.format_money(roundi(float(prod.commerce_ville(vid).ventes))), BuildingSystem.format_money(roundi(float(prod.commerce_ville(vid).achats)))])
	for nk in pays.cles_nations():
		var cn := prod.commerce_nation(int(nk))
		print("    %-12s caisse %s (plus bas %s) | exportations %s, importations %s, douane %s" % [pays.nom_nation(int(nk)),
			BuildingSystem.format_money(pays.solde(int(nk))), BuildingSystem.format_money(int(min_caisse.get(nk, 0))),
			BuildingSystem.format_money(roundi(float(cn.ventes))), BuildingSystem.format_money(roundi(float(cn.achats))), BuildingSystem.format_money(roundi(float(cn.douane)))])

	if reel > 0:
		print("Temps réel (1 jour/min), caméra sur Bâle :")
		rig.position = Vector3.ZERO
		amb.set_speed(DayNight.DEFAULT_SPEED)
		await _frames(120)
		if prof != null:
			prof.reset()
		var ims: Array[float] = []
		var last := Time.get_ticks_usec()
		for i in reel:
			await process_frame
			var now := Time.get_ticks_usec()
			ims.append((now - last) / 1000.0)
			last = now
		ims.sort()
		var moy := 0.0
		for x in ims:
			moy += x
		moy /= ims.size()
		print("  image moy %.1f ms (%.0f i/s), méd %.1f, p95 %.1f, pire %.0f ms, %d habitants, %d nœuds" % [moy, 1000.0 / maxf(moy, 0.01), ims[ims.size() / 2],
			ims[int(ims.size() * 0.95)], ims[-1], pop.persons.size(), Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
		if prof != null:
			prof.rapport(reel)
		amb.set_speed(0)

	print("Sauvegarde et chargement :")
	var n_bat := bs.buildings.size()
	var n_pers := pop.persons.size()
	var t1 := Time.get_ticks_msec()
	_check(game.save_game(), "partie sauvegardée (%d ms)" % (Time.get_ticks_msec() - t1))
	var slot := GameStart.slot_id
	var octets := 0
	var dir := SaveGame.DIR.path_join(slot)
	for f in DirAccess.get_files_at(dir):
		octets += FileAccess.get_file_as_bytes(dir.path_join(f)).size()
	print("  taille : %d Ko" % (octets / 1024))
	t1 = Time.get_ticks_msec()
	game.hud.globe_requested.emit()
	await _frames(3)
	globe = current_scene
	globe.load_saved_game(slot)
	game = await _wait_game()
	await _frames(10)
	print("  chargement en %d ms" % (Time.get_ticks_msec() - t1))
	_check(game.buildings.buildings.size() == n_bat, "bâtiments revenus (%d / %d)" % [game.buildings.buildings.size(), n_bat])
	_check(game.population.persons.size() >= n_pers - 20, "habitants revenus (%d / %d)" % [game.population.persons.size(), n_pers])
	_check(game.pays.cles_nations().size() == 3, "les trois pays reviennent")
	SaveGame.delete(slot)
	_fin()


func _fin() -> void:
	var erreurs: Array = _logger.liste.duplicate()
	if not erreurs.is_empty():
		print("Erreurs de script pendant la partie (%d) :" % erreurs.size())
		var vues := {}
		for e in erreurs:
			if not vues.has(e):
				vues[e] = true
				print("  ! ", e)
		ok = false
	print("PARTIE PAYS OK" if ok else "PARTIE PAYS ÉCHEC")
	quit(0 if ok else 1)


## Entreprises : effectif, rendement, stocks et ce qu'elles attendent.
func _diag_production(prod: Production, pop: Population) -> void:
	print("Entreprises :")
	var attentes := {}
	for bid in prod.sites:
		var site: Dictionary = prod.sites[bid]
		if not bs.buildings.has(bid):
			continue
		var t := String(bs.buildings[bid].t)
		var emplois := int(BuildingCatalog.get_type(t).get("emplois", 0))
		var ville := cm.village_de(bid)
		var nom: String = String(cm.villages[ville].nom) if cm.villages.has(ville) else "hors ville"
		var a := String(site.get("attente", ""))
		if a != "":
			attentes[a] = int(attentes.get(a, 0)) + 1
		if String(site.kind) in ["extraction", "transformation", "elevage", "entrepot"]:
			var st := []
			for g in site.st:
				if float(site.st[g]) >= 0.05:
					st.append("%s %.1f t" % [g, float(site.st[g])])
			print("    %-12s %-22s %3d/%3d employés, rendement %.2f, %s | %s" % [nom, t, prod._workers(bid), emplois, prod._rendement(bid),
				", ".join(st) if not st.is_empty() else "stock vide", a if a != "" else String(site.get("status", ""))])
	for a in attentes:
		print("    attente « %s » : %d sites" % [a, int(attentes[a])])
	print("    livraisons en cours %d, portes d'import-export %d" % [prod.missions.size(), prod.gateways().size()])
	var av := Avis.instance
	if av == null:
		return
	print("Satisfaction par thème :")
	var garde := av.ville_vid
	for vid in cm.villages:
		av.examiner(int(vid))
		var sd := av.sondage(true)
		if int(sd.n) == 0:
			continue
		var notes := []
		var pires := []
		for th in sd.themes:
			notes.append("%s %d" % [th, int(sd.themes[th].note)])
			for r in sd.themes[th].raisons:
				pires.append([int(r[1]), String(r[0])])
		pires.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
		var txt := []
		for r in pires.slice(0, 6):
			txt.append("%s (%d)" % [r[1], r[0]])
		print("    %-12s %d/100 | %s" % [String(cm.villages[vid].nom), int(sd.valeur), ", ".join(notes)])
		print("        motifs : %s" % " ; ".join(txt))
	av.examiner(garde)
