class_name Bezirke
extends Node
## Bezirke von Synth-City: meldet dem GameState, in welchem Bezirk der Spieler gerade steht.
## Zuordnung per Flaeche (x = Ost, z = Sued, Norden ist -z). Reihenfolge = Prioritaet.
## Signale: keine eigenen, Wechsel laufen ueber GameState.bezirk_setzen -> EventBus.bezirk_gewechselt.

const KERN_TURM_MITTE := Vector2(0, -240)
const KERN_TURM_RADIUS := 62.0
## Nr. 2 Neon-Basar = Neo-Distrikt hinter dem Gurken-Wald (alles westlich der Stadtgrenze)
const NEON_BASAR_AB_X := -330.0
## Nr. 3 Hafen = Ostseite hinter den Fluessen
const HAFEN_AB_X := 200.0
## Nr. 4 Daecher = nordliche Hochhaus-Zone, Nr. 5 Untergrund = Schatten-Gassen im Sueden
const DAECHER_BIS_Z := -165.0
const UNTERGRUND_AB_Z := 198.0
const PRUEF_INTERVALL := 0.25

var _spieler: Node3D
var _timer := 0.0


func _ready() -> void:
	_spieler = get_tree().get_first_node_in_group("spieler")


static func bezirk_an(x: float, z: float) -> int:
	if Vector2(x, z).distance_to(KERN_TURM_MITTE) < KERN_TURM_RADIUS:
		return 6
	if x < NEON_BASAR_AB_X:
		return 2
	if x > HAFEN_AB_X:
		return 3
	if z > UNTERGRUND_AB_Z:
		return 5
	if z < DAECHER_BIS_Z:
		return 4
	return 1


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = PRUEF_INTERVALL
	if _spieler == null:
		_spieler = get_tree().get_first_node_in_group("spieler")
		return
	var p := _spieler.global_position
	GameState.bezirk_setzen(bezirk_an(p.x, p.z))
