class_name VueSol
extends Node3D
## Bascule entre la vue de gestion (de dessus) et la vue au sol avec un personnage,
## à la 3e personne (caméra derrière l'épaule qui ne traverse pas le décor) ou
## à la 1re personne (par les yeux du personnage).
##
## Commandes au sol :
## - V : changer de vue (dessus → 3e personne → 1re personne → dessus)
## - ZQSD / WASD / flèches : marcher · Maj : courir · Espace : sauter / remonter en nageant
## - Souris : regarder · Molette : rapprocher / éloigner la caméra (au plus près : 1re personne)
## - Échap : libérer la souris (clic dans la vue pour la reprendre)

signal vue_changee(vue: int)
## E ou clic gauche en vue au sol : ouvrir une porte, etc. (rayon depuis la caméra).
signal interaction(origine: Vector3, direction: Vector3)

enum Vue { DESSUS, TROISIEME, PREMIERE }

const NOMS := {Vue.DESSUS: "Vue de dessus", Vue.TROISIEME: "3e personne", Vue.PREMIERE: "1re personne"}

@export var world_path: NodePath
@export var rig_path: NodePath
@export var transport_path: NodePath
@export var hud_path: NodePath
@export var environment_path: NodePath
@export var sensibilite := 0.0025
@export var distance_min := 1.6
@export var distance_max := 9.0
## Rayon d'affichage du relief au sol (m) et brouillard qui en cache le bord.
@export var rayon_affichage := 320.0
@export var brouillard_sol := 0.006
## Brouillard au sol hors des tunnels ; brouillard_sol baisse sous terre (lu aussi par l'ambiance).
var _brouillard_air := 0.0

var vue: Vue = Vue.DESSUS
var personnage: Personnage
var collisions: CollisionsSol
var camera: Camera3D

var world: TerrainWorld
var rig: Node3D
var hud: Node
var _env: Environment
var _brouillard_dessus := 0.0

var _pivot: Node3D # suit la tête du personnage, porte le cap et l'inclinaison
var _bras: SpringArm3D # recule la caméra sans traverser le relief ni les murs
var _cap := 0.0
var _tangage := -0.25
var _distance := 4.5
var _ui: CanvasLayer
var _boutons: Array[Button] = []
var _aide: Label
var _viseur: Control
var _panneau_visible := true


func _ready() -> void:
	world = get_node(world_path) as TerrainWorld
	rig = get_node(rig_path) as Node3D
	if not hud_path.is_empty():
		hud = get_node(hud_path)
	if not environment_path.is_empty():
		_env = (get_node(environment_path) as WorldEnvironment).environment
		_brouillard_dessus = _env.fog_density
	_brouillard_air = brouillard_sol
	var network: TransportNetwork = null
	var trafic: Traffic = null
	if not transport_path.is_empty():
		var ts := get_node(transport_path) as TransportSystem
		network = ts.network
		trafic = ts.traffic

	personnage = Personnage.new()
	personnage.name = "Personnage"
	personnage.niveau_eau = TerrainWorld.WATER_LEVEL
	add_child(personnage)
	_set_actif(personnage, false)

	collisions = CollisionsSol.new()
	collisions.name = "CollisionsSol"
	add_child(collisions)
	collisions.setup(world, network, personnage, trafic)
	collisions.set_physics_process(false)

	_pivot = Node3D.new()
	_pivot.name = "PivotCamera"
	add_child(_pivot)
	_bras = SpringArm3D.new()
	_bras.margin = 0.2
	var boule := SphereShape3D.new()
	boule.radius = 0.25
	_bras.shape = boule
	_bras.add_excluded_object(personnage.get_rid())
	_pivot.add_child(_bras)
	camera = Camera3D.new()
	camera.name = "CameraSol"
	camera.fov = 70.0
	camera.near = 0.05
	camera.far = 1500.0
	_bras.add_child(camera)

	world.origin_changed.connect(func(_la: float, _lo: float) -> void:
		if vue != Vue.DESSUS:
			set_vue(Vue.DESSUS))
	_construire_ui()
	_maj_ui(false)


# --- Changement de vue --------------------------------------------------------------

func vue_suivante() -> void:
	set_vue(((vue + 1) % 3) as Vue)


func set_vue(v: Vue) -> void:
	if v == vue:
		return
	var avant := vue
	vue = v
	if avant == Vue.DESSUS:
		_descendre()
	if v == Vue.DESSUS:
		_remonter()
	else:
		camera.cull_mask = 0xFFFFF & ~Personnage.COUCHE_CORPS if v == Vue.PREMIERE else 0xFFFFF
		if v == Vue.PREMIERE:
			personnage.aligner_corps()
		_capturer(true)
	_maj_ui(true)
	vue_changee.emit(vue)


## Quitte la vue de dessus : le personnage apparaît au centre de la vue de gestion.
func _descendre() -> void:
	# On range les outils de construction : au sol, la souris sert à regarder.
	if hud and hud.has_signal("tool_selected"):
		var b: Array = hud.get("_buttons")
		if b and b.size() > 0:
			(b[0] as Button).button_pressed = true
		hud.emit_signal("tool_selected", 0)
	var p := rig.global_position
	_cap = rig.rotation.y
	_tangage = -0.2
	var h := world.cell_height(Vector2i(floori(p.x), floori(p.z)))
	var y := (maxf(h, TerrainWorld.WATER_LEVEL - 1.3) if not is_nan(h) else p.y) + 0.05
	personnage.teleporter(Vector3(p.x, y, p.z), _cap)
	_set_actif(personnage, true)
	collisions.set_physics_process(true)
	collisions.mettre_a_jour(personnage.global_position, 9)
	personnage.en_attente = not collisions.pret_a(personnage.global_position)
	rig.set_process(false)
	rig.set_process_unhandled_input(false)
	# Au sol, le panneau de construction est rangé ; il revient en vue de dessus.
	var panneau := _panneau_construction()
	if panneau:
		_panneau_visible = panneau.visible
		panneau.visible = false
	camera.make_current()
	world.set_view(camera, personnage)
	world.view_radius_override = rayon_affichage
	if _env:
		_env.fog_density = brouillard_sol
	_placer_camera(1.0)


## Retour à la vue de gestion, centrée sur le personnage.
func _remonter() -> void:
	_capturer(false)
	var p := personnage.global_position
	rig.global_position = Vector3(p.x, rig.global_position.y, p.z)
	rig.rotation.y = _cap
	rig.set_process(true)
	rig.set_process_unhandled_input(true)
	var panneau := _panneau_construction()
	if panneau:
		panneau.visible = _panneau_visible
	var cam_dessus := rig.get_node_or_null("Camera3D") as Camera3D
	if cam_dessus:
		cam_dessus.make_current()
		world.set_view(cam_dessus, rig)
	world.view_radius_override = 0.0
	if _env:
		_env.fog_density = _brouillard_dessus
	_set_actif(personnage, false)
	collisions.set_physics_process(false)


func _panneau_construction() -> CanvasLayer:
	return get_parent().get_node_or_null("PanneauConstruction") as CanvasLayer


func _set_actif(n: Node3D, on: bool) -> void:
	n.visible = on
	n.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED


func _capturer(on: bool) -> void:
	if on:
		get_viewport().gui_release_focus()
	if DisplayServer.get_name() == "headless":
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE


func _souris_capturee() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


# --- Entrées -----------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	var typing := get_viewport().gui_get_focus_owner() is LineEdit
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo and not typing and k.physical_keycode == KEY_V:
			vue_suivante()
			get_viewport().set_input_as_handled()
			return
		if vue == Vue.DESSUS:
			return
		if k.pressed and k.keycode == KEY_ESCAPE:
			_capturer(false)
			get_viewport().set_input_as_handled()
		elif k.pressed and not k.echo and not typing and k.physical_keycode == KEY_E:
			_interagir()
			get_viewport().set_input_as_handled()
		elif k.keycode >= KEY_0 and k.keycode <= KEY_9 or k.physical_keycode >= KEY_0 and k.physical_keycode <= KEY_9:
			# Pas de changement d'outil de construction pendant la marche.
			get_viewport().set_input_as_handled()
		return
	if vue == Vue.DESSUS or not _souris_capturee():
		return
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		tourner(mm.relative * sensibilite)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_interagir()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoomer(-1)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoomer(1)
		get_viewport().set_input_as_handled()


func _interagir() -> void:
	if camera == null:
		return
	var o := camera.global_position
	var d := -camera.global_transform.basis.z
	# En 3e personne, on part de la tête du personnage, dans la direction visée.
	if vue == Vue.TROISIEME and personnage != null:
		o = personnage.global_position + Vector3(0, 1.6, 0)
	interaction.emit(o, d)


func _unhandled_input(event: InputEvent) -> void:
	# Souris libérée : un clic dans la vue la reprend.
	if vue != Vue.DESSUS and not _souris_capturee() and event is InputEventMouseButton:
		if (event as InputEventMouseButton).pressed:
			_capturer(true)
			get_viewport().set_input_as_handled()


## Regarder : x = gauche/droite, y = haut/bas (radians).
func tourner(d: Vector2) -> void:
	_cap -= d.x
	_tangage = clampf(_tangage - d.y, deg_to_rad(-85.0), deg_to_rad(80.0))


## Molette : -1 rapproche, +1 éloigne. Au plus près on passe à la 1re personne.
func zoomer(sens: int) -> void:
	if vue == Vue.PREMIERE:
		if sens > 0:
			_distance = distance_min + 0.6
			set_vue(Vue.TROISIEME)
		return
	_distance = _distance * (1.15 if sens > 0 else 1.0 / 1.15)
	if _distance < distance_min:
		_distance = distance_min + 0.6
		set_vue(Vue.PREMIERE)
	_distance = minf(_distance, distance_max)


func _physics_process(_delta: float) -> void:
	if vue == Vue.DESSUS:
		return
	var typing := get_viewport().gui_get_focus_owner() is LineEdit
	var a := Vector2.ZERO
	if not typing:
		if Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			a.y += 1.0
		if Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			a.y -= 1.0
		if Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			a.x -= 1.0
		if Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			a.x += 1.0
	personnage.commande.avance = a
	personnage.commande.cap = _cap
	personnage.commande.course = not typing and Input.is_key_pressed(KEY_SHIFT)
	personnage.commande.saut = not typing and Input.is_physical_key_pressed(KEY_SPACE)
	# Relief pas encore chargé sous ses pieds (marche très loin, téléchargement) : il attend.
	if not personnage.en_attente and not collisions.pret_a(personnage.global_position):
		personnage.en_attente = true
	if personnage.en_attente and collisions.pret_a(personnage.global_position):
		# Le relief est arrivé : on pose le personnage dessus.
		var p := personnage.global_position
		var h := world.cell_height(Vector2i(floori(p.x), floori(p.z)))
		if not is_nan(h) and p.y < h - 0.3 and not _sous_tunnel(p):
			personnage.teleporter(Vector3(p.x, maxf(h, TerrainWorld.WATER_LEVEL - 1.3) + 0.05, p.z), _cap)
		personnage.en_attente = false
	# Passé sous le relief (case creusée sous ses pieds, chute) : on le remet dessus.
	var q := personnage.global_position
	var hq := world.cell_height(Vector2i(floori(q.x), floori(q.z)))
	if (not is_nan(hq) and q.y < hq - 2.5 and q.y > TerrainWorld.WATER_LEVEL - 1.0 and not _sous_tunnel(q)) or q.y < -600.0:
		personnage.teleporter(Vector3(q.x, (hq if not is_nan(hq) else 0.0) + 0.5, q.z), _cap)
	if vue == Vue.PREMIERE:
		personnage.aligner_corps()
	collisions.ecarter(personnage)
	# Dans un tunnel, moins de brouillard : il éclaircirait tout le tube.
	if _env:
		brouillard_sol = _brouillard_air * (0.15 if _sous_tunnel(q) else 1.0)
		_env.fog_density = brouillard_sol


## Section « personnage » de la sauvegarde : vue choisie et état du personnage.
func to_dict() -> Dictionary:
	return {"vue": int(vue), "cap": _cap, "tangage": _tangage, "distance": _distance, "etat": personnage.etat()}


func from_dict(d: Dictionary) -> void:
	set_vue(Vue.DESSUS)
	if d.is_empty():
		return
	_distance = float(d.get("distance", _distance))
	var v := int(d.get("vue", 0)) as Vue
	if v == Vue.DESSUS:
		return
	set_vue(v)
	personnage.appliquer_etat(d.get("etat", {}))
	_cap = float(d.get("cap", 0.0))
	_tangage = float(d.get("tangage", -0.2))
	# Le relief peut ne pas être encore chargé : il attend sur place.
	personnage.en_attente = not collisions.pret_a(personnage.global_position)


## Vrai si le point est dans un tunnel (sous la voûte, là où le relief est percé).
func _sous_tunnel(p: Vector3) -> bool:
	var c := Vector2i(floori(p.x), floori(p.z))
	return collisions.trous.has(c) and p.y < float(collisions.trous[c])


func _process(delta: float) -> void:
	if vue != Vue.DESSUS:
		_placer_camera(delta)


func _placer_camera(delta: float) -> void:
	var tete := personnage.global_position + Vector3(0.0, Personnage.YEUX, 0.0)
	if vue == Vue.TROISIEME:
		# Un peu au-dessus et à droite de la tête, comme par-dessus l'épaule.
		var droite := Vector3.RIGHT.rotated(Vector3.UP, _cap)
		var cible := tete + Vector3(0.0, 0.15, 0.0) + droite * 0.45
		_pivot.global_position = _pivot.global_position.lerp(cible, clampf(delta * 18.0, 0.0, 1.0))
		_bras.spring_length = _distance
	else:
		_pivot.global_position = tete
		_bras.spring_length = 0.0
	_pivot.rotation = Vector3(_tangage, _cap, 0.0)
	_viseur.visible = vue == Vue.PREMIERE


# --- Interface ----------------------------------------------------------------------

func _construire_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.name = "InterfaceVue"
	_ui.layer = 2
	add_child(_ui)
	var panneau := PanelContainer.new()
	# En haut au centre, sous l'horloge : la gauche et la droite sont prises par les autres panneaux.
	panneau.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panneau.position = Vector2(-120, 158)
	panneau.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_ui.add_child(panneau)
	var boite := HBoxContainer.new()
	panneau.add_child(boite)
	var titre := Label.new()
	titre.text = "Vue (V) :"
	boite.add_child(titre)
	var ligne := HBoxContainer.new()
	boite.add_child(ligne)
	var groupe := ButtonGroup.new()
	for v in [Vue.DESSUS, Vue.TROISIEME, Vue.PREMIERE]:
		var b := Button.new()
		b.text = ["Dessus", "3e pers.", "1re pers."][v]
		b.toggle_mode = true
		b.button_group = groupe
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = NOMS[v]
		b.pressed.connect(func() -> void: set_vue(v))
		ligne.add_child(b)
		_boutons.append(b)

	_aide = Label.new()
	_aide.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_aide.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_aide.position.y = 214
	_aide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aide.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_aide.add_theme_constant_override("outline_size", 5)
	_aide.text = "ZQSD marcher · Maj courir · Espace sauter · Souris regarder · Molette caméra · V changer de vue · Échap libérer la souris"
	_ui.add_child(_aide)

	_viseur = ColorRect.new()
	_viseur.color = Color(1, 1, 1, 0.85)
	_viseur.size = Vector2(4, 4)
	_viseur.set_anchors_preset(Control.PRESET_CENTER)
	_viseur.position = -_viseur.size * 0.5
	_viseur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viseur.visible = false
	_ui.add_child(_viseur)


func _maj_ui(annoncer: bool) -> void:
	if _boutons.size() == 3:
		_boutons[vue].set_pressed_no_signal(true)
	_aide.visible = vue != Vue.DESSUS
	if annoncer and hud and hud.has_method("show_message"):
		hud.call("show_message", NOMS[vue] + ".")
