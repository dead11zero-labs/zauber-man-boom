extends RefCounted
## Lader fuer das Frosty-Cyber-Set (imported_models/frosty: Props und Kabel). Die Modelle bringen ihre Texturen mit;
## `laden` setzt den Ursprung auf Mitte unten (Massstab 1:1, die Teile sind schon in Metern).
## Nutzung: `const FP := preload("res://levels/frosty_props.gd")`, `FP.laden("props/Misc_Duckputer_A")`.
## Fehlt der Ordner (Lizenz unklar, nicht im Repo), liefert `laden` ein leeres Node3D. Keine Signale, keine Exporte.

const ORDNER := "res://imported_models/frosty/"

static var _szenen: Dictionary = {}


static func laden(teil: String) -> Node3D:
	var pfad := ORDNER + teil + ".glb"
	if not _szenen.has(teil):
		_szenen[teil] = load(pfad) if ResourceLoader.exists(pfad) else null
	var ps := _szenen[teil] as PackedScene
	var aussen := Node3D.new()
	if ps == null:
		return aussen
	var n := ps.instantiate() as Node3D
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
	n.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z)
	aussen.add_child(n)
	aussen.set_meta("masse", box.size)
	return aussen
