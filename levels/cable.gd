extends "res://levels/power_node.gd"
## Kabel: leitet den Zustand von `von` weiter (aktiv = von.aktiv) und leuchtet in dessen Farbe.
## Verlegt wird es auf dem Boden im rechten Winkel von `von.ziel_punkt()` nach `nach.ziel_punkt()`.
## Aufruf: verbinden(von, nach). Der Empfaenger bindet das Kabel selbst als Eingang ein.

const DICKE := 0.14
const BODEN_Y := 0.12
const ENERGIE_AN := 4.0
const ENERGIE_AUS := 0.15

var _von: Node
var _mat: StandardMaterial3D


func verbinden(von: Node, nach: Node) -> void:
	_von = von
	var c = von.get("farbe")
	farbe = c if c is Color else farbe
	_mat = StandardMaterial3D.new()
	_mat.emission_enabled = true
	_mat.albedo_color = farbe.darkened(0.7)
	_mat.emission = farbe
	var p1: Vector3 = von.ziel_punkt()
	var p2: Vector3 = nach.ziel_punkt()
	var punkte: Array[Vector3] = [
		p1, Vector3(p1.x, BODEN_Y, p1.z), Vector3(p2.x, BODEN_Y, p1.z), Vector3(p2.x, BODEN_Y, p2.z), p2,
	]
	for i in punkte.size() - 1:
		_strecke(punkte[i], punkte[i + 1])
	von.power_changed.connect(func(an: bool) -> void: _setzen(an))
	_setzen(bool(von.get("aktiv")))
	_darstellen()


func _strecke(a: Vector3, b: Vector3) -> void:
	if a.distance_to(b) < 0.01:
		return
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	var d := (b - a).abs()
	box.size = Vector3(maxf(d.x, DICKE), maxf(d.y, DICKE), maxf(d.z, DICKE))
	m.mesh = box
	m.material_override = _mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	m.global_position = (a + b) * 0.5


func _darstellen() -> void:
	if _mat == null:
		return
	_mat.albedo_color = farbe if aktiv else farbe.darkened(0.7)
	_mat.emission_energy_multiplier = ENERGIE_AN if aktiv else ENERGIE_AUS
