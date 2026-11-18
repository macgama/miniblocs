class_name VueSouterraine
extends Node3D
## Vue sous terre (mode Gérer) : la suite de la vue par étage. Page bas sous le
## rez-de-chaussée descend au Sous-sol −1, puis −2… jusqu'à −20 (3 m par niveau,
## 60 m de fond). Page haut remonte, Origine ou Échap revient à la surface.
##
## La caméra ne montre plus que la couche COUCHE : la surface s'efface (sauf les
## contours des routes et des bâtiments, pour se repérer) et une grille de terre
## marque le fond du niveau affiché. On voit, à leur vraie profondeur :
## - sous chaque route, les réseaux de rue (couleurs du grillage avertisseur
##   français : vert télécoms, rouge électricité, jaune gaz, bleu eau potable,
##   marron égouts), en gris si ce bout de réseau n'est alimenté par rien ;
## - les gros tronçons enterrés posés au panneau O (conduites, collecteurs, gaz,
##   fibre), en rouge s'ils sont en panne ;
## - les branchements de chaque bâtiment jusqu'à sa rue (gris : pas raccordé) ;
## - les tunnels de route et de train, le métro et ses stations ;
## - les sous-sols : cave ou parking des bâtiments du catalogue (sous_sols_de),
##   vrais sous-sols des bâtiments de l'Atelier (jusqu'à −20 : bunkers).
## Comme pour les étages, un niveau montre ce qui le touche et tout ce qui est
## plus profond (vu à travers la grille) ; ce qui est plus haut est coupé.

signal message(text: String)

## Couche de rendu de la vue (la couche 20 est celle du corps du personnage).
const COUCHE := 1 << 18
## Hauteur d'un niveau (m), comme un étage de l'Atelier (PlanEditor.H).
const H := 3.0
const NIVEAU_MAX := 20
## Les tuyaux sont dessinés un peu plus gros que nature, pour qu'on les voie de haut.
const LOUPE := 1.6
## Rayon montré autour du point visé par la caméra (m).
const RAYON := 450.0
const REFRESH := 0.5

## Réseaux de rue : décalage (part de la largeur de la route), profondeur, section.
const RUE := [
	{"res": "telecom", "dx": 0.42, "d": 0.6, "s": 0.22},
	{"res": "elec", "dx": 0.30, "d": 0.8, "s": 0.2},
	{"res": "gaz", "dx": -0.30, "d": 1.0, "s": 0.25},
	{"res": "eau", "dx": -0.42, "d": 1.2, "s": 0.3},
	{"res": "egout", "dx": 0.0, "d": 2.6, "s": 0.8},
]
## Gros tronçons enterrés : profondeur de l'axe et section (m).
const TRONCONS := {
	"conduite_eau": {"res": "eau", "d": 1.6, "s": 0.6},
	"collecteur": {"res": "egout", "d": 4.0, "s": 1.8},
	"conduite_gaz": {"res": "gaz", "d": 1.3, "s": 0.5},
	"cable_souterrain": {"res": "elec", "d": 1.0, "s": 0.3},
	"aqueduc": {"res": "eau", "d": 2.5, "s": 1.4},
	"egout_separatif": {"res": "egout", "d": 3.5, "s": 1.4},
	"reseau_chaleur": {"res": "gaz", "d": 1.2, "s": 0.7},
	"hydrogenoduc": {"res": "gaz", "d": 1.5, "s": 0.4},
	"fibre": {"res": "telecom", "d": 0.8, "s": 0.3},
	"cuivre": {"res": "telecom", "d": 0.8, "s": 0.3},
	"cuivre_souterrain": {"res": "telecom", "d": 0.8, "s": 0.3},
	"cable_coaxial": {"res": "telecom", "d": 0.7, "s": 0.25},
}
const COULEURS := {
	"telecom": Color(0.25, 0.68, 0.3),
	"elec": Color(0.86, 0.2, 0.14),
	"gaz": Color(0.96, 0.8, 0.16),
	"eau": Color(0.2, 0.46, 0.92),
	"egout": Color(0.52, 0.34, 0.2),
}
const GRIS := Color(0.36, 0.36, 0.38)
const PANNE := Color(1.0, 0.12, 0.1)
const TUNNEL := Color(0.66, 0.64, 0.6, 0.42)
const METRO := Color(0.36, 0.55, 0.85, 0.5)
const CAVE := Color(0.78, 0.66, 0.5, 0.5)
const PARKING := Color(0.55, 0.58, 0.62, 0.5)
const LEGENDE := [
	["Eau potable", "eau"], ["Égouts", "egout"], ["Électricité", "elec"], ["Gaz", "gaz"],
	["Télécoms", "telecom"], ["Métro", "metro"], ["Tunnels", "tunnel"], ["Sous-sols", "cave"],
]

var world: TerrainWorld
var transport: TransportSystem
var buildings: BuildingSystem
var reseaux: Reseaux
var telecom: Telecom
var plans: PlanEditor
var rig: Node3D
var camera: Camera3D

## 0 : surface (vue normale) ; 1 à NIVEAU_MAX : sous-sol montré.
var niveau := 0
var actif: bool:
	get: return niveau > 0

var _env: Environment
var _env_avant: Environment
var _cull_avant := 0xFFFFF
var _mi: Dictionary = {}
var _mat_plein: StandardMaterial3D
var _mat_verre: StandardMaterial3D
var _mat_repere: StandardMaterial3D
var _centre_fait := Vector2(INF, INF)
var _sale := true
var _timer := 0.0
## Nœuds des sous-sols de l'Atelier passés sur la couche de la vue.
var _plans_marques: Array = []
var _ui: CanvasLayer
var _box: PanelContainer
var _label: Label
var _colonne: VBoxContainer
## Outils pour construire sous terre (conduites, tunnels, pièces), branchés par terre_main.
var construction: ConstructionSouterraine
## Compteurs du dernier dessin (tests) : "rues", "troncons", "branchements",
## "tunnels", "stations", "sous_sols", "plans", "pieces".
var compte := {}


func _ready() -> void:
	_mat_plein = StandardMaterial3D.new()
	_mat_plein.vertex_color_use_as_albedo = true
	_mat_plein.roughness = 0.75
	_mat_plein.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_verre = StandardMaterial3D.new()
	_mat_verre.vertex_color_use_as_albedo = true
	_mat_verre.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_verre.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_verre.roughness = 0.9
	_mat_repere = StandardMaterial3D.new()
	_mat_repere.vertex_color_use_as_albedo = true
	_mat_repere.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_repere.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_repere.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_repere.render_priority = 1
	for k in ["plein", "verre", "sol", "repere"]:
		var mi := MeshInstance3D.new()
		mi.name = "Souterrain_" + k
		mi.layers = COUCHE
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		_mi[k] = mi
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0.1, 0.085, 0.07)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.92, 0.9, 0.86)
	_env.ambient_light_energy = 0.85
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_construire_ui()


# --- Niveaux --------------------------------------------------------------------

## Entre sous terre (Sous-sol −1).
func entrer() -> void:
	if actif:
		return
	if camera == null or (camera.get_viewport() != null and camera.get_viewport().get_camera_3d() != camera):
		message.emit("Vue sous terre : seulement depuis la vue de dessus.")
		return
	_cull_avant = camera.cull_mask
	_env_avant = camera.environment
	camera.cull_mask = COUCHE
	camera.environment = _env
	niveau = 1
	for k in _mi:
		(_mi[k] as MeshInstance3D).visible = true
	_sale = true
	_maj()
	message.emit("Vue sous terre : Page bas pour descendre, Page haut pour remonter, Origine ou Échap pour revenir à la surface.")


func sortir() -> void:
	if not actif:
		return
	niveau = 0
	if camera != null:
		camera.cull_mask = _cull_avant
		camera.environment = _env_avant
	for k in _mi:
		(_mi[k] as MeshInstance3D).visible = false
	_demarquer_plans()
	_box.visible = false
	if construction != null:
		construction.desactiver()


## d = −1 descend d'un niveau, +1 remonte (au-dessus de −1 : retour à la surface).
func step(d: int) -> void:
	if not actif:
		if d < 0:
			entrer()
		return
	var n := niveau - d
	if n <= 0:
		sortir()
		return
	n = mini(n, NIVEAU_MAX)
	if n == niveau:
		message.emit("Vue sous terre : %d m, c'est le plus profond." % roundi(NIVEAU_MAX * H))
		return
	niveau = n
	_sale = true
	_maj()
	if construction != null:
		construction.niveau_change()


func set_niveau(n: int) -> void:
	if n <= 0:
		sortir()
		return
	if not actif:
		entrer()
	if not actif:
		return
	var avant := niveau
	niveau = clampi(n, 1, NIVEAU_MAX)
	_sale = true
	_maj()
	if construction != null and niveau != avant:
		construction.niveau_change()


static func niveau_nom(n: int) -> String:
	return "Sous-sol −%d  (%d à %d m)" % [n, roundi((n - 1) * H), roundi(n * H)]


## Un objet dont le point le plus profond est à d_max mètres sous la surface se
## voit au niveau n s'il descend au moins jusqu'au plafond de ce niveau.
static func visible_au(n: int, d_max: float) -> bool:
	return d_max > (n - 1) * H + 0.05


## Niveaux de sous-sol d'un bâtiment du catalogue : cave pour les maisons et les
## petits commerces, parking pour les immeubles, deux niveaux pour les tours et
## les grandes surfaces. Rien sous les usines, fermes et réseaux. Un bâtiment
## peut porter sa propre valeur ("sous_sols" dans ses données).
static func sous_sols_de(type_id: String, b: Dictionary = {}) -> int:
	if b.has("sous_sols"):
		return clampi(int(b.sous_sols), 0, NIVEAU_MAX)
	var t := BuildingCatalog.get_type(type_id)
	if t.is_empty() or t.has("reseau"):
		return 0
	var aire := float(t.get("w", 0)) * float(t.get("d", 0))
	var haut := BuildingCatalog.approx_height(type_id)
	match String(t.get("cat", "")):
		"logement":
			return 2 if haut > 30.0 else 1
		"commerce":
			return 2 if aire >= 600.0 or haut > 30.0 else 1
		"industrie", "agriculture", "reseaux":
			return 0
	return 1 if aire >= 300.0 else 0


## Vrai si ce bâtiment a un parking (et pas une cave) sous lui.
static func est_parking(type_id: String) -> bool:
	var t := BuildingCatalog.get_type(type_id)
	if String(t.get("cat", "")) == "logement":
		return int(t.get("logements", 1)) > 2
	return float(t.get("w", 0)) * float(t.get("d", 0)) >= 600.0


# --- Mise à jour ------------------------------------------------------------------

func marquer_sale() -> void:
	_sale = true


func _centre() -> Vector2:
	if rig == null:
		return Vector2.ZERO
	return Vector2(rig.global_position.x, rig.global_position.z)


func _process(delta: float) -> void:
	if not actif:
		return
	# Vue au sol ou autre caméra : la vue sous terre s'arrête.
	if camera == null or camera.get_viewport().get_camera_3d() != camera:
		sortir()
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = REFRESH
	if _centre().distance_to(_centre_fait) > RAYON * 0.25:
		_sale = true
	if _sale:
		_maj()
	else:
		_marquer_plans()


func _unhandled_input(event: InputEvent) -> void:
	if not actif:
		return
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	# Un outil de construction en main : Échap arrête le tracé, puis range l'outil.
	if construction != null and construction.outil != ConstructionSouterraine.Outil.AUCUN \
			and (k.keycode == KEY_ESCAPE or k.keycode == KEY_HOME):
		construction.echap()
		get_viewport().set_input_as_handled()
		return
	match k.keycode:
		KEY_PAGEDOWN:
			step(-1)
		KEY_PAGEUP:
			step(1)
		KEY_HOME, KEY_ESCAPE:
			sortir()
		_:
			return
	get_viewport().set_input_as_handled()


func _maj() -> void:
	_sale = false
	_centre_fait = _centre()
	_label.text = "%s  ·  niveau %d / %d" % [niveau_nom(niveau), niveau, NIVEAU_MAX]
	_box.visible = true
	compte = {"rues": 0, "troncons": 0, "branchements": 0, "tunnels": 0, "stations": 0, "sous_sols": 0, "plans": 0, "pieces": 0}
	var plein := SurfaceTool.new()
	plein.begin(Mesh.PRIMITIVE_TRIANGLES)
	var verre := SurfaceTool.new()
	verre.begin(Mesh.PRIMITIVE_TRIANGLES)
	var repere := SurfaceTool.new()
	repere.begin(Mesh.PRIMITIVE_TRIANGLES)
	_dessiner_rues(plein, repere)
	_dessiner_troncons(plein)
	_dessiner_branchements(plein)
	_dessiner_tunnels(plein, verre)
	_dessiner_sous_sols(plein, verre, repere)
	if construction != null:
		compte.pieces = construction.dessiner(plein, verre, niveau)
	_poser(_mi.plein, plein, _mat_plein)
	_poser(_mi.verre, verre, _mat_verre)
	_poser(_mi.repere, repere, _mat_repere)
	_poser(_mi.sol, _grille(), _mat_repere)
	_marquer_plans()


func _poser(mi: MeshInstance3D, st: SurfaceTool, mat: Material) -> void:
	var m := st.commit()
	if m.get_surface_count() > 0:
		m.surface_set_material(0, mat)
	mi.mesh = m


# --- Hauteurs -----------------------------------------------------------------------

func _sol(x: float, z: float, defaut: float) -> float:
	if world == null:
		return defaut
	var h := world.cell_height(Vector2i(floori(x), floori(z)))
	return defaut if is_nan(h) else h


func _proche(p: Vector3) -> bool:
	return Vector2(p.x, p.z).distance_to(_centre_fait) <= RAYON


## Grille de terre au fond du niveau montré : un damier de 10 m qui suit le relief.
func _grille() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pas := 10.0
	var n := int(RAYON / pas)
	var c := (_centre_fait / pas).floor() * pas
	var prof := niveau * H
	var ry := rig.global_position.y if rig != null else 0.0
	var hs := {}
	for i in range(-n, n + 2):
		for j in range(-n, n + 2):
			var x := c.x + i * pas
			var z := c.y + j * pas
			hs[Vector2i(i, j)] = _sol(x, z, ry) - prof
	var a := Color(0.45, 0.33, 0.22, 0.34)
	var b := Color(0.34, 0.25, 0.17, 0.34)
	st.set_normal(Vector3.UP)
	for i in range(-n, n + 1):
		for j in range(-n, n + 1):
			if Vector2(i, j).length() > n:
				continue
			var x := c.x + i * pas
			var z := c.y + j * pas
			st.set_color(a if (i + j) % 2 == 0 else b)
			var p00 := Vector3(x, hs[Vector2i(i, j)], z)
			var p10 := Vector3(x + pas, hs[Vector2i(i + 1, j)], z)
			var p01 := Vector3(x, hs[Vector2i(i, j + 1)], z + pas)
			var p11 := Vector3(x + pas, hs[Vector2i(i + 1, j + 1)], z + pas)
			st.add_vertex(p00)
			st.add_vertex(p10)
			st.add_vertex(p11)
			st.add_vertex(p00)
			st.add_vertex(p11)
			st.add_vertex(p01)
	return st


# --- Réseaux de rue ---------------------------------------------------------------

func _reseau(res: String) -> ReseauBase:
	if res == "telecom":
		return telecom.cuivre if telecom != null else null
	if reseaux == null:
		return null
	match res:
		"elec": return reseaux.elec
		"eau": return reseaux.eau
		"egout": return reseaux.egout
		"gaz": return reseaux.gaz
	return null


## Taux de service de la k-ième route (ordre de Reseaux._routes()) dans un réseau.
## −1 : inconnu (calcul pas encore fait).
static func taux_route(r: ReseauBase, k: int, nb_routes: int) -> float:
	if r == null or not r.suit_routes:
		return -1.0
	var debut := r.lignes.size() - nb_routes
	var li := debut + k
	if debut < 0 or li >= r.lignes_comp.size():
		return -1.0
	return r.taux_composante(r.lignes_comp[li])


static func couleur_service(base: Color, taux: float) -> Color:
	if taux < 0.0 or taux >= 0.99:
		return base
	if taux <= 0.0:
		return GRIS
	return base.lerp(GRIS, 0.5)


func _dessiner_rues(plein: SurfaceTool, repere: SurfaceTool) -> void:
	if transport == null or transport.network == null:
		return
	var nb_routes := 0
	for eid in transport.network.edges:
		if TransportTypes.mode_of(String(transport.network.edges[eid].t)) == TransportTypes.Mode.ROAD:
			nb_routes += 1
	var k := -1
	for eid in transport.network.edges:
		var e: Dictionary = transport.network.edges[eid]
		var mode := TransportTypes.mode_of(String(e.t))
		var pts: PackedVector3Array = e.pts
		if mode == TransportTypes.Mode.ROAD:
			k += 1
		var proche := false
		for p in pts:
			if _proche(p):
				proche = true
				break
		if not proche:
			continue
		var w := TransportTypes.width_of(String(e.t), e.get("w", {}))
		# Repère de surface : le ruban de la voie, à peine visible.
		if mode != TransportTypes.Mode.WATER and not _souterraine(e):
			_ruban(repere, pts, w, Color(1, 1, 1, 0.16), 0.08)
		if mode != TransportTypes.Mode.ROAD or not visible_au(niveau, 3.0):
			continue
		compte.rues += 1
		var simple := _simplifier(pts)
		for spec in RUE:
			var res: String = spec.res
			var col := couleur_service(COULEURS[res], taux_route(_reseau(res), k, nb_routes))
			var dx := float(spec.dx) * w
			_tuyau_long(plein, _decaler(simple, dx, -float(spec.d)), float(spec.s) * LOUPE, col)


func _souterraine(e: Dictionary) -> bool:
	return float(TransportTypes.get_type(String(e.t)).get("underground", 0.0)) > 0.0


## Garde un point sur trois environ (et ceux des virages) : les tuyaux restent légers.
static func _simplifier(pts: PackedVector3Array) -> PackedVector3Array:
	if pts.size() <= 2:
		return pts
	var out := PackedVector3Array([pts[0]])
	var last := pts[0]
	for i in range(1, pts.size() - 1):
		var p := pts[i]
		var dir_a := (p - last).normalized()
		var dir_b := (pts[i + 1] - p).normalized()
		if last.distance_to(p) >= 8.0 or dir_a.dot(dir_b) < 0.995:
			out.append(p)
			last = p
	out.append(pts[pts.size() - 1])
	return out


## Décale un tracé sur le côté (dx, à droite du sens de marche) et en hauteur (dy).
static func _decaler(pts: PackedVector3Array, dx: float, dy: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	out.resize(pts.size())
	for i in pts.size():
		var a := pts[maxi(i - 1, 0)]
		var b := pts[mini(i + 1, pts.size() - 1)]
		var t := Vector3(b.x - a.x, 0, b.z - a.z)
		var side := Vector3(-t.z, 0, t.x).normalized() if t.length() > 0.001 else Vector3.RIGHT
		out[i] = pts[i] + side * dx + Vector3(0, dy, 0)
	return out


# --- Gros tronçons ----------------------------------------------------------------

func _dessiner_troncons(plein: SurfaceTool) -> void:
	var sources := []
	if reseaux != null:
		for r in reseaux.tous():
			sources.append(r)
	if telecom != null:
		sources.append(telecom.fibre)
		sources.append(telecom.cuivre)
	for r in sources:
		var rb := r as ReseauBase
		for id in rb.troncons:
			var t: Dictionary = rb.troncons[id]
			var tid := String(t.t)
			var spec: Dictionary = TRONCONS.get(tid, TRONCONS.get(rb.kind, {}))
			if spec.is_empty() or (tid.begins_with("ligne_")):
				continue
			# Profondeur choisie à la pose depuis la vue (ConstructionSouterraine), sinon celle du type.
			var prof := float(t.get("prof", spec.d))
			if not visible_au(niveau, prof + float(spec.s) / 2.0):
				continue
			var pts: PackedVector3Array = t.pts
			var proche := false
			for p in pts:
				if _proche(p):
					proche = true
					break
			if not proche:
				continue
			var col: Color = COULEURS[String(spec.res)]
			if t.get("hs", false):
				col = PANNE
			elif not t.get("ok", true):
				col = col.lerp(Color.WHITE, 0.55)
			compte.troncons += 1
			_tuyau_long(plein, _decaler(_simplifier(pts), 0.0, -prof), float(spec.s) * LOUPE, col)


# --- Branchements des bâtiments ---------------------------------------------------

func _dessiner_branchements(plein: SurfaceTool) -> void:
	if buildings == null or reseaux == null or not visible_au(niveau, 2.0):
		return
	var routes: Array = reseaux._routes()
	for bid in buildings.buildings:
		var b: Dictionary = buildings.buildings[bid]
		var rect: Rect2i = buildings._rect_of(b)
		var c3 := BuildingSystem.rect_center(rect)
		if not _proche(c3):
			continue
		var c := Vector2(c3.x, c3.z)
		var cible := _point_route(routes, c, 30.0 + Vector2(rect.size).length() / 2.0)
		if cible == Vector3.INF:
			continue
		var y0 := _sol(c.x, c.y, cible.y)
		var dir := Vector2(cible.x, cible.z) - c
		if dir.length() < 0.5:
			continue
		# Départ au bord du bâtiment, côté rue.
		var demi := Vector2(rect.size) / 2.0
		var f := minf(demi.x / maxf(absf(dir.x), 0.001), demi.y / maxf(absf(dir.y), 0.001))
		var bord := c + dir * minf(f, 1.0)
		var n := Vector2(-dir.y, dir.x).normalized()
		var fait := false
		for spec in RUE:
			var res: String = spec.res
			var r := _reseau(res)
			if r == null or not r.consos.has(bid):
				continue
			var col: Color = COULEURS[res] if r.est_raccorde(bid) else GRIS
			if r.est_raccorde(bid) and r.taux_servi(bid) <= 0.0:
				col = col.lerp(GRIS, 0.6)
			var o := n * float(spec.dx) * 2.0
			var d := float(spec.d)
			# L'égout descend en pente vers celui de la rue.
			var a := Vector3(bord.x + o.x, y0 - minf(d, 1.2), bord.y + o.y)
			var z := Vector3(cible.x + o.x, cible.y - d, cible.z + o.y)
			_tuyau(plein, a, z, minf(float(spec.s), 0.18) * LOUPE, col)
			fait = true
		if fait:
			compte.branchements += 1


## Point le plus proche sur les routes (à moins de r mètres), ou Vector3.INF.
static func _point_route(routes: Array, c: Vector2, r: float) -> Vector3:
	var best := Vector3.INF
	var best_d := r
	for pts in routes:
		var pp: PackedVector3Array = pts
		for i in range(pp.size() - 1):
			var a := pp[i]
			var b := pp[i + 1]
			if absf(a.x - c.x) > r + 20.0 and absf(b.x - c.x) > r + 20.0:
				continue
			if absf(a.z - c.y) > r + 20.0 and absf(b.z - c.y) > r + 20.0:
				continue
			var a2 := Vector2(a.x, a.z)
			var ab := Vector2(b.x, b.z) - a2
			var t := 0.0 if ab.length_squared() < 0.0001 else clampf((c - a2).dot(ab) / ab.length_squared(), 0.0, 1.0)
			var q := a2 + ab * t
			var d := q.distance_to(c)
			if d < best_d:
				best_d = d
				best = a.lerp(b, t)
	return best


# --- Tunnels et métro ---------------------------------------------------------------

func _dessiner_tunnels(plein: SurfaceTool, verre: SurfaceTool) -> void:
	if transport == null or transport.network == null:
		return
	for eid in transport.network.edges:
		var e: Dictionary = transport.network.edges[eid]
		var pts: PackedVector3Array = e.pts
		var st: PackedByteArray = e.st
		var metro := _souterraine(e)
		var mode := TransportTypes.mode_of(String(e.t))
		var w := TransportTypes.width_of(String(e.t), e.get("w", {})) + 1.5
		var haut := 6.5 if mode == TransportTypes.Mode.ROAD else 7.0
		var col := METRO if metro else TUNNEL
		var fait := false
		for i in range(pts.size() - 1):
			if not metro and (st[i] != TransportTypes.Struct.TUNNEL or st[i + 1] != TransportTypes.Struct.TUNNEL):
				continue
			var a := pts[i]
			var b := pts[i + 1]
			if not _proche(a) and not _proche(b):
				continue
			var fond := maxf(_sol(a.x, a.z, a.y) - a.y, _sol(b.x, b.z, b.y) - b.y) + 0.6
			if fond < haut * 0.5 or not visible_au(niveau, fond):
				continue
			var up := Vector3(0, haut / 2.0 - 0.4, 0)
			_boite_seg(verre, a + up, b + up, w, haut, col)
			# Chaussée ou voies au fond du tube, bien visibles.
			_boite_seg(plein, a + Vector3(0, -0.2, 0), b + Vector3(0, -0.2, 0), w - 1.5, 0.3,
				Color(0.2, 0.2, 0.22) if mode == TransportTypes.Mode.ROAD else Color(0.42, 0.36, 0.3))
			fait = true
		if fait:
			compte.tunnels += 1
	if transport.stations == null:
		return
	for sid in transport.stations.stations:
		var s: Dictionary = transport.stations.stations[sid]
		if String(s.type) != "station_metro":
			continue
		var p: Vector3 = s.pos
		if not _proche(p):
			continue
		var sol := _sol(p.x, p.z, p.y)
		var voie := p.y if p.y < sol - 3.0 else sol - float(TransportTypes.get_type("metro").get("underground", 14.0))
		if not visible_au(niveau, sol - voie + 1.0):
			continue
		var d: Vector3 = s.get("dir", Vector3.RIGHT)
		d = Vector3(d.x, 0, d.z).normalized() if Vector3(d.x, 0, d.z).length() > 0.01 else Vector3.RIGHT
		var len := float(StationSystem.TYPES.get("station_metro", {}).get("len", 80.0))
		var c := Vector3(p.x, voie + 3.5, p.z)
		_boite_seg(verre, c - d * len / 2.0, c + d * len / 2.0, 16.0, 8.0, Color(0.85, 0.82, 0.7, 0.45))
		# Quais (béton clair) des deux côtés des voies.
		for cote in [-1.0, 1.0]:
			var o: Vector3 = Vector3(-d.z, 0, d.x) * 5.6 * float(cote)
			_boite_seg(plein, c + o - d * len / 2.0 + Vector3(0, -2.6, 0), c + o + d * len / 2.0 + Vector3(0, -2.6, 0),
				4.0, 1.0, Color(0.86, 0.84, 0.78))
		# Accès : escalier jusqu'à la bouche de métro.
		var acces := Vector3(p.x, 0, p.z) + Vector3(-d.z, 0, d.x) * 10.0
		_boite_seg(verre, Vector3(acces.x, voie + 7.0, acces.z), Vector3(acces.x, sol, acces.z), 4.0, 4.0,
			Color(0.95, 0.85, 0.4, 0.55))
		compte.stations += 1


# --- Sous-sols -----------------------------------------------------------------------

func _dessiner_sous_sols(plein: SurfaceTool, verre: SurfaceTool, repere: SurfaceTool) -> void:
	if buildings == null:
		return
	for bid in buildings.buildings:
		var b: Dictionary = buildings.buildings[bid]
		var rect: Rect2i = buildings._rect_of(b)
		var c3 := BuildingSystem.rect_center(rect)
		if not _proche(c3):
			continue
		var y0 := _sol(c3.x, c3.z, rig.global_position.y if rig != null else 0.0)
		var r := Rect2(Vector2(rect.position), Vector2(rect.size))
		_contour(repere, r, y0 + 0.1, Color(1, 1, 1, 0.3))
		var nb := sous_sols_de(String(b.t), b)
		if nb <= 0 or not visible_au(niveau, nb * H):
			continue
		var col := PARKING if est_parking(String(b.t)) else CAVE
		var marge := 0.6
		var rr := r.grow(-marge) if r.size.x > 2.0 * marge + 1.0 and r.size.y > 2.0 * marge + 1.0 else r
		for k in range(1, nb + 1):
			if k < niveau:
				continue
			var haut := y0 - (k - 1) * H
			var bas := y0 - k * H
			_boite_rect(verre, rr, bas + 0.25, haut - 0.05, col)
			# Dalle du sol, opaque.
			_boite_rect(plein, rr, bas, bas + 0.25, Color(0.62, 0.6, 0.56))
			if col == PARKING:
				_places(plein, rr, bas + 0.27)
		compte.sous_sols += 1


## Lignes blanches de places de parking (2,5 m) le long du grand côté.
func _places(st: SurfaceTool, r: Rect2, y: float) -> void:
	var long_x := r.size.x >= r.size.y
	var lng := r.size.x if long_x else r.size.y
	var n := int(lng / 2.5)
	for i in range(1, n):
		var t := i * 2.5
		if long_x:
			_boite_rect(st, Rect2(r.position.x + t, r.position.y + 0.5, 0.15, minf(5.0, r.size.y / 2.0 - 0.5)), y, y + 0.02, Color(0.95, 0.95, 0.95))
		else:
			_boite_rect(st, Rect2(r.position.x + 0.5, r.position.y + t, minf(5.0, r.size.x / 2.0 - 0.5), 0.15), y, y + 0.02, Color(0.95, 0.95, 0.95))


## Sous-sols des bâtiments de l'Atelier : leurs étages négatifs passent sur la
## couche de la vue (−1 au niveau 1, −2 au niveau 2…), les autres restent cachés.
func _marquer_plans() -> void:
	_demarquer_plans()
	if plans == null or not actif:
		return
	var n_plans := 0
	for id in plans._nodes:
		var marque := false
		for e in plans._nodes[id]:
			if int(e) >= 0 or -int(e) < niveau:
				continue
			var nd: Node = plans._nodes[id][e]
			if not is_instance_valid(nd):
				continue
			if nd is Node3D and not _proche((nd as Node3D).global_position) and not _plan_proche(String(id)):
				continue
			_marquer(nd)
			marque = true
		if marque:
			n_plans += 1
	compte.plans = n_plans


func _plan_proche(id: String) -> bool:
	if not plans._bbox.has(id):
		return false
	var bb: Rect2i = plans._bbox[id]
	var m := Vector2(bb.position) + Vector2(bb.size) / 2.0
	return m.distance_to(_centre_fait) <= RAYON + Vector2(bb.size).length() / 2.0


func _marquer(nd: Node) -> void:
	if nd is VisualInstance3D:
		var vi := nd as VisualInstance3D
		if vi.layers & COUCHE == 0:
			vi.layers |= COUCHE
			_plans_marques.append(vi)
	for ch in nd.get_children():
		_marquer(ch)


func _demarquer_plans() -> void:
	for vi in _plans_marques:
		if is_instance_valid(vi):
			(vi as VisualInstance3D).layers &= ~COUCHE
	_plans_marques.clear()


# --- Géométrie ------------------------------------------------------------------------

## Tuyau (section carrée, esprit low-poly) le long d'un tracé.
static func _tuyau_long(st: SurfaceTool, pts: PackedVector3Array, s: float, col: Color) -> void:
	for i in range(pts.size() - 1):
		_tuyau(st, pts[i], pts[i + 1], s, col)


static func _tuyau(st: SurfaceTool, a: Vector3, b: Vector3, s: float, col: Color) -> void:
	_boite_seg(st, a, b, s, s, col)


## Boîte de section w × h (largeur à plat, hauteur verticale) de a à b.
static func _boite_seg(st: SurfaceTool, a: Vector3, b: Vector3, w: float, h: float, col: Color) -> void:
	var f := b - a
	var lng := f.length()
	if lng < 0.01:
		return
	f /= lng
	var droite := Vector3(-f.z, 0, f.x)
	if droite.length() < 0.01:
		droite = Vector3.RIGHT
	droite = droite.normalized()
	var haut := droite.cross(f).normalized()
	if haut.y < 0.0:
		haut = -haut
	var rx := droite * w / 2.0
	var ry := haut * h / 2.0
	var c := [a - rx - ry, a + rx - ry, a + rx + ry, a - rx + ry,
		b - rx - ry, b + rx - ry, b + rx + ry, b - rx + ry]
	st.set_color(col)
	_face(st, c[0], c[1], c[5], c[4], -haut)
	_face(st, c[3], c[7], c[6], c[2], haut)
	_face(st, c[1], c[2], c[6], c[5], droite)
	_face(st, c[0], c[4], c[7], c[3], -droite)
	_face(st, c[0], c[3], c[2], c[1], -f)
	_face(st, c[4], c[5], c[6], c[7], f)


## Boîte droite posée sur un rectangle (x, z), de y0 à y1.
static func _boite_rect(st: SurfaceTool, r: Rect2, y0: float, y1: float, col: Color) -> void:
	var x0 := r.position.x
	var x1 := r.end.x
	var z0 := r.position.y
	var z1 := r.end.y
	var c := [Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x0, y0, z1),
		Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(x0, y1, z1)]
	st.set_color(col)
	_face(st, c[0], c[3], c[2], c[1], Vector3.DOWN)
	_face(st, c[4], c[5], c[6], c[7], Vector3.UP)
	_face(st, c[0], c[1], c[5], c[4], Vector3.BACK)
	_face(st, c[2], c[3], c[7], c[6], Vector3.FORWARD)
	_face(st, c[1], c[2], c[6], c[5], Vector3.RIGHT)
	_face(st, c[3], c[0], c[4], c[7], Vector3.LEFT)


static func _face(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	st.set_normal(n)
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(d)


## Ruban plat (repère de surface d'une voie).
static func _ruban(st: SurfaceTool, pts: PackedVector3Array, w: float, col: Color, dy: float) -> void:
	st.set_color(col)
	st.set_normal(Vector3.UP)
	var sp := _simplifier(pts)
	for i in range(sp.size() - 1):
		var a := sp[i] + Vector3(0, dy, 0)
		var b := sp[i + 1] + Vector3(0, dy, 0)
		var f := b - a
		var s := Vector3(-f.z, 0, f.x).normalized() * w / 2.0
		if s.length() < 0.001:
			continue
		st.add_vertex(a - s)
		st.add_vertex(a + s)
		st.add_vertex(b + s)
		st.add_vertex(a - s)
		st.add_vertex(b + s)
		st.add_vertex(b - s)


## Contour d'un rectangle au sol (repère d'un bâtiment).
static func _contour(st: SurfaceTool, r: Rect2, y: float, col: Color) -> void:
	var e := 0.35
	_boite_rect(st, Rect2(r.position.x, r.position.y, r.size.x, e), y, y + 0.05, col)
	_boite_rect(st, Rect2(r.position.x, r.end.y - e, r.size.x, e), y, y + 0.05, col)
	_boite_rect(st, Rect2(r.position.x, r.position.y + e, e, r.size.y - 2 * e), y, y + 0.05, col)
	_boite_rect(st, Rect2(r.end.x - e, r.position.y + e, e, r.size.y - 2 * e), y, y + 0.05, col)


# --- Interface ---------------------------------------------------------------------

func _construire_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 6
	add_child(_ui)
	_box = PanelContainer.new()
	_box.add_theme_stylebox_override("panel", UiStyle.panel_box(0.9, 10, 6))
	# En bas, au-dessus de la barre des menus : les messages restent lisibles en haut.
	_box.anchor_left = 0.5
	_box.anchor_right = 0.5
	_box.anchor_top = 1.0
	_box.anchor_bottom = 1.0
	_box.offset_bottom = -120
	_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_box.visible = false
	_ui.add_child(_box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	_box.add_child(col)
	_colonne = col
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	var down := _btn("▼", "Niveau du dessous (Page bas)")
	down.pressed.connect(func() -> void: step(-1))
	row.add_child(down)
	_label = Label.new()
	_label.custom_minimum_size = Vector2(300, 0)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_label)
	var up := _btn("▲", "Niveau du dessus (Page haut)")
	up.pressed.connect(func() -> void: step(1))
	row.add_child(up)
	var surf := _btn("Retour en surface", "Revenir à la surface (Origine ou Échap)")
	surf.pressed.connect(func() -> void: sortir())
	row.add_child(surf)
	var leg := HBoxContainer.new()
	leg.add_theme_constant_override("separation", 10)
	leg.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(leg)
	for it in LEGENDE:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 3)
		var sw := ColorRect.new()
		sw.custom_minimum_size = Vector2(12, 12)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sw.color = _couleur_legende(String(it[1]))
		h.add_child(sw)
		var l := Label.new()
		l.text = String(it[0])
		l.add_theme_font_size_override("font_size", 13)
		h.add_child(l)
		leg.add_child(h)


static func _couleur_legende(k: String) -> Color:
	match k:
		"metro": return Color(METRO, 1.0)
		"tunnel": return Color(TUNNEL, 1.0)
		"cave": return Color(CAVE, 1.0)
	return COULEURS.get(k, GRIS)


## Branche les outils de construction : leur barre s'ajoute sous la légende.
func brancher_construction(c: ConstructionSouterraine) -> void:
	construction = c
	c.vue = self
	add_child(c)
	c.construire_barre(_colonne)


func _btn(text: String, tip: String) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	return b
