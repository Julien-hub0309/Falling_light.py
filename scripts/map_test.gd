extends Node
## Outil de dev : godot --headless --path . -- --maptest
## Vérifie la carte : nombre d'éléments, accès à pied à chaque toit, et à chaque étage de chaque
## bâtiment à intérieur (en partant de la porte), tour comprise.
var f := 0
var f0 := -1

func _physics_process(_dt: float) -> void:
	f += 1
	if not Nav.prete:
		return
	if f0 < 0:
		f0 = f
	if f - f0 < 30:
		return
	var carte: MapBuilder = get_parent().get_node("Carte")
	print("[map] détails : ", carte.stats, " toits=", Etat.toits.size(), " obstacles=", Etat.obstacles.size())
	var ok := 0
	var ko: Array = []
	for t in Etat.toits:
		var r := Nav.route(Vector3(-120, 0, -120), t)
		var bon := false
		if r.size() > 0:
			var l: Vector3 = r[r.size() - 1]
			bon = Vector2(l.x - t.x, l.z - t.z).length() < 3.5 and absf(l.y - t.y) < 1.5
		if bon:
			ok += 1
		else:
			ko.append(t.round())
	print("[map] toits accessibles à pied : ", ok, " / ", Etat.toits.size(), "  inaccessibles : ", ko)
	var etages_ok := 0
	var etages_tot := 0
	for it in carte.interieurs:
		var nn: int = it[4]
		var dep := Vector3(float(it[6]), 0.0, float(it[3]) + 6.0)
		for k in range(0, nn + 1):
			var p := Vector3(float(it[0]) + 2.2, float(it[5]) * k + 0.1, float(it[2]) + 3.0)
			if k == 0:
				p = Vector3(float(it[6]), 0.1, float(it[3]) - 2.6)
			etages_tot += 1
			var r := Nav.route(dep, p)
			if r.size() > 0:
				var l: Vector3 = r[r.size() - 1]
				if Vector2(l.x - p.x, l.z - p.z).length() < 2.5 and absf(l.y - p.y) < 1.2:
					etages_ok += 1
					continue
			print("[map]   inaccessible : bâtiment (%d,%d) niveau %d" % [(float(it[0]) + float(it[1])) * 0.5, (float(it[2]) + float(it[3])) * 0.5, k])
	print("[map] niveaux d'intérieur accessibles : ", etages_ok, " / ", etages_tot, " dans ", carte.interieurs.size(), " bâtiments")
	get_tree().quit()
