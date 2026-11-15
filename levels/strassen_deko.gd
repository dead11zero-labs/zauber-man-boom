extends Node3D
## Strassen-Deko aus dem Props-Set (imported_models/strassen_props): Hydranten an den Gehwegen und kleine
## Baustellen aus Absperrungen und Leitkegeln. Positionen: Strasse (Name aus StrassenDaten), Anteil t entlang
## der Strasse und Seite (+1/-1). Alles mit einfacher Kollision. Wird von stadt.gd erzeugt. Keine Signale, keine Exporte.

const PROPS := preload("res://levels/strassen_props.gd")

const GEHWEG_ABSTAND := 1.8       ## Abstand der Props vom Fahrbahnrand
const HYDRANT_H := 1.2
const ABSPERRUNG_H := 1.1
const KEGEL_H := 0.75
## [Strasse, t, Seite]; t liegt zwischen den Kreuzungen und ausserhalb der Fluesse
const HYDRANTEN: Array = [
	["ZAUBER-ALLEE", 0.15, 1.0], ["ZAUBER-ALLEE", 0.33, -1.0], ["ZAUBER-ALLEE", 0.55, 1.0], ["ZAUBER-ALLEE", 0.85, -1.0],
	["RUNENSTRASSE", 0.30, -1.0], ["RUNENSTRASSE", 0.55, 1.0], ["RUNENSTRASSE", 0.88, -1.0],
	["MARKTSTRASSE", 0.30, 1.0], ["MARKTSTRASSE", 0.75, -1.0],
	["TOWER-ALLEE", 0.40, 1.0], ["TOWER-ALLEE", 0.85, -1.0],
	["HAFENSTRASSE", 0.35, 1.0], ["HAFENSTRASSE", 0.70, -1.0],
]
const BAUSTELLEN: Array = [
	["RUNENSTRASSE", 0.42, 1.0], ["MARKTSTRASSE", 0.62, -1.0], ["TOWER-ALLEE", 0.52, -1.0],
]


func _ready() -> void:
	name = "StrassenDeko"
	for h in HYDRANTEN:
		var p := _platz(h[0], h[1], h[2])
		_prop("pumpe", HYDRANT_H, p[0], p[1], Vector3(0.6, HYDRANT_H, 0.6))
	for b in BAUSTELLEN:
		_baustelle(b[0], b[1], b[2])


## Weltposition und Streckenrichtung (Winkel um y) fuer Strasse, Anteil t und Seite.
func _platz(strasse: String, t: float, seite: float) -> Array:
	for s in StrassenDaten.STRASSEN:
		if s["name"] != strasse:
			continue
		var a: Vector2 = s["a"]
		var b: Vector2 = s["b"]
		var d := (b - a).normalized()
		var q := a.lerp(b, t) + Vector2(-d.y, d.x) * seite * (float(s["breite"]) * 0.5 + GEHWEG_ABSTAND)
		return [Vector3(q.x, 0.0, q.y), atan2(-d.y, d.x)]
	push_warning("Strasse nicht gefunden: " + strasse)
	return [Vector3.ZERO, 0.0]


## Zwei Absperrungen hintereinander am Gehweg, davor und dahinter je ein Leitkegel.
func _baustelle(strasse: String, t: float, seite: float) -> void:
	var p := _platz(strasse, t, seite)
	var pos: Vector3 = p[0]
	var w: float = p[1]
	var laengs := Vector3(cos(w), 0.0, -sin(w))
	for i in 2:
		_prop("absperrung", ABSPERRUNG_H, pos + laengs * (i - 0.5) * 2.4, w, Vector3(1.97, ABSPERRUNG_H, 0.5))
	for k in [-1.5, -0.5, 0.5, 1.5]:
		_prop("kegel", KEGEL_H, pos + laengs * k * 2.4, w, Vector3(0.45, KEGEL_H, 0.45))


## Ein Prop mit Kollisionsquader `kol` (Breite, Hoehe, Tiefe), gedreht um `w`.
func _prop(art: String, hoehe: float, pos: Vector3, w: float, kol: Vector3) -> void:
	var n := PROPS.laden(art, hoehe)
	n.position = pos
	n.rotation.y = w
	add_child(n)
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = kol
	cs.shape = sh
	cs.position = Vector3(0, kol.y * 0.5, 0)
	sb.add_child(cs)
	n.add_child(sb)
