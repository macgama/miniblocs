class_name TimeLapsePanel
extends CanvasLayer
## Écran du time-lapse (Maj+F8, ou Infos → Mode photo → Time-lapse) : revoir la
## ville grandir en accéléré depuis sa fondation, gérer les caméras fixes et
## exporter une vidéo (AVI lisible partout, MP4 si ffmpeg est installé) ou la
## suite d'images, avec la date, les habitants et le logo incrustés.

signal message(text: String)
signal ouvert_change(on: bool)

const IPS := [4, 8, 12, 24, 30, 60]
const MOIS := ["janvier", "février", "mars", "avril", "mai", "juin", "juillet", "août",
	"septembre", "octobre", "novembre", "décembre"]
const COTE_W := 330.0
## Durée de la dernière image à la fin de la vidéo (secondes).
const TENUE := 2.0

var tl: TimeLapse
## Callable() -> [Transform3D, fov] : la vue actuelle du joueur (nouvelle caméra, recadrer).
var vue_actuelle: Callable
var ambiance: DayNight

var cam_id := -1
var image := 0
var ips := 12
var lecture := false
var incruster := true
var logo := true
var _acc := 0.0
var _pause_avant := false
var _export_en_cours := false
var _cache := {}

var _fond: ColorRect
var _cams: ChoixVisuel
var _ratio: AspectRatioContainer
var _ecran: Control
var _tex: TextureRect
var _date: Label
var _hab: Label
var _logo: Label
var _vide: Label
var _jouer: Button
var _curseur: HSlider
var _pos: Label
var _liste: VBoxContainer
var _etat: Label
var _rec: CheckBox
var _inter: ChoixVisuel
var _qual: ChoixVisuel
var _fmt: ChoixVisuel
var _frise: Button
var _apercu: Control
var _apercu_tex: TextureRect
var _apercu_info: Label
## Chemin de la dernière frise exportée.
var derniere_frise := ""


func setup(t: TimeLapse) -> void:
	tl = t
	layer = 125
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_construire()
	tl.changed.connect(func() -> void:
		if visible:
			_rafraichir())


func is_open() -> bool:
	return visible


func toggle() -> void:
	set_open(not visible)


func set_open(on: bool) -> void:
	if on == visible:
		return
	visible = on
	if on:
		_pause_avant = get_tree().paused
		if ModePhoto.figeable():
			get_tree().paused = true
		if tl.camera(cam_id).is_empty() and not tl.cameras.is_empty():
			cam_id = int(tl.cameras[0].id)
		image = maxi(_nb() - 1, 0)
		lecture = false
		_rafraichir()
		Son.jouer("ui_ouvrir", -3.0, 0.0, "Interface")
	else:
		lecture = false
		_cache.clear()
		get_tree().paused = _pause_avant
		Son.jouer("ui_fermer", -3.0, 0.0, "Interface")
	ouvert_change.emit(on)


func _nb() -> int:
	var c := tl.camera(cam_id)
	return 0 if c.is_empty() else (c.images as Array).size()


# --- Lecture ---------------------------------------------------------------------

func _process(delta: float) -> void:
	if not visible or not lecture:
		return
	var n := _nb()
	if n <= 1:
		lecture = false
		_maj_jouer()
		return
	_acc += delta * ips
	if _acc >= 1.0:
		var pas := int(_acc)
		_acc -= pas
		image += pas
		if image >= n:
			image = n - 1
			lecture = false
			_maj_jouer()
		_montrer()


func jouer(on: bool) -> void:
	if on and image >= _nb() - 1:
		image = 0
	lecture = on and _nb() > 1
	_acc = 0.0
	_maj_jouer()
	_montrer()


func _maj_jouer() -> void:
	_jouer.text = "Pause" if lecture else "Lecture"
	_jouer.icon = Icones.get_icon("pause" if lecture else "play", 18)


func _texture(c: Dictionary, n: int) -> Texture2D:
	var k := "%d/%d" % [int(c.id), n]
	if _cache.has(k):
		return _cache[k]
	var img := Image.load_from_file(tl.chemin_image(c, n))
	var t: Texture2D = ImageTexture.create_from_image(img) if img != null and not img.is_empty() else null
	if _cache.size() > 90:
		_cache.clear()
	_cache[k] = t
	return t


## Date en toutes lettres de l'instant t (heure locale du lieu).
static func date_texte(t: float, decalage_h := 0.0) -> String:
	var d := Time.get_datetime_dict_from_unix_time(int(t + decalage_h * 3600.0))
	var j := int(d.day)
	return "%s %s %d" % ["1er" if j == 1 else str(j), MOIS[clampi(int(d.month) - 1, 0, 11)], int(d.year)]


static func habitants_texte(n: int) -> String:
	return "%s habitant%s" % [BuildingSystem.format_money(n).trim_suffix(" €"), "s" if n > 1 else ""]


func _decalage() -> float:
	return ambiance.utc_offset() if ambiance != null else 0.0


## Remplit une composition (écran ou export) avec l'image n de la caméra c.
func _remplir(comp: Dictionary, c: Dictionary, n: int, tex: Texture2D) -> void:
	var imgs: Array = c.images
	(comp.tex as TextureRect).texture = tex
	var e: Dictionary = imgs[n] if n < imgs.size() else {}
	# Année de la partie (époques) : « 4 mai 1846 » et non l'année de l'horloge.
	(comp.date as Label).text = FriseVille.date_texte(e, _decalage()) if not e.is_empty() else ""
	(comp.hab as Label).text = habitants_texte(int(e.get("hab", 0))) if not e.is_empty() else ""
	(comp.date as Label).visible = incruster
	(comp.hab as Label).visible = incruster
	(comp.logo as Label).visible = logo


func _montrer() -> void:
	var c := tl.camera(cam_id)
	var n := _nb()
	_vide.visible = n == 0
	if c.is_empty() or n == 0:
		_tex.texture = null
		_date.text = ""
		_hab.text = ""
		_pos.text = "Aucune image pour l'instant." if not c.is_empty() else "Aucune caméra."
		_curseur.max_value = 0
		return
	image = clampi(image, 0, n - 1)
	_ratio.ratio = float(TimeLapse.FORMATS.get(String(c.format), 16.0 / 9.0))
	_remplir({"tex": _tex, "date": _date, "hab": _hab, "logo": _logo}, c, image, _texture(c, image))
	_curseur.max_value = n - 1
	_curseur.set_value_no_signal(image)
	var jours := 0
	if n > 1:
		jours = tl.jour_de(float(c.images[-1].t)) - tl.jour_de(float(c.images[0].t))
	_pos.text = "Image %d / %d   ·   %d jours de jeu en %.1f s" % [image + 1, n, jours, float(n) / ips]


# --- Interface -------------------------------------------------------------------

func _construire() -> void:
	_fond = ColorRect.new()
	_fond.color = Color(0.03, 0.04, 0.04, 0.97)
	_fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fond)
	# En haut : titre, caméra, fermer.
	var haut := HBoxContainer.new()
	haut.set_anchors_preset(Control.PRESET_TOP_WIDE)
	haut.offset_left = 16
	haut.offset_right = -16
	haut.offset_top = 12
	haut.custom_minimum_size = Vector2(0, 40)
	haut.add_theme_constant_override("separation", 10)
	add_child(haut)
	var ic := TextureRect.new()
	ic.texture = Icones.get_icon("appareil_photo", 24, UiStyle.ACCENT)
	ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	haut.add_child(ic)
	var titre := Label.new()
	titre.text = "Time-lapse de la ville"
	titre.add_theme_font_size_override("font_size", 20)
	haut.add_child(titre)
	_cams = ChoixVisuel.new()
	_cams.icone = "appareil_photo"
	_cams.gradue = 0
	_cams.focus_mode = Control.FOCUS_NONE
	_cams.custom_minimum_size = Vector2(260, 0)
	_cams.item_selected.connect(func(i: int) -> void: _choisir(_cams.get_item_id(i)))
	haut.add_child(_cams)
	var esp := Control.new()
	esp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	haut.add_child(esp)
	var x := UiStyle.icon_button("fermer", "Fermer", "Échap", 18, 36)
	x.pressed.connect(func() -> void: set_open(false))
	haut.add_child(x)

	# Au centre : l'image, avec la date et les habitants incrustés.
	_ratio = AspectRatioContainer.new()
	_ratio.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ratio.offset_left = 16
	_ratio.offset_top = 64
	_ratio.offset_right = -COTE_W - 28
	_ratio.offset_bottom = -96
	_ratio.ratio = 16.0 / 9.0
	add_child(_ratio)
	var comp := _composition(18)
	_ecran = comp.racine
	_tex = comp.tex
	_date = comp.date
	_hab = comp.hab
	_logo = comp.logo
	_ratio.add_child(_ecran)
	_vide = Label.new()
	_vide.text = "Pas encore d'image : la caméra prend une photo par jour de jeu, vers midi.\nFondez un village (ou ajoutez une caméra à droite), puis laissez le temps passer."
	_vide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vide.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_vide.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_vide.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	_ecran.add_child(_vide)

	# En bas : lecture, curseur, vitesse, incrustations.
	var bas := VBoxContainer.new()
	bas.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bas.offset_left = 16
	bas.offset_right = -COTE_W - 28
	bas.offset_top = -84
	bas.offset_bottom = -12
	add_child(bas)
	_curseur = HSlider.new()
	_curseur.step = 1
	_curseur.focus_mode = Control.FOCUS_NONE
	_curseur.value_changed.connect(func(v: float) -> void:
		image = int(v)
		_montrer())
	bas.add_child(_curseur)
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", 10)
	bas.add_child(ligne)
	_jouer = Button.new()
	_jouer.focus_mode = Control.FOCUS_NONE
	_jouer.custom_minimum_size = Vector2(110, 34)
	_jouer.pressed.connect(func() -> void: jouer(not lecture))
	ligne.add_child(_jouer)
	var debut := Button.new()
	debut.text = "Début"
	debut.focus_mode = Control.FOCUS_NONE
	debut.pressed.connect(func() -> void:
		image = 0
		_montrer())
	ligne.add_child(debut)
	var vit := ChoixVisuel.new()
	vit.icone = "fast"
	vit.gradue = 1
	vit.focus_mode = Control.FOCUS_NONE
	for v in IPS:
		vit.add_item("%d images/s" % v)
	vit.select(IPS.find(ips))
	vit.item_selected.connect(func(i: int) -> void:
		ips = int(IPS[i])
		_montrer())
	ligne.add_child(vit)
	for spec in [["Date et habitants", true], ["Logo", false]]:
		var cb := CheckBox.new()
		cb.text = spec[0]
		cb.focus_mode = Control.FOCUS_NONE
		cb.button_pressed = incruster if spec[1] else logo
		var est_date: bool = spec[1]
		cb.toggled.connect(func(on: bool) -> void:
			if est_date:
				incruster = on
			else:
				logo = on
			_montrer())
		ligne.add_child(cb)
	_pos = Label.new()
	_pos.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	_pos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pos.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ligne.add_child(_pos)
	_maj_jouer()

	# À droite : caméras, réglages, export.
	var cote := PanelContainer.new()
	UiStyle.style_panel(cote)
	cote.anchor_left = 1.0
	cote.anchor_right = 1.0
	cote.anchor_bottom = 1.0
	cote.offset_left = -COTE_W - 16
	cote.offset_right = -16
	cote.offset_top = 64
	cote.offset_bottom = -12
	add_child(cote)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cote.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 4)
	sc.add_child(v)
	_titre(v, "Caméras")
	_liste = VBoxContainer.new()
	v.add_child(_liste)
	var nouv := HBoxContainer.new()
	v.add_child(nouv)
	_fmt = ChoixVisuel.new()
	_fmt.custom_minimum_size = Vector2(150, 40)
	_fmt.face_image = Vector2(42, 28)
	_fmt.titre = "Format de la caméra"
	for f in [["Paysage", 16.0 / 9.0], ["Vertical 9:16", 9.0 / 16.0], ["Carré", 1.0]]:
		_fmt.add_item(f[0])
		_fmt.set_item_icon(_fmt.item_count - 1, Pictos.cadrage(float(f[1]), 120))
	nouv.add_child(_fmt)
	var ajout := Button.new()
	ajout.text = "Nouvelle : vue actuelle"
	ajout.tooltip_text = "Une caméra fixe filme ce que vous voyez maintenant (fermez cet écran pour cadrer, ou utilisez le mode photo F8)."
	ajout.focus_mode = Control.FOCUS_NONE
	ajout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ajout.pressed.connect(func() -> void:
		var vu := _vue()
		if vu.is_empty():
			return
		var cid := tl.ajouter_camera("Caméra %d" % tl.next_cam, vu[0], vu[1], ["paysage", "vertical", "carre"][_fmt.selected])
		if cid >= 0:
			_choisir(cid)
			message.emit("Time-lapse : nouvelle caméra. Elle prendra sa première image demain vers midi."))
	nouv.add_child(ajout)

	_titre(v, "Réglages")
	_rec = CheckBox.new()
	_rec.text = "Enregistrer le time-lapse"
	_rec.focus_mode = Control.FOCUS_NONE
	_rec.toggled.connect(func(on: bool) -> void: tl.enregistrer = on)
	v.add_child(_rec)
	_inter = ChoixVisuel.new()
	_inter.icone = "horloge"
	_inter.gradue = 1
	_inter.focus_mode = Control.FOCUS_NONE
	for i in TimeLapse.INTERVALLES:
		_inter.add_item("Une image par jour" if i == 1 else ("Une image par mois" if i == 30 else ("Une image par semaine" if i == 7 else "Une image tous les %d jours" % i)))
	_inter.item_selected.connect(func(i: int) -> void: tl.intervalle = int(TimeLapse.INTERVALLES[i]))
	v.add_child(_inter)
	_qual = ChoixVisuel.new()
	_qual.icone = "etoile"
	_qual.gradue = 1
	_qual.focus_mode = Control.FOCUS_NONE
	_qual.add_item("Standard 720p (≈ 100 Ko par image)")
	_qual.add_item("Haute 1080p (≈ 220 Ko par image)")
	_qual.item_selected.connect(func(i: int) -> void: tl.qualite = "haute" if i == 1 else "standard")
	v.add_child(_qual)

	_titre(v, "Partager")
	_frise = Button.new()
	_frise.text = "Frise avant / après (image)"
	_frise.icon = Icones.get_icon("appareil_photo", 18, UiStyle.ACCENT_INK)
	_frise.tooltip_text = "Une seule image à partager : la ville à sa fondation et aujourd'hui, et une frise des années entre les deux (PNG 1920 × 1080)."
	_frise.focus_mode = Control.FOCUS_NONE
	UiStyle.tint_pressed(_frise, UiStyle.ACCENT, UiStyle.ACCENT_INK)
	_frise.add_theme_stylebox_override("normal", UiStyle.flat_box(UiStyle.ACCENT, 8, 6))
	_frise.add_theme_stylebox_override("hover", UiStyle.flat_box(UiStyle.ACCENT.lightened(0.15), 8, 6))
	_frise.add_theme_color_override("font_color", UiStyle.ACCENT_INK)
	_frise.add_theme_color_override("font_hover_color", UiStyle.ACCENT_INK)
	_frise.pressed.connect(exporter_frise)
	v.add_child(_frise)
	_titre(v, "Exporter")
	for spec in [["Exporter la vidéo", true], ["Exporter les images", false]]:
		var b := Button.new()
		b.text = spec[0]
		b.focus_mode = Control.FOCUS_NONE
		var video: bool = spec[1]
		b.pressed.connect(func() -> void: exporter(video))
		v.add_child(b)
	var od := Button.new()
	od.text = "Ouvrir le dossier"
	od.focus_mode = Control.FOCUS_NONE
	od.pressed.connect(func() -> void: OS.shell_open(ProjectSettings.globalize_path(dossier_export())))
	v.add_child(od)
	_etat = Label.new()
	_etat.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_etat.custom_minimum_size = Vector2(COTE_W - 30, 0)
	_etat.add_theme_font_size_override("font_size", 12)
	_etat.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	_etat.text = "Vidéo AVI (VLC, lecteur Windows, montage) ; MP4 en plus si ffmpeg est installé. Les images sont dans Images › MiniBlocs › Time-lapse."
	v.add_child(_etat)
	_construire_apercu()


## Aperçu de la frise exportée, par-dessus l'écran du time-lapse.
func _construire_apercu() -> void:
	_apercu = ColorRect.new()
	(_apercu as ColorRect).color = Color(0, 0, 0, 0.88)
	_apercu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_apercu.visible = false
	add_child(_apercu)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 40
	v.offset_right = -40
	v.offset_top = 24
	v.offset_bottom = -24
	v.add_theme_constant_override("separation", 10)
	_apercu.add_child(v)
	var t := Label.new()
	t.text = "Frise avant / après"
	t.add_theme_font_size_override("font_size", 20)
	t.add_theme_color_override("font_color", UiStyle.ACCENT)
	v.add_child(t)
	_apercu_tex = TextureRect.new()
	_apercu_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_apercu_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_apercu_tex.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_apercu_tex)
	_apercu_info = Label.new()
	_apercu_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apercu_info.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	v.add_child(_apercu_info)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 12)
	v.add_child(h)
	var od := Button.new()
	od.text = "Ouvrir le dossier"
	od.focus_mode = Control.FOCUS_NONE
	od.pressed.connect(func() -> void: OS.shell_open(ProjectSettings.globalize_path(ModePhoto.dossier_photos())))
	h.add_child(od)
	var f := Button.new()
	f.text = "Fermer l'aperçu (Échap)"
	f.focus_mode = Control.FOCUS_NONE
	f.pressed.connect(func() -> void: _apercu.visible = false)
	h.add_child(f)


## Fabrique la frise avant / après de la caméra choisie et l'enregistre dans
## Images › MiniBlocs › Photos. Renvoie le chemin (vide en cas d'échec).
func exporter_frise() -> String:
	var c := tl.camera(cam_id)
	if c.is_empty() or (c.images as Array).size() < 2:
		_etat.text = "La frise a besoin d'au moins deux images de cette caméra : laissez passer quelques jours de jeu."
		return ""
	if _export_en_cours:
		return ""
	_export_en_cours = true
	_frise.disabled = true
	_etat.text = "Frise en cours…"
	var img: Image = await FriseVille.rendre(self, tl, c, _decalage())
	_export_en_cours = false
	_frise.disabled = false
	if img == null:
		_etat.text = "La frise n'a pas pu être faite."
		return ""
	var imgs: Array = c.images
	var an0 := FriseVille.annee(imgs[0], _decalage())
	var an1 := FriseVille.annee(imgs[-1], _decalage())
	var chemin := ModePhoto.dossier_photos().path_join(FriseVille.nom_fichier(c, an0, an1))
	if img.save_png(chemin) != OK:
		_etat.text = "Impossible d'écrire " + chemin
		return ""
	derniere_frise = chemin
	var vrai := ProjectSettings.globalize_path(chemin)
	_etat.text = "Frise enregistrée : " + vrai
	_apercu_tex.texture = ImageTexture.create_from_image(img)
	_apercu_info.text = "Enregistrée dans Images › MiniBlocs › Photos : " + vrai.get_file()
	_apercu.visible = true
	message.emit("Frise avant / après enregistrée : " + vrai)
	Son.jouer("ui_ouvrir", -3.0, 0.0, "Interface")
	return chemin


## Image et incrustations, à la taille de son parent. `px` : taille de la date.
func _composition(px: int) -> Dictionary:
	var racine := Control.new()
	racine.clip_contents = true
	var tex := TextureRect.new()
	tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	racine.add_child(tex)
	var date := _ombre_label(px)
	date.position = Vector2(px, px * 0.8)
	racine.add_child(date)
	var hab := _ombre_label(int(px * 0.75))
	hab.position = Vector2(px, px * 2.4)
	racine.add_child(hab)
	var lg := _ombre_label(int(px * 0.8))
	lg.text = "MiniBlocs"
	lg.add_theme_color_override("font_color", UiStyle.ACCENT)
	lg.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	lg.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	lg.grow_vertical = Control.GROW_DIRECTION_BEGIN
	lg.offset_right = -px
	lg.offset_bottom = -px * 0.7
	racine.add_child(lg)
	return {"racine": racine, "tex": tex, "date": date, "hab": hab, "logo": lg}


func _ombre_label(px: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	l.add_theme_constant_override("shadow_offset_x", maxi(1, px / 12))
	l.add_theme_constant_override("shadow_offset_y", maxi(1, px / 12))
	l.add_theme_constant_override("outline_size", maxi(2, px / 6))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.45))
	return l


func _titre(parent: Control, t: String) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_color_override("font_color", UiStyle.ACCENT)
	l.add_theme_font_size_override("font_size", 15)
	parent.add_child(l)


func _vue() -> Array:
	if vue_actuelle.is_valid():
		return vue_actuelle.call()
	return []


func _choisir(cid: int) -> void:
	cam_id = cid
	image = maxi(_nb() - 1, 0)
	lecture = false
	_rafraichir()


func _rafraichir() -> void:
	if tl.camera(cam_id).is_empty():
		cam_id = int(tl.cameras[0].id) if not tl.cameras.is_empty() else -1
	_cams.clear()
	for c in tl.cameras:
		_cams.add_item("%s (%d)" % [String(c.nom), (c.images as Array).size()], int(c.id))
		if int(c.id) == cam_id:
			_cams.select(_cams.item_count - 1)
	_rec.set_pressed_no_signal(tl.enregistrer)
	_inter.select(maxi(TimeLapse.INTERVALLES.find(tl.intervalle), 0))
	_qual.select(1 if tl.qualite == "haute" else 0)
	for ch in _liste.get_children():
		ch.queue_free()
	if tl.cameras.is_empty():
		var l := Label.new()
		l.text = "Aucune caméra. Une caméra se pose toute seule à la fondation de chaque village."
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(COTE_W - 30, 0)
		l.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
		_liste.add_child(l)
	for c in tl.cameras:
		_ligne_camera(c)
	_frise.disabled = _nb() < 2 or _export_en_cours
	_maj_jouer()
	_montrer()


func _ligne_camera(c: Dictionary) -> void:
	var cid := int(c.id)
	var box := VBoxContainer.new()
	_liste.add_child(box)
	var nom := Button.new()
	var n := (c.images as Array).size()
	nom.text = "%s%s" % ["▶ " if cid == cam_id else "", String(c.nom)]
	nom.alignment = HORIZONTAL_ALIGNMENT_LEFT
	nom.focus_mode = Control.FOCUS_NONE
	nom.flat = cid != cam_id
	nom.pressed.connect(func() -> void: _choisir(cid))
	box.add_child(nom)
	var info := Label.new()
	var etat := "filme" if bool(c.actif) and tl.enregistrer else "en pause"
	info.text = "   %d image%s · %.1f Mo · %s · %s" % [n, "s" if n > 1 else "", tl.poids(c) / 1048576.0, String(c.format), etat]
	info.add_theme_font_size_override("font_size", 11)
	info.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	box.add_child(info)
	if cid != cam_id:
		return
	var row := HBoxContainer.new()
	box.add_child(row)
	var acts := [
		["Recadrer", "Cette caméra prend désormais la vue actuelle (les images déjà prises restent).", func() -> void:
			var vu := _vue()
			if not vu.is_empty():
				tl.recadrer(cid, vu[0], vu[1])
				message.emit("Time-lapse : « %s » recadrée sur la vue actuelle." % String(c.nom))],
		["Reprendre" if not bool(c.actif) else "Suspendre", "Arrêter ou reprendre les images de cette caméra.", func() -> void:
			tl.set_actif(cid, not bool(c.actif))],
		["Effacer", "Effacer toutes les images de cette caméra (elle continue de filmer).", func() -> void:
			_cache.clear()
			tl.effacer_images(cid)],
		["Supprimer", "Supprimer la caméra et ses images.", func() -> void:
			_cache.clear()
			tl.supprimer(cid)],
	]
	for a in acts:
		var b := Button.new()
		b.text = a[0]
		b.tooltip_text = a[1]
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 12)
		b.pressed.connect(a[2])
		row.add_child(b)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var k := event as InputEventKey
	if k == null:
		return
	get_viewport().set_input_as_handled()
	if not k.pressed:
		return
	match k.keycode:
		KEY_ESCAPE:
			if not k.echo:
				if _apercu != null and _apercu.visible:
					_apercu.visible = false
				else:
					set_open(false)
		KEY_F8:
			if not k.echo and k.shift_pressed:
				set_open(false)
		KEY_SPACE:
			if not k.echo:
				jouer(not lecture)
		KEY_LEFT:
			image = maxi(image - 1, 0)
			_montrer()
		KEY_RIGHT:
			image = mini(image + 1, maxi(_nb() - 1, 0))
			_montrer()
		KEY_HOME:
			image = 0
			_montrer()
		KEY_END:
			image = maxi(_nb() - 1, 0)
			_montrer()


# --- Export ----------------------------------------------------------------------

static func dossier_export() -> String:
	var base := OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
	var d := base.path_join("MiniBlocs").path_join("Time-lapse") if base != "" else "user://time-lapse"
	if DirAccess.make_dir_recursive_absolute(d) != OK and base != "":
		d = "user://time-lapse"
		DirAccess.make_dir_recursive_absolute(d)
	return d


## Vidéo AVI faite des JPEG tels quels (sans incrustation) : rapide, sans rendu.
## Renvoie un message d'erreur, vide si tout va bien.
static func avi_brut(t: TimeLapse, c: Dictionary, chemin: String, cadence: int, tenue := TENUE) -> String:
	var imgs: Array = c.images
	if imgs.is_empty():
		return "aucune image"
	var taille := Vector2i.ZERO
	var premiere := Image.load_from_file(t.chemin_image(c, 0))
	if premiere == null or premiere.is_empty():
		return "image introuvable : " + t.chemin_image(c, 0)
	taille = premiere.get_size()
	var avi := AviMjpeg.new()
	if not avi.ouvrir(chemin, taille.x, taille.y, cadence):
		return avi.erreur
	var dernier := PackedByteArray()
	for n in imgs.size():
		var b := FileAccess.get_file_as_bytes(t.chemin_image(c, n))
		if b.is_empty():
			continue
		# Une image d'une autre taille (qualité changée en route) est remise à la taille.
		var img := Image.new()
		if img.load_jpg_from_buffer(b) == OK and img.get_size() != taille:
			avi.ajouter_image(img)
			dernier = avi_dernier_jpeg(img, taille)
			continue
		avi.ajouter_jpeg(b)
		dernier = b
	for i in int(tenue * cadence):
		avi.ajouter_jpeg(dernier)
	avi.fermer()
	return ""


static func avi_dernier_jpeg(img: Image, taille: Vector2i) -> PackedByteArray:
	var i := img.duplicate()
	i.resize(taille.x, taille.y, Image.INTERPOLATE_BILINEAR)
	return i.save_jpg_to_buffer(0.9)


static func ffmpeg_dispo() -> bool:
	var out := []
	return OS.execute("ffmpeg", ["-hide_banner", "-version"], out) == 0


## Exporte la caméra choisie : vidéo (AVI, + MP4 si ffmpeg) ou suite d'images.
func exporter(video: bool) -> void:
	if _export_en_cours:
		return
	var c := tl.camera(cam_id)
	if c.is_empty() or (c.images as Array).is_empty():
		_etat.text = "Rien à exporter : cette caméra n'a pas encore d'image."
		return
	_export_en_cours = true
	lecture = false
	_maj_jouer()
	var nom := ModePhoto.nom_fichier("Time-lapse " + String(c.nom), Time.get_datetime_dict_from_system(), "avi")
	var dossier := dossier_export()
	var avec_rendu := (incruster or logo) and DisplayServer.get_name() != "headless"
	var chemin := ""
	var err := ""
	if video:
		chemin = dossier.path_join(nom)
		if avec_rendu:
			err = await _avi_incruste(c, chemin)
		else:
			err = avi_brut(tl, c, chemin, ips)
	else:
		chemin = dossier.path_join(nom.get_basename())
		err = await _images(c, chemin, avec_rendu)
	_export_en_cours = false
	if err != "":
		_etat.text = "Export impossible : " + err
		return
	var vrai := ProjectSettings.globalize_path(chemin)
	_etat.text = "Exporté : " + vrai
	if video and ffmpeg_dispo():
		var mp4 := vrai.get_basename() + ".mp4"
		OS.create_process("ffmpeg", ["-y", "-loglevel", "error", "-i", vrai, "-c:v", "libx264", "-pix_fmt", "yuv420p",
			"-crf", "20", "-movflags", "+faststart", "-vf", "scale=trunc(iw/2)*2:trunc(ih/2)*2", mp4])
		_etat.text += "\nMP4 en préparation (ffmpeg) : " + mp4
	message.emit("Time-lapse exporté : " + vrai)


## Rend une image avec ses incrustations (date, habitants, logo).
func _rendre_image(sv: SubViewport, comp: Dictionary, c: Dictionary, n: int) -> Image:
	var img := Image.load_from_file(tl.chemin_image(c, n))
	var tex: Texture2D = ImageTexture.create_from_image(img) if img != null and not img.is_empty() else null
	_remplir(comp, c, n, tex)
	sv.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	return sv.get_texture().get_image()


func _sv_export(c: Dictionary) -> Array:
	var first := Image.load_from_file(tl.chemin_image(c, 0))
	var taille := first.get_size() if first != null else TimeLapse.taille_images(String(c.format), tl.qualite)
	var sv := SubViewport.new()
	sv.size = taille
	sv.transparent_bg = false
	sv.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var comp := _composition(maxi(16, int(mini(taille.x, taille.y) * 0.045)))
	(comp.racine as Control).size = Vector2(taille)
	sv.add_child(comp.racine)
	add_child(sv)
	return [sv, comp, taille]


func _avi_incruste(c: Dictionary, chemin: String) -> String:
	var r := _sv_export(c)
	var sv: SubViewport = r[0]
	var taille: Vector2i = r[2]
	var avi := AviMjpeg.new()
	if not avi.ouvrir(chemin, taille.x, taille.y, ips):
		sv.queue_free()
		return avi.erreur
	var n_tot := (c.images as Array).size()
	var dernier := PackedByteArray()
	for n in n_tot:
		var img: Image = await _rendre_image(sv, r[1], c, n)
		if img == null:
			continue
		img.convert(Image.FORMAT_RGB8)
		dernier = img.save_jpg_to_buffer(0.9)
		avi.ajouter_jpeg(dernier)
		if n % 10 == 0:
			_etat.text = "Export de la vidéo : image %d / %d…" % [n + 1, n_tot]
	for i in int(TENUE * ips):
		avi.ajouter_jpeg(dernier)
	avi.fermer()
	sv.queue_free()
	return ""


func _images(c: Dictionary, dossier: String, avec_rendu: bool) -> String:
	if DirAccess.make_dir_recursive_absolute(dossier) != OK:
		return "impossible de créer " + dossier
	var n_tot := (c.images as Array).size()
	if not avec_rendu:
		for n in n_tot:
			DirAccess.copy_absolute(tl.chemin_image(c, n), dossier.path_join("%05d.jpg" % n))
		return ""
	var r := _sv_export(c)
	var sv: SubViewport = r[0]
	for n in n_tot:
		var img: Image = await _rendre_image(sv, r[1], c, n)
		if img != null:
			img.convert(Image.FORMAT_RGB8)
			img.save_jpg(dossier.path_join("%05d.jpg" % n), 0.92)
		if n % 10 == 0:
			_etat.text = "Export des images : %d / %d…" % [n + 1, n_tot]
	sv.queue_free()
	return ""
