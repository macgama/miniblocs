extends SceneTree
## Vérifie les plantes (assets/modeles/plantes/*.glb) et les textures du sol :
## chaque espèce du catalogue a son modèle, léger, posé au sol ; chaque biome
## de chaque climat trouve ses plantes ; la texture du terrain se construit.
## Usage : godot --headless --path . --import   (une fois, après de nouveaux .glb)
##         godot --headless --path . --script res://tests/plantes_test.gd

const MAX_TRIS := [400, 250, 250, 150, 150] # par catégorie (Plantes.Cat)
const MAX_TRIS_LOIN := 30

var _erreurs := 0


func _check(ok: bool, quoi: String) -> void:
	if ok:
		print("  ok  ", quoi)
	else:
		_erreurs += 1
		push_error("ÉCHEC : " + quoi)


func _initialize() -> void:
	print("Modèles :")
	var total := 0
	for e in Plantes.ESPECES.size():
		var m := Plantes.mesh(e)
		var nom := Plantes.nom(e)
		if m == null:
			_check(false, "modèle %s.glb importé" % nom)
			continue
		var tris := _tris(m)
		total += tris
		var b := m.get_aabb()
		var cat := Plantes.categorie(e)
		_check(tris > 0 and tris <= MAX_TRIS[cat], "%s : %d triangles (max %d)" % [nom, tris, MAX_TRIS[cat]])
		_check(b.position.y > -maxf(0.4, b.size.y * 0.2) and b.position.y < 0.05, "%s posé au sol (bas à %.2f m)" % [nom, b.position.y])
		if Plantes.a_version_loin(e):
			var ml := Plantes.mesh(e, true)
			_check(ml != null and _tris(ml) <= MAX_TRIS_LOIN, "%s_loin : %d triangles" % [nom, _tris(ml) if ml else -1])
			if ml:
				var hl := ml.get_aabb().end.y
				_check(absf(hl - b.end.y) < b.end.y * 0.3, "%s_loin a la même hauteur (%.1f / %.1f m)" % [nom, hl, b.end.y])
	print("  %d espèces, %d triangles en tout" % [Plantes.ESPECES.size(), total])
	_check(Plantes.hauteur(Plantes.id("sapin")) > 12.0 and Plantes.hauteur(Plantes.id("herbe")) < 1.0, "tailles réelles (sapin, herbe)")
	_check(Plantes.materiau().get_shader_parameter("palette") != null, "palette commune chargée")

	print("Biomes et climats :")
	var K := TerrainWorld.Kind
	for kind: int in [K.FORET, K.BROUSSAILLES, K.PRAIRIE, K.DESERT, K.MARAIS, K.MANGROVE, K.TOUNDRA, K.ALPAGE, K.ROCHE]:
		for c: int in Plantes.Climat.values():
			var vues := {}
			for n in 4000:
				var r := absi(hash(Vector2i(n, kind * 31 + c)))
				var e := Plantes.choisir(kind, c, 200.0, c == 1, float(r & 0xffff) / 65535.0, float((r >> 16) & 0xffff) / 65535.0)
				if e >= 0:
					vues[Plantes.nom(e)] = true
			if vues.is_empty():
				_check(false, "%s %s : aucune plante" % [TerrainWorld.KIND_NAMES[kind], Plantes.CLIMAT_NOMS[c]])
	_check(Plantes.choisir(K.NEIGE, 1, 100.0, false, 0.001, 0.5) == -1, "rien ne pousse sur la neige")
	_check(Plantes.choisir(K.MER, 1, -5.0, false, 0.001, 0.5) == -1, "rien ne pousse dans la mer")
	var montagne := Plantes.nom(Plantes.choisir(K.FORET, Plantes.Climat.TEMPERE, 1600.0, false, 0.001, 0.5))
	_check(montagne in ["sapin", "epicea", "meleze", "pin"], "forêt de montagne : conifères (%s)" % montagne)
	var tropiques := Plantes.nom(Plantes.choisir(K.FORET, Plantes.Climat.TROPICAL, 50.0, false, 0.001, 0.1))
	_check(tropiques == "tropical", "forêt tropicale (%s)" % tropiques)
	var cactus := Plantes.nom(Plantes.choisir(K.DESERT, Plantes.Climat.SUBTROPICAL, 600.0, true, 0.001, 0.5))
	_check(cactus == "cactus_saguaro", "cactus dans les déserts d'Amérique (%s)" % cactus)
	_check(Plantes.climat(48.85, 2.29) == Plantes.Climat.TEMPERE and Plantes.climat(43.3, 5.4) == Plantes.Climat.MEDITERRANEEN
		and Plantes.climat(64.0, 26.0) == Plantes.Climat.BOREAL and Plantes.climat(-3.0, -60.0) == Plantes.Climat.TROPICAL,
		"climats : Paris, Marseille, Finlande, Amazonie")

	print("Champs et textures du sol :")
	var cultures := {}
	for x in 30:
		for z in 30:
			cultures[Sols.culture(Vector2i(x * Sols.PARCELLE, z * Sols.PARCELLE), Plantes.Climat.TEMPERE)] = true
	_check(cultures.size() >= 6, "parcelles variées en climat tempéré (%d cultures)" % cultures.size())
	_check(Sols.culture(Vector2i(5, 7), 1) == Sols.culture(Vector2i(31, 0), 1), "une parcelle = une culture")
	_check(Sols.culture(Vector2i(-5, -7), 1) == Sols.culture(Vector2i(-5, -7), 1), "parcelles stables (coordonnées négatives)")
	for cu in Sols.CULTURES:
		_check(cu[2] == "" or Plantes.id(cu[2]) >= 0, "culture %s : plante connue" % cu[0])
	print("Étapes de vie :")
	var chene := Plantes.id("chene")
	var etapes := []
	for age in [1.0, 40.0, 150.0, 305.0]:
		etapes.append(Plantes.etape(chene, age)[2])
	_check(etapes == [0, 1, 2, 3], "chêne : pousse à 1 an, jeune à 40, adulte à 150, mort à 305 ans")
	_check(Plantes.etape(chene, 80.0)[0] == chene and absf(Plantes.etape(chene, 80.0)[1] - 1.0) < 0.01, "chêne adulte (taille réelle) à 80 ans")
	_check(Plantes.nom(Plantes.etape(Plantes.id("sapin"), 2.0)[0]) == "pousse_conifere", "jeune pousse de sapin = pousse de conifère")
	_check(Plantes.nom(Plantes.etape(Plantes.id("palmier"), 85.0)[0]) == "mort_palmier", "palmier mort")
	var jeunes: bool = Plantes.etape(chene, 20.0)[1] < Plantes.etape(chene, 50.0)[1]
	_check(jeunes, "un jeune arbre grandit")
	for nom_vie in Plantes.VIE:
		_check(Plantes.id(nom_vie) >= 0 and Plantes.vivace(Plantes.id(nom_vie)), "%s : 4 étapes" % nom_vie)
	for m in ["pousse_feuillu", "pousse_conifere", "pousse_palmier", "mort_feuillu", "mort_conifere", "mort_palmier"]:
		_check(Plantes.mesh(Plantes.id(m)) != null, "modèle %s" % m)
	print("Saisons :")
	var T := Plantes.Climat.TEMPERE
	_check(Plantes.saison(15.0, 48.0, T).feuilles < 0.05 and Plantes.saison(196.0, 48.0, T).feuilles > 0.95, "Paris : arbres nus en janvier, feuillus en juillet")
	_check(Plantes.saison(196.0, -35.0, T).feuilles < 0.05, "hémisphère sud : arbres nus en juillet")
	_check(Plantes.saison(285.0, 48.0, T).automne > 0.5, "feuilles rousses en octobre")
	_check(Plantes.saison(15.0, 0.0, Plantes.Climat.TROPICAL).feuilles == 1.0, "tropiques : toujours verts")
	var juillet := Sols.etat_cultures(196.0, 48.0)
	var aout := Sols.etat_cultures(228.0, 48.0)
	var avril := Sols.etat_cultures(105.0, 48.0)
	var octobre := Sols.etat_cultures(288.0, 48.0)
	_check(juillet.maturite[1] > 0.9 and juillet.taille[1] > 0.9, "blé doré en juillet")
	_check(avril.maturite[1] < 0.1 and avril.taille[1] > 0.3, "blé vert en avril")
	_check(aout.taille[1] == 0.0 and aout.couche[1] == Sols.CHAUME, "blé moissonné en août : chaume")
	_check(octobre.couche[1] == Sols.LABOUR, "labour en octobre avant les semis")
	_check(avril.maturite[2] > 0.9, "colza en fleur en avril")
	_check(Sols.etat_cultures(105.0, -30.0).taille[1] == 0.0 or Sols.etat_cultures(105.0, -30.0).couche[1] != Sols.CULTURES[1][1], "hémisphère sud : six mois de décalage")
	var tex := Sols.texture()
	_check(tex.get_layers() == Sols.COUCHES.size() and tex.get_width() == 256, "texture du sol : %d couches de %d px" % [tex.get_layers(), tex.get_width()])
	var herbe := (load(Sols.DOSSIER + "herbe.png") as Texture2D).get_image()
	if herbe.is_compressed():
		herbe.decompress()
	var moy := 0.0
	for i in 64:
		moy += herbe.get_pixel(i * 4, i * 3).r
	_check(absf(moy / 64.0 - 0.5) < 0.1, "texture détail centrée sur le gris moyen (%.2f)" % (moy / 64.0))
	for dossier in ["res://assets/textures/routes/", "res://assets/textures/eau/"]:
		var d := DirAccess.open(dossier)
		var n := 0
		if d:
			for f in d.get_files():
				if f.ends_with(".png"):
					n += 1
		_check(n > 0, "textures dans %s (%d)" % [dossier, n])

	print("PLANTES TEST OK" if _erreurs == 0 else "PLANTES TEST ÉCHEC (%d)" % _erreurs)
	quit(0 if _erreurs == 0 else 1)


func _tris(m: Mesh) -> int:
	var t := 0
	for s in m.get_surface_count():
		var arr := m.surface_get_arrays(s)
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		t += (idx.size() if idx.size() > 0 else verts.size()) / 3
	return t
