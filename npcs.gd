extends Node3D
## Verteilt Synth-Bots in der Stadt.

const ANZAHL := 7

var npc_szene := preload("res://npc.tscn")


func _ready() -> void:
	for i in ANZAHL:
		var n = npc_szene.instantiate()
		n.name = "SynthBot%d" % (i + 1)
		add_child(n)
