class_name CollectibleData
extends Resource
## Beschreibt ein Sammelobjekt (Daten statt Code). Wird als .tres in res://data/sammelobjekte/ abgelegt.
## Felder: id (Kennung), typ, wert (Menge bzw. Seitennummer), titel/text/lore (Lore-Chips), farbe.

enum Typ { MANA_KERN, RUNE, CHIP, SEITE, TEIL }

@export var id: String = ""
@export var typ: Typ = Typ.MANA_KERN
@export var wert: int = 1
@export var titel: String = ""
@export_multiline var text: String = ""
## Lore-Text fuers Journal (2-3 Saetze). Leer: das Journal zeigt `text`.
@export_multiline var lore: String = ""
@export var farbe: Color = Color(0.1, 0.9, 1.0)
