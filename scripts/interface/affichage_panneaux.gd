class_name AffichagePanneaux
extends CanvasLayer
## Fermer et réafficher les cartes d'information de l'écran de jeu (objectifs,
## habitant suivi, fil des habitants, « À faire », carte de la case, jauges…).
## La barre du haut et la barre du bas ne se ferment jamais.
## - Chaque carte reçoit une petite croix ronde dans son coin haut-droit.
## - Le bouton « œil » de la barre du haut ouvre le menu Affichage : une vignette
##   par carte (allumée = visible), « Tout afficher » et « Tout masquer ».
##   Une pastille sur l'œil compte les cartes masquées.
## - Ctrl+H : tout masquer, puis tout réafficher comme avant.
## Le choix est gardé d'une partie à l'autre (user://interface.cfg, section
## « affichage »), comme une option du joueur.
## Une carte masquée l'est même si son propre code la remontre : on la recache à
## chaque image (process_priority élevé, donc après les autres). En la réaffichant,
## `restaurer` recalcule sa vraie visibilité.

signal change

const CFG := "user://interface.cfg"
const BADGE := 22.0

## Tout ce qui peut se fermer : {id, nom, icone, aide, carte: Callable -> Control,
## restaurer: Callable}. Dans l'ordre du menu.
var panneaux: Array = []
## Ids masqués par le joueur.
var masques := {}
## Ce qui était masqué avant « tout masquer » (Ctrl+H le rend).
var _avant_tout: Array = []
## Persistance (désactivée dans les tests).
static var persist := true

var _badges := {}
var _menu: PanelContainer
## Le menu passe au-dessus de tout (bulles du tutoriel, recherche) : son propre calque.
var _calque_menu: CanvasLayer
var _tuiles := {}
## Bouton de la barre du haut (posé par TerreHud) et sa pastille.
var bouton: Button
var _compte: Label


func _init() -> void:
	layer = 7
	process_priority = 1000
	name = "AffichagePanneaux"


func _ready() -> void:
	_charger()


## Ajoute une carte que le joueur peut fermer.
func ajouter(id: String, nom: String, icone: String, aide: String, carte: Callable, restaurer := Callable()) -> void:
	panneaux.append({"id": id, "nom": nom, "icone": icone, "aide": aide, "carte": carte, "restaurer": restaurer})
	var b := Button.new()
	b.name = "Fermer_" + id
	b.icon = Icones.get_icon("fermer", 12, UiStyle.TEXT)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size = Vector2(BADGE, BADGE)
	b.size = Vector2(BADGE, BADGE)
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = "Fermer « %s » (œil en haut ou Ctrl+H pour la réafficher)" % nom
	var fond := UiStyle.flat_box(Color(0.10, 0.12, 0.11, 0.92), int(BADGE * 0.5), 0)
	fond.border_color = Color(1, 1, 1, 0.35)
	fond.set_border_width_all(1)
	b.add_theme_stylebox_override("normal", fond)
	var survol := fond.duplicate() as StyleBoxFlat
	survol.bg_color = Color("c0392b")
	survol.border_color = Color.WHITE
	b.add_theme_stylebox_override("hover", survol)
	b.add_theme_stylebox_override("pressed", survol)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.modulate.a = 0.8
	b.visible = false
	b.pressed.connect(func() -> void: masquer(id, true))
	add_child(b)
	_badges[id] = b
	if _menu != null:
		_construire_menu()
	if masques.has(id):
		_cacher(id)


func ids() -> Array:
	return panneaux.map(func(p: Dictionary) -> String: return String(p.id))


func est_masque(id: String) -> bool:
	return masques.has(id)


func nb_masques() -> int:
	var n := 0
	for p in panneaux:
		if masques.has(String(p.id)):
			n += 1
	return n


func carte(id: String) -> Control:
	for p in panneaux:
		if String(p.id) == id:
			var c: Variant = (p.carte as Callable).call()
			return c as Control if c is Control and is_instance_valid(c) else null
	return null


## Masque (on = true) ou réaffiche une carte.
func masquer(id: String, on: bool) -> void:
	if on == masques.has(id):
		return
	if on:
		masques[id] = true
		_cacher(id)
	else:
		masques.erase(id)
		for p in panneaux:
			if String(p.id) == id and (p.restaurer as Callable).is_valid():
				(p.restaurer as Callable).call()
	_apres_changement()


func tout_masquer() -> void:
	var avant := masques.keys()
	for id in ids():
		if not masques.has(id):
			masques[id] = true
			_cacher(id)
	_avant_tout = avant
	_apres_changement()


func tout_afficher() -> void:
	for id in masques.keys():
		masquer(String(id), false)
	_apres_changement()


## Ctrl+H : tout masquer ; encore une fois, revenir à ce qui était visible avant.
func basculer_tout() -> void:
	if nb_masques() >= panneaux.size():
		var garder := _avant_tout.duplicate()
		for id in ids():
			if not garder.has(id):
				masquer(id, false)
		_avant_tout = []
	else:
		tout_masquer()
	_apres_changement()


func _cacher(id: String) -> void:
	var c := carte(id)
	if c != null:
		c.visible = false


func _apres_changement() -> void:
	_sauver()
	_maj_tuiles()
	_maj_compte()
	change.emit()


func _process(_delta: float) -> void:
	for p in panneaux:
		var id := String(p.id)
		var c := carte(id)
		var b: Button = _badges[id]
		if masques.has(id):
			# Le code de la carte a pu la remontrer : elle reste fermée.
			if c != null and c.visible:
				c.visible = false
			b.visible = false
			continue
		var montre := c != null and c.is_visible_in_tree() and c.size.y > 4.0
		b.visible = montre
		if montre:
			var r := c.get_global_rect()
			b.position = Vector2(r.end.x - BADGE * 0.6, r.position.y - BADGE * 0.4)


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode == KEY_H and (k.ctrl_pressed or k.meta_pressed) and not k.shift_pressed and not k.alt_pressed:
		get_viewport().set_input_as_handled()
		basculer_tout()
	elif k.keycode == KEY_ESCAPE and menu_ouvert():
		get_viewport().set_input_as_handled()
		set_menu(false)


# --- Bouton de la barre du haut et menu en vignettes ------------------------------

## Bouton « œil » à poser dans la barre du haut, avec sa pastille (nombre de cartes masquées).
func faire_bouton() -> Button:
	bouton = UiStyle.icon_button("oeil", "Affichage : fermer ou réafficher les cartes d'information", "Ctrl+H")
	bouton.name = "Affichage"
	bouton.toggle_mode = true
	bouton.toggled.connect(set_menu)
	_compte = UiStyle.key_label("0")
	_compte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_compte.add_theme_color_override("font_color", Color.WHITE)
	var sb := UiStyle.flat_box(Color("c0392b"), 7, 0)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	_compte.add_theme_stylebox_override("normal", sb)
	_compte.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_compte.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_compte.offset_right = 2
	_compte.offset_top = -2
	bouton.add_child(_compte)
	_maj_compte()
	return bouton


func menu_ouvert() -> bool:
	return _menu != null and _menu.visible


func set_menu(on: bool) -> void:
	if on and _menu == null:
		_construire_menu()
	if _menu != null:
		_menu.visible = on
		if on:
			_maj_tuiles()
			_placer_menu.call_deferred()
	if bouton != null:
		bouton.set_pressed_no_signal(on)


func _construire_menu() -> void:
	if _menu == null:
		_menu = PanelContainer.new()
		_menu.name = "MenuAffichage"
		UiStyle.style_panel(_menu, 0.95, 12, 12)
		_menu.visible = false
		_calque_menu = CanvasLayer.new()
		_calque_menu.name = "CalqueMenuAffichage"
		_calque_menu.layer = 45
		add_child(_calque_menu)
		_calque_menu.add_child(_menu)
	for ch in _menu.get_children():
		_menu.remove_child(ch)
		ch.queue_free()
	_tuiles.clear()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_menu.add_child(col)
	var tete := HBoxContainer.new()
	col.add_child(tete)
	var titre := Label.new()
	titre.text = "Affichage"
	titre.add_theme_font_size_override("font_size", 16)
	titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tete.add_child(titre)
	var fermer := UiStyle.icon_button("fermer", "Fermer ce menu", "Échap", 16, 28)
	fermer.pressed.connect(func() -> void: set_menu(false))
	tete.add_child(fermer)
	var aide := Label.new()
	aide.text = "Allumé = visible. Clic pour fermer ou réafficher une carte."
	aide.add_theme_font_size_override("font_size", 12)
	aide.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	col.add_child(aide)
	var grille := GridContainer.new()
	grille.columns = 4
	grille.add_theme_constant_override("h_separation", 6)
	grille.add_theme_constant_override("v_separation", 6)
	col.add_child(grille)
	for p in panneaux:
		var id := String(p.id)
		var t := UiStyle.tile_button(String(p.icone), String(p.nom), "", Vector2(104, 78), 28)
		t.name = "Tuile_" + id
		t.toggle_mode = true
		t.tooltip_text = String(p.aide)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.add_theme_font_size_override("font_size", 12)
		t.toggled.connect(func(on: bool) -> void: masquer(id, not on))
		grille.add_child(t)
		_tuiles[id] = t
	col.add_child(HSeparator.new())
	var bas := HBoxContainer.new()
	bas.add_theme_constant_override("separation", 6)
	col.add_child(bas)
	var tout := UiStyle.tile_button("oeil", "Tout afficher", "", Vector2(160, 60), 24)
	tout.name = "ToutAfficher"
	tout.pressed.connect(tout_afficher)
	bas.add_child(tout)
	var rien := UiStyle.tile_button("fermer", "Tout masquer", "Ctrl+H", Vector2(160, 60), 24)
	rien.name = "ToutMasquer"
	rien.pressed.connect(tout_masquer)
	bas.add_child(rien)
	_maj_tuiles()


## Sous le bouton œil, sans sortir de l'écran.
func _placer_menu() -> void:
	if _menu == null:
		return
	_menu.reset_size()
	var vue := _menu.get_viewport_rect().size
	var x := 10.0
	var y := UiStyle.SIDE_TOP
	if bouton != null and bouton.is_inside_tree():
		var r := bouton.get_global_rect()
		x = r.position.x + r.size.x * 0.5 - _menu.size.x * 0.5
		y = r.end.y + 12.0
	_menu.position = Vector2(clampf(x, 10.0, maxf(10.0, vue.x - _menu.size.x - 10.0)), y)


func _maj_tuiles() -> void:
	for id in _tuiles:
		(_tuiles[id] as Button).set_pressed_no_signal(not masques.has(id))


func _maj_compte() -> void:
	if _compte == null:
		return
	var n := nb_masques()
	_compte.text = str(n)
	_compte.visible = n > 0
	if bouton != null:
		bouton.tooltip_text = "Affichage : fermer ou réafficher les cartes d'information (Ctrl+H)" + \
			("" if n == 0 else "\n%d carte%s masquée%s : clic pour les revoir" % [n, "s" if n > 1 else "", "s" if n > 1 else ""])


# --- Option gardée d'une partie à l'autre ---------------------------------------------

func _charger() -> void:
	if not persist:
		return
	var cfg := ConfigFile.new()
	if cfg.load(CFG) != OK:
		return
	for id in cfg.get_value("affichage", "masques", []):
		masques[String(id)] = true
	_avant_tout = cfg.get_value("affichage", "avant_tout", [])
	for id in masques:
		_cacher(String(id))
	_maj_compte()


func _sauver() -> void:
	if not persist:
		return
	var cfg := ConfigFile.new()
	cfg.load(CFG)
	cfg.set_value("affichage", "masques", masques.keys())
	cfg.set_value("affichage", "avant_tout", _avant_tout)
	cfg.save(CFG)
