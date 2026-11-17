extends Node3D
## Lastenaufzug: offene Plattform in einem engen Schacht zwischen zwei Haltestellen (oben und unten).
## Ablauf: Wer auf der Plattform steht (Gruppe "spieler"), faehrt nach VERWEIL Sekunden zur anderen Haltestelle.
## Steht der Spieler an der anderen Haltestelle neben dem Schacht, kommt die Plattform von selbst.
## Nach einer Fahrt startet sie erst wieder, wenn der Spieler einmal abgestiegen ist (kein Pendeln).
## Oben faehrt sie erst nach `freigeben()` los (vorher liegt die geschlossene Luke darueber). Rufen von unten geht immer.
## Ursprung: NW-Ecke des Schachts auf Hoehe 0, Grundflaeche x 0..groesse.x, z 0..groesse.y.
## Baut Schachtwaende, Leuchtstreifen, Fuehrungsschienen und die Tueroeffnung unten (Richtung tuer_unten).
## Exportiert: oben_y, unten_y (Oberkante der Plattform an den Haltestellen), groesse (Grundflaeche), tempo.
## Signale: oben_angekommen, unten_angekommen, fahrt_gestartet(nach_oben: bool).

signal oben_angekommen
signal unten_angekommen
signal fahrt_gestartet(nach_oben: bool)

@export var oben_y := -0.08
@export var unten_y := -16.0
@export var groesse := Vector2(2.15, 4.2)
@export var tempo := 3.5                ## Meter pro Sekunde

const VERWEIL := 0.7                    ## Sekunden auf der Plattform bis zur Abfahrt
const PLATTE_DICKE := 0.3
const STEH_HOEHE := 2.2                 ## so hoch ueber der Plattform zaehlt der Spieler als "drauf"
const RUF_ABSTAND := 4.5                ## waagerecht, ab Schachtmitte: so nah ruft der Spieler die Plattform
const RUF_HOEHE := 2.5
const WAND_DICKE := 0.4
const TUER_HOEHE := 3.0
const STREIFEN_ABSTAND := 4.0           ## senkrechter Abstand der Leuchtstreifen
const KANTE := 0.12                     ## Warnstreifen am Plattformrand
const LICHT := Color(1.0, 0.75, 0.3)

enum Zustand { OBEN, UNTEN, FAEHRT_HOCH, FAEHRT_RUNTER }

var _platte: AnimatableBody3D
var _zustand := Zustand.OBEN
var _auf_seit := 0.0
var _gesperrt_bis_abstieg := false
var _freigegeben := false
var _spieler: Node3D
var _mat_wand: StandardMaterial3D
var _mat_kante: StandardMaterial3D
var _mat_licht: StandardMaterial3D
var _mat_stahl: StandardMaterial3D


func _ready() -> void:
	_materialien()
	_schacht()
	_plattform()


func _materialien() -> void:
	_mat_wand = StandardMaterial3D.new()
	_mat_wand.albedo_color = Color(0.16, 0.17, 0.19)
	_mat_wand.metallic = 0.6
	_mat_wand.roughness = 0.55
	_mat_wand.disable_ambient_light = true
	_mat_stahl = StandardMaterial3D.new()
	_mat_stahl.albedo_color = Color(0.45, 0.47, 0.5)
	_mat_stahl.metallic = 0.9
	_mat_stahl.roughness = 0.3
	_mat_stahl.disable_ambient_light = true
	_mat_kante = StandardMaterial3D.new()
	_mat_kante.albedo_color = Color(1.0, 0.75, 0.1)
	_mat_kante.emission_enabled = true
	_mat_kante.emission = Color(1.0, 0.7, 0.1)
	_mat_kante.emission_energy_multiplier = 0.6
	_mat_licht = StandardMaterial3D.new()
	_mat_licht.albedo_color = Color(0.1, 0.1, 0.1)
	_mat_licht.emission_enabled = true
	_mat_licht.emission = LICHT
	_mat_licht.emission_energy_multiplier = 3.0


func _box(eltern: Node3D, mitte: Vector3, g: Vector3, mat: Material, kol: bool) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = g
	mi.mesh = bm
	mi.material_override = mat
	mi.position = mitte
	eltern.add_child(mi)
	if kol:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = g
		cs.shape = sh
		sb.add_child(cs)
		sb.position = mitte
		eltern.add_child(sb)


func _schacht() -> void:
	var h := oben_y - unten_y
	var ym := (oben_y + unten_y) * 0.5
	var w := WAND_DICKE * 0.5
	# West, Ost, Sued ueber die volle Hoehe; Nord nur oberhalb der Tuer
	_box(self, Vector3(-w, ym, groesse.y * 0.5), Vector3(WAND_DICKE, h, groesse.y + WAND_DICKE * 2.0), _mat_wand, true)
	_box(self, Vector3(groesse.x + w, ym, groesse.y * 0.5), Vector3(WAND_DICKE, h, groesse.y + WAND_DICKE * 2.0), _mat_wand, true)
	_box(self, Vector3(groesse.x * 0.5, ym, groesse.y + w), Vector3(groesse.x, h, WAND_DICKE), _mat_wand, true)
	var nord_unten := unten_y + TUER_HOEHE
	_box(self, Vector3(groesse.x * 0.5, (oben_y + nord_unten) * 0.5, -w), Vector3(groesse.x, oben_y - nord_unten, WAND_DICKE), _mat_wand, true)
	# Tuerrahmen unten (gelb-schwarz) und Leuchtstreifen alle STREIFEN_ABSTAND Meter
	_box(self, Vector3(groesse.x * 0.5, nord_unten - 0.08, -WAND_DICKE - 0.02), Vector3(groesse.x, 0.16, 0.06), _mat_kante, false)
	var y := unten_y + STREIFEN_ABSTAND * 0.5
	while y < oben_y - 0.5:
		_box(self, Vector3(0.02, y, groesse.y * 0.5), Vector3(0.04, 0.08, groesse.y - 0.4), _mat_licht, false)
		_box(self, Vector3(groesse.x - 0.02, y, groesse.y * 0.5), Vector3(0.04, 0.08, groesse.y - 0.4), _mat_licht, false)
		y += STREIFEN_ABSTAND
	# Fuehrungsschienen an der Suedwand
	for sx: float in [0.35, groesse.x - 0.35]:
		_box(self, Vector3(sx, ym, groesse.y - 0.05), Vector3(0.12, h, 0.1), _mat_stahl, false)
	for sy: float in [unten_y + 2.5, (oben_y + unten_y) * 0.5, oben_y - 2.0]:
		var l := OmniLight3D.new()
		l.light_color = LICHT
		l.light_energy = 1.2
		l.omni_range = 6.0
		l.position = Vector3(groesse.x * 0.5, sy, groesse.y * 0.5)
		add_child(l)


func _plattform() -> void:
	_platte = AnimatableBody3D.new()
	_platte.sync_to_physics = true
	_platte.position = Vector3(groesse.x * 0.5, oben_y, groesse.y * 0.5)
	add_child(_platte)
	var innen := groesse - Vector2(0.08, 0.08)
	_box(_platte, Vector3(0, -PLATTE_DICKE * 0.5, 0), Vector3(innen.x, PLATTE_DICKE, innen.y), _mat_stahl, false)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(innen.x, PLATTE_DICKE, innen.y)
	cs.shape = sh
	cs.position = Vector3(0, -PLATTE_DICKE * 0.5, 0)
	_platte.add_child(cs)
	# Warnstreifen an allen vier Kanten
	for sz: float in [-1.0, 1.0]:
		_box(_platte, Vector3(0, 0.005, sz * (innen.y * 0.5 - KANTE * 0.5)), Vector3(innen.x, 0.02, KANTE), _mat_kante, false)
	for sx: float in [-1.0, 1.0]:
		_box(_platte, Vector3(sx * (innen.x * 0.5 - KANTE * 0.5), 0.005, 0), Vector3(KANTE, 0.02, innen.y), _mat_kante, false)
	var l := OmniLight3D.new()
	l.light_color = LICHT
	l.light_energy = 0.8
	l.omni_range = 4.0
	l.position = Vector3(0, -0.6, 0)
	_platte.add_child(l)


func _spieler_lokal() -> Variant:
	if _spieler == null or not is_instance_valid(_spieler):
		_spieler = get_tree().get_first_node_in_group("spieler") as Node3D
		if _spieler == null:
			return null
	return to_local(_spieler.global_position)


func _auf_plattform(p: Vector3) -> bool:
	var y := _platte.position.y
	return p.x > 0.0 and p.x < groesse.x and p.z > 0.0 and p.z < groesse.y and p.y > y - 0.3 and p.y < y + STEH_HOEHE


func _wartet_an(p: Vector3, halt_y: float) -> bool:
	var mitte := Vector2(groesse.x * 0.5, groesse.y * 0.5)
	return Vector2(p.x, p.z).distance_to(mitte) < RUF_ABSTAND and absf(p.y - halt_y) < RUF_HOEHE


func _physics_process(delta: float) -> void:
	var sp: Variant = _spieler_lokal()
	match _zustand:
		Zustand.OBEN, Zustand.UNTEN:
			if sp == null:
				return
			var p: Vector3 = sp
			if _auf_plattform(p):
				if _gesperrt_bis_abstieg or (_zustand == Zustand.OBEN and not _freigegeben):
					return
				_auf_seit += delta
				if _auf_seit >= VERWEIL:
					_starten(_zustand == Zustand.UNTEN)
			else:
				_auf_seit = 0.0
				_gesperrt_bis_abstieg = false
				# Ruf von der anderen Haltestelle
				if _zustand == Zustand.OBEN and _wartet_an(p, unten_y):
					_starten(false)
				elif _zustand == Zustand.UNTEN and _wartet_an(p, oben_y):
					_starten(true)
		Zustand.FAEHRT_HOCH:
			_platte.position.y = minf(_platte.position.y + tempo * delta, oben_y)
			if _platte.position.y >= oben_y:
				_ankommen(Zustand.OBEN)
		Zustand.FAEHRT_RUNTER:
			_platte.position.y = maxf(_platte.position.y - tempo * delta, unten_y)
			if _platte.position.y <= unten_y:
				_ankommen(Zustand.UNTEN)


func _starten(nach_oben: bool) -> void:
	_zustand = Zustand.FAEHRT_HOCH if nach_oben else Zustand.FAEHRT_RUNTER
	_auf_seit = 0.0
	fahrt_gestartet.emit(nach_oben)


func _ankommen(z: Zustand) -> void:
	_zustand = z
	_auf_seit = 0.0
	var sp: Variant = _spieler_lokal()
	_gesperrt_bis_abstieg = sp != null and _auf_plattform(sp)
	if z == Zustand.OBEN:
		oben_angekommen.emit()
	else:
		unten_angekommen.emit()


## Gibt die Abfahrt von oben frei (die Luke ist offen).
func freigeben() -> void:
	_freigegeben = true


## Hoehe der Plattform-Oberkante (lokal), fuer Tests.
func plattform_y() -> float:
	return _platte.position.y
