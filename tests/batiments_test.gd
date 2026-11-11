extends SceneTree
## Test de la pose de bâtiments dans le mode Terre (sans réseau).
## Usage : godot --headless --path . --script res://tests/batiments_test.gd

var ok := true


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	if not cond:
		push_error("ÉCHEC : " + what)
		ok = false
	else:
		print("  ok  ", what)


## Plaine qui monte vers l'Est (≈ 19 cm par mètre), plate du Nord au Sud.
func _fake_tile(t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	for y in 256:
		for x in 256:
			var gx := t.x * 256 + x
			a[y * 256 + x] = 40.0 + float(gx - 4_247_700) * 0.6
	return a


func _run() -> void:
	Creations.persist = false
	print("Catalogue :")
	var all_ok := true
	var n_types := 0
	for id in BuildingCatalog.all_types():
		n_types += 1
		var t := BuildingCatalog.get_type(id)
		var m := BuildingCatalog.build_mesh(id)
		if m.get_surface_count() != 1:
			all_ok = false
			push_error("modèle vide : " + id)
			continue
		var bb := m.get_aabb()
		var fits: bool = bb.position.x >= -t.w / 2.0 - 0.7 and bb.end.x <= t.w / 2.0 + 0.7 \
			and bb.position.z >= -t.d / 2.0 - 0.7 and bb.end.z <= t.d / 2.0 + 0.7 and bb.position.y >= -0.01
		if not fits:
			all_ok = false
			push_error("%s dépasse de son emprise %d × %d : %s" % [id, t.w, t.d, bb])
		if BuildingCatalog.cost(id) <= 0 or BuildingCatalog.category(t.cat).is_empty():
			all_ok = false
			push_error("prix ou catégorie manquant : " + id)
	_check(all_ok, "%d modèles construits, chacun dans son emprise, avec prix et catégorie" % n_types)
	for c in BuildingCatalog.CATEGORIES:
		_check(BuildingCatalog.ids_in(c.id).size() >= 3, "catégorie %s : %d bâtiments" % [c.name, BuildingCatalog.ids_in(c.id).size()])
	_check(n_types >= 200, "bible : %d bâtiments au total" % n_types)
	for r in Styles.REGIONS:
		_check(BuildingCatalog.ids_in("logement", r.id).size() >= 1, "région %s : %d logements" % [r.name, BuildingCatalog.ids_in("logement", r.id).size()])
	for e in Styles.ERAS:
		var n_e := 0
		for c in BuildingCatalog.CATEGORIES:
			n_e += BuildingCatalog.ids_in(c.id, "", e.id).size()
		_check(n_e >= 5, "époque %s : %d bâtiments" % [e.name, n_e])
	var filt_ok := true
	for id in BuildingCatalog.ids_in("services", "asie_est", "traditionnel"):
		var tt := BuildingCatalog.get_type(id)
		filt_ok = filt_ok and tt.region == "asie_est" and tt.era == "traditionnel" and tt.cat == "services"
	_check(filt_ok and BuildingCatalog.ids_in("services", "asie_est", "traditionnel").size() >= 2, "filtres région + époque")
	_check(ZoneSystem.types_for("R", "japonais").has("japonais__maison") and not ZoneSystem.types_for("R", "japonais").has("maison"), "zonage par style : modèles du style seulement")
	_check(ZoneSystem.types_for("C", "").has("cafe"), "zonage classique inchangé")
	_check(BuildingCatalog.footprint("maison", 1) == Vector2i(12, 10), "un quart de tour échange largeur et profondeur")
	_check(BuildingSystem.format_money(1234567) == "1 234 567 €", "affichage de l'argent")

	print("Pose sur le terrain :")
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	root.add_child(scene)
	world.tiles.offline_generator = _fake_tile
	# Prairie partout, sauf un lac au Nord-Est.
	world.land.offline_generator = func(lat: float, lon: float) -> int:
		return 80 if lat > 48.8584 + 0.0009 and lon > 2.2945 + 0.0009 else 30
	world.set_origin(48.8584, 2.2945)
	for i in 90:
		await process_frame
	_check(not is_nan(world.cell_height(Vector2i(0, 0))), "relief chargé")

	var res := bs.check_place("maison", Vector2i(0, -8), 0)
	_check(not res.ok and String(res.reason).contains("route"), "sans route, la maison est refusée (« %s »)" % res.reason)

	var ya := world.cell_height(Vector2i(0, 0))
	var road := transport.build_segment("route", Vector3(0, ya, -60), Vector3(0, ya, 60))
	_check(road.ok, "route posée du Nord au Sud (x = 0)")

	_check(bs.best_rotation("maison", Vector2i(12, 0)) == 3, "à l'Est de la route : façade tournée vers l'Ouest")
	_check(bs.best_rotation("maison", Vector2i(-12, 0)) == 1, "à l'Ouest : façade tournée vers l'Est")
	var money0 := bs.money
	var id := bs.place("maison", Vector2i(12, 0), 3)
	_check(id > 0, "maison posée")
	var b: Dictionary = bs.buildings.get(id, {})
	var rect := BuildingSystem.rect_for("maison", Vector2i(12, 0), 3)
	var flat := true
	for x in range(rect.position.x, rect.end.x):
		for z in range(rect.position.y, rect.end.y):
			flat = flat and world.cell_height(Vector2i(x, z)) == float(b.h)
	_check(flat, "emprise de 12 × 10 cases aplanie à %.1f m" % b.h)
	_check(bs.building_at(Vector2i(12, 0)) == id and bs.occupancy.size() == 120, "120 cases occupées")
	_check(bs.money < money0 and money0 - bs.money >= BuildingCatalog.cost("maison"), "prix payé : %s" % BuildingSystem.format_money(money0 - bs.money))
	_check(scene.get_node("Batiments").get_child_count() > 3, "modèle 3D ajouté")

	_check(not bs.check_place("immeuble", Vector2i(16, 4), 3).ok, "pas de bâtiment sur un autre")
	var r2 := bs.check_place("maison", Vector2i(0, 30), 0)
	_check(not r2.ok and String(r2.reason).contains("voie"), "pas de bâtiment sur la route")
	var through := transport.build_segment("route", Vector3(12, ya, -40), Vector3(12, ya, 40))
	_check(not through.ok and String(through.reason).contains("bâtiment"), "pas de route à travers un bâtiment")
	var steep := bs.check_place("foot", Vector2i(-70, 0), 1)
	_check(not steep.ok and String(steep.reason).contains("pentu"), "terrain de foot refusé sur la pente (« %s »)" % steep.reason)
	bs.require_access = false
	var lake := bs.check_place("maison", Vector2i(130, -170), 0)
	_check(not lake.ok and String(lake.reason).contains("lac"), "pas de construction sur un lac (« %s »)" % lake.reason)
	bs.require_access = true

	bs.money = 1000
	_check(not bs.check_place("maison", Vector2i(12, -20), 3).ok, "refusé si la caisse est vide")
	bs.unlimited_money = true
	var id2 := bs.place("maison", Vector2i(12, -20), 3)
	_check(id2 > 0 and bs.money == 1000, "argent illimité : rien n'est débité")
	bs.unlimited_money = false
	bs.require_access = false
	bs.money = 1_000_000
	var id3 := bs.place("parc", Vector2i(-60, 40), 0)
	_check(id3 > 0, "sans la règle d'accès, un parc isolé est accepté")
	_check(bs.totals().non_desservis == 1, "le parc est compté sans accès")
	bs.require_access = true

	var before := bs.money
	var paid := int(bs.buildings[id3].cost)
	bs.demolish(id3)
	_check(not bs.buildings.has(id3) and bs.building_at(Vector2i(-60, 40)) == -1, "démolition")
	_check(bs.money == before + roundi(paid * BuildingSystem.REFUND), "moitié du prix rendue")

	print("Zonage :")
	var zs: ZoneSystem = scene.get_node("Zones")
	zs.growth = false
	var m0 := bs.money
	var zid := zs.add_zone("R", Rect2i(-50, -40, 45, 80))
	_check(zid > 0 and bs.money == m0 - 45 * 80 * ZoneSystem.PRICE_M2, "zone résidentielle peinte et payée")
	_check(float(zs.demand().R) > 0.0, "demande résidentielle au départ")
	var n0 := bs.buildings.size()
	for i in 40:
		zs.grow_step()
	var grown := 0
	var inside := true
	var served := true
	for bb in bs.buildings.values():
		if int(bb.get("zone", 0)) == 0:
			continue
		grown += 1
		inside = inside and Rect2i(-50, -40, 45, 80).encloses(Rect2i(Vector2i(bb.x, bb.z), BuildingCatalog.footprint(bb.t, bb.r)))
		served = served and not bs.find_access(bb.t, Rect2i(Vector2i(bb.x, bb.z), BuildingCatalog.footprint(bb.t, bb.r)), bb.r).is_empty()
		inside = inside and BuildingCatalog.get_type(bb.t).cat == "logement"
	_check(grown >= 4 and bs.buildings.size() == n0 + grown, "%d logements ont poussé dans la zone" % grown)
	_check(inside, "tous dans la zone, tous des logements")
	_check(served, "tous desservis par la route")
	_check(bs.money == m0 - 45 * 80 * ZoneSystem.PRICE_M2, "les bâtiments de zone ne coûtent rien au joueur")
	_check(zs.remove_area(Rect2i(-50, -10, 45, 20)) == 1 and zs.zones.size() == 2, "retirer le milieu coupe la zone en deux")
	_check(zs.zone_at(Vector2i(-20, 0)) == -1 and zs.zone_at(Vector2i(-20, -30)) > 0, "le milieu n'est plus zoné")
	_check(zs.add_zone("I", Rect2i(0, 0, 400, 10)) == -1, "zone trop grande refusée")
	zs.current_style = "japonais"
	var zj := zs.add_zone("R", Rect2i(-50, 41, 45, 19))
	zs.current_style = ""
	var nj0 := bs.buildings.size()
	for i in 30:
		zs._grow_in(zs.zones[zj])
	var styled := true
	var nj := 0
	for bb in bs.buildings.values():
		if int(bb.get("zone", 0)) == zj:
			nj += 1
			styled = styled and String(bb.t).begins_with("japonais__")
	_check(nj >= 1 and styled, "zone de style japonais : %d bâtiments japonais ont poussé" % nj)
	zs.remove_area(Rect2i(-50, 41, 45, 19))
	for bid in bs.buildings.keys():
		if int(bs.buildings[bid].get("zone", 0)) == zj:
			bs.demolish(bid)
	_check(bs.buildings.size() == nj0, "zone de style retirée")
	await process_frame
	_check(zs._views.size() == 2, "calques de zone dessinés")
	var nb := bs.buildings.size()

	print("Éditeur libre :")
	var be: BlockEditor = scene.get_node("Blocs")
	bs.unlimited_money = false
	bs.money = 1_000_000
	var g := world.cell_height(Vector2i(-120, -100))
	var k0 := Vector3i(-120, roundi(g / BlockEditor.UNIT_Y), -100)
	var tg := be.target_from_ray(Vector3(-119.5, g + 60.0, -99.5), Vector3.DOWN)
	_check(not tg.is_empty() and tg.place == k0 and tg.hit == null, "visée sur le sol : bloc posé au ras du relief")
	_check(be.place_blocks([k0], 0) == 1 and bs.money == 1_000_000 - 120, "un bloc de brique posé et payé")
	tg = be.target_from_ray(Vector3(-119.5, g + 60.0, -99.5), Vector3.DOWN)
	_check(tg.hit == k0 and tg.place == k0 + Vector3i(0, BlockEditor.HU, 0), "visée sur le dessus : le bloc suivant va au-dessus")
	tg = be.target_from_ray(Vector3(-130.0, g + 0.6, -99.5), Vector3.RIGHT)
	_check(tg.get("hit") == k0 and tg.place == k0 + Vector3i(-1, 0, 0), "visée de côté : le bloc suivant va à côté")
	_check(be.place_blocks([k0], 0) == 0, "pas deux blocs au même endroit")
	_check(be.check_block(k0 - Vector3i(0, 2 * BlockEditor.HU, 0)).contains("sous terre"), "pas de bloc sous terre")
	var wall := be.drag_keys(k0 + Vector3i(0, 0, 2), k0 + Vector3i(1, 0, 7), BlockEditor.Tool.WALL)
	_check(wall.size() == 6 * be.wall_height, "mur de 6 × %d blocs" % be.wall_height)
	_check(be.place_blocks(wall, 4) == wall.size(), "mur en béton posé")
	var slab := be.drag_keys(k0 + Vector3i(-3, 0, 9), k0 + Vector3i(0, 0, 12), BlockEditor.Tool.RECT)
	_check(be.place_blocks(slab, 3) == 16, "dalle de 4 × 4 en planches")
	var nblocks := be.blocks.size()
	var on_blocks := bs.check_place("maison", Vector2i(-118, -98), 0)
	_check(not on_blocks.ok and String(on_blocks.reason).contains("blocs"), "pas de bâtiment sur des blocs")
	var yb2 := world.cell_height(Vector2i(-140, -97))
	var rb := transport.build_segment("route", Vector3(-140, yb2, -97), Vector3(-100, yb2, -97))
	_check(not rb.ok, "pas de route à travers des blocs")
	var m1 := bs.money
	_check(be.remove_blocks([k0]) == 1 and bs.money == m1 + 60, "bloc retiré, moitié du prix rendue")
	_check(be.undo() and be.blocks.has(k0) and bs.money == m1, "Ctrl+Z remet le bloc")
	await process_frame
	_check(be._chunks.size() >= 1, "blocs dessinés")
	var has_body := false
	for c in (be._chunks.values()[0] as Node).get_children():
		has_body = has_body or c is StaticBody3D
	_check(has_body, "les blocs ont une collision")
	var bnode: Node = bs._nodes[id]
	_check(bnode.get_child(0) is StaticBody3D, "les bâtiments ont une collision")
	_check(world.modifications.has(Vector2i(-120, -100)), "pas d'arbres sous les blocs")

	print("Espaces publics :")
	_check(BuildingCatalog.ids_in("espaces").size() >= 25, "%d places, parcs, monuments et mobilier" % BuildingCatalog.ids_in("espaces").size())
	var bench := bs.check_place("banc", Vector2i(-250, -200), 0)
	_check(bench.ok, "un banc se pose sans route (%s)" % bench.reason)
	_check(not bs.check_place("place_pavee", Vector2i(-250, -230), 0).ok, "une place pavée demande une voie")

	print("Mes créations :")
	be.capture_name = "Ma cabane"
	var cap := be.capture(Rect2i(k0.x - 5, k0.z - 2, 9, 16))
	_check(cap.ok and int(cap.blocks) == nblocks, "création enregistrée : %s blocs" % cap.get("blocks"))
	var crea_id: String = cap.get("id", "")
	var ct := BuildingCatalog.get_type(crea_id)
	_check(ct.get("name") == "Ma cabane" and ct.cat == Creations.CATEGORY and int(ct.w) == 4 and int(ct.d) == 13, "dans le catalogue : 4 × 13 m (%s × %s)" % [ct.get("w"), ct.get("d")])
	_check(Creations.ids().has(crea_id) and BuildingCatalog.cost(crea_id) > 0, "listée dans Mes créations, avec un prix")
	var cm := BuildingCatalog.build_mesh(crea_id)
	var cbb := cm.get_aabb()
	_check(cm.get_surface_count() == 1 and absf(cbb.size.x - 4.0) < 0.01 and absf(cbb.size.z - 13.0) < 0.01 and cbb.size.y >= 1.5, "modèle de la création à la bonne taille")
	_check(not be.capture(Rect2i(500, 500, 3, 3)).ok, "sélection vide refusée")
	bs.require_access = false
	var cid := bs.place(crea_id, Vector2i(-200, 100), 1)
	bs.require_access = true
	_check(cid >= 0, "création posée comme un bâtiment")
	bs.money = before + roundi(paid * BuildingSystem.REFUND) - 45 * 80 * ZoneSystem.PRICE_M2
	nb = bs.buildings.size()
	var crea_save := Creations.to_dict(Creations.used_by(bs))
	_check((crea_save.items as Dictionary).has(crea_id), "la partie garde une copie de la création")
	Creations.remove(crea_id)
	_check(not Creations.ids().has(crea_id) and not BuildingCatalog.get_type(crea_id).is_empty(), "retirée de la liste, toujours connue des bâtiments posés")
	Creations.items.erase(crea_id)
	BuildingCatalog.all_types().erase(crea_id)
	Creations.adopt(JSON.parse_string(JSON.stringify(crea_save)))
	_check(BuildingCatalog.get_type(crea_id).get("name") == "Ma cabane", "création retrouvée depuis la sauvegarde")

	print("Sauvegarde :")
	_check(world.save_world({"transport": transport.to_dict(), "batiments": bs.to_dict(), "zones": zs.to_dict(), "blocs": be.to_dict()}), "sauvegarde")
	world.set_origin(45.8326, 6.8652)
	_check(bs.buildings.is_empty() and bs.occupancy.is_empty(), "nouvelle région : aucun bâtiment")
	_check(zs.zones.is_empty(), "nouvelle région : aucune zone")
	_check(world.load_world(), "chargement")
	transport.from_dict(world.loaded_data.get("transport", {}))
	bs.from_dict(world.loaded_data.get("batiments", {}))
	zs.from_dict(world.loaded_data.get("zones", {}))
	_check(zs.zones.size() == 2, "zones restaurées")
	be.from_dict(world.loaded_data.get("blocs", {}))
	_check(be.blocks.size() == nblocks and be.blocks.get(k0) == 0, "blocs restaurés")
	_check(bs.buildings.size() == nb and bs.building_at(Vector2i(12, 0)) == id, "bâtiments restaurés")
	_check(bs.money == before + roundi(paid * BuildingSystem.REFUND) - 45 * 80 * ZoneSystem.PRICE_M2, "caisse restaurée")
	bs.unlimited_money = true
	_check(bs.place("maison", Vector2i(12, 20), 3) > id3, "les nouveaux identifiants continuent après les anciens")

	print("BATIMENTS TEST OK" if ok else "BATIMENTS TEST ÉCHEC")
	quit(0 if ok else 1)
