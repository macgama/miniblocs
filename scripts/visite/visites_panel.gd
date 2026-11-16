class_name VisitesPanel
extends Control
## Visites et cartes postales (F12, menu Ville → Visites, ou menu principal →
## « Visiter une ville »). Trois vues :
##  - Ma ville (dans sa partie) : mot d'accueil, livre d'or, partager la ville
##    (.mbloc ou Workshop), courrier reçu (« Aller voir », « Retirer ») ;
##  - Visiter : les villes reçues (dossier d'échange, Workshop) et « Visiter » ;
##  - En visite : écrire une carte postale (texte, timbre, photo de la vue), le
##    livre d'or de la ville, « Terminer la visite ».
## Voir VisiteVille, Courrier et docs/visites.md.

signal closed
signal message(texte: String)

const W := 640.0

## La scène Terre (null depuis le menu principal).
var jeu: Node
var view := ""
var _body: VBoxContainer
var _tabs: HBoxContainer
var _etat: Label
var _texte: TextEdit
var _timbre: OptionButton
var _avec_photo: CheckBox
var _photo: Image
var _miniatures := {}


func _init(j: Node = null, vue := "") -> void:
	jeu = j
	view = vue


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(W, 0)
	UiStyle.style_panel(panel, 0.96, 10, 14)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var icon := TextureRect.new()
	icon.texture = Icones.get_icon("carte_postale", 24, UiStyle.ACCENT)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(icon)
	var t := Label.new()
	t.text = "Visites et cartes postales"
	t.add_theme_font_size_override("font_size", 20)
	t.add_theme_color_override("font_color", UiStyle.ACCENT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var x := Button.new()
	x.text = "Fermer (Échap)"
	x.focus_mode = Control.FOCUS_NONE
	x.pressed.connect(fermer)
	head.add_child(x)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 4)
	v.add_child(_tabs)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(W - 28, 520)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 6)
	scroll.add_child(_body)
	_etat = _label("", UiStyle.GOOD, 13)
	v.add_child(_etat)
	if view == "":
		view = "visite" if VisiteVille.active() else ("ma_ville" if jeu != null else "visiter")
	_construire_onglets()
	refresh()
	if view == "visite":
		_prendre_photo()


func _construire_onglets() -> void:
	for c in _tabs.get_children():
		c.queue_free()
	var specs := []
	if VisiteVille.active():
		specs = [["En visite", "visite"]]
	else:
		if jeu != null:
			specs.append(["Ma ville et mon courrier", "ma_ville"])
		specs.append(["Visiter une ville", "visiter"])
	for s in specs:
		var b := Button.new()
		b.text = s[0]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.button_pressed = s[1] == view
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var id: String = s[1]
		b.pressed.connect(func() -> void: show_view(id))
		_tabs.add_child(b)


func show_view(v: String) -> void:
	view = v
	for b in _tabs.get_children():
		(b as Button).set_pressed_no_signal((b as Button).text == _nom_onglet(v))
	refresh()


func _nom_onglet(v: String) -> String:
	return {"visite": "En visite", "ma_ville": "Ma ville et mon courrier", "visiter": "Visiter une ville"}.get(v, "")


func refresh() -> void:
	for c in _body.get_children():
		c.queue_free()
	match view:
		"visite": _vue_visite()
		"ma_ville": _vue_ma_ville()
		_: _vue_visiter()


func _courrier() -> Courrier:
	return jeu.get("courrier") if jeu != null else null


# --- En visite --------------------------------------------------------------------------------

func _vue_visite() -> void:
	var nom := VisiteVille.titre()
	var de := VisiteVille.auteur()
	_body.add_child(_titre("Visite de « %s »" % nom))
	if VisiteVille.en_ligne:
		_body.add_child(_label("Tu visites une carte entre amis : tu te promènes partout, sans construire ni payer. Tes cartes postales arrivent tout de suite chez les joueurs.", UiStyle.TEXT_DIM))
	else:
		_body.add_child(_label("Ville de %s. Promène-toi (caméra, vue au sol V, à bord E), regarde les panneaux, photographie (F8) : rien de ce que tu fais ici ne change sa ville." % (de if de != "" else "quelqu'un"), UiStyle.TEXT_DIM))
	var accueil := String(VisiteVille.en_cours.get("accueil", ""))
	var cr := _courrier()
	if accueil == "" and cr != null:
		accueil = cr.accueil
	if accueil != "":
		var q := _label("« %s »  · le mot du maire" % accueil, UiStyle.ACCENT, 14)
		_body.add_child(q)

	_body.add_child(_titre("Écrire une carte postale"))
	_texte = TextEdit.new()
	_texte.placeholder_text = "Bravo pour ta place du marché ! Le tram passe pile devant le stade…"
	_texte.custom_minimum_size = Vector2(0, 90)
	_texte.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_texte.text_changed.connect(func() -> void:
		if _texte.text.length() > VisiteVille.MAX_TEXTE:
			_texte.text = _texte.text.left(VisiteVille.MAX_TEXTE)
			_texte.set_caret_column(_texte.text.length()))
	_body.add_child(_texte)
	var h := HBoxContainer.new()
	_body.add_child(h)
	var lt := Label.new()
	lt.text = "Timbre"
	h.add_child(lt)
	_timbre = OptionButton.new()
	for i in VisiteVille.TIMBRES.size():
		_timbre.add_item(VisiteVille.TIMBRES[i], i)
	_timbre.focus_mode = Control.FOCUS_NONE
	h.add_child(_timbre)
	_avec_photo = CheckBox.new()
	_avec_photo.text = "Joindre la photo de la vue"
	_avec_photo.button_pressed = true
	_avec_photo.focus_mode = Control.FOCUS_NONE
	_avec_photo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(_avec_photo)
	var post := Button.new()
	post.text = "Poster la carte"
	post.custom_minimum_size = Vector2(150, 34)
	post.pressed.connect(poster)
	h.add_child(post)
	_body.add_child(_label("La carte est épinglée là où tu regardes. %s" % (
		"Elle part par le serveur." if VisiteVille.en_ligne else
		"Elle devient un fichier .mbloc dans ton dossier d'échange : envoie-le à %s (courriel, Discord…). Dès qu'il le dépose dans son dossier d'échange, elle arrive dans son courrier." % (de if de != "" else "l'auteur de la ville")), UiStyle.TEXT_DIM, 12))
	if not VisiteVille.en_ligne:
		var od := Button.new()
		od.text = "Ouvrir le dossier d'échange"
		od.pressed.connect(func() -> void: OS.shell_open(Partage.dossier_echange()))
		_body.add_child(od)

	if cr != null:
		_body.add_child(_titre("Livre d'or (%d)" % (cr.recues.size() + cr.posees.size())))
		if cr.recues.is_empty() and cr.posees.is_empty():
			_body.add_child(_label("Personne n'a encore laissé de carte ici : tu es le premier !", UiStyle.TEXT_DIM))
		for c in cr.posees:
			_body.add_child(_ligne_carte(c, false, true))
		for i in range(cr.recues.size() - 1, -1, -1):
			_body.add_child(_ligne_carte(cr.recues[i], false, false))

	var fin := Button.new()
	fin.text = "Terminer la visite"
	fin.custom_minimum_size = Vector2(0, 40)
	fin.pressed.connect(terminer)
	_body.add_child(fin)


## Photo de la vue (sans l'interface), prise à l'ouverture du panneau.
func _prendre_photo() -> void:
	if DisplayServer.get_name() == "headless" or jeu == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var sv := SubViewport.new()
	sv.size = Courrier.PHOTO_MAX
	sv.world_3d = get_viewport().find_world_3d()
	sv.render_target_update_mode = SubViewport.UPDATE_ONCE
	sv.process_mode = Node.PROCESS_MODE_ALWAYS
	var c := Camera3D.new()
	c.fov = cam.fov
	c.near = cam.near
	c.far = cam.far
	c.environment = cam.environment
	c.attributes = cam.attributes
	sv.add_child(c)
	add_child(sv)
	c.global_transform = cam.global_transform
	c.current = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	if is_instance_valid(sv):
		_photo = sv.get_texture().get_image()
		sv.queue_free()


## Où est le visiteur : le point visé par la caméra, et la caméra elle-même.
func _ou() -> Dictionary:
	if jeu == null:
		return {"p": Vector2.ZERO, "cam": {}}
	var rig: Node3D = jeu.rig
	var p := Vector2(rig.position.x, rig.position.z)
	var vue := jeu.get_node_or_null("VueSol")
	if vue != null and vue.get("personnage") != null and int(vue.get("vue")) != 0:
		var pers: Node3D = vue.personnage
		p = Vector2(pers.global_position.x, pers.global_position.z)
	var cam := {"x": snappedf(rig.position.x, 0.01), "z": snappedf(rig.position.z, 0.01),
		"distance": snappedf(float(rig.get("_target_distance")), 0.01), "angle": snappedf(rig.rotation_degrees.y, 0.01)}
	if rig.has_method("get_target_pitch"):
		cam["inclinaison"] = snappedf(rig.get_target_pitch(), 0.1)
	return {"p": p, "cam": cam}


func poster() -> void:
	var t := _texte.text.strip_edges()
	if t == "":
		_etat.text = "Écris quelques mots sur la carte."
		return
	var ou := _ou()
	var c := VisiteVille.carte(t, ou.p, ou.cam, _timbre.selected, _photo if _avec_photo.button_pressed else null)
	var path := VisiteVille.poster(c)
	var cr := _courrier()
	# En ligne, la carte revient du serveur avec celles des autres.
	if cr != null and not VisiteVille.en_ligne:
		cr.poser(c)
	Succes.ajouter("cartes_postales")
	_texte.text = ""
	refresh()
	if VisiteVille.en_ligne:
		_etat.text = "Carte postale envoyée."
	elif path != "":
		_etat.text = "Carte postale prête : %s" % ProjectSettings.globalize_path(path)
	else:
		_etat.text = "La carte n'a pas pu s'écrire dans le dossier d'échange."
	message.emit("Carte postale postée.")


func terminer() -> void:
	fermer()
	if VisiteVille.en_ligne:
		var cl := Multijoueur.client_actif()
		if cl != null:
			cl.deconnecter("Fin de la visite.")
		VisiteVille.oublier()
		EcranChargement.aller(MenuPrincipal.SCENE, "Retour au menu principal")
		return
	VisiteVille.terminer()


# --- Ma ville ---------------------------------------------------------------------------------

func _vue_ma_ville() -> void:
	var cr := _courrier()
	if cr == null:
		return
	_body.add_child(_titre("Faire visiter ma ville"))
	var en_ligne := Multijoueur.en_ligne()
	if en_ligne:
		_body.add_child(_label("Sur une carte entre amis, on visite en ligne : tes amis choisissent « Visiter » dans Entre amis (avec le code d'invitation). Leurs cartes postales arrivent ici.", UiStyle.TEXT_DIM))
	else:
		_body.add_child(_label("Ta ville part dans un fichier .mbloc (ou sur le Workshop). Les visiteurs se promènent dedans sans rien pouvoir changer, puis te laissent une carte postale.", UiStyle.TEXT_DIM))
	var la := Label.new()
	la.text = "Mot d'accueil pour les visiteurs"
	_body.add_child(la)
	var acc := LineEdit.new()
	acc.text = cr.accueil
	acc.max_length = VisiteVille.MAX_TEXTE
	acc.placeholder_text = "Bienvenue à Valfleuri ! Ne ratez pas le funiculaire."
	acc.text_changed.connect(func(s: String) -> void:
		cr.accueil = s
		if jeu.get("_unsaved") != null:
			jeu._unsaved = true)
	_body.add_child(acc)
	var lo := CheckBox.new()
	lo.text = "Livre d'or : les visiteurs voient les cartes que j'ai reçues"
	lo.button_pressed = cr.livre_or
	lo.toggled.connect(func(on: bool) -> void: cr.livre_or = on)
	_body.add_child(lo)
	var mo := CheckBox.new()
	mo.text = "Montrer les cartes dans la ville, là où elles ont été écrites"
	mo.button_pressed = cr.montrer
	mo.toggled.connect(func(on: bool) -> void: cr.set_montrer(on))
	_body.add_child(mo)
	if not en_ligne:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		_body.add_child(h)
		var fic := Button.new()
		fic.text = "Fichier .mbloc de ma ville"
		fic.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fic.pressed.connect(partager_fichier)
		h.add_child(fic)
		var pub := Button.new()
		pub.text = "Publier sur le Workshop" if Partage.backend().est_steam() else "Publier (atelier local)"
		pub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pub.pressed.connect(publier)
		h.add_child(pub)
		var od := Button.new()
		od.text = "Dossier d'échange"
		od.pressed.connect(func() -> void: OS.shell_open(Partage.dossier_echange()))
		h.add_child(od)

	var nl := cr.non_lues()
	_body.add_child(_titre("Courrier reçu (%d%s)" % [cr.recues.size(), ", %d nouvelle%s" % [nl, "s" if nl > 1 else ""] if nl > 0 else ""]))
	if not en_ligne:
		var rel := Button.new()
		rel.text = "Relever le courrier (dossier d'échange)"
		rel.pressed.connect(func() -> void:
			var n := cr.relever()
			refresh()
			_etat.text = "%d carte%s nouvelle%s." % [n, "s" if n > 1 else "", "s" if n > 1 else ""] if n > 0 else "Pas de nouvelle carte dans le dossier d'échange.")
		_body.add_child(rel)
	if cr.recues.is_empty():
		_body.add_child(_label("Pas encore de carte. Partage ta ville : les visiteurs t'en écriront !", UiStyle.TEXT_DIM))
	for i in range(cr.recues.size() - 1, -1, -1):
		_body.add_child(_ligne_carte(cr.recues[i], true, false))


func _remplacer() -> Dictionary:
	var cr := _courrier()
	return {"courrier": cr.pour_partage()} if cr != null else {}


func partager_fichier() -> void:
	if not jeu.save_game():
		_etat.text = "Sauvegarde impossible : %s" % String(jeu.last_error)
		return
	var cr := _courrier()
	var path := VisiteVille.exporter(GameStart.slot_id, cr.accueil if cr else "", "", _remplacer())
	if path == "":
		_etat.text = "Le fichier de la ville n'a pas pu s'écrire."
		return
	_etat.text = "Ville prête : %s — envoie ce fichier à qui tu veux." % ProjectSettings.globalize_path(path)


func publier() -> void:
	if not jeu.save_game():
		_etat.text = "Sauvegarde impossible : %s" % String(jeu.last_error)
		return
	var cr := _courrier()
	var err := VisiteVille.publier(GameStart.slot_id, cr.accueil if cr else "", "", _remplacer())
	_etat.text = err if err != "" else ("Envoi sur le Workshop…" if Partage.backend().est_steam() else "Ville publiée dans l'atelier local (avec son fichier .mbloc dans le dossier d'échange).")


# --- Visiter ----------------------------------------------------------------------------------

func _vue_visiter() -> void:
	_body.add_child(_titre("Villes à visiter"))
	_body.add_child(_label("Un ami t'a envoyé sa ville ? Dépose le fichier .mbloc dans le dossier d'échange, puis « Recevoir ». Les villes du Workshop arrivent ici toutes seules. Pour la carte entre amis d'un ami : menu principal → Entre amis → « Visiter ».", UiStyle.TEXT_DIM))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	_body.add_child(h)
	var rec := Button.new()
	rec.text = "Recevoir"
	rec.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rec.pressed.connect(func() -> void:
		var r := VisiteVille.recevoir_echange()
		Partage.synchroniser()
		refresh()
		var e: Array = r.erreurs
		_etat.text = ("%d ville%s reçue%s." % [int(r.nouvelles), "s" if int(r.nouvelles) > 1 else "", "s" if int(r.nouvelles) > 1 else ""] if int(r.nouvelles) > 0 else "Pas de nouvelle ville dans le dossier d'échange.") + ("" if e.is_empty() else " " + "; ".join(e)))
	h.add_child(rec)
	var od := Button.new()
	od.text = "Ouvrir le dossier d'échange"
	od.pressed.connect(func() -> void: OS.shell_open(Partage.dossier_echange()))
	h.add_child(od)
	var liste := VisiteVille.villes()
	if liste.is_empty():
		_body.add_child(_label("Aucune ville reçue pour l'instant.", UiStyle.TEXT_DIM))
	for v in liste:
		_body.add_child(_ligne_ville(v))


func _ligne_ville(v: Dictionary) -> Control:
	var f: Dictionary = v.fiche
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UiStyle.flat_box(Color(1, 1, 1, 0.05), 8, 6))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	box.add_child(h)
	var img := PaquetPartage.apercu_dossier(String(v.dossier))
	if img != null:
		var tr := TextureRect.new()
		tr.texture = ImageTexture.create_from_image(img)
		tr.custom_minimum_size = Vector2(128, 72)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		h.add_child(tr)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(col)
	col.add_child(_label(String(f.get("titre", "?")), UiStyle.ACCENT, 15))
	col.add_child(_label("de %s · %s" % [String(f.get("auteur", "?")), String(f.get("resume", ""))], UiStyle.TEXT_DIM, 12))
	var d := String(f.get("description", ""))
	if d != "":
		col.add_child(_label("« %s »" % d.left(160), UiStyle.TEXT, 12))
	var go := Button.new()
	go.text = "Visiter"
	go.custom_minimum_size = Vector2(90, 34)
	var dir := String(v.dossier)
	go.pressed.connect(func() -> void:
		var err := VisiteVille.visiter_dossier(dir, jeu)
		if err != "":
			_etat.text = "Visite impossible : " + err
		else:
			fermer())
	h.add_child(go)
	var del := UiStyle.icon_button("gomme", "Retirer de la liste", "", 18, 32)
	del.pressed.connect(func() -> void:
		VisiteVille.retirer(dir)
		refresh())
	h.add_child(del)
	return box


# --- Une carte postale ------------------------------------------------------------------------

func _ligne_carte(c: Dictionary, a_moi: bool, de_moi: bool) -> Control:
	var box := PanelContainer.new()
	var neuve := a_moi and _courrier() != null and not _courrier().lues.has(String(c.id))
	box.add_theme_stylebox_override("panel", UiStyle.flat_box(Color(1, 0.85, 0.4, 0.10) if neuve else Color(1, 1, 1, 0.05), 8, 6))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	box.add_child(h)
	var img := Courrier.photo_de(c)
	if img != null:
		var tr := TextureRect.new()
		tr.texture = ImageTexture.create_from_image(img)
		tr.custom_minimum_size = Vector2(120, 68)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		h.add_child(tr)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(col)
	var tim: String = VisiteVille.TIMBRES[clampi(int(c.get("timbre", 0)), 0, VisiteVille.TIMBRES.size() - 1)]
	var qui := "Toi" if de_moi else String(c.get("de", "?"))
	col.add_child(_label("%s · %s · timbre « %s »%s" % [qui, date(int(c.get("quand", 0))), tim, "  · nouvelle" if neuve else ""], UiStyle.ACCENT, 13))
	col.add_child(_label(String(c.get("texte", "")), UiStyle.TEXT, 13))
	var bs := VBoxContainer.new()
	h.add_child(bs)
	var go := Button.new()
	go.text = "Aller voir"
	go.pressed.connect(func() -> void:
		aller_voir(c)
		if a_moi and _courrier() != null:
			_courrier().marquer_lue(String(c.id))
		fermer())
	bs.add_child(go)
	if a_moi:
		if neuve:
			var lu := Button.new()
			lu.text = "Lue"
			lu.pressed.connect(func() -> void:
				_courrier().marquer_lue(String(c.id))
				refresh())
			bs.add_child(lu)
		var del := Button.new()
		del.text = "Retirer"
		del.pressed.connect(func() -> void:
			_courrier().retirer(String(c.id))
			refresh())
		bs.add_child(del)
	return box


## Caméra sur l'endroit où la carte a été écrite.
func aller_voir(c: Dictionary) -> void:
	if jeu == null:
		return
	var rig: Node3D = jeu.rig
	var cam: Dictionary = c.get("cam", {})
	rig.position.x = float(cam.get("x", c.get("x", 0.0)))
	rig.position.z = float(cam.get("z", c.get("z", 0.0)))
	if cam.has("distance"):
		rig.set("_target_distance", float(cam.distance))
	if cam.has("angle"):
		rig.rotation_degrees.y = float(cam.angle)
	if cam.has("inclinaison") and rig.has_method("set_pitch"):
		rig.set_pitch(float(cam.inclinaison), true)
	if jeu.get("_snap_pending") != null:
		jeu._snap_pending = true


static func date(t: int) -> String:
	if t <= 0:
		return "?"
	var d := Time.get_datetime_dict_from_unix_time(t)
	return "%02d/%02d/%04d" % [d.day, d.month, d.year]


# --- Petits outils ----------------------------------------------------------------------------

func _titre(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 17)
	l.add_theme_color_override("font_color", UiStyle.ACCENT)
	return l


func _label(t: String, c: Color, px := 13) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(300, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", c)
	return l


func fermer() -> void:
	closed.emit()
	queue_free()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and (k.keycode == KEY_ESCAPE or k.keycode == KEY_F12):
		get_viewport().set_input_as_handled()
		fermer()
