extends SceneTree
## Vérifie les tenues des personnages (Tenues) : uniformes selon l'époque et
## la région, vêtements des passants selon l'époque, la saison, la météo et
## l'âge, chapeaux et objets légers, apparence stable.
## Usage : godot --headless --path . --script res://tests/tenues_test.gd

const MAX_TRIS_OBJET := 400

var _erreurs := 0


func _check(ok: bool, quoi: String) -> void:
	if ok:
		print("  ok  ", quoi)
	else:
		_erreurs += 1
		push_error("ÉCHEC : " + quoi)


func _ctx(annee: int, temp := 16.0, pluie := 0.0, saison := 1, region := "europe") -> Dictionary:
	return {"annee": annee, "temp": temp, "pluie": pluie, "neige": 0.0, "saison": saison, "region": region}


func _initialize() -> void:
	print("Uniformes :")
	_check(String(Tenues.uniforme("pompier", 1850).chapeau) == "casque_laiton", "pompier de 1850 : casque de laiton")
	_check(String(Tenues.uniforme("pompier", 2025).chapeau) == "casque_f1" and int(Tenues.uniforme("pompier", 2025).motif) == Tenues.Motif.BANDES,
		"pompier d'aujourd'hui : casque F1 et bandes réfléchissantes")
	_check(String(Tenues.uniforme("pompier", 2025, "ameriques").chapeau) == "casque_us", "pompier américain : casque à bord arrière")
	_check(String(Tenues.uniforme("policier", 1820).chapeau) == "bicorne" and String(Tenues.uniforme("policier", 1910).chapeau) == "kepi",
		"gendarme au bicorne en 1820, agent au képi en 1910")
	_check(String(Tenues.uniforme("medecin", 1850).get("chapeau", "")) == "" and int(Tenues.uniforme("medecin", 1850).motif) == Tenues.Motif.COSTUME,
		"médecin de 1850 en redingote")
	_check(Tenues.uniforme("carrier", 2025) == Tenues.uniforme("ouvrier", 2025), "le carrier porte la tenue d'ouvrier")
	_check(Tenues.uniforme("aide_soignant", 1850).size() > 0, "aide-soignant de 1850 : tenue de l'époque suivante faute de mieux")
	_check(Tenues.uniforme("vendeur", 2025).is_empty(), "vendeur : pas d'uniforme")
	var noms := {}
	var plantes := 0
	for met in Metiers.METIERS:
		for a in [1820, 1900, 1960, 2025]:
			var look := Silhouettes.apparence(42, 35.0, "F", "europe", 1, _ctx(a))
			Tenues.metier(look, String(met), "F", _ctx(a))
			if not look.haut is Color or not look.bas is Color:
				plantes += 1
			if String(look.get("chapeau", "")) != "":
				noms[look.chapeau] = true
			for o in look.objets:
				noms[String(o[0])] = true
	_check(plantes == 0, "%d métiers × 4 époques habillés" % Metiers.METIERS.size())

	print("Passants selon l'époque :")
	var longues := 0
	var femmes := 0
	var chapeaux_1850 := 0
	var hommes := 0
	var chapeaux_2025 := 0
	for i in 200:
		var f := Silhouettes.apparence(1000 + i, 30.0 + i % 40, "F", "europe", i, _ctx(1850))
		femmes += 1
		if String(f.habit) in ["robe_longue", "jupe_longue"]:
			longues += 1
		var h := Silhouettes.apparence(5000 + i, 30.0 + i % 40, "H", "europe", i, _ctx(1850))
		hommes += 1
		if String(h.chapeau) != "":
			chapeaux_1850 += 1
		var h2 := Silhouettes.apparence(5000 + i, 30.0 + i % 40, "H", "europe", i, _ctx(2025))
		if String(h2.chapeau) != "":
			chapeaux_2025 += 1
		for x in [f, h, h2]:
			if String(x.chapeau) != "":
				noms[x.chapeau] = true
			for o in x.objets:
				noms[String(o[0])] = true
	_check(longues == femmes, "1850 : toutes les femmes en robe ou jupe longue (%d/%d)" % [longues, femmes])
	_check(chapeaux_1850 > hommes * 0.6, "1850 : la plupart des hommes portent un chapeau (%d/%d)" % [chapeaux_1850, hommes])
	_check(chapeaux_2025 < hommes * 0.1, "aujourd'hui : peu de chapeaux par temps doux (%d/%d)" % [chapeaux_2025, hommes])

	print("Saisons, météo, âge :")
	var shorts_hiver := 0
	var bras_nus_ete := 0
	var bonnets := 0
	var parapluies := 0
	var cartables := 0
	var cannes := 0
	for i in 300:
		var age := 8.0 + float(i % 80)
		var s := "F" if i % 2 == 0 else "H"
		var hiver := Silhouettes.apparence(i, age, s, "europe", i, _ctx(2025, -4.0, 0.0, 0))
		if float(hiver.jambes) < 0.5 or float(hiver.manches) < 0.5:
			shorts_hiver += 1
		if String(hiver.chapeau) == "bonnet_hiver":
			bonnets += 1
		var ete := Silhouettes.apparence(i, age, s, "europe", i, _ctx(2025, 30.0, 0.0, 2))
		if float(ete.manches) < 0.5:
			bras_nus_ete += 1
		var pluie := Silhouettes.apparence(i, age, s, "europe", i, _ctx(2025, 10.0, 0.8, 3))
		for o in pluie.objets:
			match String(o[0]):
				"parapluie":
					parapluies += 1
				"sac_dos", "cartable":
					if age < 18.0:
						cartables += 1
				"canne":
					cannes += 1
		for x in [hiver, ete, pluie]:
			if String(x.chapeau) != "":
				noms[x.chapeau] = true
			for o in x.objets:
				noms[String(o[0])] = true
	_check(shorts_hiver == 0, "−4 °C : personne en short ni bras nus")
	_check(bonnets > 30, "−4 °C : des bonnets (%d)" % bonnets)
	_check(bras_nus_ete > 100, "30 °C : beaucoup de bras nus (%d/300)" % bras_nus_ete)
	_check(parapluies > 40 and parapluies < 200, "sous la pluie : des parapluies, pas pour tous (%d/300)" % parapluies)
	_check(cartables > 5, "des écoliers avec un sac (%d)" % cartables)
	_check(cannes > 3, "des personnes âgées avec une canne (%d)" % cannes)
	var a1 := Silhouettes.apparence(77, 40.0, "F", "afrique", 3, _ctx(2025, 10.0, 0.8))
	var a2 := Silhouettes.apparence(77, 40.0, "F", "afrique", 3, _ctx(2025, 10.0, 0.8))
	_check(str(a1) == str(a2), "apparence stable pour un même contexte")
	var sans := Silhouettes.apparence(77, 40.0, "F", "afrique", 3, {})
	_check(String(sans.chapeau) == "" and (sans.objets as Array).is_empty(), "contexte vide : vêtements de tous les jours")

	print("Chapeaux et objets :")
	var manque := []
	var lourds := []
	for nom in noms:
		var m := Tenues.maillage(String(nom))
		if m == null:
			manque.append(nom)
			continue
		var tris := 0
		for si in m.get_surface_count():
			tris += int(m.surface_get_arrays(si)[Mesh.ARRAY_VERTEX].size() / 3.0)
		if tris > MAX_TRIS_OBJET:
			lourds.append("%s (%d)" % [nom, tris])
	_check(manque.is_empty(), "%d chapeaux et objets ont un maillage %s" % [noms.size(), "" if manque.is_empty() else str(manque)])
	_check(lourds.is_empty(), "chacun fait moins de %d triangles %s" % [MAX_TRIS_OBJET, "" if lourds.is_empty() else str(lourds)])
	_check(Tenues.maillage("haut_de_forme") == Tenues.maillage("haut_de_forme"), "maillages partagés (un seul par chapeau)")

	if Silhouettes.disponible():
		print("Personnages construits :")
		var look := Silhouettes.apparence(9, 40.0, "H", "europe", 9, _ctx(1850, -2.0, 0.9))
		look.chapeau = "haut_de_forme"
		look.objets = [["echarpe", "torse"], ["parapluie", "torse"]]
		var n := Silhouettes.creer(look)
		root.add_child(n)
		var rig := Silhouettes.os(n)
		_check((rig.tete as Node3D).get_node_or_null("Chapeau") != null, "le chapeau est posé sur la tête")
		_check(n.has_meta("tient") and String(n.get_meta("tient").g) == "parapluie", "le bras gauche tient le parapluie")
		Silhouettes.marcher(n, 1.0, 1.0)
		_check(absf((rig.avant_bras_g as Node3D).rotation.x + 2.3) < 0.01, "en marchant, le parapluie reste levé")
		_check(_meshes(n) <= 15 + 3, "au plus 3 maillages de plus que le corps (%d)" % _meshes(n))
		n.queue_free()
		var fig := Figurine.creer(-1234, "pompier")
		root.add_child(fig)
		_check(fig.silhouette != null, "figurine sans habitant (secours, chantiers) : personnage arrondi, plus de blocs")
		fig.queue_free()

	if _erreurs == 0:
		print("TEST OK : tenues")
	else:
		print("TEST ÉCHOUÉ : %d erreur(s)" % _erreurs)
	quit(1 if _erreurs > 0 else 0)


func _meshes(n: Node) -> int:
	var c := 1 if n is MeshInstance3D else 0
	for k in n.get_children():
		c += _meshes(k)
	return c
