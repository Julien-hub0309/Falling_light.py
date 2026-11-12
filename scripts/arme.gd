class_name Arme
extends RefCounted
## Classe de base de toutes les armes (armes/arme.py).

var nom := ""
var modele := ""               # clé du modèle 3D (= nom d'origine)
var titan := false
var aug_melee := false         # bonus de mêlée du craft déjà appliqué
var augmentee := false         # amélioration d'arme du craft déjà appliquée
var degats := 10.0
var cadence := 0.1
var chargeur := 30
var reserve := 0              # -1 = infinie
var portee := 100.0
var dispersion := 0.01
var plombs := 1
var auto := true
var t_recharge := 1.0
var zoom := 0.0               # FOV en visée, 0 = pas de zoom
var ads_prec := 0.5
var recul := 0.05
var couleur_trace := Color.YELLOW
var ep := 0.04
var vue_pos := Vector3.ZERO
var projectile := ""          # "roquette" : tire un projectile au lieu d'un tir instantané
var pref := 20.0               # distance de combat préférée des bots
var munitions := 0
var cool := 0.0
var rech := 0.0


static func creer(n: String) -> Arme:
	var a := Arme.new()
	a.nom = n
	a.modele = n
	var d: Dictionary = ArmesDB.DATA[n]
	for k in d:
		a.set(k, d[k])
	a.munitions = a.chargeur
	return a


## Version Titan de l'arme : dégâts x3, chargeur x3, munitions infinies, portée x1.4 (armes/titan.py).
static func pour_titan(src: Arme) -> Arme:
	var t := Arme.new()
	for p in ["nom", "modele", "degats", "cadence", "chargeur", "reserve", "portee", "dispersion", "plombs",
			"auto", "t_recharge", "zoom", "ads_prec", "recul", "couleur_trace", "ep", "pref", "projectile"]:
		t.set(p, src.get(p))
	t.titan = true
	t.nom = src.nom + " TITAN"
	t.degats = src.degats * 3.0
	t.cadence = src.cadence * 1.15
	t.chargeur = src.chargeur * 3
	t.munitions = t.chargeur
	t.reserve = -1
	t.t_recharge = src.t_recharge * 0.8
	t.portee = src.portee * 1.4
	t.dispersion = src.dispersion * 0.7
	t.recul = src.recul * 2.0
	t.ep = src.ep * 4.0
	t.pref = src.pref * 1.4
	t.vue_pos = Vector3(0.95, -0.85, -1.5)
	return t


func melee() -> bool:
	return chargeur == 0


func update(dt: float) -> void:
	cool -= dt
	if rech > 0.0:
		rech -= dt
		if rech <= 0.0:
			_fin_recharge()


func pret() -> bool:
	return cool <= 0.0 and rech <= 0.0


func recharger() -> bool:
	if melee() or rech > 0.0 or munitions >= chargeur:
		return false
	if reserve == 0:
		return false
	rech = t_recharge
	return true


func _fin_recharge() -> void:
	var besoin := chargeur - munitions
	if reserve < 0:
		munitions = chargeur
	else:
		var pris := mini(besoin, reserve)
		munitions += pris
		reserve -= pris


func ajouter_munitions(n: int) -> void:
	if reserve >= 0:
		reserve += n


## Tire depuis `origin` dans la direction `dir`. Retourne true si le coup est parti.
func tirer(owner_node: Node3D, origin: Vector3, dir: Vector3, debut: Vector3, zoomed := false) -> bool:
	if not pret():
		return false
	if not melee():
		if munitions <= 0:
			recharger()
			return false
		munitions -= 1
	var facteur := 1.0
	if owner_node is Pilote:
		facteur = Competences.facteur_cadence(owner_node)
	cool = cadence / facteur
	if projectile == "roquette":
		Etat.get_tree().current_scene.add_child(Roquette.creer(owner_node, debut, dir.normalized(), degats))
		return true
	var base := dir.normalized()
	var droite := base.cross(Vector3.UP)
	droite = droite.normalized() if droite.length() > 0.001 else Vector3.RIGHT
	var haut := droite.cross(base).normalized()
	var sp := dispersion * (ads_prec if zoomed else 1.0)
	for i in plombs:
		var dd := base + droite * randf_range(-sp, sp) + haut * randf_range(-sp, sp)
		Etat.hitscan(owner_node, origin, dd, portee, degats, couleur_trace, ep, debut)
	return true
