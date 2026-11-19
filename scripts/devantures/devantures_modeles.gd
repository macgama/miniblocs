class_name DevanturesModeles
extends RefCounted
## Maillages des devantures (voir Devantures), en low-poly fait en code.
##
## Repère d'une devanture : origine au pied de la façade, au milieu de la
## vitrine ; −Z sort vers la rue, +Z entre dans le bâtiment (la niche creusée
## dans la façade). Couches : "base" (couleurs par sommet), "lumiere"
## (plafonniers, néons : brillent le soir), "vitre" (verre).
##
## Tous les maillages sont mis en cache par clé : deux boulangeries de même
## taille, à la même époque et au même remplissage partagent leurs maillages.

const BOIS := Color("8a5a35")
const BOIS_CLAIR := Color("c49a6c")
const METAL := Color("9aa3ad")
const SOMBRE := Color("34383d")
const BLANC := Color("f2f0ea")

static var _cache := {}
static var _mats := {}


static func _kit(seed_value := 11) -> LpKit:
	var k := LpKit.new(seed_value)
	k.jitter = 0.03
	return k


# --- Matériaux --------------------------------------------------------------------------

## Couleurs par sommet, éclairées par la scène.
static func mat_base() -> Material:
	if not _mats.has("base"):
		_mats["base"] = LpKit.vertex_material(0.85)
	return _mats.base


## Lampes, néons, intérieur éclairé : `allume` les fait briller (le soir).
static func mat_lumiere(allume: bool) -> Material:
	var key := "lum_%d" % int(allume)
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		m.roughness = 0.6
		if allume:
			m.emission_enabled = true
			m.emission = Color(1.0, 0.86, 0.62)
			m.emission_energy_multiplier = 2.2
		_mats[key] = m
	return _mats[key]


## Verre de la vitrine : transparent, un peu de reflet.
static func mat_vitre() -> Material:
	if not _mats.has("vitre"):
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.78, 0.88, 0.92, 0.16)
		m.roughness = 0.05
		m.metallic = 0.2
		m.metallic_specular = 0.9
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mats["vitre"] = m
	return _mats.vitre


## Intérieur un peu éclairé (salle, rayons) : brille doucement le soir.
static func mat_interieur(allume: bool) -> Material:
	var key := "int_%d" % int(allume)
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		m.roughness = 0.85
		if allume:
			m.emission_enabled = true
			m.emission = Color(1.0, 0.8, 0.55)
			m.emission_energy_multiplier = 0.35
		_mats[key] = m
	return _mats[key]


static func _commit(k: LpKit) -> ArrayMesh:
	return k.commit({"base": mat_base(), "lumiere": mat_lumiere(false), "vitre": mat_vitre()})


# --- Niche et façade de boutique -----------------------------------------------------------

## Disposition de la façade : porte à droite, vitrine à gauche.
static func porte_x(w: float) -> float:
	return w * 0.5 - 0.3 - 0.55


## Niche creusée dans la façade : sol, plafond, murs, mur du fond, cadre de
## la devanture (piliers, bandeau d'enseigne, allège), porte. `genre` règle
## l'allège (pas d'allège pour un hall) ; `st` : DevanturesTypes.style.
static func coquille(w: float, h: float, d: float, fond: Color, st: Dictionary, genre: String) -> ArrayMesh:
	var key := "coq|%.1f|%.1f|%.1f|%s|%s|%s" % [w, h, d, fond.to_html(false), String(st.id), genre]
	if _cache.has(key):
		return _cache[key]
	var k := _kit(3)
	var cadre: Color = st.cadre
	var sol := Color("b9a58a") if String(st.id) in ["ancien", "belle_epoque"] else Color("c9c6bf")
	if genre == DevanturesTypes.SALLE:
		sol = Color("8f5f3c")
	# Intérieur.
	k.box(Vector3(0, 0.06, d * 0.5), Vector3(w, 0.12, d), sol)
	k.box(Vector3(0, h + 0.05, d * 0.5), Vector3(w, 0.1, d), BLANC.darkened(0.04))
	k.box(Vector3(0, h * 0.5, d + 0.05), Vector3(w, h, 0.1), fond)
	k.box(Vector3(-w * 0.5 - 0.05, h * 0.5, d * 0.5), Vector3(0.1, h, d), fond.darkened(0.08))
	k.box(Vector3(w * 0.5 + 0.05, h * 0.5, d * 0.5), Vector3(0.1, h, d), fond.darkened(0.08))
	# Plinthes et corniche intérieure.
	k.box(Vector3(0, 0.18, d - 0.01), Vector3(w, 0.12, 0.04), fond.darkened(0.3))
	# Plafonniers (couche lumière).
	k.layer = "lumiere"
	var n := maxi(1, int(w / 2.2))
	for i in n:
		var x := -w * 0.5 + (float(i) + 0.5) * w / n
		if String(st.id) == "ancien":
			k.tube(Vector3(x, h - 0.5, d * 0.5), Vector3(x, h - 0.2, d * 0.5), 0.12, 0.05, 6, Color("ffd38a"))
		elif bool(st.neon):
			k.box(Vector3(x, h - 0.04, d * 0.5), Vector3(1.2, 0.05, 0.16), Color("f4f8ff"))
		else:
			k.box(Vector3(x, h - 0.03, d * 0.5), Vector3(0.5, 0.04, 0.5), Color("fff3dc"))
	k.layer = "base"
	# Cadre de la devanture (en applique, légèrement en saillie).
	var pil := 0.3
	k.box(Vector3(-w * 0.5 + pil * 0.5, h * 0.5, -0.06), Vector3(pil, h + 0.02, 0.16), cadre)
	k.box(Vector3(w * 0.5 - pil * 0.5, h * 0.5, -0.06), Vector3(pil, h + 0.02, 0.16), cadre)
	# Bandeau d'enseigne.
	k.box(Vector3(0, h - 0.32, -0.1), Vector3(w + 0.1, 0.64, 0.2), st.bandeau)
	k.box(Vector3(0, h + 0.02, -0.12), Vector3(w + 0.2, 0.06, 0.26), cadre.darkened(0.2))
	k.box(Vector3(0, h - 0.66, -0.11), Vector3(w + 0.1, 0.05, 0.22), cadre.darkened(0.2))
	# Porte : chambranle et seuil.
	var px := porte_x(w)
	var ph := minf(2.3, h - 0.7)
	k.box(Vector3(px - 0.55, ph * 0.5, -0.03), Vector3(0.08, ph, 0.1), cadre)
	k.box(Vector3(px + 0.55, ph * 0.5, -0.03), Vector3(0.08, ph, 0.1), cadre)
	k.box(Vector3(px, ph + 0.04, -0.03), Vector3(1.18, 0.08, 0.1), cadre)
	k.box(Vector3(px, 0.04, -0.15), Vector3(1.2, 0.08, 0.3), Color("a7a39b"))
	# Imposte au-dessus de la porte et de la vitrine (entre porte et bandeau).
	k.box(Vector3(0, h - 0.68, -0.02), Vector3(w - 2.0 * pil, 0.04, 0.08), cadre)
	# Allège sous la vitrine (pas devant la porte), sauf pour les halls.
	var vg := -w * 0.5 + pil
	var vd := px - 0.6
	if genre != DevanturesTypes.HALL and vd > vg + 0.3:
		k.box(Vector3((vg + vd) * 0.5, 0.3, -0.04), Vector3(vd - vg, 0.6, 0.14), cadre.darkened(0.1))
	# Petits bois des vitrines anciennes.
	if bool(st.carreaux) and vd > vg + 0.3:
		var y0 := 0.6
		var y1 := h - 0.7
		var nx := maxi(2, int((vd - vg) / 0.5))
		for i in range(1, nx):
			var x := vg + (vd - vg) * float(i) / nx
			k.box(Vector3(x, (y0 + y1) * 0.5, 0.0), Vector3(0.04, y1 - y0, 0.05), cadre)
		for j in range(1, 3):
			var y := y0 + (y1 - y0) * float(j) / 3.0
			k.box(Vector3((vg + vd) * 0.5, y, 0.0), Vector3(vd - vg, 0.04, 0.05), cadre)
	# Néon de la vitrine (années 1925-1979).
	if bool(st.neon):
		k.layer = "lumiere"
		k.box(Vector3(0, h - 0.06, -0.21), Vector3(w * 0.8, 0.04, 0.04), Color("ffe0f0"))
		k.layer = "base"
	var m := _commit(k)
	_cache[key] = m
	return m


## Vitres (couche à part, transparente) : vitrine et porte vitrée.
static func vitres(w: float, h: float, genre: String) -> ArrayMesh:
	var key := "vit|%.1f|%.1f|%s" % [w, h, genre]
	if _cache.has(key):
		return _cache[key]
	var k := _kit(4)
	k.jitter = 0.0
	k.layer = "vitre"
	var pil := 0.3
	var px := porte_x(w)
	var vg := -w * 0.5 + pil
	var vd := px - 0.6
	var y0 := 0.05 if genre == DevanturesTypes.HALL else 0.6
	var y1 := h - 0.7
	if vd > vg + 0.3:
		k.box(Vector3((vg + vd) * 0.5, (y0 + y1) * 0.5, 0.0), Vector3(vd - vg, y1 - y0, 0.02), Color(1, 1, 1))
	var ph := minf(2.3, h - 0.7)
	k.box(Vector3(px, ph * 0.5 + 0.05, 0.0), Vector3(1.0, ph - 0.1, 0.02), Color(1, 1, 1))
	var m := _commit(k)
	_cache[key] = m
	return m


# --- Contenu de la vitrine -------------------------------------------------------------------

## Intérieur d'une boutique : présentoir derrière la vitrine, étagères du fond,
## comptoir et caisse ; objets exposés selon le palier de stock (0 à 4) de
## chacun. `objets` : noms ; `paliers` : même longueur.
static func boutique(w: float, h: float, d: float, objets: Array, paliers: Array, annee: int) -> ArrayMesh:
	var key := "bout|%.1f|%.1f|%.1f|%s|%s|%d" % [w, h, d, ",".join(objets), ",".join(paliers.map(func(p): return str(p))), annee / 20]
	if _cache.has(key):
		return _cache[key]
	var k := _kit(hash(key) & 0xffff)
	var pil := 0.3
	var px := porte_x(w)
	var vg := -w * 0.5 + pil + 0.1
	var vd := px - 0.7
	var bois := BOIS_CLAIR if annee < 1960 else Color("e3e1dc")
	# Présentoir à gradins derrière la vitrine.
	if vd > vg + 0.4:
		k.box(Vector3((vg + vd) * 0.5, 0.62, 0.38), Vector3(vd - vg, 0.04, 0.6), bois)
		k.box(Vector3((vg + vd) * 0.5, 0.95, 0.62), Vector3(vd - vg, 0.04, 0.3), bois)
		k.box(Vector3((vg + vd) * 0.5, 0.78, 0.76), Vector3(vd - vg, 0.34, 0.04), bois.darkened(0.15))
	# Étagères du fond.
	var ex0 := -w * 0.5 + 0.2
	var ex1 := w * 0.5 - 0.2
	for j in 4:
		k.box(Vector3(0, 0.45 + j * 0.5, d - 0.25), Vector3(ex1 - ex0, 0.04, 0.4), bois)
	k.box(Vector3(ex0, 1.2, d - 0.25), Vector3(0.04, 2.3, 0.4), bois.darkened(0.2))
	k.box(Vector3(ex1, 1.2, d - 0.25), Vector3(0.04, 2.3, 0.4), bois.darkened(0.2))
	# Comptoir et caisse (à droite, devant la porte de l'arrière-boutique).
	var cz := clampf(d * 0.55, 1.0, d - 0.9)
	var cw := minf(2.2, w * 0.4)
	var cx := -w * 0.5 + 0.3 + cw * 0.5 if w > 3.5 else 0.0
	k.box(Vector3(cx, 0.5, cz), Vector3(cw, 1.0, 0.55), bois.darkened(0.25))
	k.box(Vector3(cx, 1.02, cz), Vector3(cw + 0.06, 0.05, 0.6), bois.lightened(0.1))
	if annee >= 1890:
		k.box(Vector3(cx + cw * 0.3, 1.15, cz), Vector3(0.35, 0.22, 0.3), SOMBRE if annee >= 1970 else Color("b08d3a"))
	# Objets : sur le présentoir, puis sur les étagères.
	var slots := []
	if vd > vg + 0.4:
		var nf := maxi(2, int((vd - vg) / 0.45))
		for i in nf:
			var x := vg + (vd - vg) * (float(i) + 0.5) / nf
			slots.append(Vector3(x, 0.64, 0.3))
			slots.append(Vector3(x, 0.97, 0.62))
	var ns := maxi(2, int((ex1 - ex0) / 0.45))
	for j in 4:
		for i in ns:
			var x := ex0 + (ex1 - ex0) * (float(i) + 0.5) / ns
			slots.append(Vector3(x, 0.47 + j * 0.5, d - 0.25))
	var no := maxi(objets.size(), 1)
	for si in slots.size():
		var oi := si % no
		if oi >= objets.size():
			continue
		var pal := int(paliers[oi])
		# Le palier (0 à 4) garde 0, 1, 2, 3 ou 4 places sur 4 occupées.
		if (si / no) % 4 >= pal:
			continue
		var p: Vector3 = slots[si]
		# Les gros objets restent sur le sol ou le présentoir bas.
		var o := String(objets[oi])
		if o in ["mannequin", "portant", "fauteuil", "voiture", "lampe", "fleurs", "plantes", "cagette"] and p.y > 1.0:
			continue
		objet(k, o, p, si)
	var m := _commit(k)
	_cache[key] = m
	return m


## Salle de café ou de restaurant : comptoir, tables, banquette, ardoises.
static func salle(w: float, h: float, d: float, annee: int, garni: float) -> ArrayMesh:
	var key := "salle|%.1f|%.1f|%.1f|%d|%d" % [w, h, d, annee / 20, int(garni * 4.0)]
	if _cache.has(key):
		return _cache[key]
	var k := _kit(21)
	var bois := BOIS if annee < 1960 else Color("6f6a64")
	# Comptoir au fond, avec bouteilles et percolateur.
	k.box(Vector3(0, 0.55, d - 0.55), Vector3(w * 0.7, 1.1, 0.6), bois.darkened(0.1))
	k.box(Vector3(0, 1.12, d - 0.55), Vector3(w * 0.7 + 0.1, 0.05, 0.66), METAL if annee >= 1900 else BOIS_CLAIR)
	var nb := int(w * 2.0 * clampf(garni, 0.2, 1.0))
	for i in nb:
		var x := -w * 0.35 + 0.15 + (w * 0.7 - 0.3) * float(i) / maxf(nb - 1, 1)
		k.tube(Vector3(x, 1.6, d - 0.12), Vector3(x, 1.88, d - 0.12), 0.04, 0.02, 5,
			Color.from_hsv(fmod(0.08 + i * 0.17, 1.0), 0.55, 0.55))
	k.box(Vector3(0, 1.55, d - 0.1), Vector3(w * 0.7, 0.03, 0.18), bois)
	if annee >= 1900:
		k.box(Vector3(w * 0.2, 1.3, d - 0.55), Vector3(0.4, 0.3, 0.3), METAL.lightened(0.2))
	# Tables rondes et chaises.
	var nt := maxi(1, int(w / 1.8))
	for i in nt:
		var x := -w * 0.5 + (float(i) + 0.5) * w / nt
		var z := minf(0.9, d * 0.4)
		_table(k, Vector3(x, 0, z), annee)
	# Miroir ou ardoise au mur de côté.
	k.box(Vector3(-w * 0.5 + 0.02, 1.7, d * 0.5), Vector3(0.03, 0.8, minf(d * 0.6, 1.6)), Color("2c3e36") if annee < 1980 else Color("9fb3bf"))
	var m := _commit(k)
	_cache[key] = m
	return m


## Hall d'accueil : comptoir ou guichet, plantes, affiches, banc.
static func hall(w: float, h: float, d: float, accueil: String, annee: int, fond: Color) -> ArrayMesh:
	var key := "hall|%.1f|%.1f|%.1f|%s|%d" % [w, h, d, accueil, annee / 20]
	if _cache.has(key):
		return _cache[key]
	var k := _kit(31)
	var bois := BOIS if annee < 1950 else Color("d9d6cf")
	var cz := clampf(d * 0.6, 1.2, d - 0.6)
	match accueil:
		"guichet":
			k.box(Vector3(0, 0.55, cz), Vector3(w * 0.7, 1.1, 0.5), bois)
			k.box(Vector3(0, 1.12, cz), Vector3(w * 0.7 + 0.1, 0.05, 0.55), bois.lightened(0.15))
			var ng := maxi(1, int(w * 0.7 / 1.4))
			for i in ng:
				var x := -w * 0.35 + (float(i) + 0.5) * w * 0.7 / ng
				k.box(Vector3(x, 1.6, cz), Vector3(0.04, 0.9, 0.5), METAL)
				k.layer = "vitre"
				k.box(Vector3(x + 0.5, 1.6, cz - 0.2), Vector3(0.9, 0.8, 0.02), Color.WHITE)
				k.layer = "base"
		"reception":
			k.box(Vector3(-w * 0.15, 0.55, cz), Vector3(minf(2.4, w * 0.45), 1.1, 0.6), BOIS.darkened(0.2))
			k.box(Vector3(-w * 0.15, 1.12, cz), Vector3(minf(2.5, w * 0.47), 0.05, 0.65), Color("b08d3a"))
			k.box(Vector3(-w * 0.15, 1.75, d - 0.02), Vector3(1.2, 0.8, 0.04), Color("3d2b1f"))
			for i in 6:
				k.box(Vector3(-w * 0.15 - 0.45 + (i % 3) * 0.45, 1.55 + (i / 3) * 0.35, d - 0.06), Vector3(0.06, 0.12, 0.03), Color("e6c35c"))
			_fauteuil(k, Vector3(w * 0.3, 0, 0.9), Color("7b241c"))
		"affiches":
			for i in 3:
				var x := -w * 0.35 + i * w * 0.35
				k.box(Vector3(x, 1.6, d - 0.02), Vector3(0.7, 1.0, 0.03), Color.from_hsv(fmod(0.05 + i * 0.31, 1.0), 0.6, 0.75))
				k.box(Vector3(x, 1.6, d - 0.04), Vector3(0.78, 1.08, 0.02), SOMBRE)
			k.box(Vector3(w * 0.25, 0.5, cz), Vector3(1.4, 1.0, 0.5), bois)
		_:
			k.box(Vector3(w * 0.2, 0.5, cz), Vector3(minf(2.0, w * 0.4), 1.0, 0.55), bois)
			k.box(Vector3(w * 0.2, 1.02, cz), Vector3(minf(2.1, w * 0.42), 0.04, 0.6), bois.lightened(0.2))
			k.box(Vector3(-w * 0.3, 1.5, d - 0.02), Vector3(1.0, 0.6, 0.03), fond.darkened(0.4))
	# Plantes en pot de part et d'autre.
	_plante(k, Vector3(-w * 0.5 + 0.45, 0, 0.5))
	if w > 3.0:
		_plante(k, Vector3(w * 0.5 - 0.45, 0, d - 0.5))
	# Banc d'attente.
	if accueil == "guichet" and w > 3.2:
		k.box(Vector3(-w * 0.25, 0.42, 0.6), Vector3(1.4, 0.06, 0.4), bois)
		k.box(Vector3(-w * 0.25, 0.2, 0.6), Vector3(1.3, 0.4, 0.3), bois.darkened(0.3))
	var m := _commit(k)
	_cache[key] = m
	return m


# --- Abords : store, terrasse, étal, ardoise, stock, logement ---------------------------------

## Store banne : déplié (toile inclinée sur ses bras) ou replié dans son coffre.
static func store(w: float, h: float, couleur: Color, deplie: bool, raye: bool) -> ArrayMesh:
	var key := "store|%.1f|%.1f|%s|%d|%d" % [w, h, couleur.to_html(false), int(deplie), int(raye)]
	if _cache.has(key):
		return _cache[key]
	var k := _kit(41)
	k.jitter = 0.01
	var y := h + 0.15
	k.box(Vector3(0, y, -0.2), Vector3(w, 0.18, 0.2), couleur.darkened(0.35))
	if deplie:
		var avance := clampf(w * 0.35, 1.2, 2.2)
		var chute := 0.55
		var n := maxi(2, int(w / 0.5))
		for i in n:
			var x0 := -w * 0.5 + w * float(i) / n
			var x1 := -w * 0.5 + w * float(i + 1) / n
			var c := couleur if (not raye or i % 2 == 0) else BLANC
			k.quad(Vector3(x0, y, -0.25), Vector3(x1, y, -0.25), Vector3(x1, y - chute, -0.25 - avance), Vector3(x0, y - chute, -0.25 - avance), c, Vector3(0, 1, -0.4))
			k.quad(Vector3(x0, y, -0.25), Vector3(x0, y - chute, -0.25 - avance), Vector3(x1, y - chute, -0.25 - avance), Vector3(x1, y, -0.25), c.darkened(0.3), Vector3(0, -1, 0.4))
			# Lambrequin festonné.
			k.box(Vector3((x0 + x1) * 0.5, y - chute - 0.12, -0.25 - avance), Vector3((x1 - x0) * 0.96, 0.24, 0.02), c.darkened(0.08))
		for sx in [-1.0, 1.0]:
			k.beam(Vector3(sx * (w * 0.5 - 0.1), y - 0.05, -0.2), Vector3(sx * (w * 0.5 - 0.1), y - chute, -0.25 - avance), 0.04, 0.04, METAL)
	var m := _commit(k)
	_cache[key] = m
	return m


## Terrasse : `n` tables avec chaises et parasols, devant la devanture.
static func terrasse(w: float, n: int, annee: int, parasols: bool) -> ArrayMesh:
	var key := "terr|%.1f|%d|%d|%d" % [w, n, annee / 20, int(parasols)]
	if _cache.has(key):
		return _cache[key]
	var k := _kit(51)
	for i in n:
		var x := -w * 0.5 + 0.7 + (w - 1.4) * (float(i) + 0.5) / n
		var z := -1.2 - float(i % 2) * 0.9
		_table(k, Vector3(x, 0, z), annee)
		if parasols and i % 2 == 0:
			k.tube(Vector3(x, 0.75, z), Vector3(x, 2.3, z), 0.025, 0.025, 4, BLANC)
			k.lathe(Vector3(x, 2.05, z), [Vector2(1.0, 0.0), Vector2(0.05, 0.35)], 8, Color("c0392b") if annee < 1990 else Color("e8e2d0"), true, false)
	# Jardinières qui délimitent la terrasse.
	if annee >= 1950:
		for sx in [-1.0, 1.0]:
			k.box(Vector3(sx * (w * 0.5 - 0.2), 0.25, -1.6), Vector3(0.35, 0.5, 1.6), Color("7d6b5d"))
			k.blob(Vector3(sx * (w * 0.5 - 0.2), 0.62, -1.6), Vector3(0.22, 0.2, 0.75), Color("3d7a35"), Color("6aa84f"), 0.2, 0)
	var m := _commit(k)
	_cache[key] = m
	return m


## Étal dehors (fleurs, cagettes, livres) contre la vitrine, garni selon le palier.
static func etal(objets: Array, palier: int, w: float) -> ArrayMesh:
	var key := "etal|%s|%d|%.1f" % [",".join(objets), palier, w]
	if _cache.has(key):
		return _cache[key]
	var k := _kit(61)
	var lw := minf(w * 0.5, 2.6)
	var x0 := -w * 0.5 + 0.4 + lw * 0.5
	k.box(Vector3(x0, 0.4, -0.55), Vector3(lw, 0.05, 0.6), BOIS_CLAIR)
	k.box(Vector3(x0, 0.68, -0.4), Vector3(lw, 0.05, 0.3), BOIS_CLAIR)
	for sx in [-1.0, 1.0]:
		k.box(Vector3(x0 + sx * lw * 0.48, 0.35, -0.55), Vector3(0.05, 0.7, 0.6), BOIS)
	var n := maxi(2, int(lw / 0.42))
	var no := maxi(objets.size(), 1)
	for i in n * 2:
		if (i / no) % 4 >= palier:
			continue
		var x := x0 - lw * 0.5 + lw * (float(i % n) + 0.5) / n
		var p := Vector3(x, 0.43, -0.62) if i < n else Vector3(x, 0.71, -0.4)
		objet(k, String(objets[i % no]), p, i)
	var m := _commit(k)
	_cache[key] = m
	return m


## Ardoise sur pied (chevalet) posée sur le trottoir.
static func ardoise() -> ArrayMesh:
	if _cache.has("ardoise"):
		return _cache.ardoise
	var k := _kit(71)
	k.beam(Vector3(-0.28, 0, -0.18), Vector3(-0.25, 0.95, 0.0), 0.04, 0.03, BOIS)
	k.beam(Vector3(0.28, 0, -0.18), Vector3(0.25, 0.95, 0.0), 0.04, 0.03, BOIS)
	k.beam(Vector3(-0.28, 0, 0.18), Vector3(-0.25, 0.95, 0.0), 0.04, 0.03, BOIS)
	k.beam(Vector3(0.28, 0, 0.18), Vector3(0.25, 0.95, 0.0), 0.04, 0.03, BOIS)
	var xf := Transform3D(Basis(Vector3.RIGHT, 0.19), Vector3(0, 0.52, -0.09))
	k.xf = xf
	k.box(Vector3.ZERO, Vector3(0.5, 0.75, 0.025), Color("2b2f2c"))
	k.xf = Transform3D.IDENTITY
	var m := _commit(k)
	_cache["ardoise"] = m
	return m


## Fermeture de la devanture : "volets" (panneaux de bois), "plein" (rideau
## de fer à lames) ou "grille" (mailles : on voit la vitrine derrière).
static func rideau(w: float, h: float, sorte: String) -> ArrayMesh:
	var key := "rid|%.1f|%.1f|%s" % [w, h, sorte]
	if _cache.has(key):
		return _cache[key]
	var k := _kit(111)
	k.jitter = 0.01
	var pil := 0.3
	var lw := w - 2.0 * pil
	var top := h - 0.7
	var z := -0.12
	match sorte:
		"volets":
			var n := maxi(2, int(lw / 0.6))
			for i in n:
				var x := -lw * 0.5 + lw * (float(i) + 0.5) / n
				k.box(Vector3(x, top * 0.5, z), Vector3(lw / n - 0.03, top, 0.05), Color("4a6741"))
				k.box(Vector3(x, top * 0.75, z - 0.03), Vector3(lw / n - 0.12, 0.05, 0.02), Color("3b5334"))
				k.box(Vector3(x, top * 0.25, z - 0.03), Vector3(lw / n - 0.12, 0.05, 0.02), Color("3b5334"))
			k.box(Vector3(0, top * 0.5, z - 0.05), Vector3(lw, 0.06, 0.03), SOMBRE)
		"grille":
			var nx := int(lw / 0.18)
			for i in nx + 1:
				var x := -lw * 0.5 + lw * float(i) / nx
				k.box(Vector3(x, top * 0.5, z), Vector3(0.015, top, 0.015), METAL)
			for j in int(top / 0.18) + 1:
				k.box(Vector3(0, float(j) * 0.18, z), Vector3(lw, 0.015, 0.015), METAL)
			k.box(Vector3(0, top + 0.06, z), Vector3(lw + 0.1, 0.14, 0.18), Color("6c737a"))
		_:
			k.box(Vector3(0, top * 0.5, z), Vector3(lw, top, 0.05), Color("8d949b"))
			for i in int(top / 0.12):
				k.box(Vector3(0, 0.06 + i * 0.12, z - 0.03), Vector3(lw, 0.02, 0.02), Color("6c737a"))
			k.box(Vector3(0, top + 0.06, z), Vector3(lw + 0.1, 0.14, 0.18), Color("5c636a"))
	var m := _commit(k)
	_cache[key] = m
	return m


## Enseigne en potence (drapeau perpendiculaire à la façade), d'époque.
static func potence(couleur: Color, cadre: Color) -> ArrayMesh:
	var key := "pot|%s|%s" % [couleur.to_html(false), cadre.to_html(false)]
	if _cache.has(key):
		return _cache[key]
	var k := _kit(81)
	k.beam(Vector3(0, 0, 0), Vector3(0, 0, -0.9), 0.04, 0.04, cadre)
	k.beam(Vector3(0, -0.25, 0), Vector3(0, 0, -0.6), 0.03, 0.03, cadre)
	k.box(Vector3(0, -0.35, -0.55), Vector3(0.04, 0.55, 0.6), couleur)
	var m := _commit(k)
	_cache[key] = m
	return m


## Marchandise empilée devant une entreprise, selon le palier de stock.
static func stock_dehors(objets: Array, palier: int, w: float) -> ArrayMesh:
	var key := "stock|%s|%d|%.1f" % [",".join(objets), palier, w]
	if _cache.has(key):
		return _cache[key]
	var k := _kit(91)
	var n := mini(int(w / 1.6), 8)
	var no := maxi(objets.size(), 1)
	for i in n:
		var niveaux := palier
		var x := -w * 0.5 + 1.0 + 1.5 * float(i)
		for j in niveaux:
			if (i + j) % 3 == 2 and j == niveaux - 1:
				continue
			objet(k, String(objets[(i + j) % no]), Vector3(x, 0.0, -1.2), i * 7 + j, j)
	var m := _commit(k)
	_cache[key] = m
	return m


## Entrée d'un logement : plaque, lampe (couche lumière), jardinière fleurie.
static func logis(w: float, annee: int, fleurs: bool) -> ArrayMesh:
	var key := "logis|%.1f|%d|%d" % [w, annee / 30, int(fleurs)]
	if _cache.has(key):
		return _cache[key]
	var k := _kit(101)
	# Plaque.
	k.box(Vector3(0.75, 1.45, -0.03), Vector3(0.36, 0.22, 0.03), Color("d4af37") if annee < 1960 else Color("e8e8e8"))
	# Lampe d'entrée.
	k.box(Vector3(-0.75, 2.35, -0.08), Vector3(0.06, 0.06, 0.16), SOMBRE)
	k.layer = "lumiere"
	if annee < 1900:
		k.box(Vector3(-0.75, 2.28, -0.2), Vector3(0.16, 0.24, 0.16), Color("ffd38a"))
	else:
		k.tube(Vector3(-0.75, 2.2, -0.2), Vector3(-0.75, 2.38, -0.2), 0.09, 0.05, 6, Color("fff1d6"))
	k.layer = "base"
	# Jardinières sous les fenêtres du rez-de-chaussée.
	if fleurs:
		for sx in [-1.0, 1.0]:
			var x: float = sx * clampf(w * 0.3, 1.2, 3.0)
			k.box(Vector3(x, 0.92, -0.14), Vector3(0.9, 0.2, 0.22), Color("a0522d"))
			for i in 4:
				var c := Color.from_hsv(fmod(0.95 + i * 0.13 + sx * 0.05, 1.0), 0.65, 0.9)
				k.blob(Vector3(x - 0.33 + i * 0.22, 1.08, -0.14), Vector3(0.1, 0.09, 0.09), Color("3d7a35"), c, 0.25, 0)
	var m := _commit(k)
	_cache[key] = m
	return m


# --- Objets ----------------------------------------------------------------------------------

## Pose un objet de vitrine à `p` (posé sur la surface en p.y). `i` varie les teintes.
static func objet(k: LpKit, nom: String, p: Vector3, i: int, niveau := 0) -> void:
	var r := float((i * 37) % 11) / 11.0
	match nom:
		"baguette":
			for j in 3:
				k.beam(p + Vector3(-0.17, 0.04 + j * 0.05, -0.05 + j * 0.05), p + Vector3(0.17, 0.05 + j * 0.05, 0.02 + j * 0.03), 0.06, 0.05, Color("c8893e"))
		"miche":
			k.blob(p + Vector3(0, 0.07, 0), Vector3(0.14, 0.08, 0.12), Color("9a5b26"), Color("d39a52"), 0.12, 0)
		"croissant":
			for j in 3:
				var q := p + Vector3(-0.12 + j * 0.12, 0.03, 0.0)
				k.beam(q + Vector3(-0.05, 0, 0.03), q + Vector3(0.05, 0, -0.02), 0.06, 0.05, Color("d9a14d"))
		"gateau":
			k.tube(p, p + Vector3(0, 0.1, 0), 0.13, 0.13, 8, Color("f3e1c7"))
			k.tube(p + Vector3(0, 0.1, 0), p + Vector3(0, 0.12, 0), 0.13, 0.12, 8, Color.from_hsv(0.95 - r * 0.2, 0.5, 0.85))
		"jambon":
			k.tube(p + Vector3(0, 0.0, 0), p + Vector3(0, 0.3, 0), 0.06, 0.1, 6, Color("a8483d"))
		"viande":
			k.box(p + Vector3(0, 0.02, 0), Vector3(0.34, 0.03, 0.24), BLANC)
			k.blob(p + Vector3(0, 0.06, 0), Vector3(0.13, 0.04, 0.09), Color("8e2a2a"), Color("c0504d"), 0.2, 0)
		"saucisson":
			for j in 3:
				k.beam(p + Vector3(-0.15, 0.03, -0.06 + j * 0.06), p + Vector3(0.15, 0.03, -0.06 + j * 0.06), 0.05, 0.05, Color("7a3b2e"))
		"poisson":
			k.box(p + Vector3(0, 0.03, 0), Vector3(0.38, 0.05, 0.3), Color("e8f4f8"))
			for j in 2:
				k.blob(p + Vector3(0, 0.08, -0.06 + j * 0.12), Vector3(0.15, 0.03, 0.04), Color("6c7a89"), Color("b8c7d3"), 0.1, 0)
		"fromage":
			k.tube(p, p + Vector3(0, 0.12, 0), 0.14, 0.14, 8, Color("f2d27a"))
		"cagette":
			k.box(p + Vector3(0, 0.08, 0), Vector3(0.38, 0.16, 0.3), BOIS_CLAIR)
			var fc: Color = [Color("e74c3c"), Color("f39c12"), Color("27ae60"), Color("f1c40f"), Color("8e44ad")][i % 5]
			k.blob(p + Vector3(0, 0.18, 0), Vector3(0.17, 0.05, 0.13), fc.darkened(0.2), fc, 0.3, 0)
		"bocaux", "conserves", "flacons", "bouteilles":
			var n := 4 if nom == "bouteilles" else 3
			for j in n:
				var q := p + Vector3(-0.15 + j * 0.1, 0, 0.0)
				match nom:
					"bouteilles":
						k.tube(q, q + Vector3(0, 0.26, 0), 0.035, 0.03, 5, Color.from_hsv(0.3 + r * 0.1, 0.6, 0.35))
						k.tube(q + Vector3(0, 0.26, 0), q + Vector3(0, 0.33, 0), 0.015, 0.012, 4, SOMBRE)
					"bocaux":
						k.tube(q, q + Vector3(0, 0.14, 0), 0.045, 0.045, 6, Color.from_hsv(0.08 + j * 0.1, 0.6, 0.75))
					"conserves":
						k.tube(q, q + Vector3(0, 0.11, 0), 0.04, 0.04, 6, Color.from_hsv(r + j * 0.2, 0.55, 0.8))
					_:
						k.box(q + Vector3(0, 0.08, 0), Vector3(0.06, 0.16, 0.05), Color.from_hsv(0.5 + j * 0.1, 0.3, 0.9))
		"boites", "oeufs":
			for j in 3:
				k.box(p + Vector3(-0.13 + j * 0.13, 0.06, 0), Vector3(0.11, 0.12, 0.08), Color("f4f4f4") if nom == "oeufs" else Color.from_hsv(fmod(r + j * 0.33, 1.0), 0.45, 0.9))
		"mannequin":
			var c := Color.from_hsv(r, 0.5, 0.6)
			k.tube(p, p + Vector3(0, 0.04, 0), 0.16, 0.16, 6, SOMBRE)
			k.tube(p + Vector3(0, 0.04, 0), p + Vector3(0, 0.9, 0), 0.02, 0.02, 4, METAL)
			k.tube(p + Vector3(0, 0.85, 0), p + Vector3(0, 1.45, 0), 0.17, 0.2, 6, c)
			k.tube(p + Vector3(0, 0.55, 0), p + Vector3(0, 0.88, 0), 0.24, 0.16, 6, c.darkened(0.2))
			k.blob(p + Vector3(0, 1.58, 0), Vector3(0.09, 0.11, 0.09), Color("e8dcc8"), Color("f2e9da"), 0.05, 0)
		"portant":
			k.beam(p + Vector3(-0.3, 1.4, 0), p + Vector3(0.3, 1.4, 0), 0.03, 0.03, METAL)
			k.beam(p + Vector3(-0.3, 0, 0), p + Vector3(-0.3, 1.4, 0), 0.03, 0.03, METAL)
			k.beam(p + Vector3(0.3, 0, 0), p + Vector3(0.3, 1.4, 0), 0.03, 0.03, METAL)
			for j in 5:
				k.box(p + Vector3(-0.22 + j * 0.11, 1.05, 0), Vector3(0.05, 0.62, 0.32), Color.from_hsv(fmod(r + j * 0.17, 1.0), 0.5, 0.7))
		"chaussures":
			for j in 2:
				k.box(p + Vector3(-0.08 + j * 0.16, 0.04, 0), Vector3(0.09, 0.08, 0.24), Color.from_hsv(0.07 + r * 0.05, 0.5, 0.35 + r * 0.4))
		"ecran":
			k.box(p + Vector3(0, 0.03, 0), Vector3(0.2, 0.04, 0.15), SOMBRE)
			k.box(p + Vector3(0, 0.25, 0.02), Vector3(0.42, 0.3, 0.03), SOMBRE)
			k.layer = "lumiere"
			k.box(p + Vector3(0, 0.25, 0.0), Vector3(0.38, 0.26, 0.02), Color.from_hsv(0.55 + r * 0.1, 0.5, 0.9))
			k.layer = "base"
		"cartons", "caisses":
			var c2 := Color("c9a46b") if nom == "cartons" else Color("9c6b3c")
			k.box(p + Vector3(0, 0.15 + niveau * 0.3, 0) if nom == "caisses" else p + Vector3(0, 0.1, 0),
				Vector3(0.3, 0.2, 0.25) if nom == "cartons" else Vector3(1.1, 0.3, 0.8), c2)
		"fauteuil":
			_fauteuil(k, p, Color.from_hsv(r, 0.45, 0.6))
		"lampe":
			k.tube(p, p + Vector3(0, 0.03, 0), 0.12, 0.12, 6, SOMBRE)
			k.tube(p + Vector3(0, 0.03, 0), p + Vector3(0, 1.1, 0), 0.015, 0.015, 4, METAL)
			k.layer = "lumiere"
			k.tube(p + Vector3(0, 1.0, 0), p + Vector3(0, 1.25, 0), 0.18, 0.1, 6, Color("fbe7c6"))
			k.layer = "base"
		"fleurs":
			k.tube(p, p + Vector3(0, 0.22, 0), 0.1, 0.12, 6, Color("7f8c8d"))
			var fc2 := Color.from_hsv(fmod(0.9 + r * 0.35, 1.0), 0.7, 0.95)
			k.blob(p + Vector3(0, 0.35, 0), Vector3(0.15, 0.13, 0.15), Color("3d7a35"), fc2, 0.3, 0)
		"plantes":
			k.tube(p, p + Vector3(0, 0.2, 0), 0.1, 0.13, 6, Color("b5651d"))
			k.blob(p + Vector3(0, 0.38, 0), Vector3(0.18, 0.2, 0.18), Color("2e6b30"), Color("6aa84f"), 0.25, 0)
		"livres", "journaux":
			if nom == "journaux":
				for j in 3:
					k.box(p + Vector3(-0.12 + j * 0.12, 0.02 + j * 0.0, 0), Vector3(0.11, 0.04, 0.16), Color("ecebe4"))
			else:
				for j in 6:
					k.box(p + Vector3(-0.17 + j * 0.065, 0.11, 0), Vector3(0.05, 0.22 - (j % 3) * 0.03, 0.16), Color.from_hsv(fmod(r + j * 0.21, 1.0), 0.55, 0.6))
		"outils":
			k.beam(p + Vector3(-0.12, 0.02, 0), p + Vector3(0.12, 0.02, 0), 0.03, 0.03, BOIS)
			k.box(p + Vector3(0.14, 0.04, 0), Vector3(0.06, 0.06, 0.12), METAL)
			k.beam(p + Vector3(-0.1, 0.02, 0.08), p + Vector3(0.1, 0.02, 0.08), 0.02, 0.02, Color("c0392b"))
		"pots":
			for j in 2:
				k.tube(p + Vector3(-0.08 + j * 0.16, 0, 0), p + Vector3(-0.08 + j * 0.16, 0.16, 0), 0.07, 0.07, 6, Color.from_hsv(fmod(r + j * 0.4, 1.0), 0.5, 0.85))
		"voiture":
			var c3 := Color.from_hsv(r, 0.6, 0.7)
			k.box(p + Vector3(0, 0.45, 0), Vector3(1.6, 0.5, 0.75), c3)
			k.box(p + Vector3(0.05, 0.85, 0), Vector3(0.9, 0.35, 0.7), c3.lightened(0.1))
			for sx in [-0.55, 0.55]:
				for sz in [-0.38, 0.38]:
					k.tube(p + Vector3(sx, 0.2, sz - 0.05), p + Vector3(sx, 0.2, sz + 0.05), 0.2, 0.2, 6, SOMBRE)
		"bidons":
			for j in 2:
				k.box(p + Vector3(-0.08 + j * 0.16, 0.14, 0), Vector3(0.13, 0.28, 0.1), Color("c0392b"))
		"palette":
			k.box(p + Vector3(0, 0.07 + niveau * 0.5, 0), Vector3(1.2, 0.14, 0.8), BOIS_CLAIR)
			k.box(p + Vector3(0, 0.34 + niveau * 0.5, 0), Vector3(1.1, 0.4, 0.75), Color("c9a46b"))
		"fut":
			k.tube(p + Vector3(0, niveau * 0.9, 0), p + Vector3(0, 0.88 + niveau * 0.9, 0), 0.3, 0.3, 8, Color("5d6d7e"))
		"planches":
			for j in 4:
				k.box(p + Vector3(0, 0.05 + (niveau * 4 + j) * 0.1, 0), Vector3(1.4, 0.08, 0.7), BOIS_CLAIR.darkened(0.05 * j))
		"sacs", "balles":
			for j in 2:
				k.blob(p + Vector3(-0.3 + j * 0.6, 0.2 + niveau * 0.38, 0), Vector3(0.3, 0.19, 0.22), Color("b8a27a"), Color("d9c69c"), 0.15, 0)
		_:
			k.box(p + Vector3(0, 0.1, 0), Vector3(0.25, 0.2, 0.2), Color.from_hsv(r, 0.4, 0.8))


static func _table(k: LpKit, p: Vector3, annee: int) -> void:
	var dessus := Color("ecebe6") if annee >= 1950 else Color("6b4a2f")
	k.tube(p, p + Vector3(0, 0.03, 0), 0.22, 0.22, 6, SOMBRE)
	k.tube(p + Vector3(0, 0.03, 0), p + Vector3(0, 0.72, 0), 0.03, 0.03, 4, SOMBRE)
	k.tube(p + Vector3(0, 0.72, 0), p + Vector3(0, 0.75, 0), 0.33, 0.33, 8, dessus)
	for sx in [-1.0, 1.0]:
		var c := p + Vector3(sx * 0.55, 0, 0)
		k.box(c + Vector3(0, 0.45, 0), Vector3(0.38, 0.04, 0.38), Color("8e6c3a") if annee < 1960 else Color("4d5656"))
		k.box(c + Vector3(sx * 0.17, 0.7, 0), Vector3(0.04, 0.5, 0.38), Color("8e6c3a") if annee < 1960 else Color("4d5656"))
		for dx in [-0.16, 0.16]:
			for dz in [-0.16, 0.16]:
				k.box(c + Vector3(dx, 0.22, dz), Vector3(0.03, 0.45, 0.03), SOMBRE)


static func _fauteuil(k: LpKit, p: Vector3, c: Color) -> void:
	k.box(p + Vector3(0, 0.22, 0), Vector3(0.7, 0.3, 0.65), c)
	k.box(p + Vector3(0, 0.6, 0.27), Vector3(0.7, 0.5, 0.14), c.darkened(0.1))
	k.box(p + Vector3(-0.32, 0.45, 0), Vector3(0.1, 0.25, 0.6), c.darkened(0.15))
	k.box(p + Vector3(0.32, 0.45, 0), Vector3(0.1, 0.25, 0.6), c.darkened(0.15))


static func _plante(k: LpKit, p: Vector3) -> void:
	k.tube(p, p + Vector3(0, 0.4, 0), 0.18, 0.22, 6, Color("8d6e63"))
	k.blob(p + Vector3(0, 0.85, 0), Vector3(0.32, 0.5, 0.32), Color("2e6b30"), Color("6aa84f"), 0.25, 0)
