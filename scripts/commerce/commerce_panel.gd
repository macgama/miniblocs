class_name CommercePanel
extends CanvasLayer
## Menu « Commerce » (barre du bas → Économie, ou Maj+S) :
## - Marché : cours mondiaux du jour, famille par famille, avec leur courbe ;
##   un clic sur une marchandise montre ses 120 derniers jours.
## - Offres : ce que proposent les villes partenaires (vraies villes voisines),
##   à signer pour la ville choisie ; relations et missions commerciales.
## - Accords : accords en cours (livré aujourd'hui, retards, pénalités), rupture.
## - Entre villes : accords entre tes villes (ou avec un ami), libre-échange entre pays.
## - Crises : la crise en cours, ses effets et quoi faire ; les crises passées.
## - Bilan : commerce de chaque ville et de chaque pays.

const W := 420.0
const H := 560.0
const TABS := [["Marché mondial", "marche", "courbe"], ["Offres des villes partenaires", "offres", "pancarte"],
	["Accords en cours", "accords", "billet"], ["Entre tes villes et pays", "villes", "village"],
	["Crises économiques", "crises", "tempete"], ["Bilan du commerce", "bilan", "budget"]]
const ROUGE := Color("ff8a80")

var cm: CommerceMondial
var pays: Pays
var view := "marche"
var detail := ""
var ville := -1
var _panel: PanelContainer
var _body: VBoxContainer
var _scroll: ScrollContainer
var _title: Label
var _tab_buttons := {}
var _tick := 0.0
## Formulaire « Entre villes ».
var _f := {"vendeur": -1, "acheteur": -1, "g": "", "t": 10.0, "prix": -1.0, "duree": 60}


## Petite courbe d'un cours (facteurs), avec la ligne du prix de référence.
class CourbeCours extends Control:
	var vals: Array = []
	var couleur := Color.WHITE

	func _draw() -> void:
		if vals.size() < 2:
			return
		var lo := 1.0
		var hi := 1.0
		for v in vals:
			lo = minf(lo, float(v))
			hi = maxf(hi, float(v))
		var pad := maxf((hi - lo) * 0.1, 0.02)
		lo -= pad
		hi += pad
		var w := size.x
		var h := size.y
		var y1 := h - (1.0 - lo) / (hi - lo) * h
		draw_dashed_line(Vector2(0, y1), Vector2(w, y1), Color(1, 1, 1, 0.25), 1.0, 3.0)
		var pts := PackedVector2Array()
		for i in vals.size():
			pts.append(Vector2(w * float(i) / float(vals.size() - 1), h - (float(vals[i]) - lo) / (hi - lo) * h))
		draw_polyline(pts, couleur, 1.5, true)


func setup(c: CommerceMondial, p: Pays) -> void:
	cm = c
	pays = p
	_build()
	if cm != null:
		cm.changed.connect(func() -> void:
			if is_open():
				_refresh_keep())


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
	icon.texture = Icones.get_icon("commerce", 22, UiStyle.ACCENT)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(icon)
	_title = Label.new()
	_title.text = "Commerce"
	_title.add_theme_font_size_override("font_size", 16)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	var x := UiStyle.icon_button("fermer", "Fermer", "Maj+S", 18, 32)
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
	return _panel != null and _panel.visible


func set_open(on: bool) -> void:
	_panel.visible = on
	if on:
		refresh()


func toggle() -> void:
	set_open(not _panel.visible)


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.physical_keycode == KEY_S and k.shift_pressed and not k.ctrl_pressed and not k.alt_pressed:
		toggle()
		get_viewport().set_input_as_handled()


func show_view(v: String) -> void:
	view = v
	detail = ""
	refresh()
	_scroll.scroll_vertical = 0


func _process(delta: float) -> void:
	if not is_open():
		return
	_tick += delta
	if _tick >= 4.0 and view in ["accords", "bilan"]:
		_tick = 0.0
		_refresh_keep()


func _refresh_keep() -> void:
	var f := get_viewport().gui_get_focus_owner()
	if f != null and _body.is_ancestor_of(f):
		return
	var keep := _scroll.scroll_vertical
	refresh()
	_scroll.set_deferred("scroll_vertical", keep)


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


func _ligne(label: String, valeur: String, col := Color(0, 0, 0, 0)) -> void:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(200, 0)
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	row.add_child(l)
	var v := Label.new()
	v.text = valeur
	v.add_theme_font_size_override("font_size", 12)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if col.a > 0.0:
		v.add_theme_color_override("font_color", col)
	row.add_child(v)
	_body.add_child(row)


static func _euros(x: float) -> String:
	return BuildingSystem.format_money(roundi(x))


static func _pct(x: float) -> String:
	return ("%+d %%" % roundi(x * 100.0)).replace("+0 %", "0 %")


static func _col_var(x: float) -> Color:
	if x > 0.02:
		return UiStyle.GOOD
	if x < -0.02:
		return ROUGE
	return UiStyle.TEXT_DIM


func _courbe(vals: Array, taille: Vector2, col: Color, parent: Control = null) -> CourbeCours:
	var c := CourbeCours.new()
	c.vals = vals
	c.couleur = col
	c.custom_minimum_size = taille
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else _body).add_child(c)
	return c


## Villes que le joueur dirige (clé Pays.PAYS sans ville).
func _mes_villes() -> Array:
	var out: Array = []
	if pays != null and pays.a_des_villes():
		for vid in pays.communes.villages:
			if Multijoueur.peut_decider(int(vid)):
				out.append(int(vid))
	else:
		out.append(Pays.PAYS)
	return out


func _toutes_villes() -> Array:
	if pays != null and pays.a_des_villes():
		return pays.communes.villages.keys()
	return [Pays.PAYS]


func _nom(k: int) -> String:
	return cm._nom_ville(k)


## La ville pour qui on signe : la ville gérée (Maj+P), sinon la première.
func _ville_choisie() -> int:
	var mes := _mes_villes()
	if ville in mes:
		return ville
	if pays != null and pays.selection in mes:
		ville = pays.selection
	elif not mes.is_empty():
		ville = int(mes[0])
	return ville


func _choix_ville(texte: String) -> void:
	var mes := _mes_villes()
	if mes.size() <= 1:
		if not mes.is_empty():
			_label("%s : %s" % [texte, _nom(int(mes[0]))], 12, true)
		return
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = texte
	l.add_theme_font_size_override("font_size", 12)
	row.add_child(l)
	var o := OptionButton.new()
	o.focus_mode = Control.FOCUS_NONE
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cur := _ville_choisie()
	for i in mes.size():
		o.add_item(_nom(int(mes[i])), i)
		if int(mes[i]) == cur:
			o.select(i)
	o.item_selected.connect(func(i: int) -> void:
		ville = int(mes[i])
		refresh())
	row.add_child(o)
	_body.add_child(row)


## Décision : part au serveur sur une carte entre amis, sinon faite ici.
func _appel(f: String, args: Array, k: int) -> void:
	if Multijoueur.relayer("commerce", f, args, {"ville": k}):
		return
	cm.callv(f, args)
	refresh()


func refresh() -> void:
	if cm == null:
		return
	if cm.jour < 0 and cm.production != null and cm.production.last_day >= 0:
		cm._initialiser(cm.production.last_day)
	for v in _tab_buttons:
		(_tab_buttons[v] as Button).set_pressed_no_signal(v == view)
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	_title.text = "Commerce" + ("  ·  " + cm.nom_crise() if cm.nom_crise() != "" else "")
	if detail != "":
		_vue_detail(detail)
		return
	match view:
		"marche": _vue_marche()
		"offres": _vue_offres()
		"accords": _vue_accords()
		"villes": _vue_villes()
		"crises": _vue_crises()
		"bilan": _vue_bilan()


func _bandeau_crise() -> void:
	if cm.crise.is_empty():
		return
	var c: Dictionary = MarcheTypes.CRISES[String(cm.crise.id)]
	var l := _label("⚠ %s : encore %d jours (intensité %d %%)" % [c.nom, cm.jours_crise_restants(), roundi(cm.intensite_crise() * 100.0)], 13)
	l.add_theme_color_override("font_color", ROUGE)


# --- Marché -----------------------------------------------------------------------------------

func _vue_marche() -> void:
	_bandeau_crise()
	_label("Cours du jour sur le marché mondial (€ la tonne) et variation sur 30 jours. Tes exportations et importations se font à ce prix ; sur la carte, les prix suivent le cours à moitié. Clic : la courbe sur 120 jours.", 11, true)
	var produits := cm.biens_produits()
	for f in MarcheTypes.FAMILLES:
		_titre(String(MarcheTypes.FAMILLES[f].nom))
		for g in MarcheTypes.FAMILLES[f].biens:
			if not Ressources.MARCHANDISES.has(g):
				continue
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			var b := Button.new()
			b.text = Ressources.good_name(g) + ("  ●" if g in produits else "")
			b.tooltip_text = "%s\nPrix de référence : %s/t\n● : tes entreprises en produisent" % [Ressources.good_name(g), _euros(Ressources.price(g))]
			b.flat = true
			b.focus_mode = Control.FOCUS_NONE
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.clip_text = true
			b.custom_minimum_size = Vector2(170, 0)
			b.add_theme_font_size_override("font_size", 12)
			var gg: String = g
			b.pressed.connect(func() -> void:
				detail = gg
				refresh())
			row.add_child(b)
			var p := Label.new()
			p.text = _euros(Ressources.cours(g))
			p.custom_minimum_size = Vector2(80, 0)
			p.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			p.add_theme_font_size_override("font_size", 12)
			row.add_child(p)
			var var30 := cm.variation(g)
			var v := Label.new()
			v.text = _pct(var30)
			v.custom_minimum_size = Vector2(50, 0)
			v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			v.add_theme_font_size_override("font_size", 12)
			v.add_theme_color_override("font_color", _col_var(var30))
			row.add_child(v)
			var h: Array = cm.historique.get(g, [])
			_courbe(h.slice(maxi(0, h.size() - 30)), Vector2(70, 18), _col_var(var30), row)
			_body.add_child(row)


func _vue_detail(g: String) -> void:
	_bouton("Retour au marché", "precedent", "", func() -> void:
		detail = ""
		refresh())
	var l := _label(Ressources.good_name(g), 16)
	l.add_theme_color_override("font_color", UiStyle.ACCENT)
	var h: Array = cm.historique.get(g, [])
	_courbe(h, Vector2(W - 40, 120), UiStyle.ACCENT)
	_label("Pointillés : prix de référence. %d jours affichés." % h.size(), 11, true)
	_ligne("Cours du jour", "%s/t (×%.2f)" % [_euros(Ressources.cours(g)), cm.facteur(g)])
	_ligne("Prix de référence", "%s/t" % _euros(Ressources.price(g)))
	_ligne("Sur 7 jours / 30 jours", "%s / %s" % [_pct(cm.variation(g, 7)), _pct(cm.variation(g, 30))], _col_var(cm.variation(g, 30)))
	_ligne("Ce que touche un exportateur", "%s/t" % _euros(Ressources.prix_export(g)))
	_ligne("Ce que paie un importateur", "%s/t" % _euros(Ressources.prix_import(g)))
	_ligne("Entre entreprises de la carte", "%s/t" % _euros(Ressources.prix_interieur(g)))
	if not cm.crise.is_empty() and absf(cm.facteur_crise(g) - 1.0) > 0.01:
		_ligne("Effet de la crise", "×%.2f (%s)" % [cm.facteur_crise(g), cm.nom_crise()], ROUGE)
	_ligne("Famille", String(MarcheTypes.FAMILLES.get(MarcheTypes.famille_de(g), {}).get("nom", "")))
	var acc: Array = []
	for aid in cm.accords:
		if String(cm.accords[aid].g) == g:
			acc.append(cm.accords[aid])
	if not acc.is_empty():
		_titre("Tes accords sur cette marchandise")
		for a in acc:
			_label("• " + _texte_accord(a), 12)


# --- Offres -----------------------------------------------------------------------------------

func _vue_offres() -> void:
	_bandeau_crise()
	_choix_ville("Signer pour")
	var k := _ville_choisie()
	if cm.offres.is_empty():
		_label("Aucune offre pour l'instant : les villes partenaires en font de temps en temps. Une mission commerciale en fait venir tout de suite.", 12, true)
	else:
		_titre("Offres (%d)" % cm.offres.size())
		for o in cm.offres:
			_carte_offre(o, k)
	_titre("Villes partenaires")
	for pid in cm.partenaires:
		var p: Dictionary = cm.partenaires[pid]
		var row := HBoxContainer.new()
		var t := Label.new()
		t.text = "%s · %s hab. · %d km\nRelation : %s (%d / 100)" % [cm.nom_partenaire(int(pid)), BuildingSystem.format_money(int(p.pop)).replace(" €", ""),
			roundi(float(p.km)), cm.relation_texte(float(p.relation)), roundi(float(p.relation))]
		t.add_theme_font_size_override("font_size", 12)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var achete: Array = []
		for g in p.achete:
			achete.append(Ressources.good_name(String(g)).to_lower())
		var vend: Array = []
		for g in p.vend:
			vend.append(Ressources.good_name(String(g)).to_lower())
		t.tooltip_text = "Achète surtout : %s\nVend surtout : %s" % [", ".join(achete), ", ".join(vend)]
		t.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(t)
		var ip: int = pid
		var b := _bouton("Mission", "megaphone", "Mission commerciale : %s, relation +%d et deux offres tout de suite" % [
			_euros(ReglagesPartie.prix(MarcheTypes.MISSION_COUT)), roundi(MarcheTypes.MISSION_RELATION)],
			func() -> void: _appel("mission_commerciale", [ip, k], k), row)
		b.disabled = cm.jour - int(p.mission) < MarcheTypes.MISSION_ATTENTE
		_body.add_child(row)
		_body.add_child(HSeparator.new())


func _carte_offre(o: Dictionary, k: int) -> void:
	var box := VBoxContainer.new()
	var export := String(o.sens) == "export"
	var g := String(o.g)
	var t := Label.new()
	t.text = "%s %s %s par jour de %s" % [cm.nom_partenaire(int(o.partenaire)), "t'achète" if export else "te vend", Ressources.format_t(float(o.t)), Ressources.good_name(g).to_lower()]
	t.add_theme_font_size_override("font_size", 13)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(W - 40, 0)
	box.add_child(t)
	var ref := Ressources.prix_export(g) if export else Ressources.prix_import(g)
	var ecart := float(o.prix) / maxf(ref, 0.01) - 1.0
	var d := Label.new()
	d.text = "%s/t (%s par rapport au cours) · %d jours · environ %s par mois · expire dans %d j" % [_euros(float(o.prix)), _pct(ecart), int(o.duree),
		_euros(float(o.t) * float(o.prix) * 30.0), maxi(0, int(o.expire) - cm.jour)]
	d.add_theme_font_size_override("font_size", 11)
	d.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(W - 40, 0)
	box.add_child(d)
	if export and not g in cm.biens_produits():
		var w := Label.new()
		w.text = "Aucune de tes entreprises n'en produit : sans production, tu paieras des pénalités."
		w.add_theme_font_size_override("font_size", 11)
		w.add_theme_color_override("font_color", ROUGE)
		w.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		w.custom_minimum_size = Vector2(W - 40, 0)
		box.add_child(w)
	var row := HBoxContainer.new()
	var oo := o.duplicate()
	_bouton("Signer pour %s" % _nom(k), "billet", "Exportation : tes camions portent la marchandise à la frontière en priorité ; il faut en produire. Importation : prix fixe et passage garanti.",
		func() -> void: _appel("signer", [oo, k], k), row)
	box.add_child(row)
	_body.add_child(box)
	_body.add_child(HSeparator.new())


# --- Accords ----------------------------------------------------------------------------------

func _texte_accord(a: Dictionary) -> String:
	var g := Ressources.good_name(String(a.g)).to_lower()
	if String(a.genre) == "ia":
		var quoi := "vend à" if String(a.sens) == "export" else "achète à"
		return "%s %s %s %s/jour de %s à %s/t" % [_nom(int(a.ville)), quoi, cm.nom_partenaire(int(a.partenaire)), Ressources.format_t(float(a.t)), g, _euros(float(a.prix))]
	return "%s fournit à %s %s/jour de %s à %s/t" % [_nom(int(a.vendeur)), _nom(int(a.acheteur)), Ressources.format_t(float(a.t)), g, _euros(float(a.prix))]


func _vue_accords() -> void:
	_bandeau_crise()
	if cm.accords.is_empty():
		_label("Aucun accord en cours. Onglet Offres : ce que proposent les villes partenaires ; onglet Entre villes : accords entre tes villes.", 12, true)
	for aid in cm.accords:
		var a: Dictionary = cm.accords[aid]
		var l := _label(_texte_accord(a), 13)
		l.add_theme_color_override("font_color", UiStyle.ACCENT)
		var reste := maxi(0, int(a.fin) - cm.jour)
		_ligne("Aujourd'hui", "%s sur %s" % [Ressources.format_t(float(a.jour_t)), Ressources.format_t(float(a.t))])
		_ligne("Échangé depuis le début", "%s pour %s" % [Ressources.format_t(float(a.livre)), _euros(float(a.valeur))])
		if float(a.penalites) > 0.0:
			_ligne("Manques et pénalités", "%s manquées, %s payées" % [Ressources.format_t(float(a.manque)), _euros(float(a.penalites))], ROUGE)
		_ligne("Fin", "dans %d jours" % reste)
		var k := int(a.get("ville", a.get("vendeur", 0)))
		if String(a.genre) == "villes" and not Multijoueur.peut_decider(k):
			k = int(a.acheteur)
		if Multijoueur.peut_decider(k):
			var pen := float(reste) * float(a.t) * float(a.prix) * MarcheTypes.PENALITE_RUPTURE
			var id := int(aid)
			var kk := k
			_bouton("Rompre (pénalité %s)" % _euros(pen), "fermer", "Rompre l'accord avant la fin coûte 10 % de ce qui restait à échanger et fâche le partenaire.",
				func() -> void: _appel("resilier", [id, kk], kk))
		_body.add_child(HSeparator.new())
	if not cm.archives.is_empty():
		_titre("Accords terminés")
		for a in cm.archives.slice(0, 10):
			_label("• %s : %s, %s échangées pour %s%s" % ["Rompu" if String(a.get("etat", "")) == "rompu" else "Terminé", _texte_accord(a),
				Ressources.format_t(float(a.livre)), _euros(float(a.valeur)), (", pénalités %s" % _euros(float(a.penalites))) if float(a.penalites) > 0.0 else ""], 11, true)


# --- Entre villes et pays ---------------------------------------------------------------------

func _option(items: Array, noms: Array, cur: Variant, cb: Callable) -> OptionButton:
	var o := OptionButton.new()
	o.focus_mode = Control.FOCUS_NONE
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in items.size():
		o.add_item(String(noms[i]), i)
		if items[i] == cur:
			o.select(i)
	o.item_selected.connect(func(i: int) -> void: cb.call(items[i]))
	return o


func _champ(texte: String, c: Control) -> void:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = texte
	l.custom_minimum_size = Vector2(120, 0)
	l.add_theme_font_size_override("font_size", 12)
	row.add_child(l)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(c)
	_body.add_child(row)


func _vue_villes() -> void:
	var toutes := _toutes_villes()
	var mes := _mes_villes()
	# Propositions reçues (carte entre amis).
	var recues: Array = cm.propositions.filter(func(p: Dictionary) -> bool: return int(p.pour) in mes)
	if not recues.is_empty():
		_titre("Propositions reçues")
		for p in recues:
			_label("%s propose : %s fournit à %s %s/jour de %s à %s/t pendant %d jours" % [_nom(int(p.auteur)), _nom(int(p.vendeur)), _nom(int(p.acheteur)),
				Ressources.format_t(float(p.t)), Ressources.good_name(String(p.g)).to_lower(), _euros(float(p.prix)), int(p.duree)], 12)
			var row := HBoxContainer.new()
			var id := String(p.id)
			var k := int(p.pour)
			_bouton("Accepter", "billet", "", func() -> void: _appel("accepter", [id], k), row)
			_bouton("Refuser", "fermer", "", func() -> void: _appel("refuser", [id], k), row)
			_body.add_child(row)
	_titre("Nouvel accord entre villes")
	if toutes.size() < 2:
		_label("Il faut au moins deux villes (Maison de commune, Maj+M) pour qu'elles commercent entre elles.", 12, true)
	else:
		_label("La ville qui achète se fournit d'abord chez celle qui vend, au prix convenu. Si la ville qui vend ne livre pas, elle paie une pénalité à l'autre.", 11, true)
		if not int(_f.vendeur) in toutes:
			_f.vendeur = int(mes[0]) if not mes.is_empty() else int(toutes[0])
		if not int(_f.acheteur) in toutes or int(_f.acheteur) == int(_f.vendeur):
			for v in toutes:
				if int(v) != int(_f.vendeur):
					_f.acheteur = int(v)
					break
		var noms: Array = toutes.map(func(v: Variant) -> String: return _nom(int(v)))
		_champ("Ville qui vend", _option(toutes, noms, int(_f.vendeur), func(v: Variant) -> void:
			_f.vendeur = int(v)
			refresh()))
		_champ("Ville qui achète", _option(toutes, noms, int(_f.acheteur), func(v: Variant) -> void:
			_f.acheteur = int(v)
			refresh()))
		var biens := MarcheTypes.biens()
		if String(_f.g) == "":
			var pr := cm.biens_produits()
			_f.g = String(pr[0]) if not pr.is_empty() else String(biens[0])
		var gn: Array = biens.map(func(g: Variant) -> String: return Ressources.good_name(String(g)))
		_champ("Marchandise", _option(biens, gn, String(_f.g), func(g: Variant) -> void:
			_f.g = String(g)
			_f.prix = -1.0
			refresh()))
		var t := SpinBox.new()
		t.min_value = 0.1
		t.max_value = 2000.0
		t.step = 0.1
		t.value = float(_f.t)
		t.suffix = "t/jour"
		t.value_changed.connect(func(v: float) -> void: _f.t = v)
		_champ("Quantité", t)
		if float(_f.prix) < 0.0:
			_f.prix = snappedf(Ressources.prix_interieur(String(_f.g)), 0.01)
		var p := SpinBox.new()
		p.min_value = 0.0
		p.max_value = 1_000_000.0
		p.step = 0.5
		p.value = float(_f.prix)
		p.suffix = "€/t"
		p.value_changed.connect(func(v: float) -> void: _f.prix = v)
		_champ("Prix", p)
		_champ("Durée", _option(MarcheTypes.DUREES, MarcheTypes.DUREES.map(func(d: Variant) -> String: return "%d jours" % int(d)), int(_f.duree),
			func(d: Variant) -> void: _f.duree = int(d)))
		_label("Prix du jour entre entreprises : %s/t" % _euros(Ressources.prix_interieur(String(_f.g))), 11, true)
		var vend := int(_f.vendeur)
		var ach := int(_f.acheteur)
		var immediat := Multijoueur.peut_decider(vend) and Multijoueur.peut_decider(ach)
		var auteur := vend if Multijoueur.peut_decider(vend) else ach
		var b := _bouton("Signer l'accord" if immediat else "Proposer au maire de %s" % _nom(ach if auteur == vend else vend), "billet", "", func() -> void:
			_appel("proposer", [vend, ach, String(_f.g), float(_f.t), float(_f.prix), int(_f.duree), auteur, immediat], auteur))
		b.disabled = not (Multijoueur.peut_decider(vend) or Multijoueur.peut_decider(ach))
	# Libre-échange entre pays.
	if pays != null and pays.plusieurs_nations():
		_titre("Libre-échange entre tes pays")
		_label("Deux pays en libre-échange ne se font plus payer de douane (%s par défaut, réglable dans Maj+P)." % _pct(Pays.TAUX_DOUANE), 11, true)
		var ns: Array = pays.cles_nations()
		for i in ns.size():
			for j in range(i + 1, ns.size()):
				var na := int(ns[i])
				var nb := int(ns[j])
				var c := CheckBox.new()
				c.text = "%s ⇄ %s" % [pays.nom_nation(na), pays.nom_nation(nb)]
				c.focus_mode = Control.FOCUS_NONE
				c.button_pressed = cm.libre_echange_entre(na, nb)
				c.disabled = not Multijoueur.peut_decider(na)
				c.toggled.connect(func(on: bool) -> void: _appel("set_libre_echange", [na, nb, on], na))
				_body.add_child(c)


# --- Crises -----------------------------------------------------------------------------------

func _vue_crises() -> void:
	if cm.crise.is_empty():
		_label("Pas de crise en ce moment : les marchés sont calmes.%s" % ("" if ReglagesPartie.actuel.crises_economiques else " (Crises désactivées dans le panneau Admin, F10.)"), 13)
	else:
		var c: Dictionary = MarcheTypes.CRISES[String(cm.crise.id)]
		var l := _label(String(c.nom), 16)
		l.add_theme_color_override("font_color", ROUGE)
		_label(String(c.texte), 12)
		_ligne("Depuis", "%d jours" % (cm.jour - int(cm.crise.debut)))
		_ligne("Encore", "%d jours environ" % cm.jours_crise_restants())
		_ligne("Intensité", "%d %%" % roundi(cm.intensite_crise() * 100.0))
		_titre("Effets aujourd'hui")
		var effets: Array = []
		for g in MarcheTypes.biens():
			var f := cm.facteur_crise(g)
			if absf(f - 1.0) > 0.02:
				effets.append([f, g])
		effets.sort_custom(func(a: Array, b: Array) -> bool: return absf(float(a[0]) - 1.0) > absf(float(b[0]) - 1.0))
		for e in effets.slice(0, 12):
			_ligne(Ressources.good_name(String(e[1])), "×%.2f" % float(e[0]), _col_var(float(e[0]) - 1.0))
		if effets.size() > 12:
			_label("… et %d autres marchandises." % (effets.size() - 12), 11, true)
		if absf(Ressources.facteur_export - 1.0) > 0.01:
			_ligne("Prix payé à l'export", "×%.2f" % Ressources.facteur_export, _col_var(Ressources.facteur_export - 1.0))
		if absf(Ressources.facteur_import - 1.0) > 0.01:
			_ligne("Prix des importations", "×%.2f" % Ressources.facteur_import, _col_var(1.0 - Ressources.facteur_import))
		if absf(Ressources.facteur_capacite - 1.0) > 0.01:
			_ligne("Camions aux frontières", "×%.2f" % Ressources.facteur_capacite, _col_var(Ressources.facteur_capacite - 1.0))
		_titre("Que faire ?")
		_label(String(c.conseil), 12)
	if not cm.crises_passees.is_empty():
		_titre("Crises passées")
		for x in cm.crises_passees:
			_label("• %s : %d jours, il y a %d jours" % [String(MarcheTypes.CRISES.get(String(x.id), {}).get("nom", "?")), int(x.duree),
				cm.jour - int(x.debut) - int(x.duree)], 12, true)


# --- Bilan ------------------------------------------------------------------------------------

func _vue_bilan() -> void:
	var prod := cm.production
	_titre("Échanges avec le reste du monde (ce mois)")
	if prod != null:
		var m: Dictionary = prod.ledger.get("mois", {})
		_ligne("Exportations", _euros(float(m.get("Exportations", 0.0))))
		_ligne("Importations", _euros(-float(m.get("Importations", 0.0))))
		_ligne("Douane payée entre tes pays", _euros(-float(m.get("Douane", 0.0))))
	_titre("Par ville (mois dernier)")
	for k in _toutes_villes():
		var b := cm.bilan_ville(int(k))
		var cv: Dictionary = prod.commerce_ville(int(k)) if prod != null else {"ventes": 0.0, "achats": 0.0}
		_label(_nom(int(k)), 13)
		_ligne("  Ventes / achats aux autres villes", "%s / %s" % [_euros(float(cv.ventes)), _euros(float(cv.achats))])
		_ligne("  Accords : export / import", "%s / %s" % [_euros(float(b.export)), _euros(float(b.import))])
		if float(b.villes) > 0.0:
			_ligne("  Accords entre villes (ventes)", _euros(float(b.villes)))
		if float(b.penalites) > 0.0:
			_ligne("  Pénalités", _euros(float(b.penalites)), ROUGE)
		var n := cm.accords_de(int(k)).size()
		if n > 0:
			_ligne("  Accords en cours", "%d" % n)
	if pays != null and pays.plusieurs_nations() and prod != null:
		_titre("Par pays (mois dernier)")
		for nk in pays.cles_nations():
			var c := prod.commerce_nation(int(nk))
			_ligne(pays.nom_nation(int(nk)), "exporte %s, importe %s, douane %s" % [_euros(float(c.ventes)), _euros(float(c.achats)), _euros(float(c.douane))])
