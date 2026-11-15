extends Node3D
## "Sy-Ci Burgers": neonbeleuchtetes Burger-Restaurant in der Kernstadt.
## Lokale Achsen: Front (Glasfassade, Terrasse) zeigt nach +z, Drive-In-Tunnel liegt rechts (+x).
## Innen begehbar: Rote Sitzecken, Theke mit Roboter-Kassierer, Galerie mit Treppe, Lego-Spielecke.
## Minispiel: Wer in Reichweite des Bedienroboters "interagieren" drueckt, startet den Burger-Bau (ui/burger_minispiel.gd).

const B := 40.0        ## Breite (x)
const T := 30.0        ## Tiefe (z)
const H := 9.0         ## Hoehe
const GALERIE_Y := 4.6
const STUFEN_PLATTE := 0.1         ## Dicke einer Trittplatte
const GELAENDER_H := 1.05          ## Treppengelaender: Hoehe ueber der Stufenlinie
const GELAENDER_PFOSTEN_JE := 4    ## ein Pfosten alle n Stufen
const STUFEN_LED := 0.04           ## Breite des Leuchtstreifens an der Stufenkante
const STEVE := preload("res://characters/steve.gd")
const STEVE_SITZ_Y := 0.18  ## Feinjustierung: Hoehe der Sitzflaeche ueber dem Boden
const MINISPIEL := preload("res://ui/burger_minispiel.gd")
const ROBOTER_REICHWEITE := 5.5   ## Meter (waagerecht) bis der Hinweis erscheint
const ROBOTER_HINWEIS_HOEHE := 3.6
const ROBOTER_HINWEIS_PIXEL := 0.012

var zeit := 0.0
var burger: Node3D
var ring: Node3D
var m: Dictionary = {}
var _roboter_knoten: Node3D
var _roboter_hinweis: Label3D
var _spieler: Node3D


func _ready() -> void:
	_materialien()
	_hauptbau()
	_schild()
	_dach_burger()
	_innen()
	_terrasse()
	_drive_in()
	_licht_an()


func _process(delta: float) -> void:
	zeit += delta
	if burger != null:
		burger.rotation.y += delta * 0.5
		burger.position.y = H + 6.2 + sin(zeit * 1.4) * 0.35
	if ring != null:
		ring.rotation.y -= delta * 1.6
	_roboter_pruefen()


func _unhandled_input(event: InputEvent) -> void:
	if _roboter_nah() and event.is_action_pressed("interagieren") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_minispiel_starten()


func _roboter_nah() -> bool:
	if _roboter_knoten == null or Dialog.aktiv or get_tree().get_nodes_in_group("burger_minispiel").size() > 0:
		return false
	if _spieler == null or not is_instance_valid(_spieler):
		_spieler = get_tree().get_first_node_in_group("spieler") as Node3D
		return false
	var d := _spieler.global_position - _roboter_knoten.global_position
	return Vector2(d.x, d.z).length() <= ROBOTER_REICHWEITE and absf(d.y) < ROBOTER_HINWEIS_HOEHE


func _roboter_pruefen() -> void:
	if _roboter_hinweis != null:
		_roboter_hinweis.visible = _roboter_nah()


func _minispiel_starten() -> void:
	var spiel := CanvasLayer.new()
	spiel.set_script(MINISPIEL)
	get_tree().current_scene.add_child(spiel)


# ---------------------------------------------------------------- Helfer

func _std(c: Color, emission := 0.0, metall := 0.0, rauh := 0.6) -> StandardMaterial3D:
	var s := StandardMaterial3D.new()
	s.albedo_color = c
	s.metallic = metall
	s.roughness = rauh
	if emission > 0.0:
		s.emission_enabled = true
		s.emission = c
		s.emission_energy_multiplier = emission
	return s


func _materialien() -> void:
	m["chrom"] = _std(Color(0.55, 0.58, 0.68), 0.0, 0.9, 0.25)
	m["dunkel"] = _std(Color(0.12, 0.12, 0.2), 0.0, 0.7, 0.35)
	m["boden"] = _std(Color(0.2, 0.2, 0.3), 0.0, 0.6, 0.25)
	m["wand"] = _std(Color(0.28, 0.2, 0.3), 0.0, 0.4, 0.5)
	m["cyan"] = _std(Color(0.2, 0.9, 1.0), 3.5)
	m["blau"] = _std(Color(0.2, 0.4, 1.0), 3.5)
	m["lila"] = _std(Color(0.8, 0.25, 1.0), 3.5)
	m["gelb"] = _std(Color(1.0, 0.8, 0.15), 3.0)
	m["orange"] = _std(Color(1.0, 0.5, 0.1), 3.0)
	m["rot"] = _std(Color(0.8, 0.08, 0.1), 0.0, 0.2, 0.3)
	m["rotneon"] = _std(Color(1.0, 0.15, 0.1), 3.0)
	m["gruen"] = _std(Color(0.2, 0.7, 0.2), 0.3)
	m["weiss"] = _std(Color(0.9, 0.92, 1.0), 0.0, 0.3, 0.4)
	var glas := _std(Color(0.5, 0.75, 1.0, 0.22), 0.0, 0.0, 0.05)
	glas.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m["glas"] = glas
	m["brot"] = _std(Color(0.9, 0.55, 0.18), 0.4, 0.0, 0.5)
	m["fleisch"] = _std(Color(0.28, 0.13, 0.07), 0.0, 0.0, 0.7)
	m["kaese"] = _std(Color(1.0, 0.75, 0.1), 0.6)
	m["salat"] = _std(Color(0.3, 0.8, 0.15), 0.4)
	m["tomate"] = _std(Color(0.9, 0.2, 0.12), 0.4)
	m["blatt"] = _std(Color(0.12, 0.35, 0.12), 0.0, 0.0, 0.8)
	m["haut"] = _std(Color(1.0, 0.8, 0.45), 0.0, 0.0, 0.6)
	# Echte Texturen (Poly Haven, CC0): dreiseitig projiziert, Kachelgroesse in Metern
	m["boden"] = _tex("floor_tiles_06", 2.4, Color(0.85, 0.88, 1.0), 0.1)
	m["wand"] = _tex("metal_plate", 3.0, Color(0.55, 0.42, 0.65), 0.7)
	m["chrom"] = _tex("metal_plate", 2.0, Color(0.85, 0.88, 1.0), 0.9)
	m["leder"] = _tex("leather_red_02", 1.2, Color(1.0, 0.75, 0.75), 0.0)
	m["holz"] = _tex("wood_table_001", 1.6, Color(1.0, 0.9, 0.8), 0.0)
	m["marmor"] = _tex("marble_01", 3.0, Color(0.9, 0.95, 1.0), 0.0)
	m["terrasse"] = _tex("square_tiles_02", 2.5, Color(0.8, 0.82, 0.95), 0.0)
	m["gummi"] = _tex("rubber_tiles", 1.6, Color(0.5, 0.6, 1.0), 0.0)
	m["dach"] = _tex("metal_plate", 2.5, Color(0.7, 0.72, 0.85), 0.8)


func _tex(ordner: String, kachel: float, tint: Color, metall: float) -> StandardMaterial3D:
	var pfad := "res://assets/texturen/%s/" % ordner
	var t := StandardMaterial3D.new()
	t.albedo_texture = load(pfad + "diff.jpg")
	t.albedo_color = tint
	t.normal_enabled = true
	t.normal_texture = load(pfad + "nor.jpg")
	t.roughness_texture = load(pfad + "rough.jpg")
	t.roughness = 1.0
	t.metallic = metall
	t.uv1_triplanar = true
	t.uv1_scale = Vector3.ONE / kachel
	return t


func _kol(parent: Node3D, g: Vector3) -> void:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = g
	cs.shape = sh
	sb.add_child(cs)
	parent.add_child(sb)


func _box(pos: Vector3, g: Vector3, mat: Material, kol := true, eltern: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = g
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	(eltern if eltern != null else self).add_child(mi)
	if kol:
		_kol(mi, g)
	return mi


func _zyl(pos: Vector3, r: float, h: float, mat: Material, oben := -1.0, seg := 24, kol := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.bottom_radius = r
	cm.top_radius = r if oben < 0.0 else oben
	cm.height = h
	cm.radial_segments = seg
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	if kol:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = r
		sh.height = h
		cs.shape = sh
		sb.add_child(cs)
		mi.add_child(sb)
	return mi


func _kugel(pos: Vector3, r: float, mat: Material, flach := 1.0, eltern: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	mi.scale = Vector3(1, flach, 1)
	(eltern if eltern != null else self).add_child(mi)
	return mi


func _text(txt: String, pos: Vector3, farbe: Color, pixel: float, drehung := 0.0, fett := 14) -> Label3D:
	var l := Label3D.new()
	l.text = txt
	l.font_size = 64
	l.pixel_size = pixel
	l.outline_size = fett
	l.outline_modulate = farbe.darkened(0.75)
	l.modulate = Color(farbe.r * 1.4, farbe.g * 1.4, farbe.b * 1.4)
	l.shaded = false
	l.position = pos
	l.rotation_degrees.y = drehung
	add_child(l)
	return l


func _licht(pos: Vector3, farbe: Color, energie: float, reichweite: float) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = farbe
	l.light_energy = energie
	l.omni_range = reichweite
	add_child(l)


# ---------------------------------------------------------------- Gebaeude

func _hauptbau() -> void:
	# Boden innen und Plattform
	_box(Vector3(0, 0.15, 0), Vector3(B, 0.3, T), m["boden"])
	for i in 6:
		_box(Vector3(-17.0 + i * 6.8, 0.32, 0), Vector3(0.25, 0.04, T - 1.0), m["cyan"], false)
	# Wandsockel und Glas
	_box(Vector3(0, H - 1.0, 0), Vector3(B + 2.0, 2.0, T + 2.0), m["dunkel"], false)  # Dach-Kragen
	_box(Vector3(0, H + 0.1, 0), Vector3(B + 3.0, 0.5, T + 3.0), m["dach"])          # Dach
	# Rueckwand
	_box(Vector3(0, H * 0.5, -T * 0.5), Vector3(B, H, 0.8), m["wand"])
	# Seitenwaende: Sockel + Glas + Sturz
	for sx in [-1.0, 1.0]:
		_box(Vector3(sx * B * 0.5, 0.7, 0), Vector3(0.8, 1.0, T), m["dunkel"])
		var gl := _box(Vector3(sx * B * 0.5, 4.2, 0), Vector3(0.3, 5.0, T), m["glas"], false)
		gl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_kol_glas(Vector3(sx * B * 0.5, 4.2, 0), Vector3(0.5, 5.0, T))
	# Front: Sockel, Glas mit Tuerluecke, Sturz mit Neonrahmen
	for sx in [-1.0, 1.0]:
		var breite := B * 0.5 - 3.0
		_box(Vector3(sx * (3.0 + breite * 0.5), 0.7, T * 0.5), Vector3(breite, 1.0, 0.8), m["dunkel"])
		var gl := _box(Vector3(sx * (3.0 + breite * 0.5), 4.2, T * 0.5), Vector3(breite, 5.0, 0.3), m["glas"], false)
		gl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_kol_glas(Vector3(sx * (3.0 + breite * 0.5), 4.2, T * 0.5), Vector3(breite, 5.0, 0.5))
	_box(Vector3(0, 7.9, T * 0.5), Vector3(B, 2.2, 0.9), m["dach"], false)
	# Tuerpfosten mit Neon
	for sx in [-3.0, 3.0]:
		_box(Vector3(sx, 3.2, T * 0.5 + 0.1), Vector3(0.3, 6.4, 0.5), m["blau"], false)
	# Neon-Randstreifen um Dach und Fassade
	for z in [T * 0.5 + 1.55, -T * 0.5 - 1.55]:
		_box(Vector3(0, H + 0.45, z), Vector3(B + 3.0, 0.25, 0.25), m["cyan"], false)
	for x in [B * 0.5 + 1.55, -B * 0.5 - 1.55]:
		_box(Vector3(x, H + 0.45, 0), Vector3(0.25, 0.25, T + 3.0), m["lila"], false)
	_box(Vector3(0, 1.15, T * 0.5 + 0.45), Vector3(B, 0.2, 0.2), m["blau"], false)
	_box(Vector3(0, 7.0, T * 0.5 + 0.5), Vector3(B, 0.2, 0.2), m["lila"], false)


func _kol_glas(pos: Vector3, g: Vector3) -> void:
	var n := Node3D.new()
	n.position = pos
	add_child(n)
	_kol(n, g)


func _schild() -> void:
	# Grosses Neonschild ueber der Front und an den Seiten
	var vorn := T * 0.5 + 1.2
	_text("Sy-Ci", Vector3(-5.5, 7.9, vorn), Color(0.2, 0.65, 1.0), 0.04, 0.0, 18)
	_text("Burgers", Vector3(6.5, 7.9, vorn), Color(1.0, 0.8, 0.1), 0.04, 0.0, 18)
	# Burger-Icon links im Schild
	var ico := Node3D.new()
	ico.position = Vector3(-16.5, 7.9, vorn + 0.1)
	add_child(ico)
	_kugel(Vector3(0, 0.5, 0), 1.6, m["orange"], 0.55, ico)
	_box(Vector3(0, 0.0, 0), Vector3(3.2, 0.3, 0.4), m["gelb"], false, ico)
	_box(Vector3(0, -0.4, 0), Vector3(3.2, 0.3, 0.4), m["rotneon"], false, ico)
	_box(Vector3(0, -0.8, 0), Vector3(3.2, 0.4, 0.4), m["orange"], false, ico)
	_text("Sy-Ci Burgers", Vector3(B * 0.5 + 1.2, 7.9, 0), Color(1.0, 0.8, 0.1), 0.04, 90.0, 16)
	_text("Sy-Ci Burgers", Vector3(-B * 0.5 - 1.2, 7.9, 0), Color(0.2, 0.65, 1.0), 0.04, -90.0, 16)
	_text("OFFEN 24/7  -  SYNTH-CITY", Vector3(0, 6.2, vorn + 0.3), Color(0.3, 1.0, 1.0), 0.016, 0.0, 8)


func _dach_burger() -> void:
	burger = Node3D.new()
	burger.position = Vector3(0, H + 6.2, 0)
	add_child(burger)
	_zyl(Vector3(0, -2.6, 0), 5.0, 1.0, m["brot"], 4.4, 28).reparent(burger, false)
	var teile: Array = [
		[m["fleisch"], 0.0, 5.3, 1.1, 5.3], [m["kaese"], 0.9, 5.6, 0.3, 5.6], [m["salat"], 1.4, 5.8, 0.4, 5.8],
		[m["tomate"], 2.0, 5.3, 0.5, 5.3],
	]
	var y := -1.6
	for t in teile:
		var z := _zyl(Vector3(0, y, 0), t[2], t[3], t[0], -1.0, 28)
		z.reparent(burger, false)
		y += t[3] + 0.2
	var deckel := _kugel(Vector3(0, y - 0.2, 0), 5.3, m["brot"], 0.62, burger)
	for i in 14:
		var a := i * 2.4
		var k := _kugel(Vector3(cos(a) * 2.8 * (0.4 + (i % 4) * 0.2), y + 3.0 - (i % 4) * 0.3, sin(a) * 2.8 * (0.4 + (i % 4) * 0.2)), 0.22, m["haut"], 0.6, burger)
		k.scale = Vector3(1.4, 0.5, 0.8)
		k.rotation.y = a
	# Neonring um den Burger
	ring = Node3D.new()
	ring.position = Vector3(0, H + 6.2, 0)
	add_child(ring)
	var tm := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 8.2
	torus.outer_radius = 8.6
	tm.mesh = torus
	tm.material_override = m["gelb"]
	tm.rotation_degrees = Vector3(0, 0, 14)
	ring.add_child(tm)
	_licht(Vector3(0, H + 8.0, 0), Color(1.0, 0.7, 0.3), 3.5, 36.0)


# ---------------------------------------------------------------- Innenraum

func _innen() -> void:
	# Theke an der Rueckwand: Marmorplatte, Metallfront, Roboter-Kassierer, Kassen
	_box(Vector3(-9.5, 0.65, -9.0), Vector3(20.0, 1.0, 1.8), m["chrom"])
	_box(Vector3(-9.5, 1.2, -9.0), Vector3(20.4, 0.14, 2.2), m["marmor"], false)
	_box(Vector3(-9.5, 0.4, -8.1), Vector3(20.0, 0.2, 0.15), m["gelb"], false)
	for kx in [-15.0, -9.0, -3.0]:
		_box(Vector3(kx, 1.55, -9.2), Vector3(0.7, 0.55, 0.5), m["dunkel"], false)
		_box(Vector3(kx, 1.62, -8.93), Vector3(0.55, 0.35, 0.03), m["cyan"], false)
		_box(Vector3(kx + 1.4, 1.35, -8.6), Vector3(0.5, 0.25, 0.4), m["gelb"], false)
	_roboter(Vector3(-9.0, 0.3, -11.0))
	# Heissluft-Grill hinter der Theke
	_box(Vector3(-15.0, 1.0, -13.6), Vector3(4.0, 1.4, 1.2), m["chrom"], false)
	_box(Vector3(-15.0, 1.75, -13.6), Vector3(3.4, 0.2, 1.0), m["rotneon"], false)
	_box(Vector3(-4.0, 1.0, -13.6), Vector3(4.0, 1.4, 1.2), m["chrom"], false)
	_box(Vector3(-4.0, 1.75, -13.6), Vector3(3.4, 0.2, 1.0), m["orange"], false)
	# Menue-Tafeln mit Mini-Burgern, Pommes und Getraenk
	for i in 4:
		var x := -17.0 + i * 5.5
		_box(Vector3(x, 5.2, -T * 0.5 + 0.5), Vector3(4.6, 2.8, 0.2), m["dunkel"], false)
		var farben := [m["orange"], m["gelb"], m["rotneon"], m["cyan"]]
		_box(Vector3(x, 5.2, -T * 0.5 + 0.65), Vector3(4.3, 2.5, 0.05), farben[i], false)
		var namen := ["CLASSIC 4.99", "NEO-CHEESE 5.99", "POMMES 2.49", "ZAUBER-SHAKE 3.49"]
		_text(namen[i], Vector3(x, 4.4, -T * 0.5 + 0.75), Color(0.05, 0.05, 0.1), 0.012, 0.0, 0)
		_mini_burger(Vector3(x, 5.6, -T * 0.5 + 0.72), i)
	_text("Sy-Ci Burgers", Vector3(9.0, 6.0, -T * 0.5 + 0.7), Color(1.0, 0.8, 0.1), 0.05, 0.0, 16)
	# Neon-Burger an der Rueckwand (Hauptbild)
	_neon_burger_wand(Vector3(10.0, 3.2, -T * 0.5 + 0.55))
	# Sitzecken entlang der linken Seite (Leder, Metalltisch, Tablet)
	for i in 3:
		_sitzecke(Vector3(-17.0, 0.3, -4.0 + i * 8.0), 90.0, i)
	# Freistehende Tische mit Hockern
	for p in [Vector2(-9.0, 6.0), Vector2(-2.0, 2.0), Vector2(-9.0, -3.0)]:
		_tisch(Vector3(p.x, 0.3, p.y))
	_steve()
	# Galerie rechts hinten mit Glas-Gelaender (von der Treppe aus betretbar)
	_box(Vector3(10.25, GALERIE_Y - 0.2, -8.0), Vector3(19.5, 0.4, 12.0), m["boden"])
	_box(Vector3(11.7, GALERIE_Y - 0.5, -2.0), Vector3(16.6, 0.12, 0.25), m["blau"], false)
	var gel := _box(Vector3(11.7, GALERIE_Y + 0.55, -2.0), Vector3(16.6, 1.1, 0.12), m["glas"], false)
	gel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_box(Vector3(11.7, GALERIE_Y + 1.15, -2.0), Vector3(16.6, 0.12, 0.2), m["cyan"], false)
	_kol_glas(Vector3(11.7, GALERIE_Y + 0.6, -2.0), Vector3(16.6, 1.2, 0.2))
	var gel2 := _box(Vector3(0.5, GALERIE_Y + 0.55, -8.0), Vector3(0.12, 1.1, 12.0), m["glas"], false)
	gel2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_box(Vector3(0.5, GALERIE_Y + 1.15, -8.0), Vector3(0.2, 0.12, 12.0), m["cyan"], false)
	_kol_glas(Vector3(0.5, GALERIE_Y + 0.6, -8.0), Vector3(0.2, 1.2, 12.0))
	for x in [4.0, 10.0, 16.0]:
		_zyl(Vector3(x, GALERIE_Y * 0.5 - 0.3, -2.0), 0.25, GALERIE_Y - 0.4, m["chrom"], -1.0, 8)
	for i in 2:
		_sitzecke(Vector3(18.0, GALERIE_Y, -10.0 + i * 5.0), -90.0, i + 1)
	_tisch(Vector3(10.0, GALERIE_Y, -8.0))
	_treppe()
	_spielecke()
	# Deko: Pflanzen, Poster, Haengelampen, Deckenring
	for p in [Vector3(-18.5, 0.3, 12.5), Vector3(18.5, 0.3, 12.5), Vector3(-18.5, 0.3, -12.5), Vector3(5.0, 0.3, 12.5), Vector3(-5.0, 0.3, 12.5), Vector3(18.5, GALERIE_Y, -13.0)]:
		_pflanze(p)
	_poster(Vector3(-T * 0.5 - 5.0, 4.6, -19.6), 90.0)
	_poster_held(Vector3(-19.55, 5.0, 4.0))
	for p in [Vector2(-9.0, 6.0), Vector2(-2.0, 2.0), Vector2(-9.0, -3.0), Vector2(-7.0, 11.0)]:
		_haengelampe(Vector3(p.x, H - 0.2, p.y))
	var ringl := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 3.6
	tor.outer_radius = 4.0
	ringl.mesh = tor
	ringl.material_override = m["orange"]
	ringl.position = Vector3(0, H - 0.5, 4.0)
	add_child(ringl)
	var ringl2 := MeshInstance3D.new()
	var tor2 := TorusMesh.new()
	tor2.inner_radius = 2.6
	tor2.outer_radius = 2.8
	ringl2.mesh = tor2
	ringl2.material_override = m["cyan"]
	ringl2.position = Vector3(0, H - 0.5, 4.0)
	add_child(ringl2)
	# Decken-Neon
	for z in [-8.0, 8.0]:
		_box(Vector3(0, H - 0.15, z), Vector3(B - 3.0, 0.1, 0.3), m["gelb"], false)
	_box(Vector3(0, H - 0.2, 0), Vector3(0.3, 0.1, T - 2.0), m["blau"], false)
	# Dachaufbauten
	_dach_technik()


func _roboter(pos: Vector3) -> void:
	var r := Node3D.new()
	r.position = pos
	add_child(r)
	_roboter_knoten = r
	_roboter_hinweis = _text("E: BURGER-BAU", pos + Vector3(0, ROBOTER_HINWEIS_HOEHE, 0.6), Color(1.0, 0.85, 0.3), ROBOTER_HINWEIS_PIXEL)
	Eingabe.hinweis_binden(_roboter_hinweis, "interagieren", "%s: BURGER-BAU")
	_roboter_hinweis.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_roboter_hinweis.no_depth_test = true
	_roboter_hinweis.visible = false
	_box(Vector3(0, 0.9, 0), Vector3(0.9, 1.3, 0.6), m["weiss"], false, r)
	_box(Vector3(0, 1.2, 0.32), Vector3(0.5, 0.5, 0.05), m["blau"], false, r)
	_kugel(Vector3(0, 2.0, 0), 0.55, m["weiss"], 1.0, r)
	_box(Vector3(0, 2.0, 0.42), Vector3(0.7, 0.28, 0.2), m["dunkel"], false, r)
	_box(Vector3(-0.17, 2.02, 0.54), Vector3(0.12, 0.1, 0.05), m["cyan"], false, r)
	_box(Vector3(0.17, 2.02, 0.54), Vector3(0.12, 0.1, 0.05), m["cyan"], false, r)
	var kappe := _zyl(Vector3(0, 2.7, 0), 0.5, 0.25, m["weiss"], 0.4, 12)
	kappe.reparent(r, false)
	_box(Vector3(0.65, 1.2, 0.2), Vector3(0.18, 0.9, 0.18), m["weiss"], false, r)
	_box(Vector3(-0.65, 1.2, 0.2), Vector3(0.18, 0.9, 0.18), m["weiss"], false, r)
	_kugel(Vector3(0.65, 0.7, 0.2), 0.14, m["weiss"], 1.0, r)
	_kugel(Vector3(-0.65, 0.7, 0.2), 0.14, m["weiss"], 1.0, r)
	_box(Vector3(0, 2.55, 0), Vector3(0.05, 0.4, 0.05), m["chrom"], false, r)
	_kugel(Vector3(0, 2.8, 0), 0.08, m["rotneon"], 1.0, r)


func _sitzecke(pos: Vector3, drehung: float, nr := 0) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = drehung
	add_child(n)
	# lokal: Tisch in der Mitte, Sitzbank hinten (-z) und vorn (+z)
	_box(Vector3(0, 0.45, -2.0), Vector3(5.0, 0.9, 1.0), m["leder"], true, n)
	_box(Vector3(0, 1.3, -2.55), Vector3(5.0, 1.3, 0.35), m["leder"], false, n)
	_box(Vector3(0, 0.45, 2.0), Vector3(5.0, 0.9, 1.0), m["leder"], true, n)
	_box(Vector3(0, 1.3, 2.55), Vector3(5.0, 1.3, 0.35), m["leder"], false, n)
	# Naht-Streifen im Polster
	for x in [-1.25, 1.25]:
		_box(Vector3(x, 1.3, -2.36), Vector3(0.04, 1.2, 0.02), m["dunkel"], false, n)
		_box(Vector3(x, 1.3, 2.36), Vector3(0.04, 1.2, 0.02), m["dunkel"], false, n)
	var fuss := _zyl(Vector3(0, 0.4, 0), 0.18, 0.8, m["chrom"], -1.0, 10)
	fuss.reparent(n, false)
	_box(Vector3(0, 0.82, 0), Vector3(2.6, 0.1, 1.6), m["chrom"], true, n)
	_box(Vector3(0, 0.88, 0), Vector3(2.6, 0.02, 0.06), m["cyan"], false, n)
	# Tablet mit Burger-Bild, Tablett mit Burger und Pommes
	_box(Vector3(0, 1.12, -0.1), Vector3(0.6, 0.55, 0.06), m["dunkel"], false, n)
	_box(Vector3(0, 1.15, -0.06), Vector3(0.5, 0.4, 0.02), m["orange"], false, n)
	_box(Vector3(-0.8, 0.9, 0.2), Vector3(0.8, 0.04, 0.55), m["gelb"], false, n)
	_kugel(Vector3(-0.8, 1.0, 0.2), 0.17, m["brot"], 0.6, n)
	_box(Vector3(0.7, 1.0, 0.25), Vector3(0.16, 0.32, 0.12), m["rotneon"], false, n)
	for k in 4:
		_box(Vector3(0.7 + (k - 1.5) * 0.03, 1.22, 0.25), Vector3(0.025, 0.2, 0.025), m["gelb"], false, n)
	# Gaeste
	var farben := [Color(0.2, 0.3, 0.85), Color(0.9, 0.3, 0.5), Color(0.2, 0.75, 0.55), Color(0.95, 0.6, 0.15)]
	_figur(Vector3(-1.2, 0.9, -2.0), farben[nr % 4], true, 0.0, n)
	_figur(Vector3(1.0, 0.9, 2.0), farben[(nr + 2) % 4], true, 180.0, n)


## Steve: sitzt auf einem Hocker am Tisch bei (-2, 2), isst einen Burger und trinkt ab und zu (characters/steve.gd).
func _steve() -> void:
	var tisch := Vector3(-2.0, 0.3, 2.0)
	var winkel := 0.6  # entspricht dem ersten Hocker in _tisch()
	var hocker := tisch + Vector3(cos(winkel), 0.0, sin(winkel)) * 2.0
	var steve: Node3D = STEVE.new()
	steve.name = "Steve"
	add_child(steve)
	steve.position = hocker + Vector3(0, STEVE_SITZ_Y, 0)
	var zum_tisch := tisch - hocker
	steve.rotation.y = atan2(zum_tisch.x, zum_tisch.z)  # Modell schaut nach +z


func _tisch(pos: Vector3) -> void:
	_zyl(pos + Vector3(0, 0.45, 0), 0.2, 0.9, m["chrom"], -1.0, 10)
	_zyl(pos + Vector3(0, 0.95, 0), 1.4, 0.12, m["holz"], -1.0, 24, true)
	_zyl(pos + Vector3(0, 0.9, 0), 1.45, 0.06, m["chrom"], -1.0, 24)
	_box(pos + Vector3(0, 1.03, 0), Vector3(0.5, 0.04, 0.4), m["cyan"], false)
	_box(pos + Vector3(0.7, 1.12, 0.3), Vector3(0.5, 0.18, 0.05), m["dunkel"], false)
	var farben := [m["gelb"], m["lila"], m["orange"]]
	for i in 3:
		var a := i * TAU / 3.0 + 0.6
		var hocker := _zyl(pos + Vector3(cos(a) * 2.0, 0.3, sin(a) * 2.0), 0.5, 0.6, farben[i], -1.0, 14, true)
		_zyl(pos + Vector3(cos(a) * 2.0, 0.62, sin(a) * 2.0), 0.52, 0.08, m["leder"], -1.0, 14)


## Lego-aehnliche Minifigur (zylindrischer Kopf mit Noppe, Torso, Arme, Beine).
func _figur(pos: Vector3, farbe: Color, sitzt: bool, drehung: float, eltern: Node3D = null) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = drehung
	(eltern if eltern != null else self).add_child(n)
	var kleid := _std(farbe, 0.15, 0.0, 0.5)
	var hose := _std(farbe.darkened(0.45), 0.0, 0.0, 0.6)
	var hoehe := 0.0 if not sitzt else 0.0
	_box(Vector3(0, 0.55, 0), Vector3(0.52, 0.55, 0.3), kleid, false, n)
	_box(Vector3(-0.34, 0.55, 0.05), Vector3(0.14, 0.5, 0.16), kleid, false, n)
	_box(Vector3(0.34, 0.55, 0.05), Vector3(0.14, 0.5, 0.16), kleid, false, n)
	_kugel(Vector3(-0.34, 0.28, 0.12), 0.08, m["haut"], 1.0, n)
	_kugel(Vector3(0.34, 0.28, 0.12), 0.08, m["haut"], 1.0, n)
	_box(Vector3(0, 0.2, 0), Vector3(0.52, 0.22, 0.3), hose, false, n)
	if sitzt:
		_box(Vector3(-0.13, 0.12, 0.3), Vector3(0.2, 0.2, 0.5), hose, false, n)
		_box(Vector3(0.13, 0.12, 0.3), Vector3(0.2, 0.2, 0.5), hose, false, n)
	else:
		_box(Vector3(-0.13, -0.15, 0), Vector3(0.22, 0.5, 0.26), hose, false, n)
		_box(Vector3(0.13, -0.15, 0), Vector3(0.22, 0.5, 0.26), hose, false, n)
	var kopf := _zyl(Vector3(0, 1.05, 0), 0.26, 0.36, m["haut"], -1.0, 16)
	kopf.reparent(n, false)
	var stud := _zyl(Vector3(0, 1.28, 0), 0.1, 0.08, m["haut"], -1.0, 10)
	stud.reparent(n, false)
	_box(Vector3(-0.09, 1.08, 0.25), Vector3(0.05, 0.07, 0.02), m["dunkel"], false, n)
	_box(Vector3(0.09, 1.08, 0.25), Vector3(0.05, 0.07, 0.02), m["dunkel"], false, n)
	_box(Vector3(0, 0.97, 0.25), Vector3(0.14, 0.03, 0.02), m["dunkel"], false, n)
	_box(Vector3(0, 1.25, -0.03), Vector3(0.5, 0.1, 0.5), _std(farbe.darkened(0.7), 0.0, 0.0, 0.9), false, n)


func _mini_burger(pos: Vector3, art: int) -> void:
	var n := Node3D.new()
	n.position = pos
	add_child(n)
	if art == 2:
		# Pommes im Karton
		_box(Vector3(0, -0.35, 0), Vector3(0.7, 0.5, 0.05), m["rotneon"], false, n)
		for k in 6:
			_box(Vector3((k - 2.5) * 0.1, 0.0, 0), Vector3(0.07, 0.6, 0.04), m["gelb"], false, n)
	elif art == 3:
		_box(Vector3(0, -0.2, 0), Vector3(0.6, 1.0, 0.05), m["weiss"], false, n)
		_box(Vector3(0, 0.45, 0), Vector3(0.7, 0.12, 0.05), m["rotneon"], false, n)
		_box(Vector3(0.1, 0.8, 0), Vector3(0.06, 0.5, 0.04), m["rotneon"], false, n)
	else:
		_kugel(Vector3(0, 0.3, 0), 0.5, m["brot"], 0.55, n)
		_box(Vector3(0, 0.05, 0), Vector3(1.0, 0.1, 0.05), m["salat"], false, n)
		_box(Vector3(0, -0.07, 0), Vector3(0.95, 0.12, 0.05), m["fleisch"], false, n)
		_box(Vector3(0, -0.2, 0), Vector3(1.0, 0.07, 0.05), m["kaese"], false, n)
		_box(Vector3(0, -0.34, 0), Vector3(1.0, 0.14, 0.05), m["brot"], false, n)


func _neon_burger_wand(pos: Vector3) -> void:
	var n := Node3D.new()
	n.position = pos
	add_child(n)
	_kugel(Vector3(0, 0.9, 0), 1.7, m["orange"], 0.55, n)
	_box(Vector3(0, 0.3, 0), Vector3(3.6, 0.22, 0.12), m["salat"], false, n)
	_box(Vector3(0, -0.05, 0), Vector3(3.5, 0.3, 0.12), m["rotneon"], false, n)
	_box(Vector3(0, -0.35, 0), Vector3(3.6, 0.15, 0.12), m["gelb"], false, n)
	_box(Vector3(0, -0.7, 0), Vector3(3.6, 0.4, 0.12), m["orange"], false, n)
	for i in 3:
		var st := _box(Vector3(-3.0 + i * 0.0, 1.6 - i * 0.9, 0), Vector3(0.5, 0.5, 0.08), m["gelb"], false, n)
		st.rotation_degrees.z = 45.0
		st.position.x = -3.2 + (i % 2) * 0.7


func _poster(pos: Vector3, drehung: float) -> void:
	pass


func _poster_held(pos: Vector3) -> void:
	# Superhelden-Poster an der linken Glasseite (Rahmen, Cape, "Z")
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = 90.0
	add_child(n)
	_box(Vector3(0, 0, 0), Vector3(3.2, 4.0, 0.15), m["dunkel"], false, n)
	_box(Vector3(0, 0, 0.09), Vector3(2.9, 3.7, 0.04), _std(Color(0.1, 0.25, 0.8), 0.9), false, n)
	_box(Vector3(0, -0.3, 0.12), Vector3(1.4, 1.6, 0.03), _std(Color(0.85, 0.1, 0.12), 0.6), false, n)
	_box(Vector3(0, 0.0, 0.14), Vector3(0.7, 0.8, 0.03), _std(Color(0.1, 0.2, 0.8), 0.4), false, n)
	_kugel(Vector3(0, 0.9, 0.14), 0.4, m["haut"], 1.0, n)
	var z := Label3D.new()
	z.text = "Z"
	z.font_size = 64
	z.pixel_size = 0.012
	z.modulate = Color(1.0, 0.9, 0.2)
	z.position = Vector3(0, 0.0, 0.17)
	z.shaded = false
	n.add_child(z)


func _haengelampe(pos: Vector3) -> void:
	_zyl(pos + Vector3(0, 0.6, 0), 0.03, 1.2, m["dunkel"], -1.0, 6)
	_zyl(pos, 0.7, 0.5, m["chrom"], 0.2, 16)
	_kugel(pos + Vector3(0, -0.25, 0), 0.22, m["gelb"], 1.0)


func _pflanze(pos: Vector3) -> void:
	_zyl(pos + Vector3(0, 0.5, 0), 0.5, 1.0, m["chrom"], 0.42, 14, true)
	for i in 7:
		var a := i * TAU / 7.0
		var b := _kugel(pos + Vector3(cos(a) * 0.35, 1.7 + (i % 3) * 0.35, sin(a) * 0.35), 0.45, m["blatt"], 1.4)
		b.scale = Vector3(0.6, 1.5, 0.6)
	_zyl(pos + Vector3(0, 1.3, 0), 0.06, 1.0, m["blatt"], -1.0, 6)


func _dach_technik() -> void:
	var y := H + 0.4
	for p in [Vector3(-14, 0, 6), Vector3(-9, 0, 8), Vector3(14, 0, 6)]:
		_zyl(Vector3(p.x, y + 1.0, p.z), 0.9, 2.0, m["chrom"], -1.0, 16)
		_zyl(Vector3(p.x, y + 2.1, p.z), 1.05, 0.2, m["dach"], -1.0, 16)
	_zyl(Vector3(-4.0, y + 1.5, -8.0), 0.35, 3.0, m["chrom"], -1.0, 12)
	_box(Vector3(-4.0, y + 3.1, -8.0), Vector3(1.2, 0.3, 1.2), m["dach"], false)
	_box(Vector3(10.0, y + 0.8, -6.0), Vector3(5.0, 1.6, 3.0), m["wand"], false)
	for k in 4:
		_box(Vector3(8.4 + k * 1.1, y + 1.2, -4.45), Vector3(0.8, 0.06, 0.04), m["cyan"], false)
	# Funkmast mit rotem Blinklicht
	_zyl(Vector3(16.0, y + 3.0, -10.0), 0.12, 6.0, m["chrom"], -1.0, 6)
	_kugel(Vector3(16.0, y + 6.1, -10.0), 0.22, m["rotneon"])


func _treppe() -> void:
	# Betretbare Treppe vom Erdgeschoss (z=8) zur Galerie (z=-2). Die Kollision ist eine
	# glatte Rampe, die Stufen darueber sind nur Optik (Antritt auf Bodenhoehe).
	var x0 := 1.8
	var breite := 2.4
	var z_unten := 8.0
	var z_oben := -2.0
	var y_unten := 0.3
	var y_oben := GALERIE_Y
	var stufen := 20
	var lauf := z_unten - z_oben
	var d := lauf / stufen
	for i in stufen:
		var zc := z_unten - (i + 0.5) * d
		var oben := y_unten + (i + 0.5) * (y_oben - y_unten) / stufen
		# Offene Stufen (Trittplatte plus Setzstufe) statt eines massiven Keils: von der Seite entsteht keine Schraege
		_box(Vector3(x0, oben - STUFEN_PLATTE * 0.5, zc), Vector3(breite, STUFEN_PLATTE, d + 0.01), m["dunkel"], false)
		_box(Vector3(x0, oben - (y_oben - y_unten) / stufen * 0.5, zc + d * 0.5 - 0.02), Vector3(breite, (y_oben - y_unten) / stufen, 0.04), m["dunkel"], false)
		_box(Vector3(x0, oben + 0.005, zc + d * 0.5 - STUFEN_LED), Vector3(breite, 0.02, STUFEN_LED), m["cyan"] if i % 2 == 0 else m["blau"], false)
	var steigung := (y_oben - y_unten) / lauf
	var winkel := atan(steigung)
	var laenge := sqrt(lauf * lauf + (y_oben - y_unten) * (y_oben - y_unten))
	var rampe := Node3D.new()
	var mitte_y := (y_unten + y_oben) * 0.5 - 0.15 / cos(winkel)
	rampe.position = Vector3(x0, mitte_y, (z_unten + z_oben) * 0.5)
	rampe.rotation.x = winkel  # +x-Drehung: hebt die -z-Seite an
	add_child(rampe)
	_kol(rampe, Vector3(breite, 0.3, laenge))
	# Gelaender an beiden Laengsseiten: senkrechte Pfosten auf den Stufen und zwei schlanke Holme.
	# (Frueher schraege Glas- und Neonplatten; die wirkten wie eine Rampe neben der Treppe.)
	var hoehe := y_oben - y_unten
	for sx: float in [x0 - breite * 0.5, x0 + breite * 0.5]:
		var seite := Node3D.new()
		seite.position = Vector3(sx, (y_unten + y_oben) * 0.5 + GELAENDER_H * 0.5, (z_unten + z_oben) * 0.5)
		seite.rotation.x = winkel
		add_child(seite)
		_box(Vector3(0, GELAENDER_H * 0.5, 0), Vector3(0.07, 0.07, laenge), m["chrom"], false, seite)
		_box(Vector3(0, 0.0, 0), Vector3(0.04, 0.04, laenge), m["chrom"], false, seite)
		_kol(seite, Vector3(0.1, GELAENDER_H, laenge))
		for i in range(0, stufen + 1, GELAENDER_PFOSTEN_JE):
			var fuss_y := y_unten + hoehe * i / stufen
			_zyl(Vector3(sx, fuss_y + GELAENDER_H * 0.5, z_unten - i * d), 0.035, GELAENDER_H, m["chrom"], -1.0, 8)


func _spielecke() -> void:
	# Lego-Spielplatz hinten links: Gummiboden, Bausteine mit Noppen, Turm
	var n := Node3D.new()
	n.position = Vector3(-13.0, 0.3, -2.5)
	add_child(n)
	var farben := [_std(Color(0.9, 0.1, 0.1), 0.3, 0.0, 0.3), _std(Color(0.1, 0.3, 0.95), 0.3, 0.0, 0.3), _std(Color(1.0, 0.85, 0.1), 0.3, 0.0, 0.3), _std(Color(0.1, 0.7, 0.2), 0.3, 0.0, 0.3)]
	_box(Vector3(0, 0.04, 0), Vector3(7.4, 0.08, 6.4), m["gummi"], false, n)
	_box(Vector3(0, 0.1, 3.3), Vector3(7.4, 0.04, 0.1), m["gelb"], false, n)
	var turm := [Vector3(-2.2, 0.8, -1.5), Vector3(-0.6, 0.8, -1.5), Vector3(-2.2, 2.4, -1.5), Vector3(-0.6, 2.4, -1.5)]
	for i in turm.size():
		_box(turm[i], Vector3(1.6, 1.6, 1.6), farben[i % 4], true, n)
		for dx in [-0.4, 0.4]:
			for dz in [-0.4, 0.4]:
				var noppe := _zyl(Vector3(turm[i].x + dx, turm[i].y + 0.87, turm[i].z + dz), 0.22, 0.14, farben[i % 4], -1.0, 10)
				noppe.reparent(n, false)
	# Dach mit Fahne
	_box(Vector3(-1.4, 3.6, -1.5), Vector3(3.4, 0.15, 1.8), farben[0], false, n)
	# (Die schraege Rutsche am Turm ist entfernt: sie wirkte wie eine Plattform neben der Treppe.)
	# Bausteine zum Rumliegen
	for p in [Vector3(1.8, 0.45, 2.2), Vector3(2.9, 0.45, 2.6), Vector3(0.0, 0.45, 2.6), Vector3(-2.4, 0.45, 2.0), Vector3(-1.2, 0.45, 1.0)]:
		var f: StandardMaterial3D = farben[int(absf(p.x * 3.0)) % 4]
		_box(p, Vector3(1.2, 0.8, 0.8), f, true, n)
		for k in 3:
			var noppe := _zyl(Vector3(p.x - 0.4 + k * 0.4, p.y + 0.45, p.z), 0.14, 0.1, f, -1.0, 8)
			noppe.reparent(n, false)
	# Neon-Sterne an der Wand und Schild
	for i in 3:
		var st := _box(Vector3(-13.0 - 2.0 + i * 1.4, 4.8 + (i % 2) * 1.0, -T * 0.5 + 0.55), Vector3(0.6, 0.6, 0.06), m["gelb"], false)
		st.rotation_degrees.z = 45.0
	_text("SPIELECKE", Vector3(-13.0, 3.9, -3.0), Color(1.0, 0.8, 0.1), 0.02, 0.0, 8)


func _terrasse() -> void:
	_box(Vector3(0, 0.1, T * 0.5 + 8.0), Vector3(B + 10.0, 0.2, 16.0), m["terrasse"])
	_box(Vector3(0, 0.22, T * 0.5 + 15.9), Vector3(B + 10.0, 0.06, 0.25), m["cyan"], false)
	var reihe := [-15.0, -5.0, 5.0, 15.0]
	var schirm := _std(Color(0.9, 0.1, 0.18), 0.3)
	for i in reihe.size():
		var p := Vector3(reihe[i], 0.0, T * 0.5 + 8.5)
		_zyl(p + Vector3(0, 1.8, 0), 0.08, 3.6, m["chrom"], -1.0, 8)
		_zyl(p + Vector3(0, 3.7, 0), 3.0, 0.7, schirm, 0.1, 16)
		_zyl(p + Vector3(0, 0.95, 0), 1.1, 0.1, m["holz"], -1.0, 16, true)
		for k in 3:
			var a := k * TAU / 3.0 + i
			_zyl(p + Vector3(cos(a) * 1.9, 0.5, sin(a) * 1.9), 0.38, 1.0, m["dunkel"], -1.0, 8, true)
	# Pflanzkuebel mit Kugelbaeumen
	for x in [-22.0, -9.5, 9.5, 22.0]:
		var p := Vector3(x, 0.0, T * 0.5 + 2.0)
		_box(p + Vector3(0, 0.6, 0), Vector3(1.6, 1.2, 1.6), m["chrom"])
		_box(p + Vector3(0, 1.22, 0), Vector3(1.3, 0.06, 1.3), m["cyan"], false)
		_kugel(p + Vector3(0, 2.4, 0), 1.2, m["blatt"])
	# Baenke aus Holz und Metall sowie leuchtende Poller entlang der Terrassenkante
	for x in [-24.0, 24.0]:
		_box(Vector3(x, 0.55, T * 0.5 + 11.0), Vector3(3.6, 0.15, 1.0), m["holz"])
		_box(Vector3(x, 1.0, T * 0.5 + 11.5), Vector3(3.6, 0.8, 0.12), m["holz"], false)
		for sx in [-1.5, 1.5]:
			_box(Vector3(x + sx, 0.3, T * 0.5 + 11.0), Vector3(0.12, 0.5, 0.9), m["chrom"], false)
	for i in 11:
		var px := -24.0 + i * 4.8
		_zyl(Vector3(px, 0.7, T * 0.5 + 15.5), 0.15, 1.0, m["chrom"], -1.0, 8)
		_kugel(Vector3(px, 1.3, T * 0.5 + 15.5), 0.17, m["cyan"])
	# Zugang zur Plaza
	_box(Vector3(0, 0.24, T * 0.5 + 8.0), Vector3(6.0, 0.04, 16.0), m["gelb"], false)


func _drive_in() -> void:
	var x0 := B * 0.5 + 1.5
	# Fahrbahn und Tunnel
	_box(Vector3(x0 + 8.0, 0.08, 4.0), Vector3(16.0, 0.16, 26.0), m["dunkel"])
	_box(Vector3(x0 + 8.0, 0.2, 4.0), Vector3(0.3, 0.05, 24.0), m["gelb"], false)
	_box(Vector3(x0 + 8.0, 6.2, 0.0), Vector3(14.0, 1.2, 16.0), m["chrom"])
	_box(Vector3(x0 + 8.0, 5.55, 0.0), Vector3(14.2, 0.15, 16.2), m["blau"], false)
	_box(Vector3(x0 + 8.0, 6.85, 0.0), Vector3(14.2, 0.15, 16.2), m["lila"], false)
	_box(Vector3(x0 + 14.8, 3.0, -6.0), Vector3(0.6, 6.0, 4.0), m["chrom"])
	_text("DRIVE-IN", Vector3(x0 + 8.0, 6.2, 8.3), Color(0.3, 0.9, 1.0), 0.04, 0.0, 14)
	_text("DRIVE-IN", Vector3(x0 + 8.0, 6.2, -8.3), Color(0.3, 0.9, 1.0), 0.04, 180.0, 14)
	# Bestell-Saeule mit Menue
	var s := _box(Vector3(x0 + 3.0, 1.6, 9.4), Vector3(1.2, 3.2, 0.6), m["dunkel"])
	_box(Vector3(x0 + 3.0, 1.8, 9.72), Vector3(0.9, 2.2, 0.05), m["orange"], false)
	_box(Vector3(x0 + 3.0, 2.4, 9.78), Vector3(0.7, 0.55, 0.02), m["gelb"], false)
	_box(Vector3(x0 + 3.0, 1.3, 9.78), Vector3(0.7, 0.55, 0.02), m["rotneon"], false)
	_text(">>", Vector3(x0 + 3.0, 0.6, 9.8), Color(0.3, 1.0, 1.0), 0.02, 0.0, 6)
	# Silo-Turm mit Burger-Zeichen
	_zyl(Vector3(x0 + 15.5, 8.0, -8.0), 2.6, 16.0, m["chrom"], -1.0, 20, true)
	_zyl(Vector3(x0 + 15.5, 16.4, -8.0), 2.9, 0.8, m["blau"], -1.0, 20)
	_zyl(Vector3(x0 + 15.5, 17.4, -8.0), 1.4, 1.2, m["chrom"], 0.8, 12)
	var icon := Node3D.new()
	icon.position = Vector3(x0 + 15.5, 8.0, -5.4)
	add_child(icon)
	_kugel(Vector3(0, 1.4, 0), 1.5, m["orange"], 0.6, icon)
	_box(Vector3(0, 0.6, 0), Vector3(3.0, 0.3, 0.3), m["salat"], false, icon)
	_box(Vector3(0, 0.1, 0), Vector3(3.0, 0.4, 0.3), m["rotneon"], false, icon)
	_box(Vector3(0, -0.5, 0), Vector3(3.0, 0.5, 0.3), m["orange"], false, icon)
	# Schwebendes Auto im Drive-In
	var auto := Node3D.new()
	auto.position = Vector3(x0 + 7.0, 0.9, 5.0)
	auto.rotation_degrees.y = 90.0
	add_child(auto)
	_box(Vector3(0, 0.5, 0), Vector3(4.6, 0.8, 2.0), _std(Color(0.35, 0.4, 0.6), 0.0, 0.9, 0.2), true, auto)
	_box(Vector3(-0.2, 1.1, 0), Vector3(2.4, 0.6, 1.7), _std(Color(0.15, 0.2, 0.3), 0.0, 0.9, 0.1), false, auto)
	_box(Vector3(2.3, 0.5, 0), Vector3(0.1, 0.18, 1.7), m["cyan"], false, auto)
	_box(Vector3(-2.3, 0.5, 0), Vector3(0.1, 0.18, 1.7), m["rotneon"], false, auto)
	_box(Vector3(0, 0.05, 0), Vector3(4.0, 0.08, 1.6), m["blau"], false, auto)
	_licht(Vector3(x0 + 8.0, 5.0, 0), Color(0.3, 0.7, 1.0), 2.5, 22.0)


func _licht_an() -> void:
	# Helle Decke und mehr Innenlicht
	_box(Vector3(0, H - 0.05, 0), Vector3(B - 0.8, 0.1, T - 0.8), _tex("metal_plate", 3.0, Color(0.75, 0.7, 0.9), 0.3), false)
	for p in [Vector3(-14, 6.5, -6), Vector3(0, 6.5, -6), Vector3(14, 3.5, -8), Vector3(-14, 6.5, 8), Vector3(0, 6.5, 9), Vector3(14, 6.5, 8), Vector3(-10, 6.5, 0)]:
		_licht(p, Color(1.0, 0.85, 0.65), 2.2, 16.0)
	_licht(Vector3(-10, 6.5, 0), Color(1.0, 0.75, 0.45), 2.5, 22.0)
	_licht(Vector3(10, 6.5, 2), Color(1.0, 0.55, 0.35), 2.5, 22.0)
	_licht(Vector3(0, 3.0, T * 0.5 + 6.0), Color(1.0, 0.5, 0.7), 2.0, 22.0)
	_licht(Vector3(-13, 3.5, -2.5), Color(1.0, 0.9, 0.3), 1.8, 10.0)
