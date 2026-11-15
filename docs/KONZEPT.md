# Zauber-Man: Spielkonzept & Umsetzungsplan

> Dieses Dokument ist für Claude Code gedacht. Lies es komplett, bevor du etwas änderst.
> Ablage im Projekt-Root als `docs/KONZEPT.md`. Die Arbeitsregeln (Abschnitt 9) gehören zusätzlich in die `CLAUDE.md`.

## 1. Kurzfassung

- Genre: 3D-Rätsel- und Sammelspiel mit leichten Kämpfen
- Engine: Godot 4.x, GDScript
- Setting: Synth-City (Cyberpunk-Stadt), Held: Zauber-Man
- Kernidee: Magie und Strom sind dasselbe. Zauber-Mans Zauberblitze lassen sich durch Kabel, Spiegel und Relais leiten. Die Stadt ist ein einziges großes Schalträtsel.
- Ziel: 7 Grimoire-Seiten finden, die Stadt wieder mit Magie-Strom versorgen und den Gegner stoppen
- Spieldauer Ziel: ca. 2 bis 3 Stunden, 5 Bezirke
- Ton: frech, humorvoll, familientauglich. Kämpfe sind "Kurzschließen", kein Blut, keine Gewalt gegen Menschen.

## 2. Story

### Ausgangslage
Synth-City läuft auf dem **Kabelnetz**, einem Stromnetz, das vor Jahrzehnten heimlich mit Magie aufgeladen wurde. Das Herzstück war das **Grimoire**, ein Zauberbuch, das als Hauptschalter des Netzes diente. Der Gegner hat das Grimoire in **7 Seiten** zerrissen und über die Stadt verteilt. Seitdem flackert alles: Lichter, Fahrzeuge, Drohnen, Türen. Die Drohnen des Gegners sind die einzigen Maschinen, die noch zuverlässig laufen, weil er sie direkt anzapft.

### Held
Zauber-Man wacht in der Stadt auf, ohne zu wissen, wie lange er weg war. Er kann Blitze schießen, hat aber nur einen Bruchteil seiner alten Kraft. Jede Grimoire-Seite gibt ihm eine neue Fähigkeit zurück.

### Gegner
Der bereits vorhandene Gegner (Name und Look aus dem Projekt übernehmen) will das Netz übernehmen. Er sitzt im **Kern-Turm** in der Stadtmitte und schickt Drohnen. Sein Motiv: Er will keine Zerstörung, er will die Kontrolle über den Hauptschalter. Das macht ihn zum Boss mit Persönlichkeit statt zum reinen Prügelsack.

### Erzählform
- Kurze Dialoge mit NPCs (Textboxen, Sprecherportrait optional)
- Lore-Datenchips zum Sammeln, die die Hintergrundgeschichte stückweise erzählen
- Ein Erzähler-Kommentar von Zauber-Man selbst (kurze, freche Sprüche bei Ereignissen)
- Keine langen Zwischensequenzen. Maximal 30 Sekunden, überspringbar.

### Akte
| Akt | Bezirk | Seite | Neue Fähigkeit | Rätselthema |
|---|---|---|---|---|
| 1 | Startviertel (Hinterhöfe) | 1 | Ladeschuss (Blitz aufladen, löst Schalter aus der Ferne) | Schalter, Türen, einfache Kabel |
| 2 | Marktviertel / Neon-Basar | 2 | Kettenblitz (springt zu bis zu 3 Zielen) | Mehrere Ziele gleichzeitig treffen |
| 3 | Hafen / Containerdock | 3 | Spiegelblitz (Blitz prallt an Metall ab) | Umlenken, Reflexionsrätsel |
| 4 | Dächer / Antennenfeld | 4 und 5 | Schwebesprung (kurzer Gleitflug) | Vertikale Wege, Zeitschalter |
| 5 | Untergrund / Serverkeller | 6 | Überladung (Flächenblitz, Notfallangriff) | Kombirätsel aus allem |
| Finale | Kern-Turm | 7 | alle | Bosskampf mit Rätselphasen |

Hinweis: Reihenfolge und Bezirksnamen sind Vorschläge. Passe sie an die tatsächliche Stadt im Projekt an (siehe Aufgabe 0.1).

## 3. Kernschleife (Gameplay-Loop)

1. Bezirk erkunden (zu Fuß oder mit Fahrzeug)
2. Sammelobjekte finden und Rätsel an Schaltstellen lösen
3. Drohnen abwehren, die Rätsel stören
4. Grimoire-Seite holen, Fähigkeit freischalten
5. Mit der neuen Fähigkeit in alte Bezirke zurückkehren, um versteckte Dinge zu holen (leichtes Metroidvania-Element)

## 4. Sammelobjekte

| Objekt | Zweck | Menge (gesamt) | Pflicht? |
|---|---|---|---|
| Grimoire-Seite | Story, Fähigkeiten, Spielende | 7 | ja |
| Mana-Kern | Währung für Upgrades | ca. 150 | nein |
| Neon-Rune | Versteckte Sammelgegenstände, schalten Kosmetik frei | 25 pro Bezirk | nein |
| Datenchip | Lore-Texte | 20 | nein |
| Reparatur-Teil | Fahrzeug-Upgrades | 15 | nein |

Upgrades (mit Mana-Kernen bezahlt, bei einem NPC-Händler):
- Blitzschaden, Blitzreichweite, Ladegeschwindigkeit
- Max. Lebenspunkte
- Fahrzeug: Tempo, Boost

Belohnungslogik: Jeder Bezirk hat 100 Prozent Abschluss-Anzeige (Seite, Runen, Chips, Mana-Kerne). Beim Erreichen von 100 Prozent gibt es ein kosmetisches Extra (Umhangfarbe, Blitzfarbe).

## 5. Rätsel-System

Alle Rätsel werden aus wiederverwendbaren Bausteinen gebaut. Das hält den Aufwand klein.

| Baustein | Verhalten |
|---|---|
| `PowerSource` | Gibt Strom ab, sobald von einem Blitz getroffen (an/aus oder Timer) |
| `Cable` | Leitet Strom zwischen zwei Punkten, sichtbar als leuchtende Linie |
| `Receiver` | Schaltet etwas (Tür, Brücke, Aufzug, Licht), wenn Strom anliegt |
| `Relay` | Braucht mehrere Eingänge (UND) oder einen von mehreren (ODER) |
| `Mirror` | Lenkt Spiegelblitze um (ab Akt 3) |
| `TimerSwitch` | Strom nur für X Sekunden, dann wieder aus |
| `PressurePlate` | Reagiert auf Spieler, NPC oder Fahrzeug |
| `Barrier` | Blockiert, bis Receiver aktiv |

Regeln für Rätseldesign:
- Jedes Rätsel passt auf einen Bildschirm oder ist klar in Sichtweite.
- Der Spieler sieht immer, was mit dem Rätsel verbunden ist (leuchtende Kabel, Farbcode).
- Keine Rätsel ohne Hinweis: Wenn der Spieler 60 Sekunden festhängt, zeigt ein optionaler Hinweis-Pulse die nächste Station (ein Knopf, kein Zwang).
- Drohnen stören Rätsel, zerstören sie aber nie dauerhaft.
- Fahrzeuge sind Teil von Rätseln: als Gewicht auf Druckplatten, als Stromquelle (Batterie), zum schnellen Erreichen entfernter Schalter.

## 6. Kampfsystem (leicht)

- Angriff: Zauberblitz auf Tastendruck, mit leichter Zielhilfe. Aufladen halten für Ladeschuss.
- Ausweichen: kurzer Dash mit kurzer Unverwundbarkeit
- Lebenspunkte: 5 Herzen, Heilung durch Mana-Kerne in der Umgebung oder Heilstationen
- Kein Game-Over-Frust: Bei Niederlage zurück zum letzten Checkpoint, Sammelobjekte bleiben erhalten.

Gegnertypen:
| Gegner | Verhalten | Ab Akt |
|---|---|---|
| Spähdrohne | Schwebt, schießt langsame Funkenkugeln | 1 |
| Rammdrohne | Rast auf den Spieler zu, betäubt nach Treffer an Wand | 2 |
| Schilddrohne | Schild blockiert vorne, Blitz muss von der Seite oder über Kettenblitz | 3 |
| Reparatur-Bot | Heilt andere Drohnen, zuerst ausschalten | 4 |
| Mini-Boss pro Bezirk | Mischt Rätsel und Kampf (Schwachstelle nur über Kabel-Überlastung) | 1 bis 5 |

Endboss (Gegner im Kern-Turm), drei Phasen:
1. Er schickt Drohnenwellen, Spieler schaltet Netz-Knoten frei
2. Er nutzt das Netz selbst: Spieler muss Blitze über Spiegel zu seinen Schwachstellen lenken
3. Direktduell mit allen Fähigkeiten, Finale mit der siebten Seite

## 7. Welt und Spielfluss

- Offene Stadt mit 5 Bezirken. Bezirke sind per Tor/Schranke getrennt, die sich über Story oder Fähigkeit öffnen.
- Schnellreise über Fahrzeug-Stationen (nach erstem Besuch freigeschaltet)
- NPCs mit festen Rollen: Händler (Upgrades), Informant (gibt Hinweise auf Runen), Mechanikerin (Fahrzeug-Upgrades), pro Bezirk 1 Questgeber
- Charaktere aus der Zauber-Man-Charakterdatenbank (z. B. Aen) können als NPCs eingebaut werden. Rolle wird vom Projektinhaber festgelegt, bis dahin Platzhalter.
- Musik: Der Song "Drohnen und Kabel" eignet sich als Titel- oder Kampfthema (Rechte liegen beim Projektinhaber).

## 8. Technische Architektur (Godot 4)

### Ordnerstruktur (Vorschlag, an Bestand anpassen)
```
res://
  autoload/        # Globale Singletons
  characters/      # Spieler, Gegner, NPCs
  puzzle/          # Rätselbausteine
  collectibles/    # Sammelobjekte + Resource-Definitionen
  ui/              # HUD, Dialog, Menüs
  levels/          # Bezirke als Szenen
  vehicles/
  data/            # .tres Resources (Items, Dialoge, Upgrades)
  docs/            # Dieses Konzept
```

### Autoloads
- `EventBus`: Signale für alles, was systemübergreifend passiert (`seite_gesammelt`, `rune_gesammelt`, `rätsel_gelöst`, `spieler_gestorben`)
- `GameState`: Fortschritt, Fähigkeiten, Inventar, Bezirksabschluss
- `SaveSystem`: Speichern/Laden als JSON in `user://`
- `QuestManager`: Aktive Ziele, Hinweistexte
- `AudioManager`: Musik und Effekte, Lautstärke aus den Optionen

### Wichtige Klassen
- `Collectible` (Basisklasse, `Area3D`) mit `CollectibleData` (Resource: id, typ, wert, icon). Einsammeln über `body_entered`, sendet über EventBus.
- `LightningBolt` (Projektil): `Area3D` plus Raycast, Eigenschaften: Schaden, Reichweite, Kettenanzahl, Reflexion.
- `PowerNode` als gemeinsame Basis für `PowerSource`, `Relay`, `Receiver`. Signal `power_changed(active: bool)`. Verbindungen über exportierte NodePaths oder Gruppen.
- `Enemy` (Basisklasse) mit State Machine (Idle, Patrol, Chase, Attack, Stunned, Dead)
- `AbilityController` am Spieler: schaltet Fähigkeiten anhand `GameState` frei
- `DialogueRunner`: liest Dialoge aus `.tres` oder JSON

### Eingaben (InputMap)
`move_*`, `jump`, `dash`, `shoot` (halten = laden), `interact`, `vehicle_enter`, `hint`, `pause`

### Qualitätsregeln
- Statisch typisiertes GDScript (`var x: int`, Rückgabetypen)
- Signale statt harter Node-Pfade zwischen Systemen
- Daten in Resources, nicht im Code hartkodiert
- Eine Szene = eine Verantwortung
- Keine Magic Numbers: Werte als `@export` oder in Resource-Dateien

## 9. Arbeitsregeln für Claude Code

1. **Inventur zuerst** (Aufgabe 0.1), bevor etwas gebaut wird. Vorhandene Szenen, Skripte und Namen haben Vorrang vor diesem Konzept.
2. Immer nur einen Meilenstein-Schritt auf einmal. Nach jedem Schritt: Spiel über MCP starten, Fehlerausgabe lesen, Screenshot machen, Ergebnis prüfen.
3. Nichts Bestehendes ungefragt löschen oder umbenennen. Bei Konflikt mit dem Konzept: kurz nachfragen.
4. Nach jedem abgeschlossenen Meilenstein-Schritt ein Git-Commit mit klarer Meldung.
5. Neue Szenen und Skripte kurz kommentieren (Zweck, Signale, exportierte Variablen).
6. Platzhalter-Grafik ist ok (CSG-Formen, einfache Materialien). Optik kommt später.
7. Fortschritt in `docs/FORTSCHRITT.md` abhaken (Checkboxen unten).
8. Unklarheiten, Designentscheidungen und Ideen in `docs/OFFENE_FRAGEN.md` sammeln, nicht raten.

## 10. Umsetzungsplan

Jeder Schritt hat ein Abnahmekriterium. Erst wenn es erfüllt ist, geht es weiter.

### Meilenstein 0: Bestandsaufnahme
- [ ] 0.1 Projekt inventarisieren: Szenen, Skripte, Assets, Autoloads, InputMap, Godot-Version. Ergebnis in `docs/BESTAND.md`.
  Abnahme: Datei beschreibt Stadt, Spieler, Gegner, NPCs, Fahrzeuge mit Pfaden.
- [ ] 0.2 Ordnerstruktur und Autoloads (`EventBus`, `GameState`) anlegen, ohne Bestehendes zu brechen.
  Abnahme: Projekt startet fehlerfrei.
- [ ] 0.3 Stadt in 5 Bezirke aufteilen (Markierungen/Areas, noch keine Tore).
  Abnahme: `GameState` kennt den aktuellen Bezirk, HUD zeigt den Bezirksnamen.

### Meilenstein 1: Sammelsystem
- [ ] 1.1 `CollectibleData` und `Collectible` bauen, Mana-Kern als erstes Objekt.
  Abnahme: Einsammeln erhöht Zähler im `GameState`, Sound und Partikel laufen.
- [ ] 1.2 HUD: Mana-Kerne, Herzen, Seiten-Anzeige (x/7)
- [ ] 1.3 Neon-Runen, Datenchips, Grimoire-Seite als weitere Typen
- [ ] 1.4 Bezirks-Abschlussanzeige
- [ ] 1.5 Speichern und Laden des Fortschritts
  Abnahme: Neustart behält eingesammelte Objekte, sie erscheinen nicht erneut.

### Meilenstein 2: Zauberblitz
- [ ] 2.1 `LightningBolt` mit Zielhilfe, Cooldown, Treffer-Effekt
- [ ] 2.2 Aufladen (Ladeschuss) mit Anzeige
- [ ] 2.3 Treffer auf `PowerSource` schaltet diese ein
  Abnahme: Blitz auf Testschalter öffnet Testtür.

### Meilenstein 3: Rätselbausteine
- [ ] 3.1 `PowerNode`, `Cable`, `Receiver`, `Barrier`
- [ ] 3.2 `Relay` (UND/ODER), `TimerSwitch`, `PressurePlate`
- [ ] 3.3 Visuelles Feedback (Kabel leuchten, Farbcodes)
- [ ] 3.4 Hinweis-Pulse
- [ ] 3.5 Testraum mit 5 Beispielrätseln (ein Baustein je Rätsel plus ein Kombirätsel)
  Abnahme: Alle 5 Rätsel lösbar, Zustand wird gespeichert.

### Meilenstein 4: Gegner und Kampf
- [ ] 4.1 `Enemy`-Basis mit State Machine, Lebenspunkte, Tod-Effekt (Kurzschluss, Funken)
- [ ] 4.2 Spähdrohne, dann Rammdrohne
- [ ] 4.3 Spieler-Schaden, Herzen, Dash, Checkpoint
- [ ] 4.4 Drohnen-Spawner in Bezirken, die Rätsel stören
  Abnahme: Kampf ist spielbar, Tod führt zum Checkpoint ohne Fortschrittsverlust.

### Meilenstein 5: Story und Dialoge
- [ ] 5.1 `DialogueRunner` und Dialog-UI
- [ ] 5.2 `QuestManager` mit Zielanzeige
- [ ] 5.3 Intro (kurz), NPC-Rollen (Händler, Informant, Mechanikerin)
- [ ] 5.4 Upgrade-Shop
- [ ] 5.5 Lore-Datenchips im Menü lesbar

### Meilenstein 6: Akt 1 komplett (Vertical Slice)
- [ ] 6.1 Startviertel: 8 Rätsel, 40 Mana-Kerne, 25 Runen, 3 Chips, Mini-Boss, Seite 1
- [ ] 6.2 Fähigkeit Ladeschuss wird durch Seite 1 freigeschaltet
- [ ] 6.3 Spieltest-Durchlauf, Balancing
  Abnahme: Ein Spieler schafft Akt 1 ohne Hilfe in 20 bis 30 Minuten.
  **Hier anhalten und zusammen mit dem Projektinhaber prüfen, ob der Spielspaß stimmt, bevor Akt 2 beginnt.**

### Meilenstein 7: Akt 2 bis 5
- [ ] 7.1 Akt 2 (Kettenblitz, Schilddrohne)
- [ ] 7.2 Akt 3 (Spiegelblitz, `Mirror`-Baustein)
- [ ] 7.3 Akt 4 (Schwebesprung, Reparatur-Bot, Dächer)
- [ ] 7.4 Akt 5 (Überladung, Kombirätsel)
- [ ] 7.5 Rückkehr-Belohnungen (Bereiche, die erst mit späteren Fähigkeiten erreichbar sind)

### Meilenstein 8: Finale
- [ ] 8.1 Kern-Turm als Level
- [ ] 8.2 Endboss mit drei Phasen
- [ ] 8.3 Abspann, Abschlussstatistik

### Meilenstein 9: Politur
- [ ] 9.1 Menüs (Start, Pause, Optionen), Gamepad-Support
- [ ] 9.2 Sound und Musik einbinden
- [ ] 9.3 Performance (Drohnen-Anzahl, Beleuchtung, LOD in der Stadt)
- [ ] 9.4 Tutorial-Hinweise im Spiel, Hinweis-System testen
- [ ] 9.5 Export-Preset (Windows/Linux) und Testlauf

## 11. Offene Entscheidungen (vom Projektinhaber zu klären)

- Name und Hintergrund des vorhandenen Gegners
- Rolle der Charaktere aus der Charakterdatenbank im Spiel
- Zielplattform (PC reicht?) und Steuerung (Tastatur/Maus, Gamepad)
- Soll Zauber-Man sprechen (Sprachausgabe) oder nur Text?
- Zielgruppe und Altersfreigabe, falls Kinder mitspielen sollen
- Ob "Drohnen und Kabel" im Spiel als Musik verwendet wird

## 12. Startprompt für Claude Code

> Lies `docs/KONZEPT.md`. Starte mit Meilenstein 0 und arbeite dich Schritt für Schritt voran. Befolge die Arbeitsregeln in Abschnitt 9. Nutze den Godot-MCP, um das Spiel nach jedem Schritt zu starten und Fehler zu prüfen. Melde dich nach Aufgabe 0.1 mit einer kurzen Zusammenfassung des Bestands und deinen Anpassungsvorschlägen für das Konzept, bevor du weitermachst.
