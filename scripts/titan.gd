class_name Titan
extends CharacterBody3D
## Le Titan (bot/allie.py) : tombe du ciel, puis combat en mode auto (« allié » du pilote)
## quand le pilote n'est pas à bord. Le joueur peut embarquer / éjecter.

const GRAVITE := 22.0

var proprio = null                  # Pilote propriétaire
var state := "falling"              # falling / ready / embarque
var hp := 400.0
var hp_max := 400.0
var r := 1.6
var h := 6.0
var vivant := true
var vy := 0.0
var arme: Arme
var cible = null
var pense := 0.0
var marker: MeshInstance3D
var flamme: MeshInstance3D
var modele: Node3D
var ordre := "suivre"                 # suivre / tenir / attaquer / aller
var point_garde := Vector3.ZERO
var cd_epee := 0.0
var route: Array = []
var rt := 0.0
var bloque_t := 0.0


static func creer(par, spot: Vector3) -> Titan:
	var t := Titan.new()
	t.proprio = par
	t.position = Vector3(spot.x, 70.0, spot.z)
	return t


func _ready() -> void:
	collision_layer = Etat.COUCHE_TITAN
	collision_mask = Etat.COUCHE_MONDE
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = r
	cap.height = h
	cs.shape = cap
	cs.position.y = h * 0.5
	add_child(cs)
	_construire()
	# marqueur d'impact au sol + flamme de descente
	marker = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2.ONE * 7.0
	marker.mesh = pm
	marker.material_override = _mat(Color(1, 0.4, 0, 0.6), true)
	marker.top_level = true
	add_child(marker)
	marker.global_position = Vector3(position.x, 0.06, position.z)
	flamme = _boite(self, Vector3(1.6, 8.0, 1.6), Vector3(0, 5, 0), _mat(Color(1, 0.55, 0.1, 0.6), true))
	arme = _nouvelle_arme()
	Etat.titans.append(self)


func _mat(c: Color, unshaded := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func _boite(parent: Node3D, taille: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = taille
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _construire() -> void:
	modele = Node3D.new()
	add_child(modele)
	var c := Color.from_hsv(210.0 / 360.0, 0.15, 0.32)
	var c2 := Color.from_hsv(210.0 / 360.0, 0.1, 0.2)
	var ora := Color.from_hsv(20.0 / 360.0, 0.9, 0.9)
	var noir := Color.from_hsv(210.0 / 360.0, 0.1, 0.15)
	# (taille, position, couleur) ; z inversé par rapport au Python (avant = -z)
	var parts := [
		[Vector3(1.3, 3.0, 1.4), Vector3(-0.95, 1.5, 0), c], [Vector3(1.3, 3.0, 1.4), Vector3(0.95, 1.5, 0), c],
		[Vector3(1.5, 0.6, 2.1), Vector3(-0.95, 0.3, -0.3), c2], [Vector3(1.5, 0.6, 2.1), Vector3(0.95, 0.3, -0.3), c2],
		[Vector3(2.8, 1.2, 1.8), Vector3(0, 3.4, 0), c2], [Vector3(3.6, 2.8, 2.3), Vector3(0, 5.2, 0), c],
		[Vector3(1.5, 1.0, 2.6), Vector3(-2.4, 6.2, 0), c2], [Vector3(1.5, 1.0, 2.6), Vector3(2.4, 6.2, 0), c2],
		[Vector3(1.1, 1.0, 1.1), Vector3(0, 7.0, -0.2), c2], [Vector3(0.95, 0.28, 0.3), Vector3(0, 7.05, -0.8), ora],
		[Vector3(0.9, 0.9, 3.4), Vector3(2.4, 4.8, -1.4), noir],
		[Vector3(1.0, 2.4, 1.0), Vector3(-2.5, 4.6, -0.3), c], [Vector3(1.6, 2.2, 0.3), Vector3(-2.5, 4.4, -1.0), ora],
		[Vector3(1.0, 0.35, 1.0), Vector3(0, 5.2, 1.3), ora],
	]
	for p in parts:
		_boite(modele, p[0], p[1], _mat(p[2]))


func _nouvelle_arme() -> Arme:
	var a := Arme.pour_titan(proprio.armes[0])
	a.cadence *= 1.8                       # l'IA tire moins vite qu'un joueur
	return a


func tete() -> Vector3:
	return global_position + Vector3(0, 5.2, 0)


# ------------------------------------------------------------------ boucle ----
func _physics_process(dt: float) -> void:
	if Etat.partie == null or not Etat.partie.actif or not vivant:
		return
	if state == "falling":
		vy += 25.0 * dt
		position.y -= vy * dt
		if position.y <= 0.0:
			position.y = 0.0
			state = "ready"
			marker.queue_free()
			flamme.queue_free()
			Fx.secousse(1.0)
			Fx.explosion(global_position + Vector3(0, 0.5, 0), 16.0, Color.WHITE)
			Etat.explode(global_position, 9.0, 300.0, self, [proprio])
	elif state == "ready":
		_ia(dt)


## Marche vers `but` en suivant le chemin du navmesh (contourne bâtiments et décors) ;
## si le Titan reste coincé, il recalcule son chemin.
func _aller_a(but: Vector3, v: float, dt: float) -> void:
	rt -= dt
	var avant := global_position
	if rt <= 0.0 or (route.is_empty() and Vector2(but.x - global_position.x, but.z - global_position.z).length() > 6.0):
		rt = 1.5 if bloque_t < 0.6 else 0.3
		route = Nav.route_gros(global_position, but)
		bloque_t = 0.0
	var cible_p := but
	while route.size() > 0:
		var w: Vector3 = route[0]
		if Vector2(w.x - global_position.x, w.z - global_position.z).length() < 2.5:
			route.pop_front()
		else:
			cible_p = w
			break
	var d := cible_p - global_position
	d.y = 0.0
	if d.length() > 0.1:
		_bouger(d.normalized(), v, dt)
	var dep := Vector2(global_position.x - avant.x, global_position.z - avant.z).length()
	bloque_t = bloque_t + dt if dep < v * dt * 0.3 else 0.0
	if bloque_t > 0.8:
		rt = 0.0                                      # coincé : on recalcule


func _bouger(dir: Vector3, v: float, dt: float) -> void:
	velocity.x = dir.x * v
	velocity.z = dir.z * v
	velocity.y = -1.0 if is_on_floor() else velocity.y - GRAVITE * dt
	move_and_slide()


## Coup d'épée : arc de 5,5 m devant `origine`, 150 dégâts à tout ce qui est touché.
## `par` = le Titan ou le pilote à bord ; `titan_ref` = Titan exclu (le sien).
static func frappe(par, origine: Vector3, dir: Vector3, titan_ref) -> int:
	var prop = Etat.proprietaire(par)
	var d := Vector3(dir.x, 0, dir.z).normalized()
	var centre: Vector3 = par.global_position
	var n := 0
	Fx.epee(Vector3(centre.x, centre.y + 3.5, centre.z) + d * 2.0, d)
	for c in Etat.toutes_cibles():
		if c == par or c == prop or c == titan_ref or (prop is Pilote and c == prop.titan):
			continue
		var v: Vector3 = c.global_position - centre
		v.y = 0.0
		var dist: float = v.length() - c.r
		if dist < 5.5 and (v.normalized().dot(d) > 0.15 or v.length() < 2.5) and absf(c.global_position.y - centre.y) < 4.0:
			c.damage(150.0, prop if prop != null else par)
			Fx.sang(c.global_position + Vector3(0, 1.2, 0), 5)
			n += 1
	return n


func _chercher():
	var best = null
	var bs := 1e9
	var portee := 1.0
	if ordre == "attaquer":
		portee = 1.7
	elif ordre == "tenir":
		portee = 1.0
	for c in Etat.toutes_cibles():
		if c == self or Etat.est_ami(c, self):
			continue
		var d := Vector2(c.global_position.x - global_position.x, c.global_position.z - global_position.z).length()
		var lim := (40.0 if c is Zombie else 55.0) * portee
		if d > lim:
			continue
		var sc := d * (0.7 if c is Pilote else 1.0)
		if sc < bs and Etat.visible_entre(self, tete(), c.global_position + Vector3(0, c.h * 0.55, 0)):
			best = c
			bs = sc
	return best


func _ia(dt: float) -> void:
	arme.update(dt)
	cd_epee -= dt
	pense -= dt
	if pense <= 0.0:
		pense = 0.4
		if arme.modele != proprio.armes[0].modele:      # le pilote a changé d'arme
			arme = _nouvelle_arme()
		cible = _chercher()
	var c = cible
	if c != null and (not is_instance_valid(c) or not c.vivant):
		c = null
		cible = null
	var bouge := false
	if c != null:
		var d: Vector3 = c.global_position - global_position
		d.y = 0.0
		var dist := d.length()
		var dn := Vector3(0, 0, -1).rotated(Vector3.UP, rotation.y)
		if dist > 0.1:
			dn = d / dist
			rotation.y = atan2(-dn.x, -dn.z)
		# ÉPÉE : à portée de bras on frappe au lieu de tirer
		if dist - c.r < 5.0 and cd_epee <= 0.0:
			cd_epee = 1.0
			Titan.frappe(self, global_position, dn, self)
		elif arme.pret():
			var cp: Vector3 = c.global_position + Vector3(0, c.h * 0.55, 0)
			var org := tete()
			if Etat.visible_entre(self, org, cp):
				var jit := Vector3(randf_range(-1, 1), randf_range(-0.5, 0.5), randf_range(-1, 1)) * dist * 0.03
				arme.tirer(self, org, cp - org + jit, org + dn * 2.0)
				Etat.bruit(global_position)
		match ordre:
			"suivre":
				if dist > 32.0:
					_aller_a(c.global_position, 5.0, dt)
					bouge = true
			"attaquer":
				if dist > 14.0:
					_aller_a(c.global_position, 6.5, dt)
					bouge = true
			"aller":
				bouge = _vers_point(dt)
	else:
		match ordre:
			"suivre":
				if proprio.vivant and not proprio.elimine:
					var d2: Vector3 = proprio.global_position - global_position
					d2.y = 0.0
					if d2.length() > 14.0:
						var dn2 := d2.normalized()
						rotation.y = atan2(-dn2.x, -dn2.z)
						_aller_a(proprio.global_position, 6.0, dt)
						bouge = true
			"aller":
				bouge = _vers_point(dt)
			_:
				pass
	if not bouge:
		_bouger(Vector3.ZERO, 0.0, dt)


## Marche vers `point_garde` ; arrivé, passe en « tenir ». Retourne true si en mouvement.
func _vers_point(dt: float) -> bool:
	var d := point_garde - global_position
	d.y = 0.0
	if d.length() < 3.0:
		ordre = "tenir"
		return false
	var dn := d.normalized()
	rotation.y = atan2(-dn.x, -dn.z)
	_aller_a(point_garde, 6.0, dt)
	return true


# ---------------------------------------------------- pilotage par le joueur ----
func embarquer() -> void:
	state = "embarque"
	visible = false
	collision_layer = 0


func debarquer(pos: Vector3, nouveaux_hp: float) -> void:
	hp = nouveaux_hp
	global_position = Vector3(pos.x, 0.05, pos.z)
	state = "ready"
	visible = true
	collision_layer = Etat.COUCHE_TITAN


func damage(n: float, _source = null, _tete := false) -> void:
	if state != "ready" or not vivant:
		return
	hp -= n * 0.7
	if hp <= 0.0:
		detruire()


func detruire(explose := true) -> void:
	if not vivant:
		return
	vivant = false
	Etat.titans.erase(self)
	if explose:
		Fx.explosion(global_position + Vector3(0, 3, 0), 16.0)
		Etat.explode(global_position, 10.0, 250.0, self, [proprio])
	if proprio != null and proprio.titan == self:
		proprio.titan = null
		proprio.titan_cd = 25.0
	queue_free()
