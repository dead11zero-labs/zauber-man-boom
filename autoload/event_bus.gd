extends Node
## EventBus: systemuebergreifende Signale. Sender und Empfaenger kennen sich nicht direkt.
## Zugriff ueber den Autoload-Namen EventBus.

signal mana_kern_gesammelt(gesamt: int)
signal seite_gesammelt(nummer: int)
signal rune_gesammelt(bezirk: int)
signal chip_gesammelt(id: String)
signal raetsel_geloest(id: String)
signal spieler_gestorben
signal bezirk_gewechselt(bezirk: int, name: String)
signal faehigkeit_freigeschaltet(id: String)
signal abschluss_geaendert(bezirk: int, anteil: float)
## Kampf (Meilenstein 4)
signal herzen_geaendert(herzen: int)
signal spieler_wiederbelebt
signal checkpoint_erreicht(id: String)
signal gegner_besiegt(art: String)
## Story und Dialoge (Meilenstein 5)
## Spieler-Eingabe sperren/freigeben (Dialog, Shop, Journal). `grund` trennt die Sperren voneinander.
signal eingabe_gesperrt(grund: String, gesperrt: bool)
signal dialog_gestartet(id: String)
## antwort = Index der zuletzt gewaehlten Antwort, -1 wenn es keine Auswahl gab
signal dialog_beendet(id: String, antwort: int)
## Allgemeines Story-Ereignis, z. B. "gespraech:informant", "seite:1", "bezirk:2"
signal story_ereignis(name: String)
signal quest_geaendert(id: String)
signal quest_abgeschlossen(id: String)
signal upgrade_gekauft(id: String, stufe: int)
