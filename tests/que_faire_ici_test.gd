extends SceneTree
## Test de la fiche « Que faire ici ? » : ressources du lieu, bâtiments posables
## ou non (trop pauvre, pas encore inventé), chaînes de transformation, clic sur
## un terrain libre, bouton Construire, option et époque 1800.
## Usage : godot --headless --path . --script res://tests/que_faire_ici_test.gd

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


static func _ids(l: Array) -> Array:
	var out := []
	for f in l:
		out.append(String(f.id))
	return out


static func _fiche(l: Array, id: String) -> Dictionary:
	for f in l:
		if String(f.id) == id:
			return f
	return {}


func _run() -> void:
	Creations.persist = false
	BatimentsVie.chantiers = false
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	# Forêt à l'ouest de l'origine, champs à l'est (comme production_test).
	const LAT := 49.15
	const LON := 6.75
	world.land.offline_generator = func(_lat: float, lon: float) -> int: return 10 if lon < LON else 40
	world.view_radius_override = 1100.0
	world.set_origin(LAT, LON)
	for i in 3000:
		await process_frame
		if i >= 150 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	var prod: Production = scene.production
	var fiche: QueFaireIci = scene.que_faire_ici
	_check(fiche != null and fiche.prod == prod, "fiche branchée dans la scène")
	if fiche == null:
		_fin()
		return

	print("Forêt (ouest) :")
	var foret := QueFaireIci.analyser(prod, Vector2i(-400, 0))
	_check(bool(foret.connu), "relief connu")
	_check(not foret.ressources.is_empty() and String(foret.ressources[0][0]) == "bois", "la ressource la plus riche est le bois")
	_check(_ids(foret.ok).has("exploitation_forestiere"), "exploitation forestière posable")
	var ef := _fiche(foret.ok, "exploitation_forestiere")
	_check(not ef.is_empty() and float(ef.t_jour) > 1.0 and String(ef.good) == "bois", "tonnes de bois par jour prévues (%s)" % str(ef.get("t_jour")))
	var pe := _fiche(foret.non, "port_peche")
	_check(not pe.is_empty() and String(pe.etat) == "pauvre" and String(pe.raison).contains("il faut"), "port de pêche loin de l'eau : trop pauvre, avec la raison")
	var ol := _fiche(foret.non, "oliveraie")
	_check(not ol.is_empty() and String(ol.etat) == "climat", "oliveraie en Lorraine : mauvais climat")
	_check(_ids(foret.ok).has("mine") or _ids(foret.non).has("mine"), "la mine est examinée (fer lorrain)")
	_check(_ids(foret.chaines).has("scierie"), "chaîne sur place : scierie (bois → planches)")
	_check(_ids(foret.chaines).has("menuiserie") or _ids(foret.apports).has("menuiserie"), "menuiserie proposée (planches d'ici)")

	print("Champs (est) :")
	var champs := QueFaireIci.analyser(prod, Vector2i(400, 0))
	_check(_ids(champs.ok).has("ferme_cereales"), "ferme céréalière posable dans les champs")
	_check(_ids(champs.chaines).has("moulin"), "chaîne sur place : moulin (céréales → farine)")
	_check(_ids(champs.chaines).has("fournil"), "puis boulangerie industrielle (farine d'ici)")
	_check(not _ids(champs.ok).has("exploitation_forestiere"), "pas d'exploitation forestière dans les champs")
	for f in champs.ok:
		if float(f.rich) < float(f.need):
			_check(false, "%s posable sous le minimum" % f.id)
	# Même verdict que la règle de pose.
	var t: Dictionary = BuildingCatalog.get_type("ferme_cereales")
	var c := Vector2i(400, 0)
	var rect := Rect2i(c - Vector2i(int(t.w) / 2, int(t.d) / 2), Vector2i(int(t.w), int(t.d)))
	_check(not prod.check_site("ferme_cereales", rect).has("reason"), "même verdict que la règle de pose (ferme céréalière)")
	var t2: Dictionary = BuildingCatalog.get_type("exploitation_forestiere")
	var rect2 := Rect2i(c - Vector2i(int(t2.w) / 2, int(t2.d) / 2), Vector2i(int(t2.w), int(t2.d)))
	_check(prod.check_site("exploitation_forestiere", rect2).has("reason"), "même verdict que la règle de pose (forêt refusée)")

	print("Clic sur le terrain :")
	_check(not fiche.is_open(), "fiche fermée au départ")
	scene.population.ground_clicked.emit(Vector2i(-400, 0))
	_check(fiche.is_open() and fiche.cell == Vector2i(-400, 0), "un clic sur un terrain libre ouvre la fiche")
	_check(fiche._body.get_child_count() > 4, "la fiche montre des sections (%d éléments)" % fiche._body.get_child_count())
	var y := world.cell_height(Vector2i(0, 300))
	_check(transport.build_segment("route", Vector3(-50, y, 300), Vector3(50, y, 300)).ok, "route posée")
	fiche.fermer()
	scene.population.ground_clicked.emit(Vector2i(0, 300))
	_check(not fiche.is_open(), "un clic sur une route n'ouvre pas la fiche")
	OptionsJeu.fiche_lieu = false
	scene.population.ground_clicked.emit(Vector2i(-400, 0))
	_check(not fiche.is_open(), "option désactivée : pas de fiche")
	OptionsJeu.fiche_lieu = true
	scene.production_panel.lieu_requested.emit()
	_check(fiche.is_open(), "P → Ressources → Que faire ici ? ouvre la fiche")
	fiche.ouvrir(Vector2i(-400, 0))
	fiche.construire.emit("exploitation_forestiere")
	_check(bs.mode == BuildingSystem.Mode.PLACE and bs.type_id == "exploitation_forestiere", "Construire lance la pose du bâtiment")

	print("Époque 1800 :")
	var r := ReglagesPartie.actuel
	var avant := r.annee_depart if r != null else 0
	if r != null:
		r.annee_depart = 1800
		r.histoire_saut = 0
		r.histoire_debut = 0.0
	var vieux := QueFaireIci.analyser(prod, Vector2i(-400, 0))
	var epoque := 0
	for f in vieux.non:
		if String(f.etat) == "epoque":
			epoque += 1
	_check(epoque > 0, "en 1800, des bâtiments sont « pas encore inventés » (%d)" % epoque)
	for f in vieux.ok:
		if Epoques.annee_batiment(String(f.id)) > 1800:
			_check(false, "%s proposé en 1800 alors qu'il arrive en %d" % [f.id, Epoques.annee_batiment(String(f.id))])
	if r != null:
		r.annee_depart = avant
	_check(QueFaireIci.icone_ressource("petrole", 32) != null, "pictos des ressources dessinés")
	_fin()


func _fin() -> void:
	print("TEST OK" if ok else "TEST ÉCHEC")
	quit(0 if ok else 1)
