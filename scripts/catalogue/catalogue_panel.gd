class_name CataloguePanel
extends Control
## Fenêtre « Catalogue » (Maj+F1, menu Infos) : tout ce qui se construit ou se pose
## dans le jeu (bâtiments, véhicules, voies, réseaux, agriculture, attractions,
## Atelier, décors, meubles), avec son année d'apparition et ses évolutions
## (agrandissements, variantes, modèle de chaque époque). Le curseur « Partie
## en » montre ce qui existe à n'importe quelle année ; il part de l'année de
## la partie en cours.

signal closed

const W := 860.0
const H := 520.0
## Lignes affichées au plus (la recherche affine le reste).
const MAX_LIGNES := 250

var famille := ""
var etat := "tout"
var texte := ""
var annee := 2026

var _liste: VBoxContainer
var _titre: Label
var _resume: Label
var _annee_l: Label
var _curseur: HSlider
var _familles: OptionButton
var _etats: OptionButton


func _ready() -> void:
	annee = Epoques.annee() if Epoques.actif() else int(Time.get_date_dict_from_system().year)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	UiStyle.style_panel(panel, 0.97, 12, 16)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)

	var head := HBoxContainer.new()
	v.add_child(head)
	var ic := TextureRect.new()
	ic.texture = Icones.get_icon("journal", 26, UiStyle.ACCENT)
	ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(ic)
	_titre = Label.new()
	_titre.add_theme_font_size_override("font_size", 22)
	_titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_titre)
	var close := Button.new()
	close.name = "Fermer"
	close.text = "Fermer (Échap)"
	close.pressed.connect(close_panel)
	head.add_child(close)

	var filtres := HBoxContainer.new()
	filtres.add_theme_constant_override("separation", 8)
	v.add_child(filtres)
	_familles = OptionButton.new()
	_familles.add_item("Toutes les familles")
	_familles.set_item_metadata(0, "")
	for f in CatalogueJeu.FAMILLES:
		_familles.add_item("%s (%d)" % [f[1], CatalogueJeu.de_famille(String(f[0])).size()])
		_familles.set_item_metadata(_familles.item_count - 1, String(f[0]))
	_familles.item_selected.connect(func(i: int) -> void:
		famille = String(_familles.get_item_metadata(i))
		refresh())
	filtres.add_child(_familles)
	_etats = OptionButton.new()
	for spec in [["tout", "Tout"], ["dispo", "Déjà inventé"], ["avenir", "Pas encore inventé"]]:
		_etats.add_item(String(spec[1]))
		_etats.set_item_metadata(_etats.item_count - 1, String(spec[0]))
	_etats.item_selected.connect(func(i: int) -> void:
		etat = String(_etats.get_item_metadata(i))
		refresh())
	filtres.add_child(_etats)
	var recherche := LineEdit.new()
	recherche.placeholder_text = "Chercher (moulin, tram, looping…)"
	recherche.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recherche.text_changed.connect(func(t: String) -> void:
		texte = t
		refresh())
	filtres.add_child(recherche)

	var ligne_an := HBoxContainer.new()
	ligne_an.add_theme_constant_override("separation", 10)
	v.add_child(ligne_an)
	var l := Label.new()
	l.text = "Partie en"
	ligne_an.add_child(l)
	_curseur = HSlider.new()
	_curseur.min_value = Epoques.ANNEE_MIN
	_curseur.max_value = 2040
	_curseur.step = 1
	_curseur.value = clampi(annee, Epoques.ANNEE_MIN, 2040)
	_curseur.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_curseur.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_curseur.value_changed.connect(func(x: float) -> void:
		annee = int(x)
		refresh())
	ligne_an.add_child(_curseur)
	_annee_l = Label.new()
	_annee_l.custom_minimum_size = Vector2(48, 0)
	_annee_l.add_theme_font_size_override("font_size", 18)
	_annee_l.add_theme_color_override("font_color", UiStyle.ACCENT)
	ligne_an.add_child(_annee_l)
	if Epoques.actif():
		var ici := Button.new()
		ici.text = "Année de la partie"
		ici.tooltip_text = "Revenir à l'année en cours (%d)" % Epoques.annee()
		ici.pressed.connect(func() -> void: _curseur.value = Epoques.annee())
		ligne_an.add_child(ici)

	_resume = Label.new()
	_resume.add_theme_font_size_override("font_size", 12)
	_resume.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	v.add_child(_resume)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(W, H)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var marge := MarginContainer.new()
	marge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	marge.add_theme_constant_override("margin_right", 14)
	scroll.add_child(marge)
	_liste = VBoxContainer.new()
	_liste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_liste.add_theme_constant_override("separation", 4)
	marge.add_child(_liste)

	var note := Label.new()
	note.add_theme_font_size_override("font_size", 12)
	note.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(W, 0)
	note.text = ("Partie historique : %s. " % Epoques.resume() if Epoques.actif() else "Partie à l'époque actuelle : tout est déjà inventé. L'année de départ (dès 1800) se choisit sur le globe ou dans l'Admin (F10). ") \
		+ "« toujours » : déjà là en 1800. Le même catalogue est dans docs/catalogue."
	v.add_child(note)
	refresh()
	recherche.grab_focus.call_deferred()


func refresh() -> void:
	_annee_l.text = str(annee)
	for c in _liste.get_children():
		c.queue_free()
	var es := CatalogueJeu.filtre(famille, texte, annee, etat)
	es.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if String(a.fam) != String(b.fam):
			return _rang(String(a.fam)) < _rang(String(b.fam))
		if String(a.groupe) != String(b.groupe):
			return String(a.groupe) < String(b.groupe)
		if int(a.annee) != int(b.annee):
			return int(a.annee) < int(b.annee)
		return String(a.nom).naturalnocasecmp_to(String(b.nom)) < 0)
	var dispo := 0
	for e: Dictionary in es:
		if int(e.annee) <= annee:
			dispo += 1
	var total := CatalogueJeu.entrees().size()
	_titre.text = "Catalogue : %d objets" % total
	_resume.text = "%d affichés, dont %d déjà inventés en %d%s." % [es.size(), dispo, annee,
		"" if es.size() <= MAX_LIGNES else " (les %d premiers : affine la recherche)" % MAX_LIGNES]
	var groupe := ""
	var n := 0
	for e: Dictionary in es:
		if n >= MAX_LIGNES:
			break
		var g := "%s · %s" % [CatalogueJeu.nom_famille(String(e.fam)), e.groupe]
		if g != groupe:
			groupe = g
			var t := Label.new()
			t.text = g
			t.add_theme_font_size_override("font_size", 14)
			t.add_theme_color_override("font_color", UiStyle.ACCENT)
			_liste.add_child(t)
		_liste.add_child(_ligne(e))
		n += 1
	if es.is_empty():
		var vide := Label.new()
		vide.text = "Rien ne correspond."
		vide.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
		_liste.add_child(vide)


static func _rang(fam: String) -> int:
	for i in CatalogueJeu.FAMILLES.size():
		if CatalogueJeu.FAMILLES[i][0] == fam:
			return i
	return 99


func _ligne(e: Dictionary) -> Control:
	var ok := int(e.annee) <= annee
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiStyle.flat_box(Color(1, 1, 1, 0.06 if ok else 0.025), 7, 6))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	p.add_child(h)
	var an := Label.new()
	an.text = CatalogueJeu.texte_annee(int(e.annee))
	an.custom_minimum_size = Vector2(70, 0)
	an.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	an.add_theme_font_size_override("font_size", 14)
	an.add_theme_color_override("font_color", UiStyle.GOOD if ok else Color("ef9a7a"))
	an.tooltip_text = "Année : " + String(CatalogueJeu.SOURCES.get(String(e.source), e.source))
	an.mouse_filter = Control.MOUSE_FILTER_PASS
	h.add_child(an)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 1)
	h.add_child(v)
	var nom := Label.new()
	nom.text = String(e.nom) if ok else "%s · arrive en %d" % [e.nom, int(e.annee)]
	nom.add_theme_font_size_override("font_size", 14)
	nom.add_theme_color_override("font_color", UiStyle.TEXT if ok else UiStyle.TEXT_DIM)
	v.add_child(nom)
	for k in ["info", "evol"]:
		if String(e[k]) == "":
			continue
		var d := Label.new()
		d.text = String(e[k])
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(W - 120, 0)
		d.add_theme_font_size_override("font_size", 11)
		d.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
		v.add_child(d)
	return p


func close_panel() -> void:
	closed.emit()
	queue_free()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and (k.keycode == KEY_ESCAPE or k.keycode == KEY_F1 and k.shift_pressed):
		get_viewport().set_input_as_handled()
		close_panel()
