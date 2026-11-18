class_name MarqueursChantiers
extends Node3D
## Petits marqueurs au-dessus des chantiers, à la place des longs textes
## flottants (nom, étape, matériaux, équipe, date de fin) :
##
## - une icône ronde (cône de chantier, agrandissement ou rénovation) entourée
##   d'un anneau jaune qui se remplit avec l'avancement ;
## - une petite pastille d'état en bas à droite, seulement si le chantier
##   n'avance pas normalement : équipe au repos (lune), caisse vide (pièce,
##   rouge), pas d'ouvriers ou équipe incomplète (casque, orange), pause (‖).
## - Au survol : petite carte avec tout le détail (nom, étape, barre
##   d'avancement, état, matériaux, date de fin). Au clic, la carte reste
##   épinglée au-dessus du chantier (Échap ou clic ailleurs pour la fermer) ;
##   pour un agrandissement ou une rénovation, le clic ouvre la fiche du bâtiment.
## - Les marqueurs gardent à peu près la même taille à l'écran et s'effacent
##   au loin (BatimentsVie.VUE_PANNEAU) ; pas de marqueurs sur les photos (F8).
## - Option : Options → Jeu → « Marqueurs des chantiers » (OptionsJeu.marqueurs_chantiers).
## - Rendu comme les icônes des bâtiments non raccordés (Raccordements) : un seul
##   MultiMesh et un shader billboard ; la liste est refaite 4 fois par seconde.

const CASE := 128
const ANNEAU := Color("ffd166")
const FOND := Color("26332f")
## Pastilles d'état : statut -> [colonne de l'atlas (ligne 1), couleur du fond].
const PASTILLES := {
	"repos": [0, Color("51607e")],
	"argent": [1, Color("d62839")],
	"sans_ouvriers": [2, Color("f08c2e")],
	"equipe": [2, Color("f0b02e")],
	"pause": [3, Color("6c7471")],
}
## Icônes principales (ligne 0) : chantier, agrandissement, rénovation.
const GENRES := {"chantier": 0, "niv": 1, "renov": 2}
## Taille à l'écran : mètres par mètre de distance, bornée.
const K_TAILLE := 0.03
const TAILLE_MIN := 1.6
const TAILLE_MAX := 40.0

const PICTOS := [
	# Ligne 0 : cône de chantier, immeuble + flèche, rouleau de peinture.
	["<path d=\"M10.2 3h3.6l5.4 15H4.8Z\" fill=\"#f5a623\"/><path d=\"M8.6 9.2h6.8l1 2.8H7.6ZM6.6 14.6h10.8l1 2.8H5.6Z\" fill=\"#fff\"/><rect x=\"3\" y=\"18\" width=\"18\" height=\"3\" rx=\"1\" fill=\"#f5a623\"/>",
	"<path d=\"M4 21V11h9v10Z\" fill=\"#fff\"/><path d=\"M6 13h2v2H6Zm3 0h2v2H9Zm-3 4h2v2H6Zm3 0h2v2H9Z\" fill=\"#26332f\"/><path d=\"M17.5 21V6M14 9.5l3.5-3.5L21 9.5\" fill=\"none\" stroke=\"#ffd166\" stroke-width=\"2.4\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/>",
	"<rect x=\"4\" y=\"3.5\" width=\"14\" height=\"6\" rx=\"1.5\" fill=\"#ffd166\"/><path d=\"M18 6.5h2v5.5h-8.5v3\" fill=\"none\" stroke=\"#fff\" stroke-width=\"1.8\" stroke-linejoin=\"round\"/><rect x=\"10\" y=\"14.5\" width=\"3\" height=\"7\" rx=\"1\" fill=\"#fff\"/>",
	""],
	# Ligne 1 : lune (repos), pièce (argent), casque (ouvriers), pause.
	["<path d=\"M15.5 3.5a8.5 8.5 0 1 0 5 13.6A7 7 0 0 1 15.5 3.5Z\" fill=\"#fff\"/>",
	"<circle cx=\"12\" cy=\"12\" r=\"7.5\" fill=\"none\" stroke=\"#fff\" stroke-width=\"2.2\"/><path d=\"M14.5 8.8a3.6 3.6 0 1 0 0 6.4M7.8 11h5M7.8 13.2h5\" fill=\"none\" stroke=\"#fff\" stroke-width=\"1.7\" stroke-linecap=\"round\"/><path d=\"M4 20 20 4\" stroke=\"#fff\" stroke-width=\"2.2\" stroke-linecap=\"round\"/>",
	"<path d=\"M4 16a8 8 0 0 1 16 0Z\" fill=\"#fff\"/><path d=\"M11 6.5h2V12h-2Z\" fill=\"#000\" fill-opacity=\".25\"/><rect x=\"2.5\" y=\"15.5\" width=\"19\" height=\"3\" rx=\"1.2\" fill=\"#fff\"/>",
	"<rect x=\"6.5\" y=\"5\" width=\"4\" height=\"14\" rx=\"1\" fill=\"#fff\"/><rect x=\"13.5\" y=\"5\" width=\"4\" height=\"14\" rx=\"1\" fill=\"#fff\"/>"],
]

const SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, skip_vertex_transform, shadows_disabled;
uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 anneau : source_color = vec4(1.0, 0.82, 0.4, 1.0);
uniform float k_taille = 0.03;
uniform float taille_min = 1.6;
uniform float taille_max = 40.0;
uniform float distance_max = 650.0;
varying vec2 cellule;
varying float avance;
varying float pastille;
varying float fondu;

void vertex() {
	vec3 centre = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float d = length(CAMERA_POSITION_WORLD - centre);
	float s = clamp(d * k_taille, taille_min, taille_max);
	pastille = INSTANCE_CUSTOM.w;
	fondu = 1.0 - smoothstep(distance_max * 0.75, distance_max, d);
	vec3 droite = normalize(INV_VIEW_MATRIX[0].xyz);
	vec3 haut = normalize(INV_VIEW_MATRIX[1].xyz);
	vec3 p = centre + vec3(0.0, s * 0.6, 0.0);
	float t = s;
	if (pastille > 0.5) {
		// Petite pastille d'état, en bas à droite de l'icône.
		p += droite * (s * 0.36) - haut * (s * 0.3);
		t = s * 0.48;
	}
	if (d > distance_max) {
		t = 0.0;
	}
	p += (droite * VERTEX.x + haut * VERTEX.y) * t;
	VERTEX = (VIEW_MATRIX * vec4(p, 1.0)).xyz;
	NORMAL = vec3(0.0, 0.0, 1.0);
	cellule = INSTANCE_CUSTOM.xy;
	avance = INSTANCE_CUSTOM.z;
}

void fragment() {
	vec2 uv = UV - vec2(0.5);
	float r = length(uv) * 2.0;
	vec4 c;
	if (pastille > 0.5) {
		c = texture(atlas, (cellule + UV) / vec2(4.0, 2.0));
	} else {
		float aa = fwidth(r) * 1.2;
		// Anneau d'avancement (rempli dans le sens des aiguilles d'une montre depuis le haut).
		float a = atan(uv.x, -uv.y) / 6.2831853;
		a = a < 0.0 ? a + 1.0 : a;
		float dans_anneau = smoothstep(0.74 - aa, 0.74, r) * (1.0 - smoothstep(0.98 - aa, 0.98, r));
		vec4 piste = vec4(0.07, 0.09, 0.08, 0.7);
		vec4 col_anneau = a <= avance ? anneau : piste;
		// Icône au centre (le disque de l'atlas, réduit pour laisser la place à l'anneau).
		vec2 iuv = clamp(uv / 0.74 * 0.5 + vec2(0.5), vec2(0.0), vec2(1.0));
		vec4 ic = texture(atlas, (cellule + iuv) / vec2(4.0, 2.0));
		ic.a *= 1.0 - smoothstep(0.74 - aa, 0.74, r);
		c = mix(ic, col_anneau, dans_anneau);
		c.a = max(ic.a, dans_anneau * col_anneau.a);
	}
	ALBEDO = c.rgb;
	ALPHA = c.a * fondu;
}
"""

var vie: BatimentsVie
## Masqués par le code (tests, mode photo…) ; le joueur a OptionsJeu.marqueurs_chantiers.
var montrer := true
## Marqueurs affichés : [{bid, genre ("chantier", "niv", "renov"), pos, av, statut}].
var marqueurs: Array = []
## Bâtiment sous la souris (-1 : aucun).
var survol := -1

var _mm: MultiMeshInstance3D
var _mat: ShaderMaterial
var _acc := 10.0
var _bulle: PanelContainer
var _bulle_titre: Label
var _bulle_barre: ProgressBar
var _bulle_pc: Label
var _bulle_etat_ic: TextureRect
var _bulle_txt: Label
var _bulle_aide: Label
## Chantier dont la carte est épinglée (clic sur le marqueur), -1 sinon.
var epingle := -1
var _calque: CanvasLayer
var _appui := Vector2(-1000, -1000)

static var _atlas: ImageTexture


func _ready() -> void:
	name = "MarqueursChantiers"
	_mm = MultiMeshInstance3D.new()
	_mm.name = "Marqueurs"
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
	_mat.set_shader_parameter("anneau", ANNEAU)
	_mat.set_shader_parameter("k_taille", K_TAILLE)
	_mat.set_shader_parameter("taille_min", TAILLE_MIN)
	_mat.set_shader_parameter("taille_max", TAILLE_MAX)
	_mat.set_shader_parameter("distance_max", BatimentsVie.VUE_PANNEAU)
	_mat.render_priority = 1
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
	_bulle_titre = _etiquette(14, UiStyle.ACCENT)
	col.add_child(_bulle_titre)
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", 8)
	ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bulle_barre = ProgressBar.new()
	_bulle_barre.max_value = 1.0
	_bulle_barre.step = 0.001
	_bulle_barre.show_percentage = false
	_bulle_barre.custom_minimum_size = Vector2(180, 9)
	_bulle_barre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bulle_barre.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bulle_barre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bulle_barre.add_theme_stylebox_override("background", UiStyle.flat_box(Color(1, 1, 1, 0.12), 5, 0))
	_bulle_barre.add_theme_stylebox_override("fill", UiStyle.flat_box(ANNEAU, 5, 0))
	ligne.add_child(_bulle_barre)
	_bulle_pc = _etiquette(13, UiStyle.TEXT)
	ligne.add_child(_bulle_pc)
	col.add_child(ligne)
	var etat := HBoxContainer.new()
	etat.add_theme_constant_override("separation", 6)
	etat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bulle_etat_ic = TextureRect.new()
	_bulle_etat_ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_bulle_etat_ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	etat.add_child(_bulle_etat_ic)
	_bulle_txt = _etiquette(13, UiStyle.TEXT)
	_bulle_txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bulle_txt.custom_minimum_size = Vector2(250, 0)
	etat.add_child(_bulle_txt)
	col.add_child(etat)
	_bulle_aide = _etiquette(11, UiStyle.TEXT_DIM)
	col.add_child(_bulle_aide)
	_calque.add_child(_bulle)


static func _etiquette(taille: int, couleur: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Atlas 4 × 2 : ligne 0 les icônes (disque sombre), ligne 1 les pastilles d'état.
static func atlas() -> ImageTexture:
	if _atlas != null:
		return _atlas
	var img := Image.create(CASE * 4, CASE * 2, false, Image.FORMAT_RGBA8)
	var fonds := [[FOND, FOND, FOND, FOND], [PASTILLES.repos[1], PASTILLES.argent[1], PASTILLES.sans_ouvriers[1], PASTILLES.pause[1]]]
	for row in 2:
		for col in 4:
			var picto: String = PICTOS[row][col]
			if picto == "":
				continue
			var fond: Color = fonds[row][col]
			var svg := "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"32\" height=\"32\" viewBox=\"0 0 32 32\">" \
				+ "<circle cx=\"16\" cy=\"16\" r=\"14.6\" fill=\"#%s\" stroke=\"#fff\" stroke-width=\"%s\"/>" % [fond.to_html(false), "0" if row == 0 else "2.2"] \
				+ "<g transform=\"%s\">%s</g>" % ["translate(7.4 7.4) scale(.72)" if row == 0 else "translate(5.2 5.2) scale(.9)", picto] + "</svg>"
			var ic := Image.new()
			if ic.load_svg_from_string(svg, float(CASE) / 32.0) != OK:
				continue
			ic.convert(Image.FORMAT_RGBA8)
			img.blit_rect(ic, Rect2i(0, 0, mini(ic.get_width(), CASE), mini(ic.get_height(), CASE)), Vector2i(col * CASE, row * CASE))
	img.generate_mipmaps()
	_atlas = ImageTexture.create_from_image(img)
	return _atlas


## Icône seule (pour l'interface) : genre "chantier"/"niv"/"renov" ou statut ("repos", "argent"…).
static func icone(quoi: String, taille := 18) -> Texture2D:
	var a := atlas().get_image()
	var cell := Vector2i(int(GENRES[quoi]), 0) if GENRES.has(quoi) else (Vector2i(int(PASTILLES[quoi][0]), 1) if PASTILLES.has(quoi) else Vector2i(-1, -1))
	if cell.x < 0:
		return null
	var sub := a.get_region(Rect2i(cell.x * CASE, cell.y * CASE, CASE, CASE))
	sub.resize(taille, taille, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(sub)


func _process(delta: float) -> void:
	var ok := montrer and OptionsJeu.marqueurs_chantiers and not _camera_photo()
	_mm.visible = ok
	if not ok:
		_montrer_bulle(-1)
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


## Refait la liste des marqueurs et le MultiMesh.
func maj() -> void:
	marqueurs.clear()
	if vie != null and BatimentsVie.chantiers:
		for bid in vie.chantiers_en_cours():
			var p := vie.haut_du_chantier(bid)
			if p == Vector3.INF:
				continue
			marqueurs.append({"bid": bid, "genre": "chantier", "pos": p, "av": vie.progress(bid), "statut": vie.statut_de(bid)})
	var am := Ameliorations.instance
	if am != null and is_instance_valid(am):
		for bid in am.travaux_en_cours():
			var e := am.etat_travaux(bid)
			var p := am.haut_des_travaux(bid)
			if e.is_empty() or p == Vector3.INF:
				continue
			marqueurs.append({"bid": bid, "genre": String(e[0]), "pos": p, "av": float(e[1]), "statut": String(e[2])})
	_dessiner()


func _dessiner() -> void:
	var mm := _mm.multimesh
	var n := 0
	for m in marqueurs:
		n += 2 if String(m.statut) != "" else 1
	mm.instance_count = n
	var i := 0
	for m in marqueurs:
		mm.set_instance_transform(i, Transform3D(Basis(), m.pos))
		mm.set_instance_custom_data(i, Color(float(GENRES.get(String(m.genre), 0)), 0.0, float(m.av), 0.0))
		i += 1
		var st := String(m.statut)
		if st != "":
			mm.set_instance_transform(i, Transform3D(Basis(), m.pos))
			mm.set_instance_custom_data(i, Color(float(PASTILLES[st][0]), 1.0, 0.0, 1.0))
			i += 1


## Taille du marqueur (m) vu de la caméra, comme dans le shader.
static func taille_a(distance: float) -> float:
	return clampf(distance * K_TAILLE, TAILLE_MIN, TAILLE_MAX)


## Marqueur sous ce point de l'écran (bid, -1 si aucun) ; le plus proche de la caméra gagne.
func marqueur_sous(ecran: Vector2) -> int:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null or not _mm.visible:
		return -1
	var best := -1
	var best_d := INF
	var droite := cam.global_transform.basis.x.normalized()
	for m in marqueurs:
		var c: Vector3 = m.pos
		var d := cam.global_position.distance_to(c)
		if d > BatimentsVie.VUE_PANNEAU or cam.is_position_behind(c):
			continue
		var s := taille_a(d)
		var w := c + Vector3(0, s * 0.6, 0)
		var sp := cam.unproject_position(w)
		var rayon := (cam.unproject_position(w + droite * s * 0.5) - sp).length()
		if sp.distance_to(ecran) <= maxf(rayon, 8.0) and d < best_d:
			best_d = d
			best = int(m.bid)
	return best


func _survol(souris: Vector2) -> void:
	var sur_ui := get_viewport().gui_get_hovered_control() != null
	survol = -1 if sur_ui else marqueur_sous(souris)
	if epingle >= 0 and _marqueur(epingle).is_empty():
		epingle = -1
	if survol >= 0:
		_montrer_bulle(survol, souris + Vector2(18, 14))
	elif epingle >= 0:
		_montrer_bulle(epingle, _ecran_de(epingle))
	else:
		_montrer_bulle(-1)


func _marqueur(bid: int) -> Dictionary:
	for m in marqueurs:
		if int(m.bid) == bid:
			return m
	return {}


## Où poser la carte épinglée : à droite du marqueur à l'écran.
func _ecran_de(bid: int) -> Vector2:
	var cam := get_viewport().get_camera_3d()
	var m := _marqueur(bid)
	if cam == null or m.is_empty() or cam.is_position_behind(m.pos):
		return Vector2(-1, -1)
	var s := taille_a(cam.global_position.distance_to(m.pos))
	return cam.unproject_position(m.pos + Vector3(0, s * 0.6, 0)) + Vector2(24, -20)


## Le texte de la carte d'un chantier (ou de travaux d'agrandissement/rénovation) :
## nom et étape sur les deux premières lignes, puis le reste.
func texte_de(bid: int) -> String:
	var t := ""
	if vie != null and vie.chantiers_en_cours().has(bid):
		t = vie.texte_chantier(bid)
	elif Ameliorations.instance != null and is_instance_valid(Ameliorations.instance):
		t = Ameliorations.instance.texte_travaux(bid)
	return t


func _montrer_bulle(bid: int, pos := Vector2.ZERO) -> void:
	if _bulle == null:
		return
	var t := texte_de(bid) if bid >= 0 else ""
	var m := _marqueur(bid)
	if t == "" or m.is_empty() or pos.x < 0.0:
		_bulle.visible = false
		return
	var lignes := t.split("\n")
	var titre := lignes[0]
	if lignes.size() > 1:
		titre += " · " + lignes[1].get_slice(" · ", 0)
	var reste := "\n".join(lignes.slice(2))
	var aide := "Clic : garder ouvert" if bid != epingle else "Échap ou clic ailleurs : fermer"
	if bid == epingle and String(m.genre) != "chantier":
		aide = "Clic : fiche du bâtiment · Échap : fermer"
	elif bid != epingle and String(m.genre) != "chantier":
		aide = "Clic : fiche du bâtiment"
	var cle := "%s|%s|%s|%s|%.3f" % [titre, reste, aide, m.statut, float(m.av)]
	if _bulle.get_meta("cle", "") != cle:
		_bulle.set_meta("cle", cle)
		_bulle_titre.text = titre
		_bulle_barre.value = float(m.av)
		_bulle_pc.text = "%d %%" % floori(float(m.av) * 100.0)
		var st := String(m.statut)
		_bulle_etat_ic.texture = icone(st, 18) if st != "" else icone(String(m.genre), 18)
		_bulle_txt.text = reste
		_bulle_aide.text = aide
		_bulle.reset_size()
	_bulle.visible = true
	var vp := get_viewport().get_visible_rect().size
	pos.x = clampf(pos.x, 8.0, vp.x - _bulle.size.x - 8.0)
	pos.y = clampf(pos.y, 8.0, vp.y - _bulle.size.y - 8.0)
	_bulle.position = pos


## Clic sur un marqueur : la carte reste ouverte (chantier) ou la fiche s'ouvre
## (agrandissement, rénovation : le bâtiment est déjà habité). Avant le clic
## « normal » sur le terrain.
func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and k.physical_keycode == KEY_ESCAPE and epingle >= 0:
		epingle = -1
		_montrer_bulle(-1)
		get_viewport().set_input_as_handled()
		return
	var mb := event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT or not _mm.visible:
		return
	if mb.pressed:
		_appui = mb.position
		return
	# Pas après un glisser (la caméra a bougé).
	if mb.position.distance_to(_appui) > 6.0:
		return
	if get_viewport().gui_get_hovered_control() != null:
		return
	var pop := vie.population if vie != null else null
	if pop != null and pop._tools_busy():
		return
	var bid := marqueur_sous(mb.position)
	if bid < 0:
		# Clic ailleurs : la carte épinglée se ferme, le clic continue son chemin.
		epingle = -1
		return
	var m := _marqueur(bid)
	if String(m.get("genre", "chantier")) != "chantier" and pop != null:
		if not pop.known.has(bid):
			pop._sync_buildings()
		pop.select_building(bid)
		epingle = -1
	else:
		epingle = -1 if epingle == bid else bid
	get_viewport().set_input_as_handled()
