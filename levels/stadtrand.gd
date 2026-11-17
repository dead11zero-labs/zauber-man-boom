extends Node3D
## Stadtrand-Guertel mit TerraBrush (addons/terrabrush, MIT): ein Gelaendering direkt ausserhalb der Stadtplatte
## (Abstand INNEN bis AUSSEN vom Zentrum, Metrik TerrainForm.abstand). Dort liegt sonst Terrain3D; stadt.gd stanzt
## Terrain3D im Kern des Guertels aus (ist_terrain3d_loch), an den Raendern ueberlappen beide auf gleicher Hoehe.
## Natuerlicher Uebergang: Das Pflaster der Platte franst ueber Erde und Schotter in die Wiese aus (Rauschen in den
## Splatmaps), Waelle heben und Mulden senken das Gelaende (aenderung), innen und aussen laeuft alles auf die
## Hoehe der Gelaendeformel aus. Im Durchgang zum Neo-Distrikt bleibt das Gelaende unveraendert.
## Hoehen werden beim Start berechnet (nur Pixel im Guertel), Kollision synchron.
## wald.gd holt Baumhoehen im Guertel ueber hoehe(), damit nichts schwebt.
## Keine Signale, keine Exporte.

const INNEN := 348.0              ## Guertel beginnt knapp unter der Plattenkante (Platte endet bei TerrainForm.RAND)
const AUSSEN := 404.0
const LOCH_INNEN := 352.0         ## Terrain3D-Stuetzpunkte zwischen LOCH_INNEN und LOCH_AUSSEN werden Loch
const LOCH_AUSSEN := 398.0
const ZONE := 129                 ## Pixel je Zonenkante (Zone = ZONE - 1 Meter)
const AUFLOESUNG := 1
const ZONEN_RING := 3             ## Zonenindex des Rings (Zonen 3 decken 320..448 m)
const HOEHE_VERSATZ := 0.03       ## ueber Terrain3D, gegen Flimmern in der Ueberlappung
const WALL_HOCH := 2.6
const MULDE_TIEF := 1.6
const PASS_SPERRE := 0.02         ## ab dieser Durchgangsmaske keine Aenderung
## Texturen: 0 Pflaster (wie die Platte), 1 Erde, 2 Wiese (wie Terrain3D), 3 Fels. Erde und Wiese sind vorab so
## getoent wie die Farbkarte von terrain_bauer.gd (assets/terrain/stadtrand/*_getoent.png, per PIL erzeugt),
## damit der Guertel aussen nahtlos an Terrain3D anschliesst.
const TEXTUREN: Array = [
	["res://assets/texturen/boden_pflaster/diff.jpg", "res://assets/texturen/boden_pflaster/nor.jpg"],
	["res://assets/terrain/stadtrand/forrest_ground_01_getoent.png", "res://assets/terrain/forrest_ground_01_nrm_r.png"],
	["res://assets/terrain/stadtrand/grass_ground_getoent.png", "res://assets/terrain/grass_ground_nrm_r.png"],
	["res://assets/terrain/rocky_terrain_alb_h.png", "res://assets/terrain/rocky_terrain_nrm_r.png"],
]
const TEXTUR_DETAIL := 20
## LOD-Gitter (TerraBrush-Voreinstellung 5 Stufen x 50 Reihen, 1 m, plus Anti-Tiling kostete am Stadtrand
## rund 25 Prozent Bildrate auf der Renoir-Grafik)
const LOD_STUFEN := 4
const LOD_REIHEN := 32
const LOD_ZELLE := 2.0
const TEXTUR_GROESSE := 1024      ## TerraBrush verlangt gleiches Format und gleiche Groesse fuer alle Texturen

static var _form: FastNoiseLite
static var _fein: FastNoiseLite


static func _rauschen() -> void:
	if _form != null:
		return
	_form = FastNoiseLite.new()
	_form.seed = 4711
	_form.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_form.frequency = 1.0 / 38.0
	_form.fractal_octaves = 3
	_fein = FastNoiseLite.new()
	_fein.seed = 815
	_fein.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_fein.frequency = 1.0 / 6.0
	_fein.fractal_octaves = 2


## 0 an der Plattenkante, 1 am Aussenrand.
static func anteil(x: float, z: float) -> float:
	return clampf((TerrainForm.abstand(x, z) - TerrainForm.RAND) / (AUSSEN - TerrainForm.RAND), 0.0, 1.0)


static func im_guertel(x: float, z: float) -> bool:
	var d := TerrainForm.abstand(x, z)
	return d >= INNEN and d <= AUSSEN


## Hoehenaenderung gegenueber der Gelaendeformel: Waelle (+) und Mulden (-), innen und aussen null.
static func aenderung(x: float, z: float) -> float:
	_rauschen()
	if TerrainForm.pass_maske(x, z) > PASS_SPERRE:
		return 0.0
	var t := anteil(x, z)
	var huelle := smoothstep(0.08, 0.35, t) * (1.0 - smoothstep(0.7, 1.0, t))
	var n := _form.get_noise_2d(x, z)
	return huelle * (n * WALL_HOCH if n > 0.0 else n * MULDE_TIEF)


static func hoehe(x: float, z: float) -> float:
	return TerrainForm.hoehe(x, z) + aenderung(x, z)


static func ist_terrain3d_loch(x: float, z: float) -> bool:
	var d := TerrainForm.abstand(x, z)
	return d >= LOCH_INNEN and d <= LOCH_AUSSEN


## Mischgewichte der vier Texturen (Summe 1).
static func gewichte(x: float, z: float, h_aend: float) -> Color:
	_rauschen()
	var t := anteil(x, z)
	var n1 := _fein.get_noise_2d(x, z)
	var n2 := _fein.get_noise_2d(z * 1.7 + 100.0, x * 1.7)
	var pflaster := 1.0 - smoothstep(0.02, 0.1 + 0.08 * n1, t)
	var erde := (1.0 - pflaster) * (1.0 - smoothstep(0.06, 0.18 + 0.1 * n2, t))
	erde = maxf(erde, clampf(-h_aend / MULDE_TIEF, 0.0, 1.0) * 0.7)
	var fels := clampf((h_aend - WALL_HOCH * 0.55) / (WALL_HOCH * 0.4), 0.0, 1.0) * 0.8
	var gras := maxf(0.0, 1.0 - pflaster - erde - fels)
	var summe := maxf(pflaster + erde + gras + fels, 0.0001)
	return Color(pflaster / summe, erde / summe, gras / summe, fels / summe)


func _ready() -> void:
	name = "Stadtrand"
	if not ClassDB.class_exists("TerraBrush"):
		push_warning("Stadtrand: TerraBrush-Erweiterung fehlt, Guertel entfaellt")
		return
	var tb: Node3D = ClassDB.instantiate("TerraBrush")
	tb.set("zonesSize", ZONE)
	tb.set("resolution", AUFLOESUNG)
	tb.set("dataPath", "user://terrabrush_stadtrand")
	tb.set("createCollisionInThread", false)
	tb.set("textureDetail", TEXTUR_DETAIL)
	tb.set("useAntiTile", false)
	tb.set("lodLevels", LOD_STUFEN)
	tb.set("lodRowsPerLevel", LOD_REIHEN)
	tb.set("lodInitialCellWidth", LOD_ZELLE)
	tb.set("heightBlendFactor", 0.0)
	tb.set("useSharpTransitions", false)
	tb.set("textureSets", _texturen())
	var zonen = ClassDB.instantiate("ZonesResource")
	var liste: Array = []
	for kz in range(-ZONEN_RING, ZONEN_RING + 1):
		for kx in range(-ZONEN_RING, ZONEN_RING + 1):
			if maxi(absi(kx), absi(kz)) == ZONEN_RING:
				liste.append(_zone(kx, kz))
	zonen.set("zones", liste)
	tb.set("terrainZones", zonen)
	add_child(tb)
	tb.call("onUpdateTerrainSettings")
	_schatten_aus.call_deferred(tb)


## Flaches Gelaende braucht keinen Schattenwurf; der Schattenpass ist auf der Renoir-Grafik der Engpass.
func _schatten_aus(tb: Node) -> void:
	for g: GeometryInstance3D in tb.find_children("*", "GeometryInstance3D", true, false):
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _texturen() -> Resource:
	var sets = ClassDB.instantiate("TextureSetsResource")
	var liste: Array = []
	for i in TEXTUREN.size():
		var t: Array = TEXTUREN[i]
		var ts = ClassDB.instantiate("TextureSetResource")
		ts.set("name", "Stadtrand%d" % i)
		ts.set("albedoTexture", _angleichen(t[0]))
		ts.set("normalTexture", _angleichen(t[1]))
		liste.append(ts)
	sets.set("textureSets", liste)
	return sets


## Laedt eine Textur als RGBA8 mit TEXTUR_GROESSE und Mipmaps (Pflaster-JPG hat kein Alpha, Terrain-PNGs schon).
func _angleichen(pfad: String) -> Texture2D:
	var img := (load(pfad) as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	if img.get_width() != TEXTUR_GROESSE or img.get_height() != TEXTUR_GROESSE:
		img.resize(TEXTUR_GROESSE, TEXTUR_GROESSE, Image.INTERPOLATE_BILINEAR)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Eine Zone: Hoehen (R), Loch (G) ausserhalb des Guertels, Splatmap fuer vier Texturen.
func _zone(kx: int, kz: int) -> Resource:
	var z = ClassDB.instantiate("ZoneResource")
	z.set("zonePosition", Vector2i(kx, kz))
	var breite := float(ZONE - 1)
	var x0 := (kx - 0.5) * breite
	var z0 := (kz - 0.5) * breite
	var px := (ZONE - 1) / AUFLOESUNG + 1
	var h := Image.create(px, px, false, Image.FORMAT_RGF)
	var sp := Image.create(px, px, false, Image.FORMAT_RGBA8)
	for j in px:
		for i in px:
			var wx := x0 + i * AUFLOESUNG
			var wz := z0 + j * AUFLOESUNG
			if not im_guertel(wx, wz):
				h.set_pixel(i, j, Color(0.0, 1.0, 0.0, 1.0))
				sp.set_pixel(i, j, Color(0.0, 0.0, 1.0, 0.0))
				continue
			var a := aenderung(wx, wz)
			h.set_pixel(i, j, Color(TerrainForm.hoehe(wx, wz) + a + HOEHE_VERSATZ, 0.0, 0.0, 1.0))
			sp.set_pixel(i, j, gewichte(wx, wz, a))
	z.set("heightMapImage", h)
	z.set("splatmapsImage", [sp])
	return z
