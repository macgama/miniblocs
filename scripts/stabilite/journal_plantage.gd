class_name JournalPlantage
extends Node
## Rapport de plantage local (autoload « Plantages »). Rien n'est envoyé en ligne :
## tout reste dans le dossier du jeu, user://plantages/.
##
## Pendant la partie, une « marque de session » (session_en_cours.json) est
## réécrite toutes les 15 secondes avec l'état du jeu (scène, partie, date de
## jeu, habitants, mémoire, images par seconde) et les dernières erreurs de
## script, avec leur pile d'appels. Quand le jeu se ferme normalement, la marque
## est effacée. Si elle est encore là au lancement suivant, le jeu s'est arrêté
## brutalement (plantage du moteur, manque de mémoire, jeu tué par Windows ou
## gel) : un rapport lisible plantage-AAAAMMJJ-HHMMSS.txt est écrit avec cet
## état, les erreurs et la fin du journal du moteur (user://logs/), puis le menu
## principal le signale et propose de reprendre la dernière sauvegarde
## automatique.
##
## Une sentinelle (fil à part) note aussi quand le jeu ne répond plus depuis
## plus de 30 secondes : le rapport dira « gel » plutôt que « plantage ».
##
## Sous Windows : %APPDATA%\Godot\app_userdata\MiniBlocs\plantages
## (ou %APPDATA%\MiniBlocs\plantages pour le jeu exporté).

const DIR := "user://plantages"
const MARQUE := "user://plantages/session_en_cours.json"
const LOGS := "user://logs"
## Rapports gardés (les plus anciens sont effacés).
const GARDER := 10
const PERIODE := 15.0
const GEL_S := 30.0
const ERREURS_MAX := 40
const MESSAGES_MAX := 30

## Désactivé en headless (bancs et tests), sauf avec « -- --plantages » ou force.
static var actif := true
static var force := false
## Rapport écrit au lancement (chemin user://), vide s'il n'y en a pas.
static var dernier_rapport := ""
## Le menu principal a déjà montré le rapport.
static var rapport_vu := false

var _journal: Capteur
var _sentinelle: Thread
var _fin := false
var _mutex := Mutex.new()
var _derniere_image_ms := 0
var _gel_note := false
var _t := 0.0
var _debut := 0
## Fournisseur d'état du jeu en cours (la scène de jeu s'y inscrit) : Callable -> Dictionary.
var etat_partie := Callable()


## Capte les erreurs et les messages du moteur (appelé depuis n'importe quel fil).
class Capteur extends Logger:
	var mutex := Mutex.new()
	var erreurs: Array[String] = []
	var messages: Array[String] = []
	var total := 0

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool,
			error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		var genre: String = ["Erreur", "Avertissement", "Erreur de script", "Erreur de shader"][clampi(error_type, 0, 3)]
		var txt := "[%s] %s : %s\n    à %s:%d (%s)" % [Time.get_time_string_from_system(), genre,
			rationale if rationale != "" else code, file, line, function]
		for bt in script_backtraces:
			if bt == null or bt.is_empty():
				continue
			for i in mini(bt.get_frame_count(), 8):
				txt += "\n      %s:%d dans %s()" % [bt.get_frame_file(i), bt.get_frame_line(i), bt.get_frame_function(i)]
		mutex.lock()
		if error_type != ERROR_TYPE_WARNING:
			total += 1
		erreurs.append(txt)
		if erreurs.size() > ERREURS_MAX:
			erreurs.remove_at(0)
		mutex.unlock()

	func _log_message(message: String, error: bool) -> void:
		if error:
			return
		mutex.lock()
		messages.append(message.strip_edges().left(300))
		if messages.size() > MESSAGES_MAX:
			messages.remove_at(0)
		mutex.unlock()

	func copie() -> Dictionary:
		mutex.lock()
		var d := {"erreurs": erreurs.duplicate(), "messages": messages.duplicate(), "total": total}
		mutex.unlock()
		return d


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	actif = force or DisplayServer.get_name() != "headless" or OS.get_cmdline_user_args().has("--plantages")
	if not actif:
		set_process(false)
		return
	DirAccess.make_dir_recursive_absolute(DIR)
	dernier_rapport = verifier_session_precedente()
	_journal = Capteur.new()
	OS.add_logger(_journal)
	_debut = int(Time.get_unix_time_from_system())
	_derniere_image_ms = Time.get_ticks_msec()
	ecrire_marque()
	_sentinelle = Thread.new()
	_sentinelle.start(_veiller)


func _process(delta: float) -> void:
	_mutex.lock()
	_derniere_image_ms = Time.get_ticks_msec()
	_mutex.unlock()
	_t += delta
	if _t >= PERIODE:
		_t = 0.0
		ecrire_marque()


func _notification(what: int) -> void:
	if not actif:
		return
	if what == NOTIFICATION_CRASH:
		# Le moteur plante : on note l'état tout de suite (le rapport complet sera fait au prochain lancement).
		ecrire_marque({"fin": "plantage du moteur"})
	elif what == NOTIFICATION_EXIT_TREE:
		fermeture_normale()


## Fermeture voulue : la marque disparaît, rien à signaler au prochain lancement.
func fermeture_normale() -> void:
	if _fin:
		return
	_fin = true
	if _sentinelle != null and _sentinelle.is_started():
		_sentinelle.wait_to_finish()
	if FileAccess.file_exists(MARQUE):
		DirAccess.remove_absolute(MARQUE)
	if _journal != null:
		OS.remove_logger(_journal)


## Fil de la sentinelle : repère un jeu qui ne dessine plus d'image.
func _veiller() -> void:
	while not _fin:
		OS.delay_msec(1000)
		_mutex.lock()
		var depuis := Time.get_ticks_msec() - _derniere_image_ms
		var note := _gel_note
		_mutex.unlock()
		if depuis > GEL_S * 1000.0 and not note:
			_mutex.lock()
			_gel_note = true
			_mutex.unlock()
			_ajouter_a_marque({"gel": "aucune image depuis %d s (%s)" % [depuis / 1000, Time.get_datetime_string_from_system()]})
		elif depuis < 2000 and note:
			_mutex.lock()
			_gel_note = false
			_mutex.unlock()
			_ajouter_a_marque({"gel": "", "dernier_gel": "le jeu a recommencé à répondre (%s)" % Time.get_datetime_string_from_system()})


## État du jeu au moment présent (pour la marque).
func etat() -> Dictionary:
	var d := {
		"version": VersionBuild.texte(),
		"systeme": "%s %s" % [OS.get_name(), OS.get_version()],
		"processeur": "%s (%d cœurs)" % [OS.get_processor_name(), OS.get_processor_count()],
		"carte_graphique": RenderingServer.get_video_adapter_name(),
		"pilote": RenderingServer.get_video_adapter_api_version(),
		"debut": _debut,
		"maj": int(Time.get_unix_time_from_system()),
		"duree_min": snappedf((Time.get_unix_time_from_system() - _debut) / 60.0, 0.1),
		"scene": String(get_tree().current_scene.name) if get_tree() != null and get_tree().current_scene != null else "",
		"images_s": Engine.get_frames_per_second(),
		"memoire_mo": snappedf(OS.get_static_memory_usage() / 1048576.0, 0.1),
		"memoire_pic_mo": snappedf(OS.get_static_memory_peak_usage() / 1048576.0, 0.1),
		"memoire_video_mo": snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.1),
		"objets": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"noeuds": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
	}
	if etat_partie.is_valid():
		var p: Variant = etat_partie.call()
		if typeof(p) == TYPE_DICTIONARY:
			d["partie"] = p
	if _journal != null:
		var j := _journal.copie()
		d["erreurs"] = j.erreurs
		d["messages"] = j.messages
		d["erreurs_total"] = j.total
	return d


func ecrire_marque(extra := {}) -> void:
	if not actif or _fin:
		return
	var d := etat()
	for k in extra:
		d[k] = extra[k]
	_mutex.lock()
	if _gel_note:
		d["gel"] = "aucune image depuis plus de %d s" % int(GEL_S)
	_mutex.unlock()
	_ecrire(d)


func _ecrire(d: Dictionary) -> void:
	var tmp := MARQUE + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(d, "\t"))
	f.close()
	DirAccess.rename_absolute(tmp, MARQUE)


func _ajouter_a_marque(extra: Dictionary) -> void:
	if _fin:
		return
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(MARQUE)) if FileAccess.file_exists(MARQUE) else {}
	if typeof(d) != TYPE_DICTIONARY:
		d = {}
	for k in extra:
		d[k] = extra[k]
	_ecrire(d)


# --- Au lancement : rapport de la session précédente -------------------------------

## Si la session précédente ne s'est pas fermée normalement, écrit le rapport et renvoie son chemin.
static func verifier_session_precedente() -> String:
	if not FileAccess.file_exists(MARQUE):
		return ""
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(MARQUE))
	DirAccess.remove_absolute(MARQUE)
	if typeof(d) != TYPE_DICTIONARY:
		d = {}
	var chemin := ecrire_rapport(d, fin_du_journal_precedent(150))
	nettoyer()
	return chemin


## Rapport lisible (texte) à partir de la marque et de la fin du journal du moteur.
static func ecrire_rapport(d: Dictionary, journal_moteur: String) -> String:
	DirAccess.make_dir_recursive_absolute(DIR)
	var maj := int(d.get("maj", Time.get_unix_time_from_system()))
	var dt := Time.get_datetime_dict_from_unix_time(maj)
	var nom := "plantage-%04d%02d%02d-%02d%02d%02d.txt" % [dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second]
	var chemin := DIR.path_join(nom)
	var l: Array[String] = []
	l.append("Rapport de plantage MiniBlocs")
	l.append("=============================")
	l.append("Ce fichier reste sur ton ordinateur : rien n'a été envoyé. Tu peux l'envoyer au")
	l.append("développeur si tu veux l'aider à corriger le problème.")
	l.append("")
	var genre := "le jeu s'est arrêté sans se fermer normalement"
	if String(d.get("fin", "")) != "":
		genre = String(d.fin)
	elif String(d.get("gel", "")) != "":
		genre = "gel : " + String(d.gel)
	l.append("Ce qui s'est passé : " + genre)
	l.append("Dernier signe de vie : %s (heure de l'ordinateur, UTC)" % Time.get_datetime_string_from_unix_time(maj, true))
	l.append("Durée de la session : %s min" % str(d.get("duree_min", "?")))
	l.append("")
	l.append("Version : %s" % str(d.get("version", "?")))
	l.append("Système : %s" % str(d.get("systeme", "?")))
	l.append("Processeur : %s" % str(d.get("processeur", "?")))
	l.append("Carte graphique : %s (%s)" % [str(d.get("carte_graphique", "?")), str(d.get("pilote", "?"))])
	l.append("Mémoire : %s Mo (pic %s Mo), mémoire vidéo %s Mo" % [str(d.get("memoire_mo", "?")), str(d.get("memoire_pic_mo", "?")), str(d.get("memoire_video_mo", "?"))])
	l.append("Images par seconde : %s · objets %s · nœuds %s" % [str(d.get("images_s", "?")), str(d.get("objets", "?")), str(d.get("noeuds", "?"))])
	l.append("Écran : %s" % str(d.get("scene", "?")))
	var p: Dictionary = d.get("partie", {}) if typeof(d.get("partie", {})) == TYPE_DICTIONARY else {}
	if not p.is_empty():
		l.append("")
		l.append("Partie en cours")
		var cles := p.keys()
		cles.sort()
		for k in cles:
			l.append("  %s : %s" % [k, str(p[k])])
	l.append("")
	var errs: Array = d.get("erreurs", [])
	l.append("Dernières erreurs (%d au total pendant la session)" % int(d.get("erreurs_total", errs.size())))
	if errs.is_empty():
		l.append("  aucune")
	for e in errs:
		l.append(String(e))
	var msgs: Array = d.get("messages", [])
	if not msgs.is_empty():
		l.append("")
		l.append("Derniers messages")
		for m in msgs:
			l.append("  " + String(m))
	if journal_moteur != "":
		l.append("")
		l.append("Fin du journal du moteur")
		l.append("------------------------")
		l.append(journal_moteur)
	var f := FileAccess.open(chemin, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string("\n".join(l) + "\n")
	f.close()
	return chemin


## Les dernières lignes du journal du moteur de la session précédente (godot.log tourne
## à chaque lancement : la session précédente est le fichier daté le plus récent).
static func fin_du_journal_precedent(lignes: int) -> String:
	var d := DirAccess.open(LOGS)
	if d == null:
		return ""
	var fichiers := Array(d.get_files()).filter(func(n: String) -> bool: return n.ends_with(".log") and n != "godot.log")
	if fichiers.is_empty():
		return ""
	fichiers.sort_custom(func(a: String, b: String) -> bool:
		return FileAccess.get_modified_time(LOGS.path_join(a)) > FileAccess.get_modified_time(LOGS.path_join(b)))
	var texte := FileAccess.get_file_as_string(LOGS.path_join(fichiers[0]))
	var t := texte.split("\n")
	return "\n".join(t.slice(maxi(0, t.size() - lignes)))


## Garde les GARDER rapports les plus récents.
static func nettoyer() -> void:
	var r := rapports()
	for i in range(GARDER, r.size()):
		DirAccess.remove_absolute(DIR.path_join(r[i]))


## Noms des rapports, le plus récent d'abord.
static func rapports() -> Array:
	var d := DirAccess.open(DIR)
	if d == null:
		return []
	var r := Array(d.get_files()).filter(func(n: String) -> bool: return n.begins_with("plantage-") and n.ends_with(".txt"))
	r.sort()
	r.reverse()
	return r


## Ouvre le dossier des rapports dans l'explorateur de fichiers.
static func ouvrir_dossier() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	OS.shell_open(ProjectSettings.globalize_path(DIR))
