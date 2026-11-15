class_name TerrainForm
extends RefCounted
## Gemeinsame Formel fuer Gelaendehoehe und Waldmaske.
## terrain_bauer.gd backt daraus die Terrain3D-Daten, wald.gd setzt danach die Baeume.
## Die Stadtplatte (Boden) ist ein Quadrat bis +-RAND, ausserhalb steigt das Gelaende an.

const RAND := 350.0     ## halbe Kantenlaenge der flachen Stadtplatte
const KARTE := 1024.0   ## halbe Kantenlaenge der Terrain3D-Karte
const UNTER := -1.5     ## unter der Stadtplatte (dort unsichtbar)

## Durchgang hinter dem Gurken-Wald und Plateau der Neustadt (Westen)
const PASS_X0 := -350.0       ## Beginn an der Stadtplatte
const PASS_X1 := -540.0       ## Ende am Plateau
const PASS_Z := -206.0        ## Hoehe des Gurken-Walds
const PASS_BREITE := 34.0     ## ebene Fahrbahn
const PLATEAU_H := 22.0
const PLATEAU_M := Vector2(-712.0, -206.0)
const PLATEAU_R := 175.0      ## halbe Kantenlaenge der ebenen Flaeche

static var _huegel: FastNoiseLite
static var _grat: FastNoiseLite
static var _wald: FastNoiseLite


static func _rauschen() -> void:
	if _huegel != null:
		return
	_huegel = FastNoiseLite.new()
	_huegel.seed = 11
	_huegel.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_huegel.frequency = 1.0 / 260.0
	_huegel.fractal_octaves = 4
	_grat = FastNoiseLite.new()
	_grat.seed = 23
	_grat.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_grat.frequency = 1.0 / 430.0
	_grat.fractal_octaves = 5
	_wald = FastNoiseLite.new()
	_wald.seed = 37
	_wald.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_wald.frequency = 1.0 / 170.0
	_wald.fractal_octaves = 3


## Abstand vom Zentrum, fast quadratisch (passt zur quadratischen Stadtplatte).
static func abstand(x: float, z: float) -> float:
	var ax := absf(x)
	var az := absf(z)
	var m := maxf(ax, az)
	if m < 0.001:
		return 0.0
	var n := minf(ax, az) / m
	return m * pow(1.0 + pow(n, 12.0), 1.0 / 12.0)


## Mittellinie des Durchgangs: schlaengelt sich, endet an beiden Seiten gerade.
static func pass_z(x: float) -> float:
	var t := clampf((PASS_X0 - x) / (PASS_X0 - PASS_X1), 0.0, 1.0)
	return PASS_Z + sin(t * TAU) * 34.0


## Sollhoehe der Fahrbahn: 0 an der Stadt, PLATEAU_H oben.
static func pass_h(x: float) -> float:
	return PLATEAU_H * (1.0 - smoothstep(PASS_X1, PASS_X0, x))


## 0..1: Maske der Fahrbahn (1 = exakt Sollhoehe), plus Abstand fuer die Flanken.
static func pass_maske(x: float, z: float) -> float:
	if x > PASS_X0 + 10.0 or x < PASS_X1 - 20.0:
		return 0.0
	var dz := absf(z - pass_z(x))
	return 1.0 - smoothstep(PASS_BREITE * 0.5, PASS_BREITE * 0.5 + 40.0, dz)


static func plateau_maske(x: float, z: float) -> float:
	var sd := maxf(maxf(absf(x - PLATEAU_M.x) - PLATEAU_R, absf(z - PLATEAU_M.y) - PLATEAU_R), 0.0)
	return 1.0 - smoothstep(0.0, 70.0, sd)


static func hoehe(x: float, z: float) -> float:
	var h := _hoehe_basis(x, z)
	# Steile Flanken links und rechts vom Durchgang
	if x < PASS_X0 + 10.0 and x > PASS_X1 - 20.0:
		var dz := absf(z - pass_z(x))
		var fl := smoothstep(PASS_BREITE * 0.5 + 25.0, PASS_BREITE * 0.5 + 60.0, dz)
		fl *= 1.0 - smoothstep(PASS_BREITE * 0.5 + 60.0, PASS_BREITE * 0.5 + 150.0, dz)
		h += fl * 48.0 * smoothstep(PASS_X0 + 10.0, PASS_X0 - 40.0, x)
	var m := maxf(pass_maske(x, z), plateau_maske(x, z))
	if m > 0.0:
		h = lerpf(h, pass_h(x), m)
	return h


static func _hoehe_basis(x: float, z: float) -> float:
	_rauschen()
	var d := abstand(x, z)
	if d < RAND - 12.0:
		return UNTER
	var basis := lerpf(UNTER, 0.0, smoothstep(RAND - 12.0, RAND, d))
	var r := maxf(d - RAND, 0.0)
	if r <= 0.0:
		return basis
	var huegel := (_huegel.get_noise_2d(x, z) * 0.5 + 0.5) * 38.0 * smoothstep(0.0, 140.0, r)
	var grat := 1.0 - absf(_grat.get_noise_2d(x, z))
	grat *= grat
	var berg := grat * 175.0 * smoothstep(120.0, 520.0, r)
	var vorberg := 40.0 * smoothstep(40.0, 300.0, r)
	var rand_hub := 230.0 * smoothstep(0.60, 0.97, maxf(absf(x), absf(z)) / KARTE)
	return basis + vorberg + huegel + berg + rand_hub


## 0..1: wie dicht der Wald hier steht (0 in der Stadt, auf Gipfeln und in Lichtungen).
static func waldwert(x: float, z: float, h: float) -> float:
	_rauschen()
	if abstand(x, z) < RAND + 8.0:
		return 0.0
	if maxf(pass_maske(x, z), plateau_maske(x, z)) > 0.02:
		return 0.0
	var m := _wald.get_noise_2d(x, z) * 0.5 + 0.5
	var dichte := smoothstep(0.38, 0.55, m)
	var hoehen_faktor := 1.0 - smoothstep(70.0, 115.0, h)
	return dichte * hoehen_faktor


## Steigung (Hoehe pro Meter) aus der Formel.
static func neigung(x: float, z: float) -> float:
	var dx := hoehe(x + 2.0, z) - hoehe(x - 2.0, z)
	var dz := hoehe(x, z + 2.0) - hoehe(x, z - 2.0)
	return sqrt(dx * dx + dz * dz) / 4.0
