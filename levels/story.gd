extends Node
## Story: steuert das Intro und startet die Questkette.
## Nur beim ersten Spiel eines leeren Slots (Flag "intro_gesehen" im GameState): Bildschirm blendet aus Schwarz auf
## (Zauber-Man wacht auf), dann laeuft der Intro-Dialog (Esc ueberspringt). Danach startet das erste Ziel.
## Bei vorhandenem Fortschritt setzt der QuestManager die Kette fort.
## Signale: intro_beendet. Exportiert: schwarz_dauer, aufblenden_dauer.

signal intro_beendet

const SPERRE_GRUND := "intro"
const EBENE := 18
const START_WARTEN := 1.5  ## Sekunden nach Szenenstart, damit Welt und Boden stehen

@export var schwarz_dauer := 1.6
@export var aufblenden_dauer := 2.8

var _blende: ColorRect
var _titel: Label


func _ready() -> void:
	await get_tree().create_timer(START_WARTEN).timeout
	if GameState.flag("intro_gesehen"):
		QuestManager.fortsetzen()
		return
	await _intro()


func _intro() -> void:
	EventBus.eingabe_gesperrt.emit(SPERRE_GRUND, true)
	var ebene := CanvasLayer.new()
	ebene.layer = EBENE
	add_child(ebene)
	_blende = ColorRect.new()
	_blende.color = Color.BLACK
	_blende.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blende.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ebene.add_child(_blende)
	_titel = Label.new()
	_titel.text = "SYNTH-CITY // NETZ-STATUS: INSTABIL\n> ZAUBER-MAN: SYSTEM STARTET ..."
	_titel.add_theme_font_override("font", preload("res://ui/neon.gd").font())
	_titel.add_theme_font_size_override("font_size", 22)
	_titel.add_theme_color_override("font_color", Color(0.1, 0.95, 1.0))
	_titel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_titel.set_anchors_preset(Control.PRESET_CENTER)
	_titel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_titel.grow_vertical = Control.GROW_DIRECTION_BOTH
	ebene.add_child(_titel)
	await get_tree().create_timer(schwarz_dauer).timeout
	# Aufwachen: Blende hebt sich, Titel blendet mit aus
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_blende, "color:a", 0.0, aufblenden_dauer)
	tw.tween_property(_titel, "modulate:a", 0.0, aufblenden_dauer * 0.6)
	await tw.finished
	ebene.queue_free()
	EventBus.eingabe_gesperrt.emit(SPERRE_GRUND, false)
	var daten := Dialog.laden("intro")
	if daten != null:
		Dialog.starten(daten)
		await EventBus.dialog_beendet
	GameState.flag_setzen("intro_gesehen")
	QuestManager.starten(QuestManager.ERSTE_QUEST)
	intro_beendet.emit()
