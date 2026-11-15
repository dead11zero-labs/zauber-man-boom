extends Node3D
## Drohnen-Spawner (Bake): haelt in der Naehe des Spielers bis zu `max_aktiv` Drohnen am Leben.
## Die Drohnen patrouillieren um die Bake (z. B. ueber einem Raetselfeld) und stoeren dort
## (Spaehdrohnen schiessen Stromquellen aus; nichts wird dauerhaft zerstoert).
## Exportiert: arten (Liste 0 = Spaehdrohne, 1 = Rammdrohne, wird reihum benutzt), max_aktiv, intervall,
##   aktiv_radius (nur spawnen, wenn der Spieler so nah ist), streuung, patrouille_radius, farbe.
## Signal: drohne_erschienen(drohne).

signal drohne_erschienen(drohne: Node)

const ARTEN: Array[Script] = [
	preload("res://characters/spaehdrohne.gd"),
	preload("res://characters/rammdrohne.gd"),
]

@export var arten: Array[int] = [0]
@export var max_aktiv := 2
@export var intervall := 10.0
@export var aktiv_radius := 80.0
@export var streuung := 6.0
@export var patrouille_radius := 16.0
@export var farbe := Color(1.0, 0.25, 0.6)

const ERSTER_SPAWN := 2.0
const SPAWN_HOEHE := 3.0
const BAKE_HOEHE := 0.6
const BAKE_RADIUS := 0.9
const ENERGIE := 2.5
const PULS_TEMPO := 5.0

var _timer := ERSTER_SPAWN
var _naechste := 0
var _aktiv: Array[Node] = []
var _spieler: Node3D
var _mat: StandardMaterial3D
var _zeit := 0.0


func _ready() -> void:
	add_to_group("drohnen_spawner")
	# Platzhalter-Bake: flacher Sockel mit pulsierender Neonplatte
	var m := MeshInstance3D.new()
	var zm := CylinderMesh.new()
	zm.top_radius = BAKE_RADIUS * 0.8
	zm.bottom_radius = BAKE_RADIUS
	zm.height = BAKE_HOEHE
	m.mesh = zm
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.08, 0.05, 0.08)
	_mat.emission_enabled = true
	_mat.emission = farbe
	m.material_override = _mat
	m.position.y = BAKE_HOEHE * 0.5
	add_child(m)
	var l := OmniLight3D.new()
	l.light_color = farbe
	l.omni_range = 6.0
	l.light_energy = 1.5
	l.position.y = 1.2
	add_child(l)


func _process(delta: float) -> void:
	_zeit += delta
	_mat.emission_energy_multiplier = ENERGIE * (0.6 + 0.4 * sin(_zeit * PULS_TEMPO))
	if _spieler == null:
		_spieler = get_tree().get_first_node_in_group("spieler")
		return
	if global_position.distance_to(_spieler.global_position) > aktiv_radius:
		return
	_timer -= delta
	if _timer > 0.0 or _aktiv.size() >= max_aktiv or arten.is_empty():
		return
	_timer = intervall
	spawnen()


## Erzeugt sofort eine Drohne (die naechste Art aus `arten`). Gibt sie zurueck.
func spawnen() -> Node:
	var art := clampi(arten[_naechste % arten.size()], 0, ARTEN.size() - 1)
	_naechste += 1
	var d: CharacterBody3D = ARTEN[art].new()
	d.heim_radius = patrouille_radius
	var w := randf() * TAU
	d.position = Vector3(cos(w) * streuung, SPAWN_HOEHE, sin(w) * streuung)
	add_child(d)
	_aktiv.append(d)
	d.besiegt.connect(_weg)
	d.tree_exited.connect(_weg.bind(d))
	drohne_erschienen.emit(d)
	return d


func _weg(d: Node) -> void:
	_aktiv.erase(d)
