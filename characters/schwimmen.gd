extends Node3D
## Schwimmen fuer Zauber-Man (Kind von Modell im Spieler, Ansatz nach Cogito: Wasserzonen + Unterwasser-Effekt).
## Wasserzonen: Area3D in der Gruppe "wasser" mit Meta "oberflaeche" (Welthoehe des Wasserspiegels), z. B. der
## Teich in park.gd. wasser_bei(punkt) liefert den Wasserspiegel an einem Punkt oder NAN.
## Animation: eigene, unanimierte Instanz der Figur (assets/sentinel/sentinel_character.fbx) in Kraul-Haltung:
## Koerper waagerecht (Neigung um eine Drehachse in Brusthoehe), Arme kreisen gegenlaeufig, Beine schlagen.
## Unterwasser: tuerkise Toenung ueber dem Bild, solange die Kamera unter dem Wasserspiegel in einer Zone ist.
## Methoden: wasser_bei(), pose(delta, tempo, neigung), unterwasser_pruefen(kamera_pos). Keine Signale, keine Exporte.

const MODELL := "res://assets/sentinel/sentinel_character.fbx"
const DREHPUNKT_Y := 1.0             ## Hoehe (Modellraum), um die der Koerper beim Schwimmen kippt
const KRAUL_TEMPO := 4.2             ## rad/s Armkreis bei voller Fahrt
const KRAUL_RUHE := 1.2              ## rad/s im Stillstand (Wassertreten)
const BEIN_TEMPO := 9.0
const BEIN_WINKEL := 0.35
const ARM_SEITE := 0.18
const UNTERWASSER_FARBE := Color(0.02, 0.28, 0.38, 0.45)
const ARME: Array[Array] = [["mixamorig_RightArm", "mixamorig_RightForeArm", -1.0, 0.0], ["mixamorig_LeftArm", "mixamorig_LeftForeArm", 1.0, PI]]
const BEINE: Array[Array] = [["mixamorig_RightUpLeg", "mixamorig_RightLeg", -1.0, 0.0], ["mixamorig_LeftUpLeg", "mixamorig_LeftLeg", 1.0, PI]]

var _modell: Node3D
var _skelett: Skeleton3D
var _phase := 0.0
var _bein_phase := 0.0
var _neigung := 0.0
var _toenung: ColorRect


func _ready() -> void:
	if ResourceLoader.exists(MODELL):
		_modell = (load(MODELL) as PackedScene).instantiate() as Node3D
		add_child(_modell)
		var sk := _modell.find_children("*", "Skeleton3D", true, false)
		if not sk.is_empty():
			_skelett = sk[0] as Skeleton3D
	var ebene := CanvasLayer.new()
	ebene.layer = 5
	add_child(ebene)
	_toenung = ColorRect.new()
	_toenung.color = UNTERWASSER_FARBE
	_toenung.set_anchors_preset(Control.PRESET_FULL_RECT)
	_toenung.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toenung.visible = false
	ebene.add_child(_toenung)


## Wasserspiegel (Welthoehe) an einem Punkt, oder NAN ausserhalb aller Wasserzonen.
func wasser_bei(punkt: Vector3) -> float:
	var q := PhysicsPointQueryParameters3D.new()
	q.position = punkt
	q.collide_with_areas = true
	q.collide_with_bodies = false
	for t in get_world_3d().direct_space_state.intersect_point(q, 8):
		var a := t["collider"] as Node
		if a != null and a.is_in_group("wasser") and a.has_meta("oberflaeche"):
			return float(a.get_meta("oberflaeche"))
	return NAN


## Unterwasser-Toenung, wenn die Kamera unter einem Wasserspiegel liegt.
func unterwasser_pruefen(kamera_pos: Vector3) -> bool:
	var w := wasser_bei(kamera_pos)
	var unten := not is_nan(w) and kamera_pos.y < w
	_toenung.visible = unten
	return unten


## Kraul-Haltung. tempo 0..1 (Vortrieb), neigung in rad (+ = Kopf nach unten zum Tauchen).
func pose(delta: float, tempo: float, neigung: float) -> void:
	if _skelett == null:
		return
	_phase = fmod(_phase + delta * lerpf(KRAUL_RUHE, KRAUL_TEMPO, clampf(tempo, 0.0, 1.0)), TAU)
	_bein_phase = fmod(_bein_phase + delta * BEIN_TEMPO * maxf(tempo, 0.4), TAU)
	_neigung = lerpf(_neigung, PI * 0.5 * clampf(0.15 + tempo * 0.75, 0.0, 0.9) + neigung, minf(1.0, 4.0 * delta))
	# Koerper kippen: Kopf (+y) nach vorn (+z), Drehung um die Brust
	var t := Transform3D(Basis(), Vector3(0, DREHPUNKT_Y, 0)) * Transform3D(Basis(Vector3.RIGHT, _neigung), Vector3.ZERO) * Transform3D(Basis(), Vector3(0, -DREHPUNKT_Y, 0))
	_modell.transform = t
	for a in ARME:
		var w: float = _phase + float(a[3])
		# Arm kreist um die Querachse: ueber den Kopf (+y), unter dem Bauch (+z), an der Huefte (-y), ueber den Ruecken (-z)
		var r := Vector3(float(a[2]) * ARM_SEITE, cos(w), sin(w))
		_glied(a[0], a[1], r, r + Vector3(0, 0, 0.15))
	for b in BEINE:
		var w: float = sin(_bein_phase + float(b[3])) * BEIN_WINKEL
		var r := Vector3(float(b[2]) * 0.06, -1.0, sin(w))
		_glied(b[0], b[1], r, r)


func _glied(oben: String, unten: String, richtung_oben: Vector3, richtung_unten: Vector3) -> void:
	var ob := _skelett.find_bone(oben)
	var ub := _skelett.find_bone(unten)
	if ob < 0 or ub < 0:
		return
	var eltern := _skelett.get_bone_global_pose(_skelett.get_bone_parent(ob))
	var g := _ausrichten(ob, eltern, richtung_oben.normalized())
	_ausrichten(ub, g, richtung_unten.normalized())


## Dreht einen Knochen so, dass seine Laengsachse (+y) in `richtung` (Skelettraum) zeigt.
func _ausrichten(b: int, eltern_global: Transform3D, richtung: Vector3) -> Transform3D:
	var g := eltern_global * _skelett.get_bone_rest(b)
	g.basis = Basis(Quaternion(g.basis.y.normalized(), richtung)) * g.basis
	_skelett.set_bone_pose_rotation(b, (eltern_global.basis.inverse() * g.basis).get_rotation_quaternion())
	return g
