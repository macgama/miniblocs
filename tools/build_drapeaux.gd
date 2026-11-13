extends SceneTree
## Atlas des drapeaux (assets/drapeaux.png + assets/drapeaux.json) à partir des
## SVG 4:3 du paquet npm « flag-icons » (MIT), pour les pays de assets/pays.json.
## Usage : godot --headless --path . --script res://tools/build_drapeaux.gd -- /chemin/flag-icons/flags/4x3

const W := 96
const H := 72
const COLS := 16


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var dir: String = args[0] if not args.is_empty() else "."
	var pays: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/pays.json"))
	var codes := pays.keys()
	codes.sort()
	var rows := ceili(float(codes.size()) / COLS)
	var atlas := Image.create(COLS * W, rows * H, false, Image.FORMAT_RGBA8)
	var index := {}
	var n := 0
	for c in codes:
		var svg := FileAccess.get_file_as_string(dir.path_join(String(c) + ".svg"))
		var img := Image.new()
		if svg == "" or img.load_svg_from_string(svg, 1.0) != OK:
			push_warning("drapeau illisible : %s" % c)
			continue
		# 640 × 480 dans les SVG : on les rend à la bonne taille.
		img.load_svg_from_string(svg, float(W) / img.get_width())
		img.convert(Image.FORMAT_RGBA8)
		img.resize(W, H, Image.INTERPOLATE_LANCZOS)
		atlas.blit_rect(img, Rect2i(0, 0, W, H), Vector2i((n % COLS) * W, (n / COLS) * H))
		index[c] = n
		n += 1
	atlas.save_png("res://assets/drapeaux.png")
	var f := FileAccess.open("res://assets/drapeaux.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"w": W, "h": H, "cols": COLS, "index": index}))
	print("%d drapeaux" % n)
	quit()
