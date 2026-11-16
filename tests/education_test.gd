extends SceneTree
## Test des systèmes scolaires : degrés suisses (HarmoS), classes, orientation,
## apprentissage chez un employeur, gymnase, études en ville, diplômes exigés
## par les métiers, frontaliers ou pendulaires, époques, sauvegarde.
## Usage : godot --headless --path . --script res://tests/education_test.gd

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


func _run() -> void:
	print("Données des systèmes :")
	var S := SystemesScolaires
	_check(S.bornes("ch", 2026).oblig == [4, 15], "Suisse 2026 (HarmoS) : école obligatoire de 4 à 15 ans")
	_check(S.bornes("fr", 2026).oblig == [3, 16], "France 2026 : instruction obligatoire de 3 à 16 ans")
	_check(S.bornes("fr", 1850).oblig.is_empty(), "France 1850 : pas encore d'obligation (Ferry 1882)")
	_check(S.classe("ch", "primaire", 8, 2026) == "5H" and S.classe("ch", "sec1", 13, 2026) == "10H", "classes HarmoS : 8 ans en 5H, 13 ans en 10H")
	_check(S.classe("fr", "primaire", 8, 2026) == "CE2" and S.classe("fr", "sec1", 14, 2026) == "3e", "classes françaises : CE2, 3e")
	_check(S.nom_diplome("cfc:bouche:boulanger", 2026).begins_with("CFC") and S.nom_diplome("cfc", 1900) == "Certificat d'apprentissage cantonal",
		"le CFC (1933) remplace le certificat cantonal : " + S.nom_diplome("cfc:bouche:boulanger", 2026))
	_check(S.nom_cycle("ch", "hes", 1990) == "Technicum" and S.nom_cycle("ch", "hep", 1990) == "École normale", "avant 1997 et 2001 : technicum et école normale")
	var cur_90 := S.cursus_superieurs("ch", 1990, "mat_gym").map(func(c: Array) -> String: return String(c[0]))
	var cur_26 := S.cursus_superieurs("ch", 2026, "mat_gym").map(func(c: Array) -> String: return String(c[0]))
	_check(cur_90.has("lic_uni") and cur_26.has("bachelor_uni") and cur_26.has("bachelor_hes") and cur_26.has("bachelor_hep"),
		"Bologne : licence en 1990, bachelor université/HES/HEP en 2026")
	_check(int(S.exigence("enseignant", 1990).niv) == 3 and int(S.exigence("enseignant", 2026).niv) == 5 and bool(S.exigence("enseignant", 2026).strict),
		"enseignant : école normale avant 2001, bachelor HEP obligatoire ensuite")
	_check(int(S.exigence("medecin", 1800).niv) == 0, "en 1800, médecin sans diplôme exigé")
	_check(S.qualifie(["bachelor_hep"], "enseignant", 2026) and not S.qualifie(["mat_gym"], "enseignant", 2026), "bachelor HEP oui, maturité seule non")
	_check(S.qualifie(["dipl_med"], "medecin", 2026) and not S.qualifie(["master_uni:technique"], "medecin", 2026), "médecin : diplôme fédéral de médecin, pas un master d'ingénieur")
	_check(S.qualifie(["master_uni:technique"], "employe", 2026), "un master d'un autre domaine suffit pour un poste non obligatoire (employé de commerce)")
	_check(S.qualifie(["brevet", "bac"], "cadre", 2026) == false and S.qualifie(["licence"], "cadre", 2026), "anciens diplômes (sauvegardes) : licence valable sans domaine")
	var p18 := S.parts_orientation("ch", 2026)
	_check(float(p18.cfc) > float(p18.gym) and float(p18.gym) > 0.15, "Suisse : l'apprentissage devant le gymnase (CFC %d %%, gymnase %d %%)" % [roundi(p18.cfc * 100), roundi(p18.gym * 100)])
	_check(float(S.parts_orientation("ch", 1850).gym) < 0.05, "en 1850, très peu de maturités")
	_check(S.taux_scolarisation("fr", "primaire", 1830) < 0.6 and S.taux_scolarisation("fr", "primaire", 1900) == 1.0, "école primaire : la moitié des enfants en 1830, tous en 1900")
	_check(Education.niveaux_type("college") == ["sec1"] and Education.niveaux_type("lycee") == ["gym", "ecg"] and Education.niveaux_type("universite") == ["uni"]
		and Education.niveaux_type("ecole") == ["enfantine", "primaire"] and Education.niveaux_type("ecole_professionnelle") == ["pro"],
		"un bâtiment par degré : école, collège, lycée (gymnase), école professionnelle, université")
	_check(BuildingCatalog.get_type("residence_etudiante").get("etudiants", false) and int(BuildingCatalog.get_type("residence_etudiante").logements) == 80,
		"résidence étudiante : 80 studios")

	print("Une ville suisse :")
	Creations.persist = false
	BatimentsVie.chantiers = false
	GameStart.pays = "ch"
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var amb: DayNight = scene.get_node("Ambiance")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.set_origin(46.52, 6.63)
	for i in 60:
		await process_frame
	var pop: Population = scene.population
	var edu := pop.edu
	amb.set_speed(0)
	amb.unix_time = _at("2026-03-10", 10.0)
	bs.unlimited_money = true
	var y := world.cell_height(Vector2i(0, 0))
	_check(transport.build_segment("route", Vector3(0, y, -500), Vector3(0, y, 500)).ok, "route")
	var ids := {}
	var gauche := [["ecole", -30, -400], ["college", -45, -330], ["lycee", -45, -250], ["ecole_professionnelle", -40, -170],
		["universite", -60, -60], ["boulangerie", -14, 40], ["atelier", -18, 70], ["hopital", -36, 130], ["supermarche", -30, 200],
		["residence_etudiante", -18, 260]]
	var zc := -480
	for e in gauche:
		var fp := BuildingCatalog.footprint(String(e[0]), 1)
		var c := Vector2i(-(fp.x / 2 + 9), zc + fp.y / 2)
		ids[e[0]] = bs.place(String(e[0]), c, 1)
		if int(ids[e[0]]) < 0:
			print("    %s : %s" % [e[0], bs.check_place(String(e[0]), c, 1, false, 0.0).reason])
		zc += fp.y + 4
	var homes := []
	for i in 14:
		homes.append(bs.place("immeuble", Vector2i(16, -460 + i * 24), 3))
	var manque := []
	for k in ids:
		if int(ids[k]) < 0:
			manque.append(k)
	_check(manque.is_empty() and not homes.has(-1), "écoles de chaque degré, université, employeurs, résidence et 14 immeubles posés %s" % str(manque))
	pop._sync_buildings()
	_check(edu.systeme_batiment(int(ids.ecole)) == "ch", "la ville suit le système suisse")
	_check(pop.known.has(int(ids.residence_etudiante)) and pop.known[int(ids.residence_etudiante)].etu, "la résidence est réservée aux étudiants")
	for i in 72:
		pop.advance(300.0)
	_check(pop.persons.size() > 100, "%d habitants" % pop.persons.size())

	print("Degrés et bâtiments :")
	var bon := true
	var vus := {}
	for pid in pop.persons:
		var p: Dictionary = pop.persons[pid]
		var c := edu.cycle(p)
		if c != "" and int(p.sch) >= 0:
			vus[c] = int(vus.get(c, 0)) + 1
			if not edu.accepte(int(p.sch), c):
				bon = false
	_check(bon, "chaque élève est dans un bâtiment de son degré : %s" % str(vus))
	_check(vus.has("primaire") and vus.has("sec1"), "primaire à l'école, secondaire I au collège")
	var un_eleve := -1
	for pid in pop.persons:
		if edu.cycle(pop.persons[pid]) == "primaire" and int(pop.persons[pid].sch) >= 0:
			un_eleve = pid
			break
	if un_eleve >= 0:
		var lab := pop.stage_label(pop.persons[un_eleve])
		_check(lab.contains("H"), "libellé d'un élève : " + lab)
	var sans := 0
	for pid in pop.persons:
		if edu.sans_ecole(pop.persons[pid]):
			sans += 1
	_check(sans == 0, "aucun enfant sans école")

	print("Dix ans de vie (1 an par jour) :")
	pop.life_speed_index = 2
	var vu_app := false
	var vu_cfc := false
	var vu_mat := false
	var vu_etu_ici := false
	var vu_ecole_pro := false
	for d in 10:
		pop.advance(86400.0)
		for i in 12:
			pop.advance(300.0)
		amb.unix_time = _at("2026-03-10", 10.0) + d * 7 * 86400.0
		pop._now = {}
		for pid in pop.persons:
			var p: Dictionary = pop.persons[pid]
			if pop.stage(p) == "apprenti":
				vu_app = true
				if int(p.sch) >= 0 and edu.accepte(int(p.sch), "pro"):
					vu_ecole_pro = true
			if pop.stage(p) == "etudiant" and int(p.sch) >= 0:
				vu_etu_ici = true
			for dp in Education.diplomes(p):
				if String(dp).begins_with("cfc:"):
					vu_cfc = true
				if String(dp) == "mat_gym":
					vu_mat = true
	_check(vu_app, "des jeunes signent un contrat d'apprentissage chez un employeur de la ville")
	_check(vu_ecole_pro, "les apprentis vont aussi à l'école professionnelle")
	_check(vu_cfc, "des CFC sont obtenus")
	_check(vu_mat, "des maturités gymnasiales sont obtenues")
	_check(vu_etu_ici, "des étudiants suivent les cours de l'université de la ville")
	var en_res := (pop.by_home.get(int(ids.residence_etudiante), []) as Array).size()
	_check(en_res > 0, "la résidence étudiante accueille %d étudiants" % en_res)
	var app_jour := ""
	for pid in pop.persons:
		var p: Dictionary = pop.persons[pid]
		if pop.stage(p) == "apprenti":
			app_jour = pop.stage_label(p)
			break
	print("    exemple : " + app_jour)

	print("Diplômes exigés, pénuries :")
	var hop := int(ids.hopital)
	var ps := edu.postes(hop)
	_check(ps.has("medecin") and int(ps.medecin.q) > 0, "l'hôpital prévoit %d postes de médecin" % int(ps.get("medecin", {}).get("q", 0)))
	var sans_dip := -1
	for pid in pop.persons:
		var p: Dictionary = pop.persons[pid]
		if pop.stage(p) == "chomeur" or pop.stage(p) == "actif":
			if not edu.qualifie(p, "medecin"):
				sans_dip = pid
				break
	if sans_dip >= 0:
		var ch := edu.choisir_metier(pop.persons[sans_dip], hop)
		_check(String(ch[0]) != "medecin" and String(ch[0]) != "infirmier", "sans diplôme, pas de poste de médecin ni d'infirmier (%s)" % String(ch[0]))
	var med_ok := 0
	for pid in pop.by_job.get(hop, []):
		var p: Dictionary = pop.persons[pid]
		if String(p.met) == "medecin" and not edu.qualifie(p, "medecin"):
			med_ok += 1
	_check(med_ok == 0, "aucun médecin sans diplôme à l'hôpital")
	_check(not pop.effectif.ferme(hop), "l'hôpital est ouvert (%d employés dont %d venus d'ailleurs)" % [int(pop.effectif.etat(hop).get("embauches", 0)), edu.externes_de(hop)])
	var pen := edu.penuries()
	print("    pénuries : %s" % str(pen.map(func(e: Dictionary) -> String: return "%s %d ext %d vac" % [e.metier, e.externes, e.vacants])))
	# Rendement : une personne non qualifiée dans un métier conseillé.
	var bou := int(ids.boulangerie)
	var staff: Array = pop.by_job.get(bou, [])
	if not staff.is_empty():
		pop.persons[staff[0]].nq = true
		if pop.stage(pop.persons[staff[0]]) != "apprenti":
			pop.emplois_version += 1
			_check(edu.rendement(bou) < 1.0, "boulangerie : rendement %.2f avec un employé non qualifié" % edu.rendement(bou))

	print("Sauvegarde :")
	var d := pop.to_dict()
	var avant := {}
	for pid in pop.persons:
		avant[pid] = [",".join(Education.diplomes(pop.persons[pid])), String(pop.persons[pid].get("fil", "")), pop.stage(pop.persons[pid])]
	var ext_avant := edu.externes.duplicate(true)
	pop.from_dict(JSON.parse_string(JSON.stringify(d)))
	var pareil := true
	for pid in avant:
		if not pop.persons.has(pid):
			pareil = false
			continue
		var p: Dictionary = pop.persons[pid]
		if [",".join(Education.diplomes(p)), String(p.get("fil", "")), pop.stage(p)] != avant[pid]:
			pareil = false
	_check(pareil, "diplômes, filières et étapes rechargés")
	_check(edu.externes.size() == ext_avant.size(), "frontaliers et pendulaires rechargés")

	print("Époques :")
	ReglagesPartie.actuel.annee_depart = 1850
	edu._annee_t = -1
	_check(edu.annee() >= 1850 and edu.annee() < 1900, "partie en %d" % edu.annee())
	_check(int(S.exigence("enseignant", edu.annee()).niv) <= 3, "en 1850 l'instituteur sort de l'école normale")
	_check(not Epoques.batiment_disponible("haute_ecole") and Epoques.batiment_disponible("ecole_normale") and not Epoques.batiment_disponible("residence_etudiante"),
		"en 1850 : école normale oui ; HES moderne et résidence étudiante pas encore")
	ReglagesPartie.actuel.annee_depart = 0

	print("EDUCATION TEST %s" % ("OK" if ok else "ÉCHEC"))
	quit(0 if ok else 1)
