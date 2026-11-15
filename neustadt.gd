extends Node3D
## Neo-Distrikt: Die Neustadt auf dem Plateau hinter dem Gurken-Wald.
## Das City-Builder-Plugin (addons/citycrafter) setzt Wohnappartements, Gewerbe und Industrie,
## danach bekommen alle Gebaeude den Synth-City-Look (dunkel, Neon-Kanten, leuchtende Fenster)
## und eine Kollision. Dazu kommt die neonbeleuchtete Strasse durch den Durchgang.

const GEO := preload("res://geo.gd")
const CITYCRAFTER := "res://addons/citycrafter/citycrafter.gd"
const KIT := "res://addons/citycrafter/assets/example_assets/"
const RASTER := 5
const BLOCK := 50.0
const STRASSE := 16.0
const SAAT := 20261107

const WOHNEN := ["a", "c", "e", "f", "i", "j", "l", "m", "n"]
const GEWERBE := ["skyscraper-a", "skyscraper-b", "skyscraper-c", "skyscraper-d", "skyscraper-e", "h", "k"]
const INDUSTRIE := ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t"]

var stadt: Node3D
var rng := RandomNumberGenerator.new()
var terrain: Node = null
var _mats := {}
var m_neon: Array[StandardMaterial3D] = []


func _ready() -> void:
	rng.seed = SAAT
	terrain = get_node_or_null("../Terrain")
	_neon_materialien()
	_durchgang_strasse()
	_plateau_rand()
	_stadt_bauen()


func _neon_materialien() -> void:
	for c in [Color(0.2, 0.9, 1.0), Color(1.0, 0.2, 0.8), Color(1.0, 0.6, 0.15), Color(0.5, 0.35, 1.0)]:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 3.0
		m_neon.append(m)


func _gelaende_hoehe(x: float, z: float) -> float:
	if terrain != null:
		var d = terrain.get_data()
		if d != null:
			var h: float = d.get_height(Vector3(x, 0.0, z))
			if not is_nan(h):
				return h
	return TerrainForm.hoehe(x, z)


# ---------------------------------------------------------------- Durchgang

## Dunkle Fahrbahn mit Neon-Randlinien und Laternen vom Stadttor bis aufs Plateau.
func _durchgang_strasse() -> void:
	var pts: Array[Vector3] = []
	var x := TerrainForm.PASS_X0 + 25.0
	while x > TerrainForm.PLATEAU_M.x + TerrainForm.PLATEAU_R - 14.0:
		var z := TerrainForm.pass_z(x)
		pts.append(Vector3(x, TerrainForm.pass_h(x) + 0.18, z))
		x -= 6.0
	var asphalt := StandardMaterial3D.new()
	asphalt.albedo_color = Color(0.06, 0.06, 0.09)
	asphalt.metallic = 0.4
	asphalt.roughness = 0.35
	var mesh := MeshInstance3D.new()
	mesh.mesh = GEO.band(pts, 16.0)
	mesh.material_override = asphalt
	add_child(mesh)
	for seite in [-1.0, 1.0]:
		var kante := MeshInstance3D.new()
		kante.mesh = GEO.band(pts, 0.5, seite * 8.0, 0.04)
		kante.material_override = m_neon[0] if seite < 0.0 else m_neon[1]
		add_child(kante)
	# Laternen
	var i := 2
	while i < pts.size():
		for seite in [-1.0, 1.0]:
			var p := pts[i]
			var richt := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)])
			richt.y = 0.0
			richt = richt.normalized()
			var q: Vector3 = Vector3(-richt.z, 0.0, richt.x) * seite * 10.5
			_laterne(p + q, m_neon[0] if seite < 0.0 else m_neon[1])
		i += 6
	# Wegweiser am Plateau
	var l := Label3D.new()
	l.text = "NEO-DISTRIKT"
	l.font_size = 64
	l.pixel_size = 0.08
	l.modulate = Color(0.5, 1.4, 1.6)
	l.outline_modulate = Color(0, 0.1, 0.2)
	l.outline_size = 14
	l.shaded = false
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = Vector3(TerrainForm.PLATEAU_M.x + TerrainForm.PLATEAU_R - 6.0, TerrainForm.PLATEAU_H + 26.0, TerrainForm.PASS_Z)
	add_child(l)


func _laterne(pos: Vector3, mat: Material) -> void:
	var mast := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.2
	cm.bottom_radius = 0.3
	cm.height = 7.0
	mast.mesh = cm
	mast.position = pos + Vector3(0, 3.5, 0)
	var stahl := StandardMaterial3D.new()
	stahl.albedo_color = Color(0.15, 0.16, 0.22)
	stahl.metallic = 0.8
	stahl.roughness = 0.3
	mast.material_override = stahl
	add_child(mast)
	var lampe := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.7
	sm.height = 1.4
	lampe.mesh = sm
	lampe.material_override = mat
	lampe.position = pos + Vector3(0, 7.3, 0)
	add_child(lampe)


## Unsichtbare Waende um das Plateau, damit man nicht in die Berge laeuft.
func _plateau_rand() -> void:
	var m := TerrainForm.PLATEAU_M
	var r := TerrainForm.PLATEAU_R + 8.0
	var luecke := 24.0
	var seiten := [
		[Vector3(m.x, 0, m.y - r), Vector3(2.0 * r, 0, 0), Vector3(2.0 * r, 160, 6)],
		[Vector3(m.x, 0, m.y + r), Vector3(2.0 * r, 0, 0), Vector3(2.0 * r, 160, 6)],
		[Vector3(m.x - r, 0, m.y), Vector3(0, 0, 2.0 * r), Vector3(6, 160, 2.0 * r)],
	]
	for s in seiten:
		_wand(s[0] + Vector3(0, 80, 0), s[2])
	# Ostseite mit Luecke fuer den Durchgang
	var z0 := m.y - r
	var z1 := TerrainForm.PASS_Z - luecke
	_wand(Vector3(m.x + r, 80, (z0 + z1) / 2.0), Vector3(6, 160, z1 - z0))
	var z2 := TerrainForm.PASS_Z + luecke
	var z3 := m.y + r
	_wand(Vector3(m.x + r, 80, (z2 + z3) / 2.0), Vector3(6, 160, z3 - z2))


func _wand(pos: Vector3, groesse: Vector3) -> void:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = groesse
	cs.shape = sh
	sb.add_child(cs)
	sb.position = pos
	add_child(sb)


# ---------------------------------------------------------------- Stadt per City-Builder-Plugin

func _szenen(ordner: String, namen: Array, praefix: String) -> Array[PackedScene]:
	var out: Array[PackedScene] = []
	for n in namen:
		var pfad: String = KIT + ordner + "/Models/GLB format/" + praefix + n + ".glb"
		var ps = load(pfad)
		if ps is PackedScene:
			out.append(ps)
	return out


func _stadt_bauen() -> void:
	var cfg := CityConfiguration.new()
	cfg.residential_buildings = _szenen("kenney_city-kit-commercial_20", WOHNEN, "building-")
	cfg.commercial_buildings = _szenen("kenney_city-kit-commercial_20", GEWERBE, "building-")
	cfg.industrial_buildings = _szenen("kenney_city-kit-industrial_1.0", INDUSTRIE, "building-")
	var asphalt := StandardMaterial3D.new()
	asphalt.albedo_color = Color(0.05, 0.05, 0.08)
	asphalt.metallic = 0.4
	asphalt.roughness = 0.3
	var kreuzung := StandardMaterial3D.new()
	kreuzung.albedo_color = Color(0.08, 0.08, 0.12)
	kreuzung.metallic = 0.4
	kreuzung.roughness = 0.3
	cfg.road_material = asphalt
	cfg.intersection_material = kreuzung
	cfg.subdivision_road_material = asphalt
	cfg.ground_material = _boden_mat(Color(0.12, 0.12, 0.2))
	cfg.residential_ground_material = _boden_mat(Color(0.2, 0.1, 0.25))
	cfg.commercial_ground_material = _boden_mat(Color(0.08, 0.16, 0.26))
	cfg.industrial_ground_material = _boden_mat(Color(0.22, 0.14, 0.08))
	cfg.grid_width = RASTER
	cfg.grid_height = RASTER
	cfg.block_size = BLOCK
	cfg.street_width = STRASSE
	cfg.empty_block_chance = 0.0
	cfg.enable_multi_size_blocks = false
	cfg.enable_edge_variations = false
	cfg.enable_random_extensions = false
	cfg.district_mode = 2
	cfg.residential_ratio = 0.38
	cfg.commercial_ratio = 0.38
	cfg.industrial_ratio = 0.24
	cfg.enable_residential_subdivisions = false
	cfg.residential_buildings_min = 3
	cfg.residential_buildings_max = 4
	cfg.residential_spacing = 22.0
	cfg.residential_border_margin = 11.0
	cfg.commercial_buildings_min = 3
	cfg.commercial_buildings_max = 4
	cfg.commercial_spacing = 22.0
	cfg.commercial_border_margin = 11.0
	cfg.industrial_buildings_min = 3
	cfg.industrial_buildings_max = 4
	cfg.industrial_spacing = 22.0
	cfg.industrial_border_margin = 11.0
	cfg.rotation_mode = 1
	cfg.scale_variation = 0.0
	cfg.generate_roads = true
	cfg.generate_intersections = true
	cfg.generate_subdivision_roads = false
	cfg.intersection_height_offset = 0.03
	cfg.ground_height_offset = -0.05
	# Stadtursprung so legen, dass die Mittelachse (Strasse 2) auf den Durchgang trifft
	var pitch := BLOCK + STRASSE
	var mitte := (RASTER * pitch - STRASSE) / 2.0
	stadt = load(CITYCRAFTER).new()
	stadt.name = "Stadtbauer"
	stadt.city_configuration = cfg
	var ursprung_x := TerrainForm.PLATEAU_M.x - mitte
	var ursprung_z := TerrainForm.PASS_Z - (2.0 * pitch - STRASSE / 2.0)
	stadt.position = Vector3(ursprung_x, TerrainForm.PLATEAU_H + 0.1, ursprung_z)
	seed(SAAT)
	stadt.generation_complete.connect(_stil_anwenden)
	add_child(stadt)
	stadt.generate_city_async()


func _boden_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.5
	m.metallic = 0.3
	return m


# ---------------------------------------------------------------- Synth-Look

func _stil_anwenden() -> void:
	var nr := 0
	for b in stadt.get_children():
		if not (b is Node3D) or b is MeshInstance3D:
			continue
		var pfad: String = b.scene_file_path
		var art := 1  # Wohnen
		if pfad.contains("industrial"):
			art = 2
		elif pfad.contains("skyscraper"):
			art = 0
		_anpassen(b, art, nr)
		nr += 1
	_kreuzungslampen()
	print("[Neustadt] %d Gebaeude gestylt" % nr)


func _anpassen(b: Node3D, art: int, nr: int) -> void:
	# Groesse auf Synth-City-Mass bringen (Kenney-Modelle sind klein)
	var box := _aabb(b)
	var ziel := rng.randf_range(15.0, 22.0) if art != 2 else rng.randf_range(16.0, 24.0)
	var s: float = ziel / maxf(maxf(box.size.x, box.size.z), 0.01)
	var hoch := 1.0
	if art == 0:
		hoch = rng.randf_range(1.6, 3.0)
	elif art == 1:
		hoch = rng.randf_range(1.0, 1.7)
	b.scale = Vector3(s, s * hoch, s)
	# Farben und Leuchten
	var tint: Color = [Color(0.55, 0.8, 1.0), Color(1.0, 0.6, 1.0), Color(1.0, 0.75, 0.5)][art]
	var neon: StandardMaterial3D = m_neon[art]
	for mi in _meshes(b):
		for i in mi.mesh.get_surface_count():
			var orig := mi.mesh.surface_get_material(i)
			if orig is BaseMaterial3D:
				mi.set_surface_override_material(i, _stil_mat(orig, art, tint))
	# Dachkante als Neonrahmen und Kollision aus der Huelle im Raum der Stadt
	var pa := b.transform * _aabb(b)
	var g := pa.size
	var h := g.y
	var ts := 0.5
	var rahmen := Node3D.new()
	b.get_parent().add_child(rahmen)
	rahmen.position = Vector3(pa.position.x + g.x * 0.5, pa.position.y, pa.position.z + g.z * 0.5)
	for sx in [-1.0, 1.0]:
		_leiste(rahmen, Vector3(sx * g.x * 0.5, h, 0), Vector3(ts, ts, g.z + ts), neon)
	for sz in [-1.0, 1.0]:
		_leiste(rahmen, Vector3(0, h, sz * g.z * 0.5), Vector3(g.x + ts, ts, ts), neon)
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = g
	cs.shape = sh
	sb.add_child(cs)
	sb.position = Vector3(0, h * 0.5, 0)
	rahmen.add_child(sb)


func _leiste(eltern: Node3D, pos: Vector3, groesse: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = groesse
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	eltern.add_child(mi)


func _stil_mat(orig: BaseMaterial3D, art: int, tint: Color) -> StandardMaterial3D:
	var key := "%d_%d" % [orig.get_instance_id(), art]
	if _mats.has(key):
		return _mats[key]
	var m: StandardMaterial3D = orig.duplicate()
	m.albedo_color = tint * 0.32
	m.roughness = 0.45
	m.metallic = 0.35
	m.emission_enabled = true
	m.emission_texture = orig.albedo_texture
	m.emission = tint * 0.7
	m.emission_energy_multiplier = 0.28
	m.rim_enabled = true
	m.rim = 0.15
	m.rim_tint = 0.8
	_mats[key] = m
	return m


func _meshes(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_meshes(c))
	return out


## AABB der Meshes im Raum des Gebaeudes (ohne dessen eigenen Transform).
func _aabb(b: Node3D) -> AABB:
	var ergebnis := AABB()
	var erstes := true
	for mi in _meshes(b):
		var t := Transform3D.IDENTITY
		var n: Node = mi
		while n != null and n != b:
			if n is Node3D:
				t = (n as Node3D).transform * t
			n = n.get_parent()
		var a := t * mi.mesh.get_aabb()
		if erstes:
			ergebnis = a
			erstes = false
		else:
			ergebnis = ergebnis.merge(a)
	return ergebnis


func _kreuzungslampen() -> void:
	var pitch := BLOCK + STRASSE
	for i in RASTER + 1:
		for j in RASTER + 1:
			var p := stadt.position + Vector3(i * pitch - STRASSE * 0.5, 0.0, j * pitch - STRASSE * 0.5)
			_laterne(p + Vector3(5, 0, 5), m_neon[(i + j) % 4])
