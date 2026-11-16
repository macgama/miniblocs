class_name Patrimoine
extends Node
## Patrimoine (nœud « Patrimoine » créé par terre_main, menu Fin) :
##
## - Classement : un bâtiment ancien ou remarquable (église, château, phare,
##   théâtre, vieille ferme…) peut être « inscrit » au patrimoine, puis « classé »
##   monument historique quand son intérêt est assez grand. L'intérêt vient de
##   son rôle (monument, lieu de culte, palais…), de son style (traditionnel,
##   classique, XIXe siècle) et de son âge, compté en années de l'histoire
##   (Epoques : un bâtiment construit en 1810 a 100 ans en 1910).
## - Protection : un bâtiment protégé ne se démolit pas (il faut d'abord le
##   déclasser) et ne s'agrandit pas ; aux abords (100 m d'un bâtiment inscrit,
##   200 m d'un bâtiment classé), pas de construction de plus de 45 m (30 m près
##   d'un classé), ni d'usine ou d'installation de déchets.
## - Entretien : la ville paie l'entretien d'un monument protégé (0,12 % de sa
##   valeur par an s'il est inscrit, 0,25 % s'il est classé), l'État en rembourse
##   une part (30 % ou 50 %). Entretenu, il s'use trois fois moins vite ;
##   abandonné, il s'abîme et attire moins. La restauration passe par le chantier
##   de rénovation (Ameliorations), aidée par l'État.
## - Grands monuments (MonumentsTypes) : leurs chantiers durent des années. Les
##   curieux viennent voir le chantier, une souscription populaire et des
##   mécènes peuvent en payer une partie ; à l'inauguration, ils sont classés
##   d'office.
## - Tourisme : chaque monument et bâtiment protégé est un site « patrimoine »
##   (Tourisme._maj_sites, via points_site) ; protégé et bien entretenu, il
##   attire bien plus. Le troisième week-end de septembre, les Journées du
##   patrimoine doublent presque les visites.
##
## Section de sauvegarde « patrimoine ».

signal message(text: String)
signal actualite(text: String, pos: Vector3)
signal changed

static var instance: Patrimoine

const INSCRIT := 1
const CLASSE := 2
const NIVEAUX := ["", "Inscrit au patrimoine", "Classé monument historique"]
const NIVEAUX_COURTS := ["", "Inscrit", "Classé"]
## Intérêt minimal pour inscrire, pour classer.
const SEUILS := [0.0, 1.0, 2.0]
## Frais de dossier (étude, architecte du patrimoine).
const FRAIS := [0, 15_000, 40_000]
## Rayon des abords (m) et hauteur maximale (m) dans les abords.
const ABORDS := [0.0, 100.0, 200.0]
const HAUTEUR_ABORDS := [0.0, 45.0, 30.0]
## Catégories interdites aux abords d'un monument classé ou inscrit.
const CATS_INTERDITES := ["industrie", "dechets"]
## Entretien annuel (part de la valeur) et part remboursée par l'État.
const ENTRETIEN := [0.0, 0.0012, 0.0025]
const SUBVENTION := [0.0, 0.30, 0.50]
## Rythme d'usure : entretenu, ou laissé sans entretien.
const USURE_ENTRETENU := 0.35
const USURE_ABANDON := 1.25
## Aide de l'État à la restauration (part du prix de la rénovation).
const AIDE_RESTAURATION := [0.0, 0.25, 0.40]
## Multiplicateur d'attrait selon la protection.
const BONUS := [1.0, 1.3, 1.7]
## Journées du patrimoine (troisième week-end de septembre) : visites ×1,8.
const JOURNEES := 1.8
## Souscription : don moyen par habitant et par jour, plafond (part du prix).
const DON_HABITANT := 8.0
const PLAFOND_SOUSCRIPTION := 0.25

const ROLES_REMARQUABLES := ["monument", "culte", "palais", "theatre", "chateau", "phare", "gare"]
const MOTS_REMARQUABLES := ["chateau", "cathedrale", "eglise", "chapelle", "abbaye", "temple", "pagode", "mosquee",
	"palais", "phare", "moulin", "halle", "lavoir", "beffroi", "opera", "theatre", "basilique", "tour", "pont", "kiosque"]

var buildings: BuildingSystem
var population: Population
var ambiance: DayNight
var vie: BatimentsVie

## bid -> {"niv": 1 ou 2, "an": année du classement, "entretien": bool}
var proteges := {}
## bid -> année où le bâtiment a été fini (années de l'histoire).
var nes := {}
## bid -> {"actif": bool, "recu": int, "dons": int (donateurs), "mecenes": int}
var souscriptions := {}
## Règles des abords (hauteur, usines) : on peut les assouplir en bac à sable.
var regles_abords := true
## Comptes de la veille et de l'année : entretien, subvention, dons.
var jour := {"entretien": 0.0, "subvention": 0.0, "dons": 0.0, "journees": false}
var annee := {"entretien": 0.0, "subvention": 0.0, "dons": 0.0, "aides": 0.0}
var last_day := -1
var _rng := RandomNumberGenerator.new()
var _frac := 0.0
var _hauteurs := {}


func setup(b: BuildingSystem, p: Population, a: DayNight, v: BatimentsVie) -> void:
	buildings = b
	population = p
	ambiance = a
	vie = v
	instance = self
	_rng.seed = 1789
	if buildings != null:
		buildings.added.connect(_on_added)
		buildings.removed.connect(_on_removed)
		for bid in buildings.buildings:
			_on_added(int(bid))


func _exit_tree() -> void:
	if instance == self:
		instance = null


func clear() -> void:
	proteges.clear()
	nes.clear()
	souscriptions.clear()
	regles_abords = true
	last_day = -1
	jour = {"entretien": 0.0, "subvention": 0.0, "dons": 0.0, "journees": false}
	annee = {"entretien": 0.0, "subvention": 0.0, "dons": 0.0, "aides": 0.0}


func now() -> float:
	return ambiance.unix_time if ambiance != null else 0.0


func offset_h() -> float:
	return ambiance.utc_offset() if ambiance != null else 0.0


## Année de l'histoire en cours (Epoques, ou l'année du calendrier du jeu).
static func annee_courante() -> int:
	return Epoques.annee()


func _on_added(bid: int) -> void:
	if not nes.has(bid):
		nes[bid] = annee_courante()


func _on_removed(bid: int) -> void:
	nes.erase(bid)
	proteges.erase(bid)
	souscriptions.erase(bid)


# --- Intérêt et classement --------------------------------------------------------------

func type_of(bid: int) -> String:
	if buildings == null or not buildings.buildings.has(bid):
		return ""
	return String(buildings.buildings[bid].t)


func nom(bid: int) -> String:
	return String(BuildingCatalog.get_type(type_of(bid)).get("name", "Bâtiment"))


func pos_of(bid: int) -> Vector3:
	if buildings == null or not buildings.buildings.has(bid):
		return Vector3.ZERO
	var b: Dictionary = buildings.buildings[bid]
	return BuildingSystem.rect_center(buildings._rect_of(b)) + Vector3(0, float(b.get("h", 0.0)), 0)


func age(bid: int) -> int:
	return maxi(0, annee_courante() - int(nes.get(bid, annee_courante())))


func niveau(bid: int) -> int:
	return int(proteges.get(bid, {}).get("niv", 0))


static func est_grand_monument(type_id: String) -> bool:
	return MonumentsTypes.est_monument(type_id)


## Le bâtiment est-il un monument ou un édifice remarquable par sa fonction ?
static func remarquable(type_id: String) -> bool:
	var t := BuildingCatalog.get_type(type_id)
	if t.is_empty():
		return false
	if t.get("monument", false):
		return true
	var role := String(t.get("role", ""))
	var arch := String(t.get("arch", ""))
	if role in ROLES_REMARQUABLES or arch in ["culte", "palais", "theatre"]:
		return true
	var hay := (type_id + " " + String(t.get("name", ""))).to_lower()
	for m in MOTS_REMARQUABLES:
		if hay.contains(m) and not hay.contains("tour_habitation") and not hay.contains("tour de bureaux"):
			return String(t.get("cat", "")) in ["services", "loisirs", "espaces", "production", "tourisme", "patrimoine"]
	return false


## Intérêt patrimonial : {"pts": float, "raisons": [textes]}.
func interet(bid: int) -> Dictionary:
	var id := type_of(bid)
	var out := {"pts": 0.0, "raisons": []}
	var t := BuildingCatalog.get_type(id)
	if t.is_empty() or t.has("blocks") or t.get("campement", false):
		return out
	if est_grand_monument(id):
		out.pts = 3.0
		out.raisons.append("grand monument")
		return out
	var a := age(bid)
	var vieux := clampf(float(a) / 30.0, 0.0, 1.0)
	var pts := 0.0
	if remarquable(id):
		pts += 1.2
		out.raisons.append("édifice remarquable")
	var era := String(t.get("era", "moderne"))
	var style := 0.0
	if t.get("epoque_bat", false):
		style = 0.5
	elif era in ["antique", "traditionnel"]:
		style = 0.6
	elif era == "classique":
		style = 0.4
	if style > 0.0:
		pts += style * (0.5 + 0.5 * vieux)
		out.raisons.append("architecture d'autrefois")
	if a >= 10:
		pts += minf(2.0, float(a) / 50.0)
		out.raisons.append("%d ans" % a)
	out.pts = pts
	return out


## Niveau de protection le plus haut possible pour ce bâtiment (0, 1 ou 2).
func niveau_possible(bid: int) -> int:
	var p := float(interet(bid).pts)
	if p >= SEUILS[CLASSE]:
		return CLASSE
	if p >= SEUILS[INSCRIT]:
		return INSCRIT
	return 0


## Raison qui empêche de protéger à ce niveau ("" : possible).
func refus_proteger(bid: int, niv: int) -> String:
	if buildings == null or not buildings.buildings.has(bid):
		return "Bâtiment introuvable."
	if buildings.en_chantier(bid):
		return "Attends la fin de son chantier."
	if niveau(bid) >= niv:
		return "Déjà %s." % NIVEAUX_COURTS[niveau(bid)].to_lower()
	if niveau_possible(bid) < niv:
		var p := float(interet(bid).pts)
		return "Pas assez d'intérêt patrimonial (%.1f sur %.1f) : un édifice remarquable, une architecture d'autrefois ou des années d'histoire." % [p, SEUILS[niv]]
	var frais := int(FRAIS[niv])
	if frais > 0 and not buildings.unlimited_money:
		var prev := Pays.au_batiment(bid)
		var assez := buildings.money >= frais
		Pays.retour(prev)
		if not assez:
			return "Pas assez d'argent pour le dossier (%s)." % BuildingSystem.format_money(frais)
	return ""


## Inscrit (niv 1) ou classe (niv 2) un bâtiment. Renvoie true si c'est fait.
func proteger(bid: int, niv: int, gratuit := false) -> bool:
	var why := "" if gratuit else refus_proteger(bid, niv)
	if why != "":
		message.emit(why)
		return false
	if not gratuit:
		_flux(bid, "Patrimoine : dossiers de classement", -float(FRAIS[niv]))
	var e: Dictionary = proteges.get(bid, {"entretien": true})
	e["niv"] = niv
	e["an"] = annee_courante()
	proteges[bid] = e
	var txt := ("Nouveau monument historique classé : %s." if niv == CLASSE else "Nouveau bâtiment inscrit au patrimoine : %s.") % nom(bid)
	if niv == CLASSE:
		txt += " Les cars de touristes ont déjà réservé."
	message.emit(txt)
	actualite.emit(txt, pos_of(bid))
	changed.emit()
	return true


func declasser(bid: int) -> void:
	if not proteges.has(bid):
		return
	proteges.erase(bid)
	var txt := "Fin de la protection pour %s. Une pétition « Touche pas à mon vieux mur » circule déjà." % nom(bid)
	message.emit(txt)
	actualite.emit(txt, pos_of(bid))
	changed.emit()


func set_entretien(bid: int, on: bool) -> void:
	if proteges.has(bid):
		proteges[bid]["entretien"] = on
		changed.emit()


func entretenu(bid: int) -> bool:
	return bool(proteges.get(bid, {}).get("entretien", true))


## Valeur prise pour l'entretien et la restauration.
func valeur(bid: int) -> float:
	return float(BuildingCatalog.cost(type_of(bid)))


## Entretien annuel brut et net (après la part de l'État).
func entretien_annuel(bid: int) -> Array:
	var n := niveau(bid)
	if n <= 0 or not entretenu(bid):
		return [0.0, 0.0]
	var brut := valeur(bid) * float(ENTRETIEN[n])
	return [brut, brut * (1.0 - float(SUBVENTION[n]))]


## État du bâtiment (1 = parfait, 0 = ruine), d'après l'usure de BatimentsVie.
func etat(bid: int) -> float:
	if vie == null or not vie._etat.has(bid):
		return 1.0
	return 1.0 - clampf(float(vie._etat[bid].get("usure", 0)) / 5.0, 0.0, 1.0)


## Rythme d'usure d'un bâtiment (BatimentsVie.extra_usure).
func usure_rythme(bid: int) -> float:
	var n := niveau(bid)
	if n <= 0:
		return 1.0
	return USURE_ENTRETENU if entretenu(bid) else USURE_ABANDON


# --- Protection : démolition, agrandissement, abords --------------------------------------

func raison_demolir(bid: int) -> String:
	var n := niveau(bid)
	if n <= 0:
		return ""
	return "%s : %s, on ne démolit pas un monument protégé. Déclasse-le d'abord (touche Fin → Classement)." % [nom(bid), NIVEAUX[n].to_lower()]


func raison_agrandir(bid: int) -> String:
	var n := niveau(bid)
	if n <= 0:
		return ""
	return "Monument %s : on le restaure, on ne l'agrandit pas." % NIVEAUX_COURTS[n].to_lower()


func hauteur_type(id: String) -> float:
	if not _hauteurs.has(id):
		_hauteurs[id] = BuildingCatalog.approx_height(id)
	return float(_hauteurs[id])


## Monument protégé dont les abords touchent ce rectangle : [bid, niveau, distance], ou [].
func abords_de(rect: Rect2i) -> Array:
	var best: Array = []
	var c := Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y + rect.size.y * 0.5)
	for bid in proteges:
		if not buildings.buildings.has(bid):
			continue
		var n := int(proteges[bid].niv)
		var r := buildings._rect_of(buildings.buildings[bid])
		var cc := Vector2(r.position.x + r.size.x * 0.5, r.position.y + r.size.y * 0.5)
		var dist := maxf(0.0, c.distance_to(cc) - (r.size.length() + rect.size.length()) * 0.25)
		if dist <= float(ABORDS[n]) and (best.is_empty() or n > int(best[1])):
			best = [int(bid), n, dist]
	return best


## Règle de pose (BuildingSystem.extra_check) : {"reason", "info"}.
func check_place(id: String, rect: Rect2i) -> Dictionary:
	if not regles_abords or proteges.is_empty():
		return {}
	var ab := abords_de(rect)
	if ab.is_empty():
		return {}
	var n := int(ab[1])
	var t := BuildingCatalog.get_type(id)
	var qui := "%s (%s)" % [nom(int(ab[0])), NIVEAUX_COURTS[n].to_lower()]
	if String(t.get("cat", "")) in CATS_INTERDITES:
		return {"reason": "Aux abords de %s : pas d'usine ni d'installation de déchets à moins de %d m." % [qui, int(ABORDS[n])]}
	var h := hauteur_type(id)
	if h > float(HAUTEUR_ABORDS[n]) and not est_grand_monument(id):
		return {"reason": "Aux abords de %s : %d m de haut au plus (celui-ci en fait %d)." % [qui, int(HAUTEUR_ABORDS[n]), roundi(h)]}
	return {"info": "Abords de %s : %d m de haut au plus." % [qui, int(HAUTEUR_ABORDS[n])]}


# --- Grands chantiers ---------------------------------------------------------------------

## Grands monuments posés : [bid] (en chantier ou finis).
func grands_monuments() -> Array:
	var out: Array = []
	if buildings == null:
		return out
	for bid in buildings.buildings:
		if est_grand_monument(String(buildings.buildings[bid].t)):
			out.append(int(bid))
	return out


func en_chantier(bid: int) -> bool:
	return buildings != null and buildings.en_chantier(bid)


func avancement(bid: int) -> float:
	if buildings == null or not buildings.buildings.has(bid):
		return 0.0
	return clampf(float(buildings.buildings[bid].get("av", 1.0)), 0.0, 1.0)


## Étape du chantier d'un monument : [indice, clé, nom, avancement de l'étape].
func etape(bid: int) -> Array:
	return Chantiers.etape(MonumentsTypes.etapes(type_of(bid)), avancement(bid))


## Reste à payer par la ville.
func reste_du(bid: int) -> int:
	if buildings == null or not buildings.buildings.has(bid):
		return 0
	return int(buildings.buildings[bid].get("du", 0))


func lancer_souscription(bid: int) -> bool:
	if not en_chantier(bid) or not est_grand_monument(type_of(bid)):
		message.emit("Une souscription se lance pour le chantier d'un grand monument.")
		return false
	var s: Dictionary = souscriptions.get(bid, {"recu": 0, "dons": 0, "mecenes": 0})
	s["actif"] = true
	souscriptions[bid] = s
	var txt := "Souscription populaire lancée pour %s : chaque habitant peut donner (au plus %d %% du chantier)." % [nom(bid), roundi(PLAFOND_SOUSCRIPTION * 100.0)]
	message.emit(txt)
	actualite.emit(txt, pos_of(bid))
	changed.emit()
	return true


func souscription(bid: int) -> Dictionary:
	return souscriptions.get(bid, {})


## Dons d'un jour pour un chantier (habitants × don moyen × satisfaction).
func dons_du_jour(bid: int) -> float:
	var s: Dictionary = souscriptions.get(bid, {})
	if not s.get("actif", false) or not en_chantier(bid):
		return 0.0
	var hab := float(population.persons.size()) if population != null else 0.0
	# Une ville contente donne plus (sondage des avis, 0 à 100).
	var sat := 0.6
	if Avis.instance != null and is_instance_valid(Avis.instance) and Avis.instance.moyenne() >= 0:
		sat = float(Avis.instance.moyenne()) / 100.0
	var plafond := float(BuildingCatalog.cost(type_of(bid))) * PLAFOND_SOUSCRIPTION - float(s.get("recu", 0))
	var prestige := float(MonumentsTypes.spec(type_of(bid)).get("prestige", 3.0))
	var d := hab * DON_HABITANT * (0.5 + sat) * (0.6 + prestige / 10.0)
	return clampf(d, 0.0, maxf(0.0, minf(plafond, float(reste_du(bid)))))


func _verser_dons(bid: int, montant: float) -> void:
	if montant <= 0.0 or buildings == null or not buildings.buildings.has(bid):
		return
	var b: Dictionary = buildings.buildings[bid]
	var m := mini(int(montant), int(b.get("du", 0)))
	if m <= 0:
		return
	b["du"] = int(b.du) - m
	var s: Dictionary = souscriptions.get(bid, {"actif": false, "recu": 0, "dons": 0, "mecenes": 0})
	s["recu"] = int(s.get("recu", 0)) + m
	souscriptions[bid] = s
	jour.dons = float(jour.dons) + m
	annee.dons = float(annee.dons) + m
	BudgetCommunal.noter("Patrimoine : dons et mécénat (payés au chantier)", float(m))


# --- Tourisme -----------------------------------------------------------------------------

## Le week-end des Journées du patrimoine (troisième samedi et dimanche de septembre) ?
static func journees_du_patrimoine(unix: float, offset_h := 0.0) -> bool:
	var d := Time.get_datetime_dict_from_unix_time(int(unix + offset_h * 3600.0))
	if int(d.month) != 9:
		return false
	var wd := int(d.weekday) # 0 = dimanche, 6 = samedi
	var md := int(d.day)
	if wd == 6:
		return md >= 15 and md <= 21
	if wd == 0:
		return md >= 16 and md <= 22
	return false


func journees() -> bool:
	return journees_du_patrimoine(now(), offset_h())


## Points d'attrait d'un bâtiment comme site « patrimoine » (0 : pas un site).
func points_site(bid: int) -> float:
	var id := type_of(bid)
	if id == "":
		return 0.0
	var n := niveau(bid)
	var pts := 0.0
	if est_grand_monument(id):
		var pr := float(MonumentsTypes.spec(id).get("prestige", 3.0))
		if en_chantier(bid):
			# Les curieux viennent voir le chantier : de plus en plus à mesure qu'il monte.
			return pr * 0.25 * (0.2 + 0.8 * avancement(bid))
		pts = pr
		n = maxi(n, CLASSE)
	else:
		if buildings.en_chantier(bid):
			return 0.0
		pts = points_base(id)
		if pts <= 0.0 and n > 0:
			pts = 0.12 * float(interet(bid).pts)
		if pts <= 0.0:
			return 0.0
	pts *= float(BONUS[n]) * (0.55 + 0.45 * etat(bid))
	if journees():
		pts *= JOURNEES
	return pts


## Points de base des monuments, châteaux, cathédrales et temples de la bible.
static func points_base(id: String) -> float:
	var t := BuildingCatalog.get_type(id)
	var role := String(t.get("role", ""))
	var arch := String(t.get("arch", ""))
	if role in ["monument", "culte"] or arch in ["culte", "palais"] or id == "phare":
		return clampf(float(BuildingCatalog.cost(id)) / 8_000_000.0, 0.15, 2.5) * (1.0 if role == "monument" else 0.6)
	return 0.0


## Note donnée par les visiteurs (0 à 5).
func note_site(bid: int) -> float:
	var n := niveau(bid)
	if est_grand_monument(type_of(bid)):
		n = CLASSE if not en_chantier(bid) else 0
	return clampf(3.0 + 0.5 * n + 1.0 * (etat(bid) - 0.5), 1.0, 5.0)


## Rayonnement de la ville : la somme des points de ses sites patrimoniaux.
func rayonnement() -> float:
	var s := 0.0
	if buildings == null:
		return s
	for bid in buildings.buildings:
		s += points_site(int(bid))
	return s


## Bâtiments qu'on pourrait protéger (ou déjà protégés), du plus intéressant au moins.
func candidats(n_max := 40) -> Array:
	var out: Array = []
	if buildings == null:
		return out
	for bid in buildings.buildings:
		var i := interet(int(bid))
		if float(i.pts) >= SEUILS[INSCRIT] or proteges.has(int(bid)):
			out.append({"bid": int(bid), "pts": float(i.pts), "raisons": i.raisons})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pa := 1 if proteges.has(int(a.bid)) else 0
		var pb := 1 if proteges.has(int(b.bid)) else 0
		if pa != pb:
			return pa > pb
		return float(a.pts) > float(b.pts))
	return out.slice(0, n_max)


## Aide de l'État à la restauration d'un monument protégé (part du prix de la rénovation).
func aide_restauration(bid: int) -> float:
	return float(AIDE_RESTAURATION[niveau(bid)])


## Restaure un monument protégé (chantier de rénovation d'Ameliorations, aidé par l'État).
func restaurer(bid: int) -> bool:
	var am := Ameliorations.instance
	if am == null:
		return false
	var prix := am.cout(bid, 0)
	if not am.renover(bid):
		return false
	var aide := float(prix) * aide_restauration(bid)
	if aide > 0.0:
		_flux(bid, "Patrimoine : aide de l'État à la restauration", aide)
		annee.aides = float(annee.aides) + aide
		message.emit("L'État paie %s de la restauration de %s." % [BuildingSystem.format_money(int(aide)), nom(bid)])
	return true


# --- Journée --------------------------------------------------------------------------------

func _process(_delta: float) -> void:
	if ambiance == null or buildings == null:
		return
	var d := int(floorf((now() + offset_h() * 3600.0) / 86400.0))
	if last_day < 0:
		last_day = d
		return
	if d != last_day:
		last_day = d
		nouveau_jour()


func nouveau_jour() -> void:
	jour = {"entretien": 0.0, "subvention": 0.0, "dons": 0.0, "journees": journees()}
	var dt := Time.get_datetime_dict_from_unix_time(int(now() + offset_h() * 3600.0))
	if int(dt.month) == 1 and int(dt.day) == 1:
		annee = {"entretien": 0.0, "subvention": 0.0, "dons": 0.0, "aides": 0.0}
	# Entretien des monuments protégés (la part de l'État revient à la caisse).
	for bid in proteges.keys():
		if not buildings.buildings.has(bid):
			proteges.erase(bid)
			continue
		var e := entretien_annuel(int(bid))
		if float(e[0]) <= 0.0:
			continue
		var brut := float(e[0]) / 365.0
		var net := float(e[1]) / 365.0
		_flux(int(bid), "Patrimoine : entretien des monuments", -brut)
		_flux(int(bid), "Patrimoine : subvention de l'État", brut - net)
		jour.entretien = float(jour.entretien) + brut
		jour.subvention = float(jour.subvention) + brut - net
		annee.entretien = float(annee.entretien) + brut
		annee.subvention = float(annee.subvention) + brut - net
	# Grands chantiers : souscription et mécènes.
	for bid in grands_monuments():
		if not en_chantier(int(bid)):
			continue
		_verser_dons(int(bid), dons_du_jour(int(bid)))
		if souscriptions.has(bid) and bool(souscriptions[bid].get("actif", false)):
			souscriptions[bid]["dons"] = int(souscriptions[bid].get("dons", 0)) + maxi(1, roundi(dons_du_jour(int(bid)) / 20.0))
		# Un mécène de temps en temps (plus souvent pour un chantier prestigieux).
		var pr := float(MonumentsTypes.spec(type_of(int(bid))).get("prestige", 3.0))
		if _rng.randf() < 0.004 * pr:
			var don := float(BuildingCatalog.cost(type_of(int(bid)))) * _rng.randf_range(0.01, 0.04)
			_verser_dons(int(bid), don)
			var s: Dictionary = souscriptions.get(bid, {"actif": false, "recu": 0, "dons": 0, "mecenes": 0})
			s["mecenes"] = int(s.get("mecenes", 0)) + 1
			souscriptions[bid] = s
			var txt: String = ["Un banquier discret offre %s au chantier de %s, à condition qu'on grave son nom quelque part (en petit).",
				"Une association d'anciens élèves donne %s pour %s. Ils veulent une plaque.",
				"Une riche héritière lègue %s au chantier de %s. Son chat garde la maison."][_rng.randi() % 3] % [
				BuildingSystem.format_money(int(don)), nom(int(bid))]
			message.emit(txt)
			actualite.emit(txt, pos_of(int(bid)))
	# Grand monument fini : classé d'office à l'inauguration.
	for bid in grands_monuments():
		if not en_chantier(int(bid)) and niveau(int(bid)) < CLASSE:
			inaugurer(int(bid))
	if bool(jour.journees) and int(dt.weekday) == 6:
		var n := proteges.size()
		if n > 0:
			var txt := "Journées du patrimoine : %d monuments ouverts gratuitement ce week-end. Les guides ont révisé leurs blagues." % n
			message.emit(txt)
			actualite.emit(txt, Vector3.INF)
	changed.emit()


## Inauguration d'un grand monument : classé d'office, la presse en parle.
func inaugurer(bid: int) -> void:
	if niveau(bid) >= CLASSE:
		return
	var e: Dictionary = proteges.get(bid, {"entretien": true})
	e["niv"] = CLASSE
	e["an"] = annee_courante()
	proteges[bid] = e
	var s: Dictionary = souscriptions.get(bid, {})
	if not s.is_empty():
		s["actif"] = false
	var txt := "Inauguration : %s ! Le maire a coupé le ruban (au troisième essai). Classé monument historique d'office." % nom(bid)
	if int(s.get("recu", 0)) > 0:
		txt += " Les donateurs ont payé %s." % BuildingSystem.format_money(int(s.recu))
	message.emit(txt)
	actualite.emit(txt, pos_of(bid))
	changed.emit()


# --- Conseils -----------------------------------------------------------------------------

func conseils() -> Array:
	var out: Array = []
	var cands := candidats(60)
	var libres := 0
	for c in cands:
		if not proteges.has(int(c.bid)):
			libres += 1
	if libres > 0:
		out.append("%d bâtiment%s pourrai%s être protégé%s : onglet Classement." % [libres, "s" if libres > 1 else "", "ent" if libres > 1 else "t", "s" if libres > 1 else ""])
	for bid in proteges:
		if buildings.buildings.has(bid) and not entretenu(int(bid)):
			out.append("Plus d'entretien pour %s : le monument s'abîme et attire moins." % nom(int(bid)))
			break
	for bid in proteges:
		if buildings.buildings.has(bid) and etat(int(bid)) < 0.5:
			out.append("%s a besoin d'une restauration (l'État en paie une part)." % nom(int(bid)))
			break
	for bid in grands_monuments():
		if en_chantier(int(bid)) and not bool(souscriptions.get(bid, {}).get("actif", false)):
			out.append("Lance une souscription pour %s : les habitants paieront une part du chantier." % nom(int(bid)))
			break
	if grands_monuments().is_empty():
		out.append("Aucun grand monument : une cathédrale, un opéra ou une tour feraient venir les touristes du monde entier (onglet Bâtir).")
	return out


# --- Argent -------------------------------------------------------------------------------

func _flux(bid: int, poste: String, montant: float) -> void:
	if buildings == null or buildings.unlimited_money or absf(montant) < 0.01:
		return
	var prev := Pays.au_batiment(bid) if bid >= 0 else -1
	var bc := BudgetCommunal.instance
	if bc != null and is_instance_valid(bc) and bc.is_inside_tree():
		if montant > 0.0:
			bc.recette(poste, montant)
		else:
			bc.depense(poste, -montant)
	else:
		var f := _frac + montant
		var whole := int(f)
		_frac = f - whole
		if whole != 0:
			buildings.money += whole
	Pays.retour(prev)


# --- Sauvegarde ---------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var p := {}
	for bid in proteges:
		p[str(bid)] = proteges[bid].duplicate()
	var n := {}
	for bid in nes:
		n[str(bid)] = int(nes[bid])
	var s := {}
	for bid in souscriptions:
		s[str(bid)] = souscriptions[bid].duplicate()
	return {"proteges": p, "nes": n, "souscriptions": s, "regles_abords": regles_abords, "annee": annee.duplicate(), "last_day": last_day}


func from_dict(d: Dictionary) -> void:
	proteges.clear()
	souscriptions.clear()
	var n: Dictionary = d.get("nes", {})
	for k in n:
		nes[int(k)] = int(n[k])
	var p: Dictionary = d.get("proteges", {})
	for k in p:
		var e: Dictionary = p[k]
		proteges[int(k)] = {"niv": int(e.get("niv", 1)), "an": int(e.get("an", annee_courante())), "entretien": bool(e.get("entretien", true))}
	var s: Dictionary = d.get("souscriptions", {})
	for k in s:
		var e: Dictionary = s[k]
		souscriptions[int(k)] = {"actif": bool(e.get("actif", false)), "recu": int(e.get("recu", 0)), "dons": int(e.get("dons", 0)), "mecenes": int(e.get("mecenes", 0))}
	regles_abords = bool(d.get("regles_abords", true))
	var a: Dictionary = d.get("annee", {})
	for k in annee:
		annee[k] = float(a.get(k, 0.0))
	last_day = int(d.get("last_day", -1))
	changed.emit()
