class_name Grenade
extends RigidBody3D
## Grenade à fragmentation et fumigène (armes/grenade.py) + nuage de fumée.
## Physique réelle de Godot (rebonds) au lieu des collisions AABB maison.

var tireur = null
var type := "frag"
var fuse := 2.4


static func creer(par, pos: Vector3, vitesse: Vector3, t := "frag") -> Grenade:
	var g := Grenade.new()
	g.tireur = par
	g.type = t
	if t == "charge":
		g.fuse = 1.1
	g.position = pos
	g.linear_velocity = vitesse
	return g


func _ready() -> void:
	collision_layer = 0
	collision_mask = Etat.COUCHE_MONDE
	gravity_scale = 22.0 / 9.8              # même gravité qu'en Python
	mass = 0.4
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.35
	pm.friction = 0.8
	physics_material_override = pm
	linear_damp = 0.15
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.14
	cs.shape = sh
	add_child(cs)
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.14
	sm.height = 0.28
	mi.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.25, 0.25, 0.25) if type == "frag" else (Color(1, 0.45, 0.1) if type == "charge" else Color(0.8, 0.8, 0.8))
	mi.material_override = m
	add_child(mi)


func _physics_process(dt: float) -> void:
	if Etat.partie == null or not Etat.partie.actif:
		return
	fuse -= dt
	if fuse <= 0.0:
		detoner()


func detoner() -> void:
	if type == "frag":
		Etat.explode(global_position, 6.0, 110.0, tireur)
	elif type == "charge":
		# Charge explosive (Breacher) : détruit les structures et SONNE les ennemis proches
		Etat.explode(global_position, 6.0, 60.0, tireur)
		Etat.detruire_structures(global_position, 7.0)
		Etat.etourdir(global_position, 9.0, tireur)
	else:
		var f := Fumee.creer(global_position)
		get_tree().current_scene.add_child(f)
	queue_free()


## Nuage de fumée : bloque la ligne de vue des bots (Etat.visible_entre).
class Fumee extends MeshInstance3D:
	var rayon := 6.0
	var vie := 12.0

	static func creer(pos: Vector3, r := 6.0, duree := 12.0) -> Fumee:
		var f := Fumee.new()
		f.rayon = r
		f.vie = duree
		f.position = Vector3(pos.x, maxf(pos.y, 0.5), pos.z)
		return f

	func _ready() -> void:
		var sm := SphereMesh.new()
		sm.radius = rayon
		sm.height = rayon * 2.0
		mesh = sm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.8, 0.8, 0.8, 0.78)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material_override = m
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		Etat.fumees.append(self)

	func _physics_process(dt: float) -> void:
		if Etat.partie == null or not Etat.partie.actif:
			return
		vie -= dt
		if vie <= 0.0:
			Etat.fumees.erase(self)
			queue_free()

	func _exit_tree() -> void:
		Etat.fumees.erase(self)
