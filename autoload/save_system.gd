extends Node
## SaveSystem: 3 Spielstand-Slots als JSON (user://spielstand_1.json ... _3.json).
## Das Startmenue waehlt den Slot (waehle). Gespeichert wird nach Sammel-Ereignissen (kurz verzoegert),
## alle 20 s und beim Schliessen. Slot 0 = kein Slot (z. B. Start direkt aus dem Editor): es wird nichts gespeichert.

const SLOTS := 3
const INTERVALL := 20.0
const ALTER_PFAD := "user://spielstand.json"

var slot := 0

var hat_position := false
var position := Vector3.ZERO
var blick := 0.0
var _verzoegert: Timer


func _ready() -> void:
	_alten_stand_uebernehmen()
	_verzoegert = Timer.new()
	_verzoegert.one_shot = true
	_verzoegert.wait_time = 1.5
	_verzoegert.timeout.connect(speichern)
	add_child(_verzoegert)
	var periodisch := Timer.new()
	periodisch.wait_time = INTERVALL
	periodisch.autostart = true
	periodisch.timeout.connect(speichern)
	add_child(periodisch)
	EventBus.mana_kern_gesammelt.connect(func(_n: int) -> void: _verzoegert.start())
	EventBus.rune_gesammelt.connect(func(_b: int) -> void: _verzoegert.start())
	EventBus.chip_gesammelt.connect(func(_i: String) -> void: _verzoegert.start())
	EventBus.seite_gesammelt.connect(func(_n: int) -> void: _verzoegert.start())
	EventBus.checkpoint_erreicht.connect(func(_i: String) -> void: _verzoegert.start())
	EventBus.spieler_wiederbelebt.connect(func() -> void: _verzoegert.start())
	EventBus.upgrade_gekauft.connect(func(_i: String, _s: int) -> void: _verzoegert.start())
	EventBus.quest_geaendert.connect(func(_i: String) -> void: _verzoegert.start())
	EventBus.dialog_beendet.connect(func(_i: String, _a: int) -> void: _verzoegert.start())


func pfad(nr: int) -> String:
	return "user://spielstand_%d.json" % nr


func vorhanden(nr: int = -1) -> bool:
	return FileAccess.file_exists(pfad(slot if nr < 0 else nr))


## Kurzinfo fuer das Menue, leer wenn der Slot unbenutzt ist.
func info(nr: int) -> Dictionary:
	if not vorhanden(nr):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(pfad(nr)))
	return d if d is Dictionary else {}


## Slot aktivieren: laedt den Stand oder beginnt ein neues Spiel (leerer Slot).
func waehle(nr: int) -> void:
	slot = nr
	hat_position = false
	GameState.zuruecksetzen()
	if vorhanden(nr):
		laden()


func _alten_stand_uebernehmen() -> void:
	# Ein Stand aus der Zeit vor den Slots wandert in Slot 1
	if FileAccess.file_exists(ALTER_PFAD) and not vorhanden(1):
		DirAccess.rename_absolute(ProjectSettings.globalize_path(ALTER_PFAD), ProjectSettings.globalize_path(pfad(1)))


func speichern() -> void:
	var sp := get_tree().get_first_node_in_group("spieler") as Node3D
	if sp == null or slot == 0:
		return  # im Menue oder ohne Slot nichts schreiben
	if sp.get("_tot") == true:
		return  # waehrend des Kurzschlusses nicht speichern, nach dem Respawn wird gespeichert
	var d := GameState.zu_dict()
	d["version"] = 2
	d["bezirk"] = GameState.bezirk_name(GameState.aktueller_bezirk)
	d["zeit"] = Time.get_datetime_string_from_system(false, true)
	d["position"] = [sp.global_position.x, sp.global_position.y, sp.global_position.z]
	d["blick"] = sp.rotation.y
	var f := FileAccess.open(pfad(slot), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(d))


func laden() -> bool:
	if slot == 0 or not vorhanden():
		return false
	var d = JSON.parse_string(FileAccess.get_file_as_string(pfad(slot)))
	if not d is Dictionary:
		return false
	GameState.aus_dict(d)
	var p: Array = d.get("position", [])
	if p.size() == 3:
		position = Vector3(p[0], p[1], p[2])
		blick = float(d.get("blick", 0.0))
		hat_position = true
	return true


func loeschen(nr: int) -> void:
	if vorhanden(nr):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(pfad(nr)))
	if nr == slot:
		GameState.zuruecksetzen()
		hat_position = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		speichern()
