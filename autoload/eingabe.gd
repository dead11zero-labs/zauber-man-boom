extends Node
## Eingabe: haengt Gamepad-Belegungen an die bestehenden Aktionen (deutsche Namen bleiben) und
## buendelt Tastatur, Gamepad und Touch zu einer Abfrage fuer den Spieler.
## Linker Stick/Steuerkreuz: gehen und drehen, rechter Stick: umsehen,
## A: springen, X oder RT/RB: zaubern, Y: interagieren, B: dash, Start: Journal, Back: Minimap,
## linke Schulter: Hinweis, rechter Stick gedrueckt: Tag/Nacht.
## Eigene Zusatz-Aktionen: "hinweis" (H), "dash" (Q oder Strg links), "journal" (J), "minimap" (M), "tageszeit" (T).
##
## Schnittstelle:
##   bewegung() -> Vector2      x = drehen (rechts positiv), y = vorwaerts (positiv), je -1..1, analog
##   blick() -> Vector2         rechter Stick mit Totzone und Kurve (x rechts, y unten), -1..1
##   touch_blick_nehmen()       seit dem letzten Aufruf gewischte Strecke in Bildpunkten (Touch-Umsehen)
##   taste(aktion) -> String    Beschriftung der Aktion fuer das gerade benutzte Geraet ("E", "Y", "AKTION")
##   hinweis_binden(label, aktion, format)  haelt einen Label3D-Text wie "%s: SPRECHEN" aktuell
##   vibrieren(schwach, stark, dauer)       Rumble auf allen Pads
## Signal `geraet_geaendert(geraet)`: Tastatur/Maus, Gamepad oder Touch wurde zuletzt benutzt.
## Das Touch-Overlay (`ui/touch_overlay.gd`) wird hier erzeugt und ist nur im Touch-Betrieb sichtbar.

signal geraet_geaendert(geraet: int)

enum Geraet { TASTATUR, PAD, TOUCH }

## Sticks: radiale Totzone und Kurve (hoeherer Exponent = feinfuehliger um die Mitte)
const STICK_TOTZONE := 0.18
const BLICK_KURVE := 1.6
const LAUF_KURVE := 1.2
## Ab dieser Auslenkung zaehlt eine Stick-Bewegung als "Pad wird benutzt"
const PAD_ERKENNUNG := 0.5
## Rumble bei Treffer und Tod (schwacher Motor, starker Motor, Sekunden)
const RUMBLE_TREFFER := Vector3(0.5, 0.7, 0.25)
const RUMBLE_TOD := Vector3(0.8, 1.0, 0.6)
## Startparameter, der das Touch-Overlay auch am PC einschaltet (Test): `-- --touch`
const TOUCH_ARGUMENT := "--touch"
const TOUCH_OVERLAY := preload("res://ui/touch_overlay.gd")
const TASTEN := {
	"interagieren": ["E", "Y", "AKTION"],
	"springen": ["SHIFT", "A", "SPRUNG"],
	"zaubern": ["LEERTASTE", "X", "ZAUBER"],
	"dash": ["Q", "B", "DASH"],
	"hinweis": ["H", "LB", "HINWEIS"],
	"journal": ["J", "START", "JOURNAL"],
	"minimap": ["M", "BACK", "KARTE"],
	"ui_cancel": ["ESC", "B", "ZURÜCK"],
	"ui_accept": ["ENTER", "A", "OK"],
}

var geraet: int = Geraet.TASTATUR
## Vom Touch-Overlay gesetzter virtueller Stick (x rechts, y vorwaerts)
var touch_stick := Vector2.ZERO
var _touch_blick := Vector2.ZERO
var _herzen_alt := 0

const AKTIONEN := {
	"springen": [0],
	"zaubern": [2, 10],
	"interagieren": [3],
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_zusatz_aktion("minimap", [KEY_M], JOY_BUTTON_BACK)
	_zusatz_aktion("tageszeit", [KEY_T], JOY_BUTTON_RIGHT_STICK)
	# Neue Aktion "hinweis": Taste H, Pad linke Schulter (Hinweis-Pulse an Raetseln)
	if not InputMap.has_action("hinweis"):
		InputMap.add_action("hinweis")
		var k := InputEventKey.new()
		k.physical_keycode = KEY_H
		InputMap.action_add_event("hinweis", k)
		var b := InputEventJoypadButton.new()
		b.button_index = JOY_BUTTON_LEFT_SHOULDER
		InputMap.action_add_event("hinweis", b)
	# Neue Aktion "dash" (Meilenstein 4): Q oder Strg links, Pad B
	if not InputMap.has_action("dash"):
		InputMap.add_action("dash")
		for taste: Key in [KEY_Q, KEY_CTRL]:
			var dk := InputEventKey.new()
			dk.physical_keycode = taste
			InputMap.action_add_event("dash", dk)
		var db := InputEventJoypadButton.new()
		db.button_index = JOY_BUTTON_B
		InputMap.action_add_event("dash", db)
	# Neue Aktion "journal" (Meilenstein 5): Taste J, Pad Start (Back ist die Minimap, Y ist interagieren)
	if not InputMap.has_action("journal"):
		InputMap.add_action("journal")
		var jk := InputEventKey.new()
		jk.physical_keycode = KEY_J
		InputMap.action_add_event("journal", jk)
		var jb := InputEventJoypadButton.new()
		jb.button_index = JOY_BUTTON_START
		InputMap.action_add_event("journal", jb)
	for aktion in AKTIONEN:
		if not InputMap.has_action(aktion):
			continue
		for taste: int in AKTIONEN[aktion]:
			var e := InputEventJoypadButton.new()
			e.button_index = taste as JoyButton
			InputMap.action_add_event(aktion, e)
	var rt := InputEventJoypadMotion.new()
	rt.axis = JOY_AXIS_TRIGGER_RIGHT
	rt.axis_value = 1.0
	InputMap.action_add_event("zaubern", rt)
	var overlay := CanvasLayer.new()
	overlay.set_script(TOUCH_OVERLAY)
	add_child(overlay)
	if DisplayServer.is_touchscreen_available() and OS.has_feature("mobile") or TOUCH_ARGUMENT in OS.get_cmdline_user_args():
		_geraet_setzen(Geraet.TOUCH)
	_herzen_alt = GameState.herzen
	EventBus.herzen_geaendert.connect(_herzen_geaendert)
	EventBus.spieler_gestorben.connect(func() -> void: vibrieren(RUMBLE_TOD.x, RUMBLE_TOD.y, RUMBLE_TOD.z))


func _zusatz_aktion(aktion: String, tasten: Array, pad_knopf: JoyButton) -> void:
	if InputMap.has_action(aktion):
		return
	InputMap.add_action(aktion)
	for taste: Key in tasten:
		var k := InputEventKey.new()
		k.physical_keycode = taste
		InputMap.action_add_event(aktion, k)
	var b := InputEventJoypadButton.new()
	b.button_index = pad_knopf
	InputMap.action_add_event(aktion, b)


## Merkt sich, welches Geraet zuletzt benutzt wurde (fuer Tastenhinweise und das Touch-Overlay).
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_geraet_setzen(Geraet.TOUCH)
	elif event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > PAD_ERKENNUNG):
		_geraet_setzen(Geraet.PAD)
	elif event is InputEventKey or (event is InputEventMouse and event.device != InputEvent.DEVICE_ID_EMULATION):
		# Aus Touch erzeugte Maus-Ereignisse (device -1) schalten nicht zurueck
		if not (event is InputEventMouseMotion and geraet == Geraet.PAD):
			_geraet_setzen(Geraet.TASTATUR)


func _geraet_setzen(neu: int) -> void:
	if neu == geraet:
		return
	geraet = neu
	if neu != Geraet.TOUCH:
		touch_stick = Vector2.ZERO
		_touch_blick = Vector2.ZERO
	geraet_geaendert.emit(neu)


func ist_touch() -> bool:
	return geraet == Geraet.TOUCH


## Radiale Totzone plus Kurve fuer einen Stick.
func _stick(v: Vector2, kurve: float) -> Vector2:
	var l := v.length()
	if l < STICK_TOTZONE:
		return Vector2.ZERO
	var staerke := pow(clampf((l - STICK_TOTZONE) / (1.0 - STICK_TOTZONE), 0.0, 1.0), kurve)
	return v / l * staerke


## Staerkster Ausschlag aller angeschlossenen Pads fuer ein Achsenpaar.
func _pad_stick(achse_x: JoyAxis, achse_y: JoyAxis, kurve: float) -> Vector2:
	var bester := Vector2.ZERO
	for pad in Input.get_connected_joypads():
		var v := _stick(Vector2(Input.get_joy_axis(pad, achse_x), Input.get_joy_axis(pad, achse_y)), kurve)
		if v.length() > bester.length():
			bester = v
	return bester


## Laufen und Drehen: Tastatur/Steuerkreuz (ui_*), linker Stick (analog) oder Touch-Stick.
func bewegung() -> Vector2:
	var v := Vector2(Input.get_axis("ui_left", "ui_right"), Input.get_axis("ui_down", "ui_up"))
	# Tasten und Steuerkreuz liefern volle Werte; halbe Werte stammen vom Stick ueber die ui_*-Aktionen
	if absf(v.x) < 1.0:
		v.x = 0.0
	if absf(v.y) < 1.0:
		v.y = 0.0
	var stick := _pad_stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, LAUF_KURVE)
	stick.y = -stick.y
	if stick.length() > v.length():
		v = stick
	if touch_stick.length() > v.length():
		v = touch_stick
	return v.clampf(-1.0, 1.0)


## Umsehen mit dem rechten Stick (x rechts, y unten).
func blick() -> Vector2:
	return _pad_stick(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y, BLICK_KURVE)


func touch_blick_addieren(strecke: Vector2) -> void:
	_touch_blick += strecke


func touch_blick_nehmen() -> Vector2:
	var v := _touch_blick
	_touch_blick = Vector2.ZERO
	return v


## Beschriftung einer Aktion fuer das aktuelle Geraet.
func taste(aktion: String) -> String:
	if not TASTEN.has(aktion):
		return aktion.to_upper()
	return TASTEN[aktion][geraet]


## Haelt den Text eines Labels (Label3D oder Label) passend zum Geraet, z. B. "%s: SPRECHEN".
func hinweis_binden(label: Node, aktion: String, format: String) -> void:
	label.set("text", format % taste(aktion))
	geraet_geaendert.connect(func(_g: int) -> void:
		if is_instance_valid(label):
			label.set("text", format % taste(aktion)))


func vibrieren(schwach: float, stark: float, dauer: float) -> void:
	for pad in Input.get_connected_joypads():
		Input.start_joy_vibration(pad, schwach, stark, dauer)
	if ist_touch():
		Input.vibrate_handheld(int(dauer * 1000.0))


func _herzen_geaendert(herzen: int) -> void:
	if herzen < _herzen_alt:
		vibrieren(RUMBLE_TREFFER.x, RUMBLE_TREFFER.y, RUMBLE_TREFFER.z)
	_herzen_alt = herzen
