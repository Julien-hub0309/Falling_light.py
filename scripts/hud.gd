class_name HUD
extends CanvasLayer
## Interface (HUD/hud.py) : chrono, points, PV/armure, munitions, réticule, lunette de sniper,
## flux de messages, bannières, minimap, menu de choix de classe. Tout est construit par code.

signal classe_choisie(index: int)

const MM_TAILLE := 190.0

var racine: Control
var nuit: ColorRect
var hurt: ColorRect
var reticule: Control
var scope: Control
var t_timer: Label
var t_phase: Label
var t_score: Label
var t_feed: Label
var t_hp: Label
var t_ammo: Label
var t_arme: Label
var banner: Label
var t_etat: Label
var t_titan: Label
var t_mode: Label
var t_craft: Label
var t_comp: Label
var b_modes: Array = []
var b_hp: ProgressBar
var b_arm: ProgressBar
var minimap: Control
var menu: Control

var feed: Array = []                 # [[texte, ttl], ...]
var ban_t := 0.0
var hurt_a := 0.0
var hitm := 0.0


func _ready() -> void:
	racine = Control.new()
	racine.set_anchors_preset(Control.PRESET_FULL_RECT)
	racine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(racine)
	nuit = _rect(Color(0, 0, 0.06, 0))
	hurt = _rect(Color(1, 0, 0, 0))
	reticule = _Reticule.new()
	reticule.set_anchors_preset(Control.PRESET_CENTER)
	reticule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	racine.add_child(reticule)
	scope = _Lunette.new()
	scope.set_anchors_preset(Control.PRESET_FULL_RECT)
	scope.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scope.visible = false
	racine.add_child(scope)

	t_timer = _label(40, Control.PRESET_CENTER_TOP, HORIZONTAL_ALIGNMENT_CENTER)
	t_timer.offset_top = 8
	t_phase = _label(20, Control.PRESET_CENTER_TOP, HORIZONTAL_ALIGNMENT_CENTER)
	t_phase.offset_top = 56
	t_score = _label(22, Control.PRESET_TOP_LEFT, HORIZONTAL_ALIGNMENT_LEFT)
	t_score.offset_left = 16
	t_score.offset_top = 10
	t_feed = _label(18, Control.PRESET_TOP_RIGHT, HORIZONTAL_ALIGNMENT_RIGHT)
	t_feed.offset_right = -16
	t_feed.offset_top = 10
	t_feed.add_theme_color_override("font_color", Color.YELLOW)
	t_hp = _label(18, Control.PRESET_BOTTOM_LEFT, HORIZONTAL_ALIGNMENT_LEFT)
	t_hp.offset_left = 16
	t_hp.offset_top = -86
	b_hp = _barre(Color(0.3, 0.9, 0.2), 16, -52, 300, 16)
	b_arm = _barre(Color(0.2, 0.55, 1.0), 16, -32, 300, 8)
	t_ammo = _label(44, Control.PRESET_BOTTOM_RIGHT, HORIZONTAL_ALIGNMENT_RIGHT)
	t_ammo.offset_right = -20
	t_ammo.offset_top = -92
	t_arme = _label(18, Control.PRESET_BOTTOM_RIGHT, HORIZONTAL_ALIGNMENT_RIGHT)
	t_arme.offset_right = -20
	t_arme.offset_top = -36
	t_arme.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	banner = _label(54, Control.PRESET_CENTER_TOP, HORIZONTAL_ALIGNMENT_CENTER)
	banner.offset_top = 150
	banner.add_theme_color_override("font_color", Color(1, 0.55, 0.1))
	t_etat = _label(36, Control.PRESET_CENTER_TOP, HORIZONTAL_ALIGNMENT_CENTER)
	t_etat.offset_top = 260
	t_titan = _label(22, Control.PRESET_CENTER_BOTTOM, HORIZONTAL_ALIGNMENT_CENTER)
	t_titan.offset_top = -130
	t_titan.add_theme_color_override("font_color", Color(1, 0.6, 0.1))
	t_mode = _label(26, Control.PRESET_CENTER_TOP, HORIZONTAL_ALIGNMENT_CENTER)
	t_mode.offset_top = 88
	t_mode.add_theme_color_override("font_color", Color(0.4, 0.95, 1.0))
	t_craft = _label(15, Control.PRESET_BOTTOM_LEFT, HORIZONTAL_ALIGNMENT_LEFT)
	t_craft.offset_left = 16
	t_craft.offset_top = -108
	t_craft.add_theme_color_override("font_color", Color(0.75, 0.85, 0.75))
	t_comp = _label(15, Control.PRESET_BOTTOM_LEFT, HORIZONTAL_ALIGNMENT_LEFT)
	t_comp.offset_left = 16
	t_comp.offset_top = -128
	t_comp.add_theme_color_override("font_color", Color(1, 0.8, 0.4))
	var aide := _label(13, Control.PRESET_CENTER_BOTTOM, HORIZONTAL_ALIGNMENT_CENTER)
	aide.offset_top = -22
	aide.text = "ZQSD bouger | Espace saut/grimper | Maj sprint | Ctrl glisser | X grappin | G grenade | F Titan | E embarquer | R recharger | Échap options"
	aide.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))

	minimap = _Minimap.new()
	minimap.position = Vector2(16, 190)
	minimap.size = Vector2(MM_TAILLE, MM_TAILLE)
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	racine.add_child(minimap)

	_construire_menu()
	Etat.message.connect(func(t: String): feed = (feed + [[t, 5.0]]).slice(-6))
	Etat.banniere.connect(func(t: String, d: float): banner.text = t; ban_t = d)
	Etat.degats_recus.connect(func(): hurt_a = 0.45)
	Etat.touche.connect(func(tete: bool): hitm = 0.25 if tete else 0.12)
	Etat.menu_demande.connect(func(): menu.visible = true)
	Etat.partie_demarree.connect(func(): menu.visible = false)


# ------------------------------------------------------------------ helpers UI ----
func _rect(c: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = c
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	racine.add_child(r)
	return r


func _label(taille: int, preset: int, align: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.horizontal_alignment = align as HorizontalAlignment
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	racine.add_child(l)
	l.set_anchors_preset(preset)
	if preset == Control.PRESET_CENTER_TOP or preset == Control.PRESET_CENTER_BOTTOM:
		l.anchor_left = 0.0
		l.anchor_right = 1.0
		l.offset_left = 0
		l.offset_right = 0
	return l


func _barre(col: Color, x: float, y: float, w: float, h: float) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.min_value = 0.0
	b.max_value = 1.0
	b.value = 1.0
	b.size = Vector2(w, h)
	b.custom_minimum_size = Vector2(w, h)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	var fond := StyleBoxFlat.new()
	fond.bg_color = Color(0, 0, 0, 0.55)
	b.add_theme_stylebox_override("fill", fill)
	b.add_theme_stylebox_override("background", fond)
	racine.add_child(b)
	b.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	b.offset_left = x
	b.offset_top = y
	b.offset_right = x + w
	b.offset_bottom = y + h
	return b


func _construire_menu() -> void:
	menu = ColorRect.new()
	(menu as ColorRect).color = Color(0, 0, 0, 0.75)
	menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	racine.add_child(menu)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.add_child(centre)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	centre.add_child(vb)
	var titre := Label.new()
	titre.text = "FALLING LIGHT"
	titre.add_theme_font_size_override("font_size", 56)
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(titre)
	var sous := Label.new()
	sous.text = "Choisis ton mode puis ta classe"
	sous.add_theme_font_size_override("font_size", 24)
	sous.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sous)
	var modes := HBoxContainer.new()
	modes.alignment = BoxContainer.ALIGNMENT_CENTER
	modes.add_theme_constant_override("separation", 10)
	vb.add_child(modes)
	var infos := [["classique", "CLASSIQUE\n10 min, 5 pilotes"], ["parcours", "PARCOURS\nCouteau, checkpoints"],
			["controle", "POINT DE CONTRÔLE\nTiens la zone 30 s"]]
	var groupe := ButtonGroup.new()
	for inf in infos:
		var mb := Button.new()
		mb.text = inf[1]
		mb.toggle_mode = true
		mb.button_group = groupe
		mb.button_pressed = inf[0] == Etat.mode_jeu
		mb.custom_minimum_size = Vector2(210, 60)
		mb.add_theme_font_size_override("font_size", 16)
		mb.pressed.connect(func(): Etat.mode_jeu = inf[0])
		modes.add_child(mb)
		b_modes.append(mb)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	vb.add_child(hb)
	for i in ClassesDB.DATA.size():
		var c: Dictionary = ClassesDB.DATA[i]
		var b := Button.new()
		b.text = "%s\n\n%s" % [c["nom"], c["description"]]
		b.custom_minimum_size = Vector2(200, 170)
		b.add_theme_font_size_override("font_size", 18)
		b.pressed.connect(func():
			menu.visible = false
			classe_choisie.emit(i))
		hb.add_child(b)


# ----------------------------------------------------------------- boucle ----
func _process(dt: float) -> void:
	var j = Etat.joueur
	var P = Etat.partie
	if j == null or P == null:
		return
	var bas: bool = j.vivant and j.hp < j.hp_max * 0.3
	var pulse := 0.18 + 0.12 * absf(sin(Time.get_ticks_msec() * 0.005)) if bas else 0.0
	hurt_a = maxf(0.0, hurt_a - dt * 0.8)
	hurt.color = Color(1, 0, 0, maxf(hurt_a, pulse))
	nuit.color = Color(0, 0, 0.06, 0.10 * P.k_nuit)
	hitm -= dt
	reticule.modulate = Color.RED if hitm > 0.0 else Color.WHITE
	reticule.visible = not j.zoom
	scope.visible = j.lunette
	if ban_t > 0.0:
		ban_t -= dt
		if ban_t <= 0.0:
			banner.text = ""
	for m in feed:
		m[1] -= dt
	feed = feed.filter(func(m): return m[1] > 0.0)
	t_feed.text = "\n".join(feed.map(func(m): return m[0]))

	var restant: float = Etat.modes.temps_restant() if (P.en_cours and Etat.modes != null) else Etat.DUREE_PARTIE
	t_timer.text = "%02d:%02d" % [int(restant) / 60, int(restant) % 60]
	t_phase.text = ("NUIT" if P.nuit else "JOUR") if P.en_cours else ""
	t_phase.add_theme_color_override("font_color", Color(0.6, 0.6, 1.0) if P.nuit else Color(1, 0.9, 0.5))
	var lignes: Array = ["Points : %d    Kills : %d    Zombies : %d" % [j.score, j.kills, Etat.zombies.size()]]
	var autres: Array = Etat.pilotes.filter(func(p): return p != j and p.en_match)
	for p in autres:
		var etat_p := "ÉLIMINÉ" if p.elimine else ("%d pts" % p.score)
		lignes.append("%s : %s" % [p.nom, etat_p])
	t_score.text = "\n".join(lignes)
	t_hp.text = "PV %d / %d    Armure %d" % [ceili(j.hp), int(j.hp_max), int(j.armure)]
	if j.mode == "titan":
		t_hp.text = "TITAN  %d / %d" % [ceili(maxf(j.titan_hp, 0.0)), 400]
		b_hp.value = clampf(j.titan_hp / 400.0, 0.0, 1.0)
	else:
		b_hp.value = clampf(j.hp / j.hp_max, 0.0, 1.0)
	if j.mode == "titan":
		t_titan.text = "[E] éjecter   [Q] épée"
	elif j.titan_actif() and j.titan.state == "falling":
		t_titan.text = "TITANFALL…"
	elif j.titan_actif():
		var dt_t: float = j.global_position.distance_to(j.titan.global_position)
		t_titan.text = ("[E] embarquer dans le Titan" if dt_t < 8.0 else "Titan à %d m" % int(dt_t)) + "   ordre : " + j.titan.ordre.to_upper() + "  [B] changer  [N] aller là"
	elif j.vivant and j.titan_cd > 0.0:
		t_titan.text = "Titan prêt dans %ds" % ceili(j.titan_cd)
	elif j.vivant and j.score >= Etat.COUT_TITAN:
		t_titan.text = "[F] appeler un Titan (%d pts)" % Etat.COUT_TITAN
	else:
		t_titan.text = ""
	b_arm.value = clampf(j.armure / j.armure_max, 0.0, 1.0)
	t_mode.text = Etat.modes.texte_hud() if (P.en_cours and Etat.modes != null) else ""
	t_craft.text = Craft.resume(j) if P.en_cours else ""
	t_comp.text = (Competences.resume(j) + "   [" + j.classe.get("nom", "") + "]") if (P.en_cours and not j.classe.is_empty()) else ""
	var a: Arme = j.arme_active()
	if a != null and j.vivant:
		if a.melee():
			t_ammo.text = "—"
		elif a.rech > 0.0:
			t_ammo.text = "RECHARGE"
		else:
			t_ammo.text = "%d / %s" % [a.munitions, "∞" if a.reserve < 0 else str(a.reserve)]
		t_arme.text = "%s    Grenades : %d" % [a.nom, j.nb_tactique]
	else:
		t_ammo.text = ""
		t_arme.text = ""
	if P.pause:
		t_etat.text = "PAUSE"
	elif P.fini:
		t_etat.text = P.resultat + "\n[R] rejouer"
	elif P.en_cours and j.elimine:
		t_etat.text = "ÉLIMINÉ — caméra libre   [R] menu"
	elif P.en_cours and not j.vivant:
		t_etat.text = "Respawn…"
	else:
		t_etat.text = ""
	minimap.queue_redraw()


# ========================================================= sous-contrôles ====
class _Reticule extends Control:
	func _draw() -> void:
		for r in [Rect2(-14, -1, 9, 2), Rect2(5, -1, 9, 2), Rect2(-1, -14, 2, 9), Rect2(-1, 5, 2, 9)]:
			draw_rect(r, Color.WHITE)
		draw_rect(Rect2(-1.5, -1.5, 3, 3), Color.WHITE)


class _Lunette extends Control:
	func _draw() -> void:
		var s := get_viewport_rect().size
		var c := s * 0.5
		var rayon := s.y * 0.45
		# masque noir avec une fenêtre ronde
		for i in 64:
			var a0 := TAU * i / 64.0
			var a1 := TAU * (i + 1) / 64.0
			var p0 := c + Vector2(cos(a0), sin(a0)) * rayon
			var p1 := c + Vector2(cos(a1), sin(a1)) * rayon
			var f0 := c + Vector2(cos(a0), sin(a0)) * s.length()
			var f1 := c + Vector2(cos(a1), sin(a1)) * s.length()
			draw_colored_polygon(PackedVector2Array([p0, p1, f1, f0]), Color.BLACK)
		draw_line(c - Vector2(rayon, 0), c + Vector2(rayon, 0), Color.BLACK, 1.5)
		draw_line(c - Vector2(0, rayon), c + Vector2(0, rayon), Color.BLACK, 1.5)


class _Minimap extends Control:
	func _draw() -> void:
		var tai := size.x
		var k := tai / (2.0 * Etat.DEMI_MAP)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55))
		# nord = -z (devant au départ) ; x -> droite
		var cv := func(x: float, z: float) -> Vector2:
			return Vector2((x + Etat.DEMI_MAP) * k, (z + Etat.DEMI_MAP) * k)
		for b in Etat.batiments:
			draw_rect(Rect2(cv.call(b.position.x, b.position.y), b.size * k), Color(0.6, 0.65, 0.7, 0.6))
		var jj: Joueur = Etat.joueur
		var radar: bool = jj != null and jj.comp["radar_t"] > 0.0
		var maintenant: float = Etat.partie.t if Etat.partie != null else 0.0
		# la mini-carte ne montre que ce qui est proche (60 m zombies, 45 m pilotes) ;
		# le SCAN RADAR révèle tout dans 70 m ; un tir non silencieux se voit 1,5 s ; un Recon reste invisible
		for z in Etat.zombies:
			if is_instance_valid(z) and jj != null:
				var dz: float = Vector2(z.global_position.x - jj.global_position.x, z.global_position.z - jj.global_position.z).length()
				if dz < 60.0 or (radar and dz < Competences.RADAR_RAYON):
					var pz: Vector2 = cv.call(z.global_position.x, z.global_position.z)
					var rr := 2.5 if (radar and dz >= 60.0) else 1.5
					draw_rect(Rect2(pz - Vector2(rr, rr), Vector2(rr * 2.0, rr * 2.0)), Color(0.4, 1, 0.3))
		for pp in Etat.pilotes:
			if pp is PiloteIA and pp.vivant and jj != null:
				var dp: float = Vector2(pp.global_position.x - jj.global_position.x, pp.global_position.z - jj.global_position.z).length()
				var a_tire: bool = (maintenant - pp.dernier_tir) < 1.5 and not Competences.silencieux(pp)
				if dp < 45.0 or a_tire or (radar and dp < Competences.RADAR_RAYON):
					var q: Vector2 = cv.call(pp.global_position.x, pp.global_position.z)
					draw_rect(Rect2(q - Vector2(3, 3), Vector2(6, 6)), pp.col)
					if a_tire:
						draw_arc(q, 7.0, 0.0, TAU, 16, Color(1, 0.3, 0.2), 1.5)
		if Etat.modes != null:
			for mk in Etat.modes.marqueurs():
				var mp: Vector2 = cv.call(mk[0].x, mk[0].z)
				var col: Color = mk[1]
				draw_circle(mp, maxf(4.0, mk[2] * k), Color(col.r, col.g, col.b, 0.35))
				draw_arc(mp, maxf(4.0, mk[2] * k), 0.0, TAU, 20, col, 2.0)
		for tt in Etat.titans:
			if is_instance_valid(tt) and tt.visible and (tt.proprio == Etat.joueur or radar or tt.global_position.distance_to(Etat.joueur.global_position) < 45.0):
				var q2: Vector2 = cv.call(tt.global_position.x, tt.global_position.z)
				draw_rect(Rect2(q2 - Vector2(4, 4), Vector2(8, 8)), Color(1, 0.55, 0.1))
		var j: Joueur = Etat.joueur
		if j != null:
			var p: Vector2 = cv.call(j.global_position.x, j.global_position.z)
			var f: Vector3 = -j.global_transform.basis.z
			var dir := Vector2(f.x, f.z).normalized()
			var perp := Vector2(-dir.y, dir.x)
			draw_colored_polygon(PackedVector2Array([p + dir * 7.0, p - dir * 4.0 + perp * 4.0, p - dir * 4.0 - perp * 4.0]), Color.WHITE)
