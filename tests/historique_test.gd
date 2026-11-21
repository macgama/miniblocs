extends SceneTree
## Test d'annuler / rétablir en ville (HistoriqueVille, Ctrl+Z / Ctrl+Y) et du mode
## plan (ModePlan, Ctrl+P) : bâtiments posés et démolis (argent rendu au centime),
## voies avec carrefour (mêmes numéros de tronçons), relief, zones, projets en
## fantômes, validation en bloc défaite d'un coup, sauvegarde des projets.
## Usage : godot --headless --path . --script res://tests/historique_test.gd

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


func _cle_reseau(net: TransportNetwork) -> String:
	var ids := net.edges.keys()
	ids.sort()
	return str(ids) + "/" + str(net.nodes.size())


func _touche(scene: Node, code: Key, maj := false) -> void:
	var k := InputEventKey.new()
	k.keycode = code
	k.pressed = true
	k.ctrl_pressed = true
	k.shift_pressed = maj
	scene._touche_historique(k)


func _run() -> void:
	Creations.persist = false
	ReglagesPartie.actuel = ReglagesPartie.preset("normal")
	ReglagesPartie.actuel.deblocage = "tout"  # (ce test ne porte pas sur l'arbre de progression)
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	root.add_child(scene)
	world.tiles.offline_generator = _fake_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.set_origin(48.8584, 2.2945)
	for i in 90:
		await process_frame
	var h: HistoriqueVille = scene.historique
	var mp: ModePlan = scene.mode_plan
	_check(h != null and HistoriqueVille.instance == h, "nœud Historique")
	_check(mp != null and ModePlan.instance == mp, "nœud ModePlan")
	bs.require_access = false
	bs.unlimited_money = false
	h.vider()

	print("Bâtiments :")
	BatimentsVie.chantiers = false
	var m0 := bs.money
	var bid := bs.place("maison", Vector2i(40, 40), 0)
	_check(bid >= 0, "maison posée")
	h.noter_pose(bid)
	var m1 := bs.money
	_check(m1 < m0, "la maison est payée (%s)" % BuildingSystem.format_money(m0 - m1))
	_check(h.nom_annuler() == HistoriqueVille._nom_type("maison"), "Ctrl+Z proposera « %s »" % h.nom_annuler())
	_touche(scene, KEY_Z)
	_check(not bs.buildings.has(bid), "Ctrl+Z : la maison disparaît")
	_check(bs.money == m0, "tout l'argent revient (%d = %d)" % [bs.money, m0])
	_touche(scene, KEY_Y)
	_check(bs.buildings.has(bid), "Ctrl+Y : la maison revient, même numéro")
	_check(bs.money == m1, "elle est payée à nouveau")
	_touche(scene, KEY_Z)
	_touche(scene, KEY_Z, true)
	_check(bs.money == m1 and bs.buildings.has(bid), "Ctrl+Maj+Z rétablit aussi")
	# Démolition : 50 % rendus, que Ctrl+Z reprend.
	var avant: Dictionary = bs.buildings[bid].duplicate(true)
	var rendu := bs.demolish(bid)
	h.noter_demolition(avant, rendu)
	_check(rendu > 0 and bs.money == m1 + rendu, "démolie, %s rendus" % BuildingSystem.format_money(rendu))
	h.annuler()
	_check(bs.buildings.has(bid) and bs.money == m1, "démolition annulée : la maison revient, le remboursement est repris")
	h.refaire()
	_check(not bs.buildings.has(bid) and bs.money == m1 + rendu, "démolition rétablie")
	h.vider()
	# Chantier : ce qui a été payé au fil des travaux revient aussi.
	BatimentsVie.chantiers = true
	var mc0 := bs.money
	var bc := bs.place("maison", Vector2i(80, 40), 0)
	h.noter_pose(bc)
	var bcd: Dictionary = bs.buildings[bc]
	_check(bcd.has("du") and bs.money == mc0, "chantier lancé, rien payé d'avance")
	bcd["du"] = int(bcd.du) - 1000
	bs.money -= 1000
	h.annuler()
	_check(not bs.buildings.has(bc) and bs.money == mc0, "chantier annulé : les 1 000 € déjà payés reviennent")
	h.refaire()
	_check(bs.buildings.has(bc) and int(bs.buildings[bc].get("du", 0)) == int(bs.buildings[bc].cost), "rétabli : le chantier repart de zéro")
	h.annuler()
	BatimentsVie.chantiers = false

	print("Voies :")
	h.vider()
	var net := transport.network
	var vide := _cle_reseau(net)
	var av := transport.photo_reseau()
	var ra := transport.build_path("departementale", {}, PackedVector2Array([Vector2(-100, 0), Vector2(100, 0)]))
	_check(bool(ra.ok), "route A tracée")
	transport.edges_built.emit(ra.edges)
	transport._noter_histo("Route A", av)
	var apres_a := _cle_reseau(net)
	# Deux clics, deux gestes (dans la même image, ils n'en feraient qu'un).
	await process_frame
	av = transport.photo_reseau()
	var rb := transport.build_path("departementale", {}, PackedVector2Array([Vector2(0, 0), Vector2(0, 120)]))
	_check(bool(rb.ok), "route B branchée au milieu de A (A coupée en deux)")
	transport.edges_built.emit(rb.edges)
	transport._noter_histo("Route B", av)
	var apres_b := _cle_reseau(net)
	_check(net.edges.size() == 3, "3 tronçons après le carrefour (%d)" % net.edges.size())
	h.annuler()
	_check(_cle_reseau(net) == apres_a, "Ctrl+Z : B disparaît et A redevient un seul tronçon, même numéro")
	h.annuler()
	_check(_cle_reseau(net) == vide, "Ctrl+Z : plus de route")
	h.refaire()
	h.refaire()
	_check(_cle_reseau(net) == apres_b, "Ctrl+Y ×2 : le carrefour revient à l'identique")
	await process_frame
	var une: int = net.edges.keys()[0]
	av = transport.photo_reseau()
	transport.demolish(une)
	transport._noter_histo("Démolition", av)
	h.annuler()
	_check(net.edges.has(une) and _cle_reseau(net) == apres_b, "démolition d'un tronçon annulée")

	print("Relief :")
	h.vider()
	var c := Vector2i(300, 300)
	var h0 := world.cell_height(c)
	h.ouvrir_geste()
	world.current_tool = TerrainWorld.Tool.RAISE
	world.apply_tool(c, c + Vector2i(2, 2))
	h.fermer_geste()
	_check(world.cell_height(c) == h0 + 1.0, "terrain monté d'1 m")
	h.annuler()
	_check(world.cell_height(c) == h0 and not world.modifications.has(c), "Ctrl+Z : le relief revient tel quel")
	h.refaire()
	_check(world.cell_height(c) == h0 + 1.0, "Ctrl+Y : remonté")

	print("Zones :")
	h.vider()
	var zones: ZoneSystem = scene.zones
	var nz := zones.zones.size()
	var mz := bs.money
	zones.mode = ZoneSystem.Mode.PAINT
	h.ouvrir_geste()
	_check(zones.add_zone("R", Rect2i(200, 200, 30, 30)) >= 0, "zone ajoutée")
	h.fermer_geste()
	_check(zones.zones.size() == nz + 1, "zone peinte (%s)" % BuildingSystem.format_money(mz - bs.money))
	h.annuler()
	_check(zones.zones.size() == nz, "Ctrl+Z : la zone disparaît")
	_check(bs.money == mz, "le prix de la zone revient")
	h.refaire()
	_check(zones.zones.size() == nz + 1, "Ctrl+Y : la zone revient")

	print("Décors :")
	h.vider()
	var dec: DecorSystem = scene.decors
	var d_id := String((Decors.tous()[0] as Dictionary).id)
	var np := dec.nombre_poses()
	dec.outil = DecorSystem.Outil.POSER
	h.ouvrir_geste()
	dec.pose(d_id, 150.0, 150.0, 0.0, 1.0, true)
	dec.pose(d_id, 154.0, 150.0, 0.0, 1.0, true)
	h.fermer_geste()
	dec.outil = DecorSystem.Outil.AUCUN
	_check(dec.nombre_poses() == np + 2, "2 décors posés d'un geste")
	h.annuler()
	_check(dec.nombre_poses() == np, "Ctrl+Z : les 2 décors disparaissent")
	h.refaire()
	_check(dec.nombre_poses() == np + 2, "Ctrl+Y : ils reviennent")

	print("Mode plan :")
	h.vider()
	var mb0 := bs.money
	var nb0 := bs.buildings.size()
	var ne0 := net.edges.size()
	_touche(scene, KEY_P)
	_check(mp.actif, "Ctrl+P : mode plan ouvert")
	_check(scene.mode_plan_panel._panel.visible, "encadré du mode plan affiché")
	_check(mp.capter_voie("departementale", {}, PackedVector2Array([Vector2(-100, 200), Vector2(100, 200)])), "voie en projet")
	await process_frame
	_check(mp.capter_batiment("maison", Vector2i(0, 212), 0), "maison en projet le long de la voie prévue")
	_check(not mp.capter_batiment("maison", Vector2i(0, 212), 0), "pas deux projets au même endroit")
	_check(not mp.capter_batiment("maison", Vector2i(-50, 200), 0), "pas de bâtiment sur une voie en projet")
	_check(not mp.capter_voie("departementale", {}, PackedVector2Array([Vector2(0, 180), Vector2(0, 240)])), "pas de voie à travers un bâtiment en projet")
	_check(mp.projets.size() == 2 and mp._fantomes.size() == 2, "2 fantômes bleus")
	_check(bs.money == mb0 and bs.buildings.size() == nb0 and net.edges.size() == ne0, "rien payé, rien construit")
	_check(mp.cout_total() > 0, "total estimé : %s" % BuildingSystem.format_money(mp.cout_total()))
	h.annuler()
	_check(mp.projets.size() == 1, "Ctrl+Z retire le dernier projet")
	h.refaire()
	_check(mp.projets.size() == 2, "Ctrl+Y le remet")
	# Sauvegarde : section « projets » passée par JSON.
	var d: Variant = JSON.parse_string(JSON.stringify(mp.to_dict()))
	mp.from_dict(d)
	_check(mp.projets.size() == 2 and mp._fantomes.size() == 2, "projets relus depuis la sauvegarde")
	_check(scene.save_sections().has("projets"), "section « projets » dans la sauvegarde")
	h.vider()
	var res: Dictionary = mp.valider()
	_check(int(res.faits) == 2 and mp.projets.is_empty(), "Tout construire : 2 constructions (%s)" % str(res))
	_check(bs.buildings.size() == nb0 + 1 and net.edges.size() > ne0, "voie et maison bien là")
	_check(bs.money < mb0, "la maison est payée à la validation")
	_check(h.taille() == 1, "la validation est un seul geste")
	h.annuler()
	_check(bs.buildings.size() == nb0 and net.edges.size() == ne0 and bs.money == mb0, "Ctrl+Z défait toute la validation, argent compris")
	_check(mp.projets.size() == 2, "… et les projets reviennent en bleu")
	h.refaire()
	_check(bs.buildings.size() == nb0 + 1 and mp.projets.is_empty(), "Ctrl+Y : reconstruit")
	# Projet refusé : il reste, avec sa raison.
	bs.money = 0
	mp.capter_batiment("maison", Vector2i(60, 230), 0)
	mp.valider()
	_check(mp.projets.size() == 1 and mp.refus.size() == 1, "sans argent, le projet reste (%s)" % str(mp.refus.values()))
	mp.effacer_tout()
	_check(mp.projets.is_empty() and mp._fantomes.is_empty(), "plan effacé")
	_touche(scene, KEY_P)
	_check(not mp.actif, "Ctrl+P : mode plan fermé")

	print("Coût d'un clic dans une grande ville :")
	for i in 300:
		zones.add_zone("R", Rect2i(-600 + (i % 20) * 60, -600 + (i / 20) * 60, 40, 40))
	var decors: DecorSystem = scene.decors
	var cle_decor := ""
	var tous := Decors.tous()
	if not tous.is_empty():
		cle_decor = String(tous[0].id) if tous[0] is Dictionary else String(tous[0])
	var nd := 0
	if cle_decor != "":
		for i in 4000:
			if decors.pose(cle_decor, -1000.0 + float(i % 80) * 12.0, 800.0 + float(i / 80) * 12.0, 0.0, 1.0, true):
				nd += 1
	decors.outil = DecorSystem.Outil.POSER
	var t0 := Time.get_ticks_usec()
	for i in 10:
		h.ouvrir_geste()
		h.fermer_geste()
	var ms := float(Time.get_ticks_usec() - t0) / 10000.0
	print("  %d zones, %d décors, outils Zones et Décors ouverts : %.2f ms par clic" % [zones.zones.size(), nd, ms])
	zones.mode = ZoneSystem.Mode.NONE
	decors.outil = DecorSystem.Outil.AUCUN
	t0 = Time.get_ticks_usec()
	for i in 10:
		h.ouvrir_geste()
		h.fermer_geste()
	var ms0 := float(Time.get_ticks_usec() - t0) / 10000.0
	print("  sans outil : %.2f ms par clic" % ms0)
	_check(ms < 25.0 and ms0 < 2.0, "un clic reste léger (%.2f ms, %.2f ms sans outil)" % [ms, ms0])

	print("Enclos du zoo :")
	h.vider()
	bs.money = 1_000_000
	var zoo: ZooSysteme = scene.zoo
	scene.zoo_outils.outil = ZooOutils.Outil.ENCLOS
	var ne := zoo.enclos.size()
	h.ouvrir_geste()
	var eid := zoo.ajouter_enclos(PackedVector2Array([Vector2(300, 300), Vector2(340, 300), Vector2(340, 340), Vector2(300, 340)]))
	h.fermer_geste()
	var me := bs.money
	_check(eid >= 0 and me < 1_000_000, "enclos tracé, barrière payée (%s)" % BuildingSystem.format_money(1_000_000 - me))
	h.annuler()
	_check(zoo.enclos.size() == ne and bs.money == 1_000_000, "Ctrl+Z : l'enclos disparaît, la barrière est remboursée")
	h.refaire()
	_check(zoo.enclos.has(eid) and bs.money == me, "Ctrl+Y : l'enclos revient, même numéro")
	scene.zoo_outils.outil = ZooOutils.Outil.AUCUN

	print("Champs :")
	h.vider()
	var agri: Agriculture = scene.agriculture
	bs.money = 5_000_000
	var fbid := bs.place("ferme_cereales", Vector2i(-200, -220), 0)
	agri.outil = "champ"
	var nc := agri.champs.size()
	h.ouvrir_geste()
	var cid := agri.ajoute_champ(Rect2i(Vector2i(-230, -160), Vector2i(50, 50)), "ble", fbid)
	h.fermer_geste()
	_check(cid >= 0, "champ tracé")
	h.annuler()
	_check(agri.champs.size() == nc, "Ctrl+Z : le champ disparaît")
	h.refaire()
	_check(agri.champs.has(cid) and agri.champs[cid].r == Rect2i(Vector2i(-230, -160), Vector2i(50, 50)), "Ctrl+Y : le champ revient tel quel")
	agri.outil = ""

	print("Séance d'éditeur libre :")
	h.vider()
	bs.money = 1_000_000
	var be: BlockEditor = scene.get_node("Blocs")
	be.set_tool(BlockEditor.Tool.BLOCK)
	await process_frame
	_check(h.en_seance(), "séance ouverte avec l'outil")
	var gk := world.cell_height(Vector2i(-120, -100))
	var b0 := Vector3i(-120, roundi(gk / BlockEditor.UNIT_Y), -100)
	var nb := be.blocks.size()
	be.place_blocks([b0], 0)
	be.place_blocks([b0 + Vector3i(1, 0, 0)], 0)
	_check(be.blocks.size() == nb + 2, "deux blocs posés")
	be.undo()
	_check(be.blocks.size() == nb + 1, "dans l'outil, son Ctrl+Z défait un bloc")
	var mb := bs.money
	be.set_tool(BlockEditor.Tool.NONE)
	await process_frame
	_check(not h.en_seance() and h.taille() == 1, "outil fermé : la séance est un seul geste (%s)" % h.nom_annuler())
	h.annuler()
	_check(be.blocks.size() == nb and bs.money == 1_000_000, "Ctrl+Z : le bloc restant part, son prix revient")
	h.refaire()
	_check(be.blocks.size() == nb + 1 and bs.money == mb, "Ctrl+Y : il revient, repayé")

	print("Façade :")
	h.vider()
	var fid := bs.place("maison", Vector2i(60, -60), 0)
	var p0: Dictionary = bs.perso_of(fid).duplicate(true)
	var photo := h.photo()
	bs.money -= 5000
	bs.set_perso(fid, {"murs": "#aa3322"})
	h.noter_lot("Façade : maison", photo, [{"k": "perso", "bid": fid, "av": p0, "v_av": int(bs.buildings[fid].get("v", 0)),
		"ap": bs.perso_of(fid).duplicate(true), "v_ap": int(bs.buildings[fid].get("v", 0))}])
	var mf := bs.money
	h.annuler()
	_check(bs.perso_of(fid) == p0 and bs.money == mf + 5000, "Ctrl+Z : façade d'avant, travaux remboursés")
	h.refaire()
	_check(bs.perso_of(fid).get("murs", "") == "#aa3322" and bs.money == mf, "Ctrl+Y : nouvelle façade, repayée")

	print("Fondation :")
	h.refaire()
	_check(h.taille() > 0, "historique non vide")
	print("TEST OK" if ok else "TEST ÉCHEC")
	quit(0 if ok else 1)
