class_name MapBuilder
extends Node3D
## Ville post-apocalyptique 360 x 360 m (map/map.py + map/elements.py), version Godot.
## 6 x 6 pâtés de maisons séparés par 5 rues de 12 m. Types : immeuble, lotissement
## (4 petits immeubles + passerelles), parc, ruines, + 4 lieux spéciaux : TOUR, PARKING,
## CHANTIER, PARC central. Chaque immeuble a une RAMPE d'accès ; le reste se fait au grappin.
## Version simplifiée de l'original : les escaliers en zigzag, balcons, mobilier de toit,
## véhicules et lampadaires ne sont pas encore portés.

const ROUTES := [-120, -60, 0, 60, 120]
const CENTRES := [-150, -90, -30, 30, 90, 150]
const LOOT_TOIT := ["arme", "arme", "armure", "armure", "soin", "munitions", "grenade"]

var rng := RandomNumberGenerator.new()
var _mats := {}
var _loot_toit: Array = []           # [position, nb]
var zz: Array = []
var interieurs: Array = []
var epaves_pos: Array = []
var stats := {"zigzag": 0, "balcons": 0, "voitures": 0, "lampadaires": 0, "interieurs": 0, "maisons": 0, "tour": 0, "epaves": 0, "couvertures": 0, "arbres": 0, "etangs": 0}


func construire(graine := 1234) -> void:
	rng.seed = graine
	Etat.obstacles.clear()
	Etat.batiments.clear()
	Etat.spawns.clear()
	Etat.toits.clear()
	stats = {"zigzag": 0, "balcons": 0, "voitures": 0, "lampadaires": 0, "interieurs": 0, "maisons": 0, "tour": 0, "epaves": 0, "couvertures": 0, "arbres": 0, "etangs": 0}
	Etat.lumieres_int.clear()
	interieurs.clear()
	epaves_pos.clear()
	Etat.eau_zones.clear()
	_sol_et_routes()
	_enceinte()
	MapDecor.grand_parc(self, -60.0, -60.0)                      # 2 x 2 pâtés : grand parc avec étang
	for cx in CENTRES:
		for cz in CENTRES:
			var p := Vector2(cx, cz)
			if p.x <= -30 and p.x >= -90 and p.y <= -30 and p.y >= -90:
				continue                                           # fait partie du grand parc
			if p == Vector2(30, 30):
				MapBatiments.tour(self, cx, cz)                    # grande tour (intérieur obligatoire)
			elif p == Vector2(90, -90):
				_parking(cx, cz)
			elif p == Vector2(-90, 90):
				_chantier(cx, cz)
				MapDecor.decor_bloc(self, cx, cz, 5)
			else:
				var r := rng.randf()
				if r < 0.26:
					_immeuble(cx, cz)                              # plein, escalier / rampe extérieur
					MapDecor.decor_bloc(self, cx, cz)
				elif r < 0.50:
					MapBatiments.immeuble(self, cx, cz)            # entrable (escalier intérieur)
					MapDecor.decor_bloc(self, cx, cz)
				elif r < 0.72:
					MapBatiments.lotissement(self, cx, cz)         # 4 maisons entrables
					MapDecor.decor_bloc(self, cx, cz, 6)
				elif r < 0.82:
					_ruines(cx, cz)
				elif r < 0.91:
					MapDecor.place(self, cx, cz)
				else:
					MapDecor.petit_parc(self, cx, cz)
	_voitures()
	MapDecor.epaves(self)
	MapDecor.couvertures(self)
	_lampadaires()
	# points d'apparition : carrefours des rues
	for ax in ROUTES:
		for az in ROUTES:
			Etat.spawns.append(Vector3(ax, 0, az))
	_loots()


# ============================================================ briques de base ====
func _mat(c: Color) -> StandardMaterial3D:
	var k := c.to_html()
	if not _mats.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.9
		_mats[k] = m
	return _mats[k]


func _gris(v: float) -> Color:
	return Color(v, v, v * 1.04)


## Boîte pleine : (x0..x1, y0..y1, z0..z1). `coll` = collision, `empreinte` = zone interdite au spawn.
func bloc(x0: float, x1: float, y0: float, y1: float, z0: float, z1: float, col: Color,
		coll := true, empreinte := false, destructible := false) -> StaticBody3D:
	var corps := StaticBody3D.new()
	if destructible:
		corps.add_to_group("destructible")          # détruit par la charge explosive / les roquettes
	corps.collision_layer = Etat.COUCHE_MONDE
	corps.collision_mask = 0
	corps.position = Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5)
	var taille := Vector3(x1 - x0, y1 - y0, z1 - z0)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = taille
	mi.mesh = bm
	mi.material_override = _mat(col)
	corps.add_child(mi)
	if coll:
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = taille
		cs.shape = sh
		corps.add_child(cs)
	add_child(corps)
	if empreinte:
		Etat.obstacles.append(Rect2(x0, z0, x1 - x0, z1 - z0))
	return corps


func cylindre(x: float, z: float, rayon: float, haut: float, col: Color) -> void:
	var corps := StaticBody3D.new()
	corps.collision_layer = Etat.COUCHE_MONDE
	corps.collision_mask = 0
	corps.position = Vector3(x, haut * 0.5, z)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = rayon
	cm.bottom_radius = rayon
	cm.height = haut
	mi.mesh = cm
	mi.material_override = _mat(col)
	corps.add_child(mi)
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = rayon
	sh.height = haut
	cs.shape = sh
	corps.add_child(cs)
	add_child(corps)
	Etat.obstacles.append(Rect2(x - rayon, z - rayon, rayon * 2.0, rayon * 2.0))


## Rampe de (x0, y_bas) à (x1, y_haut), centrée sur z, de largeur `larg`. x1 peut être < x0
## (rampe qui monte vers -x).
func rampe_x(x0: float, x1: float, z: float, larg: float, y_bas: float, y_haut: float, col: Color) -> void:
	var run := absf(x1 - x0)
	var sens := 1.0 if x1 >= x0 else -1.0
	var mont := y_haut - y_bas
	var ang := atan2(mont, run) * sens
	var longueur := sqrt(run * run + mont * mont)
	var ep := 0.4
	var n := Vector3(0, 1, 0).rotated(Vector3.BACK, ang)
	var mid := Vector3((x0 + x1) * 0.5, (y_bas + y_haut) * 0.5, z) - n * ep * 0.5
	var corps := StaticBody3D.new()
	corps.collision_layer = Etat.COUCHE_MONDE
	corps.collision_mask = 0
	corps.position = mid
	corps.rotation.z = ang
	var taille := Vector3(longueur, ep, larg)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = taille
	mi.mesh = bm
	mi.material_override = _mat(col)
	corps.add_child(mi)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = taille
	cs.shape = sh
	corps.add_child(cs)
	add_child(corps)
	if y_bas <= 0.01:
		Etat.obstacles.append(Rect2(minf(x0, x1), z - larg * 0.5, run, larg))


## Escalier en ZIGZAG (rampes douces + paliers) collé à un mur.
## Deux voies côte à côte ; la voie B touche le mur (z = zmur) ; on monte en alternant les sens.
## `dir` = +1 : l'escalier s'étend vers +z depuis le mur ; -1 : vers -z.
## Paramètres (exterieur par défaut) : largeur de voie, longueur de volée, hauteur max par volée,
## longueur des paliers, piliers sous les paliers (extérieur) ou non (intérieur).
func escalier_zigzag(x_ouest: float, zmur: float, dir: float, h: float, col: Color,
		larg := 3.2, run := 10.0, pas_max := 4.0, palier := 4.0, piliers := true) -> Dictionary:
	var n := maxi(1, ceili(h / pas_max))
	var pas := h / n
	var x0 := x_ouest + palier                   # début de la 1re volée
	var x1 := x0 + run
	var zb := zmur + dir * (larg * 0.5)
	var za := zmur + dir * (larg * 1.5 + 0.2)
	var zc := zmur + dir * (larg + 0.1)           # centre des paliers (les 2 voies)
	var lp := larg * 2.0 + 0.2
	for k in n:
		var y0 := pas * k
		var y1 := pas * (k + 1)
		var vers_est := (k % 2 == 0)
		var z := za if (k % 2 == 0) else zb       # volées paires sur la voie A, impaires sur la voie B
		if vers_est:
			rampe_x(x0, x1, z, larg, y0, y1, col)
		else:
			rampe_x(x1, x0, z, larg, y0, y1, col)
		# palier = dalle fine au sommet de la volée (piliers à l'extérieur seulement)
		var pal_x0 := x1 if vers_est else x_ouest
		var pal_x1 := x1 + palier if vers_est else x0
		var za0 := minf(zc - lp * 0.5, zc + lp * 0.5)
		var za1 := maxf(zc - lp * 0.5, zc + lp * 0.5)
		bloc(pal_x0, pal_x1, y1 - 0.3, y1, za0, za1, col, true, false)
		if piliers:
			var x_ext0 := pal_x1 - 0.9 if vers_est else pal_x0
			bloc(x_ext0, x_ext0 + 0.9, 0.0, y1 - 0.3, za0, za0 + 0.9, col, true, false)
			bloc(x_ext0, x_ext0 + 0.9, 0.0, y1 - 0.3, za1 - 0.9, za1, col, true, false)
	var zmin := minf(zmur, zmur + dir * lp)
	if piliers:
		Etat.obstacles.append(Rect2(x_ouest, zmin, run + palier * 2.0, lp))
	# rectangle du trou à ménager dans les dalles des étages (volées + palier est)
	return {"trou": Rect2(x0, zmin, run + palier, lp), "x_ouest": x_ouest, "lp": lp}


func _sol_et_routes() -> void:
	var a := Etat.DEMI_MAP
	bloc(-a - 70, a + 70, -1.0, 0.0, -a - 70, a + 70, Color(0.22, 0.23, 0.22))
	for r in ROUTES:
		bloc(r - 6, r + 6, 0.0, 0.03, -a, a, Color(0.1, 0.1, 0.11), false)
		bloc(-a, a, 0.0, 0.032, r - 6, r + 6, Color(0.1, 0.1, 0.11), false)
	for ax in ROUTES:
		for az in ROUTES:
			bloc(ax - 6, ax + 6, 0.0, 0.05, az - 6, az + 6, _gris(0.2), false)


func _enceinte() -> void:
	var a := Etat.DEMI_MAP
	var col := _gris(0.3)
	bloc(-a - 2, a + 2, 0, 9, -a - 2, -a, col)
	bloc(-a - 2, a + 2, 0, 9, a, a + 2, col)
	bloc(-a - 2, -a, 0, 9, -a, a, col)
	bloc(a, a + 2, 0, 9, -a, a, col)


func _teinte(base: float) -> Color:
	var v := base * rng.randf_range(0.85, 1.15)
	return Color(v, v * rng.randf_range(0.95, 1.0), v * rng.randf_range(0.9, 1.0))


# ================================================================ pâtés ====
## Immeuble avec rampe d'accès le long d'une façade (rampe vers +x, côté +z ou -z).
func _immeuble_xy(x0: float, x1: float, z0: float, z1: float, h: float, col: Color, nb_loot := 3) -> void:
	bloc(x0, x1, 0, h, z0, z1, col, true, true)
	Etat.batiments.append(Rect2(x0, z0, x1 - x0, z1 - z0))
	var cote := 1.0 if rng.randf() < 0.5 else -1.0
	if (x1 - x0) >= 22.0 and rng.randf() < 0.5:
		# escalier en zigzag (façade +z ou -z) ; la volée finale arrive au niveau du toit
		escalier_zigzag(x0, z1 if cote > 0 else z0, cote, h, _gris(0.35))
		stats["zigzag"] += 1
		zz.append([x0, x1, z0, z1, h, cote])
		_balcons(x0, x1, z0, z1, h, cote)
		_loot_toit.append([Vector3((x0 + x1) * 0.5, h, (z0 + z1) * 0.5), x1 - x0, z1 - z0, nb_loot])
		if h >= 5.0 and h <= 26.0:
			Etat.toits.append(Vector3((x0 + x1) * 0.5 + 6.0, h, (z0 + z1) * 0.5))
		return
	var zr := (z1 + 1.6) if cote > 0 else (z0 - 1.6)
	var palier := 3.0                      # plateforme pleine au niveau du toit, au bout de la rampe
	rampe_x(x0, x1 - palier, zr, 3.0, 0.0, h, _gris(0.35))
	if cote > 0:
		bloc(x1 - palier, x1, 0, h, z1, z1 + 3.2, _gris(0.35), true, true)
	else:
		bloc(x1 - palier, x1, 0, h, z0 - 3.2, z0, _gris(0.35), true, true)
	_balcons(x0, x1, z0, z1, h, cote)
	_loot_toit.append([Vector3((x0 + x1) * 0.5, h, (z0 + z1) * 0.5), x1 - x0, z1 - z0, nb_loot])
	if h >= 5.0 and h <= 26.0:
		Etat.toits.append(Vector3((x0 + x1) * 0.5 - 2.0, h, (z0 + z1) * 0.5))


func _immeuble(cx: float, cz: float) -> void:
	var w := rng.randf_range(24.0, 36.0)
	var d := rng.randf_range(22.0, 32.0)
	var h := rng.randf_range(9.0, minf(24.0, w * 0.8))
	_immeuble_xy(cx - w * 0.5, cx + w * 0.5, cz - d * 0.5, cz + d * 0.5, h, _teinte(0.45))


func _lotissement(cx: float, cz: float) -> void:
	var h1 := rng.randf_range(6.0, 10.0)
	var h2 := rng.randf_range(6.0, 10.0)
	for sx in [-1.0, 1.0]:
		_immeuble_xy(cx + sx * 12.0 - 7.0, cx + sx * 12.0 + 7.0, cz - 12.0 - 7.0, cz - 12.0 + 7.0, h1, _teinte(0.5), 2)
		_immeuble_xy(cx + sx * 12.0 - 7.0, cx + sx * 12.0 + 7.0, cz + 12.0 - 7.0, cz + 12.0 + 7.0, h2, _teinte(0.5), 2)
	# passerelles entre les toits (même hauteur)
	bloc(cx - 5.0, cx + 5.0, h1 - 0.3, h1, cz - 13.5, cz - 10.5, _gris(0.3))
	bloc(cx - 5.0, cx + 5.0, h2 - 0.3, h2, cz + 10.5, cz + 13.5, _gris(0.3))


func _parc(cx: float, cz: float) -> void:
	bloc(cx - 22, cx + 22, 0.0, 0.06, cz - 22, cz + 22, Color(0.16, 0.25, 0.14), false)
	for i in rng.randi_range(10, 16):
		var x := cx + rng.randf_range(-20.0, 20.0)
		var z := cz + rng.randf_range(-20.0, 20.0)
		cylindre(x, z, 0.35, rng.randf_range(4.0, 8.0), Color(0.22, 0.16, 0.1))      # arbres morts
	for i in 4:
		bloc(cx + rng.randf_range(-18.0, 14.0), cx + rng.randf_range(15.0, 20.0), 0, 0.6,
				cz + rng.randf_range(-18.0, 14.0), cz + rng.randf_range(15.0, 20.0), Color(0.3, 0.28, 0.25), true, false, true)
	_loot_toit.append([Vector3(cx, 0.0, cz), 8.0, 8.0, 2])


func _ruines(cx: float, cz: float) -> void:
	for i in rng.randi_range(8, 14):
		var x := cx + rng.randf_range(-20.0, 20.0)
		var z := cz + rng.randf_range(-20.0, 20.0)
		var l := rng.randf_range(4.0, 10.0)
		var hh := rng.randf_range(1.5, 5.0)
		if rng.randf() < 0.5:
			bloc(x - l * 0.5, x + l * 0.5, 0, hh, z - 0.3, z + 0.3, _teinte(0.4), true, true, true)
		else:
			bloc(x - 0.3, x + 0.3, 0, hh, z - l * 0.5, z + l * 0.5, _teinte(0.4), true, true, true)
	for i in 10:                                                      # gravats
		var x := cx + rng.randf_range(-22.0, 22.0)
		var z := cz + rng.randf_range(-22.0, 22.0)
		var s := rng.randf_range(0.8, 1.8)
		bloc(x - s, x + s, 0, s * 0.9, z - s, z + s, _teinte(0.35), true, false, true)
	_loot_toit.append([Vector3(cx, 0.0, cz), 20.0, 20.0, 3])


func _tour(cx: float, cz: float) -> void:
	# podium avec rampe, puis tour de 59 m (accessible au grappin) coiffée d'un héliport
	_immeuble_xy(cx - 20, cx + 20, cz - 20, cz + 20, 12.0, _teinte(0.5), 3)
	Etat.toits.pop_back()                                   # le centre du podium est occupé par la tour
	Etat.toits.append(Vector3(cx - 14.0, 12.0, cz))
	bloc(cx - 8, cx + 8, 12, 59, cz - 8, cz + 8, _gris(0.55), true, false)
	bloc(cx - 10, cx + 10, 59, 59.6, cz - 10, cz + 10, _gris(0.25))
	Etat.batiments.append(Rect2(cx - 8, cz - 8, 16, 16))
	_loot_toit.append([Vector3(cx, 59.6, cz), 14.0, 14.0, 3])


func _parking(cx: float, cz: float) -> void:
	var s := 18.0
	var col := _gris(0.4)
	bloc(cx - s, cx + s, 3.4, 3.8, cz - s, cz + s, col, true, true)             # niveau 1
	bloc(cx, cx + s, 7.0, 7.4, cz - s, cz + s, col)                              # niveau 2 (moitié)
	for px in [-s + 1.0, 0.0, s - 1.0]:
		for pz in [-s + 1.0, 0.0, s - 1.0]:
			bloc(cx + px - 0.5, cx + px + 0.5, 0, 3.4, cz + pz - 0.5, cz + pz + 0.5, col)
	rampe_x(cx - s - 14.0, cx - s, cz, 4.0, 0.0, 3.8, _gris(0.3))               # sol -> niveau 1
	rampe_x(cx - s + 2.0, cx, cz + 8.0, 4.0, 3.8, 7.4, _gris(0.3))              # niveau 1 -> niveau 2
	Etat.batiments.append(Rect2(cx - s, cz - s, s * 2, s * 2))
	for i in 5:                                                                  # voitures
		var x := cx + rng.randf_range(-s + 3.0, s - 3.0)
		var z := cz + rng.randf_range(-s + 3.0, s - 3.0)
		bloc(x - 1.0, x + 1.0, 3.8, 5.0, z - 2.2, z + 2.2, Color.from_hsv(rng.randf(), 0.3, 0.35))
	_loot_toit.append([Vector3(cx + 9.0, 7.4, cz), 14.0, 24.0, 3])
	Etat.toits.append(Vector3(cx + 9.0, 7.4, cz))


func _chantier(cx: float, cz: float) -> void:
	for i in 8:                                                                  # conteneurs (empilables)
		var x := cx + rng.randf_range(-18.0, 18.0)
		var z := cz + rng.randf_range(-18.0, 18.0)
		var c := Color.from_hsv(rng.randf(), 0.5, 0.45)
		bloc(x - 3.0, x + 3.0, 0, 2.6, z - 1.2, z + 1.2, c, true, true, true)
		if rng.randf() < 0.5:
			bloc(x - 3.0, x + 3.0, 2.6, 5.2, z - 1.2, z + 1.2, c, true)
	bloc(cx + 18, cx + 20, 0, 40, cz - 18, cz - 16, Color(0.9, 0.7, 0.1), true, true)    # grue
	bloc(cx - 4, cx + 20, 40, 41.5, cz - 18.5, cz - 16.5, Color(0.9, 0.7, 0.1))
	_loot_toit.append([Vector3(cx, 0.0, cz), 20.0, 20.0, 3])


# ==================================================== détails : balcons, voitures, lampadaires ====
## Balcons : dalles en saillie sur la façade opposée à la rampe (paliers de parkour / wall-run).
func _balcons(x0: float, x1: float, z0: float, z1: float, h: float, cote_rampe: float) -> void:
	# la façade en z opposée à la rampe / à l'escalier reçoit les balcons (sinon ils bloqueraient le passage)
	var zf := z0 if cote_rampe > 0 else z1
	var sg := -1.0 if cote_rampe > 0 else 1.0
	var y := 3.8
	var k := 0
	while y < h - 2.5:
		if k % 2 == 0:
			var cx := (x0 + x1) * 0.5 + rng.randf_range(-6.0, 6.0)
			bloc(cx - 4.0, cx + 4.0, y - 0.3, y, minf(zf, zf + sg * 1.8), maxf(zf, zf + sg * 1.8), _gris(0.5), true, false)
			bloc(cx - 4.0, cx + 4.0, y, y + 0.9, minf(zf + sg * 1.6, zf + sg * 1.8), maxf(zf + sg * 1.6, zf + sg * 1.8), _gris(0.42), true, false)   # garde-corps
		else:
			var cz := (z0 + z1) * 0.5 + rng.randf_range(-5.0, 5.0)
			bloc(x1, x1 + 1.8, y - 0.3, y, cz - 4.0, cz + 4.0, _gris(0.5), true, false)
			bloc(x1 + 1.6, x1 + 1.8, y, y + 0.9, cz - 4.0, cz + 4.0, _gris(0.42), true, false)
		stats["balcons"] += 1
		y += 3.6
		k += 1


func _voitures() -> void:
	var essais := 0
	while stats["voitures"] < 34 and essais < 400:
		essais += 1
		var r: float = ROUTES[rng.randi() % ROUTES.size()]
		var t := rng.randf_range(-165.0, 165.0)
		var le_long_x := rng.randf() < 0.5
		var x := (t if le_long_x else r + rng.randf_range(-3.5, 3.5))
		var z := (r + rng.randf_range(-3.5, 3.5) if le_long_x else t)
		# pas dans un carrefour (on laisse les points d'apparition libres)
		var dans_carrefour := false
		for ax in ROUTES:
			for az in ROUTES:
				if absf(x - ax) < 9.0 and absf(z - az) < 9.0:
					dans_carrefour = true
		if dans_carrefour:
			continue
		var long := 4.4
		var lar := 1.9
		var dx := long if le_long_x else lar
		var dz := lar if le_long_x else long
		var col := Color.from_hsv(rng.randf(), rng.randf_range(0.2, 0.5), rng.randf_range(0.25, 0.5))
		bloc(x - dx * 0.5, x + dx * 0.5, 0.35, 1.0, z - dz * 0.5, z + dz * 0.5, col, true, false, true)     # caisse
		var cdx := (long * 0.45) if le_long_x else (lar * 0.85)
		var cdz := (lar * 0.85) if le_long_x else (long * 0.45)
		bloc(x - cdx * 0.5, x + cdx * 0.5, 1.0, 1.55, z - cdz * 0.5, z + cdz * 0.5, col.darkened(0.3), true, false, true)   # habitacle
		bloc(x - dx * 0.5 + 0.2, x + dx * 0.5 - 0.2, 0.0, 0.35, z - dz * 0.5 + 0.2, z + dz * 0.5 - 0.2, Color(0.05, 0.05, 0.05), true, false, true)  # roues
		Etat.obstacles.append(Rect2(x - dx * 0.5, z - dz * 0.5, dx, dz))
		stats["voitures"] += 1


var _mat_lampe: StandardMaterial3D
var lampes: Array = []                      # lumières à allumer la nuit


func _lampadaires() -> void:
	_mat_lampe = StandardMaterial3D.new()
	_mat_lampe.albedo_color = Color(1, 0.95, 0.7)
	_mat_lampe.emission_enabled = true
	_mat_lampe.emission = Color(1, 0.9, 0.6)
	_mat_lampe.emission_energy_multiplier = 0.0
	Etat.lampes_mat = _mat_lampe
	Etat.lampes.clear()
	for ax in ROUTES:
		for az in ROUTES:
			for c in [Vector2(-7.5, -7.5), Vector2(7.5, 7.5)]:
				_lampadaire(ax + c.x, az + c.y)
	for r in ROUTES:                               # le long des rues, tous les 30 m
		for t in [-90.0, -30.0, 30.0, 90.0]:
			_lampadaire(r + 6.8, t + 15.0)
			_lampadaire(t + 15.0, r - 6.8)


func _lampadaire(x: float, z: float) -> void:
	if not Etat.est_libre(x, z, 0.4):
		return
	cylindre(x, z, 0.14, 6.0, Color(0.15, 0.15, 0.17))
	var tete := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.7, 0.18, 0.4)
	tete.mesh = bm
	tete.material_override = _mat_lampe
	tete.position = Vector3(x, 6.1, z)
	tete.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(tete)
	var l := OmniLight3D.new()
	l.omni_range = 14.0
	l.light_energy = 0.0
	l.light_color = Color(1, 0.9, 0.65)
	l.shadow_enabled = false
	l.position = Vector3(x, 5.6, z)
	add_child(l)
	Etat.lampes.append(l)
	stats["lampadaires"] += 1


# =============================================================== loots ====
func _loots() -> void:
	for e in _loot_toit:
		var pos: Vector3 = e[0]
		for i in int(e[3]):
			var p := pos + Vector3(rng.randf_range(-e[1] * 0.35, e[1] * 0.35), 0.1, rng.randf_range(-e[2] * 0.35, e[2] * 0.35))
			_poser_loot(p, LOOT_TOIT[rng.randi() % LOOT_TOIT.size()])
	for i in 50:                                                                  # au sol, dans les rues
		var p := Etat.point_libre(1.0)
		_poser_loot(Vector3(p.x, 0.0, p.z), "")


func _poser_loot(p: Vector3, type: String) -> void:
	var l := Loot.creer(p, type, false)
	Etat.racine_loots.add_child(l)
