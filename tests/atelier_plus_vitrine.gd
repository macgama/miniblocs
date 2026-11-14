extends SceneTree
## Vitrine des ajouts de l'atelier : grandes pièces arrondies, petites formes
## et détails, nouvelles portes et fenêtres, nouveaux toits, nouveaux matériaux.
## Usage (avec affichage) :
##   godot --path . --script res://tests/atelier_plus_vitrine.gd -- --screenshot a.png --vue pieces|formes|ouvertures|toits|materiaux|chapelle


func _initialize() -> void:
	_run.call_deferred()


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


var be: BlockEditor
var gy := 0


func _piece(sh: int, mat: int, c: Vector2i, d: int, n := 1, y := -1, rot := 0, tint := 0) -> void:
	be.material = mat
	be.shape = sh
	be.tint = tint
	be.rot_offset = 0
	be.set_piece(d, n)
	var code := BlocFormes.encode_part(BlocFormes.encode(mat, sh, rot, tint), Vector3i.ZERO, d)
	be.place_blocks(be.piece_anchors(Vector3i(c.x, gy if y < 0 else y, c.y), code), code)


func _blk(sh: int, mat: int, k: Vector3i, rot := 0, tint := 0) -> void:
	be.place_blocks([k], BlocFormes.encode(mat, sh, rot, tint))


func _column(mat: int, x: int, z: int, h: int, y0 := -1) -> void:
	var keys := []
	for i in h:
		keys.append(Vector3i(x, (gy if y0 < 0 else y0) + i * BlockEditor.HU, z))
	be.place_blocks(keys, BlocFormes.encode(mat, BlocFormes.S.FULL))


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var shot := "atelier_plus.png"
	var vue := "pieces"
	var famille := ""
	var depuis := 58
	for i in args.size():
		if args[i] == "--screenshot" and i + 1 < args.size():
			shot = args[i + 1]
		if args[i] == "--vue" and i + 1 < args.size():
			vue = args[i + 1]
		if args[i] == "--famille" and i + 1 < args.size():
			famille = args[i + 1]
		if args[i] == "--depuis" and i + 1 < args.size():
			depuis = int(args[i + 1])
	root.msaa_3d = Viewport.MSAA_DISABLED
	root.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
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
	var amb: DayNight = scene.get_node("Ambiance")
	amb.set_speed(0)
	bs.unlimited_money = true
	bs.require_access = false
	be = scene.get_node("Blocs")
	var pe: PlanEditor = scene.get_node("Plans")
	var rig = scene.get_node("CameraRig")
	gy = roundi(world.cell_height(Vector2i(0, 0)) / BlockEditor.UNIT_Y)
	var S := BlocFormes.S
	var hu := BlockEditor.HU
	var look := Vector3(0, 0, 0)
	var dist := 50.0
	var yaw := 0.0
	var pitch := 30.0
	match vue:
		"pieces":
			# Église à coupole sur tambour, tour ronde à toit conique, bulbe, flèche…
			_piece(S.P_CYL, 16, Vector2i(-30, 0), 10, 4)
			_piece(S.P_DOME, 47, Vector2i(-30, 0), 10, 1, gy + 4 * hu)
			_blk(S.FINIAL, 48, Vector3i(-30, gy + 9 * hu, 0))
			_piece(S.P_TOWER, 17, Vector2i(-15, 0), 6, 9)
			_piece(S.P_CONE, 8, Vector2i(-15, 0), 6, 1, gy + 9 * hu)
			_piece(S.P_TOWER, 5, Vector2i(-4, 0), 6, 6, -1, 0, 0)
			_piece(S.P_ONION, 42, Vector2i(-4, 0), 6, 1, gy + 6 * hu)
			_piece(S.P_CYL, 67, Vector2i(6, 0), 4, 10)
			_piece(S.P_SPIRE, 46, Vector2i(6, 0), 4, 1, gy + 10 * hu)
			_piece(S.P_PYRAMID, 67, Vector2i(18, 0), 10)
			# Aqueduc : grandes arches sur piliers.
			for i in 4:
				var x := -34 + i * 7
				_column(16, x, 14, 4)
				_column(16, x, 15, 4)
			for i in 3:
				_piece(S.P_ARCH, 16, Vector2i(-34 + i * 7 + 4, 15), 6, 2, gy + 4 * hu, 0)
			_piece(S.P_GOTHIC, 63, Vector2i(0, 15), 6, 1)
			_piece(S.P_VAULT, 46, Vector2i(14, 15), 8, 6)
			_piece(S.P_HALFDOME, 63, Vector2i(28, 15), 8)
			look = Vector3(-4, 4, 6)
			dist = 62.0
			yaw = 200.0
			pitch = 24.0
		"formes":
			var shapes := [S.ROUND_OUT, S.ROUND_IN, S.CYLINDER, S.HALF_ROUND, S.CURVE_UP, S.CURVE_IN, S.DOME_SMALL, S.SPHERE,
				S.CONE_SMALL, S.FINIAL, S.ARCH_SMALL, S.ARCH_HALF, S.CORNICE, S.CRENEL, S.BALUSTRADE, S.CHIMNEY,
				S.DORMER, S.AWNING, S.BALCONY, S.LATTICE, S.OCULUS, S.WINDOW_ARCH, S.WINDOW_GOTHIC, S.WINDOW_GRID, S.SLIT, S.DOOR_ARCH, S.DOOR_BARN]
			var mats := [16, 16, 63, 7, 46, 89, 47, 20, 8, 48, 63, 63, 74, 17, 16, 0, 8, 113, 70, 82, 74, 74, 63, 105, 17, 3, 34]
			for i in shapes.size():
				var col := i % 9
				var row := i / 9
				var k := Vector3i(-12 + col * 3, gy, -row * 4)
				# Petit socle pour les détails qui se posent en hauteur.
				_blk(shapes[i], mats[i], k, 2, 4 if shapes[i] == S.AWNING else 0)
			look = Vector3(0, 1, -4)
			dist = 26.0
			yaw = 0.0
			pitch = 32.0
		"ouvertures", "chapelle":
			var y0 := pe.ground_level(Vector2i(0, 0))
			var id := pe.new_plan(y0)
			pe.material = 74
			pe.add_room(id, Rect2i(-10, 0, 20, 8), 0, 2)
			var kinds := ["porte_entree", "fenetre_volets", "porte_cintree", "fenetre_cintree", "fenetre_gothique", "oeil_de_boeuf",
				"fenetre_petits_bois", "meurtriere", "porte_balcon", "claustra", "arcade", "porte_grange", "porte_grange",
				"vitrine_store", "vitrine_store", "porte_double", "porte_double", "fenetre_haute", "baie"]
			for i in kinds.size():
				pe.set_opening_at(id, Vector4i(-10 + i, 0, 0, 0), kinds[i])
			var up := ["porte_balcon", "fenetre_atelier", "fenetre_atelier", "fenetre_atelier", "bandeau", "bandeau", "bandeau",
				"mur_rideau", "mur_rideau", "mur_rideau", "oeil_de_boeuf", "fenetre_gothique", "fenetre_cintree", "porte_garage",
				"porte_garage", "porte_garage", "baie_coulissante", "baie_coulissante", "fenetre_volets"]
			for i in up.size():
				pe.set_opening_at(id, Vector4i(-10 + i, 1, 0, 0), up[i])
			pe.material = 89
			pe.add_roof(id, "mansarde")
			look = Vector3(0, 3.5, 0)
			dist = 26.0
			yaw = 180.0
			pitch = 12.0
			if vue == "chapelle":
				# Chapelle : nef voûtée, fenêtres gothiques, tour ronde et coupole.
				pe.clear()
				be.clear()
				var id2 := pe.new_plan(y0)
				pe.material = 63
				pe.add_room(id2, Rect2i(-4, 0, 8, 16), 0, 2)
				for z in [2, 4, 6, 8, 10, 12, 14]:
					pe.set_opening_at(id2, Vector4i(-4, 0, z, 1), "fenetre_gothique")
					pe.set_opening_at(id2, Vector4i(4, 0, z, 1), "fenetre_gothique")
					pe.set_opening_at(id2, Vector4i(-4, 1, z, 1), "oeil_de_boeuf")
					pe.set_opening_at(id2, Vector4i(4, 1, z, 1), "oeil_de_boeuf")
				pe.set_opening_at(id2, Vector4i(-1, 0, 0, 0), "porte_cintree")
				pe.set_opening_at(id2, Vector4i(0, 0, 0, 0), "porte_cintree")
				pe.set_opening_at(id2, Vector4i(-1, 1, 0, 0), "oeil_de_boeuf")
				pe.set_opening_at(id2, Vector4i(0, 1, 0, 0), "fenetre_gothique")
				pe.material = 46
				pe.add_roof(id2, "voute")
				var ty := roundi(y0 / BlockEditor.UNIT_Y)
				_piece(S.P_TOWER, 63, Vector2i(-7, 2), 5, 14, ty)
				_piece(S.P_SPIRE, 87, Vector2i(-7, 2), 5, 1, ty + 14 * hu)
				_piece(S.P_HALFDOME, 63, Vector2i(0, 17), 8, 1, ty, 0)
				look = Vector3(0, 5, 6)
				dist = 40.0
				yaw = 215.0
				pitch = 20.0
		"toits":
			var y1 := pe.ground_level(Vector2i(0, 0))
			var i := 0
			for r in PlanEditor.ROOFS:
				var col := i % 4
				var row := i / 4
				var rect := Rect2i(-30 + col * 16, -row * 16, 9, 7)
				var id3 := pe.new_plan(y1)
				pe.material = [74, 59, 5, 70, 65, 72, 92, 16, 63, 75, 17, 67][i]
				pe.add_room(id3, rect, 0, 1)
				pe.set_opening_at(id3, Vector4i(rect.position.x + 4, 0, rect.end.y, 0), "porte_entree")
				pe.set_opening_at(id3, Vector4i(rect.position.x + 2, 0, rect.end.y, 0), "fenetre_volets")
				pe.set_opening_at(id3, Vector4i(rect.position.x + 6, 0, rect.end.y, 0), "fenetre_volets")
				pe.material = 5
				pe.add_roof(id3, String(r[0]))
				i += 1
			look = Vector3(-6, 2, -14)
			dist = 75.0
			yaw = 0.0
			pitch = 34.0
		"panneau":
			# Panneau de droite : vignettes des matériaux, devant une petite place.
			var mats := []
			for j in BlocMateriaux.LIST.size():
				if famille == "" or String(BlocMateriaux.LIST[j].fam) == famille:
					mats.append(j)
			for j in mini(mats.size(), 40):
				var col := j % 8
				var row := j / 8
				for h in 2:
					be.place_blocks([Vector3i(-12 + col * 3, gy + h * hu, -row * 3)], BlocFormes.encode(mats[j]))
					be.place_blocks([Vector3i(-12 + col * 3 + 1, gy + h * hu, -row * 3)], BlocFormes.encode(mats[j]))
			var bp: BuildingPanel = scene.get_node("PanneauConstruction")
			scene.set_create_mode(true)
			bp.set_open(true)
			bp._block_mode = "blocs"
			bp._mat_family = famille
			if not mats.is_empty():
				bp._block_material = mats[0]
			bp.show_category("blocs")
			await process_frame
			# Faire défiler le panneau jusqu'aux matériaux.
			var sc: ScrollContainer = bp._list.get_parent()
			await process_frame
			for c in bp._list.get_children():
				if c is LineEdit:
					sc.scroll_vertical = int((c as Control).position.y) - 70
			look = Vector3(-6, 1, -5)
			dist = 30.0
			yaw = 0.0
			pitch = 30.0
		"materiaux":
			var first := depuis
			var n := mini(BlocMateriaux.LIST.size() - first, 150)
			for j in n:
				var col := j % 15
				var row := j / 15
				for h in 2:
					be.place_blocks([Vector3i(-15 + col * 2, gy + h * hu, -row * 3)], BlocFormes.encode(first + j))
					be.place_blocks([Vector3i(-15 + col * 2 + 1, gy + h * hu, -row * 3)], BlocFormes.encode(first + j))
			look = Vector3(0, 1, -5)
			dist = 30.0
			yaw = 0.0
			pitch = 30.0
	pe.flush()
	rig.position = look
	rig._distance = dist
	rig._target_distance = dist
	rig.rotation_degrees.y = yaw
	if "pitch_degrees" in rig:
		rig.pitch_degrees = pitch
	for i in 90:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(shot)
	print("Capture : ", shot)
	quit(0)
