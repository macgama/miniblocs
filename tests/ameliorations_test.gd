extends SceneTree
## Test des améliorations de bâtiments (Ameliorations) : capacités par niveau,
## agrandissement en chantier payé au fil des travaux (école 1 → 2 → 3, places
## des élèves), étages en plus (bâtiment réglable et modèle Blender), centrale
## plus puissante, rénovation qui efface l'usure, sauvegarde, densification du
## zonage aux frais des propriétaires, relais de la carte entre amis.
## Usage : godot --headless --path . --script res://tests/ameliorations_test.gd

var ok := true


func _initialize() -> void:
	_run.call_deferred()
	create_timer(400.0).timeout.connect(func() -> void:
		push_error("ÉCHEC : délai dépassé")
		quit(1))


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


func _tris(m: Mesh) -> int:
	var n := 0
	for s in m.get_surface_count():
		var arr := m.surface_get_arrays(s)
		var idx = arr[Mesh.ARRAY_INDEX]
		n += (idx as PackedInt32Array).size() / 3 if idx != null and not (idx as PackedInt32Array).is_empty() else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return n


func _run() -> void:
	Creations.persist = false
	BatimentsVie.chantiers = false
	GameStart.chosen = true
	GameStart.place_name = "Valfleuri, Savoie"
	ReglagesPartie.prochaine = ReglagesPartie.preset("normal")
	ReglagesPartie.prochaine.deblocage = "tout"  # (ce test ne porte pas sur l'arbre de progression)
	ReglagesPartie.prochaine.services_fondation = false  # (services posés d'office : tests/services_fondation_test.gd)
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var bs: BuildingSystem = scene.get_node("Batiments")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.view_radius_override = 1200.0
	world.set_origin(45.5, 6.4)
	for i in 3000:
		await process_frame
		if i >= 120 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	scene.urgences.random_calls = false
	scene.population.arrivals = false
	bs.require_access = false
	# Ce test vérifie les prix des travaux : la ville paie tout (sans promoteurs privés).
	ReglagesPartie.actuel.promoteurs_prives = false
	scene.communes.nom_en_attente = "Valfleuri"
	bs.place("maison_commune", Vector2i(-60, -60), 0)
	for i in 4:
		await process_frame
	var am: Ameliorations = scene.ameliorations
	var vie: BatimentsVie = scene.vie_batiments
	_check(am != null and Ameliorations.instance == am, "nœud Ameliorations branché")

	print("Types et capacités :")
	_check(Ameliorations.ameliorable("ecole") and Ameliorations.ameliorable("maison") and Ameliorations.ameliorable("poste_national"),
		"école, maison et poste électrique s'agrandissent")
	_check(not Ameliorations.ameliorable("place_village") or BuildingCatalog.get_type("place_village").is_empty(), "un espace public ne s'agrandit pas")
	var fake := {"t": "maison", "niv": 3}
	_check(is_equal_approx(Ameliorations.facteur({"t": "maison"}), 1.0) and is_equal_approx(Ameliorations.facteur({"t": "maison", "niv": 2}), 1.5)
		and is_equal_approx(Ameliorations.facteur(fake), 2.0), "facteurs 1 ; 1,5 ; 2")

	print("Agrandir une école :")
	var pos := _spot(bs, "ecole", Vector2i(0, 0))
	print("    pose : ", bs.check_place("ecole", pos, 0).get("reason", ""))
	var eco := bs.place("ecole", pos, 0)
	if eco <= 0:
		_check(false, "école posée")
		quit(1)
		return
	for i in 4:
		await process_frame
	_check(eco > 0, "école posée")
	var seats1 := int(scene.population.known[eco].seats)
	var emp1 := int(scene.population.known[eco].emp)
	var h1 := bs.node_of(eco).mesh.get_aabb().size.y
	print("    places niveau 1 : %d, emplois %d, hauteur %.1f m" % [seats1, emp1, h1])
	_check(seats1 > 0 and am.refus_agrandir(eco) == "", "agrandissement possible")
	var prix := am.cout(eco, 2)
	_check(prix == roundi(ReglagesPartie.prix(BuildingCatalog.cost("ecole")) * 0.6), "prix du niveau 2 : %s" % BuildingSystem.format_money(prix))
	BatimentsVie.chantiers = true
	var argent0 := bs.money
	_check(am.agrandir(eco), "chantier lancé")
	var a: Dictionary = am.en_cours(eco)
	_check(not a.is_empty() and int(a.cible) == 2 and int(a.du) == prix, "travaux en cours, %s à payer" % BuildingSystem.format_money(int(a.get("du", 0))))
	_check(bs.node_of(eco).get_node_or_null("EchafaudageTravaux") != null and am.travaux_en_cours().has(eco) and am.texte_travaux(eco).contains("Agrandissement"),
		"échafaudages et marqueur de travaux (détail au survol)")
	_check(am.refus_agrandir(eco) != "", "pas deux chantiers à la fois")
	_check(int(scene.population.known[eco].seats) == seats1, "l'école reste ouverte avec ses places pendant les travaux")
	# Une semaine de travail plus tard.
	# Chantier long (les tests vont 36 fois plus vite) : on le voit avancer semaine après semaine.
	a.hr = 30000.0
	print("    caisse %s, t_prev %.0f, t %.0f, hr %.0f, rythme %.2f" % [BuildingSystem.format_money(bs.money), am._t_prev, am.now(), float(a.hr), Chantiers.rythme(scene.population)])
	scene.ambiance.unix_time += 7.0 * 86400.0
	am._avancer()
	a = am.en_cours(eco)
	print("    après : caisse %s, av %.4f, du %d" % [BuildingSystem.format_money(bs.money), float(a.get("av", 0)), int(a.get("du", 0))])
	_check(not a.is_empty() and float(a.av) > 0.0 and bs.money < argent0, "les travaux avancent (%d %%) et se paient (%s)" % [
		floori(float(a.get("av", 0.0)) * 100.0), BuildingSystem.format_money(argent0 - bs.money)])
	for i in 200:
		scene.ambiance.unix_time += 7.0 * 86400.0
		am._avancer()
		if am.en_cours(eco).is_empty():
			break
	_check(am.en_cours(eco).is_empty() and Ameliorations.niveau(bs.buildings[eco]) == 2, "école au niveau 2")
	_check(argent0 - bs.money == prix, "payée en tout %s" % BuildingSystem.format_money(argent0 - bs.money))
	await process_frame
	_check(bs.node_of(eco).get_node_or_null("EchafaudageTravaux") == null, "échafaudages démontés")
	var seats2 := int(scene.population.known[eco].seats)
	_check(seats2 == roundi(seats1 * 1.5) and int(scene.population.known[eco].emp) == roundi(emp1 * 1.5),
		"places %d → %d, emplois %d → %d" % [seats1, seats2, emp1, int(scene.population.known[eco].emp)])
	var h2 := bs.node_of(eco).mesh.get_aabb().size.y
	_check(h2 > h1 + 2.0, "un étage de plus : %.1f → %.1f m" % [h1, h2])
	_check(int(bs.totals().emplois) >= roundi(emp1 * 1.5), "totaux de la ville à jour")
	BatimentsVie.chantiers = false
	am.agrandir(eco)
	await process_frame
	am._avancer()
	_check(Ameliorations.niveau(bs.buildings[eco]) == 3 and int(scene.population.known[eco].seats) == seats1 * 2, "niveau 3 : %d places" % int(scene.population.known[eco].seats))
	_check(am.refus_agrandir(eco).contains("maximum"), "pas de niveau 4")

	print("Étages insérés dans un modèle Blender :")
	var glb_id := ""
	for id in ["creche", "chalet_bernois", "theatre", "epicerie_quartier"]:
		if BuildingCatalog.get_type(id).has("glb") and Ameliorations.ameliorable(id):
			glb_id = id
			break
	_check(glb_id != "", "modèle Blender trouvé : %s" % glb_id)
	var gp := _spot(bs, glb_id, Vector2i(200, 0))
	var g := bs.place(glb_id, gp, 0)
	await process_frame
	var mg1 := bs.node_of(g).mesh
	am.regler_niveau(g, 2)
	var mg2 := bs.node_of(g).mesh
	# Bâtiment bas : rehaussé ; bâtiment à étages : un étage recopié (plus de triangles).
	_check(mg2 != mg1 and mg2.get_aabb().size.y > mg1.get_aabb().size.y + 1.5 and (_tris(mg2) > _tris(mg1) or mg1.get_aabb().size.y < 7.5),
		"%s : %.1f → %.1f m, %d → %d triangles" % [glb_id, mg1.get_aabb().size.y, mg2.get_aabb().size.y, _tris(mg1), _tris(mg2)])
	var far := bs.node_of(g).get_node_or_null("Loin") as MeshInstance3D
	_check(far == null or far.mesh.get_aabb().size.y > mg1.get_aabb().size.y + 1.0, "version lointaine agrandie aussi")

	print("Centrale plus puissante :")
	var pn := bs.place("poste_national", _spot(bs, "poste_national", Vector2i(-200, 0)), 0)
	for i in 6:
		await process_frame
	var nom1 := float(ReseauxTypes.info("poste_national").get("cap", 0.0))
	am.regler_niveau(pn, 2)
	_check(is_equal_approx(scene.reseaux._niv(pn), 1.5), "réseau : capacité ×1,5")
	_check(am.texte_capacites(pn).contains(str(roundi(nom1 * 1.5))), "fiche : %s" % am.texte_capacites(pn))

	print("Rénovation :")
	var m := bs.place("maison", _spot(bs, "maison", Vector2i(0, 150)), 0)
	await process_frame
	vie._etat[m].usure = 4
	_check(am.refus_renover(m) == "", "maison usée : rénovation possible")
	var ar := bs.money
	am.renover(m)
	_check(not am.en_cours(m).is_empty(), "rénovation en cours")
	am.finir_tout()
	_check(am.en_cours(m).is_empty() and bs.buildings[m].has("renov") and ar - bs.money == am.cout(m, 0), "rénovée pour %s" % BuildingSystem.format_money(ar - bs.money))
	_check(int(vie._etat[m].usure) == -1 or int(vie._etat[m].usure) == 0, "usure effacée")
	vie._update_vie()
	_check(int(vie._etat[m].usure) <= 1, "usure recalculée depuis la rénovation : %d" % int(vie._etat[m].usure))

	print("Sauvegarde :")
	BatimentsVie.chantiers = true
	am.agrandir(m)
	var d := bs.to_dict()
	var sec := am.to_dict()
	var trouve := {}
	for e in d.buildings:
		trouve[int(e.id)] = e
	_check(int(trouve[eco].get("niv", 1)) == 3 and trouve[m].has("amel") and trouve[m].has("renov"), "niveau, rénovation et travaux sauvegardés")
	var json: Dictionary = JSON.parse_string(JSON.stringify(d))
	bs.from_dict(json)
	am.from_dict(JSON.parse_string(JSON.stringify(sec)))
	await process_frame
	_check(Ameliorations.niveau(bs.buildings[eco]) == 3 and bs.node_of(eco).mesh.get_aabb().size.y > h2, "niveau et étages rechargés")
	_check(not am.en_cours(m).is_empty() and int(am.en_cours(m).cible) == 2, "travaux rechargés")
	await process_frame
	_check(bs.node_of(m).get_node_or_null("EchafaudageTravaux") != null, "échafaudages remontés au chargement")
	BatimentsVie.chantiers = false
	am._avancer()

	print("Densification du zonage :")
	var zid: int = scene.zones.add_zone("R", Rect2i(Vector2i(300, 300), Vector2i(40, 40)))
	var zp := _spot(bs, "maison", Vector2i(320, 320))
	print("    zone %d, pose : %s" % [zid, bs.check_place("maison", zp, 0, true).get("reason", "")])
	var zh := bs.place("maison", zp, 0)
	await process_frame
	# Zone factice : seule sa sorte (R) compte pour la densification.
	zid = 99999
	scene.zones.zones[zid] = {"id": zid, "k": "R", "x": zp.x - 20, "z": zp.y - 20, "w": 40, "h": 40, "s": ""}
	bs.buildings[zh]["zone"] = zid
	_check(zh > 0 and int(bs.buildings[zh].zone) == zid, "maison du zonage")
	_check(am.raison_densif(zh) == "trop récent", "trop récente pour s'agrandir")
	bs.buildings[zh]["fin"] = scene.ambiance.unix_time - 100.0 * 86400.0
	scene.zones._demand_cache = {"R": 100.0, "C": 0.0, "I": 0.0}
	var log := int(scene.population.known[zh].log)
	# Un foyer arrivé entre-temps (arrivées actives dans ce test) remplirait la maison : on la vide.
	var deja: Array = scene.population.by_home.get(zh, [])
	scene.population.by_home[zh] = []
	var r := am.raison_densif(zh)
	_check(r == "logements libres", "vide : %s" % r)
	scene.population.by_home[zh] = deja
	scene.population.by_home[zh] = range(-1, -1 - log, -1)
	scene.nuisances.coef_bat[zh] = 1.0
	_check(am.raison_densif(zh) == "terrain pas assez cher", "terrain moyen : pas d'agrandissement")
	scene.nuisances.coef_bat[zh] = 1.2
	_check(am.raison_densif(zh) == "", "pleine, demandée, terrain qui monte : elle peut s'agrandir")
	var avant := bs.money
	BatimentsVie.chantiers = true
	var n := 0
	for i in 200:
		n += am.densifier()
		if n > 0:
			break
	var ad := am.en_cours(zh)
	_check(n == 1 and not ad.is_empty() and bool(ad.prive) and int(ad.du) == 0, "agrandissement lancé par les propriétaires")
	BatimentsVie.chantiers = false
	am._avancer()
	_check(Ameliorations.niveau(bs.buildings[zh]) == 2 and bs.money == avant, "niveau 2 sans frais pour la ville")
	_check(am.raison_densif(zh) == "trop récent", "pas deux fois de suite")
	scene.population.by_home.erase(zh)

	print("Carte entre amis :")
	var envoye := []
	bs.verrou_reseau = true
	bs.relais = func(act: Dictionary) -> void: envoye.append(act)
	am.agrandir(m)
	am.renover(eco)
	_check(envoye.size() == 2 and String(envoye[0].t) == "ameliorer" and String(envoye[0].op) == "niv" and String(envoye[1].op) == "renov",
		"le client envoie ses demandes au serveur")
	# Le serveur renvoie le bâtiment agrandi.
	bs.buildings[m]["niv"] = 2
	am.depuis_reseau(m, 1)
	_check(Ameliorations.niveau(bs.buildings[m]) == 2 and bs.node_of(m) != null, "niveau reçu du serveur appliqué")
	bs.verrou_reseau = false
	bs.relais = Callable()

	print("Fiche du bâtiment (H) :")
	var hp = scene.habitants_panel
	hp.show_view("batiment", g)
	await process_frame
	var txt := _textes(hp)
	_check(txt.contains("Agrandissement · niveau 2 sur 3") and not txt.contains("Agrandir ·"), "fiche courte : rubrique Agrandissement repliée")
	hp.basculer_rubrique("travaux")
	await process_frame
	txt = _textes(hp)
	_check(txt.contains("Agrandissement · niveau 2 sur 3") and txt.contains("Agrandir ·"), "rubrique dépliée : section Agrandissement et bouton")
	hp.basculer_rubrique("travaux")

	print("Sauvegarde de la partie :")
	var s2: Dictionary = scene.save_sections()
	_check(s2.has("ameliorations") and bool(s2.ameliorations.densification), "section « ameliorations »")

	print("RÉSULTAT : ", "OK" if ok else "ÉCHEC")
	quit(0 if ok else 1)


func _spot(bs: BuildingSystem, id: String, c: Vector2i) -> Vector2i:
	for dist in [0, 60, 90, 120, 160, 200, 250, 300]:
		for i in 16:
			var a := float(i) / 16.0 * TAU
			var q := c + Vector2i(roundi(cos(a) * dist), roundi(sin(a) * dist))
			if bs.check_place(id, q, 0).ok:
				return q
	return c


func _textes(n: Node) -> String:
	var out := ""
	if n is Label:
		out += (n as Label).text + "\n"
	elif n is Button:
		out += (n as Button).text + "\n"
	for c in n.get_children():
		out += _textes(c)
	return out
