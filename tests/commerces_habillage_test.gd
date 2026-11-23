extends SceneTree
## Test de l'habillage des petits commerces (DevanturesHabillage), sans scène :
## commerces concernés, thèmes par région et par époque, toit plat ou en pente,
## maillages en cache et budget de triangles pour TOUS les petits commerces du
## catalogue à trois époques.
## Usage : godot --headless --path . --script res://tests/commerces_habillage_test.gd

## Budget de triangles par commerce (loin : silhouettes ; près : petits objets).
const MAX_LOIN := 5000
const MAX_PRES := 5000

var _echecs := 0


func _initialize() -> void:
	_run()


func _ok(cond: bool, msg: String) -> void:
	if cond:
		print("  ok  ", msg)
	else:
		_echecs += 1
		push_error("ÉCHEC : " + msg)


func _tris(m: Mesh) -> int:
	var n := 0
	for s in m.get_surface_count():
		n += (m.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return n


func _geo(dev: Devantures, id: String) -> Dictionary:
	var mi := MeshInstance3D.new()
	mi.mesh = BuildingCatalog.build_mesh(id)
	var p := DevanturesTypes.profil(id)
	var g := dev._geometrie(mi, p)
	g["mes"] = DevanturesHabillage.mesures(mi.mesh, g.origine, float(g.l), float(g.prof))
	var st: Dictionary = Styles.STYLES.get(String(BuildingCatalog.get_type(id).get("style", "")), {})
	g["fh"] = float(st.get("floor_h", 3.2))
	mi.free()
	return g


func _run() -> void:
	var dev := Devantures.new()
	print("Commerces concernés")
	_ok(DevanturesHabillage.concerne(DevanturesTypes.profil("boulangerie"), 8.0, 11.0), "la boulangerie est habillée")
	_ok(DevanturesHabillage.concerne(DevanturesTypes.profil("japonais__restaurant"), 10.0, 12.0), "le restaurant japonais est habillé")
	_ok(not DevanturesHabillage.concerne(DevanturesTypes.profil("supermarche"), 20.0, 20.0), "pas le supermarché")
	_ok(not DevanturesHabillage.concerne(DevanturesTypes.profil("maison"), 8.0, 8.0), "pas les maisons")
	_ok(not DevanturesHabillage.concerne(DevanturesTypes.profil("mairie"), 12.0, 12.0), "pas la mairie")

	print("Thèmes par époque")
	var pb := DevanturesTypes.profil("boulangerie")
	var t1850 := DevanturesHabillage.theme("boulangerie", pb, 1850, 0)
	var t2025 := DevanturesHabillage.theme("boulangerie", pb, 2025, 0)
	_ok(not bool(t1850.clim) and not bool(t1850.neon) and not bool(t1850.distributeur), "1850 : ni clim, ni néon, ni distributeur")
	_ok(String(t1850.lampadaire) == "gaz" and String(DevanturesHabillage.lampadaire_de(1810, "europe")) == "", "lampadaire à gaz en 1850, aucun en 1810")
	_ok(bool(t2025.clim) and String(t2025.lampadaire) == "led", "2025 : clim et lampadaire LED")
	_ok(String(DevanturesHabillage.lampadaire_de(1925, "europe")) == "fonte" and String(DevanturesHabillage.lampadaire_de(1970, "europe")) == "crosse", "fonte en 1925, crosse en 1970")

	print("Thèmes par région")
	var pj := DevanturesTypes.profil("japonais__restaurant")
	var tj := DevanturesHabillage.theme("japonais__restaurant", pj, 2025, 0)
	_ok(String(tj.region) == "asie_est" and bool(tj.comptoir) and String(tj.lanternes) == "papier", "Japon : comptoir sur rue et lanternes de papier")
	_ok(bool(tj.noren) and bool(tj.distributeur) and String(tj.arbre) == "cerisier", "Japon : noren, distributeur, cerisier")
	var tm := DevanturesHabillage.theme("maghreb__boutique", DevanturesTypes.profil("maghreb__boutique"), 2025, 0)
	_ok(String(tm.lanternes) == "cuivre" and bool(tm.cuves) and String(tm.grimpante) == "bougainvillier", "Médina : lanternes de cuivre, cuves sur le toit, bougainvillier")
	var tc := DevanturesHabillage.theme("colonial__boutique", DevanturesTypes.profil("colonial__boutique"), 1930, 0)
	_ok(bool(tc.chateau_eau) and bool(tc.echelle), "Amérique du Nord 1930 : château d'eau et échelle")
	_ok(not bool(DevanturesHabillage.theme("colonial__boutique", DevanturesTypes.profil("colonial__boutique"), 2025, 0).chateau_eau), "plus de château d'eau neuf après 1995")

	print("Toits")
	var ga := _geo(dev, "asie_dense__restaurant")
	_ok(bool(ga.mes.plat) and float(ga.mes.toit_y) > 3.0, "mégapole asiatique : toit plat à %.1f m" % float(ga.mes.toit_y))
	var gj := _geo(dev, "japonais__boutique")
	_ok(not bool(gj.mes.plat), "Japon traditionnel : toit en pente (%.1f → %.1f m)" % [float(gj.mes.toit_y), float(gj.mes.toit_max)])
	_ok(float(gj.mes.facade) > 2.5, "hauteur de façade lue (%.1f m)" % float(gj.mes.facade))

	print("Maillages et cache")
	var m1 := DevanturesHabillage.maillages(ga, DevanturesHabillage.theme("asie_dense__restaurant", DevanturesTypes.profil("asie_dense__restaurant"), 2025, 1), 4)
	var m2 := DevanturesHabillage.maillages(ga, DevanturesHabillage.theme("asie_dense__restaurant", DevanturesTypes.profil("asie_dense__restaurant"), 2025, 1), 4)
	_ok(m1.loin is ArrayMesh and (m1.loin as ArrayMesh).get_surface_count() > 0 and (m1.pres as ArrayMesh).get_surface_count() > 0, "deux maillages non vides")
	_ok(m1.loin == m2.loin and m1.pres == m2.pres, "même commerce, même époque : maillages partagés")
	# Restaurant japonais à étage : enseigne verticale en néon.
	var gr := _geo(dev, "japonais__restaurant")
	m1 = DevanturesHabillage.maillages(gr, DevanturesHabillage.theme("japonais__restaurant", DevanturesTypes.profil("japonais__restaurant"), 2025, 0), 4)
	var neon := false
	for s in (m1.loin as ArrayMesh).get_surface_count():
		if (m1.loin as ArrayMesh).surface_get_material(s) == DevanturesHabillage.mat_neon(false):
			neon = true
	_ok(neon, "l'enseigne verticale a sa couche néon")
	var mi := MeshInstance3D.new()
	mi.mesh = m1.loin
	DevanturesHabillage.allumer(mi, true, true)
	var allume := false
	for s in mi.mesh.get_surface_count():
		if mi.get_surface_override_material(s) == DevanturesHabillage.mat_neon(true):
			allume = true
	_ok(allume, "le soir, les néons s'allument")
	DevanturesHabillage.allumer(mi, false, false)
	var eteint := true
	for s in mi.mesh.get_surface_count():
		if mi.get_surface_override_material(s) != null:
			eteint = false
	_ok(eteint, "le jour, tout est éteint")
	mi.free()
	_ok(DevanturesHabillage.places_comptoir(4.6).size() >= 2, "au moins deux tabourets au comptoir")

	print("Tous les petits commerces, en 1850, 1925 et 2025")
	var all := BuildingCatalog.all_types()
	var n := 0
	var pire_l := 0
	var pire_p := 0
	var pire_id := ""
	for id in all:
		var p := DevanturesTypes.profil(String(id))
		if p.is_empty() or not String(p.genre) in [DevanturesTypes.BOUTIQUE, DevanturesTypes.SALLE]:
			continue
		var g := _geo(dev, String(id))
		if not DevanturesHabillage.concerne(p, float(g.l), float(g.prof)):
			continue
		n += 1
		for an in [1850, 1925, 2025]:
			var ms := DevanturesHabillage.maillages(g, DevanturesHabillage.theme(String(id), p, an, n % 3), 4)
			var tl := _tris(ms.loin)
			var tp := _tris(ms.pres)
			if tl + tp > pire_l + pire_p:
				pire_l = tl
				pire_p = tp
				pire_id = "%s (%d)" % [id, an]
			if tl > MAX_LOIN or tp > MAX_PRES:
				_ok(false, "%s en %d : %d + %d triangles" % [id, an, tl, tp])
	_ok(n >= 100, "%d petits commerces habillés" % n)
	print("  le plus lourd : %s, %d triangles de loin + %d de près" % [pire_id, pire_l, pire_p])
	dev.free()
	if _echecs > 0:
		print("COMMERCES HABILLAGE : %d échec(s)" % _echecs)
		quit(1)
		return
	print("COMMERCES HABILLAGE OK")
	quit(0)
