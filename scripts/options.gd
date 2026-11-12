class_name Options
extends CanvasLayer
## Menu Options (parametres/options.py) : touches (2 par action, clavier / souris / molette),
## sensibilité, FOV, inversion Y, qualité graphique. Échap l'ouvre ; en match, il met en PAUSE.

var panneau: Control
var boutons := {}                    # [action, slot] -> Button
var capture := []                    # [action, slot] en cours d'attribution, vide sinon
var t_capture := 0
var vals := {}
var ouvert := false


func _ready() -> void:
	layer = 20
	panneau = ColorRect.new()
	(panneau as ColorRect).color = Color(0.02, 0.03, 0.06, 1.0)
	panneau.set_anchors_preset(Control.PRESET_FULL_RECT)
	panneau.visible = false
	add_child(panneau)
	var marge := MarginContainer.new()
	marge.set_anchors_preset(Control.PRESET_FULL_RECT)
	for c in ["left", "right", "top", "bottom"]:
		marge.add_theme_constant_override("margin_" + c, 30)
	panneau.add_child(marge)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	marge.add_child(col)
	var titre := Label.new()
	titre.text = "OPTIONS"
	titre.add_theme_font_size_override("font_size", 40)
	titre.add_theme_color_override("font_color", Color(1, 0.55, 0.1))
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(titre)
	var corps := HBoxContainer.new()
	corps.add_theme_constant_override("separation", 40)
	col.add_child(corps)

	# ---- touches
	var g_touches := VBoxContainer.new()
	corps.add_child(g_touches)
	g_touches.add_child(_texte("TOUCHES  (clic sur une case, puis touche / bouton souris / molette)", 15))
	var grille := GridContainer.new()
	grille.columns = 6
	grille.add_theme_constant_override("h_separation", 8)
	grille.add_theme_constant_override("v_separation", 4)
	g_touches.add_child(grille)
	var n: int = Etat.ACTIONS.size()
	var lignes := (n + 1) / 2
	for row in lignes:
		for colonne in 2:
			var i := colonne * lignes + row
			if i >= n:
				for k in 3:
					grille.add_child(Control.new())
				continue
			var a: String = Etat.ACTIONS[i][0]
			var l := _texte(Etat.ACTIONS[i][1], 15)
			l.custom_minimum_size.x = 150
			grille.add_child(l)
			for slot in 2:
				var b := Button.new()
				b.custom_minimum_size = Vector2(92, 28)
				b.pressed.connect(_demarrer_capture.bind(a, slot))
				grille.add_child(b)
				boutons[[a, slot]] = b

	# ---- réglages
	var g_reg := VBoxContainer.new()
	g_reg.add_theme_constant_override("separation", 12)
	corps.add_child(g_reg)
	g_reg.add_child(_texte("SOURIS / ÉCRAN", 15))
	_ligne(g_reg, "sens", "Sensibilité")
	_ligne(g_reg, "fov", "Champ de vision")
	_ligne(g_reg, "inv", "Inverser Y")
	_ligne(g_reg, "qual", "Graphismes")
	g_reg.add_child(_bouton("Réinitialiser les touches", func():
		Etat.reinitialiser_touches()
		_annuler()))
	g_reg.add_child(_bouton("Fermer  (Échap)", fermer))
	g_reg.add_child(_bouton("Quitter le jeu", func(): get_tree().quit()))
	var info := _texte("Retour = effacer la case  |  Échap = annuler  |  Une touche déjà utilisée est retirée de l'autre action", 13)
	info.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	col.add_child(info)
	_maj()


func _texte(t: String, taille: int) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", taille)
	return l


func _bouton(t: String, fn: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(300, 38)
	b.pressed.connect(fn)
	return b


func _ligne(parent: Control, cle: String, lib: String) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	parent.add_child(h)
	var l := _texte(lib, 16)
	l.custom_minimum_size.x = 150
	h.add_child(l)
	var moins := Button.new()
	moins.text = "-"
	moins.custom_minimum_size = Vector2(34, 30)
	moins.pressed.connect(_pas.bind(cle, -1))
	h.add_child(moins)
	var v := _texte("", 16)
	v.custom_minimum_size.x = 80
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_theme_color_override("font_color", Color.YELLOW)
	h.add_child(v)
	vals[cle] = v
	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(34, 30)
	plus.pressed.connect(_pas.bind(cle, 1))
	h.add_child(plus)


func _pas(cle: String, d: int) -> void:
	match cle:
		"sens": Etat.sensibilite = clampf(Etat.sensibilite + 5.0 * d, 10.0, 120.0)
		"fov": Etat.fov = clampf(Etat.fov + 5.0 * d, 70.0, 120.0)
		"inv": Etat.inverser_y = not Etat.inverser_y
		"qual":
			var i := (Etat.NIVEAUX.find(Etat.qualite) + d + Etat.NIVEAUX.size()) % Etat.NIVEAUX.size()
			Etat.qualite = Etat.NIVEAUX[i]
			Etat.appliquer_qualite()
	_maj()


func _nom_event(ev: InputEvent) -> String:
	if ev is InputEventKey:
		if DisplayServer.get_name() == "headless":
			return OS.get_keycode_string(ev.physical_keycode).to_upper()
		var kc := DisplayServer.keyboard_get_keycode_from_physical(ev.physical_keycode)
		return OS.get_keycode_string(kc).to_upper()
	if ev is InputEventMouseButton:
		match ev.button_index:
			MOUSE_BUTTON_LEFT: return "Clic G"
			MOUSE_BUTTON_RIGHT: return "Clic D"
			MOUSE_BUTTON_MIDDLE: return "Clic molette"
			MOUSE_BUTTON_WHEEL_UP: return "Molette +"
			MOUSE_BUTTON_WHEEL_DOWN: return "Molette -"
		return "Souris %d" % ev.button_index
	return "---"


func _maj() -> void:
	vals["sens"].text = str(int(Etat.sensibilite))
	vals["fov"].text = str(int(Etat.fov))
	vals["inv"].text = "Oui" if Etat.inverser_y else "Non"
	vals["qual"].text = Etat.qualite.to_upper()
	for k in boutons:
		var b: Button = boutons[k]
		if capture == [k[0], k[1]]:
			b.text = "..."
		else:
			var evs := InputMap.action_get_events(k[0])
			b.text = _nom_event(evs[k[1]]) if k[1] < evs.size() else "---"


# ---- attribution d'une touche ----
func _demarrer_capture(action: String, slot: int) -> void:
	capture = [action, slot]
	t_capture = Time.get_ticks_msec()
	_maj()


func _annuler() -> void:
	capture = []
	_maj()


func _meme(a: InputEvent, b: InputEvent) -> bool:
	return _ev_cle(a) == _ev_cle(b)


func _ev_cle(ev: InputEvent) -> String:
	return str(Etat._ev_vers_dict(ev))


func _assigner(action: String, slot: int, nouveau: InputEvent) -> void:
	var cle := _ev_cle(nouveau)
	for a in Etat.ACTIONS:                     # on retire la touche des autres actions
		if a[0] == action:
			continue
		var evs := InputMap.action_get_events(a[0])
		var garde: Array = evs.filter(func(e): return _ev_cle(e) != cle)
		if garde.size() != evs.size():
			InputMap.action_erase_events(a[0])
			for e in garde:
				InputMap.action_add_event(a[0], e)
	var liste: Array = InputMap.action_get_events(action).filter(func(e): return _ev_cle(e) != cle)
	if slot < liste.size():
		liste[slot] = nouveau
	else:
		liste.append(nouveau)
	InputMap.action_erase_events(action)
	for e in liste:
		InputMap.action_add_event(action, e)


func _effacer(action: String, slot: int) -> void:
	var evs := InputMap.action_get_events(action)
	if slot < evs.size():
		evs.remove_at(slot)
	InputMap.action_erase_events(action)
	for e in evs:
		InputMap.action_add_event(action, e)


func _input(event: InputEvent) -> void:
	if not ouvert or capture.is_empty():
		return
	var action: String = capture[0]
	var slot: int = capture[1]
	if event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		if event.keycode == KEY_ESCAPE:
			_annuler()
		elif event.keycode == KEY_BACKSPACE:
			_effacer(action, slot)
			_annuler()
		else:
			var k := InputEventKey.new()
			k.physical_keycode = event.physical_keycode
			_assigner(action, slot, k)
			_annuler()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and Time.get_ticks_msec() - t_capture < 250:
			return                                  # le clic qui a ouvert la capture
		if (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN) \
				and action in ["avant", "arriere", "gauche", "droite", "sprint", "tir", "viser"]:
			return                                  # pas de molette sur une action maintenue
		get_viewport().set_input_as_handled()
		var m := InputEventMouseButton.new()
		m.button_index = event.button_index
		_assigner(action, slot, m)
		_annuler()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if ouvert:
			fermer()
		else:
			ouvrir()


func ouvrir() -> void:
	ouvert = true
	panneau.visible = true
	_maj()
	var P = Etat.partie
	if P != null and P.actif:
		P.pause = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func fermer() -> void:
	ouvert = false
	capture = []
	panneau.visible = false
	Etat.sauver_config()
	var P = Etat.partie
	if P != null and P.en_cours and not P.fini:
		P.pause = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
