"""zombie.py - Point d'entrée : types de zombies selon le moment de la partie (jour / nuit)."""
from partie import etat as E
from bot.zombie_commun import ZombieBase, GestionZombies, generer_groupes, creer_groupe, bruit
from bot.zombie_jour import ZombieJour, ZombieSpecialJour, lancer_partie_jour
from bot.zombie_nuit import ZombieNuit, Rapace, ZombieGeant, lancer_partie_nuit


class _Type(type):
    def __instancecheck__(cls, obj):           # isinstance(z, Zombie) reste vrai pour tous les zombies
        return isinstance(obj, ZombieBase)


class Zombie(metaclass=_Type):
    def __new__(cls, pos):
        return (ZombieNuit if E.partie.nuit else ZombieJour)(pos)


# (classe, effectif, (taille mini de groupe, maxi)) selon le moment : sert au lancement ET au renfort
def composition(nuit):
    from bot import zombie_jour as J, zombie_nuit as N
    if nuit:
        return [(ZombieNuit, N.NB_NORMAUX, N.GROUPE_NORMAL), (Rapace, N.NB_RAPACES, N.GROUPE_RAPACE),
                (ZombieGeant, N.NB_GEANTS, (1, 1))]
    return [(ZombieJour, J.NB_NORMAUX, J.GROUPE_NORMAL), (ZombieSpecialJour, J.NB_SPECIAUX, J.GROUPE_SPECIAL)]
