class_name Roquette
extends Node3D
## Projectile du lance-roquettes : file droit, explose au contact (dégâts de zone + destruction
## des structures « destructibles »).

const VITESSE := 55.0

var tireur = null
var dir := Vector3.FORWARD
var degats := 160.0
var vie := 4.0


static func creer(par, pos: Vector3, d: Vector3, deg: float) -> Roquette:
	var r := Roquette.new()
	r.tireur = par
	r.position = pos
	r.dir = d
	r.degats = deg
	return r


func _ready() -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.14, 0.14, 0.7)
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.25, 0.3, 0.22)
	mi.material_override = m
	add_child(mi)
	var flamme := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(0.18, 0.18, 0.5)
	flamme.mesh = fm
	var m2 := StandardMaterial3D.new()
	m2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m2.albedo_color = Color(1, 0.55, 0.1)
	flamme.material_override = m2
	flamme.position.z = 0.55
	add_child(flamme)
	look_at_from_position(position, position + dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT)


func _physics_process(dt: float) -> void:
	if Etat.partie == null or not Etat.partie.actif:
		return
	vie -= dt
	var a := global_position
	var b := a + dir * VITESSE * dt
	var q := PhysicsRayQueryParameters3D.create(a, b, Etat.MASQUE_TIR)
	var amis: Array[RID] = []
	var prop = Etat.proprietaire(tireur)
	for n in [tireur, prop, prop.titan if prop is Pilote else null, prop.bouclier if prop is Pilote else null]:
		if n is CollisionObject3D:
			amis.append(n.get_rid())
	q.exclude = amis
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if not r.is_empty():
		exploser(r.position - dir * 0.2)
	elif vie <= 0.0:
		exploser(b)
	else:
		global_position = b


func exploser(pos: Vector3) -> void:
	Etat.explode(pos, 7.0, degats, tireur)
	Etat.detruire_structures(pos, 8.0)
	Fx.explosion(pos, 14.0)
	queue_free()
