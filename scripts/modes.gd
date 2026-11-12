class_name Modes
extends Node
## Modes de jeu (README « Mode de jeu ») :
##  - classique : les règles du cahier des charges (10 min, 5 pilotes, points).
##  - parcours  : couteau seul, 8 checkpoints à atteindre dans un temps imparti pendant que les
##                zombies te foncent dessus. +20 s par checkpoint. Solo, sans bots.
##  - controle  : reste 30 s seul dans la zone pour 10 points (+1 point par zombie tué).
##                Pas d'élimination (respawn gratuit), le plus de points à 10 min gagne.

const PARCOURS_NB := 8
const PARCOURS_TEMPS := 180.0
const PARCOURS_BONUS := 20.0
const RAYON_CP := 3.5
const ZONE_RAYON := 9.0
const ZONE_DUREE := 30.0
const ZONE_POINTS := 10

var mode := "classique"
var points: Array[Vector3] = []
var idx := 0
var restant := 0.0
var t_parcours := 0.0
var zone := Vector3.ZERO
var zone_active := false
var progres := {}                    # Pilote -> secondes passées seul dans la zone
var disputee := false
var visuels: Array = []
var anneau_mat: StandardMaterial3D


func temps_restant() -> float:
	if mode == "parcours":
		return maxf(0.0, restant)
	return maxf(0.0, Etat.DUREE_PARTIE - Etat.partie.t)


# ---------------------------------------------------------------- démarrage ----
func demarrer(m: String) -> void:
	arreter()
	mode = m
	idx = 0
	t_parcours = 0.0
	progres = {}
	zone_active = false
	if mode == "parcours":
		restant = PARCOURS_TEMPS
		_choisir_checkpoints()
		_maj_balises()
	elif mode == "controle":
		_nouvelle_zone(true)


func arreter() -> void:
	for v in visuels:
		if is_instance_valid(v):
			v.queue_free()
	visuels = []
	points = []
	zone_active = false
	mode = "classique"


func _libre(p: Vector3) -> bool:
	return Nav.joignable(p)


func _choisir_checkpoints() -> void:
	var depart: Vector3 = Etat.joueur.global_position
	var cands: Array[Vector3] = []
	var toits: Array = Etat.toits.duplicate()
	toits.shuffle()
	for t in toits:
		if cands.size() >= 3:
			break
		if _libre(t) and _assez_loin(t, cands, depart, 55.0):
			cands.append(t)
	var sols: Array = Etat.spawns.duplicate()
	sols.shuffle()
	for s in sols:
		if cands.size() >= PARCOURS_NB:
			break
		if _assez_loin(s, cands, depart, 55.0):
			cands.append(s)
	# ordre = plus proche voisin depuis le départ
	var pos := depart
	points = []
	while not cands.is_empty():
		var best := 0
		var bd := 1e9
		for i in cands.size():
			var d := Vector2(cands[i].x - pos.x, cands[i].z - pos.z).length()
			if d < bd:
				bd = d
				best = i
		pos = cands[best]
		points.append(pos)
		cands.remove_at(best)


func _assez_loin(p: Vector3, liste: Array, depart: Vector3, dmin: float) -> bool:
	if Vector2(p.x - depart.x, p.z - depart.z).length() < dmin:
		return false
	for q in liste:
		if Vector2(p.x - q.x, p.z - q.z).length() < dmin:
			return false
	return true


func _nouvelle_zone(premiere := false) -> void:
	var cands: Array = Etat.spawns.duplicate()
	cands.append_array(Etat.toits)
	cands.shuffle()
	var choix: Vector3 = cands[0]
	for c in cands:
		if _libre(c) and (premiere or Vector2(c.x - zone.x, c.z - zone.z).length() > 80.0):
			choix = c
			break
	zone = choix
	zone_active = true
	progres = {}
	_maj_balises()
	if not premiere:
		Etat.banniere.emit("NOUVELLE ZONE", 2.5)


# ------------------------------------------------------------------ visuels ----
func _maj_balises() -> void:
	for v in visuels:
		if is_instance_valid(v):
			v.queue_free()
	visuels = []
	if mode == "parcours":
		if idx < points.size():
			visuels.append(_balise(points[idx], Color(0.2, 0.9, 1.0, 0.55), RAYON_CP))
		if idx + 1 < points.size():
			visuels.append(_balise(points[idx + 1], Color(1, 1, 1, 0.18), RAYON_CP))
	elif mode == "controle" and zone_active:
		var b := _balise(zone, Color(1, 0.85, 0.1, 0.45), ZONE_RAYON)
		visuels.append(b)
		anneau_mat = b.get_meta("mat")


func _balise(pos: Vector3, col: Color, rayon: float) -> Node3D:
	var n := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = col
	var faisceau := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.5
	cm.bottom_radius = 0.5
	cm.height = 70.0
	faisceau.mesh = cm
	faisceau.material_override = mat
	faisceau.position.y = 35.0
	faisceau.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(faisceau)
	var anneau := MeshInstance3D.new()
	var am := CylinderMesh.new()
	am.top_radius = rayon
	am.bottom_radius = rayon
	am.height = 0.25
	anneau.mesh = am
	anneau.material_override = mat
	anneau.position.y = 0.15
	anneau.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(anneau)
	n.set_meta("mat", mat)
	Etat.get_tree().current_scene.add_child(n)
	n.global_position = pos
	return n


## [position, couleur, rayon] à dessiner sur la minimap.
func marqueurs() -> Array:
	var res: Array = []
	if mode == "parcours":
		if idx < points.size():
			res.append([points[idx], Color(0.2, 0.9, 1.0), RAYON_CP * 2.0])
		if idx + 1 < points.size():
			res.append([points[idx + 1], Color(1, 1, 1), RAYON_CP * 1.5])
	elif mode == "controle" and zone_active:
		res.append([zone, Color(1, 0.85, 0.1), ZONE_RAYON])
	return res


func texte_hud() -> String:
	var j = Etat.joueur
	if mode == "parcours" and idx < points.size():
		var p := points[idx]
		return "CHECKPOINT %d / %d   —   %d m%s" % [idx + 1, points.size(),
				int(Vector2(p.x - j.global_position.x, p.z - j.global_position.z).length()),
				"   (sur un toit)" if p.y > 3.0 else ""]
	if mode == "controle" and zone_active:
		var d := Vector2(zone.x - j.global_position.x, zone.z - j.global_position.z).length()
		if _dans_zone(j):
			if disputee:
				return "ZONE DISPUTÉE !"
			return "ZONE : %d / %d s" % [int(progres.get(j, 0.0)), int(ZONE_DUREE)]
		return "Rejoins la zone : %d m" % int(d)
	return ""


func _dans_zone(p) -> bool:
	return p.vivant and not p.elimine and p.en_match \
			and Vector2(p.global_position.x - zone.x, p.global_position.z - zone.z).length() < ZONE_RAYON \
			and p.global_position.y > zone.y - 2.0 and p.global_position.y < zone.y + 8.0


# ------------------------------------------------------------------- boucle ----
func _physics_process(dt: float) -> void:
	var P = Etat.partie
	if P == null or not P.actif:
		return
	if mode == "parcours":
		restant -= dt
		t_parcours += dt
		var j = Etat.joueur
		if j.vivant and idx < points.size():
			var p := points[idx]
			if Vector2(p.x - j.global_position.x, p.z - j.global_position.z).length() < RAYON_CP \
					and absf(j.global_position.y - p.y) < 3.5:
				idx += 1
				restant += PARCOURS_BONUS
				Fx.explosion(p + Vector3(0, 1, 0), 3.0, Color(0.2, 0.9, 1.0))
				if idx >= points.size():
					P.finir(j, "Parcours terminé en %s" % _mmss(t_parcours))
				else:
					Etat.msg("Checkpoint %d/%d  +%d s" % [idx, points.size(), int(PARCOURS_BONUS)])
					_maj_balises()
	elif mode == "controle" and zone_active:
		var dedans: Array = Etat.pilotes.filter(func(p): return _dans_zone(p))
		for p in Etat.pilotes:
			if not dedans.has(p):
				progres[p] = 0.0                       # quitter la zone remet la jauge à zéro
		disputee = dedans.size() > 1
		if dedans.size() == 1:
			var p: Pilote = dedans[0]
			progres[p] = progres.get(p, 0.0) + dt
			if progres[p] >= ZONE_DUREE:
				p.score += ZONE_POINTS
				Etat.msg("%s capture la zone : +%d points" % [p.nom, ZONE_POINTS])
				_nouvelle_zone()
		if anneau_mat != null:
			var c := Color(1, 0.15, 0.1, 0.5) if disputee else Color(1, 0.85, 0.1, 0.45)
			if not disputee and progres.get(Etat.joueur, 0.0) > 0.0:
				c = Color(0.2, 1, 0.3, 0.5)
			anneau_mat.albedo_color = c


func _mmss(t: float) -> String:
	return "%d:%02d" % [int(t) / 60, int(t) % 60]


## Appelé par Partie.verifier_fin() quand le mode n'est pas « classique ».
func verifier_fin() -> bool:
	var P = Etat.partie
	var j = Etat.joueur
	if mode == "parcours":
		if j.elimine:
			P.finir(null, "Éliminé : %d/%d checkpoints" % [idx, points.size()])
		elif restant <= 0.0:
			P.finir(null, "Temps écoulé : %d/%d checkpoints" % [idx, points.size()])
		return true
	if mode == "controle":
		if P.t >= Etat.DUREE_PARTIE:
			var best: Pilote = null
			for p in Etat.pilotes:
				if p.en_match and (best == null or p.score > best.score):
					best = p
			P.finir(best, "Temps écoulé : %d points" % best.score)
		return true
	return false
