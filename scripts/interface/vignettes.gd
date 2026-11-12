class_name Vignettes
extends Node
## Vignettes des bâtiments du panneau Construire : chaque modèle est rendu une
## fois, en vue de trois quarts, dans un petit SubViewport, puis gardé en
## mémoire. Une vignette par image pour ne pas faire ramer le jeu.
## Sans affichage (tests en --headless), rien n'est rendu : l'icône de la
## catégorie reste à la place.

const SIZE := Vector2i(192, 128)

static var _cache := {}

## File d'attente : [id, [TextureRect…]].
var _queue: Array = []
var _viewport: SubViewport
var _camera: Camera3D
var _mesh: MeshInstance3D
var _busy := false
var _enabled := true


func _ready() -> void:
	_enabled = DisplayServer.get_name() != "headless"
	if not _enabled:
		return
	_viewport = SubViewport.new()
	_viewport.size = SIZE
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.85, 0.9, 1.0)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	_viewport.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.1
	_viewport.add_child(sun)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.near = 0.1
	_camera.far = 2000.0
	_viewport.add_child(_camera)
	_mesh = MeshInstance3D.new()
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_viewport.add_child(_mesh)


static func cached(id: String) -> Texture2D:
	return _cache.get(id)


## Demande la vignette de `id` pour `target` (posée dès qu'elle est prête).
func request(id: String, target: TextureRect) -> void:
	if _cache.has(id):
		target.texture = _cache[id]
		return
	if not _enabled:
		return
	for q in _queue:
		if q[0] == id:
			(q[1] as Array).append(target)
			return
	_queue.append([id, [target]])


## Oublie les demandes en attente (le panneau a changé de liste).
func cancel_all() -> void:
	_queue.clear()


func _process(_delta: float) -> void:
	if not _enabled or _busy or _queue.is_empty():
		return
	_render_next()


func _render_next() -> void:
	_busy = true
	var job: Array = _queue.pop_front()
	var id: String = job[0]
	var mesh := BuildingCatalog.build_mesh(id, NightWindows.building_material())
	_mesh.mesh = mesh
	var box := mesh.get_aabb()
	var c := box.get_center()
	var extent := maxf(box.size.length(), 1.0)
	var dir := Vector3(1.0, 0.85, 1.25).normalized()
	_camera.size = extent * 0.62
	_camera.position = c + dir * extent * 2.0
	_camera.look_at(c, Vector3.UP)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var img := _viewport.get_texture().get_image()
	if img != null and not img.is_empty():
		var tex := ImageTexture.create_from_image(img)
		_cache[id] = tex
		for t in job[1]:
			if is_instance_valid(t):
				(t as TextureRect).texture = tex
	_busy = false
