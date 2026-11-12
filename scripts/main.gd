extends Node3D
## Scène principale (équivalent de titanfall.py) : assemble la carte, le joueur, le HUD et la partie.

@onready var carte: MapBuilder = $Carte
@onready var joueur: Joueur = $Joueur
@onready var hud: HUD = $HUD
@onready var partie: Partie = $Partie
@onready var modes: Modes = $Modes


func _ready() -> void:
	Etat.env = $WorldEnvironment.environment
	Etat.soleil = $Soleil
	Etat.racine_zombies = $Zombies
	Etat.racine_loots = $Loots
	Etat.partie = partie
	Etat.modes = modes
	Etat.joueur = joueur
	Etat.appliquer_qualite()
	carte.construire()
	Nav.cuire(carte, self)
	joueur.global_position = Etat.spawns[0]
	var noms := ["Alpha", "Bravo", "Charlie", "Delta"]
	var couleurs := [Color(0.9, 0.35, 0.15), Color(0.8, 0.7, 0.1), Color(0.6, 0.2, 0.8), Color(0.8, 0.15, 0.3)]
	for i in Etat.NB_PILOTES - 1:
		add_child(PiloteIA.creer(noms[i], couleurs[i]))
	hud.classe_choisie.connect(func(i: int): partie.demarrer(ClassesDB.DATA[i]))
	partie.ouvrir_menu()
	if OS.get_cmdline_user_args().has("--smoke"):
		var s: Node = load("res://scripts/smoke_test.gd").new()
		add_child(s)
	if OS.get_cmdline_user_args().has("--maptest"):
		add_child(load("res://scripts/map_test.gd").new())
	if OS.get_cmdline_user_args().has("--shot"):
		add_child(load("res://scripts/shot_tool.gd").new())
