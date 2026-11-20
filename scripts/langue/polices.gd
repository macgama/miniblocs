class_name Polices
extends RefCounted
## Polices de secours ajoutées derrière la police du jeu (piste CityRT 13) :
##  - symboles.ttf : flèches, triangles, ♥, ☆, ✓… (sous-ensemble de DejaVu Sans) ;
##  - chinois.otf : les caractères chinois des textes du jeu (Noto Sans SC, OFL) ;
##  - emoji.ttf : ⏳ 🏆 📌 🔒 (Noto Color Emoji, OFL).
## Sur PC, le système complète déjà ce qui manque ; dans le navigateur (démo web)
## il n'y a pas de police système : sans elles, ces signes deviennent des carrés.
## On ne les ajoute que dans le navigateur et en chinois : Noto Sans SC est plus
## haute que la police du jeu, et une police de secours agrandit toutes les lignes.
## Sous-ensembles régénérés par tools/langue/polices.py quand les textes changent.

const DOSSIER := "res://assets/polices/"
const FICHIERS := ["symboles.ttf", "chinois.otf", "emoji.ttf"]

static var _installees := false


## Ajoute les polices si le jeu en a besoin (navigateur, chinois) ou si force.
static func installer(force := false) -> void:
	if _installees or not (force or OS.has_feature("web") or Langue.actuelle == "zh"):
		return
	_installees = true
	var base := ThemeDB.fallback_font
	if base == null:
		return
	var liste: Array[Font] = base.fallbacks.duplicate()
	for f in FICHIERS:
		var chemin: String = DOSSIER + f
		if ResourceLoader.exists(chemin):
			var p := load(chemin) as Font
			if p != null and not liste.has(p):
				liste.append(p)
	base.fallbacks = liste


## Vrai si la police du jeu (avec ses secours) sait dessiner c.
static func sait(c: String) -> bool:
	installer(true)
	return ThemeDB.fallback_font.has_char(c.unicode_at(0))
