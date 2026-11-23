extends SceneTree
## Test de l'agriculture au fil des époques et des matériaux des chantiers :
## machines agricoles datées (faux, chevaux, batteuse à vapeur, tracteur,
## moissonneuse-batteuse), cultures, élevages et marchandises datés, nouvelles
## cultures (vigne, vergers, café, cacao…), nouveaux élevages et industries,
## rendements d'époque, et matériaux consommés par les chantiers (pierre et
## chaux en 1800, béton et acier aujourd'hui), pris dans les stocks de la carte.
## Usage : godot --headless --path . --script res://tests/agri_epoques_test.gd

var ok := true


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	if not cond:
		push_error("ÉCHEC : " + what)
		ok = false
	else:
		print("  ok  ", what)


func _fake_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


func _annee(r: ReglagesPartie, a: int) -> void:
	r.annee_depart = a
	r.histoire_saut = 0
	r.histoire_debut = 0.0


func _run() -> void:
	Creations.persist = false
	var r := ReglagesPartie.preset("normal")
	r.deblocage = "tout"  # (ce test ne porte pas sur l'arbre de progression)
	ReglagesPartie.actuel = r

	print("Machines d'époque :")
	_annee(r, 1800)
	_check(Epoques.annee() == 1800, "partie en 1800")
	var m := AgriDonnees.machine("moissonneuse")
	_check(String(m.name).contains("Faux") and bool(m.get("manuel", false)), "1800 : on moissonne à la faux (%s)" % m.name)
	var t := AgriDonnees.machine("tracteur")
	_check(String(t.name).contains("chevaux") and float(t.get("litres", 1.0)) == 0.0 and float(t.get("foin_h", 0.0)) > 0.0,
		"1800 : des chevaux de trait, sans gazole, qui mangent du foin")
	_check(AgriDonnees.machines_pour("labour", "ble") == ["charrue", "tracteur"] and
		String(AgriDonnees.machine("charrue").name).contains("attelée"), "labour : charrue attelée aux chevaux")
	_check(AgriDonnees.outil("traitement", "ble") == "" and not AgriEpoques.machine_existe("pulverisateur"),
		"pas de traitement des cultures avant la bouillie bordelaise")
	_check(AgriDonnees.machines_pour("recolte", "ble") == ["moissonneuse"], "moisson à la main : ni tracteur ni attelage")
	_annee(r, 1855)
	_check(String(AgriDonnees.machine("moissonneuse").name).contains("vapeur") and
		AgriDonnees.machines_pour("recolte", "ble").has("tracteur"), "1855 : moissonneuse attelée et batteuse à vapeur")
	_annee(r, 1925)
	_check(String(AgriDonnees.machine("tracteur").name).contains("Fordson"), "1925 : tracteur à pétrole")
	_check(AgriDonnees.outil("traitement", "ble") == "pulverisateur", "1925 : pulvérisateur à dos")
	_annee(r, 1945)
	_check(String(AgriDonnees.machine("moissonneuse").name) == "Moissonneuse-batteuse tractée", "1945 : moissonneuse-batteuse tractée")
	_annee(r, 1965)
	_check(bool(AgriDonnees.machine("moissonneuse").automoteur), "1965 : moissonneuse-batteuse automotrice")
	_annee(r, 2020)
	_check(AgriDonnees.machine("moissonneuse").name == AgriDonnees.MACHINES.moissonneuse.name, "2020 : la machine moderne")
	_check(String(AgriDonnees.machine("tracteur").name).contains("GPS") and String(AgriDonnees.machine("pulverisateur").name).contains("Drone"),
		"2020 : tracteur guidé par GPS et drone de pulvérisation")
	_annee(r, 2040)
	_check(String(AgriDonnees.machine("tracteur").name).contains("autonome") and float(AgriDonnees.machine("tracteur").litres) == 0.0,
		"2040 : tracteur autonome électrique")
	_check(AgriEpoques.culture_disponible("quinoa") and AgriEpoques.espece_disponible("insectes"), "2040 : quinoa et insectes")
	_annee(r, 0)
	_check(AgriDonnees.machine("tracteur") == AgriDonnees.MACHINES.tracteur, "époque actuelle : rien ne change")
	for id in AgriEpoques.VERSIONS:
		_check(AgriDonnees.MACHINES.has(id), "versions d'époque pour une vraie machine : %s" % id)

	print("Cultures, bêtes et marchandises datées :")
	_annee(r, 1800)
	_check(not AgriEpoques.culture_disponible("soja") and not AgriEpoques.culture_disponible("betterave"),
		"1800 : ni soja ni betterave sucrière")
	_check(AgriEpoques.culture_disponible("ble") and AgriEpoques.culture_disponible("vigne"), "1800 : blé et vigne")
	_check(not AgriEpoques.espece_disponible("pisciculture"), "1800 : pas encore de pisciculture")
	_check(not Ressources.disponible("plastique") and not Ressources.disponible("electronique") and not Ressources.disponible("carburant"),
		"1800 : ni plastique, ni électronique, ni carburant")
	_check(Ressources.disponible("pain") and Ressources.disponible("chaux"), "1800 : pain et chaux")
	var f1800 := AgriDonnees.facteur_epoque()
	_check(f1800 > 0.1 and f1800 < 0.25, "rendements de 1800 : %d %% d'aujourd'hui" % roundi(f1800 * 100.0))
	_annee(r, 1960)
	_check(AgriEpoques.culture_disponible("soja") and Ressources.disponible("plastique"), "1960 : soja et plastique")
	_annee(r, 0)
	_check(is_equal_approx(AgriDonnees.facteur_epoque(), 1.0), "époque actuelle : rendements d'aujourd'hui")

	print("Nouvelles cultures, élevages et industries :")
	var nouv_c := ["vigne", "verger", "agrumes", "olivier", "houblon", "tabac", "cafe", "cacao", "the", "canne"]
	var bad := []
	for id in nouv_c:
		var c := AgriDonnees.culture(id)
		if c.is_empty() or not Ressources.MARCHANDISES.has(String(c.good)) or not AgriDonnees.ORDRE_CULTURES.has(id):
			bad.append(id)
		if Plantes.id(String(c.get("plante", ""))) < 0 or Sols.COUCHES.find(String(c.get("couche", ""))) < 0:
			bad.append(id + " (visuel)")
		for k in ["semis_m", "recolte_m"]:
			if not AgriDonnees.MACHINES.has(String(c.get(k, ""))):
				bad.append("%s (%s)" % [id, k])
	_check(bad.is_empty(), "%d nouvelles cultures complètes %s" % [nouv_c.size(), str(bad)])
	var nouv_e := ["canard", "dinde", "lapin", "abeille", "pisciculture", "buffle", "lama", "renne"]
	bad = []
	for e in nouv_e:
		var sp := AgriDonnees.espece(e)
		if sp.is_empty() or not AgriDonnees.ORDRE_ESPECES.has(e):
			bad.append(e)
			continue
		for g in sp.donne:
			if not Ressources.MARCHANDISES.has(g):
				bad.append("%s→%s" % [e, g])
		for mo in sp.modeles:
			if Decors.mesh(String(mo)) == null:
				bad.append("%s (modèle %s)" % [e, mo])
		var loge := false
		for fid in AgriDonnees.FERMES:
			if (AgriDonnees.FERMES[fid].betes as Dictionary).has(e):
				loge = true
		if not loge:
			bad.append(e + " (aucune ferme)")
	_check(bad.is_empty(), "%d nouveaux élevages complets %s" % [nouv_e.size(), str(bad)])
	var nouv_b := ["vignoble", "verger", "oliveraie", "plantation_tropicale", "houblonniere", "basse_cour", "rucher",
		"pisciculture", "ranch_buffles", "elevage_andin", "elevage_rennes", "four_chaux", "tuilerie", "cave_vinicole",
		"distillerie", "rhumerie", "chocolaterie", "torrefaction", "fromagerie_alpage", "conserverie", "tannerie",
		"manufacture_tabac", "horlogerie", "chantier_naval", "usine_engrais", "recyclerie_metaux", "usine_batteries"]
	bad = []
	for id in nouv_b:
		var bt := BuildingCatalog.get_type(id)
		if bt.is_empty() or not bt.has("prod"):
			bad.append(id)
			continue
		for side in ["in", "out"]:
			for g in bt.prod.get(side, {}):
				if not Ressources.MARCHANDISES.has(g):
					bad.append("%s : %s" % [id, g])
		if String(Production.kind_of(id)) == "":
			bad.append(id + " (pas un site)")
	_check(bad.is_empty(), "%d nouveaux bâtiments de production cohérents %s" % [nouv_b.size(), str(bad)])
	_check(AgriDonnees.est_ferme("vignoble") and AgriDonnees.est_ferme("rucher"), "domaine viticole et rucher sont des fermes")
	_check(Epoques.annee_batiment("usine_engrais") == 1913 and Epoques.annee_batiment("chocolaterie") == 1820,
		"usine d'engrais en 1913, chocolaterie en 1820")
	_annee(r, 1800)
	_check(not Epoques.batiment_disponible("usine_batteries") and Epoques.batiment_disponible("four_chaux"),
		"1800 : four à chaux oui, usine de batteries non")
	_check(Production.recipe_text("chocolaterie").contains("cacao"), "recette : %s" % Production.recipe_text("chocolaterie"))

	print("Matériaux des chantiers :")
	var b1800 := MateriauxChantiers.besoins_batiment("maison", 1800)
	var b2000 := MateriauxChantiers.besoins_batiment("maison", 2000)
	_check(b1800.has("pierre") and b1800.has("chaux") and b1800.has("bois") and not b1800.has("ciment"),
		"maison de 1800 : %s" % MateriauxChantiers.texte(b1800))
	_check(b2000.has("ciment") and b2000.has("acier") and not b2000.has("chaux"), "maison de 2000 : %s" % MateriauxChantiers.texte(b2000))
	var total := 0.0
	for g in b2000:
		total += float(b2000[g])
	var surf := float(BuildingCatalog.get_type("maison").w) * float(BuildingCatalog.get_type("maison").d)
	_check(total > surf * 0.3 and total < surf * 6.0, "ordre de grandeur réaliste : %d t pour %d m² au sol" % [roundi(total), roundi(surf)])
	var v := MateriauxChantiers.besoins_voie("departementale", 100.0, 8.0, 1800)
	_check(float(v.get("pierre", 0.0)) > 100.0, "100 m de route en 1800 : %s" % MateriauxChantiers.texte(v))
	var rail := MateriauxChantiers.besoins_voie("train", 100.0, 4.0, 1880)
	_check(rail.has("acier") and rail.has("bois"), "voie ferrée de 1880 : rails d'acier et traverses en bois")

	print("Chantier de 1800 :")
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var bs: BuildingSystem = scene.get_node("Batiments")
	root.add_child(scene)
	world.tiles.offline_generator = _fake_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.set_origin(48.8584, 2.2945)
	for i in 90:
		await process_frame
	var vie: BatimentsVie = scene.get_node("VieBatiments")
	var amb: DayNight = scene.get_node("Ambiance")
	var prod: Production = scene.production
	amb.set_speed(0)
	ReglagesPartie.actuel = r
	_annee(r, 1800)
	BatimentsVie.chantiers = true
	bs.require_access = false
	bs.unlimited_money = false
	# Ce test vérifie le surcoût payé par la caisse : la ville paie tout (sans promoteurs privés).
	ReglagesPartie.actuel.promoteurs_prives = false
	bs.money = 50_000_000
	# Une carrière avec de la pierre en stock, et rien d'autre.
	var carr := bs.place("carriere", Vector2i(300, 300), 0)
	_check(carr > 0, "carrière posée")
	prod._sync()
	_check(prod.sites.has(carr), "la carrière est un site de production")
	prod.sites[carr].st["pierre"] = 5000.0
	var cash0 := float(prod.sites[carr].cash)
	var bid := bs.place("maison", Vector2i(-60, 60), 0)
	if bid < 0:
		bid = bs.place("colombages__maison", Vector2i(-60, 60), 0)
	_check(bid > 0 and bs.en_chantier(bid), "maison posée : chantier ouvert")
	var lundi := float(Time.get_unix_time_from_datetime_string("2026-03-02T07:30:00")) - amb.utc_offset() * 3600.0
	amb.unix_time = lundi
	vie._t_prev = lundi
	var b: Dictionary = bs.buildings[bid]
	var hjeu := float(b.hr) / Chantiers.rythme(vie.population)
	amb.unix_time = Chantiers.date_apres(lundi, hjeu * 0.5, amb.utc_offset())
	vie._update_chantiers()
	var mat := vie.materiaux_de(bid)
	_check(float(b.get("av", 0.0)) > 0.4, "chantier à mi-parcours (%d %%)" % roundi(float(b.get("av", 0.0)) * 100.0))
	_check(float((mat.local as Dictionary).get("pierre", 0.0)) > 0.0, "pierre prise à la carrière : %s" % Ressources.format_t(
		float((mat.local as Dictionary).get("pierre", 0.0))))
	_check(float(prod.sites[carr].st.get("pierre", 0.0)) < 5000.0, "le stock de la carrière baisse")
	_check(float(prod.sites[carr].cash) > cash0, "la carrière est payée par le chantier")
	_check(float((mat.import as Dictionary).get("chaux", 0.0)) > 0.0, "chaux importée (pas de four à chaux)")
	_check(absf(MateriauxChantiers.surcout_tonne("chaux") - Ressources.price("chaux") * (Ressources.IMPORT - 1.0)) < 1.0,
		"import : %.0f € de plus par tonne de chaux" % MateriauxChantiers.surcout_tonne("chaux"))
	_check(int(mat.get("surcout", 0)) > 0, "surcoût des imports payé par la caisse : %s" % BuildingSystem.format_money(int(mat.get("surcout", 0))))
	_check(vie.texte_chantier(bid).contains("importées"), "info-bulle : part importée")
	_check(not (mat.total as Dictionary).has("ciment"), "pas de ciment en 1800")
	var node := bs.node_of(bid)
	_check(node != null and vie.texte_chantier(bid).contains("Matériaux"), "détail du chantier (info-bulle) : matériaux")
	vie.finish_all()
	_check(not bs.buildings[bid].has("matx"), "chantier fini : bilan des matériaux effacé (sauvegarde légère)")
	# Le toit ne compte pas comme un étage : même plancher que pour la durée du chantier.
	var m1800 := MateriauxChantiers.besoins_batiment("maison", 1800)
	var t1800 := 0.0
	for g in m1800:
		t1800 += float(m1800[g])
	_check(absf(t1800 - Chantiers.plancher_batiment("maison") * 1.10) < 1.0 and t1800 < 260.0,
		"maison de 1800 : %d t pour %d m² de plancher" % [roundi(t1800), roundi(Chantiers.plancher_batiment("maison"))])

	print("Camions de livraison des chantiers :")
	var transport: TransportSystem = scene.get_node("Transport")
	var ya := world.cell_height(Vector2i(0, 0))
	r.deblocage = "tout"  # (la route n'est pas le sujet : pas d'arbre de progression)
	# Relief chargé tout autour avant de tracer la route.
	for i in 600:
		await process_frame
		if world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	ya = world.cell_height(Vector2i(0, 0))
	var plan_route := transport.build_segment("route", Vector3(-250, ya, 0), Vector3(400, ya, 0))
	_check(plan_route.ok, "route est-ouest (%s)" % String(plan_route.get("reason", "")))
	(scene.get_node("Chantiers") as SuiviChantiers).terminer_tout()  # route ouverte tout de suite
	prod.sites[carr].st["pierre"] = 0.0
	var dc := int(BuildingCatalog.get_type("carriere").d)
	var carr2 := bs.place("carriere", Vector2i(300, -(dc / 2 + 6)), bs.best_rotation("carriere", Vector2i(300, -(dc / 2 + 6))))
	_check(carr2 > 0, "carrière au bord de la route")
	prod._sync()
	prod.sites[carr2].st["pierre"] = 5000.0
	var env0 := LivraisonsChantiers.envoyes
	var id2 := "maison" if Epoques.batiment_disponible("maison") else "colombages__maison"
	var c2 := Vector2i(-100, -(int(BuildingCatalog.get_type(id2).d) / 2 + 6))
	var bid2 := bs.place(id2, c2, bs.best_rotation(id2, c2))
	_check(bid2 > 0 and bs.en_chantier(bid2), "deuxième maison au bord de la route")
	vie._t_prev = amb.unix_time
	var b2: Dictionary = bs.buildings[bid2]
	var hjeu2 := float(b2.hr) / Chantiers.rythme(vie.population)
	amb.unix_time = Chantiers.date_apres(amb.unix_time, hjeu2 * 0.6, amb.utc_offset())
	vie._update_chantiers()
	var tr := prod._traffic()
	var n_camions := 0
	if tr != null:
		for veh in tr.vehicles:
			if int(veh.get("delivery", 0)) <= LivraisonsChantiers.TAG:
				n_camions += 1
	_check(LivraisonsChantiers.envoyes > env0 and (tr == null or n_camions > 0),
		"des camions livrent le chantier (%d partis, %d sur la route)" % [LivraisonsChantiers.envoyes - env0, n_camions])
	vie.finish_all()

	print("Ferme de 1800 :")
	var agri: Agriculture = prod.agri
	var ferme := bs.place("ferme_cereales", Vector2i(-300, -300), 0)
	_check(ferme > 0, "ferme céréalière posée")
	prod._sync()
	var champ := agri.ajoute_champ(Rect2i(Vector2i(-300, -180), Vector2i(100, 100)), "soja", ferme)
	_check(champ >= 0 and String(agri.champs[champ].cult) == "ble", "en 1800, du blé au lieu du soja")
	var ch: Dictionary = agri.champs[champ]
	ch.etat = "pousse"
	ch.sc = "ble"
	ch.eng = true
	ch.tr = false
	ch.azote = 170.0
	ch.met = 1.0
	var rd := agri.rendement(ch)
	_check(rd / Agriculture.surface(ch) < 1.6, "rendement du blé en 1800 : %.1f t/ha" % (rd / Agriculture.surface(ch)))
	var achete := agri.achete_machine(ferme, "pulverisateur")
	_check(not achete, "pas de pulvérisateur à acheter en 1800")
	var achat := agri.achete_machine(ferme, "tracteur")
	var parc := agri.machines_de(ferme)
	_check(achat and not parc.is_empty() and String(parc[-1].get("nom", "")).contains("chevaux"),
		"« tracteur » de 1800 : une paire de chevaux (%s, %s)" % [achat, str(parc)])
	# Vigne : plantée une fois, récoltée, puis au repos jusqu'à la reprise.
	var vigne := agri.ajoute_champ(Rect2i(Vector2i(-180, -300), Vector2i(60, 60)), "vigne", ferme)
	var cv: Dictionary = agri.champs[vigne]
	cv.etat = "mur"
	cv.sc = "vigne"
	cv.eng = true
	cv.tr = true
	cv.reveil = true
	agri._recolte(ferme, vigne)
	_check(String(cv.etat) == "pousse" and String(cv.sc) == "vigne" and not bool(cv.reveil), "vendangée : la vigne reste et se repose")
	_check(prod.stock_of(ferme, "raisin") > 0.0, "raisin dans le stock de la ferme (%s)" % Ressources.format_t(prod.stock_of(ferme, "raisin")))
	_check(agri.tache_due(cv, 12) == "", "rien à faire à la vigne en décembre")

	ReglagesPartie.actuel = ReglagesPartie.preset("normal")
	ReglagesPartie.actuel.deblocage = "tout"  # (ce test ne porte pas sur l'arbre de progression)
	print("TEST OK" if ok else "TEST ÉCHEC")
	quit(0 if ok else 1)
