extends Node3D
## 6twelve: kleine Tankstellen-Filiale am Stadtrand (Modell imported_models/6twelve/Models/6twelve.fbx, Lizenz
## unbekannt, vom Nutzer geliefert). Das Modell ist eine ganze Szene mit Rasen, Baeumen und Strasse; hier bleibt nur
## der Laden mit Parkplatz. Eingang und Parkplatz liegen im Modell bei +z, der Knoten wird von stadt.gd gedreht.
## Geheimer Abgang: Unter dem Teppich im Lagerraum (hinten links) liegt eine Luke zum Untergrund-Komplex
## (levels/untergrund.gd). Taste "interagieren" nahe der Luke hebt den Teppich ab und klappt die Luke auf.
## Die Luke gehoert zu einem Loch in der Stadtplatte, das stadt.gd an derselben Stelle ausspart.
## Signale: abgang_geoeffnet. Keine exportierten Variablen; Gruppe "spieler" wird abgefragt, kein harter Pfad.

signal abgang_geoeffnet

const MODELL := "res://imported_models/6twelve/Models/6twelve.fbx"
## Modellteile, die nicht gebraucht werden (Praefix-Vergleich)
const ENTFERNEN: Array[String] = ["Grass", "Tree", "Dry_leaves", "Post_light_03"]
## Meshes mit Trimesh-Kollision (Praefix-Vergleich)
const KOLLISION: Array[String] = ["6twelve", "Mostrator", "Shelf", "Boxs", "Food_shelf", "IceCream_Refrigerator", "Cabinet", "Fuse_Boxes", "Air_conditioners"]
## Kollisionsflaechen unterhalb dieser Hoehe (Modellraum) werden abgeschnitten: Fundament und Bodenplatte des Modells
## wuerden sonst im Treppenschacht unter dem Laden die Koepfe treffen
const KOLLISION_Y_MIN := -0.1
const HOEHE_OFFSET := -0.08          ## Boden des Ladens (Modell y 0,1) knapp ueber die Stadtplatte
const PARKPLATZ_HEBEN := 0.22        ## Parkplatz-Mesh liegt im Modell unter der Platte und wird angehoben
## Glasfront (Modell z -8,3) bekommt Kollision links und rechts der Tuer
const GLAS_Z := -8.25
const GLAS_BOXEN: Array[Vector2] = [Vector2(-12.3, -6.9), Vector2(-4.7, 0.8)]
const GLAS_HOEHE := 3.2
## Luke im Lagerraum (Modellkoordinaten): Westseite, Treppe laeuft nach -z (zur Rueckwand)
const LUKE_X := Vector2(-15.6, -13.45)
const LUKE_Z := Vector2(-25.4, -21.2)
const LUKE_DICKE := 0.1
const LUKE_ZEIT := 1.2
const LUKE_WINKEL := -95.0
const TEPPICH_ZEIT := 0.8
const TEPPICH_VERSATZ := Vector3(1.8, 0.0, 1.6)
const REICHWEITE := 3.2              ## Meter (waagerecht) zur Luke
const REICHWEITE_Y := 2.0
const HINWEIS_HOEHE := 1.5
const HINWEIS_PIXEL := 0.0075
const FLAG_ENTDECKT := "abgang_entdeckt"

var _luke_dreh: Node3D
var _luke_kol: CollisionShape3D
var _teppich: Node3D
var _hinweis: Label3D
var _offen := false
var _spieler: Node3D
var _modell: Node3D


func _ready() -> void:
	name = "SechsZwoelf"
	if not ResourceLoader.exists(MODELL):
		return
	_modell = (load(MODELL) as PackedScene).instantiate() as Node3D
	_modell.position.y = HOEHE_OFFSET
	add_child(_modell)
	for mi: MeshInstance3D in _modell.find_children("*", "MeshInstance3D", true, false):
		if _beginnt(mi.name, ENTFERNEN):
			mi.queue_free()
			continue
		if mi.name == "Parking_lot":
			mi.position.y += PARKPLATZ_HEBEN
		elif mi.name == "Rug_004":
			_teppich = mi
		if _beginnt(mi.name, KOLLISION) and mi.mesh != null:
			_kollision_ueber_grund(mi)
	_glasfront_kollision()
	_licht_bauen()
	_luke_bauen()
	_hinweis_bauen()


## Trimesh-Kollision eines Meshes (im Raum des Modells), unten bei KOLLISION_Y_MIN abgeschnitten.
func _kollision_ueber_grund(mi: MeshInstance3D) -> void:
	var t := Transform3D()
	var c: Node3D = mi
	while c != _modell:
		t = c.transform * t
		c = c.get_parent() as Node3D
	var faces := mi.mesh.get_faces()
	var aus := PackedVector3Array()
	for i in range(0, faces.size(), 3):
		var tri: Array[Vector3] = [t * faces[i], t * faces[i + 1], t * faces[i + 2]]
		var poly := _clip_oben(tri)
		for k in range(1, poly.size() - 1):
			aus.append_array([poly[0], poly[k], poly[k + 1]])
	if aus.is_empty():
		return
	var form := ConcavePolygonShape3D.new()
	form.set_faces(aus)
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = form
	sb.add_child(cs)
	_modell.add_child(sb)


## Schneidet ein Polygon an der Ebene y = KOLLISION_Y_MIN und behaelt den oberen Teil (Sutherland-Hodgman).
func _clip_oben(poly: Array[Vector3]) -> Array[Vector3]:
	var aus: Array[Vector3] = []
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var a_ok := a.y >= KOLLISION_Y_MIN
		var b_ok := b.y >= KOLLISION_Y_MIN
		if a_ok:
			aus.append(a)
		if a_ok != b_ok:
			var u := (KOLLISION_Y_MIN - a.y) / (b.y - a.y)
			aus.append(a.lerp(b, u))
	return aus


func _beginnt(n: String, liste: Array[String]) -> bool:
	for p in liste:
		if n.begins_with(p):
			return true
	return false


func _kol_box(pos: Vector3, groesse: Vector3, eltern: Node3D = null) -> CollisionShape3D:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = groesse
	cs.shape = sh
	sb.add_child(cs)
	sb.position = pos
	(eltern if eltern != null else self).add_child(sb)
	return cs


func _glasfront_kollision() -> void:
	for x in GLAS_BOXEN:
		_kol_box(Vector3((x.x + x.y) * 0.5, GLAS_HOEHE * 0.5, GLAS_Z), Vector3(x.y - x.x, GLAS_HOEHE, 0.2))


func _licht_bauen() -> void:
	# Kaltes Ladenlicht innen, warmes Licht ueber dem Parkplatz (Laterneneffekt)
	for p: Vector3 in [Vector3(-7.5, 3.3, -13.0), Vector3(-2.0, 3.3, -15.0), Vector3(-6.0, 3.3, -22.0)]:
		var l := OmniLight3D.new()
		l.position = p
		l.light_color = Color(0.9, 0.97, 1.0)
		l.light_energy = 1.4
		l.omni_range = 11.0
		l.shadow_enabled = false
		add_child(l)
	var aussen := OmniLight3D.new()
	aussen.position = Vector3(-5.0, 4.2, -2.0)
	aussen.light_color = Color(1.0, 0.8, 0.5)
	aussen.light_energy = 2.0
	aussen.omni_range = 18.0
	aussen.shadow_enabled = false
	add_child(aussen)


## Luke: Deckel im Look des Bodens (gleiche Fliese), mit Scharnier an der Rueckseite (z-Mindestkante).
func _luke_bauen() -> void:
	var breite := LUKE_X.y - LUKE_X.x
	var tiefe := LUKE_Z.y - LUKE_Z.x
	_luke_dreh = Node3D.new()
	_luke_dreh.position = Vector3((LUKE_X.x + LUKE_X.y) * 0.5, HOEHE_OFFSET + 0.1, LUKE_Z.x)
	add_child(_luke_dreh)
	var deckel := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(breite, LUKE_DICKE, tiefe)
	deckel.mesh = bm
	deckel.position = Vector3(0, LUKE_DICKE * 0.5 - 0.005, tiefe * 0.5)
	deckel.material_override = _bodenmaterial()
	_luke_dreh.add_child(deckel)
	_luke_kol = _kol_box(deckel.position, bm.size, _luke_dreh)


## Material der Bodenfliesen des Modells (Mesh "Tiles"); Ersatz: graue Fliese.
func _bodenmaterial() -> Material:
	for mi: MeshInstance3D in _modell.find_children("Tiles", "MeshInstance3D", true, false):
		var m := mi.get_active_material(0)
		if m != null:
			return m
	var s := StandardMaterial3D.new()
	s.albedo_color = Color(0.55, 0.55, 0.58)
	return s


func _hinweis_bauen() -> void:
	_hinweis = Label3D.new()
	_hinweis.text = "E: TEPPICH ANHEBEN"
	_hinweis.font_size = 48
	_hinweis.pixel_size = HINWEIS_PIXEL
	_hinweis.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hinweis.shaded = false
	_hinweis.no_depth_test = true
	_hinweis.modulate = Color(1.0, 0.85, 0.3)
	_hinweis.outline_modulate = Color(0.0, 0.02, 0.06)
	_hinweis.outline_size = 10
	_hinweis.visible = false
	_hinweis.position = Vector3((LUKE_X.x + LUKE_X.y) * 0.5, HINWEIS_HOEHE, (LUKE_Z.x + LUKE_Z.y) * 0.5)
	add_child(_hinweis)


func _luke_mitte_lokal() -> Vector3:
	return Vector3((LUKE_X.x + LUKE_X.y) * 0.5, HOEHE_OFFSET, (LUKE_Z.x + LUKE_Z.y) * 0.5)


func _spieler_nah() -> bool:
	if _spieler == null or not is_instance_valid(_spieler):
		_spieler = get_tree().get_first_node_in_group("spieler") as Node3D
	if _spieler == null:
		return false
	var d := to_local(_spieler.global_position) - _luke_mitte_lokal()
	return Vector2(d.x, d.z).length() < REICHWEITE and absf(d.y) < REICHWEITE_Y


func _process(_delta: float) -> void:
	if _hinweis == null:
		return
	_hinweis.visible = not _offen and _spieler_nah()


func _unhandled_input(event: InputEvent) -> void:
	if _offen or not event.is_action_pressed("interagieren") or event.is_echo():
		return
	if Dialog.aktiv or not _spieler_nah():
		return
	_luke_oeffnen()
	get_viewport().set_input_as_handled()


func _luke_oeffnen() -> void:
	_offen = true
	GameState.flag_setzen(FLAG_ENTDECKT)
	if _teppich != null:
		var tw := create_tween()
		tw.tween_property(_teppich, "position", _teppich.position + TEPPICH_VERSATZ, TEPPICH_ZEIT)
		tw.parallel().tween_property(_teppich, "rotation_degrees:y", 35.0, TEPPICH_ZEIT)
	var tw2 := create_tween()
	tw2.tween_interval(TEPPICH_ZEIT * 0.5)
	tw2.tween_property(_luke_dreh, "rotation_degrees:x", LUKE_WINKEL, LUKE_ZEIT)
	_luke_kol.set_deferred("disabled", true)
	abgang_geoeffnet.emit()
