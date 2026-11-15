extends SceneTree
## Test des scénarios et défis : catalogue (champs, objectifs, bâtiments et
## voies qui existent), score et médailles, classement local, fenêtre du menu
## principal, partie lancée en scénario (réglages, date imposée, carte à
## l'écran, voies limitées, fondation, événements, objectifs, triche, emprunts
## refusés, date limite, victoire, bilan, classement, sauvegarde).
## Usage : godot --headless --path . --script res://tests/scenarios_test.gd

var ok := true


func _initialize() -> void:
	_run.call_deferred()
	create_timer(400.0).timeout.connect(func() -> void:
		push_error("ÉCHEC : délai dépassé")
		quit(1))


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


const TYPES_OBJECTIFS := ["habitants", "satisfaction", "batiment", "lignes", "caisse", "sans_dette", "palier",
	"voies", "villes", "relies", "chomage_max"]


func _run() -> void:
	Creations.persist = false
	BatimentsVie.chantiers = false
	Classement.chemin = "user://test_scenarios_classement.json"
	Classement.recharger()
	Classement.effacer()

	print("Catalogue :")
	_check(Scenarios.ids().size() >= 6, "%d scénarios" % Scenarios.ids().size())
	for id in Scenarios.ids():
		var s := Scenarios.donnees(id)
		var champs := s.has("nom") and s.has("accroche") and s.has("histoire") and s.has("lieu") and s.has("jours") \
			and s.has("objectifs") and s.has("medailles") and int(s.difficulte) >= 1 and int(s.difficulte) <= 3
		var refs := true
		for o in (s.objectifs as Array) + (s.get("bonus", []) as Array):
			if not TYPES_OBJECTIFS.has(String(o.type)) or String(o.get("texte", "")) == "":
				refs = false
			if String(o.type) == "batiment" and BuildingCatalog.get_type(String(o.ref)).is_empty():
				refs = false
				print("     bâtiment inconnu : ", o.ref)
		for k in s.get("contraintes", {}).get("routes", []):
			if TransportTypes.get_type(String(k)).is_empty():
				refs = false
		for k in s.get("reglages", {}):
			if k != "preset" and not (k in ReglagesPartie.new()):
				refs = false
				print("     réglage inconnu : ", k)
		var m: Dictionary = s.medailles
		_check(champs and refs and int(m.argent) < int(m.or), "« %s » : champs, objectifs, bâtiments, voies et réglages valides" % String(s.nom))

	print("Score et médailles :")
	var r := {"objectifs": 4, "total": 4, "bonus": 1, "jours_restants": 40, "habitants": 420, "satisfaction": 60,
		"dette": 0.0, "victoire": true}
	var sc := Scenarios.calculer_score("crue", r)
	# (4×1000 + 500 + 2000 + 40×25 + 420 + 60×20) × 1,25
	_check(int(sc.total) == roundi((4000 + 500 + 2000 + 1000 + 420 + 1200) * 1.25), "score détaillé (%d points, %d lignes)" % [int(sc.total), (sc.lignes as Array).size()])
	_check(Scenarios.medaille("crue", int(sc.total), true) == 3, "or au-dessus du seuil")
	_check(Scenarios.medaille("crue", 7600, true) == 2 and Scenarios.medaille("crue", 3000, true) == 1, "argent puis bronze")
	_check(Scenarios.medaille("crue", 99999, false) == 0, "pas de médaille sans victoire")
	r.victoire = false
	r.objectifs = 2
	r.dette = 2_000_000.0
	var perdu := Scenarios.calculer_score("crue", r)
	_check(int(perdu.total) < int(sc.total) and (perdu.lignes as Array).any(func(l) -> bool: return int(l[1]) < 0), "défaite : moins de points, dette retirée (%d)" % int(perdu.total))

	print("Classement :")
	_check(Classement.liste("crue").is_empty(), "classement vide au départ")
	_check(Classement.ajouter("crue", {"nom": "Alice", "score": 5000, "jours": 90, "medaille": 1}) == 1, "premier score : 1re place")
	_check(Classement.ajouter("crue", {"nom": "Bob", "score": 9000, "jours": 70, "medaille": 2}) == 1, "meilleur score : passe devant")
	_check(Classement.ajouter("crue", {"nom": "Chloé", "score": 9000, "jours": 60, "medaille": 2}) == 1, "égalité : le plus rapide devant")
	for i in 10:
		Classement.ajouter("crue", {"nom": "J%d" % i, "score": 6000 + i, "jours": 100, "medaille": 1})
	_check(Classement.liste("crue").size() == Classement.TAILLE, "10 scores gardés au plus")
	_check(Classement.ajouter("crue", {"nom": "Lent", "score": 10, "jours": 120, "medaille": 1}) == 0, "trop bas : pas classé")
	Classement.renommer("crue", 1, "  Chloé M.  ")
	Classement.recharger()
	_check(String(Classement.meilleur("crue").nom) == "Chloé M." and Classement.meilleure_medaille("crue") == 2, "relu du fichier, nom changé")
	_check(Classement.nom_steam("crue") == "scenario_crue" and not Classement.en_ligne(), "nom du classement Steam, pas encore en ligne")
	var envoye := []
	Classement.envoi_en_ligne = func(id: String, e: Dictionary) -> void: envoye.append([id, e])
	Classement.ajouter("course_bourg", {"nom": "Dan", "score": 4000, "jours": 50, "medaille": 1})
	Classement.envoi_en_ligne = Callable()
	_check(envoye.size() == 1 and String(envoye[0][0]) == "course_bourg", "envoi au classement en ligne quand il est branché")
	Classement.effacer()

	print("Fenêtre du menu :")
	Classement.ajouter("sans_voiture", {"nom": "Eve", "score": 9500, "jours": 80, "medaille": 2})
	var panel := ScenariosPanel.new()
	root.add_child(panel)
	await _frames(2)
	_check(panel._boutons.size() == Scenarios.ids().size(), "un bouton par scénario")
	panel.choisir("sans_voiture")
	await _frames(1)
	_check(panel._detail.get_node_or_null("Jouer") != null and panel._detail.get_node_or_null("Classement") != null, "détail : Jouer et classement")
	_check(String((panel._boutons.sans_voiture as Button).text).contains("Argent"), "meilleure médaille sur le bouton")
	var joue := []
	panel.jouer.connect(func(id: String) -> void: joue.append(id))
	(panel._detail.get_node("Jouer") as Button).pressed.emit()
	_check(joue == ["sans_voiture"], "« Jouer » envoie le scénario")
	panel.fermer()
	Classement.effacer()

	print("Partie en scénario :")
	var titre := Scenarios.preparer("sans_voiture")
	_check(titre.contains("Une ville sans voiture") and Scenarios.demande == "sans_voiture", "préparation : %s" % titre)
	_check(GameStart.place_name.begins_with("Houten") and GameStart.pays == "nl", "lieu et pays du scénario")
	ReglagesPartie.prochaine.fondateurs = 0
	_check(not ReglagesPartie.prochaine.acces_route and not ReglagesPartie.prochaine.tutoriel, "réglages imposés (pas d'accès route, pas de tutoriel)")
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.view_radius_override = 1200.0
	world.set_origin(52.0284, 5.1683)
	for i in 3000:
		await process_frame
		if i >= 120 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	scene.urgences.random_calls = false
	var s: ScenarioPartie = scene.scenario
	var carte: ScenarioCarte = scene.scenario_carte
	var y := world.cell_height(Vector2i(0, 0))
	_check(s != null and ScenarioPartie.instance == s and s.id == "sans_voiture" and s.en_cours(), "scénario démarré")
	_check(Scenarios.demande == "", "demande lue une seule fois")
	_check(not ReglagesPartie.actuel.acces_route and not bs.require_access, "accès route coupé dans la partie")
	await _frames(3)
	carte.rafraichir()
	_check(carte._panel.visible and carte._titre_l.text == "Une ville sans voiture", "carte du scénario à l'écran")
	_check(carte._jour_l.text.begins_with("Jour 0 sur 150"), "jour et date limite : %s" % carte._jour_l.text)
	_check(not scene.tuto_carte._obj_panel.visible, "pas de carte du tutoriel par-dessus")

	print("Voies limitées :")
	var av := transport.build_segment("avenue", Vector3(200, y, 0), Vector3(200, y, 150))
	_check(not av.ok and String(av.reason).contains("rue de desserte"), "avenue refusée : %s" % String(av.get("reason", "")))
	var pc := transport.build_segment("piste_cyclable", Vector3(-150, y, 0), Vector3(-150, y, 400))
	_check(pc.ok, "piste cyclable permise")
	_check(transport.build_segment("rue", Vector3(300, y, 0), Vector3(300, y, 100)).ok, "petite rue permise")
	var longue := transport.build_segment("rue", Vector3(340, y, 0), Vector3(340, y, 700))
	_check(not longue.ok and String(longue.reason).contains("Plus que"), "au-delà de 600 m de rues : refus (%s)" % String(longue.get("reason", "")))
	var obj_voies: Dictionary = Scenarios.donnees("sans_voiture").objectifs[1]
	_check(absf(s.mesure(obj_voies) - 400.0) < 5.0 and s.progres(obj_voies) == "0,4 / 3,0 km", "progrès des chemins : %s" % s.progres(obj_voies))

	print("Fondation et événements :")
	_check(carte._corps.get_child_count() > 0 and (carte._corps.get_child(0) as Label).text.contains("fonde"), "carte : il faut d'abord fonder")
	scene.communes.nom_en_attente = "Houten"
	var mc := bs.place("maison_commune", Vector2i(0, 0), 0)
	_check(mc > 0, "Maison de commune posée")
	var msgs := []
	s.message.connect(func(t: String) -> void: msgs.append(t))
	s.suivre()
	_check(s.jour_fondation == 0, "jour de fondation noté")
	s.jour0 -= 3
	s.suivre()
	_check(s.evenements_faits.has(0) and msgs.any(func(t: String) -> bool: return t.contains("600 m")), "événement du jour 2 après la fondation")
	var argent: int = bs.money
	s.jour0 -= 30
	s.suivre()
	_check(s.evenements_faits.has(1) and bs.money == argent + 3_000_000, "subvention versée (%s)" % BuildingSystem.format_money(bs.money - argent))
	_check(not s.fini, "objectifs pas remplis : on continue")

	print("Sauvegarde :")
	var sec: Dictionary = scene.save_sections()
	_check(sec.has("scenario") and String(sec.scenario.id) == "sans_voiture", "section « scenario »")
	var d := s.to_dict()
	s.clear()
	_check(not s.en_cours() and ScenarioPartie.refus_voie("avenue", 10.0) == "", "remis à zéro : plus de contrainte")
	s.from_dict(JSON.parse_string(JSON.stringify(d)))
	_check(s.en_cours() and s.jour_fondation == 0 and s.evenements_faits.has(1) and not s.triche, "relu : en cours, événements faits, pas de triche")
	_check(not s.reglages_depart.is_empty() and s.reglages_depart == s._reglages_vus(), "réglages du départ relus à l'identique")
	s.suivre()
	_check(not s.triche, "relu : toujours pas de triche au pas suivant")

	print("Victoire :")
	s.terminer(true)
	await _frames(2)
	_check(s.fini and bool(s.resultat.victoire) and int(s.resultat.score) > 0, "victoire : %d points" % int(s.resultat.score))
	_check(int(s.resultat.rang) == 1 and Classement.liste("sans_voiture").size() == 1, "entrée au classement, 1re place")
	_check(scene.bilan_scenario != null and scene.bilan_scenario.get_node_or_null("CenterContainer/BilanScenario") != null or scene.bilan_scenario != null, "bilan de fin à l'écran")
	_check(ScenarioPartie.refus_voie("avenue", 10.0) == "", "après la fin : plus de contrainte")
	scene.bilan_scenario.fermer()
	await _frames(1)
	_check(scene.bilan_scenario == null, "« Continuer à jouer » ferme le bilan")
	carte.rafraichir()
	_check(carte._jour_l.text.begins_with("Réussi en"), "carte : %s" % carte._jour_l.text)

	print("Date imposée, triche :")
	var mois0 := int(scene.ambiance.local_datetime().month)
	s.demarrer("crue")
	var dt: Dictionary = scene.ambiance.local_datetime()
	_check(int(dt.month) == 9 and int(dt.day) == 15, "départ le 15 septembre (avant : mois %d)" % mois0)
	_check(s.jour() == 0 and s.jour_fondation < 0, "jour 0, pas encore de fondation comptée")
	s.suivre()
	_check(s.jour_fondation == 0, "village déjà là : fondation comptée")
	bs.unlimited_money = true
	s.suivre()
	_check(s.triche, "argent illimité en cours de route : triche notée")
	bs.unlimited_money = false
	s.terminer(true)
	_check(int(s.resultat.rang) == 0 and Classement.liste("crue").is_empty(), "pas de classement après triche")
	scene.bilan_scenario.fermer()

	print("Emprunts refusés, date limite :")
	s.demarrer("caisses_vides")
	var why: String = scene.budget.refus_emprunt(100_000.0, 10)
	_check(why.contains("banque"), "emprunt refusé : %s" % why)
	var obj_dette: Dictionary = Scenarios.donnees("caisses_vides").objectifs[1]
	_check(s.rempli(obj_dette) and s.progres(obj_dette) == "aucune", "aucune dette")
	s.jour0 -= 200
	s.suivre()
	_check(s.fini and not bool(s.resultat.victoire) and int(s.resultat.medaille) == 0, "date limite : scénario perdu, sans médaille")
	_check(scene.budget.refus_emprunt(100_000.0, 10) == "", "après la fin : emprunts permis")
	_check(scene.bilan_scenario != null and scene.bilan_scenario.titre() == "Date limite dépassée", "bilan : %s" % scene.bilan_scenario.titre())
	scene.bilan_scenario.fermer()

	print("Abandon :")
	s.demarrer("course_bourg")
	carte.rafraichir()
	var ab := carte._corps.find_child("Abandonner", true, false) as Button
	_check(ab != null, "bouton Abandonner")
	ab.pressed.emit()
	_check(s.en_cours() and carte._confirmer, "premier clic : demande de confirmation")
	carte.rafraichir()
	(carte._corps.find_child("Abandonner", true, false) as Button).pressed.emit()
	_check(s.fini and bool(s.resultat.abandon) and int(s.resultat.rang) == 0, "abandon confirmé : pas de classement")
	scene.bilan_scenario.fermer()
	scene.hud.create_mode = true
	await _frames(2)
	_check(not carte._panel.visible, "carte masquée en mode Créer")
	scene.hud.create_mode = false

	Classement.effacer()
	print("RÉSULTAT : ", "OK" if ok else "ÉCHEC")
	print("TEST OK" if ok else "TEST ÉCHEC")
	quit(0 if ok else 1)
