class_name Creations
extends RefCounted
## « Mes créations » : constructions de l'éditeur libre enregistrées comme
## bâtiments du catalogue, que l'on peut ensuite poser comme n'importe quel
## bâtiment (fantôme, rotation R, terrassement, accès, prix).
##
## La bibliothèque est commune à toutes les parties (user://mes_creations.json).
## Chaque partie garde aussi une copie des créations qu'elle contient : une
## sauvegarde reste lisible sur un autre ordinateur.
##
## Une création : {name, w, d, blocks: [x, y2, z, matériau, …], cost}.
## x et z vont de 0 à w−1 / d−1, y2 en demi-mètres depuis le bas.

const PATH := "user://mes_creations.json"
const CATEGORY := "creations"
const MAX_SIDE := 64
## Le prix d'une création posée : ses blocs, plus la main-d'œuvre.
const LABOUR := 1.3

static var items: Dictionary = {}
static var _loaded := false
## Faux pendant les tests, pour ne pas toucher à la bibliothèque du joueur.
static var persist := true


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not persist or not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		merge_dict(data)


static func _write() -> void:
	if not persist:
		return
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(to_dict()))


static func ids() -> Array[String]:
	ensure_loaded()
	var out: Array[String] = []
	for id in items:
		if not items[id].get("hidden", false):
			out.append(id)
	return out


## Entrée de catalogue d'une création (même format que BuildingCatalog).
static func catalog_entry(id: String) -> Dictionary:
	var c: Dictionary = items[id]
	return {"name": c.name, "cat": CATEGORY, "w": int(c.w), "d": int(c.d), "access": ["route", "chemin"],
		"cost": int(c.cost), "region": "monde", "era": "contemporain", "style": "", "creation": true,
		"blocks": c.blocks, "desc": "Ma création · %d blocs · %d × %d m" % [(c.blocks as Array).size() / 4, c.w, c.d]}


## Enregistre les blocs posés sur le rectangle (toutes hauteurs). Renvoie
## {ok, id} ou {ok: false, reason}.
static func capture(editor: BlockEditor, rect: Rect2i, name: String) -> Dictionary:
	ensure_loaded()
	if rect.size.x > MAX_SIDE or rect.size.y > MAX_SIDE:
		return {"ok": false, "reason": "Sélection trop grande : %d m de côté au maximum." % MAX_SIDE}
	var picked: Array = []
	var lo_y := 1 << 30
	var lo := Vector2i(1 << 30, 1 << 30)
	var hi := Vector2i(-(1 << 30), -(1 << 30))
	for k in editor.blocks:
		var kk: Vector3i = k
		if rect.has_point(Vector2i(kk.x, kk.z)):
			picked.append(kk)
			lo_y = mini(lo_y, kk.y)
			lo = Vector2i(mini(lo.x, kk.x), mini(lo.y, kk.z))
			hi = Vector2i(maxi(hi.x, kk.x), maxi(hi.y, kk.z))
	if picked.is_empty():
		return {"ok": false, "reason": "Aucun bloc dans la sélection."}
	# On resserre l'emprise sur les blocs réellement posés.
	var w := hi.x - lo.x + 1
	var d := hi.y - lo.y + 1
	var flat: Array = []
	var price := 0
	for k in picked:
		var m: int = editor.blocks[k]
		flat.append_array([k.x - lo.x, k.y - lo_y, k.z - lo.y, m])
		price += int(BlockEditor.MATERIALS[m].price)
	var id := "crea_%d_%d" % [int(Time.get_unix_time_from_system()), randi() % 100000]
	var nm := name.strip_edges()
	if nm == "":
		nm = "Création %d" % (items.size() + 1)
	items[id] = {"name": nm, "w": w, "d": d, "blocks": flat, "cost": maxi(1000, int(price * LABOUR))}
	_register(id)
	_write()
	return {"ok": true, "id": id, "blocks": picked.size(), "w": w, "d": d}


## Retire une création de la liste. Elle reste connue du catalogue : les
## exemplaires déjà posés et les sauvegardes restent valables.
static func remove(id: String) -> void:
	ensure_loaded()
	if items.has(id):
		items[id]["hidden"] = true
		_write()


## Créations utilisées par les bâtiments posés (pour la sauvegarde de la partie).
static func used_by(buildings: BuildingSystem) -> Array:
	var out: Array = []
	for b in buildings.buildings.values():
		var t := String(b.t)
		if items.has(t) and not t in out:
			out.append(t)
	return out


static func rename(id: String, name: String) -> void:
	if items.has(id) and name.strip_edges() != "":
		items[id].name = name.strip_edges()
		_register(id)
		_write()


static func _register(id: String) -> void:
	BuildingCatalog.all_types()[id] = catalog_entry(id)


## Maillage d'une création (repère du catalogue : centré, sol en y = 0, façade vers −Z).
static func build(k: BlocMesh, t: Dictionary) -> void:
	var flat: Array = t.blocks
	var w := float(t.w)
	var d := float(t.d)
	var hy := BlockEditor.HU * BlockEditor.UNIT_Y
	var s := BlockEditor.SIZE
	var occupied := {}
	var i := 0
	while i + 3 < flat.size():
		occupied[Vector3i(int(flat[i]), int(flat[i + 1]), int(flat[i + 2]))] = int(flat[i + 3])
		i += 4
	for key in occupied:
		var kk: Vector3i = key
		var mat: Dictionary = BlockEditor.MATERIALS[occupied[kk]]
		var col: Color = mat.color
		col.a = 1.0
		if mat.get("glass", false):
			col = Color(0.55, 0.75, 0.86)
		var x0 := kk.x * s - w / 2.0
		var z0 := kk.z * s - d / 2.0
		var y0 := kk.y * BlockEditor.UNIT_Y
		var x1 := x0 + s
		var z1 := z0 + s
		var y1 := y0 + hy
		var hu := BlockEditor.HU
		if not occupied.has(kk + Vector3i(0, hu, 0)):
			k.quad(Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(x0, y1, z1), Vector3.UP, col)
		if kk.y > 0 and not occupied.has(kk - Vector3i(0, hu, 0)):
			k.quad(Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x0, y0, z1), Vector3.DOWN, col.darkened(0.2))
		if not occupied.has(kk + Vector3i(1, 0, 0)):
			k.quad(Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0), Vector3.RIGHT, col.darkened(0.08))
		if not occupied.has(kk - Vector3i(1, 0, 0)):
			k.quad(Vector3(x0, y0, z0), Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x0, y1, z0), Vector3.LEFT, col.darkened(0.08))
		if not occupied.has(kk + Vector3i(0, 0, 1)):
			k.quad(Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x0, y1, z1), Vector3.BACK, col.darkened(0.03))
		if not occupied.has(kk - Vector3i(0, 0, 1)):
			k.quad(Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x0, y1, z0), Vector3.FORWARD, col.darkened(0.03))


# --- Sauvegarde ---------------------------------------------------------------------

static func to_dict(only: Array = []) -> Dictionary:
	var out := {}
	for id in items:
		if only.is_empty() or id in only:
			out[id] = items[id]
	return {"version": 1, "items": out}


## Ajoute les créations d'une sauvegarde (sans écraser celles déjà connues).
static func merge_dict(data: Dictionary) -> int:
	var n := 0
	var src: Dictionary = data.get("items", {})
	for id in src:
		var c: Dictionary = src[id]
		if not c.has("blocks"):
			continue
		if items.has(id):
			# Une création déjà connue mais retirée de la liste reste cachée.
			continue
			continue
		items[id] = {"name": String(c.get("name", "Création")), "w": int(c.w), "d": int(c.d),
			"blocks": (c.blocks as Array).map(func(v: Variant) -> int: return int(v)),
			"cost": int(c.get("cost", 1000)), "hidden": bool(c.get("hidden", false))}
		_register(id)
		n += 1
	return n


## Ajoute à la bibliothèque les créations d'une partie chargée.
static func adopt(data: Dictionary) -> void:
	ensure_loaded()
	if merge_dict(data) > 0:
		_write()
