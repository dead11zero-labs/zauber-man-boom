extends Node3D
## Wald auf dem Terrain3D-Gelaende: Fichten und Laubbaeume als zwei MultiMeshes.
## Standort und Dichte kommen aus TerrainForm (gleiche Formel wie beim Backen des Terrains).

const STADTRAND := preload("res://levels/stadtrand.gd")
const RASTER := 8.0
const AUSSEN := 900.0
const MAX_NEIGUNG := 0.55
## Kollision der Staemme: ein gemeinsamer Zylinder fuer alle Baeume (Kronen bleiben durchlaessig)
## Der Wald wird in Kacheln geteilt, damit Baeume ausserhalb des Blickfelds und in der Ferne
## weder gezeichnet werden noch Schatten werfen.
const KACHEL := 96.0
const SICHTWEITE := 650.0
const SICHT_RAND := 30.0
const SCHATTEN_BIS := 220.0   ## nur Kacheln, deren Mitte der Stadt so nah ist, werfen Schatten
const RINDE_KACHEL := 1.5
const LAUB_KACHEL := 2.0
const RINDE_HELL := 2.0
const LAUB_HELL := 2.6
const STAMM_RADIUS := 0.5
const STAMM_HOEHE := 7.0

var rng := RandomNumberGenerator.new()
var terrain: Node = null
var _stamm_koerper: RID
var _stamm_form: CylinderShape3D


func _ready() -> void:
	rng.seed = 7
	terrain = get_node_or_null("../Terrain")
	var fichte := _fichte()
	var laub := _laubbaum()
	# Flaeche 0 ist der Stamm (Rinde), alle weiteren sind Nadeln/Laub. Die Vertexfarbe toent die Textur.
	var rinde := _baum_mat("park_rinde", RINDE_KACHEL, RINDE_HELL)
	var blatt := _baum_mat("park_rasen", LAUB_KACHEL, LAUB_HELL)
	for m: ArrayMesh in [fichte, laub]:
		for f in m.get_surface_count():
			m.surface_set_material(f, rinde if f == 0 else blatt)
	var t_f: Array = []
	var c_f: Array = []
	var t_l: Array = []
	var c_l: Array = []
	var x := -AUSSEN
	while x <= AUSSEN:
		var z := -AUSSEN
		while z <= AUSSEN:
			var px := x + rng.randf_range(-RASTER * 0.45, RASTER * 0.45)
			var pz := z + rng.randf_range(-RASTER * 0.45, RASTER * 0.45)
			z += RASTER
			var h := _hoehe(px, pz)
			var dichte := TerrainForm.waldwert(px, pz, h)
			if dichte <= 0.0 or rng.randf() > dichte * 1.15:
				continue
			if TerrainForm.neigung(px, pz) > MAX_NEIGUNG:
				continue
			var s := rng.randf_range(0.8, 1.6)
			var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.9, 1.3), s))
			var t := Transform3D(b, Vector3(px, h - 0.3, pz))
			var tint := Color.from_hsv(rng.randf_range(0.0, 1.0), 0.0, rng.randf_range(0.75, 1.1))
			if h > 35.0 or rng.randf() < 0.55:
				t_f.append(t)
				c_f.append(tint)
			else:
				t_l.append(t)
				c_l.append(Color(rng.randf_range(0.85, 1.15), rng.randf_range(0.9, 1.15), rng.randf_range(0.7, 1.0)))
		x += RASTER
	_multimesh(fichte, null, t_f, c_f)
	_multimesh(laub, null, t_l, c_l)
	_staemme_kollision(t_f + t_l)


## Ein statischer Koerper mit einem Zylinder je Stamm, direkt ueber den PhysicsServer
## (spart tausende Nodes). Die Formen kommen vor dem Einhaengen in die Welt dazu.
func _staemme_kollision(baeume: Array) -> void:
	_stamm_form = CylinderShape3D.new()
	_stamm_form.radius = STAMM_RADIUS
	_stamm_form.height = STAMM_HOEHE
	_stamm_koerper = PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_mode(_stamm_koerper, PhysicsServer3D.BODY_MODE_STATIC)
	for t: Transform3D in baeume:
		PhysicsServer3D.body_add_shape(_stamm_koerper, _stamm_form.get_rid(), Transform3D(Basis.IDENTITY, t.origin + Vector3.UP * STAMM_HOEHE * 0.5))
	PhysicsServer3D.body_set_space(_stamm_koerper, get_world_3d().space)


func _exit_tree() -> void:
	if _stamm_koerper.is_valid():
		PhysicsServer3D.free_rid(_stamm_koerper)


## Baum-Material: Poly-Haven-Textur per Triplanar (im Objektraum, wandert also nicht),
## multipliziert mit der Vertexfarbe. `hell` gleicht die Abdunklung durch die Multiplikation aus.
func _baum_mat(ordner: String, kachel: float, hell: float) -> StandardMaterial3D:
	var pfad := "res://assets/texturen/%s/" % ordner
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.albedo_texture = load(pfad + "diff.jpg")
	mat.albedo_color = Color(hell, hell, hell)
	mat.normal_enabled = true
	mat.normal_texture = load(pfad + "nor.jpg")
	mat.roughness = 1.0
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3.ONE / kachel
	return mat


func _hoehe(x: float, z: float) -> float:
	# Im Stadtrand-Guertel (TerraBrush) gilt dessen Hoehe, Terrain3D ist dort ausgestanzt
	if STADTRAND.im_guertel(x, z):
		return STADTRAND.hoehe(x, z)
	if terrain != null:
		var d = terrain.get_data()
		if d != null:
			var h: float = d.get_height(Vector3(x, 0.0, z))
			if not is_nan(h):
				return h
	return TerrainForm.hoehe(x, z)


func _multimesh(mesh: Mesh, mat: Material, transforms: Array, farben: Array) -> void:
	# nach Kacheln sortieren
	var kacheln := {}
	for i in transforms.size():
		var o: Vector3 = transforms[i].origin
		var k := Vector2i(floori(o.x / KACHEL), floori(o.z / KACHEL))
		if not kacheln.has(k):
			kacheln[k] = []
		kacheln[k].append(i)
	for k: Vector2i in kacheln:
		var liste: Array = kacheln[k]
		# Die Kachel-Instanz sitzt in der Kachelmitte, damit die Sichtweite von dort gemessen wird
		var mitte := Vector3((k.x + 0.5) * KACHEL, 0.0, (k.y + 0.5) * KACHEL)
		mitte.y = transforms[liste[0]].origin.y
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = mesh
		mm.instance_count = liste.size()
		for j in liste.size():
			var t: Transform3D = transforms[liste[j]]
			t.origin -= mitte
			mm.set_instance_transform(j, t)
			mm.set_instance_color(j, farben[liste[j]])
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		if mat != null:
			mi.material_override = mat
		mi.position = mitte
		mi.visibility_range_end = SICHTWEITE
		mi.visibility_range_end_margin = SICHT_RAND
		if Vector2(mitte.x, mitte.z).length() > TerrainForm.RAND + SCHATTEN_BIS:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)


## Fuegt ein Primitiv mit Vertexfarbe als eigene Flaeche in den Mesh ein.
func _teil(ziel: ArrayMesh, quelle: PrimitiveMesh, pos: Vector3, farbe: Color) -> void:
	var arr := quelle.get_mesh_arrays()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var cols := PackedColorArray()
	cols.resize(v.size())
	for i in v.size():
		v[i] += pos
		cols[i] = farbe
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_COLOR] = cols
	ziel.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)


func _kegel(radius: float, hoehe: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = radius
	c.height = hoehe
	c.radial_segments = 8
	c.rings = 1
	c.cap_top = false
	c.cap_bottom = false
	return c


func _stamm(radius: float, hoehe: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = radius * 0.7
	c.bottom_radius = radius
	c.height = hoehe
	c.radial_segments = 6
	c.rings = 1
	c.cap_top = false
	c.cap_bottom = false
	return c


func _fichte() -> ArrayMesh:
	var m := ArrayMesh.new()
	var rinde := Color(0.28, 0.19, 0.12)
	_teil(m, _stamm(0.38, 3.2), Vector3(0, 1.6, 0), rinde)
	_teil(m, _kegel(3.3, 4.6), Vector3(0, 4.2, 0), Color(0.16, 0.30, 0.07))
	_teil(m, _kegel(2.6, 4.2), Vector3(0, 6.5, 0), Color(0.19, 0.34, 0.08))
	_teil(m, _kegel(1.8, 3.8), Vector3(0, 8.5, 0), Color(0.22, 0.38, 0.09))
	return m


func _laubbaum() -> ArrayMesh:
	var m := ArrayMesh.new()
	_teil(m, _stamm(0.45, 4.6), Vector3(0, 2.3, 0), Color(0.33, 0.24, 0.16))
	var krone := SphereMesh.new()
	krone.radius = 3.4
	krone.height = 5.6
	krone.radial_segments = 8
	krone.rings = 5
	_teil(m, krone, Vector3(0, 6.6, 0), Color(0.20, 0.42, 0.14))
	var krone2 := SphereMesh.new()
	krone2.radius = 2.3
	krone2.height = 3.8
	krone2.radial_segments = 8
	krone2.rings = 4
	_teil(m, krone2, Vector3(1.6, 8.3, -0.8), Color(0.27, 0.50, 0.17))
	return m
