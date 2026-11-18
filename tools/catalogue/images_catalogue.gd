extends SceneTree
## Images du catalogue (docs/catalogue/img) : une vignette par objet, rendue par le
## jeu lui-même, et les évolutions en images :
## - bâtiments : chantier (fouilles, fondations, gros œuvre, toit), terminé,
##   niveaux 2 et 3, usé, abandonné ; variantes de façade ;
## - meubles : le même meuble dans les styles de chaque époque ;
## - gares et ports : la version d'époque puis la moderne.
## Les lignées (même rôle à d'autres époques) se lisent dans le catalogue
## (CatalogueJeu, champ « lignee ») et réutilisent les vignettes.
##
## Écrit aussi img/index.json, lu par tools/catalogue/export_catalogue.gd pour
## brancher les images dans catalogue.html. À lancer avec affichage :
##   xvfb-run -a godot --path . --rendering-driver opengl3 --script res://tools/catalogue/images_catalogue.gd
##   ... -- --familles batiments,decors   --limite 20   --seul nubien__maison   --manquants
## Le rendu complet prend une vingtaine de minutes.

const PX := 160
const PXE := 160
const YAW := -35.0
const PITCH := 30.0

var dossier := "res://docs/catalogue/img"
var familles: Array = []
var limite := 0
var seul := ""
## --manquants : ne rend que les objets absents de index.json (après un ajout au catalogue).
var manquants := false
var manif := {}
var holder: Node3D
var cam: Camera3D
var _vc: StandardMaterial3D
var _n := 0
var _t0 := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		var v := args[i + 1] if i + 1 < args.size() else ""
		match args[i]:
			"--dossier": dossier = v
			"--familles": familles = Array(v.split(","))
			"--limite": limite = v.to_int()
			"--seul": seul = v
			"--manquants": manquants = true
	_t0 = Time.get_ticks_msec()
	root.transparent_bg = true
	root.size = Vector2i(PX, PX)
	var scene := Node3D.new()
	root.add_child(scene)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("dfe4ec")
	env.environment.ambient_light_energy = 0.55
	scene.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -20, 0)
	sun.light_energy = 0.9
	scene.add_child(sun)
	holder = Node3D.new()
	scene.add_child(holder)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	scene.add_child(cam)
	cam.current = true
	_vc = StandardMaterial3D.new()
	_vc.vertex_color_use_as_albedo = true
	var abs_dir := ProjectSettings.globalize_path(dossier)
	DirAccess.make_dir_recursive_absolute(abs_dir)
	# Index existant : un rendu partiel (--familles, --seul) le complète.
	if FileAccess.file_exists(abs_dir.path_join("index.json")):
		var old = JSON.parse_string(FileAccess.get_file_as_string(abs_dir.path_join("index.json")))
		if old is Dictionary:
			manif = old
	var par_fam := {}
	for e: Dictionary in CatalogueJeu.entrees():
		var f := String(e.fam)
		if not familles.is_empty() and not f in familles:
			continue
		if seul != "" and String(e.id) != seul:
			continue
		if manquants and manif.has(_cle(e)):
			continue
		par_fam[f] = int(par_fam.get(f, 0)) + 1
		if limite > 0 and int(par_fam[f]) > limite:
			continue
		await _objet(e)
	var f := FileAccess.open(abs_dir.path_join("index.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(manif, "", true))
	f.close()
	print("IMAGES OK : %d images en %d s, %d objets dans l'index" % [_n, (Time.get_ticks_msec() - _t0) / 1000, manif.size()])
	quit()


static func sur(id: String) -> String:
	return id.replace("/", "__").replace("@", "_").replace(" ", "_").replace(":", "_")


func _cle(e: Dictionary) -> String:
	return "%s/%s" % [e.fam, e.id]


func _chemin(sous: String, fam: String, id: String) -> String:
	return "%s/%s/%s.webp" % [sous, fam, sur(id)]


func _sauve(img: Image, rel: String) -> void:
	var p := ProjectSettings.globalize_path(dossier).path_join(rel)
	DirAccess.make_dir_recursive_absolute(p.get_base_dir())
	img.save_webp(p, true, 0.7)
	_n += 1
	if _n % 200 == 0:
		print("  %d images (%d s)" % [_n, (Time.get_ticks_msec() - _t0) / 1000])


# --- Prise de vue ----------------------------------------------------------------------------

func _vider() -> void:
	for c in holder.get_children():
		holder.remove_child(c)
		c.queue_free()


func _mi(mesh: Mesh, mat: Material = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	if mat != null:
		mi.material_override = mat
	elif mesh is ArrayMesh and mesh.get_surface_count() > 0 and mesh.surface_get_material(0) == null:
		mi.material_override = _vc
	return mi


static func _aabb_de(n: Node, xf := Transform3D.IDENTITY) -> AABB:
	var out := AABB()
	var vide := true
	var t: Transform3D = xf * ((n as Node3D).transform if n is Node3D else Transform3D.IDENTITY)
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		out = t * (n as MeshInstance3D).mesh.get_aabb()
		vide = false
	for c in n.get_children():
		var a := _aabb_de(c, t)
		if a.size == Vector3.ZERO:
			continue
		out = a if vide else out.merge(a)
		vide = false
	return out


## Cadre la caméra sur une boîte (vue de trois quarts, orthographique).
func _cadre(bb: AABB) -> void:
	var c := bb.get_center()
	var yaw := deg_to_rad(YAW)
	var pitch := deg_to_rad(PITCH)
	var dir := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	var r := maxf(bb.size.length() * 0.5, 0.3)
	cam.position = c + dir * (r * 4.0 + 10.0)
	cam.look_at(c)
	cam.near = 0.05
	cam.far = r * 10.0 + 40.0
	# Projection des coins pour un cadrage serré.
	var basis := cam.global_transform.basis
	var mx := 0.0
	var my := 0.0
	for i in 8:
		var p := bb.get_endpoint(i) - c
		mx = maxf(mx, absf(p.dot(basis.x)))
		my = maxf(my, absf(p.dot(basis.y)))
	cam.size = maxf(mx, my) * 2.0 * 1.08


## Rend les nœuds donnés (bb : cadrage imposé) et renvoie l'image.
func _photo(nodes: Array, px: int, bb := AABB()) -> Image:
	_vider()
	for n in nodes:
		holder.add_child(n)
	if bb.size == Vector3.ZERO:
		bb = _aabb_de(holder)
	_cadre(bb)
	root.size = Vector2i(px, px)
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _bande(imgs: Array, px: int) -> Image:
	var out := Image.create(px * imgs.size(), px, false, Image.FORMAT_RGBA8)
	for i in imgs.size():
		var im: Image = imgs[i]
		im.convert(Image.FORMAT_RGBA8)
		out.blit_rect(im, Rect2i(0, 0, px, px), Vector2i(i * px, 0))
	return out


func _vignette(e: Dictionary, nodes: Array) -> void:
	var rel := _chemin("v", String(e.fam), String(e.id))
	_sauve(await _photo(nodes, PX), rel)
	_entree(e)["v"] = rel


func _entree(e: Dictionary) -> Dictionary:
	var k := _cle(e)
	if not manif.has(k):
		manif[k] = {}
	return manif[k]


func _frise(e: Dictionary, quoi: String, imgs: Array, labels: Array) -> void:
	if imgs.size() < 2:
		return
	var rel := _chemin(quoi, String(e.fam), String(e.id))
	_sauve(_bande(imgs, PXE), rel)
	_entree(e)[quoi] = {"f": rel, "n": imgs.size(), "px": PXE, "l": labels}


# --- Par famille -------------------------------------------------------------------------------

func _objet(e: Dictionary) -> void:
	var id := String(e.id)
	match String(e.fam):
		"batiments":
			await _batiment(e)
		"vehicules":
			var m := VehicleCatalog.build_mesh(id, -1, _vc)
			if m != null and m.get_surface_count() > 0:
				var mi := _mi(m, _vc)
				mi.rotation_degrees.y = 90.0
				await _vignette(e, [mi])
		"decors":
			var m := Decors.mesh(id)
			if m != null:
				await _vignette(e, [_mi(m, Decors.materiau())])
		"meubles":
			await _meuble(e)
		"spectacles":
			var mid := "%s/%s" % [SpectaclesObjets.STYLE, id]
			if Meubles.has(mid):
				var m := MeublesModeles.mesh_of(mid)
				if m != null and m.get_surface_count() > 0:
					await _vignette(e, [_mi(m)])
		"toits":
			await _vignette(e, [_mi(VignettesAtelier.roof_mesh(id))])
		"ouvertures":
			await _vignette(e, [_mi(VignettesAtelier.opening_mesh(id))])
		"amenagements":
			await _vignette(e, [_mi(VignettesAtelier.amenagement_mesh(id))])
		"materiaux":
			var img := BlocMateriaux.image(int(id))
			if img != null:
				var rel := _chemin("v", "materiaux", id)
				_sauve(img, rel)
				_entree(e)["v"] = rel
				_entree(e)["pixel"] = true
		"stations":
			await _station(e)
		"voies":
			await _voie(e)
		"attractions":
			await _attraction(e)
		"agriculture":
			await _agri(e)
		"reseaux":
			await _reseau(e)


func _batiment(e: Dictionary) -> void:
	var id := String(e.id)
	var mat := NightWindows.building_material()
	var m := BuildingCatalog.build_mesh(id, mat)
	if m == null or m.get_surface_count() == 0:
		return
	await _vignette(e, [_mi(m, mat)])
	# Frise : du chantier à la vieillesse, cadrée sur le plus grand état.
	var t := BuildingCatalog.get_type(id)
	var w := float(t.get("w", 8))
	var d := float(t.get("d", 8))
	var bb := BatimentsVie.body_bounds(m)
	if bb.size == Vector3.ZERO:
		bb = m.get_aabb()
	var etats := []
	var labels := []
	var niveaux := {}
	if Ameliorations.ameliorable(id):
		for niv in [2, 3]:
			var b := {"t": id, "niv": niv}
			var mn: ArrayMesh
			if Personnalisation.can_shape(id):
				mn = BuildingCatalog.build_mesh(id, mat, true, 0, Ameliorations.perso_effectif(b))
			else:
				mn = Ameliorations.inserer_etages(m, Ameliorations.etages_inseres(b))
			if mn != null and mn.get_surface_count() > 0:
				niveaux[niv] = mn
	var cadre := m.get_aabb()
	for mn: ArrayMesh in niveaux.values():
		cadre = cadre.merge(mn.get_aabb())
	cadre = cadre.merge(AABB(Vector3(-w / 2.0 - 1.0, 0, -d / 2.0 - 1.0), Vector3(w + 2.0, 0.5, d + 2.0)))
	var haut := bb.end.y > 12.0
	if haut:
		cadre = cadre.merge(AABB(Vector3(bb.end.x, 0, bb.end.z), Vector3(4.0, bb.end.y + 9.0, 4.0)))
	if BatimentsVie.aura_chantier(id):
		for st in [[0.0, "Fouilles"], [0.22, "Fondations"], [0.6, "Gros œuvre"], [0.92, "Toit"]]:
			var h := bb.position.y + bb.size.y * float(st[0]) if float(st[0]) > 0.0 else -1.0
			etats.append(await _photo(_chantier(m, bb, w, d, h, haut), PXE, cadre))
			labels.append(st[1])
	etats.append(await _photo([_mi(m, mat)], PXE, cadre))
	labels.append("Terminé")
	for niv in niveaux:
		etats.append(await _photo([_mi(niveaux[niv], mat)], PXE, cadre))
		labels.append("Niveau %d" % niv)
	etats.append(await _photo([_mi(m, NightWindows.variant_material(5, 0))], PXE, cadre))
	labels.append("Usé")
	etats.append(await _photo([_mi(m, NightWindows.variant_material(3, 4))], PXE, cadre))
	labels.append("Abandonné")
	_frise(e, "evo", etats, labels)
	# Variantes de façade.
	var nv := mini(BuildingCatalog.variants_of(id), 6)
	if nv > 1:
		var vs := []
		var vl := []
		for v in nv:
			var mv := BuildingCatalog.build_mesh(id, mat, true, v)
			vs.append(await _photo([_mi(mv, mat)], PXE, mv.get_aabb()))
			vl.append("Variante %d" % (v + 1))
		_frise(e, "var", vs, vl)


## Nœuds d'un chantier à la hauteur h (h < 0 : fouilles seulement).
func _chantier(m: ArrayMesh, bb: AABB, w: float, d: float, h: float, haut: bool) -> Array:
	var out := []
	var cm := NightWindows.chantier_copy()
	cm.set_shader_parameter("chantier_h", h if h > 0.0 else -100.0)
	var ce := NightWindows.chantier_copy()
	ce.set_shader_parameter("chantier_h", h + 1.3 if h > 0.0 else -100.0)
	out.append(_mi(BatimentsVie._fouille_mesh(bb, w, d)))
	out.append(_mi(BatimentsVie._palissade_mesh(w, d), NightWindows.chantier_material()))
	if h > 0.0:
		out.append(_mi(m, cm))
		out.append(_mi(BatimentsVie._scaffold_mesh(bb), ce))
		var kd := BlocMesh.new()
		kd.box(bb.get_center().x, 0.0, bb.get_center().z, bb.size.x + 0.4, 1.0, bb.size.z + 0.4, Color("a9a59c"))
		out.append(_mi(kd.to_mesh(NightWindows.chantier_material())))
		if haut:
			out.append(BatimentsVie._grue(bb))
	if h < 0.0 or h < bb.size.y * 0.3:
		var pel := EnginsChantier.pelleteuse()
		pel.position = Vector3(bb.get_center().x + minf(bb.size.x * 0.2, 2.0), 0.15, bb.get_center().z)
		pel.rotation.y = 0.6
		out.append(pel)
	else:
		var tp := EnginsChantier.toupie()
		tp.position = Vector3(-minf(w * 0.25, 4.0), 0, -d / 2.0 - 3.2)
		tp.rotation.y = -PI / 2.0
		out.append(tp)
	return out


func _meuble(e: Dictionary) -> void:
	var tid := String(e.id)
	var cands := []
	for mid in Meubles.ids():
		if not String(mid).ends_with("/" + tid):
			continue
		var st := Meubles.style_of(String(mid).get_slice("/", 0))
		if st.is_empty() or String(mid).begins_with(MuseeObjets.STYLE + "/") or String(mid).begins_with(SpectaclesObjets.STYLE + "/"):
			continue
		cands.append([Meubles.era_index(String(st.get("era", ""))), String(mid), String(st.get("name", ""))])
	if cands.is_empty():
		return
	cands.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]) or int(a[0]) == int(b[0]) and String(a[1]) < String(b[1]))
	# Six styles au plus, répartis sur les époques.
	var pris := []
	var n := mini(6, cands.size())
	for i in n:
		pris.append(cands[roundi(float(i) * (cands.size() - 1) / maxf(n - 1, 1))])
	var mid0 := String(pris[pris.size() / 2][1])
	var m0 := MeublesModeles.mesh_of(mid0)
	if m0 == null or m0.get_surface_count() == 0:
		return
	await _vignette(e, [_mi(m0)])
	if pris.size() > 1:
		var imgs := []
		var labels := []
		for p in pris:
			var mm := MeublesModeles.mesh_of(String(p[1]))
			if mm == null or mm.get_surface_count() == 0:
				continue
			imgs.append(await _photo([_mi(mm)], PXE))
			labels.append(String(p[2]))
		_frise(e, "sty", imgs, labels)


func _station(e: Dictionary) -> void:
	var id := String(e.id)
	var t := StationSystem.get_type(id)
	var air := int(t.get("mode", -1)) == StationSystem.AIR
	var m := StationSystem.build_air_mesh(id) if air else StationSystem.build_network_mesh(id, 4.0)
	if m == null or m.get_surface_count() == 0:
		return
	await _vignette(e, [_mi(m)])
	if id in ["gare", "port"]:
		var ma := StationSystem.build_network_mesh(id, 4.0, true)
		var cadre := m.get_aabb().merge(ma.get_aabb())
		_frise(e, "evo", [await _photo([_mi(ma)], PXE, cadre), await _photo([_mi(m)], PXE, cadre)],
			["Avant %d" % (1900 if id == "gare" else 1880), "Moderne"])


func _voie(e: Dictionary) -> void:
	var id := String(e.id)
	var pts := PackedVector3Array()
	var st := PackedByteArray()
	for i in 7:
		pts.append(Vector3(0, 0, i * 5.0))
		st.append(0)
	var m := TransportView.build_mesh(id, {}, pts, st, func(_p: Vector3) -> float: return 0.0)
	if m != null and m.get_surface_count() > 0:
		var nodes: Array = [_mi(m)]
		# Voie d'eau : le plan d'eau n'est pas dans le maillage (il vient du terrain).
		if TransportTypes.mode_of(id) == TransportTypes.Mode.WATER:
			var w := float(TransportTypes.default_spec(id).get("width", 20.0))
			var k := BlocMesh.new()
			k.plate(0, 15.0, w, 30.0, Color("3f88c5"), -0.4, 0.1)
			for sg in [-1.0, 1.0]:
				k.plate(sg * (w / 2.0 + 3.0), 15.0, 6.0, 30.0, Color("6aa040"), -0.2, 0.3)
			nodes.append(_mi(k.to_mesh()))
		await _vignette(e, nodes)


func _attraction(e: Dictionary) -> void:
	var id := String(e.id)
	if VoiePieces.FAMILLES.has(id):
		var src := {"bois": "mine", "familial": "mine", "suspendu": "acier", "lance": "acier", "splash": "buches"}
		var cherche := [id, String(src.get(id, "")), String(src.get(VoiePieces.style(id), VoiePieces.style(id)))]
		for fam in cherche:
			for mo: Dictionary in AttractionsPerso.modeles():
				if String(mo.famille) != fam:
					continue
				var d := mo.duplicate(true)
				d.famille = id
				d.id = "img_" + id
				var c := AttractionsPerso.calcule(d)
				var mv := VoieMesh.voie(d, c.tr, c.sim, func(_p: Vector3) -> float: return 0.0)
				if mv.get_surface_count() > 0:
					await _vignette(e, [_mi(mv)])
				return
	elif VoiePieces.PIECES.has(id):
		var tex := VoiePieces.vignette(id, 96, Color("2f3e46"))
		if tex != null:
			var img := tex.get_image()
			var rel := _chemin("v", "attractions", id)
			_sauve(img, rel)
			_entree(e)["v"] = rel


func _agri(e: Dictionary) -> void:
	var id := String(e.id)
	if AgriDonnees.CULTURES.has(id):
		await _culture(e)
		return
	if not id.contains("@"):
		var esp: Dictionary = AgriDonnees.ESPECES.get(id, {})
		var mods: Array = esp.get("modeles", [])
		if not mods.is_empty() and Decors.mesh(String(mods[0])) != null:
			await _vignette(e, [_mi(Decors.mesh(String(mods[0])), Decors.materiau())])
		return
	var mid := id.get_slice("@", 0)
	var an := id.get_slice("@", 1).to_int()
	var modele := String(AgriDonnees.MACHINES.get(mid, {}).get("modele", ""))
	for v: Dictionary in AgriEpoques.VERSIONS.get(mid, []):
		if int(v.annee) == an and bool(v.get("absent", false)):
			return
		if int(v.annee) == an and v.has("modele"):
			modele = String(v.modele)
	if modele != "" and Decors.mesh(modele) != null:
		await _vignette(e, [_mi(Decors.mesh(modele), Decors.materiau())])


## Une parcelle de 12 m : sol labouré et quelques plants de la culture.
func _culture(e: Dictionary) -> void:
	var c: Dictionary = AgriDonnees.CULTURES[String(e.id)]
	var esp := Plantes.id(String(c.get("plante", "")))
	var pm: Mesh = Plantes.mesh(esp) if esp >= 0 else null
	var k := BlocMesh.new()
	k.plate(0, 0, 12.0, 12.0, Color("6a5038"))
	for i in 6:
		k.box(-5.0 + i * 2.0, 0.0, 0, 0.7, 0.18, 11.6, Color("7d6047"))
	var nodes: Array = [_mi(k.to_mesh())]
	if pm != null:
		var pas := 2.0 if float(c.get("densite", 1.0)) < 0.2 else 1.0
		var n := int(10.0 / pas)
		for i in n + 1:
			for j in n + 1:
				var mi := _mi(pm)
				mi.position = Vector3(-5.0 + i * pas + (0.3 if j % 2 else 0.0), 0.15, -5.0 + j * pas)
				mi.rotation.y = float((i * 7 + j * 13) % 10) * 0.6
				nodes.append(mi)
	else:
		var k2 := BlocMesh.new()
		for i in 6:
			for j in 6:
				k2.box(-5.0 + i * 2.0, 0.15, -5.0 + j * 2.0, 0.6, 0.5, 0.6, c.get("couleur", Color("6aa040")))
		nodes.append(_mi(k2.to_mesh()))
	await _vignette(e, nodes)


## Un tronçon de réseau : lignes sur pylônes ou poteaux, sinon tranchée ouverte
## avec la conduite ou le câble posé au fond.
func _reseau(e: Dictionary) -> void:
	var id := String(e.id)
	var tr := ReseauxTypes.troncon(id)
	var cable: Dictionary = Telecom.CABLES.get(id, {})
	var aerien := (not tr.is_empty() and String(tr.res) == "elec" and not bool(tr.get("enterre", false))) \
		or bool(cable.get("aerien", false))
	if aerien:
		# Deux supports assez proches pour qu'on les voie bien.
		var demi := float(tr.get("haut", 8.0)) * 1.4
		var pts := PackedVector3Array([Vector3(0, 0, -demi), Vector3(0, 0, demi)])
		var m := ReseauxVue.ligne_aerienne(pts, id if not tr.is_empty() else "ligne_bt")
		await _vignette(e, [_mi(m)])
		return
	var res := String(tr.get("res", "telecom"))
	var col: Color = ReseauxTypes.COULEURS.get(res, Telecom.COULEUR_FIBRE if String(cable.get("reseau", "")) == "fibre" else Telecom.COULEUR_CUIVRE)
	var spec: Dictionary = VueSouterraine.TRONCONS.get(id, {"d": 0.8, "s": 0.3})
	var s := clampf(float(spec.s), 0.15, 1.8)
	var prof := clampf(float(spec.d), 0.6, 4.0)
	var larg := s + 1.2
	var k := BlocMesh.new()
	var L := 10.0
	# Terre des deux côtés, fond de fouille, conduite, terre déblayée et bornes.
	for sg in [-1.0, 1.0]:
		k.box(sg * (larg / 2.0 + 2.0), -prof, 0, 4.0, prof, L, Color("8a6a4a"))
		k.box(sg * (larg / 2.0 + 2.0), 0.0, 0, 4.0, 0.08, L, Color("6aa040"))
	k.box(0, -prof - 0.2, 0, larg, 0.2, L, Color("5c4433"))
	if id == "aqueduc":
		k.box(0, -prof, 0, s + 0.6, s + 0.3, L, Color("c9c1ae"))
		k.box(0, -prof + 0.15, 0, s, 0.2, L, Color("4a90b8"))
	elif id == "egout_separatif":
		k.box(-s * 0.35, -prof, 0, s * 0.6, s * 0.6, L, col)
		k.box(s * 0.4, -prof, 0, s * 0.45, s * 0.45, L, Color("4cc9f0"))
	else:
		k.box(0, -prof, 0, s, s, L, col)
		if id == "reseau_chaleur":
			k.box(0, -prof + s + 0.05, 0, s, s, L, Color("e63946"))
	k.box(larg / 2.0 + 1.0, 0.0, -2.0, 1.4, 0.7, 3.0, Color("9b7b55"))
	k.box(-larg / 2.0 - 0.6, 0.0, L / 2.0 - 1.0, 0.25, 1.0, 0.25, col)
	await _vignette(e, [_mi(k.to_mesh())])
