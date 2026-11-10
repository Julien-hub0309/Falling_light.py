"""joueur.py - Le joueur (FPS) : mouvement Titanfall (double saut, wall-run, glisse,
grappin) + parkour Dying Light (grimper) + Titan pilotable."""
import math
import random
from ursina import *
from partie import etat as E
from partie import effets as FX
from armes import modeles as VM
from bot.pilote import Pilote
from armes import titan as arme_titan
from parametres import clavier as K, souris as S
from parametres import clavier
from armes import melee
import craft


class Player(Pilote):
    def __init__(self):
        super().__init__('Toi', color.azure)
        self.pivot = Entity(parent=self, y=1.65)
        camera.parent = self.pivot
        camera.position, camera.rotation = (0, 0, 0), (0, 0, 0)
        camera.fov = S.FOV
        self.gun = Entity(parent=camera)          # racine de l'arme en main
        self.vms, self.vm, self.flash_t, self.bob = {}, None, 0, 0
        self.arme_titan = None                    # = arme principale en version Titan (à l'embarquement)
        self.vel, self.vy = Vec3(0, 0, 0), 0
        self.grounded, self.jumps, self.wall_t = True, 1, 0
        self.wall_n, self.wallrunning = None, False
        self.slide_t, self.slide_dir, self.slide_v = 0, Vec3(0, 0, 1), 0
        self.melee_t, self.melee_vms = 0, {}      # animation de frappe (couteau / épée)
        self.grimpe = None
        self.grappin, self.grappin_t, self.grappin_cd, self.corde = None, 0, 0, None
        self.zoom = self.lunette = False
        self.set_gun()

    # ---- armes / vue ---------------------------------------------------------
    def arme_active(self):
        if self.mode == 'titan' and self.arme_titan is not None:
            return self.arme_titan
        return self.arme if self.armes else None

    def set_gun(self):
        a = self.arme_active()
        if a is None:
            return
        if self.vm is not None:
            self.vm.enabled = False
        cle = (a.modele, a.titan)
        if cle not in self.vms:
            self.vms[cle] = VM.construire(a.modele, self.gun, a.titan)
        self.vm = self.vms[cle]
        self.vm.enabled = True
        self.gun.position = a.vue[1]

    def tick(self, dt):
        super().tick(dt)
        if self.arme_titan is not None:
            self.arme_titan.update(dt)

    def sur_changement_arme(self):
        self.set_gun()

    def sur_degats(self, source):
        E.hud.degats()

    def avant_mort(self):
        self.pivot.y = .4
        self.gun.enabled = False
        self.zoom = False
        self.fin_grappin()

    def apres_respawn(self):
        self.vel, self.vy = Vec3(0, 0, 0), 0
        self.grounded, self.jumps, self.wall_t = True, 1, 0
        self.wall_n, self.wallrunning, self.slide_t, self.grimpe = None, False, 0, None
        self.pivot.rotation_x = 0
        self.arme_titan = None
        self.gun.enabled = True
        self.fin_grappin()
        self.set_gun()

    # ---- Titan ------------------------------------------------------------------
    def damage(self, n, source=None, tete=False):
        if self.mode == 'titan':
            if not self.vivant or self.invuln > 0 or not E.partie.actif:
                return
            self.since_hit = 0
            self.titan_hp -= n * .8
            self.sur_degats(source)
            if self.titan_hp <= 0:
                self.ejecter(force=True)
            return
        super().damage(n, source, tete)

    def embarquer(self):
        t = self.titan
        self.mode, self.titan_hp, self.vy = 'titan', t.hp, 0
        self.arme_titan = arme_titan.pour(self.arme_pour_titan())
        self.position = Vec3(t.x, 0, t.z)
        t.embarquer()
        self.zoom = False
        self.set_gun()
        E.msg('Titan : [E] pour ejecter')

    def ejecter(self, force=False):
        t = self.titan
        pos = self.position
        self.mode, self.vy, self.grounded, self.jumps = 'pilot', 16, False, 1
        if t is not None and t.vivant:
            if force:
                t.position = Vec3(pos.x, 0, pos.z)
                t.detruire(True)
            else:
                fw = E.norm(Vec3(self.forward.x, 0, self.forward.z))
                p = pos + fw * 4
                if E.hits(p.x, 0, p.z, 1.6, 5.5) is not None:
                    p = pos
                t.debarquer(p, self.titan_hp)
        self.set_gun()

    # ---- entrées ------------------------------------------------------------------
    def input(self, key):
        P = E.partie
        if not P.actif or not self.vivant or self.elimine:
            return
        titan = self.mode == 'titan'
        if K.est(key, 'saut'):
            if self.slide_t > 0:                         # saut depuis la glissade : on garde (et on gagne un peu de) vitesse
                v = min(24, self.slide_v * 1.06)
                self.vel = Vec3(self.slide_dir.x * v, 0, self.slide_dir.z * v)
                self.slide_t = 0
            if self.grappin is not None:
                self.fin_grappin()
            if self.grounded:
                if not self.tente_grimper():
                    self.vy, self.grounded = 7 if titan else 9, False
            elif self.wallrunning:
                self.vy = 9
                if self.wall_n is not None:
                    self.vel += self.wall_n * 9
                    self.vel += Vec3(self.forward.x, 0, self.forward.z) * 3
                    self.wall_n = None
                    self.wallrunning = False
            elif not titan:
                if not self.tente_grimper() and self.jumps > 0:
                    self.vy, self.jumps = 8, self.jumps - 1
        elif K.est(key, 'recharge') and not titan:
            self.arme.recharger()
        elif K.est(key, 'arme1') and not titan:
            self.choisir_arme(0)
        elif K.est(key, 'arme2') and not titan:
            self.choisir_arme(1)
        elif (K.est(key, 'arme_suiv') or K.est(key, 'arme_prec')) and not titan:
            self.choisir_arme(1 - self.idx)
        elif K.est(key, 'titan') and not titan:
            self.appeler_titan()
        elif K.est(key, 'interagir'):
            if titan:
                self.ejecter()
            elif self.titan_actif() and self.titan.state == 'ready' \
                    and distance(self.position, self.titan.position) < 8:
                self.embarquer()
        elif K.est(key, 'tactique') and not titan:
            self.lancer_tactique(camera.world_position + camera.forward * .6,
                                 camera.forward * 18 + Vec3(0, 3, 0))
        elif K.est(key, 'grappin') and not titan:
            self.lancer_grappin()
        elif K.est(key, 'glisse') and self.grounded and not titan and self.slide_t <= 0:
            v = Vec3(self.vel.x, 0, self.vel.z)
            if v.length() > 6:
                # ELAN CONSERVE : la glissade démarre à la vitesse de la course (+12 %), jamais en dessous de 13 m/s
                self.slide_t, self.slide_dir = 2.2, E.norm(v)
                self.slide_v = min(24, max(v.length() * 1.12, 13))
        elif K.est(key, 'tir') and not self.arme_active().auto:
            self.tirer()
        elif K.est(key, 'melee'):
            melee.frapper_joueur(self)               # couteau (épée si on pilote le Titan)
        elif not titan and K.est(key, 'ordre_suivre'):
            self.donner_ordre('suivre')
        elif not titan and K.est(key, 'ordre_garder'):
            self.donner_ordre('garder')
        elif not titan and K.est(key, 'ordre_aller'):
            self.donner_ordre('aller')
        elif not titan and K.est(key, 'ordre_attaquer'):
            self.donner_ordre('attaquer')
        else:
            craft.touche(key, self)                  # kits de soin / d'armure

    # ---- animation de frappe ------------------------------------------------------------------
    def swing(self, arme):
        """Brandit le couteau / l'épée du Titan quelques instants (l'arme tenue est masquée)."""
        cle = (arme.modele, self.mode == 'titan')
        if cle not in self.melee_vms:
            self.melee_vms[cle] = VM.construire(arme.modele, camera, cle[1])
        for k, vm in self.melee_vms.items():
            vm.enabled = (k == cle)
        self.melee_t = .3
        self.gun.enabled = False

    def maj_swing(self, dt):
        if self.melee_t <= 0:
            return
        self.melee_t -= dt
        titan = self.mode == 'titan'
        for (nom, t), vm in self.melee_vms.items():
            if not vm.enabled:
                continue
            p = 1 - max(0, self.melee_t) / .3
            k = 2.6 if t else 1
            vm.position = (lerp(.45, -.25, p) * k, (-.3 + .12 * math.sin(p * 3.14)) * k, .7 * k)
            vm.rotation = (lerp(-25, 25, p), lerp(-35, 25, p), lerp(50, -60, p))
        if self.melee_t <= 0:
            for vm in self.melee_vms.values():
                vm.enabled = False
            self.gun.enabled = not self.lunette and self.melee_t <= 0

    # ---- parkour : grimper (style Dying Light) -------------------------------
    def tente_grimper(self):
        if self.mode == 'titan' or self.grimpe or not self.vivant:
            return False
        fw = Vec3(self.forward.x, 0, self.forward.z)
        if fw.length() < .1:
            return False
        fw = E.norm(fw)
        p = self.position
        qx, qz = p.x + fw.x * (self.r + .35), p.z + fw.z * (self.r + .35)
        top = E.hits(qx, p.y + .5, qz, .15, 2.2)
        if top is None or top > p.y + 2.7:
            return False
        tx, tz = p.x + fw.x * (self.r + .85), p.z + fw.z * (self.r + .85)
        sol = E.hits(tx, top - .3, tz, self.r * .8, .1)
        if sol is None or abs(sol - top) > .05:
            return False
        if E.hits(tx, top + .02, tz, self.r, self.h - .02) is not None:
            return False
        self.grimpe = [Vec3(p.x, p.y, p.z), Vec3(tx, top, tz), 0.0]
        self.slide_t = 0
        return True

    # ---- grappin -----------------------------------------------------------------------
    def lancer_grappin(self):
        if self.grappin is not None or self.grappin_cd > 0:
            return
        o, d = camera.world_position, camera.forward
        t = E.ray_world(o, d, 50)
        if t < 50:
            self.grappin, self.grappin_t = o + d * t, 1.2
            self.corde = Entity(model='cube', color=color.light_gray, scale=(.03, .03, 1))
            self.slide_t = 0

    def fin_grappin(self, boost=False):
        self.grappin = None
        if self.corde is not None:
            destroy(self.corde)
            self.corde = None
        if boost:
            self.grappin_cd = 3
            self.vy = max(self.vy, 6)

    def tirer_grappin(self, dt):
        cible = self.grappin
        d = cible - (self.position + Vec3(0, 1, 0))
        l = d.length()
        self.grappin_t -= dt
        if l < 2.5 or self.grappin_t <= 0:
            self.fin_grappin(boost=True)
            return
        dn = d * (1 / l)
        self.vel.x, self.vel.z, self.vy = dn.x * 28, dn.z * 28, dn.y * 28
        o = camera.world_position + camera.right * .3 - camera.up * .3
        self.corde.position = (o + cible) * .5
        self.corde.scale_z = distance(o, cible)
        self.corde.look_at(cible)

    # ---- tir --------------------------------------------------------------------------------
    def tirer(self):
        a = self.arme_active()
        if a.melee:                                  # clic gauche avec le couteau en main = coup de couteau
            melee.frapper_joueur(self)
            return
        o, d = camera.world_position, camera.forward
        debut = o + camera.right * .3 - camera.up * .2 + camera.forward * .5
        if a.tirer(self, o, d, debut=debut, zoomed=self.zoom):
            self.gun.z -= a.recul
            self.pivot.rotation_x -= a.recul * 6
            self.vm.flash.enabled, self.flash_t = True, .045
            FX.secousse(a.recul * 2.5)
            if self.mode == 'pilot' and a.munitions == 0:
                a.recharger()

    # ---- caméra ----------------------------------------------------------------------------------
    def regarder(self):
        a = self.arme_active()
        ratio = clamp(a.zoom / S.FOV, .25, 1) if (self.zoom and a is not None and a.zoom) else 1
        sens = S.SENSIBILITE * ratio
        vx, vy = self.mouvement_souris()
        self.rotation_y += vx * sens
        inv = -1 if S.INVERSER_Y else 1
        self.pivot.rotation_x = clamp(self.pivot.rotation_x - vy * sens * inv, -89, 89)

    def mouvement_souris(self):
        """Déplacement de la souris. Pendant le jeu, Partie désactive mouse.update (qui fait un picking
        d'entités à chaque image, inutile curseur verrouillé) : on lit alors la position et on recentre."""
        if mouse.enabled or not mouse.locked:
            return mouse.velocity[0], mouse.velocity[1]
        p = mouse.position
        mouse.position = (0, 0)
        return p[0], p[1]

    def vol_spectateur(self, dt):
        """Éliminé : caméra libre pour regarder la fin du match."""
        self.regarder()
        f, s = K.axe('avant', 'arriere'), K.axe('droite', 'gauche')
        d = camera.forward * f + camera.right * s
        self.position = self.position + d * (25 if K.tenu('sprint') else 14) * dt
        if self.y < .5:
            self.y = .5
        self.pivot.y = 1.65

    # ---- boucle principale ----------------------------------------------------------------------------
    def update(self):
        P = E.partie
        if not P.en_cours or P.pause:
            return
        dt = time.dt
        if self.elimine:
            self.vol_spectateur(dt)
            return
        if not self.vivant or P.fini:
            return
        self.tick(dt)
        self.maj_swing(dt)
        self.grappin_cd -= dt
        titan = self.mode == 'titan'
        self.r, self.h = (1.2, 5.6) if titan else (.4, 1.8)
        a = self.arme_active()
        self.regarder()
        self.pivot.y = lerp(self.pivot.y, 5.2 if titan else (.9 if self.slide_t > 0 else 1.65), 8 * dt)

        f = K.axe('avant', 'arriere')
        s = K.axe('droite', 'gauche')
        wish = self.forward * f + self.right * s
        wish = Vec3(wish.x, 0, wish.z)
        if wish.length() > 0:
            wish = E.norm(wish)

        if self.grimpe:
            self.animer_grimpe(dt, wish)
        else:
            self.mouvement(dt, f, wish, titan)

        # --- caméra : roulis en wall-run, FOV selon vitesse, zoom
        tilt = 9 * self.wall_n.dot(self.right) if (self.wallrunning and self.wall_n is not None) else 0
        camera.rotation_z = lerp(camera.rotation_z, tilt, 8 * dt)
        self.zoom = a.zoom is not None and K.tenu('viser') and self.grimpe is None
        self.lunette = self.zoom and a.zoom < 30          # lunette de sniper : arme masquée + overlay
        self.gun.enabled = not self.lunette
        if self.zoom:
            camera.fov = lerp(camera.fov, a.zoom, 10 * dt)
        else:
            vit = Vec3(self.vel.x, 0, self.vel.z).length()
            camera.fov = lerp(camera.fov, S.FOV + vit * S.FOV_VITESSE, 4 * dt)

        # --- armes : visée (arme au centre), retour du recul, balancement de marche
        vit = Vec3(self.vel.x, 0, self.vel.z).length()
        if self.grounded and vit > 1:
            self.bob += dt * (6 + vit * .5)
        amp = 0 if self.zoom else min(1, vit / 8)
        tx, ty, tz = VM.ads(a.modele, a.titan) if self.zoom else a.vue[1]
        k = min(1, 16 * dt)
        self.gun.x = lerp(self.gun.x, tx + math.sin(self.bob) * .012 * amp, k)
        self.gun.y = lerp(self.gun.y, ty + abs(math.cos(self.bob)) * .012 * amp, k)
        self.gun.z = lerp(self.gun.z, tz, 15 * dt)
        if self.flash_t > 0:
            self.flash_t -= dt
            if self.flash_t <= 0:
                self.vm.flash.enabled = False
        FX.shake *= max(0, 1 - 9 * dt)
        camera.position = Vec3(random.uniform(-1, 1) * FX.shake * .12, random.uniform(-1, 1) * FX.shake * .12, 0)
        if K.tenu('tir') and a.auto and a.pret():
            self.tirer()

    def animer_grimpe(self, dt, wish):
        g = self.grimpe
        g[2] += dt / .42
        p = min(1.0, g[2])
        up, fw = min(1.0, p / .6), max(0.0, (p - .4) / .6)
        s0, e0 = g[0], g[1]
        self.position = Vec3(lerp(s0.x, e0.x, fw), lerp(s0.y, e0.y, up), lerp(s0.z, e0.z, fw))
        self.vel, self.vy = Vec3(0, 0, 0), 0
        if p >= 1:
            self.grimpe = None
            self.grounded, self.jumps, self.wall_t = True, 1, 0
            self.vel = Vec3(wish.x * 3, 0, wish.z * 3)

    def appliquer_vitesse(self, dt, wish, speed, sprint):
        """CONSERVATION DE LA VITESSE : au-dessus de la vitesse de marche/course la vitesse ne retombe
        que progressivement (course -> glissade -> saut gardent leur élan), la direction se règle séparément."""
        if self.slide_t > 0:
            return
        sol = self.grounded
        v = Vec3(self.vel.x, 0, self.vel.z)
        mag = v.length()
        if wish.length() > 0:
            dirv = v * (1 / mag) if mag > .1 else wish
            if mag > .1 and dirv.dot(wish) < -.3:          # demi-tour : on freine franchement
                k = min(1, (14 if sol else 3.5) * dt)
                self.vel.x = lerp(self.vel.x, wish.x * speed, k)
                self.vel.z = lerp(self.vel.z, wish.z * speed, k)
                return
            d = E.norm(lerp(dirv, wish, min(1, (14 if sol else 2.6) * dt)))
            if mag > speed:                                # élan : décroissance lente vers la vitesse de course
                taux = ((1.0 if sprint else 2.0) if sol else (1.0 if self.wallrunning else .3))
                mag = speed + (mag - speed) * math.exp(-taux * dt)
            else:
                mag = lerp(mag, speed, min(1, (14 if sol else (8 if self.wallrunning else 3.5)) * dt))
            self.vel.x, self.vel.z = d.x * mag, d.z * mag
        else:                                              # aucune touche : frottement (fort au sol, faible en l'air)
            k = min(1, (10 if sol else 1.0) * dt)
            self.vel.x = lerp(self.vel.x, 0, k)
            self.vel.z = lerp(self.vel.z, 0, k)

    def mouvement(self, dt, f, wish, titan):
        sprint = K.tenu('sprint')
        speed = (10 if sprint else 6) if titan else (12 if sprint else 8) * self.vitesse_mult
        if self.wallrunning:
            speed *= 1.25
        if self.zoom:
            speed *= .7
        self.appliquer_vitesse(dt, wish, speed, sprint)

        if self.grappin is not None:
            self.tirer_grappin(dt)
        if self.slide_t > 0:
            # ---- GLISSADE : on conserve l'élan de la course, il ne diminue que par frottement (4,5 m/s²)
            self.slide_t -= dt
            self.slide_v = max(0.0, self.slide_v - 4.5 * dt)
            if wish.length() > 0:                        # léger contrôle de trajectoire
                self.slide_dir = E.norm(lerp(self.slide_dir, wish, min(1, 1.6 * dt)))
            self.vel.x, self.vel.z = self.slide_dir.x * self.slide_v, self.slide_dir.z * self.slide_v
            if not self.grounded or self.slide_v < 6.5:
                self.slide_t = 0                         # fin de glissade : la vitesse restante est conservée

        # grimper automatiquement en gardant Espace contre un mur
        if self.wall_n is not None and not self.grounded and K.tenu('saut') and f > 0 and not titan:
            if self.tente_grimper():
                return

        # wall-run : on reste collé au mur touché à la frame précédente
        stick = (self.wall_n is not None and not self.grounded and f > 0
                 and self.wall_t < 3 and not titan and self.grappin is None)
        self.wallrunning = stick
        if stick:
            self.wall_t += dt
            self.vy = max(self.vy - 6 * dt, -1.5)
            self.vel = self.vel - self.wall_n * 4
            self.jumps = 1
        elif self.grappin is None:
            self.vy -= 22 * dt

        # --- collisions axe par axe (marche jusqu'à 0,5 m sans sauter)
        self.wall_n = None
        pos, r, h, st = self.position, self.r, self.h, .5
        nx = pos.x + self.vel.x * dt
        if E.hits(nx, pos.y + st, pos.z, r, h - st) is None:
            pos.x = nx
        else:
            self.wall_n, self.vel.x = Vec3(-math.copysign(1, self.vel.x), 0, 0), 0
        nz = pos.z + self.vel.z * dt
        if E.hits(pos.x, pos.y + st, nz, r, h - st) is None:
            pos.z = nz
        else:
            self.wall_n, self.vel.z = Vec3(0, 0, -math.copysign(1, self.vel.z)), 0
        ny = pos.y + self.vy * dt
        top = E.hits(pos.x, ny, pos.z, r, h)
        if top is None and ny > 0:
            pos.y, self.grounded = ny, False
        else:
            if self.vy < 0:
                pos.y = top if top is not None else 0
                self.grounded, self.jumps, self.wall_t = True, 1, 0
            self.vy = 0
        lim = E.DEMI_MAP - 2
        pos.x, pos.z = clamp(pos.x, -lim, lim), clamp(pos.z, -lim, lim)
        self.position = pos
