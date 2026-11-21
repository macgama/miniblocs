extends SceneTree
## Test du mode gestion « tycoon » : hôtel reconnu, tuile « Gérer l'hôtel » sur
## la fiche et bouton « Gérer » du menu Tourisme, niveaux des pièces, prix,
## paiement (compte de l'hôtel puis avance de la ville), effets sur le
## tourisme (lits, note, restaurant, étoiles, prix conseillé, entretien),
## demandes des clients (pourboire, satisfaction), remboursement, objectifs,
## sauvegarde, et écran isométrique (maquette, clients, employés, bulles,
## clic sur une pièce, Échap).
## Usage : godot --headless --path . --script res://tests/gestion_test.gd

var ok := true

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
	_types_tests()
	await _city_tests()
	print("TEST OK" if ok else "TEST ÉCHEC")
	quit(0 if ok else 1)


func _types_tests() -> void:
	print("Genres :")
	_check(GestionTypes.genre_de("hotel_3") == "hotel" and GestionTypes.genre_de("palace") == "hotel", "les hôtels se gèrent")
	_check(GestionTypes.genre_de("palace_belle_epoque") == "hotel" and GestionTypes.genre_de("motel") == "hotel", "les hôtels de la bible aussi")
	_check(GestionTypes.genre_de("camping") == "" and GestionTypes.genre_de("maison") == "", "pas le camping ni les maisons (pour l'instant)")
	var g := "hotel"
	_check(GestionTypes.ordre(g).size() == GestionTypes.pieces(g).size(), "chaque pièce est dans l'ordre d'affichage")
	for pid in GestionTypes.ordre(g):
		var p := GestionTypes.piece(g, String(pid))
		_check(p.has("rect") and p.has("decor") and p.has("effets") and int(p.max) >= 2, "pièce %s complète" % pid)
		for m in p.get("metiers", []):
			_check(Metiers.METIERS.has(String(m)), "%s : métier %s connu" % [pid, m])
		if p.has("via"):
			_check(GestionTypes.pieces(g).has(String(p.via)), "%s : on y passe par %s" % [pid, p.via])
	for d in GestionTypes.genre(g).demandes:
		_check(GestionTypes.pieces(g).has(String(d.piece)), "demande « %s » dans une pièce connue" % d.texte)
	_check(GestionTypes.piece_du_metier(g, "receptionniste") == "reception" and GestionTypes.piece_du_metier(g, "cuisinier") == "restaurant", "métiers rangés par pièce")
	_check(Icones.has_icon("lit") and Icones.has_icon("grue") and Icones.has_icon("haut"), "icônes du mode gestion")


func _city_tests() -> void:
	print("Ville :")
	Creations.persist = false
	BatimentsVie.chantiers = false
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
	var tour: Tourisme = scene.tourisme
	var gest: Gestion = scene.gestion
	var vue: GestionVue = scene.gestion_vue
	_check(gest != null and vue != null and Gestion.instance == gest, "gestion et écran branchés dans la scène")
	_check(scene.save_sections().has("gestion"), "section « gestion » dans la sauvegarde")
	var pop: Population = scene.population
	var prod: Production = scene.production
	for n in [transport.traffic, tour, pop, scene.parc, scene.zoo, scene.musee, scene.spectacles, scene.dechets, prod]:
		n.set_process(false)
	scene.urgences.set_process(false)
	scene.urgences.random_calls = false
	if scene.ambiance.weather != null:
		scene.ambiance.weather.set_process(false)
		scene.ambiance.weather.precip = 0.0
	bs.unlimited_money = false
	bs.money = 50_000_000
	ReglagesPartie.actuel.deblocage = "tout"
	var y := world.cell_height(Vector2i(0, 0))
	_check(transport.build_segment("route", Vector3(-400, y, 0), Vector3(400, y, 0)).ok, "route")
	bs.message.connect(func(t: String) -> void: print("    (bâtiments) ", t))
	var poser := func(id: String, c: Vector2i) -> int:
		var sn := bs.road_snap(id, c)
		if sn.is_empty():
			print("    pas de place le long de la route pour ", id)
			return -1
		return bs.place(id, sn.center, int(sn.r), 0, float(sn.get("a", 0.0)))
	var musee: int = poser.call("musee", Vector2i(-100, -16))
	var hotel: int = poser.call("hotel_3", Vector2i(0, -14))
	var deux: int = poser.call("hotel_2", Vector2i(60, -12))
	var camping: int = poser.call("camping", Vector2i(150, -30))
	_check(musee > 0 and hotel > 0 and deux > 0 and camping > 0, "musée, deux hôtels et un camping posés %s" % str([musee, hotel, deux, camping]))
	for b in [musee, hotel, deux, camping]:
		bs.buildings[b]["chantier"] = false
	tour.ignore_staff = true
	tour._sync()
	pop._sync_buildings()

	print("Fiche et menu Tourisme :")
	var hp: HabitantsPanel = scene.habitants_panel
	hp.set_open(true)
	hp.show_view("batiment", hotel)
	await process_frame
	var tg: Button = hp._body.find_child("TuileGestion", true, false)
	_check(tg != null and tg.text.begins_with("Gérer l'hôtel"), "tuile « Gérer l'hôtel » sur la fiche de l'hôtel")
	hp.show_view("batiment", camping)
	await process_frame
	_check(hp._body.find_child("TuileGestion", true, false) == null, "pas de tuile sur le camping")
	hp.set_open(false)

	print("Sans gestion, rien ne change :")
	var lits0 := tour.lits(hotel)
	var note0 := tour.note(hotel)
	_check(not gest.etats.has(hotel) and tour.etoiles(hotel) == 3, "hôtel 3 étoiles, sans état de gestion (lits %d, note %.2f)" % [lits0, note0])
	_check(tour.spec(hotel) == TourismeTypes.spec_of("hotel_3"), "spécification inchangée")

	print("Niveaux et prix :")
	var st := gest.etat(hotel)
	_check(int(st.niv.reception) == 1 and int(st.niv.chambres) == 1, "réception et chambres au niveau 1")
	_check(int(st.niv.restaurant) == 1, "l'hôtel-restaurant a déjà son restaurant (niveau 1)")
	_check(int(st.niv.piscine) == 0 and int(st.niv.spa) == 0 and int(st.niv.bar) == 0, "piscine, spa et bar à construire")
	_check(int(gest.etat(deux).niv.restaurant) == 0, "l'hôtel 2 étoiles n'a pas de restaurant")
	var p2 := gest.prix(hotel, "chambres")
	var p3 := 0
	_check(p2 > 10_000 and p2 < 300_000, "chambres niveau 2 : %s" % BuildingSystem.format_money(p2))
	_check(gest.prix(hotel, "piscine") > gest.prix(hotel, "parking"), "piscine plus chère que le parking")
	_check(tour.spec(hotel) == TourismeTypes.spec_of("hotel_3") and absf(tour.note(hotel) - note0) < 0.001, "état créé, effets nuls tant qu'on n'améliore rien")

	print("Payer : compte de l'hôtel puis caisse de la ville :")
	tour.heb[hotel].compte = 50_000.0
	var caisse0 := bs.money
	var r := gest.ameliorer(hotel, "chambres")
	_check(bool(r.ok) and gest.niveau(hotel, "chambres") == 2, "chambres au niveau 2")
	_check(int(r.batiment) == mini(50_000, p2) and int(r.ville) == p2 - mini(50_000, p2), "l'hôtel paie %s, la ville avance %s" % [BuildingSystem.format_money(int(r.batiment)), BuildingSystem.format_money(int(r.ville))])
	_check(bs.money == caisse0 - int(r.ville), "caisse de la ville débitée de l'avance")
	_check(tour.lits(hotel) > lits0, "plus de lits : %d → %d" % [lits0, tour.lits(hotel)])
	_check(tour.note(hotel) > note0, "meilleure note : %.2f → %.2f" % [note0, tour.note(hotel)])
	_check(gest.entretien_jour(hotel) > 0.0, "entretien en plus : %s / jour" % BuildingSystem.format_money(int(gest.entretien_jour(hotel))))
	p3 = gest.prix(hotel, "chambres")
	_check(p3 > p2, "le niveau 3 coûte plus cher (%s)" % BuildingSystem.format_money(p3))
	var spec0 := tour.spec(hotel)
	_check(not bool(spec0.get("piscine", false)), "pas encore de piscine")
	_check(bool(gest.ameliorer(hotel, "piscine").ok) and bool(tour.spec(hotel).get("piscine", false)), "piscine construite : le tourisme la voit")
	_check(bool(gest.ameliorer(deux, "restaurant").ok) and bool(tour.spec(deux).get("restaurant", false)), "restaurant construit dans l'hôtel 2 étoiles")
	var rouge := bs.money
	bs.money = 0
	tour.heb[hotel].compte = 0.0
	var refus := gest.ameliorer(hotel, "spa")
	_check(not bool(refus.ok) and gest.niveau(hotel, "spa") == 0, "sans argent, pas de travaux (%s)" % String(refus.get("error", "")))
	bs.money = rouge
	var e0 := gest.etoiles(hotel)
	for pid in ["chambres", "chambres", "bar", "bar", "spa", "spa", "restaurant", "piscine"]:
		gest.ameliorer(hotel, pid)
	_check(gest.etoiles(hotel) > e0 and tour.etoiles(hotel) == gest.etoiles(hotel), "le confort fait gagner des étoiles : %d → %d" % [e0, gest.etoiles(hotel)])
	_check(float(tour.spec(hotel).prix) > float(TourismeTypes.spec_of("hotel_3").prix), "prix conseillé plus haut avec plus d'étoiles")
	var maxi := 0
	for i in 10:
		gest.ameliorer(hotel, "chambres")
	maxi = gest.niveau(hotel, "chambres")
	_check(maxi == 5 and gest.prix(hotel, "chambres") == 0 and not bool(gest.ameliorer(hotel, "chambres").ok), "niveau 5 au maximum")

	print("Une journée : les améliorations comptent :")
	scene.musee._dirty = true
	scene.musee.list()
	tour._maj_sites()
	for i in 3:
		var t := VENDREDI + 86400.0 * (i + 1)
		tour.last_day = int(tour._now(t).day)
		tour.clock = t
		prod.clock = t
		tour.new_day(tour._now(t))
	_check(tour.clients(hotel) > 0, "l'hôtel a des clients (%d)" % tour.clients(hotel))
	_check(float(tour.heb[hotel].hier.charges) > gest.entretien_jour(hotel), "l'entretien est compté dans les charges")

	print("Demandes des clients :")
	var possibles := gest.demandes_possibles(hotel)
	_check(possibles.size() >= 6, "%d demandes possibles" % possibles.size())
	var pieces_ok := true
	for d in possibles:
		pieces_ok = pieces_ok and gest.niveau(hotel, String(d.piece)) > 0
	_check(pieces_ok, "seulement dans les pièces construites")
	var compte0 := gest.compte(hotel)
	tour.heb[hotel].satisf = 3.0
	var tip := gest.regler(hotel, possibles[0])
	_check(tip > 0.0 and gest.compte(hotel) > compte0, "pourboire de %.0f € sur le compte" % tip)
	_check(float(tour.heb[hotel].satisf) > 3.0, "clients plus contents")
	gest.rater(hotel)
	_check(int(gest.etat(hotel).ratees) == 1, "demande oubliée comptée")

	print("Remboursement et objectifs :")
	var avance := float(gest.etat(hotel).aide_ville)
	_check(avance > 0.0, "la ville a avancé %s" % BuildingSystem.format_money(int(avance)))
	tour.heb[hotel].compte = avance + 1000.0
	var caisse1 := bs.money
	var rb := gest.rembourser(hotel)
	_check(rb == int(avance) and bs.money == caisse1 + rb and float(gest.etat(hotel).aide_ville) < 1.0, "l'hôtel rembourse la ville (%s)" % BuildingSystem.format_money(rb))
	var obj := gest.objectifs(hotel)
	_check(obj.size() >= 4 and bool(obj[0].fait), "objectifs (« %s » fait)" % String(obj[0].texte))

	print("Sauvegarde :")
	var d := gest.to_dict()
	var niv_avant: Dictionary = gest.etat(hotel).niv.duplicate()
	gest.clear()
	_check(not gest.etats.has(hotel) and tour.spec(hotel) == TourismeTypes.spec_of("hotel_3"), "effacé : l'hôtel redevient comme avant")
	gest.from_dict(JSON.parse_string(JSON.stringify(d)))
	_check(gest.etats.has(hotel) and gest.etat(hotel).niv == niv_avant, "rechargé : mêmes niveaux")
	_check(bool(tour.spec(hotel).get("piscine", false)), "la piscine revient avec la sauvegarde")

	print("Écran isométrique :")
	tour.heb[hotel].clients = [[40, 3, 3.0], [30, 2, 3.0]]
	_check(scene.ouvrir_gestion(hotel) and vue.est_ouvert(), "l'écran s'ouvre")
	_check(not scene.ouvrir_gestion(camping) or vue.bid == hotel, "le camping ne s'ouvre pas")
	await process_frame
	var dio := vue.diorama
	_check(dio.places.has("chambres") and not (dio.places.chambres as Array).is_empty(), "%d places dans les chambres" % (dio.places.chambres as Array).size())
	_check(dio.places.has("piscine") and dio.places.has("restaurant"), "piscine et restaurant meublés")
	_check(dio.clients.size() >= 2, "%d clients déjà là" % dio.clients.size())
	for i in 400:
		vue.simuler(0.1)
	var installes := 0
	for c in dio.clients:
		if String(c.etat) == "installe":
			installes += 1
	_check(installes > 0, "%d clients installés dans les pièces" % installes)
	_check(dio.clients.size() <= GestionVue.MAX_VISIBLES, "pas trop de monde à l'écran (%d)" % dio.clients.size())
	# Une bulle de demande et le clic dessus.
	var bulle := {}
	for i in 300:
		vue.simuler(0.1)
		for c in dio.clients:
			if not (c.demande as Dictionary).is_empty():
				bulle = c
		if not bulle.is_empty():
			break
	_check(not bulle.is_empty() and bulle.bulle != null, "un client a une demande (« %s »)" % String(bulle.get("demande", {}).get("texte", "")))
	var reg0 := int(gest.etat(hotel).reglees)
	if not bulle.is_empty():
		vue._regler(bulle)
	_check(int(gest.etat(hotel).reglees) == reg0 + 1 and (bulle.get("demande", {}) as Dictionary).is_empty(), "demande réglée d'un clic")
	# Choisir une pièce.
	vue.choisir("spa")
	_check(vue.selection == "spa" and vue._carte_corps.get_child_count() > 3, "carte du spa")
	vue.choisir("")
	_check(vue._bas.get_child_count() == GestionTypes.ordre("hotel").size() + 1, "une tuile par pièce en bas")
	var p0 := dio.centre("bar")
	_check(dio.piece_en(p0) == "bar" and dio.piece_en(Vector3(-50, 0, -50)) == "", "pièce sous un point du sol")
	# Améliorer depuis l'écran.
	bs.money = 50_000_000
	vue.choisir("parking")
	var bouton: Button = vue._carte_corps.find_child("Ameliorer", true, false)
	_check(bouton != null and not bouton.disabled, "bouton « Construire » du parking")
	if bouton != null:
		bouton.pressed.emit()
	await process_frame
	_check(gest.niveau(hotel, "parking") == 1, "parking construit depuis l'écran")
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.pressed = true
	vue._input(ev)
	vue._input(ev)
	_check(not vue.est_ouvert(), "Échap ramène à la ville")
	scene.queue_free()
	await process_frame
