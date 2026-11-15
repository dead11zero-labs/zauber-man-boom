extends Control
## Journal-Overlay (Taste J, Pad Start): Reiter ZIELE (aktives Ziel, erledigte Ziele) und DATENCHIPS (Lore-Texte).
## Bedienung: ui_left/ui_right (oder Tab) wechselt den Reiter, ui_up/ui_down waehlt einen Chip, J oder Esc schliesst.
## Sperrt die Spieler-Eingabe (EventBus.eingabe_gesperrt, Grund "journal"). Wird von hud.gd erzeugt.
## Chip-Daten: GameState.chips (ids) -> res://data/sammelobjekte/<id>.tres (CollectibleData.lore).

const NEON := preload("res://ui/neon.gd")
const SPERRE_GRUND := "journal"
const BREITE := 900.0
const HOEHE := 540.0
const INNEN := 30.0
const KOPF := 88.0
const LISTE_BREITE := 270.0
const ZEILE := 30.0
const LORE_GROESSE := 17
const REITER: Array[String] = ["ZIELE", "DATENCHIPS"]
const CHIP_PFAD := "res://data/sammelobjekte/%s.tres"

var _offen := false
var _reiter := 0
var _auswahl := 0
var _lore: Label
var _zeit := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	offset_left = -BREITE * 0.5
	offset_right = BREITE * 0.5
	offset_top = -HOEHE * 0.5
	offset_bottom = HOEHE * 0.5
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_lore = NEON.label(LORE_GROESSE, Color(0.9, 0.97, 1.0))
	_lore.position = Vector2(INNEN + LISTE_BREITE + 24.0, KOPF + 56.0)
	_lore.size = Vector2(BREITE - INNEN * 2.0 - LISTE_BREITE - 24.0, HOEHE - KOPF - 90.0)
	add_child(_lore)


func _exit_tree() -> void:
	if _offen:
		EventBus.eingabe_gesperrt.emit(SPERRE_GRUND, false)


func umschalten() -> void:
	_offen = not _offen
	visible = _offen
	if _offen:
		_auswahl = 0
		_aktualisieren()
	EventBus.eingabe_gesperrt.emit(SPERRE_GRUND, _offen)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("journal"):
		if not _offen and (Dialog.aktiv or get_tree().get_first_node_in_group("shop_offen") != null):
			return
		umschalten()
		get_viewport().set_input_as_handled()
		return
	if not _offen:
		return
	if event.is_action_pressed("ui_cancel"):
		umschalten()
	elif event.is_action_pressed("ui_right") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB):
		_reiter = (_reiter + 1) % REITER.size()
		_auswahl = 0
	elif event.is_action_pressed("ui_left"):
		_reiter = (_reiter - 1 + REITER.size()) % REITER.size()
		_auswahl = 0
	elif event.is_action_pressed("ui_down"):
		_auswahl = mini(_auswahl + 1, maxi(GameState.chips.size() - 1, 0))
	elif event.is_action_pressed("ui_up"):
		_auswahl = maxi(_auswahl - 1, 0)
	else:
		return
	_aktualisieren()
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _offen:
		_zeit += delta
		queue_redraw()


## Loest eine Chip-id in CollectibleData auf, null wenn es die Datei nicht gibt.
func chip_daten(id: String) -> Resource:
	var pfad := CHIP_PFAD % id
	return load(pfad) if ResourceLoader.exists(pfad) else null


## Lore-Text eines Chips (Fallback: der kurze `text`)
func chip_text(id: String) -> String:
	var d := chip_daten(id)
	if d == null:
		return ""
	return String(d.lore) if String(d.lore) != "" else String(d.text)


func _aktualisieren() -> void:
	if _reiter == 1 and _auswahl < GameState.chips.size():
		_lore.text = chip_text(GameState.chips[_auswahl])
	else:
		_lore.text = ""
	_lore.visible = _reiter == 1
	queue_redraw()


func _draw() -> void:
	var f := NEON.font()
	var r := Rect2(Vector2.ZERO, size)
	NEON.rahmen(self, r, NEON.CYAN)
	draw_string(f, Vector2(INNEN, 40.0), "// JOURNAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, NEON.CYAN)
	for i in REITER.size():
		var x := INNEN + i * 190.0
		var an := i == _reiter
		draw_rect(Rect2(x, 52.0, 176.0, 30.0), Color(NEON.MAGENTA, 0.22 if an else 0.05))
		if an:
			draw_rect(Rect2(x, 80.0, 176.0, 3.0), NEON.MAGENTA)
		draw_string(f, Vector2(x + 12.0, 74.0), REITER[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, NEON.MAGENTA if an else Color(NEON.CYAN, 0.7))
	draw_string(f, Vector2(INNEN, r.size.y - 20.0), "LINKS/RECHTS: REITER   AUF/AB: WÄHLEN   J: SCHLIESSEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(NEON.CYAN, 0.65))
	if _reiter == 0:
		_zeichne_ziele(f)
	else:
		_zeichne_chips(f)


func _zeichne_ziele(f: SystemFont) -> void:
	var y := KOPF + 30.0
	var q := QuestManager.aktive()
	draw_string(f, Vector2(INNEN, y), "AKTUELLES ZIEL", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(NEON.GELB, 0.8))
	if q == null:
		draw_string(f, Vector2(INNEN, y + 32.0), "Kein offenes Ziel. Die Stadt wartet.", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(NEON.CYAN, 0.8))
		y += 70.0
	else:
		draw_string(f, Vector2(INNEN, y + 32.0), "> " + String(q.ziel).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, NEON.GELB)
		draw_multiline_string(f, Vector2(INNEN, y + 62.0), String(q.beschreibung), HORIZONTAL_ALIGNMENT_LEFT, BREITE - INNEN * 2.0, 16, 3, Color(0.85, 0.95, 1.0, 0.85))
		y += 130.0
	draw_string(f, Vector2(INNEN, y), "ERLEDIGT", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(NEON.CYAN, 0.7))
	var n := 0
	for id in GameState.quests_fertig:
		var d := QuestManager.daten(id)
		var titel: String = id if d == null else String(d.ziel)
		draw_string(f, Vector2(INNEN, y + 28.0 + n * 26.0), "[x] " + titel, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(NEON.CYAN, 0.6))
		n += 1
	if n == 0:
		draw_string(f, Vector2(INNEN, y + 28.0), "Noch nichts. Fang einfach an.", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(NEON.CYAN, 0.45))


func _zeichne_chips(f: SystemFont) -> void:
	var y := KOPF + 30.0
	draw_string(f, Vector2(INNEN, y), "GEFUNDEN: %d" % GameState.chips.size(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(NEON.GELB, 0.8))
	if GameState.chips.is_empty():
		draw_string(f, Vector2(INNEN, y + 40.0), "Noch kein Datenchip gefunden.", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(NEON.CYAN, 0.6))
		return
	for i in GameState.chips.size():
		var d := chip_daten(GameState.chips[i])
		var titel: String = GameState.chips[i] if d == null else String(d.titel)
		var an := i == _auswahl
		var rr := Rect2(INNEN - 8.0, y + 14.0 + i * ZEILE, LISTE_BREITE, ZEILE - 4.0)
		if an:
			draw_rect(rr, Color(NEON.MAGENTA, 0.16))
			draw_rect(rr, Color(NEON.MAGENTA, 0.9), false, 1.5)
		draw_string(f, Vector2(INNEN, y + 34.0 + i * ZEILE), titel, HORIZONTAL_ALIGNMENT_LEFT, int(LISTE_BREITE - 16.0), 16, NEON.GELB if an else NEON.CYAN)
	if _auswahl < GameState.chips.size():
		var d2 := chip_daten(GameState.chips[_auswahl])
		var t2: String = "" if d2 == null else String(d2.titel).to_upper()
		draw_string(f, Vector2(INNEN + LISTE_BREITE + 24.0, KOPF + 42.0), t2, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, NEON.MAGENTA)
