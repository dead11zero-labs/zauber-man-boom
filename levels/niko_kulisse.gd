extends Node3D
## Fern-Kulisse: Der Cyber-Komplex "futuristic low poly city by niko" steht fest auf den Huegeln
## hinter der Ostgrenze (frueher schwebte er, das sah seltsam aus) und ist von der Stadt aus als Skyline zu sehen. Nicht betretbar, ohne Kollision,
## wirft keinen Schatten. Modell: imported_models/niko_stadt/niko_stadt.glb (aus der .blend-Datei exportiert,
## Materialien neu als Principled gesetzt). Wird von stadt.gd erzeugt. Keine Signale, keine Exporte.

const MODELL := "res://imported_models/niko_stadt/niko_stadt.glb"
const SKALA := 0.55
const MITTE_XZ := Vector2(455.0, -40.0)       ## Mitte des Fusses
const EINSINKEN := 3.0                        ## Meter, die der Fuss ins Gelaende ragt (kein Spalt am Hang)
const DREHUNG := 90.0                        ## Grad um y: Hauptseite zeigt zur Stadt
const LICHT_FARBE := Color(0.2, 0.9, 1.0)


func _ready() -> void:
	name = "NikoKulisse"
	if not ResourceLoader.exists(MODELL):
		return
	var n := (load(MODELL) as PackedScene).instantiate() as Node3D
	add_child(n)
	# Ausdehnung im Modellraum bestimmen und Unterkante/Mitte auf den Ursprung legen
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
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z)
	var huelle := Node3D.new()
	add_child(huelle)
	remove_child(n)
	huelle.add_child(n)
	huelle.scale = Vector3.ONE * SKALA
	huelle.rotation_degrees.y = DREHUNG
	position = Vector3(MITTE_XZ.x, TerrainForm.hoehe(MITTE_XZ.x, MITTE_XZ.y) - EINSINKEN, MITTE_XZ.y)
	# Schwaches Leuchten am Fuss
	var l := OmniLight3D.new()
	l.light_color = LICHT_FARBE
	l.light_energy = 2.0
	l.omni_range = 120.0
	l.position = Vector3(0, 6.0, 0)
	l.shadow_enabled = false
	add_child(l)
