extends Node3D
## Caméra de gestion : vue de dessus inclinée autour d'un point pivot.
##
## Commandes :
## - ZQSD / WASD / flèches : déplacer
## - Molette : zoomer
## - A / E en AZERTY (Q / E en QWERTY) : tourner, ou clic molette maintenu + glisser
## - Clic droit maintenu + glisser : faire glisser la carte

@export var move_speed: float = 22.0
@export var rotate_speed: float = 90.0 # degrés par seconde
@export var min_distance: float = 8.0
@export var max_distance: float = 80.0
@export var zoom_step: float = 0.12
@export var pitch_degrees: float = 55.0
@export var bounds: Rect2 = Rect2(-4, -4, 72, 72)

var _distance: float = 36.0
var _target_distance: float = 36.0
var _dragging_pan := false
var _dragging_rotate := false

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	_apply_camera()


func _process(delta: float) -> void:
	# Pas de déplacement pendant la saisie d'un texte (ex. coordonnées).
	var typing := get_viewport().gui_get_focus_owner() is LineEdit
	# Ctrl / Alt / Cmd + touche : raccourci (ex. Ctrl+Z en AZERTY), pas un déplacement.
	typing = typing or Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_ALT) or Input.is_key_pressed(KEY_META)
	# Touches « physiques » : même position sur AZERTY (ZQSD) et QWERTY (WASD).
	var input := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input.y += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input.x += 1.0

	if input != Vector2.ZERO and not typing:
		# La vitesse augmente avec le zoom pour garder une sensation constante.
		var speed := move_speed * (_distance / 36.0)
		_move_local(input.normalized() * speed * delta)

	var rot := 0.0
	if Input.is_physical_key_pressed(KEY_Q):
		rot += 1.0
	if Input.is_physical_key_pressed(KEY_E):
		rot -= 1.0
	if rot != 0.0 and not typing:
		rotation_degrees.y += rot * rotate_speed * delta

	_distance = lerp(_distance, _target_distance, clamp(delta * 10.0, 0.0, 1.0))
	_apply_camera()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_target_distance = clamp(_target_distance * (1.0 - zoom_step), min_distance, max_distance)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_target_distance = clamp(_target_distance * (1.0 + zoom_step), min_distance, max_distance)
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_dragging_pan = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging_rotate = mb.pressed
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _dragging_pan:
			var factor := _distance / 900.0
			_move_local(Vector2(-mm.relative.x, -mm.relative.y) * factor)
		elif _dragging_rotate:
			rotation_degrees.y -= mm.relative.x * 0.3


func _move_local(offset: Vector2) -> void:
	# Déplacement dans le plan du sol, orienté selon la rotation actuelle de la caméra.
	var forward := -global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	position += right * offset.x - forward * offset.y
	position.x = clamp(position.x, bounds.position.x, bounds.end.x)
	position.z = clamp(position.z, bounds.position.y, bounds.end.y)


func _apply_camera() -> void:
	var pitch := deg_to_rad(pitch_degrees)
	camera.position = Vector3(0.0, sin(pitch) * _distance, cos(pitch) * _distance)
	camera.look_at(global_position, Vector3.UP)
