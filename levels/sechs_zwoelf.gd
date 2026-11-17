extends Node3D
## 6twelve: kleine Filiale am Stadtrand (Modell imported_models/6twelve/Models/6twelve.fbx, vom Nutzer als frei
## bestaetigt). Das Modell ist eine ganze Szene mit Wald-Kulisse, Rasen, Baeumen und Strassen; hier bleiben nur
## Laden, Parkplatz und Hofmauer. Eingang und Parkplatz liegen im Modell bei +z, der Knoten wird von stadt.gd gedreht.
## Grundriss (Modellraum): Verkaufsraum z -19,7..-8,2; Lager dahinter (z -26..-20,7, im Westen bis z -17,7);
## WC vorne rechts. Tueren: Eingang (Doppeltuer), Lagertuer und Hintertuer schieben automatisch auf, das WC bleibt zu.
## Kollision: alle festen Teile des Modells (Trimesh, beidseitig, unter y 0,12 abgeschnitten).
## Geheimer Abgang: Unter dem Teppich in der Westecke des Lagers liegt eine Luke zum Untergrund-Komplex
## (levels/untergrund.gd). Taste "interagieren" nahe der Luke zieht den Teppich weg und klappt die Luke auf.
## Die Bodenfliesen des Modells bekommen dafuer ein Loch; das Loch in der Stadtplatte spart stadt.gd aus.
## Signale: abgang_geoeffnet. Keine exportierten Variablen; Gruppe "spieler" wird abgefragt, kein harter Pfad.

signal abgang_geoeffnet

const MODELL := "res://imported_models/6twelve/Models/6twelve.fbx"
## Modellteile, die entfallen (Praefix-Vergleich): Umgebung der Originalszene
const ENTFERNEN: Array[String] = ["Grass", "Tree", "Dry_leaves", "Background", "Asphalt", "Crosswalk", "Plants", "Post_light_02", "Post_light_03"]
## Teile ohne Trimesh-Kollision (Praefix-Vergleich): Flaches, Tueren (eigene Boxen), Glas (eigene Boxen), Boden
const OHNE_KOLLISION: Array[String] = ["Rug", "Lights", "Glasses", "Door", "Tiles", "Parking_lot", "Sign", "Mirror", "Carrier", "Keyboard", "Payment_Terminal"]
## Kollisionsflaechen unterhalb dieser Hoehe (Modellraum) werden abgeschnitten: Fundament und Bodenplatte des Modells
## wuerden sonst im Treppenschacht unter dem Laden die Koepfe treffen
const KOLLISION_Y_MIN := 0.12
const HOEHE_OFFSET := -0.08          ## Boden des Ladens (Modell y 0,1) knapp ueber die Stadtplatte
const PARKPLATZ_HEBEN := 0.22        ## Parkplatz-Mesh liegt im Modell unter dem Fliesenniveau und wird angehoben
## Glasfront (Modell z -8,25): Kollision links und rechts der Doppeltuer
const GLAS_Z := -8.25
const GLAS_BOXEN: Array[Vector2] = [Vector2(-12.3, -6.9), Vector2(-4.7, 0.8)]
const GLAS_HOEHE := 3.2
## Schiebetueren: Knotenname -> Schieberichtung und -weg im Modellraum (in die Wand hinein)
const TUEREN := {
	"Door": Vector3(1.05, 0, 0),
	"Door_01": Vector3(-1.05, 0, 0),
	"Door_02": Vector3(1.15, 0, 0),
	"Door_03": Vector3(1.15, 0, 0),
}
const TUER_VERSCHLOSSEN: Array[String] = ["Door_04"]   ## WC
const TUER_REICHWEITE := 2.6
const TUER_ZEIT := 0.35
const TUER_DICKE := 0.25
## Luke im Lager (Modellkoordinaten): Westecke, Treppe laeuft nach -z (zur Rueckwand)
const LUKE_X := Vector2(-15.6, -13.45)
const LUKE_Z := Vector2(-25.4, -21.2)
const LUKE_DICKE := 0.08
const LUKE_ZEIT := 1.2
const LUKE_WINKEL := -100.0
const TEPPICH_ZEIT := 0.8
const TEPPICH_VERSATZ := Vector3(2.6, 0.0, 0.3)
const REICHWEITE := 3.5              ## Meter (waagerecht) zur Luke
const REICHWEITE_Y := 2.0
const HINWEIS_HOEHE := 1.5
const HINWEIS_PIXEL := 0.0075
const FLAG_ENTDECKT := "abgang_entdeckt"
## Leuchtpylon an der Strasse (Modellraum, vor dem Parkplatz)
const PYLON_POS := Vector3(5.5, 0.0, 3.4)
const PYLON_HOEHE := 6.5

var _luke_dreh: Node3D
var _luke_kol: CollisionShape3D
var _teppich: Node3D
var _hinweis: Label3D
var _offen := false
var _spieler: Node3D
var _modell: Node3D
var _tueren: Array = []   ## je Tuer: [Node3D, Ruheposition, Offenposition, Mitte im Modellraum, CollisionShape3D, offen]


func _ready() -> void:
	name = "SechsZwoelf"
	if not ResourceLoader.exists(MODELL):
		return
	_modell = (load(MODELL) as PackedScene).instantiate() as Node3D
	_modell.position.y = HOEHE_OFFSET
	add_child(_modell)
	for mi: MeshInstance3D in _modell.find_children("*", "MeshInstance3D", true, false):
		var n := String(mi.name)
		if _beginnt(n, ENTFERNEN):
			mi.get_parent().remove_child(mi)
			mi.queue_free()
			continue
		if n == "Parking_lot":
			mi.position.y += PARKPLATZ_HEBEN
		elif n == "Rug_004":
			_teppich = mi
		elif n == "Tiles":
			mi.mesh = _mesh_mit_loch(mi, Rect2(LUKE_X.x, LUKE_Z.x, LUKE_X.y - LUKE_X.x, LUKE_Z.y - LUKE_Z.x))
		if TUEREN.has(n) or n in TUER_VERSCHLOSSEN:
			_tuer_einrichten(mi)
		elif not _beginnt(n, OHNE_KOLLISION) and mi.mesh != null:
			_kollision_ueber_grund(mi)
	_glasfront_kollision()
	_licht_bauen()
	_pylon_bauen()
	_luke_bauen()
	_hinweis_bauen()


func _beginnt(n: String, liste: Array[String]) -> bool:
	for p in liste:
		if n.begins_with(p):
			return true
	return false


## Transform eines Modellteils im Raum des Modells.
func _im_modell(mi: Node3D) -> Transform3D:
	var t := Transform3D()
	var c: Node3D = mi
	while c != _modell:
		t = c.transform * t
		c = c.get_parent() as Node3D
	return t


# ---------------------------------------------------------------- Kollision

## Trimesh-Kollision eines Meshes (im Raum des Modells), unten bei KOLLISION_Y_MIN abgeschnitten, beidseitig.
func _kollision_ueber_grund(mi: MeshInstance3D) -> void:
	var t := _im_modell(mi)
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
	form.backface_collision = true
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


# ---------------------------------------------------------------- Boden mit Loch

## Baut das Mesh eines Teils neu und spart dabei das Rechteck `loch` (x/z im Modellraum) aus.
## Dreiecke werden an den vier Lochkanten geteilt; Normalen und UV werden interpoliert, das Material bleibt.
func _mesh_mit_loch(mi: MeshInstance3D, loch: Rect2) -> Mesh:
	var t := _im_modell(mi)
	var inv := t.affine_inverse()
	var neu := ArrayMesh.new()
	for s in mi.mesh.get_surface_count():
		var arr := mi.mesh.surface_get_arrays(s)
		var pos: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var nor: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV] if arr[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var anzahl := idx.size() if not idx.is_empty() else pos.size()
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in range(0, anzahl, 3):
			var poly: Array = []
			for k in 3:
				var vi := idx[i + k] if not idx.is_empty() else i + k
				poly.append([t * pos[vi], nor[vi] if not nor.is_empty() else Vector3.UP, uv[vi] if not uv.is_empty() else Vector2.ZERO])
			# vier Teile rund um das Loch: West, Ost, Nordband, Suedband
			var west := _clip_achse(poly, 0, loch.position.x, true)
			var rest := _clip_achse(poly, 0, loch.position.x, false)
			var ost := _clip_achse(rest, 0, loch.end.x, false)
			var mitte := _clip_achse(rest, 0, loch.end.x, true)
			var nord := _clip_achse(mitte, 2, loch.position.y, true)
			var sued := _clip_achse(mitte, 2, loch.end.y, false)
			for teil: Array in [west, ost, nord, sued]:
				for k in range(1, teil.size() - 1):
					for e: Array in [teil[0], teil[k], teil[k + 1]]:
						st.set_normal(e[1])
						st.set_uv(e[2])
						st.add_vertex(inv * (e[0] as Vector3))
		st.generate_tangents()
		st.commit(neu)
		neu.surface_set_material(neu.get_surface_count() - 1, mi.mesh.surface_get_material(s))
	return neu


## Schneidet ein Polygon aus [Position, Normale, UV] an einer Achsebene (0 = x, 2 = z).
## `kleiner`: behaelt die Seite mit Koordinate <= wert, sonst >= wert.
func _clip_achse(poly: Array, achse: int, wert: float, kleiner: bool) -> Array:
	var aus: Array = []
	for i in poly.size():
		var a: Array = poly[i]
		var b: Array = poly[(i + 1) % poly.size()]
		var ka: float = (a[0] as Vector3)[achse]
		var kb: float = (b[0] as Vector3)[achse]
		var a_ok := ka <= wert if kleiner else ka >= wert
		var b_ok := kb <= wert if kleiner else kb >= wert
		if a_ok:
			aus.append(a)
		if a_ok != b_ok:
			var u := (wert - ka) / (kb - ka)
			aus.append([(a[0] as Vector3).lerp(b[0], u), (a[1] as Vector3).lerp(b[1], u), (a[2] as Vector2).lerp(b[2], u)])
	return aus


# ---------------------------------------------------------------- Tueren

## Schiebetuer (oeffnet bei Annaeherung) oder verschlossene Tuer: Kollisionsbox aus der Huelle des Tuerblatts.
func _tuer_einrichten(mi: MeshInstance3D) -> void:
	var box := _im_modell(mi) * mi.get_aabb()
	var groesse := Vector3(maxf(box.size.x, TUER_DICKE), box.size.y, maxf(box.size.z, TUER_DICKE))
	var kol := _kol_box(box.get_center(), groesse, _modell)
	if TUEREN.has(String(mi.name)):
		var weg: Vector3 = TUEREN[String(mi.name)]
		# Schiebeweg im Raum des Eltern-Knotens der Tuer
		var eltern_inv := (_im_modell(mi) * mi.transform.affine_inverse()).affine_inverse()
		var lokal := eltern_inv.basis * weg
		_tueren.append([mi, mi.position, mi.position + lokal, box.get_center(), kol, false])


func _tueren_schalten() -> void:
	if _spieler == null:
		return
	var p := _modell.to_local(_spieler.global_position)
	for t: Array in _tueren:
		var mitte: Vector3 = t[3]
		var nah := Vector2(p.x - mitte.x, p.z - mitte.z).length() < TUER_REICHWEITE and absf(p.y - mitte.y) < 3.0
		if nah == t[5]:
			continue
		t[5] = nah
		var tw := create_tween()
		tw.tween_property(t[0], "position", t[2] if nah else t[1], TUER_ZEIT)
		(t[4] as CollisionShape3D).set_deferred("disabled", nah)


# ---------------------------------------------------------------- Licht und Pylon

func _licht_bauen() -> void:
	# Kaltes Ladenlicht innen, warmes Licht ueber dem Parkplatz
	for p: Vector3 in [Vector3(-7.5, 3.3, -13.0), Vector3(-2.0, 3.3, -15.0), Vector3(-6.0, 3.3, -23.0), Vector3(-14.5, 3.0, -22.0)]:
		_lampe(p, Color(0.9, 0.97, 1.0), 1.4, 11.0)
	_lampe(Vector3(-5.0, 4.2, -2.0), Color(1.0, 0.8, 0.5), 2.0, 18.0)


func _lampe(p: Vector3, farbe: Color, energie: float, reichweite: float) -> void:
	var l := OmniLight3D.new()
	l.position = p
	l.light_color = farbe
	l.light_energy = energie
	l.omni_range = reichweite
	l.shadow_enabled = false
	add_child(l)


## Werbepylon an der Strassenecke des Parkplatzes: macht den Laden von der Strasse aus erkennbar.
func _pylon_bauen() -> void:
	var stahl := StandardMaterial3D.new()
	stahl.albedo_color = Color(0.16, 0.17, 0.2)
	stahl.metallic = 0.8
	stahl.roughness = 0.35
	var mast := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.35, PYLON_HOEHE, 0.35)
	mast.mesh = bm
	mast.material_override = stahl
	mast.position = PYLON_POS + Vector3(0, PYLON_HOEHE * 0.5, 0)
	add_child(mast)
	_kol_box(mast.position, bm.size)
	var farben: Array[Color] = [Color(0.95, 0.3, 0.15), Color(0.2, 0.75, 0.45), Color(0.2, 0.75, 0.9)]
	for i in farben.size():
		var streifen := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(2.4, 0.45, 0.25)
		streifen.mesh = sm
		var m := StandardMaterial3D.new()
		m.albedo_color = farben[i]
		m.emission_enabled = true
		m.emission = farben[i]
		m.emission_energy_multiplier = 1.6
		streifen.material_override = m
		streifen.position = PYLON_POS + Vector3(0, PYLON_HOEHE - 0.4 - i * 0.5, 0)
		add_child(streifen)
	for vorn: float in [1.0, -1.0]:
		var schrift := Label3D.new()
		schrift.text = "6TWELVE  24/7"
		schrift.font_size = 96
		schrift.pixel_size = 0.004
		schrift.modulate = Color(1, 1, 1)
		schrift.outline_modulate = Color(0.05, 0.05, 0.08)
		schrift.outline_size = 16
		schrift.shaded = false
		schrift.position = PYLON_POS + Vector3(0, PYLON_HOEHE - 0.9, vorn * 0.14)
		schrift.rotation_degrees.y = 0.0 if vorn > 0.0 else 180.0
		add_child(schrift)
	_lampe(PYLON_POS + Vector3(0, PYLON_HOEHE - 1.0, 1.0), Color(1.0, 0.9, 0.8), 1.2, 9.0)


# ---------------------------------------------------------------- Luke

## Luke: Deckel im Look des Bodens (gleiche Fliese), Scharnier an der Rueckwandseite (z-Mindestkante).
func _luke_bauen() -> void:
	var breite := LUKE_X.y - LUKE_X.x
	var tiefe := LUKE_Z.y - LUKE_Z.x
	_luke_dreh = Node3D.new()
	_luke_dreh.position = Vector3((LUKE_X.x + LUKE_X.y) * 0.5, HOEHE_OFFSET + 0.1 - LUKE_DICKE, LUKE_Z.x)
	add_child(_luke_dreh)
	var deckel := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(breite, LUKE_DICKE, tiefe)
	deckel.mesh = bm
	deckel.position = Vector3(0, LUKE_DICKE * 0.5 + 0.004, tiefe * 0.5)
	deckel.material_override = _bodenmaterial()
	_luke_dreh.add_child(deckel)
	_luke_kol = _kol_box(deckel.position, bm.size, _luke_dreh)


## Fliesenmaterial des Modells als Welt-Triplanar (der Deckel hat keine passenden UV); Ersatz: graue Fliese.
func _bodenmaterial() -> Material:
	for mi: MeshInstance3D in _modell.find_children("Tiles", "MeshInstance3D", true, false):
		var m := mi.mesh.surface_get_material(0) as BaseMaterial3D
		if m != null:
			var kopie := m.duplicate() as BaseMaterial3D
			kopie.uv1_triplanar = true
			kopie.uv1_world_triplanar = true
			kopie.uv1_scale = Vector3.ONE * 0.5
			return kopie
	var s := StandardMaterial3D.new()
	s.albedo_color = Color(0.55, 0.55, 0.58)
	return s


func _hinweis_bauen() -> void:
	_hinweis = Label3D.new()
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
	Eingabe.hinweis_binden(_hinweis, "interagieren", "%s: TEPPICH ANHEBEN")


func _luke_mitte_lokal() -> Vector3:
	return Vector3((LUKE_X.x + LUKE_X.y) * 0.5, HOEHE_OFFSET, (LUKE_Z.x + LUKE_Z.y) * 0.5)


func _spieler_nah() -> bool:
	if _spieler == null:
		return false
	var d := to_local(_spieler.global_position) - _luke_mitte_lokal()
	return Vector2(d.x, d.z).length() < REICHWEITE and absf(d.y) < REICHWEITE_Y


func _process(_delta: float) -> void:
	if _hinweis == null:
		return
	if _spieler == null or not is_instance_valid(_spieler):
		_spieler = get_tree().get_first_node_in_group("spieler") as Node3D
	_hinweis.visible = not _offen and _spieler_nah()
	_tueren_schalten()


func _unhandled_input(event: InputEvent) -> void:
	if _offen or _hinweis == null or not event.is_action_pressed("interagieren") or event.is_echo():
		return
	if Dialog.aktiv or not _spieler_nah():
		return
	luke_oeffnen()
	get_viewport().set_input_as_handled()


## Zieht den Teppich weg und klappt die Luke auf (einmalig).
func luke_oeffnen() -> void:
	if _offen or _luke_dreh == null:
		return
	_offen = true
	GameState.flag_setzen(FLAG_ENTDECKT)
	if _teppich != null:
		var tw := create_tween()
		tw.tween_property(_teppich, "position", _teppich.position + _teppich_weg(), TEPPICH_ZEIT)
	var tw2 := create_tween()
	tw2.tween_interval(TEPPICH_ZEIT * 0.5)
	tw2.tween_property(_luke_dreh, "rotation_degrees:x", LUKE_WINKEL, LUKE_ZEIT)
	_luke_kol.set_deferred("disabled", true)
	abgang_geoeffnet.emit()


func _teppich_weg() -> Vector3:
	var eltern_inv := (_im_modell(_teppich) * _teppich.transform.affine_inverse()).affine_inverse()
	return eltern_inv.basis * TEPPICH_VERSATZ
