extends Node3D
## Central Park von Synth-City (80er-Retro-Cartoon): Zuckerwatte-Baeume, geschwungene Wege mit Neon,
## Glaskuppel-Pavillons, Chrom-Baenke, Kugellampen, Teich, Roboter-Voegel und mechanische Eichhoernchen.

const Geo = preload("res://geo.gd")
const AEN := preload("res://characters/aen.gd")
const AEN_BANK := 2            ## Index in der Liste der gebauten Baenke, auf der Aen sitzt
const BANK_SITZ_HOEHE := 0.57  ## Oberkante der Sitzlatten (siehe _bank_vorlage)

const GRENZE := Rect2(-164.0, -58.0, 108.0, 96.0)
const TEICH_M := Vector2(-85.0, 14.0)
const TEICH_R := Vector2(21.0, 13.0)
## Teich als echte Mulde zum Schwimmen und Tauchen: Ufer laufen weich bis TEICH_TIEFE ab, Wasserspiegel TEICH_WASSER_Y.
## Stadtplatte, Sohle und Gelaende haben darunter ein Rechteckloch (teich_loch(), abgefragt von stadt.gd).
const TEICH_TIEFE := 4.0
const TEICH_WASSER_Y := -0.35
const TEICH_UFER := 1.0            ## Mulde reicht so weit ueber TEICH_R hinaus
const TEICH_LOCH_RAND := 1.0
const TEICH_STEIL_AB := 0.3        ## innerhalb dieses Radius-Anteils ist der Grund flach
const TEICH_RINGE := 12
const TEICH_SEGMENTE := 48
const RASEN_Y := 0.08
const RASEN_RECHTECK := Rect2(-170, -65, 120, 110)
const PAV_POS: Array[Vector2] = [Vector2(-110, -8), Vector2(-138, 22), Vector2(-72, -38)]
const PAV_R: Array[float] = [7.0, 5.5, 5.5]
const KRONEN := [Color(1.0, 0.28, 0.72), Color(0.95, 0.35, 0.95), Color(0.62, 0.32, 1.0), Color(1.0, 0.5, 0.8), Color(0.78, 0.28, 0.9)]
const BLUMEN := [Color(1.0, 0.3, 0.6), Color(0.2, 0.9, 1.0), Color(1.0, 0.8, 0.2), Color(0.6, 0.4, 1.0), Color(1.0, 0.5, 0.2)]

var rng := RandomNumberGenerator.new()
var wege: Array = []          # je Weg: Array[Vector3] (Mittellinie)
var weg_pkte: Array[Vector2] = []
var baeume: Array = []        # {pos, s}
var voegel: Array = []
var hoernchen: Array = []
var _t := 0.0

var m_weg: StandardMaterial3D
var m_neon_c: StandardMaterial3D
var m_neon_m: StandardMaterial3D
var m_chrom: StandardMaterial3D
var m_weiss: StandardMaterial3D
var m_glas: StandardMaterial3D
var m_lampe: StandardMaterial3D
var m_holz: StandardMaterial3D
var m_stein: StandardMaterial3D
var m_gruen: StandardMaterial3D
var m_rasen: StandardMaterial3D
var m_hecke: StandardMaterial3D
var m_zucker: ShaderMaterial
var m_blume: ShaderMaterial


func _ready() -> void:
	rng.seed = 2024
	_materialien()
	_rasen()
	_wege_bauen()
	_teich()
	for i in PAV_POS.size():
		_pavillon(PAV_POS[i], PAV_R[i])
	_baeume_bauen()
	_straeucher()
	_blumen_bauen()
	_baenke()
	_laternen()
	_fauna()


# ---------------------------------------------------------------- Material / Helfer

func _std(farbe: Color, emission := 0.0, metall := 0.0, rauh := 0.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = farbe
	m.metallic = metall
	m.roughness = rauh
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = farbe
		m.emission_energy_multiplier = emission
	return m


## Foto-PBR-Material (Poly Haven, CC0), world-space triplanar: keine Streckung auf skalierten Meshes.
func _pbr(ordner: String, kachel: float, tint := Color.WHITE) -> StandardMaterial3D:
	var pfad := "res://assets/texturen/%s/" % ordner
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(pfad + "diff.jpg")
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = load(pfad + "nor.jpg")
	m.roughness_texture = load(pfad + "rough.jpg")
	m.roughness = 1.0
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(kachel, kachel, kachel)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


func _materialien() -> void:
	m_weg = _pbr("park_weg", 0.28, Color(1.05, 1.05, 1.1))
	m_weg.cull_mode = BaseMaterial3D.CULL_DISABLED
	m_rasen = _pbr("park_rasen", 0.3, Color(0.85, 1.25, 0.75))
	m_hecke = _pbr("park_rasen", 0.6, Color(1.0, 1.0, 1.0))
	m_hecke.vertex_color_use_as_albedo = true
	m_neon_c = _std(Color(0.2, 0.95, 1.0), 3.0)
	m_neon_c.cull_mode = BaseMaterial3D.CULL_DISABLED
	m_neon_m = _std(Color(1.0, 0.25, 0.85), 3.0)
	m_neon_m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m_chrom = _std(Color(0.88, 0.9, 0.97), 0.0, 1.0, 0.12)
	m_weiss = _std(Color(0.96, 0.96, 0.98), 0.0, 0.0, 0.4)
	m_glas = _std(Color(0.6, 0.95, 1.0, 0.2), 0.3, 0.2, 0.05)
	m_glas.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m_glas.cull_mode = BaseMaterial3D.CULL_DISABLED
	m_glas.emission = Color(0.2, 0.7, 0.8)
	m_lampe = _std(Color(1.0, 0.95, 0.8), 3.0)
	m_holz = _pbr("park_rinde", 0.3)
	m_stein = _pbr("park_stein", 0.25)
	m_gruen = _std(Color(1, 1, 1), 0.0, 0.0, 0.8)
	m_gruen.vertex_color_use_as_albedo = true
	m_zucker = ShaderMaterial.new()
	m_zucker.shader = load("res://zuckerwatte.gdshader")
	m_blume = ShaderMaterial.new()
	m_blume.shader = load("res://exoblume.gdshader")


func _multimesh(mesh: Mesh, mat: Material, transforms: Array, farben: Array) -> void:
	if transforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		mm.set_instance_color(i, farben[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	add_child(mi)


func _mesh(m: Mesh, mat: Material, pos: Vector3, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	(parent if parent != null else self).add_child(mi)
	return mi


func _kugel(r: float, rad := 16, ringe := 8) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = rad
	s.rings = ringe
	return s


func _zyl_mesh(r_oben: float, r_unten: float, h: float, seg := 12) -> CylinderMesh:
	var z := CylinderMesh.new()
	z.top_radius = r_oben
	z.bottom_radius = r_unten
	z.height = h
	z.radial_segments = seg
	return z


func _stat_zyl(pos: Vector3, r: float, h: float) -> void:
	var sb := StaticBody3D.new()
	sb.position = pos
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = r
	sh.height = h
	cs.shape = sh
	sb.add_child(cs)
	add_child(sb)


func _frei(p: Vector2, r: float, mit_wegen := true) -> bool:
	if not GRENZE.grow(-2.0).has_point(p):
		return false
	var e := pow((p.x - TEICH_M.x) / (TEICH_R.x + 5.0 + r), 2.0) + pow((p.y - TEICH_M.y) / (TEICH_R.y + 5.0 + r), 2.0)
	if e < 1.0:
		return false
	for i in PAV_POS.size():
		if p.distance_to(PAV_POS[i]) < PAV_R[i] + 2.0 + r:
			return false
	if mit_wegen:
		for w in weg_pkte:
			if p.distance_to(w) < 3.6 + r:
				return false
	return true


func _kreis(mitte: Vector3, r: float, n := 28) -> Array[Vector3]:
	var pts: Array[Vector3] = []
	for i in n:
		var a := TAU * i / n
		pts.append(mitte + Vector3(cos(a) * r, 0, sin(a) * r))
	return Geo.kurve(pts, false, 4)


# ---------------------------------------------------------------- Rasen, Wege

func _rasen() -> void:
	# Rasen in vier Streifen um das Teichloch (der Rest zwischen Loch und Mulde kommt in _teich)
	var loch := teich_loch()
	var a := RASEN_RECHTECK
	for r: Rect2 in [Rect2(a.position.x, a.position.y, a.size.x, loch.position.y - a.position.y),
			Rect2(a.position.x, loch.end.y, a.size.x, a.end.y - loch.end.y),
			Rect2(a.position.x, loch.position.y, loch.position.x - a.position.x, loch.size.y),
			Rect2(loch.end.x, loch.position.y, a.end.x - loch.end.x, loch.size.y)]:
		var b := BoxMesh.new()
		b.size = Vector3(r.size.x, RASEN_Y, r.size.y)
		_mesh(b, m_rasen, Vector3(r.get_center().x, RASEN_Y * 0.5, r.get_center().y))


## Rechteckloch unter dem Teich (fuer Stadtplatte, Sohle, Gelaende).
static func teich_loch() -> Rect2:
	var r := TEICH_R + Vector2.ONE * (TEICH_UFER + TEICH_LOCH_RAND)
	return Rect2(TEICH_M - r, r * 2.0)



func _wege_bauen() -> void:
	var y := 0.1
	var defs: Array = [
		[[Vector3(-168, y, -6), Vector3(-150, y, -20), Vector3(-130, y, -14), Vector3(-110, y, -8), Vector3(-90, y, -16), Vector3(-70, y, -6), Vector3(-52, y, -10)], true, 0],
		[[Vector3(-112, y, -60), Vector3(-122, y, -40), Vector3(-110, y, -8), Vector3(-124, y, 10), Vector3(-138, y, 22), Vector3(-125, y, 36), Vector3(-112, y, 42)], true, 1],
		[[Vector3(-110, y, -8), Vector3(-97, y, -4), Vector3(-85, y, -6)], true, 0],
		[[Vector3(-72, y, -38), Vector3(-80, y, -27), Vector3(-90, y, -16)], true, 1],
	]
	# Rundweg um den Teich
	var ring: Array[Vector3] = []
	for i in 20:
		var a := TAU * i / 20.0
		ring.append(Vector3(TEICH_M.x + cos(a) * (TEICH_R.x + 7.0), y, TEICH_M.y + sin(a) * (TEICH_R.y + 7.0)))
	defs.append([ring, false, 1])
	for d in defs:
		var pts: Array[Vector3] = []
		pts.assign(d[0])
		var k := Geo.kurve(pts, d[1], 10)
		wege.append(k)
		for p in k:
			weg_pkte.append(Vector2(p.x, p.z))
	for i in wege.size():
		var k: Array[Vector3] = []
		k.assign(wege[i])
		var mi := MeshInstance3D.new()
		mi.mesh = Geo.band(k, 5.0)
		mi.material_override = m_weg
		add_child(mi)
		var farbe_c: bool = defs[i][2] == 0
		# Neon-Lichtstreifen an den Raendern, an Kreuzungen ausgespart
		for seite in [-2.1, 2.1]:
			var lauf: Array[Vector3] = []
			for p in k:
				if _nahe_anderer_weg(Vector2(p.x, p.z), i):
					_streifen(lauf, seite, farbe_c)
					lauf = []
				else:
					lauf.append(p)
			_streifen(lauf, seite, farbe_c)


func _nahe_anderer_weg(p: Vector2, eigener: int) -> bool:
	for j in wege.size():
		if j == eigener:
			continue
		for q in wege[j]:
			if p.distance_to(Vector2(q.x, q.z)) < 3.6:
				return true
	return false


func _streifen(lauf: Array[Vector3], seite: float, cyan: bool) -> void:
	if lauf.size() < 2:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = Geo.band(lauf, 0.3, seite, 0.03)
	mi.material_override = m_neon_c if cyan else m_neon_m
	add_child(mi)


# ---------------------------------------------------------------- Teich

func _teich() -> void:
	var c := Vector3(TEICH_M.x, 0.0, TEICH_M.y)
	var ufer := TEICH_R + Vector2.ONE * TEICH_UFER
	_teich_mulde(ufer)
	_teich_rasenrand(ufer)
	# Steinkante und Neonband um das Ufer
	var stein: Array[Vector3] = []
	var neon: Array[Vector3] = []
	for i in 32:
		var a := TAU * i / 32.0
		stein.append(c + Vector3(cos(a) * (ufer.x + 0.5), RASEN_Y + 0.02, sin(a) * (ufer.y + 0.5)))
		neon.append(c + Vector3(cos(a) * (ufer.x + 1.1), RASEN_Y + 0.06, sin(a) * (ufer.y + 1.1)))
	var rand := MeshInstance3D.new()
	rand.mesh = Geo.band(Geo.kurve(stein, false, 4), 1.0)
	rand.material_override = m_stein
	add_child(rand)
	var mi := MeshInstance3D.new()
	mi.mesh = Geo.band(Geo.kurve(neon, false, 4), 0.35)
	mi.material_override = m_neon_c
	add_child(mi)
	# Wasserflaeche (von oben und unten sichtbar) und Wasserzone fuers Schwimmen
	var wm := ShaderMaterial.new()
	wm.shader = load("res://wasser.gdshader")
	var wasser := _mesh(_zyl_mesh(1.0, 1.0, 0.06, TEICH_SEGMENTE), wm, c + Vector3(0, TEICH_WASSER_Y - 0.03, 0))
	wasser.scale = Vector3(ufer.x, 1.0, ufer.y)
	var zone := Area3D.new()
	zone.name = "TeichWasser"
	zone.add_to_group("wasser")
	zone.set_meta("oberflaeche", TEICH_WASSER_Y)
	zone.monitorable = true
	zone.monitoring = false
	var punkte := PackedVector3Array()
	for i in 24:
		var a := TAU * i / 24.0
		for y: float in [TEICH_WASSER_Y, -TEICH_TIEFE - 1.0]:
			punkte.append(Vector3(cos(a) * ufer.x, y, sin(a) * ufer.y))
	var form := ConvexPolygonShape3D.new()
	form.points = punkte
	var cs := CollisionShape3D.new()
	cs.shape = form
	zone.add_child(cs)
	zone.position = c
	add_child(zone)
	zone.set_meta("oberflaeche", to_global(Vector3(0, TEICH_WASSER_Y, 0)).y)


## Tiefe der Mulde bei Radius-Anteil s (0 Mitte, 1 Uferkante).
func _teich_hoehe(s: float) -> float:
	return lerpf(-TEICH_TIEFE, RASEN_Y, smoothstep(TEICH_STEIL_AB, 1.0, s))


func _teich_mulde(ufer: Vector2) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c := Vector3(TEICH_M.x, 0.0, TEICH_M.y)
	var punkt := func(s: float, i: int) -> Vector3:
		var a := TAU * i / TEICH_SEGMENTE
		return c + Vector3(cos(a) * ufer.x * s, _teich_hoehe(s), sin(a) * ufer.y * s)
	for k in TEICH_RINGE:
		var s0 := float(k) / TEICH_RINGE
		var s1 := float(k + 1) / TEICH_RINGE
		for i in TEICH_SEGMENTE:
			var a0: Vector3 = punkt.call(s0, i)
			var a1: Vector3 = punkt.call(s0, i + 1)
			var b0: Vector3 = punkt.call(s1, i)
			var b1: Vector3 = punkt.call(s1, i + 1)
			for v in [a0, b1, b0, a0, a1, b1]:
				st.set_uv(Vector2(v.x, v.z) * 0.25)
				st.add_vertex(v)
	st.generate_normals()
	var grund := _std(Color(0.16, 0.2, 0.2), 0.0, 0.0, 0.9)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = grund
	add_child(mi)
	var form := mi.mesh.create_trimesh_shape() as ConcavePolygonShape3D
	form.backface_collision = true
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = form
	sb.add_child(cs)
	add_child(sb)


## Rasen zwischen Teichloch (Rechteck) und Uferkante (Ellipse), mit Kollision (dort fehlt die Stadtplatte).
func _teich_rasenrand(ufer: Vector2) -> void:
	var loch := teich_loch()
	var c := Vector2(TEICH_M.x, TEICH_M.y)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var innen := func(i: int) -> Vector3:
		var a := TAU * i / TEICH_SEGMENTE
		return Vector3(c.x + cos(a) * ufer.x, RASEN_Y, c.y + sin(a) * ufer.y)
	var aussen := func(i: int) -> Vector3:
		# Strahl von der Mitte bis zum Rechteckrand
		var a := TAU * i / TEICH_SEGMENTE
		var d := Vector2(cos(a), sin(a))
		var tx := (loch.size.x * 0.5) / maxf(absf(d.x), 0.0001)
		var tz := (loch.size.y * 0.5) / maxf(absf(d.y), 0.0001)
		var p := c + d * minf(tx, tz)
		return Vector3(p.x, RASEN_Y, p.y)
	for i in TEICH_SEGMENTE:
		var a0: Vector3 = innen.call(i)
		var a1: Vector3 = innen.call(i + 1)
		var b0: Vector3 = aussen.call(i)
		var b1: Vector3 = aussen.call(i + 1)
		for v in [a0, b0, b1, a0, b1, a1]:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(v.x, v.z) * 0.3)
			st.add_vertex(v)
	# Ecken des Rechtecks: Strahlen zu den Segmentgrenzen lassen Zwickel offen, daher Eckdreiecke
	for i in TEICH_SEGMENTE:
		var b0: Vector3 = aussen.call(i)
		var b1: Vector3 = aussen.call(i + 1)
		if absf(b0.x - b1.x) > 0.01 and absf(b0.z - b1.z) > 0.01:
			var ecke := Vector3(loch.end.x if b0.x > c.x else loch.position.x, RASEN_Y, loch.end.y if b0.z > c.y else loch.position.y)
			for v in [b0, ecke, b1]:
				st.set_normal(Vector3.UP)
				st.set_uv(Vector2(v.x, v.z) * 0.3)
				st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m_rasen
	add_child(mi)
	var form := mi.mesh.create_trimesh_shape() as ConcavePolygonShape3D
	form.backface_collision = true
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = form
	sb.add_child(cs)
	add_child(sb)


# ---------------------------------------------------------------- Pavillons

func _pavillon(p2: Vector2, r: float) -> void:
	var c := Vector3(p2.x, 0.0, p2.y)
	var hoehe := 4.2
	var sockel := _mesh(_zyl_mesh(r, r, 0.08, 32), m_weg, c + Vector3(0, 0.1, 0))
	sockel.name = "Sockel"
	var rk := _kreis(c + Vector3(0, 0.15, 0), r - 0.4)
	var ring := MeshInstance3D.new()
	ring.mesh = Geo.band(rk, 0.35)
	ring.material_override = m_neon_m
	add_child(ring)
	for i in 6:
		var a := TAU * i / 6.0 + 0.2
		var px := c.x + cos(a) * (r - 0.7)
		var pz := c.z + sin(a) * (r - 0.7)
		_mesh(_zyl_mesh(0.2, 0.26, hoehe, 10), m_chrom, Vector3(px, hoehe * 0.5, pz))
		_stat_zyl(Vector3(px, hoehe * 0.5, pz), 0.28, hoehe)
	var balken := Geo.rohr(_kreis(c + Vector3(0, hoehe, 0), r - 0.7), 0.17, 8)
	_mesh(balken, m_chrom, Vector3.ZERO)
	var neon := Geo.rohr(_kreis(c + Vector3(0, hoehe - 0.3, 0), r - 0.7), 0.07, 6)
	_mesh(neon, m_neon_c, Vector3.ZERO)
	# Glaskuppel
	var kuppel := SphereMesh.new()
	kuppel.radius = r - 0.6
	kuppel.height = r - 0.6
	kuppel.is_hemisphere = true
	kuppel.radial_segments = 32
	kuppel.rings = 12
	_mesh(kuppel, m_glas, c + Vector3(0, hoehe, 0))
	# Chrom-Rippen der Kuppel
	var rr := r - 0.6
	for i in 8:
		var a := TAU * i / 8.0
		var pts: Array[Vector3] = []
		for k in 7:
			var phi := (PI * 0.5) * k / 6.0
			pts.append(c + Vector3(cos(a) * cos(phi) * rr, hoehe + sin(phi) * rr, sin(a) * cos(phi) * rr))
		_mesh(Geo.rohr(Geo.kurve(pts, true, 3), 0.05, 6), m_chrom, Vector3.ZERO)
	_mesh(_kugel(0.3), m_neon_m, c + Vector3(0, hoehe + rr + 0.1, 0))
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.5, 0.9)
	l.light_energy = 1.6
	l.omni_range = 14.0
	l.position = c + Vector3(0, hoehe + 1.5, 0)
	add_child(l)


# ---------------------------------------------------------------- Baeume, Straeucher, Blumen

func _baeume_bauen() -> void:
	var t_stamm: Array = []
	var f_stamm: Array = []
	var t_krone: Array = []
	var f_krone: Array = []
	var versuche := 0
	while baeume.size() < 52 and versuche < 600:
		versuche += 1
		var p := Vector2(rng.randf_range(GRENZE.position.x, GRENZE.end.x), rng.randf_range(GRENZE.position.y, GRENZE.end.y))
		if not _frei(p, 1.5):
			continue
		var zu_nah := false
		for b in baeume:
			if p.distance_to(b["pos"]) < 8.0:
				zu_nah = true
				break
		if zu_nah:
			continue
		var s := rng.randf_range(0.9, 1.5)
		baeume.append({"pos": p, "s": s})
		var h := 4.4 * s
		t_stamm.append(Transform3D(Basis.IDENTITY.scaled(Vector3(s, h, s)), Vector3(p.x, h * 0.5, p.y)))
		f_stamm.append(Color.WHITE)
		_stat_zyl(Vector3(p.x, h * 0.5, p.y), 0.5 * s, h)
		var farbe: Color = KRONEN[rng.randi() % KRONEN.size()]
		# Hauptkrone plus bauschige Zuckerwatte-Loben
		var rk := 3.2 * s
		t_krone.append(Transform3D(Basis.IDENTITY.scaled(Vector3(rk, rk * 0.9, rk)), Vector3(p.x, h + 1.8 * s, p.y)))
		f_krone.append(farbe)
		for k in 4:
			var a := rng.randf() * TAU
			var rl := rng.randf_range(1.8, 2.5) * s
			var off := Vector3(cos(a) * 2.1 * s, rng.randf_range(0.5, 2.0) * s, sin(a) * 2.1 * s)
			t_krone.append(Transform3D(Basis.IDENTITY.scaled(Vector3(rl, rl * 0.9, rl)), Vector3(p.x, h + 1.8 * s, p.y) + off))
			f_krone.append(farbe.lerp(KRONEN[rng.randi() % KRONEN.size()], 0.25))
	_multimesh(_zyl_mesh(0.32, 0.5, 1.0, 8), m_holz, t_stamm, f_stamm)
	_multimesh(_kugel(1.0, 14, 8), m_zucker, t_krone, f_krone)


func _straeucher() -> void:
	var t_w: Array = []
	var f_w: Array = []
	var t_k: Array = []
	var f_k: Array = []
	var t_z: Array = []
	var f_z: Array = []
	var n := 0
	var versuche := 0
	while n < 44 and versuche < 500:
		versuche += 1
		var p := Vector2(rng.randf_range(GRENZE.position.x, GRENZE.end.x), rng.randf_range(GRENZE.position.y, GRENZE.end.y))
		if not _frei(p, 1.6):
			continue
		var nah := false
		for b in baeume:
			if p.distance_to(b["pos"]) < 2.6:
				nah = true
				break
		if nah:
			continue
		n += 1
		var farbe := Color.from_hsv(rng.randf_range(0.27, 0.36), rng.randf_range(0.25, 0.45), rng.randf_range(0.55, 0.8))
		var typ := rng.randi() % 3
		var yaw := Basis(Vector3.UP, rng.randf() * TAU)
		if typ == 0:
			# geschnittener Wuerfel / Heckenstueck
			var sz := Vector3(rng.randf_range(1.6, 4.0), rng.randf_range(1.0, 1.6), rng.randf_range(1.4, 2.0))
			t_w.append(Transform3D(yaw.scaled(sz), Vector3(p.x, sz.y * 0.5, p.y)))
			f_w.append(farbe)
		elif typ == 1:
			# Kugel-Busch
			var r := rng.randf_range(0.9, 1.4)
			t_k.append(Transform3D(Basis.IDENTITY.scaled(Vector3(r, r, r)), Vector3(p.x, r, p.y)))
			f_k.append(farbe)
		else:
			# Kegel
			var h := rng.randf_range(2.0, 3.2)
			t_z.append(Transform3D(yaw.scaled(Vector3(1.0, h, 1.0)), Vector3(p.x, h * 0.5, p.y)))
			f_z.append(farbe)
	_multimesh(BoxMesh.new(), m_hecke, t_w, f_w)
	_multimesh(_kugel(1.0, 14, 8), m_hecke, t_k, f_k)
	_multimesh(_zyl_mesh(0.0, 1.1, 1.0, 10), m_hecke, t_z, f_z)


func _blumen_bauen() -> void:
	var t_stiel: Array = []
	var f_stiel: Array = []
	var t_kopf: Array = []
	var f_kopf: Array = []
	var gruppen := 0
	var versuche := 0
	while gruppen < 18 and versuche < 300:
		versuche += 1
		var m := Vector2(rng.randf_range(GRENZE.position.x, GRENZE.end.x), rng.randf_range(GRENZE.position.y, GRENZE.end.y))
		if not _frei(m, 2.8):
			continue
		gruppen += 1
		var grundfarbe: Color = BLUMEN[rng.randi() % BLUMEN.size()]
		for i in rng.randi_range(6, 11):
			var a := rng.randf() * TAU
			var d := rng.randf_range(0.0, 2.6)
			var p := Vector3(m.x + cos(a) * d, 0.0, m.y + sin(a) * d)
			var h := rng.randf_range(0.6, 1.3)
			t_stiel.append(Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, h, 1.0)), Vector3(p.x, h * 0.5, p.z)))
			f_stiel.append(Color(0.1, 0.45, 0.2))
			var k := rng.randf_range(0.32, 0.55)
			t_kopf.append(Transform3D(Basis.IDENTITY.scaled(Vector3(k, k * 1.2, k)), Vector3(p.x, h + 0.1, p.z)))
			f_kopf.append(grundfarbe.lerp(BLUMEN[rng.randi() % BLUMEN.size()], 0.3))
	_multimesh(_zyl_mesh(0.03, 0.04, 1.0, 5), m_gruen, t_stiel, f_stiel)
	_multimesh(_kugel(0.5, 10, 6), m_blume, t_kopf, f_kopf)


# ---------------------------------------------------------------- Baenke, Laternen

func _bank_vorlage() -> Node3D:
	var b := Node3D.new()
	var bogen := func(x: float) -> float:
		return 0.18 * (x / 1.2) * (x / 1.2)
	# Sitz: drei Chrom-Latten, leicht geschwungen
	for dz in [-0.28, 0.0, 0.28]:
		var pts: Array[Vector3] = []
		for x in [-1.2, -0.6, 0.0, 0.6, 1.2]:
			pts.append(Vector3(x, 0.5, dz + bogen.call(x)))
		_mesh(Geo.rohr(Geo.kurve(pts, true, 4), 0.07, 6), m_chrom, Vector3.ZERO, b)
	# Lehne: zwei Latten
	for yy in [0.8, 1.02]:
		var pts: Array[Vector3] = []
		for x in [-1.2, -0.6, 0.0, 0.6, 1.2]:
			pts.append(Vector3(x, yy, -0.5 + bogen.call(x)))
		_mesh(Geo.rohr(Geo.kurve(pts, true, 4), 0.055, 6), m_chrom, Vector3.ZERO, b)
	# Beine: geschwungener Schwung vom Boden nach hinten oben
	for x in [-1.0, 1.0]:
		var pts: Array[Vector3] = []
		for yz in [Vector2(0.02, 0.55), Vector2(0.08, 0.3), Vector2(0.3, 0.05), Vector2(0.5, -0.18), Vector2(0.8, -0.42), Vector2(1.04, -0.5)]:
			pts.append(Vector3(x, yz.x, yz.y + bogen.call(x)))
		_mesh(Geo.rohr(Geo.kurve(pts, true, 4), 0.07, 6), m_chrom, Vector3.ZERO, b)
	var glow := BoxMesh.new()
	glow.size = Vector3(2.0, 0.03, 0.5)
	_mesh(glow, m_neon_c, Vector3(0, 0.3, 0.05), b)
	return b


func _bank_setzen(vorlage: Node3D, pos: Vector3, blick_nach: Vector3) -> Node3D:
	var b: Node3D = vorlage.duplicate()
	b.position = pos
	var d := blick_nach - pos
	b.rotation.y = atan2(d.x, d.z)
	add_child(b)
	return b


## Aen (characters/aen.gd) sitzt auf der Bank und klatscht vor sich hin.
func _aen_setzen(bank: Node3D) -> void:
	var aen: Node3D = AEN.new()
	aen.name = "Aen"
	bank.add_child(aen)
	aen.position = Vector3(0.0, BANK_SITZ_HOEHE, 0.0)


func _baenke() -> void:
	var v := _bank_vorlage()
	var gebaut: Array[Node3D] = []
	# (Weg-Index, Anteil, Seite)
	var plaetze := [[0, 0.18, 1.0], [0, 0.78, -1.0], [1, 0.2, 1.0], [1, 0.85, -1.0], [3, 0.5, 1.0], [4, 0.04, -1.0], [4, 0.3, -1.0], [4, 0.55, -1.0], [4, 0.8, -1.0]]
	for pl in plaetze:
		var k: Array[Vector3] = []
		k.assign(wege[pl[0]])
		var i := clampi(int(pl[1] * (k.size() - 1)), 1, k.size() - 2)
		var t := (k[i + 1] - k[i - 1])
		t.y = 0.0
		t = t.normalized()
		var n: Vector3 = Vector3(-t.z, 0.0, t.x) * float(pl[2])
		var p: Vector3 = k[i] + n * 3.6
		p.y = 0.0
		if not _frei(Vector2(p.x, p.z), 0.8, false):
			continue
		gebaut.append(_bank_setzen(v, p, k[i]))
	v.queue_free()
	if not gebaut.is_empty():
		_aen_setzen(gebaut[mini(AEN_BANK, gebaut.size() - 1)])


func _laternen() -> void:
	var n := 0
	for wi in [0, 1, 4, 4, 3]:
		var k: Array[Vector3] = []
		k.assign(wege[wi])
		for frac in [0.1, 0.38, 0.66, 0.92]:
			if n >= 14:
				return
			var i := clampi(int(frac * (k.size() - 1)), 1, k.size() - 2)
			var t := k[i + 1] - k[i - 1]
			t.y = 0.0
			t = t.normalized()
			var seite := 1.0 if (n % 2 == 0) else -1.0
			var p := k[i] + Vector3(-t.z, 0, t.x) * 3.5 * seite
			if not _frei(Vector2(p.x, p.z), 0.6, false):
				continue
			n += 1
			_lampe(Vector3(p.x, 0.0, p.z))


func _lampe(p: Vector3) -> void:
	_mesh(_zyl_mesh(0.07, 0.11, 4.6, 8), m_weiss, p + Vector3(0, 2.3, 0))
	_mesh(_zyl_mesh(0.2, 0.2, 0.12, 12), m_chrom, p + Vector3(0, 4.55, 0))
	_mesh(_kugel(0.48, 16, 10), m_lampe, p + Vector3(0, 5.05, 0))
	_stat_zyl(p + Vector3(0, 2.3, 0), 0.12, 4.6)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.9, 0.75)
	l.light_energy = 1.5
	l.omni_range = 16.0
	l.position = p + Vector3(0, 4.8, 0)
	add_child(l)


# ---------------------------------------------------------------- Fauna

func _fauna() -> void:
	var kandidaten := baeume.duplicate()
	kandidaten.shuffle()
	# Roboter-Voegel auf Astgabeln
	for i in mini(14, kandidaten.size()):
		var b: Dictionary = kandidaten[i]
		_vogel_auf_ast(b["pos"], b["s"])
	# mechanische Eichhoernchen an den Staemmen
	for i in mini(6, kandidaten.size()):
		var b: Dictionary = kandidaten[kandidaten.size() - 1 - i]
		var e := _eichhoernchen()
		add_child(e)
		hoernchen.append({
			"node": e, "pos": b["pos"], "s": b["s"], "y": rng.randf_range(0.3, 3.0), "dir": 1.0 if rng.randf() < 0.5 else -1.0,
			"a": rng.randf() * TAU, "tempo": rng.randf_range(2.5, 4.5), "pause": rng.randf_range(0.0, 2.0)})


func _vogel_auf_ast(pos: Vector2, s: float) -> void:
	var a := rng.randf() * TAU
	var aus := Vector3(cos(a), 0, sin(a))
	var start := Vector3(pos.x, 3.0 * s, pos.y) + aus * 0.3 * s
	var ende := start + aus * 2.3 + Vector3(0, 0.9, 0)
	_mesh(Geo.rohr(Geo.kurve([start, (start + ende) * 0.5, ende] as Array[Vector3], true, 4), 0.09, 6), m_holz, Vector3.ZERO)
	# Astgabel
	for dir in [-1.0, 1.0]:
		var quer: Vector3 = Vector3(-aus.z, 0, aus.x) * float(dir)
		var gabel_ende: Vector3 = ende + aus * 0.5 + quer * 0.35 + Vector3(0, 0.5, 0)
		_mesh(Geo.rohr([ende, gabel_ende] as Array[Vector3], 0.05, 5), m_holz, Vector3.ZERO)
	var vogel := Node3D.new()
	vogel.position = ende + Vector3(0, 0.12, 0)
	vogel.rotation.y = a + rng.randf_range(-0.8, 0.8)
	add_child(vogel)
	var federn := [Color(0.5, 0.65, 0.9), Color(0.3, 0.85, 0.8), Color(0.95, 0.55, 0.85), Color(0.95, 0.75, 0.3)]
	var koerper := _std(federn[rng.randi() % federn.size()], 0.0, 1.0, 0.25)
	var led := _std(Color.from_hsv(rng.randf(), 0.8, 1.0), 3.0)
	var k := _mesh(_kugel(0.16, 12, 8), koerper, Vector3(0, 0.15, 0), vogel)
	k.scale = Vector3(1.0, 0.85, 1.35)
	var kopf := Node3D.new()
	kopf.position = Vector3(0, 0.3, 0.16)
	vogel.add_child(kopf)
	_mesh(_kugel(0.1, 12, 8), koerper, Vector3.ZERO, kopf)
	var schnabel := _mesh(_zyl_mesh(0.0, 0.04, 0.12, 6), _std(Color(1.0, 0.8, 0.2), 1.0), Vector3(0, -0.01, 0.12), kopf)
	schnabel.rotation.x = PI * 0.5
	for sx in [-1.0, 1.0]:
		_mesh(_kugel(0.03, 8, 6), led, Vector3(sx * 0.07, 0.03, 0.06), kopf)
		var fl := _mesh(_kugel(0.1, 8, 6), koerper, Vector3(sx * 0.15, 0.17, -0.02), vogel)
		fl.scale = Vector3(0.25, 0.8, 1.5)
	var schwanz := _mesh(BoxMesh.new(), koerper, Vector3(0, 0.15, -0.3), vogel)
	schwanz.scale = Vector3(0.12, 0.02, 0.25)
	schwanz.rotation.x = -0.35
	voegel.append({"kopf": kopf, "led": led, "ph": rng.randf() * TAU})


func _eichhoernchen() -> Node3D:
	var e := Node3D.new()
	var metall := _std(Color(0.85, 0.5, 0.25), 0.0, 1.0, 0.3)
	var led := _std(Color(0.3, 1.0, 0.5), 3.0)
	var koerper := _mesh(_kugel(0.13, 10, 6), metall, Vector3.ZERO, e)
	koerper.scale = Vector3(0.9, 1.7, 0.9)
	_mesh(_kugel(0.1, 10, 6), metall, Vector3(0, 0.3, 0.07), e)
	for sx in [-1.0, 1.0]:
		_mesh(_kugel(0.025, 6, 4), led, Vector3(sx * 0.07, 0.33, 0.14), e)
		var ohr := _mesh(_zyl_mesh(0.0, 0.035, 0.1, 5), metall, Vector3(sx * 0.05, 0.41, 0.05), e)
		ohr.rotation.z = -sx * 0.2
	# buschiger Schwanz, nach oben geschwungen
	for sph in [[Vector3(0, -0.14, -0.14), 0.07], [Vector3(0, 0.0, -0.24), 0.09], [Vector3(0, 0.2, -0.28), 0.11], [Vector3(0, 0.4, -0.25), 0.1]]:
		_mesh(_kugel(sph[1], 8, 6), metall, sph[0], e)
	return e


func _process(delta: float) -> void:
	_t += delta
	for v in voegel:
		var ph: float = v["ph"]
		var kopf: Node3D = v["kopf"]
		kopf.rotation.y = sin(_t * 0.7 + ph) * 0.8
		kopf.rotation.x = maxf(0.0, sin(_t * 2.3 + ph * 3.0) - 0.6) * 1.0
		var led: StandardMaterial3D = v["led"]
		led.emission_energy_multiplier = 2.5 + 2.5 * sin(_t * 3.0 + ph)
	for h in hoernchen:
		var n: Node3D = h["node"]
		var s: float = h["s"]
		var pos: Vector2 = h["pos"]
		if h["pause"] > 0.0:
			h["pause"] -= delta
		else:
			h["y"] += h["dir"] * h["tempo"] * delta
			h["a"] += 0.5 * h["dir"] * delta
			if randf() < 0.25 * delta:
				h["pause"] = randf_range(0.3, 1.2)
			if h["y"] > 3.8 * s:
				h["y"] = 3.8 * s
				h["dir"] = -1.0
				h["pause"] = randf_range(0.5, 2.0)
			elif h["y"] < 0.25:
				h["y"] = 0.25
				h["dir"] = 1.0
				h["pause"] = randf_range(0.5, 2.0)
		var a: float = h["a"]
		var rad := 0.42 * s + 0.12
		n.position = Vector3(pos.x + cos(a) * rad, h["y"], pos.y + sin(a) * rad)
		n.rotation = Vector3(0.0, PI * 0.5 - a, PI if h["dir"] < 0.0 else 0.0)
