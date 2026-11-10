"""ennemie.py - Pilotes IA rivaux (les 4 autres joueurs de la partie).
Ils chassent les zombies et les pilotes, ramassent le loot, lancent des grenades
et appellent un Titan (qui combat en mode auto pour eux)."""
import math
import random
from ursina import *
from partie import etat as E
from bot.pilote import Pilote
from bot import navigation as Nav
from bot.modeles import humanoide
from armes import modeles as VM


class PiloteIA(Pilote):
    def __init__(self, nom, col):
        super().__init__(nom, col)
        self.m = humanoide(self, col, color.hsv(0, 0, .18), color.hsv(25, .4, .8), pilote=True)
        self.torse = self.m['torse']
        self.marche, self.phase = False, 0
        self.route, self.vy = [], 0
        self.col = col
        self.cible, self.vu, self.dest = None, False, None
        self.pense, self.flash, self.react = 0, 0, 0
        self.strafe, self.strafe_t, self.bloque, self.regen_mun = 1, 0, 0, 0
        self.enabled = False

    # ---- hooks -------------------------------------------------------------
    def apres_respawn(self):
        self.cible, self.dest, self.bloque = None, None, 0
        self.sur_changement_arme()

    def sur_changement_arme(self):
        sc, col = VM.BOT.get(self.arme.modele, VM.BOT['AR-15'])
        self.m['fusil'].scale, self.m['fusil'].color = sc, col

    def avant_mort(self):
        self.enabled = False

    def sur_degats(self, source):
        self.flash = .08
        # riposte : cibler l'agresseur s'il est un pilote
        p = E.proprietaire(source)
        if isinstance(p, Pilote) and p is not self and p.vivant:
            self.cible, self.react = p, .3

    # ---- perception ------------------------------------------------------------
    def oeil(self):
        return self.position + Vec3(0, 1.6, 0)

    def penser(self):
        oeil = self.oeil()
        cands = []
        for c in E.toutes_cibles():
            if c is self or c is self.titan:
                continue
            d = math.hypot(c.x - self.x, c.z - self.z)
            if getattr(c, 'est_zombie', False):
                lim, w = 26, 1.0
            elif getattr(c, 'est_titan', False):
                lim, w = 55, 1.3
            else:
                lim, w = 65, .6
            if d < lim:
                cands.append((d * w, c))
        cands.sort(key=lambda t: t[0])
        self.cible, self.vu = None, False
        for _, c in cands[:3]:
            if E.visible(oeil, Vec3(c.x, c.y + c.h * .6, c.z)):
                if self.cible is not c and self.react <= 0:
                    self.react = random.uniform(.25, .6)
                self.cible, self.vu = c, True
                break

        if self.cible is None:
            self.choisir_destination()
        else:
            self.actions_combat()

    def choisir_destination(self):
        if self.dest is not None and self.bloque < 1.2 and self.route:
            return
        self.bloque = 0
        obj = E.partie.objectif_ia(self) if E.partie is not None else None
        if obj is not None:                                  # mode Point de contrôle : on rejoint / tient la zone
            if math.hypot(obj.x - self.x, obj.z - self.z) < E.partie.rayon_zone() * .6:
                self.dest, self.route = None, []
                return
            self.dest = Vec3(obj.x, obj.y, obj.z)
            self.route = Nav.route(self.position, self.dest, self.dest.y)
            return
        besoin = None
        if len(self.armes) < 2 or self.armes[1].melee:       # que le couteau : cherche les loots rouges (arme)
            besoin = 'arme'
        if besoin is None and self.hp < self.hp_max * .55:
            besoin = 'soin'
        elif besoin is None and self.arme.reserve is not None and not self.arme.melee \
                and self.arme.reserve + self.arme.munitions < self.arme.chargeur:
            besoin = 'munitions'
        best, bd = None, 220 if besoin else 130
        for l in E.loots:
            if not l.actif or (besoin and l.type != besoin):
                continue
            if not Nav.joignable(l.x, l.z, l.y):
                continue
            d = math.hypot(l.x - self.x, l.z - self.z)
            if d < bd:
                best, bd = l, d
        if best is not None and (besoin or random.random() < .75):
            dest = Vec3(best.x, best.y, best.z)
        else:
            dest = E.point_libre(1.0)
        self.dest = dest
        self.route = Nav.route(self.position, dest, dest.y)

    def actions_combat(self):
        c = self.cible
        dist = math.hypot(c.x - self.x, c.z - self.z)
        est_pilote = isinstance(c, Pilote)
        if est_pilote and dist < 55 and self.score >= E.COUT_TITAN \
                and not self.titan_actif() and self.titan_cd <= 0 and random.random() < .35:
            self.appeler_titan()
        if self.nb_tactique > 0 and 8 < dist < 28 and random.random() < .15:
            d = Vec3(c.x - self.x, 0, c.z - self.z)
            dn = E.norm(d)
            v = min(26, dist * 1.6)
            self.lancer_tactique(self.oeil(), dn * v + Vec3(0, 6, 0))

    # ---- mouvement ---------------------------------------------------------------
    def bouger(self, dt):
        c = self.cible
        mv, face = Vec3(0, 0, 0), None
        if c is not None:
            d = Vec3(c.x - self.x, 0, c.z - self.z)
            dist = d.length()
            if dist > .01:
                dn = d * (1 / dist)
                face = dn
                pref = self.arme.pref
                fwd = 1 if dist > pref * 1.25 else (-.7 if dist < pref * .55 else 0)
                mv = dn * fwd + Vec3(dn.z, 0, -dn.x) * self.strafe * .7
        elif self.route:
            wp = self.route[0]
            d = Vec3(wp.x - self.x, 0, wp.z - self.z)
            dist = d.length()
            if dist < 1.3:
                self.route.pop(0)
                if not self.route:
                    self.dest = None
            else:
                mv = face = d * (1 / dist)
        self.marche = False
        if mv.length() > 0:
            moved = E.marcher(self, mv.x, mv.z, 6.5 * self.vitesse_mult, dt)
            self.bloque = 0 if moved else self.bloque + dt
            self.marche = moved
            if self.bloque > 1.2:
                self.dest, self.route, self.strafe = None, [], -self.strafe
        else:
            E.marcher(self, 0, 0, 0, dt)
        if face is not None:
            self.rotation_y = math.degrees(math.atan2(face.x, face.z))

    # ---- tir ---------------------------------------------------------------------------
    def tirer_sur_cible(self, dt):
        a = self.arme
        if not a.melee and a.munitions <= 0 and (a.reserve is None or a.reserve <= 0) and len(self.armes) > 1:
            self.idx = 1 - self.idx
            return
        if a.munitions <= 0 and not a.melee:
            a.recharger()
        c = self.cible
        if c is None or not self.vu or self.react > 0:
            return
        oeil = self.oeil()
        cp = Vec3(c.x, c.y + c.h * .6, c.z)
        dist = distance(oeil, cp)
        if dist > a.portee * .85 or not a.pret() or (a.munitions <= 0 and not a.melee):
            return
        err = .03 + dist * .0012
        jit = Vec3(random.uniform(-1, 1), random.uniform(-.6, .6), random.uniform(-1, 1)) * dist * err
        fw = E.norm(Vec3(cp.x - oeil.x, 0, cp.z - oeil.z))
        a.tirer(self, oeil, cp - oeil + jit, debut=oeil + fw * .6)

    # ---- boucle -----------------------------------------------------------------------------
    def update(self):
        P = E.partie
        if not P.actif or not self.vivant:
            return
        dt = time.dt
        self.tick(dt)
        self.react -= dt
        self.flash -= dt
        self.torse.color = Color(2.6, 2.6, 2.6, 1) if self.flash > 0 else Color(1, 1, 1, 1)
        self.strafe_t -= dt
        if self.strafe_t <= 0:
            self.strafe_t, self.strafe = random.uniform(1.2, 2.5), random.choice((-1, 1))
        self.regen_mun += dt
        if self.regen_mun > 25:
            self.regen_mun = 0
            for a in self.armes:
                a.ajouter_munitions(a.chargeur)
        self.pense -= dt
        if self.pense <= 0:
            self.pense = random.uniform(.3, .5)
            self.penser()
        if self.cible is not None and not getattr(self.cible, 'vivant', False):
            self.cible, self.vu = None, False
        self.bouger(dt)
        self.animer(dt)
        self.tirer_sur_cible(dt)

    def animer(self, dt):
        if self.marche:
            self.phase += dt * 10
            amp = 38
        else:
            amp = 0
        j = self.m['jambes']
        j[0].rotation_x = lerp(j[0].rotation_x, math.sin(self.phase) * amp, 12 * dt)
        j[1].rotation_x = lerp(j[1].rotation_x, -math.sin(self.phase) * amp, 12 * dt)
        self.m['bras'][0].rotation_x = lerp(self.m['bras'][0].rotation_x, math.sin(self.phase) * amp * .6 - 30, 12 * dt)
