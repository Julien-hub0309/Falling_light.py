"""zombie_commun.py - Base de tous les zombies : IA, groupes, bruit, dégâts.

OPTIMISATION : les zombies n'ont plus d'update() chacun. Un seul GestionZombies les fait avancer, et
la fréquence de mise à jour dépend de la distance au pilote le plus proche (proche = chaque image,
loin = 1 image sur 8 avec un dt cumulé). Les animations lointaines sont coupées."""
import math
import random
from ursina import *
from partie import etat as E
from partie import effets as FX
from bot import navigation as Nav
from bot.modeles import humanoide

RAYON_BRUIT_TIR = E.RAYON_BRUIT_TIR
FLASH = Color(2.6, 2.6, 2.6, 1)           # > 1 : éclaircit les couleurs des sommets (flash de dégât)
BLANC = Color(1, 1, 1, 1)


# ---------------------------------------------------------------- groupes ---
def tailles_groupes(total, tmin, tmax):
    """Découpe `total` zombies en groupes de tmin à tmax, somme exacte (ex. 40 -> 3,4,4,3...)."""
    k = random.randint(-(-total // tmax), total // tmin)        # nombre de groupes possible
    tailles = [tmin] * k
    reste = total - tmin * k
    while reste > 0:
        i = random.randrange(k)
        if tailles[i] < tmax:
            tailles[i] += 1
            reste -= 1
    return tailles


def _pos_defaut():
    return Vec3(random.uniform(-90, 90), 0, random.uniform(-90, 90))


def creer_groupe(classe, n, centre, **options):
    """Fait apparaître `n` zombies de `classe` autour de `centre` (hors des murs) : un groupe soudé."""
    groupe = []
    for _ in range(n):
        x, z = centre.x, centre.z
        for _ in range(8):
            px, pz = centre.x + random.uniform(-3, 3), centre.z + random.uniform(-3, 3)
            if E.hits(px, 0, pz, .6, 2) is None and abs(px) < E.DEMI_MAP - 3 and abs(pz) < E.DEMI_MAP - 3:
                x, z = px, pz
                break
        zb = classe(Vec3(x, 0, z))
        zb.groupe = groupe
        for k, v in options.items():
            setattr(zb, k, v)
        groupe.append(zb)
    return groupe


def generer_groupes(classe, total, tmin, tmax, pos_fn=None, **options):
    """Crée `total` zombies de `classe`, répartis en groupes de tmin..tmax.
    pos_fn() doit renvoyer un point de spawn valide (Vec3) ; un groupe apparaît autour de ce point."""
    pos_fn = pos_fn or _pos_defaut
    crees = []
    for n in tailles_groupes(total, tmin, tmax):
        crees += creer_groupe(classe, n, pos_fn(), **options)
    return crees


# ------------------------------------------------------------------ bruit ---
def bruit(pos, rayon=RAYON_BRUIT_TIR):
    """Alerte les zombies qui écoutent (spéciaux le jour, rapaces la nuit)."""
    E.bruit(pos, rayon)


# ------------------------------------------------------------ zombie de base ---
class ZombieBase(Entity):
    volatile = True
    est_zombie = True
    geant = False

    # --- stats : redéfinies dans les sous-classes ---
    type_zombie = 'normal'
    HP, MULT_HP = 40, 1
    VITESSE, MULT_VITESSE = 2.0, 1
    DEGATS = 7
    DETECTION = 32
    DELAI_ATTAQUE = 1.0
    ANIM_VITESSE = 5
    ECOUTE_BRUIT = False                       # True : attiré par les coups de feu
    TAILLE = 1.0                               # échelle du modèle
    COULEUR_TETE = color.hsv(85, .3, .5)
    COULEUR_YEUX = Color(.9, .8, .2, 1)

    def __init__(self, pos):
        super().__init__(position=Vec3(pos.x, 0, pos.z), ignore=True)   # piloté par GestionZombies
        self.r, self.h, self.vivant = .45 * self.TAILLE, 1.9 * self.TAILLE, True
        self.hp = self.hp_max = self.HP * self.MULT_HP
        self.var = random.uniform(.85, 1.15)
        self.cible, self.pense, self.atk, self.flash = None, random.uniform(0, .4), 0, 0
        self.dest, self.dest_t, self.anim = None, 0, random.uniform(0, 6)
        self.route, self.rt, self.bloque, self.vy = [], 0, 0, 0
        self.groupe = [self]
        self.alerte_pos, self.alerte_t = None, 0
        self.bonus_detection = 0               # parcours : les zombies « foncent » sur le joueur
        self.proche = True                     # animé seulement si proche (voir GestionZombies)
        teinte = random.choice((0, 25, 50, 90, 150, 200, 240, 300))
        self.m = humanoide(self, color.hsv(teinte, .25, .3), color.hsv(220, .2, .2),
                           color.hsv(random.choice((75, 90, 105)), .3, .45), pilote=False)
        if self.TAILLE != 1:
            self.scale = self.TAILLE
        self.corps = self.m['torse']
        self.m['tete'].color = self.COULEUR_TETE
        for y in self.m['yeux']:
            y.color = self.COULEUR_YEUX
        E.zombies.append(self)
        GestionZombies.assurer()

    @property
    def vitesse(self):
        return self.VITESSE * self.MULT_VITESSE * self.var

    # ---- bruit / groupe -----------------------------------------------------
    def alerter(self, pos, propage=True):
        """Va enquêter sur un bruit (et prévient son groupe)."""
        self.alerte_pos, self.alerte_t = Vec3(pos.x, pos.y, pos.z), 12
        if propage:
            for g in self.groupe:
                if g is not self and g.vivant:
                    g.alerter(pos, False)

    # ---- IA ----------------------------------------------------------------
    def trouver_cible(self):
        best, bd = None, self.DETECTION + self.bonus_detection
        for p in E.pilotes:
            if p.vivant and not p.elimine:
                d = math.hypot(p.x - self.x, p.z - self.z)
                if d < bd:
                    best, bd = p, d
        if best is None:                                   # le groupe partage sa cible
            for g in self.groupe:
                if g is not self and g.vivant and g.cible is not None and g.cible.vivant:
                    return g.cible
        return best

    def avancer(self, dx, dz, dt):
        return E.marcher(self, dx, dz, self.vitesse, dt)

    def enquete(self, dt):
        """Marche vers l'endroit du dernier bruit, puis se calme."""
        p = self.alerte_pos
        self.alerte_t -= dt
        if self.alerte_t <= 0 or math.hypot(p.x - self.x, p.z - self.z) < 2.5:
            self.alerte_pos, self.alerte_t, self.route = None, 0, []
            return
        self.rt -= dt
        if self.bloque > .8 and self.rt <= 0:
            self.rt, self.bloque = 2.5, 0
            self.route = Nav.route(self.position, p, p.y)
        self.aller_vers(self.route[0] if self.route else p, dt)

    def aller_vers(self, but, dt):
        d = Vec3(but.x - self.x, 0, but.z - self.z)
        dist = d.length()
        if self.route and dist < 1.4:
            self.route.pop(0)
        elif dist > .01:
            dn = d * (1 / dist)
            self.rotation_y = math.degrees(math.atan2(dn.x, dn.z))
            ok = self.avancer(dn.x, dn.z, dt)
            self.bloque = 0 if ok else self.bloque + dt

    def animer(self, dt):
        self.anim += dt * self.ANIM_VITESSE
        ph = self.anim
        j, b = self.m['jambes'], self.m['bras']
        s = math.sin(ph) * 35
        j[0].rotation_x, j[1].rotation_x = s, -s
        lunge = 14 if self.atk > .5 else 0
        b[0].rotation_x = -80 + math.sin(ph * .7) * 8 + lunge
        b[1].rotation_x = -80 + math.sin(ph * .7 + 2) * 8 + lunge
        self.m['tete'].rotation_z = 8 + math.sin(ph * .5) * 6

    def tick(self, dt, proche=True):
        """Un pas d'IA (dt peut être cumulé pour les zombies lointains)."""
        if proche:
            self.animer(dt)
        elif self.proche:
            self.proche = False
        self.proche = proche
        if self.flash > 0:
            self.flash -= dt
            if self.flash <= 0:
                self.corps.color = BLANC
        self.atk -= dt
        self.pense -= dt
        if self.pense <= 0:
            self.pense = random.uniform(.25, .45)
            self.cible = self.trouver_cible()
        c = self.cible
        if c is not None and (not c.vivant or c.elimine):
            c = self.cible = None
        if c is not None:
            self.alerte_pos, self.alerte_t = None, 0
            haut = c.y - self.y > 2.5
            self.rt -= dt
            if (haut or self.bloque > .8) and self.rt <= 0:      # cible sur un toit / chemin bloqué
                self.rt, self.bloque = 2.5, 0
                self.route = Nav.route(self.position, c.position, c.y)
            but = self.route[0] if self.route else c.position
            dist = math.hypot(but.x - self.x, but.z - self.z)
            dc = math.hypot(c.x - self.x, c.z - self.z)
            if dist > .01 and (dc > 1.2 * self.TAILLE or self.route):
                self.aller_vers(but, dt)
            elif dist > .01:
                E.marcher(self, 0, 0, 0, dt)
            if dc < 1.7 * self.TAILLE and abs(c.y - self.y) < 2.2 * self.TAILLE and self.atk <= 0:
                self.atk = self.DELAI_ATTAQUE
                c.damage(self.DEGATS, self)
        elif self.alerte_pos is not None:
            self.enquete(dt)
        else:
            self.errer(dt)

    def errer(self, dt):
        """Sans cible : le groupe se déplace ensemble autour de son meneur."""
        self.route = []
        chef = self.groupe[0] if self.groupe else self
        if chef is not self and chef.vivant:
            dx, dz = chef.x - self.x, chef.z - self.z
            dist = math.hypot(dx, dz)
            if dist > 5:
                self.aller_vers(chef.position, dt * .6)
                return
            if dist < 2:                                   # évite l'empilement
                self.avancer(-dx, -dz, dt * .3)
                return
            E.marcher(self, 0, 0, 0, dt)
            return
        self.dest_t -= dt
        if self.dest is None or self.dest_t <= 0:
            a = random.uniform(0, 6.28)
            self.dest, self.dest_t = Vec3(math.sin(a), 0, math.cos(a)), random.uniform(2, 5)
        if self.avancer(self.dest.x, self.dest.z, dt * .5):
            self.rotation_y = math.degrees(math.atan2(self.dest.x, self.dest.z))
        else:
            self.dest = None

    # ---- dégâts ------------------------------------------------------------
    def damage(self, n, source=None, tete=False):
        if not self.vivant:
            return
        self.hp -= n
        self.flash = .08
        self.corps.color = FLASH
        FX.sang(self.position + Vec3(0, 1.3 * self.TAILLE, 0), 3)
        if self.hp <= 0:
            self.vivant = False
            if self in E.zombies:
                E.zombies.remove(self)
            if self in self.groupe:
                self.groupe.remove(self)
            FX.sang(self.position + Vec3(0, 1.2 * self.TAILLE, 0), 10)
            E.partie.mort_zombie(self, source)
            destroy(self)


# ------------------------------------------------------------- gestionnaire ---
class GestionZombies(Entity):
    """Fait « penser » tous les zombies. Fréquence selon la distance au pilote le plus proche."""
    _instance = None

    @classmethod
    def assurer(cls):
        if cls._instance is None or cls._instance.is_empty():
            cls._instance = cls()

    def __init__(self):
        super().__init__()
        self.n = 0

    def update(self):
        P = E.partie
        if P is None or not P.actif:
            return
        dt = time.dt
        self.n += 1
        n = self.n
        refs = [(p.x, p.z) for p in E.pilotes if p.vivant and not p.elimine]
        if not refs:
            refs = [(0, 0)]
        for i, z in enumerate(list(E.zombies)):
            if not z.vivant:
                continue
            zx, zz = z.x, z.z
            d2 = min((zx - rx) ** 2 + (zz - rz) ** 2 for rx, rz in refs)
            if d2 < 1600:        # < 40 m : chaque image, animé
                pas = 1
            elif d2 < 4900:      # < 70 m : 1 image sur 2
                pas = 2
            elif d2 < 12100:     # < 110 m : 1 sur 4
                pas = 4
            else:                # plus loin : 1 sur 8
                pas = 8
            if (n + i) % pas == 0:
                z.tick(dt * pas, pas <= 2)
