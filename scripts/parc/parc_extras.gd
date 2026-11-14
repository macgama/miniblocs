class_name ParcExtras
extends RefCounted
## Objets du parc ajoutés avec l'éditeur (menu Parc, Maj+A) : bassins et
## attractions aquatiques fixes, nouvelles boutiques et services. Même format
## que ParcTypes.TYPES (champ "parc" pour ParcLoisirs) ; ParcTypes les
## fusionne dans le catalogue, les dessine (build) et les anime (build_anim, animate).

const ROUGE := Color("d62828")
const JAUNE := Color("ffc93c")
const BLEU := Color("277da1")
const VERT := Color("43aa8b")
const ROSE := Color("f78fb3")
const VIOLET := Color("7b2cbf")
const ORANGE := Color("f77f00")
const BLANC := Color("f8f4ea")
const BOIS := Color("9c6644")
const METAL := Color("adb5bd")
const METAL_F := Color("6c757d")
const VITRE := Color("33495e")
const PAVE := Color("d8cbb3")
const EAU := Color("3f9ed8")
const EAU_C := Color("7fd3f5")
const CARRELAGE := Color("e3f2fd")

const TYPES := {
	# --- Bassins et attractions aquatiques ---------------------------------------------------
	"piscine_vagues": {"name": "Piscine à vagues", "w": 40, "d": 28, "access": [], "emplois": 4, "cost": 2_800_000, "groupe": "eau",
		"parc": {"role": "attraction", "cap": 120, "cycle": 15.0, "exc": 4.0, "int": 2.0, "attrait": 4.5, "usure": 0.04, "anim": "vagues"},
		"metiers": [["operateur_attraction", 1], ["maitre_nageur", 3]],
		"desc": "Une plage en pente douce et une vague toutes les dix secondes. Les maîtres-nageurs sifflent, c'est leur métier."},
	"pataugeoire": {"name": "Pataugeoire et jets d'eau", "w": 20, "d": 20, "access": [], "emplois": 1, "cost": 450_000, "groupe": "eau",
		"parc": {"role": "attraction", "cap": 40, "cycle": 10.0, "exc": 2.0, "int": 0.5, "attrait": 2.0, "usure": 0.03, "anim": "jets"},
		"metiers": [["maitre_nageur", 1]],
		"desc": "Trente centimètres d'eau, des champignons qui arrosent et un seau géant qui bascule. Les parents restent au sec (en théorie)."},
	"bateaux_tamponneurs": {"name": "Bateaux tamponneurs", "w": 26, "d": 20, "access": [], "emplois": 2, "cost": 700_000, "groupe": "eau",
		"parc": {"role": "attraction", "cap": 16, "cycle": 4.0, "exc": 4.0, "int": 2.5, "attrait": 3.0, "usure": 0.08, "anim": "bateaux"},
		"metiers": [["operateur_attraction", 2]],
		"desc": "Bouées à moteur et pistolets à eau. Le pilote le plus mouillé est rarement celui qu'on croit."},
	"pedalos": {"name": "Pédalos du lac", "w": 34, "d": 26, "access": [], "emplois": 1, "cost": 380_000, "groupe": "eau",
		"parc": {"role": "attraction", "cap": 24, "cycle": 10.0, "exc": 2.0, "int": 0.5, "attrait": 2.5, "usure": 0.04, "anim": "pedalos"},
		"metiers": [["operateur_attraction", 1]],
		"desc": "Douze pédalos en forme de cygne sur un petit lac. On pédale, on rit, on a mal aux mollets."},
	# --- Boutiques et services ------------------------------------------------------------------
	"pizzeria_parc": {"name": "Pizzeria", "w": 10, "d": 8, "access": [], "emplois": 3, "cost": 180_000, "groupe": "boutique",
		"parc": {"role": "stand", "vend": "manger", "prix": 9.5, "service": 55.0, "anim": "enseigne"},
		"metiers": [["vendeur_parc", 3]], "desc": "Pizzas à la part, four à bois et terrasse. Le parfum attire jusqu'aux files d'attente."},
	"creperie_parc": {"name": "Crêperie", "w": 7, "d": 6, "access": [], "emplois": 2, "cost": 90_000, "groupe": "boutique",
		"parc": {"role": "stand", "vend": "manger", "prix": 5.0, "service": 65.0, "anim": "enseigne"},
		"metiers": [["vendeur_parc", 2]], "desc": "Crêpes au sucre, à la confiture, au chocolat. La galette complète pour les grands appétits."},
	"barbe_a_papa": {"name": "Barbe à papa et churros", "w": 5, "d": 5, "access": [], "emplois": 1, "cost": 60_000, "groupe": "boutique",
		"parc": {"role": "stand", "vend": "manger", "prix": 4.0, "service": 80.0, "anim": "enseigne"},
		"metiers": [["vendeur_parc", 1]], "desc": "Sucre filé rose et churros dorés. Les enfants en mettent partout, les poubelles aussi."},
	"bar_smoothies": {"name": "Bar à smoothies", "w": 7, "d": 6, "access": [], "emplois": 2, "cost": 95_000, "groupe": "boutique",
		"parc": {"role": "stand", "vend": "boire", "prix": 4.5, "service": 70.0, "anim": "enseigne"},
		"metiers": [["vendeur_parc", 2]], "desc": "Fruits mixés, citronnade et thé glacé. Indispensable sous le soleil d'août."},
	"distributeur_boissons": {"name": "Distributeurs de boissons", "w": 3, "d": 2, "access": [], "emplois": 0, "cost": 15_000, "groupe": "boutique",
		"parc": {"role": "stand", "vend": "boire", "prix": 2.5, "service": 40.0},
		"desc": "Trois distributeurs, aucun vendeur. Ils rendent la monnaie quand ils veulent."},
	"stand_ballons": {"name": "Stand de ballons", "w": 4, "d": 4, "access": [], "emplois": 1, "cost": 30_000, "groupe": "boutique",
		"parc": {"role": "stand", "vend": "souvenir", "prix": 6.0, "service": 50.0, "anim": "enseigne"},
		"metiers": [["vendeur_parc", 1]], "desc": "Ballons gonflés à l'hélium. Un sur dix finit dans le ciel, avant même la sortie."},
	"comptoir_photo": {"name": "Comptoir photo", "w": 6, "d": 5, "access": [], "emplois": 1, "cost": 70_000, "groupe": "boutique",
		"parc": {"role": "stand", "vend": "souvenir", "prix": 12.0, "service": 35.0},
		"metiers": [["vendeur_parc", 1]], "desc": "La photo de la grande descente, imprimée en deux minutes. Bouche ouverte garantie."},
	"poste_secours": {"name": "Poste de secours", "w": 8, "d": 6, "access": [], "emplois": 2, "cost": 120_000, "groupe": "service",
		"parc": {"role": "repos", "places": 12},
		"metiers": [["infirmier", 2]], "desc": "Infirmiers, pansements et chaises à l'ombre. Les visiteurs barbouillés s'y remettent."},
	"kiosque_info": {"name": "Point d'information", "w": 5, "d": 5, "access": [], "emplois": 1, "cost": 50_000, "groupe": "service",
		"parc": {"role": "repos", "places": 8},
		"metiers": [["agent_accueil_parc", 1]], "desc": "Plans du parc, objets trouvés et enfants égarés (rendus à leurs parents)."},
}
const ORDER := ["piscine_vagues", "pataugeoire", "bateaux_tamponneurs", "pedalos", "pizzeria_parc", "creperie_parc", "barbe_a_papa",
	"bar_smoothies", "distributeur_boissons", "stand_ballons", "comptoir_photo", "poste_secours", "kiosque_info"]
const ANIMS := ["vagues", "jets", "bateaux", "pedalos"]


static func build(k: BlocMesh, id: String, t: Dictionary) -> void:
	var w := float(t.w)
	var d := float(t.d)
	match id:
		"piscine_vagues":
			k.plate(0, 0, w, d, CARRELAGE)
			k.box(0, 0, 0, w - 2.0, 0.5, d - 2.0, BLANC)
			k.plate(0, 0, w - 3.0, d - 3.0, EAU, 0.5, 0.05)
			# Machine à vagues au fond, plage de sable devant.
			k.box(0, 0, d / 2.0 - 2.0, w - 2.0, 3.5, 2.0, METAL_F)
			k.box(0, 3.5, d / 2.0 - 2.0, w - 1.0, 0.4, 2.4, BLEU)
			k.plate(0, -d / 2.0 + 2.5, w - 2.0, 4.0, Color("f2e2ba"), 0.5, 0.08)
			for i in 6:
				var x := -w / 2.0 + 4.0 + i * (w - 8.0) / 5.0
				k.cylinder(x, 0.5, -d / 2.0 + 1.5, 0.05, 0.05, 2.4, 4, METAL)
				ParcTypes.chapiteau(k, x, 2.9, -d / 2.0 + 1.5, 1.4, 0.6, 8, [ROUGE, JAUNE, BLEU][i % 3], BLANC)
			# Chaise de maître-nageur.
			k.box(w / 2.0 - 3.0, 0.5, -d / 2.0 + 4.0, 0.9, 2.4, 0.9, BLANC)
			k.box(w / 2.0 - 3.0, 2.9, -d / 2.0 + 4.0, 1.0, 0.2, 1.0, ROUGE)
		"pataugeoire":
			k.plate(0, 0, w, d, CARRELAGE)
			k.cylinder(0, 0, 0, 8.5, 8.5, 0.35, 20, BLANC)
			k.cylinder(0, 0.32, 0, 8.0, 8.0, 0.04, 20, EAU_C)
			for i in 5:
				var a := TAU * i / 5.0
				k.cylinder(cos(a) * 4.5, 0.3, sin(a) * 4.5, 0.15, 0.15, 1.6, 6, VERT)
				k.dome(cos(a) * 4.5, 1.9, sin(a) * 4.5, 1.1, 0.6, [ROUGE, JAUNE, ROSE, BLEU, ORANGE][i], 10)
			# Seau géant sur son portique.
			for s: float in [-1.0, 1.0]:
				k.box(1.6 * s, 0.3, 0, 0.25, 6.0, 0.25, JAUNE)
			k.box(0, 6.1, 0, 3.6, 0.3, 0.3, JAUNE)
			k.cylinder(0, 4.6, 0, 0.9, 1.1, 1.4, 10, ROUGE)
		"bateaux_tamponneurs":
			k.plate(0, 0, w, d, PAVE)
			k.box(0, 0, 0, w - 2.0, 0.7, d - 2.0, BLANC)
			k.plate(0, 0, w - 3.0, d - 3.0, EAU, 0.6, 0.05)
			k.box(0, 0, -d / 2.0 + 1.4, 6.0, 1.0, 2.0, BOIS)
			for x: float in [-w / 2.0 + 1.0, w / 2.0 - 1.0]:
				k.box(x, 0, 0, 0.3, 4.0, 0.3, METAL_F)
			k.box(0, 4.0, d / 2.0 - 1.0, w - 2.0, 0.8, 0.3, ROUGE)
		"pedalos":
			k.plate(0, 0, w, d, Color("8ab17d"))
			k.cylinder(0, 0, 0, minf(w, d) / 2.0 - 1.0, minf(w, d) / 2.0 - 1.0, 0.1, 24, Color("c2b280"))
			k.cylinder(0, 0.05, 0, minf(w, d) / 2.0 - 2.0, minf(w, d) / 2.0 - 2.0, 0.08, 24, EAU)
			k.box(0, 0, -d / 2.0 + 3.0, 4.0, 0.4, 6.0, BOIS)
			k.box(0, 0, -d / 2.0 + 1.2, 3.0, 2.6, 2.0, BLANC)
			k.gable(0, 2.6, -d / 2.0 + 1.2, 3.4, 2.4, 1.0, BLEU)
			k.tree(w / 2.0 - 2.5, d / 2.0 - 2.5, 1.2, Color("52b788"))
			k.tree(-w / 2.0 + 2.5, d / 2.0 - 2.5, 1.0, Color("52b788"))
		"pizzeria_parc":
			k.plate(0, 0, w, d, PAVE)
			k.box(0, 0, 1.0, 8.0, 3.2, 5.0, Color("fff1e6"))
			k.gable(0, 3.2, 1.0, 8.6, 5.6, 1.4, ROUGE)
			k.cylinder(2.8, 3.2, 2.0, 0.4, 0.3, 1.6, 6, Color("8c4a3a"))
			k.box(0, 1.0, -1.52, 6.0, 1.2, 0.05, VITRE)
			ParcTypes._store(k, -1.6, 7.6, ROUGE, VERT)
			for x: float in [-3.0, 0.0, 3.0]:
				k.cylinder(x, 0, -3.2, 0.5, 0.5, 0.75, 8, BLANC)
		"creperie_parc":
			k.plate(0, 0, w, d, PAVE)
			k.box(0, 0, 0.6, 5.6, 2.8, 3.6, Color("fdf0d5"))
			k.box(0, 1.0, -1.22, 4.0, 1.0, 0.05, VITRE)
			ParcTypes._store(k, -1.25, 5.6, BLEU, BLANC)
		"barbe_a_papa":
			k.plate(0, 0, w, d, PAVE)
			k.box(0, 0, 0.3, 3.0, 1.1, 2.0, ROSE)
			k.cylinder(0, 1.1, 0.3, 0.05, 0.05, 1.4, 4, METAL)
			ParcTypes.chapiteau(k, 0, 2.5, 0.3, 1.9, 0.9, 8, ROSE, BLANC)
			k.dome(-0.7, 1.1, 0.3, 0.35, 0.4, Color("ffc8dd"), 8)
		"bar_smoothies":
			k.plate(0, 0, w, d, PAVE)
			k.box(0, 0, 0.6, 5.4, 2.8, 3.4, Color("d8f3dc"))
			k.box(0, 1.0, -1.12, 4.0, 1.0, 0.05, VITRE)
			ParcTypes._store(k, -1.15, 5.4, ORANGE, JAUNE)
			for i in 3:
				k.dome(-1.6 + i * 1.6, 2.9, 0.6, 0.45, 0.5, [ORANGE, VERT, ROSE][i], 8)
		"distributeur_boissons":
			k.plate(0, 0, w, d, PAVE)
			for i in 3:
				k.box(-0.9 + i * 0.9, 0, 0.1, 0.8, 1.9, 0.7, [ROUGE, BLEU, VERT][i])
				k.box(-0.9 + i * 0.9, 0.9, -0.26, 0.5, 0.7, 0.03, VITRE)
		"stand_ballons":
			k.plate(0, 0, w, d, PAVE)
			k.box(0, 0, 0, 1.6, 1.0, 1.0, BLANC)
			for i in 11:
				var a := float(i) * 1.7
				var x := cos(a) * 0.7
				var z := sin(a) * 0.5
				ParcTypes.beam(k, Vector3(0, 1.0, 0), Vector3(x, 2.6 + float(i % 3) * 0.4, z), 0.02, METAL)
				k.box(x, 2.6 + float(i % 3) * 0.4, z, 0.5, 0.6, 0.5, ParcTypes.VIFS[i % ParcTypes.VIFS.size()])
		"comptoir_photo":
			k.plate(0, 0, w, d, PAVE)
			k.box(0, 0, 0.5, 5.0, 2.8, 3.0, Color("e9ecef"))
			k.box(0, 1.2, -1.02, 4.2, 1.2, 0.05, VITRE)
			k.box(0, 2.8, 0.5, 5.4, 0.3, 3.4, VIOLET)
			k.box(0, 3.1, -0.9, 1.0, 0.7, 0.5, Color("2b2d42"))
		"poste_secours":
			k.plate(0, 0, w, d, PAVE)
			k.box(0, 0, 0.4, 6.4, 3.0, 4.4, BLANC)
			k.box(0, 3.0, 0.4, 6.8, 0.3, 4.8, Color("2a9d8f"))
			k.box(0, 1.6, -1.82, 1.2, 0.35, 0.04, ROUGE)
			k.box(0, 1.6, -1.83, 0.35, 1.2, 0.04, ROUGE)
			k.box(-2.0, 0, -1.82, 1.0, 2.1, 0.05, VITRE)
		"kiosque_info":
			k.plate(0, 0, w, d, PAVE)
			k.cylinder(0, 0, 0, 1.6, 1.6, 2.6, 10, Color("caf0f8"))
			ParcTypes.chapiteau(k, 0, 2.6, 0, 2.3, 1.2, 10, BLEU, BLANC)
			k.box(0, 1.4, -1.62, 0.8, 0.8, 0.04, Color("ffffff"))
			k.box(0, 1.5, -1.64, 0.15, 0.5, 0.02, BLEU)
		_:
			k.plate(0, 0, w, d, PAVE)
			k.box(0, 0, 0, w * 0.5, 3, d * 0.5, BLANC)


## Parties mobiles (null si rien ne bouge).
static func build_anim(id: String, spec: Dictionary) -> Node3D:
	var anim := String(spec.get("anim", ""))
	if not anim in ANIMS:
		return null
	var t: Dictionary = TYPES.get(BuildingCatalog.base_of(id), {})
	var w := float(t.get("w", 20))
	var d := float(t.get("d", 20))
	var root := Node3D.new()
	root.name = "Anim"
	match anim:
		"vagues":
			var k := BlocMesh.new()
			for i in 5:
				k.box(0, 0, -d / 2.0 + 6.0 + i * 3.6, w - 3.4, 0.25, 1.2, EAU_C)
			root.add_child(_mi(k, "vagues"))
		"jets":
			for i in 5:
				var k := BlocMesh.new()
				k.cylinder(0, 0, 0, 0.12, 0.35, 1.0, 6, Color(0.8, 0.93, 1.0))
				var a := TAU * i / 5.0
				var mi := _mi(k, "jet_%d" % i)
				mi.position = Vector3(cos(a) * 4.5, 2.4, sin(a) * 4.5)
				root.add_child(mi)
		"bateaux":
			for i in 8:
				var k := BlocMesh.new()
				k.cylinder(0, 0, 0, 1.2, 1.2, 0.6, 10, ParcTypes.VIFS[i % ParcTypes.VIFS.size()])
				k.cylinder(0, 0.6, 0, 1.25, 1.1, 0.15, 10, Color("2b2d42"))
				k.box(0, 0.6, 0.2, 0.42, 0.55, 0.32, ParcTypes.VIFS[(i + 3) % ParcTypes.VIFS.size()])
				k.box(0, 1.15, 0.2, 0.26, 0.28, 0.26, VoieMesh.PEAUX[i % 5])
				root.add_child(_mi(k, "bateau_%d" % i))
		"pedalos":
			for i in 12:
				var k := BlocMesh.new()
				k.box(0, 0, 0, 1.4, 0.5, 2.2, BLANC)
				k.box(0, 0.5, -0.9, 0.3, 1.2, 0.3, BLANC)
				k.box(0, 1.6, -1.05, 0.25, 0.25, 0.5, ORANGE)
				k.box(0, 0.5, 0.3, 0.42, 0.55, 0.32, ParcTypes.VIFS[i % ParcTypes.VIFS.size()])
				k.box(0, 1.05, 0.3, 0.26, 0.28, 0.26, VoieMesh.PEAUX[i % 5])
				root.add_child(_mi(k, "pedalo_%d" % i))
	return root


static func _mi(k: BlocMesh, nom: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nom
	mi.mesh = k.to_mesh(ParcTypes.material())
	mi.visibility_range_end = 900.0
	return mi


static func animate(root: Node3D, id: String, t: float, dt: float, marche: float, phase: float) -> void:
	var spec: Dictionary = TYPES.get(BuildingCatalog.base_of(id), {}).get("parc", {})
	var tt := t + phase
	var td: Dictionary = TYPES.get(BuildingCatalog.base_of(id), {})
	var w := float(td.get("w", 20))
	var d := float(td.get("d", 20))
	match String(spec.get("anim", "")):
		"vagues":
			var v: Node3D = root.get_node("vagues")
			v.position = Vector3(0, 0.45 + 0.25 * sin(tt * 0.9) * marche, fposmod(tt * 1.8, 3.6) * marche)
		"jets":
			for i in 5:
				var j: Node3D = root.get_node("jet_%d" % i)
				var f := 0.2 + (0.8 + 0.4 * sin(tt * 2.0 + i)) * marche
				j.scale = Vector3(1, maxf(f, 0.05), 1)
				j.visible = marche > 0.05
		"bateaux":
			for i in 8:
				var b: Node3D = root.get_node("bateau_%d" % i)
				var u := float(root.get_meta("u%d" % i, float(i) * 1.3)) + dt * (0.35 + 0.05 * (i % 4)) * marche
				root.set_meta("u%d" % i, u)
				var x := (w / 2.0 - 4.0) * sin(u + i) * cos(u * 0.41 + i * 0.7)
				var z := (d / 2.0 - 4.0) * sin(u * 1.27 + i * 2.3)
				b.position = Vector3(x, 0.55 + 0.05 * sin(tt * 3.0 + i), z)
				b.rotation.y = u * 1.6 + i
		"pedalos":
			var r := minf(w, d) / 2.0 - 5.0
			for i in 12:
				var p: Node3D = root.get_node("pedalo_%d" % i)
				var u := float(root.get_meta("u%d" % i, TAU * i / 12.0)) + dt * 0.03 * marche
				root.set_meta("u%d" % i, u)
				var rr := r * (0.55 + 0.4 * sin(i * 1.9))
				p.position = Vector3(cos(u) * rr, 0.15 + 0.04 * sin(tt * 2.0 + i), sin(u) * rr)
				p.rotation.y = -u
