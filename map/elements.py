import math
import random
from ursina import *
from partie import etat as E
from map.batch import Monde

FL = 3.3          # hauteur d'un étage
MARCHE = .45      # hauteur d'une marche (franchissable sans sauter)
W = Monde()


def init_batches():
    W.b.clear()
    W.batch('beton', 'facade', 13.2)
    W.batch('brique', 'brique', 13.2)
    W.batch('verre', 'verre', 13.2)
    W.batch('toit', 'toit', 4)
    W.batch('metal', 'metal', 2)
    W.batch('bois', 'bois', 2)
    W.batch('sol', 'sol', 8)
    W.batch('route', 'route', (12, 16))
    W.batch('trottoir', 'trottoir', 6)
    W.batch('herbe', 'herbe', 6)
    W.batch('blanc', None, 4)
    W.batch('lumiere', None, 4, emissif=True)


def B(nom):
    return W.b[nom]


def gris(v):
    return color.hsv(0, 0, v)


def bloc(bat, x0, x1, y0, y1, z0, z1, col, haut=None, ch=None, coll=True):
    bat.box(x0, x1, y0, y1, z0, z1, col, haut=haut, col_haut=ch)
    if coll:
        E.ajouter_box(x0, x1, z0, z1, y0, y1)


class Facade:
    """Repère local d'une façade : u le long du mur, v vers l'extérieur."""
    def __init__(self, side, x0, z0, w, d):
        self.side, self.x0, self.z0, self.w, self.d = side, x0, z0, w, d
        self.L = w if side in 'NS' else d

    def xz(self, u, v):
        s = self.side
        if s == 'S':
            return self.x0 + u, self.z0 - v
        if s == 'N':
            return self.x0 + u, self.z0 + self.d + v
        if s == 'W':
            return self.x0 - v, self.z0 + u
        return self.x0 + self.w + v, self.z0 + u

    def box(self, bat, ua, ub, va, vb, y0, y1, col, haut=None, coll=True):
        xa, za = self.xz(ua, va)
        xb, zb = self.xz(ub, vb)
        bloc(bat, min(xa, xb), max(xa, xb), y0, y1, min(za, zb), max(za, zb), col, haut, coll=coll)

    def pt(self, u, v, y=0):
        x, z = self.xz(u, v)
        return Vec3(x, y, z)


# ------------------------------------------------------------------ immeubles
def parapet(x0, z0, w, d, h, col=None):
    col = col or gris(.5)
    t, ph = .35, .45
    toit = B('toit')
    bloc(toit, x0, x0 + w, h, h + ph, z0, z0 + t, col)
    bloc(toit, x0, x0 + w, h, h + ph, z0 + d - t, z0 + d, col)
    bloc(toit, x0, x0 + t, h, h + ph, z0 + t, z0 + d - t, col)
    bloc(toit, x0 + w - t, x0 + w, h, h + ph, z0 + t, z0 + d - t, col)


def immeuble(x0, z0, w, d, e, style, rng, y_base=0, tint=None):
    """Immeuble de `e` étages posé à y_base (corniche, soubassement, parapet). Retourne le y du toit."""
    h = y_base + e * FL
    bat = B(style)
    if tint is None:
        tint = (color.hsv(rng.choice((30, 40, 200, 215, 0)), rng.uniform(.03, .12), rng.uniform(.82, 1))
                if style == 'beton' else color.hsv(0, 0, rng.uniform(.88, 1)))
    bloc(bat, x0, x0 + w, y_base, h - .4, z0, z0 + d, tint, haut=B('toit'), coll=False)
    E.ajouter_box(x0, x0 + w, z0, z0 + d, y_base, h)
    bloc(B('toit'), x0 - .3, x0 + w + .3, h - .4, h, z0 - .3, z0 + d + .3, gris(.62), coll=False)
    if y_base == 0:
        bloc(B('toit'), x0 - .12, x0 + w + .12, 0, .9, z0 - .12, z0 + d + .12, gris(.32), coll=False)
    parapet(x0, z0, w, d, h)
    return h


# ------------------------------------------------------------------ accès aux toits
def escalier(fac, h, u0, sens=1, prof=.85, larg=2.2, y_depart=0, enregistrer=True):
    """Escalier extérieur (marches de .45). Droit si la façade est assez longue, sinon en
    zigzag (deux volées + palier + passerelle vers le toit). Praticable par bots/zombies."""
    n = math.ceil((h - y_depart) / MARCHE)
    mh = (h - y_depart) / n
    col, toit, bat = gris(.55), B('toit'), B('toit')
    pts = []
    if n * prof + 3 <= fac.L:
        for i in range(n):
            a, b = u0 + sens * i * prof, u0 + sens * (i + 1) * prof
            fac.box(bat, min(a, b), max(a, b), 0, larg, y_depart if y_depart else 0,
                    y_depart + mh * (i + 1), col, haut=toit)
        base = fac.pt(u0 - sens * 1.8, larg / 2)
        ue = u0 + sens * (n - .5) * prof
        pts = [fac.pt(ue, larg / 2, h), fac.pt(ue, -2.2, h)]
    else:
        n1 = math.ceil(n / 2)
        n2 = n - n1
        for i in range(n1):
            a, b = u0 + sens * i * prof, u0 + sens * (i + 1) * prof
            fac.box(bat, min(a, b), max(a, b), 0, larg, 0, y_depart + mh * (i + 1), col, haut=toit)
        l0 = u0 + sens * n1 * prof
        l1 = l0 + sens * 2.4
        fac.box(bat, min(l0, l1), max(l0, l1), 0, 2 * larg, 0, y_depart + mh * n1, col, haut=toit)
        for i in range(n2):
            a, b = l0 - sens * i * prof, l0 - sens * (i + 1) * prof
            fac.box(bat, min(a, b), max(a, b), larg, 2 * larg, 0, y_depart + mh * (n1 + i + 1), col, haut=toit)
        ue = l0 - sens * (n2 - .5) * prof
        fac.box(bat, ue - .9, ue + .9, 0, larg, h - .3, h, col, haut=toit)       # passerelle vers le toit
        base = fac.pt(u0 - sens * 1.8, larg / 2)
        pts = [fac.pt(u0 + sens * (n1 - .5) * prof, larg / 2, y_depart + mh * n1),
               fac.pt((l0 + l1) / 2, larg / 2, y_depart + mh * n1),
               fac.pt((l0 + l1) / 2, 1.5 * larg, y_depart + mh * n1),      # entrée de la 2e volée
               fac.pt(ue, 1.5 * larg, h), fac.pt(ue, larg / 2, h), fac.pt(ue, -2.2, h)]
    if enregistrer and y_depart == 0:
        E.acces_toit.append(dict(base=base, pts=pts, toit=pts[-1], y=h))
    return base


def balcons(fac, h, u0, sens=1, y_depart=0, long=1.5, col=None):
    """Chaîne de plateformes en saillie (escalier de secours) : montée en parkour, chaque
    plateforme est 2,4 m plus haut que la précédente -> saut / grimper (Espace)."""
    col = col or color.hsv(rng_teinte(), .5, .55)
    n = math.ceil((h - y_depart) / 2.4)
    mh = (h - y_depart) / n
    dispo = (fac.L - u0 - 1) if sens > 0 else (u0 - 1)
    long = min(long, max(1.2, dispo / n))
    for k in range(n):
        a, b = u0 + sens * k * long, u0 + sens * (k + 1) * long
        top = y_depart + mh * (k + 1)
        fac.box(B('metal'), min(a, b), max(a, b), 0, 2.0, top - .25, top, col, haut=B('metal'))
        if k % 3 == 2:      # montant décoratif
            fac.box(B('metal'), min(a, b) + .1, min(a, b) + .25, 1.8, 1.95, y_depart, top - .25, gris(.2), coll=False)
    return n * long


def rng_teinte():
    return random.choice((22, 35, 200, 140, 0))


def pont(x0, z0, x1, z1, h, large=3.0):
    """Passerelle entre deux toits à la hauteur h (dalle flottante + garde-corps bas)."""
    if abs(x1 - x0) > abs(z1 - z0):
        bloc(B('metal'), min(x0, x1), max(x0, x1), h - .35, h, z0 - large / 2, z0 + large / 2, gris(.35), haut=B('metal'))
        for sz in (-1, 1):
            bloc(B('metal'), min(x0, x1), max(x0, x1), h, h + .45, z0 + sz * large / 2 - .08, z0 + sz * large / 2 + .08,
                 color.hsv(40, .6, .5))
    else:
        bloc(B('metal'), x0 - large / 2, x0 + large / 2, h - .35, h, min(z0, z1), max(z0, z1), gris(.35), haut=B('metal'))
        for sx in (-1, 1):
            bloc(B('metal'), x0 + sx * large / 2 - .08, x0 + sx * large / 2 + .08, h, h + .45, min(z0, z1), max(z0, z1),
                 color.hsv(40, .6, .5))


# ------------------------------------------------------------------ mobilier de toit
def mobilier_toit(x0, z0, w, d, h, rng, nb=None, marge=3.0, exclure=()):
    """Couvertures sur un toit : clim, cabanon, citerne, panneau, sacs de sable, caisses, antenne.
    Retourne des positions libres pour le loot."""
    occupe = list(exclure)

    def place(sx, sz):
        for _ in range(40):
            if w - 2 * marge - sx < 0 or d - 2 * marge - sz < 0:
                return None
            x = rng.uniform(x0 + marge + sx / 2, x0 + w - marge - sx / 2)
            z = rng.uniform(z0 + marge + sz / 2, z0 + d - marge - sz / 2)
            r = (x - sx / 2 - 1, x + sx / 2 + 1, z - sz / 2 - 1, z + sz / 2 + 1)
            if all(not (r[0] < o[1] and r[1] > o[0] and r[2] < o[3] and r[3] > o[2]) for o in occupe):
                occupe.append(r)
                return x, z
        return None

    nb = nb if nb is not None else max(2, int(w * d / 90))
    for _ in range(nb):
        t = rng.choice(('clim', 'clim', 'cabanon', 'citerne', 'panneau', 'sacs', 'caisses', 'antenne'))
        if t == 'clim':
            p = place(2.4, 1.6)
            if p:
                bloc(B('metal'), p[0] - 1.2, p[0] + 1.2, h, h + 1.3, p[1] - .8, p[1] + .8, gris(rng.uniform(.5, .7)), haut=B('metal'))
        elif t == 'cabanon':
            p = place(4.5, 4.5)
            if p:
                bloc(B('toit'), p[0] - 2.25, p[0] + 2.25, h, h + 2.9, p[1] - 2.25, p[1] + 2.25, gris(.6), ch=gris(.4))
                bloc(B('blanc'), p[0] - .6, p[0] + .6, h, h + 2.0, p[1] - 2.27, p[1] - 2.2, gris(.1), coll=False)
        elif t == 'citerne':
            p = place(3, 3)
            if p:
                for sx in (-1, 1):
                    for sz in (-1, 1):
                        bloc(B('metal'), p[0] + sx * 1.3 - .1, p[0] + sx * 1.3 + .1, h, h + 2.1,
                             p[1] + sz * 1.3 - .1, p[1] + sz * 1.3 + .1, gris(.25), coll=False)
                bloc(B('bois'), p[0] - 1.5, p[0] + 1.5, h + 2.1, h + 4.3, p[1] - 1.5, p[1] + 1.5, color.white)
        elif t == 'panneau':
            p = place(7, 1)
            if p:
                for sx in (-2.5, 2.5):
                    bloc(B('metal'), p[0] + sx - .1, p[0] + sx + .1, h, h + 2.2, p[1] - .1, p[1] + .1, gris(.25), coll=False)
                bloc(B('blanc'), p[0] - 3.5, p[0] + 3.5, h + 2.0, h + 5.5, p[1] - .15, p[1] + .15,
                     color.hsv(rng.choice((0, 50, 200, 120)), .75, .75))
        elif t == 'sacs':
            p = place(5, 1.2)
            if p:
                bloc(B('bois'), p[0] - 2.5, p[0] + 2.5, h, h + 1.0, p[1] - .6, p[1] + .6, color.hsv(45, .4, .7))
        elif t == 'caisses':
            p = place(3, 3)
            if p:
                for i in range(rng.randint(2, 4)):
                    ox, oz = rng.uniform(-1, 1), rng.uniform(-1, 1)
                    bloc(B('bois'), p[0] + ox - .7, p[0] + ox + .7, h, h + 1.4, p[1] + oz - .7, p[1] + oz + .7,
                         color.hsv(30, .5, rng.uniform(.5, .8)))
        else:
            p = place(1, 1)
            if p:
                bloc(B('metal'), p[0] - .08, p[0] + .08, h, h + 7, p[1] - .08, p[1] + .08, gris(.4), coll=False)
                bloc(B('lumiere'), p[0] - .2, p[0] + .2, h + 7, h + 7.4, p[1] - .2, p[1] + .2, Color(1, .1, .1, 1), coll=False)
    libres = []
    for _ in range(12):
        x, z = rng.uniform(x0 + 2, x0 + w - 2), rng.uniform(z0 + 2, z0 + d - 2)
        if all(not (o[0] < x < o[1] and o[2] < z < o[3]) for o in occupe):
            libres.append(Vec3(x, h, z))
    return libres


# ------------------------------------------------------------------ rue
def vehicule(x, z, along_z, rng, genre=None):
    genre = genre or rng.choice(('voiture', 'voiture', 'voiture', 'camionnette', 'bus', 'camion'))
    L, Wd, H = {'voiture': (4.4, 1.9, 1.5), 'camionnette': (5.4, 2.2, 2.4), 'bus': (11, 2.7, 3.2),
                'camion': (8, 2.5, 3.4)}[genre]
    sx, sz = (Wd, L) if along_z else (L, Wd)
    if E.hits(x, 0, z, max(sx, sz) / 2, 2) is not None:
        return False
    col = color.hsv(rng.choice((0, 25, 55, 210, 120, 0)), rng.uniform(.2, .65), rng.uniform(.3, .6))
    cab = gris(.12)
    m = B('metal')
    bloc(m, x - sx / 2, x + sx / 2, .35, H * .62, z - sz / 2, z + sz / 2, col, haut=m)
    if genre in ('voiture', 'camionnette'):
        cx, cz = (x, z - L * .06) if along_z else (x - L * .06, z)
        csx, csz = (Wd * .85, L * .5) if along_z else (L * .5, Wd * .85)
        bloc(m, cx - csx / 2, cx + csx / 2, H * .62, H, cz - csz / 2, cz + csz / 2, cab, haut=m, coll=False)
    else:
        bloc(m, x - sx / 2 + .1, x + sx / 2 - .1, H * .62, H, z - sz / 2 + .1, z + sz / 2 - .1, col, haut=m, coll=False)
        bloc(B('blanc'), x - sx / 2 - .01, x + sx / 2 + .01, H * .66, H * .9, z - sz / 2 - .01, z + sz / 2 + .01, cab, coll=False)
    for fx in (-.36, .36):
        for fz in (-.5, .5):
            wx, wz = ((fx * 1.1) * Wd, fz * L * .85) if along_z else (fz * L * .85, (fx * 1.1) * Wd)
            bloc(m, x + wx - (.15 if along_z else .4), x + wx + (.15 if along_z else .4), 0, .7,
                 z + wz - (.4 if along_z else .15), z + wz + (.4 if along_z else .15), gris(.05), coll=False)
    E.ajouter_box(x - sx / 2, x + sx / 2, z - sz / 2, z + sz / 2, 0, H)
    return True


def lampadaire(x, z, cote=1, axe='x'):
    bloc(B('metal'), x - .09, x + .09, 0, 7, z - .09, z + .09, gris(.18), coll=False)
    if axe == 'x':
        bloc(B('metal'), x, x + cote * 1.5, 6.9, 7.05, z - .06, z + .06, gris(.18), coll=False)
        bloc(B('lumiere'), x + cote * 1.0, x + cote * 1.6, 6.78, 6.9, z - .2, z + .2, Color(1, .85, .5, 1), coll=False)
    else:
        bloc(B('metal'), x - .06, x + .06, 6.9, 7.05, z, z + cote * 1.5, gris(.18), coll=False)
        bloc(B('lumiere'), x - .2, x + .2, 6.78, 6.9, z + cote * 1.0, z + cote * 1.6, Color(1, .85, .5, 1), coll=False)


def feu_tricolore(x, z):
    bloc(B('metal'), x - .08, x + .08, 0, 4.5, z - .08, z + .08, gris(.15), coll=False)
    bloc(B('lumiere'), x - .18, x + .18, 3.9, 4.6, z - .1, z + .1, random.choice((Color(1, .1, .1, 1), Color(.1, 1, .2, 1))), coll=False)


def arbre_mort(x, z, rng):
    bloc(B('bois'), x - .25, x + .25, 0, rng.uniform(3, 4.5), z - .25, z + .25, color.hsv(25, .4, .4))
    for _ in range(3):
        ox, oz, hh = rng.uniform(-.9, .9), rng.uniform(-.9, .9), rng.uniform(2.2, 3.6)
        bloc(B('bois'), x + ox / 2 - .08, x + ox / 2 + .08, hh, hh + .12, z + oz / 2 - .08, z + oz / 2 + .08, color.hsv(25, .4, .35), coll=False)
        bloc(B('bois'), x + ox - .06, x + ox + .06, hh, hh + 1.1, z + oz - .06, z + oz + .06, color.hsv(25, .4, .35), coll=False)


def poubelle(x, z, rng):
    bloc(B('metal'), x - 1, x + 1, 0, 1.4, z - .6, z + .6, color.hsv(rng.choice((120, 200)), .5, .35), haut=B('metal'))


def barriere(x, z, long, along_z, h=1.2, y0=0):
    sx, sz = (.9, long) if along_z else (long, .9)
    bloc(B('toit'), x - sx / 2, x + sx / 2, y0, y0 + h, z - sz / 2, z + sz / 2, gris(.6))


def gravats(x, z, rng, n=6, rayon=3):
    for _ in range(n):
        ox, oz = rng.uniform(-rayon, rayon), rng.uniform(-rayon, rayon)
        sx, sz, hh = rng.uniform(.8, 2.2), rng.uniform(.8, 2.2), rng.uniform(.4, 1.5)
        if E.hits(x + ox, 0, z + oz, max(sx, sz) / 2, 1) is None:
            bloc(B('toit') if rng.random() < .6 else B('brique'), x + ox - sx / 2, x + ox + sx / 2, 0, hh,
                 z + oz - sz / 2, z + oz + sz / 2, color.hsv(rng.choice((0, 20, 0)), .2, rng.uniform(.4, .65)))
