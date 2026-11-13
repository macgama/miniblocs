class_name EcranChargement
extends CanvasLayer
## Écran de chargement entre deux scènes (menu → partie, partie → menu).
## Il se pose sur la racine (il survit au changement de scène), charge la scène
## en arrière-plan, la lance, puis attend que le relief autour de la caméra soit
## prêt avant de s'effacer en fondu. Des conseils (sérieux ou pas) défilent.
##
## Usage : EcranChargement.aller("res://scenes/terre.tscn", "Annecy")

const CONSEILS := [
	"Une route qui ne mène nulle part reste une route. Les habitants, eux, préfèrent qu'elle mène quelque part.",
	"Les chantiers avancent en semaine et en journée. Comme dans la vraie vie, mais sans la pause café de 40 minutes.",
	"F1 affiche toutes les commandes. Personne ne lit les notices, mais celle-ci est courte.",
	"Un village commence par une Maison de commune et 1 M€. Le reste, c'est de la paperasse.",
	"Les habitants jugent tes décisions sur le panneau Avis (Y). Ils ont toujours un avis. Toujours.",
	"Une sauvegarde automatique est faite toutes les 5 minutes s'il y a eu des changements (Options > Jeu).",
	"Tab passe en mode Créer : la ville se met en pause pendant que tu bâtis ta mairie de rêve.",
	"Le relief est le vrai relief de la Terre. Si ta ville glisse dans le lac, ce n'est pas un bug, c'est la géographie.",
	"Les poubelles qui débordent font baisser le moral. Les camions-bennes aussi, mais le matin seulement.",
	"Échap ouvre le menu pause : le temps s'arrête, les impôts aussi.",
	"Un échangeur se pose en un clic sur une route qui enjambe une autoroute. Les embouteillages, eux, viennent tout seuls.",
	"Perdre les élections ne t'empêche pas de construire. Tu ne choisis juste plus la couleur des bancs publics.",
	"Les pompiers prennent la route : une caserne mal reliée, c'est un incendie qui a le temps de s'installer.",
	"V passe en vue au sol. Admire ton œuvre de près, et les nids-de-poule aussi.",
]

const ETAPES := {
	"scene": "Chargement des plans de la ville…",
	"monde": "Mise en place des systèmes : habitants, réseaux, chantiers…",
	"relief": "Téléchargement et modelage du relief…",
	"pret": "Tout est prêt. Les habitants attendent leurs routes.",
}

## Temps maximum d'attente du relief (secondes) : au-delà on montre la partie quand même.
const ATTENTE_MAX := 25.0

static var actif: EcranChargement

var cible := ""
var titre := ""
var _fond: ColorRect
var _titre: Label
var _etape: Label
var _conseil: Label
var _barre: ProgressBar
var _rng := RandomNumberGenerator.new()
var _t_conseil := 0.0
var _progres := 0.0


## Lance le chargement d'une scène derrière l'écran de chargement.
static func aller(chemin: String, titre_partie := "") -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	if tree.paused:
		tree.paused = false
	if actif != null and is_instance_valid(actif):
		return
	var e := EcranChargement.new()
	e.cible = chemin
	e.titre = titre_partie
	tree.root.add_child(e)


func _ready() -> void:
	actif = self
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_construire()
	_lancer()


func _exit_tree() -> void:
	if actif == self:
		actif = null


func _construire() -> void:
	_fond = ColorRect.new()
	_fond.color = Color("13201a")
	_fond.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fond.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_fond)
	# Bandes de collines en facettes, dessinées une fois (pas de 3D pendant le chargement).
	var collines := Control.new()
	collines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	collines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	collines.draw.connect(func() -> void: _dessiner_collines(collines))
	collines.resized.connect(collines.queue_redraw)
	_fond.add_child(collines)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	v.custom_minimum_size = Vector2(720, 0)
	v.position -= Vector2(360, 120)
	v.add_theme_constant_override("separation", 14)
	_fond.add_child(v)
	var logo := Label.new()
	logo.text = "MiniBlocs"
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.add_theme_font_size_override("font_size", 52)
	logo.add_theme_color_override("font_color", UiStyle.ACCENT)
	logo.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	logo.add_theme_constant_override("shadow_offset_y", 3)
	v.add_child(logo)
	_titre = Label.new()
	_titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_titre.add_theme_font_size_override("font_size", 20)
	_titre.text = titre if titre != "" else "Chargement"
	v.add_child(_titre)
	_barre = ProgressBar.new()
	_barre.custom_minimum_size = Vector2(720, 14)
	_barre.show_percentage = false
	_barre.max_value = 1.0
	_barre.add_theme_stylebox_override("background", UiStyle.flat_box(Color(1, 1, 1, 0.08), 7, 0))
	_barre.add_theme_stylebox_override("fill", UiStyle.flat_box(UiStyle.ACCENT, 7, 0))
	v.add_child(_barre)
	_etape = Label.new()
	_etape.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_etape.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	v.add_child(_etape)
	_conseil = Label.new()
	_conseil.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_conseil.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_conseil.custom_minimum_size = Vector2(720, 60)
	_conseil.add_theme_font_size_override("font_size", 15)
	v.add_child(_conseil)
	_nouveau_conseil()


func _dessiner_collines(c: Control) -> void:
	var w := c.size.x
	var h := c.size.y
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var couleurs := [Color("1d3326"), Color("244030"), Color("2d4f36"), Color("365c3c")]
	for band in couleurs.size():
		var base := h * (0.62 + band * 0.1)
		var pts := PackedVector2Array([Vector2(0, h)])
		var x := 0.0
		while x <= w + 80.0:
			pts.append(Vector2(x, base - rng.randf_range(10.0, 70.0) * (1.0 - band * 0.18)))
			x += rng.randf_range(60.0, 140.0)
		pts.append(Vector2(w, h))
		c.draw_colored_polygon(pts, couleurs[band])


func _nouveau_conseil() -> void:
	_conseil.text = "Conseil : " + String(CONSEILS[_rng.randi() % CONSEILS.size()])
	_t_conseil = 0.0


func _set_etape(id: String, p: float) -> void:
	_etape.text = String(ETAPES.get(id, id))
	_progres = maxf(_progres, p)


func _process(delta: float) -> void:
	_barre.value = lerpf(_barre.value, _progres, minf(delta * 6.0, 1.0))
	_t_conseil += delta
	if _t_conseil > 6.0:
		_nouveau_conseil()


func _lancer() -> void:
	_set_etape("scene", 0.05)
	# Deux images pour que l'écran soit affiché avant le gros du travail.
	await get_tree().process_frame
	await get_tree().process_frame
	var packed: PackedScene = null
	if ResourceLoader.load_threaded_request(cible) == OK:
		while true:
			var prog := []
			var st := ResourceLoader.load_threaded_get_status(cible, prog)
			if st == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				_progres = maxf(_progres, 0.05 + 0.25 * float(prog[0] if not prog.is_empty() else 0.0))
				await get_tree().process_frame
				continue
			if st == ResourceLoader.THREAD_LOAD_LOADED:
				packed = ResourceLoader.load_threaded_get(cible) as PackedScene
			break
	if packed == null:
		packed = load(cible) as PackedScene
	if packed == null:
		_etape.text = "Impossible d'ouvrir %s." % cible
		await get_tree().create_timer(2.0).timeout
		queue_free()
		return
	_set_etape("monde", 0.35)
	await get_tree().process_frame
	get_tree().change_scene_to_packed(packed)
	# Le _ready de la scène tourne pendant l'image suivante.
	await get_tree().process_frame
	await get_tree().process_frame
	await _attendre_relief()
	_set_etape("pret", 1.0)
	await get_tree().create_timer(0.35).timeout
	var tw := create_tween()
	tw.tween_property(_fond, "modulate:a", 0.0, 0.45)
	await tw.finished
	queue_free()


## Attend que les blocs de relief proches de la caméra soient calculés (scène Terre).
func _attendre_relief() -> void:
	var scene := get_tree().current_scene
	var world: Node = scene.get("world") if scene != null else null
	if world == null or not (world is TerrainWorld):
		return
	var tw := world as TerrainWorld
	_set_etape("relief", 0.45)
	var t0 := Time.get_ticks_msec()
	var calmes := 0
	while (Time.get_ticks_msec() - t0) / 1000.0 < ATTENTE_MAX:
		await get_tree().process_frame
		var tuiles := tw.tiles.pending_count() if tw.tiles != null else 0
		var jobs := tw._jobs.size()
		var blocs := tw.chunks.size()
		_progres = maxf(_progres, minf(0.45 + 0.5 * (1.0 - exp(-blocs / 40.0)), 0.95))
		if tuiles > 0:
			_etape.text = "Téléchargement du relief : %d tuile%s en route…" % [tuiles, "s" if tuiles > 1 else ""]
		elif blocs > 0:
			_etape.text = "Modelage du relief : %d blocs de 64 m…" % blocs
		# Prêt : plus rien en attente pendant quelques images, avec des blocs posés.
		if tuiles == 0 and jobs == 0 and blocs > 0:
			calmes += 1
			if calmes > 8:
				return
		else:
			calmes = 0
