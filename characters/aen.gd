extends Node3D
## Aen: Junge aus Synth-City, sitzt auf einer Bank im Central Park (Modell imported_models/Aen_Character_Turnaround,
## Animation "Sitting_Clap" in Endlosschleife). Ursprung dieses Knotens = Mitte der Sitzflaeche, Blick nach +z.
## Das Modell wird auf `modell_hoehe` skaliert und so verschoben, dass sein Hueftknochen ueber der Sitzflaeche liegt.
## Exportiert: modell, modell_hoehe, anim_name, hueft_knochen, hueft_ueber_sitz, hueft_nach_hinten.
## Keine Signale. Wird von park.gd auf eine Bank gesetzt. Kein Dialog (siehe docs/OFFENE_FRAGEN.md).

@export var modell := "res://imported_models/Aen_Character_Turnaround/Aen_Character_Turnaround.glb"
@export var modell_hoehe := 1.55
@export var anim_name := "Sitting_Clap"
@export var hueft_knochen := "mixamorig_Hips"
@export var hueft_ueber_sitz := 0.12   ## Meter, Hueftknochen ueber der Sitzflaeche
@export var hueft_nach_hinten := 0.05  ## Meter, Hueftknochen hinter dem Sitzmittelpunkt (Richtung Lehne)

const MESS_FRAMES := 3        ## Frames warten, bis die Animation die Knochen gesetzt hat
const MESS_ZEIT := 0.4        ## Zeitpunkt in der Animation (Sekunden), an dem die Sitzhoehe gemessen wird
const ANIM_TEMPO := 1.0

var _figur: Node3D
var _skelett: Skeleton3D
var _ap: AnimationPlayer


func _ready() -> void:
	var res: Resource = load(modell)
	if not (res is PackedScene):
		push_warning("Aen: Modell nicht gefunden: " + modell)
		return
	_figur = (res as PackedScene).instantiate()
	add_child(_figur)
	var box := _huelle(_figur)
	var sk := modell_hoehe / maxf(box.size.y, 0.01)
	_figur.scale = Vector3.ONE * sk
	_figur.position.y = -box.position.y * sk  # vorlaeufig: Fuesse auf Ursprung, wird gleich ueber die Huefte korrigiert
	_skelett = _figur.find_child("Skeleton3D", true, false) as Skeleton3D
	_ap = _figur.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _ap != null and _ap.has_animation(anim_name):
		_ap.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
		_ap.speed_scale = ANIM_TEMPO
		_ap.play(anim_name)
		_ap.seek(MESS_ZEIT, true)
	_ausrichten()


## Misst die Huefte in der Sitzpose und schiebt das Modell so, dass sie auf der Bank sitzt.
func _ausrichten() -> void:
	for i in MESS_FRAMES:
		await get_tree().process_frame
	if _skelett == null:
		return
	var idx := _skelett.find_bone(hueft_knochen)
	if idx < 0:
		idx = _skelett.find_bone(hueft_knochen.replace("_", ":"))
	if idx < 0:
		return
	var h_lokal := to_local(_skelett.to_global(_skelett.get_bone_global_pose(idx).origin))
	_figur.position += Vector3(-h_lokal.x, hueft_ueber_sitz - h_lokal.y, -hueft_nach_hinten - h_lokal.z)


func _huelle(n: Node) -> AABB:
	var ergebnis := AABB()
	var erstes := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var t := Transform3D.IDENTITY
		var k: Node = m
		while k != null and k != n.get_parent():
			if k is Node3D:
				t = (k as Node3D).transform * t
			k = k.get_parent()
		var a := t * m.get_aabb()
		ergebnis = a if erstes else ergebnis.merge(a)
		erstes = false
	return ergebnis
