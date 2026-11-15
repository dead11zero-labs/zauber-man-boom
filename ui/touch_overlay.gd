extends CanvasLayer
## Touch-Overlay fuer Android: virtueller Lauf-Stick links, Wischen rechts zum Umsehen, Knoepfe fuer
## Zauber (halten = aufladen), Sprung, Dash, Aktion sowie Journal, Karte und Hinweis oben.
## Ist die Spieler-Eingabe gesperrt (Dialog, Shop, Journal, Aufzug, Burger-Minispiel), wechselt das
## Overlay in den Menue-Modus: Steuerkreuz links, OK und ZURUECK rechts.
## Wird von `autoload/eingabe.gd` erzeugt und ist nur sichtbar, solange Touch das aktive Geraet ist.
## Knoepfe loesen die normalen Aktionen aus (InputEventAction), der Stick schreibt `Eingabe.touch_stick`,
## das Wischen geht ueber `Eingabe.touch_blick_addieren`. Keine eigenen Signale oder Exporte.

const FARBE := Color(0.1, 0.95, 1.0)
const FARBE_ZAUBER := Color(1.0, 0.15, 0.8)
const FARBE_MENUE := Color(1.0, 0.85, 0.2)
const ALPHA_RUHE := 0.28
const ALPHA_AKTIV := 0.7
const RAND_BREITE := 2.5
const SCHRIFT := 15
## Lauf-Stick: Zone links unten (Anteil der Bildbreite/-hoehe), Radius und Ruheposition
const STICK_ZONE_BREITE := 0.42
const STICK_ZONE_OBEN := 0.3
const STICK_RADIUS := 78.0
const STICK_KNAUF := 34.0
const STICK_RUHE := Vector2(150.0, -150.0)   # von links unten
const STICK_TOTZONE := 0.12
## Trefferflaeche der Knoepfe ist etwas groesser als gezeichnet (dicke Daumen)
const TREFFER_FAKTOR := 1.25
## Sperrgrund des Burger-Minispiels: dort gibt es zusaetzlich den Knopf "ZURUECKNEHMEN" (Aktion dash)
const SPERRE_BURGER := "burger"

## Knopf: [Aktion, Text, Ecke (x: 0 links, 0.5 Mitte, 1 rechts; y: 0 oben, 1 unten), Versatz, Radius, Farbe]
const KNOEPFE_SPIEL := [
	["zaubern", "ZAUBER", Vector2(1, 1), Vector2(-100, -100), 60.0, FARBE_ZAUBER],
	["springen", "SPRUNG", Vector2(1, 1), Vector2(-232, -76), 46.0, FARBE],
	["dash", "DASH", Vector2(1, 1), Vector2(-76, -232), 42.0, FARBE],
	["interagieren", "AKTION", Vector2(1, 1), Vector2(-206, -196), 42.0, FARBE_MENUE],
	["journal", "JOURNAL", Vector2(0.5, 0), Vector2(-84, 44), 30.0, FARBE],
	["minimap", "KARTE", Vector2(0.5, 0), Vector2(0, 44), 30.0, FARBE],
	["hinweis", "HINWEIS", Vector2(0.5, 0), Vector2(84, 44), 30.0, FARBE],
]
const KNOEPFE_MENUE := [
	["ui_up", "▲", Vector2(0, 1), Vector2(150, -226), 40.0, FARBE],
	["ui_down", "▼", Vector2(0, 1), Vector2(150, -74), 40.0, FARBE],
	["ui_left", "◀", Vector2(0, 1), Vector2(74, -150), 40.0, FARBE],
	["ui_right", "▶", Vector2(0, 1), Vector2(226, -150), 40.0, FARBE],
	["ui_accept", "OK", Vector2(1, 1), Vector2(-100, -100), 60.0, FARBE_MENUE],
	["ui_cancel", "ZURÜCK", Vector2(1, 1), Vector2(-232, -76), 46.0, FARBE],
]
const KNOPF_BURGER := ["dash", "WEG", Vector2(1, 1), Vector2(-76, -232), 42.0, FARBE]

var _flaeche: Control
var _sperren: Dictionary = {}
## Finger-Index -> gedrueckter Knopf (Aktion)
var _finger_knopf: Dictionary = {}
var _stick_finger := -1
var _stick_start := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _blick_finger := -1


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_flaeche = Control.new()
	_flaeche.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flaeche.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flaeche.draw.connect(_zeichnen)
	add_child(_flaeche)
	visible = Eingabe.ist_touch()
	Eingabe.geraet_geaendert.connect(_geraet_geaendert)
	EventBus.eingabe_gesperrt.connect(_sperre)


func _geraet_geaendert(geraet: int) -> void:
	visible = geraet == Eingabe.Geraet.TOUCH
	if not visible:
		_alles_loslassen()
	_flaeche.queue_redraw()


func _sperre(grund: String, gesperrt: bool) -> void:
	if gesperrt:
		_sperren[grund] = true
	else:
		_sperren.erase(grund)
	# Moduswechsel: nichts darf haengen bleiben
	_alles_loslassen()
	_flaeche.queue_redraw()


## Spielszene laeuft und nichts ist gesperrt: Stick und Wischen aktiv. Sonst Menue-Modus.
func _im_spiel() -> bool:
	return _sperren.is_empty() and get_tree().get_first_node_in_group("spieler") != null


func _knoepfe() -> Array:
	if get_tree().get_first_node_in_group("spieler") == null:
		return []   # Startmenue und Ladebildschirm: dort wird direkt getippt
	if _sperren.is_empty():
		return KNOEPFE_SPIEL
	return KNOEPFE_MENUE + [KNOPF_BURGER] if _sperren.has(SPERRE_BURGER) else KNOEPFE_MENUE


func _knopf_mitte(k: Array) -> Vector2:
	var g := _flaeche.size
	return Vector2(g.x * k[2].x, g.y * k[2].y) + k[3]


func _aktion(aktion: String, gedrueckt: bool) -> void:
	var e := InputEventAction.new()
	e.action = aktion
	e.pressed = gedrueckt
	e.strength = 1.0 if gedrueckt else 0.0
	Input.parse_input_event(e)


func _alles_loslassen() -> void:
	for finger in _finger_knopf:
		_aktion(_finger_knopf[finger], false)
	_finger_knopf.clear()
	_stick_finger = -1
	_blick_finger = -1
	Eingabe.touch_stick = Vector2.ZERO


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_finger_runter(event.index, event.position)
		else:
			_finger_hoch(event.index)
		_flaeche.queue_redraw()
	elif event is InputEventScreenDrag:
		if event.index == _stick_finger:
			_stick_bewegen(event.position)
			_flaeche.queue_redraw()
		elif event.index == _blick_finger:
			Eingabe.touch_blick_addieren(event.relative)


func _finger_runter(finger: int, pos: Vector2) -> void:
	for k in _knoepfe():
		if pos.distance_to(_knopf_mitte(k)) <= k[4] * TREFFER_FAKTOR:
			_finger_knopf[finger] = k[0]
			_aktion(k[0], true)
			return
	if not _im_spiel():
		return
	var g := _flaeche.size
	if _stick_finger < 0 and pos.x < g.x * STICK_ZONE_BREITE and pos.y > g.y * STICK_ZONE_OBEN:
		_stick_finger = finger
		_stick_start = pos
		_stick_pos = pos
	elif _blick_finger < 0:
		_blick_finger = finger


func _finger_hoch(finger: int) -> void:
	if _finger_knopf.has(finger):
		_aktion(_finger_knopf[finger], false)
		_finger_knopf.erase(finger)
	if finger == _stick_finger:
		_stick_finger = -1
		Eingabe.touch_stick = Vector2.ZERO
	if finger == _blick_finger:
		_blick_finger = -1


func _stick_bewegen(pos: Vector2) -> void:
	var v := pos - _stick_start
	# Zieht der Daumen ueber den Rand, wandert der Stick mit
	if v.length() > STICK_RADIUS:
		_stick_start = pos - v.normalized() * STICK_RADIUS
		v = pos - _stick_start
	_stick_pos = pos
	var wert := v / STICK_RADIUS
	if wert.length() < STICK_TOTZONE:
		wert = Vector2.ZERO
	# Bildschirm-y zeigt nach unten, vorwaerts ist positiv
	Eingabe.touch_stick = Vector2(wert.x, -wert.y)


func _zeichnen() -> void:
	var font := ThemeDB.fallback_font
	for k in _knoepfe():
		var mitte := _knopf_mitte(k)
		var aktiv: bool = _finger_knopf.values().has(k[0])
		var farbe: Color = k[5]
		_flaeche.draw_circle(mitte, k[4], Color(farbe, 0.32 if aktiv else 0.1))
		_flaeche.draw_arc(mitte, k[4], 0.0, TAU, 48, Color(farbe, ALPHA_AKTIV if aktiv else ALPHA_RUHE + 0.2), RAND_BREITE, true)
		var groesse := SCHRIFT if k[4] >= 40.0 else SCHRIFT - 4
		if (k[1] as String).length() == 1:
			groesse = SCHRIFT + 10
		var breite := font.get_string_size(k[1], HORIZONTAL_ALIGNMENT_LEFT, -1, groesse).x
		_flaeche.draw_string(font, mitte + Vector2(-breite * 0.5, groesse * 0.36), k[1], HORIZONTAL_ALIGNMENT_LEFT, -1, groesse, Color(1, 1, 1, 0.95 if aktiv else 0.75))
	if not _im_spiel():
		return
	var start := Vector2(STICK_RUHE.x, _flaeche.size.y + STICK_RUHE.y)
	var knauf := start
	var aktiv_stick := _stick_finger >= 0
	if aktiv_stick:
		start = _stick_start
		knauf = _stick_pos
	_flaeche.draw_circle(start, STICK_RADIUS, Color(FARBE, 0.07))
	_flaeche.draw_arc(start, STICK_RADIUS, 0.0, TAU, 64, Color(FARBE, ALPHA_AKTIV if aktiv_stick else ALPHA_RUHE), RAND_BREITE, true)
	_flaeche.draw_circle(knauf, STICK_KNAUF, Color(FARBE, 0.45 if aktiv_stick else 0.2))
