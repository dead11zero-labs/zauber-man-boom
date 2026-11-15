extends RefCounted
## Lader fuer das Krankenhaus-Set (imported_models/krankenhaus): Die GLBs kommen ohne Texturen aus Blender,
## deshalb bekommt jedes Material hier seine PBR-Texturen (Albedo, Normal, Rauheit, Metall) nach Namen.
## Nutzung: `const KH := preload("res://levels/krankenhaus_modelle.gd")`, dann `KH.laden("Bed")`.
## Ursprung aller Teile: Mitte unten. Keine Signale, keine Exporte.

const ORDNER := "res://imported_models/krankenhaus/"
const TEXTUREN := ORDNER + "texturen/"

## Material-Name im GLB -> Textur-Unterordner
const MATERIAL_ORDNER := {
	"Bed": "bed",
	"Chairs_tables_1": "Chairs_table_1",
	"Walls_1": "Walls_1",
	"Doorway_1": "Doorway_1",
	"Floors_1": "Floors_1",
	"Ceiling_1": "ceiling_1",
	"Ceiling_light": "Ceiling_light",
	"Exit_sign": "exit_sign",
	"IV_bag": "Iv_bag",
	"IV_Pole": "Iv_pole",
	"Magazine": "Magazine",
	"Wheel_chair": "wheel_chair",
	"Door_mat": "Door_1",
}

## Teile, die selbst leuchten (Emissionsfarbe aus dem Albedo)
const LEUCHTET: Array[String] = ["Exit_sign", "Ceiling_light"]

static var _szenen: Dictionary = {}
static var _material: Dictionary = {}
static var _masse: Dictionary = {}


## Neue Instanz eines Teils (Dateiname ohne .glb) mit Texturen.
static func laden(teil: String) -> Node3D:
	if not _szenen.has(teil):
		_szenen[teil] = load(ORDNER + teil + ".glb")
	var n := (_szenen[teil] as PackedScene).instantiate() as Node3D
	_texturieren(n)
	return n


## Ausdehnung des Teils (Breite, Hoehe, Tiefe), Ursprung Mitte unten.
static func masse(teil: String) -> Vector3:
	if not _masse.has(teil):
		var n := laden(teil)
		var box := AABB()
		var erst := true
		for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
			var t := Transform3D()
			var c: Node3D = mi
			while c != n:
				t = c.transform * t
				c = c.get_parent() as Node3D
			var b := t * mi.get_aabb()
			box = b if erst else box.merge(b)
			erst = false
		n.free()
		_masse[teil] = box.size
	return _masse[teil]


## Mesh des Teils (erste Flaeche), z.B. fuer MultiMesh-Kacheln; das Material setzt der Aufrufer.
static func mesh(teil: String) -> Mesh:
	var n := laden(teil)
	var mi := n.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var ms := mi.mesh
	n.free()
	return ms


## PBR-Material fuer einen Material-Namen (zwischengespeichert). `kachel` > 0: dreiseitig projiziert
## (fuer grosse Flaechen), Kantenlaenge einer Kachel in Metern.
static func material(mat_name: String, kachel := 0.0, tint := Color.WHITE) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [mat_name, kachel, tint.to_html()]
	if _material.has(key):
		return _material[key]
	var ordner: String = MATERIAL_ORDNER.get(mat_name, "")
	if ordner == "":
		return null
	var pfad := TEXTUREN + ordner + "/"
	var s := StandardMaterial3D.new()
	s.albedo_color = tint
	s.roughness = 1.0
	s.metallic = 1.0 if mat_name == "Wheel_chair" else 0.0
	s.disable_ambient_light = true
	for datei in DirAccess.get_files_at(pfad):
		var ende := datei.get_basename().to_lower()
		if not (datei.ends_with(".jpg") or datei.ends_with(".png")):
			continue
		var tex := load(pfad + datei) as Texture2D
		if ende.ends_with("basecolor") or ende.ends_with("base_color"):
			s.albedo_texture = tex
		elif ende.ends_with("_normal"):
			s.normal_enabled = true
			s.normal_texture = tex
		elif ende.ends_with("roughness"):
			s.roughness_texture = tex
		elif ende.ends_with("metallic"):
			s.metallic_texture = tex
			s.metallic = 1.0
	if mat_name in LEUCHTET:
		s.emission_enabled = true
		s.emission_texture = s.albedo_texture
		s.emission_energy_multiplier = 1.2
	if kachel > 0.0:
		s.uv1_triplanar = true
		s.uv1_scale = Vector3.ONE / kachel
	_material[key] = s
	return s


## Setzt an allen Flaechen eines Teils das Textur-Material (nach Name im GLB); Phone/Pflanze/Fenster
## bekommen einfache Farben, weil ihre Texturen im Set fehlen.
static func _texturieren(wurzel: Node) -> void:
	for mi: MeshInstance3D in wurzel.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var vorher := mi.mesh.surface_get_material(i)
			var mname := vorher.resource_name if vorher != null else ""
			var neu := material(mname)
			if neu == null:
				neu = _ersatz(mname, vorher)
			if neu != null:
				mi.set_surface_override_material(i, neu)


static func _ersatz(mat_name: String, vorher: Material) -> Material:
	var key := "ersatz|" + mat_name
	if _material.has(key):
		return _material[key]
	var s := StandardMaterial3D.new()
	s.disable_ambient_light = true
	match mat_name:
		"Plant":
			s.albedo_color = Color(0.16, 0.42, 0.18)
			s.roughness = 0.8
		"Phone_ExitSign":
			s.albedo_color = Color(0.82, 0.83, 0.85)
			s.roughness = 0.4
		"Window":
			s.albedo_color = Color(0.6, 0.8, 0.9, 0.25)
			s.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			s.roughness = 0.05
		_:
			return vorher as Material
	_material[key] = s
	return s
