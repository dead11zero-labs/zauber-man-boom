extends CharacterBody3D
## Synth-Bot: laeuft auf den Strassen von Synth-City von Kreuzung zu Kreuzung.

## Strassen-Knoten (x, z) und Verbindungen: Kreuzungen des Strassennetzes (levels/strassen_daten.gd),
## die Wege fuehren ueber die Bruecken. Gelaufen wird auf dem Gehweg neben der Fahrbahn.
const KNOTEN: Array[Vector2] = [
	Vector2(0, -206), Vector2(0, -90), Vector2(0, 130), Vector2(0, 198),
	Vector2(-300, -90), Vector2(205, -90), Vector2(-300, 130), Vector2(205, 130),
	Vector2(205, -206), Vector2(205, 198), Vector2(-300, 198),
]
const KANTEN := {0: [1, 8], 1: [0, 2, 4, 5], 2: [1, 3, 6, 7], 3: [2, 9, 10], 4: [1, 6], 5: [1, 7, 8],
	6: [2, 4, 10], 7: [2, 5, 9], 8: [0, 5], 9: [3, 7], 10: [3, 6]}
## Abstand zur Fahrbahnkante (passt auch auf die Gehwege der Bruecken)
const GEHWEG_MIN := 0.5
const GEHWEG_MAX := 0.9
const GRAVITY := 30.0

var tempo := 2.2
var _knoten := 0
var _vorher := -1
var _ziel := Vector3.ZERO
var _pause := 0.0
var _spur := 0.0
var _zeit := 0.0
var _steck_t := 0.0
var _steck_pos := Vector3.ZERO
var _schreck := 0.0
var _bereit := false
var _sprung := 0.0

@onready var modell: Node3D = $Modell


func _ready() -> void:
	randomize()
	tempo = randf_range(1.8, 3.0)
	_spur = randf_range(GEHWEG_MIN, GEHWEG_MAX) * (1.0 if randf() < 0.5 else -1.0)
	add_to_group("verkehr_hindernis")  # Autos bremsen fuer Synth-Bots (vehicles/verkehr.gd)
	_zeit = randf() * 10.0
	modell.scale *= randf_range(0.95, 1.1)
	# Startpunkt: zufaellig auf einer Strasse
	_knoten = randi() % KNOTEN.size()
	var nach: int = KANTEN[_knoten].pick_random()
	var t := randf()
	var a := KNOTEN[_knoten]
	var b := KNOTEN[nach]
	var p := a.lerp(b, t)
	var d := (b - a).normalized()
	p += Vector2(-d.y, d.x) * _versatz(a, b)
	global_position = Vector3(p.x, 0.2, p.y)
	_vorher = _knoten
	_knoten = nach
	_ziel = _knoten_punkt(_knoten, _vorher)
	_bereit = true


## Seitlicher Versatz auf den Gehweg der Strasse zwischen a und b (Vorzeichen = Strassenseite).
func _versatz(a: Vector2, b: Vector2) -> float:
	return signf(_spur) * (StrassenDaten.breite_bei((a + b) * 0.5) * 0.5 + absf(_spur))


## Zielpunkt am Knoten, seitlich versetzt (eigene Spur), Richtung aus der letzten Strasse
func _knoten_punkt(k: int, von: int) -> Vector3:
	var d := (KNOTEN[k] - KNOTEN[von]).normalized()
	var p := KNOTEN[k] + Vector2(-d.y, d.x) * _versatz(KNOTEN[von], KNOTEN[k])
	return Vector3(p.x, 0.0, p.y)


func _naechster() -> void:
	var optionen: Array = KANTEN[_knoten].duplicate()
	if optionen.size() > 1:
		optionen.erase(_vorher)
	var nach: int = optionen.pick_random()
	_vorher = _knoten
	_knoten = nach
	_ziel = _knoten_punkt(_knoten, _vorher)


func _physics_process(delta: float) -> void:
	if not _bereit:
		return
	_zeit += delta
	_schreck = maxf(_schreck - delta, 0.0)
	var laeuft := false
	var richtung := Vector3(_ziel.x - global_position.x, 0.0, _ziel.z - global_position.z)
	if _pause > 0.0:
		_pause -= delta
	elif richtung.length() < 1.5:
		# Angekommen: manchmal kurz stehen bleiben (Schwatz mit der Strassenlaterne)
		if randf() < 0.35:
			_pause = randf_range(1.0, 3.5)
		_naechster()
	else:
		laeuft = true
		richtung = richtung.normalized()
		var v := richtung * tempo * (2.2 if _schreck > 0.0 else 1.0)
		velocity.x = move_toward(velocity.x, v.x, 20.0 * delta)
		velocity.z = move_toward(velocity.z, v.z, 20.0 * delta)
		rotation.y = lerp_angle(rotation.y, atan2(-richtung.x, -richtung.z), 6.0 * delta)
	if not laeuft:
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()

	# Haengt er fest (Hindernis)? Dann umkehren
	_steck_t += delta
	if _steck_t > 1.5:
		if laeuft and global_position.distance_to(_steck_pos) < 0.6:
			var alt := _knoten
			_knoten = _vorher
			_vorher = alt
			_ziel = _knoten_punkt(_knoten, _vorher)
		_steck_pos = global_position
		_steck_t = 0.0

	_animieren(delta, laeuft)


## Das Modell hat kein Skelett: Laufen wird mit Wippen, Pendeln und Vorneigen angedeutet.
func _animieren(delta: float, laeuft: bool) -> void:
	var fl := Vector2(velocity.x, velocity.z).length()
	var takt := _zeit * (5.0 + fl * 1.2)
	var stark := clampf(fl / 2.0, 0.0, 1.5)
	_sprung = maxf(_sprung - delta * 3.0, 0.0)
	modell.position.y = 0.95 + absf(sin(takt)) * 0.08 * stark + sin(_sprung * PI) * 0.7
	modell.rotation.z = sin(takt) * 0.07 * stark
	modell.rotation.x = 0.06 * stark
	if not laeuft:
		modell.position.y = 0.95 + sin(_sprung * PI) * 0.7 + sin(_zeit * 1.6) * 0.012
		modell.rotation.z = lerpf(modell.rotation.z, 0.0, 5.0 * delta)
		modell.rotation.x = lerpf(modell.rotation.x, 0.0, 5.0 * delta)


## Zauberblitz getroffen: erschrickt, huepft und rennt kurz schneller
func treffer() -> void:
	_schreck = 3.0
	_sprung = 1.0
	_pause = 0.0
