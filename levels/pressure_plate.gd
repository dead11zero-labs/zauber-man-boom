extends Area3D
## Druckplatte: aktiv, solange Spieler oder ein Koerper der Gruppe "gewicht" (NPC, Fahrzeug) darauf steht.
## Exportiert: farbe, bleibt_an (einmal gedrueckt = dauerhaft aktiv). Signal: power_changed(active).

signal power_changed(active: bool)

@export var farbe := Color(1.0, 0.85, 0.2)
@export var bleibt_an := false

const GROESSE := Vector3(2.4, 0.2, 2.4)
const GRUPPEN: Array[String] = ["spieler", "gewicht"]

var aktiv := false
var _mat: StandardMaterial3D
var _zahl := 0


func _ready() -> void:
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(GROESSE.x, 0.8, GROESSE.z)
	cs.shape = box
	cs.position.y = 0.4
	add_child(cs)
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = GROESSE
	m.mesh = bm
	_mat = StandardMaterial3D.new()
	_mat.emission_enabled = true
	m.material_override = _mat
	m.position.y = GROESSE.y * 0.5
	add_child(m)
	body_entered.connect(_rein)
	body_exited.connect(_raus)
	_darstellen()


func _zaehlt(b: Node) -> bool:
	for g in GRUPPEN:
		if b.is_in_group(g):
			return true
	return false


func _rein(b: Node) -> void:
	if _zaehlt(b):
		_zahl += 1
		_setzen(true)


func _raus(b: Node) -> void:
	if _zaehlt(b):
		_zahl = maxi(_zahl - 1, 0)
		if _zahl == 0 and not bleibt_an:
			_setzen(false)


func _setzen(an: bool) -> void:
	if an == aktiv:
		return
	aktiv = an
	_darstellen()
	power_changed.emit(aktiv)


func _darstellen() -> void:
	_mat.albedo_color = farbe if aktiv else farbe.darkened(0.7)
	_mat.emission = farbe
	_mat.emission_energy_multiplier = 3.0 if aktiv else 0.2


func ziel_punkt() -> Vector3:
	return global_position + Vector3.UP * GROESSE.y
