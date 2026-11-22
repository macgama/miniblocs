extends SceneTree
## Test du mode gestion du commissariat : pièces, objets et modèles complets,
## tuile « Gérer le commissariat », budget versé par la ville, voitures en
## plus dans la vraie flotte de police (garage), policiers en service en plus
## (vestiaires), travail plus rapide sur place, enquêteurs qui élucident les
## cambriolages arrivés trop tard, fourrière, événements, gestion
## automatique, sauvegarde, et écran isométrique (voitures qui partent).
## Usage : godot --headless --path . --script res://tests/gestion_commissariat_test.gd

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


func _run() -> void:
	_types_tests()
	await _city_tests()
	print("TEST OK" if ok else "TEST ÉCHEC")
	quit(0 if ok else 1)


func _types_tests() -> void:
	print("Genre commissariat :")
	var n := 0
	for id in BuildingCatalog.all_types():
		if GestionTypes.genre_de(String(id)) == "commissariat":
			n += 1
	_check(n >= 1 and GestionTypes.genre_de("police") == "commissariat", "%d commissariat(s) se gèrent" % n)
	_check(GestionTypes.genre_de("pompiers") == "caserne", "la caserne reste une caserne")
	_check(GestionTypes.genre_de("haussmann__restaurant") == "restaurant" and GestionTypes.genre_de("hotel_3") == "hotel", "restaurant et hôtel inchangés")
	var g := "commissariat"
	var gd := GestionTypes.genre(g)
	_check(String(gd.titre) == "Gérer le commissariat" and Icones.has_icon(String(gd.icone)), "titre et icône")
	_check(String(gd.source) == "ville", "service public payé par la ville")
	_check(GestionTypes.ordre(g).size() == GestionTypes.pieces(g).size() and GestionTypes.ordre(g).size() >= 12, "%d pièces, toutes dans l'ordre" % GestionTypes.ordre(g).size())
	_check(GestionTypes.pieces(g).has(String(gd.accueil)), "la pièce d'accueil existe")
	for pid in GestionTypes.ordre(g):
		var p := GestionTypes.piece(g, String(pid))
		_check(p.has("rect") and p.has("decor") and p.has("effets") and int(p.max) >= 2, "pièce %s complète" % pid)
		for m in p.get("metiers", []):
			_check(Metiers.METIERS.has(String(m)), "%s : métier %s connu" % [pid, m])
		if p.has("via"):
			_check(GestionTypes.pieces(g).has(String(p.via)), "%s : on y passe par %s" % [pid, p.via])
	for d in gd.demandes:
		_check(GestionTypes.pieces(g).has(String(d.piece)), "demande « %s » dans une pièce connue" % d.texte)
	for a in gd.activites:
		_check(GestionTypes.pieces(g).has(String(a[0])), "activité %s" % a[0])
	for f in gd.flotte_extra:
		_check(not VehicleCatalog.get_type(String(f[1])).is_empty() and String(f[0]) in Urgences.SERVICES, "voiture en plus : %s (%s)" % [f[1], f[0]])
	_check((gd.baies as Array).size() >= (Urgences.FLEETS.police as Array).size() + (gd.flotte_extra as Array).size(), "%d places au garage" % (gd.baies as Array).size())
	var nb := 0
	var modeles_ok := true
	var poses_ok := true
	for pid in GestionTypes.ordre(g):
		var r: Array = GestionTypes.piece(g, String(pid)).rect
		for oid in GestionTypes.objets(g, String(pid)):
			var o := GestionTypes.objet(g, String(pid), String(oid))
			nb += 1
			if not (o.has("nom") and o.has("prix") and o.has("effets")):
				push_error("objet incomplet %s/%s" % [pid, oid])
				modeles_ok = false
			var m := String(o.get("modele", ""))
			if m != "":
				var k := LpKit.new(1)
				GestionModeles.dessiner(k, m, Vector3.ZERO, 0.0)
				if k.triangle_count() <= 0:
					modeles_ok = false
					push_error("modèle vide : " + m)
			for ps in o.get("poses", []):
				if float(ps[0]) < -0.01 or float(ps[0]) > float(r[2]) + 0.01 or float(ps[1]) < -0.01 or float(ps[1]) > float(r[3]) + 0.01:
					poses_ok = false
					push_error("%s/%s posé hors de la pièce : %s" % [pid, oid, ps])
	_check(nb >= 60, "%d objets à acheter" % nb)
	_check(modeles_ok, "chaque objet a son modèle 3D")
	_check(poses_ok, "chaque objet est posé dans sa pièce")
	var pcs := GestionTypes.ordre(g)
	var chevauche := ""
	for i in pcs.size():
		for j in range(i + 1, pcs.size()):
			var a: Array = GestionTypes.piece(g, String(pcs[i])).rect
			var b: Array = GestionTypes.piece(g, String(pcs[j])).rect
			if float(a[0]) < float(b[0]) + float(b[2]) - 0.01 and float(b[0]) < float(a[0]) + float(a[2]) - 0.01 and float(a[1]) < float(b[1]) + float(b[3]) - 0.01 and float(b[1]) < float(a[1]) + float(a[3]) - 0.01:
				chevauche = "%s / %s" % [pcs[i], pcs[j]]
	_check(chevauche == "", "les pièces ne se chevauchent pas %s" % chevauche)


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
	var gest: Gestion = scene.gestion
	var vue: GestionVue = scene.gestion_vue
	var pop: Population = scene.population
	var urg: Urgences = scene.urgences
	_check(gest.urgences == urg, "la gestion connaît les urgences")
	for nd in [transport.traffic, scene.tourisme, pop, scene.parc, scene.zoo, scene.musee, scene.spectacles, scene.dechets, scene.production]:
		nd.set_process(false)
	urg.set_process(false)
	urg.random_calls = false
	bs.unlimited_money = false
	bs.money = 50_000_000
	ReglagesPartie.actuel.deblocage = "tout"
	var y := world.cell_height(Vector2i(0, 0))
	_check(transport.build_segment("route", Vector3(-400, y, 0), Vector3(400, y, 0)).ok, "route")
	var sn := bs.road_snap("police", Vector2i(0, -16))
	var cas := bs.place("police", sn.center, int(sn.r), 0, float(sn.get("a", 0.0)))
	_check(cas > 0, "commissariat posé")
	bs.buildings[cas]["chantier"] = false
	pop._sync_buildings()
	urg._sync_stations()
	_check(urg.stations.has(cas) and (urg.stations[cas].units as Array).size() == 3, "le commissariat a ses 3 voitures")

	print("Fiche :")
	var hp: HabitantsPanel = scene.habitants_panel
	hp.set_open(true)
	hp.show_view("batiment", cas)
	await process_frame
	var tg: Button = hp._body.find_child("TuileGestion", true, false)
	_check(tg != null and tg.text.begins_with("Gérer le commissariat"), "tuile « Gérer le commissariat » sur la fiche")
	hp.set_open(false)

	print("Sans gestion, rien ne change :")
	_check(not gest.etats.has(cas) and Gestion.flotte_de(cas).is_empty() and Gestion.equipage_de(cas) == 0, "pas de voiture ni de policier en plus")
	var argent0 := bs.money
	gest.nouveau_jour({"day": gest.jour + 1, "month": 6})
	_check(bs.money == argent0 and not gest.etats.has(cas), "pas de budget versé à un commissariat jamais ouvert")

	print("Budget de la ville :")
	var st := gest.etat(cas)
	_check(gest.valide(cas) and gest.source(cas) == "ville", "commissariat géré comme service public")
	_check(int(st.niv.garage) == 1 and int(st.niv.repos) == 1 and int(st.niv.enquete) == 0 and int(st.niv.chenil) == 0, "garage et vestiaires là, enquêteurs et chenil à construire")
	_check(gest.etoiles(cas) == 1, "1 insigne au départ")
	var dot := gest.dotation(cas)
	_check(dot >= 200.0 and dot <= 3000.0, "budget : %s par jour" % BuildingSystem.format_money(int(dot)))
	gest.set_auto(cas, false)
	argent0 = bs.money
	gest.nouveau_jour({"day": gest.jour + 1, "month": 6})
	_check(bs.money <= argent0 - int(dot) and absf(gest.compte(cas) - dot) < 1.0, "la ville verse le budget (%s sur le compte)" % BuildingSystem.format_money(int(gest.compte(cas))))
	_check(float(gest.hier(cas).ca) == dot and (st.hist as Array).size() == 1, "bilan du jour et historique")
	gest.changer_prix(cas, 1)
	_check(gest.dotation(cas) > dot, "budget monté (%s)" % BuildingSystem.format_money(int(gest.dotation(cas))))
	gest.changer_prix(cas, -1)
	_check(absf(gest.dotation(cas) - dot) < 0.5, "et redescendu")
	for i in 40:
		gest.changer_prix(cas, -1)
	_check(gest.dotation(cas) == 0.0, "budget à zéro possible")
	st.dotation = -1.0

	print("Garage : des voitures en plus dans la vraie police :")
	var px := gest.prix(cas, "garage")
	_check(px > 5_000 and px < 80_000, "garage niveau 2 : %s" % BuildingSystem.format_money(px))
	st.caisse = 5_000.0
	var caisse0 := bs.money
	var r := gest.ameliorer(cas, "garage")
	_check(bool(r.ok) and int(r.batiment) == 5_000 and bs.money == caisse0 - int(r.ville), "le budget paie d'abord (%s), la ville avance %s" % [BuildingSystem.format_money(int(r.batiment)), BuildingSystem.format_money(int(r.ville))])
	_check((urg.stations[cas].units as Array).size() == 4 and String(urg.stations[cas].units[3].base) == "police_nationale", "une voiture de patrouille en plus")
	gest.ameliorer(cas, "garage")
	_check((urg.stations[cas].units as Array).size() == 5, "puis une deuxième (%d voitures)" % (urg.stations[cas].units as Array).size())
	_check(gest.capacite(cas) == 5 and gest.clients(cas) == 5, "5 / 5 voitures au garage")

	print("Vestiaires : plus de policiers en service :")
	urg.stations[cas].staff_t = -INF
	var g0 := urg.staff_of(cas)
	gest.ameliorer(cas, "repos")
	urg.stations[cas].staff_t = -INF
	_check(urg.staff_of(cas) == g0 + 1 and gest.equipage(cas) == 1, "un policier en service de plus (%d → %d)" % [g0, urg.staff_of(cas)])
	st.volontaires = 2
	urg.stations[cas].staff_t = -INF
	_check(urg.staff_of(cas) == g0 + 3, "et les réservistes comptent")
	st.volontaires = 0

	print("Une intervention :")
	urg.ignore_crew = true
	gest.ameliorer(cas, "tir")
	gest.acheter(cas, "garage", "motos")
	var vit := Gestion.effet_de(cas, "vitesse")
	_check(vit > 0.05, "équipe plus rapide sur place (+%d %%)" % roundi(vit * 100.0))
	var id := urg.random_call("accident")
	_check(id != -1 and urg.incidents.has(id), "appel : accident de la route")
	var parti: Dictionary = {}
	for u in urg.stations[cas].units:
		if bool(u.out):
			parti = u
	_check(not parti.is_empty() and gest.clients(cas) == 4, "une voiture part (4 / 5 au garage)")
	_check(String((st.journal as Array)[0][1]).begins_with("Départ"), "départ au journal : %s" % String((st.journal as Array)[0][1]))
	if not parti.is_empty():
		urg._t += 200.0
		urg._on_arrival(parti, parti.v)
		_check(String(parti.phase) == "sur_place" and float(parti.wait) < float(Urgences.WORK.police) - 0.5, "sur place, travail plus court (%.0f s au lieu de %.0f)" % [float(parti.wait), float(Urgences.WORK.police)])
	_check(float(st.delai) > 100.0 and int(st.interventions) == 1, "délai d'arrivée noté (%s)" % Urgences.format_time(float(st.delai)))
	var n0 := gest.note(cas)
	for i in 6:
		gest.nouveau_jour({"day": gest.jour + 1, "month": 6})
	_check(gest.note(cas) != n0 and gest.note(cas) > 3.0, "la note suit le délai (%.1f)" % gest.note(cas))
	_check(gest.satisf(cas) > 0.5, "moral %.1f" % gest.satisf(cas))
	urg.ignore_crew = false

	print("Enquêtes : les cambriolages élucidés malgré le retard :")
	_check(gest.chance_enquete(cas) < 0.1, "peu de chances sans enquêteurs (%d %%)" % roundi(gest.chance_enquete(cas) * 100.0))
	for i in 3:
		gest.ameliorer(cas, "enquete")
	gest.ameliorer(cas, "cellules")
	gest.acheter(cas, "enquete", "tableau_liege")
	gest.acheter(cas, "enquete", "empreintes")
	var ch := gest.chance_enquete(cas)
	_check(ch > 0.35, "enquêteurs, cellules, empreintes : %d %% de chances" % roundi(ch * 100.0))
	var el0 := int(st.elucides)
	for i in 40:
		var inc := {"type": "cambriolage", "meta": {"police_bid": cas, "hid": -1}, "arrived": {"police": 5000.0}}
		urg._effects_on_done(inc, "police")
	_check(int(st.elucides) - el0 >= 6 and int(st.non_elucides) >= 3, "sur 40 cambriolages en retard : %d élucidés, %d non" % [int(st.elucides) - el0, int(st.non_elucides)])
	_check(int(urg.stats.get("elucides", 0)) >= 6, "comptés dans les statistiques des urgences")

	print("Demandes, pannes, événements :")
	var possibles := gest.demandes_possibles(cas)
	_check(possibles.size() >= 8, "%d demandes possibles" % possibles.size())
	var c0 := gest.compte(cas)
	var don := gest.regler(cas, possibles[0])
	_check(don > 0.0 and gest.compte(cas) > c0, "merci de %.0f € pour le commissariat" % don)
	_check(not gest.nouvelle_panne(cas).is_empty(), "une panne")
	gest.ameliorer(cas, "fourriere")
	gest.ameliorer(cas, "parvis")
	gest.ameliorer(cas, "chenil")
	for j in 300:
		gest._evenements(cas, gest.etat(cas), 7 if j < 150 else 5)
		gest.jour += 1
	var txt := ""
	for e in gest.etat(cas).journal:
		txt += String(e[1]) + "\n"
	_check(txt.contains("Préfecture"), "la préfecture passe")
	_check(txt.contains("Fourrière") and int(gest.etat(cas).fourriere) > 0, "la fourrière enlève des voitures (%d)" % int(gest.etat(cas).fourriere))
	_check(txt.contains("Rex") or txt.contains("Permis vélo") or txt.contains("réserve"), "chien, permis vélo ou réservistes au journal")
	var objs := gest.objectifs(cas)
	var otxt := ""
	for o in objs:
		otxt += String(o.texte) + " ; "
	_check(otxt.contains("4 min") and otxt.contains("insignes") and otxt.contains("cambriolages"), "objectifs du commissariat")

	print("Gestion automatique :")
	gest.set_auto(cas, true)
	st.caisse = 300_000.0
	var inv0 := float(st.invest)
	var argent1 := bs.money
	gest.nouveau_jour({"day": gest.jour + 1, "month": 6})
	_check(float(st.invest) > inv0, "le commissariat investit son budget tout seul (%s)" % BuildingSystem.format_money(int(float(st.invest) - inv0)))
	_check(bs.money >= argent1 - int(gest.dotation(cas)) - 1, "la ville ne paie que le budget du jour")

	print("Sauvegarde :")
	var niv: Dictionary = st.niv.duplicate()
	st.dotation = 900.0
	st.volontaires = 3
	var d := gest.to_dict()
	gest.clear()
	urg.maj_flotte(cas)
	_check((urg.stations[cas].units as Array).size() == 3, "effacé : le commissariat revient à ses 3 voitures")
	gest.from_dict(JSON.parse_string(JSON.stringify(d)))
	urg.maj_flotte(cas)
	_check(gest.etat(cas).niv == niv and gest.dotation(cas) == 900.0 and int(gest.etat(cas).volontaires) == 3, "rechargé : niveaux, budget, réservistes")
	_check((urg.stations[cas].units as Array).size() >= 5, "les voitures gagnées reviennent")
	gest.etat(cas).dotation = -1.0

	print("Écran isométrique :")
	for u in urg.stations[cas].units:
		if bool(u.out):
			urg._home(u)
	_check(scene.ouvrir_gestion(cas) and vue.est_ouvert() and vue.genre == "commissariat", "l'écran du commissariat s'ouvre")
	await process_frame
	var dio := vue.diorama
	_check(dio.engins.size() == (urg.stations[cas].units as Array).size(), "%d voitures au garage" % dio.engins.size())
	_check(dio.places.has("plaintes") and (dio.places.plaintes as Array).size() >= 2, "places au bureau des plaintes")
	for i in 300:
		vue.simuler(0.1)
	_check(not dio.clients.is_empty(), "%d visiteurs" % dio.clients.size())
	urg.ignore_crew = true
	urg.random_call("accident")
	vue._maj_engins(true)
	var part := 0
	for e in dio.engins:
		if String(e.etat) == "part":
			part += 1
	_check(part == 1, "une voiture sort du garage, gyrophares allumés")
	for i in 120:
		vue.simuler(0.1)
	var absent := 0
	for e in dio.engins:
		if String(e.etat) == "absent":
			absent += 1
	_check(absent == 1, "puis il s'en va par la rue")
	for u in urg.stations[cas].units:
		if bool(u.out):
			urg._home(u)
	vue._maj_engins(true)
	var gare := 0
	for e in dio.engins:
		if String(e.etat) == "gare":
			gare += 1
	_check(gare == dio.engins.size(), "rentré : de nouveau à sa place")
	vue.choisir("")
	var plus: Button = vue._carte_corps.find_child("Prix_plus", true, false)
	_check(plus != null, "bouton du budget")
	if plus != null:
		plus.pressed.emit()
	_check(gest.dotation(cas) > gest.dotation_defaut(cas), "budget monté depuis l'écran")
	vue.choisir("garage")
	var ligne: Node = vue._carte_corps.find_child("Objet_tableau_cles", true, false)
	var acheter: Button = ligne.find_child("Acheter", true, false) if ligne != null else null
	_check(acheter != null and not acheter.disabled, "on peut acheter le tableau des clés")
	if acheter != null:
		acheter.pressed.emit()
	await process_frame
	_check(gest.a_objet(cas, "garage", "tableau_cles"), "tableau des clés installé depuis l'écran")
	for o in ["personnel", "stats", "journal"]:
		vue.onglet = o
		vue._remplir_carte()
	_check(vue._bas.get_child_count() == GestionTypes.ordre("commissariat").size() + 1, "une tuile par pièce en bas")
	vue.fermer()
	_check(not vue.est_ouvert(), "retour à la ville")
	scene.queue_free()
	await process_frame
