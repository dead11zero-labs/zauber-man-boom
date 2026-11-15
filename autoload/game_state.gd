extends Node
## GameState: Fortschritt, Faehigkeiten, Inventar, Lebenspunkte und aktueller Bezirk.
## Signale laufen ueber EventBus. Speichern/Laden uebernimmt SaveSystem (zu_dict / aus_dict).

## Bezirke laut Konzept (Index 0 = ausserhalb, 6 = Finale)
const BEZIRKE: Array[String] = [
	"Randgebiet", "Startviertel", "Neon-Basar", "Hafen", "Daecher", "Untergrund", "Kern-Turm",
]
const MAX_HERZEN := 5
const SEITEN_GESAMT := 7

var mana_kerne: int = 0
var runen: int = 0
var chips: Array[String] = []
var seiten: Array[int] = []
var faehigkeiten: Array[String] = []
var herzen: int = MAX_HERZEN
var aktueller_bezirk: int = 0
## Eingesammelte feste Objekte (id -> true), damit sie nach Neustart nicht wiederkommen
var eingesammelt: Dictionary = {}
## Geloeste Raetsel (id -> true), werden gespeichert
var raetsel: Dictionary = {}
## Letzter Checkpoint (Meilenstein 4): id und Weltposition, wird gespeichert
var checkpoint_id: String = ""
var checkpoint_pos: Vector3 = Vector3.ZERO
## Story (Meilenstein 5): aktive Quest, abgeschlossene Quests, Flags (z. B. "intro_gesehen", "gesprochen_haendler")
var quest_aktiv: String = ""
var quests_fertig: Array[String] = []
var flags: Dictionary = {}
## Gekaufte Upgrade-Stufen (id -> Stufe, 0 = nicht gekauft)
var upgrades: Dictionary = {}
var _upgrade_cache: Dictionary = {}
## Pro Bezirk und Typ: wie viele Objekte es gibt (soll) und wie viele schon genommen sind (ist). Nur Laufzeit.
var _soll: Dictionary = {}
var _ist: Dictionary = {}


func mana_kern_hinzu(menge: int = 1) -> void:
	mana_kerne += menge
	EventBus.mana_kern_gesammelt.emit(mana_kerne)


## Zieht Herzen ab (nie unter 0) und meldet es. Gibt die verbleibenden Herzen zurueck.
func schaden(menge: int) -> int:
	herzen = maxi(herzen - menge, 0)
	EventBus.herzen_geaendert.emit(herzen)
	return herzen


func heilen(menge: int) -> void:
	var neu := mini(herzen + menge, MAX_HERZEN)
	if neu == herzen:
		return
	herzen = neu
	EventBus.herzen_geaendert.emit(herzen)


func hat_checkpoint() -> bool:
	return checkpoint_id != ""


func checkpoint_setzen(id: String, pos: Vector3) -> void:
	var neu := id != checkpoint_id
	checkpoint_id = id
	checkpoint_pos = pos
	if neu:
		EventBus.checkpoint_erreicht.emit(id)


func bezirk_setzen(nr: int) -> void:
	if nr == aktueller_bezirk:
		return
	aktueller_bezirk = nr
	EventBus.bezirk_gewechselt.emit(nr, bezirk_name(nr))


func bezirk_name(nr: int) -> String:
	return BEZIRKE[clampi(nr, 0, BEZIRKE.size() - 1)]


func hat_seite(nr: int) -> bool:
	return seiten.has(nr)


## Meldet ein festes Objekt an (zaehlt fuer den Abschluss). false = bereits eingesammelt, nicht spawnen.
func registrieren(bezirk: int, typ: int, id: String) -> bool:
	_zaehl(_soll, bezirk, typ, 1)
	if eingesammelt.has(id):
		_zaehl(_ist, bezirk, typ, 1)
		return false
	return true


func einsammeln(id: String, daten: CollectibleData, bezirk: int) -> void:
	if id != "":
		if eingesammelt.has(id):
			return
		eingesammelt[id] = true
		_zaehl(_ist, bezirk, daten.typ, 1)
	match daten.typ:
		CollectibleData.Typ.MANA_KERN:
			mana_kern_hinzu(daten.wert)
		CollectibleData.Typ.RUNE:
			runen += daten.wert
			EventBus.rune_gesammelt.emit(bezirk)
		CollectibleData.Typ.CHIP:
			if not chips.has(daten.id):
				chips.append(daten.id)
			EventBus.chip_gesammelt.emit(daten.id)
		CollectibleData.Typ.SEITE:
			if not seiten.has(daten.wert):
				seiten.append(daten.wert)
			EventBus.seite_gesammelt.emit(daten.wert)
	EventBus.abschluss_geaendert.emit(bezirk, abschluss(bezirk))


## Anteil 0..1 aller registrierten Objekte des Bezirks, oder -1 wenn der Bezirk keine hat.
func abschluss(bezirk: int) -> float:
	var s := 0
	var i := 0
	for typ: int in _soll.get(bezirk, {}):
		s += _soll[bezirk][typ]
		i += _ist.get(bezirk, {}).get(typ, 0)
	return -1.0 if s == 0 else float(i) / float(s)


func _zaehl(ziel: Dictionary, bezirk: int, typ: int, menge: int) -> void:
	if not ziel.has(bezirk):
		ziel[bezirk] = {}
	ziel[bezirk][typ] = ziel[bezirk].get(typ, 0) + menge


func flag(name: String) -> bool:
	return flags.has(name)


func flag_setzen(name: String) -> void:
	flags[name] = true


func upgrade_stufe(id: String) -> int:
	return int(upgrades.get(id, 0))


## Upgrade-Daten (Resource data/upgrades/<id>.tres), gecacht. null wenn unbekannt.
func upgrade_daten(id: String) -> Resource:
	if not _upgrade_cache.has(id):
		var pfad := "res://data/upgrades/%s.tres" % id
		_upgrade_cache[id] = load(pfad) if ResourceLoader.exists(pfad) else null
	return _upgrade_cache[id]


## Bonus der gekauften Stufe (0.0 ohne Kauf). Die Defaults im Spiel bleiben dadurch unveraendert.
func upgrade_bonus(id: String) -> float:
	var stufe := upgrade_stufe(id)
	var d := upgrade_daten(id)
	if stufe <= 0 or d == null:
		return 0.0
	return d.bonus_fuer_stufe(stufe)


## Kauft die naechste Stufe, wenn genug Mana-Kerne da sind und die Maximalstufe nicht erreicht ist.
func upgrade_kaufen(id: String) -> bool:
	var d := upgrade_daten(id)
	if d == null:
		return false
	var stufe := upgrade_stufe(id)
	if stufe >= d.max_stufe():
		return false
	var preis: int = d.kosten_fuer_stufe(stufe + 1)
	if mana_kerne < preis:
		return false
	mana_kerne -= preis
	upgrades[id] = stufe + 1
	EventBus.upgrade_gekauft.emit(id, stufe + 1)
	return true


func zuruecksetzen() -> void:
	mana_kerne = 0
	runen = 0
	chips.clear()
	seiten.clear()
	faehigkeiten.clear()
	herzen = MAX_HERZEN
	eingesammelt.clear()
	raetsel.clear()
	checkpoint_id = ""
	checkpoint_pos = Vector3.ZERO
	quest_aktiv = ""
	quests_fertig.clear()
	flags.clear()
	upgrades.clear()
	_soll.clear()
	_ist.clear()


func zu_dict() -> Dictionary:
	return {
		"mana_kerne": mana_kerne, "runen": runen, "chips": chips, "seiten": seiten,
		"faehigkeiten": faehigkeiten, "herzen": herzen, "eingesammelt": eingesammelt.keys(), "raetsel": raetsel.keys(),
		"checkpoint": checkpoint_id, "checkpoint_pos": [checkpoint_pos.x, checkpoint_pos.y, checkpoint_pos.z],
		"quest": quest_aktiv, "quests_fertig": quests_fertig, "flags": flags.keys(), "upgrades": upgrades,
	}


func aus_dict(d: Dictionary) -> void:
	zuruecksetzen()
	mana_kerne = int(d.get("mana_kerne", 0))
	runen = int(d.get("runen", 0))
	herzen = clampi(int(d.get("herzen", MAX_HERZEN)), 1, MAX_HERZEN)
	for c in d.get("chips", []):
		chips.append(str(c))
	for s in d.get("seiten", []):
		seiten.append(int(s))
	for f in d.get("faehigkeiten", []):
		faehigkeiten.append(str(f))
	for k in d.get("eingesammelt", []):
		eingesammelt[str(k)] = true
	for k in d.get("raetsel", []):
		raetsel[str(k)] = true
	checkpoint_id = str(d.get("checkpoint", ""))
	var cp: Array = d.get("checkpoint_pos", [])
	if cp.size() == 3:
		checkpoint_pos = Vector3(float(cp[0]), float(cp[1]), float(cp[2]))
	# Story (Meilenstein 5). Alte Staende ohne diese Felder: Intro gilt als gesehen
	quest_aktiv = str(d.get("quest", ""))
	for q in d.get("quests_fertig", []):
		quests_fertig.append(str(q))
	for f in d.get("flags", []):
		flags[str(f)] = true
	if not d.has("flags"):
		flags["intro_gesehen"] = true
	var up: Dictionary = d.get("upgrades", {})
	for k in up:
		upgrades[str(k)] = int(up[k])
