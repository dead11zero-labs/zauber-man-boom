extends Node3D
## RollenNpc: stehender NPC mit fester Rolle (Haendler, Informant, Mechanikerin). Minifigur aus Primitives mit Neon,
## Namensschild (Label3D) und Hinweis "E: SPRECHEN", sobald der Spieler in Reichweite ist.
## Interaktion: Aktion "interagieren" startet den Dialog (Autoload Dialog). Beim ersten Gespraech `dialog_erst`,
## danach `dialog_spaeter` (falls gesetzt). Nach dem Gespraech meldet der NPC das Story-Ereignis "gespraech:<rolle>".
## Haendler: Antwort 0 im Dialog oeffnet den Upgrade-Shop (ui/shop_menue.gd).
## Exportiert: rolle, anzeige_name, farbe, dialog_erst, dialog_spaeter, reichweite, modell (optional: Pfad zu glb/fbx,
## ersetzt die Primitive-Figur), modell_hoehe (Meter).
## Signale: angesprochen(rolle) wenn der Dialog startet. Getrennt von npc.gd/npcs.gd (laufende Synth-Bots).

signal angesprochen(rolle: String)

const SHOP := preload("res://ui/shop_menue.gd")
const KOERPER_HOEHE := 1.9
const BODEN_STRAHL_HOEHE := 30.0
const BODEN_STRAHL_TIEFE := 60.0
const NAME_HOEHE := 2.35
const HINWEIS_HOEHE := 2.85
const BESCHRIFTUNG_PIXEL := 0.008
const DREH_TEMPO := 4.0
const MODELL_FUSS_ANHEBUNG := 0.06  ## Modell leicht anheben, damit die Schuhsohlen nicht im Boden stecken
const SCHRITT_WARTEN := 2  ## Physik-Frames, bis der Boden steht
## Leichtes Standbild-Leben fuer Modelle ohne Idle-Animation (Mixamo-Skelett): Atmen, Kopfwiegen, Unterarme leicht angewinkelt
const IDLE_ATEM_TEMPO := 1.5
const IDLE_ATEM_WINKEL := 0.02
const IDLE_KOPF_TEMPO := 0.6
const IDLE_KOPF_WINKEL := 0.12
const IDLE_UNTERARM_WINKEL := 0.35

@export var rolle := "haendler"
@export var anzeige_name := "Händler"
@export var farbe := Color(1.0, 0.85, 0.2)
@export var dialog_erst := ""
@export var dialog_spaeter := ""
@export var reichweite := 4.5
@export var modell := ""
@export var modell_hoehe := 1.8

var _hinweis: Label3D
var _laufend := ""
var _spieler: Node3D
var _nah := false
var _mat: StandardMaterial3D
var _koerper: StaticBody3D
var _skelett: Skeleton3D
var _idle_knochen: Dictionary = {}  ## name -> [index, Ruhe-Rotation]
var _idle_zeit := 0.0


func _ready() -> void:
	add_to_group("rollen_npc")
	_figur_bauen()
	EventBus.dialog_beendet.connect(_dialog_ende)
	for i in SCHRITT_WARTEN:
		await get_tree().physics_frame
	_auf_boden()


func _figur_bauen() -> void:
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = farbe.darkened(0.7)
	_mat.emission_enabled = true
	_mat.emission = farbe
	_mat.emission_energy_multiplier = 1.6
	var dunkel := StandardMaterial3D.new()
	dunkel.albedo_color = Color(0.1, 0.11, 0.15)
	dunkel.metallic = 0.6
	dunkel.roughness = 0.4
	if modell != "" and _modell_laden():
		pass
	else:
		_teil(CylinderMesh.new(), Vector3(0.0, 0.45, 0.0), dunkel, {"top_radius": 0.28, "bottom_radius": 0.3, "height": 0.9})
		_teil(CapsuleMesh.new(), Vector3(0.0, 1.2, 0.0), dunkel, {"radius": 0.34, "height": 0.9})
		_teil(SphereMesh.new(), Vector3(0.0, 1.72, 0.0), dunkel, {"radius": 0.22, "height": 0.44})
		# Neon: Visier, Guertel, Armstreifen
		_teil(BoxMesh.new(), Vector3(0.0, 1.74, -0.16), _mat, {"size": Vector3(0.36, 0.08, 0.1)})
		_teil(BoxMesh.new(), Vector3(0.0, 0.95, 0.0), _mat, {"size": Vector3(0.74, 0.07, 0.5)})
		_teil(BoxMesh.new(), Vector3(-0.42, 1.25, 0.0), _mat, {"size": Vector3(0.06, 0.5, 0.14)})
		_teil(BoxMesh.new(), Vector3(0.42, 1.25, 0.0), _mat, {"size": Vector3(0.06, 0.5, 0.14)})
	var licht := OmniLight3D.new()
	licht.light_color = farbe
	licht.light_energy = 1.2
	licht.omni_range = 5.0
	licht.position.y = 1.4
	add_child(licht)
	var koerper := StaticBody3D.new()
	_koerper = koerper
	var cs := CollisionShape3D.new()
	var kap := CapsuleShape3D.new()
	kap.radius = 0.45
	kap.height = KOERPER_HOEHE
	cs.shape = kap
	cs.position.y = KOERPER_HOEHE * 0.5
	koerper.add_child(cs)
	add_child(koerper)
	_beschriftung(anzeige_name.to_upper(), NAME_HOEHE, farbe, 44)
	_hinweis = _beschriftung("E: SPRECHEN", HINWEIS_HOEHE, Color(0.1, 0.95, 1.0), 40)
	Eingabe.hinweis_binden(_hinweis, "interagieren", "%s: SPRECHEN")
	_hinweis.visible = false


## Lädt das importierte 3D-Modell, skaliert es auf modell_hoehe und stellt die Füße auf y = 0. Liefert false bei Fehler.
func _modell_laden() -> bool:
	var res: Resource = load(modell)
	if not (res is PackedScene):
		return false
	var figur: Node3D = (res as PackedScene).instantiate()
	add_child(figur)
	var box := AABB()
	var erstes := true
	for mi in figur.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var t := Transform3D.IDENTITY
		var k: Node = m
		while k != null and k != figur.get_parent():
			if k is Node3D:
				t = (k as Node3D).transform * t
			k = k.get_parent()
		var a := t * m.get_aabb()
		box = a if erstes else box.merge(a)
		erstes = false
	if erstes:
		return true
	var sk := modell_hoehe / maxf(box.size.y, 0.01)
	figur.scale = Vector3.ONE * sk
	figur.position.y = -box.position.y * sk + MODELL_FUSS_ANHEBUNG
	figur.rotate_y(PI)  # Modelle schauen nach +z, der NPC dreht seine -z-Achse zum Spieler
	_idle_vorbereiten(figur)
	return true


func _idle_vorbereiten(figur: Node) -> void:
	_skelett = figur.find_child("Skeleton3D", true, false) as Skeleton3D
	if _skelett == null:
		return
	for n in ["mixamorig_Spine1", "mixamorig_Head", "mixamorig_LeftForeArm", "mixamorig_RightForeArm"]:
		var i := _skelett.find_bone(n)
		if i >= 0:
			_idle_knochen[n] = [i, _skelett.get_bone_rest(i).basis.get_rotation_quaternion()]


func _idle_animieren(delta: float) -> void:
	_idle_zeit += delta
	for n in _idle_knochen:
		var i: int = _idle_knochen[n][0]
		var ruhe: Quaternion = _idle_knochen[n][1]
		var q := Quaternion.IDENTITY
		match n:
			"mixamorig_Spine1":
				q = Quaternion(Vector3.RIGHT, sin(_idle_zeit * IDLE_ATEM_TEMPO) * IDLE_ATEM_WINKEL)
			"mixamorig_Head":
				q = Quaternion(Vector3.UP, sin(_idle_zeit * IDLE_KOPF_TEMPO) * IDLE_KOPF_WINKEL)
			"mixamorig_LeftForeArm", "mixamorig_RightForeArm":
				q = Quaternion(Vector3.RIGHT, -IDLE_UNTERARM_WINKEL)
		_skelett.set_bone_pose_rotation(i, ruhe * q)


func _teil(mesh: Mesh, pos: Vector3, mat: Material, eig: Dictionary) -> void:
	for k in eig:
		mesh.set(k, eig[k])
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	add_child(m)


func _beschriftung(text: String, hoehe: float, f: Color, groesse: int) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = groesse
	l.pixel_size = BESCHRIFTUNG_PIXEL
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.shaded = false
	l.no_depth_test = true
	l.modulate = f
	l.outline_modulate = Color(0.0, 0.02, 0.06)
	l.outline_size = 10
	l.position.y = hoehe
	add_child(l)
	return l


func _auf_boden() -> void:
	var von := global_position + Vector3.UP * BODEN_STRAHL_HOEHE
	var q := PhysicsRayQueryParameters3D.create(von, von + Vector3.DOWN * BODEN_STRAHL_TIEFE)
	q.exclude = [_koerper.get_rid()]
	for sp in get_tree().get_nodes_in_group("spieler"):
		if sp is CollisionObject3D:
			q.exclude.append((sp as CollisionObject3D).get_rid())
	var t := get_world_3d().direct_space_state.intersect_ray(q)
	if not t.is_empty():
		global_position.y = (t["position"] as Vector3).y


func _process(delta: float) -> void:
	if _skelett != null:
		_idle_animieren(delta)
	if _spieler == null or not is_instance_valid(_spieler):
		_spieler = get_tree().get_first_node_in_group("spieler") as Node3D
		return
	var d := _spieler.global_position - global_position
	d.y = 0.0
	var nah := d.length() <= reichweite
	_nah = nah
	_hinweis.visible = nah and not Dialog.aktiv
	if nah:
		# Der NPC dreht sich zum Spieler
		var ziel := atan2(-d.x, -d.z)
		rotation.y = lerp_angle(rotation.y, ziel, clampf(DREH_TEMPO * delta, 0.0, 1.0))


## Ereignisbasiert statt Polling: ein vom Dialog/Shop verbrauchter E-Druck erreicht den NPC nicht mehr
## (sonst startet das Ende eines Dialogs sofort den naechsten).
func _unhandled_input(event: InputEvent) -> void:
	if _nah and not Dialog.aktiv and _laufend == "" and event.is_action_pressed("interagieren") and not event.is_echo():
		get_viewport().set_input_as_handled()
		sprechen()


## Startet den passenden Dialog (auch von aussen aufrufbar, z. B. fuer Tests).
func sprechen() -> void:
	if Dialog.aktiv:
		return
	var id := dialog_erst
	if GameState.flag("gesprochen_" + rolle) and dialog_spaeter != "":
		id = dialog_spaeter
	var daten := Dialog.laden(id)
	if daten == null:
		return
	_laufend = String(daten.id)
	angesprochen.emit(rolle)
	Dialog.starten(daten)


func _dialog_ende(id: String, antwort: int) -> void:
	if _laufend == "" or id != _laufend:
		return
	_laufend = ""
	GameState.flag_setzen("gesprochen_" + rolle)
	EventBus.story_ereignis.emit("gespraech:" + rolle)
	if rolle == "haendler" and antwort == 0:
		var shop := CanvasLayer.new()
		shop.set_script(SHOP)
		get_tree().current_scene.add_child(shop)
