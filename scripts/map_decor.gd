class_name MapDecor
extends RefCounted
## Décor : grand parc avec étang (2 x 2 pâtés), petits parcs, place avec fontaine, épaves de voitures
## accidentées, bus, barrières, sacs de sable, bennes, caisses... = couvertures et variété.

const VERT := Color(0.16, 0.27, 0.13)
const CHEMIN := Color(0.46, 0.42, 0.34)


# ------------------------------------------------------------- utilitaires ----
## Pose une boîte et enregistre son empreinte (pas de spawn dessus, cherchée comme couverture par les bots).
static func objet(m: MapBuilder, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float,
		col: Color, destructible := false, empreinte := true) -> void:
	m.bloc(x0, x1, y0, y1, z0, z1, col, true, empreinte, destructible)


static func _libre_rect(x0: float, x1: float, z0: float, z1: float, marge := 0.6) -> bool:
	var r := Rect2(x0, z0, x1 - x0, z1 - z0).grow(marge)
	var lim := Etat.DEMI_MAP - 4.0
	if absf(r.position.x) > lim or absf(r.position.y) > lim or absf(r.end.x) > lim or absf(r.end.y) > lim:
		return false
	for o in Etat.obstacles:
		if o.intersects(r):
			return false
	return true


static func arbre(m: MapBuilder, x: float, z: float, vivant := true) -> void:
	var h := m.rng.randf_range(4.0, 6.5)
	m.cylindre(x, z, 0.35, h, Color(0.25, 0.17, 0.1))
	if vivant:
		var c := Color.from_hsv(m.rng.randf_range(0.22, 0.32), 0.55, m.rng.randf_range(0.22, 0.34))
		var s := m.rng.randf_range(2.0, 2.8)
		m.bloc(x - s, x + s, h - 0.8, h + 2.6, z - s, z + s, c, false, false)
		m.bloc(x - s * 0.6, x + s * 0.6, h + 2.6, h + 3.6, z - s * 0.6, z + s * 0.6, c.lightened(0.08), false, false)
	m.stats["arbres"] += 1


static func banc(m: MapBuilder, x: float, z: float, le_long_x: bool) -> void:
	var lx := 1.0 if le_long_x else 0.3
	var lz := 0.3 if le_long_x else 1.0
	objet(m, x - lx, x + lx, 0.0, 0.55, z - lz, z + lz, Color(0.35, 0.22, 0.12))
	if le_long_x:
		m.bloc(x - lx, x + lx, 0.55, 1.0, z - lz, z - lz + 0.12, Color(0.3, 0.18, 0.1), true, false)
	else:
		m.bloc(x - lx, x - lx + 0.12, 0.55, 1.0, z - lz, z + lz, Color(0.3, 0.18, 0.1), true, false)


## Étang : disque d'eau peu profonde (ralentit), berge de sable, île avec arbres, ponton.
static func etang(m: MapBuilder, cx: float, cz: float, rayon: float, ponton := true) -> void:
	var sable := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = rayon + 1.6
	cm.bottom_radius = rayon + 1.6
	cm.height = 0.05
	sable.mesh = cm
	sable.material_override = m._mat(Color(0.55, 0.5, 0.36))
	sable.position = Vector3(cx, 0.11, cz)
	m.add_child(sable)
	var eau := MeshInstance3D.new()
	var wm := CylinderMesh.new()
	wm.top_radius = rayon
	wm.bottom_radius = rayon
	wm.height = 0.05
	eau.mesh = wm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.3, 0.45, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.1
	mat.metallic = 0.3
	eau.material_override = mat
	eau.position = Vector3(cx, 0.15, cz)
	eau.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.add_child(eau)
	Etat.eau_zones.append([Vector2(cx, cz), rayon])
	Etat.obstacles.append(Rect2(cx - rayon, cz - rayon, rayon * 2.0, rayon * 2.0))   # pas de spawn dans l'eau
	m.stats["etangs"] += 1
	if rayon >= 9.0:                                   # île centrale
		m.bloc(cx - 3.5, cx + 3.5, 0.0, 0.3, cz - 3.5, cz + 3.5, VERT.lightened(0.1), true, false)
		arbre(m, cx - 1.2, cz + 0.5)
		arbre(m, cx + 1.5, cz - 1.0)
	if ponton:
		var x_deb := cx + rayon + 1.4
		m.bloc(cx + 3.6, x_deb, 0.35, 0.6, cz - 1.4, cz + 1.4, Color(0.35, 0.24, 0.14), true, false)
		for i in 5:
			var x := cx + 4.0 + i * ((x_deb - cx - 4.0) / 4.0)
			m.bloc(x - 0.12, x + 0.12, 0.6, 1.4, cz - 1.4, cz - 1.2, Color(0.3, 0.2, 0.12), true, false)
			m.bloc(x - 0.12, x + 0.12, 0.6, 1.4, cz + 1.2, cz + 1.4, Color(0.3, 0.2, 0.12), true, false)
	# roseaux / rochers sur la berge
	for i in 10:
		var a := m.rng.randf_range(0.0, TAU)
		var rr := rayon + m.rng.randf_range(0.4, 1.6)
		var rx := cx + cos(a) * rr
		var rz := cz + sin(a) * rr
		var s := m.rng.randf_range(0.4, 0.9)
		m.bloc(rx - s, rx + s, 0.0, s * 1.2, rz - s, rz + s, Color(0.38, 0.38, 0.36), true, false, false)


## GRAND PARC (2 x 2 pâtés, 108 x 108 m) : allées, grand étang avec île et ponton, bois, gloriette,
## aire de jeux, haies-chicanes. Recouvre les rues du milieu.
static func grand_parc(m: MapBuilder, cx: float, cz: float) -> void:
	var h := 54.0
	m.bloc(cx - h, cx + h, 0.0, 0.09, cz - h, cz + h, VERT, false, false)
	# allées en croix et en anneau
	m.bloc(cx - h, cx + h, 0.09, 0.11, cz - 2.2, cz + 2.2, CHEMIN, false, false)
	m.bloc(cx - 2.2, cx + 2.2, 0.09, 0.11, cz - h, cz + h, CHEMIN, false, false)
	# étang dans le quart nord-ouest, ponton vers le centre
	var ex := cx - 27.0
	var ez := cz - 27.0
	etang(m, ex, ez, 15.0, true)
	# gloriette au centre (4 colonnes + toit)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			m.cylindre(cx + sx * 3.2, cz + sz * 3.2, 0.3, 3.4, Color(0.8, 0.8, 0.78))
	m.bloc(cx - 4.5, cx + 4.5, 3.4, 3.7, cz - 4.5, cz + 4.5, Color(0.55, 0.2, 0.18), true, false)
	m.bloc(cx - 3.8, cx + 3.8, 0.0, 0.3, cz - 3.8, cz + 3.8, Color(0.7, 0.7, 0.68), true, false)
	Etat.batiments.append(Rect2(cx - 4.5, cz - 4.5, 9.0, 9.0))
	# bois : arbres hors allées, hors étang
	var n := 0
	var essais := 0
	while n < 60 and essais < 400:
		essais += 1
		var x := cx + m.rng.randf_range(-h + 4.0, h - 4.0)
		var z := cz + m.rng.randf_range(-h + 4.0, h - 4.0)
		if absf(x - cx) < 5.0 or absf(z - cz) < 5.0:
			continue
		if Vector2(x - ex, z - ez).length() < 20.0:
			continue
		if absf(x - cx) < 9.0 and absf(z - cz) < 9.0:
			continue
		if not _libre_rect(x - 0.6, x + 0.6, z - 0.6, z + 0.6, 1.2):
			continue
		arbre(m, x, z, m.rng.randf() < 0.85)
		n += 1
	# bancs le long des allées
	for i in 10:
		var t := m.rng.randf_range(-h + 8.0, h - 8.0)
		var cote := 3.6 if m.rng.randf() < 0.5 else -3.6
		if m.rng.randf() < 0.5:
			if _libre_rect(cx + t - 1.1, cx + t + 1.1, cz + cote - 0.4, cz + cote + 0.4, 0.2) and Vector2(cx + t - ex, cz + cote - ez).length() > 18.0:
				banc(m, cx + t, cz + cote, true)
		else:
			if _libre_rect(cx + cote - 0.4, cx + cote + 0.4, cz + t - 1.1, cz + t + 1.1, 0.2) and Vector2(cx + cote - ex, cz + t - ez).length() > 18.0:
				banc(m, cx + cote, cz + t, false)
	# aire de jeux (quart sud-est) : plateforme, toboggan (rampe), murets
	var jx := cx + 28.0
	var jz := cz + 28.0
	m.bloc(jx - 12.0, jx + 12.0, 0.09, 0.14, jz - 12.0, jz + 12.0, Color(0.6, 0.25, 0.2), false, false)
	m.bloc(jx - 2.0, jx + 2.0, 0.0, 2.4, jz - 2.0, jz + 2.0, Color(0.2, 0.4, 0.7), true, true)
	m.rampe_x(jx + 2.0, jx + 9.0, jz, 2.0, 0.0, 2.4, Color(0.85, 0.7, 0.15))
	m.rampe_x(jx - 2.0, jx - 8.0, jz, 2.4, 0.0, 2.4, Color(0.3, 0.7, 0.3))
	for i in 3:
		objet(m, jx - 9.0 + i * 8.0, jx - 7.0 + i * 8.0, 0.0, 1.0, jz + 8.0, jz + 8.6, Color(0.5, 0.35, 0.2))
	# haies-chicanes (couvertures végétales)
	for i in 7:
		var hx := cx + m.rng.randf_range(-h + 8.0, h - 8.0)
		var hz := cz + m.rng.randf_range(-h + 8.0, h - 8.0)
		var le_long_x := m.rng.randf() < 0.5
		var lx := 3.5 if le_long_x else 0.6
		var lz := 0.6 if le_long_x else 3.5
		if absf(hx - cx) < 6.0 or absf(hz - cz) < 6.0 or Vector2(hx - ex, hz - ez).length() < 20.0:
			continue
		if _libre_rect(hx - lx, hx + lx, hz - lz, hz + lz, 0.5):
			objet(m, hx - lx, hx + lx, 0.0, 1.3, hz - lz, hz + lz, Color(0.12, 0.3, 0.1))
	m._loot_toit.append([Vector3(cx + 12.0, 0.1, cz + 12.0), 10.0, 10.0, 3])
	m._loot_toit.append([Vector3(cx - 12.0, 0.1, cz + 14.0), 10.0, 10.0, 2])


## Petit parc : bois clairsemé, bancs, parfois un étang.
static func petit_parc(m: MapBuilder, cx: float, cz: float) -> void:
	m.bloc(cx - 23.0, cx + 23.0, 0.0, 0.09, cz - 23.0, cz + 23.0, VERT, false, false)
	m.bloc(cx - 23.0, cx + 23.0, 0.09, 0.11, cz - 1.5, cz + 1.5, CHEMIN, false, false)
	var avec_etang := m.rng.randf() < 0.55
	if avec_etang:
		etang(m, cx - 8.0, cz - 8.0, 8.0, false)
	var n := 0
	var essais := 0
	while n < 14 and essais < 120:
		essais += 1
		var x := cx + m.rng.randf_range(-20.0, 20.0)
		var z := cz + m.rng.randf_range(-20.0, 20.0)
		if absf(z - cz) < 3.0 or (avec_etang and Vector2(x - (cx - 8.0), z - (cz - 8.0)).length() < 12.0):
			continue
		if _libre_rect(x - 0.6, x + 0.6, z - 0.6, z + 0.6, 1.0):
			arbre(m, x, z, m.rng.randf() < 0.75)
			n += 1
	for i in 3:
		var bx := cx + m.rng.randf_range(-16.0, 16.0)
		if _libre_rect(bx - 1.1, bx + 1.1, cz + 2.4 - 0.4, cz + 2.4 + 0.4, 0.2):
			banc(m, bx, cz + 2.4, true)
	m._loot_toit.append([Vector3(cx + 10.0, 0.1, cz + 8.0), 8.0, 8.0, 2])


## Place : fontaine, étals de marché, kiosques, jardinières (beaucoup de couvertures basses).
static func place(m: MapBuilder, cx: float, cz: float) -> void:
	m.bloc(cx - 23.0, cx + 23.0, 0.0, 0.07, cz - 23.0, cz + 23.0, Color(0.42, 0.4, 0.36), false, false)
	m.bloc(cx - 5.0, cx + 5.0, 0.0, 0.9, cz - 5.0, cz + 5.0, Color(0.6, 0.6, 0.62), true, true)
	m.bloc(cx - 4.2, cx + 4.2, 0.9, 0.95, cz - 4.2, cz + 4.2, Color(0.1, 0.3, 0.45), false, false)
	m.cylindre(cx, cz, 0.6, 3.0, Color(0.7, 0.7, 0.72))
	for i in 6:                                                              # étals
		var x := cx + m.rng.randf_range(-19.0, 19.0)
		var z := cz + m.rng.randf_range(-19.0, 19.0)
		if _libre_rect(x - 1.6, x + 1.6, z - 1.0, z + 1.0, 0.8):
			objet(m, x - 1.5, x + 1.5, 0.0, 1.0, z - 0.8, z + 0.8, Color.from_hsv(m.rng.randf(), 0.5, 0.45), true)
			for sx in [-1.5, 1.4]:
				m.bloc(x + sx, x + sx + 0.1, 1.0, 2.6, z - 0.8, z - 0.7, Color(0.3, 0.2, 0.1), false, false)
			m.bloc(x - 1.7, x + 1.7, 2.6, 2.75, z - 1.0, z + 1.0, Color.from_hsv(m.rng.randf(), 0.6, 0.55), false, false)
	for i in 8:                                                              # jardinières / bancs de pierre
		var x := cx + m.rng.randf_range(-20.0, 20.0)
		var z := cz + m.rng.randf_range(-20.0, 20.0)
		if _libre_rect(x - 1.5, x + 1.5, z - 0.6, z + 0.6, 0.6):
			objet(m, x - 1.4, x + 1.4, 0.0, 0.9, z - 0.5, z + 0.5, Color(0.5, 0.5, 0.48))
	m._loot_toit.append([Vector3(cx, 0.1, cz + 9.0), 12.0, 6.0, 3])


# ------------------------------------------------------------------ épaves ----
## Carcasse de voiture : caisse + habitacle, inclinée / retournée. `feu` : lueur orange.
static func epave(m: MapBuilder, x: float, z: float, yaw_deg: float, roll_deg: float, pitch_deg: float,
		col: Color, feu := false) -> void:
	var corps := StaticBody3D.new()
	corps.collision_layer = Etat.COUCHE_MONDE
	corps.collision_mask = 0
	corps.add_to_group("destructible")
	var haut := 0.5 * absf(cos(deg_to_rad(roll_deg))) + 0.95 * absf(sin(deg_to_rad(roll_deg))) + 2.2 * absf(sin(deg_to_rad(pitch_deg)))
	corps.position = Vector3(x, haut + 0.05, z)
	corps.rotation = Vector3(deg_to_rad(pitch_deg), deg_to_rad(yaw_deg), deg_to_rad(roll_deg))
	var pieces := [
		[Vector3(1.9, 0.75, 4.4), Vector3(0, 0.0, 0), col],
		[Vector3(1.7, 0.6, 2.2), Vector3(0, 0.65, 0.2), col.darkened(0.35)],
		[Vector3(1.9, 0.18, 0.3), Vector3(0, -0.2, -2.1), Color(0.08, 0.08, 0.08)],
	]
	for p in pieces:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = p[0]
		mi.mesh = bm
		mi.material_override = m._mat(p[2])
		mi.position = p[1]
		corps.add_child(mi)
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = p[0]
		cs.shape = sh
		cs.position = p[1]
		corps.add_child(cs)
	m.add_child(corps)
	if feu:
		var l := OmniLight3D.new()
		l.omni_range = 9.0
		l.light_energy = 1.1
		l.light_color = Color(1, 0.5, 0.15)
		l.position = Vector3(x, 2.0, z)
		m.add_child(l)
		var fl := MeshInstance3D.new()
		var fm := BoxMesh.new()
		fm.size = Vector3(0.9, 0.7, 0.9)
		fl.mesh = fm
		var fmat := StandardMaterial3D.new()
		fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fmat.albedo_color = Color(1, 0.45, 0.1)
		fl.material_override = fmat
		fl.position = Vector3(x, haut + 0.6, z)
		fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.add_child(fl)
	var r := 3.0
	Etat.obstacles.append(Rect2(x - r, z - r, r * 2.0, r * 2.0))
	m.stats["epaves"] += 1
	m.epaves_pos.append(Vector3(x, 0, z))


static func epaves(m: MapBuilder) -> void:
	var rng := m.rng
	var carbone := [Color(0.1, 0.1, 0.1), Color(0.18, 0.1, 0.08), Color(0.2, 0.2, 0.22), Color(0.3, 0.12, 0.1), Color(0.14, 0.18, 0.22)]
	# 1) carambolages aux carrefours (3 voitures emboutis, un peu en retrait du centre)
	for ax in MapBuilder.ROUTES:
		for az in MapBuilder.ROUTES:
			if rng.randf() < 0.45:
				var ox: float = [-1.0, 1.0][rng.randi() % 2] * 15.0
				var oz: float = [-1.0, 1.0][rng.randi() % 2] * 15.0
				var base := Vector2(ax + ox, az + oz)
				for i in 3:
					var p := base + Vector2(rng.randf_range(-3.0, 3.0), rng.randf_range(-3.0, 3.0))
					if _libre_rect(p.x - 2.5, p.x + 2.5, p.y - 2.5, p.y + 2.5, 0.3):
						epave(m, p.x, p.y, rng.randf_range(0.0, 360.0), [0.0, 0.0, 0.0, 90.0, 180.0, 25.0][rng.randi() % 6], rng.randf_range(-8.0, 8.0),
								carbone[rng.randi() % carbone.size()], i == 0 and rng.randf() < 0.5)
	# 2) voitures encastrées dans les bâtiments
	var bats: Array = Etat.batiments.duplicate()
	bats.shuffle()
	var n := 0
	for b in bats:
		if n >= 8 or b.size.x > 45.0:
			continue
		var cote := rng.randi() % 4
		var p := Vector2.ZERO
		var yaw := 0.0
		match cote:
			0:
				p = Vector2(b.position.x + rng.randf_range(2.0, b.size.x - 2.0), b.position.y - 2.9)
				yaw = 0.0
			1:
				p = Vector2(b.position.x + rng.randf_range(2.0, b.size.x - 2.0), b.end.y + 2.9)
				yaw = 0.0
			2:
				p = Vector2(b.position.x - 2.9, b.position.y + rng.randf_range(2.0, b.size.y - 2.0))
				yaw = 90.0
			_:
				p = Vector2(b.end.x + 2.9, b.position.y + rng.randf_range(2.0, b.size.y - 2.0))
				yaw = 90.0
		if _libre_rect(p.x - 2.5, p.x + 2.5, p.y - 2.5, p.y + 2.5, 0.2):
			epave(m, p.x, p.y, yaw, 0.0, rng.randf_range(4.0, 12.0), carbone[rng.randi() % carbone.size()], rng.randf() < 0.3)
			n += 1


# ------------------------------------------------------------ couvertures ----
static func bus(m: MapBuilder, x: float, z: float, le_long_x: bool, renverse := false) -> void:
	var lx := 5.2 if le_long_x else 1.4
	var lz := 1.4 if le_long_x else 5.2
	var col := Color.from_hsv(m.rng.randf_range(0.0, 0.14), 0.5, 0.45)
	if renverse:
		var hh := 1.4 if le_long_x else 1.4
		objet(m, x - (lx if le_long_x else 2.8), x + (lx if le_long_x else 2.8), 0.0, 2.8, z - (2.8 if le_long_x else lz), z + (2.8 if le_long_x else lz), col, false)
	else:
		objet(m, x - lx, x + lx, 0.3, 3.2, z - lz, z + lz, col, false)
		objet(m, x - lx + 0.1, x + lx - 0.1, 1.8, 2.7, z - lz - (0.02 if le_long_x else 0.0), z + lz + (0.02 if le_long_x else 0.0), Color(0.08, 0.1, 0.14), false, false)


static func barriere(m: MapBuilder, x: float, z: float, le_long_x: bool) -> void:
	var lx := 1.6 if le_long_x else 0.4
	var lz := 0.4 if le_long_x else 1.6
	objet(m, x - lx, x + lx, 0.0, 0.95, z - lz, z + lz, Color(0.55, 0.55, 0.52))


static func sacs(m: MapBuilder, x: float, z: float, le_long_x: bool) -> void:
	var lx := 1.4 if le_long_x else 0.5
	var lz := 0.5 if le_long_x else 1.4
	objet(m, x - lx, x + lx, 0.0, 1.0, z - lz, z + lz, Color(0.45, 0.4, 0.28))


static func benne(m: MapBuilder, x: float, z: float, le_long_x: bool) -> void:
	var lx := 1.3 if le_long_x else 0.75
	var lz := 0.75 if le_long_x else 1.3
	objet(m, x - lx, x + lx, 0.0, 1.35, z - lz, z + lz, Color(0.12, 0.3, 0.16), true)


static func caisses(m: MapBuilder, x: float, z: float) -> void:
	objet(m, x - 0.6, x + 0.6, 0.0, 1.2, z - 0.6, z + 0.6, Color(0.4, 0.28, 0.15), true)
	if m.rng.randf() < 0.6:
		objet(m, x - 0.5, x + 0.5, 1.2, 2.3, z - 0.5, z + 0.5, Color(0.36, 0.25, 0.14), true, false)
	if m.rng.randf() < 0.5:
		objet(m, x + 0.6, x + 1.8, 0.0, 1.2, z - 0.6, z + 0.6, Color(0.42, 0.3, 0.16), true)


static func couvertures(m: MapBuilder) -> void:
	var rng := m.rng
	var essais := 0
	var n := 0
	# le long des rues (en dehors des carrefours)
	while n < 120 and essais < 1200:
		essais += 1
		var r: float = MapBuilder.ROUTES[rng.randi() % MapBuilder.ROUTES.size()]
		var t := rng.randf_range(-168.0, 168.0)
		var le_long_x := rng.randf() < 0.5
		var off := rng.randf_range(-5.2, 5.2)
		var x := t if le_long_x else r + off
		var z := r + off if le_long_x else t
		var dans_carrefour := false
		for ax in MapBuilder.ROUTES:
			for az in MapBuilder.ROUTES:
				if absf(x - ax) < 10.0 and absf(z - az) < 10.0:
					dans_carrefour = true
		if dans_carrefour:
			continue
		var k := rng.randi() % 100
		if k < 26 and _libre_rect(x - 1.7, x + 1.7, z - 1.7, z + 1.7, 0.5):
			barriere(m, x, z, le_long_x)
			if rng.randf() < 0.7:                                # chicane : 2e barrière décalée
				var dx := 4.2 if le_long_x else 0.0
				var dz := 0.0 if le_long_x else 4.2
				if _libre_rect(x + dx - 1.7, x + dx + 1.7, z + dz - 1.7, z + dz + 1.7, 0.5):
					barriere(m, x + dx + (0.0 if le_long_x else 1.0), z + dz + (1.0 if le_long_x else 0.0), le_long_x)
			n += 1
		elif k < 46 and _libre_rect(x - 1.6, x + 1.6, z - 1.6, z + 1.6, 0.5):
			sacs(m, x, z, le_long_x)
			sacs(m, x + (1.2 if not le_long_x else 0.0), z + (1.2 if le_long_x else 0.0), not le_long_x)
			n += 1
		elif k < 62 and _libre_rect(x - 1.6, x + 1.6, z - 1.6, z + 1.6, 0.5):
			benne(m, x, z, le_long_x)
			n += 1
		elif k < 82 and _libre_rect(x - 2.3, x + 2.3, z - 2.3, z + 2.3, 0.5):
			caisses(m, x, z)
			n += 1
		elif k < 92 and _libre_rect(x - 6.0, x + 6.0, z - 2.0, z + 2.0, 0.5) and le_long_x:
			bus(m, x, z, true, false)
			n += 1
		elif k >= 92 and _libre_rect(x - 3.2, x + 3.2, z - 6.0, z + 6.0, 0.5):
			bus(m, x, z, false, true)                            # bus renversé en travers
			n += 1
	m.stats["couvertures"] += n


## Décor dans les pâtés « ordinaires » : de quoi se couvrir autour des bâtiments.
static func decor_bloc(m: MapBuilder, cx: float, cz: float, n := 9) -> void:
	var rng := m.rng
	var essais := 0
	var pose := 0
	while pose < n and essais < 80:
		essais += 1
		var x := cx + rng.randf_range(-22.0, 22.0)
		var z := cz + rng.randf_range(-22.0, 22.0)
		var le_long_x := rng.randf() < 0.5
		var k := rng.randi() % 5
		if k == 0 and _libre_rect(x - 1.8, x + 1.8, z - 1.8, z + 1.8, 0.6):
			caisses(m, x, z)
		elif k == 1 and _libre_rect(x - 1.8, x + 1.8, z - 1.8, z + 1.8, 0.6):
			benne(m, x, z, le_long_x)
		elif k == 2 and _libre_rect(x - 1.8, x + 1.8, z - 1.8, z + 1.8, 0.6):
			barriere(m, x, z, le_long_x)
		elif k == 3 and _libre_rect(x - 1.2, x + 1.2, z - 1.2, z + 1.2, 0.8):
			arbre(m, x, z, rng.randf() < 0.7)
		elif k == 4 and _libre_rect(x - 1.8, x + 1.8, z - 1.8, z + 1.8, 0.6):
			sacs(m, x, z, le_long_x)
		else:
			continue
		pose += 1
	m.stats["couvertures"] += pose
