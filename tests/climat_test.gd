extends SceneTree
## Test du climat et de la pollution à long terme : courbes et scénarios du
## réchauffement, intensité des filières et du réseau national, bilan carbone
## d'une ville (électricité, chauffage, transport, industrie, agriculture),
## sols pollués (dépôt, guérison, santé, récoltes, valeur), mesures datées du
## plan climat (nuisances, budget), météo décalée, montée de la mer et
## submersion, époques (1850 → 2100), réglages Admin, panneau, sauvegarde.
## Usage : godot --headless --path . --script res://tests/climat_test.gd

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


func _place(bs: BuildingSystem, id: String, x: int, north := true, off := 6) -> int:
	var d := int(BuildingCatalog.get_type(id).d)
	var c := Vector2i(x, -(d / 2 + off) if north else d / 2 + off)
	return bs.place(id, c, bs.best_rotation(id, c))


func _run() -> void:
	_static_tests()
	await _city_tests()
	print("TEST OK" if ok else "TEST ÉCHEC")
	quit(0 if ok else 1)


func _static_tests() -> void:
	print("Courbes et données :")
	_check(absf(ClimatTypes.histoire(1850) - 0.0) < 0.01 and absf(ClimatTypes.histoire(2026) - 1.45) < 0.01
		and ClimatTypes.histoire(1815) < 0.0, "histoire réelle : 0 °C en 1850, −0,3 °C en 1815 (Tambora), +1,45 °C en 2026")
	_check(ClimatTypes.scenario(2100, 0.0) < 2.0 and absf(ClimatTypes.scenario(2100, 1.0) - 2.7) < 0.01 and ClimatTypes.scenario(2100, 2.0) > 4.0,
		"scénarios 2100 : sobre < 2 °C, médian 2,7 °C, fossile > 4 °C")
	_check(ClimatTypes.scenario_de(1.0) == 0.0 and absf(ClimatTypes.scenario_de(6.0) - 1.0) < 0.01 and ClimatTypes.scenario_de(20.0) == 2.0,
		"émissions par habitant → scénario")
	var mer := ClimatTypes.mer_histoire(2026)
	_check(mer > 15.0 and mer < 35.0 and ClimatTypes.mer_histoire(1850) < 0.0, "mer : +%d cm depuis 1900" % roundi(mer))
	_check(ClimatTypes.filiere("centrale_charbon_locale") == "charbon" and ClimatTypes.filiere("eolienne") == "eolien"
		and ClimatTypes.filiere("centrale_solaire") == "solaire" and ClimatTypes.filiere("poste_national") == "national"
		and ClimatTypes.filiere("batteries") == "", "filières des centrales")
	_check(ClimatTypes.intensite_nationale(2020, "fr") < 0.1 and ClimatTypes.intensite_nationale(2020, "pl") > 0.6
		and ClimatTypes.intensite_nationale(1900, "fr") > 1.0, "réseau national : France nucléaire, Pologne charbon, tout au charbon en 1900")
	_check(ClimatTypes.intensite_nationale(2050, "de", 0.0) < ClimatTypes.intensite_nationale(2050, "de", 2.0), "en 2050, le réseau suit le scénario")
	_check(ClimatTypes.intensite_industrie("cimenterie") > ClimatTypes.intensite_industrie("usine") and ClimatTypes.intensite_industrie("maison") == 0.0
		and ClimatTypes.intensite_industrie("centrale_charbon") == 0.0, "industries (la centrale passe par le mix)")
	_check(ClimatTypes.famille("acierie") == "industrie" and ClimatTypes.famille("porcherie") == "ferme" and ClimatTypes.famille("maison") == "",
		"familles pour les mesures")
	_check(ClimatTypes.courbe(ClimatTypes.VOITURE, 1850) == 0.0 and ClimatTypes.courbe(ClimatTypes.VOITURE, 1950) > ClimatTypes.courbe(ClimatTypes.VOITURE, 2040),
		"voitures : rien avant le moteur, moins à l'ère électrique")
	_check(not ClimatTypes.mesure_disponible("zfe", 1990) and ClimatTypes.mesure_disponible("zfe", 2016)
		and ClimatTypes.mesure_disponible("filtres_usines", 1910), "mesures datées")
	for id in ClimatTypes.ORDRE_MESURES:
		_check(ClimatTypes.MESURES.has(id), "mesure %s décrite" % id)
	_check(ClimatTypes.MESURES.size() == ClimatTypes.ORDRE_MESURES.size(), "toutes les mesures dans l'ordre")
	_check(Icones.SVG.has("climat"), "icône climat")
	Meteo.ecart_climat = 0.0
	var t0 := Meteo.air_temperature(46.5, 1.7e9, 15.0, 400.0)
	Meteo.ecart_climat = 2.0
	_check(absf(Meteo.air_temperature(46.5, 1.7e9, 15.0, 400.0) - t0 - 2.0) < 0.001, "la météo suit le décalage du climat")
	Meteo.ecart_climat = 0.0
	var r := ReglagesPartie.new()
	_check(r.climat == 2 and r.sols_pollues, "Admin : le monde suit vos villes, sols pollués (par défaut)")
	r.climat = 3
	r.sols_pollues = false
	var r2 := r.duplicate_settings()
	_check(r2.climat == 3 and not r2.sols_pollues, "réglages sauvegardés")


func _city_tests() -> void:
	print("Ville :")
	Creations.persist = false
	BatimentsVie.chantiers = false
	ReglagesPartie.actuel = ReglagesPartie.preset("normal")
	ReglagesPartie.actuel.deblocage = "tout"  # (ce test ne porte pas sur l'arbre de progression)
	ReglagesPartie.actuel.construction_instantanee = true
	ReglagesPartie.actuel.reseaux_obligatoires = false
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var amb: DayNight = scene.get_node("Ambiance")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 10
	world.view_radius_override = 1150.0
	world.set_origin(46.5, 6.6)
	for i in 3000:
		await process_frame
		if i >= 120 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	amb.set_speed(0)
	var cl: Climat = scene.climat
	var pop: Population = scene.population
	_check(cl != null and Climat.instance == cl and scene.climat_panel != null, "module Climat et panneau dans la scène")
	pop.arrivals = false
	bs.money = 2_000_000_000
	var y := world.cell_height(Vector2i(0, 0))
	var road := transport.build_segment("departementale", Vector3(-950, y, 0), Vector3(950, y, 0))
	_check(road.ok, "départementale")
	var steel := _place(bs, "acierie", -700)
	var near := _place(bs, "maison", -700, false)
	var far := _place(bs, "maison", 700, false)
	var ferme := _place(bs, "porcherie", 400)
	var parc := _place(bs, "parc", 700)
	_check(steel > 0 and near > 0 and far > 0 and ferme > 0 and parc > 0, "aciérie, maisons, porcherie, parc")
	pop._sync_buildings()
	for i in 6:
		pop.spawn_household(near if i % 2 == 0 else far)
	# Ouvriers à l'aciérie.
	for pid in pop.persons:
		var p: Dictionary = pop.persons[pid]
		if int(p.get("job", -1)) < 0 and pop.free_jobs(steel) > 0:
			pop._join_job(p, steel)
	cl.clear()
	for d in 3:
		cl.simuler_jour()
	var m := cl.moyenne()
	print("  bilan : ", m.t)
	_check(float(m.t.get("industrie", 0.0)) > 0.0, "l'aciérie émet du CO₂ (%s t/j)" % String.num(float(m.t.get("industrie", 0.0)), 1))
	_check(float(m.t.get("agriculture", 0.0)) > 0.0, "la porcherie émet du méthane")
	_check(float(m.t.get("chauffage", 0.0)) > 0.0, "les foyers se chauffent")
	_check(float(m.t.get("absorption", 0.0)) < 0.0 and cl.forets_ha > 0.0, "la forêt autour absorbe (%d ha)" % roundi(cl.forets_ha))
	_check(cl.parcs_ha > 0.0, "le parc compte")
	_check(cl.jours.size() == 3 and not cl.annees.is_empty() and cl.cumul != 0.0, "historique des jours et de l'année")
	_check(not is_nan(cl.ecart_monde) and absf(cl.ecart_monde - 1.45) < 0.2, "réchauffement d'aujourd'hui (%s °C)" % String.num(cl.ecart_monde, 2))

	print("Électricité :")
	var e := cl.emissions_heure(2020.0)
	var mix: Dictionary = e.mix
	_check(float(mix.get("national", 0.0)) > 0.0 or scene.reseaux.elec.consos.is_empty(), "réseaux non obligatoires : le courant vient du réseau national")
	ReglagesPartie.actuel.reseaux_obligatoires = true

	print("Sols :")
	var pn := BuildingSystem.rect_center(bs._rect_of(bs.buildings[near]))
	var ps := BuildingSystem.rect_center(bs._rect_of(bs.buildings[steel]))
	var pf := BuildingSystem.rect_center(bs._rect_of(bs.buildings[far]))
	for i in 200:
		cl._sols_jour(2020.0)
	_check(cl.sol_at(ps.x, ps.z) > 0.2 and cl.sol_at(pf.x, pf.z) < 0.02, "le sol se pollue près de l'aciérie (%.2f), pas loin (%.2f)" % [cl.sol_at(ps.x, ps.z), cl.sol_at(pf.x, pf.z)])
	_check(cl.sols_pollues_ha() > 0.0 and not cl.points_noirs().is_empty(), "hectares et points noirs")
	_check(cl.risque_sol(ps) > 0.02, "un sol pollué rend un peu malade")
	var nz: Nuisances = scene.nuisances
	nz.recalculer()
	_check(nz.sante(near) >= cl.risque_sol(pn) - 0.0001, "santé des habitants : le sol compte (Nuisances.sante)")
	var src := cl.pollution_sources()
	_check(not src.is_empty() and float(src[0].salete) > 0.0, "sol pollué → saleté (valeur des terrains)")
	var ch := {"r": Rect2i(int(ps.x) - 20, int(ps.z) - 20, 40, 40)}
	_check(cl.facteur_champ(ch) < 0.97, "récoltes plus maigres sur sol pollué (×%.2f)" % cl.facteur_champ(ch))
	var avant := cl.sol_at(ps.x, ps.z)
	ReglagesPartie.actuel.sols_pollues = true
	bs.demolish(steel)
	for i in 30:
		cl._sols_jour(2020.0)
	var lent := cl.sol_at(ps.x, ps.z)
	_check(lent < avant and lent > avant * 0.9, "le sol guérit lentement tout seul (%.3f → %.3f)" % [avant, lent])
	cl.mesures["depollution"] = 1990
	for i in 30:
		cl._sols_jour(2020.0)
	_check(cl.sol_at(ps.x, ps.z) < lent - 0.03, "dépollution : bien plus vite (%.3f)" % cl.sol_at(ps.x, ps.z))
	cl.mesures.clear()

	print("Mesures :")
	steel = _place(bs, "acierie", -700)
	pop._sync_buildings()
	nz.recalculer()
	var air0 := nz.air(pn)
	_check(cl.adopter("filtres_usines") and cl.a("filtres_usines"), "adopter les électrofiltres")
	nz.recalculer()
	_check(nz.air(pn) < air0 - 0.05, "les filtres nettoient l'air près de l'aciérie (%.2f → %.2f)" % [air0, nz.air(pn)])
	_check(cl.cout_mesure("filtres_usines") > 0.0 and cl.budget_entretien().size() == 1, "coût au budget (%d €/mois)" % roundi(cl.cout_mesure("filtres_usines")))
	_check(cl.facteur_air_trafic() == 1.0, "trafic : rien sans pot catalytique")
	cl.adopter("pot_catalytique")
	_check(cl.facteur_air_trafic() < 0.7, "pot catalytique")
	cl.adopter("taxe_carbone")
	cl.simuler_jour()
	_check(cl.budget_recettes().has("Taxe carbone") or float(cl.moyenne(1).t.get("industrie", 0.0)) <= 0.0, "taxe carbone versée à la ville")
	_check(cl.abandonner("filtres_usines") and not cl.a("filtres_usines"), "abandonner une mesure")
	cl.adopter("normes_agricoles")
	_check(cl.facteurs_nuisances("porcherie").y < 1.0 and cl.facteur_champ({}) < 1.0, "normes agricoles : moins de nitrates, −5 % de récoltes")
	_check(not cl.avis_facteurs().is_empty(), "facteurs pour l'avis des habitants")

	print("Mer :")
	cl.menaces = [far]
	var n := cl.submerger()
	_check(n == 1 and float(scene.evenements.degats.get(far, {}).get("d", 0.0)) > 0.1 and cl.submersions == 1, "submersion : la maison basse est inondée")

	print("Époques :")
	var r := ReglagesPartie.actuel
	r.annee_depart = 1850
	r.histoire_debut = 0.0
	r.histoire_saut = 0
	r.rythme_histoire = 25.0
	cl.clear()
	cl.simuler_jour()
	_check(absf(cl.annee_f - 1850.0) < 1.0 and absf(cl.ecart_monde) < 0.15, "partie en 1850 : climat préindustriel (%s °C)" % String.num(cl.ecart_monde, 2))
	_check(cl.ecart_local < -1.0, "météo plus fraîche qu'aujourd'hui (%s °C)" % String.num(cl.ecart_local, 1))
	_check(cl.annonces.has("h1824") and not cl.annonces.has("h1896"), "grandes dates passées déjà connues")
	Epoques.aller_a(1990, r)
	cl.simuler_jour()
	_check(cl.ecart_monde > 0.3 and cl.ecart_monde < 1.0, "1990 : la planète s'est réchauffée (%s °C)" % String.num(cl.ecart_monde, 2))
	_check(cl.annonces.has("h1896") and cl.annonces.has("h1988"), "Arrhenius et le GIEC annoncés")
	_check(cl.mer_cm > 5.0, "la mer est montée (%d cm)" % roundi(cl.mer_cm))
	# Deux futurs : villes très émettrices, villes sobres.
	cl.intensite = 20.0
	Epoques.aller_a(2026, r)
	cl.simuler_jour()
	cl.intensite = 20.0
	Epoques.aller_a(2100, r)
	cl.intensite = 20.0
	cl.scenario_s = 2.0
	cl.avancer_climat(Climat.annee_en_cours())
	var fossile := cl.ecart_monde
	Epoques.aller_a(2026, r)
	cl.clear()
	cl.simuler_jour()
	cl.intensite = 0.5
	cl.scenario_s = 0.0
	Epoques.aller_a(2100, r)
	cl.avancer_climat(Climat.annee_en_cours())
	var sobre := cl.ecart_monde
	_check(fossile > 3.5 and sobre < 2.0, "2100 : %s °C si le monde vous imite en brûlant tout, %s °C en sobre" % [String.num(fossile, 1), String.num(sobre, 1)])
	_check(Climat.facteur_extremes() > 1.0, "plus de catastrophes quand il fait plus chaud (×%s)" % String.num(Climat.facteur_extremes(), 2))
	_check(scene.saisons.frequence() >= r.frequence_catastrophes, "les saisons lisent le facteur")
	r.climat = 0
	cl._maj_meteo()
	_check(cl.ecart_local == 0.0 and Meteo.ecart_climat == 0.0, "Admin : réchauffement désactivé")
	r.climat = 2

	print("Panneau :")
	var panel: ClimatPanel = scene.climat_panel
	for v in ["bilan", "climat", "energie", "sols", "mesures"]:
		panel.set_open(true)
		panel.show_view(v)
		_check(panel._body.get_child_count() > 2, "onglet %s" % v)
	panel.set_open(false)
	var ids := []
	for c in Calques.liste():
		ids.append(String(c.id))
	_check(ids.has("climat_sols"), "carte « Sols pollués » dans le panneau Cartes")

	print("Sauvegarde :")
	cl.sols[Vector2i(3, 4)] = 0.5
	var d := JSON.parse_string(JSON.stringify(cl.to_dict())) as Dictionary
	var ecart := cl.ecart_monde
	var nm := cl.mesures.size()
	cl.clear()
	cl.from_dict(d)
	_check(absf(cl.ecart_monde - ecart) < 0.001 and cl.mesures.size() == nm and absf(cl.sol_at(3 * 40 + 1, 4 * 40 + 1) - 0.5) < 0.001,
		"rechargé : réchauffement, mesures, sols")
	_check(scene.save_sections().has("climat"), "section de sauvegarde « climat »")
	r.annee_depart = 0
	scene.queue_free()
	await process_frame
