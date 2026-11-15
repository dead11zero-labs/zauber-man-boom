# Zauber-Man: Sprechertexte für ElevenLabs

Quelle: `data/dialoge/*.tres`. Stand der Texte: Spielstand vom 14.11.2026.
Dateiname je Zeile: `<dialog_id>_<zeilennr>.ogg` (Zeilennummer ab 0), abgelegt in `res://assets/stimmen/`.
Danach in der jeweiligen `.tres` das Feld `audio` auf den Pfad setzen, z. B. `res://assets/stimmen/intro_0.ogg`.
Fehlt die Datei, zeigt das Spiel nur den Text.

Tipp für ElevenLabs: Pro Sprecher eine feste Stimme wählen und Stabilität/Stil für alle Zeilen gleich lassen.
Satzzeichen steuern die Betonung, "..." erzeugt eine Pause. Ausgabeformat MP3 oder WAV, Umwandlung zu OGG danach z. B. mit `ffmpeg -i in.mp3 -c:a libvorbis out.ogg`.

## Sprecher und Stimmvorschläge

| Sprecher | Rolle | Stimmvorschlag |
|---|---|---|
| Zauber-Man | Held | jung, männlich, locker, leicht ironisch |
| Stimme im Funk | Funkkontakt | mittleres Alter, ruhig, leicht verzerrt (Funkeffekt nachträglich) |
| Informant | Straßeninformant | tief, verschwörerisch, geflüstert-rau |
| Händler | Marktstand | laut, jovial, Verkäufer-Ton |
| Clarissa | Mechanikerin / Kybernetikerin | weiblich, jung, entspannt, technikverliebt |
| Mechy McBoom | Wachmech am Empfang | roboterhaft, monoton, trocken-humorvoll |

## intro (Spielstart, überspringbar)

| Datei | Sprecher | Text |
|---|---|---|
| intro_0.ogg | Zauber-Man | Uff. Mein Kopf brummt wie ein defekter Trafo. Wo bin ich? ... Synth-City. Natürlich. Nur dunkler, als ich sie in Erinnerung habe. |
| intro_1.ogg | Stimme im Funk | Zauber-Man? Hörst du mich? Gut, du lebst. Das Kabelnetz flackert, seit Iggy Inferno das Grimoire zerrissen hat. |
| intro_2.ogg | Stimme im Funk | Sieben Seiten, quer über die Stadt verstreut. Je mehr Magie durch die Leitungen jagt, desto heißer brennt sein Feuer. Magie ist Strom, vergiss das nicht. |
| intro_3.ogg | Zauber-Man | Magie ist Strom. Dann sind Kabel meine Freunde und Schalter meine Zielscheiben. Also: Seiten suchen, Feuerkopf stoppen. |
| intro_4.ogg | Stimme im Funk | Sprich mit dem Informanten bei den Hinterhöfen. Und der Händler tauscht Mana-Kerne gegen Kraft. Drück J, wenn du dein Journal sehen willst. |

## informant_erst (erstes Gespräch)

| Datei | Sprecher | Text |
|---|---|---|
| informant_erst_0.ogg | Informant | Psst. Du bist also der Typ mit den Blitzen. Ich höre alles, was durchs Kabelnetz summt. |
| informant_erst_1.ogg | Informant | Die erste Grimoire-Seite liegt hier im Startviertel, bei der Runen-Plaza. Wenn du nicht weiterweißt: H drücken, der Hinweis-Pulse zeigt dir den nächsten Schalter. |
| informant_erst_2.ogg | Informant | Runen verstecken sich dort, wo Städter nicht hinschauen: hinter Ecken, auf Dächern, in Sackgassen. Wo es leise neonfarben summt, lohnt sich ein zweiter Blick. |

## informant_spaeter (weitere Gespräche)

| Datei | Sprecher | Text |
|---|---|---|
| informant_spaeter_0.ogg | Informant | Runen glimmern leise. Geh nah ran, dann hörst du sie summen. Und Datenchips? Die liegen meist da, wo jemand etwas verstecken wollte. |

## haendler

Antwortoptionen (nur Text, keine Sprachausgabe nötig): "Zeig mir deine Upgrades" / "Nur gucken".

| Datei | Sprecher | Text |
|---|---|---|
| haendler_0.ogg | Händler | Frischer Strom, heiße Ware! Mana-Kerne rein, Kraft raus. Was darf es sein? |

## mechanikerin_erst (erstes Gespräch mit Clarissa)

| Datei | Sprecher | Text |
|---|---|---|
| mechanikerin_erst_0.ogg | Clarissa | Hi, ich bin Clarissa. Ich baue und kalibriere humanoide Roboter. Gerade flackert das Netz, und meine Jungs hängen alle im Standby. |
| mechanikerin_erst_1.ogg | Clarissa | Bring mir später Reparatur-Teile, dann bau ich dir was Schnelles. Bis dahin: Werkstatt zu, Kaffee offen. Und falls du einen kleinen Jungen mit Roboter-Fimmel siehst: der gehört zu mir. |

## mechanikerin_spaeter (weitere Gespräche)

| Datei | Sprecher | Text |
|---|---|---|
| mechanikerin_spaeter_0.ogg | Clarissa | Noch keine Teile? Macht nichts. Ich kalibriere derweil meinen Arm neu und zocke eine Runde. Zu viel Arbeit macht auch eine Kybernetikerin mürbe. |

## mechy (Empfang im Zauber-Tower, überspringbar)

| Datei | Sprecher | Text |
|---|---|---|
| mechy_0.ogg | Mechy McBoom | HALT. Besucher erkannt. Ich bin Mechy McBoom, Sicherheitsdienst am Empfang. Bitte nichts anzünden, nichts sprengen, nichts aufladen, was nicht ausdrücklich dafür vorgesehen ist. |
| mechy_1.ogg | Mechy McBoom | Der Aufzug steht hinter der Sicherheitsschleuse. Etage wählen, einsteigen, nicht auf Knöpfe hämmern. Mein Name ist übrigens reine Ironie. Meistens. |

## Aussprache-Hinweise

- "Grimoire": französisch, "Grimoar".
- "Synth-City": "Sünth-Ssitti".
- "Mana-Kerne": "Mah-na".
- "Iggy Inferno": "Iggi Infärno".
- Tasten wie "J" und "H" ausgeschrieben sprechen lassen ("Jott", "Ha"), sonst liest ElevenLabs sie manchmal als Buchstabenfolge.
