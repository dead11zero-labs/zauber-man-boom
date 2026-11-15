extends Node3D
## Ignatio "Iggy" Inferno, das Chili-Wesen: Hauptgegner am Kern-Turm.
## Aktuell nur Platzhalter-Auftritt (Meilenstein 0): er rennt vor dem Turm im Kreis und kichert nicht.
## Kampf, Feuer und Milch-Schwaeche (siehe Notion-Charakterbogen) kommen mit Meilenstein 4 und 8.
## Exportierte Werte: Mitte, Radius, Tempo, Hoehe.

@export var mitte := Vector3(0, 0, -192)
@export var radius := 12.0
@export var tempo := 0.45          ## Winkelgeschwindigkeit in rad/s
@export var ziel_hoehe := 3.4      ## Iggy ist ein Boss: deutlich groesser als Zauber-Man

var _winkel := 0.0
var _modell: Node3D


func _ready() -> void:
	add_to_group("minimap_marker")
	set_meta("mm_farbe", Color(1.0, 0.35, 0.1))
	_modell = Node3D.new()
	add_child(_modell)
	var figur: Node3D = load("res://imported_models/iggy/iggy.fbx").instantiate()
	_modell.add_child(figur)
	# Auf Zielhoehe skalieren, Fuesse auf den Boden setzen
	var box := _huelle(figur)
	var s: float = ziel_hoehe / maxf(box.size.y, 0.01)
	figur.scale = Vector3.ONE * s
	figur.position.y = -box.position.y * s
	var ap := _animation_suchen(figur)
	if ap != null:
		var namen := ap.get_animation_list()
		if namen.size() > 0:
			var a := ap.get_animation(namen[namen.size() - 1])
			a.loop_mode = Animation.LOOP_LINEAR
			ap.play(namen[namen.size() - 1])
	var l := Label3D.new()
	l.text = "IGGY INFERNO"
	l.font_size = 48
	l.pixel_size = 0.012
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.shaded = false
	l.modulate = Color(1.0, 0.55, 0.15)
	l.outline_modulate = Color(0.3, 0.02, 0.0)
	l.outline_size = 12
	l.position = Vector3(0, ziel_hoehe + 0.8, 0)
	_modell.add_child(l)
	var licht := OmniLight3D.new()
	licht.light_color = Color(1.0, 0.45, 0.1)
	licht.light_energy = 2.0
	licht.omni_range = 14.0
	licht.position = Vector3(0, ziel_hoehe * 0.5, 0)
	_modell.add_child(licht)
	_winkel = randf() * TAU
	_platzieren()


func _process(delta: float) -> void:
	_winkel += tempo * delta
	_platzieren()


func _platzieren() -> void:
	position = mitte + Vector3(cos(_winkel) * radius, 0.0, sin(_winkel) * radius)
	# Blickrichtung = Laufrichtung (Gegenuhrzeigersinn)
	var richtung := Vector3(-sin(_winkel), 0.0, cos(_winkel))
	_modell.look_at(global_position + richtung, Vector3.UP)
	_modell.rotate_y(PI)


func _huelle(n: Node) -> AABB:
	var ergebnis := AABB()
	var erstes := true
	for mi in _meshes(n):
		var t := Transform3D.IDENTITY
		var k: Node = mi
		while k != null and k != n.get_parent():
			if k is Node3D:
				t = (k as Node3D).transform * t
			k = k.get_parent()
		var a := t * mi.get_aabb()
		if erstes:
			ergebnis = a
			erstes = false
		else:
			ergebnis = ergebnis.merge(a)
	return ergebnis


func _meshes(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_meshes(c))
	return out


func _animation_suchen(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _animation_suchen(c)
		if r != null:
			return r
	return null
