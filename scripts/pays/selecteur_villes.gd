class_name SelecteurVilles
extends Control
## Passer vite d'une ville à l'autre.
##
## - Dans la barre du haut : ◀ (ville précédente), le drapeau de la ville gérée
##   (clic : bande des villes en vignettes), ▶ (ville suivante). Visibles dès la 2e ville.
## - Ctrl+Tab : ville suivante, Ctrl+Maj+Tab : ville précédente. La bande des villes
##   s'affiche un instant pour montrer où l'on arrive.
## - Bande des villes : une carte par ville (photo prise la dernière fois qu'on y
##   était, drapeau, nom, palier, habitants, satisfaction, caisse, maire, pilote).
##   Un clic : la caméra saute sur la mairie, la caisse, le budget (M), la Mairie et
##   les panneaux de la ville suivent (Pays.choisir).
##
## Les photos sont prises dans un petit SubViewport qui partage le monde 3D, quand
## la caméra est sur la ville (le relief et les bâtiments y sont chargés), toutes
## les PHOTO_INTERVALLE secondes et juste avant d'en partir. Rien en mode headless.

signal aller_requested(pos: Vector3)

## Taille d'une photo de ville (16:9).
const PHOTO := Vector2i(192, 108)
## Une nouvelle photo de la ville gérée toutes les … secondes (si la caméra y est).
const PHOTO_INTERVALLE := 25.0
## Hauteur de la carte sous la photo (nom, chiffres, caisse, maire).
const CARTE_TEXTE := 102.0
## Durée d'affichage de la bande après Ctrl+Tab (secondes).
const BANDE_FLASH := 2.2
## Au-delà de cette distance, la caméra saute d'un coup (pas de survol du relief).
const SAUT_DIRECT := 2500.0

static var instance: SelecteurVilles

var pays: Pays
var communes: Communes
## Node3D de la caméra de gestion (CameraRig).
var rig: Node3D
## Callable(x, z) -> float : hauteur du sol (NAN si inconnue).
var hauteur_sol: Callable
## Callable() -> bool : vrai quand on ne peut pas sauter (vue au sol, visite, éditeur…).
var bloque: Callable

## Boutons de la barre du haut (posés par TerreHud.poser_dans_barre).
var barre: HBoxContainer
var _prec: Button
var _ici: Button
var _suiv: Button

var _bande: PanelContainer
var _cartes: HBoxContainer
var _titre: Label
var _flash := 0.0
var _sig_bande := ""
var _t_bande := 0.0
var _sale := true
var _t := 0.0
var _t_photo := 3.0

## vid -> ImageTexture (dernière photo de la ville).
var photos := {}
var _sv: SubViewport
var _cam: Camera3D
var _photo_en_cours := false
var _tween: Tween


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_barre()
	_build_bande()


func setup(p: Pays, cm: Communes, camera_rig: Node3D) -> void:
	pays = p
	communes = cm
	rig = camera_rig
	if pays != null:
		pays.changed.connect(func() -> void: _sale = true)
	if communes != null:
		communes.changed.connect(func() -> void: _sale = true)
		communes.fusion.connect(func(_g: int, partie: int) -> void: photos.erase(partie))
	_sale = true


func clear() -> void:
	photos.clear()
	_fermer()
	_sale = true


# --- Liste des villes ------------------------------------------------------------------

## Les villes du joueur, dans l'ordre de fondation.
func villes() -> Array:
	if communes == null:
		return []
	var ids: Array = communes.villages.keys()
	ids.sort()
	return ids


func actuelle() -> int:
	if pays == null:
		return -1
	var v := pays.selection
	if communes != null and communes.villages.has(v):
		return v
	# Caméra hors des territoires : la ville la plus proche.
	return plus_proche()


func plus_proche() -> int:
	if communes == null or rig == null:
		return -1
	var best := -1
	var bd := INF
	var p := Vector2(rig.position.x, rig.position.z)
	for vid in communes.villages:
		var d := p.distance_squared_to(communes.villages[vid].c as Vector2)
		if d < bd:
			bd = d
			best = int(vid)
	return best


func disponible() -> bool:
	return villes().size() >= 2


## Ville suivante (pas = 1) ou précédente (pas = -1) ; renvoie la ville atteinte.
func passer(pas: int) -> int:
	var ids := villes()
	if ids.size() < 2:
		return -1
	var i := ids.find(actuelle())
	var j := posmod((i if i >= 0 else 0) + pas, ids.size())
	var vid := int(ids[j])
	aller(vid)
	return vid


## Saute sur la ville vid : caméra sur sa mairie, ville gérée = vid.
func aller(vid: int) -> bool:
	if communes == null or not communes.villages.has(vid):
		return false
	if bloque.is_valid() and bool(bloque.call()):
		return false
	var depart := actuelle()
	if depart >= 0 and depart != vid and _camera_sur(depart):
		prendre_photo(depart)
	var c: Vector2 = communes.villages[vid].c
	if rig != null:
		var cible := Vector3(c.x, rig.position.y, c.y)
		if _tween != null and _tween.is_valid():
			_tween.kill()
		var d := Vector2(rig.position.x, rig.position.z).distance_to(c)
		if d > SAUT_DIRECT or not is_inside_tree():
			rig.position = cible
		else:
			_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			_tween.tween_property(rig, "position", cible, clampf(d / 2500.0, 0.2, 0.55))
	if pays != null:
		pays.choisir(vid)
	aller_requested.emit(Vector3(c.x, 0.0, c.y))
	Son.jouer("ui_ouvrir", -8.0, 0.0, "Interface")
	_sale = true
	return true


# --- Barre du haut -----------------------------------------------------------------------

func _build_barre() -> void:
	barre = HBoxContainer.new()
	barre.name = "SelecteurVilles"
	barre.add_theme_constant_override("separation", 2)
	barre.visible = false
	_prec = UiStyle.icon_button("precedent", "Ville précédente", "Ctrl+Maj+Tab", 18, 30)
	_prec.name = "VillePrecedente"
	_prec.focus_mode = Control.FOCUS_NONE
	_prec.pressed.connect(func() -> void: passer(-1))
	barre.add_child(_prec)
	_ici = UiStyle.icon_button("village", "Mes villes en vignettes : clic sur une ville pour y aller", "", 22, 40)
	_ici.name = "MesVilles"
	_ici.focus_mode = Control.FOCUS_NONE
	_ici.toggle_mode = true
	# Le drapeau garde ses couleurs, bouton enfoncé ou non.
	for c in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_focus_color"]:
		_ici.add_theme_color_override(c, Color.WHITE)
	_ici.toggled.connect(func(on: bool) -> void:
		if on:
			ouvrir()
		else:
			_fermer())
	barre.add_child(_ici)
	_suiv = UiStyle.icon_button("suivant", "Ville suivante", "Ctrl+Tab", 18, 30)
	_suiv.name = "VilleSuivante"
	_suiv.focus_mode = Control.FOCUS_NONE
	_suiv.pressed.connect(func() -> void: passer(1))
	barre.add_child(_suiv)


func _maj_barre() -> void:
	var on := disponible()
	barre.visible = on
	if not on:
		return
	var v := actuelle()
	if v < 0:
		return
	var vg: Dictionary = communes.villages[v]
	var code := String(vg.get("drapeau", ""))
	var ic: Texture2D = Drapeaux.icone(code, 18) if code != "" and Drapeaux.existe(code) else null
	_ici.icon = ic if ic != null else Icones.get_icon("village", 22)
	_ici.tooltip_text = "%s · %d villes : clic pour les voir en vignettes et y aller (Ctrl+Tab : suivante)" % [String(vg.nom), villes().size()]
	var ids := villes()
	var i := ids.find(v)
	_prec.tooltip_text = "Ville précédente : %s (Ctrl+Maj+Tab)" % String(communes.villages[int(ids[posmod(i - 1, ids.size())])].nom)
	_suiv.tooltip_text = "Ville suivante : %s (Ctrl+Tab)" % String(communes.villages[int(ids[posmod(i + 1, ids.size())])].nom)


# --- Bande des villes en vignettes ---------------------------------------------------

func _build_bande() -> void:
	_bande = PanelContainer.new()
	_bande.name = "BandeVilles"
	_bande.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_bande.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_bande.offset_top = UiStyle.SIDE_TOP
	_bande.visible = false
	_bande.mouse_filter = Control.MOUSE_FILTER_STOP
	UiStyle.style_panel(_bande, 0.92, 12, 10)
	# Calque à part : la bande passe devant les cartes de gauche et les panneaux.
	var calque := CanvasLayer.new()
	calque.name = "CalqueBandeVilles"
	calque.layer = 8
	add_child(calque)
	calque.add_child(_bande)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	_bande.add_child(vb)
	var tete := HBoxContainer.new()
	vb.add_child(tete)
	_titre = Label.new()
	_titre.text = "Mes villes"
	_titre.add_theme_font_size_override("font_size", 17)
	_titre.add_theme_color_override("font_color", UiStyle.ACCENT)
	_titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tete.add_child(_titre)
	var aide := Label.new()
	aide.text = "Ctrl+Tab : suivante · Ctrl+Maj+Tab : précédente"
	aide.add_theme_font_size_override("font_size", 12)
	aide.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	aide.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tete.add_child(aide)
	var x := UiStyle.icon_button("fermer", "Fermer", "Échap", 16, 28)
	x.focus_mode = Control.FOCUS_NONE
	x.pressed.connect(_fermer)
	tete.add_child(x)
	var sc := ScrollContainer.new()
	sc.name = "Defilement"
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	vb.add_child(sc)
	_cartes = HBoxContainer.new()
	_cartes.name = "Cartes"
	_cartes.add_theme_constant_override("separation", 8)
	sc.add_child(_cartes)


func is_open() -> bool:
	return _bande.visible


## Ouvre la bande (jusqu'à ce qu'on la ferme).
func ouvrir() -> void:
	_flash = 0.0
	_bande.visible = true
	_ici.set_pressed_no_signal(true)
	_remplir()


## Montre la bande un instant (après Ctrl+Tab), sauf si elle est déjà ouverte.
func montrer_un_instant() -> void:
	if _bande.visible and _flash <= 0.0:
		_remplir()
		return
	_flash = BANDE_FLASH
	_bande.visible = true
	_remplir()


func _fermer() -> void:
	_flash = 0.0
	if _bande != null:
		_bande.visible = false
	if _ici != null:
		_ici.set_pressed_no_signal(false)


func _signature() -> String:
	return "%s|%d|%d" % [str(villes()), actuelle(), photos.size()]


func _remplir() -> void:
	_sig_bande = _signature()
	_t_bande = 5.0
	for c in _cartes.get_children():
		_cartes.remove_child(c)
		c.queue_free()
	var ids := villes()
	_titre.text = "Mes villes (%d)" % ids.size()
	var ici := actuelle()
	for vid in ids:
		_cartes.add_child(_carte(int(vid), int(vid) == ici))
	# Assez large pour 5 cartes, défilement au-delà ; jamais plus large que l'écran.
	var sc := _cartes.get_parent() as ScrollContainer
	var n := mini(ids.size(), 5)
	var vue := get_viewport_rect().size.x if is_inside_tree() else 1600.0
	sc.custom_minimum_size = Vector2(minf(n * (PHOTO.x + 20.0) - 8.0, vue - 60.0), 0)
	_centrer_bande()


## Centre la bande sous la barre du haut (sa taille n'est connue qu'après coup).
func _centrer_bande() -> void:
	var w := _bande.get_combined_minimum_size().x
	if absf(_bande.offset_right - _bande.offset_left - w) < 0.5 and absf(_bande.offset_left + w * 0.5) < 0.5:
		return
	_bande.offset_left = -w * 0.5
	_bande.offset_right = w * 0.5


## Carte d'une ville : photo, drapeau + nom, chiffres, caisse.
func _carte(vid: int, ici: bool) -> Button:
	var v: Dictionary = communes.villages[vid]
	var b := Button.new()
	b.name = "Ville%d" % vid
	b.focus_mode = Control.FOCUS_NONE
	# Taille fixe : un Button ne se règle pas sur ses enfants.
	b.custom_minimum_size = Vector2(PHOTO.x + 12, PHOTO.y + CARTE_TEXTE)
	b.tooltip_text = "Aller à %s" % String(v.nom) if not ici else "%s : la ville que tu gères" % String(v.nom)
	var bord := UiStyle.ACCENT if ici else Color(1, 1, 1, 0.10)
	for st in ["normal", "hover", "pressed"]:
		var sb := UiStyle.flat_box(Color(1, 1, 1, 0.06 if st == "normal" else 0.13), 10, 6)
		sb.border_color = bord if st != "hover" else UiStyle.ACCENT.lerp(Color.WHITE, 0.3)
		sb.set_border_width_all(2 if ici or st == "hover" else 1)
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(func() -> void:
		aller(vid)
		_fermer())
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 3)
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 6
	vb.offset_top = 6
	vb.offset_right = -6
	vb.offset_bottom = -6
	b.add_child(vb)
	# Photo (ou, avant la première visite, la Maison de commune).
	var img := TextureRect.new()
	img.name = "Photo"
	img.custom_minimum_size = Vector2(PHOTO)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if photos.has(vid):
		img.texture = photos[vid]
	elif not Illustrations.poser("batiment", "maison_commune", img):
		img.texture = Pictos.auto("village", 0, 1, "village") if Icones.has_icon("village") else null
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vb.add_child(img)
	# Drapeau + nom.
	var nom := HBoxContainer.new()
	nom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nom.add_theme_constant_override("separation", 5)
	vb.add_child(nom)
	var code := String(v.get("drapeau", ""))
	if code != "" and Drapeaux.existe(code):
		var fl := TextureRect.new()
		fl.texture = Drapeaux.icone(code, 14)
		fl.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nom.add_child(fl)
	var ln := Label.new()
	ln.text = String(v.nom)
	ln.add_theme_font_size_override("font_size", 15)
	ln.add_theme_color_override("font_color", UiStyle.ACCENT if ici else UiStyle.TEXT)
	ln.clip_text = true
	ln.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	ln.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nom.add_child(ln)
	var ch := chiffres(vid)
	_ligne(vb, [["habitants", str(int(ch.hab))], ["sourire", "—" if int(ch.satisfaction) < 0 else str(int(ch.satisfaction))]],
		String(ch.palier))
	var caisse := _ligne(vb, [["budget", String(ch.caisse)]], "")
	if int(ch.solde) < 0 and not bool(ch.illimite):
		for l in caisse.get_children():
			if l is Label:
				(l as Label).add_theme_color_override("font_color", Color("ff8a80"))
	var etat := Label.new()
	etat.text = String(ch.etat)
	etat.add_theme_font_size_override("font_size", 11)
	etat.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	etat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(etat)
	return b


func _ligne(parent: Control, morceaux: Array, fin: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 4)
	parent.add_child(h)
	for m in morceaux:
		var ic := TextureRect.new()
		ic.texture = Icones.get_icon(String(m[0]), 14, UiStyle.ACCENT)
		ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(ic)
		var l := Label.new()
		l.text = String(m[1])
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color", UiStyle.TEXT)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(l)
	if fin != "":
		var f := Label.new()
		f.text = fin
		f.add_theme_font_size_override("font_size", 12)
		f.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
		f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		f.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		f.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(f)
	return h


## Chiffres d'une ville pour sa carte.
func chiffres(vid: int) -> Dictionary:
	var s: Dictionary = communes.stats.get(vid, {}) if communes != null else {}
	var p := clampi(int(s.get("palier", 0)), 0, ReglagesPartie.PALIERS.size() - 1)
	var out := {"hab": int(s.get("hab", 0)), "palier": String(ReglagesPartie.PALIERS[p].nom), "satisfaction": -1,
		"solde": 0, "caisse": "—", "illimite": false, "etat": ""}
	var av := Avis.instance
	if av != null:
		if av.ville_vid == vid:
			out.satisfaction = av.moyenne()
		else:
			var h: Array = av.historiques.get(vid, [])
			if not h.is_empty():
				out.satisfaction = int(h[h.size() - 1].valeur)
	if pays != null:
		out.illimite = pays.illimite()
		out.solde = pays.solde(vid)
		out.caisse = "Illimitée" if out.illimite else BuildingSystem.format_money(int(out.solde))
		var etats: Array[String] = []
		etats.append("Tu es maire" if pays.joueur_maire(vid) else "Mairie perdue")
		if PiloteAuto.instance != null and PiloteAuto.instance.actif(vid):
			etats.append("pilote auto")
		if pays.plusieurs_nations():
			etats.append(pays.nom_nation(pays.nation_de(vid)))
		out.etat = " · ".join(etats)
	return out


# --- Photos des villes ----------------------------------------------------------------

func _camera_sur(vid: int) -> bool:
	if rig == null or communes == null:
		return false
	return communes.village_au_point(rig.position.x, rig.position.z) == vid


static func peut_photographier() -> bool:
	return DisplayServer.get_name() != "headless"


## Photo de la ville vid, vue de haut et un peu de biais, depuis le monde 3D actuel.
func prendre_photo(vid: int) -> void:
	if _photo_en_cours or communes == null or not communes.villages.has(vid) or not is_inside_tree():
		return
	if not peut_photographier():
		return
	if _sv == null:
		_sv = SubViewport.new()
		_sv.name = "PhotoVille"
		_sv.size = PHOTO * 2
		_sv.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_sv.own_world_3d = false
		_sv.msaa_3d = Viewport.MSAA_2X
		add_child(_sv)
		_sv.world_3d = get_viewport().world_3d
		_cam = Camera3D.new()
		_cam.fov = 45.0
		_cam.far = 8000.0
		_sv.add_child(_cam)
	var v: Dictionary = communes.villages[vid]
	var c: Vector2 = v.c
	# Assez près pour voir les maisons (la brume de lointain délave tout au-delà).
	var r := clampf(float(v.get("rayon", 300.0)) * 0.3, 110.0, 700.0)
	var sol := 0.0
	if hauteur_sol.is_valid():
		var g: float = hauteur_sol.call(c.x, c.y)
		if not is_nan(g):
			sol = g
	var cible := Vector3(c.x, sol, c.y)
	var cap := rig.rotation.y if rig != null else 0.0
	var dos := Vector3(sin(cap), 0.0, cos(cap))
	_cam.position = cible + dos * r * 0.85 + Vector3.UP * r * 0.95
	_cam.look_at(cible, Vector3.UP)
	_photo_en_cours = true
	_sv.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	_photo_en_cours = false
	if not is_instance_valid(_sv):
		return
	var im := _sv.get_texture().get_image()
	if im == null or im.is_empty():
		return
	im.resize(PHOTO.x, PHOTO.y, Image.INTERPOLATE_BILINEAR)
	photos[vid] = ImageTexture.create_from_image(im)
	_sig_bande = ""


# --- Boucle et touches ---------------------------------------------------------------

func _process(delta: float) -> void:
	if _bande.visible:
		_centrer_bande()
	if _flash > 0.0:
		_flash -= delta
		if _flash <= 0.0:
			_fermer()
	_t -= delta
	if _sale or _t <= 0.0:
		_t = 1.0
		_sale = false
		_maj_barre()
		if is_open():
			_t_bande -= 1.0
			if not disponible():
				_fermer()
			# Refaite si les villes, la ville gérée ou les photos changent ; les chiffres
			# toutes les 5 s, mais jamais sous la souris (le clic ne doit pas se perdre).
			elif _signature() != _sig_bande or (_t_bande <= 0.0 and not _bande.get_global_rect().has_point(get_global_mouse_position())):
				_remplir()
	_t_photo -= delta
	if _t_photo <= 0.0:
		_t_photo = PHOTO_INTERVALLE
		var v := actuelle()
		if v >= 0 and disponible() and _camera_sur(v) and not (bloque.is_valid() and bool(bloque.call())):
			prendre_photo(v)


func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode == KEY_TAB and k.ctrl_pressed and not k.alt_pressed:
		if not disponible():
			return
		get_viewport().set_input_as_handled()
		if passer(-1 if k.shift_pressed else 1) >= 0:
			montrer_un_instant()
		return
	if k.keycode == KEY_ESCAPE and is_open():
		get_viewport().set_input_as_handled()
		_fermer()

