extends Node3D
## Setzt die drei Rollen-NPCs (Haendler, Informant, Mechanikerin) nahe den Startpunkt (0, 115).
## Clarissa (Kybernetik-Expertin, Mutter von Aen) ist die Mechanikerin und nutzt das importierte Modell.
## Eintrag: [rolle, anzeige_name, Position, Drehung y in Grad, Farbe, dialog_erst, dialog_spaeter].
## Keine Signale, keine Exporte. NPC-Skript: characters/rollen_npc.gd. Orte sind Platzhalter bis Meilenstein 6.

const MODELLE := {
	"mechanikerin": "res://imported_models/Cybernetic_Rebel_Character_Sheet/Cybernetic_Rebel_Character_Sheet.glb",
}

const NPC := preload("res://characters/rollen_npc.gd")

const LISTE := [
	["haendler", "Händler", Vector3(12, 0, 122), 200.0, Color(1.0, 0.85, 0.2), "haendler", ""],
	["informant", "Informant", Vector3(-18, 0, 111), 160.0, Color(0.1, 0.95, 1.0), "informant_erst", "informant_spaeter"],
	["mechanikerin", "Clarissa", Vector3(22, 0, 108), 230.0, Color(1.0, 0.15, 0.8), "mechanikerin_erst", "mechanikerin_spaeter"],
]


func _ready() -> void:
	for e in LISTE:
		var n: Node3D = NPC.new()
		n.rolle = e[0]
		n.anzeige_name = e[1]
		n.farbe = e[4]
		n.modell = MODELLE.get(e[0], "")
		n.dialog_erst = e[5]
		n.dialog_spaeter = e[6]
		add_child(n)
		n.position = e[2]
		n.rotation.y = deg_to_rad(e[3])
