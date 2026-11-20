class_name FilHabitants
extends PanelContainer
## Fil des habitants à l'écran (piste CityRT 8) : une petite carte en haut à
## gauche qui montre, une à une, ce que vivent et disent les habitants, comme un
## fil de réseau social. Deux sources :
##  - les étapes de vie marquantes (Population.etape_vie : embauche, mariage,
##    naissance, retraite, diplôme, arrivée, voiture…) ;
##  - une parole par jour de jeu tirée des Avis (Avis.paroles), avec son thème.
## Clic sur la carte : fiche de l'habitant (panneau Habitants, H). ◂ ▸ : posts
## précédents ou suivants. ✕ : replier la carte (son titre reste, clic pour la
## rouvrir). Le choix replié / ouvert est gardé dans user://interface.cfg.
## Les « j'aime » sont un clin d'œil : ils dépendent de l'habitant, du jour et de
## la taille de la ville, rien ne se joue dessus.

signal person_requested(pid: int)

const MAX_POSTS := 40
## Temps réel minimum entre deux nouveaux posts affichés (s) : le fil reste lisible
## même quand la ville est grande et que le temps file.
const ECART_AFFICHAGE := 6.0
const CFG := "user://interface.cfg"
## Étapes de vie gardées dans le fil (les autres sont trop fréquentes ou trop intimes).
const CODES := {"emploi": "emploi", "mariage": "fete", "enfant": "habitants", "retraite": "horloge", "diplome": "ecole",
	"arrivee": "logement", "voiture": "vehicules", "permis": "vehicules", "guerison": "sante", "sport": "sport",
	"couple": "sourire", "politique": "urne"}
const ICONE_THEME := {"emploi": "emploi", "logement": "logement", "services": "services", "securite": "bouclier",
	"environnement": "feuille", "transports": "circulation", "impots": "budget", "reseaux": "reseaux",
	"loisirs": "loisirs", "commerces": "commerce", "politique": "urne"}

var population: Population
var avis: Avis
## Posts du plus récent au plus ancien : {pid, nom, qui, texte, icone, jaime, jour, parole}.
var posts: Array = []
var replie := false

var _index := 0
var _attente: Array = []
var _depuis := ECART_AFFICHAGE
var _dernier_jour := -1
var _tick := 0.0

var _corps: VBoxContainer
var _titre: Button
var _icone: TextureRect
var _qui: Label
var _texte: Label
var _jaime: Label
var _prec: Button
var _suiv: Button


func _init() -> void:
	name = "FilHabitants"
	UiStyle.style_panel(self, 0.86, 10, 8)
	offset_left = 12.0
	offset_top = UiStyle.SIDE_TOP
	custom_minimum_size = Vector2(300, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	add_child(v)
	var tete := HBoxContainer.new()
	v.add_child(tete)
	_titre = Button.new()
	_titre.flat = true
	_titre.text = "Le fil des habitants"
	_titre.icon = Icones.get_icon("megaphone", 16, UiStyle.ACCENT)
	_titre.tooltip_text = "Ce que vivent et disent les habitants. Clic : replier ou rouvrir le fil"
	_titre.add_theme_font_size_override("font_size", 13)
	_titre.add_theme_color_override("font_color", UiStyle.ACCENT)
	_titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_titre.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_titre.pressed.connect(func() -> void: set_replie(not replie))
	tete.add_child(_titre)
	_prec = _petit_bouton("precedent", "Post plus ancien")
	_prec.pressed.connect(func() -> void: montrer(_index + 1))
	tete.add_child(_prec)
	_suiv = _petit_bouton("suivant", "Post plus récent")
	_suiv.pressed.connect(func() -> void: montrer(_index - 1))
	tete.add_child(_suiv)
	_corps = VBoxContainer.new()
	_corps.add_theme_constant_override("separation", 2)
	v.add_child(_corps)
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", 6)
	_corps.add_child(ligne)
	_icone = TextureRect.new()
	_icone.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_icone.custom_minimum_size = Vector2(20, 20)
	_icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ligne.add_child(_icone)
	_qui = Label.new()
	_qui.add_theme_font_size_override("font_size", 13)
	_qui.add_theme_color_override("font_color", UiStyle.TEXT)
	_qui.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_qui.clip_text = true
	_qui.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_qui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ligne.add_child(_qui)
	_texte = Label.new()
	_texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texte.custom_minimum_size = Vector2(284, 0)
	_texte.add_theme_font_size_override("font_size", 13)
	_texte.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	_texte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_corps.add_child(_texte)
	_jaime = Label.new()
	_jaime.add_theme_font_size_override("font_size", 11)
	_jaime.add_theme_color_override("font_color", Color("f4a6b8"))
	_jaime.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_corps.add_child(_jaime)
	_corps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_text = "Clic : fiche de l'habitant"
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	gui_input.connect(_on_gui_input)
	var cfg := ConfigFile.new()
	if cfg.load(CFG) == OK:
		replie = bool(cfg.get_value("fil_habitants", "replie", false))
	_rafraichir()


func _petit_bouton(icone: String, aide: String) -> Button:
	var b := Button.new()
	b.flat = true
	b.icon = Icones.get_icon(icone, 14, UiStyle.TEXT_DIM)
	b.tooltip_text = aide
	b.focus_mode = Control.FOCUS_NONE
	return b


func setup(pop: Population, av: Avis) -> void:
	population = pop
	avis = av
	if pop != null and not pop.etape_vie.is_connected(_on_etape):
		pop.etape_vie.connect(_on_etape)


## Vide le fil (nouvelle partie, chargement).
func clear() -> void:
	posts.clear()
	_attente.clear()
	_index = 0
	_dernier_jour = -1
	_rafraichir()


func set_replie(on: bool) -> void:
	replie = on
	var cfg := ConfigFile.new()
	cfg.load(CFG)
	cfg.set_value("fil_habitants", "replie", on)
	cfg.save(CFG)
	_rafraichir()


func _on_etape(p: Dictionary, code: String, texte: String, _ref: int) -> void:
	if not CODES.has(code) or population == null:
		return
	# Un mariage ou un couple est noté pour les deux : un seul post.
	if code == "mariage" or code == "couple":
		for q in _attente + posts.slice(0, 6):
			if int(q.get("ref", -2)) == int(p.id) and String(q.code) == code:
				return
	_attente.append(_post(p, code, texte, String(CODES[code]), false, _ref))
	if _attente.size() > 12:
		_attente.pop_front()


func _post(p: Dictionary, code: String, texte: String, icone: String, parole: bool, ref := -1) -> Dictionary:
	var age := population.age_years(p)
	var qui := "%s · %s · %d ans" % [CycleVie.full_name(p), population.stage_label(p).to_lower(), age]
	var jour := avis.jour() if avis != null else 0
	var n := maxi(population.persons.size(), 1)
	# Clin d'œil : quelques « j'aime » selon l'habitant, le jour et la taille de la ville.
	var jaime := (int(p.id) * 7 + jour * 13 + code.length() * 5) % maxi(4, int(sqrt(float(n)) * 1.5)) + (2 if parole else 0)
	return {"pid": int(p.id), "nom": CycleVie.full_name(p), "qui": qui, "texte": texte, "icone": icone,
		"jaime": jaime, "jour": jour, "parole": parole, "code": code, "ref": ref}


## Une parole par jour de jeu (habitant mécontent ou content, au hasard des Avis).
func _parole_du_jour() -> void:
	if avis == null or population == null or population.persons.is_empty():
		return
	var j := avis.jour()
	if j == _dernier_jour:
		return
	_dernier_jour = j
	var lst := avis.paroles(4)
	if lst.is_empty():
		return
	var e: Dictionary = lst[j % lst.size()]
	var pid := int(e.pid)
	if not population.persons.has(pid):
		return
	var t := "« %s »" % String(e.phrase)
	if String(e.motif) != "":
		t += " (%s)" % String(e.motif).trim_prefix("−").trim_prefix("+").strip_edges()
	_attente.append(_post(population.persons[pid], "parole", t, String(ICONE_THEME.get(String(e.theme), "sourire")), true))


func _process(delta: float) -> void:
	if population == null:
		return
	_tick += delta
	_depuis += delta
	if _tick >= 2.0:
		_tick = 0.0
		_parole_du_jour()
	if not _attente.is_empty() and _depuis >= ECART_AFFICHAGE:
		_depuis = 0.0
		ajouter(_attente.pop_front())


## Ajoute un post en tête du fil et le montre.
func ajouter(post: Dictionary) -> void:
	posts.push_front(post)
	if posts.size() > MAX_POSTS:
		posts.resize(MAX_POSTS)
	_index = 0
	_rafraichir()


func montrer(i: int) -> void:
	_index = clampi(i, 0, maxi(posts.size() - 1, 0))
	_rafraichir()


func post_affiche() -> Dictionary:
	return posts[_index] if _index < posts.size() else {}


func _rafraichir() -> void:
	if _corps == null:
		return
	visible = population != null and not posts.is_empty()
	_corps.visible = not replie and not posts.is_empty()
	_prec.visible = not replie and _index < posts.size() - 1
	_suiv.visible = not replie and _index > 0
	_titre.text = "Le fil des habitants" if not replie else "Le fil des habitants (%d)" % posts.size()
	if posts.is_empty():
		return
	var p: Dictionary = posts[_index]
	_icone.texture = Icones.get_icon(String(p.icone), 18, UiStyle.ACCENT if bool(p.parole) else UiStyle.GOOD)
	_qui.text = String(p.qui)
	_texte.text = String(p.texte)
	_jaime.text = "♥ %d j'aime" % int(p.jaime) if int(p.jaime) != 1 else "♥ 1 j'aime"
	if _index > 0:
		_jaime.text += "  ·  %d/%d" % [_index + 1, posts.size()]


func _on_gui_input(e: InputEvent) -> void:
	var mb := e as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT or replie:
		return
	var p := post_affiche()
	if p.is_empty():
		return
	accept_event()
	person_requested.emit(int(p.pid))
