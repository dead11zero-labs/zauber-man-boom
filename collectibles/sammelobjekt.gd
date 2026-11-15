extends Collectible
## Schwebendes Sammelobjekt fuer Neon-Rune, Datenchip und Grimoire-Seite (Platzhalter-Optik).
## Wird vom Platzierer erzeugt: einrichten(id, daten, position). Mana-Kerne haben ihr eigenes Skript (kristall.gd).

var _t := 0.0
var _basis_y := 0.0
var _modell: Node3D


func einrichten(p_id: String, p_daten: CollectibleData, pos: Vector3) -> bool:
	id = p_id
	add_to_group("sammelobjekt")
	daten = p_daten
	position = pos
	_basis_y = pos.y
	_t = randf() * TAU
	if not Collectible.registrieren(id, daten.typ, pos):
		return false  # schon eingesammelt
	_modell = Node3D.new()
	add_child(_modell)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = daten.farbe
	mat.emission_enabled = true
	mat.emission = daten.farbe
	mat.emission_energy_multiplier = 3.0
	var radius := 1.6
	match daten.typ:
		CollectibleData.Typ.RUNE:
			var z := CylinderMesh.new()
			z.top_radius = 0.55
			z.bottom_radius = 0.55
			z.height = 0.18
			z.radial_segments = 6
			var mi := MeshInstance3D.new()
			mi.mesh = z
			mi.material_override = mat
			mi.rotation_degrees.x = 90.0
			_modell.add_child(mi)
			var kern := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = Vector3(0.12, 0.7, 0.2)
			kern.mesh = b
			kern.material_override = mat
			_modell.add_child(kern)
		CollectibleData.Typ.CHIP:
			var b2 := BoxMesh.new()
			b2.size = Vector3(0.7, 0.1, 0.5)
			var mi2 := MeshInstance3D.new()
			mi2.mesh = b2
			mi2.material_override = mat
			_modell.add_child(mi2)
			for k in 4:
				var pin := MeshInstance3D.new()
				var pb := BoxMesh.new()
				pb.size = Vector3(0.08, 0.12, 0.1)
				pin.mesh = pb
				pin.position = Vector3(-0.27 + k * 0.18, 0.0, 0.3)
				pin.material_override = mat
				_modell.add_child(pin)
		CollectibleData.Typ.SEITE:
			radius = 2.4
			var seite := BoxMesh.new()
			seite.size = Vector3(1.3, 1.8, 0.06)
			var ms := MeshInstance3D.new()
			ms.mesh = seite
			ms.material_override = mat
			_modell.add_child(ms)
			var strahl := CylinderMesh.new()
			strahl.top_radius = 0.5
			strahl.bottom_radius = 0.9
			strahl.height = 60.0
			var sm := StandardMaterial3D.new()
			sm.albedo_color = Color(daten.farbe, 0.12)
			sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			sm.emission_enabled = true
			sm.emission = daten.farbe
			sm.emission_energy_multiplier = 1.2
			sm.cull_mode = BaseMaterial3D.CULL_DISABLED
			var mstr := MeshInstance3D.new()
			mstr.mesh = strahl
			mstr.material_override = sm
			mstr.position = Vector3(0, 30.0, 0)
			mstr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mstr)
			var l := Label3D.new()
			l.text = daten.titel
			l.font_size = 40
			l.pixel_size = 0.01
			l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			l.shaded = false
			l.modulate = Color(1.0, 0.9, 0.5)
			l.position = Vector3(0, 1.8, 0)
			add_child(l)
			var licht := OmniLight3D.new()
			licht.light_color = daten.farbe
			licht.omni_range = 18.0
			licht.light_energy = 2.0
			add_child(licht)
		_:
			pass
	var shape := CollisionShape3D.new()
	var kugel := SphereShape3D.new()
	kugel.radius = radius
	shape.shape = kugel
	add_child(shape)
	body_entered.connect(_on_body_entered)
	return true


func _process(delta: float) -> void:
	_t += delta
	if _genommen or _modell == null:
		return
	_modell.rotation.y = _t * 1.6
	position.y = _basis_y + sin(_t * 2.0) * 0.2


func _on_body_entered(body: Node) -> void:
	if einsammeln(body):
		var tw := create_tween()
		tw.tween_property(_modell, "scale", Vector3.ONE * 2.0, 0.2)
		tw.parallel().tween_property(self, "position:y", position.y + 1.2, 0.2)
		tw.tween_callback(queue_free)
