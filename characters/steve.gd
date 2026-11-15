extends Node3D
## Steve: sitzender Gast im Sy-Ci Burgers, isst einen Burger und trinkt ab und zu. Modell mit Rig und Animation
## "Sit_and_Drink" (imported_models/Bürger_von_Synth-City). Ablauf in Zyklen: mehrere Bisse (Burger in der Hand,
## schrumpft pro Biss), danach ein Schluck (Becher in der Hand), dann kurze Pause.
## Exportiert: modell, modell_hoehe, hand_knochen (Handknochen für Burger/Becher), bisse, pause.
## Keine Signale. Wird von burger.gd auf einen Hocker gesetzt (Ursprung = Sitzflaeche).

@export var modell := "res://imported_models/Bürger_von_Synth-City/Bürger_von_Synth-City.glb"
@export var modell_hoehe := 1.7
@export var hand_knochen := "mixamorig_RightHand"
@export var bisse := 3
@export var pause := 2.5
@export var anim_name := "Sit_and_Drink"

const SITZ_ABSENKUNG := 0.0  ## Feinjustierung der Sitzhoehe (Meter)
const BISS_SCHRUMPF := 0.28  ## Anteil, um den der Burger pro Biss kleiner wird
const ANIM_TEMPO := 1.0
const PROP_VERSATZ := Vector3(0.0, 0.08, 0.04)

var _ap: AnimationPlayer
var _hand: BoneAttachment3D
var _burger: Node3D
var _becher: Node3D
var _figur: Node3D


func _ready() -> void:
	var res: Resource = load(modell)
	if not (res is PackedScene):
		return
	_figur = (res as PackedScene).instantiate()
	add_child(_figur)
	_ap = _figur.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var sk := _figur.find_child("Skeleton3D", true, false) as Skeleton3D
	var mi := _figur.find_child("*", true, false)
	var box := _huelle(_figur)
	var sk_faktor := modell_hoehe / maxf(box.size.y, 0.01)
	_figur.scale = Vector3.ONE * sk_faktor
	_figur.position.y = -box.position.y * sk_faktor + SITZ_ABSENKUNG
	if sk != null and sk.find_bone(hand_knochen) >= 0:
		_hand = BoneAttachment3D.new()
		_hand.bone_name = hand_knochen
		sk.add_child(_hand)
		_burger = _burger_bauen()
		_becher = _becher_bauen()
		_hand.add_child(_burger)
		_hand.add_child(_becher)
		_burger.visible = false
		_becher.visible = false
	if _ap != null:
		_ap.speed_scale = ANIM_TEMPO
		_ablauf()


func _ablauf() -> void:
	while is_inside_tree():
		_burger.scale = Vector3.ONE
		for i in bisse:
			_burger.visible = true
			_becher.visible = false
			_ap.play(anim_name)
			await _ap.animation_finished
			_burger.scale = Vector3.ONE * (1.0 - BISS_SCHRUMPF * (i + 1))
			await get_tree().create_timer(pause).timeout
		_burger.visible = false
		_becher.visible = true
		_ap.play(anim_name)
		await _ap.animation_finished
		_becher.visible = false
		await get_tree().create_timer(pause).timeout


func _burger_bauen() -> Node3D:
	var n := Node3D.new()
	n.position = PROP_VERSATZ
	var brot := StandardMaterial3D.new()
	brot.albedo_color = Color(0.85, 0.55, 0.2)
	var patty := StandardMaterial3D.new()
	patty.albedo_color = Color(0.25, 0.12, 0.07)
	var salat := StandardMaterial3D.new()
	salat.albedo_color = Color(0.3, 0.8, 0.2)
	for e in [[0.0, 0.05, brot], [0.05, 0.03, patty], [0.08, 0.02, salat], [0.11, 0.05, brot]]:
		var m := MeshInstance3D.new()
		var z := CylinderMesh.new()
		z.top_radius = 0.045 / modell_hoehe * 1.7
		z.bottom_radius = z.top_radius
		z.height = float(e[1])
		m.mesh = z
		m.material_override = e[2]
		m.position.y = float(e[0])
		n.add_child(m)
	n.scale = Vector3.ONE / _figur.scale.x
	return n


func _becher_bauen() -> Node3D:
	var n := Node3D.new()
	n.position = PROP_VERSATZ
	var m := MeshInstance3D.new()
	var z := CylinderMesh.new()
	z.top_radius = 0.04
	z.bottom_radius = 0.03
	z.height = 0.12
	m.mesh = z
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.15, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.2, 0.3)
	mat.emission_energy_multiplier = 0.6
	m.material_override = mat
	n.add_child(m)
	n.scale = Vector3.ONE / _figur.scale.x
	return n


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
