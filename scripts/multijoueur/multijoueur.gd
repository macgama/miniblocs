class_name Multijoueur
extends RefCounted
## Carte entre amis : rôle de ce jeu (seul, serveur, joueur connecté), lancement du
## serveur depuis la ligne de commande ou depuis le menu, souvenirs de connexion.
##
## Lancer un serveur (sans écran) :
##   godot --headless --path <dossier du jeu> -- --serveur --partie <id de partie> [--port 24680]
##   godot --headless --path <dossier du jeu> -- --serveur --nouvelle --lat 45.9 --lon 6.13 --nom "Annecy"
## Options : --code ABCD-EFGH (code imposé), --terrain-plat (tests, sans Internet).
## Voir docs/multijoueur.md.

enum Role { SOLO, SERVEUR, CLIENT }

static var role: Role = Role.SOLO
static var serveur: ServeurAmis
static var client: ClientAmis
## Section « multijoueur » lue par le dernier chargement (pour le serveur).
static var section_chargee: Dictionary = {}
## Options du serveur lues sur la ligne de commande.
static var options: Dictionary = {}
static var code_impose := ""
## Terrain plat sans Internet (tests automatiques du serveur).
static var terrain_plat := false


static func en_ligne() -> bool:
	return role != Role.SOLO


## Lit les options après « -- » : {"serveur": true, "partie": "…", "port": 24680, …}.
static func lire_options(args: PackedStringArray) -> Dictionary:
	var o := {}
	var i := 0
	while i < args.size():
		var a := args[i]
		if a.begins_with("--"):
			var cle := a.substr(2)
			if i + 1 < args.size() and not args[i + 1].begins_with("--"):
				o[cle] = args[i + 1]
				i += 1
			else:
				o[cle] = true
		i += 1
	if o.has("port"):
		o.port = clampi(int(o.port), 1, 65535)
	return o


## Au lancement du jeu (menu principal) : « --serveur » ouvre directement la carte
## en serveur. Renvoie vrai si c'est le cas.
static func demarrage_serveur(tree: SceneTree) -> bool:
	var o := lire_options(OS.get_cmdline_user_args())
	if not o.has("serveur"):
		return false
	options = o
	role = Role.SERVEUR
	code_impose = String(o.get("code", ""))
	terrain_plat = o.has("terrain-plat")
	ReglagesPartie.prochaine = null
	if o.has("partie"):
		var slot := String(o.partie)
		var m := SaveGame.read_manifest(slot)
		if m.is_empty():
			printerr("[serveur] Partie introuvable : ", slot, " (dossier ", ProjectSettings.globalize_path(SaveGame.DIR), ")")
			tree.quit(2)
			return true
		var lieu: Dictionary = m.get("lieu", {})
		GameStart.lat = float(lieu.get("lat", GameStart.lat))
		GameStart.lon = float(lieu.get("lon", GameStart.lon))
		GameStart.place_name = String(lieu.get("nom", ""))
		GameStart.load_slot = slot
		GameStart.slot_id = slot
	else:
		GameStart.lat = float(o.get("lat", GameStart.lat))
		GameStart.lon = float(o.get("lon", GameStart.lon))
		GameStart.place_name = String(o.get("nom", "Carte entre amis"))
		GameStart.load_slot = ""
		GameStart.slot_id = ""
	GameStart.chosen = true
	GameStart.atelier = false
	GameStart.mode = GameStart.Mode.ENTRE_AMIS
	print("[serveur] Ouverture de « %s »…" % (GameStart.place_name if GameStart.place_name != "" else GameStart.load_slot))
	tree.change_scene_to_file.call_deferred("res://scenes/terre.tscn")
	return true


## Appelé à la fin du _ready de la scène Terre.
static func attacher(jeu: Node) -> void:
	match role:
		Role.SERVEUR:
			if terrain_plat:
				jeu.world.tiles.offline_generator = func(_t: Vector2i) -> PackedFloat32Array:
					var a := PackedFloat32Array()
					a.resize(256 * 256)
					a.fill(40.0)
					return a
				jeu.world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
			# Nouvelle carte : l'admin est celui donné par --createur, sinon le premier qui entre.
			if GameStart.slot_id == "":
				ReglagesPartie.actuel.createur = String(options.get("createur", ""))
				ReglagesPartie.actuel.tutoriel = false
			serveur = ServeurAmis.new()
			jeu.add_child(serveur)
			var err := serveur.demarrer(jeu, int(options.get("port", Protocole.PORT_DEFAUT)))
			if err != "":
				printerr("[serveur] ", err)
				jeu.get_tree().quit(3)
		Role.CLIENT:
			if client != null:
				client.attacher(jeu)


## Section de la sauvegarde (serveur seulement).
static func section() -> Dictionary:
	return serveur.to_dict() if role == Role.SERVEUR and serveur != null else {}


static func client_actif() -> ClientAmis:
	if client == null or not is_instance_valid(client):
		return null
	return client


## Crée (ou retrouve) le client, attaché à la racine de l'arbre.
static func nouveau_client(tree: SceneTree) -> ClientAmis:
	if client_actif() != null:
		client.deconnecter("")
		client.queue_free()
	client = ClientAmis.new()
	tree.root.add_child(client)
	return client


# --- Souvenirs (user://joueur.cfg) ---------------------------------------------------------

static func pseudo() -> String:
	var cfg := ConfigFile.new()
	cfg.load(SaveGame.PLAYER_FILE)
	return String(cfg.get_value("multijoueur", "pseudo", ""))


static func souvenirs() -> Dictionary:
	var cfg := ConfigFile.new()
	cfg.load(SaveGame.PLAYER_FILE)
	return {"pseudo": String(cfg.get_value("multijoueur", "pseudo", "")),
		"adresse": String(cfg.get_value("multijoueur", "adresse", "127.0.0.1")),
		"code": String(cfg.get_value("multijoueur", "code", ""))}


static func memoriser(hote: String, port: int, code: String, pseudo_: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SaveGame.PLAYER_FILE)
	SaveGame.player_id()
	cfg.load(SaveGame.PLAYER_FILE)
	cfg.set_value("multijoueur", "pseudo", pseudo_)
	cfg.set_value("multijoueur", "adresse", hote if port == Protocole.PORT_DEFAUT else "%s:%d" % [hote, port])
	cfg.set_value("multijoueur", "code", code)
	cfg.save(SaveGame.PLAYER_FILE)


# --- Héberger sur ce PC --------------------------------------------------------------------

## Copie une partie solo en carte entre amis (la partie solo reste intacte).
## Renvoie l'id de la nouvelle partie, ou "" (raison dans erreur[0]).
static func copier_en_carte(slot_src: String, erreur: Array = []) -> String:
	var res := SaveGame.read(slot_src)
	if not res.ok:
		erreur.append(String(res.error))
		return ""
	var m: Dictionary = res.manifest
	var nom := String(m.get("nom", slot_src))
	var slot := SaveGame.make_slot_id("amis " + nom)
	var info := {"nom": "%s · entre amis" % nom, "lieu": m.get("lieu", {}), "mode": "entre_amis",
		"camera": m.get("camera", {}), "resume": m.get("resume", {})}
	var sec: Dictionary = res.sections
	var reg: Dictionary = (sec.get("reglages", {}) as Dictionary).duplicate()
	reg["createur"] = SaveGame.player_id()
	reg["tutoriel"] = false
	sec["reglages"] = reg
	var err := SaveGame.write(slot, info, sec)
	if err != "":
		erreur.append(err)
		return ""
	return slot


## Lance le serveur sans écran sur ce PC (un processus à part, qui continue après
## la fermeture du jeu). Renvoie le numéro du processus, ou -1.
static func lancer_serveur_local(slot: String, port: int) -> int:
	var args := PackedStringArray(["--headless"])
	if OS.has_feature("editor") or not OS.has_feature("template"):
		args.append_array(["--path", ProjectSettings.globalize_path("res://")])
	args.append_array(["--", "--serveur", "--partie", slot, "--port", str(port)])
	return OS.create_process(OS.get_executable_path(), args)
