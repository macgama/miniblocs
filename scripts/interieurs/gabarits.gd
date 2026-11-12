class_name Gabarits
extends RefCounted
## Bâtiments meublés prêts à visiter : maison, immeuble, école, boutique,
## bureaux, café. Ils sont construits avec l'éditeur de murs (vrais murs de
## 20 cm, portes qui s'ouvrent avec E, fenêtres, escaliers, toit), puis
## meublés pièce par pièce dans le style choisi.
##
## Coordonnées locales : sommets de la grille de 0 à w (x) et de 0 à d (z),
## façade d'entrée sur z = 0. levels : un étage par entrée, avec
## rooms [x, z, w, d, fonction] (la première est l'enveloppe), walls
## [x0, z0, x1, z1] (cloisons), openings [x0, z0, x1, z1, genre] (un segment
## d'un mètre), stairs [x, z, direction] (direction de PlanEditor.STAIR_DIRS).

const _HALL_A := [1, 1, 3] # escalier vers +x sur la rangée z = 1
const _HALL_B := [4, 2, 1] # escalier vers −x sur la rangée z = 2

const KINDS := {
	"maison": {"name": "Maison familiale", "w": 10, "d": 8, "usage": "logement", "roof": "deux_pans", "budget": 160_000,
		"desc": "Deux niveaux : séjour, cuisine, salle d'eau en bas ; deux chambres et une salle de bains en haut.",
		"levels": [
			{"rooms": [[0, 0, 10, 8, ""], [0, 0, 6, 3, "entree"], [6, 0, 4, 3, "sdb"], [0, 3, 6, 5, "sejour"], [6, 3, 4, 5, "cuisine"]],
				"walls": [[0, 3, 10, 3], [6, 0, 6, 8]],
				"openings": [[5, 0, 6, 0, "porte"], [2, 0, 3, 0, "fenetre"], [8, 0, 9, 0, "fenetre_haute"], [6, 2, 6, 3, "porte"],
					[4, 3, 5, 3, "passage"], [6, 6, 6, 7, "passage"], [1, 8, 2, 8, "fenetre"], [3, 8, 4, 8, "porte_fenetre"],
					[0, 5, 0, 6, "fenetre"], [8, 8, 9, 8, "fenetre"], [10, 5, 10, 6, "fenetre"]],
				"stairs": [_HALL_A]},
			{"rooms": [[0, 0, 10, 8, ""], [0, 0, 6, 3, "entree"], [6, 0, 4, 3, "sdb"], [0, 3, 5, 5, "chambre"], [5, 3, 5, 5, "enfant"]],
				"walls": [[0, 3, 10, 3], [6, 0, 6, 3], [5, 3, 5, 8]],
				"openings": [[6, 1, 6, 2, "porte"], [1, 3, 2, 3, "porte"], [5, 3, 6, 3, "porte"], [2, 0, 3, 0, "fenetre"],
					[8, 0, 9, 0, "fenetre_haute"], [2, 8, 3, 8, "fenetre"], [0, 5, 0, 6, "fenetre"], [7, 8, 8, 8, "fenetre"], [10, 5, 10, 6, "fenetre"]],
				"stairs": []},
		]},
	"immeuble": {"name": "Immeuble de quatre appartements", "w": 12, "d": 10, "usage": "logement", "roof": "plat", "budget": 420_000,
		"desc": "Quatre niveaux, un appartement par étage (séjour, cuisine, chambre, salle de bains), cage d'escalier.",
		"levels": "immeuble"},
	"ecole": {"name": "École de deux classes", "w": 16, "d": 12, "usage": "ecole", "roof": "deux_pans", "budget": 220_000,
		"desc": "Un couloir, deux salles de classe avec pupitres et tableau, des toilettes.",
		"levels": [
			{"rooms": [[0, 0, 16, 12, ""], [0, 0, 16, 3, "entree"], [0, 3, 8, 9, "classe"], [8, 3, 6, 9, "classe"], [14, 3, 2, 9, "sdb"]],
				"walls": [[0, 3, 16, 3], [8, 3, 8, 12], [14, 3, 14, 12]],
				"openings": [[7, 0, 8, 0, "porte_vitree"], [2, 0, 3, 0, "fenetre"], [12, 0, 13, 0, "fenetre"], [6, 3, 7, 3, "porte"], [9, 3, 10, 3, "porte"],
					[14, 3, 15, 3, "porte"], [1, 12, 2, 12, "fenetre"], [3, 12, 4, 12, "fenetre"], [5, 12, 6, 12, "fenetre"],
					[9, 12, 10, 12, "fenetre"], [11, 12, 12, 12, "fenetre"], [0, 6, 0, 7, "fenetre"], [0, 9, 0, 10, "fenetre"], [16, 6, 16, 7, "fenetre_haute"]],
				"stairs": []},
		]},
	"boutique": {"name": "Boutique", "w": 10, "d": 8, "usage": "boutique", "roof": "plat", "budget": 110_000,
		"desc": "Une salle de vente derrière ses vitrines, une réserve et des toilettes.",
		"levels": [
			{"rooms": [[0, 0, 10, 8, ""], [0, 0, 10, 5, "boutique"], [0, 5, 7, 3, "reserve"], [7, 5, 3, 3, "sdb"]],
				"walls": [[0, 5, 10, 5], [7, 5, 7, 8]],
				"openings": [[4, 0, 5, 0, "porte_vitree"], [1, 0, 2, 0, "vitrine"], [2, 0, 3, 0, "vitrine"], [6, 0, 7, 0, "vitrine"], [7, 0, 8, 0, "vitrine"],
					[2, 5, 3, 5, "porte"], [8, 5, 9, 5, "porte"], [0, 2, 0, 3, "fenetre"], [3, 8, 4, 8, "porte"]],
				"stairs": []},
		]},
	"bureaux": {"name": "Bureaux sur deux niveaux", "w": 12, "d": 10, "usage": "bureaux", "roof": "plat", "budget": 260_000,
		"desc": "Deux plateaux de bureaux, un accueil, des toilettes et une salle de réunion.",
		"levels": [
			{"rooms": [[0, 0, 12, 10, ""], [0, 0, 6, 3, "entree"], [6, 0, 6, 3, "sdb"], [0, 3, 12, 7, "bureau"]],
				"walls": [[0, 3, 12, 3], [6, 0, 6, 3]],
				"openings": [[0, 2, 0, 3, "porte_vitree"], [6, 1, 6, 2, "porte"], [5, 3, 6, 3, "passage"], [1, 10, 2, 10, "baie"], [3, 10, 4, 10, "baie"],
					[5, 10, 6, 10, "baie"], [7, 10, 8, 10, "baie"], [9, 10, 10, 10, "baie"], [0, 5, 0, 6, "fenetre"], [0, 7, 0, 8, "fenetre"],
					[12, 5, 12, 6, "fenetre"], [12, 7, 12, 8, "fenetre"], [2, 0, 3, 0, "baie"]],
				"stairs": [_HALL_A]},
			{"rooms": [[0, 0, 12, 10, ""], [0, 0, 6, 3, "entree"], [6, 0, 6, 3, "bureau"], [0, 3, 12, 7, "bureau"]],
				"walls": [[0, 3, 12, 3], [6, 0, 6, 3]],
				"openings": [[6, 1, 6, 2, "porte_vitree"], [5, 3, 6, 3, "passage"], [1, 10, 2, 10, "baie"], [3, 10, 4, 10, "baie"], [5, 10, 6, 10, "baie"],
					[7, 10, 8, 10, "baie"], [9, 10, 10, 10, "baie"], [0, 5, 0, 6, "fenetre"], [12, 5, 12, 6, "fenetre"], [8, 0, 9, 0, "fenetre"], [12, 1, 12, 2, "fenetre"]],
				"stairs": []},
		]},
	"cafe": {"name": "Café-restaurant", "w": 10, "d": 10, "usage": "restaurant", "roof": "deux_pans", "budget": 130_000,
		"desc": "Une salle avec son bar et ses tables, une cuisine et des toilettes.",
		"levels": [
			{"rooms": [[0, 0, 10, 10, ""], [0, 0, 10, 6, "salle"], [0, 6, 6, 4, "cuisine"], [6, 6, 4, 4, "sdb"]],
				"walls": [[0, 6, 10, 6], [6, 6, 6, 10]],
				"openings": [[4, 0, 5, 0, "porte_vitree"], [1, 0, 2, 0, "vitrine"], [7, 0, 8, 0, "vitrine"], [0, 2, 0, 3, "baie"], [10, 2, 10, 3, "baie"],
					[2, 6, 3, 6, "passage"], [7, 6, 8, 6, "porte"], [2, 10, 3, 10, "fenetre"], [10, 8, 10, 9, "fenetre_haute"]],
				"stairs": []},
		]},
}
const ORDER := ["maison", "immeuble", "ecole", "boutique", "bureaux", "cafe"]

## Matériaux des murs et du toit selon la région du style (BlocMateriaux).
const WALLS := {"europe": 5, "mediterranee": 6, "moyen_orient": 30, "afrique": 30, "asie_est": 32, "asie_sud": 27,
	"ameriques": 32, "oceanie": 49, "monde": 5}
const ROOFS := {"europe": 7, "mediterranee": 7, "moyen_orient": 7, "afrique": 44, "asie_est": 42, "asie_sud": 7,
	"ameriques": 43, "oceanie": 44, "monde": 8}
## Sols des pièces d'eau : carrelage (récent) ou tomettes (ancien).
const WET := ["cuisine", "sdb"]


## Les étages d'un gabarit (l'immeuble est généré : quatre fois le même étage).
static func levels_of(kind: String) -> Array:
	var g: Dictionary = KINDS[kind]
	if g.levels is Array:
		return g.levels
	var out := []
	for e in 4:
		var op := [[6, 4, 6, 5, "passage"], [6, 7, 6, 8, "passage"], [10, 3, 11, 3, "porte"], [5, 3, 6, 3, "porte"],
			[1, 10, 2, 10, "fenetre"], [3, 10, 4, 10, "porte_fenetre"], [0, 6, 0, 7, "fenetre"], [0, 8, 0, 9, "fenetre"],
			[8, 10, 9, 10, "fenetre"], [10, 10, 11, 10, "fenetre"], [12, 8, 12, 9, "fenetre"], [12, 4, 12, 5, "fenetre"],
			[12, 1, 12, 2, "fenetre_haute"], [2, 0, 3, 0, "fenetre"]]
		if e == 0:
			op.append([5, 0, 6, 0, "porte_vitree"])
		var stairs := []
		if e < 3:
			stairs.append(_HALL_A if e % 2 == 0 else _HALL_B)
		out.append({"rooms": [[0, 0, 12, 10, ""], [0, 0, 6, 3, "entree"], [0, 3, 6, 7, "sejour"], [6, 3, 6, 3, "chambre"], [6, 6, 6, 4, "cuisine"], [6, 0, 6, 3, "sdb"]],
			"walls": [[0, 3, 12, 3], [6, 0, 6, 10], [6, 6, 12, 6]], "openings": op, "stairs": stairs})
	return out


## Sommet local (x, z) tourné de r quarts de tour dans une emprise w × d.
static func rot_vertex(v: Vector2i, r: int, w: int, d: int) -> Vector2i:
	match r % 4:
		1:
			return Vector2i(d - v.y, v.x)
		2:
			return Vector2i(w - v.x, d - v.y)
		3:
			return Vector2i(v.y, w - v.x)
	return v


static func rot_rect(x: int, z: int, rw: int, rd: int, r: int, w: int, d: int) -> Rect2i:
	var a := rot_vertex(Vector2i(x, z), r, w, d)
	var b := rot_vertex(Vector2i(x + rw, z + rd), r, w, d)
	var lo := Vector2i(mini(a.x, b.x), mini(a.y, b.y))
	return Rect2i(lo, Vector2i(absi(b.x - a.x), absi(b.y - a.y)))


static func size_of(kind: String, r: int) -> Vector2i:
	var g: Dictionary = KINDS[kind]
	return Vector2i(int(g.w), int(g.d)) if r % 2 == 0 else Vector2i(int(g.d), int(g.w))


## Construit et meuble le gabarit kind, coin −x −z en origin, tourné de r.
## Rend {ok, id, cost, error}.
static func build(mob: Mobilier, kind: String, origin: Vector2i, r: int, style: String) -> Dictionary:
	var pe := mob.pe
	if pe == null or not KINDS.has(kind):
		return {"ok": false, "error": "gabarit inconnu"}
	var g: Dictionary = KINDS[kind]
	var w := int(g.w)
	var d := int(g.d)
	var sz := size_of(kind, r)
	# Terrain libre et hauteur du rez-de-chaussée : au-dessus du point le plus haut.
	var y0 := -INF
	for x in range(-1, sz.x + 1):
		for z in range(-1, sz.y + 1):
			var c := origin + Vector2i(x, z)
			var inside := x >= 0 and z >= 0 and x < sz.x and z < sz.y
			var why := pe.check_cell(c, "")
			if inside and why != "":
				return {"ok": false, "error": why.trim_suffix(".").to_lower()}
			if inside:
				y0 = maxf(y0, pe.ground_level(c))
	var bs := mob.buildings
	if bs != null and not bs.unlimited_money and bs.money < int(g.budget):
		return {"ok": false, "error": "il faut au moins %s en caisse" % BuildingSystem.format_money(int(g.budget))}
	var money0 := bs.money if bs != null else 0
	var st := Meubles.style_of(style)
	var region := String(st.region)
	var era := Meubles.era_index(String(st.era))
	var wall_mat := int(WALLS.get(region, 5))
	if era >= 5:
		wall_mat = 4
	elif era == 4 and region in ["europe", "monde", "ameriques", "oceanie"]:
		wall_mat = 5
	var old_mat := pe.material
	var old_tint := pe.tint
	pe.set_tint(0)
	pe.set_material(wall_mat)
	var id := pe.new_plan(y0)
	var lv := levels_of(kind)
	var fns := []
	for e in lv.size():
		var L: Dictionary = lv[e]
		var rooms: Array = L.rooms
		var env: Array = rooms[0]
		pe.add_room(id, _shift(rot_rect(int(env[0]), int(env[1]), int(env[2]), int(env[3]), r, w, d), origin), e)
		for wl in L.walls:
			var a := rot_vertex(Vector2i(int(wl[0]), int(wl[1])), r, w, d) + origin
			var b := rot_vertex(Vector2i(int(wl[2]), int(wl[3])), r, w, d) + origin
			var keys := PlanEditor.wall_line(a, b, e)
			pe.add_walls(id, keys)
		for op in L.openings:
			var a2 := rot_vertex(Vector2i(int(op[0]), int(op[1])), r, w, d) + origin
			var b2 := rot_vertex(Vector2i(int(op[2]), int(op[3])), r, w, d) + origin
			var ks := PlanEditor.wall_line(a2, b2, e)
			if not ks.is_empty():
				pe.set_opening_at(id, ks[0], String(op[4]))
		for s in L.stairs:
			var cell := Vector2i(int(s[0]), int(s[1]))
			var rc := rot_rect(cell.x, cell.y, 1, 1, r, w, d)
			pe.add_stairs(id, rc.position + origin, e, (int(s[2]) + r) % 4)
		for i in range(1, rooms.size()):
			var rm: Array = rooms[i]
			var rr := _shift(rot_rect(int(rm[0]), int(rm[1]), int(rm[2]), int(rm[3]), r, w, d), origin)
			fns.append([e, rr, String(rm[4])])
	# Sols carrelés dans les pièces d'eau.
	pe.set_material(37 if era >= 3 else 39)
	for f in fns:
		if String(f[2]) in WET:
			var rect: Rect2i = f[1]
			for x in range(rect.position.x, rect.end.x):
				for z in range(rect.position.y, rect.end.y):
					var k := Vector3i(x, int(f[0]), z)
					if pe.plans[id].floors.has(k):
						pe.plans[id].floors[k].t = BlocFormes.encode(pe.material)
	pe._after_change(id)
	# Toit.
	pe.set_material(int(ROOFS.get(region, 7)) if era < 5 else 46)
	pe.add_roof(id, String(g.roof))
	pe.set_material(old_mat)
	pe.set_tint(old_tint)
	pe.flush()
	# Usage, fonctions des pièces, puis mobilier.
	mob.set_usage(id, String(g.usage))
	for f in fns:
		var rect2: Rect2i = f[1]
		mob.set_room_function(id, int(f[0]), rect2.position + Vector2i(rect2.size.x / 2, rect2.size.y / 2), String(f[2]))
	mob.furnish_plan(id, style)
	var cost := money0 - (bs.money if bs != null else 0)
	return {"ok": true, "id": id, "cost": cost}


static func _shift(r: Rect2i, o: Vector2i) -> Rect2i:
	return Rect2i(r.position + o, r.size)
