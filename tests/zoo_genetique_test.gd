extends SceneTree
## Test de la génétique et des échanges du zoo : parenté et consanguinité, gènes
## hérités et leurs effets, contraception, diversité, réseau d'élevage (offres et
## demandes), échanges entre zoos de la carte (autres joueurs), arrivées des
## expéditions, remise en liberté suivie, sauvegarde, onglet Échanges.
## Usage : godot --headless --path . --script res://tests/zoo_genetique_test.gd

var ok := true

const SAMEDI := 1_784_358_000.0


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
	_parente_tests()
	await _zoo_tests()
	print("TEST OK" if ok else "TEST ÉCHEC")
	quit(0 if ok else 1)


func _parente_tests() -> void:
	print("Parenté :")
	# 1, 2 : fondateurs ; 3, 4 : leurs petits ; 5 : petit de 3 et 4 ; 6 : petit de 1 et d'un autre fondateur 7.
	var g := {
		1: {"pere": -1, "mere": -1, "F": 0.0, "naiss": 0.0}, 2: {"pere": -1, "mere": -1, "F": 0.0, "naiss": 0.0},
		7: {"pere": -1, "mere": -1, "F": 0.0, "naiss": 0.0},
		3: {"pere": 1, "mere": 2, "F": 0.0, "naiss": 1000.0}, 4: {"pere": 1, "mere": 2, "F": 0.0, "naiss": 1000.0},
		6: {"pere": 1, "mere": 7, "F": 0.0, "naiss": 1100.0},
	}
	_check(is_equal_approx(ZooGenetique.parente(g, 1, 2), 0.0), "deux fondateurs : aucun lien")
	_check(is_equal_approx(ZooGenetique.parente(g, 1, 1), 0.5), "parenté avec soi-même : 1/2")
	_check(is_equal_approx(ZooGenetique.parente(g, 1, 3), 0.25), "père et petit : 1/4")
	_check(is_equal_approx(ZooGenetique.parente(g, 3, 4), 0.25), "frère et sœur : 1/4")
	_check(is_equal_approx(ZooGenetique.parente(g, 3, 6), 0.125), "demi-frère et demi-sœur : 1/8")
	g[5] = {"pere": 3, "mere": 4, "F": ZooGenetique.parente(g, 3, 4), "naiss": 2000.0}
	_check(is_equal_approx(float(g[5].F), 0.25), "petit d'un frère et d'une sœur : 25 % de consanguinité")
	_check(is_equal_approx(ZooGenetique.parente(g, 5, 5), 0.625), "un animal consanguin est plus « parent » de lui-même")
	_check(is_equal_approx(ZooGenetique.diversite(g, [1, 2]), 0.75), "2 fondateurs : 75 % de diversité")
	_check(ZooGenetique.diversite(g, [1, 2, 7]) > ZooGenetique.diversite(g, [1, 3, 4]), "des fondateurs valent mieux qu'une famille")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var a := ZooGenetique.fondateur(rng)
	var b := ZooGenetique.fondateur(rng)
	var c := ZooGenetique.heritage(rng, a, b)
	var tous := true
	for k in ZooGenetique.GENES:
		tous = tous and a.has(k) and c.has(k) and absf(float(c[k])) <= 1.0
	_check(tous, "quatre gènes (taille, santé, fertilité, longévité) hérités des deux parents")
	_check(ZooGenetique.effectif({"genes": {"sante": 0.2}, "consang": 0.25}, "sante") < 0.0, "la consanguinité affaiblit la santé")


func _zoo_tests() -> void:
	print("Zoo :")
	Creations.persist = false
	BatimentsVie.chantiers = false
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 40
	world.view_radius_override = 700.0
	world.set_origin(46.2, 6.9)
	for i in 3000:
		await process_frame
		if i >= 120 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	var zoo: ZooSysteme = scene.zoo
	for n in [transport.traffic, zoo, scene.population, scene.parc, scene.dechets, scene.production]:
		n.set_process(false)
	scene.urgences.set_process(false)
	scene.urgences.random_calls = false
	bs.unlimited_money = false
	bs.money = 50_000_000
	var y := world.cell_height(Vector2i(0, 0))
	_check(transport.build_segment("route", Vector3(-500, y, 0), Vector3(500, y, 0)).ok, "route")
	var entree := bs.place("entree_zoo", Vector2i(0, -14), bs.best_rotation("entree_zoo", Vector2i(0, -14)))
	var entree2 := bs.place("entree_zoo", Vector2i(460, -14), bs.best_rotation("entree_zoo", Vector2i(460, -14)))
	zoo.ignore_staff = true
	zoo._sync()
	_check(zoo.zoos.has(entree) and zoo.zoos.has(entree2), "deux zoos sur la carte")
	zoo.clock = SAMEDI
	zoo.last_day = int(zoo._now(zoo.clock).day)
	var sav := zoo.ajouter_enclos(PackedVector2Array([Vector2(-30, -90), Vector2(30, -90), Vector2(30, -140), Vector2(-30, -140)]), "grillage")
	var sav2 := zoo.ajouter_enclos(PackedVector2Array([Vector2(440, -90), Vector2(490, -90), Vector2(490, -140), Vector2(440, -140)]), "grillage")
	var cage := zoo.ajouter_enclos(PackedVector2Array([Vector2(60, -90), Vector2(100, -90), Vector2(100, -130), Vector2(60, -130)]), "vitre")
	_check(int(zoo.enclos[sav].zoo) == entree and int(zoo.enclos[sav2].zoo) == entree2, "un enclos dans chaque zoo")

	# Gènes et naissances.
	var pere := zoo.acheter("zebre", sav, 0)
	var mere := zoo.acheter("zebre", sav, 1)
	_check(zoo.animaux[pere].genes.size() == 4 and int(zoo.animaux[pere].pere) == -1, "un animal acheté : fondateur, quatre gènes")
	_check(zoo.genealogie.has(pere) and zoo.genealogie.has(mere), "inscrits dans la généalogie")
	zoo.animaux[mere].gest = 1.0
	zoo.animaux[mere].gest_pere = pere
	var avant := zoo.animaux.keys()
	zoo._naissances_et_morts()
	var petits: Array = []
	for aid in zoo.animaux:
		if not aid in avant:
			petits.append(aid)
	_check(not petits.is_empty(), "naissance")
	var p0: Dictionary = zoo.animaux[petits[0]]
	_check(int(p0.pere) == pere and int(p0.mere) == mere and float(p0.consang) == 0.0, "le petit connaît ses parents, sans consanguinité")
	var g_moy := (float(zoo.animaux[pere].genes.sante) + float(zoo.animaux[mere].genes.sante)) * 0.5
	_check(absf(float(p0.genes.sante) - g_moy) < 1.2, "gène de santé hérité (%.2f, parents %.2f)" % [float(p0.genes.sante), g_moy])
	# La fille grandit et se retrouve avec son père : alerte, puis petit consanguin.
	var fille := int(petits[0])
	zoo.animaux[fille].f = true
	zoo.animaux[fille].naiss = zoo.jour_courant() - 4.0 * 365.25
	var risque := zoo.couples_a_risque(sav)
	_check(risque.size() >= 1 and is_equal_approx(float(risque[0][2]), 0.25), "père et fille dans l'enclos : couple à risque signalé")
	var panel: ZooPanel = scene.zoo_panel
	var cs := "\n".join(panel.conseils(entree))
	_check(cs.contains("proches parents"), "conseil : contraception ou partenaire venu d'ailleurs")
	var div0 := zoo.diversite(entree, "zebre")
	zoo.animaux[fille].gest = 1.0
	zoo.animaux[fille].gest_pere = pere
	avant = zoo.animaux.keys()
	zoo._naissances_et_morts()
	var consanguin := -1
	for aid in zoo.animaux:
		if not aid in avant:
			consanguin = int(aid)
	_check(consanguin > 0 and is_equal_approx(float(zoo.animaux[consanguin].consang), 0.25), "petit du père et de sa fille : 25 % de consanguinité")
	_check(zoo.gene(consanguin, "fertilite") < float(zoo.animaux[consanguin].genes.fertilite), "sa fertilité effective baisse")
	_check(zoo.diversite(entree, "zebre") < div0 + 0.05, "la diversité du groupe n'augmente pas (%s)" % ZooGenetique.pourcent(zoo.diversite(entree, "zebre")))
	# Longévité.
	var a: Dictionary = zoo.animaux[pere]
	a.genes.longevite = 1.0
	var vie_longue := zoo.vie_de(a)
	a.genes.longevite = -1.0
	_check(vie_longue > zoo.vie_de(a) * 1.2, "un bon gène de longévité fait vivre plus longtemps (%.0f ans contre %.0f)" % [vie_longue, zoo.vie_de(a)])
	a.genes.longevite = 0.0
	# Contraception.
	zoo.set_contraception(mere, true)
	zoo.set_contraception(fille, true)
	zoo.animaux[mere].gest = -1.0
	zoo.animaux[fille].gest = -1.0
	var grossesse := false
	for i in 1500:
		for aid in zoo.animaux:
			zoo.animaux[aid].bien = 90.0
			zoo.animaux[aid].sante = 90.0
		zoo._naissances_et_morts()
		grossesse = grossesse or float(zoo.animaux[mere].gest) >= 0.0 or float(zoo.animaux[fille].gest) >= 0.0
	_check(not grossesse, "contraception : pas de petits pendant 4 ans")
	zoo.set_contraception(mere, false)
	for i in 1500:
		zoo.animaux[mere].bien = 90.0
		zoo._naissances_et_morts()
		if float(zoo.animaux[mere].gest) >= 0.0:
			grossesse = true
			break
	_check(grossesse and int(zoo.animaux[mere].gest_pere) >= 0, "sans contraception, la femelle attend un petit (et on sait de qui)")

	# Réseau d'élevage.
	var vente := -1
	var demande := -1
	for i in 80:
		var oid := zoo.nouvelle_offre_reseau()
		var o: Dictionary = zoo.offres[oid]
		if String(o.sorte) == "vente" and String(o.esp) == "zebre" and vente < 0:
			vente = oid
		elif String(o.sorte) == "demande" and String(o.esp) == "zebre" and int(o.f) != 1 and demande < 0:
			demande = oid
		elif oid != vente and oid != demande:
			zoo.offres.erase(oid)
	_check(vente > 0 and demande > 0, "le réseau propose et demande des zèbres")
	var argent := bs.money
	var nb := zoo.animaux.size()
	_check(zoo.acheter_offre(vente, sav) == "" and zoo.animaux.size() == nb + 1 and bs.money < argent, "zèbre acheté au réseau")
	var neuf := zoo.next_animal - 1
	_check(String(zoo.animaux[neuf].origine) == "reseau" and zoo.genealogie.has(neuf), "il vient du réseau, inscrit dans la généalogie")
	argent = bs.money
	var pr := float(zoo.zoos[entree].prestige)
	_check(zoo.repondre_demande(demande, pere) == "" and not zoo.animaux.has(pere), "le père part pour le zoo partenaire")
	_check(bs.money > argent and float(zoo.zoos[entree].prestige) > pr, "argent et prestige")
	_check(zoo.genealogie.has(pere) and not zoo.reseau.is_empty(), "sa trace est gardée (ses petits peuvent revenir)")
	var piege := false
	for i in 400:
		var oid := zoo.nouvelle_offre_reseau()
		var o: Dictionary = zoo.offres[oid]
		if String(o.sorte) == "vente" and (int(o.animal.pere) == pere or int(o.animal.mere) == pere):
			piege = zoo.parente_offre(oid, entree) > 0.03
			break
		zoo.offres.erase(oid)
	_check(piege, "le réseau propose un jour un petit du père : la parenté avec nos zèbres est signalée")

	# Échanges entre zoos de la carte (carte entre amis : l'autre maire accepte).
	zoo.echanges_directs_force = 0
	var z_ech := zoo.acheter("zebre", sav, 0)
	_check(zoo.proposer_echange(z_ech, entree2, 3000.0) == "", "zèbre proposé à l'autre zoo")
	var oj := -1
	for oid in zoo.offres_pour(entree2):
		if String(zoo.offres[oid].sorte) == "joueur":
			oj = oid
	_check(oj > 0 and int(zoo.animaux[z_ech].enclos) == sav, "proposition en attente, l'animal reste chez nous")
	_check(zoo.proposer_echange(z_ech, entree2) != "", "pas deux propositions pour le même animal")
	_check(zoo.acheter_offre(oj, cage) != "", "refusé dans un enclos d'un autre zoo que celui choisi")
	_check(zoo.acheter_offre(oj, sav2) == "" and int(zoo.animaux[z_ech].enclos) == sav2 and not zoo.offres.has(oj),
		"l'autre zoo accepte : le zèbre déménage")
	_check(int(zoo.zoos[entree2].jour.echanges) >= 1, "échange compté")
	zoo.echanges_directs_force = 1
	_check(zoo.proposer_echange(z_ech, entree) == "" and int(zoo.enclos[int(zoo.animaux[z_ech].enclos)].zoo) == entree,
		"en solo, tous les zoos sont à vous : retour immédiat")
	zoo.echanges_directs_force = -1
	for f in ["acheter_offre", "repondre_demande", "refuser_offre", "proposer_echange", "placer_arrivee", "ceder_arrivee", "set_contraception"]:
		_check(Multijoueur.appel_permis("zoo", f), "carte entre amis : %s passe par le serveur" % f)

	# Arrivées (expéditions).
	var rid := zoo.accueillir("tigre", entree, "expedition", {"nom": "Shere"})
	_check(rid > 0 and zoo.arrivees_de(entree).has(rid), "un tigre rapporté par une expédition attend un enclos")
	_check("\n".join(panel.conseils(entree)).contains("attend"), "conseil : un animal attend")
	_check(zoo.placer_arrivee(rid, cage) == "" and zoo.arrivees.is_empty(), "placé dans un enclos")
	var tigre := zoo.next_animal - 1
	_check(String(zoo.animaux[tigre].nom) == "Shere" and String(zoo.animaux[tigre].origine) == "expedition", "nom et origine gardés")
	var direct := zoo.accueillir("tigre", entree, "sauvage", {"enclos": cage, "f": true})
	_check(direct < 0 and zoo.animaux.has(-direct) and bool(zoo.animaux[-direct].f), "accueilli directement dans un enclos")
	_check(zoo.accueillir("licorne") == 0, "espèce inconnue refusée")
	var rid2 := zoo.accueillir("girafe", entree)
	argent = bs.money
	_check(zoo.ceder_arrivee(rid2) == "" and bs.money > argent, "une arrivée cédée au réseau")

	# Remise en liberté.
	zoo.animaux[tigre].bien = 85.0
	zoo.animaux[tigre].sante = 90.0
	pr = float(zoo.zoos[entree].prestige)
	var ch := zoo.chance_relache(tigre)
	_check(zoo.relacher(tigre) and float(zoo.zoos[entree].prestige) > pr, "tigre relâché : prestige (chance de s'adapter %d %%)" % roundi(ch * 100.0))
	_check(zoo.relaches.size() == 1 and String(zoo.relaches[0].statut) == "suivi", "suivi par collier émetteur")
	zoo.animaux[consanguin].tare = "hanches faibles"
	_check(zoo.raison_pas_relacher(consanguin) != "", "pas de remise en liberté d'un zèbre (non menacé) ou porteur d'une tare")
	zoo.relaches[0].fin = zoo.jour_courant() - 1.0
	zoo.relaches[0].chance = 1.0
	pr = float(zoo.zoos[entree].prestige)
	zoo._suivre_relaches()
	_check(String(zoo.relaches[0].statut) == "reussi" and float(zoo.zoos[entree].prestige) > pr, "il s'adapte à la vie sauvage : prestige et dons")

	# Onglet Échanges.
	zoo.nouvelle_offre_reseau()
	zoo.accueillir("lion", entree)
	panel.set_open(true)
	panel.choisi = entree
	panel.echange_animal = z_ech
	panel.show_view("echanges")
	await process_frame
	_check(panel._body.get_child_count() > 8, "onglet Échanges rempli (%d éléments)" % panel._body.get_child_count())
	_check(panel.fiche_genetique(consanguin).contains("Consanguinité : 25 %"), "fiche génétique d'un animal (infobulle)")
	panel.enclos_vu = sav
	panel.show_view("enclos")
	await process_frame
	panel.set_open(false)

	# Sauvegarde.
	var k_avant := ZooGenetique.parente(zoo.genealogie, consanguin, mere)
	var nb_off := zoo.offres.size()
	var d: Dictionary = JSON.parse_string(JSON.stringify(zoo.to_dict()))
	zoo.clear()
	zoo.from_dict(d)
	_check(is_equal_approx(ZooGenetique.parente(zoo.genealogie, consanguin, mere), k_avant), "généalogie relue : même parenté")
	_check(is_equal_approx(float(zoo.animaux[consanguin].consang), 0.25) and String(zoo.animaux[consanguin].tare) != "", "consanguinité et tare gardées")
	_check(zoo.offres.size() == nb_off and zoo.arrivees.size() == 1 and zoo.relaches.size() == 1, "offres, arrivées et remises en liberté gardées")
	# Ancienne sauvegarde (sans génétique).
	var vieux := d.duplicate(true)
	vieux.erase("genealogie")
	for k in vieux.animaux:
		for c in ["genes", "consang", "pere", "mere", "tare", "origine", "contra"]:
			vieux.animaux[k].erase(c)
	zoo.from_dict(vieux)
	var tous := true
	for aid in zoo.animaux:
		tous = tous and zoo.animaux[aid].genes.size() == 4 and zoo.genealogie.has(aid)
	_check(tous, "ancienne sauvegarde : chaque animal reçoit des gènes (fondateur)")
	zoo._elaguer_genealogie()
	_check(zoo.genealogie.size() >= zoo.animaux.size(), "généalogie élaguée sans perdre les vivants")
	scene.queue_free()
	await process_frame
