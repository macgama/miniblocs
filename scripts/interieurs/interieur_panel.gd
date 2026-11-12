class_name InterieurPanel
extends RefCounted
## Onglet « Intérieur » du panneau Construire : le bâtiment visé et ses
## chiffres, son usage, le style du mobilier, les outils (meubler une pièce,
## fonction des pièces, retirer), les bâtiments meublés prêts à visiter et le
## catalogue des meubles (la bible, filtrée par pièce, style et nom).

const MAX_SHOWN := 150

var mob: Mobilier
## Appelée avant de prendre un outil (range les autres outils).
var prepare: Callable

var _cat := "sejour"
var _style_filter := ""
var _search := ""
var _stats: Label
var _level: Label
var _usage_opt: OptionButton
var _bp: BuildingPanel


func setup(m: Mobilier, prep: Callable) -> void:
	mob = m
	prepare = prep
	mob.changed.connect(_refresh_stats)
	mob.plan_selected.connect(func(_id: String) -> void: _refresh_stats())
	if mob.pe != null:
		mob.pe.level_changed.connect(func(t: String) -> void:
			if is_instance_valid(_level):
				_level.text = t)


func _tool(t: Mobilier.Tool) -> void:
	if prepare.is_valid():
		prepare.call()
	mob.set_tool(t)


static func _label(text: String, size := 12, dim := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if dim:
		l.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	return l


static func _title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", UiStyle.ACCENT)
	return l


func build(bp: BuildingPanel) -> void:
	_bp = bp
	var group := bp.item_group()
	# --- Le bâtiment visé ---------------------------------------------------------
	bp.add_control(_title("Bâtiment visé"))
	_stats = _label("", 12)
	bp.add_control(_stats)
	var urow := HBoxContainer.new()
	urow.add_child(_label("Usage :", 12))
	_usage_opt = OptionButton.new()
	_usage_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for u in Mobilier.USAGE_ORDER:
		_usage_opt.add_item(String(Mobilier.USAGES[u].name))
		_usage_opt.set_item_metadata(_usage_opt.item_count - 1, u)
		_usage_opt.set_item_tooltip(_usage_opt.item_count - 1, String(Mobilier.USAGES[u].desc))
	_usage_opt.item_selected.connect(func(i: int) -> void:
		var id := mob.focus_id()
		if id == "":
			mob.message.emit("Vise d'abord un bâtiment en murs fins (survole-le avec un outil de cet onglet).")
			return
		mob.set_usage(id, String(_usage_opt.get_item_metadata(i))))
	urow.add_child(_usage_opt)
	var all := Button.new()
	all.text = "Meubler tout"
	all.tooltip_text = "Meuble toutes les pièces du bâtiment visé, selon leur fonction, dans le style choisi."
	all.pressed.connect(func() -> void:
		var id := mob.focus_id()
		if id == "":
			mob.message.emit("Vise d'abord un bâtiment en murs fins.")
			return
		var n := mob.furnish_plan(id)
		mob.message.emit("%d meuble%s posé%s dans %s." % [n, "s" if n > 1 else "", "s" if n > 1 else "", mob.plan_name(id)]))
	urow.add_child(all)
	bp.add_control(urow)
	var brow := HBoxContainer.new()
	var bname := LineEdit.new()
	bname.placeholder_text = "Nom du modèle"
	bname.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brow.add_child(bname)
	var bsave := Button.new()
	bsave.text = "Enregistrer dans la banque"
	bsave.icon = Icones.get_icon("banque", 18)
	bsave.tooltip_text = "Range le bâtiment visé (murs, pièces, meubles, toit) dans ta banque de modèles, pour le reposer ou l'échanger."
	bsave.pressed.connect(func() -> void:
		var id := mob.focus_id()
		if id == "":
			mob.message.emit("Vise d'abord un bâtiment en murs fins.")
			return
		var r := BanqueModeles.save_plan(mob, id, bname.text, bp.get_viewport())
		mob.message.emit(("Modèle « %s » enregistré dans la banque." % String(r.nom)) if r.ok else String(r.error)))
	brow.add_child(bsave)
	bp.add_control(brow)
	# --- Style ---------------------------------------------------------------------
	var srow := HBoxContainer.new()
	srow.add_child(_label("Style :", 12))
	var st := _style_option(false)
	st.item_selected.connect(func(i: int) -> void: mob.set_style(String(st.get_item_metadata(i))))
	srow.add_child(st)
	bp.add_control(srow)
	# --- Outils ----------------------------------------------------------------------
	var trow := HFlowContainer.new()
	for t in [["Meubler une pièce", Mobilier.Tool.FURNISH, "Clic dans une pièce : elle est meublée selon sa fonction (choisie ou devinée)."],
			["Fonction", Mobilier.Tool.ROOM_FN, "Clic dans une pièce : elle prend la fonction choisie à droite."],
			["Retirer", Mobilier.Tool.ERASE, "Clic sur un meuble, ou glissé : tout un rectangle (50 % remboursés)."]]:
		var b := Button.new()
		b.text = t[0]
		b.tooltip_text = t[2]
		b.toggle_mode = true
		b.button_group = group
		var tid: Mobilier.Tool = t[1]
		b.pressed.connect(func() -> void: _tool(tid))
		trow.add_child(b)
	var fn_opt := OptionButton.new()
	fn_opt.tooltip_text = "Fonction donnée par l'outil Fonction"
	for f in Meubles.PIECE_ORDER + ["studio"]:
		fn_opt.add_item(Mobilier.fn_name(String(f)))
		fn_opt.set_item_metadata(fn_opt.item_count - 1, f)
		if String(f) == mob.room_fn:
			fn_opt.select(fn_opt.item_count - 1)
	fn_opt.item_selected.connect(func(i: int) -> void:
		mob.set_room_fn(String(fn_opt.get_item_metadata(i)))
		if mob.tool != Mobilier.Tool.ROOM_FN:
			_tool(Mobilier.Tool.ROOM_FN))
	trow.add_child(fn_opt)
	bp.add_control(trow)
	var lrow := HBoxContainer.new()
	var down := Button.new()
	down.text = "▼"
	down.tooltip_text = "Étage du dessous (Page bas)"
	down.pressed.connect(func() -> void: mob.pe.step_level(-1))
	lrow.add_child(down)
	_level = Label.new()
	_level.text = PlanEditor.level_name(mob.pe.level)
	_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_level.clip_text = true
	lrow.add_child(_level)
	var up := Button.new()
	up.text = "▲"
	up.tooltip_text = "Étage du dessus (Page haut)"
	up.pressed.connect(func() -> void: mob.pe.step_level(1))
	lrow.add_child(up)
	bp.add_control(lrow)
	# --- Bâtiments meublés ------------------------------------------------------------
	bp.add_control(_title("Bâtiments meublés, prêts à visiter (V)"))
	var grow := HFlowContainer.new()
	for k in Gabarits.ORDER:
		var g: Dictionary = Gabarits.KINDS[k]
		var gb := Button.new()
		gb.text = String(g.name)
		gb.tooltip_text = "%s\n%d × %d m · environ %s avec les meubles" % [g.desc, int(g.w), int(g.d), BuildingSystem.format_money(int(g.budget))]
		gb.toggle_mode = true
		gb.button_group = group
		gb.add_theme_font_size_override("font_size", 12)
		var kk: String = k
		gb.pressed.connect(func() -> void:
			if prepare.is_valid():
				prepare.call()
			mob.set_template(kk)
			if mob.tool != Mobilier.Tool.TEMPLATE:
				mob.set_tool(Mobilier.Tool.TEMPLATE))
		grow.add_child(gb)
	bp.add_control(grow)
	# --- Catalogue ----------------------------------------------------------------------
	bp.add_control(_title("Catalogue : %d meubles et objets du monde entier" % Meubles.count()))
	var frow := HFlowContainer.new()
	var cat_opt := OptionButton.new()
	cat_opt.add_item("Toutes les pièces")
	cat_opt.set_item_metadata(0, "")
	for c in Meubles.CATEGORIES:
		cat_opt.add_item(Meubles.piece_name(String(c)))
		cat_opt.set_item_metadata(cat_opt.item_count - 1, c)
		if String(c) == _cat:
			cat_opt.select(cat_opt.item_count - 1)
	cat_opt.item_selected.connect(func(i: int) -> void:
		_cat = String(cat_opt.get_item_metadata(i))
		bp.show_category("interieur"))
	frow.add_child(cat_opt)
	var sf := _style_option(true)
	sf.item_selected.connect(func(i: int) -> void:
		_style_filter = String(sf.get_item_metadata(i))
		bp.show_category("interieur"))
	frow.add_child(sf)
	var search := LineEdit.new()
	search.placeholder_text = "Chercher un meuble…"
	search.custom_minimum_size = Vector2(160, 0)
	search.clear_button_enabled = true
	search.text = _search
	search.text_submitted.connect(func(txt: String) -> void:
		_search = txt.strip_edges()
		bp.show_category("interieur"))
	search.focus_exited.connect(func() -> void:
		if search.text.strip_edges() != _search:
			_search = search.text.strip_edges()
			bp.show_category.call_deferred("interieur"))
	frow.add_child(search)
	bp.add_control(frow)
	var ids := Meubles.filtered(_cat, _style_filter, "", "", _search)
	var shown := 0
	for id in ids:
		if shown >= MAX_SHOWN:
			break
		var e := Meubles.get_entry(String(id))
		var b2 := Button.new()
		b2.text = "%s · %s" % [e.name, Meubles.style_of(String(e.style)).name]
		b2.tooltip_text = "%s\n%s · %s, %s\n%d × %d m%s" % [e.name, Meubles.describe(String(id)), Styles.region_name(String(e.region)),
			Styles.era_name(String(e.era)).to_lower(), int(e.w), int(e.d), "" if String(e.couche) == "meuble" else (" · se pose au sol, sous les meubles" if String(e.couche) == "sol" else " · s'accroche au mur")]
		b2.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b2.toggle_mode = true
		b2.button_group = group
		b2.clip_text = true
		b2.add_theme_font_size_override("font_size", 12)
		b2.custom_minimum_size = Vector2(0, 26)
		var mid := String(id)
		b2.pressed.connect(func() -> void:
			if prepare.is_valid():
				prepare.call()
			mob.set_meuble(mid)
			if mob.tool != Mobilier.Tool.PLACE:
				mob.set_tool(Mobilier.Tool.PLACE))
		bp.add_control(b2)
		shown += 1
	if ids.size() > shown:
		bp.add_control(_label("… et %d autres : choisis une pièce, un style ou cherche un nom." % (ids.size() - shown), 12, true))
	elif ids.is_empty():
		bp.add_control(_label("Aucun meuble pour ces filtres.", 12, true))
	bp.add_control(_label(mob.summary(), 11, true))
	_refresh_stats()


func _style_option(with_all: bool) -> OptionButton:
	var o := OptionButton.new()
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	o.fit_to_longest_item = false
	o.clip_text = true
	o.custom_minimum_size = Vector2(170, 0)
	o.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if with_all:
		o.add_item("Tous les styles")
		o.set_item_metadata(0, "")
	for r in Styles.REGIONS:
		for sid in Meubles.STYLES:
			var s: Dictionary = Meubles.STYLES[sid]
			if String(s.region) != String(r.id):
				continue
			o.add_item("%s (%s, %s)" % [s.name, r.name, Styles.era_name(String(s.era)).to_lower()])
			o.set_item_metadata(o.item_count - 1, sid)
			var cur := _style_filter if with_all else mob.style
			if String(sid) == cur:
				o.select(o.item_count - 1)
	return o


func _refresh_stats() -> void:
	if not is_instance_valid(_stats):
		return
	var id := mob.focus_id()
	_stats.text = mob.describe_plan(id)
	if is_instance_valid(_usage_opt) and id != "":
		var u := mob.usage_of(id)
		for i in _usage_opt.item_count:
			if String(_usage_opt.get_item_metadata(i)) == u:
				_usage_opt.select(i)
