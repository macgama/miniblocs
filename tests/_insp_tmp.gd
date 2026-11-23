extends SceneTree
func _initialize():
	for id in ["boulangerie","japonais__boutique","asie_dense__restaurant","haussmann__boutique","bistrot_parisien","latino__boutique","colonial__boutique","pizzeria","cafe","maghreb__boutique","fleuriste"]:
		var t := BuildingCatalog.get_type(id)
		if t.is_empty(): print(id, " ??"); continue
		var m := BuildingCatalog.build_mesh(id)
		var bb := BatimentsVie.body_bounds(m)
		print(id, " style=", t.get("style",""), " w,d=", t.w, ",", t.d, " surf=", m.get_surface_count(), " bb=", bb, " aabb=", m.get_aabb(), " keys=", Metiers.keys_of(id))
	quit()
