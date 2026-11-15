extends Node
## Hinweis-Pulse: Taste H (Pad: linke Schulter) laesst eine Lichtsaeule am naechsten noch nicht
## geloesten Schalter pulsieren. Optional, kein Zwang. Schalter markieren ihr Raetsel mit Meta "raetsel_id".
## Ein Raetsel gilt als geloest, wenn GameState.raetsel die id kennt.

const DAUER := 4.0
const HOEHE := 40.0
const RADIUS := 0.6
const MAX_ENTFERNUNG := 250.0
const HINWEIS_FARBE := Color(1.0, 0.85, 0.2)

var _spieler: Node3D


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("hinweis"):
		_pulsieren()


func _pulsieren() -> void:
	if _spieler == null:
		_spieler = get_tree().get_first_node_in_group("spieler")
		if _spieler == null:
			return
	var bestes: Node3D = null
	var best_d := MAX_ENTFERNUNG
	for n in get_tree().get_nodes_in_group("blitz_ziel"):
		var z := n as Node3D
		if z == null or bool(z.get("aktiv")):
			continue
		var rid := str(z.get_meta("raetsel_id", ""))
		if rid != "" and GameState.raetsel.get(rid, false):
			continue
		var d := z.global_position.distance_to(_spieler.global_position)
		if d < best_d:
			best_d = d
			bestes = z
	if bestes == null:
		return
	var s := MeshInstance3D.new()
	var zyl := CylinderMesh.new()
	zyl.top_radius = RADIUS
	zyl.bottom_radius = RADIUS
	zyl.height = HOEHE
	s.mesh = zyl
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(HINWEIS_FARBE, 0.5)
	s.material_override = m
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_tree().current_scene.add_child(s)
	s.global_position = bestes.global_position + Vector3.UP * HOEHE * 0.5
	var tw := s.create_tween()
	tw.set_loops(int(DAUER))
	tw.tween_property(m, "albedo_color:a", 0.1, 0.5)
	tw.tween_property(m, "albedo_color:a", 0.5, 0.5)
	s.create_tween().tween_callback(s.queue_free).set_delay(DAUER)
