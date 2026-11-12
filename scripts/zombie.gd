class_name Zombie
extends CharacterBody3D
## Zombie (bot/zombie_commun.py, zombie_jour.py, zombie_nuit.py).
## 4 types : jour_normal, jour_special, nuit_normal, rapace.
## Les spéciaux (jour) et les rapaces (nuit) sont attirés par les coups de feu.

const GRAVITE := 22.0

var kind := "jour_normal"
var r := 0.45
var h := 1.9
var vivant := true
var hp := 40.0
var hp_max := 40.0
var vitesse_base := 2.0
var degats := 7.0
var detection := 32.0
var delai_attaque := 1.0
var anim_vitesse := 5.0
var ecoute_bruit := false
var var_vit := 1.0

var cible = null
var pense := 0.0
var atk := 0.0
var flash := 0.0
var anim := 0.0
var dest := Vector3.ZERO
var dest_t := 0.0
var alerte_actif := false
var alerte_pos := Vector3.ZERO
var alerte_t := 0.0
var bloque := 0.0
var route: Array = []
var forcer_detection := 0.0
var stun_t := 0.0
var rt := 0.0

var torse: MeshInstance3D
var modele: Node3D
var tete: MeshInstance3D
var yeux: Array = []
var bras: Array = []
var jambes: Array = []
var mat_torse: StandardMaterial3D


static func stats(k: String) -> Dictionary:
	match k:
		"jour_special":
			return {"hp": 40.0 * 2.0, "v": 2.0 * 1.5, "deg": 12.0, "det": 32.0, "delai": 0.9, "anim": 7.0,
				"bruit": true, "tete": Color.from_hsv(30.0 / 360.0, 0.5, 0.5), "yeux": Color(1, 0.45, 0.1)}
		"geant":   # 220 % de vie, 80 % de vitesse (cahier des charges) ; 5 par partie, la nuit
			return {"hp": 70.0 * 2.2, "v": 4.6 * 0.8, "deg": 25.0, "det": 75.0, "delai": 1.2, "anim": 5.0,
				"bruit": false, "tete": Color(0.3, 0.08, 0.08), "yeux": Color(1, 0.1, 0.05)}
		"nuit_normal":
			return {"hp": 70.0, "v": 4.6, "deg": 14.0, "det": 75.0, "delai": 0.7, "anim": 9.0,
				"bruit": false, "tete": Color.from_hsv(8.0 / 360.0, 0.5, 0.42), "yeux": Color(1, 0.1, 0.05)}
		"rapace":
			return {"hp": 70.0 * 1.7, "v": 4.6, "deg": 14.0, "det": 75.0, "delai": 0.7, "anim": 9.0,
				"bruit": true, "tete": Color.from_hsv(285.0 / 360.0, 0.55, 0.4), "yeux": Color(0.8, 0.2, 1)}
		_:  # jour_normal : 150 % de vie, 80 % de vitesse
			return {"hp": 40.0 * 1.5, "v": 2.0 * 0.8, "deg": 7.0, "det": 32.0, "delai": 1.0, "anim": 5.0,
				"bruit": false, "tete": Color.from_hsv(85.0 / 360.0, 0.3, 0.5), "yeux": Color(0.9, 0.8, 0.2)}


## Crée un zombie du type voulu à `pos` (à appeler avant add_child ou juste après).
static func creer(k: String, pos: Vector3) -> Zombie:
	var z := Zombie.new()
	z.kind = k
	z.position = Vector3(pos.x, 0.05, pos.z)
	return z


func _ready() -> void:
	if kind == "geant":
		r = 0.75
		h = 3.1
	collision_layer = Etat.COUCHE_ZOMBIE
	collision_mask = Etat.COUCHE_MONDE
	floor_snap_length = 0.3
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = r
	cap.height = h
	cs.shape = cap
	cs.position.y = h * 0.5
	add_child(cs)
	var s := stats(kind)
	hp_max = s["hp"]
	hp = hp_max
	vitesse_base = s["v"]
	degats = s["deg"]
	detection = maxf(s["det"], forcer_detection)
	delai_attaque = s["delai"]
	anim_vitesse = s["anim"]
	ecoute_bruit = s["bruit"]
	var_vit = randf_range(0.85, 1.15)
	anim = randf_range(0.0, 6.0)
	_construire(s)
	Etat.zombies.append(self)


## Passage à la nuit : les zombies encore en vie deviennent plus forts et plus rapides.
func passer_nuit() -> void:
	if kind == "nuit_normal" or kind == "rapace" or kind == "geant":
		return
	var ratio := hp / hp_max
	kind = "rapace" if kind == "jour_special" else "nuit_normal"
	var s := stats(kind)
	hp_max = s["hp"]
	hp = hp_max * ratio
	vitesse_base = s["v"]
	degats = s["deg"]
	detection = maxf(s["det"], forcer_detection)
	delai_attaque = s["delai"]
	anim_vitesse = s["anim"]
	ecoute_bruit = s["bruit"]
	tete.material_override = _mat(s["tete"])
	for y in yeux:
		y.material_override = _mat(s["yeux"], true)


# ---------------------------------------------------------------- modèle ----
func _mat(c: Color, emissif := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	if emissif:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
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


func _construire(s: Dictionary) -> void:
	modele = Node3D.new()
	modele.scale = Vector3.ONE * (h / 1.9)
	add_child(modele)
	mat_torse = _mat(Color.from_hsv(randf(), 0.25, 0.3))
	var mat_jambe := _mat(Color.from_hsv(220.0 / 360.0, 0.2, 0.2))
	var mat_peau := _mat(Color.from_hsv(randf_range(70.0, 110.0) / 360.0, 0.3, 0.45))
	torse = _boite(modele, Vector3(0.55, 0.75, 0.28), Vector3(0, 1.2, 0), mat_torse)
	tete = _boite(modele, Vector3(0.32, 0.32, 0.32), Vector3(0, 1.78, 0), _mat(s["tete"]))
	for sx in [-0.08, 0.08]:
		yeux.append(_boite(modele, Vector3(0.06, 0.04, 0.02), Vector3(sx, 1.8, -0.17), _mat(s["yeux"], true)))
	for sx in [-0.36, 0.36]:
		var p := Node3D.new()                       # pivot à l'épaule
		p.position = Vector3(sx, 1.52, 0)
		modele.add_child(p)
		_boite(p, Vector3(0.14, 0.6, 0.14), Vector3(0, -0.3, 0), mat_peau)
		bras.append(p)
	for sx in [-0.14, 0.14]:
		var p := Node3D.new()                       # pivot à la hanche
		p.position = Vector3(sx, 0.82, 0)
		modele.add_child(p)
		_boite(p, Vector3(0.18, 0.82, 0.18), Vector3(0, -0.41, 0), mat_jambe)
		jambes.append(p)


# -------------------------------------------------------------------- IA ----
func alerter(pos: Vector3) -> void:
	alerte_actif = true
	alerte_pos = pos
	alerte_t = 12.0


func trouver_cible():
	var best = null
	var bd := detection
	for p in Etat.pilotes:
		if p.vivant and not p.elimine:
			var d := Vector2(p.global_position.x - global_position.x, p.global_position.z - global_position.z).length()
			if Competences.invisible(p) and d > 5.0:
				continue                                  # Recon camouflé : invisible au-delà de 5 m
			if d < bd:
				best = p
				bd = d
	return best


func _regarder(d: Vector3) -> void:
	rotation.y = atan2(-d.x, -d.z)


func _physics_process(dt: float) -> void:
	var P = Etat.partie
	if P == null or not P.actif or not vivant:
		return
	var vit := vitesse_base * var_vit
	if stun_t > 0.0:                                      # sonné par une charge explosive
		stun_t -= dt
		velocity.x = 0.0
		velocity.z = 0.0
		velocity.y = -1.0 if is_on_floor() else velocity.y - GRAVITE * dt
		move_and_slide()
		return
	# animation de marche / bras tendus
	anim += dt * anim_vitesse
	jambes[0].rotation.x = sin(anim) * deg_to_rad(35.0)
	jambes[1].rotation.x = -sin(anim) * deg_to_rad(35.0)
	var lunge := 14.0 if atk > delai_attaque * 0.5 else 0.0
	for i in bras.size():
		bras[i].rotation.x = deg_to_rad(80.0 + sin(anim * 0.7 + i * 2.0) * 8.0 + lunge)
	tete.rotation.z = deg_to_rad(8.0 + sin(anim * 0.5) * 6.0)
	flash -= dt
	mat_torse.emission_enabled = flash > 0.0
	mat_torse.emission = Color(1, 1, 1)
	atk -= dt
	pense -= dt
	if pense <= 0.0:
		pense = randf_range(0.25, 0.45)
		cible = trouver_cible()
	var c = cible
	if c != null and (not is_instance_valid(c) or not c.vivant or c.elimine):
		c = null
		cible = null

	var dir := Vector3.ZERO
	var v := 0.0
	rt -= dt
	if c != null:
		alerte_actif = false
		var haut: bool = c.global_position.y - global_position.y > 2.5
		if (haut or bloque > 0.8) and rt <= 0.0:          # cible sur un toit / chemin bloqué
			rt = 2.5
			bloque = 0.0
			route = Nav.route(global_position, c.global_position)
		var but: Vector3 = route[0] if route.size() > 0 else c.global_position
		var d: Vector3 = but - global_position
		d.y = 0.0
		var dist := d.length()
		var dc := Vector2(c.global_position.x - global_position.x, c.global_position.z - global_position.z).length()
		if route.size() > 0 and dist < 1.4:
			route.pop_front()
		elif dist > 0.01:
			dir = d / dist
			_regarder(dir)
			if dc > 1.2 or route.size() > 0:
				v = vit
		if dc < 1.7 and absf(c.global_position.y - global_position.y) < 2.2 and atk <= 0.0:
			atk = delai_attaque
			c.damage(degats, self)
	elif alerte_actif:
		alerte_t -= dt
		var d := alerte_pos - global_position
		d.y = 0.0
		if alerte_t <= 0.0 or d.length() < 2.5:
			alerte_actif = false
			route = []
		else:
			if bloque > 0.8 and rt <= 0.0:
				rt = 2.5
				bloque = 0.0
				route = Nav.route(global_position, alerte_pos)
			var but: Vector3 = route[0] if route.size() > 0 else alerte_pos
			var dd: Vector3 = but - global_position
			dd.y = 0.0
			if route.size() > 0 and dd.length() < 1.4:
				route.pop_front()
			elif dd.length() > 0.01:
				dir = dd.normalized()
				_regarder(dir)
				v = vit
	else:
		route = []
		dest_t -= dt
		if dest == Vector3.ZERO or dest_t <= 0.0 or bloque > 0.6:
			var a := randf_range(0.0, TAU)
			dest = Vector3(sin(a), 0, cos(a))
			dest_t = randf_range(2.0, 5.0)
			bloque = 0.0
		dir = dest
		_regarder(dir)
		v = vit * 0.5

	velocity.x = dir.x * v
	velocity.z = dir.z * v
	if is_on_floor():
		velocity.y = -1.0
	else:
		velocity.y -= GRAVITE * dt
	move_and_slide()
	# bloqué contre un obstacle : petit saut pour passer les marches / gravats
	if v > 0.0 and is_on_wall() and is_on_floor():
		bloque += dt
		if bloque > 0.35 and route.is_empty() and c != null and rt > 0.0:
			velocity.y = 6.0
	elif v > 0.0:
		bloque = maxf(0.0, bloque - dt)


# ---------------------------------------------------------------- dégâts ----
func damage(n: float, source = null, _tete := false) -> void:
	if not vivant:
		return
	hp -= n
	flash = 0.08
	if hp <= 0.0:
		Fx.sang(global_position + Vector3(0, 1.2, 0), 10)
		vivant = false
		Etat.zombies.erase(self)
		Etat.partie.mort_zombie(self, source)
		queue_free()
