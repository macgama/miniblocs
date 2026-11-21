extends SceneTree
## Climat sec : la sécheresse de la région (TerrainWorld.aridite) passe au
## matériau des bâtiments (pas de mousse, poussière ocre).
## Usage : godot --headless --path . --script res://tests/aridite_test.gd

var _ok := true


func _check(c: bool, msg: String) -> void:
	if not c:
		_ok = false
		push_error("ÉCHEC : " + msg)
	else:
		print("ok : " + msg)


func _initialize() -> void:
	_check(TerrainWorld.aridite_de(0.05) == 0.0, "région verte : pas sèche")
	_check(TerrainWorld.aridite_de(0.9) == 1.0, "désert : sec")
	var mi := TerrainWorld.aridite_de(0.45)
	_check(mi > 0.2 and mi < 0.8, "steppe : à moitié sèche (%.2f)" % mi)
	var usee := NightWindows.variant_material(3, 0)
	NightWindows.set_aride(1.0)
	_check(float(NightWindows.building_material().get_shader_parameter("aride")) == 1.0, "matériau de base sec")
	_check(float(usee.get_shader_parameter("aride")) == 1.0, "variante d'usure déjà créée : sèche aussi")
	_check(float(NightWindows.variant_material(4, 1).get_shader_parameter("aride")) == 1.0, "nouvelle variante : sèche")
	NightWindows.set_aride(0.0)
	_check(float(usee.get_shader_parameter("aride")) == 0.0, "retour au climat humide")
	print("RÉSULTAT : " + ("OK" if _ok else "ÉCHEC"))
	quit(0 if _ok else 1)
