extends Resource
## QuestDaten: ein Ziel in der Questkette (Daten statt Code). Liegt als .tres in res://data/quests/<id>.tres.
## Exportiert: id, titel, ziel (Text im HUD), beschreibung (Journal), abschluss_ereignis, naechste.
## Abschluss: QuestManager meldet ein Story-Ereignis, das mit `abschluss_ereignis` uebereinstimmt.

@export var id := ""
@export var titel := ""
## Kurzer Zieltext fuers HUD, z. B. "Sprich mit dem Informanten"
@export var ziel := ""
@export_multiline var beschreibung := ""
## Ereignisname, der die Quest abschliesst, z. B. "gespraech:informant", "seite:1", "bezirk:2"
@export var abschluss_ereignis := ""
## id der Quest, die danach startet (leer = Ende der Kette)
@export var naechste := ""
