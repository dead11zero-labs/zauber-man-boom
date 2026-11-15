# Bestand (Meilenstein 0.1, Stand 2026-11-07)

Godot 4.7.2 (Forward Plus, Jolt Physics), GDScript. Hauptszene: `res://startmenue.tscn`. Kein Git-Repo.
Fast die gesamte Stadt wird beim Start per Code gebaut (`stadt.gd`), nicht im Editor platziert.

## Szenen und Ablauf
| Pfad | Zweck |
|---|---|
| `startmenue.tscn` / `.gd` | Titelbild mit unsichtbaren Buttons (Start, Optionen, Laden: "bald verfuegbar"), Titelsong `assets/audio/titelsong.mp3` in Schleife |
| `node_3d.tscn` | Spielszene: Stadt, Spieler, Terrain, Wald, Kristalle, Gurkenmonster, SynthBots, Neustadt |
| `spieler.tscn` / `spieler.gd` | Zauber-Man (CharacterBody3D), Gruppe `spieler`, Signal `kristalle_geaendert` |
| `gurkenmonster.tscn` / `.gd` | Einziger Gegner bisher, lebt im Gurken-Wald |
| `npc.tscn` / `npc.gd`, `npcs.gd` | 7 Synth-Bots laufen auf Strassen-Knoten (keine Dialoge) |
| `kristall.tscn` / `.gd`, `sammler.gd` | Kristalle (182 laut HUD) per Zufall verteilt, Boden und Luft |
| `blitz.tscn` / `.gd` | Zauberblitz des Spielers (Area3D-Projektil) |
| `schleim.gd` | Schleimkugel des Gurkenmonsters, verlangsamt den Spieler |

## Skripte der Welt
| Pfad | Inhalt |
|---|---|
| `stadt.gd` (ca. 1300 Zeilen) | Synth-City: Boden, Fluesse, Strassen, Aero-Ring mit Autos, Runen-Plaza, Zauber-Tower mit Hauptquartier (HQ, Tuer, Hologramm), Brezel-Stand, Wassertank, Popcorn-Labor, Gurkenfeld, Floronia-Versteck, Viertel mit Fassaden-Shader, Tag/Nacht (Taste T), Hintergrundmusik, Stadtgrenze mit Lücke zum Neo-Distrikt |
| `park.gd` | Central Park (Wege, Teich, Pavillons, Fauna) |
| `burger.gd` | Sy-Ci Burgers (Kernstadt, bei Runen-Plaza), begehbar mit Galerie |
| `neustadt.gd` | Neo-Distrikt auf dem Plateau im Westen, gebaut mit Addon `citycrafter` |
| `terrain_form.gd`, `terrain_bauer.gd`, `wald.gd` | Gelaendeformel, Terrain3D-Baker (`bauen()`), Waldverteilung. Durchgang und Plateau sind Teil der Formel |
| `hud.gd` | Neon-HUD (nur Kristallzaehler) |
| `geo.gd` | Geometrie-Helfer (Kurven, Rohre, Baender) |
| Shader | `gebaeude`, `neon`, `boden`, `wasser`, `balken`, `exoblume`, `filmkorn`, `zuckerwatte` (`.gdshader`) |

## Autoloads
Nur `MCPRuntimeServer` (Addon `godot_mcp_toolkit`). `EventBus`, `GameState` usw. fehlen noch.

## InputMap (eigene Aktionen)
`zaubern` (Leertaste), `springen` (Shift links/rechts, Keycode 4194325), `interagieren` (E). Bewegung ueber `ui_up/down/left/right`; Maus dreht die Figur und neigt die Kamera. Schweben bei gehaltener Sprungtaste. `ui_cancel` gibt die Maus frei. Es gibt kein Dash, kein `hint`, kein `pause`. (Stand 0.1; inzwischen per `autoload/eingabe.gd`: `hinweis` H / linke Schulter, `dash` Q oder Strg links / Pad B.)

## Gegner, NPCs, Fahrzeuge
- Gegner: Gurkenmonster (20 HP, streift, schiesst Schleim, laesst 12 Kristalle fallen, wird wiederbelebt). Ein Endboss "im Kern-Turm" existiert nicht. Der Zauber-Tower mit Hauptquartier ist da, aber ohne Gegner.
- Seit Meilenstein 4: Drohnen (`characters/enemy.gd` als Basis, Spaeh- und Rammdrohne), Spawner und Checkpoints (`levels/`), Spieler hat 5 Herzen.
- NPCs: Synth-Bots ohne Rolle. Keine Haendler, Questgeber oder Dialoge.
- Fahrzeuge: nur Deko. Autos kreisen auf dem Aero-Ring (`stadt.gd`, Modelle in `imported_models/auto_*`), nicht fahrbar.

## Orte (Weltkoordinaten x = Ost, z = Sued, Norden ist -z)
Stadtplatte +-350, Grenze bei 320. Runen-Plaza (0, 70), Zauber-Tower (0, -240), Gurken-Wald (-318..-183, -312..-100), Brezel-Stand (-255, 30), Wassertank (240, -100), Popcorn-Labor (255, 40), Floronia-Versteck (0, 262), Sy-Ci Burgers (115, 72), Neo-Distrikt-Plateau Mitte (-712, -206) auf 22 m Hoehe, Durchgang bei z ca. -206.
Viertel (Stil): Hochhaus-Zentrum Nord, Altstadt (Brezel/Elixir), Ost-Viertel, Neon-Basar-artige Zukunftszone Suedost (`m_zukunft`), ueberwucherter Handelsplatz West, Schatten-Gassen Sued.

## Addons
`terrain_3d` (Gelaende), `citycrafter` (Stadtgenerator), `godot_mcp_toolkit`, `gdllm-godot-agentic-harness`, `markdownlabel`, `meshy-godot-plugin`, `pixel_ui_scifi`, `PixelDriftMetro`, `Starter-Kit-City-Builder-main`. Der Ordner `demo/` stammt von einem Addon.

## Abweichungen zum Konzept
- Die Stadt hat keine 5 Bezirke mit Areas, sondern Viertel im Code (Rects in `_viertel_bauen`).
- Namen im Code sind deutsch (`zaubern`, `springen`), das Konzept nennt englische Actions (`shoot`, `jump`).
- Spieler hat keine Lebenspunkte, Kristalle entsprechen grob den Mana-Kernen.

## Nachtrag Meilenstein 5 (Story und Dialoge)
- Autoloads neu: `Dialog` (`autoload/dialog.gd`), `QuestManager` (`autoload/quest_manager.gd`). Neue Aktion `journal` (J, Pad Start) in `autoload/eingabe.gd`.
- EventBus neu: `eingabe_gesperrt`, `dialog_gestartet/-beendet`, `story_ereignis`, `quest_geaendert/-abgeschlossen`, `upgrade_gekauft`. GameState neu: `quest_aktiv`, `quests_fertig`, `flags`, `upgrades` (alles in `zu_dict`/`aus_dict`).
- UI: `ui/neon.gd` (Stil-Helfer), `ui/shop_menue.gd`, `ui/journal.gd`, Zielanzeige in `hud.gd`.
- NPCs: `characters/rollen_npc.gd` und `rollen_npcs.gd` (Szene `node_3d.tscn`: Knoten `RollenNpcs`), Intro: `levels/story.gd` (Knoten `Story`). Die Synth-Bots (`npc.gd`, `npcs.gd`) bleiben unveraendert.
- Daten: `data/dialoge`, `data/quests`, `data/upgrades` (je mit eigener Resource-Klasse). `CollectibleData.lore` neu.

## Nachtrag Burger-Minispiel und Aufzug
- `ui/burger_minispiel.gd` (CanvasLayer, Gruppe `burger_minispiel`, Sperre `burger`), Flag `burger_minispiel_perfekt`. Ausloeser: `burger.gd` (Roboter-Kassierer, Reichweite 5.5 m, Taste `interagieren`). Story-Ereignis `minispiel:burger_fertig`.
- `levels/aufzug.gd` (Node3D mit AnimatableBody3D-Kabine), Instanz `Aufzug` unter `Stadt`, Position (0, 0, -219.5), Haltestellen y 0 und 160. Signale `fahrt_gestartet`, `angekommen`. Die Wendel-Bahn um den Tower (`_wendel()` in `stadt.gd`) gibt es nicht mehr.

## Nachtrag Tower-Eingang, Innenaufzug, Ladeanimation
- Zauber-Tower: Stufe 1 (y 0..90) und 2 (90..160) sind hohle Huellen (`_huelle`), Suedwand Stufe 1 hat das Tor. Lobby y 0..9, Decken mit Schachtloch (`_platte_mit_loch`). `Aufzug` steht jetzt bei (0, 0, -244.5), Schacht 5 m, `oben_y` = `HQ_BODEN` 160.2. Die alten Konstanten fuer den Aussenschacht und Steg gibt es nicht mehr.
- `ladeanimation.tscn`/`.gd` ist jetzt das Ziel von `startmenue.gd` (`SPIEL`) und wechselt dann zu `node_3d.tscn`. Video: `assets/video/intro.ogv` (Original-mp4 liegt nur in ~/Downloads).

## Nachtrag Aen
- `characters/aen.gd` (Node3D, Kind der Parkbank), Modell hat nur die Animation `Sitting_Clap`. Kein Dialog, keine Kollision.

## Nachtrag Tower-Etagen und Terminal
- `levels/buero_etage.gd` (Node3D je Etage, statischer Cache fuer Meshes/Materialien). Etagenhoehen: Stufe 1 y 10 + 6k (k 0..12), Stufe 2 y 90 + 6k (k 0..10), Konstanten in `stadt.gd` (`ETAGEN_*`). Aufzug bekommt `etagen_y`/`etagen_name` fuers Terminal (Index 0 Lobby, letzter HQ).
- Aufzug hat jetzt nur noch Haltestellen Lobby und HQ, Zwischenetagen sind Kulisse (offene Kabinenfront waehrend der Fahrt durch Schranke gesperrt).
- Neue Texturordner `assets/texturen/buero_*` (Python-erzeugt, Skript nicht im Projekt).

## Nachtrag Neon-Markt, Etagenwahl, Foyer
- `neonmarkt.gd` (Node3D, Konstanten oben im Skript, keine Exporte/Signale; Neubau mit Gondelregalen, Kuehlregalen, Kassenzone, Automatiktueren). Texturen `assets/texturen/markt_*` (Poly Haven) und `markt_prod_*` (Python-erzeugt Produktreihen).
- `ui/aufzug_wahl.gd` (CanvasLayer, Signal `gewaehlt(index)`, Exporte `namen`, `aktuell`, Sperrgrund "aufzug"). `levels/aufzug.gd` hat `fahren_zu(idx)`, `fahren(bool)` bleibt als Huelle.
- `stadt.gd`: `MARKT_POS`, `_neonmarkt()`, `_foyer()`; Materialien `m_cyan_turm`/`m_silber_turm` jetzt dunkel/neutral (Business-Look).
- `characters/mechy.gd` (CharacterBody3D, Exporte `modell`, `wegpunkte`, `tempo`, `dialog_id` u. a.), Dialog `data/dialoge/mechy.tres`. Nutzt `imported_models/meshy_model_1`.

## Nachtrag Realismus, Kamera, Kollision, Gamepad, Touch (2026-11-15)
- Kamera: `kamera_arm.gd` am Knoten `KameraArm` in `spieler.tscn` (Exporte `laenge`, `radius`, `min_abstand`, `rueck_tempo`, `nah_grenze`, `maske`; Signal `naehe_geaendert(nah)`). Tastet mit einer Kugel zur Wunschposition, bewegliche Koerper werden uebersprungen. Steckt die Kamera dicht an der Figur, blendet `spieler.gd` das Modell aus. Near-Ebene 0.1.
- Eingabe: `autoload/eingabe.gd` hat jetzt `bewegung()`, `blick()`, `touch_blick_nehmen()`, `taste(aktion)`, `hinweis_binden(label, aktion, format)`, `vibrieren()`, Signal `geraet_geaendert`, Enum `Geraet` (TASTATUR, PAD, TOUCH). Neue Aktionen `minimap` (M, Pad Back) und `tageszeit` (T, rechter Stick gedrueckt). `spieler.gd` fragt Laufen/Umsehen nur noch ueber `Eingabe` ab.
- Touch: `ui/touch_overlay.gd` (CanvasLayer, Kind von `Eingabe`, Ebene 60). Sichtbar nur, wenn Touch das zuletzt benutzte Geraet ist. Am PC testbar mit Startparameter `-- --touch`.
- Grafik: `stadt.gd` hat `enum Grafik { NIEDRIG, MITTEL, HOCH }`, Automatik in `_grafik_stufe()` (Projekteinstellung `zauber_man/grafik_stufe` 0..2 uebersteuert). `_sichtweiten()` setzt Sichtweiten fuer Kleinteile und Distanz-Fade fuer Punktlichter. Neue Shader `boden_stadt.gdshader`, `strasse.gdshader`, `fluss.gdshader`; `boden.gdshader` (Neon-Raster) liegt noch im Projekt, wird aber nicht mehr benutzt. Neue Texturen `assets/texturen/strasse_asphalt`, `boden_pflaster`.
- Wald: `wald.gd` baut Kacheln (96 m) mit Sichtweite 650 m, Stamm-Kollision ueber einen PhysicsServer-Koerper, Rinde/Laub-Texturen je Flaeche.
- Projekteinstellungen: Querformat (`window/handheld/orientation`), ETC2/ASTC-Import fuer Android.

## Nachtrag Flussufer, Strassennetz, Ampeln, Bodenverkehr (2026-11-15)
- Boden: Die Stadtplatte ist keine Box mehr, sondern eine Flaeche mit ausgeschnittenen Flusslaeufen (`stadt.gd: _flaeche`, `_polygon_mesh`, Dreiecks-Kollision). Darunter liegt die Sohlenplatte (Box, Oberkante y -1,45). Achtung: Das Terrain3D-Gelaende liegt unter der Platte auf y -1,5, tiefer kann das Flussbett ohne neues Terrain-Backen nicht werden.
- Fluesse (`stadt.gd: _fluesse`, Konstanten `FLUSS_*`, `KAI_*`, `GELAENDER_*`, `RAMPE*`): Wasserspiegel y -0,7, Kaimauern mit Abdeckstein, Gelaender mit Neonband und Kollision (Luecken an Strassen und Rampen), vier Rampen zum Wasser (`RAMPEN`), Stirnwaende mit Tunnelmund am Stadtrand. Fuer Gebaeude gesperrte Breite jetzt 24 m.
- Strassennetz: Daten in `levels/strassen_daten.gd` (`class_name StrassenDaten`: `STRASSEN`, `ROUTEN`, `HALTESTELLEN`, `WEGWEISER`, statische Helfer `kreuzungen()`, `auf_strasse()`, `breite_bei()`). 11 Strassen, 19 Kreuzungen/Ecken, 13 davon mit Ampel. Neue Strassen: Tower-Allee (z -206, bis zum Durchgang), Schattenkai (z 198), Hafenstrasse (x 205), Osttangente (x 300), Brezelweg (x -300), Altstadtgasse (z -30), zwei Stichstrassen. Zauber-Allee reicht jetzt bis z 236.
- Bau: `levels/strassennetz.gd` (Knoten `Stadt/Strassennetz`, vor dem Einhaengen gesetzt: `fluesse`, `fluss_breite`, `fluss_tiefe`, `aussparungen`; Methode `nacht_setzen(an)`). Fahrbahnen, Kreuzungsflaechen, Zebrastreifen, Haltelinien, Ampelmasten mit Fussgaengersignal und Strassenschild, Bordsteine, 86 Laternen, 9 Bruecken, 5 Haltestellen, 6 Holo-Wegweiser.
- Ampeln: `levels/ampel_steuerung.gd` (Knoten `AmpelSteuerung`, Signal `phase_geaendert(ns, ow)`, `enum Zustand`, `material(schluessel)`, `zustand(achse)`). Alle Ampeln laufen im selben Takt, Umlauf 38 s.
- Bodenverkehr: `vehicles/verkehr.gd` (Knoten `Verkehr`, Eingang `kreuzungen`, Methode `ampel_phase`). 12 Schwebe-Autos auf 4 Rundkursen, Rechtsverkehr, halten bei Rot, hinter dem Vordermann und vor Knoten der Gruppen `spieler` und `verkehr_hindernis`.
- Synth-Bots (`npc.gd`): `KNOTEN`/`KANTEN` folgen dem neuen Netz inklusive Bruecken, Bots laufen auf dem Gehweg und sind in der Gruppe `verkehr_hindernis`.
- Ring-Stuetzen stehen nicht mehr auf Strassen oder im Flussbett.
- Git: Repo angelegt (Branch `main`), `.claude/settings.local.json` ist ignoriert.

## Nachtrag begehbare Haeuser, Wassertank, Pad-Familien, Realismus-Leitfaden (2026-11-15)
- Basis `levels/haus.gd` (ohne `class_name`, Unterklassen per `extends "res://levels/haus.gd"`): baut in `_rohbau(b, t, etagen, hoehe, tuer_x, tuer_b)` Aussenwaende mit Fensterbaendern (`fenster_hinten`, `fenster_seiten` abschaltbar), Decken mit Treppenloch, Dach mit Attika, Glas-Schiebetuer und das Treppenhaus hinten links (zwei Laeufe mit Zwischenpodest je Etage, Rampe als Kollision, Stufen als Optik). Unterklassen ueberschreiben `_bauen()` und optional `_leben(delta)`. Moebel-Helfer: `_tisch`, `_stuhl`, `_schreibtisch`, `_buecherregal` (Buecher als ein MultiMesh, am Ende `_buecher_bauen()`), `_vitrine`, `_bank`, `_pflanze`, `_bild`, `_schild`, `_theke`, `_innenwand`, `_deckenlicht`, `_licht_raster`, `_portikus`, `_fahne`. Front zeigt lokal nach +z.
- `stadt.gd: _haus(skript, pos, dreh)` setzt ein Haus; `_oeffentliche_gebaeude()` baut Buecherei (`BUECHEREI_POS` -33/-40, Front Ost), Museum (`MUSEUM_POS` -38/-182, Front Nord) und Stadtverwaltung (`RATHAUS_POS` 42/0, Front West). Drei neue Sperr-Rechtecke in `_sperrzonen`.
- `levels/popcorn_labor.gd` (Knoten `PopcornLabor`, 34 x 34 m, 4 Etagen je 5 m, darueber Technikgeschoss und der alte Popcorn-Eimer): Empfang mit Mais-Silos, Chemielabor, Reaktor mit springendem Popcorn, Analyse mit Serverraum. Ersetzt den frueheren geschlossenen Block in `_popcorn()`.
- `levels/buecherei.gd` (`Buecherei`, 32 x 22 m, 2 Etagen), `levels/museum.gd` (`Museum`, 36 x 20 m, 2 Etagen, Rueck- und Seitenwaende ohne Fenster), `levels/rathaus.gd` (`Rathaus`, 36 x 26 m, 3 Etagen; der Stadtplan im Buergerbuero wird aus `StrassenDaten.STRASSEN` gezeichnet).
- Wassertank: Position jetzt `TANK_POS` (240/-126, vorher z -100 und damit halb auf der Runenstrasse). Stuetzen stehen bei +-8 m unter dem Tank, mit Fussplatten, Kreuzverband und Tragring.
- Sy-Ci Burgers: Treppengelaender aus Pfosten und Holmen statt schraeger Glas- und Neonplatten (`GELAENDER_H`, `GELAENDER_PFOSTEN_JE`, `STUFEN_LED`).
- `autoload/eingabe.gd`: `enum PadFamilie`, `pad_familie`, `familie_von(name)`, Signal `pad_verbindung(name, verbunden)`, Tabelle `PAD_TASTEN` (Nintendo, PlayStation), Meldung am unteren Bildrand beim Verbinden und Trennen.
- Rendering: `project.godot` steht auf den Werten des Realismus-Leitfadens (4x MSAA, FXAA, Schattenatlas 4096, weiche Schatten Stufe 3, 16x anisotrop). `stadt.gd: _umgebung` schaltet fuer MITTEL und NIEDRIG zur Laufzeit zurueck (kein MSAA, 4x anisotrop, Schattenfilter "niedrig"). Nur Stufe HOCH: SDFGI, SSIL, volumetrischer Nebel, Kaskaden-Ueberblendung. Glow fuer alle Stufen von 0,7 auf 0,4. `_modelle_schatten()` schaltet Schattenwurf fuer alles aus `imported_models/` ein.
- Krankenhaus-Set: `imported_models/krankenhaus/*.glb` (28 Teile, Ursprung Mitte unten) und `texturen/<Ordner>/` (1024 px). `levels/krankenhaus_modelle.gd` (ohne `class_name`, per `preload`): `laden(teil)`, `masse(teil)`, `mesh(teil)`, `material(name, kachel, tint)`; Texturen werden nach Material-Name im GLB zugewiesen. `levels/krankenhaus.gd` (`Krankenhaus`, 32 x 20 m, 2 Etagen je 4,2 m) nutzt es; `KLINIK_POS` in `stadt.gd`, ein Sperr-Rechteck in `_sperrzonen`.
- Strassen-Props: `imported_models/strassen_props/` (Absperrung, Leitkegel, Ampel, Wasserpumpe = Hydrant). `levels/strassen_props.gd` setzt Ursprung und Hoehe, `levels/strassen_deko.gd` (`StrassenDeko`) verteilt Hydranten und Baustellen nach Strassenname und Anteil `t`; `stadt.gd: _strassen_deko()`.
- Buerger: `buerger.tscn` und `buerger.gd` (erbt von `npc.gd`), Modelle aus `imported_models/cityfolks/` (nicht im Repo), `npcs.gd` erzeugt `ANZAHL_BUERGER` (10) davon, wenn der Ordner existiert.
