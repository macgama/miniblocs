extends SceneTree
## Longue partie automatisée qui fait jouer ensemble les nouveautés du
## 15 novembre 2026 : époques (départ en 1800), gazette du matin, commerce
## mondial (cours, partenaires, crise), succès, time-lapse et mode photo,
## plans de site (partage), puis un scénario.
##
## La ville est fondée près de Bâle en 1800, remplie un peu, puis passe en
## pilote automatique. On joue plusieurs périodes de quelques jours en
## sautant les années (1800, 1850, 1890, 1925, 1960, 2000) : à chaque période,
## pas d'anachronisme (bâtiments posés, véhicules en circulation), une gazette
## par jour avec le bon titre d'époque, des services publics d'époque bâtis
## par le pilote, le marché qui bouge. À la fin : plan de site, photo,
## time-lapse, sauvegarde et chargement, temps réel, puis un scénario joué
## quelques jours. Toutes les erreurs de script sont relevées.
##
## Usage :
##   godot --headless --path . --script res://tests/nouveautes_partie.gd -- [--jours 6] [--hab 600] [--reel 600] [--rapport f.csv]
##   --jours N  jours joués par période (défaut 6)
##   --hab N    habitants de départ (défaut 600)
##   --reel N   images mesurées en temps réel à la fin (0 : pas de mesure)

const BLOC := 120
const PERIODES := [1800, 1850, 1890, 1925, 1960, 2000]

var ok := true
var _logger: JournalErreurs
var _bilan: Array[String] = []


class JournalErreurs extends Logger:
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
	_logger = JournalErreurs.new()
	OS.add_logger(_logger)
	_run.call_deferred()
	create_timer(3.0 * 3600.0).timeout.connect(func() -> void:
		push_error("ÉCHEC : délai dépassé")
		_fin())


func _check(cond: bool, what: String) -> void:
	if not cond:
		push_error("ÉCHEC : " + what)
		ok = false
		_bilan.append("ÉCHEC " + what)
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
var rig: Node3D
var vid := -1


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


func _relief() -> void:
	for i in 600:
		await process_frame
		if i >= 60 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break


func _brancher(g: Node) -> void:
	game = g
	world = game.world
	_offline(game)
	world.view_radius_override = 900.0
	rig = game.get_node("CameraRig")
	bs = game.buildings
	tr = game.transport
	zs = game.zones
	amb = game.ambiance
	pop = game.population
	cm = game.communes
	pays = game.pays
	pa = game.pilote


func _h(x: float, z: float) -> float:
	var h := world.cell_height(Vector2i(roundi(x), roundi(z)))
	return 260.0 if is_nan(h) else h


func _route(a: Vector2, b: Vector2, voie := "rue") -> bool:
	var r: Dictionary = tr.build_segment(voie, Vector3(a.x, _h(a.x, a.y), a.y), Vector3(b.x, _h(b.x, b.y), b.y))
	if not r.get("ok", false):
		print("    voie refusée ", a, " -> ", b, " : ", r.get("reason", "?"))
	return bool(r.get("ok", false))


func _logements() -> int:
	cm.calculer_stats()
	return int(cm.stats.get(vid, {}).get("logements", 0))


## Grille de rues et zonage autour de la mairie, puis des foyers emménagent.
func _remplir(habitants: int) -> void:
	var n := 3
	var faites := {}
	while _logements() * 2.3 < habitants * 1.15 and n <= 9:
		cm._etendre(vid, BLOC * n * 0.75 + 200.0)
		var span := BLOC * n / 2.0
		for k in n + 1:
			var v := -span + k * BLOC
			_route(Vector2(v, -span), Vector2(v, span))
			_route(Vector2(-span, v), Vector2(span, v))
		for k in n:
			for l in n:
				var key := Vector2i(k - n / 2, l - n / 2)
				if key == Vector2i.ZERO or faites.has(key):
					continue
				faites[key] = true
				var kinds := ["R", "R", "R", "C", "I", "R"]
				var kind: String = kinds[absi(key.x * 7 + key.y * 3) % kinds.size()]
				zs.add_zone(kind, Rect2i(int(-span + k * BLOC + 6), int(-span + l * BLOC + 6), BLOC - 12, BLOC - 12))
		for i in n * n * 40:
			zs.grow_step()
		n += 2
	pop._sync_buildings()
	var homes := []
	for bid in pop.known:
		if int(pop.known[bid].log) > 0 and cm.village_de(bid) == vid:
			homes.append(bid)
	homes.shuffle()
	var guard := 0
	while pop.persons.size() < habitants and guard < 20000 and not homes.is_empty():
		guard += 1
		pop.spawn_household(homes[guard % homes.size()])
	print("  grille %d × %d, %d logements, %d habitants" % [n - 2, n - 2, _logements(), pop.persons.size()])


## Bâtiments posés qui n'existaient pas encore à l'année en cours.
func _anachronismes(depuis: Dictionary) -> Array:
	var out := []
	for bid in bs.buildings:
		if depuis.has(bid):
			continue
		var t := String(bs.buildings[bid].t)
		if not Epoques.batiment_disponible(t):
			out.append("%s (%d)" % [t, Epoques.annee_batiment(t)])
	return out


## Modèles de véhicules en circulation trop modernes pour l'année.
func _vehicules_anachroniques() -> Dictionary:
	var out := {}
	if tr.traffic == null:
		return out
	for v in tr.traffic.vehicles:
		var m := String(v.get("model", ""))
		if m != "" and not Epoques.vehicule_disponible(m):
			out[m] = int(out.get(m, 0)) + 1
	return out


## Services publics présents dans la ville, par rôle (base).
func _services() -> Dictionary:
	var out := {}
	for bid in bs.buildings:
		if cm.village_de(bid) != vid:
			continue
		var base := BuildingCatalog.base_of(String(bs.buildings[bid].t))
		if base in ["ecole", "hopital", "pompiers", "police"]:
			out[base] = int(out.get(base, 0)) + 1
	return out


## Ce que ferait le joueur à chaque époque : les réseaux que les habitants
## attendent (le pilote automatique ne pose pas de réseaux), avec ce qui existe.
const RESEAUX := {"elec": ["poste_national", "centrale_charbon_locale"], "eau": ["forage_eau", "captage_eau"],
	"egout": ["station_epuration_locale", "station_epuration", "exutoire_egout"], "gaz": ["poste_gaz"]}
var _reseaux_faits := {}


func _reseaux() -> void:
	bs.unlimited_money = true
	for res in RESEAUX:
		if _reseaux_faits.has(res) or not Epoques.attendu(res):
			continue
		for id in RESEAUX[res]:
			if Epoques.batiment_disponible(id) and pa._poser(vid, id) >= 0:
				_reseaux_faits[res] = id
				print("    réseau « %s » : %s posé" % [res, id])
				break
	bs.unlimited_money = false


func _jouer(jours: int, stats: Dictionary) -> void:
	var pas := 600.0
	var t0 := amb.unix_time
	var jour := 0
	while jour < jours:
		amb.unix_time += pas
		zs.grow_step()
		var t := Time.get_ticks_usec()
		await process_frame
		var ms := float(Time.get_ticks_usec() - t) / 1000.0
		stats.n = int(stats.get("n", 0)) + 1
		stats.ms = float(stats.get("ms", 0.0)) + ms
		stats.pire = maxf(float(stats.get("pire", 0.0)), ms)
		jour = int((amb.unix_time - t0) / 86400.0)


func _run() -> void:
	Creations.persist = false
	Succes.persist = false
	Succes.reinitialiser()
	Partage.persist = false
	PlansSites.persist = false
	var jours := int(_arg("jours", "6"))
	var hab := int(_arg("hab", "600"))
	var reel := int(_arg("reel", "600"))
	var rapport := _arg("rapport", "")
	var r := ReglagesPartie.preset("normal")
	r.deblocage = "tout"  # (ce test ne porte pas sur l'arbre de progression)
	var periodes: Array = Array(_arg("periodes", ",".join(PERIODES.map(func(x) -> String: return str(x)))).split(",")).map(func(x) -> int: return int(x))
	r.annee_depart = periodes[0]
	r.rythme_histoire = 25.0
	r.tutoriel = false
	ReglagesPartie.prochaine = r

	print("Partie historique près de Bâle, départ en 1800 :")
	change_scene_to_file("res://scenes/globe.tscn")
	await _frames(5)
	var globe: Node = current_scene
	globe.select_place(47.56, 7.59, "Bâle (test)", true)
	ReglagesPartie.prochaine.tutoriel = false
	globe.start_game()
	_brancher(await _wait_game())
	_check(game != null and game.name == "Terre", "la partie s'ouvre")
	world.set_origin(47.56, 7.59)
	await _relief()
	_check(Epoques.actif() and Epoques.annee() == 1800, "nous sommes en %d" % Epoques.annee())
	_check(amb.local_datetime().year == 1800, "le calendrier affiche 1800")
	amb.set_speed(0)
	if game.villages_panel._dialog.visible:
		game.villages_panel._dialog.hide()

	print("Fondation et premiers habitants :")
	cm.nom_en_attente = "Bâle"
	var mc := bs.place("maison_commune", Vector2i(0, 0), 0)
	vid = cm.village_du_batiment(mc)
	_check(mc >= 0 and vid >= 0, "Bâle fondée")
	if game.villages_panel._dialog.visible:
		game.villages_panel._dialog.hide()
	await _frames(5)
	_check(game.timelapse.cameras.size() >= 1, "caméra de time-lapse posée à la fondation")
	var avant := {}
	for bid in bs.buildings:
		avant[bid] = true
	bs.unlimited_money = true
	BatimentsVie.chantiers = false
	_remplir(hab)
	bs.unlimited_money = false
	BatimentsVie.chantiers = true
	var ana := _anachronismes({})
	_check(ana.is_empty(), "zonage de 1800 : aucun bâtiment trop moderne%s" % ("" if ana.is_empty() else " (" + ", ".join(ana.slice(0, 8)) + ")"))
	pays._poser(vid, 3_000_000)
	pa.activer(vid, true)
	pop._sync_buildings()
	pop._match_all()

	var ligne_csv := ["annee;jours;habitants;batiments;editions;titre;ecole;hopital;pompiers;police;succes;ms_moy;ms_pire;anachronismes;vehicules_anachro"]
	var cm_mond: CommerceMondial = game.commerce_mondial
	var j0: Journal = game.journal
	var stats_tot := {}
	for annee in periodes:
		print("Période %d :" % annee)
		Epoques.aller_a(annee)
		_check(Epoques.annee() == annee, "année réglée : %d" % Epoques.annee())
		var deja := {}
		for bid in bs.buildings:
			deja[bid] = true
		var ed0: int = j0.numero
		var st := {}
		_reseaux()
		if periodes.size() > 1 and annee == periodes[1]:
			cm_mond.declencher_crise("krach")
		await _jouer(jours, st)
		for k in st:
			stats_tot[k] = (maxf(float(stats_tot.get(k, 0.0)), float(st[k])) if k == "pire" else float(stats_tot.get(k, 0.0)) + float(st[k]))
		var a := Epoques.annee()
		cm.calculer_stats()
		var h := int(cm.stats.get(vid, {}).get("hab", 0))
		var eds: int = j0.numero - ed0
		var ed: Dictionary = j0.derniere()
		var ep_attendue := String(JournalEpoques.de_annee(a).id)
		_check(eds >= jours - 1, "%d gazettes en %d jours" % [eds, jours])
		_check(not ed.is_empty() and int(ed.an) == a and String(ed.ep) == ep_attendue,
			"gazette de l'époque : « %s » datée de %s" % [Journal.titre_de(ed) if not ed.is_empty() else "?", str(ed.get("an", "?"))])
		var ana2 := _anachronismes(deja)
		_check(ana2.is_empty(), "rien de trop moderne bâti en %d%s" % [a, "" if ana2.is_empty() else " : " + ", ".join(ana2.slice(0, 8))])
		var va := _vehicules_anachroniques()
		_check(va.is_empty(), "aucun véhicule trop moderne en circulation%s" % ("" if va.is_empty() else " : " + str(va)))
		var sv := _services()
		var chant := bs.buildings.keys().filter(func(bid) -> bool: return bs.en_chantier(bid)).size()
		print("    %d enfants sans école, %d chantiers en cours" % [int(pa.chiffres(vid).sans_ecole), chant])
		print("    %d habitants (%d personnes), %d bâtiments, services %s, succès %d/%d, pas moyen %.1f ms (pire %.0f)" % [h, pop.persons.size(), bs.buildings.size(), str(sv),
			Succes.nombre(), Succes.total(), float(st.ms) / maxf(float(st.n), 1.0), float(st.pire)])
		ligne_csv.append(";".join([a, jours, h, bs.buildings.size(), eds, Journal.titre_de(ed), sv.get("ecole", 0), sv.get("hopital", 0),
			sv.get("pompiers", 0), sv.get("police", 0), Succes.nombre(), "%.1f" % (float(st.ms) / maxf(float(st.n), 1.0)), "%.0f" % float(st.pire),
			ana2.size(), va.size()].map(func(x) -> String: return str(x))))
		if annee == 1800:
			_check(h >= hab * 0.8, "la ville vit en 1800 (%d habitants)" % h)
		if annee >= 1850:
			_check(int(sv.get("ecole", 0)) >= 1, "le pilote a bâti une école d'époque (%s)" % str(sv))
		if annee >= 1890:
			_check(int(sv.get("pompiers", 0)) >= 1 and int(sv.get("police", 0)) >= 1, "pompiers et gendarmes d'époque (%s)" % str(sv))

	print("Commerce mondial :")
	var varie := 0
	for g in cm_mond.historique:
		var hst: Array = cm_mond.historique[g]
		if hst.size() >= 2 and absf(float(hst[-1]) - float(hst[0])) > 0.001:
			varie += 1
	_check(varie >= 5, "les cours bougent (%d marchandises)" % varie)
	_check(cm_mond.partenaires.size() >= 3, "%d villes partenaires : %s" % [cm_mond.partenaires.size(),
		", ".join(cm_mond.partenaires.values().map(func(p: Dictionary) -> String: return String(p.nom)))])
	_check(not cm_mond.crises_passees.is_empty() or not cm_mond.crise.is_empty(), "une crise a eu lieu")
	if not cm_mond.offres.is_empty():
		var res := cm_mond.signer(cm_mond.offres[0], vid)
		print("    offre signée : ", res if res != "" else "(accepté)")

	print("Succès :")
	_check(Succes.nombre() >= 1, "%d succès débloqués" % Succes.nombre())

	print("Plan de site, photo, time-lapse :")
	var ctx: Dictionary = game.partage_panel.contexte()
	if ctx.is_empty():
		ctx = {"bs": bs, "world": world}
	var cap := PlansSites.capture(ctx, Rect2i(-180, -180, 360, 360), "Bâle 2000")
	_check(bool(cap.get("ok", false)), "plan de site du centre : %s" % String(cap.get("resume", cap.get("reason", "?"))))
	if bool(cap.get("ok", false)):
		var pk := Partage.empaqueter("site", String(cap.id), "Bâle 2000")
		_check(bool(pk.get("ok", true)) and not pk.is_empty(), "plan empaqueté pour le partage")
		Epoques.aller_a(1800)
		var plan := PlansSites.get_plan(String(cap.id))
		var pose := PlansSites.poser(plan, Vector2i(2000, 2000), 0, ctx)
		var ana3 := []
		for b in plan.get("batiments", []):
			if not Epoques.batiment_disponible(String(b.t)):
				ana3.append(String(b.t))
		print("    plan de 2000 posé en 1800 : %d posés, %d refusés (%d modèles trop modernes dans le plan)" % [int(pose.get("poses", 0)), int(pose.get("refus", 0)), ana3.size()])
		_check(ana3.is_empty() or int(pose.get("poses", 0)) <= plan.get("batiments", []).size() - ana3.size(), "un plan moderne ne pose rien de trop moderne en 1800")
		Epoques.aller_a(2000)
	game.mode_photo.entrer()
	await _frames(3)
	var img: Image = game.mode_photo.rendre(Vector2i(640, 360))
	print("    photo rendue : ", "oui" if img != null else "non (pas de rendu en headless)")
	game.mode_photo.quitter()
	await _frames(3)
	_check(not get_root().get_tree().paused, "le mode photo rend la main")

	print("Sauvegarde et chargement :")
	var n_bat := bs.buildings.size()
	var types_av := {}
	for bid in bs.buildings:
		types_av[bid] = String(bs.buildings[bid].t) + (" (chantier)" if bs.buildings[bid].get("chantier", false) else "")
	var annee_av := Epoques.annee()
	var num_av: int = game.journal.numero
	var accords_av: int = cm_mond.accords.size()
	_check(game.save_game(), "partie sauvegardée")
	var slot := GameStart.slot_id
	game.hud.globe_requested.emit()
	await _frames(3)
	globe = current_scene
	globe.load_saved_game(slot)
	_brancher(await _wait_game())
	await _frames(10)
	var perdus := types_av.keys().filter(func(bid) -> bool: return not bs.buildings.has(bid))
	# Le pilote peut lancer un chantier juste après le chargement : seuls les manquants comptent.
	_check(perdus.is_empty(), "bâtiments revenus (%d / %d)" % [bs.buildings.size(), n_bat])
	for bid in bs.buildings:
		if not types_av.has(bid):
			print("    en plus après chargement : %d %s %s" % [bid, String(bs.buildings[bid].t), str(bs.buildings[bid].get("chantier", false))])
	for bid in types_av:
		if not bs.buildings.has(bid):
			print("    perdu au chargement : %d %s" % [bid, types_av[bid]])
	_check(Epoques.actif() and Epoques.annee() == annee_av, "l'année revient : %d (avant %d)" % [Epoques.annee(), annee_av])
	_check(game.journal.numero == num_av, "la gazette garde ses numéros (%d)" % game.journal.numero)
	_check(game.commerce_mondial.accords.size() == accords_av, "les accords commerciaux reviennent (%d)" % accords_av)

	if reel > 0:
		print("Temps réel (1 jour/min) :")
		rig.position = Vector3.ZERO
		amb.set_speed(DayNight.DEFAULT_SPEED)
		await _frames(120)
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
		print("  image moy %.1f ms, méd %.1f, p95 %.1f, pire %.0f ms, %d habitants" % [moy, ims[ims.size() / 2], ims[int(ims.size() * 0.95)], ims[-1], pop.persons.size()])
		_bilan.append("temps réel : moy %.1f ms, p95 %.1f, pire %.0f" % [moy, ims[int(ims.size() * 0.95)], ims[-1]])
		amb.set_speed(0)
	SaveGame.delete(slot)

	print("Scénario « course au bourg » :")
	game.hud.globe_requested.emit()
	await _frames(3)
	Scenarios.preparer("course_bourg")
	change_scene_to_file(Scenarios.TERRE)
	_brancher(await _wait_game())
	await _relief()
	await _frames(30)
	var sc: ScenarioPartie = game.scenario
	_check(sc != null and sc.en_cours(), "le scénario démarre")
	_check(not Epoques.actif(), "le scénario se joue à l'époque actuelle")
	if game.villages_panel._dialog.visible:
		game.villages_panel._dialog.hide()
	cm.nom_en_attente = "Bourg"
	var mc2 := bs.place("maison_commune", Vector2i(0, 0), 0)
	vid = cm.village_du_batiment(mc2)
	_check(mc2 >= 0, "bourg fondé")
	if game.villages_panel._dialog.visible:
		game.villages_panel._dialog.hide()
	pa.activer(vid, true)
	var st2 := {}
	await _jouer(5, st2)
	_check(sc.jour() >= 4, "le scénario avance (jour %d / %d)" % [sc.jour(), sc.jours_max()])
	_check(game.journal.numero >= 3, "la gazette paraît pendant le scénario (%d)" % game.journal.numero)
	print("    progression : ", ", ".join((sc.donnees().objectifs as Array).map(func(o: Dictionary) -> String: return sc.progres(o))))

	print("Bilan :")
	print("  %d périodes, pas moyen %.1f ms, pire %.0f ms" % [periodes.size(), float(stats_tot.get("ms", 0.0)) / maxf(float(stats_tot.get("n", 1)), 1.0), float(stats_tot.get("pire", 0.0))])
	for l in ligne_csv:
		print("  ", l)
	if rapport != "":
		var f := FileAccess.open(rapport, FileAccess.WRITE)
		if f != null:
			f.store_string("\n".join(ligne_csv) + "\n")
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
	for b in _bilan:
		print("  ", b)
	print("NOUVEAUTÉS PARTIE OK" if ok else "NOUVEAUTÉS PARTIE ÉCHEC")
	quit(0 if ok else 1)
