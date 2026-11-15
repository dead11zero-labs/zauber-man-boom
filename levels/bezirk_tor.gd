extends Node3D
## Energie-Tor am Durchgang zum Neon-Basar (Neo-Distrikt). Bleibt zu, bis die benoetigte Grimoire-Seite
## gefunden ist (Akt 1 -> Seite 1). Oeffnet sich dann mit einem kurzen Ausblenden.
## Exportiert: seite (Nummer der benoetigten Seite). Signale: keine, hoert auf EventBus.seite_gesammelt.

@export var seite := 1
@export var breite := 40.0
@export var hoehe := 30.0

var _koerper: StaticBody3D
var _flaeche: MeshInstance3D
var _material: StandardMaterial3D
var _texte: Array[Label3D] = []
var _zeit := 0.0


func _ready() -> void:
	position = Vector3(-327.0, 0.0, TerrainForm.PASS_Z)
	_koerper = StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.5, hoehe, breite)
	cs.shape = box
	cs.position = Vector3(0, hoehe * 0.5, 0)
	_koerper.add_child(cs)
	add_child(_koerper)
	_material = StandardMaterial3D.new()
	_material.albedo_color = Color(1.0, 0.1, 0.2, 0.28)
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.emission_enabled = true
	_material.emission = Color(1.0, 0.1, 0.25)
	_material.emission_energy_multiplier = 1.6
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var q := BoxMesh.new()
	q.size = Vector3(0.3, hoehe, breite)
	_flaeche = MeshInstance3D.new()
	_flaeche.mesh = q
	_flaeche.material_override = _material
	_flaeche.position = Vector3(0, hoehe * 0.5, 0)
	_flaeche.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_flaeche)
	for r in [90.0, -90.0]:
		var l := Label3D.new()
		l.text = "TOR GESPERRT\nGRIMOIRE-SEITE %d FEHLT" % seite
		l.font_size = 48
		l.pixel_size = 0.02
		l.shaded = false
		l.modulate = Color(1.6, 0.4, 0.5)
		l.outline_modulate = Color(0.2, 0, 0.05)
		l.outline_size = 12
		l.position = Vector3(1.0 if r > 0 else -1.0, 8.0, 0)
		l.rotation_degrees.y = r
		add_child(l)
		_texte.append(l)
	EventBus.seite_gesammelt.connect(_seite_da)
	if GameState.hat_seite(seite):
		_oeffnen(false)


func _process(delta: float) -> void:
	_zeit += delta
	if _material != null and _flaeche.visible:
		_material.emission_energy_multiplier = 1.4 + sin(_zeit * 3.0) * 0.5


func _seite_da(nr: int) -> void:
	if nr == seite:
		_oeffnen(true)


func _oeffnen(animiert: bool) -> void:
	_koerper.queue_free()
	for l in _texte:
		l.queue_free()
	if animiert:
		var tw := create_tween()
		tw.tween_property(_material, "albedo_color:a", 0.0, 1.2)
		tw.parallel().tween_property(_material, "emission_energy_multiplier", 0.0, 1.2)
		tw.tween_callback(_flaeche.hide)
	else:
		_flaeche.hide()
