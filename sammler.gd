extends Node3D
## Streut Kristalle ueber die Stadt: am Boden und einige schwebend (fuer den Schwebemodus).

const ANZAHL_BODEN := 140
const ANZAHL_LUFT := 45
const START := Vector3(0, 0, 115)
const HALB := 290.0
const MIN_ABSTAND := 9.0

var kristall_szene := preload("res://kristall.tscn")
var rng := RandomNumberGenerator.new()
var _plaetze: Array[Vector3] = []


func _ready() -> void:
	rng.seed = 4242
	# Kollisionen der Stadt gehen erst nach ein paar Physik-Frames in den Raum
	await get_tree().physics_frame
	await get_tree().physics_frame
	_streuen()


func _streuen() -> void:
	var raum := get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var kugel := SphereShape3D.new()
	kugel.radius = 1.2
	q.shape = kugel
	# Bewegliche Figuren ignorieren, damit die Verteilung (und damit die ids) bei jedem Start gleich ist
	var raus: Array[RID] = []
	var beweglich: Array[Node] = []
	beweglich.append_array(get_tree().get_nodes_in_group("spieler"))
	beweglich.append_array(get_node("../SynthBots").get_children())
	beweglich.append(get_node_or_null("../GurkenMonster"))
	for n in beweglich:
		if n is CollisionObject3D:
			raus.append(n.get_rid())
	q.exclude = raus
	# Ein paar Kristalle in Startnaehe, damit man sie sofort findet
	for i in 8:
		var w := rng.randf() * TAU
		var r := rng.randf_range(10.0, 35.0)
		_versuche(raum, q, START + Vector3(cos(w) * r, 1.6, sin(w) * r))
	var boden := 8
	var luft := 0
	var versuche := 0
	while (boden < ANZAHL_BODEN or luft < ANZAHL_LUFT) and versuche < 6000:
		versuche += 1
		var p := Vector3(rng.randf_range(-HALB, HALB), 0.0, rng.randf_range(-HALB, HALB))
		var in_luft := luft < ANZAHL_LUFT and (boden >= ANZAHL_BODEN or rng.randf() < 0.25)
		p.y = rng.randf_range(7.0, 16.0) if in_luft else 1.6
		if _versuche(raum, q, p):
			if in_luft:
				luft += 1
			else:
				boden += 1


func _versuche(raum: PhysicsDirectSpaceState3D, q: PhysicsShapeQueryParameters3D, p: Vector3) -> bool:
	for a in _plaetze:
		if a.distance_to(p) < MIN_ABSTAND:
			return false
	q.transform = Transform3D(Basis.IDENTITY, p)
	if not raum.intersect_shape(q, 1).is_empty():
		return false
	_plaetze.append(p)
	var farbe := rng.randi() % 3
	var kid := "mk_%d_%d_%d" % [roundi(p.x), roundi(p.y), roundi(p.z)]
	# Schon eingesammelte Kerne zaehlen mit, werden aber nicht mehr erzeugt
	if Collectible.registrieren(kid, CollectibleData.Typ.MANA_KERN, p):
		var k = kristall_szene.instantiate()
		add_child(k)
		k.start(p, farbe, kid)
	_set_gesamt()
	return true


func _set_gesamt() -> void:
	var sp = get_node_or_null("../Spieler")
	if sp != null:
		sp.kristalle_gesamt = maxi(_plaetze.size(), GameState.mana_kerne)
		sp.kristalle_geaendert.emit(sp.kristalle, sp.kristalle_gesamt)
