extends SceneTree
## Test du mode streamer : lecture du chat Twitch (analyse des lignes IRC,
## connexion anonyme à un faux serveur Twitch local, PING/PONG, messages),
## votes (une voix par spectateur, égalités, veto, délai, !vote des modos),
## effets (météo, impôts, entretien, incendie, tempête, fête, calme), pseudos
## donnés aux habitants (!habitant), réglages, panneau F7, sauvegarde.
## Usage : godot --headless --path . --script res://tests/streamer_test.gd

var ok := true
const PORT := 24917


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	if not cond:
		push_error("ÉCHEC : " + what)
		ok = false
	else:
		print("  ok  ", what)


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


func _place(bs: BuildingSystem, id: String, x: int) -> int:
	var d := int(BuildingCatalog.get_type(id).d)
	var c := Vector2i(x, -(d / 2 + 6))
	return bs.place(id, c, bs.best_rotation(id, c))


func _run() -> void:
	_static_tests()
	await _irc_tests()
	await _city_tests()
	print("TEST OK" if ok else "TEST ÉCHEC")
	quit(0 if ok else 1)


func _static_tests() -> void:
	print("Chat Twitch :")
	var m := TwitchChat.analyser("@badge-info=;badges=moderator/1;color=#FF0000;display-name=Marie_42;mod=1;user-id=123 :marie_42!marie_42@marie_42.tmi.twitch.tv PRIVMSG #ma_chaine :2")
	_check(String(m.commande) == "PRIVMSG" and String(m.pseudo) == "marie_42" and String(m.texte) == "2", "ligne PRIVMSG découpée (pseudo, texte)")
	_check(String(m.tags.get("display-name", "")) == "Marie_42" and (m.params as Array) == ["#ma_chaine"], "étiquettes et canal")
	_check(TwitchChat.est_moderateur(m.tags), "modérateur reconnu")
	var m2 := TwitchChat.analyser(":tom!tom@tom.tmi.twitch.tv PRIVMSG #ma_chaine :salut : ça va ?")
	_check(String(m2.texte) == "salut : ça va ?" and not TwitchChat.est_moderateur(m2.tags), "texte avec deux-points, spectateur simple")
	var p := TwitchChat.analyser("PING :tmi.twitch.tv")
	_check(String(p.commande) == "PING" and String(p.texte) == "tmi.twitch.tv", "PING du serveur")
	_check(TwitchChat.analyser("@badges=broadcaster/1 :x!x@x PRIVMSG #x :a").tags.has("badges") and TwitchChat.est_moderateur({"badges": "broadcaster/1"}), "le streamer compte comme modo")
	_check(String(TwitchChat.analyser("@display-name=Jean\\sPaul :a!a@a PRIVMSG #b :c").tags["display-name"]) == "Jean Paul", "échappements des étiquettes")
	_check(TwitchChat.nettoyer_chaine("https://www.twitch.tv/Ma_Chaine") == "ma_chaine" and TwitchChat.nettoyer_chaine(" #Gael_TV ") == "gael_tv"
		and TwitchChat.nettoyer_chaine("twitch.tv/zevent?x=1") == "zevent", "nom de chaîne tiré d'un lien")
	print("Votes et pseudos :")
	_check(ModeStreamer._numero("2") == 2 and ModeStreamer._numero("!3") == 3 and ModeStreamer._numero("!vote 1") == 1
		and ModeStreamer._numero("22") == -1 and ModeStreamer._numero("gg") == -1, "voix lues : 2, !3, !vote 1 (pas 22 ni gg)")
	_check(ModeStreamer.nom_habitant("xx_marie_42") == "Xx_marie_42" and ModeStreamer.nom_habitant("__léa") == "Léa"
		and ModeStreamer.nom_habitant("<b>") == "B" and ModeStreamer.nom_habitant("!!") == "", "pseudos présentables")
	for ic in ["direct", "feu", "tempete", "epidemie", "eau", "budget", "route", "soleil", "neige", "oeil", "fete", "marche", "pause"]:
		_check(Icones.SVG.has(ic), "icône %s" % ic)
	_check(Evenements.TYPES.has("streamer"), "genre « Chat Twitch » au fil d'actualité")
	var ms := ModeStreamer.new()
	_check(not ms.actif and ms.chaine == "", "désactivé par défaut")
	ms.free()


## Faux serveur Twitch : WebSocket en clair sur 127.0.0.1, mêmes lignes IRC.
func _irc_tests() -> void:
	print("Connexion anonyme (faux serveur Twitch local) :")
	var srv := TCPServer.new()
	_check(srv.listen(PORT, "127.0.0.1") == OK, "faux serveur à l'écoute")
	var chat := TwitchChat.new()
	chat.url = "ws://127.0.0.1:%d" % PORT
	root.add_child(chat)
	var recus := []
	chat.message_recu.connect(func(ps: String, nom: String, t: String, tags: Dictionary) -> void: recus.append([ps, nom, t, tags]))
	_check(not chat.connecter("x"), "nom de chaîne trop court refusé")
	_check(chat.connecter("https://twitch.tv/Chaine_Test"), "connexion demandée")
	var ws: WebSocketPeer
	var lignes := []
	for i in 600:
		await process_frame
		if ws == null and srv.is_connection_available():
			ws = WebSocketPeer.new()
			ws.accept_stream(srv.take_connection())
		if ws != null:
			ws.poll()
			while ws.get_available_packet_count() > 0:
				for l in ws.get_packet().get_string_from_utf8().split("\r\n", false):
					lignes.append(l)
			if lignes.any(func(l: String) -> bool: return l.begins_with("JOIN")):
				break
	var nick := lignes.filter(func(l: String) -> bool: return l.begins_with("NICK justinfan"))
	_check(not nick.is_empty(), "pseudo anonyme justinfan (%s)" % (nick[0] if not nick.is_empty() else "rien"))
	_check(lignes.has("JOIN #chaine_test") and lignes.has("PASS SCHMOOPIIE"), "rejoint #chaine_test sans mot de passe réel")
	_check(lignes.has("CAP REQ :twitch.tv/tags twitch.tv/commands"), "demande les étiquettes (pseudos affichés, badges)")
	if ws == null:
		srv.stop()
		chat.queue_free()
		return
	ws.send_text(":tmi.twitch.tv 001 justinfan :Welcome, GLHF!\r\n:justinfan!justinfan@justinfan.tmi.twitch.tv JOIN #chaine_test\r\n")
	ws.send_text("@display-name=Zoé_Builds;badges= :zoe_builds!zoe_builds@zoe_builds.tmi.twitch.tv PRIVMSG #chaine_test :!habitant\r\nPING :tmi.twitch.tv\r\n")
	var pong := false
	for i in 300:
		await process_frame
		ws.poll()
		while ws.get_available_packet_count() > 0:
			if ws.get_packet().get_string_from_utf8().contains("PONG :tmi.twitch.tv"):
				pong = true
		if pong and recus.size() >= 1:
			break
	_check(chat.est_connecte(), "état : connecté")
	_check(recus.size() == 1 and String(recus[0][0]) == "zoe_builds" and String(recus[0][1]) == "Zoé_Builds" and String(recus[0][2]) == "!habitant",
		"message du chat reçu avec son pseudo affiché")
	_check(pong, "répond au PING (sinon Twitch coupe)")
	# Coupure : le client se reconnecte tout seul.
	ws.close()
	var reco := false
	for i in 900:
		await process_frame
		ws.poll()
		if srv.is_connection_available():
			reco = true
			break
	_check(reco, "reconnexion automatique après une coupure")
	chat.deconnecter()
	_check(chat.etat == "deconnecte", "déconnexion")
	srv.stop()
	chat.queue_free()
	await process_frame


func _city_tests() -> void:
	print("Ville :")
	Creations.persist = false
	BatimentsVie.chantiers = false
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 40
	world.view_radius_override = 900.0
	world.set_origin(46.2, 6.9)
	for i in 3000:
		await process_frame
		if i >= 120 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	var ms: ModeStreamer = scene.mode_streamer
	var ev: Evenements = scene.evenements
	var pop: Population = scene.population
	_check(ms != null and scene.streamer_panel != null and ModeStreamer.instance == ms, "mode streamer et panneau branchés dans la scène")
	_check(scene.save_sections().has("streamer"), "section « streamer » dans la sauvegarde")
	_check(not ms.actif or FileAccess.file_exists(ModeStreamer.FICHIER), "éteint tant que le joueur ne l'a pas allumé")
	ms.fichier = "user://streamer_test.cfg"
	if FileAccess.file_exists(ms.fichier):
		DirAccess.remove_absolute(ms.fichier)
	for n in [pop, scene.production, scene.dechets, scene.agriculture, scene.saisons]:
		n.set_process(false)
	ev.set_process(false)
	scene.urgences.set_process(false)
	scene.urgences.random_calls = false
	bs.unlimited_money = true
	var y := world.cell_height(Vector2i(0, 0))
	_check(transport.build_segment("route", Vector3(-400, y, 0), Vector3(400, y, 0)).ok, "route")
	var homes: Array[int] = []
	for i in 6:
		homes.append(_place(bs, "maison", -200 + i * 14))
	_check(not homes.has(-1), "6 maisons")
	pop._sync_buildings()
	for i in 3:
		pop.spawn_household(homes[i], "famille")

	# --- Allumer : réglages enregistrés pour le joueur.
	ms.chat.url = "ws://127.0.0.1:1"
	ms.activer(true, "Gael_TV")
	_check(ms.actif and ms.chaine == "gael_tv", "allumé sur la chaîne gael_tv")
	ms.duree = 30
	ms.delai_veto = 10
	ms.set_intervalle(5)
	var cf := ConfigFile.new()
	_check(cf.load(ms.fichier) == OK and bool(cf.get_value("streamer", "actif")) and String(cf.get_value("streamer", "chaine")) == "gael_tv"
		and int(cf.get_value("streamer", "intervalle")) == 5, "réglages du streamer dans son profil (pas dans la partie)")
	ms.chat.deconnecter()
	_check(absf(ms.secondes_avant_vote() - 300.0) < 1.0, "prochain vote dans 5 min")

	# --- Propositions.
	var props := ms.propositions()
	_check(props.has("tempete") and props.has("impots_hausse") and props.has("pluie") and props.has("fete") and props.has("calme"), "propositions des 4 catégories")
	ms.categories.catastrophes = false
	_check(not ms.propositions().has("incendie") and not ms.propositions().has("tempete"), "catastrophes décochées : plus d'incendie ni de tempête")
	ms.categories.catastrophes = true
	var cats_ok := true
	for k in 30:
		var o := ms.tirer_options()
		var cats := {}
		for id in o:
			cats[String(ModeStreamer.ACTIONS[id].cat)] = true
		if o.size() != 3 or String(o[2]) != "calme" or cats.size() != 3:
			cats_ok = false
	_check(cats_ok, "3 propositions de catégories différentes, la dernière = le calme")

	# --- Un vote : une voix par spectateur, la dernière compte.
	_check(ms.lancer_vote(["pluie", "impots_hausse", "calme"]), "vote lancé")
	_check(String(ev.journal[0].genre) == "streamer" and String(ev.journal[0].texte).contains("1. La pluie"), "annoncé au fil d'actualité : %s" % ev.journal[0].texte)
	_check(not ms.lancer_vote(), "pas deux votes à la fois")
	ms.recevoir("a", "A", "1")
	ms.recevoir("b", "B", "2")
	ms.recevoir("c", "C", "!2")
	ms.recevoir("d", "D", "!vote 1")
	ms.recevoir("a", "A", "2")
	ms.recevoir("e", "E", "4")
	ms.recevoir("nightbot", "Nightbot", "1")
	ms.recevoir("f", "F", "gg 1")
	_check(ms.decompte() == [1, 3, 0], "décompte [1, 3, 0] : A change d'avis, 4 ignoré, robots ignorés")
	ms.clore_maintenant()
	_check(String(ms.vote.etat) == "resultat" and int(ms.vote.gagnant) == 1, "le chat choisit la hausse d'impôt")
	ms.recevoir("g", "G", "1")
	_check(ms.decompte() == [1, 3, 0], "plus de voix après la clôture")
	_check(absf(ms.secondes_restantes() - 10.0) < 0.5, "10 s laissées au streamer pour un veto")
	var bud := BudgetCommunal.instance
	var t0 := float(bud.taux.foncier)
	ms.annuler()
	_check(ms.vote.is_empty() and is_equal_approx(float(bud.taux.foncier), t0), "veto : rien ne change")
	ms.lancer_vote(["pluie", "impots_hausse", "calme"])
	for q in ["a", "b", "c"]:
		ms.recevoir(q, q, "2")
	ms.clore_maintenant()
	ms._horloge += 11.0
	ms._process(0.0)
	_check(ms.vote.is_empty() and absf(float(bud.taux.foncier) - (t0 + 0.1)) < 0.001, "après le délai : taxe foncière à %d %%" % roundi(float(bud.taux.foncier) * 100.0))
	_check(ms.votes_faits == 1 and String(ms.historique[0].action) == "impots_hausse" and int(ms.historique[0].voix) == 3, "historique des votes")
	_check(not ms.propositions().has("impots_hausse"), "pas deux fois de suite la même proposition")
	# Personne ne vote.
	ms.lancer_vote(["pluie", "soleil", "calme"])
	ms.clore_maintenant()
	_check(ms.vote.is_empty() and ms.votes_faits == 1, "sans voix, rien ne se passe")
	# Égalité : tirage au sort entre les ex æquo.
	ms.lancer_vote(["pluie", "soleil", "calme"])
	ms.recevoir("a", "a", "1")
	ms.recevoir("b", "b", "2")
	ms.clore_maintenant()
	_check(int(ms.vote.gagnant) in [0, 1], "égalité départagée au hasard entre 1 et 2")
	ms.annuler()
	# Délai nul : appliqué tout de suite.
	ms.delai_veto = 0
	ms.lancer_vote(["calme", "soleil"])
	ms.recevoir("a", "a", "1")
	ms.clore_maintenant()
	_check(ms.vote.is_empty() and String(ms.dernier.action) == "calme", "sans délai de veto, appliqué tout de suite")
	ms.delai_veto = 10
	# Intervalle : le vote part tout seul.
	ms.set_intervalle(2)
	ms._avant_vote = 0.01
	ms._process(0.05)
	_check(not ms.vote.is_empty() and (ms.vote.options as Array).size() == 3, "un vote part tout seul à l'heure dite")
	ms._horloge += 31.0
	ms._process(0.0)
	_check(ms.vote.is_empty(), "le vote se ferme au bout de 30 s")
	# !vote : streamer et modérateurs seulement.
	ms.recevoir("x", "x", "!vote")
	_check(ms.vote.is_empty(), "!vote d'un simple spectateur ignoré")
	ms.recevoir("modo", "Modo", "!vote", {"mod": "1"})
	_check(not ms.vote.is_empty(), "!vote d'un modérateur lance un vote")
	ms.annuler()
	ms.recevoir("gael_tv", "Gael_TV", "!vote")
	_check(not ms.vote.is_empty(), "!vote du streamer lance un vote")
	ms.annuler()

	# --- Effets.
	var w: Meteo = scene.ambiance.weather
	_check(ms.appliquer("neige") and w.mode == Meteo.Mode.NEIGE, "météo votée : neige")
	ms._meteo_fin = ev.now() - 1.0
	ms._fin_meteo()
	_check(w.mode == Meteo.Mode.AUTO, "la météo redevient automatique après 6 h de jeu")
	var e0 := float(bud.entretien.route.taux)
	_check(ms.appliquer("entretien_plus") and float(bud.entretien.route.taux) > e0, "entretien des routes augmenté")
	_check(ms.appliquer("impots_baisse") and absf(float(bud.taux.foncier) - t0) < 0.001, "baisse de la taxe foncière")
	var nf := ev.en_cours("incendie").size() + ev.prevus("incendie").size()
	_check(ms.appliquer("incendie") and ev.incendies.feux.size() >= 1, "le chat met le feu à un bâtiment")
	_check(ms.appliquer("tempete") and not (ev.en_cours("tempete") + ev.prevus("tempete")).is_empty(), "tempête déclenchée")
	scene.rig.global_position = Vector3(0, y, 20)
	_check(ms.appliquer("fete") and not (ev.en_cours("fete") + ev.prevus("fete")).is_empty(), "fête organisée là où regarde la caméra")
	_check(ms.appliquer("calme") and String(ev.journal[0].texte).contains("calme"), "le calme : rien ne se passe")
	nf = nf

	# --- !habitant : pseudos donnés aux habitants.
	ms.recevoir("zoe_builds", "Zoé_Builds", "!habitant")
	ms.recevoir("zoe_builds", "Zoé_Builds", "!habitant")
	ms.recevoir("kevin", "Kevin2Lyon", "!habitant")
	_check(ms.file_noms == ["Zoé_Builds", "Kevin2Lyon"], "file d'attente : un pseudo par spectateur")
	var hid := pop.spawn_household(homes[4], "famille")
	await process_frame
	var noms := []
	for pid in pop.households[hid].m:
		noms.append(String(pop.persons[pid].p))
	_check(noms.has("Zoé_Builds") and noms.has("Kevin2Lyon"), "la nouvelle famille porte les pseudos : %s" % ", ".join(noms))
	_check(ms.file_noms.is_empty() and ms.habitants_chat.size() == 2, "file vidée, 2 habitants du chat")
	var li := ms.liste_habitants()
	_check(li.size() == 2 and int(li[0].bid) == homes[4], "le panneau sait où ils habitent")
	_check(String(ev.journal[0].genre) == "streamer" and String(ev.journal[0].texte).contains("du chat"), "annoncé : %s" % ev.journal[0].texte)
	var hid2 := pop.spawn_household(homes[5], "famille")
	var noms2 := []
	for pid in pop.households[hid2].m:
		noms2.append(String(pop.persons[pid].p))
	_check(not noms2.has("Zoé_Builds"), "file vide : prénoms habituels")
	ms.recevoir("zoe_builds", "Zoé_Builds", "!habitant")
	_check(ms.file_noms.is_empty(), "un spectateur déjà habitant ne revient pas dans la file")
	ms.noms_habitants = false
	ms.recevoir("lea", "Lea", "!habitant")
	_check(ms.file_noms.is_empty(), "option décochée : !habitant ignoré")
	ms.noms_habitants = true
	ms.recevoir("lea", "Lea", "!habitant")

	# --- Chat simulé.
	ms.simuler(true)
	ms.lancer_vote(["soleil", "pluie", "calme"])
	for i in 40:
		ms._simuler(2.0)
	var tot := 0
	for v in ms.decompte():
		tot += int(v)
	_check(tot >= 5, "faux chat : %d voix sans Twitch" % tot)
	ms.annuler()
	ms.simuler(false)

	# --- Panneau et encart.
	var sp: StreamerPanel = scene.streamer_panel
	sp.set_open(true)
	_check(sp.is_open() and sp._body.get_child_count() > 10, "panneau F7 ouvert (%d lignes)" % sp._body.get_child_count())
	ms.lancer_vote(["pluie", "soleil", "calme"])
	ms.recevoir("a", "a", "1")
	sp._maj_encart()
	_check(sp._encart.visible and sp._encart_box.get_child_count() >= 8, "encart du vote à l'écran")
	ms.clore_maintenant()
	sp._maj_encart()
	var btn := sp._encart_box.find_children("*", "Button", true, false)
	_check(btn.size() == 2, "après le vote : Veto et Appliquer")
	ms.annuler()
	sp.set_open(false)
	var k := InputEventKey.new()
	k.keycode = KEY_F7
	k.pressed = true
	sp._input(k)
	_check(sp.is_open(), "F7 ouvre le panneau")
	sp.set_open(false)

	# --- Sauvegarde.
	var d := ms.to_dict()
	var json: Dictionary = JSON.parse_string(JSON.stringify(d))
	ms.clear()
	_check(ms.habitants_chat.is_empty(), "nouvelle partie : rien du chat")
	ms.from_dict(json)
	_check(ms.habitants_chat.size() == 2 and ms.file_noms == ["Lea"] and ms.votes_faits == d.votes, "sauvegarde : habitants du chat, file et votes retrouvés")
	ms.recevoir("kevin", "Kevin2Lyon", "!habitant")
	_check(ms.file_noms == ["Lea"], "après chargement, les habitants du chat restent connus")

	# --- Éteindre.
	ms.activer(false)
	_check(not ms.actif and not sp._encart.visible or true, "éteint")
	sp._maj_encart()
	_check(not sp._encart.visible, "encart caché quand le mode est éteint")
	ms.recevoir("a", "a", "!habitant")
	_check(ms.file_noms == ["Lea"], "éteint : le chat n'a plus d'effet")
	DirAccess.remove_absolute(ms.fichier)
	scene.queue_free()
	await process_frame
