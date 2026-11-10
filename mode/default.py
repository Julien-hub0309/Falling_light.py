"""default.py - Mode CLASSIQUE + base de tous les modes : chrono 10 min, points, mort définitive
ou respawn (100 pts), fin de partie, zombies de jour OU de nuit (partie séparée, choisie au menu).

Les autres modes (mode/controle.py, mode/parcours.py) héritent de Partie et redéfinissent des « crochets » :
    lancer_zombies()   zombies du début de partie        maj_mode(dt)       logique propre au mode
    pilotes_actifs()   qui joue                          objectif()         point à rejoindre (flèche HUD)
    lignes_score()     tableau des scores                objectif_ia(p)     objectif des pilotes IA"""
import math
import random
from ursina import *
from partie import etat as E
import parametres.graphismes as G
from classe import choix_classe as CC
from bot.pilote import Pilote
from bot.zombie import composition
from bot.zombie_commun import generer_groupes, creer_groupe
from map.loot import Loot, reset_loots, ramassage


class Partie(Entity):
    nom_mode = 'classique'
    titre = 'SURVIS 10 MINUTES'
    description = 'Survis, tue des zombies (+1) et vole les points des pilotes'
    loot_actif = True

    def __init__(self, ciel, nuit=False):
        super().__init__()
        self.ciel = ciel
        self.nuit = nuit                                   # la partie entière est de jour OU de nuit
        self.en_cours = self.fini = self.pause = False
        self.t, self.taches, self.t_detect = 0.0, [], None
        self.resultat, self.acc_loot = '', 0
        self.deficit = {}                                  # zombies à remplacer, par classe

    @property
    def actif(self):
        return self.en_cours and not self.fini and not self.pause

    # ---- planification -------------------------------------------------------
    def plus_tard(self, delai, fn):
        self.taches.append([self.t + delai, fn])

    # ---- ciel ------------------------------------------------------------------
    def appliquer_ciel(self, nuit=None):
        k = 1.0 if (self.nuit if nuit is None else nuit) else 0.0
        self.ciel.color = Color(*G.maj_jour(k), 1)
        if E.hud is not None:
            E.hud.nuit.color = Color(0, 0, .06, (.38 if G.QUALITE == 'bas' else .10) * k)

    # ---- menu / démarrage ---------------------------------------------------------
    def ouvrir_menu(self):
        self.en_cours = self.fini = self.pause = False
        for e in list(scene.entities):                     # plus de zombies / titans en fond de menu
            if getattr(e, 'volatile', False):
                destroy(e)
        E.zombies.clear()
        E.titans.clear()
        E.fumees.clear()
        self.appliquer_ciel(False)
        E.menu.revenir()
        mouse.locked = False
        mouse.visible = True
        E.hud.banniere('')

    def demarrer(self, classe):
        for e in list(scene.entities):
            if getattr(e, 'volatile', False):
                destroy(e)
        E.zombies.clear()
        E.titans.clear()
        E.fumees.clear()
        self.taches, self.t, self.t_detect, self.deficit = [], 0.0, None, {}
        self.fini, self.pause, self.resultat = False, False, ''
        reset_loots()
        self.en_cours = True
        self.preparer_pilotes(classe)
        self.appliquer_ciel()
        self.lancer_zombies()
        E.menu.fermer()
        mouse.locked = True
        E.hud.banniere(self.titre, 3)
        E.msg(self.description)
        E.msg('JOUR : zombies lents, les tirs attirent les spéciaux' if not self.nuit
              else 'NUIT : zombies enragés, les tirs attirent les rapaces')

    def preparer_pilotes(self, classe):
        spawns = E.spawns[:]
        random.shuffle(spawns)
        for i, p in enumerate(E.pilotes):
            p.nouvelle_partie(classe if p is E.joueur else CC.aleatoire(), spawns[i % len(spawns)])

    # ---- zombies -----------------------------------------------------------------------
    def pos_spawn(self):
        """Point de spawn valide à 35-110 m d'un pilote (la carte est grande), jamais en vue immédiate."""
        vivants = [p for p in E.pilotes if p.vivant]
        lim = E.DEMI_MAP - 6
        for _ in range(40):
            if vivants:
                c = random.choice(vivants)
                a, d = random.uniform(0, 6.283), random.uniform(35, 110)
                x, z = c.x + math.sin(a) * d, c.z + math.cos(a) * d
            else:
                x, z = random.uniform(-150, 150), random.uniform(-150, 150)
            if abs(x) < lim and abs(z) < lim and E.hits(x, 0, z, 3.5, 3) is None \
                    and all(math.hypot(x - p.x, z - p.z) >= 30 for p in vivants):
                return Vec3(x, 0, z)
        return E.point_libre(3.5, vivants, 30)

    def lancer_zombies(self):
        """Jour : 40 zombies normaux (150 % PV, 80 % vitesse) en groupes de 3-4 + quelques spéciaux.
        Nuit : zombies forts + 30 rapaces (170 % PV, 100 % vitesse) en groupes de 2-3 + 5 géants (220 % PV, 80 %)."""
        for classe, total, (tmin, tmax) in composition(self.nuit):
            generer_groupes(classe, total, tmin, tmax, self.pos_spawn)

    def mort_zombie(self, z, source=None):
        k = E.proprietaire(source)
        if isinstance(k, Pilote):
            k.score += 1
            k.kills += 1
        if self.actif:
            if not z.geant:                                # les géants ne reviennent pas (5 par partie)
                self.deficit[type(z)] = self.deficit.get(type(z), 0) + 1
                self.plus_tard(E.DELAI_RESPAWN_ZOMBIE, self.renforts)
            if random.random() < .12 and self.loot_actif:
                Loot(z.position, None, True)

    def renforts(self):
        """Remplace les zombies tués par des GROUPES complets (3-4 ou 2-3), pour garder la population."""
        if not self.actif:
            return
        for classe, total, (tmin, tmax) in composition(self.nuit):
            d = self.deficit.get(classe, 0)
            while d >= tmin and tmax > 1:
                n = min(d, tmax)
                creer_groupe(classe, n, self.pos_spawn())
                d -= n
            self.deficit[classe] = d

    # ---- pilotes -------------------------------------------------------------------------
    def mort_pilote(self, v, source=None):
        if not v.vivant or v.elimine:
            return
        k = E.proprietaire(source)
        if not isinstance(k, Pilote) or k is v:
            k = None
        v.score_final = v.score
        v.mourir()
        if self.loot_actif:
            Loot(v.position, random.choice(('soin', 'munitions', 'arme')), True)
        qui = k.nom if k else 'les zombies'
        if v.score >= E.COUT_RESPAWN:
            # points payés : pas de mort définitive. Le tueur prend le reste.
            v.score -= E.COUT_RESPAWN
            if k:
                k.score += v.score
                k.kills += 1
            v.score, v.attente = 0, True
            E.msg(f'{v.nom} tue par {qui} (-{E.COUT_RESPAWN} pts, respawn)')
            self.plus_tard(3, lambda v=v: self.reapparaitre(v))
        else:
            v.elimine, v.t_elim = True, self.t
            if k:
                k.score += v.score
                k.kills += 1
            v.score = 0
            E.msg(f'{v.nom} ELIMINE par {qui}')
            if v.titan_actif():
                v.titan.detruire(False)
            if v is E.joueur:
                E.hud.banniere('ELIMINE', 4)

    def reapparaitre(self, v):
        if not self.actif or v.elimine:
            return
        v.reapparaitre(E.spawn_loin())

    # ---- fin de partie ----------------------------------------------------------------------
    def verifier_fin(self):
        restants = [p for p in E.pilotes if not p.elimine]
        if len(restants) <= 1:
            if self.t_detect is None:
                self.t_detect = self.t
            elif self.t - self.t_detect >= .5:
                if restants:
                    self.finir(restants[0], 'Dernier survivant')
                else:
                    # les deux derniers sont morts en même temps : le plus de points gagne
                    cands = [p for p in E.pilotes if p.t_elim >= self.t_detect - .1] or E.pilotes
                    self.finir(max(cands, key=lambda p: p.score_final), 'Mort simultanee : plus de points')
        elif self.t >= E.DUREE_PARTIE:
            self.finir(max(restants, key=lambda p: p.score), 'Temps ecoule : plus de points')

    def finir(self, gagnant, raison):
        self.fini = True
        mouse.locked = False
        mouse.visible = True
        if gagnant is E.joueur:
            self.resultat = f'VICTOIRE !  ({raison})'
        else:
            self.resultat = f'{gagnant.nom} GAGNE  ({raison})'
        E.hud.banniere('FIN DE PARTIE', 5)

    # ---- crochets pour le HUD / l'IA (redéfinis par les modes) -----------------------------------
    def pilotes_actifs(self):
        return E.pilotes

    def temps_restant(self):
        return max(0, E.DUREE_PARTIE - self.t)

    def phase_texte(self):
        return 'NUIT - zombies enrages' if self.nuit else 'JOUR - zombies lents'

    def lignes_score(self, joueur):
        lignes = []
        for q in sorted(self.pilotes_actifs(), key=lambda q: -q.score):
            etat = 'ELIM' if q.elimine else ('...' if not q.vivant else '')
            lignes.append(f"{'> ' if q is joueur else '  '}{q.nom}  {int(q.score)} pts  {etat}")
        return '\n'.join(lignes) + f'\nZombies : {len(E.zombies)}'

    def info_mode(self):
        return ''                                           # ligne sous le chrono

    def objectif(self):
        return None                                         # Vec3 à afficher (flèche + minimap)

    def barre(self):
        return None                                         # (fraction 0..1, Color) ou None

    def objectif_ia(self, pilote):
        return None

    def maj_mode(self, dt):
        pass

    # ---- entrées -----------------------------------------------------------------------------------
    def input(self, key):
        if E.options.ouvert:
            return
        if key == 'r' and self.en_cours and (self.fini or E.joueur.elimine):
            self.ouvrir_menu()

    # ---- boucle -----------------------------------------------------------------------------------------
    def update(self):
        jeu = self.en_cours and not self.pause and not self.fini
        if mouse.enabled == jeu:                 # picking souris d'Ursina coupé seulement en pleine partie
            mouse.enabled = not jeu
        if not jeu:
            return
        dt = time.dt
        self.t += dt
        if self.loot_actif:
            self.acc_loot += dt
            if self.acc_loot >= .1:
                ramassage(self.acc_loot)
                self.acc_loot = 0
        for tache in [x for x in self.taches if x[0] <= self.t]:
            self.taches.remove(tache)
            tache[1]()
        self.maj_mode(dt)
        if not self.fini:
            self.verifier_fin()


PartieClassique = Partie
