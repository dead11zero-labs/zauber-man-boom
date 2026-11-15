extends "res://levels/haus.gd"
## Stadtbuecherei: begehbar, zwei Etagen mit Treppenhaus (Basis: levels/haus.gd). Front zeigt lokal nach +z.
## EG: Ausleihe, acht Regalgaenge, Wandregale, Lesetische, Zeitschriften, Katalogplaetze.
## OG: Lesesaal mit Wandregalen, Arbeitsplaetzen am Fenster, Sofaecke und Kinderecke.
## Die Buecher sind ein einziges MultiMesh. Wird von stadt.gd (_buecherei) erzeugt. Keine Signale, keine Exporte.

const B := 32.0
const T := 22.0
const ETAGEN := 2
const ETAGE_H := 4.8
const TUER_X := 5.0
const GAENGE: Array[String] = ["A-D ROMANE", "E-K ROMANE", "L-R ROMANE", "S-Z ROMANE", "ZAUBEREI", "TECHNIK", "STADTGESCHICHTE", "KOCHEN"]
const GANG_X0 := -8.5
const GANG_ABSTAND := 3.0
const KISSEN: Array[Color] = [Color(0.9, 0.25, 0.2), Color(0.2, 0.5, 0.95), Color(1.0, 0.8, 0.15), Color(0.2, 0.7, 0.35)]


func _bauen() -> void:
	name = "Buecherei"
	_basis_materialien()
	m["boden"] = _tex("foyer_wood_floor_deck", 2.0)
	m["boden_oben"] = _tex("buero_teppich", 2.0, Color(0.9, 0.95, 1.1))
	m["fassade"] = _tex("brick_wall_005", 3.0, Color(0.75, 0.68, 0.66), 0.0, 1.0, false)
	m["gruen_l"] = _std(Color(0.1, 0.5, 0.25), 0.0, 0.0, 0.4)
	m["schein"] = _std(Color(1.0, 0.9, 0.6), 1.6)
	m["teppich_r"] = _tex("buero_teppich", 1.5, Color(0.9, 0.35, 0.3))
	_rohbau(B, T, ETAGEN, ETAGE_H, TUER_X, 4.0)
	_aussen()
	_erdgeschoss()
	_lesesaal()
	_buecher_bauen()


func _aussen() -> void:
	_portikus(TUER_X, 8.0, TUER_H + 0.5, 2.6, 2, m["saeule"])
	_fassaden_schrift("BÜCHEREI", "STADTBIBLIOTHEK SYNTH-CITY // 3 MILLIONEN SEITEN", ETAGE_H + 1.9, Color(1.0, 0.85, 0.5), 0.03, -4.0)
	_leuchtbaender()
	# Pflanzkuebel und Buecher-Rueckgabeklappe aussen
	for sx: float in [-1.0, 1.0]:
		_box(Vector3(TUER_X + sx * 5.5, 0.35, T * 0.5 + 1.2), Vector3(1.6, 0.7, 1.0), m["beton"])
		_kugel(Vector3(TUER_X + sx * 5.5, 1.0, T * 0.5 + 1.2), 0.7, m["blatt"], null, 0.8)
	_box(Vector3(-6.0, 1.1, T * 0.5 + 0.2), Vector3(1.0, 0.7, 0.3), m["stahl"], false)
	_schild("RÜCKGABE 24/7", Vector3(-6.0, 1.75, T * 0.5 + 0.12), 0.0, 0.004)


## Lesetisch mit vier Stuehlen und gruener Leselampe.
func _lesetisch(pos: Vector3) -> void:
	var n := _tisch(pos, Vector3(2.4, 0.75, 1.1), m["eiche"])
	_zyl(Vector3(0, 0.95, 0), 0.02, 0.4, m["chrom"], n, -1.0, 6)
	_box(Vector3(0, 1.17, 0), Vector3(0.5, 0.08, 0.16), m["gruen_l"], false, n)
	_box(Vector3(0, 1.125, 0), Vector3(0.44, 0.01, 0.1), m["schein"], false, n)
	for sx: float in [-0.6, 0.6]:
		_stuhl(pos + Vector3(sx, 0, 0.9), 0.0, m["leder"])
		_stuhl(pos + Vector3(sx, 0, -0.9), 180.0, m["leder"])
	# aufgeschlagenes Buch
	_box(Vector3(-0.5, 0.765, 0.2), Vector3(0.34, 0.02, 0.24), m["weiss"], false, n)


func _erdgeschoss() -> void:
	var ix := innen_x()
	var iz := innen_z()
	_licht_raster(0, 3, 2, 2.2, 13.0)
	# Ausleihtheke rechts vom Eingang
	var th := _theke(Vector3(11.0, 0, 5.5), Vector3(1.2, 1.05, 5.0), 0.0, m["holz"], m["eiche"])
	for z: float in [-1.4, 1.2]:
		_box(Vector3(0.2, 1.27, z), Vector3(0.03, 0.36, 0.56), m["dunkel"], false, th)
		_box(Vector3(0.18, 1.27, z), Vector3(0.006, 0.32, 0.52), _bild_mat("buero_bild_tabelle", 0.9), false, th)
	for i in 3:
		_box(Vector3(-0.2, 1.08 + i * 0.05, 2.0), Vector3(0.3, 0.05, 0.22), _std(BUCH_FARBEN[i]), false, th)
	_stuhl(Vector3(12.4, 0, 4.5), -90.0)
	_schild("AUSLEIHE // AUSKUNFT", Vector3(10.35, 3.2, 5.5), -90.0, 0.006, Color(1.0, 0.85, 0.5))
	_buecherregal(Vector3(ix - 0.2, 0, 5.5), 6.0, 2.2, -90.0, false, 0.6)
	# Regalgaenge
	for i in GAENGE.size():
		var x := GANG_X0 + i * GANG_ABSTAND
		_buecherregal(Vector3(x, 0, -5.8), 8.4, 2.2, 90.0, true)
		_schild(GAENGE[i], Vector3(x, 2.45, -1.55), 0.0, 0.0035)
	_buecherregal(Vector3(ix - 0.2, 0, -5.0), 9.0, 2.6, -90.0)
	# Lesetische und Teppich vorn links
	_box(Vector3(-7.5, BODEN_EG + 0.01, 6.0), Vector3(12.0, 0.02, 7.0), m["teppich_r"], false)
	for p: Vector3 in [Vector3(-11.0, 0, 4.5), Vector3(-11.0, 0, 8.0), Vector3(-6.0, 0, 4.5), Vector3(-6.0, 0, 8.0)]:
		_lesetisch(p)
	# Zeitschriftenwand an der Front
	var zs := _gruppe(Vector3(-1.0, 0, iz - 0.25), 180.0)
	_box(Vector3(0, 0.9, -0.1), Vector3(4.0, 1.8, 0.05), m["holz"], false, zs)
	for i in 3:
		for k in 9:
			var heft := _box(Vector3(-1.75 + k * 0.44, 0.35 + i * 0.55, 0.02), Vector3(0.3, 0.4, 0.02), _std(BUCH_FARBEN[(i * 3 + k) % BUCH_FARBEN.size()].lightened(0.3)), false, zs)
			heft.rotation.x = -0.25
	# Katalogplaetze neben dem Treppenhaus
	for i in 2:
		_schreibtisch(Vector3(-ix + 0.7, 0, 4.0 + i * 2.2), 90.0, "buero_bild_code")
	_schild("KATALOG", Vector3(-ix + 0.05, 2.6, 5.1), 90.0, 0.005)
	_pflanze(Vector3(1.5, 0, 9.5))
	_pflanze(Vector3(ix - 1.0, 0, 9.6))
	_bild(Vector3(-9.0, 2.5, iz - 0.04), Vector2(1.6, 1.2), 180.0, "buero_poster")


func _lesesaal() -> void:
	var y := boden_y(1)
	var ix := innen_x()
	var iz := innen_z()
	_licht_raster(1, 3, 2, 2.2, 13.0)
	_schild("LESESAAL // BITTE LEISE", Vector3(-ix + treppe_b() + 3.0, y + 3.3, -iz + 0.05), 0.0, 0.006, Color(1.0, 0.85, 0.5))
	# Wandregale hinten und rechts, zwei freistehende Reihen
	_buecherregal(Vector3(4.5, y, -iz + 0.2), 21.0, 2.6, 0.0)
	_buecherregal(Vector3(ix - 0.2, y, -2.0), 15.0, 2.6, -90.0)
	for z: float in [-6.5, -3.5]:
		_buecherregal(Vector3(2.0, y, z), 14.0, 2.0, 0.0, true)
	# Arbeitsplaetze am Fenster zur Strasse
	for i in 5:
		_schreibtisch(Vector3(-3.0 + i * 2.6, y, iz - 0.55), 180.0, "buero_bild_code" if i % 2 == 0 else "buero_bild_tabelle")
	# Sofaecke
	_box(Vector3(9.0, y + 0.01, 2.5), Vector3(7.0, 0.02, 5.0), m["teppich_r"], false)
	_bank(Vector3(9.0, y, 0.6), 3.4, 0.0, true)
	_bank(Vector3(6.2, y, 2.8), 3.0, 90.0, true)
	_bank(Vector3(11.8, y, 2.8), 3.0, -90.0, true)
	_tisch(Vector3(9.0, y, 2.8), Vector3(1.6, 0.42, 0.9), m["eiche"])
	_pflanze(Vector3(12.5, y, 0.5))
	# Globus
	_zyl(Vector3(4.0, y + 0.45, 1.0), 0.05, 0.9, m["holz"], null, -1.0, 8)
	_kugel(Vector3(4.0, y + 1.25, 1.0), 0.38, _std(Color(0.2, 0.45, 0.75), 0.0, 0.0, 0.5))
	_ring(Vector3(4.0, y + 1.25, 1.0), 0.4, 0.44, m["chrom"])
	# Kinderecke vorn links: bunter Teppich, Sitzkissen, niedrige Regale
	_box(Vector3(-10.5, y + 0.01, 5.5), Vector3(8.0, 0.02, 8.0), _std(Color(0.35, 0.65, 0.9), 0.0, 0.0, 0.95), false)
	for i in 8:
		var w := TAU * i / 8.0
		_zyl(Vector3(-10.5 + cos(w) * 2.2, y + 0.18, 5.5 + sin(w) * 2.2), 0.42, 0.34, _std(KISSEN[i % 4], 0.0, 0.0, 0.9), null, -1.0, 14)
	_buecherregal(Vector3(-ix + 0.2, y, 5.5), 7.0, 1.1, 90.0, false, 0.8)
	_buecherregal(Vector3(-10.5, y, 1.2), 6.0, 1.1, 0.0, true, 0.8)
	_schild("KINDERECKE", Vector3(-ix + 0.05, y + 2.4, 5.5), 90.0, 0.006, Color(1.0, 0.6, 0.3))
	_bild(Vector3(-ix + 0.04, y + 2.4, 1.0), Vector2(1.4, 1.0), 90.0, "markt_poster")
