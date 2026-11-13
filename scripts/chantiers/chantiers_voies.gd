class_name ChantiersVoies
extends Node
## Chantiers des voies posées par le joueur (routes, rails, chemins, canaux).
##
## Un tronçon neuf porte "ch" (avancement) et "chr" (heures de travail
## réelles) dans le réseau : il n'est pas praticable (itinéraires, trafic)
## avant la fin. Étapes visibles (Chantiers.ETAPES_VOIE) : piquets du tracé,
## décapage (terre), couche de grave, enrobé qui avance derrière le finisseur,
## puis marquage. Les engins suivent le front des travaux ; les ouvriers ne
## sont là que pendant les heures de travail, près de la caméra.
##
## Réparations (budget, tempêtes…) : chantier_reparation() ferme un tronçon le
## temps des travaux (cônes, rouleau) puis le rouvre.

const TERRE := Color("6b4f35")
const GRAVE := Color("7d766c")
const PIQUET := Color("f3f1ea")
const PIQUET_TETE := Color("e8562a")
const CONE := Color("ff6a13")
## Engins et ouvriers dessinés seulement près de la caméra (m).
const VUE_ENGINS := 600.0
const VUE_OUVRIERS := 240.0

static var instance: ChantiersVoies

var transport: TransportSystem
var network: TransportNetwork
var suivi: SuiviChantiers

## eid -> {"engins": Node3D, "ouvriers": [Figurine], "etape": String}
var _vus := {}
## eid -> {"noeud": Node3D}
var _reparations := {}
var _clock := 0.0


func setup(t: TransportSystem, s: SuiviChantiers) -> void:
	transport = t
	network = t.network
	suivi = s
	instance = self
	transport.edges_built.connect(_on_edges_built)
	network.changed.connect(_sync)
	_sync()


func _exit_tree() -> void:
	if instance == self:
		instance = null


static func cle(eid: int) -> String:
	return "voie:%d" % eid


## Heures de travail réelles d'un tronçon.
func heures(eid: int) -> float:
	var e: Dictionary = network.edges[eid]
	return Chantiers.heures_voie(String(e.t), float(e.len), float(e.width), e.st)


## Le joueur vient de poser ces tronçons : ils commencent par un chantier.
func _on_edges_built(edges: Array) -> void:
	commencer(edges)


func commencer(edges: Array) -> void:
	if Chantiers.instantanes():
		return
	for eid in edges:
		if not network.edges.has(eid):
			continue
		var e: Dictionary = network.edges[eid]
		e["ch"] = 0.0
		e["chr"] = heures(eid)
	_sync()
	for eid in edges:
		if network.edges.has(eid):
			transport.view.refresh_edge(eid)


## Met le suivi d'accord avec le réseau : tronçons coupés, démolis, chargés.
func _sync() -> void:
	if suivi == null:
		return
	for k in suivi.chantiers.keys():
		var ks := String(k)
		if not ks.begins_with("voie:"):
			continue
		var eid := int(ks.substr(5))
		if not network.edges.has(eid) or not network.edges[eid].has("ch"):
			suivi.annuler(ks)
			_oublier(eid)
	for eid in network.edges:
		var e: Dictionary = network.edges[eid]
		if e.has("ch") and not suivi.en_cours(cle(eid)):
			if float(e.get("chr", 0.0)) <= 0.0:
				e["chr"] = heures(eid)
			var id: int = eid
			suivi.commencer(cle(id), float(e.chr), func(av: float, et: Array) -> void: _maj(id, av, et),
				func() -> void: _fini(id), float(e.ch))
	for eid in _vus.keys():
		if not network.edges.has(eid) or not network.edges[eid].has("ch"):
			_oublier(eid)


func _maj(eid: int, av: float, _etape: Array) -> void:
	if not network.edges.has(eid):
		return
	network.edges[eid]["ch"] = av
	if transport.view != null:
		transport.view.refresh_edge(eid)
	if _vus.has(eid):
		_placer(eid)


func _fini(eid: int) -> void:
	_oublier(eid)
	if not network.edges.has(eid) or not network.edges[eid].has("ch"):
		return
	var e: Dictionary = network.edges[eid]
	e.erase("ch")
	e.erase("chr")
	transport.message.emit("Travaux terminés : %s ouverte à la circulation." % String(TransportTypes.get_type(String(e.t)).get("name", "voie")))
	# Tout le réseau se met à jour : carrefours, feux, trafic.
	network.changed.emit()


func _oublier(eid: int) -> void:
	var v: Dictionary = _vus.get(eid, {})
	_vus.erase(eid)
	if not v.is_empty():
		if is_instance_valid(v.engins):
			(v.engins as Node).queue_free()


## Avancement d'un tronçon (1 s'il est ouvert).
func avancement(eid: int) -> float:
	return float(network.edges[eid].get("ch", 1.0)) if network.edges.has(eid) else 1.0


func en_chantier(eid: int) -> bool:
	return network.edges.has(eid) and network.edges[eid].has("ch")


## Termine tous les chantiers de voies (tests, captures).
func finir_tout() -> void:
	for eid in network.edges.keys():
		if network.edges[eid].has("ch"):
			suivi.terminer(cle(eid))


# --- Réparations ----------------------------------------------------------------------

## Ferme un tronçon le temps d'une réparation (heures de travail réelles, coût
## payé au fil des travaux), puis le rouvre et appelle fini (facultatif).
## Renvoie false si impossible.
func chantier_reparation(eid: int, heures_reelles: float, cout := 0, fini := Callable()) -> bool:
	if not network.edges.has(eid) or _reparations.has(eid):
		return false
	var k := "reparation:%d" % eid
	network.closed_edges[eid] = "travaux"
	var n := _decor_reparation(eid)
	_reparations[eid] = {"noeud": n, "fini": fini}
	suivi.commencer(k, heures_reelles, Callable(), func() -> void: _fin_reparation(eid), 0.0, cout)
	return true


func _fin_reparation(eid: int) -> void:
	var r: Dictionary = _reparations.get(eid, {})
	_reparations.erase(eid)
	if not r.is_empty() and is_instance_valid(r.noeud):
		(r.noeud as Node).queue_free()
	if String(network.closed_edges.get(eid, "")) == "travaux":
		network.closed_edges.erase(eid)
	if not r.is_empty() and (r.fini as Callable).is_valid():
		(r.fini as Callable).call()


func en_reparation(eid: int) -> bool:
	return _reparations.has(eid)


func _decor_reparation(eid: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Reparation_%d" % eid
	var e: Dictionary = network.edges[eid]
	var L := float(e.len)
	var hw := float(e.width) * 0.5
	var mid := network.point_at(eid, L * 0.5)
	var tg := network.tangent_at(eid, L * 0.5)
	var r := Vector3(-tg.z, 0, tg.x).normalized()
	var k := TransportView.MeshKit.new()
	var n := maxi(3, int(minf(L, 60.0) / 4.0))
	for i in n:
		var s := L * 0.5 + (float(i) - n * 0.5) * 4.0
		var p := network.point_at(eid, clampf(s, 0.0, L))
		for side in [-1.0, 1.0]:
			_cone(k, p + r * side * (hw - 0.4))
	var mi := MeshInstance3D.new()
	mi.mesh = k.commit()
	mi.material_override = TransportView.make_material()
	root.add_child(mi)
	var rl := EnginsChantier.rouleau()
	rl.position = mid
	rl.rotation.y = atan2(tg.x, tg.z)
	root.add_child(rl)
	add_child(root)
	return root


static func _cone(k: TransportView.MeshKit, p: Vector3) -> void:
	k.box(p + Vector3(0, 0.05, 0), Vector3(0.45, 0.1, 0.45), Color("2b2b2b"))
	k.box(p + Vector3(0, 0.4, 0), Vector3(0.28, 0.6, 0.28), CONE)
	k.box(p + Vector3(0, 0.45, 0), Vector3(0.3, 0.12, 0.3), Color("f3f1ea"))


# --- Engins et ouvriers ------------------------------------------------------------------

func _process(delta: float) -> void:
	_clock += delta
	if network == null:
		return
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var travail := suivi != null and suivi.au_travail
	for eid in network.edges:
		var e: Dictionary = network.edges[eid]
		if not e.has("ch"):
			continue
		var pres := false
		var loin := INF
		if cam != null:
			var front := _front(eid)
			loin = cam.global_position.distance_to(front[0])
			pres = loin < VUE_ENGINS
		if pres and not _vus.has(eid):
			_vus[eid] = {"engins": null, "ouvriers": [], "etape": ""}
			_placer(eid)
		elif not pres and _vus.has(eid):
			_oublier(eid)
		if not _vus.has(eid):
			continue
		var v: Dictionary = _vus[eid]
		var veut := travail and loin < VUE_OUVRIERS and not suivi.en_attente(cle(eid))
		if veut and (v.ouvriers as Array).is_empty():
			_poser_ouvriers(eid, v)
		elif not veut and not (v.ouvriers as Array).is_empty():
			_vider_ouvriers(v)
		if travail and v.engins != null:
			for f in v.ouvriers:
				(f as Figurine).animer(_clock)
			for n in (v.engins as Node3D).get_children():
				if n is Node3D and (n as Node3D).visible:
					EnginsChantier.animer(n, _clock + float(eid), true)


## [position, tangente, distance] du front des travaux d'un tronçon.
func _front(eid: int) -> Array:
	var e: Dictionary = network.edges[eid]
	var L := float(e.len)
	var et := Chantiers.etape(Chantiers.ETAPES_VOIE, float(e.get("ch", 0.0)))
	var s := clampf(L * float(et[3]), 0.5, maxf(L - 0.5, 0.5))
	return [network.point_at(eid, s), network.tangent_at(eid, s), s]


## Engins du tronçon selon l'étape, posés au front des travaux.
func _placer(eid: int) -> void:
	var v: Dictionary = _vus[eid]
	var e: Dictionary = network.edges[eid]
	var et := Chantiers.etape(Chantiers.ETAPES_VOIE, float(e.ch))
	var key := String(et[1])
	if key != String(v.etape) or v.engins == null:
		v.etape = key
		if v.engins != null and is_instance_valid(v.engins):
			(v.engins as Node).queue_free()
		_vider_ouvriers(v)
		var root := Node3D.new()
		root.name = "ChantierVoie_%d" % eid
		var mode := TransportTypes.mode_of(String(e.t))
		match key:
			"piquetage":
				var c := EnginsChantier.camionnette()
				c.position = Vector3(float(e.width) * 0.5 + 2.0, 0, -4.0)
				root.add_child(c)
			"decapage":
				var p := EnginsChantier.pelleteuse()
				root.add_child(p)
				var b := EnginsChantier.benne()
				b.position = Vector3(float(e.width) * 0.5 + 2.0, 0, -8.0)
				root.add_child(b)
			"fond":
				root.add_child(EnginsChantier.rouleau())
				var b2 := EnginsChantier.benne()
				b2.position = Vector3(0, 0, -9.0)
				root.add_child(b2)
			"revetement":
				if mode == TransportTypes.Mode.ROAD:
					root.add_child(EnginsChantier.finisseur(float(e.width) * 0.5))
					var r := EnginsChantier.rouleau()
					r.position = Vector3(0, 0, -7.0)
					root.add_child(r)
				else:
					root.add_child(EnginsChantier.benne())
			_:
				var c2 := EnginsChantier.camionnette()
				c2.position = Vector3(float(e.width) * 0.5 + 2.0, 0, 0)
				root.add_child(c2)
		add_child(root)
		v.engins = root
	var f := _front(eid)
	var eng: Node3D = v.engins
	eng.position = f[0]
	eng.rotation.y = atan2((f[1] as Vector3).x, (f[1] as Vector3).z)


## Fronts de travaux où l'équipe travaille près de la caméra (pour les sons).
func chantiers_bruyants() -> Array:
	var out := []
	for eid in _vus:
		var v: Dictionary = _vus[eid]
		if not (v.ouvriers as Array).is_empty() and v.engins != null and is_instance_valid(v.engins):
			out.append((v.engins as Node3D).global_position)
	return out


func _vider_ouvriers(v: Dictionary) -> void:
	for f in v.ouvriers:
		if is_instance_valid(f):
			(f as Node).queue_free()
	(v.ouvriers as Array).clear()


func _poser_ouvriers(eid: int, v: Dictionary) -> void:
	if v.engins == null:
		return
	var e: Dictionary = network.edges[eid]
	var key := String(v.etape)
	var gestes := {"piquetage": ["plans", "marteler"], "decapage": ["piocher", "surveiller"],
		"fond": ["piocher", "surveiller"], "revetement": ["balayer", "surveiller"], "marquage": ["balayer", "plans"]}
	var list: Array = gestes.get(key, ["surveiller"])
	var hw := float(e.width) * 0.5
	for i in 3:
		var f := Figurine.creer(-5000 - eid * 4 - i, "ouvrier")
		f.regler(String(list[i % list.size()]))
		var side := -1.0 if i % 2 == 0 else 1.0
		f.position = Vector3(side * (hw + 0.6), 0.1, -2.5 - float(i) * 3.0)
		f.rotation.y = -side * PI / 2.0
		(v.engins as Node3D).add_child(f)
		(v.ouvriers as Array).append(f)


# --- Dessin du chantier ----------------------------------------------------------------

## Maillage d'un tronçon en chantier à l'avancement av : piquets, terre
## décapée, grave, enrobé puis voie finie qui avance avec le front.
static func chantier_mesh(e: Dictionary, av: float, ground_fn: Callable, trim_a := 0.0, trim_b := 0.0,
		right_a := Vector3.ZERO, right_b := Vector3.ZERO) -> ArrayMesh:
	var type_id := String(e.t)
	var pts: PackedVector3Array = e.pts
	var st: PackedByteArray = e.st
	var d := PackedFloat32Array()
	d.resize(pts.size())
	for i in range(1, pts.size()):
		d[i] = d[i - 1] + pts[i].distance_to(pts[i - 1])
	var total := d[d.size() - 1]
	if trim_a > 0.0 or trim_b > 0.0:
		if total - trim_a - trim_b < 0.3:
			return ArrayMesh.new()
		var part := TransportNetwork.slice_polyline(pts, st, d, trim_a, total - trim_b)
		pts = part[0]
		st = part[1]
		d.resize(pts.size())
		d[0] = 0.0
		for i in range(1, pts.size()):
			d[i] = d[i - 1] + pts[i].distance_to(pts[i - 1])
		total = d[d.size() - 1]
	var et := Chantiers.etape(Chantiers.ETAPES_VOIE, av)
	var idx: int = et[0]
	var front: float = total * float(et[3])
	var mode := TransportTypes.mode_of(type_id)
	var w := float(e.get("width", TransportTypes.width_of(type_id, e.get("w", {}))))
	var hw := w * 0.5
	var right := TransportView._rights(pts)
	if right_a != Vector3.ZERO and trim_a <= 0.0:
		right[0] = right_a
	if right_b != Vector3.ZERO and trim_b <= 0.0:
		right[right.size() - 1] = right_b
	var k := TransportView.MeshKit.new()
	if mode == TransportTypes.Mode.WATER:
		# Canal : on balise au fur et à mesure.
		var part_w := TransportNetwork.slice_polyline(pts, st, d, 0.0, maxf(total * av, 0.6))
		return TransportView.build_mesh(type_id, e.get("w", {}), part_w[0], part_w[1], ground_fn)
	# Piquets du tracé (jusqu'au revêtement).
	if idx <= 2:
		var lim := front if idx == 0 else total
		var s := 0.0
		while s <= lim:
			var i := _index(d, s)
			var u := (s - d[i]) / maxf(d[i + 1] - d[i], 0.001) if i < d.size() - 1 else 0.0
			var p := pts[i].lerp(pts[mini(i + 1, pts.size() - 1)], u)
			var r := right[i]
			if st[i] != TransportTypes.Struct.TUNNEL:
				for side in [-1.0, 1.0]:
					var q: Vector3 = p + r * float(side) * (hw + 0.7)
					k.box(q + Vector3(0, 0.5, 0), Vector3(0.08, 1.0, 0.08), PIQUET)
					k.box(q + Vector3(0, 1.0, 0), Vector3(0.1, 0.15, 0.1), PIQUET_TETE)
			s += 8.0
	# Couches : terre décapée, grave, enrobé (chaque couche couvre jusqu'au front de son étape).
	if idx >= 1:
		_bande(k, pts, st, d, right, 0.0, front if idx == 1 else total, -hw - 0.7, hw + 0.7, 0.04, TERRE)
	if idx >= 2:
		_bande(k, pts, st, d, right, 0.0, front if idx == 2 else total, -hw, hw, 0.09, GRAVE)
	if idx >= 3 and mode == TransportTypes.Mode.ROAD:
		_bande(k, pts, st, d, right, front if idx == 4 else 0.0, front if idx == 3 else total, -hw, hw, 0.13, TransportView.ASPHALT)
	elif idx >= 3:
		# Rails et chemins : la voie finie avance directement.
		pass
	var mesh := k.commit()
	# Voie finie derrière le front (rails et chemins dès le « revêtement », routes au marquage).
	var fini_jusqua := 0.0
	if idx == 4:
		fini_jusqua = front
	elif idx == 3 and mode != TransportTypes.Mode.ROAD:
		fini_jusqua = front
	if idx == 4 and mode != TransportTypes.Mode.ROAD:
		fini_jusqua = total
	if fini_jusqua > 0.6:
		var part2 := TransportNetwork.slice_polyline(pts, st, d, 0.0, fini_jusqua)
		var done := TransportView.build_mesh(type_id, e.get("w", {}), part2[0], part2[1], ground_fn, 0.0, 0.0, right[0])
		if done.get_surface_count() > 0:
			if mesh.get_surface_count() == 0:
				return done
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, done.surface_get_arrays(0))
	return mesh


static func _index(d: PackedFloat32Array, s: float) -> int:
	var i := 0
	while i < d.size() - 2 and d[i + 1] < s:
		i += 1
	return i


## Bande de l'abscisse s0 à s1 (les tunnels sont sautés, les ponts en béton).
static func _bande(k: TransportView.MeshKit, pts: PackedVector3Array, st: PackedByteArray, d: PackedFloat32Array,
		right: PackedVector3Array, s0: float, s1: float, l: float, r: float, dy: float, col: Color) -> void:
	if s1 - s0 < 0.05:
		return
	for i in pts.size() - 1:
		var a0 := d[i]
		var b0 := d[i + 1]
		if b0 <= s0 or a0 >= s1 or b0 - a0 < 0.001:
			continue
		if st[i] == TransportTypes.Struct.TUNNEL or st[i + 1] == TransportTypes.Struct.TUNNEL:
			continue
		var ua := clampf((s0 - a0) / (b0 - a0), 0.0, 1.0)
		var ub := clampf((s1 - a0) / (b0 - a0), 0.0, 1.0)
		var a := pts[i].lerp(pts[i + 1], ua)
		var b := pts[i].lerp(pts[i + 1], ub)
		var ra := right[i].lerp(right[i + 1], ua).normalized()
		var rb := right[i].lerp(right[i + 1], ub).normalized()
		var bridge := st[i] == TransportTypes.Struct.BRIDGE or st[i + 1] == TransportTypes.Struct.BRIDGE
		k.strip(a, b, ra, rb, l, r, dy, TransportView.CONCRETE if bridge else col, 0.35, col.darkened(0.2))
