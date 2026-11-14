class_name ZooOutils
extends Node3D
## Outils de l'éditeur de zoo (panneau Zoo, Maj+Z) : tracer un enclos point
## par point ou en rectangle, changer sa barrière, peindre les sols, creuser
## un bassin, planter des arbres, lâcher des animaux, poser des objets
## d'enrichissement, choisir un enclos pour voir ses besoins.

signal info_changed(text: String)
signal message(text: String)
## Enclos choisi (clic avec l'outil Choisir, ou enclos tout juste tracé).
signal enclos_choisi(id: int)

enum Outil { AUCUN, CHOISIR, ENCLOS, BARRIERE, SOL, EAU, REMBLAI, RELIEF, ARBRES, ARRACHER, ANIMAL, OBJET, SUPPRIMER }

var zoo: ZooSysteme
var world: TerrainWorld
var decors: DecorSystem
var outil := Outil.AUCUN
var barriere := "grillage"
var sol := "herbe"
var espece := "zebre"
var objet := "tronc_escalade"
var rayon := 3
var angle := 0.0
## Tracé en cours (sommets d'un enclos).
var trace := PackedVector2Array()
var _survol := Vector3.ZERO
var _survol_ok := false
var _appui := false
var _debut := Vector3.ZERO
var _glisse := false
var _pinceau_t := 0.0
var _ligne: MeshInstance3D
var _cercle: MeshInstance3D
var _fantome: MeshInstance3D
var _im: ImmediateMesh


func setup(z: ZooSysteme, w: TerrainWorld, d: DecorSystem) -> void:
	zoo = z
	world = w
	decors = d


func _ready() -> void:
	_im = ImmediateMesh.new()
	_ligne = MeshInstance3D.new()
	_ligne.mesh = _im
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.no_depth_test = true
	_ligne.material_override = m
	add_child(_ligne)
	_cercle = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.95
	tm.outer_radius = 1.0
	tm.rings = 32
	_cercle.mesh = tm
	var cm := StandardMaterial3D.new()
	cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.albedo_color = Color(1, 0.9, 0.3)
	_cercle.material_override = cm
	_cercle.visible = false
	add_child(_cercle)
	_fantome = MeshInstance3D.new()
	_fantome.material_override = Decors.materiau()
	_fantome.visible = false
	add_child(_fantome)


func actif() -> bool:
	return outil != Outil.AUCUN


func set_outil(o: Outil) -> void:
	outil = o
	trace.clear()
	_appui = false
	_glisse = false
	_maj_aide()
	_dessine()


func set_inactive() -> void:
	set_outil(Outil.AUCUN)
	info_changed.emit("")


func _maj_aide() -> void:
	match outil:
		Outil.CHOISIR:
			info_changed.emit("Zoo : clic dans un enclos pour voir ses animaux et leurs besoins.")
		Outil.ENCLOS:
			info_changed.emit("Enclos (%s) : clic pour chaque coin, clic sur le premier point ou Entrée pour fermer. Glisser : un rectangle. Retour arrière : effacer un point." % String(ZooEspeces.barriere(barriere).nom))
		Outil.BARRIERE:
			info_changed.emit("Clic dans un enclos : lui donner la barrière « %s »." % String(ZooEspeces.barriere(barriere).nom))
		Outil.SOL:
			info_changed.emit("Pinceau « %s » : glisser pour peindre le sol (rayon %d m)." % [String(ZooEspeces.SOLS[sol].nom), rayon])
		Outil.EAU:
			info_changed.emit("Bassin : glisser pour creuser un plan d'eau (rayon %d m)." % rayon)
		Outil.REMBLAI:
			info_changed.emit("Remblai : glisser pour combler l'eau.")
		Outil.RELIEF:
			info_changed.emit("Relief : glisser pour faire une butte (Maj : aplanir).")
		Outil.ARBRES:
			info_changed.emit("Arbres : glisser pour planter (ombre et enrichissement).")
		Outil.ARRACHER:
			info_changed.emit("Arracher : glisser pour enlever les arbres.")
		Outil.ANIMAL:
			info_changed.emit("%s (%s) : clic dans un enclos pour en lâcher un, Maj+clic pour un groupe." % [ZooEspeces.nom(espece), ZooSysteme._euros(float(ZooEspeces.espece(espece).prix))])
		Outil.OBJET:
			info_changed.emit("%s : clic pour poser, R pour tourner." % Decors.nom(objet))
		Outil.SUPPRIMER:
			info_changed.emit("Clic dans un enclos : le démolir (ses animaux partent pour d'autres zoos).")
		_:
			info_changed.emit("")


func _pick(pos: Vector2) -> Variant:
	var cam := get_viewport().get_camera_3d()
	if cam == null or world == null:
		return null
	return world.pick_point(cam.project_ray_origin(pos), cam.project_ray_normal(pos))


static func _snap(p: Vector3) -> Vector2:
	return Vector2(roundf(p.x), roundf(p.z))


func _unhandled_input(event: InputEvent) -> void:
	if outil == Outil.AUCUN or world == null:
		return
	if event is InputEventMouseMotion:
		var p: Variant = _pick((event as InputEventMouseMotion).position)
		_survol_ok = p != null
		if p != null:
			_survol = p
			if _appui and (outil == Outil.ENCLOS) and trace.is_empty() and Vector2(_survol.x - _debut.x, _survol.z - _debut.z).length() > 2.0:
				_glisse = true
		_dessine()
	elif event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.keycode == KEY_ESCAPE:
			if not trace.is_empty():
				trace.clear()
				_dessine()
				get_viewport().set_input_as_handled()
			else:
				set_inactive()
		elif outil == Outil.ENCLOS and (k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER):
			_fermer()
			get_viewport().set_input_as_handled()
		elif outil == Outil.ENCLOS and k.keycode == KEY_BACKSPACE and not trace.is_empty():
			trace.remove_at(trace.size() - 1)
			_dessine()
			get_viewport().set_input_as_handled()
		elif outil == Outil.OBJET and k.physical_keycode == KEY_R:
			angle += deg_to_rad(-15.0 if k.shift_pressed else 45.0)
			_dessine()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		var p: Variant = _pick(mb.position)
		if mb.pressed:
			if p == null:
				return
			_appui = true
			_glisse = false
			_debut = p
			_pinceau_t = 0.0
			if outil in [Outil.SOL, Outil.EAU, Outil.REMBLAI, Outil.RELIEF, Outil.ARBRES, Outil.ARRACHER]:
				if world.has_method("apply_brush"):
					world._stroke_level = NAN
				_peindre(p, mb.shift_pressed)
			get_viewport().set_input_as_handled()
		else:
			if not _appui:
				return
			_appui = false
			get_viewport().set_input_as_handled()
			if p == null:
				p = _survol
			_clic(p, mb.shift_pressed)


func _clic(p: Vector3, maj: bool) -> void:
	var q := Vector2(p.x, p.z)
	match outil:
		Outil.CHOISIR:
			var id := zoo.enclos_a(q)
			if id >= 0:
				enclos_choisi.emit(id)
		Outil.ENCLOS:
			if _glisse and trace.is_empty():
				_glisse = false
				var a := _snap(_debut)
				var b := _snap(p)
				if absf(b.x - a.x) >= 4.0 and absf(b.y - a.y) >= 4.0:
					trace = PackedVector2Array([a, Vector2(b.x, a.y), b, Vector2(a.x, b.y)])
					_fermer()
				return
			var s := _snap(p)
			if trace.size() >= 3 and s.distance_to(trace[0]) < 2.5:
				_fermer()
				return
			if trace.is_empty() or s.distance_to(trace[trace.size() - 1]) > 0.9:
				trace.append(s)
			_dessine()
			_maj_cout()
		Outil.BARRIERE:
			var id := zoo.enclos_a(q)
			if id >= 0 and zoo.changer_barriere(id, barriere):
				message.emit("« %s » : %s." % [String(zoo.enclos[id].nom), String(ZooEspeces.barriere(barriere).nom).to_lower()])
		Outil.ANIMAL:
			var id := zoo.enclos_a(q)
			if id < 0:
				message.emit("Les animaux se lâchent dans un enclos.")
				return
			var n := int((ZooEspeces.espece(espece).groupe as Array)[0]) if maj else 1
			var faits := 0
			for i in n:
				if zoo.acheter(espece, id) >= 0:
					faits += 1
			if faits > 0:
				message.emit("%d × %s dans « %s »." % [faits, ZooEspeces.nom_bas(espece), String(zoo.enclos[id].nom)])
				var ok := ZooEspeces.barriere_ok(espece, String(zoo.enclos[id].barriere))
				if not bool(ok[0]):
					message.emit("Attention : %s, %s." % [ZooEspeces.nom_bas(espece), String(ok[1])])
				enclos_choisi.emit(id)
		Outil.OBJET:
			if decors != null and decors.pose(objet, p.x, p.z, angle):
				message.emit("%s posé." % Decors.nom(objet))
		Outil.SUPPRIMER:
			var id := zoo.enclos_a(q)
			if id >= 0:
				var nom := String(zoo.enclos[id].nom)
				for aid in zoo.animaux_de(id):
					zoo.vendre(aid)
				zoo.retirer_enclos(id)
				message.emit("« %s » démoli." % nom)


func _maj_cout() -> void:
	if trace.size() < 2:
		_maj_aide()
		return
	var pts := trace.duplicate()
	pts.append(Vector2(_survol.x, _survol.z))
	var l := 0.0
	for i in range(1, trace.size()):
		l += trace[i - 1].distance_to(trace[i])
	info_changed.emit("Enclos : %d coins, %d m de barrière (%s). Clic sur le premier point ou Entrée pour fermer." % [
		trace.size(), roundi(l), ZooSysteme._euros(l * float(ZooEspeces.barriere(barriere).prix_m))])


func _fermer() -> void:
	if trace.size() < 3:
		message.emit("Un enclos a au moins 3 coins.")
		return
	var id := zoo.ajouter_enclos(trace, barriere)
	trace.clear()
	_dessine()
	_maj_aide()
	if id >= 0:
		message.emit("« %s » : %d m², %d m de barrière." % [String(zoo.enclos[id].nom), roundi(zoo.aire(id)), roundi(ZooSysteme.perimetre(zoo.enclos[id].pts))])
		enclos_choisi.emit(id)


## Pinceaux : sols, eau, relief, arbres (mêmes règles que l'outil Paysage).
func _peindre(p: Vector3, maj: bool) -> void:
	var c := Vector2i(floori(p.x), floori(p.z))
	var avant := world.current_tool
	var r_avant := world.brush_radius
	var k_avant := world.paint_kind
	world.brush_radius = rayon
	var n := 0
	match outil:
		Outil.SOL:
			if sol == "eau":
				world.current_tool = TerrainWorld.Tool.DIG_WATER
			else:
				world.current_tool = TerrainWorld.Tool.BIOME
				world.paint_kind = int(ZooEspeces.SOLS[sol].kind)
		Outil.EAU:
			world.current_tool = TerrainWorld.Tool.DIG_WATER
		Outil.REMBLAI:
			world.current_tool = TerrainWorld.Tool.FILL_WATER
		Outil.RELIEF:
			world.current_tool = TerrainWorld.Tool.SMOOTH if maj else TerrainWorld.Tool.HILL
		Outil.ARBRES:
			world.current_tool = TerrainWorld.Tool.PLANT
		Outil.ARRACHER:
			world.current_tool = TerrainWorld.Tool.CLEAR_TREES
	n = world.apply_brush(c)
	world.current_tool = avant
	world.brush_radius = r_avant
	world.paint_kind = k_avant
	if n > 0:
		# Peindre coûte un peu (terre, sable, bâches et pompes pour l'eau).
		var prix := {Outil.SOL: 6.0, Outil.EAU: 40.0, Outil.REMBLAI: 12.0, Outil.RELIEF: 10.0, Outil.ARBRES: 25.0, Outil.ARRACHER: 4.0}
		zoo._payer_ville(Vector2(p.x, p.z), "Zoo : aménagement des enclos", float(prix.get(outil, 5.0)) * n)


func _process(delta: float) -> void:
	if outil == Outil.AUCUN:
		_cercle.visible = false
		_fantome.visible = false
		return
	var pinceau := outil in [Outil.SOL, Outil.EAU, Outil.REMBLAI, Outil.RELIEF, Outil.ARBRES, Outil.ARRACHER]
	_cercle.visible = pinceau and _survol_ok
	if _cercle.visible:
		var r := float(rayon) + 0.5
		_cercle.transform = Transform3D(Basis().scaled(Vector3(r, 1.0, r)), _survol + Vector3(0, 0.15, 0))
	if pinceau and _appui and _survol_ok:
		_pinceau_t += delta
		if _pinceau_t > 0.1:
			_pinceau_t = 0.0
			_peindre(_survol, Input.is_key_pressed(KEY_SHIFT))
	_fantome.visible = (outil == Outil.OBJET or outil == Outil.ANIMAL) and _survol_ok
	if _fantome.visible:
		var did := objet if outil == Outil.OBJET else ZooEspeces.modele(espece, false, false)
		if _fantome.mesh != Decors.mesh(did):
			_fantome.mesh = Decors.mesh(did)
		_fantome.transform = Transform3D(Basis(Vector3.UP, angle), _survol)


## Tracé en cours, rectangle glissé, enclos survolé.
func _dessine() -> void:
	_im.clear_surfaces()
	if outil != Outil.ENCLOS and outil != Outil.BARRIERE and outil != Outil.CHOISIR and outil != Outil.ANIMAL and outil != Outil.SUPPRIMER:
		return
	var pts := PackedVector2Array()
	var ferme := false
	var col := Color(1.0, 0.85, 0.3)
	if outil == Outil.ENCLOS:
		if _glisse and trace.is_empty():
			var a := _snap(_debut)
			var b := _snap(_survol)
			pts = PackedVector2Array([a, Vector2(b.x, a.y), b, Vector2(a.x, b.y)])
			ferme = true
		else:
			pts = trace.duplicate()
			if _survol_ok and not pts.is_empty():
				pts.append(_snap(_survol))
	elif _survol_ok and zoo != null:
		var id := zoo.enclos_a(Vector2(_survol.x, _survol.z))
		if id >= 0:
			pts = zoo.enclos[id].pts
			ferme = true
			col = Color(1.0, 0.4, 0.3) if outil == Outil.SUPPRIMER else Color(0.5, 1.0, 0.6)
	if pts.size() < 2:
		if pts.size() == 1:
			_point(pts[0], col)
		return
	_im.surface_begin(Mesh.PRIMITIVE_LINES)
	var n := pts.size() if ferme else pts.size() - 1
	for i in n:
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		var segs := maxi(1, ceili(a.distance_to(b) / 4.0))
		for j in segs:
			var p0 := a.lerp(b, float(j) / segs)
			var p1 := a.lerp(b, float(j + 1) / segs)
			_im.surface_set_color(col)
			_im.surface_add_vertex(Vector3(p0.x, _h(p0) + 0.3, p0.y))
			_im.surface_set_color(col)
			_im.surface_add_vertex(Vector3(p1.x, _h(p1) + 0.3, p1.y))
	_im.surface_end()
	for p in pts:
		_point(p, col)


func _point(p: Vector2, col: Color) -> void:
	_im.surface_begin(Mesh.PRIMITIVE_LINES)
	var y := _h(p) + 0.3
	for d in [Vector3(0.6, 0, 0), Vector3(0, 0, 0.6), Vector3(0, 1.2, 0)]:
		_im.surface_set_color(col)
		_im.surface_add_vertex(Vector3(p.x, y, p.y) - d)
		_im.surface_set_color(col)
		_im.surface_add_vertex(Vector3(p.x, y, p.y) + d)
	_im.surface_end()


func _h(p: Vector2) -> float:
	if world == null:
		return 0.0
	var h := world.cell_height(Vector2i(floori(p.x), floori(p.y)))
	return 0.0 if is_nan(h) else h
