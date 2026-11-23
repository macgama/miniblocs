class_name DevanturesHabillage
extends RefCounted
## Habillage des petits commerces (boutiques, cafés, restaurants) : tout ce qui
## fait qu'une échoppe a l'air « habitée », façon diorama.
##
## - Toit : climatiseurs et gaines, trappe, château d'eau (Amériques), cuves
##   noires et chauffe-eau solaires (Méditerranée, Orient, Afrique, Asie du
##   Sud), cheminées de briques, antenne râteau, parabole, panneaux solaires.
## - Façade : enseigne verticale (néon le soir), climatiseurs muraux, gouttière,
##   compteur, fils électriques, plante grimpante (lierre, glycine,
##   bougainvillier), balcon à garde-corps fleuri, escalier extérieur sur le
##   côté, échelle de toit.
## - Trottoir : comptoir sur rue avec tabourets (échoppes d'Asie, diners),
##   lanternes de papier ou de métal, fanions, noren, distributeur automatique,
##   pots de fleurs, banc, vélo, caisses, lampadaire d'époque, arbre (cerisier
##   en fleurs, palmier, tilleul…) selon la saison.
##
## Tout dépend du style du bâtiment (Styles : région) et de l'année
## (Epoques.annee) : pas de climatiseur en 1900, pas de néon en 1850, lampadaire
## à gaz puis en fonte puis en crosse puis à LED.
##
## Deux maillages par commerce, mis en cache et partagés :
## - "loin" : les grandes silhouettes (toit, balcon, enseigne verticale,
##   plante grimpante, escalier, lampadaire, arbre), montrées jusqu'à
##   Devantures.VUE_ENSEIGNE ;
## - "pres" : les petites choses (pots, tabourets, lanternes, fanions,
##   distributeur, compteur, fils…), montrées seulement de près (Devantures.VUE).
##
## Repère : celui des devantures (origine au pied de la façade, au milieu de la
## vitrine ; −Z vers la rue). Couches : "base", "lumiere" (lampadaires : la
## nuit), "neon" (enseignes, lanternes, distributeur : le soir, commerce ouvert).

const BOIS := Color("8a5a35")
const BOIS_SOMBRE := Color("5b3a24")
const METAL := Color("a7aeb5")
const METAL_SOMBRE := Color("4a5057")
const FONTE := Color("2e3236")
const BLANC := Color("eeeae2")
const BRIQUE := Color("9c4a36")
const TERRE_CUITE := Color("b5643c")
const FEUILLE := Color("3f7d3a")
const FEUILLE_CLAIRE := Color("78b356")

## Commerces trop grands pour un habillage d'échoppe.
const GRANDS := ["supermarche", "grand_magasin", "centre_commercial", "marche", "concession", "concession_auto", "station_service"]

static var _cache := {}
static var _mats := {}
## Hauteurs de toit échantillonnées par maillage (RID -> {clé point -> y}).
static var _toits := {}


## Ce commerce reçoit-il l'habillage ? (petites boutiques, cafés, restaurants)
static func concerne(p: Dictionary, l: float, profondeur: float) -> bool:
	if p.is_empty():
		return false
	var genre := String(p.get("genre", ""))
	if genre != DevanturesTypes.BOUTIQUE and genre != DevanturesTypes.SALLE:
		return false
	if GRANDS.has(String(p.get("cle", ""))):
		return false
	return l <= 22.0 and profondeur <= 26.0


## Région du monde d'un type de bâtiment (Styles), "europe" par défaut.
static func region_de(type_id: String) -> String:
	var t := BuildingCatalog.get_type(type_id)
	var s: Dictionary = Styles.STYLES.get(String(t.get("style", "")), {})
	return String(s.get("region", "europe"))


## Ce qu'un commerce montre selon sa région, son style et l'année.
## `v` : variante stable du bâtiment (0, 1, 2).
static func theme(type_id: String, p: Dictionary, annee: int, v: int) -> Dictionary:
	var t := BuildingCatalog.get_type(type_id)
	var style_id := String(t.get("style", ""))
	var region := region_de(type_id)
	var genre := String(p.get("genre", ""))
	var asie := region == "asie_est" or region == "asie_sud"
	var chaud := region in ["mediterranee", "moyen_orient", "afrique", "asie_sud", "oceanie"] \
		or style_id in ["latino", "creole", "colonial_tropical", "neo_hispanique", "pueblo", "bresil_moderne", "latino_contemporain"]
	var amerique := region == "ameriques"
	var th := {
		"region": region, "style": style_id, "annee": annee, "v": v, "genre": genre,
		# Toit.
		"clim": annee >= 1960,
		"gaines": annee >= 1950,
		"cheminees": annee < 1960 and not chaud,
		"antenne": annee >= 1955 and annee < 2012 and v != 2,
		"parabole": annee >= 1990 and (v == 1 or region in ["moyen_orient", "afrique", "mediterranee"]),
		"solaire": annee >= 2005 and v == 2,
		"chateau_eau": amerique and annee >= 1880 and annee < 1995 and not chaud and v != 1,
		"cuves": chaud and annee >= 1965,
		# Façade.
		"enseigne_v": annee >= 1925 and (asie or amerique or v == 0),
		"neon": annee >= 1925,
		"clim_murale": annee >= 1965 and (asie or chaud or v != 0),
		"fils": annee >= 1900 and (asie or region in ["afrique", "ameriques", "moyen_orient"] or annee < 1960),
		"compteur": annee >= 1910,
		"grimpante": "bougainvillier" if (region in ["mediterranee", "moyen_orient"] or (chaud and v == 1)) else ("glycine" if (region == "asie_est" and v == 1) or (region == "europe" and v == 2) else "lierre"),
		"balcon": true,
		"escalier": true,
		"echelle": amerique and annee >= 1880,
		# Trottoir.
		"comptoir": genre == DevanturesTypes.SALLE and (asie or (amerique and annee >= 1930 and v != 2) or region in ["afrique", "oceanie"]),
		"lanternes": "papier" if region == "asie_est" else ("couleurs" if region == "asie_sud" else ("cuivre" if region == "moyen_orient" else "murale")),
		"fanions": region in ["asie_sud", "afrique", "oceanie"] or style_id in ["latino", "creole", "neo_hispanique", "mediterraneen", "latino_contemporain"] or (v == 2 and genre == DevanturesTypes.SALLE),
		"noren": region == "asie_est" and style_id in ["japonais", "meiji", "japon_moderne", "asie_dense", "asie_est_contemporain", "coreen"],
		"distributeur": annee >= 1960 and (region == "asie_est" or (annee >= 1975 and v == 1)),
		"pots": true,
		"banc": v != 1,
		"velo": annee >= 1890 and (region in ["europe", "asie_est"] or v == 2),
		"caisses": genre == DevanturesTypes.SALLE or v == 1,
		"lampadaire": lampadaire_de(annee, region),
		"arbre": arbre_de(region, style_id, chaud, v),
		"tuiles": region == "asie_est" and annee < 1990,
	}
	return th


## Sorte de lampadaire selon l'époque.
static func lampadaire_de(annee: int, region: String) -> String:
	if annee < 1830:
		return ""
	if annee < 1900:
		return "gaz"
	if annee < 1955:
		return "fonte"
	if annee < 2000:
		return "crosse"
	return "led"


## Arbre du trottoir selon la région.
static func arbre_de(region: String, style_id: String, chaud: bool, v: int) -> String:
	if region == "asie_est":
		return "cerisier" if v != 2 else "erable"
	if region in ["oceanie"] or style_id in ["creole", "colonial_tropical", "latino", "bresil_moderne", "tropical_contemporain", "polynesien"]:
		return "palmier"
	if region in ["asie_sud", "afrique"]:
		return "palmier" if v == 0 else "acacia"
	if region in ["mediterranee", "moyen_orient"] or chaud:
		return "olivier" if v != 1 else "palmier"
	return "tilleul"


# --- Matériaux -----------------------------------------------------------------------------

## Néons, lanternes, écrans : leurs propres couleurs brillent quand `allume`.
static func mat_neon(allume: bool) -> Material:
	var key := "neon_%d" % int(allume)
	if not _mats.has(key):
		var sh := Shader.new()
		sh.code = """
shader_type spatial;
uniform float allume = 0.0;
void fragment() {
	vec3 c = pow(COLOR.rgb, vec3(2.2));
	ALBEDO = c * (1.0 - 0.6 * allume);
	ROUGHNESS = 0.45;
	EMISSION = c * allume * 2.6;
}
"""
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("allume", 1.0 if allume else 0.0)
		_mats[key] = m
	return _mats[key]


## Écrans et feux allumés toute la nuit (distributeur, feu piéton) : mêmes
## couleurs que les néons, mais indépendants de l'ouverture du commerce.
static func mat_nuit(allume: bool) -> Material:
	var key := "nuit_%d" % int(allume)
	if not _mats.has(key):
		var m := (mat_neon(allume) as ShaderMaterial).duplicate() as ShaderMaterial
		_mats[key] = m
	return _mats[key]


static func _commit(k: LpKit) -> ArrayMesh:
	return k.commit({"base": DevanturesModeles.mat_base(), "lumiere": DevanturesModeles.mat_lumiere(false), "neon": mat_neon(false),
		"nuit": mat_nuit(false), "vitre": DevanturesModeles.mat_vitre()})


## Allume ou éteint un maillage d'habillage (lampadaires la nuit, néons le soir
## quand le commerce est ouvert ou jusqu'à 23 h).
static func allumer(mi: MeshInstance3D, lampes: bool, neons: bool) -> void:
	if mi == null or mi.mesh == null:
		return
	for i in mi.mesh.get_surface_count():
		var m := mi.mesh.surface_get_material(i)
		if m == DevanturesModeles.mat_lumiere(false):
			mi.set_surface_override_material(i, DevanturesModeles.mat_lumiere(true) if lampes else null)
		elif m == mat_neon(false):
			mi.set_surface_override_material(i, mat_neon(true) if neons else null)
		elif m == mat_nuit(false):
			mi.set_surface_override_material(i, mat_nuit(true) if lampes else null)


# --- Hauteur du toit -----------------------------------------------------------------------

## Hauteur du dessus du bâtiment en chaque point (x, z) du repère du maillage :
## la plus haute face tournée vers le ciel au-dessus du point (0 : rien).
static func hauteurs_toit(mesh: Mesh, points: Array) -> Array:
	var rid := mesh.get_rid()
	if not _toits.has(rid):
		_toits[rid] = {}
	var memo: Dictionary = _toits[rid]
	var out := []
	var manquants := []
	for pt in points:
		var cle := "%.1f|%.1f" % [pt.x, pt.y]
		if memo.has(cle):
			out.append(memo[cle])
		else:
			out.append(null)
			manquants.append(pt)
	if manquants.is_empty():
		return out
	var res := []
	res.resize(manquants.size())
	res.fill(0.0)
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx = arr[Mesh.ARRAY_INDEX]
		var n := v.size() if idx == null or (idx as PackedInt32Array).is_empty() else (idx as PackedInt32Array).size()
		var i := 0
		while i + 2 < n:
			var a: Vector3
			var b: Vector3
			var c: Vector3
			if idx == null or (idx as PackedInt32Array).is_empty():
				a = v[i]; b = v[i + 1]; c = v[i + 2]
			else:
				a = v[idx[i]]; b = v[idx[i + 1]]; c = v[idx[i + 2]]
			i += 3
			var nn := (b - a).cross(c - a)
			if absf(nn.y) < 0.35 * nn.length():
				continue
			var lo := Vector2(minf(a.x, minf(b.x, c.x)), minf(a.z, minf(b.z, c.z)))
			var hi := Vector2(maxf(a.x, maxf(b.x, c.x)), maxf(a.z, maxf(b.z, c.z)))
			for j in manquants.size():
				var q: Vector2 = manquants[j]
				if q.x < lo.x or q.x > hi.x or q.y < lo.y or q.y > hi.y:
					continue
				var y := _sur_triangle(q, a, b, c)
				if y > float(res[j]):
					res[j] = y
	var k := 0
	for j in out.size():
		if out[j] == null:
			var pt: Vector2 = manquants[k]
			memo["%.1f|%.1f" % [pt.x, pt.y]] = res[k]
			out[j] = res[k]
			k += 1
	return out


static func _sur_triangle(q: Vector2, a: Vector3, b: Vector3, c: Vector3) -> float:
	var v0 := Vector2(b.x - a.x, b.z - a.z)
	var v1 := Vector2(c.x - a.x, c.z - a.z)
	var v2 := Vector2(q.x - a.x, q.y - a.z)
	var den := v0.x * v1.y - v1.x * v0.y
	if absf(den) < 1e-9:
		return -INF
	var u := (v2.x * v1.y - v1.x * v2.y) / den
	var w := (v0.x * v2.y - v2.x * v0.y) / den
	if u < -0.001 or w < -0.001 or u + w > 1.002:
		return -INF
	return a.y + u * (b.y - a.y) + w * (c.y - a.y)


## Mesures utiles d'un modèle, dans le repère de la devanture : hauteur de la
## façade (corniche), toit en quelques points, toit plat ou non.
static func mesures(mesh: Mesh, origine: Vector3, l: float, prof: float) -> Dictionary:
	var pts := []
	var fx := [-0.3, 0.0, 0.3]
	var fz := [0.25, 0.5, 0.75]
	for z in fz:
		for x in fx:
			pts.append(Vector2(origine.x + x * l, origine.z + z * prof))
	# Corniche de la façade : un peu derrière le bord avant.
	for x in fx:
		pts.append(Vector2(origine.x + x * l, origine.z + 0.6))
	var hs := hauteurs_toit(mesh, pts)
	var toit := []
	for i in 9:
		toit.append(float(hs[i]))
	var facade := minf(float(hs[9]), minf(float(hs[10]), float(hs[11])))
	var mn: float = toit.min()
	var mx: float = toit.max()
	return {"toit": toit, "plat": mx - mn < 0.35, "toit_y": mn, "toit_max": mx, "facade": facade}


# --- Maillages -----------------------------------------------------------------------------

## Les deux maillages d'habillage ({"loin": ArrayMesh, "pres": ArrayMesh}).
## `g` : géométrie de la devanture (Devantures._geometrie) complétée de
## "mes" (mesures), "cote_g"/"cote_d" (place libre sur les côtés), "fh"
## (hauteur d'étage) ; `th` : theme().
static func maillages(g: Dictionary, th: Dictionary, mois: int) -> Dictionary:
	var mes: Dictionary = g.mes
	var saison := _saison(mois)
	var key := "hab|%s|%s|%d|%d|%s|%.1f|%.1f|%.1f|%.1f|%.1f|%.1f|%.1f|%.1f|%d" % [
		th.style, th.region, int(th.annee) / 5, int(th.v), saison, float(g.l), float(g.w), float(g.h), float(mes.facade),
		float(mes.toit_y), float(g.cote_g), float(g.cote_d), float(g.cour), int(g.prof)]
	key += "|" + str(th.genre) + "|" + "|".join((mes.toit as Array).map(func(y): return "%.1f" % y))
	if _cache.has(key):
		return _cache[key]
	var out := {"loin": _loin(g, th, saison), "pres": _pres(g, th, saison)}
	_cache[key] = out
	return out


static func _saison(mois: int) -> String:
	if mois >= 3 and mois <= 4:
		return "printemps"
	if mois >= 5 and mois <= 8:
		return "ete"
	if mois >= 9 and mois <= 10:
		return "automne"
	return "hiver"


static func _kit(seed_value: int) -> LpKit:
	var k := LpKit.new(seed_value)
	k.jitter = 0.035
	return k


## Les grandes silhouettes.
static func _loin(g: Dictionary, th: Dictionary, saison: String) -> ArrayMesh:
	var k := _kit(int(th.v) * 31 + 7)
	var l := float(g.l)
	var w := float(g.w)
	var h := float(g.h)
	var mes: Dictionary = g.mes
	var facade := float(mes.facade)
	var annee := int(th.annee)
	var region := String(th.region)
	_toit(k, g, th)
	var etage := facade >= h + 2.4
	var fh := maxf(float(g.fh), h + 0.7)
	# Plante grimpante à l'angle gauche de la façade.
	_grimpante(k, Vector3(-l * 0.5 + 0.35, 0, -0.1), minf(facade - 0.4, fh + 2.2), String(th.grimpante), saison)
	# Balcon au premier étage, du côté opposé à la porte.
	if etage and bool(th.balcon) and facade >= fh + 1.2:
		_balcon(k, Vector3(-minf(l * 0.18, 1.6), fh, 0), clampf(l * 0.42, 2.0, 3.6), annee, region, saison)
	# Enseigne verticale à l'angle droit.
	if bool(th.enseigne_v) and etage:
		_enseigne_verticale(k, Vector3(l * 0.5 - 0.15, h + 0.9, -0.1), minf(facade - h - 1.1, 3.2), th)
	# Climatiseurs muraux.
	if bool(th.clim_murale) and etage:
		_clim(k, Vector3(l * 0.22, fh + 0.45, -0.2), false)
		if facade >= fh + 3.6:
			_clim(k, Vector3(-l * 0.3, fh + 3.4, -0.2), false)
	# Escalier extérieur sur le côté droit, vers une porte au premier étage.
	if bool(th.escalier) and etage and float(g.cote_d) >= 0.95 and float(g.prof) >= fh * 1.25 + 1.6:
		_escalier(k, Vector3(l * 0.5, 0, 0.6), fh, float(g.prof) - 1.0, annee)
	elif bool(th.echelle) and float(g.cote_d) >= 0.4:
		_echelle(k, Vector3(l * 0.5 + 0.12, 0, float(g.prof) * 0.55), facade + 0.9)
	# Lampadaire au bord du trottoir, à gauche ; arbre à droite.
	var bord := -(float(g.cour) + 1.15)
	if String(th.lampadaire) != "":
		_lampadaire(k, Vector3(-l * 0.5 + 0.5, 0, bord), String(th.lampadaire), region)
	if String(th.arbre) != "" and l >= 5.0:
		_arbre(k, Vector3(l * 0.5 - 0.5, 0, bord + 0.05), String(th.arbre), saison, int(th.v))
	# Avancée de tuiles au-dessus de la devanture (Asie de l'Est).
	if bool(th.tuiles):
		_auvent_tuiles(k, w + 0.6, h + 0.95)
	return _commit(k)


## Les petites choses, de près.
static func _pres(g: Dictionary, th: Dictionary, saison: String) -> ArrayMesh:
	var k := _kit(int(th.v) * 17 + 3)
	var l := float(g.l)
	var w := float(g.w)
	var h := float(g.h)
	var mes: Dictionary = g.mes
	var facade := float(mes.facade)
	var annee := int(th.annee)
	var px := DevanturesModeles.porte_x(w)
	var genre := String(th.genre)
	# Gouttière et compteur.
	if annee >= 1850:
		k.tube(Vector3(l * 0.5 - 0.12, 0.05, -0.1), Vector3(l * 0.5 - 0.12, facade - 0.1, -0.1), 0.05, 0.05, 6, METAL if annee >= 1950 else Color("5d6a6f"))
		k.box(Vector3(l * 0.5 - 0.12, facade - 0.12, -0.16), Vector3(0.16, 0.14, 0.2), METAL_SOMBRE)
	if bool(th.compteur):
		var cx := minf(px + 0.9, l * 0.5 - 0.45)
		k.box(Vector3(cx, 1.25, -0.06), Vector3(0.36, 0.5, 0.12), Color("c9c5b9"))
		k.box(Vector3(cx, 1.3, -0.13), Vector3(0.18, 0.12, 0.02), Color("2e3236"))
		k.beam(Vector3(cx, 1.5, -0.06), Vector3(cx, h + 0.6, -0.06), 0.03, 0.03, FONTE)
	# Fils électriques le long de la façade, avec une boîte de dérivation.
	if bool(th.fils):
		var y0 := h + 1.25
		for f in 3:
			var dy := float(f) * 0.12
			var pts := [Vector3(-l * 0.5, y0 + dy, -0.12 - 0.05 * f), Vector3(-l * 0.15, y0 + dy - 0.22, -0.18 - 0.05 * f),
				Vector3(l * 0.2, y0 + dy - 0.18, -0.18 - 0.05 * f), Vector3(l * 0.5, y0 + dy + 0.05, -0.12 - 0.05 * f)]
			for i in pts.size() - 1:
				k.beam(pts[i], pts[i + 1], 0.025, 0.025, Color("1d1f21"))
		k.box(Vector3(-l * 0.5 + 0.6, y0 + 0.05, -0.1), Vector3(0.3, 0.3, 0.16), METAL_SOMBRE)
	# Lanternes.
	var lant := String(th.lanternes)
	if lant == "murale":
		if annee >= 1830:
			for sx in [-1.0, 1.0]:
				_lanterne_murale(k, Vector3(px + sx * 0.75, 2.45, -0.06), annee)
	else:
		var n := clampi(int(w / 1.1), 2, 6)
		for i in n:
			var x := -w * 0.5 + 0.4 + (w - 0.8) * (float(i) + 0.5) / n
			_lanterne(k, Vector3(x, h + 0.5, -0.65), lant, i)
	# Fanions entre la façade et le lampadaire.
	if bool(th.fanions):
		_fanions(k, Vector3(-l * 0.5 + 0.5, h + 0.75, -(float(g.cour) + 1.1)), Vector3(l * 0.5 - 0.2, h + 1.1, -0.15), int(th.v))
	# Noren devant la porte.
	if bool(th.noren):
		_noren(k, Vector3(px, minf(2.3, h - 0.7), -0.12), int(th.v))
	# Comptoir sur rue et tabourets.
	if bool(th.comptoir):
		for pl in places_comptoir(w):
			_tabouret(k, pl.origin, annee)
		var cx0 := -w * 0.5 + 0.35
		var cx1 := px - 0.75
		k.box(Vector3((cx0 + cx1) * 0.5, 0.5, -0.3), Vector3(cx1 - cx0, 1.0, 0.36), Color("a64b2a") if String(th.region) == "asie_est" else BOIS)
		k.box(Vector3((cx0 + cx1) * 0.5, 1.03, -0.42), Vector3(cx1 - cx0 + 0.1, 0.06, 0.62), BOIS.lightened(0.15))
		# Bols, verres et baguettes sur le comptoir.
		var nb := int((cx1 - cx0) / 0.55)
		for i in nb:
			var x := cx0 + 0.3 + float(i) * 0.55
			if i % 3 == 2:
				continue
			k.lathe(Vector3(x, 1.06, -0.5), [Vector2(0.05, 0.0), Vector2(0.11, 0.08), Vector2(0.11, 0.09)], 7, Color("f1ede4") if i % 2 == 0 else Color("b8452e"), true, true)
	# Distributeur automatique, à gauche de la façade.
	if bool(th.distributeur):
		_distributeur(k, Vector3(-l * 0.5 + 0.55, 0, -0.42), int(th.v), annee)
	# Pots de fleurs de part et d'autre de la porte.
	if bool(th.pots):
		for i in 3:
			var x := px + 0.8 + 0.42 * float(i)
			if x > l * 0.5 - 0.2:
				x = px - 0.95 - 0.4 * float(i)
			_pot(k, Vector3(x, 0, -0.32 - 0.08 * float(i % 2)), 0.16 + 0.05 * float(i % 2), String(th.region), saison, i)
	# Banc, vélo, caisses.
	var bord := -(float(g.cour) + 0.75)
	if bool(th.banc) and l >= 6.0 and not bool(th.comptoir):
		_banc(k, Vector3(-l * 0.5 + 1.8, 0, bord + 0.2), annee)
	if bool(th.velo):
		_velo(k, Vector3(l * 0.5 - 1.4, 0, bord + 0.1), int(th.v))
	if bool(th.caisses) and float(g.cote_g) >= 0.6:
		for i in 3:
			k.box(Vector3(-l * 0.5 - 0.35, 0.2 + 0.4 * float(i / 2), 0.6 + 0.45 * float(i % 2)), Vector3(0.5, 0.38, 0.4), Color("b08355") if i != 1 else Color("3f6e9a"))
	return _commit(k)


## Places assises au comptoir sur rue (repère de la devanture, face au comptoir).
static func places_comptoir(w: float) -> Array:
	var px := DevanturesModeles.porte_x(w)
	var cx0 := -w * 0.5 + 0.35
	var cx1 := px - 0.75
	var out := []
	var n := maxi(1, int((cx1 - cx0) / 0.6))
	for i in n:
		var x := cx0 + (cx1 - cx0) * (float(i) + 0.5) / n
		out.append(Transform3D(Basis.IDENTITY, Vector3(x, 0.0, -0.85)))
	return out


# --- Toit ----------------------------------------------------------------------------------

static func _toit(k: LpKit, g: Dictionary, th: Dictionary) -> void:
	var mes: Dictionary = g.mes
	var l := float(g.l)
	var prof := float(g.prof)
	var toit: Array = mes.toit
	var annee := int(th.annee)
	# Points d'échantillonnage : x = (-0.3, 0, 0.3)·l, z = (0.25, 0.5, 0.75)·prof.
	var pt := func(i: int) -> Vector3:
		var xs := [-0.3, 0.0, 0.3]
		var zs := [0.25, 0.5, 0.75]
		return Vector3(float(xs[i % 3]) * l, float(toit[i]), float(zs[i / 3]) * prof)
	if float(mes.toit_max) < 2.5:
		return
	if bool(mes.plat):
		var y := float(mes.toit_y)
		# Trappe d'accès.
		var p0: Vector3 = pt.call(0)
		k.box(Vector3(p0.x, y + 0.2, p0.z), Vector3(0.9, 0.4, 0.9), Color("b9b4aa"))
		k.box(Vector3(p0.x, y + 0.43, p0.z), Vector3(1.0, 0.06, 1.0), METAL_SOMBRE)
		# Climatiseurs et gaines.
		if bool(th.clim):
			var pa: Vector3 = pt.call(8)
			_clim(k, Vector3(pa.x, y, pa.z), true)
			if int(th.v) != 0:
				var pb: Vector3 = pt.call(6)
				_clim(k, Vector3(pb.x + 0.4, y, pb.z), true)
			if bool(th.gaines):
				var a := Vector3(pa.x - 0.6, y + 0.35, pa.z)
				var b := Vector3(0.0, y + 0.35, pa.z)
				var c := Vector3(0.0, y + 0.35, prof * 0.3)
				var d := Vector3(-l * 0.5 + 0.3, y + 0.35, prof * 0.3)
				k.beam(a, b, 0.42, 0.42, METAL)
				k.box(b, Vector3(0.5, 0.5, 0.5), METAL.darkened(0.08))
				k.beam(b, c, 0.42, 0.42, METAL)
				k.box(c, Vector3(0.5, 0.5, 0.5), METAL.darkened(0.08))
				k.beam(c, d, 0.42, 0.42, METAL)
				# Colliers de la gaine.
				for f in [0.3, 0.7]:
					k.box(a.lerp(b, f), Vector3(0.06, 0.48, 0.48), METAL_SOMBRE)
				# Tuyaux noirs qui serpentent jusqu'au bord.
				k.beam(Vector3(pa.x, y + 0.08, pa.z - 0.5), Vector3(pa.x, y + 0.08, prof * 0.12), 0.07, 0.07, Color("1d1f21"))
				k.beam(Vector3(pa.x, y + 0.08, prof * 0.12), Vector3(l * 0.5 - 0.2, y + 0.08, prof * 0.12), 0.07, 0.07, Color("1d1f21"))
		elif bool(th.cheminees):
			var pc: Vector3 = pt.call(2)
			_cheminee(k, Vector3(pc.x, y, pc.z), 1.0)
		# Château d'eau en bois sur pieds.
		if bool(th.chateau_eau):
			var pe: Vector3 = pt.call(4)
			_chateau_eau(k, Vector3(pe.x, y, pe.z + 0.6))
		# Cuves noires et chauffe-eau solaire.
		if bool(th.cuves):
			var pv: Vector3 = pt.call(3)
			for i in 2:
				k.lathe(Vector3(pv.x + 0.75 * i, y, pv.z), [Vector2(0.42, 0.0), Vector2(0.45, 0.1), Vector2(0.45, 0.8), Vector2(0.3, 0.95), Vector2(0.12, 1.0)], 8, Color("26292c"), false, true)
			if annee >= 1980:
				var ps: Vector3 = pt.call(5)
				_chauffe_eau(k, Vector3(ps.x - 0.4, y, ps.z))
		if bool(th.solaire):
			var pz: Vector3 = pt.call(7)
			for i in 2:
				var c := Vector3(pz.x - 0.6 + 1.2 * i, y + 0.45, pz.z)
				k.xf = Transform3D(Basis(Vector3.RIGHT, -0.45), c)
				k.box(Vector3.ZERO, Vector3(1.1, 0.05, 1.6), Color("22344f"), 0.0, false)
				k.xf = Transform3D.IDENTITY
				k.beam(c + Vector3(0, -0.4, 0.5), c + Vector3(0, 0.1, 0.5), 0.05, 0.05, METAL)
	else:
		# Toit en pente : cheminées sur le faîtage, antenne, parabole.
		var faite: Vector3 = pt.call(4)
		for i in 9:
			var q: Vector3 = pt.call(i)
			if q.y > faite.y:
				faite = q
		if bool(th.cheminees) or annee < 1960:
			_cheminee(k, faite + Vector3(-l * 0.22, -0.3, 0), 1.2)
			if int(th.v) != 1:
				_cheminee(k, faite + Vector3(l * 0.25, -0.35, 0.4), 1.0)
		k.xf = Transform3D.IDENTITY
	var haut := float(mes.toit_max)
	var pm: Vector3 = pt.call(1)
	if bool(th.antenne):
		var base := Vector3(pm.x + 0.5, (float(mes.toit_y) if bool(mes.plat) else haut - 0.3), pm.z)
		k.beam(base, base + Vector3(0, 2.2, 0), 0.05, 0.05, METAL)
		for i in 3:
			var yy := 1.5 + 0.25 * i
			k.beam(base + Vector3(-0.45 + 0.08 * i, yy, 0), base + Vector3(0.45 - 0.08 * i, yy, 0), 0.03, 0.03, METAL)
	if bool(th.parabole):
		var pp := Vector3(l * 0.28, (float(mes.toit_y) if bool(mes.plat) else haut - 0.4), prof * 0.4)
		k.beam(pp, pp + Vector3(0, 0.6, 0), 0.05, 0.05, METAL_SOMBRE)
		k.xf = Transform3D(Basis(Vector3.RIGHT, -1.0), pp + Vector3(0, 0.75, -0.05))
		k.lathe(Vector3.ZERO, [Vector2(0.05, 0.0), Vector2(0.32, 0.1), Vector2(0.4, 0.16)], 8, Color("e7e5df"), true, false)
		k.xf = Transform3D.IDENTITY


static func _clim(k: LpKit, p: Vector3, au_toit: bool) -> void:
	if au_toit:
		# Groupe sur le toit : caisson, grille et ventilateur sur le dessus.
		k.box(p + Vector3(0, 0.1, 0), Vector3(1.25, 0.2, 0.95), METAL_SOMBRE)
		k.box(p + Vector3(0, 0.55, 0), Vector3(1.15, 0.7, 0.85), Color("d9dcdc"))
		k.lathe(p + Vector3(0, 0.9, 0), [Vector2(0.36, 0.0), Vector2(0.36, 0.05)], 10, Color("3a3f44"), false, true)
		k.box(p + Vector3(0, 0.96, 0), Vector3(0.6, 0.03, 0.06), Color("8b9298"))
		k.box(p + Vector3(0, 0.96, 0), Vector3(0.06, 0.03, 0.6), Color("8b9298"))
	else:
		# Groupe mural : caisson, grille ronde, équerres et tuyau d'évacuation.
		k.box(p, Vector3(0.8, 0.55, 0.32), Color("e4e4df"))
		k.xf = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), p + Vector3(-0.1, 0, -0.17))
		k.lathe(Vector3.ZERO, [Vector2(0.2, 0.0), Vector2(0.2, 0.02)], 10, Color("4a4f54"), false, true)
		k.xf = Transform3D.IDENTITY
		for sx in [-0.3, 0.3]:
			k.box(p + Vector3(sx, -0.3, 0.02), Vector3(0.04, 0.06, 0.36), METAL_SOMBRE)
		k.beam(p + Vector3(0.32, -0.25, -0.05), p + Vector3(0.36, -1.3, -0.04), 0.03, 0.03, Color("f0f0ea"))


static func _cheminee(k: LpKit, p: Vector3, haut: float) -> void:
	k.box(p + Vector3(0, haut * 0.5, 0), Vector3(0.55, haut, 0.45), BRIQUE)
	k.box(p + Vector3(0, haut + 0.04, 0), Vector3(0.65, 0.08, 0.55), BRIQUE.darkened(0.25))
	for sx in [-0.12, 0.12]:
		k.tube(p + Vector3(sx, haut + 0.05, 0), p + Vector3(sx, haut + 0.3, 0), 0.07, 0.06, 6, TERRE_CUITE)


static func _chateau_eau(k: LpKit, p: Vector3) -> void:
	var r := 0.85
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			k.beam(p + Vector3(sx * 0.6, 0, sz * 0.6), p + Vector3(sx * 0.55, 1.3, sz * 0.55), 0.09, 0.09, METAL_SOMBRE)
	k.beam(p + Vector3(-0.6, 0.6, -0.6), p + Vector3(0.6, 0.6, 0.6), 0.04, 0.04, METAL_SOMBRE)
	k.beam(p + Vector3(0.6, 0.6, -0.6), p + Vector3(-0.6, 0.6, 0.6), 0.04, 0.04, METAL_SOMBRE)
	k.box(p + Vector3(0, 1.33, 0), Vector3(1.6, 0.08, 1.6), BOIS_SOMBRE)
	var douelles := func(i: int, _r: int) -> Color:
		return BOIS.darkened(0.08 * float(i % 3))
	k.lathe(p + Vector3(0, 1.37, 0), [Vector2(r, 0.0), Vector2(r * 1.03, 0.9), Vector2(r, 1.8)], 12, BOIS, true, false, douelles)
	for yy in [0.35, 1.0, 1.6]:
		k.lathe(p + Vector3(0, 1.37 + yy, 0), [Vector2(r * 1.05, 0.0), Vector2(r * 1.05, 0.06)], 12, METAL_SOMBRE, false, false)
	k.lathe(p + Vector3(0, 3.17, 0), [Vector2(r + 0.08, 0.0), Vector2(0.06, 0.6)], 12, Color("6d4a33"), true, false)
	# Échelle sur le côté du réservoir.
	for i in 6:
		k.box(p + Vector3(r + 0.08, 0.3 + 0.45 * i, 0), Vector3(0.04, 0.04, 0.4), METAL_SOMBRE)
	for sz in [-0.2, 0.2]:
		k.beam(p + Vector3(r + 0.1, 0, sz), p + Vector3(r + 0.1, 2.9, sz), 0.04, 0.04, METAL_SOMBRE)


static func _chauffe_eau(k: LpKit, p: Vector3) -> void:
	k.xf = Transform3D(Basis(Vector3.RIGHT, -0.6), p + Vector3(0, 0.6, 0))
	k.box(Vector3.ZERO, Vector3(1.0, 0.06, 1.3), Color("1f3350"), 0.0, false)
	k.xf = Transform3D.IDENTITY
	k.tube(p + Vector3(-0.55, 1.1, 0.35), p + Vector3(0.55, 1.1, 0.35), 0.2, 0.2, 8, Color("dcdcd6"))
	k.beam(p + Vector3(-0.45, 0, 0.45), p + Vector3(-0.45, 0.95, 0.4), 0.04, 0.04, METAL)
	k.beam(p + Vector3(0.45, 0, 0.45), p + Vector3(0.45, 0.95, 0.4), 0.04, 0.04, METAL)


# --- Façade --------------------------------------------------------------------------------

static func _grimpante(k: LpKit, base: Vector3, haut: float, sorte: String, saison: String) -> void:
	if haut < 1.5:
		return
	var vert := FEUILLE.darkened(0.1)
	var clair := FEUILLE_CLAIRE
	var fleur := Color(0, 0, 0, 0)
	match sorte:
		"bougainvillier":
			fleur = Color("d6338a")
		"glycine":
			fleur = Color("9b7fd4") if saison == "printemps" else Color(0, 0, 0, 0)
	if saison == "automne" and sorte == "lierre":
		clair = Color("b5652e")
	if saison == "hiver" and sorte != "lierre":
		vert = Color("6b5a48")
		clair = Color("8a7660")
		fleur = Color(0, 0, 0, 0)
	# Pied touffu, puis un rideau de feuillage qui s'élargit en montant.
	k.blob(base + Vector3(0.1, 0.35, -0.12), Vector3(0.45, 0.4, 0.3), vert, clair, 0.25, 0)
	var n := int(haut / 0.38)
	for i in n:
		var y := 0.6 + float(i) * 0.38
		var f := float(i) / maxf(float(n), 1.0)
		var larg := 0.25 + 0.55 * f
		for j in 2:
			var dx := (float(j) - 0.5) * larg + sin(float(i) * 1.9 + j) * 0.12 + 0.15 * f
			var r := 0.3 + 0.08 * float((i + j) % 2)
			k.blob(base + Vector3(dx, y, -0.06), Vector3(r, r * 0.8, 0.13), vert, clair, 0.3, 0)
			if fleur.a > 0.0 and (i + j) % 3 == 1:
				k.blob(base + Vector3(dx + 0.1, y + 0.05, -0.15), Vector3(0.17, 0.15, 0.07), fleur.darkened(0.15), fleur, 0.3, 0)
	# Une branche qui court sous le premier étage.
	for i in 5:
		k.blob(base + Vector3(0.55 + 0.38 * i, haut - 0.25 - 0.12 * (i % 2), -0.06), Vector3(0.3, 0.22, 0.13), vert, clair, 0.3, 0)
		if fleur.a > 0.0 and i % 2 == 0:
			k.blob(base + Vector3(0.6 + 0.38 * i, haut - 0.4, -0.14), Vector3(0.15, 0.13, 0.07), fleur.darkened(0.15), fleur, 0.3, 0)
	# Grappes pendantes de glycine.
	if sorte == "glycine" and fleur.a > 0.0:
		for i in 4:
			k.lathe(base + Vector3(0.6 + 0.45 * i, haut - 0.95, -0.12), [Vector2(0.02, 0.0), Vector2(0.09, 0.4), Vector2(0.04, 0.55)], 5, fleur, true, true)


static func _balcon(k: LpKit, c: Vector3, larg: float, annee: int, region: String, saison: String) -> void:
	var prof := 0.85
	# Dalle et consoles.
	k.box(c + Vector3(0, -0.06, -prof * 0.5), Vector3(larg, 0.14, prof), Color("cfc8bb"))
	for sx in [-0.4, 0.4]:
		k.beam(c + Vector3(sx * larg, -0.5, -0.02), c + Vector3(sx * larg, -0.12, -prof + 0.1), 0.08, 0.1, Color("b8b1a4"))
	# Porte-fenêtre.
	k.box(c + Vector3(0, 1.1, -0.02), Vector3(1.0, 2.1, 0.05), Color("3b4650"))
	k.box(c + Vector3(0, 1.1, -0.05), Vector3(0.06, 2.0, 0.03), BLANC)
	k.box(c + Vector3(0, 2.18, -0.05), Vector3(1.12, 0.08, 0.06), BLANC)
	# Garde-corps : ferronnerie, balustres ou barreaux selon l'époque.
	var col := FONTE if annee < 1960 else (METAL if annee < 2000 else Color("d9d9d4"))
	var hr := 1.0
	k.box(c + Vector3(0, hr, -prof + 0.03), Vector3(larg, 0.05, 0.06), col)
	k.box(c + Vector3(-larg * 0.5 + 0.03, hr, -prof * 0.5), Vector3(0.06, 0.05, prof), col)
	k.box(c + Vector3(larg * 0.5 - 0.03, hr, -prof * 0.5), Vector3(0.06, 0.05, prof), col)
	k.box(c + Vector3(0, 0.12, -prof + 0.03), Vector3(larg, 0.04, 0.05), col)
	var n := int(larg / 0.16)
	for i in n + 1:
		var x := -larg * 0.5 + larg * float(i) / n
		k.box(c + Vector3(x, 0.55, -prof + 0.03), Vector3(0.025, 0.9, 0.025), col)
	if annee < 1930:
		# Volutes de fonte : petits cercles carrés au milieu du garde-corps.
		for i in int(larg / 0.5):
			k.box(c + Vector3(-larg * 0.5 + 0.25 + 0.5 * i, 0.55, -prof + 0.03), Vector3(0.2, 0.2, 0.02), col)
	# Jardinière et plantes, linge pour les régions chaudes.
	k.box(c + Vector3(0, hr + 0.12, -prof - 0.05), Vector3(larg * 0.7, 0.2, 0.2), TERRE_CUITE)
	var fleurs := saison in ["printemps", "ete"]
	for i in int(larg * 0.7 / 0.3):
		var x := -larg * 0.35 + 0.15 + 0.3 * i
		var cf := Color.from_hsv(fmod(0.95 + float(i) * 0.17, 1.0), 0.7, 0.92) if fleurs else FEUILLE_CLAIRE
		k.blob(c + Vector3(x, hr + 0.3, -prof - 0.05), Vector3(0.14, 0.13, 0.12), FEUILLE, cf, 0.3, 0)
	k.lathe(c + Vector3(-larg * 0.5 + 0.3, 0.0, -prof * 0.45), [Vector2(0.14, 0.0), Vector2(0.18, 0.35)], 7, TERRE_CUITE, true, false)
	k.blob(c + Vector3(-larg * 0.5 + 0.3, 0.55, -prof * 0.45), Vector3(0.28, 0.3, 0.28), FEUILLE, FEUILLE_CLAIRE, 0.3, 0)
	if region in ["mediterranee", "asie_sud", "asie_est", "moyen_orient", "ameriques"]:
		k.beam(c + Vector3(-larg * 0.45, 1.7, -prof + 0.05), c + Vector3(larg * 0.45, 1.7, -prof + 0.05), 0.015, 0.015, Color("ececec"))
		var linge := [Color("e8e0d0"), Color("6e9bc7"), Color("d65d5d"), Color("f2d06b")]
		for i in 4:
			k.box(c + Vector3(-larg * 0.3 + i * larg * 0.2, 1.45, -prof + 0.05), Vector3(0.3, 0.45, 0.02), linge[i])


static func _enseigne_verticale(k: LpKit, base: Vector3, haut: float, th: Dictionary) -> void:
	if haut < 1.2:
		return
	var region := String(th.region)
	var v := int(th.v)
	var neon := bool(th.neon)
	var asie := region == "asie_est" or region == "asie_sud"
	var palettes := [[Color("ff4f6d"), Color("ffd84f")], [Color("4fd6ff"), Color("ff7ad9")], [Color("ffd84f"), Color("7dff8a")]]
	var pal: Array = palettes[v % 3]
	var fond := Color("b3242e") if asie and v != 1 else Color("1f2a3a")
	var larg := 0.55
	var c := base + Vector3(0, haut * 0.5, -0.45)
	# Potences.
	for yy in [0.2, haut - 0.2]:
		k.beam(base + Vector3(0, yy, 0.05), base + Vector3(0, yy, -0.2), 0.05, 0.05, FONTE)
	k.box(c, Vector3(0.14, haut, larg), fond)
	# Cadre lumineux et « caractères » empilés (blocs de néon).
	k.layer = "neon" if neon else "base"
	var cad: Color = pal[0]
	for sx in [-1.0, 1.0]:
		k.box(c + Vector3(sx * 0.08, 0, larg * 0.5 - 0.02), Vector3(0.03, haut, 0.04), cad)
		k.box(c + Vector3(sx * 0.08, 0, -larg * 0.5 + 0.02), Vector3(0.03, haut, 0.04), cad)
		k.box(c + Vector3(sx * 0.08, haut * 0.5 - 0.02, 0), Vector3(0.03, 0.04, larg), cad)
		k.box(c + Vector3(sx * 0.08, -haut * 0.5 + 0.02, 0), Vector3(0.03, 0.04, larg), cad)
	var n := clampi(int(haut / 0.55), 2, 5)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(th.style)) + v
	for i in n:
		var yy := haut * 0.5 - 0.35 - float(i) * (haut - 0.4) / n
		var lettre: Color = pal[1] if asie else (pal[1] if i % 2 == 0 else pal[0])
		for sx in [-1.0, 1.0]:
			# Un « idéogramme » en trois traits, ou une lettre en deux.
			k.box(c + Vector3(sx * 0.08, yy, 0), Vector3(0.03, 0.05, larg * 0.6), lettre)
			k.box(c + Vector3(sx * 0.08, yy - 0.12, rng.randf_range(-0.08, 0.08)), Vector3(0.03, 0.2, 0.05), lettre)
			if asie:
				k.box(c + Vector3(sx * 0.08, yy - 0.22, 0), Vector3(0.03, 0.04, larg * 0.45), lettre)
	k.layer = "base"


static func _escalier(k: LpKit, depart: Vector3, montee: float, fin_z: float, annee: int) -> void:
	# Escalier contre le mur de droite, qui monte vers l'arrière jusqu'à un palier.
	var x := depart.x + 0.45
	var pente := 0.78
	var course := montee / pente
	var z0 := depart.z
	var z1 := minf(z0 + course, fin_z - 1.0)
	var n := maxi(int(montee / 0.19), 4)
	var col := Color("bdb6a9") if annee < 1950 else Color("c9c5bd")
	var marche := (z1 - z0) / n
	for i in n:
		var y := montee * float(i + 1) / n
		k.box(Vector3(x, y - 0.05, z0 + marche * (float(i) + 0.5)), Vector3(0.85, 0.1, marche + 0.02), col)
	# Limon plein jusqu'au sol (le dessous des marches).
	k.quad(Vector3(x + 0.43, 0, z0), Vector3(x + 0.43, 0, z1), Vector3(x + 0.43, montee, z1), Vector3(x + 0.43, 0.05, z0), col.darkened(0.12), Vector3.RIGHT)
	# Palier et porte.
	k.box(Vector3(x, montee - 0.05, z1 + 0.6), Vector3(0.9, 0.12, 1.2), col)
	k.box(Vector3(x, montee - 1.0, z1 + 0.6), Vector3(0.9, 1.9, 1.2), col.darkened(0.05))
	k.box(Vector3(depart.x + 0.02, montee + 1.05, z1 + 0.6), Vector3(0.06, 2.0, 0.9), BOIS_SOMBRE)
	# Rampe : main courante et poteaux.
	var colr := FONTE if annee < 1960 else METAL
	k.beam(Vector3(x + 0.4, 0.95, z0), Vector3(x + 0.4, montee + 0.95, z1), 0.05, 0.05, colr)
	k.beam(Vector3(x + 0.4, montee + 0.95, z1), Vector3(x + 0.4, montee + 0.95, z1 + 1.2), 0.05, 0.05, colr)
	for i in range(0, n + 1, 3):
		var f := float(i) / n
		var y := montee * f
		k.box(Vector3(x + 0.4, y + 0.5, z0 + (z1 - z0) * f), Vector3(0.04, 0.95, 0.04), colr)
	# Pots sur les marches.
	for i in [2, 5]:
		if i < n:
			var y := montee * float(i + 1) / n
			var zz := z0 + marche * (float(i) + 0.5)
			k.lathe(Vector3(x - 0.25, y, zz), [Vector2(0.1, 0.0), Vector2(0.13, 0.22)], 7, TERRE_CUITE, true, false)
			k.blob(Vector3(x - 0.25, y + 0.35, zz), Vector3(0.17, 0.18, 0.17), FEUILLE, FEUILLE_CLAIRE, 0.3, 0)


static func _echelle(k: LpKit, p: Vector3, haut: float) -> void:
	for sz in [-0.2, 0.2]:
		k.beam(p + Vector3(0, 0.9, sz), p + Vector3(0, haut, sz), 0.04, 0.04, METAL_SOMBRE)
	for i in int((haut - 0.9) / 0.3):
		k.box(p + Vector3(0, 1.0 + 0.3 * i, 0), Vector3(0.03, 0.03, 0.4), METAL_SOMBRE)
	# Crinoline en haut.
	for i in 3:
		k.box(p + Vector3(0.3, haut - 0.4 - 0.6 * i, 0), Vector3(0.03, 0.03, 0.7), METAL_SOMBRE)


static func _auvent_tuiles(k: LpKit, larg: float, y: float) -> void:
	var prof := 0.9
	var n := int(larg / 0.22)
	for i in n:
		var x := -larg * 0.5 + (float(i) + 0.5) * larg / n
		var c := Color("3a3f45").lightened(0.06 * float(i % 2))
		k.beam(Vector3(x, y, -0.05), Vector3(x, y - 0.38, -prof), 0.2, 0.06, c)
	k.box(Vector3(0, y - 0.42, -prof - 0.02), Vector3(larg + 0.1, 0.08, 0.1), Color("2c3035"))
	for sx in [-1.0, 1.0]:
		k.beam(Vector3(sx * (larg * 0.5 - 0.1), y - 0.4, -0.05), Vector3(sx * (larg * 0.5 - 0.1), y - 0.4, -prof), 0.08, 0.08, BOIS_SOMBRE)


# --- Trottoir ------------------------------------------------------------------------------

static func _lampadaire(k: LpKit, p: Vector3, sorte: String, region: String) -> void:
	match sorte:
		"gaz":
			k.tube(p, p + Vector3(0, 0.5, 0), 0.14, 0.1, 6, FONTE)
			k.tube(p + Vector3(0, 0.5, 0), p + Vector3(0, 2.9, 0), 0.07, 0.05, 6, FONTE)
			k.beam(p + Vector3(-0.25, 2.5, 0), p + Vector3(0.25, 2.5, 0), 0.03, 0.03, FONTE)
			k.layer = "lumiere"
			k.lathe(p + Vector3(0, 2.95, 0), [Vector2(0.12, 0.0), Vector2(0.2, 0.4)], 4, Color("ffd890"), true, false)
			k.layer = "base"
			k.lathe(p + Vector3(0, 3.35, 0), [Vector2(0.25, 0.0), Vector2(0.03, 0.2)], 4, FONTE, true, false)
		"fonte":
			k.tube(p, p + Vector3(0, 0.6, 0), 0.16, 0.11, 8, FONTE)
			k.tube(p + Vector3(0, 0.6, 0), p + Vector3(0, 3.6, 0), 0.08, 0.06, 8, FONTE)
			for sx in [-1.0, 1.0]:
				k.beam(p + Vector3(0, 3.4, 0), p + Vector3(sx * 0.45, 3.65, 0), 0.04, 0.04, FONTE)
				k.layer = "lumiere"
				k.blob(p + Vector3(sx * 0.45, 3.85, 0), Vector3(0.16, 0.18, 0.16), Color("fff0cf"), Color("fff6e2"), 0.0, 0)
				k.layer = "base"
		"crosse":
			k.tube(p, p + Vector3(0, 5.2, 0), 0.08, 0.06, 6, METAL)
			k.beam(p + Vector3(0, 5.2, 0), p + Vector3(0, 5.45, 1.3), 0.06, 0.06, METAL)
			k.box(p + Vector3(0, 5.42, 1.4), Vector3(0.28, 0.12, 0.55), METAL_SOMBRE)
			k.layer = "lumiere"
			k.box(p + Vector3(0, 5.35, 1.4), Vector3(0.22, 0.04, 0.45), Color("ffd9a0"))
			k.layer = "base"
		_:
			k.box(p + Vector3(0, 2.4, 0), Vector3(0.14, 4.8, 0.14), Color("3a3d40"))
			k.box(p + Vector3(0, 4.75, -0.35), Vector3(0.16, 0.08, 0.7), Color("3a3d40"))
			k.layer = "lumiere"
			k.box(p + Vector3(0, 4.7, -0.4), Vector3(0.12, 0.03, 0.55), Color("f4f6ff"))
			k.layer = "base"
	# Feu de signalisation piéton en Asie de l'Est (comme au coin d'une rue).
	if region == "asie_est" and sorte != "gaz":
		k.box(p + Vector3(0.15, 2.4, 0), Vector3(0.18, 0.45, 0.18), Color("2b2d30"))
		k.layer = "nuit"
		k.box(p + Vector3(0.15, 2.5, -0.1), Vector3(0.1, 0.1, 0.02), Color("ff4433"))
		k.box(p + Vector3(0.15, 2.3, -0.1), Vector3(0.1, 0.1, 0.02), Color("33dd66"))
		k.layer = "base"


static func _arbre(k: LpKit, p: Vector3, sorte: String, saison: String, v: int) -> void:
	# Grille au pied de l'arbre.
	k.box(p + Vector3(0, 0.03, 0), Vector3(1.1, 0.06, 1.1), Color("3c3f42"))
	match sorte:
		"palmier":
			var haut := 4.8 + 0.6 * v
			var tete := p + Vector3(0.35, haut, 0.1)
			var segs := 6
			for i in segs:
				var a := p.lerp(tete, float(i) / segs) + Vector3(sin(float(i) * 0.6) * 0.06, 0, 0)
				var b := p.lerp(tete, float(i + 1) / segs)
				k.tube(a, b, 0.16 - 0.01 * i, 0.15 - 0.01 * i, 6, Color("8a7055"))
			for i in 8:
				var ang := TAU * float(i) / 8.0
				var dir := Vector3(cos(ang), 0, sin(ang))
				var mid := tete + dir * 1.0 + Vector3(0, 0.25, 0)
				var bout := tete + dir * 1.9 + Vector3(0, -0.5, 0)
				k.beam(tete, mid, 0.5, 0.05, FEUILLE, dir.cross(Vector3.UP))
				k.beam(mid, bout, 0.4, 0.04, FEUILLE_CLAIRE, dir.cross(Vector3.UP))
		_:
			var haut := 3.0 + 0.4 * v
			k.tube(p, p + Vector3(0.1, haut, 0), 0.14, 0.09, 6, Color("6b4a35"))
			k.beam(p + Vector3(0.05, haut * 0.7, 0), p + Vector3(0.7, haut + 0.4, 0.2), 0.08, 0.08, Color("6b4a35"))
			k.beam(p + Vector3(0.05, haut * 0.75, 0), p + Vector3(-0.6, haut + 0.5, -0.2), 0.08, 0.08, Color("6b4a35"))
			var bas := FEUILLE
			var haut_c := FEUILLE_CLAIRE
			var nu := false
			match sorte:
				"cerisier":
					if saison == "printemps":
						bas = Color("e07aa5"); haut_c = Color("ffc2dc")
					elif saison == "automne":
						bas = Color("b5552e"); haut_c = Color("e39a4a")
					elif saison == "hiver":
						nu = true
				"erable":
					if saison == "automne":
						bas = Color("a8271f"); haut_c = Color("ec5a2c")
					elif saison == "hiver":
						nu = true
				"olivier":
					bas = Color("5f7258"); haut_c = Color("a3b398")
				"acacia":
					bas = Color("587a32"); haut_c = Color("93b55a")
				_:
					if saison == "automne":
						bas = Color("b07a2a"); haut_c = Color("e3b44a")
					elif saison == "hiver":
						nu = true
			if nu:
				for i in 4:
					var ang := TAU * float(i) / 4.0 + 0.4
					k.beam(p + Vector3(0.1, haut, 0), p + Vector3(cos(ang) * 0.9, haut + 0.9, sin(ang) * 0.9), 0.05, 0.05, Color("6b4a35"))
				return
			if sorte == "acacia":
				k.blob(p + Vector3(0.1, haut + 0.8, 0), Vector3(1.7, 0.45, 1.5), bas, haut_c, 0.2, 1)
				return
			k.blob(p + Vector3(0.1, haut + 0.7, 0), Vector3(1.25, 1.0, 1.15), bas, haut_c, 0.22, 1)
			k.blob(p + Vector3(0.75, haut + 0.4, 0.3), Vector3(0.75, 0.65, 0.7), bas, haut_c, 0.25, 0)
			k.blob(p + Vector3(-0.6, haut + 0.55, -0.25), Vector3(0.7, 0.6, 0.65), bas, haut_c, 0.25, 0)
			if sorte == "cerisier" and saison == "printemps":
				# Pétales tombés au pied de l'arbre.
				for i in 6:
					var ang := float(i) * 1.3
					k.box(p + Vector3(cos(ang) * (0.7 + 0.1 * i), 0.07, sin(ang) * (0.6 + 0.1 * i)), Vector3(0.25, 0.01, 0.2), Color("ffc2dc"), 0.0, false)


static func _lanterne_murale(k: LpKit, p: Vector3, annee: int) -> void:
	k.beam(p + Vector3(0, 0.1, 0.05), p + Vector3(0, 0.1, -0.25), 0.03, 0.03, FONTE)
	k.layer = "neon"
	if annee < 1900:
		k.lathe(p + Vector3(0, -0.15, -0.28), [Vector2(0.07, 0.0), Vector2(0.11, 0.25)], 4, Color("ffcf7a"), true, false)
	else:
		k.lathe(p + Vector3(0, -0.12, -0.28), [Vector2(0.06, 0.0), Vector2(0.09, 0.08), Vector2(0.06, 0.22)], 6, Color("ffe7b0"), true, true)
	k.layer = "base"
	k.lathe(p + Vector3(0, 0.1, -0.28), [Vector2(0.13, 0.0), Vector2(0.02, 0.1)], 4, FONTE, true, false)


static func _lanterne(k: LpKit, p: Vector3, sorte: String, i: int) -> void:
	k.beam(p + Vector3(0, 0.45, 0), p + Vector3(0, 0.12, 0), 0.015, 0.015, Color("1d1f21"))
	k.layer = "neon"
	match sorte:
		"papier":
			var c := Color("e0342b") if i % 3 != 2 else Color("f2e6c8")
			k.lathe(p + Vector3(0, -0.32, 0), [Vector2(0.06, 0.0), Vector2(0.17, 0.08), Vector2(0.2, 0.22), Vector2(0.17, 0.36), Vector2(0.06, 0.44)], 8, c, true, true)
		"couleurs":
			var cs := [Color("ff8a3d"), Color("f5d33f"), Color("e24a7d"), Color("47b8e0")]
			k.blob(p + Vector3(0, -0.1, 0), Vector3(0.16, 0.18, 0.16), cs[i % 4], cs[i % 4].lightened(0.2), 0.1, 0)
		_:
			k.lathe(p + Vector3(0, -0.35, 0), [Vector2(0.05, 0.0), Vector2(0.14, 0.12), Vector2(0.14, 0.3), Vector2(0.04, 0.46)], 6, Color("ffb85c"), true, true)
	k.layer = "base"
	if sorte == "papier":
		k.lathe(p + Vector3(0, 0.1, 0), [Vector2(0.08, 0.0), Vector2(0.08, 0.04)], 6, Color("1d1f21"), true, true)
		k.lathe(p + Vector3(0, -0.36, 0), [Vector2(0.08, 0.0), Vector2(0.08, 0.04)], 6, Color("1d1f21"), true, true)
	elif sorte == "cuivre":
		k.lathe(p + Vector3(0, 0.1, 0), [Vector2(0.16, 0.0), Vector2(0.02, 0.16)], 6, Color("a8692e"), true, false)
		for j in 6:
			var ang := TAU * float(j) / 6.0
			k.beam(p + Vector3(cos(ang) * 0.14, -0.35, sin(ang) * 0.14), p + Vector3(cos(ang) * 0.14, 0.1, sin(ang) * 0.14), 0.02, 0.02, Color("a8692e"))


static func _fanions(k: LpKit, a: Vector3, b: Vector3, v: int) -> void:
	var cs := [Color("e74c3c"), Color("f1c40f"), Color("2ecc71"), Color("3498db"), Color("9b59b6"), Color("ff7f50")]
	var n := int(a.distance_to(b) / 0.32)
	var prev := a
	for i in n + 1:
		var f := float(i) / n
		var q := a.lerp(b, f) + Vector3(0, -0.35 * sin(PI * f), 0)
		if i > 0:
			k.beam(prev, q, 0.015, 0.015, Color("3a3a3a"))
			var m := (prev + q) * 0.5
			var c: Color = cs[(i + v) % cs.size()]
			var bas := m + Vector3(0, -0.28, 0)
			var dir := (q - prev).normalized() * 0.13
			k.tri(m - dir, m + dir, bas, c, Vector3(0, 0, -1))
			k.tri(m - dir, m + dir, bas, c.darkened(0.15), Vector3(0, 0, 1))
		prev = q


static func _noren(k: LpKit, p: Vector3, v: int) -> void:
	var c := Color("1f3b63") if v != 1 else Color("7a2430")
	k.beam(p + Vector3(-0.6, 0.02, -0.02), p + Vector3(0.6, 0.02, -0.02), 0.04, 0.04, BOIS)
	for i in 3:
		var x := -0.38 + 0.38 * i
		k.box(p + Vector3(x, -0.32, -0.05), Vector3(0.36, 0.62, 0.02), c)
	k.box(p + Vector3(0, -0.3, -0.07), Vector3(0.22, 0.22, 0.01), Color("efe9dd"))


static func _tabouret(k: LpKit, p: Vector3, annee: int) -> void:
	var siege := Color("c0392b") if annee >= 1950 else BOIS_SOMBRE
	k.tube(p, p + Vector3(0, Accessoires.ASSISE - 0.05, 0), 0.04, 0.04, 5, METAL_SOMBRE if annee >= 1930 else BOIS)
	k.lathe(p + Vector3(0, 0, 0), [Vector2(0.16, 0.0), Vector2(0.16, 0.02)], 6, METAL_SOMBRE, false, true)
	k.lathe(p + Vector3(0, Accessoires.ASSISE - 0.06, 0), [Vector2(0.18, 0.0), Vector2(0.19, 0.06)], 8, siege, true, true)


static func _distributeur(k: LpKit, p: Vector3, v: int, annee: int) -> void:
	var corps: Color = [Color("c8262e"), Color("e9ece9"), Color("2a5fa8")][v % 3]
	k.box(p + Vector3(0, 0.92, 0), Vector3(0.9, 1.84, 0.72), corps)
	k.box(p + Vector3(0, 0.04, 0), Vector3(0.92, 0.08, 0.74), Color("2b2d30"))
	k.layer = "nuit"
	# Vitrine éclairée : trois rangées de canettes.
	k.box(p + Vector3(-0.08, 1.25, -0.37), Vector3(0.62, 0.8, 0.02), Color("e8f4ff"))
	k.layer = "base"
	var cs := [Color("d63031"), Color("0984e3"), Color("fdcb6e"), Color("00b894"), Color("e17055")]
	for r in 3:
		for c in 5:
			k.box(p + Vector3(-0.32 + 0.12 * c, 1.0 + 0.25 * r, -0.39), Vector3(0.07, 0.14, 0.02), cs[(c + r + v) % 5])
	# Boutons, monnayeur, trappe.
	k.box(p + Vector3(0.33, 1.2, -0.37), Vector3(0.12, 0.5, 0.02), Color("3a3d40"))
	k.box(p + Vector3(0, 0.35, -0.37), Vector3(0.6, 0.2, 0.02), Color("1d1f21"))
	if annee >= 1990:
		k.box(p + Vector3(0, 1.95, -0.2), Vector3(0.9, 0.18, 0.3), corps.darkened(0.2))
	# Poubelle de canettes à côté.
	k.lathe(p + Vector3(0.75, 0, -0.1), [Vector2(0.18, 0.0), Vector2(0.2, 0.75)], 8, Color("4b7a4b") if v != 2 else Color("6d7680"), true, true)


static func _pot(k: LpKit, p: Vector3, r: float, region: String, saison: String, i: int) -> void:
	var c := TERRE_CUITE if region != "asie_est" else (Color("3a4c5c") if i % 2 == 0 else Color("8a7d6a"))
	k.lathe(p, [Vector2(r * 0.75, 0.0), Vector2(r, r * 2.0), Vector2(r * 1.08, r * 2.1)], 8, c, true, true)
	var top := p + Vector3(0, r * 2.1, 0)
	match i % 3:
		0:
			# Petit arbuste rond.
			k.blob(top + Vector3(0, r * 1.4, 0), Vector3(r * 1.5, r * 1.6, r * 1.5), FEUILLE, FEUILLE_CLAIRE, 0.25, 0)
		1:
			# Fleurs.
			k.blob(top + Vector3(0, r * 0.8, 0), Vector3(r * 1.3, r * 0.9, r * 1.3), FEUILLE, FEUILLE_CLAIRE, 0.25, 0)
			if saison in ["printemps", "ete"]:
				for j in 4:
					var ang := TAU * float(j) / 4.0 + 0.3
					k.box(top + Vector3(cos(ang) * r * 0.8, r * 1.5, sin(ang) * r * 0.8), Vector3(0.08, 0.08, 0.08), Color.from_hsv(fmod(0.92 + 0.08 * j, 1.0), 0.65, 0.95))
		_:
			# Plante en feuilles hautes (bambou, sansevière, cactus selon la région).
			var cf := Color("6c8a3d") if region in ["moyen_orient", "afrique"] else FEUILLE
			for j in 5:
				var ang := TAU * float(j) / 5.0
				k.beam(top, top + Vector3(cos(ang) * r * 0.9, r * 4.0 + 0.1 * j, sin(ang) * r * 0.9), 0.06, 0.03, cf.lightened(0.05 * j))


static func _banc(k: LpKit, p: Vector3, annee: int) -> void:
	var bois := BOIS if annee < 1990 else Color("b98a5a")
	for i in 3:
		k.box(p + Vector3(0, 0.45, -0.12 + 0.13 * i), Vector3(1.6, 0.05, 0.11), bois)
	for i in 2:
		k.box(p + Vector3(0, 0.65 + 0.15 * i, 0.22), Vector3(1.6, 0.1, 0.04), bois)
	for sx in [-0.7, 0.7]:
		k.box(p + Vector3(sx, 0.22, 0.05), Vector3(0.06, 0.45, 0.45), FONTE)
		k.box(p + Vector3(sx, 0.62, 0.22), Vector3(0.06, 0.4, 0.06), FONTE)


static func _velo(k: LpKit, p: Vector3, v: int) -> void:
	var cadre: Color = [Color("2e86c1"), Color("c0392b"), Color("1e8449")][v % 3]
	var r := 0.33
	for sx in [-0.5, 0.5]:
		var c := p + Vector3(sx, r, 0)
		var n := 8
		for i in n:
			var a0 := TAU * float(i) / n
			var a1 := TAU * float(i + 1) / n
			k.beam(c + Vector3(cos(a0) * r, sin(a0) * r, 0), c + Vector3(cos(a1) * r, sin(a1) * r, 0), 0.03, 0.04, Color("1d1f21"))
	k.beam(p + Vector3(-0.5, r, 0), p + Vector3(-0.05, r + 0.38, 0), 0.04, 0.04, cadre)
	k.beam(p + Vector3(-0.5, r, 0), p + Vector3(0.0, r, 0), 0.04, 0.04, cadre)
	k.beam(p + Vector3(0.0, r, 0), p + Vector3(0.4, r + 0.42, 0), 0.04, 0.04, cadre)
	k.beam(p + Vector3(-0.05, r + 0.38, 0), p + Vector3(0.4, r + 0.42, 0), 0.04, 0.04, cadre)
	k.beam(p + Vector3(0.4, r + 0.42, 0), p + Vector3(0.5, r, 0), 0.04, 0.04, cadre)
	k.box(p + Vector3(-0.1, r + 0.48, 0), Vector3(0.22, 0.05, 0.1), Color("1d1f21"))
	k.beam(p + Vector3(0.4, r + 0.42, 0), p + Vector3(0.38, r + 0.6, 0), 0.03, 0.03, cadre)
	k.box(p + Vector3(0.38, r + 0.6, 0), Vector3(0.04, 0.04, 0.45), Color("1d1f21"))
