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
	# Scénarios : en solo seulement (une carte venue d'un scénario continue sans lui).
	if role != Role.SOLO and jeu.get("scenario") != null and jeu.scenario.en_cours():
		jeu.scenario.clear()
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


# --- Appels : réglages et commandes rejoués par le serveur -----------------------------------

## Vrai pendant qu'un jeu rejoue ce que le serveur lui envoie (rien ne repart au serveur).
static var rejeu := false

## Ce qu'un joueur peut demander au serveur (système → fonctions). « ville » : seul le
## maire de la ville concernée décide.
const APPELS := {
	"budget": {"f": ["set_taux", "emprunter", "rembourser", "set_entretien", "reparer"], "ville": true},
	"pilote": {"f": ["activer"], "ville": true},
	"stations": {"f": ["place", "remove_station", "create_line", "set_fret", "set_line", "remove_line"]},
	"commerce": {"f": ["signer", "proposer", "accepter", "refuser", "resilier", "mission_commerciale", "set_libre_echange"], "ville": true},
	# Systèmes gérés depuis un panneau (SystemesGeres) : « etat » : le serveur les fait puis
	# envoie l'état du système (pas de rejeu chez les joueurs : tirages au sort).
	"club": {"f": ["fonder", "changer_stade", "renommer", "set_couleurs", "set_formation", "set_tactique", "set_entrainement",
		"set_repos", "set_prix", "acheter", "vendre", "liberer", "prolonger", "set_academie", "promouvoir", "liberer_espoir",
		"set_abo_prix", "subventionner"], "ville": true, "etat": true},
	"parc": {"f": ["set_prix", "renommer"], "ville": true, "etat": true},
	"zoo": {"f": ["ajouter_enclos", "retirer_enclos", "changer_barriere", "renommer_enclos", "acheter", "vendre", "relacher",
		"deplacer", "set_prix", "set_nom", "set_contraception", "acheter_offre", "repondre_demande", "refuser_offre",
		"proposer_echange", "placer_arrivee", "ceder_arrivee"], "ville": true, "etat": true},
	"musee": {"f": ["renommer", "set_prix", "set_gratuit_dimanche", "lancer_expo"], "ville": true, "etat": true},
}


## Appel d'un système géré par le serveur (club, parc, zoo, musée) ?
static func appel_etat(sys: String) -> bool:
	return bool((APPELS.get(sys, {}) as Dictionary).get("etat", false))


static func appel_permis(sys: String, f: String) -> bool:
	return APPELS.has(sys) and f in (APPELS[sys].f as Array)


## Ville concernée par un appel (-1 : aucune).
static func ville_de_appel(a: Dictionary) -> int:
	match String(a.get("sys", "")):
		"budget", "commerce", "club", "parc", "zoo", "musee":
			return int(a.get("ville", -1))
		"pilote":
			var args: Array = a.get("args", [])
			return int(args[0]) if not args.is_empty() else -1
	return -1


## Sur une carte entre amis, le joueur décide-t-il dans la caisse ou la ville k ?
static func peut_decider(k: int) -> bool:
	if role != Role.CLIENT or client_actif() == null:
		return true
	if Pays.est_nation(k):
		return client.admin
	return client.mes_villes.has(k)


## Joueur connecté : l'appel part au serveur au lieu d'être fait ici (vrai), ou il
## est refusé ici parce que le joueur n'est pas maire. Faux : à faire en local.
## extra : "ville" (clé de la ville réglée), "p" (point de la carte, pour la caisse).
static func relayer(sys: String, f: String, args: Array, extra: Dictionary = {}) -> bool:
	if role != Role.CLIENT or rejeu or client_actif() == null or client.etat != "en_jeu":
		return false
	var a := {"t": "appel", "sys": sys, "f": f, "args": args}
	a.merge(extra)
	var v := ville_de_appel(a)
	if bool((APPELS.get(sys, {}) as Dictionary).get("ville", false)) and v != -1 and not peut_decider(v):
		if is_instance_valid(client.jeu):
			if appel_etat(sys):
				client.jeu.hud.show_message("Seul le maire de %s gère ce qui est dans sa ville (club, parc, zoo, musée)." % client.jeu.pays.nom_de(v))
			else:
				client.jeu.hud.show_message("Seul le maire de %s décide de ses réglages (impôts, emprunts, entretien, pilote automatique)." % client.jeu.pays.nom_de(v))
		return true
	client.envoyer_action(a)
	return true


## Fait l'appel a dans la partie jeu (serveur, ou rejeu chez un joueur). Renvoie son résultat.
static func executer_appel(jeu: Node, a: Dictionary) -> Variant:
	var sys := String(a.get("sys", ""))
	var f := String(a.get("f", ""))
	if not appel_permis(sys, f):
		return null
	var args: Array = a.get("args", [])
	match sys:
		"budget":
			var b: BudgetCommunal = jeu.budget
			var ville := int(a.get("ville", b.cle))
			var sel := b.cle
			b.selectionner(ville)
			var prev: int = jeu.pays.entrer(ville)
			var r: Variant = b.callv(f, args)
			jeu.pays.sortir(prev)
			b.selectionner(sel)
			b.changed.emit()
			return r
		"pilote":
			return jeu.pilote.callv(f, args)
		"commerce":
			return jeu.commerce_mondial.callv(f, args)
		"club":
			var clubs: Dictionary = jeu.clubs
			var c: Variant = clubs.get(String(a.get("sport", "football")))
			return (c as ClubSport).callv(f, args) if c is ClubSport else "Sport inconnu."
		"parc":
			return jeu.parc.callv(f, args)
		"zoo":
			return jeu.zoo.callv(f, args)
		"musee":
			return jeu.musee.callv(f, args)
		"stations":
			var st: StationSystem = jeu.transport.stations
			return jeu.transport.appliquer_reseau(func() -> Variant: return st.callv(f, args))
	return null


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
	# Les scénarios (objectifs, score, médailles) se jouent seul : la carte entre amis
	# reprend la ville telle quelle, sans le scénario.
	sec.erase("scenario")
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
