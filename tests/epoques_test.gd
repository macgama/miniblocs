extends SceneTree
## Test des époques : année de départ libre depuis 1800, années d'apparition
## des bâtiments, services publics d'époque, véhicules de remplacement, voies,
## réseaux attendus, matériaux de l'Atelier, temps de l'histoire, sauvegarde,
## panneau Admin.
## Usage : godot --headless --path . --script res://tests/epoques_test.gd

var ok := true


class FausseHorloge extends Node:
	var unix_time := 1_800_000_000.0


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	if not cond:
		push_error("ÉCHEC : " + what)
		ok = false
	else:
		print("  ok  ", what)


## Un bâtiment déjà inventé joue-t-il ce rôle (Metiers.keys_of) ?
func _service_dispo(cle: String) -> bool:
	var types := BuildingCatalog.all_types()
	for id in types:
		if types[id].get("cache", false):
			continue
		if Metiers.keys_of(id).has(cle) and Epoques.batiment_disponible(id):
			return true
	return false


func _materiau(nom: String) -> int:
	for i in BlocMateriaux.LIST.size():
		if String(BlocMateriaux.LIST[i].name) == nom:
			return i
	return -1


func _run() -> void:
	Creations.persist = false
	print("Époque actuelle (par défaut) :")
	ReglagesPartie.actuel = ReglagesPartie.preset("normal")
	ReglagesPartie.actuel.deblocage = "tout"  # (ce test ne porte pas sur l'arbre de progression)
	_check(not Epoques.actif(), "année de départ 0 : pas de partie historique")
	_check(ReglagesPartie.actuel.raison_blocage("centrale_nucleaire") == "", "tout reste débloqué comme avant")
	_check(Epoques.vehicule("fpt") == "fpt", "véhicules modernes inchangés")
	_check(Epoques.attendu("elec") and Epoques.attendu("telecom"), "réseaux attendus comme avant")

	print("Départ en 1800 :")
	var r := ReglagesPartie.preset("normal")
	r.deblocage = "tout"  # (ce test ne porte pas sur l'arbre de progression)
	r.annee_depart = 1800
	ReglagesPartie.actuel = r
	_check(Epoques.actif() and Epoques.annee() == 1800, "nous sommes en 1800")
	_check(r.raison_blocage("centrale_nucleaire").contains("1960"), "centrale nucléaire verrouillée jusqu'en 1960")
	_check(r.raison_blocage("maison_commune") == "" and r.raison_blocage("mairie") == "", "maison de commune et mairie ouvertes")
	for id in ["ecole", "hopital", "pompiers", "police", "supermarche", "maison", "eolienne", "haussmann__immeuble"]:
		_check(not Epoques.batiment_disponible(id), "%s pas encore inventé" % id)
	for id in ["ecole_communale", "hotel_dieu", "remise_pompes", "brigade_gendarmerie", "colombages__maison", "boulangerie", "ferme", "moulin", "cimetiere_village"]:
		_check(BuildingCatalog.all_types().has(id) and Epoques.batiment_disponible(id), "%s disponible" % id)
	for cle in ["ecole", "hopital", "police", "pompiers"]:
		_check(_service_dispo(cle), "un bâtiment fait office de « %s » en 1800" % cle)
	_check(BuildingCatalog.base_of("remise_pompes") == "pompiers" and BuildingCatalog.base_of("hotel_dieu") == "hopital", "les services d'époque jouent le rôle du service")
	for k in ["R", "C", "I"]:
		var types := ZoneSystem.types_for(k, "")
		var tous := not types.is_empty()
		for id in types:
			if not Epoques.batiment_disponible(id):
				tous = false
		_check(tous, "zone %s : %d modèles, tous d'époque" % [k, types.size()])
	_check(not ZoneSystem.types_for("R", "").has("maison"), "pas de pavillon moderne dans les zones de 1800")

	print("Véhicules d'époque :")
	var attendus := {"fpt": "pompe_a_bras", "vsav": "ambulance_chevaux", "ambulance": "ambulance_chevaux",
		"police_nationale": "gendarme_cheval", "gendarmerie": "gendarme_cheval", "benne_om": "tombereau",
		"corbillard": "corbillard_chevaux", "chasse_neige": "chasse_neige_chevaux", "autocar": "diligence_messageries"}
	for m in attendus:
		_check(Epoques.vehicule(m) == attendus[m], "%s → %s" % [m, attendus[m]])
	_check(Epoques.ATTELAGES.utilitaire.has(Epoques.vehicule("semi")), "semi → %s (attelage de transport)" % Epoques.vehicule("semi"))
	var rue := VehicleCatalog.for_track("rue")
	var vieux := not rue.is_empty()
	for id in rue:
		if int(VehicleCatalog.get_type(id).year) > 1800:
			vieux = false
	_check(vieux, "circulation de 1800 : %d modèles, tous d'avant 1800" % rue.size())
	_check(VehicleCatalog.for_track("train").is_empty(), "pas encore de train")
	for id in ["pompe_a_bras", "pompe_vapeur", "ambulance_chevaux", "gendarme_cheval", "panier_salade", "tombereau",
			"corbillard_chevaux", "chasse_neige_chevaux", "autopompe_1920", "police_1930", "ambulance_1970", "diligence_messageries"]:
		var mesh := VehicleCatalog.build_mesh(id)
		_check(mesh != null and mesh.get_surface_count() > 0, "modèle 3D de %s" % id)
	_check(VehicleCatalog.beacons(VehicleCatalog.get_type("pompe_a_bras")).is_empty(), "pas de gyrophare sur la pompe à bras")
	for id in EpoquesTypes.DEFS:
		var mesh := BuildingCatalog.build_mesh(id)
		_check(mesh != null and mesh.get_surface_count() > 0, "modèle 3D de %s" % id)

	print("Voies, réseaux et matériaux :")
	_check(Epoques.raison_voie("rue") == "" and Epoques.raison_voie("route") == "", "rues et routes de tout temps")
	_check(Epoques.raison_voie("autoroute").contains("1930") and Epoques.raison_voie("train").contains("1830"), "autoroute et train verrouillés")
	_check(Epoques.raison_station("gare") != "" and Epoques.raison_station("port") == "", "gare verrouillée, port ouvert")
	_check(Epoques.raison_troncon("ligne_mt") != "" and Epoques.raison_troncon("conduite_eau") == "", "pas de ligne électrique, conduites d'eau oui")
	_check(not Epoques.attendu("elec") and not Epoques.attendu("eau") and not Epoques.attendu("telecom"), "personne n'attend le courant, l'eau courante ni le téléphone")
	_check(not Telecom.necessaire() and not Dechets.actif(), "téléphone et ramassage des ordures pas encore nécessaires")
	_check(Epoques.materiau_disponible(_materiau("Brique")) and Epoques.materiau_disponible(_materiau("Colombage")), "brique et colombage disponibles")
	_check(not Epoques.materiau_disponible(_materiau("Béton")) and not Epoques.materiau_disponible(_materiau("Plastique rouge")), "béton et plastique pas encore inventés")

	print("Le temps passe :")
	Epoques.aller_a(1900)
	_check(Epoques.annee() == 1900 and r.histoire_saut == 100, "l'admin saute à 1900")
	_check(Epoques.vehicule("fpt") == "pompe_vapeur" and Epoques.vehicule("police_nationale") == "panier_salade", "pompe à vapeur et voiture cellulaire")
	_check(Epoques.raison_voie("train") == "" and Epoques.raison_voie("tram") == "" and Epoques.raison_voie("autoroute") != "", "train et tram arrivés, pas l'autoroute")
	_check(Epoques.batiment_disponible("ecole_republicaine") and Epoques.batiment_disponible("haussmann__immeuble"), "école de la République et immeubles haussmanniens")
	_check(Epoques.batiment_disponible("centrale_charbon_locale") and not Epoques.attendu("elec"), "électricité inventée mais pas encore indispensable")
	_check(Epoques.attendu("eau") and Epoques.attendu("dechets") and Epoques.materiau_disponible(_materiau("Béton")), "eau courante attendue, béton disponible")
	_check(not VehicleCatalog.for_track("rue").is_empty(), "circulation en 1900")
	var inv := Epoques.inventions_entre(1800, 1900)
	_check(inv.size() >= 10 and int(inv[inv.size() - 1].annee) == 1900, "%d inventions annoncées entre 1800 et 1900" % inv.size())
	Epoques.aller_a(1965)
	_check(Epoques.vehicule("fpt") == "camion_pompiers_60" and Epoques.batiment_disponible("ecole") and Epoques.batiment_disponible("centrale_nucleaire"), "1965 : camion de pompiers, école moderne, nucléaire")
	_check(Epoques.attendu("elec") and not Epoques.attendu("telecom"), "1965 : courant indispensable, téléphone pas encore")
	Epoques.aller_a(2026)
	_check(Epoques.vehicule("fpt") == "fpt" and Epoques.vehicule("benne_om") == "benne_om", "2026 : modèles d'aujourd'hui")
	_check(not Epoques.batiment_disponible("futuriste__tour"), "le futuriste attend 2040")

	print("Rythme de l'histoire :")
	var r3 := ReglagesPartie.preset("normal")
	r3.deblocage = "tout"  # (ce test ne porte pas sur l'arbre de progression)
	r3.annee_depart = 1850
	r3.rythme_histoire = 10.0
	ReglagesPartie.actuel = r3
	var h := FausseHorloge.new()
	root.add_child(h)
	Epoques.horloge = h
	_check(Epoques.annee() == 1850 and r3.histoire_debut == h.unix_time, "le temps de l'histoire part de l'horloge")
	h.unix_time += Epoques.SECONDES_AN * 2.05
	_check(Epoques.annee() == 1870, "deux ans de jeu à ×10 : 1870")
	var d := r3.to_dict()
	var r4 := ReglagesPartie.new()
	r4.from_dict(d)
	_check(r4.annee_depart == 1850 and r4.rythme_histoire == 10.0 and r4.histoire_debut == r3.histoire_debut, "sauvegarde : époque gardée")
	r4.from_dict({"annee_depart": 1200})
	_check(r4.annee_depart == Epoques.ANNEE_MIN, "pas avant 1800")
	_check(r3.summary().contains("départ en 1850"), "résumé du globe : %s" % r3.summary())

	print("Panneau Admin :")
	var p := AdminPanel.new(r3, false, true)
	root.add_child(p)
	await process_frame
	_check(p._epoque.button_pressed and int(p._annee.value) == 1870, "panneau : partie historique, année en cours 1870")
	p._annee.value = 1900
	_check(Epoques.annee(r3) == 1900, "changer l'année dans l'Admin saute dans le temps")
	p._epoque.button_pressed = false
	_check(not Epoques.actif(r3), "décocher : retour à l'époque actuelle")
	p.queue_free()
	var pc := AdminPanel.new(ReglagesPartie.preset("normal"), true, true)
	root.add_child(pc)
	await process_frame
	pc._epoque.button_pressed = true
	pc._annee.value = 1820
	_check(pc.reglages.annee_depart == 1820, "création de partie : départ en 1820")
	pc.queue_free()
	Epoques.horloge = null
	h.queue_free()
	ReglagesPartie.actuel = ReglagesPartie.preset("normal")
	ReglagesPartie.actuel.deblocage = "tout"  # (ce test ne porte pas sur l'arbre de progression)
	await process_frame

	print("TEST OK" if ok else "TEST ÉCHEC")
	quit(0 if ok else 1)
