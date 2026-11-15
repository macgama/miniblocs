class_name PartagePanel
extends CanvasLayer
## Menu « Partage » (Maj+W, ou mode Créer → 8) : publier ses créations et
## installer celles des autres joueurs.
## - Partager : bâtiments de l'Atelier, musées, créations en blocs, attractions
##   dessinées et plans de site ; « Publier » (titre, description, étiquettes)
##   et « Fichier .mbloc » à envoyer à un ami.
## - Plans de site : enregistrer une zone de la carte (parc, zoo, quartier)
##   et la reposer ailleurs.
## - Découvrir : les créations reçues (atelier local, et le Steam Workshop une
##   fois le jeu sur Steam) ; Installer, Mettre à jour, Retirer.

signal message(text: String)

const W := 400.0
const H := 560.0
const TABS := [["Partager mes créations", "partager", "envoyer"], ["Plans de site (parc, zoo, quartier)", "sites", "village"],
	["Découvrir les créations des autres", "decouvrir", "telecharger"]]
const MAX_CARTES := 80

var outil: OutilSite
var prepare: Callable
var view := "partager"
var _panel: PanelContainer
var _body: VBoxContainer
var _scroll: ScrollContainer
var _tab_buttons := {}
## Formulaire de publication ouvert : "genre:id".
var _form := ""
var _nom_site := ""
var _filtre := ""
var _cherche := ""
var _apercus := {}


func setup(o: OutilSite, prep: Callable = Callable()) -> void:
	outil = o
	prepare = prep
	_build()
	if outil != null:
		outil.zone_choisie.connect(_on_zone)
		outil.pose_faite.connect(_on_pose)
	_brancher(Partage.backend())
	if Partage.backend() != Partage.local():
		_brancher(Partage.local())


## Les services de partage vivent plus longtemps que la scène : on se
## débranche en quittant (sinon un signal viserait un menu disparu).
var _branches: Array = []


func _brancher(b: PartageBackend) -> void:
	var sur_publie := func(ok: bool, _cle: String, info: String) -> void:
		message.emit(info)
		if not ok:
			push_warning("Partage : " + info)
		if is_open():
			refresh()
	var sur_liste := func() -> void:
		_apercus.clear()
		if is_open() and view == "decouvrir":
			refresh()
	b.publie.connect(sur_publie)
	b.liste_changee.connect(sur_liste)
	_branches.append([b, sur_publie, sur_liste])


func _exit_tree() -> void:
	for e in _branches:
		var b: PartageBackend = e[0]
		if b.publie.is_connected(e[1]):
			b.publie.disconnect(e[1])
		if b.liste_changee.is_connected(e[2]):
			b.liste_changee.disconnect(e[2])
	_branches.clear()


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
	icon.texture = Icones.get_icon("partage", 22, UiStyle.ACCENT)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(icon)
	var title := Label.new()
	title.text = "Partage des créations"
	title.add_theme_font_size_override("font_size", 16)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var x := UiStyle.icon_button("fermer", "Fermer", "Maj+W", 18, 32)
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
	_body.add_theme_constant_override("separation", 5)
	_scroll.add_child(_body)


func is_open() -> bool:
	return _panel != null and _panel.visible


func set_open(on: bool) -> void:
	_panel.visible = on
	if on:
		refresh()


func toggle() -> void:
	set_open(not _panel.visible)


func _process(_delta: float) -> void:
	Partage.backend().tick()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.keycode == KEY_W and k.shift_pressed and not k.ctrl_pressed and not k.alt_pressed:
		toggle()
		get_viewport().set_input_as_handled()


func show_view(v: String) -> void:
	view = v
	refresh()
	_scroll.scroll_vertical = 0


# --- Petits outils ----------------------------------------------------------------------------

func _label(text: String, size := 12, dim := false, parent: Control = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if parent == null:
		l.custom_minimum_size = Vector2(W - 40, 0)
	else:
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
		b.icon = Icones.get_icon(icon, 16)
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	(parent if parent != null else _body).add_child(b)
	return b


## Carte : vignette, titre, lignes, rangée de boutons (rendue pour être remplie).
func _carte(tex: Texture2D, titre: String, lignes: Array) -> Array:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiStyle.flat_box(Color(1, 1, 1, 0.06), 8, 6))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)
	var pic := TextureRect.new()
	pic.custom_minimum_size = Vector2(56, 56)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.texture = tex
	row.add_child(pic)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var t := Label.new()
	t.text = titre
	t.clip_text = true
	t.add_theme_font_size_override("font_size", 14)
	col.add_child(t)
	for l in lignes:
		if String(l) != "":
			_label(String(l), 11, true, col)
	var btns := HFlowContainer.new()
	col.add_child(btns)
	_body.add_child(card)
	return [col, btns]


static func _date(t: float) -> String:
	if t <= 0.0:
		return "?"
	var d := Time.get_datetime_dict_from_unix_time(int(t))
	return "%02d/%02d/%d" % [int(d.day), int(d.month), int(d.year)]


func _icone_sorte(s: String) -> Texture2D:
	return Icones.get_icon(String(Partage.SORTE_ICONES.get(s, "creations")), 36, UiStyle.ACCENT)


func refresh() -> void:
	if _body == null:
		return
	for c in _body.get_children():
		c.queue_free()
	for v in _tab_buttons:
		_tab_buttons[v].set_pressed_no_signal(v == view)
	match view:
		"partager": _vue_partager()
		"sites": _vue_sites()
		"decouvrir": _vue_decouvrir()


# --- Partager ---------------------------------------------------------------------------------

func _vue_partager() -> void:
	var b := Partage.backend()
	_label("Publie tes créations pour les autres joueurs : elles partent avec tout ce dont elles ont besoin (un plan de site emporte ses modèles de l'Atelier, ses créations en blocs et ses attractions dessinées).", 12, true)
	if b.est_steam():
		_label("Service : Steam Workshop.", 11, true)
	else:
		_label("Service : atelier local. Le Steam Workshop prendra le relais à la sortie du jeu sur Steam ; en attendant, « Publier » crée aussi un fichier .mbloc à envoyer à tes amis.", 11, true)
	var mes := Partage.mes_creations()
	if mes.is_empty():
		_label("Rien à partager pour l'instant : enregistre un bâtiment dans la Banque (Créer → 6), une création en blocs (Créer → 5), une attraction (Maj+A) ou un plan de site (onglet suivant).", 13, true)
		return
	var ordre := ["batiment", "musee", "blocs", "attraction", "parc", "zoo", "quartier"]
	var shown := 0
	for s in ordre:
		var du_genre := mes.filter(func(m: Dictionary) -> bool: return String(m.sorte) == s)
		if du_genre.is_empty():
			continue
		_titre("%s (%d)" % [Partage.nom_sorte(s), du_genre.size()])
		for m: Dictionary in du_genre:
			if shown >= MAX_CARTES:
				break
			shown += 1
			_carte_mienne(m)


func _carte_mienne(m: Dictionary) -> void:
	var genre := String(m.genre)
	var id := String(m.id)
	var tex: Texture2D = BanqueModeles.preview_of(id) if genre == "modele" else null
	var pub := Partage.publication("%s:%s" % [genre, id])
	var etat := ("Publié le %s" % _date(float(pub.get("quand", 0.0)))) if not pub.is_empty() else "Pas encore publié"
	var parts := _carte(tex if tex != null else _icone_sorte(String(m.sorte)), String(m.nom), [String(m.detail), etat])
	var col: VBoxContainer = parts[0]
	var btns: HFlowContainer = parts[1]
	var key := "%s:%s" % [genre, id]
	var p := _bouton("Mettre à jour" if not pub.is_empty() else "Publier", "envoyer", "Publier sur %s (titre, description, étiquettes)." % Partage.backend().nom(), func() -> void:
		_form = "" if _form == key else key
		refresh(), btns)
	p.toggle_mode = true
	p.button_pressed = _form == key
	_bouton("Fichier .mbloc", "sauver", "Crée un fichier dans le dossier d'échange, à envoyer à un ami (courriel, clé USB, Discord…).", func() -> void:
		var path := Partage.exporter(genre, id)
		message.emit(("Fichier créé : %s" % ProjectSettings.globalize_path(path)) if path != "" else "Export impossible."), btns)
	if _form == key:
		_formulaire(col, genre, id, String(m.nom))


func _formulaire(col: VBoxContainer, genre: String, id: String, nom: String) -> void:
	var titre := LineEdit.new()
	titre.placeholder_text = "Titre"
	titre.text = nom
	titre.max_length = 120
	col.add_child(titre)
	var desc := TextEdit.new()
	desc.placeholder_text = "Description : ce qu'il y a dedans, comment s'en servir…"
	desc.custom_minimum_size = Vector2(0, 70)
	desc.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	col.add_child(desc)
	var tags := LineEdit.new()
	tags.placeholder_text = "Étiquettes, séparées par des virgules (ex. : médiéval, Japon, gare)"
	col.add_child(tags)
	_bouton("Publier maintenant", "partage", "", func() -> void:
		var et := []
		for t in tags.text.split(",", false):
			et.append(t.strip_edges())
		var err := Partage.publier(genre, id, titre.text, desc.text, et)
		_form = ""
		if err != "":
			message.emit(err)
		refresh(), col)


# --- Plans de site -----------------------------------------------------------------------------

func _vue_sites() -> void:
	_label("Un plan de site garde toute une zone de la carte : bâtiments (même tes modèles et tes attractions), allées et files d'attente du parc, enclos et animaux du zoo, décors, bâtiments en murs fins meublés et blocs libres. On le repose ailleurs (R pour tourner) ou on le partage.", 12, true)
	var nom := LineEdit.new()
	nom.placeholder_text = "Nom du plan (ex. : Parc des Trois Lacs)"
	nom.text = _nom_site
	nom.text_changed.connect(func(t: String) -> void: _nom_site = t)
	_body.add_child(nom)
	_bouton("Choisir une zone sur la carte", "plus", "Clic sur un coin, glisser jusqu'au coin opposé, relâcher.", func() -> void:
		if prepare.is_valid():
			prepare.call()
		if outil != null:
			outil.choisir_zone())
	var ids := PlansSites.ids()
	if ids.is_empty():
		_label("Aucun plan de site pour l'instant.", 13, true)
		return
	_titre("Mes plans (%d)" % ids.size())
	for id in ids:
		var p := PlansSites.get_plan(String(id))
		var manque := PlansSites.manquants(p)
		var lignes := ["%s · %s" % [PlansSites.nom_sorte(String(p.get("sorte", ""))), PlansSites.resume(p)],
			"Prix estimé : %s · par %s" % [BuildingSystem.format_short(PlansSites.prix(p)), String(p.get("auteur", "?"))]]
		if not manque.is_empty():
			lignes.append("Bâtiments inconnus de cette partie : %d. Installe le paquet complet." % manque.size())
		var parts := _carte(_icone_sorte(String(p.get("sorte", "quartier"))), String(p.get("nom", "?")), lignes)
		var btns: HFlowContainer = parts[1]
		var pid := String(id)
		_bouton("Poser", "plus", "Comme les bâtiments du catalogue : prix, accès, chantier. R pour tourner.", func() -> void:
			if prepare.is_valid():
				prepare.call()
			if outil != null:
				outil.poser(PlansSites.get_plan(pid)), btns)
		_bouton("Publier", "envoyer", "", func() -> void:
			_form = "site:" + pid
			show_view("partager"), btns)
		var del := UiStyle.icon_button("gomme", "Retirer ce plan", "", 16, 28)
		del.pressed.connect(func() -> void:
			PlansSites.remove(pid)
			refresh())
		btns.add_child(del)


func contexte() -> Dictionary:
	return outil.contexte.call() if outil != null and outil.contexte.is_valid() else {}


func _on_zone(rect: Rect2i) -> void:
	var r := PlansSites.capture(contexte(), rect, _nom_site)
	if r.ok:
		_nom_site = ""
		message.emit("Plan de site enregistré : %s." % String(r.resume))
	else:
		message.emit(String(r.reason))
	set_open(true)
	show_view("sites")


func _on_pose(res: Dictionary) -> void:
	if bool(res.get("envoye", false)):
		message.emit("Plan envoyé au serveur de la carte : il apparaît chez tout le monde dans un instant.")
		return
	message.emit(PlansSites.bilan(res))


# --- Découvrir ---------------------------------------------------------------------------------

func _vue_decouvrir() -> void:
	var b := Partage.backend()
	if b.est_steam():
		_label("Les créations des autres joueurs : tes abonnements du Steam Workshop, et les fichiers .mbloc reçus (à déposer dans le dossier d'échange, puis « Recevoir »).", 12, true)
	else:
		_label("Les créations des autres joueurs que tu as reçues en fichier .mbloc, et les tiennes. Un fichier reçu se dépose dans le dossier d'échange, puis « Recevoir ».", 12, true)
	var row := HFlowContainer.new()
	_body.add_child(row)
	_bouton("Recevoir", "telecharger", "Lit les fichiers .mbloc (et les anciens modèles .json) du dossier d'échange.", func() -> void:
		var r := Partage.recevoir_echange()
		var t := ("Créations reçues : %d." % int(r.nouveaux)) if int(r.nouveaux) > 0 else "Rien de nouveau dans le dossier d'échange."
		if not (r.erreurs as Array).is_empty():
			t += " Illisible : " + String(r.erreurs[0])
		message.emit(t)
		refresh(), row)
	_bouton("Dossier d'échange", "charger", "Ouvre le dossier où arrivent tes fichiers .mbloc et où déposer ceux de tes amis.", func() -> void:
		OS.shell_open(Partage.dossier_echange()), row)
	if b.est_steam():
		_bouton("Workshop", "partage", "Ouvre la page du Workshop dans Steam.", func() -> void:
			OS.shell_open("steam://url/SteamWorkshopPage/%d" % PartageSteam.app_id_projet()), row)
	var frow := HBoxContainer.new()
	_body.add_child(frow)
	var o := OptionButton.new()
	o.custom_minimum_size = Vector2(150, 0)
	o.add_item("Tout")
	o.set_item_metadata(0, "")
	for s in Partage.SORTES:
		o.add_item(Partage.nom_sorte(String(s)))
		o.set_item_metadata(o.item_count - 1, String(s))
		if String(s) == _filtre:
			o.select(o.item_count - 1)
	o.item_selected.connect(func(i: int) -> void:
		_filtre = String(o.get_item_metadata(i))
		refresh())
	frow.add_child(o)
	var search := LineEdit.new()
	search.placeholder_text = "Chercher…"
	search.text = _cherche
	search.clear_button_enabled = true
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.text_submitted.connect(func(t: String) -> void:
		_cherche = t.strip_edges()
		refresh())
	frow.add_child(search)
	var liste := filtrer(Partage.disponibles(), _filtre, _cherche)
	if liste.is_empty():
		_label("Aucune création ici pour l'instant." if _filtre == "" and _cherche == "" else "Aucune création pour ces filtres.", 13, true)
		return
	var n := 0
	for e: Dictionary in liste:
		if n >= MAX_CARTES:
			_label("… et %d autres : affine la recherche." % (liste.size() - n), 12, true)
			break
		n += 1
		_carte_dispo(e)


static func filtrer(liste: Array, sorte: String, texte: String) -> Array:
	var t := texte.to_lower()
	return liste.filter(func(e: Dictionary) -> bool:
		var f: Dictionary = e.fiche
		if sorte != "" and String(f.get("sorte", "")) != sorte:
			return false
		if t == "":
			return true
		var hay := ("%s %s %s %s" % [f.get("titre", ""), f.get("description", ""), f.get("auteur", ""), " ".join(PackedStringArray(f.get("etiquettes", [])))]).to_lower()
		return hay.contains(t))


func _apercu(dir: String, sorte: String) -> Texture2D:
	if not _apercus.has(dir):
		var img := PaquetPartage.apercu_dossier(dir)
		_apercus[dir] = ImageTexture.create_from_image(img) if img != null else null
	var t: Texture2D = _apercus[dir]
	return t if t != null else _icone_sorte(sorte)


func _carte_dispo(e: Dictionary) -> void:
	var f: Dictionary = e.fiche
	var sorte := String(f.get("sorte", ""))
	var et := String(e.etat)
	var lignes := ["%s · %s" % [Partage.nom_sorte(sorte), String(f.get("resume", ""))],
		"Publié par %s le %s" % [String(f.get("auteur", "?")), _date(float(f.get("maj", 0.0)))]]
	var desc := String(f.get("description", ""))
	if desc != "":
		lignes.append(desc.left(160) + ("…" if desc.length() > 160 else ""))
	var tags: Array = f.get("etiquettes", [])
	if tags.size() > 1:
		lignes.append("Étiquettes : " + ", ".join(PackedStringArray(tags.slice(1))))
	var parts := _carte(_apercu(String(e.dossier), sorte), String(f.get("titre", "?")), lignes)
	var btns: HFlowContainer = parts[1]
	if et == "installe":
		var ok := _label("Installé ✓ · " + Partage.ou_trouver(String(f.genre)), 11, false, btns)
		ok.add_theme_color_override("font_color", UiStyle.GOOD)
	else:
		_bouton("Mettre à jour" if et == "maj" else "Installer", "telecharger", "", func() -> void:
			var r := Partage.installer_objet(e)
			if r.ok:
				message.emit("« %s » installé : %s." % [String(f.get("titre", "")), String(r.ou)])
			else:
				message.emit("Installation impossible : %s." % String(r.error))
			refresh(), btns)
	if String(f.genre) == "site" and et != "nouveau":
		var pid := String(f.id)
		_bouton("Poser", "plus", "", func() -> void:
			if PlansSites.get_plan(pid).is_empty():
				return
			if prepare.is_valid():
				prepare.call()
			if outil != null:
				outil.poser(PlansSites.get_plan(pid)), btns)
	var src := String(e.get("source", "local"))
	var del := UiStyle.icon_button("gomme", "Se désabonner (Steam)" if src == "steam" else "Retirer de l'atelier local (ce qui est installé reste dans tes bibliothèques)", "", 16, 28)
	del.pressed.connect(func() -> void:
		(e.get("backend", Partage.local()) as PartageBackend).retirer(e)
		_apercus.erase(String(e.dossier))
		refresh())
	btns.add_child(del)
