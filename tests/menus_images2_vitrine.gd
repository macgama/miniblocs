extends SceneTree
## Vitrine des menus en images, phase 2 (tous les menus) : réglages Admin,
## continents du zoo, décors, régions des bâtiments, usages et pièces des
## intérieurs, toits de l'Atelier.
## Marche aussi sur une version où ces menus sont encore des listes de texte
## (captures « avant ») : la liste est simplement ouverte.
## Usage (avec affichage) :
##   godot --path . --rendering-driver opengl3 --script res://tests/menus_images2_vitrine.gd -- --dossier /chemin/captures [--seul toits]

var dir := "."
var seul := ""


func _initialize() -> void:
	_run.call_deferred()


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


func _shot(nom: String, frames := 20) -> void:
	for i in frames:
		await process_frame
	# Le temps que les vignettes 3D soient rendues (une par image).
	for i in 400:
		await process_frame
		var v: Node = root.get_node_or_null("IllustrationsMenus")
		if v == null or ((v.get("_queue") as Array).is_empty() and not bool(v.get("_busy"))):
			break
	for i in 4:
		await process_frame
	var p := dir.path_join(nom + ".png")
	root.get_viewport().get_texture().get_image().save_png(p)
	print("capture : ", p)


func _veut(nom: String) -> bool:
	return seul == "" or seul == nom


## Le menu (ChoixVisuel ou OptionButton) qui propose un choix nommé `texte`.
func _choix_avec(racine: Node, texte: String) -> Control:
	for c in racine.find_children("*", "Button", true, false):
		if not (c as Control).is_visible_in_tree():
			continue
		if c.has_method("get_item_text") and c.has_method("select"):
			for i in int(c.get("item_count")):
				if String(c.call("get_item_text", i)).begins_with(texte):
					return c
	return null


func _ouvrir(c: Object) -> void:
	if c == null:
		push_warning("menu introuvable")
		return
	if c.has_method("ouvrir"):
		c.call("ouvrir")
	elif c is OptionButton:
		(c as OptionButton).show_popup()


func _fermer(c: Object) -> void:
	if c == null:
		return
	if c.has_method("_close"):
		c.call("_close")
	elif c is OptionButton:
		(c as OptionButton).get_popup().hide()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size() - 1:
		if args[i] == "--dossier":
			dir = args[i + 1]
		if args[i] == "--seul":
			seul = args[i + 1]
	root.size = Vector2i(1600, 900)
	Creations.persist = false
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var amb: DayNight = scene.get_node("Ambiance")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.set_origin(46.62, 6.79)
	for i in 60:
		await process_frame
	amb.set_speed(0)
	if Guide.instance != null:
		Guide.instance.proposer = false
	amb.unix_time = Time.get_unix_time_from_datetime_string("2026-06-09T09:30:00")
	if _veut("admin"):
		scene.toggle_admin()
		await process_frame
		var c := _choix_avec(root, "Rares")
		_ouvrir(c)
		await _shot("menu-admin-catastrophes")
		_fermer(c)
		c = _choix_avec(root, "Désactivée")
		_ouvrir(c)
		await _shot("menu-admin-pollution")
		_fermer(c)
		scene.toggle_admin()
		await process_frame
	if _veut("zoo"):
		var zp: ZooPanel = scene.zoo_panel
		zp.toggle()
		zp.show_view("animaux")
		await process_frame
		var c := _choix_avec(zp, "Tous les continents")
		_ouvrir(c)
		await _shot("menu-zoo-continents")
		_fermer(c)
		zp.toggle()
	if _veut("decors"):
		var dp: DecorPanel = scene.decors_panel
		dp.set_shown(true)
		await process_frame
		await _shot("panneau-decors")
		var c := dp.get("_cats") as Control
		_ouvrir(c)
		await _shot("menu-decors-categories")
		_fermer(c)
		dp.set_shown(false)
	var bp: BuildingPanel = scene.build_panel
	if _veut("regions"):
		bp.set_open(true)
		bp.show_category("logement")
		await process_frame
		var c := _choix_avec(bp, "Toutes les régions")
		_ouvrir(c)
		await _shot("menu-batiments-regions")
		_fermer(c)
		c = _choix_avec(bp, "Toutes les époques")
		_ouvrir(c)
		await _shot("menu-batiments-epoques")
		_fermer(c)
	if _veut("interieur"):
		bp.set_open(true)
		bp.show_category("interieur")
		await process_frame
		var c := _choix_avec(bp, "Logement")
		_ouvrir(c)
		await _shot("menu-interieur-usages")
		_fermer(c)
		c = _choix_avec(bp, "Toutes les pièces")
		_ouvrir(c)
		await _shot("menu-interieur-pieces")
		_fermer(c)
	bp.set_open(false)
	if _veut("toits"):
		var bs: BuildingSystem = scene.get("buildings")
		var y := world.cell_height(Vector2i(0, 0))
		# Posé directement (sans village ni route) : seul le panneau compte ici.
		var bid := bs.next_id
		bs.next_id += 1
		bs.call("_add", {"id": bid, "t": "colombages__maison", "x": 0, "z": 0, "r": 0, "a": 0.0, "h": y, "cost": 0, "zone": 0})
		var pp: PersoPanel = scene.perso_panel
		pp.edit(bid)
		await process_frame
		var c := _choix_avec(pp, "Comme le modèle")
		_ouvrir(c)
		await _shot("menu-atelier-toits")
		_fermer(c)
		pp.set_open(false)
		print("bâtiment ", bid, " hauteur ", y)
	quit()
