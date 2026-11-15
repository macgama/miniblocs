class_name VersionBuild
extends RefCounted
## Version affichée sur l'écran titre. Le script tools/export/exporter_windows.ps1
## écrit res://build_info.json juste avant l'export (version, commit, date et heure
## du build). Lancé depuis l'éditeur, ce fichier n'existe pas : on affiche « dev ».

const CHEMIN := "res://build_info.json"


## Infos du build : {version, commit, date} ; vide si le jeu tourne depuis l'éditeur.
static func infos(chemin := CHEMIN) -> Dictionary:
	if not FileAccess.file_exists(chemin):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(chemin)) != OK:
		return {}
	return json.data if json.data is Dictionary else {}


## Texte de l'écran titre, par ex. « Version 0.1.450 (a9cae94) · build du 15.11.2026 à 12:40 · Godot 4.7.2 ».
static func texte(chemin := CHEMIN) -> String:
	var godot := "Godot %s" % Engine.get_version_info().string
	var d := infos(chemin)
	if d.is_empty():
		var ver := String(ProjectSettings.get_setting("application/config/version", ""))
		return "Version %s (dev, lancé depuis Godot) · %s" % [ver if ver != "" else "?", godot]
	var t := "Version %s" % String(d.get("version", "?"))
	if String(d.get("commit", "")) != "":
		t += " (%s)" % String(d.commit)
	if String(d.get("date", "")) != "":
		t += " · build du %s" % String(d.date)
	return t + " · " + godot
