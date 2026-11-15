extends RefCounted
## Lader fuer das Modular SciFi MegaKit (Quaternius, CC0; imported_models/megakit, Kategorien Walls, Platforms,
## Props, Columns, Decals, Aliens). Die Teile haben ihren Ursprung im Raster (Boeden und Waende liegen auf
## einem 4-m-Gitter um den Ursprung), deshalb wird NICHTS verschoben. Alle Materialien bekommen
## `disable_ambient_light`: Der Untergrund wird nur von eigenen Lampen beleuchtet, nicht vom Himmel.
## Nutzung: `const MK := preload("res://levels/megakit.gd")`, `MK.laden("Walls", "WallAstra_Straight")`.
## Keine Signale, keine Exporte.

const ORDNER := "res://imported_models/megakit/"

static var _szenen: Dictionary = {}
static var _bearbeitet: Dictionary = {}


## Neue Instanz eines Teils (Kategorie-Ordner, Dateiname ohne .gltf). Fehlt das Teil, kommt ein leeres Node3D.
static func laden(kategorie: String, teil: String) -> Node3D:
	var pfad := ORDNER + kategorie + "/" + teil + ".gltf"
	if not _szenen.has(pfad):
		_szenen[pfad] = load(pfad) if ResourceLoader.exists(pfad) else null
	var ps := _szenen[pfad] as PackedScene
	if ps == null:
		return Node3D.new()
	var n := ps.instantiate() as Node3D
	_materialien(n)
	return n


## Schaltet das Himmels-Ambient an allen Materialien des Teils ab (einmal je Material).
static func _materialien(wurzel: Node) -> void:
	for mi: MeshInstance3D in wurzel.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i) as BaseMaterial3D
			if m != null and not _bearbeitet.has(m):
				m.disable_ambient_light = true
				_bearbeitet[m] = true
