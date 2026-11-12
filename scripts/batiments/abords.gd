class_name Abords
extends RefCounted
## Abords d'une maison habitée : clôture avec portillon, boîte aux lettres,
## allée, pots de fleurs devant la porte, potager, arbre fruitier, étendoir
## à linge. Ajoutés par BatimentsVie quand un foyer habite la maison,
## retirés quand elle se vide.
##
## Un maillage par type (repère local du bâtiment, façade vers −Z).

static var _cache := {}


## La maison de ce type a-t-elle des abords ? Renvoie la façade (z) ou NAN.
static func facade_of(id: String) -> float:
	var t := BuildingCatalog.get_type(id)
	var d := float(t.get("d", 0))
	match String(t.get("arch", "")):
		"maison", "grande_maison":
			if String(t.style) in ["sahel", "afrique_sud"]:
				return NAN
			if (Styles.STYLES[t.style] as Dictionary).get("roof", "") == "thatch":
				return NAN
			return -1.5 - (d - 5.0) / 2.0
	if id == "maison":
		return -5.0
	return NAN


static func mesh_for(id: String, material: Material) -> ArrayMesh:
	if _cache.has(id):
		return _cache[id]
	var mesh: ArrayMesh = null
	var fz := facade_of(id)
	if not is_nan(fz):
		var k := BlocMesh.new()
		k.details = true
		_build(k, id, fz)
		mesh = k.to_mesh(material)
	_cache[id] = mesh
	return mesh


static func _build(k: BlocMesh, id: String, fz: float) -> void:
	var t := BuildingCatalog.get_type(id)
	var w := float(t.w)
	var d := float(t.d)
	var s: Dictionary = Styles.STYLES.get(String(t.get("style", "")), {})
	var region := String(s.get("region", "europe"))
	var garage := bool(s.get("garage", false))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id + "|abords")
	var x0 := -w / 2.0 + 0.15
	var x1 := w / 2.0 - 0.15
	var z0 := -d / 2.0 + 0.15
	var z1 := d / 2.0 - 0.15
	# Clôture selon la région : piquets blancs, haie, muret ou bambou.
	var kind := "piquets"
	match region:
		"mediterranee", "moyen_orient", "afrique":
			kind = "muret"
		"asie_est", "asie_sud":
			kind = "bambou"
		"europe":
			kind = "haie" if rng.randf() < 0.5 else "piquets"
	var gate := 0.9
	var gx1 := x1
	if garage:
		gx1 = w / 2.0 - 3.6
	_fence(k, kind, Vector2(x0, z0), Vector2(-gate, z0), Vector3.FORWARD)
	_fence(k, kind, Vector2(gate, z0), Vector2(gx1, z0), Vector3.FORWARD)
	_fence(k, kind, Vector2(x0, z0), Vector2(x0, z1), Vector3.LEFT)
	_fence(k, kind, Vector2(x1, z0 + (6.5 if garage else 0.0)), Vector2(x1, z1), Vector3.RIGHT)
	_fence(k, kind, Vector2(x0, z1), Vector2(x1, z1), Vector3.BACK)
	# Allée et boîte aux lettres.
	var path := Color("b5ab98")
	k.plate(0, (z0 + fz) / 2.0, 1.3, absf(fz - z0), path, 0.0, 0.1)
	k.box(gate + 0.45, 0, z0 + 0.05, 0.08, 1.1, 0.08, Color("3a3a3a"))
	var bal: Color = [Color("f2c14e"), Color("2f4f8f"), Color("b5432f"), Color("2f6f4f")][rng.randi() % 4]
	k.box(gate + 0.45, 1.1, z0 + 0.05, 0.42, 0.32, 0.3, bal)
	k.box(gate + 0.45, 1.42, z0 + 0.05, 0.46, 0.05, 0.34, bal.darkened(0.3))
	# Pots de fleurs de part et d'autre de la porte.
	for x in [-1.2, 1.2]:
		k.cylinder(x, 0, fz - 0.45, 0.24, 0.3, 0.42, 6, Color("b5653d"))
		var fl: Color = StyleKit.FLEURS[rng.randi() % StyleKit.FLEURS.size()]
		k.cylinder(x, 0.42, fz - 0.45, 0.32, 0.12, 0.35, 6, Color("3f7a35"))
		for j in 3:
			k.box(x - 0.12 + j * 0.12, 0.62 + (j % 2) * 0.08, fz - 0.45 + (j - 1) * 0.06, 0.13, 0.13, 0.13, fl)
	# Potager au fond du terrain, rangs de légumes.
	var back_wall := fz + (8.0 if id == "maison" else d - 5.0)
	var back := z1 - back_wall
	var bz := z1 - 1.6
	var bx := x0 + 2.0
	if back > 3.0:
		for i in 3:
			var cx := bx + i * 1.3
			k.plate(cx, bz, 1.0, 2.2, Color("6b4a2f"), 0.0, 0.14)
			for j in 4:
				k.box(cx, 0.14, bz - 0.8 + j * 0.53, 0.5, 0.22, 0.3, Color("4f8f3a") if (i + j) % 3 else Color("8fb83a"))
		# Arbre fruitier.
		var tx := x1 - 1.8
		k.cylinder(tx, 0, bz, 0.14, 0.11, 1.6, 6, Color("6b4a2b"))
		k.dome(tx, 1.3, bz, 1.2, 1.5, Color("4c8c3f"), 8)
		for j in 4:
			k.box(tx - 0.7 + j * 0.45, 1.6 + (j % 2) * 0.5, bz - 0.9 + (j % 3) * 0.2, 0.16, 0.16, 0.16, Color("d23b2f"))
		# Étendoir à linge.
		var lx := (bx + 3.5 + tx - 1.5) / 2.0
		for x in [lx - 1.4, lx + 1.4]:
			k.box(x, 0, bz + 0.2, 0.07, 1.8, 0.07, Color("8d949b"))
		k.box(lx, 1.75, bz + 0.2, 2.8, 0.02, 0.02, Color("d9d9d9"))
		var linge := [Color("f2efe6"), Color("4f86b0"), Color("e86fa0"), Color("f2c14e")]
		for j in 4:
			k.box(lx - 1.0 + j * 0.65, 1.2, bz + 0.2, 0.45, 0.55, 0.03, linge[(j + rng.randi()) % 4])
	# Banc contre la façade.
	k.box(-w / 4.0 - 0.5, 0.4, fz - 0.4, 1.4, 0.08, 0.4, Color("8a5a36"))
	for x in [-w / 4.0 - 1.1, -w / 4.0 + 0.1]:
		k.box(x, 0, fz - 0.4, 0.08, 0.4, 0.35, Color("4a3a2a"))


static func _fence(k: BlocMesh, kind: String, a: Vector2, b: Vector2, out: Vector3) -> void:
	var length := a.distance_to(b)
	if length < 0.3:
		return
	var mid := (a + b) / 2.0
	var along_x := absf(b.x - a.x) > absf(b.y - a.y)
	var sx := length if along_x else 0.0
	var sz := 0.0 if along_x else length
	match kind:
		"haie":
			k.box(mid.x, 0, mid.y, maxf(sx, 0.6), 1.1, maxf(sz, 0.6), Color("3f7a35"))
			k.box(mid.x, 1.1, mid.y, maxf(sx, 0.6) - 0.1, 0.12, maxf(sz, 0.6) - 0.1, Color("4c8c3f"))
		"muret":
			k.box(mid.x, 0, mid.y, maxf(sx, 0.3), 0.9, maxf(sz, 0.3), Color("ece6d8"))
			k.box(mid.x, 0.9, mid.y, maxf(sx, 0.36), 0.08, maxf(sz, 0.36), Color("c9bfa8"))
		_:
			var col := Color("f2efe6") if kind == "piquets" else Color("b8a35a")
			var step := 0.42 if kind == "piquets" else 0.2
			var n := maxi(1, int(length / step))
			var hgt := 0.95 if kind == "piquets" else 1.3
			for i in n + 1:
				var p := a.lerp(b, float(i) / n)
				k.box(p.x, 0, p.y, 0.08, hgt + (0.08 if i % 2 == 0 else 0.0), 0.08, col)
			k.box(mid.x, 0.3, mid.y, maxf(sx, 0.05), 0.07, maxf(sz, 0.05), col.darkened(0.1))
			k.box(mid.x, hgt - 0.25, mid.y, maxf(sx, 0.05), 0.07, maxf(sz, 0.05), col.darkened(0.1))
