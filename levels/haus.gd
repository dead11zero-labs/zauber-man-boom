extends Node3D
## Basis fuer begehbare Haeuser mit mehreren Etagen (Popcorn-Labor, Buecherei, Museum, Stadtverwaltung).
## Lokale Achsen: Front mit Eingang zeigt nach +z, Ursprung = Mitte der Grundflaeche auf Strassenniveau.
## Die Unterklasse ueberschreibt `_bauen()` (wird in `_ready` gerufen) und optional `_leben(delta)`.
## Ablauf in `_bauen()`: `_basis_materialien()`, eigene Materialien in `m`, dann `_rohbau(...)`
## (Aussenwaende mit Fensterbaendern, Decken mit Treppenloch, Dach, Schiebetuer, Treppenhaus),
## danach Moebel mit den Helfern unten und zum Schluss `_buecher_bauen()`.
## Das Treppenhaus liegt hinten links: zwei Laeufe mit Zwischenpodest je Etage. Die Kollision der
## Laeufe ist eine glatte Rampe, die Stufen darueber sind Optik (wie im Sy-Ci Burgers).
## Innenmaterialien bekommen kein Himmelslicht (`disable_ambient_light`), jede Etage hat Deckenleuchten.
## Keine Signale, keine Exporte. Alle Masse in Metern.

const WAND := 0.4                 ## Dicke der Aussenwand
const HAUT := 0.06                ## Fassadenplatte aussen auf der Wand
const DECKE := 0.3                ## Dicke der Geschossdecken
const BELAG := 0.04               ## Bodenbelag auf der Decke
const BODEN_EG := 0.03            ## Erdgeschoss-Belag liegt knapp ueber dem Pflaster (keine Schwelle)
const BRUESTUNG := 0.9            ## Wand unter dem Fensterband
const FENSTER_H := 2.4            ## Hoehe des Fensterbands
const PFEILER_ABSTAND := 4.0
const PFEILER_B := 0.5
const GLAS_DICKE := 0.08
const TUER_H := 3.0
const TUER_OEFFNEN := 7.0         ## Abstand, ab dem die Schiebetuer aufgeht
const TUER_TEMPO := 2.5           ## Oeffnungen pro Sekunde
const ATTIKA := 0.9
const LAUF_B := 1.9               ## Breite eines Treppenlaufs
const LAUF_SPALT := 0.2           ## Auge zwischen den beiden Laeufen
const LAUF_L := 6.0               ## waagerechte Laenge eines Laufs
const PODEST := 2.2
const STUFEN := 14                ## Stufen je Lauf
const GELAENDER_H := 1.05
const PFOSTEN_JE := 3             ## ein Gelaenderpfosten alle n Stufen
const RAMPE_DICKE := 0.3
const LICHT_ABSTAND := 0.5        ## Leuchte haengt so weit unter der Decke
const SCHILD_MASS := 0.5          ## Schilder: Schrift halb so gross wie der Fassaden-Schriftzug bei gleichem Pixelwert
const BUCH_FARBEN: Array[Color] = [
	Color(0.55, 0.12, 0.1), Color(0.12, 0.25, 0.5), Color(0.15, 0.4, 0.22), Color(0.75, 0.6, 0.2),
	Color(0.35, 0.2, 0.12), Color(0.8, 0.78, 0.7), Color(0.4, 0.15, 0.45), Color(0.1, 0.1, 0.12),
]

var m: Dictionary = {}
var breite := 30.0
var tiefe := 24.0
var etagen := 2
var etage_h := 4.5
## Fensterbaender an Rueckwand und Seitenwaenden (aus = geschlossene Waende, z. B. fuer Ausstellungsflaechen)
var fenster_hinten := true
var fenster_seiten := true
var zeit := 0.0
var _spieler: Node3D
var _tueren: Array = []           ## je Tuer: [linkes Blatt, rechtes Blatt, Mitte x, Blattbreite, Oeffnung 0..1, z]
var _buch_t: Array[Transform3D] = []
var _buch_f: Array[Color] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = hash(name)
	_bauen()


func _process(delta: float) -> void:
	zeit += delta
	_tueren_bewegen(delta)
	_leben(delta)


## Von der Unterklasse zu ueberschreiben: baut das ganze Haus.
func _bauen() -> void:
	pass


## Von der Unterklasse zu ueberschreiben: Animationen pro Frame.
func _leben(_delta: float) -> void:
	pass


# ---------------------------------------------------------------- Material

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


## Texturiertes Material (Poly-Haven-Ordner unter assets/texturen), dreiseitig projiziert.
func _tex(ordner: String, kachel: float, tint := Color.WHITE, metall := 0.0, rauh := 1.0, innen := true) -> StandardMaterial3D:
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


## Flaches Bild (UV 0..1), leuchtet leicht selbst (Bildschirme, Poster, Gemaelde).
func _bild_mat(ordner: String, emission := 0.15) -> StandardMaterial3D:
	var key := "bild_%s_%d" % [ordner, int(emission * 100.0)]
	if m.has(key):
		return m[key]
	var t := StandardMaterial3D.new()
	t.albedo_texture = load("res://assets/texturen/%s/diff.jpg" % ordner)
	t.roughness = 0.5
	t.disable_ambient_light = true
	if emission > 0.0:
		t.emission_enabled = true
		t.emission_texture = t.albedo_texture
		t.emission_energy_multiplier = emission
	m[key] = t
	return t


func _glas(alpha: float, innen := true, tint := Color(0.7, 0.88, 1.0)) -> StandardMaterial3D:
	var g := _std(Color(tint.r, tint.g, tint.b, alpha), 0.0, 0.0, 0.05, innen)
	g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return g


## Grundausstattung, die alle Haeuser teilen. Die Unterklasse darf Eintraege ueberschreiben.
func _basis_materialien() -> void:
	m["fassade"] = _tex("concrete_tile_facade", 4.0, Color(0.82, 0.84, 0.9), 0.1, 1.0, false)
	m["wand"] = _tex("foyer_painted_plaster_wall", 3.0, Color(1.5, 1.5, 1.5))
	m["decke"] = _tex("buero_decke", 2.4, Color(1.1, 1.1, 1.1))
	m["boden"] = _tex("foyer_granite_tile", 2.4)
	m["boden_oben"] = _tex("foyer_wood_floor_deck", 2.0)
	m["dach"] = _tex("brushed_concrete_04", 4.0, Color(0.45, 0.46, 0.5), 0.0, 1.0, false)
	m["beton"] = _tex("brushed_concrete_04", 3.0, Color(0.8, 0.8, 0.82))
	m["holz"] = _tex("foyer_dark_wood", 1.6)
	m["eiche"] = _tex("markt_oak_wood_planks", 1.4)
	m["leder"] = _tex("foyer_brown_leather", 1.2)
	m["stahl"] = _tex("kantine_stahl", 1.2, Color(1.2, 1.2, 1.25), 0.3, 0.45)
	m["teppich"] = _tex("buero_teppich", 2.0)
	m["saeule"] = _tex("brushed_concrete_04", 2.0, Color(0.95, 0.93, 0.88), 0.0, 1.0, false)
	m["chrom"] = _std(Color(0.7, 0.72, 0.76), 0.0, 0.8, 0.3)
	m["dunkel"] = _std(Color(0.1, 0.11, 0.14), 0.0, 0.3, 0.5)
	m["weiss"] = _std(Color(0.93, 0.94, 0.96), 0.0, 0.05, 0.45)
	m["rahmen"] = _std(Color(0.16, 0.17, 0.2), 0.0, 0.6, 0.4, false)
	m["lampe"] = _std(Color(1.0, 0.96, 0.88), 2.0, 0.0, 0.4)
	m["glas"] = _glas(0.16)
	m["fenster"] = _glas(0.22, false, Color(0.55, 0.75, 0.9))
	m["blatt"] = _std(Color(0.14, 0.4, 0.16), 0.0, 0.0, 0.85)
	m["topf"] = _std(Color(0.3, 0.3, 0.33), 0.0, 0.1, 0.7)
	m["akzent"] = _std(Color(0.2, 0.9, 1.0), 1.6, 0.0, 0.5, false)
	m["schirm_aus"] = _std(Color(0.03, 0.03, 0.04), 0.0, 0.2, 0.2)
	var buch := StandardMaterial3D.new()
	buch.vertex_color_use_as_albedo = true
	buch.roughness = 0.8
	buch.disable_ambient_light = true
	m["buch"] = buch


# ---------------------------------------------------------------- Grundformen

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


func _zyl(pos: Vector3, r: float, h: float, mat: Material, eltern: Node3D = null, oben := -1.0, seg := 16, kol := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.bottom_radius = r
	cm.top_radius = r if oben < 0.0 else oben
	cm.height = h
	cm.radial_segments = seg
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	(eltern if eltern != null else self).add_child(mi)
	if kol:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = maxf(r, cm.top_radius)
		sh.height = h
		cs.shape = sh
		sb.add_child(cs)
		mi.add_child(sb)
	return mi


func _kugel(pos: Vector3, r: float, mat: Material, eltern: Node3D = null, flach := 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0 * flach
	sm.radial_segments = 14
	sm.rings = 7
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	(eltern if eltern != null else self).add_child(mi)
	return mi


## Leerer Knoten mit Position und Drehung um y (Grad); Moebel werden lokal darin gebaut.
func _gruppe(pos: Vector3, dreh := 0.0) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = dreh
	add_child(n)
	return n


## Fester Schriftzug (kein Billboard). `dreh` in Grad um y; 0 = lesbar von +z aus.
func _text(txt: String, pos: Vector3, farbe: Color, pixel: float, dreh := 0.0, leuchtet := false, eltern: Node3D = null) -> Label3D:
	var l := Label3D.new()
	l.text = txt
	l.font_size = 64
	l.pixel_size = pixel
	l.outline_size = 8
	l.outline_modulate = farbe.darkened(0.75)
	l.modulate = farbe
	l.shaded = not leuchtet
	l.double_sided = false
	l.position = pos
	l.rotation_degrees.y = dreh
	(eltern if eltern != null else self).add_child(l)
	return l


func _licht(pos: Vector3, farbe: Color, energie: float, reichweite: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = farbe
	l.light_energy = energie
	l.omni_range = reichweite
	l.omni_attenuation = 0.8
	l.shadow_enabled = false
	l.position = pos
	add_child(l)
	return l


# ---------------------------------------------------------------- Rohbau

## Oberkante des Fussbodens der Etage e (0 = Erdgeschoss).
func boden_y(e: int) -> float:
	return e * etage_h


## Innenkanten des Hauses (x links/rechts, z hinten/vorn).
func innen_x() -> float:
	return breite * 0.5 - WAND


func innen_z() -> float:
	return tiefe * 0.5 - WAND


## z, an dem die Treppenlaeufe beginnen (Deckenkante am Treppenloch).
func treppe_z() -> float:
	return -innen_z() + PODEST + LAUF_L


## Breite des Treppenhauses (zwei Laeufe plus Auge).
func treppe_b() -> float:
	return LAUF_B * 2.0 + LAUF_SPALT


## Baut Waende, Decken, Dach, Tuer und Treppenhaus. `tuer_x`/`tuer_b`: Lage und Breite des Eingangs.
func _rohbau(b: float, t: float, anzahl: int, hoehe: float, tuer_x := 0.0, tuer_b := 4.0) -> void:
	breite = b
	tiefe = t
	etagen = anzahl
	etage_h = hoehe
	var ix := innen_x()
	var iz := innen_z()
	# Boeden und Decken
	_box(Vector3(0, BODEN_EG * 0.5, 0), Vector3(ix * 2.0, BODEN_EG, iz * 2.0), m["boden"], false)
	var tx0 := -ix
	var tx1 := tx0 + treppe_b()
	var tz := treppe_z()
	for e in range(1, etagen):
		var y := boden_y(e)
		# rechts neben dem Treppenloch (volle Tiefe) und vor dem Loch
		_decke(Rect2(tx1, -iz, ix - tx1, iz * 2.0), y, m["boden_oben"])
		_decke(Rect2(tx0, tz, tx1 - tx0, iz - tz), y, m["boden_oben"])
	# Dach mit Attika
	var dach_y := boden_y(etagen)
	_box(Vector3(0, dach_y + DECKE * 0.5, 0), Vector3(b, DECKE, t), m["dach"])
	_box(Vector3(0, dach_y - 0.03, 0), Vector3(ix * 2.0, 0.06, iz * 2.0), m["decke"], false)
	for s: float in [-1.0, 1.0]:
		_box(Vector3(0, dach_y + DECKE + ATTIKA * 0.5, s * (t * 0.5 - WAND * 0.5)), Vector3(b, ATTIKA, WAND), m["fassade"])
		_box(Vector3(s * (b * 0.5 - WAND * 0.5), dach_y + DECKE + ATTIKA * 0.5, 0), Vector3(WAND, ATTIKA, t - WAND * 2.0), m["fassade"])
	# Aussenwaende je Etage
	for e in etagen:
		var y0 := boden_y(e)
		_wand(Vector2(-b * 0.5, -t * 0.5 + WAND * 0.5), Vector2(b * 0.5, -t * 0.5 + WAND * 0.5), y0, Vector3(0, 0, -1), fenster_hinten)
		_wand(Vector2(-b * 0.5 + WAND * 0.5, -t * 0.5 + WAND), Vector2(-b * 0.5 + WAND * 0.5, t * 0.5 - WAND), y0, Vector3(-1, 0, 0), fenster_seiten)
		_wand(Vector2(b * 0.5 - WAND * 0.5, -t * 0.5 + WAND), Vector2(b * 0.5 - WAND * 0.5, t * 0.5 - WAND), y0, Vector3(1, 0, 0), fenster_seiten)
		var zf := t * 0.5 - WAND * 0.5
		if e == 0:
			_wand(Vector2(-b * 0.5, zf), Vector2(tuer_x - tuer_b * 0.5, zf), y0, Vector3(0, 0, 1), true)
			_wand(Vector2(tuer_x + tuer_b * 0.5, zf), Vector2(b * 0.5, zf), y0, Vector3(0, 0, 1), true)
			_wandteil(Vector3(tuer_x, y0 + (TUER_H + etage_h) * 0.5, zf), Vector3(tuer_b, etage_h - TUER_H, WAND), Vector3(0, 0, 1))
			_tuer(tuer_x, tuer_b, zf)
		else:
			_wand(Vector2(-b * 0.5, zf), Vector2(b * 0.5, zf), y0, Vector3(0, 0, 1), true)
	_treppenhaus()


## Geschossdecke ueber einem Rechteck (x, z): tragende Platte mit Kollision plus Belag.
func _decke(r: Rect2, y: float, belag: Material) -> void:
	if r.size.x <= 0.01 or r.size.y <= 0.01:
		return
	var mitte := r.get_center()
	_box(Vector3(mitte.x, y - BELAG - DECKE * 0.5, mitte.y), Vector3(r.size.x, DECKE, r.size.y), m["decke"])
	_box(Vector3(mitte.x, y - BELAG * 0.5, mitte.y), Vector3(r.size.x, BELAG, r.size.y), belag, false)


## Wandstueck mit Kollision: innen Putz, aussen eine Fassadenplatte auf der Seite `normal`.
func _wandteil(mitte: Vector3, g: Vector3, normal: Vector3) -> void:
	_box(mitte, g, m["wand"])
	var haut_g := g
	var versatz := Vector3.ZERO
	if absf(normal.x) > 0.5:
		haut_g.x = HAUT
		versatz.x = normal.x * (g.x + HAUT) * 0.5
	else:
		haut_g.z = HAUT
		versatz.z = normal.z * (g.z + HAUT) * 0.5
	_box(mitte + versatz, haut_g, m["fassade"], false)


## Aussenwand einer Etage von a nach b (x, z; achsparallel) ab Hoehe y0.
## Mit `fenster`: Bruestung, Fensterband mit Pfeilern, Sturz. Sonst geschlossene Wand.
func _wand(a: Vector2, b: Vector2, y0: float, normal: Vector3, fenster: bool) -> void:
	var laenge := a.distance_to(b)
	if laenge < 0.05:
		return
	var entlang_x := absf(a.x - b.x) > absf(a.y - b.y)
	var mitte := (a + b) * 0.5
	var g := func(l: float, h: float, d: float) -> Vector3:
		return Vector3(l, h, d) if entlang_x else Vector3(d, h, l)
	if not fenster or laenge < PFEILER_B * 2.0 + 0.6:
		_wandteil(Vector3(mitte.x, y0 + etage_h * 0.5, mitte.y), g.call(laenge, etage_h, WAND), normal)
		return
	var sturz := etage_h - BRUESTUNG - FENSTER_H
	_wandteil(Vector3(mitte.x, y0 + BRUESTUNG * 0.5, mitte.y), g.call(laenge, BRUESTUNG, WAND), normal)
	_wandteil(Vector3(mitte.x, y0 + etage_h - sturz * 0.5, mitte.y), g.call(laenge, sturz, WAND), normal)
	var fy := y0 + BRUESTUNG + FENSTER_H * 0.5
	var glas := _box(Vector3(mitte.x, fy, mitte.y), g.call(laenge, FENSTER_H, GLAS_DICKE), m["fenster"])
	glas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var felder := maxi(int(round(laenge / PFEILER_ABSTAND)), 1)
	var richtung := (b - a) / laenge
	for i in felder + 1:
		var p := a + richtung * clampf(laenge * i / felder, PFEILER_B * 0.5, laenge - PFEILER_B * 0.5)
		_wandteil(Vector3(p.x, fy, p.y), g.call(PFEILER_B, FENSTER_H, WAND), normal)


## Glas-Schiebetuer im Eingang: zwei Blaetter, oeffnen automatisch (keine Kollision).
func _tuer(x: float, b: float, z: float) -> void:
	var blatt_b := b * 0.5
	var paar: Array = []
	for s: float in [-1.0, 1.0]:
		var blatt := _box(Vector3(x + s * blatt_b * 0.5, TUER_H * 0.5, z), Vector3(blatt_b, TUER_H, GLAS_DICKE), m["fenster"], false)
		blatt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_box(Vector3(-s * (blatt_b * 0.5 - 0.04), 0, 0), Vector3(0.08, TUER_H, 0.1), m["rahmen"], false, blatt)
		paar.append(blatt)
	_box(Vector3(x, TUER_H + 0.08, z), Vector3(b + 0.3, 0.16, WAND + 0.1), m["rahmen"], false)
	_tueren.append([paar[0], paar[1], x, blatt_b, 0.0, z])


func _tueren_bewegen(delta: float) -> void:
	if _tueren.is_empty():
		return
	if not is_instance_valid(_spieler):
		_spieler = get_tree().get_first_node_in_group("spieler") as Node3D
	if _spieler == null:
		return
	var lokal := to_local(_spieler.global_position)
	for t in _tueren:
		var nah := Vector2(lokal.x - t[2], lokal.z - t[5]).length() < TUER_OEFFNEN and lokal.y < etage_h
		t[4] = move_toward(t[4], 1.0 if nah else 0.0, TUER_TEMPO * delta)
		var weg: float = t[3] * 0.92 * t[4]
		(t[0] as Node3D).position.x = t[2] - t[3] * 0.5 - weg
		(t[1] as Node3D).position.x = t[2] + t[3] * 0.5 + weg


# ---------------------------------------------------------------- Treppenhaus

## Zwei Laeufe mit Zwischenpodest je Etage, hinten links. Lauf A (links) steigt nach hinten,
## Lauf B (rechts) kommt nach vorn zurueck und endet an der Deckenkante der naechsten Etage.
func _treppenhaus() -> void:
	var ix := innen_x()
	var iz := innen_z()
	var x_a := -ix + LAUF_B * 0.5
	var x_b := -ix + LAUF_B + LAUF_SPALT + LAUF_B * 0.5
	var x_rand := -ix + treppe_b()
	var z_vorn := treppe_z()
	var z_hinten := z_vorn - LAUF_L
	var halb := etage_h * 0.5
	for e in etagen - 1:
		var y := boden_y(e)
		_lauf(x_a, y, z_vorn, z_hinten, halb, false, true)
		_lauf(x_b, y + halb, z_hinten, z_vorn, halb, false, true)
		# Zwischenpodest hinten
		_box(Vector3(-ix + treppe_b() * 0.5, y + halb - 0.125, -iz + PODEST * 0.5), Vector3(treppe_b(), 0.25, PODEST), m["beton"])
		_bruestung(Vector3(x_rand, y + halb, -iz + PODEST * 0.5), PODEST, true)
	# Absturzsicherung an den Deckenkanten der oberen Etagen
	for e in range(1, etagen):
		var y := boden_y(e)
		_bruestung(Vector3(x_rand, y, (z_vorn - iz) * 0.5), z_vorn + iz, true)
		if e == etagen - 1:
			_bruestung(Vector3(x_a, y, z_vorn), LAUF_B + LAUF_SPALT, false)
	# Wange im Erdgeschoss unter dem ersten Lauf B (damit niemand unter die Treppe laeuft)
	_box(Vector3(x_rand - 0.05, halb * 0.5, (z_vorn - iz) * 0.5), Vector3(0.1, halb, z_vorn + iz), m["wand"])


## Glasbruestung mit Handlauf; laeuft entlang z (`entlang_z`) oder entlang x. `pos` = Fusspunkt-Mitte.
func _bruestung(pos: Vector3, laenge: float, entlang_z: bool) -> void:
	var g := Vector3(0.06, GELAENDER_H, laenge) if entlang_z else Vector3(laenge, GELAENDER_H, 0.06)
	var glas := _box(pos + Vector3(0, GELAENDER_H * 0.5, 0), g, m["glas"])
	glas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var holm := Vector3(0.08, 0.06, laenge) if entlang_z else Vector3(laenge, 0.06, 0.08)
	_box(pos + Vector3(0, GELAENDER_H, 0), holm, m["chrom"], false)


## Ein Treppenlauf von (x, y0, z_start) nach z_ende, steigt um `steig`.
## Kollision: glatte Rampe. Optik: Stufen plus Wange darunter. Gelaender links/rechts waehlbar.
func _lauf(x: float, y0: float, z_start: float, z_ende: float, steig: float, links: bool, rechts: bool) -> void:
	var lauf := absf(z_ende - z_start)
	var vor := signf(z_ende - z_start)          # Laufrichtung entlang z
	var d := lauf / STUFEN
	var sh := steig / STUFEN
	for i in STUFEN:
		var zc := z_start + vor * (i + 0.5) * d
		var oben := y0 + (i + 1) * sh
		_box(Vector3(x, oben - sh, zc), Vector3(LAUF_B, sh * 2.0, d + 0.01), m["beton"], false)
		_box(Vector3(x, oben + 0.004, zc - vor * (d * 0.5 - 0.03)), Vector3(LAUF_B, 0.008, 0.05), m["dunkel"], false)
	var winkel := atan(steig / lauf)
	var laenge := sqrt(lauf * lauf + steig * steig)
	var rampe := Node3D.new()
	# Rampenoberkante liegt auf halber Stufenhoehe ueber der Stufenlinie (wie im Sy-Ci Burgers)
	rampe.position = Vector3(x, y0 + steig * 0.5 + sh * 0.5 - RAMPE_DICKE * 0.5 / cos(winkel), (z_start + z_ende) * 0.5)
	rampe.rotation.x = winkel * -vor
	add_child(rampe)
	_kol(rampe, Vector3(LAUF_B, RAMPE_DICKE, laenge))
	for seite: float in [-1.0, 1.0]:
		if (seite < 0.0 and not links) or (seite > 0.0 and not rechts):
			continue
		var sx := x + seite * (LAUF_B * 0.5 - 0.04)
		var schraeg := Node3D.new()
		schraeg.position = Vector3(sx, y0 + steig * 0.5 + sh * 0.5 + GELAENDER_H * 0.5, (z_start + z_ende) * 0.5)
		schraeg.rotation.x = winkel * -vor
		add_child(schraeg)
		_box(Vector3(0, GELAENDER_H * 0.5, 0), Vector3(0.07, 0.06, laenge), m["chrom"], false, schraeg)
		_box(Vector3.ZERO, Vector3(0.04, 0.04, laenge), m["chrom"], false, schraeg)
		_kol(schraeg, Vector3(0.08, GELAENDER_H, laenge))
		for i in range(0, STUFEN + 1, PFOSTEN_JE):
			_zyl(Vector3(sx, y0 + i * sh + sh * 0.5 + GELAENDER_H * 0.5, z_start + vor * i * d), 0.03, GELAENDER_H, m["chrom"], null, -1.0, 6)


# ---------------------------------------------------------------- Innenausbau

## Deckenleuchte der Etage e: leuchtende Platte unter der Decke plus Punktlicht.
func _deckenlicht(x: float, z: float, e: int, energie := 2.2, reichweite := 13.0, farbe := Color(1.0, 0.96, 0.88)) -> void:
	var y := boden_y(e + 1) - DECKE - BELAG if e < etagen - 1 else boden_y(e + 1) - 0.06
	_box(Vector3(x, y - 0.03, z), Vector3(1.2, 0.05, 0.6), m["lampe"], false)
	_licht(Vector3(x, y - LICHT_ABSTAND, z), farbe, energie, reichweite)


## Gleichmaessiges Raster aus Deckenleuchten ueber die ganze Etage.
func _licht_raster(e: int, spalten: int, reihen: int, energie := 2.2, reichweite := 13.0) -> void:
	var ix := innen_x()
	var iz := innen_z()
	for i in spalten:
		for j in reihen:
			_deckenlicht(-ix + ix * 2.0 * (i + 0.5) / spalten, -iz + iz * 2.0 * (j + 0.5) / reihen, e, energie, reichweite)


## Innenwand (Putz) zwischen zwei Punkten (x, z; achsparallel) auf Etage e, optional mit Tueroeffnung
## (`tuer_bei` = Abstand vom Punkt a, negativ = keine Tuer).
func _innenwand(a: Vector2, b: Vector2, e: int, tuer_bei := -1.0, tuer_b := 1.6, dicke := 0.15) -> void:
	var y0 := boden_y(e)
	var h := etage_h - DECKE - BELAG
	var laenge := a.distance_to(b)
	var richtung := (b - a) / laenge
	var entlang_x := absf(richtung.x) > 0.5
	var teile: Array = [[0.0, laenge]]
	if tuer_bei >= 0.0:
		teile = [[0.0, tuer_bei - tuer_b * 0.5], [tuer_bei + tuer_b * 0.5, laenge]]
		var pm := a + richtung * tuer_bei
		var sturz_h := h - 2.3
		_box(Vector3(pm.x, y0 + 2.3 + sturz_h * 0.5, pm.y), Vector3(tuer_b, sturz_h, dicke) if entlang_x else Vector3(dicke, sturz_h, tuer_b), m["wand"], false)
	for t in teile:
		var l: float = t[1] - t[0]
		if l <= 0.05:
			continue
		var p: Vector2 = a + richtung * (float(t[0]) + l * 0.5)
		_box(Vector3(p.x, y0 + h * 0.5, p.y), Vector3(l, h, dicke) if entlang_x else Vector3(dicke, h, l), m["wand"])


## Tisch mit Platte und vier Beinen. `g` = (Breite, Hoehe, Tiefe). Rueckgabe: Gruppe (fuer Aufbauten).
func _tisch(pos: Vector3, g: Vector3, mat: Material, dreh := 0.0) -> Node3D:
	var n := _gruppe(pos, dreh)
	_box(Vector3(0, g.y - 0.03, 0), Vector3(g.x, 0.06, g.z), mat, false, n)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_box(Vector3(sx * (g.x * 0.5 - 0.08), (g.y - 0.06) * 0.5, sz * (g.z * 0.5 - 0.08)), Vector3(0.06, g.y - 0.06, 0.06), m["chrom"], false, n)
	var k := Node3D.new()
	k.position = Vector3(0, g.y * 0.5, 0)
	n.add_child(k)
	_kol(k, g)
	return n


## Stuhl (Sitz, Lehne, Beine). Blickrichtung des Sitzenden: lokal -z; `dreh` dreht um y.
func _stuhl(pos: Vector3, dreh := 0.0, mat: Material = null) -> void:
	var n := _gruppe(pos, dreh)
	var bezug: Material = mat if mat != null else m["dunkel"]
	_box(Vector3(0, 0.46, 0), Vector3(0.46, 0.06, 0.46), bezug, false, n)
	_box(Vector3(0, 0.78, 0.21), Vector3(0.46, 0.5, 0.05), bezug, false, n)
	_zyl(Vector3(0, 0.22, 0), 0.03, 0.44, m["chrom"], n, -1.0, 6)
	_zyl(Vector3(0, 0.02, 0), 0.24, 0.03, m["chrom"], n, -1.0, 10)


## Schreibtisch mit Monitor, Tastatur und Stuhl. Der Nutzer sitzt auf der +z-Seite und schaut nach -z.
func _schreibtisch(pos: Vector3, dreh := 0.0, bild := "buero_bild_tabelle") -> Node3D:
	var n := _tisch(pos, Vector3(1.6, 0.74, 0.8), m["eiche"], dreh)
	_box(Vector3(0, 1.07, -0.22), Vector3(0.62, 0.38, 0.03), m["dunkel"], false, n)
	_box(Vector3(0, 1.07, -0.2), Vector3(0.58, 0.34, 0.006), _bild_mat(bild, 0.9), false, n)
	_box(Vector3(0, 0.82, -0.24), Vector3(0.06, 0.16, 0.04), m["dunkel"], false, n)
	_box(Vector3(0, 0.755, -0.24), Vector3(0.26, 0.015, 0.18), m["dunkel"], false, n)
	_box(Vector3(0, 0.755, 0.1), Vector3(0.44, 0.02, 0.15), m["dunkel"], false, n)
	_box(Vector3(0.36, 0.752, 0.1), Vector3(0.07, 0.025, 0.11), m["dunkel"], false, n)
	_stuhl(pos + Vector3(0, 0, 0.75).rotated(Vector3.UP, deg_to_rad(dreh)), dreh)
	return n


## Buecherregal: Rahmen mit Boeden, gefuellt mit Buechern (sammeln sich fuer ein MultiMesh).
## Laenge entlang lokal x, Buchruecken zeigen nach +z; `doppelt`: auch nach -z.
func _buecherregal(pos: Vector3, laenge: float, hoehe: float, dreh := 0.0, doppelt := false, fuellung := 0.9) -> void:
	var n := _gruppe(pos, dreh)
	var tief := 0.6 if doppelt else 0.34
	_box(Vector3(0, hoehe * 0.5, 0), Vector3(laenge, hoehe, 0.03), m["holz"], false, n)
	for sx: float in [-1.0, 1.0]:
		_box(Vector3(sx * (laenge * 0.5 - 0.02), hoehe * 0.5, 0), Vector3(0.04, hoehe, tief), m["holz"], false, n)
	var faecher := int(hoehe / 0.38)
	var fach_h := hoehe / faecher
	for i in faecher + 1:
		_box(Vector3(0, minf(i * fach_h + 0.02, hoehe - 0.02), 0), Vector3(laenge - 0.04, 0.035, tief), m["holz"], false, n)
	var k := Node3D.new()
	k.position = Vector3(0, hoehe * 0.5, 0)
	n.add_child(k)
	_kol(k, Vector3(laenge, hoehe, tief))
	var seiten: Array[float] = [1.0]
	if doppelt:
		seiten.append(-1.0)
	for s in seiten:
		for i in faecher:
			var x := -laenge * 0.5 + 0.06
			while x < laenge * 0.5 - 0.1:
				var dicke := _rng.randf_range(0.03, 0.07)
				if _rng.randf() > fuellung:
					x += dicke * 4.0   # Luecke im Regal
					continue
				var h := fach_h * _rng.randf_range(0.6, 0.85)
				var t := _rng.randf_range(0.17, 0.24)
				var zb := s * ((0.02 + t * 0.5) if doppelt else (tief * 0.5 - t * 0.5 - 0.01))
				var lokal := Transform3D(Basis.IDENTITY.scaled(Vector3(dicke, h, t)), Vector3(x + dicke * 0.5, i * fach_h + 0.04 + h * 0.5, zb))
				_buch_t.append(n.transform * lokal)
				_buch_f.append(BUCH_FARBEN[_rng.randi() % BUCH_FARBEN.size()].lightened(_rng.randf() * 0.2))
				x += dicke + 0.004


## Baut alle gesammelten Buecher als ein MultiMesh (am Ende von `_bauen()` rufen).
func _buecher_bauen() -> void:
	if _buch_t.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = BoxMesh.new()
	mm.instance_count = _buch_t.size()
	for i in _buch_t.size():
		mm.set_instance_transform(i, _buch_t[i])
		mm.set_instance_color(i, _buch_f[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = m["buch"]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## Glasvitrine auf Sockel. `g` = (Breite, Gesamthoehe, Tiefe). Rueckgabe: Gruppe, Ausstellungsflaeche bei y = 0.9.
func _vitrine(pos: Vector3, g: Vector3, dreh := 0.0) -> Node3D:
	var n := _gruppe(pos, dreh)
	_box(Vector3(0, 0.45, 0), Vector3(g.x, 0.9, g.z), m["dunkel"], false, n)
	var glas := _box(Vector3(0, 0.9 + (g.y - 0.9) * 0.5, 0), Vector3(g.x - 0.04, g.y - 0.9, g.z - 0.04), m["glas"], false, n)
	glas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_box(Vector3(0, g.y + 0.02, 0), Vector3(g.x, 0.04, g.z), m["rahmen"], false, n)
	var k := Node3D.new()
	k.position = Vector3(0, g.y * 0.5, 0)
	n.add_child(k)
	_kol(k, g)
	return n


## Sitzbank mit Polster. Laenge entlang lokal x.
func _bank(pos: Vector3, laenge: float, dreh := 0.0, lehne := false) -> void:
	var n := _gruppe(pos, dreh)
	_box(Vector3(0, 0.42, 0), Vector3(laenge, 0.12, 0.55), m["leder"], false, n)
	for sx: float in [-1.0, 1.0]:
		_box(Vector3(sx * (laenge * 0.5 - 0.15), 0.18, 0), Vector3(0.08, 0.36, 0.5), m["chrom"], false, n)
	if lehne:
		_box(Vector3(0, 0.75, -0.24), Vector3(laenge, 0.5, 0.08), m["leder"], false, n)
	var k := Node3D.new()
	k.position = Vector3(0, 0.25, 0)
	n.add_child(k)
	_kol(k, Vector3(laenge, 0.5, 0.55))


## Topfpflanze aus Blattkugeln.
func _pflanze(pos: Vector3, hoehe := 1.6) -> void:
	var n := _gruppe(pos)
	_zyl(Vector3(0, 0.3, 0), 0.3, 0.6, m["topf"], n, 0.38, 12, true)
	_zyl(Vector3(0, 0.6 + hoehe * 0.25, 0), 0.04, hoehe * 0.5, m["holz"], n, -1.0, 6)
	for i in 5:
		var w := TAU * i / 5.0
		_kugel(Vector3(cos(w) * 0.28, 0.6 + hoehe * (0.45 + 0.1 * (i % 3)), sin(w) * 0.28), 0.34, m["blatt"], n, 0.8)
	_kugel(Vector3(0, 0.6 + hoehe * 0.75, 0), 0.4, m["blatt"], n, 0.9)


## Gerahmtes Bild an der Wand. `dreh`: 0 = Bildseite zeigt nach +z.
func _bild(pos: Vector3, g: Vector2, dreh: float, ordner: String, emission := 0.25) -> void:
	var n := _gruppe(pos, dreh)
	_box(Vector3.ZERO, Vector3(g.x + 0.12, g.y + 0.12, 0.05), m["holz"], false, n)
	_box(Vector3(0, 0, 0.028), Vector3(g.x, g.y, 0.006), _bild_mat(ordner, emission), false, n)


## Schild: dunkle Platte mit Schrift. `dreh`: 0 = lesbar von +z.
func _schild(txt: String, pos: Vector3, dreh: float, pixel := 0.006, farbe := Color(0.85, 0.95, 1.0), leuchtet := true) -> void:
	pixel *= SCHILD_MASS
	var n := _gruppe(pos, dreh)
	var l := _text(txt, Vector3(0, 0, 0.035), farbe, pixel, 0.0, leuchtet, n)
	var zeilen := txt.count("\n") + 1
	var laengste := 0
	for z in txt.split("\n"):
		laengste = maxi(laengste, z.length())
	_box(Vector3.ZERO, Vector3(laengste * 38.0 * pixel + 0.3, zeilen * 88.0 * pixel + 0.2, 0.05), m["dunkel"], false, n)
	l.render_priority = 1


## Theke/Tresen: Korpus mit Arbeitsplatte. `g` = (Breite, Hoehe, Tiefe).
func _theke(pos: Vector3, g: Vector3, dreh: float, korpus: Material, platte: Material) -> Node3D:
	var n := _gruppe(pos, dreh)
	_box(Vector3(0, (g.y - 0.05) * 0.5, 0), Vector3(g.x, g.y - 0.05, g.z), korpus, false, n)
	_box(Vector3(0, g.y - 0.025, 0), Vector3(g.x + 0.08, 0.05, g.z + 0.08), platte, false, n)
	var k := Node3D.new()
	k.position = Vector3(0, g.y * 0.5, 0)
	n.add_child(k)
	_kol(k, g)
	return n


## Ring (Torus), liegt flach in der xz-Ebene.
func _ring(pos: Vector3, innen: float, aussen: float, mat: Material, eltern: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = innen
	tm.outer_radius = aussen
	tm.rings = 24
	tm.ring_segments = 10
	mi.mesh = tm
	mi.material_override = mat
	mi.position = pos
	(eltern if eltern != null else self).add_child(mi)
	return mi


## Portikus vor der Front: `anzahl` Saeulen tragen ein Vordach in Hoehe `h`, Mitte bei x.
func _portikus(x: float, b: float, h: float, vor: float, anzahl: int, saeule: Material) -> void:
	var zf := tiefe * 0.5
	_box(Vector3(x, h + 0.2, zf + vor * 0.5), Vector3(b, 0.4, vor), m["fassade"], false)
	_box(Vector3(x, h - 0.04, zf + vor - 0.1), Vector3(b, 0.08, 0.08), m["akzent"], false)
	for i in anzahl:
		var sx := x - b * 0.5 + 0.5 + (b - 1.0) * i / float(anzahl - 1)
		_zyl(Vector3(sx, h * 0.5, zf + vor - 0.5), 0.32, h, saeule, null, -1.0, 16, true)
		_box(Vector3(sx, 0.1, zf + vor - 0.5), Vector3(0.9, 0.2, 0.9), saeule, false)


## Schriftzug an der Fassade ueber dem Eingang (leuchtet), optional mit Unterzeile.
func _fassaden_schrift(titel: String, unter: String, y: float, farbe: Color, pixel := 0.03, x := 0.0) -> void:
	var zf := tiefe * 0.5 + HAUT + 0.05
	_text(titel, Vector3(x, y, zf), farbe, pixel, 0.0, true)
	if unter != "":
		_text(unter, Vector3(x, y - pixel * 62.0, zf), Color(0.6, 0.95, 1.0), pixel * 0.32, 0.0, true)


## Fahnenmast mit Fahne.
func _fahne(pos: Vector3, farbe: Color, h := 7.0) -> void:
	_zyl(pos + Vector3(0, h * 0.5, 0), 0.06, h, m["chrom"], null, -1.0, 8, true)
	_box(pos + Vector3(0.75, h - 0.6, 0), Vector3(1.4, 0.9, 0.03), _std(farbe, 0.0, 0.0, 0.8, false), false)


## Leuchtbaender an den Geschosskanten der Front (Cyber-Akzent).
func _leuchtbaender() -> void:
	for e in range(1, etagen + 1):
		_box(Vector3(0, boden_y(e) - 0.1, tiefe * 0.5 + HAUT + 0.03), Vector3(breite, 0.08, 0.06), m["akzent"], false)
