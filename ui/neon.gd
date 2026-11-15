extends RefCounted
## Neon: gemeinsame Farben und Zeichen-Helfer fuer die Story-UIs (Dialog, Shop, Journal).
## Gleicher Stil wie hud.gd (Cyan/Magenta/Gelb, abgeschraegte Ecken). Keine Signale, keine Exporte.
## Nutzung: `const NEON := preload("res://ui/neon.gd")`, dann `NEON.CYAN`, `NEON.rahmen(...)`.

const CYAN := Color(0.1, 0.95, 1.0)
const MAGENTA := Color(1.0, 0.15, 0.8)
const GELB := Color(1.0, 0.85, 0.2)
const ROT := Color(1.0, 0.15, 0.25)
const PANEL := Color(0.02, 0.04, 0.08, 0.86)
const ECKE := 14.0

static var _font: SystemFont


static func font() -> SystemFont:
	if _font == null:
		_font = SystemFont.new()
		_font.font_names = PackedStringArray(["Share Tech Mono", "DejaVu Sans Mono", "Liberation Mono", "monospace"])
		_font.font_weight = 700
	return _font


static func abgeschraegt(r: Rect2, c: float = ECKE) -> PackedVector2Array:
	var p := r.position
	var e := r.end
	return PackedVector2Array([
		Vector2(p.x + c, p.y), Vector2(e.x, p.y), Vector2(e.x, e.y - c),
		Vector2(e.x - c, e.y), Vector2(p.x, e.y), Vector2(p.x, p.y + c)])


## Zeichnet Panel mit Neon-Rahmen (und Glow) auf `ziel`.
static func rahmen(ziel: Control, r: Rect2, farbe: Color, hintergrund: Color = PANEL) -> void:
	var poly := abgeschraegt(r)
	ziel.draw_colored_polygon(poly, hintergrund)
	var linie := poly.duplicate()
	linie.append(poly[0])
	ziel.draw_polyline(linie, Color(farbe, 0.25), 6.0)
	ziel.draw_polyline(linie, farbe, 2.0)


## Label mit Neon-Schrift (fuer Texte, die automatisch umbrechen sollen)
static func label(groesse: int, farbe: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", font())
	l.add_theme_font_size_override("font_size", groesse)
	l.add_theme_color_override("font_color", farbe)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
