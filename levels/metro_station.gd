extends Node3D
## U-Bahn-Station der Linie M1 (levels/metro.gd baut zwei davon). Cyber-Look: dunkle Halle, Neonkanten,
## Bahnsteigtueren aus Glas, Abfahrtstafel; Wandverkleidung, Saeulen und Kleinkram aus "PixelDrift Metro Free"
## (levels/metro_paket.gd).
## Lokale Achsen: Ursprung = Schienenoberkante in Hallenmitte, Gleis entlang x (Gleismitte z 0), Bahnsteig bei -z.
## Das Tunnelende liegt immer bei -x, das Prellbock-Ende bei +x. Die Treppe zur Oberflaeche liegt hinter der
## Nordwand (-z) und steigt Richtung treppe_richtung * x an; oben ein Kiosk mit Vordach und Plattform.
## Exportiert: stationsname, ziel_name, treppe_richtung (+1/-1), tuer_x (x der Zugtueren bei Halt),
## linien_farbe, oberflaeche_y (Strassenniveau ueber der Schiene).
## Methoden: anzeige_setzen(), bahnsteigtueren_setzen(), im_bereich(), eingang_global(), static oeffnung_lokal() usw.
## Keine Signale.

const MP := preload("res://levels/metro_paket.gd")
const NEON := preload("res://ui/neon.gd")

@export var stationsname := "STATION"
@export var ziel_name := "ZIEL"
@export var treppe_richtung := 1.0
@export var tuer_x: Array[float] = [-11.0, -4.0, 4.0, 11.0]
@export var linien_farbe := Color(0.1, 0.95, 1.0)
@export var oberflaeche_y := 15.0

const HALLE_X := 35.0              ## halbe Hallenlaenge
const BETT_Y := -0.3               ## Gleisbett
const BODEN_U := -0.6
const BAHNSTEIG_Y := 1.1           ## = Fussboden des Zugs
const KANTE_Z := -1.6              ## Bahnsteigkante
const NORD_Z := -10.0              ## Innenseite Nordwand
const SUED_Z := 3.4                ## Innenseite Suedwand (Gleisseite)
const DECKE_Y := 9.1
const WAND_D := 0.4
const TUNNEL_HALB := 3.4           ## halbe Tunnelbreite, = metro.gd
const TUNNEL_H := 6.6
## Bahnsteigtueren
const PSD_Z := -1.75
const PSD_H := 2.3
const PSD_TUER_B := 1.8
const PSD_ZEIT := 0.9
## Treppe (alle x-Werte mit treppe_richtung multipliziert)
const TUER_X0 := 12.0              ## Durchgang Halle -> Treppenpodest
const TUER_X1 := 15.0
const TUER_H := 3.2
const TREPPE_Z0 := -10.4           ## Innenflaechen des Treppenschachts
const TREPPE_Z1 := -14.4
const TREPPE_UNTEN_X := 15.0
const TREPPE_OBEN_X := 39.5
const KOPF := 3.6                  ## lichte Hoehe ueber den Stufen
const DECKE_D := 0.3
const STUFE_H := 0.17
const STUFE_T := 0.30
const GELAENDER_H := 1.1
const KIOSK_RAND := 5.0            ## Plattform oben: so weit ueber die Oeffnung hinaus
const KIOSK_DACH_H := 3.4
const LICHT_WEISS := Color(0.8, 0.9, 1.0)
const SAEULE_SCHMAL := 0.4

var _m: Dictionary = {}
var _psd: Array = []               ## je Tuer: [linkes Blatt, rechtes Blatt, Kollision, Mitte x]
var _psd_offen := 0.0
var _psd_soll := 0.0
var _tafel: Label3D
var _tafel2: Label3D


func _ready() -> void:
	_materialien()
	_halle()
	_bahnsteigtueren()
	_treppe()
	_kiosk()
	_ausstattung()
	_schilder()


# ---------------------------------------------------------------- Geometrie fuer metro.gd und stadt.gd

static func _steigung() -> float:
	return STUFE_H / STUFE_T   ## Hoehe pro Lauf (rund 30 Grad)


## Lauf der Treppe ab der Oberkante, bis zu dem die Treppendecke ueber die Oberflaeche ragt (offener Teil).
static func oeffnung_lauf(oberflaeche: float) -> float:
	var stufe_max := oberflaeche - KOPF - DECKE_D - 0.1
	return (oberflaeche - stufe_max) / _steigung()


## Offener Treppenteil (Loch in Platte/Gelaende) als lokales x/z-Rechteck.
static func oeffnung_lokal(richtung: float, oberflaeche: float) -> Rect2:
	var x_oben := TREPPE_OBEN_X * richtung
	var x_kante := (TREPPE_OBEN_X - oeffnung_lauf(oberflaeche)) * richtung
	return Rect2(minf(x_oben, x_kante), TREPPE_Z1, absf(x_oben - x_kante), TREPPE_Z0 - TREPPE_Z1)


## Teil der Treppe, dessen Decke ueber die lokale Hoehe y ragt (fuer Loecher in Sohle und Gelaende unter der Platte).
static func durchstich_lokal(richtung: float, oberflaeche: float, y: float) -> Rect2:
	var lauf := (oberflaeche - (y - KOPF - DECKE_D)) / _steigung()
	var x_oben := (TREPPE_OBEN_X + 0.5) * richtung
	var x_kante := (TREPPE_OBEN_X - lauf) * richtung
	return Rect2(minf(x_oben, x_kante), TREPPE_Z1 - WAND_D, absf(x_oben - x_kante), TREPPE_Z0 - TREPPE_Z1 + 2.0 * WAND_D)


## Kiosk-Plattform (deckt Gelaendeloecher am Rand ab).
static func kiosk_lokal(richtung: float, oberflaeche: float) -> Rect2:
	return oeffnung_lokal(richtung, oberflaeche).grow(KIOSK_RAND)


# ---------------------------------------------------------------- Helfer

func _std(c: Color, metall := 0.3, rauh := 0.6, leuchten := 0.0) -> StandardMaterial3D:
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
	_m["boden"] = _std(Color(0.09, 0.1, 0.13), 0.5, 0.35)
	_m["bett"] = _std(Color(0.05, 0.05, 0.06), 0.1, 0.9)
	_m["wand"] = _std(Color(0.08, 0.09, 0.12), 0.4, 0.6)
	_m["decke"] = _std(Color(0.04, 0.045, 0.06), 0.2, 0.8)
	_m["stahl"] = _std(Color(0.35, 0.37, 0.42), 0.9, 0.3)
	_m["linie"] = _std(linien_farbe, 0.0, 0.4, 2.5)
	_m["pink"] = _std(Color(1.0, 0.15, 0.7), 0.0, 0.4, 2.5)
	_m["gelb"] = _std(Color(1.0, 0.8, 0.1), 0.0, 0.5, 0.8)
	_m["tafel"] = _std(Color(0.02, 0.03, 0.05), 0.5, 0.3)
	var glas := _std(Color(0.4, 0.75, 0.95), 0.0, 0.05, 0.05)
	glas.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glas.albedo_color.a = 0.12
	glas.cull_mode = BaseMaterial3D.CULL_DISABLED
	_m["glas"] = glas


func _box(mitte: Vector3, g: Vector3, mat: Material, kol := true, eltern: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = g
	mi.mesh = bm
	mi.material_override = mat
	mi.position = mitte
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(eltern if eltern != null else self).add_child(mi)
	if kol:
		_kol(mitte, g, Vector3.ZERO, eltern)
	return mi


func _kol(mitte: Vector3, g: Vector3, drehung := Vector3.ZERO, eltern: Node3D = null) -> CollisionShape3D:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = g
	cs.shape = sh
	sb.add_child(cs)
	sb.position = mitte
	sb.rotation = drehung
	(eltern if eltern != null else self).add_child(sb)
	return cs


## Quader zwischen zwei x-Werten (beliebige Reihenfolge).
func _box_x(x0: float, x1: float, y0: float, y1: float, z0: float, z1: float, mat: Material, kol := true) -> void:
	_box(Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5), Vector3(absf(x1 - x0), absf(y1 - y0), absf(z1 - z0)), mat, kol)


func _licht(pos: Vector3, farbe: Color, energie: float, reichweite: float) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = farbe
	l.light_energy = energie
	l.omni_range = reichweite
	l.shadow_enabled = false
	add_child(l)


func _text(txt: String, pos: Vector3, farbe: Color, pixel: float, drehung := 0.0, groesse := 64) -> Label3D:
	var l := Label3D.new()
	l.text = txt
	l.font = NEON.font()
	l.font_size = groesse
	l.pixel_size = pixel
	l.modulate = farbe
	l.outline_size = 8
	l.outline_modulate = Color(0.0, 0.02, 0.06)
	l.shaded = false
	l.position = pos
	l.rotation_degrees.y = drehung
	add_child(l)
	return l


func _teil(name_: String, pos: Vector3, drehung := 0.0) -> Node3D:
	var n := MP.laden(name_)
	n.position = pos
	n.rotation_degrees.y = drehung
	add_child(n)
	return n


# ---------------------------------------------------------------- Halle

func _halle() -> void:
	var d := treppe_richtung
	var tx0 := minf(TUER_X0 * d, TUER_X1 * d)
	var tx1 := maxf(TUER_X0 * d, TUER_X1 * d)
	# Gleisbett, Bahnsteig, Decke
	_box_x(-HALLE_X, HALLE_X, BODEN_U, BETT_Y, KANTE_Z, SUED_Z, _m["bett"])
	_box_x(-HALLE_X, HALLE_X, BODEN_U, BAHNSTEIG_Y, NORD_Z, KANTE_Z, _m["boden"])
	_box_x(-HALLE_X, HALLE_X, DECKE_Y, DECKE_Y + 0.4, NORD_Z - WAND_D, SUED_Z + WAND_D, _m["decke"])
	# Nordwand mit Durchgang zur Treppe
	_box_x(-HALLE_X, tx0, BODEN_U, DECKE_Y, NORD_Z - WAND_D, NORD_Z, _m["wand"])
	_box_x(tx1, HALLE_X, BODEN_U, DECKE_Y, NORD_Z - WAND_D, NORD_Z, _m["wand"])
	_box_x(tx0, tx1, BAHNSTEIG_Y + TUER_H, DECKE_Y, NORD_Z - WAND_D, NORD_Z, _m["wand"])
	# Neonrahmen um den Durchgang
	_box_x(tx0 - 0.1, tx1 + 0.1, BAHNSTEIG_Y + TUER_H, BAHNSTEIG_Y + TUER_H + 0.12, NORD_Z + 0.01, NORD_Z + 0.06, _m["linie"], false)
	for x: float in [tx0 - 0.05, tx1 + 0.05]:
		_box_x(x - 0.06, x + 0.06, BAHNSTEIG_Y, BAHNSTEIG_Y + TUER_H, NORD_Z + 0.01, NORD_Z + 0.06, _m["linie"], false)
	# Suedwand (hinter dem Gleis) und Stirnwaende; am Tunnelende bleibt das Tunnelprofil offen
	_box_x(-HALLE_X, HALLE_X, BODEN_U, DECKE_Y, SUED_Z, SUED_Z + WAND_D, _m["wand"])
	_box_x(HALLE_X, HALLE_X + WAND_D, BODEN_U, DECKE_Y, NORD_Z - WAND_D, SUED_Z + WAND_D, _m["wand"])
	_box_x(-HALLE_X - WAND_D, -HALLE_X, BODEN_U, DECKE_Y, NORD_Z - WAND_D, -TUNNEL_HALB, _m["wand"])
	_box_x(-HALLE_X - WAND_D, -HALLE_X, BETT_Y + TUNNEL_H, DECKE_Y, -TUNNEL_HALB, SUED_Z + WAND_D, _m["wand"])
	# Unsichtbare Sperre im Tunnelmund (der Zug faehrt kinematisch hindurch)
	_kol(Vector3(-HALLE_X - 0.6, BETT_Y + TUNNEL_H * 0.5, 0.0), Vector3(0.4, TUNNEL_H, TUNNEL_HALB * 2.0))
	# Neonkanten: Bahnsteigkante (gelb, Linienfarbe), Deckenkanten
	_box_x(-HALLE_X, HALLE_X, BAHNSTEIG_Y, BAHNSTEIG_Y + 0.01, KANTE_Z - 0.75, KANTE_Z - 0.45, _m["gelb"], false)
	_box_x(-HALLE_X, HALLE_X, BAHNSTEIG_Y - 0.25, BAHNSTEIG_Y - 0.05, KANTE_Z - 0.02, KANTE_Z + 0.02, _m["linie"], false)
	for z: float in [NORD_Z + 0.05, SUED_Z - 0.05]:
		_box_x(-HALLE_X, HALLE_X, DECKE_Y - 0.2, DECKE_Y - 0.08, z - 0.04, z + 0.04, _m["pink"], false)
	# Deckenleisten quer (alle 5 m)
	var x := -HALLE_X + 2.5
	while x < HALLE_X:
		_box(Vector3(x, DECKE_Y - 0.05, (NORD_Z + SUED_Z) * 0.5), Vector3(0.2, 0.08, SUED_Z - NORD_Z - 0.4), _m["linie"], false)
		x += 5.0
	for lx: float in [-24.0, -8.0, 8.0, 24.0]:
		_licht(Vector3(lx, DECKE_Y - 1.5, -5.5), LICHT_WEISS, 2.2, 16.0)
	_licht(Vector3(0, 4.0, 1.5), linien_farbe, 1.0, 18.0)


# ---------------------------------------------------------------- Bahnsteigtueren

func _bahnsteigtueren() -> void:
	var luecken: Array[float] = []
	for t in tuer_x:
		luecken.append(t)
	luecken.sort()
	var y0 := BAHNSTEIG_Y
	var ym := y0 + PSD_H * 0.5
	var x0 := -HALLE_X
	for t in luecken:
		_psd_wand(x0, t - PSD_TUER_B * 0.5)
		x0 = t + PSD_TUER_B * 0.5
		var blaetter: Array[MeshInstance3D] = []
		for s: float in [-1.0, 1.0]:
			blaetter.append(_box(Vector3(t + s * PSD_TUER_B * 0.25, ym, PSD_Z), Vector3(PSD_TUER_B * 0.5, PSD_H, 0.05), _m["glas"], false))
		var kol := _kol(Vector3(t, ym, PSD_Z), Vector3(PSD_TUER_B, PSD_H, 0.15))
		_box(Vector3(t, y0 + PSD_H + 0.15, PSD_Z), Vector3(PSD_TUER_B, 0.12, 0.12), _m["pink"], false)
		_psd.append([blaetter[0], blaetter[1], kol, t])
	_psd_wand(x0, HALLE_X)


func _psd_wand(x0: float, x1: float) -> void:
	if x1 - x0 < 0.05:
		return
	var ym := BAHNSTEIG_Y + PSD_H * 0.5
	_box(Vector3((x0 + x1) * 0.5, ym, PSD_Z), Vector3(x1 - x0, PSD_H, 0.05), _m["glas"], false)
	_kol(Vector3((x0 + x1) * 0.5, ym, PSD_Z), Vector3(x1 - x0, PSD_H, 0.15))
	_box(Vector3((x0 + x1) * 0.5, BAHNSTEIG_Y + PSD_H + 0.15, PSD_Z), Vector3(x1 - x0, 0.12, 0.12), _m["linie"], false)
	_box(Vector3((x0 + x1) * 0.5, BAHNSTEIG_Y + 0.05, PSD_Z), Vector3(x1 - x0, 0.1, 0.14), _m["stahl"], false)


func bahnsteigtueren_setzen(offen: bool) -> void:
	_psd_soll = 1.0 if offen else 0.0


func _process(delta: float) -> void:
	if _psd_offen == _psd_soll:
		return
	_psd_offen = move_toward(_psd_offen, _psd_soll, delta / PSD_ZEIT)
	for p in _psd:
		var t: float = p[3]
		var weg := PSD_TUER_B * 0.5 * _psd_offen
		(p[0] as Node3D).position.x = t - PSD_TUER_B * 0.25 - weg
		(p[1] as Node3D).position.x = t + PSD_TUER_B * 0.25 + weg
		(p[2] as CollisionShape3D).disabled = _psd_offen > 0.5


# ---------------------------------------------------------------- Treppe

func _treppe() -> void:
	var d := treppe_richtung
	var zm := (TREPPE_Z0 + TREPPE_Z1) * 0.5
	var breite := TREPPE_Z0 - TREPPE_Z1
	var steig := _steigung()
	var hoehe := oberflaeche_y - BAHNSTEIG_Y
	var lauf := hoehe / steig
	var x_unten := TREPPE_UNTEN_X * d
	var x_oben := x_unten + lauf * d
	# Podest unten (bis zum Durchgang) mit Decke
	_box_x(TUER_X0 * d, x_unten, BODEN_U, BAHNSTEIG_Y, TREPPE_Z1, TREPPE_Z0, _m["boden"])
	_box_x(TUER_X0 * d - 0.4 * d, x_unten, BAHNSTEIG_Y + KOPF, BAHNSTEIG_Y + KOPF + DECKE_D, TREPPE_Z1 - WAND_D, TREPPE_Z0 + WAND_D, _m["decke"])
	_box_x(TUER_X0 * d - 0.4 * d, TUER_X0 * d, BODEN_U, BAHNSTEIG_Y + KOPF, TREPPE_Z1, NORD_Z - WAND_D, _m["wand"])
	# Rampe als Kollision, Stufen als MultiMesh (Trittflaeche plus Leuchtkante)
	var winkel := atan(steig)
	var schraeg := sqrt(lauf * lauf + hoehe * hoehe)
	var rampe_mitte := Vector3((x_unten + x_oben) * 0.5, (BAHNSTEIG_Y + oberflaeche_y) * 0.5 - 0.15 / cos(winkel), zm)
	_kol(rampe_mitte, Vector3(schraeg, 0.3, breite), Vector3(0, 0, winkel * d))
	var stufen := int(round(hoehe / STUFE_H))
	var tiefe := lauf / stufen
	var tritte: Array[Transform3D] = []
	var kanten: Array[Transform3D] = []
	for i in stufen:
		var y := BAHNSTEIG_Y + (i + 1) * hoehe / stufen
		var x := x_unten + (i + 0.5) * tiefe * d
		tritte.append(Transform3D(Basis.from_scale(Vector3(tiefe + 0.01, y - BAHNSTEIG_Y + 0.02, breite)), Vector3(x, (y + BAHNSTEIG_Y) * 0.5 - 0.01, zm)))
		kanten.append(Transform3D(Basis.from_scale(Vector3(0.05, 0.02, breite - 0.2)), Vector3(x - tiefe * 0.5 * d + 0.03 * d, y + 0.005, zm)))
	_multimesh(tritte, _m["boden"])
	_multimesh(kanten, _m["linie"])
	# Schachtwaende, schraege Decke (nur der geschlossene Teil), Handlaeufe als Neonband
	var offen := oeffnung_lauf(oberflaeche_y)
	var x_deckenende := x_oben - offen * d
	_box_x(TUER_X0 * d, x_oben + 0.4 * d, BODEN_U, oberflaeche_y, TREPPE_Z1 - WAND_D, TREPPE_Z1, _m["wand"])
	_box_x(x_unten, x_oben + 0.4 * d, BODEN_U, oberflaeche_y, TREPPE_Z0, TREPPE_Z0 + WAND_D, _m["wand"])
	_box_x(x_oben, x_oben + 0.4 * d, BAHNSTEIG_Y, oberflaeche_y, TREPPE_Z1, TREPPE_Z0, _m["wand"], false)
	var decke_lauf := absf(x_deckenende - x_unten)
	var decke_mitte := Vector3((x_unten + x_deckenende) * 0.5, BAHNSTEIG_Y + KOPF + decke_lauf * steig * 0.5 + DECKE_D * 0.5, zm)
	var decke := _box(decke_mitte, Vector3(decke_lauf / cos(winkel), DECKE_D, breite + 2.0 * WAND_D), _m["decke"], false)
	decke.rotation.z = winkel * d
	_kol(decke_mitte, Vector3(decke_lauf / cos(winkel), DECKE_D, breite + 2.0 * WAND_D), Vector3(0, 0, winkel * d))
	for z: float in [TREPPE_Z0 - 0.08, TREPPE_Z1 + 0.08]:
		var h := _box(Vector3((x_unten + x_oben) * 0.5, (BAHNSTEIG_Y + oberflaeche_y) * 0.5 + 1.0, z), Vector3(schraeg, 0.06, 0.06), _m["linie"], false)
		h.rotation.z = winkel * d
	# Lichter im Schacht
	for k in 3:
		var t := (k + 0.5) / 3.0
		_licht(Vector3(lerpf(x_unten, x_oben, t), lerpf(BAHNSTEIG_Y, oberflaeche_y, t) + 2.5, zm), LICHT_WEISS, 1.0, 9.0)


func _multimesh(trafos: Array[Transform3D], mat: Material) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var bm := BoxMesh.new()
	mm.mesh = bm
	mm.instance_count = trafos.size()
	for i in trafos.size():
		mm.set_instance_transform(i, trafos[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


# ---------------------------------------------------------------- Kiosk an der Oberflaeche

func _kiosk() -> void:
	var d := treppe_richtung
	var o := oeffnung_lokal(d, oberflaeche_y)
	var k := kiosk_lokal(d, oberflaeche_y)
	var y := oberflaeche_y
	# Plattform (vier Streifen um die Oeffnung), Neonrand
	for r: Rect2 in [Rect2(k.position.x, k.position.y, k.size.x, o.position.y - k.position.y),
			Rect2(k.position.x, o.end.y, k.size.x, k.end.y - o.end.y),
			Rect2(k.position.x, o.position.y, o.position.x - k.position.x, o.size.y),
			Rect2(o.end.x, o.position.y, k.end.x - o.end.x, o.size.y)]:
		if r.size.x > 0.01 and r.size.y > 0.01:
			_box(Vector3(r.get_center().x, y - 0.04, r.get_center().y), Vector3(r.size.x, 0.2, r.size.y), _m["boden"])
	for z: float in [k.position.y, k.end.y]:
		_box(Vector3(k.get_center().x, y + 0.065, z), Vector3(k.size.x, 0.02, 0.15), _m["linie"], false)
	for x: float in [k.position.x, k.end.x]:
		_box(Vector3(x, y + 0.065, k.get_center().y), Vector3(0.15, 0.02, k.size.y), _m["linie"], false)
	# Gelaender an den Laengsseiten und an der Deckenkante, offen am oberen Treppenende
	var x_kante := (TREPPE_OBEN_X - oeffnung_lauf(oberflaeche_y)) * d
	for z: float in [o.position.y - 0.05, o.end.y + 0.05]:
		_box(Vector3(o.get_center().x, y + GELAENDER_H * 0.5, z), Vector3(o.size.x, GELAENDER_H, 0.08), _m["glas"])
		_box(Vector3(o.get_center().x, y + GELAENDER_H, z), Vector3(o.size.x, 0.06, 0.12), _m["linie"], false)
	_box(Vector3(x_kante - 0.05 * d, y + GELAENDER_H * 0.5, o.get_center().y), Vector3(0.08, GELAENDER_H, o.size.y), _m["glas"])
	_box(Vector3(x_kante - 0.05 * d, y + GELAENDER_H, o.get_center().y), Vector3(0.12, 0.06, o.size.y), _m["linie"], false)
	# Vordach auf vier Stuetzen
	var dach := o.grow(1.2)
	for p: Vector2 in [dach.position, Vector2(dach.end.x, dach.position.y), dach.end, Vector2(dach.position.x, dach.end.y)]:
		_box(Vector3(p.x, y + KIOSK_DACH_H * 0.5, p.y), Vector3(0.18, KIOSK_DACH_H, 0.18), _m["stahl"])
	_box(Vector3(dach.get_center().x, y + KIOSK_DACH_H + 0.1, dach.get_center().y), Vector3(dach.size.x, 0.2, dach.size.y), _m["tafel"], false)
	_box(Vector3(dach.get_center().x, y + KIOSK_DACH_H - 0.02, dach.get_center().y), Vector3(dach.size.x - 0.6, 0.04, dach.size.y - 0.6), _m["linie"], false)
	_licht(Vector3(o.get_center().x, y + KIOSK_DACH_H - 0.6, o.get_center().y), linien_farbe, 1.2, 10.0)
	# Pylon mit M1-Logo neben dem Eingang
	var pylon := Vector3((TREPPE_OBEN_X + 2.2) * d, y, o.position.y - 1.2)
	_box(pylon + Vector3(0, 2.6, 0), Vector3(0.9, 5.2, 0.5), _m["tafel"])
	_box(pylon + Vector3(0, 4.6, 0), Vector3(1.1, 1.1, 0.55), _m["linie"], false)
	for s: float in [-1.0, 1.0]:
		_text("M1", pylon + Vector3(0, 4.6, s * 0.3), Color(0.02, 0.03, 0.06), 0.012, 0.0 if s > 0.0 else 180.0, 72)
		_text("METRO", pylon + Vector3(0, 3.4, s * 0.27), linien_farbe, 0.008, 0.0 if s > 0.0 else 180.0, 48)
	var schild_dreh := 90.0 if d > 0.0 else -90.0
	_text("METRO M1 · %s" % stationsname, Vector3((TREPPE_OBEN_X + 1.25) * d, y + KIOSK_DACH_H + 0.45, o.get_center().y), linien_farbe, 0.009, schild_dreh, 48)


# ---------------------------------------------------------------- Ausstattung (PixelDrift Metro Free)

func _ausstattung() -> void:
	var d := treppe_richtung
	var tx0 := minf(TUER_X0 * d, TUER_X1 * d)
	var tx1 := maxf(TUER_X0 * d, TUER_X1 * d)
	# Wandverkleidung aus 10-m-Wandteilen an Nord- und Suedwand, Saeulen dazwischen
	var x := -HALLE_X
	while x < HALLE_X - 0.1:
		if not (x < tx1 and x + 10.0 > tx0):
			_teil("FPS_Wall_Main_01b", Vector3(x, BAHNSTEIG_Y, NORD_Z + 0.02))
		_teil("FPS_Wall_Main_01b", Vector3(x, BETT_Y, SUED_Z - 0.02))
		x += 10.0
	for sx: float in [-25.0, -5.0, 25.0]:
		if sx > tx0 - 2.0 and sx < tx1 + 2.0:
			continue
		# Pfeiler-Vorlage ist 3 x 3 m; als Wandpfeiler auf SAEULE_SCHMAL verschlankt
		var s := _teil("Arch_Wall_Column_01a", Vector3(sx, BAHNSTEIG_Y, NORD_Z + 0.4))
		s.scale = Vector3(s.scale.x * SAEULE_SCHMAL, s.scale.y * (DECKE_Y - BAHNSTEIG_Y) / 8.0, s.scale.z * SAEULE_SCHMAL)
		_kol(Vector3(sx, (BAHNSTEIG_Y + DECKE_Y) * 0.5, NORD_Z + 0.4), Vector3(1.2, DECKE_Y - BAHNSTEIG_Y, 0.9))
		_box(Vector3(sx, (BAHNSTEIG_Y + DECKE_Y) * 0.5, NORD_Z + 1.0), Vector3(0.08, DECKE_Y - BAHNSTEIG_Y - 1.0, 0.04), _m["pink"], false)
	# Getraenkeautomaten, Kisten, Feuerloescher, Kabelkasten, Neonleuchten, Rohre
	for ax: float in [-17.0, -15.6]:
		var a := _teil("GroundDecor_Props_SodaBox_01a", Vector3(ax * d, BAHNSTEIG_Y, NORD_Z + 0.7), 0.0)
		_kol(Vector3(ax * d, BAHNSTEIG_Y + 1.0, NORD_Z + 0.7), Vector3(1.2, 2.0, 1.0))
		a.name = "Automat"
	_teil("GroundDecor_Props_Box_T2_01a", Vector3(30.0, BAHNSTEIG_Y, NORD_Z + 1.2), 20.0)
	_teil("GroundDecor_Props_Box_T2_01b", Vector3(31.8, BAHNSTEIG_Y, NORD_Z + 1.0), -10.0)
	_kol(Vector3(31.0, BAHNSTEIG_Y + 1.0, NORD_Z + 1.2), Vector3(4.0, 2.0, 2.2))
	for fx: float in [-24.0, 6.0 * -d, 26.0]:
		_teil("WallDecor_Props_fireExt", Vector3(fx, BAHNSTEIG_Y + 1.2, NORD_Z + 0.05))
	_teil("WallDecor_Electric_CabbleBox_01a", Vector3(-31.0, BAHNSTEIG_Y, NORD_Z + 0.35))
	for nx: float in [-30.0, -10.0, 10.0, 30.0]:
		if nx > tx0 - 3.0 and nx < tx1 + 3.0:
			continue
		_teil("WallDecor_Light_neon_01f", Vector3(nx, DECKE_Y - 1.4, NORD_Z + 0.05))
	_teil("WallDecor_Pipe_Seam_01b", Vector3(-25.0, DECKE_Y - 0.8, SUED_Z - 0.3))
	_teil("WallDecor_Pipe_Seam_01b", Vector3(-5.0, DECKE_Y - 0.8, SUED_Z - 0.3))
	_teil("WallDecor_Pipe_Seam_01b", Vector3(15.0, DECKE_Y - 0.8, SUED_Z - 0.3))
	_teil("Ground_WorksPlace_Ladder_02a", Vector3(HALLE_X - 0.6, BETT_Y, 1.5), -90.0)
	_teil("WallDecor_Entry_Door_01c", Vector3(HALLE_X - 0.05, BAHNSTEIG_Y, -6.0), -90.0)
	# Sitzbaenke (eigene Form, im Paket fehlen sie)
	for bx: float in [-22.0, -8.0, 20.0]:
		_box(Vector3(bx, BAHNSTEIG_Y + 0.45, NORD_Z + 2.4), Vector3(3.0, 0.1, 0.7), _m["stahl"])
		_box(Vector3(bx, BAHNSTEIG_Y + 0.2, NORD_Z + 2.4), Vector3(2.8, 0.4, 0.5), _m["wand"], false)
		_box(Vector3(bx, BAHNSTEIG_Y + 0.42, NORD_Z + 2.76), Vector3(3.0, 0.03, 0.05), _m["linie"], false)
	# Prellbock am Gleisende
	_box(Vector3(HALLE_X - 1.2, BETT_Y + 0.6, 0.0), Vector3(1.0, 1.2, 2.6), _m["stahl"])
	_box(Vector3(HALLE_X - 1.75, BETT_Y + 0.9, 0.0), Vector3(0.1, 0.4, 2.4), _m["pink"], false)


func _schilder() -> void:
	# Stationsname an der Suedwand (vom Bahnsteig ueber das Gleis lesbar), Linienband darunter
	for sx: float in [-18.0, 18.0]:
		_box(Vector3(sx, 6.4, SUED_Z - 0.08), Vector3(16.0, 1.6, 0.06), _m["tafel"], false)
		_box(Vector3(sx, 5.55, SUED_Z - 0.1), Vector3(16.0, 0.08, 0.04), _m["linie"], false)
		_text(stationsname, Vector3(sx, 6.4, SUED_Z - 0.12), Color(0.9, 0.97, 1.0), 0.012, 180.0, 72)
	# Haengende Abfahrtstafel ueber dem Bahnsteig (beidseitig)
	var t := Vector3(-2.0, DECKE_Y - 2.2, -5.5)
	_box(t, Vector3(6.0, 1.3, 0.2), _m["tafel"], false)
	for s: float in [-1.0, 1.0]:
		_box(t + Vector3(s * 2.6, 1.0, 0), Vector3(0.05, 0.9, 0.05), _m["stahl"], false)
	_tafel = _text("", t + Vector3(0, 0.25, 0.11), Color(1.0, 0.8, 0.25), 0.006, 0.0, 48)
	_tafel2 = _text("", t + Vector3(0, -0.25, 0.11), linien_farbe, 0.005, 0.0, 40)
	var hinten := _text("", t + Vector3(0, 0.25, -0.11), Color(1.0, 0.8, 0.25), 0.006, 180.0, 48)
	var hinten2 := _text("", t + Vector3(0, -0.25, -0.11), linien_farbe, 0.005, 180.0, 40)
	_tafel.set_meta("zwilling", hinten)
	_tafel2.set_meta("zwilling", hinten2)
	# Linienplan an der Nordwand: zwei Stationen, Leuchtlinie
	var plan := Vector3(-8.0 * treppe_richtung, 4.6, NORD_Z + 0.08)
	_box(plan, Vector3(7.0, 2.2, 0.04), _m["tafel"], false)
	_box(plan + Vector3(0, -0.1, 0.03), Vector3(5.4, 0.1, 0.02), _m["linie"], false)
	_text("LINIE M1", plan + Vector3(0, 0.75, 0.04), linien_farbe, 0.006, 0.0, 48)
	var namen := [stationsname, ziel_name]
	for i in 2:
		var px := (-2.7 if i == 0 else 2.7) * treppe_richtung
		_box(plan + Vector3(px, -0.1, 0.04), Vector3(0.35, 0.35, 0.03), _m["pink"] if i == 0 else _m["gelb"], false)
		_text(String(namen[i]), plan + Vector3(px, -0.55, 0.04), Color(0.9, 0.95, 1.0), 0.004, 0.0, 40)
	_text("SIE SIND HIER", plan + Vector3(-2.7 * treppe_richtung, 0.3, 0.04), Color(1.0, 0.3, 0.75), 0.0035, 0.0, 40)


## Zwei Zeilen auf der Abfahrtstafel.
func anzeige_setzen(zeile1: String, zeile2: String) -> void:
	if _tafel == null:
		return
	_tafel.text = zeile1
	_tafel2.text = zeile2
	(_tafel.get_meta("zwilling") as Label3D).text = zeile1
	(_tafel2.get_meta("zwilling") as Label3D).text = zeile2


## Liegt ein Weltpunkt in Halle oder Treppenschacht dieser Station?
func im_bereich(p: Vector3) -> bool:
	var l := to_local(p)
	if l.y < BODEN_U or l.y > oberflaeche_y + 3.0:
		return false
	if absf(l.x) <= HALLE_X and l.z >= NORD_Z and l.z <= SUED_Z:
		return true
	var x0 := minf(TUER_X0 * treppe_richtung, (TREPPE_OBEN_X + 1.0) * treppe_richtung)
	var x1 := maxf(TUER_X0 * treppe_richtung, (TREPPE_OBEN_X + 1.0) * treppe_richtung)
	return l.x >= x0 and l.x <= x1 and l.z <= TREPPE_Z0 and l.z >= TREPPE_Z1


## Eingang oben (Weltkoordinaten, Mitte der Treppenoeffnung).
func eingang_global() -> Vector3:
	var o := oeffnung_lokal(treppe_richtung, oberflaeche_y)
	return to_global(Vector3(o.get_center().x, oberflaeche_y, o.get_center().y))
