extends "res://levels/haus.gd"
## Museum fuer Stadtgeschichte und Zauberei: begehbar, zwei Etagen (Basis: levels/haus.gd). Front zeigt lokal nach +z.
## EG: Kasse, Stadtmodell unter Glas, Vitrinen mit Fundstuecken (erste Brezel, Gurke Nr. 4, Mana-Kern,
## Zauberstab, Popcorn), Schwebe-Auto Mk I hinter Absperrseilen. OG: Gemaeldegalerie mit Stellwaenden und Skulpturen.
## Rueck- und Seitenwaende sind geschlossen (Haengeflaeche). Der Mana-Kern dreht sich, sonst keine Bewegung.
## Wird von stadt.gd (_museum) erzeugt. Keine Signale, keine Exporte.

const B := 36.0
const T := 20.0
const ETAGEN := 2
const ETAGE_H := 5.0
const TUER_X := 4.0
const MODELL := Vector3(5.6, 0.9, 3.8)     ## Tisch des Stadtmodells
const MODELL_HAEUSER := 46
const GEMAELDE: Array[String] = [
	"kantine_essen_suppe", "kantine_essen_gemuese", "kantine_essen_dessert", "kantine_essen_nudeln",
	"kantine_essen_salat", "kantine_essen_eintopf", "kantine_essen_reis", "kantine_essen_kartoffeln",
	"markt_poster", "buero_poster", "kantine_poster_kaffee",
]
const FUNDE: Array[String] = ["DIE ERSTE BREZEL\nBREZEL-STAND, JAHR 1", "GURKE NR. 4\nLEIHGABE NEON-MARKT", "MANA-KERN\nFUNDORT RUNEN-PLAZA", "ZAUBERSTAB DER GRÜNDER\nEICHE, KRISTALLSPITZE", "POPCORN, ERSTE CHARGE\nPOPCORN-LABOR"]

var _kern: Node3D
var _bild_nr := 0


func _bauen() -> void:
	name = "Museum"
	fenster_hinten = false
	fenster_seiten = false
	_basis_materialien()
	m["boden"] = _tex("marble_01", 3.0, Color(0.95, 0.95, 1.0))
	m["boden_oben"] = _tex("markt_oak_wood_planks", 1.6)
	m["fassade"] = _tex("brushed_concrete_04", 4.0, Color(1.5, 1.46, 1.38), 0.0, 1.0, false)
	m["marmor"] = _tex("marble_01", 2.0)
	m["gold"] = _std(Color(0.85, 0.65, 0.2), 0.0, 0.9, 0.3)
	m["teig"] = _std(Color(0.6, 0.33, 0.12), 0.0, 0.0, 0.6)
	m["gurke"] = _std(Color(0.2, 0.5, 0.15), 0.0, 0.0, 0.5)
	m["kern"] = _std(Color(0.2, 0.9, 1.0), 2.5)
	m["popcorn"] = _std(Color(1.0, 0.95, 0.75), 0.0, 0.0, 0.9)
	m["seil"] = _std(Color(0.6, 0.08, 0.1), 0.0, 0.0, 0.8)
	m["auto"] = _std(Color(0.75, 0.2, 0.15), 0.0, 0.6, 0.3)
	m["rasen"] = _std(Color(0.25, 0.45, 0.2), 0.0, 0.0, 0.9)
	m["wasser"] = _std(Color(0.2, 0.5, 0.8), 0.3, 0.0, 0.2)
	m["stellwand"] = _std(Color(0.35, 0.12, 0.14), 0.0, 0.0, 0.8)
	_rohbau(B, T, ETAGEN, ETAGE_H, TUER_X, 4.4)
	_aussen()
	_stadtgeschichte()
	_galerie()
	_buecher_bauen()


func _leben(delta: float) -> void:
	if _kern != null:
		_kern.rotation.y += delta * 0.8
		_kern.position.y = 1.5 + sin(zeit * 1.5) * 0.06


func _aussen() -> void:
	_portikus(TUER_X, 14.0, ETAGE_H * 2.0 - 0.6, 2.4, 6, m["saeule"])
	_fassaden_schrift("MUSEUM", "STADTGESCHICHTE UND ZAUBEREI", ETAGE_H + 2.3, Color(1.0, 0.9, 0.6), 0.034, -9.0)
	_leuchtbaender()
	# Ausstellungsbanner an der Front
	for i in 2:
		var farbe: Color = [Color(0.7, 0.15, 0.2), Color(0.15, 0.35, 0.7)][i]
		_box(Vector3(13.2 + i * 2.4, ETAGE_H + 0.4, T * 0.5 + HAUT + 0.06), Vector3(1.6, 5.6, 0.04), _std(farbe, 0.0, 0.0, 0.8, false), false)


## Pfosten mit Absperrseil um ein Rechteck (Mitte, halbe Groesse).
func _absperrung(mitte: Vector3, halb: Vector2) -> void:
	var ecken: Array[Vector3] = [Vector3(-halb.x, 0, -halb.y), Vector3(halb.x, 0, -halb.y), Vector3(halb.x, 0, halb.y), Vector3(-halb.x, 0, halb.y)]
	for i in 4:
		var a := mitte + ecken[i]
		var b := mitte + ecken[(i + 1) % 4]
		_zyl(a + Vector3(0, 0.5, 0), 0.04, 1.0, m["gold"], null, -1.0, 8)
		_zyl(a + Vector3(0, 0.02, 0), 0.16, 0.04, m["gold"], null, -1.0, 12)
		var l := a.distance_to(b)
		var seil := _box((a + b) * 0.5 + Vector3(0, 0.85, 0), Vector3(l, 0.04, 0.04) if absf(a.x - b.x) > 0.1 else Vector3(0.04, 0.04, l), m["seil"], false)
		_kol(seil, Vector3(l, 1.7, 0.1) if absf(a.x - b.x) > 0.1 else Vector3(0.1, 1.7, l))


## Naechstes Gemaelde aus der Liste.
func _gemaelde(pos: Vector3, dreh: float, g := Vector2(1.5, 1.5)) -> void:
	_bild(pos, g, dreh, GEMAELDE[_bild_nr % GEMAELDE.size()], 0.3)
	_bild_nr += 1


func _stadtmodell(pos: Vector3) -> void:
	var n := _theke(pos, MODELL, 0.0, m["dunkel"], m["dunkel"])
	var y := MODELL.y + 0.02
	_box(Vector3(0, y, 0), Vector3(MODELL.x - 0.3, 0.03, MODELL.z - 0.3), m["beton"], false, n)
	_box(Vector3(-1.2, y + 0.01, 0.2), Vector3(0.9, 0.03, 0.9), m["rasen"], false, n)
	for sx: float in [-1.0, 1.0]:
		_box(Vector3(sx * 1.6, y + 0.012, 0), Vector3(0.12, 0.03, MODELL.z - 0.4), m["wasser"], false, n)
	_ring(Vector3(0, y + 0.14, 0.1), 1.62, 1.7, m["chrom"], n).scale = Vector3(1.25, 1.0, 1.0)
	_box(Vector3(0, y + 0.75, -1.5), Vector3(0.28, 1.5, 0.28), m["stahl"], false, n)   # Zauber-Tower
	_zyl(Vector3(0, y + 0.03, 0.5), 0.42, 0.02, m["gold"], n, -1.0, 20)                  # Runen-Plaza
	for i in MODELL_HAEUSER:
		var p := Vector2(_rng.randf_range(-2.5, 2.5), _rng.randf_range(-1.6, 1.6))
		if p.distance_to(Vector2(0, 0.5)) < 0.55 or absf(absf(p.x) - 1.6) < 0.15 or Rect2(-1.7, -0.3, 1.0, 1.0).has_point(p) or p.distance_to(Vector2(0, -1.5)) < 0.3:
			continue
		var h := _rng.randf_range(0.08, 0.5)
		_box(Vector3(p.x, y + 0.015 + h * 0.5, p.y), Vector3(_rng.randf_range(0.12, 0.2), h, _rng.randf_range(0.12, 0.2)), m["stahl"] if i % 3 != 0 else m["weiss"], false, n)
	var glas := _box(Vector3(0, y + 0.9, 0), Vector3(MODELL.x - 0.1, 1.8, MODELL.z - 0.1), m["glas"], false, n)
	glas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_schild("SYNTH-CITY IM MASSSTAB 1:120", pos + Vector3(0, 0.55, MODELL.z * 0.5 + 0.03), 0.0, 0.004)


func _stadtgeschichte() -> void:
	var ix := innen_x()
	var iz := innen_z()
	_licht_raster(0, 3, 2, 2.3, 13.0)
	# Kasse rechts vom Eingang
	var th := _theke(Vector3(12.5, 0, 6.5), Vector3(4.5, 1.05, 1.1), 0.0, m["holz"], m["marmor"])
	_box(Vector3(-1.0, 1.25, -0.2), Vector3(0.5, 0.34, 0.03), m["dunkel"], false, th)
	_stuhl(Vector3(12.5, 0, 5.2), 180.0)
	_schild("KASSE // INFO", Vector3(12.5, 3.2, 6.5), 0.0, 0.006, Color(1.0, 0.9, 0.6))
	_schild("EG  STADTGESCHICHTE\nOG  GEMÄLDE // SKULPTUR", Vector3(ix - 0.05, 2.4, 4.0), -90.0, 0.005)
	_stadtmodell(Vector3(0.0, 0, 1.0))
	# Vitrinen an der Rueckwand
	for i in 5:
		var p := Vector3(-9.0 + i * 5.4, 0, -iz + 1.0)
		var v := _vitrine(p, Vector3(1.8, 2.2, 1.0))
		_schild(FUNDE[i], p + Vector3(0, 0.5, 0.52), 0.0, 0.0028)
		match i:
			0:
				var brezel := _ring(Vector3(0, 1.4, 0), 0.2, 0.36, m["teig"], v)
				brezel.rotation.x = PI / 2.0
				_box(Vector3(0, 1.4, 0), Vector3(0.5, 0.08, 0.08), m["teig"], false, v)
			1:
				var gurke := _zyl(Vector3(0, 1.35, 0), 0.13, 0.8, m["gurke"], v, -1.0, 12)
				gurke.rotation.z = 1.2
				_box(Vector3(0, 0.96, 0), Vector3(1.0, 0.1, 0.5), m["eiche"], false, v)
			2:
				_kern = Node3D.new()
				_kern.position = Vector3(0, 1.5, 0)
				v.add_child(_kern)
				_zyl(Vector3(0, 0.2, 0), 0.0, 0.4, m["kern"], _kern, 0.22, 6).rotation.x = PI
				_zyl(Vector3(0, -0.2, 0), 0.0, 0.4, m["kern"], _kern, 0.22, 6)
				_licht(p + Vector3(0, 1.5, 0.3), Color(0.3, 0.9, 1.0), 1.2, 5.0)
			3:
				var stab := _zyl(Vector3(0, 1.3, 0), 0.025, 1.3, m["holz"], v, 0.015, 8)
				stab.rotation.z = 1.35
				_kugel(Vector3(-0.63, 1.44, 0), 0.07, m["kern"], v)
			_:
				_zyl(Vector3(0, 1.0, 0), 0.2, 0.2, m["weiss"], v, 0.34, 14)
				for k in 9:
					_kugel(Vector3(cos(k * 2.4) * 0.16, 1.14 + (k % 3) * 0.07, sin(k * 2.4) * 0.16), 0.09, m["popcorn"], v)
	# Schwebe-Auto Mk I auf Podest hinter Seilen
	var ap := Vector3(-8.5, 0, 3.5)
	_box(ap + Vector3(0, 0.15, 0), Vector3(5.2, 0.3, 3.0), m["marmor"])
	_box(ap + Vector3(0, 0.95, 0), Vector3(4.0, 0.7, 1.8), m["auto"], false)
	_box(ap + Vector3(-0.2, 1.55, 0), Vector3(2.0, 0.6, 1.6), m["fenster"], false)
	for sx: float in [-1.0, 1.0]:
		_box(ap + Vector3(sx * 1.4, 0.55, 0), Vector3(0.9, 0.12, 1.9), m["kern"], false)
	_box(ap + Vector3(2.02, 0.95, 0), Vector3(0.04, 0.2, 1.4), m["lampe"], false)
	_absperrung(ap, Vector2(3.2, 2.1))
	_schild("SCHWEBE-AUTO MK I\nERSTES SERIENMODELL DER STADT", ap + Vector3(0, 0.75, 2.2), 0.0, 0.0035)
	# Gemaelde an den Seitenwaenden, Baenke
	for z: float in [-3.0, 3.5]:
		_gemaelde(Vector3(ix - 0.04, 2.3, z - 2.0), -90.0)
	_gemaelde(Vector3(-ix + 0.04, 2.3, 5.0), 90.0, Vector2(2.2, 1.6))
	_bank(Vector3(6.5, 0, -4.5), 2.6)
	_bank(Vector3(-3.0, 0, -4.5), 2.6)
	_pflanze(Vector3(ix - 1.0, 0, iz - 1.0))


func _galerie() -> void:
	var y := boden_y(1)
	var ix := innen_x()
	var iz := innen_z()
	_licht_raster(1, 3, 2, 2.3, 13.0)
	_schild("GALERIE", Vector3(-ix + treppe_b() + 2.0, y + 3.6, -iz + 0.05), 0.0, 0.008, Color(1.0, 0.9, 0.6))
	# Gemaelde an Rueckwand und Seitenwaenden
	for i in 6:
		_gemaelde(Vector3(-9.0 + i * 4.6, y + 2.2, -iz + 0.04), 0.0, Vector2(1.8, 1.5))
	for i in 3:
		_gemaelde(Vector3(ix - 0.04, y + 2.2, -5.0 + i * 5.0), -90.0)
	_gemaelde(Vector3(-ix + 0.04, y + 2.2, 4.0), 90.0, Vector2(2.4, 1.7))
	# Stellwaende mit Bildern auf beiden Seiten
	for i in 3:
		var sp := Vector3(-6.0 + i * 8.0, y, 0.5)
		_box(sp + Vector3(0, 1.6, 0), Vector3(4.6, 3.2, 0.3), m["stellwand"])
		_gemaelde(sp + Vector3(-1.0, 1.9, 0.17), 0.0, Vector2(1.4, 1.4))
		_gemaelde(sp + Vector3(1.1, 1.9, 0.17), 0.0, Vector2(1.2, 1.6))
		_gemaelde(sp + Vector3(0, 1.9, -0.17), 180.0, Vector2(2.4, 1.6))
	# Skulpturen auf Marmorsockeln
	for i in 4:
		var p := Vector3(-9.0 + i * 7.0, y, 6.0)
		_box(p + Vector3(0, 0.5, 0), Vector3(0.9, 1.0, 0.9), m["marmor"])
		match i:
			0:
				for k in 3:
					_kugel(p + Vector3(0, 1.3 + k * 0.42, 0), 0.3 - k * 0.07, m["chrom"])
			1:
				for k in 5:
					_box(p + Vector3(0, 1.1 + k * 0.2, 0), Vector3(0.6 - k * 0.08, 0.18, 0.6 - k * 0.08), m["gold"], false).rotation.y = k * 0.4
			2:
				_ring(p + Vector3(0, 1.55, 0), 0.3, 0.5, m["kern"]).rotation.x = PI / 2.0
			_:
				_zyl(p + Vector3(0, 1.6, 0), 0.35, 1.2, m["teig"], null, 0.0, 5)
	for i in 2:
		_bank(Vector3(-2.0 + i * 8.0, y, -4.5), 2.8)
	_pflanze(Vector3(ix - 1.0, y, iz - 1.0))
