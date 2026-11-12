class_name ArmesModeles
extends RefCounted
## GÉNÉRÉ depuis armes/modeles.py (z inversé : -z = vers l'avant dans Godot).
## Chaque pièce : [taille, position, couleur].

const MODELES := {
	"AR-15": [
		[Vector3(0.085, 0.11, 0.44), Vector3(0, 0, -0.04), Color(0.2273, 0.27, 0.1674, 1)],
		[Vector3(0.05, 0.025, 0.4), Vector3(0, 0.07, -0.05), Color(0.08, 0.08, 0.08, 1)],
		[Vector3(0.07, 0.07, 0.3), Vector3(0, -0.005, -0.4), Color(0.52, 0.4399, 0.3016, 1)],
		[Vector3(0.03, 0.03, 0.25), Vector3(0, 0.01, -0.7), Color(0.08, 0.08, 0.08, 1)],
		[Vector3(0.045, 0.045, 0.06), Vector3(0, 0.01, -0.84), Color(0.04, 0.04, 0.04, 1)],
		[Vector3(0.075, 0.11, 0.26), Vector3(0, -0.01, 0.3), Color(0.5, 0.423, 0.29, 1)],
		[Vector3(0.08, 0.12, 0.03), Vector3(0, -0.01, 0.44), Color(0.08, 0.08, 0.08, 1)],
		[Vector3(0.05, 0.17, 0.09), Vector3(0, -0.13, -0.06), Color(0.45, 0.3807, 0.261, 1)],
		[Vector3(0.05, 0.12, 0.06), Vector3(0, -0.11, 0.1), Color(0.08, 0.08, 0.08, 1)],
		[Vector3(0.012, 0.06, 0.03), Vector3(-0.03, 0.1, -0.1), Color(0.08, 0.08, 0.08, 1)],
		[Vector3(0.012, 0.06, 0.03), Vector3(0.03, 0.1, -0.1), Color(0.08, 0.08, 0.08, 1)],
		[Vector3(0.07, 0.012, 0.03), Vector3(0, 0.135, -0.1), Color(0.08, 0.08, 0.08, 1)],
		[Vector3(0.011, 0.011, 0.01), Vector3(0, 0.105, -0.125), Color(1, 0.08, 0.08, 1)],
	],
	"Kriss Vector": [
		[Vector3(0.1, 0.1, 0.34), Vector3(0, 0, -0.04), Color(0.09, 0.09, 0.09, 1)],
		[Vector3(0.07, 0.04, 0.3), Vector3(0, 0.07, -0.05), Color(0.15, 0.15, 0.15, 1)],
		[Vector3(0.102, 0.02, 0.2), Vector3(0, 0.02, -0.05), Color(0.2, 0.95, 1, 1)],
		[Vector3(0.07, 0.07, 0.18), Vector3(0, 0, -0.3), Color(0.12, 0.12, 0.12, 1)],
		[Vector3(0.025, 0.025, 0.12), Vector3(0, 0, -0.43), Color(0.04, 0.04, 0.04, 1)],
		[Vector3(0.045, 0.28, 0.07), Vector3(0, -0.19, -0.08), Color(0.09, 0.09, 0.09, 1)],
		[Vector3(0.047, 0.2, 0.02), Vector3(0, -0.19, -0.115), Color(0.2, 0.95, 1, 1)],
		[Vector3(0.06, 0.05, 0.2), Vector3(0, 0.02, 0.25), Color(0.12, 0.12, 0.12, 1)],
		[Vector3(0.045, 0.09, 0.05), Vector3(0, -0.09, 0.07), Color(0.08, 0.08, 0.08, 1)],
		[Vector3(0.04, 0.08, 0.04), Vector3(0, -0.07, -0.28), Color(0.08, 0.08, 0.08, 1)],
		[Vector3(0.012, 0.06, 0.04), Vector3(-0.03, 0.1, -0.1), Color(0.07, 0.07, 0.07, 1)],
		[Vector3(0.012, 0.06, 0.04), Vector3(0.03, 0.1, -0.1), Color(0.07, 0.07, 0.07, 1)],
		[Vector3(0.07, 0.012, 0.04), Vector3(0, 0.135, -0.1), Color(0.07, 0.07, 0.07, 1)],
		[Vector3(0.01, 0.01, 0.008), Vector3(0, 0.1, -0.125), Color(0.2, 0.95, 1, 1)],
	],
	"DRS-50": [
		[Vector3(0.085, 0.1, 0.5), Vector3(0, 0, -0.05), Color(0.874, 0.9047, 0.92, 1)],
		[Vector3(0.087, 0.03, 0.5), Vector3(0, -0.02, -0.05), Color(0.2925, 0.3844, 0.45, 1)],
		[Vector3(0.035, 0.035, 0.9), Vector3(0, 0.01, -0.8), Color(0.165, 0.1925, 0.22, 1)],
		[Vector3(0.06, 0.06, 0.12), Vector3(0, 0.01, -1.27), Color(0.08, 0.08, 0.08, 1)],
		[Vector3(0.055, 0.055, 0.32), Vector3(0, 0.095, -0.08), Color(0.1, 0.1, 0.1, 1)],
		[Vector3(0.075, 0.075, 0.07), Vector3(0, 0.095, -0.27), Color(0.12, 0.12, 0.12, 1)],
		[Vector3(0.075, 0.075, 0.07), Vector3(0, 0.095, 0.1), Color(0.12, 0.12, 0.12, 1)],
		[Vector3(0.05, 0.05, 0.01), Vector3(0, 0.095, -0.31), Color(0.3, 0.6, 1, 1)],
		[Vector3(0.08, 0.13, 0.34), Vector3(0, -0.02, 0.38), Color(0.836, 0.8653, 0.88, 1)],
		[Vector3(0.07, 0.04, 0.2), Vector3(0, 0.06, 0.35), Color(0.2925, 0.3844, 0.45, 1)],
		[Vector3(0.05, 0.1, 0.07), Vector3(0, -0.09, 0), Color(0.08, 0.08, 0.08, 1)],
		[Vector3(0.05, 0.1, 0.06), Vector3(0, -0.1, 0.14), Color(0.08, 0.08, 0.08, 1)],
		[Vector3(0.012, 0.13, 0.012), Vector3(-0.035, -0.09, -0.55), Color(0.165, 0.1925, 0.22, 1)],
		[Vector3(0.012, 0.13, 0.012), Vector3(0.035, -0.09, -0.55), Color(0.165, 0.1925, 0.22, 1)],
	],
	"Pompe": [
		[Vector3(0.075, 0.1, 0.3), Vector3(0, 0, 0), Color(0.2125, 0.2313, 0.25, 1)],
		[Vector3(0.077, 0.05, 0.12), Vector3(0, 0, -0.02), Color(0.6, 0.4875, 0.15, 1)],
		[Vector3(0.045, 0.045, 0.75), Vector3(0, 0.025, -0.5), Color(0.17, 0.185, 0.2, 1)],
		[Vector3(0.035, 0.035, 0.55), Vector3(0, -0.03, -0.42), Color(0.27, 0.285, 0.3, 1)],
		[Vector3(0.075, 0.065, 0.22), Vector3(0, -0.03, -0.3), Color(0.3, 0.1775, 0.09, 1)],
		[Vector3(0.075, 0.13, 0.34), Vector3(0, -0.02, 0.32), Color(0.3, 0.1775, 0.09, 1)],
		[Vector3(0.078, 0.13, 0.03), Vector3(0, -0.02, 0.5), Color(0.15, 0.0888, 0.045, 1)],
		[Vector3(0.014, 0.03, 0.014), Vector3(0, 0.06, -0.85), Color(0.85, 0.6694, 0.1275, 1)],
		[Vector3(0.03, 0.03, 0.07), Vector3(0.052, 0, 0.05), Color(1, 0.08, 0.08, 1)],
		[Vector3(0.03, 0.03, 0.07), Vector3(0.052, 0, -0.04), Color(1, 0.08, 0.08, 1)],
		[Vector3(0.03, 0.03, 0.07), Vector3(0.052, 0, -0.13), Color(1, 0.08, 0.08, 1)],
	],
	"Pistolet": [
		[Vector3(0.05, 0.065, 0.27), Vector3(0, 0.01, -0.05), Color(0.85, 0.85, 0.85, 1)],
		[Vector3(0.048, 0.04, 0.2), Vector3(0, -0.03, -0.03), Color(0.55, 0.55, 0.55, 1)],
		[Vector3(0.045, 0.13, 0.07), Vector3(0, -0.09, 0.06), Color(0.2, 0.2, 0.2, 1)],
		[Vector3(0.047, 0.1, 0.04), Vector3(0, -0.09, 0.06), Color(0.85, 0.6694, 0.1275, 1)],
		[Vector3(0.02, 0.02, 0.04), Vector3(0, 0.01, -0.2), Color(0.85, 0.6694, 0.1275, 1)],
		[Vector3(0.014, 0.024, 0.014), Vector3(0, 0.05, 0.07), Color(0.08, 0.08, 0.08, 1)],
		[Vector3(0.014, 0.024, 0.014), Vector3(0, 0.05, -0.17), Color(0.08, 0.08, 0.08, 1)],
	],
	"Lance-roquettes": [
		[Vector3(0.22, 0.22, 1.3), Vector3(0, 0, -0.35), Color(0.2, 0.27, 0.18, 1)],
		[Vector3(0.3, 0.3, 0.22), Vector3(0, 0, -1.05), Color(1, 0.5, 0.08, 1)],
		[Vector3(0.24, 0.24, 0.12), Vector3(0, 0, 0.35), Color(0.08, 0.08, 0.09, 1)],
		[Vector3(0.06, 0.2, 0.08), Vector3(0, -0.2, -0), Color(0.08, 0.08, 0.09, 1)],
		[Vector3(0.05, 0.09, 0.22), Vector3(0, 0.17, -0.4), Color(0.08, 0.08, 0.09, 1)],
	],
}

const MAINS := [[Vector3(0.07, 0.07, 0.14), Vector3(0, -0.03, -0.32), Color(0.06, 0.06, 0.06, 1)], [Vector3(0.07, 0.09, 0.1), Vector3(0, -0.1, 0.1), Color(0.06, 0.06, 0.06, 1)]]

const MUZZLE := {"AR-15": Vector3(0, 0.01, -0.88), "Kriss Vector": Vector3(0, 0, -0.5), "DRS-50": Vector3(0, 0.01, -1.35), "Pompe": Vector3(0, 0.02, -0.9), "Pistolet": Vector3(0, 0.01, -0.23), "Lance-roquettes": Vector3(0, 0, -1.2)}
const FLASH := {"AR-15": [Color(1, 0.8, 0.3, 0.95), 0.24], "Kriss Vector": [Color(0.4, 0.95, 1, 0.95), 0.2], "DRS-50": [Color(0.85, 0.92, 1, 0.95), 0.45], "Pompe": [Color(1, 0.5, 0.1, 0.95), 0.5], "Pistolet": [Color(1, 0.95, 0.8, 0.95), 0.16], "Lance-roquettes": [Color(1, 0.6, 0.2, 0.9), 0.5]}
## position de la racine de l'arme quand on vise (alignement de la mire)
const ADS := {"AR-15": Vector3(0, -0.105, -0.8), "Kriss Vector": Vector3(0, -0.1, -0.62), "DRS-50": Vector3(0, -0.095, -0.85), "Pompe": Vector3(0, -0.065, -0.85), "Pistolet": Vector3(0, -0.05, -0.42), "Lance-roquettes": Vector3(0, -0.16, -0.7)}

const PLAQUE_TITAN := [[Vector3(0.14, 0.05, 0.5), Vector3(0, 0.1, -0.1), Color(0.75, 0.3, 0.075, 1)], [Vector3(0.09, 0.014, 0.4), Vector3(0, 0.045, -0.05), Color(1, 0.5, 0.08, 1)], [Vector3(0.12, 0.12, 0.05), Vector3(0, 0, -0.62), Color(0.55, 0.22, 0.055, 1)]]
const ECHELLE_TITAN := 2.6


static func ads(nom: String, titan := false) -> Vector3:
	var v: Vector3 = ADS.get(nom, ADS["Pistolet"])
	return v * (ECHELLE_TITAN if titan else 1.0)


## Construit le modèle 3D sous `parent` (sans éclairage : lisible de jour comme de nuit).
## Retourne la racine ; racine.get_meta("flash") = sphère du flash de bouche.
static func construire(nom: String, parent: Node3D, titan := false) -> Node3D:
	var racine := Node3D.new()
	racine.name = "Arme_" + nom
	parent.add_child(racine)
	var pieces: Array = MODELES.get(nom, MODELES["Pistolet"]).duplicate()
	pieces.append_array(MAINS)
	if titan:
		pieces.append_array(PLAQUE_TITAN)
		racine.scale = Vector3.ONE * ECHELLE_TITAN
	for p in pieces:
		racine.add_child(_boite(p[0], p[1], p[2]))
	var fl: Array = FLASH.get(nom, FLASH["AR-15"])
	var s := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = fl[1] * 0.5 * (1.4 if titan else 1.0)
	sm.height = fl[1] * (1.4 if titan else 1.0)
	s.mesh = sm
	s.material_override = _mat(fl[0])
	s.position = MUZZLE.get(nom, Vector3(0, 0, -0.5))
	s.visible = false
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	racine.add_child(s)
	racine.set_meta("flash", s)
	return racine


static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


static func _boite(taille: Vector3, pos: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = taille
	mi.mesh = bm
	mi.material_override = _mat(c)
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
