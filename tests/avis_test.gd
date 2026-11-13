extends SceneTree
## Test de l'avis des habitants : satisfaction par thème, facteurs des autres
## systèmes (groupe « avis_sources »), sondage, quartiers, paroles, élections
## (campagne, promesses, vote, 2e tour, défaite), manifestations (cortège,
## rue fermée, négocier, ignorer et grève, police), sauvegarde, panneau Avis.
## Usage : godot --headless --path . --script res://tests/avis_test.gd

var ok := true


class SourceTest extends Node:
	var env := 0.0
	var impots := 0.0

	func avis_facteurs() -> Array:
		return [{"id": "test_env", "theme": "environnement", "f": func(_p: Dictionary) -> Array:
					return [env, ["− pollution de test"] if env < 0.0 else []]},
			{"id": "test_impots", "theme": "impots", "ville": true, "f": func() -> Array:
					return [impots, ["− impôts de test trop lourds"] if impots < 0.0 else []]}]


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


## Heure locale de Paris (UTC+1 en mars) → instant Unix.
func _at(date: String, hour: float) -> float:
	return Time.get_unix_time_from_datetime_string(date + "T00:00:00") + (hour - 1.0) * 3600.0


## Fait passer le temps heure par heure (habitants, événements, avis).
func _hours(scene: Node, n: int, step := 3600.0) -> void:
	var amb: DayNight = scene.get_node("Ambiance")
	for i in n:
		amb.unix_time += step
		scene.population._process(0.016)
		scene.evenements._process(0.016)
		scene.avis._process(0.016)


## Pose un bâtiment le long de la route nord-sud (x = 0), à partir de z0.
func _put(bs: BuildingSystem, id: String, z0: int) -> int:
	for z in range(z0, 300, 6):
		for side in [1, -1]:
			for r in 4:
				var fp := BuildingCatalog.footprint(id, r)
				for gap in [3, 6, 9]:
					var x: int = int(side) * (fp.x / 2 + gap)
					if bs.check_place(id, Vector2i(x, z), r).ok:
						return bs.place(id, Vector2i(x, z), r)
	return -1


func _run() -> void:
	Creations.persist = false
	BatimentsVie.chantiers = false
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var amb: DayNight = scene.get_node("Ambiance")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.set_origin(48.8584, 2.2945)
	for i in 60:
		await process_frame
	var pop: Population = scene.population
	var avis: Avis = scene.avis
	var ev: Evenements = scene.evenements
	_check(avis != null and Avis.instance == avis, "Avis branché (Avis.instance)")
	_check(root.get_node_or_null("Avis") == avis, "nœud /root/Avis pour les autres systèmes")
	ev.forcer_auto = 0
	ev.forcer_catastrophes = 0
	avis.manifs.forcer = 0
	avis.elections.forcer_mode = "objectifs"
	amb.set_speed(0)
	amb.unix_time = _at("2026-03-10", 10.0) # un mardi

	print("Une petite ville :")
	bs.unlimited_money = true
	var y := world.cell_height(Vector2i(0, 0))
	_check(transport.build_segment("route", Vector3(0, y, -300), Vector3(0, y, 300)).ok, "route")
	var school := bs.place("ecole", Vector2i(-30, 0), 1)
	var homes := []
	for i in 6:
		homes.append(bs.place("immeuble", Vector2i(16, -150 + i * 22), 3))
	for i in 4:
		homes.append(bs.place("maison", Vector2i(-12, -150 + i * 16), 1))
	var office := bs.place("bureaux", Vector2i(20, 80), 3)
	var mairie := bs.place("mairie", Vector2i(-24, 160), 1)
	_check(school > 0 and office > 0 and mairie > 0 and not homes.has(-1), "école, logements, bureaux, mairie")
	pop._sync_buildings()
	for i in 72:
		pop.advance(300.0)
	_check(pop.persons.size() >= 30, "%d habitants" % pop.persons.size())
	_check(avis.mairie() == mairie, "la mairie est trouvée")

	print("Satisfaction par thème :")
	var p0: Dictionary = pop.persons[pop.persons.keys()[0]]
	var s0 := pop.satisfaction(p0)
	_check(s0.has("themes") and not (s0.themes as Dictionary).is_empty(), "Population.satisfaction rend les thèmes : %s" % str(s0.themes))
	var sd := avis.sondage(true)
	_check(int(sd.n) > 0 and int(sd.valeur) > 0 and int(sd.valeur) <= 100, "sondage : %d / 100 sur %d habitants" % [int(sd.valeur), int(sd.n)])
	_check((sd.themes as Dictionary).has("emploi"), "thème emploi noté %d" % int(sd.themes.get("emploi", {}).get("note", -1)))
	_check(not (sd.quartiers as Array).is_empty() and String(sd.quartiers[0].nom) != "", "quartiers : %s" % ", ".join((sd.quartiers as Array).map(func(q) -> String: return "%s %d" % [q.nom, q.valeur])))
	_check(not (sd.logements as Dictionary).is_empty(), "satisfaction par logement (%d logements)" % (sd.logements as Dictionary).size())

	print("Facteurs des autres systèmes :")
	var src := SourceTest.new()
	src.add_to_group("avis_sources")
	scene.add_child(src)
	src.env = -12.0
	src.impots = -6.0
	avis._sources_ms = -100000
	avis._ville_ms = -100000
	var s1 := pop.satisfaction(p0)
	_check(int(s1.value) < int(s0.value) or int(s0.value) == 0, "les facteurs baissent la satisfaction (%d → %d)" % [int(s0.value), int(s1.value)])
	_check(float(s1.themes.get("environnement", 0.0)) <= -12.0 and float(s1.themes.get("impots", 0.0)) <= -6.0, "thèmes environnement et impôts remplis")
	_check((s1.why as Array).has("− pollution de test") and (s1.why as Array).has("− impôts de test trop lourds"), "les raisons des sources sont dans la fiche")
	sd = avis.sondage(true)
	_check(int(sd.themes.environnement.note) < 30, "note environnement : %d / 100" % int(sd.themes.environnement.note))
	var raisons_env: Array = sd.themes.environnement.raisons
	_check(not raisons_env.is_empty() and String(raisons_env[0][0]) == "− pollution de test", "le motif est rangé dans son thème")
	avis.facteur("direct", "reseaux", func(_p: Dictionary) -> Array: return [-3.0, ["− coupure de test"]])
	_check(float(pop.satisfaction(p0).themes.get("reseaux", 0.0)) <= -3.0, "Avis.facteur() direct")
	avis.retirer("direct")
	var par := avis.paroles(6)
	_check(not par.is_empty() and String(par[0].phrase) != "", "paroles d'habitants : « %s » (%s)" % [par[0].phrase if not par.is_empty() else "", par[0].nom if not par.is_empty() else ""])

	print("Élections :")
	src.env = 0.0
	src.impots = 0.0
	avis._ville_ms = -100000
	var el := avis.elections
	_hours(scene, 24)
	_check(el.etat == "mandat" and el.joueur_maire(), "dès %d habitants, le joueur est maire" % Elections.MIN_HABITANTS)
	_check(el.jours_avant_vote() >= Elections.MANDAT_MIN_JOURS - 7, "prochain vote dans %d jours" % el.jours_avant_vote())
	_check(el.jour_semaine(el.vote_jour) == 0, "le vote tombe un dimanche")
	var ecoles0 := el.mesure("ecoles")
	_check(el.anticiper() and el.etat == "campagne", "élections anticipées : campagne ouverte")
	_check(el.listes.size() >= 3, "%d listes : %s" % [el.listes.size(), ", ".join(el.listes.map(func(l) -> String: return String(l.nom)))])
	_check(el.promettre("ecole") and el.promettre("emploi") and el.promettre("loisirs"), "3 promesses")
	_check(not el.promettre("police"), "pas plus de 3 promesses")
	var r := el.intentions()
	var tot := 0.0
	for id in r.pct:
		tot += float(r.pct[id])
	_check(absf(tot - 100.0) < 0.5 and float(r.participation) > 20.0, "sondage d'intentions : %s, participation %d %%" % [str(r.pct), roundi(r.participation)])
	# Jusqu'au dimanche 20 h.
	var guard := 0
	while el.historique.is_empty() and guard < 24 * 10:
		_hours(scene, 1)
		guard += 1
	_check(not el.historique.is_empty(), "scrutin dépouillé le dimanche à 20 h")
	if el.etat == "entre_tours":
		guard = 0
		while el.etat == "entre_tours" and guard < 24 * 9:
			_hours(scene, 1)
			guard += 1
		_check(el.historique.size() == 2, "2e tour le dimanche suivant")
	_check(el.etat == "mandat", "nouveau mandat")
	var last := el.dernier_scrutin()
	print("     résultats : ", ", ".join((last.resultats as Array).map(func(e) -> String: return "%s %.1f %%" % [e.nom, e.pct])))
	if el.joueur_maire():
		_check(el.promesses.size() == 3 and float(el.promesses[0].ref) == ecoles0, "réélu·e : les 3 promesses sont gardées pour le mandat")
		_check(not el.tenue(el.promesses[0]), "promesse « école » pas encore tenue")
		_check(_put(bs, "ecole", -280) > 0, "nouvelle école posée")
		_check(el.tenue(el.promesses[0]), "une école de plus : promesse tenue (%s)" % el.progres(el.promesses[0]))
	# Une ville très mécontente : le joueur perd.
	src.env = -25.0
	src.impots = -25.0
	avis._ville_ms = -100000
	avis._sources_ms = -100000
	# Le joueur a pu perdre le scrutin précédent : il redevient maire pour ce cas
	# (sans mairie, seule une pétition permet d'anticiper : voir mairie_test).
	if not el.joueur_maire():
		el.maire = {"joueur": true, "liste": "joueur", "nom": el.ma_liste(), "couleur": Elections.COULEUR_JOUEUR}
	_check(el.anticiper(), "élections anticipées dans une ville mécontente")
	guard = 0
	var n_hist := el.historique.size()
	while (el.etat == "campagne" or el.etat == "entre_tours") and guard < 24 * 20:
		_hours(scene, 1)
		guard += 1
	var last2 := el.dernier_scrutin()
	print("     résultats : ", ", ".join((last2.resultats as Array).map(func(e) -> String: return "%s %.1f %%" % [e.nom, e.pct])))
	_check(el.historique.size() > n_hist and not el.joueur_maire(), "ville mécontente : la liste du joueur perd (maire : %s)" % String(el.maire.get("tete_nom", "")))
	_check(not el.objectifs.is_empty(), "objectifs imposés par la liste gagnante : %d" % el.objectifs.size())
	var tete := int(el.maire.get("tete", -1))
	if tete >= 0 and pop.persons.has(tete):
		var cv: Array = pop.persons[tete].get("cv", [])
		var found := false
		for e in cv:
			if String(e[1]) == "politique" and String(e[2]).begins_with("Élu"):
				found = true
		_check(found, "« Élu·e maire » dans le CV du nouveau maire")
	var d_el := el.to_dict()
	var el2 := Elections.new(avis)
	el2.from_dict(JSON.parse_string(JSON.stringify(d_el)))
	_check(el2.etat == el.etat and el2.objectifs.size() == el.objectifs.size() and el2.maire.get("nom") == el.maire.get("nom"), "élections : sauvegarde et rechargement")
	src.env = 0.0
	src.impots = 0.0
	avis._ville_ms = -100000

	print("Manifestations :")
	avis.manifs.forcer = 1
	src.env = -14.0
	avis._sources_ms = -100000
	avis._sondage_ms = -100000
	_check(avis.manifs.pire_theme() == "environnement", "le pire thème sous %d : environnement" % Manifestations.SEUIL)
	var mid := avis.manifs.annoncer("environnement", true)
	var m: Dictionary = avis.manifs.liste[mid]
	_check(int(m.nb) >= 12 and int(m.bid) == mairie, "%d manifestants annoncés devant la mairie" % int(m.nb))
	_hours(scene, 1, 600.0)
	_check(String(m.etat) == "en_cours", "la manifestation commence")
	var node: Node3D = avis.manifs._nodes.get(mid, null)
	_check(node != null and node.get_node_or_null("Banderole") != null, "cortège visible avec banderole")
	_check(int(m.edge) >= 0 and transport.network.closed_edges.has(int(m.edge)), "la rue du cortège est fermée")
	var p_start := node.position
	_hours(scene, 3, 600.0)
	_check(node.position.distance_to(p_start) > 5.0, "le cortège avance (%.0f m)" % node.position.distance_to(p_start))
	var walkers := 0
	var n := pop.now()
	for pid in m.part:
		for seg in pop.day_plan(pop.persons[pid], n):
			if String(seg[4]).begins_with("Manifeste"):
				walkers += 1
				break
	_check(walkers > 0, "%d manifestants quittent leur journée pour y aller" % walkers)
	var note_avant := avis.note("environnement")
	_check(avis.manifs.repondre(mid, "negocier") == "", "négocier")
	_check(String(m.etat) == "finie" and not transport.network.closed_edges.has(int(m.edge)), "fin du cortège, rue rouverte")
	avis._sondage_ms = -100000
	_check(avis.note("environnement") > note_avant, "la négociation fait remonter le thème (%d → %d)" % [note_avant, avis.note("environnement")])
	# Ignorer deux fois : grève.
	var m2 := avis.manifs.annoncer("environnement", true)
	_hours(scene, 1, 600.0)
	avis.manifs.repondre(m2, "ignorer")
	var m3 := avis.manifs.annoncer("environnement", true)
	_hours(scene, 1, 600.0)
	avis.manifs.repondre(m3, "ignorer")
	_check(pop.effectif.en_greve(school) and pop.effectif.ferme(school), "2e manifestation ignorée : grève, l'école est fermée")
	_check(not pop.effectif.en_greve(office), "les bureaux privés ne font pas grève")
	_hours(scene, 30)
	_check(not pop.effectif.en_greve(school), "la grève s'arrête le lendemain")
	# Police.
	_check(not avis.manifs.police_possible(), "sans commissariat, pas de police")
	var pol := _put(bs, "police", -280)
	_check(pol > 0 and avis.manifs.police_possible(), "commissariat construit")
	var m4 := avis.manifs.annoncer("environnement", true)
	_hours(scene, 1, 600.0)
	_check(avis.manifs.repondre(m4, "police") == "" and int(avis.manifs.liste[m4].incident) > 0, "police envoyée (incident déclaré aux urgences)")
	ev.resoudre(int(avis.manifs.liste[m4].incident))
	_check(String(avis.manifs.liste[m4].etat) == "finie" and String(avis.manifs.liste[m4].reponse) == "police", "la police disperse le cortège")
	var pid4 := int(avis.manifs.liste[m4].part[0]) if not (avis.manifs.liste[m4].part as Array).is_empty() else -1
	if pid4 >= 0:
		_check((pop.satisfaction(pop.persons[pid4]).why as Array).has("− dispersé·e par la police pendant une manifestation"), "les manifestants dispersés s'en souviennent")
	src.env = 0.0
	avis._sources_ms = -100000

	print("Sauvegarde :")
	var d := avis.to_dict()
	var json := JSON.parse_string(JSON.stringify(d)) as Dictionary
	var n_eff := avis.effets_actifs().size()
	var n_hist2 := avis.historique.size()
	avis.from_dict(json)
	_check(avis.effets_actifs().size() == n_eff and avis.historique.size() == n_hist2, "effets (%d) et historique (%d) rechargés" % [n_eff, n_hist2])
	_check(avis.manifs.liste.size() > 0 and not avis.elections.objectifs.is_empty(), "manifestations et élections rechargées")
	_check(scene.save_sections().has("avis"), "section « avis » dans la sauvegarde")

	print("Panneau Avis :")
	var panel: AvisPanel = scene.avis_panel
	panel.set_open(true)
	for v in ["avis", "quartiers", "paroles", "elections", "manifs"]:
		panel.show_view(v)
		_check(panel._body.get_child_count() > 2, "onglet %s (%d éléments)" % [v, panel._body.get_child_count()])
	avis.elections.anticiper()
	panel.show_view("elections")
	_check(panel._body.get_child_count() > 8, "onglet élections pendant la campagne")
	scene.avis_carte.set_on(true)
	_check(scene.avis_carte.multimesh.instance_count > 0, "carte de satisfaction : %d disques" % scene.avis_carte.multimesh.instance_count)
	scene.avis_carte.set_on(false)
	panel.set_open(false)

	print("TEST OK" if ok else "TEST ÉCHEC")
	quit(0 if ok else 1)
