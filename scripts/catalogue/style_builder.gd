class_name StyleBuilder
extends RefCounted
## Fabrique des bâtiments low-poly à partir d'un style (région, époque) et
## d'un archétype (maison, immeuble, lieu de culte…). Chaque combinaison donne
## un type de catalogue avec son emprise, ses chiffres et son modèle 3D.
##
## Repère local : sol en y = 0, centré sur (0, 0), façade (porte) vers −Z.

## Emprise (w le long de la façade, d en profondeur) par archétype.
const SIZES := {
	"maison": Vector2i(10, 12), "grande_maison": Vector2i(18, 20), "rangee": Vector2i(26, 12),
	"immeuble": Vector2i(20, 16), "tour": Vector2i(22, 22), "gratte_ciel": Vector2i(34, 34),
	"boutique": Vector2i(9, 12), "marche": Vector2i(30, 24), "grand_magasin": Vector2i(42, 36),
	"bureaux": Vector2i(24, 20), "atelier": Vector2i(14, 18), "usine": Vector2i(40, 30),
	"entrepot": Vector2i(30, 40), "ferme": Vector2i(28, 24), "culte": Vector2i(24, 36),
	"palais": Vector2i(44, 38), "ecole": Vector2i(34, 26), "hopital": Vector2i(40, 34),
	"gare": Vector2i(50, 26), "restaurant": Vector2i(12, 14), "theatre": Vector2i(30, 36),
	"jardin": Vector2i(30, 30),
}

## Prix de base par archétype (€), multiplié selon l'époque.
const BASE_COST := {
	"maison": 250_000, "grande_maison": 700_000, "rangee": 1_000_000, "immeuble": 2_600_000,
	"tour": 12_000_000, "gratte_ciel": 60_000_000, "boutique": 300_000, "marche": 1_500_000,
	"grand_magasin": 7_000_000, "bureaux": 9_000_000, "atelier": 500_000, "usine": 6_000_000,
	"entrepot": 2_000_000, "ferme": 800_000, "culte": 3_000_000, "palais": 15_000_000,
	"ecole": 5_000_000, "hopital": 22_000_000, "gare": 9_000_000, "restaurant": 400_000,
	"theatre": 6_000_000, "jardin": 250_000,
}

const ERA_COST := {"antique": 0.8, "traditionnel": 0.9, "classique": 1.0, "moderne": 1.0, "contemporain": 1.3, "futuriste": 1.8}


## Tous les types générés : id -> entrée de catalogue.
static func generate() -> Dictionary:
	var out := {}
	for sid in Styles.STYLES:
		var s: Dictionary = Styles.STYLES[sid]
		for arch in s.archs:
			var id := "%s__%s" % [sid, arch]
			out[id] = make_entry(sid, arch)
	return out


static func make_entry(sid: String, arch: String) -> Dictionary:
	var s: Dictionary = Styles.STYLES[sid]
	var a: Dictionary = Styles.ARCHETYPES[arch]
	var size: Vector2i = _size(s, arch)
	var floors := floors_of(s, arch)
	var e := {
		"name": String(s.get("names", {}).get(arch, "%s (%s)" % [a.name, String(s.name).to_lower()])),
		"cat": a.cat, "w": size.x, "d": size.y, "style": sid, "arch": arch,
		"region": s.region, "era": s.era,
		"access": ["route"] if a.cat in ["industrie", "commerce"] or arch in ["hopital", "gare", "tour", "immeuble"] else ["route", "chemin"],
		"cost": int(BASE_COST[arch] * float(ERA_COST.get(s.era, 1.0))),
		"desc": "%s · %s · %s" % [s.name, Styles.region_name(s.region), Styles.era_name(s.era)],
	}
	match arch:
		"maison":
			e.logements = 1
		"grande_maison":
			e.logements = 2
		"rangee":
			e.logements = 4 * maxi(1, floors - 1)
		"immeuble", "tour":
			e.logements = floors * (4 if arch == "immeuble" else 6)
		"boutique", "restaurant":
			e.emplois = 4
			e.visiteurs = 120
		"marche":
			e.emplois = 30
			e.visiteurs = 800
		"grand_magasin":
			e.emplois = 80
			e.visiteurs = 2500
		"bureaux":
			e.emplois = floors * 25
		"gratte_ciel":
			e.emplois = floors * 60
		"atelier":
			e.emplois = 10
		"usine":
			e.emplois = 120
		"entrepot":
			e.emplois = 30
		"ferme":
			e.emplois = 4
			e.logements = 1
		"culte", "jardin":
			e.visiteurs = 300
		"palais", "theatre":
			e.emplois = 40
			e.visiteurs = 600
		"ecole":
			e.emplois = 25
			e.visiteurs = 300
		"hopital":
			e.emplois = 400
		"gare":
			e.emplois = 60
			e.visiteurs = 3000
	return e


static func _size(s: Dictionary, arch: String) -> Vector2i:
	var v: Vector2i = SIZES[arch]
	if arch == "maison" and s.roof == "thatch":
		return Vector2i(10, 10)
	if arch == "maison" and s.get("stilts", false):
		return Vector2i(10, 12)
	if arch == "culte":
		match String(s.culte):
			"pagode", "sanctuaire", "temple_shikhara", "stavkirke":
				return Vector2i(24, 24)
			"mosquee_dome", "mosquee_minaret", "mosquee_terre", "wat":
				return Vector2i(34, 34)
			"cathedrale", "cathedrale_baroque":
				return Vector2i(30, 56)
			"temple_grec":
				return Vector2i(22, 40)
			"pyramide":
				return Vector2i(40, 40)
	if arch == "gratte_ciel" and s.era == "classique":
		return Vector2i(30, 30)
	if arch == "theatre" and s.era == "antique":
		return Vector2i(50, 40)
	return v


static func floors_of(s: Dictionary, arch: String) -> int:
	var era: String = s.era
	match arch:
		"maison":
			return 1 if era in ["antique", "futuriste"] or s.roof == "thatch" else 2
		"grande_maison":
			return 2
		"rangee":
			return 3 if era in ["classique", "contemporain"] else 2
		"immeuble":
			var by_era := {"traditionnel": 4, "classique": 6, "moderne": 9, "contemporain": 8, "futuriste": 12}
			return int(by_era.get(era, 5))
		"tour":
			return {"classique": 14, "moderne": 18, "contemporain": 26, "futuriste": 34}.get(era, 16)
		"gratte_ciel":
			return {"classique": 40, "contemporain": 60, "futuriste": 90}.get(era, 50)
		"bureaux":
			return {"classique": 5, "moderne": 8, "contemporain": 12, "futuriste": 14}.get(era, 6)
		"boutique", "restaurant", "atelier":
			return 2 if era != "contemporain" else 1
		"hopital":
			return 4 if era in ["moderne", "contemporain", "futuriste"] else 3
		"ecole", "palais":
			return 2
	return 1


# --- Modèles --------------------------------------------------------------------------

static func build(k: BlocMesh, t: Dictionary) -> void:
	var s: Dictionary = Styles.STYLES[t.style]
	var arch: String = t.arch
	var w := float(t.w)
	var d := float(t.d)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(t.style) + arch)
	var p := _palette(s, rng)
	_variante(k, s, p, String(t.style), arch)
	match arch:
		"culte":
			_culte(k, s, p, w, d)
		"palais":
			_palais(k, s, p, w, d)
		"jardin":
			_jardin(k, s, p, w, d)
		"marche":
			_marche(k, s, p, w, d)
		"ferme":
			_ferme(k, s, p, w, d)
		"theatre":
			if s.era == "antique":
				_amphitheatre(k, p, w, d)
			else:
				_generic(k, s, p, arch, w, d, rng)
		"maison":
			if s.roof == "thatch" or t.style == "sahel":
				_case_ronde(k, s, p, w, d)
			else:
				_generic(k, s, p, arch, w, d, rng)
		"grande_maison":
			if t.style == "sahel" or t.style == "afrique_sud":
				_concession(k, s, p, w, d)
			else:
				_generic(k, s, p, arch, w, d, rng)
		_:
			_generic(k, s, p, arch, w, d, rng)


static func _palette(s: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var walls: Array = s.walls
	var roofs: Array = s.roofs
	return {
		"wall": Color(walls[rng.randi() % walls.size()]),
		"roof": Color(roofs[rng.randi() % roofs.size()]),
		"trim": Color(s.trim),
		"glass": Color(s.get("glass", "33495e")),
		"door": Color("5a3a22"),
		"ground": Color("b9b6ae") if s.era in ["moderne", "contemporain", "futuriste", "classique"] else Color("a89b80"),
	}


## Variante : la variante 0 garde le modèle de base ; les autres changent les
## teintes des murs et du toit, le nombre de fenêtres et la pente du toit.
## Les couleurs des petits détails (volets, enseigne) dépendent aussi de la variante.
static func _variante(k: BlocMesh, s: Dictionary, p: Dictionary, sid: String, arch: String) -> void:
	var vr := RandomNumberGenerator.new()
	vr.seed = hash("%s|%s|%d" % [sid, arch, k.variant])
	p["vr"] = vr
	p["style_id"] = sid
	p["arch"] = arch
	var volets: Array = StyleKit.VOLETS.get(String(s.region), StyleKit.VOLETS["europe"])
	p["volet"] = Color(volets[vr.randi() % volets.size()])
	p["enseigne"] = Color(StyleKit.ENSEIGNES[vr.randi() % StyleKit.ENSEIGNES.size()])
	if k.variant == 0:
		return
	var walls: Array = s.walls
	var roofs: Array = s.roofs
	var wall := Color(walls[vr.randi() % walls.size()])
	var f := vr.randf_range(0.95, 1.04)
	p["wall"] = Color(minf(wall.r * f, 1.0), minf(wall.g * f, 1.0), minf(wall.b * f, 1.0))
	p["roof"] = Color(roofs[vr.randi() % roofs.size()]).darkened(vr.randf_range(-0.06, 0.08))
	p["dn"] = vr.randi_range(-1, 1)
	p["pente"] = vr.randf_range(0.85, 1.15)


## Hauteur d'étage du style.
static func _fh(s: Dictionary) -> float:
	return float(s.get("floor_h", 3.0))


## Bâtiment générique : volume, fenêtres selon l'époque, toit selon le style, ornements.
static func _generic(k: BlocMesh, s: Dictionary, p: Dictionary, arch: String, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var floors := floors_of(s, arch)
	var fh := _fh(s)
	var era: String = s.era
	var bw := w - 2.0
	var bd := d - 2.0
	var cz := 0.0
	var y0 := 0.0
	# Abords.
	if arch in ["grand_magasin", "usine", "entrepot", "hopital", "ecole", "gare", "bureaux", "tour", "gratte_ciel"]:
		k.plate(0, 0, w, d, p.ground)
	if arch in ["maison", "grande_maison"]:
		k.plate(0, 0, w, d, Color("6aa84f"))
		bd = d - 5.0
		cz = -1.5
	if arch == "grand_magasin":
		bd = d * 0.6
		cz = d * 0.2
		for i in 8:
			k.plate(-w / 2.0 + 3.0 + i * (w - 6.0) / 7.0, -d / 2.0 + 6.0, 0.15, 6.0, Color("f2f2f2"), 0.08, 0.04)
	if arch == "entrepot":
		bd = d - 8.0
		cz = 4.0
	if s.get("stilts", false):
		# Pilotis.
		y0 = 2.2
		for px in [-bw / 2.0 + 0.4, 0.0, bw / 2.0 - 0.4]:
			for pz in [-bd / 2.0 + 0.4, bd / 2.0 - 0.4]:
				k.box(px, 0, cz + pz, 0.4, y0, 0.4, Color("5a3a22"))
		k.box(0, y0 - 0.3, cz - bd / 2.0 - 1.0, 1.0, 0.2, 2.0, Color("8a5a36"))
	# Volume principal (avec gradins pour l'Art déco et les tours).
	var h := floors * fh
	var tiers := 1
	if s.get("setback", false) and floors >= 12:
		tiers = 3
	elif arch == "gratte_ciel":
		tiers = 2
	var tier_h := h / tiers
	var tw := bw
	var td := bd
	var wall: Color = p.wall
	var glassy := era in ["contemporain", "futuriste"] and arch in ["tour", "gratte_ciel", "bureaux", "grand_magasin"]
	for ti in tiers:
		var ty := y0 + ti * tier_h
		var col := Color(p.glass) if glassy else wall
		k.box(0, ty, cz, tw, tier_h, td, col)
		_windows(k, s, p, era, 0, cz, tw, td, ty, int(round(tier_h / fh)), fh, glassy)
		if ti < tiers - 1:
			k.box(0, ty + tier_h, cz, tw + 0.4, 0.4, td + 0.4, Color(p.trim))
			tw *= 0.72
			td *= 0.72
	var top := y0 + h
	# Rez-de-chaussée commercial.
	if arch in ["boutique", "restaurant", "grand_magasin"] or (arch in ["immeuble", "rangee"] and era == "classique"):
		k.box(0, y0 + 0.3, cz - bd / 2.0 - 0.05, bw * 0.8, 2.4, 0.2, Color(p.glass).darkened(0.2))
		var awn: Color = Color(p.trim) if not bool(s.get("neon", false)) else Color("e63946")
		if era != "futuriste":
			if k._fine() and not bool(s.get("neon", false)):
				StyleKit.auvent(k, 0, y0 + 2.5, cz - bd / 2.0 - 0.1, bw * 0.9, 1.3, Color(p.enseigne), Color("f2ede1"))
			else:
				k.box(0, y0 + 2.9, cz - bd / 2.0 - 0.6, bw * 0.9, 0.2, 1.2, awn)
	# Porte.
	k.box(0, y0, cz - bd / 2.0 - 0.06, 1.4 if arch != "gare" else 6.0, 2.4 if arch != "gare" else 5.0, 0.2, p.door)
	# Rangée : séparations entre les maisons.
	if arch == "rangee":
		for i in range(1, 4):
			k.box(-bw / 2.0 + i * bw / 4.0, y0, cz, 0.3, h + 0.6, bd + 0.2, Color(p.trim))
			k.box(-bw / 2.0 + (i - 0.5) * bw / 4.0, y0, cz - bd / 2.0 - 0.06, 1.1, 2.3, 0.2, p.door)
	# Toit.
	var roof: String = s.roof
	if arch in ["tour", "gratte_ciel", "bureaux", "grand_magasin", "usine", "entrepot", "hopital"] and roof in ["gable", "hip", "curved", "thatch"]:
		roof = "flat" if arch != "usine" else "saw"
	if arch == "usine" and roof == "flat":
		roof = "saw"
	_roof(k, s, p, roof, 0, top, cz, tw, td, arch)
	# Ornements du style.
	_ornaments(k, s, p, arch, bw, bd, cz, y0, top, tw, td, rng)
	# Petits détails modelés du style (volets, cheminées, gouttières, enseignes…).
	if k._fine():
		StyleKit.build(k, s, p, arch, bw, bd, cz, y0, top, tw, td, roof, floors, fh)
	# Annexes.
	if arch == "gratte_ciel":
		k.cylinder(0, top + 2.0, cz, 0.3, 0.1, 18.0 if era != "futuriste" else 40.0, 6, Color("d9d9d9"))
	if arch == "usine":
		k.cylinder(bw / 2.0 - 2.0, 0, cz + bd / 2.0 - 2.0, 1.3, 1.0, h + 16.0, 8, Color("b0413e") if era == "classique" else Color("c9ccd1"))
	if arch == "hopital":
		k.box(0, y0 + 2.6, cz - bd / 2.0 - 0.2, 2.4, 2.4, 0.2, Color("e63946"))
		k.box(0, y0 + 3.3, cz - bd / 2.0 - 0.3, 0.8, 1.0, 0.2, Color.WHITE)
	if arch == "gare":
		k.box(0, 0, d / 2.0 - 3.0, w, 0.8, 4.0, Color("8a8f96"))
		for i in 6:
			k.box(-w / 2.0 + 4.0 + i * (w - 8.0) / 5.0, 0.8, d / 2.0 - 3.0, 0.3, 4.0, 0.3, Color("55585e"))
		k.box(0, 4.8, d / 2.0 - 3.0, w, 0.3, 5.0, Color(p.roof))
	if arch == "ecole":
		k.plate(0, d / 2.0 - 3.0, w * 0.8, 5.0, Color("c96f4a"), 0.0, 0.1)
	if arch == "atelier":
		k.box(-bw / 4.0, y0, cz - bd / 2.0 - 0.06, bw * 0.35, 3.6, 0.2, Color("7d7f85"))
	if arch == "entrepot":
		for i in 4:
			k.box(-bw / 2.0 + bw * (i + 0.5) / 4.0, 0, cz - bd / 2.0 - 0.06, bw / 6.0, 4.2, 0.2, Color("6c7077"))


static func _windows(k: BlocMesh, s: Dictionary, p: Dictionary, era: String, cx: float, cz: float, bw: float, bd: float,
		y0: float, floors: int, fh: float, glassy: bool) -> void:
	if glassy:
		for i in floors:
			k.box(cx, y0 + (i + 1) * fh - 0.25, cz, bw + 0.06, 0.25, bd + 0.06, Color(p.wall).lightened(0.2))
		return
	match era:
		"moderne", "contemporain", "futuriste":
			k.window_bands(cx, cz, bw, bd, y0, floors, fh, p.glass)
		_:
			var n := maxi(1, int(bw / 3.0) + int(p.get("dn", 0)))
			var nd := maxi(1, int(bd / 3.5))
			var wh := 1.4 if era == "classique" else 1.1
			var col: Color = Color(p.glass).darkened(0.1)
			for i in floors:
				var y := y0 + i * fh + fh * 0.35
				k.windows_row(cx, cz - bd / 2.0, bw * 0.9, y, n, 1.0, wh, col)
				k.windows_row(cx, cz + bd / 2.0, bw * 0.9, y, n, 1.0, wh, col)
				k.windows_col(cx - bw / 2.0, cz, bd * 0.85, y, nd, 1.0, wh, col)
				k.windows_col(cx + bw / 2.0, cz, bd * 0.85, y, nd, 1.0, wh, col)
				if s.get("balcony", false) and i >= 1:
					k.box(cx, y - 0.45, cz - bd / 2.0 - 0.45, bw, 0.12, 0.9, Color(p.trim))
					if k._fine():
						StyleKit.garde_corps(k, cx, y - 0.33, cz - bd / 2.0 - 0.88, bw, Color(p.trim))
				if k._fine():
					StyleKit.fenetres(k, s, p, cx, cz - bd / 2.0, bw * 0.9, y, n, wh, i, -1.0)
					StyleKit.fenetres(k, s, p, cx, cz + bd / 2.0, bw * 0.9, y, n, wh, i, 1.0)


static func _roof(k: BlocMesh, s: Dictionary, p: Dictionary, kind: String, cx: float, y: float, cz: float, sx: float, sz: float, arch: String) -> void:
	var col: Color = p.roof
	var pitch := float(s.get("pitch", 0.5)) * float(p.get("pente", 1.0))
	var short := minf(sx, sz)
	match kind:
		"gable":
			k.gable(cx, y, cz, sx + 0.8, sz + 0.8, short / 2.0 * pitch, col, sx >= sz)
		"hip":
			k.hip(cx, y, cz, sx + 1.0, sz + 1.0, short / 2.0 * pitch, col)
		"thatch":
			k.roof_style = "chaume"
			k.hip(cx, y, cz, sx + 1.6, sz + 1.6, short * 0.6, col)
			k.roof_style = ""
		"curved":
			# Avant-toit large et peu pentu, puis toit plus raide : bords relevés.
			k.hip(cx, y, cz, sx + 3.0, sz + 3.0, 0.6, col.darkened(0.08))
			k.hip(cx, y + 0.5, cz, sx * 0.85, sz * 0.85, short * 0.32, col)
			k.box(cx, y + 0.5 + short * 0.32 - 0.2, cz, (maxf(sx, sz) - short) * 0.85 + 0.6, 0.4, 0.5 if sx >= sz else 0.5, col.darkened(0.25))
		"mansard":
			k.box(cx, y, cz, sx - 0.4, 0.3, sz - 0.4, Color(p.trim))
			k.hip(cx, y + 0.3, cz, sx, sz, 1.0, col)
			k.box(cx, y + 0.3, cz, sx - 2.0, 3.0, sz - 2.0, col)
			k.hip(cx, y + 3.3, cz, sx - 2.0, sz - 2.0, 0.8, col.darkened(0.1))
			for i in int(sx / 4.0):
				k.box(cx - sx / 2.0 + 2.0 + i * 4.0, y + 1.0, cz - sz / 2.0 + 1.0, 1.0, 1.6, 0.8, Color(p.wall))
		"shed":
			k.gable(cx, y, cz, sx + 0.8, sz + 0.8, 0.8, col, sx >= sz)
		"saw":
			var n := maxi(2, int(sx / 7.0))
			for i in n:
				k.gable(cx - sx / 2.0 + sx * (i + 0.5) / n, y, cz, sx / n, sz, 2.6, col, false)
		"dome":
			k.box(cx, y, cz, sx, 0.4, sz, Color(p.trim))
			k.dome(cx, y + 0.4, cz, short * 0.42, short * 0.25, Color(p.glass).lightened(0.3), 16)
		_:
			# Terrasse avec acrotère.
			k.box(cx, y, cz, sx + 0.2, 0.25, sz + 0.2, col.darkened(0.08))
			k.box(cx, y + 0.25, cz - sz / 2.0, sx + 0.2, 0.6, 0.2, Color(p.wall).darkened(0.05))
			k.box(cx, y + 0.25, cz + sz / 2.0, sx + 0.2, 0.6, 0.2, Color(p.wall).darkened(0.05))
			k.box(cx - sx / 2.0, y + 0.25, cz, 0.2, 0.6, sz, Color(p.wall).darkened(0.05))
			k.box(cx + sx / 2.0, y + 0.25, cz, 0.2, 0.6, sz, Color(p.wall).darkened(0.05))
			if s.get("green_roof", false):
				k.plate(cx, cz, sx - 0.6, sz - 0.6, Color("6aa84f"), y + 0.25, 0.15)
			elif arch in ["tour", "gratte_ciel", "bureaux", "immeuble", "hopital"]:
				k.box(cx + sx * 0.2, y + 0.25, cz, sx * 0.25, 2.2, sz * 0.25, Color("9aa0a6"))


static func _ornaments(k: BlocMesh, s: Dictionary, p: Dictionary, arch: String, bw: float, bd: float, cz: float,
		y0: float, top: float, tw: float, td: float, rng: RandomNumberGenerator) -> void:
	var trim: Color = p.trim
	var h := top - y0
	if s.get("timber", false):
		# Colombages : poutres sombres sur la façade et les pignons.
		var fz := cz - bd / 2.0 - 0.05
		for i in int(bw / 1.6) + 1:
			k.box(-bw / 2.0 + i * bw / int(bw / 1.6), y0, fz, 0.22, h, 0.12, trim)
		for j in int(h / _fh(s)) + 1:
			k.box(0, y0 + j * _fh(s), fz, bw, 0.22, 0.12, trim)
		k.box(0, y0 + h * 0.5, fz - 0.01, bw * 0.4, 0.2, 0.1, trim)
	if s.get("spikes", false):
		# Pieux (torons) des façades en terre.
		for i in int(bw / 2.0) + 1:
			k.box(-bw / 2.0 + i * bw / int(bw / 2.0), y0 + h * 0.5, cz - bd / 2.0 - 0.3, 0.2, 0.2, 0.6, Color("6b4a2b"))
		for x in [-bw / 2.0, bw / 2.0]:
			k.box(x, top, cz - bd / 2.0, 0.8, 1.2, 0.8, p.wall)
	if s.get("vigas", false):
		for i in int(bw / 1.5):
			k.cylinder(-bw / 2.0 + 0.75 + i * 1.5, top - 0.6, cz - bd / 2.0 - 0.3, 0.12, 0.12, 0.2, 5, Color("6b4a2b"))
			k.box(-bw / 2.0 + 0.75 + i * 1.5, top - 0.7, cz - bd / 2.0 - 0.25, 0.22, 0.22, 0.6, Color("6b4a2b"))
	if s.get("chhatri", false):
		for x in [-bw / 2.0 + 1.0, bw / 2.0 - 1.0]:
			for z in [cz - bd / 2.0 + 1.0, cz + bd / 2.0 - 1.0]:
				for ox in [-0.6, 0.6]:
					for oz in [-0.6, 0.6]:
						k.box(x + ox, top + 0.25, z + oz, 0.18, 1.6, 0.18, trim)
				k.box(x, top + 1.85, z, 1.8, 0.15, 1.8, trim)
				k.dome(x, top + 2.0, z, 0.9, 0.9, trim, 8)
		k.box(0, top - h * 0.45, cz - bd / 2.0 - 0.5, bw * 0.3, 1.4, 1.0, trim)
	if s.get("porch", false) and arch in ["maison", "grande_maison", "boutique", "restaurant"]:
		var pz := cz - bd / 2.0 - 1.2
		k.plate(0, pz, bw, 2.4, Color("c9a27e"), 0.0, 0.3)
		for x in [-bw / 2.0 + 0.3, -bw / 6.0, bw / 6.0, bw / 2.0 - 0.3]:
			k.box(x, 0.3, pz - 1.0, 0.25, 2.6, 0.25, Color(p.trim))
		k.box(0, 2.9, pz, bw + 0.4, 0.25, 2.6, Color(p.roof))
		if arch == "boutique":
			k.box(0, top, cz - bd / 2.0 - 0.1, bw, 2.2, 0.25, p.wall)
	if s.get("garage", false) and arch in ["maison", "grande_maison"]:
		var gx := bw / 2.0 + 0.4
		k.box(gx - 1.2, 0, cz - 1.0, 3.6, 2.8, 6.0, Color(p.wall).darkened(0.05))
		k.box(gx - 1.2, 0, cz - 4.05, 2.8, 2.2, 0.12, Color("e9e2d4"))
		k.plate(gx - 1.2, cz - 6.0, 3.0, 4.0, Color("9aa0a6"), 0.0, 0.05)
	if s.get("neon", false):
		for i in mini(3, int(h / 6.0)):
			var col: Color = [Color("e63946"), Color("f2c14e"), Color("4fd1e0"), Color("ff70c0")][rng.randi() % 4]
			k.box(bw / 2.0 - 0.6, y0 + 4.0 + i * 5.0, cz - bd / 2.0 - 0.4, 0.3, 3.5, 1.4, col)
	if s.get("paint", false):
		for i in 3:
			k.box(0, y0 + 0.4 + i * 0.6, cz - bd / 2.0 - 0.04, bw, 0.25, 0.08, [Color("8c3b2b"), Color("1f3b73"), Color("f2c14e")][i])
	if s.get("court", false) and arch == "grande_maison":
		k.plate(0, cz, bw * 0.4, bd * 0.4, Color("2a9d8f").lightened(0.3), top + 0.26, 0.05)
	if s.roof == "flat" and s.region == "moyen_orient" and arch in ["maison", "grande_maison"] and s.get("court", false) == false:
		# Tour à vent (badgir).
		k.box(bw / 4.0, top, cz + bd / 4.0, 2.0, 4.0, 2.0, p.wall)
		k.box(bw / 4.0, top + 2.6, cz + bd / 4.0, 2.1, 1.0, 2.1, Color("3a3028"))
	if s.era == "futuriste" and arch in ["tour", "gratte_ciel", "immeuble"]:
		for i in 3:
			k.cylinder(0, y0 + h * (0.3 + i * 0.25), cz, maxf(tw, td) * 0.62, maxf(tw, td) * 0.62, 0.6, 16, Color("4fd1e0"))


# --- Archétypes particuliers ------------------------------------------------------------

## Case ronde : murs cylindriques et toit conique (chaume ou terre).
static func _case_ronde(k: BlocMesh, s: Dictionary, p: Dictionary, w: float, d: float) -> void:
	k.plate(0, 0, w, d, Color("c9a46a"))
	var r := minf(w, d) * 0.34
	k.cylinder(0, 0, 0, r, r, 2.6, 12, p.wall)
	if s.get("paint", false):
		k.cylinder(0, 0.3, 0, r + 0.03, r + 0.03, 0.4, 12, p.trim)
	k.lathe(0, 2.5, 0, [Vector2(r + 1.0, 0), Vector2(r * 0.5, 1.6), Vector2(0, 3.2)], 12, Color("b39a5e"))
	k.box(0, 0, -r - 0.02, 1.0, 1.8, 0.3, Color("4a3222"))
	k.cylinder(r + 1.8, 0, r * 0.4, 0.9, 0.9, 1.8, 8, Color(p.wall).darkened(0.1))
	k.lathe(r + 1.8, 1.8, r * 0.4, [Vector2(1.2, 0), Vector2(0, 1.4)], 8, Color("b39a5e"))


## Concession ou kraal : enceinte et plusieurs cases.
static func _concession(k: BlocMesh, s: Dictionary, p: Dictionary, w: float, d: float) -> void:
	k.plate(0, 0, w, d, Color("c9a46a"))
	var wallc: Color = Color(p.wall).darkened(0.1)
	k.box(0, 0, -d / 2.0 + 0.3, w, 1.8, 0.5, wallc)
	k.box(0, 0, d / 2.0 - 0.3, w, 1.8, 0.5, wallc)
	k.box(-w / 2.0 + 0.3, 0, 0, 0.5, 1.8, d, wallc)
	k.box(w / 2.0 - 0.3, 0, 0, 0.5, 1.8, d, wallc)
	k.box(0, 0, -d / 2.0 + 0.3, 2.4, 1.9, 0.6, Color("c9a46a"))
	for c in [Vector2(-4.5, -3.5), Vector2(4.5, -3.5), Vector2(-4.5, 4.5), Vector2(4.5, 4.5), Vector2(0, 3.0)]:
		var r := 2.2
		k.cylinder(c.x, 0, c.y, r, r, 2.4, 10, p.wall)
		if s.get("paint", false):
			k.cylinder(c.x, 0.4, c.y, r + 0.03, r + 0.03, 0.35, 10, p.trim)
		k.lathe(c.x, 2.3, c.y, [Vector2(r + 0.8, 0), Vector2(0, 2.6)], 10, Color("b39a5e"))


static func _marche(k: BlocMesh, s: Dictionary, p: Dictionary, w: float, d: float) -> void:
	k.plate(0, 0, w, d, p.ground)
	var era: String = s.era
	match s.roof:
		"flat":
			if s.region == "moyen_orient" or s.region == "asie_sud":
				# Bazar à coupoles.
				k.box(0, 0, 0, w - 2.0, 5.0, d - 2.0, p.wall)
				for i in 3:
					for j in 2:
						k.dome(-w / 3.0 + i * w / 3.0, 5.0, -d / 4.0 + j * d / 2.0, 3.2, 2.4, p.roof if s.roof == "flat" else p.wall, 10)
				for i in 5:
					k.box(-w / 2.0 + 3.0 + i * (w - 6.0) / 4.0, 0, -d / 2.0 + 0.95, 2.0, 3.2, 0.2, Color("4a3222"))
				return
		"curved":
			if s.get("stilts", false):
				# Marché flottant : quai et barques.
				k.plate(0, 0, w, d, Color("4f8fc4"), 0.0, 0.05)
				k.box(0, 0, -d / 2.0 + 3.0, w, 1.0, 5.0, Color("8a5a36"))
				for i in 5:
					k.box(-w / 2.0 + 4.0 + i * (w - 8.0) / 4.0, 0.05, 3.0, 1.4, 0.5, 5.0, Color("9c6b45"))
					k.cylinder(-w / 2.0 + 4.0 + i * (w - 8.0) / 4.0, 0.55, 3.0, 0.7, 0.0, 0.6, 6, Color("e6d59c"))
				return
	# Halle : piliers et grand toit.
	var cols := 6
	for i in cols:
		for z in [-d / 2.0 + 1.5, 0.0, d / 2.0 - 1.5]:
			k.box(-w / 2.0 + 1.5 + i * (w - 3.0) / (cols - 1), 0, z, 0.6, 5.0, 0.6, Color(p.trim) if era == "classique" else Color("6b4a33"))
	var roof := "gable" if s.roof in ["flat", "dome"] and era != "traditionnel" else String(s.roof)
	if roof == "flat":
		k.box(0, 5.0, 0, w, 0.5, d, p.roof)
	else:
		_roof(k, s, p, roof if roof != "mansard" else "hip", 0, 5.0, 0, w - 1.0, d - 1.0, "marche")
	for i in 4:
		for j in 2:
			k.box(-w / 3.0 + i * w / 4.5, 0, -d / 4.0 + j * d / 2.0, 3.0, 0.9, 1.5, Color("c9a27e"))
			k.box(-w / 3.0 + i * w / 4.5, 0.9, -d / 4.0 + j * d / 2.0, 3.0, 0.3, 1.5, [Color("e63946"), Color("f2c14e"), Color("76b041")][(i + j) % 3])


static func _ferme(k: BlocMesh, s: Dictionary, p: Dictionary, w: float, d: float) -> void:
	k.plate(0, 0, w, d, Color("a8915e"))
	var era: String = s.era
	if s.get("stilts", false):
		# Grenier à riz sur pilotis et rizière.
		k.plate(0, 3.0, w, d - 6.0, Color("5aa845"), 0.0, 0.12)
		for x in [-1.5, 1.5]:
			for z in [-d / 2.0 + 1.5, -d / 2.0 + 4.0]:
				k.box(x - 4.0, 0, z, 0.3, 2.2, 0.3, Color("5a3a22"))
		k.box(-4.0, 2.2, -d / 2.0 + 2.75, 4.0, 2.4, 3.5, p.wall)
		k.hip(-4.0, 4.6, -d / 2.0 + 2.75, 5.0, 4.5, 2.2, Color("b39a5e"))
		return
	# Maison et grange.
	k.box(-w / 4.0, 0, -d / 4.0, w * 0.4, 5.6, d * 0.32, p.wall)
	_roof(k, s, p, "gable" if s.roof in ["flat", "curved", "dome", "mansard", "shed"] and s.region != "moyen_orient" else String(s.roof), -w / 4.0, 5.6, -d / 4.0, w * 0.4, d * 0.32, "ferme")
	k.box(-w / 4.0, 0, -d / 4.0 - d * 0.16 - 0.05, 1.1, 2.2, 0.2, p.door)
	var barn: Color = Color("9b2c2c") if s.region in ["ameriques", "europe"] else Color(p.wall).darkened(0.15)
	k.box(w / 4.0, 0, d / 6.0, w * 0.4, 6.5, d * 0.5, barn)
	k.gable(w / 4.0, 6.5, d / 6.0, w * 0.4 + 0.8, d * 0.5 + 0.8, 4.0, Color("4a4e55"), false)
	k.box(w / 4.0, 0, d / 6.0 - d * 0.25 - 0.05, 4.0, 4.4, 0.2, Color("f2f2f2") if era != "antique" else p.door)
	if s.region in ["ameriques", "europe"] or era in ["moderne", "contemporain"]:
		k.cylinder(-w / 2.0 + 3.0, 0, d / 2.0 - 3.5, 2.2, 2.2, 12.0, 10, Color("c9ccd1"))
		k.dome(-w / 2.0 + 3.0, 12.0, d / 2.0 - 3.5, 2.3, 1.6, Color("8a8d93"), 10)
	elif s.region == "afrique":
		for i in 3:
			k.cylinder(-w / 2.0 + 2.5 + i * 3.2, 0, d / 2.0 - 3.0, 1.2, 1.4, 2.6, 8, p.wall)
			k.lathe(-w / 2.0 + 2.5 + i * 3.2, 2.6, d / 2.0 - 3.0, [Vector2(1.7, 0), Vector2(0, 1.6)], 8, Color("b39a5e"))
	# Champ.
	for i in 6:
		k.plate(-w / 2.0 + 2.0 + i * 1.6, d / 2.0 - 3.0 if s.region not in ["ameriques", "europe", "afrique"] else -d / 2.0 + 2.0, 0.8, 4.0, Color("d2c06a"), 0.0, 0.2)


static func _jardin(k: BlocMesh, s: Dictionary, p: Dictionary, w: float, d: float) -> void:
	var region: String = s.region
	if region == "asie_est" and s.roof == "curved" and s.trim == "5a3a22":
		# Jardin zen : gravier ratissé, rochers, lanterne.
		k.plate(0, 0, w, d, Color("e6e1d6"))
		for i in 12:
			k.plate(0, -d / 2.0 + 2.0 + i * (d - 4.0) / 11.0, w - 4.0, 0.08, Color("d6d0c2"), 0.08, 0.04)
		for c in [Vector3(-6, 0, -4), Vector3(5, 0, 3), Vector3(-2, 0, 7)]:
			k.lathe(c.x, 0, c.z, [Vector2(1.6, 0), Vector2(1.4, 0.9), Vector2(0.5, 1.5), Vector2(0, 1.6)], 6, Color("7d7f85"))
		k.box(10, 0, -10, 0.6, 1.4, 0.6, Color("9a9a94"))
		k.hip(10, 1.4, -10, 1.3, 1.3, 0.5, Color("6b6f75"))
		k.tree(-11, 11, 1.0, Color("b5523b"))
		return
	k.plate(0, 0, w, d, Color("7cbf5a"))
	if region in ["moyen_orient", "asie_sud"]:
		# Jardin persan ou moghol : canaux en croix et bassin.
		k.plate(0, 0, 2.0, d, Color("4fb3d9"), 0.05, 0.06)
		k.plate(0, 0, w, 2.0, Color("4fb3d9"), 0.05, 0.06)
		k.box(0, 0, 0, 5.0, 0.5, 5.0, p.wall)
		k.plate(0, 0, 4.0, 4.0, Color("4fb3d9"), 0.5, 0.06)
		for x in [-1, 1]:
			for z in [-1, 1]:
				for i in 3:
					k.cylinder(x * (5.0 + i * 3.0), 0, z * 8.0, 0.5, 0.0, 6.0, 6, Color("2f6b3a"))
		return
	# Jardin de lettré chinois : étang, pont, pavillon.
	k.plate(-3, 2, 14, 10, Color("4f8fc4"), 0.05, 0.06)
	k.box(-3, 0.2, 2, 2.0, 0.5, 11, Color("b8322a"))
	k.box(8, 0, -8, 5, 0.5, 5, Color("b9b6ae"))
	for x in [-1.8, 1.8]:
		for z in [-1.8, 1.8]:
			k.box(8 + x, 0.5, -8 + z, 0.3, 2.6, 0.3, Color("b8322a"))
	_roof(k, s, p, "curved", 8, 3.1, -8, 4.4, 4.4, "jardin")
	k.tree(-11, -10, 1.0)
	k.tree(11, 10, 0.9, Color("e8a0b4"))


static func _amphitheatre(k: BlocMesh, p: Dictionary, w: float, d: float) -> void:
	var r := minf(w, d) / 2.0 - 0.5
	for i in 6:
		k.cylinder(0, i * 1.2, 0, r - i * 0.2, r - i * 0.2, 1.2, 24, Color(p.wall).darkened(i * 0.02))
	k.cylinder(0, 7.2, 0, r - 1.2, r - 1.2, 0.01, 24, Color(p.wall))
	k.cylinder(0, 0, 0, r * 0.45, r * 0.45, 7.25, 20, Color("d9c79a"))
	for i in 16:
		var a := TAU * i / 16.0
		k.box(cos(a) * (r - 0.4), 0, sin(a) * (r - 0.4), 1.2, 6.5, 1.2, Color(p.wall).darkened(0.1))


# --- Lieux de culte ----------------------------------------------------------------------

static func _culte(k: BlocMesh, s: Dictionary, p: Dictionary, w: float, d: float) -> void:
	var wall: Color = p.wall
	var roof: Color = p.roof
	var trim: Color = p.trim
	k.plate(0, 0, w, d, p.ground)
	match String(s.culte):
		"eglise", "eglise_blanche", "eglise_classique":
			var nw := w * 0.5
			k.box(0, 0, 2.0, nw, 9.0, d - 10.0, wall)
			k.gable(0, 9.0, 2.0, nw + 0.8, d - 9.0, 4.5, roof, false)
			k.box(0, 0, -d / 2.0 + 4.0, 5.0, 16.0, 5.0, wall)
			k.pyramid(0, 16.0, -d / 2.0 + 4.0, 5.4, 5.4, 9.0, roof)
			k.cylinder(0, 12.5, -d / 2.0 + 1.45, 1.0, 1.0, 0.1, 12, Color("fdfdfd"))
			k.box(0, 0, -d / 2.0 + 1.4, 1.8, 3.2, 0.2, p.door)
			k.windows_col(-nw / 2.0, 2.0, d - 12.0, 3.0, 5, 1.0, 3.5, Color("4f6d8f"))
			k.windows_col(nw / 2.0, 2.0, d - 12.0, 3.0, 5, 1.0, 3.5, Color("4f6d8f"))
			if s.culte == "eglise_classique":
				for x in [-2.0, -0.7, 0.7, 2.0]:
					k.cylinder(x * 1.3, 0, -d / 2.0 + 0.8, 0.4, 0.4, 7.0, 8, trim.lightened(0.6))
				k.box(0, 7.0, -d / 2.0 + 0.8, 7.0, 0.8, 1.6, wall)
		"cathedrale":
			k.box(0, 0, 4.0, w * 0.45, 22.0, d - 16.0, wall)
			k.gable(0, 22.0, 4.0, w * 0.45 + 0.8, d - 15.0, 8.0, roof, false)
			k.box(0, 0, 6.0, w - 2.0, 14.0, 8.0, wall)
			for x in [-w / 2.0 + 3.0, w / 2.0 - 3.0]:
				k.box(x, 0, 4.0, 2.0, 12.0, 2.0, wall.darkened(0.1))
			for x in [-5.5, 5.5]:
				k.box(x, 0, -d / 2.0 + 4.0, 6.0, 34.0, 6.0, wall)
				k.pyramid(x, 34.0, -d / 2.0 + 4.0, 6.0, 6.0, 12.0, roof)
			k.cylinder(0, 14.0, -d / 2.0 + 1.0, 3.0, 3.0, 0.15, 16, Color("6d4c8f"))
			k.box(0, 0, -d / 2.0 + 1.0, 4.0, 6.0, 0.3, p.door)
			k.box(0, 30.0, 4.0 - (d - 16.0) / 6.0, 1.0, 14.0, 1.0, roof)
		"cathedrale_baroque":
			k.box(0, 0, 4.0, w * 0.55, 16.0, d - 14.0, wall)
			k.gable(0, 16.0, 4.0, w * 0.55 + 0.6, d - 13.0, 5.0, roof, false)
			k.box(0, 0, -d / 2.0 + 3.0, w - 2.0, 20.0, 4.0, wall)
			for x in [-w / 2.0 + 3.0, w / 2.0 - 3.0]:
				k.box(x, 20.0, -d / 2.0 + 3.0, 4.0, 10.0, 4.0, wall)
				k.dome(x, 30.0, -d / 2.0 + 3.0, 2.2, 2.6, Color("d9a520"), 10)
			k.cylinder(0, 21.0, 8.0, 5.0, 5.0, 4.0, 12, wall)
			k.dome(0, 25.0, 8.0, 5.0, 5.0, Color("d9a520"), 14)
			k.box(0, 0, -d / 2.0 + 0.9, 3.0, 5.0, 0.3, p.door)
		"eglise_bulbes":
			k.box(0, 0, 0, w * 0.6, 10.0, d * 0.6, wall)
			k.hip(0, 10.0, 0, w * 0.6 + 0.6, d * 0.6 + 0.6, 2.0, roof)
			for c in [Vector3(0, 0, 0), Vector3(-4, 0, -4), Vector3(4, 0, -4), Vector3(-4, 0, 4), Vector3(4, 0, 4)]:
				var tall := 6.0 if c.x == 0 else 3.0
				k.cylinder(c.x, 11.0, c.z, 1.6, 1.6, tall, 10, wall)
				k.onion(c.x, 11.0 + tall, c.z, 2.0, 4.0, [Color("d9a520"), Color("2a6fdb"), Color("2a9d8f")][int(absf(c.x)) % 3], 10)
			k.box(0, 0, -d * 0.3 - 0.05, 2.0, 3.0, 0.2, p.door)
		"stavkirke":
			k.box(0, 0, 0, 10.0, 5.0, 12.0, wall)
			for i in 4:
				var sz := 13.0 - i * 2.8
				k.hip(0, 5.0 + i * 3.2, 0, sz, sz + 1.0, 2.6, roof)
				if i < 3:
					k.box(0, 5.0 + i * 3.2 + 1.8, 0, sz - 3.0, 1.6, sz - 2.0, wall)
			k.pyramid(0, 15.0, 0, 2.2, 2.2, 5.0, roof)
		"chapelle_bleue":
			k.box(0, 0, 0, 10.0, 6.0, 14.0, Color("f7f4ee"))
			k.cylinder(0, 6.0, 0, 3.6, 3.6, 2.0, 14, Color("f7f4ee"))
			k.dome(0, 8.0, 0, 3.8, 3.6, Color("2a6fdb"), 14)
			k.box(0, 6.0, -7.0, 2.5, 4.0, 1.0, Color("f7f4ee"))
			k.box(0, 0, -7.05, 1.4, 2.4, 0.2, Color("2a6fdb"))
		"mosquee_dome", "mosquee_minaret":
			k.box(0, 0, 2.0, w * 0.7, 9.0, d * 0.55, wall)
			k.box(0, 0, -d * 0.2, w * 0.7, 4.0, 0.6, wall)
			if s.culte == "mosquee_dome":
				k.cylinder(0, 9.0, 2.0, w * 0.22, w * 0.22, 2.5, 16, wall)
				k.onion(0, 11.5, 2.0, w * 0.24, w * 0.34, roof, 16)
				for x in [-w / 2.0 + 2.0, w / 2.0 - 2.0]:
					k.cylinder(x, 0, -d / 2.0 + 2.0, 1.1, 0.9, 26.0, 10, wall)
					k.cylinder(x, 20.0, -d / 2.0 + 2.0, 1.5, 1.5, 0.6, 10, trim)
					k.lathe(x, 26.0, -d / 2.0 + 2.0, [Vector2(1.0, 0), Vector2(0, 2.4)], 10, roof)
				k.box(0, 0, -d * 0.2 - 0.35, 5.0, 7.0, 0.3, roof)
			else:
				k.box(-w / 2.0 + 3.0, 0, -d / 2.0 + 3.0, 4.6, 24.0, 4.6, wall)
				k.box(-w / 2.0 + 3.0, 24.0, -d / 2.0 + 3.0, 3.0, 4.0, 3.0, wall)
				k.dome(-w / 2.0 + 3.0, 28.0, -d / 2.0 + 3.0, 1.2, 1.2, Color("2a9d8f"), 8)
				for y in [6.0, 12.0, 18.0]:
					k.box(-w / 2.0 + 3.0, y, -d / 2.0 + 0.65, 3.0, 1.6, 0.1, Color("2a9d8f"))
				k.box(0, 9.0, 2.0, w * 0.7, 0.5, d * 0.55, roof)
				k.box(0, 0, -d * 0.2 - 0.35, 3.0, 4.0, 0.3, Color("2a9d8f"))
			k.plate(0, -d / 2.0 + 4.0, w * 0.5, 6.0, Color("e9e2d4"), 0.0, 0.1)
		"mosquee_terre":
			k.box(0, 0, 2.0, w - 4.0, 8.0, d * 0.6, wall)
			for x in [-w / 2.0 + 3.0, -3.0, 3.0, w / 2.0 - 3.0]:
				k.box(x, 0, -d * 0.1 - 1.0, 3.0, 16.0, 3.0, wall)
				k.lathe(x, 16.0, -d * 0.1 - 1.0, [Vector2(1.6, 0), Vector2(0.6, 2.0), Vector2(0, 2.4)], 6, wall)
				for y in [3.0, 6.0, 9.0, 12.0]:
					k.box(x, y, -d * 0.1 - 2.8, 0.2, 0.2, 0.9, Color("6b4a2b"))
			k.box(0, 0, -d * 0.1 - 0.5, w - 4.0, 9.0, 2.0, wall)
			for i in int(w / 2.0):
				k.box(-w / 2.0 + 2.0 + i * 2.0, 4.5, -d * 0.1 - 1.8, 0.2, 0.2, 0.9, Color("6b4a2b"))
		"pagode":
			k.box(0, 0, 0, 10.0, 1.0, 10.0, Color("b9b6ae"))
			for i in 7:
				var sz := 9.0 - i * 0.9
				var y := 1.0 + i * 3.4
				k.box(0, y, 0, sz, 2.4, sz, wall)
				k.hip(0, y + 2.4, 0, sz + 3.0, sz + 3.0, 1.0, roof)
			k.cylinder(0, 1.0 + 7 * 3.4, 0, 0.3, 0.1, 5.0, 6, Color("d9a520"))
			k.box(0, 0, -8.0, 9.0, 4.0, 4.0, wall)
			_roof(k, s, p, "curved", 0, 4.0, -8.0, 9.0, 4.0, "culte")
		"sanctuaire":
			k.box(0, 0.6, 2.0, 12.0, 4.4, 9.0, Color("f4f0e6"))
			k.box(0, 0, 2.0, 13.0, 0.6, 10.0, Color("8a5a36"))
			_roof(k, s, p, "curved", 0, 5.0, 2.0, 12.0, 9.0, "culte")
			# Torii.
			var tc := Color("d1452f")
			for x in [-2.8, 2.8]:
				k.cylinder(x, 0, -9.0, 0.35, 0.3, 6.0, 8, tc)
			k.box(0, 5.2, -9.0, 8.2, 0.5, 0.6, tc)
			k.box(0, 6.0, -9.0, 9.4, 0.5, 0.8, Color("1f1f1f"))
			k.box(0, 4.2, -9.0, 6.4, 0.3, 0.4, tc)
			# Petite pagode à cinq toits.
			for i in 5:
				var sz := 4.5 - i * 0.5
				k.box(8.0, i * 2.6, 7.0, sz, 1.8, sz, Color("d1452f"))
				k.hip(8.0, i * 2.6 + 1.8, 7.0, sz + 2.2, sz + 2.2, 0.8, roof)
		"temple_shikhara":
			k.box(0, 0, 0, w - 6.0, 2.0, d - 6.0, wall.darkened(0.1))
			k.box(0, 2.0, 2.0, 10.0, 6.0, 10.0, wall)
			k.lathe(0, 8.0, 2.0, [Vector2(6.0, 0), Vector2(5.6, 5.0), Vector2(4.6, 10.0), Vector2(2.8, 14.0), Vector2(1.0, 16.0), Vector2(0, 17.0)], 8, wall)
			k.cylinder(0, 25.0, 2.0, 1.3, 1.3, 0.8, 10, Color("d9a520"))
			k.box(0, 2.0, -6.0, 7.0, 5.0, 6.0, wall)
			k.dome(0, 7.0, -6.0, 3.0, 3.0, wall, 10)
			for x in [-2.6, 2.6]:
				k.box(x, 2.0, -9.0, 0.6, 4.0, 0.6, trim)
		"wat":
			k.box(0, 0, 2.0, w * 0.5, 1.4, d * 0.6, Color("f2f2f2"))
			k.box(0, 1.4, 2.0, w * 0.45, 7.0, d * 0.55, Color("f6f1e7"))
			for i in 3:
				var off := i * 1.8
				k.gable(0, 8.4 + off * 0.9, 2.0, w * 0.45 + 2.0 - off * 2.0, d * 0.55 + 2.0 - off * 2.0, 4.5 - i * 0.6, roof if i % 2 == 0 else Color("2a6f4f"), false)
			k.cylinder(0, 14.5, -d * 0.275 + 2.0, 0.15, 0.05, 2.5, 4, Color("d9a520"))
			# Stupa doré.
			var sx := w / 2.0 - 4.0
			k.box(sx, 0, -d / 2.0 + 5.0, 6.0, 2.0, 6.0, Color("f2f2f2"))
			k.lathe(sx, 2.0, -d / 2.0 + 5.0, [Vector2(2.8, 0), Vector2(2.6, 2.4), Vector2(1.2, 4.0), Vector2(0.6, 7.0), Vector2(0.15, 11.0), Vector2(0, 12.0)], 10, Color("d9a520"))
		"mission":
			k.box(0, 0, 4.0, w * 0.5, 8.0, d - 10.0, wall)
			k.box(0, 8.0, 4.0, w * 0.5, 0.5, d - 10.0, wall.darkened(0.1))
			k.box(0, 0, -d / 2.0 + 5.0, w * 0.5 + 2.0, 12.0, 1.0, wall)
			k.lathe(0, 12.0, -d / 2.0 + 5.0, [Vector2(3.0, 0), Vector2(2.0, 1.5), Vector2(0, 2.4)], 10, wall)
			k.box(w * 0.25 + 1.5, 12.0, -d / 2.0 + 5.0, 3.0, 4.0, 3.0, wall)
			k.box(w * 0.25 + 1.5, 14.0, -d / 2.0 + 3.45, 1.2, 1.4, 0.1, Color("3a3028"))
			k.box(0, 0, -d / 2.0 + 4.45, 2.0, 3.4, 0.2, p.door)
			k.cylinder(0, 14.4, -d / 2.0 + 5.0, 0.12, 0.12, 2.0, 4, Color("3a3028"))
		"temple_grec":
			for i in 3:
				k.box(0, i * 0.5, 0, w - i * 1.2, 0.5, d - i * 1.2, Color("e6dcc6"))
			var nc := 6
			for i in nc:
				var x := -w / 2.0 + 2.4 + i * (w - 4.8) / (nc - 1)
				for z in [-d / 2.0 + 2.4, d / 2.0 - 2.4]:
					k.cylinder(x, 1.5, z, 0.8, 0.7, 9.0, 10, Color("f6f1e7"))
			for j in 1:
				for i in 6:
					var z := -d / 2.0 + 2.4 + (i + 1) * (d - 4.8) / 7.0
					for x in [-w / 2.0 + 2.4, w / 2.0 - 2.4]:
						k.cylinder(x, 1.5, z, 0.8, 0.7, 9.0, 10, Color("f6f1e7"))
			k.box(0, 1.5, 0, w - 9.0, 9.0, d - 10.0, wall.darkened(0.08))
			k.box(0, 10.5, 0, w - 3.0, 1.4, d - 3.0, Color("f6f1e7"))
			k.gable(0, 11.9, 0, w - 2.6, d - 2.6, 2.8, roof, false)
		"pyramide":
			for i in 7:
				var sz := w - i * 5.0
				k.box(0, i * 3.4, 0, sz, 3.4, sz, wall.darkened(0.02 * i))
			k.box(0, 0, -w / 2.0 + 6.0, 5.0, 23.8, 12.0, wall.lightened(0.05))
			k.box(0, 23.8, 0, 6.0, 4.0, 6.0, wall)
			k.box(0, 23.8, -3.05, 1.6, 2.4, 0.2, Color("3a3028"))
			k.box(0, 27.8, 0, 6.6, 0.6, 6.6, Color("b5523b"))
		_:
			# Église moderne : volume blanc, toit incliné, campanile.
			k.box(0, 0, 3.0, w * 0.6, 10.0, d * 0.6, Color("f1ece2"))
			k.gable(0, 10.0, 3.0, w * 0.6 + 0.6, d * 0.6 + 0.6, 3.0, Color("8a8f96"), false)
			k.box(w / 2.0 - 3.0, 0, -d / 2.0 + 4.0, 2.4, 22.0, 2.4, Color("d8d6cf"))
			k.box(w / 2.0 - 3.0, 18.0, -d / 2.0 + 2.75, 0.3, 2.4, 0.1, Color("3a3028"))
			k.box(w / 2.0 - 3.0, 19.0, -d / 2.0 + 2.7, 1.4, 0.3, 0.1, Color("3a3028"))
			k.box(0, 0, 3.0 - d * 0.3 - 0.05, 3.0, 3.4, 0.2, Color(p.glass))


# --- Palais et monuments ---------------------------------------------------------------

static func _palais(k: BlocMesh, s: Dictionary, p: Dictionary, w: float, d: float) -> void:
	var wall: Color = p.wall
	var roof: Color = p.roof
	var trim: Color = p.trim
	k.plate(0, 0, w, d, p.ground)
	match String(s.palais):
		"chateau_fort":
			var hw := w / 2.0 - 3.0
			var hd := d / 2.0 - 3.0
			k.box(0, 0, -hd, w - 6.0, 8.0, 2.0, wall)
			k.box(0, 0, hd, w - 6.0, 8.0, 2.0, wall)
			k.box(-hw, 0, 0, 2.0, 8.0, d - 6.0, wall)
			k.box(hw, 0, 0, 2.0, 8.0, d - 6.0, wall)
			for x in [-hw, hw]:
				for z in [-hd, hd]:
					k.cylinder(x, 0, z, 3.0, 3.0, 13.0, 10, wall)
					k.lathe(x, 13.0, z, [Vector2(3.4, 0), Vector2(0, 5.0)], 10, roof)
			for i in int((w - 6.0) / 2.0):
				k.box(-hw + 1.0 + i * 2.0, 8.0, -hd, 1.0, 1.0, 2.0, wall)
			k.box(0, 0, 3.0, 12.0, 20.0, 12.0, wall.darkened(0.05))
			k.hip(0, 20.0, 3.0, 13.0, 13.0, 6.0, roof)
			k.box(0, 0, -hd - 1.05, 4.0, 5.0, 0.2, p.door)
			k.box(0, 0, -hd - 3.5, 4.0, 0.4, 5.0, Color("6b4a33"))
		"kremlin":
			_palais_with(k, wall, roof, w, d, 9.0)
			for x in [-w / 2.0 + 3.0, w / 2.0 - 3.0]:
				k.box(x, 0, -d / 2.0 + 3.0, 4.0, 18.0, 4.0, Color("a64b35"))
				k.pyramid(x, 18.0, -d / 2.0 + 3.0, 4.4, 4.4, 8.0, Color("2f6b4a"))
			k.cylinder(0, 9.0, 4.0, 3.0, 3.0, 10.0, 10, Color("f1ece2"))
			k.onion(0, 19.0, 4.0, 3.6, 6.0, Color("d9a520"), 12)
		"forum":
			# Basilique romaine.
			k.box(0, 0, 0, w - 4.0, 1.2, d - 4.0, Color("e6dcc6"))
			for i in 9:
				var x := -w / 2.0 + 3.0 + i * (w - 6.0) / 8.0
				k.cylinder(x, 1.2, -d / 2.0 + 3.0, 0.8, 0.7, 10.0, 10, Color("f6f1e7"))
			k.box(0, 1.2, 3.0, w - 8.0, 13.0, d - 12.0, wall)
			k.box(0, 11.2, -d / 2.0 + 3.0, w - 4.0, 1.2, 2.0, Color("f6f1e7"))
			k.gable(0, 14.2, 3.0, w - 7.0, d - 11.0, 3.2, roof)
			k.cylinder(0, 0, -d / 2.0 - 0.5 + 10.0, 1.0, 1.0, 0.01, 4, wall)
		"kasbah", "palais_terre", "pueblo":
			# Volumes de terre en gradins, tours d'angle.
			var tiers := 3
			for i in tiers:
				var sx := w - 4.0 - i * 8.0
				var sz := d - 4.0 - i * 8.0
				k.box(0 + i * 2.0, i * 5.0, i * 2.0, sx, 5.0, sz, wall.darkened(0.03 * i))
			for x in [-w / 2.0 + 3.0, w / 2.0 - 3.0]:
				for z in [-d / 2.0 + 3.0, d / 2.0 - 3.0]:
					k.lathe(x, 0, z, [Vector2(2.6, 0), Vector2(2.0, 16.0), Vector2(2.4, 16.5), Vector2(2.4, 17.5)], 4, wall)
			k.box(0, 0, -d / 2.0 + 1.95, 3.0, 4.5, 0.2, Color("1f6f5f") if s.palais == "kasbah" else Color("4a3222"))
			if s.get("vigas", false):
				for i in 10:
					k.box(-w / 2.0 + 4.0 + i * 3.6, 4.2, -d / 2.0 + 1.6, 0.25, 0.25, 0.8, Color("6b4a2b"))
				for i in 3:
					k.box(-6.0 + i * 6.0, 5.0, -d / 2.0 + 6.0, 0.25, 4.0, 0.25, Color("8a6a48"))
			if s.get("spikes", false):
				for i in 12:
					k.box(-w / 2.0 + 3.0 + i * 3.4, 2.5, -d / 2.0 + 1.6, 0.2, 0.2, 0.9, Color("6b4a2b"))
		"palais_dome", "palais_moghol":
			k.box(0, 0, 4.0, w - 8.0, 10.0, d - 14.0, wall)
			k.box(0, 0, -d / 2.0 + 6.0, 12.0, 16.0, 3.0, wall)
			k.box(0, 0, -d / 2.0 + 4.45, 6.0, 11.0, 0.2, Color(p.trim).darkened(0.2))
			k.cylinder(0, 10.0, 4.0, 7.0, 7.0, 4.0, 16, wall)
			if s.palais == "palais_moghol":
				k.onion(0, 14.0, 4.0, 8.0, 11.0, Color("f6f1e7"), 16)
				for x in [-w / 2.0 + 2.0, w / 2.0 - 2.0]:
					for z in [-d / 2.0 + 2.0, d / 2.0 - 2.0]:
						k.cylinder(x, 0, z, 1.0, 0.8, 22.0, 10, Color("f6f1e7"))
						k.dome(x, 22.0, z, 1.4, 1.6, Color("f6f1e7"), 8)
				k.plate(0, -d / 2.0 + 1.5, 3.0, 3.0, Color("4fb3d9"), 0.0, 0.1)
			else:
				k.onion(0, 14.0, 4.0, 7.5, 9.0, roof, 16)
				for x in [-8.0, 8.0]:
					k.dome(x, 10.0, 4.0, 3.0, 2.6, roof, 10)
		"cite_interdite", "palais_siamois":
			k.box(0, 0, 2.0, w - 4.0, 2.4, d - 10.0, Color("f2f2f2"))
			for i in 3:
				k.box(0, 2.4, 2.0, w - 8.0, 0.1, 1.0, Color("f2f2f2"))
			k.box(0, 2.4, 2.0, w - 10.0, 8.0, d - 16.0, wall)
			for i in 8:
				k.cylinder(-w / 2.0 + 6.0 + i * (w - 12.0) / 7.0, 2.4, 2.0 - (d - 16.0) / 2.0 - 1.2, 0.5, 0.5, 8.0, 8, Color("b8322a"))
			if s.palais == "cite_interdite":
				_roof(k, s, p, "curved", 0, 10.4, 2.0, w - 8.0, d - 14.0, "palais")
				_roof(k, s, p, "curved", 0, 13.5, 2.0, w - 16.0, d - 20.0, "palais")
			else:
				for i in 3:
					k.gable(0, 10.4 + i * 2.0, 2.0, w - 6.0 - i * 6.0, d - 12.0 - i * 4.0, 5.0 - i, roof if i % 2 == 0 else Color("2a6f4f"))
				k.lathe(0, 16.0, 2.0, [Vector2(1.6, 0), Vector2(0.6, 4.0), Vector2(0, 10.0)], 8, Color("d9a520"))
			k.box(0, 0, -d / 2.0 + 2.0, 12.0, 6.0, 3.0, Color("b8322a"))
			_roof(k, s, p, "curved", 0, 6.0, -d / 2.0 + 2.0, 12.0, 3.0, "palais")
		"chateau_japonais":
			# Soubassement de pierre en pente et donjon à étages.
			k.lathe(0, 0, 4.0, [Vector2(16.0, 0), Vector2(12.0, 8.0)], 4, Color("8e8a82"))
			for i in 5:
				var sz := 16.0 - i * 2.4
				k.box(0, 8.0 + i * 4.0, 4.0, sz, 3.0, sz * 0.8, Color("f4f0e6"))
				k.hip(0, 11.0 + i * 4.0, 4.0, sz + 2.6, sz * 0.8 + 2.6, 1.2, roof)
			k.box(-4.6, 32.0, 4.0, 1.0, 1.6, 0.5, Color("d9a520"))
			k.box(4.6, 32.0, 4.0, 1.0, 1.6, 0.5, Color("d9a520"))
		"palais_maya":
			for i in 3:
				k.box(0, i * 2.0, 4.0, w - 6.0 - i * 4.0, 2.0, d - 14.0 - i * 3.0, wall.darkened(0.03 * i))
			k.box(0, 6.0, 4.0, w - 18.0, 6.0, 8.0, wall)
			for i in 5:
				k.box(-w / 2.0 + 13.0 + i * (w - 26.0) / 4.0, 6.0, 4.0 - 4.05, 1.6, 3.0, 0.2, Color("3a3028"))
			k.box(0, 12.0, 4.0, w - 20.0, 3.5, 2.0, Color(p.trim))
			k.box(0, 0, -d / 2.0 + 6.0, 10.0, 6.0, 10.0, wall.lightened(0.05))
		"kraal":
			_concession(k, s, p, w, d)
		"capitole":
			k.box(0, 0, 4.0, w - 6.0, 12.0, d - 14.0, wall)
			for i in 6:
				k.cylinder(-7.5 + i * 3.0, 1.0, -d / 2.0 + 7.0, 0.6, 0.6, 10.0, 10, Color("f6f4ee"))
			k.box(0, 0, -d / 2.0 + 7.0, 18.0, 1.0, 4.0, Color("e9e2d4"))
			k.box(0, 11.0, -d / 2.0 + 7.0, 18.0, 1.0, 4.0, wall)
			k.gable(0, 12.0, -d / 2.0 + 7.0, 18.4, 4.4, 2.6, wall.lightened(0.1))
			k.cylinder(0, 12.0, 4.0, 7.0, 7.0, 6.0, 16, wall)
			k.dome(0, 18.0, 4.0, 7.2, 7.0, Color("f6f4ee"), 16)
			k.cylinder(0, 25.0, 4.0, 1.2, 1.0, 3.0, 8, Color("f6f4ee"))
		"palazzo", "palacio":
			_palais_with(k, wall, roof, w, d, 12.0)
			k.box(0, 0, -d / 2.0 + 2.9, 5.0, 5.0, 0.2, p.door)
			for i in 3:
				k.windows_row(0, -d / 2.0 + 3.0, w - 8.0, 2.0 + i * 3.5, 7, 1.2, 2.0, Color("33495e"))
			k.box(0, 12.0, -d / 2.0 + 3.0, w - 4.0, 0.8, 1.2, trim)
		_:
			# Hôtel de ville : façade symétrique, beffroi.
			_palais_with(k, wall, roof, w, d, 12.0)
			k.box(0, 0, -d / 2.0 + 4.0, 7.0, 26.0, 7.0, wall)
			k.pyramid(0, 26.0, -d / 2.0 + 4.0, 7.6, 7.6, 7.0, roof)
			k.cylinder(0, 21.0, -d / 2.0 + 0.45, 1.6, 1.6, 0.1, 14, Color("fdfdfd"))
			k.box(0, 0, -d / 2.0 + 0.45, 3.0, 4.0, 0.2, p.door)
			k.windows_row(0, -d / 2.0 + 3.0, w - 10.0, 2.0, 8, 1.4, 2.4, Color("33495e"))
			k.windows_row(0, -d / 2.0 + 3.0, w - 10.0, 7.0, 8, 1.4, 2.4, Color("33495e"))


static func _palais_with(k: BlocMesh, wall: Color, roof: Color, w: float, d: float, h: float) -> void:
	k.box(0, 0, 0, w - 4.0, h, d - 6.0, wall)
	k.hip(0, h, 0, w - 3.0, d - 5.0, 3.0, roof)
	k.box(0, 0, 0, w - 16.0, h + 2.0, d - 18.0, wall.darkened(0.04))
