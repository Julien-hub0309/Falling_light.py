class_name Nav
extends RefCounted
## Navigation (bot/navigation.py) : NavigationMesh cuit au démarrage à partir des collisions du
## monde (sol, rampes, toits). Remplace le graphe d'escaliers maison.
## Tant que le cuisson n'est pas finie, les fonctions retombent sur un comportement direct.

static var region: NavigationRegion3D = null
static var prete := false
static var carte_gros: RID
static var prete_gros := false


static func cuire(racine: Node3D, parent: Node) -> void:
	prete = false
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = Etat.COUCHE_MONDE
	nm.cell_size = 0.5
	nm.cell_height = 0.25
	nm.agent_height = 2.0
	nm.agent_radius = 0.5
	nm.agent_max_climb = 0.5
	nm.agent_max_slope = 50.0
	nm.edge_max_error = 0.6                # fidélité (escaliers, paliers étroits)
	nm.region_min_size = 1.0
	var src := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, src, racine)
	var carte_nav: RID = parent.get_world_3d().navigation_map
	NavigationServer3D.map_set_cell_size(carte_nav, nm.cell_size)      # doit égaler celui du bake
	NavigationServer3D.map_set_cell_height(carte_nav, nm.cell_height)
	var fin := func():
		region = NavigationRegion3D.new()
		region.navigation_mesh = nm
		parent.add_child(region)
		prete = true
		print("[nav] navmesh prêt : ", nm.get_polygon_count(), " polygones")
	NavigationServer3D.bake_from_source_geometry_data_async(nm, src, fin)
	# 2e maillage pour les GROS gabarits (Titan : rayon 2 m, hauteur 6 m => pas d'intérieurs ni de ruelles étroites)
	prete_gros = false
	var nm2 := NavigationMesh.new()
	nm2.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm2.geometry_collision_mask = Etat.COUCHE_MONDE
	nm2.cell_size = 0.5
	nm2.cell_height = 0.25
	nm2.agent_height = 6.0
	nm2.agent_radius = 2.0
	nm2.agent_max_climb = 0.5
	nm2.agent_max_slope = 40.0
	nm2.edge_max_error = 0.8
	carte_gros = NavigationServer3D.map_create()
	NavigationServer3D.map_set_cell_size(carte_gros, nm2.cell_size)
	NavigationServer3D.map_set_cell_height(carte_gros, nm2.cell_height)
	NavigationServer3D.map_set_active(carte_gros, true)
	var fin2 := func():
		var reg := NavigationServer3D.region_create()
		NavigationServer3D.region_set_map(reg, carte_gros)
		NavigationServer3D.region_set_navigation_mesh(reg, nm2)
		prete_gros = true
		print("[nav] navmesh gros gabarit prêt : ", nm2.get_polygon_count(), " polygones")
	NavigationServer3D.bake_from_source_geometry_data_async(nm2, src, fin2)


## Chemin (liste de points, sans le point de départ). Vide si pas de navmesh / pas de chemin.
static func route(depuis: Vector3, vers: Vector3) -> Array:
	if not prete or region == null:
		return []
	var carte := region.get_navigation_map()
	var chemin := NavigationServer3D.map_get_path(carte, depuis, vers, true)
	var res: Array = []
	for i in range(1, chemin.size()):
		res.append(chemin[i])
	return res


## Le point est-il (à peu près) sur une zone praticable ?
static func joignable(p: Vector3) -> bool:
	if not prete or region == null:
		return true
	var c := NavigationServer3D.map_get_closest_point(region.get_navigation_map(), p)
	return c.distance_to(p) < 2.5


## Point praticable le plus proche de `p` (pour les ordres au Titan : on ne l'envoie pas dans un mur).
static func proche(p: Vector3) -> Vector3:
	if not prete or region == null:
		return p
	return NavigationServer3D.map_get_closest_point(region.get_navigation_map(), p)


## Chemin pour un gros gabarit (Titan), sans le point de départ.
static func route_gros(depuis: Vector3, vers: Vector3) -> Array:
	if not prete_gros:
		return []
	var chemin := NavigationServer3D.map_get_path(carte_gros, depuis, vers, true)
	var res: Array = []
	for i in range(1, chemin.size()):
		res.append(chemin[i])
	return res


static func proche_gros(p: Vector3) -> Vector3:
	if not prete_gros:
		return p
	return NavigationServer3D.map_get_closest_point(carte_gros, p)
