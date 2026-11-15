extends CanvasLayer
## Nœud global (autoload « SuccesNotif ») : démarre Steam (SteamPont), fait tourner
## ses callbacks, et affiche une carte « Succès débloqué » en haut à droite, dans
## toutes les scènes (menu, globe, partie). Les cartes se suivent si plusieurs
## succès tombent en même temps.

const DUREE := 5.0

var _file: Array = []
var _carte: PanelContainer
var _reste := 0.0
## Cartes montrées (tests).
var montrees: Array = []


func _ready() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	Succes.charger()
	SteamPont.demarrer()


func _process(delta: float) -> void:
	SteamPont.tick()
	if _carte != null:
		_reste -= delta
		if _reste <= 0.0:
			_carte.queue_free()
			_carte = null
	if _carte == null and not _file.is_empty():
		_montrer(String(_file.pop_front()))


## Appelé par Succes.debloquer.
func annoncer(id: String) -> void:
	_file.append(id)


func _montrer(id: String) -> void:
	var s := Succes.info(id)
	if s.is_empty():
		return
	montrees.append(id)
	Son.jouer("palier", -4.0, 0.0, "Interface")
	Manette.vibrer(0.35, 0.25)
	_reste = DUREE
	_carte = PanelContainer.new()
	_carte.name = "CarteSucces"
	UiStyle.style_panel(_carte, 0.95, 12, 12)
	_carte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# En haut au milieu, sous la barre du haut : les panneaux sont à droite et à gauche.
	_carte.anchor_left = 0.5
	_carte.anchor_right = 0.5
	_carte.offset_left = -200
	_carte.offset_right = 200
	_carte.offset_top = 64
	add_child(_carte)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_carte.add_child(h)
	var ic := TextureRect.new()
	ic.texture = SuccesPanel.badge(String(s.get("icone", "trophee")), true, 56)
	ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	h.add_child(ic)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var t := Label.new()
	t.text = "Succès débloqué"
	t.add_theme_font_size_override("font_size", 12)
	t.add_theme_color_override("font_color", UiStyle.ACCENT)
	v.add_child(t)
	var n := Label.new()
	n.text = String(s.nom)
	n.add_theme_font_size_override("font_size", 17)
	v.add_child(n)
	var d := Label.new()
	d.text = String(s.desc)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(290, 0)
	d.add_theme_font_size_override("font_size", 12)
	d.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	v.add_child(d)
