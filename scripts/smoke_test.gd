extends Node
## Test automatique : godot --headless --path . -- --smoke
## Lance une partie, tire, grimpe, grappin, ramasse un loot, passe la nuit, tue le joueur...

var etape := 0
var t := 0.0
var mur: StaticBody3D
var zgren: Zombie


func _isoler(j: Joueur) -> void:
	for z in Etat.zombies:
		z.set_physics_process(false)
		z.global_position = Vector3(300, 0, 300)
	for p in Etat.pilotes:
		if p != j:
			p.set_physics_process(false)
			p.global_position = Vector3(-300, 0, -300)


func _ready() -> void:
	print("[smoke] démarrage")


func _physics_process(dt: float) -> void:
	t += dt
	var P: Partie = Etat.partie
	var j: Joueur = Etat.joueur
	var carte: MapBuilder = get_parent().get_node("Carte")
	match etape:
		0:
			P.demarrer(ClassesDB.DATA[0])
			print("[smoke] partie démarrée, zombies=", Etat.zombies.size(), " loots=", Etat.loots.size(),
				" obstacles=", Etat.obstacles.size(), " spawns=", Etat.spawns.size())
			assert(Etat.zombies.size() == Etat.NB_ZOMBIES)
			assert(j.vivant and j.arme_active().nom == "Couteau")
			etape = 1
			t = 0.0
		1:
			if t > 0.5:
				Etat.racine_loots.add_child(Loot.creer(j.global_position, "arme", true))
				etape = 2
				t = 0.0
		2:
			if t > 0.5:
				print("[smoke] arme après loot : ", j.arme_active().nom)
				assert(j.arme_active().nom != "Couteau")
				var z: Zombie = Etat.zombies[0]
				z.global_position = j.global_position + Vector3(0, 0, -6)
				z.set_physics_process(false)          # le fige pour le test de tir
				etape = 3
				t = 0.0
		3:
			if t > 0.2:
				var z: Zombie = Etat.zombies[0]
				var a := j.arme_active()
				a.cool = 0.0
				var hp0 := z.hp
				j.tirer()
				print("[smoke] tir -> munitions=", a.munitions, " zombie hp ", hp0, " -> ", z.hp)
				assert(z.hp < hp0)
				z.set_physics_process(true)
				etape = 4
				t = 0.0
		4:
			# mur de 2 m devant le joueur (en terrain dégagé) -> test du grimper
			if t > 0.1:
				var o := Vector3(0, 0, -30)
				j.global_position = o
				j.rotation = Vector3.ZERO
				mur = carte.bloc(-3, 3, 0, 2.0, -33.0, -31.0, Color.GRAY)
				etape = 5
				t = 0.0
		5:
			if t > 0.5:
				var ok := j.tente_grimper()
				print("[smoke] grimper possible=", ok)
				assert(ok)
				etape = 6
				t = 0.0
		6:
			if t > 1.0:
				print("[smoke] après grimper y=", j.global_position.y, " z=", j.global_position.z)
				assert(j.global_position.y > 1.9)
				# grappin contre un mur plus loin
				j.global_position = Vector3(0, 0, -20)
				j.pivot.rotation.x = deg_to_rad(0.0)
				etape = 7
				t = 0.0
		7:
			if t > 0.2:
				j.lancer_grappin()
				print("[smoke] grappin actif=", j.grappin_actif)
				assert(j.grappin_actif)
				etape = 8
				t = 0.0
		8:
			if t > 1.0:
				print("[smoke] pos après grappin : ", j.global_position)
				j.fin_grappin(true)
				j.pivot.rotation.x = 0.0
				# zombie collé au joueur : il doit l'attaquer
				j.invuln = 0.0
				var z: Zombie = Etat.zombies[1]
				z.global_position = j.global_position + Vector3(0, 0, -1.0)
				z.cible = j
				z.atk = 0.0
				etape = 9
				t = 0.0
		9:
			if t > 2.0:
				print("[smoke] hp joueur après attaque zombie : ", j.hp, "/", j.hp_max)
				assert(j.hp < j.hp_max)
				P.t = Etat.DUREE_JOUR - 0.1
				etape = 10
				t = 0.0
		10:
			if t > 0.5:
				assert(P.nuit)
				var kinds := {}
				for z in Etat.zombies:
					kinds[z.kind] = kinds.get(z.kind, 0) + 1
				print("[smoke] nuit, k=", P.k_nuit, " types : ", kinds)
				j.score = 60
				j.damage(9999.0, null)
				etape = 11
				t = 0.0
		11:
			if t > 0.2:
				print("[smoke] score 60 -> respawn payant : attente=", j.attente, " score=", j.score, " éliminé=", j.elimine)
				assert(j.attente and not j.elimine)
				etape = 12
				t = 0.0
		12:
			if t > 3.5:
				print("[smoke] respawn : vivant=", j.vivant, " arme=", j.arme_active().nom)
				assert(j.vivant)
				j.invuln = 0.0
				j.damage(9999.0, null)
				etape = 13
				t = 0.0
		13:
			if t > 1.0:
				print("[smoke] joueur éliminé=", j.elimine, " fini=", P.fini, " résultat=", P.resultat)
				assert(j.elimine)
				etape = 14
				t = 0.0
		14:
			# --- phase 2 : relance une partie avec bots, grenades, navigation
			P.ouvrir_menu()
			P.demarrer(ClassesDB.DATA[1])
			var bots := Etat.pilotes.filter(func(p): return p is PiloteIA)
			print("[smoke] bots=", bots.size(), " nav prête=", Nav.prete)
			assert(bots.size() == 4)
			assert(Nav.prete)
			var r := Nav.route(Vector3(-120, 0, -120), Vector3(120, 0, 120))
			print("[smoke] route traversée de la ville : ", r.size(), " points")
			assert(r.size() > 2)
			# un point sur un toit est-il joignable ? (rampe + palier)
			var b: Rect2 = Etat.batiments[0]
			var toit := Vector3(b.position.x + b.size.x * 0.5, 0.0, b.position.y + b.size.y * 0.5)
			var hh := 0.0
			var rr := Etat.raycast(j, toit + Vector3(0, 80, 0), Vector3.DOWN, 100.0, Etat.COUCHE_MONDE)
			if not rr.is_empty():
				hh = rr.position.y
				toit.y = hh
			var rt := Nav.route(Vector3(-120, 0, -120), toit)
			print("[smoke] toit à y=", hh, " route=", rt.size(), " points, joignable=", Nav.joignable(toit))
			assert(rt.size() > 2)
			# grenade à fragmentation lancée sur un zombie
			j.nb_tactique = 2
			var z: Zombie = Etat.zombies[0]
			zgren = z
			z.set_physics_process(false)
			j.global_position = Vector3(0, 0, 10)
			z.global_position = Vector3(0, 0, 4)
			j.cool_tact = 0.0
			j.lancer_tactique(Vector3(0, 1, 9), Vector3(0, 1, -2))
			etape = 15
			t = 0.0
		15:
			if t > 3.2:
				var restants := Etat.zombies.filter(func(zz): return is_instance_valid(zz) and zz.position.distance_to(Vector3(0, 0, 4)) < 1.0 and zz.vivant)
				print("[smoke] zombie touché par la grenade (tué ou blessé) : ", not is_instance_valid(zgren) or zgren.hp < zgren.hp_max)
				# laisse bots + zombies jouer 60 s de partie accélérée (pas d'erreur attendue)
				Engine.time_scale = 8.0
				if is_instance_valid(zgren):
					zgren.set_physics_process(true)
				etape = 16
				t = 0.0
		16:
			if t > 60.0:
				Engine.time_scale = 1.0
				var vivants := Etat.pilotes.filter(func(p): return p.vivant).size()
				print("[smoke] après 8 s : pilotes vivants=", vivants, " zombies=", Etat.zombies.size())
				var bp := Etat.pilotes.filter(func(p): return p is PiloteIA)
				for p in bp:
					print("   ", p.nom, " pos=", p.global_position.round(), " arme=", p.arme_active().nom, " score=", p.score)
				etape = 17
				t = 0.0
		17:
			# --- phase 3 : Titan
			Engine.time_scale = 1.0
			P.ouvrir_menu()
			P.demarrer(ClassesDB.DATA[0])
			for z in Etat.zombies:
				z.set_physics_process(false)
				z.global_position = Vector3(300, 0, 300)       # hors de portée
			for p in Etat.pilotes:
				if p != j:
					p.set_physics_process(false)
					p.global_position = Vector3(-300, 0, -300)
			j.global_position = Vector3(0, 0, 0)
			j.rotation = Vector3.ZERO
			j.score = 20
			j.armes[0] = Arme.creer("AR-15")       # (le couteau seul donnerait un Titan de mêlée)
			var ok := j.appeler_titan()
			print("[smoke] appel Titan : ", ok, " score=", j.score)
			assert(ok and j.titan_actif() and j.score == 10)
			etape = 18
			t = 0.0
		18:
			if t > 4.0:
				print("[smoke] Titan état=", j.titan.state, " pos=", j.titan.global_position.round())
				assert(j.titan.state == "ready")
				j.global_position = j.titan.global_position + Vector3(4, 0, 0)
				j.embarquer()
				print("[smoke] à bord : mode=", j.mode, " arme=", j.arme_active().nom, " dégâts=", j.arme_active().degats)
				assert(j.mode == "titan" and j.arme_active().titan)
				etape = 19
				t = 0.0
		19:
			if t > 0.5:
				var z: Zombie = Etat.zombies[0]
				z.global_position = j.global_position + Vector3(0, 0, -12)
				etape = 20
				t = 0.0
		20:
			if t > 0.3:
				var z: Zombie = Etat.zombies[0]
				var a := j.arme_active()
				a.cool = 0.0
				var hp0 := z.hp
				j.pivot.rotation.x = -0.3                # le Titan voit de haut : on vise vers le bas
				j.tirer()
				print("[smoke] tir Titan : zombie ", hp0, " -> ", z.hp if is_instance_valid(z) else "mort")
				assert(not is_instance_valid(z) or z.hp < hp0)
				j.damage(100.0, null)
				print("[smoke] PV titan après 100 dégâts : ", j.titan_hp)
				assert(j.titan_hp < 400.0)
				j.pivot.rotation.x = 0.0
				j.ejecter()
				print("[smoke] éjecté : mode=", j.mode, " titan=", j.titan.state)
				assert(j.mode == "pilot" and j.titan.state == "ready")
				etape = 21
				t = 0.0
		21:
			# IA du Titan : il tire seul sur un zombie visible
			if t > 0.2:
				var z: Zombie = Etat.zombies[1]
				z.set_physics_process(false)
				var tt: Titan = j.titan
				z.global_position = tt.global_position + Vector3(0, 0, -20)
				j.global_position = tt.global_position + Vector3(6, 0, 6)
				etape = 22
				t = 0.0
		22:
			if t > 4.0:
				var z: Zombie = Etat.zombies[1] if Etat.zombies.size() > 1 else null
				print("[smoke] IA Titan a tiré : kills joueur=", j.kills, " score=", j.score)
				assert(j.kills >= 1)
				j.titan.damage(2000.0, null)
				print("[smoke] titan détruit : cd=", j.titan_cd, " titan=", j.titan)
				assert(j.titan == null and j.titan_cd > 20.0)
				etape = 23
				t = 0.0
		23:
			if t > 0.5:
				P.t = Etat.DUREE_JOUR - 0.1
				etape = 24
				t = 0.0
		24:
			if t > 0.5:
				var geants := Etat.zombies.filter(func(zz): return zz.kind == "geant")
				print("[smoke] géants=", geants.size(), " hp=", geants[0].hp, " h=", geants[0].h)
				assert(geants.size() == 5)
				# options : config + remap
				var opt: Options = get_parent().get_node("Options")
				var ev := InputEventKey.new()
				ev.physical_keycode = KEY_H
				opt._assigner("grappin", 0, ev)
				var ev2 := InputEventKey.new()
				ev2.physical_keycode = KEY_H
				opt._assigner("tactique", 0, ev2)       # H retiré de "grappin"
				print("[smoke] grappin=", InputMap.action_get_events("grappin").size(), " tactique=", opt._nom_event(InputMap.action_get_events("tactique")[0]))
				assert(InputMap.action_get_events("grappin").size() == 0)
				Etat.sensibilite = 55.0
				Etat.fov = 90.0
				Etat.qualite = "haut"
				Etat.sauver_config()
				Etat.sensibilite = 40.0
				Etat.fov = 100.0
				Etat.qualite = "moyen"
				Etat.reinitialiser_touches()
				Etat.charger_config()
				print("[smoke] config rechargée : sens=", Etat.sensibilite, " fov=", Etat.fov, " qualité=", Etat.qualite,
					" tactique=", opt._nom_event(InputMap.action_get_events("tactique")[0]))
				assert(Etat.sensibilite == 55.0 and Etat.fov == 90.0 and Etat.qualite == "haut")
				Etat.reinitialiser_touches()
				Etat.sensibilite = 40.0
				Etat.fov = 100.0
				Etat.qualite = "moyen"
				Etat.sauver_config()
				etape = 25
				t = 0.0
		25:
			# --- phase 4 : craft
			Etat.mode_jeu = "classique"
			P.ouvrir_menu()
			P.demarrer(ClassesDB.DATA[2])                      # SNIPER -> arme de classe DRS-50
			for z in Etat.zombies:
				z.set_physics_process(false)
				z.global_position = Vector3(300, 0, 300)
			for p in Etat.pilotes:
				if p != j:
					p.set_physics_process(false)
					p.global_position = Vector3(-300, 0, -300)
			j.invuln = 9999.0
			for i in 3:
				assert(j.ramasser("arme"))
			print("[smoke] 3 rouges : couteau dégâts=", j.armes[1].degats, " niveau_melee=", j.craft["niveau_melee"])
			assert(j.craft["niveau_melee"] == 1 and absf(j.armes[1].degats - 3.75) < 0.01)
			for i in 2:
				j.ramasser("arme")
			print("[smoke] 5 rouges : arme de classe=", j.armes[0].nom, " flag=", j.craft["arme_classe"])
			assert(j.craft["arme_classe"] and j.armes[0].modele == "DRS-50")
			var deg0: float = j.armes[0].degats
			var arme_avant: Arme = j.armes[0]
			assert(j.ramasser("arme"))                         # 6e : ne remplace plus l'arme de classe
			assert(j.armes[0] == arme_avant)
			for i in 4:
				j.ramasser("arme")
			print("[smoke] 10 rouges : augmentation=", j.craft["augmentation"], " dégâts ", deg0, " -> ", j.armes[0].degats, " chargeur=", j.armes[0].chargeur)
			assert(j.craft["augmentation"] and absf(j.armes[0].degats - deg0 * 1.35) < 0.01 and j.armes[0].chargeur == 7)
			# kits
			j.hp = 50.0
			j.armure = 0.0
			for i in 4:
				j.ramasser("soin")
				j.ramasser("armure")
			print("[smoke] kits soin=", j.craft["kits_soin"], " armure=", j.craft["kits_armure"], " (max 3)")
			assert(j.craft["kits_soin"] == 3 and j.craft["kits_armure"] == 3)
			assert(not j.ramasser("soin"))                     # plein : le loot reste au sol
			assert(Craft.utiliser_soin(j) and j.hp == 85.0)       # plafonné aux PV max du Sniper (85)
			assert(Craft.utiliser_armure(j) and j.armure == 40.0)
			j.nb_tactique = 6
			assert(not j.ramasser("grenade"))
			# respawn : le craft est conservé
			j.invuln = 0.0
			j.score = 60
			j.damage(9999.0, null)
			etape = 26
			t = 0.0
		26:
			if t > 3.6:
				print("[smoke] après respawn : arme=", j.armes[0].nom, " dégâts=", j.armes[0].degats)
				assert(j.vivant and j.armes[0].modele == "DRS-50" and j.armes[0].augmentee)
				etape = 27
				t = 0.0
		27:
			# --- mode PARCOURS
			Etat.mode_jeu = "parcours"
			P.ouvrir_menu()
			P.demarrer(ClassesDB.DATA[0])
			for z in Etat.zombies:
				z.set_physics_process(false)
			var actifs := Etat.pilotes.filter(func(p): return p.en_match)
			print("[smoke] parcours : pilotes actifs=", actifs.size(), " checkpoints=", Etat.modes.points.size(),
				" temps=", Etat.modes.restant, " zombies=", Etat.zombies.size(), " type=", Etat.zombies[0].kind, " détection=", Etat.zombies[0].detection)
			assert(actifs.size() == 1 and Etat.modes.points.size() == 8)
			assert(Etat.zombies[0].detection >= 900.0 and j.armes[0].melee())
			var armes_sol := Etat.loots.filter(func(l): return l.actif and l.type == "arme")
			assert(armes_sol.is_empty())
			j.invuln = 9999.0
			etape = 28
			t = 0.0
		28:
			# on se téléporte de checkpoint en checkpoint
			if t > 0.25 and Etat.modes.idx < Etat.modes.points.size() and not P.fini:
				var pt: Vector3 = Etat.modes.points[Etat.modes.idx]
				j.global_position = pt + Vector3(0, 0.1, 0)
				t = 0.0
			elif P.fini:
				print("[smoke] parcours fini : ", P.resultat, " temps restant=", int(Etat.modes.restant))
				assert(P.resultat.begins_with("VICTOIRE") and Etat.modes.restant > 180.0)
				etape = 29
				t = 0.0
		29:
			# --- mode POINT DE CONTRÔLE
			Etat.mode_jeu = "controle"
			P.ouvrir_menu()
			P.demarrer(ClassesDB.DATA[0])
			for z in Etat.zombies:
				z.set_physics_process(false)
				z.global_position = Vector3(300, 0, 300)
			for p in Etat.pilotes:
				if p != j:
					p.set_physics_process(false)
					p.global_position = Vector3(-300, 0, -300)
			j.invuln = 9999.0
			var z0: Vector3 = Etat.modes.zone
			print("[smoke] controle : zone=", z0.round(), " actif=", Etat.modes.zone_active)
			assert(Etat.modes.zone_active)
			Engine.time_scale = 6.0
			etape = 30
			t = 0.0
		30:
			var zn: Vector3 = Etat.modes.zone
			j.global_position = Vector3(zn.x, zn.y + 0.1, zn.z)
			j.velocity = Vector3.ZERO
			if j.score >= 10:
				Engine.time_scale = 1.0
				print("[smoke] zone capturée : score=", j.score, " nouvelle zone=", Etat.modes.zone.round())
				assert(j.score == 10)
				# mort : respawn gratuit, pas d'élimination
				j.invuln = 0.0
				j.damage(9999.0, null)
				etape = 31
				t = 0.0
		31:
			if t > 5.6:
				print("[smoke] controle après mort : vivant=", j.vivant, " éliminé=", j.elimine, " score=", j.score)
				assert(j.vivant and not j.elimine and j.score == 10)
				P.ouvrir_menu()
				Etat.mode_jeu = "classique"
				etape = 32
				t = 0.0
		32:
			# --- phase 5 : élan conservé
			Etat.mode_jeu = "classique"
			P.ouvrir_menu()
			P.demarrer(ClassesDB.DATA[3])                      # BRECHE
			_isoler(j)
			j.invuln = 9999.0
			j.global_position = Vector3(0, 0, 0)
			j.rotation = Vector3.ZERO
			j.vel = Vector3(0, 0, -15.0)                       # course à 15 m/s, on continue d'avancer
			j.grounded = true
			Input.action_press("avant")
			etape = 33
			t = 0.0
		33:
			if t > 0.4:
				var v: float = Vector2(j.vel.x, j.vel.z).length()
				print("[smoke] élan après 0,4 s en continuant d'avancer : ", snappedf(v, 0.1), " m/s (départ 15, cible 6)")
				assert(v > 9.0)                                # l'ancien code retombait à la vitesse de marche
				Input.action_release("avant")
				# glisse avec l'élan
				j.vel = Vector3(0, 0, -16.0)
				j.slide_dir = Vector3(0, 0, -1)
				j.slide_dur = 1.0
				j.slide_t = 1.0
				j.slide_v0 = 16.0
				etape = 34
				t = 0.0
		34:
			if t > 0.2:
				var v2: float = Vector2(j.vel.x, j.vel.z).length()
				print("[smoke] vitesse pendant la glisse : ", snappedf(v2, 0.1))
				assert(v2 > 12.0)
				j.slide_t = 0.0
				etape = 35
				t = 0.0
		35:
			# --- ordres et épée du Titan
			j.score = 30
			j.armes[0] = Arme.creer("AR-15")
			var ok := j.appeler_titan()
			assert(ok)
			etape = 36
			t = 0.0
		36:
			if t > 4.0:
				var ti: Titan = j.titan
				assert(ti.state == "ready")
				j.ordre_titan_suivant()
				print("[smoke] ordre Titan : ", ti.ordre)
				assert(ti.ordre == "tenir")
				j.ordre_titan_suivant()
				assert(ti.ordre == "attaquer")
				j.ordre_titan_suivant()
				assert(ti.ordre == "suivre")
				var but := ti.global_position + Vector3(25, 0, 0)
				j.ordre_titan_aller(but)
				assert(ti.ordre == "aller")
				etape = 37
				t = 0.0
		37:
			if fmod(t, 0.8) < 0.017 and t < 6.5:
				print("   t=", snappedf(t, 0.1), " titan=", j.titan.global_position.round(), " but=", j.titan.point_garde.round(), " route=", j.titan.route.size(), " bloque=", snappedf(j.titan.bloque_t, 0.1))
			if t > 6.0 or j.titan.ordre == "tenir":
				var d: float = Vector2(j.titan.global_position.x - j.titan.point_garde.x, j.titan.global_position.z - j.titan.point_garde.z).length()
				print("[smoke] Titan arrivé : ordre=", j.titan.ordre, " distance au but=", snappedf(d, 0.1))
				assert(d < 4.0 and j.titan.ordre == "tenir")
				# épée du joueur à bord
				j.global_position = j.titan.global_position + Vector3(4, 0, 0)
				j.embarquer()
				var z: Zombie = Etat.zombies[0]
				z.set_physics_process(false)
				z.global_position = j.global_position + Vector3(0, 0, -3.5)
				j.rotation = Vector3.ZERO
				etape = 38
				t = 0.0
		38:
			if t > 0.3:
				var z: Zombie = Etat.zombies[0]
				var hp0 := z.hp
				j.cd_epee = 0.0
				j.coup_epee()
				print("[smoke] épée : zombie ", hp0, " -> ", z.hp if is_instance_valid(z) else "mort")
				assert(not is_instance_valid(z) or z.hp < hp0)
				j.ejecter()
				j.titan.detruire(false)
				etape = 39
				t = 0.0
		39:
			# --- ARBRE DES CLASSES : BRECHE (niveau 3 : 15 loots)
			if t > 0.3:
				P.ouvrir_menu()
				P.demarrer(ClassesDB.DATA[3])
				_isoler(j)
				j.invuln = 9999.0
				print("[smoke] niveau au départ=", Competences.niveau(j), " vitesse=", snappedf(j.vitesse_totale(), 0.01), " réduction explosif=", Competences.reduc_explosif(j))
				assert(Competences.niveau(j) == 1 and absf(j.vitesse_totale() - 1.0) < 0.01)
				j.craft["rouge"] = 6
				assert(Competences.niveau(j) == 2)
				# charge explosive : détruit un mur « destructible » et sonne un zombie
				j.global_position = Vector3(0, 0, 0)
				j.rotation = Vector3.ZERO
				mur = carte.bloc(-2, 2, 0, 2.5, -14, -13, Color.GRAY, true, false, true)
				var zc: Zombie = Etat.zombies[2]
				zc.set_physics_process(false)
				zc.global_position = Vector3(0, 0, -15)
				var ok := Competences.utiliser_actif(j)
				print("[smoke] charge explosive lancée : ", ok)
				assert(ok)
				etape = 40
				t = 0.0
		40:
			if t > 2.0:
				print("[smoke] mur détruit : ", not is_instance_valid(mur), "  zombie sonné=", Etat.zombies[2].stun_t)
				assert(not is_instance_valid(mur))
				Etat.zombies[2].global_position = Vector3(300, 0, 300)     # hors de la ligne de tir
				j.craft["rouge"] = 15
				assert(Competences.niveau(j) == 3)
				assert(Competences.utiliser_ultime(j))
				print("[smoke] lance-roquettes : arme=", j.arme_active().nom, " munitions=", j.arme_active().munitions, "/", j.arme_active().reserve)
				assert(j.arme_active().projectile == "roquette")
				var zr: Zombie = Etat.zombies[3]
				zgren = zr
				zr.set_physics_process(false)
				zr.global_position = Vector3(0, 0, -30)
				etape = 41
				t = 0.0
		41:
			if t > 0.3:
				var zr: Zombie = zgren
				j.arme_active().cool = 0.0
				print("[smoke] tir : joueur en ", j.global_position.round(), " arme=", j.arme_active().nom, " mun=", j.arme_active().munitions, " zombie en ", zr.global_position.round())
				j.tirer()
				var nb := 0
				for n in get_tree().current_scene.get_children():
					if n is Roquette:
						nb += 1
				print("[smoke] roquettes en vol : ", nb)
				etape = 42
				t = 0.0
		42:
			if t > 1.2:
				print("[smoke] roquette : zombie à 30 m ", "mort" if not is_instance_valid(zgren) else str(zgren.hp))
				assert(not is_instance_valid(zgren) or zgren.hp < zgren.hp_max)
				etape = 43
				t = 0.0
		43:
			# --- ASSAUT : surchauffe ; SNIPER : radar + camouflage ; TACTIC : bouclier + ranimation
			P.ouvrir_menu()
			P.demarrer(ClassesDB.DATA[0])
			_isoler(j)
			j.invuln = 9999.0
			j.craft["rouge"] = 15
			print("[smoke] ASSAUT : vitesse x", snappedf(j.vitesse_totale(), 0.01), " grappin cd=", Competences.cd_grappin(j), " portée=", Competences.portee_grappin(j))
			assert(absf(j.vitesse_totale() - 1.1) < 0.01 and Competences.cd_grappin(j) == 1.0)
			j.armes[0] = Arme.creer("AR-15")
			var a: Arme = j.armes[0]
			var cd_norm: float = a.cadence
			assert(Competences.utiliser_ultime(j))
			a.cool = 0.0
			j.global_position = Vector3(0, 0, 0)
			a.tirer(j, j.camera.global_position, Vector3(0, 0, -1), j.camera.global_position)
			print("[smoke] surchauffe : intervalle entre tirs ", snappedf(a.cool, 0.001), " (normal ", cd_norm, ")")
			assert(a.cool < cd_norm * 0.7)
			j.hp = 50.0
			Competences.sur_kill(j)
			assert(j.hp == 65.0)
			etape = 44
			t = 0.0
		44:
			P.ouvrir_menu()
			P.demarrer(ClassesDB.DATA[2])
			_isoler(j)
			j.invuln = 9999.0
			j.craft["rouge"] = 15
			var z: Zombie = Etat.zombies[4]
			z.set_physics_process(false)
			assert(Competences.silencieux(j))
			assert(Competences.utiliser_actif(j) and j.comp["radar_t"] > 0.0)
			assert(Competences.utiliser_ultime(j) and Competences.invisible(j))
			z.global_position = j.global_position + Vector3(0, 0, -20)
			etape = 45
			t = 0.0
		45:
			if t > 0.2:
				var z: Zombie = Etat.zombies[4]
				var cible = z.trouver_cible()
				print("[smoke] SNIPER camouflé : un zombie à 20 m me voit ? ", cible != null)
				assert(cible == null)
				P.ouvrir_menu()
				P.demarrer(ClassesDB.DATA[1])                  # TACTIC
				_isoler(j)
				j.invuln = 9999.0
				j.craft["rouge"] = 15
				assert(Competences.utiliser_actif(j) and j.bouclier != null)
				print("[smoke] bouclier posé : PV=", j.bouclier.hp)
				var b: Bouclier = j.bouclier
				b.damage(100.0, null)
				assert(b.hp == 200.0)
				# ranimation
				j.invuln = 0.0
				j.hp = 10.0
				j.damage(500.0, null)
				print("[smoke] ranimation : vivant=", j.vivant, " PV=", j.hp)
				assert(j.vivant and j.hp > 40.0)
				P.ouvrir_menu()
				Etat.mode_jeu = "classique"
				etape = 46
				t = 0.0
		46:
			# --- GRAPPIN d'un bâtiment à l'autre (saut dans le vide, 35 m d'écart, toit plus haut)
			P.demarrer(ClassesDB.DATA[1])
			_isoler(j)
			j.invuln = 9999.0
			carte.bloc(54, 66, 12, 15, -50, -40, Color.GRAY)           # toit A (flottant, au-dessus de la rue)
			carte.bloc(54, 66, 14, 17, -5, 5, Color.GRAY)              # toit B, 2 m plus haut
			j.global_position = Vector3(60, 15.05, -42)
			j.rotation = Vector3(0, PI, 0)                              # regarde vers +z
			j.rotation.y = PI
			j.vel = Vector3(0, 0, 6)
			j.vy = 2.0
			j.grounded = false
			j.pivot.rotation.x = deg_to_rad(-3.5)
			etape = 47
			t = 0.0
		47:
			if t > 0.4:
				j.grappin_cd = 0.0
				j.lancer_grappin()
				print("[smoke] grappin en l'air : actif=", j.grappin_actif, " arrivée=", j.grappin_dest.round(), " kick=", j.grappin_kick)
				assert(j.grappin_actif and j.grappin_kick != Vector3.ZERO)
				etape = 48
				t = 0.0
		48:
			if fmod(t, 0.25) < 0.017 and t < 3.0:
				print("   t=", snappedf(t, 0.01), " pos=", j.global_position.round(), " vel=", Vector3(j.vel.x, j.vy, j.vel.z).round(), " grappin=", j.grappin_actif, " t_g=", snappedf(j.grappin_t, 0.01))
			if t > 4.0:
				var p := j.global_position
				print("[smoke] après grappin : pos=", p.round(), " au sol=", j.grounded)
				assert(p.z > -5.5 and p.z < 5.5 and p.x > 54 and p.x < 66 and absf(p.y - 17.0) < 1.5 and j.grounded)
				etape = 49
				t = 0.0
		49:
			# --- les bots ne ciblent / ne blessent plus leur propre Titan
			P.ouvrir_menu()
			P.demarrer(ClassesDB.DATA[0])
			_isoler(j)
			var bot: PiloteIA = Etat.pilotes.filter(func(p): return p is PiloteIA)[0]
			bot.set_physics_process(true)
			bot.score = 30
			bot.global_position = Vector3(0, 0, 0)
			bot.armes[0] = Arme.creer("AR-15")
			bot.invuln = 9999.0
			var ok := bot.appeler_titan()
			assert(ok)
			zgren = null
			etape = 50
			t = 0.0
		50:
			if t > 4.0:
				var bot: PiloteIA = Etat.pilotes.filter(func(p): return p is PiloteIA)[0]
				bot.set_physics_process(false)
				var ti: Titan = bot.titan
				assert(ti.state == "ready")
				print("[smoke] est_ami(bot, son titan)=", Etat.est_ami(bot, ti), " est_ami(joueur, titan du bot)=", Etat.est_ami(j, ti))
				assert(Etat.est_ami(bot, ti) and not Etat.est_ami(j, ti))
				bot.global_position = ti.global_position + Vector3(8, 0, 0)
				bot.penser()
				print("[smoke] cible du bot : ", bot.cible)
				assert(bot.cible != ti)
				var hp0 := ti.hp
				Etat.explode(ti.global_position + Vector3(2, 0, 0), 6.0, 200.0, bot)
				print("[smoke] explosion du bot près de son Titan : PV ", hp0, " -> ", ti.hp)
				assert(ti.hp == hp0)
				# mais le Titan du bot est bien une cible pour le joueur
				var hp1 := ti.hp
				Etat.explode(ti.global_position + Vector3(2, 0, 0), 6.0, 200.0, j)
				print("[smoke] explosion du joueur : PV ", hp1, " -> ", ti.hp)
				assert(ti.hp < hp1)
				P.ouvrir_menu()
				Etat.mode_jeu = "classique"
				print("[smoke] TOUT OK")
				get_tree().quit()
