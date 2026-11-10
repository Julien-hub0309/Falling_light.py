import math
import random
from ursina import *
from partie import etat as E
import map.elements as EL
from map.elements import FL, B, bloc, gris, Facade
from map.loot import Loot

ROUTES = (-120, -60, 0, 60, 120)
CENTRES = (-150, -90, -30, 30, 90, 150)
LOOT_TOIT = ('arme', 'arme', 'armure', 'armure', 'soin', 'munitions', 'grenade')


def loot_toit(positions, n):
    for p in positions[:n]:
        Loot(p, random.choice(LOOT_TOIT))


# ------------------------------------------------------------------ sol, routes, enceinte
def sol_et_routes():
    A = E.DEMI_MAP
    B('sol').plan(-A - 70, A + 70, -A - 70, A + 70, 0, color.white, 8)
    for r in ROUTES:
        B('route').plan(r - 6, r + 6, -A, A, .03, color.white, (12, 16))
        B('route').plan(-A, A, r - 6, r + 6, .032, color.white, (12, 16), tourne=True)
    for ax in ROUTES:
        for az in ROUTES:
            B('blanc').plan(ax - 6, ax + 6, az - 6, az + 6, .05, gris(.2))
            for k in (-4.5, -3, -1.5, 0, 1.5, 3, 4.5):          # passages piétons
                for s in (-1, 1):
                    if s * 9.4 + ax < A:
                        B('blanc').plan(min(ax + s * 6.8, ax + s * 9.4), max(ax + s * 6.8, ax + s * 9.4),
                                        az + k - .3, az + k + .3, .06, gris(.8))
                    if s * 9.4 + az < A:
                        B('blanc').plan(ax + k - .3, ax + k + .3, min(az + s * 6.8, az + s * 9.4),
                                        max(az + s * 6.8, az + s * 9.4), .06, gris(.8))
    for cx in CENTRES:
        for cz in CENTRES:
            B('trottoir').plan(cx - 24, cx + 24, cz - 24, cz + 24, .04, color.white, 6)


def enceinte(rng):
    A = E.DEMI_MAP
    for (x, z, w, d) in ((0, A + 1, 2 * A + 4, 2), (0, -A - 1, 2 * A + 4, 2),
                         (A + 1, 0, 2, 2 * A + 4), (-A - 1, 0, 2, 2 * A + 4)):
        bloc(B('toit'), x - w / 2, x + w / 2, 0, 45, z - d / 2, z + d / 2, gris(.55))
    # silhouette de ville au-delà des murs (décor visuel, sans collision)
    for k in range(70):
        ang = rng.uniform(0, 6.283)
        dist = A + rng.uniform(25, 110)
        x, z = math.cos(ang) * dist * 1.0, math.sin(ang) * dist * 1.0
        if max(abs(x), abs(z)) < A + 15:
            continue
        w, d, h = rng.uniform(14, 30), rng.uniform(14, 30), rng.uniform(25, 95)
        st = rng.choice(('beton', 'verre', 'brique'))
        bloc(B(st), x - w / 2, x + w / 2, 0, h, z - d / 2, z + d / 2, gris(.85), haut=B('toit'), coll=False)


# ------------------------------------------------------------------ types de pâtés
def toit_complet(x0, z0, w, d, h, rng, n_loot=3, exclure=()):
    libres = EL.mobilier_toit(x0, z0, w, d, h, rng, exclure=exclure)
    loot_toit(libres, n_loot)


def cotes(rng, evite=()):
    """Façades dans un ordre aléatoire, en plaçant en dernier celles qui portent un pont."""
    c = ['N', 'S', 'E', 'W']
    rng.shuffle(c)
    return [x for x in c if x not in evite] + [x for x in c if x in evite]


def acces_immeuble(x0, z0, w, d, h, rng, cote_esc, cote_chaine, prof=.85):
    f = Facade(cote_esc, x0, z0, w, d)
    if rng.random() < .5:
        EL.escalier(f, h, 1.8, 1, prof=prof)
    else:
        EL.escalier(f, h, f.L - 1.8, -1, prof=prof)
    f2 = Facade(cote_chaine, x0, z0, w, d)
    if rng.random() < .5:
        EL.balcons(f2, h, 1.5, 1)
    else:
        EL.balcons(f2, h, f2.L - 1.5, -1)


def bloc_immeuble(cx, cz, e, rng, evite=()):
    x0, z0 = cx - 20, cz - 20
    st = rng.choice(('beton', 'beton', 'brique', 'verre'))
    h = EL.immeuble(x0, z0, 40, 40, e, st, rng)
    c = cotes(rng, evite)
    acces_immeuble(x0, z0, 40, 40, h, rng, c[0], c[1])
    toit_complet(x0, z0, 40, 40, h, rng, 2)
    return h


def bloc_lotissement(cx, cz, rng):
    lots = {}
    for i, lx in enumerate((cx - 21, cx + 3)):
        for j, lz in enumerate((cz - 21, cz + 3)):
            lots[(i, j)] = (lx, lz, rng.choice((2, 3, 4)))
    # hauteurs égales entre voisins -> passerelles entre toits
    if rng.random() < .6:
        lots[(1, 0)] = lots[(1, 0)][:2] + (lots[(0, 0)][2],)
    if rng.random() < .6:
        lots[(1, 1)] = lots[(1, 1)][:2] + (lots[(0, 1)][2],)
    if rng.random() < .6:
        lots[(0, 1)] = lots[(0, 1)][:2] + (lots[(0, 0)][2],)
    for (i, j), (lx, lz, e) in lots.items():
        st = rng.choice(('beton', 'brique', 'beton'))
        h = EL.immeuble(lx, lz, 18, 18, e, st, rng)
        ext_x, ext_z = ('W' if i == 0 else 'E'), ('S' if j == 0 else 'N')
        a, b = (ext_x, ext_z) if rng.random() < .5 else (ext_z, ext_x)
        acces_immeuble(lx, lz, 18, 18, h, rng, a, b, prof=.8)
        toit_complet(lx, lz, 18, 18, h, rng, 1)
    for (i, j) in ((0, 0), (0, 1)):                                   # ponts d'est en ouest
        A_, B_ = lots[(0, j)], lots[(1, j)]
        if A_[2] == B_[2]:
            h = A_[2] * FL
            EL.pont(A_[0] + 17.6, A_[1] + 9, B_[0] + .4, A_[1] + 9, h)
    for i in (0, 1):                                                  # ponts du sud au nord
        A_, B_ = lots[(i, 0)], lots[(i, 1)]
        if A_[2] == B_[2]:
            EL.pont(A_[0] + 9, A_[1] + 17.6, A_[0] + 9, B_[1] + .4, A_[2] * FL)


def bloc_tiers(cx, cz, rng, tour=False):
    x0, z0 = cx - 20, cz - 20
    h1 = EL.immeuble(x0, z0, 40, 40, 3, rng.choice(('beton', 'brique')), rng)
    c = cotes(rng)
    f = Facade(c[0], x0, z0, 40, 40)
    EL.escalier(f, h1, 1.8, 1)
    tw = 30 if tour else 24
    e2 = 15 if tour else rng.choice((6, 8, 10))
    tx0 = cx - tw / 2 + (0 if tour else rng.uniform(-3, 3))
    tz0 = cz - tw / 2 + (0 if tour else rng.uniform(-3, 3))
    h2 = EL.immeuble(tx0, tz0, tw, tw, e2, 'verre', rng, y_base=h1)
    ft = Facade(c[1], tx0, tz0, tw, tw)
    EL.balcons(ft, h2, 1.5, 1, y_depart=h1)
    ft2 = Facade(c[2], tx0, tz0, tw, tw)
    EL.balcons(ft2, h2, ft2.L - 1.5, -1, y_depart=h1)
    toit_complet(x0, z0, 40, 40, h1, rng, 2, exclure=[(tx0 - 3, tx0 + tw + 3, tz0 - 3, tz0 + tw + 3)])
    toit_complet(tx0, tz0, tw, tw, h2, rng, 2 if not tour else 4)
    if tour:                                                         # héliport + mâts
        B('blanc').plan(cx - 7, cx + 7, cz - 7, cz + 7, h2 + .03, gris(.3))
        B('blanc').plan(cx - 4, cx - 3, cz - 4, cz + 4, h2 + .05, color.yellow)
        B('blanc').plan(cx + 3, cx + 4, cz - 4, cz + 4, h2 + .05, color.yellow)
        B('blanc').plan(cx - 3, cx + 3, cz - .5, cz + .5, h2 + .05, color.yellow)
        for sx in (-1, 1):
            for sz in (-1, 1):
                bloc(B('lumiere'), cx + sx * 14 - .3, cx + sx * 14 + .3, h2 + .45, h2 + 1.0, cz + sz * 14 - .3,
                     cz + sz * 14 + .3, Color(1, .15, .1, 1), coll=False)
        bloc(B('metal'), cx - .15, cx + .15, h2, h2 + 16, cz + 10, cz + 10.3, gris(.35), coll=False)


def bloc_parc(cx, cz, rng):
    B('herbe').plan(cx - 21, cx + 21, cz - 21, cz + 21, .045, color.white, 6)
    B('trottoir').plan(cx - 1.6, cx + 1.6, cz - 21, cz + 21, .05, color.white, 6)
    B('trottoir').plan(cx - 21, cx + 21, cz - 1.6, cz + 1.6, .052, color.white, 6)
    bloc(B('toit'), cx - 4.5, cx + 4.5, 0, .7, cz - 4.5, cz + 4.5, gris(.6))               # fontaine
    B('blanc').plan(cx - 3.8, cx + 3.8, cz - 3.8, cz + 3.8, .62, color.hsv(200, .5, .45))
    bloc(B('toit'), cx - .7, cx + .7, .7, 4.5, cz - .7, cz + .7, gris(.5))
    for _ in range(18):
        x, z = cx + rng.uniform(-20, 20), cz + rng.uniform(-20, 20)
        if abs(x - cx) > 2.5 and abs(z - cz) > 2.5 and E.hits(x, 0, z, 1, 3) is None:
            EL.arbre_mort(x, z, rng)
    for _ in range(7):
        x, z = cx + rng.uniform(-18, 18), cz + rng.uniform(-18, 18)
        if E.hits(x, 0, z, 1.5, 1) is None:
            bloc(B('bois'), x - 1, x + 1, 0, .5, z - .35, z + .35, color.white)
    # pavillon à escalader + couvertures
    px, pz = cx + 11, cz + 11
    h = EL.immeuble(px, pz, 8, 8, 1, 'brique', rng)
    EL.balcons(Facade('W', px, pz, 8, 8), h, 1.2, 1)
    EL.balcons(Facade('S', px, pz, 8, 8), h, 6.8, -1)
    loot_toit([Vec3(px + 4, h, pz + 4)], 1)
    for _ in range(6):
        EL.barriere(cx + rng.uniform(-17, 17), cz + rng.uniform(-17, 17), 4, rng.random() < .5)


def ossature(x0, z0, w, d, niveaux, rng, garde_corps=True, couleur=None):
    """Parking / chantier à étages (dalles + piliers + rampes en marches). Enregistre l'accès
    praticable par les bots jusqu'au dernier niveau. Retourne la hauteur du dernier niveau."""
    x1, z1 = x0 + w, z0 + d
    toit, ep = B('toit'), .5
    col = couleur or gris(.55)

    def rampe(k):
        sw = (k % 2 == 1)
        return (x0 + 2, x0 + 9.4, z0 + 2, z0 + 6) if sw else (x1 - 9.4, x1 - 2, z1 - 6, z1 - 2)

    rects = [rampe(k) for k in range(1, niveaux + 1)]
    for i in range(1, int(w // 8)):                                  # piliers
        for j in range(1, int(d // 8)):
            px, pz = x0 + 8 * i - 4 + 4, z0 + 8 * j - 4 + 4
            px, pz = x0 + 4 + 8 * (i - 1), z0 + 4 + 8 * (j - 1)
            if all(not (r[0] - 1.5 < px < r[1] + 1.5 and r[2] - 1.5 < pz < r[3] + 1.5) for r in rects) \
                    and px < x1 - 2 and pz < z1 - 2:
                bloc(toit, px - .5, px + .5, 0, niveaux * FL, pz - .5, pz + .5, gris(.5))
    for k in range(1, niveaux + 1):
        top = k * FL
        hx0, hx1, hz0, hz1 = rects[k - 1]
        hx0, hx1, hz0, hz1 = hx0 - .4, hx1 + .1, hz0 - .4, hz1 + .4      # trou au-dessus de la rampe
        for (a0, a1, b0, b1) in ((x0, hx0, z0, z1), (hx1, x1, z0, z1), (hx0, hx1, z0, hz0), (hx0, hx1, hz1, z1)):
            if a1 - a0 > .1 and b1 - b0 > .1:
                bloc(toit, a0, a1, top - ep, top, b0, b1, col)
        n = 8
        r = rects[k - 1]
        mh = FL / n
        for i in range(n):                                          # marches de la rampe
            if k % 2 == 1:
                a, b = r[0] + i * .9, r[0] + (i + 1) * .9 + (.2 if i == n - 1 else 0)
            else:
                a, b = r[1] - (i + 1) * .9 - (.2 if i == n - 1 else 0), r[1] - i * .9
            bloc(toit, a, b, top - FL, top - FL + mh * (i + 1), r[2], r[3], gris(.5))
        if garde_corps:                                             # parapets
            t, ph = .4, .8 if k == niveaux else .6
            bloc(toit, x0, x1, top, top + ph, z0, z0 + t, gris(.5), coll=True)
            bloc(toit, x0, x1, top, top + ph, z1 - t, z1, gris(.5))
            bloc(toit, x0, x0 + t, top, top + ph, z0 + t, z1 - t, gris(.5))
            bloc(toit, x1 - t, x1, top, top + ph, z0 + t, z1 - t, gris(.5))
        for _ in range(3):                                          # couvertures sur la dalle
            bx, bz = rng.uniform(x0 + 14, x1 - 14), rng.uniform(z0 + 14, z1 - 14)
            EL.barriere(bx, bz, 4, rng.random() < .5, y0=top)
        loot_toit([Vec3(rng.uniform(x0 + 11, x1 - 11), top, rng.uniform(z0 + 11, z1 - 11)) for _ in range(3)], 1)
    # chemins pour bots / zombies
    base = Vec3(x0 + .8, 0, z0 + 4)
    pts, y = [], 0
    for k in range(1, niveaux + 1):
        r = rects[k - 1]
        top = k * FL
        if k % 2 == 1:
            pts += [Vec3(r[0] + .1, 0, (r[2] + r[3]) / 2) if k > 1 else Vec3(r[0] + .1, 0, (r[2] + r[3]) / 2),
                    Vec3(r[1] - .3, top, (r[2] + r[3]) / 2)]
            suite = [Vec3(x0 + 10, top, z0 + 8), Vec3(x1 - 1, top, z0 + 8), Vec3(x1 - 1, top, z1 - 4)]
        else:
            pts += [Vec3(r[1] - .1, top - FL, (r[2] + r[3]) / 2), Vec3(r[0] + .3, top, (r[2] + r[3]) / 2)]
            suite = [Vec3(x1 - 10, top, z1 - 8), Vec3(x0 + 1, top, z1 - 8), Vec3(x0 + 1, top, z0 + 4)]
        if k < niveaux:
            pts += suite
        else:
            fin = r[1] + 1.8 if k % 2 == 1 else r[0] - 1.8
            pts += [Vec3(fin, top, (r[2] + r[3]) / 2)]
        E.acces_toit.append(dict(base=base, pts=list(pts), toit=pts[-1], y=top))
    return niveaux * FL


def bloc_parking(cx, cz, rng):
    ossature(cx - 20, cz - 20, 40, 40, 2, rng)
    for _ in range(5):
        EL.vehicule(cx + rng.uniform(-17, 17), cz + rng.uniform(-17, 17), rng.random() < .5, rng, 'voiture')


def bloc_chantier(cx, cz, rng):
    ossature(cx - 17, cz - 17, 32, 32, 3, rng, garde_corps=False, couleur=gris(.45))
    mx, mz = cx + 19, cz + 19                                         # grue
    bloc(B('metal'), mx - .8, mx + .8, 0, 42, mz - .8, mz + .8, color.hsv(48, .85, .85))
    bloc(B('metal'), mx - 32, mx + 6, 40, 41.4, mz - .7, mz + .7, color.hsv(48, .85, .85), coll=False)
    bloc(B('metal'), mx + 6, mx + 11, 38.8, 40, mz - 1, mz + 1, gris(.3), coll=False)
    bloc(B('metal'), mx - 24 - .05, mx - 24 + .05, 30, 40, mz - .05, mz + .05, gris(.2), coll=False)
    for k in range(4):                                                # conteneurs empilés (côté est)
        z = cz - 15 + k * 7
        for lvl in range(2):
            EL.bloc(B('metal'), cx + 18.1, cx + 20.5, lvl * 2.6, (lvl + 1) * 2.6, z - 3, z + 3,
                    color.hsv(rng.choice((0, 25, 110, 210)), .6, .6), haut=B('metal'))
    for _ in range(8):
        EL.gravats(cx + rng.uniform(-19, 19), cz + rng.uniform(-19, 19), rng, 2, 1.5)


def bloc_ruines(cx, cz, rng):
    for (ox, oz) in ((-11, -11), (11, -11), (-11, 11), (11, 11)):
        if rng.random() < .25:
            continue
        x0, z0, w, d = cx + ox - 8, cz + oz - 8, 16, 16
        t = .6
        for side in 'NSEW':                                           # murs percés
            f = Facade(side, x0, z0, w, d)
            u = 0
            while u < f.L - .5:
                seg = min(rng.uniform(3, 6), f.L - u)
                if rng.random() < .7:
                    hh = rng.choice((3.3, 6.6, 6.6))
                    f.box(B('brique'), u, u + seg, -t, 0, 0, hh, gris(.9), haut=B('toit'))
                u += seg + rng.uniform(1.8, 3.5)
        # étage partiel + escalier intérieur
        bloc(B('toit'), x0 + .6, x0 + w - .6, 3.0, 3.3, z0 + .6, z0 + d / 2, gris(.5))
        for i in range(8):
            a = x0 + 1 + i * .9
            bloc(B('toit'), a, a + .9, 0, .41 * (i + 1), z0 + d / 2 + 1.5, z0 + d / 2 + 3.5, gris(.5))
        bloc(B('toit'), x0 + 8.2, x0 + 9.6, 0, 3.3, z0 + d / 2 + 1.5, z0 + d / 2 + 3.5, gris(.5))
        gravats(x0 + w / 2, z0 + d / 2, rng, 5, 7)
        Loot(Vec3(x0 + 4, 3.3, z0 + 3), random.choice(LOOT_TOIT))
    EL.gravats(cx, cz, rng, 10, 18)


def gravats(x, z, rng, n, r):
    EL.gravats(x, z, rng, n, r)


# ------------------------------------------------------------------ décor des rues
def decor_rues(rng):
    A = E.DEMI_MAP
    for r in ROUTES:
        for k, t in enumerate(range(-A + 15, A - 10, 30)):
            if min(abs(t - a) for a in ROUTES) < 9:
                continue
            c = 1 if k % 2 == 0 else -1
            EL.lampadaire(r + 6.9 * c, t, -c, 'x')
            EL.lampadaire(t, r + 6.9 * c, -c, 'z')
    for ax in ROUTES:
        for az in ROUTES:
            for sx, sz in ((1, 1), (-1, -1)):
                EL.feu_tricolore(ax + sx * 6.8, az + sz * 6.8)
    for _ in range(85):                                               # épaves sur les routes
        r = rng.choice(ROUTES)
        t = rng.uniform(-A + 12, A - 12)
        if min(abs(t - a) for a in ROUTES) < 11:
            continue
        lane = rng.choice((-1, 1)) * rng.uniform(2.6, 4.6)
        if rng.random() < .5:
            EL.vehicule(r + lane, t, True, rng)
        else:
            EL.vehicule(t, r + lane, False, rng)
    for _ in range(26):                                               # chicanes / barrages
        r = rng.choice(ROUTES)
        t = rng.uniform(-A + 14, A - 14)
        if min(abs(t - a) for a in ROUTES) < 12:
            continue
        s = rng.choice((-1, 1))
        if rng.random() < .5:
            EL.barriere(r + s * 3.8, t, 4, True)
            EL.barriere(r - s * 3.8, t + 6, 4, True)
        else:
            EL.barriere(t, r + s * 3.8, 4, False)
            EL.barriere(t + 6, r - s * 3.8, 4, False)
    for _ in range(70):                                               # arbres morts, poubelles
        r = rng.choice(ROUTES)
        t = rng.uniform(-A + 10, A - 10)
        if min(abs(t - a) for a in ROUTES) < 9:
            continue
        s = rng.choice((-1, 1))
        x, z = (r + s * 7.4, t) if rng.random() < .5 else (t, r + s * 7.4)
        if E.hits(x, 0, z, 1.2, 3) is None:
            (EL.arbre_mort(x, z, rng) if rng.random() < .55 else EL.poubelle(x, z, rng))
    for _ in range(26):
        EL.gravats(rng.uniform(-A + 12, A - 12), rng.uniform(-A + 12, A - 12), rng, 4, 3)


# ------------------------------------------------------------------ assemblage
def construire_map():
    random.seed(3)
    rng = random.Random(11)
    E.boxes.clear()
    E.grille.clear()
    E.acces_toit.clear()
    EL.init_batches()
    A = E.DEMI_MAP

    sol_et_routes()
    enceinte(rng)

    types = {}
    for i in range(6):
        for j in range(6):
            types[(i, j)] = dict(t=rng.choices(['immeuble', 'lotissement', 'tiers', 'ruines', 'parc'],
                                               [3, 4, 2, 1.2, .7])[0], e=rng.choice((4, 5, 6, 7, 8)))
    types[(3, 3)] = dict(t='tour', e=0)
    types[(2, 2)] = dict(t='parc', e=0)
    types[(4, 1)] = dict(t='parking', e=0)
    types[(1, 4)] = dict(t='chantier', e=0)
    ponts = []
    for i in range(6):
        for j in range(6):
            for (di, dj) in ((1, 0), (0, 1)):
                a, b = types[(i, j)], types.get((i + di, j + dj))
                if b and a['t'] == 'immeuble' and b['t'] == 'immeuble' and rng.random() < .6:
                    b['e'] = a['e']
                    ponts.append(((i, j), (i + di, j + dj)))
                    sa, sb = ('E', 'W') if di else ('N', 'S')
                    a.setdefault('evite', set()).add(sa)
                    b.setdefault('evite', set()).add(sb)
    for (i, cx) in enumerate(CENTRES):
        for (j, cz) in enumerate(CENTRES):
            d = types[(i, j)]
            t = d['t']
            if t == 'immeuble':
                bloc_immeuble(cx, cz, d['e'], rng, d.get('evite', ()))
            elif t == 'lotissement':
                bloc_lotissement(cx, cz, rng)
            elif t == 'tiers':
                bloc_tiers(cx, cz, rng)
            elif t == 'tour':
                bloc_tiers(cx, cz, rng, tour=True)
            elif t == 'parc':
                bloc_parc(cx, cz, rng)
            elif t == 'parking':
                bloc_parking(cx, cz, rng)
            elif t == 'chantier':
                bloc_chantier(cx, cz, rng)
            else:
                bloc_ruines(cx, cz, rng)
    for (a, b) in ponts:                                              # ponts au-dessus des rues
        (i, j), (i2, j2) = a, b
        h = types[a]['e'] * FL
        ca, cb = (CENTRES[i], CENTRES[j]), (CENTRES[i2], CENTRES[j2])
        off = rng.uniform(-8, 8)
        if i2 != i:
            EL.pont(ca[0] + 19.6, ca[1] + off, cb[0] - 19.6, ca[1] + off, h, 3.2)
        else:
            EL.pont(ca[0] + off, ca[1] + 19.6, ca[0] + off, cb[1] - 19.6, h, 3.2)

    decor_rues(rng)
    EL.W.construire()

    # points d'apparition : intersections des quatre coins + centre
    E.spawns.clear()
    for (sx, sz) in ((-120, -120), (120, -120), (120, 120), (-120, 120), (0, 0)):
        E.spawns.append(Vec3(sx, 0, sz))
    for _ in range(45):                                               # loot au sol
        Loot(E.point_libre(1.2), None)
