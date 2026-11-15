class_name CommerceMondial
extends Node
## Commerce entre villes et pays (menu Économie → Commerce, Maj+S).
##
## - Marché mondial : chaque marchandise a un cours qui bouge chaque jour (les
##   marchandises d'une même famille bougent ensemble), autour de son prix de
##   référence. Les exportations et importations se font au cours du jour ; les
##   échanges sur la carte et les prix en rayon suivent le cours à moitié
##   (Ressources.cours_facteurs, prix_export, prix_import, prix_interieur).
## - Crises économiques : choc pétrolier, krach, sécheresse… elles montent,
##   durent, puis redescendent (MarcheTypes.CRISES). Réglages Admin : crises
##   oui ou non, marché calme, normal ou agité.
## - Villes partenaires : de vraies villes voisines du lieu de la partie (index
##   des villes du monde). Elles proposent des accords : t par jour d'une
##   marchandise, à prix fixe, pendant 30 à 180 jours.
##     · exportation : les camions de la ville portent la marchandise à la
##       frontière en priorité ; ce qui manque chaque jour coûte une pénalité ;
##     · importation : prix fixe (à l'abri des crises) et passage garanti
##       même quand la frontière est pleine.
##   Honorer ses accords améliore la relation (meilleurs prix, plus d'offres) ;
##   une mission commerciale (25 000 €) la relance.
## - Accords entre tes villes (et, sur une carte entre amis, avec les villes des
##   autres joueurs, qui doivent accepter) : la ville qui achète se fournit
##   d'abord chez la ville qui vend, au prix convenu.
## - Libre-échange entre deux de tes pays : plus de douane entre eux.
## Tout se décide par des appels (Multijoueur.APPELS « commerce ») : sur une
## carte entre amis, le serveur les vérifie et tous les rejouent. Le marché,
## les crises et les offres viennent d'une graine gardée dans la partie : tous
## les jeux voient les mêmes cours.

signal changed
signal message(text: String)
## Nouvelle pour le fil d'actualité (crises, accords).
signal actualite(text: String)

static var instance: CommerceMondial

var production: Production
var buildings: BuildingSystem
var pays: Pays

## Graine du marché (gardée dans la partie).
var graine := 0
## Dernier jour de jeu traité (-1 : pas encore commencé).
var jour := -1
## Écarts (logarithmes) des familles et des marchandises par rapport au prix de référence.
var x_fam := {}
var x_bien := {}
## Cours des derniers jours : marchandise → [facteur, …] (le plus récent à la fin).
var historique := {}
## Crise en cours : {id, debut, duree} ou {}.
var crise := {}
var crises_passees: Array = []
## Jours sans crise possible.
var repit := 45
## Villes partenaires : id → {nom, pays, pop, km, relation, vend, achete, mission}.
var partenaires := {}
## Offres des partenaires : [{id, partenaire, sens, g, t, prix, duree, expire}].
var offres: Array = []
## Accords en cours : id → accord (voir _nouvel_accord).
var accords := {}
var next_accord := 1
## Propositions entre villes de joueurs différents (carte entre amis).
var propositions: Array = []
## Paires de pays en libre-échange : ["a|b", …] (a < b).
var libre_echange: Array = []
## Accords terminés ou rompus (les plus récents d'abord).
var archives: Array = []
## Comptes des accords par ville : {"mois": {k: {export, import, villes, penalites}}, "precedent": …, "jours"}.
var bilan := {"mois": {}, "precedent": {}, "jours": 0}

## Index : marchandise → ids des accords actifs (rapide pendant la logistique).
var _idx := {}
var _idx_ok := false


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null
	Ressources.marche_neutre()


func setup(prod: Production, bs: BuildingSystem, p: Pays) -> void:
	production = prod
	buildings = bs
	pays = p
	if production != null:
		production.marche = self
		production.day_passed.connect(_on_day)


func clear() -> void:
	graine = randi()
	jour = -1
	x_fam = {}
	x_bien = {}
	historique = {}
	crise = {}
	crises_passees = []
	repit = 45
	partenaires = {}
	offres = []
	accords = {}
	next_accord = 1
	propositions = []
	libre_echange = []
	archives = []
	bilan = {"mois": {}, "precedent": {}, "jours": 0}
	_idx_ok = false
	Ressources.marche_neutre()


func _process(_delta: float) -> void:
	if jour < 0 and production != null and production.last_day >= 0:
		_initialiser(production.last_day)


## Le marché démarre : partenaires, 30 jours de cours passés pour les courbes.
func _initialiser(d: int) -> void:
	if graine == 0:
		graine = randi()
	x_fam = {}
	x_bien = {}
	historique = {}
	for i in 30:
		jour = d - 30 + i
		_marche_jour()
	jour = d
	_init_partenaires()
	_offres_jour()
	_appliquer()
	changed.emit()


func _on_day() -> void:
	if production == null:
		return
	var d := production.last_day
	if jour < 0:
		_initialiser(d)
		return
	var n := 0
	while jour < d and n < 10:
		jour += 1
		n += 1
		_jour()
	if jour < d:
		jour = d
	changed.emit()


## Une journée du marché : cours, crises, accords, offres.
func _jour() -> void:
	_marche_jour()
	_crise_jour()
	_appliquer()
	_accords_jour()
	_offres_jour()
	bilan.jours = int(bilan.jours) + 1
	if int(bilan.jours) >= 30:
		bilan.precedent = bilan.mois
		bilan.mois = {}
		bilan.jours = 0


func _rng(cle: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash("%d|%d|%s" % [graine, jour, cle])
	return r


# --- Cours --------------------------------------------------------------------------------

func _marche_jour() -> void:
	var vol := ReglagesPartie.actuel.volatilite_marche
	var r := _rng("marche")
	for f in MarcheTypes.FAMILLES:
		var fam: Dictionary = MarcheTypes.FAMILLES[f]
		var x := float(x_fam.get(f, 0.0)) * (1.0 - MarcheTypes.RAPPEL_FAMILLE) + r.randfn(0.0, float(fam.vol) * 0.75 * vol)
		x_fam[f] = clampf(x, -0.6, 0.6)
		for g in fam.biens:
			var xb := float(x_bien.get(g, 0.0)) * (1.0 - MarcheTypes.RAPPEL_BIEN) + r.randfn(0.0, float(fam.vol) * 0.5 * vol)
			x_bien[g] = clampf(xb, -0.4, 0.4)
	for g in MarcheTypes.biens():
		var h: Array = historique.get(g, [])
		h.append(snappedf(facteur(g), 0.001))
		while h.size() > MarcheTypes.HISTORIQUE:
			h.pop_front()
		historique[g] = h


## Cours d'une marchandise par rapport à son prix de référence, sans les crises.
func facteur_marche(g: String) -> float:
	var f := MarcheTypes.famille_de(g)
	return exp(float(x_fam.get(f, 0.0)) + float(x_bien.get(g, 0.0)))


## Cours d'une marchandise par rapport à son prix de référence (marché et crise).
func facteur(g: String) -> float:
	return clampf(facteur_marche(g) * facteur_crise(g), MarcheTypes.COURS_MIN, MarcheTypes.COURS_MAX)


func intensite_crise() -> float:
	if crise.is_empty():
		return 0.0
	return MarcheTypes.intensite(jour - int(crise.debut), int(crise.duree))


func facteur_crise(g: String) -> float:
	if crise.is_empty():
		return 1.0
	return 1.0 + (MarcheTypes.effet_crise(String(crise.id), g) - 1.0) * intensite_crise()


func _effet_global(cle: String) -> float:
	if crise.is_empty():
		return 1.0
	var c: Dictionary = MarcheTypes.CRISES.get(String(crise.id), {})
	return 1.0 + (float(c.get(cle, 1.0)) - 1.0) * intensite_crise()


## Donne les cours du jour aux prix du jeu (Ressources).
func _appliquer() -> void:
	var fs := {}
	for g in MarcheTypes.biens():
		fs[g] = facteur(g)
	Ressources.cours_facteurs = fs
	Ressources.facteur_export = _effet_global("export")
	Ressources.facteur_import = _effet_global("import")
	Ressources.facteur_capacite = _effet_global("capacite")


## Variation du cours sur n jours (0,12 = +12 %).
func variation(g: String, n := 30) -> float:
	var h: Array = historique.get(g, [])
	if h.size() < 2:
		return 0.0
	var a := float(h[maxi(0, h.size() - 1 - n)])
	return float(h[h.size() - 1]) / maxf(a, 0.001) - 1.0


# --- Crises -------------------------------------------------------------------------------

func _crise_jour() -> void:
	if not crise.is_empty():
		if jour - int(crise.debut) >= int(crise.duree):
			var c: Dictionary = MarcheTypes.CRISES.get(String(crise.id), {})
			crises_passees.push_front({"id": crise.id, "debut": crise.debut, "duree": crise.duree})
			while crises_passees.size() > 12:
				crises_passees.pop_back()
			crise = {}
			repit = MarcheTypes.REPIT
			_annoncer(String(c.get("fin", "La crise est terminée.")))
		return
	if not ReglagesPartie.actuel.crises_economiques:
		return
	if repit > 0:
		repit -= 1
		return
	var r := _rng("crise")
	if r.randf() < MarcheTypes.CHANCE_JOUR * ReglagesPartie.actuel.frequence_catastrophes:
		var ids: Array = MarcheTypes.CRISES.keys()
		if not crises_passees.is_empty():
			ids.erase(String(crises_passees[0].id))
		declencher_crise(String(ids[r.randi() % ids.size()]), -1, r)


## Lance une crise (duree -1 : tirée au sort dans sa fourchette).
func declencher_crise(id: String, duree := -1, r: RandomNumberGenerator = null) -> void:
	var c: Dictionary = MarcheTypes.CRISES.get(id, {})
	if c.is_empty():
		return
	if r == null:
		r = _rng("crise:" + id)
	if duree <= 0:
		duree = r.randi_range(int(c.duree[0]), int(c.duree[1]))
	crise = {"id": id, "debut": jour, "duree": duree}
	_appliquer()
	_annoncer(String(c.texte))
	changed.emit()


func nom_crise() -> String:
	if crise.is_empty():
		return ""
	return String(MarcheTypes.CRISES.get(String(crise.id), {}).get("nom", ""))


func jours_crise_restants() -> int:
	if crise.is_empty():
		return 0
	return maxi(0, int(crise.debut) + int(crise.duree) - jour)


func _annoncer(t: String) -> void:
	message.emit(t)
	actualite.emit(t)


# --- Villes partenaires et offres --------------------------------------------------------

func _init_partenaires() -> void:
	if not partenaires.is_empty():
		return
	var liste := Villes.voisines(GameStart.lat, GameStart.lon, 15.0, 250.0, MarcheTypes.PARTENAIRES)
	if liste.is_empty():
		var code := GameStart.pays if GameStart.pays != "" else "fr"
		for i in 4:
			liste.append({"nom": ["Port-Marchand", "Bourg-les-Champs", "Grandville", "Mont-Usine"][i], "pays": code,
				"pop": [180_000, 12_000, 450_000, 40_000][i], "km": [60.0, 25.0, 140.0, 80.0][i]})
	var pid := 1
	for e in liste:
		var r := RandomNumberGenerator.new()
		r.seed = hash("%d|partenaire|%s" % [graine, String(e.nom)])
		var pop := int(e.get("pop", 10000))
		var achete_f: Array
		var vend_f: Array
		if pop >= 200_000:
			achete_f = ["alimentaire", "manufacture", "construction", "energie", "agricole"]
			vend_f = ["manufacture", "chimie", "metaux"]
		elif pop >= 30_000:
			achete_f = ["construction", "alimentaire", "agricole", "metaux"]
			vend_f = ["chimie", "alimentaire", "construction", "manufacture"]
		else:
			achete_f = ["manufacture", "energie", "alimentaire", "chimie"]
			vend_f = ["agricole", "construction", "alimentaire"]
		partenaires[pid] = {"nom": String(e.nom), "pays": String(e.get("pays", "")), "pop": pop, "km": float(e.get("km", 50.0)),
			"relation": 50.0, "achete": _tirer(r, achete_f, 5), "vend": _tirer(r, vend_f, 4), "mission": -999}
		pid += 1


static func _tirer(r: RandomNumberGenerator, familles: Array, n: int) -> Array:
	var pool: Array = []
	for f in familles:
		for g in MarcheTypes.FAMILLES[f].biens:
			if Ressources.MARCHANDISES.has(g) and not g in ["fumier", "balles_tri"]:
				pool.append(g)
	var out: Array = []
	while out.size() < n and not pool.is_empty():
		var i := r.randi() % pool.size()
		out.append(pool[i])
		pool.remove_at(i)
	return out


## Marchandises que tes entreprises produisent (pour les offres d'achat des partenaires).
func biens_produits() -> Array:
	var out := {}
	if production == null:
		return []
	for bid in production.sites:
		if String(production.sites[bid].kind) in ["extraction", "transformation", "elevage"]:
			for g in production.outputs_of(bid):
				if MarcheTypes.famille_de(String(g)) != "":
					out[String(g)] = true
	var ks: Array = out.keys()
	ks.sort()
	return ks


func _offres_jour() -> void:
	offres = offres.filter(func(o: Dictionary) -> bool: return int(o.expire) >= jour)
	if partenaires.is_empty():
		return
	var produits := biens_produits()
	for pid in partenaires:
		if offres.size() >= 12:
			break
		var p: Dictionary = partenaires[pid]
		if float(p.relation) < 20.0:
			continue
		var r := _rng("offre:%d" % int(pid))
		if r.randf() < 0.12 + float(p.relation) / 1000.0:
			offres.append(_nouvelle_offre(int(pid), r, produits))


func _nouvelle_offre(pid: int, r: RandomNumberGenerator, produits: Array) -> Dictionary:
	var p: Dictionary = partenaires[pid]
	var export := r.randf() < 0.55
	var g := ""
	if export:
		if not produits.is_empty() and r.randf() < 0.65:
			g = String(produits[r.randi() % produits.size()])
		else:
			g = String(p.achete[r.randi() % (p.achete as Array).size()])
	else:
		g = String(p.vend[r.randi() % (p.vend as Array).size()])
	var taille := clampf(1.0 + log(maxf(float(p.pop), 1000.0) / 20000.0) / log(10.0), 0.5, 2.0)
	var valeur := r.randf_range(3000.0, 18000.0) * taille
	var t := valeur / maxf(Ressources.cours(g), 1.0)
	t = roundf(t) if t >= 10.0 else maxf(snappedf(t, 0.1), 0.1)
	var bonus := (float(p.relation) - 50.0) / 400.0
	var prix := 0.0
	if export:
		prix = Ressources.prix_export(g) * (1.08 + bonus + r.randf_range(0.0, 0.12))
	else:
		prix = Ressources.prix_import(g) * (0.92 - bonus - r.randf_range(0.0, 0.08))
	var duree := int(MarcheTypes.DUREES[r.randi() % MarcheTypes.DUREES.size()])
	return {"id": "o%d-%d-%d" % [jour, pid, r.randi() % 1000], "partenaire": pid, "sens": "export" if export else "import",
		"g": g, "t": t, "prix": snappedf(prix, 0.01), "duree": duree, "expire": jour + MarcheTypes.VALIDITE_OFFRE}


func nom_partenaire(pid: int) -> String:
	var p: Dictionary = partenaires.get(pid, {})
	if p.is_empty():
		return "?"
	var code := String(p.pays)
	return "%s (%s)" % [p.nom, Villes.nom_pays(code)] if code != "" else String(p.nom)


func relation_texte(v: float) -> String:
	if v >= 80.0:
		return "Excellente"
	if v >= 60.0:
		return "Bonne"
	if v >= 40.0:
		return "Correcte"
	if v >= 20.0:
		return "Tendue"
	return "Fâchée"


func _relation(pid: int, dv: float) -> void:
	if partenaires.has(pid):
		partenaires[pid].relation = clampf(float(partenaires[pid].relation) + dv, 0.0, 100.0)


# --- Décisions (appels, vérifiés par le serveur en multijoueur) -------------------------

## Signe une offre d'une ville partenaire pour la ville vid. Renvoie "" ou la raison du refus.
func signer(offre: Dictionary, vid: int) -> String:
	var id := String(offre.get("id", ""))
	var i := -1
	for j in offres.size():
		if String(offres[j].id) == id:
			i = j
	if i >= 0:
		offre = offres[i]
		offres.remove_at(i)
	elif int(offre.get("expire", -1)) < jour or not partenaires.has(int(offre.get("partenaire", -1))):
		return _refus("Cette offre n'est plus valable.")
	var a := _nouvel_accord("ia", String(offre.g), float(offre.t), float(offre.prix), int(offre.duree))
	a.sens = String(offre.sens)
	a.partenaire = int(offre.partenaire)
	a.ville = vid
	accords[int(a.id)] = a
	_idx_ok = false
	var sens_txt := "vendre à" if a.sens == "export" else "acheter à"
	_annoncer("%s signe un accord pour %s %s %s par jour de %s pendant %d jours." % [
		_nom_ville(vid), sens_txt, nom_partenaire(int(a.partenaire)), Ressources.format_t(float(a.t)), Ressources.good_name(String(a.g)).to_lower(), int(a.duree)])
	changed.emit()
	return ""


## Accord entre deux villes de la carte. immediat : le même joueur décide des deux
## (sinon une proposition attend l'accord du maire de l'autre ville).
func proposer(vendeur: int, acheteur: int, g: String, t: float, prix: float, duree: int, auteur: int, immediat := true) -> String:
	if vendeur == acheteur:
		return _refus("Choisis deux villes différentes.")
	if not Ressources.MARCHANDISES.has(g) or t <= 0.0 or prix < 0.0 or duree <= 0:
		return _refus("Accord incomplet.")
	if immediat:
		_creer_accord_villes(vendeur, acheteur, g, t, prix, duree)
		return ""
	var autre := acheteur if auteur == vendeur else vendeur
	propositions.append({"id": "p%d-%d" % [jour, propositions.size() + next_accord], "vendeur": vendeur, "acheteur": acheteur, "g": g,
		"t": t, "prix": prix, "duree": duree, "auteur": auteur, "pour": autre, "expire": jour + MarcheTypes.VALIDITE_OFFRE})
	message.emit("Proposition envoyée à %s : elle attend l'accord de son maire." % _nom_ville(autre))
	changed.emit()
	return ""


func accepter(pid: String) -> String:
	for i in propositions.size():
		var p: Dictionary = propositions[i]
		if String(p.id) == pid:
			propositions.remove_at(i)
			_creer_accord_villes(int(p.vendeur), int(p.acheteur), String(p.g), float(p.t), float(p.prix), int(p.duree))
			return ""
	return _refus("Cette proposition n'existe plus.")


func refuser(pid: String) -> String:
	for i in propositions.size():
		if String(propositions[i].id) == pid:
			var p: Dictionary = propositions[i]
			propositions.remove_at(i)
			message.emit("%s refuse l'accord proposé par %s." % [_nom_ville(int(p.pour)), _nom_ville(int(p.auteur))])
			changed.emit()
			return ""
	return _refus("Cette proposition n'existe plus.")


func _creer_accord_villes(vendeur: int, acheteur: int, g: String, t: float, prix: float, duree: int) -> void:
	var a := _nouvel_accord("villes", g, t, prix, duree)
	a.vendeur = vendeur
	a.acheteur = acheteur
	accords[int(a.id)] = a
	_idx_ok = false
	_annoncer("Accord signé : %s fournit à %s %s par jour de %s, à %s la tonne, pendant %d jours." % [
		_nom_ville(vendeur), _nom_ville(acheteur), Ressources.format_t(t), Ressources.good_name(g).to_lower(), _euros(prix), duree])
	changed.emit()


func _nouvel_accord(genre: String, g: String, t: float, prix: float, duree: int) -> Dictionary:
	var a := {"id": next_accord, "genre": genre, "g": g, "t": t, "prix": prix, "duree": duree, "debut": jour, "fin": jour + duree,
		"jour_t": 0.0, "livre": 0.0, "manque": 0.0, "valeur": 0.0, "penalites": 0.0, "retards": 0}
	next_accord += 1
	return a


## Rompt un accord avant sa fin : pénalité de 10 % de ce qui restait, payée par
## la ville qui rompt (vid ; -1 : la ville de l'accord).
func resilier(aid: int, vid := -1) -> String:
	if not accords.has(aid):
		return _refus("Cet accord n'existe plus.")
	var a: Dictionary = accords[aid]
	var reste := maxf(float(int(a.fin) - jour), 0.0) * float(a.t) * float(a.prix)
	var pen := reste * MarcheTypes.PENALITE_RUPTURE
	var qui := vid
	if String(a.genre) == "ia":
		qui = int(a.ville)
		_relation(int(a.partenaire), -15.0)
		_payer(qui, -pen, "Rupture d'un accord commercial")
	else:
		if qui != int(a.vendeur) and qui != int(a.acheteur):
			qui = int(a.vendeur)
		var autre := int(a.acheteur) if qui == int(a.vendeur) else int(a.vendeur)
		_virer(qui, autre, pen, "Rupture d'un accord commercial")
	a.penalites = float(a.penalites) + pen
	_noter(qui, "penalites", pen)
	_archiver(a, "rompu")
	message.emit("Accord rompu : %s paie %s de pénalité." % [_nom_ville(qui), _euros(pen)])
	changed.emit()
	return ""


## Mission commerciale chez un partenaire : la relation remonte et deux offres arrivent.
func mission_commerciale(pid: int, vid: int) -> String:
	if not partenaires.has(pid):
		return _refus("Partenaire inconnu.")
	var p: Dictionary = partenaires[pid]
	if jour - int(p.mission) < MarcheTypes.MISSION_ATTENTE:
		return _refus("Une mission vient de partir chez %s : attends quelques jours." % p.nom)
	var cout := ReglagesPartie.prix(MarcheTypes.MISSION_COUT)
	if not _illimite() and _solde(vid) < cout:
		return _refus("Pas assez d'argent dans la caisse de %s pour la mission (%s)." % [_nom_ville(vid), _euros(cout)])
	_payer(vid, -cout, "Mission commerciale")
	p.mission = jour
	_relation(pid, MarcheTypes.MISSION_RELATION)
	var r := _rng("mission:%d" % pid)
	var produits := biens_produits()
	for i in 2:
		offres.append(_nouvelle_offre(pid, r, produits))
	_annoncer("Mission commerciale à %s : petits fours, poignées de main et deux nouvelles offres." % p.nom)
	changed.emit()
	return ""


func set_libre_echange(na: int, nb: int, on: bool) -> String:
	if na == nb:
		return _refus("Choisis deux pays différents.")
	var k := _paire(na, nb)
	if on and not k in libre_echange:
		libre_echange.append(k)
		_annoncer("Accord de libre-échange entre %s et %s : plus de douane entre eux." % [_nom_ville(na), _nom_ville(nb)])
	elif not on and k in libre_echange:
		libre_echange.erase(k)
		_annoncer("Fin du libre-échange entre %s et %s : la douane revient." % [_nom_ville(na), _nom_ville(nb)])
	changed.emit()
	return ""


func libre_echange_entre(na: int, nb: int) -> bool:
	return na != nb and _paire(na, nb) in libre_echange


static func _paire(a: int, b: int) -> String:
	return "%d|%d" % [mini(a, b), maxi(a, b)]


func _refus(t: String) -> String:
	message.emit(t)
	return t


# --- Chaque jour : accords ---------------------------------------------------------------

func _accords_jour() -> void:
	for aid in accords.keys():
		var a: Dictionary = accords[aid]
		var fait := float(a.jour_t)
		a.jour_t = 0.0
		var oblige := String(a.genre) == "villes" or String(a.sens) == "export"
		if oblige and jour - int(a.debut) > MarcheTypes.GRACE:
			var manque := float(a.t) - fait
			if manque > float(a.t) * 0.1:
				var pen := manque * float(a.prix) * MarcheTypes.PENALITE_MANQUE
				a.manque = float(a.manque) + manque
				a.penalites = float(a.penalites) + pen
				a.retards = int(a.retards) + 1
				if String(a.genre) == "ia":
					_payer(int(a.ville), -pen, "Pénalités des accords commerciaux")
					_noter(int(a.ville), "penalites", pen)
					_relation(int(a.partenaire), -1.5)
				else:
					_virer(int(a.vendeur), int(a.acheteur), pen, "Pénalités des accords commerciaux")
					_noter(int(a.vendeur), "penalites", pen)
				if int(a.retards) == 3:
					message.emit("L'accord de %s sur %s n'est pas honoré : il manque %s par jour. Il faut du stock, des chauffeurs-livreurs et une route vers %s." % [
						_nom_ville(int(a.get("ville", a.get("vendeur", 0)))), Ressources.good_name(String(a.g)).to_lower(), Ressources.format_t(manque),
						"la frontière" if String(a.genre) == "ia" else _nom_ville(int(a.acheteur))])
			elif String(a.genre) == "ia":
				a.retards = 0
				_relation(int(a.partenaire), 0.5)
		elif String(a.genre) == "ia" and fait > 0.0:
			_relation(int(a.partenaire), 0.2)
		if jour >= int(a.fin):
			_archiver(a, "termine")
			var avec := nom_partenaire(int(a.partenaire)) if String(a.genre) == "ia" else _nom_ville(int(a.acheteur))
			message.emit("Accord terminé avec %s : %s de %s échangées pour %s." % [avec, Ressources.format_t(float(a.livre)),
				Ressources.good_name(String(a.g)).to_lower(), _euros(float(a.valeur))])
	propositions = propositions.filter(func(p: Dictionary) -> bool: return int(p.expire) >= jour)


func _archiver(a: Dictionary, fin: String) -> void:
	accords.erase(int(a.id))
	_idx_ok = false
	var c := a.duplicate()
	c.etat = fin
	c.jour_fin = jour
	archives.push_front(c)
	while archives.size() > 20:
		archives.pop_back()


# --- Pendant la logistique (Production) ---------------------------------------------------

func _index() -> void:
	if _idx_ok:
		return
	_idx = {}
	for aid in accords:
		var g := String(accords[aid].g)
		if not _idx.has(g):
			_idx[g] = []
		(_idx[g] as Array).append(int(aid))
	_idx_ok = true


func _actifs(g: String) -> Array:
	_index()
	return _idx.get(g, [])


func _ville_du_batiment(bid: int) -> int:
	if pays != null and pays.a_des_villes():
		return pays.payeur_du_batiment(bid)
	return Pays.PAYS


func _reste(a: Dictionary) -> float:
	return float(a.t) - float(a.jour_t)


## Accord d'exportation de la ville du site bid pour g, avec du reste aujourd'hui : {id, reste} ou {}.
func accord_export(bid: int, g: String) -> Dictionary:
	var ids := _actifs(g)
	if ids.is_empty():
		return {}
	var v := -2
	for aid in ids:
		var a: Dictionary = accords[aid]
		if String(a.genre) != "ia" or String(a.sens) != "export" or _reste(a) <= 0.05:
			continue
		if v == -2:
			v = _ville_du_batiment(bid)
		if int(a.ville) == v:
			return {"id": int(aid), "reste": _reste(a)}
	return {}


func reserver(aid: int, q: float) -> void:
	if accords.has(aid):
		accords[aid].jour_t = float(accords[aid].jour_t) + q


## Ce que touche une entreprise qui exporte q t de g (au prix de l'accord s'il y en a un).
func vente_export(from: int, g: String, q: float, aid := -1) -> float:
	if aid >= 0 and accords.has(aid) and String(accords[aid].g) == g:
		var a: Dictionary = accords[aid]
		var v := q * float(a.prix)
		a.livre = float(a.livre) + q
		a.valeur = float(a.valeur) + v
		_noter(int(a.ville), "export", v)
		return v
	return q * Ressources.prix_export(g)


func _accord_import(to: int, g: String) -> Dictionary:
	var ids := _actifs(g)
	if ids.is_empty():
		return {}
	var v := -2
	for aid in ids:
		var a: Dictionary = accords[aid]
		if String(a.genre) != "ia" or String(a.sens) != "import" or _reste(a) <= 0.001:
			continue
		if v == -2:
			v = _ville_du_batiment(to)
		if int(a.ville) == v:
			return a
	return {}


func import_garanti(to: int, g: String) -> bool:
	return not _accord_import(to, g).is_empty()


func import_restant(to: int, g: String) -> float:
	var a := _accord_import(to, g)
	return 0.0 if a.is_empty() else _reste(a)


## Ce que paie une entreprise pour q t de g importées.
func achat_import(to: int, g: String, q: float) -> float:
	var a := _accord_import(to, g)
	if a.is_empty():
		return q * Ressources.prix_import(g)
	var qa := minf(q, _reste(a))
	var v := qa * float(a.prix)
	a.jour_t = float(a.jour_t) + qa
	a.livre = float(a.livre) + qa
	a.valeur = float(a.valeur) + v
	_noter(int(a.ville), "import", v)
	return v + (q - qa) * Ressources.prix_import(g)


func _accord_villes(acheteur: int, g: String, vendeur := -999) -> Dictionary:
	for aid in _actifs(g):
		var a: Dictionary = accords[aid]
		if String(a.genre) == "villes" and int(a.acheteur) == acheteur and _reste(a) > 0.001 and (vendeur == -999 or int(a.vendeur) == vendeur):
			return a
	return {}


## Ville chez qui le site to doit se fournir en g (accord entre villes), ou -1.
func vendeur_pour(to: int, g: String) -> int:
	if _actifs(g).is_empty():
		return -1
	var a := _accord_villes(_ville_du_batiment(to), g)
	return -1 if a.is_empty() else int(a.vendeur)


## Prix de q t de g vendues d'une entreprise à une autre sur la carte.
func vente_entre(from: int, to: int, g: String, q: float) -> float:
	if not _actifs(g).is_empty():
		var vf := _ville_du_batiment(from)
		var vt := _ville_du_batiment(to)
		if vf != vt:
			var a := _accord_villes(vt, g, vf)
			if not a.is_empty():
				var qa := minf(q, _reste(a))
				var v := qa * float(a.prix)
				a.jour_t = float(a.jour_t) + qa
				a.livre = float(a.livre) + qa
				a.valeur = float(a.valeur) + v
				_noter(vf, "villes", v)
				return v + (q - qa) * Ressources.prix_interieur(g)
	return q * Ressources.prix_interieur(g)


# --- Caisses --------------------------------------------------------------------------------

func _multi() -> bool:
	return pays != null and pays.a_des_villes()


func _illimite() -> bool:
	return buildings != null and buildings.unlimited_money


func _solde(k: int) -> int:
	if _multi():
		return pays.solde(k)
	return buildings.money if buildings != null else 0


func _payer(k: int, montant: float, poste: String) -> void:
	if _illimite() or absf(montant) < 0.5:
		return
	if _multi():
		pays.encaisser(k, montant, poste)
		pays.changed.emit()
	elif buildings != null:
		buildings.money += roundi(montant)
		BudgetCommunal.noter(poste, roundi(montant))


func _virer(de: int, a: int, montant: float, poste: String) -> void:
	if montant < 0.5:
		return
	if _multi():
		_payer(de, -montant, poste)
		_payer(a, montant, poste)


func _noter(k: int, cle: String, v: float) -> void:
	var m: Dictionary = bilan.mois
	var e: Dictionary = m.get(k, {})
	e[cle] = float(e.get(cle, 0.0)) + v
	m[k] = e


func _nom_ville(k: int) -> String:
	if _multi() or (pays != null and Pays.est_nation(k) and k != Pays.PAYS):
		return pays.nom_de(k)
	return "Ta ville"


static func _euros(x: float) -> String:
	return BuildingSystem.format_money(roundi(x))


## Comptes des accords d'une ville (mois dernier, ou en cours s'il n'y en a pas).
func bilan_ville(k: int) -> Dictionary:
	var src: Dictionary = bilan.precedent if not (bilan.precedent as Dictionary).is_empty() else bilan.mois
	var e: Dictionary = src.get(k, {})
	return {"export": float(e.get("export", 0.0)), "import": float(e.get("import", 0.0)), "villes": float(e.get("villes", 0.0)), "penalites": float(e.get("penalites", 0.0))}


## Accords en cours qui concernent la ville k.
func accords_de(k: int) -> Array:
	var out: Array = []
	for aid in accords:
		var a: Dictionary = accords[aid]
		if int(a.get("ville", -999)) == k or int(a.get("vendeur", -999)) == k or int(a.get("acheteur", -999)) == k:
			out.append(a)
	return out


# --- Sauvegarde -----------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var pa := {}
	for k in partenaires:
		pa[str(k)] = partenaires[k]
	var ac := {}
	for k in accords:
		ac[str(k)] = accords[k]
	var bm := {}
	var bp := {}
	for k in bilan.mois:
		bm[str(k)] = bilan.mois[k]
	for k in bilan.precedent:
		bp[str(k)] = bilan.precedent[k]
	return {"version": 1, "graine": graine, "jour": jour, "x_fam": x_fam.duplicate(), "x_bien": x_bien.duplicate(),
		"historique": historique.duplicate(true), "crise": crise.duplicate(), "crises_passees": crises_passees.duplicate(true),
		"repit": repit, "partenaires": pa.duplicate(true), "offres": offres.duplicate(true), "accords": ac.duplicate(true),
		"next_accord": next_accord, "propositions": propositions.duplicate(true), "libre_echange": libre_echange.duplicate(),
		"archives": archives.duplicate(true), "bilan": {"mois": bm, "precedent": bp, "jours": int(bilan.jours)}}


func from_dict(d: Dictionary) -> void:
	var g0 := graine
	clear()
	if d.is_empty():
		if g0 != 0:
			graine = g0
		return
	graine = int(d.get("graine", graine))
	jour = int(d.get("jour", -1))
	for k in d.get("x_fam", {}):
		x_fam[String(k)] = float(d.x_fam[k])
	for k in d.get("x_bien", {}):
		x_bien[String(k)] = float(d.x_bien[k])
	for k in d.get("historique", {}):
		var h: Array = []
		for v in d.historique[k]:
			h.append(float(v))
		historique[String(k)] = h
	var c: Dictionary = d.get("crise", {})
	if not c.is_empty() and MarcheTypes.CRISES.has(String(c.get("id", ""))):
		crise = {"id": String(c.id), "debut": int(c.debut), "duree": int(c.duree)}
	for x in d.get("crises_passees", []):
		crises_passees.append({"id": String(x.id), "debut": int(x.debut), "duree": int(x.duree)})
	repit = int(d.get("repit", 45))
	for k in d.get("partenaires", {}):
		var p: Dictionary = (d.partenaires[k] as Dictionary).duplicate(true)
		p.relation = float(p.get("relation", 50.0))
		p.pop = int(p.get("pop", 0))
		p.km = float(p.get("km", 0.0))
		p.mission = int(p.get("mission", -999))
		partenaires[int(k)] = p
	for o in d.get("offres", []):
		var oo: Dictionary = (o as Dictionary).duplicate()
		oo.partenaire = int(oo.partenaire)
		oo.duree = int(oo.duree)
		oo.expire = int(oo.expire)
		oo.t = float(oo.t)
		oo.prix = float(oo.prix)
		offres.append(oo)
	for k in d.get("accords", {}):
		accords[int(k)] = _lire_accord(d.accords[k])
	next_accord = int(d.get("next_accord", 1))
	for p in d.get("propositions", []):
		var pp: Dictionary = (p as Dictionary).duplicate()
		for key in ["vendeur", "acheteur", "duree", "auteur", "pour", "expire"]:
			pp[key] = int(pp.get(key, 0))
		pp.t = float(pp.t)
		pp.prix = float(pp.prix)
		propositions.append(pp)
	for x in d.get("libre_echange", []):
		libre_echange.append(String(x))
	for x in d.get("archives", []):
		archives.append(_lire_accord(x))
	var b: Dictionary = d.get("bilan", {})
	for part in ["mois", "precedent"]:
		for k in b.get(part, {}):
			bilan[part][int(k)] = (b[part][k] as Dictionary).duplicate()
	bilan.jours = int(b.get("jours", 0))
	_idx_ok = false
	if jour >= 0:
		_appliquer()


static func _lire_accord(x: Dictionary) -> Dictionary:
	var a := x.duplicate()
	for key in ["id", "duree", "debut", "fin", "retards", "partenaire", "ville", "vendeur", "acheteur", "jour_fin"]:
		if a.has(key):
			a[key] = int(a[key])
	for key in ["t", "prix", "jour_t", "livre", "manque", "valeur", "penalites"]:
		if a.has(key):
			a[key] = float(a[key])
	return a
