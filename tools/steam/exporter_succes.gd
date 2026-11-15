extends SceneTree
## Exporte les succès pour Steamworks : docs/steam/succes-steam.csv (nom de l'API,
## noms et descriptions FR / EN, caché) et les icônes 256 × 256 (débloquée et grisée)
## dans docs/steam/succes-icones/. Usage :
##   godot --headless --path . --script res://tools/steam/exporter_succes.gd

const DOSSIER := "res://docs/steam/"


func _initialize() -> void:
	var en: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/langues/en.json")).textes
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DOSSIER + "succes-icones"))
	var f := FileAccess.open(DOSSIER + "succes-steam.csv", FileAccess.WRITE)
	f.store_csv_line(PackedStringArray(["api", "nom_fr", "description_fr", "nom_en", "description_en", "cache", "icone", "icone_grise"]))
	var n := 0
	for s in Succes.catalogue():
		var api := Succes.api_steam(String(s.id))
		var ic := String(s.get("icone", "trophee"))
		var png := "succes-icones/%s.png" % api.to_lower()
		var gris := "succes-icones/%s_gris.png" % api.to_lower()
		SuccesPanel.badge_image(ic, true, 256).save_png(DOSSIER + png)
		SuccesPanel.badge_image(ic, false, 256).save_png(DOSSIER + gris)
		f.store_csv_line(PackedStringArray([api, String(s.nom), String(s.desc), String(en.get(s.nom, s.nom)),
			String(en.get(s.desc, s.desc)), "1" if bool(s.get("cache", false)) else "0", png, gris]))
		n += 1
	f.close()
	print("%d succès exportés dans %s" % [n, DOSSIER])
	quit(0)
