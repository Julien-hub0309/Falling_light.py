class_name PiloteIA
extends Pilote
## Pilotes IA rivaux (bot/ennemie.py) : chassent les zombies et les pilotes, ramassent le loot,
## lancent des grenades. (Le Titan viendra en phase 3.)

var col := Color.RED
var marche := false
var phase := 0.0
var route: Array = []
var a_dest := false
var cible = null
var vu := false
var pense := 0.0
var flash := 0.0
var react := 0.0
var strafe := 1.0
var strafe_t := 0.0
var bloque := 0.0
var regen_mun := 0.0
var m := {}
var couv_actif := false
var couv_t := 0.0
var torse: MeshInstance3D
var mat_torse: StandardMaterial3D


static func creer(n: String, c: Color) -> PiloteIA:
	var p := PiloteIA.new()
	p.nom = n
	p.col = c
	return p


func _ready() -> void:
	super._ready()
	_construire()
	visible = false


# ------------------------------------------------------------- modèle ----
func _mat(c: Color, unshaded := false) -> StandardMaterial3D:
	var mt := StandardMaterial3D.new()
	mt.albedo_color = c
	if unshaded:
		mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mt


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
	mat_torse = _mat(col)
	var pantalon := _mat(Color.from_hsv(0.0, 0.0, 0.18))
	var peau := _mat(Color.from_hsv(25.0 / 360.0, 0.4, 0.8))
	var noir := _mat(Color.from_hsv(0.0, 0.0, 0.1))
	m["jambes"] = []
	m["bras"] = []
	for sx in [-1.0, 1.0]:
		var piv := Node3D.new()
		piv.position = Vector3(sx * 0.18, 0.88, 0)
		add_child(piv)
		_boite(piv, Vector3(0.26, 0.88, 0.3), Vector3(0, -0.44, 0), pantalon)
		_boite(piv, Vector3(0.28, 0.14, 0.42), Vector3(0, -0.84, -0.06), noir)
		m["jambes"].append(piv)
	torse = _boite(self, Vector3(0.74, 0.72, 0.4), Vector3(0, 1.26, 0), mat_torse)
	_boite(self, Vector3(0.7, 0.12, 0.38), Vector3(0, 0.93, 0), _mat(Color.from_hsv(30.0 / 360.0, 0.3, 0.2)))
	for sx in [-1.0, 1.0]:
		var piv := Node3D.new()
		piv.position = Vector3(sx * 0.47, 1.55, 0)
		add_child(piv)
		_boite(piv, Vector3(0.2, 0.72, 0.22), Vector3(0, -0.34, 0), mat_torse)
		_boite(piv, Vector3(0.16, 0.16, 0.18), Vector3(0, -0.74, 0), _mat(Color.from_hsv(0.0, 0.0, 0.08)))
		m["bras"].append(piv)
	_boite(self, Vector3(0.34, 0.36, 0.34), Vector3(0, 1.84, 0), peau)
	_boite(self, Vector3(0.4, 0.2, 0.4), Vector3(0, 1.99, 0.01), mat_torse)                      # casque
	_boite(self, Vector3(0.3, 0.09, 0.05), Vector3(0, 1.85, -0.18), _mat(Color(0.3, 0.9, 1), true))  # visière
	_boite(self, Vector3(0.5, 0.55, 0.22), Vector3(0, 1.3, 0.3), _mat(Color.from_hsv(0.0, 0.0, 0.13)))   # sac
	m["fusil"] = _boite(self, Vector3(0.1, 0.12, 0.75), Vector3(0.3, 1.05, -0.45), noir)
	m["bras"][1].rotation.x = deg_to_rad(75.0)


# ------------------------------------------------------------- hooks ----
func apres_respawn() -> void:
	cible = null
	a_dest = false
	route = []
	bloque = 0.0
	sur_changement_arme()


func sur_changement_arme() -> void:
	if m.is_empty() or armes.is_empty():
		return
	var a := arme_active()
	var taille := Vector3(0.1, 0.12, 0.75)
	match a.nom:
		"Kriss Vector": taille = Vector3(0.1, 0.12, 0.55)
		"DRS-50": taille = Vector3(0.09, 0.1, 1.1)
		"Pompe": taille = Vector3(0.1, 0.12, 0.85)
		"Pistolet": taille = Vector3(0.06, 0.08, 0.3)
		"Couteau": taille = Vector3(0.04, 0.04, 0.3)
	m["fusil"].mesh.size = taille


func avant_mort() -> void:
	visible = false


func sur_degats(source) -> void:
	flash = 0.08
	# riposte : cibler l'agresseur s'il est un pilote
	if source is Pilote and source != self and source.vivant:
		cible = source
		react = 0.3
		vu = false


# ---------------------------------------------------------- perception ----
func penser() -> void:
	if hp < hp_max * 0.5 and craft["kits_soin"] > 0:
		Craft.utiliser_soin(self)
	if cible != null and armure <= 0.0 and craft["kits_armure"] > 0:
		Craft.utiliser_armure(self)
	var oe := oeil()
	var cands: Array = []
	for c in Etat.toutes_cibles():
		if c == self or Etat.est_ami(c, self):
			continue                                      # jamais son propre Titan
		var d := Vector2(c.global_position.x - global_position.x, c.global_position.z - global_position.z).length()
		if c is Pilote and Competences.invisible(c) and d > 8.0:
			continue                                      # camouflé : invisible au-delà de 8 m
		var zom: bool = c is Zombie
		if zom and armes[0].melee() and d > 4.0:
			continue                               # sans arme à feu, on évite les zombies : cap sur le loot
		var lim := 26.0 if zom else 65.0
		var w := 1.0 if zom else 0.6
		if d < lim:
			cands.append([d * w, c])
	cands.sort_custom(func(a, b): return a[0] < b[0])
	cible = null
	vu = false
	for i in mini(3, cands.size()):
		var c = cands[i][1]
		if Etat.visible_entre(self, oe, c.global_position + Vector3(0, c.h * 0.6, 0)):
			if react <= 0.0:
				react = randf_range(0.25, 0.6)
			cible = c
			vu = true
			break
	if cible == null:
		if couv_actif and couv_t > 0.0:
			pass                                          # à couvert : on tient la position (soin / rechargement)
		else:
			couv_actif = false
			choisir_destination()
	else:
		# sous le feu, blessé ou en train de recharger : on se met à COUVERT
		var a_a := arme_active()
		if not couv_actif and not (cible is Zombie and cible.global_position.distance_to(global_position) < 8.0) \
				and (hp < hp_max * 0.5 or (a_a != null and a_a.rech > 0.0 and not a_a.melee())):
			chercher_couverture()
		actions_combat()


## Cherche un point à l'abri derrière un obstacle (bâtiment, mur, voiture...) par rapport à l'ennemi.
func chercher_couverture() -> void:
	var c = cible
	if c == null or not is_instance_valid(c):
		return
	var e: Vector3 = c.global_position
	var chest := e + Vector3(0, c.h * 0.6, 0)
	var moi := Vector2(global_position.x, global_position.z)
	var cands: Array = []
	for o in Etat.obstacles:
		var ce: Vector2 = o.get_center()
		var d := ce.distance_to(moi)
		if d < 24.0 and o.size.x < 70.0:
			cands.append([d, o])
	cands.sort_custom(func(a, b): return a[0] < b[0])
	var best_pos := Vector3.ZERO
	var best_d := 1e9
	for k in mini(14, cands.size()):
		var o: Rect2 = cands[k][1]
		var ce: Vector2 = o.get_center()
		var away := (ce - Vector2(e.x, e.z))
		if away.length() < 0.1:
			continue
		var p2 := ce + away.normalized() * (maxf(o.size.x, o.size.y) * 0.5 + 1.6)
		if not Etat.est_libre(p2.x, p2.y, 0.8):
			continue
		var p3 := Vector3(p2.x, global_position.y, p2.y)
		if Etat.visible_entre(self, p3 + Vector3(0, 1.4, 0), chest):
			continue                                      # encore exposé
		if not Nav.joignable(p3):
			continue
		var dd := moi.distance_to(p2)
		if dd < best_d:
			best_d = dd
			best_pos = p3
	if best_d < 1e8:
		route = Nav.route(global_position, best_pos)
		if route.is_empty():
			route = [best_pos]
		couv_actif = true
		couv_t = 4.0
		a_dest = true


func choisir_destination() -> void:
	if a_dest and bloque < 1.2 and route.size() > 0:
		return
	bloque = 0.0
	var a := arme_active()
	var besoin := ""
	if armes[0].melee():
		besoin = "arme"
	elif hp < hp_max * 0.55:
		besoin = "soin"
	elif not a.melee() and a.reserve >= 0 and a.reserve + a.munitions < a.chargeur:
		besoin = "munitions"
	var best = null
	var bd := 220.0 if besoin != "" else 130.0
	for l in Etat.loots:
		if not is_instance_valid(l) or not l.actif or (besoin != "" and l.type != besoin):
			continue
		if not Nav.joignable(l.global_position):
			continue
		var d := Vector2(l.global_position.x - global_position.x, l.global_position.z - global_position.z).length()
		if d < bd:
			best = l
			bd = d
	var dest: Vector3
	if besoin == "" and titan_actif() and titan.state == "ready" \
			and Vector2(titan.global_position.x - global_position.x, titan.global_position.z - global_position.z).length() > 35.0:
		dest = titan.global_position + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6))    # reste près de son Titan
	elif Etat.mode_jeu == "controle" and Etat.modes != null and Etat.modes.zone_active and besoin == "":
		var a2 := randf_range(0.0, TAU)
		dest = Etat.modes.zone + Vector3(cos(a2), 0, sin(a2)) * randf_range(0.0, 5.0)
	elif best != null and (besoin != "" or randf() < 0.75):
		dest = best.global_position
	else:
		dest = Etat.point_libre(1.0)
	route = Nav.route(global_position, dest)
	if route.is_empty():
		route = [dest]
	a_dest = true


func actions_combat() -> void:
	var c = cible
	# compétences de classe
	var dc0 := Vector2(c.global_position.x - global_position.x, c.global_position.z - global_position.z).length()
	if Competences.niveau(self) >= 2 and comp["cd_actif"] <= 0.0 and randf() < 0.25:
		match Competences.cle(self):
			"BRECHE":
				if dc0 > 8.0 and dc0 < 26.0:
					Competences.utiliser_actif(self)
			"TACTIC":
				if hp < hp_max * 0.7:
					Competences.utiliser_actif(self)
	if Competences.niveau(self) >= 3 and comp["cd_ultime"] <= 0.0 and randf() < 0.2:
		match Competences.cle(self):
			"ASSAUT":
				if dc0 < 30.0:
					Competences.utiliser_ultime(self)
			"BRECHE":
				if dc0 > 10.0 and dc0 < 60.0:
					Competences.utiliser_ultime(self)
			"SNIPER":
				if hp < hp_max * 0.5:
					Competences.utiliser_ultime(self)
	var dist := Vector2(c.global_position.x - global_position.x, c.global_position.z - global_position.z).length()
	if c is Pilote and dist < 55.0 and score >= Etat.COUT_TITAN and not titan_actif() \
			and titan_cd <= 0.0 and randf() < 0.35:
		appeler_titan()
	if nb_tactique > 0 and dist > 8.0 and dist < 28.0 and randf() < 0.15:
		var d := Vector3(c.global_position.x - global_position.x, 0, c.global_position.z - global_position.z).normalized()
		lancer_tactique(oeil(), d * minf(26.0, dist * 1.6) + Vector3(0, 6, 0))


# ---------------------------------------------------------- mouvement ----
func bouger(dt: float) -> void:
	var mv := Vector3.ZERO
	var face := Vector3.ZERO
	var c = cible
	if couv_actif:
		couv_t -= dt
		if couv_t <= 0.0:
			couv_actif = false
		elif route.size() > 0:
			var wc: Vector3 = route[0]
			var dc2 := Vector3(wc.x - global_position.x, 0, wc.z - global_position.z)
			if dc2.length() < 1.2:
				route.pop_front()
			else:
				mv = dc2.normalized()
				face = mv
		else:
			c = null                                      # à l'abri : on tient la position
	if couv_actif and (route.size() > 0 or c == null):
		pass
	elif c != null and is_instance_valid(c):
		var d := Vector3(c.global_position.x - global_position.x, 0, c.global_position.z - global_position.z)
		var dist := d.length()
		if dist > 0.01:
			var dn := d / dist
			face = dn
			var pref := arme_active().pref
			var fwd := 1.0 if dist > pref * 1.25 else (-0.7 if dist < pref * 0.55 else 0.0)
			mv = dn * fwd + Vector3(dn.z, 0, -dn.x) * strafe * 0.7
	elif not couv_actif and route.size() > 0:
		var wp: Vector3 = route[0]
		var d := Vector3(wp.x - global_position.x, 0, wp.z - global_position.z)
		var dist := d.length()
		if dist < 1.3:
			route.pop_front()
			if route.is_empty():
				a_dest = false
		else:
			mv = d / dist
			face = mv
	var v := mv * 6.5 * vitesse_totale()
	velocity.x = v.x
	velocity.z = v.z
	if is_on_floor():
		velocity.y = -1.0
	else:
		velocity.y -= 22.0 * dt
	move_and_slide()
	var avance := Vector2(get_real_velocity().x, get_real_velocity().z).length() > 0.5
	marche = mv.length() > 0.0 and avance
	if mv.length() > 0.0:
		bloque = 0.0 if avance else bloque + dt
		if bloque > 0.5 and is_on_floor() and is_on_wall():
			velocity.y = 6.0                      # petit saut pour passer une marche / un gravat
		if bloque > 1.2:
			a_dest = false
			route = []
			strafe = -strafe
	if face != Vector3.ZERO:
		rotation.y = atan2(-face.x, -face.z)


# --------------------------------------------------------------- tir ----
func tirer_sur_cible(_dt: float) -> void:
	var a := arme_active()
	if arme_temp == null and not a.melee() and a.munitions <= 0 and a.reserve <= 0 and armes.size() > 1:
		idx = 1 - idx
		sur_changement_arme()
		return
	if a.munitions <= 0:
		a.recharger()
	var c = cible
	if c == null or not is_instance_valid(c) or not vu or react > 0.0:
		return
	var oe := oeil()
	var cp: Vector3 = c.global_position + Vector3(0, c.h * 0.6, 0)
	var dist := oe.distance_to(cp)
	if dist > a.portee * 0.85 or not a.pret() or (not a.melee() and a.munitions <= 0):
		return
	var err := 0.03 + dist * 0.0012
	var jit := Vector3(randf_range(-1, 1), randf_range(-0.6, 0.6), randf_range(-1, 1)) * dist * err
	var fw := Vector3(cp.x - oe.x, 0, cp.z - oe.z).normalized()
	if a.tirer(self, oe, cp - oe + jit, oe + fw * 0.6):
		dernier_tir = Etat.partie.t
		if not a.melee():
			if not Competences.silencieux(self):
				Etat.bruit(global_position)
			comp["camo_t"] = 0.0


# ------------------------------------------------------------ boucle ----
func _physics_process(dt: float) -> void:
	var P = Etat.partie
	if P == null or not P.actif or not vivant:
		return
	tick(dt)
	react -= dt
	flash -= dt
	mat_torse.emission_enabled = flash > 0.0
	mat_torse.emission = Color.WHITE
	strafe_t -= dt
	if strafe_t <= 0.0:
		strafe_t = randf_range(1.2, 2.5)
		strafe = 1.0 if randf() < 0.5 else -1.0
	regen_mun += dt
	if regen_mun > 25.0:
		regen_mun = 0.0
		for a in armes:
			a.ajouter_munitions(a.chargeur)
	pense -= dt
	if pense <= 0.0:
		pense = randf_range(0.3, 0.5)
		penser()
	if cible != null and (not is_instance_valid(cible) or not cible.vivant):
		cible = null
		vu = false
	bouger(dt)
	animer(dt)
	tirer_sur_cible(dt)


func animer(dt: float) -> void:
	var amp := 0.0
	if marche:
		phase += dt * 10.0
		amp = 38.0
	var j: Array = m["jambes"]
	j[0].rotation.x = lerpf(j[0].rotation.x, sin(phase) * deg_to_rad(amp), 12.0 * dt)
	j[1].rotation.x = lerpf(j[1].rotation.x, -sin(phase) * deg_to_rad(amp), 12.0 * dt)
	var b: Array = m["bras"]
	b[0].rotation.x = lerpf(b[0].rotation.x, sin(phase) * deg_to_rad(amp * 0.6) - deg_to_rad(30.0), 12.0 * dt)
