extends SceneTree
## Test du journal de la ville : faits notés (nouvelles, match, carnet, village
## fondé, inauguration, pont vers nulle part, chiffres), édition du matin (une,
## articles, brèves, carnet, annonces), jour calme, époques (1823 → aujourd'hui),
## modèles réservés à leur époque, traduction anglaise de tous les modèles,
## sauvegarde et chargement, panneau F4.
## Usage : godot --headless --path . --script res://tests/journal_test.gd

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


## Tous les modèles de texte de la rédaction (pour la traduction).
func _modeles() -> Array:
	var R := JournalRedaction
	var out := []
	var listes := [R.TITRES_PONT_NULLE_PART, R.CHAPO_PONT_NULLE_PART, R.PAROLE_PONT_NULLE_PART, R.TITRES_PONT, R.CHAPO_PONT,
		R.TITRES_ROUTES, R.CHAPO_ROUTES, R.TITRES_FONDATION, R.CHAPO_FONDATION, R.TITRES_PALIER, R.CHAPO_PALIER,
		R.TITRES_CHOMAGE, R.CHAPO_CHOMAGE, R.TITRES_CAISSE_ROUGE, R.CHAPO_CAISSE_ROUGE, R.TITRES_CAISSE_VERTE, R.CHAPO_CAISSE_VERTE,
		R.TITRES_SATISFACTION_BASSE, R.CHAPO_SATISFACTION_BASSE, R.TITRES_SATISFACTION_HAUTE, R.CHAPO_SATISFACTION_HAUTE,
		R.TITRES_BOUCHONS, R.CHAPO_BOUCHONS, R.TITRES_POUBELLES, R.CHAPO_POUBELLES, R.TITRES_POLLUTION, R.CHAPO_POLLUTION,
		R.TITRES_CALME, R.CHAPO_CALME, R.ANNONCES_DROLES, R.CHAPO_INAUGURATION, R.TITRES_DEMOLITION, R.CHAPO_DEMOLITION, R.CHAPO_DEFAUT]
	for d in [R.TITRES_GENRE, R.CHAPOS_GENRE, R.TEMOINS, R.TITRES_MATCH, R.PAROLE_MATCH, R.TITRES_INAUGURATION]:
		for k in d:
			listes.append(d[k])
	for l in listes:
		for m in l:
			out.append(JournalEpoques.texte_de(m))
	for k in R.CHIFFRES:
		out.append(R.CHIFFRES[k])
	out.append_array([R.CORPS_MATCH, R.CORPS_MATCH_DOM, R.CORPS_MATCH_BUTEURS, R.CORPS_INAUGURATION, R.CORPS_INAUGURATION_COUT,
		R.ANNONCE_LOGEMENTS, R.ANNONCE_EMPLOIS, R.ANNONCE_HABITANTS, R.TEMOIN_INTRO, R.SIGNATURE])
	for e in JournalEpoques.EPOQUES:
		out.append_array([String(e.titre), String(e.devise), String(e.prix), String(e.envoye)])
	for r in Journal.RUBRIQUES:
		out.append(String(Journal.RUBRIQUES[r]))
	return out


func _textes_code() -> Array:
	# Textes écrits en dur dans journal.gd et journal_panel.gd (Langue.t, R.t, _temoin…).
	var out := []
	var re := RegEx.new()
	re.compile("(?:Langue\\.t|R\\.t|_temoin|_encadre\\([a-z]+,)\\(?\\[?\"((?:[^\"\\\\]|\\\\.)*)\"")
	for f in ["res://scripts/journal/journal.gd", "res://scripts/journal/journal_panel.gd"]:
		var src := FileAccess.get_file_as_string(f)
		for m in re.search_all(src):
			out.append(m.get_string(1))
	var re2 := RegEx.new()
	re2.compile("_temoin\\(\\[((?:\"(?:[^\"\\\\]|\\\\.)*\",?\\s*)+)\\]")
	var re3 := RegEx.new()
	re3.compile("\"((?:[^\"\\\\]|\\\\.)*)\"")
	var src2 := FileAccess.get_file_as_string("res://scripts/journal/journal.gd")
	for m in re2.search_all(src2):
		for q in re3.search_all(m.get_string(1)):
			out.append(q.get_string(1))
	return out


func _run() -> void:
	Creations.persist = false
	BatimentsVie.chantiers = false
	GameStart.chosen = true
	GameStart.place_name = "Valfleuri, Savoie"
	ReglagesPartie.prochaine = ReglagesPartie.preset("normal")
	ReglagesPartie.prochaine.fondateurs = 0
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
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
	var j: Journal = scene.journal
	var cm: Communes = scene.communes
	var ev: Evenements = scene.evenements
	j.auto = false
	_check(j != null and Journal.instance == j and scene.journal_panel != null, "journal et panneau branchés")
	j.clear()
	j.scanner()
	_check(j.faits.is_empty(), "premier passage : ce qui existe déjà ne fait pas d'article")
	var y := world.cell_height(Vector2i(0, 0))

	print("Les faits du jour :")
	cm.nom_en_attente = "Valfleuri"
	bs.place("maison_commune", Vector2i(-1000, 0), 0)
	_check(j.faits.any(func(f) -> bool: return String(f.k) == "fondation" and String(f.nom) == "Valfleuri"), "village fondé noté")
	transport.build_segment("route", Vector3(-1300, y, 40), Vector3(-700, y, 40))
	var ecole := bs.place("ecole", Vector2i(-1000, 70), bs.best_rotation("ecole", Vector2i(-1000, 70)))
	_check(ecole > 0, "école posée")
	ev.news("Incendie : Boulangerie Martin ! Les pompiers sont appelés.", Vector3(10, y, 10), "incendie", 77)
	ev.news("Le feu gagne Maison Dupont.", Vector3(10, y, 10), "incendie", 77)
	ev.news("Incendie éteint : Boulangerie Martin abîmée.", Vector3(10, y, 10), "incendie", 77)
	ev.news("Marché du samedi : ça commence (place de l'Église).", Vector3.INF, "marche", 78)
	ev.news("Le club signe un attaquant.", Vector3.INF, "match")
	ev.news("Une nouvelle sans genre connu.", Vector3.INF, "inconnu")
	_check(j.faits.filter(func(f) -> bool: return String(f.k) == "depeche").size() == 6, "nouvelles des événements notées")
	j._on_resultat({"sport": "football", "club": "FC Valfleuri", "adv": "Racing Annecy", "dom": true, "pour": 3, "contre": 1,
		"issue": "V", "buteurs": ["Paul Girard"], "affluence": 4200, "texte": "FC Valfleuri 3 – 1 Racing Annecy"})
	var pop: Population = scene.population
	var bebe := {"id": 9001, "p": "Léa", "n": "Bernard", "nj": pop.life_clock, "s": "F"}
	var vieux := {"id": 9002, "p": "Marcel", "n": "Roux", "nj": pop.life_clock - 101.0 * 365.25, "s": "H"}
	pop.etape_vie.emit(bebe, "naissance", "Naît à Valfleuri, fille de Julie Bernard", -1)
	pop.etape_vie.emit(bebe, "naissance", "Devient ton personnage principal", -1)
	pop.etape_vie.emit(vieux, "deces", "Meurt de vieillesse à 101 ans", -1)
	pop.etape_vie.emit(vieux, "emploi", "Devient boulanger", -1)
	var carnet := j.faits.filter(func(f) -> bool: return String(f.k) == "carnet")
	_check(carnet.size() == 2, "carnet : une naissance et un décès (le reste est ignoré)")
	# Un pont dont l'autre bout ne mène nulle part.
	var net := transport.network
	var a := net.add_node(Vector3(-800, y, 200), TransportTypes.Mode.ROAD)
	var b := net.add_node(Vector3(-760, y, 200), TransportTypes.Mode.ROAD)
	var st := PackedByteArray([TransportTypes.Struct.GROUND, TransportTypes.Struct.BRIDGE, TransportTypes.Struct.BRIDGE])
	net.add_edge(a, b, "route", PackedVector3Array([Vector3(-800, y, 200), Vector3(-780, y + 4, 200), Vector3(-760, y, 200)]), st)
	j.scanner()
	_check(j.faits.any(func(f) -> bool: return String(f.k) == "inauguration" and String(f.cat) == "services"), "inauguration de l'école notée")
	_check(j.faits.any(func(f) -> bool: return String(f.k) == "pont" and bool(f.nulle_part)), "pont vers nulle part repéré")
	_check(j.faits.any(func(f) -> bool: return String(f.k) == "routes"), "kilomètres de routes notés")

	print("L'édition du matin :")
	j.annee_forcee = 2026
	var ed := j.publier()
	_check(j.faits.is_empty() and j.editions.size() == 1 and int(ed.n) == 1 and j.non_lue, "édition n° 1 parue, faits vidés")
	_check(String(ed.une.genre) == "incendie", "l'incendie fait la une (le plus lourd)")
	_check((ed.une.corps as Array).size() == 3, "la une raconte les trois nouvelles de l'incendie")
	_check(not (ed.une.temoin as Dictionary).is_empty() or pop.persons.is_empty(), "un témoin (s'il y a des habitants)")
	var titres := []
	for art in ed.articles:
		titres.append(Journal.texte(art.titre))
	var tous := "\n".join(titres)
	print("    une : ", Journal.texte(ed.une.titre))
	print("    articles : ", tous.replace("\n", " | "))
	_check(ed.articles.any(func(x) -> bool: return String(x.rub) == "sport"), "article de sport sur le match")
	var nulle := false
	for art in (ed.articles as Array) + [ed.une]:
		var tt := Journal.texte(art.titre)
		if tt.contains("nulle part") or tt.contains("ne mène à rien"):
			nulle = true
	_check(nulle, "article sur le pont vers nulle part")
	_check(ed.articles.size() <= 5, "au plus 5 articles sous la une")
	var tout: Array = ((ed.articles as Array) + [ed.une]).map(func(x) -> Array: return x.titre) + (ed.breves as Array)
	_check(tout.any(func(x) -> bool: return Journal.texte(x).contains("101")), "le doyen centenaire a son article (ou sa brève)")
	_check((ed.carnet.naissance as Array).size() == 1 and String(ed.carnet.naissance[0][0]) == "Léa Bernard", "carnet : naissance de Léa Bernard")
	_check((ed.sport as Array).size() == 1, "sports en bref : la nouvelle du club")
	_check((ed.breves as Array).any(func(x) -> bool: return Journal.texte(x).contains("sans genre")), "nouvelle inconnue en brève")
	_check(not (ed.annonces as Array).is_empty(), "petites annonces")
	_check(Journal.titre_de(ed) == "Valfleuri.info", "nom du journal en 2026 : Valfleuri.info")

	print("Jour calme et époques :")
	j.annee_forcee = 1823
	var calme := j.publier()
	_check(int(calme.une.imp) == 0 and Journal.texte(calme.une.titre) != "", "jour sans nouvelle : une humoristique")
	_check(Journal.titre_de(calme) == "La Gazette de Valfleuri" and String(calme.ep) == "gazette", "1823 : La Gazette de Valfleuri")
	_check(String(JournalEpoques.de_annee(1880).id) == "petit" and String(JournalEpoques.de_annee(1950).id) == "matin"
		and String(JournalEpoques.de_annee(1799).id) == "gazette", "époques : 1880 Petit Journal, 1950 -Matin, avant 1800 Gazette")
	var rng := RandomNumberGenerator.new()
	var anachronisme := false
	for i in 300:
		var t1 := JournalRedaction.choisir(rng, JournalRedaction.TITRES_GENRE.incendie, 1823)
		var t2 := JournalRedaction.choisir(rng, JournalRedaction.ANNONCES_DROLES, 1823)
		if t1.contains("réseaux sociaux") or t1.contains("pompiers sur tous") or t2.contains("wifi") or t2.contains("télévision"):
			anachronisme = true
	_check(not anachronisme, "en 1823 : pas de réseaux sociaux, de wifi ni de télévision")
	var moderne := false
	for i in 300:
		if JournalRedaction.choisir(rng, JournalRedaction.TITRES_GENRE.incendie, 2026).contains("chaîne des seaux"):
			moderne = true
	_check(not moderne, "en 2026 : plus de chaîne des seaux")

	print("Traduction anglaise :")
	var tr := Langue.traduction("en")
	var manquants := []
	var modeles := _modeles()
	modeles.append_array(_textes_code())
	for m in modeles:
		if not tr.textes.has(m) and not manquants.has(m):
			manquants.append(m)
	if not manquants.is_empty():
		for m in manquants:
			print("MANQUANT\t", m)
	_check(manquants.is_empty(), "%d textes du journal traduits en anglais" % modeles.size())
	Langue.activer("en")
	var en := Journal.texte(ed.une.titre)
	_check(en != "" and en != Langue.t("") and not en.contains("Incendie à") and not en.contains("Le feu"), "la une se relit en anglais : " + en)
	_check(Journal.titre_de(calme) == "The Valfleuri Gazette", "1823 en anglais : The Valfleuri Gazette")
	Langue.activer("fr")

	print("Sauvegarde et panneau :")
	var d: Dictionary = JSON.parse_string(JSON.stringify(j.to_dict()))
	var n := j.editions.size()
	j.clear()
	j.from_dict(d)
	_check(j.editions.size() == n and j.numero == 2 and j._inventaire and j._bat_vus.has(ecole), "éditions, bâtiments connus et numéro rechargés")
	_check(Journal.texte(j.editions[0].une.titre) == Journal.texte(ed.une.titre), "la une relue après chargement")
	var sec: Dictionary = scene.save_sections()
	_check(sec.has("journal"), "section « journal » dans la sauvegarde")
	var panel: JournalPanel = scene.journal_panel
	panel.set_open(true)
	await process_frame
	_check(panel.is_open() and panel._page.get_child_count() > 3, "panneau ouvert, page remplie")
	_check(not j.non_lue, "édition marquée lue")
	panel._aller(-1)
	await process_frame
	_check(panel.index == 0 and String(panel.edition().ep) == "web", "édition précédente (2026)")
	_check(panel.date_texte({"js": 6, "mois": 6, "jm": 14, "an": 1823}) == "samedi 14 juin 1823", "date à l'ancienne : samedi 14 juin 1823")
	var vu := []
	panel.focus_requested.connect(func(p: Vector3) -> void: vu.append(p))
	panel.set_open(false)
	j.annee_forcee = 0

	print("Parution automatique au changement de jour :")
	var amb: DayNight = scene.ambiance
	var avant := j.editions.size()
	j.auto = true
	j._dernier_jour = -1
	await process_frame
	await process_frame
	ev.news("Fête de quartier : ça commence (rue des Lilas).", Vector3.INF, "fete", 90)
	amb.unix_time += 86400.0
	for i in 60:
		await process_frame
		if j.editions.size() > avant:
			break
	var genres := [String(j.derniere().une.genre)]
	for x in j.derniere().articles:
		genres.append(String(x.genre))
	_check(j.editions.size() == avant + 1 and genres.has("fete"), "le matin suivant : nouvelle édition avec la fête (%s)" % ", ".join(genres))
	j.auto = false
	print("RÉSULTAT : ", "OK" if ok else "ÉCHEC")
	quit(0 if ok else 1)
