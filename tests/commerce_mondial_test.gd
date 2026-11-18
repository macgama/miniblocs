extends SceneTree
## Test du commerce entre villes et pays (menu Commerce, Maj+S) : cours mondiaux
## qui bougent et restent dans leurs bornes, même graine = mêmes cours, crise qui
## monte et redescend, vraies villes partenaires, offres, accords d'exportation
## (prix de l'accord, pénalités), d'importation (prix fixe), entre villes (la ville
## qui achète se fournit chez celle qui vend), proposition à accepter, rupture,
## libre-échange (plus de douane), mission commerciale, sauvegarde, appels du
## multijoueur et panneau.
## Usage : godot --headless --path . --script res://tests/commerce_mondial_test.gd

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


static func _code(c: Vector2) -> String:
	return "fr" if c.x < -1500.0 else "ch"


var rig: Node3D
var world: TerrainWorld


func _aller(x: float, z: float) -> void:
	rig.position = Vector3(x, 0.0, z)
	for i in 600:
		await process_frame
		if i >= 5 and not is_nan(world.cell_height(Vector2i(roundi(x), roundi(z)))) and world.missing_chunk_count() == 0:
			break


## Fait passer n jours au marché.
func _jours(cm: CommerceMondial, prod: Production, n: int) -> void:
	for i in n:
		prod.last_day += 1
		cm._on_day()


func _run() -> void:
	Creations.persist = false
	BatimentsVie.chantiers = false
	GameStart.chosen = true
	GameStart.place_name = "Bâle (test)"
	GameStart.lat = 47.56
	GameStart.lon = 7.59
	ReglagesPartie.prochaine = ReglagesPartie.preset("normal")
	ReglagesPartie.prochaine.deblocage = "tout"  # (ce test ne porte pas sur l'arbre de progression)
	ReglagesPartie.prochaine.fondateurs = 0
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	world = scene.get_node("Terrain")
	rig = scene.get_node("CameraRig")
	var bs: BuildingSystem = scene.get_node("Batiments")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.view_radius_override = 1200.0
	world.set_origin(47.56, 7.59)
	for i in 600:
		await process_frame
		if i >= 60 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	scene.urgences.random_calls = false
	var cm: CommerceMondial = scene.commerce_mondial
	var prod: Production = scene.production
	var p: Pays = scene.pays
	var cmn: Communes = scene.communes
	p.pays_de = _code
	if KitInstallation.instance != null:
		KitInstallation.instance.pays_de = func(vid: int) -> String: return _code(cmn.villages[vid].c)
	ReglagesPartie.actuel.crises_economiques = false

	print("Marché mondial :")
	_check(cm != null and prod.marche == cm and CommerceMondial.instance == cm, "système Commerce branché sur la production")
	if prod.last_day < 0:
		prod.last_day = 20000
	cm.graine = 12345
	cm.jour = -1
	cm._initialiser(prod.last_day)
	_check(cm.jour == prod.last_day and (cm.historique.get("petrole", []) as Array).size() == 30, "30 jours de cours dès le départ")
	_jours(cm, prod, 90)
	var bornes := true
	var bouge := 0
	for g in MarcheTypes.biens():
		var f := cm.facteur(g)
		if f < MarcheTypes.COURS_MIN or f > MarcheTypes.COURS_MAX:
			bornes = false
		if absf(f - 1.0) > 0.03:
			bouge += 1
	_check(bornes, "cours dans leurs bornes après 120 jours")
	_check(bouge > 10, "les cours bougent (%d marchandises à plus de 3 %% de leur prix de référence)" % bouge)
	_check(is_equal_approx(Ressources.cours("petrole"), Ressources.price("petrole") * cm.facteur("petrole")), "Ressources.cours suit le marché")
	_check(is_equal_approx(Ressources.prix_export("acier"), Ressources.cours("acier") * Ressources.EXPORT), "prix à l'export = cours × 0,8")
	var ecart_f := absf(cm.facteur("acier") - 1.0)
	var ecart_i := absf(Ressources.prix_interieur("acier") / Ressources.price("acier") - 1.0)
	_check(absf(ecart_i - ecart_f * 0.5) < 0.001, "prix sur la carte : la moitié de l'écart du cours")
	# Même graine : mêmes cours (tous les jeux d'une carte entre amis voient le même marché).
	var autre := CommerceMondial.new()
	autre.graine = 12345
	for i in 30:
		autre.jour = cm.jour - 120 + i
		autre._marche_jour()
	var h1: Array = cm.historique.petrole
	var h2: Array = autre.historique.petrole
	_check(h1.slice(0, 30) == h2.slice(0, 30), "même graine, mêmes cours")
	autre.free()
	cm._appliquer()
	# Familles : l'acier et l'aluminium bougent ensemble.
	var corr := 0
	var ha: Array = cm.historique.acier
	var hl: Array = cm.historique.aluminium
	for i in range(1, ha.size()):
		if signf(float(ha[i]) - float(ha[i - 1])) == signf(float(hl[i]) - float(hl[i - 1])):
			corr += 1
	_check(corr > ha.size() * 0.55, "acier et aluminium vont souvent dans le même sens (%d / %d jours)" % [corr, ha.size() - 1])

	print("Crise économique :")
	var p0 := cm.facteur_marche("petrole")
	cm.declencher_crise("choc_petrolier", 60)
	_check(cm.nom_crise() == "Choc pétrolier" and cm.intensite_crise() == 0.0, "le choc pétrolier commence doucement")
	_jours(cm, prod, 20)
	_check(cm.intensite_crise() > 0.99 and cm.facteur_crise("petrole") > 2.1, "au plus fort : pétrole ×%.2f" % cm.facteur_crise("petrole"))
	_check(Ressources.cours("petrole") > Ressources.price("petrole") * 1.3, "le cours du pétrole s'envole (%s/t)" % BuildingSystem.format_money(roundi(Ressources.cours("petrole"))))
	_check(is_equal_approx(cm.facteur_crise("cereales"), 1.0), "les céréales ne bougent pas avec le pétrole")
	cm.declencher_crise("krach", 40)
	_jours(cm, prod, 10)
	_check(Ressources.facteur_capacite < 0.8 and Ressources.facteur_export < 0.9, "krach : moins de camions aux frontières, export moins payé")
	_jours(cm, prod, 31)
	_check(cm.crise.is_empty() and cm.crises_passees.size() == 1 and String(cm.crises_passees[0].id) == "krach", "le krach est passé")
	_check(is_equal_approx(Ressources.facteur_capacite, 1.0) and is_equal_approx(Ressources.facteur_export, 1.0), "frontières et prix redeviennent normaux")
	_check(cm.repit == MarcheTypes.REPIT, "%d jours de répit avant une autre crise" % MarcheTypes.REPIT)
	_check(p0 > 0.0, "cours du pétrole hors crise lu")

	print("Villes partenaires :")
	_check(cm.partenaires.size() == MarcheTypes.PARTENAIRES, "%d villes partenaires" % cm.partenaires.size())
	var noms: Array = []
	var pays_vus := {}
	for pid in cm.partenaires:
		noms.append(String(cm.partenaires[pid].nom))
		pays_vus[String(cm.partenaires[pid].pays)] = true
	print("      ", ", ".join(noms))
	_check(pays_vus.size() >= 2, "partenaires dans plusieurs pays autour de Bâle : %s" % ", ".join(pays_vus.keys()))
	_check(cm.offres.size() > 0, "%d offres des partenaires" % cm.offres.size())

	print("Villes du joueur :")
	cmn.nom_en_attente = "Saint-Louis"
	await _aller(-3000, 0)
	var mc1 := bs.place("maison_commune", Vector2i(-3000, 0), 0)
	var v1 := cmn.village_du_batiment(mc1)
	cmn.nom_en_attente = "Bâle"
	await _aller(0, 0)
	var mc2 := bs.place("maison_commune", Vector2i(0, 0), 0)
	var v2 := cmn.village_du_batiment(mc2)
	_check(v1 > 0 and v2 > 0 and p.nation_de(v1) != p.nation_de(v2), "Saint-Louis (France) et Bâle (Suisse)")
	_check(p.payeur_du_batiment(mc1) == v1 and p.payeur_du_batiment(mc2) == v2, "chaque Maison de commune est dans sa ville")

	print("Accord d'exportation :")
	var pid1: int = cm.partenaires.keys()[0]
	var offre := {"id": "test-export", "partenaire": pid1, "sens": "export", "g": "acier", "t": 10.0, "prix": 900.0, "duree": 30, "expire": cm.jour + 5}
	_check(cm.signer(offre, v1) == "" and cm.accords.size() == 1, "Saint-Louis signe : 10 t d'acier par jour à 900 €/t")
	var a: Dictionary = cm.accords.values()[0]
	var ae := cm.accord_export(mc1, "acier")
	_check(not ae.is_empty() and is_equal_approx(float(ae.reste), 10.0), "une entreprise de Saint-Louis doit 10 t aujourd'hui")
	_check(cm.accord_export(mc2, "acier").is_empty(), "rien pour une entreprise de Bâle")
	cm.reserver(int(ae.id), 6.0)
	var gain := cm.vente_export(mc1, "acier", 6.0, int(ae.id))
	_check(is_equal_approx(gain, 5400.0) and is_equal_approx(float(a.livre), 6.0), "6 t livrées payées au prix de l'accord (5 400 €)")
	_check(is_equal_approx(cm.vente_export(mc1, "acier", 1.0), Ressources.prix_export("acier")), "hors accord : au cours du jour")
	_check(is_equal_approx(float(cm.accord_export(mc1, "acier").reste), 4.0), "il reste 4 t à livrer aujourd'hui")
	# Jours de grâce, puis un jour sans rien livrer : pénalité et relation en baisse.
	_jours(cm, prod, MarcheTypes.GRACE + 1)
	var s1 := p.solde(v1)
	var rel := float(cm.partenaires[pid1].relation)
	_jours(cm, prod, 1)
	var pen := 10.0 * 900.0 * MarcheTypes.PENALITE_MANQUE
	_check(p.solde(v1) == s1 - roundi(pen), "rien livré : %s de pénalité pour Saint-Louis" % BuildingSystem.format_money(roundi(pen)))
	_check(float(cm.partenaires[pid1].relation) < rel, "la relation avec %s baisse" % cm.partenaires[pid1].nom)

	print("Accord d'importation :")
	var offre2 := {"id": "test-import", "partenaire": pid1, "sens": "import", "g": "carburant", "t": 5.0, "prix": 800.0, "duree": 60, "expire": cm.jour + 5}
	cm.signer(offre2, v2)
	_check(cm.import_garanti(mc2, "carburant") and not cm.import_garanti(mc1, "carburant"), "Bâle a un import garanti de carburant, pas Saint-Louis")
	var cout := cm.achat_import(mc2, "carburant", 7.0)
	_check(is_equal_approx(cout, 5.0 * 800.0 + 2.0 * Ressources.prix_import("carburant")), "5 t au prix fixe, 2 t au cours")
	_check(not cm.import_garanti(mc2, "carburant"), "quota du jour pris")

	print("Accord entre villes :")
	_check(cm.proposer(v1, v2, "ciment", 8.0, 70.0, 30, v1, true) == "", "Saint-Louis fournit du ciment à Bâle")
	_check(cm.vendeur_pour(mc2, "ciment") == v1 and cm.vendeur_pour(mc1, "ciment") == -1, "Bâle se fournit d'abord à Saint-Louis")
	var v := cm.vente_entre(mc1, mc2, "ciment", 10.0)
	_check(is_equal_approx(v, 8.0 * 70.0 + 2.0 * Ressources.prix_interieur("ciment")), "8 t au prix convenu, le reste au prix du jour")
	_check(cm.vendeur_pour(mc2, "ciment") == -1, "quota du jour livré")
	var nb := cm.accords.size()
	cm.proposer(v2, v1, "bois", 3.0, 60.0, 30, v2, false)
	_check(cm.propositions.size() == 1 and cm.accords.size() == nb, "proposition à un autre maire : en attente")
	_check(cm.accepter(String(cm.propositions[0].id)) == "" and cm.accords.size() == nb + 1 and cm.propositions.is_empty(), "le maire de Saint-Louis accepte")

	print("Rupture :")
	var aid := int(a.id)
	var s2 := p.solde(v1)
	var reste := float(int(a.fin) - cm.jour) * 10.0 * 900.0 * MarcheTypes.PENALITE_RUPTURE
	cm.resilier(aid)
	_check(not cm.accords.has(aid) and String(cm.archives[0].etat) == "rompu", "accord rompu et archivé")
	_check(p.solde(v1) == s2 - roundi(reste), "Saint-Louis paie 10 %% de ce qui restait (%s)" % BuildingSystem.format_money(roundi(reste)))

	print("Libre-échange :")
	var nf := p.nation_de(v1)
	var nc := p.nation_de(v2)
	_check(p.douane_entre(v1, v2) > 0.0, "douane entre la France et la Suisse")
	cm.set_libre_echange(nf, nc, true)
	_check(p.douane_entre(v1, v2) == 0.0 and p.douane_entre(v2, v1) == 0.0, "libre-échange : plus de douane")
	var avant := float(prod.commerce_total().douane)
	prod._commerce(mc1, mc2, 10000.0)
	_check(is_equal_approx(float(prod.commerce_total().douane), avant), "aucune douane sur une vente de Saint-Louis à Bâle")

	print("Mission commerciale :")
	var no := cm.offres.size()
	var s3 := p.solde(v1)
	var r0 := float(cm.partenaires[pid1].relation)
	_check(cm.mission_commerciale(pid1, v1) == "", "mission chez %s" % cm.partenaires[pid1].nom)
	_check(cm.offres.size() == no + 2 and float(cm.partenaires[pid1].relation) > r0 and p.solde(v1) == s3 - ReglagesPartie.prix(MarcheTypes.MISSION_COUT),
		"deux offres de plus, relation en hausse, 25 000 € payés")
	_check(cm.mission_commerciale(pid1, v1) != "", "pas deux missions de suite")

	print("Sauvegarde :")
	var d := cm.to_dict()
	var hist: Array = (cm.historique.petrole as Array).duplicate()
	var nacc := cm.accords.size()
	var j := cm.jour
	cm.from_dict(JSON.parse_string(JSON.stringify(d)))
	_check(cm.jour == j and cm.accords.size() == nacc and cm.partenaires.size() == MarcheTypes.PARTENAIRES, "jour, accords et partenaires retrouvés")
	_check((cm.historique.petrole as Array).size() == hist.size() and absf(float(cm.historique.petrole[-1]) - float(hist[-1])) < 0.0001, "courbes retrouvées")
	_check(cm.libre_echange_entre(nf, nc) and cm.vendeur_pour(mc2, "bois") == -1 and cm.vendeur_pour(mc1, "bois") == v2, "libre-échange et accords entre villes retrouvés")
	_check(scene.save_sections().has("commerce_mondial"), "section « commerce_mondial » dans la sauvegarde")

	print("Appels du multijoueur :")
	_check(Multijoueur.appel_permis("commerce", "signer") and Multijoueur.appel_permis("commerce", "set_libre_echange") and not Multijoueur.appel_permis("commerce", "clear"),
		"signer, libre-échange… permis ; le reste non")
	_check(Multijoueur.ville_de_appel({"sys": "commerce", "ville": v1}) == v1, "l'appel est vérifié pour la ville du maire")
	var r: Variant = Multijoueur.executer_appel(scene, {"sys": "commerce", "f": "set_libre_echange", "args": [nf, nc, false]})
	_check(r == "" and not cm.libre_echange_entre(nf, nc), "l'appel rejoué fait la même chose")

	print("Réglages Admin :")
	var rg := ReglagesPartie.new()
	rg.crises_economiques = false
	rg.volatilite_marche = 2.0
	var rg2 := ReglagesPartie.new()
	rg2.from_dict(rg.to_dict())
	_check(not rg2.crises_economiques and is_equal_approx(rg2.volatilite_marche, 2.0), "crises et agitation du marché gardées")

	print("Panneau Maj+S :")
	var panel: CommercePanel = scene.commerce_panel
	panel.set_open(true)
	for vue in ["marche", "offres", "accords", "villes", "crises", "bilan"]:
		panel.show_view(vue)
		_check(panel._body.get_child_count() > 2, "onglet %s (%d lignes)" % [vue, panel._body.get_child_count()])
	panel.detail = "petrole"
	panel.refresh()
	_check(panel._body.get_child_count() > 6, "courbe du pétrole sur 120 jours")
	panel.set_open(false)

	print("RÉSULTAT : ", "OK" if ok else "ÉCHEC")
	quit(0 if ok else 1)
