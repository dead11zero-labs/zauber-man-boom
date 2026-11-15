extends Node3D
## Kamera-Arm mit Kollision: haelt die Kamera vor Waenden, Decken und Boeden, damit man nicht
## durch Gebaeude hindurchschaut. Tastet mit einer Kugel vom Drehpunkt zur Wunschposition und
## zieht die Kamera heran, sobald etwas dazwischen liegt (sofort hinein, weich wieder hinaus).
## Bewegliche Koerper (Gegner, NPCs) werden ignoriert, sonst zuckt die Kamera.
## Signal `naehe_geaendert(nah)`: true, wenn die Kamera so dicht an der Figur ist, dass diese
## ausgeblendet werden sollte (sonst schaut man ins Modell).

signal naehe_geaendert(nah: bool)

## Wunschabstand der Kamera hinter dem Drehpunkt (Meter)
@export var laenge := 3.2
## Radius der Tastkugel; groesser als die Near-Ebene der Kamera, damit keine Wand angeschnitten wird
@export var radius := 0.32
## Kleinster Abstand zum Drehpunkt
@export var min_abstand := 0.25
## Tempo, mit dem die Kamera wieder auf Abstand geht (m/s)
@export var rueck_tempo := 6.0
## Unterhalb dieses Abstands gilt die Kamera als "nah" (Figur ausblenden)
@export var nah_grenze := 1.1
## Kollisionsebenen, die die Kamera blockieren
@export_flags_3d_physics var maske := 1

const MAX_AUSNAHMEN := 4      # so viele bewegliche Koerper werden pro Abtastung uebersprungen
const SICHERHEIT := 0.04      # Abstand, den die Kamera vor dem Hindernis bleibt

var abstand := 3.2
var _nah := false
var _kugel := SphereShape3D.new()

@onready var kamera: Camera3D = $Kamera


func _ready() -> void:
	abstand = laenge
	_kugel.radius = radius
	# Nach der Spielerbewegung abtasten, sonst hinkt die Kamera einen Frame hinterher
	process_physics_priority = 10


func _physics_process(delta: float) -> void:
	var frei := _freie_strecke()
	if frei < abstand:
		abstand = frei
	else:
		abstand = move_toward(abstand, frei, rueck_tempo * delta)
	kamera.position = Vector3(0.0, 0.0, abstand)
	var nah := abstand < nah_grenze
	if nah != _nah:
		_nah = nah
		naehe_geaendert.emit(nah)


## Freie Strecke vom Drehpunkt in Richtung Kamera (hoechstens `laenge`).
func _freie_strecke() -> float:
	var raum := get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _kugel
	q.collision_mask = maske
	q.transform = Transform3D(Basis.IDENTITY, global_position)
	q.motion = global_basis.z * laenge
	var ausnahmen: Array[RID] = []
	var besitzer := get_parent() as CollisionObject3D
	if besitzer != null:
		ausnahmen.append(besitzer.get_rid())
	for i in MAX_AUSNAHMEN:
		q.exclude = ausnahmen
		var anteil: float = raum.cast_motion(q)[0]
		if anteil >= 1.0:
			return laenge
		# Wer steht im Weg? Bewegliche Koerper ueberspringen und neu tasten.
		var p := PhysicsShapeQueryParameters3D.new()
		p.shape = _kugel
		p.collision_mask = maske
		p.exclude = ausnahmen
		p.transform = Transform3D(Basis.IDENTITY, global_position + q.motion * minf(anteil + 0.02, 1.0))
		var treffer := raum.get_rest_info(p)
		var koerper: Object = instance_from_id(treffer["collider_id"]) if treffer.has("collider_id") else null
		if koerper is CharacterBody3D or koerper is RigidBody3D:
			ausnahmen.append(treffer["rid"])
			continue
		return maxf(laenge * anteil - SICHERHEIT, min_abstand)
	return laenge
