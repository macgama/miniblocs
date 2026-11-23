extends SceneTree
## Test du mode gestion de l'usine : toutes les usines de l'économie se gèrent,
## pièces, objets et modèles complets, tuile « Gérer l'usine », compte = caisse
## de l'entreprise, vraie production plus rapide (cadence), moins de matière
## perdue, prix de vente (qualité), pollution en moins (Nuisances, Climat),
## énergie économisée, cadence demandée, accidents, grève, événements, gestion
## automatique, sauvegarde et écran isométrique.
## Usage : godot --headless --path . --script res://tests/gestion_usine_test.gd

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
	print("Genre usine :")
	var n := 0
	for id in BuildingCatalog.all_types():
		if GestionTypes.genre_de(String(id)) == "usine":
			n += 1
	_check(n >= 20, "%d usines et ateliers se gèrent" % n)
	_check(GestionTypes.genre_de("scierie") == "usine" and GestionTypes.genre_de("usine_biens") == "usine" and GestionTypes.genre_de("acierie") == "usine", "scierie, usine de biens, aciérie")
	_check(GestionTypes.genre_de("cafe") == "restaurant" and GestionTypes.genre_de("ferme_cereales") == "ferme" and GestionTypes.genre_de("maison") == "", "le café reste un restaurant, la ferme a son tycoon en kit, la maison rien")
	var g := "usine"
	var gd := GestionTypes.genre(g)
	_check(String(gd.titre) == "Gérer l'usine" and Icones.has_icon(String(gd.icone)), "titre et icône")
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
	for e in ["cadence", "matiere", "qualite", "depollution", "economie"]:
		_check(GestionTypes.EFFETS.has(e), "effet %s décrit" % e)
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


func _produit(prod: Production, bid: int, h: float) -> Array:
	# Remet les stocks à un état connu, puis fait tourner l'usine h heures : [produit, consommé].
	prod.sites[bid].st = {"bois": 200.0}
	prod.sites[bid].inc = {}
	prod._step_hours(h)
	return [prod.stock_of(bid, "planches"), 200.0 - prod.stock_of(bid, "bois")]


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
	var prod: Production = scene.production
	for nd in [transport.traffic, scene.tourisme, pop, scene.parc, scene.zoo, scene.musee, scene.spectacles, scene.dechets, prod]:
		nd.set_process(false)
	scene.urgences.set_process(false)
	scene.urgences.random_calls = false
	bs.unlimited_money = false
	bs.money = 50_000_000
	ReglagesPartie.actuel.deblocage = "tout"
	var y := world.cell_height(Vector2i(0, 0))
	_check(transport.build_segment("route", Vector3(-500, y, 0), Vector3(500, y, 0)).ok, "route")
	var poser := func(id: String, c: Vector2i) -> int:
		var sn := bs.road_snap(id, c)
		if sn.is_empty():
			print("    pas de place le long de la route pour ", id)
			return -1
		return bs.place(id, sn.center, int(sn.r), 0, float(sn.get("a", 0.0)))
	var usine: int = poser.call("scierie", Vector2i(0, -30))
	var autre: int = poser.call("usine_biens", Vector2i(200, -40))
	var homes: Array = []
	for i in 8:
		homes.append(poser.call("immeuble", Vector2i(-420 + i * 45, 30)))
	_check(usine > 0 and autre > 0 and not homes.has(-1), "scierie, usine de biens et 8 immeubles posés")
	for b in [usine, autre] + homes:
		if b > 0:
			bs.buildings[b]["chantier"] = false
	prod._sync()
	pop._sync_buildings()
	_check(prod.sites.has(usine) and String(prod.sites[usine].kind) == "transformation", "la scierie est une usine de l'économie")
	for i in 96:
		pop.advance(300.0)
		if (pop.by_job.get(usine, []) as Array).size() >= 3:
			break
	_check((pop.by_job.get(usine, []) as Array).size() > 0, "des ouvriers embauchés (%d)" % (pop.by_job.get(usine, []) as Array).size())

	print("Fiche :")
	var hp: HabitantsPanel = scene.habitants_panel
	hp.set_open(true)
	hp.show_view("batiment", usine)
	await process_frame
	var tg: Button = hp._body.find_child("TuileGestion", true, false)
	_check(tg != null and tg.text.begins_with("Gérer l'usine"), "tuile « Gérer l'usine » sur la fiche")
	hp.set_open(false)

	print("Sans gestion, rien ne change :")
	_check(not gest.etats.has(usine) and Gestion.cadence_de(usine) == 1.0 and Gestion.matiere_de(usine) == 1.0 and Gestion.prix_vente_de(usine) == 1.0 and Gestion.depollution_de(usine) == 0.0, "cadence, matière, prix et pollution habituels")
	_check(Gestion.entretien_site(usine) == 0.0, "pas d'entretien en plus")
	gest.nouveau_jour({"day": gest.jour + 1, "month": 6})
	_check(not gest.etats.has(usine) and not gest.etats.has(autre), "un jour passe : les usines jamais ouvertes restent comme avant")
	var avant := _produit(prod, usine, 6.0)
	_check(float(avant[0]) > 0.0, "la scierie produit %.2f t de planches en 6 h" % float(avant[0]))

	print("Niveaux, compte de l'entreprise :")
	var st := gest.etat(usine)
	_check(gest.valide(usine) and gest.source(usine) == "production", "usine gérée par l'économie")
	_check(int(st.niv.atelier) == 1 and int(st.niv.quai) == 1 and int(st.niv.chaine) == 0, "atelier et quai là, chaîne à construire")
	_check(absf(Gestion.cadence_de(usine) - 1.0) < 0.06, "état neuf : cadence proche de l'habituel (%.2f)" % Gestion.cadence_de(usine))
	var px := gest.prix(usine, "chaine")
	_check(px > 5_000 and px < 200_000, "chaîne : %s" % BuildingSystem.format_money(px))
	prod.sites[usine].cash = 20_000.0
	var caisse0 := bs.money
	var r := gest.ameliorer(usine, "chaine")
	_check(bool(r.ok) and gest.niveau(usine, "chaine") == 1, "chaîne construite")
	_check(int(r.batiment) == mini(20_000, px) and bs.money == caisse0 - int(r.ville), "la caisse de l'usine paie d'abord (%s), la ville avance %s" % [BuildingSystem.format_money(int(r.batiment)), BuildingSystem.format_money(int(r.ville))])
	for pid in ["atelier", "atelier", "atelier", "chaine", "chaine", "stock", "quai"]:
		gest.ameliorer(usine, pid)
	gest.acheter(usine, "chaine", "convoyeur")
	gest.acheter(usine, "atelier", "pont_roulant")
	_check(Gestion.cadence_de(usine) > 1.4, "cadence des machines : ×%.2f" % Gestion.cadence_de(usine))
	_check(Gestion.matiere_de(usine) > 1.05, "moins de matière perdue : ×%.2f" % Gestion.matiere_de(usine))
	_check(Gestion.entretien_site(usine) > 0.0, "entretien : %s / jour" % BuildingSystem.format_money(int(Gestion.entretien_site(usine))))

	print("Vraie production :")
	var apres := _produit(prod, usine, 6.0)
	_check(float(apres[0]) > float(avant[0]) * 1.4, "plus de planches en 6 h : %.2f t au lieu de %.2f" % [float(apres[0]), float(avant[0])])
	_check(float(apres[0]) / maxf(0.001, float(apres[1])) > float(avant[0]) / maxf(0.001, float(avant[1])) * 1.04, "plus de planches par tonne de bois")
	_check(prod.cap_of(usine, "bois") > 0.0 and prod.needs_of(usine).get("bois", 0.0) > float(ProductionTypes.prod_of("scierie").in.bois) * 1.3, "l'usine commande plus de bois (%.0f t/jour)" % float(prod.needs_of(usine).get("bois", 0.0)))
	var hj: Dictionary = gest.etat(usine).j
	_check(float(hj.get("clients", 0.0)) > 0.0 and float(hj.get("cap", 0.0)) >= float(hj.get("clients", 0.0)), "production du jour comptée (%.2f / %.2f t)" % [float(hj.get("clients", 0.0)), float(hj.get("cap", 0.0))])

	print("Cadence demandée :")
	var c1 := gest.cadence(usine)
	gest.changer_prix(usine, 1)
	gest.changer_prix(usine, 1)
	_check(gest.cadence(usine) > c1 and gest.prix_txt(usine).contains("110 %"), "heures sup : %s" % gest.prix_txt(usine))
	for i in 20:
		gest.changer_prix(usine, 1)
	_check(absf(float(gest.etat(usine).prix) - Gestion.RYTHME_MAX) < 0.001, "cadence plafonnée à %d %%" % roundi(Gestion.RYTHME_MAX * 100.0))
	var s_haut := gest.satisf(usine)
	for i in 10:
		gest.compter(usine, 0.0, 0.0, 0.0)
		gest.cloture(usine, 100.0)
	_check(gest.satisf(usine) < s_haut, "à 130 %%, le moral baisse (%.1f → %.1f)" % [s_haut, gest.satisf(usine)])
	gest.etat(usine).prix = 1.0

	print("Qualité et prix de vente :")
	var pv0 := Gestion.prix_vente_de(usine)
	gest.ameliorer(usine, "labo")
	gest.ameliorer(usine, "labo")
	gest.acheter(usine, "labo", "microscope")
	_check(Gestion.prix_vente_de(usine) > pv0 + 0.05, "produits vendus plus cher : ×%.2f" % Gestion.prix_vente_de(usine))
	var cash_v := float(prod.sites[usine].cash)
	var j0 := float(gest.etat(usine).j.get("ca", 0.0))
	prod.pay(usine, "Ventes aux entreprises", 500.0)
	_check(float(prod.sites[usine].cash) > cash_v and float(gest.etat(usine).j.get("ca", 0.0)) >= j0 + 499.0, "les ventes comptent dans le bilan du jour")

	print("Pollution et énergie :")
	var clim: Climat = Climat.instance
	var t0 := {}
	if clim != null:
		clim._batiments(0.0, t0)
	gest.ameliorer(usine, "epuration")
	gest.acheter(usine, "epuration", "filtres")
	gest.acheter(usine, "epuration", "bassin")
	_check(Gestion.depollution_de(usine) >= 0.3, "pollution en moins : −%d %%" % roundi(Gestion.depollution_de(usine) * 100.0))
	if clim != null:
		var t1 := {}
		clim._batiments(0.0, t1)
		_check(float(t1.get("industrie", 0.0)) < float(t0.get("industrie", 0.0)) or float(t0.get("industrie", 0.0)) == 0.0, "moins de CO₂ industriel (%.3f → %.3f)" % [float(t0.get("industrie", 0.0)), float(t1.get("industrie", 0.0))])
	var e0 := gest.entretien_jour(usine)
	gest.ameliorer(usine, "energie")
	gest.acheter(usine, "energie", "solaire")
	_check(gest.entretien_jour(usine) < e0 + float(GestionTypes.piece("usine", "energie").effets.entretien), "les panneaux solaires font baisser les factures")

	print("Une journée dans l'économie :")
	var cash0 := float(prod.sites[usine].cash)
	prod.clock = 1_784_282_400.0 + 86400.0
	prod.new_day()
	_check(float(prod.sites[usine].cash) < cash0 + float(gest.hier(usine).get("ca", 0.0)) + 1.0, "l'entretien est payé par la caisse de l'usine")
	var h: Dictionary = gest.hier(usine)
	_check(h.has("cap") and (gest.etat(usine).hist as Array).size() >= 1, "Production clôt la journée de l'usine")
	_check(gest.occupation(usine) >= 0.0 and gest.occupation(usine) <= 1.0, "taux de marche %d %%" % roundi(gest.occupation(usine) * 100.0))
	_check(gest.note(usine) > 0.5 and gest.satisf(usine) > 0.5, "note %.1f, moral %.1f" % [gest.note(usine), gest.satisf(usine)])

	print("Accidents, grève, événements :")
	gest.etat(usine).prix = 1.3
	for j in 300:
		gest._evenements(usine, gest.etat(usine), 3 + j % 3)
		gest.jour += 1
	var journal: Array = gest.etat(usine).journal
	var vu := {}
	for e in journal:
		for mot in ["Accident", "Audit", "commande", "Salon", "visite"]:
			if String(e[1]).contains(mot):
				vu[mot] = true
	_check(vu.has("Accident") and vu.has("Audit") and vu.has("commande"), "accidents, audits et commandes au journal (%s)" % ", ".join(vu.keys()))
	_check(int(gest.etat(usine).accidents) > 0, "%d accidents du travail à 130 %%" % int(gest.etat(usine).accidents))
	gest.etat(usine).prix = 1.0
	gest.etat(usine).satisf = 1.0
	gest.etat(usine).salaire = 0.9
	var greve := false
	for j in 60:
		gest._evenements(usine, gest.etat(usine), 6)
		if int(gest.etat(usine).greve_fin) >= gest.jour:
			greve = true
			break
		gest.jour += 1
	_check(greve and Gestion.cadence_de(usine) == 0.0, "moral au plus bas et salaires bas : grève, machines arrêtées")
	prod.sites[usine].st = {"bois": 50.0}
	prod._step_hours(2.0)
	_check(String(prod.sites[usine].status).begins_with("En grève") and prod.stock_of(usine, "bois") == 50.0, "pendant la grève, rien n'est transformé")
	gest.etat(usine).greve_fin = -1
	gest.etat(usine).satisf = 3.0
	gest.etat(usine).salaire = 1.0
	var possibles := gest.demandes_possibles(usine)
	_check(possibles.size() >= 6, "%d demandes possibles" % possibles.size())
	var c0 := gest.compte(usine)
	var tip := gest.regler(usine, possibles[0])
	_check(tip > 0.0 and gest.compte(usine) > c0, "demande réglée : %.0f €" % tip)

	print("Gestion automatique :")
	gest.set_auto(autre, true)
	gest.etat(autre)
	prod.sites[autre].cash = 3_000_000.0
	var inv0 := float(gest.etat(autre).invest)
	var caisse_auto := bs.money
	gest.nouveau_jour({"day": gest.jour + 1, "month": 7})
	_check(float(gest.etat(autre).invest) > inv0, "l'usine de biens investit ses bénéfices toute seule (%s)" % BuildingSystem.format_money(int(float(gest.etat(autre).invest) - inv0)))
	_check(bs.money == caisse_auto, "sans toucher à la caisse de la ville")
	var txt := ""
	for o in gest.objectifs(usine):
		txt += String(o.texte) + " ; "
	_check(txt.contains("accident") and txt.contains("pollution") and txt.contains("certifications"), "objectifs de l'usine")

	print("Sauvegarde :")
	var niv: Dictionary = gest.etat(usine).niv.duplicate()
	gest.etat(usine).prix = 1.15
	var d := gest.to_dict()
	gest.clear()
	_check(Gestion.cadence_de(usine) == 1.0 and Gestion.depollution_de(usine) == 0.0, "effacé : l'usine redevient comme avant")
	gest.from_dict(JSON.parse_string(JSON.stringify(d)))
	_check(gest.etat(usine).niv == niv and absf(float(gest.etat(usine).prix) - 1.15) < 0.001 and int(gest.etat(usine).accidents) > 0, "rechargé : niveaux, cadence et accidents")

	print("Écran isométrique :")
	gest.etat(usine).prix = 1.0
	gest.ameliorer(usine, "showroom")
	gest.ameliorer(usine, "refectoire")
	_check(scene.ouvrir_gestion(usine) and vue.est_ouvert() and vue.genre == "usine", "l'écran de l'usine s'ouvre")
	await process_frame
	var dio := vue.diorama
	_check(dio.places.has("showroom") and not (dio.places.showroom as Array).is_empty(), "boutique d'usine aménagée")
	_check(dio.places.has("quai") and not (dio.places.quai as Array).is_empty(), "quai de chargement")
	_check(dio.employes.size() + dio.vacants.size() > 0, "personnel ou postes vacants affichés")
	for i in 400:
		vue.simuler(0.1)
	var installes := 0
	for c in dio.clients:
		if String(c.etat) == "installe":
			installes += 1
	_check(installes > 0, "%d visiteurs dans l'usine" % installes)
	vue._remplir_haut()
	var haut := ""
	for c in vue._chiffres.get_children():
		haut += String((c as Button).text) + " | "
	_check(haut.contains("t par jour"), "production affichée en haut : %s" % haut)
	vue.choisir("")
	var plus: Button = vue._carte_corps.find_child("Prix_plus", true, false)
	_check(plus != null, "bouton de la cadence")
	if plus != null:
		plus.pressed.emit()
	_check(float(gest.etat(usine).prix) > 1.0, "cadence montée depuis l'écran")
	vue.choisir("atelier")
	var ligne: Node = vue._carte_corps.find_child("Objet_presse", true, false)
	var acheter: Button = ligne.find_child("Acheter", true, false) if ligne != null else null
	_check(acheter != null and not acheter.disabled, "on peut acheter la presse")
	if acheter != null:
		acheter.pressed.emit()
	await process_frame
	_check(gest.a_objet(usine, "atelier", "presse"), "presse installée depuis l'écran")
	_check(vue._bas.get_child_count() == GestionTypes.ordre("usine").size() + 1, "une tuile par pièce en bas")
	vue.fermer()
	_check(not vue.est_ouvert(), "retour à la ville")
	scene.queue_free()
	await process_frame
