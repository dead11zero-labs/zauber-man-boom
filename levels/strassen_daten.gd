class_name StrassenDaten
extends RefCounted
## Strassennetz von Synth-City als reine Daten (keine Nodes): Strassen, Kreuzungen, Routen des
## Bodenverkehrs, Haltestellen und Wegweiser. Alle Strassen laufen entlang der Weltachsen.
## Koordinaten sind Vector2(x, z). Genutzt von `stadt.gd` (Sperrzonen, Gelaender-Luecken),
## `levels/strassennetz.gd` (Bau) und `vehicles/verkehr.gd` (Fahrzeuge).

## name, a, b (Endpunkte), breite (m). `klein`: Stichstrasse ohne Ampel.
const STRASSEN: Array[Dictionary] = [
	{"name": "ZAUBER-ALLEE", "a": Vector2(0, -206), "b": Vector2(0, 236), "breite": 20.0},
	{"name": "TOWER-ALLEE", "a": Vector2(-345, -206), "b": Vector2(300, -206), "breite": 14.0},
	{"name": "RUNENSTRASSE", "a": Vector2(-300, -90), "b": Vector2(300, -90), "breite": 16.0},
	{"name": "MARKTSTRASSE", "a": Vector2(-300, 130), "b": Vector2(300, 130), "breite": 14.0},
	{"name": "SCHATTENKAI", "a": Vector2(-300, 198), "b": Vector2(300, 198), "breite": 12.0},
	{"name": "HAFENSTRASSE", "a": Vector2(205, -206), "b": Vector2(205, 198), "breite": 12.0},
	{"name": "OSTTANGENTE", "a": Vector2(300, -206), "b": Vector2(300, 198), "breite": 10.0},
	{"name": "BREZELWEG", "a": Vector2(-300, -90), "b": Vector2(-300, 198), "breite": 10.0},
	{"name": "ALTSTADTGASSE", "a": Vector2(0, -30), "b": Vector2(205, -30), "breite": 10.0},
	{"name": "BREZELSTICH", "a": Vector2(-300, 30), "b": Vector2(-283, 30), "breite": 8.0, "klein": true},
	{"name": "POPCORNSTICH", "a": Vector2(205, 40), "b": Vector2(227, 40), "breite": 8.0, "klein": true},
]

## Rundkurse des Bodenverkehrs (Mittellinien, im Uhrzeigersinn von oben gesehen; gefahren wird rechts).
const ROUTEN: Array = [
	[Vector2(0, -206), Vector2(205, -206), Vector2(205, -90), Vector2(0, -90)],
	[Vector2(205, -206), Vector2(300, -206), Vector2(300, 198), Vector2(205, 198)],
	[Vector2(0, 130), Vector2(205, 130), Vector2(205, 198), Vector2(0, 198)],
	[Vector2(-300, 130), Vector2(0, 130), Vector2(0, 198), Vector2(-300, 198)],
]

## Haltestellen: Position auf der Strassenmitte, Strasse laeuft Nord-Sued?, Seite (+1/-1), Anzeigetext
const HALTESTELLEN: Array = [
	[Vector2(0, -150), true, 1.0, "LINIE 1 // ZAUBER-TOWER"],
	[Vector2(80, -90), false, -1.0, "LINIE 4 // ALTSTADT"],
	[Vector2(205, 80), true, 1.0, "LINIE 7 // HAFEN"],
	[Vector2(-70, 130), false, 1.0, "LINIE 2 // NEON-MARKT"],
	[Vector2(-300, 60), true, -1.0, "LINIE 9 // BREZEL-STAND"],
]

## Holo-Wegweiser: Position, Text, Blickrichtung des Schilds (Einheitsvektor x/z)
const WEGWEISER: Array = [
	[Vector2(13, -100), "▲ ZAUBER-TOWER    ◀ GURKEN-WALD    ▶ WASSERTANK", Vector2(0, 1)],
	[Vector2(-13, -196), "◀ NEO-DISTRIKT    ▶ HAFEN", Vector2(0, 1)],
	[Vector2(13, 140), "▲ RUNEN-PLAZA    ◀ NEON-MARKT 24/7    ▶ SY-CI BURGERS", Vector2(0, -1)],
	[Vector2(195, 122), "▲ POPCORN-LABOR    ▼ SCHATTENKAI", Vector2(-1, 0)],
	[Vector2(-290, 122), "▲ BREZEL-STAND    ▶ NEON-MARKT 24/7", Vector2(1, 0)],
	[Vector2(13, 188), "▼ FLORONIA    ◀ BREZELWEG    ▶ HAFEN", Vector2(0, -1)],
]

const TOLERANZ := 0.5


static func ist_ns(s: Dictionary) -> bool:
	return is_equal_approx(s["a"].x, s["b"].x)


static func laenge(s: Dictionary) -> float:
	return (s["a"] as Vector2).distance_to(s["b"])


## Liegt p auf einer Strasse (halbe Breite plus `rand`)?
static func auf_strasse(p: Vector2, rand: float) -> bool:
	for s in STRASSEN:
		var q := Geometry2D.get_closest_point_to_segment(p, s["a"], s["b"])
		if p.distance_to(q) < s["breite"] * 0.5 + rand:
			return true
	return false


## Breite der Strasse, auf deren Mittellinie p liegt (sonst `ersatz`).
static func breite_bei(p: Vector2, ersatz := 10.0) -> float:
	for s in STRASSEN:
		if Geometry2D.get_closest_point_to_segment(p, s["a"], s["b"]).distance_to(p) < TOLERANZ:
			return s["breite"]
	return ersatz


## Alle Kreuzungen und Ecken: pos, breite_ns, breite_ow, name_ns, name_ow,
## arme (Dictionary Richtung -> bool fuer n, s, w, o), ampel (mind. drei Arme, keine Stichstrasse).
static func kreuzungen() -> Array[Dictionary]:
	var liste: Array[Dictionary] = []
	for v in STRASSEN:
		if not ist_ns(v):
			continue
		for h in STRASSEN:
			if ist_ns(h):
				continue
			var x: float = v["a"].x
			var z: float = h["a"].y
			var x0: float = minf(h["a"].x, h["b"].x)
			var x1: float = maxf(h["a"].x, h["b"].x)
			var z0: float = minf(v["a"].y, v["b"].y)
			var z1: float = maxf(v["a"].y, v["b"].y)
			if x < x0 - TOLERANZ or x > x1 + TOLERANZ or z < z0 - TOLERANZ or z > z1 + TOLERANZ:
				continue
			var arme := {"n": z0 < z - TOLERANZ, "s": z1 > z + TOLERANZ, "w": x0 < x - TOLERANZ, "o": x1 > x + TOLERANZ}
			var anzahl := 0
			for a: bool in arme.values():
				if a:
					anzahl += 1
			liste.append({
				"pos": Vector2(x, z), "breite_ns": v["breite"], "breite_ow": h["breite"],
				"name_ns": v["name"], "name_ow": h["name"], "arme": arme,
				"ampel": anzahl >= 3 and not v.get("klein", false) and not h.get("klein", false),
			})
	return liste


## Einheitsvektor (x, z) einer Arm-Richtung.
static func richtung(arm: String) -> Vector2:
	match arm:
		"n":
			return Vector2(0, -1)
		"s":
			return Vector2(0, 1)
		"w":
			return Vector2(-1, 0)
	return Vector2(1, 0)


## Rechte Seite einer Fahrtrichtung (von oben gesehen, x nach Osten, z nach Sueden).
static func rechts(fahrt: Vector2) -> Vector2:
	return Vector2(-fahrt.y, fahrt.x)
