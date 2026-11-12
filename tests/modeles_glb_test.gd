extends SceneTree
## Vérifie les bâtiments modélisés dans Blender (assets/modeles/batiments/*.glb) :
## chaque fichier s'importe, reste léger (peu de triangles, petite texture),
## a une taille réaliste en mètres et repose sur le sol (origine au pied).
## Usage : godot --headless --path . --import   (une fois, après un nouveau .glb)
##         godot --headless --path . --script res://tests/modeles_glb_test.gd

const DOSSIER := "res://assets/modeles/batiments"
const MAX_TRIANGLES := 3000
const MAX_TEXTURE := 256


func _initialize() -> void:
	var erreurs: Array[String] = []
	var nb := 0
	var d := DirAccess.open(DOSSIER)
	if d == null:
		erreurs.append("dossier introuvable " + DOSSIER)
	else:
		for f in d.get_files():
			if f.ends_with(".glb"):
				nb += 1
				_verifie(DOSSIER.path_join(f), erreurs)
	for e in erreurs:
		push_error("ÉCHEC : " + e)
	var ok := erreurs.is_empty() and nb > 0
	print("%d modèle(s) .glb vérifié(s), %d erreur(s)" % [nb, erreurs.size()])
	print("MODELES GLB TEST OK" if ok else "MODELES GLB TEST ÉCHEC")
	quit(0 if ok else 1)


func _verifie(chemin: String, erreurs: Array[String]) -> void:
	var scene := load(chemin) as PackedScene
	if scene == null:
		erreurs.append("import impossible " + chemin + " (lancer --import d'abord)")
		return
	var racine := scene.instantiate() as Node3D
	var tris := 0
	var boite := AABB()
	var premiere := true
	var textures_ok := true
	for mi in _meshes(racine):
		var m := mi.mesh
		for s in m.get_surface_count():
			var arr := m.surface_get_arrays(s)
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			tris += (idx.size() if idx.size() > 0 else verts.size()) / 3
			var mat := m.surface_get_material(s) as BaseMaterial3D
			if mat and mat.albedo_texture:
				var t := mat.albedo_texture
				if t.get_width() > MAX_TEXTURE or t.get_height() > MAX_TEXTURE:
					textures_ok = false
		var b := mi.transform * m.get_aabb()
		boite = b if premiere else boite.merge(b)
		premiere = false
	racine.free()
	print("%s : %d triangles, %.1f x %.1f x %.1f m" % [chemin.get_file(), tris, boite.size.x, boite.size.y, boite.size.z])
	if tris == 0 or tris > MAX_TRIANGLES:
		erreurs.append("%s : %d triangles (max %d)" % [chemin, tris, MAX_TRIANGLES])
	if not textures_ok:
		erreurs.append("%s : texture plus grande que %d px" % [chemin, MAX_TEXTURE])
	if absf(boite.position.y) > 0.05:
		erreurs.append("%s : ne repose pas sur le sol (bas à %.2f m)" % [chemin, boite.position.y])
	if boite.size.y < 1.0 or boite.size.y > 400.0 or boite.size.x < 1.0:
		erreurs.append("%s : taille irréaliste %s" % [chemin, str(boite.size)])


func _meshes(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		out.append(n)
	for c in n.get_children():
		out.append_array(_meshes(c))
	return out
