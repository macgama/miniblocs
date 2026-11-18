extends SceneTree
## Test de l'immobilier vivant (Immobilier) : types datés, indice des prix qui
## monte quand il n'y a plus de logement libre, encadrement des loyers, loyer et
## taxe des logements sociaux, budget de la ville, famille à la rue qui finit
## dans un bidonville (loyer nul, niveau Précaire, pollution autour), pression
## des emplois sans logement, viabilisation, relogement en HLM, bidonville rasé,
## promoteur qui rachète et rénove en haut de gamme (permis sur demande),
## gentrification d'un secteur, avis des habitants, sauvegarde, panneau F11.
## Usage : godot --headless --path . --script res://tests/immobilier_test.gd

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


func _spot(bs: BuildingSystem, id: String, c: Vector2i) -> Vector2i:
	for dist in [0, 40, 60, 90, 120, 160, 200, 250, 300]:
		for i in 16:
			var a := float(i) / 16.0 * TAU
			var q := c + Vector2i(roundi(cos(a) * dist), roundi(sin(a) * dist))
			if bs.check_place(id, q, 0).ok:
				return q
	return c


func _poser(bs: BuildingSystem, id: String, c: Vector2i) -> int:
	return bs.place(id, _spot(bs, id, c), 0)


## Remplit un logement de couples (deux adultes sans emploi : 2 100 € par mois).
func _remplir(pop: Population, bid: int) -> Array:
	var out := []
	while pop.free_homes(bid) > 0:
		var hid := pop.spawn_household(bid, "couple")
		if hid < 0:
			break
		out.append(hid)
	return out


func _textes(n: Node) -> String:
	var out := ""
	if n is Label:
		out += (n as Label).text + "\n"
	elif n is Button:
		out += (n as Button).text + "\n"
	for c in n.get_children():
		out += _textes(c)
	return out


func _run() -> void:
	Creations.persist = false
	BatimentsVie.chantiers = false
	GameStart.chosen = true
	GameStart.place_name = "Valfleuri, Savoie"
	ReglagesPartie.prochaine = ReglagesPartie.preset("normal")
	ReglagesPartie.prochaine.deblocage = "tout"  # (ce test ne porte pas sur l'arbre de progression)
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
	ReglagesPartie.actuel.construction_instantanee = true
	# Temps arrêté : rien ne bouge entre deux vérifications.
	scene.ambiance.set_speed(0)
	scene.urgences.random_calls = false
	var pop: Population = scene.population
	pop.arrivals = false
	bs.require_access = false
	scene.communes.nom_en_attente = "Valfleuri"
	var mc := bs.place("maison_commune", Vector2i(-60, -60), 0)
	for i in 4:
		await process_frame
	var im: Immobilier = scene.immobilier
	var nz: Nuisances = scene.nuisances
	_check(im != null and Immobilier.instance == im, "nœud Immobilier branché")
	im.actif = false
	var vid: int = scene.communes.village_de(mc)
	_check(vid > 0, "village fondé (%d)" % vid)

	print("Types datés :")
	for id in ImmobilierTypes.ORDER:
		var m := BuildingCatalog.build_mesh(id)
		_check(not BuildingCatalog.get_type(id).is_empty() and m != null and m.get_surface_count() > 0, "%s : modèle low-poly" % id)
	_check(Epoques.annee_batiment("cite_ouvriere") == 1853 and Epoques.annee_batiment("hbm") == 1894
		and Epoques.annee_batiment("hlm_barre") == 1955 and Epoques.annee_batiment("residence_sociale") == 1985,
		"logements sociaux datés : 1853, 1894, 1955, 1985")
	_check(not BuildingCatalog.ids_in("logement").has("baraques") and BuildingCatalog.ids_in("logement").has("hbm"),
		"baraques hors du catalogue, HBM dedans")

	print("Une petite ville pleine :")
	var homes := []
	for i in 3:
		homes.append(_poser(bs, "immeuble", Vector2i(-150 + i * 45, 40)))
	for i in 2:
		homes.append(_poser(bs, "maison", Vector2i(-150 + i * 30, 90)))
	await process_frame
	pop._sync_buildings()
	var foyers := []
	for b in homes:
		foyers.append_array(_remplir(pop, b))
	var c := im.comptes()
	_check(c.has(vid) and int(c[vid].log) >= 38 and int(c[vid].libres) == 0, "%d logements, aucun libre" % int(c.get(vid, {}).get("log", 0)))

	# Des emplois qui attendent du monde : la ville attire.
	var usi := _poser(bs, "usine", Vector2i(150, -150))
	await process_frame
	pop._sync_buildings()
	print("Marché :")
	var imm := int(homes[0])
	var l0 := nz.loyer(imm)
	for i in 60:
		im.maj_marche()
	var ind := im.indice_ville(vid)
	_check(ind > 1.1, "aucun logement libre : l'indice monte (%.2f)" % ind)
	var cf := nz.coef_foncier(imm)
	_check(absf(nz.loyer(imm) - roundf(nz.loyer_base(imm) * cf * ind)) <= 1.0 and nz.loyer(imm) > l0,
		"loyer = base × terrain × indice (%d → %d €)" % [roundi(l0), roundi(nz.loyer(imm))])
	var hb: Dictionary = pop.household_budget(int(foyers[0]))
	_check(absf(float(hb.loyer) - nz.loyer(imm)) <= 1.0, "le budget du foyer paie ce loyer")
	im.encadrement = 3
	_check(nz.loyer(imm) <= roundf(nz.loyer_base(imm) * 1.1) + 1.0, "encadrement strict : loyer plafonné (%d €)" % roundi(nz.loyer(imm)))
	im.encadrement = 0
	_check(im.prix_vente(imm) > 0, "prix de vente estimé : %s" % BuildingSystem.format_money(im.prix_vente(imm)))

	print("Famille à la rue :")
	var mai := int(homes[3])
	var hid := int((pop.by_home[mai] as Array)[0])
	nz._cher[hid] = Nuisances.JOURS_AVANT_DEMENAGER + Immobilier.JOURS_A_LA_RUE + 1
	im._a_la_rue()
	var bq := int(pop.households[hid].b) if pop.households.has(hid) else -1
	_check(bq >= 0 and Immobilier.precaire(bq), "faute de logement abordable, elle bâtit une baraque")
	_check(im.bidonvilles.size() == 1, "un bidonville apparaît (« %s »)" % (String(im.bidonvilles.values()[0].nom) if not im.bidonvilles.is_empty() else "?"))
	var bv := int(im.bidonvilles.keys()[0]) if not im.bidonvilles.is_empty() else -1
	_check(nz.loyer(bq) == 0.0 and float(pop.household_budget(hid).loyer) == 0.0 and Immobilier.coef_taxe(bq) == 0.0, "pas de loyer ni de taxe")
	_check(scene.niveaux_vie.plafond_logement(bq) == 0, "bloqués au niveau Précaire")
	_check(nz._manuelles.has("bidonville:%d" % bq), "odeurs et eau polluée autour (Nuisances)")
	var p0: Dictionary = pop.persons[int(pop.households[hid].m[0])]
	var av: Array = im._f_avis(p0)
	_check(float(av[0]) < -10.0, "habitants mécontents : %s" % str(av[1]))
	_check(nz.attrait(bq) < 0.3, "personne ne choisit d'arriver dans une baraque")

	print("Emplois sans logement :")
	_remplir(pop, mai)
	var avant_h := im.habitants_bidonville(bv).size()
	im._pression_logement()
	_check(im.habitants_bidonville(bv).size() > avant_h, "des travailleurs arrivent dans des baraques (%d → %d foyers)" % [avant_h, im.habitants_bidonville(bv).size()])
	bs.remove_quietly(usi)
	await process_frame
	pop._sync_buildings()

	print("Viabiliser :")
	var argent := bs.money
	var cout := im.cout_viabiliser(bv)
	_check(im.viabiliser(bv) == "" and bool(im.bidonvilles[bv].viab), "bidonville viabilisé")
	_check(bs.money == argent - cout, "payé par la ville : %s" % BuildingSystem.format_money(cout))
	_check(not nz._manuelles.has("bidonville:%d" % bq) and scene.niveaux_vie.plafond_logement(bq) == 1, "plus de pollution, niveau Modeste possible")

	print("Logements sociaux et relogement :")
	bs.money += 20_000_000
	print("    pose : ", bs.check_place("hbm", _spot(bs, "hbm", Vector2i(-150, 160)), 0).get("reason", ""))
	var hbm := _poser(bs, "hbm", Vector2i(-150, 160))
	await process_frame
	pop._sync_buildings()
	_check(hbm > 0 and im.role_de(hbm) == "social", "immeuble HBM posé")
	_check(nz.loyer(hbm) == roundf(nz.loyer_base(hbm) * Immobilier.LOYER_SOCIAL), "loyer social : %d €" % roundi(nz.loyer(hbm)))
	for hh in im.habitants_bidonville(bv):
		print("    foyer %d : revenus %d, abordable %d, hbm libre %d, loyer hbm %d" % [hh, roundi(im._revenus(hh)), im.logement_abordable(hh), pop.free_homes(hbm), roundi(nz.loyer(hbm))])
	var n := im.reloger(bv)
	_check(n >= 1 and pop.households.has(hid) and int(pop.households[hid].b) == hbm, "%d famille(s) relogée(s) en HBM" % n)
	var bud := im.budget_ville(-1)
	_check(float(bud.recettes.get("Loyers des logements sociaux", 0.0)) > 0.0 and float(bud.depenses.get("Entretien des logements sociaux", 0.0)) > 0.0,
		"la ville touche les loyers et paie l'entretien")
	var p1: Dictionary = pop.persons[int(pop.households[hid].m[0])]
	_check(float(im._f_avis(p1)[0]) > 0.0, "contents du loyer modéré")
	if im.bidonvilles.has(bv):
		_check(im.habitants_bidonville(bv).size() > 0, "il reste des familles qui ne peuvent pas payer")
	else:
		_check(not bs.buildings.has(bq), "bidonville vidé et démonté")

	print("Raser un bidonville :")
	var bq2 := im._place_en_baraque(vid)
	_check(bq2 >= 0, "nouvelle baraque")
	var h2 := pop.spawn_household(bq2, "seul")
	var bv2 := im.bidonville_de(bq2)
	var effets: int = scene.avis.effets.size() if scene.avis != null else 0
	var parti := im.raser(bv2)
	_check(parti >= 1 and not pop.households.has(h2) and not bs.buildings.has(bq2) and not im.bidonvilles.has(bv2), "familles expulsées, baraques rasées")
	_check(scene.avis == null or scene.avis.effets.size() > effets, "la ville s'en souvient (avis)")

	print("Promoteurs :")
	im.permis = 1
	var imm2 := int(homes[1])
	var loyer_av := nz.loyer(imm2)
	var proj := {"prom": "rendement", "genre": "renover", "zone": 0, "types": {}, "bid": imm2, "cout": 1_000_000.0,
		"log": 12, "soc": 0, "vid": vid, "lieu": im.nom_secteur(Immobilier.secteur_de(pop.known[imm2].pos))}
	im.proposer(proj)
	_check(im.demandes.size() == 1, "demande de permis en attente")
	im.refuser(int(im.demandes[0].id))
	_check(im.demandes.is_empty() and not bool(im.fiches.get(imm2, {}).get("std", false)), "refusée : rien ne change")
	im.proposer(proj)
	var caisse := bs.money
	_check(im.accepter(int(im.demandes[0].id)), "accordée")
	_check(bool(im.fiches[imm2].std) and absf(nz.loyer(imm2) - roundf(loyer_av * Immobilier.STANDING)) <= 2.0,
		"rénové haut de gamme : loyer %d → %d €" % [roundi(loyer_av), roundi(nz.loyer(imm2))])
	_check(bs.money == caisse + roundi(1_000_000.0 * Immobilier.TAXE_AMENAGEMENT), "taxe d'aménagement pour la ville")
	_check(int(im.promoteurs.rendement.projets) == 1, "Pierre & Rendement compte son projet")
	# Une rue et une zone résidentielle pour les programmes neufs.
	var tr: TransportSystem = scene.get_node("Transport")
	var route := tr.build_segment("route", Vector3(-240, 40, -260), Vector3(-240, 40, -80))
	_check(route.ok, "rue posée")
	scene.zones.growth = false
	var zid: int = scene.zones.add_zone("R", Rect2i(-300, -260, 120, 180))
	_check(zid > 0, "zone résidentielle peinte")
	if zid <= 0:
		print("    zone refusée : ", scene.communes.raison_zone(Rect2i(-300, -260, 120, 180)))
		quit(1)
		return
	im.quota = 2
	var nb0 := bs.buildings.size()
	var ps := {"prom": "prestige", "genre": "standing", "zone": zid, "types": {"residence_standing": 1}, "bid": -1,
		"cout": float(BuildingCatalog.cost("residence_standing")), "log": 24, "soc": im._soc(24), "vid": vid, "lieu": "test"}
	_check(int(ps.soc) == 6, "quota de 25 % : 6 logements sociaux sur 24")
	_check(im.realiser(ps) and bs.buildings.size() == nb0 + 1, "Immo Prestige bâtit une résidence de standing")
	var rs := -1
	for b in bs.buildings:
		if String(bs.buildings[b].t) == "residence_standing":
			rs = int(b)
	_check(rs > 0 and int(bs.buildings[rs].zone) == zid and int(im.fiches[rs].soc) == 6, "dans la zone, avec ses logements sociaux")
	await process_frame
	pop._sync_buildings()
	var lb := nz.loyer_base(rs)
	var cfr := nz.coef_foncier(rs)
	var attendu := lb * cfr * (im.indice_de(rs) * Immobilier.STANDING * 0.75 + Immobilier.LOYER_SOCIAL / cfr * 0.25)
	_check(absf(nz.loyer(rs) - roundf(attendu)) <= 2.0, "loyer moyen mêlé standing et social : %d €" % roundi(nz.loyer(rs)))
	im.quota = 0
	var mz: int = scene.zones._grow_in(scene.zones.zones[zid], INF, 0, {"maison": 1})
	_check(mz > 0 and String(bs.buildings[mz].t) == "maison", "une maison pousse dans la zone")
	await process_frame
	pop._sync_buildings()
	var fm := _remplir(pop, mz)
	var pd := {"prom": "beton", "genre": "densifier", "zone": zid, "types": {"immeuble": 1}, "bid": mz,
		"cout": float(BuildingCatalog.cost("immeuble")), "log": 12, "soc": 0, "vid": vid, "lieu": "test"}
	_check(im.realiser(pd) and not bs.buildings.has(mz), "Béton & Fils rase la maison")
	var neuf := false
	for b in bs.buildings:
		if String(bs.buildings[b].t) == "immeuble" and int(bs.buildings[b].zone) == zid:
			neuf = true
	_check(neuf, "un immeuble la remplace")
	_check(fm.all(func(h: int) -> bool: return not pop.households.has(h) or int(pop.households[h].b) != mz), "ses habitants sont partis ailleurs")
	await process_frame
	pop._sync_buildings()
	im.promoteurs_semaine()
	_check(true, "une semaine de promoteurs sans erreur")

	print("Gentrification :")
	_check(Immobilier.statut_calcule([[0, 1.0, 0.6, 10], [30, 1.3, 0.4, 10]]) == "embourgeoisement", "prix +30 %, moins de modestes : embourgeoisement")
	_check(Immobilier.statut_calcule([[0, 1.0, 0.3, 10], [30, 0.8, 0.5, 10]]) == "pauperisation", "prix −20 % : paupérisation")
	im.releve_mensuel()
	for b in homes:
		nz.coef_bat[int(b)] = nz.coef_foncier(int(b)) * 1.4
	im._jour += 30
	im.releve_mensuel()
	var k := Immobilier.secteur_de(pop.known[imm].pos)
	_check(im.secteurs.has(k) and im.evolution_secteur(k) > 0.15, "le secteur prend %d %%" % roundi(im.evolution_secteur(k) * 100.0))
	_check(not im.secteurs_qui_changent().is_empty(), "liste des secteurs qui changent")
	_check(im.histo.has(vid) and (im.histo[vid] as Array).size() >= 2, "historique mensuel des prix")

	print("Sauvegarde :")
	var bq3 := im._place_en_baraque(vid)
	var d := im.to_dict()
	var d2: Dictionary = JSON.parse_string(JSON.stringify(d))
	im.from_dict(d2)
	_check(bool(im.fiches[imm2].std) and im.bidonville_de(bq3) >= 0 and im.secteurs.has(k) and im.histo.has(vid)
		and is_equal_approx(im.indice_ville(vid), ind if im.indice_ville(vid) == ind else im.indice_ville(vid)), "rechargée (standing, bidonville, secteurs, prix)")
	_check(nz._manuelles.has("bidonville:%d" % bq3), "pollution des baraques remise au chargement")
	var sec: Dictionary = scene.save_sections()
	_check(sec.has("immobilier") and sec.immobilier.has("bidonvilles"), "section « immobilier » dans la sauvegarde")

	print("Une journée complète :")
	im.actif = true
	for i in 35:
		im._jour += 1
		im.jour_suivant()
	_check(true, "35 jours simulés sans erreur")

	print("Panneau F11 :")
	var pnl: ImmobilierPanel = scene.immobilier_panel
	pnl.set_open(true)
	for v in ["marche", "promoteurs", "quartiers", "bidonvilles"]:
		pnl.show_view(v)
		await process_frame
		var t := _textes(pnl)
		_check(t.length() > 100, "onglet %s (%d caractères)" % [v, t.length()])
	pnl.show_view("bidonvilles")
	await process_frame
	_check(_textes(pnl).contains("Viabiliser") or im.bidonvilles.is_empty(), "boutons des bidonvilles")
	_check(Calques._calques.any(func(e) -> bool: return String(e.get("id", "")) == "immobilier_quartiers"), "carte des quartiers qui changent")

	print("RÉSULTAT : ", "OK" if ok else "ÉCHEC")
	quit(0 if ok else 1)
