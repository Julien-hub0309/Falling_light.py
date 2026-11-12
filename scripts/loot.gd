class_name Loot
extends Node3D
## Objets à ramasser (map/loot.py) : soin, munitions, armure, grenade, arme.
## Le ramassage est géré par Partie.ramassage() (~10 fois par seconde).

const TYPES := {
	"soin": [Color(0.2, 0.9, 0.2), 5], "munitions": [Color(1, 0.9, 0.1), 5],
	"armure": [Color(0.1, 0.5, 1.0), 3], "grenade": [Color(1, 0.55, 0.1), 2],
	"arme": [Color(1, 0.15, 0.15), 3],
}

var type := "soin"
var temporaire := false
var vie := 45.0
var actif := true
var t := 0.0
var cube: MeshInstance3D


static func type_aleatoire() -> String:
	var total := 0
	for k in TYPES:
		total += TYPES[k][1]
	var x := randi() % total
	for k in TYPES:
		x -= TYPES[k][1]
		if x < 0:
			return k
	return "soin"


static func creer(pos: Vector3, t: String = "", temp := false) -> Loot:
	var l := Loot.new()
	l.type = t if t != "" else type_aleatoire()
	if Etat.mode_jeu == "parcours" and l.type == "arme":
		l.type = "soin"
	l.temporaire = temp
	l.position = pos
	return l


func _ready() -> void:
	var col: Color = TYPES[type][0]
	cube = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE * 0.5
	cube.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	cube.material_override = m
	cube.position.y = 0.7
	add_child(cube)
	# rayon lumineux repérable de loin
	var rayon := MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = Vector3(0.1, 7.0, 0.1)
	rayon.mesh = rm
	var m2 := StandardMaterial3D.new()
	m2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m2.albedo_color = Color(col.r, col.g, col.b, 0.35)
	rayon.material_override = m2
	rayon.position.y = 3.5
	rayon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rayon)
	t = randf_range(0.0, 6.0)
	Etat.loots.append(self)


func _process(dt: float) -> void:
	var j = Etat.joueur
	if Etat.partie == null or not Etat.partie.actif or j == null:
		return
	if absf(j.global_position.x - global_position.x) > 70.0 or absf(j.global_position.z - global_position.z) > 70.0:
		return
	t += dt
	cube.rotation.y += deg_to_rad(90.0) * dt
	cube.position.y = 0.7 + sin(t * 2.0) * 0.12


func prendre() -> void:
	if temporaire:
		retirer()
	else:
		actif = false
		visible = false
		Etat.partie.plus_tard(45.0, reapparaitre)


func reapparaitre() -> void:
	if Etat.mode_jeu == "parcours" and type == "arme":
		return
	actif = true
	visible = true


func retirer() -> void:
	Etat.loots.erase(self)
	queue_free()
