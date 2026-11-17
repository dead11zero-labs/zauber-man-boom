extends RefCounted
## Gemeinsames Lieferdrohnen-Modell (Stil der Drohnen auf dem Neon-Markt, neonmarkt.gd): flacher Rumpf,
## vier Ausleger mit Rotorscheiben, Leuchtstreifen vorn (+z), optional Paket darunter.
## Meshes und Materialien werden geteilt (statisch gecacht), damit viele Drohnen wenig kosten.
## Nutzung: `const DM := preload("res://levels/drohnen_modell.gd")`, `var d := DM.bauen(DM.Stufe.FERTIG, true)`,
## im _process `DM.rotoren_drehen(d, delta)`. Rotoren stehen in d.get_meta("rotoren").
## Stufen: RAHMEN (nur Rumpf und Ausleger, Fertigungsband), FERTIG (mit Rotoren und Lichtern).
## Keine Signale, keine Exporte.

enum Stufe { RAHMEN, FERTIG }

const RUMPF := Vector3(1.4, 0.4, 1.0)
const AUSLEGER := Vector3(0.9, 0.06, 0.06)
const AUSLEGER_POS := Vector2(0.7, 0.5)
const ROTOR_POS := Vector2(1.1, 0.8)
const ROTOR_RADIUS := 0.45
const ROTOR_TEMPO := 40.0
const PAKET := Vector3(0.7, 0.5, 0.6)
const PAKET_Y := -0.5

static var _meshes: Dictionary = {}
static var _mats: Dictionary = {}


static func _mat(name: String) -> StandardMaterial3D:
	if _mats.has(name):
		return _mats[name]
	var m := StandardMaterial3D.new()
	match name:
		"rumpf":
			m.albedo_color = Color(0.08, 0.09, 0.12)
			m.metallic = 0.8
			m.roughness = 0.35
		"rahmen":
			m.albedo_color = Color(0.42, 0.44, 0.48)
			m.metallic = 0.9
			m.roughness = 0.4
		"rotor":
			m.albedo_color = Color(0.15, 0.9, 1.0)
			m.emission_enabled = true
			m.emission = Color(0.15, 0.9, 1.0)
			m.emission_energy_multiplier = 1.2
		"streifen":
			m.albedo_color = Color(1.0, 0.2, 0.65)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.2, 0.65)
			m.emission_energy_multiplier = 2.0
		"paket":
			m.albedo_color = Color(0.62, 0.45, 0.28)
			m.roughness = 0.9
		"band":
			m.albedo_color = Color(1.0, 0.8, 0.15)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.75, 0.1)
			m.emission_energy_multiplier = 0.8
	_mats[name] = m
	return m


static func _box_mesh(g: Vector3) -> BoxMesh:
	var key := "b%s" % g
	if not _meshes.has(key):
		var bm := BoxMesh.new()
		bm.size = g
		_meshes[key] = bm
	return _meshes[key]


static func _rotor_mesh() -> CylinderMesh:
	if not _meshes.has("rotor"):
		var cm := CylinderMesh.new()
		cm.top_radius = ROTOR_RADIUS
		cm.bottom_radius = ROTOR_RADIUS
		cm.height = 0.02
		cm.radial_segments = 12
		cm.rings = 1
		_meshes["rotor"] = cm
	return _meshes["rotor"]


static func _teil(eltern: Node3D, mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	eltern.add_child(mi)
	return mi


## Neue Drohne (Ursprung = Rumpfmitte, vorn = +z).
static func bauen(stufe: Stufe, mit_paket := false) -> Node3D:
	var d := Node3D.new()
	var rotoren: Array[Node3D] = []
	var fertig := stufe == Stufe.FERTIG
	_teil(d, _box_mesh(RUMPF), _mat("rumpf" if fertig else "rahmen"), Vector3.ZERO)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_teil(d, _box_mesh(AUSLEGER), _mat("rumpf" if fertig else "rahmen"), Vector3(sx * AUSLEGER_POS.x, 0.05, sz * AUSLEGER_POS.y))
			if fertig:
				var r := Node3D.new()
				r.position = Vector3(sx * ROTOR_POS.x, 0.12, sz * ROTOR_POS.y)
				d.add_child(r)
				_teil(r, _rotor_mesh(), _mat("rotor"), Vector3.ZERO)
				rotoren.append(r)
	if fertig:
		_teil(d, _box_mesh(Vector3(0.5, 0.1, 0.02)), _mat("streifen"), Vector3(0, 0.12, RUMPF.z * 0.5 + 0.02))
	if mit_paket:
		var p := _teil(d, _box_mesh(PAKET), _mat("paket"), Vector3(0, PAKET_Y, 0))
		p.name = "Paket"
		_teil(d, _box_mesh(Vector3(PAKET.x + 0.02, 0.08, 0.12)), _mat("band"), Vector3(0, PAKET_Y, 0))
	d.set_meta("rotoren", rotoren)
	return d


## Dreht die Rotoren einer Drohne aus bauen().
static func rotoren_drehen(d: Node3D, delta: float, faktor := 1.0) -> void:
	for r: Node3D in d.get_meta("rotoren", []):
		r.rotation.y += ROTOR_TEMPO * faktor * delta


## Paket ein- oder ausblenden (fuer Lieferungen).
static func paket_zeigen(d: Node3D, an: bool) -> void:
	for c in d.get_children():
		if c is MeshInstance3D and (c.name == "Paket" or (c as MeshInstance3D).position.y == PAKET_Y):
			c.visible = an
