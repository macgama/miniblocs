extends SceneTree
## Vitrine de la carte entre amis : fenêtre « Entre amis » du menu principal et
## panneau F3 en jeu (joueurs, code, discussion).
## Usage : xvfb-run godot --path . --script res://tests/multijoueur_vitrine.gd -- --dossier captures/multijoueur

var dir := "."


func _initialize() -> void:
	_run.call_deferred()


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(35.0)
	return a


func _shot(name: String, frames := 10) -> void:
	for i in frames:
		await process_frame
	var path := dir.path_join(name)
	root.get_viewport().get_texture().get_image().save_png(path)
	print("capture : ", path)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size() - 1:
		if args[i] == "--dossier":
			dir = args[i + 1]
	DirAccess.make_dir_recursive_absolute(dir)
	root.size = Vector2i(1600, 900)
	OptionsJeu.charger()
	OptionsJeu.anticrenelage = 0
	OptionsJeu.titre_fixe = true
	root.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	var menu: MenuPrincipal = load("res://scenes/menu_principal.tscn").instantiate()
	root.add_child(menu)
	root.msaa_3d = Viewport.MSAA_DISABLED
	await _shot("menu-titre-amis.png", 30)
	menu.ouvrir_amis()
	var p: MultijoueurPanel = menu._sub
	p._adresse.text = "192.168.1.20"
	p._code.text = "KX7P-M2QD"
	p._pseudo.text = "Gaël"
	p._etat.text = "Connexion à 192.168.1.20:24680…"
	await _shot("entre-amis.png", 10)
	menu.queue_free()
	await process_frame

	Creations.persist = false
	GameStart.mode = GameStart.Mode.BAC_A_SABLE
	GameStart.load_slot = ""
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.set_origin(45.9, 6.13)
	scene.communes.nom_en_attente = "Valfleuri"
	scene.buildings.place("maison_commune", Vector2i(0, 0), 0)
	scene.ambiance.set_speed(0)
	scene.ambiance.set_local_hour(11.0)
	scene.ambiance.set_jour_permanent(true)
	scene.rig._target_distance = 220.0
	for i in 160:
		await process_frame
	var c := ClientAmis.new()
	c.admin = true
	c.nom_carte = "Annecy entre amis"
	c.hote = "192.168.1.20"
	c.pseudo = "Gaël"
	c.code_carte = "KX7P-M2QD"
	c.joueurs = [{"pid": "a", "pseudo": "Gaël", "admin": true, "en_ligne": true, "villes": ["Valfleuri"]},
		{"pid": "b", "pseudo": "Léa", "admin": false, "en_ligne": true, "villes": ["Les Granges"]},
		{"pid": "c", "pseudo": "Max", "admin": false, "en_ligne": false, "villes": []}]
	root.add_child(c)
	var jp := JoueursPanel.new(c)
	scene._windows_layer().add_child(jp)
	await process_frame
	c.chat_recu.emit("", "Léa a rejoint la carte.")
	c.chat_recu.emit("Léa", "Je fonde Les Granges de l'autre côté du lac !")
	c.chat_recu.emit("Gaël", "Super, je fais la route jusqu'à chez toi.")
	await _shot("joueurs-f3.png", 20)
	quit()
