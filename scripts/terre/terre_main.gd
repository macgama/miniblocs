extends Node3D
## Scène « Terre » : relie l'interface, la caméra et le terrain réel.

@onready var world: TerrainWorld = $Terrain
@onready var hud: CanvasLayer = $HUD
@onready var rig: Node3D = $CameraRig
@onready var transport: TransportSystem = $Transport
@onready var buildings: BuildingSystem = $Batiments
@onready var build_panel: BuildingPanel = $PanneauConstruction
@onready var zones: ZoneSystem = $Zones
@onready var blocks: BlockEditor = $Blocs
@onready var ambiance: DayNight = $Ambiance

const TRANSPORT_TOOLS := ["departementale", "train", "voie_verte", "canal"]
## Dernière classe choisie pour chaque outil de transport.
var _tool_class := {}

var _status_timer := 0.0
var transit_panel: StationPanel
## Habitants : vie, foyers, travail, école, loisirs et budget (touche H).
var population: Population
var habitants_panel: HabitantsPanel
var _hover := Vector2i.ZERO
var _hover_valid := false


func _ready() -> void:
	# Région jouable : REGION_SIZE de côté autour du point de départ.
	var half := GameStart.REGION_SIZE * 0.5
	rig.bounds = Rect2(-half, -half, GameStart.REGION_SIZE, GameStart.REGION_SIZE)
	world.origin_changed.connect(_on_origin_changed)
	world.hovered_cell_changed.connect(func(c: Vector2i, valid: bool) -> void:
		_hover = c
		_hover_valid = valid
		_refresh_cell_info())
	world.terrain_edited.connect(func(n: int) -> void:
		if n > 0:
			hud.show_message("%d case%s modifiée%s." % [n, "s" if n > 1 else "", "s" if n > 1 else ""])
		_refresh_cell_info())
	hud.go_requested.connect(func(lat: float, lon: float) -> void:
		GameStart.place_name = ""
		world.set_origin(lat, lon))
	hud.tool_selected.connect(_on_tool_selected)
	_setup_landscape()
	_setup_transit()
	_setup_population()
	hud.traffic_toggled.connect(func(on: bool) -> void: transport.traffic.set_enabled(on))
	hud.traffic_filter_changed.connect(func(era: String, region: String) -> void:
		transport.traffic.set_filters(era, region)
		hud.show_message("Véhicules : %s, %s." % [
			"toutes les époques" if era == "" else Styles.era_name(era).to_lower(),
			"toutes les régions" if region == "" else Styles.region_name(region)]))
	transport.info_changed.connect(func(t: String) -> void: hud.set_tool_info(t))
	transport.message.connect(func(t: String) -> void: hud.show_message(t))
	transport.spec_changed.connect(func(id: String, s: Dictionary) -> void: hud.show_spec(id, s, transport.curve_mode))
	hud.spec_edited.connect(func(id: String, s: Dictionary) -> void:
		_tool_class[TransportTypes.mode_of(id)] = id
		transport.set_spec(id, s)
		hud.show_spec(id, transport.spec, transport.curve_mode))
	hud.curve_toggled.connect(func(on: bool) -> void: transport.set_curve(on))
	buildings.info_changed.connect(func(t: String) -> void: hud.set_tool_info(t))
	buildings.message.connect(func(t: String) -> void: hud.show_message(t))
	build_panel.building_chosen.connect(func(id: String) -> void:
		_select_building_tool()
		buildings.set_place(id))
	build_panel.demolish_chosen.connect(func() -> void:
		_select_building_tool()
		buildings.set_demolish())
	zones.info_changed.connect(func(t: String) -> void: hud.set_tool_info(t))
	zones.message.connect(func(t: String) -> void: hud.show_message(t))
	build_panel.zone_chosen.connect(func(k: String) -> void:
		_select_building_tool()
		zones.set_paint(k))
	build_panel.zone_remove_chosen.connect(func() -> void:
		_select_building_tool()
		zones.set_remove())
	blocks.info_changed.connect(func(t: String) -> void: hud.set_tool_info(t))
	blocks.message.connect(func(t: String) -> void: hud.show_message(t))
	build_panel.block_tool_chosen.connect(func(t: int) -> void:
		_select_building_tool()
		blocks.set_tool(t))
	build_panel.block_material_chosen.connect(func(m: int) -> void:
		blocks.set_material(m)
		if blocks.tool == BlockEditor.Tool.NONE:
			_select_building_tool()
			blocks.set_tool(BlockEditor.Tool.BLOCK))
	build_panel.block_shape_chosen.connect(func(sh: int) -> void:
		blocks.set_shape(sh)
		if blocks.tool == BlockEditor.Tool.NONE or blocks.tool == BlockEditor.Tool.ERASE or blocks.tool == BlockEditor.Tool.CAPTURE:
			_select_building_tool()
			blocks.set_tool(BlockEditor.Tool.BLOCK))
	($VueSol as VueSol).interaction.connect(func(o: Vector3, d: Vector3) -> void: blocks.interact_ray(o, d, 4.0))
	build_panel.block_tint_chosen.connect(func(t: int) -> void: blocks.set_tint(t))
	build_panel.capture_name_changed.connect(func(n: String) -> void: blocks.capture_name = n)
	build_panel.creation_deleted.connect(func(id: String) -> void: Creations.remove(id))
	blocks.captured.connect(func(res: Dictionary) -> void:
		if res.ok:
			blocks.set_tool(BlockEditor.Tool.NONE)
			build_panel.clear_selection())
	build_panel.wall_height_changed.connect(func(h: int) -> void:
		blocks.wall_height = h
		blocks._emit_help())
	build_panel.growth_toggled.connect(func(on: bool) -> void: zones.growth = on)
	build_panel.zone_style_chosen.connect(func(st: String) -> void: zones.current_style = st)
	build_panel.rules_changed.connect(func(access: bool, unlimited: bool) -> void:
		buildings.require_access = access
		buildings.unlimited_money = unlimited
		buildings._refresh())
	hud.save_requested.connect(func() -> void:
		if save_game():
			hud.show_message("Partie sauvegardée : %s." % _game_title())
		else:
			hud.show_message("Échec de la sauvegarde : " + last_error))
	hud.load_requested.connect(open_saves_panel)
	hud.help_requested.connect(toggle_help)
	hud.quick_load_requested.connect(func() -> void:
		var slot := GameStart.slot_id
		if slot == "" or not SaveGame.exists(slot):
			var all := SaveGame.list_saves()
			slot = String(all[0].id) if not all.is_empty() else ""
		if slot == "":
			hud.show_message("Aucune partie sauvegardée.")
		elif load_game(slot):
			hud.show_message("Partie chargée : %s." % _game_title())
		else:
			hud.show_message("Chargement impossible : " + last_error))
	for sig in [world.terrain_edited, transport.network_changed, buildings.changed, zones.changed, blocks.changed, transport.stations.lines_changed, transport.junctions.changed, population.changed]:
		(sig as Signal).connect(func(_a = null) -> void: _unsaved = true)
	hud.city_requested.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/main.tscn"))
	hud.globe_requested.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/globe.tscn"))
	if GameStart.chosen:
		world.set_origin(GameStart.lat, GameStart.lon)
	_on_origin_changed(world.origin_lat, world.origin_lon)
	if GameStart.load_slot != "":
		var slot := GameStart.load_slot
		GameStart.load_slot = ""
		if load_game(slot):
			hud.show_message("Partie chargée : %s." % _game_title())
		else:
			hud.show_message("Chargement impossible : " + last_error)


# --- Sauvegarde -------------------------------------------------------------------

## Message de la dernière erreur de sauvegarde ou de chargement.
var last_error := ""
## Des changements depuis la dernière sauvegarde (pour la sauvegarde automatique).
var _unsaved := false
var _autosave_timer := 0.0
## Sauvegarde automatique toutes les 5 minutes, dans une partie à part.
const AUTOSAVE_SLOT := "sauvegarde-auto"
const AUTOSAVE_INTERVAL := 300.0
var _saves_panel: PartiesPanel


func _game_title() -> String:
	if GameStart.place_name != "":
		return GameStart.place_name
	return "Région %.3f, %.3f" % [world.origin_lat, world.origin_lon]


## Sections de la sauvegarde : uniquement ce que le joueur a créé ou changé.
func save_sections() -> Dictionary:
	return {"terrain": world.to_dict(), "transport": transport.to_dict(), "batiments": buildings.to_dict(),
		"zones": zones.to_dict(), "blocs": blocks.to_dict(), "ambiance": ambiance.to_dict(),
		"creations": Creations.to_dict(Creations.used_by(buildings)),
		"personnage": ($VueSol as VueSol).to_dict(), "habitants": population.to_dict()}


## Sauvegarde dans la partie en cours (ou une nouvelle). title : nom d'une nouvelle partie.
func save_game(slot := "", title := "") -> bool:
	if slot == "":
		slot = GameStart.slot_id if GameStart.slot_id != AUTOSAVE_SLOT else ""
	if slot == "":
		slot = SaveGame.make_slot_id(title if title != "" else _game_title())
	var old := SaveGame.read_manifest(slot)
	var name: String = title if title != "" else String(old.get("nom", _game_title()))
	var t := buildings.totals()
	var info := {
		"nom": name,
		"lieu": {"lat": world.origin_lat, "lon": world.origin_lon, "nom": GameStart.place_name},
		"mode": ["bac_a_sable", "entre_amis", "mondiale"][int(GameStart.mode)],
		"camera": {"x": snappedf(rig.position.x, 0.01), "z": snappedf(rig.position.z, 0.01),
			"distance": snappedf(rig._target_distance, 0.01), "angle": snappedf(rig.rotation_degrees.y, 0.01)},
		"resume": {"habitants": population.persons.size(), "batiments": t.count, "logements": t.logements, "emplois": t.emplois,
			"reseau": TransportSystem._km(_network_length()),
			"blocs": blocks.blocks.size(), "cases_modifiees": world.modifications.size()},
	}
	last_error = SaveGame.write(slot, info, save_sections())
	if last_error != "":
		return false
	if slot != AUTOSAVE_SLOT:
		GameStart.slot_id = slot
	_unsaved = false
	_autosave_timer = 0.0
	return true


## Charge une partie (par défaut la partie en cours).
func load_game(slot := "") -> bool:
	if slot == "":
		slot = GameStart.slot_id
	var res := SaveGame.read(slot)
	if not res.ok:
		last_error = res.error
		return false
	var sec: Dictionary = res.sections
	var m: Dictionary = res.manifest
	var lieu: Dictionary = m.get("lieu", {})
	GameStart.place_name = String(lieu.get("nom", ""))
	world.from_dict(sec.terrain)
	transport.from_dict(sec.get("transport", {}))
	Creations.adopt(sec.get("creations", {}))
	buildings.from_dict(sec.get("batiments", {}))
	zones.from_dict(sec.get("zones", {}))
	population.from_dict(sec.get("habitants", {}))
	blocks.from_dict(sec.get("blocs", {}))
	ambiance.from_dict(sec.get("ambiance", {}))
	($VueSol as VueSol).from_dict(sec.get("personnage", {}))
	build_panel.set_rules(buildings.require_access, buildings.unlimited_money)
	build_panel.set_growth(zones.growth)
	var cam: Dictionary = m.get("camera", {})
	if not cam.is_empty():
		rig.position.x = float(cam.get("x", 0.0))
		rig.position.z = float(cam.get("z", 0.0))
		rig._target_distance = float(cam.get("distance", rig._target_distance))
		rig.rotation_degrees.y = float(cam.get("angle", 0.0))
		_snap_pending = true
	GameStart.slot_id = slot
	_unsaved = false
	_autosave_timer = 0.0
	last_error = "" if res.warnings.is_empty() else "; ".join(res.warnings)
	if last_error != "":
		hud.show_message("Partie chargée avec des pertes : " + last_error)
	return true


## Habitants (simulation) et leur panneau.
func _setup_population() -> void:
	population = Population.new()
	population.name = "Habitants"
	add_child(population)
	population.world = world
	population.buildings = buildings
	population.transport = transport
	population.ambiance = ambiance
	population.message.connect(func(t: String) -> void: hud.show_message(t))
	buildings.changed.connect(func() -> void: population._sync_buildings.call_deferred())
	habitants_panel = HabitantsPanel.new()
	habitants_panel.name = "PanneauHabitants"
	add_child(habitants_panel)
	habitants_panel.setup(population)
	habitants_panel.focus_requested.connect(func(pos: Vector3) -> void:
		rig.position.x = pos.x
		rig.position.z = pos.z)
	hud.habitants_requested.connect(func() -> void: habitants_panel.toggle())


## Panneau des transports publics : stations et lignes.
func _setup_transit() -> void:
	transit_panel = StationPanel.new()
	transit_panel.name = "PanneauLignes"
	add_child(transit_panel)
	var st := transport.stations
	transit_panel.setup(st)
	st.info_changed.connect(func(t: String) -> void: hud.set_tool_info(t))
	st.message.connect(func(t: String) -> void: hud.show_message(t))
	hud.transit_requested.connect(func() -> void: transit_panel.toggle())
	transit_panel.station_chosen.connect(func(id: String) -> void:
		_select_building_tool(true)
		build_panel.clear_selection()
		st.set_place(id))
	transit_panel.demolish_chosen.connect(func() -> void:
		_select_building_tool(true)
		build_panel.clear_selection()
		st.set_demolish())
	transit_panel.line_tool_chosen.connect(func() -> void:
		_select_building_tool(true)
		build_panel.clear_selection()
		st.set_line_tool())


func _network_length() -> float:
	var t := 0.0
	for id in transport.network.edges:
		t += float(transport.network.edges[id].len)
	return t


func open_saves_panel() -> void:
	if _saves_panel != null:
		return
	_saves_panel = PartiesPanel.new(true)
	_windows_layer().add_child(_saves_panel)
	_saves_panel.closed.connect(func() -> void: _saves_panel = null)
	_saves_panel.load_chosen.connect(func(slot: String) -> void:
		_saves_panel.close_panel()
		if load_game(slot):
			hud.show_message("Partie chargée : %s." % _game_title())
		else:
			hud.show_message("Chargement impossible : " + last_error))
	_saves_panel.save_as_requested.connect(func(title: String) -> void:
		if save_game(SaveGame.make_slot_id(title), title):
			hud.show_message("Partie sauvegardée : %s." % title)
			_saves_panel.refresh()
		else:
			hud.show_message("Échec de la sauvegarde : " + last_error))


var _help: AidePanel
var _windows: CanvasLayer


## Calque des fenêtres (aide, parties) : au-dessus de tous les panneaux.
func _windows_layer() -> CanvasLayer:
	if _windows == null:
		_windows = CanvasLayer.new()
		_windows.name = "Fenetres"
		_windows.layer = 20
		add_child(_windows)
	return _windows


func toggle_help() -> void:
	if _help != null:
		_help.close_panel()
		return
	_help = AidePanel.new()
	_help.closed.connect(func() -> void: _help = null)
	_windows_layer().add_child(_help)


func _autosave(delta: float) -> void:
	_autosave_timer += delta
	if _autosave_timer < AUTOSAVE_INTERVAL:
		return
	_autosave_timer = 0.0
	if not _unsaved:
		return
	var keep := GameStart.slot_id
	var t := _game_title()
	if save_game(AUTOSAVE_SLOT, "Sauvegarde automatique · " + t):
		hud.show_message("Sauvegarde automatique.")
	GameStart.slot_id = keep
	# La partie du joueur n'est pas à jour : on garde la marque « non sauvegardé ».
	_unsaved = keep != ""


## Un outil de construction prend la main : on range ceux du terrain et des voies.
func _select_building_tool(from_transit := false) -> void:
	world.set_tool(TerrainWorld.Tool.INSPECT)
	landscape.set_shown(false)
	transport.stations.set_inactive()
	if transit_panel and not from_transit:
		transit_panel.clear_selection()
	transport.set_inactive()
	hud.show_spec("", {}, false)
	buildings.set_inactive()
	zones.set_inactive()
	blocks.set_inactive()
	hud.select_tool_silently(0)


## Panneau « Paysage » : pinceaux de terrain (outil 0).
var landscape: PaysagePanel


func _setup_landscape() -> void:
	landscape = PaysagePanel.new()
	landscape.name = "PanneauPaysage"
	add_child(landscape)
	landscape.set_shown(false)
	landscape.tool_chosen.connect(func(t: int) -> void:
		if landscape.visible:
			world.set_tool(t))
	landscape.radius_changed.connect(func(r: int) -> void:
		world.brush_radius = r
		world._update_selection())
	landscape.biome_chosen.connect(func(k: int) -> void: world.paint_kind = k)
	world.brush_radius = landscape.radius
	world.paint_kind = landscape.kind


func _on_tool_selected(t: int) -> void:
	landscape.set_shown(t == TerreHud.LANDSCAPE_TOOL)
	transport.stations.set_inactive()
	transit_panel.clear_selection()
	buildings.set_inactive()
	zones.set_inactive()
	blocks.set_inactive()
	build_panel.clear_selection()
	if t == TerreHud.LANDSCAPE_TOOL:
		transport.set_inactive()
		hud.show_spec("", {}, false)
		world.set_tool(landscape.current_tool)
		return
	var k := t - TerreHud.FIRST_TRANSPORT_TOOL
	if k < 0:
		transport.set_inactive()
		hud.show_spec("", {}, false)
		world.set_tool(t)
		return
	world.set_tool(TerrainWorld.Tool.INSPECT)
	if k < TRANSPORT_TOOLS.size():
		var default_id: String = TRANSPORT_TOOLS[k]
		transport.set_build(_tool_class.get(TransportTypes.mode_of(default_id), default_id))
	elif k == TRANSPORT_TOOLS.size():
		hud.show_spec("", {}, false)
		transport.set_demolish()
	else:
		hud.show_spec("", {}, false)
		transport.set_junction_tool()


func _on_origin_changed(lat: float, lon: float) -> void:
	# Nouvelle région : réseau vierge.
	population.clear()
	transport.clear()
	buildings.clear()
	zones.clear()
	blocks.clear()
	GameStart.lat = lat
	GameStart.lon = lon
	# Nouvelle région : nouvelle partie (load_game() remet son identifiant après).
	GameStart.slot_id = ""
	hud.set_place(lat, lon)
	rig.position = Vector3.ZERO
	_snap_pending = true
	hud.show_message("Chargement du relief réel autour de %.4f, %.4f…" % [lat, lon])


var _snap_pending := true


func _process(delta: float) -> void:
	_autosave(delta)
	world.update_tide(ambiance.unix_time)
	# Le pivot de la caméra suit le relief sous lui.
	var h := world.cell_height(Vector2i(floori(rig.position.x), floori(rig.position.z)))
	if not is_nan(h):
		var target := maxf(h, 0.0)
		if _snap_pending or absf(target - rig.position.y) > 60.0:
			rig.position.y = target
			_snap_pending = false
		else:
			rig.position.y = lerpf(rig.position.y, target, clampf(delta * 4.0, 0.0, 1.0))

	_status_timer -= delta
	if _status_timer <= 0.0:
		_status_timer = 0.3
		var t := world.tiles
		var s := "Blocs de 64 × 64 m affichés : %d   ·   Tuiles d'altitude : %d en mémoire" % [world.chunks.size(), t.loaded_count()]
		if t.pending_count() > 0:
			s += ", %d en téléchargement…" % t.pending_count()
		if t.failed_count() > 0:
			s += "   ·   %d tuile(s) introuvable(s) (pas de réseau ?)" % t.failed_count()
		s += "   ·   Cases modifiées : %d" % world.modifications.size()
		if Maree.amplitude(world.origin_lat, world.origin_lon) > 0.0:
			s += "   ·   " + Maree.describe(ambiance.unix_time, world.origin_lat, world.origin_lon)
		if world.water.status != "":
			s += "   ·   " + world.water.status
		hud.set_status(s)
		hud.set_network_info(transport.summary() + "   ·   " + population.summary())
		build_panel.set_money("Caisse : illimitée" if buildings.unlimited_money else "Caisse : " + BuildingSystem.format_money(buildings.money))
		build_panel.set_summary(buildings.summary())
		build_panel.set_zone_info(zones.summary())
		build_panel.set_block_info(blocks.summary())


func _refresh_cell_info() -> void:
	if not _hover_valid:
		hud.set_cell_info("Survole le terrain pour voir une case.")
		return
	var h := world.cell_height(_hover)
	if is_nan(h):
		hud.set_cell_info("Case %d, %d : relief en cours de chargement…" % [_hover.x, _hover.y])
		return
	var ll := world.local_to_lat_lon(_hover.x + 0.5, _hover.y + 0.5)
	var kind := world.cell_kind_at(_hover)
	var real := world.raw_height(_hover.x + 0.5, _hover.y + 0.5)
	var txt := "Case %d, %d   ·   %.6f, %.6f   ·   %s   ·   hauteur %.1f m (réelle %.1f m)" % [
		_hover.x, _hover.y, ll.x, ll.y, kind, h, real]
	var river := world.water_name_at(_hover)
	if river != "":
		txt += " (%s)" % river
	if world.modifications.has(_hover):
		txt += "   ·   modifiée"
	hud.set_cell_info(txt)
