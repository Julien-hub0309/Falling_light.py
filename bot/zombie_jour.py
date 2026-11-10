from ursina import *
from bot.zombie_commun import ZombieBase, generer_groupes

# ---- PARTIE DE JOUR --------------------------------------------------------
NB_NORMAUX = 40                 # zombies normaux par partie de jour
GROUPE_NORMAL = (3, 4)          # taille des groupes
NB_SPECIAUX = 8                 # (non précisé) spéciaux par partie de jour : minorité, les armes à feu les attirent
GROUPE_SPECIAL = (2, 3)


class ZombieJour(ZombieBase):
    """Zombie normal du jour : 150 % de vie, 80 % de vitesse (par rapport aux stats de base du jour)."""
    type_zombie = 'normal'
    HP, MULT_HP = 40, 1.5
    VITESSE, MULT_VITESSE = 2.0, .8
    DEGATS, DETECTION, DELAI_ATTAQUE = 7, 32, 1.0
    ANIM_VITESSE = 5


class ZombieSpecialJour(ZombieBase):
    """Zombie spécial du jour : attiré par les coups de feu. (Stats = hypothèse, à ajuster.)"""
    type_zombie = 'special'
    HP, MULT_HP = 40, 2.0
    VITESSE, MULT_VITESSE = 2.0, 1.5
    DEGATS, DETECTION, DELAI_ATTAQUE = 12, 32, .9
    ANIM_VITESSE = 7
    ECOUTE_BRUIT = True
    COULEUR_TETE = color.hsv(30, .5, .5)
    COULEUR_YEUX = Color(1, .45, .1, 1)


def lancer_partie_jour(pos_fn=None):
    """Fait apparaître tous les zombies d'une partie de jour. pos_fn() -> Vec3 de spawn valide."""
    z = generer_groupes(ZombieJour, NB_NORMAUX, *GROUPE_NORMAL, pos_fn)
    z += generer_groupes(ZombieSpecialJour, NB_SPECIAUX, *GROUPE_SPECIAL, pos_fn)
    return z
