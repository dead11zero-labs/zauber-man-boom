extends Control
## Startbildschirm: Das Titelbild mit unsichtbaren Schaltflaechen genau ueber den gemalten Buttons.

const BILD := preload("res://assets/startbildschirm.jpg")
const SPIEL := "res://ladeanimation.tscn"  ## zeigt erst das Intro-Video, laedt dann node_3d.tscn
## Lage der gemalten Buttons im Bild (Anteile von Breite/Hoehe: links, oben, rechts, unten)
const OPTIONEN := Rect2(0.200, 0.871, 0.156, 0.088)
const START := Rect2(0.376, 0.862, 0.249, 0.101)
const LADEN := Rect2(0.644, 0.871, 0.156, 0.088)

const TITELSONG := "res://assets/audio/titelsong.mp3"

var _hinweis: Label
var _blende: ColorRect
var _startet := false
var _musik: AudioStreamPlayer
var _slot_box: Control
var _slot_knoepfe: Array[Button] = []
var _slot_hinweis: Label
var _loesch_slot := 0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var song = load(TITELSONG)
	if song != null:
		song.loop = true  # Titelsong laeuft in Endlosschleife
		_musik = AudioStreamPlayer.new()
		_musik.stream = song
		_musik.volume_db = -4.0
		add_child(_musik)
		_musik.play()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var schwarz := ColorRect.new()
	schwarz.color = Color.BLACK
	schwarz.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(schwarz)
	# Bild bleibt im Seitenverhaeltnis, Buttons liegen im selben Rahmen
	var rahmen := AspectRatioContainer.new()
	rahmen.set_anchors_preset(Control.PRESET_FULL_RECT)
	rahmen.ratio = float(BILD.get_width()) / float(BILD.get_height())
	rahmen.stretch_mode = AspectRatioContainer.STRETCH_FIT
	add_child(rahmen)
	var flaeche := Control.new()
	rahmen.add_child(flaeche)
	var tex := TextureRect.new()
	tex.texture = BILD
	tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	flaeche.add_child(tex)
	_knopf(flaeche, START, _slots_zeigen)
	_knopf(flaeche, OPTIONEN, _bald.bind("OPTIONEN"))
	_knopf(flaeche, LADEN, _slots_zeigen)
	_hinweis = Label.new()
	_hinweis.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hinweis.anchor_left = 0.0
	_hinweis.anchor_right = 1.0
	_hinweis.anchor_top = 0.80
	_hinweis.anchor_bottom = 0.85
	_hinweis.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hinweis.add_theme_font_size_override("font_size", 26)
	_hinweis.add_theme_color_override("font_color", Color(0.3, 0.95, 1.0))
	_hinweis.add_theme_color_override("font_outline_color", Color(0, 0.05, 0.15))
	_hinweis.add_theme_constant_override("outline_size", 8)
	_hinweis.modulate.a = 0.0
	flaeche.add_child(_hinweis)
	_blende = ColorRect.new()
	_blende.color = Color(0, 0, 0, 0)
	_blende.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blende.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_blende)


func _knopf(eltern: Control, r: Rect2, aktion: Callable) -> void:
	var b := Button.new()
	b.anchor_left = r.position.x
	b.anchor_top = r.position.y
	b.anchor_right = r.end.x
	b.anchor_bottom = r.end.y
	b.offset_left = 0
	b.offset_top = 0
	b.offset_right = 0
	b.offset_bottom = 0
	b.flat = false
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var leer := StyleBoxEmpty.new()
	var glow := StyleBoxFlat.new()
	glow.bg_color = Color(0.2, 0.9, 1.0, 0.12)
	glow.set_border_width_all(3)
	glow.border_color = Color(0.5, 1.0, 1.0, 0.95)
	glow.set_corner_radius_all(14)
	glow.shadow_color = Color(0.2, 0.9, 1.0, 0.55)
	glow.shadow_size = 14
	b.add_theme_stylebox_override("normal", leer)
	b.add_theme_stylebox_override("hover", glow)
	b.add_theme_stylebox_override("pressed", glow)
	b.add_theme_stylebox_override("focus", glow)
	b.pressed.connect(aktion)
	eltern.add_child(b)
	if r == START:
		b.add_to_group("startknopf")
		b.call_deferred("grab_focus")


func _unhandled_input(event: InputEvent) -> void:
	if _slot_box != null:
		_slot_eingabe(event)
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ENTER:
		_slots_zeigen()
	elif event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START:
		_slots_zeigen()


## Slot-Auswahl: 3 Spielstaende. Enter/A waehlen, Entf/Y loeschen (zweimal), Esc/B zurueck.
func _slots_zeigen() -> void:
	if _slot_box != null or _startet:
		return
	_slot_box = Control.new()
	_slot_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dunkel := ColorRect.new()
	dunkel.color = Color(0, 0.02, 0.06, 0.82)
	dunkel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_slot_box.add_child(dunkel)
	var mitte := CenterContainer.new()
	mitte.set_anchors_preset(Control.PRESET_FULL_RECT)
	_slot_box.add_child(mitte)
	var spalte := VBoxContainer.new()
	spalte.add_theme_constant_override("separation", 14)
	mitte.add_child(spalte)
	var titel := Label.new()
	titel.text = "// SPIELSTAND WAEHLEN"
	titel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titel.add_theme_font_size_override("font_size", 30)
	titel.add_theme_color_override("font_color", Color(1.0, 0.2, 0.85))
	spalte.add_child(titel)
	_slot_knoepfe.clear()
	for i in SaveSystem.SLOTS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(720, 64)
		b.add_theme_font_size_override("font_size", 22)
		b.add_theme_color_override("font_color", Color(0.5, 1.0, 1.0))
		b.add_theme_color_override("font_focus_color", Color.WHITE)
		var norm := StyleBoxFlat.new()
		norm.bg_color = Color(0.02, 0.06, 0.12, 0.9)
		norm.set_border_width_all(2)
		norm.border_color = Color(0.2, 0.7, 0.9, 0.7)
		var fokus := norm.duplicate() as StyleBoxFlat
		fokus.bg_color = Color(0.05, 0.2, 0.3, 0.95)
		fokus.border_color = Color(0.5, 1.0, 1.0)
		fokus.set_border_width_all(3)
		fokus.shadow_color = Color(0.2, 0.9, 1.0, 0.5)
		fokus.shadow_size = 12
		b.add_theme_stylebox_override("normal", norm)
		b.add_theme_stylebox_override("hover", fokus)
		b.add_theme_stylebox_override("focus", fokus)
		b.add_theme_stylebox_override("pressed", fokus)
		b.pressed.connect(_slot_gewaehlt.bind(i + 1))
		b.focus_entered.connect(func() -> void: _loesch_slot = 0)
		spalte.add_child(b)
		_slot_knoepfe.append(b)
	_slot_hinweis = Label.new()
	_slot_hinweis.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_slot_hinweis.add_theme_font_size_override("font_size", 16)
	_slot_hinweis.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	spalte.add_child(_slot_hinweis)
	add_child(_slot_box)
	_slots_beschriften()
	_slot_knoepfe[0].grab_focus()


func _slots_beschriften() -> void:
	for i in SaveSystem.SLOTS:
		var d := SaveSystem.info(i + 1)
		if d.is_empty():
			_slot_knoepfe[i].text = "SLOT %d   //   NEUES SPIEL" % (i + 1)
		else:
			_slot_knoepfe[i].text = "SLOT %d   //   MANA %d   RUNEN %d   SEITEN %d/7   %s" % [i + 1, int(d.get("mana_kerne", 0)), int(d.get("runen", 0)), (d.get("seiten", []) as Array).size(), str(d.get("bezirk", "")).to_upper()]
	_slot_hinweis.text = "ENTER/A = WAEHLEN     ENTF/Y = LOESCHEN     ESC/B = ZURUECK"


func _slot_eingabe(event: InputEvent) -> void:
	var nr := 0
	for i in _slot_knoepfe.size():
		if _slot_knoepfe[i].has_focus():
			nr = i + 1
	var loeschen: bool = (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_DELETE) \
		or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_Y)
	var zurueck: bool = (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE) \
		or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B)
	if zurueck:
		_slot_box.queue_free()
		_slot_box = null
		_knopf_fokus_zurueck()
	elif loeschen and nr > 0 and SaveSystem.vorhanden(nr):
		if _loesch_slot == nr:
			SaveSystem.loeschen(nr)
			_loesch_slot = 0
			_slots_beschriften()
		else:
			_loesch_slot = nr
			_slot_hinweis.text = "SLOT %d WIRKLICH LOESCHEN?  NOCHMAL ENTF/Y DRUECKEN" % nr


func _knopf_fokus_zurueck() -> void:
	for k in get_tree().get_nodes_in_group("startknopf"):
		(k as Control).grab_focus()


func _slot_gewaehlt(nr: int) -> void:
	SaveSystem.waehle(nr)
	_spiel_starten()


func _hinweis_zeigen(text: String, dauer: float) -> void:
	_hinweis.text = text
	_hinweis.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(dauer)
	tw.tween_property(_hinweis, "modulate:a", 0.0, 0.6)


func _bald(name: String) -> void:
	_hinweis.text = "%s: BALD VERFUEGBAR" % name
	_hinweis.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(_hinweis, "modulate:a", 0.0, 0.6)


func _spiel_starten() -> void:
	if _startet:
		return
	_startet = true
	_blende.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_blende, "color:a", 1.0, 0.45)
	if _musik != null:
		tw.parallel().tween_property(_musik, "volume_db", -40.0, 0.45)
	tw.tween_callback(get_tree().change_scene_to_file.bind(SPIEL))
