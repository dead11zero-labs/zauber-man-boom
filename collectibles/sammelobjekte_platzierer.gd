extends Node3D
## Setzt die festen Sammelobjekte (Runen, Chips, Seiten) in die Welt. Die Liste ist Platzhalter bis Meilenstein 6.
## Eintrag: [id, Datenpfad, Position]. Eingesammelte ids werden uebersprungen.

const LISTE := [
	["rune_b1_01", "res://data/sammelobjekte/rune.tres", Vector3(0, 1.8, 45)],
	["rune_b1_02", "res://data/sammelobjekte/rune.tres", Vector3(40, 1.8, 70)],
	["rune_b1_03", "res://data/sammelobjekte/rune.tres", Vector3(-40, 1.8, 70)],
	["chip_01", "res://data/sammelobjekte/chip_01.tres", Vector3(0, 1.6, 98)],
	["chip_02", "res://data/sammelobjekte/chip_02.tres", Vector3(-30, 1.6, 100)],
	["seite_01", "res://data/sammelobjekte/seite_01.tres", Vector3(0, 2.4, 108)],
]

var _szene := preload("res://collectibles/sammelobjekt.gd")


func _ready() -> void:
	for e in LISTE:
		var d: CollectibleData = load(e[1])
		var o := Area3D.new()
		o.set_script(_szene)
		add_child(o)
		if not o.einrichten(e[0], d, e[2]):
			o.queue_free()
