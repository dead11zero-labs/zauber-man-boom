extends Node3D
## Setzt die Checkpoint-Stationen (zugleich Heilstationen) in die Welt. Platzhalter-Orte bis Meilenstein 6.
## Eintrag: [id, Position (x, z zaehlen, y wird auf den Boden gesetzt), Drehung um y in Grad].
## Keine Signale, keine Exporte. Station: levels/checkpoint.gd.

const STATION := preload("res://levels/checkpoint.gd")

const LISTE := [
	["cp_start", Vector3(-8, 0, 118), 0.0],
	["cp_gurkenwald", Vector3(-172, 0, -200), 90.0],
	["cp_popcorn", Vector3(232, 0, 62), 0.0],
	["cp_tower", Vector3(-30, 0, -150), 0.0],
]


func _ready() -> void:
	for e in LISTE:
		var c: Area3D = STATION.new()
		c.id = e[0]
		add_child(c)
		c.position = e[1]
		c.rotation.y = deg_to_rad(e[2])
