# Offene Fragen

Beantwortet (2026-11-07): Hauptgegner ist Iggy Inferno (Chili-Wesen, Notion). Neo-Distrikt = Bezirk 2 Neon-Basar. Kristalle = Mana-Kerne. Deutsche Input-Namen bleiben. Git kommt spaeter. Gamepad wird mitgebaut.

Entschieden (2026-11-07): Iggy hat das Grimoire zerrissen, weil Magie-Strom sein Feuer verstaerkt; Milch-Schwaeche als Raetsel in Boss-Phase 3. Gurken-Monster bleibt Mini-Boss in Bezirk 1. Hafen/Untergrund vorerst als Zuordnung auf vorhandene Stadtteile. Tor am Durchgang bis Seite 1 (umgesetzt). Sprachausgabe: ja.

1. Sprachausgabe (entschieden 2026-11-07): hochwertige KI-Stimmen als vorab erzeugte Audiodateien, keine System-TTS. Dialogzeilen in `.tres` mit Text plus Audiopfad. Offen: welcher Dienst/welches Tool erzeugt die Stimmen (z. B. ElevenLabs oder ein lokales Modell) und welche Stimmen fuer Zauber-Man und Iggy. Wird in Meilenstein 5 (`DialogueRunner`) relevant.
2. Spielstand (entschieden 2026-11-07): 3 Slots, umgesetzt. Ungetestet: Slot-Menue im echten Spiel, Gamepad-Bedienung.
3. Die Platzhalter-Objekte (3 Runen, 2 Chips, Seite 1) liegen auf der Runen-Plaza in `collectibles/sammelobjekte_platzierer.gd` und wandern mit Meilenstein 6 an ihre echten Orte.
4. Rechte am Song "Drohnen und Kabel" und Verwendung der beiden Songs.
5. Hinweis-Pulse kommt bisher nur per Taste H. Soll nach 60 s Stillstand ein Hinweis-Symbol im HUD erscheinen?
6. Geloeste Raetsel bleiben offen (Tor bleibt nach Loesung geoeffnet). Passt das, oder sollen manche wieder zufallen?
7. Kampf-Balancing (Meilenstein 4, Werte in `data/gegner/*.tres`): Wer still steht, verliert an einem Spawner mit 2 Drohnen ca. 3 Herzen in 11 s. Zu hart oder ok? Feintuning eigentlich in 6.3.
8. Rammdrohne laut Konzept erst ab Akt 2, sie fliegt aber schon jetzt am Testraum und am Hafen mit (zum Testen). Im Startviertel rausnehmen?
9. Rammdrohne nimmt immer Schaden, betaeubt doppelt. Alternative: nur im betaeubten Zustand verwundbar (mehr Raetsel-Gefuehl, aber zaeher). Was ist gewuenscht?
10. Heilung: jeder Mana-Kern heilt 1 Herz, Checkpoints heilen voll. Soll Heilung eher selten sein (z. B. nur jeder 5. Kern)?
11. Dash-Taste: Q und Strg links (Shift ist Springen). Passt das, oder lieber andere Taste?
12. Checkpoint-Orte sind Platzhalter (Start, Gurken-Wald-Rand, Popcorn-Labor, Tower-Vorplatz) und wandern mit Meilenstein 6.
13. Das Gurkenmonster ist noch kein `Enemy` (eigene Logik, kein Kurzschluss-Tod), richtet aber per Schleim jetzt 1 Herz Schaden an. Bei Meilenstein 6 (Mini-Boss) auf die Basisklasse umziehen?
14. Meilenstein 5, Stimmen: Der Audio-Haken ist da (`DialogZeile.audio`, Ablage-Vorschlag `assets/stimmen/<dialog_id>_<zeilennr>.ogg`, siehe `docs/DIALOGE.md`). Offen bleibt, welcher Dienst die Stimmen erzeugt, und ob der Runner fehlende `audio`-Pfade automatisch nach dieser Namensregel suchen soll (dann muessten die `.tres` nicht angefasst werden).
15. NPC-Namen: Die Mechanikerin ist jetzt Clarissa (Kybernetik-Expertin, Mutter von Aen, Modell `imported_models/Cybernetic_Rebel_Character_Sheet`). Haendler und Informant heissen nur nach ihrer Rolle. Sollen es Figuren aus der Charakterdatenbank sein (z. B. Aen)? Dialogtexte sind Platzhalter im frechen Ton.
16. NPC-Orte (Haendler (12, 122), Informant (-18, 111), Mechanikerin (22, 108)) und Optik (Primitives mit Neon, wirkt noch dunkel) sind Platzhalter bis Meilenstein 6.
17. Upgrade-Werte (Kosten 4 bis 25 Mana-Kerne, Bonus +25 bis +200 Prozent) sind geraten und gehoeren in 6.3 ins Balancing. Upgrades "Max. Lebenspunkte" und Fahrzeug-Tempo/Boost aus dem Konzept fehlen noch (Fahrzeuge existieren nicht).
18. Questkette ist nur der Anfang (Informant, Seite 1, Neon-Basar betreten). Wer gibt die weiteren Ziele? "Pro Bezirk 1 Questgeber" laut Konzept, Rollen kommen mit Meilenstein 6/7.
19. Journal-Taste: J, Pad Start (Back = Minimap, Y = interagieren). Passt das? Das Journal hat noch keinen Reiter fuer Runen oder Karte.
20. Alte Spielstaende ohne Story-Felder gelten als "Intro gesehen" und starten die Questkette beim Laden. Passt das, oder soll das Intro auch dort laufen?
21. Intro-Dauer: ca. 5 s Blende plus 5 kurze Dialogzeilen, Esc ueberspringt. Zu lang, zu kurz? Das Konzept erlaubt bis 30 s.
22. Steve hat keinen Dialog (nur Deko-NPC im Restaurant). Soll er ansprechbar sein und eine Rolle bekommen (z. B. Gerüchte über Iggy)?
23. Clarissas Modell hat nur die Animation "Running". Aktuell leichtes Atmen/Kopfwiegen per Code. Besser: eine Idle-Animation (z. B. Mixamo "Idle", gleiches Skelett) und optional "Talking".
24. Burger-Minispiel: Belohnung (1 Kern je Burger, +3 bei 3/3, nur bis zum ersten fehlerfreien Durchgang) und Schwierigkeit (Zeit 36/52/68 s) sind geraten. Danach gibt es nur Punkte, keine Bestenliste. Soll es eine geben (Spielstand), oder weitere Rezepte/Kunden mit Namen?
25. Burger-Minispiel: Bedienung per Pfeile/Zifferntasten/E, Rueckschritt oder Dash nimmt eine Schicht zurueck. Mit Pad ungetestet.
26. Aufzug: Er fuehrt nur zwischen Boden und HQ (kein Halt auf Ringhoehe 14 m). Die Licht-Bahn um den Turm wurde auf Wunsch entfernt, der alte Anschluss vom Aero-Ring an den Turm fehlt damit auch. Falls Spieler per Hoverboard/Ring zum Turm sollen, braucht es dort einen Halt. Kabinenfahrt dauert ca. 7 s.
27. Ladeanimation: Das Video laeuft einmal je Spielstart (auch bei geladenem Spielstand), Ueberspringen erlaubt. Das Video (8 s) ist nur die Ablenkung, der eigentliche Stadtaufbau (einige Sekunden) friert danach das letzte Bild mit "LADE SYNTH-CITY" ein. Soll das Video nur beim ersten Start (neuer Slot) laufen, und braucht der Aufbau einen echten Fortschrittsbalken?
28. (erledigt: Foyer gebaut.) Zwischen Lobby und HQ gibt es jetzt Stopps an allen Etagen; Stufe 3 und Spitze fehlen weiter.
29. Aen: Das Modell bringt nur "Sitting_Clap" mit, er klatscht also dauernd. Eine ruhige Sitz-Idle (Mixamo, gleiches Skelett) waere besser. Soll Aen ansprechbar sein (Dialog, Verbindung zu Clarissa als Mutter, siehe Frage 15)?
30. Ladebalken fuer den Stadtaufbau: noch offen. Machbar waere ein Ladebildschirm in der Spielszene, der pro Bauschritt in `stadt.gd` (`_ready`) einen Frame wartet und den Fortschritt als Balken mit Prozent zeigt. Der Aufbau friert heute das Bild ein, weil er in einem Rutsch laeuft.
31. Tower-Etagen sind nur Kulisse (keine Haltestellen, keine NPCs). Sollen einzelne Etagen spaeter anhaltbar werden (z. B. Quest-Etage, Labor, Dachterrasse)? Der Aufzug-Computer hat jetzt eine Etagenauswahl (siehe 36).
32. HQ (Glasraum oben) ist weiter sehr hell (Himmel plus Glas). Soll es ebenfalls gedaempft werden, oder bewusst hell bleiben?
33. Rechte der selbst erzeugten Buero-Texturen: eigene Erzeugung, keine Fremdrechte. Poly-Haven-Texturen bleiben in `assets/texturen/QUELLEN.txt` (Buero-Eintrag fehlt noch).
34. Neon-Markt: Betreten ist frei, es gibt noch keine Kauf-/Dialogfunktion (kein Verkaeufer, kein Shop). Sollen Salz und kuehle Milch dort kaufbar sein (Heldenbedarf, Quest Iggy Inferno)? Der Notion-Text nennt auch Flora Finsternis als Kundin, sie ist nicht eingebaut.
35. Neon-Markt: Drohnen und Hoverboards sind reine Kulisse (keine Lieferquest, kein Mitfahren). Die Waren in den Regalen sind Bildtexturen, keine einzelnen Objekte.
36. Etagen sind betretbar, aber nur Boden und Moebel kollidieren (keine Tueren zu Nebenraeumen, keine NPCs, keine Interaktion mit Computern/Automaten). Es gibt nur 4 Layouts fuer 24 Etagen. Sollen einzelne Etagen eigene Inhalte bekommen (Quest, Labor, Dachterrasse)?
37. Tower-Aussenansicht: Fenster kommen aus dem gemeinsamen Gebaeude-Shader (`gebaeude.gdshader`), Farbe jetzt neutral. Die Nachbargebaeude der Stadt sind weiter bunt. Soll die ganze Skyline gedaempft werden?
38. Foyer: Texturen sind Poly-Haven-CC0 (siehe `QUELLEN.txt`). Der Empfang ist noch unbesetzt, soll dort ein NPC (Empfangsdame/Wachmann) stehen?
39. Mechy McBoom: Das Modell ist ein statisches Mesh ohne Skelett, das Gehen ist nur Wippen und Schaukeln per Code. Ein riggtes Modell (Meshy Auto-Rig mit Walk/Idle) waere sauberer. Er reagiert nicht auf Zauber-Blitze und kennt keine Quest. Soll er das Hauptquartier bewachen oder Spieler ohne Ausweis aufhalten?
40. Kantine: Der Speiseplan ist eine Textur (Woche 47 fest, Gerichte frei erfunden, u. a. "Gurken-Gulasch (Gurke Nr. 4)"). Soll er nach Spielzeit wechseln oder Texte aus einer Datei lesen? Es gibt keine Koeche oder Gaeste als NPC und keine Kauf-Funktion. Die Speisen sind Bildtexturen, keine einzelnen Objekte.
41. Neon-Markt: Produkte sind Bildtexturen auf Regalflaechen (keine einzelnen Objekte), nichts ist kaufbar. Soll der Markt Einkaufs-Interaktion (Salz, kuehle Milch, Energiezellen) und Personal (Kassierer, Schote) bekommen?
42. Neon-Markt aussen wirkt im Test dunkel (nur Neon und Laternen). Im Stadtlicht ggf. pruefen, ob die Fassade heller sein soll.
43. Android: Es gibt noch keine `export_presets.cfg` (braucht Android-SDK, Export-Vorlagen, Keystore). Der Mobile-Renderer laeuft mit Stufe NIEDRIG; ob die Stadt (viele Lichter, 2 GB Texturen) auf einem Handy fluessig laeuft, ist ungetestet. Welches Zielgeraet?
44. Touch: Spielstand loeschen im Startmenue geht nur per Entf/Y, nicht per Finger. Tag/Nacht hat keinen Touch-Knopf. Gewuenscht?
45. Steuerung bleibt "Panzer" (links/rechts dreht die Figur). Mit Pad und Touch waere freies Laufen relativ zur Kamera ueblicher. Umbauen?
46. Grafikstufe HOCH (SSAO, Spiegelungen) kostet auf der integrierten AMD-Grafik rund 10 FPS und ist dort automatisch aus. Soll es ein Optionsmenue fuer die Stufe geben (der OPTIONEN-Knopf im Startmenue ist noch leer)?
47. Die Stadt bleibt bunt (Neonfenster, leuchtende Plaza-Ringe, Zuckerwatte-Baeume). Fuer mehr Realismus muessten die Fensterfarben im Fassaden-Shader und die Emissionen gedaempft werden (siehe auch Frage 37). Wie weit soll das gehen?
48. (erledigt 2026-11-15: Flussbett mit Kaimauern, Gelaendern, Rampen und Bruecken.)
49. Iggy hat keine Kollision (laeuft als Platzhalter im Kreis), Buesche und Baumkronen sind durchlaessig. Ok so?
50. VRAM-Verbrauch liegt bei ca. 1,8 GB (von 2 GB auf dem Testrechner). Texturen kleiner importieren?
51. Flusstiefe: Das Bett ist nur 1,45 m tief (Wasser 0,75 m), weil das Terrain3D-Gelaende unter der Stadtplatte auf y -1,5 liegt. Fuer ein tieferes Bett muesste das Terrain unter der Stadt neu gebacken werden. Gewuenscht?
52. Der Testraum (`levels/test_aufbau.gd`, z 130..155) steht auf bzw. direkt neben der Marktstrasse, die Rollen-NPCs stehen nahe der Kreuzung Zauber-Allee/Marktstrasse, der Spieler startet mitten auf der Zauber-Allee. Autos bremsen fuer den Spieler, aber der Startplatz sollte mit Meilenstein 6 auf einen Gehweg oder die Plaza wandern.
53. Die Zauber-Allee fuehrt weiter ueber die Runen-Plaza (Obelisk in der Mitte). Der Autoverkehr meidet diesen Abschnitt. Soll die Plaza eine Fussgaengerzone mit Pollern bleiben oder einen Kreisverkehr bekommen?
54. Alle Ampeln schalten gleichzeitig (eine Achse hat stadtweit Gruen). Versetzte Phasen je Kreuzung waeren realistischer. Fussgaenger (Synth-Bots) beachten die Ampeln nicht.
55. Die Strassennamen (Zauber-Allee, Tower-Allee, Runenstrasse, Marktstrasse, Schattenkai, Hafenstrasse, Osttangente, Brezelweg, Altstadtgasse) sind von mir erfunden. Passen sie zur Welt?
56. Der Westen (Gurken-Wald, Handelsplatz) hat nur Brezelweg und Tower-Allee, die Altstadt nördlich der Runenstrasse keine Querstrasse. Mehr Nebenstrassen wuerden Gebaeude kosten.
57. Durch die neuen Sperrstreifen fuer Strassen und Ufer sind einige Gebaeude weggefallen oder haben andere Hoehen (gleicher Zufallsstartwert, andere Reihenfolge).
58. Realismus-Leitfaden, HDRI-Himmel: Der Himmel bleibt prozedural, weil Tag/Nacht (Taste T) die Himmelsfarben umschaltet. Ein HDRI-Panorama braeuchte je eines fuer Tag und Nacht (z. B. Poly Haven, CC0) und einen Import im Editor. Gewuenscht?
59. Realismus-Leitfaden, VoxelGI fuer Innenraeume: braucht gebackene Daten aus dem Editor, die Haeuser entstehen aber erst zur Laufzeit per Code. Innen leuchten deshalb Deckenleuchten ohne Schatten. Auf Stufe HOCH laeuft SDFGI.
60. Realismus-Leitfaden, Parallax und Detail-Texturen: Die Poly-Haven-Sets liegen nur als Farbe/Normal/Rauheit vor (keine Hoehenkarte), und Godot kann Parallax nicht zusammen mit Triplanar. Hoehenkarten nachladen und Boeden auf feste UVs umstellen?
61. Realismus-Leitfaden, Meshy-Figuren: Alle Modelle haben Farb-, Normal-, Rauheits- und Metallkarte, aber keine AO-Karte und keine Hautmaske. Subsurface Scattering wuerde deshalb die ganze Figur treffen (auch Kleidung und Metall) und ist aus. Iggy (FBX) hat nur eine Farbtextur.
62. Glow ist von 0,7 auf 0,4 gesenkt (Leitfaden: 0,2 bis 0,4). Neon strahlt dadurch weniger ueber. Passt das noch zum Cyber-Look, oder lieber wieder kraeftiger?
63. Der Wassertank steht jetzt 26 m weiter noerdlich (z -126), weil er vorher auf der Runenstrasse stand. Dadurch haben einige Gebaeude im Nordosten andere Hoehen (gleicher Zufallsstartwert, andere Reihenfolge).
64. Die neuen Haeuser sind bewohnt von niemandem: keine NPCs, keine Interaktionen (Ausleihe, Schalter, Kasse), keine Quests. Die Gemaelde im Museum sind vorhandene Texturen (Speisenbilder als Stillleben, Poster). Die Inhalte (Schalternamen, Aemter, Exponate, "Buergermeisterin") sind von mir erfunden.
65. Die Sicherheitsschleuse im Popcorn-Labor ist nur Kulisse, man kann daran vorbeigehen. Die oberen Etagen sind grosse offene Raeume; mehr Trennwaende wuerden sie glaubwuerdiger machen.
66. Pad-Beschriftung fuer Nintendo folgt der Lage der Knoepfe (unten springen = "B"). Falls der Pro Controller unter Linux die Knoepfe nach Beschriftung statt nach Lage meldet, sind A/B und X/Y in den Hinweisen vertauscht. Das laesst sich erst mit verbundenem Pad pruefen.
67. Lizenzen der neuen Pakete: CityFolks (Alstra Infinite) verbietet Upload in Repositories, der Ordner liegt deshalb nur lokal. Die Namensnennung (Abschnitt 3.5 der vollen Lizenz auf alstrainfinite.com/fal) ist noch nicht im Spiel, z. B. im Abspann. Fuer Hospital_assets und street-props-v2 lag keine Lizenzdatei bei; das Repo ist oeffentlich. Bitte Herkunft und Lizenz klaeren, bevor `imported_models/krankenhaus/` und `strassen_props/` gepusht werden.
68. Die Klinik hat keine NPCs und keine Interaktionen (kein Heilen, keine Quest). Zimmer-, Raum- und Schildtexte sind erfunden. Die Wandtexturen des Sets passen nicht auf grosse Flaechen, die Waende sind deshalb schlichter Putz mit gruenem Sockel.
69. Die Buerger laufen ohne Animationsdatei: der Gehzyklus ist von Hand ueber Knochendrehungen gebaut (Beine, Knie, Arme, Ellbogen). Stehende Buerger zeigen die A-Pose. Sitzen, Winken oder Reden gibt es nicht. Soll ich eine echte Laufanimation (z. B. Mixamo) einbauen, oder reicht das?
70. Die Set-Ampel (trafficLight-v2) ist nicht verbaut. Moegliche Nutzung: Fussgaengerampeln an Querungen oder als Deko im Park. Das Modell ist deutlich comichafter als die Cyber-Masten der Stadt.
