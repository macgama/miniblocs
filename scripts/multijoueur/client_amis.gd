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
## Entré en visiteur : on regarde sans construire (VisiteVille.en_ligne).
var visiteur := false
## Admin : les inconnus peuvent-ils visiter sans code ?
var visites_ouvertes := false
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

# Sections partagées (zones, éditeur libre, décors, réseaux… voir SectionsPartagees).
## Délai après le dernier geste du joueur avant d'envoyer ce qu'il a changé (s).
const ENVOI_APRES := 0.3
## Vérification régulière, même sans geste (s).
const VERIF_SECTIONS := 5.0
var specs: Dictionary = {}
## Section → dernière version connue du serveur, à plat (avec nos envois).
var bases: Dictionary = {}
var envois_sections := 0
var _envoi_t := -1.0
var _verif_t := 0.0
var _argent_avant: Dictionary = {}
var _depense: Dictionary = {}
var _ecarts_sections: Dictionary = {}
var _demande_section: Dictionary = {}
## Sections changées depuis la dernière comparaison (signal « changed » de leur système).
var _sales: Dictionary = {}
var _complet_t := 0.0
## Systèmes gérés par le serveur (SystemesGeres : clubs, parc, zoo, musée).
var geres: Dictionary = {}
var etats_recus := 0
## Comparaison complète, même sans signal (s).
const VERIF_COMPLETE := 30.0


func _init() -> void:
	name = "ClientAmis"
	process_mode = Node.PROCESS_MODE_ALWAYS


func connecter(adresse: String, code_invitation: String, nom_joueur: String, en_visiteur := false) -> String:
	visiteur = en_visiteur
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
			_envoyer({"m": "bonjour", "version": Protocole.VERSION, "pid": pid, "pseudo": pseudo, "code": code, "visiteur": visiteur}))
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
	if e == "deconnecte" and visiteur:
		visiteur = false
		VisiteVille.en_ligne = false
		VisiteVille.en_cours = {}
	etat_change.emit(e, texte)


func _envoyer(msg: Dictionary) -> void:
	if peer == null or peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	peer.set_target_peer(1)
	peer.set_transfer_mode(MultiplayerPeer.TRANSFER_MODE_RELIABLE)
	peer.transfer_channel = 0
	peer.put_packet(Protocole.encoder(msg))


func envoyer_action(a: Dictionary) -> void:
	# Visiteur : rien ne part (le serveur refuserait de toute façon).
	if visiteur:
		return
	_envoyer({"m": "action", "a": a})


func envoyer_carte(c: Dictionary) -> void:
	_envoyer({"m": "carte_postale", "carte": c})


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
		_surveiller_sections(delta)


func _recevoir(msg: Dictionary) -> void:
	match String(msg.get("m", "")):
		"refus":
			_perdu.call_deferred(String(msg.get("raison", "Entrée refusée.")))
		"bienvenue":
			admin = bool(msg.get("admin", false))
			nom_carte = String(msg.get("carte", ""))
			code_carte = String(msg.get("code", ""))
			pseudo = String(msg.get("pseudo", pseudo))
			visiteur = bool(msg.get("visiteur", false))
			visites_ouvertes = bool(msg.get("visites_ouvertes", false))
			if visiteur:
				VisiteVille.en_ligne = true
				VisiteVille.en_cours = {"ville": nom_carte, "titre": nom_carte, "auteur": "", "partie": ""}
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
		specs = SectionsPartagees.specs(jeu)
		_reprendre_bases()
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
	specs = SectionsPartagees.specs(jeu)
	_reprendre_bases()
	# Clubs, parc, zoo, musée : le serveur les simule ; les clubs ne jouent pas ici.
	geres = SystemesGeres.specs(jeu)
	for nom in geres:
		if not bool(geres[nom].get("simule", true)) and geres[nom].obj is Node:
			(geres[nom].obj as Node).set_process(false)
	if not get_tree().process_frame.is_connected(_apres_gestes):
		get_tree().process_frame.connect(_apres_gestes)
	_changer("en_jeu", "Sur la carte « %s »." % nom_carte)
	if visiteur and jeu.has_method("_debut_visite"):
		jeu._debut_visite()
	jeu.hud.show_message("Carte entre amis « %s » : F3 pour les joueurs et la discussion." % nom_carte)
	_appliquer_tampon()


func _detacher() -> void:
	if get_tree() != null and get_tree().process_frame.is_connected(_apres_gestes):
		get_tree().process_frame.disconnect(_apres_gestes)
	specs = {}
	bases = {}
	if not is_instance_valid(jeu):
		geres = {}
		return
	for nom in geres:
		if is_instance_valid(geres[nom].obj) and geres[nom].obj is Node:
			(geres[nom].obj as Node).set_process(true)
	geres = {}
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
	# Création de l'Atelier, de l'éditeur libre ou du parc : sa définition part avec.
	if String(a.get("t", "")) == "poser":
		var defs := SectionsPartagees.definition(String(a.get("id", "")))
		if not defs.is_empty():
			a["defs"] = defs
	envoyer_action(a)


## Applique un message du serveur à la partie ouverte.
func appliquer(msg: Dictionary) -> void:
	match String(msg.get("m", "")):
		"carte_postale":
			var cr: Variant = jeu.get("courrier")
			if cr is Courrier:
				(cr as Courrier).recevoir(msg.get("carte"))
		"bat":
			_bat(msg.get("l", []))
		"rejouer":
			_rejouer(msg.get("a", {}), String(msg.get("par", "")), msg.get("diff"))
		"terrain":
			_terrain(msg)
		"section":
			if String(msg.get("nom", "")) == "transport":
				var d: Variant = msg.get("data")
				if d is Dictionary:
					jeu.transport.from_dict(d)
		"sections":
			_patch_section(String(msg.get("nom", "")), msg.get("patch", {}))
		"section_partagee":
			_section_entiere(String(msg.get("nom", "")), msg.get("data", {}))
		"appel":
			rejouer_appel(msg.get("a", {}))
		"etat":
			var nom := String(msg.get("nom", ""))
			var d: Variant = msg.get("data")
			if geres.has(nom) and d is Dictionary:
				SystemesGeres.appliquer(geres[nom], d)
				etats_recus += 1
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
				if e.has("defs"):
					SectionsPartagees.adopter(e.defs)
				bs.restore(b)
				bs.next_id = maxi(bs.next_id, bid + 1)
			"~":
				var b: Dictionary = e.b
				var bid := int(b.id)
				if bs.buildings.has(bid):
					if e.has("defs"):
						SectionsPartagees.adopter(e.defs)
					var mien: Dictionary = bs.buildings[bid]
					var niv_avant := int(mien.get("niv", 1))
					# Niveau d'agrandissement, rénovation et travaux en cours (Ameliorations).
					for k in ["niv", "renov", "amel"]:
						if b.has(k):
							mien[k] = b[k]
						else:
							mien.erase(k)
					var am: Ameliorations = jeu.get("ameliorations")
					if JSON.stringify(b.get("perso", {})) == JSON.stringify(mien.get("perso", {})) and int(b.get("v", -1)) in [-1, int(mien.get("v", 0))]:
						if am != null:
							am.depuis_reseau(bid, niv_avant)
					else:
						bs.set_perso(bid, b.get("perso", {}), int(b.get("v", -1)))
			"-":
				var bid := int(e.bid)
				if bs.buildings.has(bid):
					bs.remove_quietly(bid)
	bs._par_reseau = avant
	bs._refresh()


func _rejouer(a: Dictionary, par := "", diff_serveur: Variant = null) -> void:
	var tr: TransportSystem = jeu.transport
	var avant := tr._par_reseau
	tr._par_reseau = true
	# Ctrl+Z : ce que ce joueur a fait lui-même entre dans son historique.
	var mien := par != "" and par == pid and HistoriqueVille.instance != null
	var photo := tr.photo_reseau() if mien else {}
	match String(a.get("t", "")):
		"voie_histo":
			var d: Variant = a.get("d")
			if d is Dictionary and (d as Dictionary).has("e_plus"):
				tr.appliquer_diff(d, bool(a.get("annuler", true)))
		"voie":
			# La profondeur du tunnel vient du serveur (pas de l'outil ouvert ici).
			var avant_prof := RoutePlanner.profondeur_forcee
			var prof := float(a.get("prof", NAN))
			RoutePlanner.profondeur_forcee = prof
			var res: Dictionary = tr.build_path(String(a.get("id", "")), a.get("spec", {}), a.get("path", PackedVector2Array()))
			RoutePlanner.profondeur_forcee = avant_prof
			if res.ok:
				tr.edges_built.emit(res.edges)
				if not is_nan(prof) and jeu.get("construction_souterraine") != null:
					jeu.construction_souterraine.appliquer_tunnel(res.edges, prof, false)
		"voie_demolir":
			tr.demolish(int(a.get("eid", -1)))
		"carrefour":
			tr.appliquer_carrefour(String(a.get("action", "")), a.get("p", Vector3.ZERO), bool(a.get("maj", false)))
	tr._par_reseau = avant
	if mien:
		var d: Dictionary = diff_serveur if diff_serveur is Dictionary else tr.diff_reseau(photo, tr.photo_reseau())
		if not TransportSystem.diff_vide(d):
			var nom := "Démolition : voie" if String(a.get("t", "")) == "voie_demolir" else String(TransportTypes.get_type(String(a.get("id", ""))).get("name", "Voie"))
			HistoriqueVille.instance.noter(nom, {"k": "mp_voies", "diff": d})


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
	_comparer_sections(msg.get("sec", {}))
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


# --- Sections partagées ---------------------------------------------------------------------

func _reprendre_bases() -> void:
	bases = {}
	_sales = {}
	for nom in specs:
		var o: Object = specs[nom].obj
		if o.has_signal("changed") and not o.is_connected("changed", _marquer_sale.bind(nom)):
			o.connect("changed", _marquer_sale.bind(nom))
		bases[nom] = SectionsPartagees.normaliser(SectionsPartagees.lire(specs[nom]), specs[nom])
	_envoi_t = -1.0
	_depense.clear()


## Un geste du joueur (clic, touche) : on note les caisses, puis on enverra ce qui a changé.
func _input(event: InputEvent) -> void:
	if etat != "en_jeu" or not is_instance_valid(jeu):
		return
	if event is InputEventMouseButton or event is InputEventKey or (event is InputEventMouseMotion and (event as InputEventMouseMotion).button_mask != 0):
		if _argent_avant.is_empty():
			_argent_avant = _soldes()
		_envoi_t = ENVOI_APRES


func _soldes() -> Dictionary:
	var out := {}
	var pays: Pays = jeu.pays
	for k in pays.cles():
		out[int(k)] = pays.solde(k)
	out[pays.actif] = pays.solde(pays.actif)
	return out


## Fin du traitement des gestes de l'image (avant la simulation) : ce qu'ils ont coûté.
func _apres_gestes() -> void:
	if _argent_avant.is_empty() or not is_instance_valid(jeu):
		_argent_avant = {}
		return
	var apres := _soldes()
	for k in _argent_avant:
		var d := int(_argent_avant[k]) - int(apres.get(k, _argent_avant[k]))
		if d != 0:
			_depense[k] = int(_depense.get(k, 0)) + d
	_argent_avant = {}


func _marquer_sale(nom: String) -> void:
	_sales[nom] = true


func _surveiller_sections(delta: float) -> void:
	if specs.is_empty():
		return
	_verif_t += delta
	_complet_t += delta
	if _complet_t >= VERIF_COMPLETE:
		_complet_t = 0.0
		for nom in specs:
			_sales[nom] = true
	if _envoi_t >= 0.0:
		_envoi_t -= delta
		if _envoi_t < 0.0:
			envoyer_sections()
	elif _verif_t >= VERIF_SECTIONS:
		envoyer_sections()


## Envoie au serveur ce que le joueur a changé dans les sections partagées.
func envoyer_sections() -> void:
	_verif_t = 0.0
	_envoi_t = -1.0
	for nom in specs:
		_valider(nom)
	# Une dépense sans changement à envoyer (refusée en local) ne compte pas.
	_depense.clear()


func _valider(nom: String) -> void:
	if not specs.has(nom) or not bool(_sales.get(nom, true)):
		return
	_sales[nom] = false
	var spec: Dictionary = specs[nom]
	var brut := SectionsPartagees.lire(spec)
	var cur := SectionsPartagees.normaliser(brut, spec)
	var base: Dictionary = bases.get(nom, {})
	var p := SectionsPartagees.difference(base, cur)
	if SectionsPartagees.vide(p):
		return
	p["nouveaux"] = SectionsPartagees.nouveaux(base, p)
	var comp := SectionsPartagees.complets(brut, p, spec)
	if not comp.is_empty():
		p["complets"] = comp
	if not _depense.is_empty():
		p["depense"] = _depense.duplicate()
		_depense.clear()
	bases[nom] = cur
	envois_sections += 1
	envoyer_action({"t": "sections", "nom": nom, "patch": p})


## Changement d'une section venu du serveur.
func _patch_section(nom: String, p: Variant) -> void:
	if not specs.has(nom) or not p is Dictionary:
		return
	# Ce que le joueur vient de faire part d'abord (sinon il serait pris pour l'ancien état).
	_valider(nom)
	var spec: Dictionary = specs[nom]
	var brut := SectionsPartagees.lire(spec)
	var cur := SectionsPartagees.normaliser(brut, spec)
	if not SectionsPartagees.deja_applique(cur, p, spec):
		var d := SectionsPartagees.appliquer(brut, p, spec, (p as Dictionary).get("complets", {}))
		_ecrire_section(spec, d)
		cur = SectionsPartagees.normaliser(SectionsPartagees.lire(spec), spec)
	bases[nom] = cur
	_sales[nom] = false


func _section_entiere(nom: String, d: Variant) -> void:
	if not specs.has(nom) or not d is Dictionary:
		return
	_ecrire_section(specs[nom], d)
	bases[nom] = SectionsPartagees.normaliser(SectionsPartagees.lire(specs[nom]), specs[nom])
	_sales[nom] = false
	_ecarts_sections.erase(nom)


func _ecrire_section(spec: Dictionary, d: Dictionary) -> void:
	var avant := Multijoueur.rejeu
	Multijoueur.rejeu = true
	(spec.ecrire as Callable).call(d)
	Multijoueur.rejeu = avant


## Empreintes des sections du serveur : deux écarts de suite → la section entière.
func _comparer_sections(sec: Dictionary) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for nom in sec:
		if not bases.has(nom):
			continue
		if SectionsPartagees.empreinte(bases[nom]) == int(sec[nom]):
			_ecarts_sections.erase(nom)
			continue
		_ecarts_sections[nom] = int(_ecarts_sections.get(nom, 0)) + 1
		if int(_ecarts_sections[nom]) >= 2 and now - float(_demande_section.get(nom, -1000.0)) > RESYNC_MIN:
			_demande_section[nom] = now
			_ecarts_sections.erase(nom)
			_envoyer({"m": "section", "nom": nom})


# --- Appels rejoués (budget, lignes, pilote automatique) ------------------------------------

## Un réglage ou une commande fait par un joueur, rejoué ici tel que le serveur l'a fait.
func rejouer_appel(a: Dictionary) -> void:
	if not is_instance_valid(jeu):
		return
	var avant := Multijoueur.rejeu
	Multijoueur.rejeu = true
	Multijoueur.executer_appel(jeu, a)
	Multijoueur.rejeu = avant
