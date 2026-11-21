extends SceneTree
## Test du mode gestion du restaurant : les 55 cafés et restaurants se gèrent,
## pièces, objets et modèles complets, tuile « Gérer le restaurant », compte =
## caisse de l'entreprise, couverts, affluence, prix du menu et prix des repas
## dans l'économie (Production), entretien et bilan du jour, événements,
## gestion automatique, sauvegarde, et écran isométrique (maquette, clients,
## employés, prix du menu depuis l'écran).
## Usage : godot --headless --path . --script res://tests/gestion_restaurant_test.gd

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
	print("Genre restaurant :")
	var n := 0
	for id in BuildingCatalog.all_types():
		if GestionTypes.genre_de(String(id)) == "restaurant":
			n += 1
	_check(n >= 40, "%d cafés et restaurants se gèrent" % n)
	_check(GestionTypes.genre_de("cafe") == "restaurant" and GestionTypes.genre_de("haussmann__restaurant") == "restaurant", "café-restaurant et brasserie")
	_check(GestionTypes.genre_de("hotel_3") == "hotel" and GestionTypes.genre_de("maison") == "", "l'hôtel reste un hôtel, la maison rien")
	var g := "restaurant"
	var gd := GestionTypes.genre(g)
	_check(String(gd.titre) == "Gérer le restaurant" and Icones.has_icon(String(gd.icone)), "titre et icône")
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
	# Pièces sans chevauchement.
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
	var tour: Tourisme = scene.tourisme
	var gest: Gestion = scene.gestion
	var vue: GestionVue = scene.gestion_vue
	var pop: Population = scene.population
	var prod: Production = scene.production
	_check(gest.production == prod, "la gestion connaît l'économie")
	for nd in [transport.traffic, tour, pop, scene.parc, scene.zoo, scene.musee, scene.spectacles, scene.dechets, prod]:
		nd.set_process(false)
	scene.urgences.set_process(false)
	scene.urgences.random_calls = false
	bs.unlimited_money = false
	bs.money = 50_000_000
	ReglagesPartie.actuel.deblocage = "tout"
	var y := world.cell_height(Vector2i(0, 0))
	_check(transport.build_segment("route", Vector3(-400, y, 0), Vector3(400, y, 0)).ok, "route")
	var poser := func(id: String, c: Vector2i) -> int:
		var sn := bs.road_snap(id, c)
		if sn.is_empty():
			print("    pas de place le long de la route pour ", id)
			return -1
		return bs.place(id, sn.center, int(sn.r), 0, float(sn.get("a", 0.0)))
	var resto: int = poser.call("haussmann__restaurant", Vector2i(0, -14))
	var cafe: int = poser.call("cafe", Vector2i(60, -12))
	var maison: int = poser.call("maison", Vector2i(-80, -12))
	_check(resto > 0 and cafe > 0 and maison > 0, "brasserie, café et maison posés")
	for b in [resto, cafe, maison]:
		if b > 0:
			bs.buildings[b]["chantier"] = false
	prod._sync()
	pop._sync_buildings()
	_check(prod.sites.has(resto) and prod.sites.has(cafe), "les restaurants sont des entreprises de l'économie")

	print("Fiche :")
	var hp: HabitantsPanel = scene.habitants_panel
	hp.set_open(true)
	hp.show_view("batiment", resto)
	await process_frame
	var tg: Button = hp._body.find_child("TuileGestion", true, false)
	_check(tg != null and tg.text.begins_with("Gérer le restaurant"), "tuile « Gérer le restaurant » sur la fiche")
	hp.set_open(false)

	print("Sans gestion, rien ne change :")
	_check(not gest.etats.has(resto) and is_equal_approx(Gestion.affluence_de(resto), 1.0) and is_equal_approx(Gestion.prix_repas_de(resto), 1.0) and is_equal_approx(Gestion.couverts_de(resto), 1.0), "affluence, prix et couverts habituels")
	_check(Gestion.entretien_site(resto) == 0.0, "pas d'entretien en plus")

	print("Niveaux, compte de l'entreprise :")
	var st := gest.etat(resto)
	_check(gest.valide(resto) and gest.source(resto) == "production", "restaurant géré par l'économie")
	_check(int(st.niv.salle) == 1 and int(st.niv.cuisine) == 1 and int(st.niv.terrasse) == 0, "salle et cuisine là, terrasse à construire")
	_check(gest.etoiles(resto) >= 1 and gest.etoiles(resto) <= 2, "%d toque(s) au départ" % gest.etoiles(resto))
	_check(absf(Gestion.affluence_de(resto) - 1.0) < 0.06, "état neuf : affluence proche de l'habituel (%.2f)" % Gestion.affluence_de(resto))
	var px := gest.prix(resto, "terrasse")
	_check(px > 5_000 and px < 80_000, "terrasse : %s" % BuildingSystem.format_money(px))
	prod.sites[resto].cash = 20_000.0
	var caisse0 := bs.money
	var r := gest.ameliorer(resto, "terrasse")
	_check(bool(r.ok) and gest.niveau(resto, "terrasse") == 1, "terrasse construite")
	_check(int(r.batiment) == mini(20_000, px) and bs.money == caisse0 - int(r.ville), "la caisse du restaurant paie d'abord (%s), la ville avance %s" % [BuildingSystem.format_money(int(r.batiment)), BuildingSystem.format_money(int(r.ville))])
	_check(float(prod.sites[resto].cash) < 20_000.0 - float(r.batiment) + 1.0, "caisse de l'entreprise débitée")
	_check(Gestion.couverts_de(resto) > 1.1, "plus de couverts (%.2f)" % Gestion.couverts_de(resto))
	for pid in ["salle", "salle", "salle", "cuisine", "cuisine", "bar", "cave", "accueil", "salle_privee", "potager", "toilettes"]:
		gest.ameliorer(resto, pid)
	_check(gest.etoiles(resto) > int(gest.spec_base(resto).etoiles), "le confort fait gagner des toques (%d)" % gest.etoiles(resto))
	_check(Gestion.prix_repas_de(resto) > 1.05, "repas plus chers avec les toques et la cave (×%.2f)" % Gestion.prix_repas_de(resto))
	_check(Gestion.entretien_site(resto) > 0.0, "entretien : %s / jour" % BuildingSystem.format_money(int(Gestion.entretien_site(resto))))

	print("Prix du menu :")
	var aff0 := gest.affluence(resto)
	var pr0 := gest.prix_repas(resto)
	gest.changer_prix(resto, 1)
	gest.changer_prix(resto, 1)
	_check(gest.prix_repas(resto) > pr0 and gest.affluence(resto) < aff0, "plus cher : chaque repas rapporte plus, moins de clients")
	gest.changer_prix(resto, -1)
	gest.changer_prix(resto, -1)
	_check(absf(float(gest.etat(resto).prix) - 1.0) < 0.02, "retour au prix habituel")
	for i in 40:
		gest.changer_prix(resto, -1)
	_check(absf(float(gest.etat(resto).prix) - Gestion.PRIX_MIN) < 0.001, "prix plancher")
	gest.etat(resto).prix = 1.0

	print("Une journée dans l'économie :")
	gest.compter(resto, 1500.0, 90.0, 140.0)
	var cash0 := float(prod.sites[resto].cash)
	var ent := Gestion.entretien_site(resto)
	Gestion.cloture_de(resto, 400.0 + ent)
	var h: Dictionary = gest.hier(resto)
	_check(int(h.clients) == 90 and int(h.cap) == 140 and float(h.ca) == 1500.0, "bilan du jour : 90 / 140 couverts, %s" % BuildingSystem.format_money(int(h.ca)))
	_check(gest.clients(resto) == 90 and gest.capacite(resto) == 140 and absf(gest.occupation(resto) - 90.0 / 140.0) < 0.01, "clients, couverts et remplissage lus par l'écran")
	_check((gest.etat(resto).hist as Array).size() == 1, "historique du jour")
	_check(gest.note(resto) > 0.5 and gest.satisf(resto) > 0.5, "note %.1f, satisfaction %.1f" % [gest.note(resto), gest.satisf(resto)])
	# Une vraie journée de l'économie : l'entretien est payé par l'entreprise.
	var t := VENDREDI + 86400.0
	prod.clock = t
	prod.new_day()
	_check(float(prod.sites[resto].cash) < cash0, "l'entretien est payé par la caisse du restaurant")
	_check((gest.etat(resto).hist as Array).size() == 2, "Production clôt la journée du restaurant")
	_check(not gest.etats.has(cafe) or (gest.etat(cafe).hist as Array).size() <= 1, "le café suit sa propre journée")

	print("Demandes, pannes, événements :")
	var possibles := gest.demandes_possibles(resto)
	_check(possibles.size() >= 8, "%d demandes possibles" % possibles.size())
	var s0 := gest.satisf(resto)
	var c0 := gest.compte(resto)
	var tip := gest.regler(resto, possibles[0])
	_check(tip > 0.0 and gest.compte(resto) > c0 and gest.satisf(resto) > s0, "pourboire de %.0f € et client content" % tip)
	var pn := gest.nouvelle_panne(resto)
	_check(not pn.is_empty(), "une panne : %s" % String(pn.get("texte", "")))
	for j in 200:
		gest._evenements(resto, gest.etat(resto), 6)
		gest.jour += 1
	var journal: Array = gest.etat(resto).journal
	var critique := false
	for e in journal:
		critique = critique or String(e[1]).contains("critique gastronomique") or String(e[1]).contains("Inspection")
	_check(critique, "le critique et l'inspecteur passent (%d lignes au journal)" % journal.size())

	print("Gestion automatique :")
	gest.set_auto(cafe, true)
	gest.etat(cafe)
	prod.sites[cafe].cash = 300_000.0
	var inv0 := float(gest.etat(cafe).invest)
	var caisse_auto := bs.money
	gest.nouveau_jour({"day": gest.jour + 1, "month": 7})
	_check(float(gest.etat(cafe).invest) > inv0, "le café investit ses bénéfices tout seul (%s)" % BuildingSystem.format_money(int(float(gest.etat(cafe).invest) - inv0)))
	_check(bs.money == caisse_auto, "sans toucher à la caisse de la ville")
	var objs := gest.objectifs(resto)
	var txt := ""
	for o in objs:
		txt += String(o.texte) + " ; "
	_check(txt.contains("salle") and txt.contains("toques"), "objectifs du restaurant")

	print("Sauvegarde :")
	var niv: Dictionary = gest.etat(resto).niv.duplicate()
	gest.etat(resto).prix = 1.2
	var d := gest.to_dict()
	gest.clear()
	_check(is_equal_approx(Gestion.affluence_de(resto), 1.0), "effacé : le restaurant redevient comme avant")
	gest.from_dict(JSON.parse_string(JSON.stringify(d)))
	_check(gest.etat(resto).niv == niv and absf(float(gest.etat(resto).prix) - 1.2) < 0.001, "rechargé : niveaux et prix du menu")
	_check(int(gest.hier(resto).get("clients", 0)) > 0 or gest.hier(resto).has("clients"), "le bilan d'hier revient")

	print("Écran isométrique :")
	gest.etat(resto).prix = 1.0
	_check(scene.ouvrir_gestion(resto) and vue.est_ouvert() and vue.genre == "restaurant", "l'écran du restaurant s'ouvre")
	await process_frame
	var dio := vue.diorama
	_check(dio.places.has("salle") and (dio.places.salle as Array).size() >= 8, "%d places dans la salle" % (dio.places.get("salle", []) as Array).size())
	_check(dio.places.has("terrasse") and not (dio.places.terrasse as Array).is_empty(), "terrasse meublée")
	_check(dio.employes.size() + dio.vacants.size() > 0, "personnel ou postes vacants affichés")
	for i in 400:
		vue.simuler(0.1)
	var installes := 0
	for c in dio.clients:
		if String(c.etat) == "installe":
			installes += 1
	_check(installes > 0, "%d clients attablés" % installes)
	vue.choisir("")
	var plus: Button = vue._carte_corps.find_child("Prix_plus", true, false)
	_check(plus != null, "bouton du prix du menu")
	if plus != null:
		plus.pressed.emit()
	_check(float(gest.etat(resto).prix) > 1.0, "prix du menu monté depuis l'écran")
	vue.choisir("cuisine")
	var ligne: Node = vue._carte_corps.find_child("Objet_friteuse", true, false)
	var acheter: Button = ligne.find_child("Acheter", true, false) if ligne != null else null
	_check(acheter != null and not acheter.disabled, "on peut acheter la friteuse")
	if acheter != null:
		acheter.pressed.emit()
	await process_frame
	_check(gest.a_objet(resto, "cuisine", "friteuse"), "friteuse installée depuis l'écran")
	_check(vue._bas.get_child_count() == GestionTypes.ordre("restaurant").size() + 1, "une tuile par pièce en bas")
	vue.fermer()
	_check(not vue.est_ouvert(), "retour à la ville")
	scene.queue_free()
	await process_frame
