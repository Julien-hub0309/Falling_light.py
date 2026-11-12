class_name ArmesDB
extends RefCounted
## Stats des armes (armes/fusil.py, pistolet.py, shotgun.py, smg.py, sniper.py, couteau.py).
## Les clés correspondent aux propriétés de Arme. `vue_pos` = position de l'arme à l'écran
## (z négatif = vers l'avant dans Godot).

const DATA := {
	"AR-15": {
		"pref": 22.0,
		"degats": 15.0, "cadence": 0.09, "chargeur": 30, "reserve": 120, "portee": 130.0,
		"dispersion": 0.014, "auto": true, "t_recharge": 1.5, "zoom": 62.0, "ads_prec": 0.35,
		"recul": 0.06, "couleur_trace": Color(1, 0.85, 0.3), "vue_pos": Vector3(0.32, -0.28, -0.7),
	},
	"Pistolet": {
		"pref": 14.0,
		"degats": 17.0, "cadence": 0.2, "chargeur": 12, "reserve": 60, "portee": 80.0,
		"dispersion": 0.012, "auto": false, "t_recharge": 1.0, "zoom": 78.0, "ads_prec": 0.3,
		"recul": 0.05, "couleur_trace": Color(1, 0.96, 0.8), "vue_pos": Vector3(0.3, -0.25, -0.55),
	},
	"Pompe": {
		"pref": 8.0,
		"degats": 9.0, "plombs": 8, "cadence": 0.85, "chargeur": 6, "reserve": 30, "portee": 40.0,
		"dispersion": 0.07, "auto": false, "t_recharge": 2.0, "zoom": 80.0, "ads_prec": 0.55,
		"recul": 0.15, "couleur_trace": Color(1, 0.55, 0.15), "ep": 0.03,
		"vue_pos": Vector3(0.32, -0.28, -0.7),
	},
	"Kriss Vector": {
		"pref": 12.0,
		"degats": 9.0, "cadence": 0.055, "chargeur": 33, "reserve": 165, "portee": 90.0,
		"dispersion": 0.03, "auto": true, "t_recharge": 1.3, "zoom": 72.0, "ads_prec": 0.4,
		"recul": 0.04, "couleur_trace": Color(0.3, 0.95, 1), "vue_pos": Vector3(0.3, -0.27, -0.6),
	},
	"DRS-50": {
		"pref": 45.0,
		"degats": 95.0, "cadence": 1.2, "chargeur": 5, "reserve": 20, "portee": 300.0,
		"dispersion": 0.06, "auto": false, "t_recharge": 2.4, "zoom": 20.0, "ads_prec": 0.05,
		"recul": 0.2, "couleur_trace": Color(0.85, 0.93, 1), "ep": 0.05,
		"vue_pos": Vector3(0.3, -0.28, -0.9),
	},
	# Arme temporaire du Breacher (ultime) : 1 roquette par chargeur, 4 en tout.
	"Lance-roquettes": {
		"degats": 160.0, "cadence": 1.2, "chargeur": 1, "reserve": 3, "portee": 220.0,
		"dispersion": 0.0, "auto": false, "t_recharge": 1.5, "zoom": 70.0, "ads_prec": 0.2,
		"recul": 0.25, "couleur_trace": Color(1, 0.6, 0.2), "projectile": "roquette", "pref": 40.0,
		"vue_pos": Vector3(0.35, -0.3, -0.7),
	},
	# Couteau : chargeur 0 = arme de mêlée (ne consomme rien). Valeurs d'origine conservées
	# (3 dégâts / 1 s) : à ajuster. Portée ramenée de 10 à 3 m. En Python le couteau ne tirait jamais.
	"Couteau": {
		"pref": 2.0,
		"degats": 3.0, "cadence": 1.0, "chargeur": 0, "reserve": -1, "portee": 3.0,
		"dispersion": 0.0, "auto": false, "t_recharge": 0.0, "zoom": 0.0, "ads_prec": 0.2,
		"recul": 0.0, "couleur_trace": Color(1, 0.25, 0.25), "vue_pos": Vector3(0.4, -0.3, -0.6),
	},
}

## Armes qu'un loot "arme" peut donner (FABRIQUES_ARMES de pilote.py)
const PRIMAIRES := ["AR-15", "Kriss Vector", "DRS-50", "Pompe"]
