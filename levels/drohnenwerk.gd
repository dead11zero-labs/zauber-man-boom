extends Node3D
## Drohnenwerk: Maschinen und Drohnen der Drohnen-Fertigung im Untergrund (levels/untergrund.gd baut Raeume und
## Waende, dieser Knoten nur die Einrichtung). Alle Bereiche kommen als Rechtecke im Raum des Untergrund-Knotens.
## Montagehalle: zwei Foerderbaender (Linie 1 Rahmen nach Osten, Linie 2 fertige Drohnen nach Westen) mit
##   Durchlauf-Portalen an den Enden und je drei Roboterarmen (Schweisslicht).
## Hangar: Ladegestelle an der Nordwand (MultiMesh), Haengebahn mit fertigen Drohnen (West),
##   Testflug-Kaefig mit kreisenden Drohnen (Ost), Startplattform mit steigender Drohne (Mitte), Werksschild.
## Ladestation: Wandgestelle mit ladenden Drohnen (pulsierende LEDs).
## Animiert wird nur, solange der Knoten sichtbar ist (untergrund.gd blendet den Komplex oben in der Stadt aus).
## Exportiert: boden_y, hangar, hangar_h, halle, halle_h, ladestation. Keine Signale.

const DM := preload("res://levels/drohnen_modell.gd")

@export var boden_y := -16.0
@export var hangar := Rect2(-36, -96, 72, 28)
@export var hangar_h := 11.15
@export var halle := Rect2(-28, -64, 56, 36)
@export var halle_h := 8.1
@export var ladestation := Rect2(16, -20, 16, 16)

const WAND_INNEN := 0.5               ## sichtbare Wandflaeche liegt so weit innerhalb der Zellkante
## Foerderbaender (Montagehalle): Abstand der Bandmitte von der Nordkante der Halle, Laenge, Hoehe, Breite
const BAND_Z: Array[float] = [9.0, 21.0]
const BAND_LAENGE := 44.0
const BAND_HOEHE := 0.9
const BAND_BREITE := 1.6
const BAND_TEMPO := 1.2               ## m/s
const BAND_ABSTAND := 4.0             ## zwischen zwei Werkstuecken
const ARM_X: Array[float] = [-10.0, 0.0, 10.0]
const ARM_ABSTAND := 1.8              ## Armfuss neben der Bandmitte
const PORTAL_H := 2.6
## Haengebahn (Hangar West): Rechteck relativ zur Hangar-Ecke, Hoehe, Anzahl Drohnen, Tempo
const BAHN := Rect2(6.0, 8.0, 26.0, 14.0)
const BAHN_Y := 8.5
const BAHN_DROHNEN := 10
const BAHN_TEMPO := 1.5
const BAHN_HAENGER := 1.6             ## Stange zwischen Schiene und Drohne
## Testflug-Kaefig (Hangar Ost)
const KAEFIG := Rect2(42.0, 6.0, 24.0, 16.0)
const KAEFIG_H := 7.0
const KAEFIG_DROHNEN := 5
## Startplattform (Hangar Mitte)
const PAD_POS := Vector2(37.0, 15.0)
const PAD_RADIUS := 2.4
const PAD_HUB := 6.0                  ## so hoch steigt die Testdrohne
## Ladegestelle (Hangar Nordwand)
const GESTELL_EBENEN: Array[float] = [0.25, 2.1, 3.95]
const GESTELL_TIEFE := 1.6
const GESTELL_RAND := 4.0             ## frei an beiden Enden der Wand
const GESTELL_TEILUNG := 2.8          ## Abstand der Drohnen im Gestell
const LADE_DROHNEN := 6
const LED_TEMPO := 2.4

var _zeit := 0.0
var _mat: Dictionary = {}
var _band_tex: ImageTexture
var _band_stuecke: Array = []         ## je Band: [Array[Node3D], Richtung, x-Anfang, Material]
var _arme: Array = []                 ## [Turm, Schulter, Ellbogen, Phase, Spitze]
var _schweiss_lichter: Array[OmniLight3D] = []
var _bahn_drohnen: Array[Node3D] = []
var _kaefig_drohnen: Array[Node3D] = []
var _pad_drohne: Node3D
var _pad_licht: OmniLight3D
var _led_mat: StandardMaterial3D


func _ready() -> void:
	_materialien()
	_montagehalle()
	_hangar_bauen()
	_ladestation_bauen()


# ---------------------------------------------------------------- Helfer

func _std(c: Color, metall := 0.0, rauh := 0.6, leuchten := 0.0) -> StandardMaterial3D:
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
	_mat["stahl"] = _std(Color(0.32, 0.34, 0.38), 0.85, 0.35)
	_mat["dunkel"] = _std(Color(0.07, 0.08, 0.1), 0.6, 0.5)
	_mat["orange"] = _std(Color(1.0, 0.45, 0.08), 0.3, 0.45)
	_mat["gelb"] = _std(Color(1.0, 0.78, 0.1), 0.0, 0.5, 0.6)
	_mat["cyan"] = _std(Color(0.15, 0.85, 1.0), 0.0, 0.4, 2.5)
	_mat["pink"] = _std(Color(1.0, 0.2, 0.65), 0.0, 0.4, 2.5)
	_mat["schweiss"] = _std(Color(0.7, 0.9, 1.0), 0.0, 0.2, 6.0)
	var netz := _std(Color(0.2, 0.9, 1.0), 0.0, 0.5, 0.15)
	netz.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	netz.albedo_color.a = 0.05
	netz.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat["netz"] = netz
	_led_mat = _std(Color(0.3, 1.0, 0.4), 0.0, 0.4, 2.0)
	# Bandoberflaeche: dunkle Lamellen, Textur wandert (uv1_offset)
	var img := Image.create(64, 8, false, Image.FORMAT_RGB8)
	for x in 64:
		var hell := 0.16 if (x / 8) % 2 == 0 else 0.07
		for y in 8:
			img.set_pixel(x, y, Color(hell, hell, hell + 0.02))
	_band_tex = ImageTexture.create_from_image(img)


func _box(eltern: Node3D, mitte: Vector3, g: Vector3, mat: Material, kol := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = g
	mi.mesh = bm
	mi.material_override = mat
	mi.position = mitte
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	eltern.add_child(mi)
	if kol:
		_kol(eltern, mitte, g)
	return mi


func _kol(eltern: Node3D, mitte: Vector3, g: Vector3) -> void:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = g
	cs.shape = sh
	sb.add_child(cs)
	sb.position = mitte
	eltern.add_child(sb)


func _zyl(eltern: Node3D, mitte: Vector3, r: float, h: float, mat: Material, seg := 16) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = seg
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = mat
	mi.position = mitte
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	eltern.add_child(mi)
	return mi


func _licht(pos: Vector3, farbe: Color, energie: float, reichweite: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = farbe
	l.light_energy = energie
	l.omni_range = reichweite
	l.shadow_enabled = false
	add_child(l)
	return l


func _schild(txt: String, pos: Vector3, drehung: float, farbe: Color, pixel := 0.02) -> void:
	var l := Label3D.new()
	l.text = txt
	l.font_size = 96
	l.pixel_size = pixel
	l.modulate = farbe
	l.outline_size = 12
	l.outline_modulate = Color(0.0, 0.02, 0.06)
	l.shaded = false
	l.position = pos
	l.rotation_degrees.y = drehung
	add_child(l)


# ---------------------------------------------------------------- Montagehalle

func _montagehalle() -> void:
	var mitte_x := halle.get_center().x
	for i in BAND_Z.size():
		var z := halle.position.y + BAND_Z[i]
		var richtung := 1.0 if i == 0 else -1.0
		var x0 := mitte_x - BAND_LAENGE * 0.5
		# Gestell, Band und Seitenleisten (gelb)
		_box(self, Vector3(mitte_x, boden_y + BAND_HOEHE * 0.5 - 0.05, z), Vector3(BAND_LAENGE, BAND_HOEHE - 0.1, BAND_BREITE), _mat["stahl"], true)
		# Bandoberflaeche: Ebene mit Lamellen-Textur (1 Wiederholung je Meter), die mitwandert
		var band_mat := _std(Color.WHITE, 0.3, 0.7)
		band_mat.albedo_texture = _band_tex
		band_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		band_mat.uv1_scale = Vector3(BAND_LAENGE, 1.0, 1.0)
		var band := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(BAND_LAENGE, BAND_BREITE - 0.2)
		band.mesh = pm
		band.material_override = band_mat
		band.position = Vector3(mitte_x, boden_y + BAND_HOEHE + 0.005, z)
		add_child(band)
		for sz: float in [-1.0, 1.0]:
			_box(self, Vector3(mitte_x, boden_y + BAND_HOEHE + 0.04, z + sz * (BAND_BREITE * 0.5 - 0.05)), Vector3(BAND_LAENGE, 0.12, 0.1), _mat["gelb"])
		# Durchlauf-Portale an beiden Enden (verdecken das Zuruecksetzen der Werkstuecke)
		for ex: float in [x0, x0 + BAND_LAENGE]:
			_box(self, Vector3(ex, boden_y + PORTAL_H * 0.5, z), Vector3(1.6, PORTAL_H, BAND_BREITE + 1.0), _mat["dunkel"], true)
			_box(self, Vector3(ex, boden_y + PORTAL_H - 0.3, z), Vector3(1.64, 0.15, BAND_BREITE + 1.04), _mat["cyan"] if i == 0 else _mat["pink"])
		# Werkstuecke
		var stuecke: Array[Node3D] = []
		var anzahl := int(BAND_LAENGE / BAND_ABSTAND)
		for k in anzahl:
			var d := DM.bauen(DM.Stufe.RAHMEN if i == 0 else DM.Stufe.FERTIG, false)
			d.position = Vector3(x0 + k * BAND_ABSTAND, boden_y + BAND_HOEHE + 0.25, z)
			d.rotation.y = PI * 0.5 * richtung
			add_child(d)
			stuecke.append(d)
		_band_stuecke.append([stuecke, richtung, x0, band_mat])
		# Roboterarme abwechselnd nord- und suedseitig
		for k in ARM_X.size():
			var seite := -1.0 if (k + i) % 2 == 0 else 1.0
			_roboterarm(Vector3(mitte_x + ARM_X[k], boden_y, z + seite * ARM_ABSTAND), 0.0 if seite < 0.0 else PI, k * 1.7 + i)
		_schweiss_lichter.append(_licht(Vector3(mitte_x, boden_y + 2.0, z), Color(0.6, 0.85, 1.0), 0.0, 8.0))
		_schild("MONTAGE // LINIE %d" % (i + 1), Vector3(x0 - 1.2, boden_y + PORTAL_H + 0.6, z), -90.0, Color(0.15, 0.85, 1.0) if i == 0 else Color(1.0, 0.3, 0.7), 0.012)
	_schild("DROHNENWERK Ω // MONTAGE", Vector3(mitte_x, boden_y + halle_h - 1.6, halle.end.y - WAND_INNEN - 0.05), 180.0, Color(1.0, 0.8, 0.2), 0.014)


func _roboterarm(fuss: Vector3, drehung: float, phase: float) -> void:
	var basis := Node3D.new()
	basis.position = fuss
	basis.rotation.y = drehung
	add_child(basis)
	_zyl(basis, Vector3(0, 0.3, 0), 0.55, 0.6, _mat["dunkel"])
	_box(basis, Vector3(0, 0.02, 0), Vector3(1.6, 0.04, 1.6), _mat["gelb"])
	_kol(basis, Vector3(0, 0.6, 0), Vector3(1.0, 1.2, 1.0))
	var turm := Node3D.new()
	turm.position = Vector3(0, 0.6, 0)
	basis.add_child(turm)
	_zyl(turm, Vector3(0, 0.2, 0), 0.42, 0.4, _mat["orange"])
	var schulter := Node3D.new()
	schulter.position = Vector3(0, 0.45, 0)
	turm.add_child(schulter)
	_box(schulter, Vector3(0, 0.8, 0), Vector3(0.32, 1.6, 0.32), _mat["orange"])
	_zyl(schulter, Vector3.ZERO, 0.25, 0.5, _mat["dunkel"], 12).rotation.z = PI * 0.5
	var ellbogen := Node3D.new()
	ellbogen.position = Vector3(0, 1.6, 0)
	schulter.add_child(ellbogen)
	_zyl(ellbogen, Vector3.ZERO, 0.2, 0.42, _mat["dunkel"], 12).rotation.z = PI * 0.5
	_box(ellbogen, Vector3(0, 0.65, 0), Vector3(0.24, 1.3, 0.24), _mat["orange"])
	_box(ellbogen, Vector3(0, 1.38, 0), Vector3(0.16, 0.18, 0.16), _mat["dunkel"])
	var spitze := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.07
	sm.height = 0.14
	spitze.mesh = sm
	spitze.material_override = _mat["schweiss"]
	spitze.position = Vector3(0, 1.5, 0)
	ellbogen.add_child(spitze)
	_arme.append([turm, schulter, ellbogen, phase, spitze])


# ---------------------------------------------------------------- Hangar

func _hangar_bauen() -> void:
	var ecke := Vector3(hangar.position.x, boden_y, hangar.position.y)
	_ladegestelle()
	# Haengebahn: Schiene als Rechteck an Deckenstuetzen
	var b := Rect2(hangar.position + BAHN.position, BAHN.size)
	var y := boden_y + BAHN_Y
	for seite in [[Vector3(b.get_center().x, y, b.position.y), Vector3(b.size.x, 0.2, 0.3)],
			[Vector3(b.get_center().x, y, b.end.y), Vector3(b.size.x, 0.2, 0.3)],
			[Vector3(b.position.x, y, b.get_center().y), Vector3(0.3, 0.2, b.size.y)],
			[Vector3(b.end.x, y, b.get_center().y), Vector3(0.3, 0.2, b.size.y)]]:
		_box(self, seite[0], seite[1], _mat["stahl"])
	for p: Vector2 in [b.position, Vector2(b.end.x, b.position.y), b.end, Vector2(b.position.x, b.end.y)]:
		var oben := boden_y + hangar_h
		_box(self, Vector3(p.x, (y + oben) * 0.5, p.y), Vector3(0.2, oben - y, 0.2), _mat["dunkel"])
	for i in BAHN_DROHNEN:
		var d := Node3D.new()
		add_child(d)
		var dr := DM.bauen(DM.Stufe.FERTIG, false)
		dr.position = Vector3(0, -BAHN_HAENGER, 0)
		d.add_child(dr)
		_box(d, Vector3(0, -BAHN_HAENGER * 0.5, 0), Vector3(0.06, BAHN_HAENGER, 0.06), _mat["stahl"])
		_box(d, Vector3(0, -0.05, 0), Vector3(0.4, 0.2, 0.4), _mat["dunkel"])
		_bahn_drohnen.append(d)
	_schild("ENDMONTAGE", Vector3(b.get_center().x, boden_y + 4.0, b.end.y + 0.01), 0.0, Color(1.0, 0.8, 0.2), 0.015)
	# Testflug-Kaefig: Pfosten, Rahmen, Netzflaechen mit Kollision
	var k := Rect2(hangar.position + KAEFIG.position, KAEFIG.size)
	var ky := boden_y + KAEFIG_H * 0.5
	for p: Vector2 in [k.position, Vector2(k.end.x, k.position.y), k.end, Vector2(k.position.x, k.end.y),
			Vector2(k.get_center().x, k.position.y), Vector2(k.get_center().x, k.end.y)]:
		_box(self, Vector3(p.x, ky, p.y), Vector3(0.25, KAEFIG_H, 0.25), _mat["dunkel"])
	for seite in [[Vector3(k.get_center().x, ky, k.position.y), Vector3(k.size.x, KAEFIG_H, 0.05)],
			[Vector3(k.get_center().x, ky, k.end.y), Vector3(k.size.x, KAEFIG_H, 0.05)],
			[Vector3(k.position.x, ky, k.get_center().y), Vector3(0.05, KAEFIG_H, k.size.y)],
			[Vector3(k.end.x, ky, k.get_center().y), Vector3(0.05, KAEFIG_H, k.size.y)]]:
		_box(self, seite[0], seite[1], _mat["netz"], true)
		var rand: Vector3 = seite[1]
		_box(self, Vector3(seite[0].x, boden_y + KAEFIG_H, seite[0].z), Vector3(maxf(rand.x, 0.15), 0.15, maxf(rand.z, 0.15)), _mat["cyan"])
	for i in KAEFIG_DROHNEN:
		var d := DM.bauen(DM.Stufe.FERTIG, i % 2 == 0)
		add_child(d)
		_kaefig_drohnen.append(d)
	_licht(Vector3(k.get_center().x, boden_y + KAEFIG_H - 1.0, k.get_center().y), Color(0.3, 0.85, 1.0), 1.5, 16.0)
	_schild("TESTFLUG // ZUTRITT VERBOTEN", Vector3(k.get_center().x, boden_y + KAEFIG_H + 0.7, k.end.y + 0.05), 0.0, Color(1.0, 0.3, 0.3), 0.014)
	# Startplattform mit Testdrohne
	var pad := ecke + Vector3(PAD_POS.x, 0, PAD_POS.y)
	_zyl(self, pad + Vector3(0, 0.06, 0), PAD_RADIUS, 0.12, _mat["dunkel"], 32)
	_zyl(self, pad + Vector3(0, 0.1, 0), PAD_RADIUS - 0.2, 0.04, _mat["gelb"], 32)
	_zyl(self, pad + Vector3(0, 0.13, 0), PAD_RADIUS - 0.5, 0.04, _mat["dunkel"], 32)
	_pad_drohne = DM.bauen(DM.Stufe.FERTIG, true)
	_pad_drohne.position = pad + Vector3(0, 0.6, 0)
	add_child(_pad_drohne)
	_pad_licht = _licht(pad + Vector3(0, 0.8, 0), Color(1.0, 0.75, 0.2), 1.0, 7.0)
	# Werksschild an der Suedwand (Innenseite schaut nach Norden)
	_schild("DROHNENWERK Ω", Vector3(hangar.get_center().x, boden_y + hangar_h - 2.6, hangar.end.y - WAND_INNEN - 0.05), 180.0, Color(0.15, 0.9, 1.0), 0.026)


## Ladegestelle an der Hangar-Nordwand: Boeden mit Pfosten, Drohnen als MultiMesh (nur Optik ausser den Boeden).
func _ladegestelle() -> void:
	var z := hangar.position.y + WAND_INNEN + GESTELL_TIEFE * 0.5
	var x0 := hangar.position.x + GESTELL_RAND
	var x1 := hangar.end.x - GESTELL_RAND
	var laenge := x1 - x0
	for ey in GESTELL_EBENEN:
		_box(self, Vector3((x0 + x1) * 0.5, boden_y + ey, z), Vector3(laenge, 0.1, GESTELL_TIEFE), _mat["stahl"], ey < 0.5)
		_box(self, Vector3((x0 + x1) * 0.5, boden_y + ey + 0.06, z + GESTELL_TIEFE * 0.5 - 0.05), Vector3(laenge, 0.04, 0.06), _led_mat)
	var oben := GESTELL_EBENEN[GESTELL_EBENEN.size() - 1] + 1.6
	var px := x0
	while px <= x1 + 0.01:
		_box(self, Vector3(px, boden_y + oben * 0.5, z), Vector3(0.12, oben, GESTELL_TIEFE), _mat["dunkel"])
		px += GESTELL_TEILUNG * 3.0
	_kol(self, Vector3((x0 + x1) * 0.5, boden_y + oben * 0.5, z), Vector3(laenge, oben, GESTELL_TIEFE))
	# Drohnen: je Ebene eine Reihe, Teile als MultiMesh (Rumpf, Ausleger, Rotoren)
	var trafos: Array[Transform3D] = []
	for ey in GESTELL_EBENEN:
		var x := x0 + GESTELL_TEILUNG * 0.5
		while x < x1:
			trafos.append(Transform3D(Basis(), Vector3(x, boden_y + ey + 0.3, z)))
			x += GESTELL_TEILUNG
	var vorlage := DM.bauen(DM.Stufe.FERTIG, false)
	for teil: Node in vorlage.find_children("*", "MeshInstance3D", true, false):
		var mi := teil as MeshInstance3D
		var lokal := mi.transform
		if mi.get_parent() != vorlage:
			lokal = (mi.get_parent() as Node3D).transform * lokal
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mi.mesh
		mm.instance_count = trafos.size()
		for j in trafos.size():
			mm.set_instance_transform(j, trafos[j] * lokal)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mi.material_override
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
	vorlage.free()
	_schild("LADEGESTELL A-F // %d EINHEITEN" % trafos.size(), Vector3(hangar.get_center().x, boden_y + oben + 0.6, z + GESTELL_TIEFE * 0.5 + 0.05), 0.0, Color(0.3, 1.0, 0.4), 0.014)


# ---------------------------------------------------------------- Ladestation

func _ladestation_bauen() -> void:
	# Wandgestell an der Ostwand: drei Ebenen, je zwei Drohnen
	var x := ladestation.end.x - WAND_INNEN - GESTELL_TIEFE * 0.5
	var z0 := ladestation.position.y + 4.0
	for e in 3:
		var y := boden_y + 0.3 + e * 1.4
		_box(self, Vector3(x, y, z0 + 3.0), Vector3(GESTELL_TIEFE, 0.08, 8.0), _mat["stahl"], e == 0)
		_box(self, Vector3(x - GESTELL_TIEFE * 0.5 + 0.04, y + 0.05, z0 + 3.0), Vector3(0.05, 0.04, 8.0), _led_mat)
	for i in LADE_DROHNEN:
		var d := DM.bauen(DM.Stufe.FERTIG, false)
		d.position = Vector3(x, boden_y + 0.6 + (i % 3) * 1.4, z0 + 1.0 + (i / 3) * 4.0)
		d.rotation.y = -PI * 0.5
		add_child(d)
	_schild("LADESTATION", Vector3(x - GESTELL_TIEFE * 0.5 - 0.05, boden_y + 4.5, z0 + 3.0), -90.0, Color(0.3, 1.0, 0.4), 0.012)


# ---------------------------------------------------------------- Animation

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_zeit += delta
	# Baender
	for b in _band_stuecke:
		var bm: StandardMaterial3D = b[3]
		bm.uv1_offset.x = fposmod(bm.uv1_offset.x - (b[1] as float) * delta * BAND_TEMPO, 1.0)
		var stuecke: Array[Node3D] = b[0]
		var richtung: float = b[1]
		var x0: float = b[2]
		for d in stuecke:
			var rel := fposmod(d.position.x - x0 + richtung * BAND_TEMPO * delta, BAND_LAENGE)
			d.position.x = x0 + rel
	# Roboterarme und Schweisslicht
	for a in _arme:
		var ph: float = a[3]
		(a[0] as Node3D).rotation.y = sin(_zeit * 0.7 + ph) * 0.5
		(a[1] as Node3D).rotation.x = 0.7 + sin(_zeit * 1.1 + ph) * 0.15
		(a[2] as Node3D).rotation.x = 1.5 + sin(_zeit * 1.3 + ph) * 0.25
		(a[4] as Node3D).visible = sin(_zeit * 9.0 + ph * 3.0) > 0.2
	for i in _schweiss_lichter.size():
		_schweiss_lichter[i].light_energy = maxf(0.0, sin(_zeit * 17.0 + i * 2.0)) * 1.4
	# Haengebahn
	var b := Rect2(hangar.position + BAHN.position, BAHN.size)
	var umfang := (b.size.x + b.size.y) * 2.0
	for i in _bahn_drohnen.size():
		var s := fposmod(_zeit * BAHN_TEMPO + i * umfang / _bahn_drohnen.size(), umfang)
		_bahn_drohnen[i].position = _auf_rechteck(b, s, boden_y + BAHN_Y)
	# Testflug
	var k := Rect2(hangar.position + KAEFIG.position, KAEFIG.size)
	for i in _kaefig_drohnen.size():
		var d := _kaefig_drohnen[i]
		var ph := i * 1.3
		var t := _zeit * (0.35 + i * 0.05)
		var p := Vector3(k.get_center().x + sin(t + ph) * (k.size.x * 0.5 - 2.0),
			boden_y + 2.6 + sin(t * 1.7 + ph) * 1.6,
			k.get_center().y + sin(t * 2.0 + ph * 2.0) * (k.size.y * 0.5 - 2.0))
		var vor := p - d.position
		d.position = p
		if Vector2(vor.x, vor.z).length() > 0.001:
			d.rotation.y = atan2(vor.x, vor.z)
		DM.rotoren_drehen(d, delta)
	# Startplattform: Drohne steigt und landet
	var hub := (1.0 - cos(_zeit * 0.5)) * 0.5
	_pad_drohne.position.y = boden_y + 0.6 + hub * PAD_HUB
	DM.rotoren_drehen(_pad_drohne, delta, 0.4 + hub)
	_pad_licht.light_energy = 0.6 + hub * 1.4
	_led_mat.emission_energy_multiplier = 1.2 + sin(_zeit * LED_TEMPO) * 0.8


## Punkt auf dem Umfang eines Rechtecks (Laufweg s ab der NW-Ecke im Uhrzeigersinn).
func _auf_rechteck(r: Rect2, s: float, y: float) -> Vector3:
	if s < r.size.x:
		return Vector3(r.position.x + s, y, r.position.y)
	s -= r.size.x
	if s < r.size.y:
		return Vector3(r.end.x, y, r.position.y + s)
	s -= r.size.y
	if s < r.size.x:
		return Vector3(r.end.x - s, y, r.end.y)
	s -= r.size.x
	return Vector3(r.position.x, y, r.end.y - s)
