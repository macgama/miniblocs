extends SceneTree
## Test d'internet et du téléphone : catalogue, cuivre le long des routes et
## ADSL selon la distance, fibre (rue fibrée, tracé libre, poteaux), antennes
## 2G / 4G / 5G et saturation, satisfaction, rendement des entreprises,
## budget, réglage Admin, sauvegarde.
## Usage : godot --headless --path . --script res://tests/telecom_test.gd

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
	print("Catalogue :")
	for id in TelecomTypes.ORDER:
		var t := BuildingCatalog.get_type(id)
		_check(t.get("cat", "") == "services" and t.has("telecom"), "%s dans les services publics" % id)
		var m := BuildingCatalog.build_mesh(id)
		_check(m != null and m.get_surface_count() > 0, "%s a un modèle low-poly" % id)
	_check(Telecom.lignes_of("maison") == 1 and Telecom.lignes_of("immeuble") == 12 and Telecom.lignes_of("parc") == 0,
		"lignes demandées : maison 1, immeuble 12, parc 0")
	_check(Telecom.debit_adsl(500.0) == 20.0 and Telecom.debit_adsl(2500.0) == 6.0 and Telecom.debit_adsl(9000.0) < 0.1,
		"ADSL : 20 Mb/s près du central, 6 Mb/s à 2,5 km, presque rien à 9 km")

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
	var tel: Telecom = scene.telecom
	_check(tel != null and scene.telecom_panel != null, "réseau télécom et panneau branchés dans la scène")
	tel.set_process(false)
	bs.unlimited_money = true
	ReglagesPartie.actuel.telecom_necessaire = true
	var y := world.cell_height(Vector2i(0, 0))
	var road := transport.build_segment("route", Vector3(-1500, y, 0), Vector3(1500, y, 0))
	_check(road.ok, "route de 3 km")
	var near := _place(bs, "maison", -1200)
	var mid := _place(bs, "maison", 300)
	var far := _place(bs, "maison", 1400)
	var bureau := _place(bs, "bureaux", -1100, false)
	_check(near > 0 and mid > 0 and far > 0 and bureau > 0, "trois maisons et des bureaux posés")
	tel.recalculer()
	_check(tel.qualite(near) == "rien" and not tel.service[near].fixe, "sans central ni antenne : ni internet ni téléphone")
	_check(tel.rendement(bureau) < 0.5, "bureaux sans internet : rendement %.2f" % tel.rendement(bureau))

	# Satisfaction d'un habitant de la maison (foyer fictif).
	var pop: Population = scene.population
	pop.households[987654] = {"b": near}
	var p := {"f": 987654}
	var sat := tel.satisfaction_of(p)
	_check(float(sat[0]) <= -10.0 and (sat[1] as Array).size() == 2, "habitant sans internet ni mobile : %d (%s)" % [int(sat[0]), ", ".join(sat[1])])
	var chained: Array = pop.extra_satisfaction.call(p)
	_check(float(chained[0]) <= float(sat[0]) + 0.01 and (chained[1] as Array).has("− pas d'internet à la maison"),
		"branché sur la satisfaction de Population (sans le fil Avis)")
	_check(tel.avis_facteurs().size() == 1 and tel.is_in_group("avis_sources"), "facteur proposé au fil Avis")

	print("Cuivre et ADSL :")
	var central := _place(bs, "central_telephonique", -1250, false)
	_check(central > 0, "central téléphonique posé")
	tel.recalculer()
	_check(tel.service[near].fixe and tel.qualite(near) == "adsl", "maison près du central : téléphone et ADSL (%s)" % tel.info_of(near))
	_check(is_equal_approx(tel.service[near].adsl, 20.0), "ADSL à 20 Mb/s près du central")
	_check(tel.service[mid].adsl < tel.service[near].adsl and tel.service[mid].adsl >= 6.0, "à 1,5 km : %.0f Mb/s" % tel.service[mid].adsl)
	_check(tel.qualite(far) == "lent", "à 2,6 km : internet lent (%s)" % Telecom.format_debit(tel.service[far].net))
	_check(tel.rendement(bureau) == 1.0, "bureaux avec l'ADSL : rendement normal")
	var prod: Production = scene.production
	_check(prod._rendement(bureau) == 1.0, "Production lit le rendement des réseaux")

	# Une ferme loin de la route : poteaux téléphoniques.
	bs.require_access = false
	var ferme := bs.place("maison", Vector2i(-1000, 300), 0)
	bs.require_access = true
	tel.recalculer()
	_check(ferme > 0 and not tel.service[ferme].fixe, "maison à 300 m de la route : pas de ligne")
	var dp := tel._pos_of(bs.buildings[ferme])
	var ligne := tel._segment(Vector3(dp.x, y, 2.0), dp)
	ligne.insert(0, Vector3(dp.x, y, 2.0))
	var lid := tel.poser_cable("cuivre_aerien", ligne)
	tel.recalculer()
	_check(lid > 0 and tel.service[ferme].fixe, "ligne sur poteaux : la ferme a le téléphone")
	_check(tel._poteaux.mesh != null, "poteaux et fils dessinés")

	print("Fibre :")
	var fid := tel.fibrer_rue(Vector3(-800, y, 3))
	_check(fid > 0, "rue fibrée d'un clic")
	_check(tel.fibrer_rue(Vector3(-700, y, 3)) == -1, "pas deux fois la même rue")
	tel.recalculer()
	_check(tel.qualite(near) == "fibre" and tel.service[near].net >= 999.0, "fibre 1 Gb/s (%s)" % tel.info_of(near))
	_check(tel.qualite(far) == "fibre", "toute la rue est fibrée, jusqu'au bout")
	sat = tel.satisfaction_of(p)
	_check((sat[1] as Array).has("+ fibre optique à la maison"), "la fibre rend content")
	_check(tel.info_of(central).contains("lignes fibre"), "fiche du central : lignes servies")

	print("Mobile :")
	var p4 := _place(bs, "pylone_4g", 0)
	tel.recalculer()
	_check(p4 > 0 and tel.service[near].gen == "4g" and tel.service[far].gen == "4g", "pylône 4G : couverture à 1,4 km")
	_check(tel.service[near].mob < tel.service[mid].mob, "débit mobile plus faible loin de l'antenne")
	var a5 := _place(bs, "antenne_5g", 1300, false)
	tel.recalculer()
	_check(a5 > 0 and tel.service[far].gen == "5g" and tel.service[near].gen == "4g", "petite antenne 5G : seulement à 450 m")
	var b := tel.bilan()
	_check(int(b.antennes) == 2 and int(b.gen["5g"]) >= 1, "bilan : 2 antennes, de la 5G")
	# Saturation : une tour derrière une petite antenne 2G seule.
	bs.demolish(p4)
	bs.demolish(a5)
	var p2 := _place(bs, "pylone_2g", 500)
	var tours := []
	for i in 4:
		tours.append(_place(bs, "tour_habitation", 560 + i * 26, false))
	tel.recalculer()
	_check(not tours.has(-1) and tel.service[tours[0]].gen == "2g", "quatre tours couvertes en 2G")
	_check(tel.service[tours[0]].taux_mob < 1.0 and int(tel.bilan().satures) == 1, "pylône 2G saturé (%d abonnés pour 400)" % int(tel.charge["%d:0" % p2].abonnes))

	print("Budget et Admin :")
	var ent := tel.budget_entretien()
	var rec := tel.budget_recettes()
	_check(int(ent.get("Antennes et centraux téléphoniques", 0)) > 0 and int(ent.get("Câbles téléphoniques et fibre", 0)) > 0, "entretien : %s" % str(ent))
	_check(int(rec.get("Abonnements internet et téléphone", 0)) > 0, "abonnements : %s" % str(rec))
	_check(tel.is_in_group("budget_entretien") and tel.is_in_group("budget_recettes"), "proposé au budget communal")
	ReglagesPartie.actuel.telecom_necessaire = false
	_check(float(tel.satisfaction_of(p)[0]) == 0.0 and tel.rendement(ferme) == 1.0, "réglage Admin coupé : aucun effet")
	ReglagesPartie.actuel.telecom_necessaire = true
	var r2 := ReglagesPartie.new()
	r2.from_dict({"telecom_necessaire": false})
	_check(not r2.telecom_necessaire and r2.to_dict().has("telecom_necessaire"), "réglage gardé dans la sauvegarde")

	print("Argent :")
	bs.unlimited_money = false
	bs.money = 100
	_check(tel.poser_cable("fibre", tel._segment(Vector3(0, y, 50), Vector3(200, y, 50))) == -1, "pas assez d'argent : câble refusé")
	bs.money = 1_000_000
	var before := bs.money
	var seg := PackedVector3Array([Vector3(0, y, 50), Vector3(100, y, 50)])
	var cid := tel.poser_cable("fibre", seg)
	_check(cid > 0 and before - bs.money == Telecom.prix_cable("fibre", 100.0), "100 m de fibre payés %s" % BuildingSystem.format_money(before - bs.money))
	_check(tel.retirer_pres(Vector3(50, y, 52)) and not tel.fibre.troncons.has(cid), "câble retiré d'un clic")
	bs.unlimited_money = true

	print("Calques :")
	tel.set_calque("mobile")
	_check(tel._calque_mesh.mesh != null, "calque de couverture mobile")
	tel.set_calque("debit")
	_check(tel._calque_mesh.mesh != null, "calque du débit des bâtiments")
	tel.set_calque("")

	print("Sauvegarde :")
	var nf := tel.fibre.troncons.size()
	var nc := tel.cuivre.troncons.size()
	pop.households.erase(987654)
	var data: Dictionary = JSON.parse_string(JSON.stringify(scene.save_sections().telecom))
	tel.clear()
	_check(tel.fibre.troncons.is_empty(), "réseau vidé")
	tel.from_dict(data)
	_check(tel.fibre.troncons.size() == nf and tel.cuivre.troncons.size() == nc, "câbles rechargés (%d fibre, %d cuivre)" % [nf, nc])
	_check(tel.qualite(near) == "fibre" and tel.service[ferme].fixe, "service retrouvé après chargement")

	print("TEST OK" if ok else "TEST ÉCHEC")
	quit(0 if ok else 1)
