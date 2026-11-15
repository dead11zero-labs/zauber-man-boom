extends Resource
## UpgradeDaten: ein kaufbares Upgrade mit mehreren Stufen. Liegt als .tres in res://data/upgrades/<id>.tres.
## Exportiert: id, titel, beschreibung, kosten (Mana-Kerne pro Stufe), boni (Wirkung pro Stufe, kumulativer Wert).
## Bonus ist ein Anteil: 0.25 = +25 Prozent. Kopplung: spieler.gd (Laden, Zielreichweite), blitz.gd (Schaden, Reichweite).
## Kein class_name noetig: Zugriff ueber GameState.upgrade_daten(id).

@export var id := ""
@export var titel := ""
@export var beschreibung := ""
@export var kosten: PackedInt32Array = PackedInt32Array()
@export var boni: PackedFloat32Array = PackedFloat32Array()


func max_stufe() -> int:
	return mini(kosten.size(), boni.size())


## Preis der Stufe (1-basiert)
func kosten_fuer_stufe(stufe: int) -> int:
	return kosten[clampi(stufe, 1, kosten.size()) - 1]


func bonus_fuer_stufe(stufe: int) -> float:
	return boni[clampi(stufe, 1, boni.size()) - 1]
