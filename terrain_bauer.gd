@tool
extends Terrain3D
## Backt das Gelaende (Hoehen, Texturen-Verteilung, Farbe) in Terrain3D-Daten unter res://terrain/.
## Aufruf im Editor: bauen(). Danach kann man das Terrain mit den Terrain3D-Werkzeugen weiter formen.

const DATEN := "res://terrain/daten"
const BILD := 512                       ## Pixel pro Kante
const TEXTUREN := ["grass_ground", "forrest_ground_01", "rocky_terrain"]
const NAMEN := ["Gras", "Waldboden", "Fels"]
const UV := [0.08, 0.10, 0.06]


func _ctrl(basis_id: int, overlay_id: int, mischung: int) -> float:
	var v := (basis_id << 27) | (overlay_id << 22) | (mischung << 14)
	var b := PackedByteArray()
	b.resize(4)
	b.encode_u32(0, v)
	return b.decode_float(0)


func bauen() -> String:
	var t0 := Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DATEN))
	var abstand := 2.0 * TerrainForm.KARTE / BILD
	vertex_spacing = abstand
	region_size = 256
	collision_mode = 3

	# Texturen
	var assets_res := Terrain3DAssets.new()
	for i in TEXTUREN.size():
		var ta := Terrain3DTextureAsset.new()
		ta.name = NAMEN[i]
		ta.id = i
		ta.albedo_texture = load("res://assets/terrain/%s_alb_h.png" % TEXTUREN[i])
		ta.normal_texture = load("res://assets/terrain/%s_nrm_r.png" % TEXTUREN[i])
		ta.uv_scale = UV[i]
		assets_res.set_texture_asset(i, ta)
	assets = assets_res
	if material != null:
		material.auto_shader_enabled = false
		material.macro_variation_enabled = true
		material.projection_enabled = true

	# Hoehen
	var hoehen_feld := PackedFloat32Array()
	hoehen_feld.resize(BILD * BILD)
	var bild_h := Image.create(BILD, BILD, false, Image.FORMAT_RF)
	for j in BILD:
		for i in BILD:
			var x := -TerrainForm.KARTE + i * abstand
			var z := -TerrainForm.KARTE + j * abstand
			var h := TerrainForm.hoehe(x, z)
			hoehen_feld[j * BILD + i] = h
			bild_h.set_pixel(i, j, Color(h, 0, 0, 1))

	# Texturverteilung und Farbe
	var bild_c := Image.create(BILD, BILD, false, Image.FORMAT_RF)
	var bild_f := Image.create(BILD, BILD, false, Image.FORMAT_RGBA8)
	for j in BILD:
		for i in BILD:
			var x := -TerrainForm.KARTE + i * abstand
			var z := -TerrainForm.KARTE + j * abstand
			var h: float = hoehen_feld[j * BILD + i]
			var hl: float = hoehen_feld[j * BILD + maxi(i - 1, 0)]
			var hr: float = hoehen_feld[j * BILD + mini(i + 1, BILD - 1)]
			var ho: float = hoehen_feld[maxi(j - 1, 0) * BILD + i]
			var hu: float = hoehen_feld[mini(j + 1, BILD - 1) * BILD + i]
			var steil := sqrt((hr - hl) * (hr - hl) + (hu - ho) * (hu - ho)) / (2.0 * abstand)
			var fels := clampf(smoothstep(0.55, 0.95, steil) + smoothstep(105.0, 150.0, h), 0.0, 1.0)
			var wald := TerrainForm.waldwert(x, z, h)
			var c: float
			if fels < 0.15:
				c = _ctrl(0, 1, int(wald * 255.0))
			else:
				c = _ctrl(1 if wald > 0.5 else 0, 2, int(fels * 255.0))
			bild_c.set_pixel(i, j, Color(c, 0, 0, 1))
			# Gras gruener toenen, Waldboden dunkler
			var gras := 1.0 - wald
			bild_f.set_pixel(i, j, Color(1.0 - 0.18 * wald - 0.22 * gras, 1.0 - 0.08 * wald, 1.0 - 0.25 * wald - 0.35 * gras, 0.5))

	var daten := get_data()
	daten.import_images([bild_h, bild_c, bild_f], Vector3(-TerrainForm.KARTE, 0.0, -TerrainForm.KARTE), 0.0, 1.0)
	daten.save_directory(DATEN)
	data_directory = DATEN
	assets.save("res://terrain/assets.tres")
	return "fertig in %d ms, Regionen: %d" % [Time.get_ticks_msec() - t0, daten.get_region_count()]
