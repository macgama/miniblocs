extends SceneTree
## Test de la construction sous terre (scripts/souterrain/construction_souterraine.gd) :
## conduites posées en profondeur et déplacées, tunnels routiers et métro creusés
## au niveau affiché, pièces creusées (parking, bunker) devenues sous-sols de
## l'Atelier, coûts, chantiers, sauvegarde.
## Usage : godot --headless --path . --script res://tests/construction_souterraine_test.gd
## Captures (avec affichage) : ajouter -- --dossier /chemin/captures

var ok := true
var dossier := ""


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


func _key(code: Key) -> void:
	var k := InputEventKey.new()
	k.keycode = code
	k.pressed = true
	root.push_input(k)
	var r := InputEventKey.new()
	r.keycode = code
	r.pressed = false
	root.push_input(r)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(nom: String) -> void:
	if dossier == "":
		return
	await _frames(12)
	var path := dossier.path_join(nom)
	root.get_viewport().get_texture().get_image().save_png(path)
	print("capture : ", path)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size() - 1:
		if args[i] == "--dossier":
			dossier = args[i + 1]
	root.size = Vector2i(1600, 900)
	Creations.persist = false
	BatimentsVie.chantiers = false
	ReglagesPartie.actuel.construction_instantanee = true
	ReglagesPartie.actuel.cout_construction = 1.0
	var CS := ConstructionSouterraine

	print("Règles :")
	_check(CS.facteur_profondeur(1.2) == 1.0 and is_equal_approx(CS.facteur_profondeur(6.0), 2.0), "tranchée jusqu'à 2 m, tranchée blindée ×2 à 6 m")
	_check(CS.facteur_profondeur(12.0) > 2.5 and CS.methode_conduite(12.0) == "microtunnelier", "microtunnelier au-delà de 6 m")
	_check(is_equal_approx(CS.profondeur_conduite("collecteur", 1), 4.0), "au −1, un collecteur garde ses 4 m")
	_check(is_equal_approx(CS.profondeur_conduite("conduite_eau", 4), 10.5), "au −4, une conduite passe au milieu du niveau (10,5 m)")
	_check(is_equal_approx(CS.profondeur_voie(5), 14.0), "métro au −5 : voies à 14 m, comme avant")
	_check(CS.prix_piece("parking", 100, 1, 1) == 130000, "parking : 1 300 €/m² (%d)" % CS.prix_piece("parking", 100, 1, 1))
	_check(CS.prix_piece("parking", 100, 1, 1, true) == 195000, "sous un bâtiment : +50 %")
	_check(CS.prix_piece("bunker", 100, 1, 11) > CS.prix_piece("bunker", 100, 1, 1), "plus profond, plus cher")
	_check(CS.places_de("parking", 250, 1) == 10 and CS.places_de("bunker", 40, 2) == 80 and CS.places_de("cave", 40, 1) == 0, "places : 25 m² par voiture, 1 m² par personne à l'abri")
	_check(CS.prix_tunnel_m("metro", 14.0) == 60000.0 and CS.prix_tunnel_m("metro", 8.0) < 60000.0, "métro : 60 k€/m, moins en tranchée couverte")

	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var amb: DayNight = scene.get_node("Ambiance")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 40
	world.view_radius_override = 700.0
	world.set_origin(46.2, 6.9)
	await _frames(150)
	amb.set_speed(0)
	amb.unix_time = Time.get_unix_time_from_datetime_string("2026-06-10T15:00:00")
	bs.unlimited_money = false
	bs.money = 500_000_000
	# La scène prend les réglages de la nouvelle partie : on les refixe ici.
	ReglagesPartie.actuel.construction_instantanee = true
	ReglagesPartie.actuel.cout_construction = 1.0
	var res: Reseaux = scene.reseaux
	var vs: VueSouterraine = scene.souterrain
	var cs: ConstructionSouterraine = scene.construction_souterraine
	var pe: PlanEditor = scene.plans
	var rig: Node3D = scene.get_node("CameraRig")
	_check(cs != null and vs.construction == cs, "la construction sous terre est branchée sur la vue")
	var y := world.cell_height(Vector2i(0, 0))

	transport.build_segment("route", Vector3(-160, y, 0), Vector3(160, y, 0))
	var maison := bs.place("maison", Vector2i(-100, 12), bs.best_rotation("maison", Vector2i(-100, 12)))
	await _frames(10)
	rig.global_position = Vector3(0, y, 20)
	rig.set("_target_distance", 230.0)
	rig.set_pitch(50.0, true)

	print("Outils et niveaux :")
	cs.activer(CS.Outil.PIECE)
	_check(cs.outil == CS.Outil.AUCUN, "pas d'outil hors de la vue sous terre")
	vs.set_niveau(4)
	cs.activer(CS.Outil.CONDUITE, "conduite_eau")
	_check(res.outil == Reseaux.Outil.TRACER and res.type_troncon == "conduite_eau", "l'outil Eau prend le traceur du panneau O")
	_check(is_equal_approx(res.profondeur_pose, 10.5), "posée au −4 : 10,5 m de fond")
	_key(KEY_PAGEDOWN)
	await _frames(2)
	_check(vs.niveau == 5 and is_equal_approx(res.profondeur_pose, 13.5), "Page bas : la conduite descend avec la vue (13,5 m)")
	vs.set_niveau(4)
	var m0 := bs.money
	var pts := res.trace_sur_relief(Vector3(-150, y, -40), Vector3(150, y, -40))
	var cid := res.poser("conduite_eau", pts)
	var base := ReseauxTypes.prix_troncon("conduite_eau", ReseauBase.longueur(pts))
	_check(cid >= 0 and is_equal_approx(float(res.eau.troncons[cid].prof), 10.5), "conduite posée à 10,5 m")
	_check(m0 - bs.money == roundi(base * CS.facteur_profondeur(10.5)), "payée au prix du microtunnelier (×%s : %d €)" % [snappedf(CS.facteur_profondeur(10.5), 0.01), m0 - bs.money])
	await _frames(2)
	vs.marquer_sale()
	vs._maj()
	_check(int(vs.compte.troncons) >= 1, "visible au −4")
	vs.set_niveau(5)
	_check(int(vs.compte.troncons) == 0, "plus au −5")
	cs.activer(CS.Outil.CONDUITE, "fibre")
	_check(scene.telecom.outil == Telecom.Outil.FIBRE and is_equal_approx(scene.telecom.profondeur_pose, 13.5), "la fibre aussi se pose en profondeur")
	cs.desactiver()
	_check(is_nan(res.profondeur_pose) and is_nan(scene.telecom.profondeur_pose) and res.outil == Reseaux.Outil.AUCUN, "outil rangé : profondeurs normales")

	print("Déplacer une conduite :")
	ReglagesPartie.actuel.construction_instantanee = false
	vs.set_niveau(2)
	var sel := cs.conduite_pres(Vector3(0, y, -41), 8.0)
	_check(not sel.is_empty() and int(sel.id) == cid, "on attrape la conduite d'un clic")
	var nid := cs.deplacer(sel, Vector2(0, -20), 2)
	_check(nid >= 0 and res.eau.troncons.has(cid) and bool(res.eau.troncons[cid].ok), "dévoiement : l'ancienne reste en service")
	_check(not bool(res.eau.troncons[nid].ok) and is_equal_approx(float(res.eau.troncons[nid].prof), 4.5), "la nouvelle est en chantier, à 4,5 m")
	_check(absf((res.eau.troncons[nid].pts as PackedVector3Array)[0].z + 60.0) < 0.01, "20 m plus loin")
	SuiviChantiers.instance.terminer(Reseaux._cle("eau", nid))
	await _frames(2)
	_check(not res.eau.troncons.has(cid) and bool(res.eau.troncons[nid].ok), "travaux finis : l'ancienne est retirée")
	_check(cs.raison_piece(Rect2i(-20, -66, 8, 12), 2, 1).contains("conduite"), "pas de pièce à travers une conduite")
	ReglagesPartie.actuel.construction_instantanee = true

	print("Tunnels :")
	vs.set_niveau(2)
	cs.activer(CS.Outil.TUNNEL, "metro")
	_check(is_nan(RoutePlanner.profondeur_forcee), "pas de tunnel au −2 (tranchée)")
	vs.set_niveau(6)
	_check(cs.outil == CS.Outil.TUNNEL and is_equal_approx(RoutePlanner.profondeur_forcee, 17.0), "au −6 : voies à 17 m")
	_check(transport.tool == TransportSystem.Tool.BUILD and transport.type_id == "metro", "l'outil des voies prend le métro")
	m0 = bs.money
	var mt := transport.build_segment("metro", Vector3(-150, y, 60), Vector3(150, y, 60))
	_check(mt.ok, "métro creusé (%s)" % mt.get("reason", "ok"))
	cs._on_edges_built(mt.get("edges", []))
	var e0: Dictionary = transport.network.edges[mt.edges[0]] if mt.ok else {}
	var fond := y - (e0.pts as PackedVector3Array)[10].y if mt.ok else 0.0
	_check(absf(fond - 17.0) < 0.5, "voies à %s m sous le sol" % snappedf(fond, 0.1))
	_check(e0.has("prof") and m0 - bs.money > 15_000_000, "tunnel payé (%s)" % BuildingSystem.format_money(m0 - bs.money))
	vs.set_niveau(6)
	_check(int(vs.compte.tunnels) >= 1, "le tunnel se voit au −6")
	cs.activer(CS.Outil.TUNNEL, "rue")
	var rt := transport.build_segment("rue", Vector3(160, y, 0), Vector3(160, y, 200))
	_check(rt.ok, "rue en tunnel depuis le bout de la route (%s)" % rt.get("reason", "ok"))
	if rt.ok:
		var stv: PackedByteArray = rt.st
		_check(stv[0] != TransportTypes.Struct.TUNNEL and stv[stv.size() / 2] == TransportTypes.Struct.TUNNEL, "rampe depuis la surface, puis tunnel")
	cs.desactiver()
	_check(is_nan(RoutePlanner.profondeur_forcee), "outil rangé : routes de surface normales")
	var surf := transport.build_segment("rue", Vector3(-160, y, 100), Vector3(-60, y, 100))
	_check(surf.ok and (surf.st as PackedByteArray)[5] == TransportTypes.Struct.GROUND, "une rue posée ensuite reste en surface")

	print("Pièces :")
	vs.set_niveau(1)
	_check(cs.raison_piece(Rect2i(-20, -4, 8, 8), 1, 1).contains("réseaux de la rue"), "pas de cave au −1 sous la rue")
	_check(cs.raison_piece(Rect2i(-20, -4, 8, 8), 2, 1) == "", "au −2 sous la rue : possible")
	_check(cs.raison_piece(Rect2i(-20, 55, 8, 10), 5, 2).contains("tunnel"), "pas de pièce dans le tunnel du métro")
	_check(cs.raison_piece(Rect2i(-104, 8, 8, 8), 1, 1).contains("sous-sol de ce bâtiment"), "la cave de la maison occupe le −1")
	m0 = bs.money
	vs.set_niveau(2)
	cs.hauteur = 2
	var pk := cs.creuser(Rect2i(-40, 20, 20, 10), 2, 2, "parking")
	_check(pk >= 0 and float(cs.pieces[pk].av) >= 1.0, "parking de 200 m² sur 2 niveaux creusé")
	_check(m0 - bs.money == CS.prix_piece("parking", 200, 2, 3), "payé %s" % BuildingSystem.format_money(m0 - bs.money))
	var pid := String(cs.pieces[pk].plan) if pk >= 0 else ""
	_check(pe.est_souterrain(pid), "devenu un sous-sol de l'Atelier (plan souterrain)")
	var lv: Array = pe.levels_of(pid) if pid != "" else []
	_check(lv == [-3, -2], "aux niveaux −2 et −3 de l'Atelier (%s)" % str(lv))
	_check(not pe.cells.has(Vector2i(-30, 25)) and pe.cells_st.has(Vector2i(-30, 25)), "la surface reste libre au-dessus")
	_check(not world.modifications.has(Vector2i(-30, 25)), "le relief n'est pas creusé au-dessus")
	_check(cs.raison_piece(Rect2i(-35, 22, 4, 4), 3, 1) != "", "on ne creuse pas deux fois au même niveau")
	var annexe := cs.creuser(Rect2i(-20, 20, 6, 6), 2, 1, "cave")
	_check(annexe >= 0 and String(cs.pieces[annexe].plan) == pid, "une cave collée rejoint le même sous-sol")
	var bk := cs.creuser(Rect2i(-104, 8, 8, 8), 8, 1, "bunker")
	_check(bk >= 0 and bool(cs.pieces[bk].sb), "bunker au −8 sous la maison (reprise en sous-œuvre)")
	var bil := cs.bilan()
	_check(int(bil.parking) == 16 and int(bil.abri) == 64, "bilan : %d places de parking, %d à l'abri" % [int(bil.parking), int(bil.abri)])
	pe.flush()
	vs.set_niveau(3)
	vs._maj()
	_check(int(vs.compte.pieces) >= 1 and int(vs.compte.plans) >= 1, "le parking se voit au −3 (%s)" % str(vs.compte))

	print("Chantier d'une pièce :")
	ReglagesPartie.actuel.construction_instantanee = false
	m0 = bs.money
	var ch := cs.creuser(Rect2i(30, 20, 10, 10), 4, 1, "entrepot")
	_check(ch >= 0 and float(cs.pieces[ch].av) == 0.0 and SuiviChantiers.instance.en_cours(CS.cle(ch)), "entrepôt en chantier")
	_check(bs.money == m0, "rien n'est payé avant les travaux")
	_check(String(SuiviChantiers.instance.etape(CS.cle(ch))[2]) == "Sondages et piquetage", "étapes d'un chantier souterrain")
	vs.set_niveau(4)
	if dossier != "":
		# Un peu de chantier pour voir la fouille avancer.
		cs.pieces[ch].av = 0.6
		vs._maj()
		rig.global_position = Vector3(0, y, 30)
		rig.set("_target_distance", 110.0)
		rig.set_pitch(55.0, true)
		cs.activer(CS.Outil.PIECE)
		cs._aide()
	await _shot("construction-souterraine-chantier.png")
	cs.desactiver()
	SuiviChantiers.instance.terminer(CS.cle(ch))
	_check(float(cs.pieces[ch].av) >= 1.0 and pe.est_souterrain(String(cs.pieces[ch].plan)), "travaux finis : sous-sol de l'Atelier")
	_check(m0 - bs.money == CS.prix_piece("entrepot", 100, 1, 4), "payé au fil des travaux")
	ReglagesPartie.actuel.construction_instantanee = true

	print("Atelier sous terre :")
	vs.set_niveau(2)
	cs.activer(CS.Outil.ATELIER, str(PlanEditor.Tool.OPENING))
	_check(pe.tool == PlanEditor.Tool.OPENING and pe.level == -2 and pe.sous_terre, "l'outil Porte de l'Atelier au Sous-sol −2")
	_check(pe.set_opening_at(pid, Vector4i(-35, -2, 20, 0), "porte"), "porte posée dans le mur du parking")
	_key(KEY_PAGEDOWN)
	await _frames(2)
	_check(pe.level == -3, "Page bas : l'Atelier suit la vue (−3)")
	var np := pe.new_plan(pe.ground_level(Vector2i(80, 80)))
	_check(pe.est_souterrain(np), "un mur posé sous terre fait un plan souterrain")
	pe.plans.erase(np)
	pe._bbox.erase(np)
	cs.desactiver()
	_check(pe.tool == PlanEditor.Tool.NONE and not pe.sous_terre, "outil rangé")
	await _shot("construction-souterraine-parking.png")

	print("Clavier :")
	cs.activer(CS.Outil.CONDUITE, "collecteur")
	res._trace = PackedVector3Array([Vector3(0, y, -80)])
	_key(KEY_ESCAPE)
	await _frames(2)
	_check(res._trace.is_empty() and cs.outil == CS.Outil.CONDUITE and scene.pause_menu == null, "Échap arrête le tracé de la conduite")
	_key(KEY_ESCAPE)
	await _frames(2)
	_check(cs.outil == CS.Outil.AUCUN and res.outil == Reseaux.Outil.AUCUN and vs.actif and scene.pause_menu == null, "Échap encore : outil rangé, sans menu pause")
	vs.set_niveau(5)
	cs.activer(CS.Outil.TUNNEL, "metro")
	_key(KEY_ESCAPE)
	await _frames(2)
	_check(cs.outil == CS.Outil.AUCUN and transport.tool == TransportSystem.Tool.NONE and is_nan(RoutePlanner.profondeur_forcee) and scene.pause_menu == null, "Échap range le métro")
	cs.activer(CS.Outil.PIECE)
	_key(KEY_ESCAPE)
	await _frames(2)
	_check(cs.outil == CS.Outil.AUCUN and vs.actif, "Échap range l'outil, la vue reste")
	_key(KEY_ESCAPE)
	await _frames(2)
	_check(not vs.actif and scene.pause_menu == null, "Échap encore : retour à la surface")

	print("Sauvegarde :")
	var d := cs.to_dict()
	var pd := pe.to_dict()
	pe.from_dict(pd)
	cs.from_dict(JSON.parse_string(JSON.stringify(d)))
	_check(cs.pieces.size() == 4 and (cs.pieces[pk].r as Rect2i) == Rect2i(-40, 20, 20, 10), "pièces relues")
	_check(pe.est_souterrain(pid), "le plan reste souterrain après relecture")
	_check(res.eau.troncons.has(nid) and is_equal_approx(float(res.eau.to_dict().troncons[str(nid)].prof), 4.5), "profondeur de la conduite sauvegardée")

	print("Supprimer :")
	vs.set_niveau(2)
	var argent := bs.money
	_check(cs.supprimer_a(Vector3(-17, y, 23), 2) and not cs.pieces.has(annexe), "la cave est comblée")
	_check(bs.money == argent, "sans remboursement de murs non payés")
	_check(pe.plans.has(pid) and pe.levels_of(pid).has(-3), "le parking reste")
	vs.set_niveau(6)
	_check(cs.supprimer_a(Vector3(0, y, 60), 6) and not transport.network.edges.has(mt.edges[0]), "le tunnel du métro est supprimé")
	vs.sortir()

	print("RÉSULTAT : ", "OK" if ok else "ÉCHEC")
	quit(0 if ok else 1)
