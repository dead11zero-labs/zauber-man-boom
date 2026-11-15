extends Node3D
## Strassennetz von Synth-City: baut aus `StrassenDaten` Fahrbahnen, Kreuzungsflaechen, Zebrastreifen,
## Haltelinien, Ampeln (Phasen: `levels/ampel_steuerung.gd`), Bordsteine, Laternen, Strassenschilder,
## Holo-Wegweiser, Haltestellen und Bruecken ueber die Fluesse. Startet ausserdem den Bodenverkehr
## (`vehicles/verkehr.gd`). Wird von `stadt.gd: _strassen()` erzeugt.
## Vor dem Einhaengen setzen: `fluesse` (Mittellinien), `fluss_breite`, `fluss_tiefe`,
## `aussparungen` (Kreise [Mitte, Radius], in denen keine Bordsteine/Laternen stehen, z. B. die Plaza).
## `nacht_setzen(an)`: schaltet die Lichtquellen der Laternen (tagsueber aus, spart Leistung).
## Kleinteile landen in drei MultiMeshes (Metall, Leuchtteile, Farbe auf der Fahrbahn).

var fluesse: Array = []
var fluss_breite := 16.0
var fluss_tiefe := 2.4
var aussparungen: Array = []

const FAHRBAHN_DICKE := 0.12
const KREUZUNG_HOEHE := 0.14         ## Oberkante der Kreuzungsflaeche (deckt die Markierungen ab)
const FARBE_HOEHE := 0.15            ## Oberkante der aufgemalten Zeichen
const ASPHALT_KACHEL := 5.0
const ASPHALT_TINT := Color(0.55, 0.56, 0.58)
## Zebrastreifen und Haltelinie
const ZEBRA_ABSTAND := 1.0           ## Abstand vom Kreuzungsrand
const ZEBRA_TIEFE := 3.0
const ZEBRA_BALKEN := 0.5
const HALTELINIE_ABSTAND := 0.8      ## hinter dem Zebrastreifen
const HALTELINIE_DICKE := 0.4
## Ampel
const AMPEL_ABSTAND := 5.4           ## Mast steht so weit hinter dem Kreuzungsrand
const MAST_HOEHE := 6.2
const MAST_DICKE := 0.2
const KOPF := Vector3(0.5, 1.4, 0.4)   ## Signalgeber: quer, hoch, tief
const LAMPE := 0.3
const LAMPEN_ABSTAND := 0.42
const KOPF_HOEHE_OBEN := 5.1
const KOPF_HOEHE_SEITE := 3.0
const FUSS_HOEHE := 2.3
const KREUZUNG_LICHT := Vector3(8.0, 32.0, 7.5)   ## Energie, Reichweite, Hoehe
## Bordstein, Laternen
const STUECK := 4.0
const BORDSTEIN := Vector2(0.3, 0.18)
const LATERNE_ALLE := 9              ## jede 9. Stueck-Laenge (36 m), Seiten wechseln
const LATERNE_HOEHE := 7.0
const LATERNE_ARM := 1.8
const LATERNE_LICHT := Vector2(9.0, 24.0)   ## Energie, Reichweite (nur nachts an)
const KREUZUNG_FREI := 7.0           ## so weit vor einer Kreuzung enden Bordstein und Laternen
const FLUSS_FREI := 3.0
## Bruecken
const BRUECKE_UEBERSTAND := 5.0
const BRUECKE_GEHWEG := 1.5
const BRUECKE_DICKE := 0.9
const GELAENDER_H := 1.1
const PFOSTEN_ALLE := 3.0
## Schilder
const SCHILD_SICHT := 110.0
const WEGWEISER_HOEHE := 5.0
## Farben
const METALL := Color(0.13, 0.14, 0.17)
const BETON := Color(0.3, 0.3, 0.32)
const CYAN := Color(0.15, 0.9, 1.0)
const MAGENTA := Color(1.0, 0.2, 0.75)
const WARMWEISS := Color(1.0, 0.86, 0.62)
const FARBE_WEISS := Color(0.85, 0.93, 1.0)

const STEUERUNG := preload("res://levels/ampel_steuerung.gd")
const VERKEHR := preload("res://vehicles/verkehr.gd")

var _metall_t: Array[Transform3D] = []
var _metall_f: Array[Color] = []
var _leucht_t: Array[Transform3D] = []
var _leucht_f: Array[Color] = []
var _farbe_t: Array[Transform3D] = []
## Lampen der Ampeln, je Schluessel (siehe AmpelSteuerung.material) eine Liste von Transforms
var _lampen: Dictionary = {}
var _kreuzungen: Array[Dictionary] = []
var _m_asphalt: StandardMaterial3D
var _m_beton: StandardMaterial3D
var _m_glas: StandardMaterial3D
var _koerper: StaticBody3D
var _laternen_lichter: Array[OmniLight3D] = []


func _ready() -> void:
	_kreuzungen = StrassenDaten.kreuzungen()
	_m_asphalt = _textur_mat("strasse_asphalt", ASPHALT_KACHEL, ASPHALT_TINT)
	_m_beton = _textur_mat("brushed_concrete_04", 4.0, Color(0.55, 0.56, 0.6))
	_m_glas = StandardMaterial3D.new()
	_m_glas.albedo_color = Color(0.6, 0.85, 0.95, 0.14)
	_m_glas.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_m_glas.roughness = 0.05
	_koerper = StaticBody3D.new()
	add_child(_koerper)
	var steuerung := Node.new()
	steuerung.name = "AmpelSteuerung"
	steuerung.set_script(STEUERUNG)
	add_child(steuerung)
	for s in StrassenDaten.STRASSEN:
		_fahrbahn(s)
		_rand(s)
		_bruecken(s)
	for k in _kreuzungen:
		_kreuzung(k)
	for h in StrassenDaten.HALTESTELLEN:
		_haltestelle(h[0], h[1], h[2], h[3])
	for w in StrassenDaten.WEGWEISER:
		_wegweiser(w[0], w[1], w[2])
	_multimeshes(steuerung)
	var verkehr := Node3D.new()
	verkehr.name = "Verkehr"
	verkehr.set_script(VERKEHR)
	verkehr.set("kreuzungen", _kreuzungen)
	add_child(verkehr)
	steuerung.connect("phase_geaendert", Callable(verkehr, "ampel_phase"))


# ---------------------------------------------------------------- Helfer

func _textur_mat(ordner: String, kachel: float, tint: Color) -> StandardMaterial3D:
	var pfad := "res://assets/texturen/%s/" % ordner
	var t := StandardMaterial3D.new()
	t.albedo_texture = load(pfad + "diff.jpg")
	t.albedo_color = tint
	t.normal_enabled = true
	t.normal_texture = load(pfad + "nor.jpg")
	t.roughness_texture = load(pfad + "rough.jpg")
	t.uv1_triplanar = true
	t.uv1_world_triplanar = true
	t.uv1_scale = Vector3.ONE / kachel
	return t


func _p3(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x, y, p.y)


## Achsparalleler Quader im Metall-MultiMesh. `g2` = Ausdehnung in x und z, `y0`/`hoehe` senkrecht.
func _metall(mitte: Vector2, g2: Vector2, y0: float, hoehe: float, farbe := METALL) -> void:
	_metall_t.append(Transform3D(Basis.IDENTITY.scaled(Vector3(g2.x, hoehe, g2.y)), _p3(mitte, y0 + hoehe * 0.5)))
	_metall_f.append(farbe)


func _leucht(mitte: Vector2, g2: Vector2, y0: float, hoehe: float, farbe: Color) -> void:
	_leucht_t.append(Transform3D(Basis.IDENTITY.scaled(Vector3(g2.x, hoehe, g2.y)), _p3(mitte, y0 + hoehe * 0.5)))
	_leucht_f.append(farbe)


## Aufgemalte Flaeche auf der Fahrbahn (flacher Quader).
func _farbe(mitte: Vector2, g2: Vector2) -> void:
	_farbe_t.append(Transform3D(Basis.IDENTITY.scaled(Vector3(g2.x, 0.02, g2.y)), _p3(mitte, FARBE_HOEHE - 0.01)))


## Groesse (x, z) eines Quaders, der `laengs` Meter entlang der Richtung d und `quer` Meter quer dazu misst.
func _g2(d: Vector2, laengs: float, quer: float) -> Vector2:
	return Vector2(laengs, quer) if absf(d.x) > 0.5 else Vector2(quer, laengs)


func _box(mitte: Vector3, groesse: Vector3, mat: Material, kollision: bool) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = groesse
	m.mesh = bm
	m.material_override = mat
	m.position = mitte
	add_child(m)
	if kollision:
		_kollision(mitte, groesse)
	return m


func _kollision(mitte: Vector3, groesse: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var form := BoxShape3D.new()
	form.size = groesse
	cs.shape = form
	cs.position = mitte
	_koerper.add_child(cs)


func _schrift(text: String, pos: Vector3, d: Vector2, farbe: Color, groesse: int, pixel: float) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = groesse
	l.pixel_size = pixel
	l.modulate = farbe
	l.outline_modulate = Color(0.0, 0.03, 0.08)
	l.outline_size = 8
	l.shaded = false
	l.double_sided = false
	l.position = pos
	# Label3D zeigt nach +z, hier in Richtung d drehen
	l.rotation.y = atan2(d.x, d.y)
	l.visibility_range_end = SCHILD_SICHT
	add_child(l)
	return l


func _in_aussparung(p: Vector2) -> bool:
	for a in aussparungen:
		if p.distance_to(a[0]) < a[1]:
			return true
	return false


func _am_fluss(p: Vector2, rand: float) -> bool:
	for f: PackedVector2Array in fluesse:
		for i in f.size() - 1:
			if p.distance_to(Geometry2D.get_closest_point_to_segment(p, f[i], f[i + 1])) < fluss_breite * 0.5 + rand:
				return true
	return false


## Abstand, bis zu dem p (auf einer Strasse mit Richtung d) noch zur Kreuzung k gehoert.
func _in_kreuzung(p: Vector2, rand: float) -> bool:
	for k in _kreuzungen:
		var c: Vector2 = k["pos"]
		if absf(p.x - c.x) < k["breite_ns"] * 0.5 + rand and absf(p.y - c.y) < k["breite_ow"] * 0.5 + rand:
			return true
	return false


# ---------------------------------------------------------------- Fahrbahn, Bordstein, Laternen

func _fahrbahn(s: Dictionary) -> void:
	var m := ShaderMaterial.new()
	m.shader = load("res://strasse.gdshader")
	var pfad := "res://assets/texturen/strasse_asphalt/"
	m.set_shader_parameter("tex_diff", load(pfad + "diff.jpg"))
	m.set_shader_parameter("tex_nor", load(pfad + "nor.jpg"))
	m.set_shader_parameter("tex_rough", load(pfad + "rough.jpg"))
	m.set_shader_parameter("kachel", ASPHALT_KACHEL)
	m.set_shader_parameter("breite", s["breite"])
	var mitte: Vector2 = (s["a"] + s["b"]) * 0.5
	# Der Shader erwartet die Laengsachse auf lokal z
	var bahn := _box(_p3(mitte, FAHRBAHN_DICKE * 0.5), Vector3(s["breite"], FAHRBAHN_DICKE, StrassenDaten.laenge(s)), m, false)
	if not StrassenDaten.ist_ns(s):
		bahn.rotation.y = PI / 2.0
	bahn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Bordsteine beidseitig und Laternen im Wechsel, ausgespart an Kreuzungen, Fluessen und Plaetzen.
func _rand(s: Dictionary) -> void:
	var d: Vector2 = (s["b"] - s["a"]).normalized()
	var quer := StrassenDaten.rechts(d)
	var halb: float = s["breite"] * 0.5
	var anzahl := int(StrassenDaten.laenge(s) / STUECK)
	var seite := 1.0
	for i in anzahl:
		var p: Vector2 = s["a"] + d * (i + 0.5) * STUECK
		if _in_kreuzung(p, KREUZUNG_FREI) or _am_fluss(p, FLUSS_FREI) or _in_aussparung(p):
			continue
		for sg in [-1.0, 1.0]:
			_metall(p + quer * sg * (halb + BORDSTEIN.x * 0.5), _g2(d, STUECK, BORDSTEIN.x), 0.0, BORDSTEIN.y, BETON)
		if i % LATERNE_ALLE == LATERNE_ALLE / 2 and not s.get("klein", false):
			_laterne(p + quer * seite * (halb + 1.1), -quer * seite)
			seite = -seite


## Laterne: Mast, Ausleger zur Fahrbahn (Richtung `zur_bahn`), Leuchtkopf, Neonring am Fuss.
func _laterne(p: Vector2, zur_bahn: Vector2) -> void:
	_metall(p, Vector2(0.16, 0.16), 0.0, LATERNE_HOEHE)
	_metall(p, Vector2(0.4, 0.4), 0.0, 0.5)
	_leucht(p, Vector2(0.44, 0.44), 0.5, 0.06, CYAN)
	_metall(p + zur_bahn * LATERNE_ARM * 0.5, _g2(zur_bahn, LATERNE_ARM, 0.1), LATERNE_HOEHE - 0.1, 0.1)
	_leucht(p + zur_bahn * (LATERNE_ARM - 0.5), _g2(zur_bahn, 1.0, 0.32), LATERNE_HOEHE - 0.18, 0.08, WARMWEISS)
	var licht := OmniLight3D.new()
	licht.light_color = WARMWEISS
	licht.light_energy = LATERNE_LICHT.x
	licht.omni_range = LATERNE_LICHT.y
	licht.position = _p3(p + zur_bahn * (LATERNE_ARM - 0.5), LATERNE_HOEHE - 0.6)
	licht.visible = false
	add_child(licht)
	_laternen_lichter.append(licht)


## Strassenlaternen ein- oder ausschalten (von stadt.gd beim Tag/Nacht-Wechsel aufgerufen).
func nacht_setzen(an: bool) -> void:
	for l in _laternen_lichter:
		l.visible = an


# ---------------------------------------------------------------- Kreuzungen und Ampeln

func _kreuzung(k: Dictionary) -> void:
	var c: Vector2 = k["pos"]
	var flaeche := _box(_p3(c, KREUZUNG_HOEHE * 0.5), Vector3(k["breite_ns"], KREUZUNG_HOEHE, k["breite_ow"]), _m_asphalt, false)
	flaeche.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not k["ampel"]:
		return
	for arm: String in k["arme"]:
		if not k["arme"][arm]:
			continue
		var d := StrassenDaten.richtung(arm)
		var ns := arm == "n" or arm == "s"
		var breite: float = k["breite_ns"] if ns else k["breite_ow"]
		var rand: float = (k["breite_ow"] if ns else k["breite_ns"]) * 0.5
		_zebra(c, d, breite, rand)
		_ampel(c, d, breite, rand, ns, k["name_ow"] if ns else k["name_ns"])
	var licht := OmniLight3D.new()
	licht.light_color = WARMWEISS
	licht.light_energy = KREUZUNG_LICHT.x
	licht.omni_range = KREUZUNG_LICHT.y
	licht.position = _p3(c, KREUZUNG_LICHT.z)
	licht.visible = false
	add_child(licht)
	_laternen_lichter.append(licht)


## Zebrastreifen quer ueber den Arm und Haltelinie auf der ankommenden Spur.
func _zebra(c: Vector2, d: Vector2, breite: float, rand: float) -> void:
	var quer := StrassenDaten.rechts(-d)
	var mitte := c + d * (rand + ZEBRA_ABSTAND + ZEBRA_TIEFE * 0.5)
	var balken := int((breite - 1.0) / (ZEBRA_BALKEN * 2.0))
	for i in balken:
		var versatz := (i - (balken - 1) * 0.5) * ZEBRA_BALKEN * 2.0
		_farbe(mitte + quer * versatz, _g2(d, ZEBRA_TIEFE, ZEBRA_BALKEN))
	var linie := c + d * (rand + ZEBRA_ABSTAND + ZEBRA_TIEFE + HALTELINIE_ABSTAND) + quer * breite * 0.25
	_farbe(linie, _g2(d, HALTELINIE_DICKE, breite * 0.5 - 0.6))


## Ampel fuer den Verkehr, der ueber den Arm `d` auf die Kreuzung zufaehrt: Mast rechts der Fahrbahn,
## Ausleger ueber die Spur, Signalgeber oben und am Mast, Fussgaengersignal, Strassenschild.
func _ampel(c: Vector2, d: Vector2, breite: float, rand: float, ns: bool, quername: String) -> void:
	var quer := StrassenDaten.rechts(-d)
	var fuss := c + d * (rand + AMPEL_ABSTAND) + quer * (breite * 0.5 + 0.9)
	var spur := c + d * (rand + AMPEL_ABSTAND) + quer * breite * 0.25
	_metall(fuss, Vector2(MAST_DICKE, MAST_DICKE), 0.0, MAST_HOEHE)
	_metall(fuss, Vector2(0.45, 0.45), 0.0, 0.6)
	_leucht(fuss + d * (MAST_DICKE * 0.5 + 0.02), _g2(d, 0.04, 0.06), 0.7, MAST_HOEHE - 1.4, CYAN)
	var arm_laenge := fuss.distance_to(spur) + 0.4
	_metall((fuss + spur) * 0.5, _g2(quer, arm_laenge, 0.14), MAST_HOEHE - 0.2, 0.14)
	var achse := "ns" if ns else "ow"
	_signalgeber(spur, d, KOPF_HOEHE_OBEN, achse)
	_signalgeber(fuss - quer * 0.45, d, KOPF_HOEHE_SEITE, achse)
	# Fussgaengersignal: schaut quer ueber die Fahrbahn
	var fg := fuss - quer * 0.28
	_metall(fg, _g2(quer, 0.22, 0.34), FUSS_HOEHE, 0.7)
	_lampe("fuss_%s_rot" % achse, fg - quer * 0.12, -quer, FUSS_HOEHE + 0.52, 0.22)
	_lampe("fuss_%s_gruen" % achse, fg - quer * 0.12, -quer, FUSS_HOEHE + 0.18, 0.22)
	# Strassenschild am Ausleger: Name der Querstrasse
	var schild := (fuss + spur) * 0.5
	_metall(schild, _g2(quer, 3.4, 0.06), MAST_HOEHE, 0.55, Color(0.02, 0.05, 0.09))
	_leucht(schild, _g2(quer, 3.5, 0.08), MAST_HOEHE - 0.04, 0.04, CYAN)
	_schrift(quername, _p3(schild + d * 0.05, MAST_HOEHE + 0.28), d, Color(0.75, 0.97, 1.0), 44, 0.008)


## Signalgeber mit Rot, Gelb, Gruen; die Lampen schauen in Richtung d (dem Verkehr entgegen).
func _signalgeber(p: Vector2, d: Vector2, y_mitte: float, achse: String) -> void:
	_metall(p, _g2(d, KOPF.z, KOPF.x), y_mitte - KOPF.y * 0.5, KOPF.y)
	# Neonrahmen oben und unten: der Cyber-Anteil
	_leucht(p, _g2(d, KOPF.z + 0.06, KOPF.x + 0.06), y_mitte + KOPF.y * 0.5, 0.04, MAGENTA)
	var vorn := p + d * (KOPF.z * 0.5)
	_lampe("%s_rot" % achse, vorn, d, y_mitte + LAMPEN_ABSTAND, LAMPE)
	_lampe("%s_gelb" % achse, vorn, d, y_mitte, LAMPE)
	_lampe("%s_gruen" % achse, vorn, d, y_mitte - LAMPEN_ABSTAND, LAMPE)


func _lampe(schluessel: String, p: Vector2, d: Vector2, y_mitte: float, groesse: float) -> void:
	if not _lampen.has(schluessel):
		_lampen[schluessel] = []
	var g := _g2(d, 0.05, groesse)
	_lampen[schluessel].append(Transform3D(Basis.IDENTITY.scaled(Vector3(g.x, groesse, g.y)), _p3(p + d * 0.02, y_mitte)))


# ---------------------------------------------------------------- Bruecken

## Bruecken dieser Strasse ueber alle Fluesse: Platte mit Gehwegen, Gelaender mit Neonband, Pfeiler, Leuchten.
func _bruecken(s: Dictionary) -> void:
	var d: Vector2 = (s["b"] - s["a"]).normalized()
	var quer := StrassenDaten.rechts(d)
	for f: PackedVector2Array in fluesse:
		for i in f.size() - 1:
			var treffer: Variant = Geometry2D.segment_intersects_segment(s["a"], s["b"], f[i], f[i + 1])
			if treffer == null:
				continue
			var ufer: Vector2 = (f[i + 1] - f[i]).normalized()
			var schraege := maxf(absf(ufer.cross(d)), 0.3)
			var spanne := fluss_breite / schraege + BRUECKE_UEBERSTAND * 2.0
			var breite: float = s["breite"] + BRUECKE_GEHWEG * 2.0
			var mitte: Vector2 = treffer
			var g := _g2(d, spanne, breite)
			_box(_p3(mitte, 0.1 - BRUECKE_DICKE * 0.5), Vector3(g.x, BRUECKE_DICKE, g.y), _m_beton, true)
			for sg in [-1.0, 1.0]:
				var kante: Vector2 = mitte + quer * sg * (breite * 0.5 - 0.15)
				# Gehweg, Gelaender mit Handlauf, Neonband und Pfosten
				_metall(mitte + quer * sg * (s["breite"] * 0.5 + BRUECKE_GEHWEG * 0.5), _g2(d, spanne, BRUECKE_GEHWEG), 0.1, 0.1, BETON)
				_metall(kante, _g2(d, spanne, 0.12), GELAENDER_H - 0.1, 0.1)
				_leucht(kante, _g2(d, spanne, 0.06), GELAENDER_H - 0.3, 0.06, MAGENTA)
				var pfosten := int(spanne / PFOSTEN_ALLE)
				for k in pfosten + 1:
					_metall(kante + d * (k * spanne / pfosten - spanne * 0.5), Vector2(0.12, 0.12), 0.1, GELAENDER_H - 0.1)
				var gk := _g2(d, spanne, 0.2)
				_kollision(_p3(kante, GELAENDER_H * 0.5 + 0.1), Vector3(gk.x, GELAENDER_H, gk.y))
				# Leuchtpylone an den vier Brueckenkoepfen
				for ende in [-1.0, 1.0]:
					var kopf: Vector2 = kante + d * ende * (spanne * 0.5 - 0.3)
					_metall(kopf, Vector2(0.3, 0.3), 0.1, 3.2)
					_leucht(kopf, Vector2(0.34, 0.34), 2.4, 0.8, CYAN)
			# Pfeiler im Wasser
			for ende in [-1.0, 1.0]:
				var pf := _g2(d, 1.2, breite - 1.0)
				_box(_p3(mitte + d * ende * fluss_breite * 0.22, -fluss_tiefe * 0.5 - 0.3), Vector3(pf.x, fluss_tiefe + 0.2, pf.y), _m_beton, true)


# ---------------------------------------------------------------- Haltestellen, Wegweiser

## Haltestelle mit Glasdach, Rueckwand, Bank und Holo-Anzeige neben der Fahrbahn.
func _haltestelle(pos: Vector2, ns: bool, seite: float, text: String) -> void:
	var d := Vector2(0, 1) if ns else Vector2(1, 0)
	var quer := StrassenDaten.rechts(d) * seite
	var halb := 0.0
	for s in StrassenDaten.STRASSEN:
		if StrassenDaten.ist_ns(s) == ns and Geometry2D.get_closest_point_to_segment(pos, s["a"], s["b"]).distance_to(pos) < 1.0:
			halb = s["breite"] * 0.5
	var p := pos + quer * (halb + 2.4)
	var dach := _g2(d, 5.0, 2.0)
	_box(_p3(p, 2.7), Vector3(dach.x, 0.08, dach.y), _m_glas, false)
	_leucht(p - quer * 1.0, _g2(d, 5.0, 0.06), 2.62, 0.06, CYAN)
	var wand := _g2(d, 5.0, 0.08)
	_box(_p3(p + quer * 0.95, 1.4), Vector3(wand.x, 2.4, wand.y), _m_glas, true)
	for ende in [-1.0, 1.0]:
		_metall(p + quer * 0.95 + d * ende * 2.45, Vector2(0.12, 0.12), 0.0, 2.7)
		_metall(p - quer * 0.95 + d * ende * 2.45, Vector2(0.1, 0.1), 0.0, 2.7)
	_metall(p + quer * 0.55, _g2(d, 3.4, 0.45), 0.42, 0.08, Color(0.3, 0.32, 0.36))
	for ende in [-1.0, 1.0]:
		_metall(p + quer * 0.55 + d * ende * 1.4, _g2(d, 0.08, 0.4), 0.0, 0.42)
	var bk := _g2(d, 3.4, 0.45)
	_kollision(_p3(p + quer * 0.55, 0.25), Vector3(bk.x, 0.5, bk.y))
	_schrift(text + "   3 MIN", _p3(p + quer * 0.88, 2.25), -quer, Color(1.0, 0.85, 0.3), 36, 0.006)
	# Haltestellen-Stele mit leuchtendem H
	var stele := p - quer * 0.9 + d * 3.2
	_metall(stele, Vector2(0.14, 0.14), 0.0, 3.0)
	_leucht(stele, _g2(d, 0.08, 0.7), 2.3, 0.7, Color(0.3, 1.0, 0.45))
	_schrift("H", _p3(stele - quer * 0.06, 2.65), -quer, Color(0.02, 0.1, 0.04), 80, 0.006)


## Holo-Wegweiser: halbtransparente Tafel auf zwei Stelzen, Schrift schaut in Richtung d.
func _wegweiser(pos: Vector2, text: String, d: Vector2) -> void:
	var quer := StrassenDaten.rechts(d)
	var breite := text.length() * 0.2 + 1.0
	for ende in [-1.0, 1.0]:
		_metall(pos + quer * ende * breite * 0.5, Vector2(0.1, 0.1), 0.0, WEGWEISER_HOEHE + 0.6)
	var g := _g2(quer, breite, 0.05)
	var tafel := _box(_p3(pos, WEGWEISER_HOEHE), Vector3(g.x, 1.0, g.y), _m_glas, false)
	tafel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_leucht(pos, _g2(quer, breite, 0.07), WEGWEISER_HOEHE + 0.5, 0.05, CYAN)
	_leucht(pos, _g2(quer, breite, 0.07), WEGWEISER_HOEHE - 0.55, 0.05, CYAN)
	_schrift(text, _p3(pos + d * 0.05, WEGWEISER_HOEHE), d, Color(0.6, 0.97, 1.0), 40, 0.0075)


# ---------------------------------------------------------------- MultiMeshes

func _multimeshes(steuerung: Node) -> void:
	var wuerfel := BoxMesh.new()
	wuerfel.size = Vector3.ONE
	var m_metall := StandardMaterial3D.new()
	m_metall.vertex_color_use_as_albedo = true
	m_metall.metallic = 0.6
	m_metall.roughness = 0.45
	_mm(wuerfel, m_metall, _metall_t, _metall_f, true)
	var m_leucht := ShaderMaterial.new()
	m_leucht.shader = load("res://neon.gdshader")
	m_leucht.set_shader_parameter("staerke", 2.6)
	_mm(wuerfel, m_leucht, _leucht_t, _leucht_f, false)
	# Fahrbahnfarbe: leicht nachleuchtend, damit Zebrastreifen auch nachts lesbar sind
	var m_farbe := StandardMaterial3D.new()
	m_farbe.albedo_color = FARBE_WEISS
	m_farbe.roughness = 0.6
	m_farbe.emission_enabled = true
	m_farbe.emission = FARBE_WEISS
	m_farbe.emission_energy_multiplier = 0.25
	_mm(wuerfel, m_farbe, _farbe_t, [], false)
	for schluessel: String in _lampen:
		_mm(wuerfel, steuerung.call("material", schluessel), _lampen[schluessel], [], false)


func _mm(mesh: Mesh, mat: Material, transforms: Array, farben: Array, schatten: bool) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not farben.is_empty()
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		if mm.use_colors:
			mm.set_instance_color(i, farben[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	if not schatten:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
