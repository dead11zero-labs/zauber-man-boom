# Dialoge: Format und Sprachausgabe

## Aufbau
- `data/dialoge/<id>.tres`: Resource `DialogDaten` (`data/dialoge/dialog_daten.gd`) mit `id`, `ueberspringbar` und `zeilen`.
- Jede Zeile ist eine `DialogZeile` (`data/dialoge/dialog_zeile.gd`):
  - `sprecher`: Name im Namensschild
  - `text`: Anzeigetext (Tippeffekt, ca. 180 Zeichen maximal pro Zeile, sonst wird es eng)
  - `audio`: optionaler Pfad zu einer Sprachdatei. Leer oder Datei fehlt = nur Text, kein Fehler
  - `antworten`: optionale Auswahl (Texte). Leer = keine Auswahl
  - `antwort_ziele`: Zielzeile je Antwort (Index in `zeilen`), `-1` = Dialog endet. Leer = naechste Zeile
- Abspielen: `Dialog.starten(Dialog.laden("<id>"))` (Autoload `Dialog`, `autoload/dialog.gd`).
- Ende: `EventBus.dialog_beendet(id, antwort)`. `antwort` ist der Index der zuletzt gewaehlten Antwort, sonst `-1` (der Haendler oeffnet bei Antwort 0 den Shop).
- Steuerung im Dialog: E / Enter / Leertaste / Pad A (oder Y) = weiter bzw. Antwort bestaetigen, Pfeil hoch/runter = Antwort waehlen, Esc = ueberspringen (nur bei `ueberspringbar`).

## Vorhandene Dialoge
`intro` (ueberspringbar), `haendler`, `informant_erst`, `informant_spaeter`, `mechanikerin_erst`, `mechanikerin_spaeter`.

## Audiodateien (Sprachausgabe)
Entschieden: vorab erzeugte KI-Stimmen als Audiodateien, keine System-TTS. Welcher Dienst die Stimmen erzeugt, ist offen (`docs/OFFENE_FRAGEN.md`).

Vorschlag fuer Benennung und Ablage:

```
res://assets/stimmen/<dialog_id>_<zeilennr>.ogg
```

- `<zeilennr>` ist der Index der Zeile im Array `zeilen`, nullbasiert, zweistellig: `intro_00.ogg`, `intro_01.ogg`, `haendler_00.ogg`.
- Format: OGG Vorbis (klein, Godot-Standard). `.mp3` und `.wav` gehen ebenfalls.
- Der Pfad wird in der `.tres` je Zeile in `audio` eingetragen, z. B. `audio = "res://assets/stimmen/intro_00.ogg"`. Erst dann spielt der Runner die Datei ab. Der Tippeffekt laeuft parallel, die Anzeige "STIMME >>" erscheint solange die Datei laeuft.
- Beim Weiterklicken oder Dialogende stoppt die Sprachausgabe.
- Pro Zeile eine Datei. Wird der Text geaendert, muss die Datei neu erzeugt werden.
