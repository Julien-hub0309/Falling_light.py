extends Node
## Outil de dev : godot --path . -- --shot  -> écrit des captures dans /tmp/shots/
var f := 0
var plan: Array = []

func _snap(nom: String) -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/shots")
	get_viewport().get_texture().get_image().save_png("/tmp/shots/%s.png" % nom)
	print("[shot] ", nom)

func _poser(j: Joueur, pos: Vector3, yaw_deg: float, pitch_deg := 0.0) -> void:
	j.global_position = pos
	j.rotation = Vector3(0, deg_to_rad(yaw_deg), 0)
	j.pivot.rotation.x = deg_to_rad(pitch_deg)
	j.vel = Vector3.ZERO
	j.vy = 0.0

func _process(_dt: float) -> void:
	f += 1
	var j: Joueur = Etat.joueur
	var carte: MapBuilder = get_parent().get_node("Carte")
	if f == 40:
		Etat.mode_jeu = "classique"
		Etat.partie.demarrer(ClassesDB.DATA[0])
		j.invuln = 9999.0
		j.armes[0] = Arme.creer("AR-15")
		j.sur_changement_arme()
		for z in Etat.zombies:
			z.set_physics_process(false)
			z.global_position = Vector3(300, 0, 300)
		for p in Etat.pilotes:
			if p != j:
				p.set_physics_process(false)
				p.global_position = Vector3(-300, 0, 300)
		# programme des prises de vue : [nom, position, yaw, pitch]
		var it: Array = carte.interieurs[0]
		var x0: float = it[0]
		var z0: float = it[2]
		var z1: float = it[3]
		var px: float = it[6]
		plan.append(["18_maison_porte", Vector3(px, 0, z1 + 9.0), 0.0, 4.0])
		plan.append(["19_interieur_escalier", Vector3(x0 + 9.0, 0, z0 + 11.0), 0.0, 8.0])
		plan.append(["20_tour", Vector3(30, 0, 30 + 12 + 26), 0.0, 24.0])
		plan.append(["21_parc_etang", Vector3(-62, 0, -60), 45.0, 3.0])
		var ep: Vector3 = carte.epaves_pos[0] if carte.epaves_pos.size() > 0 else Vector3(10, 0, 10)
		plan.append(["22_epaves", ep + Vector3(0, 0, 11), 0.0, 4.0])
		plan.append(["23_rue_couvertures", Vector3(60, 0, 100), 180.0, 3.0])
	if f >= 60 and (f - 60) % 40 == 0:
		var i := (f - 60) / 40
		if i > 0 and i - 1 < plan.size():
			_snap(plan[i - 1][0])
		if i < plan.size():
			var e: Array = plan[i]
			_poser(j, e[1], e[2], e[3])
		elif i >= plan.size() + 1:
			get_tree().quit()
