class_name OutilSite
extends Node3D
## Outil des plans de site (menu Partage → Plans de site) :
## - « zone » : on choisit le rectangle à enregistrer (clic, glisser, relâcher) ;
## - « pose » : le plan suit la souris (cadre et emprises des bâtiments), R le
##   tourne d'un quart de tour, un clic le pose.
## Clic droit ou Échap : arrêter.

signal message(text: String)
## Zone choisie (mode « zone »).
signal zone_choisie(rect: Rect2i)
## Plan posé (mode « pose ») : le résultat de PlansSites.poser.
signal pose_faite(res: Dictionary)

const COULEUR_ZONE := Color(1.0, 0.82, 0.3, 0.3)
const COULEUR_PLAN := Color(0.49, 0.78, 1.0, 0.28)
const COULEUR_BAT := Color(0.49, 0.78, 1.0, 0.55)
## Emprises dessinées au plus (au-delà, le cadre suffit).
const MAX_BOITES := 300

var world: TerrainWorld
var camera: Camera3D
## Callable() -> Dictionary : le contexte de PlansSites (bs, allees, zoo…).
var contexte: Callable

var mode := ""
var plan: Dictionary = {}
var rot := 0
var _a := Vector2i.ZERO
var _b := Vector2i.ZERO
var _glisse := false
var _cell := Vector2i.ZERO
var _valid := false
var _right_press := Vector2.ZERO
var _cadre: MeshInstance3D
var _boites: Node3D
var _mat_zone: StandardMaterial3D
var _mat_plan: StandardMaterial3D
var _mat_bat: StandardMaterial3D


static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = true
	return m


func _ready() -> void:
	_mat_zone = _mat(COULEUR_ZONE)
	_mat_plan = _mat(COULEUR_PLAN)
	_mat_bat = _mat(COULEUR_BAT)
	_cadre = MeshInstance3D.new()
	_cadre.name = "Cadre"
	_cadre.mesh = BoxMesh.new()
	_cadre.visible = false
	add_child(_cadre)
	_boites = Node3D.new()
	_boites.name = "Emprises"
	add_child(_boites)


func actif() -> bool:
	return mode != ""


func choisir_zone() -> void:
	stop()
	mode = "zone"
	_glisse = false
	message.emit("Plan de site : clique sur un coin de la zone, glisse jusqu'au coin opposé et relâche (%d m de côté au plus) · clic droit ou Échap : arrêter" % PlansSites.MAX_SIDE)


func poser(p: Dictionary) -> void:
	stop()
	if p.is_empty():
		return
	plan = p
	rot = 0
	mode = "pose"
	_refaire_boites()
	message.emit("Poser « %s » (%s) : clic pour poser · R : tourner · clic droit ou Échap : arrêter" % [String(p.get("nom", "")), PlansSites.resume(p)])


func stop() -> void:
	if mode == "":
		return
	mode = ""
	plan = {}
	_glisse = false
	_cadre.visible = false
	_boites.visible = false
	message.emit("")


func _cam() -> Camera3D:
	var c := get_viewport().get_camera_3d()
	return c if c != null else camera


func _pick(screen: Vector2) -> Variant:
	var cam := _cam()
	if cam == null or world == null:
		return null
	return world.pick_cell(cam.project_ray_origin(screen), cam.project_ray_normal(screen))


func _unhandled_input(event: InputEvent) -> void:
	if mode == "":
		return
	if event is InputEventMouseMotion:
		var hit: Variant = _pick((event as InputEventMouseMotion).position)
		if hit != null:
			_survol(hit)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				_right_press = mb.position
			elif mb.position.distance_to(_right_press) < 5.0:
				stop()
			return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		var hit: Variant = _pick(mb.position)
		if hit == null:
			return
		get_viewport().set_input_as_handled()
		if mode == "zone":
			if mb.pressed:
				_a = hit
				_b = hit
				_glisse = true
				_dessine_zone()
			elif _glisse:
				_glisse = false
				_b = hit
				var r := zone()
				stop()
				zone_choisie.emit(r)
		elif mode == "pose" and mb.pressed:
			_survol(hit)
			var p := plan
			var res := PlansSites.poser(p, origine(), rot, contexte.call() if contexte.is_valid() else {})
			pose_faite.emit(res)
	elif event is InputEventKey:
		var k := event as InputEventKey
		if not k.pressed or k.echo:
			return
		if k.keycode == KEY_ESCAPE:
			stop()
			get_viewport().set_input_as_handled()
		elif k.keycode == KEY_R and mode == "pose" and not k.ctrl_pressed and not k.shift_pressed:
			rot = (rot + 1) % 4
			_refaire_boites()
			_dessine_plan()
			get_viewport().set_input_as_handled()


## Rectangle choisi (mode « zone »).
func zone() -> Rect2i:
	var lo := Vector2i(mini(_a.x, _b.x), mini(_a.y, _b.y))
	var hi := Vector2i(maxi(_a.x, _b.x), maxi(_a.y, _b.y))
	return Rect2i(lo, hi - lo + Vector2i.ONE)


## Coin −x −z où le plan se poserait (mode « pose ») : la souris au centre.
func origine() -> Vector2i:
	return _cell - PlansSites.taille(plan, rot) / 2


func _survol(c: Vector2i) -> void:
	_cell = c
	if mode == "zone" and _glisse:
		_b = c
		_dessine_zone()
	elif mode == "pose":
		_dessine_plan()


func _h(c: Vector2i) -> float:
	return world.cell_height(c) if world != null else 0.0


func _dessine_zone() -> void:
	var r := zone()
	var box := _cadre.mesh as BoxMesh
	box.size = Vector3(r.size.x, 0.6, r.size.y)
	_cadre.material_override = _mat_zone if r.size.x <= PlansSites.MAX_SIDE and r.size.y <= PlansSites.MAX_SIDE else _mat(Color(1, 0.3, 0.3, 0.3))
	_cadre.global_position = Vector3(r.position.x + r.size.x / 2.0, _h(r.get_center()) + 0.3, r.position.y + r.size.y / 2.0)
	_cadre.visible = true


func _dessine_plan() -> void:
	var s := PlansSites.taille(plan, rot)
	var o := origine()
	var box := _cadre.mesh as BoxMesh
	box.size = Vector3(s.x, 0.4, s.y)
	_cadre.material_override = _mat_plan
	var y := _h(o + s / 2)
	_cadre.global_position = Vector3(o.x + s.x / 2.0, y + 0.2, o.y + s.y / 2.0)
	_cadre.visible = true
	_boites.global_position = Vector3(o.x, y, o.y)
	_boites.visible = true


## Emprises des bâtiments (et des murs fins), dans le repère du coin du plan.
func _refaire_boites() -> void:
	for c in _boites.get_children():
		c.queue_free()
	var n := 0
	for b: Dictionary in plan.get("batiments", []):
		if n >= MAX_BOITES:
			break
		var t := BuildingCatalog.get_type(String(b.t))
		_boite(PlansSites.rect_batiment(b, plan, Vector2i.ZERO, rot), clampf(float(t.get("h", 6.0)) if t.has("h") else 6.0, 2.0, 30.0))
		n += 1
	for m: Dictionary in plan.get("murs", []):
		if n >= MAX_BOITES:
			break
		_boite(PlansSites.rect_murs(m, plan, rot), 3.0 * maxf(1.0, float((m.get("plan", {}) as Dictionary).get("etiquettes", {}).get("etages", 1))))
		n += 1


func _boite(r: Rect2i, hb: float) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(r.size.x, hb, r.size.y)
	mi.mesh = bm
	mi.material_override = _mat_bat
	mi.position = Vector3(r.position.x + r.size.x / 2.0, hb / 2.0, r.position.y + r.size.y / 2.0)
	_boites.add_child(mi)
