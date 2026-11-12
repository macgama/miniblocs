class_name BanquePose
extends Node3D
## Outil de pose d'un modèle en murs fins de la banque : un cadre suit la
## souris, un clic pose le modèle (coin −x −z sur la case visée).

signal message(text: String)
signal placed(plan_id: String)

var world: TerrainWorld
var camera: Camera3D
var mob: Mobilier
var bs: BuildingSystem

var model_id := ""
var _cell := Vector2i.ZERO
var _valid := false
var _frame: MeshInstance3D
var _right_press := Vector2.ZERO


func _ready() -> void:
	_frame = MeshInstance3D.new()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.49, 0.78, 1.0, 0.35)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_frame.material_override = m
	_frame.visible = false
	add_child(_frame)


func active() -> bool:
	return model_id != ""


func start(id: String) -> void:
	var d := BanqueModeles.get_model(id)
	if d.is_empty():
		return
	model_id = id
	var box := BoxMesh.new()
	box.size = Vector3(float(d.get("w", 1)), 3.0 * maxf(1.0, float((d.get("etiquettes", {}) as Dictionary).get("etages", 1))), float(d.get("d", 1)))
	_frame.mesh = box
	message.emit("Poser « %s » (%s) : clic pour poser · clic droit ou Échap : arrêter" % [String(d.nom), String((d.get("etiquettes", {}) as Dictionary).get("taille", ""))])


func stop() -> void:
	if model_id == "":
		return
	model_id = ""
	_frame.visible = false
	message.emit("")


func _cam() -> Camera3D:
	var c := get_viewport().get_camera_3d()
	return c if c != null else camera


func _unhandled_input(event: InputEvent) -> void:
	if model_id == "" or world == null:
		return
	var cam := _cam()
	if cam == null:
		return
	if event is InputEventMouseMotion:
		_update((event as InputEventMouseMotion).position, cam)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				_right_press = mb.position
			elif mb.position.distance_to(_right_press) < 5.0:
				stop()
			return
		if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
			return
		_update(mb.position, cam)
		if not _valid:
			return
		get_viewport().set_input_as_handled()
		var res := BanqueModeles.place(model_id, _cell, 0, bs, mob)
		if res.ok:
			message.emit("Modèle posé.")
			placed.emit(String(res.get("plan", "")))
		else:
			message.emit("Impossible de poser ici : %s." % String(res.error))
	elif event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo and k.keycode == KEY_ESCAPE:
			stop()
			get_viewport().set_input_as_handled()


func _update(screen: Vector2, cam: Camera3D) -> void:
	var hit: Variant = world.pick_cell(cam.project_ray_origin(screen), cam.project_ray_normal(screen))
	_valid = hit != null
	if not _valid:
		_frame.visible = false
		return
	_cell = hit
	var d := BanqueModeles.get_model(model_id)
	var size := (_frame.mesh as BoxMesh).size
	var y := world.cell_height(_cell)
	_frame.global_position = Vector3(_cell.x + float(d.get("w", 1)) / 2.0, y + size.y / 2.0, _cell.y + float(d.get("d", 1)) / 2.0)
	_frame.visible = true
