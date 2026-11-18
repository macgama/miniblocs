extends SceneTree
## Test du zonage visible (2026-11-18) : le calque coloré épouse les pentes
## (dessus et flancs des cases, jamais sous le sol), il suit le relief quand
## le sol est redessiné, et le panneau Zonage montre des cartes de couleur,
## les jauges de la demande, le pinceau en main et un aperçu du style.
## Usage : godot --headless --path . --script res://tests/zonage_test.gd

var ok := true


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	if not cond:
		push_error("ÉCHEC : " + what)
		ok = false
	else:
		print("  ok  ", what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## Colline marquée : environ 1 m de dénivelé tous les 3 m.
func _colline(t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	for y in 256:
		for x in 256:
			a[y * 256 + x] = 80.0 + sin(float(t.x * 256 + x) * 0.035) * 30.0 + cos(float(t.y * 256 + y) * 0.03) * 25.0
	return a


func _run() -> void:
	BatimentsVie.chantiers = false
	var game: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = game.get_node("Terrain")
	root.add_child(game)
	world.tiles.offline_generator = _colline
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.set_origin(48.8584, 2.2945)
	await _frames(30)
	var zs: ZoneSystem = game.get_node("Zones")
	var bs: BuildingSystem = game.get_node("Batiments")
	bs.unlimited_money = true
	zs.growth = false

	print("Calque sur la pente :")
	var rect := Rect2i(-20, -20, 24, 24)
	var hs := world.cell_heights(rect)
	var marches := 0
	for j in rect.size.y:
		for i in rect.size.x - 1:
			if hs[i + j * rect.size.x] != hs[i + 1 + j * rect.size.x]:
				marches += 1
	_check(marches > 20, "le terrain d'essai a des marches (%d)" % marches)
	var v := zs.calque_relief(rect)
	_check(v.size() % 3 == 0 and v.size() > 0, "le calque a des triangles (%d sommets)" % v.size())
	# Surface des dessus = toutes les cases ; aucun sommet sous le sol de sa case.
	var aire_dessus := 0.0
	var flancs := 0
	var sous_le_sol := 0
	for t in range(0, v.size(), 3):
		var a := v[t]
		var b := v[t + 1]
		var c := v[t + 2]
		var n := (b - a).cross(c - a)
		if absf(n.y) > 0.0001:
			aire_dessus += absf(n.y) / 2.0
			var cell := Vector2i(floori((a.x + b.x + c.x) / 3.0), floori((a.z + b.z + c.z) / 3.0))
			if a.y < world.cell_height(cell) - 0.001:
				sous_le_sol += 1
		elif n.length() > 0.0001:
			flancs += 1
	_check(is_equal_approx(aire_dessus, float(rect.size.x * rect.size.y)), "les dessus couvrent les %d cases (%.0f m²)" % [rect.size.x * rect.size.y, aire_dessus])
	_check(sous_le_sol == 0, "aucun dessus sous le sol (%d)" % sous_le_sol)
	_check(flancs >= marches, "les flancs des marches sont colorés aussi (%d triangles)" % flancs)

	print("Zones peintes :")
	var id := zs.add_zone("R", rect)
	_check(id > 0, "zone résidentielle peinte sur la pente")
	zs._rebuild_dirty_views(INF)
	var holder: Node3D = zs._views.get(id)
	_check(holder != null and holder.get_child_count() > 0, "calque créé")
	var mi := holder.get_child(0) as MeshInstance3D if holder != null and holder.get_child_count() > 0 else null
	var mat := mi.material_override as ShaderMaterial if mi != null else null
	_check(mat != null and mat.shader != null and mat.shader.resource_path.ends_with("zone_calque.gdshader"), "calque dessiné par le shader qui l'avance vers la caméra")
	world.chunk_rebuilt.emit(Vector2i(-1, -1))
	_check(zs._dirty_views.has(id), "sol redessiné → le calque de la zone est refait")
	zs._rebuild_dirty_views(INF)

	print("Panneau Zonage :")
	var panel: BuildingPanel = game.build_panel
	panel.set_open(true)
	panel.show_category("zones")
	await _frames(3)
	_check(panel._zone_cartes.size() == 4, "4 cartes : Résidentielle, Commerciale, Industrielle, Retirer")
	for k in ["R", "C", "I", "X"]:
		var b: Button = panel._zone_cartes.get(k)
		_check(b != null and b.name == "Zone" + k, "carte %s nommée « Zone%s » (pour les bulles d'aide)" % [k, k])
	_check(panel._zone_jauges.size() == 3, "3 jauges de demande")
	panel.choisir_zone("C")
	await _frames(1)
	_check(zs.mode == ZoneSystem.Mode.PAINT and zs.kind == "C", "carte Commerciale → pinceau commercial en main")
	_check((panel._zone_cartes["C"] as Button).button_pressed, "la carte choisie reste enfoncée")
	_check(panel._zone_pinceau.text.contains("Commerciale"), "l'encadré du pinceau le dit : %s" % panel._zone_pinceau.text)
	panel.choisir_zone("X")
	await _frames(1)
	_check(zs.mode == ZoneSystem.Mode.REMOVE, "carte Retirer → gomme en main")
	zs.set_inactive()
	await _frames(1)
	var enfoncees := 0
	for k in panel._zone_cartes:
		if (panel._zone_cartes[k] as Button).button_pressed:
			enfoncees += 1
	_check(enfoncees == 0, "clic droit (pinceau reposé) → aucune carte enfoncée")
	_check(panel._zone_pinceau.text.contains("Aucun pinceau"), "l'encadré invite à choisir une carte")
	panel.set_zone_info(zs.summary())
	var d := zs.demand()
	var jr: ProgressBar = panel._zone_jauges["R"][0]
	_check(is_equal_approx(jr.value, ZoneSystem.jauge_demande(float(d.R))), "jauge résidentielle = demande (%.2f)" % jr.value)
	_check(ZoneSystem.jauge_demande(-5.0) == 0.0 and ZoneSystem.jauge_demande(1000.0) == 1.0, "jauge vide sans demande, pleine au maximum")
	_check(panel._zone_label.text.contains("576"), "surface déjà zonée affichée : %s" % panel._zone_label.text)

	print("Aperçu du style :")
	_check(panel._zone_apercus.get_child_count() == 3, "3 vignettes d'exemple (R, C, I)")
	for k in ["R", "C", "I"]:
		var ex := BuildingPanel.exemple_de_style(k, "")
		_check(ex != "" and ZoneSystem.types_for(k, "").has(ex), "exemple %s du style classique : %s" % [k, ex])
	var sid: String = Styles.STYLES.keys()[0]
	var ex_s := BuildingPanel.exemple_de_style("R", sid)
	_check(ex_s != "" and ZoneSystem.types_for("R", sid).has(ex_s), "exemple résidentiel du style %s : %s" % [sid, ex_s])

	print("Pinceau sur la pente :")
	zs.set_paint("R")
	zs._cursor_valid = true
	zs._drag = true
	zs._drag_start = rect.position
	zs._cursor = rect.end - Vector2i.ONE
	zs._update_box()
	var hmin := INF
	var hmax := -INF
	for h in hs:
		hmin = minf(hmin, h)
		hmax = maxf(hmax, h)
	var box := zs._box.mesh as BoxMesh
	var bas := zs._box.position.y - box.size.y / 2.0
	var haut := zs._box.position.y + box.size.y / 2.0
	_check(zs._box.visible and bas <= hmin + 0.01 and haut >= hmax, "le cadre du pinceau englobe la pente (%.1f → %.1f m)" % [hmin, hmax])
	_check((zs._box.material_override as StandardMaterial3D).no_depth_test, "le cadre reste visible derrière le relief")
	zs.set_inactive()

	print("ZONAGE TEST " + ("OK" if ok else "ÉCHEC"))
	quit(0 if ok else 1)
