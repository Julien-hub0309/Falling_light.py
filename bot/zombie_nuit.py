from ursina import *
from bot.zombie_commun import ZombieBase, generer_groupes

# ---- PARTIE DE NUIT --------------------------------------------------------
NB_NORMAUX = 45                 # (non précisé) zombies forts : majorité (> 30 rapaces)
GROUPE_NORMAL = (3, 4)
NB_RAPACES = 30                 # zombies spéciaux par partie de nuit
GROUPE_RAPACE = (2, 3)
NB_GEANTS = 5                   # zombies géants par partie


class ZombieNuit(ZombieBase):
    """Zombie fort de la nuit."""
    type_zombie = 'normal'
    HP, MULT_HP = 70, 1
    VITESSE, MULT_VITESSE = 4.6, 1
    DEGATS, DETECTION, DELAI_ATTAQUE = 14, 75, .7
    ANIM_VITESSE = 9
    COULEUR_TETE = color.hsv(8, .5, .42)
    COULEUR_YEUX = Color(1, .1, .05, 1)


class Rapace(ZombieNuit):
    """Zombie spécial de nuit : 170 % de vie, 100 % de vitesse, attiré par les coups de feu."""
    type_zombie = 'rapace'
    MULT_HP, MULT_VITESSE = 1.7, 1
    ECOUTE_BRUIT = True
    COULEUR_TETE = color.hsv(285, .55, .4)
    COULEUR_YEUX = Color(.8, .2, 1, 1)


class ZombieGeant(ZombieNuit):
    """Zombie géant : 220 % de vie, 80 % de vitesse, 1,8x plus grand, frappe très fort. 5 par partie."""
    type_zombie = 'geant'
    geant = True
    MULT_HP, MULT_VITESSE = 2.2, .8
    DEGATS, DETECTION, DELAI_ATTAQUE = 38, 90, 1.2
    ANIM_VITESSE = 6
    TAILLE = 1.8
    COULEUR_TETE = color.hsv(0, .65, .3)
    COULEUR_YEUX = Color(1, .55, 0, 1)


def lancer_partie_nuit(pos_fn=None):
    """Fait apparaître tous les zombies d'une partie de nuit. pos_fn() -> Vec3 de spawn valide."""
    z = generer_groupes(ZombieNuit, NB_NORMAUX, *GROUPE_NORMAL, pos_fn)
    z += generer_groupes(Rapace, NB_RAPACES, *GROUPE_RAPACE, pos_fn)
    z += generer_groupes(ZombieGeant, NB_GEANTS, 1, 1, pos_fn)
    return z
