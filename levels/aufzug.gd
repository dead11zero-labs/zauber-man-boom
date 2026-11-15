extends Node3D
## Aufzug im Inneren des Zauber-Towers: Glaskabine in einem Schacht, faehrt von der Lobby (unten) ins Hauptquartier (oben).
## Die Kabine ist nach +z offen. An jeder Haltestelle gibt es eine Schachtwand (hinten, links, rechts) und eine Schiebetuer vorne,
## die nur offen ist, wenn die Kabine dort steht. Waehrend der Fahrt schliesst eine Schranke die Kabinenfront.
## Die Schacht-Oeffnungen in Boeden und Decken baut stadt.gd (_turm), dieses Skript baut Kabine, Tueren und Wandstuecke.
## In der Kabine steht ein Terminal (Computer mit Bildschirm, SubViewport): zeigt Etage, Hoehe, Status, Uhrzeit und eine Schachtanzeige.
## Bedienung: Taste "interagieren" (E / Pad Y) an einer Haltestelle. Steht die Kabine dort, faehrt sie zur anderen,
## sonst wird sie gerufen.
## Exportiert: unten_y, oben_y, schacht_groesse, fahrtempo, etagen_y und etagen_name (Hoehen und Namen aller Etagen
## fuers Terminal; Index 0 = Lobby, letzter Eintrag = HQ).
## Signale: fahrt_gestartet(ziel_oben: bool), angekommen(oben: bool). Kein harter Pfad zum Spieler (Gruppe "spieler").

signal fahrt_gestartet(ziel_oben: bool)
signal angekommen(oben: bool)

const NEON := preload("res://ui/neon.gd")
const WAHL := preload("res://ui/aufzug_wahl.gd")
const TERMINAL_GROESSE := Vector2i(640, 400)
const TERMINAL_BILD := Vector2(0.9, 0.56)
const TERMINAL_AKTIV_BIS := 60.0   ## Meter Abstand zum Spieler, bis zu dem der Bildschirm neu gezeichnet wird
const TERMINAL_TAKT := 0.1
const TERMINAL_FARBE := Color(0.75, 0.92, 0.95)
const TERMINAL_AKZENT := Color(1.0, 0.82, 0.4)
const SPIEL_ZUM_SCHACHT := 0.4      ## Schacht minus Kabine (Gesamtluft), je Seite die Haelfte
const KABINE_HOEHE := 3.4
const BODEN_DICKE := 0.3
const STATION_REICHWEITE := 6.0   ## horizontal, vom Schachtmittelpunkt
const STATION_HOEHE := 2.5        ## vertikal, um zur Etage zu zaehlen (Etagen liegen 6 m auseinander)
const FAHRT_MIN_ZEIT := 1.5
const HINWEIS_HOEHE := 3.6
const BESCHRIFTUNG_PIXEL := 0.012
const WAND_HOEHE := 1.1           ## niedrige Seitenwaende der Kabine
const WAND_DICKE := 0.2
const SCHRANKE_HOEHE := 3.0
const SCHACHT_WAND_HOEHE := 4.6   ## Wandstuecke an den Haltestellen
const SCHACHT_WAND_DICKE := 0.3
const TUER_DICKE := 0.12
const TUER_ZEIT := 0.6
const TUER_OFFEN_ANTEIL := 0.02   ## Rest-Hoehe der Tuer im geoeffneten Zustand (faehrt nach oben ein)

@export var unten_y := 0.0
@export var oben_y := 160.2
@export var schacht_groesse := 5.0
@export var fahrtempo := 22.0  ## Meter pro Sekunde
@export var etagen_y := PackedFloat32Array()
@export var etagen_name := PackedStringArray()

var _kabine: AnimatableBody3D
var _schranke: CollisionShape3D
var _tueren: Array = []  ## je Haltestelle (0 unten, 1 oben): [Node3D (Skalierung), CollisionShape3D]
var _hinweis: Label3D
var _oben := false
var _stand := 0          ## Index der Etage, an der die Kabine steht (0 = Lobby)
var _ziel := 0           ## Index der Etage, zu der sie gerade faehrt
var _wahl: Node          ## offenes Etagen-Menue (oder null)
var _faehrt := false
var _kabine_ziel_oben := false
var _spieler: Node3D
var _mat_cyan: StandardMaterial3D
var _mat_glas: StandardMaterial3D
var _mat_dunkel: StandardMaterial3D
var _kabinen_breite := 4.6
var _terminal_vp: SubViewport
var _terminal_ui: Control
var _terminal_zeit := 0.0
var _mat_wand: StandardMaterial3D
var _mat_boden: StandardMaterial3D
var _mat_decke: StandardMaterial3D


func _ready() -> void:
	_kabinen_breite = schacht_groesse - SPIEL_ZUM_SCHACHT
	_materialien()
	for i in maxi(etagen_y.size(), 2):
		_haltestelle_bauen(i)
	_kabine_bauen()
	_tuer_schalten(0, true, false)  # Kabine steht unten: Tuer der Lobby offen
	_hinweis = Label3D.new()
	_hinweis.font_size = 48
	_hinweis.pixel_size = BESCHRIFTUNG_PIXEL
	_hinweis.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hinweis.shaded = false
	_hinweis.no_depth_test = true
	_hinweis.modulate = Color(1.0, 0.85, 0.3)
	_hinweis.outline_modulate = Color(0.0, 0.02, 0.06)
	_hinweis.outline_size = 10
	_hinweis.visible = false
	add_child(_hinweis)


func _textur(ordner: String, kachel: float, tint: Color, metall: float) -> StandardMaterial3D:
	var pfad := "res://assets/texturen/%s/" % ordner
	var t := StandardMaterial3D.new()
	t.albedo_texture = load(pfad + "diff.jpg")
	t.albedo_color = tint
	t.normal_enabled = true
	t.normal_texture = load(pfad + "nor.jpg")
	t.roughness_texture = load(pfad + "rough.jpg")
	t.roughness = 1.0
	t.metallic = metall
	t.uv1_triplanar = true
	t.uv1_scale = Vector3.ONE / kachel
	t.disable_ambient_light = true
	return t


func _materialien() -> void:
	# Gedaempfte Akzentfarbe statt grellem Neon (Tower-Licht wurde reduziert)
	_mat_cyan = StandardMaterial3D.new()
	_mat_cyan.albedo_color = Color(0.45, 0.8, 0.9)
	_mat_cyan.emission_enabled = true
	_mat_cyan.emission = Color(0.45, 0.8, 0.9)
	_mat_cyan.emission_energy_multiplier = 0.8
	_mat_glas = StandardMaterial3D.new()
	_mat_glas.albedo_color = Color(0.7, 0.85, 0.95, 0.2)
	_mat_glas.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_glas.roughness = 0.05
	_mat_dunkel = _textur("foyer_painted_plaster_wall", 2.0, Color(0.7, 0.74, 0.82), 0.1)
	_mat_wand = _textur("metal_plate", 1.5, Color(0.72, 0.74, 0.8), 0.8)
	_mat_boden = _textur("floor_tiles_06", 1.5, Color(0.55, 0.57, 0.62), 0.0)
	_mat_decke = _textur("buero_decke", 1.2, Color(1, 1, 1), 0.0)


func _box(eltern: Node3D, pos: Vector3, groesse: Vector3, mat: Material, kollision := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = groesse
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	eltern.add_child(mi)
	if kollision:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = groesse
		cs.shape = bs
		sb.add_child(cs)
		mi.add_child(sb)
	return mi


## Haltestelle der Etage `idx`: Schiebetuer vorne und Schachtwaende (Kollision). Lobby (0) und HQ (letzte) bekommen
## sichtbare Waende, Deckel (HQ) und Cyan-Leisten; die Buero-Etagen haben ihren Aufzugskern schon (buero_etage.gd),
## dort gibt es nur unsichtbare Kollisionswaende und die Tuer.
func _haltestelle_bauen(idx: int) -> void:
	var y0 := _etage_y(idx)
	var voll := idx == 0 or idx == _letzte()
	var oben := idx == _letzte()
	var halb := schacht_groesse * 0.5
	var h := SCHACHT_WAND_HOEHE
	var d := SCHACHT_WAND_DICKE
	# Waende stehen knapp ausserhalb der Kabine, aber innerhalb der Bodenoeffnung
	var hinten := Vector3(0, y0 + h * 0.5, -halb - d * 0.5 + 0.05)
	var hinten_g := Vector3(schacht_groesse + 2.0 * d, h, d)
	if voll:
		_box(self, hinten, hinten_g, _mat_dunkel, true)
	else:
		_kollision(self, hinten, hinten_g)
	for sx in [-1.0, 1.0]:
		var seite := Vector3(sx * (halb + d * 0.5 - 0.05), y0 + h * 0.5, 0)
		var seite_g := Vector3(d, h, schacht_groesse)
		if voll:
			_box(self, seite, seite_g, _mat_dunkel, true)
			_box(self, Vector3(sx * (halb - 0.04), y0 + h * 0.5, 0), Vector3(0.08, h, schacht_groesse - 0.1), _mat_cyan)
		else:
			_kollision(self, seite, seite_g)
	if oben:
		_box(self, Vector3(0, y0 + h + d * 0.5, 0), Vector3(schacht_groesse + 2.0 * d, d, schacht_groesse + 2.0 * d), _mat_dunkel, true)
	# Tuer: Glasflaeche an der Vorderkante, pivotiert an der Oberkante und faehrt nach oben ein
	var tuer := Node3D.new()
	tuer.position = Vector3(0, y0 + KABINE_HOEHE, halb + TUER_DICKE * 0.5)
	add_child(tuer)
	_box(tuer, Vector3(0, -KABINE_HOEHE * 0.5, 0), Vector3(schacht_groesse, KABINE_HOEHE, TUER_DICKE), _mat_glas)
	_box(tuer, Vector3(0, -KABINE_HOEHE + 0.05, 0), Vector3(schacht_groesse, 0.1, TUER_DICKE + 0.02), _mat_cyan)
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(schacht_groesse, KABINE_HOEHE, TUER_DICKE)
	cs.shape = bs
	cs.position = Vector3(0, -KABINE_HOEHE * 0.5, 0)
	sb.add_child(cs)
	tuer.add_child(sb)
	_tueren.append([tuer, cs])  # Index = Etagenindex; Tueren stehen anfangs zu


## Hoehe (lokal) der Etage `idx`; Lobby/HQ fallen auf unten_y/oben_y zurueck, falls keine Liste gesetzt ist.
func _etage_y(idx: int) -> float:
	if etagen_y.size() > idx:
		return etagen_y[idx]
	return oben_y if idx > 0 else unten_y


func _kabine_bauen() -> void:
	_kabine = AnimatableBody3D.new()
	_kabine.sync_to_physics = true
	_kabine.position = Vector3(0, unten_y - BODEN_DICKE * 0.5, 0)
	add_child(_kabine)
	var b := _kabinen_breite
	_box(_kabine, Vector3.ZERO, Vector3(b, BODEN_DICKE, b), _mat_dunkel)
	_kollision(_kabine, Vector3.ZERO, Vector3(b, BODEN_DICKE, b))
	_box(_kabine, Vector3(0, BODEN_DICKE * 0.5 + 0.02, 0), Vector3(b - 0.3, 0.04, b - 0.3), _mat_boden)
	for sx in [-1.0, 1.0]:
		_box(_kabine, Vector3(sx * (b * 0.5 - 0.35), BODEN_DICKE * 0.5 + 0.045, 0), Vector3(0.04, 0.01, b - 0.7), _mat_cyan)
	_box(_kabine, Vector3(0, BODEN_DICKE * 0.5 + 0.045, -b * 0.5 + 0.35), Vector3(b - 0.7, 0.01, 0.04), _mat_cyan)
	var wy := BODEN_DICKE * 0.5 + WAND_HOEHE * 0.5
	for e in [[Vector3(0, wy, -b * 0.5 + WAND_DICKE * 0.5), Vector3(b, WAND_HOEHE, WAND_DICKE)],
			[Vector3(-b * 0.5 + WAND_DICKE * 0.5, wy, 0), Vector3(WAND_DICKE, WAND_HOEHE, b)],
			[Vector3(b * 0.5 - WAND_DICKE * 0.5, wy, 0), Vector3(WAND_DICKE, WAND_HOEHE, b)]]:
		_box(_kabine, e[0], e[1], _mat_wand)
		_kollision(_kabine, e[0], e[1])
		var gp: Vector3 = e[0] + Vector3(0, WAND_HOEHE * 0.5 + (KABINE_HOEHE - WAND_HOEHE) * 0.5, 0)
		_box(_kabine, gp, Vector3(e[1].x, KABINE_HOEHE - WAND_HOEHE, e[1].z), _mat_glas)
	_box(_kabine, Vector3(0, BODEN_DICKE * 0.5 + KABINE_HOEHE, 0), Vector3(b, 0.2, b), _mat_decke)
	var panel := StandardMaterial3D.new()
	panel.albedo_color = Color(1.0, 0.96, 0.88)
	panel.emission_enabled = true
	panel.emission = Color(1.0, 0.96, 0.88)
	panel.emission_energy_multiplier = 0.9
	_box(_kabine, Vector3(0, BODEN_DICKE * 0.5 + KABINE_HOEHE - 0.11, 0), Vector3(b - 1.2, 0.02, b - 1.2), panel)
	# Handlauf aus Chrom an den Seitenwaenden
	for sx in [-1.0, 1.0]:
		_box(_kabine, Vector3(sx * (b * 0.5 - WAND_DICKE - 0.08), BODEN_DICKE * 0.5 + 0.95, -0.2), Vector3(0.05, 0.05, b - 1.2), _mat_wand)
	_terminal_bauen()
	var lampe := OmniLight3D.new()
	lampe.light_color = Color(0.7, 0.95, 1.0)
	lampe.light_energy = 0.8
	lampe.omni_range = 8.0
	lampe.position = Vector3(0, KABINE_HOEHE - 0.4, 0)
	_kabine.add_child(lampe)
	# Schranke vorne: nur waehrend der Fahrt aktiv
	var sh := StaticBody3D.new()
	_schranke = CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(b, SCHRANKE_HOEHE, 0.2)
	_schranke.shape = bs
	_schranke.position = Vector3(0, BODEN_DICKE * 0.5 + SCHRANKE_HOEHE * 0.5, b * 0.5)
	_schranke.disabled = true
	sh.add_child(_schranke)
	_kabine.add_child(sh)


## Terminal: Pult mit Tastatur und schraegem Monitor an der Rueckwand. Der Bildschirm ist eine SubViewport-Textur.
func _terminal_bauen() -> void:
	var b := _kabinen_breite
	var z := -b * 0.5 + WAND_DICKE + 0.38
	var y0 := BODEN_DICKE * 0.5
	_box(_kabine, Vector3(0, y0 + 0.45, z), Vector3(1.5, 0.9, 0.55), _mat_dunkel)
	_box(_kabine, Vector3(0, y0 + 0.92, z + 0.06), Vector3(1.4, 0.04, 0.5), _mat_wand)
	# Tastatur und Maus
	var weiss := StandardMaterial3D.new()
	weiss.albedo_color = Color(0.85, 0.86, 0.9)
	weiss.roughness = 0.5
	var schwarz := StandardMaterial3D.new()
	schwarz.albedo_color = Color(0.05, 0.06, 0.08)
	schwarz.roughness = 0.35
	_box(_kabine, Vector3(-0.1, y0 + 0.955, z + 0.2), Vector3(0.62, 0.025, 0.2), weiss)
	_box(_kabine, Vector3(0.45, y0 + 0.955, z + 0.2), Vector3(0.07, 0.025, 0.11), schwarz)
	# Monitor: Standfuss, Gehaeuse, Bildflaeche
	_box(_kabine, Vector3(0, y0 + 1.0, z - 0.1), Vector3(0.3, 0.04, 0.2), schwarz)
	_box(_kabine, Vector3(0, y0 + 1.2, z - 0.14), Vector3(0.08, 0.4, 0.05), schwarz)
	_box(_kabine, Vector3(0, y0 + 1.52, z - 0.1), Vector3(TERMINAL_BILD.x + 0.1, TERMINAL_BILD.y + 0.1, 0.06), schwarz)
	_terminal_vp = SubViewport.new()
	_terminal_vp.size = TERMINAL_GROESSE
	_terminal_vp.disable_3d = true
	_terminal_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_kabine.add_child(_terminal_vp)
	_terminal_ui = Control.new()
	_terminal_ui.size = Vector2(TERMINAL_GROESSE)
	_terminal_ui.draw.connect(_terminal_zeichnen)
	_terminal_vp.add_child(_terminal_ui)
	var bild := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = TERMINAL_BILD
	bild.mesh = qm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.1, 0.1, 0.1)
	m.albedo_texture = _terminal_vp.get_texture()
	m.emission_enabled = true
	m.emission_texture = _terminal_vp.get_texture()
	m.emission_energy_multiplier = 0.9
	m.roughness = 0.15
	bild.material_override = m
	bild.position = Vector3(0, y0 + 1.52, z - 0.065)
	_kabine.add_child(bild)


## Nummer der Etage, auf der die Kabine gerade steht oder die sie zuletzt passiert hat (0 = Lobby).
func _etage_index() -> int:
	var y := _kabine.position.y + BODEN_DICKE * 0.5
	var idx := 0
	for i in etagen_y.size():
		if etagen_y[i] <= y + 0.5:
			idx = i
	return idx


func _terminal_zeichnen() -> void:
	var f := NEON.font()
	var r := Rect2(Vector2.ZERO, Vector2(TERMINAL_GROESSE))
	var u := _terminal_ui
	u.draw_rect(r, Color(0.02, 0.035, 0.05))
	u.draw_rect(Rect2(0, 0, r.size.x, 40), Color(0.08, 0.13, 0.18))
	u.draw_string(f, Vector2(16, 27), "ZAUBER-TOWER  //  AUFZUG-TERMINAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, TERMINAL_FARBE)
	u.draw_string(f, Vector2(r.size.x - 130, 27), Time.get_time_string_from_system().substr(0, 5), HORIZONTAL_ALIGNMENT_RIGHT, 114, 20, TERMINAL_AKZENT)
	var idx := _etage_index()
	var hoehe := _kabine.position.y + BODEN_DICKE * 0.5 - unten_y
	var ziel_text := "BEREIT"
	if _faehrt:
		ziel_text = "FAHRT AUFWÄRTS" if _kabine_ziel_oben else "FAHRT ABWÄRTS"
	var titel := "EG" if idx == 0 else "%02d" % idx
	if etagen_y.size() > 0 and idx == etagen_y.size() - 1:
		titel = "HQ"
	u.draw_string(f, Vector2(24, 140), titel, HORIZONTAL_ALIGNMENT_LEFT, -1, 110, TERMINAL_AKZENT)
	var name_ := String(etagen_name[idx]) if idx < etagen_name.size() else ""
	u.draw_string(f, Vector2(24, 182), name_, HORIZONTAL_ALIGNMENT_LEFT, int(r.size.x * 0.6), 22, TERMINAL_FARBE)
	u.draw_string(f, Vector2(24, 240), "HÖHE    %03d M" % int(hoehe), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, TERMINAL_FARBE)
	u.draw_string(f, Vector2(24, 276), "STATUS  " + ziel_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, TERMINAL_FARBE)
	var ziel_name := String(etagen_name[_ziel]) if _faehrt and _ziel < etagen_name.size() else "—"
	u.draw_string(f, Vector2(24, 312), "ZIEL    " + ziel_name, HORIZONTAL_ALIGNMENT_LEFT, int(r.size.x * 0.65), 24, Color(TERMINAL_FARBE, 0.7))
	u.draw_string(f, Vector2(24, 372), "E AM TERMINAL: ETAGE WÄHLEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(TERMINAL_FARBE, 0.55))
	# Schachtanzeige rechts: Balken mit Etagenstrichen und Marke
	var bx := r.size.x - 90.0
	var oben := 70.0
	var unten := r.size.y - 40.0
	var gesamt := maxf(oben_y - unten_y, 1.0)
	u.draw_rect(Rect2(bx, oben, 10, unten - oben), Color(TERMINAL_FARBE, 0.15))
	for i in etagen_y.size():
		var yy := unten - (etagen_y[i] - unten_y) / gesamt * (unten - oben)
		u.draw_line(Vector2(bx - 6, yy), Vector2(bx + 16, yy), Color(TERMINAL_FARBE, 0.45), 1.0)
	var my := unten - clampf(hoehe / gesamt, 0.0, 1.0) * (unten - oben)
	u.draw_rect(Rect2(bx - 12, my - 5, 34, 10), TERMINAL_AKZENT)


func _kollision(eltern: Node3D, pos: Vector3, groesse: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = groesse
	cs.shape = bs
	cs.position = pos
	eltern.add_child(cs)


## Tuer an Haltestelle `oben` oeffnen oder schliessen. `sofort` ueberspringt die Animation.
func _tuer_schalten(idx: int, offen: bool, animiert := true) -> void:
	var t: Array = _tueren[idx]
	var knoten: Node3D = t[0]
	var cs: CollisionShape3D = t[1]
	cs.set_deferred("disabled", offen)
	var ziel := TUER_OFFEN_ANTEIL if offen else 1.0
	if animiert:
		create_tween().tween_property(knoten, "scale:y", ziel, TUER_ZEIT)
	else:
		knoten.scale.y = ziel


func _process(delta: float) -> void:
	if _spieler == null or not is_instance_valid(_spieler):
		_spieler = get_tree().get_first_node_in_group("spieler") as Node3D
		return
	_terminal_zeit += delta
	if _terminal_zeit >= TERMINAL_TAKT:
		_terminal_zeit = 0.0
		var nah := _spieler.global_position.distance_to(_kabine.global_position) < TERMINAL_AKTIV_BIS
		_terminal_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if nah else SubViewport.UPDATE_DISABLED
		if nah:
			_terminal_ui.queue_redraw()
	var station := _station_in_naehe()
	var drin := _in_kabine()
	var zeigen := (station >= 0 or drin) and not _faehrt and not Dialog.aktiv and _wahl == null
	_hinweis.visible = zeigen
	if zeigen:
		if drin:
			_hinweis.global_position = _kabine.global_position + Vector3(0, 2.6, 0)
			_hinweis.text = "E: ETAGE WÄHLEN"
		else:
			_hinweis.global_position = _haltestelle_global(station) + Vector3(0, HINWEIS_HOEHE, schacht_groesse * 0.5 + 0.8)
			_hinweis.text = "E: ETAGE WÄHLEN" if _kabine_ist_an(station) else "E: AUFZUG RUFEN"


## Spieler steht in der Kabine (egal in welcher Hoehe).
func _in_kabine() -> bool:
	var l := _kabine.to_local(_spieler.global_position)
	var h := _kabinen_breite * 0.5
	return absf(l.x) < h and absf(l.z) < h and l.y > -1.0 and l.y < KABINE_HOEHE


func _unhandled_input(event: InputEvent) -> void:
	if _faehrt or _wahl != null or Dialog.aktiv or not event.is_action_pressed("interagieren") or event.is_echo():
		return
	if _spieler == null:
		return
	var station := _station_in_naehe()
	if station < 0 and not _in_kabine():
		return
	get_viewport().set_input_as_handled()
	if station >= 0 and not _kabine_ist_an(station) and not _in_kabine():
		fahren_zu(station)  # Ruf: Kabine kommt zur Etage des Spielers
		return
	_wahl_oeffnen()


func _letzte() -> int:
	return maxi(etagen_y.size() - 1, 1)


func _wahl_oeffnen() -> void:
	_wahl = WAHL.new()
	_wahl.set("namen", etagen_name)
	_wahl.set("aktuell", _stand)
	_wahl.connect("gewaehlt", fahren_zu)
	_wahl.tree_exited.connect(func() -> void: _wahl = null)
	get_tree().root.add_child(_wahl)


## Faehrt zur oberen (true) oder unteren (false) Haltestelle. Auch von aussen aufrufbar (Tests).
func fahren(nach_oben: bool) -> void:
	fahren_zu(_letzte() if nach_oben else 0)


## Faehrt zur Etage mit dem Index `idx` (0 = Lobby, letzte = HQ).
func fahren_zu(idx: int) -> void:
	if _faehrt or idx == _stand or idx < 0 or idx >= etagen_y.size():
		return
	_faehrt = true
	_ziel = idx
	_kabine_ziel_oben = idx > _stand
	_tuer_schalten(_stand, false)
	await get_tree().create_timer(TUER_ZEIT).timeout
	_schranke.set_deferred("disabled", false)
	fahrt_gestartet.emit(_kabine_ziel_oben)
	var ziel_y := etagen_y[idx] - BODEN_DICKE * 0.5
	var strecke := absf(_kabine.position.y - ziel_y)
	var dauer := maxf(strecke / fahrtempo, FAHRT_MIN_ZEIT)
	var tw := create_tween()
	tw.tween_property(_kabine, "position:y", ziel_y, dauer).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	_stand = idx
	_oben = idx == _letzte()
	_schranke.set_deferred("disabled", true)
	_tuer_schalten(idx, true)
	await get_tree().create_timer(TUER_ZEIT).timeout
	_faehrt = false
	angekommen.emit(_oben)


func ist_oben() -> bool:
	return _oben


## Liefert den Index der Etage, vor deren Aufzugstuer der Spieler steht, sonst -1.
func _station_in_naehe() -> int:
	var d := _spieler.global_position - global_position
	# Nur vor dem Schacht (+z) zaehlt, damit man nicht von der Rueckseite ruft
	var vorn := Vector2(d.x, d.z - schacht_groesse * 0.5)
	if vorn.length() > STATION_REICHWEITE or d.z < -schacht_groesse * 0.5:
		return -1
	for i in etagen_y.size():
		if absf(_spieler.global_position.y - (global_position.y + etagen_y[i])) < STATION_HOEHE:
			return i
	return -1


func _kabine_ist_an(station: int) -> bool:
	return _stand == station and not _faehrt


func _haltestelle_global(station: int) -> Vector3:
	return global_position + Vector3(0, _etage_y(station), 0)
