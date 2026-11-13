class_name TelecomVue
extends VBoxContainer
## Contenu du panneau Internet et téléphone (seul, ou en onglet du panneau Réseaux).

var tel: Telecom
var largeur := 324.0
## Bâtiment survolé (-1 : aucun), donné par la scène.
var survol_bid := -1
var _bilan: VBoxContainer
var _survol: Label
var _outils: Array = []
var _calques: Array = []
var _tick := 0.0

const OUTILS := [
	["Fibrer une rue", Telecom.Outil.FIBRE_RUE, "route"],
	["Fibre sous la rue (tracé libre)", Telecom.Outil.FIBRE, "chemin"],
	["Fibre sur poteaux", Telecom.Outil.FIBRE_AERIENNE, "lignes"],
	["Téléphone sur poteaux (cuivre)", Telecom.Outil.CUIVRE_AERIEN, "lignes"],
	["Retirer un câble", Telecom.Outil.RETIRER, "demolir"],
]
const CALQUES := [["Aucun calque", ""], ["Couverture mobile", "mobile"], ["Débit internet", "debit"]]


func setup(t: Telecom, w := 324.0) -> void:
	tel = t
	largeur = w
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 4)
	_titre("Bilan")
	_bilan = VBoxContainer.new()
	add_child(_bilan)
	_titre("Bâtiment survolé")
	_survol = _texte("Survole un bâtiment.", true)
	_titre("Équipements")
	_texte("Antennes relais (2G, 4G, 5G), centraux téléphoniques et nœuds de la fibre : panneau Construire (B), catégorie Services publics.", true)
	_titre("Câbles")
	for o in OUTILS:
		var b := Button.new()
		b.text = o[0]
		b.icon = Icones.get_icon(o[2], 18)
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var outil: int = o[1]
		b.pressed.connect(func() -> void: _choisir(outil))
		add_child(b)
		_outils.append([b, outil])
	_texte("Le cuivre suit toutes les routes reliées à un central : les poteaux servent aux fermes et hameaux loin des routes. La fibre ne va que là où tu la poses.", true)
	_titre("Calque")
	var row := HBoxContainer.new()
	add_child(row)
	for c in CALQUES:
		var b := Button.new()
		b.text = c[0]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 12)
		var id: String = c[1]
		b.pressed.connect(func() -> void:
			tel.set_calque(id)
			_maj_boutons())
		row.add_child(b)
		_calques.append([b, id])
	_legende()
	tel.changed.connect(func() -> void:
		if is_visible_in_tree():
			refresh())
	_maj_boutons()
	refresh()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_tick += delta
	if _tick > 0.3:
		_tick = 0.0
		_survol.text = "Survole un bâtiment." if survol_bid < 0 else _nom(survol_bid) + " : " + tel.info_of(survol_bid)
	if tel.outil == Telecom.Outil.AUCUN:
		for o in _outils:
			if (o[0] as Button).button_pressed:
				_maj_boutons()
				break


func _nom(bid: int) -> String:
	var b: Dictionary = tel.buildings.buildings.get(bid, {}) if tel.buildings != null else {}
	return String(BuildingCatalog.get_type(String(b.get("t", ""))).get("name", "Bâtiment"))


func _choisir(o: int) -> void:
	tel.set_outil(Telecom.Outil.AUCUN if tel.outil == o else o)
	_maj_boutons()


func _maj_boutons() -> void:
	for o in _outils:
		(o[0] as Button).set_pressed_no_signal(tel.outil == o[1])
	for c in _calques:
		(c[0] as Button).set_pressed_no_signal(tel.calque == c[1])


## Le panneau se ferme : outil rangé, calque masqué.
func rangement() -> void:
	tel.set_outil(Telecom.Outil.AUCUN)
	tel.set_calque("")
	_maj_boutons()


func refresh() -> void:
	if _bilan == null:
		return
	for c in _bilan.get_children():
		_bilan.remove_child(c)
		c.queue_free()
	var b := tel.bilan()
	var n := int(b.batiments)
	if n == 0:
		_texte("Aucun bâtiment n'a encore besoin du réseau.", true, _bilan)
	else:
		_texte("%d bâtiments à desservir :" % n, false, _bilan)
		for k in [["fibre", "fibre optique"], ["adsl", "ADSL rapide"], ["mobile", "box 4G / 5G"], ["lent", "internet lent"], ["rien", "sans internet"]]:
			if int(b[k[0]]) > 0:
				_ligne(Telecom.COULEURS_NET[k[0]], "%d %s (%d %%)" % [int(b[k[0]]), k[1], roundi(100.0 * int(b[k[0]]) / n)])
		_texte("Réseau mobile : %d %% des bâtiments couverts (5G %d, 4G %d, 2G %d)." % [
			roundi(100.0 * int(b.couverts) / n), int(b.gen["5g"]), int(b.gen["4g"]), int(b.gen["2g"])], false, _bilan)
	if int(b.satures) > 0:
		_texte("⚠ %d émetteur%s saturé%s : ajoute une antenne à côté." % [int(b.satures), "s" if int(b.satures) > 1 else "", "s" if int(b.satures) > 1 else ""], false, _bilan)
	_texte("%d antenne%s, %d central%s ou nœud%s optique%s, %s de fibre, %s de lignes sur poteaux." % [
		int(b.antennes), "s" if int(b.antennes) > 1 else "", int(b.centraux), "aux" if int(b.centraux) > 1 else "",
		"s" if int(b.centraux) > 1 else "", "s" if int(b.centraux) > 1 else "",
		Telecom._km(float(b.fibre_m)), Telecom._km(float(b.poteaux_m))], true, _bilan)
	var ent := tel.budget_entretien()
	var rec := tel.budget_recettes()
	var e := 0
	for k in ent:
		e += int(ent[k])
	var r := 0
	for k in rec:
		r += int(rec[k])
	_texte("Par mois : entretien %s, abonnements %s (budget de la ville)." % [BuildingSystem.format_money(e), BuildingSystem.format_money(r)], true, _bilan)
	if not Telecom.necessaire():
		_texte("Réglage Admin (F10) : internet et téléphone ne comptent pas dans cette partie.", true, _bilan)


func _legende() -> void:
	var g := GridContainer.new()
	g.columns = 2
	add_child(g)
	for k in [["fibre", "Fibre"], ["adsl", "ADSL rapide"], ["mobile", "Box 4G / 5G"], ["lent", "Lent"], ["rien", "Rien"]]:
		var h := HBoxContainer.new()
		var sw := ColorRect.new()
		sw.color = Telecom.COULEURS_NET[k[0]]
		sw.custom_minimum_size = Vector2(12, 12)
		h.add_child(sw)
		var l := Label.new()
		l.text = k[1]
		l.add_theme_font_size_override("font_size", 12)
		h.add_child(l)
		g.add_child(h)
	for gen in TelecomTypes.GENS:
		var h := HBoxContainer.new()
		var sw := ColorRect.new()
		sw.color = TelecomTypes.GENS[gen].color
		sw.custom_minimum_size = Vector2(12, 12)
		h.add_child(sw)
		var l := Label.new()
		l.text = "Couverture " + String(TelecomTypes.GENS[gen].name)
		l.add_theme_font_size_override("font_size", 12)
		h.add_child(l)
		g.add_child(h)


func _titre(t: String) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", UiStyle.ACCENT)
	add_child(l)


func _texte(t: String, dim := false, parent: Control = null) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(largeur, 0)
	l.add_theme_font_size_override("font_size", 13)
	if dim:
		l.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
	(parent if parent != null else self).add_child(l)
	return l


func _ligne(col: Color, t: String) -> void:
	var h := HBoxContainer.new()
	var sw := ColorRect.new()
	sw.color = col
	sw.custom_minimum_size = Vector2(12, 12)
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(sw)
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 13)
	h.add_child(l)
	_bilan.add_child(h)
