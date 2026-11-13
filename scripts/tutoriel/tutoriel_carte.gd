class_name TutorielCarte
extends CanvasLayer
## Carte en haut à gauche de l'écran :
##   - l'étape en cours du tutoriel (titre, explication, touches, progrès,
##     bouton d'action, « Passer », croix pour arrêter) ;
##   - les objectifs visibles en permanence : rang de la ville gérée et ce qui
##     manque pour monter, missions du pays avec leur progrès et leur délai
##     (lus dans Objectifs, rien n'est calculé ici). Clic : panneau Maj+J.
## Masquée en mode Créer et dans l'atelier.

signal objectifs_requested

const W := 340.0
const VERT := Color("7bd389")
const ORANGE := Color("ffb86b")

var tuto: Tutoriel
var obj: Objectifs
## Ville affichée : fonction qui renvoie l'id de la ville gérée (-1 : la première).
var ville_courante: Callable
## Carte cachée (mode Créer, atelier).
var cachee := false

var _col: VBoxContainer
var _tuto_panel: PanelContainer
var _etape_l: Label
var _titre_l: Label
var _texte_l: Label
var _touches_l: Label
var _progres_l: Label
var _action_b: Button
var _passer_b: Button
var _obj_panel: PanelContainer
var _obj_head_l: Label
var _replier_b: Button
var _obj_body: VBoxContainer
var _tick := 0.0
var _sig := ""


func setup(t: Tutoriel, o: Objectifs) -> void:
	tuto = t
	obj = o
	_build()
	tuto.changed.connect(_refresh_tuto)
	if obj != null:
		obj.changed.connect(func() -> void: _tick = 99.0)
	_refresh_tuto()
	_refresh_objectifs()


func _build() -> void:
	layer = 5
	_col = VBoxContainer.new()
	_col.name = "CarteTutoriel"
	_col.position = Vector2(10, UiStyle.SIDE_TOP)
	_col.custom_minimum_size = Vector2(W, 0)
	_col.add_theme_constant_override("separation", 6)
	_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_col)

	# Étape du tutoriel.
	_tuto_panel = PanelContainer.new()
	UiStyle.style_panel(_tuto_panel, 0.92, 12, 12)
	_col.add_child(_tuto_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	_tuto_panel.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	v.add_child(head)
	var ic := TextureRect.new()
	ic.texture = Icones.get_icon("aide", 20, UiStyle.ACCENT)
	ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(ic)
	_etape_l = _label("", 12, UiStyle.TEXT_DIM)
	_etape_l.autowrap_mode = TextServer.AUTOWRAP_OFF
	_etape_l.custom_minimum_size = Vector2.ZERO
	_etape_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_etape_l)
	var x := UiStyle.icon_button("fermer", "Arrêter le tutoriel (relance : F10 → Aide)", "", 16, 28)
	x.pressed.connect(func() -> void:
		tuto.arreter()
		ReglagesPartie.actuel.tutoriel = false)
	head.add_child(x)
	_titre_l = _label("", 17, UiStyle.ACCENT)
	v.add_child(_titre_l)
	_texte_l = _label("", 13)
	v.add_child(_texte_l)
	_touches_l = _label("", 12, UiStyle.TEXT_DIM)
	v.add_child(_touches_l)
	_progres_l = _label("", 13, VERT)
	v.add_child(_progres_l)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	v.add_child(row)
	_action_b = Button.new()
	_action_b.focus_mode = Control.FOCUS_NONE
	_action_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_b.pressed.connect(func() -> void: tuto.agir())
	row.add_child(_action_b)
	_passer_b = Button.new()
	_passer_b.text = "Passer"
	_passer_b.tooltip_text = "Passer cette étape"
	_passer_b.focus_mode = Control.FOCUS_NONE
	_passer_b.pressed.connect(func() -> void: tuto.passer())
	row.add_child(_passer_b)

	# Objectifs à l'écran.
	_obj_panel = PanelContainer.new()
	UiStyle.style_panel(_obj_panel, 0.86, 12, 10)
	_col.add_child(_obj_panel)
	var ov := VBoxContainer.new()
	ov.add_theme_constant_override("separation", 3)
	_obj_panel.add_child(ov)
	var oh := HBoxContainer.new()
	oh.add_theme_constant_override("separation", 6)
	ov.add_child(oh)
	var oi := TextureRect.new()
	oi.texture = Icones.get_icon("trophee", 18, UiStyle.ACCENT)
	oi.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	oh.add_child(oi)
	var ob := Button.new()
	ob.flat = true
	ob.focus_mode = Control.FOCUS_NONE
	ob.alignment = HORIZONTAL_ALIGNMENT_LEFT
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ob.tooltip_text = "Ouvrir le panneau Objectifs (Maj+J)"
	ob.add_theme_font_size_override("font_size", 14)
	ob.pressed.connect(func() -> void: objectifs_requested.emit())
	oh.add_child(ob)
	ob.text = "Objectifs"
	_obj_head_l = _label("", 12, UiStyle.TEXT_DIM)
	_obj_head_l.autowrap_mode = TextServer.AUTOWRAP_OFF
	_obj_head_l.custom_minimum_size = Vector2.ZERO
	oh.add_child(_obj_head_l)
	_replier_b = Button.new()
	_replier_b.flat = true
	_replier_b.focus_mode = Control.FOCUS_NONE
	_replier_b.custom_minimum_size = Vector2(28, 0)
	_replier_b.pressed.connect(func() -> void:
		tuto.replie = not tuto.replie
		_tick = 99.0
		_refresh_objectifs())
	oh.add_child(_replier_b)
	_obj_body = VBoxContainer.new()
	_obj_body.add_theme_constant_override("separation", 2)
	ov.add_child(_obj_body)


func _label(t: String, size := 13, col := UiStyle.TEXT) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(W - 30, 0)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


func _small(t: String, col := UiStyle.TEXT, size := 12) -> Label:
	var l := _label(t, size, col)
	l.custom_minimum_size = Vector2(W - 24, 0)
	return l


func set_cachee(on: bool) -> void:
	cachee = on
	_appliquer_visibilite()


func _appliquer_visibilite() -> void:
	if _col == null:
		return
	_tuto_panel.visible = not cachee and tuto.actif and not tuto.etape_courante().is_empty()
	_obj_panel.visible = not cachee and ReglagesPartie.actuel.objectifs_ecran and obj != null


func _refresh_tuto() -> void:
	_appliquer_visibilite()
	var e := tuto.etape_courante()
	if e.is_empty():
		return
	_etape_l.text = "Tutoriel · étape %d / %d" % [tuto.numero(), tuto.total()]
	_titre_l.text = String(e.titre)
	_texte_l.text = String(e.texte)
	_touches_l.text = String(e.get("touches", ""))
	_touches_l.visible = _touches_l.text != ""
	_action_b.visible = e.has("action")
	if e.has("action"):
		_action_b.text = String(e.action[0])
	_passer_b.visible = String(e.id) != "fin"
	_refresh_progres()


func _refresh_progres() -> void:
	var p := tuto.progres()
	_progres_l.text = p
	_progres_l.visible = p != ""


func _process(delta: float) -> void:
	_appliquer_visibilite()
	_tick += delta
	if _tick < 1.0:
		return
	_tick = 0.0
	if tuto.actif:
		_refresh_progres()
	_refresh_objectifs()


func _ville() -> int:
	var vid := -1
	if ville_courante.is_valid():
		vid = int(ville_courante.call())
	if obj == null or obj.communes == null:
		return -1
	if not obj.communes.villages.has(vid):
		vid = obj.communes.principal()
	return vid


## Lignes du résumé des objectifs : [[texte, couleur, taille]…].
func lignes_objectifs() -> Array:
	var out := []
	if obj == null or obj.communes == null:
		return out
	var vid := _ville()
	if vid < 0 or not obj.communes.villages.has(vid):
		out.append(["Fonde ton village pour recevoir tes premières missions du pays.", UiStyle.TEXT_DIM, 12])
		return out
	var nom := obj.pays.nom_de(vid) if obj.pays != null else "Ta ville"
	var i := obj.palier_de(vid)
	var rang := String(Objectifs.PALIERS[i].nom)
	if i + 1 < Objectifs.PALIERS.size():
		var suivant := String(Objectifs.PALIERS[i + 1].nom)
		out.append(["%s : %s → %s" % [nom, rang, suivant], UiStyle.ACCENT, 13])
		var m := obj.manques(vid)
		if m.is_empty():
			out.append(["  Tout est prêt : le rang arrive demain.", VERT, 12])
		for t in m.slice(0, 3):
			out.append(["  · " + String(t), UiStyle.TEXT, 12])
		if m.size() > 3:
			out.append(["  · et %d autre%s condition%s (Maj+J)" % [m.size() - 3, "s" if m.size() > 4 else "", "s" if m.size() > 4 else ""], UiStyle.TEXT_DIM, 12])
	else:
		out.append(["%s : %s, le plus haut rang !" % [nom, rang], UiStyle.ACCENT, 13])
	if obj.missions.is_empty():
		out.append(["Missions du pays : elles arrivent au prochain jour.", UiStyle.TEXT_DIM, 12])
		return out
	out.append(["Missions du pays", UiStyle.ACCENT, 13])
	var d := obj.jour()
	for mis in obj.missions:
		var reste := int(mis.fin) - d
		var p := obj.progres(mis)
		var col := ORANGE if reste <= 7 else UiStyle.TEXT
		out.append(["  · %s" % String(mis.texte), UiStyle.TEXT, 12])
		var parts: Array[String] = []
		if p != "en cours":
			parts.append(p)
		parts.append("%d j restant%s" % [maxi(reste, 0), "s" if reste > 1 else ""])
		parts.append("prime " + BuildingSystem.format_short(int(mis.prime)))
		out.append(["     " + " · ".join(parts), col, 11])
	return out


func _refresh_objectifs() -> void:
	if _obj_panel == null or not _obj_panel.visible:
		return
	_replier_b.text = "▸" if tuto.replie else "▾"
	_replier_b.tooltip_text = "Déplier les objectifs" if tuto.replie else "Replier les objectifs"
	if obj != null:
		_obj_head_l.text = "%s réputation" % "★".repeat(obj.etoiles()) if obj.etoiles() > 0 else "☆ réputation"
	_obj_body.visible = not tuto.replie
	if tuto.replie:
		return
	var lignes := lignes_objectifs()
	var sig := str(lignes)
	if sig == _sig:
		return
	_sig = sig
	for c in _obj_body.get_children():
		c.queue_free()
	for l in lignes:
		var lab := _small(String(l[0]), l[1], int(l[2]))
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_obj_body.add_child(lab)
