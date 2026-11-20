class_name JaugesVille
extends PanelContainer
## Jauges toujours visibles (piste CityRT 10), sous la barre du haut, au centre :
##  - demande Logement / Commerce / Industrie / Bureaux (ZoneSystem.demand :
##    les bureaux poussent dans les zones commerciales) ;
##  - électricité, eau, égouts (Reseaux.bilan) et déchets (Dechets.bilan).
## Chaque jauge se lit d'un coup d'œil (barre + couleur). Un clic ouvre une
## fiche courte (production, demande, bâtiments coupés, installations) avec un
## bouton vers le panneau complet ; un second clic la referme. Mise à jour
## toutes les 1,5 s de temps réel (les bilans parcourent les bâtiments).

signal panneau_requested(id: String)

const PERIODE := 1.5
## Demande : [clé, lettre, nom, couleur]. Couleurs du zonage (BuildingPanel).
const DEMANDES := [["R", "L", "Logement", Color("5cb85c")], ["C", "C", "Commerce", Color("4a90d9")],
	["I", "I", "Industrie", Color("e0b13a")], ["B", "B", "Bureaux", Color("b48ad9")]]
## Services : [id, icône, nom, panneau].
const SERVICES := [["elec", "reseaux", "Électricité", "reseaux"], ["eau", "eau", "Eau potable", "reseaux"],
	["egout", "eau", "Égouts", "reseaux"], ["dechets", "dechets", "Déchets", "dechets"]]
const BON := Color("7fd68f")
const MOYEN := Color("f0c05a")
const MAUVAIS := Color("ef6b5e")

var zones: ZoneSystem
var reseaux: Reseaux
var dechets: Dechets

var _barres := {}
var _boutons := {}
var _fiche: PanelContainer
var _fiche_texte: Label
var _fiche_bouton: Button
var _fiche_id := ""
var _tick := PERIODE


func _init() -> void:
	name = "JaugesVille"
	UiStyle.style_panel(self, 0.8, 9, 4)
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	offset_top = 72.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	add_child(row)
	for d in DEMANDES:
		row.add_child(_jauge(String(d[0]), String(d[1]), "", d[3] as Color, "Demande %s" % String(d[2]).to_lower()))
	row.add_child(UiStyle.vsep())
	for s in SERVICES:
		row.add_child(_jauge(String(s[0]), "", String(s[1]), BON, String(s[2])))
	_fiche = PanelContainer.new()
	_fiche.name = "FicheJauge"
	UiStyle.style_panel(_fiche, 0.92, 9, 8)
	_fiche.visible = false
	_fiche.top_level = true
	var v := VBoxContainer.new()
	_fiche.add_child(v)
	_fiche_texte = Label.new()
	_fiche_texte.add_theme_font_size_override("font_size", 13)
	_fiche_texte.add_theme_color_override("font_color", UiStyle.TEXT)
	v.add_child(_fiche_texte)
	_fiche_bouton = Button.new()
	_fiche_bouton.pressed.connect(func() -> void:
		var cible := _panneau_de(_fiche_id)
		fermer_fiche()
		panneau_requested.emit(cible))
	v.add_child(_fiche_bouton)
	add_child(_fiche)


func setup(z: ZoneSystem, r: Reseaux, d: Dechets) -> void:
	zones = z
	reseaux = r
	dechets = d
	rafraichir()


func _jauge(id: String, lettre: String, icone: String, couleur: Color, aide: String) -> Control:
	var b := Button.new()
	b.name = "Jauge_" + id
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = aide + " (clic : fiche)"
	b.custom_minimum_size = Vector2(62, 26)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 3)
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	if icone != "":
		var t := TextureRect.new()
		t.texture = Icones.get_icon(icone, 16, UiStyle.TEXT)
		t.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		t.custom_minimum_size = Vector2(18, 0)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(t)
		if id == "egout":
			t.modulate = Color("a08a6a")
	else:
		var l := Label.new()
		l.text = lettre
		l.add_theme_font_size_override("font_size", 14)
		l.add_theme_color_override("font_color", couleur.lightened(0.25))
		l.custom_minimum_size = Vector2(14, 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(l)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.custom_minimum_size = Vector2(38, 9)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fond := StyleBoxFlat.new()
	fond.bg_color = Color(1, 1, 1, 0.12)
	fond.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", fond)
	var plein := StyleBoxFlat.new()
	plein.bg_color = couleur
	plein.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", plein)
	h.add_child(bar)
	_barres[id] = bar
	_boutons[id] = b
	b.pressed.connect(func() -> void: basculer_fiche(id))
	return b


func _process(delta: float) -> void:
	_tick += delta
	if _tick < PERIODE:
		return
	_tick = 0.0
	rafraichir()


## Valeurs des jauges : id -> {v (0-100), texte (fiche), couleur}.
func valeurs() -> Dictionary:
	var out := {}
	var d := zones.demand() if zones != null else {}
	for e in DEMANDES:
		var k := String(e[0])
		var dv := float(d.get(k, 0.0))
		var t := "Demande %s : %s" % [String(e[2]).to_lower(), "forte" if dv > 50.0 else ("faible" if dv > 0.0 else "aucune")]
		match k:
			"R":
				t += "\n%d logements environ manquent." % maxi(int(dv / ZoneSystem.PEOPLE_PER_HOME), 0) if dv > 0.0 else "\nAssez de logements pour les emplois actuels."
				t += "\nZone résidentielle (verte) pour en faire pousser."
			"C":
				t += "\n%d emplois de commerce attendus." % maxi(int(dv), 0) if dv > 0.0 else "\nAssez de commerces pour la population."
				t += "\nZone commerciale (bleue)."
			"I":
				t += "\n%d emplois d'industrie attendus." % maxi(int(dv), 0) if dv > 0.0 else "\nAssez d'industrie pour la population."
				t += "\nZone industrielle (jaune)."
			"B":
				t += "\n%d emplois de bureau attendus." % maxi(int(dv), 0) if dv > 0.0 else "\nAssez de bureaux pour la population."
				t += "\nLes bureaux poussent dans les zones commerciales."
		out[k] = {"v": 100.0 * ZoneSystem.jauge_demande(dv), "texte": t, "couleur": null}
	for s in SERVICES:
		var id := String(s[0])
		if id == "dechets":
			out[id] = _val_dechets()
		else:
			out[id] = _val_reseau(id, String(s[2]))
	return out


func _val_reseau(res: String, nom: String) -> Dictionary:
	if reseaux == null:
		return {"v": 0.0, "texte": nom + " : pas encore de réseau.", "couleur": MAUVAIS}
	var b := reseaux.bilan(res)
	var unite := "MW" if res == "elec" else "m³/j"
	var dem := float(b.get("demande", 0.0))
	var prod := float(b.get("production", 0.0))
	var servi := float(b.get("servi", 0.0))
	var taux := 100.0 if dem <= 0.0 else clampf(100.0 * servi / dem, 0.0, 100.0)
	var t := "%s : %d %% des besoins couverts" % [nom, roundi(taux)]
	t += "\nConsommation %s %s · capacité %s %s" % [Reseaux._fmt(dem), unite, Reseaux._fmt(prod), unite]
	t += "\nCharge du réseau : %d %%" % roundi(100.0 * dem / prod) if prod > 0.0 else "\nAucune installation raccordée."
	t += "\nBâtiments raccordés : %d" % int(b.get("batiments", 0))
	var sans := int(b.get("coupes", 0))
	if sans > 0:
		t += "\nSans approvisionnement : %d bâtiment%s" % [sans, "s" if sans > 1 else ""]
	if int(b.get("partiels", 0)) > 0:
		t += "\nServis en partie : %d" % int(b.partiels)
	var couleur := BON if taux >= 95.0 else (MOYEN if taux >= 70.0 else MAUVAIS)
	if dem <= 0.0 and prod <= 0.0:
		return {"v": 0.0, "texte": nom + " : rien à desservir pour l'instant.", "couleur": UiStyle.TEXT_DIM}
	return {"v": taux, "texte": t, "couleur": couleur}


func _val_dechets() -> Dictionary:
	if dechets == null:
		return {"v": 0.0, "texte": "Déchets : pas de collecte.", "couleur": MAUVAIS}
	var b := dechets.bilan()
	var prod := float(b.get("produit", 0.0))
	var coll := float(b.get("collecte", 0.0))
	var taux := 100.0 if prod <= 0.0 else clampf(100.0 * coll / prod, 0.0, 100.0)
	var t := "Déchets : %d %% collectés hier" % roundi(taux)
	t += "\nProduits %s t · collectés %s t" % [Reseaux._fmt(prod), Reseaux._fmt(coll)]
	t += "\nRecyclage : %d %%" % roundi(100.0 * float(b.get("taux_recyclage", 0.0)))
	var deb := int(b.get("debordent", 0))
	if deb > 0:
		t += "\nPoubelles qui débordent : %d" % deb
	var couleur := BON if taux >= 95.0 and deb == 0 else (MOYEN if taux >= 70.0 else MAUVAIS)
	if prod <= 0.0:
		return {"v": 0.0, "texte": "Déchets : rien à collecter pour l'instant.", "couleur": UiStyle.TEXT_DIM}
	return {"v": taux, "texte": t, "couleur": couleur}


func rafraichir() -> void:
	var vals := valeurs()
	for id in vals:
		var bar := _barres.get(id) as ProgressBar
		if bar == null:
			continue
		var e: Dictionary = vals[id]
		bar.value = float(e.v)
		if e.couleur != null:
			(bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = e.couleur
		var lignes := String(e.texte).split("\n")
		(_boutons[id] as Button).tooltip_text = lignes[0] + " (clic : fiche)"
	if _fiche.visible:
		_fiche_texte.text = String(vals.get(_fiche_id, {}).get("texte", ""))


func basculer_fiche(id: String) -> void:
	if _fiche.visible and _fiche_id == id:
		fermer_fiche()
		return
	_fiche_id = id
	var cible := _panneau_de(id)
	_fiche_bouton.text = {"reseaux": "Ouvrir les réseaux (O)", "dechets": "Ouvrir les déchets (X)", "construire": "Zoner (B)"}[cible]
	_fiche.visible = true
	rafraichir()
	_placer_fiche.call_deferred()


func _placer_fiche() -> void:
	var b := _boutons.get(_fiche_id) as Control
	if b == null or not _fiche.visible:
		return
	_fiche.reset_size()
	var r := b.get_global_rect()
	var vue := get_viewport_rect().size
	_fiche.global_position = Vector2(clampf(r.position.x, 8.0, vue.x - _fiche.size.x - 8.0), r.end.y + 6.0)


func fermer_fiche() -> void:
	_fiche.visible = false
	_fiche_id = ""


func fiche_ouverte() -> String:
	return _fiche_id if _fiche.visible else ""


static func _panneau_de(id: String) -> String:
	if id in ["R", "C", "I", "B"]:
		return "construire"
	return "dechets" if id == "dechets" else "reseaux"
