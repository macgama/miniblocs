class_name ParcAllees
extends Node3D
## Allées et files d'attente tracées à la main dans le parc (menu Parc, onglet
## Allées et files).
##
## - Allées : segments (clic glissé), en pavés, en bois ou en terre battue,
##   étroites ou larges. Les bouts proches se soudent (2,5 m) : cela forme un
##   réseau. Dès qu'un parc a ses propres allées, le jeu ne dessine plus les
##   allées automatiques, et les visiteurs suivent le réseau (plus court chemin).
## - Files d'attente : elles partent de l'entrée d'une attraction (ou d'un
##   stand) et se prolongent par d'autres clics glissés depuis leur bout. Les
##   visiteurs y attendent en rang, garde-corps compris.
## - Gomme : clic près d'un segment pour l'effacer.
##
## Section de sauvegarde « parc_allees ».

signal changed
signal message(text: String)
signal info_changed(text: String)

const SOUDURE := 2.5
const PORTEE_ENTREE := 10.0
const GENRES := {
	"pave": {"nom": "Allée pavée", "couleur": Color("d9c9a8"), "couleur2": Color("cdbd9b")},
	"bois": {"nom": "Promenade en bois", "couleur": Color("a67c52"), "couleur2": Color("8f6844")},
	"terre": {"nom": "Chemin de terre", "couleur": Color("b8956a"), "couleur2": Color("a8865c")},
	"asphalte": {"nom": "Allée goudronnée", "couleur": Color("6c6f75"), "couleur2": Color("62656b")},
}
const LARGEURS := [2.5, 4.0, 6.0]

var parc: ParcLoisirs
var world: TerrainWorld
## Segments : {a: Vector2, b: Vector2, l: largeur, g: genre}.
var allees: Array = []
## Files : {pts: Array[Vector2], bid: int} (pts[0] devant l'entrée).
var files: Array = []
var version := 0
## "" | "allee" | "file" | "gomme"
var outil := ""
var genre := "pave"
var largeur := 4.0
var _mi: MeshInstance3D
var _ligne: MeshInstance3D
var _glisse := false
var _debut := Vector2.ZERO
var _survol := Vector3.ZERO
var _survol_ok := false
var _graphe: Dictionary = {}
var _graphe_v := -1


func _ready() -> void:
	_mi = MeshInstance3D.new()
	_mi.name = "Allees"
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mi.visibility_range_end = 1400.0
	add_child(_mi)
	_ligne = MeshInstance3D.new()
	_ligne.name = "Trace"
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.82, 0.3, 0.6)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ligne.material_override = m
	add_child(_ligne)


func setup(p: ParcLoisirs, w: TerrainWorld) -> void:
	parc = p
	world = w
	p.allees = self
	if p.buildings:
		p.buildings.changed.connect(_lier_files)


func _sol(x: float, z: float) -> float:
	if world == null:
		return 0.0
	var h := world.raw_height(x, z)
	return 0.0 if is_nan(h) else h


# --- Édition ---------------------------------------------------------------------------------------

func set_outil(o: String) -> void:
	outil = o
	_glisse = false
	_ligne.mesh = null
	_aide()


func set_inactive() -> void:
	set_outil("")


func _aide() -> void:
	match outil:
		"allee":
			info_changed.emit("%s (%.1f m) : clic glissé pour tracer. Les bouts proches se soudent. Échap : arrêter." % [String(GENRES[genre].nom), largeur])
		"file":
			info_changed.emit("File d'attente : glisse depuis l'entrée d'une attraction, puis depuis le bout de la file pour la prolonger.")
		"gomme":
			info_changed.emit("Gomme : clic sur une allée ou une file pour l'effacer.")
		_:
			info_changed.emit("")


## Point soudé sur un bout existant (allée ou file) s'il y en a un tout près.
func _soude(p: Vector2) -> Vector2:
	var best := p
	var bd := SOUDURE
	for s in allees:
		for q: Vector2 in [s.a, s.b]:
			if q.distance_to(p) < bd:
				bd = q.distance_to(p)
				best = q
	return best


func ajoute_allee(a: Vector2, b: Vector2, g := "", l := -1.0) -> bool:
	a = _soude(a)
	b = _soude(b)
	if a.distance_to(b) < 1.0:
		return false
	# Un long trait est coupé en morceaux (le réseau suit mieux le relief).
	var n := maxi(1, ceili(a.distance_to(b) / 30.0))
	for i in n:
		allees.append({"a": a.lerp(b, float(i) / n), "b": a.lerp(b, float(i + 1) / n), "l": largeur if l < 0.0 else l, "g": genre if g == "" else g})
	_change()
	return true


## Nouvelle file (depuis l'entrée d'une attraction) ou prolongement d'une file existante.
func ajoute_file(a: Vector2, b: Vector2) -> bool:
	if a.distance_to(b) < 1.0:
		return false
	for f in files:
		var pts: Array = f.pts
		if (pts[pts.size() - 1] as Vector2).distance_to(a) < SOUDURE:
			pts.append(b)
			_change()
			return true
	var bid := _attraction_proche(a)
	if bid < 0:
		message.emit("Une file d'attente commence devant l'entrée d'une attraction ou d'un stand du parc.")
		return false
	# Une seule file par attraction : la nouvelle remplace l'ancienne.
	for f in files.duplicate():
		if int(f.bid) == bid:
			files.erase(f)
	var porte := parc.porte(bid)
	files.append({"pts": [Vector2(porte.x, porte.z), b], "bid": bid})
	message.emit("File d'attente de « %s » tracée." % parc.nom_de(bid))
	_change()
	return true


func _attraction_proche(p: Vector2) -> int:
	if parc == null:
		return -1
	var best := -1
	var bd := PORTEE_ENTREE
	for bid in parc.items:
		var role := String(parc.items[bid].role)
		if not role in ["attraction", "stand", "toilettes"]:
			continue
		var d := parc.porte(int(bid))
		var dist := Vector2(d.x, d.z).distance_to(p)
		if dist < bd:
			bd = dist
			best = int(bid)
	return best


func efface_pres(p: Vector2) -> bool:
	var best := -1
	var bd := 3.0
	var dans_file := false
	for i in allees.size():
		var s: Dictionary = allees[i]
		var d := _dist_seg(p, s.a, s.b)
		if d < maxf(bd, float(s.l) / 2.0 + 0.5) and d < bd + float(s.l) / 2.0:
			bd = d
			best = i
	for i in files.size():
		var pts: Array = files[i].pts
		for j in range(1, pts.size()):
			var d := _dist_seg(p, pts[j - 1], pts[j])
			if d < bd:
				bd = d
				best = i
				dans_file = true
	if best < 0:
		return false
	if dans_file:
		var pts: Array = files[best].pts
		# On retire le dernier morceau ; une file réduite à rien disparaît.
		if pts.size() > 2:
			pts.pop_back()
		else:
			files.remove_at(best)
	else:
		allees.remove_at(best)
	_change()
	return true


static func _dist_seg(p: Vector2, a: Vector2, b: Vector2) -> float:
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))


func _change() -> void:
	version += 1
	_dessine()
	changed.emit()
	if parc:
		parc.changed.emit()


## Les files suivent leur attraction (retirées si elle disparaît).
func _lier_files() -> void:
	if parc == null:
		return
	var avant := files.size()
	files = files.filter(func(f: Dictionary) -> bool: return parc.buildings.buildings.has(int(f.bid)))
	if files.size() != avant:
		_change()


# --- Utilisé par ParcLoisirs -----------------------------------------------------------------------------

## Le parc (entrée e) a-t-il ses propres allées ?
func dans_parc(e: int) -> bool:
	if parc == null or not parc.parcs.has(e) or allees.is_empty():
		return false
	var c := parc._center(e)
	var c2 := Vector2(c.x, c.z)
	for s in allees:
		if (s.a as Vector2).distance_to(c2) < ParcLoisirs.RAYON + 40.0:
			return true
	return false


func file_de(bid: int) -> Array:
	for f in files:
		if int(f.bid) == bid:
			return f.pts
	return []


## Place n° rang dans la file dessinée (null s'il n'y en a pas).
func place_file(bid: int, rang: int) -> Variant:
	var pts := file_de(bid)
	if pts.size() < 2:
		return null
	var d := rang * 0.8 + 0.6
	for i in range(1, pts.size()):
		var a: Vector2 = pts[i - 1]
		var b: Vector2 = pts[i]
		var l := a.distance_to(b)
		if d <= l:
			var p := a.lerp(b, d / maxf(l, 0.001))
			return Vector3(p.x, _sol(p.x, p.y), p.y)
		d -= l
	# File pleine : on s'entasse au bout.
	var e: Vector2 = pts[pts.size() - 1]
	var j := Vector2(sin(rang * 2.3), cos(rang * 1.7)) * 1.2
	return Vector3(e.x + j.x, _sol(e.x, e.y), e.y + j.y)


## Bout de la file (là où l'on entre dans la queue), ou null.
func bout_file(bid: int) -> Variant:
	var pts := file_de(bid)
	if pts.size() < 2:
		return null
	var e: Vector2 = pts[pts.size() - 1]
	return Vector3(e.x, _sol(e.x, e.y), e.y)


func _maj_graphe() -> void:
	if _graphe_v == version:
		return
	_graphe_v = version
	var noeuds: Array[Vector2] = []
	var liens: Dictionary = {}
	var idx := func(p: Vector2) -> int:
		for i in noeuds.size():
			if noeuds[i].distance_to(p) < 0.6:
				return i
		noeuds.append(p)
		return noeuds.size() - 1
	for s in allees:
		var a: int = idx.call(s.a)
		var b: int = idx.call(s.b)
		if not liens.has(a):
			liens[a] = []
		if not liens.has(b):
			liens[b] = []
		(liens[a] as Array).append(b)
		(liens[b] as Array).append(a)
	# Les croisements au milieu d'un segment : on relie au plus proche bout de l'autre.
	_graphe = {"n": noeuds, "l": liens}


func _noeud_proche(p: Vector2) -> int:
	var noeuds: Array = _graphe.get("n", [])
	var best := -1
	var bd := INF
	for i in noeuds.size():
		var d := (noeuds[i] as Vector2).distance_to(p)
		if d < bd:
			bd = d
			best = i
	return best


## Chemin par les allées de `from` à `to` (vide si pas de réseau assez proche).
func route(from: Vector3, to: Vector3) -> PackedVector3Array:
	_maj_graphe()
	var noeuds: Array = _graphe.get("n", [])
	if noeuds.size() < 2:
		return PackedVector3Array()
	var a := _noeud_proche(Vector2(from.x, from.z))
	var b := _noeud_proche(Vector2(to.x, to.z))
	if a < 0 or b < 0:
		return PackedVector3Array()
	if (noeuds[a] as Vector2).distance_to(Vector2(from.x, from.z)) > 45.0 or (noeuds[b] as Vector2).distance_to(Vector2(to.x, to.z)) > 45.0:
		return PackedVector3Array()
	# A* sur le petit réseau.
	var liens: Dictionary = _graphe.l
	var g := {a: 0.0}
	var prev := {}
	var ouverts := [a]
	var cible: Vector2 = noeuds[b]
	while not ouverts.is_empty():
		var cur: int = ouverts[0]
		var cf := float(g[cur]) + (noeuds[cur] as Vector2).distance_to(cible)
		for o in ouverts:
			var f := float(g[o]) + (noeuds[o] as Vector2).distance_to(cible)
			if f < cf:
				cf = f
				cur = o
		if cur == b:
			break
		ouverts.erase(cur)
		for nb in liens.get(cur, []):
			var ng := float(g[cur]) + (noeuds[cur] as Vector2).distance_to(noeuds[nb])
			if not g.has(nb) or ng < float(g[nb]):
				g[nb] = ng
				prev[nb] = cur
				if not ouverts.has(nb):
					ouverts.append(nb)
	if not g.has(b):
		return PackedVector3Array()
	var chemin: Array = [b]
	while chemin[0] != a:
		chemin.push_front(prev[chemin[0]])
	var out := PackedVector3Array([from])
	for i in chemin:
		var q: Vector2 = noeuds[i]
		out.append(Vector3(q.x, _sol(q.x, q.y), q.y))
	out.append(to)
	return out


# --- Dessin -----------------------------------------------------------------------------------------------

func _dessine() -> void:
	var k := BlocMesh.new()
	for s in allees:
		var gg: Dictionary = GENRES.get(String(s.g), GENRES.pave)
		_bande(k, s.a, s.b, float(s.l), gg.couleur, gg.couleur2, 0.07)
		# Petit rond aux jonctions (cache les raccords).
		for q: Vector2 in [s.a, s.b]:
			var y := _sol(q.x, q.y) + 0.075
			var r := float(s.l) / 2.0
			for i in 8:
				var a0 := TAU * i / 8.0
				var a1 := TAU * (i + 1) / 8.0
				k.tri(Vector3(q.x, y, q.y), Vector3(q.x + cos(a0) * r, y, q.y + sin(a0) * r), Vector3(q.x + cos(a1) * r, y, q.y + sin(a1) * r), Vector3.UP, gg.couleur)
	for f in files:
		var pts: Array = f.pts
		for i in range(1, pts.size()):
			_bande(k, pts[i - 1], pts[i], 1.4, Color("c9b28a"), Color("bfa77f"), 0.09)
			_garde_corps(k, pts[i - 1], pts[i])
	_mi.mesh = k.to_mesh(NightWindows.building_material())


func _bande(k: BlocMesh, a: Vector2, b: Vector2, larg: float, c1: Color, c2: Color, haut: float) -> void:
	var d := b - a
	var long := d.length()
	if long < 0.1:
		return
	var side := Vector2(-d.y, d.x).normalized() * (larg / 2.0)
	var n := maxi(1, int(long / 2.0))
	for i in n:
		var p0 := a.lerp(b, float(i) / n)
		var p1 := a.lerp(b, float(i + 1) / n)
		var y0 := maxf(_sol(p0.x, p0.y), maxf(_sol(p0.x + side.x, p0.y + side.y), _sol(p0.x - side.x, p0.y - side.y))) + haut
		var y1 := maxf(_sol(p1.x, p1.y), maxf(_sol(p1.x + side.x, p1.y + side.y), _sol(p1.x - side.x, p1.y - side.y))) + haut
		k.quad(Vector3(p0.x - side.x, y0, p0.y - side.y), Vector3(p0.x + side.x, y0, p0.y + side.y),
			Vector3(p1.x + side.x, y1, p1.y + side.y), Vector3(p1.x - side.x, y1, p1.y - side.y), Vector3.UP, c1 if i % 2 == 0 else c2)


func _garde_corps(k: BlocMesh, a: Vector2, b: Vector2) -> void:
	var d := b - a
	var long := d.length()
	if long < 0.1:
		return
	var side := Vector2(-d.y, d.x).normalized() * 0.75
	var n := maxi(1, int(long / 2.0))
	for s: float in [-1.0, 1.0]:
		for i in n + 1:
			var p := a.lerp(b, float(i) / n) + side * s
			var y := _sol(p.x, p.y)
			k.box(p.x, y, p.y, 0.08, 1.0, 0.08, Color("6c757d"))
			if i < n:
				var q := a.lerp(b, float(i + 1) / n) + side * s
				ParcTypes.beam(k, Vector3(p.x, y + 0.95, p.y), Vector3(q.x, _sol(q.x, q.y) + 0.95, q.y), 0.06, Color("ffc93c"))


# --- Souris -----------------------------------------------------------------------------------------------

func _pick(pos: Vector2) -> Variant:
	var cam := get_viewport().get_camera_3d()
	if cam == null or world == null:
		return null
	return world.pick_point(cam.project_ray_origin(pos), cam.project_ray_normal(pos))


func _unhandled_input(event: InputEvent) -> void:
	if outil == "":
		return
	if event is InputEventMouseMotion:
		var p: Variant = _pick((event as InputEventMouseMotion).position)
		_survol_ok = p != null
		if p != null:
			_survol = p
			if _glisse:
				_trace_apercu(_debut, Vector2(_survol.x, _survol.z))
	elif event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == KEY_ESCAPE:
		set_outil("")
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		var p: Variant = _pick(mb.position)
		if mb.pressed and p != null:
			var q := Vector2((p as Vector3).x, (p as Vector3).z)
			if outil == "gomme":
				if not efface_pres(q):
					message.emit("Rien à effacer ici.")
			else:
				_glisse = true
				_debut = _soude(q) if outil == "allee" else q
			get_viewport().set_input_as_handled()
		elif not mb.pressed and _glisse:
			_glisse = false
			_ligne.mesh = null
			if p != null:
				var q := Vector2((p as Vector3).x, (p as Vector3).z)
				if outil == "allee":
					ajoute_allee(_debut, q)
				elif outil == "file":
					ajoute_file(_debut, q)
			get_viewport().set_input_as_handled()


func _trace_apercu(a: Vector2, b: Vector2) -> void:
	var k := BlocMesh.new()
	_bande(k, a, b, largeur if outil == "allee" else 1.4, Color.WHITE, Color.WHITE, 0.25)
	_ligne.mesh = k.to_mesh()


# --- Sauvegarde ---------------------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var a := []
	for s in allees:
		a.append([snappedf(s.a.x, 0.01), snappedf(s.a.y, 0.01), snappedf(s.b.x, 0.01), snappedf(s.b.y, 0.01), float(s.l), String(s.g)])
	var f := []
	for fi in files:
		var pts := []
		for p: Vector2 in fi.pts:
			pts.append([snappedf(p.x, 0.01), snappedf(p.y, 0.01)])
		f.append({"bid": int(fi.bid), "pts": pts})
	return {"version": 1, "allees": a, "files": f}


func from_dict(d: Dictionary) -> void:
	allees.clear()
	files.clear()
	for r: Array in d.get("allees", []):
		allees.append({"a": Vector2(r[0], r[1]), "b": Vector2(r[2], r[3]), "l": float(r[4]), "g": String(r[5])})
	for fi: Dictionary in d.get("files", []):
		var pts: Array = []
		for p: Array in fi.get("pts", []):
			pts.append(Vector2(p[0], p[1]))
		if pts.size() >= 2:
			files.append({"bid": int(fi.bid), "pts": pts})
	_change()


func clear() -> void:
	allees.clear()
	files.clear()
	_change()
