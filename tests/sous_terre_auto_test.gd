extends SceneTree
## Test de la vue sous terre automatique (scripts/souterrain/sous_terre_auto.gd) :
## un outil qui construit sous le sol, pris dans n'importe quel menu (O, Maj+O,
## Voies → Métro, Construire → Sous terre), passe la vue en sous-sol au bon
## niveau, puis la ramène en surface quand on le range ; bouton « Sous terre »
## dans la barre du bas ; panneau Sous-sol en images avec l'électricité enterrée.
## Usage : godot --headless --path . --script res://tests/sous_terre_auto_test.gd
## Captures (avec affichage) : ajouter -- --dossier /chemin/captures

var ok := true
var dossier := ""


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


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(nom: String) -> void:
	if dossier == "":
		return
	await _frames(12)
	var path := dossier.path_join(nom)
	root.get_viewport().get_texture().get_image().save_png(path)
	print("capture : ", path)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size() - 1:
		if args[i] == "--dossier":
			dossier = args[i + 1]
	root.size = Vector2i(1600, 900)
	Creations.persist = false
	BatimentsVie.chantiers = false
	ReglagesPartie.actuel.construction_instantanee = true
	ReglagesPartie.actuel.cout_construction = 1.0
	var CS := ConstructionSouterraine

	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var amb: DayNight = scene.get_node("Ambiance")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 40
	world.view_radius_override = 700.0
	world.set_origin(46.2, 6.9)
	await _frames(150)
	amb.set_speed(0)
	amb.unix_time = Time.get_unix_time_from_datetime_string("2026-06-10T15:00:00")
	bs.unlimited_money = false
	bs.money = 500_000_000
	ReglagesPartie.actuel.construction_instantanee = true
	ReglagesPartie.actuel.cout_construction = 1.0
	var res: Reseaux = scene.reseaux
	var tel: Telecom = scene.telecom
	var vs: VueSouterraine = scene.souterrain
	var cs: ConstructionSouterraine = scene.construction_souterraine
	var auto: SousTerreAuto = scene.sous_terre_auto
	var hud = scene.hud
	var rig: Node3D = scene.get_node("CameraRig")
	var y := world.cell_height(Vector2i(0, 0))
	transport.build_segment("route", Vector3(-160, y, 0), Vector3(160, y, 0))
	bs.place("maison", Vector2i(-100, 12), bs.best_rotation("maison", Vector2i(-100, 12)))
	await _frames(10)
	rig.global_position = Vector3(0, y, 20)
	rig.set("_target_distance", 230.0)
	rig.set_pitch(50.0, true)
	_check(auto != null and auto.vue == vs and auto.construction == cs, "la vue automatique est branchée")

	print("Barre du bas :")
	var tuile: Button = hud._cat_buttons.get("souterrain")
	_check(tuile != null and tuile.icon != null and tuile.text == "Sous terre", "bouton « Sous terre » en image (%s)" % (tuile.text if tuile else "aucun"))
	_check(tuile != null and tuile.is_visible_in_tree(), "visible dans la barre du bas, pas caché dans un menu")
	tuile.pressed.emit()
	await _frames(3)
	_check(vs.actif and vs.niveau == 1 and tuile.button_pressed, "un clic ouvre la vue au −1, bouton allumé")
	await _shot("1-bouton-sous-terre.png")
	tuile.pressed.emit()
	await _frames(3)
	_check(not vs.actif and not tuile.button_pressed, "un second clic revient en surface")

	print("Panneau Sous-sol en images :")
	var sans_image := []
	for k in cs._boutons:
		if (cs._boutons[k] as Button).icon == null:
			sans_image.append(k)
	_check(sans_image.is_empty() and cs._boutons.size() >= 20, "%d outils, tous en image %s" % [cs._boutons.size(), sans_image])
	_check(cs._boutons.has("c:cable_souterrain"), "bouton Électricité (câble enterré) dans Poser")
	for u in CS.USAGE_ORDRE:
		_check(cs._boutons.has("p:" + u), "pièce « %s » en vignette" % CS.USAGES[u].name)
	for t in ["sous_eau", "sous_egout", "sous_gaz", "sous_elec", "sous_fibre", "sous_metro", "sous_rue", "sous_2x2", "sous_train"]:
		_check(Pictos.get_picto(t, 60) != null, "dessin %s" % t)

	print("Réseaux (O) : conduite d'eau")
	res.set_outil(Reseaux.Outil.TRACER, "conduite_eau")
	await _frames(3)
	_check(vs.actif and vs.niveau == 1, "la vue passe seule au Sous-sol −1")
	_check(cs.outil == CS.Outil.CONDUITE and cs.type_conduite == "conduite_eau" and auto.auto_ouverte, "l'outil passe dans le panneau Sous-sol")
	_check(res.outil == Reseaux.Outil.TRACER and res.type_troncon == "conduite_eau" and not is_nan(res.profondeur_pose), "le traceur reste en main, à la profondeur du niveau")
	_check((cs._boutons["c:conduite_eau"] as Button).button_pressed, "vignette Eau enfoncée")
	await _shot("2-conduite-eau-auto.png")
	cs.echap()
	await _frames(3)
	_check(not vs.actif and res.outil == Reseaux.Outil.AUCUN, "Échap range l'outil et revient en surface")
	res.set_outil(Reseaux.Outil.TRACER, "ligne_ht")
	await _frames(3)
	_check(not vs.actif, "une ligne haute tension reste en surface")
	res.set_inactive()

	print("Câble électrique enterré :")
	res.set_outil(Reseaux.Outil.TRACER, "cable_souterrain")
	await _frames(3)
	_check(vs.actif and cs.outil == CS.Outil.CONDUITE and cs.type_conduite == "cable_souterrain", "le câble souterrain ouvre la vue")
	vs.set_niveau(3)
	_check(is_equal_approx(res.profondeur_pose, 7.5), "au −3, le câble descend à 7,5 m")
	var pts := res.trace_sur_relief(Vector3(-150, y, -40), Vector3(150, y, -40))
	var m0 := bs.money
	var cid := res.poser("cable_souterrain", pts)
	_check(cid >= 0 and is_equal_approx(float(res.elec.troncons[cid].get("prof", 0.0)), 7.5), "câble posé à 7,5 m de fond")
	var base := ReseauxTypes.prix_troncon("cable_souterrain", ReseauBase.longueur(pts))
	_check(m0 - bs.money == roundi(base * CS.facteur_profondeur(7.5)), "payé au prix de la profondeur")
	await _frames(2)
	vs.marquer_sale()
	vs._maj()
	_check(int(vs.compte.troncons) >= 1, "il se voit au −3")
	cs.desactiver()
	await _frames(3)
	_check(not vs.actif, "outil rangé : retour en surface")
	var aerien := res.poser("ligne_mt", res.trace_sur_relief(Vector3(-150, y, 80), Vector3(150, y, 80)))
	_check(aerien >= 0 and not res.elec.troncons[aerien].has("prof"), "une ligne sur poteaux n'a pas de profondeur")

	print("Télécoms (Maj+O) :")
	tel.set_outil(Telecom.Outil.CUIVRE_SOUTERRAIN)
	await _frames(3)
	_check(vs.actif and cs.type_conduite == "cuivre_souterrain" and tel.outil == Telecom.Outil.CUIVRE_SOUTERRAIN, "ligne téléphonique enterrée : sous terre")
	_check(not is_nan(tel.profondeur_pose), "posée à la profondeur du niveau")
	_check(cs._info.text.contains("Ligne téléphonique enterrée"), "l'aide nomme le câble (%s)" % cs._info.text)
	cs.echap()
	await _frames(3)
	_check(not vs.actif, "retour en surface")
	tel.set_outil(Telecom.Outil.FIBRE_AERIENNE)
	await _frames(3)
	_check(not vs.actif, "la fibre sur poteaux reste en surface")
	tel.set_inactive()

	print("Voies → Métro :")
	transport.set_build("metro")
	await _frames(3)
	_check(vs.actif and vs.niveau == CS.NIVEAU_MIN_TUNNEL, "le métro ouvre la vue au −3")
	_check(cs.outil == CS.Outil.TUNNEL and cs.type_voie == "metro" and is_equal_approx(RoutePlanner.profondeur_forcee, CS.profondeur_voie(3)), "tunnel de métro en main, voies à 8 m")
	_check(not hud._spec_panel.visible and not hud._hint_panel.visible, "les réglages et l'aide des voies de surface ne passent pas sous le panneau")
	await _shot("3-metro-auto.png")
	vs.sortir()
	await _frames(3)
	_check(not vs.actif and transport.tool == TransportSystem.Tool.BUILD and transport.type_id == "metro", "« Retour en surface » : le métro reste en main, en surface")
	_check(is_nan(RoutePlanner.profondeur_forcee), "en surface : profondeur normale (métro aérien possible)")
	_check(hud._spec_panel.visible, "en surface : les réglages des voies reviennent")
	await _frames(5)
	_check(not vs.actif, "il n'est pas repris tant qu'on le garde")
	transport.set_inactive()
	await _frames(2)
	_check(auto.laisse == "", "outil rangé : la vue automatique repart")

	print("Construire → Sous terre :")
	var bp: BuildingPanel = scene.build_panel
	bp.set_open(true)
	bp.show_category("sous_terre")
	await _frames(3)
	var cartes := bp.find_children("SousTerre_*", "Button", true, false)
	_check(cartes.size() == CS.CONDUITES.size() + CS.VOIES.size() + CS.USAGE_ORDRE.size(), "%d vignettes : conduites, tunnels, pièces" % cartes.size())
	var sans := cartes.filter(func(b: Button) -> bool: return b.icon == null)
	_check(sans.is_empty(), "toutes en image")
	await _shot("4-construire-sous-terre.png")
	var bunker: Button = bp.find_child("SousTerre_bunker", true, false)
	bunker.pressed.emit()
	await _frames(3)
	_check(vs.actif and cs.outil == CS.Outil.PIECE and cs.usage == "bunker", "Bunker : vue sous terre, outil Creuser bunker en main")
	_check(not bp._panel.visible, "le panneau Construire se range")
	_check((cs._boutons["p:bunker"] as Button).button_pressed, "vignette Bunker enfoncée")
	await _shot("5-bunker.png")
	cs.echap()
	await _frames(3)
	_check(not vs.actif, "Échap : retour en surface")
	bp.set_open(true)
	bp.show_category("sous_terre")
	await _frames(2)
	(bp.find_child("SousTerre_train", true, false) as Button).pressed.emit()
	await _frames(3)
	_check(vs.actif and vs.niveau >= CS.NIVEAU_MIN_TUNNEL and cs.outil == CS.Outil.TUNNEL and cs.type_voie == "train", "Tunnel ferroviaire : au −3")
	vs.sortir()
	await _frames(3)
	_check(not vs.actif and transport.tool != TransportSystem.Tool.BUILD, "un tunnel de train ne reste pas en main en surface")

	print("Vue ouverte à la main :")
	vs.set_niveau(4)
	res.set_outil(Reseaux.Outil.TRACER, "collecteur")
	await _frames(3)
	_check(vs.actif and vs.niveau == 4 and cs.outil == CS.Outil.CONDUITE and cs.type_conduite == "collecteur", "un collecteur pris au panneau O se pose au niveau affiché (−4)")
	cs.echap()
	await _frames(3)
	_check(vs.actif, "ouverte à la main : on reste sous terre en rangeant l'outil")
	vs.sortir()
	await _frames(2)

	print("Réglage :")
	SousTerreAuto.active = false
	res.set_outil(Reseaux.Outil.TRACER, "conduite_gaz")
	await _frames(3)
	_check(not vs.actif, "désactivée : la conduite reste en surface")
	res.set_inactive()
	SousTerreAuto.active = true

	print("Vue au sol :")
	var vsol = scene.get_node_or_null("VueSol")
	if vsol:
		vsol.vue_suivante()
	await _frames(5)
	if rig.get_viewport().get_camera_3d() != vs.camera:
		res.set_outil(Reseaux.Outil.TRACER, "conduite_eau")
		await _frames(3)
		_check(not vs.actif, "en vue au sol, pas de bascule")
		res.set_inactive()

	print("RÉSULTAT : ", "OK" if ok else "ÉCHEC")
	quit(0 if ok else 1)
