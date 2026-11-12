extends SceneTree
## Vérifie la bible de bâtiments modélisés dans Blender (assets/modeles/bible/) :
## chaque fiche est complète (catégorie, prix, métiers connus…), chaque .glb
## s'importe et se « cuit » en maillage à couleurs par sommet, léger, posé au
## sol, contenu dans son emprise, avec des vitres reconnues comme fenêtres ;
## les variantes changent les couleurs ; le catalogue et les métiers les voient.
## Usage : godot --headless --path . --import   (une fois, après de nouveaux .glb)
##         godot --headless --path . --script res://tests/bible_glb_test.gd

const MAX_TRIANGLES := 3000
const CATS := ["logement", "commerce", "industrie", "production", "services", "loisirs", "sport"]


func _initialize() -> void:
	var erreurs: Array[String] = []
	var entrees := BibleGlb.entries()
	if entrees.size() < 30:
		erreurs.append("bible trop petite : %d bâtiments" % entrees.size())
	var vitres := NightWindows.window_colors()
	var par_cat := {}
	for id: String in entrees:
		var t: Dictionary = entrees[id]
		par_cat[t.cat] = int(par_cat.get(t.cat, 0)) + 1
		_verifie_fiche(id, t, erreurs)
		_verifie_maillage(id, t, vitres, erreurs)
		if not BuildingCatalog.all_types().has(id):
			erreurs.append("%s absent du catalogue" % id)
	_verifie_variantes(entrees, erreurs)
	_verifie_metiers(erreurs)
	for e in erreurs:
		push_error("ÉCHEC : " + e)
	print("%d bâtiments de la bible vérifiés %s, %d erreur(s)" % [entrees.size(), str(par_cat), erreurs.size()])
	print("BIBLE GLB TEST OK" if erreurs.is_empty() else "BIBLE GLB TEST ÉCHEC")
	quit(0 if erreurs.is_empty() else 1)


func _verifie_fiche(id: String, t: Dictionary, erreurs: Array[String]) -> void:
	if String(t.get("name", "")) == "" or String(t.get("desc", "")) == "":
		erreurs.append("%s : nom ou description manquant" % id)
	if not CATS.has(String(t.get("cat", ""))):
		erreurs.append("%s : catégorie inconnue %s" % [id, t.get("cat")])
	if BuildingCatalog.cost(id) <= 0:
		erreurs.append("%s : pas de prix" % id)
	if int(t.w) < 3 or int(t.d) < 3:
		erreurs.append("%s : emprise trop petite" % id)
	if (t.access as Array).is_empty():
		erreurs.append("%s : pas d'accès" % id)
	if int(t.emplois) > 0 and not t.has("metiers"):
		erreurs.append("%s : des emplois mais pas de métiers" % id)
	for m in t.get("metiers", []):
		if not Metiers.METIERS.has(String(m[0])):
			erreurs.append("%s : métier inconnu %s" % [id, m[0]])
	if t.cat == "logement" and int(t.logements) <= 0:
		erreurs.append("%s : logement sans logements" % id)
	var r := false
	for reg in Styles.REGIONS:
		r = r or reg.id == t.region
	var e := false
	for era in Styles.ERAS:
		e = e or era.id == t.era
	if not r or not e:
		erreurs.append("%s : région ou époque inconnue (%s, %s)" % [id, t.region, t.era])


func _verifie_maillage(id: String, t: Dictionary, vitres: Array[Color], erreurs: Array[String]) -> void:
	if not BibleGlb.disponible(id):
		erreurs.append("%s : .glb introuvable ou non importé (lancer --import)" % id)
		return
	var m := BuildingCatalog.build_mesh(id, NightWindows.building_material())
	var arr := m.surface_get_arrays(0)
	var tris := (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	if tris == 0 or tris > MAX_TRIANGLES:
		erreurs.append("%s : %d triangles" % [id, tris])
	var b := m.get_aabb()
	if absf(b.position.y) > 0.05:
		erreurs.append("%s : ne repose pas sur le sol (%.2f)" % [id, b.position.y])
	if b.position.x < -float(t.w) / 2.0 - 0.05 or b.end.x > float(t.w) / 2.0 + 0.05 \
			or b.position.z < -float(t.d) / 2.0 - 0.05 or b.end.z > float(t.d) / 2.0 + 0.05:
		erreurs.append("%s : déborde de son emprise %d × %d (%s)" % [id, t.w, t.d, str(b)])
	# Des vitres que le shader reconnaît (fenêtres allumées la nuit).
	var cols: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	var fenetres := false
	for c in cols:
		for g in vitres:
			if absf(c.r - g.r) + absf(c.g - g.g) + absf(c.b - g.b) < 0.09:
				fenetres = true
				break
		if fenetres:
			break
	if not fenetres and int(t.get("sans_vitres", 0)) == 0:
		erreurs.append("%s : aucune vitre reconnue comme fenêtre" % id)


func _verifie_variantes(entrees: Dictionary, erreurs: Array[String]) -> void:
	var differentes := 0
	var avec := 0
	for id: String in entrees:
		if BuildingCatalog.variants_of(id) < 2:
			continue
		avec += 1
		var a := BibleGlb.couleurs(id, 0)
		var b := BibleGlb.couleurs(id, 1)
		if a != b:
			differentes += 1
	if avec > 0 and differentes < avec * 0.8:
		erreurs.append("variantes sans effet : %d sur %d" % [avec - differentes, avec])
	print("variantes de couleur OK : %d bâtiments sur %d" % [differentes, avec])


func _verifie_metiers(erreurs: Array[String]) -> void:
	if BibleGlb.entries().has("ecole_ferry"):
		if not Metiers.keys_of("ecole_ferry").has("ecole"):
			erreurs.append("l'école de village n'est pas reconnue comme école")
		if String(Metiers.jobs_for("ecole_ferry")[0][0]) != "enseignant":
			erreurs.append("l'école de village n'emploie pas d'enseignants")
	if BibleGlb.entries().has("eglise_romane") and not Metiers.venue_matches("priere", "eglise_romane"):
		erreurs.append("l'église romane n'accueille pas la vie spirituelle")
