class_name Conversion
extends RefCounted
## « Ouvrir l'intérieur » d'un bâtiment du catalogue : il est reconstruit en
## murs fins (vrais murs, portes qui s'ouvrent, escaliers, toit) à la place de
## son volume principal, avec ses couleurs, puis découpé en pièces et meublé
## dans un style proche du sien. On peut ensuite tout retoucher : murs,
## ouvertures, peinture, meubles.

## Archétypes qu'on sait ouvrir, et leur usage.
const USAGE := {"maison": "logement", "grande_maison": "logement", "rangee": "logement", "immeuble": "logement",
	"boutique": "boutique", "restaurant": "restaurant", "atelier": "bureaux", "bureaux": "bureaux", "ecole": "ecole"}
## Forme du toit des murs fins selon celle du style.
const ROOF := {"gable": "deux_pans", "shed": "deux_pans", "thatch": "quatre_pans", "hip": "quatre_pans", "curved": "quatre_pans",
	"mansard": "quatre_pans", "flat": "plat", "dome": "plat", "saw": "deux_pans"}
## Plus grand côté accepté (au-delà, on garde le modèle du catalogue).
const MAX_SIDE := 40
const MAX_LEVELS := 12


static func can_open(type_id: String) -> bool:
	var t := BuildingCatalog.get_type(type_id)
	return t.has("arch") and USAGE.has(String(t.arch))


## Volume principal du modèle (repère local du catalogue) : {w, d, cz}.
static func main_volume(t: Dictionary) -> Dictionary:
	var w := float(t.get("w", 10))
	var d := float(t.get("d", 10))
	var arch := String(t.get("arch", ""))
	if arch in ["maison", "grande_maison"]:
		return {"w": w - 2.0, "d": d - 5.0, "cz": -1.5}
	return {"w": w - 2.0, "d": d - 2.0, "cz": 0.0}


## Style de meubles le plus proche du style du bâtiment.
static func furniture_style(style_id: String) -> String:
	if Meubles.STYLES.has(style_id):
		return style_id
	var s: Dictionary = Styles.STYLES.get(style_id, {})
	var region := String(s.get("region", "europe"))
	var era := String(s.get("era", "contemporain"))
	# Même région et même époque d'abord.
	for sid in Meubles.STYLES:
		var m: Dictionary = Meubles.STYLES[sid]
		if String(m.region) == region and String(m.era) == era:
			return String(sid)
	return String(Meubles.DEFAULT_STYLE.get(region, "contemporain"))


## Matériau de BlocMateriaux le plus proche d'une couleur, parmi des familles.
static func nearest_material(c: Color, fams: Array) -> int:
	var best := 5
	var bd := INF
	for i in BlocMateriaux.LIST.size():
		var m: Dictionary = BlocMateriaux.LIST[i]
		if not String(m.get("fam", "")) in fams or m.get("glass", false):
			continue
		var o := Color(String(m.c1))
		var dd := Vector3(c.r - o.r, c.g - o.g, c.b - o.b).length_squared()
		if dd < bd:
			bd = dd
			best = i
	return best


# --- Plans des étages --------------------------------------------------------------------

## Étages d'un bâtiment de w × d mètres (façade d'entrée en z = 0), au format
## des gabarits : rooms, walls, openings, stairs.
static func levels_for(usage: String, w: int, d: int, floors: int) -> Array:
	var f := floors
	if w < 5 or d < 7:
		f = 1
	f = clampi(f, 1, MAX_LEVELS)
	var out := []
	if usage in ["boutique", "restaurant"] and d >= 8 and w >= 6:
		out.append(_shop_ground(usage, w, d, f > 1))
		for e in range(1, f):
			out.append(_mirror_z(_hall_floor(w, d, e, f, _upper_fns(e, "logement")), d))
		return out
	for e in f:
		out.append(_hall_floor(w, d, e, f, _upper_fns(e, usage)))
	return out


## Fonctions des pièces du fond (gauche, droite) et de l'avant à droite du hall.
static func _upper_fns(e: int, usage: String) -> Dictionary:
	match usage:
		"logement":
			if e == 0:
				return {"back": ["sejour", "cuisine"], "front": "sdb"}
			return {"back": ["chambre", "enfant" if e == 1 else "chambre"], "front": "sdb"}
		"ecole":
			return {"back": ["classe", "classe"], "front": "sdb"}
		"boutique":
			return {"back": ["boutique", "reserve"], "front": "sdb"}
		"restaurant":
			return {"back": ["salle", "cuisine"], "front": "sdb"}
	return {"back": ["bureau", "bureau"], "front": "sdb"}


## Un étage avec un hall d'entrée devant (escalier), une pièce d'eau à côté et
## deux pièces au fond.
static func _hall_floor(w: int, d: int, e: int, floors: int, fns: Dictionary) -> Dictionary:
	var single := w < 5 or d < 7
	if single:
		var room := String((fns.back as Array)[0])
		var op := [[w / 2, 0, w / 2 + 1, 0, "porte" if e == 0 else "fenetre"]]
		_windows_on(op, w, d, [w / 2], [], 0, d)
		return {"rooms": [[0, 0, w, d, ""], [0, 0, w, d, room]], "walls": [], "openings": op, "stairs": []}
	var hd := 3
	var hallw := mini(6, w - 3) if w >= 8 else w
	var rooms := [[0, 0, w, d, ""], [0, 0, hallw, hd, "entree"]]
	var walls := [[0, hd, w, hd]]
	var op := []
	if hallw < w:
		rooms.append([hallw, 0, w - hallw, hd, String(fns.front)])
		walls.append([hallw, 0, hallw, hd])
		op.append([hallw, hd - 1, hallw, hd, "porte"])
	var back: Array = fns.back
	var sx := clampi(int(round(w * 0.55)), 3, w)
	if w - sx < 3:
		sx = w
	if sx < w and back[0] == back[1] and String(back[0]) in ["bureau", "boutique"]:
		sx = w
	rooms.append([0, hd, sx, d - hd, String(back[0])])
	if sx < w:
		rooms.append([sx, hd, w - sx, d - hd, String(back[1])])
		walls.append([sx, hd, sx, d])
		# Passage entre les deux pièces du fond.
		var pz := mini(hd + 2, d - 2)
		op.append([sx, pz, sx, pz + 1, "porte" if e > 0 else "passage"])
	# Du hall vers le fond.
	op.append([1, hd, 2, hd, "porte" if e > 0 else "passage"])
	if sx < w and sx + 1 <= hallw - 1:
		op.append([sx, hd, sx + 1, hd, "porte"])
	# Porte d'entrée, fenêtres.
	var door_x := hallw - 1
	var front_skip := [door_x]
	if e == 0:
		op.append([door_x, 0, door_x + 1, 0, "porte"])
	_windows_on(op, w, d, front_skip, [sx], hd, d)
	# Porte-fenêtre au fond du séjour.
	if e == 0 and String(back[0]) == "sejour" and sx >= 4:
		for o in op:
			if int(o[1]) == d and int(o[3]) == d and int(o[0]) < sx - 1:
				o[4] = "porte_fenetre"
				break
	var stairs := []
	if e < floors - 1:
		stairs.append(Gabarits._HALL_A if e % 2 == 0 else Gabarits._HALL_B)
	return {"rooms": rooms, "walls": walls, "openings": op, "stairs": stairs}


## Rez-de-chaussée commercial : grande salle derrière les vitrines, réserve
## (ou cuisine) et toilettes au fond, escalier vers le logement du dessus.
static func _shop_ground(usage: String, w: int, d: int, stairs: bool) -> Dictionary:
	var main := "boutique" if usage == "boutique" else "salle"
	var back := "reserve" if usage == "boutique" else "cuisine"
	var bz := d - 3
	var sx := clampi(w - 3, 5, w)
	var rooms := [[0, 0, w, d, ""], [0, 0, w, bz, main], [0, bz, sx, 3, back]]
	var walls := [[0, bz, w, bz]]
	if sx < w:
		rooms.append([sx, bz, w - sx, 3, "sdb"])
		walls.append([sx, bz, sx, d])
	var mid := w / 2
	var op := [[mid, 0, mid + 1, 0, "porte_vitree"], [1, bz, 2, bz, "porte" if not stairs else "passage"]]
	if sx < w:
		op.append([sx + 1, bz, sx + 2, bz, "porte"])
	for x in range(1, w - 1):
		if absi(x - mid) >= 1 and x % 2 == 1:
			op.append([x, 0, x + 1, 0, "vitrine"])
	for z in range(2, bz - 1, 3):
		op.append([0, z, 0, z + 1, "fenetre"])
		op.append([w, z, w, z + 1, "fenetre"])
	op.append([sx - 2, d, sx - 1, d, "porte"])
	var st := []
	if stairs:
		st.append([1, d - 2, 3])
	return {"rooms": rooms, "walls": walls, "openings": op, "stairs": st}


## Fenêtres tous les trois mètres sur les quatre façades, sauf aux places prises.
static func _windows_on(op: Array, w: int, d: int, skip_front: Array, splits: Array, hd: int, _dd: int) -> void:
	for x in range(1, w - 1, 3):
		if not x in skip_front and not (x - 1) in skip_front and not (x + 1) in skip_front:
			op.append([x, 0, x + 1, 0, "fenetre"])
	for x in range(1, w - 1, 3):
		if not x in splits:
			op.append([x, d, x + 1, d, "fenetre"])
	for z in range(hd + 1, d - 1, 3):
		op.append([0, z, 0, z + 1, "fenetre"])
		op.append([w, z, w, z + 1, "fenetre"])


## Le même étage retourné de l'avant vers l'arrière (logement au-dessus d'une boutique).
static func _mirror_z(L: Dictionary, d: int) -> Dictionary:
	var rooms := []
	for r in L.rooms:
		rooms.append([int(r[0]), d - int(r[1]) - int(r[3]), int(r[2]), int(r[3]), String(r[4])])
	var walls := []
	for wl in L.walls:
		walls.append([int(wl[0]), d - int(wl[1]), int(wl[2]), d - int(wl[3])])
	var op := []
	for o in L.openings:
		var kind := String(o[4])
		if kind == "porte" and int(o[1]) == 0 and int(o[3]) == 0:
			kind = "fenetre"
		op.append([int(o[0]), d - int(o[1]), int(o[2]), d - int(o[3]), kind])
	var st := []
	for s in L.stairs:
		st.append([int(s[0]), d - 1 - int(s[1]), int(s[2])])
	return {"rooms": rooms, "walls": walls, "openings": op, "stairs": st}


# --- Conversion -------------------------------------------------------------------------

## Reconstruit le bâtiment bid en murs fins, meublé. Rend {ok, id, error}.
static func open_interior(mob: Mobilier, bid: int) -> Dictionary:
	var bs := mob.buildings
	if bs == null or not bs.buildings.has(bid):
		return {"ok": false, "error": "bâtiment introuvable"}
	var b: Dictionary = bs.buildings[bid]
	var type_id := String(b.t)
	if not can_open(type_id):
		return {"ok": false, "error": "ce bâtiment ne s'ouvre pas encore (seulement maisons, immeubles, boutiques, restaurants, bureaux, ateliers, écoles)"}
	var t := BuildingCatalog.get_type(type_id)
	var perso: Dictionary = b.get("perso", {})
	var vol := main_volume(t)
	var W := maxi(4, int(round(float(vol.w))))
	var D := maxi(4, int(round(float(vol.d))))
	if W > MAX_SIDE or D > MAX_SIDE:
		return {"ok": false, "error": "bâtiment trop grand pour être ouvert (%d m de côté au plus)" % MAX_SIDE}
	var floors := int(perso.get("etages", Personnalisation.base_floors(type_id)))
	var yaw := -int(b.r) * PI / 2.0 + float(b.get("a", 0.0))
	var basis := Basis(Vector3.UP, yaw)
	var rect := Rect2i(Vector2i(int(b.x), int(b.z)), BuildingCatalog.footprint(type_id, int(b.r)))
	var center := BuildingSystem.rect_center(rect) + basis * Vector3(0, 0, float(vol.cz))
	var f := basis * Vector3(0, 0, -1)
	var gr := 0
	if absf(f.x) > absf(f.z):
		gr = 1 if f.x > 0.0 else 3
	else:
		gr = 0 if f.z < 0.0 else 2
	var sz := Vector2i(W, D) if gr % 2 == 0 else Vector2i(D, W)
	var origin := Vector2i(roundi(center.x - sz.x / 2.0), roundi(center.z - sz.y / 2.0))
	# Couleurs du bâtiment -> matériaux des murs et du toit.
	var pal := Personnalisation.palette(type_id, int(b.get("v", 0)))
	var wall_c := Personnalisation.color_of(type_id, int(b.get("v", 0)), perso, "mur")
	var roof_c := Personnalisation.color_of(type_id, int(b.get("v", 0)), perso, "toit_c")
	if pal.is_empty():
		wall_c = Color("f1ece2")
	var style_id := String(t.get("style", ""))
	var roof_kind := String(perso.get("toit", Personnalisation.base_roof(type_id)))
	var usage := String(USAGE[String(t.arch)])
	var spec := {"w": W, "d": D, "levels": levels_for(usage, W, D, floors), "usage": usage,
		"roof": String(ROOF.get(roof_kind, "deux_pans")), "budget": 0,
		"wall_mat": nearest_material(wall_c, ["murs", "bois"]),
		"roof_mat": nearest_material(roof_c, ["toits"])}
	# Le bâtiment du catalogue laisse la place ; son prix compte pour la reconstruction.
	var saved := b.duplicate(true)
	bs.remove_quietly(bid)
	if not bs.unlimited_money:
		bs.money += int(saved.get("cost", 0))
	var res := Gabarits.build_spec(mob, spec, origin, gr, furniture_style(style_id))
	if not res.ok:
		if not bs.unlimited_money:
			bs.money -= int(saved.get("cost", 0))
		bs.restore(saved)
		return res
	mob.set_name_of(String(res.id), String(t.get("name", "")))
	return res
