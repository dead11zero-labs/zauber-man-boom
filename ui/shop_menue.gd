extends CanvasLayer
## Upgrade-Shop (Neon-UI): drei Upgrades aus data/upgrades/*.tres, bezahlt mit Mana-Kernen (GameState.mana_kerne).
## Bedienung: ui_up/ui_down waehlen, E / Enter / Pad A kauft die naechste Stufe, Esc / Pad B schliesst.
## Sperrt die Spieler-Eingabe (EventBus.eingabe_gesperrt, Grund "shop") und gibt sie beim Schliessen wieder frei.
## Kauflogik steckt in GameState.upgrade_kaufen(). Keine Exporte, keine eigenen Signale.
## Wird vom Haendler (characters/rollen_npc.gd) erzeugt und entfernt sich selbst.

const NEON := preload("res://ui/neon.gd")
const UPGRADE_IDS: Array[String] = ["blitzschaden", "blitzreichweite", "ladegeschwindigkeit"]
const SPERRE_GRUND := "shop"
const EBENE := 25
const BREITE := 760.0
const HOEHE := 470.0
const ZEILE_HOEHE := 92.0
const LISTE_OBEN := 120.0
const INNEN := 28.0
const EINGABE_PAUSE_MS := 200
const MELDUNG_DAUER := 2.0

var _ui: Control
var _wahl := 0
var _meldung := ""
var _meldung_farbe := NEON.CYAN
var _meldung_zeit := 0.0
var _zeit := 0.0
var _ignorieren_bis := 0


func _ready() -> void:
	add_to_group("shop_offen")
	layer = EBENE
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_CENTER)
	_ui.offset_left = -BREITE * 0.5
	_ui.offset_right = BREITE * 0.5
	_ui.offset_top = -HOEHE * 0.5
	_ui.offset_bottom = HOEHE * 0.5
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.draw.connect(_zeichnen)
	add_child(_ui)
	_ignorieren_bis = Time.get_ticks_msec() + EINGABE_PAUSE_MS
	EventBus.eingabe_gesperrt.emit(SPERRE_GRUND, true)


func _process(delta: float) -> void:
	_zeit += delta
	_meldung_zeit = maxf(_meldung_zeit - delta, 0.0)
	_ui.queue_redraw()


func _input(event: InputEvent) -> void:
	if Time.get_ticks_msec() < _ignorieren_bis:
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_down"):
		_wahl = (_wahl + 1) % UPGRADE_IDS.size()
	elif event.is_action_pressed("ui_up"):
		_wahl = (_wahl - 1 + UPGRADE_IDS.size()) % UPGRADE_IDS.size()
	elif event.is_action_pressed("interagieren") or event.is_action_pressed("ui_accept"):
		_kaufen()
	elif event.is_action_pressed("ui_cancel"):
		schliessen()
	else:
		return
	get_viewport().set_input_as_handled()


func _kaufen() -> void:
	var id := UPGRADE_IDS[_wahl]
	var d := GameState.upgrade_daten(id)
	if d == null:
		return
	var stufe := GameState.upgrade_stufe(id)
	if stufe >= d.max_stufe():
		_nachricht("BEREITS AUF MAXIMUM", NEON.GELB)
	elif GameState.upgrade_kaufen(id):
		_nachricht("GEKAUFT // STUFE %d" % (stufe + 1), NEON.CYAN)
	else:
		_nachricht("ZU WENIG MANA-KERNE", NEON.ROT)


func _nachricht(text: String, farbe: Color) -> void:
	_meldung = text
	_meldung_farbe = farbe
	_meldung_zeit = MELDUNG_DAUER


func schliessen() -> void:
	remove_from_group("shop_offen")
	EventBus.eingabe_gesperrt.emit(SPERRE_GRUND, false)
	queue_free()


func _zeichnen() -> void:
	var f := NEON.font()
	var r := Rect2(Vector2.ZERO, _ui.size)
	NEON.rahmen(_ui, r, NEON.GELB)
	_ui.draw_string(f, Vector2(INNEN, 40.0), "// HÄNDLER // UPGRADES", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, NEON.GELB)
	_ui.draw_string(f, Vector2(INNEN, 74.0), "MANA-KERNE: %03d" % GameState.mana_kerne, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, NEON.CYAN)
	for i in UPGRADE_IDS.size():
		_zeile(i, f)
	var hinweis := "AUF/AB: WÄHLEN   E: KAUFEN   ESC: SCHLIESSEN"
	_ui.draw_string(f, Vector2(INNEN, r.size.y - 22.0), hinweis, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(NEON.CYAN, 0.7))
	if _meldung_zeit > 0.0:
		var a := clampf(_meldung_zeit, 0.0, 1.0)
		_ui.draw_string(f, Vector2(r.size.x - 330.0, 74.0), _meldung, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(_meldung_farbe, a))


func _zeile(i: int, f: SystemFont) -> void:
	var id := UPGRADE_IDS[i]
	var d := GameState.upgrade_daten(id)
	var y := LISTE_OBEN + i * ZEILE_HOEHE
	var an := i == _wahl
	var box := Rect2(INNEN - 10.0, y - 6.0, _ui.size.x - INNEN * 2.0 + 20.0, ZEILE_HOEHE - 10.0)
	_ui.draw_rect(box, Color(NEON.GELB, 0.1 if an else 0.03))
	if an:
		_ui.draw_rect(box, Color(NEON.GELB, 0.9), false, 2.0)
	if d == null:
		_ui.draw_string(f, Vector2(INNEN, y + 24.0), id + " (fehlt)", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, NEON.ROT)
		return
	var stufe := GameState.upgrade_stufe(id)
	_ui.draw_string(f, Vector2(INNEN, y + 22.0), String(d.titel).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, NEON.GELB if an else NEON.CYAN)
	_ui.draw_string(f, Vector2(INNEN, y + 46.0), String(d.beschreibung), HORIZONTAL_ALIGNMENT_LEFT, int(_ui.size.x - 2.0 * INNEN - 200.0), 14, Color(0.85, 0.95, 1.0, 0.8))
	# Stufenanzeige
	for s in d.max_stufe():
		var sr := Rect2(INNEN + s * 34.0, y + 56.0, 26.0, 10.0)
		_ui.draw_rect(sr, NEON.MAGENTA if s < stufe else Color(NEON.MAGENTA, 0.18))
	var wirkung := "+%d%%" % roundi(GameState.upgrade_bonus(id) * 100.0) if stufe > 0 else "--"
	_ui.draw_string(f, Vector2(INNEN + 3.0 * 34.0 + 12.0, y + 66.0), "AKTUELL " + wirkung, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, NEON.MAGENTA)
	var preis := "MAX" if stufe >= d.max_stufe() else "%d KERNE" % d.kosten_fuer_stufe(stufe + 1)
	var kann: bool = stufe < d.max_stufe() and GameState.mana_kerne >= d.kosten_fuer_stufe(stufe + 1)
	_ui.draw_string(f, Vector2(_ui.size.x - INNEN - 150.0, y + 30.0), preis, HORIZONTAL_ALIGNMENT_RIGHT, 150, 20, NEON.GELB if kann else Color(NEON.ROT, 0.9) if stufe < d.max_stufe() else NEON.CYAN)
