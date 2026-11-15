extends "res://levels/haus.gd"
## Stadtklinik: begehbar, zwei Etagen mit Treppenhaus (Basis: levels/haus.gd). Front zeigt lokal nach +z.
## Die Einrichtung stammt aus dem Krankenhaus-Set (imported_models/krankenhaus, Lader: levels/krankenhaus_modelle.gd):
## Betten, Infusionsstaender, Rollstuehle, Schraenke, Baenke, Zeitschriften, Telefon, Notausgang- und Deckenleuchten.
## EG: Empfangshalle mit Anmeldung und Wartebereich, drei Untersuchungsraeume, Labor.
## OG: vier Patientenzimmer, Stationstresen, Aufenthaltsbereich. Auf dem Dach ein Hubschrauberlandeplatz.
## Wird von stadt.gd (_oeffentliche_gebaeude) erzeugt. Keine Signale, keine Exporte.

const KH := preload("res://levels/krankenhaus_modelle.gd")
const FP := preload("res://levels/frosty_props.gd")

const B := 32.0
const T := 20.0
const ETAGEN := 2
const ETAGE_H := 4.2
const TUER_X := 4.0
const RAUM_WAND_Z := -3.0            ## Vorderkante der Zimmerreihe an der Rueckwand (OG)
const UNTERSUCHUNG_WAND_Z := -2.0    ## Vorderkante der Untersuchungsraeume (EG)
const ZIMMER_X: Array[float] = [-11.8, -5.0, 1.8, 8.6, 15.6]   ## Zimmergrenzen im OG
const U_RAEUME_X: Array[float] = [0.0, 5.2, 10.4, 15.6]        ## Untersuchungsraeume im EG
const KACHEL_DICKE := 0.1             ## Dicke der Boden- und Deckenkacheln im Set
const KREUZ_ROT := Color(0.9, 0.08, 0.1)
## Kleinteile ohne Kollision (liegen auf Moebeln oder haengen)
const OHNE_KOLLISION: Array[String] = ["Magazine", "Landline_phone", "Ceiling_Light", "Exit_sign", "IV_bag", "Ceiling_Tile"]


func _bauen() -> void:
	name = "Krankenhaus"
	_basis_materialien()
	# Die Set-Texturen sind Atlanten fuer die UVs der Kacheln (nicht nahtlos): Boden und Decke werden
	# deshalb aus Kachel-Modellen gelegt (_kacheln), Waende bleiben Putz mit gruenem Sockel.
	m["wand"] = _tex("foyer_painted_plaster_wall", 3.0, Color(1.05, 1.15, 1.1))
	m["sockel"] = _std(Color(0.5, 0.72, 0.62), 0.0, 0.0, 0.55)
	m["fassade"] = _tex("concrete_tile_facade", 4.0, Color(1.9, 1.95, 2.05), 0.0, 1.0, false)
	m["kreuz"] = _std(KREUZ_ROT, 2.0, 0.0, 0.5, false)
	_rohbau(B, T, ETAGEN, ETAGE_H, TUER_X, 4.0)
	_aussen()
	_dach()
	_boeden_und_decken()
	_erdgeschoss()
	_station()


## Ein Teil aus dem Set: Gruppe an `pos` (Ursprung Mitte unten), gedreht um y, mit Kollisionsquader.
func _teil(teil: String, pos: Vector3, dreh := 0.0, kol := true) -> Node3D:
	var n := _gruppe(pos, dreh)
	n.add_child(KH.laden(teil))
	if kol and not teil in OHNE_KOLLISION:
		var g := KH.masse(teil)
		var k := Node3D.new()
		k.position = Vector3(0, g.y * 0.5, 0)
		n.add_child(k)
		_kol(k, g)
	return n


## Deckenleuchten aus dem Set im Raster, jeweils mit echtem Licht.
func _licht_set(e: int, spalten: int, reihen: int, energie := 2.4, reichweite := 12.0) -> void:
	var ix := innen_x()
	var iz := innen_z()
	var unterkante := boden_y(e + 1) - DECKE - BELAG if e < etagen - 1 else boden_y(e + 1) - 0.06
	for i in spalten:
		for j in reihen:
			var x := -ix + ix * 2.0 * (i + 0.5) / spalten
			var z := -iz + iz * 2.0 * (j + 0.5) / reihen
			_teil("Ceiling_Light", Vector3(x, unterkante - 0.15, z), 0.0, false)
			_licht(Vector3(x, unterkante - LICHT_ABSTAND, z), Color(0.95, 0.98, 1.0), energie, reichweite)


## Rechtecke (x, z) einer Geschossflaeche: ab Etage 1 ohne das Treppenloch.
func _flaechen(e: int) -> Array[Rect2]:
	var ix := innen_x()
	var iz := innen_z()
	if e == 0:
		return [Rect2(-ix, -iz, ix * 2.0, iz * 2.0)]
	var tx1 := -ix + treppe_b()
	var tz := treppe_z()
	return [Rect2(tx1, -iz, ix - tx1, iz * 2.0), Rect2(-ix, tz, tx1 + ix, iz - tz)]


## Legt Kachel-Modelle (2 x 2 m, im Schachbrett aus `teile`) mit Oberkante `y_unten` + Dicke auf ein Rechteck.
## Die Kacheln werden leicht gestreckt, damit sie das Rechteck genau fuellen (keine Ueberlappung).
func _kacheln(teile: Array[String], r: Rect2, y_unten: float, mat: Material, kopf := false) -> void:
	var spalten := maxi(1, ceili(r.size.x / 2.0))
	var reihen := maxi(1, ceili(r.size.y / 2.0))
	var sx := r.size.x / spalten / 2.0
	var sz := r.size.y / reihen / 2.0
	var lagen: Array = []
	for t in teile:
		lagen.append([])
	for i in spalten:
		for j in reihen:
			var basis := Basis.from_scale(Vector3(sx, 1.0, sz))
			if kopf:
				basis = Basis(Vector3.RIGHT, PI) * basis
			var tr := Transform3D(basis, Vector3(r.position.x + (i + 0.5) * r.size.x / spalten,
				y_unten + (KACHEL_DICKE if kopf else 0.0), r.position.y + (j + 0.5) * r.size.y / reihen))
			lagen[(i + j) % teile.size()].append(tr)
	for k in teile.size():
		var liste: Array = lagen[k]
		if liste.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = KH.mesh(teile[k])
		mm.instance_count = liste.size()
		for n in liste.size():
			mm.set_instance_transform(n, liste[n])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mat
		add_child(mmi)


## Fliesenboden und Rasterdecke in allen Etagen aus den Kachel-Modellen des Sets.
func _boeden_und_decken() -> void:
	var boden := KH.material("Floors_1")
	var decke := KH.material("Ceiling_1").duplicate() as StandardMaterial3D
	decke.cull_mode = BaseMaterial3D.CULL_DISABLED   # Kachel-Modell liegt kopfueber im Set
	for e in etagen:
		var basis := BODEN_EG if e == 0 else boden_y(e)
		for r in _flaechen(e):
			_kacheln(["Floor_tile_1", "Floor_tile_2"], r, basis - 0.08, boden)
		# Decke ueber der Etage (ab Etage 1 oben ohne Treppenloch; Dach voll)
		var unterkante := boden_y(e + 1) - DECKE - BELAG if e < etagen - 1 else boden_y(e + 1) - 0.06
		var rects := _flaechen(e + 1) if e < etagen - 1 else _flaechen(0)
		for r in rects:
			_kacheln(["Ceiling_Tile"], r, unterkante - 0.09, decke, true)
	# Gruener Sockel an den Aussenwaenden innen (Hoehe der Bruestung)
	var ix := innen_x()
	var iz := innen_z()
	for e in etagen:
		var y := boden_y(e) + BRUESTUNG * 0.5
		_box(Vector3(0, y, -iz + 0.02), Vector3(ix * 2.0, BRUESTUNG, 0.04), m["sockel"], false)
		for s: float in [-1.0, 1.0]:
			_box(Vector3(s * (ix - 0.02), y, 0), Vector3(0.04, BRUESTUNG, iz * 2.0), m["sockel"], false)
		if e == 0:
			_box(Vector3((-ix + TUER_X - 2.0) * 0.5, y, iz - 0.02), Vector3(ix + TUER_X - 2.0, BRUESTUNG, 0.04), m["sockel"], false)
			_box(Vector3((ix + TUER_X + 2.0) * 0.5, y, iz - 0.02), Vector3(ix - TUER_X - 2.0, BRUESTUNG, 0.04), m["sockel"], false)
		else:
			_box(Vector3(0, y, iz - 0.02), Vector3(ix * 2.0, BRUESTUNG, 0.04), m["sockel"], false)


## Kleinteil aus dem Frosty-Set (Bildschirme, Duck-Rechner, Holo-Pflanzen ...) auf einer Flaeche; ohne Kollision.
func _frosty(teil: String, pos: Vector3, dreh := 0.0) -> void:
	var n := FP.laden("props/" + teil)
	n.position = pos
	n.rotation_degrees.y = dreh
	add_child(n)


## Notausgangsschild innen an einer Wand (`dreh` wie _schild: 0 = Vorderseite nach +z).
func _notausgang(pos: Vector3, dreh: float) -> void:
	_teil("Exit_sign", pos, dreh, false)


## Zimmertuer: Oeffnung in der Querwand plus Schild darueber.
func _zimmer_wand(x0: float, x1: float, z: float, e: int, schild: String) -> void:
	_innenwand(Vector2(x0, z), Vector2(x1, z), e, (x1 - x0) * 0.5, 1.3)
	_schild(schild, Vector3((x0 + x1) * 0.5, boden_y(e) + 2.65, z + 0.1), 0.0, 0.004, Color(0.7, 0.95, 1.0))


func _aussen() -> void:
	_portikus(TUER_X, 8.0, TUER_H + 0.5, 3.0, 2, m["saeule"])
	_fassaden_schrift("KLINIK", "STADTKLINIK SYNTH-CITY // NOTAUFNAHME 24/7", ETAGE_H + 1.9, Color(0.85, 0.98, 1.0), 0.03, TUER_X)
	_leuchtbaender()
	# Rotes Kreuz an der Fassade, links neben dem Eingang
	var zf := T * 0.5 + HAUT + 0.05
	_box(Vector3(-8.0, ETAGE_H + 1.6, zf), Vector3(2.8, 0.9, 0.08), m["kreuz"], false)
	_box(Vector3(-8.0, ETAGE_H + 1.6, zf), Vector3(0.9, 2.8, 0.08), m["kreuz"], false)
	# Rettungsvorfahrt und Pflanzkuebel
	_box(Vector3(TUER_X + 7.0, 0.04, T * 0.5 + 3.5), Vector3(5.0, 0.04, 6.0), _std(Color(0.9, 0.85, 0.15), 0.0, 0.0, 0.9, false), false)
	_schild("RETTUNG\nFREIHALTEN", Vector3(TUER_X + 7.0, 1.4, T * 0.5 + 6.6), 0.0, 0.005, Color(1.0, 0.9, 0.2))
	for sx: float in [-1.0, 1.0]:
		_box(Vector3(TUER_X + sx * 5.0, 0.35, T * 0.5 + 1.4), Vector3(1.6, 0.7, 1.0), m["beton"])
		_kugel(Vector3(TUER_X + sx * 5.0, 1.0, T * 0.5 + 1.4), 0.7, m["blatt"], null, 0.8)


## Hubschrauberlandeplatz auf dem Dach.
func _dach() -> void:
	var y := boden_y(etagen) + DECKE
	_zyl(Vector3(5.0, y + 0.05, 0.0), 5.5, 0.1, _std(Color(0.18, 0.2, 0.24), 0.0, 0.0, 0.9, false), null, -1.0, 32, true)
	_ring(Vector3(5.0, y + 0.11, 0.0), 4.7, 4.9, _std(Color(0.95, 0.95, 0.95), 0.4, 0.0, 0.7, false))
	var h := _text("H", Vector3(5.0, y + 0.13, 0.0), Color(1.0, 0.95, 0.95), 0.06, 0.0, true)
	h.rotation_degrees.x = -90.0


func _erdgeschoss() -> void:
	var ix := innen_x()
	var iz := innen_z()
	_licht_set(0, 4, 2)
	# Anmeldung rechts vom Eingang
	var th := _theke(Vector3(10.5, 0, 5.2), Vector3(1.2, 1.05, 5.0), 0.0, m["weiss"], m["stahl"])
	_box(Vector3(-0.2, 1.25, -1.2), Vector3(0.03, 0.36, 0.56), m["dunkel"], false, th)
	_box(Vector3(-0.2, 1.25, 1.1), Vector3(0.03, 0.36, 0.56), m["dunkel"], false, th)
	_teil("Landline_phone", Vector3(10.5, 1.05, 6.4), 90.0, false)
	_frosty("Misc_Duckputer_B", Vector3(10.5, 1.08, 4.6), -90.0)
	_frosty("Misc_CyberScreen_B", Vector3(10.5, 1.08, 5.5), -90.0)
	_frosty("Misc_PinPad_A", Vector3(10.2, 1.08, 3.3), -90.0)
	_frosty("Light_Neon_Duck", Vector3(-4.1, 2.3, iz - 0.1), 180.0)
	_stuhl(Vector3(12.0, 0, 4.2), -90.0, m["dunkel"])
	_stuhl(Vector3(12.0, 0, 6.4), -90.0, m["dunkel"])
	_schild("ANMELDUNG", Vector3(9.85, 3.0, 5.2), -90.0, 0.006, Color(0.7, 0.95, 1.0))
	# Wartebereich links: Baenke, Tischchen mit Zeitschriften, Stuehle
	_teil("Bench", Vector3(-6.0, 0, 8.4), 180.0)
	_teil("Bench", Vector3(-2.2, 0, 8.4), 180.0)
	_teil("Bench", Vector3(-6.0, 0, 3.4), 0.0)
	_teil("Bench", Vector3(-2.2, 0, 3.4), 0.0)
	_teil("Table", Vector3(-4.1, 0, 5.9), 0.0)
	_teil("Magazine", Vector3(-4.6, 1.05, 5.8), 20.0)
	_teil("Magazine", Vector3(-3.5, 1.05, 6.1), -35.0)
	_teil("Chair", Vector3(-9.2, 0, 6.8), 90.0)
	_teil("Chair", Vector3(-9.2, 0, 4.6), 90.0)
	_schild("WARTEBEREICH", Vector3(-4.1, 3.0, iz - 0.05), 180.0, 0.005, Color(0.7, 0.95, 1.0))
	_teil("Wheel_chair", Vector3(-12.6, 0, 7.8), 160.0)
	_teil("Wheel_chair", Vector3(-12.6, 0, 9.0), 150.0)
	_pflanze(Vector3(1.0, 0, 9.0))
	_pflanze(Vector3(-ix + 1.0, 0, 5.0))
	_notausgang(Vector3(-ix + 0.02, 2.9, 2.0), 90.0)
	_notausgang(Vector3(TUER_X + 2.4, 3.15, iz - 0.02), 180.0)
	# Untersuchungsraeume an der Rueckwand
	for i in 3:
		var x0 := U_RAEUME_X[i]
		var x1 := U_RAEUME_X[i + 1]
		var cx := (x0 + x1) * 0.5
		_innenwand(Vector2(x0, -iz), Vector2(x0, UNTERSUCHUNG_WAND_Z), 0)
		_zimmer_wand(x0, x1, UNTERSUCHUNG_WAND_Z, 0, "UNTERSUCHUNG %d" % (i + 1))
		_teil("Bed", Vector3(cx, 0, -iz + 1.75), 0.0)
		_teil("Iv_bag_holder", Vector3(cx + 1.3, 0, -iz + 1.0), 0.0)
		_teil("Cabinet_2", Vector3(cx - 1.5, 0, -iz + 0.5), 0.0)
		_teil("Chair", Vector3(cx - 1.3, 0, -iz + 3.9), 160.0)
		_box(Vector3(cx + 0.9, 1.3, -iz + 4.0), Vector3(0.4, 0.05, 0.4), m["weiss"], false)
	_innenwand(Vector2(U_RAEUME_X[3], -iz), Vector2(U_RAEUME_X[3], UNTERSUCHUNG_WAND_Z), 0)
	# Labor links neben den Untersuchungsraeumen
	var lx0 := -ix + treppe_b()
	_zimmer_wand(lx0, U_RAEUME_X[0], UNTERSUCHUNG_WAND_Z, 0, "LABOR")
	_innenwand(Vector2(U_RAEUME_X[0], -iz), Vector2(U_RAEUME_X[0], UNTERSUCHUNG_WAND_Z), 0)
	_teil("Cabinet_1", Vector3(-8.0, 0, -iz + 0.5), 0.0)
	_teil("Cabinet_1", Vector3(-5.0, 0, -iz + 0.5), 0.0)
	_teil("Cabinet_3", Vector3(-2.2, 0, -iz + 0.45), 0.0)
	_teil("Table", Vector3(-6.0, 0, -5.6), 0.0)
	_teil("Chair", Vector3(-4.2, 0, -5.4), 90.0)
	_teil("Iv_bag_holder", Vector3(-9.8, 0, -4.6), 0.0)
	_frosty("Misc_LaserBlender_Base", Vector3(-6.6, 1.05, -5.6))
	_frosty("Misc_BatteryCharger_X4_A", Vector3(-5.8, 1.05, -5.9))
	_frosty("Misc_CyberScreen_A", Vector3(-5.2, 1.05, -5.2), 90.0)
	_frosty("Misc_CableBox_01_A_Large", Vector3(-8.5, 1.5, -iz + 0.1))


func _station() -> void:
	var y := boden_y(1)
	var ix := innen_x()
	var iz := innen_z()
	_licht_set(1, 4, 2)
	_schild("STATION 2 // INNERE MEDIZIN", Vector3(3.0, y + 3.4, iz - 0.05), 180.0, 0.006, Color(0.7, 0.95, 1.0))
	# Patientenzimmer an der Rueckwand
	for i in 4:
		var x0 := ZIMMER_X[i]
		var x1 := ZIMMER_X[i + 1]
		var cx := (x0 + x1) * 0.5
		if i > 0:
			_innenwand(Vector2(x0, -iz), Vector2(x0, RAUM_WAND_Z), 1)
		_zimmer_wand(x0, x1, RAUM_WAND_Z, 1, "ZIMMER %d" % (201 + i))
		_teil("Bed", Vector3(cx, y, -iz + 1.75), 0.0)
		_teil("Iv_bag_holder", Vector3(cx + 1.4, y, -iz + 1.0), 0.0)
		_teil("Cabinet_3", Vector3(cx - 1.5, y, -iz + 0.5), 0.0)
		_teil("Chair", Vector3(cx + 1.8, y, -iz + 4.4), 200.0)
		_pflanze(Vector3(cx - 2.4, y, -iz + 5.2), 1.0)
		_frosty("Misc_HoloPlant_01" if i % 2 == 0 else "Misc_HoloPlant_02", Vector3(cx - 1.5, y + 0.79, -iz + 0.45))
		_frosty("Light_Wall_01_Blue", Vector3(cx, y + 2.6, -iz + 0.05), 0.0)
	# Stationstresen mit Telefon
	var th := _theke(Vector3(-1.0, y, 3.0), Vector3(6.0, 1.05, 1.0), 0.0, m["weiss"], m["stahl"])
	_box(Vector3(0.0, 1.27, 0.2), Vector3(0.6, 0.36, 0.03), m["dunkel"], false, th)
	_teil("Landline_phone", Vector3(-3.0, y + 1.05, 2.9), 0.0, false)
	_frosty("Misc_CyberScreen_A", Vector3(-2.4, y + 1.08, 3.1), 0.0)
	_frosty("Misc_Duckputer_C", Vector3(0.3, y + 1.08, 3.1), 0.0)
	_frosty("Misc_PinPad_B", Vector3(1.4, y + 1.08, 2.8), 0.0)
	_stuhl(Vector3(-1.0, y, 2.0), 180.0, m["dunkel"])
	_stuhl(Vector3(-2.4, y, 2.0), 180.0, m["dunkel"])
	_schild("STATIONSTRESEN", Vector3(-1.0, y + 2.6, 2.45), 0.0, 0.005, Color(0.7, 0.95, 1.0))
	# Aufenthaltsbereich rechts vorn
	_teil("Table", Vector3(11.0, y, 6.0), 0.0)
	_teil("Chair", Vector3(9.2, y, 6.0), -90.0)
	_teil("Chair", Vector3(12.8, y, 6.0), 90.0)
	_teil("Magazine", Vector3(10.3, y + 1.05, 6.0), 10.0, false)
	_frosty("Misc_PizzaBox_01", Vector3(11.4, y + 1.05, 6.2), 25.0)
	_frosty("Misc_BeverageCan_01", Vector3(11.9, y + 1.05, 5.5))
	_frosty("Misc_BeverageCan_02_Crushed_A", Vector3(11.0, y + 1.05, 5.5), 40.0)
	_teil("Bench", Vector3(6.0, y, 8.6), 180.0)
	_teil("Wheel_chair", Vector3(-6.0, y, 8.6), 170.0)
	_teil("Wheel_chair", Vector3(-7.4, y, 8.6), 185.0)
	_teil("Cabinet_1", Vector3(-9.0, y, 9.0), 180.0)
	_pflanze(Vector3(14.6, y, 8.6))
	_pflanze(Vector3(-4.0, y, 8.8))
	_notausgang(Vector3(-ix + treppe_b() + 0.02, y + 2.9, 3.0), 90.0)
	_notausgang(Vector3(ix - 0.02, y + 2.9, 3.0), -90.0)
