class_name KitInstallation
extends Node
## Kit d'installation offert par l'État : la première ville fondée dans chaque
## pays du monde (pays réel du lieu : France, Suisse…) reçoit des « bons » pour
## le minimum vital, à poser toi-même où tu veux :
##   - électricité, eau potable, égouts, déchets : un bâtiment de chaque, du type
##     de ton choix (centrale, éoliennes, solaire, barrage, forage, captage,
##     lagunage, station d'épuration, déchèterie, dépôt…) ;
##   - le bon paie le bâtiment jusqu'à un plafond (de quoi servir une petite
##     ville, environ 500 habitants) ; au-delà, la ville paie la différence ;
##   - le chantier se fait comme les autres, avec les fondateurs : l'État envoie
##     un renfort d'ouvriers (RENFORT) pour qu'ils ne manquent pas aux maisons.
## Un bon sert pour un bâtiment sur le territoire de la ville, ou hors des villes
## à moins de RAYON_HORS m de sa mairie (captage au bord d'une rivière…).
## Sauvegarde : section « kit » (terre_main.save_sections).

signal changed
signal message(text: String)

static var instance: KitInstallation

## Bons du kit : id -> [nom, plafond en € (× coût des constructions), exemples].
const BONS := {
	"elec": ["Électricité", 25_000_000, "centrale biomasse ou au charbon, raccordement national, éoliennes, solaire"],
	"eau": ["Eau potable", 8_000_000, "forage et station de pompage, captage en rivière"],
	"egout": ["Égouts", 10_000_000, "lagunage, station d'épuration compacte"],
	"dechets": ["Déchets", 3_000_000, "déchèterie, dépôt de collecte, décharge"],
}
const ORDRE := ["elec", "eau", "egout", "dechets"]
## Ouvriers envoyés par l'État avec le kit.
const RENFORT := 40
const RAYON_HORS := 3000.0

var buildings: BuildingSystem
var communes: Communes
var fondateurs: Fondateurs
var world: TerrainWorld

## Bons restants par ville : vid -> {bon: true}.
var bons := {}
## Bons utilisés : vid -> {bon: [bid, type]}.
var utilises := {}
## Pays déjà servis : code (minuscules) -> vid de la ville qui a reçu le kit.
var pays_servis := {}
## Pour les tests : Callable(vid) -> code du pays, à la place de la géographie.
var pays_de: Callable


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func setup(bs: BuildingSystem, cm: Communes, f: Fondateurs, w: TerrainWorld) -> void:
	buildings = bs
	communes = cm
	fondateurs = f
	world = w
	bs.remise = remise
	bs.remise_utilisee = utiliser
	cm.fonde.connect(_on_fonde)
	cm.fusion.connect(_on_fusion)


func clear() -> void:
	bons.clear()
	utilises.clear()
	pays_servis.clear()
	changed.emit()


# --- Pays d'une ville --------------------------------------------------------------------

## Code du pays réel où se trouve la ville (« fr », « ch »…), "" si inconnu.
func code_pays(vid: int) -> String:
	if pays_de.is_valid():
		return String(pays_de.call(vid)).to_lower()
	if communes == null or not communes.villages.has(vid):
		return ""
	var c: Vector2 = communes.villages[vid].c
	var olat := world.origin_lat if world != null else GameStart.lat
	var olon := world.origin_lon if world != null else GameStart.lon
	var lat := Geo.local_to_lat(olat, c.y)
	var lon := Geo.local_to_lon(olat, olon, c.x)
	var v := Villes.plus_proche(lat, lon, 60.0)
	if not v.is_empty() and String(v.get("pays", "")) != "":
		return String(v.pays).to_lower()
	return GameStart.pays.to_lower()


func nom_pays(code: String) -> String:
	if code == "":
		return "ce pays"
	return Villes.nom_pays(code)


# --- Attribution -------------------------------------------------------------------------

func _on_fonde(vid: int) -> void:
	if communes == null or communes.ignorer or not communes.actif:
		return
	var code := code_pays(vid)
	if pays_servis.has(code):
		return
	# La toute première ville d'une partie qui a déjà ses habitants (ancienne
	# partie adoptée) ne reçoit rien : elle a déjà ses réseaux.
	if communes.villages.size() == 1 and fondateurs != null and fondateurs.population != null \
			and not fondateurs.population.persons.is_empty() and not fondateurs.arrives:
		pays_servis[code] = vid
		return
	accorder(vid, code)


## Donne le kit à une ville (et note le pays comme servi).
func accorder(vid: int, code: String) -> void:
	pays_servis[code] = vid
	var b := {}
	for id in ORDRE:
		b[id] = true
	bons[vid] = b
	var ouvriers := 0
	if fondateurs != null and ReglagesPartie.actuel.fondateurs > 0:
		ouvriers = RENFORT
		fondateurs.renfort(RENFORT)
	var nom := String(communes.villages[vid].nom) if communes.villages.has(vid) else "ta ville"
	message.emit("Pays d'accueil : %s. L'État offre à %s son kit d'installation : électricité, eau, égouts et déchets, à poser où tu veux (Maj+P pour les détails)%s." % [
		nom_pays(code), nom, " et envoie %d ouvriers pour les chantiers" % ouvriers if ouvriers > 0 else ""])
	changed.emit()


func _on_fusion(garde: int, partie: int) -> void:
	if bons.has(partie):
		var b: Dictionary = bons.get(garde, {})
		for id in bons[partie]:
			b[id] = true
		bons[garde] = b
		bons.erase(partie)
	if utilises.has(partie):
		var u: Dictionary = utilises.get(garde, {})
		u.merge(utilises[partie])
		utilises[garde] = u
		utilises.erase(partie)
	for code in pays_servis:
		if int(pays_servis[code]) == partie:
			pays_servis[code] = garde
	changed.emit()


# --- Bons ----------------------------------------------------------------------------------

## Bon qui peut servir pour ce type de bâtiment ("" : aucun).
static func bon_du_type(id: String) -> String:
	var t := BuildingCatalog.get_type(id)
	if t.has("dechets"):
		return "dechets"
	var r: Dictionary = t.get("reseau", {})
	if r.is_empty() or float(r.get("cap", 0.0)) <= 0.0:
		return ""
	match String(r.get("res", "")):
		"elec": return "elec"
		"eau": return "eau"
		"egout": return "egout"
	return ""


func plafond(bon: String) -> int:
	return ReglagesPartie.prix(int(BONS[bon][1]))


## Ville dont un bon peut payer un bâtiment posé là (-1 : aucune).
func ville_du_lieu(rect: Rect2i) -> int:
	if communes == null:
		return -1
	var c := Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y + rect.size.y * 0.5)
	var vid := communes.village_au_point(c.x, c.y)
	if vid >= 0:
		return vid
	# Hors des villes : la mairie la plus proche, pas trop loin.
	var best := -1
	var bd := RAYON_HORS
	for v in communes.villages:
		var d := (communes.villages[v].c as Vector2).distance_to(c)
		if d < bd:
			bd = d
			best = int(v)
	return best


func a_le_bon(vid: int, bon: String) -> bool:
	return bon != "" and bool((bons.get(vid, {}) as Dictionary).get(bon, false))


## Appelé par BuildingSystem.check_place : part du prix payée par un bon.
func remise(id: String, rect: Rect2i, cout: int) -> int:
	var bon := bon_du_type(id)
	if bon == "" or cout <= 0:
		return 0
	var vid := ville_du_lieu(rect)
	if not a_le_bon(vid, bon):
		return 0
	return mini(cout, plafond(bon))


## Appelé par BuildingSystem.place quand un bon a servi.
func utiliser(bid: int, id: String, rect: Rect2i) -> void:
	var bon := bon_du_type(id)
	var vid := ville_du_lieu(rect)
	if not a_le_bon(vid, bon):
		return
	(bons[vid] as Dictionary).erase(bon)
	if (bons[vid] as Dictionary).is_empty():
		bons.erase(vid)
	if not utilises.has(vid):
		utilises[vid] = {}
	utilises[vid][bon] = [bid, id]
	var reste := restants(vid)
	message.emit("%s : offert par l'État (kit d'installation). %s" % [String(BuildingCatalog.get_type(id).get("name", id)),
		"Il reste : %s." % ", ".join(reste.map(func(b) -> String: return String(BONS[b][0]).to_lower())) if not reste.is_empty() else "Le kit est complet !"])
	changed.emit()


## Bons restants d'une ville, dans l'ordre.
func restants(vid: int) -> Array:
	var out := []
	for id in ORDRE:
		if a_le_bon(vid, id):
			out.append(id)
	return out


## Texte pour le panneau Pays ("" : pas de kit pour cette ville).
func resume(vid: int) -> String:
	if not bons.has(vid) and not utilises.has(vid):
		return ""
	var parts := []
	for id in ORDRE:
		if a_le_bon(vid, id):
			parts.append("%s (jusqu'à %s)" % [String(BONS[id][0]), BuildingSystem.format_money(plafond(id))])
	if parts.is_empty():
		return "Kit de l'État : tout est posé."
	return "Kit de l'État à poser : " + ", ".join(parts) + "."


# --- Sauvegarde ------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var b := {}
	for vid in bons:
		b[str(vid)] = (bons[vid] as Dictionary).keys()
	var u := {}
	for vid in utilises:
		u[str(vid)] = (utilises[vid] as Dictionary).duplicate(true)
	return {"version": 1, "bons": b, "utilises": u, "pays": pays_servis.duplicate()}


func from_dict(d: Dictionary) -> void:
	bons.clear()
	utilises.clear()
	pays_servis.clear()
	var b: Dictionary = d.get("bons", {})
	for k in b:
		var x := {}
		for id in b[k]:
			x[String(id)] = true
		bons[int(k)] = x
	var u: Dictionary = d.get("utilises", {})
	for k in u:
		var x := {}
		for id in u[k]:
			x[String(id)] = [int(u[k][id][0]), String(u[k][id][1])]
		utilises[int(k)] = x
	var p: Dictionary = d.get("pays", {})
	for k in p:
		pays_servis[String(k)] = int(p[k])
	# Ancienne partie sans section : ses villes ont déjà leurs réseaux.
	if not d.has("pays") and communes != null:
		for vid in communes.villages:
			pays_servis[code_pays(int(vid))] = int(vid)
	changed.emit()
