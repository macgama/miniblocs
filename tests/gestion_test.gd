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
	print("Objets :")
	var nb := 0
	var modeles_ok := true
	var poses_ok := true
	for pid in GestionTypes.ordre(g):
		var r: Array = GestionTypes.piece(g, String(pid)).rect
		for oid in GestionTypes.objets(g, String(pid)):
			var o := GestionTypes.objet(g, String(pid), String(oid))
			nb += 1
			_check(o.has("nom") and o.has("prix") and o.has("effets") and int(o.get("niv", 1)) <= int(GestionTypes.piece(g, String(pid)).max), "%s/%s complet" % [pid, oid])
			var m := String(o.get("modele", ""))
			if m != "":
				var k := LpKit.new(1)
				GestionModeles.dessiner(k, m, Vector3.ZERO, 0.0)
				if k.triangle_count() <= 0:
					modeles_ok = false
					push_error("modèle vide : " + m)
				var w := 10.0 if bool(o.get("cellules", false)) else float(r[2])
				var d := float(r[3]) / 6.0 if bool(o.get("cellules", false)) else float(r[3])
				for ps in o.get("poses", []):
					if float(ps[0]) < -0.01 or float(ps[0]) > w + 0.01 or float(ps[1]) < -3.0 or float(ps[1]) > d + 0.01:
						poses_ok = false
						push_error("%s/%s posé hors de la pièce : %s" % [pid, oid, ps])
	_check(nb >= 70, "%d objets à acheter" % nb)
	_check(modeles_ok, "chaque objet a son modèle 3D")
	_check(poses_ok, "chaque objet est posé dans sa pièce")
	for f in ["pannes", "pensees", "activites"]:
		_check(GestionTypes.genre(g).has(f), "le genre a ses %s" % f)


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

	print("Objets, personnel, pannes :")
	bs.money = 50_000_000
	var c0 := gest.effet(hotel, "confort")
	_check(gest.refus_objet(hotel, "reception", "lustre") != "" and not bool(gest.acheter(hotel, "reception", "lustre").ok), "le lustre attend le hall au niveau 4")
	var ra := gest.acheter(hotel, "reception", "plantes_hall")
	_check(bool(ra.ok) and gest.a_objet(hotel, "reception", "plantes_hall") and gest.effet(hotel, "confort") > c0, "plantes vertes installées : plus de confort")
	_check(gest.refus_objet(hotel, "reception", "plantes_hall") == "déjà installé", "on n'achète pas deux fois le même objet")
	_check(gest.prix_objet(hotel, "chambres", "tele") > 0 and gest.prix_objet(hotel, "piscine", "toboggan") > gest.prix_objet(hotel, "piscine", "bouees"), "prix des objets")
	var s0 := gest.effet(hotel, "satisf")
	gest.set_salaire(hotel, 9.0)
	_check(absf(float(gest.etat(hotel).salaire) - Gestion.SALAIRE_MAX) < 0.001 and gest.effet(hotel, "satisf") > s0, "salaires au maximum : équipe plus souriante")
	var ent0 := gest.entretien_jour(hotel)
	gest.set_salaire(hotel, 1.0)
	_check(gest.entretien_jour(hotel) < ent0, "et ça coûte plus cher")
	var v0 := gest.effet(hotel, "vitesse")
	_check(bool(gest.former(hotel).ok) and int(gest.etat(hotel).formation) == 1 and gest.effet(hotel, "vitesse") > v0, "formation du personnel")
	var sp0 := gest.effet(hotel, "satisf")
	var pn := gest.nouvelle_panne(hotel)
	_check(not pn.is_empty() and (gest.etat(hotel).pannes as Array).size() == 1, "une panne : %s" % String(pn.get("texte", "")))
	_check(gest.effet(hotel, "satisf") < sp0, "la panne pèse sur la satisfaction")
	_check(bool(gest.reparer(hotel, 0).ok) and (gest.etat(hotel).pannes as Array).is_empty() and int(gest.etat(hotel).reparees) == 1, "panne réparée")
	_check((gest.etat(hotel).journal as Array).size() >= 3, "le journal raconte (%d lignes)" % (gest.etat(hotel).journal as Array).size())

	print("Gestion automatique :")
	gest.set_auto(deux, false)
	tour.heb[deux].compte = 5_000_000.0
	var inv0 := float(gest.etat(deux).invest)
	gest.nouveau_jour({"day": 40, "month": 7})
	_check(absf(float(gest.etat(deux).invest) - inv0) < 1.0, "« Je gère » : l'hôtel n'achète rien tout seul")
	_check((gest.etat(deux).hist as Array).size() >= 1, "historique du jour enregistré")
	gest.set_auto(deux, true)
	var caisse_auto := bs.money
	gest.nouvelle_panne(deux)
	gest.nouveau_jour({"day": 41, "month": 7})
	_check(float(gest.etat(deux).invest) > inv0, "auto : l'hôtel investit ses bénéfices (%s)" % BuildingSystem.format_money(int(float(gest.etat(deux).invest) - inv0)))
	_check((gest.etat(deux).pannes as Array).is_empty(), "auto : les pannes sont réparées")
	_check(bs.money == caisse_auto, "auto : la caisse de la ville n'est jamais touchée")
	tour.heb[deux].compte = 0.0
	var inv1 := float(gest.etat(deux).invest)
	gest.nouveau_jour({"day": 42, "month": 7})
	_check(absf(float(gest.etat(deux).invest) - inv1) < 1.0, "auto sans argent : rien")
	var nb_cand := gest.candidats(hotel).size()
	_check(nb_cand > 20, "%d achats possibles pour la gestion auto" % nb_cand)

	print("Sauvegarde :")
	gest.nouvelle_panne(hotel)
	gest.set_salaire(hotel, 1.2)
	var d := gest.to_dict()
	var niv_avant: Dictionary = gest.etat(hotel).niv.duplicate()
	gest.clear()
	_check(not gest.etats.has(hotel) and tour.spec(hotel) == TourismeTypes.spec_of("hotel_3"), "effacé : l'hôtel redevient comme avant")
	gest.from_dict(JSON.parse_string(JSON.stringify(d)))
	_check(gest.etats.has(hotel) and gest.etat(hotel).niv == niv_avant, "rechargé : mêmes niveaux")
	_check(bool(tour.spec(hotel).get("piscine", false)), "la piscine revient avec la sauvegarde")
	_check(gest.a_objet(hotel, "reception", "plantes_hall") and (gest.etat(hotel).pannes as Array).size() >= 1, "objets et pannes reviennent")
	_check(absf(float(gest.etat(hotel).salaire) - 1.2) < 0.001 and int(gest.etat(hotel).formation) == 1, "salaire et formation reviennent")
	_check(gest.auto(deux), "le mode automatique revient")

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
	# Objets depuis l'écran.
	vue.choisir("reception")
	var ligne: Node = vue._carte_corps.find_child("Objet_canapes_hall", true, false)
	_check(ligne != null, "la carte de la réception liste ses objets")
	var acheter: Button = ligne.find_child("Acheter", true, false) if ligne != null else null
	_check(acheter != null and not acheter.disabled, "bouton d'achat des canapés")
	if acheter != null:
		acheter.pressed.emit()
	await process_frame
	_check(gest.a_objet(hotel, "reception", "canapes_hall"), "canapés achetés depuis l'écran")
	var assis := 0
	for pl in dio.places.get("reception", []):
		if bool(pl.assis):
			assis += 1
	_check(assis >= 4, "les canapés offrent des places assises (%d)" % assis)
	# Panne sur la maquette, onglets.
	_check(dio.pannes_l.size() == (gest.etat(hotel).pannes as Array).size() and dio.pannes_l.size() >= 1, "la panne s'affiche sur la maquette")
	vue.choisir("")
	for o in ["personnel", "stats", "journal", "ensemble"]:
		var b: Button = vue._carte_corps.find_child("Onglet_" + o, true, false)
		_check(b != null, "onglet %s" % o)
		if b != null:
			b.pressed.emit()
			await process_frame
			_check(vue.onglet == o, "onglet %s ouvert" % o)
		if o == "personnel":
			var rep: Button = vue._carte_corps.find_child("Reparer", true, false)
			_check(rep != null, "bouton Réparer dans l'équipe")
			var np0 := (gest.etat(hotel).pannes as Array).size()
			if rep != null:
				rep.pressed.emit()
				await process_frame
				_check((gest.etat(hotel).pannes as Array).size() == np0 - 1 and dio.pannes_l.size() == np0 - 1, "réparé depuis l'écran")
			var plus: Button = vue._carte_corps.find_child("Salaire_plus", true, false)
			if plus != null:
				plus.pressed.emit()
			_check(float(gest.etat(hotel).salaire) > 1.2, "salaires augmentés depuis l'écran")
	var auto: Button = vue._racine.find_child("Auto", true, false)
	_check(auto != null and auto.button_pressed == gest.auto(hotel), "bouton Gestion auto")
	if auto != null:
		auto.button_pressed = not auto.button_pressed
	_check(auto != null and gest.auto(hotel) == auto.button_pressed, "bascule auto / je gère")
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.pressed = true
	vue._input(ev)
	vue._input(ev)
	_check(not vue.est_ouvert(), "Échap ramène à la ville")
	scene.queue_free()
	await process_frame
