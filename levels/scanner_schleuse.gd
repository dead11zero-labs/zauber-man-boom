extends Node3D
## Mensch-Maschinen-Scanner im Foyer des Zauber-Towers: Torbogen mit Scanstrahl und zwei Schiebetueren in einer
## Gasse von GASSE_BREITE Metern. Die Tueren sind im Ruhezustand zu (amber, "BEREIT").
## Wer in den Scanbereich tritt, wird nach Gruppen geprueft:
##   Gruppe "spieler" (Zauber-Man) und "mensch" (Buerger): gruen, die Tueren fahren auf.
##   Gruppe "maschine" (Synth-Bots, Mechy, Drohnen und alle anderen Gegner): rot, Alarmleuchte, Tueren bleiben zu.
## Steht gerade ein Berechtigter im Durchgang, schliesst eine Maschine in der Naehe die Tueren nicht.
## Ursprung: Mitte der Gasse am Boden, Durchgang entlang z (Zugang von +z, Aufzug bei -z).
## Signale: zutritt_gewaehrt(koerper), zutritt_verweigert(koerper). Keine exportierten Variablen, kein harter Pfad.

signal zutritt_gewaehrt(koerper: Node3D)
signal zutritt_verweigert(koerper: Node3D)

const GRUPPE_ERLAUBT: Array[StringName] = [&"spieler", &"mensch"]
const GRUPPE_MASCHINE: StringName = &"maschine"
const GASSE_BREITE := 3.0
const BOGEN_HOEHE := 3.2
const BOGEN_TIEFE := 1.2
const PFOSTEN_DICKE := 0.3
const TUER_HOEHE := 2.4
const TUER_DICKE := 0.12
const TUER_ZEIT := 0.35
const SCAN_TIEFE := 6.0          ## Tiefe der Pruefzone (Mitte = Tuerebene)
const DURCHGANG_ZONE := 1.4      ## Halbe Tiefe, in der eine Tuer wegen einer Maschine nicht zufahren darf
const LABEL_HOEHE := 3.9
const LABEL_PIXEL := 0.012
const FARBE_BEREIT := Color(1.0, 0.72, 0.15)
const FARBE_OK := Color(0.2, 1.0, 0.45)
const FARBE_NEIN := Color(1.0, 0.15, 0.1)
const SCAN_TEMPO := 1.4          ## Strahl-Durchlaeufe pro Sekunde

enum Zustand { BEREIT, ERLAUBT, VERWEIGERT }

var _zone: Area3D
var _tueren: Array[Node3D] = []
var _tuer_kol: Array[CollisionShape3D] = []
var _strahl: MeshInstance3D
var _lampe: OmniLight3D
var _anzeige: Label3D
var _mat_leuchte: StandardMaterial3D
var _zustand := Zustand.BEREIT
var _offen := false
var _zeit := 0.0
var _stahl: StandardMaterial3D


func _ready() -> void:
	name = "ScannerSchleuse"
	_stahl = StandardMaterial3D.new()
	_stahl.albedo_color = Color(0.55, 0.57, 0.62)
	_stahl.metallic = 0.9
	_stahl.roughness = 0.25
	_mat_leuchte = StandardMaterial3D.new()
	_mat_leuchte.emission_enabled = true
	_mat_leuchte.albedo_color = FARBE_BEREIT
	_mat_leuchte.emission = FARBE_BEREIT
	_mat_leuchte.emission_energy_multiplier = 2.0
	_mat_leuchte.disable_ambient_light = true
	_bogen_bauen()
	_tueren_bauen()
	_zone_bauen()
	_anzeige_bauen()
	_farbe_setzen(FARBE_BEREIT)


func _process(delta: float) -> void:
	_zeit += delta
	# Scanstrahl pendelt ueber die Torhoehe, solange jemand geprueft wird
	var aktiv := _zustand != Zustand.BEREIT
	_strahl.visible = aktiv
	if aktiv:
		_strahl.position.y = 0.2 + (sin(_zeit * TAU * SCAN_TEMPO) * 0.5 + 0.5) * (BOGEN_HOEHE - 0.4)
	# Alarm: rotes Blinken
	if _zustand == Zustand.VERWEIGERT:
		_lampe.light_energy = 1.0 + 2.0 * (sin(_zeit * 14.0) * 0.5 + 0.5)
	_pruefen()


## Pfosten, Sturz und Leuchtleisten.
func _bogen_bauen() -> void:
	var aussen := GASSE_BREITE * 0.5 + PFOSTEN_DICKE * 0.5
	for sx in [-1.0, 1.0]:
		_teil(Vector3(sx * aussen, BOGEN_HOEHE * 0.5, 0), Vector3(PFOSTEN_DICKE, BOGEN_HOEHE, BOGEN_TIEFE), _stahl, true)
		_teil(Vector3(sx * (GASSE_BREITE * 0.5 - 0.005), BOGEN_HOEHE * 0.5, 0), Vector3(0.02, BOGEN_HOEHE - 0.4, BOGEN_TIEFE - 0.3), _mat_leuchte, false)
	_teil(Vector3(0, BOGEN_HOEHE + 0.2, 0), Vector3(GASSE_BREITE + PFOSTEN_DICKE * 2.0, 0.4, BOGEN_TIEFE), _stahl, true)
	_strahl = _teil(Vector3(0, 1.0, 0), Vector3(GASSE_BREITE, 0.03, BOGEN_TIEFE - 0.2), _mat_leuchte, false)
	_strahl.visible = false
	_lampe = OmniLight3D.new()
	_lampe.position = Vector3(0, BOGEN_HOEHE - 0.2, 0)
	_lampe.omni_range = 7.0
	_lampe.light_energy = 1.2
	_lampe.shadow_enabled = false
	add_child(_lampe)


## Zwei Schiebetuer-Fluegel (Glas mit Leuchtkante). Offen: in die Pfosten eingefahren.
func _tueren_bauen() -> void:
	var glas := StandardMaterial3D.new()
	glas.albedo_color = Color(0.7, 0.9, 1.0, 0.35)
	glas.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glas.roughness = 0.05
	var halb := GASSE_BREITE * 0.5
	for sx in [-1.0, 1.0]:
		var t := Node3D.new()
		t.position = Vector3(sx * halb * 0.5, 0, 0)
		add_child(t)
		_teil(Vector3(0, TUER_HOEHE * 0.5, 0), Vector3(halb, TUER_HOEHE, TUER_DICKE), glas, false, t)
		_teil(Vector3(-sx * halb * 0.5, TUER_HOEHE * 0.5, 0), Vector3(0.06, TUER_HOEHE, TUER_DICKE + 0.04), _mat_leuchte, false, t)
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(halb, TUER_HOEHE, TUER_DICKE)
		cs.shape = sh
		cs.position = Vector3(0, TUER_HOEHE * 0.5, 0)
		body.add_child(cs)
		t.add_child(body)
		_tueren.append(t)
		_tuer_kol.append(cs)


func _zone_bauen() -> void:
	_zone = Area3D.new()
	_zone.monitoring = true
	_zone.monitorable = false
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(GASSE_BREITE + 1.0, 3.0, SCAN_TIEFE)
	cs.shape = sh
	cs.position = Vector3(0, 1.5, 0)
	_zone.add_child(cs)
	add_child(_zone)


## Statusanzeige ueber dem Sturz (Billboard, zeigt immer zum Betrachter).
func _anzeige_bauen() -> void:
	_anzeige = Label3D.new()
	_anzeige.font_size = 48
	_anzeige.pixel_size = LABEL_PIXEL
	_anzeige.shaded = false
	_anzeige.position = Vector3(0, LABEL_HOEHE, 0)
	_anzeige.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_anzeige)
	_text_setzen("MENSCH-MASCHINEN-SCANNER", FARBE_BEREIT)


## Pruefung jeden Frame: Wer ist in der Zone, wer ist erlaubt, wer eine Maschine?
func _pruefen() -> void:
	var erlaubt: Node3D = null
	var maschine: Node3D = null
	var erlaubt_im_durchgang := false
	for k in _zone.get_overlapping_bodies():
		var kn := k as Node3D
		if kn == null:
			continue
		var im_durchgang := absf(to_local(kn.global_position).z) < DURCHGANG_ZONE
		if _ist_erlaubt(kn):
			erlaubt = kn
			erlaubt_im_durchgang = erlaubt_im_durchgang or im_durchgang
		elif kn.is_in_group(GRUPPE_MASCHINE):
			maschine = kn
	var neu := Zustand.BEREIT
	if erlaubt != null and (maschine == null or erlaubt_im_durchgang or _offen):
		neu = Zustand.ERLAUBT
	elif maschine != null:
		neu = Zustand.VERWEIGERT
	if neu == _zustand:
		return
	_zustand = neu
	match neu:
		Zustand.ERLAUBT:
			_text_setzen("ZUTRITT GEWAEHRT", FARBE_OK)
			_farbe_setzen(FARBE_OK)
			_tueren_schalten(true)
			zutritt_gewaehrt.emit(erlaubt)
		Zustand.VERWEIGERT:
			_text_setzen("MASCHINE ERKANNT - KEIN ZUTRITT", FARBE_NEIN)
			_farbe_setzen(FARBE_NEIN)
			_tueren_schalten(false)
			zutritt_verweigert.emit(maschine)
		_:
			_text_setzen("MENSCH-MASCHINEN-SCANNER", FARBE_BEREIT)
			_farbe_setzen(FARBE_BEREIT)
			_tueren_schalten(false)


func _ist_erlaubt(k: Node) -> bool:
	if k.is_in_group(GRUPPE_MASCHINE):
		return false
	for g in GRUPPE_ERLAUBT:
		if k.is_in_group(g):
			return true
	return false


func _tueren_schalten(auf: bool) -> void:
	_offen = auf
	var halb := GASSE_BREITE * 0.5
	for i in _tueren.size():
		var sx := -1.0 if i == 0 else 1.0
		# zu: Mitte der Haelfte; auf: komplett in den Pfosten (aussen)
		var ziel_x := sx * (halb * 1.5 if auf else halb * 0.5)
		var tw := create_tween()
		tw.tween_property(_tueren[i], "position:x", ziel_x, TUER_ZEIT)
		_tuer_kol[i].set_deferred("disabled", auf)


func _farbe_setzen(f: Color) -> void:
	_mat_leuchte.albedo_color = f
	_mat_leuchte.emission = f
	_lampe.light_color = f
	_lampe.light_energy = 1.2


func _text_setzen(t: String, f: Color) -> void:
	_anzeige.text = t
	_anzeige.modulate = f


func _teil(pos: Vector3, g: Vector3, mat: Material, kol: bool, eltern: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = g
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	(eltern if eltern != null else self).add_child(mi)
	if kol:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = g
		cs.shape = sh
		sb.add_child(cs)
		mi.add_child(sb)
	return mi
