# Fortschritt

## Meilenstein 0: Bestandsaufnahme
- [x] 0.1 Projekt inventarisiert (`docs/BESTAND.md`)
- [x] 0.2 Ordnerstruktur und Autoloads (`EventBus`, `GameState`, `Eingabe` fuer Gamepad)
- [x] 0.3 Stadt in 5 Bezirke plus Kern-Turm aufgeteilt (`levels/bezirke.gd`), HUD zeigt Bezirksnamen

## Meilenstein 1: Sammelsystem
- [x] 1.1 `CollectibleData` + `Collectible`, Mana-Kern (Sound synthetisch, Funken-Partikel)
- [x] 1.2 HUD: Mana-Kerne, Herzen, Seiten x/7 (Status-Panel rechts oben)
- [x] 1.3 Neon-Runen, Datenchips, Grimoire-Seite (Platzhalter-Positionen auf der Runen-Plaza)
- [x] 1.4 Bezirks-Abschlussanzeige (Prozent der registrierten Objekte im aktuellen Bezirk)
- [x] 1.5 Speichern/Laden (`SaveSystem`, 3 Slots: `user://spielstand_1..3.json`, Slot-Auswahl im Startmenue, Entf/Y loescht mit Bestaetigung; alter Stand wandert in Slot 1)
  Abnahme getestet: Neustart behaelt eingesammelte Objekte, Position, Zaehler; sie erscheinen nicht erneut.
- [x] Neon-Basar-Tor am Durchgang: bleibt zu bis Seite 1 (`levels/bezirk_tor.gd`)

## Meilenstein 2: Zauberblitz
- [x] 2.1 `blitz.gd` mit Zielhilfe (9 Grad Kegel, Gruppe `blitz_ziel`), Cooldown 0.4 s, Treffer-Effekt (Funken, Lichtblitz)
- [x] 2.2 Ladeschuss: Taste/Maus/RT halten (1 s), Ladebalken im HUD unten Mitte, Licht an der Hand; mehr Reichweite, Schaden, Groesse
- [x] 2.3 `levels/power_source.gd` (`PowerSource`, Signal `power_changed`); `braucht_ladung` fuer Fernschalter
  Abnahme getestet (Screenshot + Log): Blitz auf Schalter A (14, 104) hebt Tuer A; Schalter B (-14, 104) reagiert nur auf Ladeschuss.
  Testaufbau: `levels/test_aufbau.gd` (wird in Meilenstein 3 durch Receiver/Cable ersetzt).

## Meilenstein 3: Raetselbausteine
- [x] 3.1 `PowerNode` (Basis), `Cable`, `Receiver`, `Barrier` (`levels/*.gd`)
- [x] 3.2 `Relay` (UND/ODER), Zeitschalter (`PowerSource.dauer`), `PressurePlate`
- [x] 3.3 Feedback: Kabel leuchten in der Farbe der Quelle, Relais/Empfaenger/Platten leuchten bei Strom
- [x] 3.4 Hinweis-Pulse: Taste H (Pad: linke Schulter), Lichtsaeule am naechsten ungeloesten Schalter
- [x] 3.5 Testraum mit 5 Raetseln suedlich vom Start (`levels/test_aufbau.gd`, z 130..155)
  Abnahme getestet (Skript): Raetsel 1, 3, 4, 5 geloest, Zustand in `GameState.raetsel` (wird gespeichert). Raetsel 2 (Zeitschalter) zaehlt erst beim Durchgang, nicht von Hand durchgespielt.

## Meilenstein 4: Gegner und Kampf
- [x] 4.1 `Enemy`-Basis (`characters/enemy.gd`): State Machine Idle/Patrol/Chase/Attack/Stunned/Dead, Lebenspunkte, Kurzschluss-Tod (Flackern, Funken, Absturz, Mana-Kern-Beute). Werte in `data/gegner/*.tres` (`characters/gegner_daten.gd`)
- [x] 4.2 Spaehdrohne (`characters/spaehdrohne.gd`, Funkenkugeln `characters/funkenkugel.gd`), Rammdrohne (`characters/rammdrohne.gd`, Sprint, betaeubt nach Wandtreffer, dann doppelter Schaden)
- [x] 4.3 Spieler-Schaden (`spieler.gd: schaden_nehmen`, Rueckstoss, 1.2 s Blinken), Dash (Q / Strg links / Pad B, 0.4 s unverwundbar), Tod -> Respawn am letzten Checkpoint (`levels/checkpoint.gd`, 4 Stationen ueber `levels/checkpoints.gd`), Checkpoints sind Heilstationen, jeder Mana-Kern heilt 1 Herz. Gurken-Schleim kostet jetzt auch 1 Herz. HUD: roter Bildrand bei Treffer, Meldungen
- [x] 4.4 Drohnen-Spawner (`levels/drohnen_spawner.gd`): Testraum (40, 138), Hafen (225, 25), Tower-Vorplatz (20, -150). Spaehdrohnen schiessen eingeschaltete Stromquellen aus (`PowerSource.stoeren()`), geloeste Tore bleiben offen
  Abnahme getestet (Skript, Slot 0, mehrere Laeufe): Spaehdrohne mit 3 Blitzen besiegt und verschwunden, Funkenkugel kostet 1 Herz, Dash blockt Treffer, Rammdrohne an Testraum-Wand betaeubt (Blitz macht 2 statt 1), Rammtreffer kostet 1 Herz, Mana-Kern heilt, Checkpoint gesetzt, Tod -> Respawn am Checkpoint mit 5 Herzen, `eingesammelt` und Mana-Kerne unveraendert, Checkpoint in `zu_dict`/`aus_dict` enthalten, Spawner erzeugt alle 10 s bis max. 2 Drohnen.
  Nicht getestet: echtes Spielen mit Tastatur/Pad (Dash-Taste, Ausweichen von Hand), Schreiben in einen echten Slot, Gurken-Schleim-Schaden im Spiel, Spawner Hafen/Tower im Spiel.

## Meilenstein 5: Story und Dialoge
- [x] 5.1 `Dialog` (Autoload `autoload/dialog.gd`, DialogueRunner + Neon-Textbox, Tippeffekt, Auswahlantworten, optionaler Audio-Pfad). Daten: `data/dialoge/*.tres` (`dialog_daten.gd`, `dialog_zeile.gd`). Format und Stimmen-Ablage: `docs/DIALOGE.md`. Spieler-Eingabe wird ueber `EventBus.eingabe_gesperrt` gesperrt
- [x] 5.2 `QuestManager` (Autoload), Quests in `data/quests/*.tres`, Zielanzeige im HUD unter dem Mana-Kerne-Panel, Fortschritt in `GameState` (`quest`, `quests_fertig`, `flags` in `zu_dict`/`aus_dict`)
- [x] 5.3 Intro (`levels/story.gd`, nur bei leerem Slot, Flag `intro_gesehen`, Esc ueberspringt) und drei Rollen-NPCs (`characters/rollen_npc.gd`, Platzierung `characters/rollen_npcs.gd`): Haendler (12, 122), Informant (-18, 111), Mechanikerin (22, 108). E = sprechen, Hinweis "E: SPRECHEN"
- [x] 5.4 Upgrade-Shop (`ui/shop_menue.gd`, Haendler-Dialog Antwort 1): Blitzschaden, Blitzreichweite, Ladegeschwindigkeit, je 3 Stufen (`data/upgrades/*.tres`), Kauf mit Mana-Kernen, im Spielstand gespeichert (`upgrades`), wirksam in `blitz.gd` und `spieler.gd` (Defaults unveraendert, Bonus 0 ohne Kauf)
- [x] 5.5 Journal (`ui/journal.gd`, Taste J / Pad Start): Reiter Ziele und Datenchips. `CollectibleData.lore` neu, Lore fuer `chip_01`, `chip_02`
  Abnahme getestet (Skript mit simulierten Eingaben, Slot 0, mit Screenshots): Intro laeuft und setzt Ziel "Sprich mit dem Informanten", Eingabe waehrenddessen gesperrt (0 m Bewegung bei gedrueckter Vorwaerts-Taste), Dialog mit allen drei NPCs per E-Taste, Ziel schreitet fort (Informant -> "Finde Grimoire-Seite 1" -> nach Seite 1 "Betritt den Neon-Basar"), Shop kauft 3 Upgrades (Mana 30 -> 17, Blitzschaden 1.0 -> 1.5, Blitzlebensdauer 0.9 -> 1.125, Ladezeit 1.0 -> 0.8), `zu_dict`/`aus_dict` behaelt Upgrades, Quest und Flags, Journal zeigt beide Chip-Loretexte.
  Nicht getestet: echtes Spielen mit Tastatur/Maus/Pad, Speichern in einen echten Slot und Neuladen (nur Dictionary-Rundlauf), Alt-Spielstand ohne Story-Felder, Audio-Wiedergabe (keine Sprachdateien vorhanden), Journal und Shop mit Pad.

## Ausserhalb des Konzepts (Minimap)
- [x] Minimap (HUD unten links, Taste M / Pad Back): dreht mit Blickrichtung, Bezirksfarben, Iggy (orange), Gurkenmonster (gruen), Sammelobjekte (gelb), Drohnen (rot)

Weitere Meilensteine: siehe `docs/KONZEPT.md`, Abschnitt 10.

## Ausserhalb des Konzepts bereits erledigt
- [x] Titelsong (Startbildschirm) und Hintergrundmusik im Spiel
- [x] Durchgang hinter dem Gurken-Wald, Plateau mit Neustadt
- [x] Sy-Ci Burgers in der Kernstadt
- [x] Gamepad-Grundbelegung (Stick, A, X/RT/RB, Y, Start im Menue), ungetestet mit echtem Pad
- [x] Mana-Kerne: Kristalle heissen jetzt Mana-Kerne (HUD, `GameState.mana_kerne`)
- [x] Steve (NPC im Sy-Ci Burgers, `characters/steve.gd`, Modell `Buerger_von_Synth-City`): sitzt am Tisch, isst Burger (3 Bisse, Burger schrumpft), trinkt dann aus einem Becher, Pause, wiederholt
- [x] Iggy Inferno als Platzhalter am Kern-Turm (`characters/iggy.gd`)
- [x] Burger-Bau-Minispiel (`ui/burger_minispiel.gd`): E am Bedienroboter an der Theke in Sy-Ci Burgers (`burger.gd`). 3 Bestellungen (4, 6, 8 Schichten), Zeitlimit, Fehlbau kostet 5 s. Belohnung bis zum ersten 3/3-Durchgang: 1 Mana-Kern je Burger, +3 Bonus
- [x] Aufzug am Zauber-Tower (`levels/aufzug.gd`, gebaut in `stadt.gd: _aufzug()`): Schacht an der Suedwand, Kabine vom Boden zur Oberkante Tier 2, Steg zum HQ (spaeter ersetzt, siehe unten). Die umlaufende Licht-Bahn (`_wendel()`) ist entfernt
  Abnahme getestet (Skript, headless): Spieler faehrt von y 0 auf y 160 und zurueck, Minispiel mit Zufallsbestellungen komplett durchgespielt (3/3, 6 Kerne), Fehlbau wird abgewiesen. Nicht getestet: Optik/Screenshot (Editor-Plugin war nicht verbunden), Bedienung mit Tastatur/Pad im echten Spiel, Fahrt mit Spieler in der Kabine bei laufender Eingabe.
- [x] Zauber-Tower: Eingang (Tor 6 x 5 m, Suedwand) und Lobby (`stadt.gd: _lobby()`, Stufen 1 und 2 sind jetzt hohle Huellen). Der Aufzug liegt innen (Schacht 5 m, nordlich der Turmmitte), Schiebetueren an beiden Haltestellen, Kabine endet direkt im HQ. Der aussenliegende Schacht und der Steg sind weg, um die HQ-Terrasse (Tier 2) steht ein Gelaender. Der Boden-Ring im HQ ist nach Sueden verschoben (wegen des Schachtlochs)
- [x] Ladeanimation: `ladeanimation.tscn`/`.gd` spielt `assets/video/intro.ogv` (aus der mp4 konvertiert, Ogg Theora) nach der Slot-Wahl, laedt `node_3d.tscn` im Hintergrund, Esc/Enter/Leertaste/Klick ueberspringt nach 0,8 s
  Abnahme getestet (Skript, headless): Strahl durch das Tor frei, Seitenwand fest. Aufzug faehrt Lobby -> HQ -> Lobby mit dem Spieler. Video laeuft (Position 4,3 s nach 4,5 s), Ueberspringen wechselt in die Spielszene. Nicht getestet: Optik (kein Screenshot), Ton des Videos, Gamepad-Skip.
- [x] Aen sitzt auf einer Parkbank (`characters/aen.gd`, gesetzt in `park.gd: _aen_setzen`, dritte gebaute Bank bei ca. (-124, -33)). Modell `imported_models/Aen_Character_Turnaround`, Animation `Sitting_Clap` als Schleife, Huefte wird per Skelett-Messung auf die Sitzflaeche gesetzt
  Abnahme getestet (Skript, headless): Aen steht an der Bank, Animation laeuft, Huefte 0,12 m ueber der Sitzflaeche. Nicht getestet: Optik (kein Screenshot), ob die Fuesse/Haende sauber sitzen.
- [x] Zauber-Tower Innenleben: 24 Buero-Etagen (13 in Stufe 1, 11 in Stufe 2, je 6 m Abstand) mit 4 Layouts (Grossraumbuero, Konferenz, Kantine, Rechenzentrum), von der Aufzugfahrt aus sichtbar (`levels/buero_etage.gd`, gebaut in `stadt.gd: _buero_etagen`). Lobby mit Marmorboden, Putzwaenden und Empfangstresen. Die Moebel sind pro Layout zu wenigen Meshes zusammengefasst und werden von allen Etagen geteilt (Cache), reine Optik ohne Kollision
- [x] Aufzug-Terminal: Computer mit Pult, Tastatur und Monitor in der Kabine (SubViewport-Bildschirm: Etage, Name, Hoehe, Status, Ziel, Uhrzeit, Schachtanzeige). Kabine mit Stahlblech-, Fliesen- und Deckentextur
- [x] Texturen: Poly-Haven-Sets (Marmor, Holz, Leder, Metall, Fliesen, Beton, Gummi, Rasen als Blattwerk) plus selbst erzeugte `assets/texturen/buero_*` (Teppich, Deckenplatte, Putz, 3 Bildschirminhalte, Whiteboard, Poster)
- [x] Neon im Tower reduziert: eigene gedaempfte Materialien (`m_cyan_turm`, `m_gold_turm`, `m_silber_turm`), Fassadenlicht und Lobby-Lampen schwaecher und warmweiss, Fassadenlicht mit kurzer Reichweite (leuchtete vorher durch die Waende in die Lobby), Innenmaterialien ohne Himmels-Ambient (`disable_ambient_light`)
  Abnahme getestet (Skript mit Screenshots auf echtem Display): Lobby, Kabine mit Terminal, Fahrt durch Etagen (Kantine, Grossraumbuero), HQ. Nicht gesehen: alle 24 Etagen einzeln, Rechenzentrum/Konferenz-Layout, Frame-Rate auf schwacher Hardware.

- [x] NEON-MARKT 24/7 (`neonmarkt.gd`, gebaut in `stadt.gd: _neonmarkt`, Position -100/92, Front nach Sueden, Sperrzone Kreis r52): 56 x 36 m, Glasfront mit Automatiktueren, Neonreklame (Pink/Cyan/Violett, Slogan "Einmal scannen, endlos strahlen"), Scanner-Tor, 5 Selbstscan-Kassen, 4 Regalgaenge (Energiezellen, Synth-Food, Snacks, ISA-Heldenbedarf Salz), Kuehltheke mit kuehler Milch, Gewuerzregal mit ausgebranntem Chili-Platz 4, Gemuesetheke unter pulsierendem Daempffeld, Holzkiste "Gurke Nr. 4" mit Absperrband, Express-Drohnen-Annahme, Lieferdrohnen-Deck auf dem Dach mit kreisenden Drohnen, Hoverboard-Drive-In. Per Screenshot geprueft, Headless-Lauf ohne Fehler.
- [x] Aufzug-Terminal: E in der Kabine oder an der Haltestelle (Kabine da) oeffnet eine Etagenauswahl (`ui/aufzug_wahl.gd`, Pfeile + E, Esc). Der Aufzug haelt jetzt an jeder Etage (`fahren_zu(index)`). Zwischenetagen: Kabine bleibt geschlossen (Schranke), Ausstieg nur Lobby und HQ.
- [x] Zauber-Tower aussen: Business-Look (dunkler Stahl, neutrale Fenster ohne Farbakzent, Eckpfosten dunkel, Leuchtstrahl entfernt, nur rote Flugwarnleuchte).
- [x] Tower-Foyer (`stadt.gd: _foyer`): Marmorboden mit dunklem Intarsienrahmen, Saeulen, Empfang mit Logowand, Sicherheitsschleuse vor dem Aufzug, Sitzgruppe mit Teppich, Pflanzen, Infotafel, Deckenleuchtenraster.
- [x] Tower-Etagen betretbar: jede Etage hat Bodenkollision (mit Schachtloch) und Moebel-Kollisionsboxen (`buero_etage.gd: _kb`), der Aufzug hat an jeder Etage eine Schiebetuer mit Kollisionswaenden (`aufzug.gd: _haltestelle_bauen(idx)`). Test (headless): Bodenstrahl auf Etage 5 trifft bei y 34,04, Ausstieg aus der Kabine auf die Etage klappt, Tuer geht auf. Ruf per E vor der Tuer holt die Kabine auf die jeweilige Etage.
- [x] Foyer realistischer: neue Poly-Haven-Texturen (`assets/texturen/foyer_*`: Putz, dunkle Holzpaneele, Holz, Leder, Granit), Wandsockel aus Holzpaneel, abgehaengte Deckenplatten, hellere Beleuchtung, Pflanzen aus Blattkugeln, Schrift nicht mehr spiegelverkehrt von hinten, Aufzugsschacht in hellerem Putzgrau.
- [x] Mechy McBoom (`characters/mechy.gd`, Dialog `data/dialoge/mechy.tres`, erzeugt in `stadt.gd: _foyer`): Wachmech aus `imported_models/meshy_model_1`, 2,6 m hoch, patrouilliert als Rundkurs vor dem Empfang im Tower-Foyer, bleibt bei E (Abstand 4 m) stehen, dreht sich zum Spieler und spricht zwei Zeilen. Test (Lauf): Rundkurs ueber alle vier Wegpunkte, Screenshot ok.
- [x] Schwebende Texte im Zauber-Tower entfernt (Lobby/Foyer-Schilder, Etagen-Schilder). Geblieben: Interaktionshinweise (Aufzug E, HQ-Geheimspruch, Mechy) und die Texte auf den HQ-Wandbildschirmen.
- [x] Kantine komplett neu (`levels/buero_etage.gd: _kantine/_kueche/_esstisch`): Kueche mit Herd, Haube, Kombidaempfer, Kuehlschrank und Fliesenwand, Essensausgabe (Warmtheke mit 8 Speisen als Texturen, Spuckschutz, Waermelampen, Tablettschiene, Tablettstapel, Kasse), Salatbar unter dem Speiseplan (Textur `kantine_speiseplan`, Wochenplan Mo-Fr mit Preisen), Getraenkestation mit Kaffeemaschine, Getraenkekuehlschrank, Automaten, Geschirrrueckgabe mit Tablettwagen, Muelltrennung, lange Esstische mit Stuehlen, gedeckten Tabletts und Haengeleuchten, Sitzecke, Uhr, Feuerloescher. Eigene Texturen `assets/texturen/kantine_*` (Edelstahl, Fliesen, Essen, Speiseplan). Kollision fuer alle grossen Moebel. Gilt fuer beide Kantinen (Etage 4 und 9 in Stufe 1, Etage 17 in Stufe 2). Zusaetzliche Lichter, Boden jetzt Beton.
- [x] NEON-MARKT 24/7 komplett neu gebaut (`neonmarkt.gd`): helle Halle (Deckenraster, Omni-Licht-Raster, Putzwaende, Fliesenboden), logische Aufteilung: Eingang links mit Wagenbox, Obst/Gemuese (Kisten, Daempffeld, "Gurke Nr. 4"), 6 Regalgaenge (Snacks, Getraenke, Konserven, Synth-Food, Energiezellen Unterstadt, Salz), Rueckwand mit Frischetheke, 5 offenen Kuehlregalen (kuehle Milch), Tiefkuehlwand, Backwaren, Ostwand Gewuerze (Chili-Platz 4 ausgebrannt), Kassenzone mit 5 Kassen und 2 Selbstscan, Drohnen-Annahme. Eingang und Ausgang als getrennte Schiebetueren mit Kollision (offene Fassade statt Innenverkleidung ueber die ganze Front). Kuehlregale ohne Glas ueber Produkten (Flimmerfehler weg). Schwebende Texte auf feste Haengeschilder reduziert. Aussen: Reklame, Vorplatz, Wagenbox, Drohnendeck, Hoverboard-Drive-In. Per Screenshot geprueft (Fassade, Tueren offen, Gaenge, Kuehlung, Kasse), Lauf ohne Fehler. Nicht geprueft: Begehen mit echtem Spieler (Tuer-Kollision), Frame-Rate.
- [x] Neon-Markt Nachbesserung: Dach und Attika haben Kollision (Strahltest trifft Dach bei y 7,4), Sockel unter der Glasfront ist an Ein- und Ausgang unterbrochen und die Schwelle liegt bodeneben (Querstrahl auf Knoechelhoehe durch beide Tueren frei, keine Stufe mehr). Neue selbst erzeugte Texturen `markt_boden_fliese` (Feinsteinzeug 60x60 mit Fugen und Sprenkeln, Normal/Rauheit) und `markt_decke_platte` (Mineralfaser-Rasterplatten mit Perforation). Nicht geprueft: Begehen mit echtem Spieler.

## Ausserhalb des Konzepts: Realismus, Kamera, Kollision, Gamepad, Touch (2026-11-15)
- [x] Kamera-Kollision (`kamera_arm.gd`): Kamera rutscht vor Waende/Decken, Figur wird bei Nahstand ausgeblendet.
  Test (headless): Ruecken an der Wassertank-Wand, Kamera bleibt 0,36 m vor der Wand statt 3,2 m dahinter; im Freien wieder 3,2 m.
- [x] Kollisions-Pruefung der ganzen Szene (Skript, 14.875 sichtbare Koerper geprueft). Ergaenzt: obere Stufe der Hochhaeuser, Waldstaemme (6.624 Baeume), Popcorn-Eimer, Wassertank-Deckel.
  Test (headless): Strahl von oben trifft das Hochhaus-Oberteil bei y 122, 14 von 20 Querstrahlen im Wald treffen Staemme.
  Bewusst ohne Kollision: Baumkronen, Buesche, Riesenbrezel, Dach-Burger, Daempffeld im Markt, Iggy (Platzhalter).
- [x] Gamepad: analoges Laufen (linker Stick, radiale Totzone), rechter Stick mit Kurve, alle angeschlossenen Pads, Rumble bei Treffer/Tod, Tastenhinweise wechseln je Geraet (E / Y / AKTION), Minimap und Tag/Nacht als Aktionen.
  Test (headless, simulierte Ereignisse): Geraetewechsel Tastatur/Pad/Touch, Hinweistext wechselt. Nicht getestet: echtes Pad in der Hand (Stick-Gefuehl, Rumble).
- [x] Touch-Overlay (`ui/touch_overlay.gd`): Lauf-Stick links, Wischen rechts, Knoepfe ZAUBER/SPRUNG/DASH/AKTION, oben JOURNAL/KARTE/HINWEIS; Menue-Modus mit Steuerkreuz, OK, ZURUECK.
  Test (headless, simulierte Finger): 8 m gelaufen, Wischen dreht 0,5 rad, Zauber laedt und feuert, Sprung 1,3 m, OK/Hoch im Menue-Modus. Screenshot geprueft. Nicht getestet: echtes Android-Geraet, APK-Export.
- [x] Optik: Pflaster-Boden, Asphaltstrassen mit Mittel- und Randlinien (Neon-Mittelstreifen entfernt), Flusswasser-Shader, Beton/Metall-Texturen fuer Stein und Aero-Ring, Rasen auf Handelsplatz/Gurken-Wald, Rinde/Laub im Wald, natuerlicherer Taghimmel, AgX-Tonemapping, weiche 4-Stufen-Schatten, SSAO und Spiegelungen (nur Stufe HOCH).
- [x] Leistung: Grafikstufen, Wald in Kacheln, Kleinteile mit Sichtweite, Lichter mit Distanz-Fade, Buesche mit weniger Dreiecken.
  Messung (AMD Renoir integriert, 1280x720, Stufe MITTEL): vorher ca. 25 FPS, jetzt 36 bis 43 FPS. Stufe HOCH auf diesem Rechner nur ca. 14 FPS.

## Ausserhalb des Konzepts: Flussufer, Strassennetz, Ampeln, Verkehr (2026-11-15)
- [x] Flussufer: abgesenktes Bett, Kaimauern, Gelaender mit Neonband, Rampen zum Wasser, Durchlaesse am Stadtrand.
  Test (headless, Strahlen): Boden im Flussbett bei y -1,5 statt 0, Kaimauer und Gelaender halten einen Querstrahl auf, Brueckenplatte liegt bei y 0,1. Screenshots geprueft (Kai, Stehen im Wasser).
- [x] Strassennetz: 11 Strassen mit Namen, alle Wahrzeichen angebunden, 9 Bruecken, Kreuzungsflaechen ohne ueberlappende Markierungen.
- [x] Ampeln an 13 Kreuzungen (Rot, Rot-Gelb, Gruen, Gelb), Fussgaengersignale, Zebrastreifen, Haltelinien, Strassenschilder, Bordsteine, Laternen (nachts mit Licht), Haltestellen, Holo-Wegweiser.
- [x] Bodenverkehr: 12 Schwebe-Autos, halten bei Rot.
  Test (headless, 70 s Spielzeit): keine Rotfahrt, jedes Auto stand zwischendurch; Synth-Bots legten 175 bis 329 m zurueck und fielen nicht ins Flussbett.
  Nicht getestet: von Hand durch die Stadt laufen, Autos und Spieler im Gedraenge, Abbiegen der Autos an vollen Kreuzungen (sie achten dort nur auf die Ampel, nicht auf Querverkehr anderer Rundkurse).
  Messung (AMD Renoir, 1280x720, Stufe MITTEL): unveraendert rund 28 bis 37 FPS, nachts mit Laternenlicht 35 FPS.

## Ausserhalb des Konzepts: begehbare Haeuser, Korrekturen, Realismus-Leitfaden (2026-11-15)
- [x] Wassertank: Stuetzen tragen den Tank (standen vorher neben dem Tank in der Luft), Hochhaus von der Runenstrasse gerueckt. Per Screenshot geprueft.
- [x] Sy-Ci Burgers: Schraege neben der Treppe entfernt (schlankes Gelaender, schmale Stufen-LEDs). Per Screenshot geprueft.
- [x] Popcorn-Labor begehbar, vier Etagen mit Treppenhaus und Labor-Einrichtung.
- [x] Buecherei, Museum und Stadtverwaltung auf frueheren Freiflaechen, alle begehbar.
  Test (headless, Spielfigur mit gehaltener Vorwaerts-Taste entlang von Wegpunkten): in allen vier Haeusern durch die Schiebetuer und ueber alle Treppen bis ins oberste Geschoss (Popcorn-Labor y 14,96, Buecherei 4,76, Museum 4,96, Stadtverwaltung 8,96). Aussen- und Innenansichten per Screenshot geprueft.
  Nicht getestet: von Hand durchlaufen, Kamera in den Treppenhaeusern, alle Moebel-Kollisionen einzeln.
- [x] Gamepad: Beschriftung je Pad-Familie, Meldung beim Verbinden.
  Test (headless): Familien-Erkennung aus dem Namen, Beschriftung wechselt, Meldungstext. Nicht getestet: echtes Pad. Der gekoppelte Pro Controller war waehrend der Arbeit nicht verbunden (`bluetoothctl`: Connected no, kein Eingabegeraet im System).
- [x] Realismus-Leitfaden (Downloads/godot_4_realismus_checkliste): umgesetzt sind Renderer-Pruefung, MSAA/FXAA, Schattenatlas und Schattenfilter, anisotrope Filterung, AgX mit Weisspunkt, Himmel als Umgebungslicht, SSAO/SSIL/SSR, SDFGI, volumetrischer Nebel, Glow 0,4, Schatten-Ueberblendung, Tangenten und LODs der Modelle (waren schon an), Schattenwurf der Modelle, Triplanar auf grossen Flaechen.
  Messung (AMD Renoir, 1280x720, Stufe MITTEL, alt und neu direkt nacheinander): 30,9 gegen 30,5 FPS. 16x anisotrop haette auf dieser Grafik 6 FPS gekostet (30 gegen 24) und gilt deshalb nur auf Stufe HOCH.
  Nicht umgesetzt: HDRI-Himmel, VoxelGI, Parallax-Hoehenkarten, Detail-Texturen, Subsurface Scattering, AO-Karten (Gruende in OFFENE_FRAGEN 58 bis 62). Stufe HOCH nur per Screenshot gesehen, Bildrate dort nicht gemessen.

## Ausserhalb des Konzepts: Asset-Pakete Krankenhaus, Strassen-Props, CityFolks (2026-11-15)
- [x] Krankenhaus-Set (Hospital_assets.zip, nur .blend plus Texturen): per Blender in einzelne GLBs zerlegt (Ursprung Mitte unten, Texturen auf 1024 px, 5 MB statt 560 MB; die UE5-Texturen und Displacement-Karten bleiben draussen). Die Set-Texturen sind Atlanten fuer die UVs der Teile, nicht nahtlos. Lader: `levels/krankenhaus_modelle.gd`.
- [x] Stadtklinik (`levels/krankenhaus.gd`, `KLINIK_POS` 62/-56, Front Sued zur Altstadtgasse): 2 Etagen, Anmeldung, Wartebereich, drei Untersuchungsraeume, Labor, vier Patientenzimmer, Stationstresen, Hubschrauberlandeplatz auf dem Dach. Boden und Decke aus den Kachel-Modellen des Sets (MultiMesh).
  Test (headless Lauftest): durch die Tuer, ueber die Treppe bis ins OG und in Zimmer 203 (y 4,16). Screenshots innen und aussen geprueft. Nicht getestet: von Hand durchlaufen, Kamera im Treppenhaus.
- [x] Strassen-Props (street-props-v2.zip): Hydranten (waterPump) und drei kleine Baustellen aus Absperrung und Leitkegel entlang der Strassen (`levels/strassen_deko.gd`, Lader `levels/strassen_props.gd`). Die Set-Ampel ist nicht eingebaut, weil die Stadt eigene Ampeln mit Phasensteuerung hat.
- [x] CityFolks (Alstra Infinite, 4 Figuren mit Skelett, ohne Animationen): 10 Buerger als Fussgaenger (`buerger.gd` erbt von `npc.gd`, Gehzyklus per Skelett). Der Ordner `imported_models/cityfolks/` steht in `.gitignore`, weil die Lizenz Weitergabe und Upload in Repos verbietet. Ohne den Ordner erzeugt `npcs.gd` keine Buerger.

## Ausserhalb des Konzepts: Niko-Stadt, Frosty-Cyber-Set, Burger-Rutsche (2026-11-15)
- [x] Sy-Ci Burgers: Die schraege Rutsche der Spielecke (cyanfarbene Platte neben der Treppe) ist entfernt. Per Screenshot geprueft; Turm und Bausteine bleiben.
- [x] "futuristic low poly city by niko" (.blend, 86 Objekte, 106k Dreiecke, nur einfache Farben): per Blender nach `imported_models/niko_stadt/niko_stadt.glb` exportiert, Materialien als Principled neu gesetzt und abgedunkelt. Als schwebende Fern-Kulisse hinter der Ostgrenze eingebaut (`levels/niko_kulisse.gd`, Mitte 455/55/-40, Massstab 0,55), ohne Kollision, ohne Schattenwurf. Per Screenshot von der Ostkante der Stadt geprueft.
- [x] FrostyCybrpackAssets_V2: nur die GLB-Ordner `props` (96 Kleinteile) und `cables` importiert (`imported_models/frosty`, 38 MB); `pipes`, `ice`, `walls_and_floors`, FBX, OBJ und glTF-Duplikate bleiben draussen. Lader `levels/frosty_props.gd`. Eingebaut in der Stadtklinik: Duck-Rechner, Bildschirme, PinPads, Holo-Pflanzen, Laser-Mixer, Batterielader, Neon-Ente, Pizzakarton und Dosen auf Tresen, Tischen und Schraenken.

## Nachbesserungen (2026-11-15, nach Rueckmeldung)
- [x] Niko-Kulisse schwebt nicht mehr: `levels/niko_kulisse.gd` setzt den Fuss auf die Gelaendehoehe bei x 455 (3 m eingesunken). Per Headless-Lauf ohne Fehler, Optik nicht im Spiel gesehen.
- [x] Sy-Ci Burgers: Die Treppe war ein massiver dunkler Keil und las sich von der Seite als Schraege. Jetzt offene Stufen (Trittplatte plus Setzstufe), Kollision unveraendert. Per Screenshot geprueft.
- [x] Zauber-Tower: Mensch-Maschinen-Scanner (`levels/scanner_schleuse.gd`) ersetzt die Stahlsaeulen der alten Schleuse. Gruppen "spieler" und "mensch" (Buerger) fahren die Tueren auf, "maschine" (Synth-Bots, Mechy, alle Gegner aus `enemy.gd`) bleibt draussen, rote Anzeige. Test mit Platzhalterfiguren: Maschine blieb vor dem Tor stehen, Spieler kam durch. Mit dem echten Spieler im Turm noch nicht getestet.
- [x] Neon-Distrikt: Gebaeude nutzen `gebaeude.gdshader` (PBR-Textur, Fenster mit Rahmen, Leuchtband) statt einfacher Toenung: Gewerbe Fassadenbeton, Wohnen Backstein, Industrie Betonplatten. Neue Shader-Parameter `y_offset` (Plateauhoehe), `dach_schwelle`, `tex_atlas`/`atlas_schwelle` (dunkle Palettenfarben der Kenney-Modelle bekommen keine Fenster). Per Screenshot geprueft.

## Ausserhalb des Konzepts: 6twelve, geheimer Abgang, Untergrund-Komplex (2026-11-15)
- [x] 6twelve (`levels/sechs_zwoelf.gd`, Lizenz des Modells unbekannt, vom Nutzer geliefert): Laden mit Parkplatz am Suedostrand (`LADEN_POS` 250/245, um 180 Grad gedreht, Eingang zum Schattenkai), Zufahrt als Asphaltstreifen, Sperrzone. Rasen, Baeume und Laub des Modells sind entfernt. Kollision aus den Modell-Meshes, unter y -0,1 abgeschnitten (sonst trifft das Fundament die Koepfe im Schacht), Glasfront mit Luecke an der Tuer.
- [x] Geheimer Abgang: Luke im Lagerraum hinten links unter dem Teppich. Taste "interagieren" in der Naehe hebt den Teppich an und klappt die Luke auf (Flag `abgang_entdeckt`). Dafuer hat die Stadtplatte ein Loch ueber der ersten Treppenspur, die Sohle ein Loch ueber dem Schacht, und das Terrain3D-Gelaende ist dort auf -40 abgesenkt (ein Kontrollkarten-Loch liess die Kollision stehen).
- [x] Untergrund-Komplex "SUB-ARCHIV Omega" (`levels/untergrund.gd`, Lader `levels/megakit.gd`, Modular SciFi MegaKit, CC0): 16 m tiefer Treppenschacht (8 Flaege), Lobby, Gang, Halle 56 x 36 m mit Saeulen, Stegen und Chrysalis auf dem Rundpodest, Serverraum, Labor, Lager, Quartier, Leitstelle. Karte als Textraster (4-m-Zellen). Test: kompletter Lauf vom Laden durch den Schacht in die Halle (Kapsel mit Physik, Spiel komplett geladen), Screenshots von Schacht, Lobby und Halle. Nicht getestet: Teppich-/Luken-Animation mit echtem Tastendruck, Raeume West, Ost, Sued und Nord von innen, Bildrate im Komplex.

## Nachbesserung 6twelve und Abgang (2026-11-15, nach Rueckmeldung)
- [x] Ursachen: Im Modell steckten noch eine Wald-Kulisse ("Background"), zwei grosse Strassenflaechen ("Asphalt"), Zebrastreifen, Hecken und Laternen der Originalszene. Der Fliesenboden des Modells deckte die Luke ab, das Gelaende war nur im Test abgesenkt (nicht im Spiel), und nur wenige Teile hatten Kollision.
- [x] `levels/sechs_zwoelf.gd` neu: Umgebung des Modells komplett entfernt, alle festen Teile mit beidseitiger Kollision (unter y 0,12 abgeschnitten), Hofmauer mit Kollision, Glasfront, Schiebetueren (Eingang, Lagertuer, Hintertuer) oeffnen bei Annaeherung, WC verschlossen, Thekenklappe frei. Fliesenboden mit echtem Loch ueber der Luke, Werbepylon an der Strasse.
- [x] Lage: `LADEN_POS` 250/211, die Parkplatzkante liegt am Gehweg des Schattenkais, Asphalt-Zufahrt ueber die ganze Parkplatzbreite. Abgang und Komplex wandern automatisch mit.
- [x] `stadt.gd: _terrain_loch`: Gelaende unter dem ganzen Komplex auf -40 abgesenkt, Kollision neu gebaut. Loch in der Platte ueber beiden Treppenspuren.
  Test im komplett geladenen Spiel (Kapsel mit den Massen des Spielers, Radius 0,5, Hoehe 1,9): Strasse, Eingang, hinter die Theke, Lagertuer, Luke (Hinweis sichtbar), Schacht, Lobby, Halle; Gegenprobe von aussen gegen die Hofmauer bleibt haengen. Screenshots aussen und an der offenen Luke. Nicht getestet: echter Tastendruck E mit dem Spieler, Kamera im engen Schacht, Kopffreiheit beim Springen (10 cm Luft am ersten Podest).
