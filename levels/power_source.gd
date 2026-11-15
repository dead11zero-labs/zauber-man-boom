class_name PowerSource
extends StaticBody3D
## Stromquelle: wird von einem Zauberblitz getroffen und gibt dann Strom ab (Gruppe "blitz_ziel" fuer die Zielhilfe).
## Exportiert: braucht_ladung (nur Ladeschuss schaltet, Fernschalter), dauer (0 = bleibt an, sonst Sekunden bis aus),
##   farbe (Leuchtfarbe).
## Signal: power_changed(active) wird bei jedem Wechsel gesendet.

signal power_changed(active: bool)

@export var braucht_ladung := false
@export var dauer := 0.0
@export var farbe := Color(0.2, 0.9, 1.0)

const HOEHE_SOCKEL := 1.1
const RADIUS_SOCKEL := 0.55
const RADIUS_KUGEL := 0.45
const ENERGIE_AUS := 0.25
const ENERGIE_AN := 3.0
const PUMPEN_TEMPO := 4.0
const HINWEIS_DAUER := 0.8

var aktiv := false
var _kugel_mat: StandardMaterial3D
var _licht: OmniLight3D
var _timer := 0.0
var _zeit := 0.0


func _ready() -> void:
	add_to_group("blitz_ziel")
	var cs := CollisionShape3D.new()
	var zyl := CylinderShape3D.new()
	zyl.radius = RADIUS_SOCKEL
	zyl.height = HOEHE_SOCKEL + RADIUS_KUGEL * 2.0
	cs.shape = zyl
	cs.position.y = zyl.height * 0.5
	add_child(cs)
	var sockel := MeshInstance3D.new()
	var zm := CylinderMesh.new()
	zm.top_radius = RADIUS_SOCKEL * 0.8
	zm.bottom_radius = RADIUS_SOCKEL
	zm.height = HOEHE_SOCKEL
	sockel.mesh = zm
	sockel.position.y = HOEHE_SOCKEL * 0.5
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.08, 0.09, 0.12)
	sm.metallic = 0.8
	sm.roughness = 0.35
	sockel.material_override = sm
	add_child(sockel)
	var kugel := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = RADIUS_KUGEL
	sph.height = RADIUS_KUGEL * 2.0
	kugel.mesh = sph
	kugel.position.y = HOEHE_SOCKEL + RADIUS_KUGEL
	_kugel_mat = StandardMaterial3D.new()
	_kugel_mat.emission_enabled = true
	_kugel_mat.albedo_color = farbe.darkened(0.6)
	_kugel_mat.emission = farbe
	kugel.material_override = _kugel_mat
	add_child(kugel)
	_licht = OmniLight3D.new()
	_licht.light_color = farbe
	_licht.omni_range = 7.0
	_licht.position.y = HOEHE_SOCKEL + RADIUS_KUGEL
	add_child(_licht)
	_darstellen()


func _process(delta: float) -> void:
	_zeit += delta
	if aktiv and dauer > 0.0:
		_timer -= delta
		if _timer <= 0.0:
			_setzen(false)
	var puls := 0.5 + 0.5 * sin(_zeit * PUMPEN_TEMPO)
	_kugel_mat.emission_energy_multiplier = (ENERGIE_AN * (0.8 + 0.2 * puls)) if aktiv else (ENERGIE_AUS * (0.5 + puls))
	_licht.light_energy = (2.5 + puls) if aktiv else 0.2


## Wird vom Blitz aufgerufen. Ohne genug Ladung gibt es nur Funken.
func blitz_treffer(ladung: float, _blitz: Node) -> void:
	if braucht_ladung and ladung < 1.0:
		_kugel_mat.emission_energy_multiplier = ENERGIE_AN
		return
	if aktiv and dauer <= 0.0:
		return
	_timer = dauer
	_setzen(true)


## Von einer Drohnen-Funkenkugel getroffen: Quelle geht aus. Nie dauerhaft, ein Blitz schaltet sie wieder an;
## bereits geloeste Tore (Barrier.geloest) bleiben offen.
func stoeren() -> void:
	_setzen(false)


func _setzen(an: bool) -> void:
	if an == aktiv:
		return
	aktiv = an
	_darstellen()
	power_changed.emit(aktiv)


func _darstellen() -> void:
	_kugel_mat.albedo_color = farbe if aktiv else farbe.darkened(0.6)


## Zielpunkt fuer die Zielhilfe (Mitte der Kugel).
func ziel_punkt() -> Vector3:
	return global_position + Vector3.UP * (HOEHE_SOCKEL + RADIUS_KUGEL)
