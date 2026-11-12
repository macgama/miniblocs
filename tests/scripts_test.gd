extends SceneTree
## Charge tous les scripts du projet : aucune erreur d'analyse (types non
## déduits, fonctions inconnues…), même pour les scripts qu'aucun autre test
## n'exécute.


func _initialize() -> void:
	var paths: Array[String] = []
	_collect("res://scripts", paths)
	_collect("res://tests", paths)
	var bad: Array[String] = []
	for p in paths:
		var s := load(p) as GDScript
		if s == null or not s.can_instantiate():
			bad.append(p)
	for p in bad:
		push_error("ÉCHEC : script invalide " + p)
	print("%d scripts chargés, %d en erreur" % [paths.size(), bad.size()])
	print("SCRIPTS TEST OK" if bad.is_empty() and paths.size() > 20 else "SCRIPTS TEST ÉCHEC")
	quit(0 if bad.is_empty() and paths.size() > 20 else 1)


func _collect(dir: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		_collect(dir.path_join(sub), out)
