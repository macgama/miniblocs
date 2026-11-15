extends SceneTree
## Version et date de build affichées sur l'écran titre (VersionBuild).
## Usage : godot --headless --path . --script res://tests/version_build_test.gd

var ok := true


func _check(cond: bool, what: String) -> void:
	if not cond:
		push_error("ÉCHEC : " + what)
		ok = false
	else:
		print("  ok  ", what)


func _initialize() -> void:
	var tmp := "user://build_info_test.json"
	# Sans fichier : mode développement.
	var t := VersionBuild.texte("user://absent.json")
	_check(t.contains("dev") and t.contains("Godot"), "sans build_info : « dev » (%s)" % t)
	# Avec un fichier comme celui que l'export écrit.
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": "0.1.450", "commit": "a9cae94", "date": "15.11.2026 à 12:40"}))
	f.close()
	t = VersionBuild.texte(tmp)
	_check(t.begins_with("Version 0.1.450 (a9cae94) · build du 15.11.2026 à 12:40 · Godot "), "avec build_info : %s" % t)
	# Fichier abîmé : pas de plantage.
	f = FileAccess.open(tmp, FileAccess.WRITE)
	f.store_string("pas du json")
	f.close()
	_check(VersionBuild.infos(tmp).is_empty(), "fichier abîmé ignoré")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
	# Le preset d'export embarque bien build_info.json.
	var cfg := ConfigFile.new()
	_check(cfg.load("res://export_presets.cfg") == OK, "export_presets.cfg présent")
	_check(String(cfg.get_value("preset.0", "include_filter", "")).contains("build_info.json"), "preset : build_info.json inclus")
	print("RÉSULTAT : ", "OK" if ok else "ÉCHEC")
	quit(0 if ok else 1)
