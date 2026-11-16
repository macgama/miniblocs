class_name MateriauxChantiers
extends RefCounted
## Matériaux des chantiers : un bâtiment ou une voie en construction consomme
## de vraies marchandises, celles de son époque (Epoques).
##
## - Vers 1800, une maison se bâtit en pierre, chaux et bois, couverte de
##   tuiles ; après 1850 arrivent la brique, le fer et le verre ; après 1900, le
##   ciment ; après 1950, le béton armé (ciment, sable, granulats, acier).
## - Les quantités suivent la surface de plancher (≈ 1 t par m² pour une
##   maison en maçonnerie) ; elles sont prises au fil des travaux, comme le
##   paiement : 10 % d'avancement = 10 % des matériaux.
## - Le chantier se sert d'abord dans les stocks de la carte (carrière, four
##   à chaux, scierie, briqueterie, entrepôt…), du plus proche au plus loin :
##   l'entreprise est payée au prix du marché intérieur, sur le prix du
##   chantier (rien de plus pour la caisse). Ce qui manque vient de l'extérieur
##   (import, déjà compris dans le prix du chantier).
##
## Le prix d'un chantier ne change donc pas : une ville qui produit ses
## matériaux fait travailler ses carrières et ses usines (emplois, impôts sur
## les bénéfices) au lieu d'acheter ailleurs.

## Recettes (t par m² de plancher) : [jusqu'à l'année (exclue), {marchandise: t}].
const RECETTES := [
	[1850, {"pierre": 0.75, "chaux": 0.08, "sable": 0.10, "bois": 0.12, "tuiles": 0.05}],
	[1900, {"pierre": 0.45, "briques": 0.25, "chaux": 0.06, "sable": 0.12, "bois": 0.10, "tuiles": 0.05, "verre": 0.01,
		"acier": 0.01}],
	[1950, {"briques": 0.40, "ciment": 0.06, "sable": 0.20, "pierre": 0.20, "acier": 0.02, "planches": 0.05, "bois": 0.03,
		"tuiles": 0.05, "verre": 0.015}],
	[99999, {"ciment": 0.12, "sable": 0.35, "pierre": 0.50, "acier": 0.04, "verre": 0.02, "planches": 0.02, "tuiles": 0.03,
		"briques": 0.05, "plastique": 0.005}],
]
## Bâtiments en bois (chalets, cabanes, maisons à ossature bois).
const MOTS_BOIS := ["bois", "chalet", "cabane", "isba", "datcha", "grange", "refuge", "kota", "fare", "minka"]
## Places, parcs, jardins : un peu de pierre et de sable par m² de terrain.
const ESPACES := {"pierre": 0.10, "sable": 0.05}
## Voies (t par m² de chaussée) ; rail en t par mètre de voie.
const VOIE_ROUTE := {"pierre": 0.6, "sable": 0.2}
const VOIE_ROUTE_MODERNE := {"pierre": 0.6, "sable": 0.15, "ciment": 0.02}
const VOIE_RAIL_M := {"pierre": 1.5, "acier": 0.12, "bois": 0.08}
const VOIE_RAIL_M_MODERNE := {"pierre": 1.5, "acier": 0.12, "ciment": 0.10}
## Rayon (m) où l'on va chercher les matériaux sur la carte.
const RAYON := 30000.0


static func _annee() -> int:
	return Epoques.annee() if Epoques.actif() else 2025


## Recette de l'époque (t par m² de plancher).
static func recette(annee := -1) -> Dictionary:
	if annee < 0:
		annee = _annee()
	for r in RECETTES:
		if annee < int(r[0]):
			return r[1]
	return RECETTES[-1][1]


## Tout ce qu'il faut pour un type de bâtiment (t) : {marchandise: t}.
static func besoins_batiment(type_id: String, annee := -1) -> Dictionary:
	var t := BuildingCatalog.get_type(type_id)
	if t.is_empty():
		return {}
	if MonumentsTypes.est_monument(type_id):
		return MonumentsTypes.materiaux(type_id)
	var w := float(t.get("w", 8))
	var d := float(t.get("d", 8))
	var out := {}
	if String(t.get("cat", "")) == "espaces":
		for g in ESPACES:
			out[g] = float(ESPACES[g]) * w * d
		return out
	var etages := maxf(1.0, ceilf(BuildingCatalog.approx_height(type_id) / 3.0))
	# Emprise bâtie : les grands terrains (usines, fermes) ne sont pas bâtis partout.
	var emprise := w * d * (0.6 if w * d > 400.0 else 0.8)
	var plancher := emprise * etages
	var rec := recette(annee)
	var hay := (type_id + " " + String(t.get("name", "")) + " " + String(t.get("style", ""))).to_lower()
	var en_bois := false
	for m in MOTS_BOIS:
		if hay.contains(m):
			en_bois = true
			break
	var industrie := String(t.get("cat", "")) in ["industrie", "production"]
	for g in rec:
		var q := float(rec[g]) * plancher
		if en_bois:
			if g == "bois" or g == "planches":
				q *= 4.0
			elif g in ["pierre", "briques", "ciment"]:
				q *= 0.3
		if industrie and g == "acier":
			q *= 2.5
		out[g] = q
	if en_bois and not out.has("planches") and Ressources.disponible("planches"):
		out["planches"] = 0.05 * plancher
	return out


## Matériaux d'un tronçon de voie (t).
static func besoins_voie(type_id: String, longueur: float, largeur: float, annee := -1) -> Dictionary:
	if annee < 0:
		annee = _annee()
	var mode := TransportTypes.mode_of(type_id)
	var out := {}
	match mode:
		TransportTypes.Mode.RAIL:
			var rec: Dictionary = VOIE_RAIL_M if annee < 1950 else VOIE_RAIL_M_MODERNE
			for g in rec:
				out[g] = float(rec[g]) * longueur
		TransportTypes.Mode.WATER, TransportTypes.Mode.AIR:
			pass
		TransportTypes.Mode.PATH:
			out["sable"] = 0.15 * longueur * maxf(largeur, 1.5)
		_:
			var rec: Dictionary = VOIE_ROUTE if annee < 1920 else VOIE_ROUTE_MODERNE
			for g in rec:
				out[g] = float(rec[g]) * longueur * maxf(largeur, 3.0)
	return out


## Texte court : « 85 t de pierre, 9 t de chaux, 14 t de bois ».
static func texte(m: Dictionary, n := 4) -> String:
	var ks := m.keys()
	ks.sort_custom(func(a, b) -> bool: return float(m[a]) > float(m[b]))
	var out: Array[String] = []
	for g in ks:
		if out.size() >= n or float(m[g]) < 0.05:
			break
		out.append("%s de %s" % [Ressources.format_t(float(m[g])), Ressources.good_name(String(g)).to_lower()])
	return ", ".join(out)


## Fournit la part `dp` (0 à 1) des matériaux `total` à un chantier situé en
## `pos` : prise dans les stocks de la carte d'abord, sinon importée. Rend
## {"local": {g: t}, "import": {g: t}, "valeur_locale": €}.
static func fournir(total: Dictionary, dp: float, pos: Vector3) -> Dictionary:
	var res := {"local": {}, "import": {}, "valeur_locale": 0.0}
	if dp <= 0.0 or total.is_empty():
		return res
	var prod := Production.instance
	for g in total:
		var besoin := float(total[g]) * dp
		if besoin <= 0.0:
			continue
		var reste := besoin
		if prod != null and is_instance_valid(prod):
			for bid in _sources(prod, String(g), pos):
				if reste <= 0.000001:
					break
				var pris := minf(prod.stock_of(bid, String(g)), reste)
				if pris <= 0.0:
					continue
				prod.put(bid, String(g), -pris)
				var v := pris * Ressources.prix_interieur(String(g))
				prod.pay(bid, "Ventes aux chantiers", v)
				res.valeur_locale = float(res.valeur_locale) + v
				reste -= pris
				res.local[g] = float(res.local.get(g, 0.0)) + pris
		if reste > 0.000001:
			res.import[g] = float(res.import.get(g, 0.0)) + reste
	return res


## Sites de la carte qui ont la marchandise en stock, du plus proche au plus loin
## (pas les commerces : on ne vide pas les rayons pour un chantier).
static func _sources(prod: Production, g: String, pos: Vector3) -> Array:
	var out := []
	for bid in prod.sites:
		var s: Dictionary = prod.sites[bid]
		if String(s.kind) == "commerce" or float(s.st.get(g, 0.0)) <= 0.0:
			continue
		var p := prod._pos_of(int(bid))
		var dist := Vector2(p.x - pos.x, p.z - pos.z).length()
		if dist <= RAYON:
			out.append([dist, int(bid)])
	out.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var ids := []
	for e in out:
		ids.append(e[1])
	return ids


## Ajoute les quantités fournies au bilan d'un chantier (dictionnaires {g: t}).
static func cumule(bilan: Dictionary, f: Dictionary) -> void:
	for g in f:
		bilan[g] = float(bilan.get(g, 0.0)) + float(f[g])
