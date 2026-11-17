class_name CatalogueJeu
extends RefCounted
## Catalogue de tout ce qui se construit ou se pose dans le jeu, avec son année
## d'apparition et ses évolutions. Construit à partir des données du jeu
## (aucune liste à tenir à la main) : il sert au panneau « Catalogue » (Maj+F1, menu
## Infos) et à l'export docs/catalogue (tools/catalogue/export_catalogue.gd).
##
## Une entrée : {"fam", "groupe", "id", "nom", "annee", "source", "info", "evol"}, et
## "lignee" (identifiants de la même famille qui tiennent le même rôle, du plus
## ancien au plus récent) quand il y en a une.
## annee 0 = de tout temps (déjà là en 1800). source dit d'où vient l'année :
## "propre" (donnée par l'objet), "table" (tables d'Epoques), "ajoutee" (datée
## avec le catalogue, EpoquesObjets), "style" (style de la bible), "epoque"
## (époque de la bible : traditionnel, antique…), "mot" (un mot du nom),
## "devinee" (aucune : année par défaut).

const FAMILLES := [
	["batiments", "Bâtiments"],
	["vehicules", "Véhicules"],
	["voies", "Voies"],
	["stations", "Stations, gares et ports"],
	["reseaux", "Lignes et conduites"],
	["agriculture", "Agriculture"],
	["attractions", "Grands-huit et attractions"],
	["amenagements", "Aménagements de l'Atelier"],
	["ouvertures", "Portes et fenêtres"],
	["toits", "Toits"],
	["materiaux", "Matériaux"],
	["decors", "Décors"],
	["meubles", "Meubles"],
	["spectacles", "Objets de spectacle"],
]

const SOURCES := {
	"propre": "date propre", "table": "table des époques", "ajoutee": "datée avec le catalogue",
	"style": "style", "epoque": "époque de la bible", "mot": "mot du nom", "devinee": "devinée",
}

static var _cache: Array = []


static func nom_famille(id: String) -> String:
	for f in FAMILLES:
		if f[0] == id:
			return String(f[1])
	return id


static func texte_annee(y: int) -> String:
	return "toujours" if y <= 0 else str(y)


## Toutes les entrées (calculées une fois).
static func entrees(recalcule := false) -> Array:
	if recalcule or _cache.is_empty():
		_cache = []
		_batiments(_cache)
		_vehicules(_cache)
		_voies(_cache)
		_agriculture(_cache)
		_attractions(_cache)
		_atelier(_cache)
		_decors(_cache)
		_meubles(_cache)
	return _cache


static func de_famille(fam: String) -> Array:
	var out := []
	for e: Dictionary in entrees():
		if String(e.fam) == fam:
			out.append(e)
	return out


static func _e(fam: String, groupe: String, id: String, nom: String, annee: int, source: String, info := "", evol := "") -> Dictionary:
	return {"fam": fam, "groupe": groupe, "id": id, "nom": nom, "annee": maxi(0, annee), "source": source,
		"info": info, "evol": evol}


static func _lignee(membres: Array) -> String:
	membres.sort_custom(func(a: Array, b: Array) -> bool: return int(a[1]) < int(b[1]) or int(a[1]) == int(b[1]) and String(a[0]) < String(b[0]))
	var parts := []
	for m in membres:
		parts.append("%s (%s)" % [m[0], texte_annee(int(m[1]))])
	return " → ".join(parts)


## Identifiants d'une lignée [nom, année, id], du plus ancien au plus récent.
static func _ids_lignee(membres: Array) -> Array:
	var m := membres.duplicate()
	m.sort_custom(func(a: Array, b: Array) -> bool: return int(a[1]) < int(b[1]) or int(a[1]) == int(b[1]) and String(a[0]) < String(b[0]))
	var out := []
	for x in m:
		out.append(String(x[2]))
	return out


# --- Bâtiments -----------------------------------------------------------------------------

static func source_batiment(id: String) -> String:
	var t := BuildingCatalog.get_type(id)
	if t.has("annee"):
		return "propre"
	if Epoques.ANNEES.has(id):
		return "table"
	if EpoquesObjets.BATIMENTS.has(id):
		return "ajoutee"
	var st := String(t.get("style", ""))
	if st != "" and Epoques.STYLE_ANNEES.has(st):
		return "style"
	if st != "":
		return "epoque"
	var hay := (id + " " + String(t.get("name", ""))).to_lower()
	for regle in Epoques.MOTS_BATIMENTS:
		if hay.contains(String(regle[0])):
			return "mot"
	return "devinee"


static func _info_batiment(id: String, t: Dictionary) -> String:
	var parts := ["%d × %d m" % [int(t.get("w", 0)), int(t.get("d", 0))]]
	var prix := BuildingCatalog.cost(id)
	if prix > 0:
		parts.append(BuildingSystem.format_short(prix))
	for spec in [["logements", "logement", "logements"], ["emplois", "emploi", "emplois"], ["visiteurs", "visiteur", "visiteurs"],
			["lits", "lit", "lits"]]:
		var v := int(t.get(spec[0], 0))
		if v > 0:
			parts.append("%d %s" % [v, spec[1] if v == 1 else spec[2]])
	var st := String(t.get("style", ""))
	if st != "" and Styles.STYLES.has(st):
		parts.append("style %s" % String(Styles.STYLES[st].get("name", st)))
	elif String(t.get("region", "")) not in ["", "monde"]:
		parts.append(Styles.region_name(String(t.region)))
	return " · ".join(parts)


static func _batiments(out: Array) -> void:
	var types := BuildingCatalog.all_types()
	var ids := []
	for id in types:
		var t: Dictionary = types[id]
		if t.has("blocks") or t.has("modele") or bool(t.get("cache", false)):
			continue
		ids.append(String(id))
	# Lignées : les bâtiments qui jouent le même rôle à différentes époques.
	var lignees := {}
	for id in ids:
		var b := BuildingCatalog.base_of(id)
		if not lignees.has(b):
			lignees[b] = []
		(lignees[b] as Array).append([String(types[id].name), Epoques.annee_batiment(id), id])
	for id in ids:
		var t: Dictionary = types[id]
		var cat := BuildingCatalog.category(String(t.get("cat", "")))
		var evol := []
		if Ameliorations.ameliorable(id):
			evol.append("Agrandissable : niveau 2 (+50 %%, %s), niveau 3 (×2, %s) ; rénovation %s" % [
				BuildingSystem.format_short(roundi(BuildingCatalog.cost(id) * Ameliorations.PRIX[2])),
				BuildingSystem.format_short(roundi(BuildingCatalog.cost(id) * Ameliorations.PRIX[3])),
				BuildingSystem.format_short(roundi(BuildingCatalog.cost(id) * Ameliorations.PRIX_RENOV))])
		var nv := BuildingCatalog.variants_of(id)
		if nv > 1:
			evol.append("%d variantes de façade" % nv)
		var lg: Array = lignees.get(BuildingCatalog.base_of(id), [])
		if lg.size() > 1:
			evol.append("Même rôle selon l'époque : " + _lignee(lg.duplicate()))
		var eb := _e("batiments", String(cat.get("name", t.get("cat", ""))), id, String(t.name), Epoques.annee_batiment(id),
			source_batiment(id), _info_batiment(id, t), " · ".join(evol))
		if lg.size() > 1:
			eb["lignee"] = _ids_lignee(lg)
		out.append(eb)


# --- Véhicules --------------------------------------------------------------------------

static func _vehicules(out: Array) -> void:
	var noms_cat := {}
	for c in VehicleCatalog.CATEGORIES:
		noms_cat[String(c.id)] = String(c.name)
	var roles := {}
	for vid in VehicleCatalog.TYPES:
		var r := Epoques.role_vehicule(String(vid))
		if r != "":
			if not roles.has(r):
				roles[r] = []
			(roles[r] as Array).append([String(VehicleCatalog.TYPES[vid].name), Epoques.annee_vehicule(String(vid)), String(vid)])
	for vid in VehicleCatalog.TYPES:
		var v: Dictionary = VehicleCatalog.TYPES[vid]
		if bool(v.get("hidden", false)):
			continue
		var y := Epoques.annee_vehicule(String(vid))
		var info := []
		if int(v.get("kmh", 0)) > 0:
			info.append("%d km/h" % int(v.kmh))
		if int(v.get("places", 0)) > 0:
			info.append("%d places" % int(v.places))
		if String(v.get("region", "")) not in ["", "monde"]:
			info.append(Styles.region_name(String(v.region)))
		var evol := ""
		var lig := []
		var r := Epoques.role_vehicule(String(vid))
		if r != "" and (roles[r] as Array).size() > 1:
			evol = "Selon l'époque : " + _lignee((roles[r] as Array).duplicate())
			lig = _ids_lignee(roles[r])
		elif y > Epoques.ANNEE_MIN:
			var avant := Epoques.vehicule_pour_annee(String(vid), y - 1)
			if avant != String(vid):
				evol = "Avant %d, remplacé par : %s" % [y, String(VehicleCatalog.get_type(avant).get("name", avant))]
				lig = [avant, String(vid)]
		var ev := _e("vehicules", String(noms_cat.get(String(v.cat), v.cat)), String(vid), String(v.name), y, "propre",
			" · ".join(info), evol)
		if not lig.is_empty():
			ev["lignee"] = lig
		out.append(ev)


# --- Voies, stations, réseaux -----------------------------------------------------------

static func _voies(out: Array) -> void:
	for c in TransportTypes.CLASSES:
		var t: Dictionary = TransportTypes.CLASSES[c]
		out.append(_e("voies", "Voies", String(c), String(t.get("name", c)), Epoques.annee_voie(String(c)), "table",
			"%d km/h" % roundi(float(t.get("kmh", 0.0))) if float(t.get("kmh", 0.0)) > 0.0 else ""))
	for s in StationSystem.TYPES:
		var t: Dictionary = StationSystem.TYPES[s]
		var evol := ""
		if String(s) == "gare":
			evol = "Avant 1900 : gare d'époque (bâtiment voyageurs en pierre)"
		elif String(s) == "port":
			evol = "Avant 1880 : embarcadère"
		out.append(_e("stations", "Stations", String(s), String(t.get("name", s)), int(Epoques.STATIONS.get(s, 0)), "table",
			String(t.get("desc", "")), evol))
	for tr in ReseauxTypes.TRONCONS:
		var t: Dictionary = ReseauxTypes.TRONCONS[tr]
		out.append(_e("reseaux", "Électricité, eau, égouts, gaz", String(tr), String(t.get("name", tr)), int(Epoques.TRONCONS.get(tr, 0)),
			"table", String(t.get("desc", ""))))
	for cb in Telecom.CABLES:
		var t: Dictionary = Telecom.CABLES[cb]
		out.append(_e("reseaux", "Téléphone et internet", String(cb), String(t.get("name", cb)), int(Epoques.TRONCONS.get(cb, 0)), "table"))


# --- Agriculture ------------------------------------------------------------------------

static func _agriculture(out: Array) -> void:
	for mid in AgriDonnees.ORDRE_MACHINES:
		if not AgriDonnees.MACHINES.has(mid):
			continue
		var m: Dictionary = AgriDonnees.MACHINES[mid]
		var vs: Array = AgriEpoques.VERSIONS.get(mid, [])
		var chaine := []
		var moderne := 0
		for v: Dictionary in vs:
			if v.has("name"):
				chaine.append([String(v.name), int(v.annee)])
			elif bool(v.get("absent", false)):
				chaine.append(["(rien)", int(v.annee)])
			else:
				moderne = int(v.annee)
		chaine.append([String(m.name) + " moderne", moderne])
		var evol := "Selon l'époque : " + _lignee(chaine.duplicate()) if chaine.size() > 1 else ""
		var lig := []
		for c in chaine:
			if String(c[0]) != "(rien)":
				lig.append("%s@%d" % [mid, int(c[1])])
		for c in chaine:
			if String(c[0]) == "(rien)":
				continue
			var ea := _e("agriculture", "Machines : " + String(m.name), "%s@%d" % [mid, int(c[1])], String(c[0]), int(c[1]), "table",
				"", evol)
			if lig.size() > 1:
				ea["lignee"] = lig
			out.append(ea)
	for cid in AgriDonnees.ORDRE_CULTURES:
		if AgriDonnees.CULTURES.has(cid):
			out.append(_e("agriculture", "Cultures", String(cid), String(AgriDonnees.CULTURES[cid].name), AgriEpoques.annee_culture(String(cid)), "table"))
	for sid in AgriDonnees.ORDRE_ESPECES:
		if AgriDonnees.ESPECES.has(sid):
			out.append(_e("agriculture", "Élevages", String(sid), String(AgriDonnees.ESPECES[sid].name), AgriEpoques.annee_espece(String(sid)), "table"))


# --- Parc de loisirs ---------------------------------------------------------------------

static func _attractions(out: Array) -> void:
	for fid in VoiePieces.ORDRE_RAIL + VoiePieces.ORDRE_EAU:
		var f := VoiePieces.famille(String(fid))
		out.append(_e("attractions", "Types d'attraction", String(fid), String(f.nom), EpoquesObjets.annee_famille_voie(String(fid)), "ajoutee",
			"gare %s · voie %s/m" % [BuildingSystem.format_short(int(f.gare_prix)), BuildingSystem.format_short(int(f.m_prix))]))
	var noms_grp := {}
	for g in VoiePieces.GROUPES:
		noms_grp[String(g[0])] = String(g[1])
	for pid in VoiePieces.PIECES:
		var p: Dictionary = VoiePieces.PIECES[pid]
		out.append(_e("attractions", "Pièces : " + String(noms_grp.get(String(p.groupe), p.groupe)), String(pid), String(p.nom),
			EpoquesObjets.annee_piece_voie(String(pid)), "ajoutee", "%d m" % roundi(float(p.L))))


# --- Atelier : aménagements, ouvertures, toits, matériaux -----------------------------------

static func _atelier(out: Array) -> void:
	var noms_fam := {}
	for f in Amenagements.FAMILLES:
		noms_fam[String(f[0])] = String(f[1])
	for k in Amenagements.ORDER:
		var a: Dictionary = Amenagements.KINDS[k]
		out.append(_e("amenagements", String(noms_fam.get(String(a.fam), a.fam)), String(k), String(a.name),
			EpoquesObjets.annee_amenagement(String(k)), "ajoutee", String(a.get("desc", ""))))
	for ot in VignettesAtelier.OPENING_TABS:
		for k in ot[2]:
			var o: Dictionary = PlanEditor.OPENINGS[k]
			out.append(_e("ouvertures", String(ot[1]), String(k), String(o.name), EpoquesObjets.annee_ouverture(String(k)), "ajoutee",
				String(o.get("desc", ""))))
	for r in PlanEditor.ROOFS:
		out.append(_e("toits", "Toits", String(r[0]), String(r[1]), EpoquesObjets.annee_toit(String(r[0])), "ajoutee"))
	var noms_mat := {}
	for f in BlocMateriaux.FAMILIES:
		noms_mat[String(f.id)] = String(f.name)
	for i in BlocMateriaux.LIST.size():
		var m: Dictionary = BlocMateriaux.LIST[i]
		var y := Epoques.annee_materiau(i)
		out.append(_e("materiaux", String(noms_mat.get(String(m.get("fam", "")), m.get("fam", ""))), str(i), String(m.name), y,
			"mot", "%s le m²" % BuildingSystem.format_short(int(m.get("price", 0)))))


# --- Décors, meubles, spectacles ---------------------------------------------------------

static func _decors(out: Array) -> void:
	var noms := {}
	for c in Decors.categories():
		noms[String(c.id)] = String(c.nom)
	for d: Dictionary in Decors.tous():
		var id := String(d.id)
		var y := EpoquesObjets.annee_decor(id)
		var evol := ""
		if y > 0:
			var avant := EpoquesObjets.decor_epoque(id, y - 1)
			evol = "Avant %d, posé tout seul : %s" % [y, Decors.nom(avant) if avant != "" else "rien"] if EpoquesObjets.DECORS_ANCIENS.has(id) else ""
		var t: Array = d.get("taille", [0, 0, 0])
		var ed := _e("decors", String(noms.get(String(d.cat), d.cat)), id, String(d.nom), y, "ajoutee",
			("%.1f × %.1f m" % [float(t[0]), float(t[1])]).replace(".", ","), evol)
		if EpoquesObjets.DECORS_ANCIENS.has(id) and not (EpoquesObjets.DECORS_ANCIENS[id] as Array).is_empty():
			var lig := []
			for alt in EpoquesObjets.DECORS_ANCIENS[id]:
				if Decors.existe(String(alt)) and not String(alt) in lig:
					lig.append(String(alt))
			lig.sort_custom(func(a: String, b: String) -> bool: return EpoquesObjets.annee_decor(a) < EpoquesObjets.annee_decor(b))
			lig.append(id)
			if lig.size() > 1:
				ed["lignee"] = lig
		out.append(ed)


static func _meubles(out: Array) -> void:
	var styles_par_type := {}
	for mid in Meubles.ids():
		var e := Meubles.get_entry(String(mid))
		var st := String(e.get("style", ""))
		if st == MuseeObjets.STYLE or st == SpectaclesObjets.STYLE:
			continue
		var ty := String(e.get("type", ""))
		styles_par_type[ty] = int(styles_par_type.get(ty, 0)) + 1
	for tid in Meubles.TYPES:
		var t: Dictionary = Meubles.TYPES[tid]
		var p: Array = t.get("p", [])
		var piece := Meubles.piece_name(String(p[0])) if not p.is_empty() else ""
		var er: Array = t.get("e", [0, 5])
		var evol := ""
		if int(er[0]) > 0 or int(er[1]) < 5:
			evol = "Styles : %s à %s" % [Styles.era_name(Meubles.ERA_ORDER[int(er[0])]), Styles.era_name(Meubles.ERA_ORDER[int(er[1])])]
		out.append(_e("meubles", piece, String(tid), String(t.n), EpoquesObjets.annee_meuble(String(tid)), "ajoutee",
			"%d × %d · %s · %d styles" % [int(t.w), int(t.d), BuildingSystem.format_short(int(t.prix)), int(styles_par_type.get(String(tid), 0))], evol))
	for sid in SpectaclesObjets.TYPES:
		var s: Dictionary = SpectaclesObjets.TYPES[sid]
		var fam := String(s.get("f", s.get("fam", "")))
		out.append(_e("spectacles", String(SpectaclesObjets.FAMILLES.get(fam, {}).get("name", "Spectacle")), String(sid), String(s.n),
			int(EpoquesObjets.SPECTACLES.get(String(sid), 0)), "ajoutee"))


# --- Filtres et chiffres -----------------------------------------------------------------

## Entrées filtrées : famille ("" = toutes), texte, disponibilité à une année
## ("tout", "dispo", "avenir").
static func filtre(fam: String, texte: String, annee: int, etat := "tout") -> Array:
	var mots := texte.strip_edges().to_lower().split(" ", false)
	var out := []
	for e: Dictionary in entrees():
		if fam != "" and String(e.fam) != fam:
			continue
		var dispo := int(e.annee) <= annee
		if etat == "dispo" and not dispo or etat == "avenir" and dispo:
			continue
		if not mots.is_empty():
			var hay := ("%s %s %s %s" % [e.nom, e.groupe, e.info, e.id]).to_lower()
			var ok := true
			for m in mots:
				if not hay.contains(m):
					ok = false
					break
			if not ok:
				continue
		out.append(e)
	return out


## Nombre d'entrées par famille et par source d'année.
static func compte_sources() -> Dictionary:
	var out := {}
	for e: Dictionary in entrees():
		var f := String(e.fam)
		if not out.has(f):
			out[f] = {}
		out[f][String(e.source)] = int(out[f].get(String(e.source), 0)) + 1
	return out
