extends SceneTree
## Captures de la démo « ferme low-poly » (scenes/demo_ferme.tscn).
## Usage (avec affichage, rendu Forward+) :
##   godot --path . --script res://tests/ferme_vitrine.gd -- --screenshot ferme.png [--lumiere 0-3] [--vue 0-3] [--sans-aide]
## --toutes prefixe : toutes les combinaisons utiles (prefixe-<vue>-<lumiere>.png).


func _initialize() -> void:
	_run.call_deferred()


func _arg(args: PackedStringArray, nom: String, defaut: String) -> String:
	var i := args.find(nom)
	return args[i + 1] if i >= 0 and i + 1 < args.size() else defaut


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	root.size = Vector2i(1600, 900)
	# Le MSAA du rendu logiciel (llvmpipe) laisse des pixels parasites :
	# pour les captures on passe à l'anticrénelage FXAA (--msaa pour le garder).
	if not args.has("--msaa"):
		root.msaa_3d = Viewport.MSAA_DISABLED
		root.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	var t0 := Time.get_ticks_msec()
	var scene: Node = load("res://scenes/demo_ferme.tscn").instantiate()
	root.add_child(scene)
	print("Construite en ", Time.get_ticks_msec() - t0, " ms : ", scene.stats)
	# --sans ssr,ssao,glow,brume,ombres : pour comparer l'effet de chaque réglage.
	for e in _arg(args, "--sans", "").split(",", false):
		match e:
			"ssr": scene.env.ssr_enabled = false
			"ssao": scene.env.ssao_enabled = false
			"glow": scene.env.glow_enabled = false
			"brume": scene.env.volumetric_fog_enabled = false
			"ombres": scene.sun.shadow_enabled = false
			"ssil": scene.env.ssil_enabled = false
	if args.has("--sans-aide"):
		scene.hud.visible = false
	var plan: Array = []
	if args.has("--toutes"):
		var pre := _arg(args, "--toutes", "ferme")
		plan = [[0, 0], [1, 0], [2, 0], [3, 0], [0, 1], [0, 3], [1, 2], [3, 1]]
		for p in plan:
			p.append("%s-%d-%d.png" % [pre, p[0], p[1]])
	elif args.has("--liste"):
		# --liste "vue:lumiere,vue:lumiere" --prefixe chemin
		for item in _arg(args, "--liste", "").split(","):
			var vl := item.split(":")
			plan.append([int(vl[0]), int(vl[1]), "%s-%s-%s.png" % [_arg(args, "--prefixe", "ferme"), vl[0], vl[1]]])
	else:
		plan = [[int(_arg(args, "--vue", "0")), int(_arg(args, "--lumiere", "0")), _arg(args, "--screenshot", "ferme.png")]]
	for p in plan:
		scene.appliquer_vue(p[0])
		scene.appliquer_lumiere(p[1])
		for i in 12:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png(p[2])
		print("Capture : ", p[2])
	quit(0)
