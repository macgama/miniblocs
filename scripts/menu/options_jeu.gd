class_name OptionsJeu
extends RefCounted
## Options du joueur, valables pour toutes les parties (pas des réglages de partie) :
## graphismes, sauvegarde automatique, langue. Fichier user://options.cfg.
## Les volumes sont dans user://son.cfg (le fichier du système de son), pour que
## le panneau Son (F2) et l'écran Options montrent toujours les mêmes valeurs.

const FICHIER := "user://options.cfg"
const FICHIER_SON := "user://son.cfg"

## Volumes (0..1), mêmes clés et mêmes valeurs par défaut que le système de son.
const VOLUMES := ["general", "musique", "effets", "ambiance", "interface"]
const VOLUMES_DEFAUT := {"general": 0.8, "musique": 0.55, "effets": 0.8, "ambiance": 0.7, "interface": 0.6}
const NOMS_VOLUMES := {"general": "Général", "musique": "Musique", "effets": "Effets", "ambiance": "Ambiances", "interface": "Interface"}

const AUTOSAVE_CHOIX := [0, 2, 5, 10, 15]
const FPS_CHOIX := [0, 30, 60, 120, 144]
const OMBRES_TAILLES := [1024, 2048, 4096]
const MSAA_CHOIX := [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X]
const LANGUES := [["fr", "Français"], ["en", "English (bientôt)"], ["de", "Deutsch (bientôt)"], ["es", "Español (bientôt)"]]

## 0 fenêtré, 1 plein écran (fenêtre sans bord), 2 plein écran exclusif.
static var fenetre := 0
static var vsync := true
## Images par seconde maximum (0 = sans limite).
static var fps_max := 0
## Résolution du rendu 3D (0,5 à 1,0) : l'interface reste nette.
static var echelle_3d := 1.0
## Qualité des ombres : 0 basse, 1 moyenne, 2 haute.
static var ombres := 1
## Anticrénelage : 0 aucun, 1 MSAA 2×, 2 MSAA 4×.
static var anticrenelage := 1
## Rendu poussé (heures dorées, occlusion, brume) : voir DayNight.rendu_pousse.
static var rendu_pousse := true
## Minutes entre deux sauvegardes automatiques (0 = jamais).
static var autosave_min := 5
static var langue := "fr"
## Réduire les mouvements de l'écran titre (caméra fixe).
static var titre_fixe := false

static var _charge := false


static func charger() -> void:
	_charge = true
	var cf := ConfigFile.new()
	if cf.load(FICHIER) != OK:
		return
	fenetre = clampi(int(cf.get_value("graphismes", "fenetre", fenetre)), 0, 2)
	vsync = bool(cf.get_value("graphismes", "vsync", vsync))
	fps_max = int(cf.get_value("graphismes", "fps_max", fps_max))
	echelle_3d = clampf(float(cf.get_value("graphismes", "echelle_3d", echelle_3d)), 0.5, 1.0)
	ombres = clampi(int(cf.get_value("graphismes", "ombres", ombres)), 0, 2)
	anticrenelage = clampi(int(cf.get_value("graphismes", "anticrenelage", anticrenelage)), 0, 2)
	rendu_pousse = bool(cf.get_value("graphismes", "rendu_pousse", rendu_pousse))
	autosave_min = int(cf.get_value("jeu", "autosave_min", autosave_min))
	if not AUTOSAVE_CHOIX.has(autosave_min):
		autosave_min = 5
	langue = String(cf.get_value("jeu", "langue", langue))
	titre_fixe = bool(cf.get_value("jeu", "titre_fixe", titre_fixe))


static func sauver() -> void:
	var cf := ConfigFile.new()
	cf.set_value("graphismes", "fenetre", fenetre)
	cf.set_value("graphismes", "vsync", vsync)
	cf.set_value("graphismes", "fps_max", fps_max)
	cf.set_value("graphismes", "echelle_3d", snappedf(echelle_3d, 0.05))
	cf.set_value("graphismes", "ombres", ombres)
	cf.set_value("graphismes", "anticrenelage", anticrenelage)
	cf.set_value("graphismes", "rendu_pousse", rendu_pousse)
	cf.set_value("jeu", "autosave_min", autosave_min)
	cf.set_value("jeu", "langue", langue)
	cf.set_value("jeu", "titre_fixe", titre_fixe)
	cf.save(FICHIER)


## Charge (la première fois) et applique les options graphiques à la fenêtre.
static func appliquer(tree: SceneTree = null) -> void:
	if not _charge:
		charger()
	if tree == null:
		tree = Engine.get_main_loop() as SceneTree
	DayNight.rendu_pousse = rendu_pousse
	TranslationServer.set_locale(langue)
	Engine.max_fps = fps_max
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_WINDOWED
	if fenetre == 1:
		mode = DisplayServer.WINDOW_MODE_FULLSCREEN
	elif fenetre == 2:
		mode = DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if DisplayServer.window_get_mode() != mode and not (mode == DisplayServer.WINDOW_MODE_WINDOWED and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED):
		DisplayServer.window_set_mode(mode)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	if tree != null:
		var vp := tree.root
		vp.scaling_3d_scale = echelle_3d
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if echelle_3d < 0.99 else Viewport.SCALING_3D_MODE_BILINEAR
		vp.msaa_3d = MSAA_CHOIX[anticrenelage]
	RenderingServer.directional_shadow_atlas_set_size(OMBRES_TAILLES[ombres], true)
	RenderingServer.directional_soft_shadow_filter_set_quality(
		[RenderingServer.SHADOW_QUALITY_HARD, RenderingServer.SHADOW_QUALITY_SOFT_LOW, RenderingServer.SHADOW_QUALITY_SOFT_HIGH][ombres])


# --- Volumes (user://son.cfg) -------------------------------------------------------

static func volume(id: String) -> float:
	var s := _son()
	if s != null:
		return float(s.get("volumes").get(id, VOLUMES_DEFAUT.get(id, 1.0)))
	var cf := ConfigFile.new()
	cf.load(FICHIER_SON)
	return clampf(float(cf.get_value("volumes", id, VOLUMES_DEFAUT.get(id, 1.0))), 0.0, 1.0)


## Change un volume : par le système de son s'il tourne, sinon directement dans
## son fichier et sur le bus audio du même nom (s'il existe).
static func set_volume(id: String, v: float) -> void:
	v = clampf(v, 0.0, 1.0)
	var s := _son()
	if s != null and s.has_method("set_volume"):
		s.call("set_volume", id, v)
		if s.has_method("sauver_reglages"):
			s.call("sauver_reglages")
		return
	var cf := ConfigFile.new()
	cf.load(FICHIER_SON)
	cf.set_value("volumes", id, snappedf(v, 0.01))
	cf.save(FICHIER_SON)
	var bus := 0 if id == "general" else AudioServer.get_bus_index(String(id).capitalize())
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(v * v, 0.0001)))
		AudioServer.set_bus_mute(bus, v <= 0.001)


## Le nœud du système de son (/root/Son), s'il existe.
static func _son() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	var n := tree.root.get_node_or_null("Son")
	return n if n != null and n.get("volumes") is Dictionary else null


## Lance la musique d'une humeur si le système de son est présent (sinon rien).
static func musique(humeur: String) -> void:
	for c in ProjectSettings.get_global_class_list():
		if String(c.get("class", "")) == "Son":
			var script: Script = load(String(c.path))
			if script != null and script.has_method("ici"):
				var s: Node = script.call("ici")
				if s != null and humeur != "":
					s.set("humeur_fn", func() -> String: return humeur)
			return
