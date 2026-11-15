extends "res://levels/haus.gd"
## Popcorn-Labor: begehbares Laborgebaeude mit vier Etagen und Treppenhaus (Basis: levels/haus.gd).
## Front mit Eingang zeigt lokal nach +z. Wird von stadt.gd (_popcorn) erzeugt.
## EG Empfang und Mais-Anlieferung, 1. OG Chemielabor, 2. OG Popcorn-Reaktor (Mais poppt im Glaskessel),
## 3. OG Analyse und Buero. Darueber ein geschlossenes Technikgeschoss, auf dem Dach der Popcorn-Eimer.
## Keine Signale, keine Exporte.

const B := 34.0
const T := 34.0
const ETAGEN := 4
const ETAGE_H := 5.0
const HOEHE_GESAMT := 30.0        ## Oberkante Technikgeschoss (wie der fruehere Block)
const EIMER_H := 16.0
const EIMER_R := Vector2(7.0, 10.0)   ## Radius unten, oben
const STREIFEN := 8
const MAIS_AUF_DACH := 45
const REAKTOR_R := 2.6
const REAKTOR_H := 3.4
const POPCORN_IM_KESSEL := 26
const POP_HOEHE := 2.2            ## so hoch springt ein Korn im Kessel
const FLUESSIG: Array[Color] = [
	Color(0.2, 0.8, 1.0), Color(1.0, 0.75, 0.1), Color(0.4, 1.0, 0.4), Color(1.0, 0.3, 0.6), Color(0.7, 0.4, 1.0),
]

var _koerner: Array = []          ## je Korn im Kessel: [Knoten, Phase, Tempo, Grundposition]
var _rot_licht: OmniLight3D


func _bauen() -> void:
	name = "PopcornLabor"
	_basis_materialien()
	m["boden"] = _tex("markt_large_grey_tiles", 3.0, Color(1.1, 1.1, 1.12))
	m["boden_oben"] = _tex("markt_boden_fliese", 2.4, Color(1.0, 1.0, 1.03))
	m["karton"] = _tex("markt_plywood", 1.2, Color(0.8, 0.65, 0.45))
	m["wand"] = _tex("markt_plastered_wall_04", 3.0, Color(1.6, 1.6, 1.65))
	m["fassade"] = _tex("concrete_tile_facade", 4.0, Color(0.72, 0.76, 0.86), 0.2, 1.0, false)
	m["labor"] = _std(Color(0.92, 0.93, 0.95), 0.0, 0.05, 0.4)
	m["platte"] = _std(Color(0.13, 0.14, 0.17), 0.0, 0.1, 0.35)
	m["gelb"] = _std(Color(1.0, 0.8, 0.1), 0.0, 0.0, 0.6)
	m["mais"] = _std(Color(0.95, 0.75, 0.15), 0.0, 0.0, 0.7)
	m["popcorn"] = _std(Color(1.0, 0.95, 0.75), 0.0, 0.0, 0.9)
	m["popcorn_a"] = _std(Color(1.0, 0.95, 0.7), 0.5, 0.0, 0.9, false)
	m["rot"] = _std(Color(0.85, 0.1, 0.1), 0.0, 0.1, 0.5)
	m["rot_a"] = _std(Color(0.9, 0.1, 0.1), 0.4, 0.0, 0.5, false)
	m["weiss_a"] = _std(Color(1, 1, 1), 0.5, 0.0, 0.5, false)
	m["glut"] = _std(Color(1.0, 0.35, 0.05), 3.0)
	m["led_g"] = _std(Color(0.2, 1.0, 0.4), 2.5)
	m["led_b"] = _std(Color(0.2, 0.6, 1.0), 2.5)
	m["gruen"] = _std(Color(0.1, 0.55, 0.25), 0.3)
	m["sack"] = _tex("markt_plywood", 1.0, Color(0.9, 0.82, 0.65))
	for i in FLUESSIG.size():
		var f := _std(Color(FLUESSIG[i].r, FLUESSIG[i].g, FLUESSIG[i].b, 0.75), 0.6, 0.0, 0.2)
		f.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m["fluessig%d" % i] = f
	_rohbau(B, T, ETAGEN, ETAGE_H, 0.0, 4.4)
	_aussen()
	_empfang()
	_chemielabor()
	_reaktor()
	_analyse()
	_buecher_bauen()


func _leben(_delta: float) -> void:
	for k in _koerner:
		var n: Node3D = k[0]
		var t := fmod(zeit * k[2] + k[1], 1.0)
		var grund: Vector3 = k[3]
		# Wurfparabel: Korn springt hoch und faellt zurueck
		n.position = grund + Vector3(0, 4.0 * t * (1.0 - t) * POP_HOEHE, 0)
		n.rotation = Vector3(t * TAU, k[1] * TAU, 0)
	if _rot_licht != null:
		_rot_licht.light_energy = 1.6 + 0.5 * sin(zeit * 3.0)


# ---------------------------------------------------------------- Aussen

func _aussen() -> void:
	var dach := boden_y(ETAGEN) + DECKE
	# Geschlossenes Technikgeschoss, zurueckgesetzt
	var tech_h := HOEHE_GESAMT - dach
	_box(Vector3(0, dach + tech_h * 0.5, 0), Vector3(B - 6.0, tech_h, T - 6.0), m["fassade"])
	for s: float in [-1.0, 1.0]:
		_box(Vector3(0, dach + tech_h - 1.2, s * (T * 0.5 - 2.95)), Vector3(B - 6.0, 0.25, 0.12), m["akzent"], false)
		for i in 5:
			_box(Vector3(-10.0 + i * 5.0, dach + tech_h * 0.45, s * (T * 0.5 - 2.95)), Vector3(2.6, 2.2, 0.1), m["rahmen"], false)
	# Popcorn-Eimer mit rot-weissen Streifen und Popcorn (wie bisher, jetzt auf dem Technikgeschoss)
	var ey := HOEHE_GESAMT + EIMER_H * 0.5
	_zyl(Vector3(0, ey, 0), EIMER_R.x, EIMER_H, m["rot_a"], null, EIMER_R.y, 24, true)
	for i in STREIFEN:
		var w := TAU * i / float(STREIFEN)
		var s := _box(Vector3(cos(w) * 8.5, ey, sin(w) * 8.5), Vector3(2.2, EIMER_H, 0.3), m["weiss_a"], false)
		s.rotation.y = -w + PI / 2.0
	for i in MAIS_AUF_DACH:
		var w := _rng.randf() * TAU
		var rr := sqrt(_rng.randf()) * 9.0
		_kugel(Vector3(cos(w) * rr, HOEHE_GESAMT + EIMER_H + _rng.randf() * 6.0, sin(w) * rr), _rng.randf_range(1.5, 2.6), m["popcorn_a"])
	_licht(Vector3(0, HOEHE_GESAMT + EIMER_H + 10.0, 0), Color(1.0, 0.85, 0.4), 4.0, 60.0)
	# Eingang: Vordach, Schriftzug, Leuchtband
	var zf := T * 0.5
	_box(Vector3(0, TUER_H + 0.6, zf + 1.6), Vector3(9.0, 0.25, 3.2), m["rahmen"], false)
	for sx: float in [-1.0, 1.0]:
		_zyl(Vector3(sx * 4.2, (TUER_H + 0.5) * 0.5, zf + 2.9), 0.12, TUER_H + 0.5, m["chrom"], null, -1.0, 10, true)
	_box(Vector3(0, TUER_H + 0.45, zf + 3.15), Vector3(9.0, 0.08, 0.08), m["akzent"], false)
	_text("POPCORN-LABOR", Vector3(0, ETAGE_H + 1.6, zf + HAUT + 0.05), Color(1.0, 0.85, 0.3), 0.03, 0.0, true)
	_text("FORSCHUNG // ENTWICKLUNG // VERKOSTUNG", Vector3(0, ETAGE_H + 0.35, zf + HAUT + 0.05), Color(0.6, 0.95, 1.0), 0.009, 0.0, true)
	for e in range(1, ETAGEN + 1):
		_box(Vector3(0, boden_y(e) - 0.1, zf + HAUT + 0.03), Vector3(B, 0.1, 0.06), m["akzent"], false)


# ---------------------------------------------------------------- Laborteile

## Glasgefaess mit farbiger Fluessigkeit. `form`: 0 Becherglas, 1 Erlenmeyerkolben, 2 Messzylinder.
func _gefaess(pos: Vector3, form: int, farbe: int, eltern: Node3D, mass := 1.0) -> void:
	var fl: Material = m["fluessig%d" % (farbe % FLUESSIG.size())]
	match form:
		0:
			_zyl(pos + Vector3(0, 0.07 * mass, 0), 0.05 * mass, 0.14 * mass, m["glas"], eltern, -1.0, 10)
			_zyl(pos + Vector3(0, 0.045 * mass, 0), 0.044 * mass, 0.08 * mass, fl, eltern, -1.0, 10)
		1:
			_zyl(pos + Vector3(0, 0.07 * mass, 0), 0.07 * mass, 0.14 * mass, m["glas"], eltern, 0.02 * mass, 10)
			_zyl(pos + Vector3(0, 0.17 * mass, 0), 0.02 * mass, 0.07 * mass, m["glas"], eltern, -1.0, 8)
			_zyl(pos + Vector3(0, 0.035 * mass, 0), 0.064 * mass, 0.06 * mass, fl, eltern, 0.045 * mass, 10)
		_:
			_zyl(pos + Vector3(0, 0.15 * mass, 0), 0.025 * mass, 0.3 * mass, m["glas"], eltern, -1.0, 8)
			_zyl(pos + Vector3(0, 0.09 * mass, 0), 0.021 * mass, 0.17 * mass, fl, eltern, -1.0, 8)
			_zyl(pos + Vector3(0, 0.005 * mass, 0), 0.05 * mass, 0.01 * mass, m["glas"], eltern, -1.0, 8)


## Laborzeile: weisser Korpus, dunkle Platte, Regalaufsatz mit Flaschen, Glasgeraete, Spuele am Ende.
func _laborzeile(pos: Vector3, laenge: float, dreh := 0.0) -> void:
	var n := _theke(pos, Vector3(laenge, 0.92, 1.5), dreh, m["labor"], m["platte"])
	# Mittelaufsatz mit zwei Boeden
	for h: float in [1.3, 1.65]:
		_box(Vector3(0, h, 0), Vector3(laenge - 0.4, 0.03, 0.34), m["labor"], false, n)
	for sx: float in [-1.0, 0.0, 1.0]:
		_box(Vector3(sx * (laenge * 0.5 - 0.22), 1.3, 0), Vector3(0.04, 0.76, 0.3), m["chrom"], false, n)
	var x := -laenge * 0.5 + 0.5
	var i := 0
	while x < laenge * 0.5 - 0.4:
		_gefaess(Vector3(x, 1.315, _rng.randf_range(-0.08, 0.08)), 0 if i % 2 == 0 else 2, _rng.randi(), n, 1.2)
		_zyl(Vector3(x + 0.2, 1.75, 0.0), 0.045, 0.17, m["fluessig%d" % (_rng.randi() % FLUESSIG.size())], n, 0.03, 8)
		for s: float in [-1.0, 1.0]:
			if _rng.randf() < 0.75:
				_gefaess(Vector3(x + _rng.randf_range(-0.1, 0.1), 0.92, s * _rng.randf_range(0.4, 0.6)), _rng.randi() % 3, _rng.randi(), n, 1.4)
		x += 0.62
		i += 1
	# Mikroskop und Bunsenbrenner
	for s: float in [-1.0, 1.0]:
		var mx := s * laenge * 0.22
		_box(Vector3(mx, 0.95, s * 0.5), Vector3(0.16, 0.04, 0.2), m["dunkel"], false, n)
		_box(Vector3(mx, 1.08, s * 0.57), Vector3(0.05, 0.24, 0.05), m["dunkel"], false, n)
		_zyl(Vector3(mx, 1.18, s * 0.5), 0.025, 0.2, m["chrom"], n, -1.0, 8)
		_zyl(Vector3(-mx, 0.98, s * 0.45), 0.02, 0.12, m["chrom"], n, -1.0, 8)
		_zyl(Vector3(-mx, 1.07, s * 0.45), 0.012, 0.06, m["glut"], n, 0.002, 6)
	# Spuele am Kopfende
	_box(Vector3(laenge * 0.5 - 0.5, 0.925, 0), Vector3(0.6, 0.02, 0.5), m["stahl"], false, n)
	_zyl(Vector3(laenge * 0.5 - 0.5, 1.08, -0.3), 0.02, 0.3, m["chrom"], n, -1.0, 8)
	# Hocker
	for s: float in [-1.0, 1.0]:
		for k in int(laenge / 2.2):
			var hx := -laenge * 0.5 + 1.2 + k * 2.2
			_zyl(Vector3(hx, 0.62, s * 1.25), 0.2, 0.06, m["dunkel"], n, -1.0, 12)
			_zyl(Vector3(hx, 0.3, s * 1.25), 0.03, 0.6, m["chrom"], n, -1.0, 6)


## Abzug (Digestorium) an der Wand: Schrank mit Glasschieber, innen beleuchtet.
func _abzug(pos: Vector3, dreh: float) -> void:
	var n := _gruppe(pos, dreh)
	_box(Vector3(0, 0.45, 0), Vector3(1.8, 0.9, 0.9), m["labor"], false, n)
	_box(Vector3(0, 0.92, 0), Vector3(1.8, 0.04, 0.9), m["platte"], false, n)
	for sx: float in [-1.0, 1.0]:
		_box(Vector3(sx * 0.87, 1.7, 0), Vector3(0.06, 1.52, 0.9), m["labor"], false, n)
	_box(Vector3(0, 1.7, -0.42), Vector3(1.8, 1.52, 0.06), m["labor"], false, n)
	_box(Vector3(0, 2.6, 0), Vector3(1.8, 0.3, 0.9), m["labor"], false, n)
	var glas := _box(Vector3(0, 1.95, 0.42), Vector3(1.68, 1.0, 0.03), m["glas"], false, n)
	glas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_box(Vector3(0, 2.42, 0.1), Vector3(1.2, 0.03, 0.2), m["lampe"], false, n)
	_zyl(Vector3(0, 3.3, -0.1), 0.2, 1.1, m["stahl"], n, -1.0, 12)
	_gefaess(Vector3(-0.4, 0.94, 0), 1, 3, n, 2.0)
	_gefaess(Vector3(0.2, 0.94, -0.1), 0, 1, n, 2.0)
	_gefaess(Vector3(0.5, 0.94, 0.1), 2, 0, n, 1.6)
	var k := Node3D.new()
	k.position = Vector3(0, 1.4, 0)
	n.add_child(k)
	_kol(k, Vector3(1.8, 2.8, 0.9))


## Chemikalienregal an der Wand mit Flaschenreihen.
func _flaschenregal(pos: Vector3, laenge: float, dreh: float) -> void:
	var n := _gruppe(pos, dreh)
	_box(Vector3(0, 1.1, -0.17), Vector3(laenge, 2.2, 0.03), m["labor"], false, n)
	for i in 5:
		var y := 0.3 + i * 0.45
		_box(Vector3(0, y, 0), Vector3(laenge, 0.03, 0.34), m["labor"], false, n)
		var x := -laenge * 0.5 + 0.15
		while x < laenge * 0.5 - 0.1:
			var h := _rng.randf_range(0.16, 0.3)
			_zyl(Vector3(x, y + 0.015 + h * 0.5, 0.02), 0.055, h, m["fluessig%d" % (_rng.randi() % FLUESSIG.size())], n, -1.0, 8)
			_zyl(Vector3(x, y + 0.03 + h, 0.02), 0.025, 0.04, m["dunkel"], n, -1.0, 6)
			x += _rng.randf_range(0.16, 0.26)
	var k := Node3D.new()
	k.position = Vector3(0, 1.1, 0)
	n.add_child(k)
	_kol(k, Vector3(laenge, 2.2, 0.4))


## Serverschrank mit Leuchtdioden.
func _server(pos: Vector3, dreh: float) -> void:
	var n := _gruppe(pos, dreh)
	_box(Vector3(0, 1.05, 0), Vector3(0.7, 2.1, 0.9), m["dunkel"], false, n)
	for i in 9:
		_box(Vector3(0, 0.25 + i * 0.2, 0.455), Vector3(0.6, 0.14, 0.01), m["platte"], false, n)
		_box(Vector3(-0.22 + (i % 3) * 0.06, 0.25 + i * 0.2, 0.462), Vector3(0.03, 0.03, 0.005), m["led_g"] if i % 4 != 0 else m["led_b"], false, n)
	var k := Node3D.new()
	k.position = Vector3(0, 1.05, 0)
	n.add_child(k)
	_kol(k, Vector3(0.7, 2.1, 0.9))


func _feuerloescher(pos: Vector3) -> void:
	_zyl(pos + Vector3(0, 0.3, 0), 0.09, 0.5, m["rot"], null, -1.0, 10)
	_zyl(pos + Vector3(0, 0.6, 0), 0.03, 0.1, m["dunkel"], null, -1.0, 6)


# ---------------------------------------------------------------- Etagen

## EG: Empfang, Wegweiser, Sicherheitsschleuse, Mais-Silos und Sackware.
func _empfang() -> void:
	var ix := innen_x()
	var iz := innen_z()
	_licht_raster(0, 2, 2, 2.4, 16.0)
	var th := _theke(Vector3(0, 0, 4.0), Vector3(6.0, 1.1, 1.2), 0.0, m["holz"], m["platte"])
	_box(Vector3(0, 0.55, 0.62), Vector3(5.6, 0.08, 0.02), m["akzent"], false, th)
	_box(Vector3(-1.2, 1.32, -0.2), Vector3(0.6, 0.38, 0.03), m["dunkel"], false, th)
	_box(Vector3(-1.2, 1.32, -0.22), Vector3(0.56, 0.34, 0.006), _bild_mat("buero_bild_tabelle", 0.9), false, th)
	_stuhl(Vector3(-1.2, 0, 2.6), 180.0)
	_schild("POPCORN-LABOR\nEMPFANG", Vector3(0, 3.4, -1.0), 0.0, 0.012, Color(1.0, 0.85, 0.3))
	_box(Vector3(0, 2.2, -1.1), Vector3(8.0, 4.4, 0.15), m["holz"])
	_schild("EG   EMPFANG // ANLIEFERUNG\n1    CHEMIELABOR\n2    POPCORN-REAKTOR\n3    ANALYSE // BUERO", Vector3(-7.5, 2.0, -iz + 9.3), 0.0, 0.005)
	_box(Vector3(-7.5, 2.2, -iz + 9.2), Vector3(4.6, 4.4, 0.15), m["wand"])
	# Wartebereich links vorn
	_bank(Vector3(-11.0, 0, 11.0), 3.0, 90.0, true)
	_bank(Vector3(-8.0, 0, 14.5), 3.0, 180.0, true)
	_tisch(Vector3(-8.5, 0, 11.5), Vector3(1.2, 0.45, 0.7), m["eiche"])
	_pflanze(Vector3(-14.5, 0, 14.5))
	_pflanze(Vector3(4.5, 0, 14.8))
	_bild(Vector3(-ix + 0.03, 2.4, 9.0), Vector2(2.4, 1.5), 90.0, "markt_poster")
	# Sicherheitsschleuse zum Treppenhaus
	for sx: float in [-1.0, 1.0]:
		_box(Vector3(-10.5 + sx * 1.0, 1.1, -3.0), Vector3(0.25, 2.2, 0.6), m["dunkel"])
		_box(Vector3(-10.5 + sx * 0.86, 1.3, -3.0), Vector3(0.02, 1.4, 0.3), m["led_g"], false)
	_box(Vector3(-10.5, 2.3, -3.0), Vector3(2.25, 0.2, 0.6), m["dunkel"], false)
	# Mais-Silos rechts hinten mit Fuellstand
	for i in 3:
		var p := Vector3(ix - 3.0, 0, -iz + 3.0 + i * 4.6)
		_zyl(p + Vector3(0, 2.3, 0), 1.7, 3.4, m["stahl"], null, -1.0, 20, true)
		_zyl(p + Vector3(0, 0.35, 0), 0.4, 0.7, m["stahl"], null, 1.7, 20)
		_zyl(p + Vector3(0, 4.25, 0), 1.7, 0.5, m["stahl"], null, 0.5, 20)
		_box(p + Vector3(-1.72, 2.3, 0), Vector3(0.04, 2.6, 0.3), m["platte"], false)
		_box(p + Vector3(-1.75, 1.3 + i * 0.4, 0), Vector3(0.03, 0.6 + i * 0.8, 0.22), m["mais"], false)
		_schild("MAIS %d" % (i + 1), p + Vector3(-1.78, 3.9, 0), -90.0, 0.006, Color(1.0, 0.85, 0.3))
	# Paletten mit Mais-Saecken
	for p: Vector3 in [Vector3(7.0, 0, -8.0), Vector3(7.0, 0, -4.5), Vector3(10.0, 0, 9.0)]:
		_box(p + Vector3(0, 0.08, 0), Vector3(1.3, 0.16, 1.1), m["eiche"], false)
		for i in 5:
			var s := _box(p + Vector3((i % 2) * 0.1 - 0.05, 0.3 + i * 0.26, 0), Vector3(1.05, 0.26, 0.75), m["sack"], false)
			s.rotation.y = 0.12 * (i % 3 - 1)
		var k := Node3D.new()
		k.position = p + Vector3(0, 0.8, 0)
		add_child(k)
		_kol(k, Vector3(1.3, 1.6, 1.1))
	# Garderobe mit Laborkitteln
	_box(Vector3(11.0, 1.9, iz - 0.3), Vector3(5.0, 0.06, 0.06), m["chrom"], false)
	for i in 7:
		_box(Vector3(9.0 + i * 0.65, 1.3, iz - 0.3), Vector3(0.5, 1.1, 0.12), m["weiss"], false)
	_feuerloescher(Vector3(3.0, 0, iz - 0.2))


## 1. OG: Chemielabor mit Laborzeilen, Abzuegen, Chemikalienregalen und Notdusche.
func _chemielabor() -> void:
	var y := boden_y(1)
	var ix := innen_x()
	var iz := innen_z()
	_licht_raster(1, 2, 2, 2.6, 16.0)
	for i in 4:
		_laborzeile(Vector3(-11.0 + i * 6.2, y, 3.5), 10.0, 90.0)
	_laborzeile(Vector3(2.5, y, -8.5), 13.0, 0.0)
	# Probenwagen und Gasflaschen
	for i in 3:
		_theke(Vector3(-8.0 + i * 6.2, y, 11.5), Vector3(1.0, 0.85, 0.6), 0.0, m["stahl"], m["stahl"])
	for i in 4:
		_zyl(Vector3(ix - 0.5, y + 0.8, 12.0 + i * 0.6), 0.14, 1.6, m["gelb"] if i % 2 == 0 else m["gruen"], null, -1.0, 10, true)
	for i in 4:
		_abzug(Vector3(ix - 0.5, y, -11.0 + i * 5.5), -90.0)
	_flaschenregal(Vector3(1.0, y, -iz + 0.25), 9.0, 0.0)
	_flaschenregal(Vector3(11.0, y, -iz + 0.25), 6.0, 0.0)
	# Notdusche und Augendusche neben dem Treppenhaus
	_zyl(Vector3(-11.0, y + 1.2, -iz + 0.3), 0.03, 2.4, m["gelb"], null, -1.0, 8)
	_zyl(Vector3(-11.0, y + 2.4, -iz + 0.6), 0.18, 0.06, m["gelb"], null, -1.0, 12)
	_box(Vector3(-11.0, y + 2.42, -iz + 0.45), Vector3(0.04, 0.04, 0.3), m["gelb"], false)
	_schild("NOTDUSCHE", Vector3(-11.0, y + 3.0, -iz + 0.05), 0.0, 0.005, Color(0.3, 1.0, 0.5))
	_zyl(Vector3(-9.5, y + 0.5, -iz + 0.3), 0.04, 1.0, m["gelb"], null, -1.0, 8)
	_zyl(Vector3(-9.5, y + 1.02, -iz + 0.3), 0.16, 0.08, m["gruen"], null, -1.0, 12)
	# Kuehlschraenke und Zentrifuge an der Frontseite
	for i in 2:
		_box(Vector3(-11.0 + i * 1.1, y + 1.0, iz - 0.4), Vector3(1.0, 2.0, 0.75), m["stahl"])
	_theke(Vector3(-3.0, y, iz - 0.45), Vector3(6.0, 0.92, 0.8), 0.0, m["labor"], m["platte"])
	for i in 3:
		_zyl(Vector3(-5.0 + i * 1.6, y + 1.1, iz - 0.45), 0.3, 0.36, m["labor"], null, -1.0, 16)
		_box(Vector3(-5.0 + i * 1.6, y + 1.08, iz - 0.78), Vector3(0.2, 0.08, 0.02), m["led_b"], false)
	_bild(Vector3(-ix + 0.03, y + 2.3, 6.0), Vector2(2.2, 1.4), 90.0, "buero_whiteboard", 0.3)
	_schild("1 // CHEMIELABOR\nSCHUTZBRILLE TRAGEN", Vector3(-ix + treppe_b() + 2.5, y + 3.2, -iz + 0.05), 0.0, 0.006, Color(1.0, 0.85, 0.3))
	_feuerloescher(Vector3(-ix + treppe_b() + 0.8, y, treppe_z() + 1.0))


## 2. OG: Popcorn-Reaktor im Glaskessel, Leitstand, Oeltanks, Foerderband mit Eimern.
func _reaktor() -> void:
	var y := boden_y(2)
	var ix := innen_x()
	var iz := innen_z()
	_licht_raster(2, 2, 2, 2.0, 16.0)
	var mitte := Vector3(3.0, y, 1.0)
	# Sockel, Heizplatte, Glaskessel, Deckel mit Abluftrohr
	_zyl(mitte + Vector3(0, 0.3, 0), REAKTOR_R + 0.5, 0.6, m["stahl"], null, -1.0, 28, true)
	_zyl(mitte + Vector3(0, 0.63, 0), REAKTOR_R - 0.15, 0.06, m["glut"], null, -1.0, 28)
	var kessel := _zyl(mitte + Vector3(0, 0.6 + REAKTOR_H * 0.5, 0), REAKTOR_R, REAKTOR_H, m["glas"], null, -1.0, 28, true)
	kessel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_zyl(mitte + Vector3(0, 0.6 + REAKTOR_H + 0.25, 0), REAKTOR_R + 0.1, 0.5, m["stahl"], null, 0.8, 28)
	_zyl(mitte + Vector3(0, 0.6 + REAKTOR_H + 0.6, 0), 0.5, ETAGE_H - REAKTOR_H - 1.0, m["stahl"], null, -1.0, 14)
	for i in 3:
		_zyl(mitte + Vector3(0, 1.4 + i * 1.0, 0), REAKTOR_R + 0.05, 0.08, m["chrom"], null, -1.0, 28)
	_rot_licht = _licht(mitte + Vector3(0, 1.4, 0), Color(1.0, 0.5, 0.15), 1.8, 9.0)
	# liegendes und springendes Popcorn
	for i in 40:
		var w := _rng.randf() * TAU
		var r := sqrt(_rng.randf()) * (REAKTOR_R - 0.4)
		var korn := _kugel(mitte + Vector3(cos(w) * r, 0.75 + _rng.randf() * 0.5, sin(w) * r), _rng.randf_range(0.14, 0.24), m["popcorn"])
		korn.scale = Vector3(1.0, _rng.randf_range(0.7, 1.0), _rng.randf_range(0.8, 1.1))
		if i < POPCORN_IM_KESSEL:
			_koerner.append([korn, _rng.randf(), _rng.randf_range(0.6, 1.3), korn.position])
	# Warnmarkierung am Boden
	for i in 16:
		var w := TAU * i / 16.0
		var st := _box(mitte + Vector3(cos(w) * (REAKTOR_R + 1.3), 0.012, sin(w) * (REAKTOR_R + 1.3)), Vector3(0.9, 0.02, 0.18), m["gelb"] if i % 2 == 0 else m["platte"], false)
		st.rotation.y = -w + PI / 2.0
	# Leitstand: Pultreihe mit Bildschirmen vor dem Kessel
	for i in 3:
		var pult := _theke(Vector3(-1.5 + i * 2.2, y, 9.5), Vector3(2.0, 0.95, 0.9), 0.0, m["dunkel"], m["platte"])
		var schirm := _box(Vector3(0, 1.35, -0.25), Vector3(1.5, 0.7, 0.04), m["dunkel"], false, pult)
		schirm.rotation.x = -0.25
		var bild := _box(Vector3(0, 1.35, -0.225), Vector3(1.4, 0.62, 0.006), _bild_mat(["buero_bild_chart", "buero_bild_code", "buero_bild_tabelle"][i], 1.0), false, pult)
		bild.rotation.x = -0.25
		for k in 6:
			_box(Vector3(-0.6 + k * 0.24, 0.985, 0.15), Vector3(0.1, 0.03, 0.1), m["led_g"] if k % 3 != 0 else m["glut"], false, pult)
		_stuhl(Vector3(-1.5 + i * 2.2, y, 10.6), 0.0)
	_schild("2 // POPCORN-REAKTOR\nKESSELTEMPERATUR 180 GRAD", Vector3(4.0, y + 3.6, iz - 0.05), 180.0, 0.006, Color(1.0, 0.6, 0.2))
	# Oeltanks und Butterkessel an der rechten Wand, Rohre zum Kessel
	for i in 3:
		var p := Vector3(ix - 1.6, y, -9.0 + i * 3.6)
		_zyl(p + Vector3(0, 1.4, 0), 1.1, 2.8, m["stahl"], null, -1.0, 18, true)
		_zyl(p + Vector3(0, 2.95, 0), 1.1, 0.3, m["stahl"], null, 0.3, 18)
		_box(p + Vector3(-1.12, 1.6, 0), Vector3(0.03, 0.5, 0.7), m["gelb"], false)
		_schild(["OEL", "BUTTER", "KARAMELL"][i], p + Vector3(-1.15, 1.6, 0), -90.0, 0.005, Color(0.1, 0.1, 0.1), false)
		_zyl(p + Vector3(0, 3.6, 0), 0.09, 1.0, m["chrom"], null, -1.0, 8)
	var rohr := _zyl(Vector3((ix - 1.6 + mitte.x) * 0.5, y + 4.1, -5.4), 0.09, ix - 1.6 - mitte.x, m["chrom"], null, -1.0, 8)
	rohr.rotation.z = PI / 2.0
	# Foerderband mit Popcorn-Eimern an der Rueckwand
	_theke(Vector3(4.0, y, -iz + 1.0), Vector3(14.0, 0.85, 1.0), 0.0, m["stahl"], m["platte"])
	for i in 8:
		var bx := -2.0 + i * 1.7
		_zyl(Vector3(bx, y + 1.07, -iz + 1.0), 0.16, 0.4, m["rot"], null, 0.24, 12)
		_kugel(Vector3(bx, y + 1.3, -iz + 1.0), 0.22, m["popcorn"], null, 0.6)
	# Verpackung links: Packtische mit Eimerstapeln, Kartonpaletten, Sackkarre
	for i in 2:
		var pt := _theke(Vector3(-10.5, y, 2.0 + i * 5.0), Vector3(1.4, 0.9, 3.6), 0.0, m["stahl"], m["stahl"])
		for k in 4:
			for h in 3:
				_zyl(Vector3(-0.25 + (k % 2) * 0.5, 1.02 + h * 0.12, -1.2 + k * 0.7), 0.16, 0.34, m["rot"], pt, 0.22, 10)
		_stuhl(Vector3(-9.2, y, 2.0 + i * 5.0), 90.0)
	for p: Vector3 in [Vector3(-13.5, y, 12.5), Vector3(-11.0, y, 13.5), Vector3(-6.5, y, 13.0)]:
		_box(p + Vector3(0, 0.08, 0), Vector3(1.3, 0.16, 1.1), m["eiche"], false)
		for i in 3:
			_box(p + Vector3(0, 0.42 + i * 0.52, 0), Vector3(1.15 - i * 0.1, 0.5, 0.95), m["karton"], false)
		var k := Node3D.new()
		k.position = p + Vector3(0, 0.85, 0)
		add_child(k)
		_kol(k, Vector3(1.3, 1.7, 1.1))
	# Mais-Trichter ueber dem Foerderband
	_zyl(Vector3(-4.5, y + 3.0, -iz + 1.2), 0.3, 1.6, m["stahl"], null, 1.3, 16)
	_zyl(Vector3(-4.5, y + 4.2, -iz + 1.2), 1.3, 0.8, m["stahl"], null, -1.0, 16)
	_feuerloescher(Vector3(-ix + treppe_b() + 0.8, y, treppe_z() + 1.0))


## 3. OG: Analyse (Arbeitsplaetze, Server), Besprechung und Verkostung.
func _analyse() -> void:
	var y := boden_y(3)
	var ix := innen_x()
	var iz := innen_z()
	_licht_raster(3, 2, 2, 2.4, 16.0)
	var bilder: Array[String] = ["buero_bild_chart", "buero_bild_code", "buero_bild_tabelle"]
	for i in 5:
		for j in 3:
			_schreibtisch(Vector3(-9.0 + i * 3.6, y, 2.5 + j * 4.2), 0.0 if j % 2 == 0 else 180.0, bilder[(i + j) % 3])
	# Glaswand zwischen Grossraum und Besprechung
	var trenn := _box(Vector3(1.0, y + 1.5, -1.5), Vector3(14.0, 3.0, 0.06), m["glas"])
	trenn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_box(Vector3(1.0, y + 3.03, -1.5), Vector3(14.0, 0.06, 0.1), m["rahmen"], false)
	# Kaffeekueche neben dem Treppenhaus
	var kueche := _theke(Vector3(-ix + treppe_b() + 2.2, y, -iz + 0.5), Vector3(3.6, 0.92, 0.7), 0.0, m["labor"], m["platte"])
	_box(Vector3(-1.0, 1.15, 0), Vector3(0.35, 0.45, 0.4), m["dunkel"], false, kueche)
	_box(Vector3(0.9, 0.925, 0), Vector3(0.6, 0.02, 0.45), m["stahl"], false, kueche)
	_box(Vector3(-ix + treppe_b() + 4.8, y + 1.0, -iz + 0.5), Vector3(0.8, 2.0, 0.7), m["stahl"])
	_bild(Vector3(-ix + treppe_b() + 2.2, y + 2.2, -iz + 0.04), Vector2(1.2, 1.6), 0.0, "kantine_poster_kaffee")
	# Serverraum hinten rechts hinter Glas
	for i in 5:
		_server(Vector3(ix - 6.5 + i * 1.1, y, -iz + 0.9), 0.0)
	var glas := _box(Vector3(ix - 4.3, y + 1.5, -iz + 3.0), Vector3(8.6, 3.0, 0.06), m["glas"])
	glas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_licht(Vector3(ix - 4.3, y + 2.5, -iz + 1.6), Color(0.3, 0.6, 1.0), 1.2, 6.0)
	# Besprechungstisch mit Whiteboard
	_tisch(Vector3(1.0, y, -8.0), Vector3(6.0, 0.74, 1.8), m["eiche"])
	for i in 5:
		_stuhl(Vector3(-1.4 + i * 1.2, y, -6.7), 0.0)
		_stuhl(Vector3(-1.4 + i * 1.2, y, -9.3), 180.0)
	_bild(Vector3(1.0, y + 2.2, -iz + 0.04), Vector2(3.6, 1.8), 0.0, "buero_whiteboard", 0.3)
	# Verkostung: Theke mit nummerierten Probenbechern
	var vk := _theke(Vector3(ix - 1.0, y, 6.0), Vector3(1.2, 1.0, 9.0), 0.0, m["holz"], m["weiss"])
	for i in 8:
		_zyl(Vector3(0, 1.1, -3.6 + i * 1.0), 0.13, 0.2, m["rot"], vk, 0.18, 10)
		_kugel(Vector3(0, 1.22, -3.6 + i * 1.0), 0.16, m["popcorn"], vk, 0.6)
	_schild("VERKOSTUNG\nPROBE 1 BIS 8", Vector3(ix - 0.05, y + 2.6, 6.0), -90.0, 0.006, Color(1.0, 0.85, 0.3))
	_buecherregal(Vector3(-ix + 0.2, y, 8.0), 6.0, 2.2, 90.0, false, 0.7)
	_pflanze(Vector3(-ix + 1.0, y, 13.5))
	_pflanze(Vector3(8.0, y, iz - 1.0))
	_bild(Vector3(2.0, y + 2.4, iz - 0.04), Vector2(2.0, 1.4), 180.0, "buero_poster")
	_schild("3 // ANALYSE", Vector3(-ix + treppe_b() + 2.5, y + 3.2, -iz + 0.05), 0.0, 0.006, Color(1.0, 0.85, 0.3))
