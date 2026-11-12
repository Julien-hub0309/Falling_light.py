class_name Fx
extends RefCounted
## Particules et effets visuels (effets.py) : étincelles, sang, flash, impacts, explosions, secousse.
## Particules = petites boîtes animées par Tween, avec un budget maximum pour garder de bons FPS.

const MAX := 160
static var budget := 0


static func _racine() -> Node:
	return Etat.get_tree().current_scene


static func _libre(n: int) -> bool:
	if budget + n > MAX:
		return false
	budget += n
	Etat.get_tree().create_timer(1.6).timeout.connect(func(): Fx.budget = maxi(0, Fx.budget - n))
	return true


static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func _forme(mesh: Mesh, pos: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(c)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_racine().add_child(mi)
	mi.global_position = pos
	return mi


static func _cube(taille: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3.ONE * taille
	return b


static func _sphere(rayon: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = rayon
	s.height = rayon * 2.0
	s.radial_segments = 12
	s.rings = 6
	return s


static func _particule(pos: Vector3, vec: Vector3, col: Color, taille: float, dur: float) -> void:
	var e := _forme(_cube(taille), pos, col)
	var cible := pos + vec + Vector3(0, -absf(vec.y) * 0.3 - 0.4, 0)
	var tw := e.create_tween().set_parallel(true)
	tw.tween_property(e, "global_position", cible, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(e, "scale", Vector3.ONE * 0.01, dur)
	tw.chain().tween_callback(e.queue_free)


static func etincelles(pos: Vector3, col := Color.YELLOW, n := 5, vit := 2.2, dur := 0.35, taille := 0.07) -> void:
	if not _libre(n):
		return
	for i in n:
		var v := Vector3(randf_range(-1, 1), randf_range(0.2, 1.2), randf_range(-1, 1)) * vit
		_particule(pos, v, col, taille, dur * randf_range(0.7, 1.2))


static func sang(pos: Vector3, n := 7) -> void:
	if not _libre(n):
		return
	for i in n:
		var v := Vector3(randf_range(-1, 1), randf_range(0.3, 1.4), randf_range(-1, 1)) * 2.2
		_particule(pos, v, Color.from_hsv(0.0, 0.9, randf_range(0.35, 0.6)), randf_range(0.05, 0.1), 0.5)


static func flash(pos: Vector3, taille := 0.2) -> void:
	var e := _forme(_sphere(taille * 0.5), pos, Color(1, 0.85, 0.4, 0.9))
	Etat.get_tree().create_timer(0.05).timeout.connect(e.queue_free)


static func impact(pos: Vector3) -> void:
	etincelles(pos, Color(0.8, 0.8, 0.8), 3, 1.6, 0.25, 0.05)


static func explosion(pos: Vector3, taille := 8.0, col := Color(1, 0.55, 0.1)) -> void:
	if taille < 4.0:
		flash(pos, taille * 0.5)
		etincelles(pos, col, 6, 2.5, 0.4, 0.1)
		return
	if not _libre(14):
		return
	var boule := _forme(_sphere(0.5), pos, Color(col.r, col.g, col.b, 0.9))
	boule.scale = Vector3.ONE * 0.3
	var tw := boule.create_tween().set_parallel(true)
	tw.tween_property(boule, "scale", Vector3.ONE * taille, 0.28).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(boule.material_override, "albedo_color", Color(0.25, 0.1, 0.05, 0.0), 0.55)
	tw.chain().tween_callback(boule.queue_free)
	var coeur := _forme(_sphere(0.5), pos, Color(1, 1, 0.85, 1))
	coeur.scale = Vector3.ONE * 0.2
	var tc := coeur.create_tween().set_parallel(true)
	tc.tween_property(coeur, "scale", Vector3.ONE * taille * 0.55, 0.15)
	tc.tween_property(coeur.material_override, "albedo_color", Color(1, 1, 0.8, 0.0), 0.2)
	tc.chain().tween_callback(coeur.queue_free)
	var onde := _forme(_sphere(0.5), Vector3(pos.x, maxf(pos.y, 0.15), pos.z), Color(1, 1, 1, 0.3))
	onde.scale = Vector3(0.5, 0.12, 0.5)
	var to := onde.create_tween().set_parallel(true)
	to.tween_property(onde, "scale", Vector3(taille * 2.3, 0.15, taille * 2.3), 0.3).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	to.tween_property(onde.material_override, "albedo_color", Color(1, 1, 1, 0.0), 0.3)
	to.chain().tween_callback(onde.queue_free)
	for i in 6:
		var v := Vector3(randf_range(-1, 1), randf_range(0.5, 1.6), randf_range(-1, 1)) * taille * 0.45
		_particule(pos, v, Color.from_hsv(randf_range(10.0, 40.0) / 360.0, 0.9, 1.0), randf_range(0.12, 0.3), 0.7)
	for i in 3:
		var f := _forme(_sphere(0.5), pos + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * taille * 0.2, Color(0.22, 0.22, 0.22, 0.55))
		f.scale = Vector3.ONE * taille * 0.3
		var tf := f.create_tween().set_parallel(true)
		tf.tween_property(f, "global_position", f.global_position + Vector3(0, taille * 0.9, 0), 1.4)
		tf.tween_property(f, "scale", Vector3.ONE * taille * 0.8, 1.4)
		tf.tween_property(f.material_override, "albedo_color", Color(0.2, 0.2, 0.2, 0.0), 1.4)
		tf.chain().tween_callback(f.queue_free)


static func secousse(a: float) -> void:
	var j = Etat.joueur
	if j != null:
		j.shake = maxf(j.shake, minf(a, 1.6))


## Onde de sonar / de choc : anneau plat qui s'élargit.
static func onde(pos: Vector3, rayon: float, col := Color(0.3, 0.9, 1.0, 0.5)) -> void:
	var o := _forme(_sphere(0.5), Vector3(pos.x, pos.y + 0.2, pos.z), col)
	o.scale = Vector3(1.0, 0.05, 1.0)
	var t := o.create_tween().set_parallel(true)
	t.tween_property(o, "scale", Vector3(rayon * 2.0, 0.08, rayon * 2.0), 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(o.material_override, "albedo_color", Color(col.r, col.g, col.b, 0.0), 0.9)
	t.chain().tween_callback(o.queue_free)


## Coup d'épée du Titan : arc lumineux devant `pos` dans la direction `dir`.
static func epee(pos: Vector3, dir: Vector3) -> void:
	var e := _forme(_cube(1.0), pos, Color(1, 0.7, 0.25, 0.8))
	(e.mesh as BoxMesh).size = Vector3(6.0, 0.25, 0.7)
	var haut := Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT
	e.look_at(pos + dir, haut)
	e.rotation.z = deg_to_rad(-70.0)
	var t := e.create_tween().set_parallel(true)
	t.tween_property(e, "rotation:z", deg_to_rad(70.0), 0.18)
	t.tween_property(e.material_override, "albedo_color", Color(1, 0.7, 0.25, 0.0), 0.28)
	t.chain().tween_callback(e.queue_free)
