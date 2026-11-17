extends Node3D
## U-Bahn-Linie M1: verbindet Synth-City (Station unter der Strasse z -206, x -85) mit dem Neo-Distrikt
## (Station unter dem Ostrand des Plateaus, x -585). Ein Pendelzug (levels/metro_zug.gd) faehrt durch einen
## geraden Tunnel unter Gurken-Wald und Durchgang; im Durchgang steigt die Strecke von -15 m auf +7 m
## (immer mindestens 10 m unter der Gelaendeoberflaeche). Stationen: levels/metro_station.gd.
## Betrieb: Der Zug haelt mit offenen Tueren. Steigt der Spieler ein, faehrt er nach ABFAHRT_MIT_FAHRGAST los;
## wartet der Spieler an der anderen Station, kommt der Zug leer; sonst pendelt er alle PENDEL_TAKT Sekunden.
## Mitfahren: Waehrend der Fahrt ist die Spieler-Eingabe gesperrt (EventBus, Grund "metro"), der Spieler wird
## mit dem Zug mitgefuehrt; oben zeigt ein Panel den naechsten Halt.
## Sperre: Bis Grimoire-Seite FREIGABE_SEITE gefunden ist (Energietor am Durchgang, levels/bezirk_tor.gd),
## ruht der Betrieb (Zug steht mit geschlossenen Tueren in der Stadt).
## Sichtbarkeit: Stationen, Tunnel und Zug sind nur sichtbar, wenn der Spieler unter der Oberflaeche oder nahe
## einem Eingang ist. stadt.gd fragt die Loecher fuer Platte, Sohle und Gelaende ueber die static-Funktionen ab.
## Signale: fahrt_gestartet(ziel: String), angekommen(station: String). Keine Exporte.

signal fahrt_gestartet(ziel: String)
signal angekommen(station: String)

const STATION := preload("res://levels/metro_station.gd")
const ZUG := preload("res://levels/metro_zug.gd")
const NEON := preload("res://ui/neon.gd")

const GLEIS_Z := -204.0
## Stationen: Name, Mitte x, Schienenhoehe, Drehung (Grad), Treppenrichtung (lokal)
const STATIONEN: Array[Dictionary] = [
	{"name": "SYNTH-CITY ZENTRUM", "x": -85.0, "y": -15.0, "dreh": 0.0, "treppe": 1.0},
	{"name": "NEO-DISTRIKT", "x": -585.0, "y": 7.0, "dreh": 180.0, "treppe": -1.0},
]
const RAMPE_X0 := -390.0           ## ab hier steigt die Strecke ...
const RAMPE_X1 := -545.0           ## ... bis hier auf die Hoehe der Neo-Station
const OBERFLAECHE_UEBER_SCHIENE := 15.0
const LINIEN_FARBE := Color(0.1, 0.95, 1.0)
const FREIGABE_SEITE := 1
const SPERRE_GRUND := "metro"
## Fahrplan
const HALT_MIN := 6.0
const ABFAHRT_MIT_FAHRGAST := 5.0
const PENDEL_TAKT := 45.0
const TUER_ZEIT := 1.4
const V_MAX := 28.0
const BESCHLEUNIGUNG := 3.0
## Tunnel (Querschnitt relativ zur Schiene, z quer zum Gleis)
const TUNNEL_HALB := 3.4
const TUNNEL_H := 6.6
const TUNNEL_SCHULTER := 4.8
const TUNNEL_DECKE_HALB := 2.0
const TUNNEL_SCHRITT := 2.0
const RIPPE_ABSTAND := 10.0
const SCHWELLE_ABSTAND := 1.2
const KOL_ABSCHNITT := 20.0
## Sichtbarkeit
const UNTER_OBERFLAECHE := 2.5
const EINGANG_NAH := 45.0
const ANZEIGE_TAKT := 0.25

enum Zustand { HALT, SCHLIESSEN, FAHRT, OEFFNEN, RUHT }

var _unten: Node3D
var _stationen: Array[Node3D] = []
var _zug: Node3D
var _zustand := Zustand.HALT
var _ort := 0
var _ziel := 1
var _x := 0.0
var _tempo := 0.0
var _zeit_im_zustand := 0.0
var _drin_seit := 0.0
var _mitfahrt := false
var _versatz := Vector3.ZERO
var _spieler: Node3D
var _anzeige_timer := 0.0
var _hud: Control
var _hud_ebene: CanvasLayer


func _ready() -> void:
	name = "MetroM1"
	process_physics_priority = 10   # nach dem Spieler: Mitfahrt setzt die Position zuletzt
	_unten = Node3D.new()
	_unten.name = "Unterirdisch"
	add_child(_unten)
	var tueren := ZUG.tuer_positionen()
	for i in STATIONEN.size():
		var d: Dictionary = STATIONEN[i]
		var s := Node3D.new()
		s.set_script(STATION)
		s.set("stationsname", d["name"])
		s.set("ziel_name", STATIONEN[1 - i]["name"])
		s.set("treppe_richtung", d["treppe"])
		s.set("tuer_x", tueren)
		s.set("linien_farbe", LINIEN_FARBE)
		s.set("oberflaeche_y", OBERFLAECHE_UEBER_SCHIENE)
		s.position = Vector3(d["x"], d["y"], GLEIS_Z)
		s.rotation_degrees.y = d["dreh"]
		_unten.add_child(s)
		_stationen.append(s)
	_tunnel_bauen()
	_gleis_bauen()
	_zug = Node3D.new()
	_zug.set_script(ZUG)
	_zug.set("linien_farbe", LINIEN_FARBE)
	_unten.add_child(_zug)
	_x = STATIONEN[0]["x"]
	_zug_setzen(_x)
	_hud_bauen()
	if _freigegeben():
		_tueren_an_station(true)
	else:
		_zustand = Zustand.RUHT


# ---------------------------------------------------------------- Strecke

static func schiene_y(x: float) -> float:
	var t := clampf((RAMPE_X0 - x) / (RAMPE_X0 - RAMPE_X1), 0.0, 1.0)
	return lerpf(STATIONEN[0]["y"], STATIONEN[1]["y"], smoothstep(0.0, 1.0, t))


static func _tunnel_enden() -> Vector2:
	# Tunnelmund der Stadt-Station (westliches Hallenende) und der Neo-Station (oestliches Hallenende)
	return Vector2(float(STATIONEN[0]["x"]) - STATION.HALLE_X, float(STATIONEN[1]["x"]) + STATION.HALLE_X)


static func _gleis_enden() -> Vector2:
	return Vector2(float(STATIONEN[0]["x"]) + STATION.HALLE_X - 1.0, float(STATIONEN[1]["x"]) - STATION.HALLE_X + 1.0)


## Lage an Position x: Ursprung auf der Schiene, Basis-x zeigt nach Osten entlang der Steigung.
static func lage(x: float) -> Transform3D:
	var h := 0.5
	var steig := (schiene_y(x + h) - schiene_y(x - h)) / (2.0 * h)
	var bx := Vector3(1.0, steig, 0.0).normalized()
	var bz := Vector3(0, 0, 1)
	var by := bz.cross(bx).normalized()
	return Transform3D(Basis(bx, by, bz), Vector3(x, schiene_y(x), GLEIS_Z))


func _zug_setzen(x: float) -> void:
	_zug.global_transform = global_transform * lage(x)


# ---------------------------------------------------------------- Tunnel und Gleis

func _mat(c: Color, metall: float, rauh: float, leuchten := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metall
	m.roughness = rauh
	m.disable_ambient_light = true
	if leuchten > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = leuchten
	return m


## Extrudiert ein Profil (Punkte z/y relativ zur Schiene) entlang x von x0 nach x1. Normalen zeigen zu `innen`.
func _extrudieren(profil: Array[Vector2], x0: float, x1: float, innen: Vector2, mat: Material, geschlossen := false) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := int(ceil(absf(x1 - x0) / TUNNEL_SCHRITT))
	var kanten := profil.size() if geschlossen else profil.size() - 1
	for i in n:
		var xa := lerpf(x0, x1, float(i) / n)
		var xb := lerpf(x0, x1, float(i + 1) / n)
		var ya := schiene_y(xa)
		var yb := schiene_y(xb)
		var v := 0.0
		for k in kanten:
			var p: Vector2 = profil[k]
			var q: Vector2 = profil[(k + 1) % profil.size()]
			var lk := p.distance_to(q)
			var mitte := (p + q) * 0.5
			var nrm2 := (innen - mitte).normalized()
			var nrm := Vector3(0, nrm2.y, nrm2.x)
			var a := Vector3(xa, ya + p.y, GLEIS_Z + p.x)
			var b := Vector3(xa, ya + q.y, GLEIS_Z + q.x)
			var c := Vector3(xb, yb + q.y, GLEIS_Z + q.x)
			var d := Vector3(xb, yb + p.y, GLEIS_Z + p.x)
			var ua := xa * 0.25
			var ub := xb * 0.25
			for e in [[a, Vector2(ua, v)], [b, Vector2(ua, v + lk * 0.25)], [c, Vector2(ub, v + lk * 0.25)], [a, Vector2(ua, v)], [c, Vector2(ub, v + lk * 0.25)], [d, Vector2(ub, v)]]:
				st.set_normal(nrm)
				st.set_uv(e[1])
				st.add_vertex(e[0])
			v += lk * 0.25
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	if mat is BaseMaterial3D:
		(mat as BaseMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_unten.add_child(mi)
	return mi


func _tunnel_bauen() -> void:
	var enden := _tunnel_enden()
	var wand := _mat(Color(0.07, 0.075, 0.09), 0.3, 0.75)
	wand.cull_mode = BaseMaterial3D.CULL_DISABLED
	var profil: Array[Vector2] = [
		Vector2(TUNNEL_HALB, STATION.BETT_Y), Vector2(TUNNEL_HALB, TUNNEL_SCHULTER),
		Vector2(TUNNEL_DECKE_HALB, TUNNEL_H), Vector2(-TUNNEL_DECKE_HALB, TUNNEL_H),
		Vector2(-TUNNEL_HALB, TUNNEL_SCHULTER), Vector2(-TUNNEL_HALB, STATION.BETT_Y)]
	_extrudieren(profil, enden.x, enden.y, Vector2(0, 3.0), wand, true)
	# Neonbaender an den Schultern (Linienfarbe links, pink rechts)
	var neon_l := _mat(LINIEN_FARBE, 0.0, 0.4, 2.5)
	var neon_r := _mat(Color(1.0, 0.15, 0.7), 0.0, 0.4, 2.5)
	for s: float in [-1.0, 1.0]:
		var p := Vector2(s * (TUNNEL_HALB - 0.05), TUNNEL_SCHULTER - 0.1)
		var band: Array[Vector2] = [p, p + Vector2(0, -0.14)]
		_extrudieren(band, enden.x, enden.y, Vector2(0, 3.0), neon_l if s < 0.0 else neon_r)
	# Rippen alle RIPPE_ABSTAND m (MultiMesh: zwei Pfosten, ein Riegel)
	var trafos_p: Array[Transform3D] = []
	var trafos_r: Array[Transform3D] = []
	var x := enden.x - RIPPE_ABSTAND * 0.5
	while x > enden.y:
		var l := lage(x)
		for s: float in [-1.0, 1.0]:
			trafos_p.append(l * Transform3D(Basis.from_scale(Vector3(0.2, TUNNEL_SCHULTER - STATION.BETT_Y, 0.12)), Vector3(0, (TUNNEL_SCHULTER + STATION.BETT_Y) * 0.5, s * (TUNNEL_HALB - 0.08))))
		trafos_r.append(l * Transform3D(Basis.from_scale(Vector3(0.2, 0.12, TUNNEL_DECKE_HALB * 2.0)), Vector3(0, TUNNEL_H - 0.08, 0)))
		x -= RIPPE_ABSTAND
	var rippe := _mat(Color(0.25, 0.27, 0.32), 0.8, 0.3)
	_multimesh(trafos_p, rippe)
	_multimesh(trafos_r, _mat(LINIEN_FARBE, 0.0, 0.4, 1.5))
	# Kollision (damit die Kamera im Zug bleibt): Boden, Waende, Decke je Abschnitt
	x = enden.x
	while x > enden.y:
		var x2 := maxf(x - KOL_ABSCHNITT, enden.y)
		var xm := (x + x2) * 0.5
		var l := lage(xm)
		var laenge := absf(x - x2) / l.basis.x.x + 0.4
		for teil in [[Vector3(0, STATION.BETT_Y - 0.25, 0), Vector3(laenge, 0.5, TUNNEL_HALB * 2.0)],
				[Vector3(0, TUNNEL_H * 0.5, -TUNNEL_HALB - 0.25), Vector3(laenge, TUNNEL_H, 0.5)],
				[Vector3(0, TUNNEL_H * 0.5, TUNNEL_HALB + 0.25), Vector3(laenge, TUNNEL_H, 0.5)],
				[Vector3(0, TUNNEL_H + 0.25, 0), Vector3(laenge, 0.5, TUNNEL_HALB * 2.0)]]:
			var sb := StaticBody3D.new()
			var cs := CollisionShape3D.new()
			var sh := BoxShape3D.new()
			sh.size = teil[1]
			cs.shape = sh
			sb.add_child(cs)
			sb.transform = l * Transform3D(Basis(), teil[0])
			_unten.add_child(sb)
		x = x2


func _gleis_bauen() -> void:
	var g := _gleis_enden()
	var stahl := _mat(Color(0.55, 0.58, 0.62), 0.95, 0.25)
	for s: float in [-1.0, 1.0]:
		var schiene: Array[Vector2] = [Vector2(s * 0.75 - 0.06, -0.15), Vector2(s * 0.75 - 0.06, 0.0), Vector2(s * 0.75 + 0.06, 0.0), Vector2(s * 0.75 + 0.06, -0.15)]
		_extrudieren(schiene, g.x, g.y, Vector2(s * 0.75, -1.0), stahl)
	var magnet: Array[Vector2] = [Vector2(-0.18, -0.12), Vector2(0.18, -0.12)]
	_extrudieren(magnet, g.x, g.y, Vector2(0, 2.0), _mat(LINIEN_FARBE, 0.0, 0.4, 2.0))
	var trafos: Array[Transform3D] = []
	var x := g.x
	while x > g.y:
		trafos.append(lage(x) * Transform3D(Basis.from_scale(Vector3(0.25, 0.12, 2.4)), Vector3(0, -0.21, 0)))
		x -= SCHWELLE_ABSTAND
	_multimesh(trafos, _mat(Color(0.1, 0.1, 0.12), 0.2, 0.8))


func _multimesh(trafos: Array[Transform3D], mat: Material) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = BoxMesh.new()
	mm.instance_count = trafos.size()
	for i in trafos.size():
		mm.set_instance_transform(i, trafos[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_unten.add_child(mmi)


# ---------------------------------------------------------------- Betrieb

func _freigegeben() -> bool:
	return GameState.hat_seite(FREIGABE_SEITE)


func _spieler_pos() -> Variant:
	if _spieler == null or not is_instance_valid(_spieler):
		_spieler = get_tree().get_first_node_in_group("spieler") as Node3D
		if _spieler == null:
			return null
	return _spieler.global_position


## Bahnsteigseite des Zugs an Station i: -1 oder +1 (lokale z-Seite des Zugs).
func _bahnsteig_seite(i: int) -> int:
	var zum_bahnsteig := _stationen[i].global_basis * Vector3(0, 0, -1)
	return 1 if zum_bahnsteig.dot(_zug.global_basis.z) > 0.0 else -1


func _tueren_an_station(offen: bool) -> void:
	_zug.call("tueren_setzen", _bahnsteig_seite(_ort), offen)
	_stationen[_ort].call("bahnsteigtueren_setzen", offen)


func _wechseln(z: Zustand) -> void:
	_zustand = z
	_zeit_im_zustand = 0.0


func _physics_process(delta: float) -> void:
	_zeit_im_zustand += delta
	var sp: Variant = _spieler_pos()
	match _zustand:
		Zustand.RUHT:
			if _freigegeben():
				_tueren_an_station(true)
				_wechseln(Zustand.HALT)
		Zustand.HALT:
			_halt(sp, delta)
		Zustand.SCHLIESSEN:
			if _zeit_im_zustand >= TUER_ZEIT:
				_abfahren(sp)
		Zustand.FAHRT:
			_fahren(delta)
		Zustand.OEFFNEN:
			if _zeit_im_zustand >= TUER_ZEIT:
				_wechseln(Zustand.HALT)
	if _mitfahrt and _spieler != null:
		_spieler.global_position = _zug.to_global(_versatz)
		if _spieler is CharacterBody3D:
			(_spieler as CharacterBody3D).velocity = Vector3.ZERO
	_sichtbarkeit(sp)
	_anzeige_timer -= delta
	if _anzeige_timer <= 0.0:
		_anzeige_timer = ANZEIGE_TAKT
		_anzeigen_aktualisieren(sp)
	if _hud != null:
		_hud_ebene.visible = _mitfahrt
		if _mitfahrt:
			_hud.queue_redraw()


func _halt(sp: Variant, delta: float) -> void:
	if sp == null:
		return
	var p: Vector3 = sp
	if _zug.call("innen", p):
		_drin_seit += delta
		if _drin_seit >= ABFAHRT_MIT_FAHRGAST and _zeit_im_zustand >= HALT_MIN * 0.5:
			_schliessen()
		return
	_drin_seit = 0.0
	if _zeit_im_zustand < HALT_MIN:
		return
	var anders := 1 - _ort
	if _stationen[anders].call("im_bereich", p):
		_schliessen()
	elif _zeit_im_zustand >= PENDEL_TAKT and not _stationen[_ort].call("im_bereich", p):
		_schliessen()


func _schliessen() -> void:
	_tueren_an_station(false)
	_wechseln(Zustand.SCHLIESSEN)


func _abfahren(sp: Variant) -> void:
	_ziel = 1 - _ort
	_tempo = 0.0
	_drin_seit = 0.0
	if sp != null and _zug.call("innen", sp):
		_mitfahrt = true
		_versatz = _zug.to_local(sp)
		EventBus.eingabe_gesperrt.emit(SPERRE_GRUND, true)
	_zug.call("anzeige_setzen", "M1 · NÄCHSTER HALT: %s" % STATIONEN[_ziel]["name"])
	fahrt_gestartet.emit(STATIONEN[_ziel]["name"])
	_wechseln(Zustand.FAHRT)


func _fahren(delta: float) -> void:
	var ziel_x: float = STATIONEN[_ziel]["x"]
	var rest := absf(ziel_x - _x)
	var soll := minf(V_MAX, sqrt(2.0 * BESCHLEUNIGUNG * rest))
	_tempo = minf(soll, _tempo + BESCHLEUNIGUNG * delta)
	_tempo = maxf(_tempo, 0.5)
	var schritt := minf(_tempo * delta, rest)
	_x += signf(ziel_x - _x) * schritt
	_zug_setzen(_x)
	if rest - schritt <= 0.001:
		_x = ziel_x
		_zug_setzen(_x)
		_ort = _ziel
		_tueren_an_station(true)
		_zug.call("anzeige_setzen", "M1 · %s" % STATIONEN[_ort]["name"])
		if _mitfahrt:
			_mitfahrt = false
			EventBus.eingabe_gesperrt.emit(SPERRE_GRUND, false)
		angekommen.emit(STATIONEN[_ort]["name"])
		_wechseln(Zustand.OEFFNEN)


func _fortschritt() -> float:
	var a: float = STATIONEN[1 - _ziel]["x"]
	var b: float = STATIONEN[_ziel]["x"]
	return clampf((_x - a) / (b - a), 0.0, 1.0)


# ---------------------------------------------------------------- Anzeigen, Sichtbarkeit, HUD

func _anzeigen_aktualisieren(sp: Variant) -> void:
	for i in _stationen.size():
		var gegen: String = STATIONEN[1 - i]["name"]
		var zeile2 := ""
		match _zustand:
			Zustand.RUHT:
				zeile2 = "BETRIEB RUHT · ENERGIESPERRE AM DURCHGANG"
			Zustand.HALT, Zustand.OEFFNEN:
				if _ort == i:
					var drin: bool = sp != null and _zug.call("innen", sp)
					zeile2 = "ZUG STEHT BEREIT · ABFAHRT IN %d S" % int(ceil(ABFAHRT_MIT_FAHRGAST - _drin_seit)) if drin else "ZUG STEHT BEREIT · BITTE EINSTEIGEN"
				else:
					zeile2 = "ZUG WIRD GERUFEN" if sp != null and _stationen[i].call("im_bereich", sp) else "ZUG IN %s" % STATIONEN[_ort]["name"]
			Zustand.SCHLIESSEN:
				zeile2 = "TÜREN SCHLIESSEN" if _ort == i else "ZUG FÄHRT GLEICH AB"
			Zustand.FAHRT:
				if _ziel == i:
					zeile2 = "ZUG KOMMT IN %d S" % int(ceil(absf(float(STATIONEN[i]["x"]) - _x) / maxf(_tempo, V_MAX * 0.6)))
				else:
					zeile2 = "ZUG UNTERWEGS NACH %s" % STATIONEN[1 - i]["name"]
		_stationen[i].call("anzeige_setzen", "M1  →  %s" % gegen, zeile2)


static func oberflaeche(x: float, z: float) -> float:
	if TerrainForm.abstand(x, z) < TerrainForm.RAND:
		return 0.0
	return TerrainForm.hoehe(x, z)


func _sichtbarkeit(sp: Variant) -> void:
	var zeigen := _mitfahrt
	if not zeigen and sp != null:
		var p: Vector3 = sp
		zeigen = p.y < oberflaeche(p.x, p.z) - UNTER_OBERFLAECHE
		if not zeigen:
			for s in _stationen:
				var e: Vector3 = s.call("eingang_global")
				if Vector2(p.x - e.x, p.z - e.z).length() < EINGANG_NAH:
					zeigen = true
					break
	if _unten.visible != zeigen:
		_unten.visible = zeigen


func _hud_bauen() -> void:
	_hud_ebene = CanvasLayer.new()
	_hud_ebene.layer = 25
	_hud_ebene.visible = false
	add_child(_hud_ebene)
	_hud = Control.new()
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.draw.connect(_hud_zeichnen)
	_hud_ebene.add_child(_hud)


func _hud_zeichnen() -> void:
	var gr := _hud.size
	var r := Rect2(gr.x * 0.5 - 250.0, 16.0, 500.0, 92.0)
	NEON.rahmen(_hud, r, LINIEN_FARBE)
	var f := NEON.font()
	_hud.draw_string(f, r.position + Vector2(0, 30), "LINIE M1 // NÄCHSTER HALT", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 14, Color(1, 1, 1, 0.7))
	_hud.draw_string(f, r.position + Vector2(0, 58), String(STATIONEN[_ziel]["name"]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 24, NEON.GELB)
	var balken := Rect2(r.position + Vector2(24, 72), Vector2(r.size.x - 48, 8))
	_hud.draw_rect(balken, Color(1, 1, 1, 0.12))
	_hud.draw_rect(Rect2(balken.position, Vector2(balken.size.x * _fortschritt(), balken.size.y)), LINIEN_FARBE)


# ---------------------------------------------------------------- Loecher fuer stadt.gd

static func _welt_rect(i: int, r: Rect2) -> Rect2:
	var d: Dictionary = STATIONEN[i]
	var dreh := deg_to_rad(float(d["dreh"]))
	var b := Basis(Vector3.UP, dreh)
	var o := Vector3(d["x"], 0.0, GLEIS_Z)
	var a := o + b * Vector3(r.position.x, 0, r.position.y)
	var c := o + b * Vector3(r.end.x, 0, r.end.y)
	return Rect2(minf(a.x, c.x), minf(a.z, c.z), absf(c.x - a.x), absf(c.z - a.z))


## Index der Station, deren Oberflaeche die Stadtplatte ist (die andere liegt unter Gelaende).
static func _stadt_station() -> int:
	return 0


## Loch in der Stadtplatte (y 0): offener Treppenteil der Stadt-Station.
static func plattenloecher() -> Array[Rect2]:
	var i := _stadt_station()
	return [_welt_rect(i, STATION.oeffnung_lokal(STATIONEN[i]["treppe"], OBERFLAECHE_UEBER_SCHIENE))]


## Loch in der Sohle (Unterkante y_unten, Welt).
static func sohlenloecher(y_unten: float) -> Array[Rect2]:
	var i := _stadt_station()
	var y_lokal := y_unten - float(STATIONEN[i]["y"])
	return [_welt_rect(i, STATION.durchstich_lokal(STATIONEN[i]["treppe"], OBERFLAECHE_UEBER_SCHIENE, y_lokal))]


## Terrain3D-Loecher (Weltrechtecke; alle Stuetzpunkte darin werden Loch): Stadt unter der Platte bei
## gelaende_unter_platte, Neo an der Oberflaeche.
static func terrain_loecher(gelaende_unter_platte: float) -> Array[Rect2]:
	var l: Array[Rect2] = []
	var i := _stadt_station()
	var y_lokal := gelaende_unter_platte - float(STATIONEN[i]["y"])
	l.append(_welt_rect(i, STATION.durchstich_lokal(STATIONEN[i]["treppe"], OBERFLAECHE_UEBER_SCHIENE, y_lokal)).grow(1.0))
	var n := 1 - i
	l.append(_welt_rect(n, STATION.oeffnung_lokal(STATIONEN[n]["treppe"], OBERFLAECHE_UEBER_SCHIENE)).grow(1.0))
	return l
