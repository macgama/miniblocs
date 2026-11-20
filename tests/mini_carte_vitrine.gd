extends SceneTree
## Captures de la mini-carte sur le vrai relief (Vulliens, Vaud) : vue d'ensemble,
## carte en couleur reprise de N, ressource de P, vue large 16 km.
## Usage (avec affichage, réseau pour le relief) :
##   LANG=fr_FR.UTF-8 godot --path . --rendering-driver opengl3 --script res://tests/mini_carte_vitrine.gd -- --dossier /chemin/captures


func _initialize() -> void:
	_run.call_deferred()


var _mc: MiniCarte


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var dir := "."
	for i in args.size() - 1:
		if args[i] == "--dossier":
			dir = args[i + 1]
	DirAccess.make_dir_recursive_absolute(dir)
	root.size = Vector2i(1600, 900)
	Creations.persist = false
	AffichagePanneaux.persist = false
	BatimentsVie.chantiers = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(MiniCarte.PREFS))
	GameStart.place_name = "Vulliens (Vaud), Suisse"
	var game: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = game.get_node("Terrain")
	root.add_child(game)
	world.set_origin(46.6236, 6.7925)
	var mc: MiniCarte = game.mini_carte
	_mc = mc
	var rig: Node3D = game.rig
	# Relief et biomes : on attend qu'ils arrivent (réseau).
	for i in 900:
		await process_frame
		if i % 60 == 0 and world.tiles.pending_count() == 0 and world.land.pending_count() == 0 and i > 240:
			break
	rig.position = Vector3(0, rig.position.y, 0)
	for i in 600:
		await process_frame
		if world.missing_chunk_count() == 0 and not is_nan(world.raw_height(0, 0)) and i > 60:
			break
	mc._fond_rect = Rect2()
	await _frames(60)
	# Un village, quelques routes et maisons, un incendie.
	game.buildings.require_access = false
	var y := world.cell_height(Vector2i(0, 0))
	y = 0.0 if is_nan(y) else y
	var tr: TransportSystem = game.transport
	game.communes.fonder_au_point("Vulliens", Vector2(0, 0))
	game.communes.fonder_au_point("Les Granges", Vector2(2600, -1400))
	_voie(tr, "departementale", Vector3(-900, y, 0), Vector3(900, y, 0))
	_voie(tr, "departementale", Vector3(0, y, -700), Vector3(0, y, 600))
	_voie(tr, "rue", Vector3(-300, y, -200), Vector3(300, y, -200))
	_voie(tr, "rue", Vector3(-300, y, 200), Vector3(300, y, 200))
	_voie(tr, "voie_verte", Vector3(-500, y, 450), Vector3(500, y, 380))
	for i in 24:
		var x := -260 + (i % 12) * 45
		var z := -170 if i < 12 else 170
		game.buildings.place("maison", Vector2i(x, z), 0)
	game.buildings.place("immeuble", Vector2i(60, -60), 0)
	game.buildings.place("maison", Vector2i(2600, -1380), 0)
	Evenements.instance.declarer({"type": "incendie", "position": Vector3(-180, y, 170), "gravite": 2, "besoin": ["pompiers"]})
	var bid: int = game.buildings.place("maison", Vector2i(700, 300), 0)
	if bid >= 0:
		game.reseaux.raccordements.manques[bid] = [["elec", Raccordements.NON_RACCORDE]]
	rig.position = Vector3(0, y, 0)
	rig._target_distance = rig.max_distance
	rig.set_pitch(60.0, true)
	mc.set_zoom(2)
	mc._t_alertes = 0.0
	mc._t_statique = 0.0
	mc._salir()
	await _frames(90)
	_capture(dir, "1-mini-carte-ensemble")
	# Couleurs de N (pollution de l'air) puis de P (bois).
	Calques.afficher("immobilier_valeur", true)
	await _frames(40)
	_capture(dir, "2-mini-carte-calque-N")
	Calques.eteindre()
	game.resource_overlay.show_resource("bois")
	await _frames(40)
	_capture(dir, "3-mini-carte-ressource-P")
	game.resource_overlay.show_resource("")
	mc.set_zoom(4)
	mc._fond_rect = Rect2()
	await _frames(150)
	_capture(dir, "4-mini-carte-16-km")
	quit()


func _voie(tr: TransportSystem, id: String, a: Vector3, b: Vector3) -> void:
	var r := tr.build_segment(id, a, b)
	print("voie %s : %s %s" % [id, r.get("ok", false), r.get("reason", "")])


func _capture(dir: String, nom: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(dir.path_join(nom + ".png"))
	var mc: MiniCarte = _mc
	var r := mc._cadre.get_global_rect().grow(6)
	var zoom := img.get_region(Rect2i(r))
	zoom.resize(int(r.size.x * 2), int(r.size.y * 2), Image.INTERPOLATE_NEAREST)
	zoom.save_png(dir.path_join(nom + "-zoom.png"))
	print("capture : ", dir.path_join(nom + ".png"))
