extends SceneTree
## Test de plusieurs pays dans une partie solo (« un pays par pays réel ») :
## chaque ville appartient au pays de son lieu, un nouveau pays reçoit son aide
## d'installation et paie le capital de sa première ville, voies hors des villes
## payées par le pays du lieu, impôt national, dotation et douane par pays,
## commerce compté entre villes et entre pays (douane au pays qui importe),
## impôt sur les bénéfices versé à la ville de l'entreprise, sauvegarde,
## ancienne partie à un seul pays, panneau Maj+P.
## Usage : godot --headless --path . --script res://tests/nations_test.gd

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


## Géographie du test : France à l'ouest, Suisse au milieu, Allemagne à l'est.
static func _code(c: Vector2) -> String:
	if c.x < -1500.0:
		return "fr"
	if c.x > 1500.0:
		return "de"
	return "ch"


var rig: Node3D
var world: TerrainWorld


## Amène la caméra au point et attend que le relief y soit chargé.
func _aller(x: float, z: float) -> void:
	rig.position = Vector3(x, 0.0, z)
	for i in 600:
		await process_frame
		if i >= 5 and not is_nan(world.cell_height(Vector2i(roundi(x), roundi(z)))) and world.missing_chunk_count() == 0:
			break


func _run() -> void:
	Creations.persist = false
	BatimentsVie.chantiers = false
	GameStart.chosen = true
	GameStart.place_name = "Bâle (test)"
	ReglagesPartie.prochaine = ReglagesPartie.preset("normal")
	ReglagesPartie.prochaine.deblocage = "tout"  # (ce test ne porte pas sur l'arbre de progression)
	ReglagesPartie.prochaine.fondateurs = 0
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	world = scene.get_node("Terrain")
	rig = scene.get_node("CameraRig")
	var transport: TransportSystem = scene.get_node("Transport")
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
	var cm: Communes = scene.communes
	var p: Pays = scene.pays
	var bud: BudgetCommunal = scene.budget
	var prod: Production = scene.production
	p.pays_de = _code
	if KitInstallation.instance != null:
		KitInstallation.instance.pays_de = func(vid: int) -> String: return _code(cm.villages[vid].c)
	p.foyer = func() -> Vector2: return Vector2(0, 9000)
	var y := world.cell_height(Vector2i(0, 0))
	var prix_mc := ReglagesPartie.prix(BuildingCatalog.cost("maison_commune"))

	print("Première ville, en France :")
	cm.nom_en_attente = "Saint-Louis"
	await _aller(-3000, 0)
	var mc1 := bs.place("maison_commune", Vector2i(-3000, 0), 0)
	var v1 := cm.village_du_batiment(mc1)
	_check(v1 > 0 and p.nation_de(v1) == Pays.PAYS and p.code_de(Pays.PAYS) == "fr", "Saint-Louis est en France (premier pays)")
	_check(not p.plusieurs_nations(), "un seul pays pour l'instant")

	print("Deuxième ville, en Suisse :")
	cm.nom_en_attente = "Bâle"
	var fr_avant := p.solde(Pays.PAYS)
	await _aller(0, 0)
	var mc2 := bs.place("maison_commune", Vector2i(0, 0), 0)
	var v2 := cm.village_du_batiment(mc2)
	var ch := p.nation_de(v2)
	_check(v2 > 0 and Pays.est_nation(ch) and ch >= Pays.NATION_BASE and p.code_de(ch) == "ch", "Bâle fonde un deuxième pays : %s" % p.nom_nation(ch))
	_check(p.plusieurs_nations() and p.cles_nations().size() == 2, "deux pays dirigés")
	_check(p.solde(Pays.PAYS) == fr_avant, "la France ne paie rien pour la ville suisse")
	var aide := ReglagesPartie.prix(Pays.DEPART_NATION)
	_check(p.solde(ch) + p.solde(v2) == aide - prix_mc, "aide d'installation (%s) = Maison de commune + capital + reste" % BuildingSystem.format_money(aide))
	_check(p.solde(v2) == roundi((aide - prix_mc) * Pays.PART_PREMIERE), "première ville suisse : 60 %% de la caisse suisse (%s)" % BuildingSystem.format_money(p.solde(v2)))
	_check(p.nom_nation(ch) != "" and p.nom_nation(ch) != p.nom_nation(Pays.PAYS), "noms des pays : %s et %s" % [p.nom_nation(Pays.PAYS), p.nom_nation(ch)])

	print("Troisième pays, puis une deuxième ville française :")
	cm.nom_en_attente = "Lörrach"
	await _aller(3500, 0)
	var mc3 := bs.place("maison_commune", Vector2i(3500, 0), 0)
	var v3 := cm.village_du_batiment(mc3)
	var de := p.nation_de(v3)
	_check(v3 > 0 and de != ch and de != Pays.PAYS and p.code_de(de) == "de", "Lörrach : troisième pays (%s)" % p.nom_nation(de))
	cm.nom_en_attente = "Huningue"
	fr_avant = p.solde(Pays.PAYS)
	await _aller(-6000, 0)
	var mc4 := bs.place("maison_commune", Vector2i(-6000, 0), 0)
	var v4 := cm.village_du_batiment(mc4)
	_check(v4 > 0 and p.nation_de(v4) == Pays.PAYS, "Huningue rejoint la France")
	_check(fr_avant - p.solde(Pays.PAYS) == prix_mc + p.solde(v4) and p.solde(v4) == mini(ReglagesPartie.prix(Pays.CAPITAL_VILLE), fr_avant - prix_mc),
		"la France paie la Maison de commune et le capital de Huningue")
	_check(p.villes_de(Pays.PAYS) == [v1, v4] and p.villes_de(ch) == [v2] and p.villes_de(de) == [v3], "villes rangées par pays")
	_check(p.cles().size() == 7 and p.cles()[-1] == Pays.PAYS, "caisses : 4 villes et 3 pays")

	print("Hors des villes, le pays du lieu paie :")
	_check(p.payeur_au_point(2000, 2500) == de and p.payeur_au_point(-2000, 2500) == Pays.PAYS and p.payeur_au_point(0, 2500) == ch, "Allemagne, France, Suisse selon le lieu")
	p.choisir(v1)
	await _aller(2500, 1500)
	var r: Dictionary = transport.build_segment("route", Vector3(2200, y, 1500), Vector3(2800, y, 1500))
	var eid := -1
	for e in transport.network.edges:
		if transport.network.point_at(e, float(transport.network.edges[e].len) * 0.5).x > 2000.0:
			eid = e
	_check(bool(r.get("ok", false)) and eid >= 0 and p.payeur_de_voie(eid) == de and p.payeur_de_cle("voie:%d" % eid) == de,
		"route en Allemagne : son chantier et son entretien sont à l'Allemagne")

	print("Réglages par pays :")
	p.set_taux_national(0.2, ch)
	p.set_dotation(0.5, ch)
	p.set_douane(0.12, ch)
	_check(is_equal_approx(p.taux_de(ch), 0.2) and is_equal_approx(p.taux_de(Pays.PAYS), Pays.TAUX_NATIONAL), "impôt national propre à la Suisse")
	_check(is_equal_approx(p.dotation_de(ch), 0.5) and is_equal_approx(p.dotation_de(de), 1.0), "dotation propre à chaque pays")
	_check(is_equal_approx(p.douane_entre(v1, v2), 0.12) and is_equal_approx(p.douane_entre(v2, v1), Pays.TAUX_DOUANE) and p.douane_entre(v1, v4) == 0.0,
		"douane payée au pays qui importe, aucune dans un même pays")
	var bch := bud.bilan_mensuel(ch)
	_check(bch.has("solde"), "bilan mensuel de la Suisse")
	var nb_villes := 0
	for nk in p.cles_nations():
		nb_villes += p.villes_de(int(nk)).size()
	_check(nb_villes == cm.villages.size(), "chaque ville a un pays")

	print("Commerce entre villes et entre pays :")
	var ch_avant := p.solde(ch)
	prod._commerce(mc1, mc2, 10000.0)  # Saint-Louis vend à Bâle : la Suisse importe
	prod._commerce(mc1, mc4, 4000.0)   # Saint-Louis vend à Huningue : même pays
	var tot := prod.commerce_total()
	_check(is_equal_approx(float(tot.villes), 14000.0) and is_equal_approx(float(tot.pays), 10000.0), "14 000 € entre villes, dont 10 000 € entre pays")
	_check(is_equal_approx(float(tot.douane), 1200.0), "douane suisse : 12 %% de 10 000 € = 1 200 €")
	var cv := prod.commerce_ville(v1)
	_check(is_equal_approx(float(cv.ventes), 14000.0) and is_equal_approx(float(prod.commerce_ville(v2).achats), 10000.0), "ventes et achats par ville")
	var cn := prod.commerce_nation(ch)
	_check(is_equal_approx(float(cn.achats), 10000.0) and is_equal_approx(float(prod.commerce_nation(Pays.PAYS).ventes), 10000.0), "exportations et importations par pays")
	prod.new_day()
	_check(p.solde(ch) == ch_avant + 1200, "la douane arrive dans la caisse suisse le soir")

	print("Une journée de budget pour tous :")
	bud.pay_day()
	_check(cm.villages.size() == 4 and p.cles_nations().size() == 3, "budget du jour passé pour 4 villes et 3 pays")

	print("Sauvegarde :")
	var d := p.to_dict()
	var bd := bud.to_dict()
	var pd := prod.to_dict()
	var soldes := {}
	for k in p.cles():
		soldes[k] = p.solde(k)
	bud.from_dict(bd)
	p.from_dict(d)
	prod.from_dict(pd)
	var memes := true
	for k in soldes:
		if p.solde(k) != int(soldes[k]):
			memes = false
	_check(memes, "toutes les caisses retrouvées (villes et pays)")
	_check(p.nation_de(v2) == ch and p.nation_de(v3) == de and p.code_de(de) == "de" and is_equal_approx(p.douane_de(ch), 0.12), "pays et réglages retrouvés")
	_check(is_equal_approx(float(prod.commerce_total().pays), 10000.0), "comptes du commerce retrouvés")

	print("Ancienne partie (un seul pays) :")
	var d1 := d.duplicate(true)
	d1.erase("nations")
	d1.erase("villes_pays")
	var cs1: Dictionary = d1.comptes
	for ks in cs1.keys():
		if Pays.est_nation(int(ks)) and int(ks) != Pays.PAYS:
			cs1.erase(ks)
	p.from_dict(d1)
	_check(not p.plusieurs_nations() and p.nation_de(v2) == Pays.PAYS, "toutes les villes dans le premier pays")
	p.from_dict(d)
	_check(p.plusieurs_nations(), "retour aux trois pays")

	print("Panneau Maj+P :")
	var panel: PaysPanel = scene.pays_panel
	panel.set_open(true)
	panel.show_view("villes")
	_check(panel._body.get_child_count() > 10, "onglet Villes rangé par pays")
	_check(panel._title.text.begins_with("Tes pays"), "titre : %s" % panel._title.text)
	panel._nation = ch
	panel.show_view("pays")
	_check(panel._body.get_child_count() > 8, "onglet Pays : la Suisse avec sa douane")
	panel.set_open(false)

	print("RÉSULTAT : ", "OK" if ok else "ÉCHEC")
	quit(0 if ok else 1)
