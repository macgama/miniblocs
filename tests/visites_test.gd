extends SceneTree
## Test des visites et des cartes postales : le maire partage sa ville (.mbloc de
## genre « ville », livre d'or fermé = cartes retirées du paquet), le visiteur la
## reçoit, l'ouvre en visite (copie cachée, rien ne se construit, rien ne se
## sauvegarde, raccourcis bloqués), écrit une carte postale avec photo ; le maire
## rouvre sa partie et la carte arrive toute seule dans son courrier (épinglée,
## sauvegardée). Paquets abîmés refusés, cartes nettoyées, visiteurs d'une carte
## entre amis (code exigé sauf visites ouvertes, actions refusées, cartes relayées).
## Usage : godot --headless --path . --script res://tests/visites_test.gd

var ok := true
const RACINE := "user://test_visites"
const SLOT_A := "test-visite-maire"


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


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _vider(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for sub in d.get_directories():
		_vider(dir.path_join(sub))
	for f in d.get_files():
		d.remove(f)
	DirAccess.remove_absolute(dir)


## Scène Terre sur un terrain plat (la partie slot est chargée à la main ensuite).
func _scene() -> Node:
	GameStart.chosen = true
	GameStart.load_slot = ""
	GameStart.place_name = "Valfleuri, Savoie"
	ReglagesPartie.prochaine = ReglagesPartie.preset("normal")
	ReglagesPartie.prochaine.fondateurs = 20
	ReglagesPartie.prochaine.tutoriel = false
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.view_radius_override = 1500.0
	world.set_origin(45.5, 6.4)
	for i in 3000:
		await process_frame
		if i >= 60 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	scene.urgences.random_calls = false
	scene.population.arrivals = false
	return scene


func _touche(code: Key, maj := false) -> InputEventKey:
	var k := InputEventKey.new()
	k.keycode = code
	k.physical_keycode = code
	k.pressed = true
	k.shift_pressed = maj
	return k


func _run() -> void:
	Creations.persist = false
	Succes.persist = false
	Partage.persist = false
	_vider(RACINE)
	Partage.echange = RACINE.path_join("echange")
	VisiteVille.dossier = RACINE.path_join("villes")
	VisiteVille.envoyees_path = RACINE.path_join("envoyees.json")
	VisiteVille.changer_scene = false
	DirAccess.make_dir_recursive_absolute(Partage.echange)
	if SaveGame.exists(SLOT_A):
		SaveGame.delete(SLOT_A)

	print("Le maire construit et partage sa ville :")
	var a: Node = await _scene()
	var bs: BuildingSystem = a.buildings
	var cm: Communes = a.communes
	cm.nom_en_attente = "Valfleuri"
	var mc := bs.place("maison_commune", Vector2i(-1000, 0), 0)
	await _frames(4)
	_check(mc >= 0 and cm.principal() >= 0, "Valfleuri fondé")
	var n_bat := bs.buildings.size()
	var cr: Courrier = a.courrier
	_check(cr != null and a.get_node_or_null("Courrier") == cr, "courrier branché")
	cr.accueil = "Bienvenue à Valfleuri !"
	# Une carte déjà reçue, qui ne doit pas partir avec la ville si le livre d'or est fermé.
	_check(cr.recevoir({"id": "ancienne-carte-0001", "de": "Zoé", "texte": "Joli clocher", "x": -990.0, "z": 5.0}), "une carte déjà reçue")
	_check(not cr.recevoir({"id": "ancienne-carte-0001", "de": "Zoé", "texte": "Joli clocher"}), "la même carte n'entre pas deux fois")
	cr.livre_or = false
	_check(a.save_game(SLOT_A, "Valfleuri"), "partie du maire sauvegardée")
	var pid := String(SaveGame.read_manifest(SLOT_A).get("partie_id", ""))
	_check(pid != "" and cr.partie() == pid, "le courrier connaît sa partie (%s)" % pid.left(8))
	var path := VisiteVille.exporter(SLOT_A, cr.accueil, "", {"courrier": cr.pour_partage()})
	_check(path != "" and FileAccess.file_exists(path), "fichier .mbloc de la ville (%s)" % path.get_file())
	var lu := PaquetPartage.lire_fichier(path)
	_check(lu.has("paquet") and PaquetPartage.genre(lu.paquet) == "ville", "c'est un paquet « ville »")
	_check(VisiteVille.verifier(lu.paquet) == "", "contenu de ville sain")
	_check(String(lu.paquet.fiche.get("partie", "")) == pid, "le paquet porte l'identifiant de la partie")
	a.queue_free()
	await _frames(3)

	print("Paquets abîmés :")
	var faux: Dictionary = lu.paquet.duplicate(true)
	(faux.contenu.principal.fichiers as Dictionary)["../../evil.json.zst"] = "AAAA"
	_check(VisiteVille.verifier(faux) != "", "un nom de fichier qui sort du dossier est refusé")
	var faux2: Dictionary = lu.paquet.duplicate(true)
	faux2.contenu.principal.partie.version = SaveGame.VERSION + 1
	_check(VisiteVille.verifier(faux2) != "", "une ville d'une version future est refusée")
	_check(Courrier.nettoyer({"id": "x", "texte": "a"}).is_empty(), "carte sans vrai identifiant refusée")
	var longue := Courrier.nettoyer({"id": "carte-longue-01", "texte": "a".repeat(2000), "de": "b".repeat(80), "x": INF})
	_check(String(longue.texte).length() == VisiteVille.MAX_TEXTE and String(longue.de).length() == 24 and float(longue.x) == 0.0, "carte bornée (texte, pseudo, position)")

	print("Le visiteur reçoit la ville :")
	var r := VisiteVille.recevoir_echange()
	_check(int(r.nouvelles) == 1, "une ville reçue du dossier d'échange")
	_check(int(VisiteVille.recevoir_echange().nouvelles) == 0, "pas deux fois la même")
	var liste := VisiteVille.villes()
	_check(liste.size() == 1 and String(liste[0].fiche.ville) == "Valfleuri", "la ville est dans la liste des visites")
	_check(int(Partage.recevoir_echange().nouveaux) == 0, "la ville n'entre pas dans l'atelier des créations")
	var err := VisiteVille.visiter_dossier(String(liste[0].dossier))
	_check(err == "" and VisiteVille.active(), "visite préparée (%s)" % err)
	_check(SaveGame.exists(VisiteVille.SLOT), "copie de la ville dans la partie cachée")
	var cachee := true
	for m in SaveGame.list_saves():
		cachee = cachee and String(m.id) != VisiteVille.SLOT
	_check(cachee, "la copie n'apparaît pas dans Charger une partie")
	_check(VisiteVille.titre() == "Valfleuri" and String(VisiteVille.en_cours.accueil) == "Bienvenue à Valfleuri !", "titre et mot d'accueil")

	print("En visite :")
	var v: Node = await _scene()
	_check(v.load_game(VisiteVille.SLOT), "la ville visitée s'ouvre")
	v._debut_visite()
	await _frames(3)
	_check((v.buildings as BuildingSystem).buildings.size() == n_bat, "mêmes bâtiments que chez le maire (%d)" % n_bat)
	_check((v.courrier as Courrier).recues.is_empty(), "livre d'or fermé : pas de cartes du maire")
	_check(v._bandeau_visite != null and v._bandeau_visite.is_inside_tree(), "bandeau de visite")
	_check(not (v.succes_suivi as SuccesSuivi).actif, "pas de succès pour la ville d'un autre")
	_check(not v.save_game(), "la visite ne se sauvegarde pas")
	_check(VisiteVille.touche_verrouillee(_touche(KEY_B)), "B (construire) bloqué")
	_check(VisiteVille.touche_verrouillee(_touche(KEY_M)), "M (budget) bloqué")
	_check(VisiteVille.touche_verrouillee(_touche(KEY_P, true)), "Maj+P (pays) bloqué")
	_check(VisiteVille.touche_verrouillee(_touche(KEY_F5)), "F5 (sauver) bloqué")
	_check(not VisiteVille.touche_verrouillee(_touche(KEY_V)), "V (vue au sol) permis")
	_check(not VisiteVille.touche_verrouillee(_touche(KEY_I, true)), "Maj+I (statistiques) permis")
	_check(not VisiteVille.touche_verrouillee(_touche(KEY_F8)), "F8 (photo) permis")
	_check(not VisiteVille.touche_verrouillee(_touche(KEY_W)), "W (caméra) permis")
	var hud: Node = v.hud
	hud._on_category("construire")
	_check(VisiteVille.categorie_verrouillee("construire") and not VisiteVille.categorie_verrouillee("stats"), "Construire verrouillé, Statistiques permises")
	hud._request_mode(true)
	_check(not hud.create_mode, "pas de mode Créer")
	hud._unhandled_key_input(_touche(KEY_5))
	_check(hud._current_tool == 0, "pas d'outil Route (5)")
	var rien := (v.buildings as BuildingSystem).buildings.size()
	_check(rien == n_bat, "rien n'a changé")

	print("Carte postale :")
	var photo := Image.create(640, 360, false, Image.FORMAT_RGB8)
	photo.fill(Color(0.3, 0.6, 0.9))
	var carte := VisiteVille.carte("Superbe mairie, et la rue en T !", Vector2(-1000, -40), {"x": -1000.0, "z": -40.0, "distance": 120.0}, 2, photo)
	_check(String(carte.partie) == pid and String(carte.ville) == "Valfleuri", "carte adressée à la partie visitée")
	_check(String(carte.photo) != "" and Courrier.photo_de(carte).get_width() <= Courrier.PHOTO_MAX.x, "photo jointe et réduite")
	var cpath := VisiteVille.poster(carte)
	(v.courrier as Courrier).poser(carte)
	_check(cpath != "" and FileAccess.file_exists(cpath) and cpath.get_file().begins_with("carte-postale"), "carte postée dans le dossier d'échange")
	_check((v.courrier as Courrier).posees.size() == 1 and (v.courrier as Courrier)._marques.get_child_count() >= 1, "carte épinglée dans la ville visitée")
	_check(VisiteVille.envoyees().size() == 1, "carte gardée dans « envoyées »")
	var panel := VisitesPanel.new(v)
	v._windows_layer().add_child(panel)
	await _frames(2)
	_check(panel.view == "visite", "F12 en visite : écrire une carte")
	panel.fermer()
	VisiteVille.terminer()
	_check(not VisiteVille.active() and not SaveGame.exists(VisiteVille.SLOT), "fin de la visite : copie jetée")
	v.queue_free()
	await _frames(3)

	print("Le maire reçoit son courrier :")
	var b: Node = await _scene()
	_check(b.load_game(SLOT_A), "partie du maire rouverte")
	var crb: Courrier = b.courrier
	var avant := crb.recues.size()
	var recus := []
	crb.arrivee.connect(func(c: Dictionary) -> void: recus.append(c))
	var n := crb.relever()
	_check(n == 1 and crb.recues.size() == avant + 1, "la carte entre dans le courrier (%d)" % n)
	_check(recus.size() == 1 and String(recus[0].de) == PaquetPartage.auteur(), "annonce de la carte")
	_check(not FileAccess.file_exists(cpath), "la carte a quitté le dossier d'échange")
	var arrivee: Dictionary = crb.recues[-1]
	_check(Courrier.photo_de(arrivee) != null, "la photo est arrivée")
	_check(String(arrivee.texte) == "Superbe mairie, et la rue en T !" and int(arrivee.timbre) == 2, "texte et timbre")
	_check(crb.non_lues() >= 1, "nouvelle carte non lue")
	crb.marquer_lue(String(arrivee.id))
	_check(b.save_game(SLOT_A), "courrier sauvegardé")
	var sec: Dictionary = SaveGame.read(SLOT_A).sections.get("courrier", {})
	_check((sec.get("recues", []) as Array).size() == avant + 1 and (sec.get("lues", []) as Array).has(arrivee.id), "section courrier dans la sauvegarde")
	var pm := VisitesPanel.new(b)
	b._windows_layer().add_child(pm)
	await _frames(2)
	_check(pm.view == "ma_ville", "F12 chez soi : ma ville et mon courrier")
	pm.aller_voir(arrivee)
	_check(is_equal_approx(b.rig.position.x, -1000.0) and is_equal_approx(b.rig.position.z, -40.0), "« Aller voir » mène la caméra à la carte")
	pm.fermer()
	# Une carte pour une autre partie reste dans le dossier.
	var autre := VisiteVille.paquet_carte(Courrier.nettoyer({"id": "carte-ailleurs-01", "texte": "Ailleurs", "partie": "autre"}))
	autre.fiche.partie = "autre-partie"
	var apath := Partage.echange.path_join("carte-postale-ailleurs.mbloc")
	PaquetPartage.ecrire_fichier(autre, apath)
	_check(crb.relever() == 0 and FileAccess.file_exists(apath), "une carte pour une autre partie reste dans le dossier")
	b.queue_free()
	await _frames(3)

	print("Visiteurs d'une carte entre amis :")
	var ca := CarteAmis.new()
	ca.creer("Les copains", "createur-123456")
	_check(not bool(ca.accepter_visiteur("visiteur-123456", "Inconnu", "").ok), "sans code : refusé")
	_check(bool(ca.accepter_visiteur("visiteur-123456", "Inconnu", ca.code).ok), "avec le code : visiteur")
	ca.visites_ouvertes = true
	var rv := ca.accepter_visiteur("visiteur-654321", "", "")
	_check(bool(rv.ok) and String(rv.pseudo) == "Visiteur", "visites ouvertes : entrée sans code")
	_check(ca.membres.is_empty(), "un visiteur ne devient pas membre")
	var ca2 := CarteAmis.new()
	ca2.from_dict(ca.to_dict())
	_check(ca2.visites_ouvertes, "réglage des visites sauvegardé")
	var c2: Node = await _scene()
	var srv := ServeurAmis.new()
	srv.jeu = c2
	c2.add_child(srv)
	srv.connectes[7] = {"pid": "visiteur-123456", "pseudo": "Inconnu", "ok": true, "t": 0.0, "visiteur": true}
	srv._recevoir(7, {"m": "action", "a": {"t": "poser", "id": "maison", "c": [0, 0]}})
	_check(srv._file.is_empty(), "une action d'un visiteur est refusée")
	srv._recevoir(7, {"m": "carte_postale", "carte": {"id": "carte-en-ligne-01", "de": "Usurpateur", "texte": "Coucou du serveur"}})
	var crc: Courrier = c2.courrier
	_check(crc.recues.size() == 1 and String(crc.recues[0].de) == "Inconnu", "carte en ligne rangée, signée par le vrai visiteur")
	c2.queue_free()
	await _frames(3)

	SaveGame.delete(SLOT_A)
	_vider(RACINE)
	print("TEST OK" if ok else "TEST ÉCHEC")
	quit(0 if ok else 1)
