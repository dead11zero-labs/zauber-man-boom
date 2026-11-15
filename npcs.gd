extends Node3D
## Verteilt Synth-Bots und Buerger (CityFolks-Modelle, siehe buerger.gd) in der Stadt.

const ANZAHL := 7
const ANZAHL_BUERGER := 10

var npc_szene := preload("res://npc.tscn")
var buerger_szene := preload("res://buerger.tscn")


func _ready() -> void:
	for i in ANZAHL:
		var n = npc_szene.instantiate()
		n.name = "SynthBot%d" % (i + 1)
		add_child(n)
	# Buerger nur, wenn die Modelle vorhanden sind (Lizenz: der Ordner liegt nicht im Repo)
	if not load("res://buerger.gd").verfuegbar():
		return
	for i in ANZAHL_BUERGER:
		var b = buerger_szene.instantiate()
		b.name = "Buerger%d" % (i + 1)
		add_child(b)
