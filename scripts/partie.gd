class_name Partie
extends Node
## Règles du match (partie.py) : chrono 10 min, jour/nuit, points, mort définitive ou
## respawn à 50 points, fin de partie, zombies qui réapparaissent, loots.

const CIEL_JOUR := Color(0.55, 0.70, 0.90)
const CIEL_NUIT := Color(0.10, 0.12, 0.28)
const BRUME_JOUR := Color(0.64, 0.72, 0.85)
const BRUME_NUIT := Color(0.03, 0.04, 0.09)

var en_cours := false
var fini := false
var nuit := false
var pause := false
var t := 0.0
var taches: Array = []              # [[temps, Callable], ...]
var t_detect := -1.0                # -1 = aucun
var resultat := ""
var acc_loot := 0.0
var k_prev := -1.0
var k_nuit := 0.0                   # 0 = plein jour, 1 = pleine nuit (lu par le HUD)

var actif: bool:
	get:
		return en_cours and not fini and not pause


# ---- planification -------------------------------------------------------------------
func plus_tard(delai: float, fn: Callable) -> void:
	taches.append([t + delai, fn])


# ---- menu / démarrage ------------------------------------------------------------------
func ouvrir_menu() -> void:
	if Etat.modes != null:
		Etat.modes.arreter()
	en_cours = false
	fini = false
	pause = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Etat.banniere.emit("", 0.0)
	Etat.menu_demande.emit()


func demarrer(classe: Dictionary) -> void:
	for z in Etat.zombies:
		if is_instance_valid(z):
			z.queue_free()
	Etat.zombies.clear()
	taches = []
	t = 0.0
	t_detect = -1.0
	nuit = false
	fini = false
	pause = false
	resultat = ""
	k_prev = -1.0
	en_cours = true
	var pts := Etat.spawns.duplicate()
	pts.shuffle()
	for i in Etat.pilotes.size():
		var p: Pilote = Etat.pilotes[i]
		p.en_match = not (Etat.mode_jeu == "parcours" and p != Etat.joueur)
		if p.en_match:
			p.nouvelle_partie(classe if p == Etat.joueur else ClassesDB.aleatoire(), pts[i % pts.size()])
		else:                                          # pilote désactivé (Parcours : solo)
			p.vivant = false
			p.elimine = true
			p.visible = false
			p.collision_layer = 0
	reset_loots()
	for i in Etat.NB_ZOMBIES:
		spawn_zombie()
	if Etat.modes != null:
		Etat.modes.demarrer(Etat.mode_jeu)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Etat.partie_demarree.emit()
	match Etat.mode_jeu:
		"parcours":
			Etat.banniere.emit("PARCOURS", 3.0)
			Etat.msg("Atteins les checkpoints à temps (+20 s chacun) — couteau seulement !")
		"controle":
			Etat.banniere.emit("POINT DE CONTRÔLE", 3.0)
			Etat.msg("Reste 30 s seul dans la zone : +10 points. Zombie tué : +1")
		_:
			Etat.banniere.emit("SURVIS 10 MINUTES", 3.0)
			Etat.msg("Tue des zombies (+1), vole les points des pilotes")


# ---- zombies -----------------------------------------------------------------------------
func _kind_zombie() -> String:
	if Etat.mode_jeu == "parcours":                   # zombies rapides dès le début
		return "rapace" if randf() < 0.3 else "nuit_normal"
	# proportions du cahier des charges : jour 8 spéciaux / 48, nuit 30 rapaces / 75
	var special := randf() < (30.0 / 75.0 if nuit else 8.0 / 48.0)
	if nuit:
		return "rapace" if special else "nuit_normal"
	return "jour_special" if special else "jour_normal"


## Les zombies apparaissent à 35-110 m d'un pilote (la carte est grande).
func spawn_zombie(kind := "") -> void:
	var vivants: Array = Etat.pilotes.filter(func(p): return p.vivant)
	var pos := Vector3.ZERO
	var trouve := false
	for i in 40:
		var x: float
		var z: float
		if vivants.size() > 0:
			var c = vivants[randi() % vivants.size()]
			var a := randf_range(0.0, TAU)
			var d := randf_range(35.0, 110.0)
			x = c.global_position.x + sin(a) * d
			z = c.global_position.z + cos(a) * d
		else:
			x = randf_range(-150.0, 150.0)
			z = randf_range(-150.0, 150.0)
		if Etat.est_libre(x, z, 0.6):
			var loin := true
			for p in vivants:
				if Vector2(x - p.global_position.x, z - p.global_position.z).length() < 30.0:
					loin = false
					break
			if loin:
				pos = Vector3(x, 0, z)
				trouve = true
				break
	if not trouve:
		pos = Etat.point_libre(0.6, vivants, 30.0)
	var zb := Zombie.creer(kind if kind != "" else _kind_zombie(), pos)
	if Etat.mode_jeu == "parcours":
		zb.forcer_detection = 900.0                    # ils foncent tous sur le joueur
	Etat.racine_zombies.add_child(zb)


func mort_zombie(z, source = null) -> void:
	var k = Etat.proprietaire(source)
	if k is Pilote:
		k.score += 1
		k.kills += 1
		Competences.sur_kill(k)
	if actif:
		if z.kind != "geant":
			plus_tard(Etat.DELAI_RESPAWN_ZOMBIE, spawn_zombie)
		if randf() < 0.12:
			var l := Loot.creer(Vector3(z.global_position.x, 0, z.global_position.z), "", true)
			Etat.racine_loots.add_child(l)


# ---- pilotes ----------------------------------------------------------------------------------
func mort_pilote(v, source = null) -> void:
	if not v.vivant or v.elimine:
		return
	var k = Etat.proprietaire(source)
	if not (k is Pilote) or k == v:
		k = null
	v.score_final = v.score
	v.mourir()
	var types := ["soin", "munitions", "arme"]
	Etat.racine_loots.add_child(Loot.creer(Vector3(v.global_position.x, 0, v.global_position.z),
			types[randi() % types.size()], true))
	var qui: String = k.nom if k != null else "les zombies"
	if Etat.mode_jeu == "controle":
		# pas d'élimination : respawn gratuit, les points ne sont pas volés
		v.attente = true
		Etat.msg("%s tué par %s" % [v.nom, qui])
		plus_tard(5.0, reapparaitre.bind(v))
	elif Etat.mode_jeu == "classique" and v.score >= Etat.COUT_RESPAWN:
		# 50 points payés : pas de mort définitive. Le tueur prend le reste.
		v.score -= Etat.COUT_RESPAWN
		if k != null:
			k.score += v.score
			k.kills += 1
			Competences.sur_kill(k)
		v.score = 0
		v.attente = true
		Etat.msg("%s tué par %s (-%d pts, respawn)" % [v.nom, qui, Etat.COUT_RESPAWN])
		plus_tard(3.0, reapparaitre.bind(v))
	else:
		v.elimine = true
		v.t_elim = t
		if k != null:
			k.score += v.score
			k.kills += 1
		v.score = 0
		Etat.msg("%s ÉLIMINÉ par %s" % [v.nom, qui])
		if v.titan_actif():
			v.titan.detruire(false)
		if v == Etat.joueur:
			Etat.banniere.emit("ÉLIMINÉ", 4.0)


func reapparaitre(v) -> void:
	if not actif or v.elimine:
		return
	v.reapparaitre(Etat.spawn_loin())


# ---- fin de partie --------------------------------------------------------------------------------
func verifier_fin() -> void:
	if Etat.modes != null and Etat.mode_jeu != "classique" and Etat.modes.verifier_fin():
		return
	var actifs: Array = Etat.pilotes.filter(func(p): return p.en_match)
	if actifs.size() == 1:                          # un seul pilote en jeu : on survit ou on est éliminé
		var p = actifs[0]
		if p.elimine:
			finir(null, "Éliminé")
		elif t >= Etat.DUREE_PARTIE:
			finir(p, "Survécu 10 minutes")
		return
	var restants: Array = actifs.filter(func(p): return not p.elimine)
	if restants.size() <= 1:
		if t_detect < 0.0:
			t_detect = t
		elif t - t_detect >= 0.5:
			if restants.size() == 1:
				finir(restants[0], "Dernier survivant")
			else:
				# les deux derniers sont morts en même temps : le plus de points gagne
				var cands: Array = Etat.pilotes.filter(func(p): return p.t_elim >= t_detect - 0.1)
				if cands.is_empty():
					cands = Etat.pilotes
				cands.sort_custom(func(a, b): return a.score_final > b.score_final)
				finir(cands[0], "Mort simultanée : plus de points")
	elif t >= Etat.DUREE_PARTIE:
		var best = restants[0]
		for p in restants:
			if p.score > best.score:
				best = p
		finir(best, "Temps écoulé : plus de points")


func finir(gagnant, raison: String) -> void:
	fini = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if gagnant == null:
		resultat = "DÉFAITE  (%s)" % raison
	elif gagnant == Etat.joueur:
		resultat = "VICTOIRE !  (%s)" % raison
	else:
		resultat = "%s GAGNE  (%s)" % [gagnant.nom, raison]
	Etat.banniere.emit("FIN DE PARTIE", 5.0)


# ---- loots ---------------------------------------------------------------------------------------------
func reset_loots() -> void:
	for l in Etat.loots.duplicate():
		if is_instance_valid(l):
			if l.temporaire:
				l.retirer()
			else:
				l.reapparaitre()
				if Etat.mode_jeu == "parcours" and l.type == "arme":
					l.actif = false                   # Parcours : « 0 armes, que le couteau »
					l.visible = false


## Appelé ~10 fois/s : ramassage par les pilotes + durée de vie des loots temporaires.
func ramassage(dt: float) -> void:
	for l in Etat.loots.duplicate():
		if not is_instance_valid(l) or not l.actif:
			continue
		if l.temporaire:
			l.vie -= dt
			if l.vie <= 0.0:
				l.retirer()
				continue
		for p in Etat.pilotes:
			if p.vivant and not p.elimine:
				var dy: float = p.global_position.y - l.global_position.y
				if absf(p.global_position.x - l.global_position.x) < 1.6 \
						and absf(p.global_position.z - l.global_position.z) < 1.6 and dy > -1.0 and dy < 2.4:
					if p.ramasser(l.type):
						l.prendre()
						break


# ---- entrées -----------------------------------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("recharge") and en_cours and (fini or Etat.joueur.elimine):
		ouvrir_menu()


# ---- boucle ----------------------------------------------------------------------------------------------------
func _physics_process(dt: float) -> void:
	if not en_cours or pause:
		return
	if not fini:
		t += dt
		acc_loot += dt
		if acc_loot >= 0.1:
			ramassage(acc_loot)
			acc_loot = 0.0
		for tache in taches.filter(func(x): return x[0] <= t):
			taches.erase(tache)
			tache[1].call()
		if not nuit and t >= Etat.DUREE_JOUR and Etat.mode_jeu != "parcours":
			nuit = true
			for z in Etat.zombies:
				if is_instance_valid(z):
					z.passer_nuit()
			for i in 5:
				spawn_zombie("geant")
			Etat.banniere.emit("LA NUIT TOMBE", 4.0)
			Etat.msg("Les zombies sont plus forts... et des géants rôdent !")
		verifier_fin()
	# ciel / lumières / brume : transition de 20 s après 5 min
	var k := clampf((t - Etat.DUREE_JOUR) / 20.0, 0.0, 1.0)
	if absf(k - k_prev) > 0.002:
		k_prev = k
		k_nuit = k
		if Etat.env != null:
			Etat.env.background_color = CIEL_JOUR.lerp(CIEL_NUIT, k)
			Etat.env.fog_light_color = BRUME_JOUR.lerp(BRUME_NUIT, k)
			Etat.env.ambient_light_energy = lerpf(1.0, 0.35, k)
		if Etat.soleil != null:
			Etat.soleil.light_energy = lerpf(1.1, 0.12, k)
		for li in Etat.lumieres_int:
			if is_instance_valid(li):
				li.light_energy = 0.55 + k * 0.9
		for l in Etat.lampes:
			if is_instance_valid(l):
				l.light_energy = k * 1.6
		if Etat.lampes_mat != null:
			Etat.lampes_mat.emission_energy_multiplier = k * 3.0
