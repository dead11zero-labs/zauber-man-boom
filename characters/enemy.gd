class_name Enemy
extends CharacterBody3D
## Enemy: Basisklasse der Drohnen-Gegner (schwebend, CharacterBody3D im Floating-Modus).
## State Machine: IDLE -> PATROL (um den Heimatpunkt) -> CHASE (Spieler in Erfassung) -> ATTACK -> CHASE ...
##   STUNNED (betaeubt, z. B. Rammdrohne nach Wandtreffer), DEAD (Kurzschluss mit Funken, faellt runter, Beute).
## Treffer: der Zauberblitz ruft blitz_treffer(ladung, blitz) auf -> schaden_nehmen(blitz.schaden).
## Gruppen: "gegner", "blitz_ziel" (Zielhilfe), "minimap_marker" (Meta "mm_farbe").
## Signale: zustand_gewechselt(neu), besiegt(gegner). Global: EventBus.gegner_besiegt(art).
## Exportiert: daten (GegnerDaten-.tres), heim_radius (Patrouillen-Radius um den Startpunkt).
## Unterklassen bauen ihr Modell in _modell_bauen() und ueberschreiben _jagen/_angriff_start/_angriff.
## Hinweis: Unterklassen nutzen `extends "res://characters/enemy.gd"` (class_name ist nur Komfort).

signal zustand_gewechselt(neu: int)
signal besiegt(gegner: Node)

enum Zustand { IDLE, PATROL, CHASE, ATTACK, STUNNED, DEAD }

const GEGNER_DATEN := preload("res://characters/gegner_daten.gd")
const BLITZ := preload("res://blitz.gd")
const MANA_KERN := preload("res://kristall.tscn")

## Boden-Abfrage: Strahl nach unten und Abfrage-Intervall
const BODEN_STRAHL := 40.0
const BODEN_INTERVALL := 0.2
## Hoehe nachfuehren (1/s)
const HOEHE_FEDER := 3.0
const DREH_TEMPO := 6.0
## Patrouille: Ziel erreicht ab diesem Abstand, neues Ziel spaetestens nach so vielen Sekunden
const PATROUILLE_NAH := 1.5
const PATROUILLE_MAX_ZEIT := 8.0
## Treffer-Aufblitzen
const BLITZ_ENERGIE := 9.0
const BLITZ_DAUER := 0.18
## Kurzschluss: Flackern, Fallen, Verschwinden
const TOD_FLACKERN := 8
const TOD_FLACKER_ZEIT := 0.07
const TOD_FALL_ZEIT := 0.5
const TOD_SCHRUMPF_ZEIT := 0.35
const TOD_FUNKEN_KLEIN := 0.15
const TOD_FUNKEN_GROSS := 1.0
const BEUTE_RADIUS := 1.5
const BEUTE_HOEHE := 1.6
## Alle Drohnen erscheinen auf der Minimap rot (gelb = Sammelobjekte, gruen = Gurkenmonster, orange = Iggy)
const MINIMAP_FARBE := Color(1.0, 0.15, 0.25)
## Nach einer Niederlage des Spielers: so lange keine Angriffe (Sekunden), alle kehren auf Patrouille zurueck
const RUHE_NACH_SPIELERTOD := 4.0

@export var daten: GEGNER_DATEN
@export var heim_radius := 14.0

var zustand: int = Zustand.IDLE
var lp := 1.0
var heim := Vector3.ZERO
var _zustand_zeit := 0.0
var _betaeubt_bis := 0.0
var _angriff_timer := 0.0
var _boden_y := 0.0
var _boden_timer := 0.0
var _patrouille_ziel := Vector3.ZERO
var _spieler: Node3D
var _mats: Array[StandardMaterial3D] = []
var _energie: Array[float] = []
var _modell: Node3D
var _form: CollisionShape3D


func _ready() -> void:
	if daten == null:
		daten = _standard_daten()
	lp = daten.max_lp
	heim = global_position
	_boden_y = global_position.y - daten.schwebe_hoehe
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	add_to_group("gegner")
	add_to_group("blitz_ziel")
	add_to_group("minimap_marker")
	set_meta("mm_farbe", MINIMAP_FARBE)
	_modell = Node3D.new()
	add_child(_modell)
	_modell_bauen()
	_spieler = get_tree().get_first_node_in_group("spieler")
	_angriff_timer = daten.angriff_pause
	EventBus.spieler_gestorben.connect(_spieler_besiegt)


## Spieler ist umgefallen: ablassen, heim patrouillieren, kurz Ruhe (kein Respawn-Camping)
func _spieler_besiegt() -> void:
	if zustand == Zustand.DEAD:
		return
	_angriff_timer = RUHE_NACH_SPIELERTOD
	if zustand != Zustand.STUNNED:
		zustand_setzen(Zustand.PATROL)


## Fuer Unterklassen: Standard-Daten, wenn keine gesetzt sind.
func _standard_daten() -> GEGNER_DATEN:
	return GEGNER_DATEN.new()


## Fuer Unterklassen: Meshes an _modell haengen, Kollisionsform mit _form_setzen() anlegen.
func _modell_bauen() -> void:
	_form_setzen(0.6)


func _form_setzen(radius: float) -> void:
	_form = CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = radius
	_form.shape = s
	add_child(_form)


## Neon-Material, das beim Treffer aufblitzt und beim Kurzschluss flackert.
func _neon_mat(farbe: Color, energie: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = farbe.darkened(0.5)
	m.emission_enabled = true
	m.emission = farbe
	m.emission_energy_multiplier = energie
	m.metallic = 0.6
	m.roughness = 0.3
	_mats.append(m)
	_energie.append(energie)
	return m


func _physics_process(delta: float) -> void:
	if zustand == Zustand.DEAD:
		return
	_zustand_zeit += delta
	_angriff_timer -= delta
	if _spieler == null:
		_spieler = get_tree().get_first_node_in_group("spieler")
	_boden_pruefen(delta)
	match zustand:
		Zustand.IDLE:
			_bremsen(delta)
			if _zustand_zeit > daten.idle_dauer:
				zustand_setzen(Zustand.PATROL)
		Zustand.PATROL:
			_patrouillieren(delta)
		Zustand.CHASE:
			if _abstand_spieler() > daten.verlieren:
				zustand_setzen(Zustand.PATROL)
			else:
				_jagen(delta)
				if _angriff_timer <= 0.0 and _abstand_spieler() < daten.angriff_reichweite:
					zustand_setzen(Zustand.ATTACK)
					_angriff_start()
		Zustand.ATTACK:
			_angriff(delta)
		Zustand.STUNNED:
			_bremsen(delta)
			velocity.y = move_toward(velocity.y, -1.0, delta * 4.0)
			if _zustand_zeit >= _betaeubt_bis:
				zustand_setzen(Zustand.CHASE)
	if zustand != Zustand.STUNNED:
		_hoehe_halten(delta)
	move_and_slide()
	_nach_bewegung()


func zustand_setzen(neu: int) -> void:
	if neu == zustand:
		return
	zustand = neu
	_zustand_zeit = 0.0
	if neu == Zustand.PATROL:
		_neues_patrouille_ziel()
	zustand_gewechselt.emit(neu)


func _abstand_spieler() -> float:
	if _spieler == null or not _spieler.is_inside_tree():
		return INF
	return global_position.distance_to(_spieler.global_position)


## Zielpunkt am Spieler (Brusthoehe)
func _spieler_punkt() -> Vector3:
	return _spieler.global_position + Vector3.UP * 1.1


func _spieler_sichtbar() -> bool:
	if _spieler == null or _spieler.get("_tot") == true:
		return false
	return _abstand_spieler() < daten.erfassung


# --- Bewegung ----------------------------------------------------------------

func _boden_pruefen(delta: float) -> void:
	_boden_timer -= delta
	if _boden_timer > 0.0:
		return
	_boden_timer = BODEN_INTERVALL
	var q := PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3.DOWN * BODEN_STRAHL)
	var aus: Array[RID] = [get_rid()]
	if _spieler is CollisionObject3D:
		aus.append((_spieler as CollisionObject3D).get_rid())
	q.exclude = aus
	var t := get_world_3d().direct_space_state.intersect_ray(q)
	if not t.is_empty():
		_boden_y = (t["position"] as Vector3).y


func _hoehe_halten(_delta: float) -> void:
	var ziel_y := _boden_y + daten.schwebe_hoehe
	velocity.y = (ziel_y - global_position.y) * HOEHE_FEDER


## Waagerecht auf `ziel` zusteuern (nur x/z).
func _steuern(ziel: Vector3, tempo: float, delta: float) -> void:
	var d := Vector3(ziel.x - global_position.x, 0.0, ziel.z - global_position.z)
	var soll := d.normalized() * tempo if d.length() > 0.1 else Vector3.ZERO
	_horizontal_auf(soll, delta)


func _horizontal_auf(soll: Vector3, delta: float) -> void:
	var h := Vector3(velocity.x, 0.0, velocity.z).move_toward(Vector3(soll.x, 0.0, soll.z), daten.beschleunigung * delta)
	velocity.x = h.x
	velocity.z = h.z


func _bremsen(delta: float) -> void:
	_horizontal_auf(Vector3.ZERO, delta)


## Dreht sich waagerecht zu `punkt` hin.
func _schauen_zu(punkt: Vector3, delta: float) -> void:
	var d := Vector3(punkt.x - global_position.x, 0.0, punkt.z - global_position.z)
	if d.length() < 0.05:
		return
	rotation.y = lerp_angle(rotation.y, atan2(-d.x, -d.z), minf(DREH_TEMPO * delta, 1.0))


func _neues_patrouille_ziel() -> void:
	var w := randf() * TAU
	var r := randf_range(0.3, 1.0) * heim_radius
	_patrouille_ziel = heim + Vector3(cos(w) * r, 0.0, sin(w) * r)


func _patrouillieren(delta: float) -> void:
	if _spieler_sichtbar():
		zustand_setzen(Zustand.CHASE)
		return
	_steuern(_patrouille_ziel, daten.tempo_patrouille, delta)
	_schauen_zu(_patrouille_ziel, delta)
	var flach := Vector2(_patrouille_ziel.x - global_position.x, _patrouille_ziel.z - global_position.z)
	if flach.length() < PATROUILLE_NAH or _zustand_zeit > PATROUILLE_MAX_ZEIT:
		zustand = Zustand.IDLE
		_zustand_zeit = 0.0
		_neues_patrouille_ziel()
		zustand_gewechselt.emit(zustand)


# --- Fuer Unterklassen -------------------------------------------------------

## Standard: auf den Halteabstand an den Spieler heran.
func _jagen(delta: float) -> void:
	var dist := _abstand_spieler()
	var ziel := _spieler.global_position
	_schauen_zu(ziel, delta)
	if dist > daten.halteabstand:
		_steuern(ziel, daten.tempo_jagd, delta)
	else:
		_bremsen(delta)


func _angriff_start() -> void:
	pass


## Standard: sofort zurueck zur Jagd.
func _angriff(_delta: float) -> void:
	_angriff_beenden()


func _angriff_beenden() -> void:
	_angriff_timer = daten.angriff_pause
	zustand_setzen(Zustand.CHASE)


## Nach move_and_slide (z. B. Kollisionen auswerten).
func _nach_bewegung() -> void:
	pass


# --- Treffer, Betaeubung, Tod ------------------------------------------------

## Vom Zauberblitz aufgerufen.
func blitz_treffer(_ladung: float, blitz: Node) -> void:
	var s: float = blitz.get("schaden") if blitz != null and blitz.get("schaden") != null else 1.0
	schaden_nehmen(s)


## Alter Treffer-Pfad (ohne Ladung)
func treffer() -> void:
	schaden_nehmen(1.0)


func schaden_nehmen(menge: float) -> void:
	if zustand == Zustand.DEAD:
		return
	if zustand == Zustand.STUNNED:
		menge *= daten.betaeubt_schaden_faktor
	lp -= menge
	_aufblitzen()
	if lp <= 0.0:
		_sterben()
		return
	# Ein Treffer weckt ihn auf
	if zustand == Zustand.IDLE or zustand == Zustand.PATROL:
		zustand_setzen(Zustand.CHASE)


## Betaeubt fuer `dauer` Sekunden (Bewegung aus, sinkt etwas ab, nimmt mehr Schaden).
func betaeuben(dauer: float) -> void:
	if zustand == Zustand.DEAD:
		return
	zustand_setzen(Zustand.STUNNED)
	_betaeubt_bis = dauer


func ist_betaeubt() -> bool:
	return zustand == Zustand.STUNNED


func _aufblitzen() -> void:
	for i in _mats.size():
		var m := _mats[i]
		m.emission_energy_multiplier = BLITZ_ENERGIE
		var tw := create_tween()
		tw.tween_property(m, "emission_energy_multiplier", _energie[i], BLITZ_DAUER)


func _sterben() -> void:
	zustand_setzen(Zustand.DEAD)
	velocity = Vector3.ZERO
	remove_from_group("blitz_ziel")
	remove_from_group("minimap_marker")
	remove_from_group("gegner")
	if _form != null:
		_form.set_deferred("disabled", true)
	besiegt.emit(self)
	EventBus.gegner_besiegt.emit(daten.anzeige_name)
	_kurzschluss()


## Tod-Effekt: Neon flackert mit kleinen Funken, Drohne kippt und faellt, grosser Funkenstoss, Beute, weg.
func _kurzschluss() -> void:
	var welt := get_parent()
	for i in TOD_FLACKERN:
		var an := i % 2 == 0
		for m in _mats:
			m.emission_energy_multiplier = BLITZ_ENERGIE if an else 0.0
		if an:
			BLITZ._treffer_effekt(welt, global_position + Vector3(randf_range(-0.5, 0.5), randf_range(-0.3, 0.5), randf_range(-0.5, 0.5)), TOD_FUNKEN_KLEIN)
		await get_tree().create_timer(TOD_FLACKER_ZEIT).timeout
	for m in _mats:
		m.emission_energy_multiplier = 0.0
	var tw := create_tween()
	tw.tween_property(self, "global_position:y", _boden_y + 0.3, TOD_FALL_ZEIT).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_modell, "rotation", Vector3(randf_range(-1.2, 1.2), randf() * TAU, randf_range(-1.2, 1.2)), TOD_FALL_ZEIT)
	await tw.finished
	BLITZ._treffer_effekt(welt, global_position, TOD_FUNKEN_GROSS)
	_beute(welt)
	var tw2 := create_tween()
	tw2.tween_property(_modell, "scale", Vector3.ONE * 0.05, TOD_SCHRUMPF_ZEIT)
	await tw2.finished
	queue_free()


func _beute(welt: Node) -> void:
	if welt == null:
		return
	for i in daten.beute_mana:
		var k = MANA_KERN.instantiate()
		welt.add_child(k)
		var w := randf() * TAU
		var pos := global_position + Vector3(cos(w) * BEUTE_RADIUS, 0.0, sin(w) * BEUTE_RADIUS)
		pos.y = _boden_y + BEUTE_HOEHE
		# kristall.start erwartet eine lokale Position im Eltern-Node
		k.start((welt as Node3D).to_local(pos) if welt is Node3D else pos, randi() % 3)
		if _spieler != null and _spieler.get("kristalle_gesamt") != null:
			_spieler.kristalle_gesamt += 1
	if _spieler != null and _spieler.has_signal("kristalle_geaendert"):
		_spieler.kristalle_geaendert.emit(_spieler.kristalle, _spieler.kristalle_gesamt)


## Zielhilfe: Mitte des Koerpers
func ziel_punkt() -> Vector3:
	return global_position
