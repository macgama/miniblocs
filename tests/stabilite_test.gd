extends SceneTree
## Stabilité (rapide, ~2 min) : sauvegardes automatiques tournantes, rapport de
## plantage local, aucune fuite de nœuds en rechargeant une partie, aucune
## erreur de téléchargement hors ligne.
##   godot --headless --path . --script res://tests/stabilite_test.gd
## Les sauvegardes automatiques et les rapports déjà présents sont mis de côté
## puis remis en place à la fin.

var ok := true
var _erreurs: Capteur


class Capteur extends Logger:
	var mutex := Mutex.new()
	var liste: Array[String] = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _e: bool, error_type: int,
			_bt: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING or (rationale + code).contains("ÉCHEC") or (rationale + code).contains("TEST_EXPRÈS"):
			return
		mutex.lock()
		liste.append("%s (%s:%d %s)" % [rationale if rationale != "" else code, file.get_file(), line, function])
		mutex.unlock()

	func _log_message(_m: String, _e: bool) -> void:
		pass


func _initialize() -> void:
	_erreurs = Capteur.new()
	OS.add_logger(_erreurs)
	_run.call_deferred()
	create_timer(600.0).timeout.connect(func() -> void:
		_check(false, "délai dépassé")
		_fin())


func _check(cond: bool, what: String) -> void:
	if cond:
		print("  ok  ", what)
	else:
		push_error("ÉCHEC : " + what)
		ok = false


func _frames(n: int) -> void:
	for i in n:
		await process_frame


# --- Mise de côté des fichiers du joueur ------------------------------------------

const COTE := "-banc-de-cote"


func _mettre_de_cote() -> void:
	for s in SaveGame.autosave_slots():
		var d := SaveGame.DIR.path_join(s)
		if DirAccess.dir_exists_absolute(d):
			DirAccess.rename_absolute(d, d + COTE)
	if DirAccess.dir_exists_absolute(JournalPlantage.DIR):
		DirAccess.rename_absolute(JournalPlantage.DIR, JournalPlantage.DIR + COTE)


func _effacer_dossier(d: String) -> void:
	var da := DirAccess.open(d)
	if da == null:
		return
	for f in da.get_files():
		DirAccess.remove_absolute(d.path_join(f))
	DirAccess.remove_absolute(d)


func _remettre() -> void:
	for s in SaveGame.autosave_slots():
		SaveGame.delete(s)
		var d := SaveGame.DIR.path_join(s)
		if DirAccess.dir_exists_absolute(d + COTE):
			DirAccess.rename_absolute(d + COTE, d)
	_effacer_dossier(JournalPlantage.DIR)
	if DirAccess.dir_exists_absolute(JournalPlantage.DIR + COTE):
		DirAccess.rename_absolute(JournalPlantage.DIR + COTE, JournalPlantage.DIR)


# --- Tests --------------------------------------------------------------------------

func _rotation() -> void:
	print("Sauvegardes automatiques tournantes :")
	var ecrits: Array[String] = []
	for i in 5:
		var s := SaveGame.prochain_autosave()
		ecrits.append(s)
		var err := SaveGame.write(s, {"nom": "auto %d" % i}, {"terrain": {"n": i}})
		_check(err == "", "sauvegarde automatique n° %d écrite dans %s" % [i + 1, s])
		OS.delay_msec(5)
	_check(ecrits.slice(0, 3) == SaveGame.autosave_slots(), "les 3 premières remplissent les 3 emplacements (%s)" % ", ".join(ecrits))
	_check(ecrits[3] == ecrits[0] and ecrits[4] == ecrits[1], "les suivantes remplacent la plus ancienne (%s, %s)" % [ecrits[3], ecrits[4]])
	var der := SaveGame.derniere_autosave()
	_check(String(der.get("id", "")) == ecrits[4] and String(der.get("nom", "")) == "auto 4", "la plus récente est retrouvée (%s)" % String(der.get("nom", "?")))
	# Une sauvegarde abîmée en cours d'écriture ne gâche pas les autres.
	var fiche := SaveGame.DIR.path_join(ecrits[4]).path_join(SaveGame.MANIFEST)
	var f := FileAccess.open(fiche, FileAccess.WRITE)
	f.store_string("{ coupure de courant")
	f.close()
	der = SaveGame.derniere_autosave()
	_check(String(der.get("nom", "")) == "auto 3", "fiche abîmée : on reprend la précédente (%s)" % String(der.get("nom", "?")))
	_check(SaveGame.prochain_autosave() == ecrits[4], "l'emplacement abîmé est le prochain réécrit")
	var liste := SaveGame.list_saves().filter(func(m: Dictionary) -> bool: return SaveGame.est_autosave(String(m.id)))
	_check(liste.size() == 2, "la liste des parties montre les sauvegardes automatiques lisibles (%d)" % liste.size())
	for s in SaveGame.autosave_slots():
		SaveGame.delete(s)


func _rapport() -> void:
	print("Rapport de plantage :")
	DirAccess.make_dir_recursive_absolute(JournalPlantage.DIR)
	# Une session qui s'est arrêtée net : sa marque est restée.
	var marque := {"version": "0.1 test", "systeme": "Windows 11", "maj": 1794000000, "duree_min": 312.5, "scene": "Terre",
		"memoire_mo": 1830.2, "partie": {"nom": "Bâle", "habitants": 5400, "date_jeu": "03/04/2031 08h15"},
		"erreurs": ["[12:00:00] Erreur de script : Invalid access to property 'x'\n    à res://scripts/x.gd:12 (f)"], "erreurs_total": 3}
	var f := FileAccess.open(JournalPlantage.MARQUE, FileAccess.WRITE)
	f.store_string(JSON.stringify(marque))
	f.close()
	var chemin := JournalPlantage.verifier_session_precedente()
	_check(chemin != "" and FileAccess.file_exists(chemin), "un rapport est écrit au lancement suivant (%s)" % chemin.get_file())
	_check(not FileAccess.file_exists(JournalPlantage.MARQUE), "la marque de session est effacée")
	var txt := FileAccess.get_file_as_string(chemin)
	_check(txt.contains("rien n'a été envoyé") and txt.contains("Bâle") and txt.contains("5400") and txt.contains("Invalid access")
		and txt.contains("1830.2"), "le rapport donne la partie, la mémoire et les erreurs")
	_check(JournalPlantage.verifier_session_precedente() == "", "fermeture normale : aucun rapport")
	# On ne garde que les 10 derniers.
	for i in 14:
		var g := FileAccess.open(JournalPlantage.DIR.path_join("plantage-2020010%d-0000%02d.txt" % [i % 9 + 1, i]), FileAccess.WRITE)
		g.store_string("vieux")
		g.close()
	JournalPlantage.nettoyer()
	_check(JournalPlantage.rapports().size() == JournalPlantage.GARDER, "seuls les %d rapports les plus récents restent (%d)" % [JournalPlantage.GARDER, JournalPlantage.rapports().size()])
	_check(JournalPlantage.rapports()[0] == chemin.get_file(), "le plus récent est le vrai rapport")

	print("Journal de la session en cours :")
	JournalPlantage.force = true
	var j := JournalPlantage.new()
	j.etat_partie = func() -> Dictionary: return {"nom": "Essai", "habitants": 42}
	get_root().add_child(j)
	await _frames(2)
	_check(FileAccess.file_exists(JournalPlantage.MARQUE), "la marque de session est posée au lancement")
	push_error("TEST_EXPRÈS erreur de démonstration")
	j.ecrire_marque()
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(JournalPlantage.MARQUE))
	_check(typeof(d) == TYPE_DICTIONARY and d.get("partie", {}).get("habitants", 0) == 42, "elle contient l'état de la partie")
	_check(typeof(d) == TYPE_DICTIONARY and str(d.get("erreurs", [])).contains("TEST_EXPRÈS"), "et les dernières erreurs, avec leur pile")
	j.queue_free()
	await _frames(2)
	_check(not FileAccess.file_exists(JournalPlantage.MARQUE), "fermeture normale : la marque disparaît")
	JournalPlantage.force = false


func _rechargements() -> void:
	print("Rechargements sans fuite :")
	var r := ReglagesPartie.preset("normal")
	r.deblocage = "tout"  # (ce test ne porte pas sur l'arbre de progression)
	r.tutoriel = false
	ReglagesPartie.prochaine = r
	change_scene_to_file("res://scenes/globe.tscn")
	await _frames(5)
	var globe: Node = current_scene
	globe.select_place(47.56, 7.59, "Bâle (test)", true)
	globe.start_game()
	var game := await _attendre_partie()
	_check(game != null, "la partie s'ouvre")
	var bs: BuildingSystem = game.buildings
	bs.unlimited_money = true
	var mc := bs.place("maison_commune", Vector2i(0, 0), 0)
	_check(mc >= 0, "mairie posée")
	if game.villages_panel._dialog.visible:
		game.villages_panel._dialog.hide()
	# Un bâtiment fini un mois après le début de la partie ne doit pas repartir en chantier
	# au chargement (l'heure de la partie revenait après les bâtiments : centrales coupées).
	game.ambiance.unix_time += 30.0 * 86400.0
	var ch := BatimentsVie.chantiers
	BatimentsVie.chantiers = false
	var forage := bs.place("forage_eau", Vector2i(60, 0), 0)
	BatimentsVie.chantiers = ch
	_check(forage >= 0 and not bs.en_chantier(forage), "forage posé et terminé un mois plus tard")
	_check(game.save_game("", "Test stabilité"), "partie sauvegardée")
	var slot := GameStart.slot_id
	# Sauvegarde automatique : dans un emplacement tournant, la partie du joueur reste la sienne.
	game._unsaved = true
	game._autosave_timer = OptionsJeu.autosave_min * 60.0
	game._autosave(1.0)
	game._unsaved = true
	game._autosave_timer = OptionsJeu.autosave_min * 60.0
	game._autosave(1.0)
	var autos := SaveGame.autosave_slots().filter(func(s: String) -> bool: return SaveGame.exists(s))
	_check(autos.size() == 2, "deux sauvegardes automatiques, deux emplacements (%s)" % ", ".join(autos))
	_check(GameStart.slot_id == slot, "la partie du joueur reste « %s »" % slot)
	var orph := []
	var objets := []
	for k in 3:
		game.hud.globe_requested.emit()
		await _frames(5)
		globe = current_scene
		globe.load_saved_game(slot)
		game = await _attendre_partie()
		await _frames(10)
		orph.append(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)))
		objets.append(int(Performance.get_monitor(Performance.OBJECT_COUNT)))
		print("    chargement %d : %d nœuds orphelins, %d objets" % [k + 1, orph[-1], objets[-1]])
	_check(game != null and game.buildings.buildings.has(mc), "la mairie revient")
	_check(game != null and game.buildings.buildings.has(forage) and not game.buildings.en_chantier(forage),
		"le forage fini reste fini après les chargements (pas de chantier relancé)")
	_check(orph[2] <= orph[0], "aucun nœud orphelin de plus à chaque chargement (%s)" % str(orph))
	_check(objets[2] <= objets[0] + 300, "le nombre d'objets ne grimpe pas d'un chargement à l'autre (%s)" % str(objets))
	SaveGame.delete(slot)


func _attendre_partie() -> Node:
	var t0 := Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Terre") and Time.get_ticks_msec() - t0 < 30000:
		await process_frame
	var g: Node = current_scene
	if g == null or g.name != "Terre":
		return null
	var w: TerrainWorld = g.get_node("Terrain")
	w.tiles.offline_generator = func(_t: Vector2i) -> PackedFloat32Array:
		var a := PackedFloat32Array()
		a.resize(256 * 256)
		a.fill(260.0)
		return a
	w.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	while EcranChargement.actif != null and Time.get_ticks_msec() - t0 < 60000:
		await process_frame
	return g


func _run() -> void:
	Creations.persist = false
	Succes.persist = false
	Partage.persist = false
	PlansSites.persist = false
	_mettre_de_cote()
	_rotation()
	await _rapport()
	await _rechargements()
	_fin()


func _fin() -> void:
	_remettre()
	var vues := {}
	for e in _erreurs.liste:
		vues[e] = int(vues.get(e, 0)) + 1
	for e in vues:
		print("  ! ×%d %s" % [vues[e], e])
	_check(vues.is_empty(), "aucune erreur pendant le test (%d)" % _erreurs.liste.size())
	print("TEST OK" if ok else "TEST ÉCHEC")
	quit(0 if ok else 1)
