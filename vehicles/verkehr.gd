extends Node3D
## Bodenverkehr: Schwebe-Autos fahren auf den Rundkursen aus `StrassenDaten.ROUTEN` (Rechtsverkehr),
## halten an roten Ampeln, hinter dem Vordermann und vor allem, was in den Gruppen "spieler" oder
## "verkehr_hindernis" steckt (z. B. Synth-Bots). Jedes Auto ist ein
## AnimatableBody3D, man kann also nicht hindurchlaufen.
## Vor dem Einhaengen setzen: `kreuzungen` (aus StrassenDaten.kreuzungen()).
## Die Ampelphase kommt ueber `ampel_phase(ns, ow)` (verbunden mit AmpelSteuerung.phase_geaendert).

var kreuzungen: Array = []

const MODELLE: Array[String] = ["auto_truck", "auto_flitzer", "auto_sportwagen"]
const MODELL_GROESSE := 2.4
const TINTS: Array[Color] = [Color(1, 1, 1), Color(1.0, 0.6, 0.95), Color(0.6, 0.9, 1.0), Color(1.0, 0.85, 0.5), Color(0.7, 1.0, 0.75)]
const AUTOS_JE_ROUTE := 3
const TEMPO := 11.0              ## m/s
const BESCHLEUNIGUNG := 5.0
const BREMSEN := 9.0
const SCHWEBEHOEHE := 0.75       ## Mitte des Autos ueber der Fahrbahn
const KOERPER := Vector3(2.0, 1.3, 4.4)
const HALT_VOR_KREUZUNG := 6.6   ## Haltepunkt: so weit vor dem Kreuzungsrand (hinter der Haltelinie)
const SICHT_AMPEL := 16.0        ## ab hier wird auf Rot reagiert
const ABSTAND_VORDERMANN := 8.0
const SPIELER_VORAUS := 11.0
const SPIELER_SEITE := 2.4
const DREH_TEMPO := 3.5
const GRUEN := 2                 ## AmpelSteuerung.Zustand.GRUEN
const HINDERNIS_SUCHE := 1.0     ## so oft (s) wird die Liste der Hindernisse erneuert
const UNTERLICHT := Vector3(1.7, 0.08, 3.4)

## Je Route: punkte (geschlossener Linienzug auf der rechten Spur), laengen (Start je Abschnitt),
## gesamt, halte ([s, ns?] vor jeder Ampelkreuzung), autos
var _routen: Array[Dictionary] = []
var _gruen_ns := false
var _gruen_ow := false
var _hindernisse: Array[Node] = []
var _hindernis_zeit := 0.0


func _ready() -> void:
	var szenen: Array[PackedScene] = []
	for name in MODELLE:
		szenen.append(load("res://imported_models/%s/%s.glb" % [name, name]) as PackedScene)
	var nr := 0
	for mitte: Array in StrassenDaten.ROUTEN:
		var route := _route_bauen(mitte)
		for i in AUTOS_JE_ROUTE:
			var auto := _auto_bauen(szenen[nr % szenen.size()], TINTS[nr % TINTS.size()])
			route["autos"].append({"node": auto, "s": route["gesamt"] * i / AUTOS_JE_ROUTE, "v": TEMPO, "gier": 0.0, "neu": true})
			nr += 1
		_routen.append(route)


func ampel_phase(ns: int, ow: int) -> void:
	_gruen_ns = ns == GRUEN
	_gruen_ow = ow == GRUEN


## Verschiebt den Rundkurs auf die rechte Spur und sammelt die Haltepunkte vor Ampelkreuzungen.
func _route_bauen(mitte: Array) -> Dictionary:
	var n := mitte.size()
	# rechte Spur je Abschnitt: Punkt auf der Spur und Richtung
	var spur_p: Array[Vector2] = []
	var spur_d: Array[Vector2] = []
	for i in n:
		var a: Vector2 = mitte[i]
		var b: Vector2 = mitte[(i + 1) % n]
		var d := (b - a).normalized()
		spur_d.append(d)
		spur_p.append(a + StrassenDaten.rechts(d) * StrassenDaten.breite_bei((a + b) * 0.5) * 0.25)
	# Ecken: Schnitt der verschobenen Geraden von Abschnitt i-1 und i
	var punkte: Array[Vector2] = []
	for i in n:
		var vor := (i + n - 1) % n
		var schnitt: Variant = Geometry2D.line_intersects_line(spur_p[vor], spur_d[vor], spur_p[i], spur_d[i])
		punkte.append(schnitt if schnitt != null else spur_p[i])
	var laengen: Array[float] = []
	var gesamt := 0.0
	for i in n:
		laengen.append(gesamt)
		gesamt += punkte[i].distance_to(punkte[(i + 1) % n])
	var halte: Array = []
	for i in n:
		var d := spur_d[i]
		var ns := absf(d.y) > 0.5
		var laenge := punkte[i].distance_to(punkte[(i + 1) % n])
		for k: Dictionary in kreuzungen:
			if not k["ampel"]:
				continue
			var c: Vector2 = k["pos"]
			var entlang := (c - punkte[i]).dot(d)
			var seitlich := absf((c - punkte[i]).dot(StrassenDaten.rechts(d)))
			# Kreuzung liegt auf diesem Abschnitt (nicht am Anfang, dort ist das Auto gerade abgebogen)
			if seitlich > 12.0 or entlang < 15.0 or entlang > laenge + 12.0:
				continue
			var rand: float = (k["breite_ow"] if ns else k["breite_ns"]) * 0.5
			halte.append([fposmod(laengen[i] + entlang - rand - HALT_VOR_KREUZUNG, gesamt), ns])
	return {"punkte": punkte, "laengen": laengen, "gesamt": gesamt, "halte": halte, "autos": []}


func _auto_bauen(szene: PackedScene, tint: Color) -> AnimatableBody3D:
	var auto := AnimatableBody3D.new()
	auto.sync_to_physics = false
	var cs := CollisionShape3D.new()
	var form := BoxShape3D.new()
	form.size = KOERPER
	cs.shape = form
	auto.add_child(cs)
	var modell: Node3D = szene.instantiate()
	# Die Modelle schauen entlang -X und sind ca. 1,9 m lang (wie die Ring-Autos in stadt.gd)
	modell.rotation_degrees.y = -90.0
	modell.scale = Vector3.ONE * MODELL_GROESSE
	auto.add_child(modell)
	for mi: MeshInstance3D in modell.find_children("*", "MeshInstance3D", true, false):
		for f in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(f)
			if mat is StandardMaterial3D:
				var kopie: StandardMaterial3D = mat.duplicate()
				kopie.albedo_color = tint
				mi.set_surface_override_material(f, kopie)
	# Schwebe-Unterlicht statt Reifen
	var licht := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = UNTERLICHT
	licht.mesh = lm
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.emission_enabled = true
	m.emission = tint.lerp(Color(0.2, 0.9, 1.0), 0.5)
	m.emission_energy_multiplier = 3.0
	licht.material_override = m
	licht.position = Vector3(0, -0.6, 0)
	licht.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	auto.add_child(licht)
	add_child(auto)
	return auto


## Position und Fahrtrichtung bei Wegstrecke s.
func _lage(route: Dictionary, s: float) -> Array:
	var punkte: Array[Vector2] = route["punkte"]
	var laengen: Array[float] = route["laengen"]
	var n := punkte.size()
	var i := n - 1
	while i > 0 and laengen[i] > s:
		i -= 1
	var a := punkte[i]
	var b := punkte[(i + 1) % n]
	var d := (b - a).normalized()
	return [a + d * (s - laengen[i]), d]


func _physics_process(delta: float) -> void:
	_hindernis_zeit -= delta
	if _hindernis_zeit <= 0.0:
		_hindernis_zeit = HINDERNIS_SUCHE
		_hindernisse = get_tree().get_nodes_in_group("spieler") + get_tree().get_nodes_in_group("verkehr_hindernis")
	for route in _routen:
		var gesamt: float = route["gesamt"]
		var autos: Array = route["autos"]
		for i in autos.size():
			var auto: Dictionary = autos[i]
			var lage := _lage(route, auto["s"])
			var pos: Vector2 = lage[0]
			var d: Vector2 = lage[1]
			var ziel := TEMPO
			# rote Ampel voraus
			for h: Array in route["halte"]:
				var weg := fposmod(h[0] - auto["s"], gesamt)
				var gruen: bool = _gruen_ns if h[1] else _gruen_ow
				if weg < SICHT_AMPEL and not gruen:
					ziel = minf(ziel, sqrt(2.0 * BREMSEN * maxf(weg - 0.3, 0.0)))
			# Vordermann auf demselben Rundkurs
			if autos.size() > 1:
				var vorn: Dictionary = autos[(i + 1) % autos.size()]
				var luecke := fposmod(vorn["s"] - auto["s"], gesamt)
				if luecke < ABSTAND_VORDERMANN + 6.0:
					ziel = minf(ziel, maxf(luecke - ABSTAND_VORDERMANN, 0.0) * 1.5)
			# Spieler oder Passant vor der Haube
			for h: Node in _hindernisse:
				var k := h as Node3D
				if k == null or not is_instance_valid(k) or k.global_position.y > 3.0:
					continue
				var sp := Vector2(k.global_position.x, k.global_position.z) - pos
				var voraus := sp.dot(d)
				if voraus > 0.0 and voraus < SPIELER_VORAUS and absf(sp.dot(StrassenDaten.rechts(d))) < SPIELER_SEITE:
					ziel = minf(ziel, maxf(voraus - 5.0, 0.0) * 1.5)
			var v: float = auto["v"]
			v = move_toward(v, ziel, (BESCHLEUNIGUNG if ziel > v else BREMSEN) * delta)
			auto["v"] = v
			auto["s"] = fposmod(auto["s"] + v * delta, gesamt)
			lage = _lage(route, auto["s"])
			pos = lage[0]
			d = lage[1]
			var gier := atan2(-d.x, -d.y)
			auto["gier"] = gier if auto["neu"] else lerp_angle(auto["gier"], gier, minf(DREH_TEMPO * delta, 1.0))
			auto["neu"] = false
			var node: AnimatableBody3D = auto["node"]
			node.global_transform = Transform3D(Basis(Vector3.UP, auto["gier"]), Vector3(pos.x, SCHWEBEHOEHE + sin(auto["s"] * 0.4) * 0.04, pos.y))
