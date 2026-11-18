class_name ParcInventions
extends RefCounted
## Attractions nouvelles qu'on obtient par la recherche du parc (ParcRecherche) :
## palais des glaces, tour panoramique, montagnes russes à looping, rivière
## rapide en bouées, cinéma dynamique. Même format que ParcTypes.TYPES (champ
## "parc" pour ParcLoisirs) ; "annee" : année d'invention (Epoques). ParcTypes
## les fusionne dans le catalogue, les dessine (build) et les anime.

const ROUGE := Color("d62828")
const JAUNE := Color("ffc93c")
const BLEU := Color("277da1")
const VERT := Color("43aa8b")
const VIOLET := Color("7b2cbf")
const ORANGE := Color("f77f00")
const BLANC := Color("f8f4ea")
const BOIS := Color("9c6644")
const METAL := Color("adb5bd")
const METAL_F := Color("6c757d")
const VITRE := Color("33495e")
const MIROIR := Color("b8d8e8")
const PAVE := Color("d8cbb3")
const EAU := Color("3f9ed8")
const EAU_C := Color("7fd3f5")
const BETON := Color("bfb8ad")

const TYPES := {
	"palais_glaces": {"name": "Palais des glaces", "w": 18, "d": 14, "access": [], "emplois": 1, "cost": 300_000, "annee": 1850,
		"parc": {"role": "attraction", "cap": 20, "cycle": 6.0, "exc": 2.0, "int": 0.5, "attrait": 2.0, "usure": 0.02, "anim": "miroir"},
		"metiers": [["operateur_attraction", 1]],
		"desc": "Un labyrinthe de miroirs. On s'y cogne surtout contre soi-même (et c'est très instructif)."},
	"tour_panoramique": {"name": "Tour panoramique", "w": 16, "d": 16, "access": [], "emplois": 2, "cost": 2_800_000, "annee": 1970,
		"parc": {"role": "attraction", "cap": 40, "cycle": 8.0, "exc": 2.5, "int": 1.0, "attrait": 4.5, "usure": 0.05, "anim": "panoramique"},
		"metiers": [["operateur_attraction", 1], ["technicien_attraction", 1]],
		"desc": "Une cabine annulaire qui monte en tournant au sommet d'un mât de 60 m. Vue sur trois cantons, ou deux départements."},
	"looping_express": {"name": "Montagnes russes à looping", "w": 72, "d": 36, "access": [], "emplois": 4, "cost": 9_500_000, "annee": 1976,
		"parc": {"role": "attraction", "cap": 24, "cycle": 2.0, "exc": 9.0, "int": 8.0, "attrait": 8.5, "usure": 0.07, "anim": "looping"},
		"metiers": [["operateur_attraction", 3], ["technicien_attraction", 1]],
		"desc": "Une chute de 25 m, un looping vertical, et un train de six wagons qui passe la tête en bas. Les casquettes restent au vestiaire."},
	"riviere_rapide": {"name": "Rivière rapide en bouées", "w": 50, "d": 36, "access": [], "emplois": 3, "cost": 5_200_000, "annee": 1980,
		"parc": {"role": "attraction", "cap": 48, "cycle": 6.0, "exc": 6.0, "int": 4.0, "attrait": 5.5, "usure": 0.07, "anim": "bouees"},
		"metiers": [["operateur_attraction", 2], ["technicien_attraction", 1]],
		"desc": "Des bouées de huit places sur un torrent artificiel. Quelqu'un est toujours plus mouillé que les autres : c'est toi."},
	"cinema_dynamique": {"name": "Cinéma dynamique 4D", "w": 24, "d": 20, "access": [], "emplois": 2, "cost": 3_200_000, "annee": 1993,
		"parc": {"role": "attraction", "cap": 60, "cycle": 9.0, "exc": 5.0, "int": 3.0, "attrait": 4.0, "usure": 0.05, "anim": "enseigne4d"},
		"metiers": [["operateur_attraction", 1], ["technicien_attraction", 1]],
		"desc": "Sièges qui bougent, vent, embruns et odeurs. Le film dure 12 minutes, le mal de mer un peu plus."},
}
const ORDER := ["palais_glaces", "tour_panoramique", "looping_express", "riviere_rapide", "cinema_dynamique"]
const ANIMS := ["miroir", "panoramique", "looping", "bouees", "enseigne4d"]


# --- Modèles fixes ------------------------------------------------------------------------------

static func build(k: BlocMesh, id: String, t: Dictionary) -> void:
	var w := float(t.w)
	var d := float(t.d)
	match id:
		"palais_glaces":
			k.plate(0, 0, w, d, PAVE)
			k.box(0, 0, 0.5, 14.0, 4.2, 10.0, BLANC)
			k.box(0, 4.2, 0.5, 14.6, 0.4, 10.6, VIOLET)
			k.gable(0, 4.6, 0.5, 14.6, 10.6, 2.6, ROUGE)
			# Façade de miroirs et colonnes dorées.
			for i in 6:
				var x := -5.5 + i * 2.2
				k.box(x, 0.4, -4.53, 1.6, 3.2, 0.05, MIROIR)
				k.box(x - 1.1, 0, -4.6, 0.25, 4.2, 0.25, JAUNE)
			k.box(0, 5.0, -4.58, 6.0, 1.0, 0.05, JAUNE)
			ParcTypes.guichet(k, -7.5, -5.8, VIOLET)
		"tour_panoramique":
			k.plate(0, 0, w, d, PAVE)
			k.cylinder(0, 0, 0, 6.5, 6.5, 0.5, 18, BETON)
			k.cylinder(0, 0.5, 0, 1.3, 1.0, 60.0, 10, BLANC)
			k.cylinder(0, 60.5, 0, 1.6, 0.2, 2.0, 10, ROUGE)
			k.cylinder(0, 62.5, 0, 0.05, 0.05, 4.0, 4, METAL_F)
			for i in 6:
				k.box(0, 8.0 + i * 9.0, -1.05, 0.4, 0.6, 0.05, ROUGE)
			ParcTypes.guichet(k, -5.0, -7.0, ROUGE)
		"looping_express":
			k.plate(0, 0, w, d, Color("8ab17d"))
			var pts := looping_points()
			for i in pts.size():
				var a := pts[i]
				var b := pts[(i + 1) % pts.size()]
				ParcTypes.beam(k, a, b, 0.35, ROUGE)
				if i % 3 == 0 and a.y > 1.5 and not _dans_looping(i):
					k.box(a.x, 0, a.z, 0.4, a.y - 0.2, 0.4, METAL_F)
			# Le looping tient sur deux pieds en A.
			var c := LOOP_C
			for s in [-1.0, 1.0]:
				ParcTypes.beam(k, Vector3(c.x - 7.0, 0.3, c.z + 3.0 * s), Vector3(c.x, c.y + LOOP_R, c.z + 0.8 * s), 0.5, METAL_F)
				ParcTypes.beam(k, Vector3(c.x + 7.0, 0.3, c.z + 3.0 * s), Vector3(c.x, c.y + LOOP_R, c.z + 0.8 * s), 0.5, METAL_F)
			# Gare.
			k.box(-6.0, 0, -15.0, 16.0, 1.2, 4.0, PAVE)
			k.box(-6.0, 4.4, -15.0, 17.0, 0.4, 5.0, ROUGE)
			for x in [-13.5, -6.0, 1.5]:
				k.box(x, 1.2, -16.8, 0.3, 3.2, 0.3, METAL_F)
			ParcTypes.guichet(k, -16.0, -16.5, ROUGE)
		"riviere_rapide":
			k.plate(0, 0, w, d, Color("8ab17d"))
			var pts := bouees_points(w, d)
			for i in pts.size():
				var a := pts[i]
				var b := pts[(i + 1) % pts.size()]
				var f := (b - a).normalized()
				var n := Vector3(-f.z, 0, f.x)
				for side in [-1.0, 1.0]:
					var o: Vector3 = n * 2.6 * side
					var top := Vector3(0, 0.9, 0)
					k.quad(a + o, b + o, b + o + top, a + o + top, n * side, BETON)
					k.quad(a + o + top, b + o + top, b + o * 0.85 + top, a + o * 0.85 + top, Vector3.UP, BETON.lightened(0.1))
				k.quad(a - n * 2.2 + Vector3(0, 0.6, 0), b - n * 2.2 + Vector3(0, 0.6, 0), b + n * 2.2 + Vector3(0, 0.6, 0),
					a + n * 2.2 + Vector3(0, 0.6, 0), Vector3.UP, EAU)
			# Rochers et cascade au milieu.
			for i in 7:
				var a := TAU * i / 7.0
				k.box(cos(a) * 6.0, 0, sin(a) * 4.0, 3.0 + (i % 3), 2.0 + (i % 4) * 1.4, 3.0, Color("8d8174"))
			k.box(0, 0, 0, 4.0, 7.0, 4.0, Color("7a6f63"))
			k.box(0, 1.0, -2.05, 2.2, 6.0, 0.05, EAU_C)
			k.box(-w / 2.0 + 8.0, 0, -d / 2.0 + 3.0, 10.0, 0.9, 3.0, PAVE)
			k.box(-w / 2.0 + 8.0, 3.6, -d / 2.0 + 3.0, 11.0, 0.3, 4.0, VERT)
			ParcTypes.guichet(k, -w / 2.0 + 2.5, -d / 2.0 + 1.5, VERT)
		"cinema_dynamique":
			k.plate(0, 0, w, d, PAVE)
			k.box(0, 0, 1.0, 20.0, 7.0, 16.0, Color("2b2d42"))
			k.dome(0, 7.0, 1.0, 8.5, 5.0, METAL, 16)
			k.box(0, 0, -7.4, 8.0, 3.4, 1.6, BLANC)
			k.box(0, 3.4, -7.4, 9.0, 0.3, 2.2, ORANGE)
			k.box(0, 0.3, -8.22, 5.0, 2.6, 0.05, VITRE)
			k.box(0, 5.0, -7.04, 14.0, 1.6, 0.05, Color("111111"))
			ParcTypes.guichet(k, -8.5, -8.5, ORANGE)


# --- Tracés -----------------------------------------------------------------------------------

const LOOP_N := 96
const LOOP_C := Vector3(14.0, 9.5, 2.0)
const LOOP_R := 8.0
## Indices du tracé qui forment le looping.
const LOOP_I0 := 40
const LOOP_I1 := 56

static var _loop: PackedVector3Array


static func _dans_looping(i: int) -> bool:
	return i >= LOOP_I0 and i <= LOOP_I1


## Montagnes russes à looping : gare devant (z ≈ −15), montée, chute, looping,
## virage relevé et retour. Boucle fermée, repère du bâtiment.
static func looping_points() -> PackedVector3Array:
	if not _loop.is_empty():
		return _loop
	var out := PackedVector3Array()
	for i in LOOP_N:
		var p: Vector3
		if i < 14:
			# Gare puis lift : de x −18 à x −28, z −15.
			var s := float(i) / 13.0
			p = Vector3(lerpf(0.0, -26.0, s), lerpf(1.6, 2.0, s) + 23.0 * smoothstep(0.35, 1.0, s), -15.0)
		elif i < 26:
			# Virage en haut (demi-cercle à gauche).
			var s := float(i - 14) / 12.0
			var a := PI * s
			p = Vector3(-26.0 - 6.0 * sin(a), 25.0 - 2.0 * s, -15.0 + 7.5 * (1.0 - cos(a)))
		elif i < LOOP_I0:
			# Grande chute vers le looping.
			var s := float(i - 26) / float(LOOP_I0 - 26)
			p = Vector3(lerpf(-26.0, LOOP_C.x, s), lerpf(23.0, LOOP_C.y - LOOP_R + 0.2, smoothstep(0.0, 0.8, s)), lerpf(0.0, LOOP_C.z - 1.2, s))
		elif i <= LOOP_I1:
			# Looping vertical dans le plan x-y (décalé en z pour que le train croise).
			var s := float(i - LOOP_I0) / float(LOOP_I1 - LOOP_I0)
			var a := TAU * s
			p = Vector3(LOOP_C.x + LOOP_R * sin(a), LOOP_C.y - LOOP_R * cos(a), LOOP_C.z - 1.2 + 2.4 * s)
		elif i < 76:
			# Virage relevé à droite.
			var s := float(i - LOOP_I1) / float(76 - LOOP_I1)
			var a := PI * s
			p = Vector3(LOOP_C.x + 12.0 * sin(a) + 4.0 * s, LOOP_C.y - LOOP_R + 0.8 + 6.0 * sin(a), LOOP_C.z + 1.2 + 9.0 * (1.0 - cos(a)) * 0.6)
		else:
			# Retour vers la gare, par l'arrière.
			var s := float(i - 76) / float(LOOP_N - 76)
			var start := Vector3(LOOP_C.x + 4.0, LOOP_C.y - LOOP_R + 0.8, LOOP_C.z + 12.0)
			p = Vector3(lerpf(start.x, 30.0, smoothstep(0.0, 0.3, s)) * (1.0 - smoothstep(0.3, 1.0, s)) + 0.0 * s,
				lerpf(start.y, 1.6, smoothstep(0.0, 0.9, s)) + 2.5 * sin(s * TAU) * (1.0 - s),
				lerpf(start.z, -15.0, smoothstep(0.25, 1.0, s)))
		out.append(Vector3(p.x, maxf(p.y, 1.2), p.z))
	_loop = out
	return out


## Canal de la rivière rapide : ovale cabossé.
static func bouees_points(w: float, d: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	var n := 28
	for i in n:
		var u := TAU * i / n
		var x := (w / 2.0 - 6.0) * sin(u) + 2.5 * sin(3.0 * u)
		var z := -(d / 2.0 - 6.0) * cos(u) + 2.0 * sin(2.0 * u)
		out.append(Vector3(x, 0.0, z))
	return out


static func _at(pts: PackedVector3Array, s: float, total: float) -> Vector3:
	var acc := 0.0
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		var l := a.distance_to(b)
		if acc + l >= s:
			return a.lerp(b, (s - acc) / maxf(l, 0.001))
		acc += l
	return pts[0]


static func _longueur(pts: PackedVector3Array) -> float:
	var l := 0.0
	for i in pts.size():
		l += pts[i].distance_to(pts[(i + 1) % pts.size()])
	return l


# --- Parties mobiles --------------------------------------------------------------------------

static func _mi(k: BlocMesh, nom: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nom
	mi.mesh = k.to_mesh(ParcTypes.material())
	mi.visibility_range_end = 900.0
	return mi


static func build_anim(id: String, spec: Dictionary) -> Node3D:
	var anim := String(spec.get("anim", ""))
	if not anim in ANIMS:
		return null
	var t: Dictionary = TYPES.get(BuildingCatalog.base_of(id), {})
	var root := Node3D.new()
	root.name = "Anim"
	match anim:
		"miroir":
			var k := BlocMesh.new()
			k.box(0, 0, 0, 2.4, 2.4, 0.15, JAUNE)
			k.box(0, 0.2, -0.09, 2.0, 2.0, 0.05, MIROIR)
			var m := _mi(k, "enseigne")
			m.position = Vector3(0, 7.6, -4.4)
			root.add_child(m)
		"panoramique":
			var k := BlocMesh.new()
			k.cylinder(0, 0, 0, 5.2, 5.2, 0.4, 20, METAL_F)
			k.cylinder(0, 0.4, 0, 5.0, 5.0, 2.2, 20, VITRE)
			k.cylinder(0, 2.6, 0, 5.3, 4.6, 0.5, 20, ROUGE)
			for i in 10:
				var a := TAU * i / 10.0
				k.box(cos(a) * 4.9, 0.4, sin(a) * 4.9, 0.2, 2.2, 0.2, BLANC)
			var c := _mi(k, "cabine")
			c.position = Vector3(0, 0.5, 0)
			root.add_child(c)
		"looping":
			for i in 6:
				var k := BlocMesh.new()
				var col: Color = [ROUGE, JAUNE, BLEU, VERT, ORANGE, VIOLET][i]
				k.box(0, 0.0, 0, 1.6, 0.8, 2.0, col)
				k.box(0, 0.8, 0.5, 1.6, 0.6, 0.25, col.darkened(0.25))
				k.box(0, 0.8, -0.5, 1.6, 0.6, 0.25, col.darkened(0.25))
				k.box(0, 0.8, 0.0, 1.2, 0.9, 0.12, METAL_F)
				root.add_child(_mi(k, "wagon_%d" % i))
		"bouees":
			for i in 6:
				var k := BlocMesh.new()
				k.cylinder(0, 0, 0, 1.7, 1.7, 0.7, 12, [JAUNE, ORANGE, ROUGE, BLEU, VERT, VIOLET][i])
				k.cylinder(0, 0.7, 0, 1.0, 1.0, 0.1, 10, Color("2b2d42"))
				for j in 4:
					var a := TAU * j / 4.0
					k.box(cos(a) * 1.15, 0.7, sin(a) * 1.15, 0.4, 0.6, 0.35, ParcTypes.VIFS[(i + j) % ParcTypes.VIFS.size()])
					k.box(cos(a) * 1.15, 1.3, sin(a) * 1.15, 0.26, 0.28, 0.26, VoieMesh.PEAUX[(i + j) % 5])
				root.add_child(_mi(k, "bouee_%d" % i))
		"enseigne4d":
			var k := BlocMesh.new()
			k.box(0, 0, 0, 3.6, 2.0, 0.3, ORANGE)
			k.box(-0.8, 0.4, -0.17, 1.0, 1.2, 0.05, BLANC)
			k.box(0.8, 0.4, -0.17, 1.0, 1.2, 0.05, BLANC)
			var e := _mi(k, "enseigne")
			e.position = Vector3(0, 12.4, 1.0)
			root.add_child(e)
	if t.is_empty():
		return root
	return root


static func animate(root: Node3D, id: String, t: float, dt: float, marche: float, phase: float) -> void:
	var td: Dictionary = TYPES.get(BuildingCatalog.base_of(id), {})
	var spec: Dictionary = td.get("parc", {})
	var tt := t + phase
	match String(spec.get("anim", "")):
		"miroir":
			var m: Node3D = root.get_node("enseigne")
			m.rotation.y = 0.25 * sin(tt * 0.8)
		"panoramique":
			var c: Node3D = root.get_node("cabine")
			# Monte 2 min, tourne en haut, redescend : un cycle de 8 min ramené à 40 s visibles.
			var u := float(root.get_meta("u", 0.0)) + dt * marche
			root.set_meta("u", u)
			var s := fposmod(u, 40.0) / 40.0
			var h := 0.5 + 52.0 * (smoothstep(0.0, 0.35, s) - smoothstep(0.65, 1.0, s))
			c.position.y = h
			c.rotation.y = u * 0.25
		"looping":
			var pts := looping_points()
			var L := float(root.get_meta("L", 0.0))
			if L <= 0.0:
				L = _longueur(pts)
				root.set_meta("L", L)
			var s := float(root.get_meta("s", 0.0))
			var p := _at(pts, s, L)
			var v := 4.0 if s < L * 0.14 else sqrt(maxf(2.0 * 9.81 * (25.5 - p.y), 16.0))
			s = fposmod(s + v * dt * marche, L)
			root.set_meta("s", s)
			for i in 6:
				var w: Node3D = root.get_node("wagon_%d" % i)
				var si := fposmod(s - i * 2.3, L)
				var a := _at(pts, si, L)
				var b := _at(pts, fposmod(si + 0.5, L), L)
				w.position = a + Vector3(0, 0.05, 0)
				var fwd := b - a
				if fwd.length() < 0.01:
					continue
				fwd = fwd.normalized()
				# Dans le looping, le « haut » du wagon pointe vers le centre de la boucle.
				var up := Vector3.UP
				var to_c := Vector3(LOOP_C.x, LOOP_C.y, a.z) - a
				if to_c.length() < LOOP_R + 1.0 and a.y > 1.6:
					up = to_c.normalized()
				var side := fwd.cross(up)
				if side.length() < 0.01:
					side = Vector3.RIGHT
				side = side.normalized()
				up = side.cross(fwd).normalized()
				w.basis = Basis(side, up, -fwd)
		"bouees":
			var pts := bouees_points(float(td.get("w", 50)), float(td.get("d", 36)))
			var L := float(root.get_meta("L", 0.0))
			if L <= 0.0:
				L = _longueur(pts)
				root.set_meta("L", L)
			var s := float(root.get_meta("s", 0.0)) + dt * 3.2 * marche
			root.set_meta("s", s)
			for i in 6:
				var b: Node3D = root.get_node("bouee_%d" % i)
				var p := _at(pts, fposmod(s + i * L / 6.0, L), L)
				b.position = Vector3(p.x, 0.65 + 0.08 * sin(tt * 3.0 + i), p.z)
				b.rotation.y = s * 0.4 + i * 1.7
		"enseigne4d":
			var e: Node3D = root.get_node("enseigne")
			e.position.y = 12.4 + 0.15 * sin(tt * 2.0)
