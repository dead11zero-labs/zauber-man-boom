class_name Collectible
extends Area3D
## Basisklasse aller Sammelobjekte. Spieler beruehrt -> GameState.einsammeln(), Sound und Funken.
## Persistenz: Jedes feste Objekt hat eine id. Bereits eingesammelte ids tauchen nicht wieder auf.
## Signale: eingesammelt(daten). Exportiert: daten (CollectibleData).

signal eingesammelt(p_daten: CollectibleData)

@export var daten: CollectibleData
var id: String = ""
var bezirk: int = 0
var _genommen := false

static var _klaenge: Dictionary = {}


## Meldet das Objekt beim GameState an (fuer Bezirks-Abschluss). false = war schon eingesammelt.
static func registrieren(p_id: String, typ: int, pos: Vector3) -> bool:
	return GameState.registrieren(Bezirke.bezirk_an(pos.x, pos.z), typ, p_id)


func einsammeln(body: Node) -> bool:
	if _genommen or daten == null or not body.is_in_group("spieler"):
		return false
	_genommen = true
	set_deferred("monitoring", false)
	GameState.einsammeln(id, daten, Bezirke.bezirk_an(global_position.x, global_position.z))
	if body.has_method("kristall_gesammelt") and daten.typ == CollectibleData.Typ.MANA_KERN:
		body.kristall_gesammelt()
	_effekt()
	eingesammelt.emit(daten)
	return true


func _effekt() -> void:
	var ziel := get_parent()
	if ziel == null:
		return
	var funken := CPUParticles3D.new()
	funken.emitting = false
	funken.one_shot = true
	funken.explosiveness = 1.0
	funken.amount = 24 if daten.typ == CollectibleData.Typ.SEITE else 12
	funken.lifetime = 0.6
	funken.direction = Vector3.UP
	funken.spread = 180.0
	funken.initial_velocity_min = 3.0
	funken.initial_velocity_max = 7.0
	funken.gravity = Vector3(0, -6, 0)
	var m := SphereMesh.new()
	m.radius = 0.08
	m.height = 0.16
	var mat := StandardMaterial3D.new()
	mat.albedo_color = daten.farbe
	mat.emission_enabled = true
	mat.emission = daten.farbe
	mat.emission_energy_multiplier = 4.0
	m.material = mat
	funken.mesh = m
	ziel.add_child(funken)
	funken.global_position = global_position
	funken.emitting = true
	var ton := AudioStreamPlayer3D.new()
	ton.stream = _klang(daten.typ)
	ton.volume_db = -4.0
	ton.max_distance = 60.0
	ziel.add_child(ton)
	ton.global_position = global_position
	ton.play()
	ziel.get_tree().create_timer(1.5).timeout.connect(func() -> void:
		if is_instance_valid(funken):
			funken.queue_free()
		if is_instance_valid(ton):
			ton.queue_free())


## Kleiner synthetischer Aufwaerts-Ton je Typ (keine Sounddateien noetig).
static func _klang(typ: int) -> AudioStreamWAV:
	if _klaenge.has(typ):
		return _klaenge[typ]
	var rate := 22050
	var dauer := 0.7 if typ == CollectibleData.Typ.SEITE else 0.22
	var n := int(rate * dauer)
	var f0: float = [880.0, 660.0, 520.0, 392.0, 600.0][clampi(typ, 0, 4)]
	var daten_b := PackedByteArray()
	daten_b.resize(n * 2)
	for i in n:
		var t := float(i) / rate
		var s := sin(TAU * f0 * t * (1.0 + t * 1.6)) * exp(-t * (4.0 if typ == CollectibleData.Typ.SEITE else 11.0))
		s += 0.4 * sin(TAU * f0 * 2.0 * t) * exp(-t * 14.0)
		daten_b.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 18000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = daten_b
	_klaenge[typ] = w
	return w
