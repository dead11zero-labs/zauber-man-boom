extends CanvasLayer
## Dialog (DialogueRunner + Dialog-UI): spielt DialogDaten-Resources ab.
## Neon-Textbox unten, Name des Sprechers, Tippeffekt, Weiter mit E / Enter / Leertaste / Pad A (Y),
## Auswahlantworten mit ui_up/ui_down. Sperrt waehrenddessen die Spieler-Eingabe (EventBus.eingabe_gesperrt).
## Hat eine Zeile einen audio-Pfad und existiert die Datei, wird sie abgespielt, sonst nur Text.
## Signale: ueber EventBus dialog_gestartet(id) / dialog_beendet(id, antwort).
## Aufruf: Dialog.starten(Dialog.laden("intro")) oder Dialog.starten(preload(...)).

const NEON := preload("res://ui/neon.gd")
const DIALOG_PFAD := "res://data/dialoge/%s.tres"
const SPERRE_GRUND := "dialog"
const EBENE := 20
const TIPP_TEMPO := 60.0  ## Zeichen pro Sekunde
const BREITE_MAX := 920.0
const RAND_SEITE := 40.0
const RAND_UNTEN := 36.0
const HOEHE := 260.0
const INNEN := 26.0
const TEXT_GROESSE := 22
const NAME_GROESSE := 17
const WAHL_GROESSE := 20
const WAHL_ZEILE := 28.0
const EINGABE_PAUSE_MS := 200  ## nach dem Start ignoriert der Runner Eingaben kurz (E-Druck vom NPC)
const TEXT_OBEN := 54.0
const TEXT_HOEHE := 90.0

var aktiv := false

var _daten: Resource
var _index := 0
var _zeichen := 0.0
var _fertig := false
var _wahl := 0
var _letzte_antwort := -1
var _ignorieren_bis := 0
var _zeit := 0.0
var _ui: Control
var _text: Label
var _audio: AudioStreamPlayer


func _ready() -> void:
	layer = EBENE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ui = Control.new()
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.anchor_left = 0.0
	_ui.anchor_right = 1.0
	_ui.anchor_top = 1.0
	_ui.anchor_bottom = 1.0
	_ui.offset_top = -(HOEHE + RAND_UNTEN)
	_ui.offset_bottom = -RAND_UNTEN
	_ui.offset_left = RAND_SEITE
	_ui.offset_right = -RAND_SEITE
	_ui.draw.connect(_zeichnen)
	_ui.resized.connect(_layout)
	add_child(_ui)
	_text = NEON.label(TEXT_GROESSE, Color(0.9, 0.97, 1.0))
	_ui.add_child(_text)
	_audio = AudioStreamPlayer.new()
	_audio.bus = &"Master"
	add_child(_audio)
	_ui.visible = false


## Laedt data/dialoge/<id>.tres, null wenn es die Datei nicht gibt.
func laden(id: String) -> Resource:
	var pfad := DIALOG_PFAD % id
	return load(pfad) if ResourceLoader.exists(pfad) else null


func starten(daten: Resource) -> void:
	if aktiv or daten == null or daten.zeilen.is_empty():
		return
	_daten = daten
	aktiv = true
	_ignorieren_bis = Time.get_ticks_msec() + EINGABE_PAUSE_MS
	_letzte_antwort = -1
	_ui.visible = true
	EventBus.eingabe_gesperrt.emit(SPERRE_GRUND, true)
	EventBus.dialog_gestartet.emit(daten.id)
	_zeile_zeigen(0)


func beenden() -> void:
	if not aktiv:
		return
	aktiv = false
	_audio.stop()
	_ui.visible = false
	var id: String = _daten.id
	_daten = null
	EventBus.eingabe_gesperrt.emit(SPERRE_GRUND, false)
	EventBus.dialog_beendet.emit(id, _letzte_antwort)


func _zeile_zeigen(i: int) -> void:
	_index = i
	_zeichen = 0.0
	_fertig = false
	_wahl = 0
	var z: Resource = _daten.zeilen[i]
	_text.text = z.text
	_text.visible_characters = 0
	_layout()
	_audio.stop()
	var pfad: String = z.audio
	if pfad != "" and ResourceLoader.exists(pfad):
		var s := load(pfad) as AudioStream
		if s != null:
			_audio.stream = s
			_audio.play()


func _layout() -> void:
	if _text == null or _ui == null:
		return
	_text.position = Vector2(INNEN, TEXT_OBEN)
	_text.size = Vector2(_ui.size.x - INNEN * 2.0, TEXT_HOEHE)


func _process(delta: float) -> void:
	if not aktiv:
		return
	_zeit += delta
	if not _fertig:
		_zeichen += TIPP_TEMPO * delta
		_text.visible_characters = int(_zeichen)
		if _zeichen >= _text.text.length():
			_fertig = true
			_text.visible_characters = -1
	_ui.queue_redraw()


func _input(event: InputEvent) -> void:
	if not aktiv or Time.get_ticks_msec() < _ignorieren_bis:
		return
	var z: Resource = _daten.zeilen[_index]
	var hat_wahl: bool = _fertig and z.antworten.size() > 0
	if event.is_action_pressed("ui_cancel") and _daten.ueberspringbar:
		get_viewport().set_input_as_handled()
		beenden()
		return
	if hat_wahl and event.is_action_pressed("ui_down"):
		_wahl = (_wahl + 1) % z.antworten.size()
	elif hat_wahl and event.is_action_pressed("ui_up"):
		_wahl = (_wahl - 1 + z.antworten.size()) % z.antworten.size()
	elif event.is_action_pressed("interagieren") or event.is_action_pressed("ui_accept"):
		_weiter()
	else:
		return
	get_viewport().set_input_as_handled()


func _weiter() -> void:
	var z: Resource = _daten.zeilen[_index]
	if not _fertig:
		_fertig = true
		_text.visible_characters = -1
		return
	var ziel := _index + 1
	if z.antworten.size() > 0:
		_letzte_antwort = _wahl
		if z.antwort_ziele.size() > _wahl:
			ziel = z.antwort_ziele[_wahl]
	if ziel < 0 or ziel >= _daten.zeilen.size():
		beenden()
	else:
		_zeile_zeigen(ziel)


func _zeichnen() -> void:
	if _daten == null:
		return
	var z: Resource = _daten.zeilen[_index]
	var r := Rect2(Vector2.ZERO, _ui.size)
	NEON.rahmen(_ui, r, NEON.CYAN)
	_ui.draw_polyline(PackedVector2Array([Vector2(r.size.x - 80, 0), Vector2(r.size.x, 0), Vector2(r.size.x, r.size.y - NEON.ECKE)]), NEON.MAGENTA, 3.0)
	# Namensschild
	var name_text := "// " + String(z.sprecher).to_upper()
	var f := NEON.font()
	var nb := f.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_GROESSE).x
	_ui.draw_rect(Rect2(INNEN - 10.0, 14.0, nb + 20.0, 28.0), Color(NEON.MAGENTA, 0.18))
	_ui.draw_rect(Rect2(INNEN - 10.0, 14.0, 4.0, 28.0), NEON.MAGENTA)
	_ui.draw_string(f, Vector2(INNEN, 34.0), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_GROESSE, NEON.MAGENTA)
	if _audio.playing:
		_ui.draw_string(f, Vector2(r.size.x - 130.0, 34.0), "STIMME >>", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(NEON.CYAN, 0.7))
	# Auswahl oder Weiter-Hinweis
	if _fertig and z.antworten.size() > 0:
		var y := TEXT_OBEN + TEXT_HOEHE + 22.0
		for i in z.antworten.size():
			var an: bool = i == _wahl
			var farbe: Color = NEON.GELB if an else Color(NEON.CYAN, 0.8)
			var zeile_rect := Rect2(INNEN - 8.0, y + i * WAHL_ZEILE - 20.0, r.size.x - INNEN * 2.0 + 16.0, WAHL_ZEILE - 2.0)
			if an:
				_ui.draw_rect(zeile_rect, Color(NEON.GELB, 0.12))
			_ui.draw_string(f, Vector2(INNEN, y + i * WAHL_ZEILE), ("> " if an else "  ") + String(z.antworten[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, WAHL_GROESSE, farbe)
	elif _fertig:
		var a := 0.5 + 0.5 * sin(_zeit * 6.0)
		_ui.draw_string(f, Vector2(r.size.x - 190.0, r.size.y - 18.0), "[E] WEITER  v", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(NEON.GELB, a))
	if _daten.ueberspringbar:
		_ui.draw_string(f, Vector2(INNEN, r.size.y - 18.0), "ESC: ÜBERSPRINGEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(NEON.CYAN, 0.5))
