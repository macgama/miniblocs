extends SceneTree
## Test « Choisir la taille d'un bâtiment » (TaillesBatiments, TaillePanel) :
## emprise puis hauteur, bornes réalistes par type et par époque, capacités,
## prix, durée du chantier et modèle qui suivent la taille, ids refusés, pose
## dans la partie, carte en deux étapes, sauvegarde, agrandissement et façade.
## Usage : godot --headless --path . --script res://tests/tailles_test.gd

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


func _spot(bs: BuildingSystem, id: String, c: Vector2i) -> Vector2i:
	for dist in [0, 40, 60, 90, 120, 160, 200, 260]:
		for i in 16:
			var a := float(i) / 16.0 * TAU
			var q := c + Vector2i(roundi(cos(a) * dist), roundi(sin(a) * dist))
			if bs.check_place(id, q, 0).ok:
				return q
	return c


func _haut(id: String) -> float:
	var m := BuildingCatalog.build_mesh(id)
	return BatimentsVie.body_bounds(m).end.y if m != null and m.get_surface_count() > 0 else 0.0


func _run() -> void:
	Creations.persist = false
	BatimentsVie.chantiers = false
	GameStart.chosen = true
	GameStart.place_name = "Valfleuri, Savoie"
	ReglagesPartie.prochaine = ReglagesPartie.preset("normal")
	ReglagesPartie.prochaine.deblocage = "tout"
	ReglagesPartie.prochaine.services_fondation = false

	print("Ids et bornes :")
	_check(TaillesBatiments.id_pour("maison", 10, 12, 2) == "maison", "la taille du catalogue garde l'id du catalogue")
	_check(TaillesBatiments.id_pour("maison", 8, 10, 1) == "maison@8x10x1", "maison 8 × 10 m de plain-pied : maison@8x10x1")
	var bm := TaillesBatiments.bornes("maison", 2020)
	_check(bm.w.x <= 6 and bm.w.y >= 16 and bm.e.x == 1 and bm.e.y == 4, "maison : 6 à 16 m de large, 1 à 4 niveaux (%s)" % str(bm))
	var bt := TaillesBatiments.bornes("tour_habitation", 2020)
	_check(bt.e.x >= 8 and bt.e.y >= 30, "tour d'habitation : de %d à %d niveaux" % [bt.e.x, bt.e.y])
	_check(TaillesBatiments.bornes("tour_habitation", 1850).e.y <= 13 and TaillesBatiments.plafond_epoque(1850) == 6,
		"en 1850 on ne monte pas haut (plafond %d)" % TaillesBatiments.plafond_epoque(1850))
	_check(BuildingCatalog.get_type("maison@10x12x20").is_empty(), "une maison de 20 niveaux est refusée")
	_check(BuildingCatalog.get_type("maison@100x12x2").is_empty(), "une maison de 100 m de large est refusée")
	_check(BuildingCatalog.get_type("foot@60x100x1").is_empty() and not TaillesBatiments.reglable("foot"), "un terrain de foot garde ses mesures officielles")
	_check(TaillesBatiments.reglable("parc") and not TaillesBatiments.hauteur_reglable("parc"), "un parc : emprise seulement, pas d'étages")
	_check(TaillesBatiments.hauteur_reglable("usine") and TaillesBatiments.hauteur_reglable("hopital"), "usine et hôpital : hauteur réglable")

	print("Caractéristiques qui suivent la taille :")
	var petite := BuildingCatalog.get_type("maison@8x10x1")
	var grande := BuildingCatalog.get_type("maison@14x16x4")
	_check(int(petite.w) == 8 and int(petite.d) == 10 and BuildingCatalog.footprint("maison@8x10x1", 1) == Vector2i(10, 8), "emprise 8 × 10 m (tournée : 10 × 8)")
	_check(int(petite.logements) == 1 and BuildingCatalog.cost("maison@8x10x1") < BuildingCatalog.cost("maison"), "petite maison : 1 logement, moins chère (%s)" % BuildingSystem.format_money(BuildingCatalog.cost("maison@8x10x1")))
	_check(int(grande.logements) == 2 and int(BuildingCatalog.get_type("maison@13x15x2").logements) == 1 and BuildingCatalog.cost("maison@14x16x4") > 2 * BuildingCatalog.cost("maison"), "grande maison : toujours 1 famille, en 4 niveaux partagée en %d logements, %s" % [grande.logements, BuildingSystem.format_money(BuildingCatalog.cost("maison@14x16x4"))])
	_check(BuildingCatalog.base_of("maison@8x10x1") == "maison" and String(petite.get("role", "")) == "maison", "reconnue comme une maison par les autres systèmes")
	var tour := BuildingCatalog.get_type("tour_habitation@22x22x30")
	_check(int(tour.logements) > 120, "tour de 30 niveaux : %d logements (60 pour 13)" % tour.logements)
	var bur := BuildingCatalog.get_type("bureaux@26x20x12")
	_check(int(bur.emplois) > 250 * 2, "bureaux de 12 niveaux : %d emplois" % bur.emplois)
	_check(Chantiers.mois_batiment("maison@8x10x1", 2020) < Chantiers.mois_batiment("maison", 2020) and Chantiers.mois_batiment("maison", 2020) < Chantiers.mois_batiment("maison@14x16x4", 2020),
		"chantier : %.1f < %.1f < %.1f mois" % [Chantiers.mois_batiment("maison@8x10x1", 2020), Chantiers.mois_batiment("maison", 2020), Chantiers.mois_batiment("maison@14x16x4", 2020)])
	var cen := ReseauxTypes.info("centrale_charbon")
	if not cen.is_empty() and float(cen.get("cap", 0.0)) > 0.0:
		var b0 := TaillesBatiments.dims("centrale_charbon")
		var gid := TaillesBatiments.id_pour("centrale_charbon", int(b0.w) + 10, int(b0.d), int(b0.e))
		_check(float(ReseauxTypes.info(gid).get("cap", 0.0)) > float(cen.cap), "centrale plus grande : plus de puissance (%s → %s)" % [cen.cap, ReseauxTypes.info(gid).get("cap", 0.0)])
	_check(Epoques.annee_batiment("tour_habitation@22x22x30") == Epoques.annee_batiment("tour_habitation"), "même année d'invention que le modèle")

	print("Modèles dessinés à la taille :")
	var h1 := _haut("maison@10x12x1")
	var h2 := _haut("maison")
	var h4 := _haut("maison@10x12x4")
	_check(h1 < h4 and h1 > 2.0, "maison : plain-pied %.1f m < 4 niveaux %.1f m (catalogue %.1f m)" % [h1, h4, h2])
	var aabb := BuildingCatalog.build_mesh("maison@14x16x2").get_aabb()
	_check(aabb.size.x <= 14.2 and aabb.size.x > 10.0 and aabb.size.z <= 16.2, "maison 14 × 16 m : modèle de %.1f × %.1f m" % [aabb.size.x, aabb.size.z])
	var hu1 := _haut("usine")
	var bu := TaillesBatiments.bornes("usine", 2020)
	var uid := TaillesBatiments.id_pour("usine", 50, 34, bu.e.y)
	_check(_haut(uid) > hu1 + 2.0 and BuildingCatalog.build_mesh(uid).get_aabb().size.x > BuildingCatalog.build_mesh("usine").get_aabb().size.x + 3.0,
		"usine plus large et plus haute (%.1f → %.1f m)" % [hu1, _haut(uid)])
	var hh := _haut("hopital")
	var hid := TaillesBatiments.id_pour("hopital", 44, 34, 2)
	_check(_haut(hid) < hh - 1.5, "hôpital de 2 niveaux plus bas que celui du catalogue (%.1f < %.1f m)" % [_haut(hid), hh])
	var vides := []
	var n := 0
	for id in BuildingCatalog.all_types():
		if not TaillesBatiments.reglable(String(id)) or n > 400:
			continue
		n += 1
		var b := TaillesBatiments.bornes(String(id), 2020)
		var gid := TaillesBatiments.id_pour(String(id), b.w.y, b.d.x, b.e.y)
		var m := BuildingCatalog.build_mesh(gid)
		if BuildingCatalog.get_type(gid).is_empty() or m == null or m.get_surface_count() == 0:
			vides.append(gid)
	_check(vides.is_empty(), "%d types réglables dessinés à leur plus grande taille, aucun vide %s" % [n, vides.slice(0, 8)])

	print("Dans la partie :")
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var bs: BuildingSystem = scene.get_node("Batiments")
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
	scene.population.arrivals = false
	bs.require_access = false
	bs.unlimited_money = false
	bs.money = 50_000_000
	scene.communes.nom_en_attente = "Valfleuri"
	bs.place("maison_commune", Vector2i(-60, -60), 0)
	for i in 4:
		await process_frame

	# Carte en deux étapes, qui suit l'outil de pose.
	var tp: TaillePanel = scene.taille_panel
	bs.set_place("maison")
	for i in 3:
		await process_frame
	_check(tp.is_open() and tp.origine == "maison" and tp.etape == 1, "choisir « Maison » ouvre la carte Taille, étape 1 : emprise")
	var bg: Button = tp._corps.find_child("EmpriseGrande", true, false)
	_check(bg != null, "vignette « Grande »")
	if bg != null:
		bg.pressed.emit()
	await process_frame
	var gw := roundi(10 * 1.25)
	_check(bs.type_id == "maison@%dx15x2" % gw, "Grande : le fantôme passe à %d × 15 m (%s)" % [gw, bs.type_id])
	_check(tp._resume.text.contains("logement") and tp._resume.text.contains("chantier"), "résumé : %s" % tp._resume.text)
	(tp._suivant as Button).pressed.emit()
	await process_frame
	_check(tp.etape == 2, "« Suivant » passe à la hauteur")
	var e1: Button = tp._corps.find_child("Etages1", true, false)
	var e4: Button = tp._corps.find_child("Etages4", true, false)
	_check(e1 != null and e4 != null and tp._corps.find_child("Etages5", true, false) == null, "vignettes de 1 à 4 niveaux, pas 5")
	if e1 != null:
		e1.pressed.emit()
	await process_frame
	_check(bs.type_id == "maison@%dx15x1" % gw, "plain-pied : %s" % bs.type_id)
	# Ce test vérifie les prix : la ville paie tout (sans promoteurs privés, voir promoteurs_test).
	ReglagesPartie.actuel.promoteurs_prives = false
	var pos := _spot(bs, bs.type_id, Vector2i(20, 0))
	var avant := bs.money
	var bid := bs.place(bs.type_id, pos, 0)
	_check(bid >= 0 and bs.money < avant, "maison de 13 × 15 m posée (%s payés)" % BuildingSystem.format_money(avant - bs.money))
	var rect := bs._rect_of(bs.buildings[bid])
	_check(rect.size == Vector2i(gw, 15), "elle occupe %d × 15 m au sol (%s)" % [gw, str(rect.size)])
	bs.set_place("usine")
	for i in 3:
		await process_frame
	_check(tp.is_open() and tp.origine == "usine", "la carte suit le bâtiment choisi")
	bs.set_place("foot")
	for i in 3:
		await process_frame
	_check(not tp.is_open(), "pas de carte pour un terrain de foot")
	bs.set_inactive()
	await process_frame

	var tid := TaillesBatiments.id_pour("immeuble", 18, 14, 8)
	var ib := bs.place(tid, _spot(bs, tid, Vector2i(60, 40)), 0)
	_check(ib >= 0, "immeuble de 8 niveaux posé")
	for i in 4:
		await process_frame
	var pop: Population = scene.population
	pop._sync_buildings()
	if ib >= 0:
		var info := pop._info_of(bs.buildings[ib])
		_check(int(info.log) == int(BuildingCatalog.get_type(tid).logements) and int(info.log) > 12, "habitants : %d logements comptés" % info.log)
		var tot := bs.totals()
		_check(int(tot.get("logements", 0)) >= int(info.log), "total de la ville : %d logements" % tot.get("logements", 0))
		bs.buildings[ib]["niv"] = 2
		_check(Ameliorations.cap(bs.buildings[ib], "logements") == roundi(int(info.log) * 1.5), "agrandi au niveau 2 : ×1,5 sur la taille choisie")
		bs.buildings[ib].erase("niv")
		_check(Personnalisation.can_customize(tid) and Personnalisation.base_floors(tid) == 8, "façade modifiable, 8 niveaux de base")

	print("Taille au geste (glisser au sol, puis monter la souris) :")
	ReglagesPartie.actuel.promoteurs_prives = true
	bs.set_place("maison")
	bs.manual_rot = true
	bs.rot = 0
	var coin := _spot(bs, "maison@12x14x2", Vector2i(-60, 60)) - Vector2i(6, 7)
	bs.geste = "trace"
	bs._g_debut = coin
	bs._g_fin = coin
	bs._g_rot = 0
	bs._trace_vers(coin + Vector2i(11, 13), Vector2.ZERO)
	_check(bs.type_id == "maison@12x14x2", "glisser sur 12 × 14 cases : %s" % bs.type_id)
	_check(bs._check.get("rect", Rect2i()) == Rect2i(coin, Vector2i(12, 14)), "l'emprise part de la case de départ (%s)" % str(bs._check.get("rect")))
	bs._trace_vers(coin + Vector2i(60, 13), Vector2.ZERO)
	_check(bs.type_id == "maison@16x14x2", "trop large : bornée à 16 m (%s)" % bs.type_id)
	bs._trace_vers(coin + Vector2i(11, 13), Vector2.ZERO)
	var lache := InputEventMouseButton.new()
	lache.button_index = MOUSE_BUTTON_LEFT
	lache.pressed = false
	lache.position = Vector2(800, 500)
	bs._geste_souris(lache)
	_check(bs.geste == "hauteur", "relâcher le bouton passe aux niveaux")
	bs._hauteur_souris(500.0 - BuildingSystem.PX_NIVEAU * 2.0)
	_check(bs.type_id == "maison@12x14x4", "monter la souris de 2 crans : 4 niveaux (%s)" % bs.type_id)
	bs._hauteur_souris(500.0 - BuildingSystem.PX_NIVEAU * 9.0)
	_check(bs.type_id == "maison@12x14x4", "pas plus de 4 niveaux pour une maison")
	var molette := InputEventMouseButton.new()
	molette.button_index = MOUSE_BUTTON_WHEEL_DOWN
	molette.pressed = true
	bs._geste_souris(molette)
	bs._geste_souris(molette)
	bs._geste_souris(molette)
	_check(bs.type_id == "maison@12x14x1", "molette vers le bas : plain-pied (%s)" % bs.type_id)
	_check(bs.texte_geste().contains("promoteur") and bs._g_label != null and bs._g_label.visible and bs._g_label.text.contains("plain-pied"),
		"aperçu : %s" % bs._g_label.text.replace("\n", " / ") if bs._g_label != null else "pas d'étiquette")
	await process_frame
	_check(tp.is_open() and tp.w == 12 and tp.d == 14 and tp.e == 1 and TaillePanel.replie, "la carte (repliée) suit le geste : %s" % tp._resume.text)
	var argent := bs.money
	var n_av := bs.buildings.size()
	var clic := InputEventMouseButton.new()
	clic.button_index = MOUSE_BUTTON_LEFT
	clic.pressed = true
	bs._geste_souris(clic)
	_check(bs.buildings.size() == n_av + 1 and bs.geste == "", "un clic pose la maison tracée")
	var posee: Dictionary = bs.buildings[bs.next_id - 1] if bs.buildings.has(bs.next_id - 1) else {}
	_check(String(posee.get("t", "")) == "maison@12x14x1" and bs._rect_of(posee) == Rect2i(coin, Vector2i(12, 14)), "maison de 12 × 14 m de plain-pied, à l'endroit tracé")
	_check(bs.money == argent, "payée par un promoteur : la caisse ne bouge pas")
	bs.geste = "trace"
	bs._g_debut = coin + Vector2i(40, 0)
	bs._g_fin = bs._g_debut
	bs._trace_vers(bs._g_debut + Vector2i(9, 9), Vector2.ZERO)
	bs.annuler_geste()
	_check(bs.geste == "" and bs.mode == BuildingSystem.Mode.PLACE, "clic droit / Échap : le geste s'annule, l'outil reste")
	bs.set_inactive()
	ReglagesPartie.actuel.promoteurs_prives = false

	# Sauvegarde : l'id voyage tel quel.
	var d := bs.to_dict()
	var json: Dictionary = JSON.parse_string(JSON.stringify(d))
	bs.from_dict(json)
	for i in 3:
		await process_frame
	var trouve := 0
	for b2 in bs.buildings.values():
		if String(b2.t) == "maison@%dx15x1" % gw or String(b2.t) == tid:
			trouve += 1
	_check(trouve == 2, "après rechargement, les deux bâtiments gardent leur taille")

	print("TEST OK" if ok else "TEST ÉCHOUÉ")
	quit(0 if ok else 1)
