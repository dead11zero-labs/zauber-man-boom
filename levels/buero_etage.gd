extends Node3D
## BueroEtage: ein Stockwerk im Zauber-Tower mit Buero-Interieur, sichtbar von der Aufzugfahrt aus.
## Ursprung = Turmmitte auf Hoehe der Bodenoberkante. Der Aufzugschacht (Loch im Boden) liegt bei `schacht_mitte`.
## Die Moebel werden pro Layout einmal zu wenigen Meshes (je Material eins)
## zusammengefasst und von allen Etagen mit gleichem Layout geteilt (Cache), damit 25 Etagen kaum Draw-Calls kosten.
## Layouts: 0 Grossraumbuero, 1 Konferenz und Chefbuero, 2 Kantine, 3 Rechenzentrum.
## Texturen: Poly Haven (assets/texturen/*) und selbst erzeugte Buero-Texturen (assets/texturen/buero_*).
## Exportiert: layout, nummer (Etagenzahl fuer das Schild), halbe_breite (halbe Innenkante), hat_decke (eigene
## Deckenplatte bauen), schacht_mitte, schacht.
## Die Etage ist betretbar: unsichtbare Kollision fuer Bodenplatte (mit Schachtloch) und Moebel (_kb).
## Keine Signale.

const LAYOUT_NAMEN: Array[String] = ["GROSSRAUMBÜRO", "KONFERENZ", "KANTINE", "RECHENZENTRUM"]
const RAUM_HOEHE := 5.4            ## lichte Hoehe bis zur Unterkante der naechsten Platte
const PLATTE_DICKE := 0.6
const BELAG_DICKE := 0.04
const DECKE_Y := 5.35              ## Mitte der abgehaengten Decke
const LAMPE_Y := 5.28
const SICHT_WEITE := 150.0         ## Meter, ab hier verschwindet das Interieur
const LICHT_ENERGIE := 1.7
const LICHT_REICHWEITE := 17.0
const LICHT_FARBE := Color(1.0, 0.95, 0.88)
const LICHT_AUSBLENDEN_AB := 70.0
const LICHT_AUSBLENDEN_LAENGE := 25.0
const SCHILD_HOEHE := 4.5
const SCHILD_PIXEL := 0.012
const FENSTER_UNTEN := 1.0
const FENSTER_HOEHE := 3.2
const FENSTER_ENERGIE := 0.55
const FENSTER_STEG_ABSTAND := 3.0

@export var layout := 0
@export var nummer := 1
@export var halbe_breite := 15.0
@export var hat_decke := true
@export var schacht_mitte := Vector2(0.0, -4.5)
@export var schacht := 5.0

static var _cache: Dictionary = {}
static var _mats: Dictionary = {}
static var _einheit: Dictionary = {}
static var _koll_cache: Dictionary = {}   ## Schluessel wie _cache: Liste [Transform3D, Vector3] der Moebel-Kollisionsboxen

var _gx := Transform3D.IDENTITY
var _batch: Dictionary = {}
var _kolls: Array = []
var _zufall := RandomNumberGenerator.new()


func _ready() -> void:
	var schluessel := "%d_%d_%s" % [layout, int(halbe_breite), hat_decke]
	if not _cache.has(schluessel):
		_kolls.clear()
		_cache[schluessel] = _bauen()
		_koll_cache[schluessel] = _kolls.duplicate()
	for e in _cache[schluessel]:
		var mi := MeshInstance3D.new()
		mi.mesh = e[0]
		mi.visibility_range_end = SICHT_WEITE
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	_kollision_bauen(_koll_cache[schluessel])
	var licht := OmniLight3D.new()
	licht.light_color = LICHT_FARBE
	licht.light_energy = LICHT_ENERGIE
	licht.omni_range = LICHT_REICHWEITE
	licht.position = Vector3(0.0, RAUM_HOEHE - 0.8, halbe_breite * 0.3)
	licht.distance_fade_enabled = true
	licht.distance_fade_begin = LICHT_AUSBLENDEN_AB
	licht.distance_fade_length = LICHT_AUSBLENDEN_LAENGE
	add_child(licht)
	if layout == 2:  # Kantine: grosser Saal, zusaetzliche Lichter ueber Kueche, Salatbar und Speisesaal
		for lp in [Vector3(0.55, 0, -0.55), Vector3(-0.55, 0, -0.5), Vector3(0.5, 0, 0.45), Vector3(-0.5, 0, 0.45), Vector3(0.0, 0, 0.0)]:
			var l2 := OmniLight3D.new()
			l2.light_color = LICHT_FARBE
			l2.light_energy = LICHT_ENERGIE
			l2.omni_range = LICHT_REICHWEITE
			l2.position = Vector3(lp.x * halbe_breite, RAUM_HOEHE - 0.8, lp.z * halbe_breite)
			l2.distance_fade_enabled = true
			l2.distance_fade_begin = LICHT_AUSBLENDEN_AB
			l2.distance_fade_length = LICHT_AUSBLENDEN_LAENGE
			add_child(l2)


# ---------------------------------------------------------------- Kollision

## Bodenplatte (mit Schachtloch) und Moebel als unsichtbare Kollisionsboxen, damit die Etage betretbar ist.
func _kollision_bauen(moebel: Array) -> void:
	var sb := StaticBody3D.new()
	add_child(sb)
	var h := schacht * 0.5
	var hx := halbe_breite
	var teile := [[-hx, hx, -hx, schacht_mitte.y - h], [-hx, hx, schacht_mitte.y + h, hx],
		[-hx, schacht_mitte.x - h, schacht_mitte.y - h, schacht_mitte.y + h], [schacht_mitte.x + h, hx, schacht_mitte.y - h, schacht_mitte.y + h]]
	for t in teile:
		_kshape(sb, Transform3D(Basis.IDENTITY, Vector3((t[0] + t[1]) * 0.5, BELAG_DICKE - PLATTE_DICKE * 0.5, (t[2] + t[3]) * 0.5)), Vector3(t[1] - t[0], PLATTE_DICKE, t[3] - t[2]))
	for m in moebel:
		_kshape(sb, m[0], m[1])


func _kshape(sb: StaticBody3D, xf: Transform3D, groesse: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = groesse
	cs.shape = bs
	cs.transform = xf
	sb.add_child(cs)


## Merkt eine Moebel-Kollisionsbox (Mitte `p`, Groesse `g`) relativ zur aktuellen Gruppe.
func _kb(p: Vector3, g: Vector3) -> void:
	_kolls.append([_gx * Transform3D(Basis.IDENTITY, p), g])


# ---------------------------------------------------------------- Materialien

static func _tex(ordner: String, kachel: float, tint: Color, metall := 0.0, rauh := 1.0) -> StandardMaterial3D:
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
	t.disable_ambient_light = true  # Innenraum: kein Himmels-Ambient, nur eigene Lampen
	return t


static func _std(c: Color, rauh := 0.6, metall := 0.0, emission := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rauh
	m.metallic = metall
	m.disable_ambient_light = true
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emission
	return m


static func _bild(ordner: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var tx := load("res://assets/texturen/%s/diff.jpg" % ordner)
	m.albedo_texture = tx
	m.albedo_color = Color(0.25, 0.25, 0.25)
	m.emission_enabled = true
	m.emission_texture = tx
	m.emission_energy_multiplier = 0.9
	m.roughness = 0.2
	m.disable_ambient_light = true
	return m


static func _material(name: String) -> Material:
	if _mats.has(name):
		return _mats[name]
	var m: Material
	match name:
		"teppich": m = _tex("buero_teppich", 2.0, Color(1, 1, 1))
		"teppich_rot": m = _tex("buero_teppich", 2.0, Color(1.5, 0.75, 0.75))
		"parkett": m = _tex("wood_table_001", 1.6, Color(1.0, 0.9, 0.78))
		"fliese": m = _tex("floor_tiles_06", 2.4, Color(0.9, 0.92, 0.95), 0.0, 0.8)
		"marmor": m = _tex("marble_01", 3.0, Color(0.95, 0.97, 1.0), 0.0, 0.7)
		"beton": m = _tex("brushed_concrete_04", 3.0, Color(0.75, 0.77, 0.8))
		"wand": m = _tex("buero_wand", 3.0, Color(1, 1, 1))
		"decke": m = _tex("buero_decke", 2.4, Color(1, 1, 1))
		"holz": m = _tex("wood_table_001", 1.4, Color(0.62, 0.45, 0.33))
		"holz_hell": m = _tex("wood_table_001", 1.4, Color(1.0, 0.93, 0.85))
		"metall": m = _tex("metal_plate", 2.0, Color(0.72, 0.75, 0.82), 0.8)
		"metall_dunkel": m = _tex("metal_plate", 2.0, Color(0.22, 0.24, 0.3), 0.85)
		"leder": m = _tex("leather_red_02", 1.0, Color(0.2, 0.22, 0.28))
		"leder_rot": m = _tex("leather_red_02", 1.0, Color(1.0, 0.8, 0.8))
		"gummi": m = _tex("rubber_tiles", 1.6, Color(0.25, 0.27, 0.32))
		"stein": m = _tex("square_tiles_02", 2.5, Color(0.85, 0.87, 0.95))
		"blatt": m = _tex("park_rasen", 0.7, Color(0.45, 0.8, 0.45))
		"weiss": m = _std(Color(0.9, 0.91, 0.93), 0.45)
		"schwarz": m = _std(Color(0.06, 0.07, 0.09), 0.35, 0.3)
		"karton": m = _std(Color(0.62, 0.48, 0.32), 0.95)
		"papier": m = _std(Color(0.92, 0.92, 0.9), 0.9)
		"erde": m = _std(Color(0.18, 0.12, 0.08), 1.0)
		"ordner_blau": m = _std(Color(0.2, 0.3, 0.6), 0.7)
		"ordner_rot": m = _std(Color(0.65, 0.18, 0.15), 0.7)
		"ordner_gruen": m = _std(Color(0.2, 0.5, 0.3), 0.7)
		"himmel": m = _std(Color(0.6, 0.78, 1.0), 0.3, 0.0, FENSTER_ENERGIE)
		"lampe": m = _std(Color(1.0, 0.95, 0.85), 0.4, 0.0, 0.9)
		"led_gruen": m = _std(Color(0.2, 1.0, 0.35), 0.4, 0.0, 2.0)
		"led_orange": m = _std(Color(1.0, 0.6, 0.15), 0.4, 0.0, 2.0)
		"automat_licht": m = _std(Color(0.9, 0.95, 1.0), 0.3, 0.0, 0.9)
		"bild_tabelle": m = _bild("buero_bild_tabelle")
		"bild_code": m = _bild("buero_bild_code")
		"bild_chart": m = _bild("buero_bild_chart")
		"whiteboard":
			var w := _tex("buero_whiteboard", 1.0, Color(1, 1, 1), 0.0, 0.25)
			w.uv1_triplanar = false
			w.uv1_scale = Vector3.ONE
			m = w
		"poster":
			var p := _tex("buero_poster", 1.0, Color(1, 1, 1), 0.0, 0.5)
			p.uv1_triplanar = false
			p.uv1_scale = Vector3.ONE
			m = p
		"stahl": m = _tex("kantine_stahl", 1.2, Color(1.25, 1.25, 1.3), 0.2, 0.45)
		"kfliese": m = _tex("kantine_fliese", 1.2, Color(1, 1, 1), 0.0, 0.35)
		"tablett": m = _std(Color(0.12, 0.13, 0.16), 0.5)
		"keramik": m = _std(Color(0.95, 0.95, 0.93), 0.2)
		"waerme": m = _std(Color(1.0, 0.55, 0.2), 0.4, 0.0, 1.6)
		"rot_k": m = _std(Color(0.7, 0.1, 0.08), 0.5)
		"gelb_k": m = _std(Color(0.9, 0.75, 0.15), 0.5)
		"blau_k": m = _std(Color(0.12, 0.3, 0.7), 0.5)
		"grau_k": m = _std(Color(0.35, 0.37, 0.4), 0.6)
		"flasche_gr": m = _std(Color(0.2, 0.55, 0.25, 0.8), 0.15)
		"flasche_br": m = _std(Color(0.55, 0.3, 0.1), 0.15)
		"saft": m = _std(Color(0.95, 0.55, 0.1), 0.3, 0.0, 0.25)
		"speiseplan":
			var sp := _tex("kantine_speiseplan", 1.0, Color(0.55, 0.55, 0.55), 0.0, 0.5)
			sp.uv1_triplanar = false
			sp.uv1_scale = Vector3.ONE
			sp.emission_enabled = true
			sp.emission_texture = sp.albedo_texture
			sp.emission_energy_multiplier = 0.45
			m = sp
		"kaffeeposter":
			var kp := _tex("kantine_poster_kaffee", 1.0, Color(1, 1, 1), 0.0, 0.5)
			kp.uv1_triplanar = false
			kp.uv1_scale = Vector3.ONE
			m = kp
		"essen_nudeln": m = _tex("kantine_essen_nudeln", 0.5, Color(1, 1, 1), 0.0, 0.4)
		"essen_reis": m = _tex("kantine_essen_reis", 0.5, Color(1, 1, 1), 0.0, 0.5)
		"essen_gemuese": m = _tex("kantine_essen_gemuese", 0.5, Color(1, 1, 1), 0.0, 0.4)
		"essen_eintopf": m = _tex("kantine_essen_eintopf", 0.5, Color(1, 1, 1), 0.0, 0.3)
		"essen_salat": m = _tex("kantine_essen_salat", 0.5, Color(1, 1, 1), 0.0, 0.4)
		"essen_kartoffeln": m = _tex("kantine_essen_kartoffeln", 0.5, Color(1, 1, 1), 0.0, 0.5)
		"essen_dessert": m = _tex("kantine_essen_dessert", 0.5, Color(1, 1, 1), 0.0, 0.4)
		"essen_suppe": m = _tex("kantine_essen_suppe", 0.5, Color(1, 1, 1), 0.0, 0.2)
		"glas":
			var g := _std(Color(0.7, 0.85, 0.95, 0.18), 0.05)
			g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m = g
		_:
			m = _std(Color(1, 0, 1))
	_mats[name] = m
	return m


# ---------------------------------------------------------------- Mesh-Sammler

static func _einheitsarrays(art: String) -> Array:
	if not _einheit.has(art):
		var pm: PrimitiveMesh
		match art:
			"zyl":
				var z := CylinderMesh.new()
				z.radial_segments = 14
				z.rings = 1
				pm = z
			"quad":
				var qm := QuadMesh.new()
				qm.size = Vector2.ONE
				pm = qm
			"kugel":
				var k := SphereMesh.new()
				k.radial_segments = 14
				k.rings = 7
				pm = k
			_:
				pm = BoxMesh.new()
		_einheit[art] = pm.get_mesh_arrays()
	return _einheit[art]


func _add(mat: String, art: String, lokal: Transform3D, skala: Vector3) -> void:
	var xf := _gx * lokal
	if not _batch.has(mat):
		_batch[mat] = {"v": PackedVector3Array(), "n": PackedVector3Array(), "t": PackedFloat32Array(), "uv": PackedVector2Array(), "i": PackedInt32Array()}
	var b: Dictionary = _batch[mat]
	var a := _einheitsarrays(art)
	var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var ns: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var ts: PackedFloat32Array = a[Mesh.ARRAY_TANGENT]
	var us: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
	var ix: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var bv: PackedVector3Array = b["v"]
	var bn: PackedVector3Array = b["n"]
	var bt: PackedFloat32Array = b["t"]
	var bu: PackedVector2Array = b["uv"]
	var bi: PackedInt32Array = b["i"]
	var basis := xf.basis
	var basis_n := basis.orthonormalized()
	var start := bv.size()
	for i in vs.size():
		bv.append(xf.origin + basis * (vs[i] * skala))
		bn.append(basis_n * ns[i])
		var t := basis_n * Vector3(ts[i * 4], ts[i * 4 + 1], ts[i * 4 + 2])
		bt.append(t.x)
		bt.append(t.y)
		bt.append(t.z)
		bt.append(ts[i * 4 + 3])
		bu.append(us[i])
	for i in ix:
		bi.append(start + i)
	b["v"] = bv
	b["n"] = bn
	b["t"] = bt
	b["uv"] = bu
	b["i"] = bi


## Quader: Mitte `p`, Kantenlaengen `s`, Drehung um Y (und optional um X) relativ zur Gruppe.
func _q(mat: String, p: Vector3, s: Vector3, rot_y := 0.0, rot_x := 0.0) -> void:
	_add(mat, "box", Transform3D(Basis.from_euler(Vector3(rot_x, rot_y, 0.0)), p), s)


## Flaches Bild (UV 0..1, Vorderseite +z), fuer Speiseplan und Poster.
func _quad(mat: String, p: Vector3, groesse: Vector2, rot_y := 0.0) -> void:
	_add(mat, "quad", Transform3D(Basis.from_euler(Vector3(0.0, rot_y, 0.0)), p), Vector3(groesse.x, groesse.y, 1.0))


func _z(mat: String, p: Vector3, radius: float, hoehe: float) -> void:
	_add(mat, "zyl", Transform3D(Basis.IDENTITY, p), Vector3(radius * 2.0, hoehe, radius * 2.0))


func _k(mat: String, p: Vector3, radius: float) -> void:
	_add(mat, "kugel", Transform3D(Basis.IDENTITY, p), Vector3.ONE * radius * 2.0)


## Setzt die Gruppentransformation (Position und Drehung um Y) fuer die folgenden Teile.
func _gruppe(p: Vector3, rot_y := 0.0) -> void:
	_gx = Transform3D(Basis(Vector3.UP, rot_y), p)


## Platte mit quadratischem Schachtloch aus vier Streifen.
func _platte(mat: String, y: float, dicke: float, hx: float) -> void:
	var h := schacht * 0.5
	var lx0 := schacht_mitte.x - h
	var lx1 := schacht_mitte.x + h
	var lz0 := schacht_mitte.y - h
	var lz1 := schacht_mitte.y + h
	var teile := [[-hx, hx, -hx, lz0], [-hx, hx, lz1, hx], [-hx, lx0, lz0, lz1], [lx1, hx, lz0, lz1]]
	_gruppe(Vector3.ZERO)
	for t in teile:
		_q(mat, Vector3((t[0] + t[1]) * 0.5, y, (t[2] + t[3]) * 0.5), Vector3(t[1] - t[0], dicke, t[3] - t[2]))


func _bauen() -> Array:
	_batch.clear()
	_zufall.seed = 1000 + layout * 17 + int(halbe_breite)
	var hx := halbe_breite
	_raumhuelle(hx)
	match layout:
		0: _grossraum(hx)
		1: _konferenz(hx)
		2: _kantine(hx)
		_: _rechenzentrum(hx)
	var ergebnis: Array = []
	for mat in _batch:
		var b: Dictionary = _batch[mat]
		var arr: Array = []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = b["v"]
		arr[Mesh.ARRAY_NORMAL] = b["n"]
		arr[Mesh.ARRAY_TANGENT] = b["t"]
		arr[Mesh.ARRAY_TEX_UV] = b["uv"]
		arr[Mesh.ARRAY_INDEX] = b["i"]
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		mesh.surface_set_material(0, _material(mat))
		ergebnis.append([mesh])
	_batch.clear()
	return ergebnis


# ---------------------------------------------------------------- Raumhuelle

func _raumhuelle(hx: float) -> void:
	var belag: String = ["teppich", "parkett", "beton", "beton"][layout]
	_platte(belag, BELAG_DICKE * 0.5, BELAG_DICKE, hx)
	if hat_decke:
		_platte("beton", -PLATTE_DICKE * 0.5, PLATTE_DICKE, hx)
	_platte("decke", DECKE_Y, 0.1, hx)
	_gruppe(Vector3.ZERO)
	# Waende (Putz), Sockelleiste, Fensterband mit Stegen
	var w := 0.08
	for s in [-1.0, 1.0]:
		_q("wand", Vector3(0, RAUM_HOEHE * 0.5, s * (hx - w * 0.5)), Vector3(2.0 * hx, RAUM_HOEHE, w))
		_q("wand", Vector3(s * (hx - w * 0.5), RAUM_HOEHE * 0.5, 0), Vector3(w, RAUM_HOEHE, 2.0 * hx - 2.0 * w))
		_q("gummi", Vector3(0, 0.08, s * (hx - w - 0.015)), Vector3(2.0 * hx - 0.2, 0.14, 0.03))
		_q("gummi", Vector3(s * (hx - w - 0.015), 0.08, 0), Vector3(0.03, 0.14, 2.0 * hx - 0.2))
		_q("himmel", Vector3(0, FENSTER_UNTEN + FENSTER_HOEHE * 0.5, s * (hx - w - 0.02)), Vector3(2.0 * hx - 0.6, FENSTER_HOEHE, 0.02))
		_q("himmel", Vector3(s * (hx - w - 0.02), FENSTER_UNTEN + FENSTER_HOEHE * 0.5, 0), Vector3(0.02, FENSTER_HOEHE, 2.0 * hx - 0.6))
		_q("metall_dunkel", Vector3(0, FENSTER_UNTEN, s * (hx - w - 0.04)), Vector3(2.0 * hx - 0.6, 0.1, 0.07))
		_q("metall_dunkel", Vector3(0, FENSTER_UNTEN + FENSTER_HOEHE, s * (hx - w - 0.04)), Vector3(2.0 * hx - 0.6, 0.1, 0.07))
		_q("metall_dunkel", Vector3(s * (hx - w - 0.04), FENSTER_UNTEN, 0), Vector3(0.07, 0.1, 2.0 * hx - 0.6))
		_q("metall_dunkel", Vector3(s * (hx - w - 0.04), FENSTER_UNTEN + FENSTER_HOEHE, 0), Vector3(0.07, 0.1, 2.0 * hx - 0.6))
	var x := -hx + 1.5
	while x < hx - 1.0:
		for s in [-1.0, 1.0]:
			_q("metall_dunkel", Vector3(x, FENSTER_UNTEN + FENSTER_HOEHE * 0.5, s * (hx - w - 0.04)), Vector3(0.1, FENSTER_HOEHE, 0.07))
			_q("metall_dunkel", Vector3(s * (hx - w - 0.04), FENSTER_UNTEN + FENSTER_HOEHE * 0.5, x), Vector3(0.07, FENSTER_HOEHE, 0.1))
		x += FENSTER_STEG_ABSTAND
	# Aufzugskern: Edelstahlwaende links, rechts, hinten, Sturz ueber der Kabinenoeffnung
	var h := schacht * 0.5
	var d := 0.3
	var cx := schacht_mitte.x
	var cz := schacht_mitte.y
	_q("metall", Vector3(cx, RAUM_HOEHE * 0.5, cz - h - d * 0.5 + 0.05), Vector3(schacht + 2.0 * d, RAUM_HOEHE, d))
	for s in [-1.0, 1.0]:
		_q("metall", Vector3(cx + s * (h + d * 0.5 - 0.05), RAUM_HOEHE * 0.5, cz), Vector3(d, RAUM_HOEHE, schacht))
		_q("metall_dunkel", Vector3(cx + s * (h + d + 0.02), RAUM_HOEHE * 0.5, cz + h - 0.2), Vector3(0.08, RAUM_HOEHE, 0.6))
	_q("metall", Vector3(cx, RAUM_HOEHE - 0.8, cz + h + 0.1), Vector3(schacht + 2.0 * d, 1.6, 0.2))
	_q("schwarz", Vector3(cx, 3.95, cz + h + 0.21), Vector3(1.2, 0.3, 0.02))
	# Deckenlampen (Paneele, weiches Weiss) ausserhalb des Schachts
	for lx in [-0.65, -0.22, 0.22, 0.65]:
		for lz in [-0.6, 0.0, 0.5, 0.85]:
			var p := Vector3(lx * hx, LAMPE_Y, lz * hx)
			if absf(p.x - cx) < h + 1.4 and absf(p.z - cz) < h + 1.4:
				continue
			_q("lampe", p, Vector3(1.2, 0.04, 0.6))


# ---------------------------------------------------------------- Moebel

func _schreibtisch(p: Vector3, rot_y: float, bild: String) -> void:
	_gruppe(p, rot_y)
	_kb(Vector3(0, 0.45, 0), Vector3(1.6, 0.9, 0.8))
	_q("holz_hell", Vector3(0, 0.74, 0), Vector3(1.6, 0.05, 0.8))
	for s in [-1.0, 1.0]:
		_q("metall", Vector3(s * 0.76, 0.37, 0), Vector3(0.04, 0.72, 0.76))
	_q("metall", Vector3(0, 0.45, -0.34), Vector3(1.5, 0.4, 0.03))
	# Monitor mit Standfuss; Bildschirm schaut nach -z
	_q("schwarz", Vector3(0.1, 0.77, -0.2), Vector3(0.22, 0.02, 0.16))
	_q("schwarz", Vector3(0.1, 0.9, -0.22), Vector3(0.05, 0.25, 0.03))
	_q("schwarz", Vector3(0.1, 1.12, -0.24), Vector3(0.58, 0.35, 0.03))
	_q(bild, Vector3(0.1, 1.12, -0.2565), Vector3(0.54, 0.31, 0.004))
	_q("weiss", Vector3(0.1, 0.77, 0.18), Vector3(0.42, 0.015, 0.14))
	_q("schwarz", Vector3(0.45, 0.77, 0.2), Vector3(0.06, 0.02, 0.1))
	_q("papier", Vector3(-0.5, 0.77, 0.05), Vector3(0.21, 0.02, 0.3), 0.2)
	_q("weiss", Vector3(-0.55, 0.82, -0.2), Vector3(0.09, 0.09, 0.09))


func _stuhl(p: Vector3, rot_y: float) -> void:
	_gruppe(p, rot_y)
	_q("leder", Vector3(0, 0.48, 0), Vector3(0.48, 0.08, 0.48))
	_q("leder", Vector3(0, 0.82, 0.22), Vector3(0.46, 0.55, 0.07))
	_z("metall_dunkel", Vector3(0, 0.27, 0), 0.025, 0.4)
	_q("metall_dunkel", Vector3(0, 0.05, 0), Vector3(0.62, 0.03, 0.06))
	_q("metall_dunkel", Vector3(0, 0.05, 0), Vector3(0.62, 0.03, 0.06), PI * 0.5)
	_q("metall_dunkel", Vector3(0, 0.05, 0), Vector3(0.62, 0.03, 0.06), PI * 0.25)


func _aktenschrank(p: Vector3, rot_y: float) -> void:
	_gruppe(p, rot_y)
	_kb(Vector3(0, 0.65, 0), Vector3(0.5, 1.3, 0.6))
	_q("metall", Vector3(0, 0.65, 0), Vector3(0.5, 1.3, 0.6))
	for i in 3:
		_q("metall_dunkel", Vector3(0, 0.25 + i * 0.4, 0.305), Vector3(0.44, 0.34, 0.012))
		_q("schwarz", Vector3(0, 0.38 + i * 0.4, 0.32), Vector3(0.18, 0.025, 0.025))


func _regal(p: Vector3, rot_y: float, breite := 1.6) -> void:
	_gruppe(p, rot_y)
	_kb(Vector3(0, 1.1, 0), Vector3(breite, 2.2, 0.4))
	for s in [-1.0, 1.0]:
		_q("metall_dunkel", Vector3(s * (breite * 0.5 - 0.02), 1.1, 0), Vector3(0.04, 2.2, 0.4))
	_q("metall_dunkel", Vector3(0, 1.1, -0.19), Vector3(breite, 2.2, 0.02))
	for i in 5:
		var y := 0.15 + i * 0.5
		_q("metall", Vector3(0, y, 0), Vector3(breite, 0.03, 0.4))
		var x := -breite * 0.5 + 0.1
		while x < breite * 0.5 - 0.15 and i < 4:
			var bw := _zufall.randf_range(0.07, 0.14)
			var mat: String = ["ordner_blau", "ordner_rot", "ordner_gruen", "karton", "papier"][_zufall.randi() % 5]
			_q(mat, Vector3(x + bw * 0.5, y + 0.22, 0.0), Vector3(bw, _zufall.randf_range(0.28, 0.4), 0.3))
			x += bw + 0.01


func _pflanze(p: Vector3, hoch := 1.5) -> void:
	_gruppe(p)
	_kb(Vector3(0, 0.6, 0), Vector3(0.5, 1.2, 0.5))
	_z("stein", Vector3(0, 0.25, 0), 0.26, 0.5)
	_z("erde", Vector3(0, 0.5, 0), 0.24, 0.02)
	_z("holz", Vector3(0, 0.5 + hoch * 0.25, 0), 0.03, hoch * 0.5)
	_k("blatt", Vector3(0, 0.5 + hoch * 0.6, 0), 0.4)
	_k("blatt", Vector3(0.2, 0.5 + hoch * 0.45, 0.1), 0.3)
	_k("blatt", Vector3(-0.18, 0.5 + hoch * 0.8, -0.1), 0.28)


func _sofa(p: Vector3, rot_y: float, laenge := 2.2) -> void:
	_gruppe(p, rot_y)
	_kb(Vector3(0, 0.45, 0), Vector3(laenge, 0.9, 0.9))
	_q("leder_rot", Vector3(0, 0.28, 0), Vector3(laenge, 0.36, 0.9))
	_q("leder_rot", Vector3(0, 0.62, -0.38), Vector3(laenge, 0.5, 0.2))
	for s in [-1.0, 1.0]:
		_q("leder_rot", Vector3(s * (laenge * 0.5 - 0.1), 0.45, 0), Vector3(0.2, 0.3, 0.9))
	_q("metall_dunkel", Vector3(0, 0.05, 0), Vector3(laenge - 0.1, 0.1, 0.8))
	_q("teppich_rot", Vector3(-laenge * 0.2, 0.5, 0.05), Vector3(0.4, 0.1, 0.4), 0.3)


func _tisch_rund(p: Vector3, mit_stuehlen := true) -> void:
	_gruppe(p)
	_kb(Vector3(0, 0.4, 0), Vector3(1.2, 0.8, 1.2))
	_z("holz_hell", Vector3(0, 0.74, 0), 0.6, 0.04)
	_z("metall", Vector3(0, 0.37, 0), 0.05, 0.72)
	_z("metall_dunkel", Vector3(0, 0.02, 0), 0.3, 0.04)
	if mit_stuehlen:
		for i in 4:
			var w := TAU * i / 4.0 + 0.4
			_stuhl(p + Vector3(sin(w), 0, cos(w)) * 0.95, w)
	_gruppe(p)
	_z("weiss", Vector3(0.1, 0.8, 0.05), 0.04, 0.08)


func _wandbild(mat: String, p: Vector3, s: Vector2, rot_y: float) -> void:
	_gruppe(p, rot_y)
	_q("metall_dunkel", Vector3(0, 0, 0), Vector3(s.x + 0.08, s.y + 0.08, 0.04))
	_q(mat, Vector3(0, 0, 0.025), Vector3(s.x, s.y, 0.01))


func _grossraum(hx: float) -> void:
	var xs := [-0.78 * hx, -0.4 * hx, 0.4 * hx, 0.78 * hx]
	var zs := [0.2 * hx, 0.55 * hx, 0.88 * hx]
	var bilder := ["bild_tabelle", "bild_code", "bild_chart"]
	var n := 0
	for z in zs:
		for x in xs:
			_schreibtisch(Vector3(x, 0, z), 0.0, bilder[n % 3])
			_stuhl(Vector3(x, 0, z + 0.85), _zufall.randf_range(-0.5, 0.5))
			n += 1
	_gruppe(Vector3.ZERO)
	_q("teppich_rot", Vector3(0, 0.05, 0.55 * hx), Vector3(0.45 * hx, 0.012, 0.9 * hx))
	for sz in [-0.1, 0.45]:
		_aktenschrank(Vector3(-hx + 0.5, 0, sz * hx), PI * 0.5)
		_aktenschrank(Vector3(hx - 0.5, 0, sz * hx), -PI * 0.5)
	_regal(Vector3(-hx + 0.4, 0, 0.8 * hx), PI * 0.5, 2.4)
	_regal(Vector3(hx - 0.4, 0, 0.8 * hx), -PI * 0.5, 2.4)
	_wandbild("whiteboard", Vector3(0, 2.0, hx - 0.12), Vector2(3.0, 1.5), PI)
	_wandbild("poster", Vector3(-hx + 0.12, 2.2, 0.35 * hx), Vector2(1.0, 1.5), PI * 0.5)
	_wandbild("poster", Vector3(hx - 0.12, 2.2, 0.35 * hx), Vector2(1.0, 1.5), -PI * 0.5)
	for px in [-0.9, 0.9]:
		_pflanze(Vector3(px * hx, 0, hx - 0.8))
	_pflanze(Vector3(-hx + 0.8, 0, -hx + 0.8), 1.8)
	_pflanze(Vector3(hx - 0.8, 0, -hx + 0.8), 1.8)
	# Drucker auf Schrank an der Westwand
	_gruppe(Vector3(-hx + 0.8, 0, 0.3 * hx), PI * 0.5)
	_q("metall", Vector3(0, 0.4, 0), Vector3(0.9, 0.8, 0.6))
	_kb(Vector3(0, 0.4, 0), Vector3(0.9, 0.8, 0.6))
	_q("weiss", Vector3(0, 0.9, 0), Vector3(0.7, 0.25, 0.5))
	_q("led_gruen", Vector3(0.25, 0.97, 0.26), Vector3(0.03, 0.02, 0.01))


func _konferenz(hx: float) -> void:
	var l := hx * 0.5
	var zc := 0.55 * hx
	_gruppe(Vector3.ZERO)
	_q("teppich_rot", Vector3(0, 0.05, zc), Vector3(l * 1.4, 0.012, 0.6 * hx))
	_q("holz", Vector3(0, 0.74, zc), Vector3(l, 0.06, 1.7))
	_kb(Vector3(0, 0.4, zc), Vector3(l, 0.8, 1.7))
	for s in [-0.35, 0.35]:
		_q("metall_dunkel", Vector3(s * l, 0.37, zc), Vector3(0.1, 0.72, 1.2))
	for i in 5:
		var x := -l * 0.4 + i * (l * 0.8 / 4.0)
		_stuhl(Vector3(x, 0, zc - 1.2), PI)
		_stuhl(Vector3(x, 0, zc + 1.2), 0.0)
		_gruppe(Vector3.ZERO)
		_q("papier", Vector3(x, 0.78, zc - 0.5), Vector3(0.21, 0.01, 0.3))
		_q("papier", Vector3(x, 0.78, zc + 0.5), Vector3(0.21, 0.01, 0.3))
	_stuhl(Vector3(-l * 0.5 - 0.9, 0, zc), PI * 0.5)
	_stuhl(Vector3(l * 0.5 + 0.9, 0, zc), -PI * 0.5)
	_gruppe(Vector3.ZERO)
	_z("weiss", Vector3(0, 0.82, zc), 0.12, 0.1)
	_q("schwarz", Vector3(0.6, 0.78, zc), Vector3(0.2, 0.02, 0.2))
	# Grosser Wandbildschirm und Sideboard
	_wandbild("bild_chart", Vector3(0, 2.4, hx - 0.14), Vector2(4.2, 2.3), PI)
	_gruppe(Vector3(0, 0, hx - 0.5))
	_q("holz", Vector3(0, 0.4, 0), Vector3(4.0, 0.8, 0.5))
	_kb(Vector3(0, 0.4, 0), Vector3(4.0, 0.8, 0.5))
	_q("marmor", Vector3(0, 0.82, 0), Vector3(4.1, 0.04, 0.55))
	# Chefbuero in der Westecke: grosser Schreibtisch, Regalwand, Sofaecke im Osten
	_schreibtisch(Vector3(-hx + 3.5, 0, 0.2 * hx), PI * 0.5, "bild_code")
	_stuhl(Vector3(-hx + 4.4, 0, 0.2 * hx), PI * 0.5)
	_regal(Vector3(-hx + 0.4, 0, 0.12 * hx), PI * 0.5, 2.4)
	_sofa(Vector3(hx - 1.2, 0, 0.1 * hx), -PI * 0.5, 2.4)
	_gruppe(Vector3(hx - 3.0, 0, 0.1 * hx))
	_q("marmor", Vector3(0, 0.4, 0), Vector3(0.7, 0.04, 1.2))
	_q("metall_dunkel", Vector3(0, 0.2, 0), Vector3(0.6, 0.4, 1.1))
	_wandbild("poster", Vector3(hx - 0.12, 2.2, 0.55 * hx), Vector2(1.0, 1.5), -PI * 0.5)
	_wandbild("whiteboard", Vector3(-hx + 0.12, 2.2, 0.62 * hx), Vector2(2.4, 1.2), PI * 0.5)
	for px in [-0.9, 0.9]:
		_pflanze(Vector3(px * hx, 0, hx - 0.8), 1.8)
	_pflanze(Vector3(hx - 0.8, 0, -hx + 0.8), 1.8)
	# Glaswand mit Metallrahmen als Trennung zum Chefbuero
	_gruppe(Vector3(-hx + 7.0, 0, 0.1 * hx))
	_q("glas", Vector3(0, 1.3, 0), Vector3(0.04, 2.6, 6.0))
	for z in [-3.0, 0.0, 3.0]:
		_q("metall_dunkel", Vector3(0, 1.3, z), Vector3(0.08, 2.6, 0.08))
	_q("metall_dunkel", Vector3(0, 2.6, 0), Vector3(0.08, 0.08, 6.0))


## Voll ausgestattete Kantine: Kueche mit Essensausgabe (Warmtheke mit Speisen, Spuckschutz, Tablettschiene, Kasse),
## Salatbar unter dem Speiseplan, Getraenkestation mit Kaffeemaschine, Geschirrrueckgabe, Automaten, lange Tische
## mit Stuehlen und gedeckten Tabletts, Haengeleuchten, Muelltrennung.
const KANTINE_SPEISEN: Array[String] = ["essen_nudeln", "essen_reis", "essen_gemuese", "essen_eintopf", "essen_kartoffeln", "essen_suppe", "essen_salat", "essen_dessert"]


func _kantine(hx: float) -> void:
	var zt := -hx + 5.0                       # Linie der Ausgabetheke (Kunden stehen suedlich davon)
	var x0 := 3.6                             # Theke beginnt hinter dem Schachtkern
	var x1 := hx - 2.4                        # und endet vor der Kassenzone
	var laenge := x1 - x0
	var xm := (x0 + x1) * 0.5
	# --- Kuechenbereich (Nordost): Gummiboden, Fliesenwand, Geraete
	_gruppe(Vector3.ZERO)
	_q("gummi", Vector3((x0 + hx) * 0.5, 0.05, (-hx + zt) * 0.5 + 0.1), Vector3(hx - x0 - 0.1, 0.012, zt + hx - 0.2))
	_q("kfliese", Vector3((x0 - 0.2 + hx) * 0.5, 1.25, -hx + 0.11), Vector3(hx - x0 - 0.2, 2.5, 0.03))
	_kueche(hx, x0, zt)
	# --- Ausgabetheke
	_gruppe(Vector3(xm, 0, zt))
	_q("stahl", Vector3(0, 0.45, 0), Vector3(laenge, 0.9, 0.9))
	_kb(Vector3(0, 0.45, 0), Vector3(laenge, 0.9, 0.9))
	_q("holz_hell", Vector3(0, 0.42, 0.47), Vector3(laenge, 0.78, 0.04))
	_q("stahl", Vector3(0, 0.92, 0.0), Vector3(laenge + 0.06, 0.04, 0.98))
	var pfannen := maxi(int(laenge / 1.0), 4)
	var pw := laenge / float(pfannen)
	for i in pfannen:
		var px := -laenge * 0.5 + pw * (i + 0.5)
		_q("stahl", Vector3(px, 0.945, -0.02), Vector3(pw - 0.08, 0.05, 0.62))
		_q(KANTINE_SPEISEN[i % KANTINE_SPEISEN.size()], Vector3(px, 0.975, -0.02), Vector3(pw - 0.16, 0.02, 0.52))
		_q("stahl", Vector3(px + pw * 0.25, 1.0, 0.3), Vector3(0.025, 0.1, 0.025))  # Kelle
	# Spuckschutz: schraege Glasscheibe auf Stahlstuetzen, Waermelampen
	for i in pfannen + 1:
		_q("stahl", Vector3(-laenge * 0.5 + pw * i, 1.3, 0.38), Vector3(0.03, 0.75, 0.03))
	_q("glas", Vector3(0, 1.45, 0.3), Vector3(laenge, 0.5, 0.02), 0.0, -0.35)
	_q("stahl", Vector3(0, 1.65, 0.24), Vector3(laenge, 0.04, 0.08))
	_q("waerme", Vector3(0, 1.6, 0.18), Vector3(laenge - 0.2, 0.03, 0.05))
	# Tablettschiene und Ablage vor der Theke
	_q("stahl", Vector3(0, 0.8, 0.72), Vector3(laenge, 0.03, 0.42))
	for i in pfannen + 1:
		_q("stahl", Vector3(-laenge * 0.5 + pw * i, 0.4, 0.72), Vector3(0.04, 0.8, 0.04))
	_q("stahl", Vector3(0, 0.84, 0.94), Vector3(laenge, 0.02, 0.03))
	# Tabletts mit Tellern in der Schiene
	for i in 3:
		_q("tablett", Vector3(-laenge * 0.5 + 0.8 + i * 1.9, 0.83, 0.72), Vector3(0.42, 0.02, 0.32))
		_z("keramik", Vector3(-laenge * 0.5 + 0.8 + i * 1.9, 0.85, 0.72), 0.13, 0.02)
	# Tablettstapel und Besteckspender am Anfang
	_gruppe(Vector3(x0 - 0.7, 0, zt + 0.7))
	_q("stahl", Vector3(0, 0.45, 0), Vector3(0.6, 0.9, 0.5))
	_kb(Vector3(0, 0.45, 0), Vector3(0.6, 0.9, 0.5))
	for i in 12:
		_q("tablett", Vector3(0, 0.93 + i * 0.022, 0), Vector3(0.44, 0.02, 0.34))
	_gruppe(Vector3(x0 - 0.7, 0, zt + 1.5))
	_q("stahl", Vector3(0, 0.45, 0), Vector3(0.55, 0.9, 0.4))
	_kb(Vector3(0, 0.45, 0), Vector3(0.55, 0.9, 0.4))
	for i in 4:
		_z("stahl", Vector3(-0.18 + i * 0.12, 1.0, 0), 0.04, 0.16)
	# --- Kassenzone am Ende der Theke
	_gruppe(Vector3(hx - 1.5, 0, zt + 1.0))
	_q("stahl", Vector3(0, 0.5, 0), Vector3(1.0, 1.0, 1.4))
	_kb(Vector3(0, 0.5, 0), Vector3(1.0, 1.0, 1.4))
	_q("holz", Vector3(0, 1.02, 0), Vector3(1.06, 0.05, 1.46))
	_q("schwarz", Vector3(-0.1, 1.2, -0.3), Vector3(0.36, 0.28, 0.04))
	_q("bild_tabelle", Vector3(-0.1, 1.2, -0.275), Vector3(0.32, 0.24, 0.004))
	_q("schwarz", Vector3(-0.1, 1.09, -0.25), Vector3(0.4, 0.08, 0.3))
	_q("schwarz", Vector3(0.25, 1.06, 0.1), Vector3(0.2, 0.04, 0.16))
	_q("stahl", Vector3(0.2, 1.1, -0.3), Vector3(0.3, 0.1, 0.25))
	_q("tablett", Vector3(-0.3, 1.05, 0.3), Vector3(0.4, 0.02, 0.3))
	# --- Salatbar unter dem Speiseplan (Nordwest)
	var sx0 := -hx + 2.2
	var sx1 := -3.6
	var sl := sx1 - sx0
	var sxm := (sx0 + sx1) * 0.5
	_gruppe(Vector3(sxm, 0, -hx + 2.2))
	_q("stahl", Vector3(0, 0.45, 0), Vector3(sl, 0.9, 1.1))
	_kb(Vector3(0, 0.45, 0), Vector3(sl, 0.9, 1.1))
	_q("holz_hell", Vector3(0, 0.42, 0.57), Vector3(sl, 0.78, 0.04))
	_q("stahl", Vector3(0, 0.92, 0), Vector3(sl + 0.06, 0.04, 1.18))
	var schalen := maxi(int(sl / 0.95), 3)
	var sw := sl / float(schalen)
	for i in schalen:
		var bx := -sl * 0.5 + sw * (i + 0.5)
		_z("stahl", Vector3(bx, 0.96, 0.0), 0.34, 0.08)
		_z(["essen_salat", "essen_gemuese", "essen_salat", "essen_kartoffeln", "essen_gemuese", "essen_dessert"][i % 6], Vector3(bx, 1.0, 0.0), 0.31, 0.02)
		_q("stahl", Vector3(bx + 0.12, 1.06, 0.12), Vector3(0.02, 0.03, 0.28), 0.5)  # Salatzange
	for i in schalen + 1:
		_q("stahl", Vector3(-sl * 0.5 + sw * i, 1.28, 0.5), Vector3(0.03, 0.7, 0.03))
	_q("glas", Vector3(0, 1.4, 0.45), Vector3(sl, 0.55, 0.02), 0.0, -0.3)
	_q("stahl", Vector3(0, 1.62, 0.4), Vector3(sl, 0.04, 0.08))
	_q("stahl", Vector3(0, 0.84, 0.8), Vector3(sl, 0.03, 0.4))
	for i in 5:
		_z("keramik", Vector3(-sl * 0.5 + 0.4, 0.99 + i * 0.02, 0.62), 0.12, 0.02)  # Tellerstapel
	# Speiseplan an der Nordwand ueber der Salatbar, Holzrahmen
	_gruppe(Vector3.ZERO)
	_q("holz", Vector3(sxm, 2.75, -hx + 0.1), Vector3(3.9, 2.3, 0.05))
	_quad("speiseplan", Vector3(sxm, 2.75, -hx + 0.14), Vector2(3.6, 2.025))
	_q("lampe", Vector3(sxm, 4.0, -hx + 0.3), Vector3(2.8, 0.05, 0.12))
	# Kleiner Aufsteller mit Tagesgericht an der Ausgabe
	_gruppe(Vector3(x0 + 0.4, 0, zt + 1.15), 0.3)
	_q("holz", Vector3(0, 0.55, 0), Vector3(0.45, 0.65, 0.04), 0.0, -0.15)
	_quad("speiseplan", Vector3(0, 0.58, 0.04), Vector2(0.4, 0.225))
	# --- Getraenkestation (Westwand)
	_gruppe(Vector3(-hx + 0.5, 0, -1.5), PI * 0.5)
	_q("stahl", Vector3(0, 0.45, 0), Vector3(2.6, 0.9, 0.6))
	_kb(Vector3(0, 0.45, 0), Vector3(2.6, 0.9, 0.6))
	_q("holz", Vector3(0, 0.92, 0), Vector3(2.7, 0.04, 0.66))
	_q("schwarz", Vector3(-0.6, 1.2, -0.05), Vector3(0.5, 0.55, 0.45))   # Vollautomat
	_q("stahl", Vector3(-0.6, 1.2, 0.19), Vector3(0.42, 0.45, 0.02))
	_q("led_gruen", Vector3(-0.6, 1.4, 0.2), Vector3(0.06, 0.02, 0.01))
	_q("keramik", Vector3(-0.6, 0.98, 0.15), Vector3(0.1, 0.1, 0.1))
	_q("stahl", Vector3(0.3, 1.15, -0.05), Vector3(0.3, 0.45, 0.3))       # Wasserspender
	_q("blau_k", Vector3(0.3, 1.38, 0.12), Vector3(0.12, 0.05, 0.02))
	for i in 3:
		_z("keramik", Vector3(0.85 + i * 0.12, 0.99, 0.05), 0.045, 0.1)   # Tassen
	_q("stahl", Vector3(0.9, 1.7, -0.22), Vector3(1.2, 0.03, 0.25))       # Tassenregal
	for i in 5:
		_z("keramik", Vector3(0.45 + i * 0.22, 1.76, -0.22), 0.045, 0.1)
	_gruppe(Vector3.ZERO)
	_quad("kaffeeposter", Vector3(-hx + 0.12, 2.3, -2.6), Vector2(0.7, 1.05), PI * 0.5)
	# --- Geschirrrueckgabe (Westwand, Mitte): Tablettwagen und Muelltrennung
	_gruppe(Vector3(-hx + 0.6, 0, 0.35 * hx), PI * 0.5)
	_q("stahl", Vector3(0, 0.9, 0), Vector3(1.2, 1.8, 0.6))
	_kb(Vector3(0, 0.9, 0), Vector3(1.2, 1.8, 0.6))
	for i in 6:
		_q("grau_k", Vector3(0, 0.25 + i * 0.28, 0.31), Vector3(1.1, 0.03, 0.02))
		for k in 3:
			_q("tablett", Vector3(-0.38 + k * 0.38, 0.28 + i * 0.28, 0.0), Vector3(0.34, 0.02, 0.5))
	for i in 3:
		_gruppe(Vector3(-hx + 0.5, 0, 0.35 * hx + 1.6 + i * 0.7), PI * 0.5)
		_z(["gelb_k", "blau_k", "grau_k"][i], Vector3(0, 0.45, 0), 0.26, 0.9)
		_kb(Vector3(0, 0.45, 0), Vector3(0.52, 0.9, 0.52))
		_z("schwarz", Vector3(0, 0.92, 0), 0.27, 0.04)
	# --- Getraenkekuehlschrank (Ostwand) mit Flaschen und Automaten
	_gruppe(Vector3(hx - 0.55, 0, zt + 3.6), -PI * 0.5)
	_q("stahl", Vector3(0, 1.0, 0), Vector3(1.2, 2.0, 0.7))
	_kb(Vector3(0, 1.0, 0), Vector3(1.2, 2.0, 0.7))
	_q("schwarz", Vector3(0, 1.0, 0.33), Vector3(1.05, 1.8, 0.04))
	for r in 5:
		for c in 6:
			_z(["flasche_gr", "flasche_br", "saft", "flasche_gr"][(r + c) % 4], Vector3(-0.42 + c * 0.17, 0.38 + r * 0.33, 0.3), 0.04, 0.22)
	_q("glas", Vector3(0, 1.0, 0.36), Vector3(1.05, 1.8, 0.02))
	_q("led_gruen", Vector3(0, 1.95, 0.36), Vector3(1.0, 0.02, 0.02))
	for i in 2:
		_gruppe(Vector3(hx - 0.7, 0, zt + 5.6 + i * 1.3), -PI * 0.5)
		_q("metall_dunkel", Vector3(0, 0.95, 0), Vector3(1.0, 1.9, 0.8))
		_kb(Vector3(0, 0.95, 0), Vector3(1.0, 1.9, 0.8))
		_q("automat_licht", Vector3(0, 1.2, 0.41), Vector3(0.8, 1.1, 0.02))
		for r in 4:
			for c in 4:
				_q(["rot_k", "blau_k", "flasche_gr", "gelb_k"][(r + c + i) % 4], Vector3(-0.27 + c * 0.18, 0.85 + r * 0.25, 0.39), Vector3(0.12, 0.14, 0.04))
		_q("schwarz", Vector3(0, 0.25, 0.41), Vector3(0.6, 0.18, 0.02))
	# --- Speisesaal: lange Tische mit Stuehlen, Gedecken und Haengeleuchten
	var reihen := int((hx - 3.3) / 3.4) + 1
	var tischreihe := 0
	for r in reihen:
		var z := 1.8 + r * 3.4
		var i := 0
		var x := 5.0
		while x <= hx - 1.2:
			for sgn in [-1.0, 1.0]:
				_esstisch(Vector3(x * sgn, 0, z), tischreihe + i)
				i += 1
			x += 3.4
		tischreihe += 3
	_gruppe(Vector3.ZERO)
	# --- Dekor: Uhr, Feuerloescher, Pflanzen, Sitzecke Sued
	_z("weiss", Vector3(0, 3.6, hx - 0.1), 0.35, 0.04)
	_gruppe(Vector3(0, 3.6, hx - 0.14), 0.0)
	_q("schwarz", Vector3(0, 0.1, 0), Vector3(0.03, 0.22, 0.01))
	_q("schwarz", Vector3(0.1, 0, 0), Vector3(0.18, 0.03, 0.01))
	_gruppe(Vector3(-hx + 0.3, 0, hx - 3.0), PI * 0.5)
	_z("rot_k", Vector3(0, 0.9, 0), 0.07, 0.45)
	_sofa(Vector3(-hx * 0.5, 0, hx - 0.8), PI, 2.6)
	_sofa(Vector3(hx * 0.5, 0, hx - 0.8), PI, 2.6)
	_gruppe(Vector3.ZERO)
	_q("teppich_rot", Vector3(0, 0.05, hx - 1.4), Vector3(hx * 1.6, 0.012, 2.0))
	_wandbild("poster", Vector3(hx - 0.12, 2.2, hx - 4.0), Vector2(1.0, 1.5), -PI * 0.5)
	for px in [-0.9, 0.9]:
		_pflanze(Vector3(px * hx, 0, hx - 0.7), 1.7)
	_pflanze(Vector3(-hx + 0.8, 0, hx - 2.2), 1.8)
	_pflanze(Vector3(hx - 0.8, 0, hx - 2.2), 1.8)


## Kuechenzeile an der Nordwand: Herd mit Toepfen, Dunstabzug, Kombidaempfer, Kuehlschrank, Arbeitstisch, Regal.
func _kueche(hx: float, x0: float, zt: float) -> void:
	var zw := -hx + 0.55
	# Herd mit vier Platten und Toepfen
	_gruppe(Vector3(x0 + 1.5, 0, zw))
	_q("stahl", Vector3(0, 0.45, 0), Vector3(1.8, 0.9, 0.8))
	_kb(Vector3(0, 0.45, 0), Vector3(1.8, 0.9, 0.8))
	_q("schwarz", Vector3(0, 0.92, 0), Vector3(1.7, 0.03, 0.72))
	for i in 4:
		var px := -0.45 + (i % 2) * 0.9
		var pz := -0.18 + int(i / 2) * 0.36
		_z("stahl", Vector3(px, 1.07, pz), 0.17, 0.26)
		_z("schwarz", Vector3(px, 1.21, pz), 0.17, 0.02)
	_q("stahl", Vector3(0, 2.2, -0.05), Vector3(1.9, 0.5, 0.85))             # Dunstabzugshaube
	_q("stahl", Vector3(0, 3.2, -0.2), Vector3(0.5, 1.5, 0.4))
	_q("schwarz", Vector3(0, 1.95, 0.0), Vector3(1.6, 0.02, 0.6))
	# Kombidaempfer
	_gruppe(Vector3(x0 + 3.2, 0, zw))
	_q("stahl", Vector3(0, 0.95, 0), Vector3(0.95, 1.9, 0.85))
	_kb(Vector3(0, 0.95, 0), Vector3(0.95, 1.9, 0.85))
	_q("schwarz", Vector3(0, 1.3, 0.43), Vector3(0.7, 0.8, 0.02))
	_q("led_orange", Vector3(0.3, 1.8, 0.43), Vector3(0.1, 0.04, 0.01))
	_q("waerme", Vector3(0, 1.3, 0.44), Vector3(0.5, 0.5, 0.005))
	# Zweitueriger Kuehlschrank
	_gruppe(Vector3(x0 + 4.7, 0, zw))
	_q("stahl", Vector3(0, 1.0, 0), Vector3(1.4, 2.0, 0.8))
	_kb(Vector3(0, 1.0, 0), Vector3(1.4, 2.0, 0.8))
	_q("schwarz", Vector3(-0.05, 1.2, 0.41), Vector3(0.03, 0.7, 0.03))
	_q("schwarz", Vector3(0.05, 1.2, 0.41), Vector3(0.03, 0.7, 0.03))
	# Arbeitstisch mit Schneidebrett und Toepfen, Regal mit Geschirr
	if hx - x0 > 9.0:
		_gruppe(Vector3(x0 + 6.8, 0, zw))
		_q("stahl", Vector3(0, 0.45, 0), Vector3(1.8, 0.9, 0.8))
		_kb(Vector3(0, 0.45, 0), Vector3(1.8, 0.9, 0.8))
		_q("holz_hell", Vector3(-0.3, 0.93, 0), Vector3(0.6, 0.04, 0.4))
		_z("stahl", Vector3(0.5, 1.05, 0), 0.2, 0.28)
		_q("stahl", Vector3(0, 1.9, -0.3), Vector3(1.8, 0.04, 0.3))
		for i in 6:
			_z("keramik", Vector3(-0.7 + i * 0.28, 1.95, -0.3), 0.12, 0.03)
	# Haengende Pfannen und Kellen an der Fliesenwand
	_gruppe(Vector3.ZERO)
	for i in 4:
		var px := x0 + 1.2 + i * 0.5
		_q("stahl", Vector3(px, 1.75, -hx + 0.2), Vector3(0.02, 0.35, 0.02))
		_z("schwarz", Vector3(px, 1.5, -hx + 0.2), 0.14, 0.03)
	# Arbeitstisch in der Kuechenmitte (Pass)
	_gruppe(Vector3((x0 + hx) * 0.5, 0, (-hx + zt) * 0.5 + 0.2))
	_q("stahl", Vector3(0, 0.45, 0), Vector3(2.4, 0.9, 0.8))
	_kb(Vector3(0, 0.45, 0), Vector3(2.4, 0.9, 0.8))
	_q("stahl", Vector3(0, 0.3, 0), Vector3(2.3, 0.03, 0.7))
	for i in 3:
		_z(["essen_nudeln", "essen_salat", "essen_dessert"][i], Vector3(-0.7 + i * 0.7, 0.96, 0), 0.22, 0.04)


## Langer Esstisch (2,4 m) mit je zwei Stuehlen pro Seite. Nummer steuert, welche Plaetze gedeckt sind.
func _esstisch(p: Vector3, nr: int) -> void:
	_gruppe(p)
	_q("holz_hell", Vector3(0, 0.75, 0), Vector3(2.4, 0.04, 0.9))
	for s in [-1.0, 1.0]:
		_q("stahl", Vector3(s * 1.05, 0.37, 0), Vector3(0.05, 0.72, 0.8))
	_q("stahl", Vector3(0, 0.1, 0), Vector3(2.1, 0.04, 0.05))
	_kb(Vector3(0, 0.4, 0), Vector3(2.4, 0.8, 0.9))
	_q("stahl", Vector3(0, 1.0, 0), Vector3(1.9, 0.03, 0.03))   # Tischleuchte (Hängeleuchte) unten
	_q("lampe", Vector3(0, 4.4, 0), Vector3(1.8, 0.08, 0.3))
	for s in [-1.0, 1.0]:
		_q("schwarz", Vector3(s * 0.8, 4.9, 0), Vector3(0.015, 0.9, 0.015))
	# Mitte: Serviettenspender, Salz und Pfeffer
	_q("stahl", Vector3(0, 0.82, 0), Vector3(0.14, 0.12, 0.1))
	_z("keramik", Vector3(0.2, 0.82, 0.05), 0.025, 0.1)
	_z("schwarz", Vector3(0.28, 0.82, 0.05), 0.025, 0.1)
	for k in 4:
		var sx := -0.6 + (k % 2) * 1.2
		var sz := -1.0 if k < 2 else 1.0
		var gedeckt := ((nr + k) % 3) != 1
		_gruppe(p)
		if gedeckt:
			var tz := sz * 0.28
			_q("tablett", Vector3(sx, 0.78, tz), Vector3(0.44, 0.02, 0.34))
			_z("keramik", Vector3(sx, 0.8, tz), 0.14, 0.02)
			_z(KANTINE_SPEISEN[(nr * 2 + k) % KANTINE_SPEISEN.size()], Vector3(sx, 0.815, tz), 0.1, 0.012)
			_z("glas", Vector3(sx + 0.16, 0.85, tz - 0.05), 0.035, 0.1)
			_q("stahl", Vector3(sx - 0.2, 0.795, tz), Vector3(0.015, 0.005, 0.15))
		_stuhl(p + Vector3(sx, 0, sz * 0.85), PI if sz < 0.0 else 0.0)
	_gruppe(p)


func _rechenzentrum(hx: float) -> void:
	# Zwei Reihen Serverschraenke mit Kabelbruecke und LED-Punkten, Gang in der Mitte (vor dem Aufzug)
	for reihe in [-1.0, 1.0]:
		var x: float = reihe * (hx * 0.45)
		for i in 6:
			var z := 1.5 + i * (hx * 1.5 / 6.0)
			_gruppe(Vector3(x, 0, z), reihe * -PI * 0.5)
			_q("metall_dunkel", Vector3(0, 1.1, 0), Vector3(0.75, 2.2, 0.95))
			_kb(Vector3(0, 1.1, 0), Vector3(0.75, 2.2, 0.95))
			for e in 9:
				_q("schwarz", Vector3(0, 0.3 + e * 0.2, 0.48), Vector3(0.62, 0.16, 0.02))
				_q(["led_gruen", "led_gruen", "led_orange"][_zufall.randi() % 3], Vector3(-0.25 + _zufall.randf() * 0.1, 0.3 + e * 0.2, 0.49), Vector3(0.04, 0.03, 0.01))
				_q(["led_gruen", "led_orange"][_zufall.randi() % 2], Vector3(0.2 + _zufall.randf() * 0.1, 0.3 + e * 0.2, 0.49), Vector3(0.03, 0.03, 0.01))
		_gruppe(Vector3.ZERO)
		_q("metall_dunkel", Vector3(x, 3.4, hx * 0.55), Vector3(0.5, 0.12, hx * 1.5))
		_q("metall", Vector3(x, 3.25, hx * 0.55), Vector3(0.45, 0.02, hx * 1.5))
	_gruppe(Vector3.ZERO)
	_q("gummi", Vector3(0, 0.05, hx * 0.55), Vector3(hx * 0.5, 0.012, hx * 1.5))
	# Regale mit Kartons an der Suedwand und Nordwestecke, kleiner Arbeitsplatz
	_regal(Vector3(-hx * 0.5, 0, hx - 0.4), PI, 2.4)
	_regal(Vector3(hx * 0.5, 0, hx - 0.4), PI, 2.4)
	_regal(Vector3(0, 0, hx - 0.4), PI, 2.4)
	_schreibtisch(Vector3(-hx + 2.0, 0, 0.2 * hx), PI * 0.5, "bild_code")
	_stuhl(Vector3(-hx + 2.9, 0, 0.2 * hx), PI * 0.5)
	_wandbild("bild_chart", Vector3(-hx + 0.12, 2.2, 0.45 * hx), Vector2(2.0, 1.1), PI * 0.5)
	_wandbild("whiteboard", Vector3(hx - 0.12, 2.0, 0.3 * hx), Vector2(2.4, 1.2), -PI * 0.5)
	_aktenschrank(Vector3(hx - 0.5, 0, -0.1 * hx), -PI * 0.5)
	_pflanze(Vector3(-hx + 0.8, 0, -hx + 0.8), 1.8)
	_pflanze(Vector3(hx - 0.8, 0, -hx + 0.8), 1.8)
