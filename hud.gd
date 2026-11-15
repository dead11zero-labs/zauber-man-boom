extends CanvasLayer
## Cyberpunk-HUD: Kristallzaehler mit Neon-Rahmen, abgeschraegten Ecken und Segmentbalken.
## Kampf (Meilenstein 4): roter Bildrand bei Treffer, Meldungen oben Mitte (Kurzschluss, Checkpoint).

const CYAN := Color(0.1, 0.95, 1.0)
const MAGENTA := Color(1.0, 0.15, 0.8)
const GELB := Color(1.0, 0.85, 0.2)
const PANEL := Color(0.02, 0.04, 0.08, 0.72)

var anzahl := 0
var gesamt := 0
var _puls := 0.0
var _zeit := 0.0
var _glitch := 0.0
var _font: SystemFont
var panel: Control
var panel2: Control
var bezirk := ""
var _bezirk_alpha := 0.0
var _ladung := 0.0
var panel3: Control  # Ladebalken des Ladeschusses (unten Mitte)

const LADE_BREITE := 320.0
const LADE_HOEHE := 18.0
const LADE_SEGMENTE := 16
const LADE_ABSTAND_UNTEN := 90.0
const ROT := Color(1.0, 0.15, 0.25)
const TREFFER_ABBAU := 2.2
const MELDUNG_DAUER := 2.5
const MELDUNG_OBEN := 190.0
const MELDUNG_GROESSE := 22
const RAND_BREITE := 70.0
const MELDUNG_RAND := 34.0

var _treffer := 0.0
var _meldung := ""
var _meldung_farbe := CYAN
var _meldung_zeit := 0.0
var _herzen_alt := GameState.herzen
var panel4: Control  # Kampf-Overlay (Treffer-Rand, Meldungen)
## Zielanzeige (Meilenstein 5): aktives Quest-Ziel unter dem Mana-Kerne-Panel
var panel5: Control
const ZIEL_OBEN := 214.0
const ZIEL_BREITE := 300.0
const ZIEL_HOEHE := 62.0
const ZIEL_TEXT_GROESSE := 14
const ZIEL_BLINK := 1.4
var _ziel_blink := 0.0
const JOURNAL_SKRIPT := preload("res://ui/journal.gd")


func _ready() -> void:
	layer = 10
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Share Tech Mono", "DejaVu Sans Mono", "Liberation Mono", "monospace"])
	_font.font_weight = 700
	# Leichtes analoges Filmkorn ueber dem ganzen Bild
	var korn := ColorRect.new()
	korn.set_anchors_preset(Control.PRESET_FULL_RECT)
	korn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var km := ShaderMaterial.new()
	km.shader = load("res://filmkorn.gdshader")
	korn.material = km
	add_child(korn)
	panel = Control.new()
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(24, 24)
	panel.size = Vector2(300, 142)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.draw.connect(_zeichnen)
	add_child(panel)
	# Status-Panel rechts oben: Herzen, Grimoire-Seiten, Bezirks-Abschluss
	panel2 = Control.new()
	panel2.anchor_left = 1.0
	panel2.anchor_right = 1.0
	panel2.offset_left = -314.0
	panel2.offset_right = -24.0
	panel2.offset_top = 24.0
	panel2.offset_bottom = 164.0
	panel2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel2.draw.connect(_zeichnen_status)
	add_child(panel2)
	panel3 = Control.new()
	panel3.anchor_left = 0.5
	panel3.anchor_right = 0.5
	panel3.anchor_top = 1.0
	panel3.anchor_bottom = 1.0
	panel3.offset_left = -LADE_BREITE * 0.5
	panel3.offset_right = LADE_BREITE * 0.5
	panel3.offset_top = -LADE_ABSTAND_UNTEN
	panel3.offset_bottom = -LADE_ABSTAND_UNTEN + LADE_HOEHE
	panel3.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel3.draw.connect(_zeichnen_ladung)
	add_child(panel3)
	panel4 = Control.new()
	panel4.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel4.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel4.draw.connect(_zeichnen_kampf)
	add_child(panel4)
	EventBus.herzen_geaendert.connect(_herzen_neu)
	EventBus.spieler_gestorben.connect(func() -> void: meldung("!! KURZSCHLUSS // NEUSTART AM CHECKPOINT", ROT))
	EventBus.checkpoint_erreicht.connect(func(_i: String) -> void: meldung("CHECKPOINT // GESPEICHERT", CYAN))
	panel5 = Control.new()
	panel5.position = Vector2(24, ZIEL_OBEN)
	panel5.size = Vector2(ZIEL_BREITE, ZIEL_HOEHE)
	panel5.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel5.draw.connect(_zeichnen_ziel)
	add_child(panel5)
	EventBus.quest_geaendert.connect(_quest_neu)
	EventBus.quest_abgeschlossen.connect(func(_i: String) -> void: meldung("ZIEL ERLEDIGT", GELB))
	var journal := Control.new()
	journal.set_script(JOURNAL_SKRIPT)
	add_child(journal)
	var karte := Control.new()
	karte.set_script(preload("res://minimap.gd"))
	add_child(karte)
	EventBus.bezirk_gewechselt.connect(_bezirk_neu)
	_bezirk_neu(GameState.aktueller_bezirk, GameState.bezirk_name(GameState.aktueller_bezirk))
	var sp := get_parent()
	if sp.has_signal("ladung_geaendert"):
		sp.ladung_geaendert.connect(func(a: float) -> void: _ladung = a)
	if sp.has_signal("kristalle_geaendert"):
		sp.kristalle_geaendert.connect(_aktualisieren)
		_aktualisieren(sp.kristalle, sp.kristalle_gesamt)


func _quest_neu(id: String) -> void:
	_ziel_blink = ZIEL_BLINK
	if id != "":
		meldung("NEUES ZIEL // " + QuestManager.ziel_text().to_upper(), MAGENTA)


func _zeichnen_ziel() -> void:
	var text := QuestManager.ziel_text()
	if text == "":
		return
	var r := Rect2(Vector2.ZERO, panel5.size)
	var poly := _abgeschraegt(r, 12.0)
	panel5.draw_colored_polygon(poly, PANEL)
	var rahmen := poly.duplicate()
	rahmen.append(poly[0])
	var farbe := GELB.lerp(Color.WHITE, clampf(_ziel_blink / ZIEL_BLINK, 0.0, 1.0) * absf(sin(_zeit * 10.0)))
	panel5.draw_polyline(rahmen, Color(farbe, 0.25), 5.0)
	panel5.draw_polyline(rahmen, farbe, 2.0)
	panel5.draw_string(_font, Vector2(18, 22), "// ZIEL  [J] JOURNAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(GELB, 0.8))
	panel5.draw_multiline_string(_font, Vector2(18, 44), text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, ZIEL_BREITE - 30.0, ZIEL_TEXT_GROESSE, 2, CYAN)


func _herzen_neu(h: int) -> void:
	if h < _herzen_alt:
		_treffer = 1.0
	_herzen_alt = h


## Kurze Meldung oben in der Mitte
func meldung(text: String, farbe: Color) -> void:
	_meldung = text
	_meldung_farbe = farbe
	_meldung_zeit = MELDUNG_DAUER


func _zeichnen_kampf() -> void:
	var gr := panel4.size
	if _treffer > 0.0:
		var c := Color(ROT, 0.45 * _treffer)
		var leer := Color(ROT, 0.0)
		# Verlauf vom Rand nach innen (vier Streifen)
		panel4.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(gr.x, 0), Vector2(gr.x, RAND_BREITE), Vector2(0, RAND_BREITE)]), PackedColorArray([c, c, leer, leer]))
		panel4.draw_polygon(PackedVector2Array([Vector2(0, gr.y - RAND_BREITE), Vector2(gr.x, gr.y - RAND_BREITE), gr, Vector2(0, gr.y)]), PackedColorArray([leer, leer, c, c]))
		panel4.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(RAND_BREITE, 0), Vector2(RAND_BREITE, gr.y), Vector2(0, gr.y)]), PackedColorArray([c, leer, leer, c]))
		panel4.draw_polygon(PackedVector2Array([Vector2(gr.x - RAND_BREITE, 0), Vector2(gr.x, 0), gr, Vector2(gr.x - RAND_BREITE, gr.y)]), PackedColorArray([leer, c, c, leer]))
	if _meldung_zeit > 0.0:
		var a := clampf(_meldung_zeit, 0.0, 1.0)
		var breite := _font.get_string_size(_meldung, HORIZONTAL_ALIGNMENT_LEFT, -1, MELDUNG_GROESSE).x
		var p := Vector2((gr.x - breite) * 0.5, MELDUNG_OBEN)
		var kasten := Rect2(p + Vector2(-MELDUNG_RAND, -30), Vector2(breite + MELDUNG_RAND * 2.0, 44))
		panel4.draw_rect(kasten, Color(PANEL, PANEL.a * a))
		panel4.draw_rect(kasten, Color(_meldung_farbe, 0.9 * a), false, 2.0)
		panel4.draw_string(_font, p, _meldung, HORIZONTAL_ALIGNMENT_LEFT, -1, MELDUNG_GROESSE, Color(_meldung_farbe, a))


func _bezirk_neu(nr: int, name: String) -> void:
	bezirk = "BEZIRK %d // %s" % [nr, name.to_upper()] if nr >= 1 and nr <= 5 else name.to_upper()
	_bezirk_alpha = 1.0


func _aktualisieren(neu: int, total: int) -> void:
	if neu > anzahl:
		_puls = 1.0
		_glitch = 0.25
	anzahl = neu
	gesamt = total


func _process(delta: float) -> void:
	_zeit += delta
	_puls = maxf(_puls - delta * 2.5, 0.0)
	_glitch = maxf(_glitch - delta, 0.0)
	_treffer = maxf(_treffer - delta * TREFFER_ABBAU, 0.0)
	_meldung_zeit = maxf(_meldung_zeit - delta, 0.0)
	_ziel_blink = maxf(_ziel_blink - delta, 0.0)
	panel5.queue_redraw()
	panel4.queue_redraw()
	panel.queue_redraw()
	panel2.queue_redraw()
	panel3.queue_redraw()


func _zeichnen_ladung() -> void:
	if _ladung <= 0.0:
		return
	var voll := _ladung >= 1.0
	var farbe := MAGENTA if voll and fmod(_zeit * 8.0, 1.0) < 0.5 else CYAN
	var breite := (LADE_BREITE - 4.0 * (LADE_SEGMENTE - 1)) / LADE_SEGMENTE
	panel3.draw_rect(Rect2(Vector2.ZERO, panel3.size), PANEL)
	for i in LADE_SEGMENTE:
		if float(i + 1) / LADE_SEGMENTE <= _ladung + 0.001:
			panel3.draw_rect(Rect2(i * (breite + 4.0), 2.0, breite, LADE_HOEHE - 4.0), farbe)


func _abgeschraegt(r: Rect2, c: float) -> PackedVector2Array:
	var p := r.position
	var e := r.end
	return PackedVector2Array([
		Vector2(p.x + c, p.y), Vector2(e.x, p.y), Vector2(e.x, e.y - c),
		Vector2(e.x - c, e.y), Vector2(p.x, e.y), Vector2(p.x, p.y + c)])


func _zeichnen() -> void:
	var r := Rect2(Vector2.ZERO, panel.size)
	var poly := _abgeschraegt(r, 16.0)
	panel.draw_colored_polygon(poly, PANEL)
	# Scanlines
	var y := 2.0 + fmod(_zeit * 18.0, 4.0)
	while y < r.size.y:
		panel.draw_line(Vector2(2, y), Vector2(r.size.x - 2, y), Color(0.1, 0.9, 1.0, 0.04), 1.0)
		y += 4.0
	# Rahmen mit Glow
	var rahmen := poly.duplicate()
	rahmen.append(poly[0])
	var farbe := CYAN.lerp(Color.WHITE, _puls * 0.7)
	panel.draw_polyline(rahmen, Color(farbe, 0.25), 6.0)
	panel.draw_polyline(rahmen, farbe, 2.0)
	# Magenta-Akzentecke
	panel.draw_polyline(PackedVector2Array([Vector2(r.size.x - 70, 0), Vector2(r.size.x, 0), Vector2(r.size.x, r.size.y - 16)]), MAGENTA, 3.0)
	panel.draw_rect(Rect2(10, 10, 6, 6), MAGENTA)
	# Titel
	var versatz := Vector2(randf_range(-3, 3), 0) if _glitch > 0.0 else Vector2.ZERO
	if _glitch > 0.0:
		panel.draw_string(_font, Vector2(28, 30) + versatz + Vector2(2, 0), "// MANA-KERNE", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(MAGENTA, 0.8))
	panel.draw_string(_font, Vector2(28, 30) + versatz, "// MANA-KERNE", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, CYAN)
	panel.draw_string(_font, Vector2(r.size.x - 100, 30), "SYS.ONLINE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(GELB, 0.5 + 0.5 * sin(_zeit * 4.0)))
	# Zaehler
	var gross := 46 + int(_puls * 8.0)
	var zahl := "%03d" % anzahl
	panel.draw_string(_font, Vector2(26, 80), zahl, HORIZONTAL_ALIGNMENT_LEFT, -1, gross, Color(GELB.lerp(Color.WHITE, _puls), 1.0))
	panel.draw_string(_font, Vector2(150, 80), "/ %03d" % gesamt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(CYAN, 0.7))
	# Schleim-Warnung
	var sp := get_parent()
	if sp.get("_klebt") != null and sp._klebt > 0.0:
		var wf := Color(0.4, 1.0, 0.15)
		panel.draw_rect(Rect2(0, r.size.y + 8, 190, 26), Color(0.02, 0.08, 0.02, 0.75))
		panel.draw_rect(Rect2(0, r.size.y + 8, 190, 26), Color(wf, 0.9), false, 2.0)
		panel.draw_string(_font, Vector2(10, r.size.y + 27), "!! SCHLEIM // LANGSAM", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, wf)
	# Bezirksname
	panel.draw_string(_font, Vector2(28, 132), bezirk, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(MAGENTA.lerp(Color.WHITE, _puls * 0.0), 0.75 + 0.25 * sin(_zeit * 3.0)))
	# Segmentbalken
	var segmente := 20
	var gefuellt := 0 if gesamt == 0 else int(round(float(anzahl) / float(gesamt) * segmente))
	for i in segmente:
		var sr := Rect2(28 + i * 12.5, 96, 9, 10)
		if i < gefuellt:
			panel.draw_rect(sr, MAGENTA.lerp(CYAN, float(i) / segmente))
		else:
			panel.draw_rect(sr, Color(CYAN, 0.12))


func _herz(mitte: Vector2, g: float, farbe: Color) -> void:
	panel2.draw_circle(mitte + Vector2(-g * 0.5, 0), g * 0.55, farbe)
	panel2.draw_circle(mitte + Vector2(g * 0.5, 0), g * 0.55, farbe)
	panel2.draw_colored_polygon(PackedVector2Array([
		mitte + Vector2(-g * 1.03, g * 0.2), mitte + Vector2(g * 1.03, g * 0.2), mitte + Vector2(0, g * 1.25)]), farbe)


func _zeichnen_status() -> void:
	var r := Rect2(Vector2.ZERO, panel2.size)
	var poly := _abgeschraegt(r, 16.0)
	panel2.draw_colored_polygon(poly, PANEL)
	var rahmen := poly.duplicate()
	rahmen.append(poly[0])
	panel2.draw_polyline(rahmen, Color(MAGENTA, 0.25), 6.0)
	panel2.draw_polyline(rahmen, MAGENTA, 2.0)
	panel2.draw_string(_font, Vector2(26, 30), "// STATUS", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, MAGENTA)
	# Herzen
	for i in GameState.MAX_HERZEN:
		var voll := i < GameState.herzen
		_herz(Vector2(40 + i * 40, 56), 9.0, Color(1.0, 0.2, 0.35) if voll else Color(1, 1, 1, 0.12))
	# Grimoire-Seiten
	panel2.draw_string(_font, Vector2(26, 98), "SEITEN %d/%d" % [GameState.seiten.size(), GameState.SEITEN_GESAMT], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, GELB)
	for i in GameState.SEITEN_GESAMT:
		var sr := Rect2(150 + i * 17, 86, 13, 14)
		if GameState.hat_seite(i + 1):
			panel2.draw_rect(sr, GELB)
		else:
			panel2.draw_rect(sr, Color(GELB, 0.15))
	# Bezirks-Abschluss
	var a := GameState.abschluss(GameState.aktueller_bezirk)
	var txt := "ABSCHLUSS  --" if a < 0.0 else "ABSCHLUSS  %d%%" % roundi(a * 100.0)
	panel2.draw_string(_font, Vector2(26, 126), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, CYAN)
	panel2.draw_rect(Rect2(170, 114, 100, 10), Color(CYAN, 0.15))
	if a > 0.0:
		panel2.draw_rect(Rect2(170, 114, 100.0 * a, 10), CYAN)
