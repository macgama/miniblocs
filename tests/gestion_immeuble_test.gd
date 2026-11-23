extends SceneTree
## Test du mode gestion de l'immeuble : immeubles et tours se gèrent (pas les
## maisons ni les baraques), pièces, objets et modèles complets, tuile
## « Gérer l'immeuble », compte = loyers encaissés, vrais logements en plus
## (de nouveaux foyers s'installent), vrai loyer des foyers (Immobilier,
## budget), satisfaction des habitants, événements, gestion automatique,
## sauvegarde et écran isométrique.
## Usage : xvfb-run -a godot --path . --rendering-driver opengl3 --script res://tests/gestion_immeuble_test.gd

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
	print("Genre immeuble :")
	_check(GestionTypes.genre_de("immeuble") == "immeuble" and GestionTypes.genre_de("tour_habitation") == "immeuble" and GestionTypes.genre_de("haussmann__immeuble") == "immeuble", "immeuble, tour, haussmannien")
	_check(GestionTypes.genre_de("maison") == "" and GestionTypes.genre_de("baraques") == "" and GestionTypes.genre_de("haussmann__rangee") == "", "ni maison, ni baraques, ni maisons en rangée")
	_check(GestionTypes.genre_de("supermarche") == "supermarche" and GestionTypes.genre_de("scierie") == "usine", "les autres genres ne changent pas")
	var g := "immeuble"
	var gd := GestionTypes.genre(g)
	_check(String(gd.titre) == "Gérer l'immeuble" and Icones.has_icon(String(gd.icone)), "titre et icône")
	_check(GestionTypes.ordre(g).size() == GestionTypes.pieces(g).size() and GestionTypes.ordre(g).size() >= 12, "%d pièces, toutes dans l'ordre" % GestionTypes.ordre(g).size())
	_check(GestionTypes.pieces(g).has(String(gd.accueil)), "la pièce d'accueil existe")
	for pid in GestionTypes.ordre(g):
		var p := GestionTypes.piece(g, String(pid))
		_check(p.has("rect") and p.has("decor") and p.has("effets") and int(p.max) >= 2, "pièce %s complète" % pid)
		if p.has("via"):
			_check(GestionTypes.pieces(g).has(String(p.via)), "%s : on y passe par %s" % [pid, p.via])
	for d in gd.demandes:
		_check(GestionTypes.pieces(g).has(String(d.piece)), "demande « %s » dans une pièce connue" % d.texte)
	for a in gd.activites:
		_check(GestionTypes.pieces(g).has(String(a[0])), "activité %s" % a[0])
	for e in ["logements", "standing", "antivol", "economie"]:
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
	_check(nb >= 55, "%d objets à acheter" % nb)
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
	var imm: int = poser.call("immeuble", Vector2i(-100, 30))
	var autre: int = poser.call("immeuble", Vector2i(-40, 30))
	var job: int = poser.call("supermarche", Vector2i(150, -40))
	_check(imm > 0 and autre > 0 and job > 0, "deux immeubles et un supermarché posés")
	for b in [imm, autre, job]:
		bs.buildings[b]["chantier"] = false
	prod._sync()
	pop._sync_buildings()
	var log0 := int(pop.known[imm].log)
	for i in 200:
		pop.advance(300.0)
		if pop.free_homes(imm) == 0 and pop.free_homes(autre) == 0:
			break
	_check(pop.free_homes(imm) == 0, "l'immeuble se remplit : %d foyers dans %d logements" % [(pop.by_home.get(imm, []) as Array).size(), log0])

	print("Fiche :")
	var hp: HabitantsPanel = scene.habitants_panel
	hp.set_open(true)
	hp.show_view("batiment", imm)
	await process_frame
	var tg: Button = hp._body.find_child("TuileGestion", true, false)
	_check(tg != null and tg.text.begins_with("Gérer l'immeuble"), "tuile « Gérer l'immeuble » sur la fiche")
	hp.set_open(false)

	print("Sans gestion, rien ne change :")
	var nu := scene.nuisances as Nuisances
	var loyer0 := nu.loyer(imm) if nu != null else 0.0
	_check(Gestion.logements_de(imm) == 0 and Gestion.loyer_de(imm) == 1.0 and Immobilier.mult_loyer(imm, 1.0) == Immobilier.mult_loyer(autre, 1.0), "logements et loyer habituels")
	gest.nouveau_jour({"day": gest.jour + 1, "month": 6})
	_check(not gest.etats.has(imm) and not gest.etats.has(autre), "un jour passe : les immeubles jamais ouverts restent comme avant")

	print("Niveaux, compte de l'immeuble :")
	var st := gest.etat(imm)
	_check(gest.valide(imm) and gest.source(imm) == "logement", "immeuble géré, chiffres des habitants")
	_check(int(st.niv.hall) == 1 and int(st.niv.appart_a) == 1 and int(st.niv.combles) == 0, "hall et appartements là, combles à aménager")
	_check(gest.capacite(imm) == log0 and gest.clients(imm) == log0, "%d / %d logements loués" % [gest.clients(imm), gest.capacite(imm)])
	var px := gest.prix(imm, "combles")
	_check(px > 3_000 and px < 200_000, "combles : %s" % BuildingSystem.format_money(px))
	st.caisse = 10_000.0
	var caisse0 := bs.money
	var r := gest.ameliorer(imm, "combles")
	_check(bool(r.ok) and gest.niveau(imm, "combles") == 1, "combles aménagés")
	_check(int(r.batiment) == mini(10_000, px) and bs.money == caisse0 - int(r.ville), "la caisse de l'immeuble paie d'abord (%s), la ville avance %s" % [BuildingSystem.format_money(int(r.batiment)), BuildingSystem.format_money(int(r.ville))])

	print("Vrais logements en plus :")
	for pid in ["combles", "appart_a", "appart_b"]:
		gest.ameliorer(imm, pid)
	gest.acheter(imm, "combles", "mezzanine")
	var nl := Gestion.logements_de(imm)
	_check(nl >= 4, "%d logements aménagés" % nl)
	_check(int(pop.known[imm].log) == log0 + nl and gest.capacite(imm) == log0 + nl, "la ville connaît %d logements au lieu de %d" % [int(pop.known[imm].log), log0])
	_check(pop.free_homes(imm) == nl, "%d logements libres pour de nouveaux foyers" % pop.free_homes(imm))
	for i in 200:
		pop.advance(300.0)
		if pop.free_homes(imm) == 0:
			break
	_check((pop.by_home.get(imm, []) as Array).size() > log0, "de nouveaux foyers s'installent : %d foyers" % (pop.by_home.get(imm, []) as Array).size())
	pop._sync_buildings()
	_check(int(pop.known[imm].log) == log0 + nl, "les logements aménagés restent après une resynchronisation")

	print("Loyer des foyers :")
	var hid: int = int((pop.by_home[imm] as Array)[0])
	var bud0 := float(pop.household_budget(hid).loyer)
	gest.changer_prix(imm, 1)
	gest.changer_prix(imm, 1)
	_check(absf(Gestion.loyer_de(imm) - 1.1) < 0.001 and gest.prix_txt(imm).contains("110 %"), gest.prix_txt(imm))
	_check(float(pop.household_budget(hid).loyer) > bud0 * 1.08, "le vrai loyer du foyer monte (%s → %s par mois)" % [BuildingSystem.format_money(int(bud0)), BuildingSystem.format_money(int(float(pop.household_budget(hid).loyer)))])
	if nu != null:
		_check(nu.loyer(imm) > loyer0 * 1.08, "loyer du quartier affiché : %s au lieu de %s" % [BuildingSystem.format_money(int(nu.loyer(imm))), BuildingSystem.format_money(int(loyer0))])
	_check(Immobilier.mult_loyer(imm, 1.0) > Immobilier.mult_loyer(autre, 1.0), "Immobilier applique le loyer du gérant")
	for i in 20:
		gest.changer_prix(imm, 1)
	_check(absf(float(gest.etat(imm).prix) - Gestion.LOYER_MAX) < 0.001, "loyer plafonné à %d %%" % roundi(Gestion.LOYER_MAX * 100.0))
	var s_haut := gest.satisf(imm)
	for i in 10:
		gest._journee_logement(imm, gest.etat(imm))
	_check(gest.satisf(imm) < s_haut, "loyer à 150 %% : les habitants râlent (%.1f → %.1f)" % [s_haut, gest.satisf(imm)])
	gest.etat(imm).prix = 1.0

	print("Une journée de l'immeuble :")
	var c0 := gest.compte(imm)
	gest._journee_logement(imm, gest.etat(imm))
	var h: Dictionary = gest.hier(imm)
	_check(float(h.get("ca", 0.0)) > 0.0 and float(h.clients) > 0.0 and h.has("cap"), "loyers encaissés : %s pour %d foyers" % [BuildingSystem.format_money(int(float(h.ca))), int(h.clients)])
	_check(absf(gest.compte(imm) - (c0 + float(h.ca) - float(h.charges))) < 1.0 or gest.compte(imm) == 0.0, "loyers moins charges dans la caisse")
	_check(gest.occupation(imm) > 0.5 and gest.occupation(imm) <= 1.0, "logements loués : %d %%" % roundi(gest.occupation(imm) * 100.0))

	print("Satisfaction des habitants :")
	var pid0: int = int((pop.households[hid].m as Array)[0])
	var p: Dictionary = pop.persons[pid0]
	gest.etat(imm).satisf = 3.0
	var sat0 := int(pop.satisfaction(p).value)
	for pidx in ["loge", "jardin", "buanderie", "escalier", "hall"]:
		gest.ameliorer(imm, pidx)
	gest.acheter(imm, "escalier", "ascenseur")
	gest.acheter(imm, "hall", "boites")
	for i in 20:
		gest._journee_logement(imm, gest.etat(imm))
	_check(gest.satisf(imm) > 3.5, "immeuble bien tenu : satisfaction %.1f" % gest.satisf(imm))
	var sat1 := pop.satisfaction(p)
	_check(int(sat1.value) > sat0, "un habitant est plus content (%d → %d)" % [sat0, int(sat1.value)])
	_check(" ".join(sat1.why).contains("immeuble bien tenu"), "la raison s'affiche : « immeuble bien tenu »")

	print("Événements :")
	gest.etat(imm).prix = 1.3
	var vu := {}
	# Les tirages dépendent de tout ce qui a utilisé le hasard avant : on regarde le journal chaque jour
	# (il ne garde que les 40 dernières lignes) et on continue jusqu'à 1 500 jours si besoin.
	for jx in 1500:
		gest._evenements_immeuble(imm, gest.etat(imm), [3, 6, 9][jx % 3])
		gest._journee_logement(imm, gest.etat(imm))
		gest.jour += 1
		for e in gest.etat(imm).journal:
			if int(e[0]) < gest.jour - 1:
				break
			for mot in ["Dégât des eaux", "label", "Cambriolage", "Fête des voisins", "Assemblée", "loyer"]:
				if String(e[1]).contains(mot):
					vu[mot] = true
		if jx >= 299 and vu.has("label") and vu.has("Dégât des eaux") and vu.has("loyer"):
			break
	gest.etat(imm).prix = 1.0
	_check(vu.has("label") and vu.has("Dégât des eaux") and vu.has("loyer"), "label, dégâts des eaux et impayés au journal (%s)" % ", ".join(vu.keys()))
	var possibles := gest.demandes_possibles(imm)
	_check(possibles.size() >= 6, "%d demandes possibles" % possibles.size())
	var cc := gest.compte(imm)
	var tip := gest.regler(imm, possibles[0])
	_check(tip > 0.0 and gest.compte(imm) > cc, "demande réglée : %.0f €" % tip)

	print("Gestion automatique :")
	gest.set_auto(autre, true)
	gest.etat(autre).caisse = 500_000.0
	var inv0 := float(gest.etat(autre).invest)
	var caisse_auto := bs.money
	gest.nouveau_jour({"day": gest.jour + 1, "month": 7})
	_check(float(gest.etat(autre).invest) > inv0, "l'autre immeuble investit tout seul (%s)" % BuildingSystem.format_money(int(float(gest.etat(autre).invest) - inv0)))
	_check(bs.money == caisse_auto, "sans toucher à la caisse de la ville")
	var txt := ""
	for o in gest.objectifs(imm):
		txt += String(o.texte) + " ; "
	_check(txt.contains("logements de plus") and txt.contains("habitants contents") and txt.contains("clés"), "objectifs de l'immeuble")

	print("Sauvegarde :")
	var niv: Dictionary = gest.etat(imm).niv.duplicate()
	gest.etat(imm).prix = 1.15
	var d := gest.to_dict()
	gest.clear()
	_check(Gestion.logements_de(imm) == 0 and Gestion.loyer_de(imm) == 1.0 and int(pop.known[imm].log) == log0, "effacé : l'immeuble redevient comme avant (%d logements)" % int(pop.known[imm].log))
	gest.from_dict(JSON.parse_string(JSON.stringify(d)))
	_check(gest.etat(imm).niv == niv and absf(Gestion.loyer_de(imm) - 1.15) < 0.001 and int(pop.known[imm].log) == log0 + Gestion.logements_de(imm), "rechargé : niveaux, loyer et logements aménagés")

	print("Écran isométrique :")
	gest.etat(imm).prix = 1.0
	_check(scene.ouvrir_gestion(imm) and vue.est_ouvert() and vue.genre == "immeuble", "l'écran de l'immeuble s'ouvre")
	await process_frame
	var dio := vue.diorama
	_check(dio.places.has("appart_a") and not (dio.places.appart_a as Array).is_empty(), "appartements meublés")
	_check(dio.places.has("jardin") and not (dio.places.jardin as Array).is_empty(), "jardin partagé")
	for i in 400:
		vue.simuler(0.1)
	var installes := 0
	for c in dio.clients:
		if String(c.etat) == "installe":
			installes += 1
	_check(installes > 0, "%d habitants et visiteurs dans l'immeuble" % installes)
	vue._remplir_haut()
	var haut := ""
	for c in vue._chiffres.get_children():
		haut += String((c as Button).text) + " | "
	_check(haut.contains("logements loués"), "logements affichés en haut : %s" % haut)
	vue.choisir("")
	var plus: Button = vue._carte_corps.find_child("Prix_plus", true, false)
	_check(plus != null, "bouton du loyer")
	if plus != null:
		plus.pressed.emit()
	_check(float(gest.etat(imm).prix) > 1.0, "loyer monté depuis l'écran")
	vue.choisir("caves")
	var ligne: Node = vue._carte_corps.find_child("Objet_poubelles", true, false)
	var acheter: Button = ligne.find_child("Acheter", true, false) if ligne != null else null
	_check(acheter != null and not acheter.disabled, "on peut acheter les conteneurs de tri")
	if acheter != null:
		acheter.pressed.emit()
	await process_frame
	_check(gest.a_objet(imm, "caves", "poubelles"), "conteneurs installés depuis l'écran")
	_check(vue._bas.get_child_count() == GestionTypes.ordre("immeuble").size() + 1, "une tuile par pièce en bas")
	vue.fermer()
	_check(not vue.est_ouvert(), "retour à la ville")
	scene.queue_free()
	await process_frame
