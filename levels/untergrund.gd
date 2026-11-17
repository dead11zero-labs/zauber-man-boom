extends Node3D
## Untergrund-Komplex "SUB-ARCHIV Omega": geheime Mega-Struktur unter dem Stadtrand, gebaut aus dem
## Modular SciFi MegaKit (levels/megakit.gd, CC0). Zugang ist der Lastenaufzug (levels/lastenaufzug.gd) direkt
## unter der Luke der 6twelve-Filiale (levels/sechs_zwoelf.gd, geoeffnet durch Anheben des Teppichs im Lagerraum).
## Ursprung dieses Knotens: NW-Ecke der Luke auf Strassenniveau (y = 0). Der Aufzugsschacht liegt bei
## x 0..AUFZUG_GROESSE.x, z 0..AUFZUG_GROESSE.y; unten fuehrt seine Tuer nach Norden in den Vorraum (z -4..0).
## Der Komplex liegt nach Norden (-z) und zu beiden Seiten, Boden bei y = BODEN_Y.
## Signale: aufzug_oben (Plattform ist oben angekommen; stadt.gd oeffnet damit die Luke von unten).
## Methode: aufzug_freigeben() (stadt.gd ruft sie, sobald die Luke offen ist).
## Aufbau: Textkarte KARTE (Zelle = 4 m). '#' fest, '.' Raum (5,05 m hoch), 'H' Halle (8,1 m), 'd' Tuerzelle,
## 'V' Schachtzelle. Waende sitzen auf den Kanten zwischen Raum und Fels; Kollision aus einfachen Boxen.
## Exportiert: nichts. Beleuchtung nur durch eigene Lampen (kein Himmelslicht).

signal aufzug_oben

const MK := preload("res://levels/megakit.gd")
const AUFZUG := preload("res://levels/lastenaufzug.gd")
const AUFZUG_GROESSE := Vector2(2.15, 4.2)   ## = Lukengroesse in levels/sechs_zwoelf.gd (LUKE_X, LUKE_Z)
const AUFZUG_OBEN_Y := -0.08                 ## Plattform knapp unter dem Lukendeckel

const ZELLE := 4.0
const BODEN_Y := -16.0
const WAND_H := 3.05              ## Hoehe eines Wandstuecks
const RAUM_H := 5.05              ## Wand plus Top-Stueck
const HALLE_H := 8.1
const WAND_KOL_DICKE := 0.9       ## Kollisionsbox der Wand, mittig auf der Kante (sichtbare Innenflaeche liegt 0,45 m davor)
const SCHACHT_SPALTE := 12        ## Spalte der Schachtzellen in der Karte
const SCHACHT_ZEILE := 19         ## Zeile der Aufzugszelle (x 0..4, z 0..4)
const LICHT_STANDARD := Color(0.75, 0.9, 1.0)
const LICHT_HALLE := Color(0.55, 0.85, 1.0)
const LICHT_ALARM := Color(1.0, 0.35, 0.25)

const KARTE: Array[String] = [
	"#########.......########",
	"#########.......########",
	"############d###########",
	"#####HHHHHHHHHHHHHH#####",
	"#...#HHHHHHHHHHHHHH#...#",
	"#...#HHHHHHHHHHHHHH#...#",
	"#...dHHHHHHHHHHHHHHd...#",
	"#...#HHHHHHHHHHHHHH#...#",
	"#...#HHHHHHHHHHHHHH#...#",
	"#####HHHHHHHHHHHHHH#####",
	"#####HHHHHHHHHHHHHH#####",
	"#####HHHHHHHHHHHHHH#####",
	"############d###########",
	"##########.....#########",
	"#####....#.....#....####",
	"#####....d.....d....####",
	"#####....###d###....####",
	"#####....###.###....####",
	"############.###########",
	"############V###########",
	"########################",
	"########################",
]

## Bodenteile je Raumart (wechseln nach Zellenhash)
const BODEN_HALLE: Array[String] = ["Platform_DarkPlates", "Platform_Metal2", "Platform_DarkPlates_Curves", "Platform_Squares"]
const BODEN_RAUM: Array[String] = ["Platform_Metal", "Platform_Simple", "Platform_3Plates"]
const WAENDE_RAUM: Array[String] = ["WallAstra_Straight", "WallAstra_Straight_Divided", "WallAstra_Straight_Flat_Window", "WallAstra_Straight"]

var _licht_mat: StandardMaterial3D
var _decke_mat: StandardMaterial3D
var _aufzug: Node3D


func _ready() -> void:
	name = "Untergrund"
	_licht_mat = StandardMaterial3D.new()
	_licht_mat.albedo_color = Color(0.1, 0.1, 0.12)
	_licht_mat.emission_enabled = true
	_licht_mat.emission = LICHT_STANDARD
	_licht_mat.emission_energy_multiplier = 3.0
	_decke_mat = StandardMaterial3D.new()
	_decke_mat.albedo_color = Color(0.06, 0.07, 0.09)
	_decke_mat.roughness = 0.9
	_decke_mat.disable_ambient_light = true
	_schacht_bauen()
	_komplex_bauen()
	_ausstattung()


# ---------------------------------------------------------------- Karte

func _zelle(c: int, r: int) -> String:
	if r < 0 or r >= KARTE.size() or c < 0 or c >= KARTE[r].length():
		return "#"
	return KARTE[r][c]


func _mitte(c: int, r: int) -> Vector3:
	return Vector3((c - SCHACHT_SPALTE) * ZELLE + ZELLE * 0.5, BODEN_Y, (r - SCHACHT_ZEILE) * ZELLE + ZELLE * 0.5)


func _hohl(ch: String) -> bool:
	return ch != "#"


func _halle(ch: String) -> bool:
	return ch == "H"


# ---------------------------------------------------------------- Bauteile setzen

func _teil(kat: String, name_: String, pos: Vector3, yaw := 0.0, skala := Vector3.ONE) -> Node3D:
	var n := MK.laden(kat, name_)
	n.position = pos
	n.rotation_degrees.y = yaw
	n.scale = skala
	add_child(n)
	return n


## Quader mit Kollision (unsichtbar), Mitte in Raumkoordinaten.
func _kol(mitte: Vector3, groesse: Vector3, drehung := Vector3.ZERO) -> void:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = groesse
	cs.shape = sh
	sb.add_child(cs)
	sb.position = mitte
	sb.rotation = drehung
	add_child(sb)


## Kollision aus der Huelle eines Teils (fuer Props und Saeulen).
func _kol_teil(n: Node3D) -> void:
	var box := AABB()
	var erst := true
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var t := Transform3D()
		var c: Node3D = mi
		while c != n:
			t = c.transform * t
			c = c.get_parent() as Node3D
		var b := t * mi.get_aabb()
		box = b if erst else box.merge(b)
		erst = false
	if erst or box.size.x < 0.05:
		return
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = box.size
	cs.shape = sh
	cs.position = box.get_center()
	sb.add_child(cs)
	n.add_child(sb)


func _lampe(pos: Vector3, farbe: Color, energie: float, reichweite: float) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = farbe
	l.light_energy = energie
	l.omni_range = reichweite
	l.shadow_enabled = false
	add_child(l)


# ---------------------------------------------------------------- Wand an einer Zellkante

## Richtung -> [Versatz zur Kante, Drehung des Wandstuecks]. Basisteil steht an der West-Kante (Innenseite +x).
const KANTEN := {
	"W": [Vector2(-2.0, 0.0), 0.0],
	"S": [Vector2(0.0, 2.0), 90.0],
	"N": [Vector2(0.0, -2.0), -90.0],
	"E": [Vector2(2.0, 0.0), 180.0],
}
const NACHBAR := {"W": Vector2i(-1, 0), "E": Vector2i(1, 0), "N": Vector2i(0, -1), "S": Vector2i(0, 1)}


func _wand_stueck(mitte: Vector3, richtung: String, kat: String, name_: String, y_extra := 0.0) -> void:
	# Das Wandstueck sitzt mit dem Ursprung in der Zellmitte, seine Kante liegt durch die Drehung bei +-2 m
	var k: Array = KANTEN[richtung]
	_teil(kat, name_, Vector3(mitte.x, mitte.y + y_extra, mitte.z), k[1])


func _wand_kante(c: int, r: int, richtung: String, halle: bool, variante: int) -> void:
	var m := _mitte(c, r)
	var name_: String = "WallAstra_Straight" if halle else WAENDE_RAUM[variante % WAENDE_RAUM.size()]
	_wand_stueck(m, richtung, "Walls", name_)
	if halle:
		_wand_stueck(m, richtung, "Walls", "WallBand_Straight", WAND_H)
		_wand_stueck(m, richtung, "Walls", "TopAstra_Straight", WAND_H * 2.0 - 3.0)
	else:
		_wand_stueck(m, richtung, "Walls", "TopAstra_Straight", 0.05)
	var h := HALLE_H if halle else RAUM_H
	var off: Vector2 = KANTEN[richtung][0]
	var kol_mitte := Vector3(m.x + off.x, m.y + h * 0.5, m.z + off.y)
	var gross := Vector3(WAND_KOL_DICKE if off.x != 0.0 else ZELLE + 0.2, h, WAND_KOL_DICKE if off.y != 0.0 else ZELLE + 0.2)
	_kol(kol_mitte, gross)


# ---------------------------------------------------------------- Komplex

func _komplex_bauen() -> void:
	for r in KARTE.size():
		for c in KARTE[r].length():
			var ch := _zelle(c, r)
			if not _hohl(ch) or ch == "V":
				continue
			var halle := _halle(ch)
			var m := _mitte(c, r)
			var h := HALLE_H if halle else RAUM_H
			var hash_wert := (c * 7 + r * 13) % 5
			# Boden: Kit-Platte plus Kollisionsbox; Decke: umgedrehte Platte plus dunkle Abdeckung (Schatten)
			var boden: String = BODEN_HALLE[hash_wert % BODEN_HALLE.size()] if halle else BODEN_RAUM[hash_wert % BODEN_RAUM.size()]
			_teil("Platforms", boden, m)
			_kol(m + Vector3(0, -0.25, 0), Vector3(ZELLE, 0.5, ZELLE))
			var decke := _teil("Platforms", "Platform_Simple2", m + Vector3(0, h, 0))
			decke.rotation_degrees.x = 180.0
			var abdeckung := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(ZELLE, 0.3, ZELLE)
			abdeckung.mesh = bm
			abdeckung.material_override = _decke_mat
			abdeckung.position = m + Vector3(0, h + 0.2, 0)
			add_child(abdeckung)
			if ch == "d":
				_tuer(c, r, m)
			# Waende an Kanten zu Fels (Tuerzellen: Seitenwaende), Halle zu Tuerzelle: Fuellung ueber der Tuer
			for d in KANTEN.keys():
				var v: Vector2i = NACHBAR[d]
				var n := _zelle(c + v.x, r + v.y)
				if n == "#":
					_wand_kante(c, r, d, halle, hash_wert + c)
				elif halle and n == "d":
					# Wand ueber der Tuer: Band von 5,05 bis 8,05
					_wand_stueck(m, d, "Walls", "WallBand_Straight", RAUM_H)
					var o: Vector2 = KANTEN[d][0]
					_kol(Vector3(m.x + o.x, m.y + RAUM_H + 1.5, m.z + o.y), Vector3(WAND_KOL_DICKE if o.x != 0.0 else ZELLE, 3.0, WAND_KOL_DICKE if o.y != 0.0 else ZELLE))


## Tuerrahmen mitten in der Tuerzelle, quer zur Laufrichtung (Laufrichtung = Achse mit Raum an beiden Seiten).
func _tuer(c: int, r: int, m: Vector3) -> void:
	var ns := _hohl(_zelle(c, r - 1)) and _hohl(_zelle(c, r + 1))
	var rahmen := _teil("Platforms", "Door_Frame_A", m, 0.0 if ns else 90.0)
	rahmen.position.y = m.y


# ---------------------------------------------------------------- Schacht

func _schacht_bauen() -> void:
	_aufzug = Node3D.new()
	_aufzug.name = "Lastenaufzug"
	_aufzug.set_script(AUFZUG)
	_aufzug.set("oben_y", AUFZUG_OBEN_Y)
	_aufzug.set("unten_y", BODEN_Y)
	_aufzug.set("groesse", AUFZUG_GROESSE)
	add_child(_aufzug)
	_aufzug.connect("oben_angekommen", func() -> void: aufzug_oben.emit())
	# Rest der Aufzugszelle (x AUFZUG_GROESSE.x..4) ist Fels: Wand zum Vorraum, sonst schaut man ins Leere
	var rest_x := ZELLE - AUFZUG_GROESSE.x
	var mitte := Vector3(AUFZUG_GROESSE.x + rest_x * 0.5, BODEN_Y + RAUM_H * 0.5, -0.2)
	var wand := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(rest_x, RAUM_H, 0.4)
	wand.mesh = bm
	wand.material_override = _decke_mat
	wand.position = mitte
	add_child(wand)
	_kol(mitte, bm.size)
	_teil("Decals", "Decal_Line_Straight", Vector3(AUFZUG_GROESSE.x * 0.5, BODEN_Y + 0.02, -2.0), 90.0)


func aufzug_freigeben() -> void:
	if _aufzug != null:
		_aufzug.call("freigeben")


# ---------------------------------------------------------------- Ausstattung

func _ausstattung() -> void:
	# Beleuchtung und Deckenleuchten je Zelle
	for r in KARTE.size():
		for c in KARTE[r].length():
			var ch := _zelle(c, r)
			if ch == "#" or ch == "V":
				continue
			var m := _mitte(c, r)
			var halle := _halle(ch)
			var h := HALLE_H if halle else RAUM_H
			if (c + r) % 2 == 0 and (halle or ch != "d"):
				var leuchte := _teil("Props", "Prop_Light_Wide", m + Vector3(0, h, 0))
				leuchte.rotation_degrees.x = 180.0
				leuchte.position.y = m.y + h - 0.02
				if (c + r) % 4 == 0:
					_lampe(m + Vector3(0, h - 1.0, 0), LICHT_HALLE if halle else LICHT_STANDARD, 2.2 if halle else 1.6, 14.0 if halle else 9.0)
	_halle_ausstatten()
	_raeume_ausstatten()


func _halle_ausstatten() -> void:
	# Mitte der Halle: Rundpodest mit Chrysalis, vier hohe Saeulen, Hallenlicht
	var mitte := (_mitte(11, 7) + _mitte(12, 7)) * 0.5
	_teil("Platforms", "Platform_Round1", mitte + Vector3(0, 0.15, 0))
	var kokon := _teil("Aliens", "Alien_Oculichrysalis", mitte + Vector3(0, 0.15, 0), 20.0, Vector3.ONE * 1.4)
	_kol_teil(kokon)
	_lampe(mitte + Vector3(0, 4.0, 0), LICHT_ALARM, 3.0, 16.0)
	for cr in [Vector2i(7, 5), Vector2i(7, 9), Vector2i(16, 5), Vector2i(16, 9)]:
		var s := _teil("Columns", "Column_Large_Straight", _mitte(cr.x, cr.y) + Vector3(2, 0, 2), 0.0, Vector3(1.0, 0.8, 1.0))
		_kol_teil(s)
	# Stege entlang der Nordwand und Rohrhalter
	for c in range(6, 18, 2):
		var p := _teil("Platforms", "Platform_Rails_4Wide", _mitte(c, 3) + Vector3(0, 0, -0.4), 0.0)
		_kol_teil(p)
	for c in [6, 11, 14, 17]:
		var rohr := _teil("Props", "Prop_PipeHolder", _mitte(c, 11) + Vector3(0, 0, 1.4))
		_kol_teil(rohr)
	# Kisten und Fass-Gruppen an der Suedwand
	var kiste_pos := [Vector2i(5, 10), Vector2i(6, 10), Vector2i(18, 10), Vector2i(17, 11)]
	for i in kiste_pos.size():
		var cr: Vector2i = kiste_pos[i]
		var k := _teil("Props", "Prop_Crate4" if i % 2 == 0 else "Prop_Crate3", _mitte(cr.x, cr.y) + Vector3(0, 0.55, 0), i * 25.0)
		_kol_teil(k)
	for i in 3:
		var f := _teil("Props", "Prop_Barrel_Large", _mitte(18, 4 + i) + Vector3(0.8, 0, 0), i * 40.0)
		_kol_teil(f)


func _raeume_ausstatten() -> void:
	# Serverraum (West): Reihen aus Computern
	for r in range(4, 9):
		for c in [1, 3]:
			var rechner := _teil("Props", "Prop_Computer", _mitte(c, r) + Vector3(0, 0, 0), 90.0 if c == 1 else -90.0)
			rechner.position.x += 1.3 if c == 1 else -1.3
			_kol_teil(rechner)
	_lampe(_mitte(2, 6) + Vector3(0, 3.5, 0), LICHT_HALLE, 2.0, 12.0)
	# Labor (Ost): Scolitex im Becken, Zugangspunkte
	var lab := _teil("Aliens", "Alien_Scolitex", _mitte(21, 6) + Vector3(0, 0, 0), 180.0, Vector3.ONE * 1.2)
	_kol_teil(lab)
	for r in [4, 8]:
		var ap := _teil("Props", "Prop_AccessPoint", _mitte(22, r) + Vector3(0.9, 0.0, 0), -90.0)
		_kol_teil(ap)
	_lampe(_mitte(21, 6) + Vector3(0, 3.5, 0), LICHT_ALARM, 2.4, 12.0)
	# Lager (Suedwest): Kisten und Fass-Stapel
	for r in range(14, 18):
		for c in [5, 8]:
			var k := _teil("Props", "Prop_Crate4" if (r + c) % 2 == 0 else "Prop_Crate3", _mitte(c, r) + Vector3(0.9 if c == 5 else -0.9, 0.55, 0), r * 17.0)
			_kol_teil(k)
	# Truhe und Kisten im Lager
	_kol_teil(_teil("Props", "Prop_Chest", _mitte(6, 15) + Vector3(0, 0, 0), 90.0))
	# Quartier (Suedost): Truhen und Zugangspunkte
	for r in [14, 17]:
		_kol_teil(_teil("Props", "Prop_Chest", _mitte(19, r) + Vector3(0, 0, 0), 180.0))
	_lampe(_mitte(6, 15) + Vector3(0, 3.5, 0), LICHT_STANDARD, 1.6, 12.0)
	_lampe(_mitte(18, 15) + Vector3(0, 3.5, 0), LICHT_STANDARD, 1.6, 12.0)
	# Leitstelle (Nord): Rechner an der Rueckwand, Fenster-Wand
	for c in range(10, 15):
		var rechner := _teil("Props", "Prop_Computer", _mitte(c, 0) + Vector3(0, 0, -1.2), 0.0)
		_kol_teil(rechner)
	_lampe(_mitte(12, 0) + Vector3(0, 3.5, 0), LICHT_HALLE, 2.2, 14.0)
	# Lobby: Logo-Decal auf dem Boden, Rueckwand-Rechner
	var logo := _teil("Decals", "Decal_Logo", _mitte(12, 14) + Vector3(0, 0.03, 0))
	logo.rotation_degrees.y = 0.0
	# Fuer das Auge: Kabel und Luefter im Gang
	_teil("Props", "Prop_Cable_3", _mitte(12, 17) + Vector3(0.6, 0.02, 0))
	var luefter := _teil("Props", "Prop_Fan_Small", _mitte(12, 13) + Vector3(0, RAUM_H - 0.35, 0))
	luefter.rotation_degrees.x = 0.0
