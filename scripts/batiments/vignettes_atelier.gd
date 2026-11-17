class_name VignettesAtelier
extends RefCounted
## Maquettes 3D des vignettes de l'atelier : un pan de mur avec sa porte ou sa
## fenêtre, une forme de bloc, une petite maison sous chaque toit. Rendues par
## Vignettes (une par image), puis gardées en mémoire.

const WALL_MAT := 74 # enduit à la chaux
const FLOOR_MAT := 2 # bois

## Rangement des portes et fenêtres des murs fins dans les onglets du panneau.
const OPENING_TABS := [
	["portes", "Portes", ["porte", "porte_vitree", "porte_fenetre", "porte_entree", "porte_cintree", "porte_double", "porte_balcon", "porte_grange", "porte_garage", "porte_fenetre_volets"]],
	["fenetres", "Fenêtres", ["fenetre", "fenetre_volets", "fenetre_petits_bois", "fenetre_cintree", "fenetre_gothique", "oeil_de_boeuf", "fenetre_haute", "meurtriere",
		"fenetre_cintree_volets", "fenetre_ogive", "fenetre_balconnet", "fenetre_store", "fenetre_haute_volets", "hublot"]],
	["baies", "Baies et vitrines", ["baie", "baie_coulissante", "mur_rideau", "fenetre_atelier", "bandeau", "vitrine", "vitrine_store", "baie_balconnet"]],
	["passages", "Passages", ["passage", "arcade", "arcade_brisee", "claustra"]],
]

## Matériau de démonstration d'une forme de bloc, selon sa famille.
const SHAPE_MAT := {"formes": 16, "toits": 7, "arrondis": 63, "details": 74, "ouvertures": 74, "grandes": 63}


static func opening_mesh(kind: String) -> ArrayMesh:
	var pe := PlanEditor.new()
	pe.material = WALL_MAT
	var o: Dictionary = PlanEditor.OPENINGS[kind]
	var n := 2 if o.get("large", false) else 1
	var wcode := BlocFormes.encode(WALL_MAT)
	var om := pe._opening_material(kind)
	var p := {"y0": 0.0, "walls": {}, "floors": {}, "stairs": {}}
	# Juste le pan de mur de l'ouverture : elle remplit la vignette.
	for x in n:
		p.walls[Vector4i(x, 0, 0, 0)] = {"a": wcode, "b": wcode, "o": kind, "om": om, "op": false}
		p.floors[Vector3i(x, 0, -1)] = {"t": BlocFormes.encode(FLOOR_MAT), "u": wcode}
	pe.plans["v"] = p
	var m := BlocMesher.new()
	pe.emit_storey("v", 0, m, m, PackedVector3Array())
	pe.free()
	return m.to_mesh()


static func shape_mesh(sh: int) -> ArrayMesh:
	var info: Dictionary = BlocFormes.INFO[sh]
	var mat := int(SHAPE_MAT.get(String(info.fam), 16))
	if sh == BlocFormes.S.P_DOME or sh == BlocFormes.S.P_ONION:
		mat = 47
	elif sh == BlocFormes.S.P_CONE or sh == BlocFormes.S.P_SPIRE:
		mat = 8
	elif String(info.name).begins_with("Porte"):
		mat = 3
	var code := BlocFormes.encode(mat, sh, 2)
	if BlocFormes.is_piece(sh):
		code = BlocFormes.encode_part(code, Vector3i.ZERO, 4)
	var cells := BlockEditor.expand(Vector3i.ZERO, code)
	var m := BlocMesher.new()
	for k in cells:
		var kk: Vector3i = k
		BlocFormes.emit(m, int(cells[kk]), Vector3(kk.x * BlockEditor.SIZE, kk.y * BlockEditor.UNIT_Y, kk.z * BlockEditor.SIZE),
			func(off: Vector3i) -> int: return int(cells.get(kk + off, -1)))
	return m.to_mesh()


static func roof_mesh(kind: String) -> ArrayMesh:
	var pe := PlanEditor.new()
	pe.material = WALL_MAT
	var wcode := BlocFormes.encode(WALL_MAT)
	var rect := Rect2i(0, 0, 6, 5)
	var p := {"y0": 0.0, "walls": {}, "floors": {}, "stairs": {}}
	for k in PlanEditor.room_walls(rect, 0):
		p.walls[k] = {"a": wcode, "b": wcode, "o": "", "om": 0, "op": false}
	for x in rect.size.x:
		for z in rect.size.y:
			p.floors[Vector3i(x, 0, z)] = {"t": BlocFormes.encode(FLOOR_MAT), "u": wcode}
	# Une porte et deux fenêtres sur la façade.
	var om := BlocFormes.encode(PlanEditor.FRAME_MAT)
	for d in [[2, "porte"], [0, "fenetre_volets"], [4, "fenetre_volets"]]:
		var kw := Vector4i(int(d[0]), 0, rect.end.y, 0)
		if p.walls.has(kw):
			p.walls[kw].o = d[1]
			p.walls[kw].om = BlocFormes.encode(PlanEditor.DOOR_MAT) if d[1] == "porte" else om
	pe.plans["v"] = p
	var m := BlocMesher.new()
	pe.emit_storey("v", 0, m, m, PackedVector3Array())
	var roof_mat := int(PlanEditor.ROOF_DEFAULT_MAT.get(kind, 7))
	var groups := pe._roof_groups(kind, rect.position, rect.end - Vector2i.ONE, 1, roundi(PlanEditor.H / BlockEditor.UNIT_Y), roof_mat, WALL_MAT)
	pe.free()
	var cells := {}
	for code in groups:
		for key in groups[code]:
			var parts := BlockEditor.expand(key, int(code))
			for kp in parts:
				cells[kp] = parts[kp]
	for k in cells:
		var kk: Vector3i = k
		BlocFormes.emit(m, int(cells[kk]), Vector3(kk.x * BlockEditor.SIZE, kk.y * BlockEditor.UNIT_Y, kk.z * BlockEditor.SIZE),
			func(off: Vector3i) -> int: return int(cells.get(kk + off, -1)))
	return m.to_mesh()


## Bassin, voie, gradins ou terrain à la taille du modèle (gradins un peu courts).
static func amenagement_mesh(kind: String) -> ArrayMesh:
	var pe := PlanEditor.new()
	var k: Dictionary = Amenagements.KINDS[kind]
	# Vue de face (la caméra des vignettes regarde depuis +z) : terrains et
	# bassins en long, gradins qui montent en s'éloignant.
	var front := String(k.fam) == "gradins" or kind == "butoir"
	var r := 2 if front else 1
	var s := Amenagements.default_size(kind, 0 if front else 1)
	# Les voies et quais en tronçon court : on voit les traverses.
	if String(k.fam) == "rails" and kind != "butoir":
		s.x = mini(s.x, 10)
	var p := {"y0": 0.0, "walls": {}, "floors": {}, "stairs": {}, "am": {}}
	p.am[Vector3i(0, 0, 0)] = {"k": kind, "w": s.x, "d": s.y, "r": r, "m": -1}
	pe.plans["v"] = p
	var m := BlocMesher.new()
	pe.emit_storey("v", 0, m, m, PackedVector3Array())
	pe.free()
	var mesh := m.to_mesh()
	# Terrains, bassins et voies sont plats : on les incline vers la caméra.
	if String(k.fam) != "gradins" and kind != "butoir" and kind != "aquarium":
		mesh = _tilted(mesh, deg_to_rad(38.0))
	return mesh


## Copie du maillage tournée autour de l'axe x (le fond se relève).
static func _tilted(mesh: ArrayMesh, angle: float) -> ArrayMesh:
	var b := Basis(Vector3.RIGHT, angle)
	var out := ArrayMesh.new()
	for si in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(si)
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i in v.size():
			v[i] = b * v[i]
			n[i] = b * n[i]
		arrays[Mesh.ARRAY_VERTEX] = v
		arrays[Mesh.ARRAY_NORMAL] = n
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.surface_set_material(si, mesh.surface_get_material(si))
	return out
