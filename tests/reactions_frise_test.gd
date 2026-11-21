extends SceneTree
## Test des bulles des habitants (réactions aux choix du joueur) et de la frise
## avant / après du time-lapse.
##  - bulles : genre de chaque choix (école, maison de style, usine, décharge,
##    routes, rails), phrases selon l'époque et l'âge, une bulle à la fois, écart
##    et recharge, branchement sur l'historique (Ctrl+Z), annuler, impôts, menu
##    Affichage, clic → fiche, fin de la bulle, textes traduits en en/de/it/es ;
##  - frise : choix des images, assemblage 1920 × 1080 (avant à gauche, après à
##    droite, frise en bas), année d'époque gardée avec chaque image, export PNG
##    depuis l'écran du time-lapse.
## Usage : godot --headless --path . --script res://tests/reactions_frise_test.gd

var ok := true
const MIDI := 1_784_282_400.0


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
	_regles_tests()
	_traductions_tests()
	await _scene_tests()
	print("TEST OK" if ok else "TEST ÉCHEC")
	quit(0 if ok else 1)


func _regles_tests() -> void:
	print("Règles des bulles :")
	_check(ReactionsHabitants.genre_batiment("ecole") == "ecole", "école → école")
	_check(ReactionsHabitants.genre_batiment("haussmann__ecole") == "ecole", "école de style haussmannien → école")
	_check(ReactionsHabitants.genre_batiment("maison") == "logement", "maison → logement")
	_check(ReactionsHabitants.genre_batiment("usine") == "industrie", "usine → industrie")
	_check(ReactionsHabitants.genre_batiment("decharge") == "dechets", "décharge → déchets")
	_check(ReactionsHabitants.genre_batiment("hopital") == "sante", "hôpital → santé")
	_check(ReactionsHabitants.genre_batiment("colombages__ferme") == "production", "ferme → production")
	_check(ReactionsHabitants.genre_batiment("maison_commune") == "", "Maison de commune : la fondation a sa propre bulle")
	var nb := 0
	for g in ReactionsHabitants.PHRASES:
		nb += (ReactionsHabitants.PHRASES[g] as Array).size()
	_check(ReactionsHabitants.PHRASES.size() >= 30 and nb >= 90, "%d genres de choix, %d phrases" % [ReactionsHabitants.PHRASES.size(), nb])
	for g in ReactionsHabitants.PAR_ID.values() + ReactionsHabitants.PAR_CATEGORIE.values():
		if not ReactionsHabitants.PHRASES.has(g):
			_check(false, "phrases pour « %s »" % g)
	_check(ReactionsHabitants.convient("<1900", 30, 1820) and not ReactionsHabitants.convient("<1900", 30, 1950), "« <1900 » : seulement avant 1900")
	_check(ReactionsHabitants.convient(">1955", 30, 2000) and not ReactionsHabitants.convient(">1955", 30, 1850), "« >1955 » : seulement après")
	_check(ReactionsHabitants.convient("enfant", 8, 1900) and not ReactionsHabitants.convient("enfant", 30, 1900), "« enfant » : moins de 15 ans")
	_check(ReactionsHabitants.convient("senior", 70, 1900) and not ReactionsHabitants.convient("senior", 40, 1900), "« senior » : 65 ans et plus")
	var r := ReactionsHabitants.new()
	var anachronisme := false
	var cheval_2000 := false
	for i in 200:
		var t1800 := r.phrase("route", 40, 1800)
		anachronisme = anachronisme or t1800.contains("garer") or t1800.contains("nids-de-poule")
		cheval_2000 = cheval_2000 or r.phrase("route", 40, 2000).contains("cheval")
	_check(not anachronisme, "en 1800, personne ne cherche à se garer")
	_check(not cheval_2000, "en 2000, plus de cheval sur la route neuve")
	var enfant_ok := true
	for i in 100:
		var t := r.phrase("ecole", 9, 1950)
		enfant_ok = enfant_ok and not t.contains("Mes enfants") and not t.contains("le curé")
	_check(enfant_ok, "un enfant ne parle pas comme un parent ni comme un grand-parent")
	r.free()
	var diff := {"e_plus": {7: {"t": "train", "pts": PackedVector3Array([Vector3(0, 0, 0), Vector3(10, 0, 0), Vector3(20, 0, 0)])}}, "e_moins": {}}
	var gv := ReactionsHabitants.genre_voies(diff)
	_check(not gv.is_empty() and gv[0] == "rail", "voie ferrée → rail (%s)" % str(gv))
	_check(ReactionsHabitants.genre_voies({"e_plus": {}, "e_moins": {3: {}}}).is_empty(), "une démolition de voie seule ne fait pas parler")


func _traductions_tests() -> void:
	print("Traductions :")
	var textes: Array = []
	for g in ReactionsHabitants.PHRASES:
		for e in ReactionsHabitants.PHRASES[g]:
			textes.append(String(e[0]))
	textes += ["%s · %d ans", "Bulles des habitants", "Les habitants réagissent en une phrase à tes choix",
		"Frise avant / après (image)", "Frise avant / après", "Avant · %d", "Aujourd'hui · %d", "%s, de %d à %d", "%s en %d", "Partager", "%s → %s  ·  %d jours de jeu",
		"Fermer l'aperçu (Échap)", "Frise en cours…", "Frise avant / après enregistrée : %s"]
	for code in ["en", "de", "it", "es"]:
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/langues/%s.json" % code))
		var tx: Dictionary = d.get("textes", {}) if d is Dictionary else {}
		var manque: Array = []
		for t in textes:
			if not tx.has(t):
				manque.append(t)
		_check(manque.is_empty(), "%s : bulles et frise traduites%s" % [code, "" if manque.is_empty() else " (manque : %s)" % str(manque.slice(0, 3))])


func _scene_tests() -> void:
	print("Dans la partie :")
	Creations.persist = false
	BatimentsVie.chantiers = false
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 40
	world.view_radius_override = 400.0
	world.set_origin(46.2, 6.9)
	for i in 3000:
		await process_frame
		if i >= 60 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	var re: ReactionsHabitants = scene.reactions
	_check(re != null and re.is_inside_tree(), "bulles des habitants branchées")
	_check(scene.affichage.ids().has("bulles"), "« Bulles des habitants » dans le menu Affichage")
	var amb: DayNight = scene.ambiance
	amb.set_speed(0)
	amb.unix_time = MIDI
	amb._apply()
	var pop: Population = scene.population
	var pid := 900001
	pop.persons[pid] = {"id": pid, "p": "Jeanne", "n": "Martin", "s": "f", "nj": pop.life_clock - 41 * 365.25, "f": -1,
		"r": "adulte", "job": -1, "met": "", "sch": -1, "hob": []}
	var heure := [1000.0]
	re.horloge = func() -> float: return heure[0]
	re.clear()

	_check(re.reagir("ecole", Vector3(0, 46, 0)), "une école posée fait réagir un habitant")
	_check(re.carte().visible and String(re.bulle.genre) == "ecole", "la bulle s'affiche")
	_check(re._qui.text.begins_with("Jeanne Martin · 41 ans"), "nom et âge de l'habitant (%s)" % re._qui.text)
	var dans_banque := false
	for e in ReactionsHabitants.PHRASES.ecole:
		dans_banque = dans_banque or String(e[0]) == String(re.bulle.texte)
	_check(dans_banque, "phrase de la banque « école » (%s)" % re.bulle.texte)
	_check(not re.reagir("commerce", Vector3.INF), "une seule bulle à la fois : l'écart est respecté")
	heure[0] += ReactionsHabitants.ECART + 1.0
	_check(not re.reagir("ecole", Vector3.INF), "pas deux fois l'école de suite (recharge)")
	_check(re.reagir("sante", Vector3.INF), "un autre genre de choix passe après l'écart")

	# Branché sur l'historique (Ctrl+Z) : les vrais gestes du joueur.
	heure[0] += ReactionsHabitants.ECART + 1.0
	var h: HistoriqueVille = HistoriqueVille.instance
	_check(h != null, "historique présent")
	h.noter("Commissariat", {"k": "bat_pose", "b": {"t": "police", "x": 0, "z": 0, "r": 0}})
	_check(String(re.bulle.get("genre", "")) == "police", "pose notée par l'historique → bulle « police »")
	heure[0] += ReactionsHabitants.ECART + 1.0
	h.annule.emit()
	_check(String(re.bulle.get("genre", "")) == "annuler", "Ctrl+Z → « finalement non ? »")
	heure[0] += ReactionsHabitants.ECART + 1.0
	re.on_geste([], ["Décors"])
	re.on_geste([], ["Décors"])
	heure[0] += ReactionsHabitants.ECART + 1.0
	re._derniers.clear()
	re.rng.seed = 3
	var dit := false
	for i in 20:
		heure[0] += ReactionsHabitants.RECHARGE + 1.0
		dit = dit or (re.reagir("decors", Vector3.INF) and String(re.bulle.genre) == "decors")
	_check(dit, "les décors font réagir de temps en temps")

	# Série : 4 maisons identiques en une minute.
	heure[0] += ReactionsHabitants.RECHARGE + 1.0
	re._derniers.clear()
	re._poses.clear()
	for i in ReactionsHabitants.SERIE:
		heure[0] += 2.0
		re._derniere = -1000.0
		re.on_geste([{"k": "bat_pose", "b": {"t": "maison", "x": 0, "z": 0, "r": 0}}], ["Maison"])
	_check(String(re.bulle.get("genre", "")) == "serie", "4 maisons pareilles → « c'est un jeu de dominos ? »")

	# Impôts.
	heure[0] += ReactionsHabitants.ECART + 1.0
	var bud := BudgetCommunal.instance
	if bud != null and not bud._bloque():
		re._lire_taux()
		bud.set_taux("foncier", 1.4)
		re._suivre_impots(2.5)
		_check(String(re.bulle.get("genre", "")) == "impots_hausse", "impôts relevés → les habitants râlent")
		bud.set_taux("foncier", 1.0)
	else:
		print("  --  budget absent : impôts non vérifiés")

	# Fin de la bulle, clic, masque.
	heure[0] += 100.0
	re._process(0.1)
	_check(re.bulle.is_empty() and not re.carte().visible, "la bulle se ferme toute seule")
	heure[0] += 100.0
	re.reagir("parc", Vector3.INF)
	_check(not re.person_requested.get_connections().is_empty(), "clic sur la bulle branché sur la fiche Habitants")
	for co in re.person_requested.get_connections():
		re.person_requested.disconnect(co.callable)
	var demande := [-1]
	re.person_requested.connect(func(p: int) -> void: demande[0] = p)
	var clic := InputEventMouseButton.new()
	clic.button_index = MOUSE_BUTTON_LEFT
	clic.pressed = true
	re._on_gui_input(clic)
	_check(demande[0] == pid and re.bulle.is_empty(), "clic sur la bulle → fiche de l'habitant")
	scene.affichage.masquer("bulles", true)
	heure[0] += 200.0
	_check(not re.reagir("zoo", Vector3.INF), "bulles masquées (menu Affichage) : plus de réaction")
	scene.affichage.masquer("bulles", false)
	heure[0] += 200.0
	_check(re.reagir("zoo", Vector3.INF), "réaffichées : les habitants reparlent")
	re.fermer()
	pop.persons.erase(pid)

	# --- Frise avant / après --------------------------------------------------------
	print("Frise avant / après :")
	_check(FriseVille.choisir(100) == [0, 20, 40, 59, 79, 99], "6 images régulières sur 100 (%s)" % str(FriseVille.choisir(100)))
	_check(FriseVille.choisir(3) == [0, 1, 2] and FriseVille.choisir(0).is_empty(), "moins d'images que la frise : toutes")
	var z := FriseVille.zones()
	var cadre := Rect2(Vector2.ZERO, Vector2(FriseVille.TAILLE))
	var dedans: bool = cadre.encloses(z.avant) and cadre.encloses(z.apres) and not z.avant.intersects(z.apres)
	for r in z.frise:
		dedans = dedans and cadre.encloses(r) and not (r as Rect2).intersects(z.avant) and not (r as Rect2).intersects(z.apres)
	_check(dedans, "mise en page dans l'image, sans chevauchement")
	_check(FriseVille.titre({"nom": "Village de Morges"}, 1800, 1846) == "Village de Morges, de 1800 à 1846", "titre de la frise")

	var tl: TimeLapse = scene.timelapse
	var panel: TimeLapsePanel = scene.timelapse_panel
	tl.set_process(false)
	var n := [0]
	tl.capturer = func(_c: Dictionary) -> Image:
		n[0] += 1
		var img := Image.create(64, 36, false, Image.FORMAT_RGB8)
		img.fill(Color(0.1 + n[0] * 0.1, 0.2, 0.9 - n[0] * 0.1))
		return img
	var cid := tl.ajouter_camera("Village de Testville", Transform3D(Basis(), Vector3(0, 300, 300)).looking_at(Vector3.ZERO, Vector3.UP))
	var c := tl.camera(cid)
	for d in 8:
		await tl.filmer(c)
		amb.shift_days(1)
	_check((c.images as Array).size() == 8, "8 images du time-lapse")
	_check(int(c.images[0].get("an", 0)) == Epoques.annee(), "chaque image garde l'année de la partie (%d)" % int(c.images[0].get("an", 0)))
	var img := FriseVille.assembler(tl, c)
	_check(img != null and img.get_size() == FriseVille.TAILLE, "frise de 1920 × 1080")
	var pa: Color = img.get_pixelv(Vector2i(z.avant.get_center()))
	var pb: Color = img.get_pixelv(Vector2i(z.apres.get_center()))
	_check(pa.r < 0.3 and pb.r > 0.75, "avant = première image, après = dernière (%s / %s)" % [pa, pb])
	var pf: Color = img.get_pixelv(Vector2i((z.frise[0] as Rect2).get_center()))
	_check(absf(pf.r - pa.r) < 0.05, "la frise commence par la fondation")
	_check(FriseVille.assembler(tl, {"images": [{}]}) == null, "une seule image : pas de frise")

	panel.set_open(true)
	panel._choisir(cid)
	_check(not panel._frise.disabled, "bouton « Frise avant / après » actif")
	var chemin: String = await panel.exporter_frise()
	_check(chemin != "" and FileAccess.file_exists(chemin), "frise enregistrée en PNG (%s)" % chemin.get_file())
	var relue := Image.load_from_file(chemin) if chemin != "" else null
	_check(relue != null and relue.get_size() == FriseVille.TAILLE, "PNG relu en 1920 × 1080")
	_check(panel._apercu.visible and panel._apercu_tex.texture != null, "aperçu de la frise à l'écran")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	panel._input(esc)
	_check(not panel._apercu.visible and panel.is_open(), "Échap ferme d'abord l'aperçu")
	if chemin != "":
		DirAccess.remove_absolute(chemin)
	tl.supprimer(cid)
	panel.set_open(false)
	scene.queue_free()
	await process_frame
