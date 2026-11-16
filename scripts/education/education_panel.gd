class_name EducationPanel
extends CanvasLayer
## Panneau « Éducation » (Maj+K) : système scolaire du pays, élèves et places
## par degré, apprentis chez les employeurs, diplômes des adultes, métiers en
## pénurie (frontaliers, pendulaires).

signal focus_requested(pos: Vector3)

const W := 372.0
const H := 560.0
const VUES := [["ecoles", "Écoles"], ["diplomes", "Diplômes et métiers"], ["systeme", "Système"]]

var pop: Population
var view := "ecoles"
## Ville affichée (-1 : toute la carte).
var ville := -1
var _panel: PanelContainer
var _title: Label
var _body: VBoxContainer
var _scroll: ScrollContainer
var _tick := 0.0


func setup(p: Population) -> void:
	pop = p
	_build()


func _build() -> void:
	layer = 6
	_panel = PanelContainer.new()
	UiStyle.place_right(_panel)
	_panel.custom_minimum_size = Vector2(W, 0)
	UiStyle.style_panel(_panel)
	_panel.visible = false
	add_child(_panel)
	var outer := VBoxContainer.new()
	_panel.add_child(outer)
	var head := HBoxContainer.new()
	outer.add_child(head)
	var icon := TextureRect.new()
	icon.texture = Icones.get_icon("ecole", 22, UiStyle.ACCENT)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(icon)
	_title = Label.new()
	_title.text = "Éducation"
	_title.add_theme_font_size_override("font_size", 16)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	var x := UiStyle.icon_button("fermer", "Fermer", "Maj+K", 18, 32)
	x.pressed.connect(func() -> void: set_open(false))
	head.add_child(x)
	var tabs := HBoxContainer.new()
	outer.add_child(tabs)
	for v in VUES:
		var b := Button.new()
		b.text = String(v[1])
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var id: String = v[0]
		b.pressed.connect(func() -> void: show_view(id))
		tabs.add_child(b)
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(W, H)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 3)
	_scroll.add_child(_body)


func is_open() -> bool:
	return _panel.visible


func set_open(on: bool) -> void:
	_panel.visible = on
	if on:
		refresh()


func toggle() -> void:
	set_open(not _panel.visible)


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.physical_keycode == KEY_K and k.shift_pressed and not k.ctrl_pressed:
		toggle()
		get_viewport().set_input_as_handled()


func show_view(v: String) -> void:
	view = v
	refresh()
	_scroll.scroll_vertical = 0


func _process(delta: float) -> void:
	if not is_open():
		return
	_tick += delta
	if _tick >= 3.0:
		_tick = 0.0
		var keep := _scroll.scroll_vertical
		refresh()
		_scroll.set_deferred("scroll_vertical", keep)


func refresh() -> void:
	if pop == null:
		return
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	_choix_ville()
	match view:
		"diplomes":
			_view_diplomes()
		"systeme":
			_view_systeme()
		_:
			_view_ecoles()


# --- Petits outils -------------------------------------------------------------------------

func _text(t: String, dim := false, size := 13) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(W - 30, 0)
	l.add_theme_font_size_override("font_size", size)
	if dim:
		l.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
	_body.add_child(l)
	return l


func _section(t: String) -> void:
	_body.add_child(HSeparator.new())
	var l := _text(t, false, 15)
	l.add_theme_color_override("font_color", UiStyle.ACCENT)


func _bouton(t: String, f: Callable, tip := "") -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 12)
	b.custom_minimum_size = Vector2(W - 30, 0)
	b.tooltip_text = tip
	b.pressed.connect(f)
	_body.add_child(b)
	return b


func _choix_ville() -> void:
	var cm := Communes.instance
	if cm == null or cm.villages.is_empty():
		ville = -1
		return
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = "Ville : "
	row.add_child(l)
	var pick := OptionButton.new()
	pick.focus_mode = Control.FOCUS_NONE
	pick.add_item("Toute la carte", 0)
	var ids: Array = cm.villages.keys()
	ids.sort()
	var i := 1
	for vid in ids:
		pick.add_item(String(cm.villages[vid].nom), i)
		pick.set_item_metadata(i, int(vid))
		if int(vid) == ville:
			pick.select(i)
		i += 1
	pick.set_item_metadata(0, -1)
	pick.item_selected.connect(func(idx: int) -> void:
		ville = int(pick.get_item_metadata(idx))
		refresh())
	row.add_child(pick)
	_body.add_child(row)


func _sys_affiche() -> String:
	var cm := Communes.instance
	if ville >= 0 and cm != null and cm.villages.has(ville):
		for bid in pop.known:
			if cm.village_de(bid) == ville:
				return pop.edu.systeme_batiment(bid)
	return pop.edu.systeme_du_code(GameStart.pays.to_lower())


# --- Écoles --------------------------------------------------------------------------------

func _view_ecoles() -> void:
	var sys := _sys_affiche()
	var an := pop.edu.annee()
	_title.text = "Éducation · écoles (%s, %d)" % [SystemesScolaires.NOMS.get(sys, sys), an]
	var b := pop.edu.bilan(ville)
	_text("Élèves sans place en scolarité obligatoire : %d · secondaire I en classes à plusieurs degrés : %d · élèves et apprentis qui étudient dans une autre ville : %d" % [
		int(b.sans_ecole), int(b.multi), int(b.eleves_ailleurs)], true, 12)
	_section("Par degré")
	for c in SystemesScolaires.CYCLES:
		if sys == "fr" and c == "ecg":
			continue
		var e: Dictionary = b.cycles[c]
		var ligne := "%s : %d élève%s · %d places dans %d bâtiment%s" % [SystemesScolaires.nom_cycle(sys, c, an), int(e.eleves),
			"s" if int(e.eleves) > 1 else "", int(e.places), int(e.batiments), "s" if int(e.batiments) > 1 else ""]
		if int(e.ailleurs) > 0:
			ligne += " · %d ailleurs" % int(e.ailleurs)
		var l := _text(ligne, false, 12)
		if int(e.batiments) == 0 and (int(e.ailleurs) > 0 or (c in Education.OBLIGATOIRES and int(b.sans_ecole) > 0)):
			l.add_theme_color_override("font_color", Color(1.0, 0.7, 0.35))
	_text("Bâtiments : crèche (école enfantine), école (enfantine, primaire), collège (secondaire I), lycée ou gymnase (maturité, bac, culture générale), école professionnelle (apprentis), haute école (HES, IUT), HEP, université ; résidence étudiante pour loger les étudiants. B → Services publics.", true, 11)
	_section("Apprentis : %d" % int(b.apprentis))
	if (b.par_employeur as Dictionary).is_empty():
		_text("Aucun contrat d'apprentissage. Les jeunes qui choisissent l'apprentissage (CFC, CAP) cherchent une entreprise formatrice en ville : boulangeries, ateliers, usines, commerces, fermes, hôpital, crèche…", true, 12)
	var emp: Array = (b.par_employeur as Dictionary).keys()
	emp.sort_custom(func(x: int, y: int) -> bool: return int(b.par_employeur[x]) > int(b.par_employeur[y]))
	for j in emp.slice(0, 12):
		var pos := pop.building_pos(int(j))
		_bouton("%s : %d apprenti%s" % [pop.building_name(int(j)), int(b.par_employeur[j]), "s" if int(b.par_employeur[j]) > 1 else ""],
			func() -> void: focus_requested.emit(pos), "Clique pour y aller.")
	_section("Étudiants")
	_text("En ville : %d · hors de la ville : %d" % [int(b.etudiants_ici), int(b.etudiants_ailleurs)])
	_text("Avec une haute école ou une université en ville, les étudiants restent (et dépensent) ici ; une résidence étudiante en attire d'ailleurs.", true, 11)


# --- Diplômes et métiers -----------------------------------------------------------------

func _view_diplomes() -> void:
	var an := pop.edu.annee()
	_title.text = "Éducation · diplômes et métiers"
	var b := pop.edu.bilan(ville)
	var tot := maxi(1, int(b.adultes))
	_section("Plus haut diplôme des adultes (%d)" % int(b.adultes))
	for n in range(SystemesScolaires.NIVEAUX.size() - 1, -1, -1):
		var k := int(b.niveaux[n])
		_text("%s : %d (%d %%)" % [SystemesScolaires.NIVEAUX[n], k, roundi(100.0 * k / tot)], false, 12)
	_text("Actifs sans le diplôme conseillé pour leur métier : %d (ils travaillent moins vite : production −%d %% chacun)." % [
		int(b.non_qualifies), roundi(100.0 * (1.0 - Education.RENDEMENT_NON_QUALIFIE))], true, 12)
	_section("Métiers en pénurie")
	var pen := pop.edu.penuries(ville)
	if pen.is_empty():
		_text("Aucune : tous les postes qui exigent un diplôme sont tenus par des habitants de la ville.", true)
	for e in pen.slice(0, 14):
		var m := String(e.metier)
		var ligne := "%s : %d %s, %d poste%s vacant%s" % [Metiers.job(m).name, int(e.externes),
			"frontaliers" if String(e.origine) == "frontaliers" else "pendulaires", int(e.vacants), "s" if int(e.vacants) > 1 else "",
			"s" if int(e.vacants) > 1 else ""]
		_text(ligne, false, 12)
		_text("   exige : " + SystemesScolaires.texte_exigence(m, an), true, 11)
	_text("Sans habitant diplômé, un poste obligatoire reste vide : des frontaliers (une ville d'un autre pays à moins de 60 km) ou des pendulaires viennent le tenir. Ils ne vivent pas ici : ni loyer ni impôts pour la ville. Former les jeunes (collège, lycée, hautes écoles) ou attirer des diplômés (logements, services) les remplace peu à peu.", true, 11)
	_section("Ce qu'exigent les métiers")
	var liste := SystemesScolaires.EXIGENCES.keys()
	liste.sort_custom(func(x: String, y: String) -> bool: return int(SystemesScolaires.EXIGENCES[x][0]) > int(SystemesScolaires.EXIGENCES[y][0]))
	for m in liste.slice(0, 18):
		_text("%s : %s" % [Metiers.job(String(m)).name, SystemesScolaires.texte_exigence(String(m), an)], true, 11)


# --- Système du pays -------------------------------------------------------------------

func _view_systeme() -> void:
	var an := pop.edu.annee()
	_title.text = "Éducation · système scolaire"
	var codes := []
	if Pays.instance != null:
		for nk in Pays.instance.cles_nations():
			var c := Pays.instance.code_de(int(nk))
			if c != "" and not codes.has(c):
				codes.append(c)
	if codes.is_empty():
		codes.append(GameStart.pays.to_lower())
	_section("Système de chaque pays")
	for code in codes:
		var row := HBoxContainer.new()
		var l := Label.new()
		l.text = "%s : " % (String(code).to_upper() if String(code) != "" else "Partie")
		l.custom_minimum_size = Vector2(70, 0)
		row.add_child(l)
		var pick := OptionButton.new()
		pick.focus_mode = Control.FOCUS_NONE
		var sys_ids := SystemesScolaires.NOMS.keys()
		for i in sys_ids.size():
			pick.add_item(String(SystemesScolaires.NOMS[sys_ids[i]]), i)
			if String(sys_ids[i]) == pop.edu.systeme_du_code(String(code)):
				pick.select(i)
		var cc: String = code
		pick.item_selected.connect(func(idx: int) -> void:
			pop.edu.choisir_systeme(cc, String(sys_ids[idx]))
			refresh())
		row.add_child(pick)
		_body.add_child(row)
	_text("Par défaut, chaque ville suit le système de son pays réel (Suisse, France, sinon générique). Les degrés, diplômes et exigences suivent l'année de la partie.", true, 11)
	var sys := _sys_affiche()
	_section("%s en %d" % [SystemesScolaires.NOMS.get(sys, sys), an])
	var bo := SystemesScolaires.bornes(sys, an)
	var o: Array = bo.oblig
	_text("École obligatoire : %s" % ("de %d à %d ans" % [int(o[0]), int(o[1])] if not o.is_empty() else "pas encore (les familles décident)"))
	for c in ["enfantine", "primaire", "sec1"]:
		var r: Array = bo[c]
		_text("%s : %d-%d ans, %d %% des enfants y vont" % [SystemesScolaires.nom_cycle(sys, c, an), int(r[0]), int(r[1]),
			roundi(100.0 * SystemesScolaires.taux_scolarisation(sys, c, an))], false, 12)
	_text("À 15 ans, orientation :", false, 12)
	var parts := SystemesScolaires.parts_orientation(sys, an)
	const NOMS_FIL := {"gym": "maturité ou bac (gymnase, lycée)", "ecg": "école de culture générale", "cfc": "apprentissage chez un employeur (CFC, CAP)",
		"pro": "école de métiers à plein temps", "afp": "formation de 2 ans (AFP)", "aucun": "pas de formation"}
	var tot := 0.0
	for k in parts:
		tot += float(parts[k])
	for k in ["gym", "ecg", "cfc", "pro", "afp", "aucun"]:
		if float(parts[k]) > 0.001:
			_text("   %s : %d %%" % [NOMS_FIL[k], roundi(100.0 * float(parts[k]) / maxf(tot, 0.001))], true, 12)
	_text("Après la maturité ou le bac :", false, 12)
	for acc in [SystemesScolaires.diplome_filiere(sys, "gym", an)]:
		for c in SystemesScolaires.cursus_superieurs(sys, an, acc):
			_text("   %s (%s ans) : %s" % [SystemesScolaires.nom_diplome(String(c[0]), an), String.num(float(c[2]), 1).trim_suffix(".0"),
				SystemesScolaires.nom_cycle(sys, String(c[3]), an)], true, 12)
