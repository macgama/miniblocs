class_name QueFaireIci
extends CanvasLayer
## Fiche « Que faire ici ? » : un clic sur un terrain libre (outil Observer) montre,
## en images, ce que le joueur peut installer à cet endroit.
##  - les ressources autour du point (pictos, jauges, %) ;
##  - les bâtiments d'extraction posables ici (vignette, tonnes par jour prévues,
##    bouton Construire), et ceux qui ne le sont pas (trop pauvre, pas encore
##    inventé à l'époque de la partie, pas encore débloqué) ;
##  - les usines qui peuvent transformer ce qui sort d'ici (chaîne complète sur
##    place, ou avec un apport à faire venir).
## Le calcul (analyser) est statique et suit la règle de pose de
## Production.check_site : même richesse minimale, même rayon de mesure.
## Option : OptionsJeu.fiche_lieu (Options → Jeu). Aussi : P → Ressources.

signal construire(id: String)

const W := 372.0
## Rayon (m) des jauges de ressources autour du point.
const RAYON := 150.0
## En dessous, une ressource n'est pas montrée.
const SEUIL := 0.05
## Cultures qui demandent un climat (Plantes.Climat) : ailleurs, la fiche les
## range dans « Pas ici » (la règle de pose ne regarde que la terre).
const CLIMATS := {
	"oliveraie": [Plantes.Climat.MEDITERRANEEN],
	"plantation_tropicale": [Plantes.Climat.SUBTROPICAL, Plantes.Climat.TROPICAL],
}

var prod: Production
## Case analysée.
var cell := Vector2i.ZERO
## Dernière analyse (voir analyser).
var data := {}
## Lecture seule (visite) : pas de bouton Construire.
var lecture_seule := false
var _panel: PanelContainer
var _title: Label
var _sous: Label
var _body: VBoxContainer
var _scroll: ScrollContainer
var _retry := -1.0


func setup(p: Production) -> void:
	prod = p
	_build()


func _build() -> void:
	layer = 7
	_panel = PanelContainer.new()
	_panel.name = "FicheQueFaireIci"
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
	icon.texture = Icones.get_icon("lieu", 22, UiStyle.ACCENT)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(icon)
	_title = Label.new()
	_title.text = "Que faire ici ?"
	_title.add_theme_font_size_override("font_size", 16)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	var x := UiStyle.icon_button("fermer", "Fermer", "Échap", 18, 32)
	x.pressed.connect(fermer)
	head.add_child(x)
	_sous = Label.new()
	_sous.add_theme_font_size_override("font_size", 12)
	_sous.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	_sous.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sous.custom_minimum_size = Vector2(W - 24, 0)
	outer.add_child(_sous)
	_body = VBoxContainer.new()
	_body.custom_minimum_size = Vector2(W - 14, 0)
	_body.add_theme_constant_override("separation", 4)
	# S'arrête au-dessus de la barre des catégories (voir UiStyle.scroll_fit).
	_scroll = UiStyle.scroll_fit(_body, _panel, UiStyle.SIDE_BAS)
	outer.add_child(_scroll)


func is_open() -> bool:
	return _panel != null and _panel.visible


## Ouvre la fiche sur la case c (et refait l'analyse).
func ouvrir(c: Vector2i) -> void:
	cell = c
	_panel.visible = true
	_scroll.scroll_vertical = 0
	refresh()


func fermer() -> void:
	_panel.visible = false
	_retry = -1.0


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if is_open() and k and k.pressed and not k.echo and k.keycode == KEY_ESCAPE:
		fermer()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _retry < 0.0 or not is_open():
		return
	_retry -= delta
	if _retry <= 0.0:
		_retry = -1.0
		refresh()


func refresh() -> void:
	if prod == null or prod.carte == null:
		return
	data = analyser(prod, cell)
	for ch in _body.get_children():
		_body.remove_child(ch)
		ch.queue_free()
	var w := prod.world
	if w != null:
		var ll := w.local_to_lat_lon(cell.x + 0.5, cell.y + 0.5)
		_sous.text = "%s · %.4f, %.4f" % [w.cell_kind_at(cell), ll.x, ll.y]
	if not bool(data.connu):
		_text("Relief et biomes en cours de lecture…", true)
		_retry = 1.0
		return
	_view()


# --- Analyse -------------------------------------------------------------------------

## Ce qu'on peut installer autour de la case c :
## {connu, ressources: [[res, richesse]], ok: [fiche], non: [fiche], chaines: [fiche],
##  apports: [fiche], produits: [marchandises extraites ici]}.
## Fiche d'extraction : {id, name, etat ("ok", "pauvre", "epoque", "verrou"), res,
## rich, need, t_jour, good, raison} ; etat peut aussi valoir "climat". Fiche de chaîne : {id, name, in, out, manque, etat}.
static func analyser(p: Production, c: Vector2i) -> Dictionary:
	var out := {"connu": true, "ressources": [], "ok": [], "non": [], "chaines": [], "apports": [], "produits": []}
	var carte := p.carte
	var autour := Rect2i(c - Vector2i(2, 2), Vector2i(5, 5))
	for res in Ressources.ORDRE:
		var m := carte.mean_in(res, autour, RAYON)
		if m < 0.0:
			out.connu = false
			return out
		if m >= SEUIL:
			out.ressources.append([res, m])
	out.ressources.sort_custom(func(a: Array, b: Array) -> bool: return float(a[1]) > float(b[1]))
	var produits := {}
	var climat := -1
	if p.world != null:
		var ll := p.world.local_to_lat_lon(c.x + 0.5, c.y + 0.5)
		climat = Plantes.climat(ll.x, ll.y)
	for id in ProductionTypes.ORDER:
		var pr: Dictionary = ProductionTypes.TYPES[id].get("prod", {})
		if String(pr.get("kind", "")) != "extraction" or not pr.has("res"):
			continue
		var t: Dictionary = ProductionTypes.TYPES[id]
		var rect := Rect2i(c - Vector2i(int(t.w) / 2, int(t.d) / 2), Vector2i(int(t.w), int(t.d)))
		var best := carte.best_of((pr.res as Dictionary).keys(), rect, float(pr.get("radius", 0.0)))
		if float(best.rich) < 0.0:
			out.connu = false
			return out
		var need := float(pr.get("min", 0.1))
		var res := String(best.res)
		if res == "":
			res = String((pr.res as Dictionary).keys()[0])
		var rich := maxf(float(best.rich), 0.0)
		var good := Production._good_of(pr, res)
		var f := {"id": id, "name": String(t.name), "res": res, "rich": rich, "need": need,
			"t_jour": float(pr.res.get(res, 0.0)) * rich, "good": good, "etat": "ok", "raison": ""}
		var epoque := Epoques.raison_batiment(id)
		if epoque != "" or not Ressources.disponible(good):
			f.etat = "epoque"
			f.raison = epoque if epoque != "" else "Pas encore inventé à cette époque."
		elif climat >= 0 and CLIMATS.has(id) and not (CLIMATS[id] as Array).has(climat):
			f.etat = "climat"
			var noms: Array[String] = []
			for k in CLIMATS[id]:
				noms.append(Plantes.CLIMAT_NOMS[int(k)])
			f.raison = "Climat %s ici : il faut un climat %s." % [Plantes.CLIMAT_NOMS[climat], " ou ".join(noms)]
		elif rich < need:
			f.etat = "pauvre"
			f.raison = "Pas assez de %s ici : %d %%, il faut %d %%." % [String(Ressources.naturelle(res).name).to_lower(),
				roundi(rich * 100.0), roundi(need * 100.0)]
		else:
			var bloc := ReglagesPartie.actuel.raison_blocage(id) if ReglagesPartie.actuel != null else ""
			if bloc != "":
				f.etat = "verrou"
				f.raison = bloc
		if f.etat == "ok":
			out.ok.append(f)
			produits[good] = true
		else:
			out.non.append(f)
	out.ok.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.rich) > float(b.rich))
	# Les ressources trop pauvres à l'avant, celles de l'avenir à la fin.
	var rang := {"verrou": 0, "pauvre": 1, "climat": 2, "epoque": 3}
	out.non.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.etat != b.etat:
			return int(rang[a.etat]) < int(rang[b.etat])
		return float(a.rich) > float(b.rich))
	out.produits = produits.keys()
	# Chaînes : usines dont tous les intrants sortent d'ici (de proche en proche),
	# puis celles qui n'en reçoivent qu'une partie (le reste à faire venir).
	var dispo := produits.duplicate()
	var usines: Array = []
	for id in ProductionTypes.ORDER:
		var pr: Dictionary = ProductionTypes.TYPES[id].get("prod", {})
		if String(pr.get("kind", "")) != "transformation" or (pr.get("in", {}) as Dictionary).is_empty():
			continue
		if Epoques.raison_batiment(id) != "":
			continue
		usines.append(id)
	var faites := {}
	var encore := true
	while encore:
		encore = false
		for id in usines:
			if faites.has(id):
				continue
			var pr: Dictionary = ProductionTypes.TYPES[id].prod
			var tout := true
			for g in pr.in:
				if Ressources.disponible(g) and not dispo.has(g):
					tout = false
					break
			if tout:
				faites[id] = true
				encore = true
				for g in pr.out:
					dispo[g] = true
				out.chaines.append(_chaine(id, []))
	for id in usines:
		if faites.has(id):
			continue
		var pr: Dictionary = ProductionTypes.TYPES[id].prod
		var ici := false
		var manque: Array = []
		for g in pr.in:
			if not Ressources.disponible(g):
				continue
			if dispo.has(g):
				ici = true
			else:
				manque.append(g)
		if ici:
			out.apports.append(_chaine(id, manque))
	out.apports.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a.manque as Array).size() < (b.manque as Array).size())
	return out


static func _chaine(id: String, manque: Array) -> Dictionary:
	var pr: Dictionary = ProductionTypes.TYPES[id].prod
	return {"id": id, "name": String(ProductionTypes.TYPES[id].name), "in": (pr.in as Dictionary).keys(),
		"out": (pr.out as Dictionary).keys(), "manque": manque, "etat": "ok" if manque.is_empty() else "apport"}


# --- Affichage -----------------------------------------------------------------------

func _view() -> void:
	var res: Array = data.ressources
	_section("Ressources autour (%d m)" % int(RAYON), "ressources")
	if res.is_empty():
		_text("Rien d'exploitable ici : ni forêt, ni bonne terre, ni roche, ni gisement connu.", true)
	else:
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 4)
		grid.add_theme_constant_override("v_separation", 4)
		_body.add_child(grid)
		for e in res:
			grid.add_child(_tuile_ressource(String(e[0]), float(e[1])))
	var ok: Array = data.ok
	_section("À construire ici (%d)" % ok.size(), "construire")
	if ok.is_empty():
		_text("Aucun bâtiment d'extraction ne trouve assez de ressources ici. Regarde la carte des ressources (P) ou essaie un peu plus loin.", true)
	for f in ok:
		_carte_batiment(f)
	var chaines: Array = data.chaines
	var apports: Array = data.apports
	if not chaines.is_empty() or not apports.is_empty():
		_section("Pour transformer ce qui sort d'ici", "industrie")
		for ch in chaines:
			_carte_chaine(ch)
		for ch in apports.slice(0, 8):
			_carte_chaine(ch)
		if apports.size() > 8:
			_text("… et %d autres usines avec un apport." % (apports.size() - 8), true, 11)
	var non: Array = data.non
	if not non.is_empty():
		_section("Pas ici (%d)" % non.size(), "cadenas")
		var grid2 := GridContainer.new()
		grid2.columns = 4
		grid2.add_theme_constant_override("h_separation", 4)
		grid2.add_theme_constant_override("v_separation", 4)
		_body.add_child(grid2)
		for f in non:
			grid2.add_child(_tuile_grise(f))
	var sous_sol := false
	for e in res:
		if String(e[0]) in Ressources.SOUS_SOL:
			sous_sol = true
	if sous_sol:
		_text("Le sous-sol est estimé : un sondage (P → Mines) donne la vraie richesse avant d'ouvrir une mine.", true, 11)
	_text("Les intrants qui manquent s'achètent ailleurs (gares, ports, routes qui sortent de la carte).", true, 11)


func _section(t: String, icone := "") -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_body.add_child(row)
	if icone != "":
		var ic := TextureRect.new()
		ic.texture = Icones.get_icon(icone, 18, UiStyle.ACCENT)
		ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		row.add_child(ic)
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", UiStyle.ACCENT)
	row.add_child(l)


func _text(t: String, dim := false, size := 12) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(W - 30, 0)
	l.add_theme_font_size_override("font_size", size)
	if dim:
		l.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	_body.add_child(l)
	return l


func _bar(value: float, col: Color, w := 0.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.min_value = 0.0
	b.max_value = 1.0
	b.value = clampf(value, 0.0, 1.0)
	b.show_percentage = false
	b.custom_minimum_size = Vector2(w, 7)
	var fond := StyleBoxFlat.new()
	fond.bg_color = Color(1, 1, 1, 0.12)
	fond.set_corner_radius_all(3)
	var plein := StyleBoxFlat.new()
	plein.bg_color = col
	plein.set_corner_radius_all(3)
	b.add_theme_stylebox_override("background", fond)
	b.add_theme_stylebox_override("fill", plein)
	return b


## Tuile d'une ressource : picto, nom, jauge et pourcentage.
func _tuile_ressource(res: String, rich: float) -> Control:
	var nat := Ressources.naturelle(res)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiStyle.flat_box(Color(1, 1, 1, 0.06), 8, 5))
	p.custom_minimum_size = Vector2((W - 40) / 3.0, 0)
	p.tooltip_text = "%s\n%s" % [nat.name, nat.desc]
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	p.add_child(v)
	var ic := TextureRect.new()
	ic.texture = icone_ressource(res, 34)
	ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	ic.custom_minimum_size = Vector2(0, 36)
	v.add_child(ic)
	var l := Label.new()
	l.text = String(nat.name).replace(" (bois)", "")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2((W - 56) / 3.0, 0)
	l.add_theme_font_size_override("font_size", 10)
	v.add_child(l)
	v.add_child(_bar(rich, nat.color))
	var pc := Label.new()
	pc.text = "%d %%" % roundi(rich * 100.0)
	pc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pc.add_theme_font_size_override("font_size", 11)
	pc.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	v.add_child(pc)
	return p


func _vignette(id: String, taille: Vector2, gris := false) -> TextureRect:
	var r := TextureRect.new()
	r.custom_minimum_size = taille
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not Illustrations.poser("batiment", id, r):
		var pr := ProductionTypes.prod_of(id)
		var ic := "industrie"
		var res: Dictionary = pr.get("res", {})
		if res.has("fertilite") or res.has("paturage"):
			ic = "agriculture"
		elif res.has("bois"):
			ic = "paysage"
		r.texture = Icones.get_icon(ic, 40)
		r.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	if gris:
		r.modulate = Color(0.55, 0.55, 0.55, 0.75)
	return r


## Carte d'un bâtiment posable : vignette, nom, ressource, tonnes par jour, Construire.
func _carte_batiment(f: Dictionary) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiStyle.flat_box(Color(0.62, 0.89, 0.69, 0.10), 9, 6))
	_body.add_child(p)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	p.add_child(row)
	row.add_child(_vignette(String(f.id), Vector2(84, 56)))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 1)
	row.add_child(v)
	var n := Label.new()
	n.text = String(f.name)
	n.add_theme_font_size_override("font_size", 13)
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	n.custom_minimum_size = Vector2(W - 200, 0)
	v.add_child(n)
	var nat := Ressources.naturelle(String(f.res))
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 4)
	v.add_child(r)
	var ic := TextureRect.new()
	ic.texture = icone_ressource(String(f.res), 18)
	ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	r.add_child(ic)
	var b := _bar(float(f.rich), nat.color, 60)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(b)
	var pc := Label.new()
	pc.text = "%d %%" % roundi(float(f.rich) * 100.0)
	pc.add_theme_font_size_override("font_size", 11)
	r.add_child(pc)
	var t := Label.new()
	t.text = "≈ %s de %s par jour" % [Ressources.format_t(float(f.t_jour)), Ressources.good_name(String(f.good)).to_lower()]
	t.add_theme_font_size_override("font_size", 11)
	t.add_theme_color_override("font_color", UiStyle.GOOD)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(W - 200, 0)
	v.add_child(t)
	var go := UiStyle.icon_button("construire", "Construire ici : %s" % f.name, "", 20, 38)
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	go.disabled = lecture_seule
	var id := String(f.id)
	go.pressed.connect(func() -> void:
		construire.emit(id)
		fermer())
	row.add_child(go)


## Carte d'une usine : vignette, intrants → produits en pictos de couleur.
func _carte_chaine(ch: Dictionary) -> void:
	var apport := String(ch.etat) == "apport"
	var p := PanelContainer.new()
	var fond := Color(1.0, 0.82, 0.4, 0.09) if apport else Color(0.62, 0.89, 0.69, 0.08)
	p.add_theme_stylebox_override("panel", UiStyle.flat_box(fond, 9, 5))
	_body.add_child(p)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	p.add_child(row)
	row.add_child(_vignette(String(ch.id), Vector2(60, 40)))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 1)
	row.add_child(v)
	var n := Label.new()
	n.text = String(ch.name)
	n.add_theme_font_size_override("font_size", 12)
	v.add_child(n)
	var flux := HFlowContainer.new()
	flux.add_theme_constant_override("h_separation", 3)
	v.add_child(flux)
	var manque: Array = ch.manque
	for g in ch.in:
		flux.add_child(_pastille(String(g), manque.has(g)))
	var fl := Label.new()
	fl.text = "→"
	fl.add_theme_font_size_override("font_size", 12)
	flux.add_child(fl)
	for g in ch.out:
		flux.add_child(_pastille(String(g), false))
	if apport:
		var names: Array[String] = []
		for g in manque:
			names.append(Ressources.good_name(String(g)).to_lower())
		var m := Label.new()
		m.text = "À faire venir : " + ", ".join(names)
		m.add_theme_font_size_override("font_size", 11)
		m.add_theme_color_override("font_color", UiStyle.ACCENT)
		m.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		m.custom_minimum_size = Vector2(W - 120, 0)
		v.add_child(m)
	p.tooltip_text = Production.recipe_text(String(ch.id))


## Petite pastille d'une marchandise (pointillés si elle manque).
func _pastille(g: String, manque: bool) -> Control:
	var l := Label.new()
	l.text = Ressources.good_name(g).to_lower()
	l.add_theme_font_size_override("font_size", 10)
	var box := UiStyle.flat_box(Color(1, 0.82, 0.4, 0.28) if manque else Color(1, 1, 1, 0.12), 6, 3)
	box.content_margin_top = 1
	box.content_margin_bottom = 1
	l.add_theme_stylebox_override("normal", box)
	return l


## Vignette grisée d'un bâtiment impossible ici, avec la raison en infobulle.
func _tuile_grise(f: Dictionary) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	v.custom_minimum_size = Vector2((W - 44) / 4.0, 0)
	v.tooltip_text = "%s\n%s" % [f.name, f.raison]
	v.mouse_filter = Control.MOUSE_FILTER_STOP
	var cadre := Control.new()
	cadre.custom_minimum_size = Vector2(0, 44)
	cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(cadre)
	var vi := _vignette(String(f.id), Vector2(66, 44), true)
	vi.set_anchors_preset(Control.PRESET_FULL_RECT)
	cadre.add_child(vi)
	var badge := TextureRect.new()
	var icone: String = {"epoque": "horloge", "verrou": "cadenas", "climat": "thermometre"}.get(String(f.etat), "moins")
	badge.texture = Icones.get_icon(icone, 16, Color("ff9f7a") if f.etat == "pauvre" else UiStyle.TEXT_DIM)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.position = Vector2(-18, 0)
	cadre.add_child(badge)
	var l := Label.new()
	l.text = String(f.name)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 9)
	l.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(l)
	var why := Label.new()
	if f.etat == "epoque":
		why.text = "arrive en %d" % Epoques.annee_batiment(String(f.id)) if Epoques.raison_batiment(String(f.id)) != "" else "plus tard"
	elif f.etat == "verrou":
		why.text = "à débloquer"
	elif f.etat == "climat":
		why.text = "mauvais climat"
	else:
		why.text = "%d %% / %d %%" % [roundi(float(f.rich) * 100.0), roundi(float(f.need) * 100.0)]
	why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	why.add_theme_font_size_override("font_size", 9)
	why.add_theme_color_override("font_color", Color("ff9f7a") if f.etat == "pauvre" else UiStyle.TEXT_DIM)
	why.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(why)
	return v


# --- Pictos des ressources ---------------------------------------------------------------

## Dessin blanc posé sur une pastille de la couleur de la ressource (SVG 24 × 24).
const DESSINS := {
	"bois": "<path d=\"M12 3 6 11h3l-4 6h14l-4-6h3Z\" fill=\"#fff\"/><rect x=\"11\" y=\"17\" width=\"2\" height=\"4\" fill=\"#fff\"/>",
	"fertilite": "<path d=\"M12 21V8\" stroke=\"#fff\" stroke-width=\"1.6\"/><path d=\"M12 8c0-2.4 1.2-4.2 2.8-5.6.4 2.4-.6 4.4-2.8 5.6ZM12 12c-2.4-.2-4.2-1.5-5-3.7 2.4-.3 4.3.8 5 3.7ZM12 12c2.4-.2 4.2-1.5 5-3.7-2.4-.3-4.3.8-5 3.7ZM12 16c-2.4-.2-4.2-1.5-5-3.7 2.4-.3 4.3.8 5 3.7ZM12 16c2.4-.2 4.2-1.5 5-3.7-2.4-.3-4.3.8-5 3.7Z\" fill=\"#fff\"/>",
	"paturage": "<rect x=\"5\" y=\"9\" width=\"12\" height=\"6\" rx=\"2\" fill=\"#fff\"/><rect x=\"16\" y=\"7\" width=\"4\" height=\"4\" rx=\"1\" fill=\"#fff\"/><path d=\"M7 15v4M15 15v4\" stroke=\"#fff\" stroke-width=\"1.8\"/>",
	"poisson": "<path d=\"M3 12c3-4 9-5 13 0-4 5-10 4-13 0Z\" fill=\"#fff\"/><path d=\"M16 12l5-4v8Z\" fill=\"#fff\"/>",
	"pierre": "<path d=\"M4 18 7 10l5-3 6 3 2 8Z\" fill=\"#fff\"/><path d=\"M7 10l4 3 7-3M11 13v5\" stroke=\"#888\" stroke-width=\"1\" fill=\"none\"/>",
	"sable": "<path d=\"M2 17c4-5 7-5 10-2s6 3 10-1v6H2Z\" fill=\"#fff\"/><circle cx=\"8\" cy=\"9\" r=\"1\" fill=\"#fff\"/><circle cx=\"12\" cy=\"7\" r=\"1\" fill=\"#fff\"/><circle cx=\"16\" cy=\"10\" r=\"1\" fill=\"#fff\"/>",
	"argile": "<path d=\"M7 6h10l2 13H5Z\" fill=\"#fff\"/><path d=\"M6 10h12M6 14h12\" stroke=\"#bc6c25\" stroke-width=\"1.2\"/>",
	"calcaire": "<rect x=\"4\" y=\"6\" width=\"16\" height=\"4\" fill=\"#fff\"/><rect x=\"4\" y=\"11\" width=\"16\" height=\"4\" fill=\"#fff\" opacity=\".8\"/><rect x=\"4\" y=\"16\" width=\"16\" height=\"3\" fill=\"#fff\" opacity=\".6\"/>",
	"granite": "<path d=\"M3 19 9 7l4 6 3-3 5 9Z\" fill=\"#fff\"/><circle cx=\"10\" cy=\"14\" r=\"1\" fill=\"#b5838d\"/><circle cx=\"14\" cy=\"16\" r=\"1\" fill=\"#b5838d\"/>",
	"sel": "<path d=\"M12 4 19 8v8l-7 4-7-4V8Z\" fill=\"#fff\"/><path d=\"M5 8l7 4 7-4M12 12v8\" stroke=\"#bbb\" stroke-width=\"1\" fill=\"none\"/>",
	"fer": "<path d=\"M5 15 8 8h8l3 7Z\" fill=\"#fff\"/><rect x=\"4\" y=\"15\" width=\"16\" height=\"3\" fill=\"#fff\"/>",
	"charbon": "<path d=\"M4 17 7 11l4-2 3 3 4-1 2 6Z\" fill=\"#fff\"/><path d=\"M7 11l2 6M14 12l-1 5\" stroke=\"#343a40\" stroke-width=\"1\"/>",
	"cuivre": "<circle cx=\"12\" cy=\"12\" r=\"6.5\" fill=\"none\" stroke=\"#fff\" stroke-width=\"2.4\"/><circle cx=\"12\" cy=\"12\" r=\"2.5\" fill=\"#fff\"/>",
	"or": "<path d=\"M4 17 7 11h10l3 6Z\" fill=\"#fff\"/><path d=\"M8 11l2-4h4l2 4\" fill=\"#fff\" opacity=\".8\"/>",
	"bauxite": "<circle cx=\"9\" cy=\"13\" r=\"4\" fill=\"#fff\"/><circle cx=\"15.5\" cy=\"11\" r=\"3\" fill=\"#fff\"/><circle cx=\"14\" cy=\"17\" r=\"2.2\" fill=\"#fff\"/>",
	"petrole": "<path d=\"M12 3c3 5 6 8 6 11a6 6 0 0 1-12 0c0-3 3-6 6-11Z\" fill=\"#fff\"/>",
	"gaz": "<path d=\"M12 3c1 4 6 6 6 11a6 6 0 0 1-12 0c0-2.5 1.5-4 3-5 0 2 1 3 2 3 0-3 0-6 1-9Z\" fill=\"#fff\"/>",
}
static var _icones := {}


## Picto rond d'une ressource naturelle, `taille` pixels.
static func icone_ressource(res: String, taille := 32) -> Texture2D:
	var key := "%s|%d" % [res, taille]
	if _icones.has(key):
		return _icones[key]
	var col: Color = Ressources.naturelle(res).get("color", Color.GRAY)
	var fond := col.darkened(0.15) if col.get_luminance() > 0.75 else col
	if col.get_luminance() > 0.75:
		fond = col.darkened(0.35)
	var svg := "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"24\" height=\"24\" viewBox=\"0 0 24 24\"><circle cx=\"12\" cy=\"12\" r=\"11.5\" fill=\"#%s\"/>%s</svg>" % [
		fond.to_html(false), String(DESSINS.get(res, "<circle cx=\"12\" cy=\"12\" r=\"4\" fill=\"#fff\"/>"))]
	var img := Image.new()
	if img.load_svg_from_string(svg, float(taille) / 24.0) != OK:
		return null
	var tex := ImageTexture.create_from_image(img)
	_icones[key] = tex
	return tex
