class_name IsolementBatiment
extends CanvasLayer
## Bâtiment isolé : un clic sur un bâtiment (outil Observer) le met seul en avant.
## - La caméra le cadre (un peu à gauche, la fiche occupe la droite).
## - Le reste de la ville pâlit : un voile gris clair à l'écran, troué autour du
##   bâtiment, et les bâtiments voisins deviennent des fantômes transparents.
## - Les cartes d'information se rangent (AffichagePanneaux.ranger) : il ne reste
##   que la barre du haut, la barre du bas et la fiche du bâtiment.
## - Échap, la croix de la fiche ou un clic ailleurs rétablit tout, caméra comprise.
##   Le bouton « Toute la ville » de la fiche sort aussi, en gardant la fiche.
## Option : Options → Jeu → « Isoler le bâtiment cliqué » (OptionsJeu.isoler_batiment).
## Base de l'entrée dans la gestion d'un bâtiment (mini-jeu façon tycoon) :
## écouter `entree` / `sortie`, ou appeler `entrer(bid)` / `sortir()`.

signal entree(bid: int)
signal sortie(bid: int)

## Bâtiments voisins rendus transparents (mètres autour du bâtiment isolé).
const RAYON_FANTOMES := 320.0
const TRANSPARENCE := 0.82
## Inclinaison de la caméra pendant l'isolement (degrés).
const INCLINAISON := 40.0
## Cartes qui restent : les questions du personnage arrêtent le temps.
const GARDER := ["personnage"]

const SHADER := """
shader_type canvas_item;
uniform sampler2D ecran : hint_screen_texture, filter_linear_mipmap;
// Trou autour du bâtiment : centre (xy) et demi-taille (zw), en coordonnées d'écran 0..1.
uniform vec4 trou = vec4(0.5, 0.5, 0.1, 0.1);
uniform float aspect = 1.7778;
uniform float douceur = 0.06;
uniform float force : hint_range(0.0, 1.0) = 1.0;
void fragment() {
	vec3 c = textureLod(ecran, SCREEN_UV, 0.0).rgb;
	vec2 d = abs(SCREEN_UV - trou.xy) - trou.zw;
	d.x *= aspect;
	float dist = length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0);
	float m = smoothstep(0.0, douceur, dist) * force;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 pale = mix(vec3(l), vec3(0.88, 0.90, 0.93), 0.62);
	COLOR = vec4(mix(c, pale, m), 1.0);
}
"""

var pop: Population
var buildings: BuildingSystem
var rig: Node3D
var affichage: AffichagePanneaux
var panneau: HabitantsPanel
## Callable() -> bool : peut-on isoler maintenant (pas en vue au sol, pas à l'Atelier…) ?
var peut_isoler: Callable

## Bâtiment isolé (-1 : aucun).
var bid := -1
## Le joueur a choisi « Toute la ville » pour ce bâtiment : on ne l'isole plus.
var _refus := -1
var _etat_cam := {}
var _fantomes := {}
var _voile: ColorRect
var _mat: ShaderMaterial
var _force := 0.0


func _init() -> void:
	name = "IsolementBatiment"
	# Sous toute l'interface (barres, fiches), au-dessus du monde 3D.
	layer = -1


func setup(p: Population, b: BuildingSystem, r: Node3D, a: AffichagePanneaux, h: HabitantsPanel) -> void:
	pop = p
	buildings = b
	rig = r
	affichage = a
	panneau = h
	_voile = ColorRect.new()
	_voile.name = "Voile"
	_voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	_voile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	_mat.shader = sh
	_voile.material = _mat
	_voile.visible = false
	add_child(_voile)
	pop.building_selected.connect(_sur_selection)
	buildings.added.connect(func(nb: int) -> void:
		if actif() and nb != bid:
			_fantomer_un(nb))


func actif() -> bool:
	return bid >= 0


func _sur_selection(b: int) -> void:
	if b < 0:
		_refus = -1
		sortir()
	elif b != _refus:
		_refus = -1
		if OptionsJeu.isoler_batiment and _peut():
			entrer(b)
		elif actif():
			sortir()


func _peut() -> bool:
	return not peut_isoler.is_valid() or bool(peut_isoler.call())


## Isole un bâtiment (connu de la population).
func entrer(b: int) -> void:
	if pop == null or not pop.known.has(b):
		return
	if b == bid:
		return
	if not actif():
		_etat_cam = rig.call("etat") if rig != null and rig.has_method("etat") else {}
		if affichage != null:
			affichage.ranger(true, GARDER)
	_defantomer()
	bid = b
	_fantomer()
	_cadrer()
	_marqueur(false)
	_voile.visible = true
	_force = 0.0
	_maj_fiche()
	entree.emit(b)


## Rétablit tout (caméra, ville, cartes). `garder_fiche` : la fiche reste ouverte
## (bouton « Toute la ville »).
func sortir(garder_fiche := true) -> void:
	if not actif():
		return
	var ancien := bid
	bid = -1
	_defantomer()
	_voile.visible = false
	if affichage != null:
		affichage.ranger(false)
	if rig != null and rig.has_method("retablir") and not _etat_cam.is_empty():
		rig.call("retablir", _etat_cam)
	_etat_cam = {}
	if garder_fiche and pop != null and pop.selected() >= 0:
		_marqueur(true)
	elif not garder_fiche and panneau != null and panneau.is_open():
		panneau.set_open(false)
	_maj_fiche()
	sortie.emit(ancien)


## Bouton de la fiche : « Toute la ville » / « Isoler ».
func basculer() -> void:
	if actif():
		_refus = bid
		sortir()
	elif pop != null and pop.selected() >= 0:
		_refus = -1
		entrer(pop.selected())


## Le bouton « Toute la ville » / « Isoler » de la fiche suit l'état.
func _maj_fiche() -> void:
	if panneau != null and panneau.is_open() and panneau.view == "batiment":
		panneau.refresh.call_deferred()


func _process(delta: float) -> void:
	if not actif():
		return
	# La fiche s'est fermée, montre autre chose, ou la vue a changé : on sort.
	if panneau == null or not panneau.is_open() or panneau.view != "batiment" or panneau.view_arg != bid \
			or not pop.known.has(bid) or not _peut():
		sortir()
		return
	_force = minf(_force + delta * 4.0, 1.0)
	_maj_voile()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or k.keycode != KEY_ESCAPE or not actif():
		return
	if affichage != null and affichage.menu_ouvert():
		return
	if pop != null and pop.order_pick >= 0:
		return
	get_viewport().set_input_as_handled()
	sortir(false)


# --- Caméra -------------------------------------------------------------------------

func _cadrer() -> void:
	if rig == null or not rig.has_method("cadrer"):
		return
	var info: Dictionary = pop.known[bid]
	var r: Rect2i = info.rect
	var h := BuildingCatalog.approx_height(String(info.t))
	var taille := maxf(maxf(float(r.size.x), float(r.size.y)), h * 1.2)
	var dist := clampf(taille * 2.3 + 16.0, 20.0, 78.0)
	# La fiche occupe la droite de l'écran : le bâtiment se place un peu à gauche
	# du centre (le pivot glisse vers la droite de la caméra).
	var droite: Vector3 = rig.global_transform.basis.x
	droite.y = 0.0
	droite = droite.normalized()
	var pos: Vector3 = (info.pos as Vector3) + droite * dist * 0.16
	rig.call("cadrer", pos, dist, INCLINAISON)


# --- Voile à l'écran ----------------------------------------------------------------

func _maj_voile() -> void:
	var cam := get_viewport().get_camera_3d()
	var vr := get_viewport().get_visible_rect().size
	if cam == null or vr.x <= 0.0:
		return
	var info: Dictionary = pop.known[bid]
	var r: Rect2i = info.rect
	var h := BuildingCatalog.approx_height(String(info.t)) + 1.0
	var c: Vector3 = info.pos
	var hx := r.size.x * 0.5 + 1.5
	var hz := r.size.y * 0.5 + 1.5
	var mi := buildings.node_of(bid) if buildings != null else null
	var aabb := AABB(Vector3(c.x - hx, c.y - 0.5, c.z - hz), Vector3(hx * 2.0, h + 0.5, hz * 2.0))
	if mi != null and is_instance_valid(mi) and mi.mesh != null:
		aabb = mi.global_transform * mi.mesh.get_aabb()
		aabb = aabb.grow(1.5)
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for i in 8:
		var p := aabb.get_endpoint(i)
		if cam.is_position_behind(p):
			continue
		var s := cam.unproject_position(p)
		mn = mn.min(s)
		mx = mx.max(s)
	if mn.x == INF:
		_mat.set_shader_parameter("force", 0.0)
		return
	var centre := (mn + mx) * 0.5 / vr
	var demi := (mx - mn) * 0.5 / vr + Vector2(18.0, 18.0) / vr
	_mat.set_shader_parameter("trou", Vector4(centre.x, centre.y, demi.x, demi.y))
	_mat.set_shader_parameter("aspect", vr.x / vr.y)
	_mat.set_shader_parameter("force", _force)


# --- Bâtiments voisins en fantômes --------------------------------------------------

func _fantomer() -> void:
	if buildings == null:
		return
	for b in buildings._nodes.keys():
		if int(b) != bid:
			_fantomer_un(int(b))


func _fantomer_un(b: int) -> void:
	var mi := buildings.node_of(b)
	if mi == null or not is_instance_valid(mi) or not pop.known.has(bid):
		return
	var c: Vector3 = pop.known[bid].pos
	if Vector2(mi.global_position.x - c.x, mi.global_position.z - c.z).length() > RAYON_FANTOMES:
		return
	for g in [mi] + mi.find_children("*", "GeometryInstance3D", true, false):
		var gi := g as GeometryInstance3D
		if gi == null or _fantomes.has(gi):
			continue
		_fantomes[gi] = [gi.transparency, gi.cast_shadow]
		gi.transparency = TRANSPARENCE
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _defantomer() -> void:
	for gi in _fantomes.keys():
		if is_instance_valid(gi):
			(gi as GeometryInstance3D).transparency = float(_fantomes[gi][0])
			(gi as GeometryInstance3D).cast_shadow = int(_fantomes[gi][1]) as GeometryInstance3D.ShadowCastingSetting
	_fantomes.clear()


## Nombre de pièces rendues transparentes (tests).
func nb_fantomes() -> int:
	return _fantomes.size()


func _marqueur(on: bool) -> void:
	if pop == null:
		return
	if pop._marker != null:
		pop._marker.visible = on and pop.selected() >= 0
	if pop._marker_label != null:
		pop._marker_label.visible = on and pop.selected() >= 0
