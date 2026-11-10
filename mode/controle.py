"""controle.py - Mode POINT DE CONTRÔLE.

Une zone apparaît sur la carte. Il faut y RESTER 30 secondes (seul dans la zone) pour gagner 10 points.
Tuer un zombie rapporte 1 point (comme dans tous les modes). Si deux pilotes sont dans la zone,
elle est CONTESTÉE : plus personne ne progresse. Quand on sort, la progression retombe vite.
Une fois capturée, une nouvelle zone apparaît ailleurs. Meilleur score au bout de 10 minutes."""
import math
import random
from ursina import *
from partie import etat as E
from mode.default import Partie

DUREE_CAPTURE = 30          # secondes dans la zone
PTS_CAPTURE = 10
PTS_ZOMBIE = 1
RAYON_ZONE = 8
DELAI_NOUVELLE_ZONE = 6     # pause entre deux zones
VIE_ZONE = 150              # une zone que personne ne capture se déplace après ce délai

CYAN, ORANGE, VERT = Color(.1, .8, 1, 1), Color(1, .55, .1, 1), Color(.3, 1, .4, 1)


class PartieControle(Partie):
    nom_mode = 'controle'
    titre = 'POINT DE CONTRÔLE'
    description = f'Reste {DUREE_CAPTURE} s dans la zone : +{PTS_CAPTURE} pts. Zombie tué : +{PTS_ZOMBIE} pt'

    def __init__(self, ciel, nuit=False):
        super().__init__(ciel, nuit)
        self.zone = None            # Vec3 du centre
        self.visuels = []
        self.progres = 0.0
        self.capteur = None
        self.conteste = False
        self.age_zone = 0.0
        self.captures = {}          # pilote -> nombre de captures

    # ---- zone ---------------------------------------------------------------------
    def demarrer(self, classe):
        self.captures = {}
        self.zone, self.visuels, self.progres, self.capteur = None, [], 0.0, None
        super().demarrer(classe)
        self.placer_zone()

    def placer_zone(self):
        if not self.actif:
            return
        ancienne = self.zone
        for _ in range(60):
            p = E.point_libre(RAYON_ZONE * .6, essais=30)
            if ancienne is None or math.hypot(p.x - ancienne.x, p.z - ancienne.z) > 70:
                break
        self.zone, self.progres, self.capteur, self.conteste, self.age_zone = Vec3(p.x, 0, p.z), 0.0, None, False, 0.0
        r = RAYON_ZONE
        sol = Entity(model='circle', rotation_x=90, scale=r * 2, position=(p.x, .12, p.z), color=Color(.1, .8, 1, .28),
                     double_sided=True)
        anneau = [Entity(model='cube', scale=(.5, 16, .5), color=Color(.1, .8, 1, .5),
                         position=(p.x + dx * r, 8, p.z + dz * r)) for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1))]
        faisceau = Entity(model='cube', scale=(1.2, 90, 1.2), color=Color(.1, .8, 1, .3), position=(p.x, 45, p.z))
        for e in [sol, faisceau] + anneau:
            e.volatile = True
            e.ignore = True
        self.visuels = [sol, faisceau] + anneau
        E.msg('Nouveau point de contrôle !')

    def retirer_zone(self):
        for e in self.visuels:
            destroy(e)
        self.visuels, self.zone = [], None

    def colorer(self, c):
        for i, e in enumerate(self.visuels):
            a = (.28, .3, .5, .5, .5, .5)[min(i, 5)]
            e.color = Color(c[0], c[1], c[2], a)

    # ---- logique ------------------------------------------------------------------
    def dans_la_zone(self):
        z = self.zone
        return [p for p in E.pilotes if p.vivant and not p.elimine
                and math.hypot(p.x - z.x, p.z - z.z) < RAYON_ZONE and abs(p.y - z.y) < 5]

    def maj_mode(self, dt):
        if self.zone is None:
            return
        self.age_zone += dt
        dedans = self.dans_la_zone()
        if len(dedans) == 1:
            p = dedans[0]
            if self.capteur is not p:
                self.capteur, self.progres = p, 0.0
            self.conteste = False
            self.progres += dt
            self.colorer(VERT)
            if self.progres >= DUREE_CAPTURE:
                self.capturer(p)
        elif len(dedans) > 1:
            self.conteste = True
            self.colorer(ORANGE)
        else:
            self.conteste = False
            self.progres = max(0.0, self.progres - 2 * dt)
            if self.progres <= 0:
                self.capteur = None
            self.colorer(CYAN)
        if self.zone is not None and self.age_zone > VIE_ZONE and self.progres <= 0:
            self.retirer_zone()
            E.msg('La zone se déplace...')
            self.plus_tard(2, self.placer_zone)

    def capturer(self, p):
        p.score += PTS_CAPTURE
        self.captures[p] = self.captures.get(p, 0) + 1
        E.msg(f'{p.nom} capture le point (+{PTS_CAPTURE} pts)')
        if p is E.joueur:
            E.hud.banniere(f'POINT CAPTURÉ  +{PTS_CAPTURE}', 2)
        self.retirer_zone()
        self.progres, self.capteur = 0.0, None
        self.plus_tard(DELAI_NOUVELLE_ZONE, self.placer_zone)

    # ---- crochets HUD / IA ----------------------------------------------------------
    def objectif(self):
        return self.zone

    def barre(self):
        if self.zone is None:
            return None
        return self.progres / DUREE_CAPTURE, (ORANGE if self.conteste else VERT)

    def info_mode(self):
        j = E.joueur
        if self.zone is None:
            return 'Prochaine zone...'
        d = math.hypot(self.zone.x - j.x, self.zone.z - j.z)
        if self.conteste:
            etat = 'CONTESTÉ !'
        elif self.capteur is j:
            etat = f'CAPTURE {int(self.progres)}/{DUREE_CAPTURE} s'
        elif self.capteur is not None:
            etat = f'{self.capteur.nom} capture...'
        else:
            etat = 'Entre dans la zone'
        return f'POINT DE CONTRÔLE  {int(d)} m  -  {etat}'

    def objectif_ia(self, pilote):
        """Les IA se disputent le point (environ 2 sur 3 y vont)."""
        if self.zone is None:
            return None
        if not hasattr(pilote, 'veut_zone') or random.random() < .1:
            pilote.veut_zone = random.random() < .65
        return self.zone if pilote.veut_zone else None

    def rayon_zone(self):
        return RAYON_ZONE
