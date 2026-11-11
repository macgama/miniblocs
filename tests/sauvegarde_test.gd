extends SceneTree
## Test de la sauvegarde des parties (format 2), sans réseau.
## Usage : godot --headless --path . --script res://tests/sauvegarde_test.gd

var ok := true


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	if not cond:
		push_error("ÉCHEC : " + what)
		ok = false
	else:
		print("  ok  ", what)


func _flat_tile(t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	for y in 256:
		for x in 256:
			a[y * 256 + x] = 40.0 + sin((t.x * 256 + x) * 0.05) * 1.5
	return a


func _run() -> void:
	# On travaille dans un dossier de test pour ne pas toucher aux vraies parties.
	print("Codage du terrain :")
	var mods := {Vector2i(0, 0): 12.5, Vector2i(-1, -1): -3.0, Vector2i(63, 64): 1234.25, Vector2i(-130, 70): 0.5}
	var enc := SaveGame.encode_cells(mods)
	_check((enc.blocs as Dictionary).size() == 4, "cases rangées par blocs de 64 m (%d blocs)" % (enc.blocs as Dictionary).size())
	var dec := SaveGame.decode_cells(enc)
	_check(dec == mods, "cases relues à l'identique")
	var v1 := {"version": 1, "lat": 45.9, "lon": 6.13, "modifications": [[1, 2, 3.5], [-5, 7, 8.0]]}
	var mig := SaveGame.migrate_section("terrain", 1, v1)
	_check(int(mig.version) == 2 and SaveGame.decode_cells(mig.modifs) == {Vector2i(1, 2): 3.5, Vector2i(-5, 7): 8.0}, "ancien terrain (format 1) converti")
	_check(SaveGame.make_slot_id("Genève (rade)").begins_with("geneve-rade-"), "nom de dossier lisible (%s)" % SaveGame.make_slot_id("Genève (rade)"))

	print("Partie complète :")
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var zs: ZoneSystem = scene.get_node("Zones")
	var be: BlockEditor = scene.get_node("Blocs")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.set_origin(48.8584, 2.2945)
	GameStart.place_name = "Test sauvegarde"
	for i in 60:
		await process_frame
	bs.unlimited_money = true
	var y := world.cell_height(Vector2i(0, 0))
	_check(transport.build_segment("route", Vector3(-80, y, 0), Vector3(80, y, 0)).ok, "route posée")
	var bid := bs.place("maison", Vector2i(0, 14), bs.best_rotation("maison", Vector2i(0, 14)))
	_check(bid >= 0, "maison posée")
	zs.add_zone("R", Rect2i(-60, -60, 50, 40))
	var gy := roundi(maxf(world.cell_height(Vector2i(30, 30)), 0.0) / BlockEditor.UNIT_Y)
	be.place_blocks([Vector3i(30, gy, 30), Vector3i(31, gy, 30)], 5)
	world.set_tool(TerrainWorld.Tool.RAISE)
	world.apply_tool(Vector2i(-40, 30), Vector2i(-38, 32))
	var n_mods := world.modifications.size()
	var n_edges := transport.network.edges.size()
	var raised := world.cell_height(Vector2i(-39, 31))

	var title := "Test auto %d" % randi()
	_check(scene.save_game(SaveGame.make_slot_id(title), title), "sauvegarde écrite (%s)" % scene.last_error)
	var slot := GameStart.slot_id
	var m := SaveGame.read_manifest(slot)
	_check(m.get("format") == SaveGame.FORMAT and int(m.version) == SaveGame.VERSION, "fiche de partie au format %d" % SaveGame.VERSION)
	_check((m.sections as Dictionary).has_all(["terrain", "transport", "batiments", "zones", "blocs", "ambiance"]), "six sections")
	_check(String(m.get("partie_id", "")).length() == 32 and String(m.get("auteur", "")).length() == 32, "identifiants de partie et de joueur")
	_check(int(m.resume.batiments) == 1, "résumé dans la fiche")
	var listed := false
	for s in SaveGame.list_saves():
		listed = listed or s.id == slot
	_check(listed, "la partie apparaît dans la liste")

	# Deuxième sauvegarde au même endroit : même partie, compteur incrémenté.
	_check(scene.save_game(), "sauvegarde à nouveau dans la même partie")
	var m2 := SaveGame.read_manifest(slot)
	_check(m2.partie_id == m.partie_id and int(m2.sauvegardes) == 2, "même identifiant de partie, 2 sauvegardes")

	# On change de région (tout est vidé), puis on recharge.
	world.set_origin(45.9, 6.13)
	for i in 5:
		await process_frame
	_check(transport.network.edges.is_empty() and bs.buildings.is_empty() and world.modifications.is_empty(), "nouvelle région vierge")
	_check(scene.load_game(slot), "chargement (%s)" % scene.last_error)
	_check(is_equal_approx(world.origin_lat, 48.8584) and is_equal_approx(world.origin_lon, 2.2945), "lieu restauré")
	_check(world.modifications.size() == n_mods and world.cell_height(Vector2i(-39, 31)) == raised, "terrain modifié restauré (%d cases)" % world.modifications.size())
	_check(transport.network.edges.size() == n_edges, "réseau restauré")
	_check(bs.buildings.size() == 1 and zs.zones.size() == 1 and be.blocks.size() == 2, "bâtiment, zone et blocs restaurés")
	_check(GameStart.slot_id == slot and GameStart.place_name == "Test sauvegarde", "partie en cours retrouvée")

	# Section abîmée : signalée, le reste se charge.
	var path := SaveGame.DIR.path_join(slot).path_join("zones.json.zst")
	var f := FileAccess.open_compressed(path, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	f.store_string("{\"abime\": true}")
	f.close()
	var res := SaveGame.read(slot)
	_check(res.ok and not (res.sections as Dictionary).has("zones") and (res.warnings as Array).size() == 1, "section abîmée détectée, le reste est lisible")

	# Ancienne sauvegarde unique (format 1) importée.
	var legacy := FileAccess.open(SaveGame.LEGACY_PATH, FileAccess.WRITE)
	legacy.store_string(JSON.stringify(v1))
	legacy.close()
	var imported := SaveGame.import_legacy()
	_check(imported != "" and SaveGame.read(imported).ok and not FileAccess.file_exists(SaveGame.LEGACY_PATH), "ancienne sauvegarde importée")

	_check(SaveGame.delete(slot) and not SaveGame.exists(slot), "suppression")
	if imported != "":
		SaveGame.delete(imported)
	DirAccess.remove_absolute(SaveGame.LEGACY_PATH + ".bak")

	print("SAUVEGARDE TEST OK" if ok else "SAUVEGARDE TEST ÉCHEC")
	quit(0 if ok else 1)
