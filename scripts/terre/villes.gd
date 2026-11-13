class_name Villes
extends RefCounted
## Recherche des villes du monde pour choisir le lieu de départ (globe).
##
## Index : assets/villes_monde.tsv.gz (135 000 villes de 1 000 habitants et plus,
## GeoNames, CC BY 4.0), fabriqué par tools/build_villes.py. Une ligne :
##   nom \t clé (minuscules sans accents) \t pays \t région \t population \t lat \t lon
## Les noms de GeoNames sont souvent anglais (London, Vienna) : ALIAS donne les
## noms français des grandes villes. Les accents sont ignorés (« zurich » trouve
## Zürich). Des coordonnées (« 46.2044, 6.1432 ») marchent aussi.

const FICHIER := "res://assets/villes_monde.tsv.gz"
const FICHIER_PAYS := "res://assets/pays.json"

## Noms français -> [nom GeoNames, pays].
const ALIAS := {
	"londres": ["London", "GB"], "pekin": ["Beijing", "CN"], "moscou": ["Moscow", "RU"], "vienne autriche": ["Vienna", "AT"],
	"varsovie": ["Warsaw", "PL"], "bucarest": ["Bucharest", "RO"], "copenhague": ["Copenhagen", "DK"],
	"bruxelles": ["Brussels", "BE"], "anvers": ["Antwerpen", "BE"], "gand": ["Gent", "BE"], "bruges": ["Brugge", "BE"],
	"cologne": ["Köln", "DE"], "munich": ["Munich", "DE"], "aix-la-chapelle": ["Aachen", "DE"], "nuremberg": ["Nürnberg", "DE"],
	"francfort": ["Frankfurt am Main", "DE"], "hambourg": ["Hamburg", "DE"], "breme": ["Bremen", "DE"], "dresde": ["Dresden", "DE"],
	"bale": ["Basel", "CH"], "berne": ["Bern", "CH"], "lucerne": ["Luzern", "CH"], "coire": ["Chur", "CH"],
	"soleure": ["Solothurn", "CH"], "saint-gall": ["St. Gallen", "CH"], "schaffhouse": ["Schaffhausen", "CH"], "bienne": ["Biel/Bienne", "CH"],
	"zoug": ["Zug", "CH"], "thoune": ["Thun", "CH"], "sion": ["Sion", "CH"],
	"geneve": ["Genève", "CH"], "zurich": ["Zürich", "CH"],
	"rome": ["Rome", "IT"], "milan": ["Milan", "IT"], "naples": ["Naples", "IT"], "turin": ["Turin", "IT"], "genes": ["Genoa", "IT"],
	"venise": ["Venice", "IT"], "florence": ["Florence", "IT"], "sienne": ["Siena", "IT"], "padoue": ["Padova", "IT"],
	"seville": ["Sevilla", "ES"], "saragosse": ["Zaragoza", "ES"], "barcelone": ["Barcelona", "ES"], "valence espagne": ["Valencia", "ES"],
	"lisbonne": ["Lisbon", "PT"], "porto": ["Porto", "PT"], "athenes": ["Athens", "GR"], "thessalonique": ["Thessaloniki", "GR"],
	"prague": ["Prague", "CZ"], "cracovie": ["Kraków", "PL"], "belgrade": ["Belgrade", "RS"], "kiev": ["Kyiv", "UA"],
	"saint-petersbourg": ["Saint Petersburg", "RU"], "edimbourg": ["Edinburgh", "GB"], "douvres": ["Dover", "GB"],
	"la haye": ["The Hague", "NL"], "le caire": ["Cairo", "EG"], "alexandrie": ["Alexandria", "EG"], "alger": ["Algiers", "DZ"],
	"tanger": ["Tangier", "MA"], "marrakech": ["Marrakesh", "MA"], "fes": ["Fès", "MA"], "le cap": ["Cape Town", "ZA"],
	"addis-abeba": ["Addis Ababa", "ET"], "mexico": ["Mexico City", "MX"], "la havane": ["Havana", "CU"],
	"new york": ["New York City", "US"], "la nouvelle-orleans": ["New Orleans", "US"], "philadelphie": ["Philadelphia", "US"],
	"bombay": ["Mumbai", "IN"], "calcutta": ["Kolkata", "IN"], "new delhi": ["New Delhi", "IN"], "nouvelle-delhi": ["New Delhi", "IN"],
	"seoul": ["Seoul", "KR"], "canton": ["Guangzhou", "CN"], "nankin": ["Nanjing", "CN"], "taipei": ["Taipei", "TW"],
	"singapour": ["Singapore", "SG"], "hanoi": ["Hanoi", "VN"], "jerusalem": ["Jerusalem", "IL"], "beyrouth": ["Beirut", "LB"],
	"damas": ["Damascus", "SY"], "bagdad": ["Baghdad", "IQ"], "teheran": ["Tehran", "IR"], "la mecque": ["Mecca", "SA"],
	"riyad": ["Riyadh", "SA"], "dubai": ["Dubai", "AE"], "ankara": ["Ankara", "TR"], "smyrne": ["İzmir", "TR"],
	"tbilissi": ["Tbilisi", "GE"], "erevan": ["Yerevan", "AM"], "achgabat": ["Ashgabat", "TM"],
}

static var _noms := PackedStringArray()
static var _cles := PackedStringArray()
static var _pays := PackedStringArray()
static var _regions := PackedStringArray()
static var _pops := PackedInt32Array()
static var _lats := PackedFloat32Array()
static var _lons := PackedFloat32Array()
static var _noms_pays := {}
static var _charge := false


## Charge l'index (une fois). Faux si le fichier manque.
static func charger() -> bool:
	if _charge:
		return not _noms.is_empty()
	_charge = true
	if FileAccess.file_exists(FICHIER_PAYS):
		var p = JSON.parse_string(FileAccess.get_file_as_string(FICHIER_PAYS))
		if p is Dictionary:
			_noms_pays = p
	var raw := FileAccess.get_file_as_bytes(FICHIER)
	if raw.is_empty():
		push_warning("Index des villes introuvable : " + FICHIER)
		return false
	var txt := raw.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP).get_string_from_utf8()
	for line in txt.split("\n", false):
		var f := line.split("\t")
		if f.size() < 7:
			continue
		_noms.append(f[0])
		_cles.append(f[1])
		_pays.append(f[2].to_lower())
		_regions.append(f[3])
		_pops.append(int(f[4]))
		_lats.append(float(f[5]))
		_lons.append(float(f[6]))
	return not _noms.is_empty()


static func nombre() -> int:
	charger()
	return _noms.size()


## Nom français d'un pays (code ISO en minuscules), ou le code.
static func nom_pays(code: String) -> String:
	charger()
	return String(_noms_pays.get(code.to_lower(), code.to_upper()))


## Minuscules sans accents (comme la clé de l'index).
static func cle(t: String) -> String:
	const DE := "àáâãäåāăąçćčďđèéêëēėęěìíîïīıłñńňòóôõöøōőŕřśšşșťţțùúûüūůűųýÿźżž"
	const EN := "aaaaaaaaacccddeeeeeeeeiiiiiillnnnooooooooorrssssttttuuuuuuuuyyzzz"
	var s := t.to_lower().strip_edges().replace("ß", "ss").replace("œ", "oe").replace("æ", "ae")
	var out := ""
	for ch in s:
		var i := DE.find(ch)
		out += EN[i] if i >= 0 else ch
	return out


static func _entree(i: int) -> Dictionary:
	return {"nom": _noms[i], "pays": _pays[i], "pays_nom": nom_pays(_pays[i]), "region": _regions[i],
		"pop": _pops[i], "lat": _lats[i], "lon": _lons[i]}


## Texte d'une ligne de résultat : « Annecy · France · 49 232 hab. ».
static func libelle(e: Dictionary) -> String:
	var s := "%s · %s" % [e.nom, e.get("pays_nom", "")]
	if int(e.get("pop", 0)) > 0:
		s += " · %s hab." % BuildingSystem.format_money(int(e.pop)).replace(" €", "")
	return s


## Villes qui correspondent à la recherche, les plus peuplées d'abord : d'abord
## celles dont le nom commence par le texte, puis celles qui le contiennent.
static func chercher(texte: String, n := 30) -> Array:
	var q := cle(texte)
	if q.length() < 2 or not charger():
		return []
	var out := []
	var vus := {}
	# Noms français des grandes villes.
	for a in ALIAS:
		if String(a).begins_with(q) or (q.length() >= 4 and String(a).contains(q)):
			var al: Array = ALIAS[a]
			var j := _trouver(String(al[0]), String(al[1]).to_lower())
			if j >= 0 and not vus.has(j):
				vus[j] = true
				out.append(_entree(j))
	var debut := []
	var mot := []
	var dedans := []
	for i in _cles.size():
		var k := _cles[i]
		if k.begins_with(q):
			if debut.size() < n:
				debut.append(i)
			elif debut.size() >= n:
				break
		elif q.length() >= 3 and mot.size() < n and (k.contains(" " + q) or k.contains("-" + q)):
			mot.append(i)
		elif q.length() >= 4 and dedans.size() < n and k.contains(q):
			dedans.append(i)
	for liste in [debut, mot, dedans]:
		for i in liste:
			if out.size() >= n:
				return out
			if not vus.has(i):
				vus[i] = true
				out.append(_entree(int(i)))
	return out


static func _trouver(nom: String, pays: String) -> int:
	for i in _noms.size():
		if _noms[i] == nom and _pays[i] == pays:
			return i
	return -1


## Ville la plus proche d'un point (dans max_km), ou {}.
static func plus_proche(lat: float, lon: float, max_km := 40.0) -> Dictionary:
	if not charger():
		return {}
	var best := -1
	var best_d := INF
	var cl := cos(deg_to_rad(lat))
	for i in _lats.size():
		var dla := _lats[i] - lat
		if absf(dla) > 1.0:
			continue
		var dlo := wrapf(_lons[i] - lon, -180.0, 180.0) * cl
		var d := dla * dla + dlo * dlo
		if d < best_d:
			best_d = d
			best = i
	if best < 0 or sqrt(best_d) * 111.0 > max_km:
		return {}
	return _entree(best)
