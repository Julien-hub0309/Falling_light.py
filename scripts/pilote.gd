class_name Pilote
extends CharacterBody3D
## Base commune du joueur et des bots (bot/pilote.py) : PV, armure, points, classe,
## armes, grenades, ramassage du loot. L'origine du nœud = les PIEDS.

var nom := "Pilote"
var r := 0.4
var h := 1.8
var vivant := false
var elimine := false
var attente := false
var score := 0
var score_final := 0
var kills := 0
var t_elim := -1.0
var hp := 100.0
var hp_max := 100.0
var armure := 0.0
var invuln := 0.0
var since_hit := 99.0
var cool_tact := 0.0
var classe: Dictionary = {}
var armes: Array = []
var idx := 0
var tactique := "frag"
var nb_tactique := 0
var vitesse_mult := 1.0
var cs_forme: CapsuleShape3D
var cs_noeud: CollisionShape3D
var mode := "pilot"                  # "pilot" ou "titan" (pilote à bord)
var titan = null                     # Titan appelé par ce pilote
var titan_cd := 0.0
var titan_hp := 0.0
var arme_titan: Arme = null
var craft: Dictionary = Craft.neuf()
var armure_max := 100.0
var comp: Dictionary = Competences.neuf()
var arme_temp: Arme = null           # arme temporaire (lance-roquettes du Breacher)
var bouclier = null                  # Bouclier déployé (Tactique)
var etourdi_t := 0.0
var cd_epee := 0.0
var dernier_tir := -99.0             # pour la mini-carte (les Recon sont silencieux)
var en_match := true                 # false : pilote désactivé dans ce mode (ex. Parcours)


func _ready() -> void:
	collision_layer = 0
	collision_mask = Etat.COUCHE_MONDE
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.35
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = r
	cap.height = h
	cs.shape = cap
	cs.position.y = h * 0.5
	add_child(cs)
	cs_forme = cap
	cs_noeud = cs
	Etat.pilotes.append(self)


# ---- hooks surchargés par Joueur / PiloteIA ----
func apres_respawn() -> void: pass
func avant_mort() -> void: pass
func sur_degats(_source) -> void: pass
func sur_changement_arme() -> void: pass


func arme_active() -> Arme:
	if mode == "titan" and arme_titan != null:
		return arme_titan
	if arme_temp != null:
		return arme_temp
	return armes[idx] if armes.size() > 0 else null


## Change la taille de la capsule (pilote 0,4 x 1,8 ; à bord du Titan 1,2 x 5,6).
func set_taille(rayon: float, haut: float) -> void:
	r = rayon
	h = haut
	cs_forme.radius = rayon
	cs_forme.height = haut
	cs_noeud.position.y = haut * 0.5


func oeil() -> Vector3:
	return global_position + Vector3(0, 1.6, 0)


# ---- cycle de vie ----
func nouvelle_partie(c: Dictionary, pos: Vector3) -> void:
	score = 0
	score_final = 0
	kills = 0
	elimine = false
	t_elim = -1.0
	titan = null
	titan_cd = 0.0
	craft = Craft.neuf()
	comp = Competences.neuf()
	arme_temp = null
	reapparaitre(pos, c)


func reapparaitre(pos: Vector3, c: Dictionary = {}) -> void:
	appliquer_classe(c if not c.is_empty() else classe)
	vivant = true
	attente = false
	mode = "pilot"
	arme_titan = null
	arme_temp = null
	etourdi_t = 0.0
	comp["ult_t"] = 0.0
	comp["camo_t"] = 0.0
	set_taille(0.4, 1.8)
	global_position = Vector3(pos.x, 0.05, pos.z)
	invuln = 3.0
	since_hit = 99.0
	cool_tact = 0.0
	collision_layer = Etat.COUCHE_PILOTE
	visible = true
	apres_respawn()


func mourir() -> void:
	vivant = false
	collision_layer = 0
	avant_mort()


func appliquer_classe(c: Dictionary) -> void:
	classe = c
	hp_max = c["hp"]
	hp = hp_max
	armure = 0.0
	tactique = c["tactique"]
	nb_tactique = c["nb_tactique"]
	vitesse_mult = c["vitesse"]
	armes = [Arme.creer("Couteau"), Arme.creer("Couteau")]   # on démarre avec le couteau seul
	idx = 0
	Craft.apres_classe(self)                                 # le craft déjà obtenu est conservé
	sur_changement_arme()


# ---- dégâts ----
func damage(n: float, source = null, _tete := false) -> void:
	if not vivant or elimine or invuln > 0.0 or Etat.partie == null or not Etat.partie.actif:
		return
	since_hit = 0.0
	if mode == "titan":                       # pilote à bord : les dégâts vont au Titan
		titan_hp -= n * 0.8
		sur_degats(source)
		if titan_hp <= 0.0:
			ejecter(true)
		return
	if armure > 0.0:
		var a := minf(armure, n * 0.6)
		armure -= a
		n -= a
	hp -= n
	sur_degats(source)
	if hp <= 0.0:
		if Competences.reanimation(self):                # Tactique niveau 3 : revient à 60 % de PV
			return
		Etat.partie.mort_pilote(self, source)


## Timers communs : invulnérabilité, régénération, armes, cooldowns.
func tick(dt: float) -> void:
	invuln = maxf(0.0, invuln - dt)
	since_hit += dt
	cool_tact -= dt
	titan_cd = maxf(0.0, titan_cd - dt)
	cd_epee = maxf(0.0, cd_epee - dt)
	etourdi_t = maxf(0.0, etourdi_t - dt)
	Competences.tick(self, dt)
	if arme_titan != null:
		arme_titan.update(dt)
	if mode == "pilot" and since_hit > 4.0 and hp < hp_max:
		hp = minf(hp_max, hp + 6.0 * dt)
	for a in armes:
		a.update(dt)
	if arme_temp != null:
		arme_temp.update(dt)


# ---- équipement ----
func choisir_arme(i: int) -> void:
	if i >= 0 and i < armes.size() and i != idx:
		idx = i
		sur_changement_arme()


func lancer_tactique(origine: Vector3, vitesse: Vector3) -> bool:
	if nb_tactique <= 0 or cool_tact > 0.0:
		return false
	nb_tactique -= 1
	cool_tact = 1.0
	Etat.get_tree().current_scene.add_child(Grenade.creer(self, origine, vitesse, tactique))
	return true


func ramasser(type: String) -> bool:
	var cr := Craft.on_loot(self, type)            # soin / armure / grenade / compteur d'armes
	if cr != -1:
		return cr == 1
	var texte := ""
	match type:
		"soin":
			if hp >= hp_max - 1.0:
				return false
			hp = minf(hp_max, hp + 45.0)
			texte = "Medikit +45 PV"
		"armure":
			if armure >= 50.0:
				return false
			armure = 50.0
			texte = "Armure +50"
		"munitions":
			for a in armes:
				a.ajouter_munitions(a.chargeur * 2)
			texte = "Munitions"
		"grenade":
			if nb_tactique >= 4:
				return false
			nb_tactique += 1
			texte = "+1 " + tactique
		"arme":
			var choix: Array = ArmesDB.PRIMAIRES.filter(func(n): return n != armes[0].nom)
			var n: String = choix[randi() % choix.size()]
			armes[0] = Arme.creer(n)
			texte = "Arme : " + n
			sur_changement_arme()
	if self == Etat.joueur and texte != "":
		Etat.msg(texte)
	return true


# ---- Titan ----
func titan_actif() -> bool:
	return titan != null and is_instance_valid(titan) and titan.vivant


## Coûte 10 points. Le Titan tombe du ciel devant le pilote.
func appeler_titan() -> bool:
	var joueur_humain: bool = (self == Etat.joueur)
	if mode == "titan" or titan_actif():
		return false
	if titan_cd > 0.0:
		if joueur_humain:
			Etat.msg("Titan prêt dans %ds" % ceili(titan_cd))
		return false
	if score < Etat.COUT_TITAN:
		if joueur_humain:
			Etat.msg("Il faut %d points pour appeler un Titan" % Etat.COUT_TITAN)
		return false
	var base := -global_transform.basis.z
	base.y = 0.0
	base = base.normalized()
	# devant soi d'abord, puis en tournant (évite les murs / bords de map)
	for ang in [0, 35, -35, 70, -70, 110, -110, 180]:
		var fw := base.rotated(Vector3.UP, deg_to_rad(ang))
		for d in range(14, 60, 4):
			var spot := global_position + fw * d
			if Etat.est_libre(spot.x, spot.z, 3.5):
				score -= Etat.COUT_TITAN
				titan = Titan.creer(self, spot)
				Etat.get_tree().current_scene.add_child(titan)
				if joueur_humain:
					Etat.msg("TITANFALL ! (-%d pts)" % Etat.COUT_TITAN)
				return true
	return false


func ejecter(_force := false) -> void:
	pass          # surchargé par Joueur


## Vitesse effective : classe x passifs x étourdissement (charge explosive).
func vitesse_totale() -> float:
	var v := vitesse_mult * Competences.mult_vitesse(self)
	return v * (0.4 if etourdi_t > 0.0 else 1.0)


## Ordres simples au Titan quand on n'est pas à bord : suivre / tenir / attaquer / aller.
func ordre_titan_suivant() -> void:
	if not titan_actif() or titan.state != "ready":
		return
	var liste := ["suivre", "tenir", "attaquer"]
	var i := liste.find(titan.ordre)
	titan.ordre = liste[(i + 1) % liste.size()] if i >= 0 else "suivre"
	titan.point_garde = titan.global_position
	if self == Etat.joueur:
		Etat.msg("Titan : " + titan.ordre.to_upper())


func ordre_titan_aller(point: Vector3) -> void:
	if not titan_actif() or titan.state != "ready":
		return
	titan.ordre = "aller"
	titan.point_garde = Nav.proche_gros(point)
	if self == Etat.joueur:
		Etat.msg("Titan : en route")
