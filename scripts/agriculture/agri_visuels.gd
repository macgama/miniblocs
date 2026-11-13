class_name AgriVisuels
extends Node3D
## Ce que l'on voit de l'agriculture : le sol de chaque champ (labouré, levée,
## culture qui mûrit, chaume) avec la bande déjà travaillée, les plantes qui
## grandissent, les machines au travail, les bottes de paille et les bêtes
## dans les prés.

## Plantes visibles jusqu'à cette distance (m), par carrés de BLOC m.
const PLANTES_LOIN := 170.0
const BLOC := 48
## Machines et bêtes visibles jusqu'à cette distance de la caméra (m).
const ENGINS_LOIN := 1500.0
const BETES_LOIN := 600.0
## Bêtes affichées au plus par espèce et par ferme.
const BETES_MAX := 24

var agri: Agriculture
var world: TerrainWorld
## Champs affichés : id -> {node, sol (MeshInstance3D), plantes (Node3D), sig, sig_plantes, rect}.
var _champs: Dictionary = {}
## Engins : clé "ferme:i" -> Node3D.
var _engins: Dictionary = {}
## Bêtes : bid -> {esp: [{node, pos, cible, vit}]}.
var _betes: Dictionary = {}
var _tick := 0.0
var _mat_sol: ShaderMaterial
## Matériau des plantes des champs : celui des plantes du terrain, sans le
## réglage par instance (« culture ») qui remplit vite le tampon des variables
## d'instance ; la taille et la couleur passent par les instances.
var _mat_plantes: ShaderMaterial
const PARAMS_PLANTES := ["palette", "roles", "vent", "feuilles", "automne", "printemps", "herbe_seche", "fleurs", "neige"]
var _rng := RandomNumberGenerator.new()


func setup(a: Agriculture, w: TerrainWorld) -> void:
	agri = a
	world = w
	agri.visuels = self
	agri.changed.connect(func() -> void: _tick = 1.0)
	if world != null:
		world.chunk_rebuilt.connect(func(_k: Vector2i) -> void: _hauteurs_a_refaire = true)
	_mat_sol = ShaderMaterial.new()
	_mat_sol.shader = preload("res://scripts/agriculture/champ.gdshader")
	_mat_sol.set_shader_parameter("sols", Sols.texture())
	_mat_sol.set_shader_parameter("premiere_couleur", Sols.PREMIERE_COULEUR)
	var sh := Shader.new()
	sh.code = (preload("res://scripts/terre/plante.gdshader") as Shader).code.replace(
		"instance uniform int culture = -1;", "uniform int culture = -1;")
	_mat_plantes = ShaderMaterial.new()
	_mat_plantes.shader = sh
	_copie_saison()


## La saison (feuilles, neige…) des plantes du terrain, recopiée sur celles des champs.
func _copie_saison() -> void:
	var src := Plantes.materiau()
	for k in PARAMS_PLANTES:
		var v: Variant = src.get_shader_parameter(k)
		if v != null:
			_mat_plantes.set_shader_parameter(k, v)


var _hauteurs_a_refaire := false


## Tout refaire (champs ajoutés, supprimés, partie chargée).
func refait() -> void:
	for id in _champs.keys():
		if not agri.champs.has(id) or _champs[id].rect != agri.champs[id].r:
			(_champs[id].node as Node).queue_free()
			_champs.erase(id)
	_tick = 1.0


func _camera_pos() -> Vector3:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	return cam.global_position if cam else Vector3.ZERO


func _process(delta: float) -> void:
	if agri == null:
		return
	_tick += delta
	if _tick >= 0.5:
		_tick = 0.0
		mise_a_jour()
	_bouge_engins()
	_bouge_betes(delta)


## Met à jour le sol, les plantes, les engins et les bêtes (appelé deux fois par seconde).
func mise_a_jour() -> void:
	var cam := _camera_pos()
	_copie_saison()
	for id in agri.champs:
		_maj_champ(int(id), cam)
	for id in _champs.keys():
		if not agri.champs.has(id):
			(_champs[id].node as Node).queue_free()
			_champs.erase(id)
	if _hauteurs_a_refaire:
		_hauteurs_a_refaire = false
		for id in _champs:
			_champs[id].sig_sol = ""
	_maj_engins(cam)
	_maj_betes(cam)


# --- Sol et plantes ------------------------------------------------------------------

## Couche de sol d'un champ dans son état actuel, et maturité (0 à 1).
func couche_de(ch: Dictionary) -> Array:
	var cult := String(ch.sc) if String(ch.sc) != "" else String(ch.cult)
	var c := AgriDonnees.culture(cult)
	var couche_culture := Sols.COUCHES.find(String(c.get("couche", "ble")))
	match String(ch.etat):
		"friche":
			return [Sols.HERBE, 0.0]
		"laboure":
			return [Sols.LABOUR, 0.0]
		"chaume":
			return [Sols.CHAUME, 0.0]
		"pousse":
			if bool(c.get("permanente", false)):
				return [couche_culture, 0.0]
			if float(ch.cr) < 0.22:
				return [Sols.LEVEE, 0.0]
			return [couche_culture, clampf((float(ch.cr) - 0.6) / 0.4, 0.0, 1.0)]
		"mur":
			return [couche_culture, 1.0]
	return [Sols.HERBE, 0.0]


## Couche après le travail en cours (même chose s'il ne change pas le sol).
func couche_apres(ch: Dictionary) -> Array:
	match String(ch.tache):
		"labour":
			return [Sols.LABOUR, 0.0]
		"semis":
			var c := AgriDonnees.culture(String(ch.cult))
			if bool(c.get("permanente", false)):
				return [Sols.COUCHES.find(String(c.couche)), 0.0]
			return [Sols.LEVEE, 0.0]
		"recolte":
			var c := AgriDonnees.culture(String(ch.sc))
			if bool(c.get("permanente", false)):
				return [Sols.COUCHES.find("pre_fauche"), 0.0]
			return [Sols.CHAUME, 0.0]
	return couche_de(ch)


static func rangs_z(r: Rect2i) -> bool:
	return r.size.y > r.size.x


func _maj_champ(id: int, cam: Vector3) -> void:
	var ch: Dictionary = agri.champs[id]
	var r: Rect2i = ch.r
	if not _champs.has(id):
		var n := Node3D.new()
		n.name = "Champ%d" % id
		add_child(n)
		var sol := MeshInstance3D.new()
		sol.name = "Sol"
		sol.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sol.material_override = _mat_sol.duplicate()
		n.add_child(sol)
		var pl := Node3D.new()
		pl.name = "Plantes"
		n.add_child(pl)
		_champs[id] = {"node": n, "sol": sol, "plantes": pl, "sig_sol": "", "sig": "", "rect": r}
	var e: Dictionary = _champs[id]
	var sol: MeshInstance3D = e.sol
	if String(e.sig_sol) == "":
		sol.mesh = _maille_sol(r)
		e.sig_sol = "ok"
	var m := sol.material_override as ShaderMaterial
	var avant := couche_de(ch)
	var apres := couche_apres(ch)
	var ha := Agriculture.surface(ch)
	var avance := clampf(float(ch.fait) / maxf(ha, 0.0001), 0.0, 1.0) if String(ch.tache) != "" else 0.0
	m.set_shader_parameter("couche_avant", int(avant[0]))
	m.set_shader_parameter("maturite", float(avant[1]))
	m.set_shader_parameter("couche_apres", int(apres[0]))
	m.set_shader_parameter("maturite_apres", float(apres[1]))
	m.set_shader_parameter("avance", avance)
	m.set_shader_parameter("rect", Vector4(r.position.x, r.position.y, r.size.x, r.size.y))
	m.set_shader_parameter("rangs_z", rangs_z(r))
	var cult := String(ch.sc) if String(ch.sc) != "" else String(ch.cult)
	m.set_shader_parameter("cereale_seche", cult in ["mais", "riz"])
	m.set_shader_parameter("base_detail", Vector3(0.34, 0.5, 0.2) if String(ch.etat) != "friche" else Vector3(0.42, 0.5, 0.24))
	# Plantes : refaites quand la culture ou sa taille changent nettement.
	var proche := Vector2(cam.x, cam.z).distance_to(Vector2(r.get_center())) < PLANTES_LOIN + r.size.length() * 0.5
	var sig := "%s|%s|%d|%d|%d" % [String(ch.etat), cult, roundi(float(ch.cr) * 20.0), roundi(avance * 20.0),
		int(ch.get("bottes", -1))]
	if not proche:
		sig = "loin"
	if sig != String(e.sig):
		e.sig = sig
		_refait_plantes(e.plantes, ch, avance, proche)


## Maillage du sol : une face par case (ou par carré de quelques cases pour les
## très grands champs), à 4 cm au-dessus du terrain.
func _maille_sol(r: Rect2i) -> ArrayMesh:
	var pas := maxi(1, ceili(sqrt(float(r.size.x * r.size.y) / 60000.0)))
	var h := world.cell_heights(r) if world != null else PackedFloat32Array()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	for z in range(0, r.size.y, pas):
		for x in range(0, r.size.x, pas):
			var y := 0.0
			if not h.is_empty():
				y = h[x + z * r.size.x]
				if is_nan(y):
					y = 0.0
			y += 0.04
			var x0 := float(r.position.x + x)
			var z0 := float(r.position.y + z)
			var x1 := float(r.position.x + mini(x + pas, r.size.x))
			var z1 := float(r.position.y + mini(z + pas, r.size.y))
			verts.append_array([Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1),
				Vector3(x0, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1)])
			for i in 6:
				normals.append(Vector3.UP)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	if not verts.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


func _hauteur(x: float, z: float) -> float:
	if world == null:
		return 0.0
	var y := world.cell_height(Vector2i(floori(x), floori(z)))
	return 0.0 if is_nan(y) else y


## Plantes du champ, en rangs, par carrés de BLOC m (chacun disparaît au loin).
func _refait_plantes(parent: Node3D, ch: Dictionary, avance: float, proche: bool) -> void:
	for c in parent.get_children():
		parent.remove_child(c)
		c.queue_free()
	if not proche:
		return
	var r: Rect2i = ch.r
	var cult := String(ch.sc) if String(ch.sc) != "" else String(ch.cult)
	var c := AgriDonnees.culture(cult)
	var etat := String(ch.etat)
	var z_rangs := rangs_z(r)
	# Bottes de paille sur le chaume pressé.
	if etat == "chaume" and int(ch.get("bottes", -1)) >= 0 and float(ch.paille) <= 0.0:
		_pose_bottes(parent, r)
		return
	if not etat in ["pousse", "mur"]:
		return
	var esp := Plantes.id(String(c.get("plante", "")))
	if esp < 0:
		return
	var mesh := Plantes.mesh(esp)
	if mesh == null:
		return
	var taille := 1.0 if etat == "mur" else clampf(float(ch.cr) * 1.25, 0.08, 1.0)
	if bool(c.get("permanente", false)):
		taille = clampf(0.3 + float(ch.cr) * 0.7, 0.3, 1.0)
	var maturite := 1.0 if etat == "mur" else clampf((float(ch.cr) - 0.6) / 0.4, 0.0, 1.0)
	var mur_col: Color = c.get("couleur", Color("d9b44a"))
	var teinte := Color(1, 1, 1).lerp(Color(mur_col.r * 1.6, mur_col.g * 1.6, mur_col.b * 1.6), maturite * 0.7)
	var pas := 1.0 / sqrt(maxf(float(c.get("densite", 0.5)), 0.02))
	# Récolte en cours : la bande fauchée n'a plus de plantes.
	var fauche := avance if String(ch.tache) == "recolte" else 0.0
	var largeur := float(r.size.x if z_rangs else r.size.y)
	var bande := 12.0
	var n_bandes := maxf(ceilf(largeur / bande), 1.0)
	var vent := Plantes.vent(esp)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(ch.id) * 7919
	for bz in range(r.position.y, r.end.y, BLOC):
		for bx in range(r.position.x, r.end.x, BLOC):
			var xforms: Array[Transform3D] = []
			var cols := PackedColorArray()
			var z := float(bz) + pas * 0.5
			while z < minf(bz + BLOC, r.end.y):
				var x := float(bx) + pas * 0.5
				while x < minf(bx + BLOC, r.end.x):
					var lx := x - r.position.x
					var lz := z - r.position.y
					var travers := lx if z_rangs else lz
					var le_long := (lz / r.size.y) if z_rangs else (lx / r.size.x)
					var b := floorf(travers / bande)
					var fait := fauche * n_bandes
					var coupe := b < floorf(fait) or (b == floorf(fait) and \
						(le_long if fmod(b, 2.0) < 1.0 else 1.0 - le_long) < fmod(fait, 1.0))
					if not coupe:
						var j := Vector3(rng.randf_range(-0.2, 0.2), 0.0, rng.randf_range(-0.2, 0.2)) * pas
						var p := Vector3(x, _hauteur(x, z), z) + j
						var s := taille * rng.randf_range(0.85, 1.1)
						var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s))
						xforms.append(Transform3D(basis, p))
						var v := rng.randf_range(0.93, 1.05)
						cols.append(Color(teinte.r * v, teinte.g * v, teinte.b * v))
					x += pas
				z += pas
			if xforms.is_empty():
				continue
			var inst := TerrainWorld._pose_multimesh(parent, mesh, xforms, cols, vent, _mat_plantes)
			inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			inst.visibility_range_end = PLANTES_LOIN
			inst.visibility_range_end_margin = 10.0


func _pose_bottes(parent: Node3D, r: Rect2i) -> void:
	var mesh := Decors.mesh("botte_ronde")
	if mesh == null:
		return
	var xforms: Array[Transform3D] = []
	var cols := PackedColorArray()
	var rng := RandomNumberGenerator.new()
	rng.seed = r.position.x * 31 + r.position.y
	var z := float(r.position.y) + 12.0
	while z < r.end.y - 4:
		var x := float(r.position.x) + 10.0
		while x < r.end.x - 4:
			var p := Vector3(x + rng.randf_range(-3, 3), 0.0, z + rng.randf_range(-3, 3))
			p.y = _hauteur(p.x, p.z)
			xforms.append(Transform3D(Basis(Vector3.UP, rng.randf() * PI), p))
			cols.append(Color.WHITE)
			x += 24.0
		z += 24.0
	var inst := TerrainWorld._pose_multimesh(parent, mesh, xforms, cols, 0.0, null)
	inst.material_override = Decors.materiau()
	inst.visibility_range_end = 900.0


# --- Engins ----------------------------------------------------------------------------

## Position (x, z) et cap de l'engin au travail sur un champ.
static func position_engin(ch: Dictionary) -> Array:
	var r: Rect2i = ch.r
	var z_rangs := rangs_z(r)
	var ha := Agriculture.surface(ch)
	var avance := clampf(float(ch.fait) / maxf(ha, 0.0001), 0.0, 0.9999)
	var largeur := float(r.size.x if z_rangs else r.size.y)
	var longueur := float(r.size.y if z_rangs else r.size.x)
	var bande := 12.0
	var n_bandes := maxf(ceilf(largeur / bande), 1.0)
	var fait := avance * n_bandes
	var b := floorf(fait)
	var aller := fmod(b, 2.0) < 1.0
	var le_long := fmod(fait, 1.0) * longueur
	if not aller:
		le_long = longueur - le_long
	var travers := minf(b * bande + bande * 0.5, largeur - 1.0)
	var p := Vector2(r.position) + (Vector2(travers, le_long) if z_rangs else Vector2(le_long, travers))
	var dir := (Vector2(0, 1) if z_rangs else Vector2(1, 0)) * (1.0 if aller else -1.0)
	return [p, dir]


func _maj_engins(cam: Vector3) -> void:
	var vus := {}
	for bid in agri.fermes:
		var f: Dictionary = agri.fermes[bid]
		var travail: Array = f.get("travail", [])
		for i in travail.size():
			var w: Dictionary = travail[i]
			if not agri.champs.has(int(w.champ)):
				continue
			var ch: Dictionary = agri.champs[int(w.champ)]
			var pe := position_engin(ch)
			var p: Vector2 = pe[0]
			if Vector2(cam.x, cam.z).distance_to(p) > ENGINS_LOIN:
				continue
			var cle := "%d:%d" % [bid, i]
			var sig := "%s|%s" % [String(w.tache), String(w.get("cult", ""))]
			if _engins.has(cle) and String(_engins[cle].get_meta("sig", "")) != sig:
				(_engins[cle] as Node).queue_free()
				_engins.erase(cle)
			if not _engins.has(cle):
				_engins[cle] = _fait_engin(String(w.tache), String(w.get("cult", "")))
				_engins[cle].set_meta("sig", sig)
				add_child(_engins[cle])
			var n: Node3D = _engins[cle]
			n.set_meta("champ", int(w.champ))
			vus[cle] = true
	for cle in _engins.keys():
		if not vus.has(cle):
			(_engins[cle] as Node).queue_free()
			_engins.erase(cle)


## Un engin : le tracteur (ou la machine automotrice) et son outil derrière.
func _fait_engin(tache: String, cult: String) -> Node3D:
	var n := Node3D.new()
	n.name = "Engin"
	var types := AgriDonnees.machines_pour(tache, cult)
	var moteur := "tracteur"
	var outil := ""
	for t in types:
		if bool(AgriDonnees.machine(t).get("automoteur", false)):
			moteur = t
		else:
			outil = t
	var mod_moteur := String(AgriDonnees.machine(moteur).get("modele", "tracteur"))
	var m := Decors.mesh(mod_moteur)
	if m:
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.material_override = Decors.materiau()
		if moteur == "arracheuse":
			mi.scale = Vector3(0.8, 0.9, 0.8)
		n.add_child(mi)
	var mod_outil := String(AgriDonnees.machine(outil).get("modele", "")) if outil != "" else ""
	if outil != "":
		var mo := Decors.mesh(mod_outil) if mod_outil != "" else null
		var oi := MeshInstance3D.new()
		if mo:
			oi.mesh = mo
			oi.material_override = Decors.materiau()
		else:
			# Outil sans modèle : un plateau large de la couleur de la machine.
			var b := BoxMesh.new()
			b.size = Vector3(6.0 if outil in ["semoir", "pulverisateur", "epandeur", "faucheuse"] else 3.0, 0.7, 1.6)
			oi.mesh = b
			var mat := StandardMaterial3D.new()
			mat.albedo_color = {"semoir": Color("d62828"), "planteuse": Color("e76f51"), "pulverisateur": Color("2a9d8f"),
				"epandeur": Color("1d3557"), "faucheuse": Color("f4a261"), "presse": Color("8ab17d")}.get(outil, Color("6c757d"))
			oi.material_override = mat
			oi.position.y = 0.6
		oi.position.z = 3.3
		n.add_child(oi)
	# On peut monter à bord (vue au sol, E) : voir ABord.
	n.add_to_group(ABord.GROUPE)
	var nom := String(AgriDonnees.machine(moteur).get("name", "Tracteur"))
	if outil != "":
		nom += " et " + String(AgriDonnees.machine(outil).get("name", outil)).to_lower()
	n.set_meta("nom_bord", nom)
	var nom_tache := String(AgriDonnees.TACHES.get(tache, {}).get("name", tache))
	n.set_meta("infos_bord", func() -> String:
		var id := int(n.get_meta("champ", -1))
		if not agri.champs.has(id):
			return "Aux champs · " + nom_tache
		var ch: Dictionary = agri.champs[id]
		var fait := clampf(float(ch.get("fait", 0.0)) / maxf(Agriculture.surface(ch), 0.0001), 0.0, 1.0)
		return "Aux champs · %s · %d %% du champ fait" % [nom_tache, roundi(fait * 100.0)])
	return n


func _bouge_engins() -> void:
	for cle in _engins:
		var n: Node3D = _engins[cle]
		var id := int(n.get_meta("champ", -1))
		if not agri.champs.has(id):
			continue
		var pe := position_engin(agri.champs[id])
		var p: Vector2 = pe[0]
		var d: Vector2 = pe[1]
		var cible := Vector3(p.x, _hauteur(p.x, p.y), p.y)
		n.position = n.position.lerp(cible, 0.15) if n.position.distance_to(cible) < 30.0 else cible
		# L'avant des modèles regarde vers −Z.
		n.basis = Basis.looking_at(Vector3(d.x, 0.0, d.y), Vector3.UP)


# --- Bêtes ------------------------------------------------------------------------------

## Où vont les bêtes d'une ferme : rectangles de pâture, sinon un enclos autour de la ferme.
func _zones_betes(bid: int) -> Array:
	var out := []
	var mois := int(agri.local_time(agri.clock).month) if agri.clock > 0.0 else 6
	if AgriDonnees.saison_herbe(mois, agri.lat(), agri.climat()):
		for id in agri.champs_de(bid):
			var ch: Dictionary = agri.champs[id]
			if bool(AgriDonnees.culture(String(ch.cult)).get("paturage", false)) and String(ch.etat) in ["pousse", "mur"]:
				out.append(ch.r)
	if out.is_empty() and agri.buildings.buildings.has(bid):
		var r := agri.buildings._rect_of(agri.buildings.buildings[bid])
		out.append(r.grow(4))
	return out


func _maj_betes(cam: Vector3) -> void:
	for bid in _betes.keys():
		if not agri.fermes.has(bid):
			_vide_betes(bid)
	for bid in agri.fermes:
		var f: Dictionary = agri.fermes[bid]
		var p := agri._pos_of(bid)
		if Vector2(cam.x, cam.z).distance_to(Vector2(p.x, p.z)) > BETES_LOIN + 300.0 or not agri.buildings.buildings.has(bid):
			_vide_betes(bid)
			continue
		var zones := _zones_betes(bid)
		if not _betes.has(bid):
			_betes[bid] = {}
		var groupes: Dictionary = _betes[bid]
		for e in groupes.keys():
			if not f.betes.has(e):
				for a in groupes[e]:
					(a.node as Node).queue_free()
				groupes.erase(e)
		for e in f.betes:
			var voulu := mini(int(f.betes[e]), BETES_MAX if e != "poule" else BETES_MAX * 2)
			if not groupes.has(e):
				groupes[e] = []
			var liste: Array = groupes[e]
			var modeles: Array = AgriDonnees.espece(e).modeles
			while liste.size() < voulu:
				var m := Decors.mesh(String(modeles[liste.size() % modeles.size()]))
				var mi := MeshInstance3D.new()
				mi.mesh = m
				mi.material_override = Decors.materiau()
				add_child(mi)
				var pos := _point_dans(zones)
				mi.position = Vector3(pos.x, _hauteur(pos.x, pos.y), pos.y)
				liste.append({"node": mi, "cible": _point_dans(zones), "zones": zones, "pause": _rng.randf_range(0.0, 8.0)})
			while liste.size() > voulu:
				(liste.pop_back().node as Node).queue_free()
			for a in liste:
				a.zones = zones
				# Rentrées (hiver) ou sorties (printemps) : on change d'endroit.
				var n: Node3D = a.node
				if not _dans(zones, Vector2(n.position.x, n.position.z)):
					var q := _point_dans(zones)
					n.position = Vector3(q.x, _hauteur(q.x, q.y), q.y)
					a.cible = _point_dans(zones)


func _vide_betes(bid: int) -> void:
	if not _betes.has(bid):
		return
	for e in _betes[bid]:
		for a in _betes[bid][e]:
			(a.node as Node).queue_free()
	_betes.erase(bid)


func _point_dans(zones: Array) -> Vector2:
	if zones.is_empty():
		return Vector2.ZERO
	var r: Rect2i = zones[_rng.randi() % zones.size()]
	return Vector2(_rng.randf_range(r.position.x + 2.0, r.end.x - 2.0), _rng.randf_range(r.position.y + 2.0, r.end.y - 2.0))


static func _dans(zones: Array, p: Vector2) -> bool:
	for r: Rect2i in zones:
		if Rect2(r).grow(2.0).has_point(p):
			return true
	return false


## Les bêtes broutent : elles marchent lentement vers un point, s'arrêtent, repartent.
func _bouge_betes(delta: float) -> void:
	for bid in _betes:
		for e in _betes[bid]:
			for a in _betes[bid][e]:
				var n: Node3D = a.node
				if float(a.pause) > 0.0:
					a.pause = float(a.pause) - delta
					continue
				var c: Vector2 = a.cible
				var p := Vector2(n.position.x, n.position.z)
				var d := c - p
				if d.length() < 0.5:
					a.cible = _point_dans(a.zones)
					a.pause = _rng.randf_range(3.0, 15.0)
					continue
				var v := 0.35 if e != "poule" else 0.25
				p += d.normalized() * minf(v * delta, d.length())
				n.position = Vector3(p.x, _hauteur(p.x, p.y), p.y)
				n.basis = Basis.looking_at(Vector3(d.x, 0.0, d.y), Vector3.UP)
