extends SceneTree
## Vitrine des visites : un village partagé, la visite (bandeau, cartes épinglées
## du livre d'or), la carte postale qu'on écrit (F7), puis le courrier du maire.
## Usage (avec affichage) :
##   xvfb-run -a godot --path . --rendering-driver opengl3 --script res://tests/visites_vitrine.gd -- --dossier /chemin/captures

const RACINE := "user://vitrine_visites"
const SLOT_A := "vitrine-visite-maire"
var dossier := "user://"


func _initialize() -> void:
	_run.call_deferred()


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


func _shot(nom: String) -> void:
	for i in 20:
		await process_frame
	var path := dossier.path_join(nom)
	root.get_viewport().get_texture().get_image().save_png(path)
	print("capture : ", path)


func _scene() -> Node:
	GameStart.chosen = true
	GameStart.load_slot = ""
	GameStart.place_name = "Valfleuri, Savoie"
	ReglagesPartie.prochaine = ReglagesPartie.preset("normal")
	ReglagesPartie.prochaine.fondateurs = 0
	ReglagesPartie.prochaine.tutoriel = false
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
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
	Langue.activer("fr")
	return scene


func _camera(scene: Node, x: float, z: float, dist: float, angle: float, pitch: float) -> void:
	var rig: Node3D = scene.rig
	rig.position.x = x
	rig.position.z = z
	rig._target_distance = dist
	rig.rotation_degrees.y = angle
	rig.set_pitch(pitch, true)
	scene._snap_pending = true


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--dossier" and i + 1 < args.size():
			dossier = args[i + 1]
	DirAccess.make_dir_recursive_absolute(dossier)
	Langue.activer("fr")
	Creations.persist = false
	Succes.persist = false
	BatimentsVie.chantiers = false
	Partage.echange = RACINE.path_join("echange")
	VisiteVille.dossier = RACINE.path_join("villes")
	VisiteVille.envoyees_path = RACINE.path_join("envoyees.json")
	VisiteVille.changer_scene = false
	DirAccess.make_dir_recursive_absolute(Partage.echange)

	var a: Node = await _scene()
	var bs: BuildingSystem = a.buildings
	a.communes.nom_en_attente = "Valfleuri"
	bs.place("maison_commune", Vector2i(-1000, 0), 0)
	for i in 6:
		await process_frame
	for x in range(-1060, -940, 4):
		for z in [-28, -4, 30]:
			for r in 4:
				var chk := bs.check_place("maison", Vector2i(x, z), r)
				if chk.ok and not (chk.access as Dictionary).is_empty():
					bs.place("maison", Vector2i(x, z), r)
					break
	for x in range(-1010, -990, 6):
		for z in range(-160, -80, 6):
			var chk := bs.check_place("maison", Vector2i(x, z), 1)
			if chk.ok and not (chk.access as Dictionary).is_empty():
				bs.place("maison", Vector2i(x, z), 1)
	var cr: Courrier = a.courrier
	cr.accueil = "Bienvenue à Valfleuri ! Ne ratez pas la mairie toute neuve."
	cr.livre_or = true
	cr.recevoir({"id": "livre-or-0001", "de": "Zoé", "texte": "Quelle jolie rue !", "x": -1030.0, "z": -16.0, "quand": 1794700000})
	cr.recevoir({"id": "livre-or-0002", "de": "Malik", "texte": "La mairie est superbe.", "x": -990.0, "z": -40.0, "quand": 1794790000})
	a.save_game(SLOT_A, "Valfleuri")
	VisiteVille.exporter(SLOT_A, cr.accueil, "", {"courrier": cr.pour_partage()})
	a.queue_free()
	for i in 4:
		await process_frame

	VisiteVille.recevoir_echange()
	var liste := VisiteVille.villes()
	VisiteVille.visiter_dossier(String(liste[0].dossier))
	var v: Node = await _scene()
	v.load_game(VisiteVille.SLOT)
	v._debut_visite()
	v.ambiance.set_speed(0)
	v.ambiance.unix_time = 1794740400.0
	_camera(v, -1010, -30, 150, 25, -38)
	await _shot("visite-ville.png")
	var p := VisitesPanel.new(v)
	v._windows_layer().add_child(p)
	for i in 6:
		await process_frame
	p._texte.text = "Superbe mairie, et la rue en T tombe pile devant la porte. On revient au printemps !"
	p._timbre.select(2)
	await _shot("visite-carte-postale.png")
	p.poster()
	p.fermer()
	VisiteVille.terminer()
	v.queue_free()
	for i in 4:
		await process_frame

	var b: Node = await _scene()
	b.load_game(SLOT_A)
	b.courrier.relever()
	b.ambiance.set_speed(0)
	b.ambiance.unix_time = 1794740400.0
	# Partie ouverte à la main après la scène : la fenêtre de fondation n'a pas lieu d'être.
	await create_timer(2.0).timeout
	b.villages_panel._dialog.hide()
	_camera(b, -1010, -30, 150, 25, -38)
	var pm := VisitesPanel.new(b)
	b._windows_layer().add_child(pm)
	await _shot("visite-courrier-maire.png")
	pm.fermer()
	await _shot("visite-cartes-epinglees.png")
	b.queue_free()
	SaveGame.delete(SLOT_A)
	quit(0)
