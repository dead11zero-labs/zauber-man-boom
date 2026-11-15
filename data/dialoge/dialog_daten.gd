extends Resource
## DialogDaten: ein ganzer Dialog (Liste von Zeilen). Liegt als .tres in res://data/dialoge/.
## Exportiert: id (Kennung, auch Teil der Audio-Dateinamen), ueberspringbar, zeilen (DialogZeile-Resources).
## Abspielen: Autoload `Dialog.starten(daten)`.

@export var id := ""
## true: Spieler darf den Dialog mit "ui_cancel" (Esc) abbrechen (z. B. Intro)
@export var ueberspringbar := false
@export var zeilen: Array[Resource] = []
