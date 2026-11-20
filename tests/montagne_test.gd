extends SceneTree
## Routes en montagne : pentes de montagne, terrassement automatique des bouts,
## zone orange (pente et épingles tolérées, plus chères et plus lentes), lacets.
## Usage : godot --headless --path . --script res://tests/montagne_test.gd

var ok := true


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	if not cond:
		push_error("ÉCHEC : " + what)
		ok = false
	else:
		print("  ok  ", what)


## Pente régulière le long de x : h = pente × x.
static func _rampe(pente: float) -> Callable:
	return func(x: float, _z: float) -> float: return 500.0 + pente * x


static func _p(t: String, x1: float, g: Callable, h0 := NAN, h1 := NAN) -> Dictionary:
	return RoutePlanner.plan(t, PackedVector2Array([Vector2(0, 0), Vector2(x1, 0)]), h0, h1, g)


func _run() -> void:
	print("Pentes de montagne :")
	_check(is_equal_approx(TransportTypes.grade_norme("departementale"), 0.10), "départementale : 10 % (routes alpines)")
	_check(is_equal_approx(TransportTypes.grade_tolere("departementale"), 0.15), "départementale : 15 % en zone orange")
	_check(TransportTypes.grade_tolere("train") < TransportTypes.grade_tolere("departementale") * 0.5, "le train reste bien plus exigeant que la route")
	_check(is_equal_approx(TransportTypes.grade_norme("voie_etroite"), 0.07), "voie métrique : 70 ‰ (Bernina)")

	# Les deux bouts raccordés (hauteurs imposées) : pas de terrassement des bouts.
	var vert := _p("departementale", 200, _rampe(0.09), 500.0, 518.0)
	_check(vert.ok and not vert.orange, "9 %% : vert (%s)" % vert.reason)
	var orange := _p("departementale", 200, _rampe(0.13), 500.0, 526.0)
	_check(orange.ok and orange.orange and String(orange.avert).contains("pente"), "13 %% : zone orange (%s)" % orange.get("avert", orange.reason))
	var rouge := _p("departementale", 200, _rampe(0.2), 500.0, 540.0)
	_check(not rouge.ok and String(rouge.reason).begins_with("Pente trop forte") and String(rouge.reason).contains("Lacets"), "20 % : refus avec conseil Lacets")

	print("Terrassement automatique :")
	# Bout libre : 11 % sur 200 m (22 m) → le bout du haut est creusé de 2 m, vert.
	var terr := _p("departementale", 200, _rampe(0.11), 500.0, NAN)
	_check(terr.ok and not terr.orange and absf(float(terr.terr_bout) - 2.0) < 0.05, "11 %% : bout creusé de %s m, reste vert" % str(snappedf(float(terr.terr_bout), 0.01)))
	var last: Vector3 = terr.pts[terr.pts.size() - 1]
	_check(absf(last.y - 520.0) < 0.05, "le bout terrassé est à 2 m sous le terrain (%.2f)" % (last.y - 522.0))
	# Au-delà de 3 m de terrassement : zone orange.
	var terr2 := _p("departementale", 200, _rampe(0.14), 500.0, NAN)
	_check(terr2.ok and terr2.orange and is_equal_approx(float(terr2.terr_bout), RoutePlanner.TERRASSEMENT_BOUT), "14 % : 3 m creusés puis zone orange")
	var vol := RoutePlanner.volumes(9.5, terr.pts, terr.st, _rampe(0.11))
	_check(float(vol.deblai) > 50.0 and float(vol.gros) > 0.0, "volumes de déblai (%d m³, dont %d m³ au-delà de 1 m)" % [roundi(vol.deblai), roundi(vol.gros)])
	var plan := terr2.duplicate()
	plan.volumes = RoutePlanner.volumes(9.5, terr2.pts, terr2.st, _rampe(0.14))
	var sc := TransportSystem.surcout(plan, 9.5)
	_check(sc >= roundi(200.0 * 9.5 * TransportSystem.PRIX_ZONE_ORANGE), "surcoût zone orange + terrassement : %d €" % sc)

	print("Virages serrés :")
	var flat := func(_x: float, _z: float) -> float: return 100.0
	# Épingle de 14 m sur une départementale (norme 240 m) : orange.
	var bend := _arc(14.0)
	var ep := RoutePlanner.plan("departementale", bend, NAN, NAN, flat)
	_check(ep.ok and ep.orange and String(ep.avert).contains("épingle"), "épingle de %d m : zone orange (%s)" % [roundi(ep.min_radius), ep.get("avert", ep.reason)])
	var trop := RoutePlanner.plan("departementale", _arc(7.0), NAN, NAN, flat)
	_check(not trop.ok and String(trop.reason).begins_with("Virage trop serré"), "rayon de 7 m : refusé (%s)" % trop.reason)
	var auto := RoutePlanner.plan("autoroute", _arc(100.0), NAN, NAN, flat)
	_check(not auto.ok, "pas d'épingle sur une autoroute")

	print("Lacets :")
	var colline := _rampe(0.25)
	var a := Vector2(0, 0)
	var b := Vector2(220, 0)
	var droit := RoutePlanner.plan("departementale", PackedVector2Array([a, b]), NAN, NAN, colline)
	_check(not droit.ok, "25 % en ligne droite : refusé")
	var lp := RoutePlanner.lacets(a, b, colline.call(a.x, a.y), colline.call(b.x, b.y), "departementale")
	_check(lp.size() > 10, "tracé en lacets proposé (%d points)" % lp.size())
	var lac := RoutePlanner.plan("departementale", lp, NAN, NAN, colline)
	_check(lac.ok, "les lacets se construisent (%s)" % lac.get("reason", ""))
	_check(lac.ok and float(lac.length) > 500.0 and float(lac.max_grade) <= TransportTypes.grade_tolere("departementale") + 0.001,
		"lacets : %d m, pente maxi %.1f %%" % [roundi(lac.length), float(lac.max_grade) * 100.0])
	var court := RoutePlanner.lacets(a, Vector2(40, 0), 500.0, 560.0, "departementale")
	_check(court.is_empty(), "trop raide pour la place : pas de lacets")
	var plat := RoutePlanner.lacets(a, b, 100.0, 105.0, "departementale")
	_check(plat.size() == 2, "pente douce : ligne droite gardée")

	print("Véhicules ralentis :")
	var net := TransportNetwork.new()
	var n0 := net.add_node(lac.pts[0], TransportTypes.Mode.ROAD)
	var n1 := net.add_node(lac.pts[lac.pts.size() - 1], TransportTypes.Mode.ROAD)
	var eid := net.add_edge(n0, n1, "departementale", lac.pts, lac.st)
	var e: Dictionary = net.edges[eid]
	_check(float(e.get("lent", 1.0)) < 1.0, "tronçon à épingles ralenti (×%.2f)" % float(e.get("lent", 1.0)))
	var no := net.add_node(orange.pts[0] + Vector3(0, 0, 50), TransportTypes.Mode.ROAD)
	var nb := net.add_node(orange.pts[orange.pts.size() - 1] + Vector3(0, 0, 50), TransportTypes.Mode.ROAD)
	var po: PackedVector3Array = orange.pts.duplicate()
	for i in po.size():
		po[i].z += 50.0
	var eo: Dictionary = net.edges[net.add_edge(no, nb, "departementale", po, orange.st)]
	_check(float(eo.get("raide", 0.0)) > 0.3 and TransportTypes.facteur_vehicule(eo, true) < TransportTypes.facteur_vehicule(eo, false),
		"13 %% : voitures ×%.2f, camions ×%.2f" % [TransportTypes.facteur_vehicule(eo, false), TransportTypes.facteur_vehicule(eo, true)])
	var copie := TransportNetwork.new()
	copie.from_dict(JSON.parse_string(JSON.stringify(net.to_dict())))
	_check(copie.edges.has(eid) and float(copie.edges[eid].get("lent", 1.0)) < 1.0, "ralentissement retrouvé au rechargement")

	print("RÉSULTAT : ", "OK" if ok else "ÉCHEC")
	quit(0 if ok else 1)


## Demi-tour de rayon r (épingle) entre deux branches droites de 60 m.
static func _arc(r: float) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in 31:
		p.append(Vector2(-60.0 + i * 2.0, 0))
	for k in range(1, 40):
		var ang := -PI * 0.5 + PI * float(k) / 40.0
		p.append(Vector2(cos(ang) * r, sin(ang) * r + r))
	for i in 31:
		p.append(Vector2(-i * 2.0, 2.0 * r))
	return p
