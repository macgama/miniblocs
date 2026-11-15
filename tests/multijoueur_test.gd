extends SceneTree
## Test de la carte entre amis : messages, invitations et caisses, puis un vrai
## serveur sans écran lancé dans un autre processus, deux joueurs, la partie d'un
## joueur ouverte et synchronisée (village, route, maison, démolition, terrain,
## vitesse, discussion), arrêt et reprise du serveur.
## Usage : godot --headless --path . --script res://tests/multijoueur_test.gd

const PORT := 24781
const CODE := "ABCD-EFGH"

var ok := true
var _serveur_pid := -1
var _slot_serveur := ""


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	if not cond:
		push_error("ÉCHEC : " + what)
		ok = false
	else:
		print("  ok  ", what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## Attend que cond() soit vrai (au plus s secondes).
func _attendre(cond: Callable, s := 15.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < s * 1000.0:
		if cond.call():
			return true
		await process_frame
	return bool(cond.call())


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


func _lancer_serveur(args: Array) -> void:
	var a := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "--", "--serveur",
		"--port", str(PORT), "--terrain-plat"])
	a.append_array(PackedStringArray(args))
	_serveur_pid = OS.create_process(OS.get_executable_path(), a)


func _arreter_serveur() -> void:
	if _serveur_pid > 0 and OS.is_process_running(_serveur_pid):
		OS.kill(_serveur_pid)
	_serveur_pid = -1


func _client(pid: String, pseudo: String, code: String) -> ClientAmis:
	var c := ClientAmis.new()
	c.pid_impose = pid
	c.ouvrir_partie = false
	root.add_child(c)
	c.connecter("127.0.0.1:%d" % PORT, code, pseudo)
	return c


func _run() -> void:
	_unitaires()
	await _en_ligne()
	_arreter_serveur()
	_effacer(_slot_serveur)
	print("RÉSULTAT : ", "OK" if ok else "ÉCHEC")
	quit(0 if ok else 1)


func _effacer(slot: String) -> void:
	if slot == "":
		return
	var dir := SaveGame.DIR.path_join(slot)
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		d.remove(f)
	DirAccess.remove_absolute(dir)


func _unitaires() -> void:
	print("Messages :")
	var msg := {"m": "bat", "l": [{"o": "+", "b": {"id": 3, "t": "maison", "x": 4, "perso": {"toit": 2}}}], "v": Vector2i(3, 4)}
	_check(Protocole.decoder(Protocole.encoder(msg)) == msg, "petit message : aller-retour")
	var gros := {"m": "terrain", "mis": []}
	for i in 5000:
		gros.mis.append([i, -i, 41.5])
	var oct := Protocole.encoder(gros)
	_check(oct[0] == 1 and oct.size() < var_to_bytes(gros).size() / 3 and Protocole.decoder(oct) == gros, "gros message compressé (%d octets)" % oct.size())
	_check(Protocole.decoder(PackedByteArray([7, 1, 2])).is_empty(), "octets illisibles : message vide")
	var big := {"sections": {"terrain": {"modifs": range(200000)}}}
	var morceaux := Protocole.decouper(big)
	_check(morceaux.size() >= 1 and (Protocole.recoller(morceaux).sections.terrain.modifs as Array).size() == 200000, "instantané en %d morceau(x)" % morceaux.size())
	_check(Protocole.lire_adresse("192.168.1.20") == ["192.168.1.20", Protocole.PORT_DEFAUT], "adresse sans port")
	_check(Protocole.lire_adresse(" serveur.fr:3000 ") == ["serveur.fr", 3000], "adresse avec port")
	_check(Protocole.lire_adresse("[::1]:4000") == ["::1", 4000], "adresse IPv6")

	print("Invitations et caisses :")
	var c := CarteAmis.new()
	c.creer("Annecy", "createur-0001")
	_check(c.code.length() == 9 and c.code[4] == "-", "code d'invitation : %s" % c.code)
	_check(CarteAmis.normaliser_code(c.code.to_lower().replace("-", " ")) == c.code, "code tapé en minuscules avec espace")
	_check(c.accepter("createur-0001", "Gaël", "", 100).ok and c.est_admin("createur-0001"), "le créateur entre sans code et est admin")
	_check(not c.accepter("ami-00000002", "Léa", "XXXX-XXXX", 100).ok, "mauvais code refusé")
	var r := c.accepter("ami-00000002", "  Léa  ", c.code, 100)
	_check(r.ok and r.nouveau and c.pseudo("ami-00000002") == "Léa" and not c.est_admin("ami-00000002"), "bon code : Léa entre, joueuse")
	c.code = CarteAmis.nouveau_code()
	_check(c.accepter("ami-00000002", "Léa", "", 200).ok, "membre : plus besoin du code")
	_check(c.cle_personnelle("ami-00000002") == Pays.JOUEUR_BASE - 2 and Pays.est_caisse_joueur(c.cle_personnelle("ami-00000002")), "caisse personnelle de Léa")
	_check(c.caisse_principale("ami-00000002") == c.cle_personnelle("ami-00000002"), "sans ville : sa caisse personnelle paie")
	c.maires[7] = "ami-00000002"
	c.maires[3] = "ami-00000002"
	_check(c.caisse_principale("ami-00000002") == 3, "maire : sa première ville paie")
	c.exclure("ami-00000002")
	_check(not c.accepter("ami-00000002", "Léa", c.code, 300).ok, "exclue : refusée même avec le code")
	var c2 := CarteAmis.new()
	var cs := c2.from_dict(c.to_dict({Pays.JOUEUR_BASE - 1: 1234}))
	_check(c2.code == c.code and c2.createur == c.createur and c2.exclus.has("ami-00000002") and int(cs[Pays.JOUEUR_BASE - 1]) == 1234, "section de sauvegarde : aller-retour")
	var c3 := CarteAmis.new()
	c3.creer("Neuve", "")
	_check(c3.accepter("premier-00001", "Max", c3.code, 1).ok and c3.createur == "premier-00001", "nouvelle carte sans créateur : le premier entré est admin")
	var o := Multijoueur.lire_options(PackedStringArray(["--serveur", "--partie", "annecy-1", "--port", "99999", "--terrain-plat"]))
	_check(o.serveur == true and o.partie == "annecy-1" and o.port == 65535 and o.has("terrain-plat"), "options de la ligne de commande")


func _en_ligne() -> void:
	print("Serveur sans écran :")
	_lancer_serveur(["--nouvelle", "--lat", "48.85", "--lon", "2.29", "--nom", "Test", "--code", CODE])
	_check(_serveur_pid > 0, "serveur lancé (processus %d)" % _serveur_pid)
	# Mauvais code : refusé.
	var intrus := _client("intrus-000001", "Intrus", "ZZZZ-ZZZZ")
	var refuse := await _attendre(func() -> bool: return intrus.etat == "deconnecte" and intrus.peer == null, 40.0)
	_check(refuse and intrus.nom_carte == "", "mauvais code : refusé")
	intrus.queue_free()
	var a := _client(SaveGame.player_id(), "Alice", CODE.to_lower())
	_check(await _attendre(func() -> bool: return a.etat == "pret", 30.0), "Alice entre et reçoit la carte (%s)" % a.etat)
	_check(a.admin and a.code_carte == CODE, "Alice, première entrée, est l'admin et voit le code")
	_check((a.dernier_instantane.sections as Dictionary).has("batiments") and not (a.dernier_instantane.sections as Dictionary).has("multijoueur"), "instantané : la partie sans la section du serveur")
	_check(SaveGame.exists(a.slot), "carte reçue enregistrée en local : %s" % a.slot)

	print("Partie d'Alice :")
	Creations.persist = false
	GameStart.chosen = true
	GameStart.atelier = false
	GameStart.load_slot = a.slot
	Multijoueur.role = Multijoueur.Role.CLIENT
	Multijoueur.client = a
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.set_origin(48.85, 2.29)
	var bs: BuildingSystem = scene.buildings
	_check(a.etat == "en_jeu" and bs.verrou_reseau and bs.relais.is_valid() and scene.transport.relais.is_valid(), "partie ouverte, branchée sur le serveur")
	_check(await _attendre(func() -> bool: return a.ma_caisse != 0, 5.0), "caisse d'Alice reçue")
	_check(Pays.est_caisse_joueur(a.ma_caisse) and bs.money == ReglagesPartie.actuel.argent_depart, "sans ville : caisse personnelle de %s" % BuildingSystem.format_money(bs.money))
	_check(bs.place("maison", Vector2i(10, 10), 0) == -1 and bs.buildings.is_empty(), "rien ne se pose en local sans le serveur")

	# Fonder un village : la Maison de commune part au serveur, revient chez Alice.
	scene.communes.nom_en_attente = "Testville"
	bs.relais.call({"t": "poser", "id": "maison_commune", "c": [0, 0], "r": 0, "a": 0.0, "perso": {}, "v": -1})
	_check(await _attendre(func() -> bool: return scene.communes.villages.size() == 1, 25.0), "Maison de commune posée par le serveur")
	var vid: int = scene.communes.villages.keys()[0] if not scene.communes.villages.is_empty() else -1
	_check(vid >= 0 and String(scene.communes.villages[vid].nom) == "Testville", "village « Testville » chez Alice aussi")
	_check(await _attendre(func() -> bool: return a.mes_villes.has(vid) and a.ma_caisse == vid, 5.0), "Alice est maire : sa caisse est celle de Testville")

	# Une route, puis une maison au bord.
	scene.transport.relais.call({"t": "voie", "id": "departementale", "spec": {}, "path": PackedVector2Array([Vector2(-80, 40), Vector2(80, 40)])})
	_check(await _attendre(func() -> bool: return scene.transport.network.edges.size() > 0, 10.0), "route tracée chez tout le monde (%d tronçon(s))" % scene.transport.network.edges.size())
	var nb := bs.buildings.size()
	bs.relais.call({"t": "poser", "id": "maison", "c": [20, 52], "r": 0, "a": 0.0, "perso": {}, "v": -1})
	_check(await _attendre(func() -> bool: return bs.buildings.size() > nb, 10.0), "maison posée par le serveur")
	var maison := -1
	for bid in bs.buildings:
		if String(bs.buildings[bid].t) == "maison":
			maison = int(bid)
	await _attendre(func() -> bool: return false, 2.5)
	_check(a.resynchros == 0 and a._ecarts == 0, "empreintes identiques : pas de resynchronisation")

	print("Deuxième joueur :")
	var b := _client("bob-00000002", "Bob", CODE)
	_check(await _attendre(func() -> bool: return b.etat == "pret", 30.0), "Bob entre avec le code")
	_check(not b.admin and b.code_carte == "", "Bob est joueur et ne voit pas le code")
	var bats: Array = b.dernier_instantane.sections.batiments.buildings
	_check(bats.any(func(e: Dictionary) -> bool: return String(e.t) == "maison"), "la carte de Bob a la maison d'Alice")
	_check(await _attendre(func() -> bool: return a.joueurs.size() == 2, 5.0), "Alice voit 2 joueurs")
	var recu := []
	b.chat_recu.connect(func(de: String, t: String) -> void: recu.append([de, t]))
	a.envoyer_chat("Salut Bob !")
	_check(await _attendre(func() -> bool: return recu.any(func(e: Array) -> bool: return e[0] == "Alice" and e[1] == "Salut Bob !"), 5.0), "discussion : Bob reçoit le message d'Alice")
	var infos := []
	b.info_recue.connect(func(t: String) -> void: infos.append(t))
	b.envoyer_admin("code")
	_check(await _attendre(func() -> bool: return not infos.is_empty(), 5.0) and String(infos[0]).begins_with("Seul l'admin"), "Bob ne peut pas changer le code")
	var bob_poses := []
	b.envoyer_action({"t": "poser", "id": "maison", "c": [-30, 52], "r": 0, "a": 0.0, "perso": {}, "v": -1})
	_check(await _attendre(func() -> bool: return bs.buildings.size() > nb + 1, 10.0), "la maison de Bob apparaît chez Alice")
	var avant_bob := bs.money
	await _attendre(func() -> bool: return false, 1.5)
	_check(bs.money == avant_bob, "la maison de Bob n'est pas payée par la caisse d'Alice")

	print("Temps, démolition, terrain :")
	scene.ambiance.set_speed(3)
	_check(await _attendre(func() -> bool: return b._vitesse_serveur == 3, 5.0), "l'admin change la vitesse pour tous")
	bs.relais.call({"t": "demolir", "bid": maison, "c": [20, 52]})
	_check(await _attendre(func() -> bool: return not bs.buildings.has(maison), 10.0), "maison démolie par le serveur")
	scene.world.relais.call({"t": "terrain", "outil": int(TerrainWorld.Tool.RAISE), "a": Vector2i(300, 300), "b": Vector2i(302, 302)})
	_check(await _attendre(func() -> bool: return scene.world.modifications.has(Vector2i(301, 301)), 10.0), "terrain monté d'un mètre chez Alice")
	_check(absf(float(scene.world.modifications.get(Vector2i(301, 301), 0.0)) - 41.0) < 0.01, "hauteur reçue : 41 m")

	print("Arrêt et reprise :")
	var nbats := bs.buildings.size()
	a.envoyer_admin("arreter")
	_check(await _attendre(func() -> bool: return not OS.is_process_running(_serveur_pid), 20.0), "l'admin arrête le serveur")
	_check(await _attendre(func() -> bool: return a.etat == "deconnecte", 10.0), "Alice est prévenue")
	_check(not bs.verrou_reseau and Multijoueur.role == Multijoueur.Role.SOLO, "la partie d'Alice repasse hors ligne")
	b.queue_free()
	for m in SaveGame.list_saves():
		if String(m.get("nom", "")) == "Test" and not String(m.id).begins_with("amis-"):
			_slot_serveur = String(m.id)
	_check(_slot_serveur != "", "carte sauvegardée par le serveur : %s" % _slot_serveur)
	scene.queue_free()
	await _frames(3)
	_lancer_serveur(["--partie", _slot_serveur])
	var a2 := _client(SaveGame.player_id(), "Alice", "")
	_check(await _attendre(func() -> bool: return a2.etat == "pret", 40.0), "Alice revient sans code (membre)")
	_check(a2.admin and a2.code_carte == CODE, "toujours admin, même code")
	var sec: Dictionary = a2.dernier_instantane.sections
	_check((sec.batiments.buildings as Array).size() == nbats and (sec.communes.villages as Array).size() >= 1, "la carte a gardé ses %d bâtiments et son village" % nbats)
	a2.deconnecter()
	_effacer(a.slot)
	_effacer(a2.slot)
