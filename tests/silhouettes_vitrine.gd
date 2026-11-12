extends SceneTree
## Captures de la vitrine des personnages (scenes/vitrine_personnages.tscn).
## Usage (avec affichage, rendu Forward+) :
##   godot --path . --script res://tests/silhouettes_vitrine.gd -- --prefixe captures/personnages [--graine 1]
## Écrit <prefixe>-foule.png, -ages.png, -gros-plan.png, -assis.png.


func _initialize() -> void:
	_run.call_deferred()


func _arg(args: PackedStringArray, nom: String, defaut: String) -> String:
	var i := args.find(nom)
	return args[i + 1] if i >= 0 and i + 1 < args.size() else defaut


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	root.size = Vector2i(1600, 900)
	root.msaa_3d = Viewport.MSAA_DISABLED
	root.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	var scene: Node = load("res://scenes/vitrine_personnages.tscn").instantiate()
	scene.graine = int(_arg(args, "--graine", "1"))
	root.add_child(scene)
	var pre := _arg(args, "--prefixe", "personnages")
	for v in [[0, "foule"], [1, "ages"], [2, "gros-plan"], [3, "assis"]]:
		scene.vue = v[0]
		scene._azimut = 0.6 if v[0] != 1 else 0.0
		scene._place_cam()
		for i in 8:
			await process_frame
		var img := root.get_texture().get_image()
		img.save_png("%s-%s.png" % [pre, v[1]])
		print("capture ", pre, "-", v[1])
	quit()
