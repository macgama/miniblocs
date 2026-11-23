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
const ZOOM_MAX := 90.0
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
## Onglet de la vue d'ensemble : ensemble, personnel, stats, journal.
var onglet := "ensemble"

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
var _auto: Button
var _icone: TextureRect
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
	_icone.texture = Icones.get_icon(String(_gd().get("icone", "lit")), 26, UiStyle.ACCENT)
	selection = ""
	onglet = "ensemble"
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
	var e := diorama.emprise()
	_cible = Vector3((float(e[0]) + float(e[2])) * 0.5 - 2.0, 0, (float(e[1]) + float(e[3])) * 0.5 - 5.5)
	_zoom = 52.0
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
	_icone = TextureRect.new()
	_icone.texture = Icones.get_icon("lit", 26, UiStyle.ACCENT)
	_icone.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	row.add_child(_icone)
	_haut = Label.new()
	_haut.name = "Titre"
	_haut.add_theme_font_size_override("font_size", 19)
	row.add_child(_haut)
	_chiffres = HBoxContainer.new()
	_chiffres.add_theme_constant_override("separation", 8)
	_chiffres.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chiffres.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(_chiffres)
	_auto = Button.new()
	_auto.name = "Auto"
	_auto.toggle_mode = true
	_auto.focus_mode = Control.FOCUS_NONE
	_auto.icon = Icones.get_icon("tourner", 18, UiStyle.ACCENT)
	_auto.add_theme_font_size_override("font_size", 14)
	_auto.toggled.connect(func(on: bool) -> void:
		if bid >= 0:
			gestion.set_auto(bid, on)
			_dire(("Gestion automatique : %s se débrouille seul." % _le()) if on else ("Tu gères %s toi-même." % _le()))
			_maj_auto())
	row.add_child(_auto)
	var aide := UiStyle.icon_button("aide", "Clic sur une pièce : la choisir.\nClic sur un « ! » : régler la demande du client.\nClic sur un ⚠ : réparer la panne.\nMolette : zoom. Clic droit glissé, flèches ou ZQSD : se déplacer.\nT : pause, Maj + T : vitesse. Échap : retour à la ville.", "", 20, 36)
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
	var st := gestion.etat(bid)
	diorama.miniatures = _miniatures_parc() if _parc() else {}
	diorama.construire(genre, st.niv, gestion.etoiles(bid), st.obj, st.pannes, gestion.nom(bid))
	diorama.placer_employes(_employes())
	diorama.surligner(selection)
	_maj_engins(false)


## Le parc de loisirs : ses vraies attractions, rangées par zone de la
## maquette (aquatique, grands frissons, petits, manèges familiaux).
func _miniatures_parc() -> Dictionary:
	var out := {}
	var pc := ParcLoisirs.instance
	if pc == null or not is_instance_valid(pc) or not pc.parcs.has(bid):
		return out
	for b in pc.attractions_ok(bid):
		var t := pc._type_of(int(b))
		var z := GestionVue.zone_attraction(t)
		if not out.has(z):
			out[z] = []
		(out[z] as Array).append(t)
	return out


## Zone de la maquette du parc où va une attraction.
static func zone_attraction(t: String) -> String:
	var sp := ParcTypes.spec_of(t)
	var cat := BuildingCatalog.get_type(t)
	if String(cat.get("groupe", "")) == "eau" or String(sp.get("anim", "")) in ["bouees", "vagues", "jets", "bateaux", "pedalos"] or String(sp.get("voie", "")) == "eau":
		return "aquatique"
	if float(sp.get("exc", 3.0)) >= 5.5:
		return "sensations"
	if float(sp.get("int", 3.0)) <= 1.0 and float(sp.get("exc", 3.0)) <= 2.0:
		return "enfants"
	return "manege"


func _parc() -> bool:
	return bid >= 0 and gestion.source(bid) == "parc"


## Métiers que le bâtiment du jeu embauche (les autres pièces prennent des extras).
func _metiers_du_type() -> Dictionary:
	var out := {}
	if _parc():
		for b in gestion.batiments_parc(bid):
			for m in Metiers.jobs_for(gestion.type_of(int(b))):
				out[String(m[0])] = true
		return out
	for m in gestion.spec_base(bid).get("metiers", []):
		out[String(m[0])] = true
	for k in Metiers.keys_of(gestion.type_of(bid)) + [genre]:
		if Metiers.PAR_BATIMENT.has(String(k)):
			for m in Metiers.PAR_BATIMENT[String(k)]:
				out[String(m[0])] = true
			break
	return out


## Employés réels du bâtiment, rangés par pièce selon leur métier. Les
## pièces ajoutées par la gestion (boutique, sport, jardin…) dont le bâtiment
## n'embauche pas le métier ont des extras, payés dans leur entretien.
func _employes() -> Array:
	var out: Array = []
	var pris := {}
	var lieux: Array = gestion.batiments_parc(bid) if _parc() else [bid]
	var embauches: Array = []
	if population != null:
		for b in lieux:
			embauches.append_array(population.by_job.get(int(b), []))
	if population != null:
		for pid in embauches:
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
	var du_type := _metiers_du_type()
	for pc in GestionTypes.ordre(genre):
		var d := GestionTypes.piece(genre, String(pc))
		var mets: Array = d.get("metiers", [])
		if mets.is_empty() or gestion.niveau(bid, String(pc)) <= 0 or int(pris.get(pc, 0)) > 0:
			continue
		# Métier embauché par le bâtiment : poste vacant tant que personne
		# n'a ce métier ; s'il y en a déjà ailleurs, un extra vient aider.
		var embauche := false
		for m in mets:
			embauche = embauche or (du_type.has(String(m)) and not _a_le_metier(out, String(m)))
		if embauche:
			continue
		for i in (d.get("postes", []) as Array).size():
			out.append({"piece": String(pc), "met": String(mets[i % mets.size()]), "pid": 700000 + bid * 31 + i * 7 + String(pc).length(), "nom": "Extra", "extra": true})
	return out


## Engins de la caserne dans la remise ; un départ fait sonner l'alerte.
func _maj_engins(anime: bool) -> void:
	var liste: Array = []
	var u := gestion.urgences
	if _ville() and u != null and u.stations.has(bid):
		for e in u.stations[bid].units:
			liste.append({"model": String(e.get("model", u.model_for(String(e.base)))) if bool(e.out) else u.model_for(String(e.base)), "out": bool(e.out)})
	var partis := diorama.placer_engins(liste, anime)
	if partis > 0:
		diorama.alerte()
		var dernier := ""
		for e in (gestion.etat(bid).journal as Array).slice(0, 1):
			dernier = String(e[1])
		_dire("Alerte ! " + (dernier if dernier.begins_with("Départ") else "Un%s %s part en intervention." % ["e" if _gs("vehicule", "engin") == "voiture" else "", _gs("vehicule", "engin")]), Color("ffb4a2"))


func _gd() -> Dictionary:
	return GestionTypes.genre(genre)


## « l'hôtel », « le restaurant »…
func _le() -> String:
	return String(_gd().get("le", "l'établissement"))


func _du() -> String:
	return String(_gd().get("du", "de l'établissement"))


## Pièce où les clients font la queue en arrivant.
func _accueil() -> String:
	return String(_gd().get("accueil", "reception"))


static func _a_le_metier(liste: Array, met: String) -> bool:
	for e in liste:
		if String(e.met) == met and not bool(e.get("extra", false)):
			return true
	return false


static func etoiles_txt(n: int) -> String:
	return "★".repeat(clampi(n, 0, 5)) + "☆".repeat(5 - clampi(n, 0, 5))


func _remplir_haut() -> void:
	if bid < 0:
		return
	_haut.text = "%s  %s" % [gestion.nom(bid), etoiles_txt(gestion.etoiles(bid))]
	for c in _chiffres.get_children():
		_chiffres.remove_child(c)
		c.queue_free()
	if _ville():
		_haut_ville()
		return
	if _parc():
		_haut_parc()
		return
	var n := gestion.clients(bid)
	var l := gestion.capacite(bid)
	var resto := gestion.source(bid) == "production"
	_chip("banque", "Compte : %s" % BuildingSystem.format_money(int(gestion.compte(bid))),
		"Bénéfices accumulés par %s. Les améliorations se paient d'abord avec ce compte." % _le())
	_chip("mairie", "Ville : %s" % BuildingSystem.format_money(gestion.caisse_ville()), "Caisse de la ville : elle avance ce qui manque.")
	if _gd().has("chip_txt"):
		var hh: Dictionary = gestion.hier(bid)
		_chip(String(_gd().get("chip", "industrie")), String(_gd().chip_txt) % [_qte(float(hh.get("clients", 0.0))), _qte(float(hh.get("cap", 0.0)))], String(_gd().get("chip_tip", "")))
	elif resto:
		_chip("couverts", "%d / %d couverts" % [n, l], "Repas servis hier / couverts possibles par jour (tables et personnel).")
	else:
		_chip("lit", "%d / %d lits" % [n, l], "Clients ce soir / lits de l'hôtel.")
	_chip("sourire", "Note %.1f" % gestion.note(bid), "Note %s sur 5 : confort, prix et avis des clients." % _du())
	_chip("habitants", "Satisfaction %.1f" % gestion.satisf(bid), "Ce que pensent les clients en ce moment (sur 5).")
	var hier: Dictionary = gestion.hier(bid)
	_chip("budget", "Hier : %s" % BuildingSystem.format_money(int(float(hier.get("ca", 0.0)) - float(hier.get("charges", 0.0)))),
		"Recettes moins charges de la veille (salaires, %s, entretien)." % _gs("charges_txt", "produits, énergie" if resto else "linge, énergie"))
	if resto and bool(hier.get("manque", false)):
		var bm := _chip("commerce", "Produits manquants", _gs("manque_txt", "Il manque de la viande, des légumes ou des boissons : il faut des livraisons (fournisseurs, routes)."))
		bm.add_theme_color_override("font_color", Color("ffb703"))
	var np := (gestion.etat(bid).pannes as Array).size()
	if np > 0:
		var b := _chip("construire", "%d panne%s" % [np, "s" if np > 1 else ""], "Des appareils sont en panne : clique sur les ⚠ de la maquette ou va dans Personnel.")
		b.add_theme_color_override("font_color", Color("ffb703"))
	_maj_auto()


## Service public (caserne) : budget, engins, garde, délai, note, moral.
func _haut_ville() -> void:
	_chip("banque", "Budget : %s" % BuildingSystem.format_money(int(gestion.compte(bid))),
		"Argent de %s : le budget versé chaque jour par la ville, moins l'entretien. Les améliorations se paient d'abord avec." % _le())
	_chip("mairie", "Ville : %s" % BuildingSystem.format_money(gestion.caisse_ville()), "Caisse de la ville : elle verse le budget et avance ce qui manque.")
	var vs := _gs("vehicules", "engins")
	_chip(String(_gd().get("icone", "pompiers")), "%d / %d %s au garage" % [gestion.clients(bid), gestion.capacite(bid), vs],
		"%s prêts à partir / %s %s. %s en accueille plus à chaque niveau." % [_maj1(vs), vs, _du(), _maj1(_gs("garage", "la remise"))])
	var u := gestion.urgences
	if u != null and u.stations.has(bid) and u.staff_of(bid) < 999:
		_chip("habitants", "%d %s" % [mini(u.staff_of(bid), 999), _gs("de_garde", "de garde")], "%s %s aujourd'hui (dont %d grâce à la gestion et aux %s). Chaque %s a besoin de son équipage pour partir." % [
			_maj1(_gs("agents", "pompiers")), _gs("de_garde", "de garde"), gestion.equipage(bid), "réservistes" if _gs("agent", "pompier") == "policier" else "volontaires", _gs("vehicule", "engin")])
	var dl := float(gestion.etat(bid).get("delai", -1.0))
	_chip("horloge", ("Délai %s" % Urgences.format_time(dl)) if dl >= 0.0 else "Pas encore d'intervention", "Temps moyen entre l'appel et l'arrivée des équipes %s. Plus il est court, meilleure est la note." % _du())
	_chip("sourire", "Note %.1f" % gestion.note(bid), "Note %s sur 5 : délai d'arrivée, moral et galons." % _du())
	_chip("etoile", "Moral %.1f" % gestion.satisf(bid), "Moral de l'équipe (sur 5) : salaires, formation, cuisine, chambres, pannes.")
	var hier: Dictionary = gestion.hier(bid)
	if not hier.is_empty():
		_chip("budget", "Hier : %d intervention%s" % [int(hier.get("clients", 0)), "s" if int(hier.get("clients", 0)) > 1 else ""], "Équipes arrivées sur les lieux hier (%d en retard)." % int(hier.get("retards", 0)))
	var np := (gestion.etat(bid).pannes as Array).size()
	if np > 0:
		var b := _chip("construire", "%d panne%s" % [np, "s" if np > 1 else ""], "Du matériel est en panne : clique sur les ⚠ de la maquette ou va dans Équipe.")
		b.add_theme_color_override("font_color", Color("ffb703"))
	_maj_auto()


func _ville() -> bool:
	return bid >= 0 and gestion.source(bid) == "ville"


## Parc de loisirs : caisse des travaux, visiteurs, note, humeur, billet, attente.
func _haut_parc() -> void:
	var pc := ParcLoisirs.instance
	_chip("banque", "Caisse des travaux : %s" % BuildingSystem.format_money(int(gestion.compte(bid))),
		"Chaque jour, %d %% du bénéfice du parc est mis de côté ici pour ses travaux. Le reste va dans la caisse de la ville." % roundi(Gestion.PARC_REINVEST * 100.0))
	_chip("mairie", "Ville : %s" % BuildingSystem.format_money(gestion.caisse_ville()), "Caisse de la ville : elle reçoit les billets et avance ce qui manque pour les travaux.")
	_chip("habitants", "%d visiteurs" % gestion.clients(bid), "Visiteurs d'hier (ou présents en ce moment). Les attractions peuvent en faire tourner environ %d par jour." % gestion.capacite(bid))
	_chip("sourire", "Note %.1f" % gestion.note(bid), "Note du parc sur 5 : variété, humeur, propreté, files, prix, fiabilité, services et aménagements.")
	_chip("etoile", "Humeur %.1f" % gestion.satisf(bid), "Humeur moyenne des visiteurs (sur 5).")
	_chip("budget", "Billet %s" % BuildingSystem.format_money(roundi(gestion.prix_unitaire(bid))), gestion.prix_txt(bid))
	if pc != null and pc.parcs.has(bid):
		_chip("horloge", "Attente %d min" % roundi(float(pc.parcs[bid].attente)), "Attente moyenne dans les files des attractions.")
		var pannes_reelles := 0
		for b in pc.attractions_ok(bid):
			if bool(pc.items[b].panne):
				pannes_reelles += 1
		if pannes_reelles > 0:
			var bp := _chip("loisirs", "%d manège%s arrêté%s" % [pannes_reelles, "s" if pannes_reelles > 1 else "", "s" if pannes_reelles > 1 else ""], "Des attractions du parc sont en panne : les techniciens de l'atelier les réparent (Maj + G → Attractions).")
			bp.add_theme_color_override("font_color", Color("ffb703"))
	var np := (gestion.etat(bid).pannes as Array).size()
	if np > 0:
		var b := _chip("construire", "%d panne%s" % [np, "s" if np > 1 else ""], "Du matériel est en panne : clique sur les ⚠ de la maquette ou va dans Équipe.")
		b.add_theme_color_override("font_color", Color("ffb703"))
	_maj_auto()
## Une quantité en tonnes, lisible (0,35 · 4,2 · 180).
static func _qte(t: float) -> String:
	if t >= 100.0:
		return "%d" % roundi(t)
	if t >= 10.0:
		return "%.1f" % t
	return "%.2f" % t


## Majuscule à la première lettre seulement.
static func _maj1(t: String) -> String:
	return t.substr(0, 1).to_upper() + t.substr(1)


## Un texte du genre (clé directe), sinon celui de la caserne.
func _gs(cle: String, defaut: String) -> String:
	return String(_gd().get(cle, defaut))


## Un mot du genre (effets, pourboires…), sinon le mot habituel.
func _mot(cle: String, defaut: String) -> String:
	return String((_gd().get("mots", {}) as Dictionary).get(cle, defaut))


func _chip(icone: String, texte: String, tip: String) -> Button:
	var b := Button.new()
	b.text = texte
	b.icon = Icones.get_icon(icone, 18, UiStyle.ACCENT)
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = tip
	b.add_theme_font_size_override("font_size", 14)
	_chiffres.add_child(b)
	return b


func _maj_auto() -> void:
	if _auto == null or bid < 0:
		return
	var on := gestion.auto(bid)
	_auto.set_pressed_no_signal(on)
	_auto.text = "Gestion auto" if on else "Je gère"
	if _ville():
		_auto.tooltip_text = ("Gestion automatique : %s répare ses pannes et investit son budget %s " % [_le(), _gs("seul", "tout seul")]
			+ "(sans jamais toucher à la caisse de la ville). Clique pour %s gérer toi-même." % ("la" if _gs("seul", "") == "toute seule" else "le")) if on else \
			"Tu gères toi-même : améliorations, objets, salaires, réparations. Clique pour laisser %s se gérer %s." % [_le(), _gs("seul", "tout seul").trim_prefix("tout ").trim_prefix("toute ")]
		return
	_auto.tooltip_text = ("Gestion automatique : %s répare ses pannes, ajuste son prix chaque semaine et investit ses bénéfices tout seul " % _le()
		+ "(sans jamais toucher à la caisse de la ville). Clique pour le gérer toi-même.") if on else \
		"Tu gères toi-même : améliorations, objets, prix, salaires et réparations. Clique pour laisser %s se gérer seul." % _le()


func _remplir_bas() -> void:
	for c in _bas.get_children():
		_bas.remove_child(c)
		c.queue_free()
	var vue := _tuile_bas("", "Ensemble", "%s, comptes" % String(_gd().get("classe", "étoiles")).capitalize(), "etoile")
	_bas.add_child(vue)
	var pannes := {}
	for p in gestion.etat(bid).pannes:
		pannes[String(p.piece)] = true
	for pid in GestionTypes.ordre(genre):
		var p := GestionTypes.piece(genre, String(pid))
		var n := gestion.niveau(bid, String(pid))
		var nobj := GestionTypes.objets(genre, String(pid)).size()
		var sous := ("Niv. %d/%d · %d/%d" % [n, gestion.niveau_max(bid, String(pid)), gestion.objets_de(bid, String(pid)).size(), nobj]) if n > 0 else "À construire"
		var t := _tuile_bas(String(pid), String(p.get("court", p.nom)), sous, "construire" if pannes.has(String(pid)) else ("piece" if n > 0 else "plus"))
		if pannes.has(String(pid)):
			t.add_theme_color_override("font_color", Color("ffb703"))
			t.tooltip_text = "Panne à réparer"
		_bas.add_child(t)


func _tuile_bas(pid: String, titre: String, sous: String, icone: String) -> Button:
	var b := Button.new()
	b.name = "Tuile_" + (pid if pid != "" else "ensemble")
	b.text = "%s\n%s" % [titre, sous]
	b.icon = Icones.get_icon(icone, 16, UiStyle.ACCENT)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.toggle_mode = true
	b.button_pressed = selection == pid
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(98, 62)
	b.add_theme_font_size_override("font_size", 11)
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
		_onglets()
		match onglet:
			"personnel":
				_carte_personnel()
			"stats":
				_carte_stats()
			"journal":
				_carte_journal()
			"essor":
				GestionEssorVue.carte_essor(self)
			"avis":
				GestionEssorVue.carte_avis(self)
			_:
				_carte_ensemble()
	else:
		_carte_piece(selection)
	# Hauteur : le contenu, au plus jusqu'à la barre du bas.
	var sc: ScrollContainer = _carte.get_meta("scroll")
	sc.custom_minimum_size.y = minf(600.0, _racine.get_viewport_rect().size.y - 74 - 120)


func _onglets() -> void:
	# Deux rangées de trois onglets : la carte garde sa largeur.
	var row := GridContainer.new()
	row.columns = 3
	row.name = "Onglets"
	row.add_theme_constant_override("h_separation", 4)
	row.add_theme_constant_override("v_separation", 4)
	_carte_corps.add_child(row)
	for o in [["ensemble", String(_gd().get("nom", "Ensemble")), "etoile"], ["personnel", "Équipe", "emploi"], ["essor", "Essor", "trophee"], ["avis", "Avis", "etoile"], ["stats", "Chiffres", "tableau"], ["journal", "Journal", "journal"]]:
		var b := Button.new()
		b.name = "Onglet_" + String(o[0])
		b.text = String(o[1])
		b.icon = Icones.get_icon(String(o[2]), 16, UiStyle.ACCENT)
		b.toggle_mode = true
		b.button_pressed = onglet == String(o[0])
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 13)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var id := String(o[0])
		b.pressed.connect(func() -> void:
			onglet = id
			_remplir_carte())
		row.add_child(b)
	_carte_corps.add_child(HSeparator.new())


func _bouton(texte: String, icone: String, principal := false) -> Button:
	var b := Button.new()
	b.text = texte
	b.icon = Icones.get_icon(icone, 18 if not principal else 22, UiStyle.ACCENT_INK if principal else UiStyle.ACCENT)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 16 if principal else 13)
	if principal:
		b.custom_minimum_size = Vector2(0, 44)
		UiStyle.tint_pressed(b, UiStyle.ACCENT, UiStyle.ACCENT_INK)
		b.add_theme_stylebox_override("normal", UiStyle.flat_box(UiStyle.ACCENT, 9, 8))
		b.add_theme_color_override("font_color", UiStyle.ACCENT_INK)
	return b


## Résultat d'un achat : message, chiffre qui monte, écran à jour.
func _apres(res: Dictionary, ou: Vector3, texte: String) -> void:
	if not bool(res.ok):
		_dire("Impossible : %s." % String(res.error), Color("ffb4a2"))
		return
	diorama.flotter(ou, texte, Color("9fe3b0"))
	_remplir_haut()
	_remplir_bas()
	_remplir_carte()


func _carte_piece(pid: String) -> void:
	var p := GestionTypes.piece(genre, pid)
	var n := gestion.niveau(bid, pid)
	var mx := gestion.niveau_max(bid, pid)
	_titre(String(p.nom), 19)
	_texte(("Niveau %d / %d   %s" % [n, mx, "■".repeat(n) + "□".repeat(mx - n)]) if n > 0 else "Pas encore construite", false, 15)
	_texte(String(p.get("desc", "")), true)
	for pn in gestion.etat(bid).pannes:
		if String(pn.piece) == pid:
			var l := _texte("⚠ Panne : %s (réparer dans Équipe ou d'un clic sur la maquette)" % String(pn.texte), false, 13)
			l.add_theme_color_override("font_color", Color("ffb703"))
	var eff: Dictionary = p.get("effets", {})
	if n < mx:
		_texte("Au niveau %d :" % (n + 1), false, 14)
		for ligne in _lignes_effets(eff):
			_texte("  • " + String(ligne), false, 13)
	# Employés de la pièce.
	var mets: Array = p.get("metiers", [])
	if not mets.is_empty() and n > 0:
		var noms: Array = []
		var extras := 0
		for e in _employes():
			if String(e.piece) == pid:
				if bool(e.get("extra", false)):
					extras += 1
				else:
					noms.append("%s (%s)" % [String(e.nom), String(Metiers.METIERS.get(String(e.met), {}).get("name", e.met))])
		if extras > 0:
			_texte("Équipe : %d extra%s (payés dans l'entretien de la pièce)." % [extras, "s" if extras > 1 else ""], true)
		elif noms.is_empty():
			_texte("Personne à ce poste : les habitants postulent tout seuls quand %s embauche. Pense aux logements et à l'école des métiers." % _le(), true)
		else:
			_texte("Équipe : " + ", ".join(noms.slice(0, 6)) + (" et %d autres" % (noms.size() - 6) if noms.size() > 6 else ""), true)
	var prix := gestion.prix(bid, pid)
	if prix <= 0:
		_texte("Niveau maximum atteint.", false, 14)
	else:
		var r := gestion.repartition(bid, prix)
		var b := _bouton(("Construire : %s" if n == 0 else "Améliorer : %s") % BuildingSystem.format_money(prix), "grue" if n == 0 else "haut", true)
		b.name = "Ameliorer"
		var manque := not buildings.unlimited_money and int(r.ville) > gestion.caisse_ville()
		b.disabled = manque
		b.pressed.connect(func() -> void:
			var res := gestion.ameliorer(bid, pid)
			_apres(res, diorama.centre(pid), "Niveau %d !" % gestion.niveau(bid, pid)))
		_carte_corps.add_child(b)
		if buildings.unlimited_money:
			_texte("Argent illimité : les travaux sont gratuits.", true)
		elif int(r.ville) <= 0:
			_texte("Payé par le compte %s." % _du(), true)
		elif int(r.batiment) > 0:
			_texte(("%s payés par " + _le() + ", %s avancés par la ville.") % [BuildingSystem.format_money(int(r.batiment)), BuildingSystem.format_money(int(r.ville))], true)
		else:
			_texte(("Le compte " + _du() + " est vide : la ville avance %s (remboursables).") % BuildingSystem.format_money(int(r.ville)), true)
		if manque:
			_texte("Pas assez d'argent dans la caisse de la ville.", false)
	# Objets à installer.
	var objs := GestionTypes.objets(genre, pid)
	if objs.is_empty():
		return
	_carte_corps.add_child(HSeparator.new())
	_texte("Objets (%d / %d installés)" % [gestion.objets_de(bid, pid).size(), objs.size()], false, 15)
	for oid in objs:
		var o: Dictionary = objs[oid]
		var row := HBoxContainer.new()
		row.name = "Objet_" + String(oid)
		row.add_theme_constant_override("separation", 6)
		_carte_corps.add_child(row)
		var l := Label.new()
		l.text = "%s\n%s" % [String(o.nom), ", ".join(_lignes_effets(o.get("effets", {}), true))]
		l.add_theme_font_size_override("font_size", 12)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.custom_minimum_size = Vector2(170, 0)
		row.add_child(l)
		var refus := gestion.refus_objet(bid, pid, String(oid))
		var b := Button.new()
		b.name = "Acheter"
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 12)
		b.custom_minimum_size = Vector2(112, 0)
		if refus == "déjà installé":
			b.text = "✔ Installé"
			b.disabled = true
			l.add_theme_color_override("font_color", UiStyle.GOOD)
		elif refus != "":
			b.text = "Niveau %d requis" % int(o.get("niv", 1)) if refus.begins_with("pièce au") else "Construire d'abord"
			b.disabled = true
			l.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
		else:
			var px := gestion.prix_objet(bid, pid, String(oid))
			b.text = BuildingSystem.format_money(px)
			b.icon = Icones.get_icon("plus", 14, UiStyle.ACCENT)
			b.disabled = not buildings.unlimited_money and int(gestion.repartition(bid, px).ville) > gestion.caisse_ville()
			var id := String(oid)
			b.pressed.connect(func() -> void:
				var res := gestion.acheter(bid, pid, id)
				_apres(res, diorama.centre(pid), "%s !" % String(o.nom)))
		row.add_child(b)


func _lignes_effets(eff: Dictionary, court := false) -> Array:
	var out: Array = []
	if eff.has("engins"):
		var n := roundi(float(eff.engins))
		var ve := _gs("vehicule", "engin")
		out.append(("+%d " + ve if court else "+%d " + ve + " dans " + _gs("garage", "la remise") + " (il lui faut son équipage)") % n)
	if eff.has("equipage"):
		var n := roundi(float(eff.equipage))
		out.append(("+%d " + _gs("de_garde", "de garde") if court else "+%d " + _gs("agent", "pompier") + " " + _gs("de_garde", "de garde") + ", prêt à partir") % n)
	if eff.has("lits_sup"):
		out.append(("+%d lits" if court else "+%d lits d'hôpital pour la ville") % roundi(float(eff.lits_sup)))
	if eff.has("soins"):
		out.append(("+%d %% soins" if court else "+%d %% de malaises sauvés malgré le retard") % roundi(float(eff.soins) * 100.0))
	if eff.has("enquete"):
		out.append(("+%d %% enquêtes" if court else "+%d %% de cambriolages élucidés même en retard") % roundi(float(eff.enquete) * 100.0))
	if eff.has("fiabilite"):
		out.append(("+%d %% fiabilité" if court else "Manèges %d %% moins usés, révisions plus efficaces") % roundi(float(eff.fiabilite) * 100.0))
	if eff.has("proprete"):
		out.append(("+%d %% propreté" if court else "Agents de propreté %d %% plus efficaces") % roundi(float(eff.proprete) * 100.0))
	if eff.has("couverts"):
		out.append(("+%d %% couverts" if court else "+%d %% de couverts (tables en plus)") % roundi(float(eff.couverts) * 100.0))
	if eff.has("cadence"):
		out.append(("+%d %% production" if court else "+%d %% de production chaque jour (matières transformées)") % roundi(float(eff.cadence) * 100.0))
	if eff.has("matiere"):
		out.append(("+%d %% matière" if court else "+%d %% de produits pour la même matière (moins de déchets)") % roundi(float(eff.matiere) * 100.0))
	if eff.has("qualite"):
		out.append(("+%d %% prix" if court else "+%d %% sur le prix de vente des produits (qualité)") % roundi(float(eff.qualite) * 100.0))
	if eff.has("depollution"):
		out.append(("−%d %% pollution" if court else "−%d %% de pollution (air, eau, CO₂) autour de l'usine") % roundi(float(eff.depollution) * 100.0))
	if eff.has("economie"):
		out.append(("−%s / jour" if court else "−%s de factures d'énergie par jour") % BuildingSystem.format_money(roundi(float(eff.economie))))
	if eff.has("lits"):
		out.append(("+%d %% lits" if court else "+%d %% de lits") % roundi(float(eff.lits) * 100.0) + ("" if court else " (%d lits de plus)" % roundi(float(TourismeTypes.lits_de(gestion.spec_base(bid))) * float(eff.lits))))
	if eff.has("confort"):
		if _ville():
			out.append(("+%.2f expérience" if court else "+%.2f d'expérience (galons)") % float(eff.confort))
		else:
			out.append(("+%.2f confort" if court else "+%.2f de note (confort)") % float(eff.confort))
	if eff.has("attrait"):
		if _ville():
			var ma := _mot("attrait", "prestige (volontaires, dons)")
			out.append(("+%d %% " + ma.get_slice(" (", 0).get_slice(" des ", 0) if court else "+%d %% de " + ma) % roundi(float(eff.attrait) * 100.0))
		elif _parc():
			out.append(("+%d %% visiteurs" if court else "+%d %% de visiteurs attirés") % roundi(float(eff.attrait) * 100.0))
		elif _gd().has("mots") and (_gd().mots as Dictionary).has("attrait"):
			out.append(("+%d %% réputation" if court else "+%d %% de " + _mot("attrait", "")) % roundi(float(eff.attrait) * 100.0))
		else:
			out.append(("+%d %% clients" if court else "+%d %% de clients attirés") % roundi(float(eff.attrait) * 100.0))
	if eff.has("satisf"):
		if _ville():
			out.append(("+%.2f moral" if court else "+%.2f de moral pour l'équipe") % float(eff.satisf))
		elif _gd().has("mots") and (_gd().mots as Dictionary).has("satisf"):
			out.append(("+%.2f moral" if court else "+%.2f de " + _mot("satisf", "") + " chaque jour") % float(eff.satisf))
		else:
			out.append(("+%.2f satisfaction" if court else "+%.2f de satisfaction chaque jour") % float(eff.satisf))
	if eff.has("repas"):
		out.append(("+%d %% repas" if court else "+%d %% de repas pris sur place") % roundi(float(eff.repas) * 100.0))
	if eff.has("vitesse"):
		if _ville():
			out.append(("+%d %% rapidité" if court else "Travail sur place %d %% plus rapide") % roundi(float(eff.vitesse) * 100.0))
		else:
			out.append(("+%d %% vitesse" if court else "Service %d %% plus rapide") % roundi(float(eff.vitesse) * 100.0))
	if eff.has("ventes"):
		var vm := float(_gd().get("ventes_mult", 1.0))
		out.append(("+%s / client" if court else ("+%s dépensés par client et par nuit" if genre == "hotel" else "+%s dépensés par client")) % BuildingSystem.format_money(maxi(1, roundi(float(eff.ventes) * vm))))
	if eff.has("entretien") and not court:
		out.append("Entretien : +%s par jour" % BuildingSystem.format_money(int(eff.entretien)))
	return out


func _carte_ensemble() -> void:
	_titre("%s  %s" % [gestion.nom(bid), etoiles_txt(gestion.etoiles(bid))], 18)
	var et: Dictionary = gestion.etat(bid)
	if gestion.auto(bid):
		if _ville():
			_texte("Gestion automatique : %s répare et investit son budget %s. Tu peux quand même acheter ce que tu veux." % [_le(), _gs("seul", "tout seul")], true, 12)
		else:
			_texte("Gestion automatique : %s répare, ajuste son prix et investit ses bénéfices tout seul. Tu peux quand même acheter ce que tu veux." % _le(), true, 12)
	var cl := String(_gd().get("classe", "étoiles"))
	var av := gestion.avant_etoile(bid)
	if av > 0.0:
		_texte("%s : encore +%.2f %s (pièces et objets)." % [String(_gd().get("prochain", "Prochaine " + cl.trim_suffix("s"))), av, "d'expérience" if _ville() else "de confort"], true)
	else:
		_texte("5 %s : le sommet !" % cl, true)
	if int(et.label_fin) >= gestion.jour:
		var txt := ("★ " + String(_gd().get("label_court", "Citée en exemple")) + " encore %d jours (" + _gs("label_effet", "un pompier de garde en plus") + ")." if _ville() else ("★ Label Sécurité encore %d jours (+6 %% de visiteurs)." if _parc() else "★ Recommandé par le guide encore %d jours (+6 %% de clients).")) % (int(et.label_fin) - gestion.jour)
		var l := _texte(txt, false, 13)
		l.add_theme_color_override("font_color", UiStyle.GOOD)
	if _ville():
		_ensemble_ville(et)
	if _parc():
		_ensemble_parc(et)
	_texte("Objectifs", false, 15)
	for o in gestion.objectifs(bid):
		var l := _texte("%s  %s  (%s)" % ["✔" if bool(o.fait) else "○", String(o.texte), String(o.avance)], false, 13)
		if bool(o.fait):
			l.add_theme_color_override("font_color", UiStyle.GOOD)
	var hier: Dictionary = gestion.hier(bid)
	_texte("Comptes d'hier", false, 15)
	if _ville():
		_texte("Budget reçu %s · entretien des améliorations %s" % [BuildingSystem.format_money(int(hier.get("ca", gestion.dotation(bid)))),
			BuildingSystem.format_money(int(gestion.entretien_jour(bid)))], true)
		_texte("Investi : %s · dons : %s · demandes réglées : %d, oubliées : %d" % [BuildingSystem.format_money(int(et.invest)),
			BuildingSystem.format_money(int(et.pourboires)), int(et.reglees), int(et.ratees)], true)
	else:
		_texte("Recettes %s · charges %s (dont entretien des améliorations %s)" % [BuildingSystem.format_money(int(hier.get("ca", 0.0))),
			BuildingSystem.format_money(int(hier.get("charges", 0.0))), BuildingSystem.format_money(int(gestion.entretien_jour(bid)))], true)
		_texte("Investi : %s · pourboires : %s · demandes réglées : %d, oubliées : %d" % [BuildingSystem.format_money(int(et.invest)),
			BuildingSystem.format_money(int(et.pourboires)), int(et.reglees), int(et.ratees)], true)
	# Prix de la nuit ou du menu.
	if gestion.valide(bid):
		var row := HBoxContainer.new()
		row.name = "Prix"
		_carte_corps.add_child(row)
		var l := Label.new()
		l.text = gestion.prix_txt(bid)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(220, 0)
		row.add_child(l)
		for d in [[-1, "moins"], [1, "plus"]]:
			var quoi := "le budget" if _ville() else _gs("prix_quoi", "le prix")
			var b := UiStyle.icon_button(String(d[1]), ("Baisser " if int(d[0]) < 0 else "Monter ") + quoi, "", 18, 32)
			b.name = "Prix_" + String(d[1])
			var sens := int(d[0])
			b.pressed.connect(func() -> void:
				gestion.changer_prix(bid, sens)
				_remplir_carte())
			row.add_child(b)
		if _ville():
			_texte("Plus de budget : %s s'équipe plus vite (même en gestion automatique), payé chaque jour par la caisse de la ville. À 0, elle ne fait plus que l'entretien." % _le(), true, 12)
		elif _parc():
			_texte("Plus cher : chaque billet rapporte plus, mais des familles font demi-tour et les visiteurs sont moins contents. En gestion automatique, le prix suit ce que vaut le parc.", true, 12)
		elif genre != "hotel":
			_texte(_gs("prix_aide", "Plus cher : chaque repas rapporte plus, mais il vient moins de monde et les clients sont moins contents."), true, 12)
	if float(et.aide_ville) > 0.5:
		var b := _bouton("Rembourser la ville (%s avancés)" % BuildingSystem.format_money(int(et.aide_ville)), "mairie")
		b.disabled = gestion.compte(bid) < 1.0
		b.pressed.connect(func() -> void:
			var v := gestion.rembourser(bid)
			if v > 0:
				_dire("%s rendus à la caisse de la ville." % BuildingSystem.format_money(v)))
		_carte_corps.add_child(b)
	_texte("Clique sur une pièce de la maquette (ou une tuile en bas) pour l'améliorer et l'équiper. Les « ! » au-dessus des clients sont des demandes, les ⚠ des pannes : clique dessus.", true, 12)


## Le vrai parc : attractions par zone, files, propreté, et ce que la gestion y change.
func _ensemble_parc(et: Dictionary) -> void:
	var pc := ParcLoisirs.instance
	if pc == null or not is_instance_valid(pc) or not pc.parcs.has(bid):
		return
	var p: Dictionary = pc.parcs[bid]
	_texte("Le parc aujourd'hui", false, 15)
	_texte("%s · %d visiteurs en ce moment · attente moyenne %d min · propreté %d / 100" % ["Ouvert" if bool(p.ouvert) else "Fermé",
		pc.presents(bid), roundi(float(p.attente)), roundi(pc.proprete(bid))], true)
	var mini := _miniatures_parc()
	for z in ["manege", "sensations", "aquatique", "enfants"]:
		var noms: Array = []
		for t in mini.get(z, []):
			noms.append(String(BuildingCatalog.get_type(String(t)).get("name", t)))
		var zn := String(GestionTypes.piece(genre, z).get("nom", z))
		_texte("%s : %s" % [zn, ", ".join(noms) if not noms.is_empty() else "aucune attraction (pose-en dans Construire → Parc de loisirs)"], true, 12)
	var effets: Array = []
	var at := ParcLoisirs.effet_gestion(bid, "attrait")
	if at > 0.0:
		effets.append("+%d %% de visiteurs" % roundi(at * 100.0))
	var cf := ParcLoisirs.effet_gestion(bid, "confort")
	if cf > 0.0:
		effets.append("+%.2f étoile" % cf)
	var vi := ParcLoisirs.effet_gestion(bid, "vitesse")
	if vi > 0.0:
		effets.append("manèges et stands %d %% plus rapides" % roundi(vi * 100.0))
	var fi := ParcLoisirs.effet_gestion(bid, "fiabilite")
	if fi > 0.0:
		effets.append("%d %% d'usure en moins" % roundi(fi * 100.0))
	var pr := ParcLoisirs.effet_gestion(bid, "proprete")
	if pr > 0.0:
		effets.append("propreté +%d %%" % roundi(pr * 100.0))
	var ve := gestion.effet(bid, "ventes")
	if ve > 0.0:
		effets.append("+%s dépensés par visiteur" % BuildingSystem.format_money(roundi(ve)))
	if not effets.is_empty():
		_texte("Dans le vrai parc : " + ", ".join(effets) + ".", true, 12)
	_texte("Mis de côté pour les travaux : %s · groupes et fêtes : %d · trophées : %d" % [BuildingSystem.format_money(int(et.get("reinvesti", 0.0))), int(et.get("groupes", 0)), int(et.get("trophees", 0))], true, 12)


## Interventions et engins de la caserne.
func _ensemble_ville(et: Dictionary) -> void:
	_texte("Interventions", false, 15)
	var dl := float(et.get("delai", -1.0))
	_texte("%d arrivées sur les lieux · délai moyen %s · %d en retard · %d départs" % [int(et.interventions),
		Urgences.format_time(dl) if dl >= 0.0 else "—", int(et.retards), int(et.departs)], true)
	if String(_gd().get("service", "")) == "ambulance":
		_texte("%d patients amenés par le SAMU · %d sauvés malgré un retard (chance %d %%) · %d lits en plus · parking %s" % [
			int(et.get("patients", 0)), int(et.get("sauves", 0)), roundi(gestion.chance_soins(bid) * 100.0), gestion.lits_sup(bid),
			BuildingSystem.format_money(int(et.get("parking", 0.0)))], true)
	if String(_gd().get("service", "")) == "police":
		_texte("Cambriolages élucidés par l'enquête malgré un retard : %d (%d non élucidés) · chance %d %% · %d voitures à la fourrière" % [
			int(et.get("elucides", 0)), int(et.get("non_elucides", 0)), roundi(gestion.chance_enquete(bid) * 100.0), int(et.get("fourriere", 0))], true)
	var u := gestion.urgences
	if u == null or not u.stations.has(bid):
		return
	for e in u.stations[bid].units:
		var m := String(e.get("model", u.model_for(String(e.base)))) if bool(e.out) else u.model_for(String(e.base))
		var nm := String(VehicleCatalog.get_type(m).get("name", m))
		var ou := "au garage"
		if bool(e.out):
			var inc: Dictionary = u.incidents.get(int(e.inc), {})
			ou = ("en intervention : %s" % String(inc.name)) if not inc.is_empty() else "sur le retour"
		var l := _texte("%s %s — %s%s" % ["●" if not bool(e.out) else "◌", nm, ou, " (gagné en gestion)" if bool(e.get("extra", false)) else ""], false, 12)
		if not bool(e.out) and not u.unit_ready(bid, e):
			l.text += " · manque d'équipage"
			l.add_theme_color_override("font_color", Color("ffb4a2"))
	_texte(_gs("conseil", "Chaque engin a besoin de son équipage pour partir : agrandis les chambres de garde, recrute des volontaires (prestige, formation)."), true, 12)


func _carte_personnel() -> void:
	var et: Dictionary = gestion.etat(bid)
	var emp := _employes()
	var reels := 0
	for e in emp:
		if not bool(e.get("extra", false)):
			reels += 1
	_titre("Équipe : %d employés, %d extras" % [reels, emp.size() - reels], 17)
	# Par pièce.
	var par := {}
	for e in emp:
		par[String(e.piece)] = int(par.get(String(e.piece), 0)) + 1
	for pid in GestionTypes.ordre(genre):
		var p := GestionTypes.piece(genre, String(pid))
		if gestion.niveau(bid, String(pid)) <= 0 or (p.get("postes", []) as Array).is_empty():
			continue
		var nb := int(par.get(String(pid), 0))
		var l := _texte("%s : %d / %d postes" % [String(p.nom), mini(nb, (p.postes as Array).size()), (p.postes as Array).size()], false, 13)
		if nb == 0:
			l.add_theme_color_override("font_color", Color("ffb4a2"))
	_carte_corps.add_child(HSeparator.new())
	# Salaires.
	var row := HBoxContainer.new()
	row.name = "Salaire"
	_carte_corps.add_child(row)
	var l := Label.new()
	l.text = "Salaires : %d %%" % roundi(float(et.salaire) * 100.0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", 15)
	row.add_child(l)
	for d in [[-1, "moins"], [1, "plus"]]:
		var b := UiStyle.icon_button(String(d[1]), "Baisser les salaires" if int(d[0]) < 0 else "Augmenter les salaires", "", 18, 32)
		b.name = "Salaire_" + ("moins" if int(d[0]) < 0 else "plus")
		var sens := int(d[0])
		b.pressed.connect(func() -> void:
			gestion.set_salaire(bid, float(gestion.etat(bid).salaire) + 0.05 * sens)
			_remplir_carte())
		row.add_child(b)
	if _ville():
		_texte("Mieux payée, l'équipe a meilleur moral (et la note suit) ; moins payée, %s économise mais l'équipe le sent." % _le(), true, 12)
		var u := gestion.urgences
		if u != null and u.stations.has(bid):
			_texte("De garde aujourd'hui : %d (dont %d volontaires et %d de plus grâce aux chambres)." % [u.staff_of(bid), int(et.get("volontaires", 0)), maxi(0, gestion.equipage(bid) - int(et.get("volontaires", 0)))], false, 13)
	else:
		_texte("Mieux payée, l'équipe sourit plus (satisfaction des clients) ; moins payée, %s économise mais les clients le sentent." % _le(), true, 12)
	# Formation.
	_texte("Formation : niveau %d / %d" % [int(et.formation), Gestion.FORMATION_MAX], false, 15)
	var pf := gestion.prix_formation(bid)
	if pf > 0:
		var b := _bouton("Former le personnel : %s" % BuildingSystem.format_money(pf), "ecole")
		b.name = "Former"
		b.disabled = not buildings.unlimited_money and int(gestion.repartition(bid, pf).ville) > gestion.caisse_ville()
		b.pressed.connect(func() -> void:
			_apres(gestion.former(bid), diorama.centre(_accueil()), "Formation !"))
		_carte_corps.add_child(b)
	_texte("Une équipe formée travaille plus vite sur place, a meilleur moral et casse moins de matériel." if _ville() else "Une équipe formée sert plus vite, rend les clients plus contents et casse moins de matériel.", true, 12)
	# Pannes.
	_carte_corps.add_child(HSeparator.new())
	var pannes: Array = et.pannes
	_texte("Pannes : %d" % pannes.size() if not pannes.is_empty() else "Aucune panne. Tout fonctionne !", false, 15)
	for i in pannes.size():
		var pn: Dictionary = pannes[i]
		var r2 := HBoxContainer.new()
		r2.name = "Panne_%d" % i
		_carte_corps.add_child(r2)
		var lp := Label.new()
		lp.text = "⚠ %s\n%s, depuis le jour %d" % [String(pn.texte), String(GestionTypes.piece(genre, String(pn.piece)).get("nom", pn.piece)), int(pn.get("jour", 0))]
		lp.add_theme_font_size_override("font_size", 12)
		lp.add_theme_color_override("font_color", Color("ffb703"))
		lp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lp.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lp.custom_minimum_size = Vector2(170, 0)
		r2.add_child(lp)
		var b := Button.new()
		b.name = "Reparer"
		b.text = "Réparer : %s" % BuildingSystem.format_money(gestion.prix_reparation(bid))
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 12)
		var idx := i
		b.pressed.connect(func() -> void: _reparer(idx))
		r2.add_child(b)
	if not pannes.is_empty():
		_texte("Chaque panne fait baisser le moral et la note tous les jours." if _ville() else "Chaque panne fait baisser la satisfaction des clients tous les jours.", true, 12)


func _reparer(i: int) -> void:
	var pannes: Array = gestion.etat(bid).pannes
	if i < 0 or i >= pannes.size():
		return
	var pid := String(pannes[i].piece)
	_apres(gestion.reparer(bid, i), diorama.centre(pid), "Réparé !")


func _carte_stats() -> void:
	var hist: Array = gestion.etat(bid).hist
	_titre("Les %d derniers jours" % mini(hist.size(), 30), 17)
	if hist.size() < 2:
		_texte("Les chiffres apparaissent après quelques jours d'ouverture.", true)
		return
	var h := hist.slice(maxi(0, hist.size() - 30))
	var ca := 0.0
	var ch := 0.0
	var occ := 0.0
	for e in h:
		ca += float(e[1])
		ch += float(e[2])
		occ += float(e[4])
	var g := GrapheGestion.new()
	g.name = "Graphe"
	g.donnees = h
	g.custom_minimum_size = Vector2(CARTE_W - 30, 150)
	_carte_corps.add_child(g)
	_texte(String(_gd().get("legende", "■ recettes   ■ charges   — remplissage")), true, 12)
	if _ville():
		var nint := 0
		for e in h:
			nint += int(e[3])
		_texte("Budget reçu : %s · entretien : %s · interventions : %d" % [BuildingSystem.format_money(int(ca)), BuildingSystem.format_money(int(ch)), nint], false, 13)
		_texte("%s : %d %% · note : %.1f · moral : %.1f" % [String(_gd().get("remplissage_nom", "Remplissage moyen")), roundi(occ / h.size() * 100.0), float(h[-1][5]), float(h[-1][6])], false, 13)
	else:
		_texte("Recettes : %s · charges : %s · bénéfice : %s" % [BuildingSystem.format_money(int(ca)), BuildingSystem.format_money(int(ch)), BuildingSystem.format_money(int(ca - ch))], false, 13)
		_texte("Remplissage moyen : %d %% · note : %.1f · satisfaction : %.1f" % [roundi(occ / h.size() * 100.0), float(h[-1][5]), float(h[-1][6])], false, 13)
	var et: Dictionary = gestion.etat(bid)
	_texte((String(_gd().get("evenement_nom", "Événements")) + (" : %d · visites : %d · pannes réparées : %d" if _ville() else " : %d · clients célèbres : %d · pannes réparées : %d")) % [int(et.seminaires), int(et.vip), int(et.reparees)], true, 12)


func _carte_journal() -> void:
	var j: Array = gestion.etat(bid).journal
	_titre("Journal %s" % _du(), 17)
	if j.is_empty():
		_texte("Rien encore. Les travaux, les achats, les pannes et les visites importantes s'inscrivent ici.", true)
		return
	for e in j.slice(0, 25):
		_texte("Jour %d · %s" % [int(e[0]), String(e[1])], false, 12)


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
	var pn := diorama.panne_sous(cam, p)
	if pn >= 0:
		_reparer(pn)
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
		_maj_engins(true)
	simuler(delta * clampf(EchelleTemps.facteur(), 0.0, 3.0))


# --- Vie de l'établissement ---------------------------------------------------------------------

func _cible_visibles() -> int:
	if _ville():
		# Visiteurs : stages de secourisme, écoles, futurs volontaires.
		return clampi(2 + gestion.niveau(bid, _accueil()) + gestion.niveau(bid, "formation"), 2, mini(MAX_VISIBLES, 9))
	if _gd().has("visiteurs"):
		# Visiteurs (chauffeurs, acheteurs, groupes) : selon les pièces qui les accueillent.
		var nv := 2
		for pc in _gd().visiteurs:
			nv += gestion.niveau(bid, String(pc))
		return clampi(nv, 2, mini(MAX_VISIBLES, 12))
	var n := gestion.clients(bid)
	if gestion.source(bid) == "production":
		# Repas par jour : beaucoup plus de passages que de nuitées.
		n = roundi(maxf(float(n), float(gestion.capacite(bid)) * 0.4) * 0.6)
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
				var nv := gestion.niveau(bid, _accueil())
				var vide := diorama.vacants.has(_accueil())
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
					if montrer and bool(_gd().get("paye_accueil", false)):
						diorama.flotter(diorama.place_file(0) + Vector3(0, 0, -1.0), "+%s" % BuildingSystem.format_money(roundi(gestion.prix_unitaire(bid))))
					diorama.ranger_file()
					return
				break
	# Rien de libre : il repart (complet).
	diorama._partir(c)
	diorama.ranger_file()


## Petit gain affiché quand un client s'installe (repas, cocktail, soin).
func _gain_visible(c: Dictionary) -> void:
	var montants: Dictionary = _gd().get("gains", {})
	var pid := String(c.piece)
	if montants.has(pid):
		var v: Variant = montants[pid]
		var e := gestion.prix_unitaire(bid) if v is String else float(v)
		diorama.flotter((c.fig as Node3D).position, "+%s" % BuildingSystem.format_money(roundi(e)))


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
		var ou := String(c.piece) if String(c.etat) == "installe" else (_accueil() if String(c.etat) in ["file", "guichet"] else "")
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
	diorama.flotter((c.fig as Node3D).position, "+%s %s" % [BuildingSystem.format_money(roundi(tip)), String(_gd().get("pourboire", "pourboire"))], Color("9fe3b0"))
	var mots: Array = GestionTypes.genre(genre).get("pensees", {}).get("regle", ["Merci !"])
	_dire("« %s » %s" % [String(d.texte), String(mots[rng.randi() % mots.size()])], Color("d8f3dc"))
	if String(c.etat) == "installe":
		c.attente = minf(float(c.attente), rng.randf_range(6.0, 14.0))
	if selection == "":
		_remplir_carte()
