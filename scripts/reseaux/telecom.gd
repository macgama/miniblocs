class_name Telecom
extends Node3D
## Internet et téléphone : antennes relais (2G, 4G, 5G), centraux téléphoniques,
## cuivre (téléphone fixe et ADSL) et fibre optique.
##
## - Cuivre : chaque route porte le cuivre (comme en vrai, la ligne suit la
##   rue) ; un bâtiment à moins de RAYON m d'une route reliée à un central a le
##   téléphone fixe et l'ADSL, dont le débit baisse avec la distance au central
##   (ADSL_PALIERS). Des lignes sur poteaux portent le cuivre hors des routes.
## - Fibre : câbles posés par le joueur (sous la rue, ou sur poteaux à la
##   campagne), alimentés par un central ou un nœud optique qui les touche.
##   1 Gb/s, partagé si les lignes demandées dépassent celles des sources.
## - Mobile : chaque antenne couvre un disque (portée réelle de sa génération).
##   Un bâtiment prend la meilleure génération qui le couvre ; les abonnés se
##   partagent la capacité de l'émetteur (saturation = débit qui baisse).
## - Conséquences (réglage Admin « telecom_necessaire ») : satisfaction des
##   habitants (fil Avis, ou Population.extra_satisfaction sinon), rendement
##   des entreprises (Production, groupe « rendement_sources »), entretien et
##   abonnements (Budget, groupes « budget_entretien » / « budget_recettes »).
## La mécanique de réseau est ReseauBase (partagée avec l'électricité et l'eau).

signal changed
signal message(text: String)
signal info_changed(text: String)
## Un outil de pose vient d'être pris (la scène range les autres outils).
signal outil_active

## Distance de raccordement d'un bâtiment (de sa porte au câble ou à la route), m.
const RAYON := 35.0
## Débit ADSL (Mb/s) selon la distance au central (m) : la ligne s'affaiblit.
const ADSL_PALIERS := [[1000.0, 20.0], [2000.0, 12.0], [3000.0, 6.0], [4000.0, 3.0], [5000.0, 1.0]]
## Au-delà : téléphone seulement (0,05 Mb/s, l'internet bas débit d'autrefois).
const ADSL_LOIN := 0.05
const FIBRE_DEBIT := 1000.0
## Part du débit mobile utilisable comme accès à la maison (box 4G / 5G).
const PART_BOX := 0.6
## Internet « lent » en dessous de ce débit (Mb/s).
const LENT := 8.0

## Câbles posés par le joueur : réseau, nom, prix (€/m), entretien (€/m/mois), sur poteaux.
const CABLES := {
	"fibre": {"reseau": "fibre", "name": "Fibre sous la rue", "cout": 60.0, "entretien": 0.02, "aerien": false},
	"fibre_aerienne": {"reseau": "fibre", "name": "Fibre sur poteaux", "cout": 18.0, "entretien": 0.04, "aerien": true},
	"cuivre_aerien": {"reseau": "cuivre", "name": "Ligne téléphonique sur poteaux", "cout": 12.0, "entretien": 0.03, "aerien": true},
}
## Entretien des équipements (€ par mois).
const ENTRETIEN := {"pylone_2g": 900, "pylone_4g": 1600, "pylone_5g": 2400, "antenne_5g": 700,
	"central_telephonique": 4500, "noeud_fibre": 500}
## Entretien du cuivre porté par les routes (€ par km et par mois).
const ENTRETIEN_CUIVRE_KM := 25.0
## Part des abonnements qui revient à la ville (€ par mois) : ligne fixe, mobile.
const RECETTE_LIGNE := 3.0
const RECETTE_MOBILE := 1.0
## Écart entre deux poteaux (m) et leur hauteur.
const POTEAU_PAS := 35.0
const POTEAU_H := 7.5
const COULEUR_FIBRE := Color("ff7bd5")
const COULEUR_CUIVRE := Color("e09f3e")
## Couleurs du calque « débit » : fibre, ADSL rapide, lent, mobile seul, rien.
const COULEURS_NET := {"fibre": Color("2dd4bf"), "adsl": Color("80ed99"), "lent": Color("ffd166"),
	"mobile": Color("f4a261"), "rien": Color("ef476f")}

enum Outil { AUCUN, FIBRE_RUE, FIBRE, FIBRE_AERIENNE, CUIVRE_AERIEN, RETIRER }
const OUTIL_CABLE := {Outil.FIBRE: "fibre", Outil.FIBRE_AERIENNE: "fibre_aerienne", Outil.CUIVRE_AERIEN: "cuivre_aerien"}

var world: TerrainWorld
var buildings: BuildingSystem
var transport: TransportSystem
var population: Population

var fibre := ReseauBase.new("fibre")
var cuivre := ReseauBase.new("cuivre")
## Antennes : bid -> {t, p: Vector3, em: Array (émetteurs de TelecomTypes)}.
var antennes: Dictionary = {}
## Centraux et nœuds optiques : bid -> {t, p}.
var centraux: Dictionary = {}
## Service de chaque bâtiment qui en a besoin : bid -> {fixe, net, via, fibre,
## adsl, gen, mob, taux_mob, lignes, abonnes}.
var service: Dictionary = {}
## Charge des émetteurs : "bid:i" -> {abonnes, cap}.
var charge: Dictionary = {}
## Outil en cours.
var outil: Outil = Outil.AUCUN
## Calque affiché : "" (aucun), "mobile" (couverture), "debit" (internet des bâtiments).
var calque := ""

var _dirty := true
var _timer := 0.0
var _trace: PackedVector3Array = PackedVector3Array()
var _survol := Vector3.ZERO
var _survol_ok := false
var _poteaux: MeshInstance3D
var _calque_mesh: MeshInstance3D
var _trace_mesh: MeshInstance3D
var _calque_dirty := true
var _prev_satisfaction: Callable


func _init() -> void:
	fibre.suit_routes = false
	fibre.rayon_raccord = RAYON
	cuivre.suit_routes = true
	cuivre.rayon_raccord = RAYON


func setup(w: TerrainWorld, b: BuildingSystem, t: TransportSystem, p: Population) -> void:
	world = w
	buildings = b
	transport = t
	population = p
	if buildings != null:
		buildings.changed.connect(marquer)
	if transport != null:
		transport.network_changed.connect(marquer)
	if population != null:
		# Sans le fil « Avis » (qui lit le groupe avis_sources), on s'ajoute à la
		# satisfaction de Population, en gardant ce qui y était déjà branché.
		_prev_satisfaction = population.extra_satisfaction
		population.extra_satisfaction = _satisfaction_chainee
	marquer()


func _ready() -> void:
	add_to_group("avis_sources")
	add_to_group("rendement_sources")
	add_to_group("budget_entretien")
	add_to_group("budget_recettes")
	# Panneau Cartes (N) : les deux calques y sont aussi.
	Calques.ajouter("telecom_mobile", "Couverture mobile", "Internet et téléphone",
		func(on: bool) -> void: set_calque("mobile" if on else ("" if calque == "mobile" else calque)),
		"2G jaune, 4G bleu, 5G violet ; fibre en rose")
	Calques.ajouter("telecom_debit", "Débit internet", "Internet et téléphone",
		func(on: bool) -> void: set_calque("debit" if on else ("" if calque == "debit" else calque)),
		"turquoise fibre, vert ADSL, orange box 4G / 5G, jaune lent, rouge rien")
	_poteaux = _mesh_instance(false)
	_calque_mesh = _mesh_instance(true)
	_trace_mesh = _mesh_instance(true)


func _mesh_instance(overlay: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	if overlay:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.disable_fog = true
		m.render_priority = 1
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	else:
		m.roughness = 0.9
	mi.material_override = m
	add_child(mi)
	return mi


func clear() -> void:
	fibre.clear()
	cuivre.clear()
	antennes.clear()
	centraux.clear()
	service.clear()
	charge.clear()
	_trace.clear()
	marquer()


func marquer() -> void:
	_dirty = true
	_calque_dirty = true


func _process(delta: float) -> void:
	_timer -= delta
	if _dirty and _timer <= 0.0:
		_timer = 0.5
		recalculer()
	if _calque_dirty and calque != "":
		_dessiner_calque()


## Réglage Admin : internet et téléphone comptent-ils (satisfaction, entreprises) ?
static func necessaire() -> bool:
	return ReglagesPartie.actuel.telecom_necessaire


# --- Bâtiments --------------------------------------------------------------------

## Lignes fixes demandées par un type de bâtiment : une par logement, une pour
## dix emplois ; 0 = il n'a pas besoin du réseau (parc, terrain de sport…).
static func lignes_of(type_id: String) -> int:
	var t := BuildingCatalog.get_type(type_id)
	if t.has("telecom"):
		return 0
	var lg := int(t.get("logements", 0))
	var em := int(t.get("emplois", 0))
	if lg == 0 and em == 0:
		return 0
	return lg + ceili(em / 10.0)


## Abonnés mobiles d'un type : deux par logement, un par emploi.
static func abonnes_of(type_id: String) -> int:
	var t := BuildingCatalog.get_type(type_id)
	if t.has("telecom"):
		return 0
	return int(t.get("logements", 0)) * 2 + int(t.get("emplois", 0))


func _pos_of(b: Dictionary) -> Vector3:
	var rect := buildings._rect_of(b)
	return BuildingSystem.door_point(String(b.t), rect, int(b.r), float(b.get("a", 0.0)))


func _sync_batiments() -> void:
	antennes.clear()
	centraux.clear()
	fibre.sources.clear()
	fibre.consos.clear()
	cuivre.sources.clear()
	cuivre.consos.clear()
	if buildings == null:
		return
	for bid in buildings.buildings:
		var b: Dictionary = buildings.buildings[bid]
		var t := String(b.t)
		if buildings.en_chantier(bid):
			continue
		var spec := TelecomTypes.spec_of(t)
		var p := _pos_of(b)
		if not spec.is_empty():
			var c := Vector3(buildings._center_of(b).x + 0.5, p.y, buildings._center_of(b).y + 0.5)
			match String(spec.kind):
				"antenne":
					antennes[bid] = {"t": t, "p": c, "em": spec.em}
				"central":
					centraux[bid] = {"t": t, "p": p}
					fibre.ajouter_source(bid, p, float(spec.lignes))
					cuivre.ajouter_source(bid, p, float(spec.cuivre))
				"noeud_fibre":
					centraux[bid] = {"t": t, "p": p}
					fibre.ajouter_source(bid, p, float(spec.lignes))
			continue
		var n := lignes_of(t)
		if n > 0:
			fibre.ajouter_conso(bid, p, n)
			cuivre.ajouter_conso(bid, p, n)


## Tracés des routes (ils portent le cuivre).
func routes() -> Array:
	var out := []
	if transport == null:
		return out
	for eid in transport.network.edges:
		var e: Dictionary = transport.network.edges[eid]
		if TransportTypes.mode_of(String(e.t)) == TransportTypes.Mode.ROAD:
			out.append(e.pts)
	return out


# --- Calcul -----------------------------------------------------------------------

func recalculer() -> void:
	_dirty = false
	_sync_batiments()
	var rts := routes()
	fibre.recalculer()
	cuivre.recalculer(rts)
	service.clear()
	charge.clear()
	# Central le plus proche de chaque composante de cuivre (pour l'ADSL).
	var centres := {}
	for bid in cuivre.sources:
		var c := cuivre.composante_de(bid)
		if c >= 0:
			if not centres.has(c):
				centres[c] = []
			centres[c].append(cuivre.sources[bid].p)
	# Mobile : chaque bâtiment choisit le meilleur émetteur qui le couvre.
	var choix := {}
	for bid in fibre.consos:
		var p: Vector3 = fibre.consos[bid].p
		var t := String(buildings.buildings[bid].t)
		var s := {"lignes": int(fibre.consos[bid].d), "abonnes": abonnes_of(t), "fibre": 0.0, "adsl": 0.0,
			"fixe": false, "gen": "", "mob": 0.0, "taux_mob": 0.0, "net": 0.0, "via": ""}
		if fibre.est_raccorde(bid):
			s.fibre = FIBRE_DEBIT * fibre.taux_servi(bid)
		if cuivre.est_raccorde(bid) and cuivre.taux_servi(bid) > 0.0:
			s.fixe = true
			var best := INF
			for q in centres.get(cuivre.composante_de(bid), []):
				best = minf(best, Vector2(p.x, p.z).distance_to(Vector2((q as Vector3).x, (q as Vector3).z)))
			s.adsl = debit_adsl(best) * cuivre.taux_servi(bid)
		var em := meilleur_emetteur(p)
		if not em.is_empty():
			choix[bid] = em
			s.gen = String(em.gen)
			var k := String(em.key)
			if not charge.has(k):
				charge[k] = {"abonnes": 0.0, "cap": float(em.cap)}
			charge[k].abonnes += float(s.abonnes)
		service[bid] = s
	for bid in choix:
		var em: Dictionary = choix[bid]
		var ch: Dictionary = charge[String(em.key)]
		var taux: float = 1.0 if float(ch.abonnes) <= float(ch.cap) else float(ch.cap) / float(ch.abonnes)
		var s: Dictionary = service[bid]
		s.taux_mob = taux
		s.mob = float(em.debit) * taux * (1.0 - 0.5 * float(em.d) / float(em.portee))
	for bid in service:
		var s: Dictionary = service[bid]
		if s.fibre > 0.0 and s.fibre >= s.adsl:
			s.net = s.fibre
			s.via = "fibre"
		elif s.adsl > 0.0:
			s.net = s.adsl
			s.via = "adsl"
		if s.gen != "" and s.gen != "2g" and s.mob * PART_BOX > s.net:
			s.net = s.mob * PART_BOX
			s.via = "mobile"
		if s.gen != "":
			s.fixe = true
	_calque_dirty = true
	_dessiner_poteaux()
	changed.emit()


static func debit_adsl(dist: float) -> float:
	for p in ADSL_PALIERS:
		if dist <= float(p[0]):
			return float(p[1])
	return ADSL_LOIN


## Meilleur émetteur qui couvre un point : génération la plus récente, puis le
## plus proche. {} si aucun. Rend {key, gen, d, portee, cap, debit, bid}.
func meilleur_emetteur(p: Vector3) -> Dictionary:
	var best := {}
	for bid in antennes:
		var a: Dictionary = antennes[bid]
		var ap: Vector3 = a.p
		var d := Vector2(p.x, p.z).distance_to(Vector2(ap.x, ap.z))
		var i := 0
		for e in a.em:
			if d <= float(e.portee):
				var rang := int(TelecomTypes.GENS[e.gen].rang)
				var brang := -1 if best.is_empty() else int(TelecomTypes.GENS[best.gen].rang)
				if rang > brang or (rang == brang and d < float(best.d)):
					best = {"key": "%d:%d" % [bid, i], "gen": e.gen, "d": d, "portee": e.portee, "cap": e.cap,
						"debit": e.debit, "bid": bid}
			i += 1
	return best


## Qualité d'internet d'un bâtiment : "fibre", "adsl", "lent", "mobile", "rien"
## ("" : il n'en a pas besoin).
func qualite(bid: int) -> String:
	if not service.has(bid):
		return ""
	var s: Dictionary = service[bid]
	if s.via == "fibre":
		return "fibre"
	if s.via == "adsl":
		return "adsl" if s.net >= LENT else "lent"
	if s.via == "mobile":
		return "mobile" if s.net >= LENT else "lent"
	if s.gen != "" or s.fixe:
		return "lent"
	return "rien"


static func format_debit(mbps: float) -> String:
	if mbps >= 1000.0:
		return "%s Gb/s" % String.num(mbps / 1000.0, 1).trim_suffix(".0")
	if mbps >= 1.0:
		return "%d Mb/s" % roundi(mbps)
	return "%d kb/s" % roundi(mbps * 1000.0)


## Une ligne de texte sur le service d'un bâtiment.
func info_of(bid: int) -> String:
	if antennes.has(bid):
		var parts := []
		for e in antennes[bid].em:
			var k := "%d:%d" % [bid, (antennes[bid].em as Array).find(e)]
			var ab := int(charge.get(k, {}).get("abonnes", 0))
			parts.append("%s %s, %d / %d abonnés" % [TelecomTypes.GENS[e.gen].name, _km(float(e.portee)), ab, int(e.cap)])
		return "Antenne : " + " · ".join(parts)
	if centraux.has(bid):
		var f: Dictionary = fibre.composantes.get(fibre.composante_de(bid), {})
		return "%s : %d lignes fibre demandées pour %d" % [BuildingCatalog.get_type(String(centraux[bid].t)).name,
			roundi(float(f.get("dem", 0.0))), roundi(float(f.get("prod", 0.0)))]
	if not service.has(bid):
		return "Pas besoin d'internet ni de téléphone."
	var s: Dictionary = service[bid]
	var out := []
	match String(s.via):
		"fibre": out.append("Fibre %s" % format_debit(s.net))
		"adsl": out.append("ADSL %s" % format_debit(s.net))
		"mobile": out.append("Box %s %s" % [TelecomTypes.GENS[s.gen].name, format_debit(s.net)])
		_: out.append("Pas d'internet")
	if s.gen != "":
		out.append("mobile %s%s" % [TelecomTypes.GENS[s.gen].name, " saturé" if s.taux_mob < 0.6 else ""])
	else:
		out.append("pas de réseau mobile")
	out.append("téléphone fixe" if cuivre.est_raccorde(bid) or s.via == "fibre" else "pas de ligne fixe")
	return " · ".join(out)


static func _km(m: float) -> String:
	return "%s km" % String.num(m / 1000.0, 1).trim_suffix(".0") if m >= 1000.0 else "%d m" % roundi(m)


## Chiffres du réseau pour le panneau.
func bilan() -> Dictionary:
	var out := {"batiments": service.size(), "fibre": 0, "adsl": 0, "lent": 0, "mobile": 0, "rien": 0,
		"couverts": 0, "gen": {"2g": 0, "4g": 0, "5g": 0}, "satures": 0, "antennes": antennes.size(),
		"centraux": centraux.size(), "fibre_m": 0.0, "poteaux_m": 0.0}
	for bid in service:
		var q := qualite(bid)
		out[q] = int(out[q]) + 1
		var g := String(service[bid].gen)
		if g != "":
			out.couverts += 1
			out.gen[g] += 1
	for k in charge:
		if float(charge[k].abonnes) > float(charge[k].cap):
			out.satures += 1
	for r in [fibre, cuivre]:
		for id in (r as ReseauBase).troncons:
			var tr: Dictionary = (r as ReseauBase).troncons[id]
			var l := ReseauBase.longueur(tr.pts)
			if String(tr.t).begins_with("fibre"):
				out.fibre_m += l
			if CABLES.get(String(tr.t), {}).get("aerien", false):
				out.poteaux_m += l
	return out


# --- Conséquences -----------------------------------------------------------------

## Satisfaction d'un habitant (fil Avis : f(p) -> [delta, raisons]).
func avis_facteurs() -> Array:
	return [{"id": "internet", "theme": "reseaux", "f": satisfaction_of}]


func satisfaction_of(p: Dictionary) -> Array:
	if not necessaire() or population == null:
		return [0.0, []]
	var home := population.home_of(p)
	if not service.has(home):
		return [0.0, []]
	var s: Dictionary = service[home]
	var d := 0.0
	var why := []
	match qualite(home):
		"fibre":
			d += 4.0
			why.append("+ fibre optique à la maison")
		"rien":
			d -= 9.0
			why.append("− pas d'internet à la maison")
		"lent":
			d -= 4.0
			why.append("− internet lent (%s)" % format_debit(s.net))
	if s.gen == "":
		d -= 6.0
		why.append("− pas de réseau mobile")
	elif s.taux_mob < 0.6:
		d -= 2.0
		why.append("− réseau mobile saturé")
	return [clampf(d, -15.0, 10.0), why]


func _satisfaction_chainee(p: Dictionary) -> Array:
	var d := 0.0
	var why := []
	if _prev_satisfaction.is_valid():
		var ex: Array = _prev_satisfaction.call(p)
		if ex.size() >= 2:
			d += float(ex[0])
			why.append_array(ex[1])
	# Le fil Avis lit avis_facteurs() : ne pas compter deux fois.
	if not is_inside_tree() or get_tree().root.get_node_or_null("Avis") == null:
		var mine := satisfaction_of(p)
		d += float(mine[0])
		why.append_array(mine[1])
	return [d, why]


## Rendement d'une entreprise (Production, groupe rendement_sources) : 1 = normal.
func rendement(bid: int) -> float:
	if not necessaire() or not service.has(bid):
		return 1.0
	var bureaux := String(BuildingCatalog.get_type(String(buildings.buildings.get(bid, {}).get("t", ""))).get("arch", "")) == "bureaux" \
		or String(buildings.buildings.get(bid, {}).get("t", "")) == "bureaux"
	match qualite(bid):
		"rien":
			return 0.4 if bureaux else 0.8
		"lent":
			return 0.75 if bureaux else 0.92
	return 1.0


## Entretien mensuel (Budget, groupe budget_entretien).
func budget_entretien() -> Dictionary:
	var eq := 0.0
	for bid in antennes:
		eq += float(ENTRETIEN.get(String(antennes[bid].t), 0))
	for bid in centraux:
		eq += float(ENTRETIEN.get(String(centraux[bid].t), 0))
	var cables := 0.0
	for r in [fibre, cuivre]:
		for id in (r as ReseauBase).troncons:
			var tr: Dictionary = (r as ReseauBase).troncons[id]
			cables += ReseauBase.longueur(tr.pts) * float(CABLES.get(String(tr.t), {}).get("entretien", 0.0))
	var km := 0.0
	if not cuivre.sources.is_empty():
		for r in routes():
			km += ReseauBase.longueur(r) / 1000.0
	var out := {}
	if eq > 0.0:
		out["Antennes et centraux téléphoniques"] = roundi(eq)
	if cables + km * ENTRETIEN_CUIVRE_KM > 0.0:
		out["Câbles téléphoniques et fibre"] = roundi(cables + km * ENTRETIEN_CUIVRE_KM)
	return out


## Part des abonnements touchée par la ville (Budget, groupe budget_recettes).
func budget_recettes() -> Dictionary:
	var lignes := 0.0
	var mobiles := 0.0
	for bid in service:
		var s: Dictionary = service[bid]
		if s.via == "fibre" or s.via == "adsl":
			lignes += float(s.lignes)
		if s.gen != "":
			mobiles += float(s.abonnes) * minf(1.0, float(s.taux_mob) + 0.2)
	var v := roundi(lignes * RECETTE_LIGNE + mobiles * RECETTE_MOBILE)
	return {"Abonnements internet et téléphone": v} if v > 0 else {}


# --- Pose des câbles --------------------------------------------------------------

func set_outil(o: Outil) -> void:
	outil = o
	if o != Outil.AUCUN:
		outil_active.emit()
	_trace.clear()
	_dessiner_trace()
	info_changed.emit(aide_outil())


func set_inactive() -> void:
	set_outil(Outil.AUCUN)


func aide_outil() -> String:
	match outil:
		Outil.FIBRE_RUE:
			return "Fibrer une rue : clic sur une route, toute la rue reçoit la fibre (%d €/m)." % roundi(ReglagesPartie.prix(int(CABLES.fibre.cout)))
		Outil.FIBRE, Outil.FIBRE_AERIENNE, Outil.CUIVRE_AERIEN:
			var c: Dictionary = CABLES[OUTIL_CABLE[outil]]
			return "%s : un clic par point, Échap ou clic droit pour finir (%d €/m)." % [c.name, roundi(ReglagesPartie.prix(int(c.cout)))]
		Outil.RETIRER:
			return "Retirer un câble : clic dessus."
	return ""


## Prix d'un câble (avec le coût de la partie).
static func prix_cable(type_id: String, longueur: float) -> int:
	return ReglagesPartie.prix(roundi(longueur * float(CABLES[type_id].cout)))


func _reseau(type_id: String) -> ReseauBase:
	return fibre if String(CABLES[type_id].reseau) == "fibre" else cuivre


## Pose un câble (payé). Rend l'identifiant du tronçon, ou -1.
func poser_cable(type_id: String, pts: PackedVector3Array) -> int:
	if pts.size() < 2 or not CABLES.has(type_id):
		return -1
	var cost := prix_cable(type_id, ReseauBase.longueur(pts))
	if buildings != null and not buildings.unlimited_money:
		if buildings.money < cost:
			message.emit("Pas assez d'argent : il faut %s." % BuildingSystem.format_money(cost))
			return -1
		buildings.money -= cost
	var id := _reseau(type_id).poser_troncon(pts, type_id)
	message.emit("%s : %s posés pour %s." % [CABLES[type_id].name, _km(ReseauBase.longueur(pts)), BuildingSystem.format_money(cost)])
	marquer()
	return id


## Fibre le long d'une route entière (tronçon le plus proche du point). Rend
## l'identifiant du câble, -1 si pas de route ou si elle est déjà fibrée.
func fibrer_rue(p: Vector3) -> int:
	if transport == null:
		return -1
	var best := -1
	var bd := 25.0
	for eid in transport.edges_near(p, 25.0):
		var e: Dictionary = transport.network.edges[eid]
		if TransportTypes.mode_of(String(e.t)) != TransportTypes.Mode.ROAD:
			continue
		var hit := transport.network.nearest_on_edge(eid, p)
		if float(hit.dist) < bd:
			bd = float(hit.dist)
			best = eid
	if best < 0:
		message.emit("Clique sur une route.")
		return -1
	var pts: PackedVector3Array = transport.network.edges[best].pts
	for id in fibre.troncons:
		var q: PackedVector3Array = fibre.troncons[id].pts
		if q.size() == pts.size() and q[0].distance_to(pts[0]) < 1.0 and q[q.size() - 1].distance_to(pts[pts.size() - 1]) < 1.0:
			message.emit("Cette rue a déjà la fibre.")
			return -1
	return poser_cable("fibre", pts.duplicate())


## Retire le câble le plus proche (moins de 8 m). Rend true si retiré.
func retirer_pres(p: Vector3) -> bool:
	var best_r: ReseauBase = null
	var best_id := -1
	var bd := 8.0
	for r in [fibre, cuivre]:
		for id in (r as ReseauBase).troncons:
			var pts: PackedVector3Array = (r as ReseauBase).troncons[id].pts
			for i in range(pts.size() - 1):
				var d := ReseauBase.dist_seg(p, pts[i], pts[i + 1])
				if d < bd:
					bd = d
					best_r = r
					best_id = id
	if best_r == null:
		return false
	var t := String(best_r.troncons[best_id].t)
	best_r.retirer_troncon(best_id)
	message.emit("%s retiré." % CABLES.get(t, {"name": "Câble"}).name)
	marquer()
	return true


## Points du tracé entre deux clics, au ras du sol tous les 5 m.
func _segment(a: Vector3, b: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	var n := maxi(1, ceili(a.distance_to(b) / 5.0))
	for i in range(1, n + 1):
		var q := a.lerp(b, float(i) / n)
		q.y = _sol(q.x, q.z, q.y)
		out.append(q)
	return out


func _sol(x: float, z: float, fallback := 0.0) -> float:
	if world == null:
		return fallback
	var h := world.raw_height(x, z)
	if is_nan(h) and world.horizon != null:
		h = world.horizon.height_at(x, z)
	return fallback if is_nan(h) else maxf(h, 0.0)


func _pick(pos: Vector2) -> Variant:
	var cam := get_viewport().get_camera_3d()
	if cam == null or world == null:
		return null
	return world.pick_point(cam.project_ray_origin(pos), cam.project_ray_normal(pos))


func _unhandled_input(event: InputEvent) -> void:
	if outil == Outil.AUCUN:
		return
	if event is InputEventMouseMotion:
		var p: Variant = _pick((event as InputEventMouseMotion).position)
		_survol_ok = p != null
		if p != null:
			_survol = p
			if not _trace.is_empty():
				_dessiner_trace()
	elif event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == KEY_ESCAPE:
		_finir()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			if not _trace.is_empty() or outil != Outil.AUCUN:
				_finir()
				get_viewport().set_input_as_handled()
			return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		var p: Variant = _pick(mb.position)
		if p == null:
			return
		get_viewport().set_input_as_handled()
		match outil:
			Outil.FIBRE_RUE:
				fibrer_rue(p)
			Outil.RETIRER:
				if not retirer_pres(p):
					message.emit("Pas de câble ici.")
			_:
				if _trace.is_empty():
					_trace.append(p)
				else:
					_trace.append_array(_segment(_trace[_trace.size() - 1], p))
				_dessiner_trace()


## Fin du tracé : pose ce qui a été tracé, ou range l'outil s'il n'y a rien.
func _finir() -> void:
	if _trace.size() >= 2 and OUTIL_CABLE.has(outil):
		poser_cable(OUTIL_CABLE[outil], _trace.duplicate())
		_trace.clear()
		_dessiner_trace()
		return
	set_outil(Outil.AUCUN)


# --- Dessin -----------------------------------------------------------------------

## Poteaux et fils des lignes aériennes (toujours visibles).
func _dessiner_poteaux() -> void:
	if _poteaux == null:
		return
	var k := BlocMesh.new()
	var any := false
	for r in [fibre, cuivre]:
		for id in (r as ReseauBase).troncons:
			var tr: Dictionary = (r as ReseauBase).troncons[id]
			if not CABLES.get(String(tr.t), {}).get("aerien", false):
				continue
			any = true
			var tops := _poteaux_de(tr.pts)
			for top in tops:
				k.cylinder(top.x, top.y - POTEAU_H, top.z, 0.13, 0.1, POTEAU_H, 5, Color("6f4e37"))
				k.box(top.x, top.y - 0.6, top.z, 0.9, 0.08, 0.08, Color("5c4033"))
			var col := Color("222222") if String(tr.t) == "cuivre_aerien" else Color("2b2d42")
			for i in range(tops.size() - 1):
				_ruban(k, tops[i] + Vector3(0, -0.5, 0), tops[i + 1] + Vector3(0, -0.5, 0), 0.04, col, 0.6)
	_poteaux.mesh = k.to_mesh() if any else null


func _poteaux_de(pts: PackedVector3Array) -> Array:
	var out := []
	var l := ReseauBase.longueur(pts)
	var n := maxi(1, ceili(l / POTEAU_PAS))
	for i in n + 1:
		var q := _point_a(pts, l * i / n)
		out.append(Vector3(q.x, _sol(q.x, q.z, q.y) + POTEAU_H, q.z))
	return out


static func _point_a(pts: PackedVector3Array, s: float) -> Vector3:
	var acc := 0.0
	for i in range(1, pts.size()):
		var seg := pts[i].distance_to(pts[i - 1])
		if acc + seg >= s and seg > 0.0:
			return pts[i - 1].lerp(pts[i], (s - acc) / seg)
		acc += seg
	return pts[pts.size() - 1]


## Ruban entre deux points (fil, câble), avec une flèche (creux) au milieu.
static func _ruban(k: BlocMesh, a: Vector3, b: Vector3, w: float, col: Color, creux := 0.0) -> void:
	var dir := b - a
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	var side := Vector3(-dir.z, 0, dir.x).normalized() * w
	var parts := 4 if creux > 0.0 else 1
	for i in parts:
		var t0 := float(i) / parts
		var t1 := float(i + 1) / parts
		var p0 := a.lerp(b, t0) - Vector3(0, creux * 4.0 * t0 * (1.0 - t0), 0)
		var p1 := a.lerp(b, t1) - Vector3(0, creux * 4.0 * t1 * (1.0 - t1), 0)
		k.quad(p0 - side, p1 - side, p1 + side, p0 + side, Vector3.UP, col)


func set_calque(c: String) -> void:
	calque = c
	_calque_dirty = true
	if c == "":
		_calque_mesh.mesh = null
	else:
		_dessiner_calque()


## Calque « mobile » : disques de couverture par génération ; calque « débit » :
## une pastille par bâtiment (fibre, ADSL, lent, mobile seul, rien) ; les deux
## montrent les câbles (fibre en rose, cuivre sur poteaux en orange).
func _dessiner_calque() -> void:
	_calque_dirty = false
	if _calque_mesh == null:
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 0
	if calque == "mobile":
		var order := ["2g", "4g", "5g"]
		for g in order:
			for bid in antennes:
				var a: Dictionary = antennes[bid]
				for e in a.em:
					if e.gen == g:
						_disque(st, a.p, float(e.portee), TelecomTypes.GENS[g].color, 0.6 + order.find(g) * 0.4)
						n += 1
	elif calque == "debit":
		for bid in service:
			var q := qualite(bid)
			var b: Dictionary = buildings.buildings.get(bid, {})
			if b.is_empty():
				continue
			var c := buildings._center_of(b)
			var y := _sol(c.x, c.y) + 12.0
			var node := buildings.node_of(bid)
			if node != null and node.mesh != null:
				y = node.global_position.y + node.get_aabb().end.y + 3.0
			var t := BuildingCatalog.get_type(String(b.t))
			var taille := clampf(minf(float(t.get("w", 8)), float(t.get("d", 8))) * 0.6, 5.0, 14.0)
			_carre(st, Vector3(c.x + 0.5, y, c.y + 0.5), taille, COULEURS_NET[q])
			n += 1
	for r in [fibre, cuivre]:
		for id in (r as ReseauBase).troncons:
			var tr: Dictionary = (r as ReseauBase).troncons[id]
			var col: Color = COULEUR_FIBRE if (r as ReseauBase) == fibre else COULEUR_CUIVRE
			var pts: PackedVector3Array = tr.pts
			for i in range(pts.size() - 1):
				_bande(st, pts[i] + Vector3(0, 0.8, 0), pts[i + 1] + Vector3(0, 0.8, 0), 1.2, col)
				n += 1
	_calque_mesh.mesh = st.commit() if n > 0 else null


func _disque(st: SurfaceTool, c: Vector3, r: float, col: Color, dy: float) -> void:
	var sides := 64
	var rings := 6
	var fill := Color(col, 0.2)
	var edge := Color(col, 0.95)
	for j in rings:
		var r0 := r * j / rings
		var r1 := r * (j + 1) / rings
		for i in sides:
			var a0 := TAU * i / sides
			var a1 := TAU * (i + 1) / sides
			var p00 := _pt(c, r0, a0, dy)
			var p01 := _pt(c, r0, a1, dy)
			var p10 := _pt(c, r1, a0, dy)
			var p11 := _pt(c, r1, a1, dy)
			for v in [[p00, p10, p11], [p00, p11, p01]]:
				for q in v:
					st.set_color(fill)
					st.add_vertex(q)
	# Bord bien visible.
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var w := maxf(3.0, r * 0.012)
		var o0 := _pt(c, r, a0, dy + 0.2)
		var o1 := _pt(c, r, a1, dy + 0.2)
		var i0 := _pt(c, r - w, a0, dy + 0.2)
		var i1 := _pt(c, r - w, a1, dy + 0.2)
		for q in [i0, o0, o1, i0, o1, i1]:
			st.set_color(edge)
			st.add_vertex(q)


func _pt(c: Vector3, r: float, a: float, dy: float) -> Vector3:
	var x := c.x + cos(a) * r
	var z := c.z + sin(a) * r
	return Vector3(x, _sol(x, z, c.y) + dy, z)


func _carre(st: SurfaceTool, c: Vector3, s: float, col: Color) -> void:
	var h := s / 2.0
	var a := c + Vector3(-h, 0, -h)
	var b := c + Vector3(h, 0, -h)
	var d := c + Vector3(h, 0, h)
	var e := c + Vector3(-h, 0, h)
	for q in [a, b, d, a, d, e]:
		st.set_color(Color(col, 0.95))
		st.add_vertex(q)


func _bande(st: SurfaceTool, a: Vector3, b: Vector3, w: float, col: Color) -> void:
	var dir := b - a
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	var side := Vector3(-dir.z, 0, dir.x).normalized() * (w / 2.0)
	for q in [a - side, b - side, b + side, a - side, b + side, a + side]:
		st.set_color(Color(col, 0.9))
		st.add_vertex(q)


## Tracé en cours (fantôme) jusqu'au curseur.
func _dessiner_trace() -> void:
	if _trace_mesh == null:
		return
	if _trace.is_empty() or not OUTIL_CABLE.has(outil):
		_trace_mesh.mesh = null
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := _trace.duplicate()
	if _survol_ok:
		pts.append(_survol)
	var col := COULEUR_FIBRE if String(CABLES[OUTIL_CABLE[outil]].reseau) == "fibre" else COULEUR_CUIVRE
	for i in range(pts.size() - 1):
		_bande(st, pts[i] + Vector3(0, 1.0, 0), pts[i + 1] + Vector3(0, 1.0, 0), 1.5, col)
	_trace_mesh.mesh = st.commit() if pts.size() >= 2 else null
	var l := ReseauBase.longueur(pts)
	info_changed.emit("%s : %s, %s. Échap ou clic droit pour finir." % [CABLES[OUTIL_CABLE[outil]].name, _km(l),
		BuildingSystem.format_money(prix_cable(OUTIL_CABLE[outil], l))])


# --- Sauvegarde -------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"v": 1, "fibre": fibre.to_dict(), "cuivre": cuivre.to_dict()}


func from_dict(d: Dictionary) -> void:
	fibre.clear()
	cuivre.clear()
	fibre.from_dict(d.get("fibre", {}))
	cuivre.from_dict(d.get("cuivre", {}))
	marquer()
	recalculer()
