extends Resource
## GegnerDaten: Werte eines Gegnertyps (Drohnen). Liegen als .tres in res://data/gegner/.
## Wird von characters/enemy.gd und den Drohnen gelesen. Keine Signale.
## Typisieren per `const GEGNER_DATEN := preload("res://characters/gegner_daten.gd")` (kein class_name noetig).

## Anzeigename (Debug, spaeter HUD)
@export var anzeige_name := "Drohne"
## Lebenspunkte (ein normaler Blitz macht 1, ein voller Ladeschuss 3)
@export var max_lp := 3.0
@export var tempo_patrouille := 3.0
@export var tempo_jagd := 6.0
## Beschleunigung beim Lenken (m/s^2)
@export var beschleunigung := 14.0
## Ab dieser Entfernung zum Spieler beginnt die Jagd, ab `verlieren` gibt der Gegner auf
@export var erfassung := 30.0
@export var verlieren := 48.0
## Angriff, wenn der Spieler naeher als das ist
@export var angriff_reichweite := 18.0
## Wunschabstand beim Jagen (0 = ganz ran)
@export var halteabstand := 11.0
## Sekunden zwischen zwei Angriffen
@export var angriff_pause := 2.6
## Ausholen vor dem Angriff (Leuchten), Sekunden
@export var ausholen := 0.55
## Herzen Schaden pro Treffer am Spieler
@export var schaden := 1
## Funkenkugel-Tempo (Spaehdrohne)
@export var projektil_tempo := 9.0
## Sprint-Tempo und -Dauer (Rammdrohne)
@export var sprint_tempo := 26.0
@export var sprint_dauer := 1.2
## Betaeubung nach Wandtreffer (Sekunden) und Schadensfaktor waehrenddessen
@export var betaeubung_dauer := 3.0
@export var betaeubt_schaden_faktor := 2.0
## kurzes Zucken nach einem Blitztreffer (Sekunden)
@export var treffer_zucken := 0.25
## Schwebehoehe ueber dem Boden
@export var schwebe_hoehe := 3.5
## Pause im Idle, bevor die Patrouille weitergeht
@export var idle_dauer := 1.5
## Mana-Kerne, die beim Kurzschluss herausfallen
@export var beute_mana := 1
## Neonfarbe (Koerper, Minimap)
@export var farbe := Color(1.0, 0.35, 0.15)
