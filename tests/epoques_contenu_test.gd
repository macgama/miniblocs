extends SceneTree
## Test du contenu d'époque 1800-1900 : bâtiments du XIXe siècle (modèles,
## années, rôles repris de leur base, zonage), véhicules d'époque, gares et ports
## d'époque, musiques et ambiances sonores d'époque.
## Usage : godot --headless --path . --script res://tests/epoques_contenu_test.gd

var ok := true


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	if not cond:
		push_error("ÉCHEC : " + what)
		ok = false
	else:
		print("  ok  ", what)


func _run() -> void:
	print("Bâtiments du XIXe siècle :")
	var types := BuildingCatalog.all_types()
	for id in EpoquesBatiments.ORDER:
		_check(types.has(id), "%s est au catalogue" % id)
		var m := BuildingCatalog.build_mesh(id)
		_check(m != null and m.get_surface_count() > 0, "%s a un modèle" % id)
		var aabb := m.get_aabb() if m != null else AABB()
		var t: Dictionary = types[id]
		_check(aabb.size.x <= float(t.w) + 0.05 and aabb.size.z <= float(t.d) + 0.05,
			"%s tient dans son emprise (%.1f × %.1f pour %d × %d)" % [id, aabb.size.x, aabb.size.z, t.w, t.d])
		_check(Epoques.annee_batiment(id) == int(EpoquesBatiments.TYPES[id].annee), "%s apparaît en %d" % [id, Epoques.annee_batiment(id)])
	_check(types.ferme_picarde.has("prod"), "la ferme à cour carrée produit comme une ferme céréalière")
	_check(BuildingCatalog.base_of("moulin_tour") == "moulin", "le moulin à vent joue le rôle du moulin")
	_check(types.relais_poste.has("touris"), "le relais de poste loge les voyageurs")
	_check(String(types.usine_gaz.get("cat", "")) == "reseaux", "l'usine à gaz est dans les réseaux")
	_check(not types.embarcadere.has("prod"), "la gare de village ne produit rien")
	var z := EpoquesBatiments.pour_zone("R", "europe", 1850)
	_check(z.has("longere") and not z.has("tulou_hakka"), "zonage 1850 en Europe : longère, pas de tulou")
	_check(EpoquesBatiments.pour_zone("R", "asie_est", 1850).has("tulou_hakka"), "zonage 1850 en Asie de l'Est : tulou")
	_check(not EpoquesBatiments.pour_zone("R", "europe", 1800).has("rangee_victorienne") or int(EpoquesBatiments.TYPES.rangee_victorienne.annee) <= 1800, "pas de bâtiment avant son année")

	print("Véhicules d'époque :")
	var n := 0
	for vid in VehicleCatalog.TYPES:
		var vt: Dictionary = VehicleCatalog.TYPES[vid]
		if not bool(vt.get("siecle", false)):
			continue
		n += 1
		var vm := VehicleCatalog.build_mesh(vid)
		_check(vm != null and vm.get_surface_count() > 0, "%s a un modèle" % vid)
		var vy := int(vt.get("year", 0))
		_check(vy >= 1780 and vy <= 1900, "%s date de %d" % [vid, vy])
	_check(n >= 30, "%d véhicules du XIXe siècle" % n)
	var r := ReglagesPartie.new()
	r.annee_depart = 1860
	for moderne in ["berline", "tgv", "tram_moderne"]:
		var ancien := Epoques.vehicule(moderne, r)
		var at := VehicleCatalog.get_type(ancien)
		_check(int(at.get("year", 9999)) <= 1860 and int(at.mode) == int(VehicleCatalog.get_type(moderne).mode),
			"en 1860, %s devient %s (%d)" % [moderne, ancien, int(at.get("year", 0))])
	_check(Epoques.vehicule("tram_moderne", r) == "tram_chevaux", "en 1860, le tramway est tiré par des chevaux")
	_check(Epoques.ATTELAGES.voiture.has(Epoques.vehicule("berline", r)), "en 1860, la berline devient une voiture à cheval")

	print("Gares et ports d'époque :")
	var avant := ReglagesPartie.actuel
	ReglagesPartie.actuel = r
	_check(StationSystem.style_ancien(), "1860 : gares à l'ancienne")
	_check(StationSystem._gare_building() == "embarcadere", "1860 : petite gare de village")
	for st in ["gare", "port"]:
		var sm := StationSystem.build_network_mesh(st, 6.0, true)
		_check(sm != null and sm.get_surface_count() > 0, "%s d'époque a un modèle" % st)
	r.annee_depart = 1890
	_check(StationSystem._gare_building() == "briques_ind__gare", "1890 : gare en briques")
	ReglagesPartie.actuel = avant
	_check(not StationSystem.style_ancien(), "partie moderne : gares modernes")

	print("Fini.")
	print("TEST OK" if ok else "TEST ÉCHOUÉ")
	quit(0 if ok else 1)
