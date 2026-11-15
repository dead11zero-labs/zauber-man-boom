extends Resource
## DialogZeile: eine Zeile in einem Dialog (Daten statt Code). Wird von DialogDaten gehalten.
## Exportiert: sprecher, text, audio (optional), antworten (optional), antwort_ziele (optional).
## Signale: keine.

## Name im Namensfeld der Dialog-UI
@export var sprecher := ""
@export_multiline var text := ""
## Optionaler Pfad zu einer vorab erzeugten Sprachdatei (z. B. res://assets/stimmen/<dialog_id>_<zeilennr>.ogg).
## Leer oder Datei fehlt: nur Text, kein Fehler.
@export_file("*.ogg", "*.mp3", "*.wav") var audio := ""
## Auswahlantworten. Leer = keine Auswahl, Weiter springt zur naechsten Zeile.
@export var antworten: PackedStringArray = PackedStringArray()
## Zielzeile pro Antwort (Index in DialogDaten.zeilen), -1 = Dialog endet. Leer = naechste Zeile.
@export var antwort_ziele: PackedInt32Array = PackedInt32Array()
