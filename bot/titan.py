"""titan.py (bot) - Ordres SIMPLES donnés au Titan quand le pilote n'est pas à bord.

    suivre    le Titan reste près du pilote et tire sur ce qui approche (ordre par défaut)
    garder    le Titan tient sa position : il ne bouge plus mais tire / frappe ce qui est à portée
    aller     le Titan va au point visé par le pilote (en tirant en chemin), puis garde la position
    attaquer  le Titan fonce sur l'ennemi le plus proche (épée au contact, canon sinon)

Touches : voir parametres/clavier.py (ordre_suivre, ordre_garder, ordre_aller, ordre_attaquer)."""
from ursina import Vec3, camera
from partie import etat as E

ORDRES = {'suivre': 'SUIVRE', 'garder': 'GARDER LA POSITION', 'aller': 'ALLER AU POINT', 'attaquer': 'ATTAQUER'}


def point_vise(portee=220):
    """Point de la carte visé par la caméra du joueur (None si on vise le ciel)."""
    o, d = camera.world_position, camera.forward
    t = E.ray_world(o, d, portee)
    if t >= portee - 1e-3 and d.y >= -.02:
        return None
    p = o + d * t
    lim = E.DEMI_MAP - 6
    return Vec3(max(-lim, min(lim, p.x)), 0, max(-lim, min(lim, p.z)))


def donner_ordre(pilote, ordre):
    """Donne un ordre au Titan de `pilote`. True si l'ordre est accepté."""
    t = pilote.titan
    joueur = pilote is E.joueur
    if t is None or not t.vivant:
        if joueur:
            E.msg("Pas de Titan à commander")
        return False
    if pilote.mode == 'titan' or t.state != 'ready':
        if joueur and t.state == 'falling':
            E.msg("Le Titan est encore en chute")
        return False
    point = None
    if ordre == 'aller':
        point = point_vise()
        if point is None:
            if joueur:
                E.msg("Vise le sol pour désigner un point")
            return False
    t.ordonner(ordre, point)
    if joueur:
        E.msg(f'Titan : {ORDRES[ordre]}')
    return True
