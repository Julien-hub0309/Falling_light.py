"""parcours.py - Mode PARCOURS.

Aucune arme à feu : seulement le COUTEAU (et le grappin, le parkour, la glissade). Il faut passer par
une série de points de passage dans le temps imparti, pendant que des vagues de zombies FONCENT sur toi.
Chaque point franchi ajoute du temps pour le suivant. Plus de temps = fin de partie ; mort = échec."""
import math
import random
from ursina import *
from partie import etat as E
from mode.default import Partie
from bot.zombie_commun import creer_groupe
from bot.zombie_jour import ZombieJour, ZombieSpecialJour
from bot.zombie_nuit import ZombieNuit, Rapace, ZombieGeant
from map.loot import reset_loots

NB_POINTS = 8
TEMPS_DEPART = 12           # secondes de grâce avant le 1er trajet
VITESSE_REF = 7.0           # m/s servant à calculer le temps alloué à chaque trajet
MARGE = 12                  # secondes ajoutées par trajet
RAYON_POINT = 5
PLAFOND_ZOMBIES = {False: 22, True: 26}
INTERVALLE_VAGUE = {False: 7.0, True: 5.5}

CLASSE_PARCOURS = dict(nom='COUREUR', description='Couteau uniquement', primaire=None, secondaire=None,
                       tactique='frag', nb_tactique=0, hp=100, vitesse=1.1)
CYAN, GRIS = Color(.1, .9, 1, 1), Color(.6, .65, .7, 1)


class PartieParcours(Partie):
    nom_mode = 'parcours'
    titre = 'PARCOURS'
    description = 'Couteau seulement : passe tous les points dans le temps imparti'
    loot_actif = False

    def __init__(self, ciel, nuit=False):
        super().__init__(ciel, nuit)
        self.points, self.idx, self.reste, self.visuels = [], 0, 0.0, []
        self.t_vague, self.tues, self.reussi = 0.0, 0, False
        self.temps_total = 0.0

    # ---- démarrage ---------------------------------------------------------------
    def demarrer(self, classe=None):
        self.visuels, self.points, self.idx = [], [], 0
        self.tues, self.reussi, self.t_vague, self.temps_total = 0, False, 3.0, 0.0
        super().demarrer(CLASSE_PARCOURS)
        for l in E.loots:                                 # pas de loot : zéro arme
            l.enabled = False

    def preparer_pilotes(self, classe):
        spawns = E.spawns[:]
        random.shuffle(spawns)
        for p in E.pilotes:
            if p is E.joueur:
                p.nouvelle_partie(CLASSE_PARCOURS, spawns[0])
            else:                                          # les IA ne participent pas
                p.vivant, p.elimine, p.enabled = False, True, False
        self.generer_parcours(spawns[0])

    def generer_parcours(self, depart):
        pts, cur = [], depart
        for i in range(NB_POINTS):
            p = None
            for _ in range(80):
                if i % 3 == 2 and E.acces_toit:           # un point sur trois en hauteur : parkour
                    a = random.choice([a for a in E.acces_toit if a['y'] <= 16] or E.acces_toit)
                    cand = Vec3(a['toit'].x, a['toit'].y, a['toit'].z)
                else:
                    cand = E.point_libre(2.5, essais=20)
                d = math.hypot(cand.x - cur.x, cand.z - cur.z)
                if 55 <= d <= 135:
                    p = cand
                    break
            if p is None:
                p = E.point_libre(2.5)
            pts.append(p)
            cur = p
        self.points = pts
        self.reste = TEMPS_DEPART + self.temps_trajet(depart, pts[0])
        self.depart = Vec3(depart.x, 0, depart.z)
        self.maj_visuels()

    def temps_trajet(self, a, b):
        return math.hypot(b.x - a.x, b.z - a.z) / VITESSE_REF + MARGE + max(0, b.y - a.y) * 1.2

    def lancer_zombies(self):
        """Quelques groupes embusqués près des points de passage ; la suite arrive en vagues."""
        for p in self.points[:4]:
            self.groupe_aleatoire(Vec3(p.x, 0, p.z))

    # ---- zombies : ils foncent ---------------------------------------------------------
    def groupe_aleatoire(self, centre):
        n = random.random()
        if not self.nuit:
            if n < .25:
                creer_groupe(ZombieSpecialJour, random.randint(2, 3), centre, bonus_detection=300)
            else:
                creer_groupe(ZombieJour, random.randint(3, 4), centre, bonus_detection=300)
        else:
            geants = sum(1 for z in E.zombies if z.geant)
            if n < .15 and geants < 2:
                creer_groupe(ZombieGeant, 1, centre, bonus_detection=300)
            elif n < .45:
                creer_groupe(Rapace, random.randint(2, 3), centre, bonus_detection=300)
            else:
                creer_groupe(ZombieNuit, random.randint(3, 4), centre, bonus_detection=300)

    def pos_vague(self):
        """Devant le joueur, entre lui et le prochain point : ils lui foncent dessus."""
        j = E.joueur
        cap = 0.0
        if self.idx < len(self.points):
            b = self.points[self.idx]
            cap = math.atan2(b.x - j.x, b.z - j.z)
        lim = E.DEMI_MAP - 6
        for _ in range(30):
            a = cap + random.uniform(-1.6, 1.6)
            d = random.uniform(38, 65)
            x, z = j.x + math.sin(a) * d, j.z + math.cos(a) * d
            if abs(x) < lim and abs(z) < lim and E.hits(x, 0, z, 3.5, 3) is None:
                return Vec3(x, 0, z)
        return E.point_libre(3.5, [j], 35)

    def mort_zombie(self, z, source=None):
        if E.proprietaire(source) is E.joueur:
            self.tues += 1
            E.joueur.score += 1
            E.joueur.kills += 1
        # pas de renfort individuel : les vagues s'en chargent

    # ---- points de passage ----------------------------------------------------------------
    def maj_visuels(self):
        for e in self.visuels:
            destroy(e)
        self.visuels = []
        for k in (self.idx, self.idx + 1):
            if k >= len(self.points):
                continue
            p, actif = self.points[k], (k == self.idx)
            c = CYAN if actif else GRIS
            a = .55 if actif else .18
            sol = Entity(model='circle', rotation_x=90, scale=RAYON_POINT * 2.4, color=Color(c[0], c[1], c[2], a * .6),
                         position=(p.x, p.y + .12, p.z), double_sided=True)
            tour = Entity(model='cube', scale=(.9 if actif else .5, 120, .9 if actif else .5),
                          color=Color(c[0], c[1], c[2], a), position=(p.x, p.y + 60, p.z))
            for e in (sol, tour):
                e.volatile, e.ignore = True, True
            self.visuels += [sol, tour]

    def verifier_point(self):
        j = E.joueur
        if self.idx >= len(self.points):
            return
        p = self.points[self.idx]
        if math.hypot(j.x - p.x, j.z - p.z) < RAYON_POINT and abs(j.y - p.y) < 3.5:
            self.idx += 1
            if self.idx >= len(self.points):
                self.reussi = True
                self.finir_parcours(True)
                return
            bonus = self.temps_trajet(p, self.points[self.idx])
            self.reste += bonus
            E.hud.banniere(f'POINT {self.idx}/{len(self.points)}   +{int(bonus)} s', 2)
            self.maj_visuels()

    # ---- fin ----------------------------------------------------------------------------------
    def finir_parcours(self, gagne, raison=''):
        self.fini = True
        mouse.locked = False
        mouse.visible = True
        t = int(self.temps_total)
        if gagne:
            bonus = int(self.reste)
            self.resultat = (f'PARCOURS TERMINE !  {t // 60}:{t % 60:02d}  -  temps restant {bonus} s  -  '
                             f'{self.tues} zombies')
            E.hud.banniere('PARCOURS TERMINÉ', 5)
        else:
            self.resultat = f'ECHEC : {raison}  -  point {self.idx}/{len(self.points)}'
            E.hud.banniere('ÉCHEC', 5)

    def mort_pilote(self, v, source=None):
        if v is E.joueur and v.vivant:
            v.mourir()
            self.finir_parcours(False, 'tu es mort')

    def verifier_fin(self):
        pass

    # ---- crochets HUD ----------------------------------------------------------------------------
    def pilotes_actifs(self):
        return [E.joueur]

    def temps_restant(self):
        return max(0, self.reste)

    def lignes_score(self, joueur):
        return (f'Point {min(self.idx + 1, len(self.points))}/{len(self.points)}\n'
                f'Zombies tues : {self.tues}\nZombies : {len(E.zombies)}')

    def objectif(self):
        return self.points[self.idx] if self.idx < len(self.points) else None

    def info_mode(self):
        o = self.objectif()
        if o is None:
            return ''
        j = E.joueur
        d = math.hypot(o.x - j.x, o.z - j.z)
        haut = '  (en hauteur)' if o.y > 3 else ''
        return f'POINT {self.idx + 1}/{len(self.points)}  -  {int(d)} m{haut}'

    # ---- boucle --------------------------------------------------------------------------------------
    def maj_mode(self, dt):
        j = E.joueur
        if not j.vivant:
            return
        self.temps_total += dt
        self.reste -= dt
        if self.reste <= 0:
            self.finir_parcours(False, 'temps écoulé')
            return
        self.verifier_point()
        self.t_vague -= dt
        if self.t_vague <= 0 and not self.fini:
            self.t_vague = INTERVALLE_VAGUE[self.nuit] * random.uniform(.8, 1.2)
            if len(E.zombies) < PLAFOND_ZOMBIES[self.nuit]:
                self.groupe_aleatoire(self.pos_vague())
