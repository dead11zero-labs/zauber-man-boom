extends Control
## Minimap (HUD): kreisrunde Karte unten links, dreht sich mit der Blickrichtung des Spielers (oben = vorwaerts).
## Zeigt Bezirksfarben, Spieler, Gruppe "minimap_marker" (Iggy, Monster; Farbe per Meta "mm_farbe")
## und noch nicht eingesammelte Sammelobjekte. Taste M (oder Pad Back) blendet sie ein/aus.
## Exportiert: keine. Wird von hud.gd erzeugt.

const DURCHMESSER := 200.0
const WELT_RADIUS := 130.0   ## so viele Meter reichen vom Kartenmittelpunkt bis zum Rand
const ZELLE := 10.0          ## Pixelgroesse einer Bezirks-Zelle
const RAND_ABSTAND := 24.0
const CYAN := Color(0.1, 0.95, 1.0)
const GELB := Color(1.0, 0.85, 0.2)
const BEZIRK_FARBEN := {
	1: Color(0.10, 0.22, 0.38), 2: Color(0.36, 0.10, 0.36), 3: Color(0.08, 0.30, 0.30),
	4: Color(0.30, 0.28, 0.10), 5: Color(0.20, 0.10, 0.30), 6: Color(0.45, 0.10, 0.12),
}

var _spieler: Node3D


func _ready() -> void:
	set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	offset_left = RAND_ABSTAND
	offset_right = RAND_ABSTAND + DURCHMESSER
	offset_top = -RAND_ABSTAND - DURCHMESSER
	offset_bottom = -RAND_ABSTAND
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Im Touch-Betrieb liegt unten links der Lauf-Stick: Karte erst auf Knopfdruck (KARTE) zeigen
	visible = not Eingabe.ist_touch()
	Eingabe.geraet_geaendert.connect(func(g: int) -> void: visible = g != Eingabe.Geraet.TOUCH)


func _unhandled_input(event: InputEvent) -> void:
	# Aktion "minimap" (M, Pad Back, Touch-Knopf KARTE), angelegt in autoload/eingabe.gd
	if event.is_action_pressed("minimap") and not event.is_echo():
		visible = not visible


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


## Welt-Offset (Meter, x/z) in Kartenpixel relativ zur Mitte, gedreht mit dem Spieler.
func _zu_karte(offset: Vector2, yaw: float) -> Vector2:
	return offset.rotated(yaw) * (DURCHMESSER * 0.5 / WELT_RADIUS)


func _draw() -> void:
	if _spieler == null:
		_spieler = get_tree().get_first_node_in_group("spieler")
		if _spieler == null:
			return
	var mitte := Vector2(DURCHMESSER, DURCHMESSER) * 0.5
	var r := DURCHMESSER * 0.5
	var pos := Vector2(_spieler.global_position.x, _spieler.global_position.z)
	# Spieler blickt -z; Drehung so, dass Blickrichtung nach oben (-y) zeigt
	var vorn := Vector2(-_spieler.global_basis.z.x, -_spieler.global_basis.z.z)
	var yaw := Vector2.UP.angle() - vorn.angle()
	draw_circle(mitte, r, Color(0.02, 0.04, 0.08, 0.8))
	# Bezirks-Zellen (nur innerhalb des Kreises)
	var n := int(DURCHMESSER / ZELLE)
	for iy in n:
		for ix in n:
			var c := Vector2((ix + 0.5) * ZELLE, (iy + 0.5) * ZELLE)
			if c.distance_to(mitte) > r - 2.0:
				continue
			var welt := pos + ((c - mitte) * (WELT_RADIUS / r)).rotated(-yaw)
			var f: Color = BEZIRK_FARBEN.get(Bezirke.bezirk_an(welt.x, welt.y), BEZIRK_FARBEN[1])
			draw_rect(Rect2(c - Vector2.ONE * ZELLE * 0.5, Vector2.ONE * ZELLE), Color(f, 0.75))
	draw_arc(mitte, r - 1.0, 0.0, TAU, 64, CYAN, 2.0)
	# Sammelobjekte
	for n3 in get_tree().get_nodes_in_group("sammelobjekt"):
		_punkt(n3 as Node3D, pos, yaw, mitte, r, GELB, 3.0, false)
	for m in get_tree().get_nodes_in_group("minimap_marker"):
		var farbe: Color = m.get_meta("mm_farbe", Color.RED)
		_punkt(m as Node3D, pos, yaw, mitte, r, farbe, 5.0, true)
	# Spieler als Pfeil
	draw_colored_polygon(PackedVector2Array([mitte + Vector2(0, -8), mitte + Vector2(6, 7), mitte + Vector2(0, 3), mitte + Vector2(-6, 7)]), Color.WHITE)


func _punkt(k: Node3D, pos: Vector2, yaw: float, mitte: Vector2, r: float, farbe: Color, groesse: float, am_rand: bool) -> void:
	if k == null or not k.is_inside_tree():
		return
	var d := _zu_karte(Vector2(k.global_position.x, k.global_position.z) - pos, yaw)
	if d.length() > r - 6.0:
		if not am_rand:
			return
		d = d.normalized() * (r - 6.0)  # Ziele ausserhalb kleben am Rand
	draw_circle(mitte + d, groesse, farbe)
