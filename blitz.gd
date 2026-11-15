extends Area3D
## Zauberblitz-Projektil (Area3D). Wird vom Spieler abgefeuert.
## Eigenschaften: schuetze (wird nicht getroffen), ladung (0..1, Ladeschuss), schaden.
## Treffer: Ziele mit `blitz_treffer(ladung, blitz)` (z. B. PowerSource) oder altem `treffer()` (Gegner).
## Beim Aufprall entsteht ein Funken-Effekt mit kurzem Lichtblitz.

const SPEED := 45.0
const LEBENSDAUER := 0.9  # normaler Blitz: ca. 40 m Reichweite
const LEBENSDAUER_LADUNG := 2.4  # Ladeschuss fliegt weit (Fernschalter)
const SPEED_LADUNG_BONUS := 0.5
const GROESSE_LADUNG_BONUS := 1.2
const SCHADEN_NORMAL := 1.0
const SCHADEN_LADUNG := 3.0
const EFFEKT_FUNKEN := 28
const EFFEKT_DAUER := 0.45

var schuetze: Node = null
var ladung := 0.0
var schaden := SCHADEN_NORMAL
var _zeit := 0.0
var _speed := SPEED
var _leben := LEBENSDAUER


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_speed = SPEED * (1.0 + SPEED_LADUNG_BONUS * ladung)
	# Upgrades (Meilenstein 5): Bonus ist 0.0 ohne Kauf, die Defaults bleiben dann unveraendert
	_leben = lerpf(LEBENSDAUER, LEBENSDAUER_LADUNG, ladung) * (1.0 + GameState.upgrade_bonus("blitzreichweite"))
	schaden = lerpf(SCHADEN_NORMAL, SCHADEN_LADUNG, ladung) * (1.0 + GameState.upgrade_bonus("blitzschaden"))
	scale = Vector3.ONE * (1.0 + GROESSE_LADUNG_BONUS * ladung)


func _physics_process(delta: float) -> void:
	global_position += -global_basis.z * _speed * delta
	_zeit += delta
	$Licht.light_energy = randf_range(3.0, 7.0)
	$Kern.scale = Vector3.ONE * randf_range(0.8, 1.2)
	if _zeit > _leben:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body == schuetze:
		return
	if body.has_method("blitz_treffer"):
		body.blitz_treffer(ladung, self)
	elif body.has_method("treffer"):
		body.treffer()
	_treffer_effekt(get_parent(), global_position, ladung)
	queue_free()


## Funkenstoss plus kurzer Lichtblitz an `pos`. Static, damit auch Schalter ihn nutzen koennen.
static func _treffer_effekt(welt: Node, pos: Vector3, staerke: float) -> void:
	if welt == null:
		return
	var funken := CPUParticles3D.new()
	funken.emitting = true
	funken.one_shot = true
	funken.explosiveness = 1.0
	funken.amount = EFFEKT_FUNKEN + int(40 * staerke)
	funken.lifetime = EFFEKT_DAUER
	funken.direction = Vector3.UP
	funken.spread = 180.0
	funken.gravity = Vector3(0, -6, 0)
	funken.initial_velocity_min = 3.0
	funken.initial_velocity_max = 8.0 + 4.0 * staerke
	var m := SphereMesh.new()
	m.radius = 0.05
	m.height = 0.1
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.6, 0.95, 1.0)
	m.material = mat
	funken.mesh = m
	var licht := OmniLight3D.new()
	licht.light_color = Color(0.4, 0.85, 1.0)
	licht.light_energy = 6.0 + 6.0 * staerke
	licht.omni_range = 9.0
	funken.add_child(licht)
	welt.add_child(funken)
	funken.global_position = pos
	var tw := funken.create_tween()
	tw.tween_property(licht, "light_energy", 0.0, EFFEKT_DAUER)
	tw.tween_callback(funken.queue_free)
