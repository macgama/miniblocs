extends "res://tests/demo_vitrine.gd"
## Vitrine du rendu « cosy » : le village de la démo (tests/demo_vitrine.gd) à
## cinq moments de la journée, pour comparer avant / après.
## Usage (avec affichage, rendu Forward+) :
##   godot --path . --resolution 1600x900 --script res://tests/cosy_vitrine.gd -- --plat --dossier /chemin [--avant]
## --avant : coupe le rendu cosy (RenduCosy.actif = false) pour l'image « avant ».


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	RenduCosy.actif = not args.has("--avant")
	RenduCosy.maquette = args.has("--maquette")
	RenduCosy.qualite = 1 if args.has("--haute") else 0
	super._initialize()


## Variantes de réglages essayées l'une après l'autre (--variantes).
const VARIANTES := [
	["agx", {"tonemap": Environment.TONE_MAPPER_AGX, "saturation": 1.32, "contraste": 1.08, "exposition": 1.15}],
	["aces", {"tonemap": Environment.TONE_MAPPER_ACES, "saturation": 1.12, "contraste": 1.04, "exposition": 1.0}],
	["filmic", {"tonemap": Environment.TONE_MAPPER_FILMIC, "saturation": 1.22, "contraste": 1.06, "exposition": 1.15}],
]


func _captures() -> void:
	_ui(false)
	if OS.get_cmdline_user_args().has("--variantes"):
		for va in VARIANTES:
			var r: Dictionary = va[1]
			RenduCosy.tonemap = r.tonemap
			RenduCosy.saturation = r.saturation
			RenduCosy.contraste = r.contraste
			RenduCosy.exposition = r.exposition
			RenduCosy.init_env(amb.env, amb.sun)
			RenduCosy.init_terrain(world)
			for v in [["apres-midi", 15.5, Vector3(10, 0, -10), 230.0, 32.0, 120.0],
					["pres", 16.5, Vector3(60, 0, 100), 200.0, 30.0, 55.0],
					["soir", 20.9, Vector3(0, 0, 10), 170.0, 30.0, 160.0]]:
				amb.set_local_hour(float(v[1]))
				_vue(centre + (v[2] as Vector3), float(v[3]), float(v[4]), float(v[5]))
				await _shot("%s-%s" % [va[0], v[0]], 40)
		return
	var vues := [
		["1-matin", 10.0, Vector3(-10, 0, 10), 205.0, 36.0, 280.0],
		["2-centre-apres-midi", 15.5, Vector3(10, 0, -10), 230.0, 32.0, 120.0],
		["3-heure-doree", 19.6, Vector3(10, 0, -10), 230.0, 32.0, 120.0],
		["4-crepuscule", 21.4, Vector3(0, 0, 10), 170.0, 30.0, 160.0],
		["5-nuit", 23.0, Vector3(0, 0, 10), 170.0, 30.0, 160.0],
		["6-maisons-de-pres", 16.5, Vector3(60, 0, 100), 200.0, 30.0, 55.0],
	]
	for v in vues:
		amb.set_local_hour(float(v[1]))
		_vue(centre + (v[2] as Vector3), float(v[3]), float(v[4]), float(v[5]))
		await _shot(String(v[0]), 60)
