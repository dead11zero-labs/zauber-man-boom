extends Node3D
## Drohnen-Lieferdienst (Minispiel auf dem Dach des Neon-Markts, gestartet an der geparkten Lieferdrohne,
## siehe neonmarkt.gd). Man fliegt eine Lieferdrohne durch die echte Stadt: Ware zum Ziel bringen, zurueck zum
## Lieferdeck, neue Ware holen, naechstes Ziel. Der Akku laeuft ab; jede Lieferung laedt AKKU_PRO_LIEFERUNG nach.
## Ziel: so viele Lieferungen wie moeglich. Ab ZIEL_LIEFERUNGEN gibt es einmalig Mana-Kerne (Flag FLAG_GESCHAFFT).
## Steuerung: vor/zurueck (W/S, Stick), drehen (A/D, Maus, Stick), steigen (Sprung oder Zauber), sinken (Dash),
## Abbruch: Esc (Tastatur) oder Journal-Taste (Pad Start). Sperrt die Spieler-Eingabe (EventBus, Grund "drohne").
## Exportiert: start_pos (Weltposition der Drohne), deck_pos (Mitte des Abholpunkts), ziele (Namen -> x/z).
## Signal: beendet(lieferungen: int, punkte: int) beim Schliessen. Entfernt sich selbst.

signal beendet(lieferungen: int, punkte: int)

const DM := preload("res://levels/drohnen_modell.gd")
const NEON := preload("res://ui/neon.gd")
const SPERRE_GRUND := "drohne"
const FLAG_GESCHAFFT := "drohnen_lieferung_geschafft"

@export var start_pos := Vector3.ZERO
@export var deck_pos := Vector3.ZERO
## Lieferziele: Name -> Position (x, z) in Weltkoordinaten. Die Hoehe kommt per Strahl von oben.
@export var ziele := {
	"SY-CI BURGERS": Vector2(92, 72),
	"STADTVERWALTUNG": Vector2(42, 0),
	"BÜCHEREI": Vector2(-33, -40),
	"STADTKLINIK": Vector2(62, -56),
	"MUSEUM": Vector2(-38, -182),
	"BREZEL-STAND": Vector2(-255, 30),
	"POPCORN-LABOR": Vector2(255, 40),
}

const TEMPO := 22.0                 ## m/s vorwaerts
const TEMPO_RUECK := 10.0
const STEIG_TEMPO := 9.0
const DREH_TEMPO := 2.2             ## rad/s mit Tasten/Stick
const MAUS_DREH := 0.004            ## rad pro Pixel
const BESCHLEUNIGUNG := 3.0         ## Anteil pro Sekunde, mit dem die Geschwindigkeit nachzieht
const MAX_HOEHE := 85.0
const NEIGUNG := 0.25               ## rad Kippen bei voller Fahrt
const KOERPER_RADIUS := 0.9
const AKKU_START := 120.0
const AKKU_PRO_LIEFERUNG := 15.0
const ZIEL_RADIUS := 4.5            ## waagerecht
const ZIEL_HOEHE := 7.0             ## so hoch ueber dem Ziel darf die Drohne noch abgeben
const DECK_RADIUS := 3.0
const DECK_HOEHE := 3.5
const PUNKTE_LIEFERUNG := 100
const PUNKTE_ZEIT_MAX := 60         ## Bonus: so viele Punkte minus vergangene Sekunden seit der Abholung (min. 0)
const ZIEL_LIEFERUNGEN := 5
const KERNE_BELOHNUNG := 5
const ZIEL_MAX_HOEHE := 70.0        ## hoeher liegende Ziele werden ausgelassen
const INTRO_DAUER := 3.5
const MELDUNG_DAUER := 2.0
const KAMERA_ABSTAND := 8.0
const KAMERA_HOEHE := 3.2
const KAMERA_NACHZIEHEN := 6.0
const STRAHL_HOEHE := 80.0
const STRAHL_RADIUS := 2.2
const STRAHL_ALPHA := 0.22
const STRAHL_AUSBLENDEN := Vector2(6.0, 40.0)   ## waagerechter Abstand: ab hier unsichtbar, ab hier voll sichtbar
const PAKET_FALLZEIT := 0.6
const EBENE := 26

enum Phase { INTRO, FLUG, ENDE }

static var bestwert := 0            ## Bestwert dieser Sitzung (Lieferungen)

var _phase := Phase.INTRO
var _drohne: CharacterBody3D
var _modell: Node3D
var _kamera: Camera3D
var _alte_kamera: Camera3D
var _gier := 0.0
var _akku := AKKU_START
var _beladen := true
var _lieferungen := 0
var _punkte := 0
var _seit_abholung := 0.0
var _ziel_name := ""
var _ziel_pos := Vector3.ZERO
var _letztes_ziel := ""
var _marker: Node3D
var _marker_mat: StandardMaterial3D
var _zeit := 0.0
var _meldung := ""
var _meldung_zeit := 0.0
var _meldung_farbe := NEON.CYAN
var _maus_dreh := 0.0
var _belohnung := 0
var _ui: Control


func _ready() -> void:
	add_to_group("drohnen_lieferung")
	add_to_group("shop_offen")   # haelt das Journal zu (ui/journal.gd), die Journal-Taste bricht hier ab
	EventBus.eingabe_gesperrt.emit(SPERRE_GRUND, true)
	_alte_kamera = get_viewport().get_camera_3d()
	_drohne_bauen()
	_marker_bauen()
	_naechstes_ziel()
	var d := _ziel_pos - start_pos
	_gier = atan2(d.x, d.z)
	_drohne.rotation.y = _gier
	_kamera = Camera3D.new()
	_kamera.fov = 75.0
	_kamera.far = 1500.0
	add_child(_kamera)
	_kamera.global_position = _kamera_soll()
	_kamera.look_at(_drohne.global_position)
	_kamera.make_current()
	_hud_bauen()


func _drohne_bauen() -> void:
	_drohne = CharacterBody3D.new()
	_drohne.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = KOERPER_RADIUS
	cs.shape = sh
	_drohne.add_child(cs)
	add_child(_drohne)
	_drohne.global_position = start_pos
	_modell = DM.bauen(DM.Stufe.FERTIG, true)
	_drohne.add_child(_modell)
	var licht := OmniLight3D.new()
	licht.light_color = Color(0.4, 0.9, 1.0)
	licht.light_energy = 1.0
	licht.omni_range = 6.0
	licht.position = Vector3(0, -0.8, 0)
	_drohne.add_child(licht)
	# Spieler nicht anstossen (er steht auf dem Dach neben dem Startpunkt)
	var sp := get_tree().get_first_node_in_group("spieler") as CollisionObject3D
	if sp != null:
		_drohne.add_collision_exception_with(sp)


func _marker_bauen() -> void:
	_marker = Node3D.new()
	add_child(_marker)
	_marker_mat = StandardMaterial3D.new()
	_marker_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_marker_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_marker_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_marker_mat.albedo_color = Color(NEON.GELB, STRAHL_ALPHA)
	var strahl := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = STRAHL_RADIUS * 0.6
	cm.bottom_radius = STRAHL_RADIUS
	cm.height = STRAHL_HOEHE
	cm.cap_top = false
	cm.cap_bottom = false
	strahl.mesh = cm
	strahl.position.y = STRAHL_HOEHE * 0.5
	strahl.material_override = _marker_mat
	strahl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marker.add_child(strahl)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = ZIEL_RADIUS - 0.4
	tm.outer_radius = ZIEL_RADIUS
	ring.mesh = tm
	ring.position.y = 0.3
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = Color.WHITE
	ring.material_override = ring_mat
	ring.set_meta("ring", true)
	_marker.add_child(ring)


# ---------------------------------------------------------------- Ablauf

func _naechstes_ziel() -> void:
	if not _beladen:
		_ziel_name = "LIEFERDECK NEON-MARKT"
		_ziel_pos = deck_pos
		_marker_faerben(NEON.CYAN)
		return
	var raum := get_world_3d().direct_space_state
	var namen: Array = ziele.keys()
	namen.shuffle()
	for n: String in namen:
		if n == _letztes_ziel:
			continue
		var xz: Vector2 = ziele[n]
		var q := PhysicsRayQueryParameters3D.create(Vector3(xz.x, ZIEL_MAX_HOEHE + 40.0, xz.y), Vector3(xz.x, -5.0, xz.y))
		q.exclude = [_drohne.get_rid()]
		var r := raum.intersect_ray(q)
		var y: float = r.get("position", Vector3.ZERO).y
		if y > ZIEL_MAX_HOEHE:
			continue
		_ziel_name = n
		_ziel_pos = Vector3(xz.x, y, xz.y)
		_letztes_ziel = n
		break
	_marker_faerben(NEON.GELB)


func _marker_faerben(c: Color) -> void:
	_marker.global_position = _ziel_pos
	_marker_mat.albedo_color = Color(c, STRAHL_ALPHA)
	for k in _marker.get_children():
		if k.has_meta("ring"):
			((k as MeshInstance3D).material_override as StandardMaterial3D).albedo_color = c


func _melden(t: String, c: Color) -> void:
	_meldung = t
	_meldung_farbe = c
	_meldung_zeit = MELDUNG_DAUER


func _physics_process(delta: float) -> void:
	_zeit += delta
	_meldung_zeit = maxf(0.0, _meldung_zeit - delta)
	DM.rotoren_drehen(_modell, delta, 1.0 if _phase != Phase.ENDE else 0.2)
	match _phase:
		Phase.INTRO:
			_schweben(delta)
			if _zeit >= INTRO_DAUER:
				_phase = Phase.FLUG
		Phase.FLUG:
			_fliegen(delta)
			_akku -= delta
			_seit_abholung += delta
			_ziel_pruefen()
			if _akku <= 0.0:
				_akku = 0.0
				_beenden("AKKU LEER. DIE DROHNE SEGELT NACH HAUSE.")
		Phase.ENDE:
			_schweben(delta)
	_kamera_folgen(delta)
	if _marker != null:
		_marker.rotation.y += delta * 0.8
		# Strahl in der Naehe ausblenden, sonst faerbt er das ganze Bild
		var p := _drohne.global_position
		var waag := Vector2(p.x - _ziel_pos.x, p.z - _ziel_pos.z).length()
		_marker_mat.albedo_color.a = STRAHL_ALPHA * clampf(inverse_lerp(STRAHL_AUSBLENDEN.x, STRAHL_AUSBLENDEN.y, waag), 0.0, 1.0)
	if _ui != null:
		_ui.queue_redraw()


func _schweben(delta: float) -> void:
	_drohne.velocity = _drohne.velocity.lerp(Vector3.ZERO, minf(1.0, BESCHLEUNIGUNG * delta))
	_drohne.move_and_slide()
	_modell.position.y = sin(_zeit * 2.0) * 0.1


func _fliegen(delta: float) -> void:
	var b := Eingabe.bewegung()
	var blick := Eingabe.blick()
	_gier -= (b.x + blick.x) * DREH_TEMPO * delta + _maus_dreh
	_maus_dreh = 0.0
	var vor := Vector3(sin(_gier), 0.0, cos(_gier))
	var hoch := 0.0
	if Input.is_action_pressed("springen") or Input.is_action_pressed("zaubern"):
		hoch += 1.0
	if Input.is_action_pressed("dash"):
		hoch -= 1.0
	var tempo := TEMPO if b.y >= 0.0 else TEMPO_RUECK
	var soll := vor * b.y * tempo + Vector3.UP * hoch * STEIG_TEMPO
	_drohne.velocity = _drohne.velocity.lerp(soll, minf(1.0, BESCHLEUNIGUNG * delta))
	_drohne.move_and_slide()
	if _drohne.global_position.y > MAX_HOEHE:
		_drohne.global_position.y = MAX_HOEHE
		_drohne.velocity.y = minf(_drohne.velocity.y, 0.0)
	# Modell: in Flugrichtung drehen, bei Fahrt nach vorn kippen
	_drohne.rotation.y = _gier
	var anteil := clampf(_drohne.velocity.dot(vor) / TEMPO, -1.0, 1.0)
	_modell.rotation.x = lerpf(_modell.rotation.x, anteil * NEIGUNG, minf(1.0, 5.0 * delta))
	_modell.rotation.z = lerpf(_modell.rotation.z, b.x * NEIGUNG * 0.6, minf(1.0, 5.0 * delta))


func _ziel_pruefen() -> void:
	var p := _drohne.global_position
	var waag := Vector2(p.x - _ziel_pos.x, p.z - _ziel_pos.z).length()
	var hoehe := p.y - _ziel_pos.y
	if _beladen:
		if waag < ZIEL_RADIUS and hoehe < ZIEL_HOEHE and hoehe > -1.0:
			_abliefern()
	elif waag < DECK_RADIUS and hoehe < DECK_HOEHE and hoehe > -1.0:
		_beladen = true
		DM.paket_zeigen(_modell, true)
		_seit_abholung = 0.0
		_melden("NEUE WARE GELADEN", NEON.CYAN)
		_naechstes_ziel()


func _abliefern() -> void:
	_beladen = false
	DM.paket_zeigen(_modell, false)
	_lieferungen += 1
	var bonus := maxi(0, PUNKTE_ZEIT_MAX - int(_seit_abholung))
	_punkte += PUNKTE_LIEFERUNG + bonus
	_akku += AKKU_PRO_LIEFERUNG
	_paket_fallen_lassen()
	_melden("GELIEFERT: %s  +%d" % [_ziel_name, PUNKTE_LIEFERUNG + bonus], NEON.GELB)
	Eingabe.vibrieren(0.3, 0.2, 0.2)
	_naechstes_ziel()


## Paket faellt sichtbar aus der Drohne aufs Ziel und verschwindet.
func _paket_fallen_lassen() -> void:
	var p := DM.bauen(DM.Stufe.RAHMEN, true)
	for k in p.get_children():
		(k as Node3D).visible = (k as Node3D).position.y == DM.PAKET_Y
	add_child(p)
	p.global_position = _drohne.global_position
	var unten := Vector3(_ziel_pos.x, _ziel_pos.y - DM.PAKET_Y + DM.PAKET.y * 0.5, _ziel_pos.z)
	var tw := create_tween()
	tw.tween_property(p, "global_position", unten, PAKET_FALLZEIT).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_interval(3.0)
	tw.tween_callback(p.queue_free)


func _kamera_soll() -> Vector3:
	var hinten := -Vector3(sin(_gier), 0.0, cos(_gier)) * KAMERA_ABSTAND
	var soll := _drohne.global_position + hinten + Vector3.UP * KAMERA_HOEHE
	# Nicht in Hauswaende: Strahl von der Drohne zur Wunschposition
	var q := PhysicsRayQueryParameters3D.create(_drohne.global_position, soll)
	q.exclude = [_drohne.get_rid()]
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if r.has("position"):
		var hit: Vector3 = r["position"]
		soll = hit + (_drohne.global_position - hit).normalized() * 0.5
	return soll


func _kamera_folgen(delta: float) -> void:
	_kamera.global_position = _kamera.global_position.lerp(_kamera_soll(), minf(1.0, KAMERA_NACHZIEHEN * delta))
	var ziel := _drohne.global_position + Vector3.UP * 0.8
	if _kamera.global_position.distance_to(ziel) > 0.1:
		_kamera.look_at(ziel)


func _beenden(text: String) -> void:
	if _phase == Phase.ENDE:
		return
	_phase = Phase.ENDE
	_melden(text, NEON.MAGENTA)
	_meldung_zeit = 9999.0
	bestwert = maxi(bestwert, _lieferungen)
	if _lieferungen >= ZIEL_LIEFERUNGEN and not GameState.flag(FLAG_GESCHAFFT):
		GameState.flag_setzen(FLAG_GESCHAFFT)
		_belohnung = KERNE_BELOHNUNG
		GameState.mana_kern_hinzu(_belohnung)
	_marker.visible = false


func _schliessen() -> void:
	if _alte_kamera != null and is_instance_valid(_alte_kamera):
		_alte_kamera.make_current()
	EventBus.eingabe_gesperrt.emit(SPERRE_GRUND, false)
	beendet.emit(_lieferungen, _punkte)
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_maus_dreh += (event as InputEventMouseMotion).relative.x * MAUS_DREH
		return
	if event.is_echo():
		return
	match _phase:
		Phase.INTRO:
			if event.is_action_pressed("interagieren") or event.is_action_pressed("ui_accept"):
				_phase = Phase.FLUG
				get_viewport().set_input_as_handled()
		Phase.FLUG:
			var abbruch := (event is InputEventKey and event.is_action_pressed("ui_cancel")) or event.is_action_pressed("journal")
			if abbruch:
				_beenden("LIEFERDIENST ABGEBROCHEN.")
				get_viewport().set_input_as_handled()
		Phase.ENDE:
			if event.is_action_pressed("interagieren") or event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
				get_viewport().set_input_as_handled()
				_schliessen()


# ---------------------------------------------------------------- HUD

func _hud_bauen() -> void:
	var ebene := CanvasLayer.new()
	ebene.layer = EBENE
	add_child(ebene)
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.draw.connect(_zeichnen)
	ebene.add_child(_ui)


func _text(t: String, pos: Vector2, groesse: int, farbe: Color, breite := -1.0, ausr := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	_ui.draw_string(NEON.font(), pos, t, ausr, breite, groesse, farbe)


func _zeichnen() -> void:
	var gr := _ui.size
	var mitte := gr.x * 0.5
	# Oberes Panel: Auftrag, Entfernung, Richtungspfeil
	var pr := Rect2(mitte - 260.0, 14.0, 520.0, 96.0)
	NEON.rahmen(_ui, pr, NEON.GELB if _beladen else NEON.CYAN)
	var auftrag := ("LIEFERN: " if _beladen else "ABHOLEN: ") + _ziel_name
	_text(auftrag, Vector2(pr.position.x, pr.position.y + 34.0), 22, NEON.GELB if _beladen else NEON.CYAN, pr.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	var d := _ziel_pos - _drohne.global_position
	var entf := Vector2(d.x, d.z).length()
	_text("%d M   HÖHE %+d M" % [int(entf), int(-d.y)], Vector2(pr.position.x, pr.position.y + 62.0), 16, Color.WHITE, pr.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	# Pfeil relativ zur Blickrichtung der Kamera
	var kam_vor := -_kamera.global_basis.z
	var winkel := atan2(d.x, d.z) - atan2(kam_vor.x, kam_vor.z)
	var pm := Vector2(mitte, pr.end.y + 34.0)
	var spitze := Vector2(-sin(winkel), -cos(winkel)) * 22.0
	var seite := Vector2(spitze.y, -spitze.x) * 0.5
	_ui.draw_colored_polygon(PackedVector2Array([pm + spitze, pm - spitze * 0.5 + seite, pm - spitze * 0.2, pm - spitze * 0.5 - seite]), NEON.GELB if _beladen else NEON.CYAN)
	# Panel rechts unten (links unten liegt die Minikarte): Akku, Lieferungen, Punkte
	var lr := Rect2(gr.x - 320.0, gr.y - 186.0, 300.0, 150.0)
	NEON.rahmen(_ui, lr, NEON.MAGENTA)
	_text("AKKU %d S" % int(ceil(_akku)), lr.position + Vector2(18.0, 36.0), 20, NEON.ROT if _akku < 20.0 else NEON.CYAN)
	var balken := Rect2(lr.position + Vector2(18.0, 48.0), Vector2(lr.size.x - 36.0, 12.0))
	_ui.draw_rect(balken, Color(1, 1, 1, 0.12))
	var anteil := clampf(_akku / AKKU_START, 0.0, 1.0)
	_ui.draw_rect(Rect2(balken.position, Vector2(balken.size.x * anteil, balken.size.y)), NEON.ROT if _akku < 20.0 else NEON.CYAN)
	_text("LIEFERUNGEN  %d / %d" % [_lieferungen, ZIEL_LIEFERUNGEN], lr.position + Vector2(18.0, 92.0), 18, NEON.GELB)
	_text("PUNKTE  %d    BEST  %d" % [_punkte, bestwert], lr.position + Vector2(18.0, 124.0), 16, Color.WHITE)
	# Steuerungshinweis
	var hilfe := "%s/%s VOR/ZURÜCK  %s/%s DREHEN  %s STEIGEN  %s SINKEN  %s ABBRUCH" % [
		"W", "S", "A", "D", Eingabe.taste("springen"), Eingabe.taste("dash"), "ESC"]
	_text(hilfe, Vector2(0.0, gr.y - 12.0), 13, Color(1, 1, 1, 0.6), gr.x - 20.0, HORIZONTAL_ALIGNMENT_RIGHT)
	# Meldung oder Intro/Ende in der Mitte
	if _phase == Phase.INTRO:
		_mittel_panel(["NEON-MARKT LIEFERDIENST", "BRING DIE WARE ZUM GELBEN STRAHL.", "DANACH ZURÜCK ZUM DECK (CYAN), NEUE WARE HOLEN.", "%d LIEFERUNGEN = BONUS. AKKU IM BLICK BEHALTEN." % ZIEL_LIEFERUNGEN], NEON.GELB)
	elif _phase == Phase.ENDE:
		var zeilen := [_meldung, "LIEFERUNGEN: %d    PUNKTE: %d" % [_lieferungen, _punkte]]
		if _belohnung > 0:
			zeilen.append("BONUS: +%d MANA-KERNE" % _belohnung)
		zeilen.append("%s: SCHLIESSEN" % Eingabe.taste("interagieren"))
		_mittel_panel(zeilen, NEON.MAGENTA)
	elif _meldung_zeit > 0.0:
		_text(_meldung, Vector2(0.0, gr.y * 0.32), 26, _meldung_farbe, gr.x, HORIZONTAL_ALIGNMENT_CENTER)


func _mittel_panel(zeilen: Array, farbe: Color) -> void:
	var gr := _ui.size
	var r := Rect2(gr.x * 0.5 - 330.0, gr.y * 0.5 - 40.0 - zeilen.size() * 16.0, 660.0, 50.0 + zeilen.size() * 34.0)
	NEON.rahmen(_ui, r, farbe)
	for i in zeilen.size():
		_text(String(zeilen[i]), Vector2(r.position.x, r.position.y + 42.0 + i * 34.0), 22 if i == 0 else 18, farbe if i == 0 else Color.WHITE, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
