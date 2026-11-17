extends Node3D
## Zug der Linie M1: zwei Wagen mit Uebergang, Cyber-Look (dunkler Lack, Neonbaender, Fensterband, Schiebetueren).
## Lokale Achsen: Ursprung = Schienenoberkante in Zugmitte, Zug entlang x, Fussboden bei BODEN_Y (= Bahnsteighoehe).
## Kollision: ein AnimatableBody3D (Boden, Dach, Seitenwaende, Tueren, Stirnwaende), damit man an der Station
## einsteigen und drin herumlaufen kann. Waehrend der Fahrt fuehrt levels/metro.gd den Spieler mit.
## Methoden: tueren_setzen(seite, offen), innen(punkt), anzeige_setzen(text), static tuer_positionen().
## Exportiert: linien_farbe. Keine Signale.

const NEON := preload("res://ui/neon.gd")

@export var linien_farbe := Color(0.1, 0.95, 1.0)

const WAGEN_L := 14.0
const WAGEN_MITTE: Array[float] = [-7.5, 7.5]
const BREITE := 3.0
const UNTEN_Y := 0.3
const BODEN_Y := 1.1
const FENSTER_Y0 := 1.9
const FENSTER_Y1 := 3.2
const DACH_Y := 3.9
const TUER_VERSATZ: Array[float] = [-3.5, 3.5]     ## Tueren je Wagen, relativ zur Wagenmitte
const TUER_B := 1.6
const TUER_H := 2.25
const TUER_ZEIT := 1.1
const WAND_D := 0.08
const NASE_L := 1.6
const UEBERGANG_B := 1.4

var _m: Dictionary = {}
var _koerper: AnimatableBody3D
var _tueren: Array = []            ## je Tuer: [seite, linkes Blatt, rechtes Blatt, Kollision, Mitte x]
var _offen := {-1: 0.0, 1: 0.0}
var _soll := {-1: 0.0, 1: 0.0}
var _anzeigen: Array[Label3D] = []


func _ready() -> void:
	_materialien()
	_koerper = AnimatableBody3D.new()
	_koerper.sync_to_physics = false
	add_child(_koerper)
	for i in WAGEN_MITTE.size():
		_wagen(WAGEN_MITTE[i], i)
	_uebergang()


## x-Positionen aller Tueren (Zug lokal), fuer die Bahnsteigtueren.
static func tuer_positionen() -> Array[float]:
	var l: Array[float] = []
	for c in WAGEN_MITTE:
		for t in TUER_VERSATZ:
			l.append(c + t)
	return l


static func laenge() -> float:
	return WAGEN_MITTE[1] - WAGEN_MITTE[0] + WAGEN_L + 2.0 * NASE_L


func _std(c: Color, metall := 0.6, rauh := 0.35, leuchten := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metall
	m.roughness = rauh
	m.disable_ambient_light = true
	if leuchten > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = leuchten
	return m


func _materialien() -> void:
	_m["lack"] = _std(Color(0.06, 0.07, 0.1), 0.85, 0.25)
	_m["dunkel"] = _std(Color(0.03, 0.03, 0.04), 0.4, 0.6)
	_m["boden"] = _std(Color(0.12, 0.13, 0.16), 0.3, 0.6)
	_m["sitz"] = _std(Color(0.35, 0.08, 0.3), 0.1, 0.7)
	_m["stahl"] = _std(Color(0.6, 0.62, 0.66), 0.95, 0.2)
	_m["linie"] = _std(linien_farbe, 0.0, 0.4, 2.5)
	_m["pink"] = _std(Color(1.0, 0.15, 0.7), 0.0, 0.4, 2.5)
	_m["licht"] = _std(Color(0.85, 0.92, 1.0), 0.0, 0.4, 1.4)
	_m["front"] = _std(Color(0.7, 0.95, 1.0), 0.0, 0.3, 4.0)
	_m["heck"] = _std(Color(1.0, 0.1, 0.15), 0.0, 0.3, 3.0)
	var glas := _std(Color(0.2, 0.45, 0.6), 0.2, 0.05, 0.04)
	glas.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glas.albedo_color.a = 0.14
	glas.cull_mode = BaseMaterial3D.CULL_DISABLED
	_m["glas"] = glas


func _box(mitte: Vector3, g: Vector3, mat: Material, kol := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = g
	mi.mesh = bm
	mi.material_override = mat
	mi.position = mitte
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	if kol:
		_kol(mitte, g)
	return mi


func _kol(mitte: Vector3, g: Vector3) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = g
	cs.shape = sh
	cs.position = mitte
	_koerper.add_child(cs)
	return cs


## Wandstueck einer Seite zwischen x0 und x1: Schuerze, Bruestung, Fensterband, Oberteil, Neonbaender.
func _seitenwand(x0: float, x1: float, z: float) -> void:
	if x1 - x0 < 0.02:
		return
	var xm := (x0 + x1) * 0.5
	var l := x1 - x0
	_box(Vector3(xm, (BODEN_Y + FENSTER_Y0) * 0.5, z), Vector3(l, FENSTER_Y0 - BODEN_Y, WAND_D), _m["lack"])
	_box(Vector3(xm, (FENSTER_Y0 + FENSTER_Y1) * 0.5, z), Vector3(l, FENSTER_Y1 - FENSTER_Y0, WAND_D * 0.5), _m["glas"])
	_box(Vector3(xm, (FENSTER_Y1 + DACH_Y) * 0.5, z), Vector3(l, DACH_Y - FENSTER_Y1, WAND_D), _m["lack"])
	var aussen := signf(z) * 0.03
	_box(Vector3(xm, FENSTER_Y0 - 0.06, z + aussen), Vector3(l, 0.07, 0.02), _m["linie"])
	_box(Vector3(xm, FENSTER_Y1 + 0.08, z + aussen), Vector3(l, 0.05, 0.02), _m["pink"])
	_kol(Vector3(xm, (BODEN_Y + DACH_Y) * 0.5, z), Vector3(l, DACH_Y - BODEN_Y, 0.15))


func _wagen(cx: float, nr: int) -> void:
	var halb := WAGEN_L * 0.5
	var hz := BREITE * 0.5
	# Fahrgestell, Boden, Dach (mit Lichtleiste), Dachaufbau
	_box(Vector3(cx, (UNTEN_Y + BODEN_Y) * 0.5, 0), Vector3(WAGEN_L, BODEN_Y - UNTEN_Y, BREITE - 0.1), _m["lack"])
	_box(Vector3(cx, UNTEN_Y + 0.1, 0), Vector3(WAGEN_L - 1.0, 0.06, BREITE - 0.2), _m["linie"])
	_box(Vector3(cx, BODEN_Y - 0.02, 0), Vector3(WAGEN_L, 0.04, BREITE - 0.1), _m["boden"])
	_kol(Vector3(cx, BODEN_Y - 0.1, 0), Vector3(WAGEN_L, 0.2, BREITE))
	_box(Vector3(cx, DACH_Y + 0.1, 0), Vector3(WAGEN_L, 0.2, BREITE), _m["lack"], true)
	_box(Vector3(cx, DACH_Y - 0.03, 0), Vector3(WAGEN_L - 1.0, 0.04, 0.3), _m["licht"])
	_box(Vector3(cx, DACH_Y + 0.35, 0), Vector3(WAGEN_L * 0.6, 0.3, 1.4), _m["dunkel"])
	var licht := OmniLight3D.new()
	licht.position = Vector3(cx, DACH_Y - 0.6, 0)
	licht.light_color = Color(0.8, 0.9, 1.0)
	licht.light_energy = 0.9
	licht.omni_range = 9.0
	add_child(licht)
	# Seitenwaende mit Tuerluecken, Tueren (beide Seiten)
	for seite: int in [-1, 1]:
		var z := seite * hz
		var x0 := cx - halb
		for t in TUER_VERSATZ:
			var tx := cx + t
			_seitenwand(x0, tx - TUER_B * 0.5, z)
			x0 = tx + TUER_B * 0.5
			var ym := BODEN_Y + TUER_H * 0.5
			var l := _box(Vector3(tx - TUER_B * 0.25, ym, z), Vector3(TUER_B * 0.5, TUER_H, WAND_D), _m["glas"])
			var r := _box(Vector3(tx + TUER_B * 0.25, ym, z), Vector3(TUER_B * 0.5, TUER_H, WAND_D), _m["glas"])
			_box(Vector3(tx, BODEN_Y + TUER_H + 0.05, z + seite * 0.03), Vector3(TUER_B + 0.1, 0.08, 0.02), _m["linie"])
			_box(Vector3(tx, (BODEN_Y + TUER_H + DACH_Y) * 0.5, z), Vector3(TUER_B, DACH_Y - BODEN_Y - TUER_H, WAND_D), _m["lack"])
			var kol := _kol(Vector3(tx, ym, z), Vector3(TUER_B, TUER_H, 0.15))
			_tueren.append([seite, l, r, kol, tx])
		_seitenwand(x0, cx + halb, z)
	# Sitzreihen zwischen den Tueren, Haltestangen an den Tueren
	for seite: float in [-1.0, 1.0]:
		for sx: float in [-5.6, 0.0, 5.6]:
			var lang := 2.4 if sx == 0.0 else 1.6
			_box(Vector3(cx + sx, BODEN_Y + 0.45, seite * (hz - 0.35)), Vector3(lang, 0.12, 0.5), _m["sitz"], true)
			_box(Vector3(cx + sx, BODEN_Y + 0.85, seite * (hz - 0.12)), Vector3(lang, 0.7, 0.08), _m["sitz"])
	for t in TUER_VERSATZ:
		var p := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.03
		cm.bottom_radius = 0.03
		cm.height = DACH_Y - BODEN_Y
		cm.radial_segments = 8
		p.mesh = cm
		p.material_override = _m["stahl"]
		p.position = Vector3(cx + t, (BODEN_Y + DACH_Y) * 0.5, 0)
		add_child(p)
	# Stirnseiten: aussen Nase mit Lichtern, innen Wand mit Durchgang zum anderen Wagen
	var aussen := signf(cx)
	var ex := cx + aussen * halb
	_box(Vector3(ex, (BODEN_Y + DACH_Y) * 0.5, 0), Vector3(WAND_D, DACH_Y - BODEN_Y, BREITE), _m["lack"], true)
	var nase := _box(Vector3(ex + aussen * NASE_L * 0.5, (UNTEN_Y + DACH_Y) * 0.5 - 0.2, 0), Vector3(NASE_L, DACH_Y - UNTEN_Y - 0.4, BREITE - 0.2), _m["lack"])
	nase.rotation.z = -aussen * 0.18
	_box(Vector3(ex + aussen * (NASE_L - 0.15), FENSTER_Y0, 0), Vector3(0.1, 0.5, BREITE - 0.6), _m["glas"])
	for lz: float in [-0.95, 0.95]:
		_box(Vector3(ex + aussen * NASE_L, UNTEN_Y + 0.55, lz), Vector3(0.06, 0.18, 0.6), _m["front"] if nr == 0 else _m["heck"])
	_box(Vector3(ex + aussen * NASE_L, UNTEN_Y + 0.3, 0), Vector3(0.05, 0.06, BREITE - 0.3), _m["linie"])
	_text("M1", Vector3(ex + aussen * (NASE_L + 0.03), FENSTER_Y1 - 0.1, 0), linien_farbe, 0.008, 90.0 * aussen)
	var ix := cx - aussen * halb
	var seit := (BREITE - UEBERGANG_B) * 0.5
	for s: float in [-1.0, 1.0]:
		_box(Vector3(ix, (BODEN_Y + DACH_Y) * 0.5, s * (UEBERGANG_B * 0.5 + seit * 0.5)), Vector3(WAND_D, DACH_Y - BODEN_Y, seit), _m["lack"], true)
	_box(Vector3(ix, (BODEN_Y + TUER_H + DACH_Y) * 0.5, 0), Vector3(WAND_D, DACH_Y - BODEN_Y - TUER_H, UEBERGANG_B), _m["lack"], true)
	# Anzeige ueber dem Durchgang (schaut in den Wagen)
	var anz := _text("", Vector3(ix + aussen * 0.06, BODEN_Y + TUER_H + 0.3, 0), Color(1.0, 0.8, 0.25), 0.004, -90.0 * aussen)
	_anzeigen.append(anz)


func _uebergang() -> void:
	var x0 := WAGEN_MITTE[0] + WAGEN_L * 0.5
	var x1 := WAGEN_MITTE[1] - WAGEN_L * 0.5
	var l := x1 - x0
	var xm := (x0 + x1) * 0.5
	_box(Vector3(xm, BODEN_Y - 0.1, 0), Vector3(l + 0.2, 0.2, UEBERGANG_B + 0.2), _m["dunkel"], true)
	for s: float in [-1.0, 1.0]:
		_box(Vector3(xm, (BODEN_Y + BODEN_Y + TUER_H) * 0.5, s * (UEBERGANG_B * 0.5 + 0.05)), Vector3(l + 0.2, TUER_H, 0.1), _m["dunkel"], true)
	_box(Vector3(xm, BODEN_Y + TUER_H + 0.05, 0), Vector3(l + 0.2, 0.1, UEBERGANG_B + 0.2), _m["dunkel"], true)


func _text(txt: String, pos: Vector3, farbe: Color, pixel: float, drehung: float) -> Label3D:
	var l := Label3D.new()
	l.text = txt
	l.font = NEON.font()
	l.font_size = 48
	l.pixel_size = pixel
	l.modulate = farbe
	l.outline_size = 6
	l.outline_modulate = Color(0.0, 0.02, 0.06)
	l.shaded = false
	l.position = pos
	l.rotation_degrees.y = drehung
	add_child(l)
	return l


# ---------------------------------------------------------------- Bedienung

## seite: -1 = lokal -z, +1 = lokal +z.
func tueren_setzen(seite: int, offen: bool) -> void:
	_soll[seite] = 1.0 if offen else 0.0


func tueren_zu() -> bool:
	return _offen[-1] == 0.0 and _offen[1] == 0.0


func tueren_offen(seite: int) -> bool:
	return _offen[seite] >= 1.0


func _process(delta: float) -> void:
	for seite: int in [-1, 1]:
		if _offen[seite] == _soll[seite]:
			continue
		_offen[seite] = move_toward(_offen[seite], _soll[seite], delta / TUER_ZEIT)
		for t in _tueren:
			if t[0] != seite:
				continue
			var tx: float = t[4]
			var weg: float = TUER_B * 0.5 * _offen[seite]
			(t[1] as Node3D).position.x = tx - TUER_B * 0.25 - weg
			(t[2] as Node3D).position.x = tx + TUER_B * 0.25 + weg
			(t[3] as CollisionShape3D).disabled = _offen[seite] > 0.5


## Liegt ein Weltpunkt (Fuesse des Spielers) im Fahrgastraum?
func innen(p: Vector3) -> bool:
	var l := to_local(p)
	var halb := (WAGEN_MITTE[1] - WAGEN_MITTE[0] + WAGEN_L) * 0.5
	return absf(l.x) < halb and absf(l.z) < BREITE * 0.5 - 0.05 and l.y > BODEN_Y - 0.4 and l.y < DACH_Y


func anzeige_setzen(text: String) -> void:
	for a in _anzeigen:
		a.text = text
