extends Area3D
## Checkpoint-Station: Spieler betritt den Lichtring -> GameState.checkpoint_setzen (wird gespeichert).
## Ist zugleich Heilstation: fuellt beim Betreten die Herzen auf (heilt = false schaltet das ab).
## Nur ein Checkpoint leuchtet aktiv, die anderen werden ueber EventBus.checkpoint_erreicht wieder dunkel.
## Exportiert: id (Speicherschluessel, eindeutig), heilt, farbe.
## Setzt sich nach dem Laden der Welt per Strahl auf den Boden.

@export var id := ""
@export var heilt := true
@export var farbe := Color(0.2, 1.0, 0.75)

const RING_RADIUS := 1.6
const RING_DICKE := 0.12
const SAEULE_HOEHE := 2.6
const SAEULE_RADIUS := 0.12
const ZONE_HOEHE := 3.0
const BODEN_STRAHL_HOEHE := 30.0
const BODEN_STRAHL_TIEFE := 60.0
const ENERGIE_AUS := 0.6
const ENERGIE_AN := 4.0
const LICHT_AUS := 0.4
const LICHT_AN := 2.5
const PULS_TEMPO := 3.0
const DREH_TEMPO := 1.2
## Respawn-Punkt liegt etwas vor dem Ring (nicht im Ring), Abstand in Metern
const RESPAWN_VERSATZ := 2.5

var aktiv := false
var _mat: StandardMaterial3D
var _licht: OmniLight3D
var _rune: MeshInstance3D
var _zeit := 0.0


func _ready() -> void:
	add_to_group("checkpoint")
	var cs := CollisionShape3D.new()
	var zy := CylinderShape3D.new()
	zy.radius = RING_RADIUS
	zy.height = ZONE_HOEHE
	cs.shape = zy
	cs.position.y = ZONE_HOEHE * 0.5
	add_child(cs)
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = farbe.darkened(0.6)
	_mat.emission_enabled = true
	_mat.emission = farbe
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = RING_RADIUS - RING_DICKE
	tm.outer_radius = RING_RADIUS
	ring.mesh = tm
	ring.material_override = _mat
	ring.position.y = 0.06
	add_child(ring)
	var saeule := MeshInstance3D.new()
	var zm := CylinderMesh.new()
	zm.top_radius = SAEULE_RADIUS
	zm.bottom_radius = SAEULE_RADIUS * 1.6
	zm.height = SAEULE_HOEHE
	saeule.mesh = zm
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.08, 0.09, 0.12)
	sm.metallic = 0.8
	saeule.material_override = sm
	saeule.position = Vector3(RING_RADIUS + 0.4, SAEULE_HOEHE * 0.5, 0.0)
	add_child(saeule)
	_rune = MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(0.5, 0.6, 0.12)
	_rune.mesh = pm
	_rune.material_override = _mat
	_rune.position = Vector3(RING_RADIUS + 0.4, SAEULE_HOEHE + 0.5, 0.0)
	add_child(_rune)
	_licht = OmniLight3D.new()
	_licht.light_color = farbe
	_licht.omni_range = 6.0
	_licht.position.y = 1.5
	add_child(_licht)
	body_entered.connect(_betreten)
	EventBus.checkpoint_erreicht.connect(func(neu: String) -> void: _setzen(neu == id))
	_setzen(GameState.checkpoint_id == id and id != "")
	await get_tree().physics_frame
	await get_tree().physics_frame
	_auf_boden()


func _auf_boden() -> void:
	var von := global_position + Vector3.UP * BODEN_STRAHL_HOEHE
	var q := PhysicsRayQueryParameters3D.create(von, von + Vector3.DOWN * BODEN_STRAHL_TIEFE)
	var t := get_world_3d().direct_space_state.intersect_ray(q)
	if not t.is_empty():
		global_position.y = (t["position"] as Vector3).y


func _process(delta: float) -> void:
	_zeit += delta
	var puls := 0.5 + 0.5 * sin(_zeit * PULS_TEMPO)
	_mat.emission_energy_multiplier = (ENERGIE_AN * (0.75 + 0.25 * puls)) if aktiv else ENERGIE_AUS
	_licht.light_energy = (LICHT_AN + puls) if aktiv else LICHT_AUS
	_rune.rotate_y(DREH_TEMPO * delta * (3.0 if aktiv else 1.0))


func _betreten(b: Node) -> void:
	if not b.is_in_group("spieler") or id == "":
		return
	GameState.checkpoint_setzen(id, respawn_punkt())
	if heilt:
		GameState.heilen(GameState.MAX_HERZEN)
	_setzen(true)


## Wo der Spieler nach einer Niederlage auftaucht
func respawn_punkt() -> Vector3:
	return global_position + global_basis.z * RESPAWN_VERSATZ


func _setzen(an: bool) -> void:
	aktiv = an
	_mat.albedo_color = farbe if an else farbe.darkened(0.6)
