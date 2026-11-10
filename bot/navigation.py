"""navigation.py - Itinéraires pour bots et zombies : grille des routes (intersections) +
escaliers menant aux toits. route() renvoie une liste de points à suivre."""
import math
from collections import deque
from ursina import Vec3
from partie import etat as E

AXES = (-120, -60, 0, 60, 120)          # axes des routes (même valeurs que map.py)


def _idx(v):
    return min(range(len(AXES)), key=lambda i: abs(AXES[i] - v))


def _proj_route(p):
    """Point de la route (axe) le plus proche d'une position."""
    ix, iz = _idx(p.x), _idx(p.z)
    if abs(p.x - AXES[ix]) < abs(p.z - AXES[iz]):
        return Vec3(AXES[ix], 0, p.z)
    return Vec3(p.x, 0, AXES[iz])


def _chemin_noeuds(a, b):
    s, g = (_idx(a.x), _idx(a.z)), (_idx(b.x), _idx(b.z))
    prev, file = {s: None}, deque([s])
    while file:
        c = file.popleft()
        if c == g:
            break
        for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (c[0] + dx, c[1] + dz)
            if 0 <= n[0] < len(AXES) and 0 <= n[1] < len(AXES) and n not in prev:
                prev[n] = c
                file.append(n)
    chemin, c = [], g
    while c is not None:
        chemin.append(Vec3(AXES[c[0]], 0, AXES[c[1]]))
        c = prev.get(c)
    return chemin[::-1]


def vers_sol(a, b):
    """Route au sol de a vers b : tout droit si dégagé, sinon par les rues."""
    if E.libre(a, b):
        return [b]
    pa, pb = _proj_route(a), _proj_route(b)
    return [pa] + _chemin_noeuds(pa, pb) + [pb, b]


def acces_possible(y):
    return any(abs(a['y'] - y) < 4 for a in E.acces_toit)


def route(depart, but, but_y=0):
    """Itinéraire vers `but` (au sol ou sur un toit accessible par escalier)."""
    if but_y > 2.5 and E.acces_toit:
        cands = [a for a in E.acces_toit if abs(a['y'] - but_y) < 4]
        if cands:
            a = min(cands, key=lambda a: math.hypot(a['toit'].x - but.x, a['toit'].z - but.z))
            if math.hypot(a['toit'].x - but.x, a['toit'].z - but.z) < 60:
                return vers_sol(depart, a['base']) + list(a['pts']) + [but]
    return vers_sol(depart, but)


def joignable(x, z, y):
    """Un bot peut-il atteindre ce point ? (sol, ou toit dont un escalier est proche)"""
    if y <= 2.5:
        return True
    return any(abs(a['y'] - y) < 4 and math.hypot(a['toit'].x - x, a['toit'].z - z) < 45 for a in E.acces_toit)
