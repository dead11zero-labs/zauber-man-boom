extends RefCounted
## Lader fuer "PixelDrift Metro Free" (Maciej EmacArt, CC BY 4.0, imported_models/pixeldrift_metro_free).
## Die Prefabs und .material-Dateien des Pakets verweisen auf res://Meshes/... und lassen sich in Godot 4.7.2 nicht
## laden, deshalb kommen hier die glTF-Teile direkt mit eigenen Materialien.
## Massstab: Viele Teile liegen im glTF in Zentimetern. Teile, deren groesste Kante unter ZENTIMETER_GRENZE liegt,
## bekommen ZENTIMETER_FAKTOR (Tuer dann knapp 3 m, Getraenkeautomat 1,9 m, Wandteil 10 x 8 m).
## Materialien: Pixel-Textur ohne Filter, kuehl getoent (Cyber-Look), beidseitig, ohne Eigenleuchten (mit
## Emissionstextur wirkte alles flach und fast weiss).
## Nutzung: `const MP := preload("res://levels/metro_paket.gd")`, `MP.laden("FPS_Wall_Main_01b")`.
## Keine Signale, keine Exporte.

const ORDNER := "res://imported_models/pixeldrift_metro_free/"
const PRAEFIX := "PAEA01_"
const ZENTIMETER_GRENZE := 0.5
const ZENTIMETER_FAKTOR := 100.0
const TEX_HAUPT := "Textures/PixelArt---EA01-Metro_Diff_clean.png"
const TEX_ZWEI := "Textures/PixelArt - EA01-Metro2_Diff.png"
const TOENUNG := Color(0.7, 0.76, 0.95)

static var _szenen: Dictionary = {}
static var _faktor: Dictionary = {}
static var _mats: Dictionary = {}


static func _material(datei: String) -> StandardMaterial3D:
	if _mats.has(datei):
		return _mats[datei]
	var m := StandardMaterial3D.new()
	var tex := load(ORDNER + datei) as Texture2D
	m.albedo_texture = tex
	m.albedo_color = TOENUNG
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.roughness = 0.7
	m.metallic = 0.2
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_ambient_light = true
	_mats[datei] = m
	return m


## Neue Instanz eines Teils (Name ohne Praefix und Endung, z. B. "FPS_Wall_Main_01b"), schon skaliert.
## Fehlt das Teil, kommt ein leeres Node3D.
static func laden(teil: String) -> Node3D:
	var pfad := ORDNER + "Meshes/" + PRAEFIX + teil + ".gltf"
	if not _szenen.has(pfad):
		_szenen[pfad] = load(pfad) if ResourceLoader.exists(pfad) else null
	var ps := _szenen[pfad] as PackedScene
	if ps == null:
		return Node3D.new()
	var n := ps.instantiate() as Node3D
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var orig := mi.mesh.surface_get_material(i)
			var zwei := orig != null and orig.resource_name.contains("Metro2")
			mi.set_surface_override_material(i, _material(TEX_ZWEI if zwei else TEX_HAUPT))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not _faktor.has(pfad):
		var box := huelle(n)
		_faktor[pfad] = ZENTIMETER_FAKTOR if maxf(box.size.x, maxf(box.size.y, box.size.z)) < ZENTIMETER_GRENZE else 1.0
	n.scale = Vector3.ONE * float(_faktor[pfad])
	return n


## Huelle aller Meshes eines Teils im Raum des Teils (ohne dessen eigene Skalierung).
static func huelle(n: Node3D) -> AABB:
	var box := AABB()
	var erst := true
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var t := Transform3D()
		var c: Node = mi
		while c != n:
			t = (c as Node3D).transform * t
			c = c.get_parent()
		var b := t * mi.get_aabb()
		box = b if erst else box.merge(b)
		erst = false
	return box
