extends CharacterBody3D
## Synth-Bot: laeuft auf den Strassen von Synth-City von Kreuzung zu Kreuzung.
## Bewegung (Ideen aus CogitoNPC, eigene Steuerung): NPCs weichen einander und dem Spieler aus (Abstossung im
## Nahbereich, Entgegenkommende werden rechts passiert; NavigationAgent3D-Ausweichen liefert ohne Navmesh nur
## Stillstand, deshalb eigenes Lenken). Weiches Anfahren und
## Bremsen, Kurven werden vor dem Knoten angeschnitten, das Schlendertempo schwankt leicht. Kommt der Spieler nahe,
## bleibt der NPC manchmal kurz stehen und schaut ihn an. Haengt er trotzdem fest, tritt er erst zur Seite, dann kehrt er um.

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
const BESCHLEUNIGUNG := 4.0          ## m/s^2 Anfahren und Bremsen (vorher praktisch sofort)
const DREH_TEMPO := 5.0
const ANKUNFT := 1.5
const KURVE_AB := 4.0                 ## ab diesem Abstand zum Knoten wird schon Richtung naechster Strasse gelenkt
const TEMPO_SCHWANKUNG := 0.15
const AUSWEICH_NAH := 2.2             ## Abstossung unterhalb dieses Abstands
const AUSWEICH_VORAUS := 4.0          ## Entgegenkommende in diesem Abstand werden rechts passiert
const AUSWEICH_KEGEL := 0.6           ## cos des Winkels, in dem jemand "vorn" steht
const AUSWEICH_STAERKE := 1.2
const GRUPPE := "npc_fussgaenger"
const BLICK_ABSTAND := 4.5            ## so nah muss der Spieler kommen, damit der NPC schaut
const BLICK_CHANCE := 0.35            ## je Annaeherung
const BLICK_DAUER := Vector2(1.5, 3.0)
const FEST_ZEIT := 1.5
const FEST_WEG := 0.6

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
var _wunsch := Vector3.ZERO
var _folge := Vector3.ZERO           ## Zielpunkt nach dem aktuellen (fuer das Anschneiden der Kurve)
var _tempo_phase := 0.0
var _spieler: Node3D
var _spieler_nah := false
var _blick_zeit := 0.0
var _fest_mal := 0

@onready var modell: Node3D = $Modell


func _ready() -> void:
	add_to_group("maschine")  # Zutrittskontrolle im Zauber-Tower (levels/scanner_schleuse.gd)
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
	_folge = _folge_punkt()
	_tempo_phase = randf() * TAU
	add_to_group(GRUPPE)
	_bereit = true


## Seitlicher Versatz auf den Gehweg der Strasse zwischen a und b (Vorzeichen = Strassenseite).
func _versatz(a: Vector2, b: Vector2) -> float:
	return signf(_spur) * (StrassenDaten.breite_bei((a + b) * 0.5) * 0.5 + absf(_spur))


## Zielpunkt am Knoten, seitlich versetzt (eigene Spur), Richtung aus der letzten Strasse
func _knoten_punkt(k: int, von: int) -> Vector3:
	var d := (KNOTEN[k] - KNOTEN[von]).normalized()
	var p := KNOTEN[k] + Vector2(-d.y, d.x) * _versatz(KNOTEN[von], KNOTEN[k])
	return Vector3(p.x, 0.0, p.y)


## Waehlt den Knoten nach dem aktuellen Ziel vorab (damit die Kurve frueh angeschnitten werden kann).
var _naechster_knoten := -1


func _folge_punkt() -> Vector3:
	var optionen: Array = KANTEN[_knoten].duplicate()
	if optionen.size() > 1:
		optionen.erase(_vorher)
	_naechster_knoten = optionen.pick_random()
	return _knoten_punkt(_naechster_knoten, _knoten)


func _naechster() -> void:
	var nach := _naechster_knoten
	if nach < 0:
		_folge_punkt()
		nach = _naechster_knoten
	_vorher = _knoten
	_knoten = nach
	_ziel = _knoten_punkt(_knoten, _vorher)
	_folge = _folge_punkt()


func _physics_process(delta: float) -> void:
	if not _bereit:
		return
	_zeit += delta
	_schreck = maxf(_schreck - delta, 0.0)
	_blick_zeit = maxf(_blick_zeit - delta, 0.0)
	_spieler_pruefen()
	var laeuft := false
	var zum_ziel := Vector3(_ziel.x - global_position.x, 0.0, _ziel.z - global_position.z)
	var soll := Vector3.ZERO
	if _blick_zeit > 0.0:
		_zum_spieler_drehen(delta)
	elif _pause > 0.0:
		_pause -= delta
	elif zum_ziel.length() < ANKUNFT:
		# Angekommen: manchmal kurz stehen bleiben (Schwatz mit der Strassenlaterne)
		if randf() < 0.35:
			_pause = randf_range(1.0, 3.5)
		_naechster()
	else:
		laeuft = true
		var richtung := zum_ziel.normalized()
		# Kurve anschneiden: kurz vor dem Knoten schon Richtung Folgepunkt lenken
		var rest := zum_ziel.length()
		if rest < KURVE_AB:
			var weiter := Vector3(_folge.x - global_position.x, 0.0, _folge.z - global_position.z).normalized()
			richtung = richtung.lerp(weiter, (1.0 - rest / KURVE_AB) * 0.6).normalized()
		var schlendern := 1.0 + sin(_zeit * 0.35 + _tempo_phase) * TEMPO_SCHWANKUNG
		soll = richtung * tempo * schlendern * (2.2 if _schreck > 0.0 else 1.0)
		rotation.y = lerp_angle(rotation.y, atan2(-richtung.x, -richtung.z), DREH_TEMPO * delta)
	if laeuft:
		soll = _ausweichen(soll)
	_wunsch.x = move_toward(_wunsch.x, soll.x, BESCHLEUNIGUNG * delta)
	_wunsch.z = move_toward(_wunsch.z, soll.z, BESCHLEUNIGUNG * delta)
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	velocity.x = _wunsch.x
	velocity.z = _wunsch.z
	move_and_slide()

	# Haengt er fest (Hindernis)? Erst zur Seite treten, beim zweiten Mal umkehren
	_steck_t += delta
	if _steck_t > FEST_ZEIT:
		if laeuft and global_position.distance_to(_steck_pos) < FEST_WEG:
			_fest_mal += 1
			if _fest_mal == 1:
				var seite := Vector3(-zum_ziel.z, 0.0, zum_ziel.x).normalized() * signf(_spur)
				_wunsch = seite * tempo
			else:
				_fest_mal = 0
				var alt := _knoten
				_knoten = _vorher
				_vorher = alt
				_ziel = _knoten_punkt(_knoten, _vorher)
				_folge = _folge_punkt()
		else:
			_fest_mal = 0
		_steck_pos = global_position
		_steck_t = 0.0

	_animieren(delta, laeuft)


## Lenkt um andere Fussgaenger und den Spieler herum: Abstossung im Nahbereich, Entgegenkommende rechts passieren.
func _ausweichen(soll: Vector3) -> Vector3:
	var schub := Vector3.ZERO
	var vor := soll.normalized()
	var rechts := vor.cross(Vector3.UP)
	var andere: Array = get_tree().get_nodes_in_group(GRUPPE)
	if _spieler != null:
		andere.append(_spieler)
	for o: Node3D in andere:
		if o == self:
			continue
		var d := global_position - o.global_position
		d.y = 0.0
		var l := d.length()
		if l < 0.01 or l > AUSWEICH_VORAUS:
			continue
		if l < AUSWEICH_NAH:
			schub += d / l * (AUSWEICH_NAH - l) / AUSWEICH_NAH
		if (-d / l).dot(vor) > AUSWEICH_KEGEL:
			schub += rechts * (AUSWEICH_VORAUS - l) / AUSWEICH_VORAUS
	return soll + schub * tempo * AUSWEICH_STAERKE


## Spieler kommt nahe: manchmal stehen bleiben und hinschauen (einmal je Annaeherung).
func _spieler_pruefen() -> void:
	if _spieler == null or not is_instance_valid(_spieler):
		_spieler = get_tree().get_first_node_in_group("spieler") as Node3D
		return
	var d := _spieler.global_position - global_position
	var nah := Vector2(d.x, d.z).length() < BLICK_ABSTAND and absf(d.y) < 3.0
	if nah and not _spieler_nah and _schreck <= 0.0 and randf() < BLICK_CHANCE:
		_blick_zeit = randf_range(BLICK_DAUER.x, BLICK_DAUER.y)
	_spieler_nah = nah


func _zum_spieler_drehen(delta: float) -> void:
	var d := _spieler.global_position - global_position
	rotation.y = lerp_angle(rotation.y, atan2(-d.x, -d.z), DREH_TEMPO * delta)


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
	_blick_zeit = 0.0
