class_name CouleursModele
extends RefCounted
## Recolore un bâtiment modélisé dans Blender (.glb) sans refaire le modèle.
##
## Chaque face d'un modèle prend sa couleur dans une petite texture « palette »
## (8 × 8 cases). À côté de chaque .glb, le fichier <nom>.palette.json donne la
## case de chaque couleur nommée (« enduit_chaud », « tuile », « volet », ou une
## couleur « #rrggbb » propre au modèle). Remplacer des cases donne une variante :
##   CouleursModele.recolore(maison, "res://assets/modeles/batiments/maison_test.glb",
##       {"enduit_chaud": Color("c9e4f0"), "volet": Color("8a3b2e")})
## Seule la copie posée dans la scène change ; le fichier du modèle reste intact.


## Charge la carte de palette d'un modèle (vide si absente).
static func carte(chemin_glb: String) -> Dictionary:
	var chemin := chemin_glb.get_basename() + ".palette.json"
	if not FileAccess.file_exists(chemin):
		return {}
	var donnees: Variant = JSON.parse_string(FileAccess.get_file_as_string(chemin))
	return donnees if donnees is Dictionary else {}


## Noms des couleurs qu'un modèle utilise vraiment (hors vitres, cadres, ombres).
static func couleurs_principales(chemin_glb: String) -> PackedStringArray:
	var noms := PackedStringArray()
	var c := carte(chemin_glb)
	var techniques := ["vitre", "cadre", "ombre", "tuile_ombre", "socle", "metal", "beton"]
	for nom: String in c.get("couleurs", {}).keys():
		if not techniques.has(nom):
			noms.append(nom)
	return noms


## Remplace les couleurs données (nom -> Color) dans la palette du modèle posé
## sous `racine`. Renvoie le nombre de couleurs remplacées.
static func recolore(racine: Node, chemin_glb: String, remplacements: Dictionary) -> int:
	var c := carte(chemin_glb)
	if c.is_empty():
		return 0
	var cases: Dictionary = c.get("couleurs", {})
	var taille := int(c.get("taille", 8))
	var px := int(c.get("pixels_par_case", 8))
	var faits := 0
	for n in racine.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(s) as BaseMaterial3D
			if mat == null or mat.albedo_texture == null:
				continue
			var tex := mat.albedo_texture
			if tex.get_width() != taille * px:
				continue  # pas la palette (vitrage, grille, panneaux solaires)
			var img := tex.get_image()
			if img.is_compressed():
				img.decompress()
			img.convert(Image.FORMAT_RGBA8)
			img.clear_mipmaps()
			faits = 0  # compté pour la palette (une seule par modèle)
			for nom: String in remplacements.keys():
				if not cases.has(nom):
					continue
				var idx := int(cases[nom]["index"])
				var x0 := (idx % taille) * px
				var y0 := (idx / taille) * px
				img.fill_rect(Rect2i(x0, y0, px, px), remplacements[nom])
				faits += 1
			var copie := mat.duplicate() as BaseMaterial3D
			copie.albedo_texture = ImageTexture.create_from_image(img)
			copie.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			mi.set_surface_override_material(s, copie)
	return faits


## Teintes plausibles pour une variante, par famille de couleur.
const MURS := ["enduit", "enduit_chaud", "pierre", "pignon"]
const TOITS := ["tuile", "ardoise", "chaume"]
const TUILES_TEINTES := ["#c8553d", "#a9472f", "#8c3b2a", "#5b5f66", "#43474e", "#7a5a44", "#b06a3b", "#6b4f3a"]
## Couleurs du terrain de foot et des lignes : jamais recolorées.
const INTOUCHABLES := ["#5aa040", "#4d9236", "#4a8a35", "#4f9a3c", "#47903a", "#f4f4f0", "#b5523b"]


## Variante au hasard mais plausible : murs pastel, toit dans des teintes de
## tuile ou d'ardoise, volets, portes et sièges dans des teintes franches mais
## pas criardes. Les rangs et le faîtage du toit suivent la tuile choisie.
static func variante_au_hasard(racine: Node, chemin_glb: String, rng: RandomNumberGenerator) -> int:
	var c := carte(chemin_glb)
	var cases: Dictionary = c.get("couleurs", {})
	var choix := {}
	var teinte_murs := rng.randf()
	for nom in couleurs_principales(chemin_glb):
		if INTOUCHABLES.has(nom):
			continue
		var origine := Color(String(cases[nom]["origine"]))
		if MURS.has(nom):
			choix[nom] = Color.from_hsv(teinte_murs, rng.randf_range(0.06, 0.28), rng.randf_range(0.78, 0.95))
		elif TOITS.has(nom):
			var t := Color(TUILES_TEINTES[rng.randi() % TUILES_TEINTES.size()])
			choix[nom] = t
			choix["tuile_ombre"] = t.darkened(0.3)
			choix["tuile_faitage"] = t.darkened(0.12)
		elif nom.begins_with("tuile_"):
			continue
		else:
			# Garde la clarté d'origine, change la teinte, saturation modérée.
			var sat := rng.randf_range(0.25, 0.6) if origine.s > 0.12 else origine.s
			choix[nom] = Color.from_hsv(rng.randf(), sat, clampf(origine.v, 0.22, 0.92))
	return recolore(racine, chemin_glb, choix)
