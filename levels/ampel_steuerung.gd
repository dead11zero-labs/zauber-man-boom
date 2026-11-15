extends Node
## Ampelsteuerung: schaltet alle Ampeln der Stadt im gleichen Takt (gruene Welle).
## Zwei Achsen, "ns" (Nord-Sued) und "ow" (Ost-West), mit deutscher Signalfolge:
## Rot -> Rot-Gelb -> Gruen -> Gelb -> Rot, dazwischen kurz alles Rot.
## Die Lampen sind MultiMeshes in `levels/strassennetz.gd`; hier liegen nur deren Materialien.
## Signal `phase_geaendert(ns, ow)`: Zustand je Achse (enum Zustand), fuer den Bodenverkehr.

signal phase_geaendert(ns: int, ow: int)

enum Zustand { ROT, ROT_GELB, GRUEN, GELB }

## Ablauf: [Dauer in s, Zustand ns, Zustand ow]
const ABLAUF: Array = [
	[1.0, Zustand.ROT_GELB, Zustand.ROT],
	[14.0, Zustand.GRUEN, Zustand.ROT],
	[2.5, Zustand.GELB, Zustand.ROT],
	[1.5, Zustand.ROT, Zustand.ROT],
	[1.0, Zustand.ROT, Zustand.ROT_GELB],
	[14.0, Zustand.ROT, Zustand.GRUEN],
	[2.5, Zustand.ROT, Zustand.GELB],
	[1.5, Zustand.ROT, Zustand.ROT],
]
const FARBEN := {
	"rot": Color(1.0, 0.1, 0.08),
	"gelb": Color(1.0, 0.75, 0.05),
	"gruen": Color(0.1, 1.0, 0.45),
}
const LEUCHTEN := 5.0        ## Emission einer eingeschalteten Lampe
const AUS_ANTEIL := 0.07     ## Resthelligkeit einer ausgeschalteten Lampe (Farbe bleibt erkennbar)

var _materialien: Dictionary = {}
var _schritt := 0
var _rest := 0.0


func _ready() -> void:
	_schritt = ABLAUF.size() - 1
	_weiter()


## Material einer Lampengruppe. Schluessel: "<achse>_<farbe>" fuer Fahrzeuge (ns_rot, ow_gruen ...)
## und "fuss_<achse>_<farbe>" fuer Fussgaenger, die die Strasse dieser Achse ueberqueren.
func material(schluessel: String) -> StandardMaterial3D:
	if not _materialien.has(schluessel):
		var m := StandardMaterial3D.new()
		m.emission_enabled = true
		m.roughness = 0.3
		_materialien[schluessel] = m
		_lampe_setzen(schluessel, false)
	return _materialien[schluessel]


func zustand(achse: String) -> int:
	return ABLAUF[_schritt][1 if achse == "ns" else 2]


func _process(delta: float) -> void:
	_rest -= delta
	if _rest <= 0.0:
		_weiter()


func _weiter() -> void:
	_schritt = (_schritt + 1) % ABLAUF.size()
	_rest = ABLAUF[_schritt][0]
	for schluessel: String in _materialien:
		_lampe_setzen(schluessel, _leuchtet(schluessel))
	phase_geaendert.emit(zustand("ns"), zustand("ow"))


func _leuchtet(schluessel: String) -> bool:
	var teile := schluessel.split("_")
	var farbe: String = teile[teile.size() - 1]
	var achse: String = teile[teile.size() - 2]
	var z := zustand(achse)
	if teile[0] == "fuss":
		# Fussgaenger gehen, solange die Fahrzeuge dieser Strasse Rot haben und der Querverkehr faehrt
		var quer_faehrt := zustand("ow" if achse == "ns" else "ns") == Zustand.GRUEN
		return quer_faehrt if farbe == "gruen" else not quer_faehrt
	match farbe:
		"rot":
			return z == Zustand.ROT or z == Zustand.ROT_GELB
		"gelb":
			return z == Zustand.GELB or z == Zustand.ROT_GELB
	return z == Zustand.GRUEN


func _lampe_setzen(schluessel: String, an: bool) -> void:
	var m: StandardMaterial3D = _materialien[schluessel]
	var farbe: Color = FARBEN[schluessel.get_slice("_", schluessel.get_slice_count("_") - 1)]
	m.albedo_color = farbe if an else farbe * AUS_ANTEIL
	m.emission = farbe
	m.emission_energy_multiplier = LEUCHTEN if an else AUS_ANTEIL
