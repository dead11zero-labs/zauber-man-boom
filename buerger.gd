extends "res://npc.gd"
## Buerger von Synth-City: Fussgaenger mit den CityFolks-Modellen (imported_models/cityfolks) statt Synth-Bot.
## Laufwege, Pausen und Ausweichen erbt er von npc.gd; neu sind Modellwahl und ein Gehzyklus per Skelett
## (Beine, Knie, Arme schwingen). Fehlt der Ordner cityfolks (Lizenz: nicht im Repo), entfaellt die Figur
## (siehe npcs.gd: dann werden keine Buerger erzeugt). Keine Signale, keine Exporte.

const MODELLE: Array[String] = [
	"res://imported_models/cityfolks/GLB/Deportista/Deportista_CityFolks_PolyMate.glb",
	"res://imported_models/cityfolks/GLB/Dough Sensei/DoughSensei_CityFolks_PolyMate.glb",
	"res://imported_models/cityfolks/GLB/Muscle Man/MuscleMan_CityFolks_PolyMate.glb",
	"res://imported_models/cityfolks/GLB/Padel Player/PadelPlayer_CityFolks_PolyMate.glb",
]
const KAPSEL_MITTE := 0.95        ## Hoehe der Kapsel: Fuesse der Figur liegen darunter
const FIGUR_SKALA := 0.95
const SCHRITT_BEIN := 0.55        ## Schwingweite der Oberschenkel (rad)
const SCHRITT_ARM := 0.4
const KNIE_BEUGE := 0.7
const ELLBOGEN_BEUGE := 0.35

var _skelett: Skeleton3D
var _figur: Node3D
## Knochen-Indizes: Oberschenkel l/r, Unterschenkel l/r, Oberarm l/r, Unterarm l/r
var _b: Array[int] = []


static func verfuegbar() -> bool:
	return ResourceLoader.exists(MODELLE[0])


func _ready() -> void:
	add_to_group("mensch")  # Zutrittskontrolle im Zauber-Tower (levels/scanner_schleuse.gd)
	var pfad: String = MODELLE.pick_random()
	_figur = (load(pfad) as PackedScene).instantiate() as Node3D
	$Modell.add_child(_figur)
	_figur.position = Vector3(0, -KAPSEL_MITTE, 0)
	_figur.scale = Vector3.ONE * FIGUR_SKALA
	_skelett = _figur.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for n in ["thigh_stretch.l", "thigh_stretch.r", "leg_stretch.l", "leg_stretch.r",
			"arm_stretch.l", "arm_stretch.r", "forearm_stretch.l", "forearm_stretch.r"]:
		_b.append(_skelett.find_bone(n))
	super._ready()


## Bewegung der Basisklasse (Wippen, Neigen) plus Gehzyklus der Gliedmassen.
func _animieren(delta: float, laeuft: bool) -> void:
	super._animieren(delta, laeuft)
	var fl := Vector2(velocity.x, velocity.z).length()
	var stark := clampf(fl / 2.0, 0.0, 1.0) if laeuft else 0.0
	var takt := _zeit * (5.0 + fl * 1.2)
	var s := sin(takt) * stark
	var s2 := sin(takt + PI) * stark
	# Positive Winkel schwingen nach hinten. Links/rechts gegengleich, das Knie beugt beim Zurueckschwingen,
	# der Arm schwingt gegen das gleichseitige Bein und der Ellbogen beugt nach vorn.
	_schwingen(_b[0], s * SCHRITT_BEIN)
	_schwingen(_b[1], s2 * SCHRITT_BEIN)
	_schwingen(_b[2], maxf(s, 0.0) * KNIE_BEUGE)
	_schwingen(_b[3], maxf(s2, 0.0) * KNIE_BEUGE)
	_schwingen(_b[4], -s * SCHRITT_ARM)
	_schwingen(_b[5], -s2 * SCHRITT_ARM)
	_schwingen(_b[6], -(0.15 + maxf(s, 0.0) * ELLBOGEN_BEUGE) * stark)
	_schwingen(_b[7], -(0.15 + maxf(s2, 0.0) * ELLBOGEN_BEUGE) * stark)


## Dreht einen Knochen um die Querachse der Figur (Vor-/Zurueckschwingen). Die Knochenachsen des Rigs sind
## gedreht, deshalb wird die Achse aus Figurenraum in den Raum des Knochens umgerechnet.
func _schwingen(knochen: int, winkel: float) -> void:
	if knochen < 0:
		return
	var achse_welt := _figur.global_basis * Vector3.RIGHT
	var achse_skelett := _skelett.global_basis.inverse() * achse_welt
	var achse_knochen := (_skelett.get_bone_global_rest(knochen).basis.inverse() * achse_skelett).normalized()
	# Die Pose ersetzt die lokale Drehung (nicht relativ zur Ruhelage): Ruhedrehung mal Schwung
	var ruhe := _skelett.get_bone_rest(knochen).basis.get_rotation_quaternion()
	_skelett.set_bone_pose_rotation(knochen, ruhe * Quaternion(achse_knochen, winkel))
