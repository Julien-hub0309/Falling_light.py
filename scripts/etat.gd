extends Node
## Autoload "Etat" : règles du cahier des charges, registres partagés et utilitaires
## (équivalent de etat.py). Accessible partout avec `Etat.xxx`.

# ---- Règles du cahier des charges ---------------------------------------------------
const DUREE_PARTIE := 600.0      # 10 min
const DUREE_JOUR := 300.0        # la nuit tombe après 5 min
const NB_PILOTES := 5
const NB_ZOMBIES := 30
const COUT_TITAN := 10
const COUT_RESPAWN := 50
const DELAI_RESPAWN_ZOMBIE := 4.0
const DEMI_MAP := 180.0
const RAYON_BRUIT_TIR := 90.0

# ---- Couches de collision (valeurs de bits) -----------------------------------------
const COUCHE_MONDE := 1
const COUCHE_PILOTE := 2
const COUCHE_ZOMBIE := 4
const COUCHE_TITAN := 8
const MASQUE_TIR := COUCHE_MONDE | COUCHE_PILOTE | COUCHE_ZOMBIE | COUCHE_TITAN

# ---- Signaux vers l'interface -------------------------------------------------------
signal message(texte: String)
signal banniere(texte: String, duree: float)
signal degats_recus
signal touche(tete: bool)
signal menu_demande
signal partie_demarree

# ---- Réglages (sauvegardés dans user://config.json) ---------------------------------
var sensibilite := 40.0              # 10..120 (même échelle que le Python)
var fov := 100.0                     # 70..120 (horizontal)
var inverser_y := false
var qualite := "moyen"
var mode_jeu := "classique"          # classique / parcours / controle               # bas / moyen / haut
const NIVEAUX := ["bas", "moyen", "haut"]
const CONFIG := "user://config.json"
## (action, libellé) dans l'ordre du menu d'options
const ACTIONS := [
	["avant", "Avancer"], ["arriere", "Reculer"], ["gauche", "Gauche"], ["droite", "Droite"],
	["saut", "Saut / grimper"], ["sprint", "Sprint"], ["glisse", "Glisser"],
	["tir", "Tirer"], ["viser", "Viser"], ["recharge", "Recharger"],
	["arme1", "Arme 1"], ["arme2", "Arme 2"], ["arme_suiv", "Arme suivante"], ["arme_prec", "Arme précédente"],
	["tactique", "Grenade / fumigène"], ["grappin", "Grappin"],
	["kit_soin", "Kit de soin"], ["kit_armure", "Kit d'armure"],
	["titan", "Appeler le Titan"], ["interagir", "Embarquer / éjecter"],
	["competence", "Compétence (niv. 2)"], ["ultime", "Ultime (niv. 3)"],
	["titan_ordre", "Ordre du Titan"], ["titan_aller", "Titan : aller là"], ["melee", "Épée du Titan"],
]

# ---- Registres partagés --------------------------------------------------------------
var joueur = null                 # Joueur
var partie = null                 # Partie
var env: Environment = null
var soleil: DirectionalLight3D = null
var racine_zombies: Node3D = null
var racine_loots: Node3D = null
var pilotes: Array = []
var zombies: Array = []
var titans: Array = []
var loots: Array = []
var fumees: Array = []
var toits: Array[Vector3] = []      # centres de toits accessibles (pour les checkpoints / zones)
var modes = null                    # Modes
var lampes: Array = []              # OmniLight3D des lampadaires (allumées la nuit)
var lampes_mat: StandardMaterial3D = null
var lumieres_int: Array = []        # lumières d'intérieur (un peu allumées le jour, fort la nuit)
var eau_zones: Array = []           # [centre Vector2, rayon] : eau peu profonde (ralentit)
var spawns: Array[Vector3] = []
var obstacles: Array[Rect2] = []  # empreintes au sol (x, z, largeur, profondeur)
var batiments: Array[Rect2] = []  # pour la minimap


func _ready() -> void:
	_creer_actions()
	charger_config()


func msg(texte: String) -> void:
	message.emit(texte)


# ---- Entrées : actions créées par code (touches PHYSIQUES => ZQSD sur AZERTY) -------------
func _creer_actions() -> void:
	var clavier := {
		"avant": [KEY_W], "arriere": [KEY_S], "gauche": [KEY_A], "droite": [KEY_D],
		"saut": [KEY_SPACE], "sprint": [KEY_SHIFT], "glisse": [KEY_CTRL, KEY_C],
		"recharge": [KEY_R], "arme1": [KEY_1], "arme2": [KEY_2],
		"tactique": [KEY_G], "grappin": [KEY_X], "kit_soin": [KEY_H], "kit_armure": [KEY_V],
		"competence": [KEY_T], "ultime": [KEY_Y], "titan_ordre": [KEY_B], "titan_aller": [KEY_N], "melee": [KEY_Q], "titan": [KEY_F], "interagir": [KEY_E],
		"pause": [KEY_ESCAPE],
	}
	for action in clavier:
		_action(action)
		InputMap.action_erase_events(action)
		for k in clavier[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	var souris := {
		"tir": MOUSE_BUTTON_LEFT, "viser": MOUSE_BUTTON_RIGHT,
		"arme_suiv": MOUSE_BUTTON_WHEEL_UP, "arme_prec": MOUSE_BUTTON_WHEEL_DOWN,
	}
	for action in souris:
		_action(action)
		InputMap.action_erase_events(action)
		var ev := InputEventMouseButton.new()
		ev.button_index = souris[action]
		InputMap.action_add_event(action, ev)


func _action(nom: String) -> void:
	if not InputMap.has_action(nom):
		InputMap.add_action(nom)


# ---- Monde : placement ---------------------------------------------------------------------
func est_libre(x: float, z: float, r: float) -> bool:
	var lim := DEMI_MAP - 3.0
	if absf(x) > lim or absf(z) > lim:
		return false
	var p := Vector2(x, z)
	for o in obstacles:
		if o.grow(r).has_point(p):
			return false
	return true


func point_libre(rayon := 1.0, loin_de: Array = [], dmin := 0.0, essais := 80) -> Vector3:
	for i in essais:
		var x := randf_range(-DEMI_MAP + 6.0, DEMI_MAP - 6.0)
		var z := randf_range(-DEMI_MAP + 6.0, DEMI_MAP - 6.0)
		if not est_libre(x, z, rayon):
			continue
		var ok := true
		for p in loin_de:
			if Vector2(x - p.global_position.x, z - p.global_position.z).length() < dmin:
				ok = false
				break
		if ok:
			return Vector3(x, 0, z)
	return Vector3.ZERO


## Point de spawn le plus éloigné des pilotes vivants.
func spawn_loin() -> Vector3:
	var best := spawns[0]
	var bd := -1.0
	for s in spawns:
		var d := 999.0
		for p in pilotes:
			if p.vivant:
				d = minf(d, Vector2(s.x - p.global_position.x, s.z - p.global_position.z).length())
		if d > bd:
			best = s
			bd = d
	return best


# ---- Rayons / tirs ---------------------------------------------------------------------------
func raycast(depuis: Node3D, origine: Vector3, dir: Vector3, dist: float, masque: int) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(origine, origine + dir.normalized() * dist, masque)
	if depuis is CollisionObject3D:
		q.exclude = [depuis.get_rid()]
	return depuis.get_world_3d().direct_space_state.intersect_ray(q)


## Tir instantané : touche le premier mur / zombie / pilote. Retourne {point, cible, tete}.
func hitscan(tireur: Node3D, origine: Vector3, dir: Vector3, portee: float, degats: float,
		couleur := Color.YELLOW, ep := 0.04, debut = null) -> Dictionary:
	dir = dir.normalized()
	var q := PhysicsRayQueryParameters3D.create(origine, origine + dir * portee, MASQUE_TIR)
	var amis: Array[RID] = []
	var prop = proprietaire(tireur)
	for a in [tireur, prop, prop.titan if prop is Pilote else null, prop.bouclier if prop is Pilote else null]:
		if a is CollisionObject3D:
			amis.append(a.get_rid())
	q.exclude = amis
	var r := tireur.get_world_3d().direct_space_state.intersect_ray(q)
	var fin := origine + dir * portee
	var cible = null
	var tete := false
	if not r.is_empty():
		fin = r.position
		var c = r.collider
		if c != null and c.has_method("damage"):
			cible = c
			var gros: bool = c is Titan or (c is Pilote and c.mode == "titan")
			tete = (not gros) and fin.y > c.global_position.y + c.h * 0.8
			if degats > 0.0:
				c.damage(degats * (1.5 if tete else 1.0), tireur, tete)
			if tireur == joueur:
				touche.emit(tete)
	var d0: Vector3 = debut if debut != null else origine
	trace(d0, fin, couleur, ep)
	if debut != null and tireur != joueur:
		Fx.flash(debut, 0.2)
	if cible == null:
		if not r.is_empty():
			Fx.impact(fin)
	elif cible is Titan or (cible is Pilote and cible.mode == "titan"):
		Fx.etincelles(fin, Color(1, 0.55, 0.1), 4)
	else:
		Fx.sang(fin, 4)
	return {"point": fin, "cible": cible, "tete": tete}


# ---- Cibles / dégâts -------------------------------------------------------------------
func toutes_cibles() -> Array:
	var res: Array = pilotes.filter(func(p): return p.vivant and not p.elimine)
	for z in zombies:
		if is_instance_valid(z) and z.vivant:
			res.append(z)
	for t in titans:
		if is_instance_valid(t) and t.vivant and t.state == "ready":
			res.append(t)
	return res


## Même camp ? (un pilote et son Titan ; un pilote et lui-même). Les zombies n'ont pas de camp.
func est_ami(a, b) -> bool:
	var pa = proprietaire(a)
	var pb = proprietaire(b)
	return pa != null and pa == pb


## Un Titan appartient à un pilote : les points vont au pilote.
func proprietaire(src):
	return src.proprio if src != null and src is Titan else src


## Explosion : dégâts décroissants avec la distance (min 25 %). Le lanceur est épargné.
func explode(pos: Vector3, rayon: float, degats: float, source = null, ignore: Array = []) -> void:
	for c in toutes_cibles():
		if c == source or ignore.has(c) or (source != null and est_ami(c, source)):
			continue                                    # ni le lanceur, ni son Titan
		var centre: Vector3 = c.global_position + Vector3(0, c.h * 0.5, 0)
		var dd := maxf(0.0, centre.distance_to(pos) - c.r)
		if dd < rayon:
			var n := degats * maxf(0.25, 1.0 - dd / rayon)
			if c is Pilote:
				n *= Competences.reduc_explosif(c)       # Breacher : armure lourde
			c.damage(n, source)
	Fx.explosion(pos, rayon * 1.6)
	if joueur != null:
		Fx.secousse(maxf(0.0, 1.0 - joueur.global_position.distance_to(pos) / 35.0) * rayon * 0.12)


func _dist_seg(a: Vector3, b: Vector3, c: Vector3) -> float:
	var ab := b - a
	var l2 := ab.dot(ab)
	if l2 < 0.000001:
		return (c - a).length()
	var t := clampf((c - a).dot(ab) / l2, 0.0, 1.0)
	return (c - (a + ab * t)).length()


## Ligne de vue entre deux points (bâtiments + fumigènes).
func visible_entre(depuis: Node3D, a: Vector3, b: Vector3) -> bool:
	var d := b - a
	var l := d.length()
	if l < 0.1:
		return true
	var r := raycast(depuis, a, d / l, l, COUCHE_MONDE)
	if not r.is_empty() and a.distance_to(r.position) < l - 0.3:
		return false
	for f in fumees:
		if is_instance_valid(f) and _dist_seg(a, b, f.global_position) < f.rayon * 0.9:
			return false
	return true


## Détruit les structures « destructibles » (murs en ruine, gravats, conteneurs, voitures...).
func detruire_structures(pos: Vector3, rayon: float) -> int:
	var n := 0
	for s in get_tree().get_nodes_in_group("destructible"):
		if is_instance_valid(s) and s.global_position.distance_to(pos) < rayon:
			Fx.explosion(s.global_position, 3.0, Color(0.8, 0.6, 0.3))
			s.queue_free()
			n += 1
	return n


## Sonne les ennemis proches : zombies figés 3 s, pilotes ralentis 2 s.
func etourdir(pos: Vector3, rayon: float, source = null) -> void:
	for c in toutes_cibles():
		if c == source or (source != null and est_ami(c, source)):
			continue
		if c.global_position.distance_to(pos) < rayon:
			if c is Zombie:
				c.stun_t = 3.0
			elif c is Pilote:
				c.etourdi_t = 2.0


## Alerte les zombies qui écoutent (spéciaux le jour, rapaces la nuit) autour d'un coup de feu.
func bruit(pos: Vector3, rayon := RAYON_BRUIT_TIR) -> void:
	for z in zombies:
		if is_instance_valid(z) and z.vivant and z.ecoute_bruit \
				and Vector2(z.global_position.x - pos.x, z.global_position.z - pos.z).length() < rayon:
			z.alerter(pos)


## Trait lumineux bref (balle traçante).
func trace(a: Vector3, b: Vector3, col := Color.YELLOW, ep := 0.04, dur := 0.05) -> void:
	var l := a.distance_to(b)
	if l < 0.5:
		return
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(ep, ep, l)
	m.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_tree().current_scene.add_child(m)
	m.global_position = (a + b) * 0.5
	var haut := Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.RIGHT
	m.look_at(b, haut)
	get_tree().create_timer(dur).timeout.connect(m.queue_free)


# ---- Configuration : touches / souris / graphismes ---------------------------------------
func _ev_vers_dict(ev: InputEvent) -> Dictionary:
	if ev is InputEventKey:
		return {"t": "k", "c": ev.physical_keycode}
	if ev is InputEventMouseButton:
		return {"t": "m", "c": ev.button_index}
	return {}


func _dict_vers_ev(d: Dictionary) -> InputEvent:
	if d.get("t") == "k":
		var k := InputEventKey.new()
		k.physical_keycode = int(d["c"]) as Key
		return k
	if d.get("t") == "m":
		var m := InputEventMouseButton.new()
		m.button_index = int(d["c"]) as MouseButton
		return m
	return null


func sauver_config() -> void:
	var touches := {}
	for a in ACTIONS:
		touches[a[0]] = InputMap.action_get_events(a[0]).map(_ev_vers_dict)
	var data := {"touches": touches, "sensibilite": sensibilite, "fov": fov,
		"inverser_y": inverser_y, "qualite": qualite}
	var f := FileAccess.open(CONFIG, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "  "))


func charger_config() -> void:
	if not FileAccess.file_exists(CONFIG):
		appliquer_qualite()
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	if typeof(data) != TYPE_DICTIONARY:
		return
	for a in data.get("touches", {}):
		if InputMap.has_action(a) and data["touches"][a] is Array:
			InputMap.action_erase_events(a)
			for d in data["touches"][a]:
				var ev := _dict_vers_ev(d)
				if ev != null:
					InputMap.action_add_event(a, ev)
	sensibilite = clampf(float(data.get("sensibilite", sensibilite)), 10.0, 120.0)
	fov = clampf(float(data.get("fov", fov)), 70.0, 120.0)
	inverser_y = bool(data.get("inverser_y", inverser_y))
	var q: String = data.get("qualite", qualite)
	if q in NIVEAUX:
		qualite = q
	appliquer_qualite()


## Graphismes : bas = pas d'ombres ni d'anti-crénelage ; moyen = ombres ; haut = ombres + MSAA 4x.
func appliquer_qualite() -> void:
	if get_viewport() == null:
		return
	get_viewport().msaa_3d = Viewport.MSAA_4X if qualite == "haut" else Viewport.MSAA_DISABLED
	if soleil != null:
		soleil.shadow_enabled = qualite != "bas"
	if env != null:
		env.fog_enabled = true


func reinitialiser_touches() -> void:
	for a in ACTIONS:
		InputMap.action_erase_events(a[0])
	_creer_actions()


func dans_eau(pos: Vector3) -> bool:
	for z in eau_zones:
		if Vector2(pos.x - z[0].x, pos.z - z[0].y).length() < z[1] and pos.y < 1.0:
			return true
	return false
