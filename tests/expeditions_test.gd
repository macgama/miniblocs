extends SceneTree
## Test des expéditions : données (destinations, objets, spécialistes, événements,
## espèces du zoo), Société des explorateurs (modèle, catalogue, date), préparation
## (qualités, durée selon l'époque, prix, conseils), départ payé, voyage,
## exploration avec événements (choix, chance, le chef décide), retour, butin dans la
## réserve, objet donné à un musée (prestige), cabinet de curiosités (tourisme),
## animaux placés au zoo, spécialistes installés (chantiers, agriculture, musée,
## santé, tourisme), vente, restitution, sauvegarde, panneau et bouton Maj+F4.
## Usage : godot --headless --path . --script res://tests/expeditions_test.gd

var ok := true

## Vendredi 17 juillet 2026, midi (UTC+2).
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
	_donnees_tests()
	await _ville_tests()
	print("TEST OK" if ok else "TEST ÉCHEC")
	quit(0 if ok else 1)


func _donnees_tests() -> void:
	print("Données :")
	_check(ExpeditionsDonnees.DESTINATIONS.size() == ExpeditionsDonnees.DESTINATIONS_ORDRE.size(), "%d destinations, toutes rangées" % ExpeditionsDonnees.DESTINATIONS.size())
	for id in ExpeditionsDonnees.DESTINATIONS:
		var d: Dictionary = ExpeditionsDonnees.DESTINATIONS[id]
		_check(ExpeditionsDonnees.CLIMAT_NOMS.has(String(d.climat)), "%s : climat connu" % id)
		for e in d.faune:
			_check(not ZooEspeces.espece(String(e)).is_empty(), "%s : espèce %s connue du zoo" % [id, e])
		if (d.themes as Array).has("objet"):
			_check(ExpeditionsDonnees.objets_de(String(id)).size() >= 2, "%s : au moins 2 objets à découvrir" % id)
		if (d.themes as Array).has("animal"):
			_check(not (d.faune as Array).is_empty(), "%s : des animaux à ramener" % id)
	var themes_musee := {}
	for k in MuseeObjets.SALLES:
		themes_musee[String(MuseeObjets.SALLES[k].get("theme", ""))] = true
	for id in ExpeditionsDonnees.OBJETS:
		var o: Dictionary = ExpeditionsDonnees.OBJETS[id]
		_check(ExpeditionsDonnees.DESTINATIONS.has(String(o.dest)), "objet %s : destination connue" % id)
		_check(themes_musee.has(String(o.theme)), "objet %s : thème de musée %s connu" % [id, o.theme])
	for id in ExpeditionsDonnees.SPECIALISTES:
		var s: Dictionary = ExpeditionsDonnees.SPECIALISTES[id]
		var dd := String(s.dest)
		_check(dd == "" or ExpeditionsDonnees.DESTINATIONS.has(dd), "spécialiste %s : destination connue" % id)
		for e in s.effets:
			_check(String(e) in ["chantiers", "agriculture", "tourisme", "musee", "sante", "avis", "expeditions"], "spécialiste %s : effet %s lu par le jeu" % [id, e])
	for id in ExpeditionsDonnees.EVENEMENTS:
		var ev: Dictionary = ExpeditionsDonnees.EVENEMENTS[id]
		_check((ev.choix as Array).size() >= 1, "événement %s : des choix" % id)
		for c in ev.choix:
			var q := String((c as Dictionary).get("q", ""))
			_check(q == "" or ExpeditionsDonnees.QUALITES.has(q), "événement %s : qualité %s connue" % [id, q])
	for m in ExpeditionsDonnees.MEMBRES:
		for q in ExpeditionsDonnees.MEMBRES[m].q:
			_check(ExpeditionsDonnees.QUALITES.has(String(q)), "membre %s : qualité %s" % [m, q])
	_check(String(ExpeditionsDonnees.transport(1810)[0]) == "en voilier" and float(ExpeditionsDonnees.transport(2026)[1]) < 0.5, "voilier en 1810, avion aujourd'hui")
	var t := BuildingCatalog.get_type("societe_explorateurs")
	_check(not t.is_empty() and String(t.cat) == "loisirs", "Société des explorateurs dans Construire → Loisirs")
	_check(Epoques.annee_batiment("societe_explorateurs") == 1800, "Société disponible dès 1800")
	var m := BuildingCatalog.build_mesh("societe_explorateurs")
	_check(m != null and m.get_surface_count() > 0 and m.get_aabb().size.y > 12.0, "Société : modèle 3D avec son globe (%d m)" % roundi(m.get_aabb().size.y))
	for j in Metiers.jobs_for("societe_explorateurs"):
		_check(Metiers.METIERS.has(String(j[0])), "métier %s connu" % j[0])
	_check(Icones.has_icon("boussole"), "icône boussole")


func _ville_tests() -> void:
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
	var ex: Expeditions = scene.expeditions
	_check(ex != null and scene.expeditions_panel != null and Expeditions.instance == ex, "expéditions et menu branchés dans la scène")
	_check(scene.save_sections().has("expeditions"), "section « expeditions » dans la sauvegarde")
	var pop: Population = scene.population
	for n in [transport.traffic, scene.tourisme, pop, scene.parc, scene.zoo, scene.musee, scene.spectacles, scene.dechets, scene.production, ex, scene.vie_batiments]:
		n.set_process(false)
	scene.urgences.set_process(false)
	scene.urgences.random_calls = false
	if scene.ambiance.weather != null:
		scene.ambiance.weather.set_process(false)
	scene.ambiance.unix_time = VENDREDI
	bs.unlimited_money = false
	bs.money = 900_000_000
	var y := world.cell_height(Vector2i(0, 0))
	var road := transport.build_segment("route", Vector3(-500, y, 0), Vector3(500, y, 0))
	_check(road.ok, "route de 1 km")

	# Bouton de la barre du bas.
	var hud: TerreHud = scene.hud
	var bouton := false
	for c in hud.CATEGORIES:
		if String(c.id) == "expeditions":
			bouton = String(c.group) == "loisirs" and String(c.key) == "Maj+F4"
	_check(bouton, "bouton Expéditions (Maj+F4) dans le menu Loisirs")
	var panel: ExpeditionsPanel = scene.expeditions_panel
	panel.set_open(false)
	hud._on_category("expeditions")
	_check(panel.is_open(), "le bouton ouvre le menu Expéditions")
	await process_frame
	_check(panel.view == "preparer" and panel._body.get_child_count() >= 2, "sans Société : le menu propose de la construire")
	panel.set_open(false)

	# Société, musée, zoo.
	var c0 := Vector2i(-200, -14)
	var soc := bs.place("societe_explorateurs", c0, bs.best_rotation("societe_explorateurs", c0))
	_check(soc > 0, "Société des explorateurs posée au bord de la route")
	var c1 := Vector2i(100, -20)
	var mus := bs.place("musee", c1, bs.best_rotation("musee", c1))
	_check(mus > 0, "musée posé")
	scene.musee._dirty = true
	var key := "bat_%d" % mus
	_check(scene.musee.list().has(key), "le musée est géré")
	var zoo: ZooSysteme = scene.zoo
	var c2 := Vector2i(300, -14)
	var entree := bs.place("entree_zoo", c2, bs.best_rotation("entree_zoo", c2))
	zoo.ignore_staff = true
	zoo._sync()
	var enc := zoo.ajouter_enclos(PackedVector2Array([Vector2(270, -60), Vector2(330, -60), Vector2(330, -120), Vector2(270, -120)]), "grillage")
	_check(entree > 0 and enc > 0, "zoo et enclos")
	_check(ex.societes() == [soc] and ex.societe_libre() == soc, "la Société est prête")

	# Préparation.
	ex.rng.seed = 7
	ex.last_day = ex.jour()
	var libres := ex.chefs_libres()
	_check(libres.size() == 3, "3 chefs proposés")
	var plan := {"dest": "nil", "chef": int(libres[0]), "membres": {"guide": 1, "medecin": 1, "archeologue": 1, "naturaliste": 1, "porteur": 2},
		"provisions": ["tropiques", "cages", "fouilles"], "auto": true}
	var q := ex.qualites(plan)
	_check(int(q.orientation) >= 4 and int(q.savoir) >= 6 and int(q.medecine) >= 5, "qualités : orientation %d, savoir %d, médecine %d" % [int(q.orientation), int(q.savoir), int(q.medecine)])
	var du := ex.durees(plan)
	_check(int(du.aller) < 12 and int(du.total) == int(du.aller) * 2 + 16, "voyage en avion : %d jours, %d au total" % [int(du.aller), int(du.total)])
	var pr := ex.prix(plan)
	_check(int(pr.total) > 120_000 and int(pr.total) < 2_000_000, "prix : %s" % BuildingSystem.format_money(int(pr.total)))
	_check(ex.avertissements(plan).is_empty(), "équipe bien préparée : aucun avertissement")
	var mal := {"dest": "arctique", "chef": int(libres[0]), "membres": {"guide": 1}, "provisions": []}
	var av := ex.avertissements(mal)
	_check(av.size() >= 2, "équipe mal préparée pour le Grand Nord : %d conseils" % av.size())
	_check(ex.partir(soc, {"dest": "nil", "chef": int(libres[0]), "membres": {"porteur": 12}}) != "", "équipe trop nombreuse refusée")

	var caisse0 := bs.money
	var r := ex.partir(soc, plan)
	_check(r == "", "départ pour la vallée du Nil (%s)" % r)
	_check(caisse0 - bs.money >= int(pr.total) - 10, "l'expédition est payée au départ (%s)" % BuildingSystem.format_money(caisse0 - bs.money))
	_check(ex.expedition_de(soc) > 0 and ex.societe_libre() == -1, "la Société est occupée")
	_check(ex.partir(soc, plan) != "", "une seule expédition à la fois par Société")
	var id := ex.expedition_de(soc)
	var x: Dictionary = ex.expeditions[id]
	_check(String(x.etat) == "aller", "en route")
	ex.avancer(int(du.aller))
	_check(String(x.etat) == "exploration", "arrivée : l'exploration commence")
	# Un événement à choix, résolu à la main.
	x.auto = false
	ex._tirer_evenement(x, ExpeditionsDonnees.destination("nil"), ex.last_day)
	_check(not (x.evenement as Dictionary).is_empty(), "un événement attend une décision")
	var ch := ex.chance(id, 0)
	_check(ch >= 0.1 and ch <= 1.0, "chance de réussite affichée (%d %%)" % roundi(ch * 100.0))
	var best := ex.meilleur_choix(id)
	_check(best >= 0, "le chef sait ce qu'il ferait (choix %d)" % best)
	panel.view = "cours"
	panel.set_open(true)
	panel.refresh()
	await process_frame
	_check(panel._body.get_child_count() > 8, "onglet En cours : carte de l'expédition et choix (%d lignes)" % panel._body.get_child_count())
	var res := ex.choisir(id, best)
	_check(res != "" and (x.evenement as Dictionary).is_empty(), "choix fait : %s" % res)
	# Sans réponse, le chef décide au bout de 2 jours.
	ex._tirer_evenement(x, ExpeditionsDonnees.destination("nil"), ex.last_day)
	if not (x.evenement as Dictionary).is_empty():
		ex.avancer(Expeditions.DELAI_CHOIX)
		_check((x.evenement as Dictionary).is_empty() or String(x.etat) != "exploration", "sans réponse, le chef a décidé")
	x.auto = true
	# Trouvailles garanties pour la suite du test.
	_check(ex._gagner(x, "objet"), "trouvaille : un objet rare")
	_check(ex._gagner(x, "animal"), "trouvaille : un couple d'animaux")
	_check(ex._gagner(x, "specialiste"), "rencontre : un spécialiste")
	var tours := 0
	while String(x.etat) != "finie" and tours < 200:
		ex.avancer(1)
		tours += 1
	_check(String(x.etat) == "finie", "retour au pays après %d jours (%s)" % [tours, String(x.issue)])
	_check(ex.chefs_libres().has(int(plan.chef)), "le chef est de nouveau libre")
	_check(ex.renommee > 0.0 and not ex.recits.is_empty(), "renommée %d et récit dans la gazette" % roundi(ex.renommee))
	var n_obj := (x.butin.objets as Array).size()
	_check(ex.objets_en("reserve").size() == n_obj and n_obj >= 1, "%d objet(s) dans la réserve" % n_obj)
	_check(ex.animaux.size() >= 2, "%d animaux attendent un enclos" % ex.animaux.size())
	_check(ex.specialistes.size() >= 1, "%d spécialiste(s) rapporté(s)" % ex.specialistes.size())
	var journal_ok := false
	for nn in scene.evenements.journal:
		if String(nn.genre) == "expeditions":
			journal_ok = true
	_check(journal_ok, "les expéditions passent au fil d'actualité")

	# Objet donné au musée.
	var oid := String(ex.objets_en("reserve")[0])
	scene.musee._cache.clear()
	var p0 := float(scene.musee.analyse(key).prestige)
	_check(ex.donner_musee(oid, key) == "", "objet donné au musée")
	var p1 := float(scene.musee.analyse(key).prestige)
	_check(p1 > p0 + 10.0, "prestige du musée : %d → %d" % [roundi(p0), roundi(p1)])
	# Cabinet de curiosités : un site touristique.
	_check(ex.exposer(oid) == "" and String(ex.objets[oid].lieu) == "cabinet", "objet exposé au cabinet de curiosités")
	scene.musee._cache.clear()
	_check(float(scene.musee.analyse(key).prestige) < p1, "le musée ne le compte plus")
	var sites := ex.sites_tourisme()
	_check(sites.size() == 1 and float(sites[0].pts) > 0.0, "le cabinet attire les touristes (%.2f points)" % float(sites[0].pts))
	scene.tourisme._maj_sites()
	var vu := false
	for s in scene.tourisme.sites:
		if String(s.kind) == "expeditions":
			vu = true
	_check(vu, "le tourisme compte le cabinet de curiosités")

	# Animaux placés au zoo.
	var nb0 := zoo.animaux_de(enc).size()
	_check(ex.placer_animal(0, enc) == "", "un animal rejoint l'enclos")
	_check(zoo.animaux_de(enc).size() == nb0 + 1, "il est bien au zoo")
	ex.animaux.append((ex.animaux[0] as Dictionary).duplicate())
	var arr0 := zoo.arrivees.size()
	_check(ex.placer_animal(ex.animaux.size() - 1, -1) == "" and zoo.arrivees.size() == arr0 + 1, "un autre attend un enclos dans l'onglet Échanges du zoo")
	var rid := int(zoo.arrivees.keys()[-1])
	_check(String(zoo.arrivees[rid].origine) == "sauvage", "il arrive né sauvage (gènes neufs)")
	var caisse1 := bs.money
	_check(ex.confier_animal(0) == "" and bs.money > caisse1, "l'autre est confié à un zoo voisin")

	# Spécialistes.
	ex.specialistes["ingenieure_ponts"] = {"ville": -1, "jour": 0}
	ex.specialistes["agronome"] = {"ville": -1, "jour": 0}
	ex.specialistes["conservatrice"] = {"ville": -1, "jour": 0}
	ex.specialistes["medecin_tropiques"] = {"ville": -1, "jour": 0}
	_check(is_equal_approx(Expeditions.rythme_chantier(soc), 1.0), "en réserve, un spécialiste n'a pas d'effet")
	var v0 := int(ex.villes()[0][0])
	_check(ex.affecter("ingenieure_ponts", v0) == "", "l'ingénieure s'installe en ville")
	_check(Expeditions.rythme_chantier(soc) > 1.1, "chantiers plus rapides (×%.2f)" % Expeditions.rythme_chantier(soc))
	_check(ex.affecter("agronome", v0) == "" and Expeditions.facteur("agriculture") > 0.1, "récoltes +12 %")
	scene.musee._cache.clear()
	var p2 := float(scene.musee.analyse(key).prestige)
	_check(ex.affecter("conservatrice", v0) == "", "la conservatrice s'installe")
	_check(float(scene.musee.analyse(key).prestige) > p2 * 1.15, "prestige des musées +20 %")
	_check(ex.affecter("medecin_tropiques", v0) != "", "pas plus de 3 spécialistes par ville")
	_check(ex.risque_sante(soc) <= 0.0, "les médecins réduisent les risques pour la santé")
	ex.affecter("agronome", -1)
	_check(ex.affecter("medecin_tropiques", v0) == "" and ex.risque_sante(soc) < -0.05, "le médecin des tropiques prend la place de l'agronome")

	# Vente et restitution.
	var x2 := {"butin": {"objets": [], "animaux": [], "specialistes": []}, "dest": "yucatan", "membres": {"archeologue": 1}, "provisions": [], "r": 0.0, "annee": 2026, "log": []}
	ex._gagner(x2, "objet")
	ex._gagner(x2, "objet")
	for o in x2.butin.objets:
		ex.objets[String(o)] = {"lieu": "reserve", "musee": "", "soc": soc, "jour": 0}
	var ventes := ex.objets_en("reserve")
	_check(ventes.size() >= 2, "deux objets du Yucatán")
	var caisse2 := bs.money
	_check(ex.vendre(String(ventes[0])) == "" and bs.money > caisse2, "vendu aux enchères (%s)" % BuildingSystem.format_money(bs.money - caisse2))
	var ren0 := ex.renommee
	_check(ex.rendre(String(ventes[1])) == "" and ex.renommee > ren0, "rendu à son pays d'origine : renommée +%d" % roundi(ex.renommee - ren0))
	_check(ex.vendre(String(ventes[1])) != "", "un objet rendu ne se vend plus")

	# Une expédition qui tourne mal : moral à zéro.
	var libres2 := ex.chefs_libres()
	_check(ex.partir(soc, {"dest": "antarctique", "chef": int(libres2[0]), "membres": {"porteur": 1}, "provisions": [], "auto": true}) == "", "départ mal préparé pour l'Antarctique")
	var id2 := ex.expedition_de(soc)
	var x3: Dictionary = ex.expeditions[id2]
	var t2 := 0
	while String(x3.etat) != "finie" and t2 < 300:
		ex.avancer(1)
		t2 += 1
	_check(String(x3.etat) == "finie" and String(x3.issue) in ["rapatriee", "abandon", "bredouille", "reussie"], "l'expédition rentre : %s" % String(x3.issue))
	_check(String(x3.issue) != "reussie" or int(x3.perdus) > 0, "sans matériel grand froid, elle a souffert (%d membre(s) rentrés)" % int(x3.perdus))

	# Sauvegarde.
	var d := ex.to_dict()
	var json: Variant = JSON.parse_string(JSON.stringify(d))
	var ex2 := Expeditions.new()
	ex2.from_dict(json)
	_check(ex2.objets.size() == ex.objets.size() and ex2.specialistes.size() == ex.specialistes.size() and ex2.expeditions.size() == ex.expeditions.size(), "sauvegarde relue : objets, spécialistes, expéditions")
	_check(int(ex2.specialistes["ingenieure_ponts"].ville) == v0 and is_equal_approx(ex2.renommee, ex.renommee), "affectations et renommée gardées")
	_check(int(ex2.chefs[0].faites) == int(ex.chefs[0].faites), "les chefs gardent leur expérience")
	ex2.free()

	# Onglets du panneau.
	for v in ["cours", "preparer", "reserve", "recits"]:
		panel.show_view(v)
		await process_frame
		_check(panel._body.get_child_count() > 1, "onglet %s rempli (%d lignes)" % [v, panel._body.get_child_count()])
	scene.queue_free()
	await process_frame
