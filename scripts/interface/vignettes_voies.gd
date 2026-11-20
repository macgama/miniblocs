class_name VignettesVoies
extends RefCounted
## Vignettes 3D des classes de voies (route, rail, chemin, voie d'eau) pour les
## menus en images : un tronçon droit construit avec le vrai maillage du jeu
## (TransportView.build_mesh, réglages par défaut de la classe), posé sur un
## carré d'herbe (ou d'eau), avec un véhicule de la classe dessus pour l'échelle.
## Rendu par Vignettes (une image par frame, gardée en mémoire).
## Voir docs/menus-en-images.md.

## Direction de la caméra : de trois quarts, assez haut pour lire les voies.
const DIR := Vector3(1.0, 1.15, 0.62)
const ZOOM := 0.5
const PX := Vector2i(168, 112)
const HERBE := Color("6f8f4e")
const TERRE := Color("8c7a5b")
const EAU := Color("3f7fa8")

static var _material: StandardMaterial3D


## Ce que montre la vignette (clé de cache).
static func cle(type_id: String) -> String:
	return "voie:" + type_id


## Pose la vignette de la classe `type_id` dans `cible` (dès qu'elle est rendue).
static func demander(vign: Vignettes, type_id: String, cible: Control) -> void:
	if vign == null:
		return
	vign.request_mesh(cle(type_id), func() -> Mesh: return maquette(type_id), cible, PX.x, DIR, ZOOM, PX.y)


## Infobulle d'une classe : vitesse, voies, largeur, rayon et pente.
static func details(type_id: String) -> String:
	var c := TransportTypes.get_type(type_id)
	if c.is_empty():
		return ""
	var spec := TransportTypes.default_spec(type_id)
	var parts: Array[String] = []
	parts.append("%d km/h" % int(c.get("kmh", 0)))
	if c.has("lanes"):
		var n := int(spec.get("lanes", 1))
		if c.get("oneway", false) or c.get("single", false):
			parts.append("sens unique")
		else:
			parts.append("%d voie%s par sens" % [n, "s" if n > 1 else ""])
	if c.has("tracks"):
		var t := int(spec.get("tracks", 1))
		parts.append("voie unique" if t == 1 else "double voie")
	parts.append("largeur %s m" % _m(TransportTypes.width_of(type_id, spec)))
	return " · ".join(parts)


## Prix d'une classe de voie pour sa carte (piste CityRT 5). La pose est gratuite
## (seul le terrassement de montagne se paie) ; l'entretien se paie chaque mois.
static func prix(type_id: String) -> String:
	var c := TransportTypes.get_type(type_id)
	if c.is_empty():
		return ""
	var cle := ""
	for k in BudgetCommunal.VOIES:
		if int(BudgetCommunal.VOIES[k]) == int(c.mode):
			cle = String(k)
	if cle == "":
		return ""
	var w := TransportTypes.width_of(type_id, TransportTypes.default_spec(type_id))
	var par_km := float(BudgetCommunal.COUT_KM[cle]) * w / float(BudgetCommunal.LARGEUR_REF[cle])
	return "%s / km / mois" % BuildingSystem.format_short(ReglagesPartie.prix(roundi(par_km)))


static func _m(v: float) -> String:
	return ("%d" % roundi(v)) if absf(v - roundf(v)) < 0.05 else ("%.1f" % v).replace(".", ",")


## Maquette d'une classe de voie : tronçon droit + sol + véhicule.
static func maquette(type_id: String) -> Mesh:
	var c := TransportTypes.get_type(type_id)
	var mesh := ArrayMesh.new()
	if c.is_empty():
		return mesh
	if _material == null:
		_material = TransportView.make_material()
	var mode := int(c.mode)
	var spec := TransportTypes.default_spec(type_id)
	var w := TransportTypes.width_of(type_id, spec)
	var longueur := clampf(w * 1.5, 24.0, 240.0)
	var pas := clampf(longueur / 24.0, 1.5, 10.0)
	var pts := PackedVector3Array()
	var st := PackedByteArray()
	var z := -longueur * 0.5
	while z <= longueur * 0.5 + 0.01:
		pts.append(Vector3(0, 0, z))
		st.append(TransportTypes.Struct.GROUND)
		z += pas
	var sol := func(_x: float, _z: float = 0.0) -> float: return 0.0
	# Sol : herbe autour, eau sous les voies d'eau.
	var k := TransportView.MeshKit.new()
	var marge := maxf(3.0, w * 0.35)
	var hl := longueur * 0.5
	if mode == TransportTypes.Mode.WATER:
		var hw := w * 0.5
		k.quad(Vector3(-hw, -0.05, -hl), Vector3(-hw, -0.05, hl), Vector3(hw, -0.05, hl), Vector3(hw, -0.05, -hl), EAU)
		for sgn in [-1.0, 1.0]:
			var x0: float = sgn * hw
			var x1: float = sgn * (hw + marge)
			k.quad(Vector3(minf(x0, x1), 0.6, -hl), Vector3(minf(x0, x1), 0.6, hl), Vector3(maxf(x0, x1), 0.6, hl), Vector3(maxf(x0, x1), 0.6, -hl), HERBE)
			k.quad(Vector3(x0, 0.6, -hl), Vector3(x0, 0.6, hl), Vector3(x0, -0.05, hl), Vector3(x0, -0.05, -hl), TERRE)
	else:
		var hx := w * 0.5 + marge
		k.quad(Vector3(-hx, -0.03, -hl), Vector3(-hx, -0.03, hl), Vector3(hx, -0.03, hl), Vector3(hx, -0.03, -hl), HERBE)
	_ajoute(mesh, k.commit(), Transform3D.IDENTITY)
	_ajoute(mesh, TransportView.build_mesh(type_id, spec, pts, st, sol), Transform3D.IDENTITY)
	# Un véhicule de la classe, sur la première voie.
	var vid := vehicule(type_id)
	if vid != "":
		var offs := TransportTypes.lane_offsets(type_id, spec)
		var x := float(offs[0]) if not offs.is_empty() else 0.0
		var y := 0.0
		match mode:
			TransportTypes.Mode.RAIL: y = 0.42
			TransportTypes.Mode.PATH: y = 0.08
			TransportTypes.Mode.ROAD: y = 0.02
		var vm := VehicleCatalog.build_mesh(vid, 0)
		_ajoute(mesh, vm, Transform3D(Basis.IDENTITY, Vector3(-x, y, longueur * 0.08)))
	return mesh


## Véhicule montré sur la vignette : un de l'époque actuelle si possible.
static func vehicule(type_id: String) -> String:
	for era in ["contemporain", "moderne", "classique", ""]:
		var l := VehicleCatalog.for_track(type_id, era)
		if not l.is_empty():
			return l[0]
	return ""


static func _ajoute(dest: ArrayMesh, src: Mesh, xf: Transform3D) -> void:
	if src == null:
		return
	for s in src.get_surface_count():
		var arrays := src.surface_get_arrays(s)
		if xf != Transform3D.IDENTITY:
			var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for i in v.size():
				v[i] = xf * v[i]
			arrays[Mesh.ARRAY_VERTEX] = v
		dest.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		dest.surface_set_material(dest.get_surface_count() - 1, _material)
