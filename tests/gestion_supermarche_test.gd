extends SceneTree
## Test du mode gestion du supermarché : supermarchés et supérettes se gèrent,
## pièces, objets et modèles complets, tuile « Gérer le magasin », compte =
## caisse du commerce, vraies courses des habitants : plus de stock en rayon,
## foyers qui changent de magasin (attrait, prix), panier moyen, clients
## comptés, file aux caisses, vols à l'étalage, promotions, gestion
## automatique, sauvegarde et écran isométrique.
## Usage : xvfb-run -a godot --path . --rendering-driver opengl3 --script res://tests/gestion_supermarche_test.gd

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
	print("Genre supermarché :")
	_check(GestionTypes.genre_de("supermarche") == "supermarche" and GestionTypes.genre_de("superette") == "supermarche", "supermarché et supérette")
	_check(GestionTypes.genre_de("boulangerie") == "" and GestionTypes.genre_de("cafe") == "restaurant" and GestionTypes.genre_de("scierie") == "usine", "la boulangerie reste à part, le café et la scierie aussi")
	var g := "supermarche"
	var gd := GestionTypes.genre(g)
	_check(String(gd.titre) == "Gérer le magasin" and Icones.has_icon(String(gd.icone)), "titre et icône")
	_check(GestionTypes.ordre(g).size() == GestionTypes.pieces(g).size() and GestionTypes.ordre(g).size() >= 12, "%d pièces, toutes dans l'ordre" % GestionTypes.ordre(g).size())
	_check(GestionTypes.pieces(g).has(String(gd.accueil)), "la pièce d'accueil existe")
	for pid in GestionTypes.ordre(g):
		var p := GestionTypes.piece(g, String(pid))
		_check(p.has("rect") and p.has("decor") and p.has("effets") and int(p.max) >= 2, "pièce %s complète" % pid)
		for m in p.get("metiers", []):
			_check(Metiers.METIERS.has(String(m)), "%s : métier %s connu" % [pid, m])
		if p.has("via"):
			_check(GestionTypes.pieces(g).has(String(p.via)), "%s : on y passe par %s" % [pid, p.via])
		var r: Array = p.rect
		for ps in p.get("postes", []):
			if float(ps[0]) < float(r[0]) - 0.01 or float(ps[0]) > float(r[0]) + float(r[2]) + 0.01 or float(ps[1]) < float(r[1]) - 0.01 or float(ps[1]) > float(r[1]) + float(r[3]) + 0.01:
				_check(false, "%s : poste %s hors de la pièce" % [pid, ps])
	for d in gd.demandes:
		_check(GestionTypes.pieces(g).has(String(d.piece)), "demande « %s » dans une pièce connue" % d.texte)
	for a in gd.activites:
		_check(GestionTypes.pieces(g).has(String(a[0])), "activité %s" % a[0])
	for e in ["rayons", "panier", "antivol", "economie"]:
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


## Foyers dont le premier magasin pour le pain est bid.
func _fideles(prod: Production, homes: Array, bid: int) -> int:
	var n := 0
	for h in homes:
		var l := prod._shops_for(int(h), "pain")
		if not l.is_empty() and int(l[0]) == bid:
			n += 1
	return n


func _remplir(prod: Production, bid: int) -> void:
	var st := {}
	for g in Ressources.COMMERCES.supermarche.vend:
		st[g] = 50.0
	prod.sites[bid].st = st
	prod.sites[bid].inc = {}


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
	var smk: int = poser.call("supermarche", Vector2i(150, -40))
	var sup: int = poser.call("superette", Vector2i(-380, -30))
	var homes: Array = []
	for i in 10:
		homes.append(poser.call("immeuble", Vector2i(-440 + i * 50, 30)))
	_check(smk > 0 and sup > 0 and not homes.has(-1), "supermarché, supérette et 10 immeubles posés")
	for b in [smk, sup] + homes:
		if b > 0:
			bs.buildings[b]["chantier"] = false
	prod._sync()
	pop._sync_buildings()
	_check(prod.sites.has(smk) and String(prod.sites[smk].kind) == "commerce", "le supermarché est un commerce de l'économie")
	for i in 120:
		pop.advance(300.0)
		if (pop.by_job.get(smk, []) as Array).size() >= 3 and (pop.by_job.get(sup, []) as Array).size() >= 1 and pop.households.size() >= 40:
			break
	_check((pop.by_job.get(smk, []) as Array).size() > 0 and (pop.by_job.get(sup, []) as Array).size() > 0, "des caissiers embauchés (%d et %d)" % [(pop.by_job.get(smk, []) as Array).size(), (pop.by_job.get(sup, []) as Array).size()])
	_check(pop.households.size() > 10, "%d foyers installés" % pop.households.size())

	print("Fiche :")
	var hp: HabitantsPanel = scene.habitants_panel
	hp.set_open(true)
	hp.show_view("batiment", smk)
	await process_frame
	var tg: Button = hp._body.find_child("TuileGestion", true, false)
	_check(tg != null and tg.text.begins_with("Gérer le magasin"), "tuile « Gérer le magasin » sur la fiche")
	hp.set_open(false)

	print("Sans gestion, rien ne change :")
	_check(not gest.etats.has(smk) and Gestion.rayons_de(smk) == 1.0 and Gestion.attraction_de(smk) == 1.0 and Gestion.panier_de(smk) == 1.0, "stock, attrait et panier habituels")
	_check(Gestion.entretien_site(smk) == 0.0, "pas d'entretien en plus")
	_remplir(prod, smk)
	_remplir(prod, sup)
	prod._shopping()
	var cap0 := prod.cap_of(smk, "pain") / prod._shop_need(smk, "pain")
	var fid0 := _fideles(prod, homes, smk)
	print("    foyers qui achètent leur pain d'abord au supermarché : %d / %d" % [fid0, homes.size()])

	gest.nouveau_jour({"day": gest.jour + 1, "month": 6})
	prod.clock = 1_784_282_400.0
	prod.new_day()
	_check(not gest.etats.has(smk) and not gest.etats.has(sup) and Gestion.rayons_de(smk) == 1.0, "un jour passe : les magasins jamais ouverts restent comme avant")
	print("Niveaux, compte du magasin :")
	var st := gest.etat(smk)
	_check(gest.valide(smk) and gest.source(smk) == "production", "magasin géré par l'économie")
	_check(int(st.niv.caisses) == 1 and int(st.niv.reserve) == 1 and int(st.niv.boucherie) == 0, "caisses et réserve là, boucherie à construire")
	var px := gest.prix(smk, "boucherie")
	_check(px > 5_000 and px < 200_000, "boucherie : %s" % BuildingSystem.format_money(px))
	prod.sites[smk].cash = 20_000.0
	var caisse0 := bs.money
	var r := gest.ameliorer(smk, "boucherie")
	_check(bool(r.ok) and gest.niveau(smk, "boucherie") == 1, "boucherie construite")
	_check(int(r.batiment) == mini(20_000, px) and bs.money == caisse0 - int(r.ville), "la caisse du magasin paie d'abord (%s), la ville avance %s" % [BuildingSystem.format_money(int(r.batiment)), BuildingSystem.format_money(int(r.ville))])

	print("Rayons mieux remplis :")
	for pid in ["reserve", "reserve", "rayons", "rayons", "quai"]:
		gest.ameliorer(smk, pid)
	gest.acheter(smk, "reserve", "racks")
	gest.acheter(smk, "reserve", "chambre_froide")
	_check(Gestion.rayons_de(smk) > 1.5, "stock gardé : ×%.2f" % Gestion.rayons_de(smk))
	var cap1 := prod.cap_of(smk, "pain") / prod._shop_need(smk, "pain")
	_check(cap1 > cap0 * 1.5, "le magasin garde plus de jours de pain en stock (%.1f au lieu de %.1f)" % [cap1, cap0])
	_check(Gestion.entretien_site(smk) > 0.0, "entretien : %s / jour" % BuildingSystem.format_money(int(Gestion.entretien_site(smk))))

	print("Les foyers changent de magasin :")
	for pid in ["parking", "parking", "parking", "fruits", "fruits", "fruits", "entree", "entree", "boulangerie", "boulangerie", "drive"]:
		gest.ameliorer(smk, pid)
	gest.acheter(smk, "fruits", "etals")
	gest.acheter(smk, "fruits", "producteurs")
	gest.acheter(smk, "entree", "prospectus")
	gest.etat(smk).prix = 0.85
	gest.compter(smk, 0.0, 0.0, 0.0)
	gest.cloture(smk, 0.0)
	_check(Gestion.attraction_de(smk) > 1.5, "attrait du supermarché : ×%.2f" % Gestion.attraction_de(smk))
	_remplir(prod, smk)
	_remplir(prod, sup)
	prod._shopping()
	var fid1 := _fideles(prod, homes, smk)
	_check(fid1 > fid0, "plus de foyers font leurs courses au supermarché (%d → %d)" % [fid0, fid1])
	gest.etat(smk).prix = 1.4
	gest.cloture(smk, 0.0)
	prod._shopping()
	_check(_fideles(prod, homes, smk) < fid1, "prix trop hauts : des foyers repartent chez la supérette (%d)" % _fideles(prod, homes, smk))
	gest.etat(smk).prix = 1.0
	gest.cloture(smk, 0.0)

	print("Panier et clients :")
	var p0 := Gestion.panier_de(smk)
	gest.acheter(smk, "boucherie", "comptoir")
	gest.ameliorer(smk, "bazar")
	gest.acheter(smk, "bazar", "rayon_jouets")
	_check(Gestion.panier_de(smk) > p0 + 0.05, "panier moyen : ×%.2f" % Gestion.panier_de(smk))
	gest.etat(smk).j = {}
	_remplir(prod, smk)
	var cash1 := float(prod.sites[smk].cash)
	prod._shopping()
	var j: Dictionary = gest.etat(smk).j
	_check(float(j.get("clients", 0.0)) > 0.0 and float(j.get("ca", 0.0)) > 0.0, "clients du jour comptés : %d, %s de ventes" % [roundi(float(j.get("clients", 0.0))), BuildingSystem.format_money(int(float(j.get("ca", 0.0))))])
	_check(float(prod.sites[smk].cash) >= cash1 + float(j.get("ca", 0.0)) - 1.0, "les ventes vont dans la caisse du magasin")
	gest.cloture(smk, 100.0)
	_check(gest.capacite(smk) > 0 and gest.prix_unitaire(smk) > 0.0, "%d clients possibles aux caisses, panier moyen %s" % [gest.capacite(smk), BuildingSystem.format_money(roundi(gest.prix_unitaire(smk)))])
	_check(gest.prix_txt(smk).contains("Prix en rayon"), gest.prix_txt(smk))
	var s0 := gest.satisf(smk)
	for i in 8:
		gest.etat(smk).j = {"ca": 1000.0, "clients": float(gest.caisses(smk)) * 2.0}
		gest.cloture(smk, 0.0)
	_check(gest.satisf(smk) < s0, "file d'attente aux caisses : la satisfaction baisse (%.1f → %.1f)" % [s0, gest.satisf(smk)])
	gest.etat(smk).satisf = 3.0

	print("Une journée dans l'économie :")
	prod.clock = 1_784_282_400.0 + 86400.0
	prod.new_day()
	_check((gest.etat(smk).hist as Array).size() >= 1 and gest.hier(smk).has("cap"), "Production clôt la journée du magasin")
	_check(gest.occupation(smk) >= 0.0 and gest.occupation(smk) <= 1.0, "passage aux caisses %d %%" % roundi(gest.occupation(smk) * 100.0))

	print("Vols, promotions, événements :")
	gest.etat(smk).hier = {"ca": 20_000.0, "charges": 0.0, "clients": 500.0, "cap": 2500.0}
	var c_vol := gest.compte(smk)
	gest._evenements_magasin(smk, gest.etat(smk), 6)
	_check(float(gest.etat(smk).vols) > 0.0 and gest.compte(smk) < c_vol, "vols à l'étalage payés par le magasin (%s)" % BuildingSystem.format_money(int(float(gest.etat(smk).vols))))
	var v0 := float(gest.etat(smk).vols)
	for i in 30:
		gest._evenements_magasin(smk, gest.etat(smk), 6)
	var sans := (float(gest.etat(smk).vols) - v0) / 30.0
	gest.acheter(smk, "entree", "portique")
	gest.ameliorer(smk, "entree")
	gest.acheter(smk, "entree", "cameras")
	gest.acheter(smk, "bureau", "ecrans_b")
	gest.acheter(smk, "bureau", "coffre_b")
	var v1 := float(gest.etat(smk).vols)
	for i in 30:
		gest._evenements_magasin(smk, gest.etat(smk), 6)
	var avec := (float(gest.etat(smk).vols) - v1) / 30.0
	_check(avec < sans * 0.8, "portiques et caméras : vols divisés (%s → %s par jour, −%d %%)" % [BuildingSystem.format_money(int(sans)), BuildingSystem.format_money(int(avec)), roundi(gest.antivol(smk) * 100.0)])
	gest.ameliorer(smk, "bureau")
	gest.ameliorer(smk, "bureau")
	for jx in 300:
		gest._evenements_magasin(smk, gest.etat(smk), [10, 12, 6][jx % 3])
		gest.jour += 1
	var vu := {}
	for e in gest.etat(smk).journal:
		for mot in ["Promotion", "client mystère", "Rush", "Vol", "Contrôle"]:
			if String(e[1]).contains(mot):
				vu[mot] = true
	_check(vu.has("Promotion") and vu.has("client mystère") and vu.has("Rush"), "promotions, client mystère et rush au journal (%s)" % ", ".join(vu.keys()))
	_check(int(gest.etat(smk).promos) > 0, "%d semaines de promotion" % int(gest.etat(smk).promos))
	gest.etat(smk).promo_fin = gest.jour + 3
	var a_promo := gest.attraction(smk)
	gest.etat(smk).promo_fin = -1
	_check(a_promo > gest.attraction(smk), "pendant une promotion, le magasin attire plus (×%.2f)" % a_promo)
	var possibles := gest.demandes_possibles(smk)
	_check(possibles.size() >= 6, "%d demandes possibles" % possibles.size())
	var c0 := gest.compte(smk)
	var tip := gest.regler(smk, possibles[0])
	_check(tip > 0.0 and gest.compte(smk) > c0, "demande réglée : %.0f €" % tip)

	print("Gestion automatique :")
	gest.set_auto(sup, true)
	gest.etat(sup)
	prod.sites[sup].cash = 2_000_000.0
	var inv0 := float(gest.etat(sup).invest)
	var caisse_auto := bs.money
	gest.nouveau_jour({"day": gest.jour + 1, "month": 7})
	_check(float(gest.etat(sup).invest) > inv0, "la supérette investit ses bénéfices toute seule (%s)" % BuildingSystem.format_money(int(float(gest.etat(sup).invest) - inv0)))
	_check(bs.money == caisse_auto, "sans toucher à la caisse de la ville")
	var txt := ""
	for o in gest.objectifs(smk):
		txt += String(o.texte) + " ; "
	_check(txt.contains("rayon vide") and txt.contains("vols") and txt.contains("enseignes"), "objectifs du magasin")

	print("Sauvegarde :")
	var niv: Dictionary = gest.etat(smk).niv.duplicate()
	gest.etat(smk).prix = 1.1
	var d := gest.to_dict()
	gest.clear()
	_check(Gestion.rayons_de(smk) == 1.0 and Gestion.attraction_de(smk) == 1.0, "effacé : le magasin redevient comme avant")
	gest.from_dict(JSON.parse_string(JSON.stringify(d)))
	_check(gest.etat(smk).niv == niv and absf(float(gest.etat(smk).prix) - 1.1) < 0.001 and float(gest.etat(smk).vols) > 0.0, "rechargé : niveaux, prix et vols")

	print("Écran isométrique :")
	gest.etat(smk).prix = 1.0
	_check(scene.ouvrir_gestion(smk) and vue.est_ouvert() and vue.genre == "supermarche", "l'écran du magasin s'ouvre")
	await process_frame
	var dio := vue.diorama
	_check(dio.places.has("rayons") and not (dio.places.rayons as Array).is_empty(), "allées des rayons")
	_check(dio.places.has("caisses") and not (dio.places.caisses as Array).is_empty(), "file aux caisses")
	_check(dio.employes.size() + dio.vacants.size() > 0, "personnel ou postes vacants affichés")
	for i in 400:
		vue.simuler(0.1)
	var installes := 0
	for c in dio.clients:
		if String(c.etat) == "installe":
			installes += 1
	_check(installes > 0, "%d clients dans le magasin" % installes)
	vue._remplir_haut()
	var haut := ""
	for c in vue._chiffres.get_children():
		haut += String((c as Button).text) + " | "
	_check(haut.contains("clients"), "clients affichés en haut : %s" % haut)
	vue.choisir("")
	var plus: Button = vue._carte_corps.find_child("Prix_plus", true, false)
	_check(plus != null, "bouton des prix")
	if plus != null:
		plus.pressed.emit()
	_check(float(gest.etat(smk).prix) > 1.0, "prix montés depuis l'écran")
	vue.choisir("frais")
	var ligne: Node = vue._carte_corps.find_child("Objet_bacs", true, false)
	var acheter: Button = ligne.find_child("Acheter", true, false) if ligne != null else null
	_check(acheter != null and not acheter.disabled, "on peut acheter les bacs à surgelés")
	if acheter != null:
		acheter.pressed.emit()
	await process_frame
	_check(gest.a_objet(smk, "frais", "bacs"), "bacs installés depuis l'écran")
	_check(vue._bas.get_child_count() == GestionTypes.ordre("supermarche").size() + 1, "une tuile par pièce en bas")
	vue.fermer()
	_check(not vue.est_ouvert(), "retour à la ville")
	scene.queue_free()
	await process_frame
