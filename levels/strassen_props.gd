extends RefCounted
## Lader fuer die Strassen-Props (imported_models/strassen_props: Absperrung, Leitkegel, Ampel, Wasserpumpe).
## Die GLBs bringen ihre Teile mit Versatz aus der Quellszene mit; `laden` setzt den Ursprung auf Mitte unten
## und skaliert auf eine Zielhoehe in Metern. Keine Signale, keine Exporte.

const ORDNER := "res://imported_models/strassen_props/"
const NAMEN := {
	"absperrung": "barricade",
	"kegel": "trafficCone-v2",
	"ampel": "trafficLight-v2",
	"pumpe": "waterPump-v2",
}

static var _szenen: Dictionary = {}


## Neue Instanz von `art` (Schluessel aus NAMEN), Ursprung Mitte unten, auf `hoehe` Meter skaliert.
## Rueckgabe: Wurzelknoten; `masse` (Metadatum) = Ausdehnung nach der Skalierung.
static func laden(art: String, hoehe: float) -> Node3D:
	if not _szenen.has(art):
		_szenen[art] = load(ORDNER + NAMEN[art] + ".glb")
	var n := (_szenen[art] as PackedScene).instantiate() as Node3D
	var box := AABB()
	var erst := true
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var t := Transform3D()
		var c: Node3D = mi
		while c != null and c != n.get_parent():
			t = c.transform * t
			c = c.get_parent() as Node3D
		var b := t * mi.get_aabb()
		box = b if erst else box.merge(b)
		erst = false
	var f := hoehe / maxf(box.size.y, 0.001)
	var wurzel := Node3D.new()
	wurzel.add_child(n)
	n.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z)
	wurzel.scale = Vector3.ONE * f
	var aussen := Node3D.new()
	aussen.add_child(wurzel)
	aussen.set_meta("masse", box.size * f)
	return aussen
