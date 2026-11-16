extends SceneTree
## Test du patrimoine : catalogue des 13 grands monuments (modèles, années,
## durées, étapes, matériaux), chantier sur plusieurs années, curieux du
## chantier, souscription, inauguration et classement d'office, démolition
## interdite, règles des abords, classement d'un édifice ancien (frais, âge,
## agrandissement refusé, entretien et subvention, usure ralentie), tourisme,
## Journées du patrimoine, sauvegarde, panneau Fin et bouton de la barre du bas.
## Usage : godot --headless --path . --script res://tests/patrimoine_test.gd

var ok := true

## Vendredi 17 juillet 2026, midi (UTC+2).
const VENDREDI := 1_784_282_400.0


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
	_check(not BuildingCatalog.category("patrimoine").is_empty(), "catégorie « Patrimoine et grands monuments » dans Construire")
	_check(MonumentsTypes.ORDER.size() == 13, "13 grands monuments")
	for id in MonumentsTypes.ORDER:
		var t := BuildingCatalog.get_type(String(id))
		_check(not t.is_empty() and String(t.cat) == "patrimoine" and t.get("monument", false), "%s dans le catalogue" % id)
		_check(not BibleGlb.entries().has(String(id)) and not EpoquesBatiments.TYPES.has(String(id)), "%s : id pas déjà pris" % id)
		var m := BuildingCatalog.build_mesh(String(id))
		_check(m != null and m.get_surface_count() > 0 and m.get_aabb().size.y > 30.0, "%s a un modèle 3D (%d m de haut)" % [id, roundi(m.get_aabb().size.y)])
		var s := MonumentsTypes.spec(String(id))
		_check(absf(Chantiers.mois_batiment(String(id)) - float(s.ans) * 12.0) < 0.01, "%s : %s de travaux" % [id, MonumentsTypes.ans_texte(float(s.ans))])
		_check(Chantiers.equipe_batiment(String(id)) == int(s.equipe), "%s : équipe de %d ouvriers" % [id, int(s.equipe)])
		var et := Chantiers.etapes_batiment(String(id))
		_check(et.size() >= 6 and float(et[-1][0]) == 1.0, "%s : %d étapes propres" % [id, et.size()])
		_check(Epoques.annee_batiment(String(id)) == int(s.annee), "%s daté (%d)" % [id, int(s.annee)])
		var mx := MateriauxChantiers.besoins_batiment(String(id))
		_check(not mx.is_empty(), "%s : matériaux du chantier" % id)
		for g in mx:
			_check(Ressources.MARCHANDISES.has(String(g)), "%s : marchandise %s connue" % [id, g])
		for j in Metiers.jobs_for(String(id)):
			_check(Metiers.METIERS.has(String(j[0])), "%s : métier %s connu" % [id, j[0]])
	_check(Chantiers.mois_batiment("grande_cathedrale") > 48.0, "la cathédrale dure plus longtemps que le plafond des bâtiments ordinaires")
	_check(Chantiers.etapes_batiment("maison") == Chantiers.ETAPES_BATIMENT, "une maison garde ses étapes ordinaires")
	_check(String(MonumentsTypes.visuel("grande_cathedrale", 0.02)[0]) == "terrassement", "étape visuelle : terrassement")
	var v := MonumentsTypes.visuel("grande_cathedrale", 0.5)
	_check(String(v[0]) == "murs" and float(v[1]) > 0.3 and float(v[1]) < 0.7, "étape visuelle : le monument monte (%.2f)" % float(v[1]))
	_check(String(MonumentsTypes.visuel("grande_cathedrale", 0.97)[0]) == "finitions", "étape visuelle : finitions")
	for ic in ["patrimoine", "grue"]:
		_check(Icones.has_icon(ic), "icône %s" % ic)
	# 19 septembre 2026 est un samedi ; le 12, c'est trop tôt.
	_check(Patrimoine.journees_du_patrimoine(1_789_819_200.0), "Journées du patrimoine le samedi 19 septembre 2026")
	_check(not Patrimoine.journees_du_patrimoine(1_789_214_400.0), "pas le 12 septembre")


func _city_tests() -> void:
	print("Ville :")
	Creations.persist = false
	BatimentsVie.chantiers = true
	ReglagesPartie.actuel.construction_instantanee = false
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var transport: TransportSystem = scene.get_node("Transport")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 40
	world.view_radius_override = 600.0
	world.set_origin(46.2, 6.9)
	for i in 3000:
		await process_frame
		if i >= 120 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	var pat: Patrimoine = scene.patrimoine
	var tour: Tourisme = scene.tourisme
	_check(pat != null and scene.patrimoine_panel != null and Patrimoine.instance == pat, "patrimoine et menu branchés dans la scène")
	_check(scene.save_sections().has("patrimoine"), "section « patrimoine » dans la sauvegarde")
	var pop: Population = scene.population
	for n in [transport.traffic, tour, pop, scene.parc, scene.zoo, scene.musee, scene.spectacles, scene.dechets, scene.production, pat, scene.vie_batiments]:
		n.set_process(false)
	scene.urgences.set_process(false)
	scene.urgences.random_calls = false
	if scene.ambiance.weather != null:
		scene.ambiance.weather.set_process(false)
	scene.ambiance.unix_time = VENDREDI
	bs.unlimited_money = false
	bs.money = 900_000_000
	var y := world.cell_height(Vector2i(0, 0))
	var road := transport.build_segment("route", Vector3(-700, y, 0), Vector3(700, y, 0))
	_check(road.ok, "route de 1,4 km")
	var poser := func(id: String, c: Vector2i) -> int:
		var sn := bs.road_snap(id, c)
		if sn.is_empty():
			return -1
		return bs.place(id, sn.center, int(sn.r), 0, float(sn.get("a", 0.0)))
	var homes: Array[int] = []
	for i in 12:
		var c := Vector2i(-660 + i * 14, 12)
		homes.append(bs.place("maison", c, bs.best_rotation("maison", c)))
	scene.vie_batiments.finish_all()
	pop._sync_buildings()
	for bid in homes:
		if bid > 0:
			pop.spawn_household(bid, "famille")
	_check(pop.persons.size() > 20, "%d habitants" % pop.persons.size())

	# Bouton de la barre du bas et touche Fin.
	var hud: TerreHud = scene.hud
	var bouton := false
	for c in hud.CATEGORIES:
		if String(c.id) == "patrimoine":
			bouton = String(c.group) == "loisirs" and String(c.key) == "Fin"
	_check(bouton, "bouton Patrimoine (touche Fin) dans le menu Loisirs")
	var panel: PatrimoinePanel = scene.patrimoine_panel
	panel.set_open(false)
	hud._on_category("patrimoine")
	_check(panel.is_open(), "le bouton ouvre le menu Patrimoine")
	panel.set_open(false)

	# --- Grand monument : un chantier de plusieurs années. ---
	var caisse0 := bs.money
	var cat: int = poser.call("grande_cathedrale", Vector2i(-300, -70))
	_check(cat > 0, "cathédrale posée au bord de la route")
	var b: Dictionary = bs.buildings[cat]
	_check(bs.en_chantier(cat) and float(b.av) < 0.01 and int(b.get("du", 0)) == int(b.cost), "chantier lancé, payé au fil des travaux (%s dus)" % BuildingSystem.format_money(int(b.get("du", 0))))
	_check(caisse0 - bs.money < 1000, "rien n'est payé d'avance")
	var duree: float = scene.vie_batiments.duree_prevue("grande_cathedrale")
	_check(duree > 86400.0 * 200.0, "la cathédrale prend environ %s dans le jeu" % Chantiers.duree_texte(duree))
	_check(scene.vie_batiments.duree_prevue("tour_fer") < duree * 0.2, "la tour de fer va beaucoup plus vite (%s)" % Chantiers.duree_texte(scene.vie_batiments.duree_prevue("tour_fer")))
	_check(String(scene.vie_batiments.etape_de(cat)[1]) == "terrassement", "première étape : terrassement")
	b["av"] = 0.40
	scene.vie_batiments._show_etape(cat)
	_check(String(scene.vie_batiments.etape_de(cat)[2]) == "La nef et les bas-côtés", "étape du chantier : %s" % String(scene.vie_batiments.etape_de(cat)[2]))
	_check(String(scene.vie_batiments._chantiers[cat].etape) == "murs", "on voit la cathédrale monter derrière ses échafaudages")
	var p_chantier := pat.points_site(cat)
	_check(p_chantier > 0.0, "les curieux viennent voir le chantier (%.2f points)" % p_chantier)
	tour._maj_sites()
	var vu := false
	for s in tour.sites:
		if String(s.kind) == "patrimoine" and int(s.key) == cat:
			vu = String(s.nom).begins_with("Chantier de")
	_check(vu, "le chantier est un site touristique « Chantier de cathédrale gothique »")
	# Souscription.
	var du0 := int(b.du)
	_check(pat.lancer_souscription(cat), "souscription populaire lancée")
	_check(pat.dons_du_jour(cat) > 100.0, "les habitants donnent %s par jour" % BuildingSystem.format_money(int(pat.dons_du_jour(cat))))
	pat.nouveau_jour()
	_check(int(b.du) < du0 and int(pat.souscription(cat).recu) > 0, "les dons réduisent ce que la ville doit payer (%s reçus)" % BuildingSystem.format_money(int(pat.souscription(cat).recu)))
	_check(pat.raison_demolir(cat) == "", "un chantier pas fini peut encore être arrêté")
	# Fin du chantier et inauguration.
	scene.vie_batiments.finish_all()
	_check(not bs.en_chantier(cat), "chantier terminé")
	pat.nouveau_jour()
	_check(pat.niveau(cat) == Patrimoine.CLASSE, "inauguré et classé monument historique d'office")
	_check(pat.points_site(cat) > p_chantier * 3.0, "fini, il attire bien plus (%.1f points)" % pat.points_site(cat))
	bs.demolish(cat)
	_check(bs.buildings.has(cat), "on ne démolit pas un monument classé")

	# --- Abords. ---
	var tour_id := "tour_habitation"
	_check(pat.hauteur_type(tour_id) > 30.0, "une tour d'habitation fait %d m" % roundi(pat.hauteur_type(tour_id)))
	var pres := bs._rect_of(bs.buildings[cat])
	var rect_pres := Rect2i(pres.position + Vector2i(pres.size.x + 20, 0), Vector2i(20, 20))
	var r1 := pat.check_place(tour_id, rect_pres)
	_check(String(r1.get("reason", "")).contains("30 m"), "tour refusée aux abords : « %s »" % String(r1.get("reason", "")))
	_check(String(pat.check_place("usine", rect_pres).get("reason", "")).contains("usine"), "usine refusée aux abords")
	_check(String(pat.check_place("maison", rect_pres).get("reason", "")) == "" and String(pat.check_place("maison", rect_pres).get("info", "")) != "", "une maison passe, avec l'info des abords")
	var loin := Rect2i(pres.position + Vector2i(600, 0), Vector2i(20, 20))
	_check(pat.check_place(tour_id, loin).is_empty(), "loin du monument, pas de règle")
	var refus: Dictionary = bs.check_place(tour_id, Vector2i(pres.end.x + 30, -40), 0)
	_check(not bool(refus.ok) and String(refus.reason).contains("abords"), "la pose est vraiment refusée par Construire")
	pat.regles_abords = false
	_check(pat.check_place(tour_id, rect_pres).is_empty(), "règles des abords coupées : tout passe")
	pat.regles_abords = true

	# --- Classement d'un édifice ancien. ---
	var culte := ""
	var types := BuildingCatalog.all_types()
	for id in types:
		var t: Dictionary = types[id]
		if String(t.get("arch", "")) == "culte" and String(t.get("era", "")) == "traditionnel" and (t.get("access", []) as Array).has("route") and int(t.get("w", 99)) <= 30:
			culte = String(id)
			break
	_check(culte != "", "un lieu de culte traditionnel dans la bible (%s)" % culte)
	var eg: int = poser.call(culte, Vector2i(300, -40))
	_check(eg > 0, "%s posé" % pat.nom(eg) if eg > 0 else "lieu de culte posé")
	scene.vie_batiments.finish_all()
	var maison := homes[0]
	_check(pat.niveau_possible(maison) == 0 and pat.refus_proteger(maison, 1) != "", "une maison neuve n'a pas d'intérêt patrimonial")
	_check(pat.niveau_possible(eg) >= Patrimoine.INSCRIT, "l'église peut être inscrite (intérêt %.1f)" % float(pat.interet(eg).pts))
	var m0 := bs.money
	_check(pat.proteger(eg, Patrimoine.INSCRIT), "église inscrite au patrimoine")
	_check(m0 - bs.money == Patrimoine.FRAIS[1], "frais de dossier payés (%s)" % BuildingSystem.format_money(m0 - bs.money))
	_check(pat.refus_proteger(eg, Patrimoine.CLASSE) != "", "pas encore assez d'histoire pour la classer")
	pat.nes[eg] = Patrimoine.annee_courante() - 120
	_check(pat.age(eg) == 120 and pat.niveau_possible(eg) == Patrimoine.CLASSE, "120 ans plus tard, elle peut être classée")
	_check(pat.proteger(eg, Patrimoine.CLASSE), "église classée monument historique")
	_check(scene.ameliorations.refus_agrandir(eg).contains("restaure"), "on ne l'agrandit pas : « %s »" % scene.ameliorations.refus_agrandir(eg))
	bs.demolish(eg)
	_check(bs.buildings.has(eg), "on ne la démolit pas")
	_check(scene.vie_batiments.extra_usure.call(eg) < 0.5, "entretenue, elle s'use trois fois moins vite")
	var e: Array = pat.entretien_annuel(eg)
	_check(float(e[0]) > 0.0 and float(e[1]) < float(e[0]), "entretien %s par an, dont %s payés par l'État" % [BuildingSystem.format_money(int(e[0])), BuildingSystem.format_money(int(e[0] - e[1]))])
	pat.set_entretien(eg, false)
	_check(scene.vie_batiments.extra_usure.call(eg) > 1.0, "sans entretien, elle s'abîme plus vite")
	pat.set_entretien(eg, true)
	var base := Patrimoine.points_base(culte)
	_check(pat.points_site(eg) > base * 1.5, "classée, elle attire plus (%.2f au lieu de %.2f)" % [pat.points_site(eg), base])
	# Journées du patrimoine.
	var p_juillet := pat.points_site(eg)
	scene.ambiance.unix_time = 1_789_819_200.0
	_check(pat.journees() and pat.points_site(eg) > p_juillet * 1.5, "Journées du patrimoine : visites presque doublées")
	scene.ambiance.unix_time = VENDREDI
	# Le reste du tourisme voit les deux monuments.
	tour._maj_sites()
	var n_pat := 0
	for s in tour.sites:
		if String(s.kind) == "patrimoine":
			n_pat += 1
	_check(n_pat >= 2 and tour.attrait_total > 5.0, "%d sites patrimoniaux, attrait de la ville %.1f" % [n_pat, tour.attrait_total])
	_check(pat.rayonnement() > 5.0, "rayonnement %.1f points" % pat.rayonnement())
	pat.set_entretien(eg, false)
	var cs := pat.conseils()
	_check(not cs.is_empty() and String(cs[0]).contains("entretien"), "conseil : « %s »" % (String(cs[0]) if not cs.is_empty() else ""))
	pat.set_entretien(eg, true)
	# Déclasser.
	pat.declasser(eg)
	_check(pat.niveau(eg) == 0 and pat.raison_demolir(eg) == "", "déclassée, elle redevient un bâtiment ordinaire")
	pat.proteger(eg, Patrimoine.CLASSE)

	# --- Sauvegarde. ---
	var data := pat.to_dict()
	var json: Dictionary = JSON.parse_string(JSON.stringify(data))
	pat.clear()
	_check(pat.niveau(eg) == 0, "partie vidée")
	pat.from_dict(json)
	_check(pat.niveau(eg) == Patrimoine.CLASSE and pat.niveau(cat) == Patrimoine.CLASSE and pat.age(eg) == 120, "classements et âges relus de la sauvegarde")
	_check(int(pat.souscription(cat).get("recu", 0)) > 0, "dons relus de la sauvegarde")

	# --- Panneau. ---
	for v in ["bref", "chantiers", "classement", "batir"]:
		panel.set_open(true)
		panel.show_view(v)
		_check(panel._body.get_child_count() > 3, "onglet %s rempli (%d lignes)" % [v, panel._body.get_child_count()])
	panel.set_open(false)
