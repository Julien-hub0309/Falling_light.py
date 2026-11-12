class_name MapBatiments
extends RefCounted
## Bâtiments ENTRABLES : maisons, immeubles et grande tour. Murs avec portes et fenêtres, étages
## (dalles percées pour l'escalier), escalier intérieur en zigzag, cloison, mobilier de couverture,
## lumières. Les ouvertures laissent passer les tirs, le grappin et les joueurs.

const EP := 0.4          # épaisseur des murs
const DALLE := 0.3       # épaisseur des planchers


# --------------------------------------------------------------------- murs ----
## Découpe un mur en segments autour des ouvertures [centre, largeur, y_bas, y_haut].
static func _mur(a0: float, a1: float, y0: float, y1: float, ouv: Array, f: Callable) -> void:
	var tri := ouv.duplicate()
	tri.sort_custom(func(p, q): return p[0] < q[0])
	var cur := a0
	for o in tri:
		var s: float = maxf(o[0] - o[1] * 0.5, a0 + 0.3)
		var e: float = minf(o[0] + o[1] * 0.5, a1 - 0.3)
		if s > cur:
			f.call(cur, s, y0, y1)
		if o[2] > y0:
			f.call(s, e, y0, o[2])                    # allège sous la fenêtre
		if o[3] < y1:
			f.call(s, e, o[3], y1)                    # linteau
		cur = e
	if cur < a1:
		f.call(cur, a1, y0, y1)


static func mur_x(m: MapBuilder, x0: float, x1: float, z0: float, z1: float, y0: float, y1: float,
		col: Color, ouv: Array = []) -> void:
	_mur(x0, x1, y0, y1, ouv, func(a, b, ya, yb): m.bloc(a, b, ya, yb, z0, z1, col, true, false))


static func mur_z(m: MapBuilder, z0: float, z1: float, x0: float, x1: float, y0: float, y1: float,
		col: Color, ouv: Array = []) -> void:
	_mur(z0, z1, y0, y1, ouv, func(a, b, ya, yb): m.bloc(x0, x1, ya, yb, a, b, col, true, false))


## Plancher percé : 4 dalles autour du trou (Rect2 en x, z).
static func dalle(m: MapBuilder, ix0: float, ix1: float, iz0: float, iz1: float, y: float, trou: Rect2, col: Color) -> void:
	var hx0 := trou.position.x
	var hx1 := trou.end.x
	var hz0 := trou.position.y
	var hz1 := trou.end.y
	if hx0 > ix0:
		m.bloc(ix0, hx0, y - DALLE, y, iz0, iz1, col, true, false)
	if hx1 < ix1:
		m.bloc(hx1, ix1, y - DALLE, y, iz0, iz1, col, true, false)
	if hz0 > iz0:
		m.bloc(hx0, hx1, y - DALLE, y, iz0, hz0, col, true, false)
	if hz1 < iz1:
		m.bloc(hx0, hx1, y - DALLE, y, hz1, iz1, col, true, false)


static func _lumiere(m: MapBuilder, pos: Vector3, portee := 11.0) -> void:
	var l := OmniLight3D.new()
	l.omni_range = portee
	l.light_energy = 0.55
	l.light_color = Color(1, 0.93, 0.8)
	l.shadow_enabled = false
	l.position = pos
	m.add_child(l)
	Etat.lumieres_int.append(l)


# --------------------------------------------------------------- bâtiment ----
## Bâtiment à `etages` niveaux de hauteur `hf`. Porte sur la face +z ; escalier au fond (z0).
## Retourne le centre du toit.
static func batiment(m: MapBuilder, x0: float, x1: float, z0: float, z1: float, etages: int, hf: float,
		col: Color, fenetres := 2, cloison := true, mobilier := true, toit_loot := 2) -> Vector3:
	var rng := m.rng
	var w := x1 - x0
	var d := z1 - z0
	var H := hf * etages
	var cx := (x0 + x1) * 0.5
	var cz := (z0 + z1) * 0.5
	var ix0 := x0 + EP
	var ix1 := x1 - EP
	var iz0 := z0 + EP
	var iz1 := z1 - EP
	var col_int := col.lightened(0.18)
	var col_sol := col.darkened(0.45)                                 # planchers plus sombres : meilleur contraste
	# --- murs, étage par étage (fenêtres décalées d'un étage à l'autre pour la variété)
	var px := cx + rng.randf_range(-w * 0.12, w * 0.12)              # centre de la porte
	for k in etages:
		var ya := hf * k
		var yb := hf * (k + 1)
		var ouv_x: Array = []
		var ouv_z: Array = []
		for i in fenetres:
			var f := (i + 1.0) / (fenetres + 1.0)
			ouv_x.append([x0 + w * f, 2.0, ya + 1.0, ya + 2.5])
			ouv_z.append([z0 + d * f, 2.0, ya + 1.0, ya + 2.5])
		var ouv_av: Array = ouv_x
		if k == 0:
			ouv_av = [[px, 2.8, 0.0, 2.7]]                           # porte (+ fenêtres si la place le permet)
			for o in ouv_x:
				if absf(o[0] - px) > 3.6:
					ouv_av.append(o)
		mur_x(m, x0, x1, z1 - EP, z1, ya, yb, col, ouv_av)           # façade avant (+z)
		mur_x(m, x0, x1, z0, z0 + EP, ya, yb, col, ouv_x)            # façade arrière (-z)
		mur_z(m, z0 + EP, z1 - EP, x0, x0 + EP, ya, yb, col, ouv_z)  # côtés
		mur_z(m, z0 + EP, z1 - EP, x1 - EP, x1, ya, yb, col, ouv_z)
	# --- escalier intérieur en zigzag, au fond, collé au mur arrière
	var st := m.escalier_zigzag(ix0, iz0, 1.0, H, col_sol.lightened(0.12), 2.8, 6.5, hf * 0.5 + 0.01, 3.6, false)
	var trou: Rect2 = st["trou"]
	var lp: float = st["lp"]
	# --- planchers (et toit) percés pour l'escalier
	for k in range(1, etages + 1):
		dalle(m, ix0, ix1, iz0, iz1, hf * k, trou, col_sol)
	# --- garde-corps du trou au toit + parapet
	var yr := H
	m.bloc(trou.position.x, trou.end.x, yr, yr + 1.0, trou.end.y - 0.2, trou.end.y, col_int, true, false)
	m.bloc(trou.end.x - 0.2, trou.end.x, yr, yr + 1.0, trou.position.y, trou.end.y, col_int, true, false)
	m.bloc(x0, x1, yr, yr + 1.0, z1 - 0.3, z1, col, true, false)
	m.bloc(x0, x1, yr, yr + 1.0, z0, z0 + 0.3, col, true, false)
	m.bloc(x0, x0 + 0.3, yr, yr + 1.0, z0, z1, col, true, false)
	m.bloc(x1 - 0.3, x1, yr, yr + 1.0, z0, z1, col, true, false)
	# --- cloison avec porte + mobilier, étage par étage
	var zone_esc := Rect2(ix0, iz0, 6.5 + 7.2, lp).grow(1.3)
	var zone_porte := Rect2(px - 2.2, iz1 - 3.0, 4.4, 3.0)
	for k in etages:
		var y := hf * k
		var zone_cloison := Rect2(0, 0, 0, 0)
		if cloison and (iz1 - iz0 - lp) >= 9.0:
			var zp := iz0 + lp + (iz1 - iz0 - lp) * rng.randf_range(0.4, 0.6)
			var dx := rng.randf_range(ix0 + 4.0, ix1 - 4.0)
			var ouv_c: Array = [[dx, 2.4, y, y + 2.6]]
			mur_x(m, ix0, ix1, zp - 0.15, zp + 0.15, y, y + hf - DALLE, col_int, ouv_c)
			zone_cloison = Rect2(dx - 2.2, zp - 1.8, 4.4, 3.6)                    # la porte de la cloison reste libre
		if mobilier:
			var n := rng.randi_range(2, 5)
			for i in n:
				var fx := rng.randf_range(ix0 + 1.0, ix1 - 1.0)
				var fz := rng.randf_range(iz0 + 1.0, iz1 - 1.0)
				var tx := rng.randf_range(0.9, 2.0)
				var tz := rng.randf_range(0.7, 1.6)
				var th: float = [0.8, 1.0, 1.8][rng.randi() % 3]
				var r2 := Rect2(fx - tx * 0.5, fz - tz * 0.5, tx, tz)
				if zone_esc.intersects(r2) or (k == 0 and zone_porte.intersects(r2)) \
						or (zone_cloison.size.x > 0.0 and zone_cloison.intersects(r2)):
					continue
				m.bloc(fx - tx * 0.5, fx + tx * 0.5, y, y + th, fz - tz * 0.5, fz + tz * 0.5,
						Color.from_hsv(rng.randf_range(0.05, 0.12), 0.35, rng.randf_range(0.25, 0.45)), true, false, true)
		_lumiere(m, Vector3(cx, y + hf - 0.6, iz1 - 3.0))
		if w >= 20.0:
			_lumiere(m, Vector3(cx, y + hf - 0.6, iz0 + lp + 2.0))
		# un loot par étage, dans les pièces avant
		m._loot_toit.append([Vector3(cx, y + 0.1, iz1 - 3.0), w * 0.3, 1.5, 1])
	m._loot_toit.append([Vector3(cx, H + 0.1, iz1 - 3.0), w * 0.3, 1.5, toit_loot])
	# --- bookkeeping : empreinte (spawn / couverture des bots), mini-carte, toit accessible
	Etat.obstacles.append(Rect2(x0, z0, w, d))
	Etat.obstacles.append(Rect2(px - 2.8, z1, 5.6, 6.0))          # porche : rien ne doit boucher la porte
	Etat.batiments.append(Rect2(x0, z0, w, d))
	Etat.toits.append(Vector3(cx, H, iz1 - 3.0))
	m.stats["interieurs"] += 1
	m.interieurs.append([x0, x1, z0, z1, etages, hf, px])
	return Vector3(cx, H, cz)


## Maison : 2 étages, ~15 x 13 m.
static func maison(m: MapBuilder, cx: float, cz: float, col: Color) -> void:
	var w := m.rng.randf_range(15.5, 17.0)
	var d := m.rng.randf_range(13.5, 15.0)
	batiment(m, cx - w * 0.5, cx + w * 0.5, cz - d * 0.5, cz + d * 0.5, 2, 3.6, col, 2, true, true, 1)
	m.stats["maisons"] += 1
	# petit auvent devant la porte et cheminée
	m.bloc(cx - 2.0, cx + 2.0, 3.0, 3.2, cz + d * 0.5, cz + d * 0.5 + 1.8, col.darkened(0.2), true, false)
	m.bloc(cx + w * 0.25, cx + w * 0.25 + 1.0, 7.2, 8.8, cz - d * 0.25, cz - d * 0.25 + 1.0, Color(0.35, 0.22, 0.18), true, false)


## Lotissement : 4 maisons entrables, séparées par des ruelles et reliées par des passerelles de toit.
static func lotissement(m: MapBuilder, cx: float, cz: float) -> void:
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			maison(m, cx + sx * 12.5, cz + sz * 12.5, m._teinte(0.5))
	# passerelles de toit (toits à 7,2 m)
	m.bloc(cx - 5.0, cx + 5.0, 6.9, 7.2, cz - 13.5, cz - 11.5, Color(0.3, 0.3, 0.32))
	m.bloc(cx - 5.0, cx + 5.0, 6.9, 7.2, cz + 11.5, cz + 13.5, Color(0.3, 0.3, 0.32))


## Immeuble entrable (3 à 5 étages).
static func immeuble(m: MapBuilder, cx: float, cz: float) -> void:
	var w := m.rng.randf_range(24.0, 32.0)
	var d := m.rng.randf_range(20.0, 24.0)
	var n := m.rng.randi_range(3, 5)
	batiment(m, cx - w * 0.5, cx + w * 0.5, cz - d * 0.5, cz + d * 0.5, n, 3.6, m._teinte(0.45), 3, true, true, 3)


## GRANDE TOUR de 59 m : l'intérieur est le SEUL accès (aucune rampe, aucun balcon).
static func tour(m: MapBuilder, cx: float, cz: float) -> void:
	var etages := 16
	var hf := 59.0 / etages
	batiment(m, cx - 12.0, cx + 12.0, cz - 12.0, cz + 12.0, etages, hf, Color(0.52, 0.54, 0.58), 1, false, false, 3)
	# héliport + antenne
	m.bloc(cx - 8.0, cx + 8.0, 59.0, 59.3, cz - 5.2, cz + 8.0, Color(0.22, 0.22, 0.25), true, false)   # hors de la cage d'escalier
	m.bloc(cx - 0.3, cx + 0.3, 59.3, 70.0, cz - 0.3, cz + 0.3, Color(0.8, 0.15, 0.15), true, false)
	# hall d'entrée : colonnes + mobilier de couverture au rez-de-chaussée
	for sx in [-1.0, 1.0]:
		m.bloc(cx + sx * 8.0 - 0.5, cx + sx * 8.0 + 0.5, 0.0, hf - DALLE, cz + 3.0, cz + 4.0, Color(0.4, 0.4, 0.44), true, false)
	for i in 6:
		var x := cx + m.rng.randf_range(-8.0, 8.0)
		var z := cz + m.rng.randf_range(-2.0, 8.0)
		m.bloc(x - 1.0, x + 1.0, 0.0, 1.0, z - 0.7, z + 0.7, Color(0.35, 0.28, 0.2), true, false, true)
	m.stats["tour"] = 1
