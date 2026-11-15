extends Node
## QuestManager: aktive Ziele und Questkette. Quests liegen als Resources in res://data/quests/<id>.tres.
## Fortschritt steckt in GameState (quest_aktiv, quests_fertig) und wird mit dem Spielstand gespeichert.
## Ereignisse kommen ueber EventBus.story_ereignis (z. B. "gespraech:informant"); dazu uebersetzt der Manager
## seite_gesammelt -> "seite:<n>" und bezirk_gewechselt -> "bezirk:<n>".
## Signale (EventBus): quest_geaendert(id) beim Start/Wechsel, quest_abgeschlossen(id).

const QUEST_PFAD := "res://data/quests/%s.tres"
const ERSTE_QUEST := "q_informant"


func _ready() -> void:
	EventBus.story_ereignis.connect(melden)
	EventBus.seite_gesammelt.connect(func(n: int) -> void: melden("seite:%d" % n))
	EventBus.bezirk_gewechselt.connect(func(nr: int, _n: String) -> void: melden("bezirk:%d" % nr))


## Laedt die Quest-Resource, null wenn unbekannt.
func daten(id: String) -> Resource:
	var pfad := QUEST_PFAD % id
	return load(pfad) if id != "" and ResourceLoader.exists(pfad) else null


func aktive() -> Resource:
	return daten(GameState.quest_aktiv)


## Text fuer das HUD, leer wenn kein Ziel offen ist.
func ziel_text() -> String:
	var q := aktive()
	return "" if q == null else String(q.ziel)


func starten(id: String) -> void:
	var q := daten(id)
	if q == null or GameState.quests_fertig.has(id):
		return
	GameState.quest_aktiv = id
	EventBus.quest_geaendert.emit(id)
	# Ist die Bedingung schon erfuellt (z. B. Seite vor dem Gespraech geholt), sofort weiter
	if _schon_erfuellt(String(q.abschluss_ereignis)):
		melden(String(q.abschluss_ereignis))


## Ein Story-Ereignis ist passiert. Schliesst die aktive Quest ab, wenn es passt.
func melden(ereignis: String) -> void:
	var q := aktive()
	if q == null or String(q.abschluss_ereignis) != ereignis:
		return
	GameState.quests_fertig.append(String(q.id))
	GameState.quest_aktiv = ""
	EventBus.quest_abgeschlossen.emit(String(q.id))
	if String(q.naechste) != "":
		starten(String(q.naechste))
	else:
		EventBus.quest_geaendert.emit("")


## Beim Spielstart: leeren Slot nicht anfassen (das Intro startet die Kette), sonst Kette fortsetzen.
func fortsetzen() -> void:
	if GameState.quest_aktiv == "" and GameState.quests_fertig.is_empty() and GameState.flag("intro_gesehen"):
		starten(ERSTE_QUEST)
	else:
		EventBus.quest_geaendert.emit(GameState.quest_aktiv)


func _schon_erfuellt(ereignis: String) -> bool:
	if ereignis.begins_with("seite:"):
		return GameState.hat_seite(int(ereignis.get_slice(":", 1)))
	if ereignis.begins_with("bezirk:"):
		return GameState.aktueller_bezirk == int(ereignis.get_slice(":", 1))
	return false
