class_name IconesIncidents
extends Node3D
## Petites icônes rondes au-dessus des incidents en cours, à la place des
## longs textes flottants (« Accident · en attente (33 s) ») :
##
## - le pictogramme dit ce qui se passe (voiture accidentée, flamme, croix,
##   bouclier, arbre, eau, pancarte, point d'exclamation) ;
## - la couleur du disque dit où en sont les secours : rouge = personne n'est
##   parti (l'icône pulse), orange = secours en route, vert = secours sur place.
## - Au survol : petite carte avec le détail (lieu, depuis quand, quel service
##   arrive ou travaille, et pourquoi personne ne vient). Au clic, la carte
##   reste épinglée (Échap ou clic ailleurs pour la fermer).
## - Les icônes proches à l'écran se décalent pour ne pas se chevaucher, gardent
##   à peu près la même taille et s'effacent au loin ; rien sur les photos (F8).
## - Même rendu que les marqueurs des chantiers (MarqueursChantiers) et les
##   icônes des bâtiments non raccordés (Raccordements) : un seul MultiMesh et
##   un shader billboard.

const CASE := 128
const COLONNES := 8
const ETATS := 3
## Couleur du disque par état des secours (ligne de l'atlas).
const COULEURS := [Color("d62839"), Color("f08c2e"), Color("2a9d8f")]
const K_TAILLE := 0.028
const TAILLE_MIN := 1.6
const TAILLE_MAX := 36.0
const DISTANCE_MAX := 2500.0
## Pictogramme (colonne de l'atlas) par type d'incident.
const PICTO_DE := {"accident": 0, "incendie": 1, "feu_poubelle": 1, "malaise": 2, "chute": 2, "malades": 2,
	"epidemie": 2, "cambriolage": 3, "arbre": 4, "inondation": 5, "crue": 5, "manifestation": 6}

const PICTOS := [
	"<path d=\"M4.5 16.5 6 11.6A2.2 2.2 0 0 1 8.1 10h7.8a2.2 2.2 0 0 1 2.1 1.6l1.5 4.9V21h-2.6v-1.6H7.1V21H4.5Z\" fill=\"#fff\"/><circle cx=\"8\" cy=\"16.3\" r=\"1.3\" fill=\"#000\" fill-opacity=\".35\"/><circle cx=\"16\" cy=\"16.3\" r=\"1.3\" fill=\"#000\" fill-opacity=\".35\"/><path d=\"M12 2.2v4.2M6.6 3.6l2.1 3.2M17.4 3.6l-2.1 3.2\" stroke=\"#fff\" stroke-width=\"1.9\" stroke-linecap=\"round\"/>",
	"<path d=\"M12 2c1.1 4.2 6.3 6.2 6.3 12.2a6.3 6.3 0 0 1-12.6 0c0-3.1 1.5-5.2 3.1-6.3 0 2.2 1 3.3 2.1 3.3 0-4.2-1-6.3 1.1-9.2Z\" fill=\"#fff\"/>",
	"<path d=\"M9.4 3h5.2v6.4H21v5.2h-6.4V21H9.4v-6.4H3V9.4h6.4Z\" fill=\"#fff\"/>",
	"<path d=\"M12 2 4.2 5v6c0 5.1 3.3 9.4 7.8 11 4.5-1.6 7.8-5.9 7.8-11V5Z\" fill=\"#fff\"/><path d=\"m12 7 1.5 3 3.3.4-2.4 2.3.6 3.3L12 14.4 9 16l.6-3.3-2.4-2.3 3.3-.4Z\" fill=\"#000\" fill-opacity=\".3\"/>",
	"<path d=\"M3.5 18.5 15.5 10\" stroke=\"#fff\" stroke-width=\"2.8\" stroke-linecap=\"round\"/><circle cx=\"17\" cy=\"8.2\" r=\"4.8\" fill=\"#fff\"/><path d=\"M2 21.5h20\" stroke=\"#fff\" stroke-width=\"2\" stroke-linecap=\"round\"/>",
	"<path d=\"M3 8.5c3-2.6 6 2.6 9 0s6 2.6 9 0M3 13.5c3-2.6 6 2.6 9 0s6 2.6 9 0M3 18.5c3-2.6 6 2.6 9 0s6 2.6 9 0\" fill=\"none\" stroke=\"#fff\" stroke-width=\"2.1\" stroke-linecap=\"round\"/>",
	"<rect x=\"4\" y=\"3\" width=\"16\" height=\"10\" rx=\"1.5\" fill=\"#fff\"/><path d=\"M12 13v8.5\" stroke=\"#fff\" stroke-width=\"2.4\" stroke-linecap=\"round\"/>",
	"<path d=\"M12 4v10\" stroke=\"#fff\" stroke-width=\"3.2\" stroke-linecap=\"round\"/><circle cx=\"12\" cy=\"19\" r=\"1.9\" fill=\"#fff\"/>",
]

const SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, skip_vertex_transform, shadows_disabled;
uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform float k_taille = 0.028;
uniform float taille_min = 1.6;
uniform float taille_max = 36.0;
uniform float distance_max = 2500.0;
varying vec2 cellule;
varying float fondu;
varying float pulse;

void vertex() {
	vec3 centre = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float d = length(CAMERA_POSITION_WORLD - centre);
	float s = clamp(d * k_taille, taille_min, taille_max);
	fondu = 1.0 - smoothstep(distance_max * 0.8, distance_max, d);
	pulse = INSTANCE_CUSTOM.w > 0.5 ? 0.5 + 0.5 * sin(TIME * 5.0 + centre.x) : 0.0;
	vec3 droite = normalize(INV_VIEW_MATRIX[0].xyz);
	vec3 haut = normalize(INV_VIEW_MATRIX[1].xyz);
	// Décalage (en largeurs d'icône) pour ne pas recouvrir une icône voisine.
	vec3 p = centre + vec3(0.0, s * 0.6, 0.0) + droite * (INSTANCE_CUSTOM.z * s * 1.1);
	float t = d > distance_max ? 0.0 : s * (1.0 + 0.08 * pulse);
	p += (droite * VERTEX.x + haut * VERTEX.y) * t;
	VERTEX = (VIEW_MATRIX * vec4(p, 1.0)).xyz;
	NORMAL = vec3(0.0, 0.0, 1.0);
	cellule = INSTANCE_CUSTOM.xy;
}

void fragment() {
	vec4 c = texture(atlas, (cellule + UV) / vec2(8.0, 3.0));
	ALBEDO = c.rgb * (1.0 + 0.3 * pulse);
	ALPHA = c.a * fondu;
}
"""

var urg: Urgences
## Masquées par le code (tests, mode photo…).
var montrer := true
## Icônes affichées : [{id, pos, col, etat, decal}].
var icones: Array = []
## Incident sous la souris (0 : aucun ; les ids locaux sont négatifs).
var survol := 0
## Incident dont la carte est épinglée (0 : aucun).
var epingle := 0

var _mm: MultiMeshInstance3D
var _mat: ShaderMaterial
var _acc := 10.0
var _calque: CanvasLayer
var _bulle: PanelContainer
var _bulle_ic: TextureRect
var _bulle_titre: Label
var _bulle_txt: Label
var _bulle_aide: Label
var _appui := Vector2(-1000, -1000)

static var _atlas: ImageTexture


func _ready() -> void:
	name = "IconesIncidents"
	_mm = MultiMeshInstance3D.new()
	_mm.name = "Icones"
	_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mm.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	mm.mesh = q
	_mm.multimesh = mm
	_mm.custom_aabb = AABB(Vector3(-1e6, -1e4, -1e6), Vector3(2e6, 2e4, 2e6))
	add_child(_mm)
	var sh := Shader.new()
	sh.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_mat.set_shader_parameter("atlas", atlas())
	_mat.set_shader_parameter("k_taille", K_TAILLE)
	_mat.set_shader_parameter("taille_min", TAILLE_MIN)
	_mat.set_shader_parameter("taille_max", TAILLE_MAX)
	_mat.set_shader_parameter("distance_max", DISTANCE_MAX)
	_mat.render_priority = 2
	_mm.material_override = _mat
	_calque = CanvasLayer.new()
	_calque.layer = 6
	add_child(_calque)
	_bulle = PanelContainer.new()
	_bulle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bulle.add_theme_stylebox_override("panel", UiStyle.panel_box(0.92, 8, 10))
	_bulle.visible = false
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bulle.add_child(col)
	var tete := HBoxContainer.new()
	tete.add_theme_constant_override("separation", 6)
	tete.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bulle_ic = TextureRect.new()
	_bulle_ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_bulle_ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tete.add_child(_bulle_ic)
	_bulle_titre = _etiquette(14, UiStyle.ACCENT)
	tete.add_child(_bulle_titre)
	col.add_child(tete)
	_bulle_txt = _etiquette(13, UiStyle.TEXT)
	_bulle_txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bulle_txt.custom_minimum_size = Vector2(280, 0)
	col.add_child(_bulle_txt)
	_bulle_aide = _etiquette(11, UiStyle.TEXT_DIM)
	col.add_child(_bulle_aide)
	_calque.add_child(_bulle)


static func _etiquette(taille: int, couleur: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Atlas 8 × 3 : une colonne par pictogramme, une ligne par état des secours.
static func atlas() -> ImageTexture:
	if _atlas != null:
		return _atlas
	var img := Image.create(CASE * COLONNES, CASE * ETATS, false, Image.FORMAT_RGBA8)
	for row in ETATS:
		var fond: Color = COULEURS[row]
		for col in COLONNES:
			var svg := "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"32\" height=\"32\" viewBox=\"0 0 32 32\">" \
				+ "<circle cx=\"16\" cy=\"16\" r=\"14.6\" fill=\"#%s\" stroke=\"#fff\" stroke-width=\"2.2\"/>" % fond.to_html(false) \
				+ "<g transform=\"translate(5.2 5.2) scale(.9)\">%s</g>" % PICTOS[col] + "</svg>"
			var ic := Image.new()
			if ic.load_svg_from_string(svg, float(CASE) / 32.0) != OK:
				continue
			ic.convert(Image.FORMAT_RGBA8)
			img.blit_rect(ic, Rect2i(0, 0, mini(ic.get_width(), CASE), mini(ic.get_height(), CASE)), Vector2i(col * CASE, row * CASE))
	img.generate_mipmaps()
	_atlas = ImageTexture.create_from_image(img)
	return _atlas


## Icône seule (interface) d'un type d'incident et d'un état (0 attente, 1 en route, 2 sur place).
static func icone(type: String, etat := 0, taille := 18) -> Texture2D:
	var a := atlas().get_image()
	var sub := a.get_region(Rect2i(picto(type) * CASE, clampi(etat, 0, ETATS - 1) * CASE, CASE, CASE))
	sub.resize(taille, taille, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(sub)


static func picto(type: String) -> int:
	return int(PICTO_DE.get(type, COLONNES - 1))


## État des secours d'un incident : 0 personne en route, 1 en route, 2 sur place.
static func etat_de(inc: Dictionary) -> int:
	match String(inc.get("state", "")):
		"en_route": return 1
		"sur_place": return 2
	return 0


func _process(delta: float) -> void:
	var ok := montrer and not _camera_photo()
	_mm.visible = ok
	if not ok:
		_montrer_bulle(0)
		return
	_acc += delta
	if _acc >= 0.25:
		_acc = 0.0
		maj()
	_survol(get_viewport().get_mouse_position())


func _camera_photo() -> bool:
	if not is_inside_tree():
		return false
	var cam := get_viewport().get_camera_3d()
	return cam != null and cam.name == "CameraPhoto"


## Point au-dessus des lieux d'un incident.
static func position_de(inc: Dictionary) -> Vector3:
	if inc.has("icone_pos"):
		return inc.icone_pos
	var p: Vector3 = inc.get("scene_pos", inc.get("pos", Vector3.ZERO))
	var pos: Vector3 = inc.get("pos", p)
	# Incident dans un bâtiment (pos est en haut du bâtiment) : au-dessus du
	# toit, pour ne pas cacher les secours devant la porte.
	if pos.y > p.y + 2.0:
		return pos + Vector3(0, 3.0, 0)
	return p + Vector3(0, 3.0, 0)


## Refait la liste des icônes (4 fois par seconde) et le MultiMesh.
func maj() -> void:
	icones.clear()
	if urg == null:
		_mm.multimesh.instance_count = 0
		return
	for id in urg.incidents:
		var inc: Dictionary = urg.incidents[id]
		icones.append({"id": int(id), "pos": position_de(inc), "col": picto(String(inc.type)), "etat": etat_de(inc), "decal": 0.0})
	_ecarter()
	var mm := _mm.multimesh
	mm.instance_count = icones.size()
	for i in icones.size():
		var ic: Dictionary = icones[i]
		mm.set_instance_transform(i, Transform3D(Basis(), ic.pos))
		mm.set_instance_custom_data(i, Color(float(ic.col), float(ic.etat), float(ic.decal), 1.0 if int(ic.etat) == 0 else 0.0))


## Décale à droite les icônes qui en recouvrent une autre à l'écran.
func _ecarter() -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null or icones.size() < 2:
		return
	icones.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return cam.global_position.distance_to(a.pos) < cam.global_position.distance_to(b.pos))
	var poses: Array = []
	var droite := cam.global_transform.basis.x.normalized()
	for ic in icones:
		var p: Vector3 = ic.pos
		if cam.is_position_behind(p):
			continue
		var s := taille_a(cam.global_position.distance_to(p))
		var c := cam.unproject_position(p + Vector3(0, s * 0.6, 0))
		var r := (cam.unproject_position(p + Vector3(0, s * 0.6, 0) + droite * s * 0.5) - c).length()
		# Un pas de décalage (s × 1,1 m) vaut 2,2 rayons à l'écran.
		for k in 6:
			var ici := c + Vector2(float(k) * 2.2 * r, 0)
			var libre := true
			for q in poses:
				if (q[0] as Vector2).distance_to(ici) < float(q[1]) + r:
					libre = false
					break
			if libre or k == 5:
				ic.decal = float(k)
				poses.append([ici, r])
				break


static func taille_a(distance: float) -> float:
	return clampf(distance * K_TAILLE, TAILLE_MIN, TAILLE_MAX)


## Centre de l'icône d'un incident à l'écran et son rayon (pixels), ou {}.
func _ecran(ic: Dictionary) -> Dictionary:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return {}
	var p: Vector3 = ic.pos
	var d := cam.global_position.distance_to(p)
	if d > DISTANCE_MAX or cam.is_position_behind(p):
		return {}
	var s := taille_a(d)
	var droite := cam.global_transform.basis.x.normalized()
	var w := p + Vector3(0, s * 0.6, 0) + droite * (float(ic.decal) * s * 1.1)
	var c := cam.unproject_position(w)
	return {"c": c, "r": (cam.unproject_position(w + droite * s * 0.5) - c).length(), "d": d}


## Incident sous ce point de l'écran (0 si aucun) ; le plus proche de la caméra gagne.
func icone_sous(ecran: Vector2) -> int:
	if not _mm.visible:
		return 0
	var best := 0
	var best_d := INF
	for ic in icones:
		var e := _ecran(ic)
		if e.is_empty():
			continue
		if (e.c as Vector2).distance_to(ecran) <= maxf(float(e.r), 8.0) and float(e.d) < best_d:
			best_d = float(e.d)
			best = int(ic.id)
	return best


func _icone(id: int) -> Dictionary:
	for ic in icones:
		if int(ic.id) == id:
			return ic
	return {}


func _survol(souris: Vector2) -> void:
	var sur_ui := get_viewport().gui_get_hovered_control() != null
	survol = 0 if sur_ui else icone_sous(souris)
	if epingle != 0 and (urg == null or not urg.incidents.has(epingle)):
		epingle = 0
	if survol != 0:
		_montrer_bulle(survol, souris + Vector2(18, 14))
	elif epingle != 0:
		var e := _ecran(_icone(epingle))
		_montrer_bulle(epingle, (e.c as Vector2) + Vector2(24, -20) if not e.is_empty() else Vector2(-1, -1))
	else:
		_montrer_bulle(0)


func _montrer_bulle(id: int, pos := Vector2.ZERO) -> void:
	if _bulle == null:
		return
	if id == 0 or urg == null or not urg.incidents.has(id) or pos.x < 0.0:
		_bulle.visible = false
		return
	var inc: Dictionary = urg.incidents[id]
	var det := urg.detail(inc)
	var aide := "Clic : garder ouvert · U : panneau Urgences" if id != epingle else "Échap ou clic ailleurs : fermer"
	if etat_de(inc) == 0 and id != epingle:
		aide = "Clic : envoyer les secours · U : panneau Urgences"
	var cle := "%s|%s|%s|%d" % [det.titre, det.texte, aide, etat_de(inc)]
	if _bulle.get_meta("cle", "") != cle:
		_bulle.set_meta("cle", cle)
		_bulle_ic.texture = icone(String(inc.type), etat_de(inc), 18)
		_bulle_titre.text = String(det.titre)
		_bulle_txt.text = String(det.texte)
		_bulle_aide.text = aide
		_bulle.reset_size()
	_bulle.visible = true
	var vp := get_viewport().get_visible_rect().size
	pos.x = clampf(pos.x, 8.0, vp.x - _bulle.size.x - 8.0)
	pos.y = clampf(pos.y, 8.0, vp.y - _bulle.size.y - 8.0)
	_bulle.position = pos


## Clic sur une icône : la carte reste ouverte. Avant le clic « normal » sur le terrain.
func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and k.physical_keycode == KEY_ESCAPE and epingle != 0:
		epingle = 0
		_montrer_bulle(0)
		get_viewport().set_input_as_handled()
		return
	var mb := event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT or not _mm.visible:
		return
	if mb.pressed:
		_appui = mb.position
		return
	if mb.position.distance_to(_appui) > 6.0:
		return
	if get_viewport().gui_get_hovered_control() != null:
		return
	var pop := urg.population if urg != null else null
	if pop != null and pop._tools_busy():
		return
	var id := icone_sous(mb.position)
	if id == 0:
		epingle = 0
		return
	# Personne n'est parti : le clic envoie les secours (ou met l'appel en tête de file).
	if urg != null and urg.incidents.has(id) and etat_de(urg.incidents[id]) == 0:
		urg.envoyer(id)
		epingle = id
	else:
		epingle = 0 if epingle == id else id
	get_viewport().set_input_as_handled()
