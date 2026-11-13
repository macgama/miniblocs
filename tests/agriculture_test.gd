extends SceneTree
## Test de l'agriculture : données (cultures, machines, bêtes), champs tracés
## près d'une ferme, travaux au fil des saisons (labour, semis, engrais,
## traitement, récolte, pressage) avec des machines louées ou achetées,
## élevage (fourrage, pâture, lait, faim des bêtes), repas des habitants
## (faim, satisfaction, départs, réglage « Mortelle »), affichage et sauvegarde.
## Usage : godot --headless --path . --script res://tests/agriculture_test.gd

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


func _place(bs: BuildingSystem, id: String, x: int, north := true) -> int:
	var d := int(BuildingCatalog.get_type(id).d)
	var c := Vector2i(x, -(d / 2 + 6) if north else d / 2 + 6)
	return bs.place(id, c, bs.best_rotation(id, c))


## Fait passer des heures de jeu pour l'agriculture et l'économie.
func _heures(amb: DayNight, agri: Agriculture, prod: Production, pop: Population, n: int) -> void:
	for h in n:
		amb.unix_time += 3600.0
		pop.advance(3600.0)
		prod.advance(3600.0)
		agri.advance(3600.0)


func _run() -> void:
	Creations.persist = false
	print("Données :")
	var bad := []
	for id in AgriDonnees.CULTURES:
		var c: Dictionary = AgriDonnees.CULTURES[id]
		if String(c.plante) != "" and Plantes.id(String(c.plante)) < 0:
			bad.append("plante " + id)
		if Sols.COUCHES.find(String(c.couche)) < 0:
			bad.append("couche " + id)
		if String(c.good) != "" and not Ressources.MARCHANDISES.has(String(c.good)):
			bad.append("marchandise " + id)
		for t in ["labour", "semis", "recolte"]:
			for m in AgriDonnees.machines_pour(t, id):
				if not AgriDonnees.MACHINES.has(m):
					bad.append("machine %s pour %s" % [m, id])
	for e in AgriDonnees.ESPECES:
		for m in AgriDonnees.espece(e).modeles:
			if not Decors.existe(String(m)):
				bad.append("modèle " + String(m))
		for g in AgriDonnees.espece(e).mange:
			if not Ressources.MARCHANDISES.has(g):
				bad.append("fourrage " + g)
		for g in AgriDonnees.espece(e).donne:
			if not Ressources.MARCHANDISES.has(g):
				bad.append("produit " + g)
	for t in AgriDonnees.FERMES:
		if BuildingCatalog.get_type(t).is_empty():
			bad.append("bâtiment " + t)
	_check(bad.is_empty(), "%d cultures, %d machines, %d espèces cohérentes %s" % [AgriDonnees.CULTURES.size(),
		AgriDonnees.MACHINES.size(), AgriDonnees.ESPECES.size(), str(bad)])
	_check(AgriDonnees.saison_semis("ble", 10, 48.0, Plantes.Climat.TEMPERE) and not AgriDonnees.saison_semis("ble", 4, 48.0, Plantes.Climat.TEMPERE),
		"blé : semé en octobre dans l'hémisphère nord, pas en avril")
	_check(AgriDonnees.saison_semis("ble", 4, -35.0, Plantes.Climat.TEMPERE), "blé : semé en avril dans l'hémisphère sud")
	_check(AgriDonnees.saison_semis("riz", 1, 10.0, Plantes.Climat.TROPICAL), "riz : toute l'année sous les tropiques")
	_check(Array(AgriDonnees.machines_pour("labour", "ble")) == ["charrue", "tracteur"], "labour : charrue + tracteur")
	_check(Array(AgriDonnees.machines_pour("recolte", "ble")) == ["moissonneuse"], "moisson : moissonneuse automotrice")
	_check(Array(AgriDonnees.machines_pour("recolte", "betterave")) == ["arracheuse"], "betteraves : arracheuse")
	_check(Ressources.COMMERCES.superette.vend.has("oeufs") and Ressources.NOURRITURE.has("huile"), "œufs et huile en rayon")
	_check(ProductionTypes.prod_of("huilerie").get("kind", "") == "transformation", "huilerie : graines → huile")

	print("Scène :")
	BatimentsVie.chantiers = false
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var amb: DayNight = scene.get_node("Ambiance")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	const LAT := 49.4
	const LON := 1.1
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 40
	world.view_radius_override = 900.0
	world.set_origin(LAT, LON)
	for i in 3000:
		await process_frame
		if i >= 120 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	var prod: Production = scene.production
	var pop: Population = scene.population
	var agri: Agriculture = scene.agriculture
	_check(agri != null and prod.agri == agri and agri.repas != null, "agriculture branchée sur l'économie")
	_check(scene.agri_panel != null and scene.agri_visuels != null, "panneau (Maj+F) et affichage des champs")
	amb.set_speed(0)
	amb.unix_time = _at("2026-09-28", 8.0)
	bs.money = 2_000_000_000
	var y := world.cell_height(Vector2i(0, 0))
	_check(transport.build_segment("route", Vector3(-700, y, 0), Vector3(700, y, 0)).ok, "route est-ouest")
	var farm := _place(bs, "ferme_cereales", 300)
	var dairy := _place(bs, "ferme_laitiere", -300)
	var mill := _place(bs, "moulin", 120)
	var shop := _place(bs, "superette", 40, false)
	var carrier := _place(bs, "transporteur", -60, false)
	var homes := []
	for i in 8:
		homes.append(_place(bs, "immeuble", -560 + i * 50, false))
	_check(farm > 0 and dairy > 0 and mill > 0 and shop > 0 and carrier > 0 and not homes.has(-1),
		"ferme céréalière, ferme laitière, moulin, supérette, transporteur, 8 immeubles")
	await process_frame
	prod._sync()

	print("Champs :")
	var far := agri.verifie(Rect2i(5000, 5000, 100, 100))
	_check(not bool(far.ok) and String(far.raison).contains("ferme"), "refusé loin des fermes : « %s »" % far.raison)
	var small := agri.verifie(Rect2i(300, -200, 10, 10))
	_check(not bool(small.ok), "refusé trop petit : « %s »" % small.raison)
	var on_farm := agri.verifie(Rect2i(280, -40, 60, 40), farm)
	_check(not bool(on_farm.ok), "refusé sur la ferme ou la route : « %s »" % on_farm.raison)
	agri.culture_choisie = "ble"
	var wheat := agri.ajoute_champ(Rect2i(240, -260, 200, 150), "ble", farm)
	_check(wheat > 0 and is_equal_approx(Agriculture.surface(agri.champs[wheat]), 3.0), "champ de blé de 3 ha")
	_check(agri.ajoute_champ(Rect2i(300, -200, 60, 60), "orge", farm) < 0, "pas de champ sur un autre champ")
	_check(agri.champ_at(Vector2i(300, -200)) == wheat and world.tree_blocker.call(Vector2i(300, -200)), "pas d'arbre dans le champ")
	_check(agri.manages(farm), "la ferme est gérée par l'agriculture")
	var prairie := agri.ajoute_champ(Rect2i(-420, -300, 120, 100), "paturage", dairy)
	var foin := agri.ajoute_champ(Rect2i(-260, -300, 100, 100), "prairie", dairy)
	_check(prairie > 0 and foin > 0, "pâture et prairie de fauche pour la ferme laitière")

	print("Habitants et employés :")
	pop._sync_buildings()
	for i in 96:
		pop.advance(300.0)
	var staff := (pop.by_job.get(farm, []) as Array).size()
	_check(staff > 0, "employés de la ferme : %d" % staff)

	print("Travaux d'automne :")
	agri.clock = -1.0
	agri.last_day = -1
	agri.clock = amb.unix_time
	prod.clock = -1.0
	var cash0 := float(prod.sites[farm].cash)
	var vu_labour := false
	for h in 24 * 12:
		_heures(amb, agri, prod, pop, 1)
		for w in agri.ferme(farm).travail:
			vu_labour = vu_labour or String(w.tache) == "labour"
		if String(agri.champs[wheat].etat) == "pousse":
			break
	var ch: Dictionary = agri.champs[wheat]
	_check(vu_labour, "labour vu aux champs")
	_check(String(ch.etat) == "pousse" and String(ch.sc) == "ble", "blé semé (état %s, %s)" % [ch.etat, agri.local_time(agri.clock)])
	var mois: Dictionary = prod.sites[farm].mois
	_check(float(mois.get("Location de machines", 0.0)) < 0.0 and float(mois.get("Gazole", 0.0)) < 0.0 and float(mois.get("Semences", 0.0)) < 0.0,
		"la ferme paie location, gazole et semences (%s)" % BuildingSystem.format_money(roundi(float(prod.sites[farm].cash) - cash0)))

	print("Visible sur le terrain :")
	var vis: AgriVisuels = scene.agri_visuels
	vis.mise_a_jour()
	_check(vis._champs.has(wheat) and (vis._champs[wheat].sol as MeshInstance3D).mesh != null, "sol du champ affiché")
	var m := (vis._champs[wheat].sol as MeshInstance3D).material_override as ShaderMaterial
	_check(int(m.get_shader_parameter("couche_avant")) == Sols.LEVEE, "le blé levé se voit (couche levée)")
	ch.cr = 0.5
	ch.etat = "pousse"
	agri.champs[foin].etat = "laboure"
	ch.tache = "engrais"
	ch.fait = Agriculture.surface(ch) * 0.4
	agri.ferme(farm).travail = [{"champ": wheat, "tache": "engrais", "machines": ["loc:epandeur", "loc:tracteur"], "cult": "ble"}]
	vis.mise_a_jour()
	_check(not vis._engins.is_empty(), "un tracteur au travail sur le champ")
	var pe := AgriVisuels.position_engin(ch)
	_check((ch.r as Rect2i).grow(1).has_point(Vector2i(pe[0])), "le tracteur est dans le champ")
	ch.tache = ""
	ch.fait = 0.0
	agri.ferme(farm).travail = []

	print("Printemps et moisson :")
	ch.cr = 0.4
	ch.eng = false
	ch.tr = false
	for d in 12:
		_heures(amb, agri, prod, pop, 24)
	_check(bool(ch.eng) and bool(ch.tr), "engrais et traitement faits")
	_check(float(ch.azote) > 100.0, "azote épandu noté (%d kg/ha)" % roundi(float(ch.azote)))
	var attendu := agri.rendement(ch)
	_check(attendu > 3.0 * 4.0 and attendu < 3.0 * 9.0, "récolte attendue réaliste : %s pour 3 ha" % Ressources.format_t(attendu))
	ch.cr = 0.999
	var cereales0 := prod.stock_of(farm, "cereales") + float(prod.today.prod.get("cereales", 0.0))
	for d in 6:
		_heures(amb, agri, prod, pop, 24)
		if float(ch.rdt) > 0.0 and float(ch.paille) <= 0.0:
			break
	_check(String(ch.prec) == "ble", "blé moissonné (puis %s)" % ch.etat)
	_check(float(ch.rdt) > 10.0, "récolte : %s" % Ressources.format_t(float(ch.rdt)))
	_check(prod.stock_of(farm, "cereales") + float(prod.yesterday.prod.get("cereales", 0.0)) + float(prod.today.prod.get("cereales", 0.0)) > cereales0
		or float(prod.yesterday.export.get("cereales", 0.0)) > 0.0, "les céréales vont dans le stock de la ferme")
	_check(float(ch.paille) <= 0.0 and int(ch.get("bottes", -1)) >= 0, "paille pressée en bottes")
	_check(prod.outputs_of(farm).has("cereales"), "la ferme vend des céréales (fournisseur du moulin)")
	_check(not String(prod.sites[farm].status).begins_with("En activité ("), "statut de la ferme : %s" % prod.sites[farm].status)

	print("Machines :")
	var money0 := bs.money
	_check(agri.achete_machine(farm, "tracteur") and bs.money < money0, "tracteur acheté avec la caisse du joueur")
	var tr: Dictionary = agri.machines_de(farm)[0]
	tr.us = 0.8
	agri.revise_machine(farm, 0)
	_check(is_equal_approx(float(tr.us), 0.1), "révision : usure remise à 10 %")
	agri.champs[wheat].etat = "chaume"
	agri.champs[wheat].paille = 0.0
	amb.unix_time = _at("2026-10-05", 6.0)
	agri.clock = amb.unix_time
	agri.last_day = int(agri.local_time(agri.clock).day)
	_heures(amb, agri, prod, pop, 6)
	_check(float(tr.h) > 0.0 or agri.ferme(farm).travail.is_empty(), "le tracteur de la ferme sert au labour (%.1f h)" % float(tr.h))

	print("Élevage :")
	var n := agri.achete_betes(dairy, "vache", 40)
	_check(n == 40 and int(agri.ferme(dairy).betes.vache) == 40, "40 vaches laitières achetées")
	_check(agri.achete_betes(dairy, "porc", 10) == 0, "pas de porcs dans une ferme laitière")
	var besoin := agri.besoins_betes(dairy)
	_check(besoin.has("foin") and besoin.has("cereales"), "elles mangent foin et céréales (%s)" % str(besoin))
	_check(prod.needs_of(dairy).has("foin"), "la ferme commande du foin par camion")
	prod.put(dairy, "foin", 20.0)
	prod.put(dairy, "cereales", 5.0)
	prod.put(dairy, "paille", 5.0)
	var lait0 := prod.stock_of(dairy, "lait")
	agri.nouveau_jour(agri.local_time(agri.clock))
	_check(prod.stock_of(dairy, "lait") > lait0 + 0.3, "lait du jour : %s" % Ressources.format_t(prod.stock_of(dairy, "lait") - lait0))
	_check(prod.stock_of(dairy, "fumier") > 0.5, "fumier pour les champs")
	agri.champs[prairie].etat = "pousse"
	agri.champs[prairie].sc = "paturage"
	amb.unix_time = _at("2026-06-10", 12.0)
	agri.clock = amb.unix_time
	_check(agri.part_au_pre(dairy) > 0.0, "en juin, les vaches broutent (%d %% au pré)" % roundi(agri.part_au_pre(dairy) * 100.0))
	amb.unix_time = _at("2026-12-10", 12.0)
	agri.clock = amb.unix_time
	_check(agri.part_au_pre(dairy) == 0.0, "en décembre, à l'étable")
	for g in ["foin", "cereales", "paille"]:
		prod.put(dairy, g, -prod.stock_of(dairy, g))
	for d in 6:
		agri.nouveau_jour(agri.local_time(agri.clock))
		for g in ["foin", "cereales"]:
			prod.put(dairy, g, -prod.stock_of(dairy, g))
	_check(int(agri.ferme(dairy).betes.get("vache", 0)) < 40, "sans fourrage, des vaches meurent (%d restent)" % int(agri.ferme(dairy).betes.get("vache", 0)))
	vis.mise_a_jour()
	_check(vis._betes.has(dairy) and not (vis._betes[dairy].get("vache", []) as Array).is_empty(), "vaches visibles près de la ferme")

	print("Repas des habitants :")
	var homes_ok := 0
	for h in pop.households.values():
		if not prod._shops_for(int(h.b), "pain").is_empty():
			homes_ok += 1
	_check(pop.households.size() > 0 and homes_ok > 0, "%d foyers, %d avec un commerce à portée" % [pop.households.size(), homes_ok])
	ReglagesPartie.actuel.faim = "normale"
	var faim_vue := false
	var departs := 0
	var foyers0 := pop.households.size()
	for d in 30:
		prod.manque_foyers.clear()
		for h in pop.households.values():
			var miss := {}
			for g in Ressources.NOURRITURE:
				miss[g] = 1.0
			prod.manque_foyers[int(h.b)] = miss
		agri.repas.apres_courses()
		departs += int(agri.repas.bilan.partis)
		if d == 4:
			var p: Dictionary = pop.persons.values()[0]
			var why: Array = pop.satisfaction(p).why
			for w in why:
				faim_vue = faim_vue or String(w).contains("a faim")
			_check(float(pop.vie.health(p).f) > 0.0, "la santé tient compte de la faim")
	_check(faim_vue, "« a faim depuis … » dans la satisfaction")
	_check(departs > 0 and pop.households.size() < foyers0, "des foyers affamés quittent la ville (%d habitants partis)" % departs)
	ReglagesPartie.actuel.faim = "aucune"
	agri.repas.clear()
	prod.manque_foyers.clear()
	agri.repas.apres_courses()
	_check(agri.repas.faim.is_empty(), "réglage « Aucun effet » : personne n'a faim")
	ReglagesPartie.actuel.faim = "normale"

	print("Sauvegarde :")
	var d := agri.to_dict()
	var json := JSON.parse_string(JSON.stringify(d)) as Dictionary
	var n_champs := agri.champs.size()
	var betes := int(agri.ferme(dairy).betes.get("vache", 0))
	agri.clear()
	_check(agri.champs.is_empty(), "tout effacé")
	agri.from_dict(json)
	_check(agri.champs.size() == n_champs and agri.champs[wheat].r == Rect2i(240, -260, 200, 150), "champs relus")
	_check(int(agri.ferme(dairy).betes.get("vache", 0)) == betes and agri.machines_de(farm).size() == 1, "bêtes et machines relues")
	_check(scene.save_sections().has("agriculture"), "section « agriculture » dans la sauvegarde")
	agri.supprime_champ(foin)
	_check(not agri.champs.has(foin), "champ supprimé")

	print("AGRICULTURE TEST OK" if ok else "AGRICULTURE TEST ÉCHEC")
	quit(0 if ok else 1)
