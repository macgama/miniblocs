class_name GestionVue
extends CanvasLayer
## Écran du mode gestion « tycoon » : un jeu de gestion dans le jeu.
##
## On y entre depuis la fiche d'un bâtiment gérable (tuile « Gérer l'hôtel »).
## La maquette isométrique (GestionDiorama) occupe tout l'écran : pièces,
## personnel à son poste, clients qui font la queue à la réception puis vont
## dans leur chambre, au restaurant, au bar, au spa ou à la piscine. En haut :
## les chiffres de l'établissement ; à droite : la pièce choisie (niveau,
## effets du niveau suivant, prix, employés) ou la vue d'ensemble (étoiles,
## objectifs, comptes, prix de la nuit) ; en bas : une tuile par pièce.
##
## Clic sur une pièce : la choisir. Clic sur un « ! » : régler la demande du
## client (pourboire, clients plus contents). Molette : zoom ; clic droit ou
## du milieu glissé, flèches, ZQSD/WASD : se déplacer. Échap : retour à la
## ville. Le temps du jeu continue (T, Maj + T restent actifs) : les clients
## vont au rythme de la ville, rien ne bouge en pause.

signal ferme

const CARTE_W := 360.0
const ZOOM_MIN := 12.0
const ZOOM_MAX := 64.0
## Clients visibles : un pour N clients réels (au plus MAX_VISIBLES).
const CLIENTS_PAR_FIGURINE := 5.0
const MAX_VISIBLES := 22
## Durées en secondes « visibles » (multipliées par la vitesse du jeu).
const ARRIVEE := 2.4
const GUICHET := 3.2
const DEMANDE_TOUTES := 6.5
const DEMANDE_DUREE := 22.0
const MAX_DEMANDES := 3

var gestion: Gestion
var tourisme: Tourisme
var population: Population
var buildings: BuildingSystem
var bid := -1
var genre := ""
var selection := ""

var diorama: GestionDiorama
var cam: Camera3D
var _cible := Vector3(18, 0, 14)
var _zoom := 36.0
var _glisse := false
var _racine: Control
var _vue: SubViewportContainer
var _sv: SubViewport
var _haut: Label
var _chiffres: HBoxContainer
var _carte: PanelContainer
var _carte_corps: VBoxContainer
var _bas: HBoxContainer
var _toast: Label
var _t_arrivee := 0.0
var _t_guichet := 0.0
var _t_demande := 0.0
var _t_ui := 0.0
var _toast_t := 0.0
var _vue_main_3d := false
var rng := RandomNumberGenerator.new()


func setup(g: Gestion, t: Tourisme, p: Population, b: BuildingSystem) -> void:
	gestion = g
	tourisme = t
	population = p
	buildings = b
	layer = 40
	visible = false
	_build()
	gestion.changed.connect(func(id: int) -> void:
		if id == bid and est_ouvert():
			_reconstruire()
			_remplir_carte())


func est_ouvert() -> bool:
	return visible and bid >= 0


## Ouvre l'écran de gestion d'un bâtiment (false : il ne se gère pas).
func ouvrir(id: int) -> bool:
	if gestion == null or not gestion.gerable(id):
		return false
	bid = id
	genre = gestion.genre_of(id)
	gestion.etat(id)
	selection = ""
	visible = true
	# La ville n'est plus dessinée derrière (gain de temps de rendu).
	var vp := _racine.get_viewport()
	_vue_main_3d = vp.disable_3d
	vp.disable_3d = true
	for c in diorama.clients.duplicate():
		(c.fig as Node).queue_free()
	diorama.clients.clear()
	diorama._prises.clear()
	_reconstruire()
	var plan: Vector2 = GestionTypes.genre(genre).get("plan", Vector2(30, 22))
	_cible = Vector3(plan.x * 0.5 + 9.0, 0, plan.y * 0.5 - 1.0)
	_zoom = 40.0
	_placer_camera()
	_remplir_haut()
	_remplir_bas()
	_remplir_carte()
	# Quelques clients déjà là, pour ne pas entrer dans un hôtel vide.
	for i in mini(_cible_visibles(), 6):
		var c := diorama.ajouter_client()
		var f: Figurine = c.fig
		f.position = diorama.place_file(0) + Vector3(0, 0, 1.0)
		c.chemin = []
		c.etat = "file"
		_envoyer(c, false)
	return true


func fermer() -> void:
	if not visible:
		return
	visible = false
	bid = -1
	if _racine != null:
		_racine.get_viewport().disable_3d = _vue_main_3d
	ferme.emit()


# --- Construction de l'écran -------------------------------------------------------------------

func _build() -> void:
	_racine = Control.new()
	_racine.name = "GestionRacine"
	_racine.set_anchors_preset(Control.PRESET_FULL_RECT)
	_racine.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_racine)
	_vue = SubViewportContainer.new()
	_vue.name = "Maquette"
	_vue.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vue.stretch = true
	_vue.mouse_filter = Control.MOUSE_FILTER_STOP
	_vue.gui_input.connect(_entree_vue)
	_racine.add_child(_vue)
	_sv = SubViewport.new()
	_sv.own_world_3d = true
	_sv.msaa_3d = Viewport.MSAA_4X
	_sv.handle_input_locally = false
	_sv.size = Vector2i(1600, 900)
	_vue.add_child(_sv)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("9fd3b8")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	var we := WorldEnvironment.new()
	we.environment = env
	_sv.add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-58, -32, 0)
	sol.light_energy = 0.85
	sol.shadow_enabled = true
	sol.directional_shadow_max_distance = 140.0
	_sv.add_child(sol)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.near = 0.5
	cam.far = 400.0
	_sv.add_child(cam)
	cam.current = true
	diorama = GestionDiorama.new()
	diorama.name = "Diorama"
	_sv.add_child(diorama)
	_build_haut()
	_build_carte()
	_build_bas()
	_toast = Label.new()
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 16)
	_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_toast.add_theme_constant_override("outline_size", 6)
	_toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.position = Vector2(-420, -150)
	_toast.size = Vector2(840, 30)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_racine.add_child(_toast)


func _build_haut() -> void:
	var p := PanelContainer.new()
	UiStyle.style_panel(p, 0.9, 12, 8)
	p.set_anchors_preset(Control.PRESET_TOP_WIDE)
	p.offset_left = 12
	p.offset_right = -12
	p.offset_top = 10
	_racine.add_child(p)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	p.add_child(row)
	var ic := TextureRect.new()
	ic.texture = Icones.get_icon("lit", 26, UiStyle.ACCENT)
	ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	row.add_child(ic)
	_haut = Label.new()
	_haut.name = "Titre"
	_haut.add_theme_font_size_override("font_size", 19)
	row.add_child(_haut)
	_chiffres = HBoxContainer.new()
	_chiffres.add_theme_constant_override("separation", 8)
	_chiffres.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chiffres.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(_chiffres)
	var aide := UiStyle.icon_button("aide", "Clic sur une pièce : la choisir.\nClic sur un « ! » : régler la demande du client.\nMolette : zoom. Clic droit glissé, flèches ou ZQSD : se déplacer.\nT : pause, Maj + T : vitesse. Échap : retour à la ville.", "", 20, 36)
	row.add_child(aide)
	var x := UiStyle.icon_button("fermer", "Retour à la ville", "Échap", 20, 36)
	x.name = "Fermer"
	x.pressed.connect(fermer)
	row.add_child(x)


func _build_carte() -> void:
	_carte = PanelContainer.new()
	_carte.name = "Carte"
	UiStyle.style_panel(_carte, 0.9, 12, 10)
	_carte.anchor_left = 1.0
	_carte.anchor_right = 1.0
	_carte.offset_left = -CARTE_W - 12
	_carte.offset_right = -12
	_carte.offset_top = 74
	_carte.custom_minimum_size = Vector2(CARTE_W, 0)
	_racine.add_child(_carte)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(CARTE_W - 20, 0)
	_carte.add_child(sc)
	_carte_corps = VBoxContainer.new()
	_carte_corps.add_theme_constant_override("separation", 6)
	_carte_corps.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_carte_corps)
	_carte.set_meta("scroll", sc)


func _build_bas() -> void:
	var p := PanelContainer.new()
	UiStyle.style_panel(p, 0.9, 12, 8)
	p.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	p.offset_bottom = -12
	_racine.add_child(p)
	_bas = HBoxContainer.new()
	_bas.name = "Pieces"
	_bas.add_theme_constant_override("separation", 6)
	p.add_child(_bas)


# --- Remplissage -----------------------------------------------------------------------------------

func _reconstruire() -> void:
	diorama.construire(genre, gestion.etat(bid).niv, gestion.etoiles(bid))
	diorama.placer_employes(_employes())
	diorama.surligner(selection)


## Employés réels du bâtiment, rangés par pièce selon leur métier.
func _employes() -> Array:
	var out: Array = []
	if population == null:
		return out
	var pris := {}
	for pid in population.by_job.get(bid, []):
		var p: Dictionary = population.persons.get(int(pid), {})
		if p.is_empty():
			continue
		var met := String(p.get("met", ""))
		# Première pièce construite de ce métier où il reste un poste libre.
		var piece := ""
		var repli := ""
		for pc in GestionTypes.ordre(genre):
			var d := GestionTypes.piece(genre, String(pc))
			if not met in (d.get("metiers", []) as Array) or gestion.niveau(bid, String(pc)) <= 0:
				continue
			if repli == "":
				repli = String(pc)
			if int(pris.get(pc, 0)) < (d.get("postes", []) as Array).size():
				piece = String(pc)
				break
		if piece == "":
			piece = repli
		if piece != "":
			pris[piece] = int(pris.get(piece, 0)) + 1
			out.append({"piece": piece, "met": met, "pid": int(pid), "nom": String(p.get("n", ""))})
	return out


static func etoiles_txt(n: int) -> String:
	return "★".repeat(clampi(n, 0, 5)) + "☆".repeat(5 - clampi(n, 0, 5))


func _remplir_haut() -> void:
	if bid < 0:
		return
	_haut.text = "%s  %s" % [tourisme.nom(bid) if tourisme != null else "", etoiles_txt(gestion.etoiles(bid))]
	for c in _chiffres.get_children():
		_chiffres.remove_child(c)
		c.queue_free()
	var n := tourisme.clients(bid) if tourisme != null else 0
	var l := tourisme.lits(bid) if tourisme != null else 0
	var st: Dictionary = tourisme.heb.get(bid, {}) if tourisme != null else {}
	_chip("banque", "Compte de l'hôtel : %s" % BuildingSystem.format_money(int(gestion.compte(bid))),
		"Bénéfices accumulés par l'hôtel. Les améliorations se paient d'abord avec ce compte.")
	_chip("mairie", "Ville : %s" % BuildingSystem.format_money(gestion.caisse_ville()), "Caisse de la ville : elle avance ce qui manque.")
	_chip("lit", "%d / %d lits" % [n, l], "Clients ce soir / lits de l'hôtel.")
	_chip("sourire", "Note %.1f / 5" % (tourisme.note(bid) if tourisme != null else 0.0), "Note de l'hôtel : confort, prix et avis des clients.")
	_chip("habitants", "Satisfaction %.1f / 5" % float(st.get("satisf", 3.0)), "Ce que pensent les clients en ce moment.")
	var hier: Dictionary = st.get("hier", {})
	_chip("budget", "Hier : %s" % BuildingSystem.format_money(int(float(hier.get("ca", 0.0)) - float(hier.get("charges", 0.0)))),
		"Recettes moins charges de la veille (salaires, linge, énergie, entretien).")


func _chip(icone: String, texte: String, tip: String) -> void:
	var b := Button.new()
	b.text = texte
	b.icon = Icones.get_icon(icone, 18, UiStyle.ACCENT)
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = tip
	b.add_theme_font_size_override("font_size", 14)
	_chiffres.add_child(b)


func _remplir_bas() -> void:
	for c in _bas.get_children():
		_bas.remove_child(c)
		c.queue_free()
	var vue := _tuile_bas("", "Vue d'ensemble", "Objectifs, étoiles, comptes", "etoile")
	_bas.add_child(vue)
	for pid in GestionTypes.ordre(genre):
		var p := GestionTypes.piece(genre, String(pid))
		var n := gestion.niveau(bid, String(pid))
		var sous := ("Niveau %d / %d" % [n, gestion.niveau_max(bid, String(pid))]) if n > 0 else "À construire"
		var t := _tuile_bas(String(pid), String(p.nom), sous, "piece" if n > 0 else "plus")
		_bas.add_child(t)


func _tuile_bas(pid: String, titre: String, sous: String, icone: String) -> Button:
	var b := Button.new()
	b.name = "Tuile_" + (pid if pid != "" else "ensemble")
	b.text = "%s\n%s" % [titre, sous]
	b.icon = Icones.get_icon(icone, 20, UiStyle.ACCENT)
	b.toggle_mode = true
	b.button_pressed = selection == pid
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(112, 54)
	b.add_theme_font_size_override("font_size", 12)
	b.pressed.connect(func() -> void: choisir(pid))
	return b


## Choisit une pièce ("" : vue d'ensemble).
func choisir(pid: String) -> void:
	selection = pid
	diorama.surligner(pid)
	_remplir_bas()
	_remplir_carte()


func _titre(t: String, taille := 17) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", taille)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(CARTE_W - 30, 0)
	_carte_corps.add_child(l)
	return l


func _texte(t: String, dim := false, taille := 13) -> Label:
	var l := _titre(t, taille)
	if dim:
		l.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	return l


func _remplir_carte() -> void:
	if bid < 0:
		return
	for c in _carte_corps.get_children():
		_carte_corps.remove_child(c)
		c.queue_free()
	if selection == "":
		_carte_ensemble()
	else:
		_carte_piece(selection)
	# Hauteur : le contenu, au plus jusqu'à la barre du bas.
	var sc: ScrollContainer = _carte.get_meta("scroll")
	sc.custom_minimum_size.y = minf(560.0, _racine.get_viewport_rect().size.y - 74 - 110)


func _carte_piece(pid: String) -> void:
	var p := GestionTypes.piece(genre, pid)
	var n := gestion.niveau(bid, pid)
	var mx := gestion.niveau_max(bid, pid)
	_titre(String(p.nom), 19)
	_texte(("Niveau %d / %d   %s" % [n, mx, "■".repeat(n) + "□".repeat(mx - n)]) if n > 0 else "Pas encore construite", false, 15)
	_texte(String(p.get("desc", "")), true)
	var eff: Dictionary = p.get("effets", {})
	if n < mx:
		_texte("Au niveau %d :" % (n + 1), false, 14)
		for ligne in _lignes_effets(eff, pid):
			_texte("  • " + String(ligne), false, 13)
	# Employés de la pièce.
	var mets: Array = p.get("metiers", [])
	if not mets.is_empty():
		var noms: Array = []
		for e in _employes():
			if String(e.piece) == pid:
				noms.append("%s (%s)" % [String(e.nom), String(Metiers.METIERS.get(String(e.met), {}).get("name", e.met))])
		if noms.is_empty():
			_texte("Personne à ce poste : les habitants postulent tout seuls quand l'hôtel embauche. Pense aux logements et à l'école des métiers.", true)
		else:
			_texte("Équipe : " + ", ".join(noms.slice(0, 6)) + (" et %d autres" % (noms.size() - 6) if noms.size() > 6 else ""), true)
	var prix := gestion.prix(bid, pid)
	if prix <= 0:
		_texte("Niveau maximum atteint.", false, 14)
		return
	var r := gestion.repartition(bid, prix)
	var b := Button.new()
	b.name = "Ameliorer"
	b.text = ("Construire : %s" if n == 0 else "Améliorer : %s") % BuildingSystem.format_money(prix)
	b.icon = Icones.get_icon("grue" if n == 0 else "haut", 22, UiStyle.ACCENT_INK)
	b.add_theme_font_size_override("font_size", 16)
	b.custom_minimum_size = Vector2(0, 44)
	b.focus_mode = Control.FOCUS_NONE
	UiStyle.tint_pressed(b, UiStyle.ACCENT, UiStyle.ACCENT_INK)
	b.add_theme_stylebox_override("normal", UiStyle.flat_box(UiStyle.ACCENT, 9, 8))
	b.add_theme_color_override("font_color", UiStyle.ACCENT_INK)
	var manque := not buildings.unlimited_money and int(r.ville) > gestion.caisse_ville()
	b.disabled = manque
	b.pressed.connect(func() -> void:
		var res := gestion.ameliorer(bid, pid)
		if not bool(res.ok):
			_dire("Impossible : %s." % String(res.error), Color("ffb4a2"))
		else:
			diorama.flotter(diorama.centre(pid), "Niveau %d !" % gestion.niveau(bid, pid), Color("9fe3b0"))
			_remplir_haut()
			_remplir_bas())
	_carte_corps.add_child(b)
	if buildings.unlimited_money:
		_texte("Argent illimité : les travaux sont gratuits.", true)
	elif int(r.ville) <= 0:
		_texte("Payé par le compte de l'hôtel.", true)
	elif int(r.batiment) > 0:
		_texte("%s payés par l'hôtel, %s avancés par la ville." % [BuildingSystem.format_money(int(r.batiment)), BuildingSystem.format_money(int(r.ville))], true)
	else:
		_texte("Le compte de l'hôtel est vide : la ville avance %s (remboursables)." % BuildingSystem.format_money(int(r.ville)), true)
	if manque:
		_texte("Pas assez d'argent dans la caisse de la ville.", false)


func _lignes_effets(eff: Dictionary, _pid: String) -> Array:
	var out: Array = []
	if eff.has("lits"):
		out.append("+%d %% de lits (%d lits de plus)" % [roundi(float(eff.lits) * 100.0), roundi(float(TourismeTypes.lits_de(gestion.spec_base(bid))) * float(eff.lits))])
	if eff.has("confort"):
		out.append("+%.2f de note (confort)" % float(eff.confort))
	if eff.has("attrait"):
		out.append("+%d %% de clients attirés" % roundi(float(eff.attrait) * 100.0))
	if eff.has("satisf"):
		out.append("+%.2f de satisfaction chaque jour" % float(eff.satisf))
	if eff.has("repas"):
		out.append("+%d %% de repas pris sur place" % roundi(float(eff.repas) * 100.0))
	if eff.has("entretien"):
		out.append("Entretien : +%s par jour" % BuildingSystem.format_money(int(eff.entretien)))
	return out


func _carte_ensemble() -> void:
	_titre("%s  %s" % [tourisme.nom(bid) if tourisme != null else "", etoiles_txt(gestion.etoiles(bid))], 18)
	var av := gestion.avant_etoile(bid)
	if av > 0.0:
		_texte("Prochaine étoile : encore +%.2f de confort (chambres, bar, restaurant, spa, piscine)." % av, true)
	else:
		_texte("5 étoiles : le sommet !", true)
	_texte("Objectifs", false, 15)
	for o in gestion.objectifs(bid):
		var l := _texte("%s  %s  (%s)" % ["✔" if bool(o.fait) else "○", String(o.texte), String(o.avance)], false, 13)
		if bool(o.fait):
			l.add_theme_color_override("font_color", UiStyle.GOOD)
	var st: Dictionary = tourisme.heb.get(bid, {}) if tourisme != null else {}
	var hier: Dictionary = st.get("hier", {})
	_texte("Comptes d'hier", false, 15)
	_texte("Recettes %s · charges %s (dont entretien des améliorations %s)" % [BuildingSystem.format_money(int(hier.get("ca", 0.0))),
		BuildingSystem.format_money(int(hier.get("charges", 0.0))), BuildingSystem.format_money(int(gestion.entretien_jour(bid)))], true)
	var et: Dictionary = gestion.etat(bid)
	_texte("Investi : %s · pourboires : %s · demandes réglées : %d, oubliées : %d" % [BuildingSystem.format_money(int(et.invest)),
		BuildingSystem.format_money(int(et.pourboires)), int(et.reglees), int(et.ratees)], true)
	# Prix de la nuit.
	if tourisme != null and tourisme.heb.has(bid):
		var row := HBoxContainer.new()
		_carte_corps.add_child(row)
		var l := Label.new()
		l.text = "Prix de la nuit : %s par personne" % BuildingSystem.format_money(roundi(float(st.prix)))
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		for d in [[-1, "moins"], [1, "plus"]]:
			var b := UiStyle.icon_button(String(d[1]), "Baisser le prix" if int(d[0]) < 0 else "Monter le prix", "", 18, 32)
			var sens := int(d[0])
			b.pressed.connect(func() -> void:
				tourisme.set_prix(bid, roundf(float(tourisme.heb[bid].prix) * (1.0 + 0.05 * sens)))
				_remplir_carte())
			row.add_child(b)
	if float(et.aide_ville) > 0.5:
		var b := Button.new()
		b.text = "Rembourser la ville (%s avancés)" % BuildingSystem.format_money(int(et.aide_ville))
		b.focus_mode = Control.FOCUS_NONE
		b.disabled = gestion.compte(bid) < 1.0
		b.pressed.connect(func() -> void:
			var v := gestion.rembourser(bid)
			if v > 0:
				_dire("%s rendus à la caisse de la ville." % BuildingSystem.format_money(v)))
		_carte_corps.add_child(b)
	_texte("Clique sur une pièce de la maquette (ou une tuile en bas) pour l'améliorer. Les « ! » au-dessus des clients sont des demandes : clique dessus.", true, 12)


func _dire(t: String, col := Color.WHITE) -> void:
	_toast.text = t
	_toast.add_theme_color_override("font_color", col)
	_toast_t = 4.0


# --- Caméra et souris --------------------------------------------------------------------------

func _placer_camera() -> void:
	cam.size = _zoom
	var dir := Vector3(1, 0, 1).normalized() * cos(deg_to_rad(35.264)) + Vector3.UP * sin(deg_to_rad(35.264))
	cam.position = _cible + dir * 90.0
	cam.look_at(_cible, Vector3.UP)


func _entree_vue(ev: InputEvent) -> void:
	var mb := ev as InputEventMouseButton
	if mb != null and mb.pressed:
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_zoom = clampf(_zoom * 0.9, ZOOM_MIN, ZOOM_MAX)
				_placer_camera()
			MOUSE_BUTTON_WHEEL_DOWN:
				_zoom = clampf(_zoom * 1.1, ZOOM_MIN, ZOOM_MAX)
				_placer_camera()
			MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
				_glisse = true
			MOUSE_BUTTON_LEFT:
				cliquer(mb.position)
	elif mb != null and not mb.pressed and mb.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		_glisse = false
	var mm := ev as InputEventMouseMotion
	if mm != null and _glisse:
		var px := _zoom / maxf(1.0, float(_sv.size.y))
		var droite := cam.global_transform.basis.x
		var avant := Vector3(-cam.global_transform.basis.z.x, 0, -cam.global_transform.basis.z.z).normalized()
		_cible -= droite * mm.relative.x * px
		_cible += avant * mm.relative.y * px * 1.7
		_placer_camera()


## Clic dans la maquette (coordonnées de la vue) : une bulle, sinon une pièce.
func cliquer(p: Vector2) -> void:
	var c := diorama.client_sous(cam, p)
	if not c.is_empty():
		_regler(c)
		return
	var o := cam.project_ray_origin(p)
	var d := cam.project_ray_normal(p)
	if absf(d.y) < 0.0001:
		return
	var t := -o.y / d.y
	var sol := o + d * t
	choisir(diorama.piece_en(sol))


func _input(ev: InputEvent) -> void:
	if not est_ouvert():
		return
	var k := ev as InputEventKey
	if k == null:
		return
	# T et Maj + T (pause, vitesse) restent à la ville.
	if k.keycode == KEY_T:
		return
	_racine.get_viewport().set_input_as_handled()
	if not k.pressed:
		return
	if k.keycode == KEY_ESCAPE:
		if selection != "":
			choisir("")
		else:
			fermer()


func _process(delta: float) -> void:
	if not est_ouvert():
		return
	if gestion == null or not gestion.gerable(bid):
		fermer()
		return
	# Clavier : se déplacer.
	var dx := 0.0
	var dz := 0.0
	if Input.is_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A):
		dx -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D):
		dx += 1.0
	if Input.is_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_W):
		dz += 1.0
	if Input.is_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_S):
		dz -= 1.0
	if dx != 0.0 or dz != 0.0:
		var droite := cam.global_transform.basis.x
		var avant := Vector3(-cam.global_transform.basis.z.x, 0, -cam.global_transform.basis.z.z).normalized()
		_cible += (droite * dx + avant * dz) * delta * _zoom * 0.8
		_placer_camera()
	if _toast_t > 0.0:
		_toast_t -= delta
		_toast.modulate.a = clampf(_toast_t, 0.0, 1.0)
	_t_ui -= delta
	if _t_ui <= 0.0:
		_t_ui = 0.6
		_remplir_haut()
	simuler(delta * clampf(EchelleTemps.facteur(), 0.0, 3.0))


# --- Vie de l'établissement ---------------------------------------------------------------------

func _cible_visibles() -> int:
	var n := tourisme.clients(bid) if tourisme != null else 0
	if n <= 0:
		return 0
	return clampi(ceili(float(n) / CLIENTS_PAR_FIGURINE), 2, MAX_VISIBLES)


## Une étape de la vie de l'hôtel (dt en secondes « visibles »).
func simuler(dt: float) -> void:
	if dt <= 0.0:
		return
	# Arrivées.
	_t_arrivee -= dt
	if _t_arrivee <= 0.0:
		_t_arrivee = ARRIVEE * rng.randf_range(0.7, 1.3)
		if diorama.clients.size() < _cible_visibles():
			diorama.ajouter_client()
	# Réception : un client servi toutes les GUICHET secondes (plus vite au niveau supérieur).
	var file := diorama.file_attente()
	if not file.is_empty():
		var premier: Dictionary = file[0]
		var au_guichet := (premier.fig as Node3D).position.distance_to(diorama.place_file(0)) < 0.3
		if au_guichet:
			_t_guichet -= dt
			if _t_guichet <= 0.0:
				var nv := gestion.niveau(bid, "reception")
				var vide := diorama.vacants.has("reception")
				_t_guichet = GUICHET / (1.0 + 0.3 * float(nv - 1)) * (2.5 if vide else 1.0)
				_envoyer(premier, true)
	for e in diorama.avancer(dt):
		var c: Dictionary = e.client
		match String(e.type):
			"entre":
				diorama.ranger_file()
			"installe":
				_gain_visible(c)
	# Demandes des clients.
	_t_demande -= dt
	if _t_demande <= 0.0:
		_t_demande = DEMANDE_TOUTES * rng.randf_range(0.6, 1.4)
		_nouvelle_demande()
	for c in diorama.clients:
		if not (c.demande as Dictionary).is_empty():
			c.demande_t = float(c.get("demande_t", DEMANDE_DUREE)) - dt
			if float(c.demande_t) <= 0.0:
				c.demande = {}
				diorama.poser_bulle(c, null)
				gestion.rater(bid)
				diorama.flotter((c.fig as Node3D).position, "Oublié…", Color("ffb4a2"))


## Le client quitte le guichet pour une pièce (selon les envies et les places).
func _envoyer(c: Dictionary, montrer: bool) -> void:
	var choix: Array = []
	var tot := 0.0
	for a in GestionTypes.genre(genre).get("activites", []):
		if gestion.niveau(bid, String(a[0])) > 0 and not (diorama.places.get(String(a[0]), []) as Array).is_empty():
			choix.append(a)
			tot += float(a[1])
	var duree := rng.randf_range(14.0, 28.0)
	for essai in 3:
		var r := rng.randf() * tot
		for a in choix:
			r -= float(a[1])
			if r <= 0.0:
				if diorama.installer(c, String(a[0]), duree):
					if montrer and tourisme != null and tourisme.heb.has(bid):
						diorama.flotter(diorama.place_file(0) + Vector3(0, 0, -1.0), "+%s" % BuildingSystem.format_money(roundi(float(tourisme.heb[bid].prix))))
					diorama.ranger_file()
					return
				break
	# Rien de libre : il repart (complet).
	diorama._partir(c)
	diorama.ranger_file()


## Petit gain affiché quand un client s'installe (repas, cocktail, soin).
func _gain_visible(c: Dictionary) -> void:
	var montants := {"restaurant": Ressources.REPAS * 1.5, "bar": 9.0, "spa": 45.0}
	var pid := String(c.piece)
	if montants.has(pid):
		diorama.flotter((c.fig as Node3D).position, "+%s" % BuildingSystem.format_money(roundi(float(montants[pid]))))


func _nouvelle_demande() -> void:
	var actives := 0
	for c in diorama.clients:
		if not (c.demande as Dictionary).is_empty():
			actives += 1
	if actives >= MAX_DEMANDES:
		return
	var possibles := gestion.demandes_possibles(bid)
	if possibles.is_empty():
		return
	var candidats: Array = []
	for c in diorama.clients:
		if not (c.demande as Dictionary).is_empty():
			continue
		var ou := String(c.piece) if String(c.etat) == "installe" else ("reception" if String(c.etat) in ["file", "guichet"] else "")
		if ou == "":
			continue
		for d in possibles:
			if String(d.piece) == ou:
				candidats.append([c, d])
	if candidats.is_empty():
		return
	var pick: Array = candidats[rng.randi() % candidats.size()]
	var c: Dictionary = pick[0]
	c.demande = pick[1]
	c.demande_t = DEMANDE_DUREE
	# Le client reste le temps qu'on lui réponde.
	if String(c.etat) == "installe":
		c.attente = maxf(float(c.attente), DEMANDE_DUREE + 1.0)
	var l := Label3D.new()
	l.name = "Bulle"
	l.text = "!"
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 110
	l.pixel_size = 0.016
	l.outline_size = 24
	l.modulate = Color("ffd166")
	l.outline_modulate = Color("7a4b00")
	l.no_depth_test = true
	var sous := Label3D.new()
	sous.text = String(pick[1].texte)
	sous.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sous.font_size = 44
	sous.pixel_size = 0.0125
	sous.outline_size = 12
	sous.outline_modulate = Color(0, 0, 0, 0.85)
	sous.no_depth_test = true
	sous.position = Vector3(0, 1.0, 0)
	l.add_child(sous)
	diorama.poser_bulle(c, l)


## Demande réglée d'un clic : pourboire et clients contents.
func _regler(c: Dictionary) -> void:
	var d: Dictionary = c.demande
	if d.is_empty():
		return
	var tip := gestion.regler(bid, d)
	c.demande = {}
	diorama.poser_bulle(c, null)
	diorama.flotter((c.fig as Node3D).position, "+%s pourboire" % BuildingSystem.format_money(roundi(tip)), Color("9fe3b0"))
	var mots: Array = GestionTypes.genre(genre).get("pensees", {}).get("regle", ["Merci !"])
	_dire("« %s » %s" % [String(d.texte), String(mots[rng.randi() % mots.size()])], Color("d8f3dc"))
	if String(c.etat) == "installe":
		c.attente = minf(float(c.attente), rng.randf_range(6.0, 14.0))
	if selection == "":
		_remplir_carte()
