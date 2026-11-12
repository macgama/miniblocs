class_name MetiersVivants
extends Node3D
## Les habitants au travail, visibles dans la ville (touche K : vue métiers).
##
## - Vue en coupe : quand la caméra est proche, les bâtiments du catalogue qui
##   ont des employés s'ouvrent : toit et façade s'effacent, on voit le sol, des
##   murets, les postes de travail (pétrin, four, tableau, lits, caisses,
##   bureaux, machines…) et les employés présents qui font leurs gestes. Les
##   élèves sont à leur pupitre, les clients dans le magasin.
## - Dehors : les métiers d'extérieur (champs, forêt, carrière, port, marché)
##   et les gestes d'extérieur (garde devant le commissariat, pompier qui
##   vérifie son camion, agent qui balaie) se voient sans vue en coupe.
## - Enseigne « Ouvert » / « Fermé » et rideau de fer selon le personnel
##   présent ; pancarte « Manque de personnel » au-dessus des bâtiments en
##   sous-effectif ou fermés faute d'employés (voir Effectif).
## - Clic sur un employé : sa fiche (Population.person_clicked).

## Distance de la caméra (rig) en dessous de laquelle la vue en coupe s'ouvre.
const COUPE_ZOOM := 34.0
## Rayon autour du point visé dans lequel les bâtiments s'ouvrent (m).
const COUPE_RAYON := 45.0
## Rayon des employés d'extérieur et des enseignes.
const RAYON := 110.0
## Rayon des pancartes « Manque de personnel ».
const RAYON_PANCARTES := 220.0
const MAX_FIGURINES := 160
const MAX_PAR_BATIMENT := 14
const MAX_VISITEURS := 10
const MAX_ELEVES := 48
const REFRESH := 0.8

## Postes contre le mur du fond : l'employé lui fait face.
const POSTES_MUR := ["four", "etagere", "rack", "tableau", "ecran", "machine", "creuset", "meule", "derrick", "camion"]

var pop: Population
var buildings: BuildingSystem
var world: TerrainWorld
var ambiance: DayNight
var rig: Node3D
## Habitants dans les bâtiments en murs fins (leurs employés sont aussi cliquables).
var occupants: Occupants

## Vue métiers active (touche K).
var enabled := true
## Ouvrir les bâtiments en coupe quand la caméra est proche.
var coupe_auto := true

## bid → {node: Node3D (coupe ou null), enseigne: Label3D, pancarte: Label3D, rideau: MeshInstance3D}
var _bats: Dictionary = {}
## pid → Figurine
var _figs: Dictionary = {}
## Bâtiments ouverts en coupe en ce moment.
var coupes: Array = []
## Ce qui est montré (tests) : [{pid, bid, geste, ou: "coupe"|"dehors"|"interieur", pos}]
var shown: Array = []
var _timer := 0.0
var _t := 0.0
var _mat_coupe: Material


func setup(p: Population, b: BuildingSystem, amb: DayNight, camera_rig: Node3D) -> void:
	pop = p
	buildings = b
	world = b.world
	ambiance = amb
	rig = camera_rig
	pop.extra_person_pick = pick
	_mat_coupe = LpKit.vertex_material(0.9)
	buildings.removed.connect(func(bid: int) -> void: _oublier(bid))


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.physical_keycode == KEY_K and not k.ctrl_pressed and not k.alt_pressed:
		if k.shift_pressed:
			coupe_auto = not coupe_auto
			pop.message.emit("Vue en coupe automatique : %s." % ("oui" if coupe_auto else "non"))
		else:
			set_enabled(not enabled)
			pop.message.emit("Vue métiers : %s." % ("on voit les habitants au travail" if enabled else "coupée"))
		get_viewport().set_input_as_handled()


func set_enabled(on: bool) -> void:
	enabled = on
	if not on:
		_tout_cacher()
	else:
		_timer = 0.0


func _process(delta: float) -> void:
	if pop == null:
		return
	if ambiance == null or ambiance.speed_index > 0:
		_t += delta
	if not enabled:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = REFRESH
		refresh()
	for pid in _figs:
		var f: Figurine = _figs[pid]
		if f.visible:
			f.animer(_t)


func _focus() -> Vector3:
	if rig != null:
		return rig.global_position
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	return cam.global_position if cam != null else Vector3.ZERO


func _zoom() -> float:
	if rig != null and "_distance" in rig:
		return float(rig.get("_distance"))
	return 999.0


func _unix() -> float:
	return ambiance.unix_time if ambiance != null else 0.0


## Recalcule les bâtiments ouverts, les employés montrés, les enseignes.
func refresh() -> void:
	shown.clear()
	var eff := pop.effectif
	if eff == null or buildings == null:
		return
	var focus := _focus()
	var f2 := Vector2(focus.x, focus.z)
	var zoom_ok := coupe_auto and _zoom() <= COUPE_ZOOM
	var vus := {}
	var figs_vues := {}
	var nouvelles_coupes := []
	for bid in pop.known:
		if not buildings.buildings.has(bid) or not eff.concerne(bid):
			continue
		var info: Dictionary = pop.known[bid]
		var c: Vector3 = info.pos
		var d := Vector2(c.x, c.z).distance_to(f2)
		if d > RAYON_PANCARTES:
			continue
		vus[bid] = true
		_pancarte(bid, eff, d <= RAYON_PANCARTES)
		if d > RAYON:
			_enseigne(bid, eff, false)
			continue
		_enseigne(bid, eff, true)
		var type_id := String(info.t)
		var dehors := Gestes.BATIMENTS_DEHORS.has(type_id) or Gestes.BATIMENTS_DEHORS.has(String(BuildingCatalog.get_type(type_id).get("arch", "")))
		var presents := eff.presents(bid)
		var coupe := not dehors and zoom_ok and d <= COUPE_RAYON + float(info.rect.size.length()) * 0.5 \
			and not buildings.en_chantier(bid) and not presents.is_empty()
		if coupe:
			nouvelles_coupes.append(bid)
			_ouvrir(bid)
		else:
			_fermer_coupe(bid)
		_placer(bid, presents, coupe, dehors, figs_vues)
	for bid in _bats.keys():
		if not vus.has(bid):
			_oublier(bid)
	coupes = nouvelles_coupes
	for pid in _figs.keys():
		if not figs_vues.has(pid):
			(_figs[pid] as Node).queue_free()
			_figs.erase(pid)


# --- Figurines ----------------------------------------------------------------------

func _figurine(pid: int, met: String, enfant := false) -> Figurine:
	if _figs.has(pid):
		return _figs[pid]
	var f := Figurine.creer(pid, met, enfant, pop)
	add_child(f)
	_figs[pid] = f
	return f


## Place les employés (et, en coupe, les élèves et les clients) d'un bâtiment.
func _placer(bid: int, presents: Array, coupe: bool, dehors_bat: bool, figs_vues: Dictionary) -> void:
	var node := buildings.node_of(bid)
	if node == null:
		return
	var b: Dictionary = buildings.buildings[bid]
	var t := BuildingCatalog.get_type(String(b.t))
	var w := float(t.get("w", 8))
	var dd := float(t.get("d", 8))
	var base := node.global_transform
	presents.sort()
	# Qui travaille dedans, qui dehors.
	var dedans := []
	var dehors_l := []
	for pid in presents:
		var met := String(pop.persons[pid].met)
		var g := Gestes.courant(int(pid), met, _unix(), String(b.t))
		if dehors_bat or Gestes.dehors(g):
			if dehors_l.size() < MAX_PAR_BATIMENT:
				dehors_l.append([pid, g])
		elif coupe and dedans.size() < MAX_PAR_BATIMENT:
			dedans.append([pid, g])
	var grille := _grille(dedans.size(), w, dd)
	var postes := []
	var classes := []
	var places := []
	for i in dehors_l.size():
		var xf := _place_dehors(i, w, dd, dehors_bat)
		places.append([dehors_l[i][0], dehors_l[i][1], xf, xf, true])
	for i in dedans.size():
		var r := _place_case(i, grille, w, dd, String(dedans[i][1]))
		places.append([dedans[i][0], dedans[i][1], r[0], r[1], false])
		if String(Gestes.info(String(dedans[i][1])).p) in ["tableau", "bureau_prof", "petite_table"] \
				or String(pop.persons[dedans[i][0]].met) == "enseignant":
			classes.append(r[2])
	for pl in places:
		var pid := int(pl[0])
		if _figs.size() >= MAX_FIGURINES and not _figs.has(pid):
			break
		var g: String = pl[1]
		var dehors: bool = pl[4]
		var gxf: Transform3D = base * (pl[2] as Transform3D)
		var pxf: Transform3D = base * (pl[3] as Transform3D)
		if dehors and world != null:
			var y := world.cell_height(Vector2i(floori(gxf.origin.x), floori(gxf.origin.z)))
			if not is_nan(y):
				gxf.origin.y = maxf(y, base.origin.y - 3.0)
				pxf.origin.y = gxf.origin.y
		var f := _figurine(pid, String(pop.persons[pid].met))
		if f.geste != g:
			f.regler(g)
		f.hauteur_assise = Accessoires.ASSISE
		f.global_transform = gxf
		f.visible = true
		figs_vues[pid] = true
		postes.append([g, pxf])
		shown.append({"pid": pid, "bid": bid, "geste": g, "ou": "dehors" if dehors else "coupe", "pos": gxf.origin})
	_postes_du_batiment(bid, postes, coupe or not dehors_l.is_empty())
	if coupe:
		_eleves_et_clients(bid, base, w, dd, classes, figs_vues)
	elif _bats.has(bid) and _bats[bid].has("meshes"):
		var meshes: Dictionary = _bats[bid].meshes
		for k in meshes.keys():
			if String(k).begins_with("eleve_"):
				(meshes[k] as Node).queue_free()
				meshes.erase(k)


## Découpe le plancher en cases (ateliers, salles de classe, chambres) : une par employé.
static func _grille(n: int, w: float, d: float) -> Dictionary:
	n = maxi(n, 1)
	var cols := clampi(ceili(sqrt(float(n) * w / maxf(d, 1.0))), 1, n)
	var rows := ceili(float(n) / cols)
	return {"cols": cols, "rows": rows, "cw": (w - 0.6) / cols, "cd": (d - 0.6) / rows}


## Case n° i : [place de l'employé, place de son poste, case {x, fond, cw, cd}]
## (repère du bâtiment : façade vers −Z, fond vers +Z).
func _place_case(i: int, gr: Dictionary, w: float, d: float, g: String) -> Array:
	var col := i % int(gr.cols)
	var row := i / int(gr.cols)
	var cw := float(gr.cw)
	var cd := float(gr.cd)
	var x := -w * 0.5 + 0.3 + cw * (float(col) + 0.5)
	var fond := d * 0.5 - 0.3 - cd * float(row)
	var info := Gestes.info(g)
	var mur := POSTES_MUR.has(String(info.p))
	var face_salle := String(info.a) in ["parler", "surveiller", "declamer", "sauter"]
	var z := fond - 0.3 - 1.45
	var yaw := 0.0
	if not mur:
		# Comptoir, lit, bureau… : l'employé tourne le dos au fond, le poste devant lui.
		z = fond - 0.5
		yaw = PI
		if Accessoires.poste_assis(String(info.p)):
			z = fond - 0.4
	z = clampf(z, -d * 0.5 + 1.2, d * 0.5 - 0.5)
	var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(x, 0.05, z))
	var pxf := xf
	if mur and face_salle:
		# Il fait face à la salle, le tableau (ou l'écran) dans son dos.
		xf = Transform3D(Basis(Vector3.UP, PI), Vector3(x, 0.05, fond - 0.3 - 2.0))
		pxf = Transform3D(Basis.IDENTITY, Vector3(x, 0.05, fond - 0.3 - 1.45))
	return [xf, pxf, {"x": x, "fond": fond, "cw": cw, "cd": cd}]


## Emplacement n° i autour du bâtiment (dehors). champs : pas côté rue, plus loin.
func _place_dehors(i: int, w: float, d: float, champs: bool) -> Transform3D:
	const SPOTS := [[-0.3, -1, 0.0], [0.3, -1, 0.0], [1, -0.2, -PI * 0.5], [-1, 0.2, PI * 0.5], [0.0, 1, PI],
		[1, 0.4, -PI * 0.5], [-1, -0.4, PI * 0.5], [-0.35, 1, PI]]
	const SPOTS_CHAMPS := [[0.0, 1, PI], [1, 0.2, -PI * 0.5], [-1, 0.2, PI * 0.5], [0.45, 1, PI], [-0.45, 1, PI],
		[1, 0.6, -PI * 0.5], [-1, 0.6, PI * 0.5]]
	var liste: Array = SPOTS_CHAMPS if champs else SPOTS
	var s: Array = liste[i % liste.size()]
	var loin := 2.6 + float(i / liste.size()) * 3.0 + (5.0 if champs else 0.0)
	var x := float(s[0]) * w * 0.5
	var z := float(s[1]) * d * 0.5
	if absf(float(s[0])) >= 1.0:
		x += signf(float(s[0])) * loin
	else:
		z += signf(float(s[1])) * loin
	# Regarde vers l'extérieur (le poste est devant lui, loin du mur).
	var yaw := atan2(x, z) if champs else float(s[2]) + PI
	return Transform3D(Basis(Vector3.UP, yaw), Vector3(x, 0.0, z))


## Élèves à leur pupitre, dans la salle de leur enseignant, et clients en coupe.
func _eleves_et_clients(bid: int, base: Transform3D, w: float, d: float, classes: Array, figs_vues: Dictionary) -> void:
	var here := pop.present_in(bid)
	here.sort()
	var eleves := []
	var clients := []
	for pid in here:
		var k := String(pop.activity(pop.persons[pid]).kind)
		if k == "ecole":
			eleves.append(pid)
		elif k == "courses" or k == "loisir":
			clients.append(pid)
	var n := 0
	if not classes.is_empty():
		var par_classe := []
		for c in classes:
			par_classe.append(0)
		for i in eleves.size():
			if n >= MAX_ELEVES or _figs.size() >= MAX_FIGURINES:
				break
			var ci := i % classes.size()
			var c: Dictionary = classes[ci]
			var j := int(par_classe[ci])
			var cols := maxi(1, int((float(c.cw) - 0.8) / 1.15))
			var x := float(c.x) - float(c.cw) * 0.5 + 0.4 + (float(c.cw) - 0.8) * (float(j % cols) + 0.5) / float(cols)
			var z := float(c.fond) - 3.9 - float(j / cols) * 1.35
			if z < float(c.fond) - float(c.cd) + 0.5:
				continue
			par_classe[ci] = j + 1
			var pid := int(eleves[i])
			var petit := pop.age_of(pop.persons[pid]) < 12.0
			var f := _figurine(pid, "", petit)
			if f.geste != "eleve":
				f.regler("corriger")
				f.geste = "eleve"
				f._outil.mesh = Accessoires.outil("stylo")
			# Face au tableau (vers le fond).
			var xf := Transform3D(Basis.IDENTITY, Vector3(x, 0.05, z))
			f.hauteur_assise = Accessoires.ASSISE
			f.global_transform = base * xf
			f.visible = true
			figs_vues[pid] = true
			_poste_mesh(bid, "eleve_%d" % n, "pupitre", base * xf)
			shown.append({"pid": pid, "bid": bid, "geste": "eleve", "ou": "coupe", "pos": f.global_position})
			n += 1
	if _bats.has(bid) and _bats[bid].has("meshes"):
		var meshes: Dictionary = _bats[bid].meshes
		for k in meshes.keys():
			if String(k).begins_with("eleve_") and int(String(k).substr(6)) >= n:
				(meshes[k] as Node).queue_free()
				meshes.erase(k)
	var per_row := maxi(1, int((w - 2.0) / 1.7))
	for i in mini(clients.size(), MAX_VISITEURS):
		if _figs.size() >= MAX_FIGURINES:
			break
		var pid2 := int(clients[i])
		var x2 := -w * 0.5 + 1.0 + 1.7 * float(i % per_row) + 0.85
		var z2 := -d * 0.5 + 1.4 + float(i / per_row) * 1.4
		var f2 := _figurine(pid2, "", pop.age_of(pop.persons[pid2]) < 12.0)
		if f2.geste != "client":
			f2.regler("conseiller")
			f2.geste = "client"
			f2.anim = "client"
			f2.va_et_vient = 0.5
			f2._outil.mesh = null
		f2.global_transform = base * Transform3D(Basis(Vector3.UP, PI * 0.15 * float(i % 3 - 1)), Vector3(x2, 0.05, z2))
		f2.visible = true
		figs_vues[pid2] = true
		shown.append({"pid": pid2, "bid": bid, "geste": "client", "ou": "coupe", "pos": f2.global_position})


# --- Postes de travail ---------------------------------------------------------------

func _postes_du_batiment(bid: int, postes: Array, visible_: bool) -> void:
	var st: Dictionary = _bats.get(bid, {})
	var holder: Node3D = st.get("postes")
	if holder == null:
		holder = Node3D.new()
		add_child(holder)
		st["postes"] = holder
		st["meshes"] = {}
		_bats[bid] = st
	holder.visible = visible_
	var used := {}
	for i in postes.size():
		var g := String(postes[i][0])
		var nom := String(Gestes.info(g).p)
		if nom == "":
			continue
		_poste_mesh(bid, "poste_%d" % i, nom, postes[i][1])
		used["poste_%d" % i] = true
	var meshes: Dictionary = st.meshes
	for k in meshes.keys():
		if String(k).begins_with("poste_") and not used.has(k):
			(meshes[k] as Node).queue_free()
			meshes.erase(k)


func _poste_mesh(bid: int, cle: String, nom: String, xf: Transform3D) -> void:
	var st: Dictionary = _bats.get(bid, {})
	if not st.has("postes"):
		_postes_du_batiment(bid, [], true)
		st = _bats[bid]
	var meshes: Dictionary = st.meshes
	var mi: MeshInstance3D = meshes.get(cle)
	if mi == null:
		mi = MeshInstance3D.new()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(st.postes as Node3D).add_child(mi)
		meshes[cle] = mi
	var m := Accessoires.poste(nom)
	if mi.mesh != m:
		mi.mesh = m
	mi.global_transform = xf
	mi.set_meta("poste", nom)


# --- Vue en coupe -------------------------------------------------------------------

## Remplace le bâtiment par sa coupe (sol, murets, porte).
func _ouvrir(bid: int) -> void:
	var st: Dictionary = _bats.get(bid, {})
	_bats[bid] = st
	var node := buildings.node_of(bid)
	if node == null:
		return
	if st.get("coupe") == null:
		var b: Dictionary = buildings.buildings[bid]
		var mi := MeshInstance3D.new()
		mi.name = "Coupe_%d" % bid
		mi.mesh = coupe_mesh(String(b.t))
		add_child(mi)
		st["coupe"] = mi
	var cm: MeshInstance3D = st.coupe
	cm.global_transform = node.global_transform
	cm.visible = true
	node.visible = false
	if st.has("rideau"):
		(st.rideau as Node3D).visible = false


func _fermer_coupe(bid: int) -> void:
	var st: Dictionary = _bats.get(bid, {})
	if st.get("coupe") != null:
		(st.coupe as Node).queue_free()
		st.erase("coupe")
		var node := buildings.node_of(bid)
		if node != null:
			node.visible = true


func _oublier(bid: int) -> void:
	if not _bats.has(bid):
		return
	_fermer_coupe(bid)
	var st: Dictionary = _bats[bid]
	for k in ["postes", "enseigne", "pancarte", "rideau"]:
		if st.get(k) != null:
			(st[k] as Node).queue_free()
	_bats.erase(bid)


func _tout_cacher() -> void:
	for bid in _bats.keys():
		_oublier(bid)
	for pid in _figs:
		(_figs[pid] as Node).queue_free()
	_figs.clear()
	coupes.clear()
	shown.clear()


static var _coupes: Dictionary = {}


## Maquette en coupe d'un type de bâtiment : dalle, murets de 1,1 m, ouverture de porte.
static func coupe_mesh(type_id: String) -> ArrayMesh:
	if _coupes.has(type_id):
		return _coupes[type_id]
	var t := BuildingCatalog.get_type(type_id)
	var w := float(t.get("w", 8))
	var d := float(t.get("d", 8))
	var cat := String(t.get("cat", ""))
	const SOLS := {"commerce": "d9c9a8", "services": "cfd8dc", "loisirs": "b08968", "sport": "8ab17d", "industrie": "9ea3a8", "production": "a39e93"}
	var sol := Color(String(SOLS.get(cat, "d6ccc2")))
	var mur := Color("efe6d8")
	var k := LpKit.new(3)
	k.jitter = 0.02
	k.box(Vector3(0, 0.0, 0), Vector3(w, 0.1, d), sol)
	# Carrelage léger.
	var n := int(w / 2.0)
	for i in n:
		k.box(Vector3(-w * 0.5 + (float(i) + 0.5) * w / n, 0.052, 0), Vector3(0.03, 0.005, d - 0.4), sol.darkened(0.08))
	var ep := 0.25
	var h := 1.1
	k.box(Vector3(0, h * 0.5, d * 0.5 - ep * 0.5), Vector3(w, h, ep), mur)
	k.box(Vector3(-w * 0.5 + ep * 0.5, h * 0.5, 0), Vector3(ep, h, d), mur)
	k.box(Vector3(w * 0.5 - ep * 0.5, h * 0.5, 0), Vector3(ep, h, d), mur)
	var porte := minf(1.8, w * 0.3)
	var seg := (w - porte) * 0.5
	k.box(Vector3(-w * 0.5 + seg * 0.5, h * 0.25, -d * 0.5 + ep * 0.5), Vector3(seg, h * 0.5, ep), mur)
	k.box(Vector3(w * 0.5 - seg * 0.5, h * 0.25, -d * 0.5 + ep * 0.5), Vector3(seg, h * 0.5, ep), mur)
	# Arase des murs (la tranche coupée, plus sombre).
	for z in [d * 0.5 - ep * 0.5]:
		k.box(Vector3(0, h + 0.01, z), Vector3(w, 0.02, ep + 0.02), mur.darkened(0.35))
	for x in [-w * 0.5 + ep * 0.5, w * 0.5 - ep * 0.5]:
		k.box(Vector3(x, h + 0.01, 0), Vector3(ep + 0.02, 0.02, d), mur.darkened(0.35))
	var m := k.commit({"base": LpKit.vertex_material(0.9)})
	_coupes[type_id] = m
	return m


# --- Enseignes et pancartes ----------------------------------------------------------

static func _a_enseigne(info: Dictionary) -> bool:
	return String(info.cat) in ["commerce", "loisirs", "services", "sport"]


func _enseigne(bid: int, eff: Effectif, proche: bool) -> void:
	var info: Dictionary = pop.known[bid]
	var st: Dictionary = _bats.get(bid, {})
	_bats[bid] = st
	if not proche or not _a_enseigne(info):
		if st.get("enseigne") != null:
			(st.enseigne as Node3D).visible = false
		if st.get("rideau") != null:
			(st.rideau as Node3D).visible = false
		return
	var node := buildings.node_of(bid)
	if node == null:
		return
	var b: Dictionary = buildings.buildings[bid]
	var t := BuildingCatalog.get_type(String(b.t))
	var d := float(t.get("d", 8))
	var w := float(t.get("w", 8))
	var ouvert := eff.ouvert_maintenant(bid)
	var lab: Label3D = st.get("enseigne")
	if lab == null:
		lab = Label3D.new()
		lab.font_size = 48
		lab.pixel_size = 0.006
		lab.outline_size = 10
		lab.double_sided = false
		add_child(lab)
		st["enseigne"] = lab
	lab.text = "OUVERT" if ouvert else "FERMÉ"
	lab.modulate = Color("52d17c") if ouvert else Color("ff5a5f")
	lab.outline_modulate = Color(0, 0, 0, 0.85)
	# Sur la façade, à côté de la porte (la façade regarde vers −Z local).
	lab.global_transform = node.global_transform * Transform3D(Basis(Vector3.UP, PI), Vector3(minf(1.6, w * 0.3), 2.3, -d * 0.5 - 0.08))
	lab.visible = true
	# Rideau de fer baissé quand le commerce est fermé (et pas ouvert en coupe).
	var rid: MeshInstance3D = st.get("rideau")
	var baisse := not ouvert and String(info.cat) == "commerce" and st.get("coupe") == null
	if baisse and rid == null:
		rid = MeshInstance3D.new()
		var k := LpKit.new(5)
		k.jitter = 0.01
		var rw := minf(w - 1.0, 4.0)
		k.box(Vector3(0, 1.15, 0), Vector3(rw, 2.3, 0.06), Color("8d949b"))
		for i in 10:
			k.box(Vector3(0, 0.1 + i * 0.23, -0.04), Vector3(rw, 0.03, 0.02), Color("6c737a"))
		k.box(Vector3(0, 2.38, 0), Vector3(rw + 0.1, 0.16, 0.2), Color("5c636a"))
		rid.mesh = k.commit({"base": LpKit.vertex_material(0.6)})
		add_child(rid)
		st["rideau"] = rid
	if rid != null:
		rid.visible = baisse
		if baisse:
			rid.global_transform = node.global_transform * Transform3D(Basis.IDENTITY, Vector3(0, 0, -d * 0.5 - 0.06))


func _pancarte(bid: int, eff: Effectif, proche: bool) -> void:
	var st: Dictionary = _bats.get(bid, {})
	_bats[bid] = st
	var e := eff.etat(bid)
	var montrer := proche and not e.is_empty() and bool(e.manque) and not buildings.en_chantier(bid)
	var lab: Label3D = st.get("pancarte")
	if not montrer:
		if lab != null:
			lab.visible = false
		return
	if lab == null:
		lab = Label3D.new()
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lab.font_size = 40
		lab.pixel_size = 0.012
		lab.outline_size = 12
		lab.no_depth_test = false
		lab.fixed_size = false
		add_child(lab)
		st["pancarte"] = lab
	var node := buildings.node_of(bid)
	var top := 6.0
	if node != null and node.mesh != null:
		top = node.mesh.get_aabb().end.y + 1.5
	lab.text = ("! Fermé : %s" % String(e.raison)) if bool(e.ferme) else ("! Manque de personnel (%d/%d)" % [int(e.embauches), int(e.prevus)])
	lab.modulate = Color("ff6b6b") if bool(e.ferme) else Color("ffb347")
	lab.outline_modulate = Color(0, 0, 0, 0.9)
	lab.global_position = (pop.known[bid].pos as Vector3) + Vector3(0, top, 0)
	lab.visible = true


# --- Clic --------------------------------------------------------------------------

## Employé (ou élève, client) visible sous la souris, ou -1.
func pick(screen: Vector2, cam: Camera3D) -> int:
	if not enabled or cam == null:
		return -1
	var best := -1
	var best_d := 20.0
	var toutes := _figs.duplicate()
	if occupants != null:
		toutes.merge(occupants.figurines)
	for pid in toutes:
		var f: Figurine = toutes[pid]
		if not f.visible or not f.is_inside_tree():
			continue
		var p := f.global_position + Vector3(0, 1.0, 0)
		if cam.is_position_behind(p):
			continue
		var d := cam.unproject_position(p).distance_to(screen)
		if d < best_d:
			best_d = d
			best = int(pid)
	return best
