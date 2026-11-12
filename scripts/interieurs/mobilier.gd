class_name Mobilier
extends Node3D
## Intérieurs des bâtiments en murs fins : meubles posés case par case, pièces
## et leur fonction, mobilier généré, usage du bâtiment et ses effets.
##
## - Un meuble est posé dans un bâtiment de l'éditeur de murs (PlanEditor), à un
##   étage, sur des cases qui ont un plancher : clé Vector4i(x, étage, z, couche)
##   de sa case d'angle (−x, −z), couche 0 « sol » (tapis), 1 « meuble », 2 « mur ».
## - Les pièces sont trouvées toutes seules : cases d'un étage reliées sans mur
##   entre elles (une porte sépare deux pièces). Chaque pièce a une fonction
##   (séjour, cuisine, chambre, classe…), choisie par le joueur ou devinée.
## - « Meubler » une pièce y pose le mobilier de sa fonction dans le style
##   choisi (la bible Meubles) : le lit contre un mur, la cuisinière à côté de
##   l'évier, les pupitres face au tableau, en laissant les portes libres.
## - L'usage du bâtiment (logement, école, boutique, bureaux, café) et ses
##   meubles donnent ses chiffres : logements, emplois, places d'élèves,
##   confort, valeur (prix de vente) et attractivité. Les habitants y
##   emménagent, y travaillent, y vont à l'école ou y font leurs courses.

signal info_changed(text: String)
signal message(text: String)
signal changed
## Le bâtiment suivi par le panneau a changé (ou ses chiffres).
signal plan_selected(id: String)

enum Tool { NONE, PLACE, ERASE, FURNISH, ROOM_FN, TEMPLATE }

const LAYERS := ["sol", "meuble", "mur"]
const REFUND := 0.5
## Les bâtiments en murs fins vus par les habitants : identifiant = BASE + numéro du plan.
const BID_BASE := 1_000_000
## Recul des meubles posés dos au mur (les murs font 20 cm sur la ligne).
const WALL_GAP := 0.07

const USAGES := {
	"logement": {"name": "Logement", "t": "maison", "cat": "logement", "desc": "Les habitants y vivent : il faut au moins un lit. Chaque étage qui a sa cuisine est un appartement."},
	"ecole": {"name": "École", "t": "ecole", "cat": "services", "desc": "Chaque pupitre est une place d'élève, chaque tableau une classe et son enseignant."},
	"boutique": {"name": "Boutique", "t": "superette", "cat": "commerce", "desc": "Les habitants viennent y faire leurs courses ; comptoirs et rayons font les emplois."},
	"bureaux": {"name": "Bureaux", "t": "bureaux", "cat": "commerce", "desc": "Chaque poste de travail est un emploi."},
	"restaurant": {"name": "Café-restaurant", "t": "cafe", "cat": "loisirs", "desc": "Les habitants y vont entre amis ; le bar et les tables font les emplois."},
}
const USAGE_ORDER := ["logement", "ecole", "boutique", "bureaux", "restaurant"]

## Mobilier de chaque fonction : [types équivalents, placement, nombre, indispensable].
## Placements : "mur" (dos au mur), "centre", "coin", "sol" (tapis), "accroche"
## (couche mur), "remplir_mur", "remplir" (au centre, avec des allées).
const LAYOUTS := {
	"sejour": [[["canape", "banquette", "coussins_sol"], "mur", 1, true], [["meuble_tv", "buffet", "vaisselier"], "mur", 1, false],
		[["table_repas"], "centre", 1, false], [["table_basse"], "centre", 1, false], [["fauteuil"], "centre", 2, false],
		[["cheminee", "poele"], "mur", 1, false], [["bibliotheque"], "mur", 1, false], [["piano"], "mur", 1, false],
		[["tapis"], "sol", 1, false], [["plante", "grande_plante"], "coin", 2, false], [["lampadaire"], "coin", 1, false], [["cadre"], "accroche", 2, false]],
	"cuisine": [[["cuisiniere", "fourneau", "foyer_feu"], "mur", 1, true], [["evier"], "mur", 1, true], [["refrigerateur", "garde_manger"], "mur", 1, true],
		[["plan_travail"], "mur", 2, false], [["lave_vaisselle"], "mur", 1, false], [["table_repas", "table_bistrot"], "centre", 1, false],
		[["vaisselier", "buffet"], "mur", 1, false], [["jarre"], "coin", 1, false], [["etagere_murale"], "accroche", 1, false]],
	"chambre": [[["lit_double", "hamac"], "mur", 1, true], [["chevet"], "mur", 2, false], [["armoire", "coffre"], "mur", 1, false],
		[["commode"], "mur", 1, false], [["coiffeuse", "table_toilette"], "mur", 1, false], [["tapis"], "sol", 1, false],
		[["lampadaire", "plante"], "coin", 1, false], [["cadre"], "accroche", 1, false]],
	"enfant": [[["lit_simple", "lit_superpose", "hamac"], "mur", 2, true], [["bureau_maison"], "mur", 1, false], [["coffre_jouets"], "coin", 1, false],
		[["armoire", "commode", "coffre"], "mur", 1, false], [["tapis"], "sol", 1, false], [["etagere_murale"], "accroche", 1, false]],
	"sdb": [[["wc", "chaise_percee"], "mur", 1, true], [["lavabo", "meuble_vasque", "table_toilette"], "mur", 1, true],
		[["baignoire", "douche", "baquet"], "mur", 1, true], [["plante"], "coin", 1, false]],
	"entree": [[["porte_manteau"], "mur", 1, false], [["banc"], "mur", 1, false], [["horloge", "commode"], "mur", 1, false],
		[["miroir", "cadre"], "accroche", 1, false], [["plante"], "coin", 1, false]],
	"bureau": [[["poste_travail"], "remplir", 12, true], [["armoire_dossiers"], "mur", 2, false], [["photocopieur"], "mur", 1, false],
		[["fontaine_eau"], "mur", 1, false], [["grande_plante", "plante"], "coin", 2, false], [["cadre"], "accroche", 1, false]],
	"classe": [], # disposition à part (face au tableau)
	"boutique": [[["comptoir"], "centre", 1, true], [["rayonnage", "vitrine_froide", "portant", "etal"], "remplir_mur", 8, true],
		[["presentoir", "mannequin", "caisses"], "remplir", 4, false], [["plante"], "coin", 1, false]],
	"salle": [[["comptoir_bar"], "centre", 1, true], [["banquette"], "mur", 2, false], [["table_bistrot", "table_repas"], "remplir", 8, true],
		[["grande_plante", "plante"], "coin", 2, false], [["cadre"], "accroche", 2, false]],
	"reserve": [[["etagere_reserve", "rayonnage"], "remplir_mur", 6, true], [["caisses", "jarre"], "remplir", 4, false]],
	"studio": [[["cuisiniere", "fourneau", "foyer_feu"], "mur", 1, true], [["evier"], "mur", 1, true], [["refrigerateur", "garde_manger"], "mur", 1, true],
		[["lit_double", "lit_simple", "hamac"], "mur", 1, true], [["canape", "banquette", "coussins_sol"], "mur", 1, false],
		[["table_bistrot", "table_repas"], "centre", 1, false], [["armoire", "coffre"], "mur", 1, false], [["plante"], "coin", 1, false]],
}
const FN_NAMES := {"studio": "Studio (pièce unique)"}

@export var plans_path: NodePath
@export var buildings_path: NodePath
@export var camera_path: NodePath

var pe: PlanEditor
var buildings: BuildingSystem
var camera: Camera3D

var tool: Tool = Tool.NONE
## Meuble choisi pour l'outil Poser.
var meuble := ""
var rot := 0
## Style du mobilier généré.
var style := "contemporain"
## Fonction donnée aux pièces par l'outil Fonction ("" = devinée).
var room_fn := "sejour"
## Gabarit de bâtiment meublé pour l'outil Gabarit.
var template := "maison"

## id du plan -> {Vector4i: {m, r}}
var items: Dictionary = {}
## id du plan -> {Vector3i (case, étage): fonction}
var room_fns: Dictionary = {}
## id du plan -> usage
var usages: Dictionary = {}
## id du plan -> style dominant (dernier style utilisé pour meubler)
var styles: Dictionary = {}

var _occ: Dictionary = {} # id -> {Vector4i(x, e, z, couche): clé du meuble}
var _nodes: Dictionary = {} # id -> {e: Node3D}
var _dirty: Dictionary = {} # id -> {e: true}
var _undo: Array = []
var _hover := {}
var _ghost: MeshInstance3D
var _ghost_mat: StandardMaterial3D
var _ghost_bad: StandardMaterial3D
var _ghost_key := ""
var _focus := ""
var _vis_timer := 0.0
var _stats_cache: Dictionary = {}


func _ready() -> void:
	if not plans_path.is_empty():
		pe = get_node_or_null(plans_path) as PlanEditor
	if not buildings_path.is_empty():
		buildings = get_node_or_null(buildings_path) as BuildingSystem
	if not camera_path.is_empty():
		camera = get_node_or_null(camera_path) as Camera3D
	if pe != null:
		pe.changed.connect(_on_plans_changed)
	_ghost = MeshInstance3D.new()
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost.visible = false
	add_child(_ghost)
	_ghost_mat = StandardMaterial3D.new()
	_ghost_mat.albedo_color = Color(0.55, 0.9, 1.0, 0.55)
	_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_bad = _ghost_mat.duplicate()
	_ghost_bad.albedo_color = Color(1.0, 0.35, 0.3, 0.55)
	var region := Prenoms.region_for_place(GameStart.lat, GameStart.lon) if GameStart.chosen else "europe"
	style = default_style_for(region)


static func default_style_for(region: String) -> String:
	var r := region
	if not Meubles.DEFAULT_STYLE.has(r):
		r = "europe"
	return String(Meubles.DEFAULT_STYLE[r])


static func fn_name(fn: String) -> String:
	if FN_NAMES.has(fn):
		return String(FN_NAMES[fn])
	return Meubles.piece_name(fn)


func clear() -> void:
	items.clear()
	room_fns.clear()
	usages.clear()
	styles.clear()
	_occ.clear()
	_undo.clear()
	_stats_cache.clear()
	for id in _nodes:
		for n in (_nodes[id] as Dictionary).values():
			(n as Node).queue_free()
	_nodes.clear()
	_dirty.clear()
	_focus = ""
	changed.emit()


# --- Outils -------------------------------------------------------------------------

func set_tool(t: Tool) -> void:
	tool = t
	_hover = {}
	_ghost.visible = false
	if pe != null:
		pe.cut_override = t != Tool.NONE
		pe._apply_cutaway()
	if t == Tool.NONE:
		info_changed.emit("")
	else:
		_emit_help()


func set_inactive() -> void:
	if tool != Tool.NONE:
		set_tool(Tool.NONE)


func set_meuble(id: String) -> void:
	if Meubles.has(id):
		meuble = id
		_ghost_key = ""
		if tool != Tool.PLACE:
			set_tool(Tool.PLACE)
		else:
			_emit_help()


func set_style(s: String) -> void:
	if Meubles.STYLES.has(s):
		style = s
		if tool != Tool.NONE:
			_emit_help()


func set_room_fn(fn: String) -> void:
	room_fn = fn
	if tool != Tool.NONE:
		_emit_help()


func set_template(kind: String) -> void:
	if Gabarits.KINDS.has(kind):
		template = kind
		if tool != Tool.TEMPLATE:
			set_tool(Tool.TEMPLATE)
		else:
			_emit_help()


func _emit_help() -> void:
	var t := ""
	var lv := PlanEditor.level_name(pe.level) if pe != null else ""
	match tool:
		Tool.PLACE:
			var e := Meubles.get_entry(meuble)
			if e.is_empty():
				t = "Choisis un meuble dans la liste"
			else:
				t = "%s (%s, %s) : clic sur le sol d'un bâtiment · R : tourner" % [e.name, Meubles.style_of(String(e.style)).name, Meubles.describe(meuble)]
		Tool.ERASE:
			t = "Retirer : clic sur un meuble (%d %% remboursés) · glissé : tout un rectangle" % roundi(REFUND * 100)
		Tool.FURNISH:
			t = "Meubler (%s) : clic dans une pièce · la fonction de la pièce choisit le mobilier" % Meubles.style_of(style).name
		Tool.ROOM_FN:
			t = "Fonction des pièces : clic dans une pièce pour en faire : %s" % fn_name(room_fn)
		Tool.TEMPLATE:
			t = "%s meublé (%s) : clic sur un terrain libre · R : tourner" % [Gabarits.KINDS[template].name, Meubles.style_of(style).name]
	info_changed.emit("%s · %s · Page haut / Page bas : étage · clic droit : retirer · Ctrl+Z : annuler · Échap : arrêter" % [t, lv])


# --- Géométrie des plans ----------------------------------------------------------------

static func edge_key(c: Vector2i, e: int, d: Vector2i) -> Vector4i:
	if d == Vector2i(0, -1):
		return Vector4i(c.x, e, c.y, 0)
	if d == Vector2i(0, 1):
		return Vector4i(c.x, e, c.y + 1, 0)
	if d == Vector2i(-1, 0):
		return Vector4i(c.x, e, c.y, 1)
	return Vector4i(c.x + 1, e, c.y, 1)


const DIRS := [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 0)]


## Mur (avec ou sans ouverture) entre la case c et sa voisine dans la direction d.
func wall_at(id: String, e: int, c: Vector2i, d: Vector2i) -> Dictionary:
	return pe.plans[id].walls.get(edge_key(c, e, d), {})


static func is_door(w: Dictionary) -> bool:
	if w.is_empty() or String(w.o) == "":
		return false
	return float(PlanEditor.OPENINGS[String(w.o)].s) < 0.05


## Hauteur libre sous une ouverture du mur (INF : mur plein).
static func sill(w: Dictionary) -> float:
	if w.is_empty() or String(w.o) == "":
		return INF
	return float(PlanEditor.OPENINGS[String(w.o)].s)


func has_floor(id: String, e: int, c: Vector2i) -> bool:
	return pe.plans[id].floors.has(Vector3i(c.x, e, c.y))


## Cases d'un étage que l'escalier prend (escalier, trémie, palier).
func blocked_cells(id: String, e: int) -> Dictionary:
	var out := {}
	var p: Dictionary = pe.plans[id]
	for k in p.stairs:
		var ks: Vector3i = k
		var r := int(p.stairs[k].r)
		var cs := PlanEditor.stair_cells(ks, r)
		var dir: Vector2i = PlanEditor.STAIR_DIRS[r % 4]
		if ks.y == e:
			for c in cs:
				out[c] = "escalier"
			out[Vector2i(ks.x, ks.z) - dir] = "palier"
		elif ks.y == e - 1:
			for i in cs.size():
				if i >= 1:
					out[cs[i]] = "tremie"
			out[(cs[cs.size() - 1] as Vector2i) + dir] = "palier"
	return out


## Pièces d'un étage : [{cells: [Vector2i], key: Vector2i, area, fn, guessed}].
func rooms(id: String, e: int) -> Array:
	var out := []
	if pe == null or not pe.plans.has(id):
		return out
	var p: Dictionary = pe.plans[id]
	var todo := {}
	for k in p.floors:
		var kf: Vector3i = k
		if kf.y == e:
			todo[Vector2i(kf.x, kf.z)] = true
	var seen := {}
	var keys := todo.keys()
	keys.sort()
	for start in keys:
		if seen.has(start):
			continue
		var cells: Array = []
		var stack: Array = [start]
		seen[start] = true
		while not stack.is_empty():
			var c: Vector2i = stack.pop_back()
			cells.append(c)
			for d in DIRS:
				var n: Vector2i = c + d
				if seen.has(n) or not todo.has(n):
					continue
				if p.walls.has(edge_key(c, e, d)):
					continue
				seen[n] = true
				stack.append(n)
		cells.sort()
		var fn := _stored_fn(id, e, cells)
		out.append({"cells": cells, "key": cells[0], "area": cells.size(), "fn": fn, "e": e})
	return out


func _stored_fn(id: String, e: int, cells: Array) -> String:
	var f: Dictionary = room_fns.get(id, {})
	if f.is_empty():
		return ""
	var count := {}
	for c in cells:
		var k := Vector3i(c.x, e, c.y)
		if f.has(k):
			count[f[k]] = int(count.get(f[k], 0)) + 1
	var best := ""
	var bn := 0
	for fn in count:
		if count[fn] > bn:
			bn = count[fn]
			best = fn
	return best


func room_at(id: String, e: int, c: Vector2i) -> Dictionary:
	for r in rooms(id, e):
		if c in r.cells:
			return r
	return {}


## Donne une fonction à la pièce de la case c.
func set_room_function(id: String, e: int, c: Vector2i, fn: String) -> bool:
	var r := room_at(id, e, c)
	if r.is_empty():
		return false
	var f: Dictionary = room_fns.get(id, {})
	room_fns[id] = f
	for cc in r.cells:
		if fn == "":
			f.erase(Vector3i(cc.x, e, cc.y))
		else:
			f[Vector3i(cc.x, e, cc.y)] = fn
	_stats_cache.erase(id)
	changed.emit()
	return true


func usage_of(id: String) -> String:
	return String(usages.get(id, "logement"))


func set_usage(id: String, u: String) -> void:
	if not USAGES.has(u) or pe == null or not pe.plans.has(id):
		return
	usages[id] = u
	_stats_cache.erase(id)
	changed.emit()
	plan_selected.emit(id)


## Fonctions devinées des pièces de tout le bâtiment, selon son usage et leur taille.
func guess_functions(id: String) -> Dictionary:
	var out := {} # Vector3i(case clé, étage) -> fonction
	var u := usage_of(id)
	var levels := pe.levels_of(id)
	# Immeuble (3 niveaux ou plus) : chaque étage est un appartement.
	var flat := levels.size() >= 3 or u != "logement"
	var groups := []
	if flat:
		for e in levels:
			groups.append(rooms(id, int(e)))
	else:
		var all := []
		for e in levels:
			all.append_array(rooms(id, int(e)))
		groups.append(all)
	for g in groups:
		var list: Array = g.duplicate()
		list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.area) > int(b.area))
		var big := []
		var small := []
		for r in list:
			if int(r.area) <= 7:
				small.append(r)
			else:
				big.append(r)
		_guess_group(u, list, big, small, out)
	return out


func _guess_group(u: String, list: Array, big: Array, small: Array, out: Dictionary) -> void:
	var have := {}
	var assign := func(r: Dictionary, fn: String) -> void:
		out[Vector3i(r.key.x, int(r.e), r.key.y)] = fn
		have[fn] = int(have.get(fn, 0)) + 1
	if u == "logement":
		if list.size() == 1:
			assign.call(list[0], "studio")
			return
		var lowest := 999
		for r in big:
			lowest = mini(lowest, int(r.e))
		# Séjour : la plus grande pièce de l'étage le plus bas.
		var sej := Vector3i(0, -999, 0)
		for r in big:
			if int(r.e) == lowest:
				sej = Vector3i(r.key.x, int(r.e), r.key.y)
				break
		var sdb_levels := {}
		for r in small:
			if int(r.area) <= 2:
				assign.call(r, "entree")
			elif not sdb_levels.has(int(r.e)):
				assign.call(r, "sdb")
				sdb_levels[int(r.e)] = true
			elif not have.has("cuisine") and int(r.area) >= 5:
				assign.call(r, "cuisine")
			else:
				assign.call(r, "entree")
		for r in big:
			var k := Vector3i(r.key.x, int(r.e), r.key.y)
			if k == sej:
				assign.call(r, "sejour")
			elif not have.has("cuisine") and int(r.e) == lowest:
				assign.call(r, "cuisine")
			elif not have.has("chambre"):
				assign.call(r, "chambre")
			else:
				assign.call(r, "enfant")
		if not have.has("cuisine") and sej.y != -999:
			# Pas de pièce pour la cuisine : le séjour fait aussi cuisine.
			out[sej] = "studio"
		if not have.has("chambre") and not have.has("enfant") and sej.y != -999:
			out[sej] = "studio"
		return
	match u:
		"ecole":
			for r in big:
				assign.call(r, "classe" if int(r.area) >= 16 else "bureau")
			for r in small:
				assign.call(r, "sdb" if not have.has("sdb") else "entree")
		"boutique":
			for i in big.size():
				assign.call(big[i], "boutique" if i == 0 or int(big[i].area) >= 20 else "reserve")
			for r in small:
				if big.is_empty() and not have.has("boutique"):
					assign.call(r, "boutique")
				else:
					assign.call(r, "sdb" if not have.has("sdb") else "reserve")
		"bureaux":
			for r in big:
				assign.call(r, "bureau")
			for r in small:
				if big.is_empty() and not have.has("bureau"):
					assign.call(r, "bureau")
				else:
					assign.call(r, "sdb" if not have.has("sdb") else "entree")
		"restaurant":
			for i in big.size():
				assign.call(big[i], "salle" if i == 0 or int(big[i].area) >= 24 else "cuisine")
			for r in small:
				if not have.has("salle"):
					assign.call(r, "salle")
				elif not have.has("sdb"):
					assign.call(r, "sdb")
				elif not have.has("cuisine"):
					assign.call(r, "cuisine")
				else:
					assign.call(r, "reserve")


## Fonction d'une pièce : choisie, ou devinée.
func function_of(id: String, room: Dictionary, guesses: Dictionary = {}) -> String:
	if String(room.fn) != "":
		return String(room.fn)
	if guesses.is_empty():
		guesses = guess_functions(id)
	return String(guesses.get(Vector3i(room.key.x, int(room.e), room.key.y), "sejour"))


# --- Pose -----------------------------------------------------------------------------

static func layer_index(e: Dictionary) -> int:
	return maxi(0, LAYERS.find(String(e.couche)))


func _occ_of(id: String) -> Dictionary:
	if not _occ.has(id):
		_occ[id] = {}
	return _occ[id]


## Meuble posé sur la case c (couche, ou -1 : la plus haute) : clé ou null.
func item_at(id: String, e: int, c: Vector2i, layer := -1) -> Variant:
	var o: Dictionary = _occ.get(id, {})
	if layer >= 0:
		return o.get(Vector4i(c.x, e, c.y, layer))
	for l in [2, 1, 0]:
		var k: Variant = o.get(Vector4i(c.x, e, c.y, l))
		if k != null:
			return k
	return null


## Peut-on poser le meuble m en c (étage e, rotation r) ? "" si oui, sinon la raison.
func check(id: String, e: int, c: Vector2i, r: int, m: String, blocked := {}) -> String:
	var ent := Meubles.get_entry(m)
	if ent.is_empty():
		return "meuble inconnu"
	if pe == null or not pe.plans.has(id):
		return "pas de bâtiment ici"
	var p: Dictionary = pe.plans[id]
	var cells := Meubles.cells_of(ent, c, r)
	var layer := layer_index(ent)
	var o := _occ_of(id)
	var bl := blocked if not blocked.is_empty() else blocked_cells(id, e)
	var fpset := {}
	for cc in cells:
		fpset[cc] = true
	for cc in cells:
		if not p.floors.has(Vector3i(cc.x, e, cc.y)):
			return "il faut un plancher sous le meuble"
		if bl.has(cc) and layer != 2:
			return "la place de l'escalier reste libre"
		if o.has(Vector4i(cc.x, e, cc.y, layer)):
			return "la place est prise"
		# Un meuble ne traverse pas un mur.
		for d in [Vector2i(1, 0), Vector2i(0, 1)]:
			if fpset.has(cc + d) and p.walls.has(edge_key(cc, e, d)):
				return "un mur coupe la place"
	if layer == 2 or (layer == 1 and float(ent.h) > 0.3 and bool(ent.mur)):
		# Couche mur : un mur derrière chaque case du dos.
		var back := Meubles.back_dir(r)
		var row := _back_row(cells, back)
		for cc in row:
			var w: Dictionary = p.walls.get(edge_key(cc, e, back), {})
			if layer == 2:
				if w.is_empty() or is_door(w):
					return "il faut un mur plein derrière"
				if sill(w) < 2.2:
					return "pas devant une fenêtre"
	return ""


static func _back_row(cells: Array, back: Vector2i) -> Array:
	var out := []
	var fpset := {}
	for c in cells:
		fpset[c] = true
	for c in cells:
		if not fpset.has((c as Vector2i) + back):
			out.append(c)
	return out


func _price_ok(amount: int) -> bool:
	return buildings == null or buildings.unlimited_money or buildings.money >= amount


func _pay(amount: int) -> void:
	if buildings != null and not buildings.unlimited_money:
		buildings.money -= amount


## Pose un meuble (payé). Rend "" ou la raison du refus.
func place(id: String, e: int, c: Vector2i, r: int, m: String, pay := true, record := true) -> String:
	var why := check(id, e, c, r, m)
	if why != "":
		return why
	var ent := Meubles.get_entry(m)
	var price := int(ent.prix)
	if pay and not _price_ok(price):
		return "pas assez d'argent (%s)" % BuildingSystem.format_money(price)
	if record:
		_push_undo(id, price if pay else 0)
	if pay:
		_pay(price)
	_put(id, e, c, r, m)
	_after(id, e)
	return ""


func _put(id: String, e: int, c: Vector2i, r: int, m: String) -> void:
	var ent := Meubles.get_entry(m)
	var layer := layer_index(ent)
	var key := Vector4i(c.x, e, c.y, layer)
	if not items.has(id):
		items[id] = {}
	items[id][key] = {"m": m, "r": r % 4}
	var o := _occ_of(id)
	for cc in Meubles.cells_of(ent, c, r):
		o[Vector4i(cc.x, e, cc.y, layer)] = key


func _take(id: String, key: Vector4i) -> void:
	var it: Dictionary = items.get(id, {}).get(key, {})
	if it.is_empty():
		return
	var ent := Meubles.get_entry(String(it.m))
	var o := _occ_of(id)
	if not ent.is_empty():
		for cc in Meubles.cells_of(ent, Vector2i(key.x, key.z), int(it.r)):
			o.erase(Vector4i(cc.x, key.y, cc.y, key.w))
	else:
		for k in o.keys():
			if o[k] == key:
				o.erase(k)
	(items[id] as Dictionary).erase(key)


## Retire le meuble de clé key (remboursé à moitié).
func remove(id: String, key: Vector4i, record := true) -> bool:
	var it: Dictionary = items.get(id, {}).get(key, {})
	if it.is_empty():
		return false
	var price := int(Meubles.get_entry(String(it.m)).get("prix", 0))
	if record:
		_push_undo(id, -roundi(price * REFUND))
	_pay(-roundi(price * REFUND))
	_take(id, key)
	_after(id, key.y)
	return true


func remove_rect(id: String, rect: Rect2i, e: int) -> int:
	var keys := {}
	var o: Dictionary = _occ.get(id, {})
	for x in range(rect.position.x, rect.end.x):
		for z in range(rect.position.y, rect.end.y):
			for l in 3:
				var k: Variant = o.get(Vector4i(x, e, z, l))
				if k != null:
					keys[k] = true
	if keys.is_empty():
		return 0
	var refund := 0
	for k in keys:
		refund += roundi(int(Meubles.get_entry(String(items[id][k].m)).get("prix", 0)) * REFUND)
	_push_undo(id, -refund)
	_pay(-refund)
	for k in keys:
		_take(id, k)
	_after(id, e)
	return keys.size()


func _after(id: String, e: int) -> void:
	_stats_cache.erase(id)
	_mark(id, e)
	changed.emit()


func _snapshot(id: String) -> Dictionary:
	return {"items": (items.get(id, {}) as Dictionary).duplicate(true), "fns": (room_fns.get(id, {}) as Dictionary).duplicate(true),
		"usage": usages.get(id, null), "style": styles.get(id, null)}


func _push_undo(id: String, cost: int) -> void:
	_undo.append({"id": id, "before": _snapshot(id), "cost": cost})
	if _undo.size() > 200:
		_undo.pop_front()


func undo() -> bool:
	if _undo.is_empty():
		return false
	var op: Dictionary = _undo.pop_back()
	var id: String = op.id
	var b: Dictionary = op.before
	_restore(id, b)
	_pay(-int(op.cost))
	return true


func _restore(id: String, b: Dictionary) -> void:
	var levels := {}
	for k in items.get(id, {}):
		levels[(k as Vector4i).y] = true
	items[id] = (b.items as Dictionary).duplicate(true)
	room_fns[id] = (b.fns as Dictionary).duplicate(true)
	if b.usage == null:
		usages.erase(id)
	else:
		usages[id] = b.usage
	if b.style == null:
		styles.erase(id)
	else:
		styles[id] = b.style
	_rebuild_occ(id)
	for k in items[id]:
		levels[(k as Vector4i).y] = true
	for e in levels:
		_mark(id, int(e))
	_stats_cache.erase(id)
	changed.emit()


func _rebuild_occ(id: String) -> void:
	var o := {}
	_occ[id] = o
	for key in items.get(id, {}):
		var k: Vector4i = key
		var it: Dictionary = items[id][k]
		var ent := Meubles.get_entry(String(it.m))
		if ent.is_empty():
			continue
		for cc in Meubles.cells_of(ent, Vector2i(k.x, k.z), int(it.r)):
			o[Vector4i(cc.x, k.y, cc.y, k.w)] = k


## Après une modification des murs ou des sols : les meubles qui n'ont plus leur
## place (plancher retiré, mur coupé…) sont rangés (remboursés à moitié).
func _on_plans_changed() -> void:
	var lost := 0
	for id in items.keys():
		if not pe.plans.has(id):
			for k in items[id]:
				lost += 1
			_drop_plan(id)
			continue
		var bad := []
		var copy: Dictionary = items[id]
		for key in copy.keys():
			var k: Vector4i = key
			var it: Dictionary = copy[k]
			_take(id, k)
			if check(id, k.y, Vector2i(k.x, k.z), int(it.r), String(it.m)) != "":
				bad.append([k, it])
			_put(id, k.y, Vector2i(k.x, k.z), int(it.r), String(it.m))
		for b in bad:
			var price := int(Meubles.get_entry(String(b[1].m)).get("prix", 0))
			_pay(-roundi(price * REFUND))
			_take(id, b[0])
			_mark(id, (b[0] as Vector4i).y)
			lost += 1
	for id in room_fns.keys():
		if not pe.plans.has(id):
			room_fns.erase(id)
			usages.erase(id)
			styles.erase(id)
	for id in usages.keys():
		if not pe.plans.has(id):
			usages.erase(id)
	_stats_cache.clear()
	if lost > 0:
		message.emit("%d meuble%s rangé%s (plus de place)." % [lost, "s" if lost > 1 else "", "s" if lost > 1 else ""])
	changed.emit()


func _drop_plan(id: String) -> void:
	items.erase(id)
	_occ.erase(id)
	room_fns.erase(id)
	usages.erase(id)
	styles.erase(id)
	if _nodes.has(id):
		for n in (_nodes[id] as Dictionary).values():
			(n as Node).queue_free()
		_nodes.erase(id)
	_dirty.erase(id)


# --- Mobilier généré ---------------------------------------------------------------------

## Meuble une pièce (la case c en fait partie) selon sa fonction, dans le style s.
## Les meubles déjà là restent. Rend le nombre de meubles posés.
func furnish_room(id: String, e: int, c: Vector2i, s := "", fn := "", record := true) -> int:
	var room := room_at(id, e, c)
	if room.is_empty():
		return 0
	if s == "":
		s = style
	if fn == "":
		fn = function_of(id, room)
	if record:
		_push_undo(id, 0)
	var spent := 0
	var n := 0
	var res := _layout(id, e, room, fn, s)
	for it in res:
		var price := int(Meubles.get_entry(String(it[3])).prix)
		if not _price_ok(spent + price):
			continue
		if check(id, e, it[0], it[1], it[3]) != "":
			continue
		_put(id, e, it[0], it[1], it[3])
		spent += price
		n += 1
	if record and not _undo.is_empty():
		(_undo[_undo.size() - 1] as Dictionary).cost = spent
	_pay(spent)
	styles[id] = s
	if String(room.fn) == "":
		set_room_function(id, e, c, fn)
	_after(id, e)
	return n


## Meuble toutes les pièces de tout le bâtiment.
func furnish_plan(id: String, s := "") -> int:
	if pe == null or not pe.plans.has(id):
		return 0
	if s == "":
		s = style
	_push_undo(id, 0)
	var spent_before := buildings.money if buildings != null else 0
	var guesses := guess_functions(id)
	var n := 0
	for e in pe.levels_of(id):
		for r in rooms(id, int(e)):
			n += furnish_room(id, int(e), r.key, s, function_of(id, r, guesses), false)
	if buildings != null and not _undo.is_empty():
		(_undo[_undo.size() - 1] as Dictionary).cost = spent_before - buildings.money
	return n


## Disposition du mobilier d'une pièce : [[case, rotation, couche, meuble]].
func _layout(id: String, e: int, room: Dictionary, fn: String, s: String) -> Array:
	var cells: Array = room.cells
	var inroom := {}
	for c in cells:
		inroom[c] = true
	var bl := blocked_cells(id, e)
	# Cases devant les portes et l'escalier : à laisser libres.
	var keep := {}
	for c in cells:
		if bl.has(c):
			keep[c] = true
		for d in DIRS:
			if is_door(wall_at(id, e, c, d)):
				keep[c] = true
				var inner: Vector2i = c - d
				if inroom.has(inner):
					keep[inner] = true
	var st := {"id": id, "e": e, "inroom": inroom, "keep": keep, "taken": {}, "res": [], "bl": bl, "reserved": {}}
	var o: Dictionary = _occ.get(id, {})
	for c in cells:
		for l in 3:
			if o.has(Vector4i(c.x, e, c.y, l)):
				st.taken[Vector3i(c.x, l, c.y)] = true
	if fn == "classe":
		_layout_classe(st, cells, s)
		return st.res
	var area := cells.size()
	for req in LAYOUTS.get(fn, LAYOUTS.sejour):
		var types: Array = req[0]
		var mode: String = req[1]
		var count: int = req[2]
		var essential: bool = req[3]
		var m := Meubles.pick_any(types, s)
		if m == "":
			continue
		if not essential and area < 6 and mode in ["centre", "coin"] and fn != "sdb":
			continue
		if String(Meubles.get_entry(m).type) == "piano" and area < 20:
			continue
		var placed := 0
		var tries := count
		if mode == "remplir" or mode == "remplir_mur":
			tries = count
		for i in tries:
			if not _place_one(st, m, mode, cells, essential):
				break
			placed += 1
		if placed == 0 and essential:
			# Plus petit équivalent : un lit simple au lieu d'un lit double…
			for t in types:
				var m2 := Meubles.pick(String(t), s)
				if m2 != "" and m2 != m and _place_one(st, m2, mode, cells, true):
					break
	return st.res


## Cherche une place pour le meuble m et l'ajoute au résultat.
func _place_one(st: Dictionary, m: String, mode: String, cells: Array, essential: bool) -> bool:
	var ent := Meubles.get_entry(m)
	var layer := layer_index(ent)
	var e: int = st.e
	var id: String = st.id
	var best: Array = []
	var best_score := -INF
	var p: Dictionary = pe.plans[id]
	for c in cells:
		for r in 4:
			var fp := Meubles.cells_of(ent, c, r)
			var ok := true
			for cc in fp:
				if not st.inroom.has(cc) or st.taken.has(Vector3i(cc.x, layer, cc.y)):
					ok = false
					break
				if layer != 2 and (st.keep.has(cc) or (st.reserved.has(cc) and not essential)):
					ok = false
					break
			if not ok:
				continue
			var back := Meubles.back_dir(r)
			var row := _back_row(fp, back)
			var walls_behind := 0
			var window_conflict := false
			for cc in row:
				var w: Dictionary = p.walls.get(edge_key(cc, e, back), {})
				if not w.is_empty() and not is_door(w):
					walls_behind += 1
					if sill(w) < float(ent.h) + 0.05 and sill(w) < 2.2:
						window_conflict = true
			var score := 0.0
			match mode:
				"mur", "remplir_mur", "accroche":
					if walls_behind < row.size() or window_conflict:
						continue
					score = 10.0
				"centre", "remplir":
					# Loin des murs, mais pas au milieu du passage.
					var near := 0
					for cc in fp:
						for d in DIRS:
							if not st.inroom.has(cc + d) or p.walls.has(edge_key(cc, e, d)):
								near += 1
					score = 5.0 - near * 0.8
					if mode == "remplir":
						score = -float(c.y) * 0.01 - float(c.x) * 0.001
				"coin":
					var sides := 0
					for d in DIRS:
						var w2: Dictionary = p.walls.get(edge_key(c, e, d), {})
						if not w2.is_empty() and not is_door(w2):
							sides += 1
					if sides < 2:
						continue
					score = sides
				"sol":
					score = 5.0
					for cc in fp:
						if st.taken.has(Vector3i(cc.x, 1, cc.y)):
							score += 1.0
						for d in DIRS:
							if not st.inroom.has(cc + d):
								score -= 1.5
			# Avec les meubles de même usage (la cuisine se range d'un seul côté).
			if mode == "mur" and (ent.tags as Array).any(func(t: String) -> bool: return t in ["cuisson", "eau", "froid", "preparation"]):
				for cc in fp:
					for d in DIRS:
						if st.taken.has(Vector3i((cc + d).x, 1, (cc + d).y)):
							score += 2.0
			if mode in ["mur", "centre"] and String(ent.type) in ["chevet"]:
				for cc in fp:
					for d in DIRS:
						if st.get("bed_cells", {}).has(cc + d):
							score += 8.0
			score += _hash01(c, r, m) * 0.5
			if score > best_score:
				best_score = score
				best = [c, r]
	if best.is_empty():
		return false
	var cpos: Vector2i = best[0]
	var rr: int = best[1]
	var fp2 := Meubles.cells_of(ent, cpos, rr)
	for cc in fp2:
		st.taken[Vector3i(cc.x, layer, cc.y)] = true
	if layer == 1:
		# Devant le meuble : une allée.
		var front := -Meubles.back_dir(rr)
		var reserve_all := mode == "remplir" or String(ent.type) in ["table_repas", "table_bistrot", "comptoir", "comptoir_bar", "poste_travail", "table_reunion", "presentoir"]
		for cc in fp2:
			var f: Vector2i = cc + front
			if not fp2.has(f):
				st.reserved[f] = true
			if reserve_all:
				for d in DIRS:
					if not fp2.has(cc + d):
						st.reserved[cc + d] = true
		if (ent.tags as Array).has("lit"):
			var bc: Dictionary = st.get("bed_cells", {})
			for cc in fp2:
				bc[cc] = true
			st["bed_cells"] = bc
	(st.res as Array).append([cpos, rr, layer, m])
	return true


static func _hash01(c: Vector2i, r: int, m: String) -> float:
	return float(absi(hash([c.x, c.y, r, m])) % 1000) / 1000.0


## Salle de classe : le tableau sur le plus long mur plein, le bureau du maître
## devant, les pupitres en rangées face au tableau, une allée au milieu.
func _layout_classe(st: Dictionary, cells: Array, s: String) -> void:
	var id: String = st.id
	var e: int = st.e
	var p: Dictionary = pe.plans[id]
	var board := Meubles.pick("tableau", s)
	var desk := Meubles.pick("bureau_maitre", s)
	var pupil := Meubles.pick("pupitre", s)
	# Mur du tableau : la direction où il y a le plus de murs pleins.
	var best_d := Vector2i(0, -1)
	var best_n := -1
	for d in DIRS:
		var n := 0
		for c in cells:
			var w: Dictionary = p.walls.get(edge_key(c, e, d), {})
			if not w.is_empty() and not is_door(w) and sill(w) >= 2.2:
				n += 1
		if n > best_n:
			best_n = n
			best_d = d
	var r := 0
	for i in 4:
		if Meubles.back_dir(i) == best_d:
			r = i
	if board != "":
		_place_one(st, board, "accroche", cells, true)
	# Distance de chaque case au mur du tableau.
	var front := -best_d
	var dist := {}
	var dmax := 0
	for c in cells:
		var k := 0
		var cc: Vector2i = c
		while st.inroom.has(cc + best_d):
			cc += best_d
			k += 1
		dist[c] = k
		dmax = maxi(dmax, k)
	if desk != "":
		var dent := Meubles.get_entry(desk)
		var placed := false
		for c in cells:
			if int(dist[c]) != 1 or placed:
				continue
			var fp := Meubles.cells_of(dent, c, r)
			var ok := true
			for cc in fp:
				if not st.inroom.has(cc) or st.taken.has(Vector3i(cc.x, 1, cc.y)) or st.keep.has(cc) or int(dist.get(cc, -1)) != 1:
					ok = false
			if ok:
				for cc in fp:
					st.taken[Vector3i(cc.x, 1, cc.y)] = true
				(st.res as Array).append([c, r, 1, desk])
				placed = true
	if pupil == "":
		return
	# Allée au milieu (perpendiculaire au tableau).
	var lateral := Vector2i(absi(front.y), absi(front.x))
	var lo := 1 << 30
	var hi := -(1 << 30)
	for c in cells:
		var v: int = c.x * lateral.x + c.y * lateral.y
		lo = mini(lo, v)
		hi = maxi(hi, v)
	var mid := (lo + hi) / 2
	for c in cells:
		var dd := int(dist[c])
		if dd < 3:
			continue
		var v2: int = c.x * lateral.x + c.y * lateral.y
		if (hi - lo) >= 4 and v2 == mid:
			continue
		if v2 == lo and (hi - lo) >= 6:
			continue
		if st.keep.has(c) or st.taken.has(Vector3i(c.x, 1, c.y)):
			continue
		if dd == dmax and dmax >= 6:
			continue
		st.taken[Vector3i(c.x, 1, c.y)] = true
		(st.res as Array).append([c, r, 1, pupil])
	for extra in [["bibliotheque", "mur"], ["casiers", "mur"], ["globe", "coin"], ["plante", "coin"]]:
		var m := Meubles.pick(String(extra[0]), s)
		if m != "":
			_place_one(st, m, String(extra[1]), cells, false)


# --- Chiffres du bâtiment ----------------------------------------------------------------

func bid_of(id: String) -> int:
	var num := id.trim_prefix("plan_")
	return BID_BASE + (int(num) if num.is_valid_int() else 0)


func plan_of_bid(bid: int) -> String:
	return "plan_%d" % (bid - BID_BASE)


## Chiffres d'un bâtiment : usage, surfaces, capacités, confort, valeur, attractivité.
func stats(id: String) -> Dictionary:
	if _stats_cache.has(id):
		return _stats_cache[id]
	var out := {"id": id, "usage": usage_of(id), "area": 0, "rooms": 0, "levels": 0, "lits": 0, "logements": 0, "emplois": 0,
		"places": 0, "conf": 0, "attr": 0, "valeur": 0, "meubles": 0, "prix_meubles": 0, "manques": [], "construction": 0, "loyer": 0.0, "tf": 1.0}
	if pe == null or not pe.plans.has(id):
		return out
	var p: Dictionary = pe.plans[id]
	var u: String = out.usage
	out.area = (p.floors as Dictionary).size()
	var lv := pe.levels_of(id)
	out.levels = lv.size()
	# Construction : murs, sols, ouvertures, escaliers.
	var cost := 0
	for k in p.walls:
		var w: Dictionary = p.walls[k]
		cost += PlanEditor.wall_price(BlocFormes.mat_of(int(w.a)))
		if String(w.o) != "":
			cost += int(PlanEditor.OPENINGS[String(w.o)].price)
	for k in p.floors:
		cost += PlanEditor.floor_price(BlocFormes.mat_of(int(p.floors[k].t)))
	cost += (p.stairs as Dictionary).size() * PlanEditor.STAIR_PRICE
	out.construction = cost
	# Meubles et ce qu'ils apportent.
	var tags := {} # étiquette -> nombre
	var kitchens := {} # étage -> true
	var conf_sum := 0.0
	var attr_sum := 0.0
	var places := {}
	for key in items.get(id, {}):
		var it: Dictionary = items[id][key]
		var ent := Meubles.get_entry(String(it.m))
		if ent.is_empty():
			continue
		out.meubles += 1
		out.prix_meubles += int(ent.prix)
		conf_sum += float(ent.conf)
		attr_sum += float(ent.attr)
		for t in ent.tags:
			tags[t] = int(tags.get(t, 0)) + 1
			if t == "cuisson":
				kitchens[(key as Vector4i).y] = true
		for pl in ent.places:
			places[pl[0]] = int(places.get(pl[0], 0)) + 1
	out.lits = int(places.get("lit", 0)) + int(places.get("bebe", 0))
	var nrooms := 0
	for e in lv:
		nrooms += rooms(id, int(e)).size()
	out.rooms = nrooms
	# Vitrines et baies du rez-de-chaussée : elles attirent le regard.
	var shop_windows := 0
	for k in p.walls:
		var kw: Vector4i = k
		if kw.y == 0 and String(p.walls[k].o) in ["vitrine", "baie", "porte_fenetre"]:
			shop_windows += 1
	var area := maxf(float(out.area), 1.0)
	var manques: Array = out.manques
	match u:
		"logement":
			if int(out.lits) == 0:
				manques.append("pas de lit : personne ne peut y vivre")
				out.logements = 0
			elif lv.size() >= 3:
				out.logements = maxi(1, kitchens.size())
			else:
				out.logements = 1
			var n := maxf(1.0, float(out.logements))
			var c := 30.0 + conf_sum / n * 0.55
			if not tags.has("cuisson"):
				c -= 15.0
				manques.append("pas de quoi cuisiner")
			if not tags.has("wc"):
				c -= 15.0
				manques.append("pas de toilettes")
			if not tags.has("toilette"):
				c -= 10.0
				manques.append("pas de quoi se laver")
			if not tags.has("eau"):
				c -= 5.0
				manques.append("pas d'évier ni de lavabo")
			if not tags.has("assise"):
				c -= 5.0
				manques.append("pas de quoi s'asseoir")
			if tags.has("chauffage"):
				c += 5.0
			if tags.has("lumiere"):
				c += 3.0
			# Place : 15 m² par lit, c'est bien.
			var per_bed := area / maxf(1.0, float(out.lits))
			if per_bed < 8.0:
				c -= 10.0
				manques.append("logement trop petit pour tous ces lits")
			elif per_bed > 18.0:
				c += 5.0
			out.conf = clampi(roundi(c), 0, 100)
			out.attr = clampi(roundi(10.0 + attr_sum * 25.0 / maxf(area, 25.0) + shop_windows * 2.0), 0, 100)
		"ecole":
			out.places = int(places.get("pupitre", 0))
			var classes := int(places.get("tableau", 0))
			out.emplois = 0 if out.places == 0 else classes + 1 + int(out.places) / 60
			if classes == 0:
				manques.append("pas de tableau : pas de classe")
			if out.places == 0:
				manques.append("pas de pupitre : pas d'élève")
			out.conf = clampi(roundi(40.0 + conf_sum * 20.0 / area), 0, 100)
			out.attr = clampi(roundi(15.0 + attr_sum * 30.0 / area), 0, 100)
		"boutique", "restaurant":
			var counters := int(places.get("comptoir", 0))
			if counters == 0:
				manques.append("pas de comptoir ni de caisse")
			var rayons := int(tags.get("rayon", 0))
			var tables := int(tags.get("table", 0))
			if u == "boutique":
				out.emplois = 0 if counters == 0 else counters * 2 + rayons / 3
				if rayons == 0:
					manques.append("rien à vendre (rayonnages, présentoirs, étals)")
			else:
				out.emplois = 0 if counters == 0 else counters * 2 + tables / 3
				if tables == 0:
					manques.append("pas de table pour les clients")
			out.places = int(places.get("assis", 0)) + int(places.get("client", 0))
			out.conf = clampi(roundi(30.0 + conf_sum * 30.0 / area), 0, 100)
			out.attr = clampi(roundi(10.0 + attr_sum * 40.0 / area + shop_windows * 4.0), 0, 100)
		"bureaux":
			out.emplois = int(places.get("poste", 0))
			if out.emplois == 0:
				manques.append("pas de poste de travail")
			out.conf = clampi(roundi(35.0 + conf_sum * 25.0 / area), 0, 100)
			out.attr = clampi(roundi(10.0 + attr_sum * 35.0 / area + shop_windows * 2.0), 0, 100)
	# Valeur : construction + meubles + emplacement (au m², selon confort et attrait).
	var quality := 0.5 + float(out.conf) / 100.0 * 0.7 + float(out.attr) / 100.0 * 0.3
	out.valeur = roundi((cost + int(out.prix_meubles) + area * 1400.0 * quality) / 1000.0) * 1000
	if u == "logement" and int(out.logements) > 0:
		var per := float(out.valeur) / float(out.logements)
		out.loyer = clampf(per * 0.0035, 300.0, 4000.0)
		out.tf = clampf(per / 250000.0, 0.3, 5.0)
	_stats_cache[id] = out
	return out


func plan_name(id: String) -> String:
	var u := usage_of(id)
	var num := id.trim_prefix("plan_")
	var s := stats(id)
	var base := String(USAGES[u].name)
	if u == "logement":
		base = "Immeuble" if int(s.logements) > 1 else "Maison"
	return "%s n° %s" % [base, num]


## Bâtiments en murs fins vus par les habitants : bid -> fiche (comme Population._info_of).
func population_info() -> Dictionary:
	var out := {}
	if pe == null:
		return out
	for id in pe.plans:
		var s := stats(id)
		var u: String = s.usage
		var bbox: Rect2i = pe._bbox.get(id, Rect2i())
		if bbox.size == Vector2i.ZERO:
			continue
		var t := String(USAGES[u].t)
		if u == "logement" and int(s.logements) > 1:
			t = "immeuble"
		var serves := []
		for hb in Metiers.LOISIRS:
			if Metiers.venue_matches(hb, t):
				serves.append(hb)
		var center := BuildingSystem.rect_center(bbox) + Vector3(0, float(pe.plans[id].y0), 0)
		out[bid_of(id)] = {"t": t, "cat": String(USAGES[u].cat), "serves": serves, "log": int(s.logements),
			"emp": int(s.emplois), "seats": int(s.places) if u == "ecole" else 0, "pos": center, "rect": bbox,
			"public": u == "ecole", "cost": int(s.construction) + int(s.prix_meubles), "house": u == "logement" and int(s.logements) == 1,
			"region": String(Meubles.style_of(String(styles.get(id, style))).region), "name": plan_name(id), "plan": id,
			"conf": int(s.conf), "attr": int(s.attr), "valeur": int(s.valeur), "loyer": float(s.loyer), "tf": float(s.tf)}
	return out


## Bâtiment en murs fins sous une case (pour la fiche des habitants) : bid ou -1.
func bid_at(c: Vector2i) -> int:
	if pe == null:
		return -1
	var id := pe.plan_at(c, 0)
	if id == "":
		return -1
	return bid_of(id)


func summary() -> String:
	var n := 0
	for id in items:
		n += (items[id] as Dictionary).size()
	if n == 0:
		return "Aucun meuble posé · %d meubles dans la bible" % Meubles.count()
	return "%d meuble%s posé%s · %d meubles dans la bible" % [n, "s" if n > 1 else "", "s" if n > 1 else "", Meubles.count()]


## Texte des chiffres d'un bâtiment (panneau Intérieur).
func describe_plan(id: String) -> String:
	if pe == null or not pe.plans.has(id):
		return "Vise un bâtiment en murs fins (onglet Éditeur libre, Murs et étages) ou pose un bâtiment meublé."
	var s := stats(id)
	var lines: Array[String] = []
	lines.append("%s · %d m² · %d pièce%s · %d niveau%s" % [plan_name(id), int(s.area), int(s.rooms), "s" if int(s.rooms) > 1 else "", int(s.levels), "x" if int(s.levels) > 1 else ""])
	match String(s.usage):
		"logement":
			lines.append("%d logement%s · %d lit%s" % [int(s.logements), "s" if int(s.logements) > 1 else "", int(s.lits), "s" if int(s.lits) > 1 else ""])
		"ecole":
			lines.append("%d places d'élèves · %d emploi%s" % [int(s.places), int(s.emplois), "s" if int(s.emplois) > 1 else ""])
		_:
			lines.append("%d emploi%s · %d places de clients" % [int(s.emplois), "s" if int(s.emplois) > 1 else "", int(s.places)])
	lines.append("Confort %d · Attractivité %d · Valeur %s" % [int(s.conf), int(s.attr), BuildingSystem.format_money(int(s.valeur))])
	lines.append("%d meuble%s (%s)" % [int(s.meubles), "s" if int(s.meubles) > 1 else "", BuildingSystem.format_money(int(s.prix_meubles))])
	if float(s.loyer) > 0.0:
		lines.append("Loyer %s par mois et par logement" % BuildingSystem.format_money(roundi(float(s.loyer))))
	for m in s.manques:
		lines.append("− " + String(m))
	return "\n".join(lines)


# --- Affichage ------------------------------------------------------------------------

func _mark(id: String, e: int) -> void:
	var d: Dictionary = _dirty.get(id, {})
	d[e] = true
	_dirty[id] = d


func flush() -> void:
	_process(0.0)


func _process(delta: float) -> void:
	if not _dirty.is_empty():
		for id in _dirty:
			for e in _dirty[id]:
				_build_level(String(id), int(e))
		_dirty.clear()
		_vis_timer = 0.0
	_vis_timer -= delta
	if _vis_timer <= 0.0:
		_vis_timer = 0.2
		_sync_visibility()


## Même visibilité que l'étage du plan (vue en coupe).
func _sync_visibility() -> void:
	if pe == null:
		return
	for id in _nodes:
		var pn: Dictionary = pe._nodes.get(id, {})
		for e in _nodes[id]:
			var n: Node3D = _nodes[id][e]
			var ref: Node3D = pn.get(e)
			n.visible = ref == null or ref.visible


func _build_level(id: String, e: int) -> void:
	var nodes: Dictionary = _nodes.get(id, {})
	_nodes[id] = nodes
	var node: Node3D = nodes.get(e)
	var list := []
	if pe != null and pe.plans.has(id):
		for key in items.get(id, {}):
			if (key as Vector4i).y == e:
				list.append(key)
	if list.is_empty():
		if node != null:
			node.queue_free()
			nodes.erase(e)
		return
	if node == null:
		node = Node3D.new()
		node.name = "Meubles_%s_E%d" % [id, e]
		add_child(node)
		nodes[e] = node
	for ch in node.get_children():
		node.remove_child(ch)
		ch.queue_free()
	var by := pe.base_y(id, e)
	var kit := LpKit.new()
	var body := StaticBody3D.new()
	for key in list:
		var k: Vector4i = key
		var it: Dictionary = items[id][k]
		var ent := Meubles.get_entry(String(it.m))
		if ent.is_empty():
			continue
		var xf := placement(ent, Vector2i(k.x, k.z), int(it.r), by)
		MeublesModeles.build(kit, ent, xf)
		if k.w == 1 and float(ent.h) >= 0.3:
			var fp := Meubles.footprint(ent, int(it.r))
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			var hh := minf(float(ent.h), 1.2)
			bs.size = Vector3(maxf(fp.x - 0.2, 0.3), hh, maxf(fp.y - 0.2, 0.3))
			cs.shape = bs
			cs.position = Vector3(k.x + fp.x * 0.5, by + hh * 0.5, k.z + fp.y * 0.5)
			body.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = kit.commit(MeublesModeles.materials())
	node.add_child(mi)
	if body.get_child_count() > 0:
		node.add_child(body)
	else:
		body.free()


## Transformation d'un meuble posé : centre de l'emprise, tourné, reculé du mur.
static func placement(ent: Dictionary, c: Vector2i, r: int, floor_y: float) -> Transform3D:
	var xf := Meubles.transform_of(ent, c, r, floor_y)
	if bool(ent.mur) or String(ent.couche) == "mur":
		var front := -Meubles.back_dir(r)
		xf.origin += Vector3(front.x, 0, front.y) * WALL_GAP
	return xf


# --- Souris et clavier -----------------------------------------------------------------

var _drag := false
var _drag_start := {}
var _right_press := Vector2.ZERO


func _pick(screen: Vector2) -> Dictionary:
	if camera == null or pe == null:
		return {}
	return pe.pick(camera.project_ray_origin(screen), camera.project_ray_normal(screen))


func _unhandled_input(event: InputEvent) -> void:
	if tool == Tool.NONE or camera == null or pe == null:
		return
	if event is InputEventMouseMotion:
		_hover = _pick((event as InputEventMouseMotion).position)
		_update_ghost()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				_right_press = mb.position
			elif mb.position.distance_to(_right_press) < 5.0:
				var h := _pick(mb.position)
				if not h.is_empty() and String(h.id) != "":
					var k: Variant = item_at(h.id, int(h.e), h.cell)
					if k != null and remove(h.id, k):
						message.emit("Meuble retiré.")
				_update_ghost()
			return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		get_viewport().set_input_as_handled()
		_hover = _pick(mb.position)
		if mb.pressed:
			if _hover.is_empty():
				return
			_drag = tool == Tool.ERASE
			_drag_start = _hover.duplicate()
			if not _drag:
				_click(_hover)
		elif _drag:
			_drag = false
			if not _hover.is_empty() and String(_drag_start.id) != "":
				var rect := PlanEditor._cell_rect(_drag_start.cell, _hover.cell)
				var n := remove_rect(_drag_start.id, rect, int(_drag_start.e))
				if n > 0:
					message.emit("%d meuble%s retiré%s." % [n, "s" if n > 1 else "", "s" if n > 1 else ""])
		_update_ghost()
	elif event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo:
			return
		if key.keycode == KEY_ESCAPE:
			set_inactive()
			get_viewport().set_input_as_handled()
		elif key.keycode == KEY_PAGEUP or key.keycode == KEY_PAGEDOWN:
			pe.step_level(1 if key.keycode == KEY_PAGEUP else -1)
			_emit_help()
			_update_ghost()
			get_viewport().set_input_as_handled()
		elif key.physical_keycode == KEY_R and not key.ctrl_pressed:
			rot = (rot + 1) % 4
			_update_ghost()
			get_viewport().set_input_as_handled()
		elif key.keycode == KEY_Z and key.ctrl_pressed:
			if undo():
				message.emit("Annulé.")
			get_viewport().set_input_as_handled()


func _click(h: Dictionary) -> void:
	var id := String(h.id)
	if id != "":
		_focus = id
		plan_selected.emit(id)
	match tool:
		Tool.PLACE:
			if id == "":
				message.emit("Pose les meubles dans un bâtiment en murs fins.")
				return
			var c := _anchor(h)
			var why := place(id, int(h.e), c, rot, meuble)
			if why != "":
				message.emit("Impossible : %s." % why)
		Tool.FURNISH:
			if id == "":
				return
			var n := furnish_room(id, int(h.e), h.cell)
			var r := room_at(id, int(h.e), h.cell)
			message.emit("%s : %d meuble%s posé%s." % [fn_name(String(r.get("fn", ""))) if not r.is_empty() else "Pièce", n, "s" if n > 1 else "", "s" if n > 1 else ""])
		Tool.ROOM_FN:
			if id == "":
				return
			_push_undo(id, 0)
			if set_room_function(id, int(h.e), h.cell, room_fn):
				message.emit("Pièce : %s." % fn_name(room_fn))
		Tool.ERASE:
			pass
		Tool.TEMPLATE:
			var res := Gabarits.build(self, template, h.cell, rot, style)
			if res.ok:
				_focus = String(res.id)
				plan_selected.emit(_focus)
				message.emit("%s meublé posé (%s)." % [Gabarits.KINDS[template].name, BuildingSystem.format_money(int(res.cost))])
			else:
				message.emit("Impossible : %s." % String(res.error))


## Case d'angle du meuble choisi, centré sous la souris.
func _anchor(h: Dictionary) -> Vector2i:
	var ent := Meubles.get_entry(meuble)
	if ent.is_empty():
		return h.cell
	var f := Meubles.footprint(ent, rot)
	var p: Vector3 = h.p
	return Vector2i(floori(p.x - f.x * 0.5 + 0.5), floori(p.z - f.y * 0.5 + 0.5))


func focus_id() -> String:
	if pe != null and pe.active_id() != "":
		return pe.active_id()
	return _focus if pe != null and pe.plans.has(_focus) else ""


func _update_ghost() -> void:
	if tool == Tool.NONE or _hover.is_empty():
		_ghost.visible = false
		return
	var h := _hover
	match tool:
		Tool.PLACE:
			var ent := Meubles.get_entry(meuble)
			if ent.is_empty():
				_ghost.visible = false
				return
			if _ghost_key != meuble:
				_ghost.mesh = MeublesModeles.mesh_of(meuble)
				_ghost_key = meuble
			var c := _anchor(h)
			var id := String(h.id)
			var by := pe.base_y(id, int(h.e)) if id != "" else float((h.p as Vector3).y)
			_ghost.transform = placement(ent, c, rot, by + 0.01)
			var why := check(id, int(h.e), c, rot, meuble) if id != "" else "pas de bâtiment"
			_ghost.material_override = _ghost_mat if why == "" else _ghost_bad
			_ghost.visible = true
			info_changed.emit("%s · %s%s" % [ent.name, Meubles.describe(meuble), "" if why == "" else " · " + why])
		Tool.TEMPLATE:
			var g: Dictionary = Gabarits.KINDS[template]
			var sz := Vector2i(int(g.w), int(g.d)) if rot % 2 == 0 else Vector2i(int(g.d), int(g.w))
			var bm := BoxMesh.new()
			bm.size = Vector3(sz.x, 3.0, sz.y)
			_ghost.mesh = bm
			_ghost_key = ""
			var p: Vector3 = h.p
			_ghost.transform = Transform3D(Basis(), Vector3(h.cell.x + sz.x * 0.5, p.y + 1.5, h.cell.y + sz.y * 0.5))
			_ghost.material_override = _ghost_mat if String(h.id) == "" else _ghost_bad
			_ghost.visible = true
		Tool.ERASE, Tool.FURNISH, Tool.ROOM_FN:
			var id2 := String(h.id)
			if id2 == "":
				_ghost.visible = false
				return
			var cells := []
			if tool == Tool.ERASE:
				var a: Dictionary = _drag_start if _drag else h
				var rect := PlanEditor._cell_rect(a.cell, h.cell)
				for x in range(rect.position.x, rect.end.x):
					for z in range(rect.position.y, rect.end.y):
						cells.append(Vector2i(x, z))
			else:
				var r := room_at(id2, int(h.e), h.cell)
				if r.is_empty():
					_ghost.visible = false
					return
				cells = r.cells
				info_changed.emit("Pièce de %d m² : %s" % [cells.size(), fn_name(function_of(id2, r)) + ("" if String(r.fn) != "" else " (devinée)")])
			var by2 := pe.base_y(id2, int(h.e))
			var boxes := []
			for c2 in cells:
				boxes.append(AABB(Vector3(c2.x + 0.04, by2 + 0.01, c2.y + 0.04), Vector3(0.92, 0.06, 0.92)))
			_ghost.mesh = PlanEditor._boxes_mesh(boxes)
			_ghost_key = ""
			_ghost.transform = Transform3D.IDENTITY
			_ghost.material_override = _ghost_bad if tool == Tool.ERASE else _ghost_mat
			_ghost.visible = true


## Vue au sol : décrit le meuble visé (E ou clic).
func interact_ray(origin: Vector3, dir: Vector3, max_dist := 3.0) -> bool:
	if pe == null:
		return false
	dir = dir.normalized()
	var t := 0.2
	while t <= max_dist:
		var pt := origin + dir * t
		var c := Vector2i(floori(pt.x), floori(pt.z))
		var id := pe.plan_at(c, 0)
		if id != "":
			var e := floori((pt.y - float(pe.plans[id].y0)) / PlanEditor.H)
			var y := pt.y - pe.base_y(id, e)
			var k: Variant = item_at(id, e, c, 1)
			if k == null:
				k = item_at(id, e, c, 2)
			if k != null:
				var it: Dictionary = items[id][k]
				var ent := Meubles.get_entry(String(it.m))
				if y <= float(ent.h) + 0.2 or (k as Vector4i).w == 2:
					message.emit("%s (%s, %s) · %s" % [ent.name, Meubles.style_of(String(ent.style)).name, Styles.era_name(String(ent.era)).to_lower(), Meubles.describe(String(it.m))])
					return true
		t += 0.1
	return false


# --- Sauvegarde --------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var out := []
	for id in pe.plans if pe != null else {}:
		var its := []
		for key in items.get(id, {}):
			var k: Vector4i = key
			var it: Dictionary = items[id][k]
			its.append_array([k.x, k.y, k.z, k.w, String(it.m), int(it.r)])
		var fns := []
		for key in room_fns.get(id, {}):
			var kf: Vector3i = key
			fns.append_array([kf.x, kf.y, kf.z, String(room_fns[id][kf])])
		if its.is_empty() and fns.is_empty() and not usages.has(id):
			continue
		out.append({"id": id, "usage": usage_of(id), "style": String(styles.get(id, "")), "meubles": its, "pieces": fns})
	return {"version": 1, "style": style, "plans": out}


func from_dict(data: Dictionary) -> void:
	clear()
	var s := String(data.get("style", ""))
	if Meubles.STYLES.has(s):
		style = s
	var lost := 0
	for pd in data.get("plans", []):
		var id := String(pd.get("id", ""))
		if id == "":
			continue
		var u := String(pd.get("usage", "logement"))
		if USAGES.has(u):
			usages[id] = u
		var st := String(pd.get("style", ""))
		if Meubles.STYLES.has(st):
			styles[id] = st
		var its: Array = pd.get("meubles", [])
		var i := 0
		while i + 5 < its.size():
			var m := String(its[i + 4])
			if Meubles.has(m):
				var ent := Meubles.get_entry(m)
				var layer := layer_index(ent)
				_put(id, int(its[i + 1]), Vector2i(int(its[i]), int(its[i + 2])), int(its[i + 5]), m)
				if layer != int(its[i + 3]):
					lost += 0
				_mark(id, int(its[i + 1]))
			else:
				lost += 1
			i += 6
		var fns: Array = pd.get("pieces", [])
		var f := {}
		i = 0
		while i + 3 < fns.size():
			f[Vector3i(int(fns[i]), int(fns[i + 1]), int(fns[i + 2]))] = String(fns[i + 3])
			i += 4
		room_fns[id] = f
	if lost > 0:
		message.emit("%d meuble%s inconnu%s ignoré%s." % [lost, "s" if lost > 1 else "", "s" if lost > 1 else "", "s" if lost > 1 else ""])
	changed.emit()
