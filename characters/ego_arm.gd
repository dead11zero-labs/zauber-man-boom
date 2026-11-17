extends Node3D
## Ego-Arm: Zauber-Mans rechter Arm als Viewmodel in der Ego-Perspektive (Kind der Spielerkamera).
## Nutzt das echte Figurenmodell (assets/sentinel/sentinel_character.fbx): Kopf, linker Arm, Beine und Umhang
## werden ueber ihre Knochen auf null skaliert, der rechte Arm wird nach vorn gewinkelt (Knochen-Globalposen).
## Bewegung: leichtes Wippen beim Laufen, Atmen im Stand, Stoss nach vorn beim Zaubern, Leuchten beim Aufladen.
## Methoden: wippen_setzen(tempo 0..1), zaubern(), ladung_setzen(anteil). Keine Signale.
## Exportiert: schulter (Lage der rechten Schulter im Kameraraum), oberarm_richtung, unterarm_richtung (Kameraraum).

const MODELL := "res://assets/sentinel/sentinel_character.fbx"
const AUSBLENDEN: Array[String] = ["mixamorig_Head", "mixamorig_LeftShoulder", "mixamorig_LeftUpLeg", "mixamorig_RightUpLeg", "Bone_032"]
const OBERARM := "mixamorig_RightArm"
const UNTERARM := "mixamorig_RightForeArm"
const HAND := "mixamorig_RightHand"
const WIPP_HOEHE := 0.018
const WIPP_SEITE := 0.012
const WIPP_TEMPO := 9.0
const ATEM_HOEHE := 0.004
const ATEM_TEMPO := 1.6
const STOSS_WEG := 0.16
const STOSS_ZEIT := 0.22
const LICHT_FARBE := Color(0.4, 0.85, 1.0)
const LICHT_MAX := 3.0

@export var schulter := Vector3(0.3, -0.31, -0.05)
@export var oberarm_richtung := Vector3(0.0, -0.08, -1.0)
@export var unterarm_richtung := Vector3(-0.22, 0.42, -1.0)

var _modell: Node3D
var _skelett: Skeleton3D
var _basis_pos := Vector3.ZERO
var _zeit := 0.0
var _wippen := 0.0
var _stoss := 0.0
var _licht: OmniLight3D


func _ready() -> void:
	if not ResourceLoader.exists(MODELL):
		return
	_modell = (load(MODELL) as PackedScene).instantiate() as Node3D
	_modell.rotation.y = PI   # Figur schaut entlang +z, die Kamera entlang -z
	add_child(_modell)
	for mi: MeshInstance3D in _modell.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sk := _modell.find_children("*", "Skeleton3D", true, false)
	if sk.is_empty():
		return
	_skelett = sk[0] as Skeleton3D
	for name_ in AUSBLENDEN:
		var b := _skelett.find_bone(name_)
		if b >= 0:
			_skelett.set_bone_pose_scale(b, Vector3.ONE * 0.001)
	_arm_beugen()
	# Modell so verschieben, dass die rechte Schulter an `schulter` (Kameraraum) liegt
	var ob := _skelett.find_bone(OBERARM)
	var schulter_modell := _modell.transform * (_skelett.transform * _skelett.get_bone_global_pose(ob).origin)
	_basis_pos = schulter - schulter_modell
	_modell.position += _basis_pos
	_licht = OmniLight3D.new()
	_licht.light_color = LICHT_FARBE
	_licht.omni_range = 2.5
	_licht.light_energy = 0.0
	add_child(_licht)


## Richtung (Kameraraum) in Skelettraum umrechnen.
func _ins_skelett(r: Vector3) -> Vector3:
	return ((_modell.transform * _skelett.transform).basis.inverse() * r).normalized()


## Dreht einen Knochen so, dass seine Laengsachse (+y) in `richtung` (Skelettraum) zeigt.
## `eltern_global` ist die neue Globalpose des Elternknochens.
func _ausrichten(b: int, eltern_global: Transform3D, richtung: Vector3) -> Transform3D:
	var g := eltern_global * _skelett.get_bone_rest(b)
	var q := Quaternion(g.basis.y.normalized(), richtung)
	g.basis = Basis(q) * g.basis
	_skelett.set_bone_pose_rotation(b, (eltern_global.basis.inverse() * g.basis).get_rotation_quaternion())
	return g


func _arm_beugen() -> void:
	var ob := _skelett.find_bone(OBERARM)
	var ub := _skelett.find_bone(UNTERARM)
	var eltern := _skelett.get_bone_global_pose(_skelett.get_bone_parent(ob))
	var g := _ausrichten(ob, eltern, _ins_skelett(oberarm_richtung))
	_ausrichten(ub, g, _ins_skelett(unterarm_richtung))


func wippen_setzen(tempo: float) -> void:
	_wippen = clampf(tempo, 0.0, 1.0)


func zaubern() -> void:
	_stoss = STOSS_ZEIT


func ladung_setzen(anteil: float) -> void:
	if _licht != null:
		_licht.light_energy = LICHT_MAX * anteil


func _process(delta: float) -> void:
	if _modell == null or not is_visible_in_tree():
		return
	_zeit += delta
	_stoss = maxf(_stoss - delta, 0.0)
	var w := _wippen
	var versatz := Vector3(sin(_zeit * WIPP_TEMPO * 0.5) * WIPP_SEITE * w,
		absf(sin(_zeit * WIPP_TEMPO * 0.5)) * -WIPP_HOEHE * w + sin(_zeit * ATEM_TEMPO) * ATEM_HOEHE, 0.0)
	var stoss := sin(_stoss / STOSS_ZEIT * PI) * STOSS_WEG
	versatz += Vector3(-0.03, 0.02, -1.0) * stoss
	_modell.position = _basis_pos + versatz
	if _licht != null and _skelett != null:
		var h := _skelett.find_bone(HAND)
		_licht.position = _modell.transform * (_skelett.transform * _skelett.get_bone_global_pose(h).origin)
