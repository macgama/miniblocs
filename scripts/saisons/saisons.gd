class_name Saisons
extends Node3D
## Saisons, climat et catastrophes naturelles (panneau Saisons et risques, Maj+R).
##
## S'appuie sur la météo (Meteo), les événements (Evenements), les réseaux
## (sécheresse et canicule de ReseauxIncidents), l'agriculture et la
## circulation (Traffic) :
##
## - SAISONS : printemps, été, automne, hiver selon la vraie date et
##   l'hémisphère (saison des pluies et saison sèche sous les tropiques). Le
##   climat de chaque jour est noté (pluie en mm, neige en cm, températures),
##   avec les records et un bilan à chaque changement de saison. Prévisions
##   à 3 jours, 7 avec une station météo (le temps du jeu est reproductible :
##   les prévisions disent vrai… presque toujours).
## - NEIGE ET DÉNEIGEMENT : la neige tient sur les routes (cm par tronçon) et
##   ralentit tout le monde, secours compris ; sur la neige, il y a des
##   accidents. Les chasse-neige saleuses du centre technique municipal
##   déneigent, les grands axes d'abord, et salent (la neige ne tient plus
##   pendant 12 h). Le sel s'achète (dôme de 150 t, rachat automatique).
## - INONDATIONS : plusieurs jours de grosses pluies ou une fonte des neiges
##   rapide font monter les rivières (vigilance crues verte, jaune, orange,
##   rouge) : crue lente sur un jour ou deux, routes coupées, bâtiments et
##   champs inondés, pompiers. Les bassins de rétention font monter l'eau
##   moins haut.
## - SÉCHERESSE : niveaux des arrêtés français (vigilance, alerte, alerte
##   renforcée, crise) d'après les jours sans pluie. La préfecture impose les
##   restrictions d'eau dès l'alerte ; les cultures et les prés souffrent ; en
##   alerte renforcée, les feux de broussailles menacent les maisons au bord
##   des bois.
## - CANICULE (3 jours à 33 °C et plus), GEL TARDIF au printemps (les jeunes
##   cultures gèlent) : nouvelles, avis des habitants, récoltes.
##
## Liens par groupes de nœuds : "avis_sources", "budget_entretien".

signal changed
signal message(text: String)

static var instance: Saisons

const NOMS_SAISONS := ["Hiver", "Printemps", "Été", "Automne"]
const ICONES_SAISONS := ["neige", "fleur", "soleil", "feuille"]
const NIVEAUX_SECHERESSE := ["Normale", "Vigilance", "Alerte", "Alerte renforcée", "Crise"]
const COULEURS_VIGILANCE := [Color("52b788"), Color("ffd166"), Color("f4a259"), Color("ef476f")]
const NOMS_VIGILANCE := ["Verte", "Jaune", "Orange", "Rouge"]

## Précipitations (mm par heure) pour une intensité de 1 ; neige (cm par heure).
const MM_H := 8.0
const NEIGE_CM_H := 4.0
## Neige sur une route : seuil pour sortir les engins, fonte par degré au-dessus de 0,5 °C.
const SEUIL_CM := 1.5
const FONTE_CM_H := 0.35
## Le sel empêche la neige de tenir pendant SEL_H heures (jusqu'à −8 °C).
const SEL_H := 12.0
const SEL_T_KM := 0.12
const PRIX_SEL_T := 110.0
## Chasse-neige : vitesse de travail (m/s), parcours maximal (m), rayon d'action (m).
const VITESSE_LAME := 8.3
const VITESSE_TRAJET := 12.0
const TOURNEE_M := 12000.0
const TOURNEE_MAX := 40
const RAYON := 7000.0
const COUT_ENGIN := 2200.0
const ENTRETIEN := 0.001
## Numéro des chasse-neige dans Traffic (bennes : 1 000 000 et plus).
const TAG := 3_000_000
const MAX_VISIBLE := 12
## Crues : indice (mm de pluie sur 3 jours + fonte) des vigilances jaune, orange, rouge.
const CRUE_JAUNE := 40.0
const CRUE_ORANGE := 70.0
const CRUE_ROUGE := 100.0
const HISTORIQUE := 400

var world: TerrainWorld
var ambiance: DayNight
var transport: TransportSystem
var buildings: BuildingSystem
var population: Population
var evenements: Evenements
var agriculture: Agriculture

## Jours notés, le plus ancien d'abord : {j (jour local), pluie (mm), neige (cm), tmin, tmax}.
var jours: Array = []
## Jour en cours (en train d'être noté).
var aujourdhui := {}
var records := {"tmax": -100.0, "tmax_j": -1, "tmin": 100.0, "tmin_j": -1, "pluie": 0.0, "pluie_j": -1, "neige": 0.0, "neige_j": -1}
var saison := -1
## Neige sur les routes : id du tronçon -> cm ; salé jusqu'à : id -> unix.
var neige: Dictionary = {}
var sel: Dictionary = {}
## Centres techniques : bid -> {sel (t), engins: [mid ou 0]}.
var centres: Dictionary = {}
## Tournées des chasse-neige : mid -> {id, centre, parcours: [{e, t, fait}], t_end, m}.
var missions: Dictionary = {}
var next_mission := 1
## Sécheresse quand le jeu n'a pas de réseaux : jours secs comptés ici.
var jours_secs := 0.0
var niveau_secheresse := 0
var canicule := false
var jours_chauds := 0
var indice_crue := 0.0
var vigilance_crue := 0
## Totaux de la partie (panneau).
var totaux := {"km_deneiges": 0.0, "sel_t": 0.0, "accidents": 0, "crues": 0, "feux": 0, "gels": 0}
## Tests : forcer les catastrophes (1 oui, 0 non, −1 réglages).
var forcer := -1
var clock := -1.0

var _last_unix := NAN
var _acc_h := 0.0
var _acc_10 := 0.0
var _jour := -1
var _restr_auto := false
var _neige_sol_hier := 0.0
var _dernier_accident := -1e12
var _dernier_gel := -1e12
var _jour_neige_annonce := -1
var _mesh: MeshInstance3D
var _mesh_dirty := true
var _mesh_timer := 0.0
var _acces: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _froid_fin := 0.0
var _neige_fin := 0.0
var _mode_avant := -1


func _init() -> void:
	name = "Saisons"
	_rng.randomize()


func _enter_tree() -> void:
	instance = self
	add_to_group("avis_sources")
	add_to_group("budget_entretien")


func _exit_tree() -> void:
	if instance == self:
		instance = null


func setup(w: TerrainWorld, a: DayNight, t: TransportSystem, b: BuildingSystem, p: Population, ev: Evenements, agri: Agriculture) -> void:
	world = w
	ambiance = a
	transport = t
	buildings = b
	population = p
	evenements = ev
	agriculture = agri
	if evenements != null:
		evenements.modules["crue"] = self
	if transport != null and transport.traffic != null:
		transport.traffic.speed_factors.append(_facteur_vitesse)
	if buildings != null:
		buildings.changed.connect(_sync_centres)
		buildings.removed.connect(func(bid: int) -> void:
			_acces.erase(bid))
	_mesh = MeshInstance3D.new()
	_mesh.name = "NeigeRoutes"
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.85
	mat.albedo_color = Color(1, 1, 1)
	_mesh.material_override = mat
	add_child(_mesh)


func clear() -> void:
	for mid in missions.keys():
		_drop_visual(int(mid))
	missions.clear()
	neige.clear()
	sel.clear()
	centres.clear()
	jours.clear()
	aujourdhui = {}
	records = {"tmax": -100.0, "tmax_j": -1, "tmin": 100.0, "tmin_j": -1, "pluie": 0.0, "pluie_j": -1, "neige": 0.0, "neige_j": -1}
	saison = -1
	next_mission = 1
	jours_secs = 0.0
	niveau_secheresse = 0
	canicule = false
	jours_chauds = 0
	indice_crue = 0.0
	vigilance_crue = 0
	totaux = {"km_deneiges": 0.0, "sel_t": 0.0, "accidents": 0, "crues": 0, "feux": 0, "gels": 0}
	_last_unix = NAN
	_jour = -1
	_restr_auto = false
	_acces.clear()
	_mesh_dirty = true
	changed.emit()


# --- Temps et lieu -----------------------------------------------------------------------------

func now() -> float:
	if clock >= 0.0:
		return clock
	return ambiance.unix_time if ambiance != null else 0.0


func meteo() -> Meteo:
	return ambiance.weather if ambiance != null else null


func lat() -> float:
	return world.origin_lat if world != null else 46.0


func lon() -> float:
	return world.origin_lon if world != null else 6.0


func climat() -> int:
	return Plantes.climat(lat(), lon())


func _utc() -> float:
	return ambiance.utc_offset() if ambiance != null else 0.0


## Date locale d'un instant : {j (jour depuis 1970), h, month, day, doy (0 à 365)}.
func date_locale(unix: float) -> Dictionary:
	var local := unix + _utc() * 3600.0
	var dt := Time.get_datetime_dict_from_unix_time(int(local))
	const AVANT := [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334]
	return {"j": int(floorf(local / 86400.0)), "h": fposmod(local, 86400.0) / 3600.0, "month": int(dt.month),
		"day": int(dt.day), "doy": AVANT[int(dt.month) - 1] + int(dt.day) - 1, "year": int(dt.year)}


func catastrophes_on() -> bool:
	if forcer >= 0:
		return forcer == 1
	if evenements != null:
		return evenements.catastrophes_on()
	return ReglagesPartie.actuel.catastrophes


func frequence() -> float:
	return ReglagesPartie.actuel.frequence_catastrophes


static func neige_active() -> bool:
	return ReglagesPartie.actuel.neige_routes


# --- Saisons -----------------------------------------------------------------------------------

## Saison (0 hiver, 1 printemps, 2 été, 3 automne) d'un jour de l'année, selon l'hémisphère.
static func saison_de(doy: int, latitude: float) -> int:
	var d := doy
	if latitude < 0.0:
		d = (doy + 183) % 365
	if d < 78 or d >= 354:
		return 0
	if d < 171:
		return 1
	if d < 265:
		return 2
	return 3


## Saison des pluies sous les tropiques (hémisphère nord : mai à octobre).
static func saison_pluies(month: int, latitude: float) -> bool:
	var m := month if latitude >= 0.0 else (month + 5) % 12 + 1
	return m >= 5 and m <= 10


func tropical() -> bool:
	return climat() == Plantes.Climat.TROPICAL


func nom_saison() -> String:
	var d := date_locale(now())
	if tropical():
		return "Saison des pluies" if saison_pluies(int(d.month), lat()) else "Saison sèche"
	return NOMS_SAISONS[saison_de(int(d.doy), lat())]


func icone_saison() -> String:
	var d := date_locale(now())
	if tropical():
		return "pluie" if saison_pluies(int(d.month), lat()) else "soleil"
	return ICONES_SAISONS[saison_de(int(d.doy), lat())]


## Avancement dans la saison (0 à 1) et jours restants.
func avancement_saison() -> Vector2:
	var doy := int(date_locale(now()).doy)
	var d := doy if lat() >= 0.0 else (doy + 183) % 365
	var bornes := [[-11, 78], [78, 171], [171, 265], [265, 354]]
	var s := saison_de(doy, lat())
	var a: int = bornes[s][0]
	var b: int = bornes[s][1]
	var x := d if not (s == 0 and d >= 354) else d - 365
	return Vector2(clampf(float(x - a) / float(b - a), 0.0, 1.0), float(b - x))


# --- Boucle ------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if ambiance == null:
		return
	var t := now()
	if is_nan(_last_unix) or t < _last_unix - 1.0:
		_last_unix = t
		_jour = int(date_locale(t).j)
	var dt := clampf(t - _last_unix, 0.0, 12.0 * 3600.0)
	_last_unix = t
	advance(dt, t)
	_mesh_timer -= delta
	if _mesh_dirty and _mesh_timer <= 0.0:
		_mesh_timer = 1.5
		_rebuild_mesh()


## Fait avancer le climat de dt secondes de jeu (t : instant atteint).
func advance(dt: float, t: float) -> void:
	_acc_h += dt
	_acc_10 += dt
	var n := 0
	while _acc_h >= 3600.0 and n < 12:
		_acc_h -= 3600.0
		n += 1
		_heure(t - _acc_h)
	if n >= 12:
		_acc_h = 0.0
	if _acc_10 >= 600.0:
		var k := mini(int(_acc_10 / 600.0), 6)
		_acc_10 = fmod(_acc_10, 600.0)
		for i in k:
			_dix_minutes(t)
	_avance_tournees(t)


## Une heure de jeu : relevé météo, neige sur les routes, accidents.
func _heure(t: float) -> void:
	var d := date_locale(t)
	if _jour < 0:
		_jour = int(d.j)
	if int(d.j) != _jour:
		_nouveau_jour(d)
		_jour = int(d.j)
	var w := meteo()
	var temp := w.temperature if w != null else 12.0
	var precip := w.precip if w != null else 0.0
	var part_neige := w.snow if w != null else 0.0
	if aujourdhui.is_empty() or int(aujourdhui.j) != int(d.j):
		aujourdhui = {"j": int(d.j), "pluie": 0.0, "neige": 0.0, "tmin": temp, "tmax": temp}
	aujourdhui.pluie = float(aujourdhui.pluie) + precip * MM_H
	var cm := precip * part_neige * NEIGE_CM_H if temp < 1.5 else 0.0
	aujourdhui.neige = float(aujourdhui.neige) + cm
	aujourdhui.tmin = minf(float(aujourdhui.tmin), temp)
	aujourdhui.tmax = maxf(float(aujourdhui.tmax), temp)
	_neige_routes(cm, temp, t)
	_fin_neige_forcee(t)
	_accidents(t)
	if int(float(d.h)) == 7:
		_jour_de_neige(int(d.j))
	_dispatch(t)


func _dix_minutes(t: float) -> void:
	for e in _crues_en_cours():
		_monte(e, t)


# --- Un jour -------------------------------------------------------------------------------------

func _nouveau_jour(d: Dictionary) -> void:
	if not aujourdhui.is_empty():
		var j := aujourdhui.duplicate()
		jours.append(j)
		if jours.size() > HISTORIQUE:
			jours.pop_front()
		_records(j)
		_gel_tardif(j, d)
		_canicule(j)
	_secheresse()
	_crue_du_jour()
	_saison_du_jour(d)
	_achat_sel()
	_pay_day()
	_neige_sol_hier = world.neige if world != null else 0.0
	aujourdhui = {}
	changed.emit()


func _records(j: Dictionary) -> void:
	if float(j.tmax) > float(records.tmax):
		records.tmax = float(j.tmax)
		records.tmax_j = int(j.j)
	if float(j.tmin) < float(records.tmin):
		records.tmin = float(j.tmin)
		records.tmin_j = int(j.j)
	if float(j.pluie) > float(records.pluie):
		records.pluie = float(j.pluie)
		records.pluie_j = int(j.j)
	if float(j.neige) > float(records.neige):
		records.neige = float(j.neige)
		records.neige_j = int(j.j)


func _saison_du_jour(d: Dictionary) -> void:
	var s := saison_de(int(d.doy), lat())
	if tropical():
		s = 10 + (1 if saison_pluies(int(d.month), lat()) else 0)
	if saison < 0:
		saison = s
		return
	if s == saison:
		return
	var avant := saison
	saison = s
	var bilan := _bilan(90)
	var txt := ""
	match s:
		0: txt = "C'est l'hiver : pense aux chasse-neige et au sel. Les pulls sortent des placards."
		1: txt = "Le printemps est là : on sème le maïs et la betterave… et le pollen fait éternuer la moitié de la ville."
		2: txt = "C'est l'été : moissons de juillet, piscines pleines et barbecues. Gare à la sécheresse."
		3: txt = "L'automne arrive : vendanges, labours et feuilles mortes dans les caniveaux."
		10: txt = "Début de la saison sèche : le fourrage se fait rare, l'eau devient précieuse."
		11: txt = "La saison des pluies commence : rivières en hausse, champs à semer."
	if avant >= 0 and not bilan.is_empty():
		txt += " Bilan de la saison passée : %s mm de pluie, %s à %s." % [_num(float(bilan.pluie)), _deg(float(bilan.tmin)), _deg(float(bilan.tmax))]
		if float(bilan.neige) > 0.5:
			txt += " %s cm de neige tombés." % _num(float(bilan.neige))
	_news(txt, "saison")


## Bilan des n derniers jours notés : {pluie, neige, tmin, tmax, jours_pluie, jours_neige}.
func _bilan(n: int) -> Dictionary:
	if jours.is_empty():
		return {}
	var out := {"pluie": 0.0, "neige": 0.0, "tmin": 100.0, "tmax": -100.0, "jours_pluie": 0, "jours_neige": 0}
	for j in jours.slice(maxi(0, jours.size() - n)):
		out.pluie = float(out.pluie) + float(j.pluie)
		out.neige = float(out.neige) + float(j.neige)
		out.tmin = minf(float(out.tmin), float(j.tmin))
		out.tmax = maxf(float(out.tmax), float(j.tmax))
		if float(j.pluie) >= 1.0:
			out.jours_pluie = int(out.jours_pluie) + 1
		if float(j.neige) >= 1.0:
			out.jours_neige = int(out.jours_neige) + 1
	return out


func bilan(n: int) -> Dictionary:
	return _bilan(n)


## Pluie (mm) des n derniers jours, le jour en cours compris.
func pluie_jours(n: int) -> float:
	var s := float(aujourdhui.get("pluie", 0.0))
	for j in jours.slice(maxi(0, jours.size() - n + 1)):
		s += float(j.pluie)
	return s


# --- Gel tardif et canicule --------------------------------------------------------------------

func _gel_tardif(j: Dictionary, d: Dictionary) -> void:
	var m := AgriDonnees.mois_nord(int(d.month), lat())
	if m < 3 or m > 5 or float(j.tmin) > -1.5 or agriculture == null:
		return
	var touches := 0
	for id in agriculture.champs:
		var ch: Dictionary = agriculture.champs[id]
		if String(ch.etat) != "pousse":
			continue
		var c := AgriDonnees.culture(String(ch.sc))
		if c.is_empty() or bool(c.get("permanente", false)) or float(ch.cr) > 0.35:
			continue
		ch.met = float(ch.get("met", 1.0)) * 0.85
		touches += 1
	if touches > 0:
		totaux.gels = int(totaux.gels) + 1
		if now() - _dernier_gel > 5.0 * 86400.0:
			_dernier_gel = now()
			_news("Gelée tardive (%s) : %d champ%s de jeunes pousses touché%s, 15 %% de récolte en moins. Les jardiniers maudissent les saints de glace." % [
				_deg(float(j.tmin)), touches, "s" if touches > 1 else "", "s" if touches > 1 else ""], "gel")


func _canicule(j: Dictionary) -> void:
	if float(j.tmax) >= 33.0:
		jours_chauds += 1
	else:
		jours_chauds = 0
	var avant := canicule
	canicule = jours_chauds >= 3
	if canicule and not avant:
		_news("Canicule : %d jours au-dessus de 33 °C. Le plan canicule est déclenché : on hydrate les anciens, les ventilateurs sont en rupture de stock." % jours_chauds, "canicule")
	elif avant and not canicule:
		_news("Fin de l'épisode caniculaire : la ville respire.", "canicule")


# --- Sécheresse ------------------------------------------------------------------------------------

func _reseaux() -> Reseaux:
	return Reseaux.instance if Reseaux.instance != null and is_instance_valid(Reseaux.instance) else null


## Jours secs comptés (ceux des réseaux quand ils sont là).
func jours_sans_pluie() -> float:
	var r := _reseaux()
	return r.incidents.jours_secs if r != null else jours_secs


func indice_secheresse() -> float:
	var r := _reseaux()
	if r != null:
		return r.incidents.secheresse
	return clampf((jours_secs - ReseauxIncidents.JOURS_SECS_DEBUT) / ReseauxIncidents.JOURS_SECS_PLEIN, 0.0, 1.0)


static func niveau_de(jours_secs_: float, indice: float) -> int:
	if indice >= 0.75:
		return 4
	if indice >= 0.4:
		return 3
	if indice > 0.0:
		return 2
	if jours_secs_ >= 8.0:
		return 1
	return 0


func _secheresse() -> void:
	if _reseaux() == null and not jours.is_empty():
		var j: Dictionary = jours[-1]
		if float(j.pluie) >= 1.2:
			jours_secs = maxf(jours_secs - 4.0, 0.0)
		elif float(j.pluie) >= 0.4:
			jours_secs = maxf(jours_secs - 1.0, 0.0)
		elif float(j.tmax) > 15.0:
			jours_secs += 1.0
	var avant := niveau_secheresse
	niveau_secheresse = niveau_de(jours_sans_pluie(), indice_secheresse())
	var r := _reseaux()
	if niveau_secheresse >= 2 and r != null and not r.incidents.restrictions:
		r.incidents.restrictions = true
		_restr_auto = true
	elif niveau_secheresse <= 1 and _restr_auto and r != null:
		r.incidents.restrictions = false
		_restr_auto = false
	if niveau_secheresse > avant:
		var txt := ""
		match niveau_secheresse:
			1: txt = "Sécheresse, vigilance : %d jours sans vraie pluie. On ressort les arrosoirs… avec modération." % int(jours_sans_pluie())
			2: txt = "Arrêté sécheresse, niveau alerte : interdiction d'arroser les pelouses et de laver sa voiture. Le golf municipal fait grise mine."
			3: txt = "Sécheresse, alerte renforcée : les champs jaunissent, les rivières baissent, risque de feux de broussailles au bord des bois."
			4: txt = "Sécheresse, niveau crise : l'eau est réservée aux usages essentiels. Même le maire a dû renoncer à remplir sa piscine."
		if txt != "":
			_news(txt, "secheresse")
	elif niveau_secheresse == 0 and avant >= 2:
		_news("La pluie est revenue : fin des restrictions d'eau. Les escargots sont ravis.", "secheresse")
	_effets_secheresse()


func _effets_secheresse() -> void:
	if agriculture != null:
		agriculture.herbe_facteur = 1.0 - 0.2 * maxf(float(niveau_secheresse) - 1.0, 0.0)
		if niveau_secheresse >= 2:
			var perte := 0.003 * float(niveau_secheresse - 1)
			for id in agriculture.champs:
				var ch: Dictionary = agriculture.champs[id]
				if String(ch.etat) != "pousse":
					continue
				var c := AgriDonnees.culture(String(ch.sc))
				if c.is_empty() or bool(c.get("permanente", false)):
					continue
				var p := perte * (2.0 if String(ch.sc) in ["riz", "mais"] else 1.0)
				ch.met = float(ch.get("met", 1.0)) * (1.0 - p)
	# Feux de broussailles au bord des bois.
	if niveau_secheresse >= 3 and catastrophes_on() and evenements != null and not jours.is_empty():
		var j: Dictionary = jours[-1]
		if float(j.tmax) >= 27.0 and _rng.randf() < 0.12 * float(niveau_secheresse - 2) * frequence():
			feu_de_broussailles()


## Un feu part des broussailles et prend une maison au bord des bois ; renvoie l'événement (−1 : rien).
func feu_de_broussailles() -> int:
	if evenements == null or buildings == null:
		return -1
	var cands := []
	for bid in buildings.buildings:
		if buildings.en_chantier(bid):
			continue
		var p := evenements.building_pos(bid)
		if _bord_des_bois(Vector2i(floori(p.x), floori(p.z))):
			cands.append(bid)
	if cands.is_empty():
		for bid in buildings.buildings:
			cands.append(bid)
	if cands.is_empty():
		return -1
	var bid: int = cands[_rng.randi() % cands.size()]
	var id := evenements.incendies.start_fire(bid, "secheresse")
	if id >= 0:
		totaux.feux = int(totaux.feux) + 1
		var raisons := ["un barbecue « parfaitement maîtrisé » selon son propriétaire", "un mégot jeté par la fenêtre d'une voiture",
			"une étincelle de débroussailleuse", "la foudre sèche d'un orage sans pluie"]
		_news("Feu de broussailles près de %s : %s. Les pompiers sont en route." % [evenements.building_name(bid),
			raisons[_rng.randi() % raisons.size()]], "secheresse", evenements.building_pos(bid))
	return id


func _bord_des_bois(c: Vector2i) -> bool:
	if world == null:
		return false
	for o in [Vector2i(30, 0), Vector2i(-30, 0), Vector2i(0, 30), Vector2i(0, -30), Vector2i(50, 50), Vector2i(-50, -50)]:
		var b := world.cell_biome(c + o)
		if b == 10 or b == 20:
			return true
	return false


# --- Crues ---------------------------------------------------------------------------------------

## Indice de crue : pluie des 3 derniers jours (mm) et fonte des neiges.
func _indice_crue() -> float:
	var fonte := 0.0
	if world != null and meteo() != null and meteo().temperature > 4.0:
		fonte = maxf(_neige_sol_hier - world.neige, 0.0) * 60.0
	return pluie_jours(3) + fonte


static func vigilance_de(indice: float) -> int:
	if indice >= CRUE_ROUGE:
		return 3
	if indice >= CRUE_ORANGE:
		return 2
	if indice >= CRUE_JAUNE:
		return 1
	return 0


func _crue_du_jour() -> void:
	indice_crue = _indice_crue()
	var avant := vigilance_crue
	vigilance_crue = vigilance_de(indice_crue)
	if vigilance_crue >= 2 and vigilance_crue > avant:
		_news("Vigilance crues %s : %s mm de pluie en trois jours, les rivières montent." % [NOMS_VIGILANCE[vigilance_crue].to_lower(),
			_num(indice_crue)], "crue")
	if vigilance_crue < 2 or not catastrophes_on() or not _crues_en_cours().is_empty():
		return
	var p := (0.35 if vigilance_crue == 2 else 1.0) * frequence()
	if _rng.randf() < p:
		declencher_crue(vigilance_crue, true)


func _crues_en_cours() -> Array:
	return evenements.en_cours("crue") if evenements != null else []


## Lance une crue (niveau 2 orange, 3 rouge) ; renvoie l'id de l'événement, −1 sans rivière.
func declencher_crue(niveau := 2, auto := false) -> int:
	if evenements == null:
		return -1
	for e in _crues_en_cours():
		return int(e.id)
	var h := _rng.randf_range(12.0, 24.0) if niveau >= 3 else _rng.randf_range(8.0, 16.0)
	var pos := Vector3.ZERO
	if buildings != null and not buildings.buildings.is_empty():
		pos = evenements.building_pos(buildings.buildings.keys()[0])
	var id := evenements.ajouter("crue", "Crue", now(), now() + h * 3600.0, pos, -1,
		{"crue": [], "niveau": 0.0, "fin_crue": 0.0, "vigilance": niveau, "montee_h": h}, auto)
	evenements._update_events(now())
	var e: Dictionary = evenements.events.get(id, {})
	if e.is_empty() or (e.data.crue as Array).is_empty():
		if not e.is_empty():
			evenements.finir(id)
		message.emit("Pas de rivière assez grosse près de la ville : pas de crue possible ici.")
		return -1
	return id


## Facteur des bassins de rétention autour d'un point (1 : aucun, 0,25 au mieux).
func facteur_retention(p: Vector3) -> float:
	var f := 1.0
	if buildings == null:
		return f
	var n := 0
	for bid in buildings.buildings:
		var b: Dictionary = buildings.buildings[bid]
		var s := SaisonsTypes.spec_of(String(b.t))
		if String(s.get("role", "")) != "retention" or buildings.en_chantier(bid):
			continue
		var q := evenements.building_pos(bid) if evenements != null else Vector3.ZERO
		if Vector2(q.x, q.z).distance_to(Vector2(p.x, p.z)) <= float(s.get("rayon", 3000.0)):
			n += 1
	return maxf(1.0 - 0.25 * n, 0.25)


## Événement « crue » commencé (appelé par Evenements).
func on_start(e: Dictionary) -> void:
	if evenements.tempetes == null:
		return
	var d: Dictionary = e.data
	if (d.get("crue", []) as Array).is_empty():
		evenements.tempetes._prepare_crue(e)
	if (d.crue as Array).is_empty():
		return
	var s0: Array = d.crue[0][0]
	var p0 := Vector3(float(s0[0]), float(s0[1]), float(s0[2]))
	e.pos = p0
	var haut := _rng.randf_range(1.2, 2.0) if int(d.get("vigilance", 2)) >= 3 else _rng.randf_range(0.6, 1.1)
	var fr := facteur_retention(p0)
	d.niveau_max = haut * fr
	d.retention = fr
	totaux.crues = int(totaux.crues) + 1
	var txt := "Crue : la rivière sort de son lit, l'eau va monter de %s m." % _num(float(d.niveau_max))
	if fr < 1.0:
		txt += " Les bassins de rétention retiennent %d %% de la vague." % roundi((1.0 - fr) * 100.0)
	else:
		txt += " Les riverains montent les meubles à l'étage."
	_news(txt, "crue", p0, int(e.id))


func on_end(e: Dictionary) -> void:
	var d: Dictionary = e.data
	if float(d.get("niveau", 0.0)) > 0.0 and evenements.tempetes != null:
		_champs_inondes(e)
		evenements.tempetes._decrue(e)
		_news("La crue a atteint son maximum (%s m) : l'eau redescend." % _num(float(d.niveau)), "crue", e.pos, int(e.id))


## L'eau monte par paliers de 10 minutes jusqu'au maximum.
func _monte(e: Dictionary, t: float) -> void:
	var d: Dictionary = e.data
	if (d.crue as Array).is_empty() or evenements.tempetes == null:
		return
	var pas := float(d.niveau_max) / maxf(float(d.get("montee_h", 12.0)) * 6.0 * 0.7, 1.0)
	var avant := float(d.niveau)
	d.niveau = minf(avant + pas, float(d.niveau_max))
	if absf(float(d.niveau) - float(d.get("niveau_vu", -1.0))) >= 0.1 or float(d.niveau) >= float(d.niveau_max):
		d.niveau_vu = float(d.niveau)
		evenements.tempetes._update_crue(e, t)


func _champs_inondes(e: Dictionary) -> void:
	if agriculture == null:
		return
	var d: Dictionary = e.data
	var spread := 6.0 + float(d.niveau) * 18.0 + 4.0
	var n := 0
	for id in agriculture.champs:
		var ch: Dictionary = agriculture.champs[id]
		if not String(ch.etat) in ["pousse", "mur"]:
			continue
		var r: Rect2i = ch.r
		var c := Vector3(r.position.x + r.size.x * 0.5, 0, r.position.y + r.size.y * 0.5)
		var rayon := maxf(r.size.x, r.size.y) * 0.5
		for s in d.crue:
			var a := Vector3(float(s[0][0]), 0, float(s[0][2]))
			var b := Vector3(float(s[1][0]), 0, float(s[1][2]))
			if Geometry3D.get_closest_point_to_segment(c, a, b).distance_to(c) < spread + rayon:
				ch.pertes = maxf(float(ch.get("pertes", 0.0)), 0.6)
				n += 1
				break
	if n > 0:
		_news("Crue : %d champ%s sous l'eau, la récolte est en grande partie perdue." % [n, "s" if n > 1 else ""], "crue")


# --- Neige sur les routes ------------------------------------------------------------------------

func _routes() -> Array:
	var out := []
	if transport == null:
		return out
	for eid in transport.network.edges:
		var e: Dictionary = transport.network.edges[eid]
		if TransportTypes.mode_of(String(e.t)) == TransportTypes.Mode.ROAD:
			out.append(eid)
	return out


## La neige tombe (cm), fond ou reste selon la température ; le sel l'empêche de tenir.
func _neige_routes(cm: float, temp: float, t: float) -> void:
	if not neige_active():
		if not neige.is_empty():
			neige.clear()
			_mesh_dirty = true
		return
	var te := minf(temp, 0.0) if t < _froid_fin else temp
	var fonte := FONTE_CM_H * maxf(te - 0.5, 0.0)
	if cm <= 0.0 and fonte <= 0.0 and neige.is_empty():
		return
	var avant := neige.size()
	for eid in _routes():
		var v := float(neige.get(eid, 0.0))
		var sale := float(sel.get(eid, 0.0)) > t and te > -8.0
		if cm > 0.0 and not sale:
			v += cm
		v -= fonte
		if sale:
			v -= 0.5
		if v > 0.05:
			neige[eid] = snappedf(v, 0.01)
		elif neige.has(eid):
			neige.erase(eid)
	for eid in sel.keys():
		if float(sel[eid]) <= t:
			sel.erase(eid)
	if cm > 0.0 or fonte > 0.0 or neige.size() != avant:
		_mesh_dirty = true


## Neige sur un tronçon (cm).
func neige_de(eid: int) -> float:
	return float(neige.get(eid, 0.0))


## Moyenne de neige sur les routes (cm) et part des routes enneigées (≥ 1,5 cm).
func etat_routes() -> Dictionary:
	var routes := _routes()
	if routes.is_empty():
		return {"moyenne": 0.0, "part": 0.0, "km": 0.0, "km_neige": 0.0, "km_sel": 0.0}
	var total := 0.0
	var long := 0.0
	var long_neige := 0.0
	var long_sel := 0.0
	var t := now()
	for eid in routes:
		var l := float(transport.network.edges[eid].len)
		long += l
		total += neige_de(eid) * l
		if neige_de(eid) >= SEUIL_CM:
			long_neige += l
		if float(sel.get(eid, 0.0)) > t:
			long_sel += l
	return {"moyenne": total / maxf(long, 1.0), "part": long_neige / maxf(long, 1.0), "km": long / 1000.0,
		"km_neige": long_neige / 1000.0, "km_sel": long_sel / 1000.0}


## Facteur de vitesse de la circulation (Traffic.speed_factors).
func _facteur_vitesse(eid: int, v: Dictionary) -> float:
	if neige.is_empty():
		return 1.0
	var cm := float(neige.get(eid, 0.0))
	if cm < 0.5 or int(v.get("delivery", -1)) >= TAG:
		return 1.0
	return clampf(1.0 - 0.08 * cm, 0.3, 1.0)


static func facteur_neige(cm: float) -> float:
	return 1.0 if cm < 0.5 else clampf(1.0 - 0.08 * cm, 0.3, 1.0)


## Sur la neige, les voitures glissent : un accident de temps en temps.
func _accidents(t: float) -> void:
	if neige.is_empty() or not catastrophes_on() or evenements == null:
		return
	if t - _dernier_accident < 6.0 * 3600.0:
		return
	var glissant := []
	for eid in neige:
		if float(neige[eid]) >= 2.0 and transport.network.edges.has(eid):
			glissant.append(eid)
	if glissant.is_empty():
		return
	var part := float(glissant.size()) / maxf(float(_routes().size()), 1.0)
	if _rng.randf() < 0.12 * part * frequence():
		accident(glissant[_rng.randi() % glissant.size()])


## Accident sur un tronçon enneigé ; renvoie l'id de l'incident.
func accident(eid: int) -> int:
	if evenements == null or not transport.network.edges.has(eid):
		return -1
	_dernier_accident = now()
	var e: Dictionary = transport.network.edges[eid]
	var p := transport.network.point_at(eid, float(e.len) * 0.5)
	var id := evenements.declarer({"type": "accident", "position": p, "batiment": -1, "gravite": 1,
		"besoin": ["police", "ambulance"], "texte": "Accident sur la neige", "role": "neige"})
	totaux.accidents = int(totaux.accidents) + 1
	var txt := ["Accident sur la chaussée enneigée : une voiture dans le fossé, le conducteur s'en tire avec une grosse frayeur.",
		"Carambolage sur la neige : trois voitures et un livreur de pizzas, aucun blessé grave (la pizza est perdue).",
		"Sortie de route sur le verglas : les secours sont en route."]
	_news(txt[_rng.randi() % txt.size()], "neige", p)
	return id


func _jour_de_neige(j: int) -> void:
	if _jour_neige_annonce == j or neige.is_empty():
		return
	var et := etat_routes()
	if float(et.moyenne) < 8.0:
		return
	_jour_neige_annonce = j
	var txt := "Jour de neige : %s cm sur les routes. Bus en retard, bonshommes de neige dans les cours d'école." % _num(float(et.moyenne))
	if centres.is_empty():
		txt += " Sans chasse-neige, la ville est paralysée (Construire → Services publics → Centre technique)."
	_news(txt, "neige")


# --- Centres techniques et chasse-neige ----------------------------------------------------------

func _sync_centres() -> void:
	if buildings == null:
		return
	for bid in buildings.buildings:
		var b: Dictionary = buildings.buildings[bid]
		var s := SaisonsTypes.spec_of(String(b.t))
		if String(s.get("role", "")) != "deneigement":
			continue
		if not centres.has(bid):
			var engins := []
			for i in int(s.get("engins", 2)):
				engins.append(0)
			centres[bid] = {"sel": float(s.get("sel_t", 150.0)) * 0.5, "engins": engins}
	for bid in centres.keys():
		if not buildings.buildings.has(bid):
			for mid in (centres[bid].engins as Array):
				if int(mid) > 0:
					_fin_tournee(int(mid))
			centres.erase(bid)


func stations_meteo() -> int:
	var n := 0
	if buildings == null:
		return 0
	for bid in buildings.buildings:
		if SaisonsTypes.role_of(String(buildings.buildings[bid].t)) == "meteo" and not buildings.en_chantier(bid):
			n += 1
	return n


func sel_max(bid: int) -> float:
	if buildings == null or not buildings.buildings.has(bid):
		return 150.0
	return float(SaisonsTypes.spec_of(String(buildings.buildings[bid].t)).get("sel_t", 150.0))


func _pos(bid: int) -> Vector3:
	if evenements != null:
		return evenements.building_pos(bid)
	if buildings != null and buildings.buildings.has(bid):
		return BuildingSystem.rect_center(buildings._rect_of(buildings.buildings[bid]))
	return Vector3.ZERO


## Point d'accès routier d'un bâtiment : {e, s, a, b, len, pos}.
func acces(bid: int) -> Dictionary:
	if _acces.has(bid):
		return _acces[bid]
	var out := {}
	if transport != null and buildings != null and buildings.buildings.has(bid):
		var b: Dictionary = buildings.buildings[bid]
		var door := BuildingSystem.door_point(String(b.t), buildings._rect_of(b), int(b.r), float(b.get("a", 0.0)))
		var best := INF
		for eid in transport.edges_near(door, 60.0):
			var e: Dictionary = transport.network.edges[eid]
			if TransportTypes.mode_of(e.t) != TransportTypes.Mode.ROAD:
				continue
			var hit: Dictionary = transport.network.nearest_on_edge(eid, door)
			if float(hit.dist) < best:
				best = float(hit.dist)
				out = {"e": int(eid), "s": float(hit.get("s", 0.0)), "a": int(e.a), "b": int(e.b), "len": float(e.len), "pos": hit.pos}
	if not out.is_empty():
		_acces[bid] = out
	return out


func engins_sortis() -> int:
	return missions.size()


func engins_total() -> int:
	var n := 0
	for bid in centres:
		n += (centres[bid].engins as Array).size()
	return n


## Envoie les engins libres sur les routes enneigées.
func _dispatch(t: float) -> void:
	if neige.is_empty() or centres.is_empty():
		return
	for bid in centres:
		if buildings.en_chantier(bid):
			continue
		var c: Dictionary = centres[bid]
		var eng: Array = c.engins
		for i in eng.size():
			if int(eng[i]) > 0:
				continue
			var mid := _plan_tournee(int(bid), t)
			if mid <= 0:
				break
			eng[i] = mid


func _reserves() -> Dictionary:
	var out := {}
	for mid in missions:
		for p in missions[mid].parcours:
			if not bool(p.fait):
				out[int(p.e)] = true
	return out


## Prévoit une tournée : les tronçons enneigés autour du centre, grands axes d'abord.
func _plan_tournee(bid: int, t: float) -> int:
	var dep := _pos(bid)
	var pris := _reserves()
	var net := transport.network
	var cands := []
	for eid in neige:
		if float(neige[eid]) < SEUIL_CM or pris.has(eid) or not net.edges.has(eid):
			continue
		var e: Dictionary = net.edges[eid]
		var mid := net.point_at(eid, float(e.len) * 0.5)
		if mid.distance_to(dep) > RAYON:
			continue
		cands.append([int(eid), mid, maxf(TransportTypes.speed_of(String(e.t)), 20.0) / 30.0, float(e.len)])
	if cands.is_empty():
		return 0
	var parcours := []
	var pos := dep
	var tt := t + 300.0
	var m := 0.0
	while not cands.is_empty() and m < TOURNEE_M and parcours.size() < TOURNEE_MAX:
		var bi := 0
		var bd := INF
		for i in cands.size():
			# Les grands axes passent avant : la distance compte moins pour eux.
			var dd := (cands[i][1] as Vector3).distance_to(pos) / float(cands[i][2])
			if dd < bd:
				bd = dd
				bi = i
		var c: Array = cands[bi]
		cands.remove_at(bi)
		tt += (c[1] as Vector3).distance_to(pos) / VITESSE_TRAJET + float(c[3]) / VITESSE_LAME
		parcours.append({"e": int(c[0]), "t": tt, "fait": false, "m": float(c[3])})
		m += float(c[3])
		pos = c[1]
	var mid_id := next_mission
	next_mission += 1
	missions[mid_id] = {"id": mid_id, "centre": bid, "parcours": parcours, "t0": t,
		"t_end": tt + pos.distance_to(dep) / VITESSE_TRAJET, "m": m}
	_spawn_visual(mid_id)
	return mid_id


func _avance_tournees(t: float) -> void:
	for mid in missions.keys():
		var ms: Dictionary = missions[mid]
		for p in ms.parcours:
			if not bool(p.fait) and float(p.t) <= t:
				p.fait = true
				_deneige(int(ms.centre), int(p.e), float(p.m), t)
		if float(ms.t_end) <= t:
			_fin_tournee(int(mid))


## Un tronçon déneigé (et salé s'il reste du sel).
func _deneige(centre: int, eid: int, longueur: float, t: float) -> void:
	if neige.has(eid):
		neige.erase(eid)
		_mesh_dirty = true
	totaux.km_deneiges = float(totaux.km_deneiges) + longueur / 1000.0
	if not centres.has(centre):
		return
	var c: Dictionary = centres[centre]
	var besoin := SEL_T_KM * longueur / 1000.0
	if float(c.sel) >= besoin:
		c.sel = float(c.sel) - besoin
		totaux.sel_t = float(totaux.sel_t) + besoin
		sel[eid] = t + SEL_H * 3600.0


func _fin_tournee(mid: int) -> void:
	if not missions.has(mid):
		return
	var ms: Dictionary = missions[mid]
	if centres.has(int(ms.centre)):
		var eng: Array = centres[int(ms.centre)].engins
		for i in eng.size():
			if int(eng[i]) == mid:
				eng[i] = 0
	_drop_visual(mid)
	missions.erase(mid)


## Une fois par jour : le dôme de sel est rempli quand il est à moitié vide.
func _achat_sel() -> void:
	for bid in centres:
		var c: Dictionary = centres[bid]
		var cap := sel_max(int(bid))
		if float(c.sel) >= cap * 0.5:
			continue
		var t := cap - float(c.sel)
		var cout := roundi(t * PRIX_SEL_T)
		if buildings.unlimited_money or buildings.money >= cout:
			if not buildings.unlimited_money:
				buildings.money -= cout
			c.sel = cap
			message.emit("Sel de déneigement livré au centre technique : %s t (%s)." % [_num(t), BuildingSystem.format_money(cout)])
		else:
			message.emit("Pas assez d'argent pour racheter du sel (%s) : les chasse-neige déneigent sans saler." % BuildingSystem.format_money(cout))


func _traffic() -> Traffic:
	if transport == null or transport.traffic == null or not transport.traffic.enabled:
		return null
	return transport.traffic


func _spawn_visual(mid: int) -> void:
	var tr := _traffic()
	if tr == null:
		return
	var n := 0
	for v in tr.vehicles:
		if int(v.get("delivery", -1)) >= TAG:
			n += 1
	if n >= MAX_VISIBLE:
		return
	var ms: Dictionary = missions[mid]
	var p := acces(int(ms.centre))
	if p.is_empty():
		return
	var start := int(p.a) if float(p.s) <= float(p.len) * 0.5 else int(p.b)
	var halts := []
	for q in ms.parcours:
		var e: Dictionary = transport.network.edges.get(int(q.e), {})
		if e.is_empty():
			continue
		halts.append({"e": int(q.e), "s": float(e.len) * 0.5})
	halts.append({"e": int(p.e), "s": float(p.s)})
	tr.add_delivery_vehicle(TAG + mid, "chasse_neige", start, halts)


func _drop_visual(mid: int) -> void:
	var tr := _traffic()
	if tr == null:
		return
	for i in range(tr.vehicles.size() - 1, -1, -1):
		var v: Dictionary = tr.vehicles[i]
		if int(v.get("delivery", -1)) == TAG + mid:
			tr._free_vehicle(v)
			tr.vehicles.remove_at(i)


## Neige blanche sur les routes non déneigées.
func _rebuild_mesh() -> void:
	_mesh_dirty = false
	if neige.is_empty() or transport == null:
		_mesh.mesh = null
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 0
	for eid in neige:
		var cm := float(neige[eid])
		if cm < 0.3 or not transport.network.edges.has(eid):
			continue
		var e: Dictionary = transport.network.edges[eid]
		var pts: PackedVector3Array = e.pts
		if pts.size() < 2:
			continue
		var hw := float(e.get("width", 6.0)) * 0.5 * 0.95
		var col := Color(0.97, 0.98, 1.0, clampf(0.35 + cm / 6.0, 0.35, 0.96))
		var lift := 0.05 + minf(cm, 20.0) * 0.004
		for i in pts.size() - 1:
			var a := pts[i]
			var b := pts[i + 1]
			var dir := b - a
			dir.y = 0.0
			if dir.length_squared() < 1e-6:
				continue
			var side := Vector3(-dir.z, 0, dir.x).normalized() * hw
			var up := Vector3(0, lift, 0)
			var a0 := a - side + up
			var a1 := a + side + up
			var b0 := b - side + up
			var b1 := b + side + up
			st.set_color(col)
			st.set_normal(Vector3.UP)
			st.add_vertex(a0)
			st.add_vertex(b0)
			st.add_vertex(a1)
			st.add_vertex(a1)
			st.add_vertex(b0)
			st.add_vertex(b1)
			n += 1
	_mesh.mesh = st.commit() if n > 0 else null


# --- Prévisions ------------------------------------------------------------------------------------

## Jours de prévisions : 3, ou 7 avec une station météo.
func jours_previsions() -> int:
	return 7 if stations_meteo() > 0 else 3


## Prévisions des n prochains jours : [{j, nom, tmin, tmax, pluie (mm), neige (cm), ciel, icone}].
func previsions(n := -1) -> Array:
	if n < 0:
		n = jours_previsions()
	var out := []
	var w := meteo()
	var hum := w.humidity if w != null else 0.5
	var alt := w._altitude if w != null else 0.0
	var la := lat()
	var lo := lon()
	var off := _utc() * 3600.0
	var t0 := now()
	var j0 := int(date_locale(t0).j)
	const JOURS := ["dim.", "lun.", "mar.", "mer.", "jeu.", "ven.", "sam."]
	for k in n:
		var debut := float(j0 + 1 + k) * 86400.0 - off
		var tmin := 100.0
		var tmax := -100.0
		var pluie := 0.0
		var cm := 0.0
		var cov := 0.0
		var orage := 0.0
		for h in range(0, 24, 2):
			var u := debut + h * 3600.0
			var temp := Meteo.air_temperature(la, u, float(h), alt)
			var nat := Meteo.natural(u, la, lo, hum, temp, float(h))
			tmin = minf(tmin, temp)
			tmax = maxf(tmax, temp)
			cov += float(nat[0]) / 12.0
			var pr := float(nat[1])
			if temp < 1.5:
				cm += pr * (1.0 - smoothstep(0.0, 2.0, temp)) * NEIGE_CM_H * 2.0
			pluie += pr * MM_H * 2.0
			orage = maxf(orage, float(nat[3]))
		var ciel := "Ensoleillé"
		var icone := "soleil"
		if cm >= 1.0:
			ciel = "Neige"
			icone = "neige"
		elif orage > 0.5:
			ciel = "Orages"
			icone = "tempete"
		elif pluie >= 3.0:
			ciel = "Pluie"
			icone = "pluie"
		elif cov > 0.6:
			ciel = "Couvert"
			icone = "nuage"
		elif cov > 0.3:
			ciel = "Éclaircies"
			icone = "nuage"
		var dt := Time.get_datetime_dict_from_unix_time(int(debut + off))
		out.append({"j": j0 + 1 + k, "nom": "%s %d/%d" % [JOURS[int(dt.weekday)], int(dt.day), int(dt.month)],
			"tmin": tmin, "tmax": tmax, "pluie": pluie, "neige": cm, "ciel": ciel, "icone": icone})
	return out


# --- Calendrier des cultures -----------------------------------------------------------------------

## Pour chaque culture qui pousse ici : mois de semis et de récolte (mois locaux, 1 à 12).
func calendrier() -> Array:
	var out := []
	var c := climat()
	var la := lat()
	for id in AgriDonnees.ORDRE_CULTURES:
		var cu := AgriDonnees.culture(id)
		if cu.is_empty() or not AgriDonnees.convient(id, c) or bool(cu.get("paturage", false)):
			continue
		var semis: Array[int] = []
		var recolte: Array[int] = []
		for m in cu.semis:
			var ml := int(m) if la >= 0.0 else (int(m) + 5) % 12 + 1
			semis.append(ml)
			if bool(cu.get("permanente", false)):
				continue
			var r := (ml - 1 + roundi(float(cu.cycle) / 30.4)) % 12 + 1
			if not recolte.has(r):
				recolte.append(r)
		if bool(cu.get("permanente", false)):
			# Fauches : de la fin du printemps à la fin de l'été.
			for m in [6, 7, 9]:
				recolte.append(m if la >= 0.0 else (m + 5) % 12 + 1)
		out.append({"id": id, "nom": String(cu.name), "semis": semis, "recolte": recolte, "couleur": cu.get("couleur", Color.WHITE)})
	return out


# --- Avis et budget --------------------------------------------------------------------------------

func avis_facteurs() -> Array:
	return [{"id": "neige_rues", "theme": "transports", "f": _avis_neige},
		{"id": "secheresse", "theme": "reseaux", "f": _avis_secheresse, "ville": true},
		{"id": "canicule", "theme": "environnement", "f": _avis_canicule, "ville": true}]


func _avis_neige(p: Dictionary) -> Array:
	if (neige.is_empty() and sel.is_empty()) or population == null:
		return [0.0, []]
	var home := population.home_of(p)
	if home < 0:
		return [0.0, []]
	var a := acces(home)
	if a.is_empty():
		return [0.0, []]
	var cm := neige_de(int(a.e))
	if cm >= 5.0:
		return [-4.0, ["− Ma rue est sous la neige, personne n'est passé"]]
	if cm >= 2.0:
		return [-2.0, ["− Ma rue n'est pas déneigée"]]
	if float(sel.get(int(a.e), 0.0)) > now():
		return [1.0, ["+ Ma rue a été déneigée et salée"]]
	return [0.0, []]


func _avis_secheresse() -> Array:
	match niveau_secheresse:
		2: return [-1.5, ["− Arrêté sécheresse : interdit d'arroser le jardin"]]
		3: return [-3.0, ["− Sécheresse : restrictions d'eau et pelouses grillées"]]
		4: return [-5.0, ["− Crise de l'eau : seulement les usages essentiels"]]
	return [0.0, []]


func _avis_canicule() -> Array:
	if canicule:
		return [-2.0, ["− Canicule : on étouffe la nuit"]]
	return [0.0, []]


func budget_entretien() -> Dictionary:
	if centres.is_empty():
		return {}
	var c := 0.0
	for bid in centres:
		c += float(BuildingCatalog.cost(String(buildings.buildings[bid].t))) * ENTRETIEN if buildings.buildings.has(bid) else 0.0
		c += COUT_ENGIN * (centres[bid].engins as Array).size()
	return {"Déneigement (engins et centre technique)": c}


var _money_frac := 0.0


func _pay_day() -> void:
	if buildings == null or buildings.unlimited_money or _budget_present():
		return
	var net := 0.0
	var e := budget_entretien()
	for k in e:
		net -= float(e[k])
	_money_frac += net / 30.0
	var whole := int(_money_frac)
	if whole != 0:
		buildings.money += whole
		_money_frac -= whole


func _budget_present() -> bool:
	if not is_inside_tree():
		return false
	for n in get_tree().get_nodes_in_group("budget"):
		return true
	return get_tree().root.find_child("Budget", true, false) != null


# --- Déclencher à la main (bac à sable) -----------------------------------------------------------

## Chute de neige à la main : `cm` cm tout de suite sur les routes, puis la
## météo passe à la neige pendant `heures` heures ; il fait froid 36 h (la
## neige tient le temps de voir passer les chasse-neige).
func chute_de_neige(cm := 5.0, heures := 3.0) -> void:
	if not neige_active():
		message.emit("La neige sur les routes est coupée (Admin, F10 → Événements).")
		return
	var t := now()
	for eid in _routes():
		if float(sel.get(eid, 0.0)) > t:
			continue
		neige[eid] = float(neige.get(eid, 0.0)) + cm
	if world != null:
		world.neige = maxf(world.neige, clampf(cm / 10.0, 0.4, 1.0))
	if aujourdhui.is_empty():
		aujourdhui = {"j": int(date_locale(t).j), "pluie": 0.0, "neige": 0.0, "tmin": 0.0, "tmax": 0.0}
	aujourdhui.neige = float(aujourdhui.neige) + cm
	_froid_fin = t + (heures + 36.0) * 3600.0
	var w := meteo()
	if w != null and heures > 0.0:
		if _neige_fin <= 0.0:
			_mode_avant = int(w.mode)
		w.mode = Meteo.Mode.NEIGE
		_neige_fin = t + heures * 3600.0
	_mesh_dirty = true
	_news("Chute de neige : %s cm sur la ville, et ça continue. %s" % [_num(cm), "Les chasse-neige sont sur le pied de guerre." if not centres.is_empty()
		else "Pas un seul chasse-neige en ville : bon courage."], "neige")
	_dispatch(t)
	changed.emit()


## Fin de la chute de neige provoquée : la météo revient comme avant.
func _fin_neige_forcee(t: float) -> void:
	if _neige_fin <= 0.0 or t < _neige_fin:
		return
	_neige_fin = 0.0
	var w := meteo()
	if w != null and w.mode == Meteo.Mode.NEIGE:
		w.mode = (_mode_avant if _mode_avant >= 0 else Meteo.Mode.AUTO) as Meteo.Mode


## Passe la sécheresse au niveau voulu (1 à 4).
func forcer_secheresse(niveau: int) -> void:
	var voulus := [0.0, 9.0, 13.0, 25.0, 36.0]
	var jours_voulus: float = voulus[clampi(niveau, 0, 4)]
	var r := _reseaux()
	if r != null:
		r.incidents.forcer_secheresse(jours_voulus)
	jours_secs = jours_voulus
	if jours.is_empty():
		jours.append({"j": int(date_locale(now()).j) - 1, "pluie": 0.0, "neige": 0.0, "tmin": 18.0, "tmax": 31.0})
	_secheresse()
	changed.emit()


func forcer_canicule() -> void:
	jours_chauds = 3
	if not canicule:
		canicule = true
		_news("Canicule : 35 °C à l'ombre trois jours de suite. Le plan canicule est déclenché, les glaciers font fortune.", "canicule")
	changed.emit()


# --- Petits outils ---------------------------------------------------------------------------------

func _news(texte: String, genre: String, pos := Vector3.INF, ev := -1) -> void:
	if evenements != null:
		evenements.news(texte, pos, genre, ev)
	message.emit(texte)


static func _num(x: float) -> String:
	if absf(x) >= 10.0:
		return str(roundi(x))
	return str(snappedf(x, 0.1)).replace(".", ",")


static func _deg(x: float) -> String:
	return "%s °C" % str(roundi(x))


# --- Sauvegarde ------------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var ng := {}
	for eid in neige:
		ng[str(eid)] = snappedf(float(neige[eid]), 0.1)
	var sl := {}
	for eid in sel:
		sl[str(eid)] = float(sel[eid])
	var ct := {}
	for bid in centres:
		ct[str(bid)] = snappedf(float(centres[bid].sel), 0.1)
	return {"version": 1, "jours": jours.slice(maxi(0, jours.size() - 120)), "aujourdhui": aujourdhui, "records": records,
		"saison": saison, "neige": ng, "sel": sl, "centres": ct, "jours_secs": jours_secs, "niveau_secheresse": niveau_secheresse,
		"canicule": canicule, "jours_chauds": jours_chauds, "indice_crue": indice_crue, "vigilance_crue": vigilance_crue,
		"totaux": totaux, "restr_auto": _restr_auto, "neige_sol": _neige_sol_hier}


func from_dict(d: Dictionary) -> void:
	clear()
	if d.is_empty():
		_sync_centres()
		return
	for j in d.get("jours", []):
		jours.append({"j": int(j.j), "pluie": float(j.pluie), "neige": float(j.neige), "tmin": float(j.tmin), "tmax": float(j.tmax)})
	var a: Dictionary = d.get("aujourdhui", {})
	if not a.is_empty():
		aujourdhui = {"j": int(a.j), "pluie": float(a.pluie), "neige": float(a.neige), "tmin": float(a.tmin), "tmax": float(a.tmax)}
	for k in (d.get("records", {}) as Dictionary):
		records[k] = d.records[k]
	saison = int(d.get("saison", -1))
	for k in (d.get("neige", {}) as Dictionary):
		neige[int(k)] = float(d.neige[k])
	for k in (d.get("sel", {}) as Dictionary):
		sel[int(k)] = float(d.sel[k])
	jours_secs = float(d.get("jours_secs", 0.0))
	niveau_secheresse = int(d.get("niveau_secheresse", 0))
	canicule = bool(d.get("canicule", false))
	jours_chauds = int(d.get("jours_chauds", 0))
	indice_crue = float(d.get("indice_crue", 0.0))
	vigilance_crue = int(d.get("vigilance_crue", 0))
	_restr_auto = bool(d.get("restr_auto", false))
	_neige_sol_hier = float(d.get("neige_sol", 0.0))
	for k in (d.get("totaux", {}) as Dictionary):
		totaux[k] = d.totaux[k]
	_sync_centres()
	for k in (d.get("centres", {}) as Dictionary):
		if centres.has(int(k)):
			centres[int(k)].sel = float(d.centres[k])
	_mesh_dirty = true
	changed.emit()
