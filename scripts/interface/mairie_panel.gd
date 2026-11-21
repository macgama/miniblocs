class_name MairiePanel
extends CanvasLayer
## Tableau de bord de la Mairie (touche M, tuile « Mairie ») : la porte d'entrée
## unique de la gestion. En haut, ce qu'il faut régler maintenant (avis du
## Conseiller, chacun avec son bouton), puis huit tuiles d'état (argent,
## habitants, satisfaction, emploi, services, réseaux, transports, déchets) qui
## ouvrent le panneau détaillé, et enfin tous les menus de gestion par thème.

## Ouvrir un panneau de gestion (id d'une catégorie de la barre ou de ouvrir_panneau).
signal panneau_requested(id: String)
## Le tableau de bord s'ouvre ou se ferme.
signal visibilite(on: bool)

const KEY := KEY_M
## Alertes affichées à la fois (Mairie et fil « À faire ») : les plus graves d'abord.
const MAX_ALERTES := 3

## Tuiles : titre, icône, indicateur principal, détail, panneau ouvert au clic.
const TUILES := [
	{"titre": "Argent", "icone": "budget", "ind": "caisse", "sous": "solde", "panneau": "budget"},
	{"titre": "Habitants", "icone": "habitants", "ind": "habitants", "sous": "logements_libres", "panneau": "habitants"},
	{"titre": "Satisfaction", "icone": "sourire", "ind": "satisfaction", "sous": "", "panneau": "avis"},
	{"titre": "Emploi", "icone": "emploi", "ind": "chomage", "sous": "emplois_libres", "panneau": "production"},
	{"titre": "Sans école", "icone": "ecole", "ind": "sans_ecole", "sous": "", "panneau": "services"},
	{"titre": "Réseaux", "icone": "reseaux", "ind": "coupures", "sous": "eau", "panneau": "reseaux", "pays": true},
	{"titre": "Transports", "icone": "circulation", "ind": "congestion", "sous": "trajet", "panneau": "trafic", "pays": true},
	{"titre": "Déchets", "icone": "dechets", "ind": "dechets", "sous": "recyclage", "panneau": "dechets", "pays": true},
]

## Tous les menus de gestion, rangés par thème (ids des catégories de TerreHud
## ou de terre_main.ouvrir_panneau).
const MENUS := [
	{"titre": "La ville", "ids": [["budget", "Budget et impôts"], ["habitants", "Habitants"], ["niveaux_vie", "Niveaux de vie"], ["avis", "Avis et élections"],
		["quartiers", "Quartiers et arrêtés"], ["objectifs", "Objectifs"], ["villages", "Villages"], ["pays", "Pays"], ["fondateurs", "Fondateurs et chantiers"], ["immobilier", "Immobilier"], ["visites", "Visites et cartes postales"]]},
	{"titre": "Services", "ids": [["services", "Écoles, santé, police"], ["urgences", "Urgences"], ["reseaux", "Eau, électricité, égouts"], ["dechets", "Déchets"], ["sante", "Santé publique"]]},
	{"titre": "Économie", "ids": [["production", "Production"], ["agriculture", "Agriculture"], ["commerce", "Commerce mondial"], ["tourisme", "Tourisme"]]},
	{"titre": "Transports", "ids": [["lignes", "Lignes"], ["trafic", "Trafic"]]},
	{"titre": "Loisirs", "ids": [["parc", "Parc de loisirs"], ["zoo", "Zoo"], ["musee", "Musée"], ["spectacles", "Spectacles"], ["club", "Club de sport"], ["patrimoine", "Patrimoine"]]},
	{"titre": "Infos", "ids": [["stats", "Statistiques"], ["cartes", "Cartes"], ["journal", "Gazette"], ["saisons", "Saisons et risques"], ["succes", "Succès"], ["climat", "Climat et pollution"], ["arbre", "Arbre de progression"]]},
]

var stats: Statistiques
## Lieu suivi : Callable -> String (Statistiques.PAYS ou id de ville), et son nom.
var lieu: Callable
var nom_lieu: Callable
## Avis d'autres systèmes qui ne passent pas par les statistiques :
## Callable(lieu: String) -> Array d'avis (mêmes clés que Conseiller._avis).
## Exemple : bâtiments non raccordés (Raccordements), bouton qui emmène au bâtiment.
var autres_alertes: Callable

var _panel: PanelContainer
var _body: VBoxContainer
var _title: Label


func _ready() -> void:
	_panel = PanelContainer.new()
	_panel.name = "Mairie"
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.custom_minimum_size = Vector2(820, 0)
	UiStyle.style_panel(_panel, 0.96, 14, 14)
	_panel.visible = false
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_panel.add_child(col)
	var head := HBoxContainer.new()
	var ic := TextureRect.new()
	ic.texture = Icones.get_icon("mairie", 26, UiStyle.ACCENT)
	ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(ic)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 20)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	var close := UiStyle.icon_button("fermer", "Fermer", "M", 18, 32)
	close.pressed.connect(func() -> void: set_open(false))
	head.add_child(close)
	col.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 470)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 8)
	scroll.add_child(_body)


func setup(st: Statistiques, l: Callable, n: Callable) -> void:
	stats = st
	lieu = l
	nom_lieu = n
	if st != null:
		st.releve_fait.connect(func() -> void:
			if is_open():
				refresh())


func is_open() -> bool:
	return _panel.visible


func set_open(on: bool) -> void:
	var was := _panel.visible
	_panel.visible = on
	if on:
		refresh()
	if was != on:
		visibilite.emit(on)


func toggle() -> void:
	set_open(not is_open())


func _lieu() -> String:
	return String(lieu.call()) if lieu.is_valid() else Statistiques.PAYS


static func _label(text: String, size := 13, color := Color.WHITE, wrap := true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.clip_text = true
	return l


## Avis à afficher : urgents et à surveiller d'abord (Conseiller), au plus n.
func alertes(n := MAX_ALERTES) -> Array:
	if stats == null:
		return []
	var out := []
	var liste := Conseiller.analyser(stats, _lieu())
	if autres_alertes.is_valid():
		var en_plus: Array = autres_alertes.call(_lieu())
		if not en_plus.is_empty():
			# « Tout va bien » n'a plus lieu d'être.
			liste = liste.filter(func(a) -> bool: return int(a.gravite) >= 1) + en_plus
			# À gravité égale, ce qui se règle d'un clic (« prio ») passe devant.
			liste.sort_custom(func(a, b) -> bool:
				var ka := int(a.gravite) * 10 + int(a.get("prio", 0))
				var kb := int(b.gravite) * 10 + int(b.get("prio", 0))
				return ka > kb)
	for a in liste:
		if int(a.gravite) >= 1 or out.is_empty():
			out.append(a)
		if out.size() >= n:
			break
	return out


## Nombre total d'alertes (urgentes ou à surveiller), même au-delà des 3 affichées.
func nombre_alertes() -> int:
	var n := 0
	for a in alertes(99):
		if int(a.gravite) >= 1:
			n += 1
	return n


func refresh() -> void:
	for ch in _body.get_children():
		_body.remove_child(ch)
		ch.queue_free()
	var nom := String(nom_lieu.call()) if nom_lieu.is_valid() else ""
	_title.text = "Mairie de %s" % nom if nom != "" else "Mairie"
	# --- À régler maintenant -----------------------------------------------------
	_body.add_child(_label("À RÉGLER MAINTENANT", 11, UiStyle.TEXT_DIM))
	var al := alertes()
	if al.is_empty():
		_body.add_child(_label("Le conseiller fera son premier relevé demain matin.", 13, UiStyle.TEXT_DIM))
	for a in al:
		_body.add_child(carte_alerte(a, func(id: String) -> void:
			set_open(false)
			panneau_requested.emit(id), false, _lieu()))
	var reste := nombre_alertes() - al.size()
	if reste > 0:
		_body.add_child(_label("+ %d autre%s, moins grave%s : elles passeront ici une fois celles-ci réglées." % [reste, "s" if reste > 1 else "", "s" if reste > 1 else ""], 12, UiStyle.TEXT_DIM))
	# --- État de la ville ---------------------------------------------------------
	_body.add_child(_label("ÉTAT DE LA VILLE", 11, UiStyle.TEXT_DIM))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_body.add_child(grid)
	for t in TUILES:
		grid.add_child(_tuile(t))
	# --- Tous les menus --------------------------------------------------------------
	_body.add_child(_label("TOUS LES MENUS DE GESTION", 11, UiStyle.TEXT_DIM))
	var menus := GridContainer.new()
	menus.columns = 3
	menus.add_theme_constant_override("h_separation", 12)
	menus.add_theme_constant_override("v_separation", 10)
	_body.add_child(menus)
	for m in MENUS:
		var c := VBoxContainer.new()
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.add_theme_constant_override("separation", 2)
		c.add_child(_label(String(m.titre), 14, UiStyle.ACCENT))
		for pair in m.ids:
			var id := String(pair[0])
			if EditionDemo.panneau_verrouille(id):
				continue
			var b := Button.new()
			b.name = "Menu_" + id
			b.text = String(pair[1])
			b.flat = true
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.focus_mode = Control.FOCUS_NONE
			var key := _key_of(id)
			if key != "":
				b.tooltip_text = "%s (%s)" % [pair[1], key]
			b.pressed.connect(func() -> void:
				set_open(false)
				panneau_requested.emit(id))
			c.add_child(b)
		menus.add_child(c)


static func _key_of(id: String) -> String:
	for c in TerreHud.CATEGORIES:
		if String(c.id) == id:
			return String(c.key)
	return ""


## Causes dépliées (« Pourquoi ? ») : id de l'avis -> true, gardé entre deux rafraîchissements.
static var causes_ouvertes := {}


## Carte d'un avis du Conseiller : pastille de couleur, titre, texte, bouton
## « Régler » (ouvre ce qu'il faut pour le régler) et « Pourquoi ? » qui déplie la
## cause chiffrée (Causes.de) : en un clic, on sait d'où vient le problème.
static func carte_alerte(a: Dictionary, ouvrir: Callable, compact := false, lieu: String = Statistiques.PAYS) -> Control:
	var g := int(a.gravite)
	var card := PanelContainer.new()
	card.name = "Alerte_" + String(a.get("id", ""))
	var sb := UiStyle.flat_box(Color(1, 1, 1, 0.05), 8, 8)
	sb.border_color = Conseiller.COULEURS[g]
	sb.border_width_left = 4
	card.add_theme_stylebox_override("panel", sb)
	var tout := VBoxContainer.new()
	tout.add_theme_constant_override("separation", 4)
	card.add_child(tout)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	tout.add_child(row)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 1)
	row.add_child(col)
	var tt := _label(String(a.titre), 13 if compact else 14, Color.WHITE, not compact)
	if compact:
		tt.tooltip_text = String(a.get("conseil", a.get("texte", "")))
		tt.mouse_filter = Control.MOUSE_FILTER_PASS
	col.add_child(tt)
	if not compact:
		col.add_child(_label(String(a.conseil) if String(a.get("conseil", "")) != "" else String(a.texte), 12, UiStyle.TEXT_DIM))
	var id := String(a.get("id", ""))
	# Cause chiffrée, dépliée par « Pourquoi ? » (seulement pour ce qui ne va pas).
	var boite: VBoxContainer = null
	if g >= 1:
		boite = VBoxContainer.new()
		boite.name = "Cause"
		boite.add_theme_constant_override("separation", 1)
		tout.add_child(boite)
		var remplir := func() -> void:
			for ch in boite.get_children():
				boite.remove_child(ch)
				ch.queue_free()
			var c := Causes.de(a, lieu)
			var cl := _label("Cause : " + String(c.cause), 12, UiStyle.ACCENT)
			cl.name = "TexteCause"
			boite.add_child(cl)
			for l in c.lignes:
				if String(l) != "":
					boite.add_child(_label("· " + String(l), 11, UiStyle.TEXT_DIM))
		boite.visible = bool(causes_ouvertes.get(id, false))
		if boite.visible:
			remplir.call()
		var q := Button.new()
		q.name = "Pourquoi"
		q.text = "?" if compact else "Pourquoi ?"
		q.tooltip_text = "Pourquoi ? Voir la cause du problème, avec les chiffres"
		q.focus_mode = Control.FOCUS_NONE
		q.toggle_mode = true
		q.button_pressed = boite.visible
		q.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if compact:
			q.custom_minimum_size = Vector2(26, 0)
		q.toggled.connect(func(on: bool) -> void:
			causes_ouvertes[id] = on
			if on:
				remplir.call()
			boite.visible = on)
		row.add_child(q)
	var pid := String(a.get("panneau", ""))
	if pid != "":
		var b := Button.new()
		b.name = "Regler"
		b.text = "Régler" if compact else "Régler ›"
		b.tooltip_text = "%s : ouvre ce qu'il faut pour régler le problème" % _verbe(pid)
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.add_theme_color_override("font_color", UiStyle.ACCENT)
		b.pressed.connect(func() -> void: ouvrir.call(pid))
		row.add_child(b)
	return card


static func _verbe(pid: String) -> String:
	if pid.begins_with("batiment:"):
		return "Construire"
	match pid:
		"budget": return "Ouvrir le budget"
		"construire": return "Construire"
		"reseaux": return "Voir les réseaux"
		"services": return "Voir les services"
		"trafic": return "Voir le trafic"
		"dechets": return "Voir les déchets"
		"avis": return "Voir les avis"
		"cartes": return "Voir la carte"
		"production": return "Voir l'économie"
		"non_raccorde": return "Y aller"
	return "Ouvrir"


func _tuile(t: Dictionary) -> Button:
	var l := Statistiques.PAYS if t.get("pays", false) else _lieu()
	var v := stats.dernier(l, String(t.ind)) if stats != null else NAN
	var b := Button.new()
	b.name = "Tuile_" + String(t.titre)
	b.custom_minimum_size = Vector2(190, 84)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", UiStyle.flat_box(Color(1, 1, 1, 0.06), 9, 8))
	b.add_theme_stylebox_override("hover", UiStyle.flat_box(Color(1, 1, 1, 0.12), 9, 8))
	b.add_theme_stylebox_override("pressed", UiStyle.flat_box(Color(1, 1, 1, 0.12), 9, 8))
	b.tooltip_text = "%s : ouvrir le détail" % t.titre
	var pid := String(t.panneau)
	b.pressed.connect(func() -> void:
		set_open(false)
		panneau_requested.emit(pid))
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 10
	box.offset_top = 8
	box.offset_right = -10
	box.offset_bottom = -8
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	b.add_child(box)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := TextureRect.new()
	ic.texture = Icones.get_icon(String(t.icone), 16, UiStyle.TEXT_DIM)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(ic)
	var tl := _label(String(t.titre), 12, UiStyle.TEXT_DIM, false)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(tl)
	box.add_child(h)
	var vl := _label(Statistiques.format(String(t.ind), v), 20, etat_couleur(String(t.ind), v), false)
	vl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(vl)
	var sous := String(t.sous)
	var txt := ""
	if sous != "":
		var sv := stats.dernier(l, sous) if stats != null else NAN
		if not is_nan(sv):
			txt = "%s : %s" % [String(Statistiques.indicateur(sous).get("nom", sous)), Statistiques.format(sous, sv)]
	elif stats != null:
		var ev := stats.evolution(l, String(t.ind), 7)
		if not is_nan(ev):
			txt = "%s en 7 jours" % Statistiques.format_ecart(String(t.ind), ev)
	var sl := _label(txt, 11, UiStyle.TEXT_DIM, false)
	sl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(sl)
	return b


## Vert, jaune ou rouge selon les seuils du Conseiller ; blanc si neutre.
static func etat_couleur(ind: String, v: float) -> Color:
	if is_nan(v):
		return UiStyle.TEXT_DIM
	var g := -1
	match ind:
		"caisse": g = 2 if v < 0.0 else 0
		"satisfaction": g = 2 if v < Conseiller.SATISFACTION_URGENT else (1 if v < Conseiller.SATISFACTION_ATTENTION else 0)
		"chomage": g = 2 if v >= Conseiller.CHOMAGE_URGENT else (1 if v >= Conseiller.CHOMAGE_ATTENTION else 0)
		"sans_ecole", "coupures", "dechets": g = 0 if v <= 0.0 else (2 if v > 50.0 else 1)
		"congestion": g = 2 if v >= Conseiller.BOUCHONS_URGENT else (1 if v >= Conseiller.BOUCHONS_ATTENTION else 0)
	return Color.WHITE if g < 0 else Conseiller.COULEURS[g]


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.physical_keycode == KEY and not k.shift_pressed and not k.ctrl_pressed and not k.alt_pressed:
		toggle()
		get_viewport().set_input_as_handled()
	elif k.keycode == KEY_ESCAPE and is_open():
		set_open(false)
		get_viewport().set_input_as_handled()
