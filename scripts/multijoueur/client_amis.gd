class_name ClientAmis
extends Node
## Le jeu d'un joueur connecté à une carte entre amis.
##
## Il reçoit la partie entière du serveur (instantané), l'écrit comme une
## sauvegarde locale (« amis-… ») et l'ouvre ; ensuite il applique ce que le serveur
## envoie et lui transmet ce que fait le joueur (voir ServeurAmis et
## docs/multijoueur.md). Il vit sur la racine de l'arbre : il traverse les
## changements de scène (menu → écran de chargement → partie).

signal etat_change(etat: String, texte: String)
signal chat_recu(de: String, texte: String)
signal joueurs_recus(liste: Array)
signal info_recue(texte: String)

const TERRE := "res://scenes/terre.tscn"
## Écart d'heure toléré avec le serveur avant de recaler l'horloge (secondes de jeu).
const ECART_HEURE := 120.0
## Délai minimal entre deux resynchronisations automatiques (s).
const RESYNC_MIN := 60.0

var peer: ENetMultiplayerPeer
var hote := ""
var port := Protocole.PORT_DEFAUT
var code := ""
var pseudo := ""
var pid := ""
## Tests : identifiant de joueur imposé (plusieurs joueurs dans le même jeu).
var pid_impose := ""
## deconnecte, connexion, attente, chargement, en_jeu
var etat := "deconnecte"
var admin := false
var nom_carte := ""
var code_carte := ""
var joueurs: Array = []
## Clé de la caisse du joueur (sa ville, ou sa caisse personnelle).
var ma_caisse := 0
var mes_villes: Array = []
## Ouvrir la partie reçue (faux dans les tests : on garde l'instantané).
var ouvrir_partie := true
var dernier_instantane: Dictionary = {}
var slot := ""
var jeu: Node
var resynchros := 0

var _morceaux: Array = []
var _attendus := 0
var _tampon: Array = []
var _ecarts := 0
var _derniere_resync := -1000.0
var _vitesse_serveur := -1
var _alerte_vitesse := false
var _t_connexion := 0.0


func _init() -> void:
	name = "ClientAmis"
	process_mode = Node.PROCESS_MODE_ALWAYS


func connecter(adresse: String, code_invitation: String, nom_joueur: String) -> String:
	var hp := Protocole.lire_adresse(adresse)
	hote = String(hp[0])
	port = int(hp[1])
	code = code_invitation
	pseudo = nom_joueur
	pid = pid_impose if pid_impose != "" else SaveGame.player_id()
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(hote, port)
	if err != OK:
		peer = null
		return "Connexion impossible (%s)." % error_string(err)
	peer.peer_connected.connect(func(id: int) -> void:
		if id == 1:
			_changer("attente", "Connecté, entrée sur la carte…")
			_envoyer({"m": "bonjour", "version": Protocole.VERSION, "pid": pid, "pseudo": pseudo, "code": code}))
	peer.peer_disconnected.connect(func(id: int) -> void:
		# Pas pendant poll() : le pair ne doit pas disparaître sous ses pieds.
		if id == 1:
			_perdu.call_deferred("Le serveur a fermé la connexion."))
	_t_connexion = 0.0
	_changer("connexion", "Connexion à %s:%d…" % [hote, port])
	return ""


func deconnecter(texte := "Déconnecté.") -> void:
	if peer != null:
		_envoyer({"m": "au_revoir"})
		peer.poll()
		peer.close()
		peer = null
	if etat == "en_jeu":
		_detacher()
	if Multijoueur.client == self:
		Multijoueur.role = Multijoueur.Role.SOLO
	_changer("deconnecte", texte)


func _perdu(texte: String) -> void:
	if etat == "deconnecte" and peer == null:
		return
	var p := peer
	peer = null
	if p != null:
		p.close()
	var en_jeu := etat == "en_jeu"
	_changer("deconnecte", texte)
	if en_jeu and is_instance_valid(jeu):
		jeu.hud.show_message(texte + " La partie continue hors ligne (rien n'est envoyé au serveur).")
		_detacher()
	Multijoueur.role = Multijoueur.Role.SOLO


func _changer(e: String, texte: String) -> void:
	etat = e
	etat_change.emit(e, texte)


func _envoyer(msg: Dictionary) -> void:
	if peer == null or peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	peer.set_target_peer(1)
	peer.set_transfer_mode(MultiplayerPeer.TRANSFER_MODE_RELIABLE)
	peer.transfer_channel = 0
	peer.put_packet(Protocole.encoder(msg))


func envoyer_action(a: Dictionary) -> void:
	_envoyer({"m": "action", "a": a})


func envoyer_chat(t: String) -> void:
	_envoyer({"m": "chat", "texte": t})


func envoyer_admin(op: String, extra: Dictionary = {}) -> void:
	var msg := {"m": "admin", "op": op}
	msg.merge(extra)
	_envoyer(msg)


func demander_resync() -> void:
	_derniere_resync = Time.get_ticks_msec() / 1000.0
	_envoyer({"m": "resync"})


func _process(delta: float) -> void:
	if peer == null:
		return
	peer.poll()
	if peer != null and etat == "connexion":
		_t_connexion += delta
		if _t_connexion > 8.0:
			peer.close()
			peer = null
			_changer("deconnecte", "Pas de réponse de %s:%d. Vérifie l'adresse, que le serveur tourne et que le port %d (UDP) est ouvert." % [hote, port, port])
			return
	while peer != null and peer.get_available_packet_count() > 0:
		var msg := Protocole.decoder(peer.get_packet())
		if not msg.is_empty():
			_recevoir(msg)
	if etat == "en_jeu" and is_instance_valid(jeu):
		_surveiller_vitesse()


func _recevoir(msg: Dictionary) -> void:
	match String(msg.get("m", "")):
		"refus":
			_perdu.call_deferred(String(msg.get("raison", "Entrée refusée.")))
		"bienvenue":
			admin = bool(msg.get("admin", false))
			nom_carte = String(msg.get("carte", ""))
			code_carte = String(msg.get("code", ""))
			pseudo = String(msg.get("pseudo", pseudo))
			Multijoueur.memoriser(hote, port, code, pseudo)
		"instantane":
			_morceaux.clear()
			_attendus = int(msg.get("n", 0))
			if etat != "en_jeu":
				_changer("chargement", "Réception de la carte (%s)…" % _taille(int(msg.get("octets", 0))))
		"morceau":
			_morceaux.append(msg.get("d", PackedByteArray()))
			if _morceaux.size() >= _attendus and _attendus > 0:
				_attendus = 0
				_instantane_recu(Protocole.recoller(_morceaux))
				_morceaux.clear()
		"chat":
			chat_recu.emit(String(msg.get("de", "")), String(msg.get("texte", "")))
			if etat == "en_jeu" and is_instance_valid(jeu):
				var de := String(msg.get("de", ""))
				jeu.hud.show_message(("%s : %s" % [de, msg.texte]) if de != "" else String(msg.texte))
		"joueurs":
			joueurs = msg.get("liste", [])
			joueurs_recus.emit(joueurs)
		"info":
			if msg.has("code"):
				code_carte = String(msg.code)
			info_recue.emit(String(msg.get("texte", "")))
			if etat == "en_jeu" and is_instance_valid(jeu):
				jeu.hud.show_message(String(msg.get("texte", "")))
		_:
			if String(msg.get("m", "")) == "tic" and etat != "en_jeu":
				_vitesse_serveur = int(msg.get("v", -1))
			if etat == "en_jeu" and is_instance_valid(jeu):
				appliquer(msg)
			elif etat == "chargement":
				_tampon.append(msg)


static func _taille(o: int) -> String:
	if o < 1024 * 1024:
		return "%d Ko" % maxi(1, o / 1024)
	return ("%.1f Mo" % (o / 1048576.0)).replace(".", ",")


func _instantane_recu(d: Dictionary) -> void:
	if d.is_empty() or not (d.get("sections", {}) as Dictionary).has("terrain"):
		deconnecter("Carte reçue illisible.")
		return
	dernier_instantane = d
	var m: Dictionary = d.get("manifest", {})
	var pid_partie := String(m.get("partie_id", ""))
	slot = "amis-" + (pid_partie.substr(0, 12) if pid_partie != "" else "carte")
	var info := m.duplicate(true)
	info["nom"] = "%s (en ligne)" % String(m.get("nom", "Carte entre amis"))
	info["serveur"] = "%s:%d" % [hote, port]
	var err := SaveGame.write(slot, info, d.sections)
	if err != "":
		deconnecter("Impossible d'enregistrer la carte reçue : " + err)
		return
	if etat == "en_jeu" and is_instance_valid(jeu):
		_recharger()
		return
	if not ouvrir_partie:
		_changer("pret", "Carte reçue.")
		return
	var lieu: Dictionary = m.get("lieu", {})
	GameStart.chosen = true
	GameStart.atelier = false
	GameStart.mode = GameStart.Mode.ENTRE_AMIS
	GameStart.lat = float(lieu.get("lat", GameStart.lat))
	GameStart.lon = float(lieu.get("lon", GameStart.lon))
	GameStart.place_name = String(lieu.get("nom", ""))
	GameStart.load_slot = slot
	Multijoueur.role = Multijoueur.Role.CLIENT
	EcranChargement.aller(TERRE, nom_carte if nom_carte != "" else "Carte entre amis")


## Resynchronisation en cours de partie : on recharge la partie reçue en gardant la caméra.
func _recharger() -> void:
	var rig: Node3D = jeu.rig
	var pos := rig.position
	var ang := rig.rotation_degrees.y
	var dist: float = rig._target_distance
	if jeu.load_game(slot):
		rig.position = pos
		rig.rotation_degrees.y = ang
		rig._target_distance = dist
		resynchros += 1
		_ecarts = 0
		jeu.hud.show_message("Carte resynchronisée avec le serveur.")
	_appliquer_tampon()


# --- Dans la partie ---------------------------------------------------------------------------

## Appelé par la scène Terre quand la partie reçue est ouverte.
func attacher(j: Node) -> void:
	jeu = j
	GameStart.mode = GameStart.Mode.ENTRE_AMIS
	var bs: BuildingSystem = jeu.buildings
	bs.verrou_reseau = true
	bs.relais = _relais_batiment
	jeu.transport.verrou_reseau = true
	jeu.transport.relais = envoyer_action
	jeu.world.relais = envoyer_action
	# Ce qui pousse tout seul (zones, pilote automatique) vient du serveur.
	jeu.zones.growth = false
	if jeu.pilote != null:
		jeu.pilote.set_process(false)
	if jeu.tutoriel != null:
		jeu.tutoriel.set_actif(false)
	ReglagesPartie.actuel.tutoriel = false
	jeu.tree_exiting.connect(func() -> void:
		if etat != "deconnecte":
			deconnecter("Tu as quitté la carte entre amis."))
	_changer("en_jeu", "Sur la carte « %s »." % nom_carte)
	jeu.hud.show_message("Carte entre amis « %s » : F3 pour les joueurs et la discussion." % nom_carte)
	_appliquer_tampon()


func _detacher() -> void:
	if not is_instance_valid(jeu):
		return
	jeu.buildings.verrou_reseau = false
	jeu.buildings.relais = Callable()
	jeu.transport.verrou_reseau = false
	jeu.transport.relais = Callable()
	jeu.world.relais = Callable()
	jeu.zones.growth = true
	if jeu.pilote != null:
		jeu.pilote.set_process(true)


func _appliquer_tampon() -> void:
	var t := _tampon
	_tampon = []
	for msg in t:
		appliquer(msg)


func _relais_batiment(a: Dictionary) -> void:
	# Maison de commune : le nom choisi pour le village part avec.
	if String(a.get("t", "")) == "poser" and Communes.est_fondateur(String(a.get("id", ""))):
		a["nom"] = jeu.communes.nom_en_attente
	envoyer_action(a)


## Applique un message du serveur à la partie ouverte.
func appliquer(msg: Dictionary) -> void:
	match String(msg.get("m", "")):
		"bat":
			_bat(msg.get("l", []))
		"rejouer":
			_rejouer(msg.get("a", {}))
		"terrain":
			_terrain(msg)
		"section":
			if String(msg.get("nom", "")) == "transport":
				var d: Variant = msg.get("data")
				if d is Dictionary:
					jeu.transport.from_dict(d)
		"tic":
			_tic(msg)
		"reglages":
			var d: Variant = msg.get("d")
			if d is Dictionary:
				var createur := ReglagesPartie.actuel.createur
				ReglagesPartie.actuel.from_dict(d)
				ReglagesPartie.actuel.createur = createur
				ReglagesPartie.actuel.tutoriel = false
				jeu._apply_settings(true)


func _bat(liste: Array) -> void:
	var bs: BuildingSystem = jeu.buildings
	var avant := bs._par_reseau
	bs._par_reseau = true
	for e in liste:
		match String(e.get("o", "")):
			"+":
				var b: Dictionary = e.b
				var bid := int(b.id)
				if bs.buildings.has(bid):
					continue
				if e.has("village"):
					jeu.communes.nom_en_attente = String(e.village)
				bs.restore(b)
				bs.next_id = maxi(bs.next_id, bid + 1)
			"~":
				var b: Dictionary = e.b
				var bid := int(b.id)
				if bs.buildings.has(bid):
					bs.set_perso(bid, b.get("perso", {}), int(b.get("v", -1)))
			"-":
				var bid := int(e.bid)
				if bs.buildings.has(bid):
					bs.remove_quietly(bid)
	bs._par_reseau = avant
	bs._refresh()


func _rejouer(a: Dictionary) -> void:
	var tr: TransportSystem = jeu.transport
	var avant := tr._par_reseau
	tr._par_reseau = true
	match String(a.get("t", "")):
		"voie":
			var res: Dictionary = tr.build_path(String(a.get("id", "")), a.get("spec", {}), a.get("path", PackedVector2Array()))
			if res.ok:
				tr.edges_built.emit(res.edges)
		"voie_demolir":
			tr.demolish(int(a.get("eid", -1)))
		"carrefour":
			tr.appliquer_carrefour(String(a.get("action", "")), a.get("p", Vector3.ZERO), bool(a.get("maj", false)))
	tr._par_reseau = avant


func _terrain(msg: Dictionary) -> void:
	var w: TerrainWorld = jeu.world
	var n := 0
	var eau := false
	for t in ServeurAmis.TABLES_TERRAIN:
		if not msg.has(t):
			continue
		var table: Dictionary = w.get(t)
		var d: Dictionary = msg[t]
		for m in d.get("mis", []):
			var c := Vector2i(int(m[0]), int(m[1]))
			table[c] = float(m[2])
			w._mark_dirty_around(c)
			n += 1
		for m in d.get("otes", []):
			var c := Vector2i(int(m[0]), int(m[1]))
			table.erase(c)
			w._mark_dirty_around(c)
			n += 1
		if t == "water_cells":
			eau = true
	if eau:
		w._on_water_changed()


func _tic(msg: Dictionary) -> void:
	var amb: DayNight = jeu.ambiance
	var t := float(msg.get("t", amb.unix_time))
	if absf(amb.unix_time - t) > ECART_HEURE:
		amb.unix_time = t
	var v := int(msg.get("v", amb.speed_index))
	_vitesse_serveur = v
	if amb.speed_index != v:
		amb.set_speed(v)
	var pays: Pays = jeu.pays
	var caisses: Dictionary = msg.get("caisses", {})
	for k in caisses:
		pays._poser(int(k), int(caisses[k]))
	ma_caisse = int(msg.get("ma", ma_caisse))
	mes_villes = msg.get("villes", [])
	if pays.actif != ma_caisse:
		pays.activer(ma_caisse)
	jeu.buildings.unlimited_money = bool(msg.get("illimite", jeu.buildings.unlimited_money))
	# Empreintes : deux tics de suite différents → on redemande la partie.
	var sig: Dictionary = msg.get("sig", {})
	if not sig.is_empty() and sig != empreintes_locales():
		_ecarts += 1
		var now := Time.get_ticks_msec() / 1000.0
		if _ecarts >= 2 and now - _derniere_resync > RESYNC_MIN:
			_ecarts = 0
			demander_resync()
	else:
		_ecarts = 0


func empreintes_locales() -> Dictionary:
	var bs: BuildingSystem = jeu.buildings
	var net: TransportNetwork = jeu.transport.network
	return {"b": [bs.buildings.size(), bs.next_id], "r": [net.edges.size(), net.nodes.size(), net.next_id],
		"v": jeu.communes.villages.size()}


## Vitesse du temps : celle du serveur. L'admin qui la change (T, Maj+T) la change pour tous.
func _surveiller_vitesse() -> void:
	if _vitesse_serveur < 0:
		return
	var amb: DayNight = jeu.ambiance
	if amb.speed_index == _vitesse_serveur:
		return
	if admin:
		envoyer_admin("vitesse", {"v": amb.speed_index})
		_vitesse_serveur = amb.speed_index
	else:
		amb.set_speed(_vitesse_serveur)
		if not _alerte_vitesse:
			_alerte_vitesse = true
			jeu.hud.show_message("Sur une carte entre amis, seul l'admin règle la vitesse du temps.")


## Réglages changés dans le panneau Admin (F10) par l'admin connecté.
func reglages_changes() -> void:
	if admin:
		envoyer_admin("reglages", {"d": ReglagesPartie.actuel.to_dict()})
