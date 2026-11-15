class_name TourismeVisuels
extends Node3D
## Touristes devant les hébergements : de petits personnages (MultiMesh, comme
## au parc de loisirs) qui arrivent valise à la main, flânent devant l'entrée,
## prennent des photos. Leur nombre suit les clients (Tourisme.clients), au plus
## MAX_PAR_HEB par hébergement, seulement près de la caméra.
## Sites naturels (tourisme v2) : baigneurs et parasols sur les plages,
## promeneurs au bord des lacs, en forêt et sur les sommets, selon les visites
## du jour (au plus MAX_PAR_SITE, le jour, près de la caméra).

const MAX_PAR_HEB := 24
const MAX_PAR_SITE := 40
const PARASOLS := [Color("e63946"), Color("ffb703"), Color("2a9d8f"), Color("ffffff"), Color("457b9d"), Color("f4a261")]
const DISTANCE := 700.0
const VITESSE := 1.1
const PEAUX := [Color("f6dccb"), Color("e5b48f"), Color("c98f67"), Color("a06743"), Color("75472d"), Color("4d2e1e")]
## Tenues de vacances : chemises à fleurs, rouge, jaune, bleu ciel, blanc.
const HABITS := [Color("e76f51"), Color("f4a261"), Color("e9c46a"), Color("2a9d8f"), Color("8ecae6"), Color("ffffff"), Color("d62828"), Color("90be6d")]
const VALISES := [Color("1d3557"), Color("e63946"), Color("343a40"), Color("ffb703"), Color("6a4c93")]

var tourisme: Tourisme
## bid → liste de touristes {p (Vector3), cible (Vector3), wait, cap, peau, habit, valise (Color ou null)}.
var agents: Dictionary = {}
var _corps: MultiMeshInstance3D
var _tetes: MultiMeshInstance3D
var _valises: MultiMeshInstance3D
var _parasols: MultiMeshInstance3D
## "nature:<clé>" → {centre (Vector3), genre, liste de promeneurs} ; un parasol par agent qui en a un.
var nature_agents: Dictionary = {}
var _t := 0.0
var _rng := RandomNumberGenerator.new()


func setup(t: Tourisme) -> void:
	tourisme = t
	_rng.seed = 31_415


func _ready() -> void:
	_corps = _multi("Corps", ParcVisuels._corps_mesh())
	_tetes = _multi("Tetes", ParcVisuels._tete_mesh())
	var k := BlocMesh.new()
	k.box(0.32, 0.05, 0.0, 0.18, 0.55, 0.38, Color.WHITE)
	k.box(0.32, 0.6, 0.0, 0.04, 0.12, 0.12, Color("212529"))
	_valises = _multi("Valises", k.to_mesh(ParcVisuels._mat()))
	var pk := BlocMesh.new()
	pk.box(0.0, 0.0, 0.0, 0.05, 2.0, 0.05, Color("dee2e6"))
	pk.box(0.0, 1.9, 0.0, 2.0, 0.12, 2.0, Color.WHITE)
	pk.box(0.0, 1.75, 0.0, 1.4, 0.15, 1.4, Color.WHITE)
	pk.box(0.9, 0.0, 0.0, 0.9, 0.03, 1.8, Color.WHITE)
	_parasols = _multi("Parasols", pk.to_mesh(ParcVisuels._mat()))


func _multi(nom: String, mesh: Mesh) -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	mmi.name = nom
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mmi.multimesh = mm
	mmi.visibility_range_end = DISTANCE
	add_child(mmi)
	return mmi


func _process(delta: float) -> void:
	if tourisme == null:
		return
	_t -= delta
	if _t <= 0.0:
		_t = 1.0
		_peupler()
	_bouger(delta)
	_dessiner()


func _camera_pos() -> Vector3:
	var vp := get_viewport()
	var cam := vp.get_camera_3d() if vp != null else null
	return cam.global_position if cam != null else Vector3.ZERO


## Combien de touristes dessiner devant chaque hébergement.
func voulus(bid: int) -> int:
	var h := 0.0
	if tourisme.ambiance != null:
		var now := tourisme._now(tourisme.ambiance.unix_time)
		h = float(now.h)
	# La nuit, tout le monde dort (ou presque).
	var jour := 1.0 if h >= 8.0 and h < 22.0 else 0.15
	return mini(MAX_PAR_HEB, roundi(float(tourisme.clients(bid)) / 5.0 * jour))


func _peupler() -> void:
	var cam := _camera_pos()
	for bid in agents.keys():
		if not tourisme.heb.has(bid):
			agents.erase(bid)
	_peupler_nature(cam)
	for bid in tourisme.heb:
		var door := tourisme.porte(int(bid))
		var loin := Vector2(door.x, door.z).distance_to(Vector2(cam.x, cam.z)) > DISTANCE
		var voulu := 0 if loin else voulus(int(bid))
		var list: Array = agents.get(bid, [])
		agents[bid] = list
		while list.size() > voulu:
			list.pop_back()
		while list.size() < voulu:
			var p := _point(int(bid), door)
			list.append({"p": p, "cible": p, "wait": _rng.randf_range(0.0, 4.0), "cap": _rng.randf() * TAU,
				"peau": PEAUX[_rng.randi() % PEAUX.size()], "habit": HABITS[_rng.randi() % HABITS.size()],
				"valise": VALISES[_rng.randi() % VALISES.size()] if _rng.randf() < 0.45 else null})


func _bouger(delta: float) -> void:
	for k in nature_agents:
		var e: Dictionary = nature_agents[k]
		for a in e.liste:
			if a.parasol != null or bool(a.assis):
				continue
			if float(a.wait) > 0.0:
				a.wait = float(a.wait) - delta
				continue
			var p: Vector3 = a.p
			var c: Vector3 = a.cible
			var d := Vector2(c.x - p.x, c.z - p.z)
			if d.length() < 0.3:
				var w := tourisme._monde()
				var q := _point_nature(w, e.centre, String(e.genre)) if w != null else Vector3.INF
				if q.is_finite() and Vector2(q.x - p.x, q.z - p.z).length() < 40.0:
					a.cible = q
				a.wait = _rng.randf_range(2.0, 8.0)
				continue
			var step := minf(d.length(), VITESSE * delta)
			var dir := d.normalized()
			a.p = Vector3(p.x + dir.x * step, lerpf(p.y, c.y, clampf(step / maxf(d.length(), 0.01), 0.0, 1.0)), p.z + dir.y * step)
			a.cap = atan2(dir.x, dir.y)
	for bid in agents:
		var door := tourisme.porte(int(bid))
		for a in agents[bid]:
			if float(a.wait) > 0.0:
				a.wait = float(a.wait) - delta
				continue
			var p: Vector3 = a.p
			var c: Vector3 = a.cible
			var d := Vector2(c.x - p.x, c.z - p.z)
			if d.length() < 0.2:
				# Nouvelle envie : regarder la façade, faire une photo, revenir à la porte.
				a.cible = _point(int(bid), door)
				a.wait = _rng.randf_range(1.0, 6.0)
				continue
			var step := minf(d.length(), VITESSE * delta)
			var dir := d.normalized()
			a.p = Vector3(p.x + dir.x * step, door.y, p.z + dir.y * step)
			a.cap = atan2(dir.x, dir.y)


## Promeneurs voulus sur un site naturel (visites du jour, le jour seulement).
func voulus_site(st: Dictionary) -> int:
	var h := 12.0
	if tourisme.ambiance != null:
		h = float(tourisme._now(tourisme.ambiance.unix_time).h)
	if h < 9.0 or h >= 20.0:
		return 0
	var v := float(tourisme.visites_jour.get("nature:%s" % String(st.key), 0.0))
	return mini(MAX_PAR_SITE, roundi(v / 6.0))


func _peupler_nature(cam: Vector3) -> void:
	var w := tourisme._monde()
	var garde := {}
	for st in tourisme.sites:
		if String(st.kind) != "nature" or w == null:
			continue
		# Le point du site le plus proche de la caméra.
		var best := Vector3.INF
		var bd := INF
		for q in st.get("points", [st.pos]):
			var d := Vector2((q as Vector3).x - cam.x, (q as Vector3).z - cam.z).length()
			if d < bd:
				bd = d
				best = q
		if bd > DISTANCE:
			continue
		var k := "nature:%s" % String(st.key)
		garde[k] = true
		var e: Dictionary = nature_agents.get(k, {"centre": best, "genre": String(st.genre), "liste": []})
		nature_agents[k] = e
		if (e.centre as Vector3).distance_to(best) > 50.0:
			e.centre = best
			e.liste = []
		var voulu := voulus_site(st)
		var list: Array = e.liste
		while list.size() > voulu:
			list.pop_back()
		var essais := 0
		while list.size() < voulu and essais < voulu * 4:
			essais += 1
			var p := _point_nature(w, e.centre, String(e.genre))
			if not p.is_finite():
				continue
			var plage := String(e.genre) == "plage"
			list.append({"p": p, "cible": p, "wait": _rng.randf_range(0.0, 6.0), "cap": _rng.randf() * TAU,
				"peau": PEAUX[_rng.randi() % PEAUX.size()], "habit": HABITS[_rng.randi() % HABITS.size()], "valise": null,
				"parasol": PARASOLS[_rng.randi() % PARASOLS.size()] if plage and _rng.randf() < 0.4 else null, "assis": plage and _rng.randf() < 0.5})
	for k in nature_agents.keys():
		if not garde.has(k):
			nature_agents.erase(k)


## Un point de terre ferme près du centre d'un site (sur le sable pour une plage). INF si raté.
func _point_nature(w: TerrainWorld, c: Vector3, genre: String) -> Vector3:
	for i in 10:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(0.0, 90.0)
		var x := c.x + cos(a) * r
		var z := c.z + sin(a) * r
		var h := w.raw_height(x, z)
		if is_nan(h):
			continue
		var mer := w.sea_level()
		if h < mer + 0.15:
			continue
		# Sur le sable (le même test que le terrain : bord de mer, bas, biome qui devient plage).
		if genre == "plage" and not _sable(w, Vector2i(floori(x), floori(z))):
			continue
		if not is_nan(w.water_surface_at(x, z)):
			continue
		var hc := w.cell_height(Vector2i(floori(x), floori(z)))
		return Vector3(x, hc if not is_nan(hc) else h, z)
	return Vector3.INF


## Case de sable : sol nu (dunes) ou même règle que le dessin du terrain (bas, au bord de la mer, biome qui devient plage).
static func _sable(w: TerrainWorld, c: Vector2i) -> bool:
	var hc := w.cell_height(c)
	if is_nan(hc) or hc < 0.0:
		return false
	# Le sable nu de WorldCover (60) au bord de la mer : la plage et ses dunes.
	if w.cell_biome(c) == 60 and hc < 20.0:
		return true
	if hc > TerrainWorld.BEACH_MAX:
		return false
	if (TerrainWorld.BEACH_KINDS >> TerrainWorld.cell_kind_id(hc, 0.0, w.cell_biome(c))) & 1 == 0:
		return false
	return hc <= 1.0 or w.cell_kind_at(c) == TerrainWorld.KIND_NAMES[TerrainWorld.Kind.PLAGE]


## Un point devant la façade, côté bâtiment (pas sur la route).
func _point(bid: int, door: Vector3) -> Vector3:
	var c := tourisme.pos_of(bid)
	var vers := Vector3(c.x - door.x, 0, c.z - door.z)
	if vers.length() < 0.1:
		vers = Vector3(0, 0, 1)
	vers = vers.normalized()
	var cote := Vector3(-vers.z, 0, vers.x)
	return door + vers * _rng.randf_range(0.8, 3.0) + cote * _rng.randf_range(-8.0, 8.0)


func _dessiner() -> void:
	var n := 0
	var nv := 0
	var np := 0
	for bid in agents:
		for a in agents[bid]:
			n += 1
			if a.valise != null:
				nv += 1
	for k in nature_agents:
		for a in nature_agents[k].liste:
			n += 1
			if a.parasol != null:
				np += 1
	var mc := _corps.multimesh
	var mt := _tetes.multimesh
	var mv := _valises.multimesh
	if mc.instance_count != n:
		mc.instance_count = n
		mt.instance_count = n
	if mv.instance_count != nv:
		mv.instance_count = nv
	var mp := _parasols.multimesh
	if mp.instance_count != np:
		mp.instance_count = np
	var i := 0
	var j := 0
	for bid in agents:
		for a in agents[bid]:
			var xf := Transform3D(Basis(Vector3.UP, float(a.cap)).scaled(Vector3.ONE * 0.95), a.p)
			mc.set_instance_transform(i, xf)
			mc.set_instance_color(i, a.habit)
			mt.set_instance_transform(i, xf)
			mt.set_instance_color(i, a.peau)
			if a.valise != null:
				mv.set_instance_transform(j, xf)
				mv.set_instance_color(j, a.valise)
				j += 1
			i += 1
	var l := 0
	for k in nature_agents:
		for a in nature_agents[k].liste:
			var b := Basis(Vector3.UP, float(a.cap)).scaled(Vector3.ONE * 0.95)
			var pos: Vector3 = a.p
			if bool(a.assis) or a.parasol != null:
				# Allongé sur sa serviette.
				b = b * Basis(Vector3.RIGHT, -PI * 0.5)
				pos += Vector3(0, 0.15, 0)
			var xf := Transform3D(b, pos)
			mc.set_instance_transform(i, xf)
			mc.set_instance_color(i, a.habit)
			mt.set_instance_transform(i, xf)
			mt.set_instance_color(i, a.peau)
			if a.parasol != null:
				mp.set_instance_transform(l, Transform3D(Basis(Vector3.UP, float(a.cap)), (a.p as Vector3) + Vector3(0.6, 0, 0.6)))
				mp.set_instance_color(l, a.parasol)
				l += 1
			i += 1


func count() -> int:
	var n := 0
	for bid in agents:
		n += (agents[bid] as Array).size()
	return n


func count_nature() -> int:
	var n := 0
	for k in nature_agents:
		n += (nature_agents[k].liste as Array).size()
	return n
