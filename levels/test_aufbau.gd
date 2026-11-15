extends Node3D
## Testraum (Meilenstein 3): fuenf Raetsel in einer Reihe suedlich vom Startpunkt (z = 130..155), je ein Baustein
## plus ein Kombiraetsel. Bausteine: PowerSource, Cable, Relay, Receiver, PressurePlate, Barrier.
## 1 Schalter -> Kabel -> Tor.  2 Zeitschalter (5 s), Tor zaehlt erst beim Durchgang.
## 3 UND-Relay: Schalter plus Fernschalter (Ladeschuss).  4 UND-Relay: Druckplatte halten und gleichzeitig schiessen.
## 5 Kombi: (A UND B) UND (Platte ODER C) -> Empfaenger-Lampe plus Tor.
## Raetsel-ids: testraum_1..5 (gespeichert in GameState.raetsel).

const QUELLE := preload("res://levels/power_source.gd")
const KABEL := preload("res://levels/cable.gd")
const RELAIS := preload("res://levels/relay.gd")
const EMPFAENGER := preload("res://levels/receiver.gd")
const PLATTE := preload("res://levels/pressure_plate.gd")
const SPERRE := preload("res://levels/barrier.gd")
const HINWEIS := preload("res://levels/hinweis_pulse.gd")

const Z_SCHALTER := 130.0
const Z_TOR := 150.0
const ZEIT_TIMER := 5.0
const CYAN := Color(0.2, 0.9, 1.0)
const PINK := Color(1.0, 0.3, 0.9)
const GRUEN := Color(0.3, 1.0, 0.5)
const GELB := Color(1.0, 0.85, 0.2)
const SPALTEN: Array[float] = [-72.0, -44.0, -16.0, 12.0, 52.0]


func _ready() -> void:
	add_child(HINWEIS.new())
	_raetsel_1(SPALTEN[0])
	_raetsel_2(SPALTEN[1])
	_raetsel_3(SPALTEN[2])
	_raetsel_4(SPALTEN[3])
	_raetsel_5(SPALTEN[4])


# --- Bausteine anlegen -------------------------------------------------------

func _quelle(pos: Vector3, farbe: Color, rid: String, ladung := false, dauer := 0.0) -> Node:
	var s = QUELLE.new()
	s.farbe = farbe
	s.braucht_ladung = ladung
	s.dauer = dauer
	s.set_meta("raetsel_id", rid)
	add_child(s)
	s.position = pos
	return s


func _platte(pos: Vector3, farbe: Color) -> Node:
	var p = PLATTE.new()
	p.farbe = farbe
	add_child(p)
	p.position = pos
	return p


func _relais(pos: Vector3, und: bool, farbe: Color) -> Node:
	var r = RELAIS.new()
	r.modus = 0 if und else 1
	r.farbe = farbe
	add_child(r)
	r.position = pos
	return r


func _tor(x: float, rid: String, farbe: Color, nur_durchgang := false) -> Node:
	var t = SPERRE.new()
	t.id = rid
	t.farbe = farbe
	t.erst_beim_durchgang = nur_durchgang
	add_child(t)
	t.position = Vector3(x, 0, Z_TOR)
	return t


## Kabel von `von` nach `nach`; liefert das Kabel als neuen Eingang.
func _kabel(von: Node, nach: Node) -> Node:
	var k = KABEL.new()
	add_child(k)
	k.verbinden(von, nach)
	return k


## Kabel von `von` zum Relay, Relay-Eingang ist das Kabel.
func _zu_relais(von: Node, r: Node) -> void:
	r.eingang_hinzu(_kabel(von, r))


func _zu_tor(von: Node, t: Node) -> void:
	t.eingang_setzen(_kabel(von, t))


# --- Die fuenf Raetsel -------------------------------------------------------

func _raetsel_1(x: float) -> void:
	var s := _quelle(Vector3(x - 3, 0, Z_SCHALTER), CYAN, "testraum_1")
	_zu_tor(s, _tor(x, "testraum_1", CYAN))


func _raetsel_2(x: float) -> void:
	var s := _quelle(Vector3(x - 9, 0, Z_SCHALTER), GELB, "testraum_2", false, ZEIT_TIMER)
	_zu_tor(s, _tor(x, "testraum_2", GELB, true))


func _raetsel_3(x: float) -> void:
	var a := _quelle(Vector3(x - 5, 0, Z_SCHALTER), CYAN, "testraum_3")
	var b := _quelle(Vector3(x + 7, 0, Z_SCHALTER - 24), PINK, "testraum_3", true)
	var r := _relais(Vector3(x, 0, 140), true, CYAN)
	_zu_relais(a, r)
	_zu_relais(b, r)
	_zu_tor(r, _tor(x, "testraum_3", CYAN))


func _raetsel_4(x: float) -> void:
	var p := _platte(Vector3(x - 6, 0, Z_SCHALTER + 4), GELB)
	var s := _quelle(Vector3(x + 6, 0, Z_SCHALTER + 4), CYAN, "testraum_4")
	var r := _relais(Vector3(x, 0, 141), true, GELB)
	_zu_relais(p, r)
	_zu_relais(s, r)
	_zu_tor(r, _tor(x, "testraum_4", GELB))


func _raetsel_5(x: float) -> void:
	var a := _quelle(Vector3(x - 12, 0, Z_SCHALTER), CYAN, "testraum_5")
	var b := _quelle(Vector3(x - 4, 0, Z_SCHALTER - 20), PINK, "testraum_5", true)
	var p := _platte(Vector3(x + 8, 0, Z_SCHALTER + 2), GELB)
	var c := _quelle(Vector3(x + 16, 0, Z_SCHALTER + 2), GRUEN, "testraum_5")
	var r1 := _relais(Vector3(x - 6, 0, 138), true, CYAN)
	var r2 := _relais(Vector3(x + 10, 0, 138), false, GELB)
	var r3 := _relais(Vector3(x, 0, 144), true, GRUEN)
	_zu_relais(a, r1)
	_zu_relais(b, r1)
	_zu_relais(p, r2)
	_zu_relais(c, r2)
	_zu_relais(r1, r3)
	_zu_relais(r2, r3)
	var lampe = EMPFAENGER.new()
	lampe.farbe = GRUEN
	add_child(lampe)
	lampe.position = Vector3(x + 12, 0, 148)
	lampe.eingang_setzen(r3)
	_zu_tor(r3, _tor(x, "testraum_5", GRUEN))
