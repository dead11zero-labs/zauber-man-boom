extends StaticBody3D
## Barrier: Sperre (Tor mit festen Seitenwaenden), die sich hebt, solange der Eingang Strom hat.
## Gelöst = einmal geoeffnet (oder, bei erst_beim_durchgang, einmal durchschritten). Gelöste Raetsel
## bleiben offen und werden gespeichert (GameState.raetsel, EventBus.raetsel_geloest).
## Exportiert: id (Speicherschluessel), breite, hoehe, farbe, erst_beim_durchgang.
## Aufruf: eingang_setzen(knoten).

@export var id := ""
@export var breite := 6.0
@export var hoehe := 5.0
@export var farbe := Color(0.2, 0.9, 1.0)
@export var erst_beim_durchgang := false

const DICKE := 0.8
const WAND_BREITE := 12.0
const OEFFNEN_ZEIT := 0.9
const DURCHGANG_TIEFE := 4.0

var geloest := false
var _tuer: Node3D
var _wand_mat: StandardMaterial3D
var _eingang_aktiv := false


func _ready() -> void:
	_wand_mat = StandardMaterial3D.new()
	_wand_mat.albedo_color = Color(0.05, 0.06, 0.1)
	_wand_mat.emission_enabled = true
	_wand_mat.emission = farbe
	_wand_mat.emission_energy_multiplier = 0.6
	# Tuerblatt: eigene Unter-Node, damit nur sie sich bewegt
	_tuer = Node3D.new()
	add_child(_tuer)
	_tuer.position.y = hoehe * 0.5
	_kasten(_tuer, Vector3.ZERO, Vector3(breite, hoehe, DICKE))
	for seite in [-1.0, 1.0]:
		_kasten(self, Vector3(seite * (breite + WAND_BREITE) * 0.5, hoehe * 0.5, 0.0), Vector3(WAND_BREITE, hoehe, DICKE))
	# Durchgangs-Zone hinter der Tuer
	var a := Area3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(breite, hoehe, DURCHGANG_TIEFE)
	cs.shape = box
	a.add_child(cs)
	a.position = Vector3(0, hoehe * 0.5, DURCHGANG_TIEFE)
	a.body_entered.connect(_durchgang)
	add_child(a)
	if GameState.raetsel.get(id, false):
		geloest = true
		_tuer.position.y = hoehe * 1.5


func _kasten(eltern: Node3D, pos: Vector3, groesse: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = groesse
	cs.shape = box
	cs.position = pos
	eltern.add_child(cs)
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = groesse
	m.mesh = bm
	m.material_override = _wand_mat
	m.position = pos
	eltern.add_child(m)


func eingang_setzen(e: Node) -> void:
	e.power_changed.connect(_strom)
	_strom(bool(e.get("aktiv")))


func _strom(an: bool) -> void:
	_eingang_aktiv = an
	var offen := an or geloest
	var tw := create_tween()
	tw.tween_property(_tuer, "position:y", hoehe * (1.5 if offen else 0.5), OEFFNEN_ZEIT).set_trans(Tween.TRANS_CUBIC)
	if an and not erst_beim_durchgang:
		_loesen()


func _durchgang(b: Node) -> void:
	if b.is_in_group("spieler") and _eingang_aktiv:
		_loesen()


func _loesen() -> void:
	if geloest:
		return
	geloest = true
	if id != "":
		GameState.raetsel[id] = true
		EventBus.raetsel_geloest.emit(id)


## Fuer Kabel: Andockpunkt am Fuss der Tuer.
func ziel_punkt() -> Vector3:
	return global_position + Vector3.UP * 0.5
