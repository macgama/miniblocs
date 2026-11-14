extends SceneTree
## Test des modèles de l'atelier devenus bâtiments du jeu : fonction (n'importe
## quel type du catalogue), entrée « mdl_… » du catalogue, maillage cuit, prix,
## pose avec rotation et chantier, sauvegarde, créations en blocs avec fonction.
## Usage : godot --headless --path . --script res://tests/modeles_jeu_test.gd

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
	Creations.persist = false
	BanqueModeles.persist = false
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var bs: BuildingSystem = scene.get_node("Batiments")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.set_origin(48.8584, 2.2945)
	for i in 60:
		await process_frame
	bs.unlimited_money = true
	bs.require_access = false
	var mob: Mobilier = scene.mobilier

	print("Un modèle en murs fins entre au catalogue :")
	var house := bs.place("hollandais__maison", Vector2i(-30, -10), 0)
	var conv := Conversion.open_interior(mob, house)
	_check(conv.ok, "maison en murs fins construite")
	var r := BanqueModeles.save_plan(mob, String(conv.id), "Ma maison")
	_check(r.ok, "enregistrée dans la banque")
	var mid := String(r.id)
	var d := BanqueModeles.get_model(mid)
	_check(d.has("dy2") and String(d.fonction) == "maison", "hauteur des blocs repérée, fonction par défaut : maison")
	var cid := ModelesJeu.catalog_id(mid)
	var t := BuildingCatalog.get_type(cid)
	_check(not t.is_empty() and String(t.name) == "Ma maison" and String(t.cat) == "logement", "entrée %s dans la catégorie Logement" % cid)
	_check(int(t.logements) >= 1 and BuildingCatalog.base_of(cid) == "maison", "un logement, rôle de la Maison")
	_check(int(t.w) >= 4 and int(t.w) <= 20 and int(t.d) >= 4 and int(t.d) <= 20, "emprise %d × %d m" % [int(t.w), int(t.d)])
	_check(BuildingCatalog.cost(cid) >= ModelesJeu.MIN_COST, "prix : %s" % BuildingSystem.format_money(BuildingCatalog.cost(cid)))
	_check(BuildingCatalog.ids_in("logement").has(cid) and ModelesJeu.ids().has(cid), "proposée dans Logement et dans Mes modèles")
	var mesh := BuildingCatalog.build_mesh(cid)
	var box := mesh.get_aabb()
	_check(mesh.get_surface_count() > 0 and box.size.y > 5.0, "maillage cuit : murs et toit (%.1f m de haut)" % box.size.y)
	_check(absf(box.get_center().x) < 1.5 and absf(box.get_center().z) < 1.5 and box.position.y > -2.5, "centré, posé au sol")
	_check(box.size.x <= float(t.w) + 0.5 and box.size.z <= float(t.d) + 0.5, "tient dans son emprise")
	_check(not Personnalisation.can_customize(cid) and not Conversion.can_open(cid), "ni personnalisation ni conversion (apparence propre)")

	print("Posé comme un bâtiment :")
	bs.unlimited_money = false
	bs.money = 50_000_000
	var m0 := bs.money
	var bid := bs.place(cid, Vector2i(20, 30), 1)
	_check(bid >= 0, "posé, tourné d'un quart")
	if bid >= 0:
		var b: Dictionary = bs.buildings[bid]
		_check(BuildingCatalog.footprint(cid, 1) == Vector2i(int(t.d), int(t.w)), "rotation : emprise tournée")
		_check(bs.money < m0 or int(b.get("du", 0)) > 0 or bs.en_chantier(bid), "il se paie (ou son chantier)")
		_check(bs.node_of(bid) != null, "il se voit")
		_check(Metiers.keys_of(cid).has("maison"), "les habitants le voient comme une maison")
	bs.unlimited_money = true

	print("Visitable une fois posé :")
	var mv: ModelesVisites = scene.modeles_visites
	var amb: DayNight = scene.get_node("Ambiance")
	var pe: PlanEditor = mob.pe
	var n_walls := (d.walls as Array).size() / 9
	var n_meubles := (d.meubles as Array).size() / 6
	var n_blocs := (d.blocs as Array).size() / 4
	var bids := [bid]
	for rr in 4:
		bids.append(bs.place(cid, Vector2i(-60 + rr * 22, 70), rr))
	amb.unix_time += 86400.0 * 90
	for i in 40:
		await process_frame
	mv.sync()
	var all_ok := true
	for i in bids.size():
		var b_id: int = bids[i]
		if b_id < 0 or bs.en_chantier(b_id):
			_check(false, "bâtiment %d posé et fini" % i)
			all_ok = false
			continue
		var pid := mv.plan_of(b_id)
		if pid == "" or not pe.plans.has(pid):
			_check(false, "murs fins posés (bâtiment %d)" % i)
			all_ok = false
			continue
		var pl: Dictionary = pe.plans[pid]
		var rect: Rect2i = bs._rect_of(bs.buildings[b_id])
		var bb: Rect2i = pe._bbox[pid]
		var nm := (mob.items.get(pid, {}) as Dictionary).size()
		var ok_i: bool = pl.walls.size() == n_walls and nm == n_meubles and (mv.links[b_id].bk as Array).size() == n_blocs * 3 \
			and rect.encloses(bb) and not bs.node_of(b_id).visible and mob.linked.get(pid, -1) == b_id
		if not ok_i:
			print("    r=%d murs %d/%d meubles %d/%d blocs %d/%d emprise %s dans %s" % [int(bs.buildings[b_id].r), pl.walls.size(), n_walls, nm, n_meubles,
				(mv.links[b_id].bk as Array).size() / 3, n_blocs, str(bb), str(rect)])
		all_ok = all_ok and ok_i
	_check(all_ok, "dans les 4 orientations : mêmes murs, meubles et toit, dans l'emprise, volume cuit caché")
	mob._on_plans_changed()
	var kept := true
	for b_id in bids:
		kept = kept and (mob.items.get(mv.plan_of(b_id), {}) as Dictionary).size() == n_meubles
	_check(kept, "aucun meuble ne tombe à la vérification (orientations justes)")
	var info := mob.population_info()
	var counted := false
	for k in info:
		if mob.linked.has(String(info[k].plan)):
			counted = true
	_check(not counted, "les murs fins ne comptent pas une deuxième fois pour les habitants")
	var cell_in := Vector2i(pe._bbox[mv.plan_of(bids[1])].get_center())
	_check(mob.bid_at(cell_in) == bids[1], "un clic dans la maison montre le bâtiment")
	var saved_links := mv.to_dict()
	mv.from_dict(saved_links)
	_check(mv.links.size() == bids.size() and mob.linked.size() == bids.size(), "liens relus après sauvegarde")
	var gone_plan := mv.plan_of(bids[2])
	var gone_bk: Array = mv.links[bids[2]].bk
	bs.demolish(bids[2])
	mv.sync()
	_check(not pe.plans.has(gone_plan) and not mv.links.has(bids[2]) and not mob.items.has(gone_plan), "démoli : murs et meubles partis")
	_check(gone_bk.is_empty() or not pe.blocks.blocks.has(Vector3i(int(gone_bk[0]), int(gone_bk[1]), int(gone_bk[2]))), "et son toit en blocs aussi")

	print("Fonction : centrale électrique :")
	BanqueModeles.set_fonction(mid, "centrale_gaz")
	t = BuildingCatalog.get_type(cid)
	_check(String(t.cat) == "reseaux" and t.has("reseau") and String(t.reseau.res) == "elec", "elle produit de l'électricité")
	_check(not ReseauxTypes.info(cid).is_empty() and BuildingCatalog.base_of(cid) == "centrale_gaz", "le réseau la reconnaît")
	var ref := BuildingCatalog.get_type("centrale_gaz")
	_check(float(t.reseau.cap) < float(ref.reseau.cap) and float(t.reseau.cap) > 0.0, "puissance à sa taille : %.1f MW (%.0f MW pour la vraie)" % [float(t.reseau.cap), float(ref.reseau.cap)])
	_check(not t.has("glb") and String(t.name) == "Ma maison", "garde son nom et son apparence")
	_check(BuildingCatalog.build_mesh(cid) == mesh, "même maillage (mis en cache)")

	print("Autres fonctions :")
	var groups := ModelesJeu.fonctions()
	var n := 0
	for g in groups:
		n += (g.ids as Array).size()
	_check(n > 300, "%d bâtiments au choix, en %d catégories" % [n, groups.size()])
	var picker := FonctionChoix.new("piscine")
	_check(picker.matches().has("piscine"), "le choix s'ouvre sur la catégorie de la fonction")
	picker._text = "grand"
	picker._cat = ""
	_check(picker.matches().size() > 0, "recherche « grand » : %d résultats" % picker.matches().size())
	picker.free()
	for f in ["stade_tuiliere", "piscine", "foot", "ferme"]:
		if BuildingCatalog.get_type(f).is_empty():
			continue
		BanqueModeles.set_fonction(mid, f)
		var tf := BuildingCatalog.get_type(cid)
		_check(BuildingCatalog.base_of(cid) == f and String(tf.cat) == String(BuildingCatalog.get_type(f).cat), "fonction %s" % f)
	_check(Stades.est_stade(cid) == Stades.est_stade("ferme") or BuildingCatalog.base_of(cid) == "ferme", "fonction ferme : pas un stade")
	BanqueModeles.set_fonction(mid, "foot")
	_check(Stades.est_stade(cid), "fonction terrain de foot : un stade")
	var parc_ids := BuildingCatalog.ids_in("parc")
	if not parc_ids.is_empty():
		var ride := ""
		for pid in parc_ids:
			if ParcTypes.role_of(String(pid)) == "attraction":
				ride = String(pid)
				break
		if ride != "":
			BanqueModeles.set_fonction(mid, ride)
			_check(ParcTypes.role_of(cid) == "attraction" and (ParcTypes.build_anim(cid) == null or ParcTypes.build_anim(cid).get_child_count() == 0), "fonction attraction (%s), sans pièces mobiles ajoutées" % ride)

	print("Sauvegarde de la partie :")
	var sec := ModelesJeu.to_dict(bs)
	_check((sec.items as Dictionary).has(mid), "le modèle voyage avec la partie")
	BanqueModeles.remove(mid)
	_check(not BuildingCatalog.get_type(cid).is_empty() and BuildingCatalog.get_type(cid).get("cache", false), "retiré de la banque : caché, les exemplaires posés restent")
	_check(not ModelesJeu.ids().has(cid), "plus dans Mes modèles")
	ModelesJeu.adopt(sec)
	_check(not BuildingCatalog.get_type(cid).is_empty(), "relu depuis une sauvegarde")

	print("Créations en blocs :")
	Creations.items["crea_test"] = {"name": "Mon bassin", "w": 6, "d": 4, "blocks": [0, 0, 0, 1, 1, 0, 0, 1, 5, 0, 3, 1], "cost": 5000}
	Creations.set_fonction("crea_test", "piscine")
	var tc := BuildingCatalog.get_type("crea_test")
	_check(String(tc.cat) == "sport" and int(tc.visiteurs) >= 1 and tc.has("blocks"), "une création devient une piscine (%d visiteurs)" % int(tc.visiteurs))
	_check(BuildingCatalog.build_mesh("crea_test").get_surface_count() > 0, "avec son apparence en blocs")
	Creations.set_fonction("crea_test", "")
	_check(String(BuildingCatalog.get_type("crea_test").cat) == Creations.CATEGORY, "sans fonction : redevient un décor")

	print("Interface :")
	var bp: BuildingPanel = scene.build_panel
	var r2 := BanqueModeles.save_plan(mob, String(conv.id), "Deuxième")
	bp.set_workshop(false)
	bp.show_category(ModelesJeu.CATEGORY)
	await process_frame
	_check(bp._item_buttons.size() > 0, "onglet Mes modèles du catalogue B")
	bp.set_workshop(true, "banque")
	scene.banque_panel._choosing = String(r2.id)
	bp.show_category("banque")
	await process_frame
	_check(true, "Banque : carte avec Fonction et choix ouvert")
	bp.show_category(Creations.CATEGORY)
	await process_frame
	_check(true, "Mes créations : bouton Fonction")

	print("MODELES JEU TEST " + ("OK" if ok else "ÉCHEC"))
	quit(0 if ok else 1)
