extends CharacterBody3D
## Mechy McBoom: Wachmech am Empfang im Foyer des Zauber-Towers. Patrouilliert zwischen Wegpunkten, bleibt stehen
## und dreht sich zum Spieler, wenn der ihn mit "interagieren" (E) anspricht (Dialog data/dialoge/mechy.tres).
## Das Modell (imported_models/meshy_model_1) ist ein statisches Mesh ohne Skelett: das Gehen entsteht per Code
## (Wippen, Schaukeln, Neigen), die Fuesse kleben nicht am Boden. Blick des Modells = +z.
## Exportiert: modell, modell_hoehe, wegpunkte (Positionen im Koordinatensystem des Elternknotens), tempo,
## pause_am_punkt, ansprech_abstand, dialog_id, anzeige_name.
## Keine Signale. Gruppe "spieler" fuer den Spieler wird gesucht. Wird von stadt.gd (_foyer) erzeugt.

@export var modell := "res://imported_models/meshy_model_1/meshy_model_1.glb"
@export var modell_hoehe := 2.6
@export var wegpunkte := PackedVector3Array()
@export var tempo := 1.2
@export var pause_am_punkt := 2.5
@export var ansprech_abstand := 4.0
@export var dialog_id := "mechy"
@export var anzeige_name := "MECHY McBOOM"

const DREHTEMPO := 3.0
const WIPP_HOEHE := 0.05
const WIPP_TAKT := 5.2          ## Schrittfrequenz (rad/s) bei Vollgang
const SCHAUKEL_WINKEL := 0.05
const NEIGE_WINKEL := 0.06
const ANKOMMEN_ABSTAND := 0.3
const KAPSEL_RADIUS := 0.55
const NAME_HOEHE_EXTRA := 0.5
const HINWEIS_PIXEL := 0.006

var _figur: Node3D
var _huelle_basis_y := 0.0
var _ziel := 0
var _pause := 0.0
var _phase := 0.0
var _spieler: Node3D
var _hinweis: Label3D
var _im_dialog := false


func _ready() -> void:
	var res: Resource = load(modell)
	if not (res is PackedScene):
		push_warning("Mechy: Modell nicht gefunden: " + modell)
		return
	_figur = (res as PackedScene).instantiate()
	add_child(_figur)
	var box := _huelle(_figur)
	var sk := modell_hoehe / maxf(box.size.y, 0.01)
	_figur.scale = Vector3.ONE * sk
	_huelle_basis_y = -box.position.y * sk
	_figur.position = Vector3(0.0, _huelle_basis_y, 0.0)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = KAPSEL_RADIUS
	cap.height = modell_hoehe
	cs.shape = cap
	cs.position.y = modell_hoehe * 0.5
	add_child(cs)
	_hinweis = Label3D.new()
	Eingabe.hinweis_binden(_hinweis, "interagieren", anzeige_name.replace("%", "%%") + "\n%s: ANSPRECHEN")
	_hinweis.pixel_size = HINWEIS_PIXEL
	_hinweis.font_size = 64
	_hinweis.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hinweis.shaded = false
	_hinweis.no_depth_test = true
	_hinweis.modulate = Color(1.0, 0.85, 0.3)
	_hinweis.outline_modulate = Color(0.0, 0.02, 0.06)
	_hinweis.outline_size = 10
	_hinweis.position.y = modell_hoehe + NAME_HOEHE_EXTRA
	_hinweis.visible = false
	add_child(_hinweis)
	EventBus.dialog_beendet.connect(_dialog_beendet)


func _physics_process(delta: float) -> void:
	if _figur == null:
		return
	if _spieler == null or not is_instance_valid(_spieler):
		_spieler = get_tree().get_first_node_in_group("spieler") as Node3D
	var nah := _spieler != null and global_position.distance_to(_spieler.global_position) < ansprech_abstand
	_hinweis.visible = nah and not Dialog.aktiv
	var geht := false
	if _im_dialog or (nah and Dialog.aktiv):
		velocity = Vector3.ZERO
		_zum_spieler_drehen(delta)
	elif wegpunkte.size() > 0:
		geht = _patrouillieren(delta)
	_animieren(delta, geht)
	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if _figur == null or Dialog.aktiv or not event.is_action_pressed("interagieren") or event.is_echo():
		return
	if _spieler == null or global_position.distance_to(_spieler.global_position) >= ansprech_abstand:
		return
	var daten := Dialog.laden(dialog_id)
	if daten == null:
		return
	get_viewport().set_input_as_handled()
	_im_dialog = true
	Dialog.starten(daten)


func _dialog_beendet(id: String, _antwort: int) -> void:
	if id == dialog_id:
		_im_dialog = false
		_pause = pause_am_punkt * 0.5


## Laeuft zum aktuellen Wegpunkt, wartet dort kurz und nimmt dann den naechsten (Rundkurs). Gibt zurueck, ob er geht.
func _patrouillieren(delta: float) -> bool:
	if _pause > 0.0:
		_pause -= delta
		velocity = Vector3.ZERO
		return false
	var z: Vector3 = wegpunkte[_ziel]
	var d := Vector3(z.x - position.x, 0.0, z.z - position.z)
	if d.length() < ANKOMMEN_ABSTAND:
		_ziel = (_ziel + 1) % wegpunkte.size()
		_pause = pause_am_punkt
		velocity = Vector3.ZERO
		return false
	var r := d.normalized()
	_drehen(r, delta)
	velocity = r * tempo
	return true


func _zum_spieler_drehen(delta: float) -> void:
	if _spieler == null:
		return
	var d := _spieler.global_position - global_position
	d.y = 0.0
	if d.length() > 0.1:
		_drehen(d.normalized(), delta)


## Dreht das Modell weich in Richtung r (Modellblick +z).
func _drehen(r: Vector3, delta: float) -> void:
	var ziel := atan2(r.x, r.z)
	_figur.rotation.y = lerp_angle(_figur.rotation.y, ziel, clampf(delta * DREHTEMPO, 0.0, 1.0))


func _animieren(delta: float, geht: bool) -> void:
	var s := 1.0 if geht else 0.0
	if geht:
		_phase += delta * WIPP_TAKT
	var wipp := absf(sin(_phase)) * WIPP_HOEHE * s
	_figur.position.y = lerpf(_figur.position.y, _huelle_basis_y + wipp, clampf(delta * 12.0, 0.0, 1.0))
	_figur.rotation.z = lerpf(_figur.rotation.z, sin(_phase) * SCHAUKEL_WINKEL * s, clampf(delta * 8.0, 0.0, 1.0))
	_figur.rotation.x = lerpf(_figur.rotation.x, NEIGE_WINKEL * s, clampf(delta * 4.0, 0.0, 1.0))


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
