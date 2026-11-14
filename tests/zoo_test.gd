extends SceneTree
## Test du zoo : espèces et modèles, bâtiments, enclos tracés, sols peints et
## bassin, besoins et bien-être, soigneurs et nourriture, barrières et
## évasions, prédateurs, naissances, visiteurs et argent, note, sauvegarde,
## menu (barre du bas, Maj+Z) et outils.
## Usage : godot --headless --path . --script res://tests/zoo_test.gd

var ok := true

## Samedi 18 juillet 2026, 9 h (heure de Suisse romande, UTC+2).
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
	_catalog_tests()
	await _city_tests()
	print("TEST OK" if ok else "TEST ÉCHEC")
	quit(0 if ok else 1)


func _catalog_tests() -> void:
	print("Catalogue :")
	_check(ZooEspeces.ORDRE.size() == ZooEspeces.ESPECES.size(), "%d espèces, toutes dans l'ordre du marché" % ZooEspeces.ORDRE.size())
	for id in ZooEspeces.ORDRE:
		var e: Dictionary = ZooEspeces.ESPECES[id]
		var somme := 0.0
		for s in e.sols:
			somme += float(e.sols[s])
			_check(ZooEspeces.SOLS.has(String(s)), "%s : sol %s connu" % [id, s]) if not ZooEspeces.SOLS.has(String(s)) else null
		_check(absf(somme - 1.0) < 0.02, "%s : sols souhaités (somme %.2f)" % [id, somme])
		for d in e.decors:
			_check(Decors.existe(String(d)) and Decors.mesh(String(d)) != null, "%s : modèle %s" % [id, d])
		_check(ZooEspeces.REGIMES.has(String(e.regime)) and ZooEspeces.UICN.has(String(e.uicn)) and ZooEspeces.CONTINENTS.has(String(e.cont)),
			"%s : régime, statut et continent" % id)
	_check(Decors.de_categorie("zoo").size() >= 29 and Decors.de_categorie("zoo_objets").size() >= 10, "décors du zoo (Blender)")
	var ids := BuildingCatalog.ids_in("zoo")
	_check(ids.size() == ZooTypes.ORDER.size(), "%d bâtiments dans la catégorie Zoo" % ids.size())
	for id in ZooTypes.ORDER:
		var t := BuildingCatalog.get_type(id)
		var m := BuildingCatalog.build_mesh(id)
		_check(m != null and m.get_surface_count() > 0, "modèle de %s" % id)
		var aabb := m.get_aabb()
		_check(aabb.size.x <= float(t.w) + 0.05 and aabb.size.z <= float(t.d) + 0.05, "%s tient dans son emprise" % id)
		for j in Metiers.jobs_for(id):
			_check(Metiers.METIERS.has(String(j[0])), "%s : métier %s connu" % [id, j[0]])
	_check(Icones.has_icon("zoo") and Icones.has_icon("enclos") and Icones.has_icon("bassin"), "icônes du zoo")
	# Barrières.
	_check(bool(ZooEspeces.barriere_ok("zebre", "grillage")[0]), "un grillage retient les zèbres")
	_check(not bool(ZooEspeces.barriere_ok("lion", "grillage")[0]), "mais pas les lions")
	_check(bool(ZooEspeces.barriere_ok("lion", "douve")[0]) and not bool(ZooEspeces.barriere_ok("tigre", "douve")[0]), "douve : bonne pour le lion, pas pour le tigre (il nage)")
	_check(not bool(ZooEspeces.barriere_ok("chimpanze", "grillage_fort")[0]) and bool(ZooEspeces.barriere_ok("chimpanze", "vitre")[0]), "le chimpanzé grimpe au grillage, pas à la vitre")
	_check(not bool(ZooEspeces.barriere_ok("kangourou", "barriere_bois")[0]), "le kangourou saute la barrière en bois")
	var hud := TerreHud.new()
	var trouve := false
	for c in TerreHud.CATEGORIES:
		if String(c.id) == "zoo" and String(c.get("group", "")) == "loisirs":
			trouve = true
	var g := false
	for gr in TerreHud.GROUPS:
		g = g or String(gr.id) == "loisirs"
	_check(trouve and g, "bouton Zoo dans le menu Loisirs de la barre du bas")
	hud.free()


func _city_tests() -> void:
	print("Zoo dans la ville :")
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
	_check(zoo != null and scene.zoo_panel != null and scene.zoo_outils != null, "zoo, menu et outils branchés dans la scène")
	_check(scene.save_sections().has("zoo"), "section « zoo » dans la sauvegarde")
	var pop: Population = scene.population
	for n in [transport.traffic, zoo, pop, scene.parc, scene.dechets, scene.production]:
		n.set_process(false)
	scene.urgences.set_process(false)
	scene.urgences.random_calls = false
	bs.unlimited_money = false
	bs.money = 50_000_000
	var y := world.cell_height(Vector2i(0, 0))
	var road := transport.build_segment("route", Vector3(-500, y, 0), Vector3(500, y, 0))
	_check(road.ok, "route de 1 km")
	var homes: Array[int] = []
	for i in 6:
		var c := Vector2i(-300 + i * 14, 12)
		homes.append(bs.place("maison", c, bs.best_rotation("maison", c)))
	pop._sync_buildings()
	for bid in homes:
		pop.spawn_household(bid, "famille")

	# Entrée et bâtiments.
	var c0 := Vector2i(0, -14)
	var entree := bs.place("entree_zoo", c0, bs.best_rotation("entree_zoo", c0))
	_check(entree > 0, "entrée du zoo posée au bord de la route")
	zoo.ignore_staff = true
	zoo._sync()
	_check(zoo.zoos.has(entree), "l'entrée fonde un zoo")
	_check(zoo.relie(entree), "l'entrée est reliée à la route")
	var poste := bs.place("poste_soigneurs_zoo", Vector2i(-40, -40), 0)
	var cuisine := bs.place("cuisine_zoo", Vector2i(-40, -60), 0)
	var resto := bs.place("restaurant_zoo", Vector2i(40, -40), 0)
	var wc := bs.place("toilettes_zoo", Vector2i(30, -60), 0)
	zoo._sync()
	_check(poste > 0 and cuisine > 0 and resto > 0 and wc > 0, "soigneurs, cuisine, restaurant et toilettes posés")
	_check(zoo.soigneurs(entree) >= 6.0, "%.0f soigneurs au travail" % zoo.soigneurs(entree))

	# Un enclos de savane : 60 × 50 m.
	var caisse0 := bs.money
	var pts := PackedVector2Array([Vector2(-30, -90), Vector2(30, -90), Vector2(30, -140), Vector2(-30, -140)])
	var sav := zoo.ajouter_enclos(pts, "grillage")
	_check(sav > 0 and absf(zoo.aire(sav) - 3000.0) < 1.0, "enclos de 3 000 m²")
	_check(bs.money < caisse0, "la barrière est payée (%d €)" % (caisse0 - bs.money))
	_check(int(zoo.enclos[sav].zoo) == entree, "l'enclos appartient au zoo")
	_check(zoo.enclos_a(Vector2(0, -100)) == sav and zoo.enclos_a(Vector2(0, -10)) == -1, "on sait quel enclos est sous la souris")
	_check(zoo.ajouter_enclos(PackedVector2Array([Vector2(0, 0), Vector2(2, 0), Vector2(2, 2)])) == -1, "pas d'enclos minuscule")
	# Sols : herbe et savane sèche peintes, un bassin.
	var outils: ZooOutils = scene.zoo_outils
	outils.rayon = 8
	outils.sol = "broussailles"
	outils.outil = ZooOutils.Outil.SOL
	for x in [-20, -5, 10, 22]:
		outils._peindre(Vector3(x, y, -100), false)
	outils.outil = ZooOutils.Outil.EAU
	world._stroke_level = NAN
	outils._peindre(Vector3(20, y, -130), false)
	outils.set_inactive()
	zoo._tout_relire()
	var c := zoo.contenu(sav)
	_check(float(c.sols.get("broussailles", 0.0)) > 0.1, "savane sèche peinte : %d %%" % roundi(float(c.sols.get("broussailles", 0.0)) * 100.0))
	_check(float(c.eau) > 0.03, "un bassin : %d %% d'eau" % roundi(float(c.eau) * 100.0))
	# Abri et jouets.
	var abri := bs.place("abri_savane_zoo", Vector2i(-15, -125), 0)
	zoo._sync()
	zoo._tout_relire()
	scene.decors.pose("ratelier_foin", 0.0, -110.0)
	scene.decors.pose("tronc_escalade", 10.0, -120.0)
	zoo._tout_relire()
	c = zoo.contenu(sav)
	_check(abri > 0 and float(c.abri) >= 30.0, "abri de savane dans l'enclos : %d places" % int(c.abri))
	_check(int(c.jouets) >= 2, "%d objets d'enrichissement" % int(c.jouets))
	# Animaux.
	for i in 6:
		zoo.acheter("zebre", sav)
	var zs := zoo.animaux_de(sav)
	_check(zs.size() == 6, "6 zèbres achetés")
	var f := 0
	for aid in zs:
		if bool(zoo.animaux[aid].f):
			f += 1
	_check(f >= 2 and f <= 4, "mâles et femelles mélangés (%d femelles)" % f)
	var b := zoo.besoins("zebre", sav)
	_check(float(b.espace) >= 0.99 and float(b.groupe) >= 0.99 and float(b.abri) >= 0.99, "zèbres : espace, groupe et abri satisfaits")
	_check(float(b.sols) > 0.4, "sols à %d %%" % roundi(float(b.sols) * 100.0))
	# Un seul lion dans un petit enclos à grillage : problèmes en série.
	var cage := zoo.ajouter_enclos(PackedVector2Array([Vector2(60, -90), Vector2(72, -90), Vector2(72, -102), Vector2(60, -102)]), "grillage")
	var lion := zoo.acheter("lion", cage)
	var bl := zoo.besoins("lion", cage)
	var txt := "\n".join(bl.problemes)
	_check(float(bl.espace) < 0.8 and txt.contains("Trop serrés"), "lion à l'étroit")
	_check(txt.contains("seul"), "lion seul")
	_check(txt.contains("évasion"), "lion derrière un grillage : risque d'évasion signalé")

	# Une journée d'été.
	zoo.clock = SAMEDI - 3600.0
	zoo.last_day = int(zoo._now(zoo.clock).day)
	var now := zoo._now(SAMEDI)
	var att := zoo.attendus(entree, now)
	_check(float(att[0]) > 50.0, "touristes attendus un samedi de juillet : %d" % roundi(float(att[0])))
	var caisse1 := bs.money
	for h in 12:
		zoo.clock += ZooSysteme.STEP
		zoo.step()
	var z: Dictionary = zoo.zoos[entree]
	_check(int(z.jour.visiteurs) > 50, "%d visiteurs dans la journée" % int(z.jour.visiteurs))
	_check(float(z.jour.billets) > 1000.0 and float(z.jour.stands) > 0.0, "billets (%d €) et restaurant (%d €)" % [roundi(float(z.jour.billets)), roundi(float(z.jour.stands))])
	_check(float(z.jour.nourriture) > 0.0, "les animaux sont nourris (%d € de nourriture)" % roundi(float(z.jour.nourriture)))
	_check(bs.money > caisse1, "la caisse de la ville gagne de l'argent")
	var faim := 0.0
	for aid in zs:
		faim += float(zoo.animaux[aid].faim)
	_check(faim / zs.size() < 70.0, "les zèbres n'ont pas faim (%d)" % roundi(faim / zs.size()))
	_check(not (z.dernieres as Array).is_empty(), "les visiteurs parlent : « %s »" % String(z.dernieres[0]) if not (z.dernieres as Array).is_empty() else "les visiteurs parlent")
	_check(zoo.bien_moyen(zs) > zoo.bien_moyen([lion]), "zèbres (%d) plus heureux que le lion seul (%d)" % [roundi(zoo.bien_moyen(zs)), roundi(zoo.bien_moyen([lion]))])

	# Évasion du lion : barrière inadaptée.
	zoo.rng.seed = 5
	var evade := false
	for i in 600:
		zoo._evasions()
		if bool(zoo.animaux[lion].evade):
			evade = true
			break
	_check(evade, "le lion finit par s'évader du grillage")
	var hab: Dictionary = pop.persons.values()[0]
	var sat: Array = zoo.satisfaction_of(hab)
	_check(sat.size() == 2, "avis des habitants : %s" % str(sat[1]))
	for i in 12:
		zoo._evasions()
	_check(not bool(zoo.animaux[lion].evade), "les soigneurs le rattrapent")
	zoo.changer_barriere(cage, "grillage_fort")
	_check(String(zoo.enclos[cage].barriere) == "grillage_fort" and bool(ZooEspeces.barriere_ok("lion", "grillage_fort")[0]), "grillage renforcé : le lion reste dedans")

	# Prédateur : le lion avec les zèbres.
	zoo.deplacer(lion, sav)
	var bz := zoo.besoins("zebre", sav)
	_check(float(bz.calme) < 0.5, "les zèbres paniquent avec un lion")
	var avant := zoo.animaux_de(sav).size()
	for i in 60:
		zoo._predateurs()
		if zoo.animaux_de(sav).size() < avant:
			break
	_check(zoo.animaux_de(sav).size() < avant, "le lion mange un zèbre (drame)")
	zoo.deplacer(lion, cage)

	# Naissance : une femelle heureuse et un mâle.
	var mere: int = zoo.animaux_de(sav)[0]
	zoo.animaux[mere].f = true
	zoo.animaux[mere].gest = 1.0
	var n0 := zoo.animaux_de(sav).size()
	zoo._naissances_et_morts()
	_check(zoo.animaux_de(sav).size() > n0, "naissance d'un petit zèbre")
	# Vente et relâcher.
	var caisse2 := bs.money
	zoo.vendre(zoo.animaux_de(sav)[0])
	_check(bs.money > caisse2, "vente d'un animal à un autre zoo")
	var panda_cage := zoo.ajouter_enclos(PackedVector2Array([Vector2(-80, -90), Vector2(-50, -90), Vector2(-50, -120), Vector2(-80, -120)]), "vitre")
	var panda := zoo.acheter("panda", panda_cage)
	zoo.animaux[panda].bien = 80.0
	var pr := float(z.prestige)
	_check(zoo.relacher(panda) and float(zoo.zoos[entree].prestige) > pr, "panda relâché dans la nature : prestige")

	# Note et conseils.
	zoo.new_day(zoo._now(zoo.clock))
	var note := float(zoo.zoos[entree].note)
	_check(note > 0.5, "note du zoo : %.1f / 5" % note)
	var panel: ZooPanel = scene.zoo_panel
	_check(not panel.conseils(entree).is_empty(), "conseils : %s" % String(panel.conseils(entree)[0]))
	for v in ["zoo", "enclos", "terrain", "animaux", "batiments", "visiteurs", "objets"]:
		panel.set_open(true)
		panel.enclos_vu = sav
		panel.show_view(v)
		await process_frame
		_check(panel._body.get_child_count() > 3, "onglet %s rempli (%d éléments)" % [v, panel._body.get_child_count()])
	panel.set_open(false)
	# Outils : tracer un enclos à la souris (coins), le fermer sur le premier point.
	outils.set_outil(ZooOutils.Outil.ENCLOS)
	outils.barriere = "palissade"
	for p in [Vector3(100, y, -90), Vector3(130, y, -90), Vector3(130, y, -120), Vector3(100, y, -120), Vector3(100.5, y, -90.5)]:
		outils._appui = true
		outils._clic(p, false)
	var dernier := zoo.next_enclos - 1
	_check(zoo.enclos.has(dernier) and String(zoo.enclos[dernier].barriere) == "palissade" and absf(zoo.aire(dernier) - 900.0) < 1.0,
		"enclos tracé coin par coin à la souris (palissade, 900 m²)")
	outils.set_inactive()

	# Visuels.
	scene.zoo.visuels._process(0.6)
	await process_frame
	_check(scene.zoo.visuels._barrieres.size() == zoo.enclos.size(), "barrières dessinées (%d)" % scene.zoo.visuels._barrieres.size())
	_check(scene.zoo.visuels._betes.size() == zoo.animaux.size(), "%d animaux dessinés" % scene.zoo.visuels._betes.size())
	_check(scene.zoo.visuels.parcours(entree).size() >= 3, "parcours des visiteurs le long des enclos")

	# Sauvegarde.
	var d := zoo.to_dict()
	var json: Dictionary = JSON.parse_string(JSON.stringify(d))
	var nb_e := zoo.enclos.size()
	var nb_a := zoo.animaux.size()
	zoo.clear()
	zoo.from_dict(json)
	_check(zoo.enclos.size() == nb_e and zoo.animaux.size() == nb_a, "sauvegarde relue : %d enclos, %d animaux" % [nb_e, nb_a])
	_check(String(zoo.enclos[cage].barriere) == "grillage_fort" and zoo.enclos[sav].pts.size() == 4, "barrières et tracés gardés")
	_check(zoo.zoos.has(entree) and float(zoo.zoos[entree].prestige) > 0.0, "zoo et prestige gardés")
	scene.queue_free()
	await process_frame
