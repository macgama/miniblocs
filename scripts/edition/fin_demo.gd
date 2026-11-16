class_name FinDemo
extends CanvasLayer
## Écran de fin de l'édition démo (Steam Next Fest) : merci, ce qui attend
## dans le jeu complet, et le gros bouton « Ajouter à ma liste de souhaits ».
##
## Motif.LIMITE : la partie a atteint la limite de la démo (EditionDemo.JOURS_MAX
## jours ou HABITANTS_MAX habitants) ; le temps reste en pause, on peut encore
## regarder sa ville. Motif.QUITTER : le joueur quitte le jeu depuis le menu.

enum Motif { LIMITE, QUITTER }

signal menu_demande
signal quitter_demande
signal ferme

## Ce qui attend dans le jeu complet (une ligne chacun).
const DANS_LE_JEU := [
	"Parc de loisirs avec grands-huit à construire pièce par pièce",
	"Zoo (34 espèces), musées, cinémas, théâtres et salles de concert",
	"Club de sport : foot, basket, hand, hockey, rugby et tennis",
	"Partir de 1800 et traverser les époques",
	"Scénarios et défis, tourisme et hôtels",
	"Cartes entre amis et l'Atelier pour créer tes bâtiments",
]

var motif: Motif
var chiffres := {}
var _panel: PanelContainer


func _init(m: Motif = Motif.LIMITE, c: Dictionary = {}) -> void:
	motif = m
	chiffres = c
	name = "FinDemo"
	layer = 65
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var voile := ColorRect.new()
	voile.color = Color(0, 0, 0, 0.55)
	voile.anchor_right = 1.0
	voile.anchor_bottom = 1.0
	add_child(voile)
	var centre := CenterContainer.new()
	centre.anchor_right = 1.0
	centre.anchor_bottom = 1.0
	add_child(centre)
	_panel = PanelContainer.new()
	_panel.name = "PanneauFinDemo"
	UiStyle.style_panel(_panel, 0.96, 16, 24)
	_panel.custom_minimum_size = Vector2(640, 0)
	centre.add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_panel.add_child(v)
	v.add_child(_label(titre(), 30, UiStyle.ACCENT))
	v.add_child(_label(sous_titre(), 16))
	v.add_child(_label("Dans le jeu complet :", 15, UiStyle.ACCENT))
	for l in DANS_LE_JEU:
		v.add_child(_label("•  " + String(l), 14, UiStyle.TEXT))
	v.add_child(_label("Sortie prévue en accès anticipé en 2027. Ajoute MiniBlocs à ta liste de souhaits : Steam te préviendra le jour J.", 13, UiStyle.TEXT_DIM))

	var souhaits := Button.new()
	souhaits.name = "Souhaits"
	souhaits.text = "♥  Ajouter à ma liste de souhaits"
	souhaits.custom_minimum_size = Vector2(0, 52)
	souhaits.add_theme_font_size_override("font_size", 20)
	var n := UiStyle.flat_box(Color(UiStyle.ACCENT, 0.92), 10, 12)
	souhaits.add_theme_stylebox_override("normal", n)
	souhaits.add_theme_stylebox_override("hover", UiStyle.flat_box(Color(UiStyle.ACCENT, 1.0), 10, 12))
	souhaits.add_theme_stylebox_override("focus", UiStyle.flat_box(Color(UiStyle.ACCENT, 1.0), 10, 12))
	souhaits.add_theme_color_override("font_color", UiStyle.ACCENT_INK)
	souhaits.add_theme_color_override("font_hover_color", UiStyle.ACCENT_INK)
	souhaits.add_theme_color_override("font_focus_color", UiStyle.ACCENT_INK)
	souhaits.pressed.connect(func() -> void: EditionDemo.ouvrir_magasin())
	v.add_child(souhaits)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	if motif == Motif.LIMITE:
		row.add_child(_bouton("Regarder", "Regarder ma ville", fermer))
		row.add_child(_bouton("Menu", "Menu principal", func() -> void: menu_demande.emit()))
	else:
		row.add_child(_bouton("Retour", "Retour au menu", fermer))
		row.add_child(_bouton("Quitter", "Quitter", func() -> void: quitter_demande.emit()))
	souhaits.grab_focus.call_deferred()


func titre() -> String:
	return "Fin de la démo" if motif == Motif.LIMITE else "Merci d'avoir joué !"


func sous_titre() -> String:
	if motif == Motif.QUITTER:
		return "C'était la démo de MiniBlocs. Ta ville t'attend, et elle n'a même pas encore de grand-huit."
	var nom := String(chiffres.get("nom", "Ta ville"))
	var jours := int(chiffres.get("jours", 0))
	var hab := int(chiffres.get("habitants", 0))
	var pourquoi := "%d jours de mandat" % jours if jours >= EditionDemo.JOURS_MAX else "%d habitants" % hab
	return "%s a atteint la limite de la démo (%s). Le temps s'arrête ici : tu peux encore la regarder et la photographier (F8), et elle est sauvegardée." % [nom, pourquoi]


func fermer() -> void:
	ferme.emit()
	queue_free()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and k.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		fermer()


func _bouton(id: String, t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.name = id
	b.text = t
	b.pressed.connect(cb)
	return b


func _label(t: String, size := 14, col := UiStyle.TEXT, w := 592.0) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(w, 0)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l
