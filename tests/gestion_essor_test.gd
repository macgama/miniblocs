extends SceneTree
## Test de l'« essor » du mode gestion (GestionEssor), commun à tous les
## genres : recherche (points, projets, bonus), campagnes (époque, coût par
## jour, lassitude), défis (proposé, accepté, réussi, prime), paliers, avis
## des clients, ressenti, classement des concurrents, gestion automatique,
## sauvegarde et onglets Essor / Avis de l'écran.
## Usage : xvfb-run -a godot --path . --rendering-driver opengl3 --script res://tests/gestion_essor_test.gd

var ok := true


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


func _run() -> void:
	_types_tests()
	await _city_tests()
	print("TEST OK" if ok else "TEST ÉCHEC")
	quit(0 if ok else 1)


func _types_tests() -> void:
	print("Catalogues :")
	var ids := {}
	for r in GestionEssor.RECHERCHES:
		ids[String(r.id)] = true
		var av := String(r.get("apres", ""))
		_check(av == "" or av == "tout" or ids.has(av), "recherche %s : prérequis avant elle" % r.id)
	_check(GestionEssor.RECHERCHES.size() >= 8, "%d projets de recherche" % GestionEssor.RECHERCHES.size())
	_check(GestionEssor.CAMPAGNES.size() >= 6 and GestionEssor.CAMPAGNES_VILLE.size() >= 4, "campagnes privées et publiques")
	_check(GestionEssor.DEFIS.size() >= 6, "%d sortes de défis" % GestionEssor.DEFIS.size())
	var e := GestionEssor.charger(JSON.parse_string(JSON.stringify(GestionEssor.vide())))
	_check(e.faits is Array and e.camp is Dictionary and typeof(e.defis_ok) == TYPE_INT, "état vide relu du JSON")


func _city_tests() -> void:
	print("Ville :")
	Creations.persist = false
	BatimentsVie.chantiers = false
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var transport: TransportSystem = scene.get_node("Transport")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 40
	world.view_radius_override = 600.0
	world.set_origin(46.2, 6.9)
	for i in 3000:
		await process_frame
		if i >= 120 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	var tour: Tourisme = scene.tourisme
	var gest: Gestion = scene.gestion
	var vue: GestionVue = scene.gestion_vue
	var pop: Population = scene.population
	var prod: Production = scene.production
	var urg: Urgences = scene.urgences
	for nd in [transport.traffic, tour, pop, scene.parc, scene.zoo, scene.musee, scene.spectacles, scene.dechets, prod]:
		nd.set_process(false)
	urg.set_process(false)
	urg.random_calls = false
	bs.unlimited_money = false
	bs.money = 50_000_000
	ReglagesPartie.actuel.deblocage = "tout"
	var y := world.cell_height(Vector2i(0, 0))
	_check(transport.build_segment("route", Vector3(-400, y, 0), Vector3(400, y, 0)).ok, "route")
	var poser := func(id: String, c: Vector2i) -> int:
		var sn := bs.road_snap(id, c)
		if sn.is_empty():
			return -1
		return bs.place(id, sn.center, int(sn.r), 0, float(sn.get("a", 0.0)))
	var resto: int = poser.call("haussmann__restaurant", Vector2i(0, -14))
	var cafe: int = poser.call("cafe", Vector2i(60, -12))
	var cas: int = poser.call("pompiers", Vector2i(-90, -16))
	_check(resto > 0 and cafe > 0 and cas > 0, "brasserie, café et caserne posés")
	for b in [resto, cafe, cas]:
		if b > 0:
			bs.buildings[b]["chantier"] = false
	prod._sync()
	pop._sync_buildings()
	urg._sync_stations()

	print("Sans rien faire, rien ne change :")
	_check(GestionEssor.bonus(gest, resto, "attrait") == 0.0 and GestionEssor.facteur_pannes(gest, resto) == 1.0, "pas de bonus pour un restaurant jamais ouvert")

	print("Recherche :")
	var st := gest.etat(resto)
	gest.set_auto(resto, false)
	prod.sites[resto].cash = 200_000.0
	var pj := GestionEssor.points_jour(gest, resto)
	_check(pj >= 1.0, "%.1f points de recherche par jour" % pj)
	_check(GestionEssor.refus_recherche(st, "maintenance") != "", "maintenance demande d'abord les méthodes")
	_check(bool(GestionEssor.lancer_recherche(gest, resto, "methodes").ok), "méthodes de travail lancées")
	var v0 := gest.effet(resto, "vitesse")
	for i in 40:
		gest.nouveau_jour({"day": gest.jour + 1, "month": 6})
		if GestionEssor.faite(st, "methodes"):
			break
	_check(GestionEssor.faite(st, "methodes"), "projet terminé au bout de quelques jours")
	_check(gest.effet(resto, "vitesse") > v0 + 0.1, "service plus rapide (%.2f → %.2f)" % [v0, gest.effet(resto, "vitesse")])
	_check(GestionEssor.refus_recherche(st, "maintenance") == "", "maintenance débloquée")
	GestionEssor.es(st).faits.append("maintenance")
	GestionEssor.es(st).faits.append("achats")
	_check(GestionEssor.facteur_pannes(gest, resto) < 0.8, "maintenance préventive : moins de pannes")
	var ch0 := gest.entretien_jour(resto)
	_check(GestionEssor.refus_recherche(st, "excellence") != "", "l'excellence attend tous les projets")

	print("Campagnes :")
	var poss := GestionEssor.campagnes_possibles(gest, resto)
	_check(not poss.is_empty(), "%d campagnes possibles à l'année %d" % [poss.size(), EpoquesObjets.annee_partie()])
	var a0 := gest.effet(resto, "attrait")
	st.prix = 1.8
	var aff0 := Gestion.affluence_de(resto)
	var res := GestionEssor.lancer_campagne(gest, resto, "affiches")
	_check(bool(res.ok) and not GestionEssor.campagne_en_cours(gest, resto).is_empty(), "affiches posées en ville")
	_check(gest.effet(resto, "attrait") > a0 + 0.03, "plus de clients attirés")
	_check(Gestion.affluence_de(resto) > aff0, "affluence du restaurant en hausse (%.2f → %.2f)" % [aff0, Gestion.affluence_de(resto)])
	st.prix = 1.0
	_check(gest.entretien_jour(resto) > ch0, "la campagne se paie chaque jour")
	_check(not bool(GestionEssor.lancer_campagne(gest, resto, "journal").ok), "une seule campagne à la fois")
	GestionEssor.arreter_campagne(gest, resto)
	_check(GestionEssor.lassitude(gest, resto, "affiches"), "refaire les affiches tout de suite : le public s'en lasse")
	res = GestionEssor.lancer_campagne(gest, resto, "affiches")
	_check(bool(res.lasse) and float(GestionEssor.campagne_en_cours(gest, resto).force) < 1.0, "moitié d'effet")
	GestionEssor.arreter_campagne(gest, resto)
	_check(GestionEssor.campagne(gest, cas, "recrutement").size() > 0 and GestionEssor.campagne(gest, cas, "radio").is_empty(), "la caserne a ses campagnes à elle")

	print("Défis :")
	var e := GestionEssor.es(st)
	e.defi_prochain = gest.jour
	gest.nouveau_jour({"day": gest.jour + 1, "month": 6})
	if (e.defi as Dictionary).is_empty():
		GestionEssor._proposer_defi(gest, resto, st)
	_check(String(e.defi.get("etat", "")) == "offert", "défi proposé : %s" % GestionEssor.texte_defi(gest, resto, e.defi))
	# Un défi sûr pour le test : régler 5 demandes.
	e.defi = {"id": "demandes", "etat": "offert", "cible": 5.0, "jours": 7, "offert": gest.jour, "prime": 2000}
	_check(bool(GestionEssor.accepter_defi(gest, resto).ok) and String(e.defi.etat) == "actif", "défi accepté")
	var cash0 := float(prod.sites[resto].cash)
	st.reglees = int(st.reglees) + 5
	gest.nouveau_jour({"day": gest.jour + 1, "month": 6})
	_check(int(e.defis_ok) == 1 and (e.defi as Dictionary).is_empty(), "défi réussi")
	_check(float(prod.sites[resto].cash) > cash0 + 1000.0, "prime versée sur la caisse du restaurant")
	var bs_avec := GestionEssor.bonus(gest, resto, "satisf")
	var bf := int(e.bonus_fin)
	e.bonus_fin = -1
	var bs_sans := GestionEssor.bonus(gest, resto, "satisf")
	e.bonus_fin = bf
	_check(int(e.bonus_fin) > gest.jour and bs_avec - bs_sans > 0.03, "clients ravis pendant 30 jours")
	e.defi = {"id": "objets", "etat": "offert", "cible": 3.0, "jours": 2, "offert": gest.jour, "prime": 1000}
	GestionEssor.accepter_defi(gest, resto)
	for i in 3:
		gest.nouveau_jour({"day": gest.jour + 1, "month": 6})
	_check(int(e.defis_rates) == 1, "défi manqué quand le temps est écoulé")

	print("Paliers :")
	for pid in ["salle", "salle", "salle", "salle"]:
		gest.ameliorer(resto, pid)
	var pal := GestionEssor.paliers(gest, resto)
	var txt := ""
	for p in pal:
		txt += String(p.nom) + " ; "
	_check(txt.contains("maximum"), "palier : %s" % txt)
	gest.nouveau_jour({"day": gest.jour + 1, "month": 6})
	_check("max_salle" in (e.paliers as Array), "palier annoncé au journal")

	print("Avis et concurrents :")
	st.hier["clients"] = 40.0
	for i in 30:
		GestionEssor._nouvel_avis(gest, resto, st)
	_check((e.avis as Array).size() > 0 and (e.avis as Array).size() <= GestionEssor.AVIS_MAX, "%d avis de clients" % (e.avis as Array).size())
	_check(GestionEssor.moyenne_avis(st) >= 1.0, "moyenne %.1f" % GestionEssor.moyenne_avis(st))
	gest.etat(resto).salaire = 1.3
	_check("Une équipe souriante" in GestionEssor.ressenti(gest, resto).plus, "les clients remarquent l'équipe bien payée")
	gest.nouvelle_panne(resto)
	_check(not (GestionEssor.ressenti(gest, resto).moins as Array).is_empty(), "et la panne")
	var cl := GestionEssor.concurrents(gest, resto)
	_check(cl.size() == 2 and GestionEssor.rang(gest, resto).y == 2, "brasserie et café en concurrence")

	print("Gestion automatique :")
	gest.set_auto(cafe, true)
	var sc := gest.etat(cafe)
	prod.sites[cafe].cash = 2_000_000.0
	for i in 12:
		gest.nouveau_jour({"day": gest.jour + 1, "month": 6})
	var ec := GestionEssor.es(sc)
	_check(String(ec.rech) != "" or not (ec.faits as Array).is_empty(), "le café fait sa recherche tout seul")
	_check(int(ec.camps) >= 1 or gest.occupation(cafe) >= 0.7, "et sa publicité quand il manque de clients")

	print("Service public :")
	var sv := gest.etat(cas)
	GestionEssor.es(sv).faits.append("fidelite")
	_check(gest.effet(cas, "equipage") >= 1.0, "fidélisation de la caserne : une personne de garde en plus")
	_check(GestionEssor.effets_recherche(gest, cas, GestionEssor.recherche("fidelite")).has("equipage") and not GestionEssor.effets_recherche(gest, cas, GestionEssor.recherche("fidelite")).has("attrait"), "pas de clients attirés pour un service public")

	print("Équipe en personnes :")
	var eq := GestionPlus.equipe(gest, resto)
	_check(eq.size() >= 2 and GestionPlus.TRAITS.has(String(eq[0].trait)), "%d personnes, chacune son trait" % eq.size())
	gest.etat(resto).salaire = 1.5
	for i in 10:
		gest.nouveau_jour({"day": gest.jour + 1, "month": 6})
	var mh := GestionPlus.moral_moyen(gest, resto)
	gest.etat(resto).salaire = 0.8
	for i in 10:
		gest.nouveau_jour({"day": gest.jour + 1, "month": 6})
	_check(GestionPlus.moral_moyen(gest, resto) < mh - 0.5, "le moral suit le salaire (%.1f → %.1f)" % [mh, GestionPlus.moral_moyen(gest, resto)])
	for p in eq:
		p.moral = 0.2
		p.bas = 6
	gest.etat(resto).salaire = 0.8
	var dem0 := int(e.demissions)
	gest.nouveau_jour({"day": gest.jour + 1, "month": 6})
	_check(int(e.demissions) > dem0, "moral trop bas une semaine : démissions (%d)" % (int(e.demissions) - dem0))
	gest.etat(resto).salaire = 1.0
	e.demande = {"i": 0, "jour": gest.jour}
	var ch_a := gest.entretien_jour(resto)
	GestionPlus.repondre_augmentation(gest, resto, true)
	_check(float(GestionPlus.equipe(gest, resto)[0].aug) > 0.0 and gest.entretien_jour(resto) > ch_a, "augmentation accordée : elle se paie chaque jour")
	_check(bool(GestionPlus.employe_du_mois(gest, resto, 1).ok) and not bool(GestionPlus.employe_du_mois(gest, resto, 2).ok), "un employé du mois par mois")
	var f0 := GestionPlus.fatigue_moyenne(gest, resto)
	GestionPlus.set_pauses(gest, resto, 2)
	for i in 5:
		gest.nouveau_jour({"day": gest.jour + 1, "month": 6})
	_check(GestionPlus.fatigue_moyenne(gest, resto) <= f0 + 0.01, "pauses longues : l'équipe récupère")

	print("Prix des services :")
	var svc := GestionPlus.services(gest, resto)
	_check(not svc.is_empty(), "services à prix : %s" % ", ".join(svc))
	if not svc.is_empty():
		var ve0 := gest.effet(resto, "ventes")
		GestionPlus.changer_tarif(gest, resto, String(svc[0]), 1)
		GestionPlus.changer_tarif(gest, resto, String(svc[0]), 1)
		_check(gest.effet(resto, "ventes") > ve0 and GestionPlus.bonus_tarifs(gest, resto, "satisf") < 0.0, "plus cher : plus de ventes, clients moins contents")

	print("Types de clients :")
	var pe := GestionPlus.parts(gest, resto, 7)
	var ph := GestionPlus.parts(gest, resto, 1)
	_check(float(pe.familles) > float(ph.familles) and float(ph.affaires) > float(pe.affaires), "l'été plus de familles, l'hiver plus de gens d'affaires")
	var ff0 := float(GestionPlus.avis_segment(gest, resto, GestionPlus.SEGMENTS[0]).fit)
	gest.ameliorer(resto, "terrasse")
	gest.ameliorer(resto, "terrasse")
	_check(float(GestionPlus.avis_segment(gest, resto, GestionPlus.SEGMENTS[0]).fit) > ff0, "la terrasse plaît aux familles")

	print("Banque :")
	var o := GestionPlus.offres_pret(gest, resto)
	_check(o.size() == 3 and float(o[0].total) > float(o[0].montant), "3 prêts possibles, avec intérêts")
	var c0 := float(prod.sites[resto].cash)
	_check(bool(GestionPlus.emprunter(gest, resto, 0).ok) and float(prod.sites[resto].cash) > c0 + float(o[0].montant) - 1.0, "argent versé sur la caisse")
	_check(not bool(GestionPlus.emprunter(gest, resto, 1).ok), "un seul prêt à la fois")
	var reste := float(GestionPlus.pret(gest, resto).reste)
	gest.nouveau_jour({"day": gest.jour + 1, "month": 6})
	_check(float(GestionPlus.pret(gest, resto).reste) < reste, "une échéance par jour")
	_check(bool(GestionPlus.rembourser_pret(gest, resto).ok) and GestionPlus.pret(gest, resto).is_empty(), "remboursé d'un coup")
	_check(GestionPlus.offres_pret(gest, cas).is_empty(), "pas de prêt pour un service public")

	print("Agrandissement et trophées :")
	var mx := gest.niveau_max(resto, "cuisine")
	_check(bool(GestionPlus.agrandir(gest, resto).ok) and gest.niveau_max(resto, "cuisine") == mx + 1, "agrandi : un niveau de plus par pièce")
	gest.nouveau_jour({"day": gest.jour + 1, "month": 6})
	var tr := GestionPlus.trophees(gest, resto)
	_check("defi_1" in tr and "agrandi" in tr, "trophées gagnés : %s" % ", ".join(tr))

	print("Sauvegarde :")
	var faits: Array = (e.faits as Array).duplicate()
	var nav := (e.avis as Array).size()
	var d := gest.to_dict()
	gest.clear()
	gest.from_dict(JSON.parse_string(JSON.stringify(d)))
	var e2 := GestionEssor.es(gest.etat(resto))
	_check(e2.faits == faits and int(e2.defis_ok) == 1 and (e2.avis as Array).size() == nav, "recherche, défis et avis rechargés")
	_check((e2.equipe as Array).size() >= 2 and typeof(e2.ext) == TYPE_INT and int(e2.ext) == 1 and (e2.trophees as Array).size() >= 2, "équipe, agrandissement et trophées rechargés")
	_check(typeof(e2.bonus_fin) == TYPE_INT and typeof((e2.avis as Array)[0][1]) == TYPE_INT, "types remis après le JSON")

	print("Écran :")
	_check(scene.ouvrir_gestion(resto) and vue.est_ouvert(), "l'écran s'ouvre")
	await process_frame
	vue.choisir("")
	var tab: Button = vue._carte_corps.find_child("Onglet_essor", true, false)
	_check(tab != null, "onglet Essor")
	if tab != null:
		tab.pressed.emit()
	_check(vue._carte_corps.find_child("Recherche_ambiance", true, false) != null, "liste des projets de recherche")
	var lancer: Button = vue._carte_corps.find_child("Campagne_journal", true, false).find_child("Bouton", true, false) if vue._carte_corps.find_child("Campagne_journal", true, false) != null else null
	_check(lancer != null and not lancer.disabled, "bouton de la campagne dans le journal")
	if lancer != null:
		lancer.pressed.emit()
	_check(String(GestionEssor.campagne_en_cours(gest, resto).get("id", "")) == "journal", "campagne lancée depuis l'écran")
	_check(vue._carte_corps.find_child("Pret_0", true, false) != null and vue._carte_corps.find_child("Agrandir", true, false) != null, "banque et agrandissement dans l'onglet Essor")
	_check(vue.diorama._statique.get_node_or_null("Trophees") != null, "trophées exposés devant l'entrée")
	var teq: Button = vue._carte_corps.find_child("Onglet_personnel", true, false)
	if teq != null:
		teq.pressed.emit()
	_check(vue._carte_corps.find_child("Personne_0", true, false) != null and vue._carte_corps.find_child("Pauses", true, false) != null, "les personnes de l'équipe et les pauses")
	var tav: Button = vue._carte_corps.find_child("Onglet_avis", true, false)
	_check(tav != null, "onglet Avis")
	if tav != null:
		tav.pressed.emit()
	var txt2 := ""
	for c in vue._carte_corps.get_children():
		if c is Label:
			txt2 += (c as Label).text + "\n"
	_check(txt2.contains("Classement") and txt2.contains("★") and txt2.contains("Familles"), "avis, types de clients et classement affichés")
	vue.fermer()
	scene.queue_free()
	await process_frame
