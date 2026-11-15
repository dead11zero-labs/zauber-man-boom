extends Collectible
## Mana-Kern (frueher Kristall): kleiner schwebender Kristall. Beim Beruehren durch den Spieler wird er eingesammelt.
## Feste Kerne haben eine id (Persistenz), Beute vom Gurken-Monster nicht.

const DATEN := preload("res://data/sammelobjekte/mana_kern.tres")
const FARBEN := [Color(0.1, 0.9, 1.0), Color(1.0, 0.2, 0.85), Color(1.0, 0.85, 0.2)]

static var _mesh: ArrayMesh
static var _mats: Array = []

var _t := 0.0
var _basis_y := 0.0
var _weg := false
var modell: MeshInstance3D


static func _vorbereiten() -> void:
	if _mesh != null:
		return
	# Doppelpyramide (Kristallform)
	var o := 0.45
	var h := 0.9
	var ring := [Vector3(o, 0, 0), Vector3(0, 0, o), Vector3(-o, 0, 0), Vector3(0, 0, -o)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 4:
		var a: Vector3 = ring[i]
		var b: Vector3 = ring[(i + 1) % 4]
		for spitze in [Vector3(0, h, 0), Vector3(0, -h, 0)]:
			var up: bool = (spitze as Vector3).y > 0.0
			var p: Array = [a, b, spitze] if up else [b, a, spitze]
			var n: Vector3 = ((p[1] - p[0]) as Vector3).cross(p[2] - p[0]).normalized()
			st.set_smooth_group(-1)
			for v in p:
				st.set_normal(n)
				st.add_vertex(v)
	_mesh = st.commit()
	for f in FARBEN:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(f.r, f.g, f.b, 0.85)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.emission_enabled = true
		m.emission = f
		m.emission_energy_multiplier = 2.5
		m.roughness = 0.1
		m.metallic = 0.3
		_mats.append(m)


func start(pos: Vector3, farbe_index: int, p_id: String = "") -> void:
	daten = DATEN
	id = p_id
	position = pos
	_basis_y = pos.y
	_t = randf() * TAU
	_vorbereiten()
	var mi := MeshInstance3D.new()
	mi.name = "Modell"
	mi.mesh = _mesh
	mi.material_override = _mats[farbe_index % _mats.size()]
	mi.scale = Vector3.ONE * 0.9
	add_child(mi)
	modell = mi
	var shape := CollisionShape3D.new()
	var kugel := SphereShape3D.new()
	kugel.radius = 1.6
	shape.shape = kugel
	add_child(shape)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_t += delta
	if _weg:
		return
	modell.rotation.y = _t * 1.8
	position.y = _basis_y + sin(_t * 2.0) * 0.25


func _on_body_entered(body: Node) -> void:
	if _weg or not einsammeln(body):
		return
	_weg = true
	var tw := create_tween().set_parallel(true)
	tw.tween_property(modell, "scale", Vector3.ONE * 2.2, 0.25)
	tw.tween_property(self, "position:y", position.y + 1.5, 0.25)
	tw.tween_property(modell.material_override, "albedo_color:a", 0.0, 0.25)
	tw.chain().tween_callback(queue_free)
