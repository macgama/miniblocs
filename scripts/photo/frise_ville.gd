class_name FriseVille
extends RefCounted
## Frise avant / après de la ville, en une image à partager (PNG 1920 × 1080).
##
## Elle est faite des images du time-lapse (une par jour depuis la fondation,
## Maj+F8) : en haut, la toute première image (« Avant ») et la dernière
## (« Aujourd'hui ») côte à côte ; en bas, une frise de FRISE images régulièrement
## espacées, avec l'année et les habitants sous chacune. Le titre dit d'où à où
## (« Village de Morges, de 1800 à 1846 ») et combien d'habitants en plus.
##
## Rendu avec les vrais textes dans un SubViewport ; sans rendu (serveur, tests),
## les images sont assemblées sans texte (même mise en page).

const TAILLE := Vector2i(1920, 1080)
## Images dans la frise du bas (première et dernière comprises).
const FRISE := 6
const FOND := Color(0.06, 0.08, 0.07)
const MARGE := 40


## Indices de `n` images régulièrement espacées parmi `total` (première et dernière
## comprises, sans doublon).
static func choisir(total: int, n := FRISE) -> Array:
	var out: Array = []
	if total <= 0:
		return out
	if total <= n:
		for i in total:
			out.append(i)
		return out
	for k in n:
		var i := roundi(float(k) * float(total - 1) / float(n - 1))
		if not out.has(i):
			out.append(i)
	return out


## Année d'une image du time-lapse : celle du calendrier de la partie (époques),
## sinon celle de l'horloge.
static func annee(e: Dictionary, decalage_h := 0.0) -> int:
	if e.has("an") and int(e.an) != 0:
		return int(e.an)
	return int(Time.get_datetime_dict_from_unix_time(int(float(e.get("t", 0.0)) + decalage_h * 3600.0)).year)


## Date d'une image en toutes lettres : jour et mois de l'horloge, année de la
## partie (« 4 mai 1846 » dans une partie commencée en 1800).
static func date_texte(e: Dictionary, decalage_h := 0.0) -> String:
	var d := Time.get_datetime_dict_from_unix_time(int(float(e.get("t", 0.0)) + decalage_h * 3600.0))
	var j := int(d.day)
	return "%s %s %d" % ["1er" if j == 1 else str(j), TimeLapsePanel.MOIS[clampi(int(d.month) - 1, 0, 11)], annee(e, decalage_h)]


## Rectangles de la mise en page : avant, après, et ceux de la frise.
static func zones() -> Dictionary:
	var w := float(TAILLE.x)
	var grand := Vector2((w - MARGE * 3) / 2.0, 0)
	grand.y = roundf(grand.x * 9.0 / 16.0)
	var y0 := 132.0
	var avant := Rect2(Vector2(MARGE, y0), grand)
	var apres := Rect2(Vector2(MARGE * 2 + grand.x, y0), grand)
	var frise: Array = []
	var pas := (w - MARGE * 2) / float(FRISE)
	var pw := pas - 18.0
	var ph := roundf(pw * 9.0 / 16.0)
	var y1 := y0 + grand.y + 52.0
	for i in FRISE:
		frise.append(Rect2(Vector2(MARGE + i * pas + 9.0, y1), Vector2(pw, ph)))
	return {"avant": avant, "apres": apres, "frise": frise}


static func titre(c: Dictionary, an0: int, an1: int) -> String:
	var nom := String(c.get("nom", "Ma ville"))
	if an0 == an1:
		return "%s en %d" % [nom, an0]
	return "%s, de %d à %d" % [nom, an0, an1]


## Les années du titre, à part du nom (traduites sans toucher au nom du village).
static func annees_texte(an0: int, an1: int) -> String:
	return str(an0) if an0 == an1 else "%d → %d" % [an0, an1]


static func sous_titre(h0: int, h1: int, jours: int) -> String:
	if jours > 0:
		return "%s → %s  ·  %d jours de jeu" % [TimeLapsePanel.habitants_texte(h0), TimeLapsePanel.habitants_texte(h1), jours]
	return "%s → %s" % [TimeLapsePanel.habitants_texte(h0), TimeLapsePanel.habitants_texte(h1)]


static func nom_fichier(c: Dictionary, an0: int, an1: int) -> String:
	var l := String(c.get("nom", "ville"))
	for ch in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]:
		l = l.replace(ch, " ")
	l = l.strip_edges().substr(0, 40).strip_edges()
	var q := Time.get_datetime_dict_from_system()
	return "MiniBlocs Frise %s %d-%d (%04d-%02d-%02d %02d-%02d-%02d).png" % [l, an0, an1,
		int(q.year), int(q.month), int(q.day), int(q.hour), int(q.minute), int(q.second)]


## Assemble la frise sans texte (aucun rendu nécessaire) : pour les tests et le
## serveur, et comme fond si le rendu échoue.
static func assembler(tl: TimeLapse, c: Dictionary) -> Image:
	var imgs: Array = c.get("images", [])
	if imgs.size() < 2:
		return null
	var out := Image.create(TAILLE.x, TAILLE.y, false, Image.FORMAT_RGB8)
	out.fill(FOND)
	var z := zones()
	_coller(out, tl.chemin_image(c, 0), z.avant)
	_coller(out, tl.chemin_image(c, imgs.size() - 1), z.apres)
	var ids := choisir(imgs.size())
	for k in ids.size():
		_coller(out, tl.chemin_image(c, int(ids[k])), z.frise[k] if k < (z.frise as Array).size() else z.frise[-1])
	return out


## Colle une image en la recadrant pour remplir le rectangle (sans la déformer).
static func _coller(out: Image, chemin: String, r: Rect2) -> void:
	var img := Image.load_from_file(chemin)
	if img == null or img.is_empty():
		return
	if img.get_format() != Image.FORMAT_RGB8:
		img.convert(Image.FORMAT_RGB8)
	var cible := Vector2i(r.size)
	var echelle := maxf(float(cible.x) / img.get_width(), float(cible.y) / img.get_height())
	var tw := maxi(cible.x, ceili(img.get_width() * echelle))
	var th := maxi(cible.y, ceili(img.get_height() * echelle))
	img.resize(tw, th, Image.INTERPOLATE_BILINEAR)
	var src := Rect2i((tw - cible.x) / 2, (th - cible.y) / 2, cible.x, cible.y)
	out.blit_rect(img, src, Vector2i(r.position))


## Rend la frise avec ses textes. `hote` : un nœud dans l'arbre (le panneau).
## Renvoie l'image assemblée sans texte quand il n'y a pas de rendu.
static func rendre(hote: Node, tl: TimeLapse, c: Dictionary, decalage_h := 0.0) -> Image:
	var fond := assembler(tl, c)
	if fond == null:
		return null
	if DisplayServer.get_name() == "headless" or hote == null or not hote.is_inside_tree():
		return fond
	var sv := SubViewport.new()
	sv.size = TAILLE
	sv.transparent_bg = false
	sv.render_target_update_mode = SubViewport.UPDATE_ONCE
	var racine := composition(tl, c, decalage_h, ImageTexture.create_from_image(fond))
	sv.add_child(racine)
	hote.add_child(sv)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := sv.get_texture().get_image()
	sv.queue_free()
	return img if img != null and not img.is_empty() else fond


## Les textes et cadres par-dessus l'image assemblée.
static func composition(tl: TimeLapse, c: Dictionary, decalage_h: float, fond: Texture2D) -> Control:
	var imgs: Array = c.images
	var z := zones()
	var racine := Control.new()
	racine.size = Vector2(TAILLE)
	var tr := TextureRect.new()
	tr.texture = fond
	tr.size = Vector2(TAILLE)
	racine.add_child(tr)
	var e0: Dictionary = imgs[0]
	var e1: Dictionary = imgs[-1]
	var an0 := annee(e0, decalage_h)
	var an1 := annee(e1, decalage_h)
	var jours := tl.jour_de(float(e1.get("t", 0.0))) - tl.jour_de(float(e0.get("t", 0.0)))
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", 24)
	ligne.position = Vector2(MARGE, 22)
	racine.add_child(ligne)
	ligne.add_child(_label(String(c.get("nom", "Ma ville")), 44, Color.WHITE))
	ligne.add_child(_label(annees_texte(an0, an1), 44, UiStyle.ACCENT))
	var st := _label(sous_titre(int(e0.get("hab", 0)), int(e1.get("hab", 0)), jours), 22, UiStyle.TEXT_DIM)
	st.position = Vector2(MARGE, 80)
	racine.add_child(st)
	_etiquette(racine, z.avant, "Avant · %d" % an0, date_texte(e0, decalage_h), an0, e0)
	_etiquette(racine, z.apres, "Aujourd'hui · %d" % an1, date_texte(e1, decalage_h), an1, e1)
	# Frise : un trait, un point et l'année sous chaque image.
	var ids := choisir(imgs.size())
	var r_premier: Rect2 = z.frise[0]
	var y_trait := r_premier.end.y + 20.0
	var trait_ := ColorRect.new()
	trait_.color = Color(UiStyle.ACCENT, 0.7)
	trait_.position = Vector2(MARGE, y_trait)
	trait_.size = Vector2(TAILLE.x - MARGE * 2, 3)
	racine.add_child(trait_)
	var meme_annee := an0 == an1
	for k in ids.size():
		var r: Rect2 = z.frise[k]
		var e: Dictionary = imgs[int(ids[k])]
		var cadre := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.draw_center = false
		sb.border_color = Color(1, 1, 1, 0.5)
		sb.set_border_width_all(2)
		cadre.add_theme_stylebox_override("panel", sb)
		cadre.position = r.position
		cadre.size = r.size
		racine.add_child(cadre)
		var point := ColorRect.new()
		point.color = UiStyle.ACCENT
		point.size = Vector2(12, 12)
		point.position = Vector2(r.get_center().x - 6, y_trait - 4.5)
		racine.add_child(point)
		var quand := date_texte(e, decalage_h) if meme_annee else str(annee(e, decalage_h))
		var la := _label(quand, 26 if not meme_annee else 18, Color.WHITE)
		la.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		la.position = Vector2(r.position.x, y_trait + 14)
		la.size = Vector2(r.size.x, 0)
		racine.add_child(la)
		var lh := _label(TimeLapsePanel.habitants_texte(int(e.get("hab", 0))), 16, UiStyle.TEXT_DIM)
		lh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lh.position = Vector2(r.position.x, y_trait + 48)
		lh.size = Vector2(r.size.x, 0)
		racine.add_child(lh)
	var logo := _label("MiniBlocs", 26, UiStyle.ACCENT)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	logo.position = Vector2(TAILLE.x - MARGE - 400, TAILLE.y - 46)
	logo.size = Vector2(400, 0)
	racine.add_child(logo)
	return racine


static func _etiquette(racine: Control, r: Rect2, mot: String, date: String, _an: int, e: Dictionary) -> void:
	var bande := ColorRect.new()
	bande.color = Color(0, 0, 0, 0.55)
	bande.position = r.position
	bande.size = Vector2(r.size.x, 58)
	racine.add_child(bande)
	var l := _label(mot, 30, UiStyle.ACCENT)
	l.position = r.position + Vector2(16, 8)
	racine.add_child(l)
	var d := _label(date + "  ·  " + TimeLapsePanel.habitants_texte(int(e.get("hab", 0))), 18, Color.WHITE)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	d.position = r.position + Vector2(16, 16)
	d.size = Vector2(r.size.x - 32, 0)
	racine.add_child(d)


static func _label(t: String, px: int, couleur: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", couleur)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("shadow_offset_x", maxi(1, px / 14))
	l.add_theme_constant_override("shadow_offset_y", maxi(1, px / 14))
	return l
