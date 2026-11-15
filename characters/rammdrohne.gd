extends "res://characters/enemy.gd"
## Rammdrohne: fliegt tief, holt aus (Leuchten, Zittern) und rast dann geradeaus auf den Spieler zu.
## Trifft sie den Spieler: Schaden + Rueckstoss. Knallt sie gegen eine Wand: betaeubt (STUNNED), nimmt dann
## doppelten Blitzschaden (Faktor in den Daten). Ausweichen per Dash ist die Idee.
## Daten: res://data/gegner/rammdrohne.tres. Signale: siehe enemy.gd.

const STANDARD := preload("res://data/gegner/rammdrohne.tres")

const KOERPER_LAENGE := 1.3
const KOERPER_RADIUS := 0.45
const SPITZE_LAENGE := 0.6
const FLOSSEN := 3
const ZITTERN := 0.06
const AUSHOL_ENERGIE := 7.0
const SPRINT_ENERGIE := 5.0
const NORMAL_ENERGIE := 2.0
## Wand = Kollision, deren Normale eher waagerecht ist
const WAND_NORMAL_Y := 0.6
## Mindest-Sprintzeit, bevor eine Wand zaehlt (damit sie nicht am Start haengen bleibt)
const SPRINT_MIN := 0.08
const STERNE_TEMPO := 5.0
const STERNE_RADIUS := 0.7
## Nach einem Treffer am Spieler prallt sie ab (m/s)
const ABPRALL := 9.0

var _sprint := false
var _sprint_richtung := Vector3.FORWARD
var _hat_getroffen := false
var _glow: StandardMaterial3D
var _sterne: Node3D
var _schweif: CPUParticles3D


func _standard_daten() -> GEGNER_DATEN:
	return STANDARD


func _modell_bauen() -> void:
	_form_setzen(KOERPER_RADIUS + 0.2)
	var c := daten.farbe
	var gehaeuse := StandardMaterial3D.new()
	gehaeuse.albedo_color = Color(0.09, 0.06, 0.09)
	gehaeuse.metallic = 0.85
	gehaeuse.roughness = 0.25
	var k := MeshInstance3D.new()
	var km := CapsuleMesh.new()
	km.radius = KOERPER_RADIUS
	km.height = KOERPER_LAENGE
	k.mesh = km
	k.material_override = gehaeuse
	k.rotation.x = PI / 2.0
	_modell.add_child(k)
	var spitze := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.0
	sm.bottom_radius = KOERPER_RADIUS * 0.8
	sm.height = SPITZE_LAENGE
	spitze.mesh = sm
	_glow = _neon_mat(c, NORMAL_ENERGIE)
	spitze.material_override = _glow
	spitze.rotation.x = -PI / 2.0
	spitze.position.z = -(KOERPER_LAENGE * 0.5 + SPITZE_LAENGE * 0.3)
	_modell.add_child(spitze)
	var band := MeshInstance3D.new()
	var bm := TorusMesh.new()
	bm.inner_radius = KOERPER_RADIUS * 0.95
	bm.outer_radius = KOERPER_RADIUS * 1.1
	band.mesh = bm
	band.material_override = _neon_mat(c, 2.0)
	band.rotation.x = PI / 2.0
	_modell.add_child(band)
	for i in FLOSSEN:
		var f := MeshInstance3D.new()
		var fm := BoxMesh.new()
		fm.size = Vector3(0.05, 0.45, 0.4)
		f.mesh = fm
		f.material_override = _neon_mat(c, 1.0)
		var halter := Node3D.new()
		halter.rotation.z = TAU * i / FLOSSEN
		f.position = Vector3(0, KOERPER_RADIUS + 0.15, KOERPER_LAENGE * 0.35)
		halter.add_child(f)
		_modell.add_child(halter)
	var licht := OmniLight3D.new()
	licht.light_color = c
	licht.light_energy = 1.0
	licht.omni_range = 4.0
	_modell.add_child(licht)
	# Schweif beim Sprint
	_schweif = CPUParticles3D.new()
	_schweif.emitting = false
	_schweif.amount = 40
	_schweif.lifetime = 0.35
	_schweif.direction = Vector3.BACK
	_schweif.spread = 15.0
	_schweif.initial_velocity_min = 2.0
	_schweif.initial_velocity_max = 4.0
	_schweif.gravity = Vector3.ZERO
	var pm := SphereMesh.new()
	pm.radius = 0.06
	pm.height = 0.12
	var pmat := StandardMaterial3D.new()
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.albedo_color = c
	pm.material = pmat
	_schweif.mesh = pm
	_schweif.position.z = KOERPER_LAENGE * 0.5
	_modell.add_child(_schweif)
	# Betaeubungs-"Sterne": kleine kreisende Funken ueber dem Kopf
	_sterne = Node3D.new()
	_sterne.position.y = KOERPER_RADIUS + 0.4
	_sterne.visible = false
	for i in 3:
		var s := MeshInstance3D.new()
		var ssm := SphereMesh.new()
		ssm.radius = 0.08
		ssm.height = 0.16
		s.mesh = ssm
		var smat := StandardMaterial3D.new()
		smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		smat.albedo_color = Color(1.0, 1.0, 0.4)
		s.material_override = smat
		var w := TAU * i / 3.0
		s.position = Vector3(cos(w), 0.0, sin(w)) * STERNE_RADIUS
		_sterne.add_child(s)
	add_child(_sterne)


func _process(delta: float) -> void:
	_sterne.visible = zustand == Zustand.STUNNED
	if _sterne.visible:
		_sterne.rotate_y(STERNE_TEMPO * delta)
	if zustand == Zustand.ATTACK and not _sprint:
		_modell.position = Vector3(randf_range(-ZITTERN, ZITTERN), randf_range(-ZITTERN, ZITTERN), 0.0)
	elif zustand != Zustand.DEAD:
		_modell.position = Vector3.ZERO


func _angriff_start() -> void:
	_sprint = false
	_hat_getroffen = false
	_glow.emission_energy_multiplier = AUSHOL_ENERGIE


func _angriff(delta: float) -> void:
	if not _sprint:
		_bremsen(delta)
		_schauen_zu(_spieler.global_position, delta)
		if _zustand_zeit >= daten.ausholen:
			_sprint = true
			var d := _spieler_punkt() - global_position
			d.y = 0.0
			_sprint_richtung = d.normalized() if d.length() > 0.1 else -global_basis.z
			_glow.emission_energy_multiplier = SPRINT_ENERGIE
			_schweif.emitting = true
		return
	velocity.x = _sprint_richtung.x * daten.sprint_tempo
	velocity.z = _sprint_richtung.z * daten.sprint_tempo
	if _zustand_zeit >= daten.ausholen + daten.sprint_dauer:
		_sprint_ende()
		_angriff_beenden()


func _nach_bewegung() -> void:
	if zustand != Zustand.ATTACK or not _sprint:
		return
	for i in get_slide_collision_count():
		var k := get_slide_collision(i)
		var wer := k.get_collider()
		if wer is Node and (wer as Node).is_in_group("spieler"):
			if not _hat_getroffen and wer.has_method("schaden_nehmen"):
				_hat_getroffen = true
				wer.schaden_nehmen(daten.schaden, global_position)
			_sprint_ende()
			velocity = -_sprint_richtung * ABPRALL
			_angriff_beenden()
			return
		if wer is Node and (wer as Node).is_in_group("gegner"):
			continue
		if absf(k.get_normal().y) < WAND_NORMAL_Y and _zustand_zeit > daten.ausholen + SPRINT_MIN:
			_wand_treffer(k.get_position())
			return


func _wand_treffer(pos: Vector3) -> void:
	_sprint_ende()
	BLITZ._treffer_effekt(get_parent(), pos, 0.4)
	velocity = -_sprint_richtung * 2.0
	_angriff_timer = daten.angriff_pause
	betaeuben(daten.betaeubung_dauer)


func _sprint_ende() -> void:
	_sprint = false
	_schweif.emitting = false
	_glow.emission_energy_multiplier = NORMAL_ENERGIE
