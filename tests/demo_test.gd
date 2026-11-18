extends SceneTree
## Test de la démo guidée (menu principal → « Démo guidée ») : bouton du menu,
## lieu et réglages de la démo, tutoriel puis chapitres de la démo (vue au
## sol, loisirs, fête, ligne de bus, rang de Village), bilan de fin, chrono,
## sauvegarde du parcours.
## Usage : godot --headless --path . --script res://tests/demo_test.gd

var ok := true


func _initialize() -> void:
	_run.call_deferred()
	create_timer(400.0).timeout.connect(func() -> void:
		push_error("ÉCHEC : délai dépassé")
		quit(1))


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


func _run() -> void:
	print("Menu principal :")
	var menu: Node = load(MenuPrincipal.SCENE).instantiate()
	root.add_child(menu)
	await _frames(2)
	_check(menu._boutons.has("demo"), "bouton « Démo guidée »")
	var noms: Array = menu._menu.get_children().map(func(b) -> String: return String(b.name))
	_check(noms.find("demo") >= 0 and noms.find("demo") < noms.find("nouvelle"), "la démo avant « Nouvelle partie » (%s)" % ", ".join(noms))
	menu.queue_free()
	await _frames(2)

	print("Préparation :")
	Creations.persist = false
	BatimentsVie.chantiers = false
	var titre := Demo.preparer()
	_check(titre.contains("Démo guidée") and GameStart.chosen and GameStart.load_slot == "", "nouvelle partie préparée (%s)" % titre)
	_check(is_equal_approx(GameStart.lat, float(Demo.LIEU.lat)) and GameStart.pays == String(Demo.LIEU.pays), "lieu de la démo")
	_check(ReglagesPartie.prochaine != null and ReglagesPartie.prochaine.argent_depart == int(ReglagesPartie.PRESETS.normal.argent_depart) and ReglagesPartie.prochaine.cout_construction == 1.0, "réglages Normal")
	_check(Demo.demandee, "démo demandée")
	ReglagesPartie.prochaine.fondateurs = 0
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var zones: ZoneSystem = scene.get_node("Zones")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.view_radius_override = 1200.0
	world.set_origin(45.5, 6.4)
	for i in 3000:
		await process_frame
		if i >= 120 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	scene.urgences.random_calls = false
	var t: Tutoriel = scene.tutoriel
	var carte: TutorielCarte = scene.tuto_carte
	var y := world.cell_height(Vector2i(0, 0))
	_check(not Demo.demandee, "demande consommée par la scène")
	_check(t.actif and t.est_demo() and t.id_courant() == "camera", "la démo commence par le tutoriel (%s)" % t.id_courant())
	_check(t.total() == Tutoriel.ETAPES.size() - 1 + Tutoriel.ETAPES_DEMO.size(), "étapes : tutoriel sans « fin » + chapitres (%d)" % t.total())
	await _frames(3)
	_check(carte._etape_l.text.begins_with("Démo guidée · étape 1 / %d" % t.total()), "en-tête de la carte : %s" % carte._etape_l.text)

	print("Tutoriel (rapide) :")
	scene.rig.position.x += 60.0
	t.verifier()
	scene.communes.nom_en_attente = "Valfleuri"
	_check(bs.place("maison_commune", Vector2i(0, 0), 0) > 0, "Maison de commune")
	_check(transport.build_segment("route", Vector3(0, y, 12), Vector3(0, y, 300)).ok, "route")
	_check(zones.add_zone("R", Rect2i(6, 30, 16, 60)) > 0, "zone résidentielle")
	t.verifier()
	t.verifier()
	var garde := 0
	while t.id_courant() != "vue_sol" and garde < 20:
		garde += 1
		print("     passe « %s »" % t.id_courant())
		t.passer()
	_check(t.id_courant() == "vue_sol", "après les objectifs : premier chapitre de la démo")
	_check(not t.faits.has("fin"), "pas d'étape « Tu es maire ! » dans la démo")

	print("Chapitres :")
	t.verifier()
	_check(t.id_courant() == "vue_sol", "vue de dessus : on attend")
	t.agir()
	await _frames(3)
	var vs: VueSol = scene.get_node("VueSol")
	_check(vs.vue != VueSol.Vue.DESSUS, "bouton : on descend dans la rue")
	t.verifier()
	_check(t.id_courant() == "loisirs", "vue au sol : étape « loisirs » (%s)" % t.id_courant())
	vs.set_vue(VueSol.Vue.DESSUS)
	await _frames(3)
	t.agir()
	_check(scene.build_panel.is_open() and scene.build_panel.category() == "espaces", "bouton : Construire → Espaces publics")
	scene.build_panel.set_open(false)
	print("     catégorie du square : ", BuildingCatalog.get_type("square").get("cat", ""))
	var sq := bs.place("square", Vector2i(-24, 60), 1)
	if sq < 0:
		sq = bs.place("square", Vector2i(26, 200), 3)
	_check(sq > 0, "square posé")
	t.verifier()
	_check(t.id_courant() == "fete", "étape « fete » (%s)" % t.id_courant())
	t.agir()
	_check(scene.evenements_panel.is_open() and scene.evenements_panel.view == "organiser", "bouton : Infos → Organiser")
	scene.evenements_panel.set_open(false)
	t.verifier()
	_check(t.id_courant() == "fete", "rien d'organisé : on attend")
	_check(scene.evenements.fetes.organiser("marche", Vector3(0, y, 100)) > 0, "marché organisé")
	t.verifier()
	_check(t.id_courant() == "ligne", "étape « ligne » (%s)" % t.id_courant())
	t.agir()
	_check(scene.transit_panel.is_open(), "bouton : panneau des lignes")
	scene.transit_panel.set_open(false)
	var a: Dictionary = transport.stations.place("arret_bus", Vector3(-6, y, 40))
	var b: Dictionary = transport.stations.place("arret_bus", Vector3(-6, y, 280))
	print("     arrêts : %s / %s" % [a.get("reason", "ok"), b.get("reason", "ok")])
	_check(t.progres().begins_with("Arrêts posés"), "progrès : %s" % t.progres())
	var ln: Dictionary = transport.stations.create_line([a.get("id", -1), b.get("id", -1)], "", 2) if a.ok and b.ok else {"ok": false}
	_check(ln.get("ok", false), "ligne de bus créée")
	t.verifier()
	_check(t.id_courant() == "village", "étape « village » (%s)" % t.id_courant())
	_check(t.progres().begins_with("Habitants :"), "progrès : %s" % t.progres())
	t.agir()
	await _frames(2)
	_check(scene.objectifs_panel.is_open(), "bouton : ce qui manque (Maj+J)")
	scene.objectifs_panel.set_open(false)
	t.verifier()
	_check(t.id_courant() == "village", "Hameau, 0 habitant : on attend")
	scene.objectifs.paliers[t.ville()] = 1
	t.verifier()
	_check(t.id_courant() == "fin_demo", "Village atteint : fin de la démo")
	await _frames(2)
	_check(not carte._passer_b.visible and carte._action_b.text == "Voir mon bilan", "carte de fin : « Voir mon bilan »")

	print("Bilan :")
	t.temps_demo = 27.0 * 60.0 + 5.0
	var bi := t.bilan()
	print("     ", bi)
	_check(int(bi.minutes) == 27 and String(bi.rang) == "Village" and int(bi.batiments) >= 2 and int(bi.jours) < 400 and int(bi.lignes) == 1, "chiffres du bilan")
	_check(float(bi.routes_km) > 0.25, "routes : %.2f km" % float(bi.routes_km))
	t.agir()
	await _frames(3)
	_check(scene.bilan_demo != null and scene.bilan_demo.is_inside_tree(), "panneau du bilan ouvert")
	_check(not t.actif and t.demo_finie, "démo finie, tutoriel arrêté")
	var txt := " ".join(scene.bilan_demo.lignes().map(func(l) -> String: return "%s %s" % [l[0], l[1]]))
	_check(txt.contains("Temps de jeu 27 min") and txt.contains("Rang Village"), "tableau : %s" % txt)
	_check(Demo.duree(65) == "1 h 05" and Demo.duree(9) == "9 min", "durées lisibles")
	scene.bilan_demo.fermer()
	await _frames(2)
	_check(scene.bilan_demo == null, "« Continuer à jouer » ferme le bilan")

	print("Sauvegarde :")
	var d := t.to_dict()
	_check(String(d.parcours) == "demo" and bool(d.demo_finie) and float(d.temps_demo) > 1600.0, "parcours, chrono et fin gardés")
	var t2 := Tutoriel.new()
	t2.from_dict({"actif": true, "etape": 14, "parcours": "demo", "temps_demo": 600.0, "faits": ["camera"]})
	_check(t2.est_demo() and t2.actif and t2.id_courant() == String(t2.etapes()[14].id) and t2.minutes_demo() == 10, "démo rechargée en cours (%s)" % t2.id_courant())
	t2.clear()
	_check(not t2.est_demo() and t2.total() == Tutoriel.ETAPES.size(), "partie sans tutoriel : plus de démo")
	t2.free()

	print("TEST OK" if ok else "TEST ÉCHEC")
	quit(0 if ok else 1)
