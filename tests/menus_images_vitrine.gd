extends SceneTree
## Vitrine des menus en images : grilles de vignettes des outils Route, Rail,
## Chemin et Voie d'eau, choix du croisement (pont, tunnel), outil Carrefour,
## panneau « Faire évoluer » (classe et bords), météo, biomes, filtres et
## cadrages du mode photo, format du time-lapse, époque de départ.
## Marche aussi sur une version sans menus en images (captures « avant ») :
## les listes de texte y sont simplement ouvertes.
## Usage (avec affichage) :
##   godot --path . --rendering-driver opengl3 --script res://tests/menus_images_vitrine.gd -- --dossier /chemin/captures [--seul route]


func _initialize() -> void:
	_run.call_deferred()


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


var dir := "."
var seul := ""


func _shot(nom: String, frames := 20) -> void:
	for i in frames:
		await process_frame
	var p := dir.path_join(nom + ".png")
	root.get_viewport().get_texture().get_image().save_png(p)
	print("capture : ", p)


## Attend que toutes les vignettes 3D demandées soient rendues.
func _attendre(v: Object) -> void:
	for i in 600:
		await process_frame
		if v == null or not ("_queue" in v) or ((v.get("_queue") as Array).is_empty() and not bool(v.get("_busy"))):
			break


func _ouvrir(picker: Object) -> void:
	if picker.has_method("ouvrir"):
		picker.call("ouvrir")
	elif picker is OptionButton:
		(picker as OptionButton).show_popup()


func _fermer(picker: Object) -> void:
	if picker.has_method("_close"):
		picker.call("_close")
	elif picker is OptionButton:
		(picker as OptionButton).get_popup().hide()


func _veut(nom: String) -> bool:
	return seul == "" or seul == nom


func _trouver(n: Node, script_class: String) -> Node:
	var s: Script = n.get_script()
	if s != null and s.get_global_name() == script_class:
		return n
	for c in n.get_children():
		var r := _trouver(c, script_class)
		if r != null:
			return r
	return null


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size() - 1:
		if args[i] == "--dossier":
			dir = args[i + 1]
		if args[i] == "--seul":
			seul = args[i + 1]
	root.size = Vector2i(1600, 900)
	Creations.persist = false
	if _veut("epoque"):
		await _epoque()
		if seul == "epoque":
			quit()
			return
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
	amb.unix_time = Time.get_unix_time_from_datetime_string("2026-06-09T09:30:00")
	var hud: TerreHud = scene.hud
	var vign: Object = hud.get("_vignettes")
	var outils := [["route", TerreHud.FIRST_TRANSPORT_TOOL], ["rail", TerreHud.FIRST_TRANSPORT_TOOL + 1],
		["chemin", TerreHud.FIRST_TRANSPORT_TOOL + 2], ["eau", TerreHud.FIRST_TRANSPORT_TOOL + 3]]
	for o in outils:
		if not _veut(o[0]):
			continue
		hud.choose_tool(int(o[1]))
		await process_frame
		_ouvrir(hud._class_pick)
		await _attendre(vign)
		await _shot("menu-" + String(o[0]))
		_fermer(hud._class_pick)
	if _veut("croisement"):
		hud.choose_tool(TerreHud.FIRST_TRANSPORT_TOOL)
		await process_frame
		_ouvrir(hud._level_pick)
		await _shot("menu-croisement")
		_fermer(hud._level_pick)
	if _veut("carrefour"):
		hud.choose_tool(9)
		await _shot("menu-carrefour")
	if _veut("evolution"):
		var panel: EvolutionPanel = scene.get_node("PanneauEvolution")
		var transport: TransportSystem = scene.get_node("Transport")
		var y := world.cell_height(Vector2i(0, 0))
		transport.build_segment("rue", Vector3(0, y, -60), Vector3(0, y, 60))
		var eid: int = transport.network.edges.keys()[0]
		panel.open_for(eid)
		await process_frame
		_ouvrir(panel._class)
		await _attendre(panel.get("_vignettes"))
		await _shot("menu-evolution-classe")
		_fermer(panel._class)
		_ouvrir(panel._bords)
		await _shot("menu-evolution-bords")
		_fermer(panel._bords)
		panel.close()
	hud.choose_tool(0)
	if _veut("meteo"):
		var ch := _trouver(root, "ClockHud")
		ch._details.visible = true
		await process_frame
		_ouvrir(ch._weather_pick)
		await _shot("menu-meteo")
		_fermer(ch._weather_pick)
		ch._details.visible = false
	if _veut("biome"):
		var pp: PaysagePanel = scene.landscape
		pp.set_shown(true)
		await process_frame
		_ouvrir(pp._biome_pick)
		await _shot("menu-biome")
		_fermer(pp._biome_pick)
		pp.set_shown(false)
	if _veut("photo"):
		var mp: ModePhoto = scene.mode_photo
		mp.entrer()
		await _shot("photo-panneau", 30)
		var pickers: Array = []
		for c in mp.find_children("*", "Button", true, false):
			if c.has_method("ouvrir") or c is OptionButton:
				pickers.append(c)
		if pickers.size() >= 2:
			_ouvrir(pickers[0])
			await _shot("menu-photo-filtre")
			_fermer(pickers[0])
			_ouvrir(pickers[1])
			await _shot("menu-photo-cadrage")
			_fermer(pickers[1])
		mp.toggle()
		await process_frame
	if _veut("timelapse"):
		var tp: Node = scene.timelapse_panel
		tp.toggle()
		await process_frame
		_ouvrir(tp._fmt)
		await _shot("menu-timelapse-format")
		_fermer(tp._fmt)
	quit()


func _epoque() -> void:
	var scene = load("res://scenes/globe.tscn").instantiate()
	scene.offline = true
	root.add_child(scene)
	for i in 30:
		await process_frame
	scene._search.text = "lausanne"
	scene._refresh_list()
	scene._list.select(0)
	scene._list.item_selected.emit(0)
	for i in 60:
		await process_frame
	scene.suivant()
	scene.suivant()
	await process_frame
	_ouvrir(scene._epoque_opt)
	await _attendre(scene.get("_vignettes"))
	await _shot("menu-epoque", 30)
	_fermer(scene._epoque_opt)
	scene.queue_free()
	for i in 5:
		await process_frame
