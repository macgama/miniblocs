class_name Accessoires
extends RefCounted
## Outils tenus en main et postes de travail des métiers visibles, en low-poly.
##
## - Outil : dans le repère de la main droite (l'avant-bras descend vers −Y,
##   la main est en 0).
## - Poste : dans le repère de l'employé, qui se tient en 0 et regarde vers
##   +Z ; le meuble est devant lui. Les postes assis ont leur chaise en 0
##   (assise à ASSISE m).

const ASSISE := 0.45

static var _outils: Dictionary = {}
static var _postes: Dictionary = {}

const BOIS := Color("a0703c")
const BOIS_CLAIR := Color("c89f6a")
const METAL := Color("9aa3ad")
const SOMBRE := Color("3a3d42")
const BLANC := Color("eeeeea")


static func _kit() -> LpKit:
	var k := LpKit.new(7)
	k.jitter = 0.025
	return k


static func outil(nom: String) -> ArrayMesh:
	if _outils.has(nom):
		return _outils[nom]
	var k := _kit()
	match nom:
		"pelle_four":
			k.beam(Vector3(0, 0, -0.1), Vector3(0, 0, 1.3), 0.04, 0.04, BOIS_CLAIR)
			k.box(Vector3(0, 0, 1.45), Vector3(0.32, 0.02, 0.36), BOIS_CLAIR)
		"louche":
			k.beam(Vector3(0, 0.05, 0), Vector3(0, -0.4, 0.05), 0.03, 0.03, METAL)
			k.box(Vector3(0, -0.45, 0.07), Vector3(0.1, 0.06, 0.1), METAL)
		"couteau":
			k.box(Vector3(0, -0.02, 0.03), Vector3(0.04, 0.1, 0.04), SOMBRE)
			k.box(Vector3(0, -0.02, 0.2), Vector3(0.015, 0.06, 0.26), METAL)
		"plateau":
			k.box(Vector3(0, 0.03, 0.12), Vector3(0.38, 0.02, 0.3), Color("4a4e57"))
			k.box(Vector3(-0.08, 0.08, 0.1), Vector3(0.07, 0.09, 0.07), BLANC)
			k.box(Vector3(0.09, 0.07, 0.14), Vector3(0.07, 0.07, 0.07), Color("f2c14e"))
		"tasse", "sachet", "billet":
			var col: Color = BLANC if nom == "tasse" else (Color("d8c3a5") if nom == "sachet" else Color("f4a261"))
			k.box(Vector3(0, -0.02, 0.06), Vector3(0.08, 0.1 if nom != "billet" else 0.01, 0.08 if nom != "billet" else 0.12), col)
		"carton":
			k.box(Vector3(-0.22, 0.05, 0.25), Vector3(0.55, 0.36, 0.4), Color("c49a6c"))
		"buche":
			k.tube(Vector3(-0.3, 0.05, 0.25), Vector3(0.3, 0.05, 0.25), 0.13, 0.12, 6, Color("8b5e34"))
		"craie", "stylo":
			k.box(Vector3(0, -0.02, 0.05), Vector3(0.02, 0.02, 0.1), BLANC if nom == "craie" else Color("1d3557"))
		"livre", "tablette":
			k.box(Vector3(0, 0.0, 0.1), Vector3(0.2, 0.03, 0.26), Color("b23a48") if nom == "livre" else SOMBRE)
		"stethoscope":
			k.beam(Vector3(0, 0, 0), Vector3(0, -0.15, 0.1), 0.015, 0.015, SOMBRE)
			k.box(Vector3(0, -0.16, 0.11), Vector3(0.05, 0.02, 0.05), METAL)
		"telephone", "radio":
			k.box(Vector3(0, 0.02, 0.04), Vector3(0.05, 0.14, 0.03), SOMBRE)
		"balai":
			k.beam(Vector3(0, 0.6, 0), Vector3(0, -0.9, 0.25), 0.03, 0.03, BOIS_CLAIR)
			k.box(Vector3(0, -0.92, 0.27), Vector3(0.35, 0.08, 0.08), Color("d4a373"))
		"marteau":
			k.beam(Vector3(0, 0.02, -0.02), Vector3(0, 0.0, 0.3), 0.03, 0.03, BOIS)
			k.box(Vector3(0, 0.0, 0.31), Vector3(0.05, 0.12, 0.05), METAL)
		"rabot":
			k.box(Vector3(0.15, -0.04, 0.05), Vector3(0.3, 0.08, 0.08), BOIS)
		"chalumeau":
			k.beam(Vector3(0, 0, 0), Vector3(0, -0.05, 0.25), 0.03, 0.03, METAL)
			k.box(Vector3(0, -0.05, 0.28), Vector3(0.03, 0.03, 0.05), Color("8ecae6"))
		"beche", "pioche":
			k.beam(Vector3(0, 0.25, 0), Vector3(0, -0.9, 0.0), 0.035, 0.035, BOIS)
			if nom == "beche":
				k.box(Vector3(0, -1.0, 0.0), Vector3(0.2, 0.22, 0.02), METAL)
			else:
				k.beam(Vector3(0, -0.9, -0.25), Vector3(0, -0.9, 0.3), 0.04, 0.05, METAL)
		"panier", "seau":
			k.box(Vector3(0, -0.12, 0.05), Vector3(0.24, 0.2, 0.2), Color("c8a165") if nom == "panier" else METAL)
		"tronconneuse":
			k.box(Vector3(0, -0.05, 0.12), Vector3(0.14, 0.16, 0.26), Color("e76f51"))
			k.box(Vector3(0, -0.05, 0.45), Vector3(0.03, 0.08, 0.45), METAL)
		"cle":
			k.box(Vector3(0, -0.02, 0.1), Vector3(0.03, 0.03, 0.22), METAL)
		"lance":
			k.beam(Vector3(0, 0, -0.2), Vector3(0, 0, 0.45), 0.06, 0.06, Color("c0c4c8"))
			k.tube(Vector3(0, 0, -0.2), Vector3(0, -0.9, -0.5), 0.04, 0.04, 5, Color("e9c46a"))
		"sifflet":
			k.box(Vector3(0, 0.0, 0.04), Vector3(0.03, 0.03, 0.05), METAL)
		_:
			return null
	var m := k.commit({"base": Figurine.materiau()})
	_outils[nom] = m
	return m


## Le poste fait-il asseoir l'employé ?
static func poste_assis(nom: String) -> bool:
	return nom in ["bureau", "bureau_prof", "volant", "pupitre"]


static func poste(nom: String) -> ArrayMesh:
	if _postes.has(nom):
		return _postes[nom]
	var k := _kit()
	var f := 0.65 # distance devant l'employé
	match nom:
		"petrin":
			k.box(Vector3(0, 0.4, f), Vector3(0.9, 0.8, 0.6), Color("8b8f94"))
			k.box(Vector3(0, 0.82, f), Vector3(0.7, 0.06, 0.45), Color("f3e9d2"))
		"plan_travail", "comptoir", "billot", "guichet", "caisse", "etabli", "table_plans":
			var col: Color = {"plan_travail": Color("e9e4d8"), "comptoir": BOIS, "billot": Color("8b5e34"), "guichet": Color("6b705c"),
				"caisse": Color("d9d9d9"), "etabli": BOIS, "table_plans": BOIS_CLAIR}[nom]
			k.box(Vector3(0, 0.45, f), Vector3(1.4, 0.9, 0.55), col)
			k.box(Vector3(0, 0.92, f), Vector3(1.45, 0.05, 0.6), Color(col).lightened(0.15))
			match nom:
				"plan_travail":
					for i in 3:
						k.box(Vector3(-0.35 + i * 0.3, 0.98, f), Vector3(0.06, 0.06, 0.4), Color("e0b36b"))
				"caisse":
					k.box(Vector3(0.3, 1.05, f), Vector3(0.3, 0.2, 0.25), SOMBRE)
					k.box(Vector3(0.3, 1.25, f + 0.05), Vector3(0.25, 0.18, 0.03), Color("4cc9f0"))
				"guichet":
					k.box(Vector3(0, 1.45, f + 0.25), Vector3(1.4, 0.9, 0.03), Color(0.8, 0.9, 1.0))
				"table_plans":
					k.box(Vector3(0, 0.96, f), Vector3(0.8, 0.01, 0.45), Color("cfe8ff"))
				"comptoir":
					k.box(Vector3(-0.4, 1.05, f), Vector3(0.3, 0.22, 0.3), Color("e0b36b"))
		"four":
			k.box(Vector3(0, 0.8, f + 0.4), Vector3(1.6, 1.6, 1.2), Color("9c6644"))
			k.box(Vector3(0, 0.95, f - 0.21), Vector3(0.8, 0.45, 0.02), Color("2b1d16"))
			k.box(Vector3(0, 0.95, f - 0.2), Vector3(0.6, 0.3, 0.02), Color("ff8c42"))
		"fourneau":
			k.box(Vector3(0, 0.45, f), Vector3(1.2, 0.9, 0.6), METAL)
			k.box(Vector3(-0.25, 1.0, f), Vector3(0.35, 0.2, 0.35), SOMBRE)
			k.box(Vector3(0.3, 0.96, f), Vector3(0.3, 0.1, 0.3), Color("cfd4da"))
		"table", "petite_table":
			var h := 0.75 if nom == "table" else 0.55
			k.box(Vector3(0, h, f), Vector3(0.9, 0.05, 0.9), BOIS_CLAIR)
			k.box(Vector3(0, h * 0.5, f), Vector3(0.08, h, 0.08), SOMBRE)
		"meule":
			k.tube(Vector3(0, 0.0, f + 0.2), Vector3(0, 0.5, f + 0.2), 0.6, 0.6, 10, Color("a8a29e"))
			k.box(Vector3(0, 0.7, f + 0.2), Vector3(0.12, 0.4, 0.12), BOIS)
		"etagere", "rack":
			k.box(Vector3(0, 1.0, f + 0.2), Vector3(1.6, 2.0, 0.45), BOIS_CLAIR if nom == "etagere" else Color("2a6f97"))
			for i in 4:
				for j in 4:
					k.box(Vector3(-0.55 + j * 0.37, 0.3 + i * 0.48, f + 0.1), Vector3(0.28, 0.28, 0.25),
						Color.from_hsv(fmod(0.1 + 0.23 * (i * 4 + j), 1.0), 0.45, 0.85) if nom == "etagere" else Color("c49a6c"))
		"palette", "caisses":
			k.box(Vector3(0, 0.07, f + 0.2), Vector3(1.2, 0.14, 0.8), BOIS_CLAIR)
			for i in 3:
				k.box(Vector3(-0.35 + i * 0.35, 0.35, f + 0.2), Vector3(0.32, 0.4, 0.6), Color("c49a6c") if nom == "palette" else Color("4cc9f0"))
		"tableau", "ecran":
			k.box(Vector3(0, 1.45, f + 0.5), Vector3(2.4, 1.1, 0.05), Color("2d4739") if nom == "tableau" else SOMBRE)
			k.box(Vector3(0, 0.88, f + 0.47), Vector3(2.4, 0.04, 0.1), BOIS)
			if nom == "tableau":
				for i in 4:
					k.box(Vector3(-0.8 + i * 0.4, 1.6 - (i % 2) * 0.2, f + 0.47), Vector3(0.3, 0.03, 0.01), BLANC)
			else:
				k.box(Vector3(0, 1.45, f + 0.47), Vector3(2.2, 0.95, 0.01), Color("4895ef"))
		"bureau", "bureau_prof":
			k.box(Vector3(0, ASSISE, 0), Vector3(0.45, 0.06, 0.45), SOMBRE)
			k.box(Vector3(0, 0.75, -0.22), Vector3(0.45, 0.6, 0.05), SOMBRE)
			k.box(Vector3(0, 0.74, 0.55), Vector3(1.2, 0.05, 0.6), BOIS_CLAIR)
			k.box(Vector3(0, 0.37, 0.75), Vector3(1.1, 0.72, 0.05), BOIS)
			if nom == "bureau":
				k.box(Vector3(0, 1.0, 0.72), Vector3(0.5, 0.32, 0.03), SOMBRE)
				k.box(Vector3(0, 1.0, 0.7), Vector3(0.45, 0.27, 0.01), Color("90e0ef"))
				k.box(Vector3(0, 0.78, 0.45), Vector3(0.4, 0.02, 0.14), Color("495057"))
			else:
				k.box(Vector3(0.2, 0.79, 0.5), Vector3(0.3, 0.06, 0.22), Color("e9c46a"))
		"pupitre":
			k.box(Vector3(0, ASSISE * 0.8, 0), Vector3(0.4, 0.05, 0.4), Color("2a9d8f"))
			k.box(Vector3(0, 0.6, -0.2), Vector3(0.4, 0.35, 0.04), Color("2a9d8f"))
			k.box(Vector3(0, 0.62, 0.42), Vector3(0.7, 0.04, 0.45), BOIS_CLAIR)
			k.box(Vector3(0, 0.31, 0.6), Vector3(0.65, 0.6, 0.04), METAL)
			k.box(Vector3(0.1, 0.65, 0.4), Vector3(0.2, 0.01, 0.26), BLANC)
		"lit", "brancard":
			var c := f + 0.35
			k.box(Vector3(0, 0.55, c), Vector3(2.0, 0.12, 0.9), BLANC)
			k.box(Vector3(0, 0.3, c), Vector3(1.9, 0.08, 0.8), METAL)
			k.box(Vector3(-0.85, 0.65, c), Vector3(0.3, 0.1, 0.55), Color("ffffff"))
			if nom == "lit":
				k.box(Vector3(0.2, 0.64, c), Vector3(1.3, 0.08, 0.86), Color("a8dadc"))
				k.box(Vector3(-0.98, 0.8, c), Vector3(0.05, 0.6, 0.9), METAL)
				# Patient allongé.
				k.blob(Vector3(-0.72, 0.75, c), Vector3(0.12, 0.12, 0.12), Color("e0a984"), Color("f1c8a6"), 0.03, 0)
		"perfusion":
			k.box(Vector3(0.6, 0.9, f + 0.3), Vector3(0.04, 1.8, 0.04), METAL)
			k.box(Vector3(0.6, 1.7, f + 0.3), Vector3(0.12, 0.2, 0.06), Color(0.8, 0.95, 1.0))
			k.box(Vector3(-0.2, 0.55, f + 0.6), Vector3(2.0, 0.12, 0.9), BLANC)
		"machine", "pupitre_commande", "projecteur":
			if nom == "machine":
				k.box(Vector3(0, 0.8, f + 0.45), Vector3(1.6, 1.6, 1.0), Color("457b9d"))
				k.box(Vector3(0, 1.0, f - 0.06), Vector3(0.6, 0.4, 0.04), SOMBRE)
				k.box(Vector3(-0.15, 1.05, f - 0.09), Vector3(0.08, 0.08, 0.03), Color("e63946"))
				k.box(Vector3(0.1, 1.05, f - 0.09), Vector3(0.08, 0.08, 0.03), Color("52b788"))
				k.tube(Vector3(0.95, 0.5, f + 0.45), Vector3(0.95, 0.5, f + 2.0), 0.25, 0.25, 8, SOMBRE)
			elif nom == "pupitre_commande":
				k.box(Vector3(0, 0.5, f), Vector3(1.0, 1.0, 0.4), Color("6c757d"))
				k.box(Vector3(0, 1.1, f + 0.1), Vector3(0.9, 0.35, 0.05), Color("90e0ef"))
			else:
				k.box(Vector3(0, 1.2, f), Vector3(0.5, 0.4, 0.8), SOMBRE)
				k.box(Vector3(0, 0.5, f), Vector3(0.3, 1.0, 0.3), METAL)
		"creuset":
			k.box(Vector3(0, 0.6, f + 0.3), Vector3(1.0, 1.2, 1.0), Color("495057"))
			k.box(Vector3(0, 1.21, f + 0.3), Vector3(0.7, 0.03, 0.7), Color("ff7b00"))
		"sillons":
			for i in 3:
				k.box(Vector3(0, 0.08, f + i * 0.6), Vector3(2.4, 0.16, 0.3), Color("6f4e37"))
				for j in 5:
					k.blob(Vector3(-1.0 + j * 0.5, 0.25, f + i * 0.6), Vector3(0.14, 0.14, 0.14), Color("52b788"), Color("95d5b2"), 0.05, 0)
		"mangeoire":
			k.box(Vector3(0, 0.3, f + 0.2), Vector3(1.8, 0.6, 0.5), BOIS)
			k.box(Vector3(0, 0.58, f + 0.2), Vector3(1.6, 0.05, 0.4), Color("e9c46a"))
		"vache":
			var cv := f + 0.3
			k.box(Vector3(0.3, 0.95, cv), Vector3(1.6, 0.7, 0.6), BLANC)
			k.box(Vector3(0.0, 1.0, cv + 0.31), Vector3(0.5, 0.4, 0.01), SOMBRE)
			k.box(Vector3(1.25, 1.05, cv), Vector3(0.4, 0.35, 0.35), BLANC)
			for x in [-0.35, 0.9]:
				for z in [-0.2, 0.2]:
					k.box(Vector3(x, 0.32, cv + z), Vector3(0.14, 0.64, 0.14), BLANC)
			k.box(Vector3(0.0, 0.52, cv), Vector3(0.25, 0.12, 0.25), Color("f4a6b0"))
		"tronc", "grumes":
			if nom == "tronc":
				k.tube(Vector3(0, 0, f + 0.3), Vector3(0, 3.5, f + 0.3), 0.25, 0.18, 8, Color("6d4c41"))
				k.blob(Vector3(0, 4.3, f + 0.3), Vector3(1.4, 1.4, 1.4), Color("2d6a4f"), Color("52b788"), 0.2, 1)
			else:
				for i in 4:
					k.tube(Vector3(-1.4, 0.2 + (i / 2) * 0.35, f + 0.2 + (i % 2) * 0.4), Vector3(1.4, 0.2 + (i / 2) * 0.35, f + 0.2 + (i % 2) * 0.4), 0.18, 0.18, 7, Color("8b5e34"))
		"rochers":
			for i in 4:
				k.stone(Vector3(-0.6 + i * 0.4, 0.25, f + 0.3 + (i % 2) * 0.3), Vector3(0.5, 0.45, 0.5), Color("9e9e9e"))
		"derrick":
			for sx in [-0.6, 0.6]:
				for sz in [-0.6, 0.6]:
					k.beam(Vector3(sx, 0, f + 1.0 + sz), Vector3(0, 6.0, f + 1.0), 0.08, 0.08, Color("d62828"))
		"filet":
			k.box(Vector3(0, 0.3, f + 0.6), Vector3(2.4, 0.6, 1.2), Color("1d3557"))
			k.box(Vector3(0, 0.62, f + 0.6), Vector3(1.6, 0.04, 0.8), Color("8ecae6"))
		"volant":
			k.box(Vector3(0, ASSISE, 0), Vector3(0.5, 0.08, 0.5), SOMBRE)
			k.box(Vector3(0, 0.8, -0.25), Vector3(0.5, 0.7, 0.08), SOMBRE)
			k.tube(Vector3(0, 0.85, 0.42), Vector3(0, 0.92, 0.36), 0.18, 0.18, 8, SOMBRE)
			k.box(Vector3(0, 0.6, 0.6), Vector3(1.6, 0.6, 0.25), Color("f9c74f"))
		"tuyau":
			k.tube(Vector3(0, 0.05, 0), Vector3(0, 0.05, -2.0), 0.06, 0.06, 5, Color("e9c46a"))
		"camion":
			k.box(Vector3(0, 1.3, f + 1.2), Vector3(2.4, 2.4, 2.0), Color("d62828"))
			k.box(Vector3(0, 0.45, f + 0.2), Vector3(2.0, 0.6, 0.1), METAL)
		"tapis":
			k.box(Vector3(0, 0.02, f + 0.6), Vector3(2.0, 0.04, 1.4), Color("4361ee"))
		"scene":
			k.box(Vector3(0, 0.15, 0.0), Vector3(3.0, 0.3, 2.0), BOIS)
		_:
			return null
	var m := k.commit({"base": Figurine.materiau()})
	_postes[nom] = m
	return m
