"""choix_mode.py - Menu de sélection : MODE DE JEU (Classique / Point de contrôle / Parcours)
et MOMENT (Jour / Nuit). Ensuite : choix de la classe (sauf Parcours : couteau seulement)."""
from ursina import *
from partie import etat as E

MODES = [
    ('classique', 'CLASSIQUE', 'Survis 10 min\nZombie tué : +1 pt\nTitans et pilotes rivaux'),
    ('controle', 'POINT DE CONTROLE', 'Reste 30 s sur le point\npour +10 pts\nZombie tué : +1 pt'),
    ('parcours', 'PARCOURS', 'Couteau seulement\nPasse tous les points\ndans le temps imparti'),
]
MOMENTS = [
    ('jour', 'JOUR', 'Zombies lents et plutôt faibles\nLes tirs attirent les spéciaux\n40 zombies en groupes de 3-4'),
    ('nuit', 'NUIT', 'Zombies forts et rapides, 5 géants\nLes tirs attirent les rapaces\n30 rapaces en groupes de 2-3'),
]
SEL, NORMAL = color.azure, color.dark_gray


def classe_du_mode(mode):
    if mode == 'controle':
        from mode.controle import PartieControle
        return PartieControle
    if mode == 'parcours':
        from mode.parcours import PartieParcours
        return PartieParcours
    from mode.default import Partie
    return Partie


class MenuMode(Entity):
    def __init__(self, menu_classe):
        super().__init__(parent=camera.ui)
        self.menu_classe = menu_classe
        self.mode, self.moment = 'classique', 'jour'
        Text(parent=self, text='FALLING LIGHT', origin=(0, 0), y=.43, scale=3.2, color=color.orange)
        Text(parent=self, text='Choisis un mode de jeu (clic ou touches 1-3)', origin=(0, 0), y=.34, scale=1.3)
        self.b_mode, self.b_moment = {}, {}
        for i, (cle, nom, desc) in enumerate(MODES):
            x = -.58 + i * .58
            b = Button(parent=self, text=nom, position=(x, .2), scale=(.54, .12), color=NORMAL)
            b.on_click = lambda c=cle: self.choisir_mode(c)
            Text(parent=self, text=desc, position=(x - .22, .1), scale=.85)
            self.b_mode[cle] = b
        Text(parent=self, text='Moment de la partie (J / N)', origin=(0, 0), y=-.08, scale=1.3)
        for i, (cle, nom, desc) in enumerate(MOMENTS):
            x = -.34 + i * .68
            b = Button(parent=self, text=nom, position=(x, -.17), scale=(.4, .09), color=NORMAL)
            b.on_click = lambda c=cle: self.choisir_moment(c)
            Text(parent=self, text=desc, position=(x - .3, -.23), scale=.8)
            self.b_moment[cle] = b
        jouer = Button(parent=self, text='CONTINUER  (Entrée)', position=(0, -.4), scale=(.5, .08), color=color.green)
        jouer.on_click = self.continuer
        ob = Button(parent=self, text='OPTIONS / TOUCHES', position=(.62, -.4), scale=(.35, .06), color=NORMAL)
        ob.on_click = lambda: E.options.ouvrir()
        self.maj()

    def maj(self):
        for c, b in self.b_mode.items():
            b.color = SEL if c == self.mode else NORMAL
        for c, b in self.b_moment.items():
            b.color = SEL if c == self.moment else NORMAL

    def choisir_mode(self, c):
        self.mode = c
        self.maj()

    def choisir_moment(self, c):
        self.moment = c
        self.maj()

    def continuer(self):
        """Crée la partie du mode choisi, puis demande la classe (Parcours : démarre tout de suite)."""
        if E.partie is not None:
            destroy(E.partie)
        E.partie = classe_du_mode(self.mode)(E.ciel, nuit=(self.moment == 'nuit'))
        if self.mode == 'parcours':
            E.partie.demarrer(None)
        else:
            self.enabled = False
            self.menu_classe.enabled = True

    def revenir(self):
        self.enabled = True
        self.menu_classe.enabled = False

    def fermer(self):
        self.enabled = False
        self.menu_classe.enabled = False

    def input(self, key):
        if E.options is not None and E.options.ouvert:
            return
        if key in ('1', '2', '3'):
            self.choisir_mode(MODES[int(key) - 1][0])
        elif key == 'j':
            self.choisir_moment('jour')
        elif key == 'n':
            self.choisir_moment('nuit')
        elif key in ('enter', 'space'):
            self.continuer()
