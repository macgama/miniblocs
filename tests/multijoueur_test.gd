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
		"--port", str(PORT), "--terrain-plat", "--tout-debloque"])
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
	if OS.get_environment("MJ_GARDER") == "":
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
	_unitaires_sections()
	var o := Multijoueur.lire_options(PackedStringArray(["--serveur", "--partie", "annecy-1", "--port", "99999", "--terrain-plat"]))
	_check(o.serveur == true and o.partie == "annecy-1" and o.port == 65535 and o.has("terrain-plat"), "options de la ligne de commande")


func _unitaires_sections() -> void:
	print("Sections partagées (à plat, différences) :")
	var spec := {"coll": {"zones": {"genre": "liste", "cle": "id", "ids": true}, "blocks": {"genre": "plat", "pas": 4},
		"poses": {"genre": "ensemble"}, "elec/troncons": {"genre": "dico", "ids": true}},
		"champs": ["av"], "compteurs": ["next_id"], "ignorer": ["growth", "stocks"]}
	var a := {"next_id": 3, "growth": true, "stocks": {"1": 5.0}, "style": "alpin",
		"zones": [{"id": 1, "k": "R"}, {"id": 2, "k": "C"}], "blocks": [0, 0, 0, 7, 1, 0, 0, 8],
		"poses": [["arbre", 1.0, 2.0]], "elec": {"next": 2, "troncons": {"1": {"t": "ligne_mt", "av": 0.5}}}}
	var pa := SectionsPartagees.normaliser(a, spec)
	_check(pa.has("zones#1") and pa.has("blocks#" + var_to_str([1, 0, 0])) and pa.has("elec/next") and not pa.has("growth") and not pa.has("stocks"), "mise à plat : une entrée par objet, sans le simulé")
	_check(not (pa["elec/troncons#1"] as Dictionary).has("av"), "champ simulé (chantier) hors comparaison")
	var b := a.duplicate(true)
	b.zones.append({"id": 3, "k": "I"})
	b.next_id = 4
	b.blocks = [1, 0, 0, 9]
	b.poses.append(["rocher", 3.0, 4.0])
	b.elec.troncons["1"]["av"] = 0.9
	var pb := SectionsPartagees.normaliser(b, spec)
	var p := SectionsPartagees.difference(pa, pb)
	_check((p.mis as Dictionary).has("zones#3") and (p.mis as Dictionary).has("blocks#" + var_to_str([1, 0, 0])) and (p.otes as Array).has("blocks#" + var_to_str([0, 0, 0])) and not (p.mis as Dictionary).has("elec/troncons#1"),
		"différence : zone ajoutée, bloc changé, bloc ôté, chantier ignoré (%d mis, %d ôtés)" % [(p.mis as Dictionary).size(), (p.otes as Array).size()])
	# Un autre joueur a changé autre chose en même temps : les deux restent.
	var serveur := a.duplicate(true)
	serveur.zones[1]["k"] = "X"
	serveur.next_id = 5
	var r := SectionsPartagees.appliquer(serveur, p, spec)
	var pr := SectionsPartagees.normaliser(r, spec)
	_check(String(pr["zones#2"].k) == "X" and pr.has("zones#3") and int(r.next_id) == 5 and (r.blocks as Array) == [1, 0, 0, 9] and (r.poses as Array).size() == 2 and bool(r.growth) and (r.stocks as Dictionary).has("1"),
		"patch appliqué sur une autre version : rien d'écrasé, compteur au plus grand, simulé gardé")
	_check(SectionsPartagees.deja_applique(pr, p, spec) and not SectionsPartagees.deja_applique(pa, p), "patch déjà appliqué reconnu")
	_check(SectionsPartagees.empreinte(pb) == SectionsPartagees.empreinte(SectionsPartagees.normaliser(b.duplicate(true), spec)) and SectionsPartagees.empreinte(pa) != SectionsPartagees.empreinte(pb), "empreintes")
	p["nouveaux"] = SectionsPartagees.nouveaux(pa, p)
	var autre := a.duplicate(true)
	autre.zones.append({"id": 3, "k": "R"})
	_check(SectionsPartagees.conflits(SectionsPartagees.normaliser(autre, spec), p, spec) == ["zones#3"] and SectionsPartagees.conflits(pr, p, spec).is_empty(), "même numéro pris par deux joueurs : conflit")
	Creations.persist = false
	Creations.items["test_mj_crea"] = {"name": "Kiosque", "w": 2, "d": 2, "blocks": [0, 0, 0, 1], "cost": 1500, "hidden": false, "fonction": ""}
	var defs := SectionsPartagees.definition("test_mj_crea")
	Creations.items.erase("test_mj_crea")
	SectionsPartagees.adopter(defs)
	_check(Creations.items.has("test_mj_crea") and BuildingCatalog.all_types().has("test_mj_crea") and SectionsPartagees.definition("maison").is_empty(), "création de l'éditeur libre : définition envoyée puis adoptée")


## La carte telle que le serveur l'a (Bob, hors partie, redemande l'instantané).
func _carte_serveur(b: ClientAmis) -> Dictionary:
	# Laisse le temps au serveur de traiter ce qui vient d'être envoyé.
	await _attendre(func() -> bool: return false, 0.6)
	b.dernier_instantane = {}
	b.demander_resync()
	await _attendre(func() -> bool: return not b.dernier_instantane.is_empty(), 15.0)
	return b.dernier_instantane.get("sections", {})


func _sections_partagees(a: ClientAmis, b: ClientAmis, scene: Node, vid: int) -> void:
	print("Zonage, éditeur libre, décors, réseaux :")
	var bs: BuildingSystem = scene.buildings
	a.info_recue.connect(func(t: String) -> void: print("      (serveur → Alice) ", t))
	# Alice zone : le zonage part au serveur, et le serveur le fait payer à sa ville.
	await _attendre(func() -> bool: return false, 1.2)
	var avant := bs.money
	a._input(_touche())
	var zid: int = scene.zones.add_zone("R", Rect2i(10, 70, 20, 20))
	await process_frame
	var cout := avant - bs.money
	_check(zid > 0 and cout > 0, "Alice zone en local (%s)" % BuildingSystem.format_money(cout))
	a.envoyer_sections()
	var sec := await _carte_serveur(b)
	var zones: Array = sec.get("zones", {}).get("zones", [])
	_check(zones.any(func(z: Dictionary) -> bool: return int(z.id) == zid and String(z.k) == "R"), "zone d'Alice sur la carte du serveur")
	# Une ligne électrique (24 000 €) : payée par la caisse de sa ville, sur le serveur.
	await _attendre(func() -> bool: return false, 1.2)
	var m0 := bs.money
	a._input(_touche())
	var tid: int = scene.reseaux.poser("ligne_mt", PackedVector3Array([Vector3(-60, 40, 100), Vector3(140, 40, 100)]))
	await process_frame
	var prix := m0 - bs.money
	a.envoyer_sections()
	sec = await _carte_serveur(b)
	_check(tid > 0 and (sec.get("reseaux", {}).get("elec", {}).get("troncons", {}) as Dictionary).has(str(tid)), "ligne électrique d'Alice sur le serveur")
	await _attendre(func() -> bool: return false, 1.5)
	var paye := m0 - bs.money
	_check(prix > 20000 and absf(paye - prix) < prix * 0.25 + 2000.0, "le serveur la fait payer à Testville (%s, prix %s)" % [BuildingSystem.format_money(paye), BuildingSystem.format_money(prix)])
	_check(a.resynchros == 0, "pas de resynchronisation de la carte")

	# Bob pose un décor et un bloc : ils arrivent chez Alice.
	var deco := String(Decors.tous()[0].id)
	var rec := [deco, 5.0, 6.0, 0.0, 1.0]
	b.envoyer_action({"t": "sections", "nom": "decors", "patch": {"mis": {"poses#" + var_to_str(rec): rec}, "otes": [], "nouveaux": []}})
	_check(await _attendre(func() -> bool: return (scene.decors.to_dict().poses as Array).has(rec), 10.0), "décor de Bob chez Alice")
	var bloc := [2, 0, 3, 0]
	b.envoyer_action({"t": "sections", "nom": "blocs", "patch": {"mis": {"blocks#" + var_to_str([2, 0, 3]): bloc}, "otes": [], "nouveaux": []}})
	_check(await _attendre(func() -> bool: return scene.blocks.blocks.has(Vector3i(2, 0, 3)), 10.0), "bloc de l'éditeur libre posé par Bob chez Alice")
	_check(scene.zones.zones.has(zid), "la zone d'Alice est restée")
	# Même numéro de zone pris par Bob : refusé.
	var infos := []
	b.info_recue.connect(func(t: String) -> void: infos.append(t))
	b.envoyer_action({"t": "sections", "nom": "zones", "patch": {"mis": {"zones#%d" % zid: {"id": zid, "k": "C", "x": 0, "z": 300, "w": 10, "h": 10, "s": ""}}, "otes": [], "nouveaux": ["zones#%d" % zid]}})
	_check(await _attendre(func() -> bool: return infos.any(func(t: String) -> bool: return t.begins_with("Un autre joueur")), 10.0), "même numéro pris en même temps : Bob est prévenu")
	await _attendre(func() -> bool: return false, 1.0)
	_check(String(scene.zones.zones[zid].k) == "R", "la zone d'Alice n'est pas écrasée")

	print("Création de l'Atelier, lignes, budget, pilote :")
	Creations.items["test_mj_kiosque"] = {"name": "Kiosque", "w": 4, "d": 4, "blocks": [0, 0, 0, 1, 1, 0, 1, 1], "cost": 1500, "hidden": false, "fonction": ""}
	Creations._register("test_mj_kiosque")
	bs.relais.call({"t": "poser", "id": "test_mj_kiosque", "c": [-60, 50], "r": 0, "a": 0.0, "perso": {}, "v": -1})
	_check(await _attendre(func() -> bool: return bs.buildings.values().any(func(e: Dictionary) -> bool: return String(e.t) == "test_mj_kiosque"), 10.0), "création d'Alice posée par le serveur (définition envoyée)")
	sec = await _carte_serveur(b)
	_check((sec.get("creations", {}).get("items", {}) as Dictionary).has("test_mj_kiosque"), "et gardée dans la carte pour les autres")
	Creations.items.erase("test_mj_kiosque")
	Creations.items.erase("test_mj_crea")

	var st: StationSystem = scene.transport.stations
	# Constructions instantanées (réglage de l'admin), pour une rue tout de suite en service.
	ReglagesPartie.actuel.construction_instantanee = true
	a.reglages_changes()
	await _attendre(func() -> bool: return false, 0.6)
	var nb_aretes: int = scene.transport.network.edges.size()
	scene.transport.relais.call({"t": "voie", "id": "departementale", "spec": {}, "path": PackedVector2Array([Vector2(-80, 200), Vector2(80, 200)])})
	_check(await _attendre(func() -> bool: return scene.transport.network.edges.size() > nb_aretes, 10.0), "rue pour le bus")
	_check(Multijoueur.relayer("stations", "place", ["arret_bus", Vector3(-40, 40, 200), 0.0], {"p": Vector2(-40, 200)}) and st.stations.is_empty(), "arrêt de bus : demandé au serveur, rien en local")
	Multijoueur.relayer("stations", "place", ["arret_bus", Vector3(40, 40, 200), 0.0], {"p": Vector2(40, 200)})
	_check(await _attendre(func() -> bool: return st.stations.size() == 2, 10.0), "deux arrêts posés par le serveur chez Alice")
	Multijoueur.relayer("stations", "create_line", [st.stations.keys()], {"p": Vector2(-40, 200)})
	_check(await _attendre(func() -> bool: return st.lines.size() == 1, 10.0), "ligne de bus créée chez Alice")
	await _attendre(func() -> bool: return false, 2.5)
	_check(a.resynchros == 0 and a._ecarts == 0, "réseau identique au serveur après les arrêts")
	sec = await _carte_serveur(b)
	_check((sec.transport.stations.lines as Array).size() == 1, "la ligne est sur la carte du serveur")

	var k := String(BudgetCommunal.TAUX_NOMS.keys()[0])
	_check(Multijoueur.relayer("budget", "set_taux", [k, 1.5], {"ville": vid}), "impôts : demandé au serveur")
	_check(await _attendre(func() -> bool: return is_equal_approx(float(scene.budget.etat_de(vid).taux[k]), 1.5), 10.0), "la maire Alice change les impôts de Testville")
	infos.clear()
	b.envoyer_action({"t": "appel", "sys": "budget", "f": "set_taux", "args": [k, 0.5], "ville": vid})
	_check(await _attendre(func() -> bool: return infos.any(func(t: String) -> bool: return t.begins_with("Seul le maire")), 10.0), "Bob, pas maire, ne peut pas les changer")
	_check(is_equal_approx(float(scene.budget.etat_de(vid).taux[k]), 1.5), "les impôts restent ceux d'Alice")
	a.mes_villes = []
	_check(Multijoueur.relayer("budget", "set_taux", [k, 0.5], {"ville": vid}) and not Multijoueur.peut_decider(vid), "en local aussi : pas maire, pas de réglage")
	await _attendre(func() -> bool: return a.mes_villes.has(vid), 3.0)
	Multijoueur.relayer("pilote", "activer", [vid, true])
	_check(await _attendre(func() -> bool: return scene.pilote.actif(vid), 10.0), "pilote automatique de Testville activé par sa maire")
	Multijoueur.relayer("pilote", "activer", [vid, false])
	_check(await _attendre(func() -> bool: return not scene.pilote.actif(vid), 10.0), "et arrêté")


## Une place libre pour le bâtiment t, cherchée en local (le serveur a la même carte).
func _place_libre(bs: BuildingSystem, t: String, x0: int, z0: int, x1: int, z1: int) -> Array:
	var pas := 4 if BuildingCatalog.footprint(t, 0).x < 30 else 10
	for z in range(z0, z1, pas):
		# Une image de temps en temps : la connexion au serveur reste vivante.
		await process_frame
		for x in range(x0, x1, pas):
			for r in 4:
				if bs.check_place(t, Vector2i(x, z), r).ok:
					return [x, z, r]
	return []


## Pose un bâtiment par le serveur et attend qu'il arrive. Renvoie son id, ou -1.
func _poser_par_serveur(bs: BuildingSystem, t: String, zone: Rect2i) -> int:
	var pl: Array = await _place_libre(bs, t, zone.position.x, zone.position.y, zone.end.x, zone.end.y)
	if pl.is_empty():
		print("      pas de place pour ", t)
		return -1
	var avant := bs.buildings.keys()
	bs.relais.call({"t": "poser", "id": t, "c": [pl[0], pl[1]], "r": pl[2], "a": 0.0, "perso": {}, "v": -1})
	var trouve := [-1]
	await _attendre(func() -> bool:
		for bid in bs.buildings:
			if not bid in avant and String(bs.buildings[bid].t) == t:
				trouve[0] = int(bid)
				return true
		return false, 10.0)
	return trouve[0]


func _systemes_geres(a: ClientAmis, b: ClientAmis, scene: Node, vid: int) -> void:
	var bs: BuildingSystem = scene.buildings
	var infos := []
	b.info_recue.connect(func(t: String) -> void: infos.append(t))

	print("Sous terre :")
	var cst: ConstructionSouterraine = scene.construction_souterraine
	await _attendre(func() -> bool: return false, 1.2)
	a._input(_touche())
	var piece := cst.creuser(Rect2i(-150, 150, 10, 10), 2, 1, "cave")
	await process_frame
	a.envoyer_sections()
	var sec := await _carte_serveur(b)
	_check(piece > 0 and (sec.get("souterrain", {}).get("pieces", {}) as Dictionary).has(str(piece)), "cave creusée par Alice sur la carte du serveur")
	var nb_aretes: int = scene.transport.network.edges.size()
	RoutePlanner.profondeur_forcee = 12.0
	scene.transport.relais.call({"t": "voie", "id": "departementale", "spec": {}, "path": PackedVector2Array([Vector2(-100, 260), Vector2(100, 260)]), "prof": 12.0})
	RoutePlanner.profondeur_forcee = NAN
	_check(await _attendre(func() -> bool: return scene.transport.network.edges.size() > nb_aretes, 10.0), "tunnel creusé par le serveur")
	var tunnel := false
	for eid in scene.transport.network.edges:
		var e: Dictionary = scene.transport.network.edges[eid]
		if absf(float(e.get("prof", 0.0)) - 12.0) < 0.2 and (e.pts as PackedVector3Array)[0].y < 35.0:
			tunnel = true
	_check(tunnel, "chez Alice aussi : à 12 m sous terre")
	sec = await _carte_serveur(b)
	_check((sec.transport.edges as Array).any(func(e: Dictionary) -> bool: return absf(float(e.get("prof", 0.0)) - 12.0) < 0.2), "profondeur du tunnel gardée dans la carte")

	print("Club, parc, zoo, musée :")
	# Une rue au sud de la mairie pour desservir les bâtiments.
	nb_aretes = scene.transport.network.edges.size()
	scene.transport.relais.call({"t": "voie", "id": "departementale", "spec": {}, "path": PackedVector2Array([Vector2(-160, -60), Vector2(160, -60)])})
	await _attendre(func() -> bool: return scene.transport.network.edges.size() > nb_aretes, 10.0)
	await _attendre(func() -> bool: return false, 0.8)
	var musee := await _poser_par_serveur(bs, "musee", Rect2i(-40, -110, 80, 44))
	_check(musee >= 0, "musée posé par le serveur")
	var cle := "bat_%d" % musee
	await _attendre(func() -> bool: return scene.musee.musees.has(cle), 5.0)
	print("      musée dans le village %d (Testville : %d)" % [scene.communes.village_de(musee), vid])
	SystemesGeres.relayer("musee", "set_prix", [cle, 7.0], scene.musee.centre(cle))
	_check(await _attendre(func() -> bool: return scene.musee.musees.has(cle) and is_equal_approx(float(scene.musee.musees[cle].prix), 7.0), 10.0), "prix du musée réglé par la maire, reçu du serveur")
	if scene.communes.village_de(musee) == vid:
		infos.clear()
		var c: Vector3 = scene.musee.centre(cle)
		b.envoyer_action({"t": "appel", "sys": "musee", "f": "set_prix", "args": [cle, 1.0], "ville": vid, "p": Vector2(c.x, c.z)})
		_check(await _attendre(func() -> bool: return infos.any(func(t: String) -> bool: return t.begins_with("Seul le maire")), 10.0), "Bob ne règle pas le musée de Testville")
		await _attendre(func() -> bool: return false, 1.0)
		_check(is_equal_approx(float(scene.musee.musees[cle].prix), 7.0), "le prix reste celui d'Alice")
	var parc := await _poser_par_serveur(bs, "entree_parc", Rect2i(-150, -110, 300, 44))
	_check(parc >= 0, "entrée de parc posée")
	await _attendre(func() -> bool: return scene.parc.parcs.has(parc), 5.0)
	SystemesGeres.relayer("parc", "set_prix", [parc, 33.0, 2.0], scene.parc._center(parc))
	SystemesGeres.relayer("parc", "renommer", [parc, "Parc des Amis"], scene.parc._center(parc))
	_check(await _attendre(func() -> bool: return scene.parc.parcs.has(parc) and is_equal_approx(float(scene.parc.parcs[parc].prix), 33.0) and String(scene.parc.parcs[parc].nom) == "Parc des Amis", 10.0), "parc renommé et billet changé par le serveur")
	# Zoo : un enclos et un zèbre, achetés par le serveur (sexe et âge tirés là-bas).
	var pts := PackedVector2Array([Vector2(-150, 300), Vector2(-120, 300), Vector2(-120, 330), Vector2(-150, 330)])
	var en0: int = scene.zoo.enclos.size()
	SystemesGeres.relayer("zoo", "ajouter_enclos", [pts, "grillage"], pts[0])
	_check(await _attendre(func() -> bool: return scene.zoo.enclos.size() == en0 + 1, 10.0), "enclos construit par le serveur, reçu par Alice")
	var eid := -1
	for id in scene.zoo.enclos:
		eid = maxi(eid, int(id))
	SystemesGeres.relayer("zoo", "acheter", ["zebre", eid], pts[0])
	_check(await _attendre(func() -> bool: return scene.zoo.animaux_de(eid).size() == 1, 10.0), "zèbre acheté par le serveur")
	SystemesGeres.relayer("zoo", "renommer_enclos", [eid, "Savane"], pts[0])
	_check(await _attendre(func() -> bool: return String(scene.zoo.enclos[eid].nom) == "Savane", 10.0), "enclos renommé")
	sec = await _carte_serveur(b)
	_check((sec.get("zoo", {}).get("animaux", {}) as Dictionary).size() == 1, "le zèbre est sur la carte du serveur")
	# Club de basket au gymnase : fondé sur le serveur ; chez Alice le club ne joue pas tout seul.
	var salle := await _poser_par_serveur(bs, "gymnase", Rect2i(-150, -110, 300, 44))
	_check(salle >= 0, "gymnase posé")
	var club: ClubSport = scene.clubs["basket"]
	SystemesGeres.relayer("club", "fonder", ["BC Amis", 1, salle], SystemesGeres.point_du_club(club, salle), {"sport": "basket"})
	_check(await _attendre(func() -> bool: return club.fonde() and String(club.club.nom) == "BC Amis", 10.0), "club de basket fondé par le serveur, reçu par Alice")
	_check(not club.is_processing() and not scene.club.is_processing(), "les clubs ne sont simulés que sur le serveur")
	_check(club.joueurs.size() >= club.min_joueurs(), "effectif reçu (%d joueurs)" % club.joueurs.size())
	SystemesGeres.relayer("club", "set_prix", [19.0], SystemesGeres.point_du_club(club), {"sport": "basket"})
	_check(await _attendre(func() -> bool: return is_equal_approx(float(club.club.prix), 19.0), 10.0), "billet du club changé")

	print("Plan de site :")
	var deco := String(Decors.tous()[1].id)
	var plan := {"format": PlansSites.FORMAT, "version": PlansSites.VERSION, "id": "test_site_mj", "nom": "Coin", "w": 20, "d": 20,
		"batiments": [], "allees": [], "files": [], "enclos": [], "decors": [[deco, 4.0, 6.0, 0.0, 1.0]], "murs": [], "blocs": [1, 0, 1, 3]}
	a.envoyer_action(PlansSites.action_reseau(plan, Vector2i(200, 300), 0))
	var deco_ok := func() -> bool:
		for r in scene.decors.to_dict().poses:
			if String(r[0]) == deco and absf(float(r[1]) - 204.0) < 0.6 and absf(float(r[2]) - 306.0) < 0.6:
				return true
		return false
	_check(await _attendre(deco_ok, 10.0), "décor du plan posé chez Alice par le serveur")
	_check(await _attendre(func() -> bool: return scene.blocks.blocks.keys().any(func(k: Vector3i) -> bool: return k.x == 201 and k.z == 301), 10.0), "bloc du plan aussi")
	await _attendre(func() -> bool: return false, 2.5)
	_check(a.resynchros == 0, "toujours pas de resynchronisation")


func _touche() -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = KEY_Z
	e.pressed = true
	return e


func _en_ligne() -> void:
	print("Serveur sans écran :")
	# Réglages choisis dans l'assistant de nouvelle partie (fichier lu par le serveur).
	var reg := ReglagesPartie.load_defaults()
	reg.argent_depart = 31_000_000
	reg.tutoriel = true
	var fr := FileAccess.open("user://test_amis_reglages.json", FileAccess.WRITE)
	fr.store_string(JSON.stringify(reg.to_dict()))
	fr.close()
	var args_assistant := Multijoueur.arguments_serveur(PackedStringArray(["--lat", "1", "--reglages", "x"]))
	_check(args_assistant.has("--serveur") and args_assistant.has("--reglages") and args_assistant.has("--headless"), "arguments du serveur d'une nouvelle carte (%s)" % " ".join(args_assistant))
	_lancer_serveur(["--nouvelle", "--lat", "48.85", "--lon", "2.29", "--nom", "Test", "--code", CODE,
		"--reglages", "user://test_amis_reglages.json"])
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
	_check(ReglagesPartie.actuel.argent_depart == 31_000_000 and not ReglagesPartie.actuel.tutoriel, "réglages de l'assistant appliqués par le serveur (argent %d, tutoriel coupé)" % ReglagesPartie.actuel.argent_depart)
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
	# La caisse de Testville bouge un peu toute seule (entretien, impôts au fil des jours) :
	# on vérifie qu'elle ne paie pas la maison (≈ 250 000 €).
	_check(avant_bob - bs.money < 50000, "la maison de Bob n'est pas payée par la caisse d'Alice (écart %s)" % BuildingSystem.format_money(avant_bob - bs.money))

	print("Temps, démolition, terrain :")
	scene.ambiance.set_speed(3)
	_check(await _attendre(func() -> bool: return b._vitesse_serveur == 3, 5.0), "l'admin change la vitesse pour tous")
	bs.relais.call({"t": "demolir", "bid": maison, "c": [20, 52]})
	_check(await _attendre(func() -> bool: return not bs.buildings.has(maison), 10.0), "maison démolie par le serveur")
	scene.world.relais.call({"t": "terrain", "outil": int(TerrainWorld.Tool.RAISE), "a": Vector2i(300, 300), "b": Vector2i(302, 302)})
	_check(await _attendre(func() -> bool: return scene.world.modifications.has(Vector2i(301, 301)), 10.0), "terrain monté d'un mètre chez Alice")
	_check(absf(float(scene.world.modifications.get(Vector2i(301, 301), 0.0)) - 41.0) < 0.01, "hauteur reçue : 41 m")

	print("Ctrl+Z en ligne :")
	var h: HistoriqueVille = scene.historique
	h.vider()
	var ne: int = scene.transport.network.edges.size()
	scene.transport.relais.call({"t": "voie", "id": "departementale", "spec": {}, "path": PackedVector2Array([Vector2(-80, 140), Vector2(80, 140)])})
	_check(await _attendre(func() -> bool: return scene.transport.network.edges.size() > ne and h.peut_annuler(), 10.0), "la route d'Alice entre dans son historique (%s)" % h.nom_annuler())
	var ne_route: int = scene.transport.network.edges.size()
	h.annuler()
	_check(await _attendre(func() -> bool: return scene.transport.network.edges.size() == ne, 10.0), "Ctrl+Z : le serveur ôte la route chez tous")
	h.refaire()
	_check(await _attendre(func() -> bool: return scene.transport.network.edges.size() == ne_route, 10.0), "Ctrl+Y : elle revient")
	var nb2 := bs.buildings.size()
	var m_av := bs.money
	var pa := {"t": "poser", "id": "maison", "c": [20, 152], "r": 0, "a": 0.0, "perso": {}, "v": -1}
	bs.relais.call(pa)
	h.noter("Maison", {"k": "mp_bat_pose", "a": pa.duplicate(true)})
	_check(await _attendre(func() -> bool: return bs.buildings.size() > nb2, 10.0), "maison posée par le serveur")
	h.annuler()
	_check(await _attendre(func() -> bool: return bs.buildings.size() == nb2, 10.0), "Ctrl+Z : la maison est retirée par le serveur")
	await _attendre(func() -> bool: return false, 1.0)
	_check(absi(bs.money - m_av) < 50000, "tout l'argent revient (écart %s)" % BuildingSystem.format_money(bs.money - m_av))

	await _sections_partagees(a, b, scene, vid)
	await _systemes_geres(a, b, scene, vid)

	print("Arrêt et reprise :")
	var nbats := bs.buildings.size()
	var types_avant := bs.buildings.values().map(func(e: Dictionary) -> String: return String(e.t))
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
	# Le serveur met quelques secondes à rouvrir la carte : on réessaie comme le menu Entre amis.
	var a2: ClientAmis = null
	for essai in 4:
		a2 = _client(SaveGame.player_id(), "Alice", "")
		if await _attendre(func() -> bool: return a2.etat == "pret" or a2.etat == "deconnecte", 40.0) and a2.etat == "pret":
			break
		a2.queue_free()
		await _attendre(func() -> bool: return false, 2.0)
	_check(a2.etat == "pret", "Alice revient sans code (membre)")
	_check(a2.admin and a2.code_carte == CODE, "toujours admin, même code")
	var sec: Dictionary = a2.dernier_instantane.sections
	if (sec.batiments.buildings as Array).size() != nbats:
		print("      reçus : ", (sec.batiments.buildings as Array).map(func(e: Dictionary) -> String: return String(e.t)), " · avant : ", types_avant)
	_check((sec.batiments.buildings as Array).size() == nbats and (sec.communes.villages as Array).size() >= 1, "la carte a gardé ses %d bâtiments et son village" % nbats)
	a2.deconnecter()
	_effacer(a.slot)
	_effacer(a2.slot)
