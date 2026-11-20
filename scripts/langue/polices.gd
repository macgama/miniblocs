class_name Polices
extends RefCounted
## Polices de secours ajoutées derrière la police du jeu (piste CityRT 13) :
##  - symboles.ttf : flèches, triangles, ♥, ☆, ✓… (sous-ensemble de DejaVu Sans) ;
##  - chinois.otf : les caractères chinois des textes du jeu (Noto Sans SC, OFL) ;
##  - emoji.ttf : ⏳ 🏆 📌 🔒 (Noto Color Emoji, OFL).
## Sur PC, le système complète déjà ce qui manque ; dans le navigateur (démo web)
## il n'y a pas de police système : sans elles, ces signes deviennent des carrés.
## Sous-ensembles régénérés par tools/langue/polices.py quand les textes changent.

const DOSSIER := "res://assets/polices/"
const FICHIERS := ["symboles.ttf", "chinois.otf", "emoji.ttf"]

static var _installees := false


static func installer() -> void:
	if _installees:
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
	installer()
	return ThemeDB.fallback_font.has_char(c.unicode_at(0))
