extends "res://levels/power_node.gd"
## Receiver: Empfaenger-Lampe. Leuchtet, wenn der Eingang Strom hat, und sendet `ausgeloest(active)`
## (z. B. fuer Licht, Aufzug, Bruecke). Aufruf: eingang_setzen(knoten).

signal ausgeloest(active: bool)

var _lampe: StandardMaterial3D


func _ready() -> void:
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.8
	s.height = 1.6
	m.mesh = s
	_lampe = StandardMaterial3D.new()
	_lampe.emission_enabled = true
	m.material_override = _lampe
	m.position.y = 1.2
	add_child(m)
	_darstellen()


func eingang_setzen(e: Node) -> void:
	e.power_changed.connect(func(an: bool) -> void: _setzen(an))
	_setzen(bool(e.get("aktiv")))


func _setzen(an: bool) -> void:
	var vorher := aktiv
	super(an)
	if aktiv != vorher:
		ausgeloest.emit(aktiv)


func _darstellen() -> void:
	if _lampe == null:
		return
	_lampe.albedo_color = farbe if aktiv else Color(0.08, 0.08, 0.1)
	_lampe.emission = farbe
	_lampe.emission_energy_multiplier = 4.0 if aktiv else 0.1
