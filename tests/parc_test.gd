extends SceneTree
## Test du parc de loisirs : catalogue et modèles, parc fondé par son entrée,
## visiteurs (touristes et habitants), files d'attente, tours de manège, billets
## et stands dans la caisse, faim et toilettes, propreté et atelier, pannes et
## réparations, note en étoiles, sauvegarde, panneau, manèges animés.
## Usage : godot --headless --path . --script res://tests/parc_test.gd

var ok := true

## Samedi 18 juillet 2026, 9 h (heure de Suisse romande, UTC+2).
const SAMEDI := 1_784_358_000.0


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


func _run() -> void:
	_catalog_tests()
	await _city_tests()
	print("TEST OK" if ok else "TEST ÉCHEC")
	quit(0 if ok else 1)


func _catalog_tests() -> void:
	print("Catalogue :")
	var ids := BuildingCatalog.ids_in("parc")
	_check(ids.size() == ParcTypes.ORDER.size(), "%d objets dans la catégorie Parc de loisirs" % ids.size())
	_check(not BuildingCatalog.category("parc").is_empty(), "onglet Parc de loisirs dans Construire")
	_check(Icones.has_icon("parc"), "icône du parc")
	var n_att := 0
	for id in ParcTypes.ORDER:
		var t := BuildingCatalog.get_type(id)
		var m := BuildingCatalog.build_mesh(id)
		_check(m != null and m.get_surface_count() > 0, "modèle de %s" % id)
		var aabb := m.get_aabb()
		_check(aabb.size.x <= float(t.w) + 0.05 and aabb.size.z <= float(t.d) + 0.05, "%s tient dans son emprise" % id)
		for j in Metiers.jobs_for(id):
			_check(Metiers.METIERS.has(String(j[0])), "%s : métier %s connu" % [id, j[0]])
		var spec := ParcTypes.spec_of(id)
		if String(spec.role) == "attraction":
			n_att += 1
			var anim := ParcTypes.build_anim(id)
			_check(anim != null and anim.get_child_count() > 0, "%s : parties mobiles" % id)
			if anim != null:
				ParcTypes.animate(anim, id, 3.0, 0.016, 1.0)
				anim.free()
		if String(spec.role) != "entree":
			_check((t.access as Array).is_empty(), "%s se pose sans route, dans le parc" % id)
	_check(n_att == 9, "9 attractions (%d)" % n_att)
	_check(ParcTypes.coaster_points().size() == ParcTypes.COASTER_N, "tracé des montagnes russes")
	var hi := 0.0
	for p in ParcTypes.coaster_points():
		hi = maxf(hi, p.y)
		if absf(p.x) > 29.0 or absf(p.z) > 16.5:
			_check(false, "le tracé sort de l'emprise en %s" % p)
	_check(hi > 12.0, "bosse de plus de 12 m (%.1f m)" % hi)


func _place(bs: BuildingSystem, id: String, x: int, z: int, r := 0) -> int:
	var bid := bs.place(id, Vector2i(x, z), r)
	if bid < 0:
		push_error("pose impossible : %s en %d, %d" % [id, x, z])
	return bid


func _city_tests() -> void:
	print("Ville :")
	Creations.persist = false
	BatimentsVie.chantiers = false
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
	var parc: ParcLoisirs = scene.parc
	_check(parc != null and scene.parc_panel != null, "parc et panneau branchés dans la scène")
	_check(scene.save_sections().has("parc"), "section « parc » dans la sauvegarde")
	var pop: Population = scene.population
	for n in [transport.traffic, parc, pop, scene.dechets, scene.production]:
		n.set_process(false)
	scene.urgences.set_process(false)
	scene.urgences.random_calls = false
	bs.unlimited_money = false
	bs.money = 50_000_000
	var y := world.cell_height(Vector2i(0, 0))
	var road := transport.build_segment("route", Vector3(-500, y, 0), Vector3(500, y, 0))
	_check(road.ok, "route de 1 km")
	# Quelques habitants.
	var homes: Array[int] = []
	for i in 6:
		var c := Vector2i(-300 + i * 14, 12)
		homes.append(bs.place("maison", c, bs.best_rotation("maison", c)))
	pop._sync_buildings()
	for bid in homes:
		pop.spawn_household(bid, "famille")
	_check(pop.persons.size() >= 12, "%d habitants" % pop.persons.size())

	# L'entrée, face à la route (côté nord), et les attractions derrière.
	var c0 := Vector2i(0, -14)
	var entree := bs.place("entree_parc", c0, bs.best_rotation("entree_parc", c0))
	_check(entree > 0, "entrée du parc posée au bord de la route")
	parc.ignore_staff = true
	parc._sync()
	_check(parc.parcs.has(entree), "l'entrée fonde un parc")
	var car := _place(bs, "carrousel_parc", -30, -50)
	var roue := _place(bs, "grande_roue_parc", 20, -48)
	var coaster := _place(bs, "montagnes_russes", 0, -110)
	var bateau := _place(bs, "bateau_pirate", -50, -85)
	var frites := _place(bs, "friterie_parc", -8, -40)
	var buv := _place(bs, "buvette_parc", -8, -30)
	var wc := _place(bs, "toilettes_parc", 40, -75)
	var loin := _place(bs, "tasses_parc", 400, -320)
	parc._sync()
	_check(car > 0 and roue > 0 and coaster > 0 and bateau > 0 and frites > 0 and buv > 0 and wc > 0, "attractions, stands et toilettes posés")
	_check(int(parc.items[car].parc) == entree and int(parc.items[coaster].parc) == entree, "rattachés au parc")
	_check(loin > 0 and int(parc.items[loin].parc) == -1 and parc.hors_parc().has(loin), "les tasses posées à 500 m sont hors du parc")
	_check(parc.attractions_ok(entree).size() == 4, "4 attractions dans le parc")

	parc.clock = SAMEDI - 3600.0
	parc.last_day = int(parc._now(parc.clock).day)
	var now := parc._now(SAMEDI)
	_check(int(now.wd) == 6 and int(now.month) == 7, "samedi de juillet, %.1f h" % float(now.h))
	var att := parc.attendus(entree, now)
	_check(float(att[0]) > 300.0, "touristes attendus un samedi d'été : %d" % roundi(float(att[0])))
	_check(float(att[1]) > 0.0, "et quelques habitants : %.1f" % float(att[1]))
	var caisse0 := bs.money
	var run := func(hours: float) -> void:
		for i in int(hours * 60.0):
			parc.clock += ParcLoisirs.STEP
			parc.step(ParcLoisirs.STEP)
	run.call(2.0)
	_check(not bool(parc.parcs[entree].ouvert) or parc._now(parc.clock).h >= 10.0, "fermé avant 10 h")
	run.call(2.0)
	var p: Dictionary = parc.parcs[entree]
	_check(bool(p.ouvert), "ouvert à 11 h")
	_check(parc.presents(entree) > 50, "visiteurs dans le parc : %d" % parc.presents(entree))
	var en_file := 0
	for a in parc.agents.values():
		if String(a.etat) == "file":
			en_file += 1
	_check(en_file > 0, "des visiteurs font la queue (%d)" % en_file)
	_check(int(p.jour.tours) > 50, "tours de manège : %d" % int(p.jour.tours))
	_check(float(p.jour.billets) > 1000.0, "billets vendus : %d €" % roundi(float(p.jour.billets)))
	_check(bs.money > caisse0, "les billets arrivent dans la caisse (+%d €)" % (bs.money - caisse0))
	run.call(3.0)
	_check(float(p.jour.stands) > 0.0, "frites et boissons vendues : %d €" % roundi(float(p.jour.stands)))
	_check(float(parc.items[frites].argent) > 0.0 and float(parc.items[buv].argent) > 0.0, "la friterie et la buvette encaissent")
	_check(parc.items[car].tours > 0 and parc.items[coaster].tours > 0, "carrousel et montagnes russes tournent")
	_check(float(parc.items[coaster].fiab) < 100.0, "les manèges s'usent (fiabilité %.1f %%)" % float(parc.items[coaster].fiab))
	_check(float(p.salete) > 0.0 and parc.proprete(entree) < 100.0, "sans agents de propreté, le parc se salit (%d / 100)" % roundi(parc.proprete(entree)))
	_check(not (p.dernieres as Array).is_empty(), "les visiteurs parlent : « %s »" % String((p.dernieres as Array)[0]))
	var d := parc.detail_note(entree)
	_check(float(d.note) > 1.0 and float(d.note) <= 5.0, "note du moment : %.1f étoiles" % float(d.note))
	print("    pensées : ", p.pensees)

	# Une panne sans atelier : dépanneur extérieur.
	parc._panne(roue, entree)
	_check(bool(parc.items[roue].panne) and (parc.items[roue].file as Array).is_empty(), "panne : file vidée")
	run.call(0.1)
	_check(bool(parc.items[roue].dep), "sans atelier, on appelle un dépanneur extérieur")
	run.call(ParcLoisirs.DEPANNEUR_H + 0.2)
	_check(not bool(parc.items[roue].panne), "le dépanneur a réparé la grande roue")
	# Atelier : réparations rapides, révisions, propreté.
	var atelier := _place(bs, "atelier_parc", -60, -40)
	var repos := _place(bs, "aire_repos_parc", 50, -110)
	parc._sync()
	_check(atelier > 0 and repos > 0, "atelier d'entretien et aire de repos posés")
	var sale0 := float(p.salete)
	parc._panne(car, entree)
	run.call(0.1)
	_check(not bool(parc.items[car].dep), "les techniciens de l'atelier prennent la panne")
	run.call(2.1)
	_check(not bool(parc.items[car].panne), "carrousel réparé en moins de 2 h")
	_check(float(p.salete) < sale0 + 5.0, "les agents de propreté ramassent (%d → %d)" % [roundi(sale0), roundi(float(p.salete))])
	# Fermeture : tout le monde rentre, puis bilan du jour.
	run.call(12.0)
	_check(not bool(p.ouvert), "fermé la nuit")
	_check(parc.presents(entree) == 0, "plus personne la nuit")
	var hier: Dictionary = p.hier
	_check(int(hier.visiteurs) > 200, "bilan de la journée : %d visiteurs, %d touristes" % [int(hier.visiteurs), int(hier.touristes)])
	_check(float(hier.depenses) > 0.0, "salaires et entretien payés : %d €" % roundi(float(hier.depenses)))
	_check(int(hier.sortis) > 0 and float(hier.humeur) / int(hier.sortis) > 30.0, "humeur à la sortie : %d" % roundi(float(hier.humeur) / maxi(1, int(hier.sortis))))
	_check(float(p.note) != 2.5, "la note a bougé : %.2f" % float(p.note))
	print("    hier : ", hier)

	# Prix trop élevé : les visiteurs râlent ou font demi-tour.
	parc.set_prix(entree, 110.0)
	run.call(13.0)
	_check(int(p.jour.refus) > 0, "à 110 €, des visiteurs font demi-tour (%d)" % int(p.jour.refus))
	parc.set_prix(entree, 25.0)

	# Avis et nuisances.
	var pid := int(pop.persons.keys()[0])
	parc.sorties[pid] = parc.last_day
	var sat: Array = parc.satisfaction_of(pop.persons[pid])
	_check(float(sat[0]) > 0.0, "habitant content de sa sortie : %s" % ", ".join(sat[1]))
	var bruit := parc.pollution_sources()
	_check(not bruit.is_empty() and float(bruit[0].bruit) > 0.0, "le parc fait du bruit pour les voisins")
	_check(parc.get_groups().has("avis_sources") and parc.get_groups().has("pollution_sources"), "groupes des autres systèmes")

	# Visuels : manèges animés, clôture et allées, visiteurs.
	parc.visuels._rebuild_t = 0.0
	parc.visuels._process(0.1)
	_check(parc.visuels._anims.has(car) and (parc.visuels._anims[car] as Node3D).get_child_count() > 0, "le carrousel a ses parties mobiles")
	_check(parc.visuels._decor.has(entree) and (parc.visuels._decor[entree] as MeshInstance3D).mesh.get_surface_count() > 0, "clôture et allées dessinées")
	parc.clock = parc.clock + 0.0
	run.call(1.0)
	parc.visuels._process(0.1)
	_check(parc.visuels._corps.multimesh.instance_count == 0 or parc.presents(entree) > 0, "visiteurs dessinés")

	# Sauvegarde.
	parc.renommer(entree, "Les Folies de Test")
	parc.items[coaster].fiab = 42.0
	var dd := parc.to_dict()
	var back: Dictionary = JSON.parse_string(JSON.stringify(dd))
	parc.from_dict(back)
	_check(String(parc.parcs[entree].nom) == "Les Folies de Test", "nom du parc relu")
	_check(absf(float(parc.items[coaster].fiab) - 42.0) < 0.01, "fiabilité relue")
	_check(int(parc.parcs[entree].total.visiteurs) > 200, "cumul des visiteurs relu")

	# Panneau.
	var panel: ParcPanel = scene.parc_panel
	for v in ["parc", "attractions", "visiteurs"]:
		panel.view = v
		panel.set_open(true)
		_check(panel._body.get_child_count() > 2, "panneau, vue %s" % v)
	panel.set_open(false)
	# Démolir l'entrée ferme le parc.
	bs.demolish(entree)
	parc._sync()
	_check(not parc.parcs.has(entree) and int(parc.items[car].parc) == -1, "sans entrée, plus de parc")
	scene.queue_free()
	await process_frame
