class_name Son
extends Node
## Son et musique de MiniBlocs (nœud /root/Son, créé à la demande).
##
## - Bus audio : Musique, Effets, Ambiance, Interface (sous Master).
## - Volumes et options du joueur : user://son.cfg (préférences du joueur, pas
##   de la partie : elles valent pour toutes les parties et le globe).
## - Sons ponctuels : Son.jouer("argent"), Son.jouer_a("chantier_fini", pos).
## - Musique : liste de lecture selon l'humeur (menu, jour, soir, nuit), fondu
##   entre deux morceaux, pauses de silence entre les morceaux (réglable).
## - Clic des boutons : tous les boutons du jeu font un petit « tic ».
## Les sons sont fabriqués par tools/build_sons.py (synthèse maison, CC0).

signal morceau_change(titre: String)
signal volumes_changes

const DOSSIER := "res://assets/son/"
const CONFIG := "user://son.cfg"
const BUS := ["Musique", "Effets", "Ambiance", "Interface"]

## id -> [titre, humeur]. Humeurs : menu (globe), jour, soir, nuit.
const MORCEAUX := {
	"une_terre_a_batir": ["Une Terre à bâtir", "menu"],
	"premier_coup_de_pioche": ["Premier coup de pioche", "jour"],
	"valse_du_permis_de_construire": ["Valse du permis de construire", "jour"],
	"conseil_municipal_en_retard": ["Conseil municipal (en retard)", "jour"],
	"nids_de_poule_blues": ["Nids-de-poule blues", "soir"],
	"lampadaires": ["Lampadaires", "nuit"],
	"heure_creuse": ["Heure creuse", "nuit"],
}
## Humeurs acceptées par chaque moment (le soir mélange jour et nuit).
const HUMEURS := {
	"menu": ["menu"],
	"jour": ["jour", "soir"],
	"soir": ["soir", "jour", "nuit"],
	"nuit": ["nuit", "soir"],
}

static var _inst: Son
## Cache des flux : chemin -> AudioStream.
static var _flux := {}

## Volumes 0..1 : general, musique, effets, ambiance, interface.
var volumes := {"general": 0.8, "musique": 0.55, "effets": 0.8, "ambiance": 0.7, "interface": 0.6}
var pauses_musique := true
var couper_hors_focus := true
## Morceaux que le joueur a retirés de la liste.
var exclus: Array = []
## Fonction qui donne l'humeur du moment (posée par la scène Terre).
var humeur_fn := Callable()

var _pool: Array[AudioStreamPlayer] = []
var _ui_pool: Array[AudioStreamPlayer] = []
var _derniers := {}
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_cur: AudioStreamPlayer
var _fondu := 0.0
var morceau := ""
var _attente := 2.0
var _historique: Array = []
var _humeur_jouee := ""
var _hors_focus := false
var _rng := RandomNumberGenerator.new()


# --- Accès ---------------------------------------------------------------------

## Le nœud Son (créé et accroché à la racine au premier appel).
static func ici() -> Son:
	if _inst != null and is_instance_valid(_inst):
		return _inst
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var n := tree.root.get_node_or_null("Son") as Son
	if n == null:
		n = Son.new()
		n.name = "Son"
		tree.root.add_child.call_deferred(n)
	_inst = n
	return n


## Joue un son ponctuel (effets/<id>.ogg). db : volume relatif, hauteur : variation au hasard.
static func jouer(id: String, db := 0.0, hauteur := 0.0, bus := "Effets") -> void:
	var s := ici()
	if s != null and s.is_inside_tree():
		s._jouer(id, db, hauteur, bus)


## Joue un son ponctuel à un endroit du monde 3D (s'entend selon la distance).
static func jouer_a(id: String, pos: Vector3, db := 0.0, portee := 400.0) -> void:
	var s := ici()
	if s != null and s.is_inside_tree():
		s._jouer_a(id, pos, db, portee)


## Flux audio d'un fichier du dossier son (« effets/argent », « ambiance/pluie »…).
static func flux(chemin: String, boucle := false) -> AudioStream:
	var path := DOSSIER + chemin + ".ogg"
	if _flux.has(path):
		return _flux[path]
	var st: AudioStream = null
	if ResourceLoader.exists(path):
		st = load(path) as AudioStream
	if st == null and FileAccess.file_exists(path):
		# Pas encore importé (tests sans éditeur) : lecture directe du fichier.
		st = AudioStreamOggVorbis.load_from_file(path)
	if st is AudioStreamOggVorbis:
		if boucle:
			st = (st as AudioStreamOggVorbis).duplicate()
		(st as AudioStreamOggVorbis).loop = boucle
	_flux[path] = st
	return st


# --- Vie du nœud -----------------------------------------------------------------

func _ready() -> void:
	_inst = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_creer_bus()
	charger_reglages()
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = "Effets"
		add_child(p)
		_pool.append(p)
	for i in 4:
		var p := AudioStreamPlayer.new()
		p.bus = "Interface"
		add_child(p)
		_ui_pool.append(p)
	_music_a = AudioStreamPlayer.new()
	_music_b = AudioStreamPlayer.new()
	for p in [_music_a, _music_b]:
		p.bus = "Musique"
		p.volume_db = -80.0
		add_child(p)
		p.finished.connect(_on_fini.bind(p))
	get_tree().node_added.connect(_on_node_added)
	_brancher_boutons(get_tree().root)


func _creer_bus() -> void:
	for b in BUS:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
	appliquer_volumes()


## Applique les volumes aux bus (courbe en carré : plus naturelle à l'oreille).
func appliquer_volumes() -> void:
	var g := float(volumes.general)
	if _hors_focus and couper_hors_focus:
		g = 0.0
	AudioServer.set_bus_volume_db(0, _db(g))
	AudioServer.set_bus_mute(0, g <= 0.001)
	for b in BUS:
		var i := AudioServer.get_bus_index(b)
		if i >= 0:
			var v := float(volumes.get(b.to_lower(), 1.0))
			AudioServer.set_bus_volume_db(i, _db(v))
			AudioServer.set_bus_mute(i, v <= 0.001)


static func _db(v: float) -> float:
	return -80.0 if v <= 0.001 else linear_to_db(v * v)


func set_volume(id: String, v: float) -> void:
	volumes[id] = clampf(v, 0.0, 1.0)
	appliquer_volumes()
	volumes_changes.emit()
	sauver_reglages()


func charger_reglages() -> void:
	var cf := ConfigFile.new()
	if cf.load(CONFIG) != OK:
		return
	for k in volumes.keys():
		volumes[k] = clampf(float(cf.get_value("volumes", k, volumes[k])), 0.0, 1.0)
	pauses_musique = bool(cf.get_value("musique", "pauses", pauses_musique))
	couper_hors_focus = bool(cf.get_value("options", "couper_hors_focus", couper_hors_focus))
	exclus = Array(cf.get_value("musique", "exclus", []))
	appliquer_volumes()


func sauver_reglages() -> void:
	var cf := ConfigFile.new()
	for k in volumes:
		cf.set_value("volumes", k, snappedf(float(volumes[k]), 0.01))
	cf.set_value("musique", "pauses", pauses_musique)
	cf.set_value("musique", "exclus", exclus)
	cf.set_value("options", "couper_hors_focus", couper_hors_focus)
	cf.save(CONFIG)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_hors_focus = true
		appliquer_volumes()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_hors_focus = false
		appliquer_volumes()


# --- Sons ponctuels ---------------------------------------------------------------

func _jouer(id: String, db: float, hauteur: float, bus: String) -> void:
	# Le même son deux fois en moins de 80 ms : un seul.
	var now := Time.get_ticks_msec()
	if now - int(_derniers.get(id, -1000)) < 80:
		return
	_derniers[id] = now
	var st := flux("effets/" + id)
	if st == null:
		return
	var pool := _ui_pool if bus == "Interface" else _pool
	var p: AudioStreamPlayer = null
	for q in pool:
		if not q.playing:
			p = q
			break
	if p == null:
		p = pool[0]
		pool.push_back(pool.pop_front())
	p.stream = st
	p.bus = bus
	p.volume_db = db
	p.pitch_scale = 1.0 + (_rng.randf_range(-hauteur, hauteur) if hauteur > 0.0 else 0.0)
	p.play()


func _jouer_a(id: String, pos: Vector3, db: float, portee: float) -> void:
	var now := Time.get_ticks_msec()
	if now - int(_derniers.get(id, -1000)) < 80:
		return
	_derniers[id] = now
	var st := flux("effets/" + id)
	var scene := get_tree().current_scene
	if st == null or scene == null or not (scene is Node3D):
		return
	var cam := get_viewport().get_camera_3d()
	if cam != null and cam.global_position.distance_to(pos) > portee:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = st
	p.bus = "Effets"
	p.volume_db = db
	p.unit_size = 40.0
	p.max_distance = portee
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	scene.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()


# --- Panneau ---------------------------------------------------------------------

var _panneau: SonPanel


## Ouvre ou ferme le panneau Son et musique (F2).
static func panneau() -> void:
	var s := ici()
	if s == null or not s.is_inside_tree():
		return
	if s._panneau != null and is_instance_valid(s._panneau):
		s._panneau.close_panel()
		return
	s._panneau = SonPanel.new()
	s._panneau.closed.connect(func() -> void: s._panneau = null)
	s.add_child(s._panneau)


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.keycode == KEY_F2 and (_panneau == null or not is_instance_valid(_panneau)):
		get_viewport().set_input_as_handled()
		panneau()


# --- Clic des boutons --------------------------------------------------------------

func _on_node_added(n: Node) -> void:
	if n is BaseButton:
		_brancher(n as BaseButton)


func _brancher_boutons(n: Node) -> void:
	if n is BaseButton:
		_brancher(n as BaseButton)
	for c in n.get_children():
		_brancher_boutons(c)


func _brancher(b: BaseButton) -> void:
	if b.has_meta("son_branche") or b.has_meta("sans_clic"):
		return
	b.set_meta("son_branche", true)
	b.pressed.connect(func() -> void: _jouer("ui_clic", -4.0, 0.06, "Interface"))


# --- Musique -------------------------------------------------------------------------

func humeur() -> String:
	var scene := get_tree().current_scene
	if scene != null and scene.scene_file_path.contains("globe"):
		return "menu"
	if humeur_fn.is_valid() and is_instance_valid(humeur_fn.get_object()):
		return String(humeur_fn.call())
	return "jour"


## Morceaux possibles pour une humeur (ceux que le joueur n'a pas retirés).
func liste(h: String) -> Array:
	var ok: Array = HUMEURS.get(h, ["jour"])
	var out: Array = []
	for id in MORCEAUX:
		if not exclus.has(id) and ok.has(String(MORCEAUX[id][1])):
			out.append(id)
	return out


func titre(id: String) -> String:
	return String(MORCEAUX[id][0]) if MORCEAUX.has(id) else ""


## Lance un morceau (fondu de 3 s avec le précédent).
func lancer(id: String) -> void:
	var st := flux("musique/" + id)
	if st == null:
		return
	var nxt := _music_b if _music_cur == _music_a else _music_a
	nxt.stream = st
	nxt.volume_db = -40.0
	nxt.play()
	_music_cur = nxt
	_fondu = 3.0
	morceau = id
	_humeur_jouee = humeur()
	_historique.append(id)
	if _historique.size() > 4:
		_historique.pop_front()
	morceau_change.emit(titre(id))


## Morceau suivant (bouton du panneau Son).
func suivant() -> void:
	var h := humeur()
	var l := liste(h)
	if l.is_empty():
		l = liste("jour")
	if l.is_empty():
		arreter_musique()
		return
	var choix: Array = l.filter(func(x) -> bool: return not _historique.has(x))
	if choix.is_empty():
		choix = l.filter(func(x) -> bool: return x != morceau)
	if choix.is_empty():
		choix = l
	lancer(String(choix[_rng.randi() % choix.size()]))


func arreter_musique() -> void:
	morceau = ""
	_fondu = -3.0
	morceau_change.emit("")


func _on_fini(p: AudioStreamPlayer) -> void:
	if p != _music_cur:
		return
	morceau = ""
	morceau_change.emit("")
	_attente = _rng.randf_range(25.0, 90.0) if pauses_musique else 1.0


func _process(delta: float) -> void:
	# Fondus enchaînés.
	var other := _music_b if _music_cur == _music_a else _music_a
	if _music_cur != null:
		var target := 0.0 if morceau != "" else -80.0
		_music_cur.volume_db = move_toward(_music_cur.volume_db, target, delta * 14.0)
	if other != null and other.playing:
		other.volume_db = move_toward(other.volume_db, -80.0, delta * 20.0)
		if other.volume_db <= -79.0:
			other.stop()
	if _music_cur != null and morceau == "" and _music_cur.playing and _music_cur.volume_db <= -79.0:
		_music_cur.stop()
	# Changement de moment : du globe à la ville (ou l'inverse), on change tout de suite.
	var h := humeur()
	if morceau != "" and (h == "menu") != (_humeur_jouee == "menu"):
		suivant()
		return
	if morceau == "":
		_attente -= delta
		if _attente <= 0.0:
			_attente = 5.0
			suivant()
