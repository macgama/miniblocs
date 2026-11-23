class_name BatimentsClassiques
extends RefCounted
## Modèles « classiques » de la ville (ceux du zonage par défaut et des
## services publics), dessinés avec soin : couleurs franches et harmonieuses,
## toits équipés, balcons, marquises, enseignes, abords plantés. Chaque type a
## quatre variantes (palettes et équipements différents).
##
## De loin (k._fine() faux), seuls les volumes, les grandes lignes de façade
## et les couleurs restent : peu de triangles.
## Repère : sol en y = 0, façade (porte) vers −Z, emprise w × d centrée.

const H = preload("res://scripts/batiments/habillage_ville.gd")

## Types dessinés ici (les autres restent dans BuildingCatalog.build_mesh).
const IDS := ["maison", "villa", "immeuble", "tour_habitation", "bureaux", "atelier", "entrepot", "usine",
	"maison_commune", "mairie", "ecole", "pompiers", "police", "hopital", "chateau_eau"]

const VITRE := Color("33495e")
const VITRE_CLAIRE := Color("6d97b8")
const VITRE_MUR := Color("8fb8d8")
const VITRE_BLEUE := Color("4f6d8f")
const VITRE_PORTE := Color("1d2d3c")


static func gere(id: String) -> bool:
	return id in IDS


static func build(k: BlocMesh, id: String, w: float, d: float) -> void:
	var rng := H.rng_pour(k, id)
	match id:
		"maison": _maison(k, w, d, rng)
		"villa": _villa(k, w, d, rng)
		"immeuble": _immeuble(k, w, d, rng)
		"tour_habitation": _tour(k, w, d, rng)
		"bureaux": _bureaux(k, w, d, rng)
		"mairie": _mairie(k, w, d, rng)
		"maison_commune": _maison_commune(k, w, d, rng)
		"ecole": _ecole(k, w, d, rng)
		"pompiers": _pompiers(k, w, d, rng)
		"police": _police(k, w, d, rng)
		"hopital": _hopital(k, w, d, rng)
		"atelier": _atelier(k, w, d, rng)
		"entrepot": _entrepot(k, w, d, rng)
		"usine": _usine(k, w, d, rng)
		"chateau_eau": _chateau_eau(k, w, d, rng)


static func _pal(k: BlocMesh, palettes: Array) -> Dictionary:
	var p: Dictionary = palettes[k.variant % palettes.size()]
	var out := {}
	for key in p:
		out[key] = p[key] if key in ["garde", "mode"] else Color(String(p[key]))
	return out


# --- Logement ---------------------------------------------------------------------------

const PAL_MAISON := [
	{"mur": "f6ead2", "toit": "c8553d", "volet": "4f7a5a", "porte": "7a4a2e", "cloture": "f4f1ea"},
	{"mur": "f3d9a4", "toit": "8c4a3a", "volet": "3d6b8f", "porte": "2f4f6f", "cloture": "f4f1ea"},
	{"mur": "dfe8d6", "toit": "5b5f66", "volet": "c0623a", "porte": "8c2f39", "cloture": "6b4f3a"},
	{"mur": "f2c9b6", "toit": "a4553f", "volet": "f4f1ea", "porte": "3d6b4f", "cloture": "f4f1ea"},
]


static func _maison(k: BlocMesh, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var p := _pal(k, PAL_MAISON)
	k.plate(0, 0, w, d, Color("7fb35a"))
	k.box(0, 0, -1.0, 8.0, 5.6, 8.0, p.mur)
	k.gable(0, 5.6, -1.0, 8.8, 8.8, 3.2, p.toit)
	k.box(0, 0, -5.0, 1.1, 2.2, 0.2, p.porte)
	k.windows_row(0, -5.0, 7.0, 3.3, 3, 1.1, 1.2, VITRE)
	k.windows_row(-2.5, -5.0, 2.0, 0.9, 1, 1.1, 1.2, VITRE)
	k.windows_row(2.5, -5.0, 2.0, 0.9, 1, 1.1, 1.2, VITRE)
	k.windows_col(-4.0, -1.0, 6.0, 3.3, 2, 1.1, 1.2, VITRE)
	k.windows_col(4.0, -1.0, 6.0, 3.3, 2, 1.1, 1.2, VITRE)
	k.windows_col(4.0, -1.0, 6.0, 0.9, 2, 1.1, 1.2, VITRE)
	k.box(3.0, 5.6, 1.0, 0.7, 2.6, 0.7, Color("8c4a3a"))
	if not k._fine():
		k.tree(-3.2, 4.4, 0.8)
		return
	k.anchor("fumee", Vector3(3.0, 8.3, 1.0))
	k.box(3.0, 8.2, 1.0, 0.85, 0.12, 0.85, Color("6b3a2e"))
	# Volets ouverts de part et d'autre des fenêtres de façade.
	for y in [0.9, 3.3]:
		var xs := [-2.5, 2.5] if y < 2.0 else [-7.0 / 3.0, 0.0, 7.0 / 3.0]
		for x: float in xs:
			for s in [-1.0, 1.0]:
				k.box(x + s * 0.88, y - 0.02, -5.08, 0.55, 1.24, 0.06, p.volet)
	# Jardinières sous les fenêtres de l'étage.
	for x in [-7.0 / 3.0, 7.0 / 3.0]:
		k.box(x, 3.05, -5.2, 1.2, 0.22, 0.3, Color("c0623a"))
		for j in 3:
			k.box(x - 0.4 + j * 0.4, 3.27, -5.2, 0.24, 0.16, 0.2, H.FLEURS[(j + k.variant) % H.FLEURS.size()])
	# Auvent au-dessus de la porte, marches.
	k.panel(Vector3(-0.95, 2.75, -5.1), Vector3(0.95, 2.75, -5.1), Vector3(0.95, 2.45, -6.0), Vector3(-0.95, 2.45, -6.0), Vector3(0, 1, -0.3), p.toit)
	for x in [-0.85, 0.85]:
		k.box(x, 2.3, -5.9, 0.08, 0.2, 0.08, Color("f4f1ea"))
	H.marches(k, 0, -5.1, 1.4, 2)
	# Allée, clôture à piquets, boîte aux lettres.
	k.plate(0, -5.75, 1.2, 1.5, Color("d8cdb6"), 0.0, 0.1)
	_cloture(k, -w / 2.0 + 0.15, w / 2.0 - 0.15, -d / 2.0 + 0.15, 1.4, p.cloture)
	k.box(1.4, 0, -d / 2.0 + 0.5, 0.08, 1.0, 0.08, Color("3d4248"))
	k.box(1.4, 1.0, -d / 2.0 + 0.5, 0.45, 0.32, 0.3, p.volet)
	# Jardin : arbre rond, massifs, haie au fond, potager.
	H.arbre_rond(k, -3.4, 0, 4.4, 0.9, H.FEUILLAGES[k.variant % H.FEUILLAGES.size()])
	H.massif(k, -2.8, -5.6, 2.4, 0.8, rng)
	H.massif(k, 2.9, -5.6, 2.2, 0.8, rng)
	H.haie(k, 0, d / 2.0 - 0.4, w - 0.6, 0.6, 1.0)
	if k.variant % 2 == 0:
		for i in 3:
			k.box(2.6, 0, 3.6 + i * 0.7, 2.4, 0.25, 0.45, Color("6b4f3a"))
			for j in 4:
				k.dome(1.7 + j * 0.6, 0.25, 3.6 + i * 0.7, 0.2, 0.25, Color("5f9e4a"), 5)
	else:
		H.parasol(k, 2.6, 0, 4.4, H.PARASOLS[k.variant % H.PARASOLS.size()])


## Clôture basse à piquets sur l'avant (z), avec un portillon au milieu.
static func _cloture(k: BlocMesh, x0: float, x1: float, z: float, porte: float, col: Color) -> void:
	for seg in [[x0, -porte / 2.0], [porte / 2.0, x1]]:
		var a: float = seg[0]
		var b: float = seg[1]
		var n := maxi(1, int((b - a) / 0.35))
		for i in n + 1:
			k.box(a + i * (b - a) / n, 0, z, 0.08, 0.85, 0.06, col)
		k.box((a + b) / 2.0, 0.55, z, b - a, 0.08, 0.05, col)
		k.box((a + b) / 2.0, 0.25, z, b - a, 0.08, 0.05, col)


const PAL_VILLA := [
	{"mur": "f7f4ee", "bardage": "b07a4f", "toit": "e9e2d4", "accent": "3d4248"},
	{"mur": "f2e3c6", "bardage": "8a5a3c", "toit": "e8dcc4", "accent": "c8553d"},
	{"mur": "e6eef0", "bardage": "6f7a80", "toit": "dfe6ea", "accent": "2a9d8f"},
	{"mur": "f5e1d3", "bardage": "a86b4a", "toit": "eadbd0", "accent": "3d6b8f"},
]


static func _villa(k: BlocMesh, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var p := _pal(k, PAL_VILLA)
	k.plate(0, 0, w, d, Color("7fb35a"))
	# Volume du bas, volume de l'étage décalé (porte-à-faux), garage.
	k.box(-1.5, 0, -2.0, 11.0, 3.0, 9.0, p.mur)
	k.box(-2.3, 3.0, -2.4, 9.4, 3.0, 8.2, p.bardage if k.variant % 2 == 0 else p.mur)
	k.box(-2.3, 6.0, -2.4, 10.0, 0.4, 8.8, p.toit)
	k.box(-1.5, 3.0, -2.0, 11.6, 0.3, 9.6, p.toit)
	k.box(5.5, 0, -4.0, 4.4, 3.0, 6.0, p.mur.darkened(0.04))
	k.box(5.5, 3.0, -4.0, 4.7, 0.3, 6.3, p.toit)
	k.box(5.5, 0, -7.05, 3.2, 2.4, 0.1, Color("9aa0a6"))
	# Grandes baies.
	k.box(-3.0, 0.25, -6.55, 6.0, 2.4, 0.1, VITRE_CLAIRE)
	k.windows_row(-2.3, -6.55, 8.0, 3.7, 3, 2.0, 1.6, VITRE)
	k.box(-1.5, 0.25, 2.55, 8.0, 2.4, 0.1, VITRE_CLAIRE)
	k.box(0.5, 0, -6.6, 1.2, 2.4, 0.1, Color("5a3a22"))
	# Piscine et plage.
	k.plate(-1.0, 5.0, 9.0, 4.4, Color("e8e2d4"), 0.0, 0.12)
	k.plate(-1.0, 5.0, 7.0, 3.0, Color("4fc3e0"), 0.0, 0.16)
	if not k._fine():
		k.tree(6.0, 5.5, 1.0)
		return
	# Lames du bardage.
	if k.variant % 2 == 0:
		for i in 8:
			k.box(-2.3, 3.2 + i * 0.36, -6.52, 9.42, 0.06, 0.04, p.bardage.darkened(0.15))
	# Montants des baies, marquise sur l'entrée, garde-corps de la terrasse.
	for i in 5:
		k.box(-6.0 + i * 1.5, 0.25, -6.62, 0.08, 2.4, 0.08, p.accent)
	H.marquise(k, 0.5, 2.6, -6.5, 2.2, 1.2, p.accent)
	k.box(4.0, 3.3, -2.0, 0.06, 0.9, 9.4, H.VERRE_GC)
	# Plage de la piscine : transats, parasol, bordure.
	for x in [-4.6, -3.2]:
		k.box(x, 0.12, 6.6, 0.7, 0.3, 1.8, Color("f4f1ea"))
		k.panel(Vector3(x - 0.35, 0.42, 6.9), Vector3(x + 0.35, 0.42, 6.9), Vector3(x + 0.35, 0.9, 7.5), Vector3(x - 0.35, 0.9, 7.5), Vector3(0, 1, 1), Color("f4f1ea"))
	H.parasol(k, 3.6, 0.12, 6.4, H.PARASOLS[(k.variant + 2) % H.PARASOLS.size()])
	k.box(-1.0, 0.16, 3.5, 0.6, 0.6, 0.06, Color("c3c8ce"))
	# Allée du garage, haies, arbres ronds, massifs.
	k.plate(5.5, -7.6, 3.4, 1.0, Color("bdb7ad"), 0.0, 0.1)
	H.haie(k, -w / 2.0 + 0.35, 1.0, 0.6, d - 2.0, 1.3)
	H.haie(k, w / 2.0 - 0.35, 3.5, 0.6, 8.0, 1.3)
	H.arbre_rond(k, 6.0, 0, 5.5, 1.0, H.FEUILLAGES[(k.variant + 1) % H.FEUILLAGES.size()])
	H.arbre_rond(k, -6.5, 0, 6.0, 0.8, H.FEUILLAGES[k.variant % H.FEUILLAGES.size()])
	H.massif(k, -4.0, -7.4, 5.0, 0.9, rng)
	H.lampadaire(k, 2.0, -7.5, 2.0)


const PAL_IMMEUBLE := [
	{"mur": "f4e4c8", "socle": "d9734e", "cordon": "fbf6ec", "rail": "f4f1ea", "garde": "verre", "mode": "mixte"},
	{"mur": "eba98a", "socle": "8c4a3a", "cordon": "f6efe2", "rail": "3d4248", "garde": "barreaux", "mode": "jardin"},
	{"mur": "c3d8b8", "socle": "4f7a5a", "cordon": "f4f1ea", "rail": "f4f1ea", "garde": "verre", "mode": "solaire"},
	{"mur": "b5d3e7", "socle": "3d6b8f", "cordon": "f7f4ee", "rail": "f7f4ee", "garde": "plein", "mode": "technique"},
]


static func _immeuble(k: BlocMesh, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var p := _pal(k, PAL_IMMEUBLE)
	var bw := 16.0
	var bd := 10.5
	var cz := 0.25
	var fz := cz - bd / 2.0
	var fh := 3.2
	var floors := 4
	k.plate(0, 0, w, d, Color("cfc8bb"))
	# Socle coloré (rez-de-chaussée) et étages.
	k.box(0, 0, cz, bw, fh, bd, p.socle)
	k.box(0, fh, cz, bw, fh * (floors - 1), bd, p.mur)
	H.fenetres(k, 0, cz, bw, bd, 0, floors, fh, 5, 3, VITRE, 1.2, 1.5, true)
	k.windows_row(-4.6, fz, 5.0, 0.9, 2, 1.3, 1.5, VITRE)
	k.windows_row(4.6, fz, 5.0, 0.9, 2, 1.3, 1.5, VITRE)
	H.porte_vitree(k, 0, fz, 2.2, 2.5)
	H.toit_terrasse(k, 0, floors * fh, cz, bw, bd, p.mur, rng, {"mode": String(p.mode), "acrotere": 0.8})
	if not k._fine():
		return
	# Cordons d'étage clairs et chaînes d'angle.
	for i in range(1, floors):
		k.box(0, i * fh - 0.1, cz, bw + 0.14, 0.2, bd + 0.14, p.cordon)
	for x in [-bw / 2.0, bw / 2.0]:
		for z in [fz, cz + bd / 2.0]:
			k.box(x, fh, z, 0.5, fh * (floors - 1), 0.5, p.cordon)
	# Balcons : en quinconce devant, en colonnes derrière.
	H.balcons(k, 0, fz, bw, 0, floors, fh, -1.0, p.cordon, p.rail, rng, "alterne", String(p.garde), 3.0, 1.3)
	H.balcons(k, 0, cz + bd / 2.0, bw, 0, floors, fh, 1.0, p.cordon, p.rail, rng, "colonnes", String(p.garde), 3.0, 1.1)
	# Entrée : marquise colorée, marches, numéro, jardinières, vélos, lampadaire.
	H.marquise(k, 0, 2.9, fz, 3.4, 1.4, p.cordon)
	H.marches(k, 0, fz, 2.4, 2)
	k.box(1.55, 2.2, fz - 0.07, 0.45, 0.45, 0.06, Color("f4f1ea"))
	H.jardiniere(k, -2.8, 0, fz - 0.9, 2.4, 0.8, rng)
	H.jardiniere(k, 2.8, 0, fz - 0.9, 2.4, 0.8, rng)
	H.velos(k, 5.0, fz - 1.0, 4, rng)
	H.lampadaire(k, -7.6, fz - 1.2)
	H.arbre_rond(k, -7.2, 0, cz + bd / 2.0 + 0.9, 0.7, H.FEUILLAGES[k.variant])
	# Boîtes aux lettres et interphone à droite de la porte.
	k.box(-1.6, 1.0, fz - 0.06, 0.5, 0.8, 0.08, Color("c3c8ce"))


const PAL_TOUR := [
	{"mur": "f4f2ee", "accent": "2a9d8f", "socle": "e9e4da", "vitre": "4f6d8f"},
	{"mur": "f2e2c8", "accent": "c8553d", "socle": "e6d6bc", "vitre": "33495e"},
	{"mur": "e3e7ea", "accent": "e9b949", "socle": "cfd5da", "vitre": "6d97b8"},
	{"mur": "f3dcd6", "accent": "3d5a80", "socle": "e8cfc8", "vitre": "4f6d8f"},
]


static func _tour(k: BlocMesh, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var p := _pal(k, PAL_TOUR)
	var fh := 3.0
	var floors := 12
	var y0 := 4.5
	var tw := 16.0
	var top := y0 + floors * fh
	k.plate(0, 0, w, d, Color("cfc8bb"))
	# Socle vitré, avec terrasse plantée sur son toit.
	k.box(0, 0, 0, 20.0, y0, 20.0, p.socle)
	H.trame(k, 0, 0, 20.0, 20.0, 0.4, 1, 3.6, VITRE_PORTE if k.variant == 1 else VITRE_BLEUE, p.socle.darkened(0.15), 2.5, 0.75)
	k.box(0, y0 - 0.3, 0, 20.4, 0.3, 20.4, p.accent)
	# Fût de la tour.
	k.box(0, y0, 0, tw, floors * fh, tw, p.mur)
	H.trame(k, 0, 0, tw, tw, y0, floors, fh, p.vitre, p.mur.lightened(0.3), 2.0, 0.5)
	# Bandes d'angle colorées en façade et couronnement.
	k.box(0, top, 0, tw + 0.6, 0.5, tw + 0.6, p.accent)
	var attique := 9.0
	k.box(-2.0, top + 0.5, 1.5, attique, 3.0, attique, p.mur)
	k.box(-2.0, top + 0.9, 1.5 - attique / 2.0, attique - 1.0, 2.0, 0.1, p.vitre)
	k.box(-2.0, top + 3.5, 1.5, attique + 1.6, 0.35, attique + 1.6, p.accent)
	H.toit_terrasse(k, -2.0, top + 3.85, 1.5, attique, attique, p.mur, rng, {"mode": "technique", "edicule": false, "antenne": true, "acrotere": 0.5})
	if not k._fine():
		return
	for x in [-tw / 2.0, tw / 2.0]:
		k.box(x, y0, -tw / 2.0, 0.7, floors * fh, 0.7, p.accent)
	# Balcons vitrés devant et derrière, un étage sur deux décalé.
	H.balcons(k, 0, -tw / 2.0, tw - 1.0, y0, floors, fh, -1.0, p.mur.darkened(0.05), p.mur, rng, "alterne", "verre", 3.0, 1.3, 0)
	H.balcons(k, 0, tw / 2.0, tw - 1.0, y0, floors, fh, 1.0, p.mur.darkened(0.05), p.mur, rng, "alterne", "verre", 3.0, 1.3, 0)
	# Terrasse de l'attique (pergola) et jardin sur le socle.
	k.plate(-2.0, 1.5 - attique / 2.0 - 1.4, attique, 2.6, H.BOIS_TERRASSE, top + 0.5, 0.06)
	for x in [-5.8, 1.8]:
		k.box(x, top + 0.5, 1.5 - attique / 2.0 - 2.5, 0.12, 2.6, 0.12, p.accent)
	k.box(-2.0, top + 3.1, 1.5 - attique / 2.0 - 1.5, attique - 1.0, 0.12, 2.4, p.accent)
	H.parasol(k, 4.0, top + 0.5, -1.0, H.PARASOLS[k.variant])
	for c in [Vector2(-9.0, -9.0), Vector2(9.0, -9.0), Vector2(-9.0, 9.0), Vector2(9.0, 9.0)]:
		k.plate(c.x * 0.95, c.y * 0.95, 2.2, 2.2, H.PELOUSE, y0, 0.12)
		k.dome(c.x * 0.95, y0 + 0.12, c.y * 0.95, 0.8, 0.9, H.FEUILLAGES[rng.randi() % H.FEUILLAGES.size()], 6)
	for i in 4:
		H.jardiniere(k, -6.0 + i * 4.0, y0, -9.4, 2.2, 0.7, rng)
	# Entrée : marquise, porte, enseigne du numéro, abords.
	H.marquise(k, 0, 3.4, -10.0, 7.0, 2.2, p.accent, true)
	H.porte_vitree(k, 0, -10.0, 3.0, 2.8)
	H.marches(k, 0, -10.0, 4.0, 1)
	H.jardiniere(k, -6.5, 0, -10.6, 3.0, 0.8, rng)
	H.jardiniere(k, 6.5, 0, -10.6, 3.0, 0.8, rng)
	H.banc(k, -3.8, -10.6)
	H.velos(k, 8.0, -9.0, 3, rng)
	H.lampadaire(k, -10.4, -10.4)
	H.lampadaire(k, 10.0, -10.4)


# --- Bureaux ----------------------------------------------------------------------------

const PAL_BUREAUX := [
	{"vitre": "8fb8d8", "cadre": "f2f4f6", "socle": "dfe4e8", "logo": "2a6fdb", "lettres": "f4f7fa"},
	{"vitre": "4f6d8f", "cadre": "3d4248", "socle": "5b6068", "logo": "e76f51", "lettres": "fdf6ec"},
	{"vitre": "6d97b8", "cadre": "e8dcc6", "socle": "d8c9ad", "logo": "2a9d8f", "lettres": "fbf8f0"},
	{"vitre": "8fb8d8", "cadre": "c9d3da", "socle": "aab4bc", "logo": "f4a261", "lettres": "263238"},
]


static func _bureaux(k: BlocMesh, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var p := _pal(k, PAL_BUREAUX)
	var fh := 3.6
	var floors := 6
	var bw := 20.0
	var bd := 14.0
	var cz := 1.5
	var fz := cz - bd / 2.0
	var top := floors * fh
	k.plate(0, 0, w, d, Color("d6d1c7"))
	k.box(0, 0, cz, bw, top, bd, p.cadre.darkened(0.08))
	H.trame(k, 0, cz, bw, bd, 0, floors, fh, p.vitre, p.cadre, 1.7, 0.74)
	# Hall en double hauteur sous un auvent.
	k.box(0, top, cz, bw + 0.8, 0.5, bd + 0.8, p.cadre)
	H.porte_vitree(k, 0, fz - 0.16, 3.2, 3.0)
	H.toit_terrasse(k, 0, top + 0.5, cz, bw, bd, p.cadre, rng, {"mode": "technique", "acrotere": 1.1})
	if not k._fine():
		return
	# Brise-soleil horizontaux sur la façade sud selon la variante.
	if k.variant % 2 == 1:
		for i in range(1, floors):
			k.box(0, i * fh + fh * 0.72, fz - 0.55, bw, 0.08, 0.9, p.cadre)
	else:
		for i in range(1, floors):
			k.box(0, i * fh - 0.1, fz - 0.45, bw + 0.3, 0.2, 0.7, p.cadre)
	H.marquise(k, 0, 4.0, fz - 0.2, 9.0, 3.0, p.logo, true)
	# Enseigne de la société sur le toit, logo en façade.
	H.enseigne_toit(k, -2.5, top + 0.5 + 1.1, fz + 1.2, 9.0, 1.4, p.logo, p.lettres, rng)
	H.pastille(k, bw / 2.0 - 2.0, top - 1.0, fz - 0.2, 0.9, p.logo, p.lettres, "carre")
	# Abords : mâts, bancs, jardinières, arbres ronds, vélos.
	for i in 3:
		H.drapeau(k, -8.5 + i * 1.6, -7.8, 7.0, [p.logo, Color("f4f1ea"), Color("3d5a80")][i], p.logo.lightened(0.3))
	H.jardiniere(k, -6.5, 0, fz - 1.4, 3.2, 1.0, rng)
	H.jardiniere(k, 6.5, 0, fz - 1.4, 3.2, 1.0, rng)
	H.banc(k, 6.5, fz - 2.4)
	H.velos(k, 7.5, cz + bd / 2.0 + 0.7, 3, rng)
	H.arbre_rond(k, -9.6, 0, cz + bd / 2.0 + 0.6, 0.65, H.FEUILLAGES[k.variant])
	H.lampadaire(k, 9.6, -8.4)


# --- Services publics -------------------------------------------------------------------

const PAL_MAIRIE := [
	{"mur": "f3e8d2", "toit": "4f5d75", "pierre": "e2d3b4", "volet": "3d6b8f"},
	{"mur": "f0d9a8", "toit": "a4553f", "pierre": "e6c98f", "volet": "4f7a5a"},
	{"mur": "f6f3ec", "toit": "3f4a5c", "pierre": "dcd6c8", "volet": "7a2e2e"},
	{"mur": "efd3c3", "toit": "5b5f66", "pierre": "e0bfa9", "volet": "2f4f6f"},
]


static func _mairie(k: BlocMesh, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var p := _pal(k, PAL_MAIRIE)
	k.plate(0, 0, w, d, Color("d8d2c4"))
	k.box(0, 0, 1.0, 24.0, 10.0, 14.0, p.mur)
	k.gable(0, 10.0, 1.0, 24.8, 14.8, 4.0, p.toit)
	# Avant-corps central à fronton.
	k.box(0, 0, -6.3, 8.0, 10.0, 0.8, p.pierre)
	k.windows_row(-8.0, -6.0, 8.0, 1.4, 3, 1.4, 2.4, VITRE)
	k.windows_row(8.0, -6.0, 8.0, 1.4, 3, 1.4, 2.4, VITRE)
	k.windows_row(-8.0, -6.0, 8.0, 5.8, 3, 1.4, 2.4, VITRE)
	k.windows_row(8.0, -6.0, 8.0, 5.8, 3, 1.4, 2.4, VITRE)
	k.windows_row(0, -6.7, 6.0, 5.8, 3, 1.3, 2.4, VITRE)
	k.windows_col(-12.0, 1.0, 12.0, 1.4, 4, 1.4, 2.4, VITRE)
	k.windows_col(12.0, 1.0, 12.0, 1.4, 4, 1.4, 2.4, VITRE)
	k.windows_col(-12.0, 1.0, 12.0, 5.8, 4, 1.4, 2.4, VITRE)
	k.windows_col(12.0, 1.0, 12.0, 5.8, 4, 1.4, 2.4, VITRE)
	k.box(0, 0, -6.75, 2.4, 3.6, 0.2, Color("6b4a33"))
	# Campanile et horloge.
	k.box(0, 10.0, -4.0, 4.0, 8.0, 4.0, p.mur)
	k.pyramid(0, 18.0, -4.0, 4.6, 4.6, 4.0, p.toit)
	H.horloge(k, 0, 16.6, -6.0, 1.2)
	# Mât : le drapeau du village y est hissé (Communes, position fixe).
	k.box(0, 0, -7.5, 0.2, 9.2, 0.2, Color("d9d9d9"))
	if not k._fine():
		return
	# Fronton triangulaire et corniche.
	k.gable(0, 10.0, -6.3, 8.6, 0.9, 2.2, p.pierre, true)
	k.box(0, 9.8, 1.0, 24.6, 0.3, 14.6, p.pierre)
	k.box(0, 4.4, 1.0, 24.3, 0.25, 14.3, p.pierre)
	k.box(0, 0, 1.0, 24.3, 0.7, 14.3, p.pierre.darkened(0.12))
	# Colonnes, balcon d'honneur, marches.
	for x in [-3.4, -1.6, 1.6, 3.4]:
		k.cylinder(x, 0.6, -7.0, 0.3, 0.3, 3.6, 8, Color("f6f1e6"))
		k.box(x, 4.2, -7.0, 0.7, 0.2, 0.7, Color("f6f1e6"))
	k.box(0, 4.2, -7.3, 8.2, 0.25, 1.6, p.pierre)
	StyleKit.garde_corps(k, 0, 4.45, -8.05, 8.0, Color("2e3136"))
	for i in 4:
		var dd := 0.45 * (4 - i)
		k.box(0, i * 0.15, -6.75 - dd / 2.0, 9.0 + (3 - i) * 0.6, 0.15, dd, Color("cfc6b4").lightened(i * 0.03))
	# Volets et lucarnes.
	for row in [1.4, 5.8]:
		for xc in [-8.0, 8.0]:
			for i in 3:
				var x: float = xc - 8.0 / 2.0 + 8.0 / 3.0 * (i + 0.5)
				for s in [-1.0, 1.0]:
					k.box(x + s * 1.05, row - 0.02, -6.08, 0.65, 2.44, 0.06, p.volet)
	for x in [-9.0, -5.5, 5.5, 9.0]:
		k.box(x, 10.4, -4.6, 1.5, 1.6, 1.4, p.mur)
		k.gable(x, 12.0, -4.6, 1.8, 1.6, 0.7, p.toit, false)
		k.box(x, 10.6, -5.32, 0.9, 1.1, 0.06, VITRE)
	# Abords : massifs, lampadaires, bancs.
	H.massif(k, -8.5, -8.0, 6.0, 1.4, rng)
	H.massif(k, 8.5, -8.0, 6.0, 1.4, rng)
	H.lampadaire(k, -5.4, -8.4)
	H.lampadaire(k, 5.4, -8.4)
	H.banc(k, -11.5, -8.0, false)
	H.banc(k, 11.5, -8.0, false)
	H.arbre_rond(k, -11.8, 0, 8.6, 0.8, H.FEUILLAGES[1])
	H.arbre_rond(k, 11.8, 0, 8.6, 0.8, H.FEUILLAGES[3])


static func _maison_commune(k: BlocMesh, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var p := _pal(k, PAL_MAIRIE)
	k.plate(0, 0, w, d, Color("cfc8b6"))
	k.box(0, 0, 1.0, 12.0, 6.4, 8.0, p.mur)
	k.gable(0, 6.4, 1.0, 12.8, 8.8, 3.2, BuildingCatalog.ROOF_TILE if k.variant % 2 == 0 else p.toit)
	k.box(0, 0, -3.05, 1.6, 2.6, 0.2, Color("6b4a33"))
	k.box(0, 2.6, -3.1, 2.2, 0.3, 0.3, p.pierre)
	k.windows_row(0, -3.0, 10.0, 0.9, 4, 1.1, 1.6, VITRE)
	k.windows_row(0, -3.0, 10.0, 3.9, 4, 1.1, 1.4, VITRE)
	k.box(0, 6.4, -1.0, 2.2, 4.6, 2.2, p.mur)
	H.horloge(k, 0, 9.9, -2.1, 0.65)
	k.pyramid(0, 11.0, -1.0, 2.8, 2.8, 2.4, BuildingCatalog.ROOF_DARK)
	# Mât devant la porte : le drapeau choisi pour le village y est hissé (Communes).
	k.box(-4.5, 0, -5.5, 0.15, 7.2, 0.15, Color("d9d9d9"))
	k.cylinder(-4.5, 7.2, -5.5, 0.12, 0.12, 0.12, 6, Color("d4af37"))
	k.box(0, 0, -6.6, 3.0, 0.05, 1.0, Color("bdb5a3"))
	if not k._fine():
		k.tree(5.5, -5.0, 0.7)
		return
	for i in 4:
		var x := -5.0 + 2.5 * (i + 0.5)
		for s in [-1.0, 1.0]:
			k.box(x + s * 0.85, 3.88, -3.08, 0.55, 1.44, 0.06, p.volet)
		k.box(x, 3.65, -3.2, 1.2, 0.22, 0.3, Color("c0623a"))
		k.box(x, 3.87, -3.2, 1.0, 0.14, 0.2, H.FLEURS[(i + k.variant) % H.FLEURS.size()])
	k.box(0, 0, 1.0, 12.3, 0.6, 8.3, p.pierre.darkened(0.12))
	H.marches(k, 0, -3.05, 1.8, 2)
	H.lampadaire(k, 2.2, -4.0, 3.2)
	H.banc(k, 4.0, -5.2)
	H.arbre_rond(k, 5.6, 0, -5.0, 0.7, H.FEUILLAGES[k.variant])
	H.massif(k, -2.6, -4.0, 2.6, 0.9, rng)


const PAL_ECOLE := [
	{"mur": "f8dfa8", "toit": "c96f4a", "accent": "2a6fdb", "cour": "d9734e"},
	{"mur": "f4f1ea", "toit": "e9b949", "accent": "e76f51", "cour": "4ea8de"},
	{"mur": "cfe6c9", "toit": "4f7a5a", "accent": "f4a261", "cour": "c96f4a"},
	{"mur": "d7e6f2", "toit": "3d6b8f", "accent": "f15bb5", "cour": "e9c46a"},
]


static func _ecole(k: BlocMesh, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var p := _pal(k, PAL_ECOLE)
	k.plate(0, 0, w, d, Color("d6d1c7"))
	k.box(-4.0, 0, -8.0, 30.0, 8.0, 12.0, p.mur)
	k.box(14.0, 0, 3.0, 10.0, 8.0, 24.0, p.mur)
	H.fenetres(k, -4.0, -8.0, 30.0, 12.0, 0, 2, 4.0, 8, 3, VITRE, 1.8, 2.0)
	H.fenetres(k, 14.0, 3.0, 10.0, 24.0, 0, 2, 4.0, 3, 6, VITRE, 1.8, 2.0)
	k.box(-4.0, 8.0, -8.0, 30.6, 0.5, 12.6, p.toit)
	k.box(14.0, 8.0, 3.0, 10.6, 0.5, 24.6, p.toit)
	k.box(-4.0, 0, -14.1, 3.0, 2.6, 0.3, p.accent)
	# Cour de récréation.
	k.plate(-5.0, 7.0, 22.0, 14.0, p.cour, 0.0, 0.1)
	if not k._fine():
		k.tree(-13.0, 11.0, 1.0)
		k.tree(2.0, 11.0, 0.9)
		return
	# Encadrements de fenêtres colorés : un bandeau par étage.
	for i in 2:
		k.box(-4.0, i * 4.0 + 0.85, -8.0, 30.2, 0.18, 12.2, p.accent)
	# Acrotère et panneaux solaires.
	H.toit_terrasse(k, -4.0, 8.5, -8.0, 30.0, 12.0, p.mur, rng, {"mode": "solaire", "acrotere": 0.6, "edicule": false})
	H.toit_terrasse(k, 14.0, 8.5, 3.0, 10.0, 24.0, p.mur, rng, {"mode": "technique", "acrotere": 0.6})
	# Entrée : marquise, enseigne « ÉCOLE », horloge.
	H.marquise(k, -4.0, 3.0, -14.0, 8.0, 2.2, p.accent, true)
	H.enseigne(k, -4.0, 5.4, -14.0, 8.0, 1.1, p.accent, Color("fbf8f0"), rng)
	H.horloge(k, 6.5, 7.0, -14.0, 0.7)
	H.marches(k, -4.0, -14.15, 3.4, 2)
	# Préau, marelle, panier de basket, bancs, arbres, clôture de la cour.
	k.box(-12.0, 3.2, 4.0, 8.0, 0.25, 4.0, p.toit)
	for x in [-15.8, -8.2]:
		for z in [2.2, 5.8]:
			k.box(x, 0.1, z, 0.2, 3.1, 0.2, Color("f4f1ea"))
	for i in 5:
		k.plate(-2.0, 5.0 + i * 0.9, 0.8, 0.8, Color("fbf8f0") if i % 2 == 0 else Color("f2c14e"), 0.1, 0.03)
	k.plate(4.0, 9.0, 0.1, 6.0, Color("fbf8f0"), 0.1, 0.03)
	k.cylinder(4.0, 0.1, 12.6, 0.08, 0.08, 3.0, 5, Color("3d4248"))
	k.box(4.0, 2.7, 12.3, 1.6, 1.0, 0.08, Color("fbf8f0"))
	k.cylinder(4.0, 2.75, 12.0, 0.25, 0.25, 0.05, 8, Color("e76f51"))
	H.arbre_rond(k, -13.0, 0.1, 11.0, 1.0, H.FEUILLAGES[0])
	H.arbre_rond(k, 2.0, 0.1, 11.0, 0.9, H.FEUILLAGES[2])
	H.banc(k, -7.0, 12.5)
	H.banc(k, -1.0, 12.5)
	for x in range(-16, 7, 2):
		k.box(float(x), 0, 14.3, 0.08, 1.4, 0.08, Color("2e3136"))
	k.box(-5.0, 1.3, 14.3, 22.0, 0.08, 0.06, Color("2e3136"))
	H.velos(k, 6.0, -13.0, 5, rng)
	H.jardiniere(k, -11.0, 0, -15.0, 4.0, 0.8, rng)
	H.jardiniere(k, 3.0, 0, -15.0, 4.0, 0.8, rng)


static func _pompiers(k: BlocMesh, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var rouge: Color = [Color("c0392b"), Color("d63d2e"), Color("b8322a"), Color("c94431")][k.variant % 4]
	var mur: Color = [Color("f1ebe0"), Color("e6d3b3"), Color("eceff1"), Color("f3e3cf")][k.variant % 4]
	k.plate(0, 0, w, d, Color("5d6066"))
	k.box(-2.0, 0, 1.5, 18.0, 7.0, 14.0, mur)
	k.box(-2.0, 7.0, 1.5, 18.4, 0.5, 14.4, rouge.darkened(0.2))
	for i in 3:
		k.box(-7.5 + i * 5.5, 0, -5.55, 4.2, 4.6, 0.2, rouge)
	k.windows_row(-2.0, -5.5, 18.0, 5.2, 6, 1.2, 1.2, VITRE)
	k.windows_col(7.0, 1.5, 12.0, 5.2, 4, 1.2, 1.2, VITRE)
	k.windows_col(-11.0, 1.5, 12.0, 1.6, 4, 1.2, 1.4, VITRE)
	k.windows_col(-11.0, 1.5, 12.0, 5.2, 4, 1.2, 1.2, VITRE)
	# Tour de séchage des tuyaux.
	k.box(8.5, 0, 4.0, 3.5, 16.0, 3.5, rouge)
	k.box(8.5, 16.0, 4.0, 4.0, 0.5, 4.0, rouge.darkened(0.25))
	if not k._fine():
		return
	# Portes sectionnelles : cadres blancs, panneaux vitrés, chiffres.
	for i in 3:
		var x := -7.5 + i * 5.5
		k.box(x, 0, -5.68, 4.6, 4.9, 0.08, Color("f4f1ea"))
		k.box(x, 0, -5.72, 4.2, 4.6, 0.06, rouge)
		for j in 5:
			k.box(x, 0.85 + j * 0.85, -5.78, 4.2, 0.05, 0.04, rouge.darkened(0.25))
		k.box(x, 3.0, -5.79, 3.6, 0.5, 0.04, Color("41505f"))
		k.box(x, 5.0, -5.68, 0.6, 0.6, 0.06, Color("f4f1ea"))
	# Bandeau « POMPIERS », gyrophare, cloche.
	H.enseigne(k, -2.0, 6.0, -5.6, 9.0, 0.8, rouge.darkened(0.3), Color("fbf8f0"), rng)
	k.cylinder(-11.0, 7.5, -5.0, 0.25, 0.25, 0.35, 8, Color("ff4d3a"))
	H.toit_terrasse(k, -2.0, 7.5, 1.5, 18.0, 14.0, mur, rng, {"mode": "technique", "acrotere": 0.5, "antenne": true})
	for i in 4:
		k.windows_row(8.5, 2.25, 2.0, 3.0 + i * 3.2, 1, 0.9, 1.3, VITRE)
	k.box(8.5, 16.5, 4.0, 3.0, 0.15, 3.0, Color("3d4248"))
	k.lathe(8.5, 16.65, 4.0, [Vector2(2.4, 0), Vector2(0.0, 1.4)], 8, rouge.darkened(0.15))
	# Lignes jaunes au sol, bornes, borne incendie, mât.
	for i in 3:
		var x := -7.5 + i * 5.5
		k.plate(x - 2.3, -7.4, 0.15, 3.6, Color("f2c14e"), 0.06, 0.02)
		k.plate(x + 2.3, -7.4, 0.15, 3.6, Color("f2c14e"), 0.06, 0.02)
	k.cylinder(9.5, 0, -6.8, 0.25, 0.25, 0.75, 8, Color("d63d2e"))
	k.cylinder(9.5, 0.75, -6.8, 0.27, 0.12, 0.2, 8, Color("d63d2e").darkened(0.2))
	k.box(9.5, 0.4, -6.8, 0.7, 0.14, 0.14, Color("c3c8ce"))
	H.drapeau(k, 10.5, -8.4, 7.0, rouge, Color("fbf8f0"))
	H.jardiniere(k, 8.5, 0, -1.0, 2.6, 0.8, rng)
	H.arbre_rond(k, 9.8, 0, 8.2, 0.6, H.FEUILLAGES[k.variant])


static func _police(k: BlocMesh, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var bleu: Color = [Color("1f3b73"), Color("234a8c"), Color("1d3557"), Color("2c4f8f")][k.variant % 4]
	var mur: Color = [Color("eef2f6"), Color("f4f1ea"), Color("e3e9ef"), Color("f2ede4")][k.variant % 4]
	var fh := 3.7
	k.plate(0, 0, w, d, Color("cfcac0"))
	k.box(0, 0, 1.0, 16.0, 7.5, 12.0, mur)
	k.box(0, 7.5, 1.0, 16.4, 0.5, 12.4, bleu)
	k.box(0, 0, 1.0, 16.1, 1.0, 12.1, bleu.lightened(0.15))
	H.trame(k, 0, 1.0, 16.0, 12.0, 0.0, 2, fh, VITRE, mur, 2.2, 0.45)
	k.box(0, 0, -5.1, 2.6, 2.8, 0.3, bleu)
	if not k._fine():
		return
	H.porte_vitree(k, 0, -5.2, 2.2, 2.6, bleu)
	H.marquise(k, 0, 3.1, -5.0, 5.0, 1.8, bleu, false)
	H.enseigne(k, 0, 5.3, -5.0, 6.0, 1.0, Color("2a6fdb"), Color("fbf8f0"), rng)
	H.marches(k, 0, -5.2, 2.6, 2)
	H.toit_terrasse(k, 0, 8.0, 1.0, 16.0, 12.0, mur, rng, {"mode": "technique", "acrotere": 0.5, "antenne": true})
	k.cylinder(-6.5, 8.0, -4.5, 0.25, 0.25, 0.35, 8, Color("3a7bff"))
	# Bornes, drapeau, parking avec voiture de patrouille.
	for x in [-2.2, -1.2, 1.2, 2.2]:
		k.cylinder(x, 0, -6.9, 0.12, 0.12, 0.8, 6, Color("2e3136"))
	H.drapeau(k, -6.8, -6.8, 7.5, bleu, Color("fbf8f0"))
	k.plate(5.8, -6.6, 4.4, 2.6, Color("5d6066"), 0.0, 0.06)
	k.box(5.8, 0.2, -6.6, 4.0, 0.7, 1.8, Color("f4f6f8"))
	k.box(5.8, 0.5, -6.6, 4.02, 0.22, 1.82, bleu)
	k.box(5.6, 0.9, -6.6, 2.1, 0.55, 1.6, Color("41505f"))
	k.box(5.6, 1.45, -6.6, 0.8, 0.12, 0.3, Color("3a7bff"))
	H.jardiniere(k, -4.5, 0, -5.8, 2.4, 0.7, rng)
	H.arbre_rond(k, -7.6, 0, 6.6, 0.6, H.FEUILLAGES[k.variant])


const PAL_HOPITAL := [
	{"mur": "f6f8fa", "accent": "2a9d8f", "vitre": "6d97b8"},
	{"mur": "f4f1ea", "accent": "3d6b8f", "vitre": "4f6d8f"},
	{"mur": "eef3f6", "accent": "4ea8de", "vitre": "6d97b8"},
	{"mur": "f5efe8", "accent": "88b04b", "vitre": "8fb8d8"},
]


static func _hopital(k: BlocMesh, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var p := _pal(k, PAL_HOPITAL)
	var rouge := Color("e63946")
	k.plate(0, 0, w, d, Color("d6d1c7"))
	# Socle (consultations, urgences), tour des chambres.
	k.box(0, 0, 4.0, 40.0, 7.0, 24.0, p.mur)
	H.trame(k, 0, 4.0, 40.0, 24.0, 0.0, 2, 3.5, p.vitre, p.mur, 2.4, 0.5)
	k.box(0, 7.0, 6.0, 24.0, 18.0, 16.0, p.mur)
	H.trame(k, 0, 6.0, 24.0, 16.0, 7.0, 5, 3.6, p.vitre, p.mur, 2.0, 0.5)
	k.box(0, 25.0, 6.0, 24.6, 0.6, 16.6, p.accent)
	# Héliport.
	k.cylinder(0, 25.6, 6.0, 6.0, 6.0, 0.15, 14, Color("4a4e55"))
	k.box(0, 25.75, 6.0, 2.6, 0.05, 0.5, Color("fbf8f0"))
	k.box(-1.05, 25.75, 6.0, 0.5, 0.05, 3.0, Color("fbf8f0"))
	k.box(1.05, 25.75, 6.0, 0.5, 0.05, 3.0, Color("fbf8f0"))
	# Hall d'entrée et croix rouge.
	k.box(0, 0, -8.6, 10.0, 4.0, 3.0, p.accent.lightened(0.55))
	H.pastille(k, 0, 23.6, -2.0, 1.6, rouge, Color("fbf8f0"), "croix")
	if not k._fine():
		return
	k.cylinder(0, 25.75, 6.0, 5.4, 5.4, 0.05, 14, Color("f2c14e"))
	k.cylinder(0, 25.76, 6.0, 5.1, 5.1, 0.05, 14, Color("4a4e55"))
	k.box(0, 25.81, 6.0, 2.6, 0.04, 0.5, Color("fbf8f0"))
	k.box(-1.05, 25.81, 6.0, 0.5, 0.04, 3.0, Color("fbf8f0"))
	k.box(1.05, 25.81, 6.0, 0.5, 0.04, 3.0, Color("fbf8f0"))
	H.trame(k, 0, -8.6, 10.0, 3.0, 0.2, 1, 3.6, Color("1d2d3c"), p.accent, 1.6, 0.8, [0, 1, 3])
	H.marquise(k, 0, 4.0, -10.1, 13.0, 2.6, p.accent, true)
	H.enseigne(k, 0, 4.4, -10.2, 8.0, 1.0, p.accent, Color("fbf8f0"), rng)
	H.porte_vitree(k, 0, -10.1, 3.2, 2.8)
	# Urgences : auvent rouge pour les ambulances sur le côté.
	k.box(17.0, 3.8, -9.6, 6.0, 0.3, 4.0, rouge)
	for x in [14.3, 19.7]:
		k.box(x, 0, -11.2, 0.2, 3.8, 0.2, Color("c3c8ce"))
	H.enseigne(k, 17.0, 4.15, -11.6, 5.0, 0.6, rouge, Color("fbf8f0"), rng)
	k.box(17.0, 0.3, -9.4, 2.0, 1.9, 4.6, Color("f4f6f8"))
	k.box(17.0, 1.1, -9.4, 2.02, 0.3, 4.62, rouge)
	# Toits techniques, croix sur le socle.
	H.toit_terrasse(k, -14.0, 7.0, 4.0, 10.0, 22.0, p.mur, rng, {"mode": "jardin", "edicule": false, "acrotere": 0.9})
	H.toit_terrasse(k, 15.0, 7.0, 6.0, 9.0, 20.0, p.mur, rng, {"mode": "technique", "edicule": false, "acrotere": 0.9})
	# Abords : parvis, jardinières, bancs, arbres, parking.
	for i in 4:
		H.jardiniere(k, -18.0 + i * 3.6, 0, -11.0, 3.0, 0.9, rng)
	H.banc(k, -6.8, -12.6)
	H.banc(k, 6.8, -12.6)
	H.arbre_rond(k, -20.5, 0, -14.5, 0.9, H.FEUILLAGES[1])
	H.arbre_rond(k, -8.8, 0, -14.8, 0.8, H.FEUILLAGES[3])
	H.arbre_rond(k, 8.8, 0, -14.8, 0.8, H.FEUILLAGES[0])
	H.lampadaire(k, -4.0, -14.8)
	H.lampadaire(k, 4.0, -14.8)
	H.parking(k, -16.0, 14.0, 12.0, 5.0, 5, rng)


static func _chateau_eau(k: BlocMesh, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var cuve: Color = [Color("e9ecef"), Color("d7e6f2"), Color("f3e3cf"), Color("dfe8d6")][k.variant % 4]
	var bande: Color = [Color("2a6fdb"), Color("2a9d8f"), Color("c8553d"), Color("4f7a5a")][k.variant % 4]
	k.plate(0, 0, w, d, Color("8c8f86"))
	k.cylinder(0, 0, 0, 1.6, 1.4, 18.0, 10, Color("c9ccd1"))
	k.lathe(0, 17.0, 0, [Vector2(1.5, 0), Vector2(4.6, 3.0), Vector2(4.8, 6.5), Vector2(4.2, 7.5), Vector2(0, 8.4)], 14, cuve)
	if not k._fine():
		return
	k.cylinder(0, 22.0, 0, 4.85, 4.85, 1.0, 14, bande)
	k.cylinder(0, 24.4, 0, 4.9, 4.9, 0.12, 14, Color("5b6068"))
	for i in 10:
		var a := TAU * i / 10.0
		k.box(cos(a) * 4.8, 24.5, sin(a) * 4.8, 0.06, 0.9, 0.06, Color("5b6068"))
	k.cylinder(0, 25.4, 0, 0.4, 0.4, 0.8, 8, Color("c9ccd1"))
	k.box(0, 0, -1.65, 0.9, 2.1, 0.1, Color("5b6068"))
	for i in 18:
		k.box(1.4, 0.4 + i, -0.6, 0.5, 0.05, 0.05, Color("8d949b"))
	H.haie(k, 0, -d / 2.0 + 0.4, w - 1.0, 0.6, 1.0)
	H.arbre_rond(k, -4.4, 0, 4.4, 0.6, H.FEUILLAGES[k.variant])


# --- Industrie --------------------------------------------------------------------------

const PAL_INDUS := [
	{"mur": "c9b38a", "toit": "5b5f66", "accent": "f2b134", "bureau": "eef2f6"},
	{"mur": "b5c4cf", "toit": "4f5d75", "accent": "e76f51", "bureau": "f4f1ea"},
	{"mur": "d8c3a5", "toit": "6b4f3a", "accent": "2a9d8f", "bureau": "eef2f6"},
	{"mur": "c7cdb6", "toit": "5d6066", "accent": "3d6b8f", "bureau": "f6ead2"},
]


static func _atelier(k: BlocMesh, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var p := _pal(k, PAL_INDUS)
	k.plate(0, 0, w, d, Color("cfcac0"))
	k.box(0, 0, 2.0, 14.0, 6.0, 15.0, p.mur)
	k.gable(0, 6.0, 2.0, 14.6, 15.6, 2.0, p.toit, false)
	k.box(-2.0, 0, -5.55, 5.0, 4.4, 0.2, Color("7d7f85"))
	k.windows_row(4.0, -5.5, 4.0, 1.2, 2, 1.4, 1.4, VITRE)
	k.windows_col(7.0, 2.0, 13.0, 3.6, 5, 1.6, 1.2, VITRE)
	k.windows_col(-7.0, 2.0, 13.0, 3.6, 5, 1.6, 1.2, VITRE)
	if not k._fine():
		return
	for j in 6:
		k.box(-2.0, 0.6 + j * 0.65, -5.7, 5.0, 0.05, 0.04, Color("6c7077"))
	k.box(-2.0, 4.4, -5.68, 5.3, 0.25, 0.12, p.accent)
	H.marquise(k, -2.0, 4.8, -5.6, 6.0, 1.6, p.toit.lightened(0.1))
	H.enseigne(k, 4.0, 3.6, -5.5, 4.6, 0.8, p.accent, Color("2e3136"), rng)
	k.box(4.0, 0, -5.68, 1.0, 2.2, 0.1, Color("3d4248"))
	for x in [-4.9, 0.9]:
		k.box(x, 0, -6.4, 0.25, 0.9, 0.25, p.accent)
	k.box(5.6, 0, 6.0, 1.6, 1.4, 2.0, Color("4f7a5a"))
	k.box(5.6, 1.4, 6.0, 1.7, 0.1, 2.1, Color("3a5a40"))
	for i in 3:
		k.box(-5.5 + i * 1.3, 0, -7.6, 1.1, 0.15, 1.1, Color("a26b3c"))
		k.box(-5.5 + i * 1.3, 0.15, -7.6, 1.0, 0.6 + 0.2 * (i % 2), 1.0, Color("c9b38a"))
	k.cylinder(-4.5, 7.6, 3.0, 0.3, 0.3, 1.4, 6, Color("8d949b"))
	k.cylinder(-4.5, 9.0, 3.0, 0.45, 0.12, 0.25, 6, Color("8d949b"))


static func _entrepot(k: BlocMesh, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var p := _pal(k, PAL_INDUS)
	k.plate(0, 0, w, d, Color("8d8f92"))
	k.box(0, 0, 4.0, 30.0, 10.0, 32.0, p.mur)
	k.gable(0, 10.0, 4.0, 30.6, 32.6, 2.2, Color("8a8d93") if k.variant % 2 == 0 else p.toit, false)
	for i in 4:
		k.box(-10.5 + i * 7.0, 0, -12.05, 4.5, 4.5, 0.2, Color("6c7077"))
	k.windows_row(0, -12.0, 28.0, 7.0, 7, 2.6, 1.0, VITRE)
	if not k._fine():
		for i in 4:
			k.plate(-10.5 + i * 7.0, -17.0, 0.2, 6.0, Color("f2f2f2"), 0.06, 0.04)
		return
	# Bardage nervuré et liseré coloré.
	for i in 15:
		k.box(-14.0 + i * 2.0, 0.45, -12.12, 0.1, 9.4, 0.06, p.mur.darkened(0.1))
	k.box(0, 9.3, -12.15, 30.2, 0.7, 0.12, p.accent)
	# Quais : portes à lames, butoirs, auvent, bornes jaunes, marquage.
	for i in 4:
		var x := -10.5 + i * 7.0
		for j in 7:
			k.box(x, 0.5 + j * 0.6, -12.2, 4.5, 0.05, 0.04, Color("55585e"))
		k.box(x - 2.0, 0.3, -12.3, 0.3, 0.5, 0.3, NOIR_C)
		k.box(x + 2.0, 0.3, -12.3, 0.3, 0.5, 0.3, NOIR_C)
		k.plate(x - 2.6, -16.0, 0.2, 7.0, Color("f2f2f2"), 0.06, 0.04)
		k.cylinder(x + 3.0, 0, -12.8, 0.15, 0.15, 1.0, 6, Color("f2c14e"))
	k.box(0, 5.0, -13.4, 30.0, 0.25, 2.6, p.toit.lightened(0.15))
	# Camion à quai.
	var cab: Color = [Color("e76f51"), Color("2a6fdb"), Color("f4f1ea"), Color("2a9d8f")][k.variant % 4]
	k.box(-3.5, 0.6, -17.0, 2.5, 3.0, 8.0, Color("eef0f2"))
	k.box(-3.5, 0.5, -21.8, 2.4, 2.8, 2.0, cab)
	k.box(-3.5, 2.0, -22.82, 2.2, 0.9, 0.05, Color("41505f"))
	# Bureaux accolés (pignon droit) et enseigne.
	k.box(13.0, 0, -9.0, 4.0, 6.0, 6.0, p.bureau)
	k.windows_row(13.0, -12.0, 3.6, 0.9, 2, 1.2, 1.4, VITRE)
	k.windows_row(13.0, -12.0, 3.6, 3.6, 2, 1.2, 1.4, VITRE)
	k.box(13.0, 6.0, -9.0, 4.3, 0.25, 6.3, p.accent)
	H.enseigne(k, -1.0, 7.4, -12.1, 12.0, 1.4, p.accent, Color("2e3136"), rng)
	H.toit_terrasse(k, 13.0, 6.25, -9.0, 4.0, 6.0, p.bureau, rng, {"mode": "technique", "edicule": false, "acrotere": 0.4})
	for i in 5:
		k.box(-12.0 + i * 6.0, 10.9, 4.0, 1.4, 0.4, 20.0, Color("bfe0ea"))
	H.arbre_rond(k, 14.0, 0, -14.5, 0.7, H.FEUILLAGES[k.variant])


const NOIR_C := Color("2e3136")


static func _usine(k: BlocMesh, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var p := _pal(k, PAL_INDUS)
	var brique := k.variant % 2 == 0
	var mur: Color = Color("b8664a") if brique else p.mur
	k.plate(0, 0, w, d, Color("8d8f92"))
	k.box(-3.0, 0, 2.0, 36.0, 9.0, 28.0, mur)
	for i in 6:
		var sx := -18.0 + i * 6.0
		k.gable(sx, 9.0, 2.0, 6.0, 28.4, 3.0, p.toit, false)
		if k._fine():
			# Verrières des sheds (face nord, +Z… vue de face : une bande claire).
			k.box(sx + 1.6, 9.2, 2.0, 0.08, 2.4, 27.0, Color("bfe0ea"))
	k.box(-3.0, 0, -12.05, 6.0, 5.0, 0.2, Color("55585e"))
	k.windows_row(-3.0, -12.0, 34.0, 4.4, 10, 1.6, 2.2, VITRE)
	k.cylinder(18.5, 0, 12.0, 1.6, 1.2, 30.0, 8, Color("b0413e") if brique else Color("c9ccd1"))
	k.cylinder(18.5, 26.0, 12.0, 1.3, 1.3, 1.5, 8, Color("eeeeee"))
	k.cylinder(18.5, 0, -6.0, 2.6, 2.6, 12.0, 10, Color("d9d9d9"))
	k.cylinder(18.5, 12.0, -6.0, 2.6, 0.0, 1.5, 10, Color("a5a5a5"))
	if not k._fine():
		return
	k.anchor("fumee", Vector3(18.5, 30.2, 12.0))
	k.cylinder(18.5, 20.0, 12.0, 1.36, 1.36, 0.8, 8, p.accent)
	k.cylinder(18.5, 0, -2.0, 2.0, 2.0, 9.0, 10, p.accent.lightened(0.2))
	k.cylinder(18.5, 9.0, -2.0, 2.0, 0.0, 1.2, 10, Color("a5a5a5"))
	# Passerelle et tuyaux entre les silos et le hall.
	k.box(16.2, 8.0, -4.0, 2.6, 0.5, 0.5, Color("8d949b"))
	k.box(17.0, 3.5, 2.0, 0.4, 0.4, 20.0, p.accent)
	k.box(17.0, 5.2, 2.0, 0.3, 0.3, 20.0, Color("8d949b"))
	for z in [-6.0, -1.0, 4.0, 9.0]:
		k.box(17.0, 0, z, 0.2, 5.4, 0.2, Color("5b6068"))
	# Bureaux de l'usine (avant gauche), enseigne, porte à lames.
	for j in 6:
		k.box(-3.0, 0.6 + j * 0.7, -12.18, 6.0, 0.05, 0.04, Color("3d4248"))
	H.enseigne(k, -3.0, 6.8, -12.0, 14.0, 1.4, p.accent, Color("2e3136"), rng)
	k.box(-3.0, 9.0, 2.0, 36.4, 0.3, 28.4, mur.darkened(0.15))
	k.box(-3.0, 0, 2.0, 36.2, 0.8, 28.2, Color("6b6e73"))
	# Cour : palettes, bennes, conteneurs colorés, bornes.
	var conts := [Color("c8553d"), Color("2a6fdb"), Color("2a9d8f"), Color("e9b949")]
	for i in 3:
		k.box(-19.0 + i * 3.0, 0, -15.0, 2.4, 2.6, 6.0, conts[(i + k.variant) % 4])
	for i in 4:
		k.box(6.0 + i * 1.4, 0, -14.5, 1.2, 0.15, 1.2, Color("a26b3c"))
		k.box(6.0 + i * 1.4, 0.15, -14.5, 1.1, 0.5 + 0.3 * (i % 2), 1.1, Color("d8c3a5"))
	for x in [-6.4, 0.4]:
		k.cylinder(x, 0, -12.7, 0.15, 0.15, 1.0, 6, Color("f2c14e"))
	for i in 3:
		k.box(-14.0 + i * 8.0, 9.3, 8.0, 2.0, 1.0, 1.6, Color("d9dcdf"))
	H.arbre_rond(k, 14.0, 0, -15.0, 0.7, H.FEUILLAGES[k.variant])
