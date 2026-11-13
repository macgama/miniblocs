extends SceneTree
## Test de la personnalisation des bâtiments, de l'ouverture de leur intérieur,
## de la banque de modèles et des tuiles de l'atelier.
## Usage : godot --headless --path . --script res://tests/atelier_test.gd

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

	print("Personnaliser :")
	var tid := "hollandais__maison"
	_check(Personnalisation.can_customize(tid) and Personnalisation.can_shape(tid), "la Maison à pignon se personnalise")
	var a := bs.place(tid, Vector2i(-30, -10), 0)
	var b := bs.place(tid, Vector2i(-18, -10), 0)
	_check(a >= 0 and b >= 0, "deux maisons posées")
	var h0 := bs.node_of(a).mesh.get_aabb().size.y
	bs.set_perso(a, {"mur": "3d6fa8", "toit_c": "c2453a", "toit": "hip", "etages": 4})
	var h1 := bs.node_of(a).mesh.get_aabb().size.y
	_check(h1 > h0 + 4.0, "4 étages : plus haute (%.1f m au lieu de %.1f m)" % [h1, h0])
	_check(bs.node_of(a).mesh != bs.node_of(b).mesh, "seule la maison personnalisée change")
	_check(Personnalisation.color_of(tid, int(bs.buildings[a].v), bs.perso_of(a), "mur").to_html(false) == "3d6fa8", "couleur des murs retenue")
	var cleaned := Personnalisation.clean({"mur": "3D6FA8", "etages": 3.0, "toit": "inconnu", "pente": 9.0})
	_check(cleaned.etages == 3 and not cleaned.has("toit") and float(cleaned.pente) <= 2.0, "réglages nettoyés (types, bornes)")
	var saved := bs.to_dict()
	bs.from_dict(saved)
	_check(bs.buildings.size() == 2, "les deux maisons relues")
	_check(bs.perso_of(a).get("etages", 0) == 4 and String(bs.perso_of(a).mur) == "3d6fa8", "personnalisation relue après sauvegarde")
	_check(Personnalisation.swatches(tid, "mur").size() >= 8, "nuancier des murs (style + teintes)")

	print("Banque de modèles :")
	var r := BanqueModeles.save_building(bs, a, "Maison bleue")
	_check(r.ok, "maison personnalisée enregistrée")
	var m := BanqueModeles.get_model(String(r.id))
	_check(String(m.genre) == "facade" and String(m.etiquettes.style) == "hollandais" and (m.etiquettes.couleurs as Array).has("bleu"),
		"étiquettes : style, couleurs (%s)" % BanqueModeles.describe(m))
	_check(BanqueModeles.filtered("", "maison", "", "", "bleu").has(r.id) and BanqueModeles.filtered("", "", "", "", "jaune").is_empty(),
		"filtres par type et couleur")
	var placed := BanqueModeles.place(String(r.id), Vector2i(-6, -10), 1, bs, mob)
	_check(placed.ok and int(bs.perso_of(int(placed.bid)).get("etages", 0)) == 4, "modèle reposé avec sa personnalisation")

	print("Ouvrir l'intérieur :")
	var n0 := mob.pe.plans.size()
	var res := Conversion.open_interior(mob, b)
	_check(res.ok, "Maison à pignon ouverte : %s" % str(res))
	var pid := String(res.get("id", ""))
	_check(not bs.buildings.has(b) and mob.pe.plans.size() == n0 + 1, "le modèle du catalogue laisse place aux murs fins")
	_check(mob.pe.levels_of(pid).size() == 2, "deux niveaux comme le modèle")
	var st := mob.stats(pid)
	_check(int(st.logements) >= 1 and int(st.lits) >= 2, "meublée : %d logement, %d lits" % [int(st.logements), int(st.lits)])
	_check((mob.items.get(pid, {}) as Dictionary).size() > 15, "%d meubles posés" % (mob.items.get(pid, {}) as Dictionary).size())
	_check(mob.plan_name(pid) == "Maison à pignon", "le bâtiment garde son nom")
	# Toutes les orientations, et d'autres archétypes.
	var turned := 0
	for rr in 4:
		var bid := bs.place("hollandais__maison", Vector2i(-30 + rr * 14, 20), rr)
		if bid >= 0 and Conversion.open_interior(mob, bid).ok:
			turned += 1
	_check(turned == 4, "ouverte dans les quatre orientations (%d/4)" % turned)
	var shop := bs.place("hollandais__boutique", Vector2i(30, 20), 0)
	var rs := Conversion.open_interior(mob, shop) if shop >= 0 else {"ok": false}
	_check(rs.ok and mob.usage_of(String(rs.id)) == "boutique", "une boutique s'ouvre aussi (rayons, réserve, logement au-dessus)")
	var church := bs.place("hollandais__culte", Vector2i(30, -40), 0)
	var rc := Conversion.open_interior(mob, church) if church >= 0 else {"ok": false}
	_check(church < 0 or (not rc.ok and bs.buildings.has(church)), "un lieu de culte ne s'ouvre pas et reste en place")
	for usage in ["logement", "ecole", "bureaux", "restaurant", "boutique"]:
		for dims in [[8, 7, 1], [10, 9, 3], [16, 12, 2], [5, 6, 2]]:
			var lv := Conversion.levels_for(usage, int(dims[0]), int(dims[1]), int(dims[2]))
			if lv.is_empty() or (lv[0].rooms as Array).size() < 2:
				_check(false, "plan d'étages %s %s" % [usage, str(dims)])

	print("Banque : bâtiment en murs fins :")
	var rp := BanqueModeles.save_plan(mob, pid, "Pignon meublé")
	_check(rp.ok, "maison en murs fins enregistrée")
	var mp := BanqueModeles.get_model(String(rp.id))
	_check(String(mp.genre) == "plan" and int(mp.etiquettes.pieces) >= 4 and (mp.blocs as Array).size() > 0, "murs, %d pièces, meubles et toit en blocs" % int(mp.etiquettes.pieces))
	var pp := BanqueModeles.place(String(rp.id), Vector2i(10, 50), 0, bs, mob)
	_check(pp.ok, "reposée ailleurs")
	if pp.ok:
		var np := String(pp.plan)
		_check(mob.pe.plans[np].walls.size() == mob.pe.plans[pid].walls.size(), "mêmes murs")
		_check((mob.items[np] as Dictionary).size() == (mob.items[pid] as Dictionary).size(), "mêmes meubles")
		_check(mob.plan_name(np) == "Pignon meublé", "nom du modèle")
	var bad := BanqueModeles.place(String(rp.id), Vector2i(10, 50), 0, bs, mob)
	_check(not bad.ok, "pas deux fois au même endroit")
	# Échange : un modèle exporté se réimporte.
	var copy := mp.duplicate(true)
	copy["id"] = "copie_test"
	_check(BanqueModeles.import_data(copy) == "copie_test" and BanqueModeles.count() == 3, "import d'un modèle reçu")
	var future := copy.duplicate(true)
	future["id"] = "futur"
	future["version"] = 99
	_check(BanqueModeles.import_data(future) == "", "un modèle d'une version plus récente est refusé")

	print("Bâtiments Blender :")
	var gid := "maison_normande"
	_check(Personnalisation.can_customize(gid) and not Personnalisation.can_shape(gid), "maison Blender : couleurs réglables, forme fixe")
	_check(Personnalisation.color_keys(gid).has("mur") and Personnalisation.color_keys(gid).has("toit_c"), "murs et toit réglables (%s)" % str(Personnalisation.color_keys(gid)))
	var g1 := bs.place(gid, Vector2i(60, -40), 0)
	var g2 := bs.place(gid, Vector2i(60, -20), 0)
	_check(g1 >= 0 and g2 >= 0, "deux maisons normandes posées")
	if g1 >= 0 and g2 >= 0:
		bs.set_perso(g1, {"mur": "3d6fa8", "toit_c": "2f6b4f"})
		var cols := (bs.node_of(g1).mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_COLOR] as PackedColorArray
		var cols0 := (bs.node_of(g2).mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_COLOR] as PackedColorArray
		_check(cols != cols0 and Personnalisation.color_of(gid, 0, bs.perso_of(g1), "mur").to_html(false) == "3d6fa8", "murs repeints en bleu")
		var vol := BibleGlb.volume(gid)
		_check(not vol.is_empty() and float(vol.w) > 6.0 and float(vol.w) < 16.0, "volume lu dans le modèle (%s)" % str(vol))
		_check(Conversion.can_open(gid), "la maison Blender s'ouvre")
		var rg := Conversion.open_interior(mob, g1)
		_check(rg.ok and not bs.buildings.has(g1), "intérieur ouvert : %s" % str(rg))
		if rg.ok:
			var gp := String(rg.id)
			_check(mob.plan_name(gp) == "Maison normande" and (mob.items.get(gp, {}) as Dictionary).size() > 8, "meublée, nom gardé")
	var nb_open := 0
	for id in BibleGlb.entries():
		if Conversion.can_open(String(id)):
			nb_open += 1
	_check(nb_open >= 40, "%d bâtiments Blender ouvrables" % nb_open)
	_check(not Conversion.can_open("cathedrale_gothique"), "une cathédrale ne s'ouvre pas")

	print("Vue par étage :")
	var rig: Node3D = scene.get_node("CameraRig")
	var bb0: Rect2i = mob.pe._bbox[pid]
	rig.global_position = Vector3(bb0.position.x + bb0.size.x / 2.0, rig.global_position.y, bb0.position.y + bb0.size.y / 2.0)
	mob.pe.set_tool(PlanEditor.Tool.NONE)
	var ve: VueEtages = scene.vue_etages
	ve.step(-1)
	mob.pe.flush()
	_check(ve.etage == 0 and not (mob.pe._nodes[pid][1] as Node3D).visible and (mob.pe._nodes[pid][0] as Node3D).visible,
		"Page bas : l'étage du haut disparaît")
	_check(scene.get_node("Blocs").clips.size() >= 1, "le toit est coupé aussi")
	ve.step(1)
	_check(ve.etage == -1 and (mob.pe._nodes[pid][1] as Node3D).visible and scene.get_node("Blocs").clips.is_empty(), "Page haut : tout revient")

	print("Panneaux :")
	var perso: PersoPanel = scene.perso_panel
	perso.edit(a)
	await process_frame
	_check(perso.is_open() and perso._body.get_child_count() > 20, "panneau Personnaliser (%d lignes)" % perso._body.get_child_count())
	var bp: BuildingPanel = scene.get_node("PanneauConstruction")
	scene.set_create_mode(true)
	bp.set_open(true)
	bp.show_category("banque")
	await process_frame
	_check(bp._item_buttons.size() >= 4, "onglet Banque de modèles")
	var hud: TerreHud = scene.hud
	_check(hud._cat_buttons.has("banque") and hud._cat_buttons.has("atelier"), "tuiles Banque et Atelier du mode Créer")
	_check(Icones.has_icon("banque") and Icones.has_icon("atelier"), "icônes Banque et Atelier")
	var pop: Population = scene.population
	bs.buildings[a]["chantier"] = false
	pop._sync_buildings()
	var hp: HabitantsPanel = scene.habitants_panel
	hp.set_open(true)
	hp.show_view("batiment", a)
	await process_frame
	var found := false
	for c in hp._body.get_children():
		if c is HBoxContainer:
			for bb in c.get_children():
				if bb is Button and (bb as Button).text == "Personnaliser":
					found = true
	_check(found, "bouton Personnaliser sur la fiche du bâtiment")

	print("ATELIER TEST OK" if ok else "ATELIER TEST ÉCHEC")
	quit(0 if ok else 1)
