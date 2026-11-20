class_name Regisseurs
extends Node
## Régisseurs de quartier (piste CityRT 9) : le maire confie un quartier à un
## habitant, avec un budget par mois et un caractère. Chaque semaine de jeu, le
## régisseur reçoit sa part du budget (payée par la caisse de la ville) et fait
## UNE chose dans son quartier, selon son caractère :
##   - il prend un arrêté de sa liste (Arretes), payé sur sa cagnotte ;
##   - sinon il fait poser du mobilier (DecorSystem) : bancs, arbres, jeux,
##     lampadaires… au prix des décors ;
##   - « Économe » rend une partie de la cagnotte à la ville.
## Ce qu'il fait passe dans le fil des habitants et le journal du quartier. Les
## habitants du quartier apprécient d'avoir un des leurs aux commandes (thème
## politique de l'Avis). Le maire reprend la main quand il veut : la cagnotte
## revient à la ville. Mairie perdue, déménagement ou décès : le régisseur s'en va.
## Sauvegardé dans la section « quartiers » (Quartiers.to_dict / from_dict).

signal action(qid: int, pid: int, texte: String)

## Caractères : nom, description, arrêtés voulus (dans l'ordre), décors posés, rendu de la cagnotte.
const CARACTERES := {
	"ecolo": {"nom": "Écolo", "desc": "Plante, fleurit, trie et calme la circulation.",
		"arretes": ["espaces_verts", "tri_obligatoire", "zone_30", "extinction_eclairage"],
		"decors": ["jardiniere", "jardin_partage", "banc_bois", "poubelles_tri"]},
	"prudent": {"nom": "Prudent", "desc": "Sécurité avant tout : détecteurs, lumière, calme la nuit.",
		"arretes": ["detecteurs_fumee", "eclairage_nuit", "calme_nuit", "poids_lourds"],
		"decors": ["lampadaire", "potelets", "barriere_metal", "borne_incendie"]},
	"bon_vivant": {"nom": "Bon vivant", "desc": "Des bancs, des jeux, des terrasses : la rue est à tout le monde.",
		"arretes": ["rue_pietonne", "zone_30"], "abroge": ["calme_nuit"],
		"decors": ["banc_vert", "table_pique_nique", "balancoire", "toboggan", "fontaine_wallace", "kiosque_musique"]},
	"econome": {"nom": "Économe", "desc": "Chaque euro compte : il économise et rend ce qui reste.",
		"arretes": ["extinction_eclairage", "stationnement_payant"], "abroge": ["eclairage_nuit", "espaces_verts"],
		"decors": ["poubelle", "banc_pierre"], "rend": 0.5},
}
const BUDGETS := [5_000, 15_000, 40_000]
const SEMAINE := 7
## Avis : les habitants du quartier aiment avoir un des leurs comme régisseur.
const AVIS_POLITIQUE := 2.0
const MAX_DECORS_SEMAINE := 4

var quartiers: Quartiers
var population: Population
var decors: DecorSystem
## qid -> {pid, car, budget, caisse, depuis, semaine, actions, dernier}
var regisseurs := {}
var _tick := 0.0
var _jour_vu := -1


func setup(q: Quartiers, p: Population, d: DecorSystem) -> void:
	quartiers = q
	population = p
	decors = d
	add_to_group("avis_sources")


func clear() -> void:
	regisseurs.clear()
	_jour_vu = -1


func _jour() -> int:
	return int(population.now().day) if population != null else 0


func de(qid: int) -> Dictionary:
	return regisseurs.get(qid, {})


static func caractere_de(pid: int) -> String:
	var ks := CARACTERES.keys()
	return String(ks[(pid * 2654435761) % ks.size()]) if pid >= 0 else String(ks[0])


static func nom_caractere(car: String) -> String:
	return String(CARACTERES.get(car, {}).get("nom", car))


## Quartier où habite un habitant (-1 s'il n'habite dans aucun).
func quartier_de(p: Dictionary) -> int:
	if population == null or quartiers == null:
		return -1
	var home := population.home_of(p)
	if home < 0 or not population.known.has(home):
		return -1
	var pos: Vector3 = population.known[home].pos
	return quartiers.quartier_au_point(pos.x, pos.z)


## Habitants qui pourraient être régisseurs : adultes du quartier (25 ans et plus),
## les plus âgés d'abord (ils connaissent le coin). [{pid, nom, age, car, qui}]
func candidats(qid: int, n := 3) -> Array:
	var out := []
	if population == null:
		return out
	var pris := {}
	for k in regisseurs:
		pris[int(regisseurs[k].pid)] = true
	var liste := []
	for id in population.persons:
		var p: Dictionary = population.persons[id]
		if pris.has(int(id)) or population.age_years(p) < 25:
			continue
		if quartier_de(p) != qid:
			continue
		liste.append(p)
		if liste.size() > 400:
			break
	liste.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return population.age_years(a) > population.age_years(b))
	# Un de chaque caractère si possible.
	var vus := {}
	for p in liste:
		var car := caractere_de(int(p.id))
		if vus.has(car) and vus.size() < CARACTERES.size():
			continue
		vus[car] = true
		out.append({"pid": int(p.id), "nom": CycleVie.full_name(p), "age": population.age_years(p), "car": car,
			"qui": population.stage_label(p)})
		if out.size() >= n:
			break
	return out


func raison_confier(qid: int, pid: int) -> String:
	if quartiers == null or not quartiers.quartiers.has(qid):
		return "Quartier inconnu."
	var vid := quartiers.ville_de(qid)
	if not quartiers.decide(vid):
		return "Tu n'es plus maire de %s : tu ne peux pas confier ce quartier." % quartiers.nom_ville(vid)
	if quartiers.ha(qid) <= 0.0:
		return "Peins d'abord le quartier sur la carte."
	if population == null or not population.persons.has(pid):
		return "Cet habitant n'est plus là."
	return ""


## Confie le quartier à un habitant, avec un budget par mois (€).
func confier(qid: int, pid: int, budget: int) -> String:
	var why := raison_confier(qid, pid)
	if why != "":
		return why
	if regisseurs.has(qid):
		reprendre(qid, false)
	var p: Dictionary = population.persons[pid]
	regisseurs[qid] = {"pid": pid, "car": caractere_de(pid), "budget": maxi(budget, 0), "caisse": 0, "depuis": _jour(),
		"semaine": _jour(), "actions": 0, "dernier": ""}
	var t := "%s devient régisseur%s du quartier %s (%s, %s par mois)." % [CycleVie.full_name(p), CycleVie.g(p, "", "e"),
		String(quartiers.quartiers[qid].nom), nom_caractere(caractere_de(pid)).to_lower(), BuildingSystem.format_money(budget)]
	quartiers._noter(quartiers.ville_de(qid), t)
	action.emit(qid, pid, t)
	quartiers.message.emit(t)
	quartiers.changed.emit()
	return ""


func changer_budget(qid: int, budget: int) -> void:
	if regisseurs.has(qid):
		regisseurs[qid].budget = maxi(budget, 0)
		quartiers.changed.emit()


## Le maire reprend la main : la cagnotte revient à la ville.
func reprendre(qid: int, annoncer := true) -> void:
	if not regisseurs.has(qid):
		return
	var r: Dictionary = regisseurs[qid]
	var vid := quartiers.ville_de(qid) if quartiers.quartiers.has(qid) else 0
	if int(r.caisse) > 0:
		quartiers._payer(vid, -int(r.caisse), "Régisseurs de quartier")
	regisseurs.erase(qid)
	if annoncer and quartiers.quartiers.has(qid):
		var t := "Le maire reprend la main sur %s ; la cagnotte (%s) revient à la ville." % [String(quartiers.quartiers[qid].nom),
			BuildingSystem.format_money(int(r.caisse))]
		quartiers._noter(vid, t)
		quartiers.message.emit(t)
	quartiers.changed.emit()


func _process(delta: float) -> void:
	_tick += delta
	if _tick < 2.0 or regisseurs.is_empty():
		return
	_tick = 0.0
	var j := _jour()
	if j == _jour_vu:
		return
	_jour_vu = j
	journee(j)


## Une journée de jeu : chaque régisseur dont la semaine est passée agit.
func journee(j: int) -> void:
	for qid in regisseurs.keys():
		var r: Dictionary = regisseurs[qid]
		if not _toujours_la(qid):
			continue
		if j - int(r.semaine) >= SEMAINE:
			r.semaine = j
			semaine(qid)


func _toujours_la(qid: int) -> bool:
	var r: Dictionary = regisseurs[qid]
	var raison := ""
	if not quartiers.quartiers.has(qid):
		regisseurs.erase(qid)
		return false
	if not population.persons.has(int(r.pid)):
		raison = "Le régisseur de %s n'est plus là : le maire reprend la main." % String(quartiers.quartiers[qid].nom)
	elif quartier_de(population.persons[int(r.pid)]) != qid:
		raison = "%s a quitté le quartier %s : le maire reprend la main." % [CycleVie.full_name(population.persons[int(r.pid)]),
			String(quartiers.quartiers[qid].nom)]
	elif not quartiers.decide(quartiers.ville_de(qid)):
		raison = "Nouvelle équipe à la mairie : le régisseur de %s rend son tablier." % String(quartiers.quartiers[qid].nom)
	if raison == "":
		return true
	reprendre(qid, false)
	quartiers._noter(quartiers.ville_de(qid), raison)
	quartiers.message.emit(raison)
	return false


## La semaine d'un régisseur : il touche sa part du budget, puis fait une chose.
## Renvoie ce qu'il a fait (texte), ou "".
func semaine(qid: int) -> String:
	var r: Dictionary = regisseurs[qid]
	var vid := quartiers.ville_de(qid)
	var part := roundi(float(r.budget) * SEMAINE / 30.44)
	if part > 0:
		quartiers._payer(vid, part, "Régisseurs de quartier")
		r.caisse = int(r.caisse) + part
	var car: Dictionary = CARACTERES.get(String(r.car), CARACTERES.ecolo)
	var t := _arrete(qid, r, car)
	if t == "":
		t = _decors(qid, r, car)
	if t == "" and float(car.get("rend", 0.0)) > 0.0 and int(r.caisse) > 0:
		var rendu := roundi(float(r.caisse) * float(car.rend))
		quartiers._payer(vid, -rendu, "Régisseurs de quartier")
		r.caisse = int(r.caisse) - rendu
		t = "rend %s à la ville : « rien d'utile à acheter cette semaine »" % BuildingSystem.format_money(rendu)
	if t == "":
		return ""
	r.actions = int(r.actions) + 1
	r.dernier = t
	var p: Dictionary = population.persons[int(r.pid)]
	var texte := "%s, régisseur%s du quartier %s : %s." % [CycleVie.full_name(p), CycleVie.g(p, "", "e"), String(quartiers.quartiers[qid].nom), t]
	quartiers._noter(vid, texte)
	action.emit(qid, int(r.pid), t)
	quartiers.changed.emit()
	return texte


func _arrete(qid: int, r: Dictionary, car: Dictionary) -> String:
	var h := quartiers.ha(qid)
	for aid in car.get("abroge", []):
		if quartiers.a_arrete(qid, String(aid)) and quartiers.abroger(qid, String(aid), true) == "":
			return "abroge « %s »" % Arretes.nom(String(aid))
	for aid in car.get("arretes", []):
		var a := String(aid)
		if quartiers.a_arrete(qid, a):
			continue
		var cout := Arretes.cout_pose(a, h)
		if int(r.caisse) < cout:
			continue
		# La ville avance le prix, la cagnotte du régisseur le lui rend aussitôt.
		var vid := quartiers.ville_de(qid)
		quartiers._payer(vid, -cout, "Régisseurs de quartier")
		if quartiers.adopter(qid, a, true) != "":
			quartiers._payer(vid, cout, "Régisseurs de quartier")
			continue
		r.caisse = int(r.caisse) - cout
		return "fait passer « %s » (%s)" % [Arretes.nom(a), BuildingSystem.format_money(cout)]
	return ""


func _decors(qid: int, r: Dictionary, car: Dictionary) -> String:
	if decors == null:
		return ""
	var ids := []
	for id in car.get("decors", []):
		if Decors.existe(String(id)) and EpoquesObjets.decor_disponible(String(id)):
			ids.append(String(id))
	var cases := quartiers.cases_de(qid)
	if ids.is_empty() or cases.is_empty():
		return ""
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([qid, int(r.semaine), int(r.pid)])
	# Au hasard parmi ce que la cagnotte peut payer (un kiosque attend qu'elle grossisse).
	var abordables := ids.filter(func(x: String) -> bool: return Decors.prix(x) <= int(r.caisse))
	if abordables.is_empty():
		return ""
	var id: String = abordables[rng.randi() % abordables.size()]
	var prix := Decors.prix(id)
	var n := 0
	var essais := 0
	while n < MAX_DECORS_SEMAINE and int(r.caisse) >= prix and essais < 40:
		essais += 1
		var k: Vector2i = cases[rng.randi() % cases.size()]
		var c := Quartiers.centre_case(k) + Vector2(rng.randf_range(-20.0, 20.0), rng.randf_range(-20.0, 20.0))
		if decors._bloque(Vector2i(floori(c.x), floori(c.y))) or not decors.decor_a(Vector3(c.x, 0.0, c.y), 2.0).is_empty():
			continue
		if decors.pose(id, c.x, c.y, rng.randf() * TAU):
			r.caisse = int(r.caisse) - prix
			n += 1
	if n == 0:
		return ""
	return "fait poser %d × %s (%s)" % [n, Decors.nom(id).to_lower(), BuildingSystem.format_money(prix * n)]


# --- Avis des habitants -----------------------------------------------------------------

func avis_facteurs() -> Array:
	return [{"id": "regisseur", "theme": "politique", "f": func(p: Dictionary) -> Array: return avis_politique(p)}]


func avis_politique(p: Dictionary) -> Array:
	if regisseurs.is_empty():
		return [0.0, []]
	var q := quartier_de(p)
	if q < 0 or not regisseurs.has(q):
		return [0.0, []]
	return [AVIS_POLITIQUE, ["+ un habitant du quartier en est le régisseur (%s)" % String(quartiers.quartiers[q].nom)]]


# --- Sauvegarde ---------------------------------------------------------------------------

func to_list() -> Array:
	var out := []
	for qid in regisseurs:
		var r: Dictionary = regisseurs[qid]
		out.append({"q": int(qid), "pid": int(r.pid), "car": String(r.car), "budget": int(r.budget), "caisse": int(r.caisse),
			"depuis": int(r.depuis), "semaine": int(r.semaine), "actions": int(r.actions), "dernier": String(r.dernier)})
	return out


func from_list(l: Array) -> void:
	regisseurs.clear()
	for e in l:
		if not (e is Dictionary) or not CARACTERES.has(String(e.get("car", ""))):
			continue
		regisseurs[int(e.q)] = {"pid": int(e.pid), "car": String(e.car), "budget": int(e.get("budget", 0)),
			"caisse": int(e.get("caisse", 0)), "depuis": int(e.get("depuis", 0)), "semaine": int(e.get("semaine", 0)),
			"actions": int(e.get("actions", 0)), "dernier": String(e.get("dernier", ""))}
