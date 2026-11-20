class_name Illustrations
extends RefCounted
## Images des choix des menus (ChoixVisuel.set_item_modele) : un vrai modèle du
## jeu rendu en vignette 3D (bâtiment, véhicule, meuble, décor, animal…) ou un
## petit dessin (toit, timbre, champ, drapeau). Un seul nœud Vignettes, partagé
## par tous les menus, rend les modèles une image par frame et les garde en
## mémoire. Sans affichage (--headless), les modèles 3D ne sont pas rendus : le
## menu garde sa vignette dessinée d'office (poser renvoie false).
## Voir docs/menus-en-images.md.

## Sortes connues (tests, documentation).
const SORTES := ["batiment", "vehicule", "meuble", "piece", "decor", "decor_cat", "animal", "continent",
	"categorie", "famille", "salle", "icone_sorte", "vehicule_epoque", "vehicule_region", "style", "style_meuble", "region", "epoque", "usage", "drapeau", "picto", "culture", "toit", "timbre", "icone"]

static var _vign: Vignettes


## Nœud de rendu partagé (créé à la première demande).
static func vignettes() -> Vignettes:
	if _vign != null and is_instance_valid(_vign):
		return _vign
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	_vign = Vignettes.new()
	_vign.name = "IllustrationsMenus"
	tree.root.add_child.call_deferred(_vign)
	return _vign


static func rendu_3d() -> bool:
	return DisplayServer.get_name() != "headless"


## Pose dans `cible` l'image de (`sorte`, `id`). Renvoie false si rien ne sera
## posé (id inconnu, ou modèle 3D sans affichage) : l'appelant met autre chose.
static func poser(sorte: String, id: String, cible: TextureRect) -> bool:
	match sorte:
		"picto":
			var t := Pictos.get_picto(id, 120)
			if t == null:
				return false
			cible.texture = t
			return true
		"toit":
			return _tex(Pictos.get_picto("toit_" + id, 120), cible)
		"timbre":
			return _tex(Pictos.get_picto("timbre_" + id.to_lower(), 120), cible)
		"culture":
			return _tex(Pictos.champ(id, 120), cible)
		"drapeau":
			return _tex(Drapeaux.icone(id, 48), cible)
		"icone", "icone_sorte", "famille", "salle":
			var ic := icone_de(sorte, id)
			return _tex(Pictos.auto(id, 0, 1, ic) if ic != "" else null, cible)
	if sorte == "piece" and SpectaclesObjets.SALLES.has(id):
		return poser("salle", id, cible)
	# Modèles 3D.
	var b := batiment_de(sorte, id)
	if b != "":
		if not rendu_3d():
			return false
		var v := vignettes()
		if v == null:
			return false
		v.request(b, cible)
		return true
	var m := _maquette(sorte, id)
	if m.is_empty():
		return false
	if not rendu_3d():
		return false
	var v2 := vignettes()
	if v2 == null:
		return false
	var builder: Callable = m[1]
	v2.request_mesh(String(m[0]), builder, cible, 128, m[2], float(m[3]), 96)
	return true


## Pose l'image de (`sorte`, `id`) comme icône de la ligne `index` d'une ItemList.
## (Aussi pour un PopupMenu : même façon de poser les icônes.)
static func poser_dans_liste(sorte: String, id: String, liste: Object, index: int) -> bool:
	var r := Relais.new()
	r.liste = liste
	r.index = index
	r.texte = liste.get_item_text(index)
	var ok := poser(sorte, id, r)
	if not ok:
		r.free()
	elif r.texture != null:
		r.recevoir_vignette(r.texture)
	return ok


## Reçoit une vignette (TextureRect ou rendu 3D plus tard) et la pose dans une ItemList,
## si la ligne n'a pas changé entre-temps.
class Relais extends TextureRect:
	var liste: Object
	var index := 0
	var texte := ""

	func recevoir_vignette(tex: Texture2D) -> void:
		if is_instance_valid(liste) and index < liste.item_count and liste.get_item_text(index) == texte:
			liste.set_item_icon(index, tex)
		queue_free()


## La sorte et l'id ont-ils une image ? (sans rien rendre ; tests)
static func connu(sorte: String, id: String) -> bool:
	match sorte:
		"picto":
			return Pictos.has_picto(id)
		"toit":
			return Pictos.has_picto("toit_" + id)
		"timbre":
			return Pictos.has_picto("timbre_" + id.to_lower())
		"culture":
			return not AgriDonnees.culture(id).is_empty()
		"drapeau":
			return Drapeaux.icone(id, 24) != null
		"icone", "icone_sorte", "famille", "salle":
			return icone_de(sorte, id) != ""
	if sorte == "piece" and SpectaclesObjets.SALLES.has(id):
		return true
	return batiment_de(sorte, id) != "" or not _maquette(sorte, id).is_empty()


static func _tex(t: Texture2D, cible: TextureRect) -> bool:
	if t == null:
		return false
	cible.texture = t
	return true


## Icône (Icones) d'une sorte dessinée en tuile de couleur, ou "".
static func icone_de(sorte: String, id: String) -> String:
	var ic := ""
	match sorte:
		"icone":
			ic = id
		"icone_sorte":
			ic = String(Partage.SORTE_ICONES.get(id, ""))
		"famille":
			ic = String(FAMILLES_ICONES.get(id, ""))
		"salle":
			var f := String(SpectaclesObjets.SALLES.get(id, {}).get("famille", ""))
			ic = {"cinema": "clap", "theatre": "masques", "concert": "micro"}.get(f, "masques")
	return ic if Icones.has_icon(ic) else ""


const FAMILLES_ICONES := {"batiments": "construire", "vehicules": "vehicules", "voies": "route", "stations": "lignes",
	"reseaux": "reseaux", "agriculture": "agriculture", "attractions": "loisirs", "amenagements": "atelier",
	"ouvertures": "ouverture", "toits": "toit", "materiaux": "materiaux", "decors": "decors", "meubles": "interieur",
	"spectacles": "masques"}


## Bâtiment du catalogue qui représente (sorte, id), ou "".
static func batiment_de(sorte: String, id: String) -> String:
	if id == "":
		return ""
	var types := BuildingCatalog.all_types()
	match sorte:
		"batiment":
			return id if types.has(id) else ""
		"usage":
			var u: Dictionary = Mobilier.USAGES.get(id, {})
			var t := String(u.get("t", ""))
			return t if types.has(t) else ""
		"categorie":
			var l := BuildingCatalog.ids_in(id)
			return l[0] if not l.is_empty() else ""
		"style":
			for arch in ["maison", "grande_maison", "immeuble", "boutique", "rangee"]:
				if types.has(id + "__" + arch):
					return id + "__" + arch
			for bid in types:
				if String(types[bid].get("style", "")) == id:
					return String(bid)
			return ""
		"region", "epoque":
			# Une maison de cette région (ou de cette époque), la plus typique trouvée.
			var meilleur := ""
			for bid in types:
				var t: Dictionary = types[bid]
				if t.get("cache", false) or String(t.get("cat", "")) != "logement":
					continue
				var ok := String(t.get("region", "")) == id if sorte == "region" else String(t.get("era", "")) == id
				if not ok:
					continue
				if String(bid).ends_with("__maison"):
					return String(bid)
				if meilleur == "":
					meilleur = String(bid)
			return meilleur
	return ""


## [clé, builder, direction, zoom] d'une maquette 3D, ou [].
static func _maquette(sorte: String, id: String) -> Array:
	var face := Vector3(0.55, 0.45, 1.0)
	match sorte:
		"vehicule":
			if VehicleCatalog.get_type(id).is_empty():
				return []
			return ["ill_veh_" + id, func() -> Mesh: return VehicleCatalog.build_mesh(id, 0, TransportView.make_material()),
				Vector3(1.0, 0.6, -0.9), 0.62]
		"meuble":
			if Meubles.get_entry(id).is_empty():
				return []
			return ["ill_meuble_" + id, func() -> Mesh: return MeublesModeles.mesh_of(id), face, 0.6]
		"piece":
			var mid := meuble_de_piece(id)
			return _maquette("meuble", mid) if mid != "" else []
		"style_meuble":
			var l := Meubles.filtered("", id)
			return _maquette("meuble", String(l[0])) if not l.is_empty() else []
		"vehicule_epoque", "vehicule_region":
			var l := VehicleCatalog.for_track("rue", id if sorte == "vehicule_epoque" else "", id if sorte == "vehicule_region" else "")
			for vid in l:
				if VehicleCatalog.get_type(vid).get("cat", "") in ["voiture", "car", "auto"]:
					return _maquette("vehicule", vid)
			return _maquette("vehicule", l[0]) if not l.is_empty() else []
		"decor", "animal":
			if not Decors.existe(id):
				return []
			return ["ill_decor_" + id, func() -> Mesh: return ZooPanel.mesh_colore(id), face, 0.62]
		"decor_cat":
			var l := Decors.de_categorie(id)
			if l.is_empty():
				return []
			return _maquette("decor", String((l[0] as Dictionary).id))
		"continent":
			var did := animal_de_continent(id)
			return _maquette("decor", did) if did != "" else []
	return []


## Meuble typique de chaque pièce (premier trouvé dans le catalogue).
const MEUBLE_TYPIQUE := {"sejour": "canape", "cuisine": "cuisiniere", "chambre": "lit_double", "enfant": "lit_superpose",
	"sdb": "baignoire", "entree": "porte_manteau", "bureau": "poste_travail", "classe": "pupitre", "boutique": "comptoir",
	"salle": "table_bistrot", "reserve": "rayonnage", "deco": "grande_plante"}
## Animal typique de chaque continent du zoo.
const ANIMAL_TYPIQUE := {"afrique": "lion", "asie": "tigre", "europe": "ours_brun", "amerique": "lama", "oceanie": "kangourou",
	"polaire": "ours_polaire", "ferme": "chevre"}


## Le meuble le plus parlant d'une pièce : le typique, sinon le plus gros.
static func meuble_de_piece(cat: String) -> String:
	var best := ""
	var best_v := -1.0
	var typ := String(MEUBLE_TYPIQUE.get(cat, ""))
	for mid in Meubles.filtered(cat):
		if typ != "" and String(mid).get_slice("/", 1) == typ:
			return String(mid)
		var e := Meubles.get_entry(String(mid))
		var v := float(e.get("w", 1.0)) * float(e.get("d", 1.0)) * float(e.get("h", 1.0))
		if v > best_v:
			best_v = v
			best = String(mid)
	return best


## Un animal du continent (le premier de la liste qui a un modèle).
static func animal_de_continent(cont: String) -> String:
	var typ := String(ANIMAL_TYPIQUE.get(cont, ""))
	if ZooEspeces.ESPECES.has(typ):
		var d := String((ZooEspeces.ESPECES[typ].get("decors", [""]) as Array)[0])
		if Decors.existe(d):
			return d
	for sid in ZooEspeces.ESPECES:
		var e: Dictionary = ZooEspeces.ESPECES[sid]
		if String(e.get("cont", "")) == cont and not (e.get("decors", []) as Array).is_empty():
			var did := String(e.decors[0])
			if Decors.existe(did):
				return did
	return ""
