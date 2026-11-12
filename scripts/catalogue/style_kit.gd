class_name StyleKit
extends RefCounted
## Petits détails modelés des bâtiments de la bible, style par style : volets,
## jardinières, cheminées (avec leur point de fumée), gouttières et descentes,
## enseignes, auvents rayés, garde-corps, colombages en croix, lanternes,
## moucharabiehs, climatiseurs, antennes, panneaux solaires, réservoirs d'eau,
## balcons modernes, marches devant la porte.
##
## Appelé par StyleBuilder seulement quand les finitions sont actives (la
## version vue de loin s'en passe). Repère local du bâtiment : sol en y = 0,
## façade (porte) vers −Z.

## Couleurs de volets par région.
const VOLETS := {
	"europe": ["3d6b4f", "2f4f6f", "7a2e2e", "d8cfb8", "5b7f8f", "6b8e5a", "8a6a3a"],
	"mediterranee": ["2f6f9f", "3d7a5a", "8a9a5b", "4f86b0", "6fa8c7"],
	"ameriques": ["2b2b2b", "3d5a80", "f2efe6", "6b2e2e", "3d6b4f"],
	"oceanie": ["3d6b4f", "f2efe6", "2f4f6f"],
}
## Couleurs d'enseignes et d'auvents.
const ENSEIGNES := ["8c2f39", "1f5f5b", "2f4f8f", "c9822b", "3d6b2f", "6b2e5f", "b5432f", "24476b"]

const BRIQUE := Color("8c4a3a")
const ZINC := Color("8d949b")
const CUIVRE := Color("9a6a45")
const BOIS := Color("6b4a2b")
const FLEURS := [Color("d23b48"), Color("e86fa0"), Color("f2efe6"), Color("e8a33b"), Color("b04ad0")]


## Que porte ce style ? Une clé du style (Styles.STYLES) peut forcer un réglage.
static func flags(s: Dictionary, sid: String, arch: String) -> Dictionary:
	var era: String = s.era
	var reg: String = s.region
	var trad := era in ["traditionnel", "classique"]
	var house := arch in ["maison", "grande_maison", "rangee"]
	var resid := house or arch == "immeuble"
	var pente := String(s.roof) in ["gable", "hip", "mansard", "shed"]
	var f := {
		"volets": trad and reg in ["europe", "mediterranee", "ameriques", "oceanie"] and resid
			and not bool(s.get("balcony", false)) and sid not in ["gothique", "latino", "far_west", "art_deco"],
		"jardinieres": trad and reg == "europe" and resid and sid not in ["briques_ind", "gothique"],
		"cheminee": pente and era != "futuriste" and era != "antique"
			and reg in ["europe", "ameriques", "oceanie", "moyen_orient"]
			and (resid or arch in ["ferme", "restaurant", "boutique", "ecole"]),
		"gouttieres": pente and era not in ["antique"] and sid not in ["isba", "polynesien", "maori"],
		"enseigne": arch in ["boutique", "restaurant", "grand_magasin", "atelier"],
		"croix": bool(s.get("timber", false)),
		"lanternes": sid in ["chinois", "japonais", "coreen"] and arch in ["maison", "grande_maison", "rangee", "boutique", "restaurant"],
		"moucharabieh": sid in ["maghreb", "persan", "indien", "ottoman", "swahili"] and arch in ["maison", "grande_maison", "rangee", "boutique", "restaurant"],
		"clim": era in ["moderne", "contemporain"] and String(s.roof) == "flat",
		"clim_facade": sid in ["asie_dense", "afrique_moderne", "golfe", "sovietique"] and arch in ["immeuble", "rangee", "tour", "boutique"],
		"antennes": era in ["classique", "moderne"] and resid and reg != "asie_est",
		"solaire": era == "contemporain" and house,
		"reservoir": sid == "art_deco" and arch in ["immeuble", "tour"],
		"balcons": era in ["moderne", "contemporain"] and arch in ["immeuble", "tour"] and sid not in ["verre"],
		"perron": arch in ["maison", "grande_maison", "rangee", "immeuble", "boutique", "restaurant", "ecole", "bureaux"],
	}
	for key in f:
		if s.has("kit_" + key):
			f[key] = bool(s["kit_" + key])
	return f


static func build(k: BlocMesh, s: Dictionary, p: Dictionary, arch: String, bw: float, bd: float, cz: float,
		y0: float, top: float, tw: float, td: float, roof: String, floors: int, fh: float) -> void:
	var vr: RandomNumberGenerator = p.vr
	var sid: String = p.get("style_id", "")
	var f := flags(s, sid, arch)
	var fz := cz - bd / 2.0
	var pitch := float(s.get("pitch", 0.5)) * float(p.get("pente", 1.0))
	if f.croix:
		_croix(k, p, bw, fz, y0, top, fh, vr)
	if f.perron and y0 < 0.05:
		var pierre := Color("a39d92")
		if arch == "rangee":
			for i in 4:
				k.box(-bw / 2.0 + (i + 0.5) * bw / 4.0, 0, fz - 0.45, 1.6, 0.16, 0.7, pierre)
		else:
			k.box(0, 0, fz - 0.5, 2.0, 0.16, 0.8, pierre)
			k.box(0, 0, fz - 0.3, 1.6, 0.3, 0.4, pierre.lightened(0.05))
	if f.gouttieres and roof in ["gable", "hip", "mansard", "shed"]:
		_gouttieres(k, roof, tw, td, cz, y0, top, ZINC if vr.randf() < 0.7 else CUIVRE)
	if f.cheminee and roof in ["gable", "hip", "mansard"]:
		_cheminees(k, s, p, sid, arch, roof, tw, td, cz, top, pitch, vr)
	if f.enseigne:
		_enseigne(k, s, p, bw, fz, y0, vr)
	if f.lanternes:
		for x in [-1.3, 1.3]:
			k.box(x, y0 + 2.75, fz - 0.55, 0.05, 0.35, 0.05, Color("2b2b2b"))
			k.cylinder(x, y0 + 2.2, fz - 0.55, 0.2, 0.22, 0.55, 6, Color("c0392b"))
			k.box(x, y0 + 2.15, fz - 0.55, 0.3, 0.06, 0.3, Color("2b2b2b"))
	if f.moucharabieh and floors >= 2:
		var n := 1 if bw < 10.0 else 2
		for i in n:
			var x := (0.0 if n == 1 else (-bw / 4.0 + i * bw / 2.0)) + vr.randf_range(-0.5, 0.5)
			var y := y0 + fh + 0.3
			k.box(x, y, fz - 0.35, 1.8, 2.0, 0.6, BOIS)
			for j in 4:
				k.box(x, y + 0.3 + j * 0.42, fz - 0.67, 1.7, 0.08, 0.06, BOIS.darkened(0.3))
			k.box(x, y + 2.0, fz - 0.4, 2.0, 0.15, 0.7, BOIS.darkened(0.15))
	if f.clim and arch not in ["maison"]:
		var n := clampi(int(tw * td / 120.0), 1, 5)
		for i in n:
			var x := vr.randf_range(-tw * 0.35, tw * 0.35)
			var z := cz + vr.randf_range(-td * 0.35, td * 0.35)
			k.box(x, top + 0.25, z, 1.2, 0.8, 0.9, Color("c9ccd1"))
			k.cylinder(x, top + 1.05, z, 0.35, 0.35, 0.04, 8, Color("3a3d42"))
	if f.clim_facade:
		for i in range(1, mini(floors, 12)):
			if vr.randf() < 0.55:
				var x := vr.randf_range(-bw * 0.4, bw * 0.4)
				k.box(x, y0 + i * fh + 0.2, fz - 0.3, 0.8, 0.55, 0.45, Color("dcdcd6"))
	if f.antennes:
		if vr.randf() < 0.6:
			var x := vr.randf_range(-tw * 0.3, tw * 0.3)
			var base := top + (minf(tw, td) / 2.0 * pitch if roof in ["gable", "hip"] else 0.25)
			k.box(x, base - 0.2, cz, 0.06, 2.2, 0.06, Color("6b6e73"))
			k.box(x, base + 1.6, cz, 1.2, 0.04, 0.04, Color("6b6e73"))
			k.box(x, base + 1.2, cz, 0.8, 0.04, 0.04, Color("6b6e73"))
	if f.solaire and roof == "flat":
		_solaire(k, tw, td, cz, top)
	if f.reservoir and roof == "flat":
		var x := tw * 0.25
		var z := cz + td * 0.2
		for ox in [-0.9, 0.9]:
			for oz in [-0.9, 0.9]:
				k.box(x + ox, top + 0.25, z + oz, 0.18, 2.0, 0.18, BOIS.darkened(0.2))
		k.cylinder(x, top + 2.25, z, 1.5, 1.5, 2.6, 10, Color("8a6440"))
		k.lathe(x, top + 4.85, z, [Vector2(1.6, 0), Vector2(0, 1.0)], 10, Color("4f4a44"))
	if f.balcons and floors >= 3:
		var cols := maxi(1, int(bw / 6.0))
		var rail := Color("b8c2c9") if s.era == "contemporain" else Color(p.wall).lightened(0.1)
		for i in range(1, floors):
			for c in cols:
				if (c + i + k.variant) % 2 == 1:
					continue
				var x := -bw / 2.0 + (c + 0.5) * bw / cols
				var y := y0 + i * fh
				k.box(x, y - 0.1, fz - 0.6, 3.2, 0.15, 1.2, Color(p.wall).darkened(0.08))
				k.box(x, y + 0.05, fz - 1.15, 3.2, 1.0, 0.1, rail)
				k.box(x - 1.55, y + 0.05, fz - 0.6, 0.1, 1.0, 1.1, rail)
				k.box(x + 1.55, y + 0.05, fz - 0.6, 0.1, 1.0, 1.1, rail)


## Volets ouverts et jardinières autour des fenêtres d'une façade ±Z
## (mêmes positions que BlocMesh.windows_row). side = −1 devant, +1 derrière.
static func fenetres(k: BlocMesh, s: Dictionary, p: Dictionary, cx: float, z: float, width: float, y: float,
		count: int, wh: float, floor_i: int, side: float) -> void:
	var f := flags(s, String(p.get("style_id", "")), String(p.get("arch", "")))
	if not (f.volets or f.jardinieres):
		return
	var volets: bool = f.volets
	var vr: RandomNumberGenerator = p.vr
	var step := width / count
	var col: Color = p.get("volet", Color("3d6b4f"))
	var zz := z + side * 0.1
	for i in count:
		var x := cx - width / 2.0 + step * (i + 0.5)
		if volets:
			for sx in [-0.76, 0.76]:
				k.box(x + sx, y - 0.02, zz, 0.48, wh + 0.04, 0.06, col)
				k.box(x + sx, y + wh * 0.5 - 0.03, zz + side * 0.035, 0.44, 0.06, 0.02, col.darkened(0.2))
		if f.jardinieres and side < 0.0 and vr.randf() < 0.45:
			k.box(x, y - 0.42, z - 0.22, 1.05, 0.24, 0.3, Color("6b4a2b"))
			var fl: Color = FLEURS[vr.randi() % FLEURS.size()]
			for j in 4:
				k.box(x - 0.39 + j * 0.26, y - 0.18, z - 0.22, 0.2, 0.16, 0.22, fl if j % 2 == 0 else fl.lightened(0.15))
			k.box(x, y - 0.2, z - 0.22, 1.0, 0.06, 0.26, Color("3f7a35"))


## Garde-corps à barreaux le long d'un balcon (façade ±Z).
static func garde_corps(k: BlocMesh, cx: float, y: float, z: float, width: float, col: Color) -> void:
	var n := maxi(2, int(width / 0.55))
	for i in n + 1:
		k.box(cx - width / 2.0 + i * width / n, y, z, 0.05, 0.85, 0.05, col)
	k.box(cx, y + 0.85, z, width, 0.07, 0.09, col)
	k.box(cx, y + 0.1, z, width, 0.05, 0.05, col)


## Auvent rayé en pente au-dessus d'une vitrine (façade −Z en z_face).
static func auvent(k: BlocMesh, cx: float, y: float, z_face: float, width: float, depth: float, c1: Color, c2: Color) -> void:
	var n := maxi(3, int(width / 0.6))
	var sw := width / n
	var hi := y + 0.55
	var lo := y - 0.05
	var zo := z_face - depth
	for i in n:
		var x0 := cx - width / 2.0 + i * sw
		var x1 := x0 + sw
		var col := c1 if i % 2 == 0 else c2
		k.panel(Vector3(x0, hi, z_face), Vector3(x1, hi, z_face), Vector3(x1, lo, zo), Vector3(x0, lo, zo), Vector3(0, 1, -1), col)
		k.panel(Vector3(x0, hi - 0.03, z_face), Vector3(x1, hi - 0.03, z_face), Vector3(x1, lo - 0.03, zo), Vector3(x0, lo - 0.03, zo), Vector3(0, -1, 0.5), col.darkened(0.25))
		# Lambrequin (bord qui pend), festonné.
		k.box((x0 + x1) / 2.0, lo - 0.28, zo, sw, 0.28 if i % 2 == 0 else 0.22, 0.03, col)
	# Joues latérales.
	for x in [cx - width / 2.0, cx + width / 2.0]:
		k.tri(Vector3(x, hi, z_face), Vector3(x, lo, zo), Vector3(x, lo, z_face), Vector3.LEFT if x < cx else Vector3.RIGHT, c1.darkened(0.15))


## Colombages en croix de Saint-André entre les poteaux de la façade.
static func _croix(k: BlocMesh, p: Dictionary, bw: float, fz: float, y0: float, top: float, fh: float, vr: RandomNumberGenerator) -> void:
	var trim: Color = p.trim
	var n := int(bw / 1.6)
	if n < 2:
		return
	var step := bw / n
	var z := fz - 0.115
	var floors := int((top - y0) / fh + 0.01)
	for j in floors:
		var ya := y0 + j * fh + 0.11
		var yb := y0 + (j + 1) * fh - 0.11
		for i in n:
			# Une travée sur trois, en évitant le milieu (porte, fenêtres).
			if (i + j + k.variant) % 3 != 0 or absf(-bw / 2.0 + (i + 0.5) * step) < 1.4:
				continue
			var xa := -bw / 2.0 + i * step + 0.11
			var xb := xa + step - 0.22
			var t := 0.09
			if vr.randf() < 0.5:
				k.panel(Vector3(xa, ya, z), Vector3(xa + t * 2.0, ya, z), Vector3(xb, yb, z), Vector3(xb - t * 2.0, yb, z), Vector3.FORWARD, trim)
				k.panel(Vector3(xb, ya, z), Vector3(xb - t * 2.0, ya, z), Vector3(xa, yb, z), Vector3(xa + t * 2.0, yb, z), Vector3.FORWARD, trim)
			else:
				k.panel(Vector3(xa, ya, z), Vector3(xa + t * 2.0, ya, z), Vector3(xb, yb, z), Vector3(xb - t * 2.0, yb, z), Vector3.FORWARD, trim)


## Gouttières sous les bords du toit et descentes aux angles.
static func _gouttieres(k: BlocMesh, roof: String, tw: float, td: float, cz: float, y0: float, top: float, col: Color) -> void:
	var along_x := tw >= td
	var over := 0.4 if roof in ["gable", "shed"] else (0.5 if roof == "hip" else 0.0)
	var y := top + (0.3 if roof == "mansard" else 0.0)
	var ex := tw / 2.0 + over
	var ez := td / 2.0 + over
	var sides := []
	if roof in ["gable", "shed"]:
		sides = ["z"] if along_x else ["x"]
	else:
		sides = ["z", "x"]
	for sd in sides:
		for sg in [-1.0, 1.0]:
			if sd == "z":
				k.box(0, y - 0.16, cz + sg * ez, tw + 2.0 * over, 0.14, 0.16, col)
				var px := (tw / 2.0 - 0.25) * (1.0 if sg > 0 else -1.0)
				k.box(px, y0 + 0.1, cz + sg * (td / 2.0 + 0.08), 0.1, y - y0 - 0.2, 0.1, col)
				k.box(px, y - 0.2, cz + sg * (td / 2.0 + ez) / 2.0 + sg * 0.04, 0.1, 0.1, ez - td / 2.0, col)
			else:
				k.box(sg * ex, y - 0.16, cz, 0.16, 0.14, td + 2.0 * over, col)
				var pz := cz + (td / 2.0 - 0.25) * (-1.0 if sg > 0 else 1.0)
				k.box(sg * (tw / 2.0 + 0.08), y0 + 0.1, pz, 0.1, y - y0 - 0.2, 0.1, col)


## Cheminées sur le toit, avec leur point de fumée (ancre « fumee »).
static func _cheminees(k: BlocMesh, s: Dictionary, p: Dictionary, sid: String, arch: String, roof: String,
		tw: float, td: float, cz: float, top: float, pitch: float, vr: RandomNumberGenerator) -> void:
	var along_x := tw >= td
	var long := maxf(tw, td)
	var short := minf(tw, td)
	var ridge := top + short / 2.0 * pitch
	if roof == "mansard":
		ridge = top + 0.3 + 3.0 + 0.8
	var brick := sid in ["colombages", "tudor", "hollandais", "briques_ind", "colonial", "banlieue_us", "haussmann", "australien"]
	var col: Color = BRIQUE if brick else Color(p.wall).darkened(0.18)
	var spots: Array[float] = []
	match arch:
		"rangee":
			for i in range(1, 4):
				spots.append(-long / 2.0 + i * long / 4.0)
		"immeuble", "grande_maison", "ecole":
			spots = [-long * 0.3, long * 0.3]
		_:
			spots = [long * (0.28 if vr.randf() < 0.5 else -0.28) * vr.randf_range(0.6, 1.0)]
	var off := short * (0.0 if vr.randf() < 0.5 else 0.16)
	for a in spots:
		var x := a if along_x else off
		var z := cz + (off if along_x else a)
		var h := ridge - top + 0.9
		k.box(x, top, z, 0.75, h, 0.85, col)
		k.box(x, top + h, z, 0.95, 0.12, 1.05, col.darkened(0.25))
		k.cylinder(x, top + h + 0.12, z, 0.13, 0.11, 0.3, 6, Color("9a5a40"))
		k.anchor("fumee", Vector3(x, top + h + 0.45, z))


## Enseigne au-dessus de la vitrine, et potence suspendue pour les styles anciens.
static func _enseigne(k: BlocMesh, s: Dictionary, p: Dictionary, bw: float, fz: float, y0: float, vr: RandomNumberGenerator) -> void:
	var col: Color = p.get("enseigne", Color("8c2f39"))
	var w := minf(bw * 0.6, 8.0)
	k.box(0, y0 + 3.12, fz - 0.12, w + 0.2, 0.62, 0.1, col.darkened(0.35))
	k.box(0, y0 + 3.17, fz - 0.17, w, 0.52, 0.06, col)
	# Lettres claires stylisées.
	var n := int(w / 0.7)
	for i in n:
		if vr.randf() < 0.85:
			k.box(-w / 2.0 + 0.35 + i * (w - 0.7) / maxf(n - 1, 1), y0 + 3.26, fz - 0.21, 0.36, 0.3 if i % 3 else 0.34, 0.03, Color("f2ede1"))
	if s.era in ["traditionnel", "classique", "antique"]:
		var x := bw / 2.0 - 0.6
		k.box(x, y0 + 4.0, fz - 0.5, 0.06, 0.06, 0.95, Color("2b2b2b"))
		k.box(x, y0 + 3.95, fz - 0.95, 0.04, 0.12, 0.04, Color("2b2b2b"))
		k.box(x, y0 + 3.25, fz - 0.95, 0.07, 0.7, 0.7, col.lightened(0.1))
		k.box(x, y0 + 3.4, fz - 0.95, 0.08, 0.4, 0.4, Color("e8c66a"))


## Panneaux solaires inclinés sur une terrasse.
static func _solaire(k: BlocMesh, tw: float, td: float, cz: float, top: float) -> void:
	var rows := clampi(int(td / 3.0), 1, 3)
	var cols := clampi(int(tw / 2.2), 1, 4)
	var col := Color("1d2b4a")
	for r in rows:
		for c in cols:
			var x := -tw * 0.35 + (c + 0.5) * tw * 0.7 / cols
			var z := cz - td * 0.3 + r * td * 0.6 / maxf(rows, 1)
			var x0 := x - 0.9
			var x1 := x + 0.9
			k.panel(Vector3(x0, top + 0.35, z - 0.5), Vector3(x1, top + 0.35, z - 0.5), Vector3(x1, top + 0.95, z + 0.5),
				Vector3(x0, top + 0.95, z + 0.5), Vector3(0, 1, -0.6), col)
			k.box(x, top + 0.25, z + 0.4, 0.1, 0.7, 0.1, Color("8d949b"))
