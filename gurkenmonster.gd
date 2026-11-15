extends CharacterBody3D
## Gurken-Monster: streift durch den Gurken-Wald, verschiesst Schleim und hat einen Energiebalken.

## Der Gurken-Wald (x, z). Das Monster verlaesst diesen Bereich nie.
const FELD := Rect2(-312.0, -306.0, 122.0, 194.0)
const RAND := 4.0
const MAX_HP := 20
const GRAVITY := 30.0
const TEMPO_STREIFEN := 3.5
const TEMPO_JAGD := 6.0
const ERFASSUNG := 75.0
const SCHUSS_REICHWEITE := 60.0
const HALTEABSTAND := 20.0
const SCHUSS_PAUSE := 2.3
const SCHLEIM_TEMPO := 26.0
const KRISTALLE_BEIM_TOD := 12

var hp := MAX_HP
var tot := false
var _bereit := false
var _ziel := Vector3.ZERO
var _hat_ziel := false
var _pause := 1.0
var _umweg_zeit := 0.0
var _schuss_timer := 3.0
var _steck_timer := 0.0
var _steck_pos := Vector3.ZERO
var _spieler: Node3D
var _meshes: Array = []
var _flash: StandardMaterial3D
var _flash_tween: Tween

@onready var modell: Node3D = $Modell
@onready var balken: MeshInstance3D = $Balken
@onready var anim: AnimationPlayer = $Modell.find_child("AnimationPlayer", true, false)


func _ready() -> void:
	add_to_group("minimap_marker")
	set_meta("mm_farbe", Color(0.3, 1.0, 0.3))
	randomize()
	_flash = StandardMaterial3D.new()
	_flash.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash.albedo_color = Color(1, 1, 1, 0)
	for m in modell.find_children("*", "MeshInstance3D", true, false):
		m.material_overlay = _flash
	if anim != null:
		for n in anim.get_animation_list():
			anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
		anim.play(anim.get_animation_list()[0])
		anim.pause()
	balken.material_override = balken.material_override.duplicate()
	_spieler = get_tree().get_first_node_in_group("spieler")
	# Kollisionen der Stadt gehen erst nach ein paar Physik-Frames in den Raum
	await get_tree().physics_frame
	await get_tree().physics_frame
	_freien_platz_suchen()
	_bereit = true


func _freien_platz_suchen() -> void:
	var raum := get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var k := CapsuleShape3D.new()
	k.radius = 2.2
	k.height = 6.0
	q.shape = k
	for i in 80:
		var p := Vector3(randf_range(FELD.position.x + 20, FELD.end.x - 20), 3.2, randf_range(FELD.position.y + 20, FELD.end.y - 20))
		q.transform = Transform3D(Basis.IDENTITY, p)
		if raum.intersect_shape(q, 1).is_empty():
			global_position = Vector3(p.x, 0.2, p.z)
			return
	global_position = Vector3(FELD.get_center().x, 0.2, FELD.get_center().y)


func _clamp_feld(p: Vector3) -> Vector3:
	p.x = clampf(p.x, FELD.position.x + RAND, FELD.end.x - RAND)
	p.z = clampf(p.z, FELD.position.y + RAND, FELD.end.y - RAND)
	return p


func _physics_process(delta: float) -> void:
	if not _bereit or tot:
		return
	if _spieler == null:
		_spieler = get_tree().get_first_node_in_group("spieler")
	var tempo := 0.0
	var ziel := global_position
	var schauen := Vector3.ZERO
	var nah := false
	var dist := 9999.0
	if _spieler != null:
		dist = global_position.distance_to(_spieler.global_position)
		nah = dist < ERFASSUNG

	if nah:
		# Jagd: auf den Spieler zu, aber nur bis zur Feldgrenze
		ziel = _clamp_feld(_spieler.global_position)
		var flach := Vector2(ziel.x - global_position.x, ziel.z - global_position.z)
		if dist > HALTEABSTAND and flach.length() > 2.0:
			tempo = TEMPO_JAGD
		schauen = _spieler.global_position - global_position
		_hat_ziel = false
		_schuss_timer -= delta
		if _schuss_timer <= 0.0 and dist < SCHUSS_REICHWEITE:
			_schuss_timer = SCHUSS_PAUSE
			_schiessen()
	else:
		_schuss_timer = maxf(_schuss_timer, 1.5)
		# Streifen: Zufallsziel im Feld, zwischendurch Pausen
		if _pause > 0.0:
			_pause -= delta
		else:
			if not _hat_ziel:
				_ziel = _clamp_feld(Vector3(randf_range(FELD.position.x, FELD.end.x), 0.0, randf_range(FELD.position.y, FELD.end.y)))
				_hat_ziel = true
				_umweg_zeit = 12.0
			ziel = _ziel
			var d := Vector2(_ziel.x - global_position.x, _ziel.z - global_position.z).length()
			_umweg_zeit -= delta
			if d < 3.0 or _umweg_zeit <= 0.0:
				_hat_ziel = false
				_pause = randf_range(1.0, 3.5)
			else:
				tempo = TEMPO_STREIFEN

	var richtung := Vector3(ziel.x - global_position.x, 0.0, ziel.z - global_position.z)
	if tempo > 0.0 and richtung.length() > 0.01:
		richtung = richtung.normalized()
		schauen = richtung if schauen == Vector3.ZERO or not nah else schauen
	else:
		richtung = Vector3.ZERO
	var v := richtung * tempo
	velocity.x = move_toward(velocity.x, v.x, 25.0 * delta)
	velocity.z = move_toward(velocity.z, v.z, 25.0 * delta)
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	schauen.y = 0.0
	if schauen.length() > 0.01:
		var w := atan2(-schauen.x, -schauen.z)
		rotation.y = lerp_angle(rotation.y, w, 4.0 * delta)
	move_and_slide()
	global_position = Vector3(_clamp_feld(global_position).x, global_position.y, _clamp_feld(global_position).z)

	# Haengt er an einer Gurke fest? Dann anderes Ziel
	_steck_timer += delta
	if _steck_timer > 1.2:
		if tempo > 0.0 and global_position.distance_to(_steck_pos) < 0.8:
			_hat_ziel = false
			_pause = 0.2
			if nah:
				# seitlich ausweichen
				_ziel = _clamp_feld(global_position + Vector3(randf_range(-15, 15), 0, randf_range(-15, 15)))
				_hat_ziel = true
				_pause = 0.0
				_umweg_zeit = 3.0
		_steck_pos = global_position
		_steck_timer = 0.0

	if anim != null:
		var laeuft := Vector2(velocity.x, velocity.z).length() > 0.5
		if laeuft:
			anim.speed_scale = Vector2(velocity.x, velocity.z).length() / 3.5
			if not anim.is_playing():
				anim.play()
		else:
			anim.pause()


func _schiessen() -> void:
	# kurzes Ausholen, dann Schleim in hohem Bogen
	var s0 := modell.scale
	var t2 := create_tween()
	t2.tween_property(modell, "scale", s0 * Vector3(1.12, 0.82, 1.12), 0.25)
	t2.tween_property(modell, "scale", s0 * Vector3(0.92, 1.12, 0.92), 0.08)
	t2.tween_property(modell, "scale", s0, 0.2)
	await get_tree().create_timer(0.3).timeout
	if tot or _spieler == null:
		return
	var start := global_position + Vector3(0, 4.3, 0) + (-global_basis.z) * 2.0
	var ziel: Vector3 = _spieler.global_position + Vector3(0, 1.0, 0)
	ziel += Vector3(randf_range(-1.5, 1.5), 0.0, randf_range(-1.5, 1.5))
	var d := ziel - start
	var flach := Vector2(d.x, d.z)
	var zeit := maxf(flach.length() / SCHLEIM_TEMPO, 0.4)
	var vxz := flach / zeit
	var vy := (d.y + 0.5 * 20.0 * zeit * zeit) / zeit
	var s := Area3D.new()
	s.set_script(preload("res://schleim.gd"))
	get_parent().add_child(s)
	s.global_position = start
	s.start(Vector3(vxz.x, vy, vxz.y), self)


## Wird vom Zauberblitz aufgerufen.
func treffer() -> void:
	if tot:
		return
	hp -= 1
	balken.material_override.set_shader_parameter("fuell", float(hp) / MAX_HP)
	_flash.albedo_color = Color(1, 1, 1, 0.55)
	if _flash_tween:
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "albedo_color:a", 0.0, 0.18)
	if hp <= 0:
		_sterben()


func _sterben() -> void:
	tot = true
	velocity = Vector3.ZERO
	balken.visible = false
	if anim != null:
		anim.pause()
	var tw := create_tween()
	tw.tween_property(modell, "scale", modell.scale * Vector3(1.3, 0.05, 1.3), 0.6)
	tw.parallel().tween_property(_flash, "albedo_color", Color(0.4, 1.0, 0.1, 0.8), 0.4)
	tw.tween_callback(_beute_und_weg)


func _beute_und_weg() -> void:
	var k_szene := preload("res://kristall.tscn")
	for i in KRISTALLE_BEIM_TOD:
		var k = k_szene.instantiate()
		get_parent().add_child(k)
		var w := randf() * TAU
		var r := randf_range(2.0, 8.0)
		k.start(global_position + Vector3(cos(w) * r, 1.6, sin(w) * r), randi() % 3)
		if _spieler != null:
			_spieler.kristalle_gesamt += 1
	if _spieler != null:
		_spieler.kristalle_geaendert.emit(_spieler.kristalle, _spieler.kristalle_gesamt)
	visible = false
	$Kollision.set_deferred("disabled", true)
	await get_tree().create_timer(30.0).timeout
	_wiederbeleben()


func _wiederbeleben() -> void:
	hp = MAX_HP
	balken.material_override.set_shader_parameter("fuell", 1.0)
	modell.scale = Vector3.ONE * 3.2
	_flash.albedo_color = Color(1, 1, 1, 0)
	_freien_platz_suchen()
	visible = true
	balken.visible = true
	$Kollision.disabled = false
	tot = false
