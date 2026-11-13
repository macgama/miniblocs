class_name PlanEditor
extends Node3D
## Murs, étages et intérieurs : l'autre mode de l'éditeur libre.
##
## Les blocs de 1 m restent faits pour le massif (soubassements, toits,
## clôtures). Ici, les murs font 20 cm d'épaisseur et se posent SUR les lignes
## de la grille, entre deux cases : une pièce de 4 × 4 cases garde 4 m de
## côté, et les cloisons ne mangent pas de case.
##
## - Un « plan » est un bâtiment : une hauteur de base y0 (dessus du plancher du
##   rez-de-chaussée) et des étages de H = 3 m, numérotés 0 (rez-de-chaussée),
##   1, 2… et −1, −2… pour les sous-sols (le terrain est creusé dessous).
## - Murs : clé Vector4i(x, étage, z, dir). dir 0 : de (x, z) à (x + 1, z) ;
##   dir 1 : de (x, z) à (x, z + 1). Côté a : vers −z (dir 0) ou −x (dir 1),
##   côté b : l'autre. Chaque côté a son matériau et sa teinte (codes
##   BlocFormes.encode). Une ouverture (porte, fenêtre…) est portée par le mur.
## - Planchers : clé Vector3i(x, étage, z), dalle de 20 cm sous le niveau de
##   l'étage, dessus t et plafond u (vu de l'étage du dessous).
## - Escaliers : clé Vector3i(x, étage, z) de la première case, sur 4 cases
##   dans la direction r (0 : +z, 1 : −x, 2 : −z, 3 : +x), 12 marches de 25 cm.
##
## Outils : Mur (clic glissé d'un coin à l'autre), Pièce (rectangle : quatre
## murs et le plancher), Sol, Ouverture, Peinture (un côté de mur ou un sol ;
## glissé : toute une pièce), Escalier, Gomme. Page haut / Page bas : étage
## actif ; les étages du dessus sont masqués (vue en coupe).

signal info_changed(text: String)
signal message(text: String)
signal changed
signal level_changed(text: String)

enum Tool { NONE, WALL, ROOM, FLOOR, OPENING, PAINT, STAIRS, ERASE }

## Hauteur d'un étage (m), plancher compris.
const H := 3.0
## Demi-épaisseur des murs (m).
const HALF := 0.1
## Épaisseur des planchers (m).
const SLAB := 0.2
## Profondeur des fondations sous les murs du rez-de-chaussée.
const FOUNDATION := 2.0
const MIN_LEVEL := -5
const MAX_LEVEL := 59
const STAIR_LEN := 4
const STAIR_STEPS := 12
const MAX_OP := 4096
const REFUND := 0.5
## Plâtre (plafonds), parquet chêne et béton (sols par défaut).
const CEILING_MAT := 55
const FLOOR_MAT := 35
const BASEMENT_MAT := 4
const FRAME_MAT := 57
const DOOR_MAT := 2
const GLASS_MAT := 10
const BRASS_MAT := 48
const NO_PREV := -1.0e9

## Ouvertures : bas (s) et haut (t) au-dessus du plancher, en mètres.
const OPENINGS := {
	"passage": {"name": "Passage", "s": 0.0, "t": 2.2, "price": 40, "desc": "Ouverture sans porte entre deux pièces."},
	"porte": {"name": "Porte", "s": 0.0, "t": 2.1, "price": 450, "leaf": true, "desc": "Porte pleine (E en vue au sol pour l'ouvrir)."},
	"porte_vitree": {"name": "Porte vitrée", "s": 0.0, "t": 2.1, "price": 600, "leaf": true, "glass": true, "desc": "Porte avec un vitrage."},
	"porte_fenetre": {"name": "Porte-fenêtre", "s": 0.0, "t": 2.2, "price": 700, "leaf": true, "glass": true, "full": true, "desc": "Porte entièrement vitrée, vers un jardin ou un balcon."},
	"fenetre": {"name": "Fenêtre", "s": 0.9, "t": 2.15, "price": 350, "window": true, "desc": "Fenêtre à croisillons, allège à 90 cm."},
	"fenetre_haute": {"name": "Fenêtre haute", "s": 1.5, "t": 2.1, "price": 250, "window": true, "desc": "Petite fenêtre (salle de bains, cuisine)."},
	"baie": {"name": "Baie vitrée", "s": 0.1, "t": 2.5, "price": 650, "bay": true, "desc": "Grand vitrage du sol au plafond."},
	"vitrine": {"name": "Vitrine", "s": 0.3, "t": 2.7, "price": 800, "bay": true, "desc": "Vitrine de magasin."},
}
const OPENING_ORDER := ["porte", "porte_vitree", "porte_fenetre", "passage", "fenetre", "fenetre_haute", "baie", "vitrine"]
const STAIR_DIRS := [Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 0)]

@export var world_path: NodePath
@export var camera_path: NodePath
@export var buildings_path: NodePath
@export var blocks_path: NodePath

var world: TerrainWorld
var camera: Camera3D
var buildings: BuildingSystem
var blocks: BlockEditor

var tool: Tool = Tool.NONE
var material := 5
var tint := 0
var opening := "porte"
var rot_offset := 0
## Étage actif (0 = rez-de-chaussée).
var level := 0
## Masquer les étages au-dessus de l'étage actif pendant l'édition.
var cutaway := true
## Vue en coupe demandée par un autre outil (meubles de l'intérieur).
var cut_override := false
## Murs et pièces posés sur ce nombre d'étages d'un coup (à partir de l'étage actif).
var wall_levels := 1

## id -> {id, y0, walls, floors, stairs, dug}
var plans: Dictionary = {}
## Vector2i -> id : cases occupées (bloquent les voies et les bâtiments).
var cells: Dictionary = {}

var _nodes: Dictionary = {} # id -> {étage: Node3D}
var _dirty: Dictionary = {} # id -> {étage: true}
var _bbox: Dictionary = {} # id -> Rect2i
var _undo: Array = []
var _active := ""
var _hover := {}
var _drag := false
var _drag_start := {}
var _right_press := Vector2.ZERO
var _ghost: MeshInstance3D
var _ghost_ok: StandardMaterial3D
var _ghost_bad: StandardMaterial3D
var _grid: MeshInstance3D
var _next_id := 1


func _ready() -> void:
	if not world_path.is_empty():
		world = get_node_or_null(world_path) as TerrainWorld
	if not camera_path.is_empty():
		camera = get_node_or_null(camera_path) as Camera3D
	if not buildings_path.is_empty():
		buildings = get_node_or_null(buildings_path) as BuildingSystem
	if not blocks_path.is_empty():
		blocks = get_node_or_null(blocks_path) as BlockEditor
	_ghost_ok = BuildingSystem._tint(Color(0.55, 0.85, 1.0, 0.45))
	_ghost_bad = BuildingSystem._tint(Color(1, 0.3, 0.25, 0.5))
	_ghost = MeshInstance3D.new()
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost.visible = false
	add_child(_ghost)
	_grid = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(48, 48)
	_grid.mesh = pm
	_grid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sh := Shader.new()
	sh.code = GRID_SHADER
	var gm := ShaderMaterial.new()
	gm.shader = sh
	_grid.material_override = gm
	_grid.visible = false
	add_child(_grid)


const GRID_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 f = fract(wp.xz);
	vec2 d = min(f, 1.0 - f);
	float line = 1.0 - smoothstep(0.0, 0.035, min(d.x, d.y));
	vec2 c = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xz;
	float fade = 1.0 - smoothstep(10.0, 24.0, distance(wp.xz, c));
	ALBEDO = vec3(1.0);
	ALPHA = line * fade * 0.55;
}
"""


# --- Outils -------------------------------------------------------------------------

func set_tool(t: Tool) -> void:
	tool = t
	_drag = false
	_hover = {}
	_ghost.visible = false
	_grid.visible = false
	_apply_cutaway()
	if t == Tool.NONE:
		info_changed.emit("")
	else:
		_emit_help()
	_emit_level()


func set_inactive() -> void:
	if tool != Tool.NONE:
		set_tool(Tool.NONE)


func set_material(m: int) -> void:
	material = clampi(m, 0, BlocMateriaux.LIST.size() - 1)
	if tool != Tool.NONE:
		_emit_help()


func set_tint(t: int) -> void:
	tint = clampi(t, 0, BlocMateriaux.TINTS.size() - 1)


func set_opening(kind: String) -> void:
	if OPENINGS.has(kind):
		opening = kind
	if tool != Tool.NONE:
		_emit_help()


func set_cutaway(on: bool) -> void:
	cutaway = on
	_apply_cutaway()


func step_level(d: int) -> void:
	level = clampi(level + d, MIN_LEVEL, MAX_LEVEL)
	_apply_cutaway()
	_emit_level()
	if tool != Tool.NONE:
		_emit_help()


## Va directement à un étage (échelle des étages du mode Créer).
func set_level(e: int) -> void:
	step_level(e - level)


## Murs par étage du bâtiment : {étage: nombre de murs} (un étage avec seulement
## un plancher compte 0 mur).
func level_counts(id: String) -> Dictionary:
	var out := {}
	if not plans.has(id):
		return out
	var p: Dictionary = plans[id]
	for k in p.floors:
		var e: int = (k as Vector3i).y
		if not out.has(e):
			out[e] = 0
	for k in p.walls:
		var e: int = (k as Vector4i).y
		out[e] = int(out.get(e, 0)) + 1
	return out


static func level_name(e: int) -> String:
	if e == 0:
		return "Rez-de-chaussée"
	if e < 0:
		return "Sous-sol %d" % -e
	return "%d%s étage" % [e, "er" if e == 1 else "e"]


func _emit_level() -> void:
	var t := level_name(level)
	if _active != "" and plans.has(_active):
		var lv := levels_of(_active)
		if not lv.is_empty():
			t += "  ·  bâtiment de %d niveau%s" % [lv.size(), "x" if lv.size() > 1 else ""]
	level_changed.emit(t)


func _emit_help() -> void:
	var mat: Dictionary = BlocMateriaux.LIST[material]
	var t := ""
	match tool:
		Tool.WALL:
			t = "Mur de 20 cm (%s, %s le mètre) : clic glissé d'un coin de case à l'autre" % [mat.name, BuildingSystem.format_money(ReglagesPartie.prix(wall_price(material)))]
		Tool.ROOM:
			t = "Pièce : clic glissé en rectangle (quatre murs en %s et le plancher)" % mat.name
		Tool.FLOOR:
			t = "Sol : clic glissé en rectangle (%s)" % mat.name
		Tool.OPENING:
			t = "%s : clic près d'un mur (%s)" % [OPENINGS[opening].name, BuildingSystem.format_money(ReglagesPartie.prix(int(OPENINGS[opening].price)))]
		Tool.PAINT:
			t = "Peinture (%s) : clic sur un côté de mur ou un sol · glissé : toute la pièce" % mat.name
		Tool.STAIRS:
			t = "Escalier vers l'étage du dessus (4 cases de long) : clic · R : tourner"
		Tool.ERASE:
			t = "Gomme : clic sur un mur, un sol, un escalier ou une ouverture · glissé : tout un rectangle"
	info_changed.emit("%s · %s · Page haut / Page bas : étage · clic droit : retirer · Ctrl+Z : annuler · Échap : arrêter" % [t, level_name(_eff_level())])


func clear() -> void:
	for id in plans.keys():
		_restore_terrain(id)
	plans.clear()
	cells.clear()
	_bbox.clear()
	_undo.clear()
	for id in _nodes:
		for n in (_nodes[id] as Dictionary).values():
			(n as Node).queue_free()
	_nodes.clear()
	_dirty.clear()
	_active = ""
	if blocks:
		blocks.set_clip(Rect2i(), INF)
	changed.emit()


# --- Prix ---------------------------------------------------------------------------

## Prix d'un mètre de mur (1 m × 2,8 m × 0,2 m) dans ce matériau.
static func wall_price(m: int) -> int:
	return maxi(1, roundi(float(BlocMateriaux.LIST[clampi(m, 0, BlocMateriaux.LIST.size() - 1)].price) * 0.6))


static func floor_price(m: int) -> int:
	return maxi(1, roundi(float(BlocMateriaux.LIST[clampi(m, 0, BlocMateriaux.LIST.size() - 1)].price) * 0.3))


const STAIR_PRICE := 1500


## Les prix des murs et étages sont des prix de base : le coût de la partie
## (ReglagesPartie.cout_construction) s'applique au moment de payer.
func _can_pay(amount: int) -> bool:
	return buildings == null or buildings.unlimited_money or buildings.money >= ReglagesPartie.prix(amount)


func _pay(amount: int) -> void:
	if buildings != null and not buildings.unlimited_money:
		buildings.money -= ReglagesPartie.prix(amount)


# --- Plans --------------------------------------------------------------------------

func base_y(id: String, e: int) -> float:
	return float(plans[id].y0) + e * H


func new_plan(y0: float) -> String:
	var id := "plan_%d" % _next_id
	while plans.has(id):
		_next_id += 1
		id = "plan_%d" % _next_id
	_next_id += 1
	plans[id] = {"id": id, "y0": y0, "walls": {}, "floors": {}, "stairs": {}, "dug": {}}
	_bbox[id] = Rect2i()
	return id


## Hauteur de base d'un nouveau bâtiment posé sur la case c.
func ground_level(c: Vector2i) -> float:
	var g := world.cell_height(c) if world != null else 0.0
	if is_nan(g):
		g = 0.0
	# Le plancher du rez-de-chaussée affleure le sol (le terrain est creusé
	# sous la dalle) : la porte est de plain-pied. Près d'une voie, on se
	# cale sur la chaussée.
	var road := _road_height(c)
	if not is_nan(road) and absf(road - g) <= 3.0:
		g = road
	return roundf(maxf(g, 0.0) / 0.5) * 0.5


## Remet un bâtiment de plain-pied (rez-de-chaussée au niveau du sol ou de
## la voie voisine, devant sa façade la plus basse). Les blocs posés dessus
## (toit) suivent. Renvoie le déplacement en mètres.
func reseat(id: String) -> float:
	if not plans.has(id):
		return 0.0
	var p: Dictionary = plans[id]
	var r: Rect2i = _bbox[id]
	_restore_terrain(id)
	# Niveau du sol devant les portes extérieures du rez-de-chaussée ;
	# sans porte, le point le plus bas autour de l'emprise.
	var g := INF
	for k in p.walls:
		var kw: Vector4i = k
		var kind := String(p.walls[kw].o)
		if kw.y != 0 or kind == "" or float(OPENINGS[kind].s) > 0.0:
			continue
		for c in wall_cells(kw):
			if not p.floors.has(Vector3i(c.x, 0, c.y)):
				g = minf(g, ground_level(c))
	if is_inf(g):
		for x in range(r.position.x - 1, r.end.x + 1):
			for z in [r.position.y - 1, r.end.y]:
				g = minf(g, ground_level(Vector2i(x, z)))
		for z in range(r.position.y, r.end.y):
			for x in [r.position.x - 1, r.end.x]:
				g = minf(g, ground_level(Vector2i(x, z)))
	if is_inf(g):
		g = float(p.y0)
	var d := g - float(p.y0)
	if absf(d) < 0.01:
		_sync_terrain(id)
		return 0.0
	var old_y0 := float(p.y0)
	p.y0 = g
	# Les blocs au-dessus du rez-de-chaussée (toit) suivent.
	if blocks != null:
		var dy := roundi(d / BlockEditor.UNIT_Y)
		var lo := old_y0 - SLAB
		var moved := {}
		for k in blocks.blocks.keys():
			var kb: Vector3i = k
			if r.grow(2).has_point(Vector2i(kb.x, kb.z)) and kb.y * BlockEditor.UNIT_Y >= lo:
				moved[kb] = blocks.blocks[kb]
				blocks._drop_block(kb)
		for k in moved:
			var kb2: Vector3i = k
			blocks._put_block(kb2 + Vector3i(0, dy, 0), moved[k])
		blocks.changed.emit()
	_after_change(id)
	return d


## Hauteur de la chaussée la plus proche (moins de 12 m), NAN s'il n'y en a pas.
func _road_height(c: Vector2i) -> float:
	if buildings == null or buildings.transport == null:
		return NAN
	var tr: TransportSystem = buildings.transport
	var p := Vector3(c.x + 0.5, 0.0, c.y + 0.5)
	var best := NAN
	var bd := 12.0
	for eid in tr.edges_near(p, 30.0):
		var e: Dictionary = tr.network.edges[eid]
		var hit := tr.network.nearest_on_edge(eid, p)
		var d := float(hit.dist) - float(e.get("width", 4.0)) / 2.0
		if d < bd:
			bd = d
			best = float((hit.pos as Vector3).y)
	return best


## Bâtiment le plus proche dont l'emprise (agrandie de margin cases) contient c.
func plan_at(c: Vector2i, margin := 2) -> String:
	var best := ""
	var bd := INF
	for id in _bbox:
		var r: Rect2i = _bbox[id]
		if r.size == Vector2i.ZERO:
			continue
		if r.grow(margin).has_point(c):
			var center := Vector2(r.position) + Vector2(r.size) / 2.0
			var d := center.distance_to(Vector2(c))
			if d < bd:
				bd = d
				best = id
	return best


func levels_of(id: String) -> Array:
	var seen := {}
	var p: Dictionary = plans[id]
	for k in p.floors:
		seen[(k as Vector3i).y] = true
	for k in p.walls:
		seen[(k as Vector4i).y] = true
	var out := seen.keys()
	out.sort()
	return out


func _update_bbox(id: String) -> void:
	var p: Dictionary = plans[id]
	var lo := Vector2i(1 << 30, 1 << 30)
	var hi := Vector2i(-(1 << 30), -(1 << 30))
	var any := false
	for k in p.floors:
		var kk: Vector3i = k
		lo = Vector2i(mini(lo.x, kk.x), mini(lo.y, kk.z))
		hi = Vector2i(maxi(hi.x, kk.x + 1), maxi(hi.y, kk.z + 1))
		any = true
	for k in p.walls:
		var kw: Vector4i = k
		lo = Vector2i(mini(lo.x, kw.x), mini(lo.y, kw.z))
		hi = Vector2i(maxi(hi.x, kw.x + (1 if kw.w == 0 else 0)), maxi(hi.y, kw.z + (1 if kw.w == 1 else 0)))
		any = true
	for k in p.stairs:
		for c in stair_cells(k, int(p.stairs[k].r)):
			var cc: Vector2i = c
			lo = Vector2i(mini(lo.x, cc.x), mini(lo.y, cc.y))
			hi = Vector2i(maxi(hi.x, cc.x + 1), maxi(hi.y, cc.y + 1))
			any = true
	_bbox[id] = Rect2i(lo, hi - lo) if any else Rect2i()


func _rebuild_cells() -> void:
	cells.clear()
	for id in plans:
		var p: Dictionary = plans[id]
		for k in p.floors:
			cells[Vector2i(k.x, k.z)] = id
		for k in p.walls:
			var kw: Vector4i = k
			cells[Vector2i(kw.x, kw.z)] = id
			cells[Vector2i(kw.x, kw.z) - (Vector2i(0, 1) if kw.w == 0 else Vector2i(1, 0))] = id


## Le plan n'a plus rien : on l'oublie.
func _drop_if_empty(id: String) -> void:
	var p: Dictionary = plans[id]
	if p.walls.is_empty() and p.floors.is_empty() and p.stairs.is_empty():
		_restore_terrain(id)
		plans.erase(id)
		_bbox.erase(id)
		if _nodes.has(id):
			for n in (_nodes[id] as Dictionary).values():
				(n as Node).queue_free()
			_nodes.erase(id)
		_dirty.erase(id)
		if _active == id:
			_active = ""


# --- Éléments -----------------------------------------------------------------------

static func wall_cells(k: Vector4i) -> Array:
	# Les deux cases de part et d'autre du mur.
	if k.w == 0:
		return [Vector2i(k.x, k.z - 1), Vector2i(k.x, k.z)]
	return [Vector2i(k.x - 1, k.z), Vector2i(k.x, k.z)]


static func stair_cells(k: Vector3i, r: int) -> Array:
	var out := []
	var d: Vector2i = STAIR_DIRS[r % 4]
	for i in STAIR_LEN:
		out.append(Vector2i(k.x, k.z) + d * i)
	return out


## Murs d'une ligne entre deux sommets (alignée sur x ou sur z).
static func wall_line(a: Vector2i, b: Vector2i, e: int) -> Array:
	var out := []
	if absi(b.x - a.x) >= absi(b.y - a.y):
		for x in range(mini(a.x, b.x), maxi(a.x, b.x)):
			out.append(Vector4i(x, e, a.y, 0))
	else:
		for z in range(mini(a.y, b.y), maxi(a.y, b.y)):
			out.append(Vector4i(a.x, e, z, 1))
	return out


## Murs du contour d'un rectangle de cases (coins inclus).
static func room_walls(r: Rect2i, e: int) -> Array:
	var out := []
	for x in range(r.position.x, r.end.x):
		out.append(Vector4i(x, e, r.position.y, 0))
		out.append(Vector4i(x, e, r.end.y, 0))
	for z in range(r.position.y, r.end.y):
		out.append(Vector4i(r.position.x, e, z, 1))
		out.append(Vector4i(r.end.x, e, z, 1))
	return out


## Raison pour laquelle la case est interdite ("" si possible).
func check_cell(c: Vector2i, id: String) -> String:
	if buildings != null:
		if buildings.occupancy.has(c):
			return "Un bâtiment occupe cette case."
		if buildings.transport != null and buildings.transport.is_cell_occupied(c):
			return "Une voie passe ici."
	if cells.has(c) and cells[c] != id:
		return "Un autre bâtiment est déjà ici."
	if world != null and is_nan(world.cell_height(c)):
		return "Relief encore en chargement."
	return ""


func _wall_code() -> int:
	return BlocFormes.encode(material, 0, 0, tint)


## Matériau des cadres et battants : celui choisi s'il s'y prête (bois, métal).
func _opening_material(kind: String) -> int:
	var m: Dictionary = BlocMateriaux.LIST[material]
	if (m.fam == "bois" or m.fam == "metal_verre") and not m.get("glass", false):
		return BlocFormes.encode(material, 0, 0, tint)
	if OPENINGS[kind].get("leaf", false) and not OPENINGS[kind].get("full", false):
		return BlocFormes.encode(DOOR_MAT, 0, 0, tint)
	return BlocFormes.encode(FRAME_MAT, 0, 0, 0)


func _snapshot(id: String) -> Variant:
	return (plans[id] as Dictionary).duplicate(true) if plans.has(id) else null


func _push_undo(id: String, before: Variant, cost: int) -> void:
	_undo.append({"id": id, "before": before, "cost": cost})
	if _undo.size() > 100:
		_undo.pop_front()


func _after_change(id: String, all_levels := true) -> void:
	if plans.has(id):
		_update_bbox(id)
		_sync_terrain(id)
		_drop_if_empty(id)
	_rebuild_cells()
	if plans.has(id):
		var d: Dictionary = _dirty.get(id, {})
		if all_levels:
			for e in levels_of(id):
				d[e] = true
		# Les étages déjà affichés aussi (un étage vidé doit disparaître).
		if _nodes.has(id):
			for e in _nodes[id]:
				d[e] = true
		_dirty[id] = d
	_apply_cutaway()
	_emit_level()
	changed.emit()


## Pose des murs (une seule étape d'annulation). Renvoie le nombre posé.
func add_walls(id: String, keys: Array, code := -1) -> int:
	if code < 0:
		code = _wall_code()
	var todo := []
	var reason := ""
	for k in keys:
		var kw: Vector4i = k
		if id != "" and plans.has(id) and plans[id].walls.has(kw):
			continue
		var r := ""
		for c in wall_cells(kw):
			r = check_cell(c, id)
			if r == "":
				break
		if r != "":
			if reason == "":
				reason = r
			continue
		todo.append(kw)
		if todo.size() >= MAX_OP:
			break
	if todo.is_empty():
		if reason != "":
			message.emit(reason)
		return 0
	var cost := todo.size() * wall_price(BlocFormes.mat_of(code))
	if not _can_pay(cost):
		message.emit("Pas assez d'argent : %s nécessaires." % BuildingSystem.format_money(ReglagesPartie.prix(cost)))
		return 0
	var before: Variant = _snapshot(id)
	if id == "" or not plans.has(id):
		push_error("add_walls : plan inconnu")
		return 0
	for kw in todo:
		plans[id].walls[kw] = {"a": code, "b": code, "o": "", "om": 0, "op": false}
	_pay(cost)
	_push_undo(id, before, cost)
	_after_change(id)
	return todo.size()


## Pose des planchers sur les cases d'un rectangle (étage e).
func add_floors(id: String, rect: Rect2i, e: int, code := -1, replace := false) -> int:
	if code < 0:
		code = BlocFormes.encode(material, 0, 0, tint)
	var p: Dictionary = plans[id]
	var todo := []
	var reason := ""
	for x in range(rect.position.x, rect.end.x):
		for z in range(rect.position.y, rect.end.y):
			var k := Vector3i(x, e, z)
			if p.floors.has(k) and not replace:
				continue
			var r := check_cell(Vector2i(x, z), id)
			if r != "":
				if reason == "":
					reason = r
				continue
			todo.append(k)
	if todo.size() > MAX_OP:
		todo.resize(MAX_OP)
	if todo.is_empty():
		if reason != "":
			message.emit(reason)
		return 0
	var cost := todo.size() * floor_price(BlocFormes.mat_of(code))
	if not _can_pay(cost):
		message.emit("Pas assez d'argent : %s nécessaires." % BuildingSystem.format_money(ReglagesPartie.prix(cost)))
		return 0
	var before: Variant = _snapshot(id)
	for k in todo:
		var old: Dictionary = p.floors.get(k, {})
		p.floors[k] = {"t": code, "u": int(old.get("u", BlocFormes.encode(CEILING_MAT)))}
	_pay(cost)
	_push_undo(id, before, cost)
	_after_change(id)
	return todo.size()


## Pièce : le contour en murs et le plancher (une seule étape d'annulation),
## sur n étages à partir de e.
func add_room(id: String, rect: Rect2i, e: int, n := 1) -> bool:
	var p: Dictionary = plans[id]
	var wcode := _wall_code()
	var walls := []
	var floors := []
	var fcodes := {}
	for ee in range(e, mini(e + maxi(n, 1), MAX_LEVEL + 1)):
		fcodes[ee] = BlocFormes.encode(BASEMENT_MAT if ee < 0 else FLOOR_MAT)
		for k in room_walls(rect, ee):
			if not p.walls.has(k):
				walls.append(k)
		for x in range(rect.position.x, rect.end.x):
			for z in range(rect.position.y, rect.end.y):
				var k := Vector3i(x, ee, z)
				if not p.floors.has(k):
					floors.append(k)
	var fcode := BlocFormes.encode(BASEMENT_MAT if e < 0 else FLOOR_MAT)
	for x in range(rect.position.x - 1, rect.end.x + 1):
		for z in range(rect.position.y - 1, rect.end.y + 1):
			var inside := rect.has_point(Vector2i(x, z))
			var r := check_cell(Vector2i(x, z), id)
			if inside and r != "":
				message.emit(r)
				return false
	if walls.size() + floors.size() > MAX_OP:
		message.emit("Pièce trop grande.")
		return false
	var cost := walls.size() * wall_price(material) + floors.size() * floor_price(BlocFormes.mat_of(fcode))
	if not _can_pay(cost):
		message.emit("Pas assez d'argent : %s nécessaires." % BuildingSystem.format_money(ReglagesPartie.prix(cost)))
		return false
	var before: Variant = _snapshot(id)
	for k in walls:
		p.walls[k] = {"a": wcode, "b": wcode, "o": "", "om": 0, "op": false}
	for k in floors:
		p.floors[k] = {"t": int(fcodes.get((k as Vector3i).y, fcode)), "u": BlocFormes.encode(CEILING_MAT)}
	_pay(cost)
	_push_undo(id, before, cost)
	_after_change(id)
	return true


## Met une ouverture dans un mur (le crée s'il n'existe pas).
func set_opening_at(id: String, k: Vector4i, kind: String) -> bool:
	var p: Dictionary = plans[id]
	var cost := int(OPENINGS[kind].price)
	if not p.walls.has(k):
		for c in wall_cells(k):
			var r := check_cell(c, id)
			if r != "":
				message.emit(r)
				return false
		cost += wall_price(material)
	elif String(p.walls[k].o) == kind:
		return false
	if not _can_pay(cost):
		message.emit("Pas assez d'argent : %s nécessaires." % BuildingSystem.format_money(ReglagesPartie.prix(cost)))
		return false
	var before: Variant = _snapshot(id)
	if not p.walls.has(k):
		p.walls[k] = {"a": _wall_code(), "b": _wall_code(), "o": "", "om": 0, "op": false}
	p.walls[k].o = kind
	p.walls[k].om = _opening_material(kind)
	p.walls[k].op = false
	_pay(cost)
	_push_undo(id, before, cost)
	_after_change(id, false)
	_mark(id, k.y)
	return true


## Peint un côté de mur ("a" ou "b").
func paint_wall(id: String, k: Vector4i, side: String) -> bool:
	var p: Dictionary = plans[id]
	if not p.walls.has(k):
		return false
	var code := _wall_code()
	if int(p.walls[k][side]) == code:
		return false
	var cost := maxi(1, wall_price(material) / 3)
	if not _can_pay(cost):
		return false
	var before: Variant = _snapshot(id)
	p.walls[k][side] = code
	_pay(cost)
	_push_undo(id, before, cost)
	_after_change(id, false)
	_mark(id, k.y)
	return true


## Peint une pièce : les sols du rectangle et les côtés de murs tournés vers lui.
func paint_rect(id: String, rect: Rect2i, e: int) -> int:
	var p: Dictionary = plans[id]
	var code := _wall_code()
	var n := 0
	var before: Variant = _snapshot(id)
	# Un matériau de sol peint les sols ; les autres peignent les murs.
	var fam := String(BlocMateriaux.LIST[material].fam)
	if fam != "sols":
		for k in p.walls:
			var kw: Vector4i = k
			if kw.y != e:
				continue
			var cs := wall_cells(kw)
			if rect.has_point(cs[0]) and int(p.walls[kw].a) != code:
				p.walls[kw].a = code
				n += 1
			if rect.has_point(cs[1]) and int(p.walls[kw].b) != code:
				p.walls[kw].b = code
				n += 1
	if fam == "sols" or n == 0:
		for x in range(rect.position.x, rect.end.x):
			for z in range(rect.position.y, rect.end.y):
				var fk := Vector3i(x, e, z)
				if p.floors.has(fk) and int(p.floors[fk].t) != code:
					p.floors[fk].t = code
					n += 1
	if n == 0:
		return 0
	var cost := n * maxi(1, wall_price(material) / 3)
	_pay(cost)
	_push_undo(id, before, cost)
	_after_change(id, false)
	_mark(id, e)
	return n


func paint_floor(id: String, k: Vector3i) -> bool:
	var p: Dictionary = plans[id]
	if not p.floors.has(k):
		return false
	var code := _wall_code()
	if int(p.floors[k].t) == code:
		return false
	var before: Variant = _snapshot(id)
	p.floors[k].t = code
	var cost := maxi(1, floor_price(material) / 2)
	_pay(cost)
	_push_undo(id, before, cost)
	_after_change(id, false)
	_mark(id, k.y)
	return true


## Escalier de l'étage e vers e + 1, sur 4 cases à partir de c.
func add_stairs(id: String, c: Vector2i, e: int, r: int) -> bool:
	var p: Dictionary = plans[id]
	var k := Vector3i(c.x, e, c.y)
	var mine := stair_cells(k, r)
	for sk in p.stairs:
		if (sk as Vector3i).y != e:
			continue
		for oc in stair_cells(sk, int(p.stairs[sk].r)):
			if oc in mine:
				message.emit("Il y a déjà un escalier ici.")
				return false
	for sc in mine:
		var reason := check_cell(sc, id)
		if reason != "":
			message.emit(reason)
			return false
	var cost := STAIR_PRICE
	if not _can_pay(cost):
		message.emit("Pas assez d'argent : %s nécessaires." % BuildingSystem.format_money(ReglagesPartie.prix(cost)))
		return false
	var before: Variant = _snapshot(id)
	var m := material if BlocMateriaux.LIST[material].fam != "nature" else 2
	p.stairs[k] = {"r": r, "m": BlocFormes.encode(m, 0, 0, tint)}
	# Un palier en bas s'il n'y a pas de sol.
	for sc in mine:
		var fk := Vector3i(sc.x, e, sc.y)
		if not p.floors.has(fk):
			p.floors[fk] = {"t": BlocFormes.encode(BASEMENT_MAT if e < 0 else FLOOR_MAT), "u": BlocFormes.encode(CEILING_MAT)}
	_pay(cost)
	_push_undo(id, before, cost)
	_after_change(id)
	return true


## Retire ce qui se trouve au point visé : ouverture (outil Ouverture), mur, escalier ou sol.
func erase_at(id: String, hit: Dictionary, only_opening := false) -> bool:
	var p: Dictionary = plans[id]
	var e: int = hit.e
	var before: Variant = _snapshot(id)
	var back := 0
	if hit.get("edge") != null and p.walls.has(hit.edge):
		var w: Dictionary = p.walls[hit.edge]
		if String(w.o) != "":
			back += roundi(int(OPENINGS[w.o].price) * REFUND)
			if only_opening:
				w.o = ""
				_pay(-back)
				_push_undo(id, before, -back)
				_after_change(id, false)
				_mark(id, e)
				return true
		if only_opening:
			return false
		back += roundi(wall_price(BlocFormes.mat_of(int(w.a))) * REFUND)
		p.walls.erase(hit.edge)
	elif only_opening:
		return false
	else:
		var c: Vector2i = hit.cell
		var sk: Variant = stair_at(id, c, e)
		if sk != null:
			p.stairs.erase(sk)
			back += roundi(STAIR_PRICE * REFUND)
		else:
			var fk := Vector3i(c.x, e, c.y)
			if not p.floors.has(fk):
				return false
			back += roundi(floor_price(BlocFormes.mat_of(int(p.floors[fk].t))) * REFUND)
			p.floors.erase(fk)
	_pay(-back)
	_push_undo(id, before, -back)
	_after_change(id)
	return true


## Efface tout un rectangle de l'étage e (murs dedans et sur le contour).
func erase_rect(id: String, rect: Rect2i, e: int) -> int:
	var p: Dictionary = plans[id]
	var before: Variant = _snapshot(id)
	var back := 0
	var n := 0
	for k in p.walls.keys():
		var kw: Vector4i = k
		if kw.y != e:
			continue
		var inside := false
		if kw.w == 0:
			inside = kw.x >= rect.position.x and kw.x < rect.end.x and kw.z >= rect.position.y and kw.z <= rect.end.y
		else:
			inside = kw.z >= rect.position.y and kw.z < rect.end.y and kw.x >= rect.position.x and kw.x <= rect.end.x
		if inside:
			back += roundi(wall_price(BlocFormes.mat_of(int(p.walls[kw].a))) * REFUND)
			p.walls.erase(kw)
			n += 1
	for k in p.floors.keys():
		var kf: Vector3i = k
		if kf.y == e and rect.has_point(Vector2i(kf.x, kf.z)):
			back += roundi(floor_price(BlocFormes.mat_of(int(p.floors[kf].t))) * REFUND)
			p.floors.erase(kf)
			n += 1
	for k in p.stairs.keys():
		var ks: Vector3i = k
		if ks.y == e and rect.has_point(Vector2i(ks.x, ks.z)):
			back += roundi(STAIR_PRICE * REFUND)
			p.stairs.erase(ks)
			n += 1
	if n == 0:
		return 0
	_pay(-back)
	_push_undo(id, before, -back)
	_after_change(id)
	return n


func stair_at(id: String, c: Vector2i, e: int) -> Variant:
	var p: Dictionary = plans[id]
	for sk in p.stairs:
		if (sk as Vector3i).y == e and c in stair_cells(sk, int(p.stairs[sk].r)):
			return sk
	return null


## Recopie l'étage e à l'étage du dessus (là où c'est libre), n fois.
func copy_level_up(id: String, e: int, n := 1) -> int:
	var p: Dictionary = plans[id]
	var walls := []
	var floors := []
	var stairs := []
	for k in p.walls:
		if (k as Vector4i).y == e:
			walls.append(k)
	for k in p.floors:
		if (k as Vector3i).y == e:
			floors.append(k)
	for k in p.stairs:
		if (k as Vector3i).y == e:
			stairs.append(k)
	if walls.is_empty() and floors.is_empty():
		message.emit("Rien à recopier à cet étage.")
		return 0
	n = clampi(n, 1, MAX_LEVEL - e)
	var cost := 0
	var add_w := {}
	var add_f := {}
	var add_s := {}
	for i in range(1, n + 1):
		for k in walls:
			var kw: Vector4i = k
			var nk := Vector4i(kw.x, e + i, kw.z, kw.w)
			if not p.walls.has(nk):
				var w: Dictionary = p.walls[kw]
				var nw: Dictionary = w.duplicate()
				# Pas de porte d'entrée en étage : une porte extérieure devient une porte-fenêtre ?
				# On garde l'ouverture telle quelle, le joueur la change s'il le veut.
				nw.op = false
				add_w[nk] = nw
				cost += wall_price(BlocFormes.mat_of(int(w.a)))
				if String(w.o) != "":
					cost += int(OPENINGS[w.o].price)
		for k in floors:
			var kf: Vector3i = k
			var nk2 := Vector3i(kf.x, e + i, kf.z)
			if not p.floors.has(nk2):
				var f: Dictionary = p.floors[kf]
				# Le sol d'un sous-sol (béton) devient du parquet à l'étage.
				var t := int(f.t)
				if e < 0 and e + i >= 0 and BlocFormes.mat_of(t) == BASEMENT_MAT:
					t = BlocFormes.encode(FLOOR_MAT)
				add_f[nk2] = {"t": t, "u": int(f.u)}
				cost += floor_price(BlocFormes.mat_of(t))
		for k in stairs:
			var ks: Vector3i = k
			var nk3 := Vector3i(ks.x, e + i, ks.z)
			if not p.stairs.has(nk3):
				add_s[nk3] = (p.stairs[ks] as Dictionary).duplicate()
				cost += STAIR_PRICE
	if add_w.is_empty() and add_f.is_empty():
		message.emit("L'étage du dessus est déjà construit.")
		return 0
	if not _can_pay(cost):
		message.emit("Pas assez d'argent : %s nécessaires." % BuildingSystem.format_money(ReglagesPartie.prix(cost)))
		return 0
	var before: Variant = _snapshot(id)
	for k in add_w:
		p.walls[k] = add_w[k]
	for k in add_f:
		p.floors[k] = add_f[k]
	for k in add_s:
		p.stairs[k] = add_s[k]
	_pay(cost)
	_push_undo(id, before, cost)
	_after_change(id)
	return n


## Ouvre ou ferme la porte du mur k.
func toggle_door(id: String, k: Vector4i) -> bool:
	var p: Dictionary = plans.get(id, {})
	if p.is_empty() or not p.walls.has(k):
		return false
	var w: Dictionary = p.walls[k]
	if String(w.o) == "" or not OPENINGS[w.o].get("leaf", false):
		return false
	w.op = not bool(w.op)
	_mark(id, k.y)
	changed.emit()
	return true


## Vue au sol : ouvre la porte visée à moins de max_dist mètres.
func interact_ray(origin: Vector3, dir: Vector3, max_dist := 3.0) -> bool:
	dir = dir.normalized()
	var t := 0.0
	while t <= max_dist:
		var pt := origin + dir * t
		var c := Vector2i(floori(pt.x), floori(pt.z))
		var id := plan_at(c, 1)
		if id != "":
			var e := floori((pt.y - float(plans[id].y0)) / H)
			var y := pt.y - base_y(id, e)
			if y >= 0.0 and y <= 2.3:
				var fx := pt.x - roundf(pt.x)
				var fz := pt.z - roundf(pt.z)
				var k: Variant = null
				if absf(fz) < 0.35:
					k = Vector4i(floori(pt.x), e, roundi(pt.z), 0)
				if (k == null or not plans[id].walls.has(k)) and absf(fx) < 0.35:
					k = Vector4i(roundi(pt.x), e, floori(pt.z), 1)
				if k != null and toggle_door(id, k):
					var w: Dictionary = plans[id].walls[k]
					message.emit("%s %s." % [OPENINGS[w.o].name, "ouverte" if w.op else "fermée"])
					return true
		t += 0.1
	return false


func undo() -> bool:
	if _undo.is_empty():
		return false
	var op: Dictionary = _undo.pop_back()
	var id: String = op.id
	if plans.has(id):
		_restore_terrain(id)
	if op.before == null:
		if plans.has(id):
			plans[id].walls.clear()
			plans[id].floors.clear()
			plans[id].stairs.clear()
			plans[id].dug.clear()
	else:
		plans[id] = (op.before as Dictionary).duplicate(true)
		# Le terrain est recreusé d'après les sols (_sync_terrain).
		plans[id].dug = {}
		if not _bbox.has(id):
			_bbox[id] = Rect2i()
	_pay(-int(op.cost))
	_after_change(id)
	return true


func summary() -> String:
	if plans.is_empty():
		return "Aucun bâtiment en murs fins."
	var w := 0
	var f := 0
	for p in plans.values():
		w += (p.walls as Dictionary).size()
		f += (p.floors as Dictionary).size()
	return "%d bâtiment%s · %d m de murs · %d m² de planchers" % [plans.size(), "s" if plans.size() > 1 else "", w, f]


# --- Terrain ------------------------------------------------------------------------

## Creuse le terrain sous les planchers du rez-de-chaussée et des sous-sols,
## et le rend tel qu'il était là où il n'y a plus rien.
func _sync_terrain(id: String) -> void:
	if world == null or not plans.has(id):
		return
	var p: Dictionary = plans[id]
	var need := {}
	for k in p.floors:
		var kf: Vector3i = k
		if kf.y <= 0:
			var c := Vector2i(kf.x, kf.z)
			need[c] = minf(float(need.get(c, INF)), base_y(id, kf.y) - SLAB)
	var touched := []
	for c in p.dug.keys():
		if not need.has(c):
			_restore_cell(c, p.dug[c])
			p.dug.erase(c)
			touched.append(c)
	for c in need:
		if not p.dug.has(c):
			var h0 := world.cell_height(c)
			if is_nan(h0):
				continue
			p.dug[c] = [float(world.modifications.get(c, NO_PREV)), h0]
		var rec: Array = p.dug[c]
		var target := minf(float(rec[1]), float(need[c]))
		if not world.modifications.has(c) or absf(float(world.modifications[c]) - target) > 0.001:
			world.modifications[c] = target
			touched.append(c)
	if not touched.is_empty():
		world.mark_cells_dirty(touched)


func _restore_cell(c: Vector2i, rec: Array) -> void:
	if float(rec[0]) == NO_PREV:
		world.modifications.erase(c)
	else:
		world.modifications[c] = float(rec[0])


func _restore_terrain(id: String) -> void:
	if world == null or not plans.has(id):
		return
	var p: Dictionary = plans[id]
	var touched := []
	for c in p.dug:
		_restore_cell(c, p.dug[c])
		touched.append(c)
	p.dug.clear()
	if not touched.is_empty():
		world.mark_cells_dirty(touched)


# --- Visée --------------------------------------------------------------------------

## Bâtiment visé en dernier ("" s'il n'y en a pas).
func active_id() -> String:
	return _active if plans.has(_active) else ""


func _eff_level() -> int:
	return level if _active != "" else 0


## Point visé à l'étage actif : {id, e, p (Vector3), cell, vertex, edge, side}.
func pick(origin: Vector3, dir: Vector3) -> Dictionary:
	var ground: Variant = world.pick_point(origin, dir) if world != null else null
	var id := ""
	# Bâtiment visé à l'étage actif : on coupe le rayon à la hauteur de cet
	# étage pour chaque bâtiment (le sol sous le curseur est loin quand on
	# construit en hauteur).
	if _active != "" and plans.has(_active):
		var pa: Variant = _plane_hit(origin, dir, base_y(_active, level))
		if pa != null and (_bbox[_active] as Rect2i).grow(8).has_point(Vector2i(floori(pa.x), floori(pa.z))):
			id = _active
	if id == "" and level != 0:
		var bd := INF
		for pid in plans:
			var ph: Variant = _plane_hit(origin, dir, base_y(pid, level))
			if ph == null:
				continue
			var r: Rect2i = _bbox[pid]
			if r.grow(4).has_point(Vector2i(floori(ph.x), floori(ph.z))):
				var d := (origin as Vector3).distance_to(ph)
				if d < bd:
					bd = d
					id = pid
		if id != "" and _active != id:
			_active = id
			_apply_cutaway()
			_emit_level()
	if id == "" and ground != null:
		var gp: Vector3 = ground
		id = plan_at(Vector2i(floori(gp.x), floori(gp.z)), 3)
		if id != "" and _active != id:
			_active = id
			_apply_cutaway()
			_emit_level()
	if id == "" and _active != "":
		_active = ""
		_apply_cutaway()
		_emit_level()
	var pt: Variant
	var e := 0
	if id != "":
		e = level
		pt = _plane_hit(origin, dir, base_y(id, level))
	else:
		pt = ground
		if pt != null:
			var g := ground_level(Vector2i(floori((pt as Vector3).x), floori((pt as Vector3).z)))
			var on_plane: Variant = _plane_hit(origin, dir, g)
			if on_plane != null:
				pt = on_plane
	if pt == null:
		return {}
	var p: Vector3 = pt
	var out := {"id": id, "e": e, "p": p, "cell": Vector2i(floori(p.x), floori(p.z)),
		"vertex": Vector2i(roundi(p.x), roundi(p.z))}
	# Mur le plus proche du point.
	var fx := absf(p.x - roundf(p.x))
	var fz := absf(p.z - roundf(p.z))
	if fz <= fx:
		out.edge = Vector4i(floori(p.x), e, roundi(p.z), 0)
		out.side = "a" if p.z < roundf(p.z) else "b"
		out.edge_dist = fz
	else:
		out.edge = Vector4i(roundi(p.x), e, floori(p.z), 1)
		out.side = "a" if p.x < roundf(p.x) else "b"
		out.edge_dist = fx
	return out


static func _plane_hit(origin: Vector3, dir: Vector3, y: float) -> Variant:
	if absf(dir.y) < 1e-5:
		return null
	var t := (y - origin.y) / dir.y
	if t <= 0.0:
		return null
	return origin + dir * t


## Mur visé « franchement » (près de la ligne) : clé ou null.
func _near_wall(h: Dictionary, tol := 0.3) -> Variant:
	if h.is_empty() or h.id == "" or float(h.edge_dist) > tol:
		return null
	return h.edge if plans[h.id].walls.has(h.edge) else null


# --- Souris et clavier ------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if tool == Tool.NONE or camera == null or world == null:
		return
	if event is InputEventMouseMotion:
		_update_hover((event as InputEventMouseMotion).position)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				_right_press = mb.position
			elif mb.position.distance_to(_right_press) < 5.0:
				_update_hover(mb.position)
				if not _hover.is_empty() and _hover.id != "":
					if erase_at(_hover.id, _erase_target(_hover), tool == Tool.OPENING):
						_update_hover(mb.position)
			return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		_update_hover(mb.position)
		get_viewport().set_input_as_handled()
		if mb.pressed:
			if _hover.is_empty():
				return
			_drag = true
			_drag_start = _hover.duplicate()
			if tool == Tool.OPENING or tool == Tool.STAIRS:
				_drag = false
				_click(_hover)
		elif _drag:
			_drag = false
			if not _hover.is_empty():
				_release(_drag_start, _hover)
			_update_hover(mb.position)
	elif event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo:
			return
		if key.keycode == KEY_ESCAPE:
			if _drag:
				_drag = false
				_update_ghost()
			else:
				set_inactive()
			get_viewport().set_input_as_handled()
		elif key.keycode == KEY_PAGEUP:
			step_level(1)
			_update_ghost()
			get_viewport().set_input_as_handled()
		elif key.keycode == KEY_PAGEDOWN:
			step_level(-1)
			_update_ghost()
			get_viewport().set_input_as_handled()
		elif key.physical_keycode == KEY_R and not key.ctrl_pressed:
			rot_offset = (rot_offset + 1) % 4
			_update_ghost()
			get_viewport().set_input_as_handled()
		elif key.keycode == KEY_Z and key.ctrl_pressed:
			if undo():
				message.emit("Annulé.")
			get_viewport().set_input_as_handled()


func _erase_target(h: Dictionary) -> Dictionary:
	var out := h.duplicate()
	if _near_wall(h, 0.3 if tool != Tool.OPENING else 0.5) == null:
		out.edge = null
	return out


## Plan où poser : celui visé, ou un nouveau bâtiment.
func _plan_for(h: Dictionary) -> String:
	if h.id != "":
		return h.id
	var id := new_plan(ground_level(h.cell))
	_active = id
	return id


func _click(h: Dictionary) -> void:
	match tool:
		Tool.OPENING:
			var k: Vector4i = h.edge
			var id := _plan_for(h)
			if not set_opening_at(id, k, opening):
				_drop_if_empty(id)
		Tool.STAIRS:
			var id2 := _plan_for(h)
			if not add_stairs(id2, h.cell, h.e, _stair_rot()):
				_drop_if_empty(id2)


func _release(a: Dictionary, b: Dictionary) -> void:
	var rect := _cell_rect(a.cell, b.cell)
	match tool:
		Tool.WALL:
			var keys := _stack(wall_line(a.vertex, b.vertex, a.e))
			if keys.is_empty():
				return
			var id := _plan_for(a)
			if add_walls(id, keys) == 0:
				_drop_if_empty(id)
		Tool.ROOM:
			var id2 := _plan_for(a)
			if not add_room(id2, rect, a.e, wall_levels):
				_drop_if_empty(id2)
		Tool.FLOOR:
			var id3 := _plan_for(a)
			if add_floors(id3, rect, a.e, -1, true) == 0:
				_drop_if_empty(id3)
		Tool.PAINT:
			if a.id == "":
				return
			if rect.size == Vector2i.ONE:
				var wk: Variant = _near_wall(a, 0.35)
				if wk != null:
					paint_wall(a.id, wk, a.side)
				else:
					paint_floor(a.id, Vector3i(a.cell.x, a.e, a.cell.y))
			else:
				paint_rect(a.id, rect, a.e)
		Tool.ERASE:
			if a.id == "":
				return
			if rect.size == Vector2i.ONE:
				erase_at(a.id, _erase_target(a))
			else:
				erase_rect(a.id, rect, a.e)


## Les mêmes murs sur wall_levels étages, à partir de l'étage des clés.
func _stack(keys: Array) -> Array:
	var out := []
	for i in maxi(wall_levels, 1):
		for k in keys:
			var kw: Vector4i = k
			if kw.y + i <= MAX_LEVEL:
				out.append(Vector4i(kw.x, kw.y + i, kw.z, kw.w))
	return out


static func _cell_rect(a: Vector2i, b: Vector2i) -> Rect2i:
	var lo := Vector2i(mini(a.x, b.x), mini(a.y, b.y))
	return Rect2i(lo, Vector2i(absi(b.x - a.x) + 1, absi(b.y - a.y) + 1))


func _stair_rot() -> int:
	var r := 0
	if camera != null:
		r = BlocFormes.rot_facing(-camera.global_transform.basis.z)
	return (r + rot_offset) % 4


func _update_hover(screen: Vector2) -> void:
	_hover = pick(camera.project_ray_origin(screen), camera.project_ray_normal(screen))
	_update_ghost()


# --- Fantôme ------------------------------------------------------------------------

func _update_ghost() -> void:
	if tool == Tool.NONE or _hover.is_empty():
		_ghost.visible = false
		_grid.visible = false
		return
	var h := _hover
	var by := base_y(h.id, h.e) if h.id != "" else float((h.p as Vector3).y)
	_grid.visible = true
	_grid.global_position = Vector3(roundf(h.p.x), by + 0.03, roundf(h.p.z))
	var boxes: Array = [] # [AABB]
	var bad := false
	var info := ""
	var a: Dictionary = _drag_start if _drag else h
	var rect := _cell_rect(a.cell, h.cell)
	match tool:
		Tool.WALL:
			var keys := wall_line(a.vertex, h.vertex, a.e) if _drag else []
			if keys.is_empty():
				var v: Vector2i = h.vertex
				boxes.append(AABB(Vector3(v.x - 0.15, by, v.y - 0.15), Vector3(0.3, H - SLAB, 0.3)))
			for k in keys:
				boxes.append(_wall_aabb(k, by, wall_levels))
			if _drag:
				info = "Mur de %d m%s · %s" % [keys.size(), _levels_txt(), BuildingSystem.format_money(ReglagesPartie.prix(keys.size() * wall_levels * wall_price(material)))]
		Tool.ROOM:
			for k in room_walls(rect, a.e):
				boxes.append(_wall_aabb(k, by, wall_levels))
			boxes.append(AABB(Vector3(rect.position.x, by - SLAB, rect.position.y), Vector3(rect.size.x, SLAB, rect.size.y)))
			info = "Pièce de %d × %d m (%d m²)%s" % [rect.size.x, rect.size.y, rect.size.x * rect.size.y, _levels_txt()]
		Tool.FLOOR, Tool.PAINT, Tool.ERASE:
			var wk: Variant = _near_wall(h, 0.35) if not _drag and tool != Tool.FLOOR else null
			if wk != null:
				boxes.append(_wall_aabb(wk, by).grow(0.03))
			else:
				boxes.append(AABB(Vector3(rect.position.x, by - SLAB, rect.position.y), Vector3(rect.size.x, SLAB + 0.05, rect.size.y)))
			bad = tool == Tool.ERASE
			if _drag:
				info = "%d × %d m" % [rect.size.x, rect.size.y]
		Tool.OPENING:
			var o: Dictionary = OPENINGS[opening]
			var bx := _wall_aabb(h.edge, by)
			bx.position.y = by + float(o.s)
			bx.size.y = float(o.t) - float(o.s)
			boxes.append(bx.grow(0.04))
		Tool.STAIRS:
			var r := _stair_rot()
			for i in STAIR_LEN:
				var c: Vector2i = h.cell + STAIR_DIRS[r] * i
				var hh := (i + 1) * H / STAIR_LEN
				boxes.append(AABB(Vector3(c.x + 0.05, by, c.y + 0.05), Vector3(0.9, hh, 0.9)))
	if boxes.is_empty():
		_ghost.visible = false
		return
	_ghost.mesh = _boxes_mesh(boxes)
	_ghost.material_override = _ghost_bad if bad else _ghost_ok
	_ghost.visible = true
	if info != "":
		info_changed.emit(info)


func _wall_aabb(k: Vector4i, by: float, n := 1) -> AABB:
	var hh := H * n - SLAB
	if k.w == 0:
		return AABB(Vector3(k.x, by, k.z - HALF), Vector3(1, hh, 2 * HALF))
	return AABB(Vector3(k.x - HALF, by, k.z), Vector3(2 * HALF, hh, 1))


func _levels_txt() -> String:
	return "" if wall_levels <= 1 else " sur %d étages" % wall_levels


func set_wall_levels(n: int) -> void:
	wall_levels = clampi(n, 1, MAX_LEVEL + 1)
	_update_ghost()


static func _boxes_mesh(boxes: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for b in boxes:
		var bb: AABB = b
		var lo := bb.position
		var hi := bb.end
		var c := [Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, lo.y, hi.z), Vector3(lo.x, lo.y, hi.z),
			Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z)]
		for f in [[0, 1, 2, 3], [7, 6, 5, 4], [0, 4, 5, 1], [1, 5, 6, 2], [2, 6, 7, 3], [3, 7, 4, 0]]:
			st.add_vertex(c[f[0]])
			st.add_vertex(c[f[1]])
			st.add_vertex(c[f[2]])
			st.add_vertex(c[f[0]])
			st.add_vertex(c[f[2]])
			st.add_vertex(c[f[3]])
	return st.commit()


# --- Vue en coupe -------------------------------------------------------------------

## Vue par étage (mode Gérer, VueEtages) : les bâtiments en murs fins de
## vue_plans ne montrent que leurs étages jusqu'à vue_etage (−1 : tout).
var vue_etage := -1
var vue_plans: Array = []


func set_vue_etage(e: int, ids: Array) -> void:
	vue_etage = e
	vue_plans = ids.duplicate() if e >= 0 else []
	_apply_cutaway()


## Bâtiments en murs fins dont le centre est à moins de r mètres de c.
func plans_near(c: Vector2, r: float) -> Array:
	var out := []
	for id in _bbox:
		var bb: Rect2i = _bbox[id]
		if bb.size == Vector2i.ZERO:
			continue
		var m := Vector2(bb.position) + Vector2(bb.size) / 2.0
		if m.distance_to(c) <= r + Vector2(bb.size).length() / 2.0:
			out.append(id)
	return out


func _apply_cutaway() -> void:
	var cut := cutaway and (tool != Tool.NONE or cut_override) and _active != "" and plans.has(_active)
	var vue := vue_etage >= 0 and not cut
	for id in _nodes:
		var vu: bool = vue and id in vue_plans
		for e in _nodes[id]:
			var n: Node3D = _nodes[id][e]
			n.visible = not (cut and id == _active and int(e) > level) and not (vu and int(e) > vue_etage)
	if blocks != null:
		var list := []
		if vue:
			# Toit coupé à 1,2 m au-dessus du plancher de l'étage montré (ou du
			# dernier étage des bâtiments plus bas) : on voit dans les combles.
			for id in vue_plans:
				if plans.has(id) and _bbox.has(id):
					var lv := levels_of(id)
					var ep := mini(vue_etage, int(lv.max()) if not lv.is_empty() else 0)
					list.append([(_bbox[id] as Rect2i).grow(2), base_y(id, ep) + 1.2])
		blocks.set_clips(list)
	if blocks != null:
		if cut:
			blocks.set_clip((_bbox[_active] as Rect2i).grow(2), base_y(_active, level + 1) - SLAB)
		else:
			blocks.set_clip(Rect2i(), INF)


# --- Affichage ----------------------------------------------------------------------

func _mark(id: String, e: int) -> void:
	var d: Dictionary = _dirty.get(id, {})
	for x in [e - 1, e, e + 1]:
		d[x] = true
	_dirty[id] = d


func _process(_delta: float) -> void:
	if _dirty.is_empty():
		return
	for id in _dirty:
		if not plans.has(id):
			continue
		for e in _dirty[id]:
			_build_storey(id, int(e))
	_dirty.clear()
	_apply_cutaway()


## Construit tout de suite ce qui attend (tests, captures).
func flush() -> void:
	_process(0.0)


func _has_floor_render(p: Dictionary, k: Vector3i) -> bool:
	return p.floors.has(k) and not _stair_hole(p, k)


## Case du plancher ouverte au-dessus d'un escalier (trémie).
func _stair_hole(p: Dictionary, k: Vector3i) -> bool:
	for sk in p.stairs:
		var ks: Vector3i = sk
		if ks.y != k.y - 1:
			continue
		var sc := stair_cells(ks, int(p.stairs[sk].r))
		var c := Vector2i(k.x, k.z)
		if c in sc and sc.find(c) >= 1:
			return true
	return false


func _build_storey(id: String, e: int) -> void:
	var p: Dictionary = plans[id]
	var by := base_y(id, e)
	var m := BlocMesher.new()
	var sm := BlocMesher.new()
	var ramps := PackedVector3Array()
	# Planchers.
	for k in p.floors:
		var kf: Vector3i = k
		if kf.y != e or not _has_floor_render(p, kf):
			continue
		var f: Dictionary = p.floors[kf]
		var t := int(f.t)
		var u := int(f.u)
		var mats := [u, u, u, t, u, u]
		var nb := [Vector3i(-1, 0, 0), Vector3i(1, 0, 0), Vector3i.ZERO, Vector3i.ZERO, Vector3i(0, 0, -1), Vector3i(0, 0, 1)]
		for i in [0, 1, 4, 5]:
			if _has_floor_render(p, kf + nb[i]):
				mats[i] = -1
		box(m, Vector3(kf.x, by - SLAB, kf.z), Vector3(kf.x + 1, by, kf.z + 1), mats)
	# Murs et poteaux d'angle.
	var posts := {} # Vector2i -> [bas, haut, code]
	for k in p.walls:
		var kw: Vector4i = k
		if kw.y != e:
			continue
		var w: Dictionary = p.walls[kw]
		var ext := _wall_extent(p, kw, by)
		_emit_wall(m, kw, w, ext.x, ext.y, by)
		var ends := [Vector2i(kw.x, kw.z), Vector2i(kw.x + 1, kw.z) if kw.w == 0 else Vector2i(kw.x, kw.z + 1)]
		for v in ends:
			if posts.has(v):
				var pv: Array = posts[v]
				posts[v] = [minf(pv[0], ext.x), maxf(pv[1], ext.y), pv[2]]
			else:
				posts[v] = [ext.x, ext.y, int(w.a)]
	# Un poteau ne monte pas dans celui de l'étage du dessus.
	var upper := {}
	for k in p.walls:
		var ku: Vector4i = k
		if ku.y == e + 1:
			upper[Vector2i(ku.x, ku.z)] = true
			upper[Vector2i(ku.x + 1, ku.z) if ku.w == 0 else Vector2i(ku.x, ku.z + 1)] = true
	for v in posts:
		var pv2: Array = posts[v]
		var vv: Vector2i = v
		if upper.has(vv):
			pv2[1] = minf(pv2[1], by + H - SLAB)
		var code := int(pv2[2])
		box(m, Vector3(vv.x - HALF, pv2[0], vv.y - HALF), Vector3(vv.x + HALF, pv2[1], vv.y + HALF), [code, code, code, code, code, code])
	# Escaliers.
	for k in p.stairs:
		var ks: Vector3i = k
		if ks.y != e:
			continue
		_emit_stairs(sm, ramps, ks, p.stairs[k], by)
	# Nœuds.
	var nodes: Dictionary = _nodes.get(id, {})
	_nodes[id] = nodes
	var node: Node3D = nodes.get(e)
	if m.is_empty() and sm.is_empty():
		if node:
			node.queue_free()
			nodes.erase(e)
		return
	if node == null:
		node = Node3D.new()
		node.name = "%s_E%d" % [id, e]
		add_child(node)
		nodes[e] = node
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()
	var mesh := m.to_mesh()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	node.add_child(mi)
	var faces := mesh.get_faces() if mesh.get_surface_count() > 0 else PackedVector3Array()
	if not sm.is_empty():
		var smi := MeshInstance3D.new()
		smi.mesh = sm.to_mesh()
		node.add_child(smi)
	faces.append_array(ramps)
	if not faces.is_empty():
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(faces)
		cs.shape = shape
		body.add_child(cs)
		node.add_child(body)


## Bas et haut d'un mur (en mètres) : il couvre la tranche des planchers, et
## descend en fondation sous le rez-de-chaussée.
func _wall_extent(p: Dictionary, k: Vector4i, by: float) -> Vector2:
	var below := Vector4i(k.x, k.y - 1, k.z, k.w)
	var above := Vector4i(k.x, k.y + 1, k.z, k.w)
	var bottom := by - SLAB
	if k.y <= 0 and not p.walls.has(below):
		bottom = by - (FOUNDATION if k.y == 0 else SLAB)
	var top := by + H - SLAB
	var cs := wall_cells(k)
	var floor_above := false
	for c in cs:
		if p.floors.has(Vector3i(c.x, k.y + 1, c.y)):
			floor_above = true
	if not floor_above and not p.walls.has(above):
		top = by + H
	return Vector2(bottom, top)


## Pavé de lo à hi ; mats : codes des faces [−x, +x, −y, +y, −z, +z] (−1 : pas de face).
static func box(m: BlocMesher, lo: Vector3, hi: Vector3, mats: Array) -> void:
	var faces := [
		[[Vector3(lo.x, lo.y, lo.z), Vector3(lo.x, lo.y, hi.z), Vector3(lo.x, hi.y, hi.z), Vector3(lo.x, hi.y, lo.z)], Vector3.LEFT],
		[[Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, hi.y, hi.z), Vector3(hi.x, hi.y, lo.z)], Vector3.RIGHT],
		[[Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, lo.y, hi.z), Vector3(lo.x, lo.y, hi.z)], Vector3.DOWN],
		[[Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z)], Vector3.UP],
		[[Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(lo.x, hi.y, lo.z)], Vector3.FORWARD],
		[[Vector3(lo.x, lo.y, hi.z), Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z)], Vector3.BACK],
	]
	for i in 6:
		var code: int = mats[i]
		if code < 0:
			continue
		var mat := BlocFormes.mat_of(code)
		m.face(faces[i][0], faces[i][1], BlocMateriaux.layer(mat), BlocMateriaux.tint_color(BlocFormes.tint_of(code)), BlocMateriaux.is_glass(mat))


## Pavé dans le repère du mur : u le long du mur (0 → 1), y en mètres, w à
## travers (négatif : côté a). mats : [u−, u+, y−, y+, w−, w+].
static func _wbox(m: BlocMesher, k: Vector4i, u0: float, u1: float, y0: float, y1: float, w0: float, w1: float, mats: Array) -> void:
	if k.w == 0:
		box(m, Vector3(k.x + u0, y0, k.z + w0), Vector3(k.x + u1, y1, k.z + w1), mats)
	else:
		box(m, Vector3(k.x + w0, y0, k.z + u0), Vector3(k.x + w1, y1, k.z + u1), [mats[4], mats[5], mats[2], mats[3], mats[0], mats[1]])


func _emit_wall(m: BlocMesher, k: Vector4i, w: Dictionary, bottom: float, top: float, by: float) -> void:
	var a := int(w.a)
	var b := int(w.b)
	var u0 := HALF
	var u1 := 1.0 - HALF
	var kind := String(w.o)
	if kind == "" or not OPENINGS.has(kind):
		_wbox(m, k, u0, u1, bottom, top, -HALF, HALF, [-1, -1, a, a, a, b])
		return
	var o: Dictionary = OPENINGS[kind]
	var s := by + float(o.s)
	var t := by + float(o.t)
	if s > bottom + 0.001:
		_wbox(m, k, u0, u1, bottom, s, -HALF, HALF, [-1, -1, a, a, a, b])
	_wbox(m, k, u0, u1, t, top, -HALF, HALF, [-1, -1, a, a, a, b])
	var fm := int(w.om)
	var gl := BlocFormes.encode(GLASS_MAT)
	var fr := [fm, fm, fm, fm, fm, fm]
	var g6 := [gl, gl, gl, gl, gl, gl]
	if kind == "passage":
		return
	var jamb := 0.04 if o.get("leaf", false) else (0.03 if o.get("bay", false) else 0.06)
	var fd := 0.05
	# Cadre : montants, traverse haute (et appui pour les fenêtres).
	_wbox(m, k, u0, u0 + jamb, s, t, -fd, fd, fr)
	_wbox(m, k, u1 - jamb, u1, s, t, -fd, fd, fr)
	_wbox(m, k, u0 + jamb, u1 - jamb, t - jamb, t, -fd, fd, fr)
	if not o.get("leaf", false):
		_wbox(m, k, u0 + jamb, u1 - jamb, s, s + jamb, -fd, fd, fr)
		# Appui de fenêtre qui dépasse des deux côtés.
		if o.get("window", false):
			_wbox(m, k, u0 - 0.02, u1 + 0.02, s - 0.04, s, -HALF - 0.04, HALF + 0.04, fr)
		_wbox(m, k, u0 + jamb, u1 - jamb, s + jamb, t - jamb, -0.008, 0.008, g6)
		if o.get("window", false):
			var mid := (u0 + u1) / 2.0
			_wbox(m, k, mid - 0.02, mid + 0.02, s + jamb, t - jamb, -0.025, 0.025, fr)
			var ym := (s + t) / 2.0 + 0.1
			_wbox(m, k, u0 + jamb, u1 - jamb, ym - 0.02, ym + 0.02, -0.025, 0.025, fr)
		return
	# Battant de porte.
	var lu0 := u0 + jamb
	var lu1 := u1 - jamb
	var ly1 := t - jamb
	var lm := fm
	if bool(w.op):
		# Ouvert à 90° côté b, contre le montant de gauche.
		_wbox(m, k, lu0, lu0 + 0.045, s, ly1, 0.03, 0.03 + (lu1 - lu0), [lm, lm, lm, lm, lm, lm])
		return
	if o.get("full", false):
		var r := 0.07
		_wbox(m, k, lu0, lu0 + r, s, ly1, -0.022, 0.022, fr)
		_wbox(m, k, lu1 - r, lu1, s, ly1, -0.022, 0.022, fr)
		_wbox(m, k, lu0 + r, lu1 - r, s, s + 0.15, -0.022, 0.022, fr)
		_wbox(m, k, lu0 + r, lu1 - r, ly1 - r, ly1, -0.022, 0.022, fr)
		_wbox(m, k, lu0 + r, lu1 - r, s + 0.15, ly1 - r, -0.006, 0.006, g6)
	elif o.get("glass", false):
		_wbox(m, k, lu0, lu1, s, s + 1.0, -0.022, 0.022, fr)
		_wbox(m, k, lu0, lu0 + 0.1, s + 1.0, ly1, -0.022, 0.022, fr)
		_wbox(m, k, lu1 - 0.1, lu1, s + 1.0, ly1, -0.022, 0.022, fr)
		_wbox(m, k, lu0 + 0.1, lu1 - 0.1, ly1 - 0.1, ly1, -0.022, 0.022, fr)
		_wbox(m, k, lu0 + 0.1, lu1 - 0.1, s + 1.0, ly1 - 0.1, -0.006, 0.006, g6)
	else:
		_wbox(m, k, lu0, lu1, s, ly1, -0.022, 0.022, fr)
		# Panneaux en relief des deux côtés.
		for side in [-1.0, 1.0]:
			var w0 := 0.022 if side > 0 else -0.032
			var w1 := 0.032 if side > 0 else -0.022
			_wbox(m, k, lu0 + 0.08, lu1 - 0.08, s + 0.15, s + 0.95, w0, w1, fr)
			_wbox(m, k, lu0 + 0.08, lu1 - 0.08, s + 1.1, ly1 - 0.12, w0, w1, fr)
	# Poignées (laiton).
	var brass := BlocFormes.encode(BRASS_MAT)
	_wbox(m, k, lu1 - 0.1, lu1 - 0.05, s + 1.0, s + 1.05, -0.07, 0.07, [brass, brass, brass, brass, brass, brass])


func _emit_stairs(m: BlocMesher, ramps: PackedVector3Array, k: Vector3i, st: Dictionary, by: float) -> void:
	var r := int(st.r) % 4
	var code := int(st.m)
	var mats := [code, code, code, code, code, code]
	var run := float(STAIR_LEN) / STAIR_STEPS
	var rise := H / STAIR_STEPS
	for i in STAIR_STEPS:
		var s0 := i * run
		var s1 := (i + 1) * run
		var y1 := by + (i + 1) * rise
		var lo_hi := _stair_box(k, r, s0, s1, 0.05, 0.95)
		box(m, Vector3(lo_hi[0].x, by, lo_hi[0].y), Vector3(lo_hi[1].x, y1, lo_hi[1].y), mats)
	# Rampe de collision (le personnage monte une pente, pas des marches).
	var a0 := _stair_point(k, r, 0.0, 0.0)
	var a1 := _stair_point(k, r, 0.0, 1.0)
	var b0 := _stair_point(k, r, STAIR_LEN, 0.0)
	var b1 := _stair_point(k, r, STAIR_LEN, 1.0)
	var p0 := Vector3(a0.x, by, a0.y)
	var p1 := Vector3(a1.x, by, a1.y)
	var q0 := Vector3(b0.x, by + H, b0.y)
	var q1 := Vector3(b1.x, by + H, b1.y)
	ramps.append_array([p0, q0, q1, p0, q1, p1])


## Point du repère de l'escalier (s le long de la montée, c à travers) → (x, z).
static func _stair_point(k: Vector3i, r: int, s: float, c: float) -> Vector2:
	match r:
		0:
			return Vector2(k.x + c, k.z + s)
		1:
			return Vector2(k.x + 1 - s, k.z + c)
		2:
			return Vector2(k.x + c, k.z + 1 - s)
		_:
			return Vector2(k.x + s, k.z + c)


static func _stair_box(k: Vector3i, r: int, s0: float, s1: float, c0: float, c1: float) -> Array:
	var a := _stair_point(k, r, s0, c0)
	var b := _stair_point(k, r, s1, c1)
	return [Vector2(minf(a.x, b.x), minf(a.y, b.y)), Vector2(maxf(a.x, b.x), maxf(a.y, b.y))]


# --- Toit automatique ---------------------------------------------------------------

## Toit posé en blocs de l'éditeur sur le dernier étage du bâtiment :
## "deux_pans", "quatre_pans" ou "plat". Renvoie le nombre de blocs posés.
func add_roof(id: String, kind: String, roof_mat := -1) -> int:
	if blocks == null or not plans.has(id):
		return 0
	var p: Dictionary = plans[id]
	var lv := levels_of(id)
	if lv.is_empty():
		return 0
	var etop: int = lv[-1]
	# Emprise du dernier étage : ses sols et l'intérieur de ses murs.
	var lo := Vector2i(1 << 30, 1 << 30)
	var hi := Vector2i(-(1 << 30), -(1 << 30))
	for k in p.floors:
		var kf: Vector3i = k
		if kf.y == etop:
			lo = Vector2i(mini(lo.x, kf.x), mini(lo.y, kf.z))
			hi = Vector2i(maxi(hi.x, kf.x), maxi(hi.y, kf.z))
	for k in p.walls:
		var kw: Vector4i = k
		if kw.y != etop:
			continue
		# Cases que le mur borde (de part et d'autre de sa ligne, bornées ensuite).
		var a := Vector2i(kw.x, kw.z)
		var b := Vector2i(kw.x + 1, kw.z) if kw.w == 0 else Vector2i(kw.x, kw.z + 1)
		lo = Vector2i(mini(lo.x, mini(a.x, b.x)), mini(lo.y, mini(a.y, b.y)))
		hi = Vector2i(maxi(hi.x, maxi(a.x, b.x) - 1), maxi(hi.y, maxi(a.y, b.y) - 1))
	if lo.x > hi.x or lo.y > hi.y:
		message.emit("Le dernier étage est vide : pose d'abord des pièces.")
		return 0
	if roof_mat < 0:
		roof_mat = material if BlocMateriaux.LIST[material].fam == "toits" else 7
	var wall_mat := _main_wall_material(id, etop)
	var y2 := roundi((base_y(id, etop) + H) / BlockEditor.UNIT_Y)
	# Un toit déjà posé sur ce bâtiment est remplacé (on peut changer de forme).
	var old := []
	for k in blocks.blocks:
		var kb: Vector3i = k
		if kb.x >= lo.x - 1 and kb.x <= hi.x + 1 and kb.z >= lo.y - 1 and kb.z <= hi.y + 1 and kb.y >= y2:
			old.append(kb)
	if not old.is_empty():
		blocks.remove_blocks(old)
	# Débord d'une case tout autour, sauf s'il bute (voie trop basse, bâtiment voisin) :
	# le toit est alors posé au ras des murs pour rester fermé.
	var groups := {}
	for over in [1, 0]:
		groups = _roof_groups(kind, lo, hi, over, y2, roof_mat, wall_mat)
		if _roof_fits(groups):
			break
	var placed := 0
	var wanted := 0
	for code in groups:
		wanted += (groups[code] as Array).size()
		placed += blocks.place_blocks(groups[code], code)
	if placed < wanted:
		message.emit("Toit incomplet : %d blocs sur %d (voie, bâtiment ou caisse insuffisante)." % [placed, wanted])
		return placed
	if placed > 0:
		message.emit("Toit posé : %d blocs (Gomme de l'éditeur de blocs pour le retirer)." % placed)
	return placed


func _roof_fits(groups: Dictionary) -> bool:
	for code in groups:
		for key in groups[code]:
			if blocks.check_block(key) != "":
				return false
	return true


## Blocs du toit (code -> [clés]) avec un débord de over cases autour de l'emprise lo..hi.
func _roof_groups(kind: String, lo: Vector2i, hi: Vector2i, over: int, y2: int, roof_mat: int, wall_mat: int) -> Dictionary:
	var hu := BlockEditor.HU
	var x0 := lo.x - over
	var x1 := hi.x + over
	var z0 := lo.y - over
	var z1 := hi.y + over
	var groups := {} # code -> [clés]
	var add := func(key: Vector3i, code: int) -> void:
		if not groups.has(code):
			groups[code] = []
		groups[code].append(key)
	match kind:
		"plat":
			for x in range(lo.x, hi.x + 1):
				for z in range(lo.y, hi.y + 1):
					add.call(Vector3i(x, y2, z), BlocFormes.encode(roof_mat, BlocFormes.S.SLAB))
		"quatre_pans":
			var i := 0
			while x0 + i <= x1 - i and z0 + i <= z1 - i:
				var ax := x0 + i
				var bx := x1 - i
				var az := z0 + i
				var bz := z1 - i
				var y := y2 + i * hu
				if ax == bx or az == bz:
					for x in range(ax, bx + 1):
						for z in range(az, bz + 1):
							add.call(Vector3i(x, y, z), BlocFormes.encode(roof_mat, BlocFormes.S.SLAB))
					break
				for x in range(ax + 1, bx):
					add.call(Vector3i(x, y, az), BlocFormes.encode(roof_mat, BlocFormes.S.SLOPE, 0))
					add.call(Vector3i(x, y, bz), BlocFormes.encode(roof_mat, BlocFormes.S.SLOPE, 2))
				for z in range(az + 1, bz):
					add.call(Vector3i(ax, y, z), BlocFormes.encode(roof_mat, BlocFormes.S.SLOPE, 3))
					add.call(Vector3i(bx, y, z), BlocFormes.encode(roof_mat, BlocFormes.S.SLOPE, 1))
				add.call(Vector3i(ax, y, az), BlocFormes.encode(roof_mat, BlocFormes.S.CORNER_OUT, 0))
				add.call(Vector3i(bx, y, az), BlocFormes.encode(roof_mat, BlocFormes.S.CORNER_OUT, 1))
				add.call(Vector3i(bx, y, bz), BlocFormes.encode(roof_mat, BlocFormes.S.CORNER_OUT, 2))
				add.call(Vector3i(ax, y, bz), BlocFormes.encode(roof_mat, BlocFormes.S.CORNER_OUT, 3))
				i += 1
		_:
			# Deux pans : faîtage dans le sens de la plus grande longueur.
			var along_x := (x1 - x0) >= (z1 - z0)
			var n := (z1 - z0 + 1) if along_x else (x1 - x0 + 1)
			var steep := n <= 9
			for j in n:
				var from_end := mini(j, n - 1 - j)
				var rising := j < n - 1 - j
				var middle := j == n - 1 - j
				var y := y2 + (from_end if steep else from_end / 2) * hu
				var sh: int
				if middle:
					sh = BlocFormes.S.SLAB
				elif steep:
					sh = BlocFormes.S.SLOPE
				else:
					sh = BlocFormes.S.SLOPE_LOW if from_end % 2 == 0 else BlocFormes.S.SLOPE_HIGH
				var r := (0 if rising else 2) if along_x else (3 if rising else 1)
				if middle:
					r = 0
				var span := range(x0, x1 + 1) if along_x else range(z0, z1 + 1)
				for q in span:
					var key := Vector3i(q, y, z0 + j) if along_x else Vector3i(x0 + j, y, q)
					add.call(key, BlocFormes.encode(roof_mat, sh, r))
				# Pignons : remplissage sous la pente, dans le matériau des murs.
				var layers := from_end if steep else from_end / 2
				if j == 0 or j == n - 1:
					continue
				for gq in ([lo.x, hi.x] if along_x else [lo.y, hi.y]):
					for l in layers:
						var gk := Vector3i(gq, y2 + l * hu, z0 + j) if along_x else Vector3i(x0 + j, y2 + l * hu, gq)
						add.call(gk, BlocFormes.encode(wall_mat))
	return groups


func _main_wall_material(id: String, e: int) -> int:
	var count := {}
	for k in plans[id].walls:
		if (k as Vector4i).y == e:
			var m := BlocFormes.mat_of(int(plans[id].walls[k].a))
			count[m] = int(count.get(m, 0)) + 1
	var best := 5
	var bn := 0
	for m in count:
		if count[m] > bn:
			bn = count[m]
			best = m
	return best


# --- Sauvegarde ---------------------------------------------------------------------

func to_dict() -> Dictionary:
	var out := []
	for id in plans:
		var p: Dictionary = plans[id]
		var w := []
		for k in p.walls:
			var kw: Vector4i = k
			var v: Dictionary = p.walls[k]
			w.append_array([kw.x, kw.y, kw.z, kw.w, int(v.a), int(v.b), String(v.o), int(v.om), 1 if v.op else 0])
		var f := []
		for k in p.floors:
			var kf: Vector3i = k
			f.append_array([kf.x, kf.y, kf.z, int(p.floors[k].t), int(p.floors[k].u)])
		var s := []
		for k in p.stairs:
			var ks: Vector3i = k
			s.append_array([ks.x, ks.y, ks.z, int(p.stairs[k].r), int(p.stairs[k].m)])
		var d := []
		for c in p.dug:
			var rec: Array = p.dug[c]
			d.append_array([c.x, c.y, rec[0], rec[1]])
		out.append({"id": id, "y0": p.y0, "walls": w, "floors": f, "stairs": s, "dug": d})
	return {"version": 1, "h": H, "plans": out}


func from_dict(data: Dictionary) -> void:
	clear()
	for pd in data.get("plans", []):
		var id := String(pd.get("id", ""))
		if id == "":
			continue
		plans[id] = {"id": id, "y0": float(pd.get("y0", 0.0)), "walls": {}, "floors": {}, "stairs": {}, "dug": {}}
		_bbox[id] = Rect2i()
		var p: Dictionary = plans[id]
		var w: Array = pd.get("walls", [])
		var i := 0
		while i + 8 < w.size():
			var kind := String(w[i + 6])
			p.walls[Vector4i(int(w[i]), int(w[i + 1]), int(w[i + 2]), int(w[i + 3]) & 1)] = {
				"a": int(w[i + 4]), "b": int(w[i + 5]), "o": kind if OPENINGS.has(kind) else "", "om": int(w[i + 7]), "op": int(w[i + 8]) == 1}
			i += 9
		var f: Array = pd.get("floors", [])
		i = 0
		while i + 4 < f.size():
			p.floors[Vector3i(int(f[i]), int(f[i + 1]), int(f[i + 2]))] = {"t": int(f[i + 3]), "u": int(f[i + 4])}
			i += 5
		var s: Array = pd.get("stairs", [])
		i = 0
		while i + 4 < s.size():
			p.stairs[Vector3i(int(s[i]), int(s[i + 1]), int(s[i + 2]))] = {"r": int(s[i + 3]) % 4, "m": int(s[i + 4])}
			i += 5
		var d: Array = pd.get("dug", [])
		i = 0
		while i + 3 < d.size():
			p.dug[Vector2i(int(d[i]), int(d[i + 1]))] = [float(d[i + 2]), float(d[i + 3])]
			i += 4
		var num := id.trim_prefix("plan_")
		if num.is_valid_int():
			_next_id = maxi(_next_id, int(num) + 1)
		_update_bbox(id)
		var dd: Dictionary = {}
		for e in levels_of(id):
			dd[e] = true
		_dirty[id] = dd
	_rebuild_cells()
	changed.emit()
