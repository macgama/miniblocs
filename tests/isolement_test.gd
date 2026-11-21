extends SceneTree
## Bâtiment isolé (IsolementBatiment) : au clic sur un bâtiment, la caméra le
## cadre, la ville pâlit (voile + voisins transparents), les cartes se rangent et
## seule la fiche reste ; Échap, la croix de la fiche ou « Toute la ville »
## rétablit tout (caméra, cartes, bâtiments), sans toucher au choix d'affichage
## du joueur.
## Usage : godot --headless --path . --script res://tests/isolement_test.gd
## Captures (avec affichage) : ajouter --rendering-driver opengl3 … -- --dossier /chemin

var ok := true
var scene: Node
var dir := ""


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	if not cond:
		push_error("ÉCHEC : " + what)
		ok = false
	else:
		print("  ok  ", what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


func _touche(code: Key) -> void:
	var k := InputEventKey.new()
	k.keycode = code
	k.physical_keycode = code
	k.pressed = true
	root.push_input(k)
	await process_frame
	k = k.duplicate()
	k.pressed = false
	root.push_input(k)
	await process_frame


func _shot(nom: String) -> void:
	await _frames(14)
	if dir == "" or DisplayServer.get_name() == "headless":
		return
	var path := dir.path_join(nom)
	root.get_viewport().get_texture().get_image().save_png(path)
	print("capture : ", path)


func _place(bs: BuildingSystem, id: String, x: int, side := -1) -> int:
	var d := int(BuildingCatalog.get_type(id).d)
	var c := Vector2i(x, side * (d / 2 + 6))
	return bs.place(id, c, bs.best_rotation(id, c))


func _bouton(n: Node, texte: String) -> Button:
	for b in n.find_children("*", "Button", true, false):
		if (b as Button).text == texte and (b as Button).is_visible_in_tree():
			return b
	return null


func _run() -> void:
	print("Bâtiment isolé au clic")
	var args := OS.get_cmdline_user_args()
	for i in args.size() - 1:
		if args[i] == "--dossier":
			dir = args[i + 1]
	Creations.persist = false
	AffichagePanneaux.persist = false
	OptionsJeu.isoler_batiment = true
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_size = Vector2i(1600, 900)
	root.size = Vector2i(1600, 900)
	BatimentsVie.chantiers = false
	ReglagesPartie.actuel.construction_instantanee = true
	ReglagesPartie.actuel.deblocage = "tout"
	scene = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var amb: DayNight = scene.get_node("Ambiance")
	root.add_child(scene)
	Langue.activer("fr")
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 40
	world.view_radius_override = 900.0
	world.set_origin(46.2, 6.9)
	await _frames(150)
	amb.set_speed(0)
	if Guide.instance != null:
		Guide.instance.proposer = false
	amb.unix_time = Time.get_unix_time_from_datetime_string("2026-06-10T15:00:00")
	bs.unlimited_money = true
	bs.require_access = false
	var pop: Population = scene.population
	var y := world.cell_height(Vector2i(0, 0))
	transport.build_segment("route", Vector3(-200, y, 0), Vector3(200, y, 0))
	var maisons: Array = []
	for i in 8:
		maisons.append(_place(bs, "maison", -90 + i * 22, 1))
	for i in 3:
		_place(bs, "immeuble", -60 + i * 30, -1)
	_place(bs, "bureaux", 60, -1)
	if SuiviChantiers.instance:
		SuiviChantiers.instance.terminer_tout()
	await process_frame
	pop._sync_buildings()
	pop.follow_camera = false
	for i in 24:
		pop.advance(300.0)
	pop.vie.follow(-1)

	var iso: IsolementBatiment = scene.isolement
	var hp: HabitantsPanel = scene.habitants_panel
	var aff: AffichagePanneaux = scene.affichage
	var rig: Node3D = scene.get_node("CameraRig")
	_check(iso != null, "le module d'isolement est posé dans la scène")
	rig.position = Vector3(0, y, 20)
	rig._target_distance = 160.0
	rig.set_pitch(55.0, true)
	rig.rotation_degrees.y = 0.0
	await _frames(20)
	# Cartes visibles avant le clic (jauges, mini-carte, carte de la case…).
	var avant := {}
	for id in aff.ids():
		var c := aff.carte(id)
		if c != null and c.visible:
			avant[id] = true
	_check(avant.size() >= 2, "des cartes d'information sont visibles avant le clic (%s)" % ", ".join(avant.keys()))
	await _shot("1-avant-le-clic.png")

	var m1: int = maisons[3]
	var m2: int = maisons[5]
	pop.select_building(m1)
	await _frames(30)
	_check(iso.actif() and iso.bid == m1, "un clic sur une maison l'isole")
	_check(hp.is_open() and hp.view == "batiment", "la fiche du bâtiment est ouverte")
	_check(iso._voile.visible, "le voile qui fait pâlir la ville est affiché")
	_check(absf(float(rig._target_distance) - 160.0) > 20.0, "la caméra se rapproche pour cadrer le bâtiment (%.0f m)" % float(rig._target_distance))
	var voisin := bs.node_of(maisons[4])
	_check(voisin != null and voisin.transparency > 0.5, "les bâtiments voisins deviennent transparents")
	_check(bs.node_of(m1).transparency == 0.0, "le bâtiment cliqué reste opaque")
	_check(iso.nb_fantomes() >= 8, "%d pièces de bâtiments voisins en fantômes" % iso.nb_fantomes())
	var ranges := 0
	for id in avant:
		var c := aff.carte(String(id))
		if c != null and not c.visible:
			ranges += 1
	_check(ranges == avant.size(), "toutes les cartes d'information se rangent (%d/%d)" % [ranges, avant.size()])
	_check(aff.masques.is_empty(), "le choix d'affichage du joueur n'est pas modifié")
	_check(not pop._marker.visible, "la boîte de sélection bleue disparaît")
	var b := _bouton(hp._panel, "Toute la ville")
	_check(b != null, "la fiche propose « Toute la ville »")
	var tr: Vector4 = iso._mat.get_shader_parameter("trou")
	_check(tr.z > 0.01 and tr.z < 0.5 and tr.x > 0.1 and tr.x < 0.9, "le trou du voile entoure le bâtiment à l'écran (%s)" % str(tr))
	await _shot("2-maison-isolee.png")

	pop.select_building(m2)
	await _frames(20)
	_check(iso.actif() and iso.bid == m2, "un clic sur une autre maison passe à celle-ci")
	_check(bs.node_of(m1).transparency > 0.5 and bs.node_of(m2).transparency == 0.0, "l'ancienne devient fantôme, la nouvelle opaque")

	await _touche(KEY_ESCAPE)
	await _frames(30)
	_check(not iso.actif(), "Échap sort de l'isolement")
	_check(not hp.is_open(), "Échap ferme la fiche")
	_check(scene.pause_menu == null, "Échap n'ouvre pas le menu pause")
	_check(voisin.transparency == 0.0 and iso.nb_fantomes() == 0, "les bâtiments redeviennent opaques")
	_check(not iso._voile.visible, "le voile disparaît")
	_check(absf(float(rig._target_distance) - 160.0) < 0.5, "la caméra revient où elle était")
	var revenues := 0
	for id in avant:
		var c := aff.carte(String(id))
		if c != null and c.visible:
			revenues += 1
	_check(revenues == avant.size(), "les cartes reviennent (%d/%d)" % [revenues, avant.size()])
	await _shot("3-apres-echap.png")

	# La croix de la fiche rétablit tout aussi.
	pop.select_building(m1)
	await _frames(10)
	_check(iso.actif(), "nouvel isolement")
	hp.set_open(false)
	await _frames(10)
	_check(not iso.actif() and voisin.transparency == 0.0, "fermer la fiche rétablit tout")

	# « Toute la ville » : la fiche reste, la ville revient ; « Isoler » y retourne.
	pop.select_building(m1)
	await _frames(10)
	b = _bouton(hp._panel, "Toute la ville")
	if b != null:
		b.pressed.emit()
	await _frames(20)
	_check(not iso.actif() and hp.is_open() and hp.view == "batiment", "« Toute la ville » : fiche gardée, ville rétablie")
	_check(pop._marker.visible, "la boîte de sélection revient")
	b = _bouton(hp._panel, "Isoler")
	_check(b != null, "la fiche propose « Isoler »")
	await _shot("4-toute-la-ville-fiche-gardee.png")
	b = _bouton(hp._panel, "Isoler")
	if b != null:
		b.pressed.emit()
	await _frames(10)
	_check(iso.actif(), "« Isoler » isole à nouveau")

	# Un lien vers un habitant (autre vue de la fiche) sort de l'isolement.
	hp.show_view("ville")
	await _frames(10)
	_check(not iso.actif(), "changer de vue dans le panneau rétablit tout")
	hp.set_open(false)

	# Option désactivée : le clic ouvre la fiche sans isoler.
	OptionsJeu.isoler_batiment = false
	pop.select_building(m1)
	await _frames(10)
	_check(hp.is_open() and not iso.actif(), "option désactivée : fiche sans isolement")
	hp.set_open(false)
	OptionsJeu.isoler_batiment = true

	# Signaux pour la future gestion du bâtiment (tycoon).
	var vus: Array = []
	iso.entree.connect(func(x: int) -> void: vus.append(["entree", x]))
	iso.sortie.connect(func(x: int) -> void: vus.append(["sortie", x]))
	pop.select_building(m2)
	await _frames(5)
	pop.select_building(-1)
	await _frames(5)
	_check(vus == [["entree", m2], ["sortie", m2]], "signaux entree / sortie émis (%s)" % str(vus))

	print("RÉSULTAT : ", "OK" if ok else "ÉCHEC")
	quit(0 if ok else 1)
