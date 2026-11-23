extends SceneTree
## Test du mode gestion du parc de loisirs : zones, objets et modèles complets,
## bouton « Gérer le parc » du panneau du parc, caisse des travaux remplie par
## une part du bénéfice, effets des aménagements sur le vrai parc (visiteurs
## attirés, manèges plus fiables, propreté, humeur, note), billet, demandes,
## événements, gestion automatique, sauvegarde, et maquette avec les vraies
## attractions en miniature.
## Usage : godot --headless --path . --script res://tests/gestion_parc_test.gd

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
	_types_tests()
	await _city_tests()
	print("TEST OK" if ok else "TEST ÉCHEC")
	quit(0 if ok else 1)


func _types_tests() -> void:
	print("Genre parc :")
	_check(GestionTypes.genre_de("entree_parc") == "parc", "l'entrée du parc se gère")
	_check(GestionTypes.genre_de("carrousel_parc") == "", "un manège seul ne se gère pas")
	_check(GestionTypes.genre_de("hopital") == "hopital" and GestionTypes.genre_de("hotel_3") == "hotel", "hôpital et hôtel inchangés")
	var g := "parc"
	var gd := GestionTypes.genre(g)
	_check(String(gd.titre).begins_with("Gérer le parc") and Icones.has_icon(String(gd.icone)), "titre et icône")
	_check(String(gd.source) == "parc", "chiffres du vrai parc")
	_check(GestionTypes.ordre(g).size() == GestionTypes.pieces(g).size() and GestionTypes.ordre(g).size() >= 12, "%d zones, toutes dans l'ordre" % GestionTypes.ordre(g).size())
	_check(GestionTypes.pieces(g).has(String(gd.accueil)), "la zone d'accueil existe")
	for pid in GestionTypes.ordre(g):
		var p := GestionTypes.piece(g, String(pid))
		_check(p.has("rect") and p.has("decor") and p.has("effets") and int(p.max) >= 2, "zone %s complète" % pid)
		for m in p.get("metiers", []):
			_check(Metiers.METIERS.has(String(m)), "%s : métier %s connu" % [pid, m])
		if p.has("via"):
			_check(GestionTypes.pieces(g).has(String(p.via)), "%s : on y passe par %s" % [pid, p.via])
	for z in gd.miniatures:
		_check(GestionTypes.pieces(g).has(String(z)), "miniatures dans la zone %s" % z)
	for d in gd.demandes:
		_check(GestionTypes.pieces(g).has(String(d.piece)), "demande « %s » dans une zone connue" % d.texte)
	for a in gd.activites:
		_check(GestionTypes.pieces(g).has(String(a[0])), "activité %s" % a[0])
	var nb := 0
	var modeles_ok := true
	var poses_ok := true
	for pid in GestionTypes.ordre(g):
		var r: Array = GestionTypes.piece(g, String(pid)).rect
		for oid in GestionTypes.objets(g, String(pid)):
			var o := GestionTypes.objet(g, String(pid), String(oid))
			nb += 1
			if not (o.has("nom") and o.has("prix") and o.has("effets")):
				push_error("objet incomplet %s/%s" % [pid, oid])
				modeles_ok = false
			var m := String(o.get("modele", ""))
			if m != "":
				var k := LpKit.new(1)
				GestionModeles.dessiner(k, m, Vector3.ZERO, 0.0)
				if k.triangle_count() <= 0:
					modeles_ok = false
					push_error("modèle vide : " + m)
			for ps in o.get("poses", []):
				if float(ps[0]) < -0.01 or float(ps[0]) > float(r[2]) + 0.01 or float(ps[1]) < -0.01 or float(ps[1]) > float(r[3]) + 0.01:
					poses_ok = false
					push_error("%s/%s posé hors de la zone : %s" % [pid, oid, ps])
	_check(nb >= 60, "%d objets à acheter" % nb)
	_check(modeles_ok, "chaque objet a son modèle 3D")
	_check(poses_ok, "chaque objet est posé dans sa zone")
	var pcs := GestionTypes.ordre(g)
	var chevauche := ""
	for i in pcs.size():
		for j in range(i + 1, pcs.size()):
			var a: Array = GestionTypes.piece(g, String(pcs[i])).rect
			var b: Array = GestionTypes.piece(g, String(pcs[j])).rect
			if float(a[0]) < float(b[0]) + float(b[2]) - 0.01 and float(b[0]) < float(a[0]) + float(a[2]) - 0.01 and float(a[1]) < float(b[1]) + float(b[3]) - 0.01 and float(b[1]) < float(a[1]) + float(a[3]) - 0.01:
				chevauche = "%s / %s" % [pcs[i], pcs[j]]
	_check(chevauche == "", "les zones ne se chevauchent pas %s" % chevauche)
	_check(GestionVue.zone_attraction("montagnes_russes") == "sensations", "montagnes russes → sensations fortes")
	_check(GestionVue.zone_attraction("carrousel_parc") in ["manege", "enfants"], "carrousel → manèges")


func _place(bs: BuildingSystem, id: String, x: int, z: int, r := 0) -> int:
	var bid := bs.place(id, Vector2i(x, z), r)
	if bid < 0:
		push_error("pose impossible : %s en %d, %d (%s)" % [id, x, z, bs.check_place(id, Vector2i(x, z), r).reason])
	return bid


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
	world.view_radius_override = 900.0
	world.set_origin(46.2, 6.9)
	for i in 3000:
		await process_frame
		if i >= 120 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	var gest: Gestion = scene.gestion
	var vue: GestionVue = scene.gestion_vue
	var parc: ParcLoisirs = scene.parc
	var pop: Population = scene.population
	ReglagesPartie.actuel.recherche_parc = false
	ReglagesPartie.actuel.deblocage = "tout"
	for nd in [transport.traffic, scene.tourisme, pop, parc, scene.zoo, scene.musee, scene.spectacles, scene.dechets, scene.production]:
		nd.set_process(false)
	scene.urgences.set_process(false)
	scene.urgences.random_calls = false
	bs.unlimited_money = false
	bs.money = 50_000_000
	var y := world.cell_height(Vector2i(0, 0))
	_check(transport.build_segment("route", Vector3(-500, y, 0), Vector3(500, y, 0)).ok, "route")
	var c0 := Vector2i(0, -14)
	var entree := bs.place("entree_parc", c0, bs.best_rotation("entree_parc", c0))
	_check(entree > 0, "entrée du parc posée")
	parc.ignore_staff = true
	parc._sync()
	var car := _place(bs, "carrousel_parc", -30, -50)
	var roue := _place(bs, "grande_roue_parc", 20, -48)
	var coaster := _place(bs, "montagnes_russes", 0, -110)
	var bateau := _place(bs, "bateau_pirate", -50, -85)
	var frites := _place(bs, "friterie_parc", -8, -40)
	var wc := _place(bs, "toilettes_parc", 40, -75)
	parc._sync()
	_check(car > 0 and roue > 0 and coaster > 0 and bateau > 0 and frites > 0 and wc > 0, "attractions posées")
	_check(parc.attractions_ok(entree).size() == 4, "4 attractions dans le parc")
	_check(gest.batiments_parc(entree).size() >= 6, "la gestion voit l'entrée et les %d bâtiments du parc" % gest.batiments_parc(entree).size())

	print("Panneau du parc :")
	var pp = scene.parc_panel
	pp.set_open(true)
	pp.show_view("parc")
	await process_frame
	var bt: Button = pp.find_child("GererParc", true, false)
	_check(bt != null, "bouton « Gérer le parc (maquette) »")
	pp.set_open(false)

	print("Sans gestion, rien ne change :")
	_check(not gest.etats.has(entree), "parc jamais ouvert en gestion")
	_check(Gestion.effet_de(entree, "attrait") == 0.0 and Gestion.humeur_parc_de(entree) == 0.0, "aucun effet sur le vrai parc")
	var argent0 := bs.money
	gest.nouveau_jour({"day": gest.jour + 1, "month": 7})
	_check(bs.money == argent0 and not gest.etats.has(entree), "rien de prélevé")

	print("Le vrai parc tourne :")
	var st := gest.etat(entree)
	_check(gest.valide(entree) and gest.source(entree) == "parc", "parc géré")
	_check(int(st.niv.accueil) >= 1 and int(st.niv.manege) >= 1, "accueil et manèges là dès le départ")
	gest.set_auto(entree, false)
	parc.clock = SAMEDI - 3600.0
	parc.last_day = int(parc._now(parc.clock).day)
	var att0 := float(parc.attendus(entree, parc._now(SAMEDI))[0])
	var run := func(hours: float) -> void:
		for i in int(hours * 60.0):
			parc.clock += ParcLoisirs.STEP
			parc.step(ParcLoisirs.STEP)
	run.call(8.0)
	_check(gest.visiteurs_parc(entree) > 20, "%d visiteurs dans le parc" % gest.visiteurs_parc(entree))
	_check(gest.capacite_parc(entree) > 0, "capacité %d" % gest.capacite_parc(entree))
	_check(gest.note(entree) > 0.5 and gest.note(entree) <= 5.0, "note du vrai parc : %.1f" % gest.note(entree))
	_check(gest.prix_unitaire(entree) == float(parc.parcs[entree].prix), "le billet est celui du parc (%s)" % gest.prix_txt(entree))
	var prix0 := float(parc.parcs[entree].prix)
	gest.changer_prix(entree, 1)
	_check(float(parc.parcs[entree].prix) > prix0, "billet monté depuis la gestion (%.1f €)" % float(parc.parcs[entree].prix))
	gest.changer_prix(entree, -1)
	run.call(17.0)
	var p: Dictionary = parc.parcs[entree]
	var caisse0 := float(st.caisse)
	gest.nouveau_jour({"day": gest.jour + 1, "month": 7})
	_check(float(st.hier.ca) > 0.0 and int(st.hier.clients) > 0, "bilan d'hier : %s, %d visiteurs" % [BuildingSystem.format_money(int(st.hier.ca)), int(st.hier.clients)])
	_check(float(st.caisse) >= caisse0, "une part du bénéfice va à la caisse des travaux (+%s)" % BuildingSystem.format_money(int(float(st.caisse) - caisse0)))
	_check(int(st.record) == int(st.hier.clients), "record noté")

	print("Aménagements → vrai parc :")
	st.caisse = 2_000_000.0
	var r := gest.ameliorer(entree, "atelier")
	_check(bool(r.ok), "atelier de maintenance construit")
	_check(Gestion.effet_de(entree, "fiabilite") > 0.0, "manèges plus fiables (+%d %%)" % roundi(Gestion.effet_de(entree, "fiabilite") * 100.0))
	gest.ameliorer(entree, "toilettes")
	gest.ameliorer(entree, "atelier")
	_check(Gestion.effet_de(entree, "proprete") > 0.0, "parc plus propre (+%d %%)" % roundi(Gestion.effet_de(entree, "proprete") * 100.0))
	gest.ameliorer(entree, "accueil")
	gest.ameliorer(entree, "parking")
	gest.ameliorer(entree, "spectacles")
	_check(Gestion.effet_de(entree, "attrait") > 0.0, "plus de visiteurs attirés (+%d %%)" % roundi(Gestion.effet_de(entree, "attrait") * 100.0))
	var att1 := float(parc.attendus(entree, parc._now(SAMEDI))[0])
	_check(att1 > att0, "le vrai parc attend plus de monde (%d → %d)" % [roundi(att0), roundi(att1)])
	_check(Gestion.humeur_parc_de(entree) > 0.0, "les visiteurs arrivent de meilleure humeur (+%.1f)" % Gestion.humeur_parc_de(entree))
	var dn := parc.detail_note(entree)
	_check(dn.has("gestion") and float(dn.gestion) > 0.0, "la note du parc compte les aménagements (+%.2f)" % float(dn.get("gestion", 0.0)))
	var oid0 := ""
	for o in GestionTypes.objets("parc", "restauration"):
		oid0 = String(o)
		break
	_check(bool(gest.acheter(entree, "restauration", oid0).ok) and gest.a_objet(entree, "restauration", oid0), "objet acheté pour la restauration (%s)" % oid0)

	print("Demandes, événements, objectifs :")
	var possibles := gest.demandes_possibles(entree)
	_check(possibles.size() >= 8, "%d demandes possibles" % possibles.size())
	var b0 := float(st.bonus)
	var don := gest.regler(entree, possibles[0])
	_check(float(st.bonus) > b0, "demande réglée : visiteurs ravis (bonus %.1f)" % float(st.bonus))
	_check(not gest.nouvelle_panne(entree).is_empty(), "une panne dans la maquette")
	for j in 400:
		gest._evenements(entree, gest.etat(entree), 6 if j < 200 else 12)
		gest.jour += 1
	var txt := ""
	for e in gest.etat(entree).journal:
		txt += String(e[1]) + "\n"
	_check(txt.contains("Inspection") or txt.contains("Label"), "inspection de sécurité au journal")
	_check(txt.contains("autocar") or txt.contains("Autocar") or txt.contains("scolaire") or txt.contains("anniversaire") or txt.contains("influen"), "autocars, sorties scolaires, anniversaires ou influenceurs")
	var objs := gest.objectifs(entree)
	var otxt := ""
	for o in objs:
		otxt += String(o.texte) + " ; "
	_check(otxt.contains("1 000 visiteurs") and otxt.contains("trophée"), "objectifs du parc")

	print("Gestion automatique :")
	gest.set_auto(entree, true)
	st.caisse = 300_000.0
	var inv0 := float(st.invest)
	gest.nouveau_jour({"day": gest.jour + 1, "month": 7})
	_check(float(st.invest) > inv0, "le parc investit sa caisse tout seul (%s)" % BuildingSystem.format_money(int(float(st.invest) - inv0)))

	print("Sauvegarde :")
	var niv: Dictionary = st.niv.duplicate()
	var d := gest.to_dict()
	gest.clear()
	_check(Gestion.effet_de(entree, "attrait") == 0.0, "effacé : plus d'effet")
	gest.from_dict(JSON.parse_string(JSON.stringify(d)))
	_check(gest.etat(entree).niv == niv and Gestion.effet_de(entree, "attrait") > 0.0, "rechargé : niveaux et effets")

	print("Maquette :")
	_check(scene.ouvrir_gestion(entree) and vue.est_ouvert() and vue.genre == "parc", "la maquette du parc s'ouvre")
	await process_frame
	var dio := vue.diorama
	var nmini := 0
	for z in dio.miniatures:
		nmini += mini((dio.miniatures[z] as Array).size(), 3)
	_check(nmini == 4 and dio._minis.size() == 4, "les 4 vraies attractions en miniature (%d)" % dio._minis.size())
	_check(dio.miniatures.has("sensations"), "les montagnes russes dans les sensations fortes")
	for i in 300:
		vue.simuler(0.1)
	_check(not dio.clients.is_empty(), "%d visiteurs dans la maquette" % dio.clients.size())
	_check(dio.places.has("restauration") and not (dio.places.restauration as Array).is_empty(), "places à la restauration")
	vue.choisir("")
	var plus: Button = vue._carte_corps.find_child("Prix_plus", true, false)
	_check(plus != null, "bouton du billet")
	for o in ["personnel", "stats", "journal"]:
		vue.onglet = o
		vue._remplir_carte()
	_check(vue._bas.get_child_count() == GestionTypes.ordre("parc").size() + 1, "une tuile par zone en bas")
	vue.fermer()
	_check(not vue.est_ouvert(), "retour à la ville")
	scene.queue_free()
	await process_frame
