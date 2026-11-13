class_name BuildingSystem
extends Node3D
## Pose de bâtiments prédéfinis dans le mode Terre.
##
## - Aperçu fantôme sous la souris (vert : possible, rouge : impossible + raison).
## - R : tourner d'un quart de tour. Sans rotation manuelle, la façade se
##   tourne toute seule vers la route la plus proche.
## - Terrassement automatique : l'emprise est aplanie à la hauteur moyenne,
##   avec un talus de deux cases autour.
## - Règles du bac à sable : accès à une voie obligatoire (option), coût du
##   bâtiment et du terrassement payé par la caisse (option « argent illimité »).
## - Données sérialisables : un bâtiment = {id, t, x, z, r, h}.

signal info_changed(text: String)
signal message(text: String)
signal changed
## Un bâtiment vient d'apparaître (pose, zonage ou chargement) / de disparaître.
signal added(bid: int)
signal removed(bid: int)
## La personnalisation d'un bâtiment posé a changé.
signal perso_changed(bid: int)

enum Mode { NONE, PLACE, DEMOLISH }

## Écart de hauteur maximal sous l'emprise avant de refuser le terrassement (m).
const MAX_RELIEF := 12.0
## Distance maximale entre la porte et une voie pour être desservi (m).
const ACCESS_MAX := 10.0
## Recul de la porte par rapport au bord de la chaussée, quand le bâtiment se
## cale le long d'une voie (m).
const SETBACK := 1.5
## Largeur du talus autour de l'emprise (cases).
const APRON := 2
## Coût du terrassement par case et par mètre de hauteur déplacée (€).
const EARTH_COST := 15.0
## Part du prix rendue à la démolition.
const REFUND := 0.5
const START_MONEY := 20_000_000

@export var world_path: NodePath
@export var camera_path: NodePath
@export var transport_path: NodePath

var world: TerrainWorld
var camera: Camera3D
var transport: TransportSystem

var mode: Mode = Mode.NONE
var type_id := "maison"
var rot := 0
var manual_rot := false
## Le long d'une voie courbe ou en biais : petit angle en plus du quart de
## tour (radians, ±45°) et case centrale calée sur le bord de la voie.
var angle := 0.0
## Caler automatiquement le bâtiment le long de la voie la plus proche
## (désactivé par R, qui reprend la main sur l'orientation).
var snap_to_road := true
var _place_center := Vector2i.ZERO
## Règles du bac à sable.
var require_access := true
var unlimited_money := false
var money: int = START_MONEY

## id -> {"id", "t", "x", "z", "r", "h"} (x, z : coin de l'emprise)
var buildings: Dictionary = {}
## Vector2i -> id du bâtiment qui occupe la case
var occupancy: Dictionary = {}
var next_id := 1
## Zone touchée par le dernier changement (vide = tout a pu changer, ex. chargement).
var last_change_rect := Rect2i()
## Si défini, Callable(case: Vector2i) -> bool : case prise par autre chose (blocs libres).
var extra_blocker: Callable
## Règle de pose en plus (production : richesse du sol) : (id, rect) ->
## {"reason": refus ou "", "info": texte ajouté à l'aide de pose}.
var extra_check: Callable
## Optionnel : Callable(id, rect, prix) -> int, part du prix offerte (kit de l'État,
## KitInstallation), et Callable(bid, id, rect) appelé quand elle a servi.
var remise: Callable
var remise_utilisee: Callable

var _nodes: Dictionary = {} # id -> MeshInstance3D
var _meshes: Dictionary = {} # type -> ArrayMesh
var _meshes_far: Dictionary = {} # type -> ArrayMesh sans finitions (vu de loin)
## Distance (m) au-delà de laquelle un bâtiment passe à sa version légère.
const LOIN := 320.0
var _material: Material
var _ghost: MeshInstance3D
var _plate: MeshInstance3D
var _link: MeshInstance3D
var _ok_mat: StandardMaterial3D
var _bad_mat: StandardMaterial3D
var _hover_mat: StandardMaterial3D
var _cursor := Vector2i.ZERO
var _cursor_valid := false
var _check := {}
var _hover_building := -1
var _right_press := Vector2.ZERO


func _ready() -> void:
	if not world_path.is_empty():
		world = get_node_or_null(world_path) as TerrainWorld
	if not camera_path.is_empty():
		camera = get_node_or_null(camera_path) as Camera3D
	if not transport_path.is_empty():
		transport = get_node_or_null(transport_path) as TransportSystem
	changed.connect(func() -> void: _summary_dirty = true)
	if transport != null:
		transport.network_changed.connect(func() -> void:
			_summary_dirty = true
			_access_cache.clear())
		# Une voie ne peut pas traverser un bâtiment.
		transport.blocker = func(c: Vector2i) -> bool:
			return occupancy.has(c) or (extra_blocker.is_valid() and extra_blocker.call(c))
	# Couleurs par sommet, et fenêtres qui s'allument la nuit (cycle jour/nuit).
	_material = NightWindows.building_material()
	_ok_mat = _tint(Color(0.35, 0.95, 0.45, 0.55))
	_bad_mat = _tint(Color(1.0, 0.3, 0.25, 0.55))
	_hover_mat = _tint(Color(1.0, 0.25, 0.2, 0.45))

	_ghost = MeshInstance3D.new()
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost.visible = false
	add_child(_ghost)
	_plate = MeshInstance3D.new()
	_plate.mesh = BoxMesh.new()
	_plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_plate.visible = false
	add_child(_plate)
	_link = MeshInstance3D.new()
	_link.mesh = BoxMesh.new()
	_link.material_override = _tint(Color(1, 0.85, 0.2, 0.85))
	_link.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_link.visible = false
	add_child(_link)


static func _tint(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func mesh_for(id: String, variant := 0, perso: Dictionary = {}) -> ArrayMesh:
	var key := _mesh_key(id, variant, perso)
	if not _meshes.has(key):
		_meshes[key] = BuildingCatalog.build_mesh(id, _material, true, variant, perso)
	return _meshes[key]


## Version légère (sans finitions) d'un modèle, pour le lointain.
func mesh_far_for(id: String, variant := 0, perso: Dictionary = {}) -> ArrayMesh:
	var key := _mesh_key(id, variant, perso)
	if not _meshes_far.has(key):
		_meshes_far[key] = BuildingCatalog.build_mesh(id, _material, false, variant, perso)
	return _meshes_far[key]


static func _mesh_key(id: String, variant: int, perso: Dictionary) -> String:
	var key := id if variant == 0 else "%s#%d" % [id, variant]
	if not perso.is_empty():
		key += "|" + JSON.stringify(perso, "", true)
	return key


## Personnalisation d'un bâtiment posé ({} : celui du catalogue).
func perso_of(bid: int) -> Dictionary:
	return (buildings[bid].get("perso", {}) as Dictionary) if buildings.has(bid) else {}


## Change la personnalisation (et la variante si v >= 0) d'un bâtiment posé.
func set_perso(bid: int, perso: Dictionary, v := -1) -> void:
	if not buildings.has(bid):
		return
	var b: Dictionary = buildings[bid]
	if perso.is_empty():
		b.erase("perso")
	else:
		b["perso"] = perso.duplicate()
	if v >= 0:
		b["v"] = v
	if _nodes.has(bid):
		removed.emit(bid)
		var old: Node = _nodes[bid]
		_nodes.erase(bid)
		old.queue_free()
		remove_child(old)
	_spawn(b)
	perso_changed.emit(bid)
	changed.emit()


## Nœud 3D d'un bâtiment (null s'il n'existe pas).
func node_of(bid: int) -> MeshInstance3D:
	return _nodes.get(bid, null) as MeshInstance3D


## Le bâtiment est-il encore en chantier (voir BatimentsVie) ?
func en_chantier(bid: int) -> bool:
	return buildings.has(bid) and bool(buildings[bid].get("chantier", false))


## Variante du modèle d'un bâtiment posé : stable pour un emplacement donné.
static func variant_for(id: String, x: int, z: int) -> int:
	var n := BuildingCatalog.variants_of(id)
	if n <= 1:
		return 0
	return posmod(hash(Vector2i(x, z)), n)


# --- Outils -------------------------------------------------------------------------

## Personnalisation donnée à chaque bâtiment posé par l'outil (modèle de la banque).
var place_perso: Dictionary = {}
var place_variant := -1


func set_place(id: String, perso: Dictionary = {}, v := -1) -> void:
	mode = Mode.PLACE
	type_id = id
	manual_rot = false
	place_perso = perso.duplicate()
	place_variant = v
	_ghost.mesh = mesh_for(id, maxi(v, 0), perso)
	_refresh()
	var t := BuildingCatalog.get_type(id)
	info_changed.emit("%s (%d × %d m) : clic pour poser · R : tourner · clic droit ou Échap : arrêter" % [t.name, t.w, t.d])


func set_demolish() -> void:
	mode = Mode.DEMOLISH
	_refresh()
	info_changed.emit("Démolir un bâtiment : clic dessus (%d %% du prix rendu, le terrain reste aplani)." % roundi(REFUND * 100))


func set_inactive() -> void:
	if mode == Mode.NONE:
		return
	mode = Mode.NONE
	_refresh()
	info_changed.emit("")


func rotate_quarter() -> void:
	rot = (rot + 1) % 4
	manual_rot = true
	_refresh()


func clear() -> void:
	for bid in _nodes.keys():
		removed.emit(bid)
	for n in _nodes.values():
		(n as Node).queue_free()
	_nodes.clear()
	buildings.clear()
	occupancy.clear()
	next_id = 1
	money = ReglagesPartie.actuel.argent_depart
	_hover_building = -1
	last_change_rect = Rect2i()
	changed.emit()


# --- Géométrie ----------------------------------------------------------------------

## Rectangle de cases occupé par un type posé autour de la case centrale.
static func rect_for(id: String, center: Vector2i, r: int) -> Rect2i:
	var fp := BuildingCatalog.footprint(id, r)
	return Rect2i(center - fp / 2, fp)


## Direction de la façade (porte) pour une rotation : 0 = −Z, puis quarts de tour.
static func front_dir(r: int) -> Vector3:
	return Basis(Vector3.UP, -r * PI / 2.0) * Vector3.FORWARD


static func rect_center(rect: Rect2i) -> Vector3:
	return Vector3(rect.position.x + rect.size.x / 2.0, 0.0, rect.position.y + rect.size.y / 2.0)


## Point juste devant la porte.
static func door_point(id: String, rect: Rect2i, r: int, a := 0.0) -> Vector3:
	var t := BuildingCatalog.get_type(id)
	return rect_center(rect) + front_dir(r).rotated(Vector3.UP, a) * (float(t.d) / 2.0 + 0.5)


## Cases couvertes par le bâtiment (emprise tournée de a radians en plus du quart de tour r).
static func cells_for(id: String, center: Vector2i, r: int, a := 0.0) -> Array:
	var rect := rect_for(id, center, r)
	var out := []
	if absf(a) < 0.001:
		for x in range(rect.position.x, rect.end.x):
			for z in range(rect.position.y, rect.end.y):
				out.append(Vector2i(x, z))
		return out
	var c := rect_center(rect)
	var hx := rect.size.x / 2.0
	var hz := rect.size.y / 2.0
	var ca := cos(a)
	var sa := sin(a)
	var reach := ceili(sqrt(hx * hx + hz * hz)) + 1
	for x in range(floori(c.x) - reach, floori(c.x) + reach + 1):
		for z in range(floori(c.z) - reach, floori(c.z) + reach + 1):
			var dx := x + 0.5 - c.x
			var dz := z + 0.5 - c.z
			# Repère du bâtiment (rotation inverse autour de Y).
			var lx := dx * ca - dz * sa
			var lz := dx * sa + dz * ca
			if absf(lx) <= hx + 0.35 and absf(lz) <= hz + 0.35:
				out.append(Vector2i(x, z))
	return out


## Calage le long de la voie la plus proche du curseur : {center, r, a} ou {}.
## La façade regarde la voie, parallèle à elle au point le plus proche, et la
## porte est à SETBACK mètres du bord de la chaussée.
func road_snap(id: String, cursor: Vector2i) -> Dictionary:
	if transport == null:
		return {}
	var t := BuildingCatalog.get_type(id)
	var modes := []
	for type in t.get("access", []):
		modes.append(TransportTypes.mode_of(type))
	if modes.is_empty():
		return {}
	var q := Vector2(cursor.x + 0.5, cursor.y + 0.5)
	var reach := float(t.d) + 12.0
	var best := {}
	for eid in transport.edges_near(Vector3(q.x, 0, q.y), reach + 20.0):
		var e: Dictionary = transport.network.edges[eid]
		if not TransportTypes.mode_of(e.t) in modes:
			continue
		var pts: PackedVector3Array = e.pts
		for i in pts.size() - 1:
			var pa := Vector2(pts[i].x, pts[i].z)
			var pb := Vector2(pts[i + 1].x, pts[i + 1].z)
			var ab := pb - pa
			if ab.length_squared() < 1e-6:
				continue
			var u := clampf((q - pa).dot(ab) / ab.length_squared(), 0.0, 1.0)
			var p := pa + ab * u
			var dist := q.distance_to(p) - float(e.get("width", 4.0)) / 2.0
			if dist <= reach and (best.is_empty() or dist < best.dist):
				best = {"dist": dist, "p": p, "tan": ab.normalized(), "w": float(e.get("width", 4.0))}
	if best.is_empty():
		return {}
	var tan: Vector2 = best.tan
	var n := Vector2(-tan.y, tan.x)
	if n.dot(q - (best.p as Vector2)) < 0.0:
		n = -n
	# Façade vers la voie : direction −n. Lacet ψ tel que Basis(UP, ψ)·(0, 0, −1) = −n.
	var psi := atan2(n.x, n.y)
	var r := posmod(roundi(-psi / (PI / 2.0)), 4)
	var a := wrapf(psi + r * PI / 2.0, -PI, PI)
	var want: Vector2 = (best.p as Vector2) + n * (float(best.w) / 2.0 + SETBACK + float(t.d) / 2.0)
	# Case centrale dont le centre d'emprise est le plus proche du point voulu.
	var off := rect_center(rect_for(id, Vector2i.ZERO, r))
	var center := Vector2i(roundi(want.x - off.x), roundi(want.y - off.z))
	return {"center": center, "r": r, "a": a}



# --- Vérification ---------------------------------------------------------------------

## Accès : voie desservante la plus proche de la porte. {} si aucune.
func find_access(id: String, rect: Rect2i, r: int, a := 0.0) -> Dictionary:
	if transport == null:
		return {}
	var door := door_point(id, rect, r, a)
	var best := {}
	for type in BuildingCatalog.get_type(id).get("access", []):
		# "route" ou "chemin" : toute classe de voie de ce mode (rue, avenue…).
		var mode := TransportTypes.mode_of(type)
		# Seuls les tronçons proches de la porte (index spatial du réseau).
		for eid in transport.edges_near(door, ACCESS_MAX + 30.0):
			var e: Dictionary = transport.network.edges[eid]
			if TransportTypes.mode_of(e.t) != mode:
				continue
			var reach := ACCESS_MAX + float(e.get("width", 4.0)) / 2.0
			var hit := transport.network.nearest_on_edge(eid, door)
			if hit.dist <= reach and (best.is_empty() or hit.dist < best.dist):
				best = {"dist": hit.dist, "pos": hit.pos, "type": type, "door": door}
	return best


## Analyse complète d'une pose : {ok, reason, rect, h, cost, access, earth}.
## grown : bâtiment poussé dans une zone (accès toujours exigé, rien à payer).
func check_place(id: String, center: Vector2i, r: int, grown := false, a := 0.0) -> Dictionary:
	var t := BuildingCatalog.get_type(id)
	var rect := rect_for(id, center, r)
	var cells := cells_for(id, center, r, a)
	var res := {"ok": false, "reason": "", "rect": rect, "h": 0.0, "cost": 0, "access": {}, "earth": 0.0, "cells": cells, "a": a}
	if t.is_empty() or world == null:
		res.reason = "Type de bâtiment inconnu."
		return res
	var lo := INF
	var hi := -INF
	var sum := 0.0
	var n := 0
	for cc in cells:
		var c: Vector2i = cc
		var x := c.x
		var z := c.y
		if occupancy.has(c):
			res.reason = "Il y a déjà un bâtiment ici."
			return res
		if transport != null and transport.is_cell_occupied(c):
			res.reason = "Une voie passe sur l'emplacement."
			return res
		if extra_blocker.is_valid() and extra_blocker.call(c):
			res.reason = "Des blocs sont construits ici."
			return res
		var h := world.cell_height(c)
		if is_nan(h):
			res.reason = "Relief encore en chargement."
			return res
		if h < 0.0:
			res.reason = "On ne construit pas dans la mer."
			return res
		lo = minf(lo, h)
		hi = maxf(hi, h)
		sum += h
		n += 1
		# Le biome (10 m de résolution) est lu une case sur trois.
		if x % 3 == 0 and z % 3 == 0 and world.cell_biome(c) == 80:
			res.reason = "On ne construit pas sur un lac ou une rivière."
			return res
	if hi - lo > MAX_RELIEF:
		res.reason = "Terrain trop pentu : %.0f m de dénivelé (maximum %.0f m)." % [hi - lo, MAX_RELIEF]
		return res
	var target := snappedf(sum / n, world.height_step)
	# Desservi par une voie : le rez-de-chaussée se cale à la hauteur de la
	# chaussée devant la porte (la parcelle est terrassée), pas en contrebas.
	res.access = find_access(id, rect, r, a)
	if not res.access.is_empty():
		var road_h := snappedf(float((res.access.pos as Vector3).y), world.height_step)
		if maxf(absf(hi - road_h), absf(lo - road_h)) <= MAX_RELIEF:
			target = road_h
	res.h = target
	var earth := 0.0
	for c in cells:
		earth += absf(world.cell_height(c) - target)
	if not res.access.is_empty():
		for c in path_cells(res.access.door, res.access.pos):
			if not c in cells:
				var hc := world.cell_height(c)
				if not is_nan(hc):
					earth += absf(hc - target)
	res.earth = earth
	res.cost = ReglagesPartie.prix(BuildingCatalog.cost(id) + roundi(earth * EARTH_COST))
	if not grown:
		var lock := ReglagesPartie.actuel.raison_blocage(id)
		if lock != "":
			res.reason = lock
			return res
	if extra_check.is_valid() and not grown:
		var ex: Dictionary = extra_check.call(id, rect)
		res["info"] = String(ex.get("info", ""))
		if String(ex.get("reason", "")) != "":
			res.reason = String(ex.reason)
			return res
	if grown:
		res.cost = 0
	elif remise.is_valid() and not unlimited_money:
		var off := int(remise.call(id, rect, int(res.cost)))
		if off > 0:
			res.cost = int(res.cost) - off
			res["remise"] = off
			res["info"] = ("%s · " % String(res.get("info", "")) if String(res.get("info", "")) != "" else "") + \
				"Kit de l'État : %s offerts" % format_money(off)
	var needs_access := not (t.get("access", []) as Array).is_empty()
	if (require_access or grown) and needs_access and res.access.is_empty():
		var names: Array[String] = []
		for acc_type in t.get("access", []):
			names.append(String(TransportTypes.get_type(acc_type).get("name", acc_type)).to_lower())
		res.reason = "Il faut une %s à moins de %d m de la porte." % [" ou un ".join(names), int(ACCESS_MAX)]
		return res
	if not grown and not unlimited_money:
		# Plusieurs villes : c'est la caisse de la ville du lieu (ou du pays) qui paie.
		var dispo := money
		var qui := ""
		if Pays.instance != null and Pays.instance.a_des_villes():
			var k := Pays.instance.payeur_du_rect(rect)
			dispo = Pays.instance.solde(k)
			qui = " dans la caisse de " + Pays.instance.nom_de(k)
		if res.cost > dispo:
			res.reason = "Pas assez d'argent%s : %s nécessaires." % [qui, format_money(res.cost)]
			return res
	res.ok = true
	return res


## Rotation automatique : celle dont la porte est la plus proche d'une voie.
func best_rotation(id: String, center: Vector2i) -> int:
	var best_r := rot
	var best_d := INF
	for r in 4:
		var a := find_access(id, rect_for(id, center, r), r)
		if not a.is_empty() and a.dist < best_d - 0.01:
			best_d = a.dist
			best_r = r
	return best_r


# --- Pose et démolition -----------------------------------------------------------------

## Pose un bâtiment centré sur une case. Renvoie son id, ou -1 (raison dans message).
## zone > 0 : le bâtiment pousse dans cette zone (gratuit, sans message).
func place(id: String, center: Vector2i, r: int, zone := 0, a := 0.0) -> int:
	var res := check_place(id, center, r, zone > 0, a)
	if not res.ok:
		if zone == 0:
			message.emit(res.reason)
		return -1
	_terrace(res.cells, res.h)
	if not (res.access as Dictionary).is_empty():
		_terrace_path(res.access.door, res.access.pos, res.h)
	# Avec un chantier, le prix se paie au fil des travaux (BatimentsVie).
	var chantier := BatimentsVie.aura_chantier(id)
	if not unlimited_money and not chantier:
		var caisse_prev := Pays.au_rect(res.rect)
		money -= int(res.cost)
		Pays.retour(caisse_prev)
	var bid := next_id
	next_id += 1
	var rect: Rect2i = res.rect
	var e := {"id": bid, "t": id, "x": rect.position.x, "z": rect.position.y, "r": r, "a": a, "h": res.h, "cost": res.cost, "zone": zone}
	if chantier and int(res.cost) > 0:
		e["du"] = int(res.cost)
	_add(e)
	if int(res.get("remise", 0)) > 0 and remise_utilisee.is_valid():
		remise_utilisee.call(bid, id, rect)
	if zone == 0:
		if chantier:
			message.emit("Chantier de %s lancé : %s, payés au fil des travaux." % [BuildingCatalog.get_type(id).name, format_money(res.cost)])
		else:
			message.emit("%s construit pour %s." % [BuildingCatalog.get_type(id).name, format_money(res.cost)])
	last_change_rect = rect.grow(3)
	changed.emit()
	return bid


## Optionnel : Callable(bid) -> String, raison qui empêche de démolir ("" : permis).
var demolish_check: Callable


func demolish(bid: int) -> void:
	if not buildings.has(bid):
		return
	if demolish_check.is_valid():
		var why := String(demolish_check.call(bid))
		if why != "":
			message.emit(why)
			return
	var b: Dictionary = buildings[bid]
	var rect := _rect_of(b)
	for c in _cells_of(b):
		occupancy.erase(c)
	if _nodes.has(bid):
		removed.emit(bid)
		(_nodes[bid] as Node).queue_free()
		_nodes.erase(bid)
	buildings.erase(bid)
	# Chantier pas fini : seule la part déjà payée compte.
	var back := roundi(float(int(b.get("cost", 0)) - int(b.get("du", 0))) * REFUND)
	if not unlimited_money:
		var caisse_prev := Pays.au_rect(rect)
		money += back
		Pays.retour(caisse_prev)
	if _hover_building == bid:
		_hover_building = -1
	message.emit("%s démoli (%s rendus)." % [BuildingCatalog.get_type(b.t).get("name", b.t), format_money(back)])
	last_change_rect = rect.grow(3)
	changed.emit()


## Retire un bâtiment sans remboursement ni message (il est remplacé, par
## exemple reconstruit en murs fins).
func remove_quietly(bid: int) -> void:
	if not buildings.has(bid):
		return
	var b: Dictionary = buildings[bid]
	for c in _cells_of(b):
		occupancy.erase(c)
	if _nodes.has(bid):
		removed.emit(bid)
		(_nodes[bid] as Node).queue_free()
		_nodes.erase(bid)
	buildings.erase(bid)
	if _hover_building == bid:
		_hover_building = -1
	last_change_rect = _rect_of(b).grow(3)
	changed.emit()


## Remet un bâtiment retiré par remove_quietly (même id, mêmes données).
func restore(b: Dictionary) -> void:
	if buildings.has(int(b.id)):
		return
	_add(b)
	last_change_rect = _rect_of(b).grow(3)
	changed.emit()


func building_at(c: Vector2i) -> int:
	return int(occupancy.get(c, -1))


func _rect_of(b: Dictionary) -> Rect2i:
	return Rect2i(Vector2i(int(b.x), int(b.z)), BuildingCatalog.footprint(b.t, int(b.r)))


## Case centrale (celle passée à place()) d'un bâtiment posé.
func _center_of(b: Dictionary) -> Vector2i:
	return Vector2i(int(b.x), int(b.z)) + BuildingCatalog.footprint(b.t, int(b.r)) / 2


func _cells_of(b: Dictionary) -> Array:
	return cells_for(b.t, _center_of(b), int(b.r), float(b.get("a", 0.0)))


func _add(b: Dictionary) -> void:
	var bid := int(b.id)
	buildings[bid] = b
	var rect := _rect_of(b)
	for c in _cells_of(b):
		occupancy[c] = bid
	if not b.has("v"):
		b["v"] = variant_for(String(b.t), int(b.x), int(b.z))
	_spawn(b)


## Nœud 3D (maillage, collision, version lointaine) d'un bâtiment.
func _spawn(b: Dictionary) -> void:
	var bid := int(b.id)
	var rect := _rect_of(b)
	var v := int(b.v)
	var perso: Dictionary = b.get("perso", {})
	var mi := MeshInstance3D.new()
	mi.name = "Batiment_%d" % bid
	mi.mesh = mesh_for(b.t, v, perso)
	mi.position = rect_center(rect) + Vector3(0, float(b.h), 0)
	mi.rotation.y = -int(b.r) * PI / 2.0 + float(b.get("a", 0.0))
	mi.visibility_range_end = 1400.0
	# Modèle Blender (stades) : il garde ses matériaux, ni usure ni chantier.
	if BuildingCatalog.get_type(b.t).has("glb") and BuildingCatalog.get_type(b.t).has("stade"):
		mi.set_meta("glb", true)
	# Collision : le personnage de la vue au sol ne traverse pas le bâtiment.
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var bb := mi.mesh.get_aabb()
	box.size = bb.size
	shape.shape = box
	shape.position = bb.get_center()
	body.add_child(shape)
	mi.add_child(body)
	# Au loin, la version sans finitions (5 fois moins de triangles).
	if BlocMesh.details_enabled and not BuildingCatalog.get_type(b.t).has("blocks") and not mi.has_meta("glb"):
		mi.visibility_range_end = LOIN
		var far := MeshInstance3D.new()
		far.name = "Loin"
		far.mesh = mesh_far_for(b.t, v, perso)
		far.visibility_range_begin = LOIN
		far.visibility_range_end = 1400.0
		mi.add_child(far)
	add_child(mi)
	_nodes[bid] = mi
	added.emit(bid)


## Aplanit l'emprise et adoucit un talus autour (sans toucher aux voies ni aux autres bâtiments).
## Cases du chemin d'accès (3 m de large) entre la porte et la voie.
func path_cells(door: Vector3, road: Vector3) -> Array:
	var out := {}
	var a := Vector2(door.x, door.z)
	var b := Vector2(road.x, road.z)
	var d := b - a
	var n := maxi(1, ceili(d.length() / 0.5))
	var side := Vector2(-d.y, d.x).normalized() if d.length() > 0.01 else Vector2.ZERO
	for i in n + 1:
		var p := a + d * (float(i) / n)
		for k in [-1.0, 0.0, 1.0]:
			var q: Vector2 = p + side * k
			var c := Vector2i(floori(q.x), floori(q.y))
			if occupancy.has(c) or (transport != null and transport.is_cell_occupied(c)):
				continue
			out[c] = true
	return out.keys()


## Parvis : le chemin de la porte à la voie, au niveau du bâtiment.
func _terrace_path(door: Vector3, road: Vector3, target: float) -> void:
	var cells := path_cells(door, road)
	for c in cells:
		world.modifications[c] = target
	world.mark_cells_dirty(cells)


func _terrace(footprint: Array, target: float) -> void:
	var cells := {}
	# Anneaux de talus autour de l'emprise (distance en cases, 8 voisins).
	var ring := {}
	for c in footprint:
		ring[c] = 0
	var front: Array = footprint.duplicate()
	for k in range(1, APRON + 1):
		var nxt := []
		for c in front:
			for dx in [-1, 0, 1]:
				for dz in [-1, 0, 1]:
					var n: Vector2i = c + Vector2i(dx, dz)
					if not ring.has(n):
						ring[n] = k
						nxt.append(n)
		front = nxt
	for cc in ring:
		var c: Vector2i = cc
		if int(ring[c]) == 0:
			cells[c] = target
			continue
		if occupancy.has(c) or (transport != null and transport.is_cell_occupied(c)):
			continue
		var h := world.cell_height(c)
		if is_nan(h):
			continue
		var u := float(ring[c]) / float(APRON + 1)
		cells[c] = snappedf(lerpf(target, h, u), world.height_step)
	# Les cases de l'emprise sont toujours enregistrées : pas d'arbres dessous.
	for c in cells:
		world.modifications[c] = cells[c]
	world.mark_cells_dirty(cells.keys())


# --- Souris et clavier ------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if mode == Mode.NONE or camera == null or world == null:
		return
	if event is InputEventMouseMotion:
		_update_cursor((event as InputEventMouseMotion).position)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				_right_press = mb.position
			elif mb.position.distance_to(_right_press) < 5.0:
				set_inactive()
			return
		if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
			return
		_update_cursor(mb.position)
		if not _cursor_valid:
			return
		get_viewport().set_input_as_handled()
		if mode == Mode.DEMOLISH:
			if _hover_building >= 0:
				var at := _nodes[_hover_building].global_position as Vector3 if _nodes.has(_hover_building) else Vector3.ZERO
				var had := buildings.has(_hover_building)
				demolish(_hover_building)
				if had and not buildings.has(_hover_building):
					Son.jouer_a("demolition", at)
				else:
					Son.jouer("ui_erreur", -4.0, 0.0, "Interface")
				_refresh()
			return
		var nb := place(type_id, _place_center, rot, 0, angle)
		if nb < 0:
			Son.jouer("ui_erreur", -4.0, 0.0, "Interface")
		if nb >= 0:
			Son.jouer("pose_batiment", -2.0, 0.08)
			if not place_perso.is_empty() or place_variant >= 0:
				set_perso(nb, place_perso, place_variant)
			_refresh()
	elif event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo:
			return
		if key.keycode == KEY_ESCAPE:
			set_inactive()
			get_viewport().set_input_as_handled()
		elif key.physical_keycode == KEY_R and mode == Mode.PLACE:
			rotate_quarter()
			get_viewport().set_input_as_handled()


func _update_cursor(screen: Vector2) -> void:
	var hit: Variant = world.pick_cell(camera.project_ray_origin(screen), camera.project_ray_normal(screen))
	var valid := hit != null
	var c: Vector2i = hit if valid else _cursor
	if c == _cursor and valid == _cursor_valid:
		return
	_cursor = c
	_cursor_valid = valid
	_refresh()


## Met à jour l'aperçu, la surbrillance et le texte d'aide.
func _refresh() -> void:
	_ghost.visible = false
	_plate.visible = false
	_link.visible = false
	_set_hover(-1)
	if mode == Mode.DEMOLISH and _cursor_valid:
		_set_hover(building_at(_cursor))
		if _hover_building >= 0:
			var b: Dictionary = buildings[_hover_building]
			var back := roundi(float(int(b.get("cost", 0)) - int(b.get("du", 0))) * REFUND)
			var en_cours := " (chantier à %d %%)" % floori(float(b.av) * 100.0) if b.has("av") else ""
			info_changed.emit("Démolir %s%s : clic (%s rendus)" % [BuildingCatalog.get_type(b.t).name, en_cours, format_money(back)])
		return
	if mode != Mode.PLACE or not _cursor_valid:
		return
	_place_center = _cursor
	angle = 0.0
	if not manual_rot:
		rot = best_rotation(type_id, _cursor)
		var snap := road_snap(type_id, _cursor) if snap_to_road else {}
		if not snap.is_empty():
			_place_center = snap.center
			rot = snap.r
			angle = snap.a
	_check = check_place(type_id, _place_center, rot, false, angle)
	var rect: Rect2i = _check.rect
	var h: float = _check.h
	if h == 0.0:
		h = maxf(world.cell_height(_cursor), 0.0) if not is_nan(world.cell_height(_cursor)) else 0.0
	var center := rect_center(rect)
	_ghost.visible = true
	_ghost.position = center + Vector3(0, h + 0.05, 0)
	_ghost.rotation.y = -rot * PI / 2.0 + angle
	_ghost.material_override = _ok_mat if _check.ok else _bad_mat
	_plate.visible = true
	(_plate.mesh as BoxMesh).size = Vector3(rect.size.x + 0.1, 0.4, rect.size.y + 0.1)
	_plate.position = center + Vector3(0, h + 0.05, 0)
	_plate.rotation.y = angle
	_plate.material_override = _ok_mat if _check.ok else _bad_mat
	var acc: Dictionary = _check.access
	if not acc.is_empty():
		var a: Vector3 = acc.door
		a.y = h + 0.3
		var b: Vector3 = acc.pos
		b.y += 0.3
		var len := Vector2(a.x - b.x, a.z - b.z).length()
		if len > 0.2:
			_link.visible = true
			(_link.mesh as BoxMesh).size = Vector3(0.5, 0.2, len)
			_link.position = (a + b) / 2.0
			_link.look_at(b, Vector3.UP)
	var t := BuildingCatalog.get_type(type_id)
	var txt := "%s (%d × %d m) · %s" % [t.name, t.w, t.d, format_money(int(_check.cost))]
	if _check.earth > 0.0:
		txt += " dont terrassement %s" % format_money(ReglagesPartie.prix(roundi(_check.earth * EARTH_COST)))
	txt += " · " + ("desservi par une %s" % String(TransportTypes.get_type(acc.type).name).to_lower() if not acc.is_empty() else "aucune voie à proximité")
	if String(_check.get("info", "")) != "":
		txt += "\n" + String(_check.info)
	if not _check.ok:
		txt += "\n✗ " + String(_check.reason)
	txt += "\nClic : poser · R : tourner%s · clic droit ou Échap : arrêter" % ("" if manual_rot else " (calé le long de la route)" if angle != 0.0 or _place_center != _cursor else " (orientation auto vers la route)")
	info_changed.emit(txt)


func _set_hover(bid: int) -> void:
	if bid == _hover_building:
		return
	if _hover_building >= 0 and _nodes.has(_hover_building):
		(_nodes[_hover_building] as MeshInstance3D).material_overlay = null
	_hover_building = bid
	if bid >= 0 and _nodes.has(bid):
		(_nodes[bid] as MeshInstance3D).material_overlay = _hover_mat


# --- Chiffres ------------------------------------------------------------------------

static func format_money(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = " " + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if v < 0 else "") + s + out + " €"


## Prix court pour les listes : « 280 k€ », « 1,5 M€ ».
static func format_short(v: int) -> String:
	if v >= 1_000_000:
		var m := float(v) / 1_000_000.0
		return ("%d M€" % roundi(m)) if m >= 10.0 or is_equal_approx(m, roundf(m)) else ("%.1f M€" % m).replace(".", ",")
	if v >= 1000:
		return "%d k€" % roundi(v / 1000.0)
	return "%d €" % v


## Totaux : logements, emplois, visiteurs, nombre par catégorie.
func totals() -> Dictionary:
	var out := {"logements": 0, "emplois": 0, "visiteurs": 0, "count": buildings.size(), "non_desservis": 0}
	for b in buildings.values():
		var t := BuildingCatalog.get_type(b.t)
		for k in ["logements", "emplois", "visiteurs"]:
			out[k] += int(t.get(k, 0))
		var bid := int(b.id)
		if not _access_cache.has(bid):
			_access_cache[bid] = (t.get("access", []) as Array).is_empty() or not find_access(b.t, _rect_of(b), int(b.r), float(b.get("a", 0.0))).is_empty()
		if not _access_cache[bid]:
			out.non_desservis += 1
	return out


var _summary := ""
var _summary_dirty := true
## Bâtiment desservi par une voie ? id -> bool (vidé quand le réseau change).
var _access_cache := {}


func summary() -> String:
	if not _summary_dirty:
		return _summary
	_summary_dirty = false
	var t := totals()
	var s := "Bâtiments : %d   ·   Logements : %d   ·   Emplois : %d" % [t.count, t.logements, t.emplois]
	if t.non_desservis > 0:
		s += "   ·   %d sans accès" % t.non_desservis
	_summary = s
	return s


# --- Sauvegarde ---------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var list := []
	for b in buildings.values():
		var e := {"id": b.id, "t": b.t, "x": b.x, "z": b.z, "r": b.r, "a": b.get("a", 0.0), "h": b.h, "cost": b.get("cost", 0), "zone": b.get("zone", 0)}
		# Variante du modèle, dates, avancement et reste à payer du chantier (BatimentsVie) ;
		# chantier en pause ou passé en premier, places du campement (Fondateurs).
		for key in ["v", "ne", "fin", "av", "hr", "du", "perso", "pause", "ordre", "nlog", "nemp"]:
			if b.has(key):
				e[key] = b[key]
		list.append(e)
	return {"version": 1, "next_id": next_id, "money": money, "require_access": require_access,
		"unlimited_money": unlimited_money, "buildings": list}


func from_dict(data: Dictionary) -> void:
	clear()
	next_id = int(data.get("next_id", 1))
	money = int(data.get("money", START_MONEY))
	require_access = bool(data.get("require_access", true))
	unlimited_money = bool(data.get("unlimited_money", false))
	for b in data.get("buildings", []):
		if BuildingCatalog.get_type(String(b.t)).is_empty():
			continue
		var e := {"id": int(b.id), "t": String(b.t), "x": int(b.x), "z": int(b.z), "r": int(b.r),
			"a": float(b.get("a", 0.0)), "h": float(b.h), "cost": int(b.get("cost", 0)), "zone": int(b.get("zone", 0)),
			# Sans date (anciennes parties) : bâti depuis longtemps, pas de chantier.
			"ne": float(b.get("ne", 0.0)), "fin": float(b.get("fin", 0.0))}
		if b.has("v"):
			e["v"] = int(b.v)
		if b.has("av"):
			e["av"] = float(b.av)
			e["hr"] = float(b.get("hr", 0.0))
		if int(b.get("du", 0)) > 0:
			e["du"] = int(b.du)
		if bool(b.get("pause", false)):
			e["pause"] = true
		if b.has("ordre"):
			e["ordre"] = float(b.ordre)
		for key in ["nlog", "nemp"]:
			if b.has(key):
				e[key] = int(b[key])
		var pd = b.get("perso", {})
		if pd is Dictionary and not (pd as Dictionary).is_empty():
			e["perso"] = Personnalisation.clean(pd)
		_add(e)
		next_id = maxi(next_id, int(b.id) + 1)
	last_change_rect = Rect2i()
	changed.emit()
