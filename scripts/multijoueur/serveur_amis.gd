class_name ServeurAmis
extends Node
## Serveur de la carte entre amis : la partie tourne ici (Godot sans écran,
## « --headless »), même quand le créateur est hors ligne.
##
## Le serveur fait foi : les joueurs lui envoient ce qu'ils font (poser, démolir,
## tracer une voie, terrasser…), il vérifie, l'applique à SA partie et renvoie le
## résultat à tout le monde :
##  - bâtiments : chaque bâtiment posé, retiré ou changé (par un joueur, la pousse
##    des zones, le pilote automatique, les fondateurs…) part tel quel (« bat ») ;
##  - voies : les tracés des joueurs sont rejoués chez chacun (« rejouer »), les
##    autres changements du réseau partent en section entière (« section ») ;
##  - terrain : les cases changées (« terrain ») ;
##  - chaque seconde (« tic ») : heure et vitesse du temps, caisses, empreintes
##    (nombre de bâtiments, de tronçons…) ; un jeu qui ne retombe pas sur les mêmes
##    redemande la partie entière (« resync »).
## Voir docs/multijoueur.md.

signal journal(texte: String)

const ATTENTE_BONJOUR := 10.0
## Une action dont le relief n'est pas encore chargé attend au plus ce temps (s).
const ATTENTE_RELIEF := 20.0
const SAUVEGARDE := 60.0
const TABLES_TERRAIN := ["modifications", "water_cells", "biome_paint", "tree_paint"]

var jeu: Node
var carte := CarteAmis.new()
var peer: ENetMultiplayerPeer
var port := Protocole.PORT_DEFAUT
## peer -> {"pid", "pseudo", "ok", "t"}
var connectes := {}
var sauvegarde_auto := SAUVEGARDE

var _evts_bat: Array = []
var _ombres := {}
var _terrain_sale := true
var _terrain_t := 0.0
var _tic := 0.0
var _sauve_t := 0.0
var _sale := false
var _push_transport := -1.0
var _rejeu := false
var _file: Array = []
var _en_cours := false
var _auteur := ""
var _messages: Array = []
var _arret := false


func _init() -> void:
	name = "ServeurAmis"
	process_mode = Node.PROCESS_MODE_ALWAYS


## Démarre l'écoute. Renvoie "" ou la raison de l'échec.
func demarrer(j: Node, p: int) -> String:
	jeu = j
	port = p
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(port, Protocole.JOUEURS_MAX)
	if err != OK:
		peer = null
		return "Impossible d'ouvrir le port %d (%s) : un autre serveur tourne peut-être déjà." % [port, error_string(err)]
	peer.peer_connected.connect(_on_connexion)
	peer.peer_disconnected.connect(_on_deconnexion)
	GameStart.mode = GameStart.Mode.ENTRE_AMIS
	var caisses := {}
	if Multijoueur.section_chargee.is_empty():
		carte.creer(jeu._game_title(), ReglagesPartie.actuel.createur)
	else:
		caisses = carte.from_dict(Multijoueur.section_chargee)
	if carte.createur == "":
		carte.createur = ReglagesPartie.actuel.createur
	ReglagesPartie.actuel.createur = carte.createur
	if Multijoueur.code_impose != "":
		carte.code = CarteAmis.normaliser_code(Multijoueur.code_impose)
	var pays: Pays = jeu.pays
	for k in caisses:
		if int(k) != pays.actif:
			pays.comptes[int(k)] = int(caisses[k])
	# Partie solo devenue carte entre amis : ses villes sont celles du créateur.
	for vid in jeu.communes.villages:
		if not carte.maires.has(int(vid)):
			carte.maires[int(vid)] = carte.createur
	var bs: BuildingSystem = jeu.buildings
	bs.added.connect(func(bid: int) -> void: _evts_bat.append(["+", bid]))
	bs.removed.connect(func(bid: int) -> void: _evts_bat.append(["-", bid]))
	bs.perso_changed.connect(func(bid: int) -> void: _evts_bat.append(["~", bid]))
	bs.changed.connect(func() -> void:
		_terrain_sale = true
		_sale = true)
	jeu.world.terrain_edited.connect(func(_n: int) -> void:
		_terrain_sale = true
		_sale = true)
	jeu.transport.network_changed.connect(func() -> void:
		_terrain_sale = true
		_sale = true
		if not _rejeu:
			_push_transport = 0.4)
	jeu.communes.fonde.connect(_on_fonde)
	for sig in [bs.message, jeu.transport.message, jeu.communes.message, jeu.pays.message]:
		(sig as Signal).connect(func(t: String) -> void:
			if _en_cours:
				_messages.append(t))
	_init_ombres()
	# Le serveur ne fait ni tutoriel ni fondation à l'écran.
	if jeu.tutoriel != null:
		jeu.tutoriel.set_actif(false)
	if GameStart.slot_id == "":
		jeu.save_game("", carte.nom if carte.nom != "" else "Carte entre amis")
	_log("Carte entre amis « %s » ouverte sur le port %d. Code d'invitation : %s" % [carte.nom, port, carte.code])
	return ""


func _log(t: String) -> void:
	print("[serveur] ", t)
	journal.emit(t)


# --- Connexions ---------------------------------------------------------------------------

func _on_connexion(id: int) -> void:
	connectes[id] = {"pid": "", "pseudo": "", "ok": false, "t": Time.get_ticks_msec() / 1000.0}


func _on_deconnexion(id: int) -> void:
	var c: Dictionary = connectes.get(id, {})
	connectes.erase(id)
	if bool(c.get("ok", false)):
		_log("%s a quitté la carte." % c.pseudo)
		_a_tous({"m": "chat", "de": "", "texte": "%s a quitté la carte." % c.pseudo})
		_envoyer_joueurs()


func _envoyer(id: int, msg: Dictionary) -> void:
	if peer == null:
		return
	peer.set_target_peer(id)
	peer.set_transfer_mode(MultiplayerPeer.TRANSFER_MODE_RELIABLE)
	peer.transfer_channel = 0
	peer.put_packet(Protocole.encoder(msg))


## À tous les joueurs entrés (instantané reçu), sauf sauf.
func _a_tous(msg: Dictionary, sauf := 0) -> void:
	var oct := Protocole.encoder(msg)
	for id in connectes:
		if int(id) != sauf and bool(connectes[id].ok):
			peer.set_target_peer(id)
			peer.set_transfer_mode(MultiplayerPeer.TRANSFER_MODE_RELIABLE)
			peer.transfer_channel = 0
			peer.put_packet(oct)


func _process(delta: float) -> void:
	if peer == null:
		return
	peer.poll()
	while peer != null and peer.get_available_packet_count() > 0:
		var id := peer.get_packet_peer()
		var msg := Protocole.decoder(peer.get_packet())
		if not msg.is_empty():
			_recevoir(id, msg)
	if peer == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	for id in connectes.keys():
		if not bool(connectes[id].ok) and now - float(connectes[id].t) > ATTENTE_BONJOUR:
			peer.disconnect_peer(id)
	_traiter_file()
	_envoyer_batiments()
	if _push_transport >= 0.0:
		_push_transport -= delta
		if _push_transport < 0.0:
			_a_tous({"m": "section", "nom": "transport", "data": JSON.parse_string(JSON.stringify(jeu.transport.to_dict()))})
	_terrain_t += delta
	_tic += delta
	if _tic >= 1.0:
		_tic = 0.0
		if _terrain_sale or _terrain_t > 5.0:
			_envoyer_terrain()
		_envoyer_tic()
	_sauve_t += delta
	if _sauve_t >= sauvegarde_auto and _sale:
		sauvegarder()


func sauvegarder() -> bool:
	_sauve_t = 0.0
	_sale = false
	var ok: bool = jeu.save_game()
	if not ok:
		_log("Échec de la sauvegarde : " + String(jeu.last_error))
	return ok


func arreter() -> void:
	if _arret:
		return
	_arret = true
	_a_tous({"m": "chat", "de": "", "texte": "Le serveur s'arrête (partie sauvegardée)."})
	sauvegarder()
	if peer != null:
		peer.poll()
		for id in connectes.keys():
			peer.disconnect_peer(id)
		peer.close()
		peer = null
	_log("Serveur arrêté.")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if peer != null:
			arreter()


# --- Messages reçus -------------------------------------------------------------------------

func _recevoir(id: int, msg: Dictionary) -> void:
	var c: Dictionary = connectes.get(id, {})
	if c.is_empty():
		return
	var type := String(msg.get("m", ""))
	if type == "bonjour":
		_bonjour(id, msg)
		return
	if not bool(c.ok):
		return
	match type:
		"action":
			var a: Variant = msg.get("a")
			if a is Dictionary:
				_file.append({"id": id, "pid": c.pid, "a": a, "t": Time.get_ticks_msec() / 1000.0})
		"chat":
			var t := String(msg.get("texte", "")).strip_edges().replace("\n", " ")
			if t != "":
				_a_tous({"m": "chat", "de": c.pseudo, "texte": t.substr(0, 300)})
		"resync":
			_envoyer_instantane(id)
		"admin":
			_admin(id, c, msg)
		"au_revoir":
			peer.disconnect_peer(id)


func _bonjour(id: int, msg: Dictionary) -> void:
	if int(msg.get("version", 0)) != Protocole.VERSION:
		_refuser(id, "Version du jeu différente de celle du serveur : mets les deux à jour.")
		return
	var pid := String(msg.get("pid", ""))
	for autre in connectes:
		if int(autre) != id and String(connectes[autre].pid) == pid:
			_refuser(id, "Tu es déjà connecté à cette carte depuis un autre jeu.")
			return
	var res := carte.accepter(pid, String(msg.get("pseudo", "")), String(msg.get("code", "")), int(Time.get_unix_time_from_system()))
	if not res.ok:
		_refuser(id, String(res.raison))
		return
	ReglagesPartie.actuel.createur = carte.createur
	var c: Dictionary = connectes[id]
	c.pid = pid
	c.pseudo = carte.pseudo(pid)
	c.ok = true
	# Premier passage : sa caisse personnelle reçoit l'argent de départ de la carte.
	var kp := carte.cle_personnelle(pid)
	var pays: Pays = jeu.pays
	if carte.villes_de(pid).is_empty() and not pays.comptes.has(kp) and pays.actif != kp:
		pays.comptes[kp] = ReglagesPartie.actuel.argent_depart
	_sale = true
	var admin := carte.est_admin(pid)
	_envoyer(id, {"m": "bienvenue", "pid": pid, "pseudo": c.pseudo, "admin": admin, "carte": carte.nom,
		"code": carte.code if admin else "", "nouveau": bool(res.nouveau)})
	_envoyer_instantane(id)
	_log("%s a rejoint la carte%s." % [c.pseudo, " (première fois)" if res.nouveau else ""])
	_a_tous({"m": "chat", "de": "", "texte": "%s a rejoint la carte." % c.pseudo}, id)
	_envoyer_joueurs()


func _refuser(id: int, raison: String) -> void:
	_envoyer(id, {"m": "refus", "raison": raison})
	_log("Connexion refusée : " + raison)
	var p := peer
	get_tree().create_timer(0.5, true).timeout.connect(func() -> void:
		if p != null and p == peer:
			p.disconnect_peer(id))


## La partie entière : la même chose qu'une sauvegarde, sans la section du serveur.
func instantane() -> Dictionary:
	var sec: Dictionary = jeu.save_sections()
	sec.erase("multijoueur")
	var m := SaveGame.read_manifest(GameStart.slot_id)
	var info := {"nom": carte.nom, "partie_id": String(m.get("partie_id", "")), "mode": "entre_amis",
		"lieu": {"lat": jeu.world.origin_lat, "lon": jeu.world.origin_lon, "nom": GameStart.place_name}}
	return {"manifest": info, "sections": sec}


func _envoyer_instantane(id: int) -> void:
	var morceaux := Protocole.decouper(instantane())
	var total := 0
	for m in morceaux:
		total += m.size()
	_envoyer(id, {"m": "instantane", "n": morceaux.size(), "octets": total})
	for i in morceaux.size():
		_envoyer(id, {"m": "morceau", "i": i, "d": morceaux[i]})


func _admin(id: int, c: Dictionary, msg: Dictionary) -> void:
	if not carte.est_admin(String(c.pid)):
		_envoyer(id, {"m": "info", "texte": "Seul l'admin de la carte peut faire ça."})
		return
	match String(msg.get("op", "")):
		"code":
			carte.code = CarteAmis.nouveau_code()
			_sale = true
			_envoyer(id, {"m": "info", "texte": "Nouveau code d'invitation : %s (l'ancien ne marche plus)." % carte.code, "code": carte.code})
		"exclure":
			var pid := String(msg.get("pid", ""))
			if pid == carte.createur:
				return
			carte.exclure(pid)
			_sale = true
			for autre in connectes.keys():
				if String(connectes[autre].pid) == pid:
					_refuser(autre, "L'admin de la carte t'en a exclu.")
			_envoyer_joueurs()
		"vitesse":
			jeu.ambiance.set_speed(clampi(int(msg.get("v", 1)), 0, DayNight.SPEEDS.size() - 1))
			_sale = true
		"reglages":
			var d: Variant = msg.get("d")
			if d is Dictionary:
				ReglagesPartie.actuel.from_dict(d)
				ReglagesPartie.actuel.createur = carte.createur
				jeu._apply_settings(true)
				_sale = true
				_a_tous({"m": "reglages", "d": ReglagesPartie.actuel.to_dict()}, id)
		"caisse":
			var k := carte.caisse_principale(String(c.pid))
			jeu.pays._poser(k, int(msg.get("v", 0)))
			_sale = true
		"arreter":
			arreter()
			get_tree().quit()


func _envoyer_joueurs() -> void:
	var liste := []
	var en_ligne := {}
	for id in connectes:
		if bool(connectes[id].ok):
			en_ligne[String(connectes[id].pid)] = true
	for pid in carte.membres:
		var m: Dictionary = carte.membres[pid]
		var villes := []
		for vid in carte.villes_de(pid):
			if jeu.communes.villages.has(vid):
				villes.append(String(jeu.communes.villages[vid].nom))
		liste.append({"pid": pid, "pseudo": m.pseudo, "admin": carte.est_admin(pid), "en_ligne": en_ligne.has(pid),
			"villes": villes, "vu": int(m.vu)})
	_a_tous({"m": "joueurs", "liste": liste, "carte": carte.nom})


# --- Actions des joueurs -------------------------------------------------------------------

## Point de la carte touché par une action (pour attendre que son relief soit chargé).
static func point_de(a: Dictionary) -> Variant:
	match String(a.get("t", "")):
		"poser", "demolir":
			var c: Array = a.get("c", [0, 0])
			return Vector2(float(c[0]), float(c[1]))
		"terrain":
			return Vector2(a.a)
		"pinceau":
			return Vector2(a.c)
		"voie":
			var p: PackedVector2Array = a.get("path", PackedVector2Array())
			return p[0] if p.size() > 0 else null
		"carrefour":
			var v: Vector3 = a.get("p", Vector3.ZERO)
			return Vector2(v.x, v.z)
	return null


func _relief_pret(p: Variant) -> bool:
	if p == null:
		return true
	var w: TerrainWorld = jeu.world
	var k := Vector2i(floori(p.x / w.chunk_size), floori(p.y / w.chunk_size))
	return w._ensure_tiles(k)


func _traiter_file() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var reste: Array = []
	for e in _file:
		if not _relief_pret(point_de(e.a)) and now - float(e.t) < ATTENTE_RELIEF:
			reste.append(e)
			continue
		var txt := executer(String(e.pid), e.a)
		if txt != "" and connectes.has(e.id):
			_envoyer(e.id, {"m": "info", "texte": txt})
	_file = reste


## Applique une action d'un joueur à la partie du serveur. Renvoie le message pour lui.
func executer(pid: String, a: Dictionary) -> String:
	_en_cours = true
	_auteur = pid
	_messages.clear()
	var bs: BuildingSystem = jeu.buildings
	var tr: TransportSystem = jeu.transport
	var w: TerrainWorld = jeu.world
	var t := String(a.get("t", ""))
	var refus := ""
	match t:
		"poser":
			var c := Vector2i(int(a.c[0]), int(a.c[1]))
			_forcer_payeur(pid, Vector2(c.x + 0.5, c.y + 0.5))
			if String(a.get("nom", "")) != "":
				jeu.communes.nom_en_attente = String(a.nom).substr(0, 40)
			var bid := bs.place(String(a.get("id", "")), c, int(a.get("r", 0)), 0, float(a.get("a", 0.0)))
			var perso: Dictionary = a.get("perso", {})
			if bid >= 0 and (not perso.is_empty() or int(a.get("v", -1)) >= 0):
				bs.set_perso(bid, perso, int(a.get("v", -1)))
		"demolir":
			var c := Vector2i(int(a.c[0]), int(a.c[1]))
			var bid := bs.building_at(c)
			if bid < 0:
				bid = int(a.get("bid", -1))
			if bid < 0 or not bs.buildings.has(bid):
				refus = "Plus rien à démolir ici."
			else:
				bs.demolish(bid)
		"voie":
			var path: PackedVector2Array = a.get("path", PackedVector2Array())
			if path.size() < 2:
				refus = "Tracé trop court."
			else:
				_forcer_payeur(pid, (path[0] + path[path.size() - 1]) * 0.5)
				_rejeu = true
				var res: Dictionary = tr.build_path(String(a.get("id", "")), a.get("spec", {}), path)
				_rejeu = false
				if res.ok:
					tr.edges_built.emit(res.edges)
					_a_tous({"m": "rejouer", "a": a})
					_messages.append(tr._describe(res, true))
				else:
					refus = String(res.reason)
		"voie_demolir":
			var eid := int(a.get("eid", -1))
			if tr.network.edges.has(eid):
				_rejeu = true
				tr.demolish(eid)
				_rejeu = false
				_a_tous({"m": "rejouer", "a": a})
		"carrefour":
			_rejeu = true
			var txt := tr.appliquer_carrefour(String(a.get("action", "")), a.get("p", Vector3.ZERO), bool(a.get("maj", false)))
			_rejeu = false
			_a_tous({"m": "rejouer", "a": a})
			if txt != "":
				_messages.append(txt)
		"terrain":
			w.appliquer_outil(int(a.get("outil", 0)), a.get("a", Vector2i.ZERO), a.get("b", Vector2i.ZERO))
		"pinceau":
			w.appliquer_pinceau(a)
		_:
			refus = "Action inconnue du serveur : %s." % t
	Pays.payeur_force = -1
	_en_cours = false
	_auteur = ""
	_sale = true
	if refus != "":
		return refus
	return String(_messages[_messages.size() - 1]) if not _messages.is_empty() else ""


## Hors de ses villes, c'est la caisse du joueur qui paie.
func _forcer_payeur(pid: String, p: Vector2) -> void:
	Pays.payeur_force = -1
	var vid: int = jeu.communes.village_au_point(p.x, p.y)
	if vid >= 0 and carte.maire_de(vid) == pid:
		return
	Pays.payeur_force = carte.caisse_principale(pid)


## Un village fondé pendant l'action d'un joueur : il en est le maire, et sa caisse
## personnelle rejoint celle de sa première ville.
func _on_fonde(vid: int) -> void:
	var pid := _auteur if _auteur != "" else carte.createur
	carte.maires[vid] = pid
	var pays: Pays = jeu.pays
	if carte.villes_de(pid).size() == 1:
		var kp := carte.cle_personnelle(pid)
		var reste := pays.solde(kp)
		if reste > 0:
			pays._poser(kp, 0)
			pays._poser(vid, pays.solde(vid) + reste)
	_sale = true
	_envoyer_joueurs.call_deferred()


# --- Envois réguliers -----------------------------------------------------------------------

## Bâtiment tel qu'il part chez les joueurs (comme dans la sauvegarde).
static func batiment_pour_envoi(b: Dictionary) -> Dictionary:
	var e := b.duplicate(true)
	return e


func _envoyer_batiments() -> void:
	if _evts_bat.is_empty():
		return
	var bs: BuildingSystem = jeu.buildings
	var liste := []
	for ev in _evts_bat:
		var bid := int(ev[1])
		match String(ev[0]):
			"+", "~":
				if bs.buildings.has(bid):
					var e := {"o": ev[0], "b": batiment_pour_envoi(bs.buildings[bid])}
					# Bâtiment fondateur d'un village : son nom, pour que chacun fonde le même.
					for vid in jeu.communes.villages:
						if int(jeu.communes.villages[vid].bid) == bid:
							e["village"] = String(jeu.communes.villages[vid].nom)
					liste.append(e)
			"-":
				liste.append({"o": "-", "bid": bid})
	_evts_bat.clear()
	_a_tous({"m": "bat", "l": liste})


func _init_ombres() -> void:
	for t in TABLES_TERRAIN:
		_ombres[t] = (jeu.world.get(t) as Dictionary).duplicate()


## Cases du terrain changées depuis le dernier envoi.
func _envoyer_terrain() -> void:
	_terrain_sale = false
	_terrain_t = 0.0
	var msg := {"m": "terrain"}
	var rien := true
	for t in TABLES_TERRAIN:
		var cur: Dictionary = jeu.world.get(t)
		var avant: Dictionary = _ombres[t]
		var mis := []
		var otes := []
		for c in cur:
			if not avant.has(c) or avant[c] != cur[c]:
				mis.append([c.x, c.y, cur[c]])
		if cur.size() - mis.size() != avant.size():
			for c in avant:
				if not cur.has(c):
					otes.append([c.x, c.y])
		if not mis.is_empty() or not otes.is_empty():
			msg[t] = {"mis": mis, "otes": otes}
			rien = false
			_ombres[t] = cur.duplicate()
	if not rien:
		_a_tous(msg)


## Empreintes comparées par chaque jeu pour savoir s'il est resté à jour.
func empreintes() -> Dictionary:
	var bs: BuildingSystem = jeu.buildings
	var net: TransportNetwork = jeu.transport.network
	return {"b": [bs.buildings.size(), bs.next_id], "r": [net.edges.size(), net.nodes.size(), net.next_id],
		"v": jeu.communes.villages.size()}


func _envoyer_tic() -> void:
	var pays: Pays = jeu.pays
	var caisses := {}
	for k in pays.cles():
		caisses[int(k)] = pays.solde(k)
	var vus := {}
	for id in connectes:
		if bool(connectes[id].ok):
			var kp := carte.cle_personnelle(String(connectes[id].pid))
			caisses[kp] = pays.solde(kp)
	var base := {"m": "tic", "t": jeu.ambiance.unix_time, "v": jeu.ambiance.speed_index, "caisses": caisses,
		"sig": empreintes(), "illimite": jeu.buildings.unlimited_money}
	for id in connectes:
		if bool(connectes[id].ok):
			var msg := base.duplicate()
			var pid := String(connectes[id].pid)
			msg["ma"] = carte.caisse_principale(pid)
			msg["villes"] = carte.villes_de(pid)
			_envoyer(id, msg)
			vus[pid] = true
	var now := int(Time.get_unix_time_from_system())
	for pid in vus:
		carte.membres[pid].vu = now


## Section « multijoueur » de la sauvegarde du serveur (membres, code, caisses personnelles).
func to_dict() -> Dictionary:
	var pays: Pays = jeu.pays
	var cs := {}
	for pid in carte.membres:
		var kp := carte.cle_personnelle(pid)
		if pays.comptes.has(kp) or pays.actif == kp:
			cs[kp] = pays.solde(kp)
	return carte.to_dict(cs)
