extends SceneTree
## Vérifie le manteau neigeux commun (scripts/terre/neige.gdshaderinc) :
## plus de neige en montant, neige de saison sur les sommets (été compris),
## les trois shaders (terrain, relief lointain, plantes) compilent avec
## l'include et reçoivent les mêmes réglages.
## Usage : godot --headless --path . --script res://tests/neige_test.gd

var _erreurs := 0


func _check(ok: bool, quoi: String) -> void:
	if ok:
		print("  ok  ", quoi)
	else:
		_erreurs += 1
		push_error("ÉCHEC : " + quoi)


func _initialize() -> void:
	var w := TerrainWorld.new()
	w.origin_lat = 46.62 # Vulliens (Vaud)
	w.neige_alt_ref = 700.0

	print("Hiver (21 décembre), il a un peu neigé au village :")
	var hiver := Time.get_unix_time_from_datetime_string("2026-12-21T12:00:00")
	var t := Meteo.air_temperature(w.origin_lat, hiver, 9.0, w.neige_alt_ref)
	w.neige_iso0 = w.neige_alt_ref + t / 0.0065
	w.neige = 0.4
	_check(is_equal_approx(w.neige_a(700.0), 0.4), "au village : la neige de la météo (%.2f)" % w.neige_a(700.0))
	_check(w.neige_a(1500.0) > 0.95, "à 1 500 m : tout blanc (%.2f)" % w.neige_a(1500.0))
	_check(w.neige_a(400.0) < w.neige_a(700.0), "plus bas, moins de neige (%.2f)" % w.neige_a(400.0))
	w.neige = 0.0
	_check(w.neige_a(700.0) == 0.0, "neige fondue au village : plus rien au village")
	_check(w.neige_a(1800.0) > 0.9, "mais les sommets restent blancs l'hiver (%.2f, isotherme 0 °C à %.0f m)" % [w.neige_a(1800.0), w.neige_iso0])

	print("Été (15 juillet) :")
	var ete := Time.get_unix_time_from_datetime_string("2026-07-15T12:00:00")
	t = Meteo.air_temperature(w.origin_lat, ete, 9.0, w.neige_alt_ref)
	w.neige_iso0 = w.neige_alt_ref + t / 0.0065
	_check(w.neige_iso0 > 2500.0 and w.neige_iso0 < 4000.0, "isotherme 0 °C vers %.0f m" % w.neige_iso0)
	_check(w.neige_a(1500.0) == 0.0, "pas de neige à 1 500 m")
	_check(w.neige_a(4200.0) > 0.9, "neiges éternelles à 4 200 m (%.2f)" % w.neige_a(4200.0))

	print("Shaders :")
	for p in ["res://scripts/terre/terrain.gdshader", "res://scripts/terre/horizon.gdshader", "res://scripts/terre/plante.gdshader"]:
		var sh: Shader = load(p)
		var noms := []
		for u in sh.get_shader_uniform_list():
			noms.append(u.name)
		var ok := true
		for cle in w.neige_params():
			ok = ok and cle in noms
		_check(ok, "%s : uniformes de neige présents" % p.get_file())
	var pm := Plantes.materiau()
	w.neige = 0.7
	Plantes.applique_neige(w.neige_params())
	_check(is_equal_approx(float(pm.get_shader_parameter("neige_iso0")), w.neige_iso0), "réglages recopiés sur les plantes")
	w.free()

	print("NEIGE TEST OK" if _erreurs == 0 else "NEIGE TEST ÉCHEC (%d)" % _erreurs)
	quit(0 if _erreurs == 0 else 1)
