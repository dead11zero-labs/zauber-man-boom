extends Node3D
## Synth-City: wird beim Start komplett per Code aufgebaut.
## Koordinaten: x = Ost, z = Süd (Norden ist -z). Mit der Taste T wechselt Tag/Nacht.

const GRENZE := 320.0
const RING_M := Vector2(0, 10)
const RING_RX := 210.0
const RING_RZ := 170.0
const RING_H := 14.0
const TURM := Vector2(0, -240)
const BURGER_POS := Vector2(107, 83)
## Wassertank-Hochhaus: steht noerdlich der Runenstrasse (frueher z -100, das ragte auf die Fahrbahn)
const TANK_POS := Vector2(240, -126)
const POPCORN_POS := Vector2(255, 40)
## Oeffentliche Gebaeude (begehbar, levels/haus.gd): [Skript, Mitte, Drehung, Sperrflaeche]
const BUECHEREI_POS := Vector2(-33, -40)   ## Front nach Osten zur Zauber-Allee
const MUSEUM_POS := Vector2(-38, -182)     ## Front nach Norden zur Tower-Allee
const RATHAUS_POS := Vector2(42, 0)        ## Front nach Westen zur Zauber-Allee, mit Vorplatz
const KLINIK_POS := Vector2(62, -56)       ## Front nach Sueden zur Altstadtgasse, Vorfahrt davor
const TANK_RADIUS := 13.0
const TANK_STUETZE_H := 8.0
const TANK_STUETZE_ABSTAND := 8.0   ## Stuetzen stehen bei +-8 m (Diagonale 11,3 m, innerhalb des Tankradius)
const STRASSE_KACHEL := 5.0     ## Meter pro Asphalt-Kachel
const BODEN_KACHEL := 4.0       ## Meter pro Pflaster-Kachel
const RASEN_KACHEL := 3.0       ## Meter pro Rasen-Kachel
## Bildqualitaet (nur Forward+; der Mobile-Renderer auf Android ignoriert SSAO und SSR)
const SSAO_RADIUS := 1.6
const SSAO_STAERKE := 1.8
const SSR_SCHRITTE := 40
## Realismus-Leitfaden (docs/FORTSCHRITT.md): Die Projekteinstellungen stehen auf den Werten fuer Stufe HOCH
## (4x MSAA, FXAA, weiche Schatten "mittel", 16x anisotrop). Schwaechere Stufen schalten hier zur Laufzeit zurueck.
const TONEMAP_WEISS := 6.0          ## Weisspunkt fuer ACES/Filmic (AgX nutzt seinen eigenen `tonemap_agx_white`)
const GLOW_STAERKE := 0.4           ## vorher 0.7: Neon ueberstrahlte ganze Flaechen
const NEBEL_VOLUMEN_DICHTE := 0.0015 ## volumetrischer Nebel (nur Stufe HOCH); der Leitfaden nennt 0.005+, das ist fuer 700 m Stadt zu dicht
const SSIL_RADIUS := 4.0
## Grafikstufen: HOCH (eigene Grafikkarte), MITTEL (integrierte Grafik), NIEDRIG (Mobile-Renderer/Android).
## Automatik ueber `_grafik_stufe()`, fest einstellbar per Projekteinstellung `zauber_man/grafik_stufe` (0..2).
enum Grafik { NIEDRIG, MITTEL, HOCH }
const GRAFIK_EINSTELLUNG := "zauber_man/grafik_stufe"
## je Stufe: Schattenweite der Sonne (m) und Anteil der 3D-Aufloesung
const SCHATTEN_WEITE: Array[float] = [90.0, 150.0, 240.0]
const AUFLOESUNG_3D: Array[float] = [0.7, 0.77, 1.0]
## Kleinteile verschwinden auf Distanz: [laengste Kante bis (m), sichtbar bis (m)]
const SICHTWEITEN: Array[Vector2] = [Vector2(1.0, 70.0), Vector2(3.0, 140.0), Vector2(8.0, 320.0)]
const SICHT_RAND := 8.0             ## Hysterese, damit nichts flackert
const SCHATTEN_AB_GROESSE := 1.2    ## kleinere Teile werfen keinen Schatten
const LICHT_FADE_FAKTOR := 4.0      ## Punktlichter verblassen ab Reichweite x Faktor
const LICHT_FADE_MIN := 70.0
const LICHT_FADE_LAENGE := 25.0
const BUSCH_SEGMENTE := 12
const MODELL_ORDNER := "res://imported_models/"
const SONNE_WEICH := 0.6        ## Winkeldurchmesser der Sonne in Grad (weiche Schattenraender)
## Fluesse: abgesenktes Bett mit Kaimauern, Gelaender und Rampen zum Wasser
const FLUSS_BREITE := 16.0
const FLUSS_TIEFE := 1.45       ## Sohle unter Strassenniveau (knapp ueber dem Terrain3D-Gelaende, das unter der Platte auf -1.5 liegt)
const WASSER_Y := -0.7          ## Wasserspiegel
const FLUSS_SPERRE := 24.0      ## fuer Gebaeude gesperrte Breite (Wasser plus Uferweg)
const KAI_STUECK := 4.0         ## Kaimauer und Gelaender werden in Stuecken dieser Laenge gebaut
const KAI_KANTE := Vector2(0.7, 0.12)        ## Abdeckstein: Breite, Hoehe
const GELAENDER_H := 1.1
const GELAENDER_ABSTAND := 0.45  ## Gelaender steht so weit hinter der Mauerkante
const GELAENDER_PFOSTEN := 0.12
const GELAENDER_STRASSE := 3.2   ## Luecke im Gelaender, wo eine Strasse (Bruecke) kreuzt
const RAMPE_LAENGE := 7.0
const RAMPE_BREITE := 2.2
const RAMPE_LUECKE := 3.5        ## Gelaender-Luecke am oberen Ende einer Rampe
## Rampen zum Wasser: [Fluss (0 Ost, 1 West), Abschnitt der Flusslinie, Uferseite (+1/-1)]
const RAMPEN: Array = [[0, 3, 1.0], [0, 5, -1.0], [1, 3, -1.0], [1, 5, 1.0]]
const PLATTE := 700.0            ## Kantenlaenge der Stadtplatte
const MARKT_POS := Vector2(-100, 92)   ## Mitte des Neon-Markts 24/7 (Front nach Sueden)

var rng := RandomNumberGenerator.new()
var kreise: Array = []
var rechtecke: Array = []
var linien: Array = []
var fenster_mats: Array = []
var autos: Array = []

var env: Environment
var himmel: ProceduralSkyMaterial
var sonne: DirectionalLight3D
var nacht := false
var _fluss_cache: Array[PackedVector2Array] = []
var _netz: Node3D   ## Strassennetz (bekommt den Tag/Nacht-Wechsel fuer die Laternen)
var grafik: int = Grafik.HOCH

# Hauptquartier
const HQ_BODEN := 160.2
const HQ_DECKE := 174.0
const AUFZUG_OBEN := HQ_BODEN  ## Haltestelle oben = HQ-Boden
const AUFZUG_SCHACHT := 5.0
const AUFZUG_VERSATZ_Z := -4.5   ## Schacht liegt nordlich der Turmmitte, damit er im HQ nicht am Holo-Tisch steht
const LOBBY_HOEHE := 9.0
const WAND_DICKE_TURM := 2.0
const TUER_BREITE := 6.0
const TUER_HOEHE := 5.0
const DECKE_DICKE := 1.0
const ETAGEN_ABSTAND := 6.0
const ETAGEN_START_1 := 10.0     ## Oberkante der Lobby-Decke = erste Buero-Etage in Stufe 1
const ETAGEN_ANZAHL_1 := 13
const ETAGEN_START_2 := 90.0     ## Oberkante der Stufe-1-Dachplatte = erste Etage in Stufe 2
const ETAGEN_ANZAHL_2 := 11
const ETAGEN_LAYOUTS: Array[int] = [0, 1, 0, 2, 3, 0, 1, 0, 2, 3, 0, 1, 0]
const INNEN_HALB_1 := 15.0       ## halbe Innenkante Stufe 1 (34 m minus zwei Waende)
const INNEN_HALB_2 := 11.0
var hq_tuer: MeshInstance3D
var hq_tuer_pos: Vector3
var hq_hinweis: Label3D
var hq_offen := false
var hq_holo: Node3D
var hq_brett: Node3D
var hq_brett_y := 0.0
var spieler: Node3D
var zeit := 0.0

var m_silber: ShaderMaterial
var m_alt: ShaderMaterial
var m_zukunft: ShaderMaterial
var m_schatten: ShaderMaterial
var m_bewachsen: ShaderMaterial
var m_strasse: StandardMaterial3D   ## glatter Asphalt ohne Markierung (Reserve)
var m_ring: StandardMaterial3D
var m_wasser: Material
var m_cyan: StandardMaterial3D
var m_gold: StandardMaterial3D
var m_rot: StandardMaterial3D
var m_blau: StandardMaterial3D
var m_stein: StandardMaterial3D
var m_trim: StandardMaterial3D
var m_neon: ShaderMaterial
var m_cyan_turm: StandardMaterial3D   ## gedaempfter Akzent im Tower (statt grellem Neon)
var m_gold_turm: StandardMaterial3D
var m_silber_turm: ShaderMaterial
var m_neon_blink: ShaderMaterial

## Fassadendetails (Gesimse, Pilaster, Dachaufbauten, Neonstreifen) werden gesammelt und
## am Ende als je ein MultiMesh gebaut. Eigener Zufallsgenerator, damit das Stadtlayout gleich bleibt.
var rng_d := RandomNumberGenerator.new()
var det_t: Array = []
var det_f: Array = []
var neon_t: Array = []
var neon_f: Array = []
var blink_t: Array = []
var blink_f: Array = []


func _ready() -> void:
	rng.seed = 1337
	_materialien()
	_umgebung()
	_sperrzonen()
	_boden()
	_fluesse()
	_strassen()
	_ring()
	_plaza()
	_park()
	_turm()
	_brezel_stand()
	_wassertank()
	_popcorn()
	_burger()
	_neonmarkt()
	_oeffentliche_gebaeude()
	_strassen_deko()
	_gurkenfeld()
	_floronia()
	_viertel_bauen()
	if get_node_or_null("../Terrain") == null:
		_berge()  # Ersatz-Kegelberge, nur ohne Terrain3D-Gelaende
	_grenze()
	_tageszeit()
	_sichtweiten(self)
	_modelle_schatten.call_deferred()
	_hintergrundmusik()


## Waehlt die Grafikstufe: Mobile-Renderer -> NIEDRIG, integrierte Grafik -> MITTEL, sonst HOCH.
func _grafik_stufe() -> int:
	var fest: int = ProjectSettings.get_setting(GRAFIK_EINSTELLUNG, -1)
	if fest >= Grafik.NIEDRIG and fest <= Grafik.HOCH:
		return fest
	if RenderingServer.get_current_rendering_method() != "forward_plus" or OS.has_feature("mobile"):
		return Grafik.NIEDRIG
	if RenderingServer.get_video_adapter_type() != RenderingDevice.DEVICE_TYPE_DISCRETE_GPU:
		return Grafik.MITTEL
	return Grafik.HOCH


## Leistung: Kleinteile (Moebel, Deko) bekommen eine Sichtweite und werfen keinen Schatten,
## Punktlichter verblassen auf Distanz. Gilt fuer alles unterhalb von `wurzel`.
func _sichtweiten(wurzel: Node) -> void:
	var stapel: Array[Node] = [wurzel]
	while not stapel.is_empty():
		var n: Node = stapel.pop_back()
		stapel.append_array(n.get_children())
		if n is MeshInstance3D and n.mesh != null and n.visibility_range_end <= 0.0:
			var g: Vector3 = n.mesh.get_aabb().size * n.global_basis.get_scale()
			var kante := maxf(g.x, maxf(g.y, g.z))
			for stufe in SICHTWEITEN:
				if kante <= stufe.x:
					n.visibility_range_end = stufe.y
					n.visibility_range_end_margin = SICHT_RAND
					break
			if kante < SCHATTEN_AB_GROESSE:
				n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif n is OmniLight3D or n is SpotLight3D:
			var reichweite: float = n.omni_range if n is OmniLight3D else n.spot_range
			n.distance_fade_enabled = true
			n.distance_fade_begin = maxf(reichweite * LICHT_FADE_FAKTOR, LICHT_FADE_MIN)
			n.distance_fade_length = LICHT_FADE_LAENGE


## Realismus-Leitfaden Punkt 3: alle importierten Modelle (Meshy-Figuren, Fahrzeuge) werfen Schatten.
## Laeuft einmal nach dem Aufbau ueber die ganze Szene (auch Spieler, NPCs und Verkehr ausserhalb der Stadt).
func _modelle_schatten() -> void:
	var stapel: Array[Node] = [get_tree().current_scene]
	while not stapel.is_empty():
		var n: Node = stapel.pop_back()
		if n == null:
			continue
		stapel.append_array(n.get_children())
		var mi := n as MeshInstance3D
		if mi != null and mi.mesh != null and mi.mesh.resource_path.begins_with(MODELL_ORDNER):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


## Hintergrundmusik im Spiel (Endlosschleife)
func _hintergrundmusik() -> void:
	var song = load("res://assets/audio/hintergrund.mp3")
	if song == null:
		return
	song.loop = true
	var p := AudioStreamPlayer.new()
	p.name = "Hintergrundmusik"
	p.stream = song
	p.volume_db = -10.0
	add_child(p)
	p.play()


func _unhandled_input(event: InputEvent) -> void:
	# Aktion "tageszeit" (T, Pad: rechter Stick gedrueckt), angelegt in autoload/eingabe.gd
	if event.is_action_pressed("tageszeit") and not event.is_echo():
		nacht = not nacht
		_tageszeit()


func _process(delta: float) -> void:
	zeit += delta
	_hq_leben(delta)
	for a in autos:
		a["winkel"] += a["tempo"] * delta
		var w: float = a["winkel"]
		var s: float = a["spur"]
		var n: Node3D = a["node"]
		var p := Vector3(RING_RX * s * cos(w), RING_H + 2.2 + sin(w * 9.0) * 0.3, RING_M.y + RING_RZ * s * sin(w))
		var t := Vector3(-RING_RX * sin(w), 0.0, RING_RZ * cos(w)) * signf(a["tempo"])
		n.position = p
		n.look_at(p + t, Vector3.UP)


# ---------------------------------------------------------------- Material

func _fm(basis_farbe: Color, a: Color, b: Color, c: Color, lit: float, zelle: Vector2, metall := 0.3, rauh := 0.5, textur := "concrete_tile_facade", kachel := 4.0, akzent := Color(0.1, 0.9, 1.0), akzent_staerke := 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://gebaeude.gdshader")
	var pfad := "res://assets/texturen/%s/" % textur
	m.set_shader_parameter("tex_diff", load(pfad + "diff.jpg"))
	m.set_shader_parameter("tex_nor", load(pfad + "nor.jpg"))
	m.set_shader_parameter("tex_rough", load(pfad + "rough.jpg"))
	m.set_shader_parameter("tex_size", kachel)
	m.set_shader_parameter("accent", akzent)
	m.set_shader_parameter("accent_staerke", akzent_staerke)
	m.set_shader_parameter("base_color", basis_farbe)
	m.set_shader_parameter("window_a", a)
	m.set_shader_parameter("window_b", b)
	m.set_shader_parameter("window_c", c)
	m.set_shader_parameter("lit_chance", lit)
	m.set_shader_parameter("cell", zelle)
	m.set_shader_parameter("metallic_val", metall)
	m.set_shader_parameter("roughness_val", rauh)
	fenster_mats.append(m)
	return m


func _std(farbe: Color, emission := 0.0, metall := 0.0, rauh := 0.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = farbe
	m.metallic = metall
	m.roughness = rauh
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = farbe
		m.emission_energy_multiplier = emission
	return m


func _materialien() -> void:
	var blau := Color(0.25, 0.55, 1.0)
	var gold := Color(1.0, 0.8, 0.25)
	var rot := Color(1.0, 0.22, 0.18)
	m_silber = _fm(Color(0.82, 0.88, 1.0), blau, gold, rot, 0.45, Vector2(3.2, 4.0), 0.35, 0.35, "concrete_tile_facade", 4.0, Color(0.3, 0.6, 1.0), 0.5)
	m_alt = _fm(Color(0.85, 0.8, 0.75), gold, rot, blau, 0.5, Vector2(3.6, 4.2), 0.0, 0.5, "brick_wall_005", 3.0)
	m_zukunft = _fm(Color(0.35, 0.42, 0.55), Color(0.1, 0.9, 1.0), Color(1.0, 0.2, 0.8), Color(0.9, 0.95, 1.0), 0.7, Vector2(2.6, 3.2), 0.75, 0.3, "metal_plate", 3.0, Color(0.1, 0.9, 1.0), 1.0)
	m_schatten = _fm(Color(0.28, 0.27, 0.33), Color(1.0, 0.25, 0.15), Color(0.8, 0.15, 0.4), Color(1.0, 0.5, 0.2), 0.1, Vector2(3.4, 4.0), 0.1, 0.55, "brushed_concrete_04", 4.0, Color(1.0, 0.2, 0.15), 0.4)
	m_bewachsen = _fm(Color(0.8, 0.85, 0.75), gold, blau, rot, 0.35, Vector2(3.4, 4.0), 0.0, 0.55, "concrete_moss", 4.0)
	m_trim = _std(Color(1, 1, 1), 0.0, 0.7, 0.4)
	m_trim.vertex_color_use_as_albedo = true
	m_neon = ShaderMaterial.new()
	m_neon.shader = load("res://neon.gdshader")
	m_neon_blink = ShaderMaterial.new()
	m_neon_blink.shader = load("res://neon.gdshader")
	m_neon_blink.set_shader_parameter("blink_tempo", 2.2)
	m_neon_blink.set_shader_parameter("staerke", 6.0)
	m_strasse = _aussen_mat("strasse_asphalt", STRASSE_KACHEL, Color(0.55, 0.56, 0.58), 0.0)
	m_ring = _aussen_mat("metal_plate", 3.0, Color(0.38, 0.4, 0.46), 0.8)
	var fluss := ShaderMaterial.new()
	fluss.shader = load("res://fluss.gdshader")
	m_wasser = fluss
	m_cyan = _std(Color(0.2, 0.9, 1.0), 3.0)
	m_gold = _std(Color(1.0, 0.75, 0.2), 2.5)
	m_rot = _std(Color(1.0, 0.15, 0.1), 3.0)
	m_blau = _std(Color(0.2, 0.4, 1.0), 3.0)
	m_stein = _aussen_mat("brushed_concrete_04", 4.0, Color(0.5, 0.51, 0.55), 0.0)
	# Zauber-Tower: Business-Look, dunkler Stahl, neutrale Fenster, kein Neon aussen
	m_cyan_turm = _std(Color(0.16, 0.18, 0.22), 0.0, 0.85, 0.3)
	m_gold_turm = _std(Color(1.0, 0.78, 0.35), 0.7)
	var fenster_warm := Color(1.0, 0.93, 0.78)
	var fenster_kalt := Color(0.82, 0.9, 1.0)
	m_silber_turm = _fm(Color(0.46, 0.5, 0.58), fenster_kalt, fenster_warm, fenster_kalt, 0.3, Vector2(3.2, 4.0), 0.55, 0.28, "concrete_tile_facade", 4.0, Color(0.8, 0.85, 0.95), 0.0)


# ---------------------------------------------------------------- Helfer

func _kollision(parent: Node3D, groesse: Vector3) -> void:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = groesse
	cs.shape = sh
	sb.add_child(cs)
	parent.add_child(sb)


func _box(mitte: Vector3, groesse: Vector3, mat: Material, kollision := true) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = groesse
	m.mesh = bm
	m.material_override = mat
	m.position = mitte
	add_child(m)
	if kollision:
		_kollision(m, groesse)
	return m


func _zyl(mitte: Vector3, radius: float, hoehe: float, mat: Material, kollision := false, segmente := 32, oben := -1.0) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.bottom_radius = radius
	cm.top_radius = radius if oben < 0.0 else oben
	cm.height = hoehe
	cm.radial_segments = segmente
	cm.rings = 1
	m.mesh = cm
	m.material_override = mat
	m.position = mitte
	add_child(m)
	if kollision:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = radius
		sh.height = hoehe
		cs.shape = sh
		sb.add_child(cs)
		m.add_child(sb)
	return m


## Balken von a nach b. Die Oberseite liegt auf der Linie a-b.
## Gestauchte Kugel fuer Blattwerk (Pflanzen im Foyer).
func _blatt_kugel(pos: Vector3, r: float, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.6
	sm.radial_segments = 10
	sm.rings = 6
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	add_child(mi)


func _balken(a: Vector3, b: Vector3, breite: float, dicke: float, mat: Material, kollision := true, parent: Node = null) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(breite, dicke, a.distance_to(b))
	m.mesh = bm
	m.material_override = mat
	var basis_ := Basis.looking_at(b - a, Vector3.UP)
	m.transform = Transform3D(basis_, (a + b) / 2.0 - basis_.y * dicke / 2.0)
	if parent == null:
		parent = self
	parent.add_child(m)
	if kollision:
		_kollision(m, bm.size)
	return m


func _kapsel(a: Vector3, b: Vector3, radius: float, mat: Material, parent: Node3D) -> void:
	var m := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = radius
	cm.height = a.distance_to(b) + radius * 2.0
	m.mesh = cm
	m.material_override = mat
	m.transform = Transform3D(Basis(Quaternion(Vector3.UP, (b - a).normalized())), (a + b) / 2.0)
	parent.add_child(m)


func _licht(pos: Vector3, farbe: Color, energie: float, reichweite: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = farbe
	l.light_energy = energie
	l.omni_range = reichweite
	l.position = pos
	add_child(l)


func _multimesh(mesh: Mesh, mat: Material, transforms: Array, farben: Array) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		mm.set_instance_color(i, farben[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	add_child(mi)


func _text(text: String, pos: Vector3, farbe: Color, pixel: float, billboard := true) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = 64
	l.pixel_size = pixel
	l.outline_size = 14
	l.outline_modulate = farbe.darkened(0.7)
	l.modulate = Color(farbe.r * 1.5, farbe.g * 1.5, farbe.b * 1.5)
	l.shaded = false
	l.position = pos
	if billboard:
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(l)
	return l


# ---------------------------------------------------------------- Sperrzonen

func _sperrzonen() -> void:
	kreise = [
		[Vector2(0, 70), 58.0],       # Runen-Plaza
		[TURM, 50.0],                 # Zauber-Tower + Aufzug
		[Vector2(-255, 30), 30.0],    # Brezel-Stand
		[TANK_POS, 30.0],             # Wassertank
		[POPCORN_POS, 30.0],          # Popcorn-Labor
		[Vector2(0, 262), 28.0],      # Floronia-Versteck
		[BURGER_POS, 44.0],           # Sy-Ci Burgers
		[Vector2(-100, 98), 52.0],    # Neon-Markt 24/7 (Gebaeude + Vorplatz)
	]
	rechtecke = [
		Rect2(-170, -65, 120, 110),   # Waldviertel
		Rect2(-318, -312, 135, 212),  # Gurken-Wald
		Rect2(-47, -59, 28, 38),      # Buecherei
		Rect2(-59, -196, 42, 27),     # Museum
		Rect2(14, -21, 44, 42),       # Stadtverwaltung mit Vorplatz
		Rect2(40, -70, 48, 34),       # Stadtklinik mit Rettungsvorfahrt
	]
	linien = [
		[_fluss_ost(), FLUSS_SPERRE],
		[_fluss_west(), FLUSS_SPERRE],
		[PackedVector2Array([Vector2(-170, TerrainForm.PASS_Z), Vector2(-345, TerrainForm.PASS_Z)]), 46.0],  # Zugang zum Durchgang
	]
	# Strassennetz (levels/strassen_daten.gd): Fahrbahn plus Gehweg-Streifen bleibt frei
	for st in StrassenDaten.STRASSEN:
		linien.append([PackedVector2Array([st["a"], st["b"]]), st["breite"] + 4.0])


func _fluss_ost() -> PackedVector2Array:
	return PackedVector2Array([Vector2(70, -300), Vector2(110, -200), Vector2(140, -120), Vector2(125, -40),
		Vector2(145, 40), Vector2(150, 120), Vector2(185, 200), Vector2(200, 300)])


func _fluss_west() -> PackedVector2Array:
	return PackedVector2Array([Vector2(-120, -300), Vector2(-165, -210), Vector2(-200, -130), Vector2(-195, -40),
		Vector2(-205, 50), Vector2(-195, 140), Vector2(-215, 300)])


func _blockiert(x: float, z: float, r: float) -> bool:
	var p := Vector2(x, z)
	for c in kreise:
		if p.distance_to(c[0]) < c[1] + r:
			return true
	for rc in rechtecke:
		if rc.grow(r).has_point(p):
			return true
	for l in linien:
		var pts: PackedVector2Array = l[0]
		for i in pts.size() - 1:
			var q := Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1])
			if p.distance_to(q) < l[1] / 2.0 + r + 1.0:
				return true
	var e := sqrt(pow((x - RING_M.x) / RING_RX, 2.0) + pow((z - RING_M.y) / RING_RZ, 2.0))
	if absf(e - 1.0) * RING_RZ < 14.0 + r:
		return true
	return false


func _auf_linien(x: float, z: float, r: float) -> bool:
	var p := Vector2(x, z)
	for l in linien:
		var pts: PackedVector2Array = l[0]
		for i in pts.size() - 1:
			var q := Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1])
			if p.distance_to(q) < l[1] / 2.0 + r:
				return true
	return false


# ---------------------------------------------------------------- Umgebung, Boden

func _umgebung() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	himmel = ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = himmel
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	env.tonemap_white = TONEMAP_WEISS
	env.glow_intensity = GLOW_STAERKE
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.glow_bloom = 0.03
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = true
	env.fog_aerial_perspective = 0.5
	env.fog_sky_affect = 0.3
	# Kontaktschatten in Ecken und Spiegelungen auf Wasser, Glas und nassem Asphalt
	# Beides braucht einen zusaetzlichen Geometrie-Durchlauf: nur auf Stufe HOCH
	grafik = _grafik_stufe()
	var hoch := grafik == Grafik.HOCH
	env.ssao_enabled = hoch
	env.ssao_radius = SSAO_RADIUS
	env.ssao_intensity = SSAO_STAERKE
	env.ssr_enabled = hoch
	env.ssr_max_steps = SSR_SCHRITTE
	env.ssr_fade_in = 0.2
	env.ssr_fade_out = 2.5
	# Indirektes Licht und Lichtstreuung: SDFGI, SSIL und volumetrischer Nebel kosten viel, nur Stufe HOCH
	env.ssil_enabled = hoch
	env.ssil_radius = SSIL_RADIUS
	env.sdfgi_enabled = hoch
	env.sdfgi_use_occlusion = true
	env.volumetric_fog_enabled = hoch
	env.volumetric_fog_density = NEBEL_VOLUMEN_DICHTE
	env.volumetric_fog_gi_inject = 1.0
	we.environment = env
	add_child(we)
	sonne = DirectionalLight3D.new()
	sonne.shadow_enabled = true
	sonne.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if hoch else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sonne.directional_shadow_blend_splits = hoch
	sonne.directional_shadow_max_distance = SCHATTEN_WEITE[grafik]
	sonne.light_angular_distance = SONNE_WEICH if hoch else 0.0
	# 3D-Bild kleiner rechnen und hochskalieren (HUD bleibt scharf)
	var bild := get_viewport()
	bild.scaling_3d_scale = AUFLOESUNG_3D[grafik]
	if grafik == Grafik.MITTEL:
		bild.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
	# Kantenglaettung und Schattenfilter: volle Werte nur auf Stufe HOCH
	bild.msaa_3d = Viewport.MSAA_4X if hoch else Viewport.MSAA_DISABLED
	bild.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED if grafik == Grafik.NIEDRIG else Viewport.SCREEN_SPACE_AA_FXAA
	# 16x anisotrop kostet auf integrierter Grafik rund 20 Prozent Bildrate (gemessen 30 statt 24 FPS mit 4x)
	bild.anisotropic_filtering_level = Viewport.ANISOTROPY_16X if hoch else Viewport.ANISOTROPY_4X
	var filter := RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM if hoch else RenderingServer.SHADOW_QUALITY_SOFT_LOW
	RenderingServer.directional_soft_shadow_filter_set_quality(filter)
	RenderingServer.positional_soft_shadow_filter_set_quality(filter)
	sonne.shadow_bias = 0.04
	sonne.shadow_normal_bias = 1.5
	sonne.rotation_degrees = Vector3(-40, -35, 0)
	add_child(sonne)


func _tageszeit() -> void:
	if nacht:
		himmel.sky_top_color = Color(0.02, 0.02, 0.09)
		himmel.sky_horizon_color = Color(0.28, 0.08, 0.38)
		himmel.ground_horizon_color = Color(0.28, 0.08, 0.38)
		himmel.ground_bottom_color = Color(0.02, 0.01, 0.05)
		sonne.light_color = Color(0.5, 0.6, 1.0)
		sonne.light_energy = 0.25
		env.ambient_light_energy = 0.6
		env.fog_light_color = Color(0.09, 0.04, 0.17)
		env.fog_density = 0.0022
	else:
		# Natuerlicher Taghimmel: tiefes Blau oben, heller Dunst am Horizont
		himmel.sky_top_color = Color(0.16, 0.33, 0.68)
		himmel.sky_horizon_color = Color(0.66, 0.74, 0.84)
		himmel.ground_horizon_color = Color(0.62, 0.68, 0.76)
		himmel.ground_bottom_color = Color(0.16, 0.17, 0.19)
		sonne.light_color = Color(1.0, 0.95, 0.86)
		sonne.light_energy = 1.25
		env.ambient_light_energy = 0.75
		env.fog_light_color = Color(0.7, 0.76, 0.85)
		env.fog_density = 0.0004
	for m in fenster_mats:
		m.set_shader_parameter("emission_strength", 2.8 if nacht else 0.35)
	if _netz != null:
		_netz.call("nacht_setzen", nacht)


func _boden() -> void:
	# Pflaster statt Neon-Raster (boden.gdshader bleibt im Projekt, wird aber nicht mehr benutzt)
	var m := ShaderMaterial.new()
	m.shader = load("res://boden_stadt.gdshader")
	var pfad := "res://assets/texturen/boden_pflaster/"
	m.set_shader_parameter("tex_diff", load(pfad + "diff.jpg"))
	m.set_shader_parameter("tex_nor", load(pfad + "nor.jpg"))
	m.set_shader_parameter("tex_rough", load(pfad + "rough.jpg"))
	m.set_shader_parameter("kachel", BODEN_KACHEL)
	# Die Platte endet an TerrainForm.RAND, dahinter uebernimmt das Terrain3D-Gelaende.
	# Sie ist keine Box mehr, sondern eine Flaeche mit ausgeschnittenen Flusslaeufen.
	var b := _flaeche(Rect2(-PLATTE / 2.0, -PLATTE / 2.0, PLATTE, PLATTE), 0.0, m, true)
	b.name = "Boden"
	# Schatten-Gassen: dunkler Asphalt, Handelsplatz und Gurken-Wald: Rasen
	_flaeche(Rect2(-190, 197, 380, 100), 0.06, _aussen_mat("strasse_asphalt", STRASSE_KACHEL, Color(0.28, 0.28, 0.3), 0.0), false)
	_flaeche(Rect2(-295, -97.5, 80, 395), 0.06, _aussen_mat("park_rasen", RASEN_KACHEL, Color(0.75, 0.8, 0.7), 0.0), false)
	_flaeche(Rect2(-318, -312, 135, 212), 0.08, _aussen_mat("park_rasen", RASEN_KACHEL, Color(0.5, 0.58, 0.42), 0.0), false)


## Flusslauf als Polygon (Mittellinie bis ueber den Plattenrand verlaengert, auf Breite gebracht,
## an der Platte abgeschnitten). Ohne Loecher, teilt die Platte von Nord nach Sued.
func _fluss_polygon(pts: PackedVector2Array) -> PackedVector2Array:
	var linie := pts.duplicate()
	var rand := PLATTE / 2.0 + 10.0
	var vorn := linie[0] - linie[1]
	linie.insert(0, linie[0] + vorn * ((-rand - linie[0].y) / vorn.y))
	var n := linie.size()
	var hinten := linie[n - 1] - linie[n - 2]
	linie.append(linie[n - 1] + hinten * ((rand - linie[n - 1].y) / hinten.y))
	var breit := Geometry2D.offset_polyline(linie, FLUSS_BREITE / 2.0, Geometry2D.JOIN_ROUND, Geometry2D.END_BUTT)
	var h := PLATTE / 2.0
	var platte := PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
	var teile := Geometry2D.intersect_polygons(breit[0], platte)
	return teile[0]


func _fluss_polygone() -> Array[PackedVector2Array]:
	if _fluss_cache.is_empty():
		_fluss_cache = [_fluss_polygon(_fluss_ost()), _fluss_polygon(_fluss_west())]
	return _fluss_cache


## Ebene Flaeche auf Hoehe y: Rechteck minus Flusslaeufe, als ein Mesh (Normalen nach oben).
## Mit `kollision` bekommt sie einen Dreiecks-Kollisionskoerper.
func _flaeche(bereich: Rect2, y: float, mat: Material, kollision: bool) -> MeshInstance3D:
	var teile: Array[PackedVector2Array] = [PackedVector2Array([bereich.position, Vector2(bereich.end.x, bereich.position.y), bereich.end, Vector2(bereich.position.x, bereich.end.y)])]
	for fluss in _fluss_polygone():
		var rest: Array[PackedVector2Array] = []
		for t in teile:
			for stueck in Geometry2D.clip_polygons(t, fluss):
				if not Geometry2D.is_polygon_clockwise(stueck):
					rest.append(stueck)
		teile = rest
	return _polygon_mesh(teile, y, mat, kollision)


func _polygon_mesh(teile: Array[PackedVector2Array], y: float, mat: Material, kollision: bool) -> MeshInstance3D:
	var ecken := PackedVector3Array()
	for t in teile:
		var idx := Geometry2D.triangulate_polygon(t)
		for i in range(0, idx.size(), 3):
			var a := Vector3(t[idx[i]].x, y, t[idx[i]].y)
			var b := Vector3(t[idx[i + 1]].x, y, t[idx[i + 1]].y)
			var c := Vector3(t[idx[i + 2]].x, y, t[idx[i + 2]].y)
			# Dreieck so drehen, dass die Vorderseite nach oben zeigt
			if (c - a).cross(b - a).y < 0.0:
				var tausch := b
				b = c
				c = tausch
			ecken.append_array([a, b, c])
	return _dreiecke(ecken, mat, kollision)


## Mesh aus einer Dreiecksliste (flache Normalen), optional mit Kollision.
func _dreiecke(ecken: PackedVector3Array, mat: Material, kollision: bool) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0, ecken.size(), 3):
		# Vorderseite ist im Uhrzeigersinn gewickelt, die Normale zeigt zur Vorderseite
		var n := (ecken[i + 2] - ecken[i]).cross(ecken[i + 1] - ecken[i]).normalized()
		for k in 3:
			st.set_normal(n)
			st.add_vertex(ecken[i + k])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	add_child(mi)
	if kollision:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var form := ConcavePolygonShape3D.new()
		form.backface_collision = true
		form.set_faces(ecken)
		cs.shape = form
		sb.add_child(cs)
		mi.add_child(sb)
	return mi


## Haengt einen achsfreien Quader von a nach b (Unterkante auf y_unten) an eine Dreiecksliste.
func _quader(ecken: PackedVector3Array, a: Vector2, b: Vector2, breite: float, y_unten: float, hoehe: float) -> void:
	var laengs := (b - a).normalized()
	var quer := Vector2(-laengs.y, laengs.x) * breite * 0.5
	var p: Array[Vector3] = []
	for yy in [y_unten, y_unten + hoehe]:
		for q in [a - quer, a + quer, b + quer, b - quer]:
			p.append(Vector3(q.x, yy, q.y))
	# Deckel, Boden und vier Seiten (je zwei Dreiecke, Vorderseite aussen)
	for f in [[4, 5, 6, 7], [3, 2, 1, 0], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]]:
		var n := (p[f[2]] - p[f[0]]).cross(p[f[1]] - p[f[0]])
		var mitte := (p[f[0]] + p[f[2]]) * 0.5
		var zentrum := Vector3((a.x + b.x) * 0.5, y_unten + hoehe * 0.5, (a.y + b.y) * 0.5)
		if n.dot(mitte - zentrum) < 0.0:
			ecken.append_array([p[f[0]], p[f[2]], p[f[1]], p[f[0]], p[f[3]], p[f[2]]])
		else:
			ecken.append_array([p[f[0]], p[f[1]], p[f[2]], p[f[0]], p[f[2]], p[f[3]]])


## Fluesse: Sohle, Wasser, Kaimauern mit Abdeckstein, Gelaender (mit Luecken an Strassen und Rampen),
## Rampen zum Wasser und Durchlaesse am Stadtrand.
func _fluesse() -> void:
	var m_kai := _aussen_mat("brushed_concrete_04", 3.0, Color(0.62, 0.63, 0.66), 0.0)
	var m_sohle := _aussen_mat("concrete_moss", 5.0, Color(0.32, 0.36, 0.33), 0.0)
	var m_gelaender := _std(Color(0.2, 0.22, 0.26), 0.0, 0.85, 0.35)
	var m_gel_neon := _std(Color(0.2, 0.9, 1.0), 1.6)
	# Sohle: eine Platte unter der ganzen Stadt, sichtbar nur in den Flusslaeufen (faengt auch alles auf, was faellt)
	_box(Vector3(0, -FLUSS_TIEFE - 0.5, 0), Vector3(PLATTE, 1.0, PLATTE), m_sohle)
	var linien_f: Array[PackedVector2Array] = [_fluss_ost(), _fluss_west()]
	var polys := _fluss_polygone()
	var rand := PLATTE / 2.0 - 0.1
	for f in polys.size():
		var poly := polys[f]
		_polygon_mesh([poly], WASSER_Y, m_wasser, false)
		# Rampen dieses Flusses: Fusspunkt oben (Gelaender-Luecke) merken
		var luecken: Array[Vector2] = []
		for r in RAMPEN:
			if r[0] != f:
				continue
			var pa: Vector2 = linien_f[f][r[1]]
			var pb: Vector2 = linien_f[f][r[1] + 1]
			var laengs := (pb - pa).normalized()
			var quer := Vector2(-laengs.y, laengs.x) * float(r[2])
			var mitte := (pa + pb) * 0.5 + quer * (FLUSS_BREITE / 2.0 - RAMPE_BREITE / 2.0)
			var oben := mitte - laengs * RAMPE_LAENGE / 2.0
			var unten := mitte + laengs * RAMPE_LAENGE / 2.0
			_balken(Vector3(oben.x, 0.0, oben.y), Vector3(unten.x, -FLUSS_TIEFE, unten.y), RAMPE_BREITE, 0.5, m_kai)
			luecken.append(oben + laengs * RAMPE_LUECKE * 0.3 + quer * RAMPE_BREITE / 2.0)
		var wand := PackedVector3Array()
		var stein := PackedVector3Array()
		var gel := PackedVector3Array()
		var neon := PackedVector3Array()
		var gel_koerper := StaticBody3D.new()
		add_child(gel_koerper)
		for i in poly.size():
			var a := poly[i]
			var b := poly[(i + 1) % poly.size()]
			# Kanten auf dem Plattenrand sind offen (dort stehen die Durchlaesse)
			if (absf(a.y) > rand and absf(b.y) > rand) or (absf(a.x) > rand and absf(b.x) > rand):
				continue
			var laengs := (b - a).normalized()
			var aussen := Vector2(-laengs.y, laengs.x)
			if Geometry2D.is_point_in_polygon((a + b) * 0.5 + aussen * 0.3, poly):
				aussen = -aussen
			var stuecke := maxi(1, ceili(a.distance_to(b) / KAI_STUECK))
			for k in stuecke:
				var p0 := a.lerp(b, float(k) / stuecke)
				var p1 := a.lerp(b, float(k + 1) / stuecke)
				var pm := (p0 + p1) * 0.5
				# Mauer: Flaeche zeigt ins Flussbett
				var o0 := Vector3(p0.x, 0.0, p0.y)
				var o1 := Vector3(p1.x, 0.0, p1.y)
				var u0 := o0 + Vector3.DOWN * FLUSS_TIEFE
				var u1 := o1 + Vector3.DOWN * FLUSS_TIEFE
				var innen := Vector3(-aussen.x, 0.0, -aussen.y)
				if (o1 - o0).cross(u0 - o0).dot(innen) > 0.0:
					wand.append_array([o0, u0, o1, o1, u0, u1])
				else:
					wand.append_array([o0, o1, u0, o1, u1, u0])
				_quader(stein, p0 + aussen * KAI_KANTE.x * 0.5, p1 + aussen * KAI_KANTE.x * 0.5, KAI_KANTE.x, 0.0, KAI_KANTE.y)
				# Gelaender: nicht ueber Strassen (dort stehen Bruecken) und nicht am Rampenkopf
				var frei := StrassenDaten.auf_strasse(pm, GELAENDER_STRASSE)
				for l in luecken:
					if pm.distance_to(l) < RAMPE_LUECKE:
						frei = true
				if frei:
					continue
				var g0 := p0 + aussen * GELAENDER_ABSTAND
				var g1 := p1 + aussen * GELAENDER_ABSTAND
				_quader(gel, g0, g1, 0.1, GELAENDER_H - 0.08, 0.08)
				_quader(gel, g0, g1, 0.05, GELAENDER_H * 0.5, 0.05)
				_quader(gel, g0, g0 + laengs * GELAENDER_PFOSTEN, GELAENDER_PFOSTEN, 0.0, GELAENDER_H)
				_quader(neon, g0, g1, 0.06, GELAENDER_H - 0.16, 0.05)
				var cs := CollisionShape3D.new()
				var form := BoxShape3D.new()
				form.size = Vector3(0.2, GELAENDER_H, g0.distance_to(g1))
				cs.shape = form
				cs.transform = Transform3D(Basis.looking_at(Vector3(laengs.x, 0.0, laengs.y), Vector3.UP), Vector3(pm.x + aussen.x * GELAENDER_ABSTAND, GELAENDER_H * 0.5, pm.y + aussen.y * GELAENDER_ABSTAND))
				gel_koerper.add_child(cs)
		_dreiecke(wand, m_kai, true)
		_dreiecke(stein, m_kai, false)
		_dreiecke(gel, m_gelaender, false)
		_dreiecke(neon, m_gel_neon, false).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Durchlaesse am Stadtrand: Stirnwand mit dunklem Tunnelmund
		for ende in [0, linien_f[f].size() - 1]:
			var pe: Vector2 = linien_f[f][ende]
			var nach: Vector2 = linien_f[f][1 if ende == 0 else ende - 1]
			var zr := -1.0 if ende == 0 else 1.0
			var x := pe.x + (pe.x - nach.x) / (pe.y - nach.y) * (zr * (PLATTE / 2.0 - 2.0) - pe.y)
			_box(Vector3(x, 1.5, zr * (PLATTE / 2.0 - 1.0)), Vector3(FLUSS_BREITE + 14.0, FLUSS_TIEFE * 2.0 + 3.0, 2.0), m_kai)
			_box(Vector3(x, -0.6, zr * (PLATTE / 2.0 - 2.05)), Vector3(FLUSS_BREITE - 1.0, FLUSS_TIEFE + 1.2, 0.1), _std(Color(0.0, 0.0, 0.0), 0.0, 0.0, 1.0), false)


## Strassennetz mit Bruecken, Kreuzungen, Ampeln, Laternen, Schildern und Bodenverkehr
## (levels/strassennetz.gd). Die Daten stehen in levels/strassen_daten.gd.
func _strassen() -> void:
	var netz := Node3D.new()
	netz.name = "Strassennetz"
	netz.set_script(load("res://levels/strassennetz.gd"))
	netz.set("fluesse", [_fluss_ost(), _fluss_west()])
	netz.set("fluss_breite", FLUSS_BREITE)
	netz.set("fluss_tiefe", FLUSS_TIEFE)
	netz.set("aussparungen", kreise)
	add_child(netz)
	_netz = netz


# ---------------------------------------------------------------- Aero-Stadtring

func _ring_pt(theta: float, s := 1.0) -> Vector3:
	return Vector3(RING_RX * s * cos(theta), RING_H, RING_M.y + RING_RZ * s * sin(theta))


func _ring() -> void:
	var n := 96
	for i in n:
		var a := _ring_pt(TAU * i / n)
		var b := _ring_pt(TAU * (i + 1) / n)
		_balken(a, b, 16.0, 1.2, m_ring)
		var seitlich := (b - a).cross(Vector3.UP).normalized() * 7.8
		for sg in [-1.0, 1.0]:
			_balken(a + seitlich * sg + Vector3(0, 0.15, 0), b + seitlich * sg + Vector3(0, 0.15, 0), 0.5, 0.3, m_cyan, false)
		# Stuetzen stehen weder auf Strassen noch im Flussbett
		if i % 6 == 0 and not _auf_linien(a.x, a.z, 2.0):
			_zyl(Vector3(a.x, (RING_H - 1.2) / 2.0, a.z), 1.6, RING_H - 1.2, m_ring, true, 12)
	# Auffahrten
	for grad in [30.0, 150.0, 210.0, 330.0]:
		var p := _ring_pt(deg_to_rad(grad))
		var q := Vector3(RING_M.x + (p.x - RING_M.x) * 0.5, 0.1, RING_M.y + (p.z - RING_M.y) * 0.5)
		_balken(q, p, 12.0, 1.0, m_ring)
		linien.append([PackedVector2Array([Vector2(q.x, q.z), Vector2(p.x, p.z)]), 14.0])
	# fliegende Autos: drei Meshy-Modelle (auto_truck, auto_flitzer, auto_sportwagen), verschieden eingefaerbt.
	# Die Modelle schauen entlang -X und sind ca. 1,9 m lang, daher drehen und vergroessern.
	var farben := [Color(0.2, 0.9, 1.0), Color(1.0, 0.2, 0.8), Color(1.0, 0.8, 0.2), Color(1.0, 0.25, 0.2)]
	var tints := [Color(1, 1, 1), Color(1.0, 0.6, 0.95), Color(0.6, 0.9, 1.0), Color(1.0, 0.85, 0.5), Color(1.0, 0.55, 0.5), Color(0.7, 1.0, 0.75)]
	var auto_szenen: Array[PackedScene] = []
	for name in ["auto_truck", "auto_flitzer", "auto_sportwagen"]:
		var ps := load("res://imported_models/%s/%s.glb" % [name, name]) as PackedScene
		auto_szenen.append(ps)
	for i in 12:
		var f: Color = farben[i % 4]
		var car := Node3D.new()
		var modell: Node3D = auto_szenen[i % 3].instantiate()
		modell.rotation_degrees.y = -90.0
		modell.scale = Vector3.ONE * 2.4
		car.add_child(modell)
		_auto_einfaerben(modell, tints[(i / 3 + i) % tints.size()])
		var glow := MeshInstance3D.new()
		var gm := BoxMesh.new()
		gm.size = Vector3(1.8, 0.1, 3.6)
		glow.mesh = gm
		glow.material_override = _std(f, 4.0)
		glow.position = Vector3(0, -0.75, 0)
		glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		car.add_child(glow)
		add_child(car)
		var richtung := 1.0 if i % 2 == 0 else -1.0
		autos.append({
			"node": car,
			"winkel": rng.randf() * TAU,
			"tempo": richtung * rng.randf_range(0.10, 0.16),
			"spur": 1.0 + 0.028 * richtung,
		})


## Faerbt die Materialien eines Auto-Modells ein (Kopie, Textur bleibt) und spart Schatten/Fernsicht.
func _auto_einfaerben(wurzel: Node, tint: Color) -> void:
	for mi in wurzel.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.visibility_range_end = 500.0
		m.visibility_range_end_margin = 60.0
		m.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		for sfl in m.mesh.get_surface_count():
			var mat := m.mesh.surface_get_material(sfl)
			if mat is StandardMaterial3D:
				var k: StandardMaterial3D = mat.duplicate()
				k.albedo_color = tint
				if k.emission_enabled:
					k.emission = k.emission * tint
				m.set_surface_override_material(sfl, k)


# ---------------------------------------------------------------- Wahrzeichen

func _plaza() -> void:
	var c := Vector3(0, 0, 70)
	_zyl(c + Vector3(0, 0.09, 0), 58.0, 0.18, m_cyan, false, 64)
	_zyl(c + Vector3(0, 0.11, 0), 55.0, 0.22, m_stein, false, 64)
	_zyl(c + Vector3(0, 0.12, 0), 40.0, 0.24, m_gold, false, 64)
	_zyl(c + Vector3(0, 0.13, 0), 38.0, 0.26, m_stein, false, 64)
	# Obelisk
	var ob := _zyl(c + Vector3(0, 25.0, 0), 3.2, 50.0, _std(Color(0.1, 0.12, 0.2), 0.0, 0.9, 0.2), false, 4, 0.9)
	ob.rotation_degrees.y = 45.0
	var os := Node3D.new()
	os.position = c + Vector3(0, 25.0, 0)
	add_child(os)
	_kollision(os, Vector3(4.5, 50.0, 4.5))
	var spitze := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 2.0
	sp.height = 4.0
	spitze.mesh = sp
	spitze.material_override = m_cyan
	spitze.position = c + Vector3(0, 52.0, 0)
	add_child(spitze)
	_licht(c + Vector3(0, 53.0, 0), Color(0.3, 0.9, 1.0), 5.0, 80.0)
	# vier Runen-Felder
	var runen := [
		[Vector3(-26, 0, 45), Color(0.2, 0.4, 1.0)],
		[Vector3(26, 0, 45), Color(1.0, 0.15, 0.1)],
		[Vector3(-26, 0, 95), Color(1.0, 0.85, 0.15)],
		[Vector3(26, 0, 95), Color(1.0, 0.35, 0.1)],
	]
	for r in runen:
		_zyl(r[0] + Vector3(0, 0.32, 0), 8.0, 0.12, _std(r[1], 3.0), false, 6)
		_zyl(r[0] + Vector3(0, 0.34, 0), 5.5, 0.12, _std(r[1].darkened(0.5), 1.0), false, 6)
		_licht(r[0] + Vector3(0, 3.0, 0), r[1], 3.0, 28.0)


func _park() -> void:
	# Central Park: eigenes Skript (park.gd) baut Wege, Teich, Pavillons, Baeume, Fauna
	var p := Node3D.new()
	p.name = "Park"
	p.set_script(load("res://park.gd"))
	add_child(p)


func _turm() -> void:
	var silber := m_silber_turm
	var tiers := [[Vector3(34, 90, 34), 45.0], [Vector3(26, 70, 26), 125.0], [Vector3(18, 46, 18), 197.0]]
	for i in tiers.size():
		var g: Vector3 = tiers[i][0]
		var ym: float = tiers[i][1]
		if i < 2:
			_huelle(g, ym, silber, i == 0)
		else:
			_box(Vector3(TURM.x, ym, TURM.y), g, silber)
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				_box(Vector3(TURM.x + sx * g.x / 2.0, ym, TURM.y + sz * g.z / 2.0), Vector3(0.7, g.y, 0.7), m_cyan_turm, false)
	_lobby()
	var etagen := _buero_etagen()
	_hq()
	_zyl(Vector3(TURM.x, 265.0, TURM.y), 9.0, 90.0, _std(Color(0.3, 0.32, 0.36), 0.0, 0.9, 0.3), false, 8, 0.3)
	# Kein Leuchtstrahl mehr (Business-Look): nur die rote Flugwarnleuchte an der Spitze
	_licht(Vector3(TURM.x, 310.0, TURM.y), Color(1, 0.2, 0.2), 3.0, 90.0)
	_licht(Vector3(TURM.x, 60.0, TURM.y + 26.0), Color(0.85, 0.9, 1.0), 0.8, 36.0)  # Fassadenlicht, kurze Reichweite (sonst leuchtet es in die Lobby)
	_aufzug(etagen)


## Hohle Turmstufe aus vier Waenden (je WAND_DICKE_TURM stark). Mit `tuer` hat die Suedwand ein Tor (Eingang).
func _huelle(g: Vector3, ym: float, mat: Material, tuer: bool) -> void:
	var w := WAND_DICKE_TURM
	var hx := g.x * 0.5
	var hz := g.z * 0.5
	_box(Vector3(TURM.x, ym, TURM.y - hz + w * 0.5), Vector3(g.x, g.y, w), mat)
	_box(Vector3(TURM.x - hx + w * 0.5, ym, TURM.y), Vector3(w, g.y, g.z - 2.0 * w), mat)
	_box(Vector3(TURM.x + hx - w * 0.5, ym, TURM.y), Vector3(w, g.y, g.z - 2.0 * w), mat)
	var zs := TURM.y + hz - w * 0.5
	if not tuer:
		_box(Vector3(TURM.x, ym, zs), Vector3(g.x, g.y, w), mat)
		return
	var seite := (g.x - TUER_BREITE) * 0.5
	for sx in [-1.0, 1.0]:
		_box(Vector3(TURM.x + sx * (TUER_BREITE * 0.5 + seite * 0.5), ym, zs), Vector3(seite, g.y, w), mat)
	var sturz := g.y - TUER_HOEHE
	_box(Vector3(TURM.x, ym - g.y * 0.5 + TUER_HOEHE + sturz * 0.5, zs), Vector3(TUER_BREITE, sturz, w), mat)


## Platte mit quadratischem Loch (fuer den Aufzugsschacht): vier Streifen um das Loch.
## x0..x1 / z0..z1 = Aussenkante der Platte, `loch` = Mitte (x, z) des Lochs, `loch_groesse` = Kantenlaenge.
func _platte_mit_loch(x0: float, x1: float, z0: float, z1: float, y: float, dicke: float, loch: Vector2, loch_groesse: float, mat: Material, kollision := true) -> void:
	var h := loch_groesse * 0.5
	var lx0 := loch.x - h
	var lx1 := loch.x + h
	var lz0 := loch.y - h
	var lz1 := loch.y + h
	var teile := [
		[x0, x1, z0, lz0],     # Nord
		[x0, x1, lz1, z1],     # Sued
		[x0, lx0, lz0, lz1],   # West
		[lx1, x1, lz0, lz1],   # Ost
	]
	for t in teile:
		if t[1] - t[0] <= 0.001 or t[3] - t[2] <= 0.001:
			continue
		_box(Vector3((t[0] + t[1]) * 0.5, y, (t[2] + t[3]) * 0.5), Vector3(t[1] - t[0], dicke, t[3] - t[2]), mat, kollision)


## Eingangshalle (innen): Boden, Decke mit Schachtloch, Leitstreifen vom Tor zum Aufzug, Beschriftung, Licht.
func _lobby() -> void:
	var r := TURM.x - 15.0
	var e := TURM.x + 15.0
	var n := TURM.y - 15.0
	var sued := TURM.y + 15.0
	var loch := Vector2(TURM.x, TURM.y + AUFZUG_VERSATZ_Z)
	var marmor := _tex_mat("marble_01", 2.4, Color(0.92, 0.92, 0.94), 0.05)
	var beton := _tex_mat("brushed_concrete_04", 3.0, Color(0.7, 0.72, 0.76), 0.0)
	var wand := _tex_mat("foyer_painted_plaster_wall", 3.0, Color(1.25, 1.2, 1.12), 0.0)
	var holz := _tex_mat("foyer_dark_wood", 1.6, Color(0.85, 0.78, 0.7), 0.0)
	_platte_mit_loch(r, e, n, sued, 0.03, 0.06, loch, AUFZUG_SCHACHT, marmor, false)
	_platte_mit_loch(r, e, n, sued, LOBBY_HOEHE + DECKE_DICKE * 0.5, DECKE_DICKE, loch, AUFZUG_SCHACHT, beton)
	_platte_mit_loch(r, e, n, sued, 90.0 - DECKE_DICKE * 0.5, DECKE_DICKE, loch, AUFZUG_SCHACHT, beton)
	_platte_mit_loch(TURM.x - 11.0, TURM.x + 11.0, TURM.y - 11.0, TURM.y + 11.0, 160.0 - DECKE_DICKE * 0.5, DECKE_DICKE, loch, AUFZUG_SCHACHT, beton)
	# Wandverkleidung innen (Putz mit Marmorsockel), Suedwand um das Tor ausgespart
	var wd := 0.1
	_box(Vector3(TURM.x, LOBBY_HOEHE * 0.5, n + wd * 0.5), Vector3(30.0, LOBBY_HOEHE, wd), wand, false)
	_box(Vector3(TURM.x, 0.6, n + wd + 0.03), Vector3(30.0, 1.2, 0.06), marmor, false)
	for sx in [-1.0, 1.0]:
		_box(Vector3(TURM.x + sx * (15.0 - wd * 0.5), LOBBY_HOEHE * 0.5, TURM.y), Vector3(wd, LOBBY_HOEHE, 30.0), wand, false)
		_box(Vector3(TURM.x + sx * (15.0 - wd - 0.03), 0.6, TURM.y), Vector3(0.06, 1.2, 30.0), marmor, false)
		var br := 15.0 - TUER_BREITE * 0.5
		_box(Vector3(TURM.x + sx * (TUER_BREITE * 0.5 + br * 0.5), LOBBY_HOEHE * 0.5, sued - wd * 0.5), Vector3(br, LOBBY_HOEHE, wd), wand, false)
	# Empfangstresen (Holz, Marmorplatte) mit Bildschirm, zwei Pflanzen
	_box(Vector3(TURM.x - 8.0, 0.55, TURM.y + 4.0), Vector3(5.0, 1.1, 1.0), holz, true)
	_box(Vector3(TURM.x - 8.0, 1.12, TURM.y + 4.0), Vector3(5.2, 0.06, 1.2), marmor, false)
	_box(Vector3(TURM.x - 8.0, 1.5, TURM.y + 3.8), Vector3(0.6, 0.38, 0.04), _std(Color(0.05, 0.06, 0.08), 0.3, 0.3), false)
	# Leitstreifen vom Tor zum Aufzug
	var schacht_front := loch.y + AUFZUG_SCHACHT * 0.5 + 0.5
	var tor_z := TURM.y + 17.0
	_box(Vector3(TURM.x, 0.07, (schacht_front + tor_z) * 0.5), Vector3(0.3, 0.02, tor_z - schacht_front), m_cyan_turm, false)
	# Tor: Pfosten und Sturzleiste in Cyan, Schriftzug darueber
	for sx in [-1.0, 1.0]:
		_box(Vector3(TURM.x + sx * (TUER_BREITE * 0.5 + 0.2), TUER_HOEHE * 0.5, tor_z + 0.1), Vector3(0.4, TUER_HOEHE, 0.5), m_cyan_turm, false)
	_box(Vector3(TURM.x, TUER_HOEHE + 0.2, tor_z + 0.1), Vector3(TUER_BREITE + 0.8, 0.4, 0.5), m_cyan_turm, false)
	# Licht: Halle hell, Tor einladend
	_licht(Vector3(TURM.x, LOBBY_HOEHE - 2.0, TURM.y), Color(1.0, 0.95, 0.88), 3.0, 26.0)
	_licht(Vector3(TURM.x, 4.0, TURM.y + 12.0), Color(1.0, 0.95, 0.88), 1.4, 14.0)
	_licht(Vector3(TURM.x, 4.0, tor_z + 4.0), Color(1.0, 0.95, 0.88), 1.4, 12.0)
	_foyer(marmor, holz, wand)
	# Gelaender um die Tier-2-Terrasse (die HQ-Tuer fuehrt auf den Rand dieser Stufe)
	var rand := 13.0
	for sz in [-1.0, 1.0]:
		_box(Vector3(TURM.x, 160.0 + 0.6, TURM.y + sz * (rand - 0.1)), Vector3(2.0 * rand, 1.2, 0.2), m_cyan_turm)
	for sx in [-1.0, 1.0]:
		_box(Vector3(TURM.x + sx * (rand - 0.1), 160.0 + 0.6, TURM.y), Vector3(0.2, 1.2, 2.0 * rand - 0.4), m_cyan_turm)


## Klassisches Buero-Foyer: Marmorboden mit dunklem Intarsienrahmen, Saeulen, Empfang mit Logowand, Sicherheitsschleuse
## vor dem Aufzug, Sitzgruppe mit Teppich, Pflanzen, Infotafel, Deckenleuchten.
func _foyer(marmor: Material, holz: Material, wand: Material) -> void:
	var cx := TURM.x
	var cz := TURM.y
	var stahl := _std(Color(0.55, 0.57, 0.62), 0.0, 0.9, 0.25)
	stahl.disable_ambient_light = true
	var dunkel := _std(Color(0.07, 0.08, 0.1), 0.0, 0.5, 0.35)
	dunkel.disable_ambient_light = true
	var granit := _tex_mat("foyer_granite_tile", 2.0, Color(0.7, 0.7, 0.75), 0.15)
	var paneel := _tex_mat("foyer_dark_paneled_wood", 1.6, Color(0.9, 0.85, 0.8), 0.0)
	var leder := _tex_mat("foyer_brown_leather", 0.8, Color(0.9, 0.85, 0.8), 0.0)
	var teppich := _tex_mat("buero_teppich", 1.5, Color(0.6, 0.65, 0.75), 0.0)
	var blatt := _std(Color(0.12, 0.35, 0.14), 0.0, 0.0, 0.8)
	blatt.disable_ambient_light = true
	var topf := _std(Color(0.8, 0.8, 0.82), 0.0, 0.1, 0.5)
	topf.disable_ambient_light = true
	var licht_mat := _std(Color(1.0, 0.96, 0.88), 1.2)
	licht_mat.disable_ambient_light = true
	var glas := _std(Color(0.7, 0.88, 1.0, 0.18), 0.0, 0.0, 0.05)
	glas.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Bodenintarsie: dunkler Rahmen und Mittelbahn vom Eingang zur Schleuse
	for sz in [-1.0, 1.0]:
		_box(Vector3(cx, 0.07, cz + sz * 13.6), Vector3(27.4, 0.02, 0.5), granit, false)
	for sx in [-1.0, 1.0]:
		_box(Vector3(cx + sx * 13.6, 0.07, cz), Vector3(0.5, 0.02, 27.4), granit, false)
	_box(Vector3(cx, 0.07, cz + 9.0), Vector3(1.0, 0.02, 12.0), granit, false)
	# Holzpaneele als Wandsockel (bis 1,3 m) mit Leiste, an Nord-, West- und Ostwand
	_box(Vector3(cx, 0.65, cz - 14.82), Vector3(29.6, 1.3, 0.1), paneel, false)
	_box(Vector3(cx, 1.33, cz - 14.8), Vector3(29.6, 0.06, 0.14), holz, false)
	for sx in [-1.0, 1.0]:
		_box(Vector3(cx + sx * 14.82, 0.65, cz), Vector3(0.1, 1.3, 29.6), paneel, false)
		_box(Vector3(cx + sx * 14.8, 1.33, cz), Vector3(0.14, 0.06, 29.6), holz, false)
	# Saeulen (Marmor, mit Stahlmanschette)
	for p in [Vector2(-10, 9), Vector2(10, 9), Vector2(-10, -11), Vector2(10, -11)]:
		_box(Vector3(cx + p.x, LOBBY_HOEHE * 0.5, cz + p.y), Vector3(1.1, LOBBY_HOEHE, 1.1), marmor, true)
		_box(Vector3(cx + p.x, 0.25, cz + p.y), Vector3(1.3, 0.5, 1.3), granit, false)
		_box(Vector3(cx + p.x, LOBBY_HOEHE - 0.2, cz + p.y), Vector3(1.3, 0.4, 1.3), stahl, false)
	# Empfang: Logowand dahinter, zwei Stuehle, Lampe
	_box(Vector3(cx - 8.0, 2.0, cz + 1.9), Vector3(6.2, 4.0, 0.2), holz, false)
	_box(Vector3(cx - 8.0, 0.1, cz + 1.9), Vector3(6.4, 0.2, 0.3), granit, false)
	for sx in [-1.0, 1.0]:
		_box(Vector3(cx - 8.0 + sx * 1.4, 0.55, cz + 2.9), Vector3(0.6, 0.1, 0.6), dunkel, false)
		_box(Vector3(cx - 8.0 + sx * 1.4, 1.0, cz + 2.65), Vector3(0.6, 0.9, 0.1), dunkel, false)
		_zyl(Vector3(cx - 8.0 + sx * 1.4, 0.27, cz + 2.9), 0.05, 0.54, stahl, false, 8)
	# Sicherheitsschleuse vor dem Aufzug: Mittelgasse 3 m, Glasflaechen und Stahlsaeulen
	var sz0 := cz + 1.5
	for sx in [-1.0, 1.0]:
		_box(Vector3(cx + sx * 1.5, 0.55, sz0), Vector3(0.3, 1.1, 1.0), stahl, true)
		_box(Vector3(cx + sx * 1.5, 1.12, sz0), Vector3(0.32, 0.04, 1.02), _std(Color(0.3, 0.9, 0.5), 1.2), false)
		_box(Vector3(cx + sx * 3.4, 0.8, sz0), Vector3(3.4, 1.6, 0.06), glas, true)
		_box(Vector3(cx + sx * 3.4, 1.62, sz0), Vector3(3.4, 0.05, 0.1), stahl, false)
	# Sitzgruppe (Ost): Teppich, zwei Sofas, Couchtisch
	_box(Vector3(cx + 8.5, 0.09, cz + 5.0), Vector3(7.0, 0.04, 5.0), teppich, false)
	for sz in [-1.0, 1.0]:
		_box(Vector3(cx + 8.5, 0.35, cz + 5.0 + sz * 2.0), Vector3(3.2, 0.5, 1.0), leder, true)
		_box(Vector3(cx + 8.5, 0.85, cz + 5.0 + sz * 2.4), Vector3(3.2, 0.7, 0.25), leder, false)
	_box(Vector3(cx + 8.5, 0.3, cz + 5.0), Vector3(1.6, 0.06, 0.9), holz, true)
	for sx in [-1.0, 1.0]:
		_box(Vector3(cx + 8.5 + sx * 0.7, 0.15, cz + 5.0), Vector3(0.08, 0.3, 0.8), stahl, false)
	# Pflanzen
	for p in [Vector2(-13.5, 12.5), Vector2(13.5, 12.5), Vector2(-13.5, -13.5), Vector2(13.5, -13.5), Vector2(4.5, 8.0), Vector2(-4.5, 8.0), Vector2(12.0, 1.0)]:
		_zyl(Vector3(cx + p.x, 0.45, cz + p.y), 0.5, 0.9, topf, true, 16)
		_zyl(Vector3(cx + p.x, 1.0, cz + p.y), 0.04, 0.6, dunkel, false, 6)
		for k in 9:
			var a := k * TAU / 9.0
			var hh := 1.25 + 0.35 * float(k % 3)
			_blatt_kugel(Vector3(cx + p.x + cos(a) * 0.32, hh, cz + p.y + sin(a) * 0.32), 0.34, blatt)
		_blatt_kugel(Vector3(cx + p.x, 2.1, cz + p.y), 0.45, blatt)
	# Infotafel (Ost) und Uhr (West)
	_box(Vector3(cx + 14.85, 3.0, cz - 3.0), Vector3(0.12, 2.6, 4.0), dunkel, false)
	_zyl(Vector3(cx - 14.85, 5.5, cz - 8.0), 0.6, 0.08, stahl, false, 24).rotation_degrees.z = 90.0
	# Mechy McBoom: Wachmech, patrouilliert vor dem Empfang (Rundkurs, nordlich der Eingangstuer, zwischen Saeulen und Pflanzen)
	var mechy := CharacterBody3D.new()
	mechy.name = "MechyMcBoom"
	mechy.set_script(load("res://characters/mechy.gd"))
	var route := PackedVector3Array([Vector3(cx - 11.0, 0.04, cz + 11.5), Vector3(cx + 7.0, 0.04, cz + 11.5), Vector3(cx + 7.0, 0.04, cz + 14.0), Vector3(cx - 11.0, 0.04, cz + 14.0)])
	mechy.set("wegpunkte", route)
	mechy.position = route[0]
	add_child(mechy)
	# Abgehaengte Decke (helle Deckenplatten) unter der Betonplatte, mit Schachtloch
	var deckenplatte := _tex_mat("buero_decke", 1.2, Color(1, 1, 1), 0.0)
	_platte_mit_loch(cx - 14.9, cx + 14.9, cz - 14.9, cz + 14.9, LOBBY_HOEHE - 0.05, 0.05, Vector2(cx, cz + AUFZUG_VERSATZ_Z), AUFZUG_SCHACHT, deckenplatte, false)
	# Deckenleuchten (Raster) und ruhiges Grundlicht
	for ix in range(-3, 4):
		for iz in range(-3, 4):
			var lp := Vector3(cx + ix * 4.0, LOBBY_HOEHE - 0.1, cz + iz * 4.0)
			if absf(lp.x - cx) < 3.0 and absf(lp.z - (cz + AUFZUG_VERSATZ_Z)) < 3.5:
				continue
			_box(lp, Vector3(1.6, 0.06, 1.6), licht_mat, false)
	for lp in [Vector2(-7, 6), Vector2(7, 6), Vector2(0, -9), Vector2(-9, -9), Vector2(9, -9), Vector2(0, 11)]:
		_licht(Vector3(cx + lp.x, 6.5, cz + lp.y), Color(1.0, 0.95, 0.86), 2.2, 13.0)


## Buero-Etagen in den Turmstufen (levels/buero_etage.gd). Liefert Hoehen und Namen aller Haltepunkte fuers
## Aufzug-Terminal: Lobby, alle Etagen, HQ.
func _buero_etagen() -> Dictionary:
	var ys := PackedFloat32Array([0.0])
	var namen := PackedStringArray(["LOBBY"])
	var nr := 0
	for stufe in 2:
		var start := ETAGEN_START_1 if stufe == 0 else ETAGEN_START_2
		var anzahl := ETAGEN_ANZAHL_1 if stufe == 0 else ETAGEN_ANZAHL_2
		var halb := INNEN_HALB_1 if stufe == 0 else INNEN_HALB_2
		for k in anzahl:
			var layout := ETAGEN_LAYOUTS[nr % ETAGEN_LAYOUTS.size()]
			nr += 1
			var e := Node3D.new()
			e.set_script(load("res://levels/buero_etage.gd"))
			e.set("layout", layout)
			e.set("nummer", nr)
			e.set("halbe_breite", halb)
			e.set("hat_decke", k > 0)
			e.set("schacht_mitte", Vector2(0.0, AUFZUG_VERSATZ_Z))
			e.set("schacht", AUFZUG_SCHACHT)
			e.position = Vector3(TURM.x, start + k * ETAGEN_ABSTAND, TURM.y)
			add_child(e)
			ys.append(start + k * ETAGEN_ABSTAND)
			namen.append("ETAGE %d  %s" % [nr, ["GROSSRAUMBÜRO", "KONFERENZ", "KANTINE", "RECHENZENTRUM"][layout]])
	ys.append(AUFZUG_OBEN)
	namen.append("HQ ZAUBER-MAN")
	return {"y": ys, "name": namen}


## Texturiertes Aussenmaterial (Welt-Triplanar, damit Kacheln ueber Bauteilgrenzen hinweg passen).
func _aussen_mat(ordner: String, kachel: float, tint: Color, metall: float) -> StandardMaterial3D:
	var t := _tex_mat(ordner, kachel, tint, metall)
	t.uv1_world_triplanar = true
	t.disable_ambient_light = false
	return t


func _tex_mat(ordner: String, kachel: float, tint: Color, metall: float) -> StandardMaterial3D:
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
	t.disable_ambient_light = true  # Innenraum: kein Himmels-Ambient
	return t


## Aufzug mitten im Turm (levels/aufzug.gd): Lobby (y 0) bis HQ-Boden. Die Schachtloecher in Decken und HQ-Boden
## bauen _lobby() und _hq(). Ersetzt die frueher umlaufende Licht-Bahn (Wendel).
func _aufzug(etagen: Dictionary) -> void:
	var lift := Node3D.new()
	lift.name = "Aufzug"
	lift.set_script(load("res://levels/aufzug.gd"))
	lift.position = Vector3(TURM.x, 0.0, TURM.y + AUFZUG_VERSATZ_Z)
	lift.set("oben_y", AUFZUG_OBEN)
	lift.set("schacht_groesse", AUFZUG_SCHACHT)
	lift.set("etagen_y", etagen["y"])
	lift.set("etagen_name", etagen["name"])
	add_child(lift)


func _hq() -> void:
	var cx := TURM.x
	var cz := TURM.y
	var fb := HQ_BODEN
	var hoehe := HQ_DECKE - fb
	var glas := _std(Color(0.55, 0.85, 1.0, 0.2), 0.0, 0.1, 0.05)
	glas.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var wy := fb + hoehe / 2.0
	# Boden
	var loch := Vector2(cx, cz + AUFZUG_VERSATZ_Z)
	_platte_mit_loch(cx - 9.0, cx + 9.0, cz - 9.0, cz + 9.0, fb - 0.1, 0.2, loch, AUFZUG_SCHACHT, _std(Color(0.06, 0.07, 0.1), 0.0, 0.9, 0.2))
	# Boden-Ring um den Holo-Tisch, nach Sueden verschoben, damit er nicht ueber dem Aufzugsschacht liegt
	_zyl(Vector3(cx, fb + 0.03, cz + 2.6), 4.5, 0.06, m_gold_turm, false, 48)
	_zyl(Vector3(cx, fb + 0.04, cz + 2.6), 4.2, 0.08, _std(Color(0.06, 0.07, 0.1), 0.0, 0.9, 0.2), false, 48)
	# Glaswaende: Nord, Ost, West
	_box(Vector3(cx, wy, cz - 8.5), Vector3(18, hoehe, 1), glas)
	_box(Vector3(cx + 8.5, wy, cz), Vector3(1, hoehe, 18), glas)
	_box(Vector3(cx - 8.5, wy, cz), Vector3(1, hoehe, 18), glas)
	# Suedwand mit Tueroeffnung (5 m breit, 4,5 m hoch)
	var wz := cz + 8.5
	_box(Vector3(cx - 5.75, wy, wz), Vector3(6.5, hoehe, 1), glas)
	_box(Vector3(cx + 5.75, wy, wz), Vector3(6.5, hoehe, 1), glas)
	var sturz := hoehe - 4.5
	_box(Vector3(cx, fb + 4.5 + sturz / 2.0, wz), Vector3(5, sturz, 1), glas)
	# Pfosten
	for px in [-9.0, -3.0, 3.0, 9.0]:
		for pz in [-9.0, 9.0]:
			_box(Vector3(cx + px, wy, cz + pz), Vector3(0.5, hoehe, 0.5), m_cyan_turm, false)
	for pz in [-3.0, 3.0]:
		for px in [-9.0, 9.0]:
			_box(Vector3(cx + px, wy, cz + pz), Vector3(0.5, hoehe, 0.5), m_cyan_turm, false)
	# Tuer: fast unsichtbar, gleitet nach oben
	hq_tuer_pos = Vector3(cx, fb + 2.25, wz)
	hq_tuer = _box(hq_tuer_pos, Vector3(5, 4.5, 0.5), _std(Color(0.1, 0.4, 0.6, 0.35), 1.2, 0.5, 0.1))
	hq_tuer.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hq_hinweis = _text("[E] Geheimspruch sprechen", Vector3(cx, fb + 6.5, wz + 1.5), Color(1.0, 0.85, 0.3), 0.012)
	Eingabe.hinweis_binden(hq_hinweis, "interagieren", "[%s] Geheimspruch sprechen")
	hq_hinweis.visible = false
	# Beleuchtung
	_licht(Vector3(cx, HQ_DECKE - 1.5, cz), Color(1.0, 0.92, 0.8), 2.5, 24.0)
	_licht(Vector3(cx, fb + 2.0, cz), Color(0.7, 0.88, 1.0), 0.8, 14.0)

	# Holo-Tisch in der Mitte
	var tisch := _zyl(Vector3(cx, fb + 0.5, cz + 0.5), 2.0, 1.0, _std(Color(0.08, 0.09, 0.14), 0.0, 0.9, 0.2), true, 24)
	_zyl(Vector3(cx, fb + 1.03, cz + 0.5), 1.8, 0.06, m_cyan_turm, false, 24)
	hq_holo = Node3D.new()
	hq_holo.position = Vector3(cx, fb + 2.3, cz + 0.5)
	add_child(hq_holo)
	var holo_mat := _std(Color(0.3, 0.9, 1.0, 0.45), 1.2)
	holo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for i in 7:
		var m := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var hh := rng.randf_range(0.3, 1.2)
		bm.size = Vector3(0.25, hh, 0.25)
		m.mesh = bm
		m.material_override = holo_mat
		m.position = Vector3(rng.randf_range(-1.0, 1.0), hh / 2.0 - 0.6, rng.randf_range(-1.0, 1.0))
		hq_holo.add_child(m)
	var turm_holo := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.02
	tm.bottom_radius = 0.12
	tm.height = 1.8
	turm_holo.mesh = tm
	turm_holo.material_override = holo_mat
	turm_holo.position = Vector3(0, 0.3, 0)
	hq_holo.add_child(turm_holo)
	_licht(hq_holo.position, Color(0.6, 0.88, 1.0), 0.8, 8.0)

	# Ruestungs-Ladestation (rot-gold), hinten links
	var rot_metall := _std(Color(0.75, 0.06, 0.05), 0.25, 0.9, 0.25)
	var gold_metall := _std(Color(1.0, 0.75, 0.2), 0.6, 0.9, 0.2)
	var ar := Node3D.new()
	ar.position = Vector3(cx - 5.5, fb, cz - 4.0)
	add_child(ar)
	var sockel := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 1.6
	sm.bottom_radius = 1.6
	sm.height = 0.4
	sockel.mesh = sm
	sockel.material_override = m_gold_turm
	sockel.position = Vector3(0, 0.2, 0)
	ar.add_child(sockel)
	var teile := [
		[Vector3(-0.4, 0.9, 0), Vector3(0.5, 1.4, 0.5), rot_metall],
		[Vector3(0.4, 0.9, 0), Vector3(0.5, 1.4, 0.5), rot_metall],
		[Vector3(0, 2.35, 0), Vector3(1.5, 1.7, 0.9), rot_metall],
		[Vector3(-1.1, 2.4, 0), Vector3(0.4, 1.5, 0.4), gold_metall],
		[Vector3(1.1, 2.4, 0), Vector3(0.4, 1.5, 0.4), gold_metall],
		[Vector3(0, 1.45, 0), Vector3(1.0, 0.25, 0.7), gold_metall],
	]
	for t in teile:
		var m := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = t[1]
		m.mesh = bm
		m.material_override = t[2]
		m.position = t[0]
		ar.add_child(m)
	for kugel in [[Vector3(0, 3.55, 0), 0.45, gold_metall], [Vector3(-1.0, 3.0, 0), 0.55, gold_metall], [Vector3(1.0, 3.0, 0), 0.55, gold_metall], [Vector3(0, 2.4, 0.5), 0.3, m_gold_turm]]:
		var m := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = kugel[1]
		sp.height = kugel[1] * 2.0
		m.mesh = sp
		m.material_override = kugel[2]
		m.position = kugel[0]
		ar.add_child(m)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var strahl := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.05
			cm.bottom_radius = 0.05
			cm.height = 5.0
			strahl.mesh = cm
			strahl.material_override = m_cyan_turm
			strahl.position = Vector3(sx * 1.5, 2.5, sz * 1.5)
			ar.add_child(strahl)
	_licht(ar.position + Vector3(0, 3.0, 1.5), Color(1.0, 0.6, 0.2), 2.0, 10.0)

	# Hoverboard-Werkbank, hinten rechts
	_box(Vector3(cx + 5.0, fb + 0.5, cz - 3.5), Vector3(4, 1, 2), _std(Color(0.12, 0.13, 0.18), 0.0, 0.8, 0.3))
	_box(Vector3(cx + 3.3, fb + 1.15, cz - 3.0), Vector3(0.5, 0.3, 0.4), m_gold_turm, false)
	_box(Vector3(cx + 6.4, fb + 1.1, cz - 4.0), Vector3(0.7, 0.2, 0.3), m_rot, false)
	hq_brett = Node3D.new()
	hq_brett_y = fb + 2.2
	hq_brett.position = Vector3(cx + 5.0, hq_brett_y, cz - 3.5)
	add_child(hq_brett)
	var brett := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(3.4, 0.16, 0.9)
	brett.mesh = bb
	brett.material_override = _std(Color(0.15, 0.2, 0.5), 0.5, 0.9, 0.2)
	hq_brett.add_child(brett)
	var streifen := MeshInstance3D.new()
	var sb := BoxMesh.new()
	sb.size = Vector3(3.0, 0.02, 0.25)
	streifen.mesh = sb
	streifen.material_override = m_gold_turm
	streifen.position = Vector3(0, 0.09, 0)
	hq_brett.add_child(streifen)
	var unten := MeshInstance3D.new()
	var ub := BoxMesh.new()
	ub.size = Vector3(3.0, 0.05, 0.7)
	unten.mesh = ub
	unten.material_override = m_cyan_turm
	unten.position = Vector3(0, -0.12, 0)
	hq_brett.add_child(unten)
	_licht(hq_brett.position + Vector3(0, -0.5, 0), Color(0.6, 0.88, 1.0), 0.8, 7.0)

	# Bildschirme an der Nordwand
	var schirme := [
		[-5.5, m_cyan_turm.albedo_color, "SYNTH-CITY\nSTATUS: RUHIG"],
		[0.0, Color(1.0, 0.8, 0.25), "PLAN Nr. 7\nGURKEN-MONSTER"],
		[5.5, Color(1.0, 0.25, 0.2), "ALARM\nDUNKELWELT-FLORONIA"],
	]
	for e in schirme:
		var farbe: Color = e[1]
		_box(Vector3(cx + e[0], fb + 7.0, cz - 7.8), Vector3(5, 2.6, 0.15), _std(farbe.darkened(0.6), 1.2), false)
		_text(e[2], Vector3(cx + e[0], fb + 7.0, cz - 7.68), farbe, 0.0075, false)


func _hq_leben(delta: float) -> void:
	if hq_holo:
		hq_holo.rotation.y += delta * 0.6
	if hq_brett:
		hq_brett.position.y = hq_brett_y + sin(zeit * 2.0) * 0.1
		hq_brett.rotation.y += delta * 0.35
	if hq_tuer == null:
		return
	if spieler == null:
		spieler = get_node_or_null("../Spieler")
		return
	var d := spieler.global_position.distance_to(hq_tuer_pos)
	hq_hinweis.visible = d < 9.0 and not hq_offen
	if d < 9.0 and not hq_offen and Input.is_action_just_pressed("interagieren"):
		hq_offen = true
		create_tween().tween_property(hq_tuer, "position:y", hq_tuer_pos.y + 4.7, 0.9).set_trans(Tween.TRANS_QUAD)
	elif hq_offen and d > 20.0:
		hq_offen = false
		create_tween().tween_property(hq_tuer, "position:y", hq_tuer_pos.y, 0.9).set_trans(Tween.TRANS_QUAD)


func _brezel_stand() -> void:
	var c := Vector3(-255, 0, 30)
	_box(c + Vector3(0, 7, 0), Vector3(40, 14, 40), _std(Color(0.4, 0.25, 0.14), 0.0, 0.2, 0.6))
	_box(c + Vector3(20.2, 5, 0), Vector3(0.4, 4, 28), _std(Color(1, 0.8, 0.3), 2.0), false)
	var pivot := Node3D.new()
	pivot.position = c + Vector3(0, 14, 0)
	pivot.rotation_degrees.y = 90.0
	pivot.scale = Vector3.ONE * 2.2
	add_child(pivot)
	var teig := _std(Color(0.85, 0.45, 0.12), 1.4, 0.0, 0.4)
	var salz := _std(Color(1, 1, 0.9), 2.0)
	# Echte Brezel: Bauch unten, zwei sich kreuzende Arme, Enden liegen auf dem Bauch.
	# Punkte (x, y, z) in Einheiten; z hebt Kreuzung und Enden ueber den Bauch.
	var pts: Array[Vector3] = [
		Vector3(-0.92, -0.38, 0.25), Vector3(-1.0, 0.0, 0.25), Vector3(-1.08, 0.45, 0.08),
		Vector3(-0.88, 0.85, 0.0), Vector3(-0.5, 0.95, -0.06), Vector3(0.0, 0.62, -0.13),
		Vector3(0.55, 0.35, -0.06), Vector3(0.95, 0.05, 0.0),
		Vector3(0.9, -0.4, 0.0), Vector3(0.55, -0.88, 0.0), Vector3(0.0, -1.05, 0.0),
		Vector3(-0.55, -0.88, 0.0), Vector3(-0.9, -0.4, 0.0), Vector3(-0.95, 0.05, 0.0),
		Vector3(-0.55, 0.35, 0.06), Vector3(0.0, 0.62, 0.13), Vector3(0.5, 0.95, 0.06),
		Vector3(0.88, 0.85, 0.0), Vector3(1.08, 0.45, 0.08), Vector3(1.0, 0.0, 0.25),
		Vector3(0.92, -0.38, 0.25)]
	const MASS := 8.5
	const DICKE := 0.115 * MASS
	var kurve := _brezel_kurve(pts, MASS)
	var bm := MeshInstance3D.new()
	bm.mesh = _rohr_mesh(kurve, DICKE, 14)
	bm.material_override = teig
	bm.position = Vector3(0, 9.0, 0)
	pivot.add_child(bm)
	# Salzkoerner auf der Vorderseite
	var wm := BoxMesh.new()
	wm.size = Vector3(0.3, 0.3, 0.3)
	var salz_rng := RandomNumberGenerator.new()
	salz_rng.seed = 99
	for i in range(0, kurve.size(), 2):
		if salz_rng.randf() < 0.45:
			continue
		var w := salz_rng.randf_range(-0.9, 0.9)
		var sm := MeshInstance3D.new()
		sm.mesh = wm
		sm.material_override = salz
		sm.rotation = Vector3(salz_rng.randf() * TAU, salz_rng.randf() * TAU, 0.0)
		sm.position = Vector3(0, 9.0, 0) + kurve[i] + Vector3(sin(w) * DICKE * 0.9, 0.0, cos(w) * DICKE * 0.95)
		pivot.add_child(sm)
	_licht(c + Vector3(15, 22, 0), Color(1.0, 0.6, 0.2), 4.0, 50.0)


## Glatte Kurve (Catmull-Rom) durch die Punkte, mit MASS skaliert.
func _brezel_kurve(pts: Array[Vector3], mass: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var n := pts.size()
	for i in n - 1:
		var p0 := pts[maxi(i - 1, 0)]
		var p1 := pts[i]
		var p2 := pts[i + 1]
		var p3 := pts[mini(i + 2, n - 1)]
		for k in 12:
			var t := k / 12.0
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t) * mass)
	out.append(pts[n - 1] * mass)
	return out


## Rohr (Teigstrang) entlang einer Kurve. Die Kurve liegt fast in der xy-Ebene.
func _rohr_mesh(kurve: Array[Vector3], radius: float, seiten: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ringe: Array = []
	for i in kurve.size():
		var t := (kurve[mini(i + 1, kurve.size() - 1)] - kurve[maxi(i - 1, 0)]).normalized()
		var seite := t.cross(Vector3(0, 0, 1)).normalized()
		var hoch := seite.cross(t).normalized()
		# Strang an den Enden leicht abrunden
		var f := minf(float(mini(i, kurve.size() - 1 - i)) / 3.0, 1.0)
		var r := radius * sqrt(maxf(f, 0.15))
		var ring: Array[Vector3] = []
		for j in seiten:
			var a := TAU * j / seiten
			ring.append(kurve[i] + (seite * cos(a) + hoch * sin(a)) * r)
		ringe.append(ring)
	for i in ringe.size() - 1:
		for j in seiten:
			var j2 := (j + 1) % seiten
			var a: Vector3 = ringe[i][j]
			var b: Vector3 = ringe[i + 1][j]
			var c: Vector3 = ringe[i + 1][j2]
			var d: Vector3 = ringe[i][j2]
			for v in [a, b, c, a, c, d]:
				st.add_vertex(v)
	st.generate_normals()
	return st.commit()


func _wassertank() -> void:
	# Hochhaus mit Wassertank auf dem Dach. Der Tank ruht auf vier Stuetzen mit Fussplatten,
	# Tragring und Kreuzverband; die Stuetzen stehen innerhalb des Tankradius.
	var c := Vector3(TANK_POS.x, 0, TANK_POS.y)
	_box(c + Vector3(0, 30, 0), Vector3(38, 60, 38), m_silber)
	_box(c + Vector3(0, 60.5, 0), Vector3(32, 1, 32), m_ring)
	var rost := _std(Color(0.3, 0.42, 0.5), 0.0, 0.85, 0.35)
	var dach_y := 61.0
	var tank_y := dach_y + TANK_STUETZE_H
	var ecken: Array[Vector3] = []
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var fuss := c + Vector3(sx * TANK_STUETZE_ABSTAND, dach_y, sz * TANK_STUETZE_ABSTAND)
			ecken.append(fuss)
			_box(fuss + Vector3(0, 0.15, 0), Vector3(2.6, 0.3, 2.6), m_ring, false)
			_zyl(fuss + Vector3(0, TANK_STUETZE_H / 2.0, 0), 0.7, TANK_STUETZE_H, rost, false, 10)
	# Kreuzverband zwischen benachbarten Stuetzen (Reihenfolge: -x-z, -x+z, +x+z, +x-z)
	var reihum: Array[Vector3] = [ecken[0], ecken[1], ecken[3], ecken[2]]
	for i in 4:
		var a := reihum[i]
		var b := reihum[(i + 1) % 4]
		_balken(a + Vector3(0, 0.6, 0), b + Vector3(0, TANK_STUETZE_H - 0.8, 0), 0.25, 0.25, rost, false)
		_balken(a + Vector3(0, TANK_STUETZE_H - 0.8, 0), b + Vector3(0, 0.6, 0), 0.25, 0.25, rost, false)
	# Tragring direkt unter dem Tankboden
	_zyl(c + Vector3(0, tank_y - 0.4, 0), TANK_RADIUS - 0.6, 0.8, m_ring, false, 32)
	_zyl(c + Vector3(0, tank_y + 10.0, 0), TANK_RADIUS, 20.0, rost, true, 32)
	_zyl(c + Vector3(0, tank_y + 22.0, 0), TANK_RADIUS + 0.5, 4.0, rost, true, 32, 0.8)
	_zyl(c + Vector3(0, tank_y + 13.0, 0), TANK_RADIUS + 0.15, 1.2, m_blau, false, 32)
	_zyl(c + Vector3(0, tank_y + 5.0, 0), TANK_RADIUS + 0.15, 1.2, m_blau, false, 32)


func _popcorn() -> void:
	# Popcorn-Labor (levels/popcorn_labor.gd): begehbar, Eingang zeigt zum Popcornstich (nach Westen)
	_haus("res://levels/popcorn_labor.gd", POPCORN_POS, -90.0)


## Oeffentliche Gebaeude auf den frueheren Freiflaechen: Buecherei, Museum, Stadtverwaltung.
func _oeffentliche_gebaeude() -> void:
	_haus("res://levels/buecherei.gd", BUECHEREI_POS, 90.0)
	_haus("res://levels/museum.gd", MUSEUM_POS, 180.0)
	_haus("res://levels/rathaus.gd", RATHAUS_POS, -90.0)
	_haus("res://levels/krankenhaus.gd", KLINIK_POS, 0.0)


## Hydranten und kleine Baustellen entlang der Strassen (levels/strassen_deko.gd)
func _strassen_deko() -> void:
	var d := Node3D.new()
	d.set_script(load("res://levels/strassen_deko.gd"))
	add_child(d)


## Setzt ein begehbares Haus (Unterklasse von levels/haus.gd). `dreh`: Grad um y; die Front zeigt
## bei 0 nach Sueden (+z), bei -90 nach Westen, bei 90 nach Osten, bei 180 nach Norden.
func _haus(skript: String, pos: Vector2, dreh: float) -> void:
	var h := Node3D.new()
	h.set_script(load(skript))
	h.position = Vector3(pos.x, 0, pos.y)
	h.rotation_degrees.y = dreh
	add_child(h)


func _burger() -> void:
	# Sy-Ci Burgers: Front zeigt zur Runen-Plaza (nach Westen)
	var b := Node3D.new()
	b.name = "SyCiBurgers"
	b.set_script(load("res://burger.gd"))
	b.position = Vector3(115, 0, 72)
	b.rotation_degrees.y = -90.0
	add_child(b)


func _neonmarkt() -> void:
	var n := Node3D.new()
	n.name = "NeonMarkt"
	n.set_script(load("res://neonmarkt.gd"))
	n.position = Vector3(MARKT_POS.x, 0, MARKT_POS.y)
	add_child(n)


func _gurkenfeld() -> void:
	var pfad := "res://assets/texturen/gurke/"
	var gruen := StandardMaterial3D.new()
	gruen.albedo_texture = load(pfad + "diff.jpg")
	gruen.normal_enabled = true
	gruen.normal_texture = load(pfad + "nor.png")
	gruen.normal_scale = 1.4
	gruen.roughness_texture = load(pfad + "rough.jpg")
	gruen.roughness = 1.0
	gruen.metallic_specular = 0.6
	gruen.rim_enabled = true
	gruen.rim = 0.25
	gruen.rim_tint = 0.6
	gruen.uv1_scale = Vector3(1.0, 1.2, 1.0)
	var plaetze: Array = []  # [Position als Vector2, Radius]
	var geschafft := 0
	var versuche := 0
	while geschafft < 85 and versuche < 2000:
		versuche += 1
		var r := rng.randf_range(2.2, 4.4)
		var h := rng.randf_range(11.0, 22.0)
		var steht := rng.randf() < 0.22
		if steht:
			h *= 1.3
		var x := rng.randf_range(-308.0, -190.0)
		var z := rng.randf_range(-304.0, -112.0)
		var ausmass := h * 0.5 if not steht else r + 1.0
		if _auf_linien(x, z, ausmass + 1.0):
			continue
		var frei := true
		for q in plaetze:
			if Vector2(x, z).distance_to(q[0]) < ausmass * 0.8 + q[1] + 1.0:
				frei = false
				break
		if not frei:
			continue
		plaetze.append([Vector2(x, z), ausmass * 0.8])
		geschafft += 1
		var m := MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		cm.radius = r
		cm.height = h
		cm.radial_segments = 24
		cm.rings = 8
		m.mesh = cm
		m.material_override = gruen
		if steht:
			m.rotation_degrees = Vector3(rng.randf_range(-9.0, 9.0), rng.randf() * 360.0, rng.randf_range(-9.0, 9.0))
			m.position = Vector3(x, h * 0.5 - 0.3, z)
		else:
			m.rotation_degrees = Vector3(0, rng.randf() * 360.0, 90.0)
			m.position = Vector3(x, r * 0.85, z)
		add_child(m)
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := CapsuleShape3D.new()
		sh.radius = r
		sh.height = h
		cs.shape = sh
		sb.add_child(cs)
		m.add_child(sb)


func _floronia() -> void:
	var c := Vector3(0, 0, 262)
	var obsidian := _std(Color(0.02, 0.02, 0.03), 0.0, 0.95, 0.1)
	_box(c + Vector3(0, 15, 0), Vector3(22, 30, 22), obsidian)
	_box(c + Vector3(0, 47, 0), Vector3(15, 34, 15), obsidian)
	_box(c + Vector3(0, 80, 0), Vector3(9, 32, 9), obsidian)
	for sx in [-1.0, 1.0]:
		var h := _zyl(c + Vector3(sx * 4.5, 100, 0), 1.6, 24.0, obsidian, false, 8, 0.1)
		h.rotation_degrees.z = -sx * 22.0
		var auge := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = 1.4
		sp.height = 2.8
		auge.mesh = sp
		auge.material_override = _std(Color(1, 0.05, 0.05), 6.0)
		auge.scale = Vector3(1.6, 0.6, 0.4)
		auge.position = c + Vector3(sx * 2.4, 88, -4.6)
		add_child(auge)
	_licht(c + Vector3(0, 88, -10), Color(1.0, 0.1, 0.1), 6.0, 90.0)
	_licht(c + Vector3(0, 20, -20), Color(0.8, 0.1, 0.3), 4.0, 50.0)


# ---------------------------------------------------------------- Viertel

func _viertel_bauen() -> void:
	# [Bereich, hmin, hmax, fmin, fmax, Schritt, Material, Turm-Bias, Dachlicht, Schildtexte, Schild-Chance]
	var tech := ["ZAUBER", "SYNTH", "NEO", "ARCANE", "RUNEN"]
	var alt := ["BREZEL", "ELIXIR", "TEE", "MAGIE", "RUNEN-SHOP"]
	var zuk := ["CYBER", "FUTURE", "NEO", "Z-CORP", "HOLO"]
	var viertel := [
		[Rect2(-190, -298, 380, 126), 45.0, 150.0, 14.0, 22.0, 26.0, m_silber, true, Color(0, 0, 0, 0), tech, 0.25],
		[Rect2(-190, -165, 380, 135), 18.0, 42.0, 14.0, 22.0, 30.0, m_alt, false, Color(0, 0, 0, 0), alt, 0.4],
		[Rect2(70, -30, 125, 160), 14.0, 38.0, 14.0, 20.0, 28.0, m_silber, false, Color(0, 0, 0, 0), tech, 0.2],
		[Rect2(-195, 48, 125, 112), 14.0, 30.0, 14.0, 20.0, 28.0, m_alt, false, Color(0, 0, 0, 0), alt, 0.3],
		[Rect2(215, -298, 80, 300), 25.0, 60.0, 16.0, 24.0, 30.0, m_silber, false, Color(0, 0, 0, 0), tech, 0.2],
		[Rect2(215, 2, 80, 60), 20.0, 35.0, 14.0, 20.0, 28.0, m_silber, false, Color(0, 0, 0, 0), tech, 0.2],
		[Rect2(200, 62, 95, 236), 30.0, 95.0, 12.0, 20.0, 26.0, m_zukunft, false, Color(0.2, 0.9, 1.0), zuk, 0.3],
		[Rect2(-298, -98, 83, 396), 7.0, 16.0, 12.0, 20.0, 24.0, m_bewachsen, false, Color(0, 0, 0, 0), alt, 0.3],
		[Rect2(-190, 198, 380, 100), 10.0, 34.0, 7.0, 11.0, 13.0, m_schatten, false, Color(0, 0, 0, 0), [], 0.0],
	]
	rng_d.seed = 4242
	for v in viertel:
		_viertel(v)
	_details_bauen()
	# rote Laternen in den Schatten-Gassen
	for i in 14:
		var p := Vector3(rng.randf_range(-170, 170), 6.0, rng.randf_range(205, 290))
		if p.distance_to(Vector3(0, 6, 262)) < 30.0:
			continue
		_licht(p, Color(1.0, 0.15, 0.1), 2.5, 16.0)
	# Buesche im ueberwucherten Handelsplatz
	var busch := SphereMesh.new()
	busch.radius = 2.0
	busch.height = 3.2
	busch.radial_segments = BUSCH_SEGMENTE
	busch.rings = BUSCH_SEGMENTE / 2
	var tb: Array = []
	var fb: Array = []
	for i in 160:
		var x := rng.randf_range(-295.0, -218.0)
		var z := rng.randf_range(-95.0, 295.0)
		if _blockiert(x, z, 3.0):
			continue
		var s := rng.randf_range(0.7, 2.2)
		tb.append(Transform3D(Basis.IDENTITY.scaled(Vector3(s, s * 0.8, s)), Vector3(x, s, z)))
		fb.append(Color.from_hsv(rng.randf_range(0.22, 0.36), 0.7, rng.randf_range(0.3, 0.55)))
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	_multimesh(busch, mat, tb, fb)


func _viertel(v: Array) -> void:
	var rect: Rect2 = v[0]
	var schritt: float = v[5]
	var x := rect.position.x + schritt / 2.0
	while x < rect.end.x:
		var z := rect.position.y + schritt / 2.0
		while z < rect.end.y:
			var px := x + rng.randf_range(-2.0, 2.0)
			var pz := z + rng.randf_range(-2.0, 2.0)
			var w := rng.randf_range(v[3], v[4])
			var d := rng.randf_range(v[3], v[4])
			if not _blockiert(px, pz, maxf(w, d) * 0.5 + 1.0):
				var h: float = rng.randf_range(v[1], v[2])
				if v[7]:
					var dist := Vector2(px, pz).distance_to(TURM)
					h *= lerpf(1.0, 0.45, clampf(dist / 250.0, 0.0, 1.0))
					h = maxf(h, 30.0)
				_gebaeude(px, pz, w, d, h, v[6], v[8], v[9], v[10])
			z += schritt
		x += schritt


func _gebaeude(px: float, pz: float, w: float, d: float, h: float, mat: Material, dach: Color, woerter: Array, chance: float) -> void:
	var tw := w
	var td := d
	var h_unten := h
	if h > 45.0 and rng.randf() < 0.6:
		var h1 := h * 0.68
		_box(Vector3(px, h1 / 2.0, pz), Vector3(w, h1, d), mat)
		var h2 := h - h1
		tw = w * 0.62
		td = d * 0.62
		h_unten = h1
		_box(Vector3(px, h1 + h2 / 2.0, pz), Vector3(tw, h2, td), mat)
	else:
		_box(Vector3(px, h / 2.0, pz), Vector3(w, h, d), mat)
	if dach.a > 0.0:
		_box(Vector3(px, h + 0.3, pz), Vector3(tw + 0.4, 0.6, td + 0.4), _std(dach, 3.0), false)
	_fassade_details(px, pz, w, d, h, h_unten, tw, td, mat, dach.a > 0.0)


func _det(mitte: Vector3, groesse: Vector3, farbe: Color) -> void:
	det_t.append(Transform3D(Basis.IDENTITY.scaled(groesse), mitte))
	det_f.append(farbe)


func _neon_streifen(mitte: Vector3, groesse: Vector3, farbe: Color, blinkend := false) -> void:
	var t := Transform3D(Basis.IDENTITY.scaled(groesse), mitte)
	if blinkend:
		blink_t.append(t)
		blink_f.append(farbe)
	else:
		neon_t.append(t)
		neon_f.append(farbe)


## Gesimse, Eckpilaster, Geschossbaender, Bruestung, Dachaufbauten, Antennen und Neonstreifen.
func _fassade_details(px: float, pz: float, w: float, d: float, h: float, h_unten: float, tw: float, td: float, mat: Material, leuchtdach: bool) -> void:
	var trim := Color(0.09, 0.10, 0.13)
	if mat == m_alt:
		trim = Color(0.24, 0.20, 0.17)
	elif mat == m_bewachsen:
		trim = Color(0.17, 0.22, 0.13)
	elif mat == m_schatten:
		trim = Color(0.02, 0.02, 0.03)
	# Sockelabsatz und Kranzgesims
	_det(Vector3(px, 1.0, pz), Vector3(w + 0.7, 0.35, d + 0.7), trim)
	_det(Vector3(px, h_unten - 0.55, pz), Vector3(w + 0.8, 1.0, d + 0.8), trim)
	# Eckpilaster
	if h_unten > 20.0:
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				_det(Vector3(px + sx * w / 2.0, h_unten / 2.0, pz + sz * d / 2.0), Vector3(0.9, h_unten, 0.9), trim)
	# Geschossbaender alle 18 m
	var y := 18.0
	while y < h_unten - 6.0:
		_det(Vector3(px, y, pz), Vector3(w + 0.5, 0.7, d + 0.5), trim)
		y += 18.0
	# Absatz beim Turmaufsatz
	if h_unten < h - 1.0:
		_det(Vector3(px, h - 0.55, pz), Vector3(tw + 0.8, 1.0, td + 0.8), trim)
	# Dachbruestung (Leuchtdaecher haben schon ihren Rand)
	if not leuchtdach:
		_det(Vector3(px, h + 0.5, pz - td / 2.0 + 0.25), Vector3(tw, 1.0, 0.5), trim)
		_det(Vector3(px, h + 0.5, pz + td / 2.0 - 0.25), Vector3(tw, 1.0, 0.5), trim)
		_det(Vector3(px - tw / 2.0 + 0.25, h + 0.5, pz), Vector3(0.5, 1.0, td - 1.0), trim)
		_det(Vector3(px + tw / 2.0 - 0.25, h + 0.5, pz), Vector3(0.5, 1.0, td - 1.0), trim)
	# Dachaufbauten: Klimageraete, Lueftungsboxen, Aufzugsturm
	if tw > 8.0 and td > 8.0:
		var gx := tw / 2.0 - 2.5
		var gz := td / 2.0 - 2.5
		for i in rng_d.randi_range(2, 5):
			var gr := Vector3(rng_d.randf_range(1.5, 3.5), rng_d.randf_range(0.8, 2.2), rng_d.randf_range(1.5, 3.5))
			var gp := Vector3(px + rng_d.randf_range(-gx, gx), h + gr.y / 2.0, pz + rng_d.randf_range(-gz, gz))
			_det(gp, gr, Color(0.2, 0.21, 0.25) * rng_d.randf_range(0.7, 1.3))
		if h > 30.0:
			_det(Vector3(px + rng_d.randf_range(-gx, gx) * 0.5, h + 1.8, pz + rng_d.randf_range(-gz, gz) * 0.5), Vector3(4.0, 3.6, 4.0), trim.lightened(0.15))
	# Antenne mit Warnlicht
	if h > 35.0 and rng_d.randf() < 0.55:
		var ah := rng_d.randf_range(8.0, 18.0)
		var ap := Vector3(px + rng_d.randf_range(-1.0, 1.0), h + ah / 2.0, pz + rng_d.randf_range(-1.0, 1.0))
		_det(ap, Vector3(0.35, ah, 0.35), trim.lightened(0.2))
		_det(ap + Vector3(0, ah * 0.3, 0), Vector3(2.4, 0.2, 0.2), trim.lightened(0.2))
		if h > 50.0:
			_neon_streifen(ap + Vector3(0, ah / 2.0 + 0.5, 0), Vector3(0.9, 0.9, 0.9), Color(1.0, 0.1, 0.05), true)
	# senkrechte Neonstreifen an den Ecken hoher Tuerme
	if (leuchtdach or h > 60.0) and rng_d.randf() < 0.75:
		var farben := [Color(0.2, 0.9, 1.0), Color(1.0, 0.2, 0.8), Color(1.0, 0.8, 0.25)]
		var nf: Color = farben[rng_d.randi() % 3]
		var sx := 1.0 if rng_d.randf() < 0.5 else -1.0
		var sz := 1.0 if rng_d.randf() < 0.5 else -1.0
		_neon_streifen(Vector3(px + sx * (w / 2.0 + 0.5), h_unten * 0.5, pz + sz * (d / 2.0 + 0.5)), Vector3(0.28, h_unten * 0.88, 0.28), nf)


func _details_bauen() -> void:
	var einheit := BoxMesh.new()
	einheit.size = Vector3.ONE
	_multimesh(einheit, m_trim, det_t, det_f)
	_multimesh(einheit, m_neon, neon_t, neon_f)
	_multimesh(einheit, m_neon_blink, blink_t, blink_f)


# ---------------------------------------------------------------- Berge, Grenze, Beschriftung

func _berge() -> void:
	var kegel := CylinderMesh.new()
	kegel.top_radius = 0.15
	kegel.bottom_radius = 1.0
	kegel.height = 1.0
	kegel.radial_segments = 7
	kegel.rings = 1
	var tr: Array = []
	var fa: Array = []
	var n := 17
	# lueckenlose Klippenwand direkt hinter der Grenze
	for seite in 4:
		for i in n:
			var t := lerpf(-GRENZE - 40.0, GRENZE + 40.0, float(i) / (n - 1))
			var pos := Vector2(t, GRENZE + 45.0)
			pos = pos.rotated(seite * PI / 2.0)
			_berg_hinzu(tr, fa, pos, rng.randf_range(42.0, 58.0), rng.randf_range(55.0, 100.0))
	# grosse Berge dahinter
	for i in 70:
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(430.0, 700.0)
		var pos := Vector2(cos(ang), sin(ang)) * dist
		_berg_hinzu(tr, fa, pos, rng.randf_range(60.0, 130.0), rng.randf_range(110.0, 260.0))
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	_multimesh(kegel, mat, tr, fa)


func _berg_hinzu(tr: Array, fa: Array, pos: Vector2, radius: float, hoehe: float) -> void:
	var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(radius, hoehe, radius))
	tr.append(Transform3D(b, Vector3(pos.x, hoehe / 2.0 - 4.0, pos.y)))
	fa.append(Color.from_hsv(rng.randf_range(0.07, 0.25), rng.randf_range(0.1, 0.3), rng.randf_range(0.16, 0.30)))


func _grenze() -> void:
	var wand := 2.0 * GRENZE + 40.0
	for seite in 4:
		var rot := seite * PI / 2.0
		# Westseite (3): lokale x-Achse zeigt nach +z. Dort bleibt hinter dem Gurken-Wald eine Luecke.
		var teile: Array = [[-wand / 2.0, wand / 2.0]]
		if seite == 3:
			var l := TerrainForm.PASS_Z
			teile = [[-wand / 2.0, l - 20.0], [l + 20.0, wand / 2.0]]
		for t in teile:
			var breite: float = t[1] - t[0]
			var mitte: float = (t[0] + t[1]) / 2.0
			var sb := StaticBody3D.new()
			var cs := CollisionShape3D.new()
			var sh := BoxShape3D.new()
			sh.size = Vector3(breite, 200, 10)
			cs.shape = sh
			sb.add_child(cs)
			sb.position = Vector3(mitte, 100, GRENZE + 5.0).rotated(Vector3.UP, rot)
			sb.rotation.y = rot
			add_child(sb)
		var lt: Array = [[-GRENZE, GRENZE]]
		if seite == 3:
			lt = [[-GRENZE, TerrainForm.PASS_Z - 20.0], [TerrainForm.PASS_Z + 20.0, GRENZE]]
		for t in lt:
			var linie := _box(Vector3((t[0] + t[1]) / 2.0, 0.15, GRENZE).rotated(Vector3.UP, rot), Vector3(t[1] - t[0], 0.3, 0.6), m_cyan, false)
			linie.rotation.y = rot
	_durchgang_tor()


## Neon-Torbogen im Westen: Eingang zum Durchgang Richtung Neustadt.
func _durchgang_tor() -> void:
	var z := TerrainForm.PASS_Z
	var x := -GRENZE - 4.0
	for sz in [-1.0, 1.0]:
		_box(Vector3(x, 14, z + sz * 22.0), Vector3(4, 28, 4), m_stein)
		_box(Vector3(x + 2.1, 14, z + sz * 22.0), Vector3(0.4, 26, 0.8), m_cyan, false)
	_box(Vector3(x, 28.5, z), Vector3(5, 4, 50), m_stein)
	_box(Vector3(x + 2.6, 28.5, z), Vector3(0.4, 0.8, 48), m_blau, false)
	var tafel := _text("NEO-DISTRIKT >>", Vector3(x - 3.0, 28.5, z), Color(0.3, 0.95, 1.0), 0.06, false)
	tafel.rotation_degrees.y = -90.0
	var tafel2 := _text("NEO-DISTRIKT >>", Vector3(x + 3.0, 28.5, z), Color(0.3, 0.95, 1.0), 0.06, false)
	tafel2.rotation_degrees.y = 90.0
	_licht(Vector3(x - 6, 20, z), Color(0.3, 0.9, 1.0), 4.0, 60.0)
