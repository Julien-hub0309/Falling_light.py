class_name Joueur
extends Pilote
## Le joueur FPS (bot/joueur.py + base Pilote de bot/pilote.py) :
## mouvement Titanfall (double saut, wall-run, glisse, grappin) + grimper façon Dying Light.
## L'origine du nœud = les PIEDS du joueur (comme en Python).

const GRAVITE := 22.0
const SENSIBILITE := 0.0022          # radians par pixel
const FOV_VITESSE := 0.8

# (état de pilote : voir pilote.gd)

# ---- mouvement ----
var vel := Vector3.ZERO              # vitesse horizontale (x, z)
var vy := 0.0
var grounded := true
var jumps := 1
var wall_t := 0.0
var wall_n := Vector3.ZERO
var a_mur := false
var wallrunning := false
var slide_t := 0.0
var slide_dir := Vector3.FORWARD
var slide_v0 := 10.0
var slide_dur := 1.0
var grimpe: Array = []               # [départ, arrivée, progression] ; vide = pas en train de grimper
var grappin_actif := false
var grappin_pos := Vector3.ZERO
var grappin_dest := Vector3.ZERO
var grappin_kick := Vector3.ZERO
var grappin_phase2 := 0.0           # franchissement du rebord après le grappin
var grappin_dir2 := Vector3.ZERO
var grappin_t := 0.0
var grappin_cd := 0.0

# ---- vue / arme ----
var zoom := false
var lunette := false
var bob := 0.0
var flash_t := 0.0
var shake := 0.0
var pivot: Node3D
var camera: Camera3D
var gun: Node3D
var vms := {}
var vm: Node3D = null
var corde: MeshInstance3D


func _ready() -> void:
	nom = "Toi"
	super._ready()
	pivot = Node3D.new()
	pivot.position.y = 1.65
	add_child(pivot)
	camera = Camera3D.new()
	camera.fov = Etat.fov
	camera.keep_aspect = Camera3D.KEEP_WIDTH      # FOV horizontal comme Ursina
	camera.near = 0.05
	camera.far = 600.0
	pivot.add_child(camera)
	gun = Node3D.new()
	camera.add_child(gun)
	corde = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.03, 0.03, 1.0)
	corde.mesh = bm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.8, 0.8, 0.8)
	corde.material_override = m
	corde.top_level = true
	corde.visible = false
	add_child(corde)
	camera.make_current()


# =============================== hooks de Pilote ===============================
func set_gun() -> void:
	var a := arme_active()
	if a == null or gun == null:
		return
	if vm != null:
		vm.visible = false
	var cle := a.modele + ("_T" if a.titan else "")
	if not vms.has(cle):
		vms[cle] = ArmesModeles.construire(a.modele, gun, a.titan)
	vm = vms[cle]
	vm.visible = true
	gun.position = a.vue_pos


func sur_changement_arme() -> void:
	zoom = false
	set_gun()


func sur_degats(_source) -> void:
	Etat.degats_recus.emit()


func avant_mort() -> void:
	pivot.position.y = 0.4
	gun.visible = false
	zoom = false
	fin_grappin(false)


func apres_respawn() -> void:
	mode = "pilot"
	vel = Vector3.ZERO
	vy = 0.0
	grounded = true
	jumps = 1
	wall_t = 0.0
	a_mur = false
	wallrunning = false
	slide_t = 0.0
	grimpe = []
	pivot.rotation.x = 0.0
	pivot.position.y = 1.65
	gun.visible = true
	fin_grappin(false)
	set_gun()
	camera.make_current()


# =============================== entrées ===============================
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		regarder(event.relative)
		return
	var P = Etat.partie
	if P == null or not P.actif or not vivant or elimine:
		return
	var titan_a_bord := mode == "titan"
	if event.is_action_pressed("saut"):
		if slide_t > 0.0:
			slide_t = 0.0
		if grappin_actif:
			fin_grappin(false)
		if grounded:
			if titan_a_bord or not tente_grimper():
				vy = 7.0 if titan_a_bord else 9.0
				grounded = false
		elif wallrunning:
			vy = 9.0
			if a_mur:
				vel += wall_n * 9.0
				vel += -global_transform.basis.z * 3.0
				a_mur = false
				wallrunning = false
		elif not titan_a_bord and not tente_grimper() and jumps > 0:
			vy = 8.0
			jumps -= 1
	elif event.is_action_pressed("recharge") and not titan_a_bord:
		arme_active().recharger()
	elif event.is_action_pressed("arme1") and not titan_a_bord:
		choisir_arme(0)
	elif event.is_action_pressed("arme2") and not titan_a_bord:
		choisir_arme(1)
	elif (event.is_action_pressed("arme_suiv") or event.is_action_pressed("arme_prec")) and not titan_a_bord:
		choisir_arme(1 - idx)
	elif event.is_action_pressed("competence"):
		Competences.utiliser_actif(self)
	elif event.is_action_pressed("ultime"):
		Competences.utiliser_ultime(self)
	elif event.is_action_pressed("titan_ordre") and not titan_a_bord:
		ordre_titan_suivant()
	elif event.is_action_pressed("titan_aller") and not titan_a_bord:
		var res := Etat.raycast(self, camera.global_position, -camera.global_transform.basis.z, 150.0, Etat.COUCHE_MONDE)
		if res.is_empty():
			Etat.msg("Titan : vise le sol")
		else:
			ordre_titan_aller(res.position)
	elif event.is_action_pressed("melee") and titan_a_bord:
		coup_epee()
	elif event.is_action_pressed("kit_soin"):
		Craft.utiliser_soin(self)
	elif event.is_action_pressed("kit_armure"):
		Craft.utiliser_armure(self)
	elif event.is_action_pressed("titan") and not titan_a_bord:
		appeler_titan()
	elif event.is_action_pressed("interagir"):
		if titan_a_bord:
			ejecter()
		elif titan_actif() and titan.state == "ready" and global_position.distance_to(titan.global_position) < 8.0:
			embarquer()
	elif event.is_action_pressed("tactique") and not titan_a_bord:
		lancer_tactique(camera.global_position - camera.global_transform.basis.z * 0.6,
				-camera.global_transform.basis.z * 18.0 + Vector3(0, 3, 0))
	elif event.is_action_pressed("grappin") and not titan_a_bord:
		lancer_grappin()
	elif event.is_action_pressed("glisse") and grounded and slide_t <= 0.0 and not titan_a_bord:
		var v := Vector3(vel.x, 0, vel.z)
		if v.length() > 6.0:
			slide_dur = 1.0
			slide_t = slide_dur
			slide_v0 = clampf(maxf(v.length(), 10.0), 10.0, 18.0)   # on glisse avec l'élan de la course
			slide_dir = v.normalized()
	elif event.is_action_pressed("tir") and not arme_active().auto:
		tirer()


# =============================== Titan ===============================
func coup_epee() -> void:
	if cd_epee > 0.0:
		return
	cd_epee = 0.8
	Titan.frappe(self, camera.global_position, -camera.global_transform.basis.z, null)



func embarquer() -> void:
	var t: Titan = titan
	mode = "titan"
	titan_hp = t.hp
	vy = 0.0
	arme_titan = Arme.pour_titan(armes[0])
	global_position = Vector3(t.global_position.x, 0.05, t.global_position.z)
	t.embarquer()
	zoom = false
	set_taille(1.2, 5.6)
	set_gun()
	Etat.msg("Titan : [E] pour éjecter")


func ejecter(force := false) -> void:
	var t: Titan = titan
	var pos := global_position
	mode = "pilot"
	vy = 16.0
	grounded = false
	jumps = 1
	set_taille(0.4, 1.8)
	if t != null and is_instance_valid(t) and t.vivant:
		if force:
			t.global_position = Vector3(pos.x, 0.05, pos.z)
			t.detruire(true)
		else:
			var fw := -global_transform.basis.z
			fw.y = 0.0
			var p := pos + fw.normalized() * 4.0
			if not Etat.est_libre(p.x, p.z, 1.6):
				p = pos
			t.debarquer(p, titan_hp)
	arme_titan = null
	set_gun()


func regarder(rel: Vector2) -> void:
	var a := arme_active()
	var ratio := 1.0
	if zoom and a != null and a.zoom > 0.0:
		ratio = clampf(a.zoom / Etat.fov, 0.25, 1.0)
	var sens := SENSIBILITE * (Etat.sensibilite / 40.0) * ratio
	var inv := -1.0 if Etat.inverser_y else 1.0
	rotate_y(-rel.x * sens)
	pivot.rotation.x = clampf(pivot.rotation.x - rel.y * sens * inv, deg_to_rad(-89.0), deg_to_rad(89.0))


# =============================== grimper (Dying Light) ===============================
func tente_grimper() -> bool:
	if grimpe.size() > 0 or not vivant:
		return false
	var fw := -global_transform.basis.z
	fw.y = 0.0
	if fw.length() < 0.1:
		return false
	fw = fw.normalized()
	var p := global_position
	# un mur est bien devant nous (à hauteur de poitrine)
	if Etat.raycast(self, p + Vector3(0, 1.0, 0), fw, r + 0.6, Etat.COUCHE_MONDE).is_empty():
		return false
	# surface d'arrivée : rayon vertical vers le bas, juste derrière le bord
	var tx := p.x + fw.x * (r + 0.85)
	var tz := p.z + fw.z * (r + 0.85)
	var haut := Vector3(tx, p.y + 2.7, tz)
	var res := Etat.raycast(self, haut, Vector3.DOWN, 2.5, Etat.COUCHE_MONDE)
	if res.is_empty() or res.normal.y < 0.7:
		return false
	var top: float = res.position.y
	if top < p.y + 0.5 or top > p.y + 2.7:
		return false
	# la place pour se tenir debout
	if not Etat.raycast(self, Vector3(tx, top + 0.05, tz), Vector3.UP, h, Etat.COUCHE_MONDE).is_empty():
		return false
	grimpe = [p, Vector3(tx, top + 0.02, tz), 0.0]
	slide_t = 0.0
	return true


func animer_grimpe(dt: float, wish: Vector3) -> void:
	grimpe[2] += dt / 0.42
	var p := minf(1.0, grimpe[2])
	var up := minf(1.0, p / 0.6)
	var fw := maxf(0.0, (p - 0.4) / 0.6)
	var s0: Vector3 = grimpe[0]
	var e0: Vector3 = grimpe[1]
	global_position = Vector3(lerpf(s0.x, e0.x, fw), lerpf(s0.y, e0.y, up), lerpf(s0.z, e0.z, fw))
	vel = Vector3.ZERO
	vy = 0.0
	velocity = Vector3.ZERO
	if p >= 1.0:
		grimpe = []
		grounded = true
		jumps = 1
		wall_t = 0.0
		vel = Vector3(wish.x * 3.0, 0, wish.z * 3.0)


# =============================== grappin ===============================
func lancer_grappin() -> void:
	if grappin_actif or grappin_phase2 > 0.0 or not vivant or mode == "titan" or grimpe.size() > 0:
		return
	if grappin_cd > 0.0:
		Etat.msg("Grappin : recharge %.1f s" % grappin_cd)
		return
	var o := camera.global_position
	var d := -camera.global_transform.basis.z
	var res := Etat.raycast(self, o, d, Competences.portee_grappin(self), Etat.COUCHE_MONDE)
	if res.is_empty():
		Etat.msg("Grappin : aucune prise à portée")
		return
	var pt: Vector3 = res.position
	var n: Vector3 = res.normal
	var dest := pt
	grappin_kick = Vector3.ZERO
	if n.y < 0.6:
		# C'est un MUR : on cherche le bord du toit juste au-dessus du point visé et on s'y fait
		# tirer (point d'arrivée au-dessus du bord, côté extérieur), puis une poussée vers
		# l'intérieur nous dépose sur le toit : on peut enchaîner d'un bâtiment à l'autre.
		var out := Vector3(n.x, 0, n.z).normalized()
		var dedans := pt - out * 0.8
		var r2 := Etat.raycast(self, Vector3(dedans.x, pt.y + 14.0, dedans.z), Vector3.DOWN, 14.6, Etat.COUCHE_MONDE)
		if not r2.is_empty() and r2.normal.y > 0.7 and r2.position.y > pt.y - 0.3 and r2.position.y - pt.y < 13.5:
			dest = Vector3(pt.x + out.x * 0.7, r2.position.y + 1.3, pt.z + out.z * 0.7)
			grappin_kick = -out * 8.0
		else:
			dest = pt + n * 1.0                          # mur trop haut : on s'y accroche (puis Espace = grimper)
	else:
		dest = pt + n * 0.5
	grappin_actif = true
	grappin_pos = pt
	grappin_dest = dest
	grappin_t = o.distance_to(dest) / 30.0 + 0.8
	slide_t = 0.0
	wallrunning = false
	corde.visible = true


func fin_grappin(boost: bool) -> void:
	grappin_actif = false
	if corde != null:
		corde.visible = false
	if boost:
		grappin_cd = Competences.cd_grappin(self)
		vy = maxf(vy, 6.0)


func tirer_grappin(dt: float) -> void:
	var d := grappin_dest - (global_position + Vector3(0, 1, 0))
	var l := d.length()
	grappin_t -= dt
	if l < 2.2 or grappin_t <= 0.0:
		if grappin_kick != Vector3.ZERO:                  # arrivée au bord : on franchit le rebord
			grappin_dir2 = grappin_kick.normalized()
			grappin_phase2 = 0.32
			grappin_kick = Vector3.ZERO
			fin_grappin(false)
			grappin_cd = Competences.cd_grappin(self)
		else:
			fin_grappin(true)
		return
	var dn := d / l
	vel.x = dn.x * 30.0
	vel.z = dn.z * 30.0
	vy = dn.y * 30.0
	var b := camera.global_transform.basis
	var o := camera.global_position + b.x * 0.3 - b.y * 0.3
	corde.global_position = (o + grappin_pos) * 0.5
	corde.scale = Vector3(1, 1, maxf(o.distance_to(grappin_pos), 0.1))
	corde.look_at(grappin_pos, Vector3.UP)


# =============================== tir ===============================
func tirer() -> void:
	var a := arme_active()
	var b := camera.global_transform.basis
	var o := camera.global_position
	var d := -b.z
	var debut := o + b.x * 0.3 - b.y * 0.2 + d * 0.5
	if a.tirer(self, o, d, debut, zoom):
		var rec := a.recul * Competences.facteur_recul(self)
		gun.position.z += rec
		pivot.rotation.x = minf(pivot.rotation.x + deg_to_rad(rec * 6.0), deg_to_rad(89.0))
		dernier_tir = Etat.partie.t
		if vm != null and vm.has_meta("flash") and not a.melee():
			vm.get_meta("flash").visible = true
			flash_t = 0.045
		shake += a.recul * 2.5
		if not a.melee():
			if not Competences.silencieux(self):
				Etat.bruit(global_position)
			comp["camo_t"] = 0.0                  # tirer met fin au camouflage
			if mode == "pilot" and a.munitions == 0:
				a.recharger()


# =============================== boucle principale ===============================
func _physics_process(dt: float) -> void:
	var P = Etat.partie
	if P == null or not P.en_cours or P.pause:
		return
	if elimine:
		vol_spectateur(dt)
		return
	if not vivant or P.fini:
		return
	tick(dt)
	grappin_cd -= dt
	var a := arme_active()
	pivot.position.y = lerpf(pivot.position.y, 5.2 if mode == "titan" else (0.9 if slide_t > 0.0 else 1.65), 8.0 * dt)

	var f := Input.get_axis("arriere", "avant")
	var s := Input.get_axis("gauche", "droite")
	var wish := global_transform.basis * Vector3(s, 0, -f)
	wish.y = 0.0
	if wish.length() > 0.0:
		wish = wish.normalized()

	if grimpe.size() > 0:
		animer_grimpe(dt, wish)
	else:
		mouvement(dt, f, wish)

	# --- caméra : roulis en wall-run, FOV selon la vitesse, zoom
	var tilt := 0.0
	if wallrunning and a_mur:
		tilt = deg_to_rad(-9.0 * wall_n.dot(global_transform.basis.x))
	camera.rotation.z = lerpf(camera.rotation.z, tilt, 8.0 * dt)
	zoom = a.zoom > 0.0 and Input.is_action_pressed("viser") and grimpe.is_empty()
	lunette = zoom and a.zoom < 30.0           # lunette de sniper : arme masquée + overlay
	gun.visible = not lunette
	if zoom:
		camera.fov = lerpf(camera.fov, a.zoom, 10.0 * dt)
	else:
		var vit := Vector2(vel.x, vel.z).length()
		camera.fov = lerpf(camera.fov, Etat.fov + vit * FOV_VITESSE, 4.0 * dt)

	# --- arme : visée (au centre), retour du recul, balancement de marche
	var vit2 := Vector2(vel.x, vel.z).length()
	if grounded and vit2 > 1.0:
		bob += dt * (6.0 + vit2 * 0.5)
	var amp := 0.0 if zoom else minf(1.0, vit2 / 8.0)
	var cible: Vector3 = ArmesModeles.ads(a.modele, a.titan) if zoom else a.vue_pos
	var k := minf(1.0, 16.0 * dt)
	gun.position.x = lerpf(gun.position.x, cible.x + sin(bob) * 0.012 * amp, k)
	gun.position.y = lerpf(gun.position.y, cible.y + absf(cos(bob)) * 0.012 * amp, k)
	gun.position.z = lerpf(gun.position.z, cible.z, 15.0 * dt)
	if flash_t > 0.0:
		flash_t -= dt
		if flash_t <= 0.0 and vm != null and vm.has_meta("flash"):
			vm.get_meta("flash").visible = false
	shake *= maxf(0.0, 1.0 - 9.0 * dt)
	camera.position = Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * shake * 0.12

	if Input.is_action_pressed("tir") and a.auto and a.pret():
		tirer()


func mouvement(dt: float, f: float, wish: Vector3) -> void:
	if grappin_phase2 > 0.0:
		# phase 2 du grappin : glissade horizontale par-dessus le rebord (sans gravité) puis on retombe SUR le toit
		grappin_phase2 -= dt
		vel.x = grappin_dir2.x * 9.0
		vel.z = grappin_dir2.z * 9.0
		vy = 0.0
		velocity = Vector3(vel.x, 0.0, vel.z)
		move_and_slide()
		vel.x = velocity.x
		vel.z = velocity.z
		grounded = is_on_floor()
		if grounded:
			grappin_phase2 = 0.0
		return
	var sprint := Input.is_action_pressed("sprint")
	var titan_a_bord := mode == "titan"
	var speed := (10.0 if sprint else 6.0) if titan_a_bord else (12.0 if sprint else 8.0) * vitesse_totale()
	if wallrunning:
		speed *= 1.25
	if zoom:
		speed *= 0.7
	var taux := 14.0 if grounded else (8.0 if wallrunning else 3.5)
	var vh := Vector2(vel.x, vel.z).length()
	if grounded and slide_t <= 0.0 and vh > speed * 1.08:
		# CONSERVATION DE LA VITESSE : l'élan (course, glissade, saut, wall-run) ne retombe que doucement
		taux = 2.4 if wish.length() > 0.1 else 5.0
	var k := minf(1.0, taux * dt)
	vel.x = lerpf(vel.x, wish.x * speed, k)
	vel.z = lerpf(vel.z, wish.z * speed, k)
	if vh > 20.0:
		vel.x *= 20.0 / vh
		vel.z *= 20.0 / vh

	if grappin_actif:
		tirer_grappin(dt)
	if slide_t > 0.0:
		slide_t -= dt
		var v := 6.0 + (slide_v0 - 6.0) * maxf(0.0, slide_t) / slide_dur
		vel.x = slide_dir.x * v
		vel.z = slide_dir.z * v
		if not grounded:
			slide_t = 0.0

	# grimper automatiquement en gardant Espace contre un mur
	if a_mur and not grounded and Input.is_action_pressed("saut") and f > 0.0 and not titan_a_bord:
		if tente_grimper():
			return

	# wall-run : on reste collé au mur touché à la frame précédente
	var stick := a_mur and not grounded and f > 0.0 and wall_t < 3.0 and not grappin_actif and not titan_a_bord
	wallrunning = stick
	if stick:
		wall_t += dt
		vy = maxf(vy - 6.0 * dt, -1.5)
		vel -= Vector3(wall_n.x, 0, wall_n.z) * 4.0
		jumps = 1
	elif not grappin_actif:
		vy -= GRAVITE * dt

	a_mur = false
	velocity = Vector3(vel.x, vy, vel.z)
	move_and_slide()

	vel.x = velocity.x
	vel.z = velocity.z
	grounded = is_on_floor()
	if grounded:
		vy = 0.0
		jumps = 1
		wall_t = 0.0
	else:
		vy = velocity.y
		if is_on_ceiling() and vy > 0.0:
			vy = 0.0
	if is_on_wall() and not grounded:
		wall_n = get_wall_normal()
		a_mur = true
	var lim := Etat.DEMI_MAP - 2.0
	global_position.x = clampf(global_position.x, -lim, lim)
	global_position.z = clampf(global_position.z, -lim, lim)


## Éliminé : caméra libre pour regarder la fin du match.
func vol_spectateur(dt: float) -> void:
	var f := Input.get_axis("arriere", "avant")
	var s := Input.get_axis("gauche", "droite")
	var b := camera.global_transform.basis
	var d := -b.z * f + b.x * s
	global_position += d * (25.0 if Input.is_action_pressed("sprint") else 14.0) * dt
	global_position.y = maxf(global_position.y, 0.5)
	pivot.position.y = 1.65
