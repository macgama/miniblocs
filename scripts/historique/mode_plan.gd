class_name ModePlan
extends Node3D
## Mode plan (Ctrl+P) : ce que le joueur pose en ville reste un projet, dessiné en
## fantôme bleu : bâtiments et voies sont placés sans payer ni lancer de chantier.
## Le panneau du mode plan (ModePlanPanel) donne le total estimé et valide tout d'un
## coup (« Tout construire ») : les voies d'abord, pour que les bâtiments aient leur
## accès, puis les bâtiments. Ce qui ne passe pas (argent, place prise) reste en
## projet avec sa raison. Ctrl+Z défait un projet posé, ou toute une validation.
##
## Les projets sont gardés dans la sauvegarde (section « projets »). Sur une carte
## entre amis, ils restent propres à chaque joueur (non partagés) jusqu'à la
## validation, qui part au serveur comme des poses ordinaires.

signal changed
signal message(text: String)
signal actif_change(on: bool)

static var instance: ModePlan

const COULEUR := Color(0.32, 0.62, 1.0, 0.42)
const COULEUR_REFUS := Color(1.0, 0.45, 0.35, 0.45)
## Hauteur du ruban d'une voie en projet au-dessus du sol (m).
const LEVE_VOIE := 0.25

var buildings: BuildingSystem
var transport: TransportSystem

var actif := false
## Projets dans l'ordre de pose : {"pid", "k": "bat" | "voie", ...}.
## bat : "t", "c" [x, z], "r", "a", "perso", "v", "h", "cout".
## voie : "t", "spec", "path" [x, z, x, z…], "pts" [x, y, z…], "l" (largeur), "prof".
var projets: Array = []
var next_pid := 1
## pid -> raison du dernier refus à la validation.
var refus: Dictionary = {}

var _fantomes: Dictionary = {} # pid -> Node3D
var _cases: Dictionary = {} # Vector2i -> pid (emprise des bâtiments prévus)
var _cases_voies: Dictionary = {} # Vector2i -> pid (emprise des voies prévues)
var _mat: StandardMaterial3D
var _mat_refus: StandardMaterial3D


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	_mat = _matiere(COULEUR)
	_mat_refus = _matiere(COULEUR_REFUS)


static func _matiere(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = Color(c.r, c.g, c.b) * 0.35
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func basculer() -> void:
	set_actif(not actif)


func set_actif(on: bool) -> void:
	if on == actif:
		return
	actif = on
	if on:
		message.emit("Mode plan : ce que tu poses reste en projet (bleu), sans payer ni chantier. « Tout construire » valide le plan.")
	else:
		message.emit("Mode plan quitté%s." % ("" if projets.is_empty() else " : %d projet%s gardé%s en bleu" % [projets.size(), _s(projets.size()), _s(projets.size())]))
	actif_change.emit(on)
	changed.emit()


static func _s(n: int) -> String:
	return "s" if n > 1 else ""


# --- Projets ----------------------------------------------------------------------------------

## Clic de pose d'un bâtiment en mode plan. Renvoie true si un projet a été ajouté.
func capter_batiment(id: String, center: Vector2i, r: int, a := 0.0, perso: Dictionary = {}, v := -1) -> bool:
	if buildings == null:
		return false
	if Communes.est_fondateur(id):
		message.emit("La Maison de commune se pose directement : quitte le mode plan (Ctrl+P) pour fonder le village.")
		return false
	var res := verifier_batiment(id, center, r, a)
	if not bool(res.ok):
		message.emit(String(res.reason))
		Son.jouer("ui_erreur", -4.0, 0.0, "Interface")
		return false
	var p := {"pid": next_pid, "k": "bat", "t": id, "c": [center.x, center.y], "r": r, "a": a,
		"perso": perso.duplicate(true), "v": v, "h": float(res.h), "cout": int(res.cost)}
	next_pid += 1
	_ajouter(p)
	_noter(p, true)
	var acces := "" if bool(res.get("acces", true)) else " Pas encore de voie devant : prévois-en une."
	message.emit("Projet : %s (%s estimés).%s" % [HistoriqueVille._nom_type(id), BuildingSystem.format_money(int(res.cost)), acces])
	Son.jouer("pose_batiment", -8.0, 0.08)
	return true


## La place est-elle libre (bâtiments, voies, autres projets) ? L'argent et l'accès à
## une voie ne comptent pas encore : la voie peut être elle-même en projet.
func verifier_batiment(id: String, center: Vector2i, r: int, a := 0.0) -> Dictionary:
	var acc := buildings.require_access
	var um := buildings.unlimited_money
	buildings.require_access = false
	buildings.unlimited_money = true
	var res := buildings.check_place(id, center, r, false, a)
	buildings.require_access = acc
	buildings.unlimited_money = um
	if bool(res.ok):
		for c in res.cells:
			if _cases.has(c):
				res.ok = false
				res.reason = "Un autre projet occupe déjà cette place."
				break
			if _cases_voies.has(c):
				res.ok = false
				res.reason = "Une voie en projet passe sur l'emplacement."
				break
	res["acces"] = not (res.access as Dictionary).is_empty() or (BuildingCatalog.get_type(id).get("access", []) as Array).is_empty()
	return res


## Clic de tracé d'une voie en mode plan. Renvoie true si un projet a été ajouté.
func capter_voie(id: String, spec: Dictionary, path: PackedVector2Array, prof := NAN) -> bool:
	if transport == null or path.size() < 2:
		return false
	id = TransportTypes.resolve(id)
	var s := TransportTypes.normalize(id, spec)
	var plan := transport.evaluate(id, s, path)
	if not bool(plan.ok):
		message.emit(String(plan.reason))
		Son.jouer("ui_erreur", -4.0, 0.0, "Interface")
		return false
	var pts: PackedVector3Array = plan.pts
	for c in RoutePlanner.footprint(TransportTypes.width_of(id, s), pts, plan.st):
		if _cases.has(c):
			message.emit("Un bâtiment en projet est sur le tracé.")
			Son.jouer("ui_erreur", -4.0, 0.0, "Interface")
			return false
	var flat := []
	for q in path:
		flat.append_array([snappedf(q.x, 0.01), snappedf(q.y, 0.01)])
	var p3 := []
	for q in pts:
		p3.append_array([snappedf(q.x, 0.01), snappedf(q.y, 0.01), snappedf(q.z, 0.01)])
	var p := {"pid": next_pid, "k": "voie", "t": id, "spec": s.duplicate(true), "path": flat, "pts": p3,
		"st": Array(plan.st), "l": TransportTypes.width_of(id, s), "cout": 0}
	if not is_nan(prof):
		p["prof"] = prof
	next_pid += 1
	_ajouter(p)
	_noter(p, true)
	var l := 0.0
	for i in range(1, pts.size()):
		l += pts[i].distance_to(pts[i - 1])
	message.emit("Projet : %s, %d m." % [String(TransportTypes.get_type(id).get("name", "voie")), roundi(l)])
	Son.jouer("pose_route", -8.0, 0.08)
	return true


func _ajouter(p: Dictionary) -> void:
	projets.append(p)
	_occuper(p)
	_fantome(p)
	changed.emit()


func _occuper(p: Dictionary) -> void:
	if String(p.k) == "bat":
		for c in _cellules(p):
			_cases[c] = int(p.pid)
		return
	var pts := _points(p)
	var st := PackedByteArray()
	for v in p.get("st", []):
		st.append(int(v))
	if st.size() != pts.size():
		st.resize(pts.size())
		st.fill(0)
	for c in RoutePlanner.footprint(float(p.get("l", 6.0)), pts, st):
		_cases_voies[c] = int(p.pid)


static func _points(p: Dictionary) -> PackedVector3Array:
	var f: Array = p.get("pts", [])
	var pts := PackedVector3Array()
	var i := 0
	while i + 2 < f.size():
		pts.append(Vector3(float(f[i]), float(f[i + 1]), float(f[i + 2])))
		i += 3
	return pts


## Remet un projet retiré (Ctrl+Z, rétablir), à sa place dans l'ordre.
func remettre(p: Dictionary) -> void:
	if projet(int(p.pid)).size() > 0:
		return
	var q := p.duplicate(true)
	var i := projets.size()
	for k in projets.size():
		if int(projets[k].pid) > int(q.pid):
			i = k
			break
	projets.insert(i, q)
	_occuper(q)
	next_pid = maxi(next_pid, int(q.pid) + 1)
	_fantome(q)
	changed.emit()


func projet(pid: int) -> Dictionary:
	for p in projets:
		if int(p.pid) == pid:
			return p
	return {}


## Retire un projet (noter : dans l'historique, pour Ctrl+Z).
func retirer(pid: int, noter := true) -> void:
	var p := projet(pid)
	if p.is_empty():
		return
	projets.erase(p)
	refus.erase(pid)
	for d in [_cases, _cases_voies]:
		for c in (d as Dictionary).keys():
			if int(d[c]) == pid:
				(d as Dictionary).erase(c)
	if _fantomes.has(pid):
		(_fantomes[pid] as Node).queue_free()
		_fantomes.erase(pid)
	if noter:
		_noter(p, false)
	changed.emit()


func effacer_tout() -> void:
	for p in projets.duplicate():
		retirer(int(p.pid))
	message.emit("Plan effacé.")


## Vide tout sans rien noter (nouvelle partie, chargement).
func clear() -> void:
	projets.clear()
	refus.clear()
	_cases.clear()
	_cases_voies.clear()
	for n in _fantomes.values():
		(n as Node).queue_free()
	_fantomes.clear()
	next_pid = 1
	changed.emit()


func _noter(p: Dictionary, ajout: bool) -> void:
	if HistoriqueVille.instance == null:
		return
	var nom := ("Projet : " if ajout else "Projet retiré : ") + nom_projet(p).to_lower()
	HistoriqueVille.instance.noter(nom, {"k": "projet", "ajout": ajout, "p": p.duplicate(true)})


static func nom_projet(p: Dictionary) -> String:
	if String(p.k) == "voie":
		return String(TransportTypes.get_type(String(p.t)).get("name", "Voie"))
	return HistoriqueVille._nom_type(String(p.t))


func cout_total() -> int:
	var t := 0
	for p in projets:
		t += int(p.get("cout", 0))
	return t


func compte(k: String) -> int:
	var n := 0
	for p in projets:
		if String(p.k) == k:
			n += 1
	return n


func _cellules(p: Dictionary) -> Array:
	return BuildingSystem.cells_for(String(p.t), Vector2i(int(p.c[0]), int(p.c[1])), int(p.r), float(p.get("a", 0.0)))


static func chemin(p: Dictionary) -> PackedVector2Array:
	var out := PackedVector2Array()
	var f: Array = p.get("path", [])
	var i := 0
	while i + 1 < f.size():
		out.append(Vector2(float(f[i]), float(f[i + 1])))
		i += 2
	return out


# --- Validation -------------------------------------------------------------------------------

## Construit tout le plan : voies, puis bâtiments. Renvoie {"faits", "refuses", "cout"}.
func valider() -> Dictionary:
	var faits := 0
	var cout := 0
	refus.clear()
	var ordre: Array = []
	for p in projets:
		if String(p.k) == "voie":
			ordre.append(p)
	for p in projets:
		if String(p.k) == "bat":
			ordre.append(p)
	for p in ordre:
		var r := _construire(p)
		if r.ok:
			faits += 1
			cout += int(r.get("cout", 0))
			retirer(int(p.pid))
		else:
			refus[int(p.pid)] = String(r.reason)
	_rafraichir_fantomes()
	var txt := "Plan validé : %d construction%s lancée%s" % [faits, _s(faits), _s(faits)]
	if cout > 0:
		txt += " (%s payés tout de suite)" % BuildingSystem.format_money(cout)
	if refus.is_empty():
		txt += "."
	else:
		txt += ". %d projet%s gardé%s : %s" % [refus.size(), _s(refus.size()), _s(refus.size()), String(refus.values()[0])]
	if ordre.is_empty():
		txt = "Le plan est vide : pose d'abord des bâtiments ou des voies en mode plan."
	message.emit(txt)
	changed.emit()
	return {"faits": faits, "refuses": refus.size(), "cout": cout}


func _construire(p: Dictionary) -> Dictionary:
	if String(p.k) == "voie":
		var path := chemin(p)
		if transport.relais.is_valid():
			var a := {"t": "voie", "id": String(p.t), "spec": (p.spec as Dictionary).duplicate(true), "path": path}
			if p.has("prof"):
				a["prof"] = float(p.prof)
			transport.relais.call(a)
			return {"ok": true}
		var av := transport.photo_reseau()
		RoutePlanner.profondeur_forcee = float(p.get("prof", NAN))
		var res := transport.build_path(String(p.t), p.spec, path)
		RoutePlanner.profondeur_forcee = NAN
		if not bool(res.ok):
			return {"ok": false, "reason": String(res.reason)}
		transport.edges_built.emit(res.edges)
		transport._noter_histo(nom_projet(p), av)
		return {"ok": true}
	var c := Vector2i(int(p.c[0]), int(p.c[1]))
	var id := String(p.t)
	if buildings.relais.is_valid():
		var pa := {"t": "poser", "id": id, "c": [c.x, c.y], "r": int(p.r), "a": float(p.get("a", 0.0)),
			"perso": p.get("perso", {}), "v": int(p.get("v", -1))}
		buildings.relais.call(pa)
		if HistoriqueVille.instance != null:
			HistoriqueVille.instance.noter(nom_projet(p), {"k": "mp_bat_pose", "a": pa.duplicate(true)})
		return {"ok": true}
	var chk := buildings.check_place(id, c, int(p.r), false, float(p.get("a", 0.0)))
	if not bool(chk.ok):
		return {"ok": false, "reason": "%s : %s" % [nom_projet(p), String(chk.reason)]}
	var avant := buildings.money
	var bid := buildings.place(id, c, int(p.r), 0, float(p.get("a", 0.0)))
	if bid < 0:
		return {"ok": false, "reason": "%s : refusé." % nom_projet(p)}
	var perso: Dictionary = p.get("perso", {})
	if not perso.is_empty() or int(p.get("v", -1)) >= 0:
		buildings.set_perso(bid, perso, int(p.get("v", -1)))
	if HistoriqueVille.instance != null:
		HistoriqueVille.instance.noter_pose(bid)
	return {"ok": true, "cout": maxi(avant - buildings.money, 0)}


# --- Fantômes ---------------------------------------------------------------------------------

func _fantome(p: Dictionary) -> void:
	var pid := int(p.pid)
	if _fantomes.has(pid):
		(_fantomes[pid] as Node).queue_free()
	var n: MeshInstance3D
	if String(p.k) == "bat":
		n = _fantome_bat(p)
	else:
		n = _fantome_voie(p)
	if n == null:
		return
	n.name = "Projet_%d" % pid
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.material_override = _mat_refus if refus.has(pid) else _mat
	add_child(n)
	_fantomes[pid] = n


func _rafraichir_fantomes() -> void:
	for pid in _fantomes:
		(_fantomes[pid] as MeshInstance3D).material_override = _mat_refus if refus.has(pid) else _mat


func _fantome_bat(p: Dictionary) -> MeshInstance3D:
	if buildings == null:
		return null
	var id := String(p.t)
	var c := Vector2i(int(p.c[0]), int(p.c[1]))
	var r := int(p.r)
	var v := int(p.get("v", -1))
	if v < 0:
		v = BuildingSystem.variant_for(id, c.x, c.y)
	var mi := MeshInstance3D.new()
	mi.mesh = buildings.mesh_for(id, v, p.get("perso", {}))
	var rect := BuildingSystem.rect_for(id, c, r)
	mi.position = BuildingSystem.rect_center(rect) + Vector3(0, float(p.get("h", 0.0)) + 0.05, 0)
	mi.rotation.y = -r * PI / 2.0 + float(p.get("a", 0.0))
	return mi


func _fantome_voie(p: Dictionary) -> MeshInstance3D:
	var pts := _points(p)
	if pts.size() < 2:
		return null
	var hw := float(p.get("l", 6.0)) * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var g: Array[Vector3] = []
	var d: Array[Vector3] = []
	for k in pts.size():
		var t := pts[mini(k + 1, pts.size() - 1)] - pts[maxi(k - 1, 0)]
		t.y = 0.0
		var n := Vector3(-t.z, 0.0, t.x).normalized() * hw
		var y := Vector3(0, LEVE_VOIE, 0)
		g.append(pts[k] + n + y)
		d.append(pts[k] - n + y)
	for k in pts.size() - 1:
		st.add_vertex(g[k])
		st.add_vertex(d[k])
		st.add_vertex(g[k + 1])
		st.add_vertex(g[k + 1])
		st.add_vertex(d[k])
		st.add_vertex(d[k + 1])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	return mi


# --- Sauvegarde (section « projets ») -------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"version": 1, "projets": projets.duplicate(true), "next": next_pid}


func from_dict(d: Dictionary) -> void:
	clear()
	for p in d.get("projets", []):
		if p is Dictionary and (p as Dictionary).has("pid") and (p as Dictionary).has("k"):
			var q: Dictionary = (p as Dictionary).duplicate(true)
			q.pid = int(q.pid)
			projets.append(q)
			_occuper(q)
			_fantome(q)
	next_pid = maxi(int(d.get("next", 1)), 1)
	for p in projets:
		next_pid = maxi(next_pid, int(p.pid) + 1)
	changed.emit()
