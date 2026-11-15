extends "res://levels/power_node.gd"
## Relay: kombiniert mehrere Eingaenge. UND = alle muessen Strom haben, ODER = mindestens einer.
## Aufruf: eingang_hinzu(knoten). Exportiert: modus (UND/ODER).

enum Modus { UND, ODER }

@export var modus := Modus.UND

var _eingaenge: Array[Node] = []
var _lampe: StandardMaterial3D


func _ready() -> void:
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.0, 0.8, 1.0)
	m.mesh = box
	_lampe = StandardMaterial3D.new()
	_lampe.emission_enabled = true
	m.material_override = _lampe
	m.position.y = 0.4
	add_child(m)
	var l := Label3D.new()
	l.text = "UND" if modus == Modus.UND else "ODER"
	l.font_size = 40
	l.pixel_size = 0.01
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.shaded = false
	l.position.y = 1.4
	add_child(l)
	_darstellen()


func eingang_hinzu(e: Node) -> void:
	_eingaenge.append(e)
	e.power_changed.connect(func(_an: bool) -> void: _pruefen())
	_pruefen()


func _pruefen() -> void:
	var n := 0
	for e in _eingaenge:
		if bool(e.get("aktiv")):
			n += 1
	_setzen(n == _eingaenge.size() if modus == Modus.UND else n > 0)


func _darstellen() -> void:
	if _lampe == null:
		return
	_lampe.albedo_color = farbe if aktiv else Color(0.08, 0.08, 0.1)
	_lampe.emission = farbe
	_lampe.emission_energy_multiplier = 3.0 if aktiv else 0.1
