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

const TRANSPORT_TOOLS := ["departementale", "train", "voie_verte", "canal"]
## Dernière classe choisie pour chaque outil de transport.
var _tool_class := {}

var _status_timer := 0.0
var _hover := Vector2i.ZERO
var _hover_valid := false


func _ready() -> void:
	world.origin_changed.connect(_on_origin_changed)
	world.hovered_cell_changed.connect(func(c: Vector2i, valid: bool) -> void:
		_hover = c
		_hover_valid = valid
		_refresh_cell_info())
	world.terrain_edited.connect(func(n: int) -> void:
		if n > 0:
			hud.show_message("%d case%s modifiée%s." % [n, "s" if n > 1 else "", "s" if n > 1 else ""])
		_refresh_cell_info())
	hud.go_requested.connect(func(lat: float, lon: float) -> void: world.set_origin(lat, lon))
	hud.tool_selected.connect(_on_tool_selected)
	hud.traffic_toggled.connect(func(on: bool) -> void: transport.traffic.set_enabled(on))
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
	build_panel.wall_height_changed.connect(func(h: int) -> void:
		blocks.wall_height = h
		blocks._emit_help())
	build_panel.growth_toggled.connect(func(on: bool) -> void: zones.growth = on)
	build_panel.rules_changed.connect(func(access: bool, unlimited: bool) -> void:
		buildings.require_access = access
		buildings.unlimited_money = unlimited
		buildings._refresh())
	hud.save_requested.connect(func() -> void:
		var ok := world.save_world({"transport": transport.to_dict(), "batiments": buildings.to_dict(), "zones": zones.to_dict(), "blocs": blocks.to_dict()})
		hud.show_message("Région sauvegardée." if ok else "Échec de la sauvegarde."))
	hud.load_requested.connect(func() -> void:
		if world.load_world():
			transport.from_dict(world.loaded_data.get("transport", {}))
			buildings.from_dict(world.loaded_data.get("batiments", {}))
			zones.from_dict(world.loaded_data.get("zones", {}))
			blocks.from_dict(world.loaded_data.get("blocs", {}))
			build_panel.set_rules(buildings.require_access, buildings.unlimited_money)
			build_panel.set_growth(zones.growth)
			hud.show_message("Région chargée.")
		else:
			hud.show_message("Aucune sauvegarde trouvée."))
	hud.city_requested.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/main.tscn"))
	hud.globe_requested.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/globe.tscn"))
	if GameStart.chosen:
		world.set_origin(GameStart.lat, GameStart.lon)
	_on_origin_changed(world.origin_lat, world.origin_lon)


## Un outil de construction prend la main : on range ceux du terrain et des voies.
func _select_building_tool() -> void:
	world.set_tool(TerrainWorld.Tool.INSPECT)
	transport.set_inactive()
	hud.show_spec("", {}, false)
	buildings.set_inactive()
	zones.set_inactive()
	blocks.set_inactive()
	hud.select_tool_silently(0)


func _on_tool_selected(t: int) -> void:
	buildings.set_inactive()
	zones.set_inactive()
	blocks.set_inactive()
	build_panel.clear_selection()
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
	else:
		hud.show_spec("", {}, false)
		transport.set_demolish()


func _on_origin_changed(lat: float, lon: float) -> void:
	# Nouvelle région : réseau vierge.
	transport.clear()
	buildings.clear()
	zones.clear()
	blocks.clear()
	GameStart.lat = lat
	GameStart.lon = lon
	hud.set_place(lat, lon)
	rig.position = Vector3.ZERO
	_snap_pending = true
	hud.show_message("Chargement du relief réel autour de %.4f, %.4f…" % [lat, lon])


var _snap_pending := true


func _process(delta: float) -> void:
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
		if world.water.status != "":
			s += "   ·   " + world.water.status
		hud.set_status(s)
		hud.set_network_info(transport.summary())
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
