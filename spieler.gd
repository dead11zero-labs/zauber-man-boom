extends CharacterBody3D

const SPEED = 12.0
const TURN_SPEED = 3.0
const GRAVITY = 30.0
const SPRUNG_KRAFT = 13.0
const ZAUBER_PAUSE = 0.4
## Ladeschuss: Taste halten. Nach LADE_ZEIT ist die Ladung voll; kurzer Druck feuert einen normalen Blitz.
const LADE_ZEIT := 1.0
const LADE_MIN := 0.25  # unter dieser Haltezeit zaehlt es als normaler Schuss
## Zielhilfe: Ziele der Gruppe "blitz_ziel" im Kegel werden leicht angepeilt
const ZIEL_WINKEL := deg_to_rad(9.0)
const ZIEL_REICHWEITE := 45.0
const ZIEL_REICHWEITE_LADUNG := 120.0
## Schwebemodus: Steiggeschwindigkeit bei gehaltener Sprungtaste und Beschleunigung
const SCHWEBE_STEIGEN = 9.0
const SCHWEBE_BESCHLEUNIGUNG = 30.0
## Maus-Umsehen
const MAUS_EMPFINDLICHKEIT = 0.003
## Gamepad: Umsehen mit dem rechten Stick (rad/s bei voller Auslenkung)
const STICK_DREHEN = 2.6
const STICK_NICKEN = 1.6
## Touch: Umsehen per Wischen (rad je Bildpunkt)
const TOUCH_EMPFINDLICHKEIT = 0.005
const NICK_MIN = deg_to_rad(-70.0)
const NICK_MAX = deg_to_rad(45.0)
## Zeitpunkt in der Sprung-Animation, an dem die Fuesse den Boden verlassen
const SPRUNG_ANIM_ABSPRUNG = 1.3
const SPRUNG_ANIM_FALL = 1.5
## Kampf (Meilenstein 4): Dash (Aktion "dash"), Unverwundbarkeit, Rueckstoss, Respawn am Checkpoint
const DASH_TEMPO := 34.0
const DASH_DAUER := 0.18
const DASH_PAUSE := 0.7
const DASH_SCHUTZ := 0.4  # Unverwundbarkeit ab Dash-Beginn
const TREFFER_SCHUTZ := 1.2  # Unverwundbarkeit nach einem Treffer (Figur blinkt)
const BLINK_TEMPO := 14.0
const RUECKSTOSS := 11.0
const RUECKSTOSS_HOCH := 5.0
const RUECKSTOSS_ABBAU := 30.0
const RESPAWN_PAUSE := 1.6
const RESPAWN_HOEHE := 0.3
## Heilung: jeder eingesammelte Mana-Kern gibt so viele Herzen zurueck
const HEILUNG_PRO_KERN := 1
const BLITZ_SKRIPT := preload("res://blitz.gd")
## Ego-Perspektive (Aktion "perspektive"): Kamera auf Augenhoehe, Koerper aus, rechter Arm als Viewmodel
const EGO_ARM := preload("res://characters/ego_arm.gd")
const EGO_AUGENHOEHE := 1.65
const EGO_BLITZ_VERSATZ := Vector3(0.22, -0.18, -0.9)   ## Blitzstart vor der Hand (Kameraraum)
## Schwimmen (characters/schwimmen.gd): in Wasserzonen, sobald die Brust unter dem Wasserspiegel liegt
const SCHWIMMEN := preload("res://characters/schwimmen.gd")
const SCHWIMM_BRUST := 1.2        ## Brusthoehe ueber den Fuessen
const SCHWIMM_LAGE := 1.35        ## so tief liegen die Fuesse beim Treiben unter dem Wasserspiegel
const SCHWIMM_TEMPO := 5.5
const TAUCH_TEMPO := 3.5
const AUFTRIEB := 2.5
const WASSER_BREMSE := 8.0
const AUSSTIEG_SPRUNG := 9.0      ## Sprung aus dem Wasser an der Oberflaeche
const TAUCH_NEIGUNG := 0.5

signal kristalle_geaendert(anzahl: int, gesamt: int)
## Ladeanteil 0..1 waehrend die Zaubertaste gehalten wird (HUD-Balken)
signal ladung_geaendert(anteil: float)

var kristalle := 0
var kristalle_gesamt := 0
var blitz_szene = preload("res://blitz.tscn")
var _zauber_timer := 0.0
var _ladezeit := 0.0
var _laedt := false
var _lade_licht: OmniLight3D
var _sprung_aktiv := false
var _luftzeit := 0.0
var _sprung_name := ""
var _schwebt := false
var _klebt := 0.0
var _nick_standard := 0.0
var _dash_zeit := 0.0
var _dash_pause := 0.0
var _dash_richtung := Vector3.ZERO
var _schutz := 0.0  # Dash-Unverwundbarkeit
var _unverwundbar := 0.0  # nach Treffer
var _rueckstoss := Vector3.ZERO
var _tot := false
var _start_pos := Vector3.ZERO
## Eingabe-Sperren (Meilenstein 5): Dialog, Shop, Journal melden sich ueber EventBus.eingabe_gesperrt
var _sperren: Dictionary = {}
## Kamera steckt dicht an der Figur (Wand im Ruecken): Modell ausblenden, sonst schaut man hinein
var _kamera_nah := false
var _ego := false
var _schwimmen: Node3D
var _schwimmt := false
var _ego_arm: Node3D
var _arm_pos_dritte := Vector3.ZERO
var _arm_laenge_dritte := 3.2

@onready var hand: Marker3D = $Hand
@onready var modell_lauf: Node3D = $Modell/Laufen
@onready var modell_stehen: Node3D = $Modell/Stehen
@onready var modell_sprung: Node3D = $Modell/Springen
@onready var anim: AnimationPlayer = $Modell/Laufen/AnimationPlayer
@onready var kamera_arm: Node3D = $KameraArm
@onready var anim_sprung: AnimationPlayer = $Modell/Springen/AnimationPlayer

func _ready():
	add_to_group("spieler")
	kristalle = GameState.mana_kerne
	if SaveSystem.hat_position:
		global_position = SaveSystem.position + Vector3(0, 0.3, 0)
		rotation.y = SaveSystem.blick
		SaveSystem.hat_position = false
	_start_pos = global_position
	EventBus.eingabe_gesperrt.connect(_sperre_setzen)
	EventBus.upgrade_gekauft.connect(func(_i: String, _s: int) -> void: kristalle = GameState.mana_kerne; kristalle_geaendert.emit(kristalle, kristalle_gesamt))
	EventBus.mana_kern_gesammelt.connect(func(_n: int) -> void: GameState.heilen(HEILUNG_PRO_KERN))
	_nick_standard = kamera_arm.rotation.x
	_arm_pos_dritte = kamera_arm.position
	_arm_laenge_dritte = kamera_arm.get("laenge")
	_schwimmen = Node3D.new()
	_schwimmen.set_script(SCHWIMMEN)
	_schwimmen.visible = false
	$Modell.add_child(_schwimmen)
	_ego_arm = Node3D.new()
	_ego_arm.set_script(EGO_ARM)
	_ego_arm.visible = false
	kamera_arm.get_node("Kamera").add_child(_ego_arm)
	kamera_arm.connect("naehe_geaendert", func(nah: bool) -> void: _kamera_nah = nah)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Eingabe.ist_touch() else Input.MOUSE_MODE_CAPTURED
	Eingabe.geraet_geaendert.connect(_geraet_geaendert)
	var hud := CanvasLayer.new()
	hud.set_script(preload("res://hud.gd"))
	add_child(hud)
	anim.get_animation("Running").loop_mode = Animation.LOOP_LINEAR
	anim.play("Running")
	_sprung_name = anim_sprung.get_animation_list()[0]
	_root_motion_entfernen(anim_sprung.get_animation(_sprung_name))

## Die Sprung-Animation wandert die Huefte nach vorn. Das macht die Spielfigur selbst, daher raus damit.
func _root_motion_entfernen(a: Animation) -> void:
	for t in a.get_track_count():
		if a.track_get_type(t) == Animation.TYPE_POSITION_3D and str(a.track_get_path(t)).ends_with("Hips"):
			var v0: Vector3 = a.track_get_key_value(t, 0)
			for k in a.track_get_key_count(t):
				var v: Vector3 = a.track_get_key_value(t, k)
				a.track_set_key_value(t, k, Vector3(v0.x, v.y, v0.z))

func ist_gesperrt() -> bool:
	return not _sperren.is_empty()

func _sperre_setzen(grund: String, gesperrt: bool) -> void:
	if gesperrt:
		_sperren[grund] = true
		# Laufende Aufladung abbrechen, damit beim Sperren kein Blitz losgeht
		_laedt = false
		_ladezeit = 0.0
		ladung_geaendert.emit(0.0)
		_lade_licht_setzen(0.0)
	else:
		_sperren.erase(grund)
		_zauber_timer = ZAUBER_PAUSE

## Ladezeit des Ladeschusses inkl. Upgrade "ladegeschwindigkeit" (Default LADE_ZEIT bleibt unveraendert)
func _lade_zeit() -> float:
	return LADE_ZEIT / (1.0 + GameState.upgrade_bonus("ladegeschwindigkeit"))

## Vom Schleim des Gurken-Monsters getroffen: kurz verlangsamt (nicht waehrend des Dash)
func schleim_treffer() -> void:
	if _schutz > 0.0 or _tot:
		return
	_klebt = 3.0

## Schaden von Gegnern/Projektilen. `von` = Herkunft fuer den Rueckstoss. true = Treffer zaehlt.
func schaden_nehmen(menge: int, von: Vector3 = Vector3.INF) -> bool:
	if _tot or ist_unverwundbar():
		return false
	_unverwundbar = TREFFER_SCHUTZ
	if von != Vector3.INF:
		var weg := global_position - von
		weg.y = 0.0
		_rueckstoss = weg.normalized() * RUECKSTOSS if weg.length() > 0.01 else Vector3.ZERO
		velocity.y = RUECKSTOSS_HOCH
	if GameState.schaden(menge) <= 0:
		_sterben()
	return true

func ist_unverwundbar() -> bool:
	return _schutz > 0.0 or _unverwundbar > 0.0

## Herzen leer: Kurzschluss, kurze Pause, dann zurueck zum letzten Checkpoint (Sammelobjekte bleiben).
func _sterben() -> void:
	_tot = true
	_laedt = false
	_ladezeit = 0.0
	ladung_geaendert.emit(0.0)
	_lade_licht_setzen(0.0)
	BLITZ_SKRIPT._treffer_effekt(get_parent(), global_position + Vector3.UP, 1.0)
	EventBus.spieler_gestorben.emit()
	await get_tree().create_timer(RESPAWN_PAUSE).timeout
	_wiederbeleben()

func _wiederbeleben() -> void:
	var ziel := GameState.checkpoint_pos if GameState.hat_checkpoint() else _start_pos
	global_position = ziel + Vector3.UP * RESPAWN_HOEHE
	velocity = Vector3.ZERO
	_rueckstoss = Vector3.ZERO
	_klebt = 0.0
	_schwebt = false
	GameState.heilen(GameState.MAX_HERZEN)
	_unverwundbar = TREFFER_SCHUTZ
	_tot = false
	$Modell.visible = true
	EventBus.spieler_wiederbelebt.emit()

func _dash_starten(vorwaerts: float) -> void:
	_dash_zeit = DASH_DAUER
	_dash_pause = DASH_PAUSE
	_schutz = DASH_SCHUTZ
	_dash_richtung = -transform.basis.z * (-1.0 if vorwaerts < 0.0 else 1.0)
	BLITZ_SKRIPT._treffer_effekt(get_parent(), global_position + Vector3.UP, 0.0)

func kristall_gesammelt() -> void:
	kristalle += 1
	kristalle_geaendert.emit(kristalle, kristalle_gesamt)

## Touch braucht einen sichtbaren Zeiger (Overlay-Knoepfe), Maus und Pad fangen ihn wieder ein.
func _geraet_geaendert(geraet: int) -> void:
	if geraet == Eingabe.Geraet.TOUCH:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif geraet == Eingabe.Geraet.PAD and not ist_gesperrt():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if Eingabe.ist_touch():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not ist_gesperrt():
		# Links/rechts dreht die Figur, hoch/runter neigt die Kamera
		rotate_y(-event.relative.x * MAUS_EMPFINDLICHKEIT)
		kamera_arm.rotation.x = clampf(kamera_arm.rotation.x - event.relative.y * MAUS_EMPFINDLICHKEIT, NICK_MIN, NICK_MAX)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		# Der Klick zum Einfangen der Maus loest keinen Blitz aus
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_zauber_timer = ZAUBER_PAUSE
	elif event.is_action_pressed("perspektive") and not ist_gesperrt():
		ego_setzen(not _ego)
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

## Wechselt zwischen Schulterkamera und Ego-Sicht.
func ego_setzen(an: bool) -> void:
	_ego = an
	kamera_arm.set("laenge", 0.0 if an else _arm_laenge_dritte)
	kamera_arm.set("abstand", 0.0 if an else _arm_laenge_dritte)
	kamera_arm.position = Vector3(0.0, EGO_AUGENHOEHE, 0.0) if an else _arm_pos_dritte
	kamera_arm.rotation.x = 0.0 if an else _nick_standard
	_ego_arm.visible = an

func ist_ego() -> bool:
	return _ego

func _sprung_starten(ab_zeit: float) -> void:
	_sprung_aktiv = true
	anim_sprung.play(_sprung_name)
	anim_sprung.seek(ab_zeit, true)

func _physics_process(delta):
	_schutz = maxf(_schutz - delta, 0.0)
	_unverwundbar = maxf(_unverwundbar - delta, 0.0)
	_dash_pause = maxf(_dash_pause - delta, 0.0)
	$Modell.visible = not _tot and not _kamera_nah and not _ego and (_unverwundbar <= 0.0 or fmod(_unverwundbar * BLINK_TEMPO, 1.0) < 0.5)
	if _tot:
		velocity = Vector3.ZERO
		return
	var gesperrt := ist_gesperrt()
	var lauf := Vector2.ZERO if gesperrt else Eingabe.bewegung()
	var vorwaerts: float = lauf.y
	rotate_y(-lauf.x * TURN_SPEED * delta)
	# Gamepad: rechter Stick sieht sich um (Maus bleibt wie gehabt), Touch: Wischen auf der rechten Seite
	var blick := Vector2.ZERO if gesperrt else Eingabe.blick()
	var wisch := Eingabe.touch_blick_nehmen() * TOUCH_EMPFINDLICHKEIT
	if gesperrt:
		wisch = Vector2.ZERO
	if blick != Vector2.ZERO or wisch != Vector2.ZERO:
		rotate_y(-blick.x * STICK_DREHEN * delta - wisch.x)
		kamera_arm.rotation.x = clampf(kamera_arm.rotation.x - blick.y * STICK_NICKEN * delta - wisch.y, NICK_MIN, NICK_MAX)
	_klebt = maxf(_klebt - delta, 0.0)
	_schwimmen.call("unterwasser_pruefen", (kamera_arm.get_node("Kamera") as Node3D).global_position)
	var wasser: float = _schwimmen.call("wasser_bei", global_position + Vector3.UP * SCHWIMM_BRUST)
	_schwimmt = not is_nan(wasser) and global_position.y + SCHWIMM_BRUST < wasser
	if _schwimmt:
		_schwimm_physik(delta, vorwaerts, wasser, gesperrt)
		_zauber_verarbeiten(delta, gesperrt)
		return
	_schwimmen.visible = false
	var richtung = -transform.basis.z * vorwaerts * SPEED * (0.4 if _klebt > 0.0 else 1.0)
	if not gesperrt and Input.is_action_just_pressed("dash") and _dash_pause <= 0.0:
		_dash_starten(vorwaerts)
	if _dash_zeit > 0.0:
		_dash_zeit -= delta
		richtung = _dash_richtung * DASH_TEMPO
	_rueckstoss = _rueckstoss.move_toward(Vector3.ZERO, RUECKSTOSS_ABBAU * delta)
	velocity.x = richtung.x + _rueckstoss.x
	velocity.z = richtung.z + _rueckstoss.z

	if is_on_floor():
		_schwebt = false
		if velocity.y <= 0.0:
			velocity.y = 0.0
		_luftzeit = 0.0
		if not gesperrt and Input.is_action_just_pressed("springen"):
			velocity.y = SPRUNG_KRAFT
			_sprung_starten(SPRUNG_ANIM_ABSPRUNG)
	else:
		_luftzeit += delta
		if not gesperrt and Input.is_action_just_pressed("springen"):
			# Doppelsprung: Schwebemodus an, beim naechsten Doppelsprung wieder aus
			_schwebt = not _schwebt
			if _schwebt:
				velocity.y = 0.0
				_sprung_starten(SPRUNG_ANIM_FALL)
				anim_sprung.pause()
			else:
				anim_sprung.play()
		if _schwebt:
			var ziel_y = SCHWEBE_STEIGEN if Input.is_action_pressed("springen") and not gesperrt else 0.0
			velocity.y = move_toward(velocity.y, ziel_y, SCHWEBE_BESCHLEUNIGUNG * delta)
		else:
			velocity.y -= GRAVITY * delta
			# Abgestuerzt statt gesprungen: Fall-Pose zeigen
			if not _sprung_aktiv and _luftzeit > 0.3:
				_sprung_starten(SPRUNG_ANIM_FALL)
	move_and_slide()

	var laeuft := absf(vorwaerts) > 0.05
	# Sprung-Animation beenden: gelandet und (Animation fertig oder Spieler laeuft los)
	if _sprung_aktiv and is_on_floor() and _luftzeit == 0.0:
		if not anim_sprung.is_playing() or (laeuft and anim_sprung.current_animation_position > 2.3):
			_sprung_aktiv = false
	modell_sprung.visible = _sprung_aktiv
	modell_lauf.visible = laeuft and not _sprung_aktiv
	modell_stehen.visible = not laeuft and not _sprung_aktiv
	anim.speed_scale = signf(vorwaerts) * maxf(absf(vorwaerts), 0.4) if laeuft else 1.0
	if _ego:
		_ego_arm.call("wippen_setzen", absf(vorwaerts) if is_on_floor() else 0.0)

	_zauber_verarbeiten(delta, gesperrt)


## Im Wasser: Vortrieb, Auftrieb bis zur Treibhoehe, Tauchen (Dash) und Auftauchen (Sprung), Kraul-Animation.
func _schwimm_physik(delta: float, vorwaerts: float, wasser: float, gesperrt: bool) -> void:
	_schwebt = false
	_sprung_aktiv = false
	_dash_zeit = 0.0
	_luftzeit = 0.0
	var h := -transform.basis.z * vorwaerts * SCHWIMM_TEMPO * (0.4 if _klebt > 0.0 else 1.0)
	_rueckstoss = _rueckstoss.move_toward(Vector3.ZERO, RUECKSTOSS_ABBAU * delta)
	velocity.x = h.x + _rueckstoss.x
	velocity.z = h.z + _rueckstoss.z
	var treib_y := wasser - SCHWIMM_LAGE
	var hoch := 0.0
	if not gesperrt:
		if Input.is_action_pressed("springen"):
			hoch += 1.0
		if Input.is_action_pressed("dash"):
			hoch -= 1.0
	if hoch > 0.0 and Input.is_action_just_pressed("springen") and global_position.y >= treib_y - 0.2:
		velocity.y = AUSSTIEG_SPRUNG
	elif hoch != 0.0:
		velocity.y = move_toward(velocity.y, hoch * TAUCH_TEMPO, WASSER_BREMSE * delta)
	else:
		velocity.y = move_toward(velocity.y, clampf((treib_y - global_position.y) * AUFTRIEB, -TAUCH_TEMPO, TAUCH_TEMPO), WASSER_BREMSE * delta)
	move_and_slide()
	modell_lauf.visible = false
	modell_stehen.visible = false
	modell_sprung.visible = false
	_schwimmen.visible = true
	_schwimmen.call("pose", delta, absf(vorwaerts), -velocity.y / TAUCH_TEMPO * TAUCH_NEIGUNG)
	if _ego:
		_ego_arm.call("wippen_setzen", absf(vorwaerts) * 0.6)


func ist_am_schwimmen() -> bool:
	return _schwimmt


## Zaubertaste: Laden bei gehaltener Taste, Blitz beim Loslassen.
func _zauber_verarbeiten(delta: float, gesperrt: bool) -> void:
	_zauber_timer -= delta
	var maus_schuss := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var zauber_gehalten := (Input.is_action_pressed("zaubern") or maus_schuss) and not gesperrt
	var lade_zeit := _lade_zeit()
	if zauber_gehalten and _zauber_timer <= 0.0:
		_laedt = true
		_ladezeit = minf(_ladezeit + delta, lade_zeit)
		ladung_geaendert.emit(_ladezeit / lade_zeit if _ladezeit >= LADE_MIN else 0.0)
		_lade_licht_setzen(_ladezeit / lade_zeit if _ladezeit >= LADE_MIN else 0.0)
	elif _laedt:
		# Taste losgelassen: feuern
		var anteil := _ladezeit / lade_zeit if _ladezeit >= LADE_MIN else 0.0
		_laedt = false
		_ladezeit = 0.0
		ladung_geaendert.emit(0.0)
		_lade_licht_setzen(0.0)
		_zauber_timer = ZAUBER_PAUSE
		_blitz_schiessen(anteil)

func _lade_licht_setzen(anteil: float) -> void:
	if _ego_arm != null:
		_ego_arm.call("ladung_setzen", anteil)
	if anteil <= 0.0:
		if _lade_licht != null:
			_lade_licht.visible = false
		return
	if _lade_licht == null:
		_lade_licht = OmniLight3D.new()
		_lade_licht.light_color = Color(0.4, 0.85, 1.0)
		_lade_licht.omni_range = 5.0
		hand.add_child(_lade_licht)
	_lade_licht.visible = true
	_lade_licht.light_energy = 1.0 + 6.0 * anteil * randf_range(0.7, 1.0)

## Naechstes Ziel im Zielkegel um die Blickrichtung `richtung`, oder null.
func _ziel_finden(von: Vector3, richtung: Vector3, reichweite: float) -> Node3D:
	var bestes: Node3D = null
	var bester_winkel := ZIEL_WINKEL
	for n in get_tree().get_nodes_in_group("blitz_ziel"):
		var z := n as Node3D
		if z == null or not z.is_inside_tree():
			continue
		var p: Vector3 = z.call("ziel_punkt") if z.has_method("ziel_punkt") else z.global_position
		var d := p - von
		if d.length() > reichweite:
			continue
		var w := richtung.angle_to(d)
		if w < bester_winkel:
			bester_winkel = w
			bestes = z
	return bestes

func _blitz_schiessen(ladung := 0.0):
	var blitz = blitz_szene.instantiate()
	blitz.schuetze = self
	blitz.ladung = ladung
	get_parent().add_child(blitz)
	if _ego:
		# Ego-Sicht: aus der rechten Hand, genau in Blickrichtung der Kamera
		var kam: Camera3D = kamera_arm.get_node("Kamera")
		blitz.global_transform = kam.global_transform.translated_local(EGO_BLITZ_VERSATZ)
		_ego_arm.call("zaubern")
	else:
		blitz.global_transform = hand.global_transform
		# Blitz folgt dem Blick nach oben/unten (Standard-Kamerawinkel = waagerecht)
		blitz.rotate_object_local(Vector3.RIGHT, kamera_arm.rotation.x - _nick_standard)
	# Zielhilfe: Blitz leicht auf ein Ziel im Kegel ausrichten
	var reichweite := ZIEL_REICHWEITE_LADUNG if ladung >= 1.0 else ZIEL_REICHWEITE
	reichweite *= 1.0 + GameState.upgrade_bonus("blitzreichweite")
	var ziel := _ziel_finden(blitz.global_position, -blitz.global_basis.z, reichweite)
	if ziel != null:
		var p: Vector3 = ziel.call("ziel_punkt") if ziel.has_method("ziel_punkt") else ziel.global_position
		blitz.look_at(p, Vector3.UP)
