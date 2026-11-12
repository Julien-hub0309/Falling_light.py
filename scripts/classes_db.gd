class_name ClassesDB
extends RefCounted
## Les 4 classes (classe/classe_1..4.py). Le pilote démarre avec le couteau seulement
## (classe/choix_classe.py : appliquer) ; l'arme principale vient du loot.

const DATA := [
	{"nom": "ASSAUT", "description": "AR-15\n2 grenades\nPolyvalent", "primaire": "AR-15",
		"tactique": "frag", "nb_tactique": 2, "hp": 100.0, "vitesse": 1.0},
	{"nom": "TACTIC", "description": "Kriss Vector\n2 grenades\nRapide (+10%)", "primaire": "Kriss Vector",
		"tactique": "frag", "nb_tactique": 2, "hp": 90.0, "vitesse": 1.1},
	{"nom": "SNIPER", "description": "DRS-50 (lunette)\n2 fumigènes\nLongue portée", "primaire": "DRS-50",
		"tactique": "fumigene", "nb_tactique": 2, "hp": 85.0, "vitesse": 1.0},
	{"nom": "BRECHE", "description": "Fusil à pompe\nRésistant (120 PV)\nLent (-8%)", "primaire": "Pompe",
		"tactique": "frag", "nb_tactique": 3, "hp": 120.0, "vitesse": 0.92},
]

static func aleatoire() -> Dictionary:
	return DATA[randi() % DATA.size()]
