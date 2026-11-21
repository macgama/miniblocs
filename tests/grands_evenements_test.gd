extends SceneTree
## Test des vols cinématiques et des grands événements : vol (caméra, bandes,
## interface cachée, temps ralenti, passer, file, réglage « Vols automatiques »),
## vol au nouveau palier, fête de la ville (anniversaire, organisée, feu
## d'artifice à 22 h), inauguration d'un monument, premier train, sauvegarde,
## bouton « Filmer » du panneau Infos.
## Usage : godot --headless --path . --script res://tests/grands_evenements_test.gd

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


func _at(date: String, hour: float) -> float:
	return Time.get_unix_time_from_datetime_string(date + "T00:00:00") + (hour - 1.0) * 3600.0


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _feux(ev: Evenements) -> int:
	var n := 0
	for c in ev.visuels.find_children("*", "FeuxArtifice", true, false):
		if not (c as Node).is_queued_for_deletion():
			n += 1
	return n


func _run() -> void:
	Creations.persist = false
	BatimentsVie.chantiers = false
	GameStart.chosen = true
	GameStart.place_name = "Valfleuri, Savoie"
	ReglagesPartie.prochaine = ReglagesPartie.preset("normal")
	ReglagesPartie.prochaine.deblocage = "tout"
	ReglagesPartie.prochaine.fondateurs = 0
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var amb: DayNight = scene.get_node("Ambiance")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.view_radius_override = 900.0
	world.set_origin(45.5, 6.4)
	for i in 3000:
		await process_frame
		if i >= 120 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	scene.urgences.random_calls = false
	var ev: Evenements = scene.evenements
	var vol: VolCinematique = scene.vol_cinematique
	var ge: GrandsEvenements = scene.grands_evenements
	var cm: Communes = scene.communes
	ev.forcer_auto = 0
	ev.forcer_catastrophes = 0
	bs.unlimited_money = true
	amb.set_speed(DayNight.DEFAULT_SPEED)
	amb.unix_time = _at("2026-06-10", 10.0)
	vol.set_auto(true)
	_check(vol != null and ge != null and ev.grands == ge and ev.planificateurs.has(ge), "vol cinématique et grands événements branchés")
	_check(ev.modules.has("fete_ville") and ev.modules.has("inauguration") and ev.modules.has("premier_train"), "trois types d'événements")

	print("Vol cinématique :")
	var cam0 := root.get_viewport().get_camera_3d()
	var hud_layers := 0
	for c in root.find_children("*", "CanvasLayer", true, false):
		if (c as CanvasLayer).visible:
			hud_layers += 1
	var finis := []
	vol.fini.connect(func(passe: bool) -> void: finis.append(passe))
	var y := world.cell_height(Vector2i(0, 0))
	_check(vol.lancer({"centre": Vector3(0, y, 0), "rayon": 100.0, "titre": "Essai", "sous_titre": "sous-titre", "bulle": "« bulle »"}), "vol lancé")
	_check(vol.actif and root.get_viewport().get_camera_3d() == vol.camera, "la caméra du vol a la main")
	_check(amb.speed_index == VolCinematique.VITESSE_MAX, "temps ralenti à 10 min/s pendant le vol")
	var visibles := 0
	for c in root.find_children("*", "CanvasLayer", true, false):
		if (c as CanvasLayer).visible:
			visibles += 1
	_check(visibles == 1 and vol._layer.visible, "interface cachée, seules les bandes du vol restent (%d calques avant)" % hud_layers)
	var p0 := VolCinematique.position_vol(Vector3.ZERO, 100.0, 0.0)
	var p1 := VolCinematique.position_vol(Vector3.ZERO, 100.0, 1.0)
	_check(p0.y > p1.y + 100.0 and Vector2(p0.x, p0.z).length() > Vector2(p1.x, p1.z).length() * 2.0,
		"trajectoire : haut et loin (%d m) puis bas et près (%d m)" % [roundi(p0.y), roundi(p1.y)])
	for i in 30:
		vol._process(0.1)
	_check(vol._titre.modulate.a > 0.9 and vol._haut.offset_bottom > 10.0, "titre affiché, bandes noires")
	var c_pos := vol.camera.global_position
	_check(c_pos.distance_to(Vector3(0, y, 0)) > 50.0, "la caméra tourne autour du lieu (%d m)" % roundi(c_pos.distance_to(Vector3(0, y, 0))))
	_check(vol.lancer({"centre": Vector3(50, y, 0), "titre": "Deuxième"}) and vol.file.size() == 1, "un 2e vol attend son tour")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	vol._input(esc)
	_check(finis == [true], "Échap : vol passé")
	await _frames(2)
	_check(vol.actif and String(vol.plan.titre) == "Deuxième", "le vol en attente part ensuite")
	for i in int((VolCinematique.DUREE + 1.0) / 0.1):
		vol._process(0.1)
	_check(not vol.actif and finis == [true, false], "le vol finit tout seul")
	_check(root.get_viewport().get_camera_3d() == cam0 and amb.speed_index == DayNight.DEFAULT_SPEED, "caméra de gestion et vitesse du temps rendues")
	visibles = 0
	for c in root.find_children("*", "CanvasLayer", true, false):
		if (c as CanvasLayer).visible:
			visibles += 1
	_check(visibles == hud_layers, "interface revenue (%d calques)" % visibles)
	vol.set_auto(false)
	_check(not vol.lancer({"centre": Vector3(0, y, 0), "auto": true}) and not vol.actif, "« Vols automatiques » décoché : pas de vol tout seul")
	_check(vol.lancer({"centre": Vector3(0, y, 0), "titre": "À la main"}) and vol.actif, "mais Filmer à la main marche encore")
	vol.passer()
	vol.set_auto(true)

	print("Palier :")
	cm.nom_en_attente = "Valfleuri"
	var mc := bs.place("maison_commune", Vector2i(-200, 0), 0)
	var v1 := cm.principal()
	_check(mc > 0 and v1 >= 0, "Valfleuri fondé")
	await _frames(2)
	if vol.actif:
		vol.passer()
	cm.calculer_stats()
	var paliers := []
	scene.objectifs.palier_gagne.connect(func(vid: int, i: int) -> void: paliers.append([vid, i]))
	cm.stats[v1]["hab"] = 120
	# (Satisfaction mise en cache : elle demande de vrais habitants.)
	scene.objectifs._cache["sat:%d" % v1] = [Time.get_ticks_msec() + 600000, 80]
	scene.objectifs.verifier_palier(v1)
	_check(paliers == [[v1, 1]], "Valfleuri devient Village (signal palier_gagne)")
	_check(vol.actif and String(vol.plan.titre) == "Valfleuri devient Village" and String(vol.plan.bulle) != "", "vol : « %s » · %s" % [vol.plan.get("titre", ""), vol.plan.get("sous_titre", "")])
	_check(_feux(ev) == 1, "petit feu d'artifice sur la mairie")
	var feu: FeuxArtifice = ev.visuels.find_children("*", "FeuxArtifice", true, false)[0]
	for i in 20:
		feu._process(0.5)
	_check(feu.eclatements > 0, "les fusées éclatent (%d bouquets)" % feu.eclatements)
	vol.passer()
	feu.arreter()
	for i in 40:
		feu._process(0.5)
	_check(feu.is_queued_for_deletion(), "le feu d'artifice se range après le bouquet final")

	print("Fête de la ville :")
	cm.stats[v1]["hab"] = 200
	cm.villages[v1].fonde = _at("2025-06-11", 9.0)
	amb.unix_time = _at("2026-06-11", 0.5)
	ev.forcer_auto = 1
	ev._last_day = -1
	ev._process(0.0)
	var fetes := ev.prevus("fete_ville")
	_check(fetes.size() == 1 and int(fetes[0].data.ans) == 1, "1er anniversaire : fête prévue (%s)" % (fetes[0].nom if not fetes.is_empty() else "aucune"))
	ev._last_day = -1
	ev._process(0.0)
	fetes = ev.prevus("fete_ville")
	_check(fetes.size() == 1, "une seule fête par an")
	var fid := int(fetes[0].id)
	amb.unix_time = _at("2026-06-11", 20.5)
	ev._process(0.0)
	_check(String(ev.events[fid].etat) == "en_cours" and ev.events[fid].has("node"), "20 h 30 : tables, guirlandes et foule devant la mairie")
	_check(_feux(ev) == 0 and not vol.actif, "pas encore de feu d'artifice")
	amb.unix_time = _at("2026-06-11", 22.1)
	ev._process(0.0)
	_check(_feux(ev) == 1 and bool(ev.events[fid].data.feux), "22 h : feu d'artifice")
	_check(vol.actif and String(vol.plan.sous_titre).contains("son 1 an") and String(vol.plan.titre).begins_with("Fête de la ville"), "vol : « %s » · %s" % [vol.plan.titre, vol.plan.sous_titre])
	vol.passer()
	amb.unix_time = _at("2026-06-12", 0.2)
	ev._process(0.0)
	_check(String(ev.events[fid].etat) == "fini", "fini à minuit")
	ev.forcer_auto = 0
	# Organisée par le joueur.
	var fo := ge.organiser_fete(Vector3(-200, y, 0))
	_check(fo > 0 and ev.events.has(fo) and bool(ev.events[fo].data.joueur), "fête organisée par le joueur à Valfleuri")
	_check(ge.organiser_fete(Vector3(-200, y, 0)) == -1, "pas deux fêtes en même temps")
	_check(ge.organiser_fete(Vector3(5000, y, 5000)) == -1, "pas de fête hors d'une ville")
	ev.finir(fo)

	print("Inauguration :")
	var bid := mc
	_check(bid > 0, "un monument posé")
	scene.patrimoine.inaugure.emit(bid)
	var inaug := ev.en_cours("inauguration") + ev.prevus("inauguration")
	_check(inaug.size() == 1, "inauguration annoncée : %s" % (inaug[0].nom if not inaug.is_empty() else "aucune"))
	ev._process(0.0)
	var noeud: Node = ev.events[int(inaug[0].id)].get("node", null)
	_check(String(ev.events[int(inaug[0].id)].etat) == "en_cours" and noeud != null and noeud.find_children("*", "FeuxArtifice", true, false).size() == 1
		and noeud.get_node_or_null("Ruban") != null, "ruban, foule et feu d'artifice")
	_check(vol.actif and String(vol.plan.titre).begins_with("Inauguration"), "vol au-dessus du monument")
	vol.passer()
	ev.finir(int(inaug[0].id))

	print("Premier train :")
	var road := transport.build_segment("train", Vector3(-400, y, 120), Vector3(800, y, 120))
	_check(road.ok, "une voie ferrée")
	var st := transport.stations
	var g1 := st.place("gare", Vector3(-250, y, 120))
	var g2 := st.place("gare", Vector3(650, y, 120))
	_check(g1.ok and g2.ok, "deux gares (raison : %s %s)" % [g1.get("reason", ""), g2.get("reason", "")])
	var ln := st.create_line([g1.id, g2.id], "", 1)
	_check(ln.ok, "ligne de train créée (%s)" % ln.get("reason", ""))
	var trains := ev.en_cours("premier_train") + ev.prevus("premier_train")
	_check(trains.size() == 1 and ge.premiers_trains.has(v1), "premier train de Valfleuri : %s" % (trains[0].nom if not trains.is_empty() else "aucun"))
	ev._process(0.0)
	_check(vol.actif and vol.plan.has("suivre") and (vol.plan.suivre as Callable).is_valid(), "le vol suit la rame")
	vol.passer()
	var ln2 := st.create_line([g1.id, g2.id], "", 1)
	_check(ln2.ok and (ev.en_cours("premier_train") + ev.prevus("premier_train")).size() == 1, "une 2e ligne n'en refait pas")

	print("Sauvegarde :")
	var d := ev.to_dict()
	ev.from_dict(JSON.parse_string(JSON.stringify(d)))
	_check(ge.premiers_trains.has(v1) and ge.fetes_faites.has(v1), "premiers trains et fêtes faites rechargés")
	ge.apres_chargement()
	_check(ge.verifier_trains() == -1, "après un chargement, les lignes existantes ne refont pas la fête")

	print("Panneau Infos :")
	var fe := ge.organiser_fete(Vector3(-200, y, 0))
	ev.events[fe].debut = ev.now()
	ev._process(0.0)
	scene.evenements_panel.set_open(true)
	scene.evenements_panel.show_view("en_cours")
	var filmer := false
	for b in scene.evenements_panel.find_children("*", "Button", true, false):
		if (b as Button).text.contains("Filmer"):
			filmer = true
			(b as Button).pressed.emit()
			break
	_check(filmer and vol.actif, "bouton « Filmer » sur un événement en cours")
	vol.passer()
	scene.evenements_panel.show_view("organiser")
	var orga := false
	for b in scene.evenements_panel.find_children("*", "Button", true, false):
		orga = orga or (b as Button).text.begins_with("Fête de la ville")
	_check(orga, "Organiser : « Fête de la ville »")
	_check(FileAccess.file_exists("res://assets/son/effets/feu_artifice.ogg") and FileAccess.file_exists("res://assets/son/effets/applaudissements.ogg"), "sons feu d'artifice et applaudissements")

	print("GRANDS EVENEMENTS TEST OK" if ok else "GRANDS EVENEMENTS TEST ÉCHEC")
	quit(0 if ok else 1)
