class_name PowerNode
extends Node3D
## Basis fuer Strom-Bausteine ohne eigene Physik (Relay, Cable, Receiver). Alles, was `aktiv` hat und
## `power_changed(active)` sendet (auch PowerSource), kann als Eingang dienen (Duck-Typing).
## Signal: power_changed(active: bool). Exportiert: farbe.

signal power_changed(active: bool)

@export var farbe := Color(0.2, 0.9, 1.0)

var aktiv := false


func _setzen(an: bool) -> void:
	if an == aktiv:
		return
	aktiv = an
	power_changed.emit(aktiv)
	_darstellen()


func _darstellen() -> void:
	pass


## Punkt, an dem Kabel andocken.
func ziel_punkt() -> Vector3:
	return global_position + Vector3.UP * 0.6
