extends SceneTree
## Test des bulles d'aide (BullesAide) et du guide par chapitres (Guide) :
## bulles des étapes du tutoriel, cible encadrée, bulle qui ne cache pas la
## cible, file d'attente quand une étape se valide pendant ses bulles, tous les
## chapitres parcourus jusqu'au bout, proposition à la première ouverture d'un
## panneau, « Plus tard », « Ne plus proposer », panneau Guide (Ctrl+F1).
## Usage : godot --headless --path . --script res://tests/bulles_test.gd
## Captures (avec affichage) :
##   godot --path . --rendering-driver opengl3 --script res://tests/bulles_test.gd -- --dossier /chemin

var ok := true
var dossier := ""


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


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(nom: String) -> void:
	if dossier == "":
		return
	await _frames(12)
	var p := dossier.path_join(nom)
	root.get_viewport().get_texture().get_image().save_png(p)
	print("     capture : ", p)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size() - 1:
		if args[i] == "--dossier":
			dossier = args[i + 1]
	root.size = Vector2i(1600, 900)
	Creations.persist = false
	Guide.persist = false
	BatimentsVie.chantiers = false
	GameStart.chosen = true
	GameStart.load_slot = ""
	GameStart.place_name = "Valfleuri, Savoie"
	ReglagesPartie.prochaine = ReglagesPartie.preset("normal")
	ReglagesPartie.prochaine.deblocage = "tout"
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
	var t: Tutoriel = scene.tutoriel
	var b: BullesAide = scene.bulles_aide
	var g: Guide = scene.guide

	print("Bulles du tutoriel :")
	_check(b != null and g != null and scene.guide_panel != null, "bulles, guide et panneau branchés")
	await _frames(3)
	_check(b.actif and b.id == "tuto:camera" and b.index == 0, "partie neuve : bulles de la première étape au centre (%s)" % b.id)
	_check(b._titre_l.text == "Bienvenue, futur maire", "titre de la première bulle")
	var vp := b._voile.get_rect()
	var br := b.bulle_rect()
	_check(absf(br.get_center().x - vp.size.x * 0.5) < 40.0, "bulle centrée (x %d sur %d)" % [br.get_center().x, vp.size.x])
	await _shot("1-bienvenue.png")
	b.suivant()
	await _frames(4)
	_check(b._cible != null and String(b._cible.name) == "CarteTutoriel", "bulle 2 : cible = la carte du tutoriel")
	_check(b.cible_rect().size.x > 100.0, "cible encadrée (%s)" % b.cible_rect())
	_check(not b.bulle_rect().intersects(b.cible_rect()), "la bulle ne cache pas la cible")
	await _shot("2-carte-tutoriel.png")
	b.suivant()
	b.suivant()
	_check(not b.actif, "« Compris » ferme les bulles")
	_check(t.actif and t.id_courant() == "camera", "le tutoriel attend toujours la caméra")
	scene.montrer_bulles_etape(t.id_courant(), true)
	_check(b.actif and b.id == "tuto:camera", "« ? » de la carte : les bulles reviennent")
	b.fermer()
	scene.rig.position.x += 60.0
	t.verifier()
	await _frames(3)
	_check(t.id_courant() == "fonder" and b.actif and b.id == "tuto:fonder", "étape suivante : ses bulles s'ouvrent")
	_check(b.bulle().has("action") and String(b.bulle().action[1]) == "tuto_agir", "dernière bulle : bouton d'action de l'étape")
	b.action.emit("tuto_agir")
	_check(not b.actif and scene.villages_panel._dialog.visible, "bouton d'action de la bulle : fenêtre de fondation")
	scene.villages_panel._dialog.hide()
	scene.communes.nom_en_attente = "Valfleuri"
	var mc := bs.place("maison_commune", Vector2i(0, 0), 0)
	_check(mc > 0, "Maison de commune posée")
	for i in 30:
		await process_frame
		if t.id_courant() != "fonder":
			break
	t.verifier()
	await _frames(3)
	print("     étape : %s, bulles : %s" % [t.id_courant(), b.id])
	if t.id_courant() == "fondateurs":
		_check(b.actif and b.id == "guide:fondateurs", "étape « fondateurs » : bulles du chapitre Fondateurs")
		await _frames(4)
		_check(scene.fondateurs_panel.is_open(), "la bulle ouvre le panneau des fondateurs")
		_check(b._cible is Label and (b._cible as Label).text == "Les fondateurs", "cible : la section « Les fondateurs »")
		await _shot("3-fondateurs.png")
		t.verifier()
		await _frames(3)
		_check(t.id_courant() != "fondateurs" and b.id == "guide:fondateurs", "étape validée pendant les bulles : elles continuent")
		var suivante := t.id_courant()
		b.aller(2)
		await _frames(4)
		_check(b._cible is Label and (b._cible as Label).text.begins_with("Chantiers en cours"), "bulle 3 : « Chantiers en cours »")
		var r := b.cible_rect()
		_check(r.size.y > 40.0, "la section entière est encadrée (%d px)" % r.size.y)
		await _shot("4-chantiers-en-cours.png")
		b.aller(3)
		b.suivant()
		await _frames(3)
		_check(g.est_vu("fondateurs"), "chapitre Fondateurs vu jusqu'au bout")
		_check(b.actif and b.id == "tuto:" + suivante, "puis les bulles de l'étape suivante (%s)" % b.id)
		scene.fondateurs_panel.set_open(false)
	b.fermer()

	print("Chapitres du guide :")
	t.arreter()
	var trouvees := 0
	var total := 0
	for ch in Guide.CHAPITRES:
		var id := String(ch.id)
		g.lancer(id)
		_check(b.actif and b.id == "guide:" + id, "chapitre « %s » lancé" % String(ch.titre))
		var manques: Array[String] = []
		for k in (ch.bulles as Array).size():
			b.aller(k)
			await _frames(3)
			b._process(0.3)
			total += 1
			var bu: Dictionary = ch.bulles[k]
			if b._cible != null:
				trouvees += 1
			elif bu.has("cible") or bu.has("panneau"):
				manques.append(String(bu.titre))
			if id == "zoo" and k == 0:
				await _shot("5-zoo.png")
			if id == "construire" and k == 3:
				await _shot("6-construire-zonage.png")
			if id == "mairie" and k == 0:
				await _shot("7-mairie.png")
			if id == "atelier" and k == 1:
				await _shot("7b-atelier.png")
		if not manques.is_empty():
			print("     (rien à encadrer, partie neuve : %s)" % ", ".join(manques))
		b.suivant()
		_check(not b.actif and g.est_vu(id), "« %s » vu jusqu'au bout" % String(ch.titre))
		for p in ["fondateurs_panel", "build_panel", "mairie_panel", "budget_panel", "habitants_panel", "avis_panel", "reseaux_panel",
				"transit_panel", "decors_panel", "zoo_panel", "musee_panel", "parc_panel", "club_panel", "production_panel", "pays_panel", "objectifs_panel"]:
			var n = scene.get(p)
			if n != null and n.has_method("set_open") and n.is_open():
				n.set_open(false)
		if scene.decors_panel.visible:
			scene.decors_panel.set_shown(false)
		if scene.hud.create_mode:
			scene.set_create_mode(false)
		await _frames(2)
	print("     cibles encadrées : %d / %d bulles" % [trouvees, total])
	_check(trouvees * 2 >= total, "au moins la moitié des bulles encadrent quelque chose")

	print("Propositions :")
	g.oublier()
	g.verifier()
	_check(not b.actif, "rien d'ouvert : rien à proposer")
	scene.zoo_panel.set_open(true)
	await _frames(2)
	g.verifier()
	_check(b.actif and b.id == "proposition" and g.propose == "zoo", "zoo ouvert la première fois : visite proposée")
	await _shot("8-proposition-zoo.png")
	b.action.emit("guide_decouvrir")
	_check(b.actif and b.id == "guide:zoo", "« Découvrir » : chapitre du zoo")
	b.fermer()
	_check(not g.est_vu("zoo"), "fermé avant la fin : pas compté comme vu")
	g.verifier()
	_check(not b.actif, "déjà proposé dans cette session : pas reproposé")
	scene.zoo_panel.set_open(false)
	scene.musee_panel.set_open(true)
	await _frames(2)
	g.verifier()
	_check(b.actif and g.propose == "musee", "musée proposé")
	b.suivant()
	_check(not b.actif and not g.est_vu("musee"), "« Plus tard » : fermé, pas vu")
	scene.musee_panel.set_open(false)
	scene.club_panel.set_open(true)
	await _frames(2)
	g.verifier()
	_check(b.actif and g.propose == "club", "club proposé")
	b.action.emit("guide_jamais")
	_check(not b.actif and not g.proposer, "« Ne plus proposer » coupe les propositions")
	scene.club_panel.set_open(false)
	scene.parc_panel.set_open(true)
	await _frames(2)
	g.verifier()
	_check(not b.actif, "plus de propositions")
	scene.parc_panel.set_open(false)
	g.set_proposer(true)
	t.demarrer()
	await _frames(2)
	b.fermer()
	scene.reseaux_panel.set_open(true)
	await _frames(2)
	g.verifier()
	_check(not b.actif or b.id != "proposition", "pas de proposition pendant le tutoriel")
	scene.reseaux_panel.set_open(false)
	t.arreter()

	print("Panneau Guide :")
	var gp: GuidePanel = scene.guide_panel
	scene.hud.guide_requested.emit()
	await _frames(3)
	_check(gp.is_open(), "Ctrl+F1 (barre) ouvre le guide")
	_check(gp._body.get_child_count() >= Guide.CHAPITRES.size(), "un rang par chapitre (%d)" % gp._body.get_child_count())
	await _shot("9-panneau-guide.png")
	gp.set_open(false)

	print("Traductions :")
	for code in ["en", "de", "it", "es"]:
		var f := FileAccess.open("res://assets/langues/%s.json" % code, FileAccess.READ)
		var d: Dictionary = JSON.parse_string(f.get_as_text()).get("textes", {})
		var manque: Array[String] = []
		for ch in Guide.CHAPITRES:
			for k in ["titre", "resume"]:
				if not d.has(String(ch[k])):
					manque.append(String(ch[k]))
			for bu in ch.bulles:
				for k in ["titre", "texte", "touches"]:
					if bu.has(k) and not d.has(String(bu[k])):
						manque.append(String(bu[k]))
		for e in Tutoriel.ETAPES + Tutoriel.ETAPES_DEMO:
			for k in ["titre", "texte", "texte_rue", "touches"]:
				if e.has(k) and String(e[k]) != "" and not d.has(String(e[k])):
					manque.append(String(e[k]))
			for bu in e.get("bulles", []):
				for k in ["titre", "texte", "touches"]:
					if bu.has(k) and not d.has(String(bu[k])):
						manque.append(String(bu[k]))
		_check(manque.is_empty(), "%s : toutes les bulles traduites%s" % [code, "" if manque.is_empty() else " (manque : %s)" % manque[0]])

	print("RÉSULTAT : ", "OK" if ok else "ÉCHEC")
	print("TEST OK" if ok else "TEST ÉCHEC")
	quit(0 if ok else 1)
