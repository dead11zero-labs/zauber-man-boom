extends Control
## Ladeanimation: spielt das Intro-Video (assets/video/intro.ogv) vor dem Spielstart, waehrend die Spielszene
## im Hintergrund geladen wird. Danach wechselt sie zu SPIEL. Esc / Enter / Leertaste / Klick ueberspringt das Video.
## Szene: ladeanimation.tscn (nur dieses Skript am Wurzelknoten). Aufgerufen von startmenue.gd nach der Slot-Wahl.
## Keine Signale, keine Exporte. Das Video muss Ogg Theora sein (Godot spielt kein mp4).

const SPIEL := "res://node_3d.tscn"
const VIDEO := "res://assets/video/intro.ogv"
const SEITENVERHAELTNIS := 16.0 / 9.0
const SPRUNG_ERST_NACH := 0.8     ## Sekunden, bevor Ueberspringen erlaubt ist (kein versehentliches Weiterklicken)
const HINWEIS_TEXT := "ESC: ÜBERSPRINGEN"
const LADE_TEXT := "LADE SYNTH-CITY ..."
const SCHRIFT_GROESSE := 22
const RAND := 24.0

var _video: VideoStreamPlayer
var _hinweis: Label
var _zeit := 0.0
var _fertig := false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var schwarz := ColorRect.new()
	schwarz.color = Color.BLACK
	schwarz.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(schwarz)
	var rahmen := AspectRatioContainer.new()
	rahmen.set_anchors_preset(Control.PRESET_FULL_RECT)
	rahmen.ratio = SEITENVERHAELTNIS
	rahmen.stretch_mode = AspectRatioContainer.STRETCH_FIT
	add_child(rahmen)
	_video = VideoStreamPlayer.new()
	_video.expand = true
	_video.finished.connect(_video_zu_ende)
	var stream := load(VIDEO) as VideoStream
	if stream == null:
		push_warning("Ladeanimation: Video fehlt, starte direkt.")
		_spiel_laden()
		return
	_video.stream = stream
	rahmen.add_child(_video)
	_hinweis = Label.new()
	_hinweis.text = HINWEIS_TEXT
	_hinweis.add_theme_font_size_override("font_size", SCHRIFT_GROESSE)
	_hinweis.add_theme_color_override("font_color", Color(0.3, 0.95, 1.0))
	_hinweis.add_theme_color_override("font_outline_color", Color(0, 0.05, 0.15))
	_hinweis.add_theme_constant_override("outline_size", 8)
	_hinweis.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_hinweis.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_hinweis.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hinweis.offset_right = -RAND
	_hinweis.offset_bottom = -RAND
	_hinweis.modulate.a = 0.0
	add_child(_hinweis)
	ResourceLoader.load_threaded_request(SPIEL)
	_video.play()


func _process(delta: float) -> void:
	_zeit += delta
	if _hinweis != null and not _fertig:
		_hinweis.modulate.a = clampf((_zeit - SPRUNG_ERST_NACH) * 2.0, 0.0, 0.8)


func _unhandled_input(event: InputEvent) -> void:
	if _fertig or _zeit < SPRUNG_ERST_NACH:
		return
	var druck := false
	if event is InputEventKey:
		druck = event.pressed and not event.echo and event.keycode in [KEY_ESCAPE, KEY_ENTER, KEY_SPACE]
	elif event is InputEventMouseButton or event is InputEventJoypadButton:
		druck = event.pressed
	if druck:
		_video_zu_ende()


func _video_zu_ende() -> void:
	if _fertig:
		return
	_fertig = true
	_video.stop()
	_spiel_laden()


## Wartet auf die im Hintergrund geladene Spielszene und wechselt dann. Der Aufbau der Stadt beim Start dauert
## einige Sekunden, daher steht vorher ein Ladetext auf dem Bild.
func _spiel_laden() -> void:
	_fertig = true
	if _hinweis != null:
		_hinweis.text = LADE_TEXT
		_hinweis.modulate.a = 1.0
	else:
		get_tree().change_scene_to_file(SPIEL)
		return
	if ResourceLoader.load_threaded_get_status(SPIEL) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		ResourceLoader.load_threaded_request(SPIEL)
	var paket: PackedScene = ResourceLoader.load_threaded_get(SPIEL) as PackedScene
	await get_tree().process_frame
	await get_tree().process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_packed(paket)
