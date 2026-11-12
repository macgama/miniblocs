extends SceneTree
## Vérifie les personnages arrondis (assets/modeles/personnages, Silhouettes) :
## chaque corps, coiffure et habit est importé et léger, le squelette a toutes
## ses articulations (origine au bon endroit), les tailles suivent l'âge, et
## l'apparence des habitants est stable et variée.
## Usage : godot --headless --path . --import   (une fois, après de nouveaux .glb)
##         godot --headless --path . --script res://tests/silhouettes_test.gd

const CORPS := ["bebe_x_moyen", "bebe_x_rond", "petit_x_mince", "petit_x_moyen", "petit_x_rond",
	"enfant_x_mince", "enfant_x_moyen", "enfant_x_rond", "ado_f_mince", "ado_f_moyen", "ado_f_rond",
	"ado_h_mince", "ado_h_moyen", "ado_h_rond", "adulte_f_mince", "adulte_f_moyen", "adulte_f_rond", "adulte_f_fort",
	"adulte_h_mince", "adulte_h_moyen", "adulte_h_rond", "adulte_h_fort", "senior_f_mince", "senior_f_moyen",
	"senior_f_rond", "senior_h_mince", "senior_h_moyen", "senior_h_rond"]
const COIFFURES := ["ras", "court", "raie", "boucles", "afro", "mi_long", "long", "queue", "chignon",
	"tresses", "locks", "calvitie", "bebe", "foulard", "turban", "casquette"]
const HABITS := ["jupe", "robe", "jupe_longue", "robe_longue"]
const MAX_TRIS := 1400

var _erreurs := 0


func _check(ok: bool, quoi: String) -> void:
	if ok:
		print("  ok  ", quoi)
	else:
		_erreurs += 1
		push_error("ÉCHEC : " + quoi)


func _initialize() -> void:
	print("Corps :")
	for nom in CORPS:
		var sc := Silhouettes._scene("corps/" + nom)
		if sc == null:
			_check(false, "corps %s importé" % nom)
			continue
		var n := Silhouettes.creer({"corps": nom})
		root.add_child(n)
		var rig := Silhouettes.os(n)
		var manque := []
		for k in Silhouettes.NOEUDS:
			if rig.get(k) == null:
				manque.append(k)
		var tris := _tris(n)
		var b := _aabb(n)
		_check(manque.is_empty() and tris <= MAX_TRIS, "%s : %d triangles, %.2f m, articulations %s" % [
			nom, tris, b.end.y, "complètes" if manque.is_empty() else "manquantes " + str(manque)])
		_check(absf(b.position.y) < 0.03, "%s : pieds au sol (%.3f)" % [nom, b.position.y])
		if manque.is_empty():
			var g := _g(rig.jambe_g)
			var gb := _g(rig.bras_g)
			var t := _g(rig.tete)
			_check(g.x > 0.0 and gb.x > g.x and t.y > gb.y - 0.1 and gb.y > g.y,
				"%s : hanche gauche en +X, épaule plus haut et plus large, cou au-dessus" % nom)
			var m := _g(rig.main_d)
			_check(m.x < 0.0 and m.y < gb.y, "%s : main droite au bout du bras (%.2f, %.2f)" % [nom, m.x, m.y])
		n.queue_free()

	print("Coiffures et habits :")
	for nom in COIFFURES:
		var sc := Silhouettes._scene("cheveux/" + nom)
		_check(sc != null, "coiffure %s importée" % nom)
	for nom in HABITS:
		_check(Silhouettes._scene("habits/" + nom) != null, "habit %s importé" % nom)

	print("Tailles selon l'âge :")
	var precedent := 0.0
	for age in [0.5, 2.0, 4.0, 8.0, 13.0, 16.0, 30.0, 80.0]:
		var look := Silhouettes.apparence(42, age, "H", "europe", 7)
		var n := Silhouettes.creer(look)
		root.add_child(n)
		var h := _aabb(n).end.y
		var cible := Silhouettes.taille_cible(age, "H")
		_check(absf(h - cible) < 0.15 * cible, "%s ans : %.2f m (visé %.2f), corps %s" % [age, h, cible, look.corps])
		if age <= 30.0:
			_check(h > precedent, "%s ans plus grand qu'avant" % age)
		precedent = h
		n.queue_free()

	print("Diversité :")
	var peaux := {}
	var coifs := {}
	var corps := {}
	var habits := {}
	var regions := ["europe", "afrique", "asie_est", "asie_sud", "moyen_orient", "ameriques", "oceanie", "mediterranee"]
	for i in 600:
		var look := Silhouettes.apparence(i, float(i % 90), "F" if i % 2 == 0 else "H", regions[i % regions.size()], i / 3)
		peaux[(look.peau as Color).to_html(false).substr(0, 2)] = true
		coifs[look.coiffure] = true
		corps[look.corps] = true
		habits[look.habit] = true
	_check(peaux.size() >= 8, "%d teintes de peau différentes" % peaux.size())
	_check(coifs.size() >= 14, "%d coiffures utilisées" % coifs.size())
	_check(corps.size() >= 26, "%d corps utilisés sur %d" % [corps.size(), CORPS.size()])
	_check(habits.size() == 5, "jupes, robes et pantalons : %s" % str(habits.keys()))
	var a := Silhouettes.apparence(17, 40.0, "F", "afrique", 5)
	var b := Silhouettes.apparence(17, 40.0, "F", "afrique", 5)
	_check(a.hash() == b.hash(), "apparence stable d'une fois à l'autre")

	print("Couleurs, tenue, poses :")
	var n2 := Silhouettes.creer(a)
	root.add_child(n2)
	Silhouettes.habiller(n2, {"haut": Color.WHITE, "bas": "1d3557", "manches": true})
	var rig2 := Silhouettes.os(n2)
	var torse := rig2.torse as GeometryInstance3D
	_check(torse.get_instance_shader_parameter("haut") == Color.WHITE, "tenue de métier : haut blanc")
	_check(torse.get_instance_shader_parameter("peau") == a.peau, "la peau ne change pas avec la tenue")
	_check(torse.material_override == Silhouettes.materiau(), "matériau commun (palette des rôles)")
	Silhouettes.poser(n2, "assis")
	var hanche_assis := _g(rig2.bassin).y
	_check(hanche_assis < 0.2, "assis : bassin sur l'assise (%.2f m)" % hanche_assis)
	Silhouettes.poser(n2, "couche")
	var bc := _aabb(n2)
	_check(bc.size.z > 1.2 and bc.size.y < 0.65 and bc.position.y > -0.1, "couché : allongé (%.2f m de long, de %.2f à %.2f m de haut) %s %s" % [bc.size.z, bc.position.y, bc.end.y, a.coiffure, a.habit])
	Silhouettes.poser(n2, "debout")
	Silhouettes.marcher(n2, 1.2, 1.0)
	_check(absf((rig2.jambe_g as Node3D).rotation.x) > 0.3, "marche : les jambes bougent")
	n2.queue_free()

	if _erreurs == 0:
		print("TEST OK : silhouettes")
	else:
		print("TEST ÉCHEC : silhouettes (%d erreurs)" % _erreurs)
	quit(1 if _erreurs else 0)


func _tris(n: Node) -> int:
	var t := 0
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var m := (n as MeshInstance3D).mesh
		for s in m.get_surface_count():
			var arr := m.surface_get_arrays(s)
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			t += (idx.size() if idx.size() > 0 else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	for c in n.get_children():
		t += _tris(c)
	return t


func _aabb(n: Node) -> AABB:
	var r := AABB()
	var first := true
	for mi in _meshes(n):
		var b := _xf(mi) * mi.mesh.get_aabb()
		if first:
			r = b
			first = false
		else:
			r = r.merge(b)
	return r


func _meshes(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		out.append(n)
	for c in n.get_children():
		out.append_array(_meshes(c))
	return out


## Transformation globale sans arbre de scène (le test tourne dans _initialize).
func _xf(n: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var c := n
	while c != null and c is Node3D:
		t = (c as Node3D).transform * t
		c = c.get_parent()
	return t


func _g(n: Node3D) -> Vector3:
	return _xf(n).origin
