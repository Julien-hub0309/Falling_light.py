class_name Bouclier
extends StaticBody3D
## Bouclier portatif du Tactique : une couverture déployable qui absorbe les dégâts (300 PV, 25 s).

var proprio = null
var hp := 300.0
var h := 2.2
var r := 1.7
var vie := 25.0
var vivant := true


static func creer(par, pos: Vector3, yaw: float) -> Bouclier:
	var b := Bouclier.new()
	b.proprio = par
	b.position = pos
	b.rotation.y = yaw
	return b


func _ready() -> void:
	collision_layer = Etat.COUCHE_MONDE
	collision_mask = 0
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(3.4, 2.2, 0.3)
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.25, 0.6, 1.0, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = Color(0.2, 0.5, 1.0)
	m.emission_energy_multiplier = 0.6
	mi.material_override = m
	mi.position.y = 1.1
	add_child(mi)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(3.4, 2.2, 0.3)
	cs.shape = sh
	cs.position.y = 1.1
	add_child(cs)


func _physics_process(dt: float) -> void:
	if Etat.partie == null or not Etat.partie.actif:
		return
	vie -= dt
	if vie <= 0.0:
		casser(false)


func damage(n: float, _source = null, _tete := false) -> void:
	hp -= n
	Fx.etincelles(global_position + Vector3(0, 1.2, 0), Color(0.4, 0.7, 1), 3)
	if hp <= 0.0:
		casser(true)


func casser(avec_effet: bool) -> void:
	if not vivant:
		return
	vivant = false
	if avec_effet:
		Fx.explosion(global_position + Vector3(0, 1, 0), 3.0, Color(0.4, 0.7, 1))
	if proprio != null and is_instance_valid(proprio) and proprio.bouclier == self:
		proprio.bouclier = null
	queue_free()
