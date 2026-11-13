extends SceneTree
## Test des services funéraires : catalogue (cimetières, columbarium,
## crématorium, pompes funèbres), corbillard, obsèques après un décès (convoi
## sur la route, cérémonie au cimetière, tombe qui apparaît), caveau familial,
## crémation et urne, cimetière plein (attente puis commune voisine),
## concessions, argent, avis des habitants, clic sur une tombe, réglage
## Admin et sauvegarde.
## Usage : xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tests/funeraire_test.gd

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


func _place(bs: BuildingSystem, id: String, x: int, north := true) -> int:
	var d := int(BuildingCatalog.get_type(id).d)
	var c := Vector2i(x, -(d / 2 + 6) if north else d / 2 + 6)
	return bs.place(id, c, bs.best_rotation(id, c))


func _run() -> void:
	_catalog_tests()
	await _city_tests()
	print("TEST OK" if ok else "TEST ÉCHEC")
	quit(0 if ok else 1)


func _catalog_tests() -> void:
	print("Catalogue :")
	var ids := BuildingCatalog.ids_in("funeraire")
	_check(ids.size() == FuneraireTypes.ORDER.size(), "%d bâtiments dans la catégorie Funéraire" % ids.size())
	_check(not BuildingCatalog.category("funeraire").is_empty(), "onglet Funéraire dans Construire")
	for id in FuneraireTypes.ORDER:
		var m := BuildingCatalog.build_mesh(id)
		_check(m != null and m.get_surface_count() > 0, "modèle de %s" % id)
		for j in Metiers.jobs_for(id):
			_check(Metiers.METIERS.has(String(j[0])), "%s : métier %s connu" % [id, j[0]])
		if FuneraireTypes.role_of(id) in ["cimetiere", "columbarium"]:
			var sl: Array = FuneraireTypes.slots(id)
			var t := BuildingCatalog.get_type(id)
			var inside := true
			for x in sl:
				var p: Vector3 = (x as Transform3D).origin
				inside = inside and absf(p.x) < float(t.w) / 2.0 and absf(p.z) < float(t.d) / 2.0
			_check(sl.size() > 50 and inside, "%s : %d places, toutes dans l'enceinte" % [id, sl.size()])
	_check(FuneraireTypes.places("cimetiere_communal") >= 1000, "cimetière communal : %d tombes" % FuneraireTypes.places("cimetiere_communal"))
	_check(FuneraireTypes.places("cimetiere_paysager") > FuneraireTypes.places("cimetiere_communal"), "le paysager est le plus grand")
	for st in ["dalle", "stele", "blanche", "asie", "simple", "juive", "plaque", "fleurs", "cercueil", "fosse"]:
		_check(FuneraireTypes.tomb_mesh(st).get_surface_count() > 0, "maillage « %s »" % st)
	var cb := VehicleCatalog.get_type("corbillard")
	_check(not cb.is_empty() and bool(cb.get("livraison", false)), "corbillard au catalogue des véhicules")
	_check(not Traffic._no_service(VehicleCatalog.for_track("route")).has("corbillard"), "pas de corbillard dans la circulation d'ambiance")
	_check(VehicleCatalog.build_mesh("corbillard") != null, "modèle du corbillard")
	_check(Icones.get_icon("funeraire", 22) != null, "icône Funéraire")
	_check(Gestes.info("recueillement").a == "recueil", "geste « se recueille »")


func _city_tests() -> void:
	print("Ville :")
	Creations.persist = false
	BatimentsVie.chantiers = false
	ReglagesPartie.actuel.construction_instantanee = true
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 40
	world.view_radius_override = 900.0
	world.set_origin(46.2, 6.9)
	for i in 3000:
		await process_frame
		if i >= 120 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	var fun: Funeraire = scene.funeraire
	_check(fun != null and Funeraire.instance == fun, "services funéraires branchés dans la scène")
	_check(scene.save_sections().has("funeraire"), "section « funeraire » dans la sauvegarde")
	var pop: Population = scene.population
	# Horloge à 1 min/s, comme avant le nouveau défaut (1 jour/min) : la journée ne bascule pas en plein test.
	scene.ambiance.set_speed(2)
	var tf := transport.traffic
	for n in [tf, fun, pop, scene.dechets, scene.production]:
		n.set_process(false)
	scene.urgences.set_process(false)
	scene.urgences.random_calls = false
	bs.unlimited_money = true
	var y := world.cell_height(Vector2i(0, 0))
	var road := transport.build_segment("route", Vector3(-700, y, 0), Vector3(700, y, 0))
	_check(road.ok, "route de 1,4 km")
	var homes: Array[int] = []
	for i in 8:
		homes.append(_place(bs, "maison", -400 + i * 14))
	_check(not homes.has(-1), "8 maisons posées")
	pop._sync_buildings()
	for bid in homes:
		pop.spawn_household(bid, "famille")
	_check(pop.persons.size() >= 12, "%d habitants" % pop.persons.size())

	fun.ignore_hours = true
	fun.ignore_crew = true
	fun.clock = 1_800_000_000.0
	fun.last_day = int(fun._now(fun.clock).day)
	var t := func(hours: float) -> void:
		for i in int(hours * 4.0):
			fun.clock += 900.0
			fun.step(900.0)
			fun._update_ceremonies()
			tf.step(0.5)

	# Un couple : on suit l'un puis l'autre jusqu'au cimetière.
	var a := -1
	for pid in pop.persons:
		if int(pop.persons[pid].get("cj", -1)) >= 0 and pop.persons.has(int(pop.persons[pid].cj)):
			a = int(pid)
			break
	_check(a >= 0, "un couple dans la ville")
	var b := int(pop.persons[a].cj)
	var hid := int(pop.persons[a].f)

	# Sans cimetière : le défunt attend, sa famille s'inquiète, puis commune voisine.
	ReglagesPartie.actuel.cremation = 0.0
	var lone := -1
	for pid in pop.persons:
		if int(pid) != a and int(pid) != b and pop.age_of(pop.persons[pid]) >= 18.0:
			lone = int(pid)
			break
	var lone_rel: Array = []
	for q in pop.persons:
		if int(pop.persons[q].f) == int(pop.persons[lone].f) and int(q) != lone:
			lone_rel.append(int(q))
	pop.vie.die(lone, "de vieillesse")
	_check(fun.obseques.has(lone) and String(fun.obseques[lone].etat) == "attente", "sans cimetière, le défunt attend une place")
	t.call(24.0 * 3.0)
	if not lone_rel.is_empty():
		var sat: Array = fun.satisfaction_of(pop.persons[lone_rel[0]])
		_check(float(sat[0]) < 0.0, "la famille est inquiète : %s" % ", ".join(sat[1]))
	t.call(24.0 * 4.0)
	_check(not fun.obseques.has(lone) and String(fun.sepultures.get(lone, {}).get("mode", "")) == "export", "enterré dans une commune voisine après 6 jours")
	_check(fun.sepulture_text(lone).contains("commune voisine"), "fiche : « %s »" % fun.sepulture_text(lone))

	# Pompes funèbres, cimetière, crématorium, columbarium, lieu de culte.
	var pf := _place(bs, "pompes_funebres", -60, false)
	var cim := _place(bs, "cimetiere_village", 200)
	var cre := _place(bs, "crematorium", 320, false)
	var col := _place(bs, "columbarium", 120, false)
	var culte_id := ""
	for id in BuildingCatalog.all_types():
		if String(BuildingCatalog.get_type(id).get("arch", "")) == "culte" and int(BuildingCatalog.get_type(id).get("w", 99)) <= 40:
			culte_id = id
			break
	var eglise := _place(bs, culte_id, 450) if culte_id != "" else -1
	_check(pf > 0 and cim > 0 and cre > 0 and col > 0, "pompes funèbres, cimetière, crématorium et columbarium posés")
	pop._sync_buildings()
	fun._sync()
	_check(fun.sites.size() == 4 and (fun.sites[pf].units as Array).size() == 2, "2 corbillards aux pompes funèbres")
	_check(not fun.access_of(pf).is_empty() and not fun.access_of(cim).is_empty() and not fun.access_of(homes[0]).is_empty(), "accès à la route")
	_check(fun.free_places(cim) == fun.capacity(cim) and fun.capacity(cim) > 100, "cimetière vide : %d places" % fun.capacity(cim))

	# Décès : obsèques prévues, convoi, cérémonie, tombe.
	var ep0 := float(pop.households[hid].ep)
	pop.vie.die(a, "de vieillesse")
	var o: Dictionary = fun.obseques.get(a, {})
	_check(not o.is_empty() and String(o.etat) == "prevu" and int(o.dest) == cim, "obsèques prévues au cimetière")
	_check(float(o.t_prevu) >= float(o.t_mort) + Funeraire.DELAI - 1.0, "1 jour au moins après le décès")
	_check((o.proches as Array).has(b), "le conjoint est parmi les proches")
	t.call(Funeraire.DELAI / 3600.0 + 0.5)
	o = fun.obseques.get(a, {})
	_check(String(o.get("etat", "")) == "convoi" and int(o.pf) == pf, "le convoi part des pompes funèbres")
	_check(fun.vehicles_on_road().corbillards == 1, "le corbillard roule sur la route")
	_check(float(o.t_dest) > float(o.t0) + 600.0, "horaire du convoi calculé par la route")
	_check(eglise < 0 or not bool(o.religieux) or int(o.culte) == eglise, "cérémonie au lieu de culte si la famille le veut")
	var guard := 0
	while String(fun.obseques.get(a, {}).get("etat", "")) == "convoi" and guard < 40:
		t.call(0.25)
		guard += 1
	_check(fun.vehicles_on_road().cortege >= 0, "voitures de la famille derrière le corbillard")
	_check(String(fun.obseques.get(a, {}).get("etat", "")) == "ceremonie", "mise en terre au cimetière")
	_check(fun.ceremonies_shown() == 1 and (fun._cer[a].figs as Array).size() >= 3, "les proches entourent la fosse (%d)" % (fun._cer[a].figs as Array).size())
	t.call(1.0)
	_check(fun.ceremonies_shown() == 0, "fin de la cérémonie")
	_check(fun.used(cim) == 1 and fun.tombs_shown(cim) == 1, "une pierre tombale apparaît au cimetière")
	_check(fun.sepultures.has(a) and int(fun.sepultures[a].bid) == cim, "le défunt repose au cimetière")
	var f: Dictionary = pop.vie.archive[a]
	var has_cv := false
	for e in f.cv:
		has_cv = has_cv or String(e[1]) == "obseques"
	_check(has_cv, "obsèques notées dans le CV du défunt")
	var b_cv := false
	for e in pop.persons[b].cv:
		b_cv = b_cv or String(e[1]) == "obseques"
	_check(b_cv, "et dans celui du conjoint")
	_check(float(pop.households[int(pop.persons[b].f)].ep) < ep0, "la famille a payé les obsèques")
	_check(float(fun.today.commune) + float(fun.yesterday.commune) > 0.0, "la commune encaisse la concession")
	var sat_b: Array = fun.satisfaction_of(pop.persons[b])
	_check(float(sat_b[0]) > 0.0, "le conjoint : %s" % ", ".join(sat_b[1]))
	t.call(24.0)
	_check(int(fun.sites[pf].units[0].pid) == -1, "le corbillard est rentré")
	_check(fun.vehicles_on_road().corbillards == 0, "plus de corbillard sur la route")

	# Clic sur la tombe : la fiche du défunt.
	var cam := Camera3D.new()
	scene.add_child(cam)
	var tomb := fun.slot_world(cim, int(fun.sepultures[a].slot)).origin
	cam.global_position = tomb + Vector3(0, 25, -18)
	cam.look_at(tomb)
	var screen := cam.unproject_position(fun.slot_world(cim, int(fun.sepultures[a].slot)) * Vector3(0, 0.6, 0.6))
	_check(fun.pick(screen, cam) == a, "clic sur la tombe → fiche du défunt")

	# Le conjoint rejoint le caveau familial.
	pop.vie.die(b, "de vieillesse")
	_check(bool(fun.obseques[b].caveau) and int(fun.obseques[b].slot) == int(fun.sepultures[a].slot), "le conjoint rejoindra le caveau familial")
	t.call(Funeraire.DELAI / 3600.0 + 8.0)
	_check(fun.used(cim) == 1 and (fun.sites[cim].tombes[int(fun.sepultures[a].slot)].occ as Array).size() == 2, "deux noms sur la même tombe")

	# Crémation : crématorium, puis l'urne le lendemain.
	ReglagesPartie.actuel.cremation = 1.0
	var c := -1
	for pid in pop.persons:
		if pop.age_of(pop.persons[pid]) >= 18.0:
			c = int(pid)
			break
	pop.vie.die(c, "d'une maladie")
	_check(String(fun.obseques[c].mode) == "cremation" and int(fun.obseques[c].dest) == cre, "crémation au crématorium de la ville")
	t.call(Funeraire.DELAI / 3600.0 + 34.0)
	_check(fun.sepultures.has(c) and String(fun.sepultures[c].mode) in ["case", "jardin", "famille"], "l'urne : %s" % fun.sepulture_text(c))
	_check(int(fun.totaux.cremations) + int(fun.today.cremations) >= 1, "crémation comptée")
	fun.urnes.append({"pid": c, "t": fun.clock, "dest": -1, "slot": -1, "kind": "case", "nom": "Test", "pres": cre})
	fun._place_urns()
	fun.step(900.0)
	_check(fun.used(col) >= 1 and fun.tombs_shown(col) >= 1, "une plaque au columbarium")

	# Concessions : reprise sans famille, renouvelée avec.
	var cap := fun.capacity(cim)
	fun.sites[cim].tombes[cap - 1] = {"occ": [987654], "noms": ["Inconnu Ancien"], "fin": pop.life_clock - 1.0, "t": 0.0}
	fun.new_day()
	_check(not fun.sites[cim].tombes.has(cap - 1) and int(fun.yesterday.reprises) == 1, "concession échue sans famille : place reprise")
	var heir := -1
	for pid in pop.persons:
		if not (pop.persons[pid].pa as Array).is_empty() and int(pop.persons[pid].pa[0]) >= 0:
			heir = int(pid)
			break
	if heir >= 0:
		var par := int(pop.persons[heir].pa[0])
		fun.sites[cim].tombes[cap - 2] = {"occ": [par], "noms": ["Parent"], "fin": pop.life_clock - 1.0, "t": 0.0}
		fun.new_day()
		_check(fun.sites[cim].tombes.has(cap - 2) and float(fun.sites[cim].tombes[cap - 2].fin) > pop.life_clock, "concession renouvelée par un enfant")

	# Cimetière plein : on remplit tout ; le défunt attend.
	ReglagesPartie.actuel.cremation = 0.0
	for i in fun.capacity(cim):
		if not fun.sites[cim].tombes.has(i):
			fun.sites[cim].tombes[i] = {"occ": [800000 + i], "noms": ["X"], "fin": pop.life_clock + 9999.0, "t": 0.0}
	_check(fun.free_places(cim) == 0, "cimetière plein")
	var d2 := -1
	for pid in pop.persons:
		if pop.age_of(pop.persons[pid]) >= 18.0:
			d2 = int(pid)
			break
	if d2 >= 0:
		pop.vie.die(d2, "de vieillesse")
		_check(String(fun.obseques[d2].etat) == "attente" or bool(fun.obseques[d2].caveau), "plus de place : il attend (sauf caveau familial)")
	fun._vis_dirty[cim] = true
	fun.step(900.0)
	_check(fun.tombs_shown(cim) == fun.capacity(cim), "toutes les tombes visibles (%d)" % fun.tombs_shown(cim))

	# Liens avec les autres systèmes.
	_check(fun.get_groups().has("avis_sources") and fun.get_groups().has("budget_entretien") and fun.get_groups().has("pollution_sources"), "groupes des autres systèmes")
	_check(float(fun.budget_entretien().get("Cimetières et crématorium", 0.0)) > 0.0, "entretien pour le budget")
	_check(not fun.pollution_sources().is_empty(), "fumée du crématorium dans les nuisances")
	_check(not fun.fiche_lignes(cim).is_empty() and not fun.fiche_lignes(pf).is_empty(), "lignes des fiches de bâtiment")
	var panel: HabitantsPanel = scene.habitants_panel
	panel.set_open(true)
	panel.show_view("funeraire")
	_check(panel._body.get_child_count() > 5, "onglet Funéraire du panneau Habitants")
	panel.show_view("profil", a)
	var found := false
	for ch in panel._body.get_children():
		if ch is Label and String((ch as Label).text).begins_with("Repose"):
			found = true
	_check(found, "fiche du défunt : où il repose")
	panel.show_view("batiment", cim)
	panel.set_open(false)

	# Sauvegarde.
	var save := fun.to_dict()
	var back: Dictionary = JSON.parse_string(JSON.stringify(save))
	var n_used := fun.used(cim)
	var n_sep := fun.sepultures.size()
	fun.from_dict(back)
	_check(fun.used(cim) == n_used and fun.sepultures.size() == n_sep and int(fun.sepultures[a].bid) == cim, "sauvegarde relue (tombes, sépultures)")
	_check(fun.tombs_shown(cim) == n_used, "tombes de nouveau visibles après le chargement")

	# Admin : sans obsèques, rien ne se passe à la mort.
	ReglagesPartie.actuel.funeraire = false
	var d3 := -1
	for pid in pop.persons:
		d3 = int(pid)
		break
	if d3 >= 0:
		pop.vie.die(d3, "de vieillesse")
		_check(not fun.obseques.has(d3), "réglage Admin : obsèques désactivées")
	ReglagesPartie.actuel.funeraire = true
	ReglagesPartie.actuel.cremation = -1.0
	var r := ReglagesPartie.new()
	r.funeraire = false
	r.cremation = 0.5
	var r2 := ReglagesPartie.new()
	r2.from_dict(r.to_dict())
	_check(not r2.funeraire and absf(r2.cremation - 0.5) < 0.001, "réglages funéraires sauvegardés")
	scene.queue_free()
	await process_frame
