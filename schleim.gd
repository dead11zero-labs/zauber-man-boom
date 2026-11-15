extends Area3D
## Glibberiger gruener Schleimball des Gurken-Monsters. Fliegt im Bogen und klatscht auf.

const GRAVITATION := 20.0
## Herzen Schaden beim Spieler (Meilenstein 4)
const SCHADEN := 1

static var _mat: StandardMaterial3D

var vel := Vector3.ZERO
var schuetze: Node = null
var _weg := false
var _t := 0.0
var _mesh: MeshInstance3D


static func material() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.albedo_color = Color(0.35, 0.95, 0.1, 0.82)
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat.roughness = 0.05
		_mat.metallic_specular = 1.0
		_mat.emission_enabled = true
		_mat.emission = Color(0.25, 0.8, 0.05)
		_mat.emission_energy_multiplier = 0.8
		_mat.rim_enabled = true
		_mat.rim = 0.8
		_mat.rim_tint = 0.2
	return _mat


func start(v: Vector3, von: Node) -> void:
	vel = v
	schuetze = von
	_mesh = MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.8
	sp.height = 1.6
	_mesh.mesh = sp
	_mesh.material_override = material()
	add_child(_mesh)
	var cs := CollisionShape3D.new()
	var k := SphereShape3D.new()
	k.radius = 0.9
	cs.shape = k
	add_child(cs)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _weg:
		return
	_t += delta
	vel.y -= GRAVITATION * delta
	global_position += vel * delta
	# Glibber-Wabbeln
	var w := sin(_t * 22.0) * 0.18
	_mesh.scale = Vector3(1.0 + w, 1.0 - w, 1.0 + w)
	if _t > 6.0 or global_position.y < -5.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if _weg or body == schuetze:
		return
	_weg = true
	if body.has_method("schaden_nehmen") and body.is_in_group("spieler"):
		body.schaden_nehmen(SCHADEN, global_position)
	if body.has_method("schleim_treffer"):
		body.schleim_treffer()
	_klatschen()
	queue_free()


func _klatschen() -> void:
	var p := global_position
	if p.y > 4.0:
		return
	var fleck := MeshInstance3D.new()
	var z := CylinderMesh.new()
	z.top_radius = randf_range(1.3, 2.0)
	z.bottom_radius = z.top_radius
	z.height = 0.05
	z.radial_segments = 14
	fleck.mesh = z
	var m: StandardMaterial3D = material().duplicate()
	fleck.material_override = m
	get_parent().add_child(fleck)
	fleck.global_position = Vector3(p.x, maxf(p.y, 0.0) + 0.04, p.z)
	fleck.scale = Vector3(0.3, 1.0, 0.3)
	var tw := fleck.create_tween()
	tw.tween_property(fleck, "scale", Vector3.ONE, 0.15)
	tw.tween_interval(3.0)
	tw.tween_property(m, "albedo_color:a", 0.0, 1.5)
	tw.tween_callback(fleck.queue_free)
