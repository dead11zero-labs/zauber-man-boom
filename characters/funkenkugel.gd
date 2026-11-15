extends Area3D
## Funkenkugel: langsames Projektil der Spaehdrohne. Fliegt geradeaus, ignoriert Gegner.
## Trifft sie den Spieler: schaden_nehmen(schaden, von). Trifft sie einen Raetselbaustein mit stoeren():
## schaltet ihn aus (nie dauerhaft, ein Blitz schaltet wieder ein). Sonst verpufft sie an Waenden.
## Aufruf: start(richtung_mal_tempo, schuetze, schaden). Keine Signale, keine Exporte.

const BLITZ := preload("res://blitz.gd")
const RADIUS := 0.35
const LEBENSDAUER := 5.0
const FARBE := Color(1.0, 0.7, 0.15)
const LICHT_ENERGIE := 2.5
const LICHT_REICHWEITE := 5.0
const FLACKERN := 0.3
const FUNKEN_STAERKE := 0.1

var vel := Vector3.ZERO
var schuetze: Node = null
var schaden := 1
var _t := 0.0
var _weg := false
var _kern: MeshInstance3D
var _licht: OmniLight3D


func start(v: Vector3, von: Node, p_schaden: int) -> void:
	vel = v
	schuetze = von
	schaden = p_schaden
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = RADIUS
	cs.shape = s
	add_child(cs)
	_kern = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = RADIUS
	sm.height = RADIUS * 2.0
	_kern.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = FARBE.lightened(0.4)
	_kern.material_override = m
	add_child(_kern)
	_licht = OmniLight3D.new()
	_licht.light_color = FARBE
	_licht.omni_range = LICHT_REICHWEITE
	add_child(_licht)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _weg:
		return
	_t += delta
	global_position += vel * delta
	_licht.light_energy = LICHT_ENERGIE * randf_range(1.0 - FLACKERN, 1.0 + FLACKERN)
	_kern.scale = Vector3.ONE * randf_range(1.0 - FLACKERN, 1.0)
	if _t > LEBENSDAUER:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if _weg or body == schuetze or body.is_in_group("gegner"):
		return
	_weg = true
	if body.has_method("schaden_nehmen") and body.is_in_group("spieler"):
		body.schaden_nehmen(schaden, global_position)
	elif body.has_method("stoeren"):
		body.stoeren()
	BLITZ._treffer_effekt(get_parent(), global_position, FUNKEN_STAERKE)
	queue_free()
