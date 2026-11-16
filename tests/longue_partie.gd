extends SceneTree
## Banc de stabilité : une longue partie jouée sans pause (10 heures de jeu
## réel par défaut, au rythme normal de 1 jour par minute), pour trouver les
## fuites de mémoire, les ralentissements qui s'installent et les erreurs qui
## n'arrivent qu'au bout de plusieurs heures.
##
## La ville est fondée près de Bâle, remplie, puis confiée au pilote
## automatique ; le temps tourne à la vitesse par défaut avec de vraies images
## (le moteur fait tout : trafic, habitants, chantiers, sauvegardes
## automatiques toutes les 5 minutes). Toutes les N minutes de jeu on relève :
## images (moyenne, p95, pire), mémoire, objets et nœuds du moteur, nœuds
## orphelins, habitants, bâtiments, véhicules, et la taille de chaque liste et
## dictionnaire des systèmes du jeu (pour repérer celui qui grossit sans
## fin). La caméra se promène pour charger et décharger le relief. Toutes les
## 2 heures : sauvegarde puis rechargement de la partie (une fuite au
## chargement se voit tout de suite).
##
## Usage :
##   godot --headless --path . --fixed-fps 30 --script res://tests/longue_partie.gd -- [--heures 10] [--hab 600]
##       [--echantillon 10] [--recharger 120] [--rapport banc.csv] [--listes listes.csv]
##   --heures N       heures de jeu réel simulées (défaut 10)
##   --echantillon N  minutes entre deux relevés (défaut 10)
##   --recharger N    minutes entre deux sauvegarde + chargement (défaut 120, 0 = jamais)
##   --fixed-fps      images par seconde simulées : 30 = un PC moyen (60 est plus fidèle mais 2× plus long)
## À la fin : verdict sur la mémoire (pente après la première heure), les objets,
## les nœuds orphelins, la vitesse des images (début contre fin) et les erreurs.

const BLOC := 120

var ok := true
var _logger: JournalErreurs
var _bilan: Array[String] = []


class JournalErreurs extends Logger:
	var mutex := Mutex.new()
	var liste: Array = []
	var total := 0

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool,
			error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING or rationale.begins_with("ÉCHEC") or code.begins_with("ÉCHEC"):
			return
		mutex.lock()
		total += 1
		if liste.size() < 500:
			liste.append("%s (%s:%d %s)" % [rationale if rationale != "" else code, file.get_file(), line, function])
		mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass


func _initialize() -> void:
	_logger = JournalErreurs.new()
	OS.add_logger(_logger)
	_run.call_deferred()
	create_timer(20.0 * 3600.0, true, false, true).timeout.connect(func() -> void:
		push_error("ÉCHEC : délai dépassé")
		_fin())


func _check(cond: bool, what: String) -> void:
	if not cond:
		push_error("ÉCHEC : " + what)
		ok = false
		_bilan.append("ÉCHEC " + what)
	else:
		print("  ok  ", what)
		_bilan.append("ok   " + what)


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
	# L'horizon aussi : sinon le relevé de la nature (tourisme, tous les 30 jours) génère
	# des dizaines de tuiles détaillées et coûte 3 s, ce qui n'arrive pas dans le vrai jeu.
	if w.horizon != null and w.horizon.tiles != null:
		w.horizon.tiles.offline_generator = _flat_tile


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


func _reseaux() -> void:
	bs.unlimited_money = true
	for id in ["poste_national", "forage_eau", "station_epuration", "poste_gaz"]:
		pa._poser(vid, id)
	bs.unlimited_money = false


# --- Relevés -----------------------------------------------------------------------

## Taille de chaque liste / dictionnaire des systèmes du jeu (enfants directs de la partie).
func _tailles_listes() -> Dictionary:
	var out := {}
	if not is_instance_valid(game):
		return out
	var noeuds: Array = [game]
	noeuds.append_array(game.get_children())
	for n in noeuds:
		if n.get_script() == null:
			continue
		for p in n.get_property_list():
			if not (int(p.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE):
				continue
			var t := int(p.type)
			if t != TYPE_ARRAY and t != TYPE_DICTIONARY and t < TYPE_PACKED_BYTE_ARRAY:
				continue
			var v: Variant = n.get(p.name)
			if v == null:
				continue
			var nom := "%s.%s" % [n.name, p.name]
			out[nom] = (v as Dictionary).size() if t == TYPE_DICTIONARY else v.size()
	return out


func _vehicules() -> int:
	return tr.traffic.vehicles.size() if tr != null and tr.traffic != null else 0


func _mo(octets: float) -> float:
	return octets / 1048576.0


func _releve(minute: float, ims: PackedFloat32Array, reel_ms: float) -> Dictionary:
	var tri := ims.duplicate()
	tri.sort()
	var moy := 0.0
	for x in tri:
		moy += x
	moy /= maxf(tri.size(), 1)
	cm.calculer_stats()
	return {
		"minute": minute,
		"jour": int((amb.unix_time - _t0_jeu) / 86400.0),
		"ms_moy": moy, "ms_reel": reel_ms / maxf(ims.size(), 1), "ms_p95": tri[int(tri.size() * 0.95)] if tri.size() > 0 else 0.0, "ms_pire": tri[-1] if tri.size() > 0 else 0.0,
		"mem_mo": _mo(OS.get_static_memory_usage()), "mem_pic_mo": _mo(OS.get_static_memory_peak_usage()),
		"objets": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"noeuds": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphelins": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"ressources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"habitants": pop.persons.size(), "batiments": bs.buildings.size(), "vehicules": _vehicules(),
		"argent": int(cm.caisse(vid)) if cm.has_method("caisse") else 0,
		"erreurs": _logger.total,
	}


const COLONNES := ["minute", "jour", "ms_moy", "ms_reel", "ms_p95", "ms_pire", "mem_mo", "mem_pic_mo", "objets", "noeuds", "orphelins",
	"ressources", "habitants", "batiments", "vehicules", "erreurs"]
var _t0_jeu := 0.0
var _debut_ech := 0


func _ligne(r: Dictionary) -> String:
	return ";".join(COLONNES.map(func(c: String) -> String:
		var v: Variant = r.get(c, "")
		return ("%.2f" % v) if typeof(v) == TYPE_FLOAT else str(v)))


## Pente (par heure) des moindres carrés de y en fonction de x (minutes).
static func _pente(xs: Array, ys: Array) -> float:
	var n := xs.size()
	if n < 2:
		return 0.0
	var mx := 0.0
	var my := 0.0
	for i in n:
		mx += float(xs[i])
		my += float(ys[i])
	mx /= n
	my /= n
	var num := 0.0
	var den := 0.0
	for i in n:
		num += (float(xs[i]) - mx) * (float(ys[i]) - my)
		den += (float(xs[i]) - mx) * (float(xs[i]) - mx)
	return num / den * 60.0 if den > 0.0 else 0.0


func _sauver_recharger() -> void:
	var avant_bat := bs.buildings.size()
	var avant_hab := pop.persons.size()
	var ids_bat := bs.buildings.keys()
	var ids_hab := pop.persons.keys()
	if not game.save_game(_slot, "Banc longue partie"):
		_check(false, "sauvegarde : " + String(game.last_error))
		return
	_slot = GameStart.slot_id
	game.hud.globe_requested.emit()
	await _frames(3)
	var globe: Node = current_scene
	globe.load_saved_game(_slot)
	_brancher(await _wait_game())
	await _frames(10)
	if game.villages_panel._dialog.visible:
		game.villages_panel._dialog.hide()
	pa.activer(vid, true)
	amb.set_speed(DayNight.DEFAULT_SPEED)
	_recharges += 1
	# Le temps reprend pendant l'écran de chargement : des habitants peuvent arriver, partir ou
	# mourir et des chantiers s'ouvrir ; on compte seulement ce qui a disparu sans raison.
	var bat_perdus := ids_bat.filter(func(b) -> bool: return not bs.buildings.has(b)).size()
	var hab_perdus := ids_hab.filter(func(p) -> bool: return not pop.persons.has(p)).size()
	print("    rechargement n° %d : %d bâtiments (%d disparus), %d habitants (%d disparus, %+d en tout)" % [_recharges,
		bs.buildings.size(), bat_perdus, pop.persons.size(), hab_perdus, pop.persons.size() - avant_hab])
	if bat_perdus > 2 or hab_perdus > maxi(5, avant_hab / 100):
		_check(false, "rechargement n° %d fidèle (%d bâtiments et %d habitants disparus)" % [_recharges, bat_perdus, hab_perdus])


var _slot := ""
var _recharges := 0


func _run() -> void:
	Creations.persist = false
	Succes.persist = false
	Succes.reinitialiser()
	Partage.persist = false
	PlansSites.persist = false
	var heures := float(_arg("heures", "10"))
	var hab := int(_arg("hab", "600"))
	var ech := float(_arg("echantillon", "10"))
	var recharger := float(_arg("recharger", "120"))
	var rapport := _arg("rapport", "")
	var rapport_listes := _arg("listes", "")
	var fps := Engine.physics_ticks_per_second
	var fixe := 0
	var ca := OS.get_cmdline_args()
	var fi := ca.find("--fixed-fps")
	if fi >= 0 and fi + 1 < ca.size():
		fixe = int(ca[fi + 1])
	if fixe <= 0:
		print("  (sans --fixed-fps, le temps du jeu suit l'horloge réelle : le banc durera vraiment %.0f h)" % heures)
	var r := ReglagesPartie.preset("normal")
	r.tutoriel = false
	ReglagesPartie.prochaine = r
	OptionsJeu.autosave_min = 5

	print("Longue partie près de Bâle (%.1f h de jeu, %d habitants au départ, %s images/s) :" % [heures, hab, str(fixe) if fixe > 0 else "temps réel"])
	change_scene_to_file("res://scenes/globe.tscn")
	await _frames(5)
	var globe: Node = current_scene
	globe.select_place(47.56, 7.59, "Bâle (banc)", true)
	ReglagesPartie.prochaine.tutoriel = false
	globe.start_game()
	_brancher(await _wait_game())
	_check(game != null and game.name == "Terre", "la partie s'ouvre")
	world.set_origin(47.56, 7.59)
	await _relief()
	amb.set_speed(0)
	if game.villages_panel._dialog.visible:
		game.villages_panel._dialog.hide()
	cm.nom_en_attente = "Bâle"
	var mc := bs.place("maison_commune", Vector2i(0, 0), 0)
	vid = cm.village_du_batiment(mc)
	_check(mc >= 0 and vid >= 0, "ville fondée")
	if game.villages_panel._dialog.visible:
		game.villages_panel._dialog.hide()
	bs.unlimited_money = true
	BatimentsVie.chantiers = false
	_remplir(hab)
	bs.unlimited_money = false
	BatimentsVie.chantiers = true
	_reseaux()
	pays._poser(vid, 3_000_000)
	pa.activer(vid, true)
	pop._sync_buildings()
	pop._match_all()
	_check(game.save_game("", "Banc longue partie"), "première sauvegarde")
	_slot = GameStart.slot_id

	print("Partie sans pause :")
	amb.set_speed(DayNight.DEFAULT_SPEED)
	_t0_jeu = amb.unix_time
	await _frames(60)
	var lignes: Array[String] = [";".join(COLONNES)]
	var releves: Array[Dictionary] = []
	var listes: Array[Dictionary] = []
	var csv: FileAccess = FileAccess.open(rapport, FileAccess.WRITE) if rapport != "" else null
	if csv != null:
		csv.store_line(lignes[0])
		csv.flush()
	var duree_min := heures * 60.0
	var minute := 0.0
	var prochain_releve := ech
	var prochain_recharge := recharger if recharger > 0.0 else INF
	var ims := PackedFloat32Array()
	var last := Time.get_ticks_usec()
	var debut_reel := Time.get_ticks_msec()
	_debut_ech = debut_reel
	var rng := RandomNumberGenerator.new()
	rng.seed = 1800
	var lent := 0
	while minute < duree_min:
		await process_frame
		var now := Time.get_ticks_usec()
		var ms := (now - last) / 1000.0
		last = now
		ims.append(ms)
		if ms > 2000.0:
			lent += 1
			if lent <= 20:
				print("    image de %.1f s à la minute %.1f" % [ms / 1000.0, minute])
		minute += (1.0 / float(fixe)) / 60.0 if fixe > 0 else ms / 60000.0
		if minute >= prochain_releve:
			prochain_releve += ech
			var rel := _releve(minute, ims, float(Time.get_ticks_msec() - _debut_ech))
			_debut_ech = Time.get_ticks_msec()
			ims = PackedFloat32Array()
			releves.append(rel)
			listes.append(_tailles_listes())
			lignes.append(_ligne(rel))
			if csv != null:
				csv.store_line(lignes[-1])
				csv.flush()
			print("  %5.0f min · jour %3d · %4d hab · %4d bât · %3d véh · image %.1f ms (réel %.1f, p95 %.1f, pire %.0f) · %.0f Mo · %d objets · %d nœuds · %d orphelins · %d erreurs · %.0f min réelles" % [
				minute, rel.jour, rel.habitants, rel.batiments, rel.vehicules, rel.ms_moy, rel.ms_reel, rel.ms_p95, rel.ms_pire, rel.mem_mo,
				rel.objets, rel.noeuds, rel.orphelins, rel.erreurs, (Time.get_ticks_msec() - debut_reel) / 60000.0])
			# La caméra part voir ailleurs (relief chargé / déchargé), puis revient.
			var ang := rng.randf() * TAU
			var dist := rng.randf_range(0.0, 2500.0) if releves.size() % 3 != 0 else 0.0
			rig.position = Vector3(cos(ang) * dist, rig.position.y, sin(ang) * dist)
			last = Time.get_ticks_usec()
		if minute >= prochain_recharge and minute < duree_min - ech:
			prochain_recharge += recharger
			await _sauver_recharger()
			last = Time.get_ticks_usec()

	amb.set_speed(0)
	print("Bilan :")
	_verdict(releves, listes)
	if rapport_listes != "" and not listes.is_empty():
		var noms := {}
		for l in listes:
			for k in l:
				noms[k] = true
		var cles := noms.keys()
		cles.sort()
		var f := FileAccess.open(rapport_listes, FileAccess.WRITE)
		if f != null:
			f.store_line("liste;" + ";".join(releves.map(func(x: Dictionary) -> String: return "%.0f" % float(x.minute))))
			for k in cles:
				f.store_line(k + ";" + ";".join(listes.map(func(l: Dictionary) -> String: return str(l.get(k, "")))))
	if _slot != "":
		SaveGame.delete(_slot)
	_fin()


func _verdict(rel: Array[Dictionary], listes: Array[Dictionary]) -> void:
	if rel.size() < 4:
		_check(false, "assez de relevés (%d)" % rel.size())
		return
	# On laisse passer la première heure (ville qui démarre, caches qui se remplissent).
	var i0 := 0
	while i0 < rel.size() - 3 and float(rel[i0].minute) < 60.0:
		i0 += 1
	var xs := []
	var mem := []
	var obj := []
	var orph := []
	var par_hab := []
	for i in range(i0, rel.size()):
		xs.append(rel[i].minute)
		mem.append(rel[i].mem_mo)
		obj.append(rel[i].objets)
		orph.append(rel[i].orphelins)
		# Mémoire par « contenu » (habitants + bâtiments + véhicules) : grossir avec la ville est normal.
		par_hab.append(float(rel[i].mem_mo) / maxf(float(rel[i].habitants + rel[i].batiments * 4 + rel[i].vehicules), 1.0) * 1000.0)
	var p_mem := _pente(xs, mem)
	var p_obj := _pente(xs, obj)
	var p_orph := _pente(xs, orph)
	var p_par := _pente(xs, par_hab)
	var a: Dictionary = rel[i0]
	var z: Dictionary = rel[-1]
	print("  mémoire %.0f → %.0f Mo (pic %.0f), pente %.1f Mo/h ; par contenu %.2f → %.2f Ko, pente %.3f Ko/h" % [a.mem_mo, z.mem_mo,
		z.mem_pic_mo, p_mem, par_hab[0], par_hab[-1], p_par])
	print("  objets %d → %d (pente %.0f/h), nœuds %d → %d, orphelins %d → %d" % [a.objets, z.objets, p_obj, a.noeuds, z.noeuds, a.orphelins, z.orphelins])
	print("  habitants %d → %d, bâtiments %d → %d, véhicules %d → %d" % [a.habitants, z.habitants, a.batiments, z.batiments, a.vehicules, z.vehicules])
	# Ralentissement : dernières heures contre deuxième heure, rapporté au nombre d'habitants.
	var tiers := maxi(1, (rel.size() - i0) / 3)
	var debut := 0.0
	var fin := 0.0
	for i in range(i0, i0 + tiers):
		debut += float(rel[i].ms_moy)
	for i in range(rel.size() - tiers, rel.size()):
		fin += float(rel[i].ms_moy)
	debut /= tiers
	fin /= tiers
	var pire := 0.0
	for r in rel:
		pire = maxf(pire, float(r.ms_pire))
	print("  image moyenne %.1f ms au début, %.1f ms à la fin ; pire image %.0f ms" % [debut, fin, pire])
	_check(int(z.orphelins) <= int(a.orphelins) + 50, "pas de nœuds orphelins qui s'accumulent (%d → %d)" % [a.orphelins, z.orphelins])
	_check(p_par < maxf(0.05 * float(par_hab[0]), 0.05), "la mémoire suit la taille de la ville, sans fuite (%.3f Ko par élément et par heure)" % p_par)
	_check(fin < maxf(debut * 2.0, debut + 8.0) * maxf(1.0, float(z.habitants) / maxf(float(a.habitants), 1.0)),
		"les images ne ralentissent pas plus que la ville ne grandit (%.1f → %.1f ms)" % [debut, fin])
	# Listes qui grossissent beaucoup plus vite que la ville.
	if listes.size() >= 3:
		var la: Dictionary = listes[i0]
		var lz: Dictionary = listes[-1]
		var croissance := maxf(float(z.habitants + z.batiments) / maxf(float(a.habitants + a.batiments), 1.0), 1.0)
		var suspectes := []
		for k in lz:
			var v0 := float(la.get(k, 0))
			var v1 := float(lz[k])
			if v1 >= 2000.0 and v1 > maxf(v0, 50.0) * croissance * 3.0:
				suspectes.append("%s %d → %d" % [k, int(v0), int(v1)])
		if not suspectes.is_empty():
			print("  listes qui grossissent plus vite que la ville (×%.1f) :" % croissance)
			for s in suspectes:
				print("    - ", s)
		_check(suspectes.is_empty(), "aucune liste ne grossit sans fin (%d suspecte(s))" % suspectes.size())


func _fin() -> void:
	var erreurs: Array = _logger.liste.duplicate()
	if not erreurs.is_empty():
		var vues := {}
		for e in erreurs:
			vues[e] = int(vues.get(e, 0)) + 1
		print("Erreurs de script pendant la partie (%d, %d différentes) :" % [_logger.total, vues.size()])
		for e in vues:
			print("  ! ×%d %s" % [vues[e], e])
		ok = false
	for b in _bilan:
		print("  ", b)
	print("LONGUE PARTIE OK" if ok else "LONGUE PARTIE ÉCHEC")
	quit(0 if ok else 1)
