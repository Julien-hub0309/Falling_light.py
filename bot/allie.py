"""allie.py - Le Titan : tombe du ciel, puis combat en mode auto (« allié » du pilote) quand le pilote
n'est pas à bord. Il obéit à des ordres simples (bot/titan.py) : suivre, garder, aller, attaquer.
Au corps à corps il frappe à l'ÉPÉE (à la place du couteau du pilote). Le joueur peut embarquer/éjecter."""
import math
import random
from ursina import *
from partie import etat as E
from partie import effets as FX
import parametres.graphismes as G
from armes import titan as arme_titan, epee as arme_epee, melee
from bot import navigation as Nav

PORTEE_FRAPPE = 5.5          # distance (au bord de la cible) à laquelle le Titan sort l'épée


class TitanAuto:
    """IA du Titan quand il n'est pas piloté."""

    def __init__(self, titan):
        self.t = titan
        self.arme = self.nouvelle_arme()
        self.epee = arme_epee.creer()
        self.cible, self.pense = None, 0
        self.route, self.bloque, self.rt, self.but_prec = [], 0, 0, None

    def nouvelle_arme(self):
        a = arme_titan.pour(self.t.owner.arme_pour_titan())
        a.cadence *= 1.8                       # l'IA tire moins vite qu'un joueur
        self.modele = a.modele
        return a

    def tete(self):
        return self.t.position + Vec3(0, 5.2, 0)

    def chercher(self):
        t, best, bs = self.t, None, 1e9
        agressif = t.ordre == 'attaquer'
        for c in E.toutes_cibles():
            if c is t or c is t.owner:
                continue
            d = math.hypot(c.x - t.x, c.z - t.z)
            lim = 90 if agressif else (55 if not getattr(c, 'est_zombie', False) else 40)
            if d > lim:
                continue
            score = d * (.7 if hasattr(c, 'classe') else 1)
            if score < bs and (agressif or E.visible(self.tete(), Vec3(c.x, c.y + c.h * .55, c.z))):
                best, bs = c, score
        return best

    def bouger(self, dx, dz, v, dt):
        t = self.t
        nx, nz = t.x + dx * v * dt, t.z + dz * v * dt
        ok = False
        if E.hits(nx, .5, t.z, 1.6, 5.5) is None:
            t.x, ok = nx, True
        if E.hits(t.x, .5, nz, 1.6, 5.5) is None:
            t.z, ok = nz, True
        return ok

    def marcher(self, but, v, dt):
        """Va vers `but` ; si bloqué, passe par les rues. Retourne True si arrivé."""
        t = self.t
        if self.but_prec is None or math.hypot(but.x - self.but_prec.x, but.z - self.but_prec.z) > 6:
            self.route, self.bloque, self.but_prec = [], 0, Vec3(but.x, 0, but.z)
        if math.hypot(but.x - t.x, but.z - t.z) < 2.5:
            return True
        self.rt -= dt
        if self.bloque > .8 and self.rt <= 0:
            self.rt, self.bloque = 3, 0
            self.route = Nav.vers_sol(t.position, but)
        wp = self.route[0] if self.route else but
        d = Vec3(wp.x - t.x, 0, wp.z - t.z)
        dist = d.length()
        if self.route and dist < 3:
            self.route.pop(0)
            return False
        if dist > .01:
            dn = d * (1 / dist)
            t.rotation_y = math.degrees(math.atan2(dn.x, dn.z))
            self.bloque = 0 if self.bouger(dn.x, dn.z, v, dt) else self.bloque + dt
        return False

    def update(self, dt):
        t, o = self.t, self.t.owner
        self.arme.update(dt)
        self.epee.update(dt)
        self.pense -= dt
        if self.pense <= 0:
            self.pense = .4
            if self.arme.modele != o.arme_pour_titan().modele:      # le pilote a changé d'arme
                self.arme = self.nouvelle_arme()
            self.cible = self.chercher()
        c = self.cible
        if c is not None and not getattr(c, 'vivant', False):
            c = self.cible = None
        dc = math.hypot(c.x - t.x, c.z - t.z) - c.r if c is not None else 999

        # ---- déplacement selon l'ordre
        ordre, but, v = t.ordre, None, 5
        if ordre == 'aller':
            but, v = t.point, 6
            if self.marcher(but, v, dt):
                t.ordonner('garder')
                but = None
            else:
                but = 'fait'
        elif ordre == 'attaquer':
            if c is not None and dc > PORTEE_FRAPPE - 1.5 and (dc > 22 or not E.visible(self.tete(), Vec3(c.x, c.y + c.h * .55, c.z))):
                self.marcher(Vec3(c.x, 0, c.z), 6, dt)
            elif c is None and o.vivant and not o.elimine and math.hypot(o.x - t.x, o.z - t.z) > 14:
                self.marcher(Vec3(o.x, 0, o.z), 6, dt)
        elif ordre == 'suivre':
            if c is not None:
                if dc > 32:
                    self.marcher(Vec3(c.x, 0, c.z), 5, dt)
            elif o.vivant and not o.elimine and math.hypot(o.x - t.x, o.z - t.z) > 14:
                self.marcher(Vec3(o.x, 0, o.z), 6, dt)
        # 'garder' : ne bouge pas

        # ---- combat : épée au contact, canon sinon
        if c is None:
            return
        cp = Vec3(c.x, c.y + c.h * .55, c.z)
        if ordre != 'aller' or dc < 14:                    # en route on garde le cap, sauf si l'ennemi est tout près
            d = Vec3(c.x - t.x, 0, c.z - t.z)
            if d.length() > .1:
                t.rotation_y = math.degrees(math.atan2(d.x, d.z))
        if dc <= PORTEE_FRAPPE:
            if self.epee.pret():
                self.epee.cool = self.epee.cadence
                t.balancer()
                dn = Vec3(c.x - t.x, 0, c.z - t.z)
                melee.coup(t, Vec3(t.x, t.y + 3, t.z), dn, self.epee)
        elif self.arme.pret():
            org = self.tete()
            if E.visible(org, cp):
                dist = distance(org, cp)
                jit = Vec3(random.uniform(-1, 1), random.uniform(-.5, .5), random.uniform(-1, 1)) * dist * .03
                dn = E.norm(Vec3(cp.x - org.x, 0, cp.z - org.z))
                self.arme.tirer(t, org, cp - org + jit, debut=org + dn * 2)


class Titan(Entity):
    volatile = True
    est_titan = True

    def __init__(self, owner, spot):
        super().__init__(position=Vec3(spot.x, 70, spot.z))
        c, c2, ora = color.hsv(210, .15, .32), color.hsv(210, .1, .2), color.hsv(20, .9, .9)
        parts = [((1.3, 3.0, 1.4), (-.95, 1.5, 0), c), ((1.3, 3.0, 1.4), (.95, 1.5, 0), c),        # jambes
                 ((1.5, .6, 2.1), (-.95, .3, .3), c2), ((1.5, .6, 2.1), (.95, .3, .3), c2),         # pieds
                 ((2.8, 1.2, 1.8), (0, 3.4, 0), c2),                                               # bassin
                 ((3.6, 2.8, 2.3), (0, 5.2, 0), c),                                                # torse
                 ((1.5, 1.0, 2.6), (-2.4, 6.2, 0), c2), ((1.5, 1.0, 2.6), (2.4, 6.2, 0), c2),      # épaulières
                 ((1.1, 1.0, 1.1), (0, 7.0, .2), c2),                                              # tête
                 ((.95, .28, .3), (0, 7.05, .8), ora),                                             # oeil
                 ((.9, .9, 3.4), (2.4, 4.8, 1.4), color.hsv(210, .1, .15)),                          # canon
                 ((1.0, 2.4, 1.0), (-2.5, 4.6, .3), c), ((1.6, 2.2, .3), (-2.5, 4.4, 1.0), ora),    # bras gauche + bouclier
                 ((1.0, .35, 1.0), (0, 5.2, -1.3), ora)]                                           # réacteur
        for sc, pos, col in parts:
            G.solide(parent=self, model='cube', color=col, scale=sc, position=pos)
        self.flamme = Entity(parent=self, model='cube', scale=(1.6, 8, 1.6), y=5, color=Color(1, .55, .1, .6), ignore=True)
        self.marker = Entity(model='plane', scale=7, position=(spot.x, .06, spot.z), color=Color(1, .4, 0, .6))
        # épée : rangée dans le dos, brandie pendant une frappe
        self.epee_piv = Entity(parent=self, position=(0, 5.6, .2), enabled=False, ignore=True)
        G.solide(parent=self.epee_piv, model='cube', color=color.hsv(200, .1, .95), scale=(.3, .22, 6.2), position=(0, 0, 3.6))
        G.solide(parent=self.epee_piv, model='cube', color=ora, scale=(1.6, .3, .4), position=(0, 0, .9))
        self.t_epee = 0
        self.owner, self.state, self.vy = owner, 'falling', 0
        self.hp = self.hp_max = 400
        self.r, self.h, self.vivant = 1.6, 6, True
        self.ordre, self.point, self.marker_ordre = 'suivre', None, None
        self.ia = TitanAuto(self)
        E.titans.append(self)

    # ---- ordres ----------------------------------------------------------------------
    def ordonner(self, ordre, point=None):
        self.ordre, self.point = ordre, point
        self.ia.route, self.ia.bloque, self.ia.but_prec = [], 0, None
        if self.marker_ordre is not None:
            destroy(self.marker_ordre)
            self.marker_ordre = None
        if ordre == 'aller' and point is not None:
            self.marker_ordre = Entity(model='circle', rotation_x=90, scale=5, position=(point.x, .2, point.z),
                                       color=Color(1, .6, .1, .55), double_sided=True, ignore=True)
            self.marker_ordre.volatile = True

    def balancer(self):
        """Animation de frappe à l'épée (visible sur le Titan piloté par l'IA)."""
        p = self.epee_piv
        p.enabled, self.t_epee = True, .45
        p.rotation_y = -75
        p.animate('rotation_y', 75, duration=.25, curve=curve.out_quad)

    def update(self):
        if not E.partie.actif:
            return
        dt = time.dt
        if self.t_epee > 0:
            self.t_epee -= dt
            if self.t_epee <= 0:
                self.epee_piv.enabled = False
        if self.state == 'falling':
            self.vy += 25 * dt
            self.y -= self.vy * dt
            if self.y <= 0:
                self.y, self.state = 0, 'ready'
                destroy(self.marker)
                destroy(self.flamme)
                FX.secousse(1.0)
                E.boom(self.position + Vec3(0, .5, 0), 16, .5, color.white)
                E.explode(self.position, 9, 300, self, ignore=(self.owner,))
        elif self.state == 'ready':
            self.ia.update(dt)

    # ---- pilotage par le joueur
    def embarquer(self):
        self.state = 'embarque'
        self.enabled = False
        if self.marker_ordre is not None:
            destroy(self.marker_ordre)
            self.marker_ordre = None

    def debarquer(self, pos, hp):
        self.hp = hp
        self.position = Vec3(pos.x, 0, pos.z)
        self.state, self.enabled = 'ready', True
        self.ordre = 'suivre'

    def damage(self, n, source=None, tete=False):
        if self.state != 'ready' or not self.vivant:
            return
        self.hp -= n * .7
        if self.hp <= 0:
            self.detruire()

    def detruire(self, explose=True):
        if not self.vivant:
            return
        self.vivant = False
        if self in E.titans:
            E.titans.remove(self)
        if explose:
            E.boom(self.position + Vec3(0, 3, 0), 16, .5)
            E.explode(self.position, 10, 250, self, ignore=(self.owner,))
        o = self.owner
        if o.titan is self:
            o.titan, o.titan_cd = None, 25
        if self.state == 'falling':
            destroy(self.marker)
        if self.marker_ordre is not None:
            destroy(self.marker_ordre)
        destroy(self)
