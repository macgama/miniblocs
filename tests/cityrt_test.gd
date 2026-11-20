extends SceneTree
## Test des pistes CityRT 4 à 13 et de la touche F de l'éditeur de blocs :
##  - F renverse le bloc même quand un habitant est suivi (le panneau Habitants
##    ne vole plus la touche) ; message si la forme ne se renverse pas ;
##  - jauges toujours visibles : demande L/C/I/B (bureaux) et 4 services, fiche au clic ;
##  - fil des habitants : étapes de vie et paroles, clic = fiche de l'habitant ;
##  - bouton « Afficher » du tutoriel : bulles avec cible seulement.
## Usage : godot --headless --path . --script res://tests/cityrt_test.gd

var ok := true


func _initialize() -> void:
	_run.call_deferred()
	create_timer(500.0).timeout.connect(func() -> void:
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


func _touche(k: Key, shift := false) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = k
	e.keycode = k
	e.pressed = true
	e.shift_pressed = shift
	return e


func _run() -> void:
	Creations.persist = false
	BatimentsVie.chantiers = false
	ReglagesPartie.actuel = ReglagesPartie.preset("normal")
	ReglagesPartie.actuel.deblocage = "tout"
	ReglagesPartie.actuel.construction_instantanee = true
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
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
	_village(scene)
	await _touche_f(scene)
	await _jauges(scene)
	await _fil(scene)
	await _afficher(scene)
	await _suite(scene)
	print("RÉSULTAT : ", "OK" if ok else "ÉCHEC")
	if ok:
		print("TEST OK")
	quit(0 if ok else 1)


func _place(bs: BuildingSystem, id: String, x: int, north := true, off := 6) -> int:
	var d := int(BuildingCatalog.get_type(id).d)
	var c := Vector2i(x, -(d / 2 + off) if north else d / 2 + off)
	var chk: Dictionary = bs.check_place(id, c, bs.best_rotation(id, c))
	if not chk.ok:
		print("     (non posé) ", id, " : ", chk.get("reason", chk))
	return bs.place(id, c, bs.best_rotation(id, c))


## Une route, quelques maisons habitées et un immeuble de bureaux.
func _village(scene: Node) -> void:
	var bs: BuildingSystem = scene.buildings
	var pop: Population = scene.population
	var world: TerrainWorld = scene.world
	pop.arrivals = false
	bs.money = 2_000_000_000
	var y := world.cell_height(Vector2i(0, 0))
	var road: Dictionary = scene.transport.build_segment("departementale", Vector3(-600, y, 0), Vector3(600, y, 0))
	_check(road.ok, "une route de 1,2 km")
	var maisons := []
	for x in [-300, -260, -220, -180]:
		maisons.append(_place(bs, "maison", x))
	var bur := _place(bs, "bureaux", 100, true, 8)
	_check(not maisons.has(-1) and bur > 0, "quatre maisons et des bureaux")
	pop._sync_buildings()
	for m in maisons:
		pop.spawn_household(int(m), "famille")
	_check(pop.persons.size() >= 8, "des habitants (%d)" % pop.persons.size())


## Rien par défaut : les lots suivants (prix, décors, régisseur, route au geste…)
## ajoutent leurs vérifications ici.
func _suite(_scene: Node) -> void:
	pass


func _touche_f(scene: Node) -> void:
	print("Touche F de l'éditeur de blocs :")
	var pop: Population = scene.population
	var blocks: BlockEditor = scene.blocks
	var hp: HabitantsPanel = scene.habitants_panel
	var pid := -1
	for id in pop.persons:
		pid = int(id)
		break
	_check(pid >= 0, "des habitants (fondateurs) pour en suivre un")
	pop.follow(pid)
	_check(pop.followed() == pid, "un habitant est suivi")
	scene.set_create_mode(true)
	await _frames(2)
	blocks.set_tool(BlockEditor.Tool.BLOCK)
	blocks.set_shape(BlocFormes.S.SLOPE if "SLOPE" in BlocFormes.S else 1)
	var cam0 := pop.follow_camera
	var pose0 := blocks.pose
	hp._unhandled_key_input(_touche(KEY_F))
	_check(pop.follow_camera == cam0, "F avec l'outil Poser : la caméra de l'habitant ne bascule pas")
	blocks._unhandled_input(_touche(KEY_F))
	_check(blocks.pose != pose0, "F renverse le bloc (%d → %d)" % [pose0, blocks.pose])
	var msgs := []
	var f := func(t: String) -> void: msgs.append(t)
	blocks.message.connect(f)
	blocks.set_shape(BlocFormes.S.FULL)
	blocks.flip_step()
	_check(msgs.size() == 1 and String(msgs[0]).contains("ne peut pas se renverser"), "cube plein : F explique qu'il ne se renverse pas")
	blocks.message.disconnect(f)
	blocks.set_tool(BlockEditor.Tool.NONE)
	scene.set_create_mode(false)
	await _frames(2)
	hp._unhandled_key_input(_touche(KEY_F))
	_check(pop.follow_camera != cam0, "sans outil de blocs, F bascule toujours la caméra de l'habitant suivi")
	pop.follow(-1)


func _jauges(scene: Node) -> void:
	print("Jauges toujours visibles :")
	var j: JaugesVille = scene.jauges
	_check(j != null and j.is_inside_tree() and j.visible, "jauges sous la barre du haut")
	var d: Dictionary = scene.zones.demand()
	_check(d.has("B"), "demande des bureaux (B) calculée")
	_check(ZoneSystem.est_bureau("bureaux") and not ZoneSystem.est_bureau("boulangerie"), "bureaux reconnus, pas la boulangerie")
	var v := j.valeurs()
	for k in ["R", "C", "I", "B", "elec", "eau", "egout", "dechets"]:
		_check(v.has(k) and float(v[k].v) >= 0.0 and float(v[k].v) <= 100.0, "jauge %s entre 0 et 100 (%s)" % [k, str(v.get(k, {}).get("v"))])
	j.basculer_fiche("elec")
	await _frames(2)
	_check(j.fiche_ouverte() == "elec" and j._fiche_texte.text.begins_with("Électricité"), "clic : fiche courte de l'électricité")
	var vers := []
	j.panneau_requested.connect(func(id: String) -> void: vers.append(id))
	j._fiche_bouton.pressed.emit()
	_check(vers == ["reseaux"] and j.fiche_ouverte() == "", "bouton de la fiche : panneau Réseaux, fiche refermée")
	scene.reseaux_panel.set_open(false)
	j.basculer_fiche("B")
	j.basculer_fiche("B")
	_check(j.fiche_ouverte() == "", "second clic : la fiche se referme")
	scene.set_create_mode(true)
	await _frames(2)
	_check(not j.visible, "mode Créer : jauges cachées")
	scene.set_create_mode(false)
	await _frames(2)
	_check(j.visible, "retour en mode Gérer : jauges visibles")


func _fil(scene: Node) -> void:
	print("Fil des habitants :")
	var fil: FilHabitants = scene.fil_habitants
	var pop: Population = scene.population
	_check(fil != null, "fil des habitants créé")
	fil.clear()
	_check(fil.posts.is_empty() and not fil.visible, "fil vide : carte cachée")
	var pid := -1
	for id in pop.persons:
		pid = int(id)
		break
	var p: Dictionary = pop.persons[pid]
	pop.etape_vie.emit(p, "loisir", "Se met à la pétanque", -1)
	pop.etape_vie.emit(p, "emploi", "Devient boulanger à Valfleuri", -1)
	fil._depuis = 99.0
	fil._process(0.1)
	_check(fil.posts.size() == 1 and String(fil.posts[0].texte).contains("boulanger"), "embauche dans le fil (les loisirs n'y vont pas)")
	_check(fil.visible and fil._qui.text.begins_with(CycleVie.full_name(p)), "carte visible : nom de l'habitant")
	var q: Dictionary = {}
	for id in pop.persons:
		if int(id) != pid:
			q = pop.persons[id]
			break
	pop.etape_vie.emit(p, "mariage", "Se marie", int(q.id))
	pop.etape_vie.emit(q, "mariage", "Se marie", pid)
	_check(fil._attente.size() == 1, "un mariage = un seul post pour les deux époux")
	var vus := []
	fil.person_requested.connect(func(x: int) -> void: vus.append(x))
	var clic := InputEventMouseButton.new()
	clic.button_index = MOUSE_BUTTON_LEFT
	clic.pressed = true
	fil._on_gui_input(clic)
	_check(vus == [pid], "clic : fiche de l'habitant demandée")
	await _frames(2)
	_check(scene.habitants_panel.is_open() and scene.habitants_panel.view == "profil", "le panneau Habitants s'ouvre sur sa fiche")
	scene.habitants_panel.set_open(false)
	fil.set_replie(true)
	_check(fil.visible and not fil._corps.visible, "replié : il ne reste que le titre")
	fil.set_replie(false)
	scene.avis.population = pop
	fil._dernier_jour = -99
	fil._parole_du_jour()
	_check(fil._attente.size() >= 1, "une parole des Avis par jour de jeu")


func _afficher(scene: Node) -> void:
	print("Bouton « Afficher » du tutoriel :")
	var t: Tutoriel = scene.tutoriel
	var carte: TutorielCarte = scene.tuto_carte
	var route := {}
	for e in t.etapes():
		if String(e.id) == "route":
			route = e
	var l := Tutoriel.bulles_afficher(route)
	_check(not l.is_empty() and (l[0] as Dictionary).has("cible"), "étape Route : bulle qui encadre le bouton Voies")
	_check((l[l.size() - 1] as Dictionary).has("action"), "la dernière bulle garde l'action (prendre l'outil)")
	_check(Tutoriel.peut_afficher(route), "« Afficher » proposé pour la route")
	t.demarrer()
	await _frames(2)
	_check(t.actif, "tutoriel relancé")
	if t.actif:
		_check(carte._afficher_b.visible == Tutoriel.peut_afficher(t.etape_courante()), "bouton « Afficher » sur la carte selon l'étape")
		_check(carte._passer_b.text == "Je sais déjà", "« Je sais déjà » passe l'étape")
		while t.actif and t.id_courant() != "route":
			t.passer()
		if t.id_courant() == "route":
			scene.afficher_etape()
			await _frames(3)
			_check(scene.bulles_aide.actif and scene.bulles_aide.id.ends_with(":afficher"), "Afficher : bulles « Où cliquer » à l'écran")
			_check(scene.bulles_aide.bulle().has("cible"), "la bulle montre un élément de l'écran")
			scene.bulles_aide.fermer()
