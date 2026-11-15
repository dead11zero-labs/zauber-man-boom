extends CanvasLayer
## Etagen-Auswahl am Aufzug-Terminal im Zauber-Tower (geoeffnet von levels/aufzug.gd).
## Zeigt die Etagenliste (Index 0 = Lobby, letzter = HQ) als scrollende Liste mit Markierung.
## Bedienung: Hoch/Runter waehlen (Bild hoch/runter springt 5), E / Enter / Pad A faehrt, Esc bricht ab.
## Sperrt die Spieler-Eingabe (EventBus.eingabe_gesperrt, Grund "aufzug").
## Exportierte Variablen: namen (Etagennamen), aktuell (Etage, an der die Kabine steht).
## Signal: gewaehlt(index: int) beim Bestaetigen einer anderen Etage. Entfernt sich danach selbst.

signal gewaehlt(index: int)

const NEON := preload("res://ui/neon.gd")
const SPERRE_GRUND := "aufzug"
const EBENE := 27
const BREITE := 560.0
const ZEILE := 40.0
const SICHTBAR := 9
const KOPF := 74.0
const FUSS := 44.0
const SPRUNG := 5
const EINGABE_PAUSE_MS := 200
const SCHRIFT := 22

@export var namen := PackedStringArray()
@export var aktuell := 0

var _auswahl := 0
var _ui: Control
var _ignorieren_bis := 0


func _ready() -> void:
	layer = EBENE
	_auswahl = clampi(aktuell, 0, maxi(namen.size() - 1, 0))
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.draw.connect(_zeichnen)
	add_child(_ui)
	_ignorieren_bis = Time.get_ticks_msec() + EINGABE_PAUSE_MS
	EventBus.eingabe_gesperrt.emit(SPERRE_GRUND, true)


func _input(event: InputEvent) -> void:
	if Time.get_ticks_msec() < _ignorieren_bis:
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		_schliessen()
	elif event.is_action_pressed("ui_up"):
		_auswahl = clampi(_auswahl + 1, 0, namen.size() - 1)  # oben in der Liste = hoehere Etage
	elif event.is_action_pressed("ui_down"):
		_auswahl = clampi(_auswahl - 1, 0, namen.size() - 1)
	elif event.is_action_pressed("ui_page_up"):
		_auswahl = clampi(_auswahl + SPRUNG, 0, namen.size() - 1)
	elif event.is_action_pressed("ui_page_down"):
		_auswahl = clampi(_auswahl - SPRUNG, 0, namen.size() - 1)
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interagieren"):
		if _auswahl != aktuell:
			gewaehlt.emit(_auswahl)
		_schliessen()
	else:
		return
	get_viewport().set_input_as_handled()
	_ui.queue_redraw()


func _schliessen() -> void:
	EventBus.eingabe_gesperrt.emit(SPERRE_GRUND, false)
	queue_free()


func _zeichnen() -> void:
	var f := NEON.font()
	var vp := _ui.size
	var hoehe := KOPF + SICHTBAR * ZEILE + FUSS
	var r := Rect2((vp.x - BREITE) * 0.5, (vp.y - hoehe) * 0.5, BREITE, hoehe)
	_ui.draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 0.45))
	NEON.rahmen(_ui, r, NEON.CYAN)
	_ui.draw_string(f, r.position + Vector2(24, 36), "AUFZUG  //  ETAGE WÄHLEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, NEON.CYAN)
	_ui.draw_line(r.position + Vector2(20, 50), r.position + Vector2(BREITE - 20, 50), Color(NEON.CYAN, 0.4), 1.0)
	# Fenster der Liste: Auswahl moeglichst mittig, hoehere Etagen oben
	var erste := clampi(_auswahl + SICHTBAR / 2, SICHTBAR - 1, maxi(namen.size() - 1, SICHTBAR - 1))
	for i in SICHTBAR:
		var idx := erste - i
		if idx < 0 or idx >= namen.size():
			continue
		var y := r.position.y + KOPF + i * ZEILE
		var gewaehlt_zeile := idx == _auswahl
		if gewaehlt_zeile:
			_ui.draw_rect(Rect2(r.position.x + 16, y, BREITE - 32, ZEILE - 4), Color(NEON.CYAN, 0.22))
			_ui.draw_rect(Rect2(r.position.x + 16, y, 4, ZEILE - 4), NEON.GELB)
		var farbe := NEON.GELB if gewaehlt_zeile else Color(0.75, 0.92, 0.95, 0.85)
		var nr := "EG" if idx == 0 else ("HQ" if idx == namen.size() - 1 else "%02d" % idx)
		_ui.draw_string(f, Vector2(r.position.x + 32, y + 26), nr, HORIZONTAL_ALIGNMENT_LEFT, -1, SCHRIFT, farbe)
		_ui.draw_string(f, Vector2(r.position.x + 100, y + 26), String(namen[idx]), HORIZONTAL_ALIGNMENT_LEFT, int(BREITE - 200), SCHRIFT, farbe)
		if idx == aktuell:
			_ui.draw_string(f, Vector2(r.end.x - 110, y + 26), "HIER", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(NEON.MAGENTA, 0.9))
	_ui.draw_string(f, r.position + Vector2(24, hoehe - 16), "↑↓ WÄHLEN   E FAHREN   ESC ZURÜCK", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.75, 0.92, 0.95, 0.6))
