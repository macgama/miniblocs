class_name MuseeVisuels
extends Node3D
## Visiteurs des musées en murs fins : de petits personnages (MultiMesh, comme
## au parc de loisirs) qui vont d'une œuvre à l'autre, s'arrêtent devant,
## passent les portes, s'assoient parfois sur les banquettes. Leur nombre suit
## les visiteurs présents (Musee.presents), au plus MAX_PAR_MUSEE par musée.

const MAX_PAR_MUSEE := 40
const VITESSE := 0.9
const PEAUX := [Color("f6dccb"), Color("e5b48f"), Color("c98f67"), Color("a06743"), Color("75472d"), Color("4d2e1e")]
const HABITS := [Color("1d3557"), Color("8e1e24"), Color("2a9d8f"), Color("e9c46a"), Color("6b4a2f"), Color("5e6b73"), Color("f4a261"), Color("3a3d42"), Color("e6e1d3")]

var musee: Musee
## Clé du musée → liste de visiteurs {p, path, wait, e, cap, peau, habit}.
var agents: Dictionary = {}
## Clé → {étage: {"spots": [[case, cap]], "walk": {case: true}}}.
var _plans: Dictionary = {}
var _corps: MultiMeshInstance3D
var _tetes: MultiMeshInstance3D
var _t := 0.0
var _rng := RandomNumberGenerator.new()


func setup(m: Musee) -> void:
	musee = m
	_rng.seed = 90_210


func _ready() -> void:
	_corps = _multi("Corps", ParcVisuels._corps_mesh())
	_tetes = _multi("Tetes", ParcVisuels._tete_mesh())
	if musee != null and musee.mob != null:
		musee.mob.changed.connect(func() -> void: _plans.clear())


func _multi(nom: String, mesh: Mesh) -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	mmi.name = nom
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mmi.multimesh = mm
	mmi.visibility_range_end = 600.0
	add_child(mmi)
	return mmi


## Cases où l'on marche et points de vue devant les œuvres, étage par étage.
func carte(key: String) -> Dictionary:
	if _plans.has(key):
		return _plans[key]
	var out := {}
	var mob := musee.mob
	if mob == null or mob.pe == null or not mob.pe.plans.has(key):
		return out
	var p: Dictionary = mob.pe.plans[key]
	var occ: Dictionary = mob._occ.get(key, {})
	for e in mob.pe.levels_of(key):
		var walk := {}
		var bl := mob.blocked_cells(key, int(e))
		for k in p.floors:
			var kf: Vector3i = k
			if kf.y != int(e):
				continue
			var c := Vector2i(kf.x, kf.z)
			if bl.has(c) or occ.has(Vector4i(c.x, int(e), c.y, 1)):
				continue
			walk[c] = true
		var spots := []
		var seats := []
		for k2 in mob.items.get(key, {}):
			var kk: Vector4i = k2
			if kk.y != int(e):
				continue
			var it: Dictionary = mob.items[key][k2]
			var ent := Meubles.get_entry(String(it.m))
			if ent.is_empty():
				continue
			var oeuvre := String(ent.get("theme", "")) != "" or String(ent.get("service", "")) != ""
			var seat := (ent.tags as Array).has("assise")
			if not oeuvre and not seat:
				continue
			var r := int(it.r)
			var cells := Meubles.cells_of(ent, Vector2i(kk.x, kk.z), r)
			var centre := Vector2.ZERO
			for c2 in cells:
				centre += Vector2(c2.x + 0.5, c2.y + 0.5)
			centre /= float(cells.size())
			if seat and not oeuvre:
				for c3 in cells:
					seats.append([c3, r])
				continue
			var dirs: Array = [-Meubles.back_dir(r)]
			if not bool(ent.mur):
				dirs = Mobilier.DIRS
			for c4 in cells:
				for d in dirs:
					var f: Vector2i = c4 + d
					if walk.has(f) and not cells.has(f):
						var to := centre - Vector2(f.x + 0.5, f.y + 0.5)
						spots.append([f, atan2(to.x, to.y)])
		out[int(e)] = {"walk": walk, "spots": spots, "seats": seats, "y": mob.pe.base_y(key, int(e))}
	_plans[key] = out
	return out


func _passable(key: String, e: int, a: Vector2i, d: Vector2i) -> bool:
	var w: Dictionary = musee.mob.wall_at(key, e, a, d)
	return w.is_empty() or Mobilier.is_door(w)


## Chemin de case en case (largeur d'abord), portes comprises.
func chemin(key: String, e: int, from: Vector2i, to: Vector2i) -> Array:
	var c := carte(key)
	if not c.has(e):
		return []
	var walk: Dictionary = c[e].walk
	if not walk.has(to):
		return []
	var prev := {from: from}
	var file: Array = [from]
	var i := 0
	while i < file.size() and i < 4000:
		var cur: Vector2i = file[i]
		i += 1
		if cur == to:
			break
		for d in Mobilier.DIRS:
			var n: Vector2i = cur + d
			if prev.has(n) or not walk.has(n) or not _passable(key, e, cur, d):
				continue
			prev[n] = cur
			file.append(n)
	if not prev.has(to):
		return []
	var out := []
	var cur2 := to
	while cur2 != from:
		out.push_front(cur2)
		cur2 = prev[cur2]
	return out


func _process(delta: float) -> void:
	if musee == null or musee.mob == null:
		return
	_t -= delta
	if _t <= 0.0:
		_t = 1.0
		_peupler()
	_bouger(delta)
	_dessiner()


func _peupler() -> void:
	for key in agents.keys():
		if not musee.musees.has(key) or not musee.is_plan(String(key)):
			agents.erase(key)
	for k in musee.musees:
		var key := String(k)
		if not musee.is_plan(key):
			continue
		var voulu := mini(MAX_PAR_MUSEE, musee.presents(key))
		var list: Array = agents.get(key, [])
		agents[key] = list
		while list.size() > voulu:
			list.pop_back()
		var c := carte(key)
		if c.is_empty():
			continue
		while list.size() < voulu:
			var e := int(c.keys()[_rng.randi() % c.size()])
			var walk: Dictionary = c[e].walk
			if walk.is_empty():
				break
			var cells := walk.keys()
			var cell: Vector2i = cells[_rng.randi() % cells.size()]
			list.append({"p": Vector2(cell.x + 0.5, cell.y + 0.5), "cell": cell, "path": [], "wait": _rng.randf_range(0.0, 4.0), "e": e,
				"cap": _rng.randf() * TAU, "peau": PEAUX[_rng.randi() % PEAUX.size()], "habit": HABITS[_rng.randi() % HABITS.size()], "assis": false})


func _bouger(delta: float) -> void:
	for key in agents:
		var c := carte(String(key))
		for a in agents[key]:
			if not c.has(int(a.e)):
				continue
			if float(a.wait) > 0.0:
				a.wait = float(a.wait) - delta
				continue
			var path: Array = a.path
			if path.is_empty():
				_choisir(String(key), a, c[int(a.e)])
				continue
			var nxt: Vector2i = path[0]
			var goal := Vector2(nxt.x + 0.5, nxt.y + 0.5)
			var v: Vector2 = goal - (a.p as Vector2)
			var step := VITESSE * delta
			a.assis = false
			if v.length() <= step:
				a.p = goal
				a.cell = nxt
				path.pop_front()
				if path.is_empty():
					a.cap = float(a.get("vue", a.cap))
					a.wait = _rng.randf_range(4.0, 14.0)
					a.assis = bool(a.get("va_assis", false))
			else:
				a.p = (a.p as Vector2) + v.normalized() * step
				a.cap = atan2(v.x, v.y)


func _choisir(key: String, a: Dictionary, lv: Dictionary) -> void:
	var spots: Array = lv.spots
	var seats: Array = lv.seats
	var target: Vector2i = a.cell
	a.va_assis = false
	if not seats.is_empty() and _rng.randf() < 0.12:
		var s: Array = seats[_rng.randi() % seats.size()]
		# Un banc : on s'assoit sur la case voisine libre, face à la salle.
		for d in Mobilier.DIRS:
			var f: Vector2i = (s[0] as Vector2i) + d
			if (lv.walk as Dictionary).has(f):
				target = f
				a.vue = atan2(-float(d.x), -float(d.y))
				break
	elif not spots.is_empty():
		var sp: Array = spots[_rng.randi() % spots.size()]
		target = sp[0]
		a.vue = float(sp[1])
	var path := chemin(key, int(a.e), a.cell, target)
	if path.is_empty():
		a.wait = _rng.randf_range(2.0, 6.0)
		a.cap = float(a.get("vue", a.cap))
		return
	a.path = path


func _dessiner() -> void:
	var n := 0
	for key in agents:
		n += (agents[key] as Array).size()
	var mc := _corps.multimesh
	var mt := _tetes.multimesh
	if mc.instance_count != n:
		mc.instance_count = n
		mt.instance_count = n
	var i := 0
	for key in agents:
		var c := carte(String(key))
		# Vue en coupe : pas de visiteurs dans les étages cachés.
		var niv: Dictionary = musee.mob.pe._nodes.get(key, {}) if musee.mob.pe != null else {}
		for a in agents[key]:
			var y := float(c.get(int(a.e), {}).get("y", 0.0))
			var nd = niv.get(int(a.e))
			var cache := nd != null and not (nd as Node3D).visible
			var pos := Vector3((a.p as Vector2).x, y, (a.p as Vector2).y)
			var b := Basis(Vector3.UP, float(a.cap)).scaled(Vector3.ONE * 0.95)
			if bool(a.get("assis", false)):
				b = b.scaled(Vector3(1.0, 0.72, 1.0))
			if cache:
				# Taille nulle (pas de déplacement, qui fausserait la boîte englobante).
				b = b.scaled(Vector3.ONE * 0.0001)
			var xf := Transform3D(b, pos)
			mc.set_instance_transform(i, xf)
			mc.set_instance_color(i, a.habit)
			mt.set_instance_transform(i, xf)
			mt.set_instance_color(i, a.peau)
			i += 1


func count() -> int:
	var n := 0
	for key in agents:
		n += (agents[key] as Array).size()
	return n
