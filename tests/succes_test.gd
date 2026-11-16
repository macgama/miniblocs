extends SceneTree
## Test des succès du joueur : catalogue, compteurs, seuils, argent illimité, pont
## Steam (faux Steam), sauvegarde du profil, continents, et dans une partie : relevé
## des chiffres, succès des Objectifs repris, fenêtre F6, carte « Succès débloqué ».
## Usage : godot --headless --path . --script res://tests/succes_test.gd

var ok := true


class FauxSteam:
	extends Object
	var poses := {}
	var deja := {}
	var envois := 0
	var progres: Array = []

	func steamInitEx() -> Dictionary:
		return {"status": 0, "verbal": "OK"}

	func setAchievement(n: String) -> bool:
		poses[n] = true
		return true

	func getAchievement(n: String) -> Dictionary:
		return {"ret": true, "achieved": deja.has(n) or poses.has(n)}

	func storeStats() -> bool:
		envois += 1
		return true

	func indicateAchievementProgress(n: String, v: int, m: int) -> bool:
		progres.append([n, v, m])
		return true

	func run_callbacks() -> void:
		pass


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


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _key(k: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.pressed = pressed
		root.push_input(e)
		await process_frame


func _run() -> void:
	Succes.persist = false
	Succes.reinitialiser()
	SteamPont.reinitialiser()

	print("Catalogue :")
	var cat := Succes.catalogue()
	_check(cat.size() == Objectifs.SUCCES.size() + Succes.NOUVEAUX.size() and cat.size() >= 60, "%d succès (%d des Objectifs)" % [cat.size(), Objectifs.SUCCES.size()])
	var ids := {}
	var re := RegEx.create_from_string("^[A-Z0-9_]+$")
	var noms_ok := true
	var icones_ok := true
	for s in cat:
		ids[String(s.id)] = true
		var api := Succes.api_steam(String(s.id))
		if re.search(api) == null or api.length() > 64:
			noms_ok = false
		if not Icones.has_icon(String(s.get("icone", "trophee"))):
			icones_ok = false
			print("    icône manquante : ", s.id)
		if String(s.nom).strip_edges() == "" or String(s.desc).strip_edges() == "":
			noms_ok = false
	_check(ids.size() == cat.size(), "ids uniques")
	_check(noms_ok, "noms Steam valides (MB_…, majuscules) et textes remplis")
	_check(icones_ok, "chaque succès a une icône")
	# Chaque compteur est bien relevé quelque part.
	var src := FileAccess.get_file_as_string("res://scripts/succes/succes_suivi.gd") + FileAccess.get_file_as_string("res://scripts/manette/manette.gd") \
		+ FileAccess.get_file_as_string("res://scripts/visite/visites_panel.gd") + FileAccess.get_file_as_string("res://scripts/visite/courrier.gd")
	var orphelins: Array = []
	for s in Succes.NOUVEAUX:
		if not src.contains("\"%s\"" % String(s.stat)):
			orphelins.append(s.stat)
	_check(orphelins.is_empty(), "chaque compteur est relevé (%s)" % ", ".join(orphelins))

	print("Compteurs et seuils :")
	var recus: Array = Succes.recents
	Succes.noter("route_m", 400)
	_check(not Succes.est_debloque("route_nulle_part"), "400 m de route : pas encore")
	Succes.noter("route_m", 1200)
	_check(Succes.est_debloque("route_nulle_part") and recus.has("route_nulle_part"), "1,2 km : « La route de nulle part » débloqué et signalé")
	Succes.noter("route_m", 800)
	_check(Succes.stat("route_m") == 1200, "noter garde le meilleur chiffre")
	_check(SteamPont.journal.has(["succes", "MB_ROUTE_NULLE_PART"]), "parti vers le pont Steam (hors Steam : rien ne casse)")
	var n0 := recus.size()
	Succes.noter("route_m", 1300)
	_check(recus.size() == n0, "pas débloqué deux fois")
	for i in 24:
		Succes.ajouter("incendies")
	_check(not Succes.est_debloque("pompier_de_service") and is_equal_approx(Succes.avancement("pompier_de_service"), 24.0 / 25.0), "24 incendies : 96 %")
	Succes.ajouter("incendies")
	_check(Succes.est_debloque("pompier_de_service"), "25 incendies : « Pompier de service »")
	_check(Succes.avancement("dans_le_rouge") < 0.0, "succès oui/non : pas de barre d'avancement")
	Succes.argent_illimite = true
	Succes.noter("caisse", 900_000_000)
	Succes.ajouter("demolitions", 500)
	_check(not Succes.est_debloque("oncle_picsou") and not Succes.debloquer("premier_village") and Succes.stat("demolitions") == 0.0,
		"argent illimité : aucun succès, les compteurs n'avancent pas")
	Succes.argent_illimite = false
	Succes.noter("caisse", 900_000_001)
	_check(Succes.est_debloque("oncle_picsou"), "vrai argent : « Bas de laine »")
	_check(not Succes.debloquer("n_existe_pas"), "id inconnu refusé")
	_check(Succes.debloquer("premier_village") and Succes.est_debloque("premier_village"), "succès des Objectifs débloquable par son id")

	print("Profil sur le disque :")
	Succes.persist = true
	Succes.fichier = "user://succes_test.cfg"
	Succes.sauver()
	var avant := Succes.nombre()
	Succes._charge = false
	Succes.charger()
	_check(Succes.nombre() == avant and Succes.stat("incendies") == 25.0, "rechargé : %d succès, 25 incendies" % avant)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Succes.fichier))
	Succes.persist = false

	print("Steam (faux) :")
	var fs := FauxSteam.new()
	fs.deja["MB_ARCHITECTE"] = true
	SteamPont.reinitialiser()
	SteamPont.faux = fs
	_check(SteamPont.demarrer() and SteamPont.actif(), "Steam démarré")
	_check(fs.poses.has("MB_ROUTE_NULLE_PART") and fs.poses.has("MB_PREMIER_VILLAGE"), "succès gagnés hors ligne reportés sur Steam")
	_check(Succes.est_debloque("architecte"), "succès gagné ailleurs sur Steam repris ici")
	_check(fs.envois >= 1, "storeStats appelé")
	Succes.noter("batiments", 30)
	_check(not fs.progres.is_empty() and String(fs.progres[0][0]) == "MB_CENT_TOITS", "avancement envoyé (30 / 100 bâtiments)")
	var np := fs.progres.size()
	Succes.noter("batiments", 31)
	_check(fs.progres.size() == np, "avancement envoyé seulement par paliers de 10 %")
	Succes.noter("batiments", 100)
	_check(fs.poses.has("MB_CENT_TOITS"), "« Cent toits » posé sur Steam")
	SteamPont.reinitialiser()
	fs.free()

	print("Continents :")
	_check(SuccesSuivi.continent(46.64, 6.63) == "europe", "Échallens : Europe")
	_check(SuccesSuivi.continent(48.86, 2.35) == "europe", "Paris : Europe")
	_check(SuccesSuivi.continent(40.71, -74.0) == "amerique_nord", "New York : Amérique du Nord")
	_check(SuccesSuivi.continent(-22.9, -43.2) == "amerique_sud", "Rio : Amérique du Sud")
	_check(SuccesSuivi.continent(6.5, 3.4) == "afrique", "Lagos : Afrique")
	_check(SuccesSuivi.continent(30.0, 31.2) == "afrique", "Le Caire : Afrique")
	_check(SuccesSuivi.continent(35.7, 139.7) == "asie", "Tokyo : Asie")
	_check(SuccesSuivi.continent(-33.9, 151.2) == "oceanie", "Sydney : Océanie")
	_check(SuccesSuivi.continent(55.75, 37.6) == "europe", "Moscou : Europe")

	print("Médailles :")
	var img := SuccesPanel.badge_image("feu", true, 64)
	_check(img.get_size() == Vector2i(64, 64) and img.get_pixel(32, 32).a > 0.9 and img.get_pixel(1, 1).a < 0.1, "médaille ronde 64 px")

	print("Dans une partie :")
	Succes.reinitialiser()
	Creations.persist = false
	ReglagesPartie.prochaine = ReglagesPartie.preset("normal")
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
	var suivi: SuccesSuivi = scene.succes_suivi
	_check(suivi != null and suivi.actif, "suivi des succès dans la partie")
	var y := world.cell_height(Vector2i(0, 0))
	scene.transport.build_segment("route", Vector3(0, y, -700), Vector3(0, y, 700))
	await _frames(2)
	var r := bs.place("maison", Vector2i(16, 0), 3)
	await _frames(2)
	suivi.releve()
	_check(Succes.stat("route_m") >= 1300 and Succes.est_debloque("route_nulle_part"), "route de 1,4 km relevée : %.0f m" % Succes.stat("route_m"))
	_check(Succes.stat("batiments") >= 1 and Succes.est_debloque("premier_coup_de_pelle"), "premier bâtiment relevé (%s)" % str(r))
	scene.objectifs.succes_debloque("trois_villes")
	suivi.releve()
	_check(Succes.est_debloque("trois_villes"), "succès des Objectifs (Maj+J) repris dans le profil")
	bs.unlimited_money = true
	suivi.releve()
	scene.objectifs.succes_debloque("relies")
	Succes.noter("route_m", 30000)
	_check(not Succes.est_debloque("ponts_et_chaussees") and not scene.objectifs.succes.has("relies"), "argent illimité dans la partie : succès coupés (profil et Objectifs)")
	bs.unlimited_money = false
	suivi.releve()
	scene.ambiance.set_speed(DayNight.SPEEDS.size() - 1)
	suivi.releve()
	_check(Succes.est_debloque("pied_au_plancher"), "vitesse maximale : « Pied au plancher »")
	scene.ambiance.set_speed(0)
	suivi._pause_s = 599.0
	await _frames(3)
	suivi._pause_s = 700.0
	await _frames(2)
	_check(Succes.est_debloque("pause_cafe"), "10 minutes en pause : « Pause café »")
	scene.ambiance.set_speed(1)
	scene.evenements.incident_declare.emit({"type": "incendie"})
	scene.evenements.incident_declare.emit({"type": "crue"})
	_check(Succes.stat("incendies") == 1.0 and Succes.stat("catastrophes") == 1.0, "incendie et crue comptés")
	var nb_cont := Succes.stat("continents")
	suivi.noter_continent()
	_check(Succes.stat("continent_europe") == 1.0 and Succes.stat("continents") >= maxf(nb_cont, 1.0), "fondation : continent noté (Europe)")

	print("Fenêtre F6 et notification :")
	await _key(KEY_F6)
	await _frames(2)
	_check(scene.succes_panel != null and scene.succes_panel.is_inside_tree(), "F6 ouvre la fenêtre des succès")
	var lignes: int = scene.succes_panel._liste.get_child_count()
	_check(lignes == Succes.total(), "toutes les lignes affichées (%d)" % lignes)
	scene.succes_panel.filtre = "debloques"
	scene.succes_panel.refresh()
	await _frames(1)
	var vis := 0
	for c in scene.succes_panel._liste.get_children():
		if not c.is_queued_for_deletion():
			vis += 1
	_check(vis == Succes.nombre(), "filtre Débloqués : %d" % vis)
	await _key(KEY_ESCAPE)
	await _frames(2)
	_check(scene.succes_panel == null, "Échap la ferme")
	var notif := root.get_node_or_null("SuccesNotif")
	_check(notif != null, "nœud global des notifications")
	if notif != null:
		await _frames(3)
		_check(not notif.montrees.is_empty(), "carte « Succès débloqué » montrée (%d)" % notif.montrees.size())
	_check(scene.hud._category("succes").get("group", "") == "infos", "Succès dans le menu Infos de la barre du bas")

	scene.queue_free()
	await _frames(3)
	print("RÉSULTAT : ", "OK" if ok else "ÉCHEC")
	quit(0 if ok else 1)
