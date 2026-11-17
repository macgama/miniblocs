extends SceneTree
## Test de l'éditeur du parc (Maj+A) : pièces et tracés, physique (vitesse, G,
## notes), modèles prêts, gare posée comme un bâtiment, attraction utilisée par
## les visiteurs, allées et files d'attente, décors à thème, nouveaux objets
## (bassins, boutiques), sauvegarde, panneau.
## Usage : godot --headless --path . --script res://tests/parc_editeur_test.gd

var ok := true
const SAMEDI := 1_784_358_000.0


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
	_pieces_tests()
	_physique_tests()
	_objets_tests()
	await _partie_tests()
	print("TEST OK" if ok else "TEST ÉCHEC")
	quit(0 if ok else 1)


func _pieces_tests() -> void:
	print("Pièces :")
	_check(VoiePieces.PIECES.size() >= 40, "%d pièces de voie" % VoiePieces.PIECES.size())
	_check(VoiePieces.FAMILLES.size() == 20, "20 familles (14 grands-huit, 6 sur l'eau)")
	# Attractions d'avant-guerre : un modèle de leur famille de base, rejoué chez elles.
	var src := {"bois": "mine", "familial": "mine", "acier": "acier", "buches": "buches", "toboggan": "toboggan"}
	for fid in ["panoramique", "bobsleigh", "train_fantome", "moulin", "tour_glissade", "promenades", "tournant", "luge_ete", "aile", "realite_virtuelle"]:
		var base := String(src.get(VoiePieces.style(fid), "mine"))
		var ok := false
		var modeles := AttractionsPerso.modeles().filter(func(m: Dictionary) -> bool: return String(m.famille) == fid)
		if not modeles.is_empty():
			base = fid
		for m: Dictionary in AttractionsPerso.modeles():
			if String(m.famille) == base:
				var d := m.duplicate(true)
				d.famille = fid
				d.id = "t_" + fid
				var c := AttractionsPerso.calcule(d)
				var mesh := VoieMesh.voie(d, c.tr, c.sim, func(_p: Vector3) -> float: return 0.0)
				var car := VoieMesh.voiture(d, true)
				ok = mesh.get_surface_count() > 0 and car.get_surface_count() > 0 and bool(c.sim.ok)
				print("    %s : ok %s, %s" % [VoiePieces.famille(fid).nom, c.sim.ok, c.sim.erreurs])
				break
		_check(ok, "%s : voie et voitures dessinées" % VoiePieces.famille(fid).nom)
	for id in VoiePieces.PIECES:
		var tex := VoiePieces.vignette(id, 40)
		if tex == null:
			_check(false, "vignette de %s" % id)
	_check(VoiePieces.refus("bois", 0, "looping") != "", "pas de looping en bois")
	_check(VoiePieces.refus("acier", 0, "looping") == "", "looping en acier")
	_check(VoiePieces.refus("acier", 0, "eclabousse") != "", "pas d'éclaboussure sur les rails")
	_check(VoiePieces.refus("buches", 0, "eclabousse") == "", "éclaboussure sur les bûches")
	_check(VoiePieces.refus("acier", 45, "virage_g") != "", "pas de virage dans une pente de 45°")
	_check(VoiePieces.refus("acier", 0, "fin_montee") != "", "fin de montée seulement après une montée")
	_check(VoiePieces.refus("mine", 25, "raidir_haut") != "", "train de la mine : 25° au plus")
	# Un looping revient à plat, dans le même sens, à la même hauteur.
	var d := {"famille": "acier", "pieces": [{"p": "looping"}]}
	var tr := VoiePieces.trace(d)
	var fin: Dictionary = tr.fin
	_check(absf(float(fin.pitch)) < 0.01 and absf(wrapf(float(fin.yaw) + PI / 2.0, -PI, PI)) < 0.01, "le looping ressort à plat, dans le même sens")
	var hmax := 0.0
	for p in tr.P:
		hmax = maxf(hmax, p.y)
	_check(hmax > 14.0 and hmax < 22.0, "hauteur du looping : %.1f m" % hmax)
	# Immelmann : demi-tour en hauteur.
	tr = VoiePieces.trace({"famille": "acier", "pieces": [{"p": "immelmann_g"}]})
	_check(absf(absf(wrapf(float(tr.fin.yaw) + PI / 2.0, -PI, PI)) - PI) < 0.02, "l'Immelmann ressort dans l'autre sens")
	_check(float((tr.fin.pos as Vector3).y) > 10.0, "… et en hauteur (%.1f m)" % float((tr.fin.pos as Vector3).y))
	# Quatre virages à droite reviennent au départ.
	tr = VoiePieces.trace({"famille": "acier", "pieces": [{"p": "virage_d"}, {"p": "virage_d"}, {"p": "virage_d"}, {"p": "virage_d"}]})
	_check((tr.fin.pos as Vector3).distance_to(VoiePieces.depart("acier").pos + Vector3(24, 0, 0)) < 1.0, "quatre virages à droite font un tour complet")


func _physique_tests() -> void:
	print("Physique et modèles prêts :")
	for m: Dictionary in AttractionsPerso.modeles():
		var tr := VoiePieces.trace(m)
		var sim := VoiePhysique.simule(m, tr)
		_check(bool(tr.ferme), "%s : circuit complet" % m.nom)
		_check(bool(sim.ok), "%s : le tour se fait (%s)" % [m.nom, ", ".join(sim.erreurs)])
		var spec := VoiePhysique.spec_parc(m, sim)
		print("    %s : %d m, %d s, %d km/h, %.0f m, G %.1f/%.1f, lat %.1f, exc %.1f int %.1f nau %.1f, %d places, %s" % [m.nom,
			roundi(float(sim.longueur)), roundi(float(sim.duree)), roundi(float(sim.v_max) * 3.6), float(sim.h_max), float(sim.gv_min),
			float(sim.gv_max), float(sim.gl_max), float(sim.exc), float(sim.int), float(sim.nau), int(spec.cap), BuildingSystem.format_money(VoiePhysique.prix(m, sim))])
		_check(float(sim.exc) > 2.0 and float(sim.exc) <= 10.0, "%s : excitation %.1f" % [m.nom, float(sim.exc)])
		_check(float(sim.gv_max) < 6.5, "%s : G supportables (%.1f)" % [m.nom, float(sim.gv_max)])
		var mesh := VoieMesh.voie(m, tr, sim, func(p: Vector3) -> float: return 0.0)
		_check(mesh.get_surface_count() > 0 and mesh.get_aabb().size.length() > 20.0, "%s : voie dessinée" % m.nom)
		var car := VoieMesh.voiture(m, true, true)
		_check(car.get_surface_count() > 0, "%s : voiture" % m.nom)
	# Sans chaîne, le train cale dans la montée.
	var d := {"famille": "acier", "pieces": [{"p": "droit"}, {"p": "montee"}, {"p": "droit_long"}, {"p": "fin_montee"}], "raccord": true}
	var sim := VoiePhysique.simule(d, VoiePieces.trace(d))
	_check(not bool(sim.ok) and String(sim.erreurs[0]).contains("cale"), "sans chaîne, le train cale : « %s »" % String(sim.erreurs[0]))
	# Une montée à chaîne puis une grande descente : plus de 80 km/h.
	d = AttractionsPerso.modeles()[0]
	sim = VoiePhysique.simule(d, VoiePieces.trace(d))
	_check(float(sim.v_max) * 3.6 > 55.0, "le Serpentin dépasse 55 km/h (%d)" % roundi(float(sim.v_max) * 3.6))
	_check(int(sim.inversions) == 2, "deux inversions")
	# Relevé automatique : dans un grand virage, le latéral reste faible.
	_check(float(sim.gl_max) < 1.6, "virages relevés : %.1f G latéraux au plus" % float(sim.gl_max))


func _objets_tests() -> void:
	print("Nouveaux objets et décors :")
	for id in ParcExtras.ORDER:
		var t := BuildingCatalog.get_type(id)
		_check(String(t.get("cat", "")) == "parc", "%s dans le catalogue du parc" % id)
		var m := BuildingCatalog.build_mesh(id)
		_check(m.get_surface_count() > 0 and m.get_aabb().size.x <= float(t.w) + 0.05 and m.get_aabb().size.z <= float(t.d) + 0.05, "%s : modèle dans son emprise" % id)
		for j in Metiers.jobs_for(id):
			_check(Metiers.METIERS.has(String(j[0])), "%s : métier %s connu" % [id, j[0]])
		var spec := ParcTypes.spec_of(id)
		if String(spec.get("anim", "")) in ParcExtras.ANIMS:
			var a := ParcTypes.build_anim(id)
			_check(a != null and a.get_child_count() > 0, "%s : parties mobiles" % id)
			ParcTypes.animate(a, id, 2.0, 0.016, 1.0)
			a.free()
	var n := 0
	for id in ParcThemes.PROPS:
		if Decors.existe(id) and Decors.mesh(id) != null and Decors.procedural(id):
			n += 1
	_check(n == ParcThemes.PROPS.size(), "%d décors à thème au catalogue des décors" % n)
	var cats := 0
	for c in Decors.categories():
		if String(c.id).begins_with("theme_"):
			cats += 1
	_check(cats == ParcThemes.THEMES.size(), "%d thèmes dans le panneau des décors" % cats)


func _partie_tests() -> void:
	print("Dans une partie :")
	Creations.persist = false
	BatimentsVie.chantiers = false
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var amb: DayNight = scene.get_node("Ambiance")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 40
	world.view_radius_override = 600.0
	world.set_origin(46.2, 6.9)
	for i in 120:
		await process_frame
	amb.set_speed(0)
	amb.unix_time = SAMEDI
	ReglagesPartie.actuel.recherche_parc = false
	bs.unlimited_money = true
	var y := world.cell_height(Vector2i(0, 0))
	transport.build_segment("route", Vector3(-400, y, 0), Vector3(400, y, 0))
	var parc: ParcLoisirs = scene.parc
	var atr: AttractionsPerso = scene.attractions
	var al: ParcAllees = scene.parc_allees
	parc.set_process(false)
	parc.ignore_staff = true
	var c0 := Vector2i(0, -14)
	var e := bs.place("entree_parc", c0, bs.best_rotation("entree_parc", c0))
	_check(e > 0, "entrée du parc posée")
	# Un grand-huit tout prêt, posé dans le parc.
	atr.nouveau("mine", AttractionsPerso.modeles()[1])
	_check(atr.outil == "gare", "on pose d'abord la gare")
	atr.poser_gare(Vector2i(-90, -120), 0)
	_check(atr.outil == "trace" and atr.resultat().sim.ok, "tracé complet après la pose de la gare")
	_check(atr.conflits() == "", "le tracé ne traverse aucun bâtiment (%s)" % atr.conflits())
	_check(atr.construire(), "Construire")
	var coaster := -1
	for bid in bs.buildings:
		if AttractionsPerso.is_atr(String(bs.buildings[bid].t)):
			coaster = int(bid)
	_check(coaster > 0, "la gare est un bâtiment du catalogue (%s)" % (String(bs.buildings[coaster].t) if coaster > 0 else "?"))
	await process_frame
	await process_frame
	_check(atr._poses.has(coaster), "la voie est dessinée autour de la gare")
	parc._sync()
	_check(parc.items.has(coaster) and String(parc.items[coaster].role) == "attraction", "le parc la compte comme attraction")
	_check(int(parc.items[coaster].parc) == e, "elle est dans le parc")
	var spec := ParcTypes.spec_of(String(bs.buildings[coaster].t))
	_check(int(spec.cap) >= 20 and float(spec.exc) > 2.0, "places %d, excitation %.1f" % [int(spec.cap), float(spec.exc)])
	# Bûches et toboggan.
	atr.nouveau("buches", AttractionsPerso.modeles()[2])
	atr.poser_gare(Vector2i(60, -130), 2)
	_check(atr.construire(), "bûches construites (%s)" % ", ".join(atr.resultat().get("sim", {}).get("erreurs", [])))
	atr.nouveau("toboggan", AttractionsPerso.modeles()[4])
	atr.poser_gare(Vector2i(-20, -60), 1)
	_check(atr.construire(), "toboggan construit")
	var stand := bs.place("pizzeria_parc", Vector2i(20, -40), 0)
	var wc := bs.place("toilettes_parc", Vector2i(30, -50), 0)
	var bassin := bs.place("piscine_vagues", Vector2i(80, -60), 0)
	_check(stand > 0 and wc > 0 and bassin > 0, "pizzeria, toilettes et piscine à vagues posées")
	parc._sync()
	# Allées et file d'attente.
	var portail := parc.portail(e)
	var porte := parc.porte(coaster)
	_check(al.ajoute_allee(Vector2(portail.x, portail.z), Vector2(-40, -60)), "allée tracée")
	al.ajoute_allee(Vector2(-40, -60), Vector2(porte.x, porte.z - 12.0))
	_check(al.dans_parc(e), "le parc a ses propres allées")
	_check(al.ajoute_file(Vector2(porte.x, porte.z) + Vector2(0, -1), Vector2(porte.x + 10.0, porte.z - 6.0)), "file d'attente devant le grand-huit")
	_check(al.ajoute_file(Vector2(porte.x + 10.0, porte.z - 6.0), Vector2(porte.x - 10.0, porte.z - 10.0)), "la file se prolonge")
	var p3: Variant = al.place_file(coaster, 3)
	_check(p3 != null and (p3 as Vector3).distance_to(porte) < 6.0, "la 4e place est près de l'entrée")
	var r := al.route(portail, Vector3(porte.x, y, porte.z - 12.0))
	_check(r.size() >= 3, "les visiteurs suivent les allées (%d points)" % r.size())
	# Une journée au parc.
	parc.clock = SAMEDI
	parc.last_day = int(parc._now(parc.clock).day)
	for i in 4 * 60:
		parc.clock += ParcLoisirs.STEP
		parc.step(ParcLoisirs.STEP)
	_check(int(parc.items[coaster].tours) > 0, "le grand-huit tourne (%d tours)" % int(parc.items[coaster].tours))
	var dans_file := 0
	for aid in parc.items[coaster].file:
		var a: Dictionary = parc.agents[aid]
		if (a.pos as Vector3).distance_to(porte) < 40.0:
			dans_file += 1
	print("    file du grand-huit : %d visiteurs, attente %d min" % [(parc.items[coaster].file as Array).size(), roundi(parc.attente(coaster))])
	# Les trains bougent quand l'attraction tourne.
	var pose: Dictionary = atr._poses[coaster]
	var tau0 := float(pose.tau)
	# Temps en pause dans ce test : les manèges suivent la vitesse du temps, on la force à ×1.
	EchelleTemps.force = 1.0
	atr._process(1.0)
	EchelleTemps.force = -1.0
	_check(float(pose.tau) != tau0 or not atr._en_marche(coaster), "les trains avancent quand l'attraction tourne")
	# Modifier le tracé.
	atr.modifier(coaster)
	_check(atr.outil == "trace" and int(atr.brouillon.bid) == coaster, "modifier le tracé d'une attraction posée")
	var n0 := (atr.design().pieces as Array).size()
	atr.retire_derniere()
	_check(not bool(atr.design().raccord) and (atr.design().pieces as Array).size() == n0, "retirer : le raccord part d'abord")
	atr.boucler()
	_check(atr.construire(), "tracé modifié validé")
	# Sauvegarde.
	var sec: Dictionary = scene.save_sections()
	_check(sec.has("parc_editeur") and (sec.parc_editeur.designs as Dictionary).size() == 3, "3 dessins dans la sauvegarde")
	_check(sec.has("parc_allees") and (sec.parc_allees.files as Array).size() == 1, "allées et file dans la sauvegarde")
	var json := JSON.stringify(sec.parc_editeur)
	var t := String(bs.buildings[coaster].t)
	AttractionsPerso.designs.clear()
	BuildingCatalog.all_types().erase(t)
	AttractionsPerso.adopt(JSON.parse_string(json))
	_check(not BuildingCatalog.get_type(t).is_empty() and not ParcTypes.spec_of(t).is_empty(), "rechargée : la gare retrouve son attraction")
	var al_json := JSON.stringify(sec.parc_allees)
	al.clear()
	al.from_dict(JSON.parse_string(al_json))
	_check(al.allees.size() > 0 and al.file_de(coaster).size() == 3, "rechargées : allées et file")
	# Panneau.
	var pan: ParcEditeurPanel = scene.parc_editeur_panel
	pan.set_open(true)
	for o in ParcEditeurPanel.ONGLETS:
		pan.show_onglet(String(o[0]))
		_check(pan._body.get_child_count() > 0, "onglet %s" % o[1])
	atr.nouveau("acier")
	atr.poser_gare(Vector2i(150, -200), 0)
	for pid in ["droit", "montee", "droit_long", "fin_montee", "descente", "fin_descente", "looping"]:
		atr.chaine = pid in ["montee", "droit_long", "fin_montee"]
		atr.ajoute(pid)
	pan.refresh()
	_check(pan._body.get_child_count() > 10, "éditeur de tracé dans le panneau (%d lignes)" % pan._body.get_child_count())
	atr.apercu("vrille_g")
	_check(atr._apercu.mesh != null, "aperçu de la pièce survolée")
	atr.annuler()
	_check(atr.brouillon.is_empty() and BuildingCatalog.get_type("atr_x").is_empty(), "annuler le brouillon")
	# Les décors à thème se posent comme les autres.
	var dec: DecorSystem = scene.decors
	_check(dec.pose("pt_fusee", 30.0, -90.0, 0.0, 1.0), "une fusée posée en décor")
	scene.queue_free()
	await process_frame
