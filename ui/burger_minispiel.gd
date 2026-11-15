extends CanvasLayer
## Burger-Bau (Minispiel bei Sy-Ci Burgers, gestartet vom Bedienroboter an der Theke, siehe burger.gd).
## Ablauf: 3 Bestellungen (4, 6, 8 Schichten). Der Burger wird Schicht fuer Schicht nach Vorlage gestapelt,
## das obere Broetchen schliesst ihn ab und gibt ihn ab. Zeitlimit pro Runde, Fehlversuche kosten Zeit.
## Bedienung: Pfeile/Pad-Kreuz waehlen Zutat, E / Enter / Pad A / Leertaste legt sie auf, Zifferntasten 1..0 direkt,
## Rueckschritt oder Dash-Taste nimmt die oberste Schicht weg, Esc bricht ab.
## Sperrt die Spieler-Eingabe (EventBus.eingabe_gesperrt, Grund "burger").
## Belohnung: Mana-Kerne (KERNE_PRO_BURGER, KERNE_BONUS bei 3 von 3), nur bis zum ersten fehlerfreien Durchgang
## (Flag FLAG_PERFEKT in GameState). Danach geht es nur um Punkte.
## Signal: beendet(richtige: int, punkte: int) beim Schliessen nach einem vollstaendigen Durchgang.
## Keine Exporte. Wird von burger.gd erzeugt und entfernt sich selbst.

signal beendet(richtige: int, punkte: int)

const NEON := preload("res://ui/neon.gd")
const SPERRE_GRUND := "burger"
const FLAG_PERFEKT := "burger_minispiel_perfekt"
const EBENE := 26
const BREITE := 1040.0
const HOEHE := 600.0
const INNEN := 28.0
const EINGABE_PAUSE_MS := 200
const RUNDEN := 3
const FUELLUNGEN_START := 2          ## Schichten zwischen den Broetchen in Runde 1
const FUELLUNGEN_SCHRITT := 2        ## pro weitere Runde mehr
const ZEIT_BASIS := 20.0             ## Sekunden pro Runde plus ZEIT_PRO_FUELLUNG je Fuellung
const ZEIT_PRO_FUELLUNG := 8.0
const FEHLER_STRAFE := 5.0           ## Sekunden Abzug fuer einen falschen Burger
const PUNKTE_BASIS := 100
const PUNKTE_PRO_SEKUNDE := 10
const KERNE_PRO_BURGER := 1
const KERNE_BONUS := 3
const STAPEL_MAX := 14
const MELDUNG_DAUER := 2.2
const SPALTEN := 5
const KACHEL_B := 88.0
const KACHEL_H := 104.0
const KACHEL_ABSTAND := 14.0
const BURGER_BREITE := 190.0
const SCHICHT_SKALA := 1.0

enum Phase { INTRO, SPIEL, RUNDE_ENDE, ENDE }

## Zutaten: [Name, Farbe, Hoehe in Pixeln]. Index 0 = Broetchen unten, 1 = Broetchen oben.
const ZUTATEN := [
	["BRÖTCHEN UNTEN", Color(0.88, 0.58, 0.22), 22.0],
	["BRÖTCHEN OBEN", Color(0.92, 0.6, 0.22), 34.0],
	["PATTY", Color(0.38, 0.17, 0.09), 24.0],
	["KÄSE", Color(1.0, 0.8, 0.12), 9.0],
	["SALAT", Color(0.35, 0.82, 0.25), 13.0],
	["TOMATE", Color(0.9, 0.12, 0.1), 13.0],
	["GURKE", Color(0.3, 0.6, 0.2), 9.0],
	["ZWIEBEL", Color(0.88, 0.75, 0.9), 8.0],
	["BACON", Color(0.85, 0.3, 0.3), 9.0],
	["SOSSE", Color(1.0, 0.4, 0.1), 9.0],
]
const BROETCHEN_U := 0
const BROETCHEN_O := 1
const ERSTE_FUELLUNG := 2

const ROBOTER_TEXT := "WILLKOMMEN BEI SY-CI BURGERS. KUNDE 4711 WILL EXAKT DIESEN BURGER. ICH HABE KEINE FINGER FÜR SOWAS. SIE SCHON. BEEP."

var _ui: Control
var _phase := Phase.INTRO
var _runde := 0
var _auftrag: Array[int] = []
var _stapel: Array[int] = []
var _rest := 0.0
var _zeit_gesamt := 1.0
var _wahl := ERSTE_FUELLUNG
var _punkte := 0
var _richtige := 0
var _meldung := ""
var _meldung_farbe := NEON.CYAN
var _meldung_zeit := 0.0
var _runde_text := ""
var _runde_ok := false
var _belohnung := 0
var _zeit := 0.0
var _ignorieren_bis := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("burger_minispiel")
	layer = EBENE
	_rng.randomize()
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
	if _phase == Phase.SPIEL:
		_rest -= delta
		if _rest <= 0.0:
			_rest = 0.0
			_runde_beenden(false, "ZEIT ABGELAUFEN. DER KUNDE GEHT HUNGRIG.")
	_ui.queue_redraw()


# ---------------------------------------------------------------- Eingabe

func _input(event: InputEvent) -> void:
	if Time.get_ticks_msec() < _ignorieren_bis:
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		schliessen()
	elif event.is_action_pressed("interagieren") or event.is_action_pressed("ui_accept"):
		_bestaetigen()
	elif _phase == Phase.SPIEL and _spiel_eingabe(event):
		pass
	else:
		return
	get_viewport().set_input_as_handled()


func _spiel_eingabe(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_right"):
		_wahl_bewegen(1, 0)
	elif event.is_action_pressed("ui_left"):
		_wahl_bewegen(-1, 0)
	elif event.is_action_pressed("ui_down"):
		_wahl_bewegen(0, 1)
	elif event.is_action_pressed("ui_up"):
		_wahl_bewegen(0, -1)
	elif event.is_action_pressed("dash"):
		_zurueck()
	else:
		var k := event as InputEventKey
		if k == null or not k.pressed or k.echo:
			return false
		if k.keycode == KEY_BACKSPACE:
			_zurueck()
		elif _ziffer(k.keycode) >= 0:
			var i := _ziffer(k.keycode)
			if i < ZUTATEN.size():
				_wahl = i
				_auflegen(i)
		else:
			return false
	return true


func _ziffer(k: Key) -> int:
	if k >= KEY_1 and k <= KEY_9:
		return int(k) - int(KEY_1)
	if k == KEY_0:
		return 9
	return -1


func _wahl_bewegen(dx: int, dy: int) -> void:
	var n := ZUTATEN.size()
	var zeilen := ceili(float(n) / SPALTEN)
	var sp := _wahl % SPALTEN
	var ze := floori(float(_wahl) / SPALTEN)
	sp = (sp + dx + SPALTEN) % SPALTEN
	ze = (ze + dy + zeilen) % zeilen
	_wahl = mini(ze * SPALTEN + sp, n - 1)


func _bestaetigen() -> void:
	match _phase:
		Phase.INTRO:
			_runde_starten()
		Phase.SPIEL:
			_auflegen(_wahl)
		Phase.RUNDE_ENDE:
			if _runde + 1 >= RUNDEN:
				_ende_starten()
			else:
				_runde += 1
				_runde_starten()
		Phase.ENDE:
			schliessen()


# ---------------------------------------------------------------- Spiellogik

func _runde_starten() -> void:
	var fuellungen := FUELLUNGEN_START + FUELLUNGEN_SCHRITT * _runde
	_auftrag = _auftrag_wuerfeln(fuellungen)
	_stapel.clear()
	_zeit_gesamt = ZEIT_BASIS + ZEIT_PRO_FUELLUNG * fuellungen
	_rest = _zeit_gesamt
	_phase = Phase.SPIEL
	_wahl = ERSTE_FUELLUNG
	_nachricht("RUNDE %d: LOS!" % (_runde + 1), NEON.CYAN)


## Zufallsbestellung: unteres Broetchen, `fuellungen` Schichten (nie dieselbe zweimal hintereinander), oberes Broetchen.
func _auftrag_wuerfeln(fuellungen: int) -> Array[int]:
	var a: Array[int] = [BROETCHEN_U]
	var vorher := -1
	for i in fuellungen:
		var z := _rng.randi_range(ERSTE_FUELLUNG, ZUTATEN.size() - 1)
		while z == vorher:
			z = _rng.randi_range(ERSTE_FUELLUNG, ZUTATEN.size() - 1)
		a.append(z)
		vorher = z
	a.append(BROETCHEN_O)
	return a


func _auflegen(id: int) -> void:
	if _phase != Phase.SPIEL:
		return
	if _stapel.is_empty() and id != BROETCHEN_U:
		_nachricht("ERST DAS UNTERE BRÖTCHEN!", NEON.ROT)
		return
	if id == BROETCHEN_U and not _stapel.is_empty():
		_nachricht("UNTEN LIEGT SCHON EIN BRÖTCHEN", NEON.ROT)
		return
	if _stapel.size() >= STAPEL_MAX:
		_nachricht("DER BURGER IST SCHON ZU HOCH", NEON.ROT)
		return
	_stapel.append(id)
	if id == BROETCHEN_O:
		_abgeben()


func _zurueck() -> void:
	if _phase == Phase.SPIEL and not _stapel.is_empty():
		_stapel.pop_back()


func _abgeben() -> void:
	if _stapel == _auftrag:
		var bonus := int(_rest) * PUNKTE_PRO_SEKUNDE
		_punkte += PUNKTE_BASIS + bonus
		_richtige += 1
		_runde_beenden(true, "PERFEKT! +%d PUNKTE (ZEITBONUS %d)" % [PUNKTE_BASIS + bonus, bonus])
		return
	var fehler := 0
	for i in mini(_stapel.size(), _auftrag.size()):
		if _stapel[i] != _auftrag[i]:
			fehler = i + 1
			break
	if fehler == 0:
		fehler = mini(_stapel.size(), _auftrag.size()) + 1
	_stapel.clear()
	_rest = maxf(_rest - FEHLER_STRAFE, 0.0)
	_nachricht("FALSCH! SCHICHT %d STIMMT NICHT. -%d S" % [fehler, int(FEHLER_STRAFE)], NEON.ROT)


func _runde_beenden(ok: bool, text: String) -> void:
	_runde_ok = ok
	_runde_text = text
	_phase = Phase.RUNDE_ENDE


func _ende_starten() -> void:
	_phase = Phase.ENDE
	_belohnung = 0
	if not GameState.flag(FLAG_PERFEKT):
		_belohnung = _richtige * KERNE_PRO_BURGER
		if _richtige == RUNDEN:
			_belohnung += KERNE_BONUS
			GameState.flag_setzen(FLAG_PERFEKT)
		if _belohnung > 0:
			GameState.mana_kern_hinzu(_belohnung)
	EventBus.story_ereignis.emit("minispiel:burger_fertig")


func _nachricht(text: String, farbe: Color) -> void:
	_meldung = text
	_meldung_farbe = farbe
	_meldung_zeit = MELDUNG_DAUER


func schliessen() -> void:
	if _phase == Phase.ENDE:
		beendet.emit(_richtige, _punkte)
	remove_from_group("burger_minispiel")
	EventBus.eingabe_gesperrt.emit(SPERRE_GRUND, false)
	queue_free()


# ---------------------------------------------------------------- Zeichnen

func _zeichnen() -> void:
	var f := NEON.font()
	var r := Rect2(Vector2.ZERO, _ui.size)
	NEON.rahmen(_ui, r, NEON.MAGENTA)
	_ui.draw_string(f, Vector2(INNEN, 40.0), "// SY-CI BURGERS // BURGER-BAU", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, NEON.MAGENTA)
	_ui.draw_string(f, Vector2(r.size.x - INNEN - 300.0, 40.0), "PUNKTE %05d" % _punkte, HORIZONTAL_ALIGNMENT_RIGHT, 300, 22, NEON.GELB)
	match _phase:
		Phase.INTRO:
			_intro_zeichnen(f, r)
		Phase.SPIEL, Phase.RUNDE_ENDE:
			_spielfeld_zeichnen(f, r)
		Phase.ENDE:
			_ende_zeichnen(f, r)
	var hinweis := "PFEILE: WÄHLEN   E: AUFLEGEN   1-0: DIREKT   RÜCKSCHRITT: ZURÜCK   ESC: ABBRECHEN"
	if _phase != Phase.SPIEL:
		hinweis = "E: WEITER   ESC: SCHLIESSEN"
	_ui.draw_string(f, Vector2(INNEN, r.size.y - 18.0), hinweis, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(NEON.CYAN, 0.7))


func _intro_zeichnen(f: SystemFont, r: Rect2) -> void:
	_roboter_zeichnen(Vector2(190.0, 430.0))
	_ui.draw_string(f, Vector2(360.0, 170.0), "BEDIENROBOTER BU-R6R", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, NEON.CYAN)
	_ui.draw_multiline_string(f, Vector2(360.0, 220.0), ROBOTER_TEXT, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 360.0 - INNEN, 20, -1, Color(0.85, 0.95, 1.0))
	_ui.draw_multiline_string(f, Vector2(360.0, 360.0), "%d BESTELLUNGEN. TOP-BRÖTCHEN GIBT DEN BURGER AB. FALSCH GEBAUT KOSTET ZEIT." % RUNDEN, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 360.0 - INNEN, 18, -1, Color(NEON.GELB, 0.9))
	if int(_zeit * 2.0) % 2 == 0:
		_ui.draw_string(f, Vector2(360.0, 480.0), "[E] ANNEHMEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, NEON.MAGENTA)


func _ende_zeichnen(f: SystemFont, r: Rect2) -> void:
	_roboter_zeichnen(Vector2(190.0, 430.0))
	var kopf := "PERFEKT, KUNDE 4711 WEINT VOR GLÜCK." if _richtige == RUNDEN else "KUNDE 4711 HAT SCHON SCHLIMMERES GEGESSEN." if _richtige > 0 else "KUNDE 4711 BESTELLT JETZT BEIM GURKENMONSTER."
	_ui.draw_string(f, Vector2(360.0, 170.0), "SCHICHTENDE", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, NEON.CYAN)
	_ui.draw_multiline_string(f, Vector2(360.0, 220.0), kopf, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 360.0 - INNEN, 20, -1, Color(0.85, 0.95, 1.0))
	_ui.draw_string(f, Vector2(360.0, 320.0), "RICHTIGE BURGER: %d / %d" % [_richtige, RUNDEN], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, NEON.GELB)
	_ui.draw_string(f, Vector2(360.0, 356.0), "PUNKTE: %d" % _punkte, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, NEON.GELB)
	var lohn := "BELOHNUNG: %d MANA-KERNE" % _belohnung if _belohnung > 0 else "BELOHNUNG: KEINE (SCHON ABGEHOLT ODER NICHTS GEBAUT)"
	_ui.draw_string(f, Vector2(360.0, 410.0), lohn, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, NEON.MAGENTA)


func _spielfeld_zeichnen(f: SystemFont, r: Rect2) -> void:
	_ui.draw_string(f, Vector2(INNEN, 76.0), "RUNDE %d / %d" % [_runde + 1, RUNDEN], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, NEON.CYAN)
	# Zeitbalken
	var anteil := clampf(_rest / _zeit_gesamt, 0.0, 1.0)
	var balken := Rect2(150.0, 62.0, r.size.x - 150.0 - INNEN - 90.0, 14.0)
	_ui.draw_rect(balken, Color(NEON.CYAN, 0.12))
	var bf := NEON.CYAN if anteil > 0.5 else NEON.GELB if anteil > 0.25 else NEON.ROT
	_ui.draw_rect(Rect2(balken.position, Vector2(balken.size.x * anteil, balken.size.y)), bf)
	_ui.draw_string(f, Vector2(balken.end.x + 10.0, 76.0), "%04.1f S" % _rest, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, bf)
	# Vorlage links, Checkliste Mitte, eigener Burger rechts
	_ui.draw_string(f, Vector2(INNEN, 110.0), "VORLAGE", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, NEON.GELB)
	_burger_zeichnen(_auftrag, Vector2(INNEN + 110.0, 380.0))
	_checkliste_zeichnen(f, Vector2(300.0, 110.0))
	_ui.draw_string(f, Vector2(r.size.x - INNEN - 260.0, 110.0), "DEIN BURGER", HORIZONTAL_ALIGNMENT_RIGHT, 260, 16, NEON.GELB)
	_burger_zeichnen(_stapel, Vector2(r.size.x - INNEN - 130.0, 380.0))
	_regal_zeichnen(f, r)
	var text := _meldung
	var farbe := _meldung_farbe
	var alpha := clampf(_meldung_zeit, 0.0, 1.0)
	if _phase == Phase.RUNDE_ENDE:
		text = _runde_text + "   [E] WEITER"
		farbe = NEON.CYAN if _runde_ok else NEON.ROT
		alpha = 1.0
	if alpha > 0.0:
		_ui.draw_string(f, Vector2(INNEN, 98.0), text, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 2.0 * INNEN, 18, Color(farbe, alpha))


## Checkliste: Bestellung von unten nach oben, bereits richtig gelegte Schichten abgehakt.
func _checkliste_zeichnen(f: SystemFont, ursprung: Vector2) -> void:
	var richtig := 0
	for i in mini(_stapel.size(), _auftrag.size()):
		if _stapel[i] != _auftrag[i]:
			break
		richtig += 1
	var zeilen := _auftrag.size()
	var zeile_h := minf(24.0, 220.0 / maxf(zeilen, 1))
	for i in zeilen:
		var y := ursprung.y + 30.0 + i * zeile_h
		var z: Array = ZUTATEN[_auftrag[i]]
		var ok := i < richtig
		var naechste := i == richtig
		var farbe: Color = NEON.CYAN if ok else (NEON.GELB if naechste else Color(0.7, 0.8, 0.9, 0.6))
		_ui.draw_rect(Rect2(ursprung.x, y - 12.0, 12.0, 12.0), z[1])
		_ui.draw_string(f, Vector2(ursprung.x + 22.0, y), "%d. %s%s" % [i + 1, z[0], "  ✓" if ok else ""], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, farbe)
	if _stapel.size() > richtig:
		_ui.draw_string(f, Vector2(ursprung.x, ursprung.y + 40.0 + zeilen * zeile_h), "SCHICHT %d PASST NICHT" % (richtig + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, NEON.ROT)


func _regal_zeichnen(f: SystemFont, r: Rect2) -> void:
	var n := ZUTATEN.size()
	var breite := SPALTEN * KACHEL_B + (SPALTEN - 1) * KACHEL_ABSTAND
	var x0 := (r.size.x - breite) * 0.5
	var y0 := 424.0
	for i in n:
		var sp := i % SPALTEN
		var ze := floori(float(i) / SPALTEN)
		var rc := Rect2(x0 + sp * (KACHEL_B + KACHEL_ABSTAND), y0 + ze * (KACHEL_H * 0.5 + 8.0), KACHEL_B, KACHEL_H * 0.5)
		var an := i == _wahl and _phase == Phase.SPIEL
		_ui.draw_rect(rc, Color(NEON.MAGENTA, 0.18 if an else 0.05))
		if an:
			_ui.draw_rect(rc, NEON.GELB, false, 2.0)
		# Mini-Schicht links in der Kachel, Name rechts davon
		_schicht_zeichnen(i, Vector2(rc.position.x + 24.0, rc.position.y + rc.size.y * 0.5 + 4.0), 36.0)
		_ui.draw_string(f, Vector2(rc.position.x + 48.0, rc.position.y + 20.0), String(ZUTATEN[i][0]).replace("BRÖTCHEN ", "BRÖT. "), HORIZONTAL_ALIGNMENT_LEFT, int(rc.size.x - 50.0), 11, NEON.GELB if an else NEON.CYAN)
		_ui.draw_string(f, Vector2(rc.position.x + 48.0, rc.position.y + 40.0), "[%d]" % ((i + 1) % 10), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(NEON.CYAN, 0.6))


## Zeichnet einen ganzen Stapel von unten nach oben auf einem Teller, `basis` = Mitte der Telleroberkante.
func _burger_zeichnen(stapel: Array[int], basis: Vector2) -> void:
	_ui.draw_colored_polygon(_oval(basis + Vector2(0, 8.0), BURGER_BREITE * 0.62, 10.0), Color(0.75, 0.8, 0.9))
	_ui.draw_colored_polygon(_oval(basis + Vector2(0, 4.0), BURGER_BREITE * 0.55, 7.0), Color(0.95, 0.97, 1.0))
	var y := basis.y
	var skala := minf(SCHICHT_SKALA, 190.0 / maxf(_stapel_hoehe(stapel), 1.0))
	for id in stapel:
		var h := _schicht_zeichnen(id, Vector2(basis.x, y), BURGER_BREITE, skala)
		y -= h


func _stapel_hoehe(stapel: Array[int]) -> float:
	var h := 0.0
	for id in stapel:
		h += float(ZUTATEN[id][2])
	return h


## Zeichnet eine Schicht, Unterkante bei `pos.y`, mittig auf `pos.x`. Liefert die Hoehe in Pixeln (mit Skala).
func _schicht_zeichnen(id: int, pos: Vector2, breite: float, skala := 1.0) -> float:
	var z: Array = ZUTATEN[id]
	var farbe: Color = z[1]
	var h: float = z[2] * skala
	var b := breite
	var x0 := pos.x - b * 0.5
	var y0 := pos.y - h
	match id:
		BROETCHEN_U:
			_ui.draw_colored_polygon(_abgerundet(Rect2(x0 + 4.0, y0, b - 8.0, h), h * 0.45), farbe)
		BROETCHEN_O:
			_ui.draw_colored_polygon(_kuppel(Vector2(pos.x, pos.y), b * 0.5, h), farbe)
			for k in 5:
				var sx := pos.x + (k - 2) * b * 0.15
				_ui.draw_circle(Vector2(sx, pos.y - h * (0.55 + 0.12 * ((k + 1) % 2))), maxf(b * 0.012, 1.5), Color(1.0, 0.95, 0.75))
		ERSTE_FUELLUNG:  # Patty
			_ui.draw_colored_polygon(_abgerundet(Rect2(x0 + 2.0, y0, b - 4.0, h), h * 0.4), farbe)
			_ui.draw_line(Vector2(x0 + b * 0.12, y0 + h * 0.3), Vector2(x0 + b * 0.88, y0 + h * 0.3), farbe.lightened(0.25), maxf(h * 0.08, 1.0))
		3:  # Kaese
			_ui.draw_rect(Rect2(x0 - 3.0, y0, b + 6.0, h * 0.6), farbe)
			_ui.draw_colored_polygon(PackedVector2Array([Vector2(x0 + b * 0.15, y0 + h * 0.6), Vector2(x0 + b * 0.45, y0 + h * 0.6), Vector2(x0 + b * 0.3, y0 + h)]), farbe)
		4:  # Salat (Wellen)
			_ui.draw_colored_polygon(_wellig(Rect2(x0 - 6.0, y0, b + 12.0, h), h * 0.35, 9), farbe)
		5:  # Tomate
			_ui.draw_rect(Rect2(x0 + 2.0, y0, b - 4.0, h), farbe)
			for k in 4:
				_ui.draw_circle(Vector2(x0 + b * (0.2 + 0.2 * k), y0 + h * 0.5), maxf(h * 0.12, 1.0), farbe.lightened(0.45))
		6:  # Gurke
			_ui.draw_rect(Rect2(x0 + 6.0, y0, b - 12.0, h), farbe)
			_ui.draw_rect(Rect2(x0 + 6.0, y0 + h * 0.35, b - 12.0, maxf(h * 0.3, 1.0)), farbe.lightened(0.35))
		7:  # Zwiebel
			_ui.draw_rect(Rect2(x0 + 10.0, y0, b - 20.0, h), farbe)
			for k in 3:
				_ui.draw_line(Vector2(x0 + 10.0, y0 + h * (0.25 + 0.25 * k)), Vector2(x0 + b - 10.0, y0 + h * (0.25 + 0.25 * k)), farbe.darkened(0.3), 1.0)
		8:  # Bacon (Wellen)
			_ui.draw_colored_polygon(_wellig(Rect2(x0, y0, b, h), h * 0.3, 6), farbe)
			_ui.draw_line(Vector2(x0 + 4.0, y0 + h * 0.5), Vector2(x0 + b - 4.0, y0 + h * 0.5), Color(1.0, 0.8, 0.75, 0.6), maxf(h * 0.12, 1.0))
		9:  # Sosse (mit Tropfen)
			_ui.draw_rect(Rect2(x0 + 4.0, y0, b - 8.0, h * 0.6), farbe)
			for k in 3:
				_ui.draw_rect(Rect2(x0 + b * (0.2 + 0.3 * k), y0 + h * 0.6, maxf(b * 0.04, 2.0), h * 0.4), farbe)
	return h


func _oval(mitte: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in 24:
		var w := TAU * i / 24.0
		p.append(mitte + Vector2(cos(w) * rx, sin(w) * ry))
	return p


func _kuppel(unten_mitte: Vector2, rx: float, h: float) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in 17:
		var w := PI * i / 16.0
		p.append(unten_mitte + Vector2(cos(w) * rx, -sin(w) * h))
	return p


func _abgerundet(rc: Rect2, rad: float) -> PackedVector2Array:
	var p := PackedVector2Array()
	var e := rc.end
	var ecken := [
		[Vector2(e.x - rad, rc.position.y + rad), -PI * 0.5],
		[Vector2(e.x - rad, e.y - rad), 0.0],
		[Vector2(rc.position.x + rad, e.y - rad), PI * 0.5],
		[Vector2(rc.position.x + rad, rc.position.y + rad), PI],
	]
	for c in ecken:
		for i in 6:
			var w: float = c[1] + (PI * 0.5) * i / 5.0
			p.append((c[0] as Vector2) + Vector2(cos(w), sin(w)) * rad)
	return p


func _wellig(rc: Rect2, amp: float, wellen: int) -> PackedVector2Array:
	var p := PackedVector2Array()
	var n := wellen * 4
	for i in n + 1:
		var t := float(i) / n
		p.append(Vector2(rc.position.x + rc.size.x * t, rc.position.y + amp + sin(t * TAU * wellen * 0.5) * amp))
	p.append(Vector2(rc.end.x, rc.end.y))
	p.append(Vector2(rc.position.x, rc.end.y))
	return p


## Kleiner weisser Roboter im Stil des Kassierers in burger.gd (Zeichnung, `fuss` = Mitte der Standflaeche).
func _roboter_zeichnen(fuss: Vector2) -> void:
	var weiss := Color(0.92, 0.95, 1.0)
	var wackeln := sin(_zeit * 2.0) * 3.0
	_ui.draw_rect(Rect2(fuss.x - 50.0, fuss.y - 150.0 + wackeln, 100.0, 130.0), weiss)
	_ui.draw_rect(Rect2(fuss.x - 30.0, fuss.y - 120.0 + wackeln, 60.0, 45.0), Color(0.2, 0.4, 1.0))
	_ui.draw_circle(Vector2(fuss.x, fuss.y - 190.0 + wackeln), 52.0, weiss)
	_ui.draw_rect(Rect2(fuss.x - 38.0, fuss.y - 205.0 + wackeln, 76.0, 28.0), Color(0.12, 0.12, 0.2))
	var blinzeln := int(_zeit * 1.3) % 5 == 0
	for sx in [-17.0, 17.0]:
		_ui.draw_rect(Rect2(fuss.x + sx - 6.0, fuss.y - 196.0 + wackeln, 12.0, 4.0 if blinzeln else 10.0), NEON.CYAN)
	_ui.draw_rect(Rect2(fuss.x - 2.0, fuss.y - 252.0 + wackeln, 4.0, 20.0), Color(0.55, 0.58, 0.68))
	_ui.draw_circle(Vector2(fuss.x, fuss.y - 258.0 + wackeln), 7.0, NEON.ROT)
