class_name MiniCarte
extends Control
## Mini-carte vue du dessus, en bas à droite de l'écran (mode Gérer, vue de dessus).
##
## - Fond : relief ombré et occupation du sol réelle (forêts, champs, eau, neige),
##   routes, rails et bâtiments, territoires des villages (frontières).
## - Couleurs : reprend le calque en couleur choisi dans Cartes (N) ou la
##   ressource montrée dans Production (P).
## - Alertes : incendies et appels d'urgence, catastrophes en cours, bâtiments
##   non raccordés, chantiers. Clic sur un point : la caméra y va.
## - Carte entre amis : les villes des autres joueurs (voisines) et leurs frontières.
## - Clic ou glisser : déplace la caméra ; molette ou − / + : zoom (1 à 40 km).
## - Ctrl+M ou ▾ : replier / déplier (le choix et le zoom sont gardés).
##
## Performances : le fond est calculé quelques lignes par image, seulement quand
## la caméra sort de la zone déjà calculée ; routes, bâtiments et frontières sont
## dessinés une fois (coordonnées du monde) puis seulement déplacés ; les alertes
## sont relevées une fois par seconde.

signal camera_deplacee(pos: Vector2)

## Côté de la carte (px, base 1600 × 900).
const TAILLE := 196.0
## Largeur montrée (m) à chaque cran de zoom.
const ETENDUES := [1000.0, 2000.0, 4000.0, 8000.0, 16000.0, 40000.0]
const ZOOM_DEFAUT := 2
## Pixels du fond (de côté) ; il couvre FOND_MARGE fois la largeur montrée.
const FOND_PX := 128
const FOND_MARGE := 1.6
## Lignes du fond calculées par image.
const LIGNES_PAR_IMAGE := 3
## Grille du calque en couleur (N, P).
const DONNEES_PX := 48
const PREFS := "user://mini_carte.cfg"

## Couleurs ESA WorldCover (code -> couleur de la carte).
const COULEURS_SOL := {
	10: Color("3f6b3a"), 20: Color("8a9a55"), 30: Color("9cbf6a"), 40: Color("d8cf8a"),
	50: Color("b7a99a"), 60: Color("c9bca0"), 70: Color("f4f7fb"), 80: Color("4f86b8"),
	90: Color("6fa59a"), 95: Color("3f8a6a"), 100: Color("b9c79a"),
}
const COULEUR_EAU := Color("4f86b8")
const COULEUR_INCONNU := Color(0.16, 0.18, 0.17)
const COULEUR_ROUTE := Color(0.96, 0.95, 0.9)
const COULEUR_RAIL := Color(0.25, 0.22, 0.24)
const COULEUR_CHEMIN := Color(0.86, 0.74, 0.55)
const COULEUR_CANAL := Color(0.3, 0.55, 0.85)
const COULEUR_BATIMENT := Color(0.98, 0.86, 0.72)
## Couleur et taille des points d'alerte par genre.
const ALERTES := {
	"incident": {"couleur": Color("ff3b30"), "r": 4.5, "nom": "Appel d'urgence"},
	"catastrophe": {"couleur": Color("ff9f1c"), "r": 5.0, "nom": "Catastrophe"},
	"non_raccorde": {"couleur": Color("d62839"), "r": 1.8, "nom": "Non raccordé"},
	"chantier": {"couleur": Color("ffd166"), "r": 2.0, "nom": "Chantier"},
}
## Événements en cours montrés comme catastrophes.
const CATASTROPHES := ["incendie", "tempete", "epidemie", "crue", "submersion"]

var jeu: Node
var rig: Node3D
var world: TerrainWorld

var zoom := ZOOM_DEFAUT
var replie := false
## Centre de la carte (x, z du monde) : le pivot de la caméra.
var centre := Vector2.ZERO
## Alertes relevées : [{p: Vector2, genre, nom, bid}].
var alertes: Array = []
## Nom du calque en couleur repris (N ou P), "" sans calque.
var calque_nom := ""

var _cadre: PanelContainer
var _titre: Label
var _legende: Label
var _vue: Control
var _monde: Node2D
var _fond: Node2D
var _donnees: Node2D
var _statique: Node2D
var _dessus: Control
var _bouton_replie: Button
var _bouton_ouvrir: Button
var _en_vue := true

# Fond en cours de calcul.
var _fond_tex: ImageTexture
var _fond_rect := Rect2()
var _calcul := {}
var _fond_incomplet := false
var _t_fond := 0.0
# Calque en couleur.
var _donnees_tex: ImageTexture
var _donnees_rect := Rect2()
var _donnees_rects: Array = []
var _donnees_cle := ""
var _t_donnees := 0.0
# Couche statique.
var _statique_sale := true
var _t_statique := 0.0
var _t_alertes := 0.0
var _glisse := false


func _ready() -> void:
	name = "MiniCarte"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	_lire_prefs()
	_construire()
	_appliquer_replie()


func setup(jeu_: Node) -> void:
	jeu = jeu_
	rig = jeu.get("rig")
	world = jeu.get("world")
	for nom in ["transport"]:
		var t = jeu.get(nom)
		if t != null and t.has_signal("network_changed"):
			t.network_changed.connect(_salir)
	var b = jeu.get("buildings")
	if b != null:
		b.changed.connect(_salir)
	var c = jeu.get("communes")
	if c != null:
		c.changed.connect(_salir)
	if world != null:
		world.origin_changed.connect(func(_la: float, _lo: float) -> void:
			_fond_rect = Rect2()
			_fond_tex = null
			_calcul = {}
			_salir())


# --- Construction de l'interface ---------------------------------------------------

func _construire() -> void:
	_cadre = PanelContainer.new()
	UiStyle.style_panel(_cadre, 0.88, 10, 6)
	_cadre.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_cadre)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	_cadre.add_child(col)
	var tete := HBoxContainer.new()
	tete.add_theme_constant_override("separation", 2)
	col.add_child(tete)
	_titre = Label.new()
	_titre.add_theme_font_size_override("font_size", 13)
	_titre.add_theme_color_override("font_color", UiStyle.TEXT)
	_titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_titre.tooltip_text = "Mini-carte : clic ou glisser pour déplacer la caméra, molette pour le zoom (Ctrl+M : replier)"
	_titre.mouse_filter = Control.MOUSE_FILTER_PASS
	tete.add_child(_titre)
	tete.add_child(_petit_bouton("moins", "Voir plus large", func() -> void: set_zoom(zoom + 1)))
	tete.add_child(_petit_bouton("plus", "Voir de plus près", func() -> void: set_zoom(zoom - 1)))
	_bouton_replie = _petit_bouton("fermer", "Replier la mini-carte (Ctrl+M)", func() -> void: set_replie(true))
	tete.add_child(_bouton_replie)
	_vue = Vue.new()
	_vue.carte = self
	_vue.custom_minimum_size = Vector2(TAILLE, TAILLE)
	_vue.clip_contents = true
	_vue.mouse_filter = Control.MOUSE_FILTER_STOP
	_vue.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	col.add_child(_vue)
	var fond_uni := ColorRect.new()
	fond_uni.color = COULEUR_INCONNU
	fond_uni.set_anchors_preset(Control.PRESET_FULL_RECT)
	fond_uni.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vue.add_child(fond_uni)
	_monde = Node2D.new()
	_vue.add_child(_monde)
	_fond = Couche.new()
	_fond.dessin = _dessiner_fond
	_monde.add_child(_fond)
	_donnees = Couche.new()
	_donnees.dessin = _dessiner_donnees
	_monde.add_child(_donnees)
	_statique = Couche.new()
	_statique.dessin = _dessiner_statique
	_monde.add_child(_statique)
	_dessus = Dessus.new()
	_dessus.carte = self
	_dessus.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dessus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vue.add_child(_dessus)
	_legende = Label.new()
	_legende.add_theme_font_size_override("font_size", 11)
	_legende.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	_legende.custom_minimum_size.x = TAILLE
	_legende.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_legende.visible = false
	col.add_child(_legende)
	_bouton_ouvrir = Button.new()
	_bouton_ouvrir.text = "Carte"
	_bouton_ouvrir.icon = Icones.get_icon("cartes", 18)
	_bouton_ouvrir.tooltip_text = "Déplier la mini-carte (Ctrl+M)"
	_bouton_ouvrir.focus_mode = Control.FOCUS_NONE
	_bouton_ouvrir.add_theme_stylebox_override("normal", UiStyle.panel_box(0.88, 10, 6))
	_bouton_ouvrir.add_theme_stylebox_override("hover", UiStyle.panel_box(0.95, 10, 6))
	_bouton_ouvrir.add_theme_stylebox_override("pressed", UiStyle.panel_box(0.95, 10, 6))
	_bouton_ouvrir.pressed.connect(func() -> void: set_replie(false))
	add_child(_bouton_ouvrir)
	_maj_titre()


func _petit_bouton(icone: String, aide: String, f: Callable) -> Button:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.icon = Icones.get_icon(icone, 14, UiStyle.TEXT)
	b.tooltip_text = aide
	b.custom_minimum_size = Vector2(22, 22)
	b.pressed.connect(f)
	return b


# --- Réglages -------------------------------------------------------------------------

func etendue() -> float:
	return float(ETENDUES[zoom])


## Pixels de la carte par mètre.
func echelle() -> float:
	return TAILLE / etendue()


func set_zoom(z: int) -> void:
	z = clampi(z, 0, ETENDUES.size() - 1)
	if z == zoom:
		return
	zoom = z
	_maj_titre()
	_salir()
	_t_donnees = 0.0
	_ecrire_prefs()


func set_replie(on: bool) -> void:
	replie = on
	_appliquer_replie()
	_ecrire_prefs()


func basculer() -> void:
	set_replie(not replie)


func est_montree() -> bool:
	return is_visible_in_tree() and _cadre.visible


func _appliquer_replie() -> void:
	if _cadre == null:
		return
	_cadre.visible = not replie and _en_vue
	_bouton_ouvrir.visible = replie and _en_vue
	_salir()
	reset_size()


func _maj_titre() -> void:
	var e := etendue()
	_titre.text = "Carte · %s" % ("%d km" % int(e / 1000.0) if e >= 1000.0 else "%d m" % int(e))


func _lire_prefs() -> void:
	var cf := ConfigFile.new()
	if cf.load(PREFS) == OK:
		zoom = clampi(int(cf.get_value("carte", "zoom", ZOOM_DEFAUT)), 0, ETENDUES.size() - 1)
		replie = bool(cf.get_value("carte", "replie", false))


func _ecrire_prefs() -> void:
	var cf := ConfigFile.new()
	cf.set_value("carte", "zoom", zoom)
	cf.set_value("carte", "replie", replie)
	cf.save(PREFS)


# --- Boucle -----------------------------------------------------------------------------

func _salir() -> void:
	_statique_sale = true


func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and k.ctrl_pressed and not k.shift_pressed and not k.alt_pressed \
			and (k.physical_keycode == KEY_M or k.keycode == KEY_M) and is_visible_in_tree() and _en_vue:
		basculer()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_maj_en_vue()
	if not is_visible_in_tree() or not _en_vue or rig == null:
		return
	_placer()
	if replie:
		return
	centre = Vector2(rig.global_position.x, rig.global_position.z)
	var k := echelle()
	_monde.scale = Vector2(k, k)
	_monde.position = Vector2(TAILLE, TAILLE) * 0.5 - centre * k
	# Fond : recalculé quand la caméra sort de la zone déjà prête.
	_t_fond -= delta
	if _calcul.is_empty():
		var cote := etendue() * FOND_MARGE
		var besoin := not _fond_rect.has_area() or absf(_fond_rect.size.x - cote) > 1.0 \
			or not _fond_rect.grow(-etendue() * 0.25).has_point(centre) \
			or (_fond_incomplet and _t_fond <= 0.0)
		if besoin and world != null:
			_commencer_fond(centre, cote)
	if not _calcul.is_empty():
		_avancer_fond()
	# Calque en couleur (N, P).
	_t_donnees -= delta
	var cle := _cle_donnees()
	if cle != _donnees_cle or (_t_donnees <= 0.0 and cle != "") \
			or (cle != "" and not _donnees_rect.grow(-etendue() * 0.2).has_point(centre) and _donnees_rects.is_empty()):
		_calculer_donnees(cle)
	# Routes, bâtiments, frontières.
	_t_statique -= delta
	if _statique_sale and _t_statique <= 0.0:
		_statique_sale = false
		_t_statique = 1.0
		_statique.queue_redraw()
	_t_alertes -= delta
	if _t_alertes <= 0.0:
		_t_alertes = 1.0
		_relever_alertes()
	_dessus.queue_redraw()


## Visible seulement en vue de dessus, hors Atelier.
func _maj_en_vue() -> void:
	var on := not GameStart.atelier
	if on and jeu != null:
		var vue := jeu.get_node_or_null("VueSol")
		if vue != null and int(vue.get("vue")) != 0:
			on = false
	if on != _en_vue:
		_en_vue = on
		_appliquer_replie()


## En bas à droite, au-dessus de la barre des catégories.
func _placer() -> void:
	var hud := get_parent()
	var bas := 12.0
	var dock: Control = hud.get("_dock") if hud != null else null
	if dock != null and dock.is_visible_in_tree():
		var r := dock.get_global_rect()
		var vp := get_viewport_rect().size
		bas = vp.y - r.position.y + 8.0
	offset_right = -12.0
	offset_bottom = -bas
	var s := (_bouton_ouvrir if replie else _cadre).get_combined_minimum_size()
	offset_left = offset_right - s.x
	offset_top = offset_bottom - s.y


# --- Caméra ----------------------------------------------------------------------------

## Point du monde (x, z) sous un point de la carte (px).
func vers_monde(p: Vector2) -> Vector2:
	return centre + (p - Vector2(TAILLE, TAILLE) * 0.5) / echelle()


func vers_carte(w: Vector2) -> Vector2:
	return (w - centre) * echelle() + Vector2(TAILLE, TAILLE) * 0.5


func aller_a(w: Vector2) -> void:
	if rig == null:
		return
	var b: Rect2 = rig.get("bounds")
	rig.position.x = clampf(w.x, b.position.x, b.end.x)
	rig.position.z = clampf(w.y, b.position.y, b.end.y)
	centre = Vector2(rig.position.x, rig.position.z)
	camera_deplacee.emit(centre)


## Alerte la plus proche d'un point de la carte (à moins de `rayon` px), sinon {}.
func alerte_sous(p: Vector2, rayon := 8.0) -> Dictionary:
	var best := {}
	var d_best := rayon
	for a in alertes:
		var d := vers_carte(a.p).distance_to(p)
		if d <= d_best:
			d_best = d
			best = a
	return best


func cliquer(p: Vector2) -> void:
	var a := alerte_sous(p)
	if a.is_empty():
		aller_a(vers_monde(p))
		return
	aller_a(a.p)
	var hud = jeu.get("hud") if jeu != null else null
	if hud != null and hud.has_method("show_message"):
		hud.show_message("%s : %s." % [String(ALERTES[a.genre].nom), String(a.nom)])
	var bid := int(a.get("bid", -1))
	var pop = jeu.get("population")
	if bid >= 0 and pop != null and pop.has_method("select_building"):
		pop.select_building(bid)


func infobulle(p: Vector2) -> String:
	var a := alerte_sous(p)
	if not a.is_empty():
		return "%s : %s\nClic : y aller" % [String(ALERTES[a.genre].nom), String(a.nom)]
	var c = jeu.get("communes") if jeu != null else null
	if c != null:
		var w := vers_monde(p)
		var vid := int(c.village_au_point(w.x, w.y))
		if vid >= 0 and c.villages.has(vid):
			return "%s\nClic : y aller" % nom_village(vid)
	return "Clic : y aller · molette : zoom"


# --- Fond : relief et occupation du sol ------------------------------------------------

func _commencer_fond(c: Vector2, cote: float) -> void:
	var pas := cote / FOND_PX
	var x0 := snappedf(c.x - cote * 0.5, pas)
	var z0 := snappedf(c.y - cote * 0.5, pas)
	var h := PackedFloat32Array()
	h.resize(FOND_PX * FOND_PX)
	var sol := PackedByteArray()
	sol.resize(FOND_PX * FOND_PX)
	var eau := PackedFloat32Array()
	eau.resize(FOND_PX * FOND_PX)
	_calcul = {"rect": Rect2(x0, z0, cote, cote), "pas": pas, "h": h, "sol": sol, "eau": eau, "j": 0}


func _avancer_fond() -> void:
	var r: Rect2 = _calcul.rect
	var pas := float(_calcul.pas)
	var h: PackedFloat32Array = _calcul.h
	var sol: PackedByteArray = _calcul.sol
	var eau: PackedFloat32Array = _calcul.eau
	var j0 := int(_calcul.j)
	var j1 := mini(j0 + LIGNES_PAR_IMAGE, FOND_PX)
	var lons := PackedFloat64Array()
	lons.resize(FOND_PX)
	for i in FOND_PX:
		var ll := world.local_to_lat_lon(r.position.x + (i + 0.5) * pas, 0.0)
		lons[i] = ll.y
	var horizon: HorizonTerrain = world.horizon
	for j in range(j0, j1):
		var z := r.position.y + (j + 0.5) * pas
		var lats := PackedFloat64Array([world.local_to_lat_lon(0.0, z).x])
		var ligne := PackedByteArray()
		if world.land != null:
			ligne = world.land.sample_grid(lats, lons)
		for i in FOND_PX:
			var x := r.position.x + (i + 0.5) * pas
			var k := i + j * FOND_PX
			var hh := world.raw_height(x, z)
			if is_nan(hh) and horizon != null:
				hh = horizon.height_at(x, z)
			h[k] = hh
			sol[k] = ligne[i] if not ligne.is_empty() else 0
			eau[k] = world.water.width_at(x, z) if world.water != null else 0.0
	_calcul.j = j1
	if j1 >= FOND_PX:
		_finir_fond()


func _finir_fond() -> void:
	var h: PackedFloat32Array = _calcul.h
	var sol: PackedByteArray = _calcul.sol
	var eau: PackedFloat32Array = _calcul.eau
	var pas := float(_calcul.pas)
	var img := Image.create(FOND_PX, FOND_PX, false, Image.FORMAT_RGBA8)
	var incomplet := false
	var mer := world.sea_level()
	var lumiere := Vector3(-1.0, 1.4, -1.0).normalized()
	for j in FOND_PX:
		for i in FOND_PX:
			var k := i + j * FOND_PX
			var hh := h[k]
			var cl := int(sol[k])
			var c: Color
			if cl == 0 and is_nan(hh):
				incomplet = true
				c = COULEUR_INCONNU
			elif cl == 80 or (cl == 0 and hh < mer):
				c = COULEUR_EAU
			else:
				c = COULEURS_SOL.get(cl, Color("9cbf6a"))
				if cl == 0:
					incomplet = true
				if not is_nan(hh):
					# Relief ombré (lumière du nord-ouest) et teinte d'altitude.
					var hx := _h_voisin(h, i + 1, j, hh) - _h_voisin(h, i - 1, j, hh)
					var hz := _h_voisin(h, i, j + 1, hh) - _h_voisin(h, i, j - 1, hh)
					var n := Vector3(-hx, 2.0 * pas, -hz).normalized()
					var ombre := clampf(n.dot(lumiere), 0.0, 1.0)
					c = c.darkened(clampf(0.55 - ombre * 0.75, -0.25, 0.5)) if ombre < 0.73 else c.lightened((ombre - 0.73) * 0.9)
					if hh > 1800.0:
						c = c.lerp(Color(0.85, 0.85, 0.85), clampf((hh - 1800.0) / 1600.0, 0.0, 0.5))
				var w := eau[k]
				if w > 0.0:
					c = c.lerp(COULEUR_EAU, clampf(0.45 + w / pas, 0.45, 1.0))
			img.set_pixel(i, j, c)
	if _fond_tex != null and _fond_tex.get_size() == Vector2(FOND_PX, FOND_PX):
		_fond_tex.update(img)
	else:
		_fond_tex = ImageTexture.create_from_image(img)
	_fond_rect = _calcul.rect
	_fond_incomplet = incomplet
	_t_fond = 3.0
	_calcul = {}
	_fond.queue_redraw()


static func _h_voisin(h: PackedFloat32Array, i: int, j: int, defaut: float) -> float:
	if i < 0 or j < 0 or i >= FOND_PX or j >= FOND_PX:
		return defaut
	var v := h[i + j * FOND_PX]
	return defaut if is_nan(v) else v


func _dessiner_fond(ci: Node2D) -> void:
	if _fond_tex != null and _fond_rect.has_area():
		ci.draw_texture_rect(_fond_tex, _fond_rect, false)


# --- Calque en couleur repris de N ou P ----------------------------------------------

## Clé du calque à reprendre ("" : aucun).
func _cle_donnees() -> String:
	if jeu == null:
		return ""
	var ro = jeu.get("resource_overlay")
	if ro != null and String(ro.res) != "":
		return "res:" + String(ro.res)
	var id := Calques.actif()
	if id != "" and _calque_couleur() != null:
		return "calque:" + id
	return ""


## Carte en couleur (CalqueCouleur) affichée en ce moment, ou null.
func _calque_couleur() -> CalqueCouleur:
	for n in get_tree().get_nodes_in_group(CalqueCouleur.GROUPE):
		var cc := n as CalqueCouleur
		if cc != null and cc.visible:
			return cc
	return null


func _calculer_donnees(cle: String) -> void:
	_donnees_cle = cle
	_t_donnees = 2.0
	_donnees_rects = []
	_donnees_tex = null
	calque_nom = ""
	if cle == "":
		_donnees.queue_redraw()
		_maj_legende()
		return
	var cote := etendue() * 1.5
	var n := DONNEES_PX
	var pas := cote / n
	var x0 := snappedf(centre.x - cote * 0.5, pas)
	var z0 := snappedf(centre.y - cote * 0.5, pas)
	_donnees_rect = Rect2(x0, z0, cote, cote)
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	if cle.begins_with("res:"):
		var res := cle.substr(4)
		var info := Ressources.naturelle(res)
		calque_nom = String(info.get("name", res))
		var col: Color = info.get("color", Color.WHITE)
		var carte = jeu.get("production").carte if jeu.get("production") != null else null
		if carte != null:
			var v: PackedFloat32Array = carte.sample(res, x0, z0, n, n, pas)
			for j in n:
				for i in n:
					var r := v[i + j * n]
					if r >= 0.03:
						img.set_pixel(i, j, Color(col.r, col.g, col.b, 0.25 + 0.65 * r))
	else:
		var id := cle.substr(7)
		for c in Calques.liste():
			if String(c.id) == id:
				calque_nom = String(c.nom)
		var cc := _calque_couleur()
		if cc != null and cc.rects.is_valid():
			for e in cc.rects.call():
				var v := float(e[1])
				if v < 0.0:
					continue
				var col := cc.degrade.sample(clampf(v, 0.0, 1.0))
				col.a = lerpf(cc.alpha.x, cc.alpha.y, clampf(v, 0.0, 1.0))
				_donnees_rects.append([Rect2(e[0]), col])
		elif cc != null and cc.valeur.is_valid():
			for j in n:
				for i in n:
					var v := float(cc.valeur.call(x0 + (i + 0.5) * pas, z0 + (j + 0.5) * pas))
					if v < 0.0 or v < cc.seuil:
						continue
					var col := cc.degrade.sample(clampf(v, 0.0, 1.0))
					col.a = lerpf(cc.alpha.x, cc.alpha.y, clampf(v, 0.0, 1.0))
					img.set_pixel(i, j, col)
	if _donnees_rects.is_empty():
		_donnees_tex = ImageTexture.create_from_image(img)
	_donnees.queue_redraw()
	_maj_legende()


func _maj_legende() -> void:
	_legende.visible = calque_nom != ""
	_legende.text = "Couleurs : %s" % calque_nom


func _dessiner_donnees(ci: Node2D) -> void:
	if _donnees_tex != null and _donnees_rect.has_area():
		ci.draw_texture_rect(_donnees_tex, _donnees_rect, false)
	var mini := 1.5 / echelle()
	for e in _donnees_rects:
		var r: Rect2 = e[0]
		ci.draw_rect(Rect2(r.position, r.size.max(Vector2(mini, mini))), e[1])


# --- Routes, bâtiments, territoires ---------------------------------------------------

func _dessiner_statique(ci: Node2D) -> void:
	if jeu == null:
		return
	var k := echelle()
	var px := 1.0 / k
	# Territoires des villages.
	var c = jeu.get("communes")
	if c != null:
		for vid in c.villages:
			var v: Dictionary = c.villages[vid]
			var col := _couleur_village(int(vid))
			var fond := Color(col.r, col.g, col.b, 0.16)
			var cases: Dictionary = v.get("cases", {})
			var cote := float(Communes.CASE)
			for cs in cases:
				var q: Vector2i = cs
				var o := Vector2(q.x * cote, q.y * cote)
				ci.draw_rect(Rect2(o, Vector2(cote, cote)), fond)
				# Frontière : côtés qui ne touchent pas une case du même village.
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if cases.has(q + d):
						continue
					var a: Vector2
					var b: Vector2
					match d:
						Vector2i(1, 0):
							a = o + Vector2(cote, 0)
							b = o + Vector2(cote, cote)
						Vector2i(-1, 0):
							a = o
							b = o + Vector2(0, cote)
						Vector2i(0, 1):
							a = o + Vector2(0, cote)
							b = o + Vector2(cote, cote)
						_:
							a = o
							b = o + Vector2(cote, 0)
					ci.draw_line(a, b, Color(col.r, col.g, col.b, 0.95), 1.5 * px)
	# Voies : routes, rails, chemins, canaux.
	var t = jeu.get("transport")
	if t != null:
		var net: TransportNetwork = t.network
		var saut := maxi(1, int(round(3.0 / maxf(k * 2.0, 0.001))))
		for eid in net.edges:
			var e: Dictionary = net.edges[eid]
			var pts: PackedVector3Array = e.pts
			if pts.size() < 2:
				continue
			var ligne := PackedVector2Array()
			var pas := maxi(1, mini(saut, pts.size() / 2))
			for i in range(0, pts.size(), pas):
				ligne.append(Vector2(pts[i].x, pts[i].z))
			var fin := pts[pts.size() - 1]
			ligne.append(Vector2(fin.x, fin.z))
			var mode := TransportTypes.mode_of(String(e.t))
			var col := COULEUR_ROUTE
			var larg := maxf(net.half_width(int(eid)) * 2.0, 1.4 * px)
			match mode:
				TransportTypes.Mode.RAIL:
					col = COULEUR_RAIL
					larg = maxf(4.0, 1.4 * px)
				TransportTypes.Mode.PATH:
					col = COULEUR_CHEMIN
					larg = maxf(2.0, 1.0 * px)
				TransportTypes.Mode.WATER:
					col = COULEUR_CANAL
				TransportTypes.Mode.AIR:
					continue
			ci.draw_polyline(ligne, col, larg)
	# Bâtiments.
	var b = jeu.get("buildings")
	if b != null:
		var mini := 1.6 * px
		for bid in b.buildings:
			var r: Rect2i = b._rect_of(b.buildings[bid])
			var rr := Rect2(r.position, r.size)
			if rr.size.x < mini or rr.size.y < mini:
				rr = Rect2(rr.get_center() - Vector2(mini, mini) * 0.5, Vector2(mini, mini))
			ci.draw_rect(rr, COULEUR_BATIMENT)


## Couleur d'un village : la sienne en solo ; en carte entre amis, ambre pour les
## villes du joueur et la couleur du village pour les voisines.
func _couleur_village(vid: int) -> Color:
	var c = jeu.get("communes")
	var idx := int((c.villages[vid] as Dictionary).get("couleur", 0)) if c != null and c.villages.has(vid) else 0
	var col: Color = Communes.COULEURS[idx % Communes.COULEURS.size()]
	var mes = _mes_villes()
	if mes != null and (mes as Array).has(vid):
		return UiStyle.ACCENT
	return col


## Villes du joueur sur une carte entre amis, null en solo.
func _mes_villes() -> Variant:
	if not Multijoueur.en_ligne():
		return null
	var cl := Multijoueur.client_actif()
	if cl == null:
		return null
	var out := []
	for v in cl.mes_villes:
		out.append(int(v))
	return out


## Nom du village, avec « ta ville » ou « ville voisine » sur une carte entre amis.
func nom_village(vid: int) -> String:
	var c = jeu.get("communes") if jeu != null else null
	if c == null or not c.villages.has(vid):
		return ""
	var nom := String(c.villages[vid].nom)
	var mes = _mes_villes()
	if mes == null:
		return nom
	return ("%s (ta ville)" if (mes as Array).has(vid) else "%s (ville voisine)") % nom


# --- Alertes ------------------------------------------------------------------------------

func _relever_alertes() -> void:
	var out: Array = []
	var ev := Evenements.instance
	if ev != null and is_instance_valid(ev):
		for id in ev.incidents:
			var inc: Dictionary = ev.incidents[id]
			if String(inc.get("etat", "")) == "resolu":
				continue
			var p = inc.get("position", Vector3.ZERO)
			if p is Vector3:
				out.append({"p": Vector2(p.x, p.z), "genre": "incident", "nom": _nom_incident(inc), "bid": int(inc.get("batiment", -1))})
		for id in ev.events:
			var e: Dictionary = ev.events[id]
			if String(e.get("etat", "")) != "en_cours" or not CATASTROPHES.has(String(e.get("type", ""))):
				continue
			var p = e.get("pos", Vector3.INF)
			if p is Vector3 and (p as Vector3).is_finite():
				out.append({"p": Vector2(p.x, p.z), "genre": "catastrophe", "nom": String(e.get("nom", "")), "bid": int(e.get("bid", -1))})
	var b = jeu.get("buildings") if jeu != null else null
	var res = jeu.get("reseaux") if jeu != null else null
	if b != null and res != null and res.raccordements != null:
		var n := 0
		for bid in res.raccordements.non_raccordes():
			if not b.buildings.has(bid):
				continue
			var cpos := BuildingSystem.rect_center(b._rect_of(b.buildings[bid]))
			out.append({"p": Vector2(cpos.x, cpos.z), "genre": "non_raccorde", "nom": _nom_batiment(b, int(bid)), "bid": int(bid)})
			n += 1
			if n >= 300:
				break
	var vie = jeu.get("vie_batiments") if jeu != null else null
	if vie != null and vie.get("marqueurs") != null:
		for m in vie.marqueurs.marqueurs:
			var p: Vector3 = m.pos
			var bid := int(m.get("bid", -1))
			out.append({"p": Vector2(p.x, p.z), "genre": "chantier", "nom": "%s (%d %%)" % [_nom_batiment(b, bid), int(float(m.get("av", 0.0)) * 100.0)], "bid": bid})
	# Les plus graves dessinés en dernier (au-dessus).
	var ordre := {"chantier": 0, "non_raccorde": 1, "catastrophe": 2, "incident": 3}
	out.sort_custom(func(a: Dictionary, c: Dictionary) -> bool: return int(ordre[a.genre]) < int(ordre[c.genre]))
	alertes = out


static func _nom_incident(inc: Dictionary) -> String:
	var t := String(inc.get("texte", ""))
	if t != "":
		return t
	var ty := String(inc.get("type", ""))
	if Evenements.TYPES.has(ty):
		return String(Evenements.TYPES[ty].nom)
	return ty.capitalize()


static func _nom_batiment(b, bid: int) -> String:
	if b == null or not b.buildings.has(bid):
		return "Bâtiment"
	return String(BuildingCatalog.get_type(String(b.buildings[bid].t)).get("name", "Bâtiment"))


# --- Dessus : caméra, alertes, noms des villages -------------------------------------

func _dessiner_dessus(ci: Control) -> void:
	var font := get_theme_default_font()
	var cote := Vector2(TAILLE, TAILLE)
	# Noms des villages.
	var c = jeu.get("communes") if jeu != null else null
	if c != null:
		for vid in c.villages:
			var v: Dictionary = c.villages[vid]
			var p := vers_carte(v.c)
			if p.x < -20 or p.y < -10 or p.x > cote.x + 20 or p.y > cote.y + 10:
				continue
			var col := _couleur_village(int(vid))
			ci.draw_circle(p, 3.0, col)
			var nom := String(v.nom)
			var w := font.get_string_size(nom, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			var o := Vector2(clampf(p.x - w * 0.5, 2.0, cote.x - w - 2.0), clampf(p.y - 9.0, 12.0, cote.y - 4.0))
			ci.draw_string_outline(font, o, nom, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color(0, 0, 0, 0.85))
			ci.draw_string(font, o, nom, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col.lightened(0.35))
	# Champ de la caméra.
	_dessiner_camera(ci)
	# Alertes (les urgentes clignotent ; hors champ, elles restent au bord).
	var t := Time.get_ticks_msec() / 1000.0
	for a in alertes:
		var g: Dictionary = ALERTES[a.genre]
		var p: Vector2 = vers_carte(a.p)
		var urgent: bool = a.genre == "incident" or a.genre == "catastrophe"
		var dedans := Rect2(Vector2.ZERO, cote).has_point(p)
		if not dedans:
			if not urgent:
				continue
			p = p.clamp(Vector2(4, 4), cote - Vector2(4, 4))
		var r := float(g.r)
		if urgent:
			var halo := 0.5 + 0.5 * sin(t * 6.0)
			ci.draw_circle(p, r + 3.0 + halo * 2.5, Color(g.couleur.r, g.couleur.g, g.couleur.b, 0.25 + 0.2 * halo))
		ci.draw_circle(p, r + (1.0 if urgent else 0.6), Color(0, 0, 0, 0.7 if urgent else 0.45))
		ci.draw_circle(p, r, g.couleur)
	# Nord.
	ci.draw_string_outline(font, Vector2(cote.x - 12, 13), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color(0, 0, 0, 0.8))
	ci.draw_string(font, Vector2(cote.x - 12, 13), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UiStyle.TEXT)
	ci.draw_rect(Rect2(Vector2.ZERO, cote), Color(1, 1, 1, 0.18), false, 1.0)


func _dessiner_camera(ci: Control) -> void:
	var cam := rig.get_node_or_null("Camera3D") as Camera3D if rig != null else null
	var milieu := Vector2(TAILLE, TAILLE) * 0.5
	var poly := champ_camera(cam)
	if poly.size() == 4:
		var pts := PackedVector2Array()
		for w in poly:
			pts.append(vers_carte(w))
		ci.draw_colored_polygon(pts, Color(1, 1, 1, 0.12))
		pts.append(pts[0])
		ci.draw_polyline(pts, Color(1, 1, 1, 0.9), 1.5, true)
	# Le pivot et la direction du regard.
	var dir := Vector2(0, -1)
	if cam != null:
		var f := -cam.global_transform.basis.z
		var d2 := Vector2(f.x, f.z)
		if d2.length() > 0.01:
			dir = d2.normalized()
	var cote := Vector2(-dir.y, dir.x)
	ci.draw_colored_polygon(PackedVector2Array([milieu + dir * 7.0, milieu - dir * 4.0 + cote * 4.5, milieu - dir * 4.0 - cote * 4.5]), UiStyle.ACCENT)


## Coins au sol (x, z) de ce que voit la caméra, bornés à 1,5 fois la largeur de la carte.
func champ_camera(cam: Camera3D) -> Array:
	if cam == null or not cam.is_inside_tree():
		return []
	var vp := cam.get_viewport().get_visible_rect().size
	var sol := rig.global_position.y
	var limite := etendue() * 1.5
	var out := []
	for e: Vector2 in [Vector2(0, 0), Vector2(vp.x, 0), Vector2(vp.x, vp.y), Vector2(0, vp.y)]:
		var o := cam.project_ray_origin(e)
		var d := cam.project_ray_normal(e)
		var p: Vector3
		if d.y < -0.001:
			p = o + d * ((sol - o.y) / d.y)
		else:
			p = o + Vector3(d.x, 0.0, d.z).normalized() * limite
		var v := Vector2(p.x, p.z) - centre
		if v.length() > limite:
			v = v.normalized() * limite
		out.append(centre + v)
	return out


# --- Classes internes ---------------------------------------------------------------------

## Zone de la carte : clic / glisser (caméra), molette (zoom), infobulle.
class Vue extends Control:
	var carte: MiniCarte

	func _gui_input(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb != null:
			if mb.button_index == MOUSE_BUTTON_LEFT:
				carte._glisse = mb.pressed
				if mb.pressed:
					carte.cliquer(mb.position)
				accept_event()
			elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				carte.set_zoom(carte.zoom - 1)
				accept_event()
			elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				carte.set_zoom(carte.zoom + 1)
				accept_event()
			return
		var mm := event as InputEventMouseMotion
		if mm != null and carte._glisse and mm.button_mask & MOUSE_BUTTON_MASK_LEFT:
			carte.aller_a(carte.vers_monde(mm.position))
			accept_event()

	func _get_tooltip(at: Vector2) -> String:
		return carte.infobulle(at)


## Couche dessinée en coordonnées du monde (redessinée seulement quand elle change).
class Couche extends Node2D:
	var dessin: Callable

	func _draw() -> void:
		if dessin.is_valid():
			dessin.call(self)


class Dessus extends Control:
	var carte: MiniCarte

	func _draw() -> void:
		carte._dessiner_dessus(self)
