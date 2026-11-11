extends Node3D
## Scène « Terre » : relie l'interface, la caméra et le terrain réel.

@onready var world: TerrainWorld = $Terrain
@onready var hud: CanvasLayer = $HUD
@onready var rig: Node3D = $CameraRig

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
	hud.tool_selected.connect(func(t: int) -> void: world.set_tool(t))
	hud.save_requested.connect(func() -> void:
		hud.show_message("Région sauvegardée." if world.save_world() else "Échec de la sauvegarde."))
	hud.load_requested.connect(func() -> void:
		hud.show_message("Région chargée." if world.load_world() else "Aucune sauvegarde trouvée."))
	hud.city_requested.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/main.tscn"))
	hud.globe_requested.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/globe.tscn"))
	if GameStart.chosen:
		world.set_origin(GameStart.lat, GameStart.lon)
	_on_origin_changed(world.origin_lat, world.origin_lon)


func _on_origin_changed(lat: float, lon: float) -> void:
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
		hud.set_status(s)


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
	if world.modifications.has(_hover):
		txt += "   ·   modifiée"
	hud.set_cell_info(txt)
