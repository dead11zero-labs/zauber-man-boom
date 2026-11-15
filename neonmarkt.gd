extends Node3D
## "NEON-MARKT 24/7": grosser Supermarkt der Kernstadt (Vorlage: Notion-Seite "Neon-Mart 24/7"), voll begehbar.
## Lokale Achsen: Front (Glasfassade, Ein- und Ausgang, Vorplatz) zeigt nach +z, Ursprung = Mitte der Grundflaeche.
## Aufteilung wie in einem echten Markt: Eingang links mit Einkaufswagen, danach Obst und Gemuese (mit Daempffeld und
## der Kiste "Gurke Nr. 4"), in der Mitte sechs Regalgaenge (Snacks, Getraenke, Konserven, Synth-Food, Energiezellen,
## Salz/Heldenbedarf), an der Rueckwand Frischetheke, Kuehlregale mit kuehler Milch, Tiefkuehlwand und Backwaren,
## an der Ostwand die exotischen Gewuerze (mit ausgebranntem Chili-Platz), vorn rechts Kassenzone mit 5 Kassen,
## 2 Selbstscan-Kassen und der Ausgang. Aussen: Neonreklame, Vorplatz mit Wagenbox, Lieferdrohnen-Deck auf dem Dach,
## Hoverboard-Drive-In. Automatiktueren oeffnen, sobald der Spieler naht.
## Texturen: Poly Haven (assets/texturen/markt_*) und selbst erzeugte Produktreihen (assets/texturen/markt_prod_*).
## Schriften nur auf festen Schildern (keine frei schwebenden Texte). Keine Signale, keine Exporte.
## Wird von stadt.gd (_neonmarkt) erzeugt. Alle Masse in Metern.

const B := 56.0                  ## Breite (x)
const T := 36.0                  ## Tiefe (z)
const H := 7.0                   ## Aussenhoehe bis Dachkante
const DECKE_Y := 5.0             ## Hoehe der abgehaengten Decke innen
const WAND := 0.5
const GLAS_H := 3.6              ## Hoehe der Schaufensterfront
const TUER_B := 4.2              ## Breite einer Tuer-Oeffnung
const TUER_X_EIN := -16.0
const TUER_X_AUS := 22.0
const TUER_OEFFNEN := 4.5        ## Abstand, ab dem die Tueren aufgehen
const TUER_TEMPO := 2.0          ## Tueren pro Sekunde (1 = voll offen)
const VORPLATZ_TIEFE := 12.0
const GONDEL_X: Array[float] = [-4.0, 0.5, 5.0, 9.5, 14.0, 18.5]
const GONDEL_Z0 := -12.5
const GONDEL_Z1 := 1.5
const REGAL_STUFEN := 5
const STUFE_H := 0.42
const KASSEN_X: Array[float] = [5.0, 8.5, 12.0, 15.5, 19.0]
const PINK := Color(1.0, 0.2, 0.65)
const CYAN := Color(0.15, 0.9, 1.0)
const VIOLETT := Color(0.6, 0.3, 1.0)
const DROHNEN_ANZAHL := 3
const DROHNEN_RADIUS := Vector2(46.0, 34.0)
const DROHNEN_TEMPO := 0.18
const DROHNEN_HOEHE := 24.0
const ROTOR_TEMPO := 40.0
const FELD_X0 := -26.5
const FELD_X1 := -10.0
const FELD_Z0 := -4.0
const FELD_Z1 := 9.0
const FELD_H := 3.2

var m: Dictionary = {}
var zeit := 0.0
var _spieler: Node3D
var _tueren: Array = []          ## je Tuer: [linkes Blatt, rechtes Blatt, Mittelpunkt x, Oeffnung 0..1]
var _feld_mat: StandardMaterial3D
var _drohnen: Array[Node3D] = []
var _rotoren: Array[Node3D] = []
var _bretter: Array[Node3D] = []
var _prod_cache: Dictionary = {}


func _ready() -> void:
	_materialien()
	_huelle()
	_fassade()
	_boden_decke_licht()
	_eingangsbereich()
	_obst_gemuese()
	_gaenge()
	_rueckwand()
	_gewuerz_wand()
	_kassenzone()
	_drohnen_bauen()
	_aussen()


func _process(delta: float) -> void:
	zeit += delta
	_tueren_bewegen(delta)
	if _feld_mat != null:
		_feld_mat.albedo_color.a = 0.06 + 0.03 * sin(zeit * 2.0)
	for i in _drohnen.size():
		var d := _drohnen[i]
		var w := zeit * DROHNEN_TEMPO + TAU * i / float(DROHNEN_ANZAHL)
		d.position = Vector3(cos(w) * DROHNEN_RADIUS.x, DROHNEN_HOEHE + sin(w * 2.0) * 3.0, sin(w) * DROHNEN_RADIUS.y)
		d.rotation.y = atan2(-sin(w) * DROHNEN_RADIUS.x, cos(w) * DROHNEN_RADIUS.y)
	for r in _rotoren:
		r.rotation.y += delta * ROTOR_TEMPO
	for i in _bretter.size():
		_bretter[i].position.y = 0.9 + sin(zeit * 1.6 + i) * 0.08


# ---------------------------------------------------------------- Helfer

func _std(c: Color, emission := 0.0, metall := 0.0, rauh := 0.6, innen := true) -> StandardMaterial3D:
	var s := StandardMaterial3D.new()
	s.albedo_color = c
	s.metallic = metall
	s.roughness = rauh
	s.disable_ambient_light = innen
	if emission > 0.0:
		s.emission_enabled = true
		s.emission = c
		s.emission_energy_multiplier = emission
	return s


func _tex(ordner: String, kachel: float, tint: Color, metall := 0.0, rauh := 1.0, innen := true) -> StandardMaterial3D:
	var pfad := "res://assets/texturen/%s/" % ordner
	var t := StandardMaterial3D.new()
	t.albedo_texture = load(pfad + "diff.jpg")
	t.albedo_color = tint
	if ResourceLoader.exists(pfad + "nor.jpg"):
		t.normal_enabled = true
		t.normal_texture = load(pfad + "nor.jpg")
	if ResourceLoader.exists(pfad + "rough.jpg"):
		t.roughness_texture = load(pfad + "rough.jpg")
	t.roughness = rauh
	t.metallic = metall
	t.uv1_triplanar = true
	t.uv1_scale = Vector3.ONE / kachel
	t.disable_ambient_light = innen
	return t


func _glas(alpha: float, innen := true) -> StandardMaterial3D:
	var g := _std(Color(0.7, 0.88, 1.0, alpha), 0.0, 0.0, 0.05, innen)
	g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return g


## Produktreihe (Textur mit 3 Varianten uebereinander), gekachelt entlang der Laenge `laenge` (Kachel = 2 m).
func _prod(kat: String, variante: int, laenge: float) -> StandardMaterial3D:
	var key := "%s_%d_%d" % [kat, variante, int(laenge * 10.0)]
	if _prod_cache.has(key):
		return _prod_cache[key]
	var t := StandardMaterial3D.new()
	t.albedo_texture = load("res://assets/texturen/markt_prod_%s/diff.jpg" % kat)
	t.roughness = 0.55
	t.disable_ambient_light = true
	t.uv1_scale = Vector3(laenge / 2.0, 1.0 / 3.0, 1.0)
	t.uv1_offset = Vector3(variante * 0.31, variante / 3.0, 0.0)
	t.emission_enabled = true
	t.emission_texture = t.albedo_texture
	t.emission_energy_multiplier = 0.12
	_prod_cache[key] = t
	return t


## Flaches Bild (UV 0..1) fuer Frische-Tablett, Backwaren und Poster.
func _bild(name: String, kachel_x := 1.0, emission := 0.1) -> StandardMaterial3D:
	var t := StandardMaterial3D.new()
	var pfad := "res://assets/texturen/markt_poster/diff.jpg" if name == "poster" else "res://assets/texturen/markt_prod_%s/diff.jpg" % name
	t.albedo_texture = load(pfad)
	t.roughness = 0.5
	t.disable_ambient_light = true
	t.uv1_scale = Vector3(kachel_x, 1.0, 1.0)
	t.emission_enabled = true
	t.emission_texture = t.albedo_texture
	t.emission_energy_multiplier = emission
	return t


func _materialien() -> void:
	m["boden"] = _tex("markt_boden_fliese", 2.4, Color(1.0, 1.0, 1.03), 0.0, 1.0)
	m["wand"] = _tex("markt_plastered_wall_04", 3.0, Color(1.7, 1.7, 1.75), 0.0)
	m["decke"] = _tex("markt_decke_platte", 2.4, Color(0.95, 0.95, 0.95), 0.0, 1.0)
	m["stahl"] = _tex("kantine_stahl", 1.2, Color(1.25, 1.25, 1.3), 0.2, 0.45)
	m["fliese_w"] = _tex("markt_long_white_tiles", 1.2, Color(1.2, 1.2, 1.2), 0.0, 0.4)
	m["kiste"] = _tex("markt_plank_flooring_02", 1.0, Color(0.95, 0.85, 0.7), 0.0)
	m["eiche"] = _tex("markt_oak_wood_planks", 1.2, Color(1.0, 0.92, 0.85), 0.0)
	m["gummi"] = _tex("rubber_tiles", 1.0, Color(0.35, 0.35, 0.4), 0.0)
	m["vorplatz"] = _tex("concrete_tile_facade", 3.0, Color(0.7, 0.72, 0.78), 0.0, 1.0, false)
	m["fassade"] = _tex("concrete_tile_facade", 4.0, Color(0.8, 0.83, 0.92), 0.2, 1.0, false)
	m["alu"] = _std(Color(0.72, 0.74, 0.78), 0.0, 0.3, 0.35, false)
	m["dunkel"] = _std(Color(0.09, 0.1, 0.14), 0.0, 0.3, 0.45, false)
	m["dunkel_i"] = _std(Color(0.09, 0.1, 0.14), 0.0, 0.25, 0.45)
	m["regal"] = _std(Color(0.62, 0.65, 0.7), 0.0, 0.25, 0.5)
	m["regal_d"] = _std(Color(0.22, 0.24, 0.3), 0.0, 0.2, 0.5)
	m["weiss"] = _std(Color(0.94, 0.95, 0.97), 0.0, 0.1, 0.4)
	m["lampe"] = _std(Color(1.0, 0.97, 0.9), 1.5, 0.0, 0.4)
	m["pink"] = _std(PINK, 2.6, 0.0, 0.5, false)
	m["cyan"] = _std(CYAN, 2.4, 0.0, 0.5, false)
	m["violett"] = _std(VIOLETT, 2.4, 0.0, 0.5, false)
	m["pink_i"] = _std(PINK, 1.3)
	m["cyan_i"] = _std(CYAN, 1.3)
	m["violett_i"] = _std(VIOLETT, 1.3)
	m["gelb"] = _std(Color(1.0, 0.8, 0.15), 0.8)
	m["rot"] = _std(Color(0.85, 0.1, 0.1), 0.0, 0.1, 0.4)
	m["gruen_led"] = _std(Color(0.2, 1.0, 0.4), 2.0)
	m["rot_led"] = _std(Color(1.0, 0.15, 0.1), 2.0, 0.0, 0.5, false)
	m["schirm"] = _std(Color(0.2, 0.85, 1.0), 1.0, 0.0, 0.3)
	m["glas"] = _glas(0.16)
	m["glas_a"] = _glas(0.16, false)
	m["poster"] = _bild("poster", 1.0, 0.15)
	_feld_mat = _std(Color(0.7, 0.4, 1.0, 0.07), 0.4, 0.0, 0.2)
	_feld_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_feld_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	m["feld"] = _feld_mat


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


func _zyl(pos: Vector3, r: float, h: float, mat: Material, kol := false, eltern: Node3D = null, seg := 16) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = seg
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	(eltern if eltern != null else self).add_child(mi)
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


func _kugel(pos: Vector3, r: float, mat: Material, eltern: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 12
	sm.rings = 6
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	(eltern if eltern != null else self).add_child(mi)
	return mi


## Flaeche (QuadMesh, UV 0..1), Vorderseite zeigt nach +z, gedreht um y (dann um x).
func _quad(pos: Vector3, gr: Vector2, mat: Material, rot_y := 0.0, rot_x := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = gr
	mi.mesh = qm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = Vector3(rot_x, rot_y, 0.0)
	add_child(mi)
	return mi


func _licht(pos: Vector3, farbe: Color, energie: float, reichweite: float) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = farbe
	l.light_energy = energie
	l.omni_range = reichweite
	add_child(l)


## Schrift direkt auf einer Flaeche (nur von vorn lesbar), `rot_y` wie bei _quad.
func _schrift(txt: String, pos: Vector3, farbe: Color, groesse := 48, pixel := 0.008, rot_y := 0.0) -> Label3D:
	var l := Label3D.new()
	l.text = txt
	l.font_size = groesse
	l.pixel_size = pixel
	l.outline_size = 0
	l.modulate = farbe
	l.shaded = false
	l.double_sided = false
	l.position = pos
	l.rotation.y = rot_y
	add_child(l)
	return l


## Haengeschild: dunkle Tafel an zwei Seilen, Schrift vorn und hinten, farbige Unterkante.
func _haengeschild(pos: Vector3, txt: String, farbe: Color, rot_y := 0.0) -> void:
	var w := maxf(2.2, txt.length() * 0.2 + 0.5)
	var knoten := Node3D.new()
	knoten.position = pos
	knoten.rotation.y = rot_y
	add_child(knoten)
	_box(Vector3.ZERO, Vector3(w, 0.5, 0.08), m["dunkel_i"], false, knoten)
	_box(Vector3(0, -0.27, 0), Vector3(w, 0.04, 0.1), _std(farbe, 1.6), false, knoten)
	var seil := DECKE_Y - pos.y - 0.25
	for s in [-1.0, 1.0]:
		_box(Vector3(s * (w * 0.5 - 0.15), 0.25 + seil * 0.5, 0), Vector3(0.015, seil, 0.015), m["dunkel_i"], false, knoten)
	var hell := farbe.lightened(0.5)
	for sg in [1.0, -1.0]:
		var l := Label3D.new()
		l.text = txt
		l.font_size = 40
		l.pixel_size = 0.0085
		l.outline_size = 0
		l.modulate = hell
		l.shaded = false
		l.double_sided = false
		l.position = Vector3(0, 0.0, sg * 0.045)
		l.rotation.y = 0.0 if sg > 0.0 else PI
		knoten.add_child(l)


# ---------------------------------------------------------------- Gebaeude

func _huelle() -> void:
	var hz := T * 0.5
	var hx := B * 0.5
	# Aussenwaende (Rueckseite und Seiten), Dach mit Attika
	_box(Vector3(0, H * 0.5, -hz + WAND * 0.5), Vector3(B, H, WAND), m["fassade"])
	for s in [-1.0, 1.0]:
		_box(Vector3(s * (hx - WAND * 0.5), H * 0.5, 0), Vector3(WAND, H, T - 2.0 * WAND), m["fassade"])
	_box(Vector3(0, H + 0.2, 0), Vector3(B, 0.4, T), m["dunkel"])
	for s in [-1.0, 1.0]:
		_box(Vector3(0, H + 0.7, s * (hz - 0.15)), Vector3(B, 0.6, 0.3), m["fassade"])
		_box(Vector3(s * (hx - 0.15), H + 0.7, 0), Vector3(0.3, 0.6, T), m["fassade"])
	# Innenverkleidung (Putz) Rueck- und Seitenwaende, Sockelleiste
	_box(Vector3(0, DECKE_Y * 0.5, -hz + WAND + 0.05), Vector3(B - 1.0, DECKE_Y, 0.1), m["wand"], false)
	for s in [-1.0, 1.0]:
		_box(Vector3(s * (hx - WAND - 0.05), DECKE_Y * 0.5, 0), Vector3(0.1, DECKE_Y, T - 1.0), m["wand"], false)
		_box(Vector3(s * (hx - WAND - 0.12), 0.1, 0), Vector3(0.05, 0.2, T - 1.2), m["stahl"], false)
	_box(Vector3(0, 0.1, -hz + WAND + 0.12), Vector3(B - 1.2, 0.2, 0.05), m["stahl"], false)
	# Fassadenband ueber den Schaufenstern: innen Putz (nur ueber der Glashoehe, damit die Tueren frei bleiben)
	_box(Vector3(0, (GLAS_H + DECKE_Y) * 0.5, hz - WAND - 0.05), Vector3(B - 1.0, DECKE_Y - GLAS_H, 0.1), m["wand"], false)


func _fassade() -> void:
	var hz := T * 0.5
	var hx := B * 0.5
	var z := hz - WAND * 0.5
	# Fassadenband ueber den Schaufenstern (aussen), Sockel unter den Fenstern
	_box(Vector3(0, GLAS_H + (H - GLAS_H) * 0.5, z), Vector3(B, H - GLAS_H, WAND), m["fassade"])
	for sg in [[-hx + WAND, TUER_X_EIN - TUER_B * 0.5], [TUER_X_EIN + TUER_B * 0.5, TUER_X_AUS - TUER_B * 0.5], [TUER_X_AUS + TUER_B * 0.5, hx - WAND]]:
		_box(Vector3((sg[0] + sg[1]) * 0.5, 0.15, z), Vector3(sg[1] - sg[0], 0.3, WAND), m["fassade"])
	_box(Vector3(0, GLAS_H - 0.1, z + WAND * 0.5 + 0.03), Vector3(B, 0.12, 0.06), m["cyan"], false)
	_box(Vector3(0, GLAS_H + 0.25, z + WAND * 0.5 + 0.03), Vector3(B, 0.06, 0.06), m["pink"], false)
	# Schaufensterfront in drei festen Feldern, Pfosten alle 3 m
	var grenzen: Array[float] = [-hx + WAND, TUER_X_EIN - TUER_B * 0.5, TUER_X_EIN + TUER_B * 0.5, TUER_X_AUS - TUER_B * 0.5, TUER_X_AUS + TUER_B * 0.5, hx - WAND]
	for i in [0, 2, 4]:
		var x0: float = grenzen[i]
		var x1: float = grenzen[i + 1]
		_box(Vector3((x0 + x1) * 0.5, 0.3 + (GLAS_H - 0.3) * 0.5, z), Vector3(x1 - x0, GLAS_H - 0.3, 0.1), m["glas_a"])
		var n := maxi(int((x1 - x0) / 3.0), 1)
		for k in n + 1:
			_box(Vector3(x0 + (x1 - x0) * k / float(n), GLAS_H * 0.5, z + 0.02), Vector3(0.1, GLAS_H, 0.16), m["alu"], false)
		_box(Vector3((x0 + x1) * 0.5, GLAS_H - 0.05, z + 0.02), Vector3(x1 - x0, 0.1, 0.16), m["alu"], false)
		_box(Vector3((x0 + x1) * 0.5, 0.3, z + 0.02), Vector3(x1 - x0, 0.1, 0.16), m["alu"], false)
	# Tuereinheiten (Ein- und Ausgang): Rahmen, zwei Schiebefluegel (innen versetzt)
	for tx in [TUER_X_EIN, TUER_X_AUS]:
		_box(Vector3(tx, GLAS_H - 0.12, z + 0.02), Vector3(TUER_B + 0.3, 0.24, 0.3), m["dunkel"], false)
		for s in [-1.0, 1.0]:
			_box(Vector3(tx + s * (TUER_B * 0.5 + 0.05), GLAS_H * 0.5, z + 0.02), Vector3(0.1, GLAS_H, 0.2), m["alu"], false)
		_box(Vector3(tx, 0.0, z), Vector3(TUER_B, 0.02, 0.5), m["stahl"], false)
		var links := Node3D.new()
		var rechts := Node3D.new()
		links.position = Vector3(tx - TUER_B * 0.25, 0.0, z - 0.24)
		rechts.position = Vector3(tx + TUER_B * 0.25, 0.0, z - 0.24)
		add_child(links)
		add_child(rechts)
		for t in [links, rechts]:
			_box(Vector3(0, (GLAS_H - 0.3) * 0.5 + 0.1, 0), Vector3(TUER_B * 0.5 - 0.04, GLAS_H - 0.3, 0.06), m["glas_a"], true, t)
			_box(Vector3(0, GLAS_H - 0.22, 0), Vector3(TUER_B * 0.5 - 0.04, 0.1, 0.08), m["alu"], false, t)
			_box(Vector3(0, 0.15, 0), Vector3(TUER_B * 0.5 - 0.04, 0.1, 0.08), m["alu"], false, t)
		_tueren.append([links, rechts, tx, 0.0])
	# Beschriftung der Tueren auf festen Schildern, Fassadenschriftzug
	for e in [[TUER_X_EIN, "EINGANG"], [TUER_X_AUS, "AUSGANG"]]:
		_box(Vector3(e[0], GLAS_H + 0.75, z + WAND * 0.5 + 0.06), Vector3(3.0, 0.7, 0.08), m["dunkel"], false)
		_schrift(e[1], Vector3(e[0], GLAS_H + 0.75, z + WAND * 0.5 + 0.12), Color(0.9, 0.97, 1.0), 56, 0.01)
	_box(Vector3(2.0, 5.6, z + WAND * 0.5 + 0.05), Vector3(24.0, 1.4, 0.1), m["dunkel"], false)
	_schrift("NEON-MARKT", Vector3(-2.5, 5.65, z + WAND * 0.5 + 0.12), PINK.lightened(0.1), 160, 0.0095)
	_schrift("24/7", Vector3(9.5, 5.65, z + WAND * 0.5 + 0.12), CYAN, 160, 0.0095)
	_box(Vector3(2.0, 6.35, z + WAND * 0.5 + 0.08), Vector3(24.2, 0.06, 0.06), m["violett"], false)
	_box(Vector3(2.0, 4.82, z + WAND * 0.5 + 0.08), Vector3(24.2, 0.06, 0.06), m["pink"], false)
	_dachreklame()


## Reklametafel auf dem Dach (Vorder- und Rueckseite) mit Slogan.
func _dachreklame() -> void:
	var z := T * 0.5 - 3.0
	_box(Vector3(0, H + 3.4, z), Vector3(30.0, 5.0, 0.4), m["dunkel"], false)
	_box(Vector3(0, H + 5.95, z + 0.05), Vector3(30.4, 0.2, 0.3), m["cyan"], false)
	_box(Vector3(0, H + 0.95, z + 0.05), Vector3(30.4, 0.2, 0.3), m["violett"], false)
	for s in [-1.0, 1.0]:
		_box(Vector3(s * 15.1, H + 3.4, z + 0.05), Vector3(0.2, 5.0, 0.3), m["pink"], false)
		_box(Vector3(s * 8.0, H + 0.5, z), Vector3(0.5, 1.0, 0.5), m["dunkel"], false)
	_schrift("NEON-MARKT", Vector3(-4.0, H + 4.1, z + 0.26), PINK.lightened(0.15), 200, 0.0135)
	_schrift("24/7", Vector3(10.5, H + 4.1, z + 0.26), CYAN, 200, 0.0135)
	_schrift("EINMAL SCANNEN, ENDLOS STRAHLEN", Vector3(0, H + 2.0, z + 0.26), VIOLETT.lightened(0.45), 64, 0.0105)
	_schrift("NEON-MARKT 24/7", Vector3(0, H + 3.4, z - 0.26), PINK.lightened(0.15), 200, 0.011, PI)


func _tueren_bewegen(delta: float) -> void:
	if _spieler == null or not is_instance_valid(_spieler):
		_spieler = get_tree().get_first_node_in_group("spieler") as Node3D
		return
	var z := T * 0.5 - WAND * 0.5
	for t in _tueren:
		var tp := to_global(Vector3(t[2], 1.0, z))
		var d := Vector2(_spieler.global_position.x - tp.x, _spieler.global_position.z - tp.z).length()
		var ziel := 1.0 if d < TUER_OEFFNEN else 0.0
		var offen: float = move_toward(t[3], ziel, delta * TUER_TEMPO)
		t[3] = offen
		var weg := TUER_B * 0.5 * offen
		(t[0] as Node3D).position.x = t[2] - TUER_B * 0.25 - weg
		(t[1] as Node3D).position.x = t[2] + TUER_B * 0.25 + weg


# ---------------------------------------------------------------- Boden, Decke, Licht

func _boden_decke_licht() -> void:
	var hz := T * 0.5
	# Boden: duenne Platte mit Kollision (Oberkante 2 cm)
	_box(Vector3(0, 0.005, 0), Vector3(B - 1.0, 0.03, T - 1.0), m["boden"])
	# Abgehaengte Decke
	_box(Vector3(0, DECKE_Y + 0.03, 0), Vector3(B - 1.0, 0.06, T - 1.0), m["decke"], false)
	# Leuchtstreifen (LED)
	for x in [-21.0, -14.0, -7.0, 0.0, 7.0, 14.0, 21.0]:
		for z in [-14.0, -8.0, -2.0, 4.0, 10.0, 15.0]:
			_box(Vector3(x, DECKE_Y - 0.02, z), Vector3(4.2, 0.05, 0.45), m["lampe"], false)
	# Klimarohre unter der Decke
	for z in [-5.0, 8.0]:
		_box(Vector3(0, DECKE_Y - 0.25, z), Vector3(B - 2.0, 0.28, 0.28), m["regal"], false)
	# Raumlicht: Raster aus Omni-Lichtern mit ueberlappender Reichweite, damit nichts dunkel bleibt
	for x in [-21.0, -7.0, 7.0, 21.0]:
		for z in [-12.0, -1.0, 10.0]:
			_licht(Vector3(x, 4.3, z), Color(1.0, 0.97, 0.92), 3.0, 18.0)
	_licht(Vector3(-17.0, 4.0, hz - 3.0), Color(1.0, 0.97, 0.92), 2.0, 14.0)
	_licht(Vector3(22.0, 4.0, hz - 3.0), Color(1.0, 0.97, 0.92), 2.0, 14.0)


# ---------------------------------------------------------------- Eingangsbereich

## Einkaufswagen: Rahmen, Drahtkorb (Streben), Raeder, Griff.
func _wagen(p: Vector3, rot_y := 0.0) -> void:
	var w := Node3D.new()
	w.position = p
	w.rotation.y = rot_y
	add_child(w)
	var stahl: Material = m["stahl"]
	_box(Vector3(0, 0.3, 0), Vector3(0.5, 0.03, 0.9), stahl, false, w)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_zyl(Vector3(sx * 0.22, 0.07, sz * 0.38), 0.06, 0.04, m["dunkel"], false, w, 8).rotation_degrees.z = 90.0
		_box(Vector3(sx * 0.27, 0.62, 0.0), Vector3(0.02, 0.025, 0.8), stahl, false, w)
		for k in 4:
			_box(Vector3(sx * 0.27, 0.4 + k * 0.1, 0.0), Vector3(0.02, 0.015, 0.8), stahl, false, w)
	for sz in [-1.0, 1.0]:
		_box(Vector3(0, 0.5, sz * 0.4), Vector3(0.54, 0.4, 0.02), m["glas"], false, w)
	_box(Vector3(0, 1.0, -0.46), Vector3(0.5, 0.04, 0.04), m["rot"], false, w)
	_box(Vector3(0.0, 0.62, -0.44), Vector3(0.02, 0.7, 0.02), stahl, false, w)


func _eingangsbereich() -> void:
	var hz := T * 0.5
	# Wagenbox innen links neben dem Eingang (ineinandergeschobene Wagen), Koerbe rechts davon
	for i in 7:
		_wagen(Vector3(-25.0 + i * 0.34, 0.02, hz - 3.0), 0.0)
	for i in 6:
		_wagen(Vector3(-25.0 + i * 0.34, 0.02, hz - 5.2), 0.0)
	for i in 8:
		_box(Vector3(-11.6, 0.1 + i * 0.12, hz - 2.2), Vector3(0.42, 0.1, 0.3), m["rot"], false)
		_box(Vector3(-11.0, 0.1 + i * 0.12, hz - 2.2), Vector3(0.42, 0.1, 0.3), m["rot"], false)
	# Pfandautomat an der Westwand
	var wx := -B * 0.5 + WAND + 0.5
	_box(Vector3(wx, 1.0, 10.5), Vector3(0.9, 2.0, 1.2), m["regal"])
	_box(Vector3(wx + 0.47, 1.3, 10.5), Vector3(0.04, 0.5, 0.7), m["schirm"], false)
	_box(Vector3(wx + 0.47, 0.8, 10.5), Vector3(0.04, 0.3, 0.6), m["dunkel_i"], false)
	_box(Vector3(wx + 0.47, 1.8, 10.5), Vector3(0.04, 0.1, 0.9), m["gruen_led"], false)
	# Poster an der Westwand
	_quad(Vector3(wx - 0.24, 2.4, 14.5), Vector2(1.2, 1.8), m["poster"], PI * 0.5)


# ---------------------------------------------------------------- Obst und Gemuese

func _obst_gemuese() -> void:
	var kugel := SphereMesh.new()
	kugel.radius = 0.5
	kugel.height = 1.0
	kugel.radial_segments = 8
	kugel.rings = 4
	var zyl := CylinderMesh.new()
	zyl.top_radius = 0.5
	zyl.bottom_radius = 0.5
	zyl.height = 1.0
	zyl.radial_segments = 6
	var tk: Array = []
	var fk: Array = []
	var tz: Array = []
	var fz: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 247
	var sorten := [
		[true, Color(0.85, 0.1, 0.08), 0.085],    # Aepfel
		[true, Color(0.98, 0.55, 0.05), 0.09],    # Orangen
		[true, Color(0.98, 0.88, 0.15), 0.07],    # Zitronen
		[true, Color(0.9, 0.12, 0.05), 0.07],     # Tomaten
		[false, Color(0.25, 0.65, 0.15), 0.045],  # Gurken
		[false, Color(0.95, 0.5, 0.08), 0.03],    # Moehren
		[true, Color(0.35, 0.55, 0.15), 0.08],    # Birnen
		[true, Color(0.55, 0.15, 0.55), 0.07],    # Auberginen
		[true, Color(0.8, 0.7, 0.3), 0.065],      # Kartoffeln
	]
	var nr := 0
	var xs: Array[float] = [-22.5, -15.0]
	var zs: Array[float] = [-1.2, 2.8, 6.8]
	for x in xs:
		for z in zs:
			# Tisch mit Holzsockel und Kisten (leicht geneigt), je drei Kisten mit einer Sorte
			_box(Vector3(x, 0.3, z), Vector3(3.6, 0.6, 1.5), m["kiste"])
			for k in 3:
				var kx := x - 1.2 + k * 1.2
				_box(Vector3(kx, 0.68, z), Vector3(1.1, 0.12, 1.3), m["kiste"], false)
				_box(Vector3(kx, 0.78, z + 0.64), Vector3(1.1, 0.14, 0.03), m["kiste"], false)
				var sorte: Array = sorten[(nr * 3 + k) % sorten.size()]
				for q in 34:
					var p := Vector3(kx + rng.randf_range(-0.46, 0.46), 0.82 + rng.randf() * 0.06, z + rng.randf_range(-0.55, 0.55))
					var s: float = sorte[2] * 2.0
					if sorte[0]:
						tk.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s * rng.randf_range(0.9, 1.15)), p))
						fk.append((sorte[1] as Color).lerp(Color(1, 1, 1), rng.randf() * 0.08))
					else:
						var b := Basis(Vector3(0, 0, 1), PI * 0.5).rotated(Vector3.UP, rng.randf() * PI).scaled(Vector3(s * 0.6, s * 3.0, s * 0.6))
						tz.append(Transform3D(b, p))
						fz.append(sorte[1])
			nr += 1
	_multimesh(kugel, tk, fk)
	_multimesh(zyl, tz, fz)
	# Obstwand an der Westwand: Holzregal mit Stufen und Obst
	var wx := -B * 0.5 + WAND + 0.5
	for st in 3:
		_box(Vector3(wx, 0.5 + st * 0.6, -1.0), Vector3(1.0, 0.05, 9.0), m["kiste"], st == 0)
		for i in 8:
			var cz := -4.5 + i * 1.1
			var farbe: Color = [Color(0.85, 0.1, 0.08), Color(0.98, 0.6, 0.1), Color(0.4, 0.7, 0.2), Color(0.95, 0.85, 0.2)][(i + st) % 4]
			var fm := _std(farbe, 0.0, 0.0, 0.4)
			for q in 3:
				_kugel(Vector3(wx - 0.1 + (q % 2) * 0.3, 0.64 + st * 0.6, cz + q * 0.28 - 0.3), 0.1, fm)
	_haengeschild(Vector3(-18.0, 3.7, 3.0), "OBST & GEMÜSE", Color(0.3, 0.85, 0.35))
	# Daempffeld ueber dem Gemuese (violett, pulsierend), vier Geraetepfosten an den Ecken, Warnplakette
	var fx := (FELD_X0 + FELD_X1) * 0.5
	var fz2 := (FELD_Z0 + FELD_Z1) * 0.5
	_box(Vector3(fx, FELD_H * 0.5, fz2), Vector3(FELD_X1 - FELD_X0, FELD_H, FELD_Z1 - FELD_Z0), m["feld"], false)
	for cx in [FELD_X0, FELD_X1]:
		for cz in [FELD_Z0, FELD_Z1]:
			_box(Vector3(cx, 1.6, cz), Vector3(0.22, 3.2, 0.22), m["regal_d"])
			_box(Vector3(cx, 3.0, cz), Vector3(0.26, 0.3, 0.26), m["violett_i"], false)
	_box(Vector3(FELD_X1 - 0.5, 1.7, FELD_Z1 + 0.14), Vector3(1.1, 0.3, 0.04), m["dunkel_i"], false)
	_schrift("DÄMPFFELD AKTIV", Vector3(FELD_X1 - 0.5, 1.7, FELD_Z1 + 0.17), Color(0.85, 0.7, 1.0), 24, 0.0042)
	# Gurke Nr. 4: Kiste auf Brandfleck mit Absperrband und Plakette (Ecke Nordwest vor der Frischetheke)
	var kx2 := -B * 0.5 + 2.6
	var kz := -7.0
	_zyl(Vector3(kx2, 0.025, kz), 1.5, 0.01, _std(Color(0.03, 0.03, 0.04), 0.0, 0.0, 0.9), false)
	_box(Vector3(kx2, 0.3, kz), Vector3(1.2, 0.6, 0.8), m["kiste"])
	_box(Vector3(kx2, 0.62, kz), Vector3(1.04, 0.04, 0.64), m["dunkel_i"], false)
	var gurke := _zyl(Vector3(kx2, 0.74, kz), 0.1, 0.7, _std(Color(0.25, 0.7, 0.2), 0.6, 0.0, 0.4), false, null, 12)
	gurke.rotation_degrees.z = 90.0
	for s in [-1.0, 1.0]:
		_zyl(Vector3(kx2 + s * 1.4, 0.5, kz + 1.0), 0.04, 1.0, m["gelb"], false, null, 6)
	_box(Vector3(kx2, 0.85, kz + 1.0), Vector3(2.8, 0.1, 0.02), m["gelb"], false)
	_box(Vector3(kx2, 1.3, kz + 0.9), Vector3(0.8, 0.3, 0.03), m["dunkel_i"], false)
	_schrift("GURKE NR. 4", Vector3(kx2, 1.3, kz + 0.93), Color(0.6, 1.0, 0.5), 28, 0.0045)


func _multimesh(mesh: Mesh, trafos: Array, farben: Array) -> void:
	if trafos.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = trafos.size()
	for i in trafos.size():
		mm.set_instance_transform(i, trafos[i])
		mm.set_instance_color(i, farben[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.45
	mat.disable_ambient_light = true
	mi.material_override = mat
	add_child(mi)


# ---------------------------------------------------------------- Regalgaenge

## Doppelseitiges Gondelregal: Stahlkern, 5 Regalboeden je Seite, Produktreihen, Preisschienen, Kopfleiste, Endstaender.
func _gondel(x: float, kat: String, titel: String, farbe: Color) -> void:
	var z0 := GONDEL_Z0
	var z1 := GONDEL_Z1
	var l := z1 - z0
	var zm := (z0 + z1) * 0.5
	_box(Vector3(x, 1.1, zm), Vector3(0.5, 2.2, l), m["regal_d"])
	_box(Vector3(x, 0.07, zm), Vector3(1.5, 0.14, l + 0.1), m["regal_d"], false)
	for s in [-1.0, 1.0]:
		for k in REGAL_STUFEN:
			var y := 0.18 + k * STUFE_H
			_box(Vector3(x + s * 0.5, y, zm), Vector3(0.5, 0.03, l), m["regal"], false)
			_box(Vector3(x + s * 0.745, y + 0.02, zm), Vector3(0.02, 0.05, l), m["weiss"], false)
			var q := _quad(Vector3(x + s * 0.62, y + 0.22, zm), Vector2(l, 0.4), _prod(kat, (k + int(x)) % 3, l))
			q.rotation.y = PI * 0.5 if s > 0.0 else -PI * 0.5
		for i in int(l) + 1:
			_box(Vector3(x + s * 0.74, 1.2, z0 + i), Vector3(0.04, 2.1, 0.04), m["regal_d"], false)
	# Kopfleiste (Neonkante in Abteilungsfarbe) und Endstaender mit Promo-Ware
	_box(Vector3(x, 2.28, zm), Vector3(1.5, 0.16, l), m["regal_d"], false)
	_box(Vector3(x, 2.37, zm), Vector3(1.52, 0.03, l + 0.02), _std(farbe, 1.2), false)
	for ez in [z0 - 0.5, z1 + 0.5]:
		_box(Vector3(x, 0.55, ez), Vector3(1.3, 1.1, 0.7), m["regal"])
		var vorn: bool = ez > zm
		_quad(Vector3(x, 0.78, ez + (0.36 if vorn else -0.36)), Vector2(1.2, 0.35), _prod(kat, 1, 2.0), 0.0 if vorn else PI)
		_box(Vector3(x, 1.12, ez), Vector3(1.34, 0.04, 0.74), _std(farbe, 0.8), false)
	_haengeschild(Vector3(x, 3.5, zm), titel, farbe)


func _gaenge() -> void:
	var gaenge := [
		["snack", "SNACKS & NEON-DRINKS", PINK],
		["getraenke", "GETRÄNKE", Color(0.2, 0.7, 1.0)],
		["konserven", "KONSERVEN", Color(1.0, 0.65, 0.2)],
		["synth", "SYNTH-FOOD", VIOLETT],
		["energie", "ENERGIEZELLEN  UNTERSTADT", CYAN],
		["salz", "ISA-HELDENBEDARF: SALZ", Color(0.85, 0.9, 1.0)],
	]
	for i in gaenge.size():
		_gondel(GONDEL_X[i], gaenge[i][0], gaenge[i][1], gaenge[i][2])


# ---------------------------------------------------------------- Rueckwand

## Offenes Kuehlregal (Multideck) an der Rueckwand: Stahlkorpus, 5 Boeden mit Produkten, Lichtleiste (ohne Glas).
func _kuehlregal(cx: float, breite: float, kat: String) -> void:
	var z := -T * 0.5 + WAND + 0.55
	_box(Vector3(cx, 1.15, z - 0.2), Vector3(breite, 2.3, 0.2), m["stahl"])
	_box(Vector3(cx, 0.1, z + 0.1), Vector3(breite, 0.2, 0.9), m["stahl"], true)
	for k in 5:
		var y := 0.35 + k * 0.4
		_box(Vector3(cx, y, z + 0.03), Vector3(breite, 0.03, 0.62), m["regal"], false)
		_quad(Vector3(cx, y + 0.21, z + 0.31), Vector2(breite, 0.38), _prod(kat, k % 3, breite))
	_box(Vector3(cx, 2.3, z + 0.1), Vector3(breite, 0.12, 0.85), m["stahl"], false)
	_box(Vector3(cx, 2.22, z + 0.35), Vector3(breite - 0.1, 0.04, 0.12), m["cyan_i"], false)
	for s in [-1.0, 1.0]:
		_box(Vector3(cx + s * (breite * 0.5), 1.15, z + 0.1), Vector3(0.04, 2.3, 0.9), m["stahl"], false)


func _rueckwand() -> void:
	var hz := -T * 0.5 + WAND
	# Frischetheke (Bedientheke) im Nordwesten: Glasvitrine mit Fleisch und Kaese, Fliesenwand, Personalbereich
	var fx := -21.5
	_box(Vector3(fx, 0.55, -12.5), Vector3(9.0, 1.1, 1.2), m["weiss"])
	_box(Vector3(fx, 0.5, -12.5 + 0.63), Vector3(9.0, 0.9, 0.04), m["stahl"], false)
	_box(Vector3(fx, 1.12, -12.5), Vector3(9.1, 0.04, 1.3), m["stahl"], false)
	_quad(Vector3(fx, 1.35, -12.5), Vector2(9.0, 0.4), _bild("frische", 3.0, 0.1), 0.0, -1.1)
	var scheibe := _box(Vector3(fx, 1.62, -12.1), Vector3(9.0, 0.6, 0.02), m["glas"], false)
	scheibe.rotation_degrees.x = -25.0
	for i in 7:
		_box(Vector3(fx - 4.5 + i * 1.5, 1.5, -12.0), Vector3(0.03, 0.8, 0.03), m["stahl"], false)
	_box(Vector3(fx, 1.95, -12.2), Vector3(9.0, 0.04, 0.4), m["lampe"], false)
	_box(Vector3(fx, 1.2, hz + 0.1 + 0.55), Vector3(9.0, 2.4, 0.06), m["fliese_w"], false)
	_box(Vector3(fx, 0.5, hz + 1.8), Vector3(8.0, 1.0, 0.8), m["stahl"])
	_box(Vector3(fx - 2.0, 1.3, hz + 1.8), Vector3(0.9, 0.6, 0.6), m["weiss"], false)
	_haengeschild(Vector3(fx, 3.5, -12.5), "FRISCHETHEKE", Color(1.0, 0.4, 0.5))
	# Kuehlregale (Milch, Joghurt, Kaese) in der Mitte der Rueckwand
	var breite := 4.6
	for i in 5:
		_kuehlregal(-12.0 + breite * 0.5 + i * breite, breite, "milch")
	_haengeschild(Vector3(-0.5, 3.6, -14.5), "MILCH & FRISCHE: KÜHLE MILCH", Color(0.5, 0.8, 1.0))
	# Tiefkuehlwand mit Glastueren
	for i in 2:
		var cx := 14.5 + i * 4.0
		var z := -T * 0.5 + WAND + 0.55
		_box(Vector3(cx, 1.15, z - 0.2), Vector3(3.9, 2.3, 0.2), m["stahl"])
		_box(Vector3(cx, 0.15, z + 0.1), Vector3(3.9, 0.3, 0.9), m["stahl"])
		for k in 4:
			_quad(Vector3(cx, 0.55 + k * 0.5, z + 0.3), Vector2(3.8, 0.46), _prod("tiefkuehl", k % 3, 3.8))
		for d in 3:
			var dx := cx - 1.3 + d * 1.3
			_box(Vector3(dx, 1.2, z + 0.52), Vector3(1.24, 2.0, 0.03), m["glas"], false)
			_box(Vector3(dx - 0.62, 1.2, z + 0.54), Vector3(0.03, 2.0, 0.05), m["alu"], false)
			_box(Vector3(dx + 0.5, 1.2, z + 0.57), Vector3(0.03, 0.6, 0.04), m["alu"], false)
		_box(Vector3(cx, 2.3, z + 0.1), Vector3(3.9, 0.14, 0.9), m["stahl"], false)
		_box(Vector3(cx, 2.22, z + 0.52), Vector3(3.8, 0.04, 0.05), m["cyan_i"], false)
	_haengeschild(Vector3(16.5, 3.6, -14.8), "TIEFKÜHLUNG", Color(0.5, 0.9, 1.0))
	# Backwaren in der Nordostecke: Holzregalwand mit Broten, Theke, Ofen
	var bx := 24.0
	_box(Vector3(bx, 1.25, hz + 0.3), Vector3(6.6, 2.5, 0.3), m["eiche"])
	for k in 3:
		_box(Vector3(bx, 0.5 + k * 0.7, hz + 0.65), Vector3(6.4, 0.05, 0.5), m["eiche"], false)
		_quad(Vector3(bx, 0.77 + k * 0.7, hz + 0.9), Vector2(6.2, 0.55), _bild("backwaren2", 3.0, 0.1))
	_box(Vector3(bx, 0.55, hz + 3.2), Vector3(6.0, 1.1, 0.9), m["eiche"])
	_box(Vector3(bx, 1.12, hz + 3.2), Vector3(6.1, 0.04, 1.0), m["stahl"], false)
	_quad(Vector3(bx, 1.35, hz + 3.15), Vector2(5.8, 0.55), _bild("backwaren2", 3.0, 0.1), 0.0, -0.8)
	_box(Vector3(bx, 1.55, hz + 3.55), Vector3(6.0, 0.4, 0.02), m["glas"], false)
	_box(Vector3(bx + 4.1, 1.0, hz + 1.2), Vector3(1.4, 2.0, 1.2), m["stahl"])
	_box(Vector3(bx + 4.1, 1.1, hz + 1.82), Vector3(1.0, 0.8, 0.03), m["dunkel_i"], false)
	_box(Vector3(bx + 4.1, 1.1, hz + 1.84), Vector3(0.6, 0.4, 0.005), _std(Color(1.0, 0.55, 0.15), 1.4), false)
	_haengeschild(Vector3(bx, 3.5, hz + 3.0), "BACKWAREN", Color(1.0, 0.75, 0.3))


# ---------------------------------------------------------------- Gewuerze (Ostwand)

func _gewuerz_wand() -> void:
	var wx := B * 0.5 - WAND - 0.45
	for i in 6:
		var z := -14.0 + i * 1.6
		var verbrannt := i == 3
		_box(Vector3(wx + 0.05, 1.15, z), Vector3(0.5, 2.3, 1.55), m["regal_d"])
		for k in 5:
			_box(Vector3(wx - 0.18, 0.3 + k * 0.42, z), Vector3(0.4, 0.03, 1.55), m["regal"], false)
			var q := _quad(Vector3(wx - 0.3, 0.5 + k * 0.42, z), Vector2(1.5, 0.38), _prod("gewuerz", (i + k) % 3, 1.5))
			q.rotation.y = -PI * 0.5
		if verbrannt:
			_box(Vector3(wx - 0.32, 1.1, z), Vector3(0.02, 2.2, 1.5), _std(Color(0.03, 0.03, 0.04), 0.0, 0.0, 0.9), false)
			_box(Vector3(wx - 0.34, 0.65, z), Vector3(0.02, 0.28, 0.5), _std(Color(1.0, 0.3, 0.05), 1.3, 0.0, 0.5), false)
	_haengeschild(Vector3(wx - 0.6, 3.4, -9.0), "EXOTISCHE GEWÜRZE", Color(1.0, 0.55, 0.25), PI * 0.5)
	_box(Vector3(wx - 0.45, 2.5, -9.2), Vector3(0.04, 0.3, 1.5), m["dunkel_i"], false)
	_schrift("PLATZ 4: SCHOTE HAT GEKÜNDIGT", Vector3(wx - 0.48, 2.5, -9.2), Color(1.0, 0.85, 0.6), 20, 0.0045, -PI * 0.5)


# ---------------------------------------------------------------- Kassenzone

func _kassenzone() -> void:
	for i in KASSEN_X.size():
		_kasse(KASSEN_X[i], i + 1)
	# Selbstscan-Kassen: zwei Kioske links der Kassenzone
	for i in 2:
		_sb_kasse(-1.0 - i * 3.0)
	_haengeschild(Vector3(-2.5, 3.5, 7.0), "SELBSTSCAN", Color(0.3, 0.9, 0.7))
	_haengeschild(Vector3(12.0, 3.6, 5.0), "KASSEN", Color(1.0, 0.85, 0.3))
	# Banner mit Slogan ueber den Kassen als feste Tafel
	_box(Vector3(12.0, 4.2, 12.0), Vector3(15.0, 0.5, 0.08), m["dunkel_i"], false)
	_schrift("EINMAL SCANNEN, ENDLOS STRAHLEN", Vector3(12.0, 4.2, 12.05), Color(0.8, 0.9, 1.0), 40, 0.0072)
	_box(Vector3(12.0, 3.92, 12.0), Vector3(15.0, 0.04, 0.1), m["pink_i"], false)
	# Express-Drohnen-Annahme an der Ostwand vorn
	var ex := B * 0.5 - WAND - 0.8
	_box(Vector3(ex, 0.55, 12.0), Vector3(1.2, 1.1, 4.0), m["regal"])
	_box(Vector3(ex, 1.12, 12.0), Vector3(1.3, 0.04, 4.1), m["stahl"], false)
	_box(Vector3(ex + 0.5, 1.9, 12.0), Vector3(0.06, 1.0, 2.6), m["dunkel_i"], false)
	_box(Vector3(ex + 0.46, 1.9, 12.0), Vector3(0.02, 0.9, 2.4), m["schirm"], false)
	_schrift("DROHNEN-ANNAHME", Vector3(ex - 0.55, 2.8, 12.0), Color(0.8, 1.0, 1.0), 28, 0.0055, -PI * 0.5)


func _kasse(x: float, nr: int) -> void:
	var z0 := 5.5
	# Foerderband (Gummi) auf weissem Korpus, Kassenpult mit Bildschirm und Scanner, Packbereich
	_box(Vector3(x, 0.45, z0 + 1.5), Vector3(0.9, 0.9, 3.0), m["weiss"])
	_box(Vector3(x, 0.92, z0 + 1.5), Vector3(0.66, 0.03, 2.9), m["gummi"], false)
	_box(Vector3(x - 0.36, 0.94, z0 + 1.5), Vector3(0.05, 0.05, 2.9), m["stahl"], false)
	_box(Vector3(x + 0.36, 0.94, z0 + 1.5), Vector3(0.05, 0.05, 2.9), m["stahl"], false)
	_box(Vector3(x, 0.5, z0 + 3.9), Vector3(1.5, 1.0, 0.8), m["weiss"])
	_box(Vector3(x, 1.02, z0 + 3.9), Vector3(1.55, 0.04, 0.84), m["stahl"], false)
	_box(Vector3(x - 0.3, 1.3, z0 + 3.75), Vector3(0.5, 0.35, 0.04), m["dunkel_i"], false)
	_box(Vector3(x - 0.3, 1.3, z0 + 3.72), Vector3(0.44, 0.29, 0.005), m["schirm"], false)
	_box(Vector3(x - 0.3, 1.13, z0 + 3.75), Vector3(0.05, 0.2, 0.05), m["dunkel_i"], false)
	_box(Vector3(x + 0.25, 1.06, z0 + 3.5), Vector3(0.3, 0.02, 0.18), m["dunkel_i"], false)
	_box(Vector3(x + 0.5, 1.12, z0 + 3.8), Vector3(0.1, 0.14, 0.18), m["dunkel_i"], false)
	# Kassenleuchte mit Nummer (feste Anzeige auf Mast)
	_box(Vector3(x + 0.8, 1.5, z0 + 3.9), Vector3(0.06, 3.0, 0.06), m["regal_d"], false)
	_box(Vector3(x + 0.8, 3.1, z0 + 3.9), Vector3(0.4, 0.4, 0.14), m["dunkel_i"], false)
	_box(Vector3(x + 0.8, 2.86, z0 + 3.9), Vector3(0.36, 0.05, 0.16), m["gruen_led"] if nr != 5 else m["rot_led"], false)
	_schrift(str(nr), Vector3(x + 0.8, 3.1, z0 + 3.98), Color(0.5, 1.0, 0.6), 48, 0.006)
	_schrift(str(nr), Vector3(x + 0.8, 3.1, z0 + 3.82), Color(0.5, 1.0, 0.6), 48, 0.006, PI)
	# Quengelregal am Anfang der Spur mit Snacks
	_box(Vector3(x, 0.55, z0 - 0.4), Vector3(1.0, 1.1, 0.4), m["regal_d"])
	_quad(Vector3(x, 0.55, z0 - 0.19), Vector2(0.96, 0.6), _prod("snack", nr % 3, 1.0))
	_quad(Vector3(x, 0.55, z0 - 0.61), Vector2(0.96, 0.6), _prod("snack", (nr + 1) % 3, 1.0), PI)
	# Trenner zwischen den Spuren: niedriges Regal
	if nr < KASSEN_X.size():
		_box(Vector3(x + 1.75, 0.5, z0 + 1.5), Vector3(0.4, 1.0, 3.0), m["regal"])


func _sb_kasse(x: float) -> void:
	var z := 9.5
	_box(Vector3(x, 0.55, z), Vector3(0.7, 1.1, 0.7), m["weiss"])
	_box(Vector3(x, 1.5, z - 0.1), Vector3(0.6, 0.45, 0.05), m["dunkel_i"], false)
	_box(Vector3(x, 1.5, z - 0.13), Vector3(0.54, 0.4, 0.005), m["schirm"], false)
	_box(Vector3(x, 1.12, z + 0.1), Vector3(0.4, 0.02, 0.3), m["dunkel_i"], false)
	_box(Vector3(x + 1.0, 0.45, z), Vector3(0.9, 0.9, 0.7), m["weiss"])
	_box(Vector3(x + 1.0, 0.92, z), Vector3(0.9, 0.03, 0.7), m["stahl"], false)


# ---------------------------------------------------------------- Aussen

func _drohne(pos: Vector3, mit_paket := true) -> Node3D:
	var d := Node3D.new()
	d.position = pos
	add_child(d)
	_box(Vector3.ZERO, Vector3(1.4, 0.4, 1.0), m["dunkel"], false, d)
	_box(Vector3(0, 0.12, 0.52), Vector3(0.5, 0.1, 0.02), m["pink"], false, d)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(Vector3(sx * 0.7, 0.05, sz * 0.5), Vector3(0.9, 0.06, 0.06), m["dunkel"], false, d)
			var r := Node3D.new()
			r.position = Vector3(sx * 1.1, 0.12, sz * 0.8)
			d.add_child(r)
			_zyl(Vector3.ZERO, 0.45, 0.02, m["cyan"], false, r, 12)
			_rotoren.append(r)
	if mit_paket:
		_box(Vector3(0, -0.5, 0), Vector3(0.7, 0.5, 0.6), m["fassade"], false, d)
		_box(Vector3(0, -0.5, 0.31), Vector3(0.5, 0.1, 0.02), m["gelb"], false, d)
	return d


func _drohnen_bauen() -> void:
	for i in DROHNEN_ANZAHL:
		_drohnen.append(_drohne(Vector3(0, DROHNEN_HOEHE, 0)))
	# Lieferdrohnen-Deck auf dem Dach: drei Landeplaetze, eine geparkte Drohne
	var deck := Vector3(-18.0, H + 0.45, -8.0)
	for i in 3:
		var p := deck + Vector3(i * 6.0, 0.0, 0)
		_zyl(p, 2.2, 0.06, m["dunkel"], false)
		_zyl(p + Vector3(0, 0.04, 0), 2.0, 0.04, m["cyan"], false, null, 24)
		_zyl(p + Vector3(0, 0.07, 0), 1.7, 0.04, m["dunkel"], false, null, 24)
	_drohne(deck + Vector3(6.0, 0.5, 0), true)
	# Dachtechnik: Klimageraete und Antenne mit Warnleuchte
	for i in 4:
		_box(Vector3(14.0 + i * 3.4, H + 1.0, -10.0), Vector3(2.6, 1.2, 2.2), m["fassade"], false)
	_zyl(Vector3(25.0, H + 6.0, -12.0), 0.15, 12.0, m["dunkel"], false)
	_kugel(Vector3(25.0, H + 12.1, -12.0), 0.35, m["rot_led"])


func _aussen() -> void:
	var hz := T * 0.5
	# Vorplatz (Pflaster) mit Leitstreifen, Laternen und Pollern
	_box(Vector3(0, 0.005, hz + VORPLATZ_TIEFE * 0.5), Vector3(B + 4.0, 0.03, VORPLATZ_TIEFE), m["vorplatz"], false)
	for i in 5:
		var c: Material = [m["pink"], m["cyan"], m["violett"]][i % 3]
		_box(Vector3(-16.0 + i * 8.0, 0.03, hz + 5.0), Vector3(0.25, 0.01, VORPLATZ_TIEFE - 2.0), c, false)
	for x in [-24.0, -8.0, 8.0, 24.0]:
		_zyl(Vector3(x, 3.0, hz + 9.0), 0.12, 6.0, m["dunkel"], true)
		_kugel(Vector3(x, 6.1, hz + 9.0), 0.35, m["pink"] if x < 0 else m["cyan"])
		_licht(Vector3(x, 5.6, hz + 9.0), PINK if x < 0 else CYAN, 1.2, 12.0)
	for x in range(-24, 25, 6):
		_zyl(Vector3(x, 0.5, hz + 11.2), 0.12, 1.0, m["violett"], true, null, 8)
	# Wagenbox vor dem Eingang
	for i in 6:
		_wagen(Vector3(-24.0 + i * 0.34, 0.02, hz + 2.2), 0.0)
	_box(Vector3(-23.0, 1.2, hz + 2.2), Vector3(3.0, 0.06, 1.2), m["dunkel"], false)
	_licht(Vector3(0, 4.0, hz + 4.0), Color(1.0, 0.8, 0.95), 1.6, 16.0)
	# Hoverboard-Drive-In an der Ostseite: Dach auf vier Pfosten, Leuchtring, schwebende Bretter
	var dx := B * 0.5 + 8.0
	_box(Vector3(dx, 4.2, 6.0), Vector3(10.0, 0.4, 10.0), m["dunkel"], false)
	_box(Vector3(dx, 3.95, 11.1), Vector3(10.0, 0.14, 0.1), m["pink"], false)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_zyl(Vector3(dx + sx * 4.6, 2.1, 6.0 + sz * 4.6), 0.22, 4.2, m["dunkel"], true)
	_zyl(Vector3(dx, 0.04, 6.0), 4.2, 0.06, m["dunkel"], false, null, 32)
	_zyl(Vector3(dx, 0.08, 6.0), 3.8, 0.04, m["cyan"], false, null, 32)
	_zyl(Vector3(dx, 0.11, 6.0), 3.5, 0.04, m["dunkel"], false, null, 32)
	_box(Vector3(dx, 4.55, 11.15), Vector3(5.0, 0.6, 0.06), m["dunkel"], false)
	_schrift("HOVERBOARD-DRIVE-IN", Vector3(dx, 4.55, 11.2), CYAN, 40, 0.0085)
	for i in 2:
		var b := Node3D.new()
		b.position = Vector3(dx - 1.4 + i * 2.8, 0.9, 6.0)
		b.rotation.y = 0.5 - i
		add_child(b)
		_box(Vector3.ZERO, Vector3(1.5, 0.1, 0.45), _std(Color(0.2, 0.25, 0.55), 0.0, 0.9, 0.2, false), false, b)
		_box(Vector3(0, 0.06, 0), Vector3(1.3, 0.02, 0.15), m["gelb"], false, b)
		_box(Vector3(0, -0.07, 0), Vector3(1.3, 0.03, 0.4), m["cyan"], false, b)
		_bretter.append(b)
	_licht(Vector3(dx, 3.0, 6.0), CYAN, 1.5, 12.0)
