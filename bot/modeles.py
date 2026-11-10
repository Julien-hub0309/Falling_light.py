"""modeles.py (bot) - Personnages articulés : pilotes (casque, gilet, sac, visière) et
zombies (bras tendus, yeux brillants). Retourne un dict de pièces pour l'animation.

OPTIMISATION : un personnage n'est plus ~15 cubes (15 draw calls) mais 6 à 8 pièces. Chaque
membre / le torse est UN maillage fusionné (couleurs dans les sommets), fabriqué une seule fois
puis dupliqué avec partage de la géométrie (copy_to) : peu d'appels de rendu et création quasi gratuite."""
from panda3d.core import NodePath
from ursina import *
import parametres.graphismes as G

# ---- géométrie d'un cube ------------------------------------------------------
_FACES = (((1, 0, 0), ((1, -1, -1), (1, -1, 1), (1, 1, 1), (1, 1, -1))),
          ((-1, 0, 0), ((-1, -1, -1), (-1, -1, 1), (-1, 1, 1), (-1, 1, -1))),
          ((0, 1, 0), ((-1, 1, -1), (1, 1, -1), (1, 1, 1), (-1, 1, 1))),
          ((0, -1, 0), ((-1, -1, -1), (1, -1, -1), (1, -1, 1), (-1, -1, 1))),
          ((0, 0, 1), ((-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1))),
          ((0, 0, -1), ((-1, -1, -1), (1, -1, -1), (1, 1, -1), (-1, 1, -1))))
_maitres = {}


def _cuire(pieces):
    """pieces = [(échelle, position, couleur)] -> Mesh unique (couleurs par sommet)."""
    V, N, C, T, U = [], [], [], [], []
    for sc, pos, col in pieces:
        col = Color(col[0], col[1], col[2], 1)
        for n, coins in _FACES:
            pts = [(pos[0] + cx * sc[0] / 2, pos[1] + cy * sc[1] / 2, pos[2] + cz * sc[2] / 2) for cx, cy, cz in coins]
            a = (pts[1][0] - pts[0][0], pts[1][1] - pts[0][1], pts[1][2] - pts[0][2])
            b = (pts[2][0] - pts[0][0], pts[2][1] - pts[0][1], pts[2][2] - pts[0][2])
            cr = (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])
            if cr[0] * n[0] + cr[1] * n[1] + cr[2] * n[2] > 0:       # enroulement horaire vu de l'extérieur
                pts.reverse()
            i = len(V)
            V += pts
            N += [n] * 4
            C += [col] * 4
            U += [(0, 0)] * 4
            T += [(i, i + 1, i + 2), (i, i + 2, i + 3)]
    return Mesh(vertices=V, triangles=T, normals=N, colors=C, uvs=U, static=True)


def _cle(col):
    return (round(float(col[0]), 2), round(float(col[1]), 2), round(float(col[2]), 2))


def _piece(parent, cle, pieces, **kw):
    """Entité 'pièce' : maillage fusionné partagé entre tous les personnages de même clé."""
    m = _maitres.get(cle)
    if m is None:
        m = _maitres[cle] = _cuire(pieces)
    inst = m.copy_to(NodePath('inst'))
    inst.detach_node()
    return G.solide(parent=parent, model=inst, **kw)


def _c(parent, sc, pos, col, **kw):
    return G.solide(parent=parent, model='cube', scale=sc, position=pos, color=col, **kw)


def humanoide(racine, veste, pantalon, peau, botte=None, pilote=True):
    """Construit le personnage sous `racine`. Clés : jambes[2], bras[2], torse, tete, (yeux | fusil).
    Les couleurs de veste/pantalon/botte/peau sont dans les sommets : torse.color reste blanc
    (le passer à une valeur > 1 fait un flash de dégâts)."""
    m = {'jambes': [], 'bras': []}
    botte = botte or color.hsv(0, 0, .1)
    kj = ('jambe', _cle(pantalon), _cle(botte))
    pj = [((.26, .88, .3), (0, -.44, 0), pantalon), ((.28, .14, .42), (0, -.84, .06), botte)]
    for sx in (-1, 1):
        piv = Entity(parent=racine, position=(sx * .18, .88, 0), ignore=True)
        _piece(piv, kj, pj)
        m['jambes'].append(piv)
    ceinture = color.hsv(30, .3, .2)
    pt = [((.74, .72, .4), (0, 1.26, 0), veste), ((.7, .12, .38), (0, .93, 0), ceinture)]
    if pilote:
        pt += [((.4, .2, .4), (0, 1.99, -.01), veste),                        # casque
               ((.3, .09, .05), (0, 1.85, .18), Color(.3, .9, 1, 1)),          # visière lumineuse
               ((.5, .55, .22), (0, 1.3, -.3), color.hsv(0, 0, .13))]          # sac à dos
    m['torse'] = _piece(racine, ('torse', pilote, _cle(veste)), pt, name='torse')
    main = color.hsv(0, 0, .08) if pilote else peau
    ka = ('bras', _cle(veste), _cle(main))
    pa = [((.2, .72, .22), (0, -.34, 0), veste), ((.16, .16, .18), (0, -.74, 0), main)]
    for sx in (-1, 1):
        piv = Entity(parent=racine, position=(sx * .47, 1.55, 0), ignore=True)
        _piece(piv, ka, pa)
        m['bras'].append(piv)
    m['tete'] = _piece(racine, ('tete',), [((.34, .36, .34), (0, 0, 0), (1, 1, 1))], position=(0, 1.84, 0), color=peau)
    if pilote:
        m['fusil'] = _c(racine, (.1, .12, .75), (.3, 1.05, .45), color.hsv(0, 0, .1))   # fusil
        m['bras'][1].rotation_x = -75
    else:
        for b in m['bras']:
            b.rotation_x = -80
        m['yeux'] = [_piece(racine, ('yeux',), [((.07, .05, .04), (sx * .08, 1.88, .18), (1, 1, 1)) for sx in (-1, 1)],
                            color=Color(1, .8, .1, 1))]
        m['tete'].rotation_z = 8
    return m
