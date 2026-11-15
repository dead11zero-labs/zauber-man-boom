extends "res://characters/enemy.gd"
## Spaehdrohne: schwebt in Kopfhoehe, haelt Abstand zum Spieler, kreist leicht und schiesst langsame Funkenkugeln.
## Stoert Raetsel: auf Patrouille schiesst sie ab und zu auf eingeschaltete Stromquellen in der Naehe
## (die gehen aus, ein Blitz schaltet sie wieder an; geloeste Tore bleiben offen).
## Daten: res://data/gegner/spaehdrohne.tres. Signale: siehe enemy.gd.

const STANDARD := preload("res://data/gegner/spaehdrohne.tres")
const FUNKENKUGEL := preload("res://characters/funkenkugel.gd")

const KOERPER_RADIUS := 0.55
const RING_RADIUS := 0.85
const RING_DICKE := 0.08
const AUGE_RADIUS := 0.2
const AUGE_ABSTAND := 0.5
const ROTOR_ANZAHL := 4
const ROTOR_ABSTAND := 0.75
const ROTOR_TEMPO := 30.0
const SCHWANKEN_TEMPO := 2.2
const SCHWANKEN_HOEHE := 0.15
## Seitliches Kreisen beim Jagen (Anteil vom Jagdtempo)
const KREISEN := 0.45
## Toleranz um den Halteabstand
const ABSTAND_TOLERANZ := 2.0
## Raetsel stoeren: so oft (Sekunden) und so weit (Meter)
## Aus = Raetsel bleiben ungestoert (ruhiger Spielfluss). Auf true setzen, um das Stoeren wieder zu erlauben.
const STOEREN_AKTIV := false
const STOER_PAUSE := 9.0
const STOER_REICHWEITE := 20.0
const AUSHOL_ENERGIE := 8.0
const AUGE_ENERGIE := 3.0
const ZIEL_STREUUNG := 0.6

var _rotoren: Array[Node3D] = []
var _auge_mat: StandardMaterial3D
var _kreis_richtung := 1.0
var _stoer_timer := STOER_PAUSE
var _schuss_ziel: Node3D = null
var _zeit := 0.0


func _standard_daten() -> GEGNER_DATEN:
	return STANDARD


func _modell_bauen() -> void:
	_form_setzen(KOERPER_RADIUS + 0.15)
	var c := daten.farbe
	var gehaeuse := StandardMaterial3D.new()
	gehaeuse.albedo_color = Color(0.07, 0.08, 0.11)
	gehaeuse.metallic = 0.8
	gehaeuse.roughness = 0.3
	var k := MeshInstance3D.new()
	var km := SphereMesh.new()
	km.radius = KOERPER_RADIUS
	km.height = KOERPER_RADIUS * 1.4
	k.mesh = km
	k.material_override = gehaeuse
	_modell.add_child(k)
	var ring := MeshInstance3D.new()
	var rm := TorusMesh.new()
	rm.inner_radius = RING_RADIUS - RING_DICKE
	rm.outer_radius = RING_RADIUS
	ring.mesh = rm
	ring.material_override = _neon_mat(c, 2.5)
	_modell.add_child(ring)
	var auge := MeshInstance3D.new()
	var am := SphereMesh.new()
	am.radius = AUGE_RADIUS
	am.height = AUGE_RADIUS * 2.0
	auge.mesh = am
	_auge_mat = _neon_mat(c.lightened(0.3), AUGE_ENERGIE)
	auge.material_override = _auge_mat
	auge.position = Vector3(0, 0, -AUGE_ABSTAND)
	_modell.add_child(auge)
	for i in ROTOR_ANZAHL:
		var w := TAU * i / ROTOR_ANZAHL + PI / 4.0
		var r := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.5, 0.03, 0.08)
		r.mesh = bm
		r.material_override = _neon_mat(c, 1.2)
		var halter := Node3D.new()
		halter.position = Vector3(cos(w) * ROTOR_ABSTAND, 0.25, sin(w) * ROTOR_ABSTAND)
		halter.add_child(r)
		_modell.add_child(halter)
		_rotoren.append(halter)
	var licht := OmniLight3D.new()
	licht.light_color = c
	licht.light_energy = 1.2
	licht.omni_range = 4.0
	_modell.add_child(licht)
	_kreis_richtung = 1.0 if randf() < 0.5 else -1.0


func _process(delta: float) -> void:
	_zeit += delta
	for r in _rotoren:
		r.rotate_y(ROTOR_TEMPO * delta)
	if zustand != Zustand.DEAD:
		_modell.position.y = sin(_zeit * SCHWANKEN_TEMPO) * SCHWANKEN_HOEHE


func _patrouillieren(delta: float) -> void:
	super._patrouillieren(delta)
	if zustand != Zustand.PATROL and zustand != Zustand.IDLE:
		return
	if not STOEREN_AKTIV:
		return
	_stoer_timer -= delta
	if _stoer_timer > 0.0:
		return
	_stoer_timer = STOER_PAUSE
	var ziel := _stoerziel_finden()
	if ziel != null:
		_schuss_ziel = ziel
		zustand_setzen(Zustand.ATTACK)
		_angriff_start()


## Naechste eingeschaltete Stromquelle (Methode stoeren, aktiv) in Reichweite, sonst null.
func _stoerziel_finden() -> Node3D:
	var bestes: Node3D = null
	var best := STOER_REICHWEITE
	for n in get_tree().get_nodes_in_group("blitz_ziel"):
		if not n.has_method("stoeren") or n.get("aktiv") != true:
			continue
		var d := global_position.distance_to((n as Node3D).global_position)
		if d < best:
			best = d
			bestes = n as Node3D
	return bestes


func _jagen(delta: float) -> void:
	var dist := _abstand_spieler()
	var ziel := _spieler.global_position
	_schauen_zu(ziel, delta)
	var zu := Vector3(ziel.x - global_position.x, 0.0, ziel.z - global_position.z).normalized()
	var seite := zu.cross(Vector3.UP) * _kreis_richtung
	var soll := seite * daten.tempo_jagd * KREISEN
	if dist > daten.halteabstand + ABSTAND_TOLERANZ:
		soll += zu * daten.tempo_jagd
	elif dist < daten.halteabstand - ABSTAND_TOLERANZ:
		soll -= zu * daten.tempo_jagd
	_horizontal_auf(soll, delta)
	if get_slide_collision_count() > 0:
		_kreis_richtung = -_kreis_richtung


func _angriff_start() -> void:
	if _schuss_ziel == null:
		_schuss_ziel = _spieler
	_auge_mat.emission_energy_multiplier = AUSHOL_ENERGIE


func _angriff(delta: float) -> void:
	_bremsen(delta)
	if _schuss_ziel == null or not is_instance_valid(_schuss_ziel):
		_schuss_ziel = null
		_angriff_beenden()
		return
	var zp := _zielpunkt(_schuss_ziel)
	_schauen_zu(zp, delta)
	if _zustand_zeit < daten.ausholen:
		return
	_schiessen(zp)
	_auge_mat.emission_energy_multiplier = AUGE_ENERGIE
	var war_raetsel := _schuss_ziel != _spieler
	_schuss_ziel = null
	if war_raetsel:
		zustand_setzen(Zustand.PATROL)
	else:
		_angriff_beenden()


func _zielpunkt(z: Node3D) -> Vector3:
	if z == _spieler:
		return _spieler_punkt()
	return z.call("ziel_punkt") if z.has_method("ziel_punkt") else z.global_position


func _schiessen(ziel: Vector3) -> void:
	var start := global_position + (-global_basis.z) * (AUGE_ABSTAND + 0.3)
	var d := ziel + Vector3(randf_range(-ZIEL_STREUUNG, ZIEL_STREUUNG), 0.0, randf_range(-ZIEL_STREUUNG, ZIEL_STREUUNG)) - start
	var k: Area3D = FUNKENKUGEL.new()
	get_parent().add_child(k)
	k.global_position = start
	k.start(d.normalized() * daten.projektil_tempo, self, daten.schaden)
