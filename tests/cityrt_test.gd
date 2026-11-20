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


func _suite(scene: Node) -> void:
	await _prix(scene)
	await _deplacer(scene)
	await _regisseur(scene)
	await _geste_route(scene)


func _geste_route(scene: Node) -> void:
	print("Route tracée au geste + Ctrl+Z :")
	# Un geste tremblé en forme de S, sur 400 m.
	var brut := PackedVector2Array()
	for i in 101:
		var x := 300.0 + i * 4.0
		brut.append(Vector2(x, 200.0 + 60.0 * sin(i / 100.0 * TAU) + (1.2 if i % 2 == 0 else -1.2)))
	var lisse := RoutePlanner.trace_geste(brut, "rue")
	var rmin := float(TransportTypes.get_type("rue").get("r_min", 15.0))
	var r := RoutePlanner.min_radius(RoutePlanner.resample(lisse, TransportTypes.STEP))
	_check(lisse.size() > 2 and r >= rmin - 0.5, "tracé lissé : virages ≥ rayon mini (%.0f m ≥ %.0f m)" % [r, rmin])
	_check(lisse[0].distance_to(brut[0]) < 0.1 and lisse[lisse.size() - 1].distance_to(brut[brut.size() - 1]) < 0.1, "le tracé part et arrive où la souris l'a dit")
	var ecart := 0.0
	for p in brut:
		var best := INF
		for q in RoutePlanner.resample(lisse, 2.0):
			best = minf(best, p.distance_to(q))
		ecart = maxf(ecart, best)
	_check(ecart < 25.0, "il suit l'allure du geste (écart max %.0f m)" % ecart)
	var dep := RoutePlanner.trace_geste(brut, "departementale")
	_check(RoutePlanner.min_radius(RoutePlanner.resample(dep, TransportTypes.STEP)) >= 239.5, "une départementale garde ses 240 m de rayon : le geste est adouci")
	var droite := RoutePlanner.trace_geste(PackedVector2Array([Vector2(0, 0), Vector2(50, 0.8), Vector2(100, -0.6), Vector2(150, 0)]), "departementale")
	_check(droite.size() == 2, "un trait presque droit reste une droite")
	# Le geste dans l'outil, comme la souris.
	var ts: TransportSystem = scene.transport
	var w: TerrainWorld = scene.world
	ts.set_build("rue")
	var aretes := ts.network.edges.size()
	var y0 := w.cell_height(Vector2i(300, 200))
	ts._start = {"node": -1, "edge": -1, "pos": Vector3(300, y0, 200), "dir": Vector2.ZERO}
	ts.commencer_geste()
	for p in brut:
		ts.ajouter_point_geste(p)
	var fin := brut[brut.size() - 1]
	ts._cursor = Vector3(fin.x, w.cell_height(Vector2i(fin)), fin.y)
	ts._cursor_valid = true
	var h: HistoriqueVille = scene.historique
	var n_h := h.taille()
	ts.finir_geste()
	_check(ts.network.edges.size() > aretes, "relâcher le bouton pose la route (%d tronçons)" % (ts.network.edges.size() - aretes))
	_check(not ts._geste and not ts._start.is_empty(), "le tracé continue depuis le bout posé")
	_check(h.taille() == n_h + 1, "le geste est une entrée de l'historique")
	var txt := h.annuler()
	_check(ts.network.edges.size() == aretes, "Ctrl+Z défait la route tracée (%s)" % txt)
	ts.set_inactive()
	await _frames(2)


func _prix(scene: Node) -> void:
	print("Prix sur chaque carte :")
	var banc := Decors.prix("banc_bois")
	_check(banc >= 100 and banc <= 400, "banc en bois : %d € (≈ 200 €)" % banc)
	_check(Decors.prix("statue_equestre") > Decors.prix("buste") and Decors.prix("buste") > banc, "statue équestre > buste > banc")
	_check(Decors.prix("cloture_bois") < banc, "clôture : prix au tronçon, moins cher qu'un banc")
	var dp: DecorPanel = scene.decors_panel
	_check(dp._liste.item_count > 0 and dp._liste.get_item_text(0).contains("€"), "cartes des décors avec leur prix (%s)" % dp._liste.get_item_text(0).replace("\n", " · "))
	var pr := VignettesVoies.prix("departementale")
	_check(pr.contains("€") and pr.contains("km"), "carte de voie : entretien %s" % pr)
	var cv := ChoixVisuel.new()
	cv.add_item("Rue")
	cv.set_item_prix(0, "60 €")
	_check(cv.get_item_prix(0) == "60 €", "tuile en images : ligne de prix")
	cv.free()


func _deplacer(scene: Node) -> void:
	print("Déplacer à la main les décors :")
	var d: DecorSystem = scene.decors
	var bs: BuildingSystem = scene.buildings
	var y: float = scene.world.cell_height(Vector2i(0, 40))
	d.set_outil(DecorSystem.Outil.POSER)
	d.choix = "banc_bois"
	var argent0 := bs.money
	var n0 := d.nombre_poses()
	# Trois bancs posés comme le joueur (clic par clic) : chacun payé.
	for x in [0.0, 4.0, 8.0]:
		if d._peut_payer(Decors.prix("banc_bois")) and d.pose("banc_bois", x, 40.0, 0.0):
			d._payer(Decors.prix("banc_bois"))
	_check(d.nombre_poses() == n0 + 3, "trois bancs posés")
	_check(argent0 - bs.money == 3 * Decors.prix("banc_bois"), "payés : %s" % BuildingSystem.format_money(argent0 - bs.money))
	d.set_outil(DecorSystem.Outil.DEPLACER)
	# Cadre glissé autour des trois bancs.
	d.commencer_geste(Vector3(-2, y, 37))
	_check(d._geste == "cadre", "clic dans le vide : cadre de sélection")
	d._geste_dernier = Vector3(10, y, 43)
	d.finir_geste(Vector3(10, y, 43))
	_check(d.selection.size() == 3, "cadre : trois bancs choisis (%d)" % d.selection.size())
	# Glisser l'un des bancs : tout le groupe suit.
	d.commencer_geste(Vector3(4.2, y, 40.1))
	_check(d._geste == "deplace", "clic sur un banc choisi : on déplace le groupe")
	d.deplacer_selection(0.0, 10.0)
	d.finir_geste(Vector3(4.2, y, 50.1))
	_check(not d.decor_a(Vector3(4, y, 50)).is_empty() and d.decor_a(Vector3(4, y, 40)).is_empty(), "le groupe a bougé de 10 m")
	_check(d.nombre_poses() == n0 + 3, "déplacer ne copie rien")
	# Ctrl + glisser : copie (payée).
	var argent1 := bs.money
	d.commencer_geste(Vector3(4.0, y, 50.0), false, true)
	d.deplacer_selection(12.0, 0.0)
	d.finir_geste(Vector3(16.0, y, 50.0))
	_check(d.nombre_poses() == n0 + 6, "Ctrl + glisser : trois copies (%d)" % (d.nombre_poses() - n0))
	_check(argent1 - bs.money == 3 * Decors.prix("banc_bois"), "copies payées")
	_check(not d.decor_a(Vector3(4, y, 50)).is_empty() and not d.decor_a(Vector3(16, y, 50)).is_empty(), "originaux en place, copies à côté")
	# R : tourne le groupe autour de son centre.
	var a0 := float(d.selection[0][4])
	var c0 := Vector2(float(d.selection[1][1]), float(d.selection[1][3]))
	d.tourner_selection(PI / 2.0)
	_check(absf(fposmod(float(d.selection[0][4]) - a0, TAU) - PI / 2.0) < 0.01, "R : chaque banc tourne d'un quart de tour")
	_check(Vector2(float(d.selection[1][1]), float(d.selection[1][3])).distance_to(c0) < 0.05, "le banc du milieu reste au centre")
	# Suppr : retire la sélection, la moitié du prix est rendue.
	var argent2 := bs.money
	_check(d.retirer_selection() == 3 and d.nombre_poses() == n0 + 3, "Suppr : les trois copies retirées")
	_check(bs.money - argent2 == 3 * (Decors.prix("banc_bois") / 2), "moitié du prix rendue")
	# Caisse vide : pas de copie.
	d.choisir([d.decor_a(Vector3(4, y, 50))])
	var argent3 := bs.money
	bs.money = 10
	_check(d.copier_selection() == 0 and d.nombre_poses() == n0 + 3, "caisse vide : la copie est refusée")
	bs.money = argent3
	d.set_inactive()
	_check(d.selection.is_empty(), "lâcher l'outil vide la sélection")
	var sv := d.to_dict()
	_check((sv.poses as Array).size() == d.nombre_poses(), "sauvegarde : les décors déplacés sont gardés")


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


func _regisseur(scene: Node) -> void:
	print("Régisseur de quartier :")
	var q: Quartiers = scene.quartiers
	var rg: Regisseurs = q.regisseurs
	var pop: Population = scene.population
	var bs: BuildingSystem = scene.buildings
	_check(rg != null and rg.is_in_group("avis_sources"), "régisseurs branchés aux quartiers et à l'avis")
	var qid := q.creer("Les Tilleuls")
	_check(qid > 0, "quartier créé")
	q.peindre_rect(qid, Rect2i(-350, -100, 250, 200))
	_check(q.ha(qid) > 0.0, "quartier peint autour des maisons (%s ha)" % str(q.ha(qid)))
	var cands := rg.candidats(qid)
	_check(not cands.is_empty(), "des habitants du quartier peuvent devenir régisseurs (%d)" % cands.size())
	if cands.is_empty():
		return
	var c: Dictionary = cands[0]
	_check(Regisseurs.CARACTERES.has(String(c.car)) and int(c.age) >= 25, "candidat : %s, %d ans, %s" % [c.nom, int(c.age), c.car])
	var posts0: int = scene.fil_habitants.posts.size()
	_check(rg.confier(qid, int(c.pid), 40_000) == "", "quartier confié")
	_check(scene.fil_habitants.posts.size() == posts0 + 1, "la nomination passe dans le fil des habitants")
	var p: Dictionary = pop.persons[int(c.pid)]
	var av := rg.avis_politique(p)
	_check(float(av[0]) > 0.0, "ses voisins aiment avoir un des leurs aux commandes")
	# Caractère forcé « bon vivant » : bancs et jeux, puis rues piétonnes quand la cagnotte suffit.
	rg.regisseurs[qid].car = "bon_vivant"
	var argent0 := bs.money
	var decors0: int = scene.decors.nombre_poses()
	var t := rg.semaine(qid)
	_check(t != "", "une semaine : il fait quelque chose (%s)" % t)
	_check(argent0 - bs.money == roundi(40_000.0 * 7.0 / 30.44), "sa part du budget est payée par la ville")
	var a_fait: bool = scene.decors.nombre_poses() > decors0 or q.a_arrete(qid, "rue_pietonne") or q.a_arrete(qid, "zone_30")
	_check(a_fait, "arrêté pris ou mobilier posé dans le quartier")
	for i in 6:
		rg.semaine(qid)
	_check(int(rg.de(qid).actions) >= 3, "il agit chaque semaine (%d actions)" % int(rg.de(qid).actions))
	_check(int(rg.de(qid).caisse) >= 0, "la cagnotte ne passe jamais sous zéro")
	# Sauvegarde et rechargement.
	var d := q.to_dict()
	rg.clear()
	q.from_dict(d)
	_check(rg.de(qid).get("pid", -1) == int(c.pid) and String(rg.de(qid).car) == "bon_vivant", "sauvegardé avec les quartiers")
	# Reprendre la main : la cagnotte revient.
	var caisse := int(rg.de(qid).caisse)
	var argent1 := bs.money
	rg.reprendre(qid)
	_check(rg.de(qid).is_empty() and bs.money - argent1 == caisse, "reprendre la main : cagnotte rendue (%s)" % BuildingSystem.format_money(caisse))
	# Mairie perdue : il s'en va.
	rg.confier(qid, int(c.pid), 5_000)
	var qp: QuartiersPanel = scene.quartiers_panel
	qp.set_open(true)
	q.selection = qid
	qp.refresh()
	await _frames(2)
	_check(qp._body.get_child_count() > 0, "panneau du quartier avec la section Régisseur")
	qp.set_open(false)
	pop.persons.erase(int(c.pid))
	rg.journee(rg._jour() + 30)
	_check(rg.de(qid).is_empty(), "régisseur parti : le maire reprend la main")
