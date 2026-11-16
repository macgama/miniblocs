class_name ParcoursAtelier
extends CanvasLayer
## Parcours guidé du mode Créer et de l'Atelier : trois étapes affichées en haut
## (1 Construire, 2 Nom et usage, 3 Enregistrer) et un seul bouton
## « Enregistrer mon bâtiment ». Il prend la construction visée (murs fins avec
## leur toit et leurs blocs, ou un groupe de blocs) sans rectangle à tracer,
## demande son nom et son usage dans la partie, puis la range dans
## Construire › Mes modèles. Ensuite : « Le poser dans ma partie ».

## Le joueur veut poser le bâtiment enregistré (id du catalogue).
signal poser_demande(catalog_id: String)

const ETAPES := ["Construire", "Nom et usage", "Enregistrer"]

var plans: PlanEditor
var blocks: BlockEditor
var mob: Mobilier
## Point regardé par la caméra (Callable -> Vector3), pour choisir la construction visée.
var focus: Callable
## Texte du bouton « poser » après l'enregistrement (Atelier : retour à la partie).
var texte_poser := "Le poser dans ma partie"
## Vrai : le bouton « poser » est proposé (faux : atelier ouvert depuis le menu).
var poser_possible := true

var _bar: PanelContainer
var _steps: Array[Label] = []
var _save_btn: Button
var _hint: Label
var _dialog: PanelContainer
var _dlg_box: VBoxContainer
var _etape := 0
var _enregistre := false
var _nom := ""
var _fonction := ""
var _cible: Dictionary = {}
var _dernier: Dictionary = {}
var _refresh_timer := 0.0


func _ready() -> void:
	layer = 5
	_bar = PanelContainer.new()
	_bar.name = "ParcoursAtelier"
	_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_bar.offset_top = 108
	UiStyle.style_panel(_bar, 0.92, 12, 8)
	add_child(_bar)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	_bar.add_child(col)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	for i in ETAPES.size():
		if i > 0:
			var a := Label.new()
			a.text = "›"
			a.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
			row.add_child(a)
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 14)
		row.add_child(l)
		_steps.append(l)
	row.add_child(UiStyle.vsep())
	_save_btn = Button.new()
	_save_btn.name = "EnregistrerBatiment"
	_save_btn.text = "Enregistrer mon bâtiment"
	_save_btn.icon = Icones.get_icon("banque", 18, Color("08200f"))
	_save_btn.tooltip_text = "Range ta construction dans Construire › Mes modèles, pour la poser dans toutes tes parties."
	_save_btn.focus_mode = Control.FOCUS_NONE
	_green(_save_btn)
	_save_btn.pressed.connect(ouvrir)
	row.add_child(_save_btn)
	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 12)
	_hint.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_hint)

	_dialog = PanelContainer.new()
	_dialog.name = "FicheEnregistrer"
	_dialog.set_anchors_preset(Control.PRESET_CENTER)
	_dialog.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_dialog.grow_vertical = Control.GROW_DIRECTION_BOTH
	_dialog.custom_minimum_size = Vector2(520, 0)
	UiStyle.style_panel(_dialog, 0.97, 14, 16)
	_dialog.visible = false
	add_child(_dialog)
	_dlg_box = VBoxContainer.new()
	_dlg_box.add_theme_constant_override("separation", 8)
	_dialog.add_child(_dlg_box)
	set_shown(false)
	_refresh()


static func _green(b: Button) -> void:
	var c := Color("46b56a")
	b.add_theme_stylebox_override("normal", UiStyle.flat_box(c, 8, 8))
	b.add_theme_stylebox_override("hover", UiStyle.flat_box(c.lightened(0.12), 8, 8))
	b.add_theme_stylebox_override("pressed", UiStyle.flat_box(c.darkened(0.12), 8, 8))
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, Color("08200f"))


func setup(p: PlanEditor, b: BlockEditor, m: Mobilier, f: Callable) -> void:
	plans = p
	blocks = b
	mob = m
	focus = f
	for sig in [p.changed, b.changed]:
		(sig as Signal).connect(func() -> void:
			_enregistre = false
			_refresh_timer = 0.2)
	_refresh()


## Visible en mode Créer et dans l'Atelier.
func set_shown(on: bool) -> void:
	_bar.visible = on
	if not on:
		fermer()


func is_shown() -> bool:
	return _bar.visible


func dialog_open() -> bool:
	return _dialog.visible


func _process(delta: float) -> void:
	if _refresh_timer > 0.0:
		_refresh_timer -= delta
		if _refresh_timer <= 0.0:
			_refresh()


# --- Construction visée ----------------------------------------------------------

func _focus_point() -> Vector3:
	return focus.call() if focus.is_valid() else Vector3.ZERO


## Ce que « Enregistrer » prendra : {genre: "plan", id} ou {genre: "blocs", rect, n}, ou {}.
func cible() -> Dictionary:
	if plans != null:
		var pid := plans.active_id()
		if pid != "" and not _plan_ok(pid):
			pid = ""
		if pid == "":
			var f := _focus_point()
			var best := INF
			for id in plans.plans:
				if not _plan_ok(String(id)):
					continue
				var bb: Rect2i = plans._bbox.get(id, Rect2i())
				var c := Vector2(bb.position) + Vector2(bb.size) * 0.5
				var d := c.distance_to(Vector2(f.x, f.z))
				if d < best:
					best = d
					pid = String(id)
		if pid != "":
			return {"genre": "plan", "id": pid}
	if blocks != null and not blocks.blocks.is_empty():
		var r := groupe_blocs(blocks.blocks, _focus_point())
		if r.n > 0:
			return {"genre": "blocs", "rect": r.rect, "n": r.n}
	return {}


func _plan_ok(id: String) -> bool:
	if not plans.plans.has(id) or (plans.plans[id].walls as Dictionary).is_empty():
		return false
	# Murs d'un modèle déjà posé dans la ville : ce n'est pas une construction en cours.
	return mob == null or not mob.linked.has(id)


## Groupe de blocs voisins (cases qui se touchent, coins compris) le plus près
## du point f, limité à Creations.MAX_SIDE de côté : {rect: Rect2i, n: blocs}.
static func groupe_blocs(all: Dictionary, f: Vector3) -> Dictionary:
	var cells := {}
	for k in all:
		var kk: Vector3i = k
		var c := Vector2i(kk.x, kk.z)
		cells[c] = int(cells.get(c, 0)) + 1
	if cells.is_empty():
		return {"rect": Rect2i(), "n": 0}
	var start := Vector2i.ZERO
	var best := INF
	var fp := Vector2(f.x, f.z)
	for c: Vector2i in cells:
		var d := (Vector2(c) + Vector2(0.5, 0.5)).distance_squared_to(fp)
		if d < best:
			best = d
			start = c
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	var lo := start
	var hi := start
	var n := 0
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		n += int(cells[c])
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				var nc := c + Vector2i(dx, dz)
				if seen.has(nc) or not cells.has(nc):
					continue
				# Pas plus grand qu'une création.
				if maxi(hi.x, nc.x) - mini(lo.x, nc.x) >= Creations.MAX_SIDE or maxi(hi.y, nc.y) - mini(lo.y, nc.y) >= Creations.MAX_SIDE:
					continue
				seen[nc] = true
				queue.append(nc)
	return {"rect": Rect2i(lo, hi - lo + Vector2i.ONE), "n": n}


## Une phrase sur la construction visée.
func describe(c: Dictionary) -> String:
	if c.is_empty():
		return "Rien à enregistrer pour l'instant."
	if c.genre == "plan":
		var bb: Rect2i = plans._bbox.get(c.id, Rect2i())
		var lv := plans.levels_of(String(c.id)).size()
		return "Bâtiment en murs · %d × %d m · %d niveau%s" % [bb.size.x, bb.size.y, lv, "x" if lv > 1 else ""]
	var r: Rect2i = c.rect
	return "Construction en blocs · %d bloc%s · %d × %d m" % [int(c.n), "s" if int(c.n) > 1 else "", r.size.x, r.size.y]


# --- Étapes -------------------------------------------------------------------

func etape() -> int:
	return _etape


func _refresh() -> void:
	if _steps.is_empty():
		return
	var built := not cible().is_empty()
	if _enregistre:
		_etape = 3
	elif _dialog.visible:
		_etape = 1
	else:
		_etape = 1 if built else 0
	for i in _steps.size():
		var l := _steps[i]
		var done := i < _etape or (i == 0 and built)
		l.text = ("✓ " if done else "%d  " % (i + 1)) + ETAPES[i]
		var col := UiStyle.GOOD if done else (UiStyle.CREATE if i == _etape else UiStyle.TEXT_DIM)
		l.add_theme_color_override("font_color", col)
	_save_btn.disabled = not built
	if _enregistre:
		_hint.text = "Enregistré : retrouve-le dans Construire › Mes modèles, dans toutes tes parties."
	elif built:
		_hint.text = "Quand ton bâtiment te plaît : « Enregistrer mon bâtiment »."
	else:
		_hint.text = "Construis avec Murs et étages (2) ou Blocs (3). Clic droit : retirer · Ctrl+Z : annuler."


# --- Fiche « Enregistrer mon bâtiment » -----------------------------------------

func ouvrir() -> void:
	_cible = cible()
	if _cible.is_empty():
		return
	_fonction = _fonction_par_defaut(_cible)
	_nom = ""
	_fill_form()
	_dialog.visible = true
	_refresh()


func fermer() -> void:
	if _dialog != null:
		_dialog.visible = false
	_refresh()


func _fonction_par_defaut(c: Dictionary) -> String:
	if c.genre == "plan" and mob != null:
		var am: Dictionary = plans.plans[c.id].get("am", {})
		var s := Amenagements.suggest_fonction(am)
		if s != "" and not mob.usages.has(c.id):
			return s
		return String(Mobilier.USAGES.get(mob.usage_of(String(c.id)), Mobilier.USAGES.logement).t)
	return ""


func _clear() -> void:
	for ch in _dlg_box.get_children():
		_dlg_box.remove_child(ch)
		ch.queue_free()


static func _label(text: String, size := 13, dim := false) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	if dim:
		l.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	return l


func _fill_form() -> void:
	_clear()
	var head := HBoxContainer.new()
	var t := _label("Enregistrer mon bâtiment", 18)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var x := UiStyle.icon_button("fermer", "Fermer (Échap)", "", 18, 32)
	x.pressed.connect(fermer)
	head.add_child(x)
	_dlg_box.add_child(head)
	_dlg_box.add_child(_label(describe(_cible), 13, true))
	_dlg_box.add_child(_label("Nom", 13))
	var name_edit := LineEdit.new()
	name_edit.name = "Nom"
	name_edit.placeholder_text = "Chalet du lac, gare du village…"
	name_edit.text = _nom
	name_edit.text_changed.connect(func(s: String) -> void: _nom = s)
	_dlg_box.add_child(name_edit)
	_dlg_box.add_child(_label("Usage dans la partie", 13))
	var cur := _label("", 13)
	cur.add_theme_color_override("font_color", UiStyle.GOOD)
	_dlg_box.add_child(cur)
	var set_cur := func() -> void:
		cur.text = ("Il jouera le rôle de : %s" % ModelesJeu.fonction_name(_fonction)) if _fonction != "" else "Simple décor (pas de rôle dans la ville)"
	set_cur.call()
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 220)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_dlg_box.add_child(scroll)
	var ch := FonctionChoix.new(_fonction)
	ch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _cible.genre == "blocs":
		var none := Button.new()
		none.text = "Aucun rôle (simple décor)"
		none.alignment = HORIZONTAL_ALIGNMENT_LEFT
		none.pressed.connect(func() -> void: ch.picked.emit(""))
		ch.add_child(none)
		ch.move_child(none, 1)
	ch.picked.connect(func(f: String) -> void:
		_fonction = f
		set_cur.call())
	scroll.add_child(ch)
	_dlg_box.add_child(_label("Il ira dans Construire › Mes modèles, dans toutes tes parties, avec son prix et son chantier.", 12, true))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	var cancel := Button.new()
	cancel.text = "Annuler"
	cancel.pressed.connect(fermer)
	row.add_child(cancel)
	var ok := Button.new()
	ok.name = "Valider"
	ok.text = "Enregistrer"
	ok.icon = Icones.get_icon("banque", 18, Color("08200f"))
	_green(ok)
	ok.pressed.connect(func() -> void: enregistrer(_nom, _fonction))
	row.add_child(ok)
	_dlg_box.add_child(row)
	name_edit.grab_focus.call_deferred()


## Enregistre la construction visée : {ok, catalog_id, nom} ou {ok: false, error}.
func enregistrer(nom: String, fonction: String) -> Dictionary:
	var c := _cible if not _cible.is_empty() else cible()
	var res := {"ok": false, "error": "Rien à enregistrer : construis d'abord quelque chose."}
	if c.is_empty():
		return res
	if c.genre == "plan":
		# L'aperçu : l'image de l'écran sans la fiche ni le bandeau.
		_dialog.visible = false
		_bar.visible = false
		var r := BanqueModeles.save_plan(mob, String(c.id), nom, get_viewport())
		_bar.visible = true
		if r.ok:
			if fonction != "":
				BanqueModeles.set_fonction(String(r.id), fonction)
			res = {"ok": true, "catalog_id": ModelesJeu.catalog_id(String(r.id)), "nom": String(r.nom)}
		else:
			res = {"ok": false, "error": String(r.error)}
	else:
		var r := Creations.capture(blocks, c.rect, nom)
		if r.ok:
			if fonction != "":
				Creations.set_fonction(String(r.id), fonction)
			res = {"ok": true, "catalog_id": String(r.id), "nom": String(Creations.items[r.id].name)}
		else:
			res = {"ok": false, "error": String(r.reason)}
	_dernier = res
	_cible = {}
	if res.ok:
		_enregistre = true
		_show_done(res)
	else:
		_fill_form()
		_dlg_box.add_child(_label(String(res.error), 13))
	_dialog.visible = true
	_refresh()
	return res


func dernier() -> Dictionary:
	return _dernier


func _show_done(res: Dictionary) -> void:
	_clear()
	var t := _label("« %s » est enregistré" % String(res.nom), 18)
	t.add_theme_color_override("font_color", UiStyle.GOOD)
	_dlg_box.add_child(t)
	_dlg_box.add_child(_label("Tu le retrouves dans Construire › Mes modèles, dans toutes tes parties. Pour le partager avec d'autres joueurs : Mes modèles › Partager.", 13, true))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	var more := Button.new()
	more.text = "Continuer à construire"
	more.pressed.connect(fermer)
	row.add_child(more)
	if poser_possible:
		var put := Button.new()
		put.name = "Poser"
		put.text = texte_poser
		put.icon = Icones.get_icon("plus", 18, Color("08200f"))
		_green(put)
		var cid := String(res.catalog_id)
		put.pressed.connect(func() -> void:
			fermer()
			poser_demande.emit(cid))
		row.add_child(put)
	_dlg_box.add_child(row)


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and k.keycode == KEY_ESCAPE and _dialog.visible:
		fermer()
		get_viewport().set_input_as_handled()
