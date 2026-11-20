class_name SpectaclesPanel
extends CanvasLayer
## Menu « Spectacles » (barre du bas → Loisirs, ou Maj+X) : cinémas, salles de
## concert, théâtres et studios de cinéma.
## - Salles : note, public d'hier, billet, programmation automatique, prochaines
##   dates, dernières représentations (et les films à l'affiche d'un cinéma).
## - Programmer : les spectacles en tournée qui peuvent venir, avec le public et
##   le bénéfice attendus ; un clic les réserve.
## - Studios : plateaux, décors et annexes ; produire un film (genre, budget,
##   réalisateur, tête d'affiche) ; filmographie, entrées, prix.
## - Bâtir : tous les bâtiments de spectacle, et les salles meublées prêtes à
##   poser (vrais murs, scène, fauteuils, foyer : SpectaclesGabarits).
## - Aménager : les objets de scène, de salle, de sono et de tournage, à poser
##   un par un dans un bâtiment en murs fins (et « aménager toute la salle »).
## - À l'affiche : l'agenda de la ville et les films du moment.
## - Public : ce que disent les spectateurs.

signal focus_requested(pos: Vector3)
signal building_chosen(id: String)

const W := 390.0
const H := 560.0
const TABS := [["Mes salles", "salles", "masques"], ["Programmer", "programmer", "billet"], ["Studios de cinéma", "studios", "clap"],
	["Bâtir", "batir", "construire"], ["Aménager l'intérieur", "amenager", "interieur"], ["À l'affiche", "affiche", "tableau"], ["Public", "public", "habitants"]]
const JOURS := ["dim.", "lun.", "mar.", "mer.", "jeu.", "ven.", "sam."]

var spect: Spectacles
var view := "salles"
var choisi := -1
var studio_choisi := -1
var genre_filtre := ""
## Film en préparation dans le formulaire.
var form := {"genre": "comedie_film", "budget": "petit", "real": "bernard_routine", "star": "inconnus", "titre": ""}
var _panel: PanelContainer
var _title: Label
var _body: VBoxContainer
var _scroll: ScrollContainer
var _tab_buttons := {}
var _tick := 0.0
## Appelée avant de prendre un outil de l'Intérieur (range les autres outils).
var prepare: Callable
var famille := "scene"
var _vignettes: Vignettes
var _group := ButtonGroup.new()


func setup(s: Spectacles, prep: Callable = Callable()) -> void:
	spect = s
	prepare = prep
	_build()
	_vignettes = Vignettes.new()
	_vignettes.name = "VignettesSpectacles"
	add_child(_vignettes)


func _prep() -> void:
	if prepare.is_valid():
		prepare.call()


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
	icon.texture = Icones.get_icon("masques", 22, UiStyle.ACCENT)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(icon)
	_title = Label.new()
	_title.text = "Spectacles"
	_title.add_theme_font_size_override("font_size", 16)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.clip_text = true
	head.add_child(_title)
	var x := UiStyle.icon_button("fermer", "Fermer", "Maj+X", 18, 32)
	x.pressed.connect(func() -> void: set_open(false))
	head.add_child(x)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 2)
	outer.add_child(tabs)
	for spec in TABS:
		var b := Button.new()
		b.icon = Icones.get_icon(spec[2], 20)
		b.tooltip_text = spec[0]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 34)
		var v: String = spec[1]
		b.pressed.connect(func() -> void: show_view(v))
		tabs.add_child(b)
		_tab_buttons[v] = b
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(W - 20, H)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 4)
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
	if k and k.pressed and not k.echo and k.physical_keycode == KEY_X and k.shift_pressed and not k.ctrl_pressed and not k.alt_pressed:
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
	if _tick >= 2.0 and view in ["salles", "studios", "affiche", "public"]:
		_tick = 0.0
		var f := get_viewport().gui_get_focus_owner()
		if f != null and _body.is_ancestor_of(f):
			return
		var keep := _scroll.scroll_vertical
		refresh()
		_scroll.set_deferred("scroll_vertical", keep)


func courante() -> int:
	if spect == null:
		return -1
	var l := spect.list_salles()
	if l.is_empty():
		return -1
	if not l.has(choisi):
		choisi = int(l[0])
	return choisi


func studio_courant() -> int:
	if spect == null:
		return -1
	var l := spect.list_studios()
	if l.is_empty():
		return -1
	if not l.has(studio_choisi):
		studio_choisi = int(l[0])
	return studio_choisi


# --- Petits outils ----------------------------------------------------------------------------

func _label(text: String, size := 12, dim := false, parent: Control = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(W - 40, 0) if parent == null else Vector2.ZERO
	if parent != null:
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if dim:
		l.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	(parent if parent != null else _body).add_child(l)
	return l


func _titre(text: String) -> void:
	var l := _label(text, 14)
	l.add_theme_color_override("font_color", UiStyle.ACCENT)


func _bouton(text: String, icon: String, tip: String, cb: Callable, parent: Control = null) -> Button:
	var b := Button.new()
	b.text = text
	if icon != "":
		b.icon = Icones.get_icon(icon, 18)
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = parent != null
	b.pressed.connect(cb)
	(parent if parent != null else _body).add_child(b)
	return b


func _option(items: Array, current: String, cb: Callable) -> ChoixVisuel:
	var opt := ChoixVisuel.new()
	opt.focus_mode = Control.FOCUS_NONE
	opt.clip_text = true
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for it in items:
		opt.add_item(String(it[1]))
		opt.set_item_metadata(opt.item_count - 1, it[0])
		if str(it[0]) == current:
			opt.select(opt.item_count - 1)
	opt.item_selected.connect(func(i: int) -> void: cb.call(opt.get_item_metadata(i)))
	return opt


func _ligne(label: String, ctrl: Control) -> void:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(110, 0)
	l.add_theme_font_size_override("font_size", 12)
	row.add_child(l)
	ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(ctrl)
	_body.add_child(row)


static func etoiles(n: float) -> String:
	var s := ""
	for i in 5:
		s += "★" if n >= i + 0.75 else ("⯪" if n >= i + 0.25 else "☆")
	return s


func _date(day: int, h := -1) -> String:
	var dt := spect.date_of(day)
	var s := "%s %d/%02d" % [JOURS[int(dt.wd)], int(dt.mday), int(dt.month)]
	if h >= 0:
		s += " %d h%s" % [h, "30" if h == 20 else ""]
	return s


static func _euros(x: float) -> String:
	return BuildingSystem.format_money(int(x))


func refresh() -> void:
	if spect == null:
		return
	for v in _tab_buttons:
		(_tab_buttons[v] as Button).set_pressed_no_signal(v == view)
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	var bid := courante()
	_title.text = "Spectacles" if bid < 0 or view in ["studios", "batir", "affiche", "amenager"] else spect.nom(bid)
	match view:
		"salles": _vue_salles(bid)
		"programmer": _vue_programmer(bid)
		"studios": _vue_studios()
		"batir": _vue_batir()
		"amenager": _vue_amenager()
		"affiche": _vue_affiche()
		"public": _vue_public(bid)


func _choix_salle(bid: int) -> void:
	var l := spect.list_salles()
	if l.size() < 2:
		return
	var items: Array = []
	for b in l:
		items.append([int(b), "%s (%s)" % [spect.nom(int(b)), SpectaclesTypes.FAMILLES[spect.famille_of(int(b))].name]])
	_body.add_child(_option(items, str(bid), func(v: Variant) -> void:
		choisi = int(v)
		refresh()))


# --- Mes salles -------------------------------------------------------------------------------

func _vue_salles(bid: int) -> void:
	if bid < 0:
		_label("Pas encore de salle de spectacle.", 14)
		_label("Onglet Bâtir : cinémas, salles de concert, théâtres, opéra, cirque… Le cinéma du catalogue (B → Loisirs) et les théâtres des styles du monde comptent aussi.", 12, true)
		_bouton("Bâtir une salle", "construire", "Ouvre l'onglet Bâtir.", func() -> void: show_view("batir"))
		return
	_choix_salle(bid)
	var st: Dictionary = spect.salles[bid]
	var s := spect.spec(bid)
	var fam := spect.famille_of(bid)
	var n := spect.note(bid)
	var l := _label("%s  %.1f / 5" % [etoiles(n), n], 18)
	l.add_theme_color_override("font_color", UiStyle.ACCENT)
	_label("%s · %d places%s · confort %d %% · acoustique %d %%%s" % [spect.type_name(bid), spect.places(bid),
		(" · %d écrans" % int(s.get("salles", 1))) if fam == "cinema" else "", roundi(float(s.get("confort", 0.5)) * 100.0),
		roundi(float(s.get("acoustique", 0.5)) * 100.0), " · plein air" if bool(s.get("plein_air", false)) else ""], 12, true)
	if spect.en_chantier(bid):
		_label("En chantier : ouverture à la fin des travaux.", 12)
	elif spect.sans_personnel(bid):
		_label("Fermé faute de personnel.", 12)
	var h: Dictionary = st.hier
	_label("Hier : %d spectateurs, %d représentation%s%s%s" % [int(h.spectateurs), int(h.representations), "s" if int(h.representations) > 1 else "",
		(", %d complet%s" % [int(h.complets), "s" if int(h.complets) > 1 else ""]) if int(h.complets) > 0 else "",
		(", %d annulée%s" % [int(h.annulations), "s" if int(h.annulations) > 1 else ""]) if int(h.annulations) > 0 else ""], 12)
	_label("Recettes d'hier : %s (billets %s, bar %s) · dépenses %s" % [_euros(Spectacles.recettes(h)), _euros(float(h.billets)),
		_euros(float(h.bar)), _euros(float(h.depenses))], 12, true)
	var prix := SpinBox.new()
	prix.min_value = 0
	prix.max_value = 250
	prix.step = 0.5
	prix.value = float(st.prix)
	prix.suffix = "€"
	prix.value_changed.connect(func(v: float) -> void: spect.set_prix(bid, v))
	_ligne("Billet :", prix)
	if fam != "cinema":
		var auto := CheckBox.new()
		auto.text = "Programmation automatique"
		auto.tooltip_text = "Le directeur de la salle réserve les tournées qui rapportent le plus, dix jours à l'avance."
		auto.button_pressed = bool(st.auto)
		auto.focus_mode = Control.FOCUS_NONE
		auto.toggled.connect(func(on: bool) -> void:
			spect.set_auto(bid, on)
			refresh())
		_body.add_child(auto)
	var nrow := HBoxContainer.new()
	var ne := LineEdit.new()
	ne.text = spect.nom(bid)
	ne.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ne.text_submitted.connect(func(tx: String) -> void:
		spect.renommer(bid, tx)
		refresh())
	nrow.add_child(ne)
	var go := Button.new()
	go.icon = Icones.get_icon("lieu", 18)
	go.tooltip_text = "Aller voir la salle"
	go.focus_mode = Control.FOCUS_NONE
	go.pressed.connect(func() -> void: focus_requested.emit(spect.centre(bid)))
	nrow.add_child(go)
	_body.add_child(nrow)
	if fam == "cinema":
		_titre("À l'affiche")
		var day := spect._today()
		for id in spect.affiche(bid, day):
			var f: Dictionary = spect.films[id]
			var sem := int(floorf(float(day - int(f.sortie)) / 7.0)) + 1
			_label("%s%s « %s » · %s · %de semaine%s" % ["📌 " if int(st.affiche_forcee) == int(id) else "", "★ " if bool(f.get("joueur", false)) else "",
				String(f.titre), SpectaclesProgrammes.genre_name(String(f.genre)), sem, " · ton film" if bool(f.get("joueur", false)) else ""], 12)
		_label("Séances : %s" % ", ".join(spect.seances(bid).keys().map(func(x: Variant) -> String: return "%d h" % int(x))), 11, true)
	else:
		_titre("Prochaines dates")
		var ag: Array = st.agenda
		if ag.is_empty():
			_label("Rien de programmé. Onglet Programmer, ou coche la programmation automatique.", 12, true)
		for i in mini(ag.size(), 12):
			var ev: Dictionary = ag[i]
			var row := HBoxContainer.new()
			_label("%s · %s" % [_date(int(ev.d), int(ev.h)), SpectaclesProgrammes.nom_tournee(String(ev.sp))], 12, false, row)
			var x := Button.new()
			x.icon = Icones.get_icon("fermer", 14)
			x.tooltip_text = "Annuler cette date (moins de 7 jours avant : la moitié du cachet est due)"
			x.focus_mode = Control.FOCUS_NONE
			var idx := i
			x.pressed.connect(func() -> void:
				spect.annuler(bid, idx)
				refresh())
			row.add_child(x)
			_body.add_child(row)
	var hist: Array = st.historique
	if not hist.is_empty():
		_titre("Dernières représentations")
		for hh in hist.slice(0, 6):
			var titre := SpectaclesProgrammes.nom_tournee(String(hh.sp)) if fam != "cinema" else ""
			var bil := int(hh.recette) - int(hh.cout)
			_label("%s · %s · %d / %d · %s%s" % [_date(int(hh.d)), titre, int(hh.public), int(hh.places),
				"+" if bil >= 0 else "", _euros(float(bil))], 11, true)
	_conseils(bid)


func _conseils(bid: int) -> void:
	var out: Array = []
	var st: Dictionary = spect.salles[bid]
	var fam := spect.famille_of(bid)
	if fam != "cinema" and (st.agenda as Array).is_empty() and not bool(st.auto):
		out.append("La salle est vide : programme des dates, ou laisse faire la programmation automatique.")
	var h: Dictionary = st.hier
	if int(h.complets) > 0 and int(h.refus) > 200:
		out.append("%d personnes refoulées hier : tu peux monter le prix du billet ou bâtir une plus grande salle." % int(h.refus))
	if int(h.representations) > 0 and int(h.spectateurs) < spect.places(bid) * int(h.representations) / 5:
		out.append("Salle aux trois quarts vide : baisse le billet ou programme des artistes plus connus.")
	if spect.habitants() < 2000 and spect.places(bid) > 2000:
		out.append("Grande salle pour une petite ville : seules les stars feront venir la région.")
	if out.is_empty():
		return
	_titre("Conseils")
	for c in out:
		_label("• " + String(c), 12)


# --- Programmer -------------------------------------------------------------------------------

func _vue_programmer(bid: int) -> void:
	if bid < 0:
		_label("Bâtis d'abord une salle (onglet Bâtir).", 13)
		return
	_choix_salle(bid)
	var fam := spect.famille_of(bid)
	if fam == "cinema":
		_titre("Films du moment")
		_label("Le cinéma passe les films les plus attirants. Épingle un film pour le garder à l'affiche.", 12, true)
		var day := spect._today()
		var l := spect.films_affiche_monde(day)
		l.sort_custom(func(a: int, b: int) -> bool: return spect.attrait(spect.films[a], day) > spect.attrait(spect.films[b], day))
		for id in l:
			var f: Dictionary = spect.films[id]
			var pin := int(spect.salles[bid].affiche_forcee) == int(id)
			_bouton("%s« %s » · %s · %s" % ["📌 " if pin else "", String(f.titre), SpectaclesProgrammes.genre_name(String(f.genre)),
				etoiles(float(f.q) / 20.0)], "clap", "Épingler ce film dans ce cinéma (ou le désépingler).", func() -> void:
					spect.forcer_affiche(bid, int(id))
					refresh())
		return
	var s := spect.spec(bid)
	var genres: Array = [["", "Tous les genres"]]
	for g in s.get("genres", []):
		genres.append([String(g), SpectaclesProgrammes.genre_name(String(g))])
	_body.add_child(_option(genres, genre_filtre, func(v: Variant) -> void:
		genre_filtre = String(v)
		refresh()))
	_label("Public et bénéfice estimés pour la prochaine date libre (billet à %s)." % _euros(float(spect.salles[bid].prix)), 11, true)
	for sp in SpectaclesProgrammes.TOURNEES:
		var e: Array = SpectaclesProgrammes.TOURNEES[sp]
		if not (s.get("genres", []) as Array).has(String(e[1])):
			continue
		if genre_filtre != "" and String(e[1]) != genre_filtre:
			continue
		var raison := spect.compatible(bid, String(sp))
		var date := _prochaine_date(bid, String(sp))
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 1)
		_label("%s — %s · notoriété %d · cachet %s" % [String(e[0]), SpectaclesProgrammes.genre_name(String(e[1])), int(e[2]), _euros(float(e[3]))], 12, raison != "", box)
		_label(String(e[5]), 11, true, box)
		if raison != "":
			_label(raison[0].to_upper() + raison.substr(1) + ".", 11, true, box)
		elif date.is_empty():
			_label("Pas de date libre dans les deux mois.", 11, true, box)
		else:
			var est := spect.estimation(bid, String(sp), date)
			_label("%s : ~%d spectateurs sur %d · %s%s" % [_date(int(date.day)), int(est.public), spect.places(bid),
				"+" if float(est.benefice) >= 0.0 else "", _euros(float(est.benefice))], 11, false, box)
			var row := HBoxContainer.new()
			for nd in [1, 3, 6]:
				var nn: int = nd
				var b := Button.new()
				b.text = "%d date%s" % [nn, "s" if nn > 1 else ""]
				b.focus_mode = Control.FOCUS_NONE
				b.pressed.connect(func() -> void:
					spect.programmer(bid, String(sp), nn, int(date.day))
					refresh())
				row.add_child(b)
			box.add_child(row)
		_body.add_child(box)
		_body.add_child(HSeparator.new())


func _prochaine_date(bid: int, sp: String) -> Dictionary:
	var genre := String(SpectaclesProgrammes.TOURNEES[sp][1])
	var day := spect._today() + 1
	for i in 60:
		var dt := spect.date_of(day + i)
		if not spect.creneaux(bid, dt, genre).is_empty() and not spect._occupe(bid, day + i, -1) and not spect._en_tournee_ailleurs(sp, day + i, bid):
			return dt
	return {}


# --- Studios ----------------------------------------------------------------------------------

func _vue_studios() -> void:
	var sid := studio_courant()
	if sid < 0:
		_titre("Studios de cinéma")
		_label("Pose des studios (onglet Bâtir) pour produire tes propres films. Autour, à moins de 300 m : plateaux, décors (western, rue de grande ville, château, base spatiale, bassin), effets spéciaux, post-production, atelier de décors.", 12, true)
		_bouton("Poser des studios de cinéma (%s)" % _euros(float(BuildingCatalog.cost("studio_cinema"))), "construire",
			"Bureaux de production et deux plateaux.", func() -> void: building_chosen.emit("studio_cinema"))
		return
	var l := spect.list_studios()
	if l.size() > 1:
		var items: Array = []
		for b in l:
			items.append([int(b), spect.nom(int(b))])
		_body.add_child(_option(items, str(sid), func(v: Variant) -> void:
			studio_choisi = int(v)
			refresh()))
	_title.text = spect.nom(sid)
	var st: Dictionary = spect.studios[sid]
	var an := spect.annexes(sid)
	_label("Réputation %d / 100 · plateaux libres %d sur %d" % [roundi(float(st.reputation)), spect.plateaux_libres(sid), spect.plateaux(sid)], 13)
	var dec: Array = []
	for d in an.decors:
		dec.append(spect._decor_nom(String(d)))
	_label("Décors : %s · effets spéciaux %s · post-production %s · atelier %s" % [", ".join(dec) if not dec.is_empty() else "aucun",
		"oui" if bool(an.vfx) else "non", "oui" if bool(an.postprod) else "non", "oui" if bool(an.atelier) else "non"], 12, true)
	if spect.en_chantier(sid):
		_label("Les studios sont en chantier.", 12)
	var nrow := HBoxContainer.new()
	var ne := LineEdit.new()
	ne.text = spect.nom(sid)
	ne.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ne.text_submitted.connect(func(tx: String) -> void:
		spect.renommer(sid, tx)
		refresh())
	nrow.add_child(ne)
	var go := Button.new()
	go.icon = Icones.get_icon("lieu", 18)
	go.tooltip_text = "Aller voir les studios"
	go.focus_mode = Control.FOCUS_NONE
	go.pressed.connect(func() -> void: focus_requested.emit(spect.centre(sid)))
	nrow.add_child(go)
	_body.add_child(nrow)
	# Films en cours.
	var encours := spect.films_du_studio(sid, ["prep", "tournage", "post", "salle"])
	if not encours.is_empty():
		_titre("En cours")
		for id in encours:
			var f: Dictionary = spect.films[id]
			var av := spect.avancement(int(id))
			_label("« %s » · %s · %s" % [String(f.titre), SpectaclesProgrammes.genre_name(String(f.genre)), String(av[1])], 12)
			var pb := ProgressBar.new()
			pb.min_value = 0.0
			pb.max_value = 1.0
			pb.value = float(av[0])
			pb.show_percentage = false
			pb.custom_minimum_size = Vector2(W - 40, 8)
			_body.add_child(pb)
			if String(f.phase) == "salle":
				_label("Presse %s · public %s · %s entrées (%s ici) · recettes %s" % [etoiles(float(f.presse) / 20.0), etoiles(float(f.public) / 20.0),
					Spectacles._nombre(int(f.entrees)), Spectacles._nombre(int(f.get("entrees_ville", 0))), _euros(float(f.recettes))], 11, true)
	_nouveau_film(sid)
	var finis := spect.films_du_studio(sid, ["fini"])
	if not finis.is_empty() or not (st.prix as Array).is_empty():
		_titre("Filmographie")
		for id in finis:
			var f: Dictionary = spect.films[id]
			var bil := float(f.recettes) - float(f.cout)
			_label("« %s » (%s) · presse %s · %s entrées · %s%s%s" % [String(f.titre), SpectaclesProgrammes.genre_name(String(f.genre)).to_lower(),
				etoiles(float(f.presse) / 20.0), Spectacles._nombre(int(f.entrees)), "+" if bil >= 0.0 else "", _euros(bil),
				(" · 🏆 " + String(f.prix)) if String(f.get("prix", "")) != "" else ""], 11)
		for p in st.prix:
			_label("🏆 " + String(p), 11, true)


func _nouveau_film(sid: int) -> void:
	_titre("Produire un film")
	var genres: Array = []
	for g in SpectaclesProgrammes.genres_films():
		genres.append([g, SpectaclesProgrammes.genre_name(String(g))])
	_ligne("Genre :", _option(genres, String(form.genre), func(v: Variant) -> void:
		form.genre = String(v)
		refresh()))
	var budgets: Array = []
	for b in SpectaclesProgrammes.BUDGET_ORDER:
		var e: Array = SpectaclesProgrammes.BUDGETS[b]
		budgets.append([b, "%s (%s)" % [String(e[0]), _euros(float(e[1]))]])
	_ligne("Budget :", _option(budgets, String(form.budget), func(v: Variant) -> void:
		form.budget = String(v)
		refresh()))
	var reals: Array = []
	for r in SpectaclesProgrammes.REAL_ORDER:
		var e: Array = SpectaclesProgrammes.REALISATEURS[r]
		reals.append([r, "%s · talent %d · %s" % [String(e[0]), int(e[1]), _euros(float(e[2]))]])
	_ligne("Réalisation :", _option(reals, String(form.real), func(v: Variant) -> void:
		form.real = String(v)
		refresh()))
	var stars: Array = []
	for s in SpectaclesProgrammes.STAR_ORDER:
		var e: Array = SpectaclesProgrammes.STARS[s]
		stars.append([s, "%s%s" % [String(e[0]), (" · %s" % _euros(float(e[2]))) if int(e[2]) > 0 else ""]])
	_ligne("Tête d'affiche :", _option(stars, String(form.star), func(v: Variant) -> void:
		form.star = String(v)
		refresh()))
	var re: Array = SpectaclesProgrammes.REALISATEURS[String(form.real)]
	var se: Array = SpectaclesProgrammes.STARS[String(form.star)]
	_label("%s : %s %s : %s" % [String(re[0]), String(re[4]), String(se[0]), String(se[4])], 11, true)
	var trow := HBoxContainer.new()
	var te := LineEdit.new()
	te.placeholder_text = "Titre du film (au hasard si vide)"
	te.text = String(form.titre)
	te.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	te.text_changed.connect(func(tx: String) -> void: form.titre = tx)
	trow.add_child(te)
	var de := Button.new()
	de.icon = Icones.get_icon("tourner", 16)
	de.tooltip_text = "Un titre au hasard"
	de.focus_mode = Control.FOCUS_NONE
	de.pressed.connect(func() -> void:
		form.titre = SpectaclesProgrammes.titre_au_hasard(String(form.genre), spect.rng)
		refresh())
	trow.add_child(de)
	_body.add_child(trow)
	var dv := spect.devis(sid, String(form.genre), String(form.budget), String(form.real), String(form.star))
	_label("Coût : %s (budget %s + cachets %s) · tournage %d jours, montage %d jours" % [_euros(float(dv.total)), _euros(float(dv.budget)),
		_euros(float(dv.cachets)), int(dv.jours), int(dv.post)], 12)
	for c in dv.conseils:
		_label("• " + String(c), 11, true)
	_bouton("Lancer la production", "clap", "Cachets et préparation payés tout de suite, le reste pendant le tournage.", func() -> void:
		var err := spect.lancer_film(sid, String(form.genre), String(form.budget), String(form.real), String(form.star), String(form.titre))
		if err != "":
			spect.message.emit("Impossible de lancer le film : " + err + ".")
		else:
			form.titre = ""
		refresh())


# --- Bâtir ------------------------------------------------------------------------------------

func _vue_batir() -> void:
	var mob := spect.mob
	if mob != null:
		_titre("Salles meublées, prêtes à jouer")
		_label("Clic sur un terrain libre, R pour tourner. Vrais murs, scène ou écran au fond, fauteuils en rangées, foyer et billetterie, loges : tout est déjà posé.", 11, true)
		for k in SpectaclesGabarits.ORDER:
			var g: Dictionary = SpectaclesGabarits.KINDS[k]
			var kind := String(k)
			var b0 := _bouton("%s · %d × %d m · %s" % [g.name, int(g.w), int(g.d), _euros(float(g.budget))], "interieur", String(g.desc), func() -> void:
				_prep()
				mob.set_template(kind))
			b0.clip_text = true
			b0.add_theme_font_size_override("font_size", 12)
	var groupes := [["Cinémas", SpectaclesTypes.of_famille("cinema")], ["Studios de cinéma", SpectaclesTypes.of_role("studio")],
		["Annexes des studios (à moins de 300 m)", SpectaclesTypes.of_role("annexe")], ["Salles de concert", SpectaclesTypes.of_famille("concert")],
		["Théâtres, opéra et cirque", SpectaclesTypes.of_famille("theatre")]]
	for g in groupes:
		_titre(String(g[0]))
		for id in g[1]:
			var t := BuildingCatalog.get_type(String(id))
			var sp := SpectaclesTypes.spec_of(String(id))
			var cap := (" · %d places" % int(sp.places)) if sp.has("places") else ""
			var b := _bouton("%s — %s%s" % [String(t.name), _euros(float(BuildingCatalog.cost(String(id)))), cap], "construire",
				String(t.get("desc", "")), func() -> void: building_chosen.emit(String(id)))
			b.add_theme_font_size_override("font_size", 12)
	_titre("Ailleurs dans le catalogue")
	_label("Le cinéma (B → Loisirs), le kiosque à musique (Espaces publics) et les théâtres des styles du monde (opéra, cinéma Art déco, amphithéâtre…) sont aussi des salles. Un modèle de l'Atelier qui prend une de ces fonctions en devient une.", 12, true)


# --- Aménager ---------------------------------------------------------------------------------

func _vue_amenager() -> void:
	var mob := spect.mob
	if mob == null:
		_label("L'aménagement intérieur n'est pas disponible ici.", 12, true)
		return
	_label("Dans un bâtiment en murs fins (mode Créer, Tab) : donne-lui l'usage Cinéma, Théâtre, Salle de concert ou Studio de cinéma, puis pose les objets. Les fauteuils font les places, la billetterie est indispensable.", 11, true)
	var row := HFlowContainer.new()
	_body.add_child(row)
	for u in ["cinema", "theatre", "concert", "studio_cine"]:
		var uu := String(u)
		_bouton(String(Mobilier.USAGES[uu].name), "interieur", "Le bâtiment visé devient : %s.\n%s" % [Mobilier.USAGES[uu].name, Mobilier.USAGES[uu].desc], func() -> void:
			var id := mob.focus_id()
			if id == "":
				mob.message.emit("Vise d'abord un bâtiment en murs fins (survole-le avec un outil de pose, ou clic dessus avec l'outil Fonction).")
				return
			mob.set_usage(id, uu)
			spect._dirty = true
			mob.message.emit("%s : %s." % [mob.plan_name(id), Mobilier.USAGES[uu].name])
			refresh(), row)
	for c in row.get_children():
		(c as Button).clip_text = false
		(c as Button).add_theme_font_size_override("font_size", 11)
	var tout := _bouton("Aménager toute la salle (pièce par pièce)", "interieur", "Scène, rideaux, fauteuils face à la scène, régie, foyer… dans toutes les pièces du bâtiment visé.", func() -> void:
		var id := mob.focus_id()
		if id == "":
			mob.message.emit("Vise d'abord un bâtiment en murs fins.")
			return
		var n := mob.furnish_plan(id, "contemporain")
		spect._dirty = true
		mob.message.emit("%d objets posés dans %s." % [n, mob.plan_name(id)]))
	tout.clip_text = true
	tout.add_theme_font_size_override("font_size", 12)
	_label("Fonction des pièces (outil Fonction : clic dans une pièce) :", 11, true)
	var opt := ChoixVisuel.new()
	opt.modele_meta = "salle"
	opt.focus_mode = Control.FOCUS_NONE
	opt.add_theme_font_size_override("font_size", 11)
	for f in SpectaclesObjets.SALLE_ORDER:
		opt.add_item(SpectaclesObjets.salle_name(String(f)))
		opt.set_item_metadata(opt.item_count - 1, f)
		opt.set_item_tooltip(opt.item_count - 1, String(SpectaclesObjets.SALLES[f].desc))
		if String(f) == mob.room_fn:
			opt.select(opt.item_count - 1)
	opt.item_selected.connect(func(i: int) -> void:
		_prep()
		mob.set_room_fn(String(opt.get_item_metadata(i)))
		mob.set_tool(Mobilier.Tool.ROOM_FN))
	_body.add_child(opt)
	var fams := HFlowContainer.new()
	fams.add_theme_constant_override("h_separation", 2)
	_body.add_child(fams)
	for f in SpectaclesObjets.FAMILLE_ORDER:
		var fs: Dictionary = SpectaclesObjets.FAMILLES[f]
		var b := Button.new()
		b.icon = Icones.get_icon(String(fs.icon), 18, UiStyle.ACCENT if f == famille else Color.WHITE)
		b.text = String(fs.name)
		b.add_theme_font_size_override("font_size", 10)
		b.tooltip_text = "%s\n%s" % [fs.name, fs.desc]
		b.toggle_mode = true
		b.button_pressed = f == famille
		b.focus_mode = Control.FOCUS_NONE
		var ff := String(f)
		b.pressed.connect(func() -> void:
			famille = ff
			refresh())
		fams.add_child(b)
	_label(String(SpectaclesObjets.FAMILLES[famille].desc), 11, true)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	_body.add_child(grid)
	_vignettes.cancel_all()
	for id in SpectaclesObjets.of_famille(famille):
		grid.add_child(_carte(String(id)))
	_label("R : tourner · clic droit : retirer · Page haut / bas : étage · Échap : arrêter. Les objets posés sur un plancher de scène montent sur la scène.", 11, true)


func _carte(id: String) -> Button:
	var mob := spect.mob
	var e := Meubles.get_entry(id)
	var b := Button.new()
	b.custom_minimum_size = Vector2(84, 104)
	b.focus_mode = Control.FOCUS_NONE
	b.toggle_mode = true
	b.button_group = _group
	b.button_pressed = mob.meuble == id and mob.tool == Mobilier.Tool.PLACE
	b.text = "%s\n%s" % [e.name, BuildingSystem.format_money(int(e.prix))]
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.clip_text = true
	b.add_theme_constant_override("icon_max_width", 60)
	b.add_theme_font_size_override("font_size", 10)
	b.add_theme_constant_override("line_spacing", -3)
	var tip := "%s\n%s · %d × %d m" % [e.name, Meubles.describe(id), int(e.w), int(e.d)]
	var n := 0
	for pl in e.get("places", []):
		if String(pl[0]) == "assis":
			n += 1
	if n > 0 and String(e.get("sp", "siege")) == "siege":
		tip += "\n%d places pour le public" % n
	if float(e.get("estrade", 0.0)) > 0.0:
		tip += "\nPlancher de scène : les objets posés dessus montent de %d cm." % roundi(float(e.estrade) * 100.0)
	if int(e.get("son", 0)) > 0:
		tip += "\nAcoustique +%d" % int(e.son)
	if String(e.get("decor", "")) != "":
		tip += "\nDécor de tournage (sert les films du genre)."
	if String(e.couche) == "mur":
		tip += "\nS'accroche sur un mur plein."
	elif bool(e.get("suspendu", false)):
		tip += "\nSuspendu au plafond."
	b.tooltip_text = tip
	_vignettes.request_mesh("spectacle:" + id, func() -> Mesh: return MeublesModeles.mesh_of(id), b, 72)
	b.pressed.connect(func() -> void:
		_prep()
		mob.set_meuble(id))
	return b


# --- À l'affiche ------------------------------------------------------------------------------

func _vue_affiche() -> void:
	_titre("Cette semaine en ville")
	var ag := spect.agenda_ville(7)
	if ag.is_empty():
		_label("Aucun spectacle programmé.", 12, true)
	for ev in ag.slice(0, 30):
		_label("%s · %s — %s" % [_date(int(ev.d), int(ev.h)), SpectaclesProgrammes.nom_tournee(String(ev.sp)), spect.nom(int(ev.bid))], 12)
	_titre("Films du moment")
	var day := spect._today()
	var l := spect.films_affiche_monde(day)
	l.sort_custom(func(a: int, b: int) -> bool: return spect.attrait(spect.films[a], day) > spect.attrait(spect.films[b], day))
	for id in l.slice(0, 12):
		var f: Dictionary = spect.films[id]
		_label("%s« %s » · %s · %s · sorti le %s" % ["★ " if bool(f.get("joueur", false)) else "", String(f.titre), SpectaclesProgrammes.genre_name(String(f.genre)),
			etoiles(float(f.q) / 20.0), _date(int(f.sortie))], 12)


# --- Public -----------------------------------------------------------------------------------

func _vue_public(bid: int) -> void:
	var tot := 0
	for b in spect.salles:
		tot += int(spect.salles[b].hier.spectateurs)
	_label("Hier, %d spectateurs dans les salles de la ville." % tot, 13)
	if bid < 0:
		return
	_choix_salle(bid)
	var st: Dictionary = spect.salles[bid]
	_titre("Ce qu'ils disent")
	for p in st.dernieres:
		_label(String(p), 12)
	if (st.dernieres as Array).is_empty():
		_label("Pas encore de public.", 12, true)
	var t: Dictionary = st.total
	_titre("Depuis l'ouverture")
	_label("%d spectateurs, %d représentations, %d complets · recettes %s" % [int(t.spectateurs), int(t.representations), int(t.complets),
		_euros(Spectacles.recettes(t))], 12, true)
