extends "res://levels/haus.gd"
## Stadtverwaltung von Synth-City: begehbar, drei Etagen (Basis: levels/haus.gd). Front zeigt lokal nach +z.
## EG Buergerbuero (Information, Wartebereich mit Aufrufanzeige, vier Schalter, Stadtplan aus den Strassendaten),
## 1. OG Aemter (Flur mit sieben Bueros), 2. OG Ratssaal und Buergermeisterbuero.
## Aussen: Portikus, Uhr, Fahnen. Wird von stadt.gd (_rathaus) erzeugt. Keine Signale, keine Exporte.

const B := 36.0
const T := 26.0
const ETAGEN := 3
const ETAGE_H := 4.5
const TUER_X := 3.0
const SCHALTER: Array[String] = ["1 // MELDEWESEN", "2 // ZAUBERLIZENZEN", "3 // SCHWEBE-KFZ", "4 // FUNDBÜRO"]
const AEMTER_HINTEN: Array[String] = ["1.01 BAUAMT", "1.02 ORDNUNGSAMT", "1.03 STANDESAMT"]
const AEMTER_VORN: Array[String] = ["1.04 STADTKASSE", "1.05 ZAUBERAUFSICHT", "1.06 VERKEHR // AMPELN", "1.07 ARCHIV"]
const FLUR := 2.2                   ## halbe Flurbreite im 1. OG
const PLAN_MASSSTAB := 1.0 / 170.0  ## Stadtplan an der Wand
const STADT_BLAU := Color(0.1, 0.25, 0.6)
const STADT_GOLD := Color(0.9, 0.7, 0.15)


func _bauen() -> void:
	name = "Rathaus"
	_basis_materialien()
	m["boden"] = _tex("foyer_granite_tile", 2.4)
	m["boden_oben"] = _tex("markt_oak_wood_planks", 2.4)
	m["fassade"] = _tex("concrete_tile_facade", 4.0, Color(1.5, 1.45, 1.35), 0.0, 1.0, false)
	m["marmor"] = _tex("marble_01", 2.0)
	m["gold"] = _std(STADT_GOLD, 0.0, 0.9, 0.3)
	m["blau"] = _std(STADT_BLAU, 0.0, 0.0, 0.7)
	m["strasse"] = _std(Color(0.85, 0.87, 0.9), 0.4)
	m["hier"] = _std(Color(1.0, 0.2, 0.2), 2.0)
	m["papier"] = _std(Color(0.95, 0.95, 0.9), 0.0, 0.0, 0.9)
	_rohbau(B, T, ETAGEN, ETAGE_H, TUER_X, 5.0)
	_aussen()
	_buergerbuero()
	_aemter()
	_ratssaal()
	_buecher_bauen()


func _aussen() -> void:
	_portikus(TUER_X, 16.0, ETAGE_H * 2.0 - 0.4, 3.2, 6, m["saeule"])
	_fassaden_schrift("STADTVERWALTUNG", "SYNTH-CITY // BÜRGERBÜRO // RATSSAAL", ETAGE_H * 2.0 + 1.6, Color(1.0, 0.9, 0.6), 0.03, TUER_X)
	_leuchtbaender()
	# Uhr im Giebelfeld
	var uhr := Vector3(TUER_X, ETAGE_H * 2.0 + 3.2, T * 0.5 + HAUT + 0.06)
	_zyl(uhr, 0.9, 0.08, m["weiss"], null, -1.0, 24).rotation.x = PI / 2.0
	_box(uhr + Vector3(0, 0.3, 0.06), Vector3(0.06, 0.6, 0.02), m["dunkel"], false)
	_box(uhr + Vector3(0.2, 0, 0.06), Vector3(0.4, 0.05, 0.02), m["dunkel"], false)
	for i in 3:
		_fahne(Vector3(-11.0 + i * 2.0, 0, T * 0.5 + 6.0), [STADT_BLAU, STADT_GOLD, Color(0.75, 0.1, 0.5)][i])
	for sx: float in [-1.0, 1.0]:
		_box(Vector3(TUER_X + sx * 9.5, 0.35, T * 0.5 + 2.0), Vector3(2.0, 0.7, 1.2), m["beton"])
		_kugel(Vector3(TUER_X + sx * 9.5, 1.05, T * 0.5 + 2.0), 0.8, m["blatt"], null, 0.8)
	_bank(Vector3(12.0, 0, T * 0.5 + 5.0), 3.0, 180.0, true)


## Stadtplan aus den Strassendaten (levels/strassen_daten.gd) auf einer Wandtafel. `dreh`: 0 = lesbar von +z.
func _stadtplan(pos: Vector3, dreh: float, standort: Vector2) -> void:
	var n := _gruppe(pos, dreh)
	_box(Vector3.ZERO, Vector3(4.4, 3.6, 0.06), m["dunkel"], false, n)
	for st in StrassenDaten.STRASSEN:
		var a: Vector2 = st["a"] * PLAN_MASSSTAB
		var b: Vector2 = st["b"] * PLAN_MASSSTAB
		var mitte := (a + b) * 0.5
		var dicke: float = maxf(st["breite"] * PLAN_MASSSTAB, 0.035)
		var g := Vector3(absf(a.x - b.x) + dicke, dicke, 0.01) if StrassenDaten.ist_ns(st) == false else Vector3(dicke, absf(a.y - b.y) + dicke, 0.01)
		# Karte: x nach rechts, Norden (-z) nach oben
		_box(Vector3(mitte.x, -mitte.y, 0.036), g, m["strasse"], false, n)
	_zyl(Vector3(standort.x * PLAN_MASSSTAB, -standort.y * PLAN_MASSSTAB, 0.05), 0.06, 0.02, m["hier"], n, -1.0, 10).rotation.x = PI / 2.0
	_text("STADTPLAN SYNTH-CITY", Vector3(0, 1.62, 0.04), Color(0.85, 0.95, 1.0), 0.004, 0.0, true, n)
	_text("● STANDORT", Vector3(1.5, -1.62, 0.04), Color(1.0, 0.4, 0.4), 0.003, 0.0, true, n)


func _buergerbuero() -> void:
	var ix := innen_x()
	var iz := innen_z()
	_licht_raster(0, 3, 2, 3.0, 14.0)
	# Information gegenueber dem Eingang
	var info := _theke(Vector3(TUER_X, 0, 5.5), Vector3(5.0, 1.1, 1.2), 0.0, m["holz"], m["marmor"])
	_box(Vector3(0, 0.6, 0.62), Vector3(4.6, 0.08, 0.02), m["akzent"], false, info)
	_box(Vector3(1.2, 1.3, -0.2), Vector3(0.6, 0.38, 0.03), m["dunkel"], false, info)
	_stuhl(Vector3(TUER_X, 0, 4.2), 180.0)
	_schild("INFORMATION", Vector3(TUER_X, 3.3, 5.5), 0.0, 0.008, Color(1.0, 0.9, 0.6))
	# Wartenummern-Spender und Fotoautomat
	_zyl(Vector3(TUER_X - 4.0, 0.55, 9.5), 0.18, 1.1, m["dunkel"], null, -1.0, 12, true)
	_box(Vector3(TUER_X - 4.0, 1.2, 9.5), Vector3(0.3, 0.2, 0.3), m["hier"], false)
	_box(Vector3(ix - 0.9, 1.1, 9.5), Vector3(1.4, 2.2, 2.0), m["dunkel"])
	_box(Vector3(ix - 1.62, 1.2, 9.5), Vector3(0.03, 1.6, 0.9), m["blau"], false)
	_schild("PASSFOTO", Vector3(ix - 1.63, 2.3, 9.5), -90.0, 0.004)
	# Schalter an der Rueckwand: Tresen mit Glasscheibe, dahinter Arbeitsplatz
	for i in SCHALTER.size():
		var x := -9.5 + i * 6.6
		var th := _theke(Vector3(x, 0, -iz + 3.2), Vector3(5.2, 1.1, 0.9), 0.0, m["holz"], m["marmor"])
		var glas := _box(Vector3(0, 1.75, 0.2), Vector3(5.2, 1.3, 0.04), m["glas"], false, th)
		glas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_schild(SCHALTER[i], Vector3(x, 3.2, -iz + 3.4), 0.0, 0.006, Color(0.85, 0.95, 1.0))
		_schreibtisch(Vector3(x, 0, -iz + 1.5), 180.0)
		if i > 0:
			_box(Vector3(x - 3.3, 1.3, -iz + 2.2), Vector3(0.1, 2.6, 3.0), m["wand"])
	# Wartebereich mit Aufrufanzeige
	for i in 3:
		for k in 2:
			_bank(Vector3(1.0 + k * 6.5, 0, -4.5 + i * 2.6), 4.4, 180.0, true)
	_schild("AUFRUF   A 042   ▶   SCHALTER 3", Vector3(4.0, 3.4, -6.4), 0.0, 0.009, Color(1.0, 0.5, 0.2))
	# Formulare, Stadtplan, Pflanzen
	var fs := _gruppe(Vector3(ix - 0.25, 0, -1.0), -90.0)
	_box(Vector3(0, 0.9, -0.1), Vector3(4.0, 1.8, 0.05), m["holz"], false, fs)
	for i in 3:
		for k in 8:
			_box(Vector3(-1.6 + k * 0.46, 0.4 + i * 0.5, 0.02), Vector3(0.3, 0.36, 0.03), m["papier"], false, fs).rotation.x = -0.25
	_schild("FORMULARE", Vector3(ix - 0.05, 2.3, -1.0), -90.0, 0.005)
	_stadtplan(Vector3(-ix + 0.05, 2.3, 5.0), 90.0, Vector2(42, 0))
	_bank(Vector3(-ix + 2.5, 0, 5.0), 3.0, 90.0)
	_pflanze(Vector3(-ix + 1.0, 0, iz - 1.0))
	_pflanze(Vector3(ix - 1.0, 0, iz - 1.0))
	_pflanze(Vector3(-6.0, 0, 4.0))


## Buero mit zwei Arbeitsplaetzen, Aktenregal und Pflanze. `nach_hinten`: Raum liegt hinter dem Flur.
func _buero(e: int, x0: float, x1: float, nach_hinten: bool, titel: String) -> void:
	var y := boden_y(e)
	var iz := innen_z()
	var mx := (x0 + x1) * 0.5
	var z_wand := -FLUR if nach_hinten else FLUR
	var z_aussen := -iz if nach_hinten else iz
	var s := -1.0 if nach_hinten else 1.0
	_innenwand(Vector2(x0, z_wand), Vector2(x1, z_wand), e, (x1 - x0) * 0.5)
	_innenwand(Vector2(x1, z_wand), Vector2(x1, z_aussen), e)
	_schild(titel, Vector3(mx + 1.6, y + 1.9, z_wand - s * 0.09), 0.0 if nach_hinten else 180.0, 0.0035)
	_schreibtisch(Vector3(mx - 1.6, y, z_aussen - s * 2.2), 0.0 if nach_hinten else 180.0)
	_schreibtisch(Vector3(mx + 1.6, y, z_aussen - s * 2.2), 0.0 if nach_hinten else 180.0, "buero_bild_chart")
	_buecherregal(Vector3(x1 - 0.3, y, (z_wand + z_aussen) * 0.5 + s * 0.5), 3.6, 2.0, -90.0, false, 0.75)
	_pflanze(Vector3(x0 + 0.8, y, z_wand + s * 0.9), 1.2)
	_deckenlicht(mx, (z_wand + z_aussen) * 0.5, e, 1.6, 9.0)


func _aemter() -> void:
	var y := boden_y(1)
	var ix := innen_x()
	_licht_raster(1, 3, 1, 1.8, 10.0)
	var links := -ix + treppe_b() + 0.6
	var b_h := (ix - links) / AEMTER_HINTEN.size()
	for i in AEMTER_HINTEN.size():
		_buero(1, links + i * b_h, links + (i + 1) * b_h, true, AEMTER_HINTEN[i])
	_innenwand(Vector2(links, -FLUR), Vector2(links, -innen_z()), 1)
	var b_v := ix * 2.0 / AEMTER_VORN.size()
	for i in AEMTER_VORN.size():
		_buero(1, -ix + i * b_v, -ix + (i + 1) * b_v, false, AEMTER_VORN[i])
	# Flur: Baenke, Kopierer, Wegweiser
	_bank(Vector3(-2.0, y, -FLUR + 0.45), 2.4)
	_bank(Vector3(9.0, y, FLUR - 0.45), 2.4, 180.0)
	_box(Vector3(ix - 0.8, y + 0.55, 0), Vector3(0.9, 1.1, 0.7), m["weiss"])
	_box(Vector3(ix - 0.8, y + 1.13, 0), Vector3(0.9, 0.06, 0.7), m["dunkel"], false)
	_schild("1. OG  ÄMTER\n◀ 1.01 BIS 1.03     1.04 BIS 1.07 ▶", Vector3(-ix + 0.05, y + 2.6, 0.5), 90.0, 0.004)


func _ratssaal() -> void:
	var y := boden_y(2)
	var ix := innen_x()
	var iz := innen_z()
	_licht_raster(2, 3, 2, 2.3, 14.0)
	var wand_x := 10.5
	# Hufeisentisch mit Stuehlen
	_tisch(Vector3(-1.0, y, -8.0), Vector3(11.0, 0.75, 1.2), m["holz"])
	for sx: float in [-1.0, 1.0]:
		_tisch(Vector3(-1.0 + sx * 4.9, y, -3.6), Vector3(1.2, 0.75, 7.0), m["holz"])
		for i in 5:
			_stuhl(Vector3(-1.0 + sx * 6.0, y, -6.2 + i * 1.3), -90.0 * sx, m["leder"])
	for i in 7:
		_stuhl(Vector3(-4.9 + i * 1.3, y, -9.1), 180.0, m["leder"])
	# Rednerpult
	_box(Vector3(-1.0, y + 0.6, 1.2), Vector3(0.8, 1.2, 0.6), m["holz"])
	_box(Vector3(-1.0, y + 1.22, 1.2), Vector3(0.9, 0.04, 0.7), m["holz"], false).rotation.x = 0.2
	# Stadtwappen und Fahnen an der Rueckwand
	var wappen := Vector3(-1.0, y + 3.0, -iz + 0.06)
	_zyl(wappen, 0.9, 0.06, m["blau"], null, -1.0, 28).rotation.x = PI / 2.0
	_ring(wappen + Vector3(0, 0, 0.02), 0.82, 0.92, m["gold"]).rotation.x = PI / 2.0
	_text("SC", wappen + Vector3(0, 0, 0.05), STADT_GOLD, 0.012, 0.0, true)
	for sx: float in [-1.0, 1.0]:
		_fahne(Vector3(-1.0 + sx * 2.4, y, -iz + 0.5), STADT_BLAU if sx < 0.0 else STADT_GOLD, 3.4)
	# Zuschauerreihen
	for i in 3:
		for k in 8:
			_stuhl(Vector3(-5.6 + k * 1.3, y, 4.6 + i * 1.5), 180.0)
	_schild("RATSSAAL", Vector3(-ix + treppe_b() + 2.0, y + 3.3, -iz + 0.05), 0.0, 0.008, Color(1.0, 0.9, 0.6))
	# Buergermeisterbuero rechts
	_innenwand(Vector2(wand_x, -iz), Vector2(wand_x, iz), 2, iz + 3.0)
	_schild("BÜRGERMEISTERIN", Vector3(wand_x - 0.09, y + 2.6, 3.0), -90.0, 0.005, Color(1.0, 0.9, 0.6))
	var bx := (wand_x + ix) * 0.5
	_box(Vector3(bx, y + 0.01, 0), Vector3(ix - wand_x - 0.4, 0.02, 12.0), m["teppich"], false)
	var chef := _tisch(Vector3(bx, y, -6.0), Vector3(2.6, 0.76, 1.2), m["holz"], 0.0)
	_box(Vector3(0.6, 1.06, 0.2), Vector3(0.6, 0.38, 0.03), m["dunkel"], false, chef)
	_stuhl(Vector3(bx, y, -7.2), 180.0, m["leder"])
	for sx: float in [-0.7, 0.7]:
		_stuhl(Vector3(bx + sx, y, -4.6), 0.0, m["leder"])
	_buecherregal(Vector3(bx, y, -iz + 0.2), 5.0, 2.4, 0.0, false, 0.8)
	_bank(Vector3(bx, y, 6.0), 3.0, 180.0, true)
	_tisch(Vector3(bx, y, 4.4), Vector3(1.4, 0.42, 0.8), m["eiche"])
	_pflanze(Vector3(ix - 0.9, y, 9.5))
	_bild(Vector3(ix - 0.04, y + 2.3, 1.0), Vector2(1.6, 1.2), -90.0, "buero_poster")
	_deckenlicht(bx, -4.0, 2, 1.8, 9.0)
	_deckenlicht(bx, 6.0, 2, 1.8, 9.0)
