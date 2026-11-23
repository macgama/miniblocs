extends SceneTree
## Test des tycoons « en kit » (GenresAuto : zoo, école, gare, musée,
## mairie, stades, fermes…) : chaque fiche montée en vrai genre (pièces
## sans chevauchement, portes, chemins, objets posés dans leur pièce,
## modèles 3D, métiers connus), adaptation à l'époque (noms, pièces et objets
## pas encore inventés) et au pays, puis en ville : compte « lieu » (visiteurs,
## recettes, budget de la ville pour un service public), améliorations,
## gestion automatique, liens avec le vrai système, sauvegarde et écran.
## Usage : godot --headless --path . --script res://tests/gestion_kit_test.gd [--genre zoo]

var ok := true
var seul := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args() + OS.get_cmdline_args()
	var i := args.find("--genre")
	if i >= 0 and i + 1 < args.size():
		seul = String(args[i + 1])
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


func _genres() -> Array:
	var out: Array = []
	for g in GenresAuto.specs():
		if seul == "" or String(g) == seul:
			out.append(String(g))
	return out


func _run() -> void:
	Langue.activer("fr")
	for g in _genres():
		_types_tests(g)
	_epoques_tests()
	await _city_tests()
	print("TEST OK" if ok else "TEST ÉCHEC")
	quit(0 if ok else 1)


static func _rect_dans(r: Array, x: float, z: float, m := 0.01) -> bool:
	return x >= float(r[0]) - m and x <= float(r[0]) + float(r[2]) + m and z >= float(r[1]) - m and z <= float(r[1]) + float(r[3]) + m


func _types_tests(g: String) -> void:
	print("Genre %s :" % g)
	var gd := GestionTypes.genre(g)
	_check(String(gd.get("source", "")) == "lieu" and gd.has("titre") and Icones.has_icon(String(gd.get("icone", ""))), "%s : source « lieu », titre et icône" % g)
	var n := 0
	var exemple := ""
	for id in BuildingCatalog.all_types():
		if GestionTypes.genre_de(String(id)) == g:
			n += 1
			if exemple == "":
				exemple = String(id)
	_check(n >= 1, "%s : %d bâtiment(s) se gèrent (%s…)" % [g, n, exemple])
	var pcs := GestionTypes.ordre(g)
	_check(pcs.size() == GestionTypes.pieces(g).size() and pcs.size() >= 8, "%s : %d pièces" % [g, pcs.size()])
	_check(GestionTypes.pieces(g).has(String(gd.accueil)), "%s : pièce d'accueil" % g)
	var plan: Vector2 = gd.plan
	var porte: Vector2 = gd.porte
	_check(absf(porte.y - plan.y) < 0.01 and porte.x > 0.0 and porte.x < plan.x, "%s : porte sur la façade" % g)
	var metiers_ok := true
	var portes_ok := true
	for pid in pcs:
		var p := GestionTypes.piece(g, String(pid))
		if not (p.has("rect") and p.has("decor") and p.has("effets") and int(p.max) >= 2 and String(p.nom) != ""):
			push_error("pièce incomplète : %s/%s" % [g, pid])
			portes_ok = false
		for m in p.get("metiers", []):
			if not Metiers.METIERS.has(String(m)):
				push_error("%s/%s : métier inconnu %s" % [g, pid, m])
				metiers_ok = false
		if String(pid) != String(gd.accueil) and not p.has("porte"):
			push_error("%s/%s sans porte" % [g, pid])
			portes_ok = false
		# La porte d'une salle du fond s'ouvre sur le hall.
		if p.has("porte") and not GestionTypes.est_dehors(g, String(pid)):
			var a: Array = GestionTypes.piece(g, String(gd.accueil)).rect
			if not _rect_dans(a, float(p.porte[0]), float(p.porte[1])):
				push_error("%s/%s : porte hors du hall" % [g, pid])
				portes_ok = false
	_check(metiers_ok, "%s : métiers connus du jeu" % g)
	_check(portes_ok, "%s : pièces complètes, portes sur le hall" % g)
	for d in gd.demandes:
		_check(GestionTypes.pieces(g).has(String(d.piece)), "%s : demande « %s »" % [g, d.texte])
	for a in gd.activites:
		_check(GestionTypes.pieces(g).has(String(a[0])), "%s : activité %s" % [g, a[0]])
	for pid in gd.pannes:
		_check(GestionTypes.pieces(g).has(String(pid)), "%s : pannes de %s" % [g, pid])
	var nb := 0
	var modeles_ok := true
	var poses_ok := true
	for pid in pcs:
		var r: Array = GestionTypes.piece(g, String(pid)).rect
		for oid in GestionTypes.objets(g, String(pid)):
			var o := GestionTypes.objet(g, String(pid), String(oid))
			nb += 1
			var m := String(o.get("modele", ""))
			if m.begins_with("deco:"):
				if Decors.info(m.substr(5)).is_empty():
					modeles_ok = false
					push_error("décor inconnu : " + m)
			elif m != "":
				var k := LpKit.new(1)
				GestionModeles.dessiner(k, m, Vector3.ZERO, 0.0)
				if k.triangle_count() <= 0:
					modeles_ok = false
					push_error("modèle vide : " + m)
			if (o.poses as Array).is_empty():
				poses_ok = false
				push_error("%s/%s/%s sans place" % [g, pid, oid])
			for ps in o.poses:
				if float(ps[0]) < -0.01 or float(ps[0]) > float(r[2]) + 0.01 or float(ps[1]) < -0.01 or float(ps[1]) > float(r[3]) + 0.01:
					poses_ok = false
					push_error("%s/%s posé hors de la pièce : %s" % [pid, oid, ps])
	_check(nb >= 30, "%s : %d objets à acheter" % [g, nb])
	_check(modeles_ok, "%s : chaque objet a son modèle 3D" % g)
	_check(poses_ok, "%s : chaque objet a sa place dans sa pièce" % g)
	var chevauche := ""
	for i in pcs.size():
		for j in range(i + 1, pcs.size()):
			var a: Array = GestionTypes.piece(g, String(pcs[i])).rect
			var b: Array = GestionTypes.piece(g, String(pcs[j])).rect
			if float(a[0]) < float(b[0]) + float(b[2]) - 0.01 and float(b[0]) < float(a[0]) + float(a[2]) - 0.01 and float(a[1]) < float(b[1]) + float(b[3]) - 0.01 and float(b[1]) < float(a[1]) + float(a[3]) - 0.01:
				chevauche = "%s / %s" % [pcs[i], pcs[j]]
	_check(chevauche == "", "%s : les pièces ne se chevauchent pas %s" % [g, chevauche])
	# Le dehors ne déborde pas sur la rue.
	var dehors_ok := true
	for pid in (gd.dehors as Dictionary):
		var r: Array = gd.dehors[pid].rect
		if float(r[1]) + float(r[3]) > plan.y + 9.0 or float(r[0]) < plan.x:
			dehors_ok = false
	_check(dehors_ok, "%s : le dehors reste entre le bâtiment et la rue" % g)


func _epoques_tests() -> void:
	print("Époques et pays :")
	var r := ReglagesPartie.actuel
	var a0 := r.annee_depart
	var s0 := r.histoire_saut
	var p0 := GameStart.pays
	r.annee_depart = 1850
	r.histoire_saut = 0
	GenresAuto.vider_cache()
	if GenresAuto.connu("zoo"):
		_check(Epoques.annee() < 1900, "partie en %d" % Epoques.annee())
		_check(String(GestionTypes.genre("zoo").nom) == "Ménagerie", "le zoo s'appelle « Ménagerie » avant 1900")
		_check(GestionEpoques.refus_piece("zoo", "vivarium") != "", "pas de vivarium en 1850 : %s" % GestionEpoques.refus_piece("zoo", "vivarium"))
		_check(GestionEpoques.refus_objet("zoo", "accueil", "bornes_z") != "", "pas de borne à billets en 1850")
		_check(GestionEpoques.refus_objet("zoo", "accueil", "plan_zoo") == "", "mais un plan du zoo, oui")
	_check(GestionEpoques.refus_objet("hotel", "chambres", "tele") != "" or GestionTypes.objet("hotel", "chambres", "tele").is_empty(), "les hôtels de 1850 n'ont pas la télé")
	r.annee_depart = 0
	GenresAuto.vider_cache()
	_check(not Epoques.actif() and GestionEpoques.annee() == 99999, "partie moderne : tout est permis")
	if GenresAuto.connu("zoo"):
		_check(String(GestionTypes.genre("zoo").nom) == "Zoo" and GestionEpoques.refus_piece("zoo", "vivarium") == "", "le zoo moderne a son vivarium")
	GameStart.pays = "CH"
	_check(String(GestionTypes.piece("commissariat", "commandement").nom).contains("117"), "en Suisse, la police répond au 117")
	_check(String(GestionTypes.genre("commissariat").titre) == "Gérer le poste de police", "« poste de police » en Suisse")
	GameStart.pays = "FR"
	_check(String(GestionTypes.genre("commissariat").titre) == "Gérer le commissariat", "« commissariat » en France")
	GameStart.pays = p0
	r.annee_depart = a0
	r.histoire_saut = s0
	GenresAuto.vider_cache()


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
	world.view_radius_override = 900.0
	world.set_origin(46.2, 6.9)
	for i in 3000:
		await process_frame
		if i >= 120 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	var gest: Gestion = scene.gestion
	var vue: GestionVue = scene.gestion_vue
	for nd in [transport.traffic, scene.tourisme, scene.population, scene.parc, scene.zoo, scene.musee, scene.spectacles, scene.dechets, scene.production]:
		nd.set_process(false)
	scene.urgences.set_process(false)
	bs.unlimited_money = false
	bs.money = 600_000_000
	ReglagesPartie.actuel.deblocage = "tout"
	ReglagesPartie.actuel.territoire = false
	var y := world.cell_height(Vector2i(0, 0))
	var rangs := [0, 220, -220, 440, -440, 660, -660]
	for rz in rangs.slice(0, ceili(_genres().size() / 7.0)):
		_check(transport.build_segment("route", Vector3(-560, y, rz), Vector3(560, y, rz)).ok, "route en z = %d" % rz)
	var n := 0
	for g in _genres():
		var x := -500 + (n % 7) * 160
		var z := rangs[mini(n / 7, rangs.size() - 1)] as int
		n += 1
		var candidats: Array[String] = []
		if String(GenresAuto.specs()[g].get("exemple", "")) != "":
			candidats.append(String(GenresAuto.specs()[g].exemple))
		for id in BuildingCatalog.all_types():
			if GestionTypes.genre_de(String(id)) == g and not String(id).contains("__") and not String(id) in candidats:
				candidats.append(String(id))
		var type_id := ""
		var bid := -1
		# Le premier type du genre qui se pose (une carrière veut son gisement).
		for t in candidats.slice(0, 6):
			type_id = t
			bid = _poser(bs, type_id, x, z)
			if bid > 0:
				break
			var c2 := Vector2i(x, z - BuildingCatalog.footprint(type_id, 0).y / 2 - 6)
			print("    refus (%s) : %s" % [type_id, bs.check_place(type_id, c2, bs.best_rotation(type_id, c2), false, 0.0).get("reason", "?")])
		_check(bid > 0, "%s : %s posé" % [g, type_id])
		if bid <= 0:
			continue
		bs.buildings[bid]["chantier"] = false
		scene.population._sync_buildings()
		await _un_genre(scene, gest, vue, bs, g, bid)
	# Sauvegarde et rechargement.
	print("Sauvegarde :")
	var d := gest.to_dict()
	var avant := gest.etats.duplicate(true)
	gest.from_dict(JSON.parse_string(JSON.stringify(d)))
	var memes := true
	for b in avant:
		if not gest.etats.has(b) or absf(float(gest.etats[b].caisse) - float(avant[b].caisse)) > 0.5:
			memes = false
			continue
		for pid in avant[b].niv:
			if int(gest.etats[b].niv.get(pid, -1)) != int(avant[b].niv[pid]):
				memes = false
	_check(memes and gest.etats.size() == avant.size(), "%d établissements retrouvés après rechargement" % gest.etats.size())
	scene.queue_free()
	await process_frame


func _poser(bs: BuildingSystem, type_id: String, x: int, z: int) -> int:
	var sn := bs.road_snap(type_id, Vector2i(x, z - 40))
	var bid := bs.place(type_id, sn.center, int(sn.r), 0, float(sn.get("a", 0.0))) if sn.has("center") else -1
	if bid <= 0:
		var c0 := Vector2i(x, z - 16)
		bid = bs.place(type_id, c0, bs.best_rotation(type_id, c0))
	if bid <= 0:
		for r in 4:
			bid = bs.place(type_id, Vector2i(x, z - BuildingCatalog.footprint(type_id, r).y / 2 - 6), r)
			if bid > 0:
				break
	return bid


func _un_genre(scene: Node, gest: Gestion, vue: GestionVue, bs: BuildingSystem, g: String, bid: int) -> void:
	var gd := GestionTypes.genre(g)
	_check(gest.genre_of(bid) == g and gest.valide(bid) and gest.source(bid) == "lieu", "%s : géré en compte propre" % g)
	print("  %s : fiche" % g)
	var hp: HabitantsPanel = scene.habitants_panel
	hp.set_open(true)
	hp.show_view("batiment", bid)
	await process_frame
	var tg: Button = hp._body.find_child("TuileGestion", true, false)
	_check(tg != null and tg.text.begins_with(String(gd.titre)), "%s : tuile « %s » sur la fiche" % [g, gd.titre])
	hp.set_open(false)
	var argent0 := bs.money
	gest.nouveau_jour({"day": gest.jour + 1, "month": 6})
	_check(not gest.etats.has(bid), "%s : jamais ouvert, rien ne change" % g)
	var st := gest.etat(bid)
	gest.set_auto(bid, false)
	_check(gest.capacite(bid) > 0, "%s : capacité %d %s par jour" % [g, gest.capacite(bid), gd.get("unite", "")])
	argent0 = bs.money
	var publique := GestionLieu.public(gest, bid)
	for i in 3:
		gest.nouveau_jour({"day": gest.jour + 1, "month": 6})
	var h := gest.hier(bid)
	_check((st.hist as Array).size() == 3 and h.has("ca"), "%s : trois journées comptées (hier : %s, %d %s)" % [g, BuildingSystem.format_money(int(h.ca)), int(h.clients), gd.get("unite", "")])
	if publique:
		_check(float(h.budget) > 0.0 and bs.money < argent0, "%s : la ville verse le budget (%s par jour)" % [g, BuildingSystem.format_money(int(h.budget))])
		var d0 := GestionLieu.dotation(gest, bid)
		gest.changer_prix(bid, 1)
		_check(GestionLieu.dotation(gest, bid) > d0 or GestionLieu.panier(gest, bid) > 0.0, "%s : − / + règle le budget" % g)
	else:
		_check(float(h.clients) > 0.0 and gest.compte(bid) > 0.0, "%s : des visiteurs et de l'argent sur le compte (%s)" % [g, BuildingSystem.format_money(int(gest.compte(bid)))])
		var px0 := float(st.prix)
		gest.changer_prix(bid, 1)
		_check(float(st.prix) > px0 and gest.prix_txt(bid) != "", "%s : prix monté (%s)" % [g, gest.prix_txt(bid)])
		gest.changer_prix(bid, -1)
	# Améliorer une pièce à construire.
	var cible := ""
	for pid in GestionTypes.ordre(g):
		if gest.niveau(bid, String(pid)) == 0 and GestionEpoques.refus_piece(g, String(pid)) == "":
			cible = String(pid)
			break
	if cible != "":
		var c0 := gest.capacite(bid)
		var r := gest.ameliorer(bid, cible)
		_check(bool(r.ok) and gest.niveau(bid, cible) == 1, "%s : %s construit (%s)" % [g, cible, BuildingSystem.format_money(int(r.batiment) + int(r.ville))])
		_check(gest.capacite(bid) >= c0, "%s : capacité gardée ou en hausse" % g)
	# Un objet.
	var achat := false
	for pid in GestionTypes.ordre(g):
		for oid in GestionTypes.objets(g, String(pid)):
			if gest.refus_objet(bid, String(pid), String(oid)) == "":
				achat = bool(gest.acheter(bid, String(pid), String(oid)).ok)
				break
		if achat:
			break
	_check(achat, "%s : un objet acheté" % g)
	# Gestion automatique : elle investit seule.
	gest.set_auto(bid, true)
	st.caisse = float(st.caisse) + 400_000.0
	var inv0 := float(st.invest)
	for i in 10:
		gest.nouveau_jour({"day": gest.jour + 1, "month": 7})
	_check(float(st.invest) > inv0, "%s : la gestion automatique investit (%s)" % [g, BuildingSystem.format_money(int(float(st.invest) - inv0))])
	_check(gest.objectifs(bid).size() >= 6, "%s : objectifs" % g)
	# Lien avec le vrai système.
	await _liens(scene, gest, g, bid)
	# L'écran isométrique s'ouvre et se ferme.
	_check(vue.ouvrir(bid), "%s : écran isométrique ouvert" % g)
	for i in 4:
		await process_frame
	var nb_pl := 0
	for pid in vue.diorama.places:
		nb_pl += (vue.diorama.places[pid] as Array).size()
	_check(nb_pl >= 10, "%s : %d places pour les visiteurs dans la maquette" % [g, nb_pl])
	for t in ["ensemble", "personnel", "essor", "avis", "stats", "journal"]:
		vue.onglet = t
		vue._remplir_carte()
	await process_frame
	_check(vue.visible, "%s : tous les onglets s'affichent" % g)
	vue.fermer()
	await process_frame


func _liens(scene: Node, gest: Gestion, g: String, bid: int) -> void:
	match g:
		"zoo":
			var z: ZooSysteme = scene.zoo
			z._sync()
			_check(z.zoos.has(bid), "zoo : le vrai zoo existe")
			var a0 := z.attrait(bid)
			var st := gest.etat(bid)
			st.niv["nurserie"] = 4
			var a1 := z.attrait(bid)
			_check(a1 >= a0, "zoo : la nurserie attire plus de monde (%.1f → %.1f)" % [a0, a1])
			z.zoos[bid].hier.visiteurs = 420
			z.zoos[bid].hier.billets = 8000.0
			var c0 := gest.compte(bid)
			gest.nouveau_jour({"day": gest.jour + 1, "month": 7})
			_check(gest.clients(bid) == 420, "zoo : les vrais visiteurs d'hier comptent (%d)" % gest.clients(bid))
			_check(gest.compte(bid) > c0 or bool(st.auto), "zoo : une part des billets va aux travaux")
